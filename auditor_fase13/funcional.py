"""Mide el cierre funcional y conserva la clasificación por impacto de la investigación."""

from collections import Counter, defaultdict
from datetime import date
from fractions import Fraction
from hashlib import sha256
import json
import re
import subprocess
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

from mission_rules import _collect
from world_rules import XP_OPCIONAL


CLIENT_CASES = {
    "instalacion_migracion": "Instalación, actualización y migración",
    "alianza_inicio": "Ruta inicial de Alianza en español",
    "horda_inicio": "Ruta inicial de Horda en inglés",
    "mapa_questie": "Mapas, flecha y convivencia con Questie",
    "nivel_viaje": "Tramo intermedio, continuidad y transporte",
    "desbloqueos_clase": "Desbloqueos esenciales y tramo alto",
}
RESEARCH_CODES = {"MISION_FUENTES_INCOMPLETAS", "PERFIL_REQUISITOS_PENDIENTES"}
IMPROVEMENT_CODES = {"posiciones_sin_evidencia_forever", "xp_escenario_misiones", "xp_evidencia_incompleta",
                     "xp_real_cliente", "viajes_coste_cliente", "objetivos_agrupables"}
CRITICAL_CODES = {"motor-prueba-no-disponible", "motor-prueba-seleccion"}
OPTIONAL_ORDER_CODES = {"MISION_REQUISITO_ALTERNATIVO", "MISION_REQUISITO_ORDEN", "MISION_REQUISITO_FUERA_DE_RUTA"}
PRIORITIES = ("P0", "P1", "P2", "P3")


def load_client_evidence(path, routes, fingerprint):
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("El registro funcional debe contener una lista de pruebas de Forever.")
    profiles = {row["id"]: (row["_faccion"], row["clase"], row["razas"]) for row in routes}
    result, seen = {}, set()
    for sample in data:
        if not isinstance(sample, dict):
            raise ValueError("Registro funcional de cliente inválido.")
        case = sample.get("caso")
        key = case, str(sample.get("huella_addon", ""))
        if (case not in CLIENT_CASES or key in seen or sample.get("origen") != "cliente_forever"
                or sample.get("resultado") not in ("superada", "fallo")
                or sample.get("ruta") not in profiles
                or not re.fullmatch(r"1\.60\.\d+\.\d+", str(sample.get("compilacion", "")))
                or not re.fullmatch(r"[0-9a-f]{64}", str(sample.get("huella_addon", "")))
                or not isinstance(sample.get("evidencia"), str) or not sample["evidencia"].strip()):
            raise ValueError(f"Prueba funcional inválida o duplicada para {case}.")
        if (sample.get("faccion") not in ("Alliance", "Horde") or sample.get("idioma") not in ("esES", "enUS")
                or type(sample.get("nivel")) is not int or not 1 <= sample["nivel"] <= 60
                or not all(isinstance(sample.get(field), str) and sample[field].strip() for field in ("raza", "clase"))):
            raise ValueError(f"Falta el perfil observado para {case}.")
        faction, player_class, races = profiles[sample["ruta"]]
        level = sample["nivel"]
        if (sample["faccion"] != faction or sample["clase"] != player_class or sample["raza"] not in races
                or (case == "alianza_inicio" and (faction != "Alliance" or sample["idioma"] != "esES" or level > 15))
                or (case == "horda_inicio" and (faction != "Horde" or sample["idioma"] != "enUS" or level > 15))
                or (case == "nivel_viaje" and not 17 <= level <= 44)
                or (case == "desbloqueos_clase" and not 45 <= level <= 60)):
            raise ValueError(f"El perfil no cubre el escenario funcional {case}.")
        date.fromisoformat(str(sample.get("fecha", "")))
        seen.add(key)
        if sample["huella_addon"] == fingerprint:
            result[case] = sample
    return result


def package_entries(addon):
    return {path.relative_to(addon.parent).as_posix(): path
            for path in sorted(addon.rglob("*")) if path.is_file()}


def addon_fingerprint(entries):
    manifest = "".join(f"{sha256(path.read_bytes()).hexdigest()}  {name}\n" for name, path in entries.items())
    return sha256(manifest.encode("utf-8")).hexdigest()


def verify_package(path, entries, fingerprint, *, create=False):
    if create:
        path.parent.mkdir(parents=True, exist_ok=True)
        with ZipFile(path, "w") as archive:
            for name, file in entries.items():
                archive.writestr(ZipInfo(name), file.read_bytes(), compress_type=ZIP_DEFLATED)
    if not path.is_file():
        return None
    with ZipFile(path) as archive:
        members = archive.namelist()
        if len(members) != len(entries) or set(members) != set(entries) or archive.testzip() is not None:
            raise ValueError(f"Contenido inesperado en {path}.")
        if any(archive.read(name) != file.read_bytes() for name, file in entries.items()):
            raise ValueError(f"El paquete {path} pertenece a otro corte del addon.")
    return {"nombre": path.name, "archivos": len(entries), "huella_addon": fingerprint,
            "sha256": sha256(path.read_bytes()).hexdigest()}


def verify_remote(root):
    def git(*args):
        return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True, timeout=15).stdout.strip()

    branch = "fase-13-auditoria-leveo"
    ref = f"refs/heads/{branch}"
    try:
        if git("branch", "--show-current") != branch or not re.search(r"(?:[:/])JKRiveroF/Wow(?:\.git)?$", git("remote", "get-url", "origin")):
            return False
        return (not git("status", "--porcelain", "--", "GuiaAventurero")
                and git("ls-remote", "--exit-code", "origin", ref) == f"{git('rev-parse', 'HEAD')}\t{ref}")
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return False


def _optional(point, missions):
    if XP_OPCIONAL.match(point.guide_text):
        return True
    if point.quest in (1374, 1375):
        return "si no lo tienes en el diario, continúa" in point.guide_text.casefold()
    return (point.quest == 3504 and point.guide_text.startswith("Si Belgrom")
            and any(3504 in row.get("misiones_sin_aceptar_ni_entregar", ())
                    for row in missions.get(3505, {}).get("observaciones_oferta", ())))


def classify(routes, findings, inventory, optional_test=False):
    missions = {row["id"]: row for row in inventory["misiones"] if row.get("rutas")}
    points = {}
    acceptances = defaultdict(list)
    for route in routes:
        for point in _collect(route, []):
            points[route["_archivo"], point.location] = point
            if point.action == "A":
                acceptances[point.quest].append((route["id"], _optional(point, missions)))
    classified = []
    for finding in findings:
        row = dict(finding)
        point = points.get((row.get("archivo"), row.get("ubicacion")))
        if point:
            row.setdefault("mision", point.quest)
        code = row["codigo"]
        if code in CRITICAL_CODES or (row["bloque"] == 1 and row["gravedad"] == "error"):
            priority, status = "P0", "defecto" if row["gravedad"] == "error" else "por comprobar"
        elif code in RESEARCH_CODES:
            priority, status = "P3", "dato pendiente"
        elif code in IMPROVEMENT_CODES:
            priority, status = "P2", "estimación o precisión pendiente"
        elif (code in OPTIONAL_ORDER_CODES and optional_test and point and point.quest == 93685
              and _optional(point, missions)):
            priority, status = "P2", "dependencia de canje opcional comprobada"
        else:
            priority, status = "P1", "defecto" if row["gravedad"] != "pendiente" else "por comprobar"
        row.update(prioridad=priority, estado_funcional=status)
        classified.append(row)

    for quest, mission in missions.items():
        if mission.get("evidencia", {}).get("existe", {}).get("valor") is True:
            continue
        samples = acceptances[quest]
        unsafe = sorted({route for route, optional in samples if not optional})
        if not samples:
            unsafe = mission["rutas"]
        if unsafe:
            classified.append({"bloque": 2, "codigo": "oferta_principal_sin_alternativa", "mision": quest,
                               "rutas": unsafe, "prioridad": "P1", "estado_funcional": "por comprobar",
                               "detalle": "Falta acreditar la oferta o una salida segura en la ruta principal."})
    return classified


def documents_ready(root):
    documents = root / "auditor_fase13"
    notes = (documents / "NOTAS_FASE13.md").read_text(encoding="utf-8")
    protocol = (documents / "VALIDACION_FOREVER.md").read_text(encoding="utf-8")
    registry = (documents / "PENDIENTES_INVESTIGACION_FOREVER.md").read_text(encoding="utf-8")
    return (all(re.search(rf"^## {language}\n\n- \S", notes, re.M) for language in ("Español", "English"))
            and all(re.search(rf"^\| `{case}` \|", protocol, re.M) for case in CLIENT_CASES)
            and "<!-- incidencias-fase13:inicio -->" in registry and "<!-- incidencias-fase13:fin -->" in registry)


def measure_functional(routes, classified, tests, regression, client, package=None, git_verified=False,
                       documentation=False, complete_sources=False):
    def test(name):
        return name in tests

    def case(name):
        return client.get(name, {}).get("resultado") == "superada"

    def unblocked(block):
        return not any(row["bloque"] == block and row["prioridad"] in ("P0", "P1") for row in classified)

    def proof(name, passed, source):
        return {"id": name, "superada": bool(passed), "evidencia": source}

    selection = len(routes) == 47 and len({(r["_faccion"], r["clase"], race)
                                         for r in routes for race in r.get("razas", ())}) == 56 and unblocked(1)
    optional = test("test_kumisha_and_stonetalon_can_be_omitted_in_the_real_route_engine")
    profile_cases = [client[key] for key in ("alianza_inicio", "horda_inicio", "desbloqueos_clase") if case(key)]
    profiles = (len(profile_cases) == 3 and {r["faccion"] for r in profile_cases} == {"Alliance", "Horde"}
                and len({r["raza"] for r in profile_cases}) >= 2 and len({r["clase"] for r in profile_cases}) >= 2
                and {r["idioma"] for r in profile_cases} == {"esES", "enUS"})
    checks = {
        1: [proof("lua_y_toc", unblocked(1) and test("test_toc_version_guardados_y_recursos"), "Lua 5.1 y TOC"),
            proof("integridad", all(test(name) for name in ("test_manifiesto_y_zip_del_commit_base",
                  "test_las_rutas_conservan_todo_fuera_de_los_cambios_revisados",
                  "test_distribucion_conserva_archivos_y_limites_de_cambios")), "Manifiesto y comparación con el ZIP base"),
            proof("rutas_niveles_motor_y_perfiles", selection, "Carga y selección de 47 rutas y 56 perfiles con API simulada")],
        2: [proof("ids_disponibilidad_y_dependencias", complete_sources and selection and unblocked(2), "Reglas de misión y clasificación por impacto"),
            proof("orden_e_instrucciones", test("test_stonetalon_optional_chain_keeps_the_original_destinations_after_1070")
                  and test("test_algaz_brutal_armor_and_mage_deliveries_follow_their_requirements"), "Secuencias corregidas y textos ES/EN"),
            proof("omisiones_seguras", optional, "Control de avance real del addon con API simulada")],
        3: [proof("mapas_y_coordenadas", complete_sources and selection and unblocked(3), "Validación local de mapas, destinos y contradicciones conocidas"),
            proof("marcadores_y_flecha", case("mapa_questie"), "Cliente Forever · mapa_questie")],
        4: [proof("tramos_y_nivel", test("test_engine_selects_a_valid_section_for_every_level_and_profile") and unblocked(4),
                  "Selección de tramo con el motor Lua y niveles mínimos conocidos"),
            proof("sin_xp_y_opcionales", optional and test("test_refuerzos_sin_xp_have_matching_english_for_reviewed_steps"),
                  "Separación de canjes y opciones en las pruebas locales"),
            proof("continuidad", case("nivel_viaje"), "Cliente Forever · nivel_viaje")],
        5: [proof("viajes_conocidos", complete_sources and selection and unblocked(5), "Cartografía local y transportes incompatibles conocidos"),
            proof("nodos_por_faccion", test("test_primary_flight_records_match_route_coordinates")
                  and test("test_pasos_desconocidos_o_incompletos_siguen_manuales"), "Nodos y transporte desconocido en API simulada"),
            proof("desplazamiento", case("nivel_viaje"), "Cliente Forever · nivel_viaje")],
        6: [proof("matriz_y_filtros", selection and unblocked(6), "Selección y filtros de 56 combinaciones"),
            proof("arranques", test("test_all_non_skyborne_routes_match_observed_starters")
                  and test("test_racial_pickup_indices_and_english_translation"), "Inicio, raza y traducción en pruebas locales"),
            proof("desbloqueos_y_textos", profiles, "Cliente Forever · Alianza ES, Horda EN y desbloqueos de clase")],
        7: [proof("regresion", regression.get("correcta") and regression.get("ejecutadas", 0) > 0
                  and regression.get("ejecutadas") == regression.get("superadas"), "Batería local obligatoria"),
            proof("questie_y_guardados_locales", test("test_migracion_legacy_preserva_identidad_progreso_y_preferencias")
                  and test("test_eventos_de_mision_respetan_questie_y_el_estado_indeterminado"), "Questie y migración con API simulada"),
            proof("instalacion_y_cliente", profiles and all(case(key) for key in CLIENT_CASES), "Suite representativa de Forever"),
            proof("documentacion_e_incidencias", documentation and all(unblocked(n) for n in range(1, 8)),
                  "Clasificación completa y registro de investigación generado"),
            proof("zip", bool(package) and all(case(key) for key in CLIENT_CASES), "ZIP contrastado con la instalación validada"),
            proof("sincronizacion", git_verified, "Rama de desarrollo y árbol del addon verificados")],
    }
    counts = Counter(row["prioridad"] for row in classified)
    blocked = sorted({route for row in classified if row["prioridad"] in ("P0", "P1")
                      for route in (row.get("rutas") or [row.get("ruta")]) if route})
    return {"bloques": {str(block): rows for block, rows in checks.items()},
            "incidencias": {key: counts[key] for key in PRIORITIES}, "rutas_bloqueadas": blocked,
            "cliente": {key: client.get(key, {}).get("resultado", "pendiente") for key in CLIENT_CASES},
            "paquete": package}


def add_to_measurement(metrics, functional):
    metrics["cierre_funcional"] = functional
    for key, row in metrics["bloques"].items():
        checks = functional["bloques"][key]
        row["funcional"] = [sum(check["superada"] for check in checks), len(checks)]
    value = sum(Fraction(*row["funcional"]) * row["peso"] for row in metrics["bloques"].values()) / 100
    metrics["global"]["funcional"] = [value.numerator, value.denominator]


def render_registry(classified, routes):
    groups = defaultdict(list)
    for row in classified:
        groups[row["prioridad"], row["bloque"], row["codigo"], row.get("mision", "—")].append(row)
    lines = ["| Prioridad | Bloque | Comprobación | ID de misión | Casos | Rutas | Confianza y motivo | Fuente o comprobación futura |",
             "| --- | ---: | --- | ---: | ---: | --- | --- | --- |"]
    for (priority, block, code, mission), rows in sorted(groups.items(), key=lambda pair: tuple(map(str, pair[0]))):
        affected = sorted({route for row in rows for route in (row.get("rutas") or [row.get("ruta")]) if route})
        route_text = ("Todas las rutas" if len(affected) == len(routes) else ", ".join(f"`{r}`" for r in affected) or "Transversal")
        status = rows[0]["estado_funcional"]
        source = rows[0].get("fuente")
        followup = ("[Evidencia](" + str(source) + ")" if source else "Cruzar el inventario por ID con fuentes de Forever")
        if any(row.get("resolucion") == "cliente" for row in rows):
            followup = "[Protocolo de cliente](VALIDACION_FOREVER.md)"
        lines.append(f"| {priority} | {block} | `{code}` | {mission} | {len(rows)} | {route_text} | {status} | {followup} |")
    return "\n".join(lines)

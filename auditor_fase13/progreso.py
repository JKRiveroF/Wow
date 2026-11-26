"""Mide el avance de la fase a partir de resultados, evidencia y validaciones registradas."""

from collections import Counter
from datetime import date, datetime
from fractions import Fraction
import json
import os
import re
import subprocess
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from mission_rules import _waypoints
from world_rules import _catalog_entry, _dict, _id, _matches_observation, _matches_positions, _position, _positions_by_action, _source


BLOCKS = {
    1: ("Estructura", 10), 2: ("Misiones", 25), 3: ("Cartografía", 20),
    4: ("Experiencia", 15), 5: ("Viajes", 15), 6: ("Clase, raza y facción", 10),
    7: ("Regresión y preparación", 5),
}
SCHEMA = 1
PREVIOUS_CERTIFIED = ((95, 95), (47, 188), (47, 141), (47, 141), (47, 141), (94, 141), (1, 4))
STATES = ("confirmada", "parcial", "inferencia", "investigacion", "cliente")
MISSION_LOCAL = {"MISION_ACCION_ETIQUETA_DISTINTA", "MISION_DESTINO_INVALIDO", "MISION_DESTINO_REPETIDO",
                 "MISION_ORDEN_ACCION"}
RESEARCH_REVIEWS = {"2.identidad", "2.dependencias", "2.especiales", "3.posiciones", "4.estimacion",
                    "5.transporte", "5.desbloqueos", "5.alternativas", "7.paquete", "7.sincronizacion"}
CLIENT_TASKS = {
    "3.cliente": ("3.transiciones", "3.interiores", "3.puntos_vuelo"),
    "4.cliente": ("4.saldo", "4.bloqueos"),
    "5.cliente": ("5.tiempos_secuencias",),
    "6.cliente": ("6.acceso", "6.desbloqueos", "6.traducciones"),
}
CLIENT_REVIEWS = {"5.ahorro", "6.aprendizaje", "7.caso_cliente"} | {part for parts in CLIENT_TASKS.values() for part in parts}
TWO_STAGE_FIELDS = {"nombre_es", "nombre_en", "razas", "facciones"}
LEARNING_CONFIRMED = {"efecto_de_aprendizaje", "aprendizaje_por_habilidad"}
LEARNING_CONTRASTED = LEARNING_CONFIRMED | {"indicio_de_recompensa", "destino_de_aprendizaje_pendiente"}


def family(name, states, contrast=False):
    counts = Counter(states)
    base = sum(counts.values())
    if not base:
        return None
    stages = {"confirmadas": counts["confirmada"]}
    if contrast:
        stages["contrastadas"] = counts["confirmada"] + counts["parcial"]
    return {"nombre": name, "unidades": base, "estados": {state: counts[state] for state in STATES},
            "comprobaciones_superadas": sum(stages.values()), "comprobaciones_aplicables": base * len(stages),
            "etapas": stages}


def criterion(key, closed, parts=()):
    complete, total = sum(closed), len(closed)
    parts = [part for part in parts if part]
    cert = Fraction(complete, total) if total else Fraction()
    # La revisión integral es una comprobación expresa y participa junto a las familias.
    ratios = [cert, *(Fraction(p["comprobaciones_superadas"], p["comprobaciones_aplicables"]) for p in parts)]
    effective = sum(ratios) / len(ratios)
    return {"id": key, "completos": complete, "aplicables": total, "efectivo": _pair(effective), "familias": parts}


def _pair(value):
    return [value.numerator, value.denominator]


def _state(passed, pending="investigacion"):
    return "confirmada" if passed else pending


def validate_records(path):
    if not path.is_file():
        return set()
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"Se esperaba una lista de validaciones en {path}.")
    seen, verified = set(), set()
    for row in data:
        if not isinstance(row, dict):
            raise ValueError(f"Registro de validación inválido en {path}.")
        key = row.get("criterio"), row.get("unidad")
        if (not all(isinstance(value, str) and value.strip() for value in key) or key in seen
                or key[0] not in RESEARCH_REVIEWS | CLIENT_REVIEWS):
            raise ValueError(f"Validación duplicada o desconocida: {key}.")
        if (row.get("resultado") not in ("verificado", "pendiente", "fallo")
                or not isinstance(row.get("fuente"), str) or not row["fuente"].strip()):
            raise ValueError(f"Falta resultado o evidencia para {key}.")
        date.fromisoformat(str(row.get("fecha", "")))
        if key[0] in CLIENT_REVIEWS and not re.fullmatch(r"\d+\.\d+\.\d+\.\d+", str(row.get("compilacion", ""))):
            raise ValueError(f"Falta la compilación de Forever para {key}.")
        seen.add(key)
        if row["resultado"] == "verificado":
            verified.add(key)
    return verified


def _field_state(mission, field, conditional):
    evidence = mission["evidencia"]
    if field in evidence:
        if field == "existe" and evidence[field]["valor"] is not True:
            return "investigacion"
        return "confirmada"
    if field == "nombre_es" and (match := mission.get("contraste_es_heredado")):
        if match["titulo_guia_cotejado"] and not match["titulos_guia_distintos"]:
            return "parcial"
        return "inferencia"
    if field in ("razas", "facciones"):
        samples = evidence.get("acceso_observado", {}).get("valor", [])
        token = "raza" if field == "razas" else "faccion"
        if any(row.get(token) for row in samples):
            return "parcial"
    related = {"prerrequisitos": "misiones_previas_observadas", "seguimientos": "siguiente_sugerida"}
    if related.get(field) in evidence or any(row.get("campo") == field for row in mission["indicios"]):
        return "inferencia"
    return "cliente" if conditional and field == "existe" else "investigacion"


def _valid_reference(record, position):
    if _source(record, "posiciones_descartadas") and position in _positions_by_action(record, "posiciones_descartadas", None):
        return "investigacion"
    if _source(record, "posiciones") and _matches_positions(position, _positions_by_action(record, "posiciones", None), 1):
        return "confirmada"
    return "parcial" if _matches_observation(record, None, position, 1) else "investigacion"


def _coverage(routes, catalog, missions, flights):
    """Usa el mismo inventario en los bloques que consumen misiones o posiciones compartidas."""
    maps, positions, flight_names = set(), {}, set()
    for route in routes:
        for section in route.get("secciones", []) or []:
            for step in _dict(section).get("pasos", []) or []:
                check = _dict(_dict(step).get("comprobar"))
                if _id(arrival := check.get("llegar")):
                    maps.add(arrival)
                if isinstance(name := check.get("vuelo"), str) and name.strip():
                    flight_names.add((route.get("_faccion"), name))
        for _, _, _, _, _, point in _waypoints(route):
            if not (position := _position(point)):
                continue
            maps.add(position[0])
            if _id(point.get("npc")):
                key = point["npc"], position
                if key not in positions:
                    positions[key] = _valid_reference(_catalog_entry(catalog.get("pnj"), point["npc"]), position)
            elif not _id(point.get("q")):
                positions[None, position] = "investigacion"

    mission_positions = (point["estado"] for mission in missions for point in mission["posiciones"])
    location_states = {"compatible_con_fuente": "confirmada", "cerca_de_observacion": "parcial"}
    map_states = []
    for map_id in maps:
        record = _catalog_entry(catalog.get("mapas"), map_id)
        map_states.append(_state(record.get("existe") is True and _source(record, "existe")))
    nodes = {}
    for faction, name in flight_names:
        documented = _catalog_entry(catalog.get("vuelos"), name)
        allowed = documented.get("facciones") or []
        faction_source = _source(documented, "facciones")
        confirmed = faction_source and faction in allowed
        observed = flights.get("nodos", {}).get(faction, {}).get(name, {})
        unavailable = ((_source(documented, "existe") and documented.get("existe") is False)
                       or (faction_source and allowed and faction not in allowed))
        key = faction, observed.get("nodo", name)
        status = _state((confirmed or observed) and not unavailable)
        if key not in nodes or unavailable:
            nodes[key] = status
    return (family("UiMapID", map_states),
            family("Coordenadas por misión y acción", (location_states.get(status, "investigacion")
                                                        for status in mission_positions), contrast=True),
            family("Coordenadas de PNJ y orientación", positions.values(), contrast=True),
            family("Nodos de vuelo por facción", nodes.values()))


def _client_cases(path):
    lines = path.read_text(encoding="utf-8").split("\n## ", 1)[0].splitlines()
    return [cell for line in lines if line.startswith("| ")
            and (cell := line.split("|")[1].strip()) not in ("Comprobación", "---")]


def _madrid_now():
    try:
        return datetime.now(ZoneInfo("Europe/Madrid")).isoformat(timespec="seconds")
    except ZoneInfoNotFoundError:
        if os.name != "nt":
            raise ValueError("El sistema no dispone de la zona horaria Europe/Madrid.") from None
        # Windows ofrece las reglas de Madrid en su registro nativo de zonas horarias.
        cmd = ("[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow, 'Romance Standard Time')"
               ".ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture)")
        return subprocess.check_output(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", cmd],
                                       text=True).strip()


def _window_id(group):
    fields = ("x", "y", "mision", "accion", "pnj")
    points = [[point.get(field) for field in fields] for point in group["destinos"]]
    return json.dumps([group["mapa"], *points], separators=(",", ":"))


def _learning_state(claim, records, client_pairs):
    pair = f"{claim['mision']}/{claim['hechizo']}"
    states = set(claim["rutas_por_estado"])
    if (states and states <= LEARNING_CONFIRMED) or ("6.aprendizaje", pair) in records:
        return "confirmada"
    if states & LEARNING_CONTRASTED:
        return "parcial"
    return "cliente" if pair in client_pairs else "investigacion"


def measure(routes, findings, catalog, inventory, flights, clustering, regression, root, records):
    missions = [row for row in inventory["misiones"] if row["rutas"]]
    routes_by_id = {route["id"]: route for route in routes if route.get("id")}
    documents = root / "auditor_fase13"
    inventory_text = (documents / "INVENTARIO_RUTAS.md").read_text(encoding="utf-8")
    expected_files = {route: path for path, route in re.findall(r"^\| \d+ \| `([^`]+)` \| `([^`]+)`", inventory_text, re.M)}
    route_files = {**expected_files, **{key: route["_archivo"] for key, route in routes_by_id.items()}}
    routes_ids = list(route_files)
    routes_failed = {row.get("archivo") for row in findings if row["bloque"] == 1 and row["gravedad"] == "error"}
    by_block = {block: [row for row in findings if row["bloque"] == block] for block in BLOCKS}

    def succeeds(block, codes=None):
        invalid = {row.get("archivo") for row in by_block[block]
                   if (codes is None and row["gravedad"] == "error")
                   or (codes is not None and row["codigo"] in codes)}
        return [key in routes_by_id and None not in invalid and file not in invalid | routes_failed
                for key, file in route_files.items()]

    def reviewed(key, units=None):
        if units is None:
            return [(key, unit) in records and unit in routes_by_id and route_files[unit] not in routes_failed
                    for unit in routes_ids]
        return [(key, unit) in records for unit in units]

    # La matriz del protocolo delimita los casos de oferta que dependen de contenido del cliente.
    client_path = documents / "VALIDACION_FOREVER.md"
    protocol = client_path.read_text(encoding="utf-8")
    conditional_ids = {int(q) for q in re.findall(r"^\| (\d+) \| \d+ \| Cliente [^|]",
                                                  protocol, re.M)}
    client_learning = {f"{quest}/{spell}" for quest, spell in
                       re.findall(r"^\| (\d+) \| (\d+) \| Cliente \|", protocol, re.M)}
    learning = inventory.get("aprendizaje_en_rutas", {}).get("declaraciones", [])
    learning_states = [_learning_state(row, records, client_learning) for row in learning]
    learning_family = family("Aprendizaje por misión y hechizo", learning_states, contrast=True)
    if learning_family:
        learning_family["confirmaciones_pendientes_cliente"] = sum(
            state != "confirmada" and f"{row['mision']}/{row['hechizo']}" in client_learning
            for row, state in zip(learning, learning_states))
    disputed_titles = {(row["mision"], "nombre_es" if row["codigo"] == "MISION_TITULO_ES_DISTINTO" else "nombre_en")
                       for row in by_block[2] if row.get("mision") and row["codigo"] in
                       ("MISION_TITULO_ES_DISTINTO", "MISION_TITULO_EN_DISTINTO")}
    disputed_titles.update((quest, "nombre_en") for row in by_block[2] if row["codigo"] == "MISION_TRADUCCION_EN_PENDIENTE"
                           for quest in row.get("misiones", []))

    def field_state(mission, field):
        status = _field_state(mission, field, mission["id"] in conditional_ids)
        return "parcial" if status == "confirmada" and (mission["id"], field) in disputed_titles else status

    def mission_fields(*fields):
        return [family(field, (field_state(mission, field) for mission in missions),
                       contrast=field in TWO_STAGE_FIELDS) for field in fields]

    def mission_reviews(key, fields, codes):
        unresolved = {route for mission in missions for route in mission["rutas"]
                      if any(field_state(mission, field) != "confirmada" for field in fields)}
        return [reviewed and valid and route not in unresolved for route, reviewed, valid in
                zip(routes_ids, reviewed(key), succeeds(2, codes))]

    def client_checks(key):
        checks = {task: reviewed(task) for task in CLIENT_TASKS[key]}
        closed = [all(results) for results in zip(*checks.values())]
        return closed, [family(task, (_state(ok, "cliente") for ok in values)) for task, values in checks.items()]

    map_family, mission_positions, other_positions, nodes = _coverage(routes, catalog, missions, flights)
    curve = _dict(catalog.get("xp_por_nivel"))
    thresholds = _dict(curve.get("niveles"))
    curve_family = family("Curva 1–60", (_state(_source(curve, "niveles") and _id(thresholds.get(str(lvl))))
                                        for lvl in range(1, 60)))
    practical_xp = family("Entregas con XP efectiva observada por ID", (_state(
        any(type(sample.get("xp")) is int and type(sample.get("level")) is int
            for sample in mission["evidencia"].get("entregas_observadas", {}).get("valor", [])), "cliente")
        for mission in missions if "T" in mission["acciones"]))
    combat_states, combat_covered = [], set()
    for route_id, route in routes_by_id.items():
        combat = _dict(_catalog_entry(catalog.get("xp_combates"), route_id).get("tramos"))
        coverage = []
        for index, _ in enumerate(route.get("secciones", []), 1):
            record = _dict(combat.get(str(index)))
            coverage.append(_state(_source(record, "xp") and type(record.get("xp")) is int and record["xp"] >= 0))
        combat_states.extend(coverage)
        if coverage and all(state == "confirmada" for state in coverage):
            combat_covered.add(route_id)

    travel_groups = clustering.get("candidatos", [])
    group_states = [_state(all(row["estado"] == "validacion_cliente" for row in group["apariciones"]))
                    for group in travel_groups]
    windows = [_window_id(group) for group in travel_groups]
    timed_states = [_state(("5.ahorro", key) in records, "cliente") for key in windows]
    untimed = {row["ruta"] for group, state in zip(travel_groups, timed_states) if state != "confirmada"
               for row in group["apariciones"]}

    core_ready = not any(row["codigo"] in ("motor-prueba-no-disponible", "motor-prueba-seleccion") for row in by_block[1])
    syntax = not any(row["codigo"].startswith(("toc-", "lua-compilacion")) for row in by_block[1])
    identity = ("existe", "nombre_es", "nombre_en")
    dependencies = ("nivel_minimo", "prerrequisitos", "prerrequisitos_alternativos", "seguimientos")
    conditions = ("excluyentes", "repetible", "objetos", "desbloqueos", "grupo", "elite", "mision_activa", "desactivada_por")
    cases = _client_cases(client_path)
    case_checks = reviewed("7.caso_cliente", cases)
    notes = (documents / "NOTAS_FASE13.md").read_text(encoding="utf-8")
    tests = regression.get("ejecutadas", 0)
    passed = regression.get("superadas", 0)
    packet_drafts = [bool(re.search(r"^## Español\n\n- \S", notes, re.M)),
                     bool(re.search(r"^## English\n\n- \S", notes, re.M)), bool(cases)]
    packet = [all(packet_drafts) and all(reviewed("7.paquete", ("final",)))]
    estimated = [success and mark and route in combat_covered for route, success, mark in zip(
        routes_ids, succeeds(4, {"xp_evidencia_incompleta"}), reviewed("4.estimacion"))]
    cartography_client, cartography_parts = client_checks("3.cliente")
    xp_client, xp_parts = client_checks("4.cliente")
    travel_client, travel_parts = client_checks("5.cliente")
    profile_client, profile_parts = client_checks("6.cliente")
    titles_conflicts = {"MISION_NO_EXISTE", "MISION_TITULO_ES_DISTINTO", "MISION_TITULO_EN_DISTINTO",
                        "MISION_TRADUCCION_EN_PENDIENTE"}
    order_conflicts = {"MISION_NIVEL_FUERA_DEL_TRAMO", "MISION_REQUISITO_ALTERNATIVO", "MISION_REQUISITO_FUERA_DE_RUTA",
                       "MISION_REQUISITO_ORDEN", "MISION_SEGUIMIENTO_ORDEN"}
    openings, alternatives = reviewed("5.desbloqueos"), reviewed("5.alternativas")
    transport_ok = [all(checks) for checks in zip(reviewed("5.transporte"), openings, alternatives,
                                                succeeds(5, {"viajes_fuente_pendiente", "vuelo_no_disponible"}))]
    cartography_ok = [reviewed and supported for reviewed, supported in zip(
        reviewed("3.posiciones"), succeeds(3, {"mapa_inexistente_forever", "posicion_descartada_forever", "posicion_difiere_forever"}))]

    criteria = [
        criterion("1.sintaxis", [syntax]), criterion("1.contrato", succeeds(1)),
        criterion("1.motor", [core_ready and good for good in succeeds(1)]),
        criterion("2.local", succeeds(2, MISSION_LOCAL)),
        criterion("2.identidad", mission_reviews("2.identidad", identity, titles_conflicts), mission_fields(*identity)),
        criterion("2.dependencias", mission_reviews("2.dependencias", dependencies, order_conflicts), mission_fields(*dependencies)),
        criterion("2.especiales", mission_reviews("2.especiales", conditions, {"MISION_EXCLUYENTE", "MISION_GRUPO_SIN_AVISO",
                                                                              "MISION_DISPONIBILIDAD_ORDEN"}),
                  mission_fields(*conditions, "objetos_objetivo")),
        criterion("3.local", succeeds(3, {"mapa_invalido", "coordenada_invalida", "pnj_invalido"})),
        criterion("3.posiciones", cartography_ok, (map_family, mission_positions, other_positions)),
        criterion("3.cliente", cartography_client, cartography_parts),
        criterion("4.local", succeeds(4, {"rango_niveles_invalido", "nivel_sin_tramo_automatico",
                                            "nivel_comprobacion_invalido", "nivel_fuera_de_tramo"})),
        criterion("4.estimacion", estimated, (*mission_fields("xp"), curve_family, family("XP de combate por tramo", combat_states))),
        criterion("4.cliente", xp_client, (*xp_parts, practical_xp)),
        criterion("5.local", succeeds(5, {"vuelo_invalido"})),
        criterion("5.transporte", transport_ok, (nodes,
                  family("Desbloqueos de transporte por ruta", map(_state, openings)),
                  family("Alternativas de transporte por ruta", map(_state, alternatives)))),
        criterion("5.cliente", [check and route not in untimed for route, check in zip(routes_ids, travel_client)], (
                  *travel_parts,
                  family("Contraste de las ventanas distintas", group_states),
                  family("Medición de las ventanas distintas en Forever", timed_states))),
        criterion("6.local", succeeds(6, {"PERFIL_FILTRO_RACIAL_INALCANZABLE", "PERFIL_RAMA_DE_TALENTO_INVALIDA"})),
        criterion("6.perfiles", succeeds(6, {row["codigo"] for row in by_block[6]
                                             if row["codigo"].startswith(("ARRANQUE_", "PERFIL_MATRIZ_", "PERFIL_NO_JUGABLE_", "PERFIL_SIN_RUTA"))})),
        criterion("6.cliente", profile_client, (*profile_parts, *mission_fields("clases", "razas", "facciones"), learning_family)),
        criterion("7.regresion", [tests > 0 and passed == tests and regression.get("correcta") is True],
                  (family("Pruebas locales", (_state(i < passed) for i in range(tests))),)),
        criterion("7.cliente", [bool(case_checks) and all(case_checks)], (
                  family("Casos del protocolo en Forever", (_state(ok, "cliente") for ok in case_checks)),)),
        criterion("7.paquete", packet, (family("Borradores ES, EN y protocolo", map(_state, packet_drafts)),)),
        criterion("7.sincronizacion", [all(packet) and all(case_checks) and all(reviewed("7.sincronizacion", ("final",)))]),
    ]
    by_id = {}
    for block, (_, weight) in BLOCKS.items():
        rows = [row for row in criteria if row["id"].startswith(f"{block}.")]
        passed, total = (sum(row[k] for row in rows) for k in ("completos", "aplicables"))
        by_id[str(block)] = {"peso": weight, "certificado": [passed, total],
                             "efectivo": _pair(sum(Fraction(*row["efectivo"]) * row["aplicables"] for row in rows) / total
                                               if total else Fraction()),
                             "criterios": rows, "pendientes_por_via": _pending(by_block[block])}
    return {"bloques": by_id, "global": _global(by_id), "regresion": regression, "casos_cliente": cases,
            "ventanas_agrupamiento": windows, "pendientes_por_via": _pending(findings),
            "rutas": len(routes), "misiones_activas": len(missions)}


def _pending(findings):
    counts = Counter(row.get("resolucion") for row in findings if row["gravedad"] == "pendiente")
    return {"investigacion": counts["investigación"], "cliente": counts["cliente"]}


def _ratio(pair):
    return Fraction(*pair) if pair and pair[1] else Fraction()


def _global(blocks):
    return {key: _pair(sum(_ratio(row[key]) * row["peso"] for row in blocks.values()) / 100)
            if all(row[key] is not None for row in blocks.values()) else None
            for key in ("certificado", "efectivo")}


def _comparison_snapshot(data):
    return {**{key: {name: row[name] for name in ("certificado", "efectivo")}
               for key, row in data["bloques"].items()}, "global": data["global"]}


def compare(current, previous=None):
    comparable = (previous or {}).get("version") == SCHEMA
    if comparable and previous["actual"] == current:
        return previous
    if comparable:
        baseline = _comparison_snapshot(previous["actual"])
    else:
        initial = {str(block): {"peso": weight, "certificado": list(PREVIOUS_CERTIFIED[block - 1]), "efectivo": None}
                   for block, (_, weight) in BLOCKS.items()}
        baseline = _comparison_snapshot({"bloques": initial, "global": _global(initial)})
    changes = {key: {metric: (_pair(_ratio(pair) - _ratio(baseline[key][metric]))
                              if baseline[key][metric] is not None else None)
                     for metric, pair in row.items()}
               for key, row in _comparison_snapshot(current).items()}
    return {"version": SCHEMA, "actualizado": _madrid_now(), "anterior": baseline,
            "actual": current, "variacion": changes}


def percentage(pair):
    if pair is None:
        return "—"
    value = _ratio(pair)
    rounded = round(float(value * 100), 2)
    if rounded == 100 and value < 1:
        rounded = 99.99
    return f"{rounded:.2f}".rstrip("0").rstrip(".").replace(".", ",") + " %"


def _delta(before, after):
    if before is None:
        return "—"
    change = round(float((_ratio(after) - _ratio(before)) * 100), 2)
    return (f"{change:+.2f}".rstrip("0").rstrip(".").replace(".", ",") if change else "0") + " pp"


def render(data):
    actual, previous = data["actual"], data["anterior"]
    lines = []
    for field, label in (("certificado", "certificado"), ("efectivo", "efectivo")):
        pair = actual["global"][field]
        bar = int(_ratio(pair) * 20)
        lines.extend([f"**Progreso {label} global · {percentage(pair)}**", "",
                      "`" + "█" * bar + "░" * (20 - bar) + "`", ""])
    lines.extend(["| Bloque | Peso | Criterios completos | Certificado anterior | Certificado actual | Variación | Efectivo anterior | Efectivo actual | Variación |",
                  "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"])
    for index, (name, weight) in BLOCKS.items():
        key = str(index)
        row = actual["bloques"][key]
        lines.append(_table_row(name, weight, "/".join(map(str, row["certificado"])), previous[key], row))
    lines += [_table_row("**Global ponderado**", 100, "", previous["global"], actual["global"]), "",
              f"**Última actualización de la medición · {data['actualizado'].replace('T', ' ')} (Madrid)**", ""]
    pending = actual["pendientes_por_via"]
    lines.extend([f"El auditor registra **{pending['investigacion']} grupos de investigación** y "
                  f"**{pending['cliente']} grupos de validación en Forever**. Las coberturas por criterio "
                  "están en `progreso_medicion.json`."])
    if not actual["regresion"]:
        lines.extend(["", "La regresión no se ejecutó en este informe de consulta."])
    return "\n".join(lines)


def _table_row(name, weight, counts, before, current):
    cells = [name, f"{weight} %", counts]
    for field in ("certificado", "efectivo"):
        cells.extend((percentage(before[field]), percentage(current[field]), _delta(before[field], current[field])))
    return "| " + " | ".join(cells) + " |"


def update_section(text, marker, body):
    start, end = (f"<!-- {marker}:{edge} -->" for edge in ("inicio", "fin"))
    if text.count(start) != 1 or text.count(end) != 1 or text.index(start) > text.index(end):
        raise ValueError(f"Sección generada ausente o duplicada: {marker}.")
    left, _, suffix = text.partition(start)
    _, _, right = suffix.partition(end)
    return f"{left}{start}\n\n{body}\n\n{end}{right}"

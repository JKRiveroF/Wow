"""Prioriza el contraste de pares de objetivos dentro de un mismo paso."""

import argparse
import json
from pathlib import Path

from mission_rules import _confirmed
from world_rules import _catalog_entry, _dict, _id, _list, _position, _proximity


HERE = Path(__file__).resolve().parent
RELATIONS = ("prerrequisitos", "desbloqueos", "seguimientos", "excluyentes")


def _geometry(points):
    """Reproduce el umbral geométrico del bloque 5 con dos extremos fijos."""
    positions = [_position(point) for point in points]
    if any(position is None or point.get("raza") for position, point in zip(positions, points)):
        return None
    start, first, second, stop = positions
    if len({position[0] for position in positions}) != 1:
        return None
    middle = _proximity(first, second)
    original = _proximity(start, first) + middle + _proximity(second, stop)
    alternative = _proximity(start, second) + middle + _proximity(first, stop)
    saving = original - alternative
    if saving <= 10 or saving <= original * 0.2:
        return None
    key = tuple((position, point.get("q"), point.get("a"), point.get("npc"))
                for position, point in zip(positions, points))
    return key, original, alternative


def _relations(quest_pair, catalog):
    missing = []
    conflicts = []
    for quest, other in (quest_pair, quest_pair[::-1]):
        entry = _catalog_entry(catalog.get("misiones"), quest)
        for field in RELATIONS:
            source = _confirmed(entry, field)
            value = entry.get(field)
            if not source or not isinstance(value, list):
                missing.append({"mision": quest, "campo": field})
            elif other in value:
                conflicts.append({"mision": quest, "relacionada": other, "campo": field, "fuente": source})
    return missing, conflicts


def _record_acceptances(active, point):
    quest, action = point.get("q"), point.get("a")
    if not _id(quest) or action not in ("A", "T"):
        return
    limited_to = point.get("raza")
    for race, accepted in active.items():
        if not limited_to or limited_to == race:
            if action == "A":
                accepted.add(quest)
            else:
                accepted.discard(quest)


def _route_windows(route):
    """Conserva índices de ruta y estado A/T por perfil antes de cada objetivo."""
    active = {race: set() for race in (_list(route.get("razas")) or [None])}
    route_lines = _list(route.get("_lineas_pasos"))
    for section_index, section in enumerate(_list(route.get("secciones")), 1):
        lines = _list(route_lines[section_index - 1]) if section_index <= len(route_lines) else []
        for step_index, step in enumerate(_list(_dict(section).get("pasos")), 1):
            step = _dict(step)
            points = [_dict(point) for point in _list(step.get("wp"))]
            for index, point in enumerate(points):
                if 0 < index < len(points) - 2 and point.get("a") == "C":
                    following = points[index + 1]
                    quest_pair = (point.get("q"), following.get("q"))
                    if (following.get("a") == "C" and all(_id(q) for q in quest_pair)
                            and quest_pair[0] != quest_pair[1]):
                        result = _geometry(points[index - 1:index + 3])
                        if result:
                            missions = set(quest_pair)
                            missing = [{"raza": race, "misiones": sorted(missions - accepted)}
                                       for race, accepted in active.items() if not missions <= accepted]
                            yield quest_pair, result, {
                                "ruta": route.get("id"), "archivo": route.get("_archivo"),
                                "seccion": section_index, "paso": step_index,
                                "linea": lines[step_index - 1] if step_index <= len(lines) else None,
                                "destinos_intercambiados": [index + 1, index + 2],
                                "aceptaciones_no_demostradas": missing,
                                "paso_con_comprobacion": bool(step.get("comprobar")),
                                "paso_con_variantes_raciales": any(item.get("raza") for item in points),
                                "texto_paso": step.get("t"),
                            }
                _record_acceptances(active, point)


def analyze_clustering(routes, catalog):
    """Agrupa la misma ventana de destinos y mantiene los bloqueos de cada ruta."""
    candidates = {}
    for route in routes:
        for quest_pair, (key, original, alternative), occurrence in _route_windows(route):
            if key not in candidates:
                missing, conflicts = _relations(quest_pair, catalog)
                candidates[key] = {
                    "mapa": key[0][0][0], "misiones_intercambiadas": list(quest_pair),
                    "destinos": [{"x": position[1], "y": position[2], "mision": quest,
                                  "accion": action, "pnj": npc} for position, quest, action, npc in key],
                    "distancia_original": round(original, 3), "distancia_alternativa": round(alternative, 3),
                    "ahorro_geometrico": round(original - alternative, 3),
                    "reduccion_pct": round((original - alternative) * 100 / original, 2),
                    "relaciones_sin_evidencia": missing, "relaciones_que_bloquean": conflicts,
                    "apariciones": [],
                }
            candidate = candidates[key]
            if candidate["relaciones_que_bloquean"] or candidate["relaciones_sin_evidencia"] or any(
                occurrence[field] for field in ("aceptaciones_no_demostradas", "paso_con_comprobacion",
                                                "paso_con_variantes_raciales")
            ):
                occurrence["estado"] = "investigacion"
            else:
                occurrence["estado"] = "validacion_cliente"
            candidate["apariciones"].append(occurrence)

    groups = sorted(candidates.values(), key=lambda candidate: -candidate["ahorro_geometrico"])
    appearances = [occurrence for candidate in groups for occurrence in candidate["apariciones"]]
    return {"rutas_con_candidatos": len({occurrence["ruta"] for occurrence in appearances}),
            "apariciones": len(appearances), "candidatos": groups}


def render_clustering(report):
    lines = ["# Agrupación de objetivos · seguimiento del bloque 5", "",
             f"{report['rutas_con_candidatos']} rutas · {report['apariciones']} apariciones · "
             f"{len(report['candidatos'])} ventanas distintas", "",
             "Cada ventana conserva los extremos y permuta sus dos objetivos internos dentro del mismo paso. "
             "La distancia se expresa en unidades del mapa normalizado 0–100. Los tiempos y el acceso por terreno "
             "quedan pendientes de un recorrido en Forever. El análisis no modifica las rutas.", ""]
    for candidate in report["candidatos"]:
        first, second = candidate["misiones_intercambiadas"]
        lines += [f"## UiMapID {candidate['mapa']} · {first} ↔ {second}", "",
                  f"Distancia {candidate['distancia_original']:.2f} → {candidate['distancia_alternativa']:.2f}, "
                  f"diferencia de {candidate['ahorro_geometrico']:.2f} ({candidate['reduccion_pct']:.2f} %). "
                  f"{len(candidate['apariciones'])} apariciones.", ""]
        if candidate["relaciones_sin_evidencia"]:
            lines += [f"Pendiente de investigación: {len(candidate['relaciones_sin_evidencia'])} campos "
                      "de relaciones entre misiones sin evidencia suficiente.", ""]
        for conflict in candidate["relaciones_que_bloquean"]:
            lines += [f"La misión {conflict['mision']} vincula a {conflict['relacionada']} en «{conflict['campo']}». "
                      f"[Evidencia]({conflict['fuente']})", ""]
        lines += ["| Ruta | Archivo y ubicación | Objetivos | Estado |",
                  "| --- | --- | --- | --- |"]
        for occurrence in candidate["apariciones"]:
            location = f"{occurrence['seccion']}.{occurrence['paso']}"
            if occurrence["linea"] is not None:
                location += f", línea {occurrence['linea']}"
            positions = " y ".join(map(str, occurrence["destinos_intercambiados"]))
            flags = []
            if occurrence["aceptaciones_no_demostradas"]:
                flags.append("revisar aceptaciones previas por raza")
            if occurrence["paso_con_comprobacion"]:
                flags.append("comprobación de paso")
            if occurrence["paso_con_variantes_raciales"]:
                flags.append("destinos de raza")
            status = "Investigar" if occurrence["estado"] == "investigacion" else "Probar en Forever"
            if flags:
                status += " · " + ", ".join(flags)
            lines.append(f"| {occurrence['ruta']} | `{occurrence['archivo']}` ({location}) | {positions} | {status} |")
        lines.append("")
    return "\n".join(lines)


def main():
    from catalogo import load_catalog
    from lua_routes import load_routes

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon", type=Path, default=HERE.parent / "GuiaAventurero")
    parser.add_argument("--catalogo", type=Path)
    parser.add_argument("--trazas-questie", type=Path)
    parser.add_argument("--datos-questie", type=Path)
    parser.add_argument("--datos-eg", type=Path)
    parser.add_argument("--salida", type=Path, default=HERE / "salida" / "agrupamientos")
    args = parser.parse_args()

    if args.salida.resolve().is_relative_to(args.addon.resolve()):
        parser.error("La salida debe quedar fuera del addon instalable.")
    routes, findings = load_routes(args.addon)
    if not routes or any(finding["gravedad"] == "error" for finding in findings):
        parser.error("El addon tiene errores de carga. Ejecuta auditar.py para localizarlos.")
    catalog = load_catalog(args.catalogo, args.trazas_questie, args.datos_questie, args.datos_eg)
    report = analyze_clustering(routes, catalog)
    args.salida.mkdir(parents=True, exist_ok=True)
    (args.salida / "AGRUPAMIENTOS.md").write_text(render_clustering(report), encoding="utf-8")
    data = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    (args.salida / "agrupamientos.json").write_text(data, encoding="utf-8")
    print(f"{report['apariciones']} apariciones en {len(report['candidatos'])} ventanas. Informe en {args.salida}.")


if __name__ == "__main__":
    main()

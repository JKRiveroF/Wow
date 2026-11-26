"""Auditor de las rutas de Guía del Aventurero, ejecutado fuera del addon."""

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

from catalogo import import_quest_v2, load_catalog
from arranques import audit_arranques
from estructura import audit_structure
from inventario_misiones import inventory_missions
from lua_routes import load_routes
from vuelos_observados import link_flights

HERE = Path(__file__).resolve().parent
BLOCKS = {1: "Estructura", 2: "Misiones", 3: "Cartografía", 4: "Experiencia",
          5: "Viajes", 6: "Clase, raza y facción"}
SEVERITIES = ("error", "aviso", "pendiente")
CLIENT_CHECKS = {"viajes_coste_cliente", "xp_real_cliente"}


def readable(value):
    return str(value).replace("\n", " ").replace("|", "\\|")


def render_findings(findings):
    if not findings:
        return "Sin hallazgos en las comprobaciones ejecutadas.\n"
    lines = ["| Bloque | Gravedad | Resolución | Código | Ubicación | Detalle |",
             "| ---: | --- | --- | --- | --- | --- |"]
    for result in findings:
        location = " · ".join(filter(None, [result.get("archivo"), result.get("ubicacion")]))
        fields = (result["bloque"], result["gravedad"], result.get("resolucion", ""),
                  result["codigo"], location, result["detalle"])
        lines.append("| " + " | ".join(map(readable, fields)) + " |")
    return "\n".join(lines) + "\n"


def report_version(addon):
    with (addon / "GuiaAventurero.toc").open(encoding="utf-8-sig") as toc:
        for line in toc:
            field, _, value = line.partition(":")
            if field.strip() == "## Version":
                return value.strip()
    return "desconocida"


def audit(addon, blocks, catalog, flight_reports=None):
    routes, findings = load_routes(addon)
    findings.extend(audit_structure(routes))
    invalid = {finding["archivo"] for finding in findings
               if finding["gravedad"] == "error" and finding.get("archivo")}
    eligible = [route for route in routes if route["_archivo"] not in invalid]
    if 5 in blocks and catalog.get("vuelos_observados"):
        flights = link_flights(eligible, catalog["vuelos_observados"])
        catalog = {**catalog, "vuelos_por_faccion": flights["nodos"]}
        if flight_reports is not None:
            flight_reports.update(flights)
    if 2 in blocks or 6 in blocks:
        from mission_rules import (audit_missions, audit_profile_matrix, audit_specializations,
                                   load_mission_badges, load_mission_localization)

        catalog = {**catalog, "_localizacion_addon": load_mission_localization(addon)}
        if 2 in blocks:
            groups = {int(quest) for quest, entry in catalog.get("misiones", {}).items()
                      if str(quest).isdigit() and (entry.get("elite") is True or entry.get("grupo") is True)}
            catalog["_etiquetas_addon"] = load_mission_badges(addon, groups) if groups else {}
        for route in eligible:
            if 2 in blocks:
                findings.extend(audit_missions(route, catalog))
            if 6 in blocks:
                findings.extend(audit_specializations(route, catalog))
                findings.extend(audit_arranques(route, catalog))
        if 6 in blocks:
            findings.extend(audit_profile_matrix(routes, catalog))
    if blocks.intersection({3, 4, 5}):
        from world_rules import audit_world

        for route in eligible:
            findings.extend(result for result in audit_world(route, catalog) if result["bloque"] in blocks)
    if 5 in blocks:
        from agrupamientos import analyze_clustering, clustering_findings

        findings.extend(clustering_findings(analyze_clustering(eligible, catalog)))
    for item in findings:
        if item["gravedad"] == "pendiente" and "resolucion" not in item:
            item["resolucion"] = "cliente" if item["codigo"] in CLIENT_CHECKS else "investigación"
    findings.sort(key=lambda item: (item["bloque"], SEVERITIES.index(item["gravedad"]),
                                    item.get("archivo") or "", item["codigo"], str(item.get("ubicacion", ""))))
    return routes, findings


def write_reports(output, version, blocks, routes, findings):
    route_output = output / "rutas"
    route_output.mkdir(parents=True, exist_ok=True)
    by_file = defaultdict(list)
    for finding in findings:
        by_file[finding.get("archivo")].append(finding)
    route_index = []
    manifest = []
    for number, route in enumerate(routes, 1):
        path = route["_archivo"]
        route_id = route.get("id")
        name = route.get("nombre") or path
        filename = f"{number:02d}-{Path(path).stem}.md"
        results = by_file.pop(path, [])
        totals = Counter(item["gravedad"] for item in results)
        pending = Counter(item["resolucion"] for item in results if "resolucion" in item)
        route_index.append(f"| [{readable(name)}](rutas/{filename}) | {readable(route_id)} | "
                           f"{totals['error']} | {totals['aviso']} | {totals['pendiente']} |")
        manifest.append({"id": route_id, "nombre": name, "archivo": path,
                         "faccion": route.get("_faccion"), "razas": route.get("razas"),
                         "clase": route.get("clase"), "hallazgos": dict(totals),
                         "pendientes_por_via": dict(pending)})
        (route_output / filename).write_text(
            f"# {name}\n\nVersión {version} · `{path}` · `{route_id}`\n\n"
            + render_findings(results), encoding="utf-8", newline="\n")

    summary = ["# Auditoría de rutas", "", f"Versión {version} · {len(routes)} rutas cargadas", "",
               "Los resultados corresponden al código ejecutado y a los datos de evidencia suministrados. "
               "Las pruebas de juego se registran por separado.", "",
               "| Bloque | Errores | Avisos | Pendientes |", "| --- | ---: | ---: | ---: |"]
    for block in sorted(blocks | {1}):
        totals = Counter(item["gravedad"] for item in findings if item["bloque"] == block)
        summary.append(f"| {BLOCKS[block]} | {totals['error']} | {totals['aviso']} | {totals['pendiente']} |")
    summary.extend(["", "## Resultados transversales y archivos sin ruta cargada", "",
                    render_findings([result for group in by_file.values() for result in group]),
                    "## Resultados por ruta", "", "| Ruta | ID | Errores | Avisos | Pendientes |",
                    "| --- | --- | ---: | ---: | ---: |", *route_index, ""])
    (output / "INFORME.md").write_text("\n".join(summary), encoding="utf-8", newline="\n")
    pending = Counter(item["resolucion"] for item in findings if "resolucion" in item)
    data = {"version": version, "bloques": sorted(blocks | {1}), "rutas": manifest, "hallazgos": findings,
            "pendientes_por_via": dict(pending)}
    (output / "resultados.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                                            encoding="utf-8", newline="\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon", type=Path, default=HERE.parent / "GuiaAventurero")
    parser.add_argument("--salida", type=Path, default=HERE / "salida")
    parser.add_argument("--catalogo", type=Path, help="Catálogo JSON opcional de evidencia por campo.")
    parser.add_argument("--trazas-questie", type=Path, help="Directorio local con las trazas de QuestieDB 1.1.6.")
    parser.add_argument("--datos-questie", type=Path, help="Directorio local con las reglas Forever de QuestieDB 1.1.6.")
    parser.add_argument("--datos-eg", type=Path, help="Directorio local con EG Link y QuestXP de Forever.")
    parser.add_argument("--questv2", type=Path, help="Tabla QuestV2 CSV de Forever 1.60.1.71139.")
    parser.add_argument("--bloque", action="append", type=int, choices=BLOCKS,
                        help="Bloque que ejecutar. Repetible. Por defecto ejecuta todos.")
    args = parser.parse_args()
    addon, output = args.addon.resolve(), args.salida.resolve()
    if output.is_relative_to(addon) or (output / "rutas").resolve().is_relative_to(addon):
        parser.error("La salida del auditor debe quedar fuera del addon instalable.")
    blocks = set(args.bloque or BLOCKS)
    try:
        version = report_version(addon)
        catalog = load_catalog(args.catalogo, args.trazas_questie, args.datos_questie, args.datos_eg)
        quest_v2 = import_quest_v2(args.questv2) if args.questv2 else None
        flights = {}
        routes, findings = audit(addon, blocks, catalog, flights)
        write_reports(output, version, blocks, routes, findings)
        if flights:
            (output / "vuelos_observados.json").write_text(
                json.dumps(flights, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        if 2 in blocks:
            missions = inventory_missions(routes, catalog, quest_v2)
            (output / "misiones_individuales.json").write_text(json.dumps(missions, ensure_ascii=False, indent=2) + "\n",
                                                               encoding="utf-8", newline="\n")
    except (OSError, ValueError) as error:
        print(f"Error del auditor: {error}", file=sys.stderr)
        return 2
    totals = Counter(item["gravedad"] for item in findings)
    print(f"{len(routes)} rutas | {totals['error']} errores | {totals['aviso']} avisos | "
          f"{totals['pendiente']} pendientes")
    print(output / "INFORME.md")
    return int(bool(totals["error"]))


if __name__ == "__main__":
    sys.exit(main())

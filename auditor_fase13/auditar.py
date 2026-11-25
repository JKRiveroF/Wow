"""Auditor de las rutas de Guía del Aventurero, ejecutado fuera del addon."""

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

from estructura import audit_structure
from lua_routes import load_routes

HERE = Path(__file__).resolve().parent
BLOCKS = {1: "Estructura", 2: "Misiones", 3: "Cartografía", 4: "Experiencia",
          5: "Viajes", 6: "Clase, raza y facción"}
SEVERITIES = ("error", "aviso", "pendiente")


def readable(value):
    return str(value).replace("\n", " ").replace("|", "\\|")


def render_findings(findings):
    if not findings:
        return "Sin hallazgos en las comprobaciones ejecutadas.\n"
    lines = ["| Bloque | Gravedad | Código | Ubicación | Detalle |",
             "| ---: | --- | --- | --- | --- |"]
    for result in findings:
        location = " · ".join(filter(None, [result.get("archivo"), result.get("ubicacion")]))
        fields = (result["bloque"], result["gravedad"], result["codigo"], location, result["detalle"])
        lines.append("| " + " | ".join(map(readable, fields)) + " |")
    return "\n".join(lines) + "\n"


def report_version(addon):
    with (addon / "GuiaAventurero.toc").open(encoding="utf-8-sig") as toc:
        for line in toc:
            field, _, value = line.partition(":")
            if field.strip() == "## Version":
                return value.strip()
    return "desconocida"


def audit(addon, blocks, catalog):
    routes, findings = load_routes(addon)
    findings.extend(audit_structure(routes))
    invalid = {finding["archivo"] for finding in findings
               if finding["gravedad"] == "error" and finding.get("archivo")}
    eligible = [route for route in routes if route["_archivo"] not in invalid]
    if 2 in blocks or 6 in blocks:
        from mission_rules import audit_missions, audit_specializations, load_mission_localization

        catalog = {**catalog, "_localizacion_addon": load_mission_localization(addon)}
        for route in eligible:
            if 2 in blocks:
                findings.extend(audit_missions(route, catalog))
            if 6 in blocks:
                findings.extend(audit_specializations(route, catalog))
    if blocks.intersection({3, 4, 5}):
        from world_rules import audit_world

        for route in eligible:
            findings.extend(result for result in audit_world(route, catalog) if result["bloque"] in blocks)
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
        route_index.append(f"| [{readable(name)}](rutas/{filename}) | {readable(route_id)} | "
                           f"{totals['error']} | {totals['aviso']} | {totals['pendiente']} |")
        manifest.append({"id": route_id, "nombre": name, "archivo": path,
                         "faccion": route.get("_faccion"), "razas": route.get("razas"),
                         "clase": route.get("clase"), "hallazgos": dict(totals)})
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
    data = {"version": version, "bloques": sorted(blocks | {1}), "rutas": manifest, "hallazgos": findings}
    (output / "resultados.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                                            encoding="utf-8", newline="\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon", type=Path, default=HERE.parent / "GuiaAventurero")
    parser.add_argument("--salida", type=Path, default=HERE / "salida")
    parser.add_argument("--catalogo", type=Path, help="Catálogo JSON opcional de evidencia por campo.")
    parser.add_argument("--bloque", action="append", type=int, choices=BLOCKS,
                        help="Bloque que ejecutar. Repetible. Por defecto ejecuta todos.")
    args = parser.parse_args()
    addon, output = args.addon.resolve(), args.salida.resolve()
    if output.is_relative_to(addon) or (output / "rutas").resolve().is_relative_to(addon):
        parser.error("La salida del auditor debe quedar fuera del addon instalable.")
    blocks = set(args.bloque or BLOCKS)
    try:
        version = report_version(addon)
        catalog = json.loads(args.catalogo.read_text(encoding="utf-8-sig")) if args.catalogo else {}
        if not isinstance(catalog, dict):
            parser.error("El catálogo debe ser un objeto JSON.")
        routes, findings = audit(addon, blocks, catalog)
        write_reports(output, version, blocks, routes, findings)
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

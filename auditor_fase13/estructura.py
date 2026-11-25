"""Comprobaciones del contrato de ruta que consume el motor del addon."""

import re
from collections import defaultdict


def sequence(value):
    """Una tabla Lua vacía puede llegar como lista o como diccionario."""
    if isinstance(value, list):
        return value
    if value == {}:
        return []
    return None


def text(value):
    return isinstance(value, str) and bool(value.strip())


def step_location(route, section, step):
    location = f"sección {section}, paso {step}"
    lines = route.get("_lineas_pasos", [])
    if 0 < section <= len(lines) and 0 < step <= len(lines[section - 1]):
        line = lines[section - 1][step - 1]
        if line:
            return f"línea {line} ({location})"
    return location


def audit_structure(routes):
    findings = []
    ids = defaultdict(list)
    selections = defaultdict(list)

    for route in routes:
        def report(code, detail, location=None, severity="error"):
            finding = {
                "bloque": 1, "gravedad": severity, "codigo": code,
                "archivo": route["_archivo"], "ruta": route.get("id"), "detalle": detail,
            }
            if location:
                finding["ubicacion"] = location
            findings.append(finding)

        route_id = route.get("id")
        if not text(route_id) or not re.fullmatch(r"[a-z0-9_]+", route_id):
            report("ID_RUTA_INVALIDO", "El ID debe ser un token válido para el selector de rutas.")
        else:
            ids[route_id].append(route["_archivo"])
        for field in ("nombre", "clase"):
            if not text(route.get(field)):
                report("CABECERA_INCOMPLETA", f"Falta el campo de texto {field}.")
        races = sequence(route.get("razas"))
        if not races or not all(text(race) for race in races) or len(set(races)) != len(races):
            report("RAZAS_INVALIDAS", "Se requiere una secuencia de tokens de raza distintos.")
        elif text(route_id) and text(route.get("clase")) and text(route.get("_faccion")):
            for race in races:
                selections[route["_faccion"], race, route["clase"]].append(route_id)
        for field in ("talentos", "profesiones"):
            if not isinstance(route.get(field), (dict, list)):
                report("DATOS_RUTA_INCOMPLETOS", f"El motor requiere una tabla {field}.")

        sections = sequence(route.get("secciones"))
        if not sections:
            report("SIN_SECCIONES", "El motor requiere una secuencia de secciones no vacía.")
            continue
        levels = set()
        previous_step = None
        for sec_number, section in enumerate(sections, 1):
            location = f"sección {sec_number}"
            if not isinstance(section, dict):
                report("SECCION_INVALIDA", "La sección debe ser una tabla con campos.", location)
                continue
            if not text(section.get("titulo")):
                report("TITULO_SECCION_INVALIDO", "La sección requiere un título.", location)
            start, end = section.get("min"), section.get("max")
            if type(start) is int and type(end) is int and 1 <= start <= end <= 60:
                levels.update(range(start, end + 1))
            else:
                report("RANGO_SECCION_INVALIDO", f"Rango de niveles inválido: {start} a {end}.", location)
            steps = sequence(section.get("pasos"))
            if not steps:
                report("SIN_PASOS", "La sección requiere una secuencia de pasos no vacía.", location)
                continue
            for step_number, step in enumerate(steps, 1):
                location = step_location(route, sec_number, step_number)
                if not isinstance(step, dict) or not text(step.get("t")):
                    report("TEXTO_PASO_INVALIDO", "El paso requiere texto para el motor.", location)
                    previous_step = None
                    continue
                if step == previous_step:
                    report("PASO_CONTIGUO_IGUAL", "El paso repite todos los datos del anterior.", location, "aviso")
                previous_step = step
                if "wp" in step:
                    waypoints = sequence(step["wp"])
                    if waypoints is None or any(not isinstance(wp, dict) for wp in waypoints):
                        report("DESTINOS_INVALIDOS", "wp debe ser una secuencia de tablas de destino.", location)
                checks = step.get("comprobar", {})
                if not isinstance(checks, dict) and checks != []:
                    report("COMPROBACION_INVALIDA", "comprobar debe ser una tabla de condiciones.", location)
        missing = sorted(set(range(1, 61)) - levels)
        if missing:
            report("HUECO_NIVELES_DECLARADOS", "No hay ningún tramo declarado para los niveles " + ", ".join(map(str, missing)) + ".")

    for route_id, files in ids.items():
        if len(files) > 1:
            findings.append({"bloque": 1, "gravedad": "error", "codigo": "ID_RUTA_DUPLICADO",
                             "archivo": files[0], "ruta": route_id, "detalle": "Registrado en " + ", ".join(files)})
    for selection, candidates in selections.items():
        if len(candidates) > 1:
            findings.append({"bloque": 1, "gravedad": "error", "codigo": "SELECCION_AMBIGUA",
                             "archivo": None, "ruta": None,
                             "detalle": f"{' / '.join(selection)} coincide con {', '.join(candidates)}."})
    return findings

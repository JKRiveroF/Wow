"""Carga el TOC y las rutas 1–60 en Lua 5.1 para la auditoría externa."""

import json
import re
from pathlib import Path, PurePosixPath

from lupa.lua51 import LuaError, LuaRuntime, lua_type


TOC = "GuiaAventurero.toc"
CORE = "GuiaAventurero.lua"
HORDA = {"Orc", "Troll", "Tauren", "Scourge"}
ENGINE_FUNCTIONS = ("ElegirRuta", "CargarRuta", "AdaptarARaza")


def _finding(code, file, detail, *, route=None, line=None, severity="error"):
    result = {
        "bloque": 1, "gravedad": severity, "codigo": code, "archivo": file,
        "ruta": route, "detalle": detail,
    }
    if line is not None:
        result["ubicacion"] = f"línea {line}"
    return result


def _toc_entries(addon, findings):
    files = {path.relative_to(addon).as_posix() for path in addon.rglob("*") if path.is_file()}
    toc = addon / TOC
    if not toc.resolve().is_relative_to(addon):
        findings.append(_finding("toc-ruta-externa", TOC, "El TOC apunta fuera del addon."))
        return
    try:
        lines = toc.read_text(encoding="utf-8-sig").splitlines()
    except (OSError, UnicodeError) as error:
        findings.append(_finding("toc-lectura", TOC, str(error)))
        return

    seen = set()
    registered = set()
    for line_no, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        entry = PurePosixPath(line.replace("\\", "/"))
        name = entry.as_posix()
        if entry.is_absolute() or ".." in entry.parts or ":" in name:
            findings.append(_finding("toc-ruta-invalida", TOC, name, line=line_no))
            continue
        if not (addon / name).resolve().is_relative_to(addon):
            findings.append(_finding("toc-ruta-externa", TOC, name, line=line_no))
            continue
        if name.casefold() in seen:
            findings.append(_finding("toc-entrada-duplicada", TOC, name, line=line_no))
            continue
        seen.add(name.casefold())
        if name not in files:
            findings.append(_finding("toc-archivo-ausente", TOC, name, line=line_no))
            continue
        if entry.suffix.lower() == ".xml":
            findings.append(_finding("toc-inclusion-xml", TOC, name, line=line_no, severity="pendiente"))
        if entry.suffix.lower() == ".lua":
            if entry.parts[0] == "Rutas":
                registered.add(name)
            yield line_no, name

    route_files = {name for name in files if name.startswith("Rutas/") and name.lower().endswith(".lua")}
    for name in sorted(route_files - registered):
        findings.append(_finding("ruta-fuera-toc", name, "Archivo de ruta sin entrada en el TOC."))


def _plain(value, table_id, active, converted):
    kind = lua_type(value)
    if kind is None:
        return value
    if kind != "table":
        raise ValueError(f"tipo de dato Lua no exportable: {kind}")
    identity = table_id(value)
    if identity in active:
        raise ValueError("referencia circular en los datos Lua")
    if identity in converted:
        return converted[identity]
    active.add(identity)
    entries = {}
    for key, item in value.items():
        if type(key) not in (str, int, float):
            raise ValueError(f"tipo de clave Lua no exportable: {type(key).__name__}")
        entries[key] = _plain(item, table_id, active, converted)
    active.remove(identity)
    if entries.keys() == set(range(1, len(entries) + 1)):
        converted[identity] = [entries[key] for key in range(1, len(entries) + 1)]
    else:
        converted[identity] = entries
    return converted[identity]


def _locate_steps(source, sections):
    """Devuelve líneas físicas si sus grupos concuerdan con las tablas ejecutadas."""
    if not isinstance(sections, list):
        return None
    region = re.search(r"^R\.secciones\s*=\s*\{[^\n]*\n(.*?)^\}", source, re.M | re.S)
    if region is None:
        return None
    offset = source.count("\n", 0, region.start(1)) + 1
    groups = []
    for line_no, line in enumerate(region[1].splitlines(), offset):
        if re.match(r"^\s*pasos\s*=\s*\{\s*$", line):
            groups.append([])
            continue
        literal = re.match(r'^\s*\{\s*t\s*=\s*("(?:[^"\\]|\\.)*")', line)
        if groups and literal:
            try:
                text = json.loads(literal[1])
            except json.JSONDecodeError:
                return None
            groups[-1].append((line_no, text))
    if len(groups) != len(sections):
        return None
    for section, lines in zip(sections, groups):
        steps = section.get("pasos") if isinstance(section, dict) else None
        if not isinstance(steps, list) or len(steps) != len(lines):
            return None
        if any(not isinstance(step, dict) or step.get("t") != text for step, (_, text) in zip(steps, lines)):
            return None
    return [[line_no for line_no, _ in lines] for lines in groups]


def _engine(addon, lua, harness, findings):
    try:
        core = addon / CORE
        if not core.resolve().is_relative_to(addon):
            raise ValueError("el núcleo apunta fuera del addon")
        source = core.read_text(encoding="utf-8-sig")
        pieces = []
        for name in ENGINE_FUNCTIONS:
            function = re.search(rf"^local function {name}\([^\n]*\)\n.*?^end\b", source, re.M | re.S)
            if function is None:
                raise ValueError(f"no se pudo extraer la función {name} del núcleo")
            pieces.append(function[0])
        pieces.append("return {" + ", ".join(f"{name} = {name}" for name in ENGINE_FUNCTIONS) + "}")
        chunk = lua.compile("\n".join(pieces), name=f"@{CORE} (funciones del motor)", mode="t")
        environment = harness.entorno_motor()
        return harness.ejecutar(harness.con_entorno(chunk, environment)), environment
    except (LuaError, OSError, ValueError) as error:
        findings.append(_finding("motor-prueba-no-disponible", CORE, str(error), severity="pendiente"))
        return None, None


def _load_one(addon, name, line, source, chunk, lua, harness, engine, environment, findings):
    raw_env = harness.entorno()
    harness.ejecutar(harness.con_entorno(chunk, raw_env), addon.name, lua.table())
    registry = raw_env.GuiaAventurero_Rutas
    if lua_type(registry) != "table" or set(registry.keys()) != {1} or lua_type(registry[1]) != "table":
        findings.append(_finding("ruta-registro", name, "El archivo debe registrar exactamente una ruta en el índice 1."))
        return None

    raw = registry[1]
    route_id = raw.id if isinstance(raw.id, str) else None
    engine_loaded = False
    if engine is not None:
        environment.GuiaAventurero_Rutas = registry
        environment.GL.erroresCarga = lua.table()
        engine_loaded = harness.ejecutar(engine.CargarRuta, raw)
        if not engine_loaded:
            detail = environment.GL.erroresCarga[1] or "El motor no aceptó los datos de la ruta."
            findings.append(_finding("motor-rechaza-ruta", name, detail, route=route_id))
    elif raw.cargar is not None:
        harness.ejecutar(raw.cargar, raw)
    raw.cargar = None
    route = _plain(raw, harness.identidad_de_tabla(), set(), {})
    if not isinstance(route, dict):
        findings.append(_finding("ruta-sin-cabecera", name, "La tabla registrada no contiene una cabecera.", route=route_id))
        return None

    races = route.get("razas")
    faction = route.get("faccion")
    if faction is None and isinstance(races, list) and races and isinstance(races[0], str) and races[0] != "Skyborne":
        faction = "Horde" if races[0] in HORDA else "Alliance"
    route.update(_archivo=name, _linea_toc=line, _faccion=faction)
    step_lines = _locate_steps(source, route.get("secciones"))
    if step_lines is not None:
        route["_lineas_pasos"] = step_lines
    if engine_loaded and isinstance(races, list):
        for race in races:
            if not isinstance(race, str):
                continue
            environment.raza = race
            try:
                problem = harness.comprobar_filtro(engine.AdaptarARaza, raw, race)
            except LuaError as error:
                problem = str(error)
            if problem:
                findings.append(_finding("motor-filtro-raza", name, f"{race}: {problem}", route=route_id))
    return route


def _check_selection(routes, lua, harness, engine, environment, findings):
    headers = []
    for route in routes:
        header = {key: route[key] for key in ("id", "clase", "razas", "faccion") if key in route}
        headers.append(lua.table_from(header, recursive=True))
    environment.GuiaAventurero_Rutas = lua.table_from(headers)
    for route, expected in zip(routes, headers):
        route_id, faction = route.get("id"), route["_faccion"]
        if not isinstance(route_id, str) or not isinstance(route.get("razas"), list):
            continue
        for race in route["razas"]:
            if not isinstance(race, str):
                continue
            environment.raza, environment.clase, environment.faccion = race, route.get("clase"), faction
            selected = harness.ejecutar(engine.ElegirRuta)
            selected_id = None if selected is None else selected.id
            if not harness.misma_tabla(selected, expected):
                findings.append(_finding(
                    "motor-seleccion-ruta", route["_archivo"],
                    f"Con {race}, {environment.clase} y {faction} el motor selecciona {selected_id!r}.",
                    route=route_id,
                ))


def load_routes(addon: Path) -> tuple[list[dict], list[dict]]:
    """Compila módulos del TOC y extrae datos e incidencias de las rutas registradas."""
    addon = addon.resolve()
    lua = LuaRuntime(register_eval=False, register_builtins=False, max_memory=128 * 1024 * 1024)
    harness_source = Path(__file__).with_name("entorno_lua.lua").read_text(encoding="utf-8")
    harness = lua.execute(harness_source, name="@entorno_lua.lua", mode="t")
    routes, findings = [], []
    engine, environment = _engine(addon, lua, harness, findings)
    for line, name in _toc_entries(addon, findings):
        try:
            source = (addon / name).read_text(encoding="utf-8-sig")
            chunk = lua.compile(source, name=f"@{name}", mode="t")
        except (LuaError, OSError, UnicodeError) as error:
            findings.append(_finding("lua-compilacion", name, str(error)))
            continue
        if name.startswith("Rutas/"):
            try:
                route = _load_one(addon, name, line, source, chunk, lua, harness, engine, environment, findings)
            except (LuaError, ValueError, RecursionError) as error:
                findings.append(_finding("ruta-carga", name, str(error)))
            else:
                if route is not None:
                    routes.append(route)
    if engine is not None:
        try:
            _check_selection(routes, lua, harness, engine, environment, findings)
        except (LuaError, ValueError) as error:
            findings.append(_finding("motor-prueba-seleccion", CORE, str(error)))
    return routes, findings

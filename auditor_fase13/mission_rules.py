"""Reglas de misiones y perfiles de la guía de leveo."""

from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import re
import unicodedata


PREFIXES = {"Recoger": "A", "Objetivo": "C", "Entregar": "T"}
CONFIRMED = {"forever", "cliente"}
PHASE_TWO_FIELDS = (
    "existe", "nombre_es", "nombre_en", "nivel_minimo", "prerrequisitos", "excluyentes",
    "seguimientos", "repetible", "objetos", "desbloqueos", "grupo", "elite",
)
PHASE_SIX_FIELDS = ("clases", "razas", "facciones")
QUEST_TAGS = {"Elite": "ÉLITE", "Dungeon": "MAZMORRA", "Raid": "BANDA"}


@dataclass(frozen=True)
class MissionPoint:
    quest: int
    action: str
    section: int
    step: int
    point: int
    maximum: int | None
    guide_text: str
    waypoint: dict

    @property
    def location(self):
        return f"Sección {self.section}, paso {self.step}, destino {self.point}"


def _issue(route, block, severity, code, detail, location=None, source=None):
    item = {
        "bloque": block,
        "gravedad": severity,
        "codigo": code,
        "archivo": route.get("_archivo"),
        "ruta": route.get("id"),
        "detalle": detail,
    }
    if location is not None:
        item["ubicacion"] = location
    if source:
        item["fuente"] = source
    return item


def _list(value):
    return value if isinstance(value, list) else []


def _id(value):
    if isinstance(value, int) and not isinstance(value, bool) and value > 0:
        return value
    if isinstance(value, float) and value.is_integer() and value > 0:
        return int(value)
    return None


def _waypoints(route):
    for si, section in enumerate(_list(route.get("secciones")), 1):
        if not isinstance(section, dict):
            continue
        for pi, step in enumerate(_list(section.get("pasos")), 1):
            if not isinstance(step, dict):
                continue
            for wi, waypoint in enumerate(_list(step.get("wp")), 1):
                if isinstance(waypoint, dict):
                    yield si, pi, wi, section, step, waypoint


def _mission_title(waypoint):
    name = waypoint.get("n")
    if not isinstance(name, str):
        return None, None
    prefix, _, label = name.partition(": ")
    if prefix not in PREFIXES or not label.strip():
        return None, None
    match = re.fullmatch(r"(.+) \(([^()]+)\)", label) or re.fullmatch(r"(.+?) \((.+)\)", label)
    return prefix, match[1] if match else label


def _collect(route, issues):
    for section, step, index, section_data, step_data, waypoint in _waypoints(route):
        if "q" not in waypoint and "a" not in waypoint:
            continue
        quest = _id(waypoint.get("q"))
        action = waypoint.get("a")
        location = f"Sección {section}, paso {step}, destino {index}"
        if quest is None or action not in ("A", "C", "T"):
            issues.append(_issue(route, 2, "error", "MISION_DESTINO_INVALIDO", (
                f"q={waypoint.get('q')!r}, a={action!r}. El motor necesita un ID positivo "
                "y una acción A (aceptar), C (objetivos) o T (entregar)."
            ), location))
            continue
        prefix, _ = _mission_title(waypoint)
        if prefix is not None and PREFIXES[prefix] != action:
            issues.append(_issue(route, 2, "error", "MISION_ACCION_ETIQUETA_DISTINTA", (
                f"Misión {quest}: la etiqueta indica «{prefix}» y el motor aplica {action}."
            ), location))
        guide_text = " ".join(value for name in ("t", "nota", "notaDespues")
                              if isinstance(value := step_data.get(name), str))
        yield MissionPoint(quest, action, section, step, index, _id(section_data.get("max")),
                           guide_text, waypoint)


def _entry(catalog, quest):
    missions = catalog.get("misiones", {})
    if not isinstance(missions, dict):
        return {}
    item = missions.get(str(quest), missions.get(quest, {}))
    return item if isinstance(item, dict) else {}


def _evidence(entry, field):
    fields = entry.get("evidencia")
    if not isinstance(fields, dict):
        record = entry
    elif field.startswith("nombre_"):
        record = fields.get(field, fields.get("nombres"))
    else:
        record = fields.get(field)
    if not isinstance(record, dict) or not record.get("fuente"):
        return None, None
    return record.get("estado"), record["fuente"]


def _confirmed(entry, field):
    status, source = _evidence(entry, field)
    if not isinstance(status, str) or status not in CONFIRMED:
        return None
    if field.startswith("nombre_"):
        names = entry.get("nombres")
        return source if isinstance(names, dict) and _variants(names.get(field[-2:])) else None
    return source if field in entry else None


def _norm(name):
    text = unicodedata.normalize("NFKD", name.casefold())
    return "".join(char for char in text if char.isalnum())


def _variants(names):
    if isinstance(names, str):
        return [names]
    return [name for name in _list(names) if isinstance(name, str) and name.strip()]


def _titles(route, first, points, entry, localization):
    issues = []
    labels = {}
    for point in points:
        _, title = _mission_title(point.waypoint)
        if title and point.action in ("A", "T"):
            labels.setdefault(_norm(title), (title, point))

    names = entry.get("nombres", {})
    if not isinstance(names, dict):
        names = {}
    known_es = _variants(names.get("es"))
    known_en = _variants(names.get("en"))
    own_names = route.get("nombresPropios", {})
    aliases = own_names.get(first.quest, own_names.get(str(first.quest), [])) if isinstance(own_names, dict) else []
    guide_aliases = _variants(entry.get("alias_es_guia"))
    allowed = {_norm(name) for name in [*known_es, *known_en, *_variants(aliases), *guide_aliases]}

    local_by_id = localization.get("por_id", {})
    local_by_name = localization.get("por_nombre", {})
    local_title = local_by_id.get(first.quest)
    if isinstance(local_title, str) and not known_en:
        allowed.add(_norm(local_title))
    source = _confirmed(entry, "nombre_es")
    if source:
        for normalized, (title, point) in labels.items():
            if normalized not in allowed:
                issues.append(_issue(route, 2, "aviso", "MISION_TITULO_ES_DISTINTO", (
                    f"Misión {first.quest}: «{title}» difiere de los títulos de referencia «{', '.join(known_es)}»."
                ), point.location, source))
    source = _confirmed(entry, "nombre_en")
    if source:
        expected_en = {_norm(name) for name in known_en}
        if local_title and _norm(local_title) not in expected_en:
            issues.append(_issue(route, 2, "aviso", "MISION_TITULO_EN_DISTINTO", (
                f"Misión {first.quest}: el título inglés «{local_title}» difiere de «{', '.join(known_en)}»."
            ), first.location, source))

    missing_english = False
    if localization and not localization.get("errores") and not local_title:
        known_en_normalized = {_norm(name) for name in known_en}
        missing_english = any(title not in local_by_name and key not in known_en_normalized
                              for key, (title, _) in labels.items())
    return issues, missing_english


def _for_race(points, race):
    return [point for point in points if point.waypoint.get("raza") in (None, race)]


def _coverage(quests, catalog, fields):
    missing = {}
    for field in fields:
        count = sum(not _confirmed(_entry(catalog, quest), field) for quest in quests)
        if count:
            missing[field] = count
    return missing


def _coverage_issue(route, block, code, coverage, total):
    detail = ", ".join(f"{field} {count}/{total}" for field, count in coverage.items())
    item = _issue(route, block, "pendiente", code, "Misiones sin confirmación por campo: " + detail + ".")
    item["cobertura_pendiente"] = coverage
    return item


def _point_sequence(route, events, race, catalog):
    issues = []
    seen = set()
    accepted, turned_in = set(), set()
    planned_acceptances = {point.quest for point in events if point.action == "A"}
    planned_turn_ins = {point.quest for point in events if point.action == "T"}
    first_acceptance = {}
    alternatives_by_quest = defaultdict(set)
    for index, point in enumerate(events):
        if point.action == "A":
            first_acceptance.setdefault(point.quest, index)
        alternatives_by_quest[point.quest].add(_id(point.waypoint.get("alternativa")))
    incompatibilities = set()
    variant = f" ({race})" if len(_list(route.get("razas"))) > 1 else ""

    for point in events:
        quest = point.quest
        entry = _entry(catalog, quest)
        repeatable = entry.get("repetible") is True and _confirmed(entry, "repetible")
        marker = tuple(repr(point.waypoint.get(field)) for field in ("m", "x", "y", "n"))
        key = (quest, point.action, marker)
        if point.action == "C":
            key = (point.section, point.step, *key)
        if key in seen and not repeatable:
            issues.append(_issue(route, 2, "aviso", "MISION_DESTINO_REPETIDO", (
                f"Misión {quest}: se repite la acción {point.action} en el mismo punto{variant}."
            ), point.location))
        seen.add(key)

        if point.action != "A":
            if quest in planned_acceptances and quest not in accepted:
                issues.append(_issue(route, 2, "aviso", "MISION_ORDEN_ACCION", (
                    f"Misión {quest}: la acción {point.action} figura antes de la aceptación de la ruta{variant}."
                ), point.location))
            elif point.action == "C" and quest in turned_in and not repeatable:
                issues.append(_issue(route, 2, "aviso", "MISION_ORDEN_ACCION", (
                    f"Misión {quest}: hay un objetivo después de la entrega{variant}."
                ), point.location))
            if point.action == "T":
                turned_in.add(quest)
            continue

        if quest in accepted:
            continue
        accepted.add(quest)
        requirement = _id(entry.get("nivel_minimo"))
        source = _confirmed(entry, "nivel_minimo")
        if requirement and source and point.maximum is not None and requirement > point.maximum:
            issues.append(_issue(route, 2, "aviso", "MISION_NIVEL_FUERA_DEL_TRAMO", (
                f"Misión {quest}: exige nivel {requirement} y este tramo termina en {point.maximum}{variant}."
            ), point.location, source))

        for field in ("prerrequisitos", "desbloqueos"):
            source = _confirmed(entry, field)
            if not source:
                continue
            for required in _list(entry.get(field)):
                if _id(required) is None or required in turned_in:
                    continue
                in_route = required in planned_turn_ins
                code = "MISION_REQUISITO_ORDEN" if in_route else "MISION_REQUISITO_FUERA_DE_RUTA"
                context = "se entrega después" if in_route else "no tiene entrega en esta ruta"
                issues.append(_issue(route, 2, "aviso", code, (
                    f"Misión {quest}: el requisito obligatorio {required} {context}{variant}."
                ), point.location, source))

        source = _confirmed(entry, "prerrequisitos_alternativos")
        alternatives = {value for required in _list(entry.get("prerrequisitos_alternativos"))
                        if (value := _id(required)) is not None}
        if source and alternatives and alternatives.isdisjoint(turned_in):
            available_later = alternatives & planned_turn_ins
            detail = "la ruta solo entrega opciones después" if available_later else "la ruta carece de las entregas alternativas"
            names = ", ".join(map(str, sorted(alternatives)))
            issues.append(_issue(route, 2, "aviso", "MISION_REQUISITO_ALTERNATIVO", (
                f"Misión {quest}: se necesita una entrega entre {names} y {detail}{variant}."
            ), point.location, source))

        source = _confirmed(entry, "excluyentes")
        if source:
            for incompatible in _list(entry.get("excluyentes")):
                if _id(incompatible) is None or incompatible == quest or incompatible not in planned_acceptances:
                    continue
                if alternatives_by_quest[quest] == {incompatible} and alternatives_by_quest[incompatible] == {quest}:
                    continue
                pair = frozenset((quest, incompatible))
                if pair not in incompatibilities:
                    incompatibilities.add(pair)
                    issues.append(_issue(route, 2, "aviso", "MISION_EXCLUYENTE", (
                        f"La ruta incluye la aceptación de las misiones excluyentes {quest} y {incompatible}{variant}."
                    ), point.location, source))

    for index, point in enumerate(events):
        if point.action != "T":
            continue
        entry = _entry(catalog, point.quest)
        source = _confirmed(entry, "seguimientos")
        if not source:
            continue
        for next_quest in _list(entry.get("seguimientos")):
            if _id(next_quest) is None:
                continue
            accepted_early = first_acceptance.get(next_quest, index) < index
            if accepted_early:
                issues.append(_issue(route, 2, "aviso", "MISION_SEGUIMIENTO_ORDEN", (
                    f"La ruta propone aceptar la misión de seguimiento {next_quest} antes de entregar {point.quest}{variant}."
                ), point.location, source))

    return issues


def audit_missions(route: dict, catalog: dict) -> list[dict]:
    """Valida misiones de la ruta en el orden en que las consume el addon."""
    issues = []
    events = list(_collect(route, issues))
    by_quest = defaultdict(list)
    for point in events:
        by_quest[point.quest].append(point)

    untranslated = []
    localization = catalog.get("_localizacion_addon", {})
    badges = catalog.get("_etiquetas_addon", {})
    for quest, points in by_quest.items():
        entry = _entry(catalog, quest)
        first = points[0]
        source = _confirmed(entry, "existe")
        if source and entry["existe"] is False:
            issues.append(_issue(route, 2, "error", "MISION_NO_EXISTE", (
                f"La fuente marca la misión {quest} como inexistente en WoW Forever."
            ), first.location, source))
        title_issues, missing_english = _titles(route, first, points, entry, localization)
        for issue in title_issues:
            issue["mision"] = quest
        issues.extend(title_issues)
        if missing_english:
            untranslated.append(quest)

        group = ("grupo" if entry.get("grupo") is True and _confirmed(entry, "grupo") else
                 "elite" if entry.get("elite") is True and _confirmed(entry, "elite") else None)
        category = QUEST_TAGS.get(entry.get("tipo_mision"))
        badge = badges.get(quest, "")
        label_matches = category in badge if category else bool(re.search(r"GRUPO|ÉLITE|MAZMORRA|BANDA", badge))
        if group and not label_matches and not any(
            re.search(r"grupo|[eé]lite|mazmorra|banda", point.guide_text, re.I) for point in points
        ):
            issues.append(_issue(route, 2, "aviso", "MISION_GRUPO_SIN_AVISO", (
                f"Misión {quest}: la fuente la marca como {'de grupo' if group == 'grupo' else 'de élite'} "
                "y la guía no muestra una etiqueta o indicación correspondiente."
            ), first.location, _confirmed(entry, group)))
            issues[-1]["mision"] = quest

    if untranslated:
        sample = ", ".join(str(quest) for quest in untranslated[:12])
        issues.append(_issue(route, 2, "pendiente", "MISION_TRADUCCION_EN_PENDIENTE", (
            f"{len(untranslated)} misiones requieren comprobar el título que muestra el addon en inglés. "
            f"Sin entrada de traducción aplicable en el TOC ni título de referencia que coincida. IDs iniciales: {sample}."
        )))
        issues[-1]["misiones"] = untranslated

    for race in _list(route.get("razas")) or [None]:
        issues.extend(_point_sequence(route, _for_race(events, race), race, catalog))

    coverage = _coverage(by_quest, catalog, PHASE_TWO_FIELDS)
    if coverage:
        issues.append(_coverage_issue(route, 2, "MISION_FUENTES_INCOMPLETAS", coverage, len(by_quest)))
    return issues


def audit_specializations(route: dict, catalog: dict) -> list[dict]:
    """Comprueba filtros raciales, ramas de talentos y requisitos de personaje."""
    issues = []
    races = _list(route.get("razas"))
    places = [(f"Sección {si}, paso {pi}, destino {wi}", waypoint)
              for si, pi, wi, _, _, waypoint in _waypoints(route)]
    for field in ("entrenamiento", "hechizosExtra"):
        places.extend((f"{field}[{index}]", point) for index, point in enumerate(_list(route.get(field)), 1)
                      if isinstance(point, dict))
    for location, point in places:
        race = point.get("raza")
        if race is not None and race not in races:
            issues.append(_issue(route, 6, "error", "PERFIL_FILTRO_RACIAL_INALCANZABLE", (
                f"El filtro exige la raza {race!r}, que no figura en esta ruta. El motor descarta esta entrada."
            ), location))

    branches = {branch.get("nombre") for branch in _list(route.get("ramas")) if isinstance(branch, dict)
                and isinstance(branch.get("nombre"), str)}
    for index, talent in enumerate(_list(route.get("talentos")), 1):
        if isinstance(talent, dict) and not isinstance(talent.get("rama"), str):
            issues.append(_issue(route, 6, "error", "PERFIL_RAMA_DE_TALENTO_INVALIDA", (
                f"El talento «{talent.get('nombre')}» carece de rama de talentos reconocible."
            ), f"talentos[{index}]"))
        elif isinstance(talent, dict) and talent["rama"] not in branches:
            issues.append(_issue(route, 6, "error", "PERFIL_RAMA_DE_TALENTO_INVALIDA", (
                f"La rama «{talent['rama']}» del talento «{talent.get('nombre')}» no está en R.ramas."
            ), f"talentos[{index}]"))

    events = list(_collect(route, []))
    quests = {event.quest for event in events}
    for race in races or [None]:
        checked = set()
        for point in _for_race(events, race):
            if point.quest in checked:
                continue
            checked.add(point.quest)
            entry = _entry(catalog, point.quest)
            faction_races = entry.get("razas_por_faccion")
            for field, value in (("clases", route.get("clase")), ("razas", race),
                                 ("facciones", route.get("_faccion"))):
                source = _confirmed(entry, field)
                allowed = _list(entry.get(field))
                if field == "razas" and allowed and isinstance(faction_races, dict):
                    allowed = _list(faction_races.get(route.get("_faccion"), allowed))
                if source and allowed and value not in allowed:
                    issues.append(_issue(route, 6, "aviso", "PERFIL_REQUISITO_DE_MISION", (
                        f"Misión {point.quest}: {field} admitidos {', '.join(map(str, allowed))}, "
                        f"pero este perfil usa {value}."
                    ), point.location, source))

    coverage = _coverage(quests, catalog, PHASE_SIX_FIELDS)
    if coverage:
        issues.append(_coverage_issue(route, 6, "PERFIL_REQUISITOS_PENDIENTES", coverage, len(quests)))
    return issues


def audit_profile_matrix(routes: list[dict], catalog: dict) -> list[dict]:
    """Compara las selecciones declaradas con las combinaciones jugables en Forever."""
    matrix = catalog.get("perfiles", {})
    source = _confirmed(matrix, "facciones")
    if not source:
        return [_issue({}, 6, "pendiente", "PERFIL_MATRIZ_SIN_FUENTE",
                       "Falta una matriz de combinaciones jugables con evidencia de Forever.")]
    expected = {(faction, race, class_token)
                for faction, races in matrix["facciones"].items()
                for race, classes in races.items()
                for class_token in classes}
    observed = set()
    issues = []
    for route in routes:
        faction, class_token = route.get("_faccion"), route.get("clase")
        for race in _list(route.get("razas")):
            profile = (faction, race, class_token)
            observed.add(profile)
            if profile not in expected:
                issues.append(_issue(route, 6, "error", "PERFIL_NO_JUGABLE_EN_FOREVER", (
                    f"La combinación {faction}, {race}, {class_token} no figura en la matriz oficial."
                ), "Cabecera de la ruta", source))

    for faction, race, class_token in sorted(expected - observed):
        issues.append(_issue({}, 6, "error", "PERFIL_SIN_RUTA", (
            f"No hay ruta para {faction}, {race}, {class_token}, combinación jugable en Forever."
        ), source=source))
    return issues


def load_mission_localization(addon: Path) -> dict:
    """Lee las tablas EN del TOC con la precedencia que aplica Idioma.lua."""
    from lupa.lua51 import LuaRuntime

    runtime = LuaRuntime(register_eval=False, register_builtins=False)
    load = runtime.eval(r'''
        function (files)
            local texts, quests, deferred, errors = {}, {}, {}, {}
            local function assign(target, values, overwrite)
                for k, v in pairs(values) do
                    if (type(k) == "number" or type(k) == "string") and type(v) == "string"
                     and (overwrite or target[k] == nil) then target[k] = v end
                end
            end
            local function register(values, purpose)
                local target = purpose == "misiones" and quests or texts
                if type(values) == "table" then assign(target, values, true)
                elseif type(values) == "string" then
                    deferred[#deferred + 1] = {target, values}
                end
            end
            local function run(source, name, ...)
                local chunk, reason = loadstring(source, "@" .. name)
                if not chunk then return false, reason end
                setfenv(chunk, {type = type})
                return pcall(chunk, ...)
            end
            for _, file in ipairs(files) do
                local first = #deferred + 1
                local ok, reason = run(file[2], file[1], "GuiaAventurero", {AnadirIngles = register})
                if not ok then errors[#errors + 1] = tostring(reason) end
                for index = first, #deferred do deferred[index][3] = file[1] end
            end
            for _, block in ipairs(deferred) do
                local ok, value = run(block[2], block[3])
                if ok and type(value) == "table" then assign(block[1], value, false)
                else errors[#errors + 1] = tostring(value) end
            end
            return {por_id = quests, por_nombre = texts, errores = errors}
        end
    ''')
    addon = addon.resolve()
    manifest = (addon / "GuiaAventurero.toc").read_text(encoding="utf-8-sig")
    files = []
    errors = []
    for line in manifest.splitlines():
        entry = line.strip().replace("\\", "/")
        if not entry.startswith("Idioma/") or not entry.endswith(".lua"):
            continue
        path = (addon / entry).resolve()
        if not path.is_relative_to(addon):
            errors.append(f"{entry}: ruta fuera del addon")
            continue
        try:
            files.append(runtime.table_from([entry, path.read_text(encoding="utf-8-sig")]))
        except (OSError, UnicodeError) as error:
            errors.append(f"{entry}: {error}")
    result = load(runtime.table_from(files))
    return {"por_id": dict(result["por_id"]), "por_nombre": dict(result["por_nombre"]),
            "errores": errors + list(result["errores"].values())}


def load_mission_badges(addon: Path, quests) -> dict:
    """Ejecuta la función del addon con una ficha de misión aún sin datos."""
    from lupa.lua51 import LuaError, LuaRuntime

    toc = (addon / "GuiaAventurero.toc").read_text(encoding="utf-8-sig").splitlines()
    if "Opcionales.lua" not in {line.strip() for line in toc}:
        return {}
    runtime = LuaRuntime(register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    run = runtime.eval('''function(source)
        local chunk = assert(loadstring(source, "@Opcionales.lua"))
        setfenv(chunk, {type = type, ipairs = ipairs, pcall = pcall, table = {insert = table.insert}})
        local addon = {L = function(text) return text end, tarjetasGuia = {}}
        chunk("GuiaAventurero", addon)
        return addon.EtiquetaMision
    end''')
    try:
        badge = run((addon / "Opcionales.lua").read_text(encoding="utf-8-sig"))
        return {quest: badge(quest)[0] for quest in quests} if badge else {}
    except LuaError as error:
        raise ValueError(f"No se pudo comprobar la etiqueta de misión de Opcionales.lua: {error}") from error

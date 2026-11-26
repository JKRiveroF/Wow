"""Cruza los iniciadores y receptores con posiciones observadas de la misma entidad."""

from collections import defaultdict
from hashlib import sha256
import json
import re

from catalogo import TRACE_BASE
from eg_link import _source
from mission_rules import _confirmed, _norm, _variants
from questie_rules import FIXES, NUMBERS, SOURCE, _classic_columns, _fields, _read


NPC_TRACES = "src/corrections/Forever/traces/foreverNpcTraces.lua"
OBJECT_TRACES = "src/corrections/Forever/traces/foreverObjectTraces.lua"
QUESTS = "data/Forever/foreverQuestDB.lua"
HASHES = {
    NPC_TRACES: "f7aa667257db11ea8f65bd2cb0c88a418bd95286367a97a10e6de3155b94e196",
    OBJECT_TRACES: "4527c06d8e7db60ec112ea18b7e4382f696f95aa1abd30b70cb0ddeb6a571331",
    QUESTS: "621d4a1670232c047e7d171d8f1fdbd31581458935ee59dd70836016838dc942",
}
STATIC_ROLES = {"startedBy": "A", "finishedBy": "T"}
ENTITY_ROW = re.compile(r"^ {8}\[(\d+)\] = \{")
ENTITY_FIELD = re.compile(r"^ {12}\[(?:npc|object)Keys\.(spawns|questStarts_add|questEnds_add)\] = (.*),$")
SPAWN_AREA = re.compile(r"\[(\d+)\]\s*=\s*\{((?:\{\s*[\d., -]+\s*\},?\s*)+)\}")
SPAWN_POINT = re.compile(r"\{\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\s*\}")
QUEST_ROW = re.compile(r"^\[(\d+)\] = \{(.*)\},$")


def _lines(directory, name):
    path = directory / name.rsplit("/", 1)[-1]
    if not path.is_file():
        return []
    data = path.read_bytes()
    if sha256(data).hexdigest() != HASHES[name]:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requieren los datos de QuestieDB 1.1.6.")
    return data.decode("utf-8-sig").splitlines()


def _trace_entities(lines, kind, reference, maps, roles, positions):
    entity = None
    for line_number, line in enumerate(lines, 1):
        if row := ENTITY_ROW.match(line):
            entity = kind, int(row[1])
        elif line == "        },":
            entity = None
        elif entity and (field := ENTITY_FIELD.fullmatch(line)):
            source = f"{TRACE_BASE}{reference}#L{line_number}"
            if field[1] == "spawns":
                for area, coordinates in SPAWN_AREA.findall(field[2]):
                    if map_id := maps.get(int(area)):
                        positions[entity].extend({"m": map_id, "x": x, "y": y, "fuente": source}
                                                 for a, b in SPAWN_POINT.findall(coordinates)
                                                 if 0 <= (x := float(a)) <= 100 and 0 <= (y := float(b)) <= 100)
            elif NUMBERS.fullmatch(field[2]):
                action = "A" if field[1] == "questStarts_add" else "T"
                for quest in re.findall(r"\d+", field[2]):
                    roles[quest, action][entity] = source


def _entities(raw):
    if not raw.startswith("{") or not raw.endswith("}"):
        return ()
    return tuple((kind, int(entity)) for kind, group in zip(("pnj", "objeto"), _classic_columns(raw[1:-1]))
                 if NUMBERS.fullmatch(group) for entity in re.findall(r"\d+", group) if int(entity) > 0)


def _static_contacts(lines, missions):
    contacts = defaultdict(dict)
    for line_number, line in enumerate(lines, 1):
        if not (row := QUEST_ROW.fullmatch(line)) or row[1] not in missions:
            continue
        entry = missions[row[1]]
        if not _confirmed(entry, "nombre_en") or not entry.get("existe"):
            continue
        columns = _classic_columns(row[2])
        try:
            title = json.loads(columns[0])
        except ValueError:
            continue
        if not isinstance(title, str) or not any(_norm(title) == _norm(name) for name in _variants(entry["nombres"]["en"])):
            continue
        for action, raw in zip(("A", "T"), columns[1:3]):
            contacts[row[1], action].update(dict.fromkeys(_entities(raw), f"{TRACE_BASE}{QUESTS}#L{line_number}"))
    return contacts


def _apply_corrections(lines, static, traced):
    boundary = next((i for i, line in enumerate(lines) if ":LoadDynamic(" in line), len(lines))
    for quest, line, field, raw, _ in _fields(lines):
        key, _, operation = field.partition("_")
        if key not in STATIC_ROLES:
            continue
        role = quest, STATIC_ROLES[key]
        affected = _entities(raw)
        source = f"{SOURCE}{FIXES}#L{line}"
        if operation == "remove":
            for entity in affected:
                static[role].pop(entity, None)
                traced[role].pop(entity, None)
        elif not operation:
            traced[role] = {entity: origin for entity, origin in traced[role].items() if entity in affected}
            static[role] = dict.fromkeys(affected, source)
        elif operation == "add":
            static[role].update(dict.fromkeys(affected, source))
    for quest, _, field, _, _ in _fields(lines[boundary + 1:]):
        if (key := field.split("_", 1)[0]) in STATIC_ROLES:
            static.pop((quest, STATIC_ROLES[key]), None)


def link_contacts(directory, catalog):
    missions = catalog.get("misiones", {})
    traced, trace_points, maps_by_area = defaultdict(dict), defaultdict(list), defaultdict(set)
    for map_id, record in catalog.get("mapas", {}).items():
        if record.get("area") and record.get("existe") is True:
            maps_by_area[record["area"]].add(int(map_id))
    maps = {area: next(iter(ids)) for area, ids in maps_by_area.items() if len(ids) == 1}
    for kind, name in (("pnj", NPC_TRACES), ("objeto", OBJECT_TRACES)):
        _trace_entities(_lines(directory, name), kind, name, maps, traced, trace_points)
    static = _static_contacts(_lines(directory, QUESTS), missions)
    _apply_corrections(_read(directory, FIXES), static, traced)
    eg_points = catalog.get("entidades_interaccion", {})
    matched = {}
    for quest, entry in missions.items():
        actions = {}
        for action in ("A", "T"):
            role = quest, action
            observed = traced.get(role, {}).copy()
            for sample in entry.get("interlocutores_observados", {}).get(action, []):
                observed[sample["tipo"], sample["id"]] = _source(sample["build"], "npcs")["fuente"]
            source_roles = observed or static.get(role, {})
            points = {}
            for (kind, entity), contact in source_roles.items():
                for sample in (*trace_points.get((kind, entity), ()), *eg_points.get(kind, {}).get(entity, ())):
                    key = kind, entity, sample["m"], sample["x"], sample["y"]
                    points[key] = {**sample, "tipo": kind, "id": entity, "fuente_interaccion": contact,
                                   "metodo_interaccion": "observada" if observed else "catalogo_estatico"}
            if points:
                actions[action] = list(points.values())
        if actions:
            source = next(iter(actions.values()))[0]["fuente_interaccion"]
            matched[quest] = {"referencias_interaccion": actions, "evidencia": {"referencias_interaccion": {
                "estado": "forever", "fuente": source, "metodo": "posicion_de_interlocutor"}}}
    npcs = {str(entity): {"posiciones_trazas": samples, "evidencia": {"posiciones_trazas": {
        "estado": "forever", "fuente": samples[0]["fuente"]}}}
            for (kind, entity), samples in trace_points.items() if kind == "pnj" and samples}
    return {"misiones": matched, "pnj": npcs}

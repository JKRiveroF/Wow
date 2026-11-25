"""Carga evidencia acotada por campo, sin ejecutar código de fuentes externas."""

import json
import re
from hashlib import sha256
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRACE_BASE = "https://github.com/Questie/QuestieDB/blob/v1.1.6/"
TRACE_QUESTS = "src/corrections/Forever/traces/foreverQuestTraces.lua"
TRACE_XP = "support/Forever/QuestXP/xpDB-traces.lua"
TRACE_MAPS = "support/Forever/Zones/uiMapIdToAreaId.lua"
TRACE_HASHES = {
    TRACE_QUESTS: "ab463080df59687617648766288aa024d062ff0d4257cd605bd5d9cf71bc4eba",
    TRACE_XP: "f9b3c863f11f4a7a8512eb4a715a575d700a9528f49103c8652da9f219ecfabf",
    TRACE_MAPS: "4964def0918a8cddef6c5f8292526a076b2afe73ea58f178f68a78e35bec39e3",
}
QUEST_ROW = re.compile(r"^ {8}\[(\d+)\] = \{$")
QUEST_NAME = re.compile(r'^ {12}\[questKeys\.name\] = ("(?:[^"\\]|\\.)*"),$')
XP_ROW = re.compile(r"^QuestXP\.db\[(\d+)\] = \{(\d+), (\d+)\}$")
MAP_ROW = re.compile(r"^\s*\[(\d+)\] = (\d+), -- (.+)$")
ENTITY_KEYS = ("misiones", "mapas", "pnj", "vuelos")


def read_catalog(path):
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict):
        raise ValueError(f"El catálogo {path} debe ser un objeto JSON.")
    for entity in ENTITY_KEYS:
        if entity in data and (not isinstance(data[entity], dict) or
                               not all(isinstance(record, dict) and isinstance(record.get("evidencia", {}), dict)
                                       for record in data[entity].values())):
            raise ValueError(f"El índice {entity} del catálogo debe contener objetos por clave.")
    return data


def _trace_lines(directory, reference):
    path = directory / Path(reference).name
    data = path.read_bytes()
    if sha256(data).hexdigest() != TRACE_HASHES[reference]:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requieren las trazas de QuestieDB 1.1.6.")
    return data.decode("utf-8-sig").splitlines()


def import_traces(directory):
    quests = {}

    def record(quest_id, field, value, reference, line_number):
        source = TRACE_BASE + reference + f"#L{line_number}"
        evidence = {"estado": "forever", "fuente": source}
        entry = quests.setdefault(quest_id, {**evidence, "evidencia": {}})
        entry[field] = value
        entry["evidencia"][field] = evidence

    quest_id = None
    for line_number, line in enumerate(_trace_lines(directory, TRACE_QUESTS), 1):
        if row := QUEST_ROW.fullmatch(line):
            quest_id = row[1]
            record(quest_id, "existe", True, TRACE_QUESTS, line_number)
        elif line == "        },":
            quest_id = None
        elif quest_id and (name := QUEST_NAME.fullmatch(line)):
            record(quest_id, "nombres", {"en": json.loads(name[1])}, TRACE_QUESTS, line_number)

    for line_number, line in enumerate(_trace_lines(directory, TRACE_XP), 1):
        if entry := XP_ROW.fullmatch(line):
            record(entry[1], "xp", int(entry[3]), TRACE_XP, line_number)
            record(entry[1], "existe", True, TRACE_XP, line_number)
    maps = {}
    in_canonical_table = False
    for line_number, line in enumerate(_trace_lines(directory, TRACE_MAPS), 1):
        if line == "ZoneDB.private.uiMapIdToAreaId = [[return {":
            in_canonical_table = True
        elif in_canonical_table and line == "}]]":
            break
        elif in_canonical_table and (row := MAP_ROW.fullmatch(line)):
            maps[row[1]] = {"existe": True, "estado": "forever", "build": "1.60.1.69893",
                            "fuente": TRACE_BASE + TRACE_MAPS + f"#L{line_number}"}
    if len(maps) != 54:
        raise ValueError("No se pudieron extraer los 54 mapas canónicos de QuestieDB 1.1.6.")
    return {"misiones": quests, "mapas": maps}


def _merge_catalog(previous, current):
    combined = {**previous, **current}
    for entity in ENTITY_KEYS:
        old_records, new_records = previous.get(entity, {}), current.get(entity, {})
        if entity not in current:
            continue
        records = {**old_records}
        for key, new in new_records.items():
            old = old_records.get(key, {})
            evidence = old.get("evidencia", {}).copy()
            for field in new:
                if field in evidence:
                    del evidence[field]
            evidence.update(new.get("evidencia", {}))
            records[key] = {**old, **new}
            if evidence:
                records[key]["evidencia"] = evidence
        combined[entity] = records
    return combined


def load_catalog(path=None, trace_directory=None):
    catalog = import_traces(trace_directory) if trace_directory is not None else {}
    catalog = _merge_catalog(catalog, read_catalog(HERE / "evidencia_forever.json"))
    catalog = _merge_catalog(catalog, read_catalog(HERE / "curva_xp_forever.json"))
    return _merge_catalog(catalog, read_catalog(path)) if path is not None else catalog

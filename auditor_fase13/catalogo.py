"""Carga evidencia acotada por campo, sin ejecutar código de fuentes externas."""

import csv
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
QUEST_OBJECTIVES = re.compile(r"^ {12}\[questKeys\.objectives\] = (.*),$")
XP_ROW = re.compile(r"^QuestXP\.db\[(\d+)\] = \{(\d+), (\d+)\}$")
MAP_ROW = re.compile(r"^\s*\[(\d+)\] = (\d+), -- (.+)$")
ENTITY_KEYS = ("misiones", "mapas", "pnj", "vuelos")
QUEST_V2_BUILD = "1.60.1.71139"
QUEST_V2_HASH = "90cf939d1231e08257527add9259d4fecd429763d57b3f075a0ec2ff73f5f6dd"


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
    from questie_rules import observed_objectives

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
        elif quest_id and (objectives := QUEST_OBJECTIVES.fullmatch(line)):
            if items := observed_objectives(objectives[1]):
                record(quest_id, "objetos_objetivo", items, TRACE_QUESTS, line_number)

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


def import_quest_v2(path):
    raw = path.read_bytes()
    if sha256(raw).hexdigest() != QUEST_V2_HASH:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requiere QuestV2 de Forever {QUEST_V2_BUILD}.")
    rows = csv.DictReader(raw.decode("utf-8-sig").splitlines())
    return {"build": QUEST_V2_BUILD, "fuente": f"https://wago.tools/db2/QuestV2/csv?build={QUEST_V2_BUILD}",
            "ids": {int(row["ID"]) for row in rows}}


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
            record = {**old, **new}
            if isinstance(new.get("nombres"), dict) and isinstance(old.get("nombres"), dict):
                record["nombres"] = {**old["nombres"], **new["nombres"]}
            for field in new:
                if field in evidence and field != "nombres":
                    del evidence[field]
            supplied = new.get("evidencia", {})
            for locale in ("es", "en"):
                if isinstance(new.get("nombres"), dict) and locale in new["nombres"]:
                    field = f"nombre_{locale}"
                    source = supplied.get(field, supplied.get("nombres"))
                    if source:
                        evidence[field] = source
                    else:
                        evidence.pop(field, None)
            evidence.update(supplied)
            if evidence:
                record["evidencia"] = evidence
            records[key] = record
        combined[entity] = records
    return combined


def load_catalog(path=None, trace_directory=None, quest_directory=None, eg_directory=None):
    catalog = import_traces(trace_directory) if trace_directory is not None else {}
    if quest_directory is not None:
        from questie_evidence import import_inherited_spanish_titles, import_spanish_titles
        from questie_rules import import_quest_rules

        rules = import_quest_rules(quest_directory)
        for quest, entry in rules["misiones"].items():
            title = entry["evidencia"].get("nombre_en")
            observed = catalog.get("misiones", {}).get(quest, {})
            if title and "/generated/" in title["fuente"] and "nombres" in observed:
                entry.pop("nombres")
                entry["evidencia"].pop("nombre_en")
            objects = entry["evidencia"].get("objetos_objetivo")
            if objects and "/generated/" in objects["fuente"] and "objetos_objetivo" in observed:
                entry.pop("objetos_objetivo")
                entry["evidencia"].pop("objetos_objetivo")
        catalog = _merge_catalog(catalog, rules)
        catalog = _merge_catalog(catalog, import_spanish_titles(quest_directory))
        catalog["titulos_es_heredados"] = import_inherited_spanish_titles(quest_directory)
    if eg_directory is not None:
        from eg_link import import_eg_link

        observations = import_eg_link(eg_directory)
        for quest, entry in observations["misiones"].items():
            current = catalog.get("misiones", {}).get(quest, {})
            if "xp_calculada" in entry and "xp" not in current:
                entry["xp"] = entry["xp_calculada"]
                entry["evidencia"]["xp"] = entry["evidencia"]["xp_calculada"]
        catalog = _merge_catalog(catalog, observations)
    catalog = _merge_catalog(catalog, read_catalog(HERE / "evidencia_forever.json"))
    catalog = _merge_catalog(catalog, read_catalog(HERE / "curva_xp_forever.json"))
    catalog = _merge_catalog(catalog, read_catalog(HERE / "perfiles_forever.json"))
    catalog = _merge_catalog(catalog, read_catalog(HERE / "arranques_forever.json"))
    catalog = _merge_catalog(catalog, read_catalog(HERE / "cartografia_forever.json"))
    if quest_directory is not None and eg_directory is not None:
        from questie_rules import corroborate_classic_followups

        catalog = _merge_catalog(catalog, corroborate_classic_followups(quest_directory, catalog))
    return _merge_catalog(catalog, read_catalog(path)) if path is not None else catalog

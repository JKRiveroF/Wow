"""Lee campos estáticos de Forever y relaciones inferidas de QuestieDB 1.1.6."""

import json
import re
from hashlib import sha256
from pathlib import Path

SOURCE = "https://github.com/Questie/QuestieDB/blob/v1.1.6/src/corrections/Forever/"
BASE = "generated/foreverBaseQuest.lua"
FIXES = "foreverQuestFixes.lua"
RELATIONS = "traces/foreverQuestRelationTraces.lua"
HASHES = {
    BASE: "197dff16946293da0cd23722578cb383a498c6e8d046fc49a96a3777883a66c2",
    FIXES: "1f322361045262150f843f8c3e72ed6ac048a449883899889b36eb1146465b30",
    RELATIONS: "8fdaf341227ae4b890c5c865f024a6c0a951423fa5d1a09073e5c3a833e871f8",
}

ROW = re.compile(r"^ {8}\[(\d+)\]\s*=\s*\{")
FIELD = re.compile(r"^ {12}\[questKeys\.(\w+)\]\s*=\s*(.+?),\s*(--.*)?$")
NUMBERS = re.compile(r"\{\s*(?:[0-9]+(?:\s*,\s*[0-9]+)*)?\s*\}")
NUMBER_FIELDS = {"requiredLevel": "nivel_minimo", "questLevel": "nivel_mision", "sourceItemId": "objeto_entregado"}
LIST_FIELDS = {"preQuestGroup": "prerrequisitos", "preQuestSingle": "prerrequisitos_alternativos",
               "exclusiveTo": "excluyentes", "breadcrumbs": "introductorias", "requiredSourceItems": "objetos"}
LINK_FIELDS = {"nextQuestInChain": "seguimientos", "disabledByQuest": "desactivada_por", "parentQuest": "mision_activa"}
RELATION_FIELDS = {"preQuestGroup", "preQuestSingle", "exclusiveTo", "breadcrumbs", "nextQuestInChain"}
RACES = {
    "HUMAN": ("Alliance", "Human"), "DWARF": ("Alliance", "Dwarf"), "NIGHT_ELF": ("Alliance", "NightElf"),
    "GNOME": ("Alliance", "Gnome"), "SKYBORNE_ALLIANCE": ("Alliance", "Skyborne"),
    "ORC": ("Horde", "Orc"), "UNDEAD": ("Horde", "Scourge"), "TAUREN": ("Horde", "Tauren"),
    "TROLL": ("Horde", "Troll"), "SKYBORNE_HORDE": ("Horde", "Skyborne"),
}
CLASSES = {"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}


def _read(directory, name):
    path = directory / Path(name).name
    raw = path.read_bytes()
    if sha256(raw).hexdigest() != HASHES[name]:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requieren los datos de QuestieDB 1.1.6.")
    return raw.decode("utf-8-sig").splitlines()


def _fields(lines):
    current = None
    for number, line in enumerate(lines, 1):
        if line.startswith("function ") and ":LoadDynamic(" in line:
            break
        if row := ROW.match(line):
            current = row[1]
        elif line.lstrip() in ("},", "}") and len(line) - len(line.lstrip()) <= 8:
            current = None
        elif current and (field := FIELD.fullmatch(line)):
            yield current, number, field[1], field[2], field[3] or ""


def _mask(value, prefix, groups):
    """Acepta solo constantes conocidas y operaciones sobre grupos disjuntos."""
    if value == "0":
        return set()
    terms = re.split(r"\s*([+-])\s*", value)
    result = set()
    operation = "+"
    for index, part in enumerate(terms):
        if index % 2:
            operation = part
            continue
        if not part.startswith(prefix) or part[len(prefix):] not in groups:
            return None
        operand = groups[part[len(prefix):]]
        if operation == "+" and not result.intersection(operand):
            result.update(operand)
        elif operation == "-" and operand.issubset(result):
            result.difference_update(operand)
        else:
            return None
    return result


def _decode(field, value):
    if field in NUMBER_FIELDS and re.fullmatch(r"-?\d+", value):
        return {NUMBER_FIELDS[field]: int(value)}
    if field in LIST_FIELDS and NUMBERS.fullmatch(value):
        return {LIST_FIELDS[field]: [int(item) for item in re.findall(r"\d+", value)]}
    if field in LINK_FIELDS and value.isdecimal():
        return {LINK_FIELDS[field]: [int(value)] if value != "0" else []}
    if field == "objectives" and re.fullmatch(r"(?:[{} ,\d-]|nil)+", value):
        try:
            goals = json.loads(value.replace("{", "[").replace("}", "]").replace("nil", "null"))
        except ValueError:
            return {}
        if isinstance(goals, list) and len(goals) > 2 and isinstance(goals[2], list):
            items = [row[0] for row in goals[2] if isinstance(row, list) and row and type(row[0]) is int and row[0] > 0]
            if items:
                return {"objetos_objetivo": sorted(set(items))}
    if field == "specialFlags" and value in ("0", "specialFlags.NONE", "specialFlags.REPEATABLE"):
        return {"repetible": value == "specialFlags.REPEATABLE"}
    if field == "requiredClasses":
        classes = _mask(value, "classIDs.", {name: {name} for name in CLASSES} | {"NONE": set()})
        return {"clases": sorted(classes)} if classes is not None else {}
    if field == "requiredRaces":
        groups = {name: {profile} for name, profile in RACES.items()}
        groups |= {"ALL_ALLIANCE": {pair for pair in RACES.values() if pair[0] == "Alliance"},
                   "ALL_HORDE": {pair for pair in RACES.values() if pair[0] == "Horde"}, "NONE": set()}
        profiles = _mask(value, "raceIDs.", groups)
        if profiles is not None:
            return {"razas": sorted({pair[1] for pair in profiles}),
                    "facciones": sorted({pair[0] for pair in profiles}),
                    "razas_por_faccion": {faction: sorted(race for side, race in profiles if side == faction)
                                          for faction in ("Alliance", "Horde")}}
    if field == "name" and value.startswith('"'):
        try:
            name = json.loads(value)
        except ValueError:
            return {}
        if isinstance(name, str) and name.strip():
            return {"nombres": {"en": name}}
    return {}


def observed_objectives(value):
    """Toma solo IDs de la ranura de objetos, donde el formato es inequívoco."""
    return _decode("objectives", value).get("objetos_objetivo")


def import_quest_rules(directory):
    missions = {}
    relation_candidates = {}
    sources = {filename: _read(directory, filename) for filename in (BASE, RELATIONS, FIXES)}
    fixes = sources[FIXES]
    dynamic = next((i for i, line in enumerate(fixes) if ":LoadDynamic(" in line), len(fixes))
    dynamic_ids = set(re.findall(r"\[(\d+)\]\s*=", "\n".join(fixes[dynamic:])))
    for filename, lines in sources.items():
        for quest, line, field, value, note in _fields(lines):
            if filename == RELATIONS and field not in RELATION_FIELDS:
                continue
            columns = _decode(field, value)
            if not columns:
                continue
            source = SOURCE + filename + f"#L{line}"
            uncertain = re.search(r"unverified|assumption:", note, re.I) or quest in dynamic_ids
            if filename == RELATIONS or uncertain:
                for key, item in columns.items():
                    relation_candidates.setdefault(quest, []).append({"campo": key, "valor": item, "fuente": source})
                    if filename == FIXES and quest in missions:
                        entry = missions[quest]
                        entry.pop(key, None)
                        entry["evidencia"].pop("nombre_en" if key == "nombres" else key, None)
                continue
            evidence = {"estado": "forever", "fuente": source}
            entry = missions.setdefault(quest, {"existe": True, "evidencia": {"existe": evidence}})
            for key, item in columns.items():
                entry[key] = item
                entry["evidencia"]["nombre_en" if key == "nombres" else key] = evidence
    return {"misiones": missions, "candidatos_por_mision": relation_candidates}

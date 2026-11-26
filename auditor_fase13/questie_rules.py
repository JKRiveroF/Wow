"""Lee campos estáticos de Forever y relaciones inferidas de QuestieDB 1.1.6."""

import json
import re
from hashlib import sha256
from pathlib import Path

SOURCE = "https://github.com/Questie/QuestieDB/blob/v1.1.6/src/corrections/Forever/"
BASE = "generated/foreverBaseQuest.lua"
FIXES = "foreverQuestFixes.lua"
RELATIONS = "traces/foreverQuestRelationTraces.lua"
CLASSIC_DB = "data/Classic/classicQuestDB.lua"
LEGACY_FIXES = "src/corrections/Forever/legacy/classicQuestFixes.lua"
LEGACY_CACHE = "legacyForeverClassicQuestFixes.lua"
REPOSITORY = "https://github.com/Questie/QuestieDB/blob/v1.1.6/"
HASHES = {
    BASE: "197dff16946293da0cd23722578cb383a498c6e8d046fc49a96a3777883a66c2",
    FIXES: "1f322361045262150f843f8c3e72ed6ac048a449883899889b36eb1146465b30",
    RELATIONS: "8fdaf341227ae4b890c5c865f024a6c0a951423fa5d1a09073e5c3a833e871f8",
    CLASSIC_DB: "bd44f6353531b4fe3b95eab3d469bef64ab41503646c509db73813f309ab3ad4",
    LEGACY_FIXES: "76cd6a05f035826cabc6180a0ff2a1a37c5e7946c891eb0a06412fab5a4caf2e",
}

ROW = re.compile(r"^ {8}\[(\d+)\]\s*=\s*\{")
FIELD = re.compile(r"^ {12}\[questKeys\.(\w+)\]\s*=\s*(.+?),\s*(--.*)?$")
NUMBERS = re.compile(r"\{\s*(?:[0-9]+(?:\s*,\s*[0-9]+)*)?\s*\}")
NUMBER_FIELDS = {"requiredLevel": "nivel_minimo", "questLevel": "nivel_mision", "sourceItemId": "objeto_entregado"}
LIST_FIELDS = {"preQuestGroup": "prerrequisitos", "preQuestSingle": "prerrequisitos_alternativos",
               "exclusiveTo": "excluyentes", "breadcrumbs": "introductorias", "requiredSourceItems": "objetos"}
LINK_FIELDS = {"nextQuestInChain": "seguimientos", "disabledByQuest": "desactivada_por", "parentQuest": "mision_activa"}
RELATION_FIELDS = {"preQuestGroup", "preQuestSingle", "exclusiveTo", "breadcrumbs", "nextQuestInChain"}
INHERITED_RELATIONS = {"preQuestGroup", "preQuestSingle", "nextQuestInChain"}
CLASSIC_COLUMN = re.compile(r"^ +\['(\w+)'\] = (\d+),")
TRACE_ROW = re.compile(r"^ {8}(?:-- )?\[(\d+)\]\s*=\s*\{")
TRACE_REQUIREMENT = re.compile(r"^ {12}-- \[questKeys\.preQuestSingle\] = \{(\d+)\},\s*$")
TRACE_HANDOFF = re.compile(
    r"^ {12}-- already in QuestieDB; Assumption: offered right after (\d+) was turned in "
    r"\(([^;]+); very high; 100\+ characters\)\s*$"
)
GATE_FIELDS = {"preQuestSingle", "preQuestGroup", "parentQuest", "availableStartingWith", "disabledByQuest"}
RACES = {
    "HUMAN": ("Alliance", "Human"), "DWARF": ("Alliance", "Dwarf"), "NIGHT_ELF": ("Alliance", "NightElf"),
    "GNOME": ("Alliance", "Gnome"), "SKYBORNE_ALLIANCE": ("Alliance", "Skyborne"),
    "ORC": ("Horde", "Orc"), "UNDEAD": ("Horde", "Scourge"), "TAUREN": ("Horde", "Tauren"),
    "TROLL": ("Horde", "Troll"), "SKYBORNE_HORDE": ("Horde", "Skyborne"),
}
CLASSES = {"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}


def _read(directory, name, cache_name=None):
    path = directory / (cache_name or Path(name).name)
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


def _classic_columns(row):
    """Separa la fila compacta sin interpretar sus literales Lua."""
    fields = []
    start = depth = 0
    for token in re.finditer(r'"(?:[^"\\]|\\.)*"|[{},]', row):
        symbol = token[0]
        if symbol == "{":
            depth += 1
        elif symbol == "}":
            depth -= 1
        elif symbol == "," and not depth:
            fields.append(row[start:token.start()].strip())
            start = token.end()
    fields.append(row[start:].strip())
    return fields


def _classic_relations(directory):
    base = _read(directory, CLASSIC_DB)
    columns = {match[1]: int(match[2]) - 1 for line in base if (match := CLASSIC_COLUMN.match(line))
               and match[1] in INHERITED_RELATIONS}
    records = {}
    for number, line in enumerate(base, 1):
        row = re.fullmatch(r"\[(\d+)\] = \{(.*)\},", line)
        if row is None:
            continue
        fields = _classic_columns(row[2])
        source = f"{REPOSITORY}{CLASSIC_DB}#L{number}"
        records[row[1]] = {field: (fields[index], source) for field, index in columns.items() if index < len(fields)}

    legacy = _read(directory, LEGACY_FIXES, LEGACY_CACHE)
    dynamic_start = next(i for i, line in enumerate(legacy, 1) if ":LoadFactionFixes(" in line)
    for quest, number, field, value, _ in _fields(legacy):
        if field not in INHERITED_RELATIONS:
            continue
        if number < dynamic_start:
            records.setdefault(quest, {})[field] = (value, f"{REPOSITORY}{LEGACY_FIXES}#L{number}")
        else:
            records.setdefault(quest, {}).pop(field, None)
    return records


def _traced_requirements(lines):
    """Selecciona solo entregas con observación del ofrecimiento antes y después."""
    quest = None
    for number, line in enumerate(lines, 1):
        if row := TRACE_ROW.match(line):
            quest = row[1]
        elif line.strip() in ("},", "-- },"):
            quest = None
        elif quest and (condition := TRACE_REQUIREMENT.fullmatch(line)):
            handoff = TRACE_HANDOFF.fullmatch(lines[number - 2])
            if (handoff and handoff[1] == condition[1]
                    and {"handoff", "offer-set", "absence"} <= set(handoff[2].split(", "))):
                yield quest, int(condition[1]), number


def corroborate_inherited_relations(directory, catalog):
    """Contrasta continuaciones y requisitos de una entrega con evidencia de alcance distinto."""
    if not all((directory / name).is_file() for name in (Path(CLASSIC_DB).name, LEGACY_CACHE)):
        return {}
    missions = catalog.get("misiones", {})
    inherited = _classic_relations(directory)
    confirmed = {}
    for quest, fields in inherited.items():
        value, classic_source = fields.get("nextQuestInChain", ("", ""))
        if not value.isdecimal() or not (following := int(value)):
            continue
        entry = missions.get(quest, {})
        successor = missions.get(str(following), {})
        if "seguimientos" in entry or entry.get("siguiente_sugerida") != following:
            continue
        history = successor.get("misiones_previas_observadas", {})
        if int(quest) not in history.get("before", []):
            continue
        candidate = entry.get("evidencia", {}).get("siguiente_sugerida", {})
        observed = successor.get("evidencia", {}).get("misiones_previas_observadas", {})
        if candidate.get("estado") != "forever" or observed.get("estado") != "forever":
            continue
        proof = {**candidate, "metodo": "secuencia_contrastada",
                 "fuentes_adicionales": [classic_source, observed["fuente"]]}
        confirmed[quest] = {"seguimientos": [following], "evidencia": {"seguimientos": proof}}

    base, fixes = (_read(directory, layer) for layer in (BASE, FIXES))
    replaced = {quest for lines in (base, fixes) for quest, _, field, _, _ in _fields(lines) if field in GATE_FIELDS}
    dynamic = next((i for i, line in enumerate(fixes) if ":LoadDynamic(" in line), len(fixes))
    replaced.update(re.findall(r"\[(\d+)\]\s*=", "\n".join(fixes[dynamic:])))
    for quest, required, number in _traced_requirements(_read(directory, RELATIONS)):
        entry = missions.get(quest, {})
        if quest in replaced or not entry.get("existe") or entry.keys() & {
            "prerrequisitos", "prerrequisitos_alternativos", "mision_activa", "desactivada_por"
        }:
            continue
        baseline, source = inherited.get(quest, {}).get("preQuestSingle", ("", ""))
        field = "prerrequisitos_alternativos"
        if _decode("preQuestSingle", baseline).get(field) != [required]:
            continue
        proof = {"estado": "forever", "fuente": f"{SOURCE}{RELATIONS}#L{number}",
                 "metodo": "oferta_tras_entrega_contrastada", "fuentes_adicionales": [source]}
        record = confirmed.setdefault(quest, {"evidencia": {}})
        record[field] = [required]
        record["evidencia"][field] = proof
    return {"misiones": confirmed}

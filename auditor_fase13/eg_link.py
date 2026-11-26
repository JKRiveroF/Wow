"""Lee instantáneas de Forever y conserva su alcance por campo y compilación."""

import csv
import json
from decimal import Decimal
from hashlib import sha256

from questie_rules import RACES

REVISION = "f25e0efde0c8490e4e6f356a68f7a81a703fa21c"
BASE = f"https://github.com/JIVESCORP/eg-link-output-wowf/blob/{REVISION}/data/wowf/"
HASHES = {
    ("70938", "quests.enUS"): "cc038ecb07f37a74b4bde7e6663950288205487b26d11fdd30687e2811b870f7",
    ("70959", "quests.enUS"): "7d462939d968f129ca05346867b668f05d9e9326a0ea57476781058bff60a97f",
    ("71037", "quests.enUS"): "1229fc898ddf774f7c314805929b5e5ba15673effe7f707af46b07b5ab104f27",
    ("71091", "quests.enUS"): "f9f5bd74ea4adf82462cc93d5c1924bd37bf8df4d42d8a47f5f1131f7849d630",
    ("70959", "npcs"): "ba05fda32ceca14957237e7f9065b8535fd59a5d0db1358f4bca0073ac9d07e0",
    ("70959", "objectives"): "d04a7715b3b23013bf546075e3a97d4063c4db7323fad3f4deae77d96567b47c",
    ("70959", "turn_ins"): "329efdcf27854b9a851ed5e0c09712aaa7feeae63de3344a6441e228b19e8659",
    ("70959", "quest_prerequisites"): "db21d94f2303050935ee178e8fdb7d7c07277d91ebefa6b3d9f5e6c13d8f3633",
    ("71037", "quest_prerequisites"): "66fe82c4ee3dbff588d0704ad1cdf85a33603b8086324e8787417798494dfbaa",
    ("71091", "quest_prerequisites"): "74576279b4717d77c3dec5b14ac58671fd521d2d0531700da8b043b4b9e8455a",
    ("71037", "quest_scan"): "b50ecf42fa6f4757b1ec92df2cf4f6b6b1266cb5ccc26c82de90362d86fc8e2b",
    ("71091", "quest_scan"): "49391e207fb9297d34424721096171f32c9b013689b4c704606062d0805e10d1",
    ("71037", "item_uses"): "3e16f56d3435cc974cfec2052dcffe8fad90a2976f65e87393d4c05eb89ae75a",
    ("71037", "flights"): "a1406e02cc1124769f7297cf6a0e96b91fc9dde61eac5af2c155349db63bc7e3",
}
EG_FIELDS = (
    "nivel_mision", "mascara_racial", "siguiente_sugerida", "area_mision", "objetivos_servidor",
    "objetos_por_botin", "habilidades_recompensa", "componentes_xp", "entregas_observadas",
    "misiones_previas_observadas", "escaneo_faccion", "opciones_dialogo_observadas", "usos_objetos_observados",
    "xp_calculada",
)
XP_BUILD = "1.60.1.71091"
XP_HASH = "1513f3f2646ae0b33b79de6219614792f0dbc050bb5bd76c1c4f0fce668a86fd"
XP_SOURCE = f"https://wago.tools/db2/QuestXP/csv?build={XP_BUILD}"
RACE_BITS = dict(enumerate(("HUMAN", "ORC", "DWARF", "NIGHT_ELF", "UNDEAD", "TAUREN", "GNOME", "TROLL")))
RACE_BITS.update({32: "SKYBORNE_ALLIANCE", 33: "SKYBORNE_HORDE"})


def _source(build, dataset):
    return {"estado": "forever", "build": build, "fuente": f"{BASE}{build}/{dataset}.json"}


def _read(directory, build_number, dataset):
    build = f"1.60.1.{build_number}"
    path = directory / f"eg-{build}-{dataset}.json"
    raw = path.read_bytes()
    if sha256(raw).hexdigest() != HASHES[build_number, dataset]:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requiere la revisión EG Link {REVISION}.")
    data = json.loads(raw)
    meta = data["meta"]
    expected = ("wowf", build, dataset.split(".")[0], 1)
    if tuple(meta[k] for k in ("product", "clientBuild", "dataset", "schemaVersion")) != expected:
        raise ValueError(f"Metadatos inesperados en {path}.")
    if dataset == "quests.enUS" and meta.get("locale") != "enUS":
        raise ValueError(f"Idioma inesperado en {path}.")
    return data, _source(build, dataset)


def _record(index, key, values, source):
    entry = index.setdefault(key, {"evidencia": {}})
    entry.update(values)
    entry["evidencia"].update({field: source for field in values})


def _race_fields(value):
    bits = int(value, 16)
    all_known = sum(1 << bit for bit in RACE_BITS)
    profiles = {RACES[race] for bit, race in RACE_BITS.items() if bits & (1 << bit)}
    if not profiles or bits & all_known == all_known:
        return {}
    factions = sorted({side for side, _ in profiles})
    return {"razas": sorted({race for _, race in profiles}), "facciones": factions,
            "razas_por_faccion": {side: sorted(race for faction, race in profiles if faction == side)
                                  for side in factions}}


def _read_xp_table(directory):
    path = directory / f"QuestXP-{XP_BUILD}.csv"
    raw = path.read_bytes()
    if sha256(raw).hexdigest() != XP_HASH:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requiere QuestXP de Forever {XP_BUILD}.")
    return {int(row["ID"]): row for row in csv.DictReader(raw.decode("utf-8-sig").splitlines())}


def _base_xp(entry, table):
    components = entry.get("componentes_xp")
    if not components:
        return None
    tier = table.get(entry["nivel_mision"], {}).get(f"Difficulty_{components['xpDifficulty']}")
    if tier is None:
        return None
    return int(int(tier) * Decimal(str(components["xpMultiplier"])))


def _quest_values(row):
    mask = row["raceMask"]
    result = {"existe": True, "nivel_minimo": row["minLevel"], "nivel_mision": row["level"],
              "mascara_racial": mask, **_race_fields(mask)}
    if row["title"].strip():
        result["nombres"] = {"en": row["title"]}
    for original, field in (("nextQuestId", "siguiente_sugerida"), ("startItemId", "objeto_entregado"),
                            ("zoneAreaId", "area_mision")):
        if row.get(original):
            result[field] = row[original]
    if objectives := row.get("objectives"):
        result["objetivos_servidor"] = [
            {k: goal[k] for k in ("id", "typeId", "type", "objectId", "amount") if k in goal}
            for goal in objectives
        ]
        items = {}
        for goal in objectives:
            if goal.get("type") == "item" and goal.get("objectId", 0) > 0 and goal.get("amount", 0) > 0:
                key = str(goal["objectId"])
                items[key] = max(items.get(key, 0), goal["amount"])
        if items:
            result["objetos_objetivo"] = sorted(map(int, items))
            result["cantidades_objetivo"] = items
    if drops := row.get("itemDrops"):
        result["objetos_por_botin"] = drops
    rewards = row["rewards"]
    components = {key: rewards[key] for key in ("xpDifficulty", "xpMultiplier") if key in rewards}
    if len(components) == 2:
        result["componentes_xp"] = components
    spells = sorted({item["spellId"] for item in rewards.get("displaySpells", []) if item.get("spellId", 0) > 0})
    if spells or rewards.get("spellId"):
        result["habilidades_recompensa"] = {"mostradas": spells, "aplicada": rewards.get("spellId")}
    return result


def _positions(rows):
    return [{"m": row["uiMap"], "x": round(100 * row["mapX"], 4), "y": round(100 * row["mapY"], 4)}
            for row in rows if row.get("uiMap", 0) > 0
            and all(type(row.get(axis)) in (int, float) and 0 <= row[axis] <= 1 for axis in ("mapX", "mapY"))
            and (row["mapX"] or row["mapY"])]


def _import_npcs(missions, data, source):
    npcs, linked = {}, {}
    for section in ("npcs", "objects"):
        for key, row in data[section].items():
            if not row.get("sources") or not (positions := _positions(row.get("positions", []))):
                continue
            if section == "npcs":
                _record(npcs, key, {"posiciones_observadas": positions}, source)
            for field, action in (("offers", "A"), ("takes", "T")):
                for quest_id in row.get(field, {}):
                    linked.setdefault(quest_id, {}).setdefault(action, []).extend(positions)
    for quest_id, actions in linked.items():
        _record(missions, quest_id, {"posiciones_observadas": actions}, source)
    return npcs


def _import_objectives(missions, data, source):
    for quest_id in data["quests"].keys() | data["completed"].keys():
        goals = data["quests"].get(quest_id, {}).values()
        positions = [pos for row in goals if row.get("sources") and row.get("gains")
                     for pos in _positions(row.get("positions", []))]
        completed = data["completed"].get(quest_id, {})
        if completed.get("sources") and completed.get("times"):
            positions.extend(_positions(completed.get("positions", [])))
        if positions:
            _record(missions, quest_id, {"progreso_observado": {"C": positions}}, source)
    for quest_id, row in data["gossip"].items():
        _record(missions, quest_id, {"opciones_dialogo_observadas": row}, source)


def _import_turn_ins(missions, data, source):
    for quest_id in data["quests"].keys() | data["withLegacy"].keys():
        observations = [{key: row[key] for key in ("level", "race", "faction", "xp", "maxLevel",
                                                  "xpDisabled", "diplomat", "sources") if key in row}
                        for section in ("quests", "withLegacy") for row in data[section].get(quest_id, [])]
        _record(missions, quest_id, {"entregas_observadas": observations}, source)


def import_eg_link(directory):
    missions, npcs, flights = {}, {}, {}
    xp_table = _read_xp_table(directory)
    for build, dataset in HASHES:
        data, source = _read(directory, build, dataset)
        if dataset == "quests.enUS":
            for quest_id, row in data["quests"].items():
                missions[quest_id] = {"evidencia": {}}
                _record(missions, quest_id, _quest_values(row), source)
        elif dataset == "npcs":
            npcs = _import_npcs(missions, data, source)
        elif dataset == "objectives":
            _import_objectives(missions, data, source)
        elif dataset == "turn_ins":
            _import_turn_ins(missions, data, source)
        elif dataset == "flights":
            flights = {**source, "maestros": data["masters"], "conexiones": data["routes"]}
        elif dataset in ("quest_prerequisites", "item_uses"):
            field = "misiones_previas_observadas" if dataset == "quest_prerequisites" else "usos_objetos_observados"
            for quest_id, row in data["quests"].items():
                _record(missions, quest_id, {field: row}, source)
        elif dataset == "quest_scan":
            for quest_id, row in data["described"].items():
                counts = {key: row[key] for key in ("factions", "noDataFactions", "sources") if key in row}
                _record(missions, quest_id, {"escaneo_faccion": counts}, source)
            for quest_id in data["repeatable"]:
                _record(missions, quest_id, {"repetible": True}, source)
    for quest_id, entry in missions.items():
        xp = _base_xp(entry, xp_table)
        if xp is not None:
            source = {**entry["evidencia"]["componentes_xp"], "tabla": XP_SOURCE, "metodo": "calculada"}
            _record(missions, quest_id, {"xp_calculada": xp}, source)
    return {"misiones": missions, "pnj": npcs, "vuelos_observados": flights}

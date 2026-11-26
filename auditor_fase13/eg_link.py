"""Lee instantáneas de Forever y conserva su alcance por campo y compilación."""

import csv
import json
from decimal import Decimal
from hashlib import sha256

from questie_rules import RACES

REVISION = "f25e0efde0c8490e4e6f356a68f7a81a703fa21c"
REVISION_71139 = "1339ce5600bbc2b12e8f1081e584f548f62fa57f"
BASE = "https://github.com/JIVESCORP/eg-link-output-wowf/blob/"
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
EXTRA_HASHES = {
    ("70790", "quests.enUS"): "1d338604744f0100ec58ea14c904f1b1c676b826d832bc747c90eae27b569bc7",
    ("70790", "turn_ins"): "a462e92603a2a64a420dfbc383a3c62196da14f83fb2771ffd759fce8be9d795",
    ("70790", "quest_scan"): "61dcbb4de5f9b08fe65c091080bb3af8eeff0c4a4ced8f31b27ef0e449f17e56",
    ("70790", "npcs"): "e732c47ad4bde79fa6ea1acba656d7498c39ac46e8cc4afc29f43239e4f128b4",
    ("70840", "quests.enUS"): "e78aaae3aee37b26a47de4eef4b171910a04e77b9cb85bc3985a25bd0c058294",
    ("70840", "turn_ins"): "5580cc6050524a9b94ede61acf1f9af6a4678aacbf367569be668d68b611ba2a",
    ("70840", "npcs"): "d657fb35416b2da2d9d75cbb3ff870f517111ce092a405301afdfb5fee4ef94b",
    ("70840", "quest_scan"): "a33a0c1eb0eee42c747b6355ba38fad4892456ab44a7671b7fa944af8bd6b319",
    ("70862", "quests.enUS"): "7b96a1e976a6746492f8a17e8de9ab1b014f236ebfb01e5f03dbe81880777877",
    ("70862", "turn_ins"): "7d54c980222a6154bec6afb0413fb8cf39a172fd146ece3a6024504b7687ea5b",
    ("70862", "quest_scan"): "c237d72377bad9904bf4ad49d1121cc73ae3f2aa94847cfcc8d75e28268fbae3",
    ("70862", "npcs"): "64ca5ce997d82cc0ce9aa1ea1f96ea2c363b28bb3ebf3af460e2d16693915cdc",
    ("70888", "quests.enUS"): "c3b3a6aeee4a6c90c0d88a1e8ec468a43957fd46a7153b927c9a41b0e67faf7d",
    ("70888", "turn_ins"): "b9cc57d19b126a9696ddc1cd7ebe70e7674f739d2af039915f3cc60b5fd78549",
    ("70888", "quest_scan"): "f7bd32186f15993c6bdb42b1c4dfcf68e9bbdeca31834a4460a52d4854716fd9",
    ("70888", "npcs"): "e03cc30ff79ebf02f50bdc6baf3463b5b8c65569175a1e112102fcfc9ea74274",
    ("70938", "turn_ins"): "b0bdb851d6790e590323432d9f08bef811613a829c03cd68414ad2ecec8899f1",
    ("70938", "npcs"): "25707c9ea017a905cda6b01206cd6d3bf496e6f77c823034c33d5907d951752c",
    ("70959", "quest_scan"): "d765048784e3c9a2259869982a2da0fce7a2913712fc1aa618315f6647d429a2",
    ("71037", "npcs"): "25cbc37150af015aae0c0406c2485d1c26e2f35b622c0963e2b830b683e7b8b0",
    ("71037", "objectives"): "724e5c3263d78da807cb09e59fcdd87367e77306ba5a4a6ec4d3a91d054fc903",
    ("71037", "turn_ins"): "c467fbfa634783dc16c1ea3f3e911e4375771da222047bcd93a851cb77a510ec",
    ("71091", "npcs"): "634e380c300f3d0fbb46e5bc413b4dc389641d340a96ce5cd5b1068d090b88c1",
    ("71091", "objectives"): "adecc0c1747159750030fa123f28c56ad6058bfa0501c77953b932d3818f482e",
    ("71091", "turn_ins"): "59652ac7ac8de5b928bd6638f2c816b016c9aab50f1169aba271da3014c6159d",
    ("71139", "quests.enUS"): "67b6338e44ff81e5d587ed36ce8acb56fa1171c939f15902cd598bf1b813eea8",
    ("71139", "quest_scan"): "051ebed401f45d3ca6595cfaec0af8a85a5fc0c2ed5698bd93bee0689c631c30",
    ("71139", "npcs"): "dc793783e33545d30e152689a1c3307a223fddb2319a221f6fa136b5cf145521",
    ("71139", "objectives"): "7ca0ad356113812e5ae5920b947e32f925270ba373cb211f21d4ba5a2eb212b4",
    ("71139", "turn_ins"): "b96bd91c917f4e37c47137a4e43bd2c1a59add12496d40539aa7d36935dfe8df",
    ("71139", "quest_prerequisites"): "b57b9cfae9d5471821a308bab7336704763f3f2c1de14119d1086f6df34f530b",
    ("71139", "item_uses"): "d911a0a8a2788c0051b9aecc50bd75b9e2bd8bab7c0727b2166161f3a3fc79cf",
}
EG_FIELDS = (
    "nivel_mision", "mascara_racial", "siguiente_sugerida", "area_mision", "objetivos_servidor",
    "objetos_por_botin", "habilidades_recompensa", "componentes_xp", "entregas_observadas",
    "misiones_previas_observadas", "escaneo_faccion", "opciones_dialogo_observadas", "usos_objetos_observados",
    "xp_calculada", "consultas_sin_respuesta",
    "tipo_mision", "limite_segundos", "interlocutores_observados", "posiciones_observadas", "progreso_observado",
)
XP_BUILD = "1.60.1.71091"
XP_HASH = "1513f3f2646ae0b33b79de6219614792f0dbc050bb5bd76c1c4f0fce668a86fd"
NEW_BUILD = "1.60.1.71139"
RECENT_REVISION_BUILDS = {"1.60.1.70790", "1.60.1.70840", "1.60.1.70862", "1.60.1.70888", NEW_BUILD}
QUEST_INFO_HASH = "06e1f7250d8ad8d042516ebae1fa4a78fa9307cab0fe62daf19a73331518fd4b"
QUEST_INFO_SOURCE = f"https://wago.tools/db2/QuestInfo/csv?build={XP_BUILD}"
RACE_BITS = dict(enumerate(("HUMAN", "ORC", "DWARF", "NIGHT_ELF", "UNDEAD", "TAUREN", "GNOME", "TROLL")))
RACE_BITS.update({32: "SKYBORNE_ALLIANCE", 33: "SKYBORNE_HORDE"})


def _source(build, dataset):
    recent = build in RECENT_REVISION_BUILDS or (build == "1.60.1.70938" and dataset != "quests.enUS")
    revision = REVISION_71139 if recent else REVISION
    return {"estado": "forever", "build": build, "fuente": f"{BASE}{revision}/data/wowf/{build}/{dataset}.json"}


def _read(directory, build_number, dataset):
    build = f"1.60.1.{build_number}"
    path = directory / f"eg-{build}-{dataset}.json"
    raw = path.read_bytes()
    key = build_number, dataset
    source = _source(build, dataset)
    if sha256(raw).hexdigest() != (HASHES.get(key) or EXTRA_HASHES[key]):
        raise ValueError(f"SHA-256 inesperado en {path}. Consulta {source['fuente']}.")
    data = json.loads(raw)
    meta = data["meta"]
    expected = ("wowf", build, dataset.split(".")[0], 1)
    if tuple(meta[k] for k in ("product", "clientBuild", "dataset", "schemaVersion")) != expected:
        raise ValueError(f"Metadatos inesperados en {path}.")
    if dataset == "quests.enUS" and meta.get("locale") != "enUS":
        raise ValueError(f"Idioma inesperado en {path}.")
    return data, source


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
    newer = directory / f"QuestXP-{NEW_BUILD}.csv"
    build = NEW_BUILD if newer.is_file() else XP_BUILD
    path = directory / f"QuestXP-{build}.csv"
    raw = path.read_bytes()
    if sha256(raw).hexdigest() != XP_HASH:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requiere QuestXP de Forever {build}.")
    rows = {int(row["ID"]): row for row in csv.DictReader(raw.decode("utf-8-sig").splitlines())}
    return rows, f"https://wago.tools/db2/QuestXP/csv?build={build}"


def _read_quest_info(directory):
    path = directory / f"QuestInfo-{XP_BUILD}.csv"
    if not path.is_file():
        return {}
    raw = path.read_bytes()
    if sha256(raw).hexdigest() != QUEST_INFO_HASH:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requiere QuestInfo de Forever {XP_BUILD}.")
    return {int(row["ID"]): row["InfoName_lang"] for row in csv.DictReader(raw.decode("utf-8-sig").splitlines())}


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
    if type(row.get("timeLimitSeconds")) is int and row["timeLimitSeconds"] > 0:
        result["limite_segundos"] = row["timeLimitSeconds"]
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


def _quest_type(row, table):
    name = table.get(row.get("questInfoId"))
    if not name:
        return {}
    result = {"tipo_mision": name}
    if name == "Elite":
        result["elite"] = True
    if name in ("Dungeon", "Raid"):
        result["grupo"] = True
    return result


def _positions(rows):
    return [{"m": row["uiMap"], "x": round(100 * row["mapX"], 4), "y": round(100 * row["mapY"], 4)}
            for row in rows if row.get("uiMap", 0) > 0
            and all(type(row.get(axis)) in (int, float) and 0 <= row[axis] <= 1 for axis in ("mapX", "mapY"))
            and (row["mapX"] or row["mapY"])]


def _record_observations(index, key, field, current, source):
    """Conserva muestras de todas las compilaciones sin sumar contadores solapados."""
    entry = index.get(key, {})
    old = entry.get("evidencia", {}).get(field, {})
    links = list(dict.fromkeys([*old.get("fuentes_adicionales", []), old.get("fuente")]))
    sources = [link for link in links if link and link != source["fuente"]]
    if isinstance(current, dict):
        previous = entry.get(field, {})
        merged = {**previous, **{action: _unique_rows(previous.get(action, []), rows)
                                  for action, rows in current.items()}}
    else:
        merged = _unique_rows(entry.get(field, []), current)
    evidence = {**source, "fuentes_adicionales": sources} if sources else source
    _record(index, key, {field: merged}, evidence)


def _unique_rows(previous, samples):
    rows = list(previous)
    for sample in samples:
        if sample not in rows:
            rows.append(sample)
    return rows


def _import_npcs(missions, data, source, npcs=None):
    npcs = {} if npcs is None else npcs
    linked_positions, linked_contacts = {}, {}
    for section, kind in (("npcs", "pnj"), ("objects", "objeto")):
        for key, row in data[section].items():
            if not row.get("sources"):
                continue
            positions = _positions(row.get("positions", []))
            if section == "npcs" and positions:
                _record_observations(npcs, key, "posiciones_observadas", positions, source)
            contact = {"tipo": kind, "id": int(key), "nombre": row.get("name"), "build": source.get("build")}
            for field, action in (("offers", "A"), ("takes", "T")):
                for quest_id in row.get(field, {}):
                    linked_contacts.setdefault(quest_id, {}).setdefault(action, []).append(contact)
                    if positions:
                        linked_positions.setdefault(quest_id, {}).setdefault(action, []).extend(positions)
    for quest_id, actions in linked_contacts.items():
        _record_observations(missions, quest_id, "interlocutores_observados", actions, source)
    for quest_id, actions in linked_positions.items():
        _record_observations(missions, quest_id, "posiciones_observadas", actions, source)
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
            _record_observations(missions, quest_id, "progreso_observado", {"C": positions}, source)
    for quest_id, row in data["gossip"].items():
        _record(missions, quest_id, {"opciones_dialogo_observadas": row}, source)


def _import_turn_ins(missions, data, source):
    for quest_id in data["quests"].keys() | data["withLegacy"].keys():
        observations = [{**{key: row[key] for key in ("level", "race", "faction", "xp", "maxLevel",
                                                       "xpDisabled", "diplomat", "sources") if key in row},
                         "con_legacy": section == "withLegacy", "build": source.get("build")}
                        for section in ("quests", "withLegacy") for row in data[section].get(quest_id, [])]
        if observations:
            _record_observations(missions, quest_id, "entregas_observadas", observations, source)


def _import_scan(missions, data, source):
    for quest_id, row in data["described"].items():
        if row.get("sources"):
            counts = {key: row[key] for key in ("factions", "noDataFactions", "sources") if key in row}
            _record(missions, quest_id, {"escaneo_faccion": counts}, source)
            if "existe" not in missions[quest_id]:
                _record(missions, quest_id, {"existe": True}, source)
    for quest_id in data["noData"]:
        key = str(quest_id)
        recorded = missions.get(key, {}).get("consultas_sin_respuesta", [])
        _record(missions, key, {"consultas_sin_respuesta": [*recorded, source]}, source)
    for quest_id in data["repeatable"]:
        _record(missions, quest_id, {"repetible": True}, source)


def _observed_factions(entry, profiles):
    """Acredita las dos facciones con entregas de una ficha de acceso estable."""
    if not profiles or "facciones" in entry:
        return None
    latest = max(profiles)
    reference = profiles[latest]
    builds = {}
    for sample in entry.get("entregas_observadas", []):
        faction, build = sample.get("faction"), sample.get("build")
        if (faction in ("Alliance", "Horde") and profiles.get(build) == reference
                and sample.get("sources", 0) > 0 and type(sample.get("level")) is int
                and sample["level"] >= reference[1]):
            builds[faction] = max(build, builds.get(faction, build))
    if builds.keys() != {"Alliance", "Horde"}:
        return None
    sources = [_source(build, "turn_ins") for build in sorted(set(builds.values()), reverse=True)]
    detail_builds = sorted({latest, *builds.values()}, reverse=True)
    links = [source["fuente"] for source in sources[1:]]
    links.extend(_source(build, "quests.enUS")["fuente"] for build in detail_builds)
    return {**sources[0], "metodo": "entregas_perfil_estable", "fuentes_adicionales": links}


def import_eg_link(directory):
    missions, npcs, flights = {}, {}, {}
    profiles = {}
    xp_table, xp_source = _read_xp_table(directory)
    quest_info = _read_quest_info(directory)
    extras = {key for key in EXTRA_HASHES if (directory / f"eg-1.60.1.{key[0]}-{key[1]}.json").is_file()}
    datasets = sorted(HASHES.keys() | extras, key=lambda key: (key[1] != "quests.enUS", *key))
    for build, dataset in datasets:
        data, source = _read(directory, build, dataset)
        if dataset == "quests.enUS":
            for quest_id, row in data["quests"].items():
                profiles.setdefault(quest_id, {})[source["build"]] = (row["title"], row["minLevel"], row["raceMask"])
                missions[quest_id] = {"evidencia": {}}
                _record(missions, quest_id, _quest_values(row), source)
                if values := _quest_type(row, quest_info):
                    _record(missions, quest_id, values, {**source, "tabla": QUEST_INFO_SOURCE})
        elif dataset == "npcs":
            _import_npcs(missions, data, source, npcs)
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
            _import_scan(missions, data, source)
    for quest_id, entry in missions.items():
        if qualified := _observed_factions(entry, profiles.get(quest_id)):
            _record(missions, quest_id, {"facciones": ["Alliance", "Horde"]}, qualified)
        xp = _base_xp(entry, xp_table)
        if xp is not None:
            source = {**entry["evidencia"]["componentes_xp"], "tabla": xp_source, "metodo": "calculada"}
            _record(missions, quest_id, {"xp_calculada": xp}, source)
    return {"misiones": missions, "pnj": npcs, "vuelos_observados": flights}

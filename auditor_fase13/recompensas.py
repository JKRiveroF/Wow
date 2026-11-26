"""Contrasta el aprendizaje declarado en las rutas con los efectos de Forever."""

from collections import Counter, defaultdict
import csv
from hashlib import sha256

from mission_rules import _confirmed, _entry, _id, _list


BUILD = "1.60.1.71139"
TABLES = {
    "SpellEffect": "970158fb0ea34695b1d59837a8a612d72b76592f941324372095e1566ea461f2",
    "SkillLineAbility": "ecdc96fca011a72281802b0a10e6e36dbcc9c072c2dfae93b5ceaa9f31aa74e7",
}
EFFECT_SOURCE = f"https://wago.tools/db2/SpellEffect/csv?build={BUILD}"
SKILL_SOURCE = f"https://wago.tools/db2/SkillLineAbility/csv?build={BUILD}"
CLASS_MASKS = {"WARRIOR": 1, "PALADIN": 2, "HUNTER": 4, "ROGUE": 8, "PRIEST": 16,
               "SHAMAN": 64, "MAGE": 128, "WARLOCK": 256, "DRUID": 1024}


def _rows(directory, table):
    path = directory / f"{table}-{BUILD}.csv"
    if not path.is_file():
        return ()
    content = path.read_bytes()
    if sha256(content).hexdigest() != TABLES[table]:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requiere {table} de Forever {BUILD}.")
    return csv.DictReader(content.decode("utf-8-sig").splitlines())


def _learning(effects, skill_abilities):
    recipes = defaultdict(list)
    for row in skill_abilities:
        if row["AcquireMethod"] == "1" and row["RaceMasks_0"] == row["RaceMasks_1"] == "0":
            recipes[int(row["SkillLine"])].append((int(row["Spell"]), int(row["MinSkillLineRank"]), int(row["ClassMask"])))
    taught, unspecified_target, by_skill = defaultdict(set), defaultdict(set), defaultdict(set)
    for row in effects:
        if row["DifficultyID"] != "0":
            continue
        spell = int(row["SpellID"])
        target = row["ImplicitTarget_0"]
        if row["Effect"] == "36" and (learned := int(row["EffectTriggerSpell"])) > 0:
            if target == "1":
                taught[spell].add(learned)
            elif target == row["ImplicitTarget_1"] == "0":
                unspecified_target[spell].add(learned)
        elif row["Effect"] == "44" and target == "1":
            skill, tier = int(row["EffectMiscValue_0"]), float(row["EffectBasePointsF"])
            # El escalón indica el límite de la habilidad. Un personaje que la estrena parte de un punto.
            if skill > 0 and tier >= 1 and tier.is_integer():
                by_skill[spell].update((learned, skill, minimum, classes) for learned, minimum, classes in recipes[skill]
                                       if minimum == 1)
    return {spell: {"directo": sorted(taught[spell]),
                    "por_habilidad": [{"hechizo": learned, "linea": skill, "rango": rank, "mascara_clase": classes}
                                     for learned, skill, rank, classes in sorted(by_skill[spell])],
                    **({"destino_sin_declarar": sorted(unspecified_target[spell])} if spell in unspecified_target else {})}
            for spell in taught.keys() | by_skill.keys() | unspecified_target.keys()}


def load_learning(directory):
    return _learning(_rows(directory, "SpellEffect"), _rows(directory, "SkillLineAbility"))


def _status(entry, spell, class_mask):
    if _confirmed(entry, "aprendizaje_recompensa"):
        learning = entry["aprendizaje_recompensa"]
        if spell in learning["directo"]:
            return "efecto_de_aprendizaje"
        if any(row["hechizo"] == spell and (not row["mascara_clase"] or row["mascara_clase"] & class_mask)
               for row in learning["por_habilidad"]):
            return "aprendizaje_por_habilidad"
        if spell in learning.get("destino_sin_declarar", []):
            return "destino_de_aprendizaje_pendiente"
    if _confirmed(entry, "habilidades_recompensa"):
        reward = entry["habilidades_recompensa"]
        if spell == reward.get("aplicada") or spell in _list(reward.get("mostradas")):
            return "indicio_de_recompensa"
    return "pendiente"


def audit_learning(routes, catalog):
    claims = defaultdict(lambda: defaultdict(set))
    for route in routes:
        route_id = route.get("id") or route["_archivo"]
        class_mask = CLASS_MASKS.get(route.get("clase"), 0)
        for spell in _list(route.get("hechizosExtra")):
            if (not isinstance(spell, dict) or spell.get("origen") != "mision"
                    or not (quest := _id(spell.get("mision"))) or not (spell_id := _id(spell.get("id")))):
                continue
            state = _status(_entry(catalog, quest), spell_id, class_mask)
            claims[quest, spell_id][state].add(route_id)
    rows, counts = [], Counter()
    for (quest, spell), matching in sorted(claims.items()):
        counts[next(iter(matching)) if len(matching) == 1 else "mixto"] += 1
        rows.append({"mision": quest, "hechizo": spell, "rutas_por_estado": {state: sorted(ids) for state, ids in matching.items()}})
    return {"total": len(rows), "resumen": dict(counts), "declaraciones": rows}

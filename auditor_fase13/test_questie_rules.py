import tempfile
import unittest
from hashlib import sha256
from pathlib import Path
from unittest.mock import patch

from catalogo import _merge_catalog, import_quest_v2
from inventario_misiones import inventory_missions
from lua_routes import load_routes
from mission_rules import load_mission_localization
from questie_evidence import import_inherited_spanish_titles
from questie_rules import (BASE, CLASSIC_DB, FIXES, LEGACY_CACHE, LEGACY_FIXES, RELATIONS,
                          _decode, corroborate_inherited_relations, import_quest_rules, observed_objectives)

ROOT = Path(__file__).resolve().parent.parent


class QuestieRulesTest(unittest.TestCase):
    def test_inherited_spanish_compares_labels_without_counting_as_a_live_title(self):
        data = '[7] = {"Misión de la costa", {}},\n'.encode()
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "questie-forever-heredado-esES.lua"
            path.write_bytes(data)
            with patch("questie_evidence.INHERITED_ES_HASH", sha256(data).hexdigest()):
                titles = import_inherited_spanish_titles(path.parent)
        route = {"id": "ruta", "_archivo": "ruta.lua", "secciones": [{"pasos": [{"wp": [
            {"a": "A", "q": 7, "n": "Recoger: Misión de la costa"},
            {"a": "T", "q": 7, "n": "Entregar: Otra misión"},
        ]}]}]}
        report = inventory_missions([route], {"titulos_es_heredados": titles})
        self.assertEqual(report["cobertura"]["nombre_es"], 0)
        quest, = report["misiones"]
        self.assertIn("existe", quest["pendientes_de_fuente"])
        inherited = quest["contraste_es_heredado"]
        self.assertEqual(inherited["estado"], "classic_compatible")
        self.assertEqual(inherited["titulos_guia_distintos"], ["Otra misión"])

    def test_inherited_followup_requires_server_suggestion_and_prior_history(self):
        base = ('    [\'nextQuestInChain\'] = 3,\n[7] = {"name, with {braces}",{{4,5}},12},\n'
                '[8] = {"other",nil,13},\n[9] = {"dynamic",nil,14},\n')
        fixes = ('        [7] = {\n            [questKeys.nextQuestInChain] = 11,\n        },\n'
                 'function C:LoadFactionFixes()\n        [9] = {\n'
                 '            [questKeys.nextQuestInChain] = 3,\n        },\n')
        suggestion = {"estado": "forever", "fuente": "cache"}
        history = {"estado": "forever", "fuente": "observación"}
        catalog = {"misiones": {
            str(q): {"siguiente_sugerida": after, "evidencia": {"siguiente_sugerida": suggestion}}
            for q, after in ((7, 11), (8, 13), (9, 14))}}
        catalog["misiones"].update({str(after): {"misiones_previas_observadas": {"before": before},
                                               "evidencia": {"misiones_previas_observadas": history}}
                                     for after, before in ((11, [7]), (13, [20]), (14, [9]))})
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            sources = {CLASSIC_DB: base, LEGACY_FIXES: fixes, BASE: "", FIXES: "", RELATIONS: ""}
            for name, source in sources.items():
                (directory / (LEGACY_CACHE if name == LEGACY_FIXES else Path(name).name)).write_bytes(source.encode())
            with patch("questie_rules.HASHES", {name: sha256(source.encode()).hexdigest() for name, source in sources.items()}):
                result = corroborate_inherited_relations(directory, catalog)["misiones"]
        self.assertEqual(set(result), {"7"})
        self.assertEqual(result["7"]["seguimientos"], [11])
        self.assertNotIn("prerrequisitos", result["7"])
        self.assertIn(LEGACY_FIXES, result["7"]["evidencia"]["seguimientos"]["fuentes_adicionales"][0])

    def test_inherited_requirement_needs_matching_gate_and_strong_observed_offer(self):
        base = "    ['preQuestSingle'] = 2,\n" + "\n".join(
            f'[{quest}] = {{"quest",{{{prior}}}}},' for quest, prior in ((7, 9), (8, 9), (10, 11), (12, 9), (13, 9)))
        traces = "\n".join(
            f"        -- [{quest}] = {{\n"
            f"            -- already in QuestieDB; Assumption: offered right after 9 was turned in "
            f"(handoff, offer-set{', absence' if absence else ''}; very high; 100+ characters)\n"
            f"            -- [questKeys.preQuestSingle] = {{9}},\n        -- }},"
            for quest, absence in ((7, True), (8, False), (10, True), (12, True), (13, True)))
        fixes = "        [12] = {\n            [questKeys.preQuestGroup] = {},\n        },\n"
        catalog = {"misiones": {str(quest): {"existe": True} for quest in (7, 8, 10, 12)}}
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            sources = {CLASSIC_DB: base, LEGACY_FIXES: "function C:LoadFactionFixes()\n",
                       BASE: "", FIXES: fixes, RELATIONS: traces}
            for name, source in sources.items():
                (directory / (LEGACY_CACHE if name == LEGACY_FIXES else Path(name).name)).write_bytes(source.encode())
            with patch("questie_rules.HASHES", {name: sha256(source.encode()).hexdigest() for name, source in sources.items()}):
                result = corroborate_inherited_relations(directory, catalog)["misiones"]
        self.assertEqual(set(result), {"7"})
        self.assertEqual(result["7"]["prerrequisitos_alternativos"], [9])
        self.assertIn(RELATIONS, result["7"]["evidencia"]["prerrequisitos_alternativos"]["fuente"])

    def test_client_quest_index_does_not_supply_server_availability(self):
        raw = b"ID,UniqueBitFlag,UiQuestDetailsThemeID\n42,4,0\n"
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "QuestV2.csv"
            path.write_bytes(raw)
            with patch("catalogo.QUEST_V2_HASH", sha256(raw).hexdigest()):
                quest_v2 = import_quest_v2(path)
                path.write_bytes(raw + b"7,1,0\n")
                with self.assertRaises(ValueError):
                    import_quest_v2(path)

        source = {"estado": "forever", "fuente": "servidor"}
        catalog = {"misiones": {"7": {**source, "existe": True}}}
        routes = [{"id": "ruta", "_archivo": "ruta.lua",
                   "secciones": [{"pasos": [{"wp": [{"q": 7, "a": "A"}, {"q": 42, "a": "A"}]}]}]}]
        result = inventory_missions(routes, catalog, quest_v2)
        offered, registered = result["misiones"]
        self.assertFalse(offered["fila_questv2"])
        self.assertTrue(offered["evidencia"]["existe"]["valor"])
        self.assertTrue(registered["fila_questv2"])
        self.assertIn("existe", registered["pendientes_de_fuente"])

    def test_static_priority_and_inferred_separation(self):
        rows = {
            BASE: '        [7] = {\n            [questKeys.requiredClasses] = classIDs.WARRIOR,\n        },\n',
            FIXES: '        [7] = {\n            [questKeys.requiredClasses] = classIDs.HUNTER,\n        },\n',
            RELATIONS: '        [7] = {\n            [questKeys.preQuestSingle] = {10,20},\n        },\n',
        }
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for name, content in rows.items():
                (directory / Path(name).name).write_bytes(content.encode())
            hashes = {name: sha256(content.encode()).hexdigest() for name, content in rows.items()}
            with patch("questie_rules.HASHES", hashes):
                result = import_quest_rules(directory)
        self.assertEqual(result["misiones"]["7"]["clases"], ["HUNTER"])
        self.assertNotIn("prerrequisitos_alternativos", result["misiones"]["7"])
        self.assertEqual(result["candidatos_por_mision"]["7"][0]["valor"], [10, 20])

    def test_alternative_prerequisite_and_racial_profiles(self):
        self.assertEqual(_decode("preQuestGroup", "{1, 2}"), {"prerrequisitos": [1, 2]})
        self.assertEqual(_decode("preQuestSingle", "{1, 2}"), {"prerrequisitos_alternativos": [1, 2]})
        result = _decode("requiredRaces", "raceIDs.SKYBORNE_ALLIANCE + raceIDs.ORC")
        self.assertEqual(result["razas_por_faccion"], {"Alliance": ["Skyborne"], "Horde": ["Orc"]})
        self.assertEqual(_decode("requiredRaces", "raceIDs.ALL_HORDE + raceIDs.ORC"), {})
        self.assertEqual(observed_objectives("{{{99}},nil,{{280841},{280839}}}"), [280839, 280841])
        self.assertIsNone(observed_objectives("nil"))

    def test_localization_merge_and_mission_deduplication(self):
        source = {"estado": "forever", "fuente": "datos de prueba"}
        old = {"misiones": {"7": {"nombres": {"en": "Name"}, "evidencia": {"nombre_en": source}}}}
        new = {"misiones": {"7": {"nombres": {"es": ["Nombre"]}, "evidencia": {"nombre_es": source}}}}
        catalog = _merge_catalog(old, new)
        waypoint = {"q": 7, "a": "A", "m": 1, "x": 10, "y": 20}
        routes = [{"id": route_id, "_archivo": route_id + ".lua",
                   "secciones": [{"pasos": [{"wp": [waypoint]}]}]} for route_id in ("ruta_a", "ruta_b")]
        result = inventory_missions(routes, catalog)
        self.assertEqual(result["total"], 1)
        self.assertEqual(result["cobertura"]["nombre_en"], 1)
        self.assertEqual(result["cobertura"]["nombre_es"], 1)
        row = result["misiones"][0]
        self.assertEqual(row["rutas"], ["ruta_a", "ruta_b"])
        self.assertEqual(row["acciones"], {"A": 2})
        self.assertEqual(row["posiciones"][0]["rutas"], 2)


class QuestChainRegressionTest(unittest.TestCase):
    def test_water_chain_and_blackrock_prerequisite(self):
        addon = ROOT / "GuiaAventurero"
        routes, errors = load_routes(addon)
        self.assertEqual(errors, [])
        translations = load_mission_localization(addon)["por_nombre"]
        steps_blackrock = 0
        for route in routes:
            steps = [step for section in route["secciones"] for step in section["pasos"]]
            points = [(index, wp["q"], wp["a"]) for index, step in enumerate(steps)
                      for wp in step.get("wp", []) if "q" in wp]
            if route["_faccion"] == "Alliance":
                block = [(index, action) for index, quest, action in points if quest == 98387]
                self.assertEqual([action for _, action in block], ["A", "T"])
                idx = block[0][0]
                self.assertEqual(idx, block[1][0])
                self.assertIn((idx, 20, "T"), points)
                self.assertTrue(all(idx < step for step, quest, action in points if quest in {19, 115} and action == "A"))
                self.assertIn("8 stolen weapons", translations[steps[idx]["t"]])
                steps_blackrock += 1
            if route["id"] == "enano_chaman":
                expected = [(quest, action) for quest in (94497, 94499, 94500) for action in ("A", "C", "T")]
                water = [(idx, quest, action) for idx, quest, action in points if quest in {94497, 94499, 94500}]
                self.assertEqual([(quest, action) for _, quest, action in water], expected)
                self.assertEqual(water[2][0], water[3][0])
                self.assertEqual(water[5][0], water[6][0])
                self.assertIn("accept the red waterskin quest", translations[steps[water[2][0]]["t"]])
                self.assertIn("accept the blue waterskin quest", translations[steps[water[5][0]]["t"]])
        self.assertEqual(steps_blackrock, 25)


if __name__ == "__main__":
    unittest.main()

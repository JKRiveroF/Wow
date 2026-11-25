import tempfile
import unittest
from hashlib import sha256
from pathlib import Path
from unittest.mock import patch

from catalogo import _merge_catalog
from inventario_misiones import inventory_missions
from lua_routes import load_routes
from mission_rules import load_mission_localization
from questie_rules import BASE, FIXES, RELATIONS, _decode, import_quest_rules, observed_objectives

ROOT = Path(__file__).resolve().parent.parent


class QuestieRulesTest(unittest.TestCase):
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

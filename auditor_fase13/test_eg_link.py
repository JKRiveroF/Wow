"""Comprueba la interpretación de los datos públicos de Forever."""

import unittest

from eg_link import _base_xp, _import_npcs, _import_objectives, _import_scan, _import_turn_ins, _quest_values, _race_fields
from inventario_misiones import _coordinate_result
from vuelos_observados import link_flights


class EGLinkTests(unittest.TestCase):
    def test_missing_scan_reply_does_not_erase_identity(self):
        missions = {}
        _import_scan(missions, {"described": {"1": {"sources": 1}}, "noData": [2], "repeatable": {}},
                     {"estado": "forever", "fuente": "71037"})
        _import_scan(missions, {"described": {}, "noData": [1, 2], "repeatable": {}},
                     {"estado": "forever", "fuente": "71091"})
        self.assertTrue(missions["1"]["existe"])
        self.assertNotIn("existe", missions["2"])
        self.assertEqual([row["fuente"] for row in missions["2"]["consultas_sin_respuesta"]], ["71037", "71091"])

    def test_records_are_not_interpreted_as_prerequisites_or_effective_xp(self):
        entry = _quest_values({
            "title": "Key to the City", "minLevel": 30, "level": 33, "raceMask": "aa2aaaaa4e0ab3b2",
            "nextQuestId": 545, "objectives": [{"type": "item", "objectId": 279469, "amount": 1}],
            "rewards": {"xpDifficulty": 0, "xpMultiplier": 1.0},
        })
        self.assertEqual(entry["siguiente_sugerida"], 545)
        self.assertNotIn("prerrequisitos", entry)
        self.assertEqual(entry["cantidades_objetivo"], {"279469": 1})
        self.assertEqual(entry["facciones"], ["Horde"])
        self.assertEqual(_race_fields("0000000100000000")["razas_por_faccion"], {"Alliance": ["Skyborne"]})
        self.assertEqual(_race_fields("0000000300000000")["facciones"], ["Alliance", "Horde"])
        self.assertEqual(_race_fields("ffffffffffffffff"), {})
        self.assertIsNone(_base_xp(entry, {}))
        self.assertEqual(_base_xp(entry, {33: {"Difficulty_0": "0"}}), 0)
        self.assertNotIn("xp", entry)
        observations = {}
        _import_turn_ins(observations, {"quests": {"1": [{"xp": 525, "level": 9, "sources": 1}]},
                                        "withLegacy": {}}, {"estado": "forever", "fuente": "entregas"})
        self.assertNotIn("xp", observations["1"])
        self.assertEqual(observations["1"]["entregas_observadas"][0]["xp"], 525)

    def test_positions_use_matching_ui_map_and_preserve_action(self):
        evidence = {"estado": "forever", "fuente": "posiciones"}
        there = {"uiMap": 2521, "mapX": 0.4525, "mapY": 0.4525}
        missions = {}
        _import_npcs(missions, {"npcs": {"1": {"offers": {"2": {}}, "sources": 1, "positions": [there]}},
                                "objects": {}}, evidence)
        _import_objectives(missions, {"quests": {"2": {"1": {"gains": 3, "sources": 1, "positions": [there]}}},
                                      "completed": {}, "gossip": {}}, evidence)
        mission = missions["2"]
        self.assertEqual(_coordinate_result(mission, "A", (2521, 45.2, 45.2)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(mission, "C", (2521, 45.2, 45.2)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(mission, "T", (2521, 45.2, 45.2)), "investigacion")
        self.assertEqual(_coordinate_result(mission, "C", (2522, 45.2, 45.2)), "investigacion")

    def test_flights_match_npc_and_keep_talent_and_direction(self):
        def steps(names):
            return [{"wp": [{"npc": npc}], "comprobar": {"vuelo": name}} for name, npc in names]

        routes = [
            {"_faccion": "Alliance", "secciones": [{"pasos": steps([("A", 111), ("B", 222), ("C", 333)])}]},
            {"_faccion": "Horde", "secciones": [{"pasos": steps([("A", 444), ("B", 555)])}]},
        ]
        data = {"fuente": "flights", "build": "71037",
                "maestros": {str(n * 111): {"node": n, "sources": 1} for n in (1, 2, 4)},
                "conexiones": {"1>2|frequentFlier:1": {"seconds": {"62": 2}}, "1>3": {"sources": 1},
                               "2>4": {"seconds": {"30": 1}}}}
        report = link_flights(routes, data)
        self.assertEqual(report["nodos_sin_indicio"], {"Alliance": ["C"], "Horde": ["B"]})
        self.assertEqual(report["conexiones"]["Horde"], {})
        alliance = report["conexiones"]["Alliance"]
        self.assertEqual(list(alliance), ["1>2|frequentFlier:1"])
        self.assertEqual(alliance["1>2|frequentFlier:1"]["talento"], "frequentFlier:1")

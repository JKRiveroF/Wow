"""Comprueba la interpretación de los datos públicos de Forever."""

import unittest

from eg_link import (NEW_BUILD, REVISION_71139, XP_BUILD, _base_xp, _import_npcs, _import_objectives,
                     _import_scan, _import_turn_ins, _quest_type, _quest_values, _race_fields, _source)
from inventario_misiones import _coordinate_result
from vuelos_observados import link_flights


class EGLinkTests(unittest.TestCase):
    def test_newer_quest_snapshot_links_to_its_own_revision(self):
        current = _source(NEW_BUILD, "quests.enUS")
        previous = _source(XP_BUILD, "quests.enUS")
        self.assertIn(REVISION_71139, current["fuente"])
        self.assertNotIn(REVISION_71139, previous["fuente"])
        self.assertTrue(current["fuente"].endswith(f"/{NEW_BUILD}/quests.enUS.json"))

    def test_early_live_snapshots_link_to_the_revision_with_verified_hashes(self):
        for build in ("1.60.1.70790", "1.60.1.70862", "1.60.1.70888"):
            for dataset in ("npcs", "quest_scan"):
                with self.subTest(build=build, dataset=dataset):
                    source = _source(build, dataset)
                    self.assertIn(f"/{REVISION_71139}/data/wowf/{build}/{dataset}.json", source["fuente"])

    def test_quest_info_distinguishes_elite_dungeon_and_unclassified_quests(self):
        table = {1: "Elite", 41: "PvP", 62: "Raid", 81: "Dungeon"}
        self.assertEqual(_quest_type({"questInfoId": 1}, table), {"tipo_mision": "Elite", "elite": True})
        self.assertEqual(_quest_type({"questInfoId": 62}, table), {"tipo_mision": "Raid", "grupo": True})
        self.assertEqual(_quest_type({"questInfoId": 81}, table), {"tipo_mision": "Dungeon", "grupo": True})
        self.assertEqual(_quest_type({"questInfoId": 41}, table), {"tipo_mision": "PvP"})
        self.assertEqual(_quest_type({}, table), {})

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

    def test_multiple_snapshots_preserve_actions_positions_and_turn_in_context(self):
        older = {"estado": "forever", "fuente": "primera", "build": "1.60.1.70959"}
        newer = {"estado": "forever", "fuente": "segunda", "build": "1.60.1.71037"}
        there = {"uiMap": 2521, "mapX": 0.45, "mapY": 0.45}
        here = {"uiMap": 2521, "mapX": 0.55, "mapY": 0.45}
        missions = {}
        npcs = _import_npcs(missions, {"npcs": {"1": {"offers": {"2": {}}, "sources": 1,
                                                     "positions": [there]}}, "objects": {}}, older)
        _import_npcs(missions, {"npcs": {"1": {"takes": {"2": {}}, "sources": 1,
                                               "positions": [there, here]}}, "objects": {}}, newer, npcs)
        mission = missions["2"]
        self.assertEqual({a: len(points) for a, points in mission["posiciones_observadas"].items()}, {"A": 1, "T": 2})
        self.assertEqual(len(npcs["1"]["posiciones_observadas"]), 2)
        self.assertEqual(mission["evidencia"]["posiciones_observadas"]["fuentes_adicionales"], ["primera"])

        sample = {"xp": 525, "level": 9, "sources": 1}
        _import_turn_ins(missions, {"quests": {"2": [sample]}, "withLegacy": {}}, older)
        _import_turn_ins(missions, {"quests": {}, "withLegacy": {"2": [sample]}}, newer)
        self.assertEqual([(row["build"], row["con_legacy"], row["sources"])
                          for row in mission["entregas_observadas"]],
                         [("1.60.1.70959", False, 1), ("1.60.1.71037", True, 1)])

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

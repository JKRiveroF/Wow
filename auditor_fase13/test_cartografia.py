"""Regresión de las etiquetas de Alterac y de los datos de vuelo compartidos."""

import unittest
from pathlib import Path
from unittest.mock import patch

from lupa.lua51 import LuaRuntime

from catalogo import read_catalog
from contactos import NPC_TRACES, OBJECT_TRACES, QUESTS, link_contacts
from inventario_misiones import _coordinate_result
from lua_routes import load_routes
from mission_rules import load_mission_localization


ADDON = Path(__file__).resolve().parent.parent / "GuiaAventurero"


class MapRegressionTest(unittest.TestCase):
    def test_contact_trace_preserves_entity_type_action_and_canonical_map(self):
        sources = {
            NPC_TRACES: """        [7] = {
            [npcKeys.spawns] = {[12]={{42.1,41.1}},[99]={{42.1,41.1}}},
            [npcKeys.questStarts_add] = {100},
        },""",
            OBJECT_TRACES: """        [7] = {
            [objectKeys.spawns] = {[12]={{80,80}}},
            [objectKeys.questEnds_add] = {100},
        },""",
            QUESTS: "",
        }
        catalog = {"mapas": {"1429": {"area": 12, "existe": True}, "1": {"area": 99, "existe": True},
                             "2": {"area": 99, "existe": True}}, "misiones": {"100": {}}}
        with patch("contactos._lines", side_effect=lambda _, name: sources[name].splitlines()), patch("contactos._read", return_value=[]):
            result = link_contacts(ADDON.parent, catalog)
        mission = result["misiones"]["100"]
        accept, = mission["referencias_interaccion"]["A"]
        delivery, = mission["referencias_interaccion"]["T"]
        self.assertEqual((accept["id"], accept["tipo"], accept["m"]), (7, "pnj", 1429))
        self.assertEqual((delivery["id"], delivery["tipo"], delivery["m"]), (7, "objeto", 1429))
        self.assertEqual(_coordinate_result(mission, "A", (1429, 42, 41)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(mission, "T", (1429, 42, 41)), "investigacion")
        self.assertIn("#L2", result["pnj"]["7"]["evidencia"]["posiciones_trazas"]["fuente"])

    def test_static_contact_requires_current_title_and_respects_corrections(self):
        sources = {NPC_TRACES: "", OBJECT_TRACES: "", QUESTS: "\n".join(
            f'[{quest}] = {{"Quest",{{{{7}}}},{{{{7}}}}}},' for quest in range(100, 105))}
        corrections = """        [101] = {
            [questKeys.startedBy_remove] = {{7}},
        },
        [102] = {
            [questKeys.startedBy] = {{8}},
        },
function C:LoadDynamic()
        [103] = {
            [questKeys.startedBy] = {{8}},
        },"""
        evidence = {"estado": "forever", "fuente": "título"}
        missions = {str(quest): {"existe": True, "nombres": {"en": "Otro título" if quest == 104 else "Quest"},
                                  "evidencia": {"nombre_en": evidence}} for quest in range(100, 105)}
        position = {"m": 1429, "x": 42.1, "y": 41.1, "fuente": "posición de Forever", "build": "1.60.1.71139"}
        catalog = {"misiones": missions, "entidades_interaccion": {"pnj": {7: [position], 8: [position]}}}
        with patch("contactos._lines", side_effect=lambda _, name: sources[name].splitlines()), \
                patch("contactos._read", return_value=corrections.splitlines()):
            result = link_contacts(ADDON.parent, catalog)["misiones"]
        self.assertNotIn("104", result)
        self.assertEqual(set(result["101"]["referencias_interaccion"]), {"T"})
        self.assertEqual(set(result["103"]["referencias_interaccion"]), {"T"})
        accepted, = result["102"]["referencias_interaccion"]["A"]
        self.assertEqual((accepted["id"], accepted["metodo_interaccion"]), (8, "catalogo_estatico"))
        self.assertIn("foreverQuestFixes.lua", accepted["fuente_interaccion"])

    def test_reprojected_points_provide_partial_evidence_for_the_documented_action(self):
        records = read_catalog(ADDON.parent / "auditor_fase13" / "cartografia_forever.json")["misiones"]
        self.assertEqual(_coordinate_result(records["1486"], "T", (1413, 46, 35.7)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(records["6563"], "C", (1440, 13.5, 12.3)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(records["6563"], "T", (1440, 13.5, 12.3)), "investigacion")

    def test_alterac_keeps_map_points_and_both_names(self):
        routes, errors = load_routes(ADDON)
        self.assertEqual(errors, [])
        points = [point for route in routes for section in route["secciones"]
                  for step in section["pasos"] for point in step.get("wp", []) if point.get("m") == 1459]
        self.assertEqual(len(points), 523)
        self.assertEqual({point.get("z") for point in points}, {"Valle de Alterac"})
        localization = load_mission_localization(ADDON)
        self.assertEqual(localization["por_nombre"]["Valle de Alterac"], "Alterac Valley")

    def test_optional_quest_still_loads_in_both_factions(self):
        lua = LuaRuntime(register_eval=False, register_builtins=False)
        lua.execute((ADDON / "OpcionalesKalimdor.lua").read_text(encoding="utf-8"))
        for faction, index in (("Alliance", "opcionalesNuevas"), ("Horde", "opcionalesNuevasH")):
            payload = lua.globals().GuiaAventurero_Datos.Kalimdor[faction]
            quest = lua.execute(payload)[index][3520]
            self.assertEqual([point.a for _, point in sorted(quest.wp.items())], ["A", "T"])

    def test_primary_flight_records_match_route_coordinates(self):
        records = (ADDON / "Datos94.lua").read_text(encoding="utf-8")
        spots = {352: (1453, 71.3, 72.2), 931: (1433, 25.5, 59.4)}
        for npc_id, (map_id, x, y) in spots.items():
            self.assertRegex(records, rf"\{{ npc = {npc_id}, [^\n]+m = {map_id}, x = {x}, y = {y},")

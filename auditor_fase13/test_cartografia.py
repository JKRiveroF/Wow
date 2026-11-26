"""Regresión de las etiquetas de Alterac y de los datos de vuelo compartidos."""

import unittest
from pathlib import Path

from lupa.lua51 import LuaRuntime

from catalogo import read_catalog
from inventario_misiones import _coordinate_result
from lua_routes import load_routes
from mission_rules import load_mission_localization


ADDON = Path(__file__).resolve().parent.parent / "GuiaAventurero"


class MapRegressionTest(unittest.TestCase):
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

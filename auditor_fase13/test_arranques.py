"""Contraste de arranques de Forever y compatibilidad de la introducción gnoma."""

import json
from pathlib import Path
import unittest

from arranques import audit_arranques
from lua_routes import load_routes
from test_perfiles_forever import ADDON, lua_for_addon


CATALOG = json.loads(Path(__file__).with_name("arranques_forever.json").read_text(encoding="utf-8"))
PRIEST_ROUTE = "Rutas/EnanoGnomoSacerdote.lua"


def _priest_route(race):
    lua, module, load = lua_for_addon()
    lua.globals()["raza_arranque"] = race
    module["Raza"] = lua.eval("function() return raza_arranque end")
    load("Idioma.lua")
    for name in (ADDON / "GuiaAventurero.toc").read_text(encoding="utf-8-sig").splitlines():
        if name.startswith("Idioma\\"):
            load(name.replace("\\", "/"))
    load(PRIEST_ROUTE)
    route = lua.globals()["GuiaAventurero_Rutas"][1]
    route["cargar"](route)

    source = (ADDON / "GuiaAventurero.lua").read_text(encoding="utf-8").split("local function ListarRutas()", 1)[0]
    engine = "local function AdaptarARaza(R)" + source.split("local function AdaptarARaza(R)", 1)[1]
    adapt = lua.execute("local GL = ...\n" + engine + "\nreturn AdaptarARaza", module)
    adapt(route)
    return module, route


class ArranquesTest(unittest.TestCase):
    def test_all_non_skyborne_routes_match_observed_starters(self):
        routes, errors = load_routes(ADDON)
        self.assertFalse(errors)
        routes = [route for route in routes if "Skyborne" not in route["razas"]]
        self.assertEqual(len(routes), 37)
        self.assertEqual(sum(len(route["razas"]) for route in routes), 46)
        for route in routes:
            with self.subTest(route=route["id"]):
                self.assertEqual(audit_arranques(route, CATALOG), [])

    def test_early_pickup_and_wrong_race_are_detected(self):
        points = [
            {"m": 1426, "q": 179, "a": "A"},
            {"m": 1426, "q": 179, "a": "C"},
            {"m": 1426, "q": 98574, "a": "A"},
            {"m": 1426, "q": 179, "a": "T"},
            {"m": 1426, "q": 98574, "a": "T"},
            {"m": 1426, "q": 233, "a": "A"},
            {"m": 1426, "q": 233, "a": "T"},
        ]
        route = {
            "_archivo": PRIEST_ROUTE, "id": "enano_gnomo_sacerdote",
            "razas": ["Dwarf", "Gnome"], "clase": "PRIEST",
            "secciones": [{"min": 1, "pasos": [{"wp": points}]}],
        }
        findings = audit_arranques(route, CATALOG)
        self.assertEqual({finding["codigo"] for finding in findings}, {
            "ARRANQUE_MISION_CLASE_INCOMPATIBLE",
            "ARRANQUE_MISION_CLASE_ANTES_DE_REQUISITO",
        })

        points[:] = [point for point in points if point["q"] != 98574]
        self.assertEqual([finding["codigo"] for finding in audit_arranques(route, CATALOG)],
                         ["ARRANQUE_MISION_CLASE_AUSENTE"])

    def test_racial_pickup_indices_and_english_translation(self):
        for race, quest, index, title in (("Gnome", 98574, 5, "Hallowed Memorandum"),
                                          ("Dwarf", 3110, 3, "Hallowed Rune")):
            with self.subTest(race=race):
                module, route = _priest_route(race)
                steps = route["secciones"][1]["pasos"]
                self.assertEqual([steps[2]["wp"][i]["q"] for i in range(1, len(steps[2]["wp"]) + 1)],
                                 [179, 179, 233, 170, 98574] if race == "Gnome" else [179, 179, 3110, 233, 170])
                pickup, turn_in = steps[2]["wp"][index], steps[3]["wp"][1]
                self.assertEqual(len(steps[3]["wp"]), 1)
                self.assertEqual([(item["q"], item["a"]) for item in (pickup, turn_in)], [(quest, "A"), (quest, "T")])
                self.assertEqual(steps[3]["comprobar"]["hechizos"][1], 1243)
                module["TraducirRuta"](route)
                self.assertIn(f"[{title}]", steps[2]["t"])
                self.assertIn("Learn Power Word: Fortitude", steps[3]["t"])
                self.assertIn(title, pickup["n"])
                self.assertIn(title, turn_in["n"])


if __name__ == "__main__":
    unittest.main()

"""Pruebas de los perfiles Skyborne con el cargador y la localización del addon."""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ADDON = Path(__file__).resolve().parents[1] / "GuiaAventurero"


def lua_for_addon(faction="Alliance"):
    lua = LuaRuntime(register_eval=False, register_builtins=False)
    lua.globals()["faction"] = faction
    lua.execute('''
        function CreateFrame() return { RegisterEvent = function () end, SetScript = function () end } end
        function GetLocale() return "enUS" end
        function UnitFactionGroup() return faction end
    ''')
    execute = lua.eval('''
        function (source, filename, module)
            return assert(loadstring(source, "@" .. filename))("GuiaAventurero", module)
        end
    ''')
    module = lua.eval('''
        { colores = {}, L = function (value) return value end, alIniciar = {}, Evento = function () end }
    ''')

    def load(path):
        execute((ADDON / path).read_text(encoding="utf-8-sig"), str(path), module)

    return lua, module, load


class ForeverProfilesTest(unittest.TestCase):
    def test_ten_skyborne_training_texts_translate_with_addon_engine(self):
        lua, module, load = lua_for_addon()
        load("Idioma.lua")
        entries = (ADDON / "GuiaAventurero.toc").read_text(encoding="utf-8-sig").splitlines()
        for name in entries:
            if name.startswith("Idioma\\"):
                load(name.replace("\\", "/"))

        route_paths = sorted((ADDON / "Rutas").glob("Skyborne*.lua"))
        self.assertEqual(len(route_paths), 10)
        for path in route_paths:
            with self.subTest(path=path.name):
                lua.globals()["GuiaAventurero_Rutas"] = lua.table()
                load(path.relative_to(ADDON))
                route = lua.globals()["GuiaAventurero_Rutas"][1]
                route["cargar"](route)
                section = route["secciones"][1]
                original = section["entrenar"]
                module["TraducirRuta"](route)
                english = section["entrenar"]
                self.assertNotEqual(english, original)
                if route["faccion"] == "Horde":
                    self.assertIn("Charged durante una hora", original)
                    self.assertIn("Charged for an hour", english)
                    self.assertIn("activating Skysight increases your movement speed by 30%", english)
                    self.assertNotIn("30% for an hour", english)
                else:
                    self.assertIn("Attuned durante una hora", original)
                    self.assertIn("Attuned for an hour", english)
                    self.assertIn("50% for 15 seconds", english)
                    self.assertIn("100% for 15 seconds", english)

    def test_camping_herbalism_uses_shendar_when_horde_payload_loads(self):
        for faction in ("Alliance", "Horde"):
            with self.subTest(faction=faction):
                _, module, load = lua_for_addon(faction)
                load("OpcionalesOtras.lua")
                load("Continentes.lua")
                self.assertTrue(module["CargarContinente"]("Otras"))
                quests = module["WH"]["opcionalesNuevasH"]
                if faction == "Alliance":
                    self.assertIsNone(quests)
                    continue

                waypoints = quests[97968]["wp"]
                destinations = [waypoints[index] for index in range(1, len(waypoints) + 1)]
                self.assertEqual([(point["a"], point["m"], point["x"], point["y"]) for point in destinations],
                                 [("A", 2521, 41.7, 44.8), ("C", 2521, 43, 43.6), ("T", 2521, 43, 43.6)])
                self.assertTrue(destinations[0]["n"].endswith("(Raan Wildwind)"))
                self.assertTrue(destinations[2]["n"].endswith("(Halassa Fernbreeze)"))


if __name__ == "__main__":
    unittest.main()

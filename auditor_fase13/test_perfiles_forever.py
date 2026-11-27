"""Pruebas del cargador, la localización y las opcionales por perfil."""

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
    def test_waypoint_translates_a_title_with_parentheses_before_the_npc(self):
        lua, module, load = lua_for_addon("Horde")
        load("Idioma.lua")
        load("Idioma/enUS_Datos.lua")
        waypoint = lua.table_from({"m": 1421, "n": "Entregar: Vuelve con Quinn (de nuevo) (Quinn Yorick)",
                                    "q": 91921, "a": "T"})
        module["TraducirDestino"](waypoint)
        self.assertEqual(waypoint["n"], "Turn in: Return to Quinn (Again) (Quinn Yorick)")

    def test_waypoint_translates_a_nested_npc_name_after_the_mission_title(self):
        lua, module, load = lua_for_addon("Horde")
        load("Idioma.lua")
        module["AnadirIngles"](lua.table_from({"Nombre de misión (variación)": "Quest Name (Variant)",
                                             "Guía (veterano)": "Guide (Veteran)"}))
        waypoint = lua.table_from({"n": "Entregar: Nombre de misión (variación) (Guía (veterano))"})
        module["TraducirDestino"](waypoint)
        self.assertEqual(waypoint["n"], "Turn in: Quest Name (Variant) (Guide (Veteran))")

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

    def test_kumisha_optionals_follow_level_and_turn_ins_across_continents(self):
        chain = [
            (1389, 30, [1435, 1435, 1435]),
            (93464, 30, [1435, 1443]),
            (93465, 30, [1443, 1443, 1443]),
            (93678, 30, [1443, 1435]),
            (93679, 45, [1435, 1435, 1435]),
            (93684, 45, [1435, 1419]),
        ]
        for faction, locale, index in (("Alliance", "esES", "opcionalesNuevas"),
                                       ("Horde", "enUS", "opcionalesNuevasH")):
            with self.subTest(faction=faction):
                lua, module, load = lua_for_addon(faction)
                lua.globals()["locale"] = locale
                lua.execute("""
                    GuiaAventureroDB = { estiloRuta = "completa" }
                    completadas = {}
                    function GetLocale() return locale end
                    function UnitLevel() return nivel end
                """)
                module["tarjetasGuia"] = lua.table()
                module["PosicionJugador"] = lua.eval("function() return mapa end")
                module["MisionCompletada"] = lua.eval("function(q) return completadas[q] end")
                module["MisionEnDiario"] = lua.eval("function(q) return activa == q end")
                module["DestinoHecho"] = lua.eval(
                    'function(w) return (w.a == "A" and activa == w.q) or (w.a == "C" and objetivo) end'
                )
                for name in ("Idioma.lua", "Idioma/enUS_Datos.lua", "OpcionalesOtras.lua",
                             "OpcionalesReinos.lua", "Continentes.lua", "Opcionales.lua"):
                    load(name)
                self.assertTrue(module["CargarContinente"]("Otras"))
                optional = module["WH"][index]
                crystal_quest = optional[1389]
                self.assertTrue(module["CargarContinente"]("Reinos"))
                self.assertEqual(optional[1389]["nivelMinimo"], crystal_quest["nivelMinimo"])

                def candidate(quest):
                    return next((row for row in module["_opcionales"]().values() if row["q"] == quest), None)

                previous = None
                for quest, minimum, maps in chain:
                    with self.subTest(quest=quest):
                        self.assertEqual([point["m"] for point in optional[quest]["wp"].values()], maps)
                        lua.globals()["mapa"] = maps[0]
                        lua.globals()["nivel"] = minimum
                        if previous:
                            lua.globals()["activa"] = previous
                            self.assertIsNone(candidate(quest))
                            lua.globals()["activa"] = None
                            lua.globals()["completadas"][previous] = True
                        lua.globals()["nivel"] = minimum - 1
                        self.assertIsNone(candidate(quest))
                        lua.globals()["nivel"] = minimum
                        self.assertIsNotNone(candidate(quest))
                        previous = quest

                lua.globals()["mapa"] = 1419
                lua.globals()["activa"] = 93684
                landing = candidate(93684)["w"]
                self.assertEqual((landing["a"], landing["m"], landing["x"], landing["y"]), ("T", 1419, 52, 35.6))
                expected = ("Turn in: The Found One (Kum'isha the Collector)" if locale == "enUS"
                            else "Entregar: El Encontrado (Kum'isha el Coleccionista)")
                self.assertEqual(landing["n"], expected)
                lua.globals()["GuiaAventureroDB"]["estiloRuta"] = "rapida"
                self.assertIsNone(candidate(93684))

    def test_skyborne_aquatic_form_uses_faction_chain_and_requires_druid_level_16(self):
        for faction, chain, city, route_name in (
            ("Alliance", [26, 29, 272, 5061], 1457, "SkyborneADruida.lua"),
            ("Horde", [27, 28, 30, 31], 1456, "SkyborneDruida.lua"),
        ):
            with self.subTest(faction=faction):
                lua, module, load = lua_for_addon(faction)
                lua.execute("""
                    GuiaAventureroDB = { estiloRuta = "completa" }
                    completadas = {}
                    function UnitLevel() return nivel end
                    function UnitClass() return "class", clase end
                """)
                module["tarjetasGuia"] = lua.table()
                module["Raza"] = lua.eval("function() return raza end")
                module["PosicionJugador"] = lua.eval("function() return mapa end")
                module["MisionCompletada"] = lua.eval("function(q) return completadas[q] end")
                module["MisionEnDiario"] = lua.eval("function(q) return activa == q end")
                module["DestinoHecho"] = lua.eval('function(w) return w.a == "A" and activa == w.q end')
                for name in ("Idioma.lua", "Idioma/enUS_Datos.lua", "Idioma/enUS_Rutas.lua",
                             "OpcionalesOtras.lua", "Continentes.lua", "Opcionales.lua",
                             "Rutas/" + route_name):
                    load(name)
                self.assertTrue(module["CargarContinente"]("Otras"))
                lookup = "opcionalesNuevas" if faction == "Alliance" else "opcionalesNuevasH"
                quests = module["WH"][lookup]

                def visible(quest_id):
                    return next((row for row in module["_opcionales"]().values() if row["q"] == quest_id), None)

                lua.execute("raza, clase, nivel = 'Skyborne', 'DRUID', 15")
                lua.globals()["mapa"] = city
                self.assertIsNone(visible(chain[0]))
                lua.execute("nivel, clase = 16, 'MAGE'")
                self.assertIsNone(visible(chain[0]))
                lua.execute("clase, raza = 'DRUID', 'Human'")
                self.assertIsNone(visible(chain[0]))
                lua.execute("raza = 'Skyborne'")
                for index, quest_id in enumerate(chain):
                    lua.globals()["mapa"] = quests[quest_id]["wp"][1]["m"]
                    if index:
                        self.assertIsNone(visible(quest_id))
                        lua.globals()["completadas"][chain[index - 1]] = True
                    self.assertEqual(visible(quest_id)["w"]["a"], "A")
                lua.globals()["activa"] = chain[-1]
                lua.globals()["mapa"] = city
                point = visible(chain[-1])["w"]
                self.assertEqual((point["m"], point["a"]), (city, "T"))
                self.assertTrue(point["n"].startswith("Turn in: Aquatic Form"))
                route = lua.globals()["GuiaAventurero_Rutas"][1]
                route["cargar"](route)
                module["TraducirRuta"](route)
                skills = [entry for entry in route["hechizosExtra"].values() if entry["id"] == 1066]
                self.assertEqual([(skill["n"], skill["mision"]) for skill in skills], [(16, chain[-1])])
                hints = [step["nota"] for section in route["secciones"].values() for step in section["pasos"].values()
                         if (step["nota"] or "").startswith("Optional Aquatic Form")]
                self.assertEqual(len(hints), 1)
                self.assertIn("Shrine of Remulos", hints[0])


if __name__ == "__main__":
    unittest.main()

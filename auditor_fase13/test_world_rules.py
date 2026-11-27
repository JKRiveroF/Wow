import json
from pathlib import Path
import re
import unittest
from zipfile import ZipFile

from lupa.lua51 import LuaRuntime

from lua_routes import load_routes
from world_rules import audit_world, valid_xp_sample


HERE = Path(__file__).resolve().parent
ADDON = HERE.parent / "GuiaAventurero"
EVIDENCE = json.loads((HERE / "evidencia_forever.json").read_text(encoding="utf-8"))


def waypoint(action, quest, map_id=1444, x=44.7, y=37.6):
    return {"a": action, "q": quest, "m": map_id, "z": "Feralas", "x": x, "y": y}


def sample(waypoints, text="", minimum=1, maximum=60):
    return {
        "id": "prueba", "_archivo": "Rutas/Prueba.lua", "razas": ["Human"],
        "_faccion": "Alliance", "_lineas_pasos": [[10]],
        "secciones": [{"min": minimum, "max": maximum, "pasos": [{"t": text, "wp": waypoints}]}],
    }


def engine_functions(*names):
    source = (ADDON / "GuiaAventurero.lua").read_text(encoding="utf-8-sig")
    functions = [re.search(rf"^local function {name}\([^\n]*\)\n.*?^end\b", source, re.M | re.S) for name in names]
    return "\n".join(function[0] for function in functions)


class WorldRulesTest(unittest.TestCase):
    def test_xp_excludes_the_second_branch_and_separates_specializations(self):
        route = sample([dict(waypoint("T", 10), alternativa=20), dict(waypoint("T", 20), alternativa=10)])
        route["secciones"][0]["pasos"].append({"t": "Misión opcional de especialización", "wp": [waypoint("T", 30)]})
        source = {"estado": "forever", "fuente": "fixture"}
        catalog = {"misiones": {"10": dict(source, xp=100), "20": dict(source, xp=200), "30": dict(source, xp=300)}}
        report = next(item for item in audit_world(route, catalog) if item["codigo"] == "xp_escenario_misiones")
        self.assertIn("100 XP de misión registrada (1/1 entregas)", report["detalle"])
        self.assertIn("300 XP documentada aparte", report["detalle"])

    def test_partial_xp_reports_separate_combat_and_mission_subtotals(self):
        route = sample([waypoint("T", 10), waypoint("T", 10)])
        data = {
            "misiones": {"10": {"estado": "forever", "fuente": "fixture", "xp": 100}},
            "xp_combates": {route["id"]: {"tramos": {"1": {"estado": "forever", "fuente": "fixture", "xp": 70}}}},
        }
        assessment = next(item for item in audit_world(route, data) if item["codigo"] == "xp_escenario_misiones")
        self.assertIn("100 XP de misión registrada (1/1 entregas)", assessment["detalle"])
        self.assertIn("70 XP de combate estimada", assessment["detalle"])
        self.assertEqual(assessment["gravedad"], "pendiente")

    def test_xp_delivery_samples_require_enabled_progression_in_the_level_range(self):
        valid = {"level": 30, "xp": 0, "sources": 1, "faction": "Alliance", "race": "Human"}
        self.assertTrue(valid_xp_sample(valid))
        for patch in ({"level": 60}, {"xpDisabled": True}, {"maxLevel": True}, {"sources": 0}, {"xp": -1}):
            self.assertFalse(valid_xp_sample({**valid, **patch}), patch)

        route = sample([waypoint("T", quest) for quest in (10, 11, 12, 13, 14, 15, 10)], minimum=30, maximum=35)
        route["secciones"][0]["pasos"].append({"t": "Misión opcional: entrega adicional", "wp": [waypoint("T", 16)]})
        rows = {10: valid, 11: {**valid, "race": "Dwarf"}, 12: {**valid, "faction": "Horde"},
                13: {**valid, "level": 35}, 14: {**valid, "xpDisabled": True},
                15: {**valid, "level": 29}, 16: valid}
        source = {"estado": "forever", "fuente": "fixture"}
        catalog = {"misiones": {str(quest): {**source, "xp": 10, "entregas_observadas": [row]}
                               for quest, row in rows.items()}}
        finding = next(item for item in audit_world(route, catalog) if item["codigo"] == "xp_escenario_misiones")
        self.assertEqual(finding["cobertura_xp_por_perfil"], {"Human": {"observadas": 1, "aplicables": 6}})
        self.assertIn("1/6 entregas con muestra", finding["detalle"])

    def test_map_coordinates_and_phase_followup(self):
        invalid = waypoint("A", 10, map_id=True, x=float("inf"), y=-1)
        findings = audit_world(sample([invalid], maximum=59), {})
        self.assertEqual(
            [item["codigo"] for item in findings if item["gravedad"] == "error"],
            ["mapa_invalido", "coordenada_invalida", "coordenada_invalida", "nivel_sin_tramo_automatico"],
        )
        self.assertIn("línea 10", findings[0]["ubicacion"])

    def test_official_evidence_for_superseded_point_and_zero_xp(self):
        variants = [waypoint("C", 3520), waypoint("T", 1878)]
        route = sample(variants, "Misión extra para no quedarte corto de nivel")
        findings = audit_world(route, EVIDENCE)
        self.assertEqual(
            {(item["bloque"], item["codigo"]) for item in findings if item["gravedad"] == "error"},
            {(3, "posicion_descartada_forever"), (4, "mision_sin_xp_usada_como_refuerzo")},
        )

    def test_classic_positions_stay_unverified(self):
        data = {"mapas": {"1444": {
            "estado": "forever", "fuente": "local", "existe": False,
            "evidencia": {"existe": {"estado": "classic_compatible", "fuente": "local"}},
        }}}
        findings = audit_world(sample([waypoint("A", 10)]), data)
        self.assertNotIn("mapa_inexistente_forever", {item["codigo"] for item in findings})
        self.assertIn("mapas_sin_evidencia_forever", {item["codigo"] for item in findings})


class RouteHotfixTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.routes, cls.findings = load_routes(ADDON)
        cls.lua = LuaRuntime()
        translations = cls.lua.execute("""
            Diccionario = {}
            return {AnadirIngles = function(t)
              for key, value in pairs(t) do Diccionario[key] = value end
            end}
        """)
        cls.lua.execute((ADDON / "Idioma" / "enUS_Refuerzos97.lua").read_text(encoding="utf-8"), "GuiaAventurero", translations)
        cls.dictionary = cls.lua.globals().Diccionario

    def test_screecher_spirits_has_a_and_t_without_obsolete_pin(self):
        self.assertEqual(len(self.routes), 47)
        self.assertFalse([finding for finding in self.findings if finding["gravedad"] == "error"])
        for route in self.routes:
            with self.subTest(route=route["id"]):
                steps = [step for section in route["secciones"] for step in section["pasos"]
                         if any(point.get("q") == 3520 for point in step.get("wp", []))]
                step, = steps
                self.assertEqual([point["a"] for point in step["wp"] if point.get("q") == 3520], ["A", "T"])
                self.assertIn("costa de la Isla del Terror", step["t"])
                self.assertIn("Isle of Dread coastline", self.dictionary[step["t"]])

    def test_screecher_spirits_remains_pending_in_actual_engine_until_turn_in(self):
        simulate = self.lua.execute(
            """
            local accepted, completed, objective
            local GL = {}
            local entregadas = {}
            local C_QuestLog = {
              IsQuestFlaggedCompleted = function(q) return completed and q == 3520 end,
              GetLogIndexForQuestID = function(q) return accepted and q == 3520 and 1 or nil end,
              IsComplete = function(q) return objective and q == 3520 end,
            }
            local function Marcado() return false end
            local function ComprobacionesHechas() return nil end
            """
            + engine_functions("MisionCompletada", "MisionEnDiario", "ObjetivosListos", "DestinoHecho", "EstadoPaso")
            + """
            return function(step, a, o, c)
              accepted, objective, completed = a, o, c
              return EstadoPaso(step)
            end
            """
        )
        route_step = next(
            step for section in self.routes[0]["secciones"] for step in section["pasos"]
            if any(point.get("q") == 3520 for point in step.get("wp", []))
        )
        step = self.lua.table_from(route_step, recursive=True)
        for accepted, objective in [(False, False), (True, False), (True, True)]:
            with self.subTest(accepted=accepted, objective=objective):
                self.assertEqual(simulate(step, accepted, objective, False), "pendiente")
        self.assertEqual(simulate(step, False, False, True), "hecho")

        test_saved = self.lua.execute(
            """
            local saved_step
            local GuiaAventureroDB = {destino = 3}
            local GL = {EnteroGuardado = tonumber}
            local function PasoActual() return nil, saved_step end
            """
            + engine_functions("DestinoActual")
            + """
            return function(step)
              saved_step = step
              local point, count = DestinoActual()
              return point.a, count, GuiaAventureroDB.destino
            end
            """
        )
        self.assertEqual(test_saved(step), ("T", 2, 2))

    def test_repeatable_water_pouch_remains_optional_with_original_waypoints(self):
        repeatable_count = 0
        with ZipFile(HERE.parent / "GuiaAventurero-9.7.9.zip") as original:
            for route in self.routes:
                with self.subTest(route=route["id"]):
                    path = route["_archivo"]
                    before = original.read(f"GuiaAventurero/{path}")
                    after = (ADDON / path).read_bytes()
                    first_turn_in = rb'^.*\bq = 1707\b.*$'
                    self.assertEqual(re.findall(first_turn_in, after, re.M), re.findall(first_turn_in, before, re.M))
                    exchange_waypoints = rb'\{[^{}]*\bq = 1878\b[^{}]*\}'
                    self.assertEqual(re.findall(exchange_waypoints, after), re.findall(exchange_waypoints, before))
                    for section in route["secciones"]:
                        for step in section["pasos"]:
                            actions = [point["a"] for point in step.get("wp", []) if point.get("q") == 1878]
                            if not actions:
                                continue
                            repeatable_count += 1
                            self.assertEqual(actions, ["A", "C", "T"])
                            self.assertIn("opcional y no da experiencia", step["t"])
                            self.assertIn("optional and gives no experience", self.dictionary[step["t"]])
        self.assertEqual(repeatable_count, 38)


if __name__ == "__main__":
    unittest.main()

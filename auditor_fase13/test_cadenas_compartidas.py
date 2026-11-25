"""Regresión de las alternativas y de sus prerrequisitos en rutas compartidas."""

import re
import unittest
from collections import Counter
from pathlib import Path

from lupa.lua51 import LuaRuntime

from lua_routes import load_routes
from mission_rules import audit_missions, load_mission_localization

ADDON = Path(__file__).resolve().parents[1] / "GuiaAventurero"
PAIRS = {324: 526, 526: 324, 94484: 94493, 94493: 94484}


class SharedChainsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.routes, findings = load_routes(ADDON)
        if findings:
            raise AssertionError(findings)

    def test_alternatives_preserve_points_and_have_two_languages(self):
        counts = Counter()
        translations = load_mission_localization(ADDON)["por_nombre"]
        evidence = {"estado": "forever", "fuente": "fixture"}
        catalog = {"misiones": {str(q): dict(evidence, excluyentes=[other]) for q, other in PAIRS.items()}}
        for route in self.routes:
            for section in route["secciones"]:
                for step in section["pasos"]:
                    for point in step.get("wp", []):
                        if (qid := point.get("q")) in PAIRS:
                            self.assertEqual(point.get("alternativa"), PAIRS[qid])
                            self.assertIn(step["t"], translations)
                            counts[qid] += 1
            self.assertFalse([row for row in audit_missions(route, catalog) if row["codigo"] == "MISION_EXCLUYENTE"])
        self.assertEqual(counts, {324: 42, 526: 42, 94484: 20, 94493: 20})

    def test_state_machine_accepts_only_the_chosen_branch(self):
        lua = LuaRuntime(register_eval=False, register_builtins=False)
        content = (ADDON / "GuiaAventurero.lua").read_text(encoding="utf-8")
        names = ("DestinoHecho", "EstadoPaso")
        functions = "\n".join(re.search(rf"^local function {name}\([^\n]*\)\n.*?^end\b", content, re.M | re.S)[0]
                              for name in names)
        run = lua.execute(
            "local aceptadas, hechas\n"
            "local function Marcado() return false end\n"
            "local function MisionEnDiario(q) return not not aceptadas[q] end\n"
            "local function MisionCompletada(q) return not not hechas[q] end\n"
            "local function ObjetivosListos() return false end\n"
            "local function ComprobacionesHechas() return nil end\n"
            + functions + "\nreturn function(aceptar, completar, paso) aceptadas=aceptar; hechas=completar; return EstadoPaso(paso) end"
        )
        both = {"wp": [{"q": 94484, "a": "T", "alternativa": 94493}, {"q": 94493, "a": "T", "alternativa": 94484}]}
        dropped = {"wp": [{"q": 94484, "a": "T", "alternativa": 94493}]}
        for accepted, completed, step, expected in (
            ({}, {}, both, "pendiente"),
            ({94484: True}, {}, both, "pendiente"),
            ({94493: True}, {}, dropped, "hecho"),
            ({94484: True, 94493: True}, {}, both, "pendiente"),
            ({}, {94484: True}, both, "hecho"),
            ({}, {94493: True}, both, "hecho"),
            ({}, {94493: True}, {"wp": [{"q": 94484, "a": "T"}]}, "pendiente"),
        ):
            with self.subTest(accepted=accepted, completed=completed):
                self.assertEqual(run(*(lua.table_from(value, recursive=True)
                                       for value in (accepted, completed, step))), expected)

    def test_new_prerequisites_follow_original_anchors(self):
        counts = Counter()
        translations = load_mission_localization(ADDON)["por_nombre"]
        for route in self.routes:
            events = [(wp, step) for section in route["secciones"] for step in section["pasos"]
                      for wp in step.get("wp", []) if "q" in wp]
            ordered = [(wp["q"], wp["a"]) for wp, _ in events]
            prerequisite, original, followup = (98221, 464, 465) if route["_faccion"] == "Alliance" else (93680, 544, 545)
            self.assertEqual([action for q, action in ordered if q == prerequisite], ["A", "T"])
            self.assertLess(ordered.index((prerequisite, "T")), ordered.index((followup, "A")))
            self.assertLess(ordered.index((original, "T")), ordered.index((followup, "A")))
            self.assertTrue(all(step["t"] in translations for wp, step in events if wp["q"] in {prerequisite, followup}))
            counts[prerequisite] += 1
        self.assertEqual(counts, {98221: 25, 93680: 22})


if __name__ == "__main__":
    unittest.main()

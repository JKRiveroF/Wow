"""Pruebas del desglose de candidatos y el texto de Desolace."""

import unittest
from pathlib import Path

from agrupamientos import RELATIONS, analyze_clustering, clustering_findings, render_clustering
from catalogo import load_catalog
from lua_routes import load_routes
from mission_rules import load_mission_localization


ADDON = Path(__file__).resolve().parents[1] / "GuiaAventurero"


def waypoint(x, q=None, a=None, **fields):
    return {"m": 1443, "x": x, "y": 0, "q": q, "a": a, **fields}


def route_fixture(first_acceptance):
    return {"id": "ejemplo", "razas": ["Orc", "Troll"], "_archivo": "ejemplo.lua", "_lineas_pasos": [[31, 32]],
            "secciones": [{"pasos": [{"wp": [first_acceptance, waypoint(0, 12, "A")]},
                                    {"wp": [waypoint(0), waypoint(40, 11, "C"),
                                            waypoint(10, 12, "C"), waypoint(50)]}]}]}


def empty_relations():
    return {"misiones": {str(q): {"estado": "forever", "fuente": "prueba",
                                  **{field: [] for field in RELATIONS}} for q in (11, 12)}}


class TestAgrupamientos(unittest.TestCase):
    def test_geometry_keeps_anchors_and_reports_1_based_positions(self):
        report = analyze_clustering([route_fixture(waypoint(0, 11, "A"))], empty_relations())
        candidate, = report["candidatos"]
        appearance, = candidate["apariciones"]
        self.assertEqual((candidate["distancia_original"], candidate["distancia_alternativa"]), (110, 50))
        self.assertEqual(candidate["ahorro_geometrico"], 60)
        self.assertEqual(appearance["destinos_intercambiados"], [2, 3])
        self.assertEqual(appearance["linea"], 32)
        self.assertEqual(appearance["estado"], "validacion_cliente")
        self.assertIn("Probar en Forever", render_clustering(report))

    def test_sources_and_per_race_acceptance_keep_occurrence_in_research(self):
        route = route_fixture(waypoint(0, 11, "A", raza="Orc"))
        catalog = empty_relations()
        catalog["misiones"]["12"]["prerrequisitos"] = [11]
        report = analyze_clustering([route], catalog)
        candidate, = report["candidatos"]
        appearance, = candidate["apariciones"]
        self.assertEqual(appearance["aceptaciones_no_demostradas"], [{"raza": "Troll", "misiones": [11]}])
        self.assertEqual(appearance["estado"], "investigacion")
        self.assertEqual(candidate["relaciones_que_bloquean"][0]["campo"], "prerrequisitos")

    def test_map_change_and_racial_point_are_excluded(self):
        for field in ({"m": 1413}, {"raza": "Orc"}):
            route = route_fixture(waypoint(0, 11, "A"))
            route["secciones"][0]["pasos"][1]["wp"][1].update(field)
            self.assertFalse(analyze_clustering([route], {})["candidatos"])

    def test_pair_contrast_keeps_unrelated_fields_open_and_yields_to_new_links(self):
        route = route_fixture(waypoint(0, 11, "A"))
        evidence = {"fuentes": ["pares"], "detalle": "Caso probado", "fecha_consulta": "2026-11-26"}
        catalog = {"relaciones_agrupamiento": {"11:12": evidence}}
        report = analyze_clustering([route], catalog)
        self.assertTrue(report["candidatos"][0]["relaciones_sin_evidencia"])
        self.assertEqual([row["resolucion"] for row in clustering_findings(report)], ["cliente"])

        catalog["candidatos_por_mision"] = {"11": [{"campo": "excluyentes", "valor": [12], "fuente": "traza"}]}
        report = analyze_clustering([route], catalog)
        self.assertIn("La traza sugiere un vínculo", render_clustering(report))
        self.assertEqual([row["resolucion"] for row in clustering_findings(report)], ["investigación"])

        catalog["misiones"] = {"12": {"estado": "forever", "fuente": "registro", "prerrequisitos_alternativos": [11]}}
        report = analyze_clustering([route], catalog)
        self.assertEqual(report["candidatos"][0]["relaciones_que_bloquean"][0]["campo"], "prerrequisitos_alternativos")


class TestRutasDesolace(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.routes, cls.findings = load_routes(ADDON)

    def test_deduplicates_current_windows_without_losing_any_occurrence(self):
        self.assertFalse(self.findings)
        report = analyze_clustering(self.routes, {})
        self.assertEqual(report["rutas_con_candidatos"], 22)
        self.assertEqual(report["apariciones"], 51)
        self.assertEqual({item["mapa"]: len(item["apariciones"]) for item in report["candidatos"]},
                         {1413: 7, 1435: 22, 1443: 22})

    def test_documented_windows_are_reported_as_client_checks(self):
        report = analyze_clustering(self.routes, load_catalog())
        findings = list(clustering_findings(report))
        self.assertEqual(report["apariciones"], 51)
        self.assertEqual(len(findings), 22)
        self.assertTrue(all(row["resolucion"] == "cliente" for row in findings))

    def test_desolace_text_retains_mission_order_and_has_english_translation(self):
        messages = set()
        affected = 0
        for route in self.routes:
            for section in route["secciones"]:
                for step in section["pasos"]:
                    points = step.get("wp", [])
                    if not any(point.get("q") == 5386 and point.get("a") == "C" for point in points):
                        continue
                    with self.subTest(route=route["id"]):
                        self.assertEqual(route["_faccion"], "Horde")
                        self.assertEqual([(point["q"], point["a"]) for point in points],
                                         [(6142, "C"), (5386, "C"), (5381, "C"),
                                          (6142, "T"), (5386, "T"), (5381, "T")])
                        self.assertEqual((points[1]["m"], points[1]["x"], points[1]["y"]), (1443, 22.4, 73.1))
                        self.assertIn("lleva dos peces a Nataka Cuerno Largo", step["t"])
                        self.assertIn("cinco mariscos de las nasas bajo los muelles por cada pez", step["t"])
                        messages.add(step["t"])
                        affected += 1
        self.assertEqual(affected, 22)
        message, = messages
        english = load_mission_localization(ADDON)["por_nombre"][message]
        self.assertIn("two Bloodbelly Fish", english)
        self.assertIn("traps below the docks", english)
        self.assertIn("trade five to Jinar'Zillen", english)

    def test_swamp_uses_distinct_objectives_and_keeps_positions(self):
        messages = set()
        affected = 0
        for route in self.routes:
            for section in route["secciones"]:
                for step in section["pasos"]:
                    points = step.get("wp", [])
                    if not any(point.get("q") == 1430 and point.get("a") == "C" for point in points):
                        continue
                    with self.subTest(route=route["id"]):
                        self.assertEqual(route["_faccion"], "Horde")
                        self.assertEqual([(point["q"], point["a"]) for point in points],
                                         [(1430, "C"), (698, "C"), (1424, "C"),
                                          (1430, "T"), (698, "T"), (1424, "T")])
                        self.assertEqual([(point["m"], point["x"], point["y"]) for point in points[:3]],
                                         [(1435, 95.9, 69.1), (1435, 55.1, 52.8), (1435, 70.4, 50.4)])
                        self.assertIn("diez patas de cangrejos monstruosos", step["t"])
                        self.assertIn("crocoliscos adultos hasta reunir ocho flancos", step["t"])
                        messages.add(step["t"])
                        affected += 1
        self.assertEqual(affected, 22)
        message, = messages
        english = load_mission_localization(ADDON)["por_nombre"][message]
        self.assertIn("ten legs from Monstrous Crawlers", english)
        self.assertIn("adult sawtooth crocolisks", english)


if __name__ == "__main__":
    unittest.main()

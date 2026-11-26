import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from progreso import (BLOCKS, PREVIOUS_CERTIFIED, _coverage, _field_state, _global, _learning_state, _window_id,
                      compare, criterion, family, measure, percentage, render, update_section, validate_records)


class ProgressTests(unittest.TestCase):
    def test_contrast_and_confirmation_are_distinct_binary_checks(self):
        data = family("destinos", ("confirmada", "parcial", "inferencia", "investigacion", "cliente"), contrast=True)
        self.assertEqual(data["estados"], {state: 1 for state in data["estados"]})
        self.assertEqual(data["etapas"], {"confirmadas": 1, "contrastadas": 2})
        self.assertEqual(data["comprobaciones_superadas"], 3)
        self.assertEqual(data["comprobaciones_aplicables"], 10)
        self.assertEqual(family("destinos", ("parcial",))["comprobaciones_superadas"], 0)

    def test_partial_data_does_not_change_original_certification(self):
        data = criterion("2.identidad", [True, False], (family("títulos", ("confirmada",) * 2),))
        self.assertEqual([data["completos"], data["aplicables"]], [1, 2])
        self.assertEqual(data["efectivo"], [3, 4])
        self.assertEqual(criterion("2.identidad", [True, True])["efectivo"], [1, 1])
        self.assertEqual(percentage([999999, 1000000]), "99,99 %")

    def test_pending_family_blocks_full_effective_progress_even_with_review_recorded(self):
        coverage = family("Aprendizaje", ("confirmada", "cliente"), contrast=True)
        data = criterion("6.cliente", [True], (coverage,))
        self.assertEqual([data["completos"], data["aplicables"]], [1, 1])
        self.assertEqual(data["efectivo"], [3, 4])

    def test_positive_profile_observation_only_passes_the_contrast_stage(self):
        mission = {"evidencia": {"acceso_observado": {"valor": [{"raza": "Skyborne", "faccion": "Horde"}]}},
                   "indicios": []}
        self.assertEqual(_field_state(mission, "razas", False), "parcial")
        self.assertEqual(_field_state(mission, "facciones", False), "parcial")
        self.assertEqual(_field_state(mission, "clases", False), "investigacion")
        mission["evidencia"]["razas"] = {"valor": ["Skyborne"]}
        self.assertEqual(_field_state(mission, "razas", False), "confirmada")

    def test_learning_keeps_one_pair_open_until_all_its_route_profiles_are_resolved(self):
        claim = {"mision": 1, "hechizo": 2, "rutas_por_estado": {"pendiente": ["a", "b"]}}
        self.assertEqual(_learning_state(claim, set(), set()), "investigacion")
        self.assertEqual(_learning_state(claim, set(), {"1/2"}), "cliente")
        claim["rutas_por_estado"]["aprendizaje_por_habilidad"] = ["c"]
        self.assertEqual(_learning_state(claim, set(), {"1/2"}), "parcial")
        self.assertEqual(_learning_state(claim, {("6.aprendizaje", "1/2")}, {"1/2"}), "confirmada")

    def test_weights_keep_exact_certified_baseline(self):
        data = {str(i): {"peso": weight, "certificado": certified, "efectivo": [1, 1]}
                for (i, (_, weight)), certified in zip(BLOCKS.items(), PREVIOUS_CERTIFIED)}
        data["2"]["efectivo"] = [3, 4]
        self.assertEqual(_global(data), {"certificado": [49, 120], "efectivo": [15, 16]})
        self.assertEqual(percentage(_global(data)["certificado"]), "40,83 %")

    @patch("progreso._madrid_now", return_value="2026-11-26T17:41:00+01:00")
    def test_first_comparison_and_repeat_preserve_previous_measured_cut(self, _now):
        def snapshot(value):
            blocks = {str(i): {"peso": weight, "certificado": [*ratio], "efectivo": value}
                      for (i, (_, weight)), ratio in zip(BLOCKS.items(), PREVIOUS_CERTIFIED)}
            return {"bloques": blocks, "global": _global(blocks), "regresion": {"ejecutadas": 1},
                    "pendientes_por_via": {"cliente": 1, "investigacion": 2}}

        original = compare(snapshot([1, 2]))
        self.assertIsNone(original["anterior"]["2"]["efectivo"])
        self.assertEqual(original["variacion"]["2"]["certificado"], [0, 1])
        second = compare(snapshot([3, 4]), original)
        self.assertEqual(second["anterior"]["2"]["efectivo"], [1, 2])
        self.assertEqual(second["variacion"]["2"]["efectivo"], [1, 4])
        self.assertIs(compare(snapshot([3, 4]), second), second)
        self.assertIn("+25 pp", render(second))
        self.assertIn("**2 grupos de investigación** y **1 grupos de validación", render(second))

    def test_duplicate_routes_reuse_map_coordinates_and_flight_nodes(self):
        point = {"m": 12, "x": 40, "y": 32, "npc": 47}
        route = {"_faccion": "Horde", "secciones": [{"pasos": [
            {"comprobar": {"vuelo": "Costa", "llegar": 15}}, {"wp": [point]},
            {"comprobar": {"vuelo": "Coast"}}]}]}
        catalog = {"vuelos": {"Costa": {"existe": True, "estado": "forever", "fuente": "ficha"}}}
        flights = {"nodos": {"Horde": {"Costa": {"nodo": 1}, "Coast": {"nodo": 1}}}}
        maps, _, positions, nodes = _coverage([route, route], catalog, [], flights)
        self.assertEqual(maps["unidades"], 2)
        self.assertEqual(positions["unidades"], 1)
        self.assertEqual(nodes["unidades"], 1)
        self.assertEqual(nodes["estados"]["confirmada"], 1)

    def test_windows_at_the_same_coordinates_keep_distinct_objectives(self):
        first = {"mapa": 12, "destinos": [{"x": 25, "y": 50, "mision": 4, "accion": "C"}]}
        second = {"mapa": 12, "destinos": [{"x": 25, "y": 50, "mision": 5, "accion": "C"}]}
        self.assertNotEqual(_window_id(first), _window_id(second))

    def test_record_requires_compilation_and_rejects_duplicates(self):
        record = {"criterio": "3.interiores", "unidad": "ruta", "resultado": "verificado",
                  "fecha": "2026-11-26", "fuente": "prueba de entrada al interior"}
        with TemporaryDirectory() as directory:
            path = Path(directory) / "records.json"
            path.write_text(json.dumps([record]), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "compilación"):
                validate_records(path)
            record["compilacion"] = "1.60.1.71139"
            path.write_text(json.dumps([record]), encoding="utf-8")
            self.assertEqual(validate_records(path), {("3.interiores", "ruta")})
            path.write_text(json.dumps([record, record]), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicada"):
                validate_records(path)

    def test_missing_route_and_pending_client_cannot_raise_completion(self):
        route = {"id": "a", "_archivo": "Rutas/A.lua", "_faccion": "Horde", "secciones": []}
        mission = {"id": 1, "rutas": ["a", "b"], "acciones": {"A": 2}, "posiciones": [], "indicios": [],
                   "evidencia": {"nombre_es": {"valor": "Título"}}}
        with TemporaryDirectory() as directory:
            root = Path(directory)
            files = root / "auditor_fase13"
            files.mkdir()
            (files / "INVENTARIO_RUTAS.md").write_text("| 1 | `Rutas/A.lua` | `a` |\n| 2 | `Rutas/B.lua` | `b` |\n",
                                                       encoding="utf-8")
            (files / "VALIDACION_FOREVER.md").write_text("| Comprobación | Resultado |\n| --- | --- |\n| A | B |\n",
                                                        encoding="utf-8")
            (files / "NOTAS_FASE13.md").write_text("## Español\n\n- Borrador\n\n## English\n\n- Draft\n",
                                                    encoding="utf-8")
            report = measure([route], [], {}, {"misiones": [mission]}, {}, {},
                             {"ejecutadas": 2, "superadas": 1, "correcta": False}, root,
                             {("3.interiores", "a"), ("3.interiores", "b"), ("7.sincronizacion", "final")})
        self.assertEqual(report["bloques"]["1"]["certificado"], [3, 5])
        identity = report["bloques"]["2"]["criterios"][1]
        self.assertEqual(identity["familias"][1]["unidades"], 1)
        client = report["bloques"]["3"]["criterios"][2]
        self.assertEqual(client["completos"], 0)
        self.assertEqual(client["familias"][1]["estados"]["confirmada"], 1)
        self.assertEqual(report["bloques"]["7"]["certificado"], [0, 4])
        self.assertNotEqual(report["global"]["efectivo"], [1, 1])

    def test_replaces_only_the_generated_section(self):
        source = "encabezado\n<!-- m:inicio -->\ntexto viejo\n<!-- m:fin -->\npie\n"
        expected = "encabezado\n<!-- m:inicio -->\n\ncontenido\n\n<!-- m:fin -->\npie\n"
        self.assertEqual(update_section(source, "m", "contenido"), expected)
        with self.assertRaisesRegex(ValueError, "ausente"):
            update_section(source, "otro", "contenido")

import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from funcional import (CLIENT_CASES, addon_fingerprint, add_to_measurement, classify, load_client_evidence,
                       measure_functional, package_entries, verify_package)
from progreso import BLOCKS, _global, compare


class FunctionalTest(unittest.TestCase):
    def test_functional_migration_keeps_the_published_data_baseline(self):
        blocks = {str(key): {"peso": weight, "certificado": [1, 4], "efectivo": [3, 4]}
                  for key, (_, weight) in BLOCKS.items()}
        source = {"bloques": blocks, "global": _global(blocks)}
        previous = compare(source)
        current = json.loads(json.dumps(source))
        checks = {str(key): [{"superada": key != 7}] for key in BLOCKS}
        add_to_measurement(current, {"bloques": checks})
        comparison = compare(current, previous)
        self.assertEqual(comparison["actual"]["global"], {**source["global"], "funcional": [19, 20]})
        self.assertEqual(comparison["anterior"]["global"], source["global"])
        self.assertEqual(comparison["variacion"]["global"], {"certificado": [0, 1], "efectivo": [0, 1], "funcional": None})

    def test_kumisha_downgrade_requires_exact_mission_and_test(self):
        def waypoint(quest):
            return {"q": quest, "a": "A", "m": 1, "x": 10, "y": 10, "n": "Recoger: prueba"}

        route = {"id": "ruta", "_archivo": "Ruta.lua", "secciones": [{"min": 1, "max": 60, "pasos": [
            {"t": "Misión opcional de Kum'isha: canje", "wp": [waypoint(93685)]},
            {"t": "Entrega obligatoria", "wp": [waypoint(4)]}]}]}
        warnings = [{"bloque": 2, "gravedad": "aviso", "codigo": "MISION_REQUISITO_ALTERNATIVO",
                     "ruta": "ruta", "archivo": "Ruta.lua", "ubicacion": f"Sección 1, paso {step}, destino 1"}
                    for step in (1, 2)]
        inventory = {"misiones": []}
        self.assertEqual([row["prioridad"] for row in classify([route], warnings, inventory)], ["P1", "P1"])
        self.assertEqual([row["prioridad"] for row in classify([route], warnings, inventory, True)], ["P2", "P1"])

    def test_unconfirmed_required_offer_remains_a_blocker(self):
        inventory = {"misiones": [{"id": 4, "rutas": ["mi_ruta"], "evidencia": {}}]}
        row, = classify([], [], inventory)
        self.assertEqual((row["prioridad"], row["mision"], row["rutas"]), ("P1", 4, ["mi_ruta"]))

    def test_client_evidence_requires_exact_product_and_representative_profile(self):
        route = {"id": "gnomo_mago", "_faccion": "Alliance", "clase": "MAGE", "razas": ["Gnome"]}
        sample = {"caso": "alianza_inicio", "origen": "cliente_forever", "resultado": "superada", "ruta": "gnomo_mago",
                  "compilacion": "1.60.1.71139", "fecha": "2026-11-27", "evidencia": "registro de sesión",
                  "faccion": "Alliance", "clase": "MAGE", "raza": "Gnome", "nivel": 10, "idioma": "esES",
                  "huella_addon": "a" * 64}
        with TemporaryDirectory() as temp:
            path = Path(temp) / "resultados.json"
            path.write_text(json.dumps([sample]), encoding="utf-8")
            self.assertEqual(load_client_evidence(path, [route], "b" * 64), {})
            self.assertEqual(load_client_evidence(path, [route], "a" * 64), {"alianza_inicio": sample})
            for change in ({"origen": "simulacion"}, {"idioma": "enUS"}, {"nivel": 20}):
                path.write_text(json.dumps([{**sample, **change}]), encoding="utf-8")
                with self.assertRaises(ValueError):
                    load_client_evidence(path, [route], "a" * 64)

    def test_local_success_never_closes_the_client_or_zip_gate(self):
        case = measure_functional([], [], set(), {"ejecutadas": 20, "superadas": 20, "correcta": True}, {},
                                  package={"nombre": "candidato.zip"}, git_verified=True, documentation=True)
        self.assertEqual(case["cliente"], dict.fromkeys(CLIENT_CASES, "pendiente"))
        gates = {row["id"]: row["superada"] for row in case["bloques"]["7"]}
        self.assertTrue(gates["regresion"])
        self.assertFalse(gates["instalacion_y_cliente"])
        self.assertFalse(gates["zip"])

    def test_package_is_reproducible_and_rejects_a_stale_file(self):
        with TemporaryDirectory() as temp:
            root = Path(temp)
            addon = root / "GuiaAventurero"
            addon.mkdir()
            script = addon / "Modulo.lua"
            script.write_bytes(b"return true\n")
            entries = package_entries(addon)
            fingerprint = addon_fingerprint(entries)
            package = root / "paquete.zip"
            first = verify_package(package, entries, fingerprint, create=True)
            self.assertEqual(verify_package(package, entries, fingerprint, create=True), first)
            script.write_bytes(b"return false\n")
            with self.assertRaisesRegex(ValueError, "otro corte"):
                verify_package(package, entries, addon_fingerprint(entries))

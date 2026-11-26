from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from mission_rules import (audit_missions, audit_profile_matrix, audit_specializations,
                           load_mission_localization)


def waypoint(q, a, **fields):
    return {"q": q, "a": a, "m": 1, "x": 2, "y": 3, "n": "Destino", **fields}


def route(*steps, races=None):
    return {
        "id": "gnomo_mago", "_archivo": "Rutas/GnomoMago.lua", "_faccion": "Alliance",
        "razas": races or ["Gnome"], "clase": "MAGE",
        "secciones": [{"min": 1, "max": 5, "pasos": list(steps)}],
    }


def step(*points, text="Instrucciones"):
    return {"wp": list(points), "t": text}


def documented(**fields):
    return {"estado": "forever", "fuente": "test", **fields}


def findings(result):
    return [item["codigo"] for item in result if item["gravedad"] != "pendiente"]


class MissionRulesTest(unittest.TestCase):
    def test_malformed_mission_and_mismatched_action(self):
        candidate = route(step(waypoint(True, "A"), waypoint(17, "A", n="Entregar: Nombre"),
                               waypoint(17, "T")))
        result = audit_missions(candidate, {})
        self.assertEqual(findings(result), ["MISION_DESTINO_INVALIDO", "MISION_ACCION_ETIQUETA_DISTINTA"])
        self.assertEqual(result[0]["ubicacion"], "Sección 1, paso 1, destino 1")

    def test_repeat_objectives_and_racial_variants(self):
        candidate = route(step(waypoint(17, "A", raza="Dwarf"), waypoint(17, "A", raza="Gnome")),
                          step(waypoint(17, "C"), waypoint(17, "C", x=5)), step(waypoint(17, "T")),
                          races=["Dwarf", "Gnome"])
        self.assertEqual(findings(audit_missions(candidate, {})), [])

    def test_language_coverage_depends_on_values_and_evidence(self):
        candidate = route(step(waypoint(17, "A", n="Recoger: Título"), waypoint(17, "T")))
        catalog = {"misiones": {"17": {
            "nombres": {"en": "English name"}, "existe": False,
            "evidencia": {"nombres": {"estado": "forever", "fuente": "test"}},
        }}, "_localizacion_addon": {"por_id": {17: "English name"}, "por_nombre": {}}}
        result = audit_missions(candidate, catalog)
        self.assertEqual(findings(result), [])
        coverage = next(item["cobertura_pendiente"] for item in result if "cobertura_pendiente" in item)
        self.assertEqual(coverage["nombre_es"], 1)
        self.assertNotIn("nombre_en", coverage)

    def test_prerequisite_and_followup_use_waypoint_order(self):
        candidate = route(step(waypoint(17, "A"), waypoint(19, "A"), waypoint(17, "T"), waypoint(19, "T")))
        catalog = {"misiones": {"17": documented(seguimientos=[19]),
                                "19": documented(prerrequisitos=[17], nivel_minimo=7)}}
        self.assertEqual(set(findings(audit_missions(candidate, catalog))),
                         {"MISION_REQUISITO_ORDEN", "MISION_SEGUIMIENTO_ORDEN", "MISION_NIVEL_FUERA_DEL_TRAMO"})

    def test_offer_conditions_distinguish_active_and_completed_quests(self):
        candidate = route(step(waypoint(17, "A"), waypoint(19, "A"), waypoint(20, "A"), waypoint(17, "T"),
                               waypoint(21, "A"), waypoint(22, "A"), waypoint(23, "A"), waypoint(24, "A")))
        catalog = {"misiones": {"19": documented(mision_activa=[17]), "20": documented(desactivada_por=[17]),
                                "21": documented(mision_activa=[17]), "22": documented(disponible_desde=[17]),
                                "23": documented(disponible_hasta_entrega=[17]),
                                "24": documented(disponible_desde=[18])}}
        issues = [item for item in audit_missions(candidate, catalog) if item["gravedad"] == "aviso"]
        self.assertEqual([item["codigo"] for item in issues], ["MISION_DISPONIBILIDAD_ORDEN"] * 4)
        self.assertEqual([item["detalle"].split(":")[0] for item in issues],
                         ["Misión 20", "Misión 21", "Misión 23", "Misión 24"])

    def test_group_warning_checks_guide_text(self):
        catalog = {"misiones": {"17": documented(grupo=True)}}
        points = waypoint(17, "A"), waypoint(17, "T")
        self.assertEqual(findings(audit_missions(route(step(*points)), catalog)), ["MISION_GRUPO_SIN_AVISO"])
        self.assertEqual(findings(audit_missions(route(step(*points, text="Busca un grupo.")), catalog)), [])
        catalog["misiones"]["17"]["tipo_mision"] = "Dungeon"
        catalog["_etiquetas_addon"] = {17: "ÉLITE"}
        self.assertEqual(findings(audit_missions(route(step(*points)), catalog)), ["MISION_GRUPO_SIN_AVISO"])
        catalog["_etiquetas_addon"][17] = " |cffa335eeMAZMORRA|r"
        self.assertEqual(findings(audit_missions(route(step(*points)), catalog)), [])

    def test_unreachable_race_and_sourced_class_restriction(self):
        candidate = route(step(waypoint(17, "A", raza="Dwarf"), waypoint(19, "A")))
        catalog = {"misiones": {"19": documented(clases=["WARRIOR"])}}
        self.assertEqual(findings(audit_specializations(candidate, catalog)),
                         ["PERFIL_FILTRO_RACIAL_INALCANZABLE", "PERFIL_REQUISITO_DE_MISION"])

    def test_official_matrix_discriminates_skyborne_by_faction(self):
        alliance = {**route(races=["Skyborne"]), "id": "skyborne_a_mago"}
        horde = {**alliance, "id": "skyborne_mago", "_faccion": "Horde"}
        catalog = {"perfiles": documented(facciones={
            "Alliance": {"Skyborne": ["MAGE"]}, "Horde": {"Skyborne": ["SHAMAN"]},
        })}
        self.assertEqual(findings(audit_profile_matrix([alliance, horde], catalog)),
                         ["PERFIL_NO_JUGABLE_EN_FOREVER", "PERFIL_SIN_RUTA"])
        self.assertEqual(audit_profile_matrix([alliance, {**horde, "clase": "SHAMAN"}], catalog), [])

    def test_toc_localization_load_uses_addon_precedence(self):
        with TemporaryDirectory() as directory:
            addon = Path(directory)
            (addon / "Idioma").mkdir()
            (addon / "GuiaAventurero.toc").write_text("Idioma\\Uno.lua\nIdioma\\Dos.lua\n", encoding="utf-8")
            (addon / "Idioma" / "Uno.lua").write_text(
                'local _, GL = ...\nGL.AnadirIngles([[return { [5] = "Deferred", [6] = "Fallback" }]], "misiones")',
                encoding="utf-8")
            (addon / "Idioma" / "Dos.lua").write_text(
                'local _, GL = ...\nGL.AnadirIngles({ [5] = "Direct" }, "misiones")',
                encoding="utf-8")
            result = load_mission_localization(addon)
        self.assertEqual(result, {"por_id": {5: "Direct", 6: "Fallback"}, "por_nombre": {}, "errores": []})


if __name__ == "__main__":
    unittest.main()

"""Regresión de las etiquetas de Alterac y de los datos de vuelo compartidos."""

import unittest
from pathlib import Path
from unittest.mock import patch

from lupa.lua51 import LuaRuntime

from catalogo import read_catalog
from contactos import ITEM_FIXES, ITEM_TRACES, NPC_TRACES, OBJECT_TRACES, QUESTS, _loot_sources, link_contacts
from inventario_misiones import _coordinate_result
from lua_routes import load_routes
from mission_rules import load_mission_localization


ADDON = Path(__file__).resolve().parent.parent / "GuiaAventurero"


class MapRegressionTest(unittest.TestCase):
    def test_contact_trace_preserves_entity_type_action_and_canonical_map(self):
        sources = {
            NPC_TRACES: """        [7] = {
            [npcKeys.spawns] = {[12]={{42.1,41.1}},[99]={{42.1,41.1}}},
            [npcKeys.questStarts_add] = {100},
        },""",
            OBJECT_TRACES: """        [7] = {
            [objectKeys.spawns] = {[12]={{80,80}}},
            [objectKeys.questEnds_add] = {100},
        },""",
            QUESTS: "",
        }
        catalog = {"mapas": {"1429": {"area": 12, "existe": True}, "1": {"area": 99, "existe": True},
                             "2": {"area": 99, "existe": True}}, "misiones": {"100": {}}}
        with patch("contactos._lines", side_effect=lambda _, name: sources.get(name, "").splitlines()), \
                patch("contactos._read", return_value=[]):
            result = link_contacts(ADDON.parent, catalog)
        mission = result["misiones"]["100"]
        accept, = mission["referencias_interaccion"]["A"]
        delivery, = mission["referencias_interaccion"]["T"]
        self.assertEqual((accept["id"], accept["tipo"], accept["m"]), (7, "pnj", 1429))
        self.assertEqual((delivery["id"], delivery["tipo"], delivery["m"]), (7, "objeto", 1429))
        self.assertEqual(_coordinate_result(mission, "A", (1429, 42, 41)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(mission, "T", (1429, 42, 41)), "investigacion")
        self.assertIn("#L2", result["pnj"]["7"]["evidencia"]["posiciones_trazas"]["fuente"])

    def test_static_contact_requires_current_title_and_respects_corrections(self):
        sources = {NPC_TRACES: "", OBJECT_TRACES: "", QUESTS: "\n".join(
            f'[{quest}] = {{"Quest",{{{{7}}}},{{{{7}}}}}},' for quest in range(100, 105))}
        corrections = """        [101] = {
            [questKeys.startedBy_remove] = {{7}},
        },
        [102] = {
            [questKeys.startedBy] = {{8}},
        },
function C:LoadDynamic()
        [103] = {
            [questKeys.startedBy] = {{8}},
        },"""
        evidence = {"estado": "forever", "fuente": "título"}
        missions = {str(quest): {"existe": True, "nombres": {"en": "Otro título" if quest == 104 else "Quest"},
                                  "evidencia": {"nombre_en": evidence}} for quest in range(100, 105)}
        position = {"m": 1429, "x": 42.1, "y": 41.1, "fuente": "posición de Forever", "build": "1.60.1.71139"}
        catalog = {"misiones": missions, "entidades_interaccion": {"pnj": {7: [position], 8: [position]}}}
        with patch("contactos._lines", side_effect=lambda _, name: sources.get(name, "").splitlines()), \
                patch("contactos._read", return_value=corrections.splitlines()):
            result = link_contacts(ADDON.parent, catalog)["misiones"]
        self.assertNotIn("104", result)
        self.assertEqual(set(result["101"]["referencias_interaccion"]), {"T"})
        self.assertEqual(set(result["103"]["referencias_interaccion"]), {"T"})
        accepted, = result["102"]["referencias_interaccion"]["A"]
        self.assertEqual((accepted["id"], accepted["metodo_interaccion"]), (8, "catalogo_estatico"))
        self.assertIn("foreverQuestFixes.lua", accepted["fuente_interaccion"])

    def test_loot_requires_a_confirmed_item_objective_and_an_observed_source_position(self):
        traces = """        [90] = {
            [itemKeys.npcDrops_add] = {7,8},
            [itemKeys.objectDrops_add] = {7},
        },"""
        fixes = """        [90] = {
            [itemKeys.npcDrops_remove] = {7},
        },"""
        sources = {ITEM_TRACES: traces, ITEM_FIXES: fixes}
        sample = {"m": 1429, "x": 41, "y": 42, "fuente": "observación", "build": "1.60.1.71139"}
        objectives = {"objetos_objetivo": [90, 90], "evidencia": {
            "objetos_objetivo": {"estado": "forever", "fuente": "objetivo del servidor"}}}
        catalog = {"misiones": {"100": objectives, "101": {"objetos_objetivo": [90]}},
                   "entidades_interaccion": {"criatura": {7: [sample], 8: [sample, sample]},
                                            "objeto": {7: [{**sample, "x": 80}]}}}
        with patch("contactos._lines", side_effect=lambda _, name: sources.get(name, "").splitlines()), \
                patch("contactos._read", return_value=[]):
            result = link_contacts(ADDON.parent, catalog)["misiones"]
        self.assertEqual(set(result), {"100"})
        locations = result["100"]["referencias_botin"]["C"]
        self.assertEqual({(row["item"], row["tipo"], row["id"]) for row in locations}, {(90, "pnj", 8), (90, "objeto", 7)})
        self.assertEqual(len(locations), 2)
        self.assertIn("foreverItemTraces.lua", locations[0]["fuente_botin"])
        self.assertEqual(_coordinate_result(result["100"], "C", (1429, 41, 42)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(result["100"], "A", (1429, 41, 42)), "investigacion")
        self.assertEqual(_coordinate_result(result["100"], "C", (1430, 41, 42)), "investigacion")

    def test_loot_replacements_preserve_the_other_entity_type_and_keep_corrected_source(self):
        traces = """        [90] = {
            [itemKeys.npcDrops_add] = {7,8},
            [itemKeys.objectDrops_add] = {7},
        },"""
        fixes = """        [90] = {
            [itemKeys.npcDrops] = {}, -- only show vendors
            [itemKeys.objectDrops_add] = {9},
        },"""
        observed = {90: [{"tipo": "pnj", "id": 10, "fuente": "botín antiguo"}]}
        with patch("contactos._lines", side_effect=[traces.splitlines(), fixes.splitlines()]):
            result, _ = _loot_sources(ADDON.parent, observed)
            result = result[90]
        self.assertEqual(set(result), {("objeto", 7), ("objeto", 9)})
        self.assertIn("foreverItemFixes.lua", result["objeto", 9]["fuente"])
        with patch("contactos._lines", side_effect=[traces.splitlines(), []]):
            self.assertEqual(_loot_sources(ADDON.parent), ({}, {}))

    def test_observed_loot_without_coordinates_registers_only_the_origin(self):
        missions = {"100": {"objetos_objetivo": [90], "evidencia": {"objetos_objetivo": {
            "estado": "forever", "fuente": "objetivo del servidor"}}}}
        observed = {90: [{"tipo": "objeto", "id": 9, "fuente": "botín observado"}]}
        catalog = {"misiones": missions, "botin_observado": observed}
        with patch("contactos._lines", side_effect=lambda _, src: ["-- correcciones"] if src == ITEM_FIXES else []), \
                patch("contactos._read", return_value=[]):
            result = link_contacts(ADDON.parent, catalog)["misiones"]["100"]
        self.assertEqual(result["origenes_botin"], {"90": observed[90]})
        self.assertNotIn("referencias_botin", result)
        self.assertEqual(_coordinate_result(result, "C", (1429, 41, 42)), "investigacion")

    def test_loot_interaction_keeps_the_spell_on_the_mission_position(self):
        item = {"objetos_objetivo": [90], "evidencia": {"objetos_objetivo": {
            "estado": "forever", "fuente": "misión"}}}
        point = {"m": 1438, "x": 44.41, "y": 60.56, "fuente": "posición"}
        sample = {"tipo": "objeto", "id": 2742, "fuente": "saqueo", "registro_botin": "object:2742|spell:22810|group",
                  "hechizo_botin": 22810, "metodo_botin": "interaccion_hechizo"}
        catalog = {"misiones": {"100": item}, "botin_observado": {90: [sample]},
                   "entidades_interaccion": {"botin_objeto": {2742: [point]}}}
        with patch("contactos._lines", side_effect=lambda _, src: ["-- correcciones"] if src == ITEM_FIXES else []), \
                patch("contactos._read", return_value=[]):
            result = link_contacts(ADDON.parent, catalog)["misiones"]["100"]
        reference, = result["referencias_botin"]["C"]
        self.assertEqual((reference["hechizo_botin"], reference["registro_botin"]), (22810, sample["registro_botin"]))
        self.assertEqual(_coordinate_result(result, "C", (1438, 44.6, 60.4)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(result, "C", (1438, 55, 60.4)), "investigacion")

    def test_contextual_loot_is_scoped_to_the_quest_and_respects_item_corrections(self):
        item_evidence = {"objetos_objetivo": [90], "evidencia": {
            "objetos_objetivo": {"estado": "forever", "fuente": "objetivo de misión"}}}
        point = {"m": 1429, "x": 41, "y": 42, "fuente": "posición de la criatura"}
        sample = {"tipo": "pnj", "id": 9, "fuente": "saqueo", "registro_botin": "npc:9|quest", "mision_botin": 100}
        catalog = {"misiones": {"100": item_evidence, "101": item_evidence},
                   "botin_por_mision": {"100": {90: [sample, {**sample, "id": 10, "registro_botin": "npc:10|quest"}]}},
                   "entidades_interaccion": {"botin_pnj": {9: [point], 10: [point]}}}
        fixes = """        [90] = {
            [itemKeys.npcDrops_remove] = {10},
        },"""
        with patch("contactos._lines", side_effect=lambda _, src: fixes.splitlines() if src == ITEM_FIXES else []), \
                patch("contactos._read", return_value=[]):
            result = link_contacts(ADDON.parent, catalog)["misiones"]
        self.assertEqual(set(result), {"100"})
        self.assertEqual(result["100"]["origenes_botin"], {"90": [sample]})
        reference, = result["100"]["referencias_botin"]["C"]
        self.assertEqual((reference["fuente_botin"], reference["mision_botin"], reference["id"]), ("saqueo", 100, 9))

    def test_queried_loot_keeps_its_source_and_yields_to_observed_loot(self):
        item = {"objetos_objetivo": [90], "evidencia": {"objetos_objetivo": {
            "estado": "forever", "fuente": "misión"}}}
        point = {"m": 1429, "x": 35, "y": 40, "fuente": "posición"}
        query = {"tipo": "objeto", "id": 7, "fuente": "consulta", "metodo_botin": "consulta_entidad"}
        observed = {"tipo": "objeto", "id": 7, "fuente": "botín observado"}
        catalog = {"misiones": {"100": item}, "botin_consultado": {90: [query]},
                   "entidades_interaccion": {"objeto": {7: [point]}}}
        with patch("contactos._lines", side_effect=lambda _, src: ["-- correcciones"] if src == ITEM_FIXES else []), \
                patch("contactos._read", return_value=[]):
            queried = link_contacts(ADDON.parent, catalog)["misiones"]["100"]
            found = link_contacts(ADDON.parent, {**catalog, "botin_observado": {90: [observed]}})["misiones"]["100"]
        self.assertEqual(queried["origenes_botin"], {"90": [query]})
        self.assertEqual(queried["referencias_botin"]["C"][0]["metodo_botin"], "consulta_entidad")
        self.assertEqual(found["origenes_botin"], {"90": [observed]})
        self.assertEqual(_coordinate_result(queried, "C", (1429, 35, 40)), "cerca_de_observacion")

    def test_public_loot_reports_are_matched_by_exact_item_and_entity(self):
        item = {"objetos_objetivo": [8363], "evidencia": {"objetos_objetivo": {
            "estado": "forever", "fuente": "objetivo de misión"}}}
        unrelated = {**item, "objetos_objetivo": [8364]}
        point = {"m": 1438, "x": 44.8, "y": 59.4, "fuente": "traza"}
        report = {"tipo": "pnj", "id": 2009, "fuente": "publicación", "metodo_botin": "botin_de_jugadores",
                  "fecha_consulta": "2026-11-27"}
        catalog = {"misiones": {"2541": item, "2561": unrelated}, "botin_fuentes_publicas": {"8363": [report]},
                   "entidades_interaccion": {"criatura": {2009: [point]}}}
        with patch("contactos._lines", side_effect=lambda _, src: ["-- correcciones"] if src == ITEM_FIXES else []), \
                patch("contactos._read", return_value=[]):
            found = link_contacts(ADDON.parent, catalog)["misiones"]
        self.assertEqual(set(found), {"2541"})
        self.assertEqual(found["2541"]["origenes_botin"], {"8363": [report]})
        reference, = found["2541"]["referencias_botin"]["C"]
        self.assertEqual((reference["fuente"], reference["fuente_botin"], reference["fecha_consulta"]),
                         ("traza", "publicación", "2026-11-27"))
        self.assertEqual(_coordinate_result(found["2541"], "C", (1438, 44.7, 59.5)), "cerca_de_observacion")
        self.assertEqual(_coordinate_result(found["2541"], "C", (1439, 44.7, 59.5)), "investigacion")

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

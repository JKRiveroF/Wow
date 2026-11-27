"""Regresión de facción de la 9.8.0 en Lua 5.1, fuera del addon."""

from collections import Counter
from io import BytesIO
from pathlib import Path
import re
import subprocess
import unittest
from zipfile import ZipFile

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "GuiaAventurero"
BASE = "6eeee28"
CAPITALS = {"Alliance": {1453, 1455, 1457}, "Horde": {1454, 1456, 1458}}
ALLIANCE_RACES = {"Human", "Dwarf", "NightElf", "Gnome"}
MOVED_TO_HORDE = {90854, 92844, 92847, 92893, 92894, 93035, 93037, 93062, 93066, 93125, 93196, 95769}
HORDE_EXCLUSIVE = {6606, 7142, 7877} | MOVED_TO_HORDE
ALLIANCE_EXCLUSIVE = {5401, 5402, 5403, 5404, 7162, 7168, 7169, 7170, 7171, 8796, 8797, 9319}
NEUTRAL_ELDERS = {8646, 8718, 8866}


def lua_runtime():
    runtime = LuaRuntime(register_eval=False, register_builtins=False)
    runtime.execute('''
        SlashCmdList = {}
        function CreateFrame() return {RegisterEvent=function() end, SetScript=function() end} end
        function GetLocale() return "enUS" end
        function UnitLevel() return 60 end
    ''')
    return runtime


def load(runtime, module, path):
    return runtime.execute((ADDON / path).read_text(encoding="utf-8-sig"), ADDON.name, module, name=f"@{path}")


def faction(route):
    return route.faccion or ("Alliance" if route.razas[1] in ALLIANCE_RACES else "Horde")


class FactionRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua = lua_runtime()
        cls.module = cls.lua.table()
        module = cls.module
        load(cls.lua, module, "Idioma.lua")
        load(cls.lua, module, "Idioma/enUS_Refuerzos97.lua")
        load(cls.lua, module, "GuiaAventurero.lua")
        cls.routes = {}
        for path in sorted((ADDON / "Rutas").glob("*.lua")):
            cls.lua.globals().GuiaAventurero_Rutas = None
            load(cls.lua, module, path.relative_to(ADDON))
            route = cls.lua.globals().GuiaAventurero_Rutas[1]
            route.cargar(route)
            cls.routes[path.name] = route

        load(cls.lua, module, "DatosWowhead.lua")
        for name in ("Kalimdor", "Reinos", "Otras"):
            load(cls.lua, module, f"Opcionales{name}.lua")
        cls.catalogues = {"Alliance": {}, "Horde": {}}
        for area, payloads in cls.lua.globals().GuiaAventurero_Datos.items():
            for side, payload in payloads.items():
                cls.catalogues[side][area] = cls.lua.execute(payload)
        cls.catalogues["Alliance"]["Base"] = cls.lua.table(opcionales=module.WH.opcionales)

    def test_routes_filter_factions_and_keep_shared_quests(self):
        self.assertEqual(len(self.routes), 47)
        self.assertEqual(sum(len(route.razas) for route in self.routes.values()), 56)
        shared = Counter()
        omitted = Counter()
        for name, route in self.routes.items():
            side = faction(route)
            forbidden = HORDE_EXCLUSIVE if side == "Alliance" else ALLIANCE_EXCLUSIVE
            opposing = CAPITALS["Horde" if side == "Alliance" else "Alliance"]
            for section in route.secciones.values():
                for step in section.pasos.values():
                    if step.t.startswith("Variante de la otra facción"):
                        omitted[side] += 1
                        self.assertIsNone(step.wp)
                        self.assertEqual(self.module.EstadoPaso(step), "hecho")
                        self.assertEqual(self.module.EnIngles(step.t), "This variant is for the other faction. Continue to the next step.")
                    for point in step.wp.values() if step.wp else ():
                        if point.q is None:
                            continue
                        context = name, point.q, point.a, point.m
                        self.assertNotIn(point.q, forbidden, context)
                        if point.a in {"A", "T"} or point.q == 8867:
                            self.assertNotIn(point.m, opposing, context)
                        if point.q in {687, 737, 8867} and point.a == "A":
                            shared[side, point.q] += 1
                            if side == "Horde" and point.q in {687, 737}:
                                self.assertEqual(point.m, 1417 if point.q == 687 else 1458, context)
        self.assertEqual(omitted, {"Alliance": 25, "Horde": 49})
        for side in CAPITALS:
            self.assertGreaterEqual(min(shared[side, q] for q in (687, 737, 8867)), 1)

    def test_optional_catalogues_keep_valid_faction_and_neutral_event_variants(self):
        combined = {"Alliance": {}, "Horde": {}}
        for side, areas in self.catalogues.items():
            opposing = CAPITALS["Horde" if side == "Alliance" else "Alliance"]
            forbidden = HORDE_EXCLUSIVE if side == "Alliance" else ALLIANCE_EXCLUSIVE
            for area, catalog in areas.items():
                for group in catalog.values():
                    for quest, entry in group.items():
                        context = side, area, quest
                        self.assertNotIn(quest, forbidden, context)
                        combined[side][quest] = entry
                        for point in entry.wp.values():
                            if quest not in NEUTRAL_ELDERS:
                                self.assertNotIn(point.m, opposing, context)
        self.assertEqual(combined["Alliance"][8867].wp[1].m, 1453)
        self.assertEqual(combined["Horde"][8867].wp[1].m, 1458)
        self.assertEqual({p.a for p in combined["Horde"][1513].wp.values()}, {"A", "T"})
        self.assertIsNone(combined["Horde"][9386].pre1)
        self.assertLessEqual(MOVED_TO_HORDE, combined["Horde"].keys())
        self.assertLessEqual({5401, 5402, 5403, 5404}, combined["Alliance"].keys())
        for quest in NEUTRAL_ELDERS:
            self.assertIn(quest, combined["Horde"])

    def test_changed_route_slots_preserve_saved_progress_and_translations(self):
        archive = subprocess.check_output(["git", "archive", "--format=zip", BASE, "GuiaAventurero"], cwd=ROOT)
        allowed_files = {"GuiaAventurero/Mazmorras.lua", "GuiaAventurero/OpcionalesKalimdor.lua", "GuiaAventurero/OpcionalesReinos.lua",
                         "GuiaAventurero/Idioma/enUS_Refuerzos97.lua"}
        changed_steps = 0
        with ZipFile(BytesIO(archive)) as original:
            names = {item.filename for item in original.infolist() if not item.is_dir()}
            self.assertEqual({path.relative_to(ROOT).as_posix() for path in ADDON.rglob("*") if path.is_file()}, names)
            for name in names:
                previous = original.read(name)
                current = (ROOT / name).read_bytes()
                if name.startswith("GuiaAventurero/Rutas/"):
                    before, after = previous.decode().splitlines(), current.decode().splitlines()
                    self.assertEqual(len(before), len(after), name)
                    for old, new in zip(before, after):
                        if old == new:
                            continue
                        changed_steps += 1
                        self.assertIn("-- REFUERZO_97 q=", old, name)
                        instr = re.search(r't = "([^\"]+)"', new)[1]
                        self.assertNotEqual(self.module.EnIngles(instr), instr, (name, instr))
                        actions = r'\bq = \d+, a = "([ACT])"'
                        if "-- Variante de faccion q=" not in new:
                            self.assertEqual(re.findall(actions, old), re.findall(actions, new), name)
                elif name not in allowed_files:
                    self.assertEqual(current, previous, name)
        self.assertEqual(changed_steps, 207)

    def test_dungeon_option_places_each_shendralar_quest_in_its_faction(self):
        for side, quest, forbidden in (("Alliance", 7462, 7877), ("Horde", 7877, 7462)):
            lua = lua_runtime()
            lua.globals().faction = side
            lua.execute('function UnitFactionGroup() return faction end')
            module = lua.table()
            for path in ("Idioma.lua", "GuiaAventurero.lua", "DatosWowhead.lua", "Mazmorras.lua"):
                load(lua, module, path)
            dungeon = next(row for row in module.DatosMazmorras().values() if row.clave == "La Masacre")
            quest_ids = [entry.q for entry in dungeon.misiones.values()]
            self.assertEqual(quest_ids.count(quest), 1)
            self.assertNotIn(forbidden, quest_ids)


if __name__ == "__main__":
    unittest.main()

from collections import Counter
from pathlib import Path
from zipfile import ZipFile
import re
import unittest

from mission_rules import load_mission_localization


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "GuiaAventurero"
TITLE_FIXES = {"3481": ("Abalarios...", "Abalorios..."), "8412": ("ótem de espíritu", "Tótem de espíritu")}
ARMSMITH_QUESTS = {"5283", "5301", "85712"}
QUEST_MARKER = re.compile(r"-- REFUERZO_97 q=(3481|8412|5283|5301|85712)$")


def marked_steps(source):
    return {match[1]: line for line in source.splitlines() if (match := QUEST_MARKER.search(line))}


class MissionTextFixesTest(unittest.TestCase):
    def test_wild_leather_and_bloodpetal_instructions_keep_waypoints_and_quantities(self):
        materials = {
            2855: ("6 complementos", "1 atriplex", "6 Thick Armor Kits", "1 Wildvine"),
            2856: ("2 corazas", "2 pares de guantes", "1 atriplex", "2 Turtle Scale Breastplates", "2 pairs of Turtle Scale Gloves"),
            2857: ("2 túnicas Nochefugaz", "2 cintas Nochefugaz", "1 atriplex", "2 Nightscape Tunics", "2 Nightscape Headbands"),
            2858: ("2 pantalones Nochefugaz", "2 pares de botas Nochefugaz", "2 atriplex", "2 Nightscape Pants", "2 Wildvines"),
            2859: ("2 yelmos", "2 brazales", "2 atriplex", "2 Turtle Scale Helms", "2 Turtle Scale Bracers"),
            4148: ("1 brote", "marcador del objetivo es orientativo", "1 Bloodpetal Sprout", "from a plant"),
            5150: ("15 brotes", "Sin XP base", "15 Bloodpetal Sprouts", "No base XP"),
        }
        marker = re.compile(r"-- REFUERZO_97 q=(285[5-9]|4148|5150)$")
        localized = load_mission_localization(ADDON)
        self.assertEqual(localized["errores"], [])
        counts = Counter()
        with ZipFile(ROOT / "GuiaAventurero-9.7.9.zip") as baseline:
            for path in (ADDON / "Rutas").glob("*.lua"):
                original = baseline.read(path.relative_to(ROOT).as_posix()).decode("utf-8")
                old_points = {int(match[1]): line.split('", wp = ', 1)[1]
                              for line in original.splitlines() if (match := marker.search(line))}
                for line in path.read_text(encoding="utf-8").splitlines():
                    if not (match := marker.search(line)):
                        continue
                    quest = int(match[1])
                    with self.subTest(ruta=path.name, mision=quest):
                        text, points = line.split('t = "', 1)[1].split('", wp = ', 1)
                        self.assertEqual(points, old_points[quest])
                        translated = localized["por_nombre"][text]
                        for item in materials[quest]:
                            self.assertIn(item, text + "\n" + translated)
                        if 2855 <= quest <= 2859:
                            self.assertTrue(text.startswith("Misión opcional"))
                            self.assertIn("Camp Mojache", translated)
                        counts[quest] += 1
        self.assertEqual(counts, dict.fromkeys(range(2855, 2860), 22) | {4148: 22, 5150: 47})

    def test_stonetalon_optional_chain_keeps_the_original_destinations_after_1070(self):
        localized = load_mission_localization(ADDON)
        self.assertEqual(localized["errores"], [])
        self.assertEqual(localized["por_id"][1070], "On Guard in Stonetalon")
        self.assertEqual(localized["por_id"][1085], "On Guard in Stonetalon")
        marker = "-- REFUERZO_97 q=1085"
        chains = 0
        with ZipFile(ROOT / "GuiaAventurero-9.7.9.zip") as baseline:
            for path in (ADDON / "Rutas").glob("*.lua"):
                original = baseline.read(path.relative_to(ROOT).as_posix()).decode("utf-8")
                previous = next((line for line in original.splitlines() if line.endswith(marker)), None)
                source = path.read_text(encoding="utf-8")
                steps = [line for line in source.splitlines() if line.endswith(marker)]
                if previous is None:
                    self.assertEqual(steps, [])
                    continue
                with self.subTest(ruta=path.name):
                    line, = steps
                    self.assertTrue(line.endswith(previous.split('wp = { ', 1)[1]))
                    self.assertEqual(re.findall(r'q = (\d+), a = "([AT])"', line),
                                     [("1070", "A"), ("1070", "T"), ("1085", "A"), ("1085", "T")])
                    self.assertIn('m = 1440, z = "Vallefresno", x = 34.92, y = 49.76', line)
                    self.assertIn('m = 1442, z = "Sierra Espolón", x = 59.87, y = 66.88', line)
                    wording = line.split('t = "', 1)[1].split('", wp = ', 1)[0]
                    self.assertIn("Si pasas por Astranaar", wording)
                    self.assertIn("If you pass through Astranaar", localized["por_nombre"][wording])
                    chains += 1
        self.assertEqual(chains, 14)

    def test_priest_mission_titles_change_without_modifying_abilities_or_waypoints(self):
        cases = [
            ("EnanoGnomoSacerdote.lua", 5645, "Castigar", "Chastise",
             [("Sin miedo", "Castigar")]),
            ("NoMuertoSacerdote.lua", 5679, "Sacrificio oscuro", "Dark Sacrifice",
             [("[Peste devoradora]", "[Sacrificio oscuro]"),
              ("Recoger: Peste devoradora", "Recoger: Sacrificio oscuro"),
              ("Entregar: Peste devoradora", "Entregar: Sacrificio oscuro"),
              ('misionNombre = "Peste devoradora"', 'misionNombre = "Sacrificio oscuro"')]),
        ]
        localized = load_mission_localization(ADDON)
        self.assertEqual(localized["errores"], [])
        self.assertEqual(localized["por_nombre"]["Peste devoradora"], "Devouring Plague")
        with ZipFile(ROOT / "GuiaAventurero-9.7.9.zip") as baseline:
            for file, quest_id, spanish, english, replacements in cases:
                with self.subTest(mision=quest_id):
                    path = ADDON / "Rutas" / file
                    markers = (f"q = {quest_id},", f"mision = {quest_id},")
                    previous = baseline.read(path.relative_to(ROOT).as_posix()).decode("utf-8")
                    expected = [line for line in previous.splitlines() if any(key in line for key in markers)]
                    for old, new in replacements:
                        expected = [line.replace(old, new) for line in expected]
                    current = path.read_text(encoding="utf-8")
                    lines = [line for line in current.splitlines() if any(key in line for key in markers)]
                    self.assertTrue(lines)
                    self.assertEqual(lines, expected)
                    self.assertEqual(localized["por_id"][quest_id], english)
                    self.assertEqual(localized["por_nombre"][spanish], english)
                    for line in lines:
                        if 't = "' in line:
                            sentence = line.split('t = "', 1)[1].split('", wp = ', 1)[0]
                            translation = localized["por_nombre"][sentence]
                            self.assertIn(f"[{english}]", translation)
                            if quest_id == 5679:
                                self.assertIn("Devouring Plague", translation)

    def test_title_corrections_and_specialization_requirements_leave_waypoints_unchanged(self):
        counts = Counter()
        localized = load_mission_localization(ADDON)
        self.assertEqual(localized["errores"], [])
        self.assertEqual(localized["por_nombre"]["Abalorios..."], "Trinkets...")
        with ZipFile(ROOT / "GuiaAventurero-9.7.9.zip") as baseline:
            for path in sorted((ADDON / "Rutas").glob("*.lua")):
                original = marked_steps(baseline.read(path.relative_to(ROOT).as_posix()).decode("utf-8"))
                current = marked_steps(path.read_text(encoding="utf-8"))
                original_ids = {"5301" if quest_id == "85712" else quest_id for quest_id in current}
                self.assertEqual(set(original), original_ids)
                counts.update(current.keys())
                for quest_id, line in current.items():
                    with self.subTest(ruta=path.stem, mision=quest_id):
                        if quest_id in TITLE_FIXES:
                            old, new = TITLE_FIXES[quest_id]
                            self.assertEqual(line, original[quest_id].replace(old, new))
                        else:
                            self.assertIn(quest_id, ARMSMITH_QUESTS)
                            baseline_quest = "5301" if quest_id == "85712" else quest_id
                            expected = original[baseline_quest].split(', wp = ', 1)[1]
                            self.assertEqual(line.split(', wp = ', 1)[1], expected.replace(baseline_quest, quest_id))
                            self.assertIn("Misión opcional de especialización", line)
                            self.assertIn("4 yelmos de mitril ornamentados", line)
                            self.assertIn("2 botas de mitril ornamentadas", line)
                            self.assertIn("1 pechera de mitril ornamentada", line)
                            sentence = line.split('t = "', 1)[1].split('", wp = ', 1)[0]
                            translated = localized["por_nombre"][sentence]
                            self.assertIn("Optional specialization quest", translated)
                            self.assertIn("4 Ornate Mithril Helms, 2 Ornate Mithril Boots and 1 Ornate Mithril Breastplate",
                                          translated)
                            if quest_id == "85712":
                                self.assertIn("nivel 40", line)
                                self.assertIn("Okothos offers", translated)
                            else:
                                self.assertIn("nivel 40 y Herrería 200", line)
                                self.assertIn("Omite este paso", line)
                                self.assertIn("level 40 and 200 Blacksmithing", translated)
                                self.assertIn("Skip this step", translated)

        self.assertEqual(counts, {"3481": 23, "8412": 3, "5283": 19, "5301": 5, "85712": 17})

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

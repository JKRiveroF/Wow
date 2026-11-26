"""Integridad de la base y regresiones locales de guardados y Questie."""

import hashlib
import json
import re
import subprocess
import unittest
from pathlib import Path
from zipfile import ZipFile

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "GuiaAventurero"
BASE = "592d887a021ec136696e460895630982737fec95"
BASE_ZIP = "GuiaAventurero-9.7.9.zip"
MANIFEST = Path(__file__).with_name("SHA256_ORIGINALES.sha256")
ALLOWED_MODULES = {
    "GuiaAventurero/Datos94.lua",
    "GuiaAventurero/GuiaAventurero.lua",
    "GuiaAventurero/Idioma.lua",
    "GuiaAventurero/Idioma/enUS_Datos.lua",
    "GuiaAventurero/Idioma/enUS_Interfaz.lua",
    "GuiaAventurero/Idioma/enUS_Refuerzos97.lua",
    "GuiaAventurero/Idioma/enUS_Rutas.lua",
    "GuiaAventurero/Opcionales.lua",
    "GuiaAventurero/OpcionalesKalimdor.lua",
    "GuiaAventurero/OpcionalesOtras.lua",
    "GuiaAventurero/OpcionalesReinos.lua",
}
NO_XP_TEXT_QUESTS = {
    734, 777, 975, 1191, 2582, 2584, 2586, 2602, 2604, 2662, 3503, 4463, 5150,
    *range(4381, 4387), *range(4481, 4485), *range(4801, 4808),
    117, 2881, 3375, 3644, 3645, 4467, 4970, 6546, 6547, 6581, 7942, 8324,
    8428, 8433, 8437, 8441, 8492, 8767, 8768, 8769, 8846, 8851, 8852, 8853, 8854, 8867,
    349, 410, 431, 619, 779, 841, 1130, 1192, 1422, 1559, 1789, 2607, 3421, 3502,
    4041, 4324, 5059, 5892, 6781, 6846, 6881, 6941, 6942, 6943, 6982, 7026, 7027,
    7342, 7386, 7601, 8249, 9415,
}
SALVE_QUESTS = set(range(4103, 4113)) | set(range(5882, 5892))
OPTIONAL_TEXT_QUESTS = {
    1578, 1618, 2358, 5201, 5227, 6804, 6805, 6821, 6848, 7622, 8319, 8353, 8355, 8356,
    8556, 8689, 8691, 8692, 8693, 8694, 8696, 8788, 8863, 9266,
}
AUXILIARY_TEXT_QUESTS = {
    498, 1016, 1026, 1089, 1126, 1136, 1195, 1371, 1373, 1846, 3062, 3528, 3924, 4005, 4293, 4294,
    5051, 5149, 5526, 8318,
}
SALVE_ORIGINALS = {
    **{quest: quest - 1779 for quest in range(5882, 5887)},
    **{quest: quest - 5 for quest in range(5887, 5892)},
    **{quest: quest + 5 for quest in range(4103, 4108)},
    **{quest: quest + 1779 for quest in range(4108, 4113)},
}
ES_TITLES = json.loads(Path(__file__).with_name("titulos_es_revisados.json").read_text(encoding="utf-8"))
ROUTE_QUEST_WAYPOINT = re.compile(r'\{[^{}]*?\bq = (\d+)\s*,\s*a = "[ACT]"[^{}]*?\}')


def _source(name):
    return (ADDON / name).read_text(encoding="utf-8-sig")


def _match(source, pattern):
    match = re.search(pattern, source, re.MULTILINE | re.DOTALL)
    if match is None:
        raise AssertionError(f"No se encontró el bloque Lua: {pattern}")
    return match[0]


def _load(runtime, name):
    return runtime.execute(_source(name), ADDON.name, runtime.globals().GL, name=f"@{name}")


def _sha(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def _route_without_reviewed_edits(source):
    original_alterac = r'm = 1459, z = "(?:|Alterac Valley|Valle de Alterac)"'
    obsolete_objective = r'\{ m = 1444, z = "Feralas", x = 44\.7, y = 37\.6, n = "[^"]+", q = 3520, a = "C" \}, '
    klockmort_route = 'id = "enano_gnomo_guerrero"' in source
    skyborne_druid = bool(re.search(r'id = "skyborne_(?:a_)?druida"', source))

    def restore_title(match):
        changed = ES_TITLES.get(match[1])
        if not changed:
            return match[0]
        return re.sub(r'(\bn = "(?:Recoger: |Objetivo: |Entregar: )?)' + re.escape(changed["titulo"])
                      + r'(?=[ "(])', lambda name: name[1] + changed["anterior"], match[0], count=1)

    lines = []
    for line in source.splitlines(keepends=True):
        line = line.replace("Pelambres de lobo toscas", "Pieles de lobo bastas")
        line = line.replace(
            "Con Desuello 1, acepta [Pieles de lobo bastas] con Helene Desollapelambres y reúne 7 pelambres de los lobos del este.",
            "Helene Desollapelambres, a su lado, te da [Pieles de lobo bastas]: desuella los lobos del este.",
        )
        if skyborne_druid and re.search(r'^  \{ n = 16, id = 1066, origen = "mision", mision = (31|5061),', line):
            continue
        if skyborne_druid and 'nota = "Forma acuática opcional, desde nivel 16:' in line:
            line = re.sub(r', nota = "Forma acuática opcional, desde nivel 16:[^"]*"', "", line)
        for quest in set(ROUTE_QUEST_WAYPOINT.findall(line)).intersection(ES_TITLES):
            title = ES_TITLES[quest]
            line = line.replace(f"[{title['titulo']}]", f"[{title['anterior']}]")
        line = ROUTE_QUEST_WAYPOINT.sub(restore_title, line)
        refuerzo = re.search(r"-- REFUERZO_97 q=(\d+)\s*$", line)
        gate = re.search(r"-- (?:REFUERZO_97 q=|Paso conservado )(455|468|473|1838|1840|1848|1947|1948)\s*$", line)
        if gate:
            line = re.sub(r'\{ t = ".*', f"<dependencia revisada {gate[1]}>", line)
        line = line.replace(" Si quieres la cadena de varitas, acepta [Viaje al pantano] con Deino junto al instructor antes de ir al Marjal.", "")
        if refuerzo and (quest := int(refuerzo[1])) in SALVE_QUESTS:
            if 't = "Bálsamo de Frondavil:' in line or 't = "Canje opcional:' in line:
                line = re.sub(rf"(\bq\s*=\s*){quest}\b", lambda match: match[1] + str(SALVE_ORIGINALS[quest]), line)
            line = re.sub(r't = "[^"]+"', 't = "<bálsamo revisado>"', line, count=1)
        invasion = re.search(r"-- (?:REFUERZO_97 q=|Paso conservado )(926[34])\s*$", line)
        if invasion:
            line = re.sub(r'\{ t = ".*', f'<paso de invasión revisado {invasion[1]}>', line)
        hratha = re.search(r"-- (?:REFUERZO_97 q=|Paso conservado )(138[01])\s*$", line)
        if hratha:
            line = re.sub(r'\{ t = ".*', f'<paso de Hratha revisado {hratha[1]}>', line)
        azshara = re.search(r"-- (?:REFUERZO_97 q=|Paso conservado )(350[4-7])\s*$", line)
        if azshara:
            line = re.sub(r't = "[^"]+"', 't = "<Traición revisada>"', line, count=1)
            line = re.sub(r', \{ [^{}]+q = 91497, a = "[ACT]" \}', "", line)
            if azshara[1] in ("3506", "3507"):
                line = re.sub(r'\bq = (91500|91531)\b', f"q = {azshara[1]}", line)
                line = line.replace(f"Paso conservado {azshara[1]}", f"REFUERZO_97 q={azshara[1]}")
                line = line.replace("Escrito de invocación sin'dorei", "Tomo de invocación Kaldorei")
                line = re.sub(r'(n = "(?:Recoger|Entregar): )(?:Una jugada explosiva|Venganza cobrada)', r'\1Traición', line)
        if refuerzo and int(refuerzo[1]) in (1374, 1375):
            line = re.sub(r't = "[^"]+"', 't = "<rama de centauros revisada>"', line, count=1)
        if refuerzo and int(refuerzo[1]) in (2521, 2522, 93685, 93686):
            line = re.sub(r't = "[^"]+"', 't = "<cadena de Kum\'isha revisada>"', line, count=1)
            line = re.sub(r"(\bq\s*=\s*)9368([56])\b", lambda m: m[1] + ("2521" if m[2] == "5" else "2522"), line)
        if refuerzo and int(refuerzo[1]) in NO_XP_TEXT_QUESTS:
            line = re.sub(r't = "[^"]+"', 't = "<recompensa revisada>"', line, count=1)
        if refuerzo and int(refuerzo[1]) in AUXILIARY_TEXT_QUESTS:
            line = re.sub(r't = "[^"]+"', 't = "<materiales revisados>"', line, count=1)
        if refuerzo and int(refuerzo[1]) == 8941:
            line = re.sub(r't = "[^"]+"', 't = "<compensación revisada>"', line, count=1)
        if refuerzo and int(refuerzo[1]) in OPTIONAL_TEXT_QUESTS:
            line = re.sub(r't = "[^"]+"', 't = "<misión opcional revisada>"', line, count=1)
            if int(refuerzo[1]) == 5227:
                line = re.sub(r', \{ [^{}]+q = 5227, a = "C" \}', "", line)
            if int(refuerzo[1]) == 8788:
                line = line.replace('m = 1454, z = "Orgrimmar", x = 52.3, y = 69.4',
                                    'm = 1455, z = "Forjaz", x = 33.5, y = 65.6')
        line = re.sub(original_alterac, 'm = 1459, z = "<etiqueta revisada>"', line)
        if line.rstrip().endswith(("-- REFUERZO_97 q=3520", "-- REFUERZO_97 q=1878",
                                   "-- REFUERZO_97 q=5301", "-- REFUERZO_97 q=85712", "-- REFUERZO_97 q=5283")):
            line = re.sub(r't = "[^"]+"', 't = "<instrucciones revisadas>"', line, count=1)
            line = re.sub(obsolete_objective, "", line)
        if line.rstrip().endswith("-- REFUERZO_97 q=85712"):
            line = re.sub(r'q=85712\b', "q=5301", re.sub(r'q = 85712\b', "q = 5301", line))
        warrior_branch = re.search(r"-- (?:REFUERZO_97 q=|Paso conservado )(170[045689])\s*$", line)
        if klockmort_route and warrior_branch and line.lstrip().startswith('{ t = "'):
            line = re.sub(r'\{ t = ".*', f'<rama de la armadura revisada {warrior_branch[1]}>', line)
        if line.rstrip().endswith("-- REFUERZO_97 q=3481"):
            line = line.replace("Abalarios...", "Abalorios...")
        if line.rstrip().endswith("-- REFUERZO_97 q=8412"):
            line = re.sub(r"T?ótem de espíritu", "<tótem>", line)
        if ("q = 5386, a = \"C\"" in line and "q = 6142," in line) or (
            "q = 1430, a = \"C\"" in line and "q = 698, a = \"C\"" in line
        ) or (
            "q = 924, a = \"A\"" in line or "q = 924, a = \"C\"" in line
        ):
            line = re.sub(r't = "[^"]+"', 't = "<objetivos revisados>"', line, count=1)
        if "q = 3110," in line and 'raza = "Dwarf"' in line:
            line = re.sub(r't = "[^"]+"', 't = "<inicio racial revisado>"', line, count=1)
            line = re.sub(r', \{ [^{}]+q = 98574, a = "A", raza = "Gnome" \}', "", line)
            line = line.replace('n = "Entregar: Memorándum santificado (Silo Khalder)", q = 98574, a = "T", raza = "Gnome"',
                                'n = "Silo Khalder", npc = 837, raza = "Gnome"')
        if re.search(r"\b(?:q|mision) = 5645\b", line):
            line = line.replace("Sin miedo", "Castigar")
        if re.search(r"\b(?:q|mision) = 5679\b", line):
            line = line.replace("[Peste devoradora]", "[Sacrificio oscuro]")
            for field in ('misionNombre = "', "Recoger: ", "Entregar: "):
                line = line.replace(field + "Peste devoradora", field + "Sacrificio oscuro")
        if line.startswith('    entrenar = "') and "Aelthalyste te da tu misión de raza del 20:" in line:
            line = line.replace("Aelthalyste te da tu misión de raza del 20: Peste devoradora.",
                                "Aelthalyste te da tu misión de raza del 20: Sacrificio oscuro.")
        if 'q = 20, a = "A"' in line and 'q = 20, a = "T"' in line:
            line = re.sub(r't = "[^"]+"', 't = "<bloqueo revisado>"', line, count=1)
            line = re.sub(r', \{ [^{}]+q = 98387, a = "[AT]" \}', "", line)
        if re.search(r'\bq = (?:324|526|94484|94493|464|465|544|545)\b', line):
            line = re.sub(r't = "[^"]+"', 't = "<cadena revisada>"', line, count=1)
            line = re.sub(r'(q = (?:324|526|94484|94493), a = "[AT]"), alternativa = \d+', r'\1', line)
            line = re.sub(r', \{ [^{}]+q = (?:98221|93680), a = "[AT]" \}', "", line)
        if "Una lección que aprender" in line:
            line = re.sub(r'q = (?:26|27)(?=, a = "[AT]")', "q = <variante acuática>", line)
        if "Sheldras Moontree" in line and 'npc = 5504' in line and 'hechizos = { 5188 }' in line:
            line = re.sub(r't = "[^"]+"', 't = "<inicio de forma felina>"', line, count=1)
            line = re.sub(r', \{ [^{}]+q = 98393, a = "[AT]" \}', "", line)
        if 'q = 98394, a = "A"' in line or ('q = 98341, a = "A"' in line and "q = 98340" not in line):
            line = re.sub(r't = "[^"]+"', 't = "<encargo de forma felina>"', line, count=1)
        if 'q = 430, a = "A"' in line:
            line = re.sub(r't = "[^"]+"', 't = "<requisitos de Ivar>"', line, count=1)
            line = re.sub(r', \{ [^{}]+q = (?:430, a = "T"|91920, a = "[ACT]"|91921, a = "A") \}', "", line)
        if 'q = 425, a = "A"' in line:
            line = re.sub(r't = "[^"]+"', 't = "<entrega antes de Ivar>"', line, count=1)
            line = line.replace('y = 12.7, n = "Entregar: Vuelve con Quinn (de nuevo) (Quinn Yorick)", q = 91921',
                                'y = 12.6, n = "Entregar: Vuelve con Quinn (Quinn Yorick)", q = 430')
        if any(f'q = {quest}, a = "T"' in line for quest in (94495, 94497, 94499)):
            line = re.sub(r't = "[^"]+"', 't = "<odres revisados>"', line, count=1)
            line = re.sub(r', \{ [^{}]+q = (?:94499|94500), a = "A" \}', "", line)
        if line.startswith("    entrenar = ") and "Walk on Air" in line:
            line = re.sub(r"(?:Skysight|Read Ley ?[Ll]ine) .*?(?= Además)", "<racial revisada>.", line)
        lines.append(line)
    return "".join(lines)


class IntegridadTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pairs = [line.split("  ", 1) for line in MANIFEST.read_text(encoding="ascii").splitlines()]
        cls.originals = {name: checksum for checksum, name in pairs}
        if len(pairs) != 219 or len(cls.originals) != 219:
            raise AssertionError("El manifiesto debe identificar 219 originales únicos.")
        cls.files = set(cls.originals) - {BASE_ZIP}
        cls.routes = {name for name in cls.files if name.startswith("GuiaAventurero/Rutas/")}

    def test_manifiesto_y_zip_del_commit_base(self):
        result = subprocess.run(
            ["git", "cat-file", "blob", f"{BASE}:{BASE_ZIP}"],
            cwd=ROOT, capture_output=True, check=True,
        )
        self.assertEqual(hashlib.sha256(result.stdout).hexdigest(), self.originals[BASE_ZIP])
        archive = ROOT / BASE_ZIP
        self.assertEqual(_sha(archive), self.originals[BASE_ZIP])
        with ZipFile(archive) as zip_file:
            members = [entry for entry in zip_file.infolist() if not entry.is_dir()]
            self.assertEqual(len(members), len(self.files))
            self.assertEqual({entry.filename for entry in members}, self.files)
            for entry in members:
                with self.subTest(path=entry.filename), zip_file.open(entry) as file:
                    self.assertEqual(hashlib.file_digest(file, "sha256").hexdigest(), self.originals[entry.filename])

    def test_distribucion_conserva_archivos_y_limites_de_cambios(self):
        packaged = {path.relative_to(ROOT).as_posix() for path in ADDON.rglob("*") if path.is_file()}
        self.assertEqual(packaged, self.files)
        self.assertEqual(len(self.routes), 47)
        self.assertLessEqual(ALLOWED_MODULES, packaged)
        for name in sorted(packaged - self.routes - ALLOWED_MODULES):
            with self.subTest(path=name):
                self.assertEqual(_sha(ROOT / name), self.originals[name])

    def test_las_rutas_conservan_todo_fuera_de_los_cambios_revisados(self):
        with ZipFile(ROOT / BASE_ZIP) as original:
            for name in sorted(self.routes):
                with self.subTest(ruta=name):
                    expected = _route_without_reviewed_edits(original.read(name).decode("utf-8"))
                    actual = _route_without_reviewed_edits((ROOT / name).read_bytes().decode("utf-8"))
                    self.assertTrue(expected == actual, f"La ruta {name} contiene cambios fuera del alcance documentado.")

    def test_toc_version_guardados_y_recursos(self):
        lines = _source("GuiaAventurero.toc").splitlines()
        metadata = dict(line[3:].split(": ", 1) for line in lines if line.startswith("## "))
        self.assertEqual(metadata["Version"], "9.7.9")
        self.assertEqual(metadata["Interface"], "16001")
        self.assertEqual(metadata["Author"], "JKRiveroF")
        self.assertEqual(metadata["SavedVariables"], "GuiaAventureroCuenta, GuiaAventureroRespaldo")
        self.assertEqual(metadata["SavedVariablesPerCharacter"], "GuiaAventureroDB")
        modules = [f"GuiaAventurero/{line.replace(chr(92), '/')}" for line in lines if line.endswith(".lua")]
        self.assertEqual(len(modules), 144)
        self.assertEqual(set(modules), {name for name in self.files if name.endswith(".lua")})
        self.assertEqual({name for name in modules if name in self.routes}, self.routes)
        for extension, count in ((".blp", 61), (".tga", 9)):
            assets = [name for name in self.files if name.endswith(extension)]
            self.assertEqual(len(assets), count)
            for name in sorted(assets):
                with self.subTest(asset=name):
                    self.assertEqual(_sha(ROOT / name), self.originals[name])

    def test_refuerzos_sin_xp_have_matching_english_for_reviewed_steps(self):
        from mission_rules import load_mission_localization

        localized = load_mission_localization(ADDON)["por_nombre"]
        found = set()
        total = 0
        for name in self.routes:
            for line in (ROOT / name).read_text(encoding="utf-8").splitlines():
                if "Sin XP base" not in line:
                    continue
                quest = int(re.search(r"-- REFUERZO_97 q=(\d+)$", line)[1])
                if quest in SALVE_QUESTS:
                    continue
                text = re.search(r't = "([^"]+)"', line)[1]
                self.assertIn("No base XP", localized.get(text, ""))
                found.add(quest)
                total += 1
        self.assertEqual(found, NO_XP_TEXT_QUESTS)
        self.assertEqual(total, 2061)

    def test_optional_turn_ins_keep_english_and_use_the_correct_seasonal_city(self):
        from mission_rules import load_mission_localization
        from world_rules import XP_OPCIONAL

        localized = load_mission_localization(ADDON)["por_nombre"]
        found = set()
        count = gifts = 0
        for name in self.routes:
            for line in (ROOT / name).read_text(encoding="utf-8").splitlines():
                match = re.search(r' t = "([^"]+)".*-- REFUERZO_97 q=(\d+)$', line)
                if not match or (quest := int(match[2])) not in OPTIONAL_TEXT_QUESTS:
                    continue
                with self.subTest(route=name, quest=quest):
                    self.assertTrue(XP_OPCIONAL.match(match[1]))
                    self.assertTrue(localized.get(match[1], "").startswith("Optional quest:"))
                    if quest == 8788:
                        self.assertEqual(line.count('m = 1454, z = "Orgrimmar", x = 52.3, y = 69.4'), 2)
                        gifts += 1
                    if quest == 5227:
                        self.assertEqual(re.findall(r'q = 5227, a = "([ACT])"', line), ["A", "T"])
                    if quest == 8319:
                        self.assertIn("después de Mensajes secretos", match[1])
                        self.assertIn("after Secret Communication", localized[match[1]])
                    if quest == 1578:
                        self.assertIn("Herrería 25", match[1])
                        self.assertIn("6 Copper Axes and 6 Copper Chain Belts", localized[match[1]])
                    if quest == 1618:
                        self.assertIn("Herrería 35", match[1])
                        self.assertIn("4 Runed Copper Belts and 4 Heavy Copper Mauls", localized[match[1]])
                found.add(quest)
                count += 1
        self.assertEqual(found, OPTIONAL_TEXT_QUESTS)
        self.assertEqual(count, 331)
        self.assertEqual(gifts, 6)

    def test_skinning_quest_uses_current_names_and_profession_requirement(self):
        from mission_rules import load_mission_localization

        localization = load_mission_localization(ADDON)
        self.assertEqual(localization["por_id"][91751], "Rough Wolf Pelts")
        self.assertEqual(localization["por_nombre"]["Pelambres de lobo toscas"], "Rough Wolf Pelts")
        acceptances = 0
        for name in self.routes:
            for line in (ROOT / name).read_text(encoding="utf-8").splitlines():
                if 'q = 91751, a = "A"' not in line:
                    continue
                sentence = re.search(r't = "((?:[^"\\]|\\.)*)"', line)[1].replace(r'\"', '"')
                self.assertIn("Con Desuello 1", sentence)
                self.assertIn("reúne 7 pelambres", sentence)
                self.assertIn("With 1 Skinning, accept [Rough Wolf Pelts]", localization["por_nombre"][sentence])
                acceptances += 1
        self.assertEqual(acceptances, 4)

    def test_auxiliary_item_instructions_are_shared_and_bilingual(self):
        from mission_rules import load_mission_localization
        from world_rules import XP_OPCIONAL

        localized = load_mission_localization(ADDON)["por_nombre"]
        found = {}
        total = 0
        for file in self.routes:
            for text, value in re.findall(r't = "([^"]+)".*-- REFUERZO_97 q=(\d+)$', _source(file.split("/", 1)[1]), re.M):
                quest = int(value)
                if quest not in AUXILIARY_TEXT_QUESTS:
                    continue
                self.assertEqual(text, found.setdefault(quest, text))
                self.assertEqual(bool(XP_OPCIONAL.match(text)), quest in (1846, 3528, 5526))
                self.assertIn(text, localized)
                self.assertNotIn("Recógela, cumple los objetivos y entrégala", text)
                total += 1
        self.assertEqual(set(found), AUXILIARY_TEXT_QUESTS)
        self.assertEqual(total, 519)
        self.assertIn("Flame of Uzel", localized[found[1136]])
        self.assertIn("stay there until the totem forms", localized[found[4005]])
        self.assertIn("seal it in the reliquary", localized[found[5526]])
        self.assertIn("Advanced Target Dummy", localized[found[1371]])
        self.assertIn("Lágrimas rotas", found[1371])
        self.assertIn("3.000 de reputación", found[1371])
        self.assertIn("Draenethyst Shard", localized[found[1373]])
        self.assertIn("El Valle de los Huesos", found[1373])
        self.assertIn("3.000 de reputación", found[1373])
        self.assertIn("ten Encrypted Twilight Texts", localized[found[8318]])
        self.assertIn("Bor Bravacrín", found[8318])

    def test_felwood_first_turn_ins_and_repeatables_follow_the_right_faction(self):
        from mission_rules import load_mission_localization

        localized = load_mission_localization(ADDON)["por_nombre"]
        removed = 0
        for name in self.routes:
            text = (ROOT / name).read_text(encoding="utf-8")
            self.assertNotRegex(text, r"\bq = 926[34]\b")
            removed += len(re.findall(r"-- Paso conservado 926[34]$", text, re.M))
            alliance = "q = 4101," in text
            first = 5882 if alliance else 5887
            repeat = 4103 if alliance else 4108
            expected = list(range(first, first + 5)) + list(range(repeat, repeat + 5))
            if alliance and Path(name).stem in ("EnanoChaman", "GnomoMago", "HumanoMago", "SkyborneAMago"):
                expected = [first]
            entries = []
            for quest in re.finditer(r't = "([^"]+)".*-- REFUERZO_97 q=(\d+)$', text, re.M):
                quest_id = int(quest[2])
                if quest_id not in SALVE_QUESTS:
                    continue
                entries.append(quest_id)
                translation = localized.get(quest[1], "")
                self.assertIn("No base XP" if quest_id < 5882 else "Cenarion Beacon", translation)
            self.assertEqual(entries, expected, name)
        self.assertEqual(removed, 10)

    def test_hratha_uses_the_forever_quest_once_per_affected_route(self):
        from mission_rules import load_mission_localization

        localized = load_mission_localization(ADDON)
        self.assertEqual(localized["por_id"][96222], "Khan Hratha")
        affected = 0
        for name in self.routes:
            text = (ROOT / name).read_text(encoding="utf-8")
            self.assertNotRegex(text, r"\bq = 138[01]\b")
            steps = [line for line in text.splitlines() if re.search(r"-- Paso conservado 138[01]$", line)]
            if not steps:
                continue
            affected += 1
            self.assertEqual(re.findall(r'q = 96222, a = "([ACT])"', steps[0]), ["A", "C", "T"])
            self.assertEqual(steps[0].count('x = 43.5, y = 79.0'), 2)
            self.assertIn("Maraudine centaur", localized["por_nombre"][re.search(r't = "([^"]+)"', steps[0])[1]])
            self.assertTrue(all("wp =" not in step for step in steps[1:]))
        self.assertEqual(affected, 34)

    def test_kumisha_steps_use_live_ids_in_all_routes(self):
        from mission_rules import load_mission_localization

        localized = load_mission_localization(ADDON)
        self.assertEqual(localized["por_id"][93685], "To Serve Kum'isha")
        self.assertEqual(localized["por_id"][93686], "Kum'isha's Endeavors")
        for name in self.routes:
            text = (ROOT / name).read_text(encoding="utf-8")
            self.assertNotRegex(text, r"\bq = 252[12]\b")
            entries = re.findall(r't = "([^"]+)".*-- REFUERZO_97 q=(9368[56])$', text, re.M)
            self.assertEqual([q for _, q in entries], ["93685", "93686"])
            self.assertIn("The Found One", localized["por_nombre"][entries[0][0]])
            self.assertIn("Flawless Draenethyst Sphere", localized["por_nombre"][entries[1][0]])

    def test_ivar_intro_preserves_destinations_and_requires_both_new_quests(self):
        for route in sorted((ADDON / "Rutas").glob("NoMuerto*.lua")):
            with self.subTest(route=route.name):
                lines = route.read_text(encoding="utf-8").splitlines()
                before = next(i for i, line in enumerate(lines) if 'q = 430, a = "A"' in line)
                self.assertEqual(re.findall(r'q = (\d+), a = "([ACT])"', lines[before])[-6:],
                                 [("430", "A"), ("430", "T"), ("91920", "A"), ("91920", "C"),
                                  ("91920", "T"), ("91921", "A")])
                self.assertEqual(re.findall(r'q = (\d+), a = "([ACT])"', lines[before + 1]),
                                 [("91921", "T"), ("425", "A"), ("425", "C"), ("425", "T")])

    def test_druid_routes_use_the_correct_aquatic_variants_and_cat_referral(self):
        elf = _source("Rutas/ElfoDruida.lua")
        tauren = _source("Rutas/TaurenDruida.lua")
        self.assertEqual(re.findall(r'\bq = (26|27), a = "([AT])"', elf), [("26", "A"), ("26", "T")])
        self.assertEqual(re.findall(r'\bq = (26|27), a = "([AT])"', tauren), [("27", "A"), ("27", "T")])
        for route, next_quest in ((elf, 98394), (_source("Rutas/SkyborneADruida.lua"), 98341)):
            self.assertLess(route.index('q = 98393, a = "A"'), route.index('q = 98393, a = "T"'))
            self.assertLess(route.index('q = 98393, a = "T"'), route.index(f'q = {next_quest}, a = "A"'))

    def test_klockmort_branch_reuses_menethil_and_leaves_grimand_for_humans(self):
        dwarf_gnome_route = _source("Rutas/EnanoGnomoGuerrero.lua")
        human_route = _source("Rutas/HumanoGuerrero.lua")
        self.assertNotRegex(dwarf_gnome_route, r'\bq = 170[056],')
        self.assertEqual(set(re.findall(r'\bq = (170[056]),', human_route)), {"1700", "1705", "1706"})
        self.assertEqual(re.findall(r'\bq = (170[489]), a = "([ACT])"', dwarf_gnome_route),
                         [("1704", "A"), ("1704", "T"), ("1708", "A"), ("1708", "C"),
                          ("1708", "T"), ("1709", "A"), ("1709", "T")])
        self.assertRegex(dwarf_gnome_route, r'm = 1437, [^\n]*x = 11\.7, y = 65, n = "Objetivo: Coral férreo", q = 1708')
        harbor = next(line for line in dwarf_gnome_route.splitlines() if "En el Castillo de Menethil acepta" in line)
        self.assertIn("Si llevas [Coral férreo]", harbor)
        self.assertNotIn("q = 1708", harbor)

    def test_armorsmith_route_variant_matches_profile_and_keeps_waypoints(self):
        counts = {5301: 0, 85712: 0}
        for path in (ADDON / "Rutas").glob("*.lua"):
            source = path.read_text(encoding="utf-8")
            points = re.findall(r'\{ m = 1454, [^{}]+x = 79\.8, y = 24\.1, [^{}]+q = (5301|85712), a = "([AT])" \}', source)
            if not points:
                continue
            character_class = re.search(r'\bclase = "([A-Z]+)"', source)[1]
            expected = 5301 if character_class in {"WARRIOR", "PALADIN"} else 85712
            self.assertEqual(points, [(str(expected), "A"), (str(expected), "T")])
            counts[expected] += 1
        self.assertEqual(counts, {5301: 5, 85712: 17})

    def test_azshara_betrayed_uses_live_follow_ups_in_all_horde_routes(self):
        count = 0
        expected = [
            [("3504", "A"), ("3504", "T")],
            [("3505", "A"), ("3505", "C"), ("3505", "T"),
             ("91497", "A"), ("91497", "C"), ("91497", "C"), ("91497", "C"), ("91497", "T")],
            [("91500", "A"), ("91500", "T")],
            [("91531", "A"), ("91531", "T")],
        ]
        for route in (ADDON / "Rutas").glob("*.lua"):
            text = route.read_text(encoding="utf-8")
            self.assertNotRegex(text, r'\bq = 350[67],')
            stages = [line for line in text.splitlines()
                      if re.search(r"-- (?:REFUERZO_97 q=|Paso conservado )350[4-7]$", line)]
            if not stages:
                continue
            with self.subTest(route=route.name):
                count += 1
                self.assertEqual([re.findall(r'q = (\d+), a = "([ACT])"', line) for line in stages], expected)
                self.assertIn("6 reivindicadores y 6 peritos", stages[1])
                self.assertIn("Desmonta dentro del círculo", stages[2])
                self.assertIn("x = 75.2, y = 34.2", stages[3])
        self.assertEqual(count, 22)


class MissionBadgeTest(unittest.TestCase):
    def test_badge_uses_localized_category_then_the_live_tag_and_group_size(self):
        from mission_rules import load_mission_badges, load_mission_localization

        tags = load_mission_badges(ADDON, (193, 1102, 8181, 1))
        self.assertIn("ÉLITE", tags[193])
        self.assertIn("MAZMORRA", tags[1102])
        self.assertIn("BANDA", tags[8181])
        self.assertEqual(tags[1], "")

        lua = LuaRuntime(unpack_returned_tuples=True)
        localized = load_mission_localization(ADDON)["por_nombre"]
        lua.globals().translations = lua.table_from(localized)
        lua.execute("GL = {L = function(text) return translations[text] or text end, tarjetasGuia = {}}")
        _load(lua, "Opcionales.lua")
        badge = lua.globals().GL.EtiquetaMision
        self.assertIn("ELITE", badge(193)[0])
        self.assertIn("DUNGEON", badge(1102)[0])
        self.assertIn("RAID", badge(8181)[0])
        lua.execute('''C_QuestLog = {
            GetQuestTagInfo = function() return {tagID = 81} end,
            GetSuggestedGroupSize = function() return 5 end,
        }''')
        label, size = badge(8181)
        self.assertIn("DUNGEON", label)
        self.assertIn("GROUP 5", label)
        self.assertNotIn("RAID", label)
        self.assertEqual(size, 5)


class MissionPrerequisitesTest(unittest.TestCase):
    def test_rogue_upgrade_keeps_its_preparation_and_equipment_names(self):
        from mission_rules import load_mission_badges, load_mission_localization
        from world_rules import XP_OPCIONAL

        self.assertIn("MAZMORRA", load_mission_badges(ADDON, (8941,))[8941])
        translation = load_mission_localization(ADDON)["por_nombre"]
        for file in ("NoMuertoPicaro", "OrcoTrolPicaro", "SkybornePicaro"):
            route = _source(f"Rutas/{file}.lua")
            accepted = route.index('q = 8941, a = "A"')
            self.assertLess(route.index('q = 8978, a = "T"'), accepted)
            text = re.search(r't = "([^"]+)"[^\n]+-- REFUERZO_97 q=8941$', route, re.M)[1]
            self.assertTrue(XP_OPCIONAL.match(text))
            self.assertIn("Shadowcraft Belt", translation[text])
            self.assertIn("Shadowcraft Gloves", translation[text])

    def test_algaz_brutal_armor_and_mage_deliveries_follow_their_requirements(self):
        from lua_routes import load_routes
        from mission_rules import load_mission_localization
        from world_rules import XP_OPCIONAL

        routes, findings = load_routes(ADDON)
        self.assertFalse(findings)
        localized = load_mission_localization(ADDON)["por_nombre"]
        alliance = warriors = mages = 0
        for route in routes:
            steps = [step for section in route["secciones"] for step in section["pasos"]]
            points = [point for step in steps for point in step.get("wp", []) if point.get("q")]
            actions = [(point["q"], point["a"]) for point in points]
            if (473, "A") in actions:
                self.assertEqual(route["_faccion"], "Alliance")
                self.assertLess(actions.index((455, "T")), actions.index((473, "A")))
                self.assertEqual([a for q, a in actions if q == 455], ["A", "C", "T"])
                steps_to_check = [step for step in steps if any(p.get("q") in (455, 473) for p in step.get("wp", []))]
                alliance += 1
            elif (1840, "A") in actions:
                self.assertEqual(route["clase"], "WARRIOR")
                self.assertEqual([p for p in actions if p[0] in (1838, 1848, 1840)],
                                 [(1838, "A"), (1838, "T"), (1848, "A"), (1848, "T"), (1840, "A"), (1840, "T")])
                steps_to_check = [step for step in steps if any(p.get("q") in (1838, 1840) for p in step.get("wp", []))]
                warriors += 1
            elif route["_faccion"] == "Horde" and (1947, "A") in actions:
                self.assertEqual(route["clase"], "MAGE")
                self.assertEqual([p for p in actions if p[0] in (1947, 1948)],
                                 [(1947, "A"), (1947, "T"), (1948, "A"), (1948, "C"), (1948, "C"), (1948, "T")])
                self.assertEqual([p["m"] for p in points if p["q"] in (1947, 1948)],
                                 [1454, 1445, 1445, 1417, 1417, 1445])
                trainer, = [step for step in steps if "acepta [Viaje al pantano] con Deino junto al instructor" in step["t"]]
                self.assertTrue(trainer["comprobar"]["hechizos"])
                self.assertIn("Deino", localized[trainer["t"]])
                steps_to_check = [step for step in steps if any(p.get("q") in (1947, 1948) for p in step.get("wp", []))]
                mages += 1
            else:
                continue
            for step in steps_to_check:
                self.assertTrue(XP_OPCIONAL.match(step["t"]))
                self.assertTrue(localized[step["t"]].startswith("Optional"))
        self.assertEqual((alliance, warriors, mages), (25, 4, 2))


class GuardadosTest(unittest.TestCase):
    def test_migracion_legacy_preserva_identidad_progreso_y_preferencias(self):
        runtime = LuaRuntime(register_eval=False, register_builtins=False)
        runtime.execute('''
            GL = {}
            function CreateFrame()
                return { RegisterEvent = function() end, SetScript = function() end }
            end
            function Mensaje(texto) error(texto) end
            anterior = {
                ruta = "orco_trol_guerrero", seccion = 4, paso = 11, destino = 2,
                autoMisiones = false, notas = { "nota de personaje" },
                vuelos = { ["El Cruce"] = true }, escala = "25",
            }
            GuiaLeveoDB = anterior
            GuiaLeveoCuenta = { idioma = "es" }
            GuiaAventureroCuenta = { idioma = "en" }
        ''')
        _load(runtime, "Idioma.lua")
        core = _source("GuiaAventurero.lua")
        runtime.execute(_match(core, r"^local AUTOMATISMOS = [^\n]+$") + "\n"
                        + _match(core, r"^local ESQUEMA = .*?^local function Migrar\(db\)\n.*?^end$")
                        + "\nmigrar = Migrar")
        runtime.execute('''
            GL._TraerNombreViejo()
            assert(GuiaAventureroDB == anterior and GuiaLeveoDB == nil)
            assert(GuiaAventureroCuenta.idioma == "en" and GuiaLeveoCuenta == nil)
            assert(GL._LimpiarGuardado() == 1 and anterior.escala == 1.5)
            migrar(anterior)
            assert(anterior.esquema == 2 and anterior.ruta == "orco_trol_guerrero")
            assert(anterior.seccion == 4 and anterior.paso == 11 and anterior.destino == 2)
            assert(anterior.notas[1] == "nota de personaje" and anterior.vuelos["El Cruce"])
            assert(anterior.autoMisiones == false and anterior.autoVender == false)
            anterior.autoVender = true
            migrar(anterior)
            assert(anterior.autoVender == true)
            local nuevo = {}
            migrar(nuevo)
            assert(nuevo.esquema == 2 and nuevo.autoMisiones == false and nuevo.autoVender == false)
        ''')


class QuestieTest(unittest.TestCase):
    def setUp(self):
        self.runtime = LuaRuntime(register_eval=False, register_builtins=False)
        self.runtime.execute('''
            GL = { comandos = {}, alIniciar = {}, colores = {} }
            function GL.Seguro(v) return v end
            function GL.Evento() end
            function GL.Fallo(_, mensaje) error(mensaje) end
            function CreateFrame()
                return { SetScript = function(_, _, handler) evento_mision = handler end }
            end
            function GetQuestID() return 101 end
            function IsQuestCompletable() return true end
            llamadas = { acepta = 0, completa = 0, recompensa = 0 }
            function AcceptQuest() llamadas.acepta = llamadas.acepta + 1 end
            function CompleteQuest() llamadas.completa = llamadas.completa + 1 end
            function GetQuestReward() llamadas.recompensa = llamadas.recompensa + 1 end
            C_AddOns = { IsAddOnLoaded = function(nombre)
                assert(nombre == "Questie")
                return cargado
            end }
            GuiaAventureroDB = { questie976 = true, autoMisiones = true, autoSeguimiento = true }
            GL.RUTA = { secciones = {{ pasos = {{ wp = {{ q = 101, a = "A" }, { q = 101, a = "T" }} }} }} }
        ''')
        for name in ("Asistente97.lua", "Revision976.lua", "Misiones.lua"):
            _load(self.runtime, name)
        self.runtime.execute("GL.alIniciar[1]()")

    def test_eventos_de_mision_respetan_questie_y_el_estado_indeterminado(self):
        self.runtime.execute('''
            local function dialogo()
                evento_mision(nil, "QUEST_DETAIL")
                evento_mision(nil, "QUEST_PROGRESS")
                evento_mision(nil, "QUEST_COMPLETE")
            end
            cargado = true
            assert(GL.QuestieConvivencia976())
            dialogo()
            cargado = nil
            assert(GL.QuestieConvivencia976())
            dialogo()
            assert(llamadas.acepta == 0 and llamadas.completa == 0 and llamadas.recompensa == 0)
            cargado = false
            assert(not GL.QuestieConvivencia976())
            dialogo()
            assert(llamadas.acepta == 1 and llamadas.completa == 1 and llamadas.recompensa == 1)
        ''')

    def test_seguimiento_no_quita_misiones_ajenas_al_cargar_questie(self):
        experience = _source("Experiencia.lua")
        self.runtime.execute(_match(experience, r"^local function DB\(\)[^\n]*$") + "\n"
                             + _match(experience, r"^local function IndiceMision\(q\)\n.*?^GL\.ActualizarSeguimiento976 = [^\n]+$"))
        self.runtime.execute('''
            local wp = {{ q = 101, a = "C" }, { q = 102, a = "T" }}
            function GL.PasoActual() return 1, { wp = wp } end
            function GetQuestLogIndexByID(id) return id end
            local seguimientos, agregadas, retiradas = { [102] = true }, {}, {}
            function IsQuestWatched(id) return seguimientos[id] == true end
            function AddQuestWatch(id) seguimientos[id] = true; table.insert(agregadas, id) end
            function RemoveQuestWatch(id) seguimientos[id] = nil; table.insert(retiradas, id) end
            cargado = false
            GL.ActualizarSeguimiento976()
            assert(#agregadas == 1 and agregadas[1] == 101 and #retiradas == 0)
            wp = {}
            cargado = true
            GL.ActualizarSeguimiento976()
            assert(seguimientos[101] and seguimientos[102] and #retiradas == 0)
            cargado = false
            GL.ActualizarSeguimiento976()
            assert(seguimientos[101] and seguimientos[102] and #retiradas == 0)
            assert(next(GuiaAventureroDB.vigiladas) == nil)
        ''')


if __name__ == "__main__":
    unittest.main()

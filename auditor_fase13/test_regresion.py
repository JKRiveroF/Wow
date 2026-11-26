"""Integridad de la base y regresiones locales de guardados y Questie."""

import hashlib
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
    "GuiaAventurero/Idioma/enUS_Datos.lua",
    "GuiaAventurero/Idioma/enUS_Interfaz.lua",
    "GuiaAventurero/Idioma/enUS_Refuerzos97.lua",
    "GuiaAventurero/Idioma/enUS_Rutas.lua",
    "GuiaAventurero/OpcionalesKalimdor.lua",
    "GuiaAventurero/OpcionalesOtras.lua",
    "GuiaAventurero/OpcionalesReinos.lua",
}
NO_XP_TEXT_QUESTS = {
    734, 777, 975, 1191, 2582, 2584, 2586, 2602, 2604, 2662, 3503, 4463, 5150,
    *range(4381, 4387), *range(4481, 4485), *range(4801, 4808),
}
SALVE_QUESTS = set(range(4103, 4113)) | set(range(5882, 5892))
SALVE_ORIGINALS = {
    **{quest: quest - 1779 for quest in range(5882, 5887)},
    **{quest: quest - 5 for quest in range(5887, 5892)},
    **{quest: quest + 5 for quest in range(4103, 4108)},
    **{quest: quest + 1779 for quest in range(4108, 4113)},
}


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
    lines = []
    for line in source.splitlines(keepends=True):
        refuerzo = re.search(r"-- REFUERZO_97 q=(\d+)\s*$", line)
        if refuerzo and (quest := int(refuerzo[1])) in SALVE_QUESTS:
            if 't = "Bálsamo de Frondavil:' in line or 't = "Canje opcional:' in line:
                line = re.sub(rf"(\bq\s*=\s*){quest}\b", lambda match: match[1] + str(SALVE_ORIGINALS[quest]), line)
            line = re.sub(r't = "[^"]+"', 't = "<bálsamo revisado>"', line, count=1)
        invasion = re.search(r"-- (?:REFUERZO_97 q=|Paso conservado )(926[34])\s*$", line)
        if invasion:
            line = re.sub(r'\{ t = ".*', f'<paso de invasión revisado {invasion[1]}>', line)
        if refuerzo and int(refuerzo[1]) in NO_XP_TEXT_QUESTS:
            line = re.sub(r't = "[^"]+"', 't = "<recompensa revisada>"', line, count=1)
        line = re.sub(original_alterac, 'm = 1459, z = "<etiqueta revisada>"', line)
        if line.rstrip().endswith(("-- REFUERZO_97 q=3520", "-- REFUERZO_97 q=1878",
                                   "-- REFUERZO_97 q=5301", "-- REFUERZO_97 q=5283")):
            line = re.sub(r't = "[^"]+"', 't = "<instrucciones revisadas>"', line, count=1)
            line = re.sub(obsolete_objective, "", line)
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
        self.assertEqual(total, 1136)

    def test_felwood_first_turn_ins_and_repeatables_follow_the_right_faction(self):
        from mission_rules import load_mission_localization

        localized = load_mission_localization(ADDON)["por_nombre"]
        removed = 0
        for name in self.routes:
            text = (ROOT / name).read_text(encoding="utf-8")
            self.assertNotRegex(text, r"\bq = 926[34]\b")
            removed += text.count("-- Paso conservado")
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

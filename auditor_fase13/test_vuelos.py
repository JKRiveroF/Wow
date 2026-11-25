"""Regresión de los pasos de vuelo con el catálogo real y API Taxi simuladas."""

import re
import unittest
from pathlib import Path

from lupa.lua51 import LuaRuntime


ADDON = Path(__file__).resolve().parents[1] / "GuiaAventurero"
CORE = (ADDON / "GuiaAventurero.lua").read_text(encoding="utf-8-sig")


def _function(name):
    pattern = rf"^(?:local )?function {re.escape(name)}\([^\n]*\)\n.*?^end$"
    match = re.search(pattern, CORE, re.MULTILINE | re.DOTALL)
    if not match:
        raise AssertionError(f"Función del motor no encontrada: {name}")
    return match[0]


def _create_runtime(locale, language):
    runtime = LuaRuntime(register_eval=False, register_builtins=False)
    runtime.globals().locale, runtime.globals().idioma = locale, language
    runtime.execute('''
        GL = {}
        GuiaAventureroCuenta = { idioma = idioma }
        function GetLocale() return locale end
        function CreateFrame()
            return {
                RegisterEvent = function() end,
                UnregisterEvent = function() end,
                SetScript = function(_, _, handler) al_cargar = handler end,
            }
        end
        function Seguro(value) return value end
        function UnitLevel() return 20 end
    ''')
    for line in (ADDON / "GuiaAventurero.toc").read_text(encoding="utf-8-sig").splitlines():
        entry = line.strip().replace("\\", "/")
        if entry == "Idioma.lua" or entry.startswith("Idioma/") and entry.endswith(".lua"):
            source = (ADDON / entry).read_text(encoding="utf-8-sig")
            runtime.execute(source, ADDON.name, runtime.globals().GL, name=f"@{entry}")
    runtime.execute('al_cargar(CreateFrame(), "ADDON_LOADED", "GuiaAventurero")')
    names = ("VueloConocido", "GL.EstadoVueloConocido", "GuardarVuelos", "ComprobacionesHechas", "EstadoPaso")
    runtime.execute("\n".join(_function(name) for name in names) + '''
        guardar_vuelos = GuardarVuelos
        estado_paso = EstadoPaso
        function paso_de_vuelo(nombre)
            local paso = { comprobar = { vuelo = nombre } }
            GL.TraducirRuta({ secciones = {{ pasos = { paso } }} })
            return paso
        end
    ''')
    return runtime


class EstadoDeVueloTest(unittest.TestCase):
    def test_cliente_ingles_reconoce_guardado_anterior_en_espanol(self):
        runtime = _create_runtime("enUS", "es")
        runtime.globals().GuiaAventureroDB = runtime.table_from({
            "vuelos": {"El Cruce, Los Baldíos": True, "Refugio Roca del Sol, Sierra Espolón": True},
        }, recursive=True)
        for name, expected in (("El Cruce", "The Crossroads"), ("Roca del Sol", "Sun Rock")):
            with self.subTest(name=name):
                step = runtime.globals().paso_de_vuelo(name)
                self.assertEqual(step.comprobar.vuelo, expected)
                self.assertEqual(runtime.globals().estado_paso(step), "hecho")

    def test_cliente_y_guia_en_espanol_reconocen_claves_inglesas(self):
        runtime = _create_runtime("esES", "es")
        for alias, saved in (
            ("Hachazo", "Splintertree Post"), ("Juncobrezo", "Brackenwall Village"),
            ("Mojache", "Camp Mojache"), ("Roca del Sol", "Sun Rock Retreat"),
            ("Sangrevenenosa", "Bloodvenom Post"), ("Sombraprensa", "Shadowprey Village"),
            ("Viento Libre", "Freewind Post"), ("El Cruce", "THE CROSSROADS"),
        ):
            with self.subTest(alias=alias):
                runtime.globals().GuiaAventureroDB = runtime.table_from({"vuelos": {saved: True}}, recursive=True)
                step = runtime.globals().paso_de_vuelo(alias)
                self.assertEqual(step.comprobar.vuelo, alias)
                self.assertEqual(runtime.globals().estado_paso(step), "hecho")

    def test_pasos_desconocidos_o_incompletos_siguen_manuales(self):
        runtime = _create_runtime("esMX", "en")
        runtime.globals().GuiaAventureroDB = runtime.table_from({
            "vuelos": {"The Crossroads, The Barrens": False, "Gadgetzan, Tanaris": True, 1: True},
        }, recursive=True)
        for alias in ("La Bahía del Botín", "El Cruce", ""):
            with self.subTest(alias=alias):
                step = runtime.globals().paso_de_vuelo(alias)
                self.assertEqual(runtime.globals().estado_paso(step), "manual")
        step = runtime.globals().paso_de_vuelo("Gadgetzan")
        self.assertEqual(runtime.globals().estado_paso(step), "hecho")
        step.comprobar.nivel = 21
        self.assertEqual(runtime.globals().estado_paso(step), "manual")

    def test_taxi_clasico_y_moderno_solo_guardan_estados_positivos(self):
        runtime = _create_runtime("enUS", "en")
        runtime.execute('''
            GuiaAventureroDB = { vuelos = { ["Gadgetzan, Tanaris"] = true } }
            local clasicos = {
                { "El Cruce, Los Baldíos", "CURRENT" },
                { "Trinquete, Los Baldíos", "REACHABLE" },
                { "Hachazo, Vallefresno", "DISTANT" },
            }
            function NumTaxiNodes() return #clasicos end
            function TaxiNodeName(i) return clasicos[i][1] end
            function TaxiNodeGetType(i) return clasicos[i][2] end
            function GetTaxiMapID() return 1 end
            C_TaxiMap = { GetAllTaxiNodes = function()
                return {
                    { name = "Forjaz, Dun Morogh", state = 0 },
                    { name = "Entrañas, Claros de Tirisfal", state = 1 },
                    { name = "Sañadiente, Tierras del Interior", state = 2 },
                    { name = "Sombraprensa, Desolace" },
                }
            end }
            guardar_vuelos()
        ''')
        saved = dict(runtime.globals().GuiaAventureroDB.vuelos.items())
        self.assertEqual(set(saved), {
            "Gadgetzan, Tanaris", "El Cruce, Los Baldíos", "Trinquete, Los Baldíos",
            "Forjaz, Dun Morogh", "Entrañas, Claros de Tirisfal",
        })
        self.assertTrue(all(value is True for value in saved.values()))
        for alias in ("El Cruce", "Trinquete", "Forjaz", "Entrañas"):
            with self.subTest(alias=alias):
                self.assertEqual(runtime.globals().estado_paso(runtime.globals().paso_de_vuelo(alias)), "hecho")


if __name__ == "__main__":
    unittest.main()

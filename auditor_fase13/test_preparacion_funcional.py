"""Ensayos locales del candidato en Lua 5.1 y en una instalación aislada."""

import math
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from zipfile import ZipFile

from funcional import addon_fingerprint, package_entries, verify_package
from lua_routes import load_routes
from test_perfiles_forever import ADDON, lua_for_addon


class PreparacionMotorTest(unittest.TestCase):
    def setUp(self):
        self.lua, self.guide, self.load = lua_for_addon()
        self.lua.execute('''
            nivel, mapa, px, py = 17, 1420, 0.2, 0.2
            mensajes, eventos, hechizos = {}, {}, {}
            DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(mensajes, text) end }
            SlashCmdList = {}
            function UnitLevel() return nivel end
            function GetPlayerFacing() return 0 end
            function CreateFrame()
              local frame = { registered = {} }
              function frame:RegisterEvent(event) self.registered[event] = true end
              function frame:SetScript(event, handler)
                if event == "OnEvent" then table.insert(eventos, { frame = self, handler = handler }) end
              end
              return frame
            end
            function CreateVector2D(x, y)
              return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
            end
            UiMapPoint = { CreateFromCoordinates = function(m, x, y)
                return { uiMapID = m, position = CreateVector2D(x, y) }
            end }
            C_Map = {
              GetBestMapForUnit = function() return mapa end,
              GetPlayerMapPosition = function() return CreateVector2D(px, py) end,
              GetMapInfo = function(m) return m == 9900 and { mapType = 4, parentMapID = 1421 } or nil end,
              GetWorldPosFromMapPos = function(m, pos)
                return m == 1444 and 2 or 1, CreateVector2D(pos.x * 1000, pos.y * 1000)
              end,
              GetUserWaypoint = function() return marca end,
              SetUserWaypoint = function(p) marca = p end,
              ClearUserWaypoint = function() marca = nil end,
            }
            Enum = { SpellBookSpellBank = { Player = 0 } }
            C_SpellBook = { IsSpellKnown = function(id, bank) return bank == 0 and hechizos[id] == true end }
            function UnitIsDeadOrGhost() return false end
            function InCombatLockdown() return false end
            function UnitAffectingCombat() return false end
            function Emitir(event, ...)
              for _, listener in ipairs(eventos) do
                if listener.frame.registered[event] then listener.handler(listener.frame, event, ...) end
              end
            end
        ''')
        self.load("Idioma.lua")
        source = (ADDON / "GuiaAventurero.lua").read_text(encoding="utf-8-sig")
        # Aísla el repintado de las ventanas y expone el punto de entrada privado de la flecha.
        self.lua.execute(source + '''
            function GL.EnsayoRuta(ruta)
              RUTA, frame = ruta, { IsShown = function() return true end }
              Refrescar = function() end
              GuiaAventureroDB = { seccion = 1, paso = 1, destino = 1, modo = "guia" }
              return GuiaAventureroDB
            end
            function GL.EnsayoFlecha(widget)
              flecha = widget
              ActualizarFlecha()
            end
        ''', ADDON.name, self.guide, name="@GuiaAventurero.lua")

    def test_marker_and_arrow_follow_the_destination_and_respect_questie(self):
        self.load("Mapa.lua")
        self.lua.globals().Guide = self.guide
        east, south, preserved = self.lua.execute('''
            local db = Guide.EnsayoRuta({ secciones = {{ pasos = {{ wp = {
              { m = 1420, x = 70, y = 20, n = "Este" },
              { m = 1420, x = 20, y = 70, n = "Sur" },
              { m = 1444, x = 20, y = 70, n = "Otro", z = "Feralas" },
            } }} }} })
            local text = function() return { SetText = function(self, value) self.value = value end } end
            local arrow = { puedeGirar = true, texto = text(), dist = text(), tex = {
              Show = function(self) self.visible = true end, Hide = function(self) self.visible = false end,
              SetRotation = function(self, value) self.rotation = value end, SetVertexColor = function() end,
            } }
            local function capture()
              Guide.ActualizarMarca()
              Guide.EnsayoFlecha(arrow)
              return { map = marca.uiMapID, x = marca.position.x, y = marca.position.y,
                       rotation = arrow.tex.rotation, dist = arrow.estado.dist, visible = arrow.tex.visible }
            end
            local first = capture()
            db.destino = 2
            local second = capture()
            Guide.QuestieConvivencia976 = function() return true end
            Guide.ActualizarMarca()
            assert(marca == nil, "La guía debe retirar su propia marca con Questie")
            local external = UiMapPoint.CreateFromCoordinates(1421, 0.50, 0.60)
            marca = external
            db.destino = 3
            Guide.ActualizarMarca()
            Guide.EnsayoFlecha(arrow)
            assert(not arrow.tex.visible and arrow.estado == nil and arrow.texto.value:find("Feralas"))
            Guide.QuestieConvivencia976 = function() return false end
            Guide.ActualizarMarca()
            return first, second, marca == external
        ''')
        for mark, x, y, rotation in ((east, .7, .2, -math.pi / 2), (south, .2, .7, -math.pi)):
            self.assertEqual((mark["map"], mark["x"], mark["y"], mark["visible"]), (1420, x, y, True))
            self.assertAlmostEqual(mark["rotation"], rotation)
            self.assertAlmostEqual(mark["dist"], 500)
        self.assertTrue(preserved)

    def test_level_event_and_same_session_step_progression(self):
        self.lua.globals().Guide = self.guide
        before, after, reached, message = self.lua.execute('''
            local db = Guide.EnsayoRuta({ talentos = {}, secciones = {
              { min = 17, max = 20, pasos = {{ t = "Sube de nivel", comprobar = { nivel = 20 } }} },
              { min = 20, max = 25, pasos = {
                  { t = "Primer destino", wp = {{ m = 1421, x = 50, y = 50 }} },
                  { t = "Segundo destino", wp = {{ m = 1422, x = 50, y = 50 }} },
              } },
            } })
            local function position()
              local d = Guide.DestinoActual()
              return {db.seccion, db.paso, db.destino, d and d.m}
            end
            Guide.IrAMiNivel()
            local before = position()
            nivel = 20
            Emitir("PLAYER_LEVEL_UP", 20)
            local after = position()
            Guide.Siguiente()
            local reached = position()
            Guide.IrAMiNivel()
            assert(db.seccion == 2 and db.paso == 1 and db.destino == 1)
            return before, after, reached, table.concat(mensajes, " ")
        ''')
        self.assertEqual(list(before.values()), [1, 1, 1])
        self.assertEqual(tuple(after[i] for i in range(1, 5)), (2, 1, 1, 1421))
        self.assertEqual(tuple(reached[i] for i in range(1, 5)), (2, 2, 1, 1422))
        self.assertIn("Mi nivel", message)

    def test_travel_waits_for_discovery_and_arrival_including_child_maps(self):
        self.lua.globals().Guide = self.guide
        unknown, learned, wrong_map, arrived = self.lua.execute('''
            local db = Guide.EnsayoRuta({ secciones = {{ pasos = {
              { t = "Aprender vuelo", comprobar = { vuelo = "The Sepulcher" } },
              { t = "Llegar", comprobar = { llegar = 1421 } },
              { t = "Continuar en la zona", wp = {{ m = 1421, x = 50, y = 50 }} },
            } }} })
            db.vuelos = { ["The Sepulcher, Silverpine Forest"] = false }
            Guide.Sincronizar()
            local unknown = db.paso
            db.vuelos["The Sepulcher, Silverpine Forest"] = true
            Guide.Sincronizar()
            local learned = db.paso
            mapa = 1444
            Emitir("ZONE_CHANGED_NEW_AREA")
            local wrongMap = db.paso
            mapa = 9900
            Emitir("ZONE_CHANGED_NEW_AREA")
            local d = Guide.DestinoActual()
            return unknown, learned, wrongMap, { db.paso, db.destino, d.m }
        ''')
        self.assertEqual((unknown, learned, wrong_map), (1, 2, 2))
        self.assertEqual(tuple(arrived[i] for i in range(1, 4)), (3, 1, 1421))

    def test_spell_learned_event_advances_only_after_the_book_changes(self):
        self.lua.globals().Guide = self.guide
        pending, advanced = self.lua.execute('''
            local db = Guide.EnsayoRuta({ equivalentes = { [1066] = { 91066 } }, secciones = {{ pasos = {
              { t = "Forma acuática", comprobar = { nivel = 16, hechizos = { 1066 } } },
              { t = "Continuar", wp = {{ m = 1421, x = 50, y = 50 }} },
            } }} })
            hechizos[91067] = true
            Emitir("SPELLS_CHANGED")
            local pending = db.paso
            hechizos[91066] = true
            Emitir("LEARNED_SPELL_IN_SKILL_LINE")
            return pending, db.paso
        ''')
        self.assertEqual((pending, advanced), (1, 2))

    def test_alternative_requires_a_confirmed_inactive_primary_quest(self):
        self.lua.globals().Guide = self.guide
        self.lua.execute('''
            local journal, completed = { [2] = true }, {}
            C_QuestLog = {
              IsOnQuest = function(id) return journal[id] end,
              IsQuestFlaggedCompleted = function(id) return completed[id] == true end,
            }
            local step = { q = 1, a = "T", alternativa = 2 }
            assert(Guide.DestinoHecho(step) == false)
            journal[1] = false
            assert(Guide.DestinoHecho(step) == true)
            journal[1] = true
            assert(Guide.DestinoHecho(step) == false)
            journal[2], completed[2] = false, true
            assert(Guide.DestinoHecho(step) == false)
            journal[1] = false
            assert(Guide.DestinoHecho(step) == true)
        ''')


class PreparacionPaqueteTest(unittest.TestCase):
    def test_integrated_modules_run_in_toc_order(self):
        lua, guide, load = lua_for_addon()
        lua.execute('''
            SlashCmdList = {}
            tooltip_hooks = {}
            GameTooltip = {
              HasScript = function(_, script) return script == "OnTooltipSetItem" end,
              HookScript = function(_, script, fn) table.insert(tooltip_hooks, { script, fn }) end,
            }
            function GetBuildInfo() return "1.60.1", "71139", "2026", 16001 end
            function InCombatLockdown() return false end
            function UnitAffectingCombat() return false end
            function UnitIsDeadOrGhost() return false end
            function GetTime() return 0 end
        ''')
        toc = (ADDON / "GuiaAventurero.toc").read_text(encoding="utf-8-sig").splitlines()
        for line in toc:
            if line.endswith(".lua") and not line.startswith("#"):
                load(line.replace("\\", "/"))
        self.assertEqual(guide["VERSION"], "9.8.0")
        self.assertEqual(len(lua.globals()["GuiaAventurero_Rutas"]), 47)
        self.assertEqual(len(guide["erroresCarga"]), 0)
        self.assertGreaterEqual(lua.eval('#tooltip_hooks'), 2)
        self.assertEqual(lua.eval('type(SlashCmdList.GUIAAVENTURERO)'), "function")

    def test_candidate_installs_and_loads_clean_and_over_the_original(self):
        entries = package_entries(ADDON)
        fingerprint = addon_fingerprint(entries)
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            package = root / "candidato.zip"
            verify_package(package, entries, fingerprint, create=True)
            with ZipFile(package) as candidate, ZipFile(ADDON.parent / "GuiaAventurero-9.7.9.zip") as original:
                for upgrade in (False, True):
                    with self.subTest(actualizacion=upgrade):
                        installation = root / ("actualizacion" if upgrade else "limpia")
                        addons = installation / "Interface" / "AddOns"
                        addons.mkdir(parents=True)
                        saved = installation / "WTF" / "Account" / "Ensayo" / "SavedVariables" / "GuiaAventurero.lua"
                        if upgrade:
                            legacy = [name for name in original.namelist() if not name.endswith("/")]
                            self.assertTrue(set(legacy).issubset(entries))
                            original.extractall(addons, members=legacy)
                            saved.parent.mkdir(parents=True)
                            saved.write_bytes(b"GuiaAventureroDB = { seccion = 2, paso = 3, destino = 2, auto = false }\n")
                        previous = saved.read_bytes() if upgrade else None
                        candidate.extractall(addons, members=entries)
                        installed = addons / ADDON.name
                        self.assertEqual(addon_fingerprint(package_entries(installed)), fingerprint)
                        routes, findings = load_routes(installed)
                        self.assertFalse([row for row in findings if row["gravedad"] == "error"])
                        self.assertEqual(len(routes), 47)
                        self.assertEqual(sum(len(row["razas"]) for row in routes), 56)
                        self.assertEqual(saved.read_bytes() if saved.exists() else None, previous)

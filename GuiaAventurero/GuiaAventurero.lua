-- GuiaAventurero.lua
-- Guia de leveo 1-60 con rutas por clase y raza para WoW Forever. Creado por JKRiveroF.
-- Cada ruta vive en Rutas\<Nombre>.lua y se registra en GuiaAventurero_Rutas.
-- Cliente moderno de Forever (interfaz 16001, Lua 5.1): self, C_Map, C_SkillInfo, C_QuestLog y GetPlayerFacing.
-- Los demas archivos (Opciones, Misiones, Instructor, Mapa) usan lo que este exporta en la tabla del addon (GL).

local _, GL = ...
if type(GL) ~= "table" then GL = {} end
GL.alIniciar = GL.alIniciar or {}      -- funciones que se llaman al cargar la ruta y crear las ventanas
GL.trasRefrescar = GL.trasRefrescar or {} -- funciones que se llaman despues de cada refresco
GL.comandos = GL.comandos or {}        -- subcomandos de /ga que añaden los otros archivos
GL.modos = GL.modos or {}
GL.tarjetasGuia = GL.tarjetasGuia or {}   -- 6.9: funciones (panel, y, ancho) -> alto, encima de la caja del paso              -- paneles extra de la ventana (por ejemplo "opciones")
GL.alReiniciar = GL.alReiniciar or {}  -- funciones que se llaman con /ga reset
GL.erroresCarga = GL.erroresCarga or {}
-- 9.1: errores de los módulos mientras juegas (los últimos 20, sin repetir), para /ga informe.
-- Devuelve si hay que avisar también en el chat (/ga depurar errores).
GL.erroresJuego = GL.erroresJuego or {}
function GL.Fallo(origen, err)
  local texto = tostring(origen or "?") .. ": " .. tostring(err)
  local lista = GL.erroresJuego
  for i = 1, #lista do
    if lista[i].texto == texto then lista[i].veces = lista[i].veces + 1; return GL.depurar end
  end
  table.insert(lista, { texto = texto, veces = 1, hora = (date and date("%H:%M")) or "?" })
  while #lista > 20 do table.remove(lista, 1) end
  return GL.depurar
end
-- 8.6: token de la raza del jugador. Los Skyborne (raza nueva de Forever, en las dos facciones) se reconocen por su
-- número de raza (95 Alianza, 96 Horda), por si el token del cliente no es "Skyborne".
function GL.Raza()
  if not UnitRace then return nil end
  local _, token, id = UnitRace("player")
  if id == 95 or id == 96 or (type(token) == "string" and token:lower():find("skyborne")) then return "Skyborne" end
  return token
end
-- 7.9.6: registra un evento sin romper el archivo si el cliente no lo tiene (LEARNED_SPELL_IN_TAB ya no existe
-- en 1.60 y cortaba la carga de Pantalla.lua: por eso no salían los buffs). Se pueden dar varios nombres: vale el primero que exista.
function GL.Evento(frame, ...)
  for i = 1, select("#", ...) do
    local e = select(i, ...)
    local ok, registrado = pcall(frame.RegisterEvent, frame, e)
    -- Algunos clientes devuelven false en vez de lanzar un error. nil sigue siendo válido.
    if ok and registrado ~= false then return true end
  end
  table.insert(GL.erroresCarga, GL.L"evento que el juego no tiene: " .. table.concat({ ... }, " / "))
  return false
end

local AZUL = "|cff69ccf0"
local AMARILLO = "|cffffd100"
local VERDE = "|cff1eff00"
local GRIS = "|cffb4b4b8"   -- 8.9.5: más claro, se lee mejor sobre el fondo oscuro
local BLANCO = "|cffffffff"
local FIN = "|r"
local AUTOR = GL.L"Creado por JKRiveroF"

-- Texturas del juego y del addon
local RUTA_FLECHA = "Interface\\AddOns\\GuiaAventurero\\flecha"
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"
local BORDE_VENTANA = "Interface\\Tooltips\\UI-Tooltip-Border"
local INTERROGANTE = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICONO_HECHO = "Interface\\Buttons\\UI-CheckBox-Check"
local ICONO_LUGAR = "Interface\\Icons\\INV_Misc_Map_01"
local ICONO_ACCION = {
  A = "Interface\\GossipFrame\\AvailableQuestIcon",          -- recoger (!)
  C = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",   -- objetivo (estrella)
  T = "Interface\\GossipFrame\\ActiveQuestIcon",             -- entregar (?)
}

-- Medidas (la ventana se redimensiona desde la esquina inferior derecha)
local ANCHO, ALTO = 470, 620     -- 9.0: estilo moderno, con la barra lateral de iconos
local MIN_ANCHO, MIN_ALTO = 400, 600   -- 9.4: cabe el botón Oro con Mascotas y Grupo
local MAX_ANCHO, MAX_ALTO = 900, 1100
local MARGEN = 12              -- margen derecho del contenido (9.0: el izquierdo es GL.IZQ, tras la barra lateral)
local ARRIBA, ABAJO = 54, 20   -- 9.0: arriba solo va la barra de XP; abajo, el autor
local ALTO_SUB = 32            -- fila de subpestañas (Personaje y Opciones), 9.0: selector segmentado
GL.RAIL = 52                   -- 9.0: ancho de la barra lateral de iconos
GL.IZQ = GL.RAIL + 12          -- 9.0: margen izquierdo del contenido
-- Subpestañas (6.0.1): Personaje junta Talentos y Hechizos; Opciones (la rueda) junta Ajustes y Novedades.
local LADO = { reputacion = true, mazmorras = true, biblioteca = true, cuenta = true, coleccion = true }   -- 6.6/6.7: modos de los botones del lateral derecho
local GRUPOS = { clase = "personaje", talentos = "personaje", hechizos = "personaje", equipo = "personaje", estadisticas = "personaje", opciones = "opciones", automatismos = "opciones", novedades = "opciones" }
-- Automatismos (6.0.2): apagados en los personajes nuevos; los ya empezados conservan lo que tenían.
local AUTOMATISMOS = { "auto", "autoDestino", "autoMisiones", "autoHechizos", "autoRecetas", "autoTalentos", "autoVender" }
local Y_CAJA = 92              -- donde empieza la caja del paso en la pestaña Guía
local ALTO_DESTINO = 18
local MAX_DESTINOS = 12         -- filas de objetivos: Siguiente, Cerca de ti y Completado (6.1)
local MAX_CERCA = 3
local CERCA = 219               -- yardas (200 m) para "Cerca de ti"
local MAX_FILAS = 12
local HUECO = 4
local LLEGADA = 12             -- yardas para dar el destino por alcanzado

local COLOR = {
  fondo = { 0.082, 0.090, 0.122, 0.97 },   -- 9.0: estilo moderno (#15171f)
  borde = { 0.165, 0.176, 0.227, 1 },
  caja = { 0.114, 0.125, 0.161, 0.92 },    -- tarjetas (#1d2029)
  cajaBorde = { 0.184, 0.200, 0.259, 1 },
  boton = { 0.133, 0.145, 0.184, 1 },      -- #22252f
  botonBorde = { 0.133, 0.145, 0.184, 1 },
  rail = { 0.055, 0.063, 0.086, 1 },       -- 9.0: barra lateral (#0e1016)
  segmento = { 0.165, 0.176, 0.227, 1 },   -- 9.0: opción elegida del selector segmentado
  activo = { 0.27, 0.21, 0.07, 1 },
  activoBorde = { 1, 0.78, 0.25, 1 },
  actual = { 0.12, 1, 0, 0.09 },
  elegido = { 1, 0.82, 0, 0.12 },
  icono = { 0, 0, 0, 1 },
  iconoBorde = { 0.45, 0.42, 0.35, 1 },
  iconoActual = { 0.12, 1, 0, 1 },
  iconoPasado = { 0.25, 0.25, 0.25, 1 },
  -- tema: un solo acento dorado y un secundario cian
  acento = { 1, 0.78, 0.25, 1 },
  cian = { 0.41, 0.80, 0.94, 1 },
  verde = { 0.25, 0.85, 0.35, 1 },
  gris = { 0.66, 0.67, 0.73, 1 },   -- 8.9.5: más contraste
  pestana = { 0, 0, 0, 0 },
  pestanaActiva = { 0.49, 0.42, 1, 0.14 },
  accion = { 0.20, 0.16, 0.06, 1 },
  accionBorde = { 0.65, 0.50, 0.18, 1 },
  flechaFondo = { 0.04, 0.045, 0.065, 0.80 },
  flechaBorde = { 0.30, 0.31, 0.39, 1 },
}

-- Temas: solo cambian los colores del acento. Se eligen en Opciones y se aplican al momento.
local TEMAS = {
  -- 9.0: el morado del estilo moderno es el tema de partida; la acción va rellena del color del acento
  { id = "morado", nombre = GL.L"Morado", acento = { 0.49, 0.42, 1 }, oscuro = { 0.17, 0.15, 0.36 }, accion = { 0.42, 0.36, 0.90 }, accionBorde = { 0.49, 0.42, 1 } },
  { id = "dorado", nombre = GL.L"Dorado", acento = { 1, 0.78, 0.25 }, oscuro = { 0.27, 0.21, 0.07 }, accion = { 0.20, 0.16, 0.06 }, accionBorde = { 0.65, 0.50, 0.18 } },
  { id = "azul", nombre = GL.L"Azul", acento = { 0.38, 0.66, 1 }, oscuro = { 0.08, 0.16, 0.30 }, accion = { 0.06, 0.12, 0.22 }, accionBorde = { 0.22, 0.42, 0.72 } },
  { id = "verde", nombre = GL.L"Verde", acento = { 0.55, 0.92, 0.38 }, oscuro = { 0.12, 0.24, 0.08 }, accion = { 0.09, 0.18, 0.06 }, accionBorde = { 0.32, 0.60, 0.20 } },
  -- 7.1: pergamino, el único que cambia también el fondo y el borde de la ventana (cuero oscuro y borde de pergamino)
  { id = "pergamino", nombre = GL.L"Pergamino", acento = { 0.88, 0.70, 0.40 }, oscuro = { 0.30, 0.22, 0.10 }, accion = { 0.24, 0.17, 0.08 }, accionBorde = { 0.70, 0.52, 0.25 },
    fondo = { 0.17, 0.13, 0.08 }, borde = { 0.62, 0.48, 0.26 } },
  -- 8.8: el acento toma el color de la clase del personaje (se calcula al aplicarlo)
  -- 8.9.1: cuatro temas más, con su fondo y su borde
  { id = "hielo", nombre = GL.L"Hielo", acento = { 0.55, 0.86, 1 }, oscuro = { 0.10, 0.20, 0.27 }, accion = { 0.07, 0.15, 0.20 }, accionBorde = { 0.32, 0.58, 0.72 },
    fondo = { 0.035, 0.055, 0.08 }, borde = { 0.30, 0.42, 0.52 } },
  { id = "fuego", nombre = GL.L"Fuego", acento = { 1, 0.48, 0.16 }, oscuro = { 0.30, 0.12, 0.04 }, accion = { 0.22, 0.09, 0.03 }, accionBorde = { 0.72, 0.32, 0.10 },
    fondo = { 0.075, 0.04, 0.03 }, borde = { 0.48, 0.24, 0.14 } },
  { id = "sombra", nombre = GL.L"Sombra", acento = { 0.66, 0.50, 0.92 }, oscuro = { 0.17, 0.11, 0.25 }, accion = { 0.12, 0.08, 0.18 }, accionBorde = { 0.42, 0.30, 0.62 },
    fondo = { 0.03, 0.02, 0.045 }, borde = { 0.28, 0.22, 0.38 } },
  { id = "naturaleza", nombre = GL.L"Naturaleza", acento = { 0.56, 0.85, 0.36 }, oscuro = { 0.13, 0.22, 0.08 }, accion = { 0.09, 0.16, 0.06 }, accionBorde = { 0.36, 0.56, 0.22 },
    fondo = { 0.04, 0.06, 0.035 }, borde = { 0.28, 0.38, 0.22 } },
  { id = "clase", nombre = GL.L"Clase", clase = true, acento = { 0.78, 0.61, 0.43 }, oscuro = { 0.21, 0.16, 0.12 }, accion = { 0.16, 0.12, 0.09 }, accionBorde = { 0.51, 0.40, 0.28 } },
}

-- 8.8: color de la clase del jugador (r, g, b) y su código para el texto
-- (va en GL y no como local: el archivo está en el límite de 200 locales de Lua 5.1)
function GL.ColorDeClase()
  if not UnitClass then return nil end
  local _, token = UnitClass("player")
  local c = token and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]))
  if c and type(c.r) == "number" then return c.r, c.g, c.b end
  return nil
end
local FONDO_BASE, BORDE_BASE = { 0.082, 0.090, 0.122 }, { 0.165, 0.176, 0.227 }

local function BuscarTema(id)
  for i = 1, #TEMAS do
    if TEMAS[i].id == id then return TEMAS[i] end
  end
  return TEMAS[1]
end

-- Cambia en la tabla COLOR los colores del acento. Las tablas se cambian por dentro (no se sustituyen) para
-- que los botones, que ya las tienen guardadas, vean el color nuevo.
local function Poner(destino, r, g, b, a)
  destino[1], destino[2], destino[3], destino[4] = r, g, b, a
end

local function AplicarTema(id)
  local t = BuscarTema(id)
  if t.clase then
    local okC, r, g, b = pcall(GL.ColorDeClase)
    if okC and r then
      Poner(t.acento, r, g, b); Poner(t.oscuro, r * 0.27, g * 0.27, b * 0.27)
      Poner(t.accion, r * 0.2, g * 0.2, b * 0.2); Poner(t.accionBorde, r * 0.65, g * 0.65, b * 0.65)
    end
  end
  local a = t.acento
  Poner(COLOR.acento, a[1], a[2], a[3], 1)
  Poner(COLOR.activoBorde, a[1], a[2], a[3], 1)
  Poner(COLOR.pestanaActiva, a[1], a[2], a[3], 0.10)
  Poner(COLOR.elegido, a[1], a[2], a[3], 0.12)
  Poner(COLOR.activo, t.oscuro[1], t.oscuro[2], t.oscuro[3], 1)
  Poner(COLOR.accion, t.accion[1], t.accion[2], t.accion[3], 1)
  Poner(COLOR.accionBorde, t.accionBorde[1], t.accionBorde[2], t.accionBorde[3], 1)
  local f, b = t.fondo or FONDO_BASE, t.borde or BORDE_BASE
  Poner(COLOR.fondo, f[1], f[2], f[3], COLOR.fondo[4])
  Poner(COLOR.borde, b[1], b[2], b[3], 1)
  return t
end

-- Al cambiar de tema se repinta lo que ya esta creado. Cada pieza que usa el acento se apunta con PorTema,
-- que ademas la pinta una vez al crearla; los botones se repintan todos juntos (botonesTema).
local alCambiarTema = {}
local botonesTema = {}
local function PorTema(pintar)
  table.insert(alCambiarTema, pintar)
  pintar()
end

-- Respaldo si el cliente no da posiciones del mundo: tamano aproximado de cada mapa en yardas.
local TAMANO_ZONA = {
  ["Dun Morogh"] = { 4925, 3283 },
  ["Forjaz"] = { 790, 527 },
  ["Loch Modan"] = { 2758, 1839 },
  ["Ciudad de Ventormenta"] = { 1737, 1158 },
  ["Bosque de Elwynn"] = { 3470, 2314 },
  ["Páramos de Poniente"] = { 3500, 2333 },
  ["Montañas Crestagrana"] = { 2170, 1447 },
  ["Los Humedales"] = { 4135, 2756 },
  ["Bosque del Ocaso"] = { 2700, 1800 },
  ["Las Mil Agujas"] = { 4400, 2933 },
  ["Desolace"] = { 4495, 2997 },
  ["Vega de Tuercespina"] = { 6381, 4254 },
  ["Laderas de Trabalomas"] = { 3200, 2133 },
  ["Montañas de Alterac"] = { 2800, 1866 },
  ["Tierras Altas de Arathi"] = { 3600, 2400 },
  ["Marjal Revolcafango"] = { 5250, 3500 },
  ["Tanaris"] = { 6900, 4600 },
  ["Feralas"] = { 6950, 4633 },
  ["Tierras del Interior"] = { 3850, 2566 },
  ["Cráter de Un'Goro"] = { 3700, 2466 },
  ["Frondavil"] = { 5750, 3833 },
  ["Cuna del Invierno"] = { 7100, 4733 },
  ["Tierras de la Peste del Oeste"] = { 4300, 2866 },
  ["Tierras de la Peste del Este"] = { 3870, 2581 },
}

local RUTA                -- ruta activa (tabla registrada en GuiaAventurero_Rutas)
local frame, flecha
-- Elementos de la ventana (en una tabla para no pasar del limite de variables de Lua 5.1)
local ui = { modos = {}, subs = {}, nav = {}, destinos = {}, info = {}, ramas = {}, filasTal = {}, oficios = {}, filasOfi = {}, pagTal = {}, pagOfi = {} }
-- Paginas de alto variable: inicio = primer elemento mostrado, fin = ultimo, pila = inicios anteriores.
local inicioTal, finTal, pilaTal = 1, 1, {}
local inicioOfi, finOfi, pilaOfi = 1, 1, {}

local pestanasInfo = { "entrenar", "equipo", "profesion" }
local nombresInfo = { entrenar = GL.L"Hechizos", equipo = GL.L"Equipo", profesion = GL.L"Profesión" }

------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------
local function Mensaje(texto)
  DEFAULT_CHAT_FRAME:AddMessage(AZUL .. GL.L"Guía del Aventurero" .. ":" .. FIN .. " " .. texto)
end

-- 8.7: las misiones nuevas de Forever sin nombre en español en la base de datos llevan en la ruta un nombre nuestro
-- (R.nombresPropios = { [id] = { "nuestro", "inglés" } }). Si el juego sabe el nombre de la misión y no es el inglés,
-- es el oficial de tu cliente: se usa ese y se guarda para la próxima vez.
-- En un bloque y en GL: el archivo está al límite de 200 variables locales de Lua.
do
local trad, tradRuta = nil, nil
local function TituloCliente(q, en)
  local db = GuiaAventureroDB
  if db and db.titulos and db.titulos[q] then return db.titulos[q] end
  local t
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local ok, r = pcall(C_QuestLog.GetTitleForQuestID, q); if ok and type(r) == "string" then t = r end
  end
  if (not t or t == "") and C_QuestLog and C_QuestLog.GetQuestInfo then
    local ok, r = pcall(C_QuestLog.GetQuestInfo, q); if ok and type(r) == "string" then t = r end
  end
  if not t or t == "" then
    if C_QuestLog and C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, q) end
    return nil
  end
  if t == en then return nil end
  if db then db.titulos = db.titulos or {}; db.titulos[q] = t end
  return t
end
GL.NombreOficial = function(n)
  local R = RUTA or GL.RUTA
  if not (R and R.nombresPropios) then return n end
  if tradRuta ~= R then
    trad, tradRuta = {}, R
    for q, v in pairs(R.nombresPropios) do trad[v[1]] = trad[v[1]] or { q = q, en = v[2] } end
  end
  local e = trad[n]
  if not e then return n end
  return TituloCliente(e.q, e.en) or n
end
end

local function Colorear(texto)
  texto = string.gsub(texto or "", "%[(.-)%]", function(n) return AMARILLO .. GL.NombreOficial(n) .. FIN end)
  texto = string.gsub(texto, "<(.-)>", function(n) return ((GL.ColorObjeto and GL.ColorObjeto(n)) or VERDE) .. n .. FIN end)   -- 8.9.1: color de su calidad
  return texto
end

-- Forever puede devolver "valores secretos" en algunas situaciones: no se pueden usar en cuentas.
local function Seguro(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

local function Mostrar(region, si)
  if si then region:Show() else region:Hide() end
end

local function Rango(d, h)
  if d == h then return tostring(d) end
  return d .. "-" .. h
end

local function NumSecciones()
  return #RUTA.secciones
end

local function SeccionPorNivel(nivel)
  local n = NumSecciones()
  for i = 1, n do
    local s = RUTA.secciones[i]
    if nivel >= s.min and nivel < s.max then
      return i
    end
  end
  return n
end

-- Las consultas de otros módulos pueden llegar antes de iniciar o después de un fallo de carga.
function GL.EnteroGuardado(v)
  v = tonumber(v)
  if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
  return math.floor(v)
end
local function PasoActual()
  local db = GuiaAventureroDB
  if type(db) ~= "table" or not RUTA or type(RUTA.secciones) ~= "table" then return nil, nil end
  local s = RUTA.secciones[db.seccion]
  if type(s) ~= "table" or type(s.pasos) ~= "table" then return nil, nil end
  local p = s.pasos[db.paso]
  if type(p) ~= "table" then return s, nil end
  return s, p
end

-- 6.1: objetivos pospuestos o ignorados por el jugador (por personaje). La clave no depende del orden del paso.
local destinoExtra = nil   -- destino de "Cerca de ti" que sigue la flecha sin cambiar de paso (no se guarda)
local function ClaveDestino(d)
  return tostring(d.q or "") .. ":" .. tostring(d.a or "") .. ":" .. tostring(d.n or "")
end
local function Marcado(lista, d)
  local t = GuiaAventureroDB and GuiaAventureroDB[lista]
  return (d and type(t) == "table" and t[ClaveDestino(d)]) and true or false
end
local function Marcar(lista, d, v)
  local db = GuiaAventureroDB
  if type(db[lista]) ~= "table" then db[lista] = {} end
  db[lista][ClaveDestino(d)] = v or nil
end

local function DestinoActual()
  if destinoExtra then return destinoExtra, 1 end
  local _, p = PasoActual()
  if not p or not p.wp then return nil, 0 end
  local total = #p.wp
  if total == 0 then return nil, 0 end
  local db = GuiaAventureroDB
  db.destino = math.max(1, math.min(total, GL.EnteroGuardado(db.destino) or 1))
  return p.wp[db.destino], total
end

------------------------------------------------------------------------
-- Profesiones: Forever usa C_SkillInfo (por id de habilidad); los clientes antiguos, la API global.
------------------------------------------------------------------------
local function BuscarEnSkillInfo(prof, nombre)
  for i = 1, C_SkillInfo.GetNumSkillLines() do
    local info = C_SkillInfo.GetSkillLineInfo(i)
    if info and not info.isHeader then
      if (prof.skill and prof.skill > 0 and info.skillID == prof.skill)
        or (info.name and string.lower(info.name) == nombre) then
        return Seguro(info.rank), Seguro(info.maxRank or info.skillMaxRank or info.maxSkillRank)
      end
    end
  end
  return nil
end

-- Devuelve el nivel de la profesion y su tope actual (o nil si no la tienes).
local function NivelProfesion(prof)
  local nombre = string.lower(prof.nombre or "")
  if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
    local rango, tope = BuscarEnSkillInfo(prof, nombre)
    if rango then return rango, tope end
    -- Si la cabecera "Profesiones" está plegada en la ventana de habilidades, sus líneas no se listan.
    if C_SkillInfo.ExpandSkillHeader then
      local plegadas = false
      for i = C_SkillInfo.GetNumSkillLines(), 1, -1 do
        local info = C_SkillInfo.GetSkillLineInfo(i)
        if info and info.isHeader and info.isCollapsed then
          C_SkillInfo.ExpandSkillHeader(i)
          plegadas = true
        end
      end
      if plegadas then return BuscarEnSkillInfo(prof, nombre) end
    end
    return nil
  end
  if GetProfessions and GetProfessionInfo and not GetNumSkillLines then
    local lista = { GetProfessions() }
    for i = 1, 6 do
      if lista[i] then
        local nom, _, rango, tope, _, _, linea = GetProfessionInfo(lista[i])
        if (prof.skill and linea == prof.skill) or (nom and string.lower(nom) == nombre) then
          return rango, tope
        end
      end
    end
    return nil
  end
  if GetNumSkillLines then
    for i = 1, GetNumSkillLines() do
      local nom, cabecera, _, rango, _, _, tope = GetSkillLineInfo(i)
      if nom and not cabecera and string.lower(nom) == nombre then
        return rango, tope
      end
    end
  end
  return nil
end

------------------------------------------------------------------------
-- Misiones hechas: el addon las comprueba para avanzar solo
------------------------------------------------------------------------
local entregadas = {}   -- entregadas en esta sesion (el juego tarda un momento en marcarlas)
local bloqueo = false   -- 9.6: «s:p» del paso ya hecho al que volviste a mano: no se te mueve de ahí mientras sigas en él

local function MisionCompletada(q)
  if entregadas[q] then return true end
  local f = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
  if not f then return false end
  local ok, r = pcall(f, q)
  if ok and r then return true end
  -- 9.2: hecha la alternativa o una posterior de la cadena (al instalar con un personaje ya avanzado)
  return GL.MisionImplicita and GL.MisionImplicita(q, f) or false
end

local function MisionEnDiario(q)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
    local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, q)
    return (ok and i ~= nil and i > 0) and true or false
  end
  return false
end

local function ObjetivosListos(q)
  if C_QuestLog and C_QuestLog.IsComplete then
    local ok, r = pcall(C_QuestLog.IsComplete, q)
    return (ok and r) and true or false
  end
  return false
end

-- true o false si el destino es de una mision; nil si no se puede comprobar (PNJ o punto del mapa).
-- A = recoger (la tienes en el diario), C = objetivos (listos para entregar), T = entregar.
local function DestinoHecho(d)
  if d and Marcado("ignorados", d) then return true end   -- ignorado: cuenta como hecho
  if not d or not d.q then return nil end
  if MisionCompletada(d.q) then return true end
  -- La alternativa activa permite seguir su rama. Si se aceptaron las dos, queda pendiente la entrega.
  if d.alternativa and (MisionCompletada(d.alternativa) or
     (not MisionEnDiario(d.q) and MisionEnDiario(d.alternativa))) then return true end
  if d.a == "A" then return MisionEnDiario(d.q) end
  if d.a == "C" then return MisionEnDiario(d.q) and ObjetivosListos(d.q) end
  return false
end

-- Objetivos de una mision del diario: "3/4" para la lista de destinos y el detalle para el tooltip.
local function ProgresoMision(q)
  if not q or not (C_QuestLog and C_QuestLog.GetQuestObjectives) or not MisionEnDiario(q) then return nil end
  local ok, objetivos = pcall(C_QuestLog.GetQuestObjectives, q)
  if not ok or type(objetivos) ~= "table" or #objetivos == 0 then return nil end
  local partes, lineas = {}, {}
  for i = 1, #objetivos do
    local o = objetivos[i]
    local hechos, total = Seguro(o.numFulfilled), Seguro(o.numRequired)
    local texto, listo = Seguro(o.text), Seguro(o.finished)
    if type(hechos) == "number" and type(total) == "number" and total > 0 then
      table.insert(partes, ((hechos >= total) and VERDE or AMARILLO) .. hechos .. "/" .. total .. FIN)
    end
    if type(texto) == "string" and texto ~= "" then
      table.insert(lineas, (listo and VERDE or BLANCO) .. texto .. FIN)
    end
  end
  return table.concat(partes, " "), table.concat(lineas, "\n")
end

-- Texto corto para la lista de destinos: "3/4" en los objetivos y "lista" cuando ya se puede entregar.
local function ProgresoDestino(d, hecho)
  if not d or not d.q or hecho then return nil end
  if d.a == "C" then return ProgresoMision(d.q) end
  if d.a == "T" and MisionEnDiario(d.q) and ObjetivosListos(d.q) then
    local _, detalle = ProgresoMision(d.q)
    return VERDE .. "lista" .. FIN, detalle
  end
  return nil
end

------------------------------------------------------------------------
-- Pasos sin misiones: el addon tambien los da por hechos cuando puede comprobarlos
-- (profesiones aprendidas, zona a la que hay que llegar, ruta de vuelo aprendida o nivel).
------------------------------------------------------------------------
local function EnMapa(objetivo)
  if not (objetivo and C_Map and C_Map.GetBestMapForUnit) then return false end
  local m = Seguro(C_Map.GetBestMapForUnit("player"))
  for _ = 1, 6 do
    if not m or m == 0 then return false end
    if m == objetivo then return true end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    m = info and Seguro(info.parentMapID)
  end
  return false
end

local function VueloConocido(nombre)
  local vuelos = GuiaAventureroDB and GuiaAventureroDB.vuelos
  if type(vuelos) ~= "table" or type(nombre) ~= "string" or nombre == "" then return false end
  -- Las claves guardadas pueden venir de un cliente de otro idioma. La API puede añadir la zona tras una coma.
  local traducir = GL.EnIngles
  local ingles = traducir and string.lower(traducir(nombre))
  nombre = string.lower(nombre)
  for nodo, conocido in pairs(vuelos) do
    if conocido and type(nodo) == "string" then
      local guardado = string.lower(nodo)
      if string.find(guardado, nombre, 1, true) then return true end
      if traducir then
        if ingles ~= nombre and string.find(guardado, ingles, 1, true) then return true end
        local lugar = string.match(nodo, "^[^,]+") or nodo
        if string.find(string.lower(traducir(lugar)), ingles, 1, true) then return true end
      end
    end
  end
  return false
end

-- Las rutas de vuelo que conoces solo se pueden leer con el mapa de vuelo abierto: se guardan por personaje.
-- Solo estados positivos documentados; no inferir descubrimiento de estados desconocidos.
function GL.EstadoVueloConocido(estado)
  if issecretvalue and issecretvalue(estado) then return false end
  if type(estado) ~= "number" then return false end
  local e = Enum and Enum.FlightPathState
  local actual = e and e.Current or 0
  local alcanzable = e and e.Reachable or 1
  return estado == actual or estado == alcanzable
end

local function GuardarVuelos()
  local db = GuiaAventureroDB
  if type(db) ~= "table" then return end
  if type(db.vuelos) ~= "table" then db.vuelos = {} end
  if NumTaxiNodes and TaxiNodeName and TaxiNodeGetType then
    for i = 1, (NumTaxiNodes() or 0) do
      local tipo = TaxiNodeGetType(i)
      local nombre = Seguro(TaxiNodeName(i))
      if nombre and (tipo == "CURRENT" or tipo == "REACHABLE") then db.vuelos[nombre] = true end
    end
  end
  if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and GetTaxiMapID then
    local ok, nodos = pcall(C_TaxiMap.GetAllTaxiNodes, GetTaxiMapID())
    if ok and type(nodos) == "table" then
      for i = 1, #nodos do
        local n = nodos[i]
        local nombre = n and Seguro(n.name)
        if type(nombre) == "string" and nombre ~= "" and GL.EstadoVueloConocido(n.state) then db.vuelos[nombre] = true end
      end
    end
  end
end

-- true si conoces el hechizo (ese rango en concreto). Forever usa C_SpellBook; los clientes antiguos, la API global.
-- Los venenos del pícaro son recetas de la habilidad Venenos y no van al libro de hechizos: si el libro dice que no,
-- se pregunta también si está en el libro (como hace What's Training) y si el juego lo cuenta como hechizo tuyo.
local function ConocidoEnLibro(id)
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local banco = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local ok, r = pcall(C_SpellBook.IsSpellKnown, id, banco)
    if ok and r then return true end
    if C_SpellBook.IsSpellInSpellBook then
      local ok2, r2 = pcall(C_SpellBook.IsSpellInSpellBook, id, banco, false)
      if ok2 and r2 then return true end
    end
    if IsPlayerSpell then
      local ok3, r3 = pcall(IsPlayerSpell, id)
      if ok3 and r3 then return true end
    end
    if ok then return false end
  end
  local f = IsPlayerSpell or IsSpellKnown
  if f then
    local ok, r = pcall(f, id)
    if ok then return r and true or false end
  end
  return false
end
-- Cuenta también los hechizos que el juego cambia por otro id (R.equivalentes de la ruta): el Sello de rectitud
-- del principio del paladín pasa a ser otro hechizo al aprender Sentencia, y sin esto el rango 2 no se ofrecería.
local function HechizoConocido(id)
  if not id then return false end
  if ConocidoEnLibro(id) then return true end
  local eq = RUTA and RUTA.equivalentes and RUTA.equivalentes[id]
  if eq then
    for i = 1, #eq do
      if ConocidoEnLibro(eq[i]) then return true end
    end
  end
  -- lo del instructor de mascotas del cazador no va al libro de hechizos: la guía apunta lo que aprendes
  if GL.ConocidoFuera and GL.ConocidoFuera(id) then return true end
  return false
end

-- true si el paso trae comprobaciones y se cumplen todas; si no, nil (el paso sigue siendo "manual").
local function ComprobacionesHechas(p)
  local c = p and p.comprobar
  if not c then return nil end
  if c.nivel and (UnitLevel("player") or 1) < c.nivel then return nil end
  if c.llegar and not EnMapa(c.llegar) then return nil end
  if c.vuelo and not VueloConocido(c.vuelo) then return nil end
  if c.hechizos then
    for i = 1, #c.hechizos do
      if not HechizoConocido(c.hechizos[i]) then return nil end
    end
  end
  if c.oficios then
    for i = 1, #c.oficios do
      if not NivelProfesion({ skill = c.oficios[i], nombre = "" }) then return nil end
    end
  end
  -- 9.2: llevar alguno de estos objetos (o tener ya hecha la misión que los pide)
  if c.objetos then
    local tiene = c.mision and MisionCompletada(c.mision) or false
    for i = 1, #c.objetos do
      if not tiene and GetItemCount and (GetItemCount(c.objetos[i]) or 0) > 0 then tiene = true end
    end
    if not tiene then return nil end
  end
  -- 9.2: un nivel mínimo de una habilidad (por ejemplo Forzar cerraduras 80)
  if c.oficioMin then
    for i = 1, #c.oficioMin do
      local o = c.oficioMin[i]
      local n = NivelProfesion(o)
      if type(n) ~= "number" or n < (o.min or 1) then return nil end
    end
  end
  return true
end

-- "hecho" (todas sus misiones hechas), "pendiente" o "manual" (sin misiones que comprobar)
local function EstadoPaso(p)
  local hay = false
  if p and p.wp then
    for i = 1, #p.wp do
      local h = DestinoHecho(p.wp[i])
      if h == false then return "pendiente" end
      if h then hay = true end
    end
  end
  if not hay and ComprobacionesHechas(p) then return "hecho" end
  return hay and "hecho" or "manual"
end

local function PasoDespues(sec, paso)
  if paso < #RUTA.secciones[sec].pasos then return sec, paso + 1 end
  if sec < NumSecciones() then return sec + 1, 1 end
  return nil
end

-- Se puede pasar de largo si el paso esta hecho, o si no tiene misiones y el siguiente paso con misiones ya esta hecho.
local function PuedeSaltar(sec, paso)
  local estado = EstadoPaso(RUTA.secciones[sec].pasos[paso])
  if estado ~= "manual" then return estado == "hecho" end
  local s, p = sec, paso
  for _ = 1, 10 do
    s, p = PasoDespues(s, p)
    if not s then return false end
    local e = EstadoPaso(RUTA.secciones[s].pasos[p])
    if e ~= "manual" then return e == "hecho" end
  end
  return false
end

------------------------------------------------------------------------
-- Rutas y talentos
------------------------------------------------------------------------
local function ElegirRuta()
  local rutas = GuiaAventurero_Rutas or {}
  if #rutas == 0 then return nil end
  local db = GuiaAventureroDB
  if db.rutaElegida then
    for i = 1, #rutas do
      if rutas[i].id == db.rutaElegida then return rutas[i] end
    end
  end
  local _, clase = UnitClass("player")
  local raza = GL.Raza()
  local faccion = UnitFactionGroup and UnitFactionGroup("player")
  -- 9.2: la Horda y la Alianza nunca comparten ruta. La facción de la ruta es la suya (Skyborne) o la de sus razas.
  local HORDA = { Orc = true, Troll = true, Tauren = true, Scourge = true }
  local function DeFaccion(r)
    if not faccion then return true end
    local f = r.faccion
    if not f and r.razas and r.razas[1] and r.razas[1] ~= "Skyborne" then f = HORDA[r.razas[1]] and "Horde" or "Alliance" end
    return not f or f == faccion
  end
  local deLaClase, deLaFaccion
  for i = 1, #rutas do
    local r = rutas[i]
    if DeFaccion(r) then
      deLaFaccion = deLaFaccion or r
      if r.clase == clase then
        if not r.razas then return r end
        for j = 1, #r.razas do
          if r.razas[j] == raza then return r end
        end
        deLaClase = deLaClase or r
      end
    end
  end
  return deLaClase or deLaFaccion or rutas[1]
end

-- Cada archivo de Rutas registra solo la cabecera (id, nombre, clase, razas) y deja el resto en R.cargar.
-- Al iniciar se rellena solo la ruta elegida; las demas sueltan sus datos y el juego libera esa memoria.
-- Una ruta sin R.cargar (escrita a la antigua, con todo ya dentro) tambien vale.
local function CargarRuta(R)
  local rutas = GuiaAventurero_Rutas or {}
  local function FalloCarga(err)
    local texto = GL.L"error al cargar la ruta " .. tostring(R.id) .. ": " .. tostring(err)
    table.insert(GL.erroresCarga, texto)
    Mensaje(texto)
    return false
  end
  if R.cargar then
    local ok, err = pcall(R.cargar, R)
    if not ok then return FalloCarga(err) end
  end
  -- No continuar el arranque con una ruta incompleta ni descartar los cargadores antes de validarla.
  if type(R.secciones) ~= "table" or #R.secciones == 0 or
     type(R.talentos) ~= "table" or type(R.profesiones) ~= "table" then
    return FalloCarga(GL.L"datos de ruta incompletos")
  end
  for _, sec in ipairs(R.secciones) do
    if type(sec) ~= "table" or type(sec.pasos) ~= "table" or #sec.pasos == 0 then
      return FalloCarga(GL.L"datos de ruta incompletos")
    end
  end
  for i = 1, #rutas do rutas[i].cargar = nil end
  collectgarbage("collect")
  return true
end

-- Puntos solo para una raza (raza = token de UnitRace): se quitan los de las otras razas al cargar la ruta.
-- Lo mismo con los hechizos de una sola raza del instructor y de la lista (los de raza del sacerdote).
local function AdaptarARaza(R)
  local raza = GL.Raza()
  if not raza or R.adaptada == raza then return end
  R.adaptada = raza
  local function DeMiRaza(lista)
    local quedan = {}
    for _, e in ipairs(lista) do
      if not e.raza or e.raza == raza then table.insert(quedan, e) end
    end
    return quedan
  end
  for _, s in ipairs(R.secciones or {}) do
    for _, p in ipairs(s.pasos or {}) do
      if p.wp then p.wp = DeMiRaza(p.wp) end
    end
  end
  if R.entrenamiento then R.entrenamiento = DeMiRaza(R.entrenamiento) end
  if R.hechizosExtra then R.hechizosExtra = DeMiRaza(R.hechizosExtra) end
end

local function ListarRutas()
  local rutas = GuiaAventurero_Rutas or {}
  for i = 1, #rutas do
    local marca = (RUTA and rutas[i].id == RUTA.id) and (VERDE .. GL.L" (activa)" .. FIN) or ""
    Mensaje(rutas[i].id .. ": " .. GL.L(tostring(rutas[i].nombre or "")) .. marca)   -- 9.7.4: en inglés salía el nombre en español
  end
  Mensaje(GL.L"Para cambiar: /ga ruta <id> y después /reload")
end

local function Rama(nombre)
  local ramas = RUTA.ramas or {}
  for i = 1, #ramas do
    if ramas[i].nombre == nombre then return ramas[i] end
  end
  return nil
end

-- Puntos de una rama segun el plan hasta un nivel (un punto por nivel desde el 10).
local function PuntosRama(nombre, nivel)
  local total = 0
  for i = 1, #RUTA.talentos do
    local t = RUTA.talentos[i]
    if t.rama == nombre and nivel >= t.d then
      total = total + math.min(nivel, t.h) - t.d + 1
    end
  end
  return total
end

------------------------------------------------------------------------
-- Piezas de la interfaz (estilo propio: fondos planos, bordes finos e iconos del juego)
------------------------------------------------------------------------
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil

local function Color(t)
  return t[1], t[2], t[3], t[4] or 1
end

-- Fondo plano con borde de 1 pixel (o solo fondo si el cliente no tiene backdrops).
local function Caja(f, fondo, borde)
  if f.SetBackdrop then
    if not f.cajaHecha then
      f:SetBackdrop({ bgFile = BLANCO8, edgeFile = BLANCO8, edgeSize = 1 })
      f.cajaHecha = true
    end
    f:SetBackdropColor(Color(fondo))
    f:SetBackdropBorderColor(Color(borde or fondo))
  else
    if not f.fondoCaja then
      f.fondoCaja = f:CreateTexture(nil, "BACKGROUND")
      f.fondoCaja:SetAllPoints()
    end
    f.fondoCaja:SetColorTexture(Color(fondo))
  end
end

-- Borde de 1 pixel hecho con cuatro lineas (sirve sobre barras, que no admiten backdrop).
local function Marco4(f, c)
  local function Linea()
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(Color(c))
    return t
  end
  local arriba, abajo, izq, der = Linea(), Linea(), Linea(), Linea()
  arriba:SetHeight(1); arriba:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); arriba:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  abajo:SetHeight(1); abajo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); abajo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  izq:SetWidth(1); izq:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); izq:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  der:SetWidth(1); der:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); der:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  return { arriba, abajo, izq, der }
end

-- Sombra suave alrededor de una ventana (un halo oscuro y translucido detras).
local function Sombra(f)
  if not PLANTILLA then return end
  local ok, sombra = pcall(CreateFrame, "Frame", nil, f, PLANTILLA)
  if not ok or not sombra or not sombra.SetBackdrop then return end
  sombra:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
  sombra:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
  sombra:SetFrameLevel(math.max((f:GetFrameLevel() or 1) - 1, 0))
  sombra:SetBackdrop({ edgeFile = BLANCO8, edgeSize = 4 })
  sombra:SetBackdropBorderColor(0, 0, 0, 0.30)
  f.sombra = sombra
end

-- Linea fina de color en el borde de arriba de una ventana.
local function Acento(f, alto)
  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetHeight(alto or 2)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  PorTema(function() t:SetColorTexture(Color(COLOR.acento)) end)
  return t
end

-- Pone un icono; si el archivo no existe en el cliente, pone el interrogante.
local function PonerIcono(tex, ruta, recortar)
  local ok = tex:SetTexture(ruta or INTERROGANTE)
  if ok == false then tex:SetTexture(INTERROGANTE) end
  if recortar == false then
    tex:SetTexCoord(0, 1, 0, 1)
  else
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- quita el borde de los iconos
  end
end

local function Texto(padre, fuente, horizontal)
  local t = padre:CreateFontString(nil, "OVERLAY", fuente or "GameFontHighlightSmall")
  t:SetJustifyH(horizontal or "LEFT")
  t:SetJustifyV("TOP")
  return t
end

local function UnaLinea(fs)
  if fs.SetWordWrap then fs:SetWordWrap(false) end
end

-- Tooltip: fijo (titulo y texto) o leido de los campos ayudaTitulo y ayudaTexto del marco.
local function Ayuda(f, titulo, texto)
  f.ayudaTitulo, f.ayudaTexto = titulo, texto
  f:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.ayudaTitulo then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.ayudaTitulo, 1, 0.82, 0)
    if self.ayudaTexto then GameTooltip:AddLine(self.ayudaTexto, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
end

-- estilo: nil (boton normal), "pestana" (plana, con linea de color abajo si esta activa),
-- "accion" (boton principal, con borde dorado) o "cerrar" (la X de la ventana).
local function CrearBoton(padre, texto, funcion, icono, alto, estilo)
  -- 9.4.2: con el idioma elegido a mano, los textos de las tablas de cada archivo se tradujeron antes de saber
  -- el idioma; aquí se traducen otra vez (lo que ya está traducido no cambia)
  if type(texto) == "string" and texto ~= "" and GL.L then texto = GL.L(texto) end
  alto = alto or 22
  local b = CreateFrame("Button", nil, padre, PLANTILLA)
  b:SetHeight(alto)
  b:SetWidth(80)
  local fondo, borde, colTexto = COLOR.boton, COLOR.botonBorde, { 0.82, 0.83, 0.88 }   -- 9.0: texto claro en vez de dorado
  if estilo == "pestana" then
    fondo, borde, colTexto = COLOR.pestana, COLOR.pestana, { 0.68, 0.68, 0.74 }
  elseif estilo == "accion" then
    fondo, borde, colTexto = COLOR.accion, COLOR.accionBorde, { 1, 1, 1 }
  elseif estilo == "cerrar" then
    fondo, borde, colTexto = COLOR.pestana, COLOR.pestana, { 0.80, 0.80, 0.85 }
  end
  b.estilo, b.colFondo, b.colBorde, b.colTexto = estilo, fondo, borde, colTexto
  table.insert(botonesTema, b)
  Caja(b, fondo, borde)
  local brillo = b:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  if estilo == "cerrar" then
    brillo:SetColorTexture(0.90, 0.25, 0.25, 0.35)
  else
    brillo:SetColorTexture(1, 1, 1, 0.08)
  end
  b.brillo = brillo
  -- al pulsar, se oscurece
  b:SetPushedTexture(BLANCO8)
  local pulsado = b:GetPushedTexture()
  if pulsado then
    pulsado:SetAllPoints()
    pulsado:SetVertexColor(0, 0, 0, 0.30)
  end
  if estilo == "pestana" then
    b.linea = b:CreateTexture(nil, "OVERLAY")
    b.linea:SetHeight(2)
    b.linea:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.linea:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    PorTema(function() b.linea:SetColorTexture(Color(COLOR.acento)) end)
    b.linea:Hide()   -- 9.0: ya no se usa (selector segmentado)
  end
  b.texto = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.texto:SetTextColor(colTexto[1], colTexto[2], colTexto[3])
  if icono then
    b.icono = b:CreateTexture(nil, "ARTWORK")
    b.icono:SetWidth(alto - 8)
    b.icono:SetHeight(alto - 8)
    b.icono:SetPoint("LEFT", b, "LEFT", 5, 0)
    PonerIcono(b.icono, icono)
    b.texto:SetPoint("LEFT", b.icono, "RIGHT", 2, 0)
  else
    b.texto:SetPoint("LEFT", b, "LEFT", 4, 0)
  end
  b.texto:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  UnaLinea(b.texto)
  b.texto:SetText(texto)
  b.etiqueta = texto
  b:SetScript("OnClick", function(self, ...) funcion(self, ...) end)   -- 7.9.7: el botón se pasa a la función (antes llegaba vacío y Llevarme, No y Ver no hacían nada)
  b.SetActivo = function(self, activo)
    self.esActivo = activo and true or false
    if self.estilo == "pestana" then
      if activo then
        Caja(self, COLOR.segmento, COLOR.segmento)   -- 9.0: selector segmentado (sin línea abajo)
        self.texto:SetTextColor(1, 1, 1)
      else
        Caja(self, self.colFondo, self.colBorde)
        self.texto:SetTextColor(self.colTexto[1], self.colTexto[2], self.colTexto[3])
      end
    elseif activo then
      Caja(self, COLOR.activo, COLOR.activoBorde)
      self.texto:SetTextColor(1, 1, 1)
    else
      Caja(self, self.colFondo, self.colBorde)
      self.texto:SetTextColor(self.colTexto[1], self.colTexto[2], self.colTexto[3])
    end
  end
  return b
end

-- Con otro tema, todos los botones se pintan de nuevo con su estado de ahora.
table.insert(alCambiarTema, function()
  for i = 1, #botonesTema do
    local b = botonesTema[i]
    if b.esActivo or b.estilo == "accion" then b:SetActivo(b.esActivo) end   -- solo estos usan el color del tema
  end
end)

local function CrearBarra(padre, r, g, b)
  local barra = CreateFrame("StatusBar", nil, padre)
  barra:SetHeight(16)
  barra:SetStatusBarTexture(BLANCO8)
  barra:SetStatusBarColor(r, g, b, 0.95)
  barra:SetMinMaxValues(0, 1)
  barra:SetValue(0)
  local fondo = barra:CreateTexture(nil, "BACKGROUND")
  fondo:SetAllPoints()
  fondo:SetColorTexture(0.02, 0.02, 0.04, 0.90)
  -- brillo suave en la mitad de arriba y borde fino
  local brillo = barra:CreateTexture(nil, "OVERLAY")
  brillo:SetPoint("TOPLEFT", barra, "TOPLEFT", 1, -1)
  brillo:SetPoint("TOPRIGHT", barra, "TOPRIGHT", -1, -1)
  brillo:SetHeight(6)
  brillo:SetColorTexture(1, 1, 1, 0.08)
  Marco4(barra, COLOR.botonBorde)
  barra.texto = barra:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  barra.texto:SetPoint("CENTER", barra, "CENTER", 0, 0)
  barra.texto:SetShadowOffset(1, -1)
  barra.texto:SetShadowColor(0, 0, 0, 1)
  return barra
end

-- Marco con borde fino y un icono dentro.
local function CrearMarcoIcono(padre, lado)
  local m = CreateFrame("Frame", nil, padre, PLANTILLA)
  m:SetWidth(lado)
  m:SetHeight(lado)
  Caja(m, COLOR.icono, COLOR.iconoBorde)
  m.icono = m:CreateTexture(nil, "ARTWORK")
  m.icono:SetPoint("TOPLEFT", m, "TOPLEFT", 1, -1)
  m.icono:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -1, 1)
  return m
end

-- Coloca botones en fila, todos del mismo ancho.
local ANCHO_PONER_TAL = 104   -- botón "Poner talentos" a la derecha de las ramas

local function Encadenar(botones, padre, x, y)
  for i = 1, #botones do
    if i == 1 then
      botones[i]:SetPoint("TOPLEFT", padre, "TOPLEFT", x, y)
    else
      botones[i]:SetPoint("LEFT", botones[i - 1], "RIGHT", 6, 0)
    end
  end
end

local function Repartir(botones, ancho)
  local n = #botones
  if n == 0 then return end
  local w = math.floor((ancho - (n - 1) * 6) / n)
  for i = 1, n do botones[i]:SetWidth(w) end
end

local function AnchoContenido()
  return ((frame and frame:GetWidth()) or ANCHO) - GL.IZQ - MARGEN
end

local function AltoContenido()
  local sub = (GuiaAventureroDB and GRUPOS[GuiaAventureroDB.modo]) and ALTO_SUB or 0
  return ((frame and frame:GetHeight()) or ALTO) - ARRIBA - ABAJO - sub
end

-- Tamano de letra del texto del paso: 13 por el deslizador de Opciones (del 80 % al 150 %).
local function TamTextoPaso()
  local f = (GuiaAventureroDB and GuiaAventureroDB.tamTexto) or 1
  if GuiaAventureroDB and GuiaAventureroDB.lectura == true then f = f * 1.3 end   -- 8.9.5: modo lectura
  return math.floor(13 * f + 0.5)
end

-- Alto real de un texto ya escrito; si el juego aun no lo sabe, se estima.
local function Alto(fs, texto, linea, ancho)
  local h = fs.GetStringHeight and fs:GetStringHeight()
  if not h or h <= 0 then
    local limpio = string.gsub(texto or "", "|c%x%x%x%x%x%x%x%x", "")
    limpio = string.gsub(limpio, "|r", "")
    local porLinea = math.max(10, math.floor((ancho or 360) / ((linea or 12) * 0.5)))
    local lineas = 0
    for parte in string.gmatch(limpio .. "\n", "(.-)\n") do
      lineas = lineas + math.max(1, math.ceil(string.len(parte) / porLinea))
    end
    h = lineas * (linea or 12)
  end
  return h
end

-- Rellena las filas desde 'inicio' mientras quepan en 'disponible' (pixeles). Devuelve el ultimo mostrado.
local function LlenarLista(filas, disponible, inicio, total, rellenar)
  local usado, ultimo, cortar = 0, inicio - 1, false
  for k = 1, #filas do
    local fila = filas[k]
    local i = inicio + k - 1
    if not cortar and i <= total then
      local h = rellenar(fila, i)
      if k == 1 or usado + h + HUECO <= disponible then
        usado = usado + h + HUECO
        ultimo = i
        fila:Show()
      else
        cortar = true
        fila:Hide()
      end
    else
      fila:Hide()
    end
  end
  return ultimo
end

------------------------------------------------------------------------
-- Refresco de los paneles
------------------------------------------------------------------------
local function PosicionEnRuta()
  local db = GuiaAventureroDB
  local antes, total = 0, 0
  for i = 1, NumSecciones() do
    local n = #RUTA.secciones[i].pasos
    if i < db.seccion then antes = antes + n end
    total = total + n
  end
  return antes + db.paso, total
end

-- Pasos hechos de verdad (6.1): con sus misiones completadas o ignoradas; los pasos sin misiones cuentan si ya
-- quedaron atrás. Recorre toda la ruta, así que se guarda unos segundos.
local cachePasos = { t = -100 }
local function PasosHechos()
  local ahora = (GetTime and GetTime()) or 0
  if GetTime and cachePasos.ruta == RUTA and ahora >= cachePasos.t and ahora - cachePasos.t < 3
      and cachePasos.seccion == GuiaAventureroDB.seccion and cachePasos.paso == GuiaAventureroDB.paso then
    return cachePasos.hechos, cachePasos.total
  end
  local actual = PosicionEnRuta()
  local hechos, n = 0, 0
  for i = 1, NumSecciones() do
    local pasos = RUTA.secciones[i].pasos
    for j = 1, #pasos do
      n = n + 1
      local e = EstadoPaso(pasos[j])
      if e == "hecho" or (e == "manual" and n < actual) then hechos = hechos + 1 end
    end
  end
  cachePasos.t, cachePasos.ruta = ahora, RUTA
  cachePasos.seccion, cachePasos.paso = GuiaAventureroDB.seccion, GuiaAventureroDB.paso
  cachePasos.hechos, cachePasos.total = hechos, n
  return hechos, n
end

-- 9.0: el subtítulo ya no se ve; su texto solo hace falta en la ayuda del icono, así que se calcula al pasar el ratón
function GL.TextoCabecera()
  local nivel = UnitLevel("player") or 1
  local extra = ""
  local xp, xpMax = Seguro(UnitXP and UnitXP("player")), Seguro(UnitXPMax and UnitXPMax("player"))
  if type(xp) == "number" and type(xpMax) == "number" and xpMax > 0 then
    extra = extra .. "  ·  " .. AZUL .. math.floor(xp * 100 / xpMax) .. GL.L" % de XP" .. FIN
  end
  local contar = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or GetNumQuestLogEntries
  if contar then
    local ok, _, misiones = pcall(contar)
    misiones = ok and Seguro(misiones)
    if type(misiones) == "number" then
      extra = extra .. GRIS .. "  ·  " .. misiones .. (misiones == 1 and GL.L" misión" or GL.L" misiones") .. FIN
    end
  end
  local colorNombre = AMARILLO   -- 8.8: con el tema Clase, el nombre sale en el color de la clase
  if GL.temaActivo == "clase" then
    local okC, r, g, b = pcall(GL.ColorDeClase)
    if okC and r then colorNombre = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) end
  end
  return colorNombre .. RUTA.nombre .. FIN .. GRIS .. GL.L"  ·  nivel " .. nivel .. FIN .. extra
end

local function RefrescarCabecera()
  if ui.botonFlecha and flecha then ui.botonFlecha:SetActivo(flecha:IsShown()) end
end

------------------------------------------------------------------------
-- 6.2: recuperación de ruta. Si estás en otra zona que la de tu paso, busca el paso pendiente más cercano
-- de la zona donde estás para ofrecer retomar ahí.
------------------------------------------------------------------------
local function MapasDeMiZona()
  local mapas = {}
  if not (C_Map and C_Map.GetBestMapForUnit) then return mapas end
  local m = Seguro(C_Map.GetBestMapForUnit("player"))
  for _ = 1, 6 do
    if not m or m <= 0 then break end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    if type(info) ~= "table" or (info.mapType and info.mapType <= 2) then break end   -- hasta el continente
    mapas[m] = true
    m = info.parentMapID
  end
  return mapas
end

local cacheRetomar = { t = -100 }
local function BuscarRetomar(zona, mapas)
  local ahora = (GetTime and GetTime()) or 0
  if GetTime and cacheRetomar.ruta == RUTA and cacheRetomar.zona == zona
      and cacheRetomar.seccion == GuiaAventureroDB.seccion and cacheRetomar.paso == GuiaAventureroDB.paso
      and ahora >= cacheRetomar.t and ahora - cacheRetomar.t < 5 then
    -- La zona puede tener varios mapas con el mismo nombre. Comparar también el conjunto de mapas.
    local iguales = true
    for m in pairs(mapas) do if not cacheRetomar.mapas[m] then iguales = false; break end end
    if iguales then for m in pairs(cacheRetomar.mapas) do if not mapas[m] then iguales = false; break end end end
    if iguales then return cacheRetomar.r end
  end
  local mejor, mejorDist, mejorOrden
  local actual = PosicionEnRuta()
  local n = 0
  for s = 1, NumSecciones() do
    local pasos = RUTA.secciones[s].pasos
    for p = 1, #pasos do
      n = n + 1
      for i, d in ipairs(pasos[p].wp or {}) do
        if (mapas[d.m] or (zona ~= "" and d.z == zona)) and DestinoHecho(d) == false then
          local ok, este, _, dist = false, nil, nil, nil
          if GL.Vector then ok, este, _, dist = pcall(GL.Vector, d) end
          dist = (ok and este and dist) or 1e9
          local orden = math.abs(n - actual)
          if not mejor or dist < mejorDist or (dist == mejorDist and orden < mejorOrden) then
            mejor, mejorDist, mejorOrden = { s = s, p = p, i = i, d = d, dist = dist }, dist, orden
          end
        end
      end
    end
  end
  cacheRetomar.t, cacheRetomar.ruta, cacheRetomar.zona = ahora, RUTA, zona
  cacheRetomar.seccion, cacheRetomar.paso = GuiaAventureroDB.seccion, GuiaAventureroDB.paso
  cacheRetomar.mapas = cacheRetomar.mapas or {}
  for m in pairs(cacheRetomar.mapas) do cacheRetomar.mapas[m] = nil end
  for m in pairs(mapas) do cacheRetomar.mapas[m] = true end
  cacheRetomar.r = mejor
  return mejor
end

local Preparacion   -- 6.3: se define más abajo (necesita ContarObjeto)

-- 6.3: ¿el paso siguiente es en otra zona? Devuelve la zona actual del paso y la del siguiente.
local function CambioDeZona(p)
  local d = p.wp and p.wp[1]
  local s, q = PasoDespues(GuiaAventureroDB.seccion, GuiaAventureroDB.paso)
  local sig = s and RUTA.secciones[s].pasos[q]
  local d2 = sig and sig.wp and sig.wp[1]
  if d and d2 and d.z and d2.z and d.z ~= d2.z then return d.z, d2.z end
  return nil
end

-- Avisos encima de la caja del paso: desvío de la flecha, paso en otra zona y preparación antes de irte.
-- Devuelve el alto que ocupan.
local function RefrescarAvisos(p, ancho)
  local db = GuiaAventureroDB
  local y = 0
  if destinoExtra and DestinoHecho(destinoExtra) == true then destinoExtra = nil end
  if destinoExtra then
    ui.desvio.texto:SetText(AZUL .. GL.L"Desvío:" .. FIN .. GL.L" la flecha va a " .. tostring(destinoExtra.n))
    ui.desvio:Show()
    y = y + 28
  else
    ui.desvio:Hide()
  end
  ui.aviso:Hide()
  local d = p.wp and p.wp[db.destino]
  local zona = (GetZoneText and GetZoneText()) or ""
  local enTaxi = UnitOnTaxi and UnitOnTaxi("player")
  if d and d.z and zona ~= "" and not enTaxi and ui.zonaDescartada ~= zona then
    local mapas = MapasDeMiZona()
    if not mapas[d.m] and d.z ~= zona then
      local r = BuscarRetomar(zona, mapas)
      if r then
        local donde = RUTA.secciones[r.s].titulo
        local lejos = (r.dist < 1e8) and (GL.L", a " .. math.floor(r.dist * 0.9144 + 0.5) .. " m") or ""   -- 9.7.4: en inglés salía «a 88 m»
        ui.aviso.retomar = r
        ui.aviso.texto:SetWidth(ancho - 18)
        ui.aviso.texto:SetText(AMARILLO .. GL.L"Te has desviado:" .. FIN .. GL.L" estás en " .. BLANCO .. zona .. FIN ..
          GL.L" y tu paso es en " .. d.z .. ".\n" .. GRIS .. GL.L"El paso pendiente más cercano: sección " .. r.s .. GL.L", paso " ..
          r.p .. " (" .. donde .. ")" .. lejos .. "." .. FIN)
        ui.aviso:ClearAllPoints()
        ui.aviso:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 0, -(Y_CAJA - 4 + y))
        ui.aviso:SetPoint("TOPRIGHT", ui.panelGuia, "TOPRIGHT", 0, -(Y_CAJA - 4 + y))
        ui.aviso:Show()
        y = y + 76
      else
        local directo = GL.TextoTransporteDirecto and GL.TextoTransporteDirecto(d.m)
        local otro = GL.OtroContinente and GL.OtroContinente(d.m)
        if directo or otro then
        -- 9.6: en otro continente y sin pasos de la ruta aquí: al menos decir dónde está tu paso
        ui.aviso.retomar = nil
        ui.aviso.texto:SetWidth(ancho - 18)
        ui.aviso.texto:SetText(AMARILLO .. (otro and GL.L"Estás en otro continente:" or GL.L"Transporte entre zonas:") .. FIN .. " " .. BLANCO .. zona .. FIN ..
          GL.L". Tu paso es en " .. tostring(d.z) .. ".\n" .. GRIS .. (directo or (GL.TextoTransporte and GL.TextoTransporte(d.m)) or GL.L"Vuelve en barco, zepelín o con la piedra de hogar; la flecha te guía al llegar.") .. FIN)
        ui.aviso:ClearAllPoints()
        ui.aviso:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 0, -(Y_CAJA - 4 + y))
        ui.aviso:SetPoint("TOPRIGHT", ui.panelGuia, "TOPRIGHT", 0, -(Y_CAJA - 4 + y))
        ui.aviso:Show()
        y = y + 76
        end
      end
    end
  end
  if ui.aviso.btnRetomar then GL.Mostrar(ui.aviso.btnRetomar, ui.aviso.retomar ~= nil) end
  -- 6.3: preparación antes de dejar la zona (o cuando la pides con /ga preparar)
  ui.prep:Hide()
  local zonaPaso, zonaSig = CambioDeZona(p)
  if ui.prepForzada then zonaPaso = zonaPaso or (d and d.z) end
  -- 9.4.2: fuera de la Guía. Al cambiar de zona sale como aviso en el centro de la pantalla, una vez por zona;
  -- /ga preparar la sigue enseñando aquí entera.
  if zonaPaso and not ui.prepForzada and ui.prepAvisada ~= zonaPaso and GL.LineasAntesDeSalir and GL.LanzarAvisoFuera then
    ui.prepAvisada = zonaPaso
    local okS, lineasS = pcall(GL.LineasAntesDeSalir, zonaPaso)
    if okS and type(lineasS) == "table" and #lineasS > 0 then
      local primera = tostring(lineasS[1][1] or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      pcall(GL.LanzarAvisoFuera, GL.L"Antes de salir de " .. zonaPaso, primera .. (#lineasS > 1 and ("  (+" .. (#lineasS - 1) .. ")") or ""), false,
        function() if GL.comandos and GL.comandos["preparar"] then GL.comandos["preparar"]("") end end)   -- 9.4.2: clic: la lista entera (9.7.6: sin pasar por /ga preparar, que ya no existe)
    end
  end
  if zonaPaso and Preparacion and ui.prepForzada then
    local ok, alto = pcall(Preparacion, zonaPaso, zonaSig, ancho)
    if ok and alto then
      ui.prep:ClearAllPoints()
      ui.prep:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 0, -(Y_CAJA - 4 + y))
      ui.prep:SetPoint("TOPRIGHT", ui.panelGuia, "TOPRIGHT", 0, -(Y_CAJA - 4 + y))
      ui.prep:SetHeight(alto)
      ui.prep:Show()
      y = y + alto + 6
    elseif not ok and GL.Fallo(GL.L"preparación", alto) then
      Mensaje(GL.L"error en la preparación: " .. tostring(alto))
    end
  end
  if ui.desvio:IsShown() then
    ui.desvio:ClearAllPoints()
    ui.desvio:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 0, -(Y_CAJA - 4))
    ui.desvio:SetPoint("TOPRIGHT", ui.panelGuia, "TOPRIGHT", 0, -(Y_CAJA - 4))
  end
  return y
end

local function RefrescarGuia()
  local db = GuiaAventureroDB
  local s, p = PasoActual()
  local ancho, alto = AnchoContenido(), AltoContenido()

  ui.zona:SetText(s.titulo)
  local ritmo = GL.TextoRitmo and GL.TextoRitmo()   -- 6.9: XP por hora y tiempo para el siguiente nivel
  ui.niveles:SetText(GRIS .. GL.L"Niveles " .. s.min .. "-" .. s.max .. GL.L"  ·  sección " .. db.seccion .. GL.L" de " .. NumSecciones() .. FIN .. (ritmo and ("  ·  " .. ritmo) or "") ..
    ((GL.TextoDescansada and GL.TextoDescansada()) or ""))   -- 7.4
  if GL.PintarChips then pcall(GL.PintarChips, ui, s, db, ritmo) end   -- 8.9.5: la misma información en etiquetas
  local hechos, total = PasosHechos()
  ui.progreso:SetMinMaxValues(0, total)
  ui.progreso:SetValue(hechos)
  local estim = GL.TextoTiempoSeccion and GL.TextoTiempoSeccion()   -- 7.5.7: tiempo estimado para acabar la sección
  if estim then
    ui.progreso.texto:SetText(GL.L"Ruta " .. hechos .. "/" .. total .. " · " .. math.floor(hechos * 100 / total) .. " %  ·  " .. estim)
  else
    ui.progreso.texto:SetText(GL.L"Ruta: " .. hechos .. GL.L" de " .. total .. GL.L" pasos hechos  (" .. math.floor(hechos * 100 / total) .. " %)")
  end

  -- 9.6: Guía clara (GuiaClara.lua): tarjetas Coger, Hacer y Entregar en lugar de la caja del paso y los objetivos
  local clara = (GL.PintarGuiaClara and GL.GuiaClaraActiva() and not (GL.ModoLectura and GL.ModoLectura())) and true or false
  if GL.GuiaClaraOcultar then pcall(GL.GuiaClaraOcultar, clara) end
  if ui.ultimoPasoExtra ~= db.seccion .. ":" .. db.paso then destinoExtra = nil; ui.sel = nil end
  ui.ultimoPasoExtra = db.seccion .. ":" .. db.paso

  -- 6.2: avisos de desvío y de zona encima de la caja del paso
  local yAvisos = RefrescarAvisos(p, ancho)
  local y
  if clara then
    if GL.SubirAvisos then pcall(GL.SubirAvisos, ui.panelGuia, 32) end   -- sin la fila Anterior / Mi nivel / Siguiente
    local okC, hC = pcall(GL.PintarGuiaClara, ui.panelGuia, Y_CAJA - 32 + yAvisos, ancho)
    if okC and type(hC) == "number" then
      ui.caja:Hide(); ui.acciones:Hide(); ui.sinDestino:Hide(); ui.cabAvisos:Hide()
      for g = 1, 3 do ui.grupos[g]:Hide() end
      for i = 1, MAX_DESTINOS do ui.destinos[i]:Hide() end
      if GL.OcultarLinea then pcall(GL.OcultarLinea) end
      ui.ultimoPaso = db.seccion .. ":" .. db.paso
      y = -(Y_CAJA - 32 + yAvisos + hC)
    else
      clara = false
      if GL.Fallo(GL.L"guía clara", hC) then Mensaje(GL.L"guía clara: " .. tostring(hC)) end
      if GL.GuiaClaraOcultar then pcall(GL.GuiaClaraOcultar, false) end
      if GL.SubirAvisos then pcall(GL.SubirAvisos, ui.panelGuia, -32) end
    end
  end
  if not clara then   -- 9.6: la Guía de antes (sin sangrar de nuevo para no mover todo el bloque)
  ui.caja:Show()
  if GL.LineaAntes then   -- 9.0: línea de tiempo, el paso anterior encima de la caja (Guia9.lua)
    local okL, hL = pcall(GL.LineaAntes, ui.panelGuia, Y_CAJA - 4 + yAvisos, ancho)
    if okL and type(hL) == "number" then yAvisos = yAvisos + hL elseif not okL and GL.Fallo(GL.L"línea de tiempo", hL) then Mensaje(GL.L"línea de tiempo: " .. tostring(hL)) end
  end
  ui.caja:ClearAllPoints()
  ui.caja:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 0, -(Y_CAJA + yAvisos))
  ui.caja:SetPoint("TOPRIGHT", ui.panelGuia, "TOPRIGHT", 0, -(Y_CAJA + yAvisos))

  -- caja del paso
  local estado = EstadoPaso(p)
  ui.pasoNum:SetText(AMARILLO .. GL.L"Paso " .. db.paso .. GL.L" de " .. #s.pasos .. FIN .. ((GL.EtiquetaPaso and db.iconosPaso ~= false) and ("   " .. GL.EtiquetaPaso(db.seccion, db.paso)) or ""))
  if estado == "hecho" then
    ui.pasoEstado:SetText(VERDE .. GL.L"Hecho" .. FIN)
  elseif estado == "pendiente" then
    ui.pasoEstado:SetText(AMARILLO .. GL.L"En curso" .. FIN)
  else
    ui.pasoEstado:SetText(GRIS .. GL.L"Sin misiones" .. FIN)
  end
  local texto = Colorear(p.t)
  if GL.Resaltar then   -- 8.9.5: PNJ, lugares y acciones con color
    local okT, t2 = pcall(GL.Resaltar, texto, p)
    if okT and type(t2) == "string" then texto = t2 end
  end
  -- 7.0: retrato del PNJ del destino a la izquierda del texto (Experiencia.lua); devuelve el hueco que ocupa
  local okR, r = pcall(function() return GL.ActualizarRetrato and GL.ActualizarRetrato(ui.caja, DestinoActual()) end)
  r = (okR and type(r) == "number") and r or 0
  -- 8.9.5: línea «Ahora» (qué hacer y a cuántos metros) encima del texto
  local okA, hA = pcall(function() return GL.PintarAhora and GL.PintarAhora(ui.caja, DestinoActual(), r, ancho) end)
  hA = (okA and type(hA) == "number") and hA or 0
  ui.pasoTexto:ClearAllPoints()
  ui.pasoTexto:SetPoint("TOPLEFT", ui.caja, "TOPLEFT", 14 + r, -26 - hA)
  ui.pasoTexto:SetWidth(ancho - 24 - r)
  ui.pasoTexto:SetText(texto)
  local altoCaja = 30 + hA + Alto(ui.pasoTexto, texto, math.floor(TamTextoPaso() * 1.25 + 0.5), ancho - 24 - r) + 10
  if r > 0 then altoCaja = math.max(altoCaja, 26 + 58 + 8) end
  if GL.AltoRecompensas then   -- 8.9.1: iconos de las recompensas de la misión que entregas
    local okRec, extraRec = pcall(GL.AltoRecompensas, ui.caja, p, ancho, altoCaja)
    if okRec and type(extraRec) == "number" then altoCaja = altoCaja + extraRec end
  end
  local nota = db.notas and db.notas[db.seccion .. ":" .. db.paso]   -- 7.4
  if nota and nota ~= "" then
    local tn = GRIS .. GL.L"Tu nota: " .. FIN .. "|cffcccccc" .. nota .. FIN
    ui.notaTexto:ClearAllPoints()
    ui.notaTexto:SetPoint("TOPLEFT", ui.caja, "TOPLEFT", 14 + r, -(altoCaja - 4))
    ui.notaTexto:SetWidth(ancho - 24 - r)
    ui.notaTexto:SetText(tn)
    ui.notaTexto:Show()
    altoCaja = altoCaja + Alto(ui.notaTexto, tn, 13, ancho - 24 - r) + 4
  else
    ui.notaTexto:Hide()
  end
  -- destello al cambiar de paso (no al abrir la ventana ni al refrescar el mismo paso)
  local clavePaso = db.seccion .. ":" .. db.paso
  if ui.ultimoPaso and ui.ultimoPaso ~= clavePaso and db.destello ~= false then
    local d = ui.caja.destello
    if d and d.anim then d.anim:Stop(); d.anim:Play() end
  end
  if ui.ultimoPaso and ui.ultimoPaso ~= clavePaso and GL.AlCambiarPaso then pcall(GL.AlCambiarPaso, ui.caja) end   -- 8.8: transición
  ui.ultimoPaso = clavePaso
  ui.caja:SetHeight(altoCaja)
  local colRaya = COLOR.gris
  if estado == "hecho" then colRaya = COLOR.verde elseif estado == "pendiente" then colRaya = COLOR.acento end
  ui.caja.raya:SetColorTexture(colRaya[1], colRaya[2], colRaya[3], 1)

  -- 8.9.5: modo lectura: solo el paso (con letra más grande); se quita con el botón Leer de la caja
  if GL.ModoLectura and GL.ModoLectura() then
    for g = 1, 3 do ui.grupos[g]:Hide() end
    for i = 1, MAX_DESTINOS do ui.destinos[i]:Hide() end
    ui.acciones:Hide(); ui.sinDestino:Hide(); ui.cabAvisos:Hide()
    if ui.contAvisos then ui.contAvisos:Hide() end
    if GL.CabeceraAvisos then pcall(GL.CabeceraAvisos, nil, 0) end
    for i = 1, #ui.info do ui.info[i]:Hide() end
    ui.infoTexto:Hide()
    if ui.despGuia then ui.despGuia:Ajustar(Y_CAJA + yAvisos + altoCaja + 10) end
    return
  end
  for i = 1, #ui.info do ui.info[i]:Show() end
  ui.infoTexto:Show()

  -- objetivos (6.1): Siguiente (lo que falta del paso; lo pospuesto al final), Cerca de ti (destinos de los pasos
  -- siguientes a menos de 200 m) y Completado (lo hecho del paso). Clic en uno: Seguir, Posponer o Ignorar.
  if ui.ultimoPasoExtra ~= clavePaso then destinoExtra = nil; ui.sel = nil end
  ui.ultimoPasoExtra = clavePaso
  if destinoExtra and DestinoHecho(destinoExtra) == true then destinoExtra = nil end
  local grupos = { {}, {}, {} }
  local pospuestos = {}
  for i = 1, ((p.wp and #p.wp) or 0) do
    local d = p.wp[i]
    local hecho = DestinoHecho(d)
    local e = { d = d, i = i, hecho = hecho }
    if hecho then table.insert(grupos[3], e)
    elseif Marcado("pospuestos", d) then e.pospuesto = true; table.insert(pospuestos, e)
    else table.insert(grupos[1], e) end
  end
  for _, e in ipairs(pospuestos) do table.insert(grupos[1], e) end
  if GL.Vector then
    local cs, cp = db.seccion, db.paso
    local vistos = {}
    for _ = 1, 10 do
      cs, cp = PasoDespues(cs, cp)
      if not cs then break end
      local sig = RUTA.secciones[cs].pasos[cp]
      for _, d in ipairs(sig.wp or {}) do
        local clave = ClaveDestino(d)
        if not vistos[clave] and d.m and DestinoHecho(d) ~= true then
          vistos[clave] = true
          local ok, este, _, dist = pcall(GL.Vector, d)
          if ok and este and dist and dist <= CERCA then table.insert(grupos[2], { d = d, dist = dist }) end
        end
      end
    end
    table.sort(grupos[2], function(x, z) return x.dist < z.dist end)
    for k = #grupos[2], MAX_CERCA + 1, -1 do grupos[2][k] = nil end
  end
  local nombresGrupo = { GL.L"Siguiente", GL.L"Cerca de ti (pasos siguientes)", GL.L"Completado en este paso" }
  y = -(Y_CAJA + yAvisos + altoCaja + 4)
  local usadas, haySel = 0, false
  ui.acciones:Hide()
  for g = 1, 3 do
    local cab = ui.grupos[g]
    if #grupos[g] > 0 and usadas < MAX_DESTINOS then
      cab:ClearAllPoints()
      cab:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 0, y)
      cab:SetText(GRIS .. string.upper(nombresGrupo[g]) .. FIN)
      cab:Show()
      y = y - 14
      for k, e in ipairs(grupos[g]) do
        if usadas >= MAX_DESTINOS then break end
        usadas = usadas + 1
        local fila, d = ui.destinos[usadas], e.d
        fila.entrada, fila.grupo = e, g
        fila:ClearAllPoints()
        fila:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 0, y)
        fila:SetPoint("TOPRIGHT", ui.panelGuia, "TOPRIGHT", 0, y)
        if e.hecho then
          PonerIcono(fila.icono, ICONO_HECHO, false)
        elseif d.a and ICONO_ACCION[d.a] then
          PonerIcono(fila.icono, ICONO_ACCION[d.a], false)
        else
          PonerIcono(fila.icono, ICONO_LUGAR)
        end
        local etiqueta, grupoN = "", nil   -- 7.6: ÉLITE / GRUPO N (lo dice el juego)
        if d.q and GL.EtiquetaMision and not e.hecho then etiqueta, grupoN = GL.EtiquetaMision(d.q) end
        fila.texto:SetText(((e.hecho or e.pospuesto) and GRIS or BLANCO) .. d.n .. FIN .. etiqueta)
        fila.coords:SetText(GRIS .. string.format("%.1f, %.1f", d.x or 0, d.y or 0) .. FIN)
        local progreso, detalle = ProgresoDestino(d, e.hecho)
        if g == 2 then progreso = string.format("%d m", math.floor(e.dist * 0.9144 + 0.5))
        elseif e.pospuesto then progreso = GRIS .. "pospuesto" .. FIN
        elseif e.hecho then progreso = GRIS .. (Marcado("ignorados", d) and "ignorado" or "hecho") .. FIN end
        fila.progreso:SetText(progreso or "")
        local sigue = (destinoExtra and destinoExtra == d) or (not destinoExtra and g ~= 2 and e.i == db.destino)
        Mostrar(fila.elegido, sigue)
        Mostrar(fila.raya, sigue)
        Mostrar(fila.par, k % 2 == 0)
        fila.ayudaTitulo = d.n
        fila.ayudaTexto = tostring(d.z) .. "  " .. string.format("%.1f, %.1f", d.x or 0, d.y or 0) ..
          (e.hecho and ("\n" .. VERDE .. GL.L"Hecho" .. FIN) or "") ..
          ((detalle and detalle ~= "") and ("\n" .. detalle) or "") ..
          ((etiqueta ~= "") and ("\n" .. (grupoN and grupoN > 1 and (GL.L"Recomendado ir con " .. grupoN .. GL.L" jugadores. ") or GL.L"Mejor ir en grupo. ") ..
            GL.L"Si vas solo, Ignorar lo salta.") or "") ..
          "\n" .. GRIS .. GL.L"Clic: Seguir, Posponer o Ignorar." .. (d.q and GL.L"\nShift+clic: enlazar la misión en el chat." or "") .. FIN
        fila:Show()
        y = y - ALTO_DESTINO
        if ui.sel == ClaveDestino(d) then
          haySel = true
          ui.acciones.entrada = e
          ui.acciones:ClearAllPoints()
          ui.acciones:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 22, y - 2)
          Mostrar(ui.acciones.posponer, g == 1)
          ui.acciones.ignorar:ClearAllPoints()
          ui.acciones.ignorar:SetPoint("LEFT", g == 1 and ui.acciones.posponer or ui.acciones.seguir, "RIGHT", 4, 0)
          ui.acciones.ignorar.texto:SetText((e.hecho and Marcado("ignorados", d)) and GL.L"No ignorar" or GL.L"Ignorar")
          ui.acciones:Show()
          y = y - 22
        end
      end
      y = y - 2
    else
      cab:Hide()
    end
  end
  if not haySel then ui.sel = nil end
  for i = usadas + 1, MAX_DESTINOS do ui.destinos[i]:Hide() end
  if usadas == 0 then
    ui.sinDestino:ClearAllPoints()
    ui.sinDestino:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 2, y - 2)
    ui.sinDestino:SetPoint("TOPRIGHT", ui.panelGuia, "TOPRIGHT", 0, y - 2); UnaLinea(ui.sinDestino)
    ui.sinDestino:Show()
    y = y - ALTO_DESTINO
  else
    ui.sinDestino:Hide()
  end

  if GL.LineaDespues then   -- 9.0: línea de tiempo, los pasos siguientes debajo de los objetivos (Guia9.lua)
    local okL, hL = pcall(GL.LineaDespues, ui.panelGuia, -y + 4, ancho)
    if okL and type(hL) == "number" and hL > 0 then y = y - hL - 4 elseif not okL and GL.Fallo(GL.L"línea de tiempo", hL) then Mensaje(GL.L"línea de tiempo: " .. tostring(hL)) end
  end
  end   -- 9.6: fin de la Guía de antes
  -- 7.4: avisos de otros módulos (equipo, bolsas, comida, reactivos, posada, grupo) debajo de los objetivos
  -- 8.9.5: las tarjetas van en un marco propio para poder plegarlas todas juntas
  if not ui.contAvisos then
    ui.contAvisos = CreateFrame("Frame", nil, ui.panelGuia)
    ui.contAvisos:SetAllPoints(ui.panelGuia)
  end
  local yTarjetas = -y + 6   -- 9.4.2: sin cabecera AVISOS (solo quedan opcionales y cambios de ruta)
  local altoTarjetas, nTarjetas = 0, 0
  for i = 1, #GL.tarjetasGuia do
    local ok, h = pcall(GL.tarjetasGuia[i], ui.contAvisos, yTarjetas + altoTarjetas, ancho)
    if ok and type(h) == "number" and h > 0 then altoTarjetas = altoTarjetas + h + 6; nTarjetas = nTarjetas + 1
    elseif not ok then GL.Fallo("tarjeta #" .. i, h) end
  end
  ui.cabAvisos:Hide()
  if GL.CabeceraAvisos then pcall(GL.CabeceraAvisos, nil, 0) end
  if altoTarjetas > 0 then
    ui.contAvisos:Show()
    y = y - 6 - altoTarjetas
  end
  if clara and GL.PintarLuego then   -- 9.6: «Luego» y los botones Atrás y Saltar paso
    local okL, hL = pcall(GL.PintarLuego, ui.panelGuia, -y + 6, ancho)
    if okL and type(hL) == "number" then y = y - 6 - hL elseif not okL and GL.Fallo(GL.L"guía clara", hL) then Mensaje(GL.L"guía clara: " .. tostring(hL)) end
  end

  -- 9.4.2: sin «Consejos de la sección» en la Guía (lo mismo está en Personaje › Hechizos y Equipo y en Profesiones)
  if not ui.conConsejos then
    ui.info[1]:Hide(); ui.infoTexto:Hide()
    if ui.despGuia then ui.despGuia:Ajustar(-y + 8) end
    return
  end
  -- consejos de la zona (ocupan el resto del alto)
  y = y - 8
  ui.info[1]:ClearAllPoints()
  ui.info[1]:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 0, y)
  -- 9.0: un solo bloque plegable "Consejos de la sección" (antes tres pestañas Hechizos / Equipo / Profesión)
  local abiertos = db.consejosAbiertos == true
  ui.info[1].texto:SetText((abiertos and "-  " or "+  ") .. GL.L"Consejos de la sección")
  ui.info[1]:SetActivo(abiertos)
  y = y - 20 - 6
  ui.infoTexto:ClearAllPoints()
  ui.infoTexto:SetPoint("TOPLEFT", ui.panelGuia, "TOPLEFT", 2, y)
  ui.infoTexto:SetWidth(ancho - 4)
  ui.infoTexto:SetHeight(math.max(14, alto + y))
  local info = ""
  if abiertos then
    local partes = {}
    for _, clave in ipairs(pestanasInfo) do
      local t = Colorear(s[clave] or "")
      -- en Hechizos, primero lo que puedes aprender ya en el instructor, por orden de prioridad (Instructor.lua)
      if clave == "entrenar" and GL.TextoHechizosNivel then
        local ok, extra = pcall(GL.TextoHechizosNivel)
        if ok and extra and extra ~= "" then t = (t ~= "" and (extra .. "\n\n" .. t)) or extra end
      end
      if t ~= "" then partes[#partes + 1] = "|cffffd100" .. nombresInfo[clave] .. "|r\n" .. t end
    end
    info = table.concat(partes, "\n\n")
  end
  ui.infoTexto:SetText(info)
  -- 7.9.2: si los consejos no caben, el panel crece y sale la barra para bajar
  local altoInfo = math.max(14, (ui.infoTexto:GetStringHeight() or 0) + 4)
  if altoInfo > alto + y then ui.infoTexto:SetHeight(altoInfo) end
  if ui.despGuia then ui.despGuia:Ajustar(-y + altoInfo) end
end

local function RellenarTalento(fila, i, ancho, nivel, real)
  local t = RUTA.talentos[i]
  local estado = "futuro"
  if real then   -- 9.7.4: lo que tienes puesto en tu árbol, no solo tu nivel
    if real.hecho[i] then estado = "pasado" elseif real.primero == i then estado = "actual" end
  elseif nivel > t.h then estado = "pasado" elseif nivel >= t.d then estado = "actual" end
  PonerIcono(fila.marco.icono, t.icono)
  fila.marco.icono:SetDesaturated(estado == "pasado")
  fila.marco.icono:SetAlpha(estado == "pasado" and 0.55 or 1)
  if estado == "actual" then
    Caja(fila.marco, COLOR.icono, COLOR.iconoActual)
  elseif estado == "pasado" then
    Caja(fila.marco, COLOR.icono, COLOR.iconoPasado)
  else
    Caja(fila.marco, COLOR.icono, COLOR.iconoBorde)
  end
  Mostrar(fila.fondo, estado == "actual")
  Mostrar(fila.raya, estado == "actual")
  -- 9.5: como en el juego: amarillo si el talento queda completo, verde si aún le faltan puntos
  local pa, pb = string.match(t.puntos or "", "^(%d+)/(%d+)$")
  fila.puntos:SetText(((pa and pa == pb) and "|cffffd100" or "|cff4dff4d") .. tostring(t.puntos or "") .. FIN)
  fila.nivel:SetText(AZUL .. GL.L"Nv " .. Rango(t.d, t.h) .. FIN)
  local color = BLANCO
  if estado == "actual" then color = VERDE elseif estado == "pasado" then color = GRIS end
  -- 9.4.2: solo el nombre en el idioma de la guía (el del otro idioma, entre paréntesis, sigue en los datos para buscarlo en el árbol)
  local titulo = color .. (string.match(t.nombre, "^(.-)%s*%(.-%)%s*$") or t.nombre) .. FIN
  fila.titulo:SetWidth(ancho - 44 - 58)
  fila.titulo:SetText(titulo)
  local rama = Rama(t.rama)
  local nombreRama = rama and ("|cff" .. rama.color .. t.rama .. FIN) or t.rama
  local nota = nombreRama .. GRIS .. (t.fila and (GL.L", fila " .. t.fila) or "") .. ". " .. t.nota .. FIN
  fila.nota:SetWidth(ancho - 44 - 4)
  fila.nota:SetText(nota)
  -- 9.4.2: la nota en una línea; entera, al pasar el ratón por la fila
  if not fila.notaUnaLinea then
    fila.notaUnaLinea = true
    UnaLinea(fila.nota)
    fila:EnableMouse(true)
    fila:SetScript("OnEnter", function(self)
      if not (GameTooltip and self.notaTitulo) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.notaTitulo, 1, 0.82, 0)
      GameTooltip:AddLine(self.notaCompleta or "", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    fila:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end
  fila.notaTitulo = string.match(t.nombre, "^(.-)%s*%(.-%)%s*$") or t.nombre
  fila.notaCompleta = nota
  local h = 3 + Alto(fila.titulo, titulo, 13, ancho - 102) + 2 + 14 + 4
  if h < 38 then h = 38 end
  fila:SetHeight(h)
  return h
end

local function RefrescarTalentos()
  local nivel = UnitLevel("player") or 1
  local ancho, alto = AnchoContenido(), AltoContenido()
  local total = #RUTA.talentos
  if inicioTal > total then inicioTal = total end
  if inicioTal < 1 then inicioTal = 1 end

  -- 9.7.7.1: si el juego deja leer tu árbol, los puntos que tienes de verdad en cada rama (antes, los del plan)
  local reales = GL.PuntosRealesPorRama and GL.PuntosRealesPorRama() or nil
  for i = 1, #ui.ramas do
    local chip = ui.ramas[i]
    local r = chip.rama
    local tengo = reales and ((reales.ramas or {})[r.nombre] or 0) or PuntosRama(r.nombre, nivel)
    chip.texto:SetText("|cff" .. r.color .. r.nombre .. FIN .. "\n" .. BLANCO .. tengo .. FIN ..
      GRIS .. " / " .. PuntosRama(r.nombre, 60) .. FIN)
  end
  local resumen
  if nivel < 10 then
    resumen = BLANCO .. GL.L"Los talentos empiezan al nivel 10." .. FIN
  else
    resumen = BLANCO .. GL.L"Nivel " .. nivel .. ": " .. math.min(nivel, 60) - 9 .. GL.L" de 51 puntos." .. FIN
  end
  -- 9.4.2: los talentos ya salen solo en el idioma de la guía: fuera la frase de los paréntesis
  local intro = tostring(RUTA.talentosIntro or ""):gsub("%s*Nombres en español con el inglés entre paréntesis%.", "")
  resumen = resumen .. "  " .. GRIS .. intro .. FIN
  ui.talResumen:SetWidth(ancho)
  ui.talResumen:SetText(resumen)

  local y = -(36 + Alto(ui.talResumen, resumen, 12, ancho) + 8)
  -- 9.6: con la Guía clara, tarjeta «Ahora» (Pestanas96.lua) y el plan entero en un desplegable
  local claraTal = GL.PestanasClaras and GL.PestanasClaras() and GL.PintarTalentoAhora
  Mostrar(ui.ponerTal, not claraTal)
  if claraTal then
    local yy, abierto = GL.PintarTalentoAhora(ui.panelTal, -y, ancho, RefrescarTalentos)
    y = -yy
    if not abierto then
      for i = 1, #ui.filasTal do ui.filasTal[i]:Hide() end
      ui.talPagina:SetText("")
      return
    end
  elseif GL.OcultarTalentoAhora then
    GL.OcultarTalentoAhora()
  end
  local primera = ui.filasTal[1]
  primera:ClearAllPoints()
  primera:SetPoint("TOPLEFT", ui.panelTal, "TOPLEFT", 0, y)
  primera:SetPoint("TOPRIGHT", ui.panelTal, "TOPRIGHT", 0, y)
  local disponible = alto + y - 22 - 22
  local real = GL.EstadoTalentosReal and GL.EstadoTalentosReal() or nil
  finTal = LlenarLista(ui.filasTal, disponible, inicioTal, total, function(fila, i)
    return RellenarTalento(fila, i, ancho, nivel, real)
  end)
  ui.talPagina:SetText(GRIS .. GL.L"Talentos " .. Rango(inicioTal, finTal) .. GL.L" de " .. total .. GL.L" (rueda del ratón)" .. FIN)
end

-- Cuantos tienes de un objeto (bolsas y banco).
local function ContarObjeto(id)
  if GL.InventarioProfesion975 then return GL.InventarioProfesion975(id) end
  return nil
end

-- Linea "Tienes: 34/58 Paño de lino, 2 Hilo burdo". Lo que hace falta se cuenta como un punto por objeto fabricado.
local function MaterialesPaso(paso, nivel)
  if not paso.mat or #paso.mat == 0 then return nil end
  local partes = {}
  for i = 1, #paso.mat do
    local m = paso.mat[i]            -- { id, cantidad por objeto (0 si no se sabe), nombre }
    local n = ContarObjeto(m[1])
    if n then
      if m[2] and m[2] > 0 then
        local necesario = GL.NecesarioProfesion975 and GL.NecesarioProfesion975(paso, m, nivel) or m[2] * math.max(1, paso.h - paso.d)
        table.insert(partes, ((n >= necesario) and VERDE or AMARILLO) .. n .. "/" .. necesario .. FIN .. " " .. GL.T(m[3]))
      else
        table.insert(partes, BLANCO .. n .. FIN .. " " .. GL.T(m[3]))
      end
    else
      local necesario = m[2] and m[2] > 0 and GL.NecesarioProfesion975 and GL.NecesarioProfesion975(paso, m, nivel)
      table.insert(partes, GRIS .. "?" .. (necesario and ("/" .. necesario) or "") .. FIN .. " " .. GL.T(m[3]))
    end
  end
  if #partes == 0 then return nil end
  return GRIS .. GL.L"Tienes: " .. FIN .. table.concat(partes, GRIS .. ", " .. FIN)
end

------------------------------------------------------------------------
-- 6.3: preparación antes de dejar una zona. Solo con datos de la guía o del juego: misiones del diario con algo
-- que hacer aquí, hechizos que puedes aprender y el instructor de la ruta más cercano, materiales que faltan
-- para el paso actual de tus profesiones y misiones de la guía que quedan en la zona.
------------------------------------------------------------------------
Preparacion = function(zona, zonaSig, ancho)
  local lineas = {}   -- { texto, destino para Seguir o nil }
  local seccion = RUTA.secciones[GuiaAventureroDB.seccion]
  -- misiones del diario con objetivos o entrega en esta zona; y misiones de la guía que quedan aquí
  local vistas, diario, quedan = {}, {}, 0
  for _, sec in ipairs(RUTA.secciones) do
    for _, paso in ipairs(sec.pasos or {}) do
      for _, wp in ipairs(paso.wp or {}) do
        if wp.q and wp.z == zona and not vistas[wp.q .. tostring(wp.a)] then
          vistas[wp.q .. tostring(wp.a)] = true
          if (wp.a == "C" or wp.a == "T") and MisionEnDiario(wp.q) and not MisionCompletada(wp.q) and not Marcado("ignorados", wp) then
            if not vistas[wp.q] then
              vistas[wp.q] = true
              local prog = ProgresoDestino(wp, false)
              table.insert(diario, { wp = wp, prog = prog })
            end
          end
          if wp.a == "T" and not MisionCompletada(wp.q) then quedan = quedan + 1 end
        end
      end
    end
  end
  if #diario > 0 then
    local partes = {}
    for i = 1, math.min(#diario, 2) do
      local nombre = string.gsub(string.gsub(diario[i].wp.n, "^[^:]-:%s*", ""), "%s*%b()%s*$", "")
      table.insert(partes, AMARILLO .. nombre .. FIN .. (diario[i].prog and (" " .. diario[i].prog) or ""))
    end
    table.insert(lineas, { #diario .. (#diario == 1 and GL.L" misión" or GL.L" misiones") .. GL.L" del diario por acabar aquí: " ..
      table.concat(partes, ", ") .. (#diario > 2 and (" y " .. (#diario - 2) .. GL.L" más") or ""), diario[1].wp })
  end
  -- hechizos que puedes aprender ya y el instructor de clase de la ruta en esta zona (el más cercano)
  local n = GL.HechizosParaAprender and GL.HechizosParaAprender() or 0
  if n > 0 then
    local mejor, mejorDist
    for _, sec in ipairs(RUTA.secciones) do
      for _, paso in ipairs(sec.pasos or {}) do
        if paso.comprobar and paso.comprobar.hechizos then
          for _, wp in ipairs(paso.wp or {}) do
            if wp.npc and wp.z == zona then
              local ok, este, _, dist = false, nil, nil, nil
              if GL.Vector then ok, este, _, dist = pcall(GL.Vector, wp) end
              dist = (ok and este and dist) or 1e9
              if not mejor or dist < mejorDist then mejor, mejorDist = wp, dist end
            end
          end
        end
      end
    end
    local donde = ""
    if mejor then
      donde = ": " .. AMARILLO .. mejor.n .. FIN .. ((mejorDist < 1e8) and (" (a " .. math.floor(mejorDist * 0.9144 + 0.5) .. " m)") or "")
    end
    table.insert(lineas, { GL.L"Puedes aprender " .. n .. (n == 1 and GL.L" hechizo" or GL.L" hechizos") .. donde, mejor })
  end
  -- materiales que faltan para el paso actual de cada profesión de la ruta que tengas
  for _, prof in ipairs(RUTA.profesiones or {}) do
    local nivel = NivelProfesion(prof)
    if nivel then
      for _, paso in ipairs(prof.pasos or {}) do
        if nivel >= paso.d and nivel < paso.h and paso.mat then
          local faltan = {}
          local incierto = false
          for _, m in ipairs(paso.mat) do
            local tengo = ContarObjeto(m[1])
            if tengo and m[2] and m[2] > 0 then
              local necesario = GL.NecesarioProfesion975 and GL.NecesarioProfesion975(paso, m, nivel) or m[2] * math.max(1, paso.h - nivel)
              if tengo < necesario then table.insert(faltan, "|cffff7070" .. (necesario - tengo) .. " " .. GL.T(m[3]) .. FIN) end
            elseif m[2] and m[2] > 0 then incierto = true end
          end
          if incierto then table.insert(lineas, { (prof.corto or prof.nombre) .. ": " .. GL.L"Inventario no disponible para algunos materiales." }) end
          if #faltan > 0 then
            table.insert(lineas, { (prof.corto or prof.nombre) .. GL.L" (paso " .. paso.d .. "-" .. paso.h .. GL.L"): te faltan " ..
              table.concat(faltan, ", ") })
          end
          break
        end
      end
    end
  end
  if GL.LineasAntesDeSalir then   -- 9.0: comida, bebida y reactivos que conviene comprar (Guia9.lua)
    local okS, extra = pcall(GL.LineasAntesDeSalir, zona)
    if okS and type(extra) == "table" then for _, l in ipairs(extra) do table.insert(lineas, l) end end
  end
  local resumen = (#lineas == 0) and (VERDE .. GL.L"Todo listo para irte." .. FIN) or nil
  if quedan > 0 then
    table.insert(lineas, { GRIS .. GL.L"Quedan " .. quedan .. (quedan == 1 and GL.L" misión" or GL.L" misiones") ..
      GL.L" de la guía por entregar en esta zona (Exploración)." .. FIN })
  end
  if resumen then table.insert(lineas, 1, { resumen }) end

  -- pintar
  local c = ui.prep
  local cosas = 0
  for _, l in ipairs(lineas) do if l[3] ~= "info" and l[1] ~= resumen then cosas = cosas + 1 end end
  c.titulo:SetText(VERDE .. GL.L"Antes de salir de " .. zona .. FIN .. (cosas > 0 and (GRIS .. "  ·  " .. cosas .. (cosas == 1 and GL.L" cosa" or GL.L" cosas") .. FIN) or ""))
  c.sig:SetText(zonaSig and (GRIS .. GL.L"el siguiente paso es en " .. zonaSig .. FIN) or "")
  local y = -24
  for i = 1, #c.lineas do c.lineas[i].texto:Hide(); c.lineas[i].boton:Hide() end
  for i = 1, math.min(#lineas, #c.lineas) do
    local l, f = lineas[i], c.lineas[i]
    local conBoton = l[2] ~= nil
    local w = ancho - 18 - (conBoton and 64 or 0)
    f.texto:ClearAllPoints()
    f.texto:SetPoint("TOPLEFT", c, "TOPLEFT", 9, y)
    f.texto:SetWidth(w)
    f.texto:SetText(l[1])
    f.texto:Show()
    if conBoton then
      f.boton.destino = l[2]
      f.boton:ClearAllPoints()
      f.boton:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, y + 2)
      f.boton:Show()
    end
    y = y - math.max(18, Alto(f.texto, l[1], 12, w)) - 4
  end
  return -y + 26   -- más el botón Entendido
end

local function RellenarPasoOficio(fila, i, ancho, prof, nivel)
  local paso = prof.pasos[i]
  local estado = "futuro"
  if nivel and nivel >= paso.h then
    estado = "pasado"
  elseif nivel and nivel >= paso.d then
    estado = "actual"
  end
  -- 5.9: un paso sin icono propio trae iconoObjeto (id del objeto) y el icono se pide al juego
  local icono = paso.icono or prof.icono
  if paso.iconoObjeto and C_Item and C_Item.GetItemIconByID then
    local ok, fid = pcall(C_Item.GetItemIconByID, paso.iconoObjeto)
    if ok and fid then icono = fid end
  end
  PonerIcono(fila.marco.icono, icono)
  fila.marco.icono:SetDesaturated(estado == "pasado")
  fila.marco.icono:SetAlpha(estado == "pasado" and 0.55 or 1)
  Mostrar(fila.fondo, estado == "actual")
  Mostrar(fila.raya, estado == "actual")
  local texto
  if estado == "pasado" then
    texto = GRIS .. Rango(paso.d, paso.h) .. "  " .. string.gsub(paso.t, "[<>%[%]]", "") .. FIN
  else
    texto = AZUL .. Rango(paso.d, paso.h) .. FIN .. "  " .. Colorear(paso.t)
    if estado == "actual" then texto = texto .. VERDE .. GL.L"  < estás aquí" .. FIN end
    local materiales = MaterialesPaso(paso, nivel)
    if materiales then texto = texto .. "\n" .. materiales end
  end
  fila.texto:SetWidth(ancho - 32)
  fila.texto:SetText(texto)
  local h = Alto(fila.texto, texto, 12, ancho - 32) + 6
  if h < 26 then h = 26 end
  fila:SetHeight(h)
  return h
end

local function RefrescarOficios()
  local db = GuiaAventureroDB
  local prof = RUTA.profesiones[db.profesion] or RUTA.profesiones[1]
  local nivel, tope = NivelProfesion(prof)
  local ancho, alto = AnchoContenido(), AltoContenido()
  local total = #prof.pasos
  if inicioOfi > total then inicioOfi = total end
  if inicioOfi < 1 then inicioOfi = 1 end

  for i, b in pairs(ui.oficios) do b:SetActivo(i == db.profesion) end
  if prof.skill then db.profesionSkill = prof.skill end   -- 9.5: para no perderla al rehacer la lista
  PonerIcono(ui.ofiMarco.icono, prof.icono)
  ui.ofiNombre:SetText(prof.nombre)
  Mostrar(ui.ofiBarra, not prof.vacia)   -- 9.5: sin profesiones no hay barra que llenar
  if nivel then
    local maximo = tope or 300
    ui.ofiBarra:SetMinMaxValues(0, maximo)
    ui.ofiBarra:SetValue(nivel)
    local txt = nivel .. " / " .. maximo
    if tope and tope < 300 and nivel >= tope then txt = txt .. GL.L"  -  aprende el siguiente rango" end
    ui.ofiBarra.texto:SetText(txt)
  else
    ui.ofiBarra:SetMinMaxValues(0, 300)
    ui.ofiBarra:SetValue(0)
    ui.ofiBarra.texto:SetText(GL.L"Aún no la tienes")
  end

  local intro = GRIS .. Colorear(prof.intro) .. FIN
  if prof.skill == 356 and GL.NecesidadesPesca977 then
    local faltan=GL.NecesidadesPesca977(GL.RUTA and GL.RUTA.profesiones)
    if #faltan>0 then
      local partes={}
      for i=1,math.min(4,#faltan) do
        local m=faltan[i]
        partes[#partes+1]=((GetItemInfo and GetItemInfo(m.id)) or GL.L(m.nombre)).." ×"..m.falta..(m.desconocido and " (?)" or "")
      end
      intro=intro.."\n"..GRIS..GL.L("Peces que te faltan para Cocina y Alquimia (según tus planes, descontando lo que llevas en las bolsas; no todos se pescan aquí): ")..table.concat(partes,", ")..FIN
    end
  end
  for i = 1, #prof.pasos do
    if prof.pasos[i].mat then
      intro = intro .. "\n" .. GRIS .. GL.L"Tienes x/y: existencias (bolsas y banco) y materiales estimados para el tramo restante. Compra en tandas; no todas las fabricaciones dan habilidad." .. FIN
      break
    end
  end
  ui.ofiIntro:SetWidth(ancho)
  ui.ofiIntro:SetText(intro)
  local y = -(80 + GL.OFI.fila + Alto(ui.ofiIntro, intro, 12, ancho) + 8)
  if GL.TarjetaTramo then   -- 9.0: el tramo actual en una tarjeta propia (Secciones9.lua)
    local okT, hT = pcall(GL.TarjetaTramo, ui.panelOfi, -y, ancho, prof, nivel)
    if okT and type(hT) == "number" and hT > 0 then y = y - hT - 8 elseif not okT and GL.Fallo("tramo", hT) then Mensaje(GL.L"tramo: " .. tostring(hT)) end
  end
  if GL.TarjetaRecoleccion then   -- 9.1: ruta de recolección (Recoleccion.lua), solo con Minería, Herboristería o Desuello
    local okR, hR = pcall(GL.TarjetaRecoleccion, ui.panelOfi, -y, ancho)
    if okR and type(hR) == "number" and hR > 0 then y = y - hR - 8 elseif not okR and GL.Fallo(GL.L"recolección", hR) then Mensaje(GL.L"recolección: " .. tostring(hR)) end
  end
  local primera = ui.filasOfi[1]
  primera:ClearAllPoints()
  primera:SetPoint("TOPLEFT", ui.panelOfi, "TOPLEFT", 0, y)
  primera:SetPoint("TOPRIGHT", ui.panelOfi, "TOPRIGHT", 0, y)
  local disponible = alto + y - 22 - 22
  finOfi = LlenarLista(ui.filasOfi, disponible, inicioOfi, total, function(fila, i)
    return RellenarPasoOficio(fila, i, ancho, prof, nivel)
  end)
  ui.ofiPagina:SetText((total > 0) and (GRIS .. GL.L"Pasos " .. Rango(inicioOfi, finOfi) .. GL.L" de " .. total .. GL.L" (rueda del ratón)" .. FIN) or "")   -- 9.6: sin «Pasos 1-0 de 0»
end

local function Refrescar()
  if not frame then return end
  local db = GuiaAventureroDB
  RefrescarCabecera()
  ui.panelGuia:Hide(); ui.panelTal:Hide(); ui.panelOfi:Hide()
  for _, extra in pairs(GL.modos) do
    if extra.panel then extra.panel:Hide() end
  end
  local extra = GL.modos[db.modo]
  if extra and extra.panel then
    extra.panel:Show()
    if extra.refrescar then   -- 7.6.3: si una pantalla falla, se dice en el chat (una vez) y las pestañas siguen bien
      local ok, err = pcall(extra.refrescar)
      if not ok then
        GL.Fallo("panel " .. tostring(db.modo), err)
        ui.erroresPantalla = ui.erroresPantalla or {}
        if not ui.erroresPantalla[db.modo] then ui.erroresPantalla[db.modo] = true; Mensaje(GL.L"error en la pantalla " .. tostring(db.modo) .. ": " .. tostring(err)) end
      end
    end
  elseif db.modo == "talentos" then
    ui.panelTal:Show(); RefrescarTalentos()
  elseif db.modo == "oficios" then
    ui.panelOfi:Show(); RefrescarOficios()
  else
    db.modo = "guia"
    ui.panelGuia:Show(); RefrescarGuia()
  end
  local grupo = GRUPOS[db.modo] or db.modo
  local rep = LADO[db.modo]   -- 6.6: en Reputación y Mazmorras no salen las pestañas de la guía
  for i = 1, #ui.modos do ui.modos[i]:SetActivo(ui.modos[i].clave == grupo) end   -- 9.0: iconos de la barra lateral
  if ui.lado then for i = 1, #ui.lado do ui.lado[i]:SetActivo(ui.lado[i].clave == (rep and db.modo or nil)) end end
  for clave, fila in pairs(ui.subs) do
    if ui.fondosSub and ui.fondosSub[clave] then Mostrar(ui.fondosSub[clave], clave == grupo) end
    for i = 1, #fila do
      fila[i]:SetActivo(fila[i].clave == db.modo)
    end
  end
  if ui.botonOpciones then ui.botonOpciones:SetActivo(grupo == "opciones") end
  for i = 1, #GL.trasRefrescar do
    local ok, err = pcall(GL.trasRefrescar[i])
    if not ok and GL.Fallo(GL.L"tras refrescar", err) then Mensaje(GL.L"error: " .. tostring(err)) end
  end
end

-- Al redimensionar se refresca como mucho cada 0,05 s.
local refrescoProgramado = false
local function ProgramarRefresco()
  if refrescoProgramado then return end
  refrescoProgramado = true
  local function Hacer()
    refrescoProgramado = false
    Refrescar()
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.05, Hacer) else Hacer() end
end

------------------------------------------------------------------------
-- Navegacion
------------------------------------------------------------------------
local function Siguiente()
  local db = GuiaAventureroDB
  local s = RUTA.secciones[db.seccion]
  if db.paso < #s.pasos then
    db.paso = db.paso + 1
  elseif db.seccion < NumSecciones() then
    db.seccion = db.seccion + 1
    db.paso = 1
  else
    Mensaje(GL.L"Has llegado al final de la guía. ¡Enhorabuena!")
  end
  db.destino = 1
  -- 9.6: hacia delante no se bloquea: si caes en un paso ya hecho, la guía sigue sola hasta el primero que falte
  -- (antes se quedaba quieta para siempre tras pulsar Siguiente sobre un paso hecho)
  bloqueo = false
  Refrescar()
  if GL.ProgramarSync then GL.ProgramarSync() end
end

local function Anterior()
  local db = GuiaAventureroDB
  local anteriorS, anteriorP = db.seccion, db.paso
  if db.paso > 1 then
    db.paso = db.paso - 1
  elseif db.seccion > 1 then
    db.seccion = db.seccion - 1
    db.paso = #RUTA.secciones[db.seccion].pasos
  end
  db.destino = 1
  bloqueo = PuedeSaltar(db.seccion, db.paso) and (db.seccion .. ":" .. db.paso) or false
  Refrescar()
  if anteriorS ~= db.seccion or anteriorP ~= db.paso then
    Mensaje(GL.L"Estás en un paso anterior: Mi nivel te lleva al tuyo")
  end
end

local function CambiarSeccion(delta)
  local db = GuiaAventureroDB
  local nueva = db.seccion + delta
  if nueva >= 1 and nueva <= NumSecciones() then
    db.seccion = nueva
    db.paso = 1
    db.destino = 1
  end
  bloqueo = PuedeSaltar(db.seccion, db.paso) and (db.seccion .. ":" .. db.paso) or false
  Refrescar()
end

-- Paginas de Talentos y Profesiones
local function PaginaTal(delta)
  if delta > 0 then
    if finTal < #RUTA.talentos then
      table.insert(pilaTal, inicioTal)
      inicioTal = finTal + 1
    end
  elseif #pilaTal > 0 then
    inicioTal = table.remove(pilaTal)
  else
    inicioTal = math.max(1, inicioTal - (finTal - inicioTal + 1))
  end
  Refrescar()
end

local function PaginaOfi(delta)
  local prof = RUTA.profesiones[GuiaAventureroDB.profesion] or RUTA.profesiones[1]
  if delta > 0 then
    if finOfi < #prof.pasos then
      table.insert(pilaOfi, inicioOfi)
      inicioOfi = finOfi + 1
    end
  elseif #pilaOfi > 0 then
    inicioOfi = table.remove(pilaOfi)
  else
    inicioOfi = math.max(1, inicioOfi - (finOfi - inicioOfi + 1))
  end
  Refrescar()
end

-- 9.4.2: rueda del ratón, de una fila en una (como en el resto de pestañas)
local function RuedaTal(delta)
  if delta < 0 and finTal >= #RUTA.talentos then return end
  pilaTal = {}
  inicioTal = math.max(1, inicioTal - delta)
  Refrescar()
end

local function RuedaOfi(delta)
  local prof = RUTA.profesiones[GuiaAventureroDB.profesion] or RUTA.profesiones[1]
  if delta < 0 and finOfi >= #prof.pasos then return end
  pilaOfi = {}
  inicioOfi = math.max(1, inicioOfi - delta)
  Refrescar()
end

-- Al abrir Talentos o Profesiones, la lista empieza en lo que toca a tu nivel.
local function TalentosDeMiNivel()
  local nivel = UnitLevel("player") or 1
  inicioTal, pilaTal = 1, {}
  for i = 1, #RUTA.talentos do
    if RUTA.talentos[i].h >= nivel then inicioTal = i; return end
  end
  inicioTal = #RUTA.talentos
end

local function ProfesionDeMiNivel()
  local prof = RUTA.profesiones[GuiaAventureroDB.profesion] or RUTA.profesiones[1]
  local nivel = NivelProfesion(prof)
  inicioOfi, pilaOfi = 1, {}
  if not nivel then return end
  for i = 1, #prof.pasos do
    if nivel < prof.pasos[i].h then inicioOfi = i; return end
  end
  inicioOfi = #prof.pasos
end

-- 7.6.1: red de seguridad. Cada panel recorta lo que se salga de él, para que nada sobresalga del marco.
local function RecortarPaneles()
  for _, m in pairs(GL.modos or {}) do
    local p = type(m) == "table" and m.panel
    if p and p.SetClipsChildren and not p.recortado then p:SetClipsChildren(true); p.recortado = true end
  end
  for _, p in pairs({ ui.panelGuia, ui.panelTal, ui.panelOfi }) do
    if p and p.SetClipsChildren and not p.recortado then p:SetClipsChildren(true); p.recortado = true end
  end
end

local function AbrirModo(modo)
  RecortarPaneles()
  if GuiaAventureroDB.subPersonaje == "estadisticas" then GuiaAventureroDB.subPersonaje = "talentos" end   -- 9.0
  if modo == "personaje" then modo = GuiaAventureroDB.subPersonaje or "talentos" end
  if modo == "estadisticas" then GuiaAventureroDB.vistaCuenta, GuiaAventureroDB.hoyModo, modo = "hoy", "nivel", "cuenta" end   -- 9.0
  -- 9.0: secciones que se crean al abrirlas. 9.4.1: se mira después de traducir "personaje" a su subpestaña
  -- (si la última abierta era Clase, el botón Personaje no la creaba y volvía a la guía)
  if GL.perezosos and GL.perezosos[modo] and not GL.modos[modo] then
    local okP, errP = pcall(GL.perezosos[modo])
    if not okP then
      GL.Fallo("panel " .. tostring(modo), errP)
      Mensaje(GL.L"error al cargar " .. modo .. ": " .. tostring(errP))
    end
  end
  if GL.perezosos and GL.perezosos[modo] and not GL.modos[modo] then modo = "talentos" end
  if (modo == "hechizos" or modo == "equipo" or modo == "estadisticas") and not GL.modos[modo] then
    Mensaje(GL.L"la pestaña " .. modo .. GL.L" no se ha podido crear. Escribe /ga depurar y pega el informe en el hilo.")
    modo = "talentos"
  end
  if GRUPOS[modo] == "personaje" then GuiaAventureroDB.subPersonaje = modo end
  GuiaAventureroDB.modo = modo
  if not LADO[modo] then GuiaAventureroDB.modoGuia = modo end   -- 6.6: el botón Guía vuelve aquí
  if modo == "talentos" then TalentosDeMiNivel() elseif modo == "oficios" then ProfesionDeMiNivel() end
  Refrescar()
end

-- Avanza solo mientras las misiones del paso ya esten hechas, y lleva la flecha al primer destino que falte.
local function Sincronizar()
  local db = GuiaAventureroDB
  if not RUTA or not frame then return end
  if db.auto ~= false and not (bloqueo and bloqueo == db.seccion .. ":" .. db.paso) then
    local saltados = 0
    while saltados < 500 and PuedeSaltar(db.seccion, db.paso) do
      local s, p = PasoDespues(db.seccion, db.paso)
      if not s then break end
      db.seccion, db.paso, db.destino = s, p, 1
      saltados = saltados + 1
    end
    local _, paso = PasoActual()
    local actual = paso and paso.wp and paso.wp[db.destino]
    if actual and (DestinoHecho(actual) or Marcado("pospuestos", actual)) then
      -- el primero que falte y no esté pospuesto; si solo quedan pospuestos, el primero de ellos
      local elegido
      for i = 1, #paso.wp do
        if not DestinoHecho(paso.wp[i]) and not Marcado("pospuestos", paso.wp[i]) then elegido = i; break end
      end
      if not elegido and DestinoHecho(actual) then
        for i = 1, #paso.wp do
          if not DestinoHecho(paso.wp[i]) then elegido = i; break end
        end
      end
      if elegido then db.destino = elegido end
    end
    if saltados == 1 then
      Mensaje(GL.L"paso hecho: pasas al siguiente.")
    elseif saltados > 1 then
      Mensaje(saltados .. GL.L" pasos ya hechos: sigues en " .. RUTA.secciones[db.seccion].titulo .. GL.L", paso " .. db.paso .. ".")
    end
  end
  Refrescar()
end

local syncProgramada = false
local function ProgramarSync()
  if syncProgramada then return end
  syncProgramada = true
  local function Hacer()
    syncProgramada = false
    local ok, err = pcall(Sincronizar)
    if not ok then GL.Fallo("Sincronizar", err) end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.5, Hacer) else Hacer() end
end

local function IrAMiNivel()
  local db = GuiaAventureroDB
  db.seccion = SeccionPorNivel(UnitLevel("player") or 1)
  db.paso = 1
  db.destino = 1
  db.modo = "guia"
  bloqueo = false
  Sincronizar()
end

local function AlternarAuto()
  local db = GuiaAventureroDB
  if db.auto == false then
    db.auto = true
    bloqueo = false
    Mensaje(GL.L"avance automático activado: la guía pasa sola los pasos con las misiones hechas.")
    Sincronizar()
  else
    db.auto = false
    Mensaje(GL.L"avance automático desactivado: usa Siguiente para avanzar.")
  end
end

------------------------------------------------------------------------
-- Flecha
------------------------------------------------------------------------
local function OrientacionJugador()
  if not GetPlayerFacing then return nil end
  local ok, f = pcall(GetPlayerFacing)
  if not ok then return nil end
  return Seguro(f)
end

-- Mapa y posicion (0-1) del jugador.
function GL.NumeroMapaSeguro(v)
  v = Seguro(v)
  if type(v) == "number" and v == v and math.abs(v) < math.huge then return v end
end

local function PosicionJugador()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local ok, mapa, x, y = pcall(function()
    local m = GL.NumeroMapaSeguro(C_Map.GetBestMapForUnit("player"))
    if not m or m <= 0 then return nil end
    local pos = C_Map.GetPlayerMapPosition(m, "player")
    if not Seguro(pos) then return nil end
    local px, py = pos:GetXY()
    return m, GL.NumeroMapaSeguro(px), GL.NumeroMapaSeguro(py)
  end)
  if not ok or not mapa or not x or not y or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then return nil end
  return mapa, x, y
end

-- Punto de un mapa (0-1) en coordenadas del mundo (yardas) y su continente.
local function AMundo(mapa, x, y)
  mapa, x, y = GL.NumeroMapaSeguro(mapa), GL.NumeroMapaSeguro(x), GL.NumeroMapaSeguro(y)
  if not (mapa and mapa > 0 and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok, c, wx, wy = pcall(function()
    local continente, pos = C_Map.GetWorldPosFromMapPos(mapa, CreateVector2D(x, y))
    continente = GL.NumeroMapaSeguro(continente)
    if not continente or not Seguro(pos) then return nil end
    local a, b = pos:GetXY()
    return continente, GL.NumeroMapaSeguro(a), GL.NumeroMapaSeguro(b)
  end)
  if ok and c and wx and wy then return c, wx, wy end
end

-- Direcciones "este" y "sur" de un mapa en el mundo (vectores unitarios), calculadas una vez por mapa.
local ejesMapa = {}
local function Ejes(mapa)
  local e = ejesMapa[mapa]
  if e == nil then
    e = false
    -- Se usan puntos a media distancia: en algunos mapas el borde (1, 1) se traduce mal.
    local c0, x0, y0 = AMundo(mapa, 0, 0)
    local c1, x1, y1 = AMundo(mapa, 0.5, 0)
    local c2, x2, y2 = AMundo(mapa, 0, 0.5)
    if c0 and c0 == c1 and c0 == c2 then
      local ex, ey = x1 - x0, y1 - y0
      local sx, sy = x2 - x0, y2 - y0
      local le = math.sqrt(ex * ex + ey * ey)
      local ls = math.sqrt(sx * sx + sy * sy)
      if le > 0 and ls > 0 then e = { ex / le, ey / le, sx / ls, sy / ls } end
    end
    if e then ejesMapa[mapa] = e end
  end
  return e or nil
end

-- Devuelve este, sur (yardas) y distancia del jugador al destino; o nil y un motivo.
local function Vector(d)
  local mapa, px, py = PosicionJugador()
  if not mapa then return nil, "sinpos" end
  local cj, jx, jy = AMundo(mapa, px, py)
  local cd, dx, dy = AMundo(d.m, d.x / 100, d.y / 100)
  local ejes = Ejes(mapa)
  if cj and cd and ejes then
    if cj ~= cd then return nil, "continente" end
    local vx, vy = dx - jx, dy - jy
    local este = vx * ejes[1] + vy * ejes[2]
    local sur = vx * ejes[3] + vy * ejes[4]
    return este, sur, math.sqrt(vx * vx + vy * vy), mapa ~= d.m
  end
  if mapa == d.m then
    local tam = TAMANO_ZONA[d.z] or { 1500, 1000 }
    local este = (d.x / 100 - px) * tam[1]
    local sur = (d.y / 100 - py) * tam[2]
    return este, sur, math.sqrt(este * este + sur * sur), false
  end
  return nil, "zona"
end

-- Al llegar a un PNJ sin mision (instructor, maestro de vuelo, vendedor...), la flecha pasa sola al siguiente
-- destino del paso que falte. Una sola vez por destino: si luego lo eliges a mano, la flecha se queda en el.
local llegados = {}
local function LlegadaAPnj(d)
  local db = GuiaAventureroDB
  if db.autoDestino == false then return false end   -- automatismo "Siguiente destino al llegar"
  if not d.npc or d.q then return false end
  local clave = db.seccion .. ":" .. db.paso .. ":" .. db.destino
  if llegados[clave] then return false end
  llegados[clave] = true
  local _, p = PasoActual()
  if not p or not p.wp then return false end
  for i = db.destino + 1, #p.wp do
    if DestinoHecho(p.wp[i]) ~= true then
      db.destino = i
      Refrescar()
      return true
    end
  end
  return false
end

-- El borde de la flecha cambia de color segun lo cerca que estes del destino.
local function BordeFlecha(c)
  if flecha and flecha.SetBackdropBorderColor then
    flecha:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
  end
end

-- Si el cliente no puede girar la imagen (SetRotation), la flecha dice el rumbo con palabras.
local RUMBOS_RELATIVOS = { "delante", GL.L"delante a la derecha", GL.L"a la derecha", GL.L"detrás a la derecha", GL.L"detrás",
  GL.L"detrás a la izquierda", GL.L"a la izquierda", GL.L"delante a la izquierda" }
local RUMBOS_BRUJULA = { "norte", "nordeste", "este", "sudeste", "sur", "suroeste", "oeste", "noroeste" }

-- rel: angulo en radianes, en sentido horario, desde delante (o desde el norte si no se sabe hacia donde miras).
local function RumboEnPalabras(rel, conBrujula)
  local lista = conBrujula and RUMBOS_BRUJULA or RUMBOS_RELATIVOS
  local sector = math.floor(rel / (math.pi / 4) + 0.5) % 8
  return lista[sector + 1]
end

local RUMBOS8 = { GL.L"al norte", GL.L"al noreste", GL.L"al este", GL.L"al sureste", GL.L"al sur", GL.L"al suroeste", GL.L"al oeste", GL.L"al noroeste" }
local function ActualizarFlecha()
  flecha.estado = nil   -- 8.8: lo que necesita Graficos.lua (anillo y estilos de flecha)
  flecha.dist:SetText("")
  BordeFlecha(COLOR.flechaBorde)
  local d = DestinoActual()
  if not d then
    flecha.tex:Hide()
    flecha.texto:SetText(GRIS .. GL.L"Sin destino en este paso" .. FIN)
    return
  end
  local este, sur, dist, otroMapa = Vector(d)
  if not este then
    flecha.tex:Hide()
    if sur == "continente" then
      flecha.texto:SetText(AMARILLO .. GL.L"Ve a " .. d.z .. FIN .. GL.L" (otro continente)\n" .. GRIS .. d.n .. FIN)
    elseif sur == "zona" then
      flecha.texto:SetText(AMARILLO .. GL.L"Ve a " .. d.z .. FIN .. "\n" .. GRIS .. d.n .. FIN)
    else
      flecha.texto:SetText(GRIS .. GL.L"Sin posición (cueva o mazmorra)" .. FIN .. "\n" .. d.z .. " " .. string.format("%.1f, %.1f", d.x, d.y))
    end
    return
  end

  if dist < LLEGADA then
    if LlegadaAPnj(d) then return end
    flecha.tex:Hide()
    BordeFlecha(COLOR.verde)
    flecha.estado = { d = d, dist = dist, llegado = true }
    flecha.dist:SetText(VERDE .. GL.L"¡Has llegado!" .. FIN)
    flecha.texto:SetText(GRIS .. d.n .. FIN)
    if GL.AlLlegar then pcall(GL.AlLlegar, d) end   -- 7.2: sonido al llegar (una vez por destino)
    return
  end

  local angulo = math.atan2(este, -sur)          -- desde el norte, en sentido horario
  local orient = OrientacionJugador()            -- 0 = norte, crece hacia la izquierda
  local rel = angulo
  if orient then rel = angulo + orient end
  local dosPi = 2 * math.pi
  rel = rel % dosPi
  -- flecha.tga es una sola flecha que apunta hacia arriba: se gira (SetRotation va en sentido antihorario)
  local girada = false
  if flecha.puedeGirar then girada = pcall(flecha.tex.SetRotation, flecha.tex, -rel) end
  if girada then flecha.tex:Show() else flecha.tex:Hide() end

  -- la distancia cambia de color al acercarte; 7.1: la flecha también (verde cerca, amarilla a media distancia, roja lejos)
  local colorDist = BLANCO
  local cd = GL.COLORES_DIST   -- 9.0: el modo daltónico los cambia
  local r, g, b = cd.lejos[1], cd.lejos[2], cd.lejos[3]
  if dist < 60 then
    colorDist = GL.colores.VERDE; BordeFlecha(COLOR.verde); r, g, b = cd.cerca[1], cd.cerca[2], cd.cerca[3]
  elseif dist < 300 then
    colorDist = AMARILLO; BordeFlecha(COLOR.acento); r, g, b = cd.medio[1], cd.medio[2], cd.medio[3]
  end
  if GuiaAventureroDB.flechaColor == false then r, g, b = 1, 1, 1 end
  flecha.tex:SetVertexColor(r, g, b)
  flecha.estado = { d = d, dist = dist, rel = rel, orient = orient, girada = girada, r = r, g = g, b = b }
  local donde = GRIS .. d.n .. FIN
  if otroMapa then donde = donde .. "\n" .. AMARILLO .. d.z .. FIN end
  if girada then
    if not orient then donde = donde .. "\n" .. GRIS .. GL.L"(norte arriba)" .. FIN end
  else
    donde = AMARILLO .. RumboEnPalabras(rel, not orient) .. FIN .. "\n" .. donde
  end
  local rumbo = RUMBOS8[math.floor(((angulo % dosPi) + math.pi / 8) / (math.pi / 4)) % 8 + 1]   -- 7.1: rumbo de brújula
  flecha.dist:SetText(colorDist .. string.format("%d m", math.floor(dist * 0.9144)) .. FIN .. GRIS .. " · " .. rumbo .. FIN)   -- 6.0.2: en metros (1 yarda = 0,9144 m)
  if destinoExtra then BordeFlecha(COLOR.cian) end   -- 6.2: desvío, en azul
  flecha.texto:SetText(destinoExtra and (AZUL .. GL.L"Desvío" .. FIN .. "\n" .. donde) or donde)
end

-- 7.9.8: el marco de la flecha se pone en píxeles enteros de la pantalla. Con la escala de la interfaz, un borde
-- de 1 unidad podía caer entre dos píxeles y no dibujarse (faltaba la raya de arriba).
local function FlechaAlPixel()
  if not flecha or not GetPhysicalScreenSize then return false end
  local _, alto = GetPhysicalScreenSize()
  local escala = flecha:GetEffectiveScale()
  local l, t = flecha:GetLeft(), flecha:GetTop()
  if not alto or alto <= 0 or not escala or escala <= 0 or not l or not t then return false end
  local u = 768 / alto / escala   -- un píxel de la pantalla, en unidades de la flecha
  local function Redondo(v) return math.floor(v / u + 0.5) * u end
  flecha:ClearAllPoints()
  flecha:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", Redondo(l), Redondo(t))
  flecha:SetWidth(Redondo(190)); flecha:SetHeight(Redondo(134))
  if flecha.SetBackdrop then
    local r, g, b, a = flecha:GetBackdropBorderColor()
    local fr, fg, fb, fa = flecha:GetBackdropColor()
    flecha:SetBackdrop({ bgFile = BLANCO8, edgeFile = BLANCO8, edgeSize = u })
    flecha:SetBackdropColor(fr or 0, fg or 0, fb or 0, fa or 1)
    flecha:SetBackdropBorderColor(r or 1, g or 1, b or 1, a or 1)
  end
  return true
end
GL.FlechaAlPixel = function() if flecha then flecha.alPixel = false end end

local function CrearFlecha()
  flecha = CreateFrame("Frame", "GuiaAventureroFlecha", UIParent, PLANTILLA)
  flecha:SetWidth(190)
  flecha:SetHeight(134)
  Caja(flecha, COLOR.flechaFondo, COLOR.flechaBorde)
  flecha:SetFrameStrata("MEDIUM")
  flecha:SetMovable(true)
  flecha:EnableMouse(true)
  flecha:SetClampedToScreen(true)
  flecha:RegisterForDrag("LeftButton")
  flecha:SetScript("OnDragStart", function(self)
    if not GuiaAventureroDB.bloqueada then self:StartMoving() end
  end)
  flecha:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    pcall(FlechaAlPixel)
    local p, _, rp, x, y = self:GetPoint()
    GuiaAventureroDB.posFlecha = { p, rp, x, y }
  end)
  local db = GuiaAventureroDB
  if db.posFlecha then
    flecha:SetPoint(db.posFlecha[1], UIParent, db.posFlecha[2], db.posFlecha[3], db.posFlecha[4])
  else
    flecha:SetPoint("TOP", UIParent, "TOP", 0, -120)
  end

  flecha.tex = flecha:CreateTexture(nil, "ARTWORK")
  flecha.tex:SetTexture(RUTA_FLECHA)
  flecha.puedeGirar = flecha.tex.SetRotation ~= nil
  flecha.tex:SetWidth(56)
  flecha.tex:SetHeight(56)
  flecha.tex:SetPoint("TOP", flecha, "TOP", 0, -10)

  -- distancia en grande y, debajo, el nombre del destino
  flecha.dist = flecha:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  flecha.dist:SetPoint("TOP", flecha.tex, "BOTTOM", 0, -4)
  flecha.dist:SetWidth(176)
  flecha.dist:SetHeight(18)
  flecha.dist:SetJustifyH("CENTER")
  flecha.dist:SetShadowOffset(1, -1)
  flecha.dist:SetShadowColor(0, 0, 0, 1)

  flecha.texto = flecha:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  flecha.texto:SetPoint("TOP", flecha.dist, "BOTTOM", 0, -2)
  flecha.texto:SetWidth(176)
  flecha.texto:SetJustifyH("CENTER")
  flecha.texto:SetJustifyV("TOP")
  flecha.texto:SetShadowOffset(1, -1)
  flecha.texto:SetShadowColor(0, 0, 0, 1)

  local acumulado = 0
  flecha:SetScript("OnUpdate", function(self, elapsed)
    acumulado = acumulado + (elapsed or 0)
    if acumulado < 0.1 then return end
    acumulado = 0
    if not flecha.alPixel then
      local okP, hecho = pcall(FlechaAlPixel); flecha.alPixel = okP and hecho
      if not okP then GL.Fallo("FlechaAlPixel", hecho) end
    end
    local ok, err = pcall(ActualizarFlecha)
    if not ok then GL.Fallo("ActualizarFlecha", err) end
    if GL.TrasFlecha then
      local okT, errT = pcall(GL.TrasFlecha, flecha)
      if not okT then GL.Fallo("TrasFlecha", errT) end
    end   -- 8.8: anillo de cercanía y estilos
    if not ok then
      flecha.tex:Hide()
      flecha.texto:SetText(GRIS .. GL.L"Flecha no disponible ahora" .. FIN)
    end
  end)

  if db.flecha == false then flecha:Hide() end
end

local function AlternarFlecha()
  if flecha:IsShown() then
    flecha:Hide(); GuiaAventureroDB.flecha = false
  else
    flecha:Show(); GuiaAventureroDB.flecha = true
  end
  if ui.botonFlecha then ui.botonFlecha:SetActivo(flecha:IsShown()) end
end

------------------------------------------------------------------------
-- Ventana principal
------------------------------------------------------------------------
local function NuevoPanel()
  local p = CreateFrame("Frame", nil, frame)
  p:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -ARRIBA)
  p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -MARGEN, ABAJO)
  return p
end

local function CrearPanelGuia()
  local p = NuevoPanel()
  ui.panelGuia = p
  ui.despGuia = GL.Desplazable(p)   -- 7.9.2: si la ventana es pequeña, se baja con la rueda

  ui.zona = Texto(p, "GameFontNormalLarge")
  ui.zona:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  ui.zona:SetPoint("TOPRIGHT", p, "TOPRIGHT", -58, 0)
  UnaLinea(ui.zona)
  ui.niveles = Texto(p, "GameFontHighlightSmall")
  ui.niveles:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -21)
  ui.niveles:SetPoint("TOPRIGHT", p, "TOPRIGHT", -58, -21)
  UnaLinea(ui.niveles)
  -- 9.1: < y > abren la vista previa de la sección (no mueven tu progreso); con Mayús cambian de sección como antes
  local function VerSeccion(delta)
    if GL.VistaPrevia and not (IsShiftKeyDown and IsShiftKeyDown()) then GL.VistaPrevia(GuiaAventureroDB.seccion + delta) else CambiarSeccion(delta) end
  end
  local secSig = CrearBoton(p, ">", function() VerSeccion(1) end)
  secSig:SetWidth(26)
  secSig:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -4)
  Ayuda(secSig, GL.L"Sección siguiente", GL.L"Clic: verla sin mover tu progreso. Mayús+clic: ir a ella.")
  local secAnt = CrearBoton(p, "<", function() VerSeccion(-1) end)
  secAnt:SetWidth(26)
  secAnt:SetPoint("RIGHT", secSig, "LEFT", -4, 0)
  Ayuda(secAnt, GL.L"Sección anterior", GL.L"Clic: verla sin mover tu progreso. Mayús+clic: ir a ella.")

  ui.progreso = CrearBarra(p, 0.30, 0.72, 0.92)
  ui.progreso:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -40)
  ui.progreso:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -40)

  ui.nav[1] = CrearBoton(p, GL.L"< Anterior", Anterior, nil, 24)
  ui.nav[2] = CrearBoton(p, GL.L"Mi nivel", IrAMiNivel, nil, 24)
  ui.nav[3] = CrearBoton(p, GL.L"Siguiente >", Siguiente, nil, 24, "accion")
  Encadenar(ui.nav, p, 0, -60)

  ui.caja = CreateFrame("Frame", nil, p, PLANTILLA)
  ui.caja:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -Y_CAJA)
  ui.caja:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -Y_CAJA)
  ui.caja:SetHeight(80)
  Caja(ui.caja, COLOR.caja, COLOR.cajaBorde)
  -- raya de color a la izquierda: dorada en curso, verde hecha, gris sin misiones
  ui.caja.raya = ui.caja:CreateTexture(nil, "ARTWORK")
  ui.caja.raya:SetWidth(3)
  ui.caja.raya:SetPoint("TOPLEFT", ui.caja, "TOPLEFT", 0, 0)
  ui.caja.raya:SetPoint("BOTTOMLEFT", ui.caja, "BOTTOMLEFT", 0, 0)
  ui.caja.raya:SetColorTexture(Color(COLOR.acento))
  ui.pasoNum = Texto(ui.caja, "GameFontNormalSmall")
  ui.pasoNum:SetPoint("TOPLEFT", ui.caja, "TOPLEFT", 14, -8)
  ui.pasoEstado = Texto(ui.caja, "GameFontNormalSmall", "RIGHT")
  ui.pasoEstado:SetPoint("TOPRIGHT", ui.caja, "TOPRIGHT", -10, -8)
  ui.pasoTexto = Texto(ui.caja, "GameFontHighlight")
  ui.pasoTexto:SetPoint("TOPLEFT", ui.caja, "TOPLEFT", 14, -26)
  -- 7.4: nota propia del jugador en cada paso
  ui.notaBoton = CrearBoton(ui.caja, GL.L"Nota", function() if GL.EditarNota then GL.EditarNota() end end, nil, 16)
  ui.notaBoton:SetWidth(44)
  ui.notaBoton:SetPoint("RIGHT", ui.pasoEstado, "LEFT", -8, 0)
  -- 9.4.2: «En curso» con su ancho (antes «Nota» se le montaba encima) y «Paso n de m · tipo» se corta
  -- antes de los botones Leer y Nota en lugar de pasar por debajo
  ui.pasoEstado:SetWidth(72)
  if ui.pasoEstado.SetWordWrap then ui.pasoEstado:SetWordWrap(false) end
  ui.pasoNum:SetPoint("RIGHT", ui.notaBoton, "LEFT", -50, -4)   -- -4: deja alto de sobra a la línea
  UnaLinea(ui.pasoNum)
  Ayuda(ui.notaBoton, GL.L"Nota", GL.L"Escribe tu propia nota para este paso. Se guarda en este personaje.")
  ui.notaTexto = Texto(ui.caja, "GameFontHighlightSmall")
  ui.notaTexto:Hide()
  ui.cabAvisos = Texto(p, "GameFontHighlightSmall")
  ui.cabAvisos:Hide()
  -- el texto del paso es lo que mas se lee jugando: un poco mas grande y con mas aire entre lineas
  local fuentePaso, _, opcionesPaso = ui.pasoTexto:GetFont()
  ui.fuentePaso, ui.opcionesPaso = fuentePaso, opcionesPaso
  if fuentePaso then ui.pasoTexto:SetFont(fuentePaso, TamTextoPaso(), opcionesPaso) end
  -- destello breve al cambiar de paso
  ui.caja.destello = ui.caja:CreateTexture(nil, "OVERLAY")
  ui.caja.destello:SetAllPoints()
  PorTema(function() ui.caja.destello:SetColorTexture(COLOR.acento[1], COLOR.acento[2], COLOR.acento[3], 0.22) end)
  ui.caja.destello:SetAlpha(0)
  if ui.caja.destello.CreateAnimationGroup then
    local ag = ui.caja.destello:CreateAnimationGroup()
    local entra = ag:CreateAnimation("Alpha")
    entra:SetFromAlpha(0); entra:SetToAlpha(1); entra:SetDuration(0.12); entra:SetOrder(1)
    local sale = ag:CreateAnimation("Alpha")
    sale:SetFromAlpha(1); sale:SetToAlpha(0); sale:SetDuration(0.45); sale:SetOrder(2)
    ag:SetScript("OnFinished", function() ui.caja.destello:SetAlpha(0) end)
    ui.caja.destello.anim = ag
  end
  if ui.pasoTexto.SetSpacing then ui.pasoTexto:SetSpacing(2) end

  for i = 1, MAX_DESTINOS do
    local f = CreateFrame("Button", nil, p)
    f:SetHeight(ALTO_DESTINO)
    f.par = f:CreateTexture(nil, "BACKGROUND")
    f.par:SetAllPoints()
    f.par:SetColorTexture(1, 1, 1, 0.035)
    f.elegido = f:CreateTexture(nil, "BACKGROUND")
    f.elegido:SetAllPoints()
    PorTema(function() f.elegido:SetColorTexture(Color(COLOR.elegido)) end)
    f.raya = f:CreateTexture(nil, "BORDER")
    f.raya:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.raya:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.raya:SetWidth(2)
    PorTema(function() f.raya:SetColorTexture(Color(COLOR.acento)) end)
    local brillo = f:CreateTexture(nil, "HIGHLIGHT")
    brillo:SetAllPoints()
    brillo:SetColorTexture(1, 1, 1, 0.06)
    f.icono = f:CreateTexture(nil, "ARTWORK")
    f.icono:SetWidth(14)
    f.icono:SetHeight(14)
    f.icono:SetPoint("LEFT", f, "LEFT", 6, 0)
    f.coords = Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.coords:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    f.coords:SetWidth(64)   -- columna fija: las coordenadas quedan alineadas
    -- progreso de la mision (3/4) o "lista" para entregar, entre el nombre y las coordenadas
    f.progreso = Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.progreso:SetPoint("RIGHT", f.coords, "LEFT", -8, 0)
    UnaLinea(f.progreso)
    f.texto = Texto(f, "GameFontHighlightSmall")
    f.texto:SetPoint("LEFT", f.icono, "RIGHT", 6, 0)
    f.texto:SetPoint("RIGHT", f.progreso, "LEFT", -6, 0)
    UnaLinea(f.texto)
    f:SetScript("OnClick", function(self)
      -- 6.1: el clic abre (o cierra) los botones Seguir, Posponer e Ignorar debajo del objetivo
      local e = self.entrada
      if not e then return end
      if IsShiftKeyDown and IsShiftKeyDown() and e.d.q and GL.EnlazarMision and GL.EnlazarMision(e.d) then return end   -- 7.2
      local clave = ClaveDestino(e.d)
      ui.sel = (ui.sel ~= clave) and clave or nil
      Refrescar()
    end)
    Ayuda(f)
    ui.destinos[i] = f
  end
  ui.sinDestino = Texto(p, "GameFontHighlightSmall")
  ui.sinDestino:SetText(GRIS .. GL.L"Este paso no tiene destino para la flecha." .. FIN)

  -- 6.2: barra de desvío y aviso de "te has desviado"
  local desvio = CreateFrame("Frame", nil, p, PLANTILLA)
  desvio:SetHeight(24)
  Caja(desvio, { 0.41, 0.80, 0.94, 0.08 }, { 0.41, 0.80, 0.94, 0.5 })
  desvio.boton = CrearBoton(desvio, GL.L"Volver a mi paso", function()
    destinoExtra = nil
    Refrescar()
  end, nil, 18)
  desvio.boton:SetWidth(108)
  desvio.boton:SetPoint("RIGHT", desvio, "RIGHT", -4, 0)
  Ayuda(desvio.boton, GL.L"Volver a mi paso", GL.L"La flecha vuelve al destino de tu paso.")
  desvio.texto = Texto(desvio, "GameFontHighlightSmall")
  desvio.texto:SetPoint("LEFT", desvio, "LEFT", 8, 0)
  desvio.texto:SetPoint("RIGHT", desvio.boton, "LEFT", -6, 0)
  UnaLinea(desvio.texto)
  desvio:Hide()
  ui.desvio = desvio

  local aviso = CreateFrame("Frame", nil, p, PLANTILLA)
  aviso:SetHeight(70)
  PorTema(function() Caja(aviso, { COLOR.acento[1], COLOR.acento[2], COLOR.acento[3], 0.08 }, { COLOR.acento[1], COLOR.acento[2], COLOR.acento[3], 0.55 }) end)
  aviso.texto = Texto(aviso, "GameFontHighlightSmall")
  aviso.texto:SetPoint("TOPLEFT", aviso, "TOPLEFT", 9, -7)
  if aviso.texto.SetSpacing then aviso.texto:SetSpacing(2) end
  local avisoBotones = {}
  avisoBotones[1] = CrearBoton(aviso, GL.L"Retomar ahí", function()
    local r = aviso.retomar
    if not r then return end
    local db = GuiaAventureroDB
    db.seccion, db.paso, db.destino = r.s, r.p, r.i
    destinoExtra = nil
    bloqueo = false
    Refrescar()
  end, nil, 20, "accion")
  Ayuda(avisoBotones[1], GL.L"Retomar ahí", GL.L"La guía salta a ese paso, que está en la zona donde estás.")
  avisoBotones[2] = CrearBoton(aviso, GL.L"Seguir con mi paso", function()
    ui.zonaDescartada = (GetZoneText and GetZoneText()) or ""
    Refrescar()
  end, nil, 20)
  Ayuda(avisoBotones[2], GL.L"Seguir con mi paso", GL.L"No vuelve a avisar mientras sigas en esta zona.")
  avisoBotones[1]:SetPoint("BOTTOMLEFT", aviso, "BOTTOMLEFT", 8, 7)
  avisoBotones[2]:SetPoint("LEFT", avisoBotones[1], "RIGHT", 4, 0)
  aviso:SetScript("OnSizeChanged", function(self)
    local w = math.floor(((self:GetWidth() or 300) - 20) / 2)
    avisoBotones[1]:SetWidth(w); avisoBotones[2]:SetWidth(w)
  end)
  avisoBotones[1]:SetWidth(150); avisoBotones[2]:SetWidth(150)
  aviso.btnRetomar = avisoBotones[1]   -- 9.6: sin paso que retomar (otro continente) solo queda «Seguir con mi paso»
  aviso:Hide()
  ui.aviso = aviso

  -- 6.3: tarjeta de preparación antes de dejar la zona
  local prep = CreateFrame("Frame", nil, p, PLANTILLA)
  Caja(prep, { 0.25, 0.85, 0.35, 0.07 }, { 0.25, 0.85, 0.35, 0.5 })
  prep.titulo = Texto(prep, "GameFontNormalSmall")
  prep.titulo:SetPoint("TOPLEFT", prep, "TOPLEFT", 9, -7)
  prep.sig = Texto(prep, "GameFontHighlightSmall", "RIGHT")
  prep.sig:SetPoint("TOPRIGHT", prep, "TOPRIGHT", -9, -7)
  prep.lineas = {}
  for i = 1, 8 do
    local l = {}
    l.texto = Texto(prep, "GameFontHighlightSmall")
    l.boton = CrearBoton(prep, GL.L"Seguir", function(self)
      local b = prep.lineas[i].boton
      if b.destino and GL.SeguirDesvio then GL.SeguirDesvio(b.destino) end
    end, nil, 18)
    l.boton:SetWidth(56)
    Ayuda(l.boton, GL.L"Seguir", GL.L"La flecha va ahí como desvío, sin cambiar tu paso.")
    prep.lineas[i] = l
  end
  prep.entendido = CrearBoton(prep, GL.L"Entendido", function()
    local _, pa = PasoActual()
    ui.prepDescartada = (pa and pa.wp and pa.wp[1] and pa.wp[1].z) or ui.prepDescartada
    ui.prepForzada = nil
    Refrescar()
  end, nil, 18)
  prep.entendido:SetWidth(80)
  prep.entendido:SetPoint("BOTTOMRIGHT", prep, "BOTTOMRIGHT", -8, 6)
  Ayuda(prep.entendido, GL.L"Entendido", GL.L"Cierra este aviso hasta que vayas a dejar otra zona.")
  prep:Hide()
  ui.prep = prep

  -- 6.1: títulos de los grupos de objetivos y botones del objetivo pulsado
  ui.grupos = {}
  for g = 1, 3 do
    ui.grupos[g] = Texto(p, "GameFontHighlightSmall")
    ui.grupos[g]:Hide()
  end
  local acc = CreateFrame("Frame", nil, p)
  acc:SetHeight(18)
  acc:SetWidth(240)
  acc:Hide()
  ui.acciones = acc
  local function Hecho()
    ui.sel = nil
    Refrescar()
    ProgramarSync()
  end
  acc.seguir = CrearBoton(acc, GL.L"Seguir", function()
    local e = acc.entrada
    if not e then return end
    if e.i then
      Marcar("pospuestos", e.d, false)
      GuiaAventureroDB.destino = e.i
      destinoExtra = nil
    else
      destinoExtra = e.d          -- Cerca de ti: la flecha va ahí sin cambiar de paso
    end
    ui.sel = nil
    Refrescar()
  end, nil, 18, "accion")
  acc.seguir:SetWidth(62)
  acc.seguir:SetPoint("LEFT", acc, "LEFT", 0, 0)
  Ayuda(acc.seguir, GL.L"Seguir", GL.L"La flecha te lleva a este objetivo.")
  acc.posponer = CrearBoton(acc, GL.L"Posponer", function()
    local e = acc.entrada
    if not e or not e.i then return end
    Marcar("pospuestos", e.d, true)
    Hecho()
  end, nil, 18)
  acc.posponer:SetWidth(70)
  acc.posponer:SetPoint("LEFT", acc.seguir, "RIGHT", 4, 0)
  Ayuda(acc.posponer, GL.L"Posponer", GL.L"Lo deja para el final del paso: la flecha va antes a lo demás.")
  acc.ignorar = CrearBoton(acc, GL.L"Ignorar", function()
    local e = acc.entrada
    if not e then return end
    if Marcado("ignorados", e.d) then
      Marcar("ignorados", e.d, false)
    else
      Marcar("ignorados", e.d, true)
      Marcar("pospuestos", e.d, false)
      if destinoExtra == e.d then destinoExtra = nil end
      Mensaje(GL.L"objetivo ignorado: cuenta como hecho en este personaje. /ga ignorados lo deshace.")
    end
    Hecho()
  end, nil, 18)
  acc.ignorar:SetWidth(74)
  Ayuda(acc.ignorar, GL.L"Ignorar", GL.L"Lo da por hecho en este personaje. /ga ignorados los recupera todos.")

  ui.info[1] = CrearBoton(p, GL.L"+  Consejos de la sección", function()
    GuiaAventureroDB.consejosAbiertos = not GuiaAventureroDB.consejosAbiertos
    Refrescar()
  end, nil, 20)
  Ayuda(ui.info[1], GL.L"Consejos de la sección", GL.L"Hechizos que entrenar, equipo y profesiones para esta parte de la ruta. Clic para abrir o cerrar.")
  ui.infoTexto = Texto(p, "GameFontHighlightSmall")
end

-- Pie de una lista con paginas: texto y botones < Página, Mi nivel, Página >.
local function CrearPie(p, botones, pagina, irANivel, rueda)
  botones[1] = CrearBoton(p, GL.L"< Página", function() pagina(-1) end)
  botones[2] = CrearBoton(p, GL.L"Mi nivel", function() irANivel(); Refrescar() end)
  botones[3] = CrearBoton(p, GL.L"Página >", function() pagina(1) end)
  botones[1]:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
  botones[2]:SetPoint("LEFT", botones[1], "RIGHT", 6, 0)
  botones[3]:SetPoint("LEFT", botones[2], "RIGHT", 6, 0)
  -- 9.4.2: la lista se mueve con la rueda del ratón; de los botones solo queda «Mi nivel»
  if rueda then
    botones[1]:Hide(); botones[3]:Hide()
    botones[2]:ClearAllPoints()
    botones[2]:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta) rueda(delta) end)
  end
  local t = Texto(p, "GameFontHighlightSmall")
  t:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 2, 28)
  return t
end

local function CrearFilas(p, filas, lado)
  for i = 1, MAX_FILAS do
    local f = CreateFrame("Frame", nil, p)
    f:SetHeight(lado + 4)
    if i > 1 then
      f:SetPoint("TOPLEFT", filas[i - 1], "BOTTOMLEFT", 0, -HUECO)
      f:SetPoint("TOPRIGHT", filas[i - 1], "BOTTOMRIGHT", 0, -HUECO)
    end
    -- filas alternas con un tono muy suave
    f.zebra = f:CreateTexture(nil, "BACKGROUND")
    f.zebra:SetAllPoints()
    f.zebra:SetColorTexture(1, 1, 1, 0.03)
    if i % 2 == 1 then f.zebra:Hide() end
    f.fondo = f:CreateTexture(nil, "BACKGROUND")
    f.fondo:SetAllPoints()
    f.fondo:SetColorTexture(Color(COLOR.actual))
    -- raya verde a la izquierda de la fila que toca ahora
    f.raya = f:CreateTexture(nil, "BORDER")
    f.raya:SetWidth(3)
    f.raya:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.raya:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.raya:SetColorTexture(Color(COLOR.verde))
    f.raya:Hide()
    f.marco = CrearMarcoIcono(f, lado)
    f.marco:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -2)
    filas[i] = f
  end
end

local function CrearPanelTalentos()
  local p = NuevoPanel()
  p:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(ARRIBA + ALTO_SUB))   -- debajo de las subpestañas
  ui.panelTal = p

  -- puntos por rama (solo las ramas que usa el plan o que tienen plan de especialización, 9.7.7.1)
  local ramas = RUTA.ramas or {}
  local conPlan = {}
  for _, e in ipairs((GL.ESPECIALIZACIONES or {})[select(2, UnitClass("player")) or ""] or {}) do
    if e.plan then conPlan[GL.L(e.rama)] = true end
  end
  for i = 1, #ramas do
    local r = ramas[i]
    if PuntosRama(r.nombre, 60) > 0 or conPlan[r.nombre] then
      local chip = CreateFrame("Frame", nil, p, PLANTILLA)
      chip:SetHeight(30)
      Caja(chip, COLOR.caja, COLOR.cajaBorde)
      chip.icono = chip:CreateTexture(nil, "ARTWORK")
      chip.icono:SetWidth(22)
      chip.icono:SetHeight(22)
      chip.icono:SetPoint("LEFT", chip, "LEFT", 4, 0)
      PonerIcono(chip.icono, r.icono)
      chip.texto = Texto(chip, "GameFontHighlightSmall")
      chip.texto:SetPoint("LEFT", chip.icono, "RIGHT", 6, 0)
      chip.texto:SetPoint("RIGHT", chip, "RIGHT", -4, 0)   -- 9.5: nombre arriba y puntos debajo, para que no se corten
      if chip.texto.SetSpacing then chip.texto:SetSpacing(1) end
      chip.rama = r
      table.insert(ui.ramas, chip)
    end
  end
  Encadenar(ui.ramas, p, 0, 0)
  -- botón para gastar ya los puntos libres siguiendo el plan (lo hace Talentos.lua)
  ui.ponerTal = CrearBoton(p, GL.L"Poner talentos", function() if GL.PonerTalentos then GL.PonerTalentos(true) end end, nil, 30, "accion")
  ui.ponerTal:SetWidth(ANCHO_PONER_TAL)
  ui.ponerTal:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  Ayuda(ui.ponerTal, GL.L"Poner talentos", GL.L"Gasta los puntos de talento que tengas libres siguiendo el plan de la guía. " ..
    GL.L"Con la opción automática se hace solo al subir de nivel.")
  ui.talResumen = Texto(p, "GameFontHighlightSmall")
  ui.talResumen:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -36)

  CrearFilas(p, ui.filasTal, 34)
  for i = 1, MAX_FILAS do
    local f = ui.filasTal[i]
    -- puntos sobre el icono, como en la ventana de talentos del juego
    local insignia = CreateFrame("Frame", nil, f.marco)
    insignia:SetAllPoints(f.marco)
    -- 9.5: cifras con la fuente de números del juego (con contorno), en una placa oscura con borde que sobresale
    -- un poco por la esquina, para que se lean sobre los iconos claros
    f.puntos = insignia:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if NumberFontNormal then pcall(f.puntos.SetFontObject, f.puntos, NumberFontNormal) end
    f.puntos:SetPoint("BOTTOMRIGHT", f.marco, "BOTTOMRIGHT", 3, -2)
    local bordePuntos = insignia:CreateTexture(nil, "BACKGROUND")
    bordePuntos:SetPoint("TOPLEFT", f.puntos, "TOPLEFT", -3, 2)
    bordePuntos:SetPoint("BOTTOMRIGHT", f.puntos, "BOTTOMRIGHT", 3, -2)
    bordePuntos:SetColorTexture(0.45, 0.45, 0.5, 0.9)
    local fondoPuntos = insignia:CreateTexture(nil, "BORDER")
    fondoPuntos:SetPoint("TOPLEFT", bordePuntos, "TOPLEFT", 1, -1)
    fondoPuntos:SetPoint("BOTTOMRIGHT", bordePuntos, "BOTTOMRIGHT", -1, 1)
    fondoPuntos:SetColorTexture(0, 0, 0, 0.92)
    f.nivel = Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.nivel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.titulo = Texto(f, "GameFontNormal")
    f.titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 44, -3)
    f.nota = Texto(f, "GameFontHighlightSmall")
    f.nota:SetPoint("TOPLEFT", f.titulo, "BOTTOMLEFT", 0, -2)
  end
  ui.talPagina = CrearPie(p, ui.pagTal, PaginaTal, TalentosDeMiNivel, RuedaTal)
end

-- 9.5: profesiones secundarias, como las agrupa el juego
-- (en GL y no en locales: GuiaAventurero.lua está en el tope de 200 locales)
GL.OFI = { secundaria = { [129] = true, [185] = true, [356] = true, [40] = true }, fila = 30, titulo = 78 }

-- 9.5: botones de las profesiones que has aprendido; se rehacen cuando aprendes o olvidas una
GL.OFI.botones = function(p)
  for _, b in ipairs(ui.oficios) do b:Hide() end
  ui.oficios, ui.ofiPri, ui.ofiSec = {}, {}, {}
  for i = 1, #RUTA.profesiones do
    local indice = i
    local prof = RUTA.profesiones[i]
    if not prof.vacia then
      -- corto: nombre para el botón cuando el entero no cabe (el entero sale al elegirla)
      local b = CrearBoton(p, prof.corto or prof.nombre, function()
        GuiaAventureroDB.profesion = indice
        GuiaAventureroDB.profesionSkill = prof.skill
        ProfesionDeMiNivel()
        Refrescar()
      end, prof.icono, 26)
      ui.oficios[i] = b
      table.insert(GL.OFI.secundaria[prof.skill] and ui.ofiSec or ui.ofiPri, b)
    end
  end
  Mostrar(ui.ofiNingunaPri, #ui.ofiPri == 0)
  Mostrar(ui.ofiNingunaSec, #ui.ofiSec == 0)
  Encadenar(ui.ofiPri, p, GL.OFI.titulo, 0)
  Encadenar(ui.ofiSec, p, GL.OFI.titulo, -GL.OFI.fila)
end

local function CrearPanelOficios()
  local p = NuevoPanel()
  ui.panelOfi = p

  -- 9.5: como en el juego, dos filas: principales y secundarias (Primeros auxilios, Cocina y Pesca)
  ui.ofiTitPri = Texto(p, "GameFontNormalSmall")
  ui.ofiTitPri:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -7)
  ui.ofiTitPri:SetText(GL.L"Principales")
  ui.ofiTitSec = Texto(p, "GameFontNormalSmall")
  ui.ofiTitSec:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -7 - GL.OFI.fila)
  ui.ofiTitSec:SetText(GL.L"Secundarias")
  ui.ofiNingunaPri = Texto(p, "GameFontHighlightSmall")
  ui.ofiNingunaPri:SetPoint("TOPLEFT", p, "TOPLEFT", GL.OFI.titulo, -7)
  ui.ofiNingunaPri:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -7)
  ui.ofiNingunaPri:SetText(GRIS .. GL.L"Ninguna aprendida." .. FIN)
  ui.ofiNingunaSec = Texto(p, "GameFontHighlightSmall")
  ui.ofiNingunaSec:SetPoint("TOPLEFT", p, "TOPLEFT", GL.OFI.titulo, -7 - GL.OFI.fila)
  ui.ofiNingunaSec:SetText(GRIS .. GL.L"Ninguna aprendida." .. FIN)
  GL.OFI.botones(p)

  ui.ofiMarco = CrearMarcoIcono(p, 38)
  ui.ofiMarco:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -34 - GL.OFI.fila)
  ui.ofiNombre = Texto(p, "GameFontNormalLarge")
  ui.ofiNombre:SetPoint("TOPLEFT", p, "TOPLEFT", 46, -35 - GL.OFI.fila)
  ui.ofiNombre:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -35 - GL.OFI.fila); UnaLinea(ui.ofiNombre)   -- 7.6.1: dentro del marco
  ui.ofiBarra = CrearBarra(p, COLOR.acento[1], COLOR.acento[2], COLOR.acento[3])
  PorTema(function() ui.ofiBarra:SetStatusBarColor(COLOR.acento[1], COLOR.acento[2], COLOR.acento[3], 0.95) end)
  ui.ofiBarra:SetPoint("TOPLEFT", p, "TOPLEFT", 46, -57 - GL.OFI.fila)
  ui.ofiBarra:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -57 - GL.OFI.fila)
  ui.ofiIntro = Texto(p, "GameFontHighlightSmall")
  ui.ofiIntro:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -80 - GL.OFI.fila)

  CrearFilas(p, ui.filasOfi, 22)
  for i = 1, MAX_FILAS do
    local f = ui.filasOfi[i]
    f.texto = Texto(f, "GameFontHighlightSmall")
    f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -4)
  end
  ui.ofiPagina = CrearPie(p, ui.pagOfi, PaginaOfi, ProfesionDeMiNivel, RuedaOfi)
end

-- Reparte el ancho de las filas de botones; se llama al crear la ventana y al redimensionarla.
-- Con la ventana estrecha, las pestañas quitan el icono para que quepa el nombre entero; los botones de las
-- profesiones, también cuando son muchos (el pícaro tiene cinco).
local function IconosSegunAncho(botones, minimo)
  for i = 1, #botones do
    local b = botones[i]
    if b.icono then
      local cabe = (b:GetWidth() or 0) >= minimo
      Mostrar(b.icono, cabe)
      if cabe then b.texto:SetPoint("LEFT", b.icono, "RIGHT", 2, 0)
      else b.texto:SetPoint("LEFT", b, "LEFT", 4, 0) end
    end
  end
end

local function Disponer()
  if not frame then return end
  local ancho = AnchoContenido()
  Repartir(ui.nav, ancho)
  Repartir(ui.info, ancho)
  Repartir(ui.ramas, ancho - (ui.ponerTal and (ANCHO_PONER_TAL + 6) or 0))
  -- 9.5: cada fila (principales y secundarias) se reparte el ancho que queda tras su título
  Repartir(ui.ofiPri or ui.oficios, ancho - GL.OFI.titulo)
  Repartir(ui.ofiSec or {}, ancho - GL.OFI.titulo)
  IconosSegunAncho(ui.oficios, 100)
  Repartir(ui.pagTal, ancho)
  Repartir(ui.pagOfi, ancho)
  -- 7.6.1: las subpestañas (Personaje y Opciones) se reparten el ancho, como las pestañas: ya no se salen del marco
  for _, lista in pairs(ui.subs or {}) do
    local n = #lista
    if n > 0 then   -- 9.0: selector segmentado, sin hueco entre opciones
      local w = math.floor((ancho - 6 - (n - 1) * 6) / n)
      for i = 1, n do lista[i]:SetWidth(w) end
    end
  end
end

-- 9.5: rehace la lista de profesiones (las aprendidas) y sus botones; mantiene elegida la que tenías
GL.OFI.reconstruir = function()
  if not (GL.ProfesionesDelPersonaje and ui.panelOfi) then return end
  local ok, cambia = pcall(GL.ProfesionesDelPersonaje, RUTA)
  if not ok or not cambia then return end
  GL.OFI.botones(ui.panelOfi)
  local db = GuiaAventureroDB
  db.profesion = 1
  for i, prof in ipairs(RUTA.profesiones) do
    if prof.skill and prof.skill == db.profesionSkill then db.profesion = i end
  end
  Disponer()
  ProfesionDeMiNivel()
end

local function GuardarPosicion()
  local p, _, rp, x, y = frame:GetPoint()
  GuiaAventureroDB.pos = { p, rp, x, y }
end

local function GuardarTamano()
  GuiaAventureroDB.tam = { math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5) }
end

local function Limitar(v, minimo, maximo)
  if v < minimo then return minimo end
  if v > maximo then return maximo end
  return v
end

local function CrearVentana()
  local db = GuiaAventureroDB
  frame = CreateFrame("Frame", "GuiaAventureroFrame", UIParent, PLANTILLA)
  local tam = db.tam or {}
  frame:SetWidth(Limitar(tonumber(tam[1]) or ANCHO, MIN_ANCHO, MAX_ANCHO))
  frame:SetHeight(Limitar(tonumber(tam[2]) or ALTO, MIN_ALTO, MAX_ALTO))
  frame:SetFrameStrata("MEDIUM")
  frame:SetToplevel(true)
  Caja(frame, COLOR.fondo, COLOR.borde)
  table.insert(alCambiarTema, function()   -- 7.1: el tema Pergamino cambia el fondo y el borde
    Caja(frame, COLOR.fondo, COLOR.borde)
    if GL.AplicarAjustes then GL.AplicarAjustes() end
  end)
  Sombra(frame)
  frame:SetMovable(true)
  frame:SetResizable(true)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(MIN_ANCHO, MIN_ALTO, MAX_ANCHO, MAX_ALTO)
  elseif frame.SetMinResize then
    frame:SetMinResize(MIN_ANCHO, MIN_ALTO)
    frame:SetMaxResize(MAX_ANCHO, MAX_ALTO)
  end
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if not GuiaAventureroDB.bloqueada then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    GuardarPosicion()
  end)
  if db.pos then
    frame:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
  end

  -- 9.0: estilo moderno. A la izquierda, la barra lateral de iconos (retrato, secciones y, abajo, tamaño y opciones);
  -- arriba a la derecha, la barra de XP (Interfaz.lua) con la flecha y cerrar a su lado.
  local rail = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  rail:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  rail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
  rail:SetWidth(GL.RAIL - 1)
  rail:SetColorTexture(Color(COLOR.rail))
  local railLinea = frame:CreateTexture(nil, "BORDER")
  railLinea:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.RAIL, -1)
  railLinea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", GL.RAIL, 1)
  railLinea:SetWidth(1)
  railLinea:SetColorTexture(1, 1, 1, 0.06)
  ui.rail = rail
  ui.icono = CrearMarcoIcono(frame, 34)
  ui.icono:SetPoint("TOPLEFT", frame, "TOPLEFT", (GL.RAIL - 34) / 2, -10)
  PorTema(function() Caja(ui.icono, COLOR.icono, COLOR.acento) end)
  PonerIcono(ui.icono.icono, RUTA.icono)
  ui.icono.nivel = ui.icono:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.icono.nivel:SetPoint("BOTTOMRIGHT", ui.icono, "BOTTOMRIGHT", 6, -5)
  ui.icono.nivel:SetShadowOffset(1, -1)
  ui.icono.nivel:SetShadowColor(0, 0, 0, 1)
  ui.icono:EnableMouse(true)
  ui.icono:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(GL.L"Guía del Aventurero", 1, 0.82, 0)
    local okT, t = pcall(GL.TextoCabecera)
    if okT and t then GameTooltip:AddLine(t, 1, 1, 1, true) end
    GameTooltip:AddLine(AUTOR, 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  ui.icono:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- el título y el subtítulo de antes siguen existiendo (otros archivos los leen), pero ya no se ven:
  -- el subtítulo sale en la ayuda del retrato
  local titulo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titulo:SetText(BLANCO .. GL.L"Guía del " .. FIN .. AMARILLO .. GL.L"Aventurero" .. FIN)
  titulo:Hide()
  ui.titulo = titulo

  local cerrar = CrearBoton(frame, "×", function()
    frame:Hide()
    GuiaAventureroDB.oculto = true
  end, nil, 22, "cerrar")
  cerrar:SetWidth(22)
  cerrar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
  if GameFontNormalLarge then
    cerrar.texto:SetFontObject(GameFontNormalLarge)
    cerrar.texto:SetTextColor(cerrar.colTexto[1], cerrar.colTexto[2], cerrar.colTexto[3])
  end
  Ayuda(cerrar, GL.L"Cerrar", GL.L"Oculta la ventana. /ga la vuelve a mostrar.")
  ui.cerrar = cerrar

  ui.botonFlecha = CrearBoton(frame, "", AlternarFlecha, nil, 22)
  ui.botonFlecha:SetWidth(22)
  ui.botonFlecha:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -8)
  local dibujo = ui.botonFlecha:CreateTexture(nil, "ARTWORK")
  dibujo:SetTexture(RUTA_FLECHA)
  dibujo:SetPoint("TOPLEFT", ui.botonFlecha, "TOPLEFT", 2, -2)
  dibujo:SetPoint("BOTTOMRIGHT", ui.botonFlecha, "BOTTOMRIGHT", -2, 2)
  Ayuda(ui.botonFlecha, GL.L"Flecha", GL.L"Muestra u oculta la flecha que te lleva al siguiente destino.")

  -- botón de la barra lateral: solo el icono; el activo lleva fondo del acento y una raya a la izquierda
  local function BotonLateral(clave, nombre, icono, ayuda, funcion)
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(36); b:SetHeight(32)
    b.fondo = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.fondo:SetAllPoints()
    b.fondo:SetColorTexture(0, 0, 0, 0)
    b.raya = b:CreateTexture(nil, "ARTWORK")
    b.raya:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -4)
    b.raya:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 4)
    b.raya:SetWidth(3)
    b.raya:Hide()
    b.icono = b:CreateTexture(nil, "ARTWORK")
    b.icono:SetWidth(20); b.icono:SetHeight(20)
    b.icono:SetPoint("CENTER", b, "CENTER", 1, 0)
    PonerIcono(b.icono, icono)
    b.icono:SetAlpha(0.65)
    local brillo = b:CreateTexture(nil, "HIGHLIGHT")
    brillo:SetAllPoints()
    brillo:SetColorTexture(1, 1, 1, 0.06)
    b.texto = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")   -- lo usan las insignias; no se ve
    b.texto:Hide()
    b.clave, b.etiqueta = clave, nombre
    b:SetScript("OnClick", function(self, ...) funcion(self, ...) end)
    Ayuda(b, nombre, ayuda)
    b.SetActivo = function(self, activo)
      self.esActivo = activo and true or false
      if activo then
        self.fondo:SetColorTexture(COLOR.acento[1], COLOR.acento[2], COLOR.acento[3], 0.16)
        self.raya:SetColorTexture(Color(COLOR.acento)); self.raya:Show()
        self.icono:SetAlpha(1)
      else
        self.fondo:SetColorTexture(0, 0, 0, 0)
        self.raya:Hide()
        self.icono:SetAlpha(0.65)
      end
    end
    return b
  end
  GL.BotonLateral = BotonLateral   -- Interfaz.lua pone con ella Buscar, Grupo, tamaño y opciones

  local primeraRama = RUTA.ramas and RUTA.ramas[1]
  -- 9.4.2: el botón Personaje lleva el icono de la clase, no el de una rama (un paladín de Reprensión veía el de Sagrado)
  local claseJ = UnitClass and select(2, UnitClass("player"))
  local ICONO_CLASE = type(claseJ) == "string" and ("Interface\\Icons\\ClassIcon_" .. claseJ:sub(1, 1) .. claseJ:sub(2):lower()) or nil
  local ICONO_HECHIZOS = "Interface\\Icons\\INV_Misc_Book_09"
  local modos = {
    { "guia", GL.L"Guía", ICONO_LUGAR, GL.L"El paso actual de tu ruta y lo que viene." },
    { "personaje", GL.L"Personaje", ICONO_CLASE or (primeraRama and primeraRama.icono) or "Interface\\Icons\\INV_Misc_Head_Gnome_01", GL.L"Talentos, hechizos, equipo y estadísticas." },
    { "oficios", GL.L"Profesiones", RUTA.profesiones[1] and RUTA.profesiones[1].icono, GL.L"Lo que toca fabricar ahora y los materiales." },
    { "exploracion", GL.L"Exploración", "Interface\\Icons\\INV_Misc_Spyglass_03", GL.L"Cerca de ti, misiones de la zona y tu viaje." },   -- el panel lo hace Exploracion.lua
  }
  local y = -54
  for i = 1, #modos do
    local clave = modos[i][1]
    local b = BotonLateral(clave, modos[i][2], modos[i][3], modos[i][4], function() AbrirModo(clave) end)
    -- si el cliente no trae ClassIcon_*, el círculo de la clase de la pantalla de personajes
    if clave == "personaje" and ICONO_CLASE and b.icono.GetTexture and not b.icono:GetTexture() and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[claseJ] then
      b.icono:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
      b.icono:SetTexCoord(unpack(CLASS_ICON_TCOORDS[claseJ]))
    end
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", (GL.RAIL - 36) / 2, y)
    ui.modos[i] = b
    y = y - 34
  end
  local sep = frame:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1); sep:SetWidth(24)
  sep:SetPoint("TOPLEFT", frame, "TOPLEFT", (GL.RAIL - 24) / 2, y - 3)
  sep:SetColorTexture(1, 1, 1, 0.10)
  ui.separadorLateral = sep
  y = y - 8

  -- subpestañas: selector segmentado (un fondo oscuro y la opción elegida más clara)
  local subs = {
    personaje = { { "talentos", GL.L"Talentos" }, { "hechizos", GL.L"Hechizos" }, { "equipo", GL.L"Equipo" }, { "clase", GL.L"Clase" } },   -- 9.4: Clase; 9.0: Estadísticas pasa a Cuenta › Hoy › Por nivel
    opciones = { { "opciones", GL.L"Ajustes" }, { "automatismos", GL.L"Automatismos" }, { "novedades", GL.L"Novedades" } },
  }
  ui.fondosSub = {}
  for grupo, lista in pairs(subs) do
    ui.subs[grupo] = {}
    local fondoSub = CreateFrame("Frame", nil, frame, PLANTILLA)
    fondoSub:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -ARRIBA)
    fondoSub:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MARGEN, -ARRIBA)
    fondoSub:SetHeight(ALTO_SUB - 6)
    Caja(fondoSub, COLOR.rail, COLOR.rail)
    fondoSub:Hide()
    ui.fondosSub[grupo] = fondoSub
    for i = 1, #lista do
      local clave = lista[i][1]
      local b = CrearBoton(fondoSub, lista[i][2], function() AbrirModo(clave) end, nil, ALTO_SUB - 12, "pestana")
      b.texto:SetJustifyH("CENTER")
      b.clave = clave
      ui.subs[grupo][i] = b
    end
    Encadenar(ui.subs[grupo], fondoSub, 3, -3)
  end

  -- 6.6: lo que antes eran botones fuera de la ventana, ahora en la barra, bajo la raya
  local lado = {
    { GL.L"Mazmorras y bandas", "Interface\\Icons\\INV_Misc_Key_03", "mazmorras", GL.L"Mazmorras de tu nivel (misiones, jefes y botín) y bandas (cómo entrar y equipo antes de banda)." },
    { GL.L"Reputación", "Interface\\Icons\\INV_BannerPVP_02", "reputacion", GL.L"Guías de reputación." },
    { GL.L"Biblioteca", "Interface\\Icons\\INV_Misc_Book_11", "biblioteca", GL.L"Datos del mundo: zonas, facciones, profesiones." },
    { GL.L"Cuenta", "Interface\\Icons\\INV_Misc_GroupNeedMore", "cuenta", GL.L"Hoy, tus personajes y buscar objetos." },   -- 7.4
    { GL.L"Colección", "Interface\\Icons\\Ability_Mount_RidingHorse", "coleccion", GL.L"Monturas, mascotas y juguetes." },   -- 7.5.16
  }
  ui.lado = {}
  for i = 1, #lado do
    local clave = lado[i][3]
    local b = BotonLateral(clave, lado[i][1], lado[i][2], lado[i][4], function()
      if GuiaAventureroDB.modo == clave then AbrirModo(GuiaAventureroDB.modoGuia or "guia") else AbrirModo(clave) end
    end)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", (GL.RAIL - 36) / 2, y)
    ui.lado[i] = b
    y = y - 34
  end
  ui.yLateral = y   -- Interfaz.lua sigue poniendo iconos desde aquí

  CrearPanelGuia()
  CrearPanelTalentos()
  CrearPanelOficios()

  -- pie: autor abajo a la derecha y esquina para cambiar el tamaño
  local autor = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  autor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 5)   -- 9.4.2: más abajo, para no pisar los pies de las listas
  autor:SetJustifyH("RIGHT")
  autor:SetText(GRIS .. AUTOR .. FIN)
  autor:SetAlpha(0.6)
  ui.autor = autor

  local agarre = CreateFrame("Button", nil, frame)
  agarre:SetWidth(16)
  agarre:SetHeight(16)
  agarre:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
  -- seis puntitos en triangulo, mas discretos que la textura del chat
  local puntosAgarre = {}
  for fila = 0, 2 do
    for col = 0, 2 - fila do
      local p = agarre:CreateTexture(nil, "ARTWORK")
      p:SetWidth(2)
      p:SetHeight(2)
      p:SetPoint("BOTTOMRIGHT", agarre, "BOTTOMRIGHT", -2 - col * 4, 2 + fila * 4)
      p:SetColorTexture(1, 1, 1, 0.28)
      table.insert(puntosAgarre, p)
    end
  end
  local function TonoAgarre(a, r, g, b)
    for i = 1, #puntosAgarre do puntosAgarre[i]:SetColorTexture(r, g, b, a) end
  end
  agarre:SetScript("OnMouseDown", function()
    if not GuiaAventureroDB.bloqueada then frame:StartSizing("BOTTOMRIGHT") end
  end)
  agarre:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    GuardarTamano()
    GuardarPosicion()
  end)
  Ayuda(agarre, GL.L"Tamaño", GL.L"Arrastra para cambiar el tamaño de la ventana.")
  agarre:HookScript("OnEnter", function() TonoAgarre(0.9, COLOR.acento[1], COLOR.acento[2], COLOR.acento[3]) end)
  agarre:HookScript("OnLeave", function() TonoAgarre(0.28, 1, 1, 1) end)

  frame:SetScript("OnSizeChanged", function()
    Disponer()
    ProgramarRefresco()
  end)
  -- Al mostrarse se refresca: los altos de los textos solo se conocen con la ventana visible.
  frame:SetScript("OnShow", function() Refrescar() end)
  Disponer()
  if db.oculto then frame:Hide() end
  Refrescar()
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Guardados (6.0.3): GuiaAventureroDB es de cada personaje (SavedVariablesPerCharacter), así que sus preferencias
-- no se mezclan con las de otros. db.esquema dice qué migraciones tiene ya; cada una se hace una sola vez,
-- en orden, y nunca borra datos que no conoce (atascos, posiciones, notas...).
------------------------------------------------------------------------
local ESQUEMA = 2
local MIGRACIONES = {
  -- 1 (6.0.2): automatismos. Si el personaje ya usaba la guía (tiene ruta), cada uno queda como lo tenía
  -- (antes venían encendidos); si es nuevo, todos apagados.
  function(db)
    if db.automatismos602 then return end   -- ya migrado con la 6.0.2
    local empezado = db.ruta ~= nil
    for i = 1, #AUTOMATISMOS do
      local k = AUTOMATISMOS[i]
      if db[k] == nil then db[k] = empezado and k ~= "autoVender" end   -- 6.9: vender lo gris nunca venía encendido
    end
  end,
  -- 2 (6.9): automatismo nuevo "Vender lo gris", apagado en todos los personajes.
  function(db)
    if db.autoVender == nil then db.autoVender = false end
  end,
}

local function Migrar(db)
  local desde = tonumber(db.esquema) or 0
  -- Un esquema inválido no debe saltarse migraciones ni indexar funciones inexistentes.
  if desde ~= desde or desde < 0 or desde == math.huge or desde % 1 ~= 0 then desde = 0 end
  if desde > ESQUEMA then return end -- conservar datos de versiones posteriores
  for i = desde + 1, ESQUEMA do
    local ok, err = pcall(MIGRACIONES[i], db)
    if not ok then
      Mensaje(GL.L"no se pudo poner al día lo guardado (paso " .. i .. "): " .. tostring(err))
      return
    end
    db.esquema = i
  end
  db.esquema = ESQUEMA
  db.automatismos602 = nil   -- lo sustituye db.esquema
end

-- Revisa los datos de la ruta cargada: destinos sin mapa o sin coordenadas, mapas que el juego no conoce y
-- pasos sin forma de darse por hechos. Lo usa /ga depurar.
local function RevisarRuta()
  local r = { pasos = 0, destinos = 0, sinCoord = {}, mapasRaros = {}, sinFin = {} }
  if not RUTA or not RUTA.secciones then return r end
  local mapasVistos = {}
  for s, sec in ipairs(RUTA.secciones) do
    for p, paso in ipairs(sec.pasos or {}) do
      r.pasos = r.pasos + 1
      local donde = s .. "." .. p
      local conMision = false
      for _, wp in ipairs(paso.wp or {}) do
        r.destinos = r.destinos + 1
        if wp.q then conMision = true end
        if not (wp.m and wp.x and wp.y) then
          table.insert(r.sinCoord, donde)
        elseif mapasVistos[wp.m] == nil then
          local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(wp.m)
          mapasVistos[wp.m] = (type(info) == "table") and true or false
          if not mapasVistos[wp.m] then table.insert(r.mapasRaros, wp.m .. " (" .. tostring(wp.z) .. ")") end
        end
      end
      if not conMision and not paso.comprobar and #(paso.wp or {}) > 0 then
        local soloPnj = true
        for _, wp in ipairs(paso.wp) do if not wp.npc then soloPnj = false end end
        if not soloPnj then table.insert(r.sinFin, donde) end
      end
    end
  end
  return r
end

local function Iniciar()
  if type(GuiaAventureroDB) ~= "table" then GuiaAventureroDB = {} end
  local db = GuiaAventureroDB
  Migrar(db)
  GL.temaActivo = AplicarTema(db.tema).id
  RUTA = ElegirRuta()
  if not RUTA then
    Mensaje(GL.L"no hay ninguna ruta instalada en la carpeta Rutas.")
    return
  end
  if not CargarRuta(RUTA) then RUTA = nil; return end
  AdaptarARaza(RUTA)
  if GL.TraducirRuta then GL.TraducirRuta(RUTA) end   -- 9.3.5: en inglés (Idioma.lua)
  if GL.ProfesionesDelPersonaje then pcall(GL.ProfesionesDelPersonaje, RUTA) end   -- 9.5: las que has aprendido (Secundarias.lua)
  if db.ruta ~= RUTA.id then
    -- ruta nueva para este personaje: empezamos en la seccion de su nivel
    db.ruta = RUTA.id
    db.seccion = SeccionPorNivel(UnitLevel("player") or 1)
    db.paso = 1
    db.destino = 1
    db.profesion = 1
  end
  -- 9.7.4: lo guardado puede venir raro (texto, decimales, negativos): se pasa a un número entero válido
  db.seccion, db.paso, db.destino = GL.EnteroGuardado(db.seccion), GL.EnteroGuardado(db.paso), GL.EnteroGuardado(db.destino)
  if not db.seccion or db.seccion < 1 or db.seccion > NumSecciones() then db.seccion = 1 end
  if not db.paso or db.paso < 1 or db.paso > #RUTA.secciones[db.seccion].pasos then db.paso = 1 end
  if not db.destino or db.destino < 1 then db.destino = 1 end
  if not db.pestana then db.pestana = "entrenar" end
  if not db.modo then db.modo = "guia" end
  if not db.profesion or not RUTA.profesiones[db.profesion] then db.profesion = 1 end
  TalentosDeMiNivel()
  ProfesionDeMiNivel()
  CrearFlecha()
  CrearVentana()
  GL.RUTA, GL.frame, GL.flecha = RUTA, frame, flecha
  for i = 1, #GL.alIniciar do
    local ok, err = pcall(GL.alIniciar[i])
    if not ok then
      Mensaje(GL.L"error al iniciar un módulo: " .. tostring(err))
      table.insert(GL.erroresCarga, GL.L"al iniciar: " .. "#" .. i .. ": " .. tostring(err))
    end
  end
  Mensaje(GL.L"cargada la ruta " .. RUTA.nombre .. " (" .. AUTOR .. GL.L"). /ga muestra u oculta la ventana." ..
    (db.auto == false and "" or GL.L" La guía avanza sola cuando ya tienes hechas las misiones de un paso (se quita en Ajustes)."))
  ProgramarSync()
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "PLAYER_LOGIN")
GL.Evento(eventos, "PLAYER_REGEN_DISABLED")
GL.Evento(eventos, "PLAYER_REGEN_ENABLED")
GL.Evento(eventos, "PLAYER_LEVEL_UP")
GL.Evento(eventos, "SKILL_LINES_CHANGED")
GL.Evento(eventos, "PLAYER_ENTERING_WORLD")
GL.Evento(eventos, "QUEST_LOG_UPDATE")
GL.Evento(eventos, "QUEST_ACCEPTED")
GL.Evento(eventos, "QUEST_TURNED_IN")
GL.Evento(eventos, "QUEST_REMOVED")
GL.Evento(eventos, "ZONE_CHANGED_NEW_AREA")
GL.Evento(eventos, "TAXIMAP_OPENED")
GL.Evento(eventos, "BAG_UPDATE_DELAYED")
GL.Evento(eventos, "SPELLS_CHANGED")
GL.Evento(eventos, "LEARNED_SPELL_IN_SKILL_LINE")
eventos:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_REGEN_DISABLED" then
    if GL.ModoDiscretoCombate then GL.ModoDiscretoCombate(true) end
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    if GL.ModoDiscretoCombate then GL.ModoDiscretoCombate(false) end
    return
  elseif event == "PLAYER_LOGIN" then
    Iniciar()
  elseif event == "TAXIMAP_OPENED" then
    pcall(GuardarVuelos)
    if RUTA and frame then ProgramarSync() end
  elseif event == "BAG_UPDATE_DELAYED" then
    -- los materiales de Profesiones cuentan lo que llevas en las bolsas
    if frame and frame:IsShown() and GuiaAventureroDB.modo == "oficios" then ProgramarRefresco() end
  elseif event == "PLAYER_LEVEL_UP" then
    if not RUTA or not frame then return end
    local nivel = tonumber((...)) or UnitLevel("player")
    -- hechizos nuevos de este nivel por orden de prioridad (Instructor.lua); si no hay datos, el aviso de siempre
    local okE, entreno = pcall(function() return GL.MensajeEntrenamiento and GL.MensajeEntrenamiento(nivel) end)
    if okE and entreno then
      Mensaje(entreno)
    elseif nivel % 2 == 0 then
      Mensaje(GL.L"Nivel " .. nivel .. GL.L": visita a tu " .. (RUTA.instructor or GL.L"instructor de clase") .. GL.L" para aprender hechizos nuevos.")
    end
    -- con los talentos automáticos (Talentos.lua) ya se avisa de lo que se pone
    if not (GL.AutoTalentos and GL.AutoTalentos()) then
      for i = 1, #RUTA.talentos do
        local t = RUTA.talentos[i]
        if nivel >= t.d and nivel <= t.h then
          local nombreT = t.nombre
          if GL.ingles then nombreT = string.match(nombreT or "", "^(.-)%s*%(.-%)%s*$") or nombreT end   -- 9.7.4: en inglés, sin el nombre español entre paréntesis
          Mensaje(GL.L"Talento: " .. tostring(nombreT) .. " (" .. t.rama .. GL.L", fila " .. t.fila .. ").")
        end
      end
    end
    local s = RUTA.secciones[GuiaAventureroDB.seccion]
    if s and nivel >= s.max and GuiaAventureroDB.seccion < NumSecciones() then
      Mensaje(GL.L"Ya tienes nivel para la siguiente sección. Pulsa 'Mi nivel' o '>'.")
    end
    if GuiaAventureroDB.modo == "talentos" then TalentosDeMiNivel() end
    Refrescar()
    ProgramarSync()   -- por si el paso era subir de nivel
  elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
    -- hechizo aprendido: puede cerrar un paso de instructor y cambia la lista de Hechizos
    if RUTA and frame then
      ProgramarSync()
      if frame:IsShown() and GuiaAventureroDB.modo == "guia" and GuiaAventureroDB.consejosAbiertos then ProgramarRefresco() end
    end
  elseif event == "SKILL_LINES_CHANGED" then
    if RUTA and frame and GL.OFI.reconstruir then GL.OFI.reconstruir() end   -- 9.5: aprendiste u olvidaste una profesión
    if frame and frame:IsShown() and GuiaAventureroDB.modo == "oficios" then Refrescar() end
    if RUTA and frame then ProgramarSync() end   -- por si el paso era aprender una profesión
  else
    -- cambios en el diario de misiones: comprobar si el paso ya esta hecho
    if event == "QUEST_TURNED_IN" then
      local q = tonumber((...))
      if q then entregadas[q] = true end
      if GL.OlvidarImplicitas then GL.OlvidarImplicitas() end
    end
    if RUTA and frame then ProgramarSync() end
  end
end)

------------------------------------------------------------------------
-- Diagnostico (/ga depurar): un informe para copiar y pegar cuando algo no va
------------------------------------------------------------------------
local informe   -- ventana con el texto del informe

local function MostrarInforme(texto)
  if not informe then
    local f = CreateFrame("Frame", "GuiaAventureroInforme", UIParent, PLANTILLA)
    f:SetWidth(520)
    f:SetHeight(420)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    Caja(f, COLOR.fondo, COLOR.borde)
    Sombra(f)
    Acento(f, 2)
    local titulo = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    titulo:SetText(BLANCO .. GL.L"Informe de " .. FIN .. AMARILLO .. GL.L"Guía del Aventurero" .. FIN)
    local ayuda = Texto(f, "GameFontHighlightSmall")
    ayuda:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
    ayuda:SetText(GRIS .. GL.L"Pulsa Ctrl+C para copiarlo y pégalo donde te lo pidan." .. FIN)

    local caja = CreateFrame("Frame", nil, f, PLANTILLA)
    caja:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -56)
    caja:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 46)
    Caja(caja, COLOR.caja, COLOR.cajaBorde)
    local scroll = CreateFrame("ScrollFrame", nil, caja)
    scroll:SetPoint("TOPLEFT", caja, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", caja, "BOTTOMRIGHT", -6, 6)
    local editor = CreateFrame("EditBox", nil, scroll)
    editor:SetMultiLine(true)
    editor:SetAutoFocus(false)
    editor:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    editor:SetWidth(480)
    scroll:SetScrollChild(editor)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      local v = (self:GetVerticalScroll() or 0) - delta * 28
      local maximo = self:GetVerticalScrollRange() or 0
      if v < 0 then v = 0 end
      if v > maximo then v = maximo end
      self:SetVerticalScroll(v)
    end)
    -- el texto no se edita: si se teclea algo, vuelve a ponerse el informe
    editor:SetScript("OnTextChanged", function(self, usuario)
      if usuario and self.textoFijo and self:GetText() ~= self.textoFijo then
        self:SetText(self.textoFijo)
        self:HighlightText()
      end
    end)
    editor:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    editor:SetScript("OnEscapePressed", function() f:Hide() end)

    local todo = CrearBoton(f, GL.L"Seleccionar todo", function()
      editor:SetFocus()
      editor:HighlightText()
    end, nil, 24)
    todo:SetWidth(120)
    todo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    local cerrar = CrearBoton(f, GL.L"Cerrar", function() f:Hide() end, nil, 24, "accion")
    cerrar:SetWidth(90)
    cerrar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    if UISpecialFrames then table.insert(UISpecialFrames, "GuiaAventureroInforme") end
    f.editor, f.scroll = editor, scroll
    informe = f
  end
  local editor = informe.editor
  editor.textoFijo = texto
  editor:SetText(texto)
  -- el cuadro de texto necesita un alto: una linea por salto y otra por cada ~72 caracteres de mas
  local lineas = 0
  for linea in string.gmatch(texto .. "\n", "(.-)\n") do
    lineas = lineas + math.max(1, math.ceil(string.len(linea) / 72))
  end
  editor:SetHeight(math.max(lineas * 14 + 12, 300))
  informe.scroll:SetVerticalScroll(0)
  informe:Show()
  editor:SetFocus()
  editor:HighlightText()
end

local function SiNo(v) return v and GL.L"sí" or "no" end

local function InformeDiagnostico()
  local L = {}
  local function Linea(t) table.insert(L, t) end
  -- Cada bloque va protegido: si una consulta falla, el informe sigue y lo dice.
  local function Bloque(nombre, consulta)
    local ok, err = pcall(consulta)
    if not ok then Linea(nombre .. GL.L": no se pudo consultar (" .. tostring(err) .. ")") end
  end
  local db = (type(GuiaAventureroDB) == "table") and GuiaAventureroDB or {}

  Linea(GL.L"GUÍA DEL AVENTURERO · INFORME DE DIAGNÓSTICO")
  Bloque(GL.L"Versión", function()
    local leer = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local toc = leer and leer("GuiaAventurero", "Version") or "?"
    local v = GL.VERSION or "?"
    Linea(GL.L"Versión: " .. tostring(v) .. " (toc: " .. tostring(toc) .. ")" ..
      (tostring(v) ~= tostring(toc) and GL.L"  ¡NO COINCIDEN: puede haber archivos de versiones distintas!" or ""))
  end)
  Bloque(GL.L"Cliente", function()
    local version, build, fecha, interfaz = GetBuildInfo()
    Linea(GL.L"Cliente: " .. tostring(version) .. " (build " .. tostring(build) .. ", " .. tostring(fecha) ..
      GL.L"), interfaz " .. tostring(interfaz) .. GL.L", idioma " .. tostring(GetLocale()))
  end)
  Bloque(GL.L"Personaje", function()
    local _, clase = UnitClass("player")
    local raza = GL.Raza()
    Linea(GL.L"Personaje: " .. tostring(clase) .. ", " .. tostring(raza) .. GL.L", nivel " .. tostring(UnitLevel("player")))
  end)
  Bloque(GL.L"Ruta", function()
    local registradas = {}
    local rutas = GuiaAventurero_Rutas or {}
    for i = 1, #rutas do table.insert(registradas, tostring(rutas[i].id)) end
    if RUTA then
      Linea(GL.L"Ruta: " .. tostring(RUTA.id) .. " (" .. tostring(RUTA.nombre) .. "), " ..
        tostring(#(RUTA.secciones or {})) .. GL.L" secciones")
      Linea(GL.L"Posición: sección " .. tostring(db.seccion) .. GL.L", paso " .. tostring(db.paso) ..
        GL.L", destino " .. tostring(db.destino) .. GL.L", pestaña " .. tostring(db.pestana) .. GL.L", modo " .. tostring(db.modo))
    else
      Linea(GL.L"Ruta: NINGUNA cargada")
    end
    Linea(GL.L"Rutas registradas (" .. #registradas .. "): " .. table.concat(registradas, ", "))
    if db.rutaElegida then Linea(GL.L"Ruta elegida a mano: " .. tostring(db.rutaElegida)) end
  end)
  Bloque(GL.L"Datos de la ruta", function()
    local r = RevisarRuta()
    local function Lista(t) return #t == 0 and "ninguno" or (#t .. ": " .. table.concat(t, ", ", 1, math.min(#t, 12)) .. (#t > 12 and "..." or "")) end
    Linea(GL.L"Revisión de la ruta: " .. r.pasos .. GL.L" pasos, " .. r.destinos .. GL.L" destinos")
    Linea(GL.L"  Destinos sin mapa o coordenadas (sección.paso): " .. Lista(r.sinCoord))
    Linea(GL.L"  Mapas que el juego no reconoce: " .. Lista(r.mapasRaros))
    Linea(GL.L"  Pasos que no avanzan solos (sin misión ni comprobación; se pasan con Siguiente): " .. Lista(r.sinFin))
  end)
  Bloque(GL.L"Automatismos y guardado", function()
    local t = {}
    for i = 1, #AUTOMATISMOS do
      local k = AUTOMATISMOS[i]
      table.insert(t, k .. "=" .. ((db[k] ~= false) and GL.L"sí" or "no"))
    end
    Linea(GL.L"Automatismos: " .. table.concat(t, ", "))
    Linea(GL.L"Guardado de este personaje: esquema " .. tostring(db.esquema) .. GL.L" de " .. ESQUEMA ..
      GL.L", pasos atascados apuntados " .. ((type(db.atascos) == "table") and #db.atascos or 0))
  end)
  Bloque(GL.L"Tema", function()
    Linea(GL.L"Tema: elegido " .. tostring(BuscarTema(db.tema).id) .. GL.L", activo " .. tostring(GL.temaActivo))
  end)
  Bloque(GL.L"Opciones", function()
    -- todo lo guardado que no es una tabla (las posiciones y tamaños de las ventanas van aparte)
    local claves = {}
    for k, v in pairs(db) do
      local t = type(v)
      if t == "string" or t == "number" or t == "boolean" then table.insert(claves, tostring(k)) end
    end
    table.sort(claves)
    local datos = {}
    for i = 1, #claves do
      local v = db[claves[i]]
      if type(v) == "number" then v = string.format("%.3g", v) end
      table.insert(datos, claves[i] .. "=" .. tostring(v))
    end
    Linea(GL.L"Datos guardados: " .. (#datos > 0 and table.concat(datos, ", ") or "ninguno"))
  end)
  Bloque(GL.L"Ventana", function()
    if frame then
      Linea(GL.L"Ventana: creada, visible " .. SiNo(frame:IsShown()) .. ", " .. math.floor(frame:GetWidth() + 0.5) ..
        "x" .. math.floor(frame:GetHeight() + 0.5) .. GL.L", escala " .. string.format("%.2f", frame:GetScale()))
    else
      Linea(GL.L"Ventana: NO creada")
    end
    if flecha then
      Linea(GL.L"Flecha: creada, visible " .. SiNo(flecha:IsShown()) .. GL.L", puede girar (SetRotation) " ..
        SiNo(flecha.puedeGirar) .. GL.L", escala " .. string.format("%.2f", flecha:GetScale()))
    else
      Linea(GL.L"Flecha: NO creada")
    end
  end)
  Bloque(GL.L"Funciones del juego", function()
    local necesarias = {
      { "C_Map.GetPlayerMapPosition", C_Map and C_Map.GetPlayerMapPosition },
      { "C_Map.SetUserWaypoint", C_Map and C_Map.SetUserWaypoint },
      { "C_Timer.After", C_Timer and C_Timer.After },
      { "C_AddOns", C_AddOns },
      { "BackdropTemplate", BackdropTemplateMixin },
      { "GetPlayerFacing", GetPlayerFacing },
      { "SetResizeBounds", UIParent.SetResizeBounds },
      { "Settings", Settings and Settings.RegisterCanvasLayoutCategory },
    }
    if flecha then table.insert(necesarias, { "Texture:SetRotation", flecha.puedeGirar }) end
    local faltan = {}
    for i = 1, #necesarias do
      if not necesarias[i][2] then table.insert(faltan, necesarias[i][1]) end
    end
    Linea(GL.L"Funciones del juego que faltan (algunas son opcionales según el cliente): " ..
      (#faltan > 0 and table.concat(faltan, ", ") or "ninguna"))
  end)
  Bloque(GL.L"Módulos", function()
    local esperadas = { "NOVEDADES", "RefrescarHechizos", "AprenderRecomendado", "AprenderRecetas",
      "AplicarTamTexto", "CambiarTema" }
    local faltan = {}
    for i = 1, #esperadas do
      if not GL[esperadas[i]] then table.insert(faltan, esperadas[i]) end
    end
    Linea(GL.L"Módulos del addon que faltan: " .. (#faltan > 0 and table.concat(faltan, ", ") or "ninguno"))
    local sinPantalla = {}
    for _, m in ipairs({ "equipo", "hechizos", "estadisticas" }) do
      if not GL.modos[m] then table.insert(sinPantalla, m) end
    end
    Linea(GL.L"Pantallas que no se han creado: " .. (#sinPantalla > 0 and table.concat(sinPantalla, ", ") or "ninguna"))
    if GL.InformeBuffs then local ok, t = pcall(GL.InformeBuffs); Linea(GL.L"Buffs en pantalla: " .. (ok and t or (GL.L"error: " .. tostring(t)))) end
    Linea(GL.L"Fallos al cargar: " .. (#GL.erroresCarga > 0 and table.concat(GL.erroresCarga, "; ") or "ninguno"))
  end)
  Bloque(GL.L"Memoria", function()
    local actualizar = UpdateAddOnMemoryUsage or (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage)
    local leer = GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
    local propia = ""
    if actualizar and leer then
      actualizar()
      propia = GL.L", de ellos Guía del Aventurero " .. string.format("%.1f MB", leer("GuiaAventurero") / 1024)
    end
    Linea(GL.L"Memoria de Lua de toda la interfaz: " .. string.format("%.1f MB", collectgarbage("count") / 1024) .. propia)
  end)
  Linea(GL.L"Avisos de error en el chat: " .. (GL.depurar and GL.L"activados" or GL.L"desactivados") ..
    GL.L" (/ga depurar errores los activa o quita)")
  return table.concat(L, "\n")
end

local function Depurar(orden)
  if orden == "errores" then
    GL.depurar = not GL.depurar
    Mensaje(GL.L"avisos de error en el chat " .. (GL.depurar and GL.L"activados" or GL.L"desactivados") .. ".")
    return
  end
  local ok, texto = pcall(InformeDiagnostico)
  if not ok then
    Mensaje(GL.L"no se pudo preparar el informe: " .. tostring(texto))
    return
  end
  local ok2, err = pcall(MostrarInforme, texto)
  if ok2 then
    Mensaje(GL.L"informe abierto: pulsa Ctrl+C para copiarlo.")
  else
    Mensaje(GL.L"no se pudo abrir la ventana del informe (" .. tostring(err) .. GL.L"). Aquí va en el chat:")
    for linea in string.gmatch(texto .. "\n", "(.-)\n") do Mensaje(linea) end
  end
end

------------------------------------------------------------------------
-- Pasos que no avanzan (/ga atascado [nota]): guarda una foto del paso actual por personaje
-- (GuiaAventureroDB.atascos, las 30 últimas) para revisarlo después. "ver" las enseña y "borrar" las quita.
------------------------------------------------------------------------
local MAX_ATASCOS = 30

local function FotoPaso(nota)
  local db = GuiaAventureroDB
  local s, p = PasoActual()
  local L = {}
  local function Linea(t) table.insert(L, t) end
  local fecha = tostring((date and date("%d-%m-%Y %H:%M")) or "?")
  Linea(fecha .. GL.L" · versión " .. tostring(GL.VERSION or "?") .. GL.L" · ruta " .. tostring(RUTA and RUTA.id) ..
    GL.L" · sección " .. tostring(db.seccion) .. GL.L", paso " .. tostring(db.paso) .. GL.L", destino " .. tostring(db.destino))
  local zona = (GetZoneText and GetZoneText()) or "?"
  local mapa = (C_Map and C_Map.GetBestMapForUnit) and C_Map.GetBestMapForUnit("player") or nil
  Linea(GL.L"Nivel " .. tostring(UnitLevel("player")) .. " · " .. tostring(zona) .. GL.L" (mapa " .. tostring(mapa) .. ")")
  if nota and nota ~= "" then Linea(GL.L"Nota: " .. nota) end
  if s then Linea(GL.L"Sección: " .. tostring(s.titulo)) end
  if p then
    local t = tostring(p.t or "")
    if string.len(t) > 160 then t = string.sub(t, 1, 160) .. "..." end
    Linea(GL.L"Paso: " .. t)
    Linea(GL.L"Estado del paso para la guía: " .. tostring(EstadoPaso(p)))
    for i = 1, #(p.wp or {}) do
      local d = p.wp[i]
      local partes = { i .. ". " .. tostring(d.n or "?") }
      if d.q then
        table.insert(partes, (d.a or "?") .. tostring(d.q))
        table.insert(partes, GL.L"hecho " .. tostring(DestinoHecho(d)))
        table.insert(partes, GL.L"en diario " .. SiNo(MisionEnDiario(d.q)))
        table.insert(partes, GL.L"objetivos listos " .. SiNo(ObjetivosListos(d.q)))
        table.insert(partes, GL.L"entregada " .. SiNo(MisionCompletada(d.q)))
      elseif d.npc then
        table.insert(partes, GL.L"PNJ " .. tostring(d.npc))
      end
      Linea("  " .. table.concat(partes, " · "))
    end
    if p.comprobar then
      local c = {}
      for k, v in pairs(p.comprobar) do
        if type(v) == "table" then
          local x = {}
          for j = 1, #v do table.insert(x, tostring(v[j])) end
          v = table.concat(x, ",")
        end
        table.insert(c, tostring(k) .. "=" .. tostring(v))
      end
      table.sort(c)
      Linea(GL.L"  comprobar: " .. table.concat(c, " ") .. " -> " .. tostring(ComprobacionesHechas(p)))
    end
  end
  return table.concat(L, "\n")
end

local function TextoAtascos()
  local lista = GuiaAventureroDB.atascos or {}
  if #lista == 0 then return nil end
  local partes = { GL.L"GUÍA DEL AVENTURERO · PASOS QUE NO AVANZARON (" .. #lista .. ")" }
  for i = 1, #lista do table.insert(partes, "\n#" .. i .. "  " .. lista[i]) end
  return table.concat(partes, "\n")
end

local function Atascado(orden)
  local db = GuiaAventureroDB
  db.atascos = db.atascos or {}
  if orden == "borrar" then
    db.atascos = {}
    Mensaje(GL.L"pasos apuntados borrados.")
    return
  end
  if orden == "ver" then
    local texto = TextoAtascos()
    if not texto then Mensaje(GL.L"no hay pasos apuntados. Usa /ga atascado en el paso que no avance.") return end
    local ok = pcall(MostrarInforme, texto)
    if not ok then for linea in string.gmatch(texto .. "\n", "(.-)\n") do Mensaje(linea) end end
    return
  end
  local ok, foto = pcall(FotoPaso, orden)
  if not ok then
    Mensaje(GL.L"no se pudo apuntar el paso: " .. tostring(foto))
    return
  end
  table.insert(db.atascos, foto)
  while #db.atascos > MAX_ATASCOS do table.remove(db.atascos, 1) end
  Mensaje(GL.L"paso apuntado (" .. #db.atascos .. GL.L"). /ga atascado ver los enseña para copiarlos; " ..
    GL.L"/ga atascado borrar los quita.")
  pcall(MostrarInforme, TextoAtascos())
end
GL.comandos = GL.comandos or {}
GL.comandos["atascado"] = Atascado

------------------------------------------------------------------------
-- Comandos
------------------------------------------------------------------------
SLASH_GUIAAVENTURERO1 = "/ga"
SLASH_GUIAAVENTURERO2 = "/guialeveo"   -- 9.5: el de antes sigue valiendo
SLASH_GUIAAVENTURERO3 = "/gleveo"
SlashCmdList["GUIAAVENTURERO"] = function(msg)
  msg = string.lower(msg or "")
  -- el diagnóstico va antes de comprobar que la guía cargó: es justo cuando más falta hace
  if msg == "depurar" or string.match(msg, "^depurar%s") then
    Depurar(string.match(msg, "^depurar%s*(.-)%s*$"))
    return
  end
  if not frame then
    Mensaje(GL.L"la guía no se ha cargado (¿falta la carpeta Rutas?).")
    return
  end
  local db = GuiaAventureroDB
  local idRuta = string.match(msg, "^ruta%s+(%S+)")
  local palabra, resto = string.match(msg, "^(%S+)%s*(.-)$")
  -- 9.7.6: comandos quitados porque ya tienen su botón o su casilla (o hacían lo mismo que otro): se dice dónde está
  local quitado = palabra and GL.COMANDOS_QUITADOS and GL.COMANDOS_QUITADOS[palabra]
  if quitado then
    Mensaje("/ga " .. palabra .. GL.L" ya no existe" .. (quitado ~= true and (": " .. GL.L(quitado)) or "") .. ".")
  elseif palabra and GL.comandos[palabra] then
    GL.comandos[palabra](resto)
  elseif msg == "rutas" or msg == "ruta" then
    ListarRutas()
  elseif idRuta then
    db.rutaElegida = idRuta
    Mensaje(GL.L"ruta '" .. idRuta .. GL.L"' elegida. Escribe /reload para cargarla.")
  elseif msg == "nivel" then
    IrAMiNivel(); frame:Show(); db.oculto = false
  elseif msg == "sig" then
    Siguiente()
  elseif msg == "ant" then
    Anterior()
  elseif msg == "auto" then
    AlternarAuto()
  elseif msg == "flecha" then
    AlternarFlecha()
  elseif msg == "talentos" then
    frame:Show(); db.oculto = false; AbrirModo("talentos")
  elseif msg == "oficios" or msg == "profesiones" then
    frame:Show(); db.oculto = false; AbrirModo("oficios")
  elseif msg == "preparar" then
    ui.prepForzada = true
    frame:Show(); db.oculto = false; AbrirModo("guia")
  elseif msg == "ignorados" then
    local n = 0
    for _ in pairs(type(db.ignorados) == "table" and db.ignorados or {}) do n = n + 1 end
    db.ignorados, db.pospuestos = nil, nil
    Mensaje(n == 0 and GL.L"no tienes objetivos ignorados." or (n .. GL.L" objetivos ignorados vuelven a contar (y nada queda pospuesto)."))
    ProgramarSync()
  elseif msg == "automatismos" then
    if GL.AbrirAutomatismos then GL.AbrirAutomatismos() end
  elseif msg == "personaje" then
    frame:Show(); db.oculto = false; AbrirModo("personaje")
  elseif msg == "exploracion" or msg == "exploración" then
    frame:Show(); db.oculto = false; AbrirModo("exploracion")
  elseif msg:match("^idioma") or msg:match("^language") then   -- 9.3.5
    if GL.ComandoIdioma then GL.ComandoIdioma(msg:match("^%S+%s+(%S+)")) end
  elseif msg == "reset" then
    db.pos = nil; db.posFlecha = nil; db.tam = nil
    frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    frame:SetWidth(ANCHO); frame:SetHeight(ALTO)
    flecha:ClearAllPoints(); flecha:SetPoint("TOP", UIParent, "TOP", 0, -120)
    for i = 1, #GL.alReiniciar do pcall(GL.alReiniciar[i]) end
    IrAMiNivel(); frame:Show(); db.oculto = false
    Mensaje(GL.L"ventanas reiniciadas.")
  elseif msg == "ayuda" then
    Mensaje(GL.L"/ga (mostrar/ocultar), nivel, sig, ant, auto, flecha, talentos, oficios, compacto, opciones, " ..
      "hechizos, misiones, instructor, autohechizos, autorecetas, ponertalentos, autotalentos, marca, minimapa, novedades, rutas, depurar, atascado, comprobar, perfil, compatibilidad, tutorial, compartir, memoria, franja, tamano, reset")
  else
    GL.AlternarVentana()
  end
end

------------------------------------------------------------------------
-- Lo que usan los demas archivos del addon
------------------------------------------------------------------------
-- Modo discreto: oculta temporalmente la guia y la flecha durante combate.
-- Solo restaura los elementos que estaban visibles antes del combate.
local discretoCombate = { activo = false, ventana = false, flecha = false }
function GL.ModoDiscretoCombate(enCombate)
  local db = GuiaAventureroDB or {}
  if db.discretoCombate ~= true then return end
  if enCombate then
    if discretoCombate.activo then return end
    discretoCombate.activo = true
    discretoCombate.ventana = frame and frame:IsShown() or false
    discretoCombate.flecha = flecha and flecha:IsShown() or false
    if discretoCombate.ventana then frame:Hide() end
    if discretoCombate.flecha then flecha:Hide() end
  else
    if not discretoCombate.activo then return end
    discretoCombate.activo = false
    if discretoCombate.ventana and frame and not db.oculto then frame:Show() end
    if discretoCombate.flecha and flecha and db.flecha ~= false then flecha:Show() end
    discretoCombate.ventana, discretoCombate.flecha = false, false
  end
end

-- Muestra u oculta la ventana (Opciones.lua la cambia para el modo compacto).
function GL.AlternarVentana()
  if not frame then return end
  local db = GuiaAventureroDB
  if frame:IsShown() then
    frame:Hide(); db.oculto = true
  else
    frame:Show(); db.oculto = false
  end
end

-- 7.9.2: hace que un panel se pueda desplazar cuando no cabe en la ventana.
-- El panel pasa a ser el hijo de un ScrollFrame con sus mismos anclajes; su pantalla dice cuánto alto necesita
-- con :Ajustar(alto). Si cabe, no sale barra; si no, sale una barra fina a la derecha (rueda o arrastrar).
function GL.Desplazable(panel)
  local padre = panel:GetParent()
  local puntos = {}
  for i = 1, (panel:GetNumPoints() or 0) do puntos[i] = { panel:GetPoint(i) } end
  local sf = CreateFrame("ScrollFrame", nil, padre)
  for _, pt in ipairs(puntos) do sf:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
  if sf.SetClipsChildren then sf:SetClipsChildren(true) end
  panel:ClearAllPoints()
  panel:SetParent(sf)
  sf:SetScrollChild(panel)
  panel:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)

  local barra = CreateFrame("Frame", nil, padre)
  barra:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, 0)
  barra:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 0)
  barra:SetWidth(4)
  local fondo = barra:CreateTexture(nil, "BACKGROUND")
  fondo:SetAllPoints(barra)
  fondo:SetColorTexture(1, 1, 1, 0.08)
  local pulgar = CreateFrame("Frame", nil, barra)
  pulgar:SetWidth(4)
  local tono = pulgar:CreateTexture(nil, "ARTWORK")
  tono:SetAllPoints(pulgar)
  local a = (GL.COLOR and GL.COLOR.acento) or { 0.4, 0.67, 0.94 }
  tono:SetColorTexture(a[1] or 0.4, a[2] or 0.67, a[3] or 0.94, 0.9)
  barra:Hide()

  local d = { sf = sf, barra = barra, necesario = 0, pos = 0 }
  local function Rango() return math.max(0, d.necesario - (sf:GetHeight() or 0)) end
  local function Colocar()
    local h, r = sf:GetHeight() or 0, Rango()
    d.pos = math.max(0, math.min(d.pos, r))
    sf:SetVerticalScroll(d.pos)
    if r > 0 and h > 0 and panel:IsShown() then
      local c = (GL.COLOR and GL.COLOR.acento) or a
      tono:SetColorTexture(c[1] or 0.4, c[2] or 0.67, c[3] or 0.94, 0.9)   -- sigue al tema
      local alto = math.max(20, h * h / d.necesario)
      pulgar:SetHeight(alto)
      pulgar:ClearAllPoints()
      pulgar:SetPoint("TOP", barra, "TOP", 0, -((h - alto) * d.pos / r))
      barra:Show()
    else
      barra:Hide()
    end
  end
  function d:Ajustar(necesario)
    d.necesario = math.ceil(necesario or 0)
    panel:SetWidth(math.max(1, sf:GetWidth() or 1))
    panel:SetHeight(math.max(sf:GetHeight() or 1, d.necesario))
    Colocar()
  end
  function d:Arriba() d.pos = 0; Colocar() end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(_, delta) d.pos = d.pos - delta * 40; Colocar() end)
  sf:SetScript("OnSizeChanged", function() d:Ajustar(d.necesario) end)
  pulgar:EnableMouse(true)
  pulgar:SetScript("OnMouseDown", function()
    local _, y0 = GetCursorPosition()
    local escala, p0 = barra:GetEffectiveScale(), d.pos
    pulgar:SetScript("OnUpdate", function()
      if not IsMouseButtonDown("LeftButton") then pulgar:SetScript("OnUpdate", nil); return end
      local _, y = GetCursorPosition()
      local h = sf:GetHeight() or 1
      local libre = math.max(1, h - pulgar:GetHeight())
      d.pos = p0 + (y0 - y) / escala * Rango() / libre
      Colocar()
    end)
  end)
  -- el ScrollFrame se ve y se esconde con su panel, para no quitar la rueda a las otras pantallas
  hooksecurefunc(panel, "Show", function() sf:Show(); Colocar() end)
  hooksecurefunc(panel, "Hide", function() sf:Hide(); barra:Hide() end)
  if not panel:IsShown() then sf:Hide() end
  return d
end

-- 7.9.1: engancha una función al tooltip de objetos sin romper el archivo que la pide.
-- Prueba OnTooltipSetItem y, si el cliente no lo tiene, TooltipDataProcessor. Lo que falle queda en el informe.
GL.erroresCarga = GL.erroresCarga or {}
function GL.EngancharTooltipObjeto(fn, nombre)
  if not GameTooltip then return false end
  local ok = false
  if GameTooltip.HasScript and GameTooltip.HookScript then
    local okH, tiene = pcall(GameTooltip.HasScript, GameTooltip, "OnTooltipSetItem")
    if okH and tiene then ok = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", fn) end
  end
  if not ok and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    ok = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(t) if t == GameTooltip then fn(t) end end)
  end
  if not ok then table.insert(GL.erroresCarga, (nombre or "tooltip") .. GL.L": el juego no deja ampliar el tooltip de objetos") end
  return ok
end
GL.MostrarInforme, GL.InformeDiagnostico, GL.TextoAtascos, GL.FotoPaso = MostrarInforme, InformeDiagnostico, TextoAtascos, FotoPaso   -- 9.1
GL.SeccionPorNivel, GL.PuedeSaltar, GL.Sincronizar = SeccionPorNivel, PuedeSaltar, Sincronizar   -- 9.1
GL.Marcar, GL.Marcado = Marcar, Marcado   -- 9.1
GL.colores = { AZUL = AZUL, AMARILLO = AMARILLO, VERDE = VERDE, GRIS = GRIS, BLANCO = BLANCO, FIN = FIN }
GL.COLOR = COLOR
GL.LADO = LADO   -- 9.0: Barra9.lua añade Grupo y Buscar
GL.COLORES_DIST = { cerca = { 0.25, 0.85, 0.35 }, medio = { 1, 0.82, 0.2 }, lejos = { 1, 0.40, 0.33 } }   -- 9.0
GL.PROXIMA = GL.L"|cffff9933Próxima actualización:|r "   -- 7.4: partes aún sin completar (datos pendientes)
GL.TEMAS, GL.BuscarTema = TEMAS, BuscarTema
GL.PorTema = PorTema
-- Opciones cambia el tema al momento: se guarda, se cambian los colores y se repinta todo lo creado.
GL.CambiarTema = function(id)
  local t = AplicarTema(id)
  if type(GuiaAventureroDB) == "table" then GuiaAventureroDB.tema = t.id end
  GL.temaActivo = t.id
  for i = 1, #alCambiarTema do
    local ok, err = pcall(alCambiarTema[i])
    if not ok and GL.Fallo("tema", err) then Mensaje(GL.L"error al repintar el tema: " .. tostring(err)) end
  end
  if frame then Refrescar() end
end
-- Opciones cambia el tamano del texto del paso sin recargar.
GL.AplicarTamTexto = function()
  if ui.pasoTexto and ui.fuentePaso then ui.pasoTexto:SetFont(ui.fuentePaso, TamTextoPaso(), ui.opcionesPaso) end
  if frame and frame:IsShown() then Refrescar() end
end
GL.ICONO_ACCION, GL.ICONO_HECHO, GL.ICONO_LUGAR, GL.INTERROGANTE = ICONO_ACCION, ICONO_HECHO, ICONO_LUGAR, INTERROGANTE
GL.RUTA_FLECHA, GL.BLANCO8, GL.BORDE_VENTANA, GL.AUTOR = RUTA_FLECHA, BLANCO8, BORDE_VENTANA, AUTOR
GL.MARGEN, GL.ARRIBA, GL.ABAJO, GL.ALTO_SUB = MARGEN, ARRIBA, ABAJO, ALTO_SUB
GL.PosicionJugador, GL.Vector = PosicionJugador, Vector
GL.AUTOMATISMOS = AUTOMATISMOS
-- 6.2: desvío (la flecha va a un destino sin cambiar de paso) y saltar al paso de un destino
GL.SeguirDesvio = function(d)
  destinoExtra = d
  if frame then Refrescar() end
end
GL.AbrirProfesion976 = function(skill)
  if not (RUTA and RUTA.profesiones and GuiaAventureroDB) then return end
  for i,prof in ipairs(RUTA.profesiones) do
    if prof.skill==skill and not prof.vacia then GuiaAventureroDB.profesion=i; GuiaAventureroDB.profesionSkill=skill; AbrirModo("oficios"); return true end
  end
  if GL.MostrarInforme then GL.MostrarInforme(GL.L"Esta profesión no está aprendida por tu personaje. Consulta su guía en Biblioteca.") end
  return false
end
GL.IrAPaso = function(s, p, i)
  local db = GuiaAventureroDB
  db.seccion, db.paso, db.destino = s, p, i or 1
  destinoExtra = nil
  bloqueo = PuedeSaltar(s, p) and (s .. ":" .. p) or false   -- como al ir a mano con Anterior
  if frame then frame:Show(); db.oculto = false; AbrirModo("guia") end
end
-- 9.1: mover la guía a un paso sin abrir la ventana (Recalcular.lua); la sincronización sigue luego como siempre
GL.SaltarA = function(s, p, i)
  local db = GuiaAventureroDB
  if not (RUTA and RUTA.secciones[s] and RUTA.secciones[s].pasos[p]) then return false end
  db.seccion, db.paso, db.destino = s, p, i or 1
  destinoExtra = nil
  bloqueo = false
  ProgramarSync()
  return true
end
GL.ui = ui
GL.Mensaje, GL.Colorear, GL.Seguro, GL.Mostrar, GL.Rango = Mensaje, Colorear, Seguro, Mostrar, Rango
GL.MaterialesPaso = MaterialesPaso   -- 9.0
GL.Color, GL.Caja, GL.PonerIcono, GL.Texto, GL.UnaLinea, GL.Ayuda = Color, Caja, PonerIcono, Texto, UnaLinea, Ayuda
GL.Sombra, GL.Acento, GL.Marco4 = Sombra, Acento, Marco4
GL.CrearBoton, GL.CrearMarcoIcono, GL.CrearBarra, GL.Alto = CrearBoton, CrearMarcoIcono, CrearBarra, Alto
GL.PasoActual, GL.DestinoActual, GL.DestinoHecho, GL.EstadoPaso = PasoActual, DestinoActual, DestinoHecho, EstadoPaso
GL.ProgresoDestino, GL.MisionEnDiario, GL.MisionCompletada = ProgresoDestino, MisionEnDiario, MisionCompletada
GL.ObjetivosListos = ObjetivosListos   -- 9.7.4: ventana compacta
GL.HechizoConocido, GL.NivelProfesion = HechizoConocido, NivelProfesion
GL.NumSecciones, GL.PosicionEnRuta = NumSecciones, PosicionEnRuta
GL.ClaveDestino, GL.PasoDespues = ClaveDestino, PasoDespues   -- 8.8
GL.Refrescar, GL.ProgramarRefresco, GL.ProgramarSync = Refrescar, ProgramarRefresco, ProgramarSync
GL.Siguiente, GL.Anterior, GL.IrAMiNivel, GL.AbrirModo = Siguiente, Anterior, IrAMiNivel, AbrirModo
GL.AlternarFlecha, GL.AlternarAuto = AlternarFlecha, AlternarAuto

-- Idioma.lua (9.3.5): idioma de la guía. Los textos se escriben en español en el código y pasan por GL.L:
-- en español sale el texto tal cual; en inglés sale su traducción de Idioma\enUS*.lua (si no hay, el español).
-- El idioma es el del cliente (enUS o enGB: inglés; el resto: español) salvo que se elija otro en Ajustes > General
-- o con /ga idioma es|en|auto (se guarda en la cuenta y vale al recargar).
-- Las traducciones de las rutas y de los datos van en un texto aparte que solo se lee si la guía está en inglés.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end

local cliente = "esES"
if type(GetLocale) == "function" then
  local ok, valor = pcall(GetLocale)
  local secreto = false
  if ok and type(issecretvalue) == "function" then
    local comprobado, resultado = pcall(issecretvalue, valor)
    secreto = not comprobado or resultado == true
  end
  if ok and not secreto and type(valor) == "string" and valor ~= "" then cliente = valor end
end
GL.clienteIngles = (cliente == "enUS" or cliente == "enGB")
GL.ingles = GL.clienteIngles

local EN = {}          -- texto en español -> texto en inglés
local bloques = {}     -- traducciones guardadas como texto (rutas, datos): se leen solo en inglés
GL.textosIngles = EN

-- Idioma\enUS*.lua añaden sus tablas con esto. Una tabla se mezcla ya; un texto ("return { ... }") se guarda
-- y solo se convierte en tabla si la guía sale en inglés.
-- destino = "misiones": la tabla es [id de misión] = nombre inglés (GL.misionesIngles).
GL.misionesIngles = {}
function GL.AnadirIngles(t, destino)
  local tabla = (destino == "misiones") and GL.misionesIngles or EN
  if type(t) == "table" then
    for k, v in pairs(t) do tabla[k] = v end
  elseif type(t) == "string" then
    table.insert(bloques, { t, tabla })
  end
end

local function LeerBloques()
  if #bloques == 0 then return end
  local cargar = loadstring or load
  for i = 1, #bloques do
    local compilado, f = false, nil
    if type(cargar) == "function" then compilado, f = pcall(cargar, bloques[i][1]) end
    if compilado and type(f) == "function" then
      local ok, t = pcall(f)
      if ok and type(t) == "table" then
        local tabla = bloques[i][2]
        for k, v in pairs(t) do if tabla[k] == nil then tabla[k] = v end end
      end
    end
  end
  bloques = {}
  collectgarbage("collect")
end

-- Formatos de presentación según el idioma elegido para la guía.
function GL.FormatoMiles(n)
  local s = tostring(math.floor((n or 0) + 0.5))
  local signo = s:sub(1, 1) == "-" and "-" or ""
  if signo ~= "" then s = s:sub(2) end
  local sep = GL.ingles and "," or "."
  local r = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if r:sub(1, 1) == sep then r = r:sub(2) end
  return signo .. r
end
function GL.FormatoDecimal(texto)
  if GL.ingles then return texto end
  return (texto:gsub("%.", ","))
end

-- 9.4.2: la letra del juego no tiene ▲ ✓ ★ ▶ ■ → (salían como cuadrados vacíos). GL.Simbolos los cambia por
-- iconos pequeños de la carpeta Iconos, del color del texto que los rodea (|cffRRGGBB) o del suyo por defecto.
local ICONOS = "Interface\\AddOns\\GuiaAventurero\\Iconos\\"
local SIMBOLOS = {   -- símbolo = { icono, color por defecto (r, g, b de 0 a 255) }
  ["▲"] = { "arriba", 64, 217, 89 }, ["↑"] = { "arriba", 64, 217, 89 },
  ["▼"] = { "abajo", 240, 80, 80 }, ["▾"] = { "abajo", 200, 200, 210 },
  ["→"] = { "derecha", 200, 200, 210 }, ["➜"] = { "derecha", 255, 209, 0 },
  ["▶"] = { "triangulo", 64, 217, 89 }, ["■"] = { "cuadro", 200, 200, 210 },
  ["★"] = { "estrella", 255, 209, 0 }, ["✓"] = { "ok", 64, 217, 89 }, ["✔"] = { "ok", 64, 217, 89 },
  ["⚠"] = { "aviso", 255, 112, 112 },
}
local function Icono(sim, r, g, b)
  local d = SIMBOLOS[sim]
  return "|T" .. ICONOS .. d[1] .. ":0:0:0:0:32:32:0:32:0:32:" .. (r or d[2]) .. ":" .. (g or d[3]) .. ":" .. (b or d[4]) .. "|t"
end
local function Simbolos(s)
  if type(s) ~= "string" or not s:find("[\226]") then return s end
  local fuera, color, i = {}, nil, 1
  while i <= #s do
    local cc = s:match("^|c%x%x(%x%x%x%x%x%x)", i)
    if cc then color = cc; table.insert(fuera, s:sub(i, i + 9)); i = i + 10
    elseif s:sub(i, i + 1) == "|r" then color = nil; table.insert(fuera, "|r"); i = i + 2
    else
      local hecho
      for sim in pairs(SIMBOLOS) do
        if s:sub(i, i + #sim - 1) == sim then
          local r, g, b
          if color then r, g, b = tonumber(color:sub(1, 2), 16), tonumber(color:sub(3, 4), 16), tonumber(color:sub(5, 6), 16) end
          table.insert(fuera, Icono(sim, r, g, b)); i = i + #sim; hecho = true; break
        end
      end
      if not hecho then table.insert(fuera, s:sub(i, i)); i = i + 1 end
    end
  end
  return table.concat(fuera)
end
GL.Simbolos = Simbolos
GL.Icono = Icono

local function Traducir(s)
  if type(s) ~= "string" then return s end
  if not GL.ingles then return Simbolos(s) end
  if #bloques > 0 then LeerBloques() end
  return Simbolos(EN[s] or s)
end

-- Los nombres que da el juego (zonas, rutas de vuelo, profesiones) van en el idioma del cliente: así se pueden
-- comparar con lo que dice el juego, sea cual sea el idioma de la guía.
local function TraducirCliente(s)
  if not GL.clienteIngles or type(s) ~= "string" then return s end
  if #bloques > 0 then LeerBloques() end
  return EN[s] or s
end
GL.LC = TraducirCliente

-- L"texto" o L["texto"]: el texto en el idioma de la guía
GL.L = setmetatable({}, {
  __index = function(_, k) return Traducir(k) end,
  __call = function(_, k) return Traducir(k) end,
})
GL.T = Traducir
-- El nombre inglés de un texto, sea cual sea el idioma de la guía (para reconocer lo que dice un cliente en inglés)
function GL.EnIngles(s)
  if type(s) ~= "string" then return s end
  return EN[s] or s
end

-- El idioma elegido en la cuenta (las variables guardadas llegan con ADDON_LOADED). Lo que se crea al
-- iniciar la guía (después) ya sale en ese idioma; un cambio de idioma vale del todo al recargar (/reload).
function GL.IdiomaElegido()
  local c = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.idioma
  if c == "es" or c == "en" then return c end
  return "auto"
end

function GL.PonerIdioma(codigo)
  if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
  if codigo == "es" or codigo == "en" then GuiaAventureroCuenta.idioma = codigo else GuiaAventureroCuenta.idioma = nil end
end

-- 9.5: el addon se llamaba GuiaLeveo. Si el jugador renombra sus archivos de WTF\...\SavedVariables de
-- GuiaLeveo.lua a GuiaAventurero.lua, lo guardado llega con los nombres de antes: se pasa a los nuevos.
-- Este es el primer ADDON_LOADED del addon (Idioma.lua va primero en el .toc), así que los demás ya lo ven.
local function TraerNombreViejo()
  for _, par in ipairs({ { "GuiaLeveoCuenta", "GuiaAventureroCuenta" }, { "GuiaLeveoRespaldo", "GuiaAventureroRespaldo" },
      { "GuiaLeveoDB", "GuiaAventureroDB" } }) do
    local viejo = _G[par[1]]
    if type(viejo) == "table" and (type(_G[par[2]]) ~= "table" or next(_G[par[2]]) == nil) then _G[par[2]] = viejo end
    _G[par[1]] = nil
  end
end
GL._TraerNombreViejo = TraerNombreViejo   -- para las pruebas

-- 9.7.4: lo guardado por versiones anteriores puede tener un dato con otro tipo (una tabla donde ahora va
-- un número, un texto donde va una tabla...). Con eso la ventana no se abría. Se quita y vale lo de serie.
local TIPOS_DB = {
  table = { "aprendidosFuera", "atascos", "domadas", "establo", "estadisticas", "gSec", "ignorados", "mazMuertos", "mazNo",
    "notas", "pescaGuardado", "pescaPos", "pos", "posBuffs", "posCompacto", "posFlecha", "posFranja", "posMazmorra",
    "posNormal", "rangosIgnorados", "recalculos", "resumenActual", "resumenes", "sesionAnterior", "tam", "titulos",
    "vigiladas", "vuelos", "vuelosNPC" },
  number = { "escala", "alphaVentana", "escalaFlecha", "opacidad", "anguloMinimapa", "tamTexto" },
  boolean = { "alturaFlecha" },
  string = { "especializacion", "rutaElegida", "ruta" },
}
-- Límites de los deslizadores existentes (Opciones.lua).
local LIMITES_DB = {
  escala = { 0.6, 1.5 }, alphaVentana = { 0.3, 1 },
  escalaFlecha = { 0.6, 2 }, opacidad = { 0.2, 1 }, tamTexto = { 0.8, 1.5 },
}
local function LimpiarGuardado()
  local db = GuiaAventureroDB
  if type(db) ~= "table" then return 0 end
  local n = 0
  for tipo, claves in pairs(TIPOS_DB) do
    for _, k in ipairs(claves) do
      local v = db[k]
      if v ~= nil then
        if tipo == "number" then
          local numero = (type(v) == "number" or type(v) == "string") and tonumber(v)
          if not numero or numero ~= numero or numero == math.huge or numero == -math.huge then
            db[k] = nil; n = n + 1
          else
            local limites = LIMITES_DB[k]
            if limites then numero = math.max(limites[1], math.min(limites[2], numero)) end
            if k == "anguloMinimapa" then numero = numero % 360 end
            if type(v) ~= "number" or v ~= numero then db[k] = numero; n = n + 1 end
          end
        elseif type(v) ~= tipo then
          db[k] = nil; n = n + 1
        end
      end
    end
  end
  -- estadísticas: sus partes también
  local e = db.estadisticas
  if type(e) == "table" and e.niveles ~= nil and type(e.niveles) ~= "table" then e.niveles = {}; n = n + 1 end
  if type(e) == "table" and e.niveles == nil then e.niveles = {} end
  return n
end
GL._LimpiarGuardado = LimpiarGuardado   -- para las pruebas

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, _, nombre)
  if nombre ~= "GuiaAventurero" then return end
  self:UnregisterEvent("ADDON_LOADED")
  pcall(TraerNombreViejo)
  pcall(LimpiarGuardado)
  local c = GL.IdiomaElegido()
  if c == "en" then GL.ingles = true elseif c == "es" then GL.ingles = false else GL.ingles = GL.clienteIngles end
  if GL.ingles or GL.clienteIngles then LeerBloques() else bloques = {} end
  if GL.TraducirDatos then GL.TraducirDatos(GL.WH) end   -- los opcionales se traducen al juntarlos (Continentes.lua)
end)

------------------------------------------------------------------------
-- Rutas en inglés: al cargar la ruta se cambian sus textos por los ingleses.
-- Los destinos «Recoger: misión (PNJ)» se rehacen con el nombre inglés de la misión (por su id) y del PNJ.
------------------------------------------------------------------------
local PREFIJOS = { ["Recoger"] = "Accept", ["Entregar"] = "Turn in", ["Objetivo"] = "Objective" }
GL.prefijosIngles = PREFIJOS

-- GL.misionesIngles[id] = nombre inglés de la misión (Idioma\enUS_Nombres.lua)
local function NombreMision(q, es)
  local t = GL.misionesIngles
  if q and t and t[q] then return t[q] end
  return Traducir(es)
end
GL.NombreMisionIngles = NombreMision

local function TraducirDestino(d)
  if GL.ingles and type(d.n) == "string" then
    local pre, resto = d.n:match("^([^:]+): (.+)$")
    if pre and PREFIJOS[pre] then
      local mision, pnj = resto:match("^(.*) %(([^()]*)%)$")
      if not mision then mision, pnj = resto:match("^(.-) %((.-)%)$") end
      if not mision then mision = resto end
      local t = PREFIJOS[pre] .. ": " .. NombreMision(d.q, mision)
      if pnj then t = t .. " (" .. Traducir(pnj) .. ")" end
      d.n = t
    else
      d.n = Traducir(d.n)
    end
  end
  if d.z then d.z = TraducirCliente(d.z) end
end
GL.TraducirDestino = TraducirDestino

-- Textos de la guía (idioma de la guía) y nombres del juego (idioma del cliente). Los nombres de los talentos
-- no se tocan: ya llevan los dos idiomas («Ferocidad (Ferocity)») y así se buscan en el árbol.
local GUIA = { "t", "nota", "notaDespues", "titulo", "entrenar", "equipo", "profesion", "intro", "talentosIntro",
  "nombre", "rama", "misionNombre", "instructor", "desc", "d" }
local CLIENTE = { "z", "zona", "vuelo", "lugar" }

local function TraducirTabla(t, vistos, talentos)
  if type(t) ~= "table" or vistos[t] then return end
  vistos[t] = true
  if t.wp == nil and type(t.n) == "string" and (t.m or t.x) then TraducirDestino(t) end
  if GL.ingles then
    for _, k in ipairs(GUIA) do
      if type(t[k]) == "string" and not (k == "nombre" and (talentos or t.skill)) then t[k] = Traducir(t[k]) end
    end
  end
  for _, k in ipairs(CLIENTE) do
    if type(t[k]) == "string" then t[k] = TraducirCliente(t[k]) end
  end
  if t.skill and type(t.nombre) == "string" then t.nombre = TraducirCliente(t.nombre) end   -- profesiones: como en el juego
  for k, v in pairs(t) do
    if type(v) == "table" then
      if k == "wp" then
        for _, d in ipairs(v) do if type(d) == "table" then TraducirDestino(d) end end
      else
        TraducirTabla(v, vistos, talentos)
      end
    end
  end
end

-- Un plan de talentos: rama y nota en inglés; «Ferocidad (Ferocity)» pasa a «Ferocity (Ferocidad)» (Talentos.lua
-- busca los dos nombres, en cualquier orden).
function GL.TraducirTalentos(lista)
  if not GL.ingles or type(lista) ~= "table" then return end
  for _, t in ipairs(lista) do
    if type(t) == "table" and not t.traducido then
      t.traducido = true
      if type(t.rama) == "string" then t.rama = Traducir(t.rama) end
      if type(t.nota) == "string" then t.nota = Traducir(t.nota) end
      local es, en
      if type(t.nombre) == "string" then es, en = t.nombre:match("^(.-)%s*%((.-)%)%s*$") end
      if es and en and en ~= "" then t.nombre = en .. " (" .. es .. ")" end
    end
  end
end

-- Se llama tras cargar la ruta (GuiaAventurero.lua, Iniciar). Las ramas se cambian en todas partes por igual
-- (ramas, talentos, especialidades y ramaHechizo) para que sigan casando entre sí.
function GL.TraducirRuta(R)
  if not (GL.ingles or GL.clienteIngles) or type(R) ~= "table" or R.traducida then return end
  R.traducida = true
  local vistos = {}
  if type(R.talentos) == "table" then vistos[R.talentos] = true; GL.TraducirTalentos(R.talentos) end
  if GL.ingles then
    for i, e in ipairs(R.especialidades or {}) do R.especialidades[i] = Traducir(e) end
    for id, r in pairs(R.ramaHechizo or {}) do
      if type(r) == "string" then R.ramaHechizo[id] = Traducir(r)
      elseif type(r) == "table" then for i, x in ipairs(r) do r[i] = Traducir(x) end end
      vistos[r] = true
    end
    if type(R.especialidades) == "table" then vistos[R.especialidades] = true end
    if type(R.nombresPropios) == "table" then vistos[R.nombresPropios] = true end
  end
  for k, v in pairs(R) do
    if type(v) == "table" then TraducirTabla(v, vistos)
    elseif type(v) == "string" and GL.ingles and (k == "nombre" or k == "talentosIntro" or k == "instructor") then R[k] = Traducir(v) end
  end
end

------------------------------------------------------------------------
-- Datos (DatosWowhead.lua y los opcionales de Continentes.lua): sus textos cortos y nombres en inglés.
-- Lo que tiene nombre inglés propio (ing) lo usa; los jefes van como en el juego (se reconocen al morir).
------------------------------------------------------------------------
local DATOS = { "n", "d", "de", "donde", "r", "desc", "quien", "vendedor", "como", "fuente", "nota", "t", "titulo",
  "rol", "mat", "nombre", "lado" }
local LISTAS_GUIA = { armas = true }
local LISTAS_CLIENTE = { zonas = true }

local function TraducirDato(t, vistos, jefes)
  if type(t) ~= "table" or vistos[t] then return end
  vistos[t] = true
  if t.wp == nil and type(t.n) == "string" and (t.m or t.x) and t.n:find(": ", 1, true) then
    TraducirDestino(t)
  elseif type(t.n) == "string" then
    if jefes then
      t.nombreOriginal977 = t.nombreOriginal977 or t.n
      t.n = (GL.clienteIngles and t.ing) or TraducirCliente(t.nombreOriginal977)
    elseif GL.ingles then t.n = t.ing or Traducir(t.n) end
  end
  if t.sp and type(t.r) == "string" then t.recetaOriginal9775 = t.recetaOriginal9775 or t.r end
  if GL.ingles then
    for _, k in ipairs(DATOS) do
      if k ~= "n" and type(t[k]) == "string" then t[k] = Traducir(t[k]) end
    end
  end
  for _, k in ipairs(CLIENTE) do
    if type(t[k]) == "string" then t[k] = TraducirCliente(t[k]) end
  end
  for k, v in pairs(t) do
    if type(v) == "table" then
      if k == "wp" then
        for _, d in ipairs(v) do if type(d) == "table" then TraducirDestino(d) end end
      elseif LISTAS_GUIA[k] or LISTAS_CLIENTE[k] then
        local f = LISTAS_GUIA[k] and Traducir or TraducirCliente
        for i, x in ipairs(v) do if type(x) == "string" then v[i] = f(x) end end
      else
        if GL.ingles and type(k) == "number" and v.wp and type(v.n) == "string" then v.n = NombreMision(k, v.n) end
        TraducirDato(v, vistos, jefes or k == "jefes")
      end
    end
  end
end

function GL.TraducirDatos(t)
  if not (GL.ingles or GL.clienteIngles) or type(t) ~= "table" then return end
  TraducirDato(t, {}, false)
end

------------------------------------------------------------------------
-- Ajustes > General: Idioma (Automático, Español, English). Vale al recargar la interfaz.
------------------------------------------------------------------------
local L = GL.L
local function AvisarRecarga()
  local nombres = { auto = L"automático (el del juego)", es = "español", en = "English" }
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fb3ff" .. L"Guía del Aventurero" .. ":|r " .. L"idioma: " .. nombres[GL.IdiomaElegido()] ..
      ". " .. L"Escribe /reload para cambiarlo.")
  end
end

-- /ga idioma es|en|auto
function GL.ComandoIdioma(arg)
  arg = (type(arg) == "string" and arg or ""):match("^%s*(.-)%s*$"):lower()
  if arg == "es" or arg == "español" or arg == "espanol" then GL.PonerIdioma("es")
  elseif arg == "en" or arg == "english" or arg == "inglés" or arg == "ingles" then GL.PonerIdioma("en")
  elseif arg == "auto" or arg == "automático" or arg == "automatico" then GL.PonerIdioma("auto")
  else
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(L"Uso: /ga idioma es|en|auto")
    end
    return
  end
  AvisarRecarga()
end

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "idioma", "Idioma de la guía (Language)",
  "Automático: el del juego. Español o English: siempre ese. Vale al recargar (/reload).",
  function() return GL.IdiomaElegido() end,
  function(v) GL.PonerIdioma(v); AvisarRecarga() end,
  opciones = { { "auto", "Automático" }, { "es", "Español" }, { "en", "English" } }, pestana = "general" })

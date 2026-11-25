-- Tiempos.lua (9.2): tipo de cada paso (con su icono) y lo que tarda a TU ritmo.
--  · Tipo: aceptar, matar o recoger, entregar, vuelo, instructor, piedra de hogar o ir a un sitio.
--  · Tiempo de un paso, por orden: lo que tardaste tú (este personaje) en ese paso; lo que tarda la cuenta en ese
--    paso corregido por tu ritmo (si vas un 15 % más rápido que la media, un 15 % menos); lo que tardas tú en pasos
--    del mismo tipo; la media de la cuenta; y si no hay nada, 4 min.
-- Lo guarda Guia9.lua al pasar de paso: GuiaAventureroCuenta.pasos9[ruta][clave] = { t (media), n, xp } y, por personaje,
-- GuiaAventureroDB.tiempos9[ruta][clave] = segundos.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local POR_DEFECTO = 240

local function DB() return GuiaAventureroDB or {} end
local function Num(v) v = (GL.Seguro and GL.Seguro(v)) or v; return type(v) == "number" and v or nil end
local function IdRuta() return (GL.RUTA and GL.RUTA.id) or "?" end

------------------------------------------------------------------------
-- Tipo de paso
------------------------------------------------------------------------
local TIPOS = {
  aceptar = { n = L"Aceptar", icono = "Interface\\GossipFrame\\AvailableQuestIcon", color = { 1, 0.82, 0 } },
  matar = { n = L"Matar o recoger", icono = "Interface\\Icons\\INV_Sword_04", color = { 0.97, 0.44, 0.44 } },
  entregar = { n = L"Entregar", icono = "Interface\\GossipFrame\\ActiveQuestIcon", color = { 0.29, 0.87, 0.5 } },
  vuelo = { n = L"Vuelo", icono = "Interface\\Icons\\Ability_Mount_Wyvern_01", color = { 0.29, 0.76, 1 } },
  instructor = { n = L"Instructor", icono = "Interface\\Icons\\INV_Misc_Book_09", color = { 0.66, 0.6, 1 } },
  hogar = { n = L"Piedra de hogar", icono = "Interface\\Icons\\INV_Misc_Rune_01", color = { 0.98, 0.57, 0.24 } },
  ir = { n = L"Ir a un sitio", icono = "Interface\\Icons\\INV_Misc_Map_01", color = { 0.77, 0.78, 0.83 } },
}
GL.TIPOS_PASO = TIPOS

local cacheTipo = setmetatable({}, { __mode = "k" })
local function Tipo(p)
  if type(p) ~= "table" then return "ir", TIPOS.ir end
  local c = cacheTipo[p]
  if c then return c, TIPOS[c] end
  local t = string.lower(tostring(p.t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  local a, cc, e = false, false, false
  for _, d in ipairs(p.wp or {}) do
    if d.a == "A" then a = true elseif d.a == "C" then cc = true elseif d.a == "T" then e = true end
  end
  local r
  if cc then r = "matar"
  elseif e then r = "entregar"
  elseif a then r = "aceptar"
  elseif t:find(L"piedra de hogar", 1, true) or t:find(L"^usa la piedra") then r = "hogar"
  elseif t:find(L"vuel[ao]") or t:find("grifo") or t:find(L"dracoleón") or t:find(L"murciélago") or t:find("hipogrifo") or t:find("wyvern") then r = "vuelo"
  elseif t:find("entrena") or t:find("instructor") then r = "instructor"
  else r = "ir" end
  cacheTipo[p] = r
  return r, TIPOS[r]
end
GL.TipoPaso = Tipo

-- Icono pequeño para meter en un texto
function GL.IconoTipo(p, tam)
  local _, t = Tipo(p)
  return "|T" .. t.icono .. ":" .. (tam or 12) .. ":" .. (tam or 12) .. "|t"
end

------------------------------------------------------------------------
-- Datos guardados
------------------------------------------------------------------------
local function Cuenta()
  local c = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.pasos9
  local t = type(c) == "table" and c[IdRuta()]
  return type(t) == "table" and t or {}
end
local function Mios()
  local db = DB()
  local t = type(db.tiempos9) == "table" and db.tiempos9[IdRuta()]
  return type(t) == "table" and t or {}
end

-- Lo llama Guia9.lua al acabar un paso
function GL.GuardarTiempoPaso(clave, seg, xp)
  if type(clave) ~= "string" or not Num(seg) then return end
  if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
  local c = GuiaAventureroCuenta
  c.pasos9 = type(c.pasos9) == "table" and c.pasos9 or {}
  local id = IdRuta()
  c.pasos9[id] = type(c.pasos9[id]) == "table" and c.pasos9[id] or {}
  local v = c.pasos9[id][clave]
  if type(v) ~= "table" or not Num(v.t) then v = { t = seg, n = 1, xp = xp }
  else
    local n = Num(v.n) or 1
    v.t = math.floor((v.t * n + seg) / (n + 1) + 0.5)
    v.n = math.min(n + 1, 20)   -- media móvil: las últimas veces pesan más que las de hace meses
    if xp and xp > 0 then v.xp = xp end
  end
  c.pasos9[id][clave] = v
  local db = DB()
  db.tiempos9 = type(db.tiempos9) == "table" and db.tiempos9 or {}
  db.tiempos9[id] = type(db.tiempos9[id]) == "table" and db.tiempos9[id] or {}
  db.tiempos9[id][clave] = math.floor(seg)
  GL.TiemposCambiaron()
end

------------------------------------------------------------------------
-- Tu ritmo frente a la cuenta, y tus medias por tipo
------------------------------------------------------------------------
local cache
function GL.TiemposCambiaron() cache = nil end

local function PasoDeClave(clave)
  local s, p = string.match(clave, "^(%d+):(%d+)$")
  local R = GL.RUTA
  local sec = R and s and R.secciones[tonumber(s)]
  return sec and sec.pasos[tonumber(p)]
end

local function Calcular()
  if cache then return cache end
  local mios, cuenta = Mios(), Cuenta()
  local sm, sc, pares, nMios = 0, 0, 0, 0
  local porTipo = {}
  for clave, t in pairs(mios) do
    t = Num(t)
    if t then
      nMios = nMios + 1
      local v = cuenta[clave]
      -- solo pasos que también hizo otro personaje (n >= 2): si no, la media de la cuenta es tu propio tiempo
      if type(v) == "table" and Num(v.t) and (Num(v.n) or 1) >= 2 then sm, sc, pares = sm + t, sc + v.t, pares + 1 end
      local p = PasoDeClave(clave)
      if p then
        local tipo = Tipo(p)
        porTipo[tipo] = porTipo[tipo] or { s = 0, n = 0 }
        porTipo[tipo].s, porTipo[tipo].n = porTipo[tipo].s + t, porTipo[tipo].n + 1
      end
    end
  end
  local factor = 1
  if pares >= 5 and sc > 0 then factor = math.max(0.5, math.min(2, sm / sc)) end
  local st, nt = 0, 0
  for _, v in pairs(cuenta) do if type(v) == "table" and Num(v.t) then st, nt = st + v.t, nt + 1 end end
  local medias = {}
  for tipo, x in pairs(porTipo) do if x.n >= 3 then medias[tipo] = x.s / x.n end end
  cache = { factor = factor, pares = pares, nMios = nMios, media = nt >= 3 and st / nt or nil, porTipo = medias }
  return cache
end

-- Tiempo de un paso: segundos y de dónde sale ("tuyo", "cuenta", "tipo", "media" o "fijo")
local function Estimar(s, p)
  local clave = s .. ":" .. p
  local mio = Num(Mios()[clave])
  if mio then return mio, "tuyo" end
  local k = Calcular()
  local v = Cuenta()[clave]
  if type(v) == "table" and Num(v.t) then return v.t * k.factor, "cuenta" end
  local paso = PasoDeClave(clave)
  local tipo = paso and Tipo(paso)
  if tipo and k.porTipo[tipo] then return k.porTipo[tipo], "tipo" end
  if k.media then return k.media * k.factor, "media" end
  return POR_DEFECTO, "fijo"
end
GL.EstimarPaso = Estimar

-- Lo de una sección (desde el paso 'desde', incluido): segundos, pasos con tiempo de verdad, total de pasos
local function EstimarSeccion(s, desde, saltarHechos)
  local R = GL.RUTA
  local sec = R and R.secciones[s]
  if not sec then return 0, 0, 0 end
  local total, conocidos, n = 0, 0, 0
  for i = desde or 1, #sec.pasos do
    local hecho = false
    if saltarHechos and GL.EstadoPaso then
      local ok, e = pcall(GL.EstadoPaso, sec.pasos[i]); hecho = ok and e == "hecho"
    end
    if not hecho then
      local t, f = Estimar(s, i)
      total, n = total + t, n + 1
      if f == "tuyo" or f == "cuenta" then conocidos = conocidos + 1 end
    end
  end
  return total, conocidos, n
end
GL.EstimarSeccion = EstimarSeccion

-- Lo que te queda de ruta desde donde estás: segundos y % de pasos con tiempo de verdad
function GL.EstimarRestoRuta()
  local R, db = GL.RUTA, DB()
  if not R or not db.seccion then return nil end
  local total, conocidos, n = 0, 0, 0
  for s = db.seccion, #R.secciones do
    local t, c, k = EstimarSeccion(s, s == db.seccion and (db.paso or 1) or 1, s == db.seccion)
    total, conocidos, n = total + t, conocidos + c, n + k
  end
  return total, n > 0 and conocidos / n or 0
end

-- Cuánto más rápido o lento vas que la cuenta (0.85 = un 15 % más rápido) y con cuántos pasos se sabe
function GL.TuRitmoPasos()
  local k = Calcular()
  return k.factor, k.pares, k.nMios
end

function GL.FiabilidadTiempos()
  local n = Calcular().nMios
  if n >= 100 then return "alta", n elseif n >= 20 then return "media", n end
  return "baja", n
end

-- Pasos donde más tardas frente a la cuenta: { { titulo, t, media } }
function GL.PasosLentos(max)
  local l = {}
  local cuenta = Cuenta()
  for clave, t in pairs(Mios()) do
    t = Num(t)
    local v = cuenta[clave]
    if t and type(v) == "table" and Num(v.t) and (Num(v.n) or 1) >= 2 and t > v.t * 1.4 and t - v.t >= 120 then
      local p = PasoDeClave(clave)
      if p then table.insert(l, { clave = clave, paso = p, t = t, media = v.t, r = t / v.t }) end
    end
  end
  table.sort(l, function(a, b) return a.r > b.r end)
  while #l > (max or 2) do table.remove(l) end
  return l
end

-- Minutos que tardaste en cada sección (las que tienen al menos la mitad de los pasos medidos)
function GL.MinutosPorSeccion()
  local R = GL.RUTA
  if not R then return {} end
  local suma, n = {}, {}
  for clave, t in pairs(Mios()) do
    local s = tonumber(string.match(clave, "^(%d+):"))
    if s and Num(t) then suma[s], n[s] = (suma[s] or 0) + t, (n[s] or 0) + 1 end
  end
  local l = {}
  for s = 1, #R.secciones do
    if n[s] and n[s] >= #R.secciones[s].pasos / 2 then table.insert(l, { s = s, min = suma[s] / 60 * (#R.secciones[s].pasos / n[s]) }) end
  end
  return l
end

-- Etiqueta del paso actual: icono, tipo y «tú: ~9 min · media 12»
function GL.EtiquetaPaso(s, p)
  local R = GL.RUTA
  local paso = R and R.secciones[s] and R.secciones[s].pasos[p]
  if not paso then return "" end
  local _, ti = Tipo(paso)
  local t, f = Estimar(s, p)
  local v = Cuenta()[s .. ":" .. p]
  local partes = { GL.IconoTipo(paso, 12) .. " " .. C.GRIS .. string.upper(ti.n) .. C.FIN }
  local tu = (f == "tuyo" and L"tú: " or L"tú: ~") .. math.max(1, math.floor(t / 60 + 0.5)) .. L" min"
  if f ~= "fijo" then
    if type(v) == "table" and Num(v.t) and f ~= "cuenta" then tu = tu .. L" · media " .. math.max(1, math.floor(v.t / 60 + 0.5))
    elseif f == "cuenta" and Calcular().factor ~= 1 then tu = tu .. L" · media " .. math.max(1, math.floor(v.t / 60 + 0.5)) end
    table.insert(partes, C.GRIS .. tu .. C.FIN)
  end
  return table.concat(partes, "  ")
end

GL._tiempos = { Tipo = Tipo, Estimar = Estimar, Calcular = function() cache = nil; return Calcular() end, Mios = Mios, Cuenta = Cuenta }

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "iconosPaso", "Iconos y tiempos por tipo de paso",
  "Cada paso con su icono (aceptar, matar, entregar, vuelo, instructor, hogar o ir) y lo que tardas tú en él.",
  function() return DB().iconosPaso ~= false end, function(v) DB().iconosPaso = v; if GL.Refrescar then GL.Refrescar() end end, pestana = "paso" })

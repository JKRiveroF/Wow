-- CazadorBrujo94.lua (9.4): ayudas de clase para cazadores y brujos.
--  · Cazador: pestaña Rangos en Mascotas. Cada habilidad de mascota con sus rangos, el nivel de cada uno y una bestia
--    cercana que lo enseña (se doma, se aprende con Entrenar bestia y se suelta), con Llevarme. Bestias de Bestias.lua.
--  · Avisos nuevos: mascota descontenta (dale de comer, con lo que come) y, para el brujo, sin piedra de salud con
--    fragmentos de sobra. La munición y los fragmentos de alma ya los avisaba la Guía.
-- Rangos de Classic 1.12: en Forever pueden cambiar. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local function Clase() return UnitClass and select(2, UnitClass("player")) end
local function Nivel() return (UnitLevel and UnitLevel("player")) or 1 end

-- habilidad -> niveles de cada rango
local RANGOS = {
  { "mordisco", { 1, 8, 16, 24, 32, 40, 48, 56 } },
  { "zarpa", { 1, 8, 16, 24, 32, 40, 48, 56 } },
  { "cargar", { 1, 12, 24, 36, 48, 60 } },
  { "aliento", { 1, 12, 24, 36, 48, 60 } },
  { "chillido", { 8, 24, 48, 56 } },
  { "veneno", { 8, 24, 40, 56 } },
  { "aullido", { 10, 24, 40, 56 } },
  { "escudo", { 20 } },
  { "carrera", { 30, 40, 50 } },
  { "picado", { 30, 40, 50 } },
  { "acechar", { 30, 40, 50 } },
  { "pisoton", { 30, 40, 50 } },
}
local ROMANO = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

local function Familias(h)
  local r = {}
  for _, f in ipairs((GL.bestias and GL.bestias.familias) or {}) do
    for _, x in ipairs(f.hab or {}) do if x == h then r[f.f] = f end end
  end
  return r
end

-- La bestia que enseña un rango: de una familia con esa habilidad, de nivel entre el del rango y el del siguiente,
-- no más alta que tú (no la podrías domar), sin élites; la más cercana o, si no, la de menos nivel.
local function Maestra(h, desde, hasta)
  local fams, mejor, mejorD = Familias(h), nil, nil
  local tope = math.min(hasta - 1, Nivel())
  for _, b in ipairs((GL.bestias and GL.bestias.lista) or {}) do
    if fams[b.f] and b.min and b.min >= desde and b.min <= tope and not (b.r == 1 or b.r == 2) then
      local d
      if GL.Vector then local ok, _, _, dist = pcall(GL.Vector, b); if ok and type(dist) == "number" then d = dist end end
      if not mejor or (d and (not mejorD or d < mejorD)) or (not d and not mejorD and b.min < mejor.min) then mejor, mejorD = b, d end
    end
  end
  return mejor, mejorD
end

local function Filas()
  local filas, nv = {}, Nivel()
  local H = (GL.bestias and GL.bestias.habilidades) or {}
  for _, e in ipairs(RANGOS) do
    local h, niveles = e[1], e[2]
    local nombre = H[h] and (H[h]:match("^([^:]+)") or H[h]) or h
    local fams = {}
    for _, f in pairs(Familias(h)) do table.insert(fams, f.n) end
    table.sort(fams)
    table.insert(filas, { titulo = true, texto = nombre .. C.GRIS .. "  · " .. #niveles .. (#niveles == 1 and L" rango" or L" rangos") .. C.FIN,
      detalle = table.concat(fams, ", "), ayudaTitulo = nombre, ayudaTexto = H[h] })
    for i, n in ipairs(niveles) do
      local hasta = niveles[i + 1] or 99
      local b, d = nil, nil
      if n <= nv then b, d = Maestra(h, n, hasta) end
      local det
      if n > nv then det = C.GRIS .. L"desde el nivel " .. n .. C.FIN
      elseif b then det = L"Doma: " .. b.n .. C.GRIS .. " (" .. (b.nv or b.min) .. ") · " .. (b.zona or "?") .. (d and (" · " .. math.floor(d) .. " m") or "") .. C.FIN
      else det = C.GRIS .. L"No hay bestia de este rango en la base de datos para tu nivel" .. C.FIN end
      table.insert(filas, { texto = nombre .. " " .. (ROMANO[i] or i) .. C.GRIS .. L"  (nivel " .. n .. ")" .. C.FIN, detalle = det,
        destino = b and b.m and { m = b.m, x = b.x, y = b.y, z = b.zona, n = b.n } or nil,
        ayudaTitulo = nombre .. " " .. (ROMANO[i] or i), ayudaTexto = b and (L"Doma esta bestia, ábrele Entrenar bestia para aprender el rango y suéltala.") or nil })
    end
  end
  return filas
end

local ventana
local function Refrescar()
  if not (ventana and ventana:IsShown()) then return end
  ventana.lista:Poner(Filas(), C.GRIS .. L"Rangos de las habilidades de tu mascota y una bestia cercana que los enseña. Con Entrenar bestia ves los que ya sabes. Rangos de Classic." .. C.FIN)
end
function GL.AbrirRangosMascota()
  ventana = GL.VentanaLista("rangos", L"Rangos de habilidades de mascota", 440, 440)
  if not ventana.hecha then
    ventana.hecha = true
    local espera = 0
    ventana:HookScript("OnUpdate", function(_, dt) espera = espera + dt; if espera >= 3 then espera = 0; Refrescar() end end)
  end
  ventana:Show()
  Refrescar()
end

------------------------------------------------------------------------
-- Avisos (Mejoras.lua llama a GL.avisosExtra; urgencia y nombre de la píldora en sus tablas)
------------------------------------------------------------------------
local PIEDRA_SALUD = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 }
GL.avisosExtra = GL.avisosExtra or {}
table.insert(GL.avisosExtra, function()
  local l, clase = {}, Clase()
  if clase == "HUNTER" and HasPetUI and HasPetUI() and GetPetHappiness then
    local feliz = GetPetHappiness()
    if feliz == 1 or feliz == 2 then
      local come = GetPetFoodTypes and { GetPetFoodTypes() } or {}
      table.insert(l, { "mascota", L"Tu mascota está " .. C.AMARILLO .. (feliz == 1 and L"descontenta" or L"normal") .. C.FIN ..
        L": dale de comer (Alimentar mascota) para que haga más daño" .. (#come > 0 and (L". Come: " .. table.concat(come, ", ")) or "") .. "." })
    end
  end
  if clase == "WARLOCK" and Nivel() >= 10 and GetItemCount then
    local tengo = false
    for _, id in ipairs(PIEDRA_SALUD) do if (GetItemCount(id) or 0) > 0 then tengo = true; break end end
    local fragmentos = GetItemCount(6265) or 0
    if not tengo and fragmentos >= 3 and not (InCombatLockdown and InCombatLockdown()) then
      table.insert(l, { "piedrasalud", L"No llevas " .. C.AMARILLO .. L"piedra de salud" .. C.FIN .. L" y te sobran fragmentos de alma: crea una antes de salir." })
    end
  end
  return l
end)
table.insert(GL.alIniciar, function()
  if GL.URGENCIA_AVISO then GL.URGENCIA_AVISO.mascota = 1; GL.URGENCIA_AVISO.piedrasalud = 3 end
  if GL.NOMBRE_PILDORA then GL.NOMBRE_PILDORA.mascota = L"Mascota"; GL.NOMBRE_PILDORA.piedrasalud = L"Piedra de salud" end
  if GL.TITULOS_AVISO then GL.TITULOS_AVISO.mascota = L"Mascota descontenta" end
end)

GL._rangosMascota = { Filas = Filas, Maestra = Maestra }   -- para las pruebas

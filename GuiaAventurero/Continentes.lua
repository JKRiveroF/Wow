-- Continentes.lua (9.2): un solo addon que carga solo lo que necesitas. Las misiones opcionales van en
-- OpcionalesKalimdor.lua, OpcionalesReinos.lua y OpcionalesOtras.lua (Isla Zephras), cada facción en un texto.
-- Al entrar con un personaje, igual que se elige su ruta: se suelta el texto de la otra facción, se mira en qué
-- continente estás (y a cuál lleva el paso de la guía) y solo ese texto se convierte en tabla. El del otro continente
-- se queda como texto (ocupa poco) hasta que llegas allí; entonces se convierte solo, sin /reload.
-- (En la 9.1 iban en dos addons aparte, GuiaAventurero_Kalimdor y GuiaAventurero_Reinos: ya no hacen falta.)
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local CONTINENTE = { [1414] = "Kalimdor", [1415] = "Reinos" }
-- zonas que el juego podría no colgar de su continente (las nuevas de Forever, entre otras)
local ZONA = { [2482] = "Kalimdor", [2652] = "Kalimdor", [2548] = "Reinos" }
for m = 1416, 1437 do ZONA[m] = "Reinos" end
for _, m in ipairs({ 1453, 1455, 1458, 1459 }) do ZONA[m] = "Reinos" end
for _, m in ipairs({ 1411, 1412, 1413, 1454, 1456, 1457 }) do ZONA[m] = "Kalimdor" end
for m = 1438, 1452 do ZONA[m] = "Kalimdor" end
GL.CONTINENTE_DE_ZONA = ZONA

local cargados = {}

local function Faccion() return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "Horde" or "Alliance" end

-- Junta los datos de un continente en GL.WH (las tablas que usa Opcionales.lua)
local function Juntar(c)
  local datos = GuiaAventurero_Datos and GuiaAventurero_Datos[c]
  if type(datos) ~= "table" then return false end
  local fn = datos[Faccion()]
  GuiaAventurero_Datos[c] = nil   -- se suelta también lo de la otra facción
  if type(fn) == "string" then
    local f, err = (loadstring or load)(fn, L"opcionales de " .. c)
    if not f then table.insert(GL.erroresCarga, L"datos de " .. c .. ": " .. tostring(err)); return false end
    fn = f
  end
  if type(fn) ~= "function" then return false end
  local ok, t = pcall(fn)
  if not ok or type(t) ~= "table" then table.insert(GL.erroresCarga, L"datos de " .. c .. ": " .. tostring(t)); return false end
  if GL.TraducirDatos then GL.TraducirDatos(t) end   -- 9.3.5: en inglés (Idioma.lua)
  GL.WH = GL.WH or {}
  for tabla, lista in pairs(t) do
    GL.WH[tabla] = GL.WH[tabla] or {}
    for q, o in pairs(lista) do GL.WH[tabla][q] = o end
  end
  GL.RevisionCatalogo976 = (GL.RevisionCatalogo976 or 0) + 1
  cargados[c] = true
  return true
end

local function Cargar(c)
  if cargados[c] then return true end
  return Juntar(c)
end

-- Al entrar: el texto de la otra facción se suelta en los tres (Kalimdor, Reinos y Otras)
local function SoltarOtraFaccion()
  local f = Faccion()
  for _, c in ipairs({ "Kalimdor", "Reinos", "Otras" }) do
    local d = GuiaAventurero_Datos and GuiaAventurero_Datos[c]
    if type(d) == "table" then
      for fac in pairs(d) do if fac ~= f then d[fac] = nil end end
    end
  end
end
GL.CargarContinente = Cargar

-- Continente donde estás: subiendo por los mapas hasta el continente; si no, por la zona
local function Donde()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok then return nil end
  for _ = 1, 8 do
    if GL.Seguro then m = GL.Seguro(m) end
    if type(m) ~= "number" or m ~= m or m <= 0 or m == math.huge then return nil end
    if CONTINENTE[m] then return CONTINENTE[m] end
    if ZONA[m] then return ZONA[m] end
    if not C_Map.GetMapInfo then return nil end
    local okInfo, info = pcall(C_Map.GetMapInfo, m)
    if GL.Seguro then info = GL.Seguro(info) end
    if not okInfo or type(info) ~= "table" then return nil end
    m = info.parentMapID
  end
  return nil
end
GL.ContinenteDondeEstas = Donde

local function Mirar()
  local c = Donde()
  if c then Cargar(c) end
  -- también el del paso de la guía (por si vas a ir allí) y, si no se sabe dónde estás, los dos
  local d = GL.DestinoActual and GL.DestinoActual()
  local c2 = d and d.m and ZONA[d.m]
  if c2 then Cargar(c2) end
  if not c and not c2 then Cargar("Kalimdor"); Cargar("Reinos") end
end
GL.MirarContinente = Mirar

GL.ContinenteActual = function()
  local l = {}
  for _, c in ipairs({ "Kalimdor", "Reinos", "Otras" }) do if cargados[c] then table.insert(l, c) end end
  return #l > 0 and table.concat(l, ", ") or "ninguno"
end

-- Las que añadiste tú (opcAnadidas) pueden ser de otro continente: si alguna no está cargada, se cargan los dos
local function AnadidasSinDatos()
  local a = GuiaAventureroDB and GuiaAventureroDB.opcAnadidas
  if type(a) ~= "table" then return false end
  local WH = GL.WH or {}
  local h = Faccion() == "Horde"
  for q in pairs(a) do
    local esta = h and ((WH.opcionalesH or {})[q] or (WH.opcionalesNuevasH or {})[q]) or ((WH.opcionales or {})[q] or (WH.opcionalesNuevas or {})[q])
    if not esta then return true end
  end
  return false
end

table.insert(GL.alIniciar, function()
  SoltarOtraFaccion()
  Cargar("Otras")
  pcall(Mirar)
  if AnadidasSinDatos() then Cargar("Kalimdor"); Cargar("Reinos") end
  collectgarbage("collect")
end)

local ev = CreateFrame("Frame")
GL.Evento(ev, "ZONE_CHANGED_NEW_AREA")
GL.Evento(ev, "PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if not GL.RUTA then return end
  local ok, err = pcall(Mirar)
  if not ok and GL.Fallo then GL.Fallo("continentes", err) end
end)

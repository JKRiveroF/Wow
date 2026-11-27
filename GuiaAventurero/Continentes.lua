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
local faccionCargada

-- R15: una facción todavía no disponible no significa Alianza.
local function Faccion()
  if type(UnitFactionGroup) ~= "function" then return nil end
  local ok, f = pcall(UnitFactionGroup, "player")
  if not ok then return nil end
  if type(issecretvalue) == "function" then
    local leido, secreto = pcall(issecretvalue, f)
    if not leido or secreto then return nil end
  end
  if f == "Horde" or f == "Alliance" then return f end
end

-- Junta los datos de un continente en GL.WH (las tablas que usa Opcionales.lua).
-- No liberar el origen hasta completar la traducción y validar todos los destinos.
local function Juntar(c)
  local datos = GuiaAventurero_Datos and GuiaAventurero_Datos[c]
  local fac = Faccion()
  if type(datos) ~= "table" or not fac or (faccionCargada and faccionCargada ~= fac) then return false end
  local fn = datos[fac]
  local function fallo(err)
    local aviso = L"datos de " .. c .. ": " .. tostring(err)
    for _, anterior in ipairs(GL.erroresCarga) do if anterior == aviso then return false end end
    table.insert(GL.erroresCarga, aviso)
    return false
  end
  if type(fn) == "string" then
    local cargar = loadstring or load
    if type(cargar) ~= "function" then return false end
    local ok, f, err = pcall(cargar, fn, L"opcionales de " .. c)
    if not ok or type(f) ~= "function" then return fallo(ok and err or f) end
    fn = f
  end
  if type(fn) ~= "function" then return false end
  local ok, t = pcall(fn)
  if not ok or type(t) ~= "table" then return fallo(t) end
  if GL.TraducirDatos then
    local bien, err = pcall(GL.TraducirDatos, t)
    if not bien then return fallo(err) end
  end
  if not GL.WH then GL.WH = {} end
  if type(GL.WH) ~= "table" then return fallo("WH") end
  for tabla, lista in pairs(t) do
    if type(lista) ~= "table" or (GL.WH[tabla] ~= nil and type(GL.WH[tabla]) ~= "table") then
      return fallo(tabla)
    end
  end
  if Faccion() ~= fac then return false end
  for tabla, lista in pairs(t) do
    GL.WH[tabla] = GL.WH[tabla] or {}
    for q, o in pairs(lista) do GL.WH[tabla][q] = o end
  end
  GL.RevisionCatalogo976 = (GL.RevisionCatalogo976 or 0) + 1
  cargados[c] = true
  faccionCargada = fac
  GuiaAventurero_Datos[c] = nil
  return true
end

local function Cargar(c)
  if cargados[c] then return true end
  return Juntar(c)
end

-- Al entrar: el texto de la otra facción se suelta en los tres (Kalimdor, Reinos y Otras)
local otraFaccionLiberada
local function SoltarOtraFaccion()
  local f = faccionCargada
  if otraFaccionLiberada or not f or Faccion() ~= f then return end
  for _, c in ipairs({ "Kalimdor", "Reinos", "Otras" }) do
    local d = GuiaAventurero_Datos and GuiaAventurero_Datos[c]
    if type(d) == "table" then
      for fac in pairs(d) do if fac ~= f then d[fac] = nil end end
    end
  end
  otraFaccionLiberada = true
end
GL.CargarContinente = Cargar

-- Continente donde estás: subiendo por los mapas hasta el continente; si no, por la zona
local function Donde()
  local origen=GL.MapaUnidadR14()
  local m=origen
  local vistos={}
  for _=1,8 do
    if not m or vistos[m] then return nil end
    vistos[m]=true
    local c=CONTINENTE[m] or ZONA[m]
    if c then
      if GL.MapaUnidadR14()==origen then return c end
      return nil
    end
    local _,padre=GL.InfoMapaR14(m)
    m=padre
  end
end
GL.ContinenteDondeEstas = Donde

local AnadidasSinDatos
local function Mirar()
  if not Faccion() then return end
  Cargar("Otras")
  local c = Donde()
  if c then Cargar(c) end
  -- también el del paso de la guía (por si vas a ir allí) y, si no se sabe dónde estás, los dos
  local d = GL.DestinoActual and GL.DestinoActual()
  local c2 = d and d.m and ZONA[d.m]
  if c2 then Cargar(c2) end
  if not c and not c2 then Cargar("Kalimdor"); Cargar("Reinos") end
  if AnadidasSinDatos and AnadidasSinDatos() then Cargar("Kalimdor"); Cargar("Reinos") end
  SoltarOtraFaccion()
end
GL.MirarContinente = Mirar

GL.ContinenteActual = function()
  local l = {}
  -- 9.7.9.1: nombres para enseñar (en inglés salían «Reinos, Otras»)
  local nombre = { Kalimdor = "Kalimdor", Reinos = "Reinos del Este", Otras = "Otras" }
  for _, c in ipairs({ "Kalimdor", "Reinos", "Otras" }) do if cargados[c] then table.insert(l, L(nombre[c])) end end
  return #l > 0 and table.concat(l, ", ") or L"ninguno"
end

-- Las que añadiste tú (opcAnadidas) pueden ser de otro continente: si alguna no está cargada, se cargan los dos
AnadidasSinDatos = function()
  local a = GuiaAventureroDB and GuiaAventureroDB.opcAnadidas
  if type(a) ~= "table" then return false end
  local WH = GL.WH or {}
  local fac = Faccion()
  if not fac then return false end
  for q in pairs(a) do
    local esta
    if fac == "Horde" then esta = (WH.opcionalesH or {})[q] or (WH.opcionalesNuevasH or {})[q]
    else esta = (WH.opcionales or {})[q] or (WH.opcionalesNuevas or {})[q] end
    if not esta then return true end
  end
  return false
end

table.insert(GL.alIniciar, function()
  pcall(Mirar)
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

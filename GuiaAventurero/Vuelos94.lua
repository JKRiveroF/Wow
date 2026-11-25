-- Vuelos94.lua (9.4): los puntos de vuelo de tu facción que aún no tienes, por continente y por cercanía, con Llevarme.
-- Cuáles tienes: al abrir el mapa de vuelo, cada nodo que el juego da como conocido se busca entre los maestros de
-- vuelo por su posición (y el maestro con el que hablas queda apuntado). Se guarda por personaje (vuelosNPC).
-- Botón «Por descubrir» en Exploración › Puntos de vuelo y /ga vuelos. Datos: Datos94.lua y Exploracion.lua.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local KALIMDOR = { [1411] = true, [1412] = true, [1413] = true, [1454] = true, [1456] = true, [1457] = true }
for m = 1438, 1452 do KALIMDOR[m] = true end
local function Continente(m) return KALIMDOR[m] and "K" or "R" end
local function Lado()
  if not UnitFactionGroup then return nil end
  local ok, lado = pcall(UnitFactionGroup, "player")
  if not ok or (issecretvalue and issecretvalue(lado)) then return nil end
  return lado == "Horde" and "H" or lado == "Alliance" and "A" or nil
end
local function DB() return GuiaAventureroDB end
local function Distancia(v)
  if not GL.Vector then return nil end
  local ok, _, _, d = pcall(GL.Vector, v)
  if ok and not (issecretvalue and issecretvalue(d)) and type(d) == "number" and d >= 0 and d < math.huge then return d end
end

-- Todos los maestros de vuelo (Datos94 y los de Exploración, sin repetir)
local lista = nil
local function Maestros()
  if lista then return lista end
  lista = {}
  local visto = {}
  local function Poner(v)
    if v.npc and not visto[v.npc] and v.m and v.x and v.y then visto[v.npc] = true; table.insert(lista, v) end
  end
  for _, v in ipairs((GL.D94 and GL.D94.vuelos) or {}) do Poner(v) end
  for _, v in ipairs((GL._vuelos and GL._vuelos()) or {}) do Poner(v) end
  return lista
end

function GL.VueloConocidoNPC(npc)
  local db = DB()
  return npc ~= nil and type(db) == "table" and type(db.vuelosNPC) == "table" and db.vuelosNPC[npc] == true
end

local function DeMiLado(v, lado)
  return v.lado == nil or v.lado == "AH" or (lado ~= nil and type(v.lado) == "string" and string.find(v.lado, lado, 1, true) ~= nil)
end

local function Coordenadas(pos)
  local ok, x, y = pcall(function() return pos:GetXY() end)
  if not ok or (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then return nil end
  if type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

-- Al abrir el mapa de vuelo: el PNJ con el que hablas y los nodos conocidos, por su posición en el mapa del continente
local function Apuntar()
  local db = DB()
  if type(db) ~= "table" then return end
  if type(db.vuelosNPC) ~= "table" then db.vuelosNPC = {} end
  local guid = UnitGUID and UnitGUID("npc")
  local id = not (issecretvalue and issecretvalue(guid)) and type(guid) == "string" and tonumber((select(6, strsplit("-", guid))))
  if id then db.vuelosNPC[id] = true end
  if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and GetTaxiMapID and C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
  local okM, mapa = pcall(GetTaxiMapID)
  if not okM or (issecretvalue and issecretvalue(mapa)) or type(mapa) ~= "number" or mapa <= 0 or mapa >= math.huge or mapa % 1 ~= 0 then return end
  local ok, nodos = pcall(C_TaxiMap.GetAllTaxiNodes, mapa)
  if not (ok and type(nodos) == "table") then return end
  local candidatos = {}
  for _, v in ipairs(Maestros()) do
    local okW, cont, mundo = pcall(C_Map.GetWorldPosFromMapPos, v.m, CreateVector2D(v.x / 100, v.y / 100))
    local okP, _, pos = false, nil, nil
    if okW and cont and mundo then okP, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, mundo, mapa) end
    if okP and pos then
      local px, py = Coordenadas(pos)
      for _, n in ipairs(nodos) do
        local p = type(n) == "table" and n.position
        if p and px then
          local nx, ny = Coordenadas(p)
          if nx and math.abs(nx - px) < 0.02 and math.abs(ny - py) < 0.02 then
            candidatos[n] = candidatos[n] or {}
            table.insert(candidatos[n], v)
          end
        end
      end
    end
  end
  -- Una coincidencia ambigua no demuestra que el maestro esté descubierto.
  local porNPC = {}
  for n, opciones in pairs(candidatos) do
    for _, v in ipairs(opciones) do
      porNPC[v.npc] = (porNPC[v.npc] or 0) + 1
    end
  end
  local lado = Lado()
  for n, opciones in pairs(candidatos) do
    local v = opciones[1]
    if #opciones == 1 and porNPC[v.npc] == 1 and DeMiLado(v, lado) and GL.EstadoVueloConocido(n.state) then
      db.vuelosNPC[v.npc] = true
    end
  end
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("TAXIMAP_OPENED")
ev:SetScript("OnEvent", function() pcall(Apuntar) end)

-- ¿Lo tienes? Por PNJ o, como antes, por el nombre del maestro (Exploración guarda db.vuelos[nombre])
local function Tengo(v)
  if GL.VueloConocidoNPC(v.npc) then return true end
  local db = DB()
  return type(db) == "table" and type(db.vuelos) == "table" and (db.vuelos[v.n] or (v.ing and db.vuelos[v.ing])) and true or false
end

-- Recomendaciones de exploración: catálogo común, distancia en línea recta.
-- Sin posición medible solo mostramos referencias locales, nunca un vuelo lejano supuesto.
function GL.VuelosCercanos(zona, mapas)
  local filas = {}
  mapas = mapas or {}
  local lado = Lado()
  for _, v in ipairs(Maestros()) do
    if DeMiLado(v, lado) then
      local aqui = mapas[v.m] or (zona and zona ~= "" and v.z == zona)
      local act = Tengo(v)
      local d
      if aqui or not act then d = Distancia(v) end
      if aqui or (not act and d ~= nil) then
        filas[#filas + 1] = { v = v, aqui = aqui, d = d, act = act }
      end
    end
  end
  table.sort(filas, function(a, b)
    if a.act ~= b.act then return not a.act end
    if (a.d ~= nil) ~= (b.d ~= nil) then return a.d ~= nil end
    if a.d ~= b.d then return a.d < b.d end
    return a.v.npc < b.v.npc
  end)
  return filas
end

local cont = nil
local function Filas()
  local mio = cont or "R"
  local faltan, tengo, total = {}, {}, 0
  local lado = Lado()
  for _, v in ipairs(Maestros()) do
    if DeMiLado(v, lado) and Continente(v.m) == mio then
      total = total + 1
      local conocido = Tengo(v)
      local dist
      if not conocido then dist = Distancia(v) end
      table.insert(conocido and tengo or faltan, { v = v, d = dist })
    end
  end
  table.sort(faltan, function(a, b)
    if a.d and b.d then return a.d < b.d end
    if a.d or b.d then return a.d ~= nil end
    return (a.v.z or "") < (b.v.z or "")
  end)
  table.sort(tengo, function(a, b) return (a.v.z or "") < (b.v.z or "") end)
  local filas = {}
  for _, e in ipairs(faltan) do
    local v = e.v
    table.insert(filas, { texto = L(v.n), detalle = (v.z and L(v.z) or "?") .. (e.d and (C.GRIS .. " · " .. math.floor(e.d) .. " m" .. C.FIN) or ""),
      destino = { m = v.m, x = v.x, y = v.y, z = v.z, n = L"Vuelo: " .. L(v.n) }, ayudaTitulo = L(v.n),
      ayudaTexto = L"Habla con el maestro de vuelo para activar el punto." })
  end
  for _, e in ipairs(tengo) do
    table.insert(filas, { hecha = true, texto = C.GRIS .. L(e.v.n) .. C.FIN, detalle = e.v.z and L(e.v.z) or "" })
  end
  local cab = L"Te faltan " .. #faltan .. L" de " .. total .. L" puntos de vuelo de tu facción en este continente, los más cercanos primero. " ..
    L"Los que tienes se apuntan al abrir el mapa de vuelo."
  return filas, cab
end

local ventana
local function Refrescar()
  if not (ventana and ventana:IsShown()) then return end
  ventana.pest.Marcar(cont)
  local filas, cab = Filas()
  ventana.lista:Poner(filas, C.GRIS .. cab .. C.FIN)
end

function GL.AbrirVuelos94()
  if not cont then
    local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    cont = m and Continente(m) or "R"
  end
  ventana = GL.VentanaLista("vuelos", L"Vuelos por descubrir", 420, 420)
  if not ventana.pest then
    ventana.pest = GL.CrearPestanas94(ventana.arriba, { { "R", L"Reinos del Este" }, { "K", "Kalimdor" } }, function(id) cont = id; Refrescar() end, 130)
    ventana:ConPestanas(true)
    local espera = 0
    ventana:HookScript("OnUpdate", function(_, dt) espera = espera + dt; if espera >= 3 then espera = 0; Refrescar() end end)
  end
  ventana:Show()
  Refrescar()
end

GL.comandos = GL.comandos or {}
GL.comandos["vuelos"] = function() GL.AbrirVuelos94() end

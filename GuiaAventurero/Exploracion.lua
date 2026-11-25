-- Exploracion.lua: pestaña Exploración (6.0.1). Dónde estás, las misiones de la guía en tu zona
-- (cuántas llevas hechas) y el destino de la flecha. Solo lee datos: no cambia la ruta ni el progreso.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local ALTO_FILA = 16
local VUELOS_ALTO = 86           -- 6.9: bloque de puntos de vuelo
local FONDO = 6                -- 9.4.2: hueco de abajo (antes 70, con el destino de la flecha)
local HOGAR_ALTO = 66            -- 7.5.8: bloque de la piedra de hogar, encima de los puntos de vuelo
local CADA = 0.5                 -- segundos entre refrescos mientras la pestaña está abierta

local panel, ui = nil, { filas = {} }
local lista, claveZona = {}, nil -- misiones de la guía en la zona actual (se rehace al cambiar de zona)
local desde = 0                  -- desplazamiento de la lista con la rueda del ratón
local sel = nil                  -- 6.2: misión pulsada (id), con los botones Seguir e Ir a su paso

------------------------------------------------------------------------
-- Datos
------------------------------------------------------------------------
-- Mapas de la zona del jugador: el suyo y sus padres hasta el continente (sin incluirlo).
local function MapasDeMiZona()
  local mapas = {}
  if not (C_Map and C_Map.GetBestMapForUnit) then return mapas end
  local m = GL.Seguro(C_Map.GetBestMapForUnit("player"))
  local vueltas = 0
  while m and m > 0 and vueltas < 6 do
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    if not info or (info.mapType and info.mapType <= 2) then break end   -- 0 cosmos, 1 mundo, 2 continente
    mapas[m] = true
    m = info.parentMapID
    vueltas = vueltas + 1
  end
  return mapas
end

-- "Recoger: Los enanos modistos (Sten Brazofuerte)" -> "Los enanos modistos"
local function NombreMision(n)
  n = string.gsub(n or "", "^[^:]-:%s*", "")
  n = string.gsub(n, "%s*%b()%s*$", "")
  return n
end

local function RehacerLista(zona, mapas)
  lista = {}
  local vistas = {}
  local RUTA = GL.RUTA
  if not RUTA or not RUTA.secciones then return end
  for s, sec in ipairs(RUTA.secciones) do
    for p, paso in ipairs(sec.pasos or {}) do
      for i, wp in ipairs(paso.wp or {}) do
        if wp.q and (mapas[wp.m] or (zona ~= "" and wp.z == zona)) then
          local e = vistas[wp.q]
          if not e then
            e = { q = wp.q, nombre = NombreMision(wp.n), destinos = {} }
            vistas[wp.q] = e
            table.insert(lista, e)
          end
          table.insert(e.destinos, { s = s, p = p, i = i, wp = wp })
          if wp.a == "A" then
            e.nombre = NombreMision(wp.n)   -- el nombre de recoger es el más fiable
          end
        end
      end
    end
  end
end

-- 7.5.12: zonas de la ruta en orden, con sus misiones (sin repetir)
local modoTodas, zonaFija = false, nil
local function ZonasRuta()
  local orden, por = {}, {}
  local RUTA = GL.RUTA
  if not RUTA or not RUTA.secciones then return orden end
  for _, sec in ipairs(RUTA.secciones) do
    for _, paso in ipairs(sec.pasos or {}) do
      for _, wp in ipairs(paso.wp or {}) do
        if wp.q and wp.z then
          local z = por[wp.z]
          if not z then z = { zona = wp.z, qs = {}, total = 0 }; por[wp.z] = z; table.insert(orden, z) end
          if not z.qs[wp.q] then z.qs[wp.q] = true; z.total = z.total + 1 end
        end
      end
    end
  end
  return orden
end

-- 7.6: Cerca de ti. Entrenadores, vendedores, raros, bolsas (DatosWowhead.lua) y posadas con coordenadas, por distancia.
local modoCerca = false
local POSADAS
local function ListaCerca()
  local res, WH, vistos, grupos = {}, GL.WH or {}, {}, {}
  local function Meter(tipo, nombre, d, destino)
    if not (d and d.m and type(d.x) == "number" and type(d.y) == "number" and nombre) then return end
    destino = destino or { m = d.m, x = d.x, y = d.y, z = d.zona or d.z, n = nombre }
    local lugar = string.format("%s:%.4f:%.4f", d.m, d.x, d.y)
    local id = "cerca:" .. tipo .. ":" .. nombre .. ":" .. lugar
    if vistos[id] then return end
    local ok, este, _, dist = pcall(GL.Vector, destino)
    if ok and este and type(dist) == "number" and dist >= 0 and dist < math.huge then
      vistos[id] = true
      grupos[lugar] = (grupos[lugar] or 0) + 1
      table.insert(res, { q = id, lugar = lugar, nombre = tipo .. " · " .. nombre, dist = dist, destinos = { { wp = destino } } })
    end
  end
  for _, e in ipairs(WH.entrenadores or {}) do if GL.DeMiLado(e) then Meter(L"Entrenador de armas", e.n, e) end end
  for _, v in ipairs(WH.vendedores or {}) do if GL.DeMiLado(v) then Meter(L"Vendedor", (v.vendedor or "?") .. " (" .. (v.n or "?") .. ")", v) end end
  for _, r in ipairs(WH.raros or {}) do if GL.DeMiLado(r) then Meter(L"Raro", r.n .. (r.nivel and (" (" .. r.nivel .. ")") or ""), r) end end
  for _, b in ipairs(WH.bolsas or {}) do
    if GL.DeMiLado(b) and not (b.q and GL.MisionCompletada and GL.MisionCompletada(b.q)) then Meter(L"Bolsa", "[" .. b.n .. "]", b) end
  end
  for _, p in ipairs(POSADAS or {}) do if GL.DeMiLado(p) then Meter(L"Posada", p.n .. " (" .. p.lugar .. ")", p) end end
  -- Solo objetivos activos de la sección actual; no modifica la ruta ni su progreso.
  local db = GuiaAventureroDB
  local sec = db and GL.RUTA and GL.RUTA.secciones and GL.RUTA.secciones[db.seccion or 1]
  local mapas = MapasDeMiZona()
  -- Aprovechar una visita local: solo pasos con un único PNJ identificable.
  local ok, pendientes = false, nil
  if GL.EntrenamientoClasePendiente then ok, pendientes = pcall(GL.EntrenamientoClasePendiente) end
  if ok and type(pendientes) == "number" and pendientes > 0 then
    for _, seccion in ipairs(GL.RUTA and GL.RUTA.secciones or {}) do
      for _, paso in ipairs(seccion.pasos or {}) do
        if paso.comprobar and type(paso.comprobar.hechizos) == "table" and #paso.comprobar.hechizos > 0 then
          local candidato, ambiguo
          for _, wp in ipairs(paso.wp or {}) do
            if wp.npc then
              if candidato and candidato.npc ~= wp.npc then ambiguo = true end
              candidato = candidato or wp
            end
          end
          if candidato and not ambiguo and mapas[candidato.m] and GL.DeMiLado(candidato) then
            Meter(L"Instructor de clase", candidato.n .. " (" .. pendientes .. L" recomendados pendientes" .. ")", candidato)
          end
        end
      end
    end
  end
  for _, paso in ipairs(sec and sec.pasos or {}) do
    for _, wp in ipairs(paso.wp or {}) do
      if wp.q and mapas[wp.m] and wp.a == "C" and GL.MisionEnDiario and GL.MisionEnDiario(wp.q)
        and GL.DestinoHecho and GL.DestinoHecho(wp) == false then
        Meter(L"Misión", wp.n, wp, wp)
      end
    end
  end
  table.sort(res, function(a, b)
    if a.dist ~= b.dist then return a.dist < b.dist end
    if a.lugar ~= b.lugar then return a.lugar < b.lugar end
    return a.q < b.q
  end)
  for _, e in ipairs(res) do e.juntas = grupos[e.lugar] end
  return res
end
GL.ListaActividadesCercanas = ListaCerca

local function Estado(q)
  if GL.MisionCompletada(q) then return "hecha" end
  if GL.MisionEnDiario(q) then return "curso" end
  return "pendiente"
end

local RUMBOS = { L"al norte", L"al noreste", L"al este", L"al sureste", L"al sur", L"al suroeste", L"al oeste", L"al noroeste" }
local function Rumbo(este, sur)
  local ang = math.atan2 and math.atan2(este, -sur) or math.atan(este, -sur)   -- 0 = norte, en sentido horario
  local sector = math.floor(ang / (math.pi / 4) + 0.5) % 8
  return RUMBOS[sector + 1]
end

------------------------------------------------------------------------
-- Pintar
------------------------------------------------------------------------
------------------------------------------------------------------------
-- 6.9: puntos de vuelo. Uno está activado si has hablado con su maestro de vuelo con el mapa de vuelo abierto
-- (se apunta en db.vuelos). Los que faltan salen ordenados por distancia, solo los de tu continente.
------------------------------------------------------------------------
local VUELOS = {   -- maestros de vuelo sacados de los pasos "activa el vuelo con" de todas las rutas
  { lado = "A", n = "Felicia Maline", m = 1431, z = L"Bosque del Ocaso", x = 77.5, y = 44.3, npc = 2409 },
  { lado = "A", n = L"Dungar Tragolargo", m = 1453, z = L"Ciudad de Ventormenta", x = 71.3, y = 72.2, npc = 352 },
  { lado = "A", n = L"Caylais Plumalunar", m = 1439, z = L"Costa Oscura", x = 36.3, y = 45.6, npc = 3841 },
  { lado = "A", n = "Maethrya", m = 1452, z = L"Cuna del Invierno", x = 62.3, y = 36.6, npc = 11138 },
  { lado = "A", n = L"Baritanas Rioceleste", m = 1443, z = "Desolace", x = 64.7, y = 10.5, npc = 6706 },
  { lado = "A", n = L"Fyldren Plumalunar", m = 1444, z = "Feralas", x = 30.2, y = 43.2, npc = 8019 },
  { lado = "A", n = "Gryth Thurden", m = 1455, z = L"Forjaz", x = 55.5, y = 47.7, npc = 1573 },
  { lado = "A", n = "Mishellena", m = 1448, z = L"Frondavil", x = 62.5, y = 24.2, npc = 12578 },
  { lado = "A", n = "Darla Harris", m = 1424, z = L"Laderas de Trabalomas", x = 49.3, y = 52.3, npc = 2432 },
  { lado = "A", n = "Thorgrum Borrelson", m = 1432, z = "Loch Modan", x = 33.9, y = 51.0, npc = 1572 },
  { n = "Bragok", m = 1413, z = L"Los Baldíos", x = 63.1, y = 37.2, npc = 16227 },
  { lado = "A", n = "Shellei Brondir", m = 1437, z = L"Los Humedales", x = 9.5, y = 59.7, npc = 1571 },
  { lado = "A", n = "Baldruc", m = 1445, z = L"Marjal Revolcafango", x = 67.5, y = 51.3, npc = 4321 },
  { lado = "A", n = L"Ariena Tempespluma", m = 1433, z = L"Montañas Crestagrana", x = 25.5, y = 59.4, npc = 931 },
  { lado = "A", n = "Thor", m = 1436, z = L"Páramos de Poniente", x = 56.5, y = 52.6, npc = 523 },
  { lado = "A", n = L"Bera Rocamartillo", m = 1446, z = "Tanaris", x = 51.0, y = 29.3, npc = 7823 },
  { lado = "A", n = L"Cedrik Prosa", m = 1417, z = L"Tierras Altas de Arathi", x = 45.7, y = 46.1, npc = 2835 },
  { lado = "A", n = L"Guthrum Tronapuño", m = 1425, z = L"Tierras del Interior", x = 11.1, y = 46.1, npc = 8018 },
  { lado = "A", n = "Daelyshia", m = 1440, z = L"Vallefresno", x = 34.4, y = 48.0, npc = 4267 },
  -- 8.5: maestros de vuelo de la Horda, de los pasos "activa el vuelo con" de las rutas de la Horda (Bragok, en
  -- Trinquete, es neutral). lado = "A" o "H": solo salen a esa facción.
  { lado = "H", n = "Doras", m = 1454, z = "Orgrimmar", x = 45.1, y = 63.9, npc = 3310 },
  { lado = "H", n = "Tal", m = 1456, z = L"Cima del Trueno", x = 47.0, y = 49.8, npc = 2995 },
  { lado = "H", n = "Michael Garrett", m = 1458, z = L"Entrañas", x = 63.2, y = 48.6, npc = 4551 },
  { lado = "H", n = "Karos Razok", m = 1421, z = L"Bosque de Argénteos", x = 45.6, y = 42.6, npc = 2226 },
  { lado = "H", n = "Devrak", m = 1413, z = L"Los Baldíos", x = 51.5, y = 30.3, npc = 3615 },
  { lado = "H", n = L"Omusa Tronacuerno", m = 1413, z = L"Los Baldíos", x = 44.5, y = 59.1, npc = 10378 },
  { lado = "H", n = "Tharm", m = 1442, z = L"Sierra Espolón", x = 45.1, y = 59.8, npc = 4312 },
  { lado = "H", n = "Vhulgra", m = 1440, z = L"Vallefresno", x = 73.2, y = 61.6, npc = 12616 },
  { lado = "H", n = "Zarise", m = 1424, z = L"Laderas de Trabalomas", x = 60.1, y = 18.6, npc = 2389 },
  { lado = "H", n = "Nyse", m = 1441, z = L"Las Mil Agujas", x = 45.1, y = 49.1, npc = 4317 },
  { lado = "H", n = "Thalon", m = 1443, z = "Desolace", x = 21.6, y = 74.1, npc = 6726 },
  { lado = "H", n = "Urda", m = 1417, z = L"Tierras Altas de Arathi", x = 73.0, y = 32.7, npc = 2851 },
  { lado = "H", n = "Thysta", m = 1434, z = L"Vega de Tuercespina", x = 32.5, y = 29.4, npc = 1387 },
  { lado = "H", n = "Gringer", m = 1434, z = L"Vega de Tuercespina", x = 26.9, y = 77.1, npc = 2858 },
  { lado = "H", n = "Shardi", m = 1445, z = L"Marjal Revolcafango", x = 35.6, y = 31.9, npc = 11899 },
  { lado = "H", n = "Breyk", m = 1435, z = L"Pantano de las Penas", x = 46.1, y = 54.8, npc = 6026 },
  { lado = "H", n = "Gorrik", m = 1418, z = L"Tierras Inhóspitas", x = 4.0, y = 44.8, npc = 2861 },
  { lado = "H", n = L"Bulkrek Puñofuria", m = 1446, z = "Tanaris", x = 51.6, y = 25.4, npc = 7824 },
  { lado = "H", n = "Shyn", m = 1444, z = "Feralas", x = 75.5, y = 44.4, npc = 8020 },
  { lado = "H", n = "Gorkas", m = 1425, z = L"Tierras del Interior", x = 81.7, y = 81.8, npc = 4314 },
  { lado = "H", n = "Kroum", m = 1447, z = "Azshara", x = 22.0, y = 49.6, npc = 8610 },
  { lado = "H", n = "Brakkar", m = 1448, z = L"Frondavil", x = 34.4, y = 54.0, npc = 11900 },
  { lado = "H", n = "Yugrek", m = 1452, z = L"Cuna del Invierno", x = 60.5, y = 36.3, npc = 11139 },
}

local function VueloActivado(v)
  local db = GuiaAventureroDB
  if GL.VueloConocidoNPC and GL.VueloConocidoNPC(v.npc) then return true end   -- 9.4: apuntado por su posición en el mapa de vuelo
  return db.vuelos and db.vuelos[v.n] and true or false
end

local function RefrescarVuelos(zona, mapas)
  local filas, n = GL.VuelosCercanos(zona, mapas), 0
  for i = 1, 3 do
    local f, e = ui.vuelos[i], filas[i]
    if e then
      local act = e.act
      f.texto:SetText((act and (GL.Icono("✓") .. " ") or "") .. e.v.n .. C.GRIS .. " (" .. (e.v.z or "?") .. ")" .. C.FIN ..
        (act and "" or (e.aqui and (C.AMARILLO .. L"  te falta" .. C.FIN) or "")))
      f.distVuelo = e.d
      f.boton.destino = { m = e.v.m, x = e.v.x, y = e.v.y, z = e.v.z, n = L"Vuelo: " .. e.v.n }
      GL.Mostrar(f.boton, not act)
      f:Show()
    else
      f.distVuelo = nil
      f:Hide()
    end
    n = n + (e and 1 or 0)
  end
  ui.vuelosVacio:SetText(n == 0 and (C.GRIS .. L"Tu ruta no tiene puntos de vuelo cerca." .. C.FIN) or "")
end

------------------------------------------------------------------------
-- 7.5.8: piedra de hogar. Posadas de la Alianza (posadero, coordenadas del mapa de su zona). Las ocho primeras
-- salen de las rutas de la guía; el resto son del clásico y se han comprobado con QuestieDB (Forever) en la 7.7,
-- menos Villa del Lago, donde QuestieDB pone al posadero en otro sitio.
------------------------------------------------------------------------
POSADAS = {
  { lado = "A", lugar = "Kharanos", z = "Dun Morogh", m = 1426, x = 47.4, y = 52.5, n = L"Tabernero Belm" },
  { lado = "A", lugar = L"Villadorada", z = L"Bosque de Elwynn", m = 1429, x = 43.8, y = 65.8, n = L"Tabernero Farley" },
  { lado = "A", lugar = L"Villa Oscura", z = L"Bosque del Ocaso", m = 1431, x = 73.9, y = 44.4, n = L"Tabernera Trelayne" },
  { lado = "A", lugar = "Thelsamar", z = "Loch Modan", m = 1432, x = 35.5, y = 48.4, n = L"Tabernero Hogartufa" },
  { lado = "A", lugar = "Dolanaar", z = "Teldrassil", m = 1438, x = 55.6, y = 59.8, n = L"Tabernero Keldamyr" },
  { lado = "A", lugar = "Auberdine", z = L"Costa Oscura", m = 1439, x = 37.0, y = 44.1, n = L"Tabernero Shaussiy" },
  { lugar = "Gadgetzan", z = "Tanaris", m = 1446, x = 52.5, y = 27.9, n = L"Tabernero Fizzgrimble" },
  { lado = "A", lugar = L"Forjaz", z = L"Forjaz", m = 1455, x = 18.1, y = 51.5, n = L"Tabernero Brebefuego" },
  { lado = "A", lugar = L"Colina del Centinela", z = L"Páramos de Poniente", m = 1436, x = 52.8, y = 53.7, n = L"Posada" },
  { lado = "A", lugar = L"Villa del Lago", z = L"Montañas Crestagrana", m = 1433, x = 21.9, y = 44.8, n = L"Posada" },
  { lado = "A", lugar = L"Puerto de Menethil", z = L"Los Humedales", m = 1437, x = 10.7, y = 60.9, n = L"Posada" },
  { lado = "A", lugar = L"Costasur", z = L"Laderas de Trabalomas", m = 1424, x = 51.2, y = 58.9, n = L"Posada" },
  { lado = "A", lugar = "Astranaar", z = L"Vallefresno", m = 1440, x = 37.0, y = 49.3, n = L"Posada" },
  { lado = "A", lugar = L"Isla de Theramore", z = L"Marjal Revolcafango", m = 1445, x = 66.6, y = 45.2, n = L"Posada" },
  { lado = "A", lugar = L"Punta de Nijel", z = "Desolace", m = 1443, x = 66.3, y = 6.6, n = L"Posada" },
  { lado = "A", lugar = L"Pico Nidal", z = L"Tierras del Interior", m = 1425, x = 14.1, y = 41.6, n = L"Posada" },
  { lado = "A", lugar = L"Bastión Plumaluna", z = "Feralas", m = 1444, x = 31.0, y = 43.4, n = L"Posada" },
  { lugar = L"Bahía del Botín", z = L"Vega de Tuercespina", m = 1434, x = 27.0, y = 77.3, n = L"Posada" },
  { lugar = L"Vista Eterna", z = L"Cuna del Invierno", m = 1452, x = 61.3, y = 38.9, n = L"Posada" },
  { lugar = L"Fuerte Cenarion", z = "Silithus", m = 1451, x = 51.9, y = 39.2, n = L"Posada" },
  -- 8.5: posadas de la Horda (y Trinquete y la Capilla de la Esperanza de la Luz, neutrales), con el posadero y su sitio
  -- de QuestieDB (Forever). lado = "A" o "H": solo se ofrecen a esa facción; sin lado, a las dos.
  { lado = "H", lugar = L"Cerrotajo", z = "Durotar", m = 1411, x = 51.5, y = 41.6, n = L"Tabernero Grosk" },
  { lado = "H", lugar = "Orgrimmar", z = "Orgrimmar", m = 1454, x = 54.1, y = 68.4, n = L"Tabernero Gryshka" },
  { lado = "H", lugar = L"Poblado Pezuña de Sangre", z = "Mulgore", m = 1412, x = 45.9, y = 64.2, n = L"Tabernero Kauth" },
  { lado = "H", lugar = L"Cima del Trueno", z = L"Cima del Trueno", m = 1456, x = 45.8, y = 64.7, n = L"Tabernera Pala" },
  { lado = "H", lugar = L"Rémol", z = L"Claros de Tirisfal", m = 1420, x = 61.7, y = 52.1, n = L"Tabernero Renee" },
  { lado = "H", lugar = L"Entrañas", z = L"Entrañas", m = 1458, x = 67.7, y = 37.9, n = L"Tabernero Norman" },
  { lado = "H", lugar = L"El Sepulcro", z = L"Bosque de Argénteos", m = 1421, x = 43.2, y = 41.3, n = L"Tabernero Bates" },
  { lado = "H", lugar = L"El Cruce", z = L"Los Baldíos", m = 1413, x = 52.0, y = 29.9, n = L"Tabernero Boorand Ventollano" },
  { lado = "H", lugar = L"Campamento Taurajo", z = L"Los Baldíos", m = 1413, x = 45.6, y = 59.0, n = L"Tabernera Byula" },
  { lugar = L"Trinquete", z = L"Los Baldíos", m = 1413, x = 62.1, y = 39.4, n = L"Tabernero Wiley" },
  { lado = "H", lugar = L"Refugio Roca del Sol", z = L"Sierra Espolón", m = 1442, x = 47.5, y = 62.1, n = L"Tabernero Jayka" },
  { lado = "H", lugar = L"Puesto del Hachazo", z = L"Vallefresno", m = 1440, x = 74.0, y = 60.7, n = L"Tabernero Kaylisk" },
  { lado = "H", lugar = L"Molino Tarren", z = L"Laderas de Trabalomas", m = 1424, x = 62.8, y = 19.0, n = L"Tabernero Shay" },
  { lado = "H", lugar = L"Poblado Viento Libre", z = L"Las Mil Agujas", m = 1441, x = 46.1, y = 51.5, n = L"Tabernero Abeqwa" },
  { lado = "H", lugar = L"Poblado Sombraprensa", z = "Desolace", m = 1443, x = 24.1, y = 68.2, n = L"Tabernero Sikewa" },
  { lado = "H", lugar = L"Sentencia", z = L"Tierras Altas de Arathi", m = 1417, x = 73.8, y = 32.5, n = L"Tabernero Abegwa" },
  { lado = "H", lugar = L"Campamento Grom'gol", z = L"Vega de Tuercespina", m = 1434, x = 31.5, y = 29.8, n = L"Tabernero Thulbek" },
  { lado = "H", lugar = "Kargath", z = L"Tierras Inhóspitas", m = 1418, x = 2.8, y = 45.9, n = L"Tabernero Shul'kar" },
  { lado = "H", lugar = L"Rocal", z = L"Pantano de las Penas", m = 1435, x = 45.2, y = 56.7, n = L"Tabernero Karkul" },
  { lado = "H", lugar = L"Campamento Mojache", z = "Feralas", m = 1444, x = 74.8, y = 45.2, n = L"Tabernera Greul" },
  { lado = "H", lugar = L"Sañadiente", z = L"Tierras del Interior", m = 1425, x = 78.1, y = 81.4, n = "Lard" },
  { lugar = L"Capilla de la Esperanza de la Luz", z = L"Tierras de la Peste del Este", m = 1423, x = 71.8, y = 48.5, n = "Jessica Chambers" },
  -- 8.6: Isla Zephras (inicio de los Skyborne de las dos facciones)
  { lugar = "Shen'dar", z = L"Isla Zephras", m = 2521, x = 43.0, y = 43.2, n = "Coriella Calmbreeze" },
  { lugar = "Valanaar", z = L"Isla Zephras", m = 2521, x = 62.2, y = 72.6, n = "Donaal Downbreeze" },
}

-- Mapa principal de una sección: el que más se repite en sus destinos.
local function MapaSeccion(sec)
  local cuenta, mejor, n = {}, nil, 0
  for _, p in ipairs((sec and sec.pasos) or {}) do
    for _, d in ipairs(p.wp or {}) do
      if d.m then
        cuenta[d.m] = (cuenta[d.m] or 0) + 1
        if cuenta[d.m] > n then mejor, n = d.m, cuenta[d.m] end
      end
    end
  end
  return mejor
end

-- 8.5: si la posada (o el entrenador, la montura...) es de tu facción o neutral: lado = "A", "H" o nada.
function GL.DeMiLado(p)
  if not p.lado then return true end
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Horde" then return p.lado == "H" end
  return p.lado == "A"
end

-- Posada recomendada: la de la zona principal de la sección siguiente (o de esta si es la última).
local function PosadaRecomendada(vinc)
  local db = GuiaAventureroDB
  local secs = GL.RUTA and GL.RUTA.secciones
  if type(db) ~= "table" or not secs then return nil end
  local sig = secs[(db.seccion or 1) + 1] or secs[db.seccion or 1]
  local m = MapaSeccion(sig)
  local mejor, coste
  for _, p in ipairs(POSADAS) do
    if p.m == m and GL.DeMiLado(p) then
      -- Conservar la vinculación si ya está en una posada válida de la zona.
      if vinc and vinc == p.lugar then return p, sig end
      local suma, n = 0, 0
      for _, paso in ipairs(sig.pasos or {}) do
        for _, d in ipairs(paso.wp or {}) do
          if d.m == m and type(d.x) == "number" and type(d.y) == "number" then
            suma = suma + math.sqrt((p.x-d.x)^2 + (p.y-d.y)^2)
            n = n + 1
          end
        end
      end
      local c = n > 0 and suma/n or math.huge
      if not mejor or c < coste then mejor, coste = p, c end
    end
  end
  return mejor, sig
end

local function EstadoHogar()
  if GetItemCount then
    local ok, n = pcall(GetItemCount, 6948)
    if ok and n == 0 then return nil, "ausente" end
  end
  if not GetItemCooldown then return nil end
  local ok, inicio, dur, habilitado = pcall(GetItemCooldown, 6948)
  if not ok or type(inicio) ~= "number" or type(dur) ~= "number" or habilitado == 0 then return nil end
  if inicio == 0 or dur <= 1.5 then return 0 end
  if not GetTime then return nil end
  local tOK, ahora = pcall(GetTime)
  if not tOK or type(ahora) ~= "number" then return nil end
  return math.max(0, inicio + dur - ahora)
end

local function RefrescarHogar()
  local vinc = GetBindLocation and GetBindLocation()
  local resto, motivo = EstadoHogar()
  local estado = C.GRIS .. L"Estado desconocido" .. C.FIN
  if motivo == "ausente" then estado = C.GRIS .. L"Sin piedra de hogar" .. C.FIN end
  if resto == 0 then estado = C.VERDE .. L"lista" .. C.FIN
  elseif resto then estado = C.GRIS .. L"disponible en " .. math.ceil(resto / 60) .. L" min" .. C.FIN end
  ui.hogarEstado:SetText(estado)
  ui.hogarVinc:SetText(L"Vinculada en " .. C.AMARILLO .. (vinc or "?") .. C.FIN .. ".")
  local p, sig = PosadaRecomendada(vinc)
  ui.hogarBoton.destino = nil
  if p and vinc ~= p.lugar then
    ui.hogarRec:SetText((sig and (L"Siguiente sección: " .. C.AMARILLO .. sig.titulo .. C.FIN .. ". ") or "") .. L"Te conviene la posada de " ..
      C.AMARILLO .. p.lugar .. C.FIN .. C.GRIS .. " (" .. p.z .. ", " .. string.format("%.1f, %.1f", p.x, p.y) .. ")" .. C.FIN ..
      "")
    ui.hogarBoton.destino = { m = p.m, x = p.x, y = p.y, z = p.z, n = L"Posada de " .. p.lugar .. (p.n ~= "Posada" and p.n ~= L"Posada" and (" (" .. p.n .. ")") or "") }
    ui.hogarBoton:Show()
  elseif p then
    ui.hogarRec:SetText(C.VERDE .. L"Ya la tienes donde conviene para la sección siguiente." .. C.FIN)
    ui.hogarBoton:Hide()
  else
    ui.hogarRec:SetText(C.GRIS .. L"No hay posada conocida en la zona de la sección siguiente: deja la piedra de hogar donde está." .. C.FIN)
    ui.hogarBoton:Hide()
  end
end
GL.EstadoHogar = EstadoHogar

local function Refrescar()
  if not panel or not panel:IsVisible() then return end
  local zona = (GetZoneText and GetZoneText()) or ""
  local sub = (GetSubZoneText and GetSubZoneText()) or ""
  local mapas = MapasDeMiZona()
  local clave = zona
  for m in pairs(mapas) do clave = clave .. ":" .. m end
  if zonaFija then clave = L"fija:" .. zonaFija end   -- 7.5.12: zona elegida en Todas las zonas
  if modoTodas then clave = "todas" end
  if modoCerca then lista = ListaCerca(); clave = "cerca" end
  if clave ~= claveZona and not modoCerca then
    claveZona = clave
    desde = 0
    sel = nil
    if modoTodas then
      lista = {}
      for _, z in ipairs(ZonasRuta()) do
        local hechas = 0
        for q in pairs(z.qs) do if GL.MisionCompletada(q) then hechas = hechas + 1 end end
        table.insert(lista, { zona = z.zona, nombre = z.zona, hechas = hechas, total = z.total })
      end
    elseif zonaFija then
      RehacerLista(zonaFija, {})
    else
      RehacerLista(zona, mapas)
    end
  end
  if clave ~= claveZona then claveZona, desde, sel = clave, 0, nil end
  ui.todas.texto:SetText((modoTodas or zonaFija or modoCerca) and L"Esta zona" or L"Todas las zonas")
  ui.cerca:SetActivo(modoCerca)

  ui.zona:SetText(zona ~= "" and zona or L"Zona desconocida")
  ui.subzona:SetText(C.GRIS .. L"Subzona" .. C.FIN)
  ui.subzonaV:SetText(sub ~= "" and sub or C.GRIS .. "-" .. C.FIN)
  local mapa, x, y = GL.PosicionJugador()
  ui.coordsV:SetText(mapa and (C.AZUL .. string.format("%.1f, %.1f", x * 100, y * 100) .. C.FIN)
    or (C.GRIS .. L"no disponibles aquí" .. C.FIN))

  -- misiones de la guía en esta zona (7.5.12: o de toda la ruta, por zonas)
  local hechas, estados = 0, {}
  local total = #lista
  if modoCerca then
    for i in ipairs(lista) do estados[i] = "cerca" end
  elseif modoTodas then
    total = 0
    for i, e in ipairs(lista) do hechas, total = hechas + e.hechas, total + e.total; estados[i] = "zona" end
  else
    for i, e in ipairs(lista) do
      estados[i] = Estado(e.q)
      if estados[i] == "hecha" then hechas = hechas + 1 end
    end
  end
  ui.tituloLista:SetText(modoCerca and L"Cerca de ti" or modoTodas and L"Tu ruta por zonas" or (zonaFija and (L"Misiones de la guía en " .. zonaFija) or L"Misiones de la guía en esta zona"))
  if modoCerca then
    ui.cuenta:SetText(C.GRIS .. #lista .. L" sitios" .. C.FIN)
    ui.barra:SetMinMaxValues(0, 1); ui.barra:SetValue(0)
    ui.barra.texto:SetText("")
  elseif total == 0 then
    ui.cuenta:SetText(C.GRIS .. "ninguna" .. C.FIN)
    ui.barra:SetMinMaxValues(0, 1); ui.barra:SetValue(0)
    ui.barra.texto:SetText("")
  else
    ui.cuenta:SetText(C.VERDE .. hechas .. L" de " .. total .. C.FIN)
    ui.barra:SetMinMaxValues(0, total); ui.barra:SetValue(hechas)
    ui.barra.texto:SetText(math.floor(hechas * 100 / total) .. " %")
  end
  local caben = #ui.filas
  local maximo = math.max(0, #lista - caben)
  if desde > maximo then desde = maximo end
  ui.acc:Hide()
  local hueco = 0
  for i = 1, caben do
    local f, j = ui.filas[i], desde + i
    local e = lista[j]
    f.entrada = e
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -112 - (i - 1) * ALTO_FILA - hueco)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -112 - (i - 1) * ALTO_FILA - hueco)
    if e and hueco > 0 and i == caben then e = nil end   -- los botones ocupan el sitio de la última fila
    GL.Mostrar(f.marca, e ~= nil and sel == e.q)
    if e and modoCerca then
      f.nombre:SetText(C.AMARILLO .. (e.juntas > 1 and ("[" .. e.juntas .. "] ") or "") .. e.nombre .. C.FIN)
      f.estado:SetText(C.GRIS .. math.floor(e.dist * 0.9144 + 0.5) .. " m" .. C.FIN)
      f:Show()
      if sel == e.q then
        ui.acc.entrada = e
        ui.acc:ClearAllPoints()
        ui.acc:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 10, -2)
        ui.acc:Show()
        hueco = 22
      end
    elseif e and modoTodas then
      local pct = e.total > 0 and math.floor(e.hechas * 100 / e.total) or 0
      local col = (pct >= 100 and C.VERDE) or (pct > 0 and C.AMARILLO) or C.GRIS
      f.nombre:SetText(col .. e.nombre .. C.FIN)
      f.estado:SetText(col .. pct .. " %" .. C.FIN .. C.GRIS .. " · " .. e.hechas .. "/" .. e.total .. C.FIN)
      f:Show()
    elseif e then
      local st = estados[j]
      if st == "hecha" then
        f.nombre:SetText(C.VERDE .. "+ " .. e.nombre .. C.FIN)
        f.estado:SetText(C.GRIS .. "hecha" .. C.FIN)
      else
        f.nombre:SetText(C.BLANCO .. "· " .. C.FIN .. C.AMARILLO .. e.nombre .. C.FIN)
        f.estado:SetText(C.GRIS .. (st == "curso" and L"en curso" or "pendiente") .. C.FIN)
      end
      f:Show()
      if sel == e.q and st ~= "hecha" then
        ui.acc.entrada = e
        ui.acc:ClearAllPoints()
        ui.acc:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 10, -2)
        ui.acc:Show()
        hueco = 22
      end
    else
      f:Hide()
    end
  end
  GL.Mostrar(ui.acc.paso, not modoCerca)
  if modoCerca and #lista == 0 then
    ui.vacia:SetText(C.GRIS .. L"No hay entrenadores, vendedores, raros ni posadas de la guía en tu continente." .. C.FIN)
  elseif modoCerca then
    ui.vacia:SetText(maximo > 0 and (C.GRIS .. (desde + 1) .. "-" .. math.min(#lista, desde + caben) .. L" de " .. #lista .. L" (rueda del ratón)" .. C.FIN) or "")
  elseif total == 0 then
    ui.vacia:SetText(C.GRIS .. L"La guía no tiene misiones en esta zona." .. C.FIN)
  elseif maximo > 0 then
    ui.vacia:SetText(C.GRIS .. (modoTodas and L"Zonas " or L"Misiones ") .. (desde + 1) .. "-" .. math.min(#lista, desde + caben) .. L" de " .. #lista ..
      L" (rueda del ratón para ver más)" .. C.FIN)
  else
    ui.vacia:SetText("")
  end

  -- 9.4.2: sin «Destino de la flecha» (la línea de la flecha de arriba ya dice adónde y a cuánto)
  for _, c in ipairs(ui.casillas) do c.Actualizar() end
  pcall(RefrescarVuelos, zona, mapas)
  pcall(RefrescarHogar)
end

-- Cuántas filas de misiones caben entre la barra y el bloque del destino.
local function Disponer()
  if not panel then return end
  local alto = (panel:GetHeight() or 0)
  local libre = alto - 112 - (FONDO + 22) - VUELOS_ALTO - HOGAR_ALTO       -- arriba: zona, coordenadas, título y barra; abajo: vuelos y hogar
  local caben = math.max(2, math.floor(libre / ALTO_FILA))
  for i = #ui.filas + 1, caben do
    local f = CreateFrame("Button", nil, panel)
    f:SetHeight(ALTO_FILA)
    f.marca = f:CreateTexture(nil, "BACKGROUND")
    f.marca:SetAllPoints()
    f.marca:SetColorTexture(1, 0.82, 0, 0.12)
    f.marca:Hide()
    local brillo = f:CreateTexture(nil, "HIGHLIGHT")
    brillo:SetAllPoints()
    brillo:SetColorTexture(1, 1, 1, 0.06)
    f:SetScript("OnClick", function(self)
      local e = self.entrada
      if not e then return end
      if modoTodas then   -- 7.5.12: abre las misiones de esa zona
        modoTodas, zonaFija, claveZona = false, e.zona, nil
        Refrescar()
        return
      end
      sel = (sel ~= e.q) and e.q or nil
      Refrescar()
    end)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -112 - (i - 1) * ALTO_FILA)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -112 - (i - 1) * ALTO_FILA)
    f.estado = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.estado:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.estado:SetWidth(70)
    f.nombre = GL.Texto(f, "GameFontHighlightSmall")
    f.nombre:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.nombre:SetPoint("RIGHT", f.estado, "LEFT", -4, 0)
    GL.UnaLinea(f.nombre)
    ui.filas[i] = f
  end
  for i = caben + 1, #ui.filas do ui.filas[i]:Hide() end
  for i = #ui.filas, caben + 1, -1 do ui.filas[i] = nil end
  ui.vacia:ClearAllPoints()
  ui.vacia:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -112 - caben * ALTO_FILA - 2)
  ui.vacia:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -112 - caben * ALTO_FILA - 2)
end

------------------------------------------------------------------------
-- Crear
------------------------------------------------------------------------
local function Par(y, ancla)
  local k = GL.Texto(panel, "GameFontHighlightSmall")
  local v = GL.Texto(panel, "GameFontHighlightSmall", "RIGHT")
  if ancla then
    k:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, y)
    v:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, y)
  else
    k:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    v:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y)
  end
  v:SetPoint("LEFT", k, "RIGHT", 8, 0)
  GL.UnaLinea(k); GL.UnaLinea(v)
  return k, v
end

local function Seccion(texto, y, abajo)
  local t = GL.Texto(panel, "GameFontNormal")
  local linea = panel:CreateTexture(nil, "ARTWORK")
  linea:SetHeight(1)
  linea:SetColorTexture(1, 1, 1, 0.08)
  if abajo then
    t:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, y)
  else
    t:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
  end
  linea:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -3)
  linea:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  t:SetText(texto)
  return t
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  local fuera = CreateFrame("Frame", nil, frame)
  fuera:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)
  fuera:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  fuera:Hide()
  ui.fuera = fuera
  -- 9.6: la vista de siempre va en un marco interior; con la Guía clara, encima van las tarjetas (ExploracionClara)
  panel = CreateFrame("Frame", nil, fuera)
  panel:SetPoint("TOPLEFT", fuera, "TOPLEFT", 0, 0)
  panel:SetPoint("BOTTOMRIGHT", fuera, "BOTTOMRIGHT", 0, 0)
  ui.interior = panel

  ui.zona = GL.Texto(panel, "GameFontNormalLarge")
  ui.zona:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  ui.zona:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  GL.UnaLinea(ui.zona)
  ui.subzona, ui.subzonaV = Par(-24)
  local k
  k, ui.coordsV = Par(-40)
  k:SetText(L"Tus coordenadas")

  ui.tituloLista = Seccion(L"Misiones de la guía en esta zona", -62)
  ui.todas = GL.CrearBoton(panel, L"Todas las zonas", function()
    if modoTodas or zonaFija or modoCerca then modoTodas, zonaFija, modoCerca = false, nil, false else modoTodas = true end
    claveZona = nil
    Refrescar()
  end, nil, 16)
  ui.todas:SetWidth(100)
  ui.todas:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -60)
  ui.cerca = GL.CrearBoton(panel, L"Cerca de ti", function()   -- 7.6
    modoCerca = not modoCerca
    if modoCerca then modoTodas, zonaFija = false, nil end
    claveZona = nil
    Refrescar()
  end, nil, 16)
  ui.cerca:SetWidth(80)
  ui.cerca:SetPoint("RIGHT", ui.todas, "LEFT", -4, 0)
  ui.tituloLista:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -190, -62); GL.UnaLinea(ui.tituloLista)   -- 7.6.1: no pisa los botones
  GL.Ayuda(ui.cerca, L"Cerca de ti", L"Entrenadores, vendedores, raros, bolsas, posadas y objetivos activos de esta zona. El número entre corchetes indica actividades en las mismas coordenadas. Clic en uno: Seguir.")
  GL.Ayuda(ui.todas, L"Todas las zonas", L"Cambia la lista por las zonas de tu ruta con el porcentaje de misiones hechas. Clic en una zona: sus misiones.")
  k, ui.cuenta = Par(-80)
  k:SetText(L"Completadas")
  ui.barra = GL.CrearBarra(panel, GL.COLOR.verde[1], GL.COLOR.verde[2], GL.COLOR.verde[3])
  ui.barra:SetHeight(12)
  ui.barra:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -95)
  ui.barra:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -95)
  ui.vacia = GL.Texto(panel, "GameFontHighlightSmall")
  GL.UnaLinea(ui.vacia)

  -- 6.2: botones de la misión pulsada
  local acc = CreateFrame("Frame", nil, panel)
  acc:SetWidth(200); acc:SetHeight(18)
  acc:Hide()
  local function Pendiente(e)   -- primer destino de la misión que falta (o el primero si no se sabe)
    for _, x in ipairs(e.destinos) do
      if GL.DestinoHecho(x.wp) == false then return x end
    end
    return e.destinos[1]
  end
  acc.seguir = GL.CrearBoton(acc, L"Seguir", function()
    local x = acc.entrada and Pendiente(acc.entrada)
    if x and GL.SeguirDesvio then GL.SeguirDesvio(x.wp) end
    sel = nil
    Refrescar()
  end, nil, 18, "accion")
  acc.seguir:SetWidth(62)
  acc.seguir:SetPoint("LEFT", acc, "LEFT", 0, 0)
  GL.Ayuda(acc.seguir, L"Seguir", L"La flecha va a esta misión como desvío, sin cambiar tu paso.")
  acc.paso = GL.CrearBoton(acc, L"Ir a su paso", function()
    local x = acc.entrada and Pendiente(acc.entrada)
    sel = nil
    if x and GL.IrAPaso then GL.IrAPaso(x.s, x.p, x.i) end
  end, nil, 18)
  acc.paso:SetWidth(86)
  acc.paso:SetPoint("LEFT", acc.seguir, "RIGHT", 4, 0)
  GL.Ayuda(acc.paso, L"Ir a su paso", L"La guía salta al paso de esta misión.")
  ui.acc = acc

  -- 7.5.8: piedra de hogar y posada recomendada para la sección siguiente
  local yH = FONDO + VUELOS_ALTO + HOGAR_ALTO
  Seccion(L"Piedra de hogar", yH, true)
  ui.hogarEstado = GL.Texto(panel, "GameFontHighlightSmall", "RIGHT")
  ui.hogarEstado:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, yH)
  ui.hogarVinc = GL.Texto(panel, "GameFontHighlightSmall")
  ui.hogarVinc:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, yH - 22)
  ui.hogarBoton = GL.CrearBoton(panel, L"Llevarme a la posada", function(self) end, nil, 16)
  ui.hogarBoton:SetScript("OnClick", function(self) if self.destino and GL.SeguirDesvio then GL.SeguirDesvio(self.destino) end end)
  ui.hogarBoton:SetWidth(132)
  ui.hogarBoton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, yH - 24)
  GL.Ayuda(ui.hogarBoton, L"Llevarme a la posada", L"La flecha te lleva al posadero como desvío, sin cambiar tu paso, por si quieres poner allí la piedra.")
  ui.hogarVinc:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -138, yH - 22); GL.UnaLinea(ui.hogarVinc)   -- 7.6.1
  ui.hogarEstado:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 110, yH); GL.UnaLinea(ui.hogarEstado)
  ui.hogarRec = GL.Texto(panel, "GameFontHighlightSmall")
  ui.hogarRec:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, yH - 56)
  ui.hogarRec:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, yH - 56)
  ui.hogarRec:SetHeight(30)

  -- 6.9: puntos de vuelo (los de la zona y los siguientes que te faltan en la ruta)
  Seccion(L"Puntos de vuelo", FONDO + VUELOS_ALTO, true)
  if GL.AbrirVuelos94 then   -- 9.4: todos los que te faltan
    ui.vuelosTodos = GL.CrearBoton(panel, L"Por descubrir", function() GL.AbrirVuelos94() end, nil, 16)
    ui.vuelosTodos:SetWidth(96)
    ui.vuelosTodos.texto:SetJustifyH("CENTER")
    ui.vuelosTodos:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, FONDO + VUELOS_ALTO - 2)
    GL.Ayuda(ui.vuelosTodos, L"Vuelos por descubrir", L"Todos los puntos de vuelo de tu facción que aún no tienes, con Llevarme.")
  end
  ui.vuelos = {}
  for i = 1, 3 do
    local f = CreateFrame("Frame", nil, panel)
    f:SetHeight(16)
    f:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, FONDO + VUELOS_ALTO - 22 - i * 16)
    f:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, FONDO + VUELOS_ALTO - 22 - i * 16)
    f.boton = GL.CrearBoton(f, L"Llevarme", function(self) end, nil, 15)
    f.boton:SetScript("OnClick", function(self) if self.destino and GL.SeguirDesvio then GL.SeguirDesvio(self.destino) end end)
    f.boton:SetWidth(64)
    f.boton:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.texto = GL.Texto(f, "GameFontHighlightSmall")
    f.texto:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.texto:SetPoint("RIGHT", f.boton, "LEFT", -4, 0)
    GL.UnaLinea(f.texto)
    f:Hide()
    ui.vuelos[i] = f
  end
  ui.vuelosVacio = GL.Texto(panel, "GameFontHighlightSmall")
  ui.vuelosVacio:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, FONDO + VUELOS_ALTO - 38)
  ui.vuelosVacio:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, FONDO + VUELOS_ALTO - 38); GL.UnaLinea(ui.vuelosVacio)   -- 7.6.1: dentro del marco

  ui.casillas = {}   -- 9.0: «Mostrar la flecha» y «Destinos en el mapa» ya están en Ajustes y en el botón de la flecha

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    desde = math.max(0, desde - delta * 3)
    Refrescar()
  end)
  panel:SetScript("OnSizeChanged", function() Disponer(); Refrescar() end)
  Disponer()
  local function Todo()
    if ui.Clara and ui.Clara() then return end   -- 9.6: tarjetas (y la vista de siempre si está abierta)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", fuera, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", fuera, "BOTTOMRIGHT", 0, 0)
    panel:Show()
    Disponer(); Refrescar()
  end
  ui.Disponer, ui.Refrescar = Disponer, Refrescar
  local esperaF = 0
  fuera:SetScript("OnUpdate", function(_, dt)
    esperaF = esperaF + dt
    if esperaF >= CADA then
      esperaF = 0
      if panel:IsShown() then Refrescar()
      elseif ui.Clara then pcall(ui.Clara) end
    end
  end)
  GL.modos.exploracion = { panel = fuera, refrescar = Todo }
end

------------------------------------------------------------------------
-- 9.6: con la Guía clara, tres tarjetas (dónde estás, piedra de hogar, vuelo que te falta) y lo de siempre en
-- un desplegable «Misiones de la zona, vuelos y Tu viaje»
------------------------------------------------------------------------
local clara = {}
local function TextoDe(f) local ok, x = pcall(f.GetText, f); return ok and type(x) == "string" and x or "" end

local function ExploracionClara()
  local fuera = ui.fuera
  if not (GL.PestanasClaras and GL.PestanasClaras() and GL.CrearTarjeta96) then
    for _, k in ipairs({ "donde", "hogar", "vuelo", "desp" }) do if clara[k] then clara[k]:Hide() end end
    return false
  end
  if not clara.donde then
    clara.donde = GL.CrearTarjeta96(fuera, true)
    clara.hogar = GL.CrearTarjeta96(fuera)
    clara.vuelo = GL.CrearTarjeta96(fuera)
    clara.desp = GL.CrearDesplegable96(fuera, "exploTodo", function() GL.modos.exploracion.refrescar() end)
  end
  local ancho = (fuera:GetWidth() or 0) > 60 and fuera:GetWidth() or 400
  local abierto = clara.desp:Abierto()
  if abierto then
    clara.donde:Hide(); clara.hogar:Hide(); clara.vuelo:Hide()
    local h = clara.desp:Pintar(0, L"Misiones de la zona, vuelos y Tu viaje")
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", fuera, "TOPLEFT", 0, -(h + 8))
    panel:SetPoint("BOTTOMRIGHT", fuera, "BOTTOMRIGHT", 0, 0)
    panel:Show()
    Disponer(); Refrescar()
    return true
  end
  panel:Hide()
  local zona = (GetZoneText and GetZoneText()) or ""
  local sub = (GetSubZoneText and GetSubZoneText()) or ""
  local mapas = MapasDeMiZona()
  -- misiones de la guía en tu zona (sin tocar la lista de la vista de siempre)
  local guardada = lista
  RehacerLista(zona, mapas)
  local hechas, curso, quedan = 0, 0, 0
  for _, e in ipairs(lista) do
    local st = Estado(e.q)
    if st == "hecha" then hechas = hechas + 1 elseif st == "curso" then curso = curso + 1 else quedan = quedan + 1 end
  end
  local total = #lista
  lista = guardada
  local y = 0
  local textoDonde
  if total == 0 then
    textoDonde = C.GRIS .. L"La guía no tiene misiones en esta zona." .. C.FIN
  else
    textoDonde = L"Misiones de la guía aquí: " .. C.AMARILLO .. (quedan + curso) .. L" por hacer" .. C.FIN ..
      (curso > 0 and (C.GRIS .. " (" .. curso .. L" en el diario)" .. C.FIN) or "") .. " · " .. C.VERDE .. hechas .. L" hechas" .. C.FIN ..
      C.GRIS .. " · " .. math.floor(hechas * 100 / total) .. " %" .. C.FIN
  end
  y = y + clara.donde:Pintar(y, ancho, C.AMARILLO .. L"Dónde estás" .. C.FIN,
    C.BLANCO .. (zona ~= "" and zona or L"Zona desconocida") .. C.FIN .. (sub ~= "" and (C.GRIS .. " · " .. sub .. C.FIN) or ""),
    textoDonde, total > 0 and { { L"Ver misiones", function() GuiaAventureroDB.exploTodo = true; GL.modos.exploracion.refrescar() end, 96 } } or nil) + 8
  -- piedra de hogar
  pcall(RefrescarHogar)
  local rec = TextoDe(ui.hogarRec)
  local hogarBotones = ui.hogarBoton:IsShown() and ui.hogarBoton.destino and
    { { L"Llevarme a la posada", function() GL.SeguirDesvio(ui.hogarBoton.destino) end, 132 } } or nil
  y = y + clara.hogar:Pintar(y, ancho, C.AMARILLO .. L"Piedra de hogar" .. C.FIN, TextoDe(ui.hogarEstado),
    TextoDe(ui.hogarVinc) .. (rec ~= "" and ("\n" .. rec) or ""), hogarBotones) + 8
  -- el vuelo más cercano que te falta
  pcall(RefrescarVuelos, zona, mapas)
  local vuelo
  for i = 1, 3 do
    local f = ui.vuelos[i]
    if f:IsShown() and f.boton:IsShown() and f.boton.destino then vuelo = f; break end
  end
  local botonesVuelo = {}
  if vuelo then table.insert(botonesVuelo, { L"Llevarme", function() GL.SeguirDesvio(vuelo.boton.destino) end, 96 }) end
  if GL.AbrirVuelos94 then table.insert(botonesVuelo, { L"Por descubrir", function() GL.AbrirVuelos94() end, 96 }) end
  y = y + clara.vuelo:Pintar(y, ancho, C.AMARILLO .. L"Vuelos que te faltan" .. C.FIN, "",
    vuelo and ((vuelo.distVuelo ~= nil and L"El más cercano: " or L"Vuelo en tu zona: ") .. TextoDe(vuelo.texto)) or (C.VERDE .. L"Tienes los puntos de vuelo cercanos de tu ruta." .. C.FIN),
    #botonesVuelo > 0 and botonesVuelo or nil) + 8
  clara.desp:Pintar(y, L"Misiones de la zona, vuelos y Tu viaje")
  return true
end
ui.Clara = ExploracionClara

table.insert(GL.alIniciar, CrearPanel)

-- 6.9: al abrir el mapa de vuelo hablando con un PNJ, ese punto de vuelo queda activado
local ev = CreateFrame("Frame")
GL.Evento(ev, "TAXIMAP_OPENED")
ev:SetScript("OnEvent", function()
  local db = GuiaAventureroDB
  local nombre = UnitName and UnitName("npc")
  if type(db) == "table" and type(nombre) == "string" and nombre ~= "" then
    db.vuelos = db.vuelos or {}
    db.vuelos[nombre] = true
  end
end)
GL._vuelos = function() return VUELOS end
GL._exploUI = ui   -- 9.0: Secciones9.lua pone el botón Tu viaje
GL._zonas = { Cerca = function(v) modoCerca, modoTodas, zonaFija, claveZona = v, false, nil, nil end, Lista = function() return lista end,
  Todas = function(v) modoTodas, zonaFija, claveZona = v, nil, nil end, Fija = function(z) modoTodas, zonaFija, claveZona = false, z, nil end, Zonas = ZonasRuta }
GL._hogar = { Posada = PosadaRecomendada, Estado = EstadoHogar, Refrescar = RefrescarHogar, POSADAS = POSADAS }

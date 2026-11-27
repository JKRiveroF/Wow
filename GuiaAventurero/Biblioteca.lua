-- Biblioteca.lua: biblioteca de datos del mundo (6.8). Se abre con el botón Biblioteca del lateral derecho.
-- Categorías (Zonas, Facciones, Mazmorras, Razas y clases, Profesiones), buscador, lista y ficha con
-- enlaces a lo relacionado. Cada categoría se carga solo al abrirla. Solo lee datos.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local ALTO_FILA = 18
local FILAS = 6
local CADA = 2

local panel, ui = nil, { filas = {}, cats = {}, rel = {} }
local cat, desde, sel, busqueda = "zonas", 0, nil, ""
local cargadas = {}               -- categoría -> lista de entradas (se rellena al abrirla)

------------------------------------------------------------------------
-- Entradas. Campos: n (nombre), min/max (niveles), lado (Alianza, Horda, Neutral), desc, puntos (lista),
-- rel (lista de { t = "mazmorra"|"faccion"|"destino", n = texto, ... }), fuente, comprobado.
------------------------------------------------------------------------
local MODULOS = {}

-- Zonas: 7.6, niveles de theforeverguides.com (Forever); mazmorras y facciones relacionadas de los datos de la guía.
MODULOS.zonas = function()
  return {
    { n = L"Bosque de Elwynn", min = 1, max = 10, lado = L"Alianza", region = L"Reinos del Este", desc = L"Bosques y granjas alrededor de Ventormenta.", puntos = { L"Villadorada (posada e instructores)", L"Ventormenta, al noroeste" }, rel = { { t = "faccion", id = 72, n = L"Ventormenta" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = "Dun Morogh", min = 1, max = 12, lado = L"Alianza", region = L"Reinos del Este", desc = L"Tierras nevadas de los enanos y los gnomos, alrededor de Forjaz.", puntos = { L"Kharanos (posada e instructores)", L"Forjaz, al este" }, rel = { { t = "mazmorra", n = "Gnomeregan" }, { t = "mazmorra", n = L"Salón de los Feudales" }, { t = "faccion", id = 47, n = L"Forjaz" }, { t = "faccion", id = 54, n = L"Exiliados de Gnomeregan" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = "Teldrassil", min = 1, max = 11, lado = L"Alianza", region = "Kalimdor", rel = { { t = "faccion", id = 69, n = "Darnassus" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Isla Zephras", min = 1, max = 12, lado = L"Ambas (inicio de los Skyborne)", region = L"Islas", desc = L"Zona nueva de Forever: inicio de los Skyborne.", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    -- 8.5: zonas de inicio de la Horda.
    { n = "Durotar", min = 1, max = 10, lado = L"Horda", region = "Kalimdor", desc = L"Tierra roja de los orcos y los trols, alrededor de Orgrimmar.", puntos = { L"Valle de los Retos (inicio)", L"Cerrotajo (posada e instructores)", L"Orgrimmar, al norte" }, rel = { { t = "mazmorra", n = L"Sima Ígnea" }, { t = "faccion", id = 76, n = "Orgrimmar" }, { t = "faccion", id = 530, n = L"Trols Lanza Negra" } }, fuente = L"datos de la guía (rutas de la Horda)", comprobado = false },
    { n = "Mulgore", min = 1, max = 10, lado = L"Horda", region = "Kalimdor", desc = L"Praderas de los tauren, alrededor de Cima del Trueno.", puntos = { L"Campamento Narache (inicio)", L"Poblado Pezuña de Sangre (posada e instructores)", L"Cima del Trueno, al norte" }, rel = { { t = "faccion", id = 81, n = L"Cima del Trueno" } }, fuente = L"datos de la guía (rutas de la Horda)", comprobado = false },
    { n = L"Claros de Tirisfal", min = 1, max = 10, lado = L"Horda", region = L"Reinos del Este", desc = L"Bosques muertos de los Renegados, sobre Entrañas.", puntos = { L"Camposanto (inicio)", L"Rémol (posada e instructores)", L"Entrañas, al sureste" }, rel = { { t = "mazmorra", n = L"Ruinas de Lordaeron" }, { t = "mazmorra", n = L"Monasterio Escarlata" }, { t = "faccion", id = 68, n = L"Entrañas" } }, fuente = L"datos de la guía (rutas de la Horda)", comprobado = false },
    { n = L"Bosque de Argénteos", min = 10, max = 20, lado = L"Horda", region = L"Reinos del Este", desc = L"Bosque de los Renegados al sur de Tirisfal, frente a los huargos de Arugal.", puntos = { L"El Sepulcro (posada y vuelo)" }, rel = { { t = "mazmorra", n = L"Castillo de Colmillo Oscuro" }, { t = "mazmorra", n = L"Ciudad de Dalaran" } }, fuente = L"datos de la guía (rutas de la Horda)", comprobado = false },
    { n = L"Páramos de Poniente", min = 9, max = 18, lado = L"Alianza", region = L"Reinos del Este", desc = L"Granjas tomadas por la Hermandad Defias al oeste de Elwynn.", puntos = { L"Colina del Centinela (vuelo, posada, instructores)", L"Arroyo de la Luna: entrada a Las Minas de la Muerte" }, rel = { { t = "mazmorra", n = L"Las Minas de la Muerte" }, { t = "faccion", id = 72, n = L"Ventormenta" }, { t = "destino", n = L"Colina del Centinela", d = { m = 1436, x = 56.3, y = 47.5, n = L"Colina del Centinela" } } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = "Loch Modan", min = 10, max = 18, lado = L"Alianza", region = L"Reinos del Este", desc = L"Lago y colinas al este de Dun Morogh, con la gran presa de Thelsamar.", puntos = { L"Thelsamar (vuelo, posada)" }, rel = { { t = "faccion", id = 47, n = L"Forjaz" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Los Baldíos", min = 10, max = 33, lado = L"Horda", region = "Kalimdor", rel = { { t = "mazmorra", n = L"Cavernas de los Lamentos" }, { t = "mazmorra", n = L"Horado Rajacieno" }, { t = "mazmorra", n = L"Zahúrda Rajacieno" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Bosque del Ocaso", min = 10, max = 30, lado = L"En disputa", region = L"Reinos del Este", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Costa Oscura", min = 11, max = 19, lado = L"Alianza", region = "Kalimdor", rel = { { t = "faccion", id = 69, n = "Darnassus" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Montañas Crestagrana", min = 15, max = 25, lado = L"En disputa", region = L"Reinos del Este", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Sierra Espolón", min = 15, max = 25, lado = L"En disputa", region = "Kalimdor", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Vallefresno", min = 19, max = 30, lado = L"En disputa", region = "Kalimdor", rel = { { t = "mazmorra", n = L"Cavernas de Brazanegra" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Los Humedales", min = 20, max = 30, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = L"Excavación" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Laderas de Trabalomas", min = 20, max = 31, lado = L"En disputa", region = L"Reinos del Este", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Las Mil Agujas", min = 24, max = 35, lado = L"En disputa", region = "Kalimdor", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Montañas de Alterac", min = 27, max = 39, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = L"Ciudad de Dalaran" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Tierras Altas de Arathi", min = 30, max = 40, lado = L"En disputa", region = L"Reinos del Este", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = "Desolace", min = 30, max = 39, lado = L"En disputa", region = "Kalimdor", rel = { { t = "mazmorra", n = "Maraudon" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Vega de Tuercespina", min = 30, max = 50, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = L"La Ciudad Sumergida" }, { t = "faccion", id = 21, n = L"Bahía del Botín" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Clarofluvial", min = 35, max = 45, lado = L"En disputa", region = L"Reinos del Este", desc = L"Zona nueva de Forever. Alianza: Farholde Keep (vuelo con Gretchen Mayberry, 60.6, 81.6), a pie por el norte de Crestagrana o en barco desde Puerto Bonvapor.", rel = { { t = "mazmorra", n = L"Bastión Krol'dok" }, { t = "faccion", id = 2826, n = L"Hermandad de la Caballería" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Tierras Inhóspitas", min = 36, max = 45, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = "Uldaman" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Marjal Revolcafango", min = 36, max = 45, lado = L"En disputa", region = "Kalimdor", rel = { { t = "mazmorra", n = L"Prisión de Alcaz" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Pantano de las Penas", min = 36, max = 43, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = L"Templo de Atal'Hakkar" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = "Tanaris", min = 40, max = 50, lado = L"En disputa", region = "Kalimdor", rel = { { t = "mazmorra", n = "Zul'Farrak" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = "Feralas", min = 41, max = 50, lado = L"En disputa", region = "Kalimdor", rel = { { t = "mazmorra", n = L"La Masacre" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Tierras del Interior", min = 41, max = 49, lado = L"En disputa", region = L"Reinos del Este", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = "Azshara", min = 42, max = 55, lado = L"En disputa", region = "Kalimdor", rel = { { t = "mazmorra", n = L"Bastión Faucenegra" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"La Garganta de Fuego", min = 43, max = 50, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = L"Profundidades de Roca Negra" }, { t = "mazmorra", n = L"Cumbre de Roca Negra" }, { t = "faccion", id = 59, n = L"Hermandad del Torio" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Las Tierras Devastadas", min = 46, max = 55, lado = L"En disputa", region = L"Reinos del Este", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Tierras de la Peste del Oeste", min = 46, max = 57, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = "Scholomance" }, { t = "faccion", id = 529, n = L"El Alba Argenta" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Frondavil", min = 47, max = 54, lado = L"En disputa", region = "Kalimdor", rel = { { t = "faccion", id = 576, n = L"Bastión Fauces de Madera" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Cráter de Un'Goro", min = 48, max = 55, lado = L"En disputa", region = "Kalimdor", rel = { { t = "mazmorra", n = L"Bancal del Creador" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Las Estepas Ardientes", min = 50, max = 59, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = L"Profundidades de Roca Negra" }, { t = "mazmorra", n = L"Cumbre de Roca Negra" }, { t = "faccion", id = 59, n = L"Hermandad del Torio" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Paso de la Muerte", min = 50, max = 60, lado = L"En disputa", region = L"Reinos del Este", desc = L"Sin misiones.", fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Tierras de la Peste del Este", min = 54, max = 59, lado = L"En disputa", region = L"Reinos del Este", rel = { { t = "mazmorra", n = "Stratholme" }, { t = "faccion", id = 529, n = L"El Alba Argenta" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = "Silithus", min = 55, max = 59, lado = L"En disputa", region = "Kalimdor", rel = { { t = "faccion", id = 609, n = L"Círculo Cenarion" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Cuna del Invierno", min = 55, max = 60, lado = L"En disputa", region = "Kalimdor", rel = { { t = "faccion", id = 576, n = L"Bastión Fauces de Madera" } }, fuente = L"theforeverguides.com y datos de la guía", comprobado = false },
    { n = L"Monte Hyjal", min = 56, max = 60, lado = L"En disputa", region = "Kalimdor", desc = L"Zona nueva de Forever: sus misiones son de nivel 56 a 60.", fuente = L"QuestieDB (Forever): niveles de sus misiones", comprobado = true },
  }
end

-- Facciones: las mismas fichas de la guía de reputación (6.6).
MODULOS.facciones = function()
  local lista, fichas = {}, GL.DatosReputacion and GL.DatosReputacion() or {}
  for id, f in pairs(fichas) do
    local puntos = {}
    for i = 1, #(f.subir or {}) do table.insert(puntos, f.subir[i]) end
    for i = 1, #(f.recompensas or {}) do table.insert(puntos, L"Recompensa: " .. f.recompensas[i]) end
    if f.pendiente then table.insert(puntos, L"Datos parciales: comprobar en Forever.") end
    local function ActualizarAviso(e)
      local actuales = {}
      for i = 1, #puntos do actuales[i] = puntos[i] end
      local aviso = GL.AvisoFaccion977 and GL.AvisoFaccion977(f, id)
      if aviso then actuales[#actuales+1] = aviso end
      e.puntos = actuales
    end
    local e = { n = f.n or (L"Facción " .. id), desc = f.intendente and (L"Intendente: " .. f.intendente) or nil,
      dinamico = ActualizarAviso, rel = { { t = "faccion", id = id, n = L"Ver en Reputación" } }, fuente = f.fuente or L"guía de reputación", comprobado = f.confirmado }
    ActualizarAviso(e)
    table.insert(lista, e)
  end
  table.sort(lista, function(a, b) return a.n < b.n end)
  return lista
end

-- Mazmorras: los mismos datos de la guía de mazmorras (6.7).
MODULOS.mazmorras = function()
  local lista, datos = {}, GL.DatosMazmorras and GL.DatosMazmorras() or {}
  for i = 1, #datos do
    local m = datos[i]
    local rel = { { t = "mazmorra", n = m.n, texto = L"Ver en Mazmorras" } }
    if m.e then table.insert(rel, { t = "destino", n = L"Llevarme", d = { m = m.e.m, x = m.e.x, y = m.e.y, n = L"Entrada de " .. m.n } }) end
    table.insert(lista, { n = m.n, min = m.min, max = m.max, desc = m.z, puntos = { #m.misiones .. ((UnitFactionGroup and UnitFactionGroup("player") == "Horde") and L" misiones de la Horda" or L" misiones de la Alianza") },
      rel = rel, fuente = m.nueva and L"Wowhead y Warcraft Tavern (nueva de Forever)" or L"guía de mazmorras y QuestieDB", comprobado = true })
  end
  table.sort(lista, function(a, b) return a.min < b.min end)
  return lista
end

-- 7.5.16: categorías que se rellenan desde DatosWowhead.lua
local function WH(clave) return (GL.WH and GL.WH[clave]) or {} end
local function Dinero(c) return (GL.Dinero and GL.Dinero(c)) or (tostring(c) .. " c") end
local function Coord(e) return (e.x and e.y) and string.format("%.1f, %.1f", e.x, e.y) or nil end
local function LadoActual()
  if type(UnitFactionGroup) ~= "function" then return nil end
  local ok, f = pcall(UnitFactionGroup, "player")
  if ok then return f == "Alliance" and "A" or (f == "Horde" and "H" or nil) end
end
local function Llevar(e, nombre)
  if not (e.m and e.x and e.y) then return nil end
  return { t = "destino", n = L"Llevarme", d = { m = e.m, x = e.x, y = e.y, n = nombre or e.n } }
end
local function Zona() return (GetZoneText and GetZoneText()) or "" end

MODULOS.raros = function()
  local lista, zona = {}, Zona()
  for _, r in ipairs(WH("raros")) do
    local puntos = {}
    if r.zona then table.insert(puntos, r.zona .. (Coord(r) and (" · " .. Coord(r)) or "")) end
    if r.ing then table.insert(puntos, L"En inglés: " .. r.ing) end
    table.insert(puntos, #(r.botin or {}) > 0 and (#r.botin .. L" objetos en su botín") or L"Sin botín propio conocido")
    local rel = {}
    table.insert(rel, Llevar(r))
    if #(r.botin or {}) > 0 then table.insert(rel, { t = "botin", n = L"Ver todo el botín", titulo = r.n, objetos = r.botin }) end
    table.insert(lista, { n = r.n, ing = r.ing, min = r.nivel, max = r.nivel, lado = r.elite and L"élite" or "raro", desc = r.desc, puntos = puntos,
      rel = rel, fuente = "Wowhead", comprobado = r.comprobado, primero = (r.zona == zona) })
  end
  table.sort(lista, function(a, b)   -- los de tu zona primero, luego por nivel
    if a.primero ~= b.primero then return a.primero end
    return (a.min or 0) < (b.min or 0)
  end)
  return lista
end

MODULOS.vendedores = function()
  local lista = {}
  for _, v in ipairs(WH("vendedores")) do
    table.insert(lista, { n = v.n, min = v.nivel, max = v.nivel, desc = v.desc, vendedor977 = v,
      dinamico = function(e)
        local actual, d, rep = LadoActual(), v, v.rep
        local compatible = not v.lado or actual == v.lado
        if v.id == 262766 then
          -- Mismos destinos y requisitos que Colección; no duplicar coordenadas.
          compatible = false
          for _, m in ipairs((WH("coleccion").monturas or {})) do
            if m.id == v.id then
              local origen = m.destinos977 and m.destinos977[actual]
              rep = m.repPorLado977 and m.repPorLado977[actual]
              if origen then
                d = { m=origen.m, x=origen.x, y=origen.y, zona=origen.zona,
                  vendedor=actual == "H" and "Okamache" or v.vendedor }
                compatible = true
              end
              break
            end
          end
        end
        local puntos, rel = {}, {}
        if compatible then
          puntos[#puntos+1] = L"Vendedor: " .. (d.vendedor or "?") .. (d.zona and (L", en " .. L(d.zona)) or "") .. (Coord(d) and (" · " .. Coord(d)) or "")
          local destino = Llevar(d, d.vendedor)
          if destino then destino.d.z = d.zona and L(d.zona); rel[#rel+1] = destino end
        else puntos[#puntos+1] = L"Vendedor de otra facción o facción sin confirmar." end
        if v.precio then puntos[#puntos+1] = L"Precio: " .. Dinero(v.precio) end
        if rep then
          puntos[#puntos+1] = L"Reputación: " .. L(rep.n or "?") .. L" en " .. L(rep.nivel or "?")
          if GL.EstadoRequisitoReputacion977 and GL.TextoEstadoReputacion977 then
            local estado, id = GL.EstadoRequisitoReputacion977(rep)
            puntos[#puntos+1] = GL.TextoEstadoReputacion977(estado)
            if id then rel[#rel+1] = { t="faccion", id=id, n=L"Ver en Reputación" } end
          end
        elseif v.id == 262766 then puntos[#puntos+1] = L"Exaltado con la organización comercial de tu facción; facción sin confirmar." end
        if v.limitado then puntos[#puntos+1] = L"Cantidad limitada: vuelve a salir con el tiempo" end
        e.puntos, e.rel = puntos, rel
      end, fuente = "Wowhead", comprobado = v.comprobado })
  end
  table.sort(lista, function(a, b) return (a.min or 0) < (b.min or 0) end)
  return lista
end

MODULOS.bolsas = function()
  local lista = {}
  for _, b in ipairs(WH("bolsas")) do if not GL.DeMiLado or GL.DeMiLado(b) then   -- 9.2: solo las de tu facción
    local puntos = { L"La da: " .. (b.quien and (b.quien .. " · ") or "") .. (b.d or "?") .. (b.zona and (L", en " .. b.zona) or "") .. (Coord(b) and (" · " .. Coord(b)) or "") }
    if b.huecos then table.insert(puntos, L"Bolsa de " .. b.huecos .. L" huecos") end
    if b.q and GL.MisionCompletada and GL.MisionCompletada(b.q) then table.insert(puntos, C.VERDE .. L"Ya la has hecho" .. C.FIN)
    elseif b.q and GL.MisionEnDiario and GL.MisionEnDiario(b.q) then table.insert(puntos, C.VERDE .. L"La llevas en el diario" .. C.FIN) end
    table.insert(lista, { n = b.n, min = b.nivel, max = b.nivel, desc = b.desc, puntos = puntos, rel = { Llevar(b, b.quien or b.d) },
      fuente = "Wowhead", comprobado = b.comprobado })
  end end
  table.sort(lista, function(a, b) return (a.min or 0) < (b.min or 0) end)
  return lista
end

MODULOS.entrenadores = function()
  local lista, sabe = {}, {}
  for _, h in ipairs((GL.Habilidades and GL.Habilidades()) or {}) do sabe[h.n] = true end
  for _, e in ipairs(WH("entrenadores")) do if not GL.DeMiLado or GL.DeMiLado(e) then
    local armas = {}
    for _, a in ipairs(e.armas or {}) do table.insert(armas, sabe[a] and (C.VERDE .. a .. C.FIN) or a) end
    local puntos = { (e.zona or "?") .. (Coord(e) and (" · " .. Coord(e)) or ""), L"Enseña: " .. table.concat(armas, ", ") }
    if e.precio then table.insert(puntos, L"Precio: " .. Dinero(e.precio) .. L" cada una") end
    table.insert(lista, { n = e.n, desc = e.desc, puntos = puntos, rel = { Llevar(e) }, fuente = "Wowhead", comprobado = e.comprobado })
  end end
  table.sort(lista, function(a, b) return a.n < b.n end)
  return lista
end

-- Raciales de Forever, contraste build 1.60.1.71139 (Zockify, Endgame Tools).
-- Los nombres españoles de referencia no se usan para identificar hechizos del cliente.
local function Racial(es, en, ids)
  local texto = GL.ingles and en or es
  -- Only use the client label when its locale matches the guide. For class
  -- variants require positive knowledge of the spell, never select arbitrarily.
  local locale = GetLocale and GetLocale()
  local mismo = (GL.ingles and (locale == "enUS" or locale == "enGB")) or
    (not GL.ingles and (locale == "esES" or locale == "esMX"))
  if mismo and ids and GL.NombreHechizo then
    local id = type(ids) == "number" and ids or nil
    if type(ids) == "table" and GL.HechizoConocido then
      for _, candidato in ipairs(ids) do
        if GL.HechizoConocido(candidato) then id = candidato; break end
      end
    end
    if id then
      local nombre = GL.NombreHechizo(id)
      local sufijo = texto:match("( — .+)$")
      if type(nombre) == "string" and nombre ~= "" and sufijo then return nombre .. sufijo end
    end
  end
  return texto
end
MODULOS.razas = function()
  return {
    { n = L"Humano", lado = L"Alianza", desc = L"Clases: cazador, mago, paladín, sacerdote, pícaro, brujo y guerrero.",
      puntos = { L"Empieza en el Bosque de Elwynn",
        Racial("Voluntad de supervivencia — elimina aturdimientos.", "Will to Survive — removes stuns.", 1259718),
        Racial("Percepción — mejora la detección de sigilo.", "Perception — improves stealth detection.", 20600),
        Racial("Crueldad — +1 % de crítico.", "Ruthless — +1% critical chance.", 20597),
        Racial("Espíritu humano — +10 % de espíritu.", "The Human Spirit — +10% Spirit.", 20598) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
    { n = L"Enano", lado = L"Alianza", desc = L"Clases: cazador, paladín, sacerdote, pícaro, chamán y guerrero.",
      puntos = { L"Empieza en Dun Morogh",
        Racial("Petraforma — limpia sangrados, venenos y enfermedades; reduce daño físico.", "Stoneform — clears bleeds, poisons and diseases; reduces physical damage.", 20594),
        Racial("Buscar tesoro — rastreo de cofres y posibilidad de botín extra.", "Find Treasure — tracks chests and may yield extra loot.", 2481),
        Racial("Precisión artesanal — +1 % de golpe (nombre ES orientativo).", "Artisan's Precision — +1% hit.", 1259719),
        Racial("Caza mayor — +5 % de daño a bestias.", "Big Game Hunter — +5% damage against beasts.", 1259721) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
    { n = L"Gnomo", lado = L"Alianza", desc = L"Clases: mago, sacerdote, pícaro, brujo y guerrero.",
      puntos = { L"Empieza en Dun Morogh",
        Racial("Artista del escape — elimina efectos que limitan el movimiento.", "Escape Artist — removes movement impairments.", 20589),
        Racial("¡Eureka! — mejora el daño no periódico y reduce su coste durante 8 s.", "Eureka! — improves non-periodic damage and reduces its cost for 8 sec.", {1259812, 1259813, 1259817, 1259821, 1259823}),
        Racial("Mente expansiva — aumenta el recurso máximo según la clase.", "Expansive Mind — increases the maximum class resource.", {20591, 1259802, 1259803}),
        Racial("Especialización en ingeniería — reduce fallos de dispositivos.", "Engineering Specialization — reduces device failures.", 20593) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
    { n = L"Elfo de la noche", lado = L"Alianza", desc = L"Clases: druida, cazador, sacerdote, pícaro y guerrero.",
      puntos = { L"Empieza en Teldrassil",
        Racial("Fusión de las sombras — oculta al personaje; en combate puede desviar la atención enemiga.", "Shadowmeld — conceals you; in combat may divert enemy attention.", 20580),
        Racial("Luz de Elune — +10 % de crítico durante 15 s.", "Elune's Light — +10% critical chance for 15 sec.", 1259799),
        Racial("Prontitud — +1 % de esquivar y +2 % de velocidad de movimiento.", "Quickness — +1% dodge and +2% movement speed.", 20582),
        Racial("Espíritu de fuego fatuo — +75 % de velocidad al morir.", "Wisp Spirit — +75% movement speed after death.", 20585) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
    -- 8.5: razas de la Horda. Combinaciones de Forever (method.gg): orco mago, trol brujo y no-muerto paladín son nuevas.
    { n = L"Orco", lado = L"Horda", desc = L"Clases: cazador, mago (nuevo en Forever), pícaro, chamán, brujo y guerrero.",
      puntos = { L"Empieza en el Valle de los Retos (Durotar)",
        Racial("Furia sangrienta — aumenta poder de ataque y de hechizos.", "Blood Fury — increases attack and spell power.", 20572),
        Racial("Trizar maldición — disipa maldiciones y reduce daño mágico.", "Shatter Curse — removes curses and banes and reduces magic damage.", 1299026),
        Racial("Firmeza — reduce la duración de aturdimientos un 20 %.", "Hardiness — reduces stun duration by 20%.", 20573),
        Racial("Comandar — +5 % de daño de mascotas de cazador y brujo.", "Command — +5% Hunter and Warlock pet damage.", {20575, 20576}) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
    { n = L"No-muerto", lado = L"Horda", desc = L"Clases: mago, paladín (nuevo en Forever), sacerdote, pícaro, brujo y guerrero.",
      puntos = { L"Empieza en Camposanto (Claros de Tirisfal)",
        Racial("Voluntad de los Renegados — elimina miedo, sueño y encantamiento.", "Will of the Forsaken — removes fear, sleep and charm.", 7744),
        Racial("Canibalizar — recupera salud y maná de cadáveres válidos.", "Cannibalize — restores health and mana from eligible corpses.", 20577),
        Racial("Toque de la tumba — posibilidad de drenar salud al atacar.", "Touch of the Grave — chance to drain health when attacking.", {1260189, 1260201}),
        Racial("Respiración subacuática — dura más bajo el agua.", "Underwater Breathing — extends underwater breath.", 5227) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
    { n = "Tauren", lado = L"Horda", desc = L"Clases: druida, cazador, chamán y guerrero.",
      puntos = { L"Empieza en el Campamento Narache (Mulgore)",
        Racial("Pisotón de guerra — aturde enemigos cercanos.", "War Stomp — stuns nearby enemies.", 20549),
        Racial("Cultivo — duplica una hierba cercana.", "Cultivation — duplicates a nearby herb.", 20552),
        Racial("Carrera por las llanuras — acelera al desplazarse a pie (nombre ES orientativo).", "Plainsrunning — builds movement speed on foot.", 1259918),
        Racial("Aguante — +5 % de salud máxima.", "Endurance — +5% maximum health.", 20550) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
    { n = L"Trol", lado = L"Horda", desc = L"Clases: cazador, mago, sacerdote, pícaro, chamán, brujo (nuevo en Forever) y guerrero.",
      puntos = { L"Empieza en el Valle de los Retos (Durotar)",
        Racial("Iracundia — aumenta velocidad de ataque y lanzamiento.", "Berserking — increases attack and casting speed.", 20554),
        Racial("Regeneración rápida — recupera salud si no te interrumpen.", "Rapid Regeneration — restores health while uninterrupted.", 1260270),
        Racial("Matanza de bestias — +5 % de daño contra bestias.", "Beast Slaying — +5% damage against beasts.", 20557),
        Racial("Regeneración — mejora la recuperación de salud, incluso en combate.", "Regeneration — improves health recovery, including in combat.", 20555) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
    { n = "Skyborne", lado = L"Alianza (High Order) y Horda (Windshapers)", desc = L"Raza nueva de Forever. Clases: druida, cazador, pícaro y guerrero en las dos facciones; mago solo en la Alianza y chamán solo en la Horda. 8.6: rutas de la Horda para las cinco clases.",
      puntos = { L"Empieza en la Isla Zephras; la Horda sale en nave celeste a Mulgore",
        Racial("Caminar sobre el aire — planeo durante 10 s.", "Walk on Air — glide for 10 sec.", 1259416),
        Racial("Leer línea Ley (Alianza) — mejora la regeneración; una línea Ley potencia el efecto.", "Read Leyline (Alliance) — boosts regeneration; a leyline strengthens the effect.", 1259705),
        Racial("Visión cielonata (Horda) — mejora el desplazamiento; una convergencia potencia el efecto.", "Skysight (Horde) — boosts travel speed; a convergence strengthens the effect.", 1259686),
        Racial("Bendición del viento — +2 % de celeridad.", "Wind Blessed — +2% haste.", 1259710),
        Racial("Perspicacia elemental — +5 % de daño contra elementales.", "Elemental Insight — +5% damage against elementals.", 1259707) }, fuente = Racial("Forever 71139; nombres ES de referencia, pendientes del cliente", "Forever 71139; reference ES names pending client verification") },
  }
end
-- Profesiones: 7.6, tramos 1-300 de las guías de profesiones de Wowhead (Forever), en DatosWowhead.lua.
-- El tramo en el que estás va resaltado y cuenta lo que llevas en las bolsas y el banco (se recalcula al refrescar).
local function ActualizarProfesion(e)
  local p = e.prof
  local rango, tope
  if GL.NivelProfesion then
    local ok, r, t = pcall(GL.NivelProfesion, { nombre = p.n, skill = p.skill })
    if ok then rango, tope = r, t end
  end
  -- 7.6.2: también los otros personajes de la cuenta que la tienen (guardados en Cuenta)
  local otros = (GL.ProfesionEnCuenta and GL.ProfesionEnCuenta(p.n, p.skill)) or {}
  local alters = {}
  for i = 1, math.min(#otros, 4) do table.insert(alters, otros[i].n .. " " .. otros[i].r) end
  local txtAlters = #alters > 0 and table.concat(alters, ", ") or nil
  e.region = (rango and (rango .. " / " .. (tope or 300)) or L"no la tienes") .. (txtAlters and ("  ·  " .. txtAlters) or "")
  e.desc = (rango and (L"Tienes " .. rango .. L" de " .. (tope or 300) .. ".") or L"No tienes esta profesión.") ..
    (txtAlters and (L"\nOtros personajes: " .. C.BLANCO .. txtAlters .. C.FIN .. ".") or "")
  if not rango and otros[1] then rango, e.deOtro = otros[1].r, otros[1].n else e.deOtro = nil end
  if e.deOtro then e.desc = e.desc .. "\n" .. C.GRIS .. L"Los tramos van marcados para " .. e.deOtro .. L"; los materiales cuentan los de este personaje." .. C.FIN end
  local l = {}
  -- 8.7: con la Horda, sus instructores y vendedores (DatosWowhead.lua, profesionesHorda)
  local PH = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and WH("profesionesHorda") or nil
  for _, t in ipairs(p.tramos or {}) do
    local hecho = rango and rango >= t.h
    local ahora = rango and rango >= t.d and rango < t.h
    local texto = t.d .. "-" .. t.h .. "  " .. t.r .. (t.c and (" ×" .. t.c) or "") .. (t.zonas and (" · " .. t.zonas) or "")
    if hecho then texto = C.VERDE .. "+ " .. texto .. C.FIN
    elseif ahora then texto = C.AMARILLO .. "> " .. texto .. C.FIN
    else texto = C.GRIS .. texto .. C.FIN end
    table.insert(l, texto)
    if ahora then
      local de = GL.OrigenProfesion975 and GL.OrigenProfesion975(t, PH and "Horde" or "Alliance") or (t.de and ((PH and PH.de and PH.de[t.de]) or t.de))
      if de then table.insert(l, "     " .. C.GRIS .. L"Receta: " .. de .. C.FIN) end
      local requisitos = GL.RequisitosFabricacion975 and GL.RequisitosFabricacion975(t.sp)
      if requisitos then table.insert(l, "     " .. C.GRIS .. requisitos .. C.FIN) end
      local falta, incierto, sinCantidad = {}, false, false
      if t.mat and #t.mat > 0 then table.insert(l, "     " .. L"Materiales en bolsas.") end
      for _, m in ipairs(t.mat or {}) do
        local tienes = GL.BolsasProfesion975 and GL.BolsasProfesion975(m[1])
        local necesario = GL.MaterialBiblioteca975(t, m, rango)
        if type(necesario) == "number" and necesario > 0 then
          if tienes == nil then incierto = true
          elseif tienes < necesario then table.insert(falta, L(m[3]) .. " " .. C.AMARILLO .. tienes .. C.FIN .. " / " .. necesario) end
        else sinCantidad = true end
      end
      if sinCantidad then table.insert(l, "     " .. L"Cantidad necesaria sin confirmar.") end
      if incierto then table.insert(l, "     " .. L"Inventario no disponible para algunos materiales.") end
      if #falta > 0 then
        table.insert(l, L"     Te falta para el tramo:")
        for _, x in ipairs(falta) do table.insert(l, "       " .. x) end
      elseif not incierto and not sinCantidad and t.mat and #t.mat > 0 then
        table.insert(l, "     " .. C.VERDE .. L"Tienes los reactivos cuantificados del tramo; comprueba receta, herramientas y estación." .. C.FIN)
      end
    end
  end
  local nota = (GL.NotaProfesion975 and GL.NotaProfesion975(p, PH and "Horde" or "Alliance")) or (PH and PH.nota and PH.nota[p.n]) or p.nota
  if nota then table.insert(l, C.GRIS .. nota .. C.FIN) end
  if GL.AyudaPlan975 then table.insert(l, GL.AyudaPlan975(p.skill, "referencia")) end
  if e.rel and #e.rel > 0 then l[#l+1] = L"Facciones relacionadas: recetas adicionales; consulta su disponibilidad y rango. No son requisitos del tramo." end
  e.puntos = l
end

MODULOS.profesiones = function()
  local lista = {}
  local relacionadas = { [197]={59,92,609}, [171]={93}, [164]={59,93}, [333]={576,92}, [202]={93}, [165]={59,92,609} }
  local fichas = GL.DatosReputacion and GL.DatosReputacion() or {}
  for _, p in ipairs(WH("profesiones")) do
    local rel = {}
    for _, id in ipairs(relacionadas[p.skill] or {}) do
      local f = fichas[id]
      if f then rel[#rel+1] = { t="faccion", id=id, n=f.n } end
    end
    table.insert(lista, { n = p.n, prof = p, dinamico = ActualizarProfesion, rel=rel,
      fuente = p.fuente or L"guía de profesiones de Wowhead" })
  end
  return lista
end

local CATEGORIAS = { { "zonas", L"Zonas" }, { "facciones", L"Facciones" }, { "mazmorras", L"Mazmorras" },
  { "razas", L"Razas y clases" }, { "profesiones", L"Profesiones" },
  { "raros", L"Raros y élites" }, { "vendedores", L"Vendedores" }, { "bolsas", L"Bolsas" }, { "entrenadores", L"Entrenadores" } }
local BAJA = 48   -- 7.5.16: segunda fila de categorías; 7.6.1: tres filas de tres, repartidas en el ancho

local function Entradas(clave)
  if not cargadas[clave] then
    local ok, lista = pcall(MODULOS[clave])
    cargadas[clave] = (ok and type(lista) == "table") and lista or {}
  end
  return cargadas[clave]
end

-- Búsqueda literal tolerante a tildes, mayúsculas y espacios repetidos.
local tildes = { ["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u", ["ü"]="u", ["ñ"]="n",
  ["Á"]="a", ["É"]="e", ["Í"]="i", ["Ó"]="o", ["Ú"]="u", ["Ü"]="u", ["Ñ"]="n" }
local function NormalizarBusqueda(t)
  t = tostring(t or ""):lower()
  for a, b in pairs(tildes) do t = t:gsub(a, b) end
  return (t:gsub("%s+", " "):match("^%s*(.-)%s*$"))
end
GL.NormalizarBusqueda97 = NormalizarBusqueda
local function Puntuacion(nombre, b)
  local n = NormalizarBusqueda(nombre)
  if n == b then return 1 end
  if n:find(b, 1, true) == 1 then return 2 end
  if n:find(b, 1, true) then return 3 end
end
GL.PuntuacionBusqueda97 = Puntuacion

-- Conserva el orden original dentro de cada grupo de relevancia.
local function Lista()
  local b = NormalizarBusqueda(busqueda)
  if b == "" then return Entradas(cat) end
  local grupos = {{}, {}, {}}
  for i = 1, #CATEGORIAS do
    local lista = Entradas(CATEGORIAS[i][1])
    for k = 1, #lista do
      local e = lista[k]
      local p, q = Puntuacion(e.n, b), e.ing and Puntuacion(e.ing, b)
      local rango = p and q and math.min(p, q) or p or q
      if rango then table.insert(grupos[rango], e) end
    end
  end
  local r = {}
  for _, grupo in ipairs(grupos) do
    for _, e in ipairs(grupo) do r[#r+1] = e end
  end
  return r
end

local function ColorNivel(e)
  if not e.min then return C.GRIS end
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  local d = math.floor((e.min + e.max) / 2) - nivel
  if d >= 5 then return "|cffff4040" elseif d >= 3 then return "|cffff8040" elseif d >= -2 then return "|cffffd100"
  elseif d >= -8 then return "|cff40c040" end
  return "|cff9d9d9d"
end

local function AbrirRelacionado(r)
  if r.t == "mazmorra" and GL.AbrirMazmorra then GL.AbrirMazmorra(r.n)
  elseif r.t == "faccion" and GL.AbrirFaccion then GL.AbrirFaccion(r.id)
  elseif r.t == "destino" and r.d and GL.SeguirDesvio then GL.SeguirDesvio(r.d)
  elseif r.t == "botin" and GL.VerBotin then GL.VerBotin(r.titulo, r.objetos) end   -- 7.5.16
end

------------------------------------------------------------------------
-- Refrescar
------------------------------------------------------------------------
local function Ficha(e)
  if e.dinamico then pcall(e.dinamico, e) end   -- 7.6: profesiones
  ui.fichaTitulo:SetText(string.upper(e.n))
  local cab = {}
  if e.min then table.insert(cab, (e.min == e.max) and (L"nivel " .. e.min) or (L"niveles " .. e.min .. "-" .. e.max)) end
  if e.lado then table.insert(cab, e.lado) end
  ui.fichaCab:SetText(table.concat(cab, " · "))
  local l = {}
  if e.desc then table.insert(l, e.desc) end
  if e.puntos and #e.puntos > 0 then
    table.insert(l, " ")
    table.insert(l, C.AMARILLO .. (cat == "zonas" and busqueda == "" and L"Puntos de interés" or (cat == "profesiones" and busqueda == "") and L"Tramos" or L"Datos") .. C.FIN)
    for i = 1, #e.puntos do table.insert(l, "• " .. e.puntos[i]) end
  end
  if e.rel and #e.rel > 0 then
    table.insert(l, " ")
    table.insert(l, C.AMARILLO .. L"Relacionado" .. C.FIN)
  end
  ui.actualizarTexto(table.concat(l, "\n"), e)
  for i = 1, #ui.rel do
    local r = e.rel and e.rel[i]
    ui.rel[i].dato = r
    if r then ui.rel[i].texto:SetText(r.texto or r.n) end
    GL.Mostrar(ui.rel[i], r ~= nil)
  end
  ui.fichaFuente:SetText(C.GRIS .. L"Fuente: " .. (e.fuente or "?") .. (e.comprobado and L" · comprobado con QuestieDB" or "") .. C.FIN)
  ui.ficha:Show()
end

local function Refrescar()
  if not panel or not panel:IsShown() then return end
  if ui.ColocarCategorias then ui.ColocarCategorias() end
  for i = 1, #ui.cats do ui.cats[i]:SetActivo(busqueda == "" and ui.cats[i].clave == cat) end
  local lista = Lista()
  desde = math.max(0, math.min(desde, #lista - FILAS))
  local elegida = nil
  for i = 1, #lista do if lista[i] == sel then elegida = sel end end
  if not elegida then elegida = lista[1]; sel = elegida end
  local titulo = busqueda ~= "" and (L"Resultados de «" .. busqueda .. "»") or nil
  for i = 1, #CATEGORIAS do if not titulo and CATEGORIAS[i][1] == cat then titulo = CATEGORIAS[i][2] end end
  ui.titulo:SetText(titulo)
  for i = 1, FILAS do
    local fila, e = ui.filas[i], lista[desde + i]
    fila.entrada = e
    if e and e.dinamico then pcall(e.dinamico, e) end
    if e then
      fila.nombre:SetText(e.n .. (e.region and (C.GRIS .. "  " .. e.region .. C.FIN) or ""))
      fila.ayudaTitulo, fila.ayudaTexto = e.n, e.region
      fila.nivel:SetText(e.min and (ColorNivel(e) .. e.min .. (e.min ~= e.max and ("-" .. e.max) or "") .. C.FIN) or "")
      GL.Mostrar(fila.marca, e == elegida)
      fila:Show()
    else
      fila.ayudaTitulo, fila.ayudaTexto = nil, nil
      fila:Hide()
    end
  end
  if #lista == 0 then
    ui.mas:SetText(C.GRIS .. (busqueda ~= "" and L"No hay nada con ese nombre." or L"No hay nada en esta categoría.") .. C.FIN)
  elseif #lista > FILAS then
    ui.mas:SetText(C.GRIS .. (desde + 1) .. "-" .. math.min(#lista, desde + FILAS) .. L" de " .. #lista .. L" (rueda del ratón)" .. C.FIN)
  else
    ui.mas:SetText("")
  end
  if elegida then Ficha(elegida) else ui.ficha:Hide() end
end

------------------------------------------------------------------------
-- Crear
------------------------------------------------------------------------
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)   -- sin pestañas: empieza bajo la cabecera
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()

  -- categorías
  for i = 1, #CATEGORIAS do
    local clave = CATEGORIAS[i][1]
    local b = GL.CrearBoton(panel, CATEGORIAS[i][2], function()
      cat, desde, sel, busqueda = clave, 0, nil, ""
      if ui.buscar then ui.buscar:SetText(""); ui.buscar:ClearFocus() end
      Refrescar()
    end, nil, 20)
    local anchos = { razas = 92, raros = 92, vendedores = 78, entrenadores = 136 }
    b:SetWidth(anchos[clave] or 70)
    b.clave = clave
    ui.cats[i] = b
  end
  local function ColocarCategorias()   -- 7.6.1: 3 por fila, mismo ancho, siempre dentro del panel
    local w = math.floor((((panel:GetWidth() or 0) > 0 and panel:GetWidth() or 402) - 8) / 3)
    for i = 1, #ui.cats do
      local b = ui.cats[i]
      b:ClearAllPoints()
      b:SetWidth(w)
      b:SetPoint("TOPLEFT", panel, "TOPLEFT", ((i - 1) % 3) * (w + 4), -math.floor((i - 1) / 3) * 24)
    end
    local wr = math.floor((((panel:GetWidth() or 0) > 0 and panel:GetWidth() or 402) - 24 - 8) / 3)
    for i = 1, #ui.rel do ui.rel[i]:SetWidth(wr) end
  end
  ui.ColocarCategorias = ColocarCategorias

  -- buscador
  local caja = CreateFrame("EditBox", nil, panel, PLANTILLA)
  caja:SetHeight(20)
  caja:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -26 - BAJA)
  caja:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -26 - BAJA)
  caja:SetAutoFocus(false)
  caja:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  caja:SetTextInsets(6, 6, 0, 0)
  if GL.Caja and GL.COLOR then GL.Caja(caja, { 0, 0, 0, 0.4 }, GL.COLOR.botonBorde) end
  local pista = GL.Texto(caja, "GameFontDisableSmall")
  pista:SetPoint("LEFT", caja, "LEFT", 6, 0)
  pista:SetText(L"Buscar en la biblioteca...")
  caja:SetScript("OnTextChanged", function(self)
    busqueda = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    GL.Mostrar(pista, busqueda == "" and not self:HasFocus())
    desde, sel = 0, nil
    Refrescar()
  end)
  caja:SetScript("OnEditFocusGained", function() pista:Hide() end)
  caja:SetScript("OnEditFocusLost", function() GL.Mostrar(pista, busqueda == "") end)
  caja:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  caja:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  ui.buscar = caja

  ui.titulo = GL.Texto(panel, "GameFontNormal")
  ui.titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -54 - BAJA)
  ui.titulo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -54 - BAJA); GL.UnaLinea(ui.titulo)   -- 7.6.1: dentro del marco

  for i = 1, FILAS do
    local f = CreateFrame("Button", nil, panel)
    f:SetHeight(ALTO_FILA)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -72 - BAJA - (i - 1) * ALTO_FILA)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -72 - BAJA - (i - 1) * ALTO_FILA)
    f.marca = f:CreateTexture(nil, "BACKGROUND")
    f.marca:SetAllPoints()
    f.marca:SetColorTexture(1, 0.82, 0, 0.12)
    f.marca:Hide()
    local brillo = f:CreateTexture(nil, "HIGHLIGHT")
    brillo:SetAllPoints()
    brillo:SetColorTexture(1, 1, 1, 0.06)
    f.nivel = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.nivel:SetPoint("RIGHT", f, "RIGHT", -2, 0)
    f.nivel:SetWidth(50)
    f.nombre = GL.Texto(f, "GameFontHighlightSmall")
    f.nombre:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.nombre:SetPoint("RIGHT", f.nivel, "LEFT", -4, 0)
    GL.UnaLinea(f.nombre)
    if GL.Ayuda then GL.Ayuda(f) end
    f:SetScript("OnClick", function(self)
      if self.entrada then sel = self.entrada; Refrescar() end
    end)
    ui.filas[i] = f
  end
  ui.mas = GL.Texto(panel, "GameFontHighlightSmall")
  ui.mas:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -74 - BAJA - FILAS * ALTO_FILA)
  ui.mas:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -74 - BAJA - FILAS * ALTO_FILA); GL.UnaLinea(ui.mas)   -- 7.6.1: dentro del marco

  -- ficha
  local ficha = CreateFrame("Frame", nil, panel, PLANTILLA)
  ficha:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -92 - BAJA - FILAS * ALTO_FILA)
  ficha:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
  if GL.Caja and GL.COLOR then GL.Caja(ficha, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  local borde = ficha:CreateTexture(nil, "ARTWORK")
  borde:SetWidth(3)
  borde:SetPoint("TOPLEFT", ficha, "TOPLEFT", 0, 0)
  borde:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 0, 0)
  borde:SetColorTexture(1, 0.78, 0.25, 1)
  ui.ficha = ficha
  ui.fichaTitulo = GL.Texto(ficha, "GameFontNormalSmall")
  ui.fichaTitulo:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -8)
  ui.fichaTitulo:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -8)
  ui.fichaTitulo:SetHeight(28)
  if ui.fichaTitulo.SetWordWrap then ui.fichaTitulo:SetWordWrap(true) end
  if ui.fichaTitulo.SetMaxLines then ui.fichaTitulo:SetMaxLines(2) end
  ui.fichaCab = GL.Texto(ficha, "GameFontNormalSmall", "RIGHT")
  ui.fichaCab:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -38)
  ui.fichaCab:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -38)
  GL.UnaLinea(ui.fichaCab)
  if GL.CrearTextoDesplazableR10 then
    ui.fichaTexto, ui.actualizarTexto = GL.CrearTextoDesplazableR10(ficha, 55, 46)
  else
    ui.fichaTexto = GL.Texto(ficha, "GameFontHighlightSmall")
    ui.fichaTexto:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -55)
    ui.fichaTexto:SetPoint("BOTTOMRIGHT", ficha, "BOTTOMRIGHT", -8, 46)
    ui.actualizarTexto = function(t) ui.fichaTexto:SetText(t) end
  end
  ui.fichaFuente = GL.Texto(ficha, "GameFontHighlightSmall")
  ui.fichaFuente:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 12, 6)
  ui.fichaFuente:SetPoint("BOTTOMRIGHT", ficha, "BOTTOMRIGHT", -8, 6); GL.UnaLinea(ui.fichaFuente)   -- 7.6.1: dentro del marco
  for i = 1, 3 do
    local b = GL.CrearBoton(ficha, "", function(self) end, nil, 18)
    b:SetScript("OnClick", function(self) if self.dato then AbrirRelacionado(self.dato) end end)
    b:SetWidth(122)
    if i == 1 then b:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 12, 22) else b:SetPoint("LEFT", ui.rel[i - 1], "RIGHT", 4, 0) end
    b:Hide()
    ui.rel[i] = b
  end
  ColocarCategorias()

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    desde = math.max(0, desde - delta)
    Refrescar()
  end)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt)
    if not panel:IsShown() then return end
    espera = espera + dt
    if espera >= CADA then espera = 0; Refrescar() end
  end)
  GL.modos.biblioteca = { panel = panel, refrescar = Refrescar }
end

-- 9.0: se crea al abrirla por primera vez (Ajustes › General › Cargar cada sección al abrirla)
GL.perezosos = GL.perezosos or {}
GL.perezosos.biblioteca = CrearPanel
table.insert(GL.alIniciar, function() if type(GuiaAventureroDB) == "table" and GuiaAventureroDB.cargarAlAbrir == false then CrearPanel() end end)

-- Para las pruebas
GL._fichasBiblioteca977 = function(c)
  local lista = MODULOS[c] and MODULOS[c]() or {}
  for _, e in ipairs(lista) do if e.dinamico then e.dinamico(e) end end
  return lista
end
GL._biblioteca = function(c, b, recargar) if recargar then cargadas = {} end; cat, busqueda, sel, desde = c or cat, b or "", nil, 0; Refrescar(); return #Lista() end

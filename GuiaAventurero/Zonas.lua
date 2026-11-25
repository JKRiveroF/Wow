-- Zonas.lua (9.1): zona de misión sombreada en el mapa del mundo y en el minimapa para cada objetivo del paso.
-- Las rutas no traen el contorno de cada zona: se calcula con los puntos de objetivo (C) de cada misión del paso.
-- Con un punto, un círculo alrededor; con varios, el círculo que los cubre a todos con un margen.
-- Cada misión lleva su color (el del acento la del destino de la flecha). Se apaga en Ajustes › Flecha.
-- También dibuja en el mapa la ruta de recolección que sigas (Recoleccion.lua).
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local CIRCULO = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- círculo blanco con el borde suave
local RADIO_MIN, MARGEN = 3.5, 2.0   -- en % del mapa
local COLORES = { { 1, 0.82, 0.2 }, { 0.41, 0.80, 0.94 }, { 0.25, 0.85, 0.35 }, { 1, 0.45, 0.35 }, { 0.80, 0.55, 1 } }

local function DB() return GuiaAventureroDB or {} end
local function Activo() return DB().zonasMision ~= false end

-- Zonas del paso: { m, x, y, r (en %), q, n, actual }
local function ZonasDelPaso()
  local res = {}
  if not GL.PasoActual then return res end
  local _, p = GL.PasoActual()
  if not p or not p.wp then return res end
  local actual = GL.DestinoActual and GL.DestinoActual()
  local por = {}
  for _, d in ipairs(p.wp) do
    if d.a == "C" and d.m and d.x and d.y and GL.DestinoHecho(d) ~= true then
      local clave = tostring(d.q or d.n) .. "@" .. d.m
      local g = por[clave]
      if not g then g = { m = d.m, q = d.q, n = d.n, puntos = {} }; por[clave] = g; table.insert(res, g) end
      table.insert(g.puntos, d)
      if d == actual then g.actual = true end
    end
  end
  for _, g in ipairs(res) do
    local sx, sy = 0, 0
    for _, d in ipairs(g.puntos) do sx, sy = sx + d.x, sy + d.y end
    g.x, g.y = sx / #g.puntos, sy / #g.puntos
    local r = 0
    for _, d in ipairs(g.puntos) do r = math.max(r, math.sqrt((d.x - g.x) ^ 2 + (d.y - g.y) ^ 2)) end
    g.r = math.max(RADIO_MIN, r + MARGEN)
    g.puntos = nil
  end
  return res
end
GL.ZonasDelPaso = ZonasDelPaso

local function ColorDe(i, g)
  if g.actual then local a = GL.COLOR.acento; return a[1], a[2], a[3] end
  local c = COLORES[(i - 1) % #COLORES + 1]
  return c[1], c[2], c[3]
end

------------------------------------------------------------------------
-- Mapa del mundo
------------------------------------------------------------------------
local capa, manchas, puntosRec = nil, {}, {}
local function Mancha(i)
  local t = manchas[i]
  if t then return t end
  t = { fondo = capa:CreateTexture(nil, "BACKGROUND"), borde = capa:CreateTexture(nil, "BORDER") }
  t.fondo:SetTexture(CIRCULO); t.borde:SetTexture(CIRCULO)
  if t.fondo.SetBlendMode then t.fondo:SetBlendMode("BLEND"); t.borde:SetBlendMode("ADD") end
  manchas[i] = t
  return t
end

local function PintarMapa()
  for _, t in ipairs(manchas) do t.fondo:Hide(); t.borde:Hide() end
  for _, t in ipairs(puntosRec) do t:Hide() end
  local mapa = WorldMapFrame
  if not mapa or not mapa.IsShown or not mapa:IsShown() or not (mapa.GetMapID and mapa.GetCanvas) then return end
  local idMapa, lienzo = mapa:GetMapID(), mapa:GetCanvas()
  if not idMapa or not lienzo then return end
  if not capa or capa:GetParent() ~= lienzo then
    capa = CreateFrame("Frame", nil, lienzo)
    capa:SetAllPoints(lienzo)
    manchas, puntosRec = {}, {}
  end
  capa:SetFrameLevel((lienzo:GetFrameLevel() or 1) + 1500)   -- encima de las teselas, debajo de los iconos (2000)
  capa:Show()
  local ancho, alto = lienzo:GetWidth(), lienzo:GetHeight()
  if Activo() then
    local n = 0
    for i, g in ipairs(ZonasDelPaso()) do
      if g.m == idMapa then
        n = n + 1
        local t = Mancha(n)
        local r, gr, b = ColorDe(i, g)
        local w = g.r / 100 * ancho * 2
        for _, tx in ipairs({ t.fondo, t.borde }) do
          tx:ClearAllPoints()
          tx:SetPoint("CENTER", lienzo, "TOPLEFT", g.x / 100 * ancho, -g.y / 100 * alto)
        end
        t.fondo:SetSize(w, w); t.fondo:SetVertexColor(r, gr, b, g.actual and 0.30 or 0.20); t.fondo:Show()
        t.borde:SetSize(w * 0.55, w * 0.55); t.borde:SetVertexColor(r, gr, b, 0.10); t.borde:Show()
      end
    end
  end
  -- ruta de recolección: un punto en cada parada, unidas en círculo
  local rec = GL.RutaRecoleccion and GL.RutaRecoleccion()
  if rec and rec.m == idMapa and rec.puntos then
    local escala = lienzo:GetScale() or 1
    if escala <= 0 then escala = 1 end
    local usados = 0
    local col = rec.color or { 0.25, 0.85, 0.35 }
    local np = #rec.puntos
    for i = 1, np do
      local a, b = rec.puntos[i], rec.puntos[i % np + 1]
      local x1, y1, x2, y2 = a[1] / 100 * ancho, -a[2] / 100 * alto, b[1] / 100 * ancho, -b[2] / 100 * alto
      local largo = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) * escala
      local cuantos = math.max(1, math.floor(largo / 10))
      for k = 0, cuantos - 1 do
        if usados >= 600 then break end
        usados = usados + 1
        local t = puntosRec[usados]
        if not t then t = capa:CreateTexture(nil, "OVERLAY"); t:SetTexture("Interface\\Buttons\\WHITE8X8"); puntosRec[usados] = t end
        local grande = (k == 0)
        local lado = (grande and 8 or 3) / escala
        t:SetSize(lado, lado)
        t:SetVertexColor(col[1], col[2], col[3], grande and 1 or 0.8)
        t:ClearAllPoints()
        local f = k / cuantos
        t:SetPoint("CENTER", lienzo, "TOPLEFT", x1 + (x2 - x1) * f, y1 + (y2 - y1) * f)
        t:Show()
      end
    end
  end
end
GL.PintarZonasMapa = PintarMapa

-- Se pinta a la vez que los iconos de los destinos (Mapa.lua llama siempre a GL.ActualizarPines)
if GL.ActualizarPines then
  local original = GL.ActualizarPines
  GL.ActualizarPines = function(...)
    original(...)
    local ok, err = pcall(PintarMapa)
    if not ok and GL.Fallo then GL.Fallo(L"zonas en el mapa", err) end
  end
end

------------------------------------------------------------------------
-- Minimapa
------------------------------------------------------------------------
local DIAMETRO = { [false] = { 466.67, 400, 333.33, 266.67, 200, 133.33 }, [true] = { 300, 240, 180, 120, 80, 50 } }
local mini, mascara = {}, nil
local function Finito(v)
  return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v == v and math.abs(v) < math.huge
end
local function AnchoZona(m)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local _, a = C_Map.GetWorldPosFromMapPos(m, CreateVector2D(0, 0.5))
  local _, b = C_Map.GetWorldPosFromMapPos(m, CreateVector2D(0.5, 0.5))
  if not a or not b then return nil end
  local x1, y1 = a:GetXY(); local x2, y2 = b:GetXY()
  if not (Finito(x1) and Finito(y1) and Finito(x2) and Finito(y2)) then return nil end
  local ancho = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) * 2
  return Finito(ancho) and ancho > 0 and ancho or nil
end
local anchos = {}

-- Reintentar una máscara no disponible, sin repetir la creación cada fotograma.
local intentosMascara = 0
local function PrepararMascara()
  if mascara or not Minimap.CreateMaskTexture then return end
  if intentosMascara > 0 then intentosMascara = intentosMascara - 1; return end
  intentosMascara = 24 -- aproximadamente cinco segundos entre intentos
  local ok, m = pcall(Minimap.CreateMaskTexture, Minimap)
  if not ok or not m then return end
  local lista = pcall(function()
    m:SetTexture(CIRCULO, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(Minimap)
  end)
  if not lista then return end
  mascara = m
  for _, t in ipairs(mini) do
    if t.AddMaskTexture then pcall(t.AddMaskTexture, t, mascara) end
  end
end

local function Mini(i)
  local t = mini[i]
  if t then return t end
  t = Minimap:CreateTexture(nil, "ARTWORK")
  t:SetTexture(CIRCULO)
  if mascara and t.AddMaskTexture then pcall(t.AddMaskTexture, t, mascara) end
  mini[i] = t
  return t
end

local function PintarMinimapa()
  for _, t in ipairs(mini) do t:Hide() end
  if not Activo() or not Minimap or not GL.Vector or DB().minimapaDestinos == false then return end
  local dentro = IsIndoors and IsIndoors() and true or false
  local zoom = (Minimap.GetZoom and Minimap:GetZoom()) or 0
  if not Finito(zoom) then return end
  local diam = DIAMETRO[dentro][zoom + 1] or 466.67
  local ancho = Minimap:GetWidth()
  if not Finito(ancho) or ancho <= 0 then return end
  local radio = ancho / 2
  local girar = GetCVar and GetCVar("rotateMinimap") == "1"
  local cara = 0
  if girar then
    if not GetPlayerFacing then return end
    cara = GetPlayerFacing()
    if not Finito(cara) then return end
  end
  PrepararMascara()
  local n = 0
  for i, g in ipairs(ZonasDelPaso()) do
    local este, sur = GL.Vector({ m = g.m, x = g.x, y = g.y })
    if Finito(este) and Finito(sur) then
      if anchos[g.m] == nil then
        local ok, anchoZona = pcall(AnchoZona, g.m)
        if ok and anchoZona then anchos[g.m] = anchoZona end
      end
      local yardas = (anchos[g.m] or 1500) * g.r / 100
      local x, y = este, -sur
      if girar and cara then
        local c, s = math.cos(cara), math.sin(cara)
        x, y = x * c + y * s, -x * s + y * c
      end
      local escala = radio / (diam / 2)
      local px, py, pr = x * escala, y * escala, yardas * escala
      local dist = math.sqrt(px * px + py * py)
      -- sin máscara, solo se pinta si la zona cabe dentro del minimapa
      if dist - pr < radio and (mascara or dist + pr <= radio) then
        n = n + 1
        local t = Mini(n)
        local r, gr, b = ColorDe(i, g)
        t:SetVertexColor(r, gr, b, g.actual and 0.32 or 0.22)
        t:SetSize(pr * 2, pr * 2)
        t:ClearAllPoints()
        t:SetPoint("CENTER", Minimap, "CENTER", px, py)
        t:Show()
      end
    end
  end
end

local reloj = 0
local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function(_, dt)
  reloj = reloj + (dt or 0)
  if reloj < 0.2 then return end
  reloj = 0
  local ok, err = pcall(PintarMinimapa)
  if not ok and GL.Fallo then GL.Fallo(L"zonas en el minimapa", err) end
end)

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "zonasMision", "Zonas de misión sombreadas",
  "En el mapa del mundo y en el minimapa, un círculo de color donde están los objetivos de cada misión del paso. El del destino de la flecha, en el color del acento.",
  function() return Activo() end, function(v) DB().zonasMision = v; if GL.ActualizarPines then pcall(GL.ActualizarPines) end end, pestana = "flecha" })

GL._zonas = { Zonas = ZonasDelPaso, Mapa = PintarMapa, Minimapa = PintarMinimapa }

-- SeccionMapa.lua (9.2): toda la sección en el mapa del mundo. Cada paso que tiene destino en el mapa que miras
-- sale como un círculo con su número, unido al siguiente por una línea: verde lo hecho, el color del tema el paso
-- actual y gris lo que falta. Al pasar el ratón: el paso, lo que tarda y su XP. Casilla «Sección entera» arriba a la
-- derecha del mapa, y también en Ajustes › Flecha.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local DISCO = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local VERDE, GRIS = { 0.29, 0.87, 0.5 }, { 0.42, 0.44, 0.52 }

local function DB() return GuiaAventureroDB or {} end
local function Activo() return DB().seccionMapa ~= false end

local capa, nodos, lineas, puntos = nil, {}, {}, {}

local function Nodo(i)
  local n = nodos[i]
  if n then return n end
  n = CreateFrame("Button", nil, capa)
  n:SetSize(20, 20)
  n.borde = n:CreateTexture(nil, "BACKGROUND")
  n.borde:SetAllPoints(); n.borde:SetTexture(DISCO); n.borde:SetVertexColor(0.05, 0.06, 0.09, 1)
  n.disco = n:CreateTexture(nil, "ARTWORK")
  n.disco:SetPoint("TOPLEFT", 2, -2); n.disco:SetPoint("BOTTOMRIGHT", -2, 2); n.disco:SetTexture(DISCO)
  n.num = n:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  n.num:SetPoint("CENTER", 0, 0)
  n:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.paso then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.i .. " · " .. (self.titulo or L"Paso"), 1, 1, 1)
    if self.tipo then GameTooltip:AddLine(self.tipo, 0.7, 0.7, 0.75) end
    if self.t then GameTooltip:AddLine(L"Unos " .. math.max(1, math.floor(self.t / 60 + 0.5)) .. L" min", 0.7, 0.7, 0.75) end
    if self.xp then GameTooltip:AddLine("+" .. self.xp .. " XP", 0.64, 0.45, 1) end
    if self.hecho then GameTooltip:AddLine(L"Hecho", 0.29, 0.87, 0.5) end
    GameTooltip:Show()
  end)
  n:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  nodos[i] = n
  return n
end

local function Linea(i)
  local l = lineas[i]
  if l then return l end
  if capa.CreateLine then l = capa:CreateLine(nil, "ARTWORK") end
  lineas[i] = l or false
  return l
end

local function Punto(i)
  local t = puntos[i]
  if t then return t end
  t = capa:CreateTexture(nil, "ARTWORK")
  t:SetTexture("Interface\\Buttons\\WHITE8X8")
  puntos[i] = t
  return t
end

local function Corto(t)
  t = tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%[(.-)%]", "«%1»")
  t = t:match("^(.-)[%.:;]%s") or t
  if #t > 60 then t = t:sub(1, 60) .. "…" end
  return t
end

local function Ocultar()
  -- pairs y no ipairs: las líneas empiezan en el índice 2 (la 1 no existe), y con ipairs no se ocultaba ninguna,
  -- así que las del mapa anterior seguían viéndose en todos los demás
  for _, n in pairs(nodos) do n:Hide() end
  for _, l in pairs(lineas) do if l then l:Hide() end end
  for _, t in pairs(puntos) do t:Hide() end
end

local function Dibujar()
  Ocultar()
  local mapa = WorldMapFrame
  if not Activo() or not GL.RUTA or not mapa or not mapa.GetMapID or not mapa.GetCanvas then return end
  local idMapa, lienzo = mapa:GetMapID(), mapa:GetCanvas()
  if type(lienzo) ~= "table" or not lienzo.GetWidth then return end
  local db = DB()
  local sec = GL.RUTA.secciones[db.seccion or 1]
  if not sec then return end
  if not capa or capa:GetParent() ~= lienzo then
    if capa then capa:Hide() end
    capa = CreateFrame("Frame", nil, lienzo)
    capa:SetAllPoints(lienzo)
    nodos, lineas, puntos = {}, {}, {}
  end
  capa:SetFrameLevel((lienzo:GetFrameLevel() or 1) + 1990)
  capa:Show()
  local ancho, alto = lienzo:GetWidth(), lienzo:GetHeight()
  local escala = (lienzo.GetScale and lienzo:GetScale()) or 1
  if not escala or escala <= 0 then escala = 1 end
  local ac = GL.COLOR.acento
  local cuenta = type(GuiaAventureroCuenta) == "table" and type(GuiaAventureroCuenta.pasos9) == "table" and GuiaAventureroCuenta.pasos9[GL.RUTA.id] or {}
  -- un punto por paso: su primer destino en este mapa
  local lista = {}
  for i, p in ipairs(sec.pasos) do
    for _, d in ipairs(p.wp or {}) do
      if d.m == idMapa and d.x and d.y then table.insert(lista, { i = i, p = p, x = d.x, y = d.y }); break end
    end
  end
  local nl, np = 0, 0
  for k, e in ipairs(lista) do
    local ok, est = pcall(GL.EstadoPaso, e.p)
    e.hecho = (ok and est == "hecho") or e.i < (db.paso or 1)
    e.color = (e.i == db.paso) and ac or (e.hecho and VERDE or GRIS)
    e.px, e.py = e.x / 100 * ancho, -e.y / 100 * alto
    local n = Nodo(k)
    n:ClearAllPoints()
    n:SetPoint("CENTER", lienzo, "TOPLEFT", e.px, e.py)
  end
  for k, e in ipairs(lista) do
    if k > 1 then
      local a = lista[k - 1]
      local col = (a.hecho and e.hecho) and VERDE or ((e.i <= (db.paso or 1)) and ac or GRIS)
      local l = Linea(k)
      if l then
        nl = nl + 1
        l:SetThickness(3 / escala)
        l:SetColorTexture(col[1], col[2], col[3], 0.85)
        -- 9.2: la línea va de un círculo a otro (sin desplazamientos), porque en el lienzo ampliado del mapa
        -- el juego no escala igual los desplazamientos de las líneas y salían corridas, fuera de su sitio
        l:ClearAllPoints()
        l:SetStartPoint("CENTER", Nodo(k - 1), 0, 0)
        l:SetEndPoint("CENTER", Nodo(k), 0, 0)
        l:Show()
      else
        -- sin líneas en este cliente: puntos cada pocos píxeles
        local largo = math.sqrt((e.px - a.px) ^ 2 + (e.py - a.py) ^ 2) * escala
        local cuantos = math.min(60, math.floor(largo / 8))
        for j = 1, cuantos - 1 do
          np = np + 1
          local t = Punto(np)
          t:SetSize(3 / escala, 3 / escala)
          t:SetVertexColor(col[1], col[2], col[3], 0.85)
          t:ClearAllPoints()
          t:SetPoint("CENTER", lienzo, "TOPLEFT", a.px + (e.px - a.px) * j / cuantos, a.py + (e.py - a.py) * j / cuantos)
          t:Show()
        end
      end
    end
  end
  for k, e in ipairs(lista) do
    local n = Nodo(k)
    local tam = ((e.i == db.paso) and 24 or 19) / escala
    n:SetSize(tam, tam)
    n:ClearAllPoints()
    n:SetPoint("CENTER", lienzo, "TOPLEFT", e.px, e.py)
    n.disco:SetVertexColor(e.color[1], e.color[2], e.color[3], 1)
    n.num:SetText(e.hecho and e.i ~= db.paso and "" or tostring(e.i))
    if n.num.SetScale then n.num:SetScale(1 / escala) end
    n.i, n.paso, n.titulo, n.hecho = e.i, e.p, Corto(e.p.t), e.hecho
    n.tipo = GL.TipoPaso and select(2, GL.TipoPaso(e.p)).n or nil
    n.t = GL.EstimarPaso and select(1, GL.EstimarPaso(db.seccion, e.i)) or nil
    local v = cuenta and cuenta[db.seccion .. ":" .. e.i]
    n.xp = type(v) == "table" and type(v.xp) == "number" and v.xp > 0 and v.xp or nil
    n:SetFrameLevel(capa:GetFrameLevel() + ((e.i == db.paso) and 3 or 1))
    n:Show()
  end
end
GL.DibujarSeccionMapa = Dibujar

-- Va con los pines del mapa (Mapa.lua y Zonas.lua)
local antes = GL.ActualizarPines
if antes then
  GL.ActualizarPines = function(...)
    -- aunque fallen los pines, se redibuja (y se oculta) la sección para el mapa nuevo
    local okAntes, errAntes = pcall(antes, ...)
    local ok, err = pcall(Dibujar)
    if not okAntes and GL.Fallo then GL.Fallo(L"pines del mapa", errAntes) end
    if not ok and GL.Fallo then GL.Fallo(L"sección en el mapa", err) end
  end
end

-- Casilla en el propio mapa
local casilla
local function Casilla()
  if casilla or not WorldMapFrame or not CreateFrame then return end
  local padre = WorldMapFrame.ScrollContainer or WorldMapFrame
  casilla = CreateFrame("CheckButton", "GuiaAventureroSeccionMapa", padre, "UICheckButtonTemplate")
  casilla:SetSize(22, 22)
  casilla:SetPoint("TOPRIGHT", padre, "TOPRIGHT", -110, -4)
  casilla:SetFrameLevel((padre:GetFrameLevel() or 1) + 2100)
  local t = casilla.text or casilla.Text or (casilla.GetName and _G[casilla:GetName() .. "Text"])
  if t and t.SetText then t:SetText(L"Sección entera"); casilla.etiqueta = t end
  casilla:SetScript("OnClick", function(self)
    DB().seccionMapa = self:GetChecked() and true or false
    pcall(GL.ActualizarPines)
  end)
  casilla:SetScript("OnShow", function(self) self:SetChecked(Activo()) end)
  casilla:SetChecked(Activo())
end
table.insert(GL.alIniciar, function() pcall(Casilla) end)

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "seccionMapa", "Sección entera en el mapa del mundo",
  "Todos los pasos de la sección numerados y unidos: verde lo hecho, tu color el actual y gris lo que falta.",
  function() return Activo() end, function(v) DB().seccionMapa = v; if casilla then casilla:SetChecked(v) end; pcall(GL.ActualizarPines) end, pestana = "flecha" })

GL._seccionMapa = { Dibujar = Dibujar, Nodos = function() return nodos end }

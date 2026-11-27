-- Guia9.lua (9.0): lo nuevo de la pestaña Guía con el estilo moderno.
--  · Línea de tiempo: el paso anterior (hecho y lo que tardaste) encima de la caja y los siguientes debajo,
--    cada uno con la XP que da y lo que tarda más o menos; al pasar el ratón, su recompensa.
--  · (9.4.2: quitado el minimapa de la caja del paso.)
--  · Avisos fuera de la ventana cuando está cerrada, compacta o en franja.
--  · Lista «Antes de salir»: comida, bebida, reactivos y munición que conviene llevar.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"

local function DB() return GuiaAventureroDB or {} end
local function Si(k) return DB()[k] ~= false end
local function Num(v)
  if GL.Seguro then v = GL.Seguro(v) end
  return type(v) == "number" and v == v and v >= 0 and v < math.huge and v or nil
end
local function Ahora() return (GetTime and GetTime()) or 0 end
local function Nivel() return Num(UnitLevel and UnitLevel("player")) or 1 end
local function Miles(n)
  return GL.FormatoMiles(n)
end
local function Duracion(seg)
  seg = math.floor((seg or 0) + 0.5)
  if seg < 60 then return "1 min" end
  local m = math.floor(seg / 60 + 0.5)
  if m < 60 then return m .. L" min" end
  return math.floor(m / 60) .. " h " .. (m % 60) .. L" min"
end

------------------------------------------------------------------------
-- Tiempo y XP de cada paso: se apuntan al pasar al siguiente y se guardan para toda la cuenta
-- (así una ruta que ya hiciste con otro personaje te dice cuánto tarda cada paso).
------------------------------------------------------------------------
local xpTotal, xpAntes, xpMaxAntes, nivelAntes = 0, nil, nil, nil
local function LeerXP()
  local xp, max, nv = Num(UnitXP and UnitXP("player")), Num(UnitXPMax and UnitXPMax("player")), Nivel()
  if not xp or not max then return end
  if xpAntes then
    if nv > (nivelAntes or nv) then xpTotal = xpTotal + (xpMaxAntes - xpAntes) + xp
    elseif xp > xpAntes then xpTotal = xpTotal + (xp - xpAntes) end
  end
  xpAntes, xpMaxAntes, nivelAntes = xp, max, nv
end

local function Almacen()
  local c = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.pasos9
  local id = GL.RUTA and GL.RUTA.id
  local t = type(c) == "table" and id and c[id]
  return type(t) == "table" and t or {}
end

local claveAnt, desde, xpDesde, rutaAnt, dbAnt = nil, nil, 0, nil, nil
local function MirarPaso()
  local db = DB()
  local ruta = GL.RUTA and GL.RUTA.id
  if type(ruta) ~= "string" or ruta == "" or type(db.seccion) ~= "number" or type(db.paso) ~= "number" then
    claveAnt, desde = nil, nil; return
  end
  if ruta ~= rutaAnt or db ~= dbAnt then claveAnt, desde = nil, nil; rutaAnt, dbAnt = ruta, db end
  local clave = db.seccion .. ":" .. db.paso
  if clave == claveAnt then return end
  if claveAnt and desde and GL.PasoDespues then
    local s, p = string.match(claveAnt, "^(%d+):(%d+)$")
    local ns, np = GL.PasoDespues(tonumber(s), tonumber(p))
    local dt = Ahora() - desde
    -- solo cuenta si avanzas al paso que sigue (saltar pasos o volver atrás no es lo que tarda un paso)
    if ns == db.seccion and np == db.paso and dt >= 10 and dt <= 3600 then
      if GL.GuardarTiempoPaso then GL.GuardarTiempoPaso(claveAnt, math.floor(dt), math.max(0, xpTotal - xpDesde))
      end
    end
  end
  claveAnt, desde, xpDesde = clave, Ahora(), xpTotal
end

local function Media()
  local t, n = 0, 0
  for _, v in pairs(Almacen()) do if type(v) == "table" and Num(v.t) and v.t > 0 and v.t <= 3600 then t, n = t + v.t, n + 1 end end
  if n < 3 then return nil end
  return t / n
end

-- XP que da un paso: las misiones que entregas y que ya llevas en el diario. Si no, lo que dio la última vez.
local function XPPaso(p, clave)
  local total, sabe = 0, false
  for _, d in ipairs((p and p.wp) or {}) do
    if d.a == "T" and d.q and GL.IndiceEnDiario and GL.XPDeMision then
      local idx = GL.IndiceEnDiario(d.q)
      if idx then
        local okX, v = pcall(GL.XPDeMision, d.q, idx)
        if okX and Num(v) and v > 0 then total = total + v; sabe = true end
      end
    end
  end
  if sabe then return total, true end
  local g = clave and Almacen()[clave]
  if type(g) == "table" and Num(g.xp) and g.xp > 0 then return g.xp, false end
  return nil
end

local function TiempoPaso(clave)
  -- 9.2: a tu ritmo (Tiempos.lua): lo tuyo, lo de la cuenta corregido, tu media del tipo de paso...
  local s_, p_ = string.match(clave or "", "^(%d+):(%d+)$")
  if s_ and GL.EstimarPaso then
    local ok, t, f = pcall(GL.EstimarPaso, tonumber(s_), tonumber(p_))
    if ok and Num(t) and f ~= "fijo" then return t, f == "tuyo" end
    if ok then return nil end
  end
  local g = Almacen()[clave]
  if type(g) == "table" and Num(g.t) and g.t > 0 and g.t <= 3600 then return g.t, true end
  local m = Media()
  if m then return m, false end
  return nil
end

-- Texto corto de un paso: la primera frase, sin los corchetes de misión y objeto.
local function Corto(p, max)
  local t = (p and p.t) or ""
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("%[(.-)%]", "«%1»"):gsub("<(.-)>", "%1")
  local frase = t:match("^(.-[%.:;])%s") or t
  frase = frase:gsub("[%.:;]$", "")
  max = max or 60
  if #frase > max then
    local corte = frase:sub(1, max):match("^(.*)%s") or frase:sub(1, max)
    frase = corte .. "…"
  end
  return frase
end

------------------------------------------------------------------------
-- Línea de tiempo
------------------------------------------------------------------------
local filas = {}
local function Fila(i, panel)
  local f = filas[i]
  if f then return f end
  f = CreateFrame("Button", nil, panel)
  f:SetHeight(18)
  f.icono = f:CreateTexture(nil, "ARTWORK")
  f.icono:SetWidth(12); f.icono:SetHeight(12)
  f.icono:SetPoint("LEFT", f, "LEFT", 2, 0)
  f.linea = f:CreateTexture(nil, "BACKGROUND")
  f.linea:SetWidth(1)
  f.linea:SetPoint("TOP", f.icono, "BOTTOM", 0, 0)
  f.linea:SetPoint("BOTTOM", f, "BOTTOM", 0, -2)
  f.linea:SetPoint("LEFT", f, "LEFT", 7, 0)
  f.linea:SetColorTexture(1, 1, 1, 0.12)
  f.der = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
  f.der:SetPoint("RIGHT", f, "RIGHT", -2, 0)
  f.texto = GL.Texto(f, "GameFontHighlightSmall")
  f.texto:SetPoint("LEFT", f.icono, "RIGHT", 7, 0)
  f.texto:SetPoint("RIGHT", f.der, "LEFT", -6, 0)
  if f.texto.SetWordWrap then f.texto:SetWordWrap(false) end
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.04)
  f:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.paso then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine((self.titulo or L"Paso") .. (self.tipo and (" · " .. self.tipo) or ""), 1, 1, 1)
    GameTooltip:AddLine(Corto(self.paso, 400), 0.8, 0.8, 0.85, true)
    if self.xp then GameTooltip:AddLine("+" .. Miles(self.xp) .. " XP" .. (self.xpSeguro and "" or L" (la última vez)"), 0.64, 0.45, 1) end
    if self.tiempo then GameTooltip:AddLine((self.hecho and L"Tardaste " or L"Unos ") .. Duracion(self.tiempo), 0.7, 0.7, 0.75) end
    local okR, lista = pcall(function() return GL.RecompensasPaso and GL.RecompensasPaso(self.paso) end)
    if okR and type(lista) == "table" then
      local okM, rec = pcall(function() return GL.RecompensaRecomendada and GL.RecompensaRecomendada(lista) end)
      rec = okM and rec or nil
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine((lista[1] and lista[1].elegir) and L"Recompensa (elige una):" or L"Recompensa:", 1, 0.82, 0)
      for i, r in ipairs(lista) do
        local nombre = (type(r.enlace) == "string" and r.enlace:match("%[(.-)%]")) or L"Objeto"
        if i == rec then GameTooltip:AddLine(GL.Icono("★", 64, 217, 89) .. " " .. nombre .. L"  (recomendada)", 0.25, 0.85, 0.35)
        else GameTooltip:AddLine("  " .. nombre, 0.85, 0.85, 0.85) end
      end
    end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  filas[i] = f
  return f
end

local function Cuantos()
  local n = DB().pasosLinea
  if n == nil then n = 2 end
  return tonumber(n) or 2
end

local function PasoAntes(s, p)
  local R = GL.RUTA
  if not R then return nil end
  if p > 1 then return s, p - 1 end
  if s > 1 and R.secciones[s - 1] then return s - 1, #R.secciones[s - 1].pasos end
  return nil
end

local function Pintar(f, panel, y, paso, clave, hecho, ancho)
  f.paso, f.hecho = paso, hecho
  local xp, seguro = XPPaso(paso, clave)
  local t, medido = TiempoPaso(clave)
  if hecho and not medido then t = nil end
  f.xp, f.xpSeguro, f.tiempo = xp, seguro, t
  local der = {}
  if hecho then table.insert(der, C.VERDE .. "hecho" .. C.FIN) end
  if xp and not hecho then table.insert(der, "|cffa48cff+" .. Miles(xp) .. " XP" .. C.FIN) end
  if t then table.insert(der, C.GRIS .. Duracion(t) .. C.FIN) end
  f.der:SetText(table.concat(der, C.GRIS .. " · " .. C.FIN))
  f.texto:SetText((hecho and C.GRIS or "|cffd0d2dc") .. Corto(paso, 70) .. C.FIN)
  if GL.TipoPaso and DB().iconosPaso ~= false then
    -- 9.2: icono del tipo de paso (aceptar, matar, entregar, vuelo, instructor, hogar o ir); gris si ya está hecho
    local _, ti = GL.TipoPaso(paso)
    f.icono:SetTexture(ti.icono)
    if f.icono.SetTexCoord then f.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if f.icono.SetDesaturated then f.icono:SetDesaturated(hecho and true or false) end
    f.icono:SetVertexColor(1, 1, 1, hecho and 0.5 or 1)
    f.tipo = ti.n
  elseif hecho then
    if f.icono.SetTexCoord then f.icono:SetTexCoord(0, 1, 0, 1) end
    f.icono:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); f.icono:SetVertexColor(1, 1, 1, 0.8)
  else
    if f.icono.SetTexCoord then f.icono:SetTexCoord(0, 1, 0, 1) end
    f.icono:SetTexture(BLANCO8)
    local a = GL.COLOR.acento
    f.icono:SetVertexColor(a[1], a[2], a[3], 0.35)
  end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  f:Show()
end

local function OcultarFilas(desde_)
  for i = desde_, #filas do filas[i]:Hide() end
end

-- Encima de la caja: el paso anterior. Devuelve el alto que ocupa.
function GL.LineaAntes(panel, y, ancho)
  OcultarFilas(1)
  do return 0 end   -- 9.4.2: sin el paso anterior encima de la caja (ya está hecho; no hace falta verlo)
  if Cuantos() <= 0 or not GL.RUTA then return 0 end
  local db = DB()
  local s, p = PasoAntes(db.seccion, db.paso)
  if not s then return 0 end
  local paso = GL.RUTA.secciones[s].pasos[p]
  if not paso then return 0 end
  local f = Fila(1, panel)
  f.titulo = L"Paso anterior"
  f.icono:SetSize(12, 12)
  Pintar(f, panel, y + 2, paso, s .. ":" .. p, true, ancho)
  f.linea:Show()
  return 22
end

-- 9.6: la Guía clara no usa la línea de tiempo: se oculta entera
function GL.OcultarLinea()
  OcultarFilas(1)
  if filas.cab then filas.cab:Hide() end
  if filas.resumen then filas.resumen:Hide() end
end

-- Debajo de los objetivos: los pasos que vienen y lo que queda de sección.
function GL.LineaDespues(panel, y, ancho)
  for i = 2, #filas do filas[i]:Hide() end
  local n = Cuantos()
  if n <= 0 or not GL.RUTA or not GL.PasoDespues then return 0 end
  local db = DB()
  local alto = 0
  local cs, cp = db.seccion, db.paso
  local cab = filas.cab
  if not cab then
    cab = GL.Texto(panel, "GameFontHighlightSmall")
    filas.cab = cab
  end
  cab:ClearAllPoints()
  cab:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(y + 2))
  cab:SetText(C.GRIS .. L"DESPUÉS" .. C.FIN)
  cab:Show()
  alto = 16
  local usadas = 0
  for i = 1, n do
    cs, cp = GL.PasoDespues(cs, cp)
    if not cs then break end
    local paso = GL.RUTA.secciones[cs].pasos[cp]
    local f = Fila(1 + i, panel)
    f.titulo = (cs ~= db.seccion) and (GL.RUTA.secciones[cs].titulo .. L" · paso " .. cp) or (L"Paso " .. cp)
    Pintar(f, panel, y + alto, paso, cs .. ":" .. cp, false, ancho)
    f.linea:Show()
    alto = alto + 19
    usadas = usadas + 1
  end
  -- resumen de lo que queda de la sección
  local sec = GL.RUTA.secciones[db.seccion]
  local quedan, xp, t = 0, 0, 0
  local tSabe = false
  for i = db.paso + 1, #((sec and sec.pasos) or {}) do
    local paso = sec.pasos[i]
    local okE, est = pcall(GL.EstadoPaso, paso)
    if not (okE and est == "hecho") then
      quedan = quedan + 1
      local x = XPPaso(paso, db.seccion .. ":" .. i)
      if x then xp = xp + x end
      local tt = TiempoPaso(db.seccion .. ":" .. i)
      if tt then t = t + tt; tSabe = true end
    end
  end
  if usadas == 0 and quedan == 0 then cab:Hide(); return 0 end
  if quedan > 0 then
    local f = filas.resumen
    if not f then
      f = CreateFrame("Frame", nil, panel, PLANTILLA)
      f:SetHeight(20)
      f.texto = GL.Texto(f, "GameFontHighlightSmall")
      f.texto:SetPoint("LEFT", f, "LEFT", 8, 0)
      f.der = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
      f.der:SetPoint("RIGHT", f, "RIGHT", -8, 0)
      filas.resumen = f
    end
    GL.Caja(f, { 1, 1, 1, 0.03 }, GL.COLOR.cajaBorde)
    local partes = { quedan .. (quedan == 1 and L" paso" or L" pasos") }
    if xp > 0 then table.insert(partes, "+" .. Miles(xp) .. " XP") end
    if tSabe then table.insert(partes, L"unos " .. Duracion(t) .. (GL.EstimarPaso and L" (tu ritmo)" or "")) end
    f.texto:SetText(C.GRIS .. L"Lo que queda de sección: " .. C.FIN .. table.concat(partes, C.GRIS .. " · " .. C.FIN))
    local cur, max = Num(UnitXP and UnitXP("player")), Num(UnitXPMax and UnitXPMax("player"))
    local sube = cur and max and max > 0 and xp > 0 and (cur + xp >= max) and Nivel() < 60
    f.der:SetText(sube and (L"|cffa48cffnivel " .. (Nivel() + 1) .. C.FIN) or "")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(y + alto + 2))
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -(y + alto + 2))
    f:Show()
    alto = alto + 24
  elseif filas.resumen then
    filas.resumen:Hide()
  end
  return alto
end

------------------------------------------------------------------------
-- Minimapa en la caja del paso (debajo de la línea «Ahora»)
------------------------------------------------------------------------
local ALTO_MAPA = 66
local mapa
local function CrearMapa(caja)
  mapa = CreateFrame("Button", nil, caja, PLANTILLA)
  mapa:SetHeight(ALTO_MAPA)
  GL.Caja(mapa, { 0, 0, 0, 0.5 }, GL.COLOR.cajaBorde)
  if mapa.SetClipsChildren then mapa:SetClipsChildren(true) end
  mapa.lienzo = CreateFrame("Frame", nil, mapa)
  mapa.lienzo:SetAllPoints()
  mapa.teselas = {}
  local function Punto(r, g, b, lado)
    local t = mapa:CreateTexture(nil, "OVERLAY")
    t:SetTexture(BLANCO8)
    t:SetSize(lado, lado)
    t:SetVertexColor(r, g, b, 1)
    return t
  end
  mapa.tu = Punto(0.49, 0.42, 1, 7)
  mapa.tuBorde = mapa:CreateTexture(nil, "ARTWORK")
  mapa.tuBorde:SetTexture(BLANCO8); mapa.tuBorde:SetSize(11, 11); mapa.tuBorde:SetVertexColor(1, 1, 1, 0.9)
  mapa.destino = Punto(1, 0.78, 0.25, 8)
  mapa.destinoBorde = mapa:CreateTexture(nil, "ARTWORK")
  mapa.destinoBorde:SetTexture(BLANCO8); mapa.destinoBorde:SetSize(12, 12); mapa.destinoBorde:SetVertexColor(0, 0, 0, 0.9)
  mapa.camino = {}
  for i = 1, 10 do mapa.camino[i] = Punto(1, 1, 1, 2) end
  mapa.nombre = GL.Texto(mapa, "GameFontHighlightSmall")
  mapa.nombre:SetPoint("TOPLEFT", mapa, "TOPLEFT", 5, -4)
  mapa.abrir = GL.Texto(mapa, "GameFontHighlightSmall", "RIGHT")
  mapa.abrir:SetPoint("BOTTOMRIGHT", mapa, "BOTTOMRIGHT", -5, 4)
  mapa.abrir:SetText(C.GRIS .. L"Abrir mapa" .. C.FIN)
  mapa:SetScript("OnClick", function(self)
    if self.mapID and WorldMapFrame and OpenWorldMap then pcall(OpenWorldMap, self.mapID)
    elseif ToggleWorldMap then pcall(ToggleWorldMap) end
  end)
  if GL.Ayuda then GL.Ayuda(mapa, L"Mapa del paso", L"Tú en morado y el destino en dorado. Clic: abre el mapa grande.") end
end

local function PosJugador(m)
  if not (C_Map and C_Map.GetPlayerMapPosition) then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
  if ok and pos and pos.GetXY then
    local x, y = pos:GetXY()
    if Num(x) and Num(y) and (x > 0 or y > 0) then return x, y end
  end
  return nil
end

-- Pinta el recorte; devuelve false si no hay dibujo de ese mapa.
local function PintarMapa(d, ancho)
  if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures and d.m) then return false end
  local okC, capas = pcall(C_Map.GetMapArtLayers, d.m)
  local capa = okC and type(capas) == "table" and capas[1]
  local okT, texturas = pcall(C_Map.GetMapArtLayerTextures, d.m, 1)
  if type(capa) ~= "table" or not okT or type(texturas) ~= "table" or #texturas == 0 then return false end
  local LW, LH, TW, TH = Num(capa.layerWidth), Num(capa.layerHeight), Num(capa.tileWidth), Num(capa.tileHeight)
  if not (LW and LH and TW and TH) or LW <= 0 then return false end
  local W, H = ancho, ALTO_MAPA
  local dx, dy = (d.x or 50) / 100, (d.y or 50) / 100
  local px, py = PosJugador(d.m)
  -- zoom: que quepan tú y el destino, entre el mapa entero a lo ancho y tres veces más cerca
  local cx, cy, esc = dx, dy, 3 * W / LW
  if px then
    cx, cy = (dx + px) / 2, (dy + py) / 2
    local sepX, sepY = math.abs(dx - px) * LW + 40, math.abs(dy - py) * LH + 30
    esc = math.min(3 * W / LW, W / sepX, H / sepY)
  end
  esc = math.max(esc, W / LW)
  local vw, vh = W / esc, H / esc   -- ventana visible en píxeles del mapa
  local x0 = math.max(0, math.min(LW - vw, cx * LW - vw / 2))
  local y0 = math.max(0, math.min(math.max(0, LH - vh), cy * LH - vh / 2))
  local cols = math.ceil(LW / TW)
  local usadas = 0
  for i, tex in ipairs(texturas) do
    local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
    local tx0, ty0 = c * TW, r * TH
    local ix0, ix1 = math.max(tx0, x0), math.min(tx0 + TW, x0 + vw)
    local iy0, iy1 = math.max(ty0, y0), math.min(ty0 + TH, y0 + vh)
    if ix1 > ix0 and iy1 > iy0 then
      usadas = usadas + 1
      local t = mapa.teselas[usadas]
      if not t then t = mapa.lienzo:CreateTexture(nil, "BACKGROUND"); mapa.teselas[usadas] = t end
      t:SetTexture(tex)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", mapa, "TOPLEFT", (ix0 - x0) * esc, -(iy0 - y0) * esc)
      t:SetSize((ix1 - ix0) * esc, (iy1 - iy0) * esc)
      t:SetTexCoord((ix0 - tx0) / TW, (ix1 - tx0) / TW, (iy0 - ty0) / TH, (iy1 - ty0) / TH)
      t:SetVertexColor(0.75, 0.75, 0.75)
      t:Show()
    end
  end
  for i = usadas + 1, #mapa.teselas do mapa.teselas[i]:Hide() end
  local function Poner(t, x, y)
    t:ClearAllPoints()
    t:SetPoint("CENTER", mapa, "TOPLEFT", (x * LW - x0) * esc, -(y * LH - y0) * esc)
    t:Show()
  end
  Poner(mapa.destinoBorde, dx, dy); Poner(mapa.destino, dx, dy)
  if px then
    Poner(mapa.tuBorde, px, py); Poner(mapa.tu, px, py)
    for i = 1, #mapa.camino do
      local f = i / (#mapa.camino + 1)
      Poner(mapa.camino[i], px + (dx - px) * f, py + (dy - py) * f)
      mapa.camino[i]:SetAlpha(0.55)
    end
  else
    mapa.tu:Hide(); mapa.tuBorde:Hide()
    for i = 1, #mapa.camino do mapa.camino[i]:Hide() end
  end
  mapa.mapID = d.m
  mapa.nombre:SetText(C.BLANCO .. (GL.ZonaDestinoGuiaR11 and GL.ZonaDestinoGuiaR11(d) or tostring(d.z or "")) .. C.FIN)
  return true
end

local pintarAhora = GL.PintarAhora
local function EnvolverAhora()
  if GL._ahora9 or not GL.PintarAhora then return end
  pintarAhora = GL.PintarAhora
  GL._ahora9 = true
  GL.PintarAhora = function(caja, d, r, ancho)
    local h = pintarAhora(caja, d, r, ancho) or 0
    if mapa then mapa:Hide() end
    do return h end   -- 9.4.2: sin minimapa en la caja del paso (no hacía falta)
    if not Si("mapaPaso") or type(d) ~= "table" or not d.m or not caja then return h end
    if GL.ModoLectura and GL.ModoLectura() then return h end
    if not mapa then CrearMapa(caja) end
    local w = math.max(80, (ancho or 360) - 24 - (r or 0))
    mapa:ClearAllPoints()
    mapa:SetPoint("TOPLEFT", caja, "TOPLEFT", 14 + (r or 0), -(26 + h))
    mapa:SetWidth(w)
    local ok, hay = pcall(PintarMapa, d, w)
    if not (ok and hay) then return h end
    mapa:Show()
    return h + ALTO_MAPA + 6
  end
end

-- El minimapa de la caja del paso está desactivado desde 9.4.2: no necesita OnUpdate.

------------------------------------------------------------------------
-- Avisos fuera de la ventana (ventana cerrada, compacta o en franja)
------------------------------------------------------------------------
local tostadas, vistas = {}, {}
local function VentanaCompleta()
  return GL.frame and GL.frame:IsShown() and (DB().tamano or "completo") == "completo"
end

local function Tostada(i)
  local t = tostadas[i]
  if t then return t end
  t = CreateFrame("Frame", nil, UIParent, PLANTILLA)
  t:SetFrameStrata("HIGH")
  t:SetSize(330, 46)
  GL.Caja(t, { 0.082, 0.090, 0.122, 0.95 }, { 1, 0.30, 0.30, 0.8 })
  t.icono = t:CreateTexture(nil, "ARTWORK")
  t.icono:SetSize(20, 20)
  t.icono:SetPoint("LEFT", t, "LEFT", 10, 2)
  t.titulo = GL.Texto(t, "GameFontNormal")
  t.titulo:SetPoint("TOPLEFT", t, "TOPLEFT", 38, -8)
  t.texto = GL.Texto(t, "GameFontHighlightSmall")
  t.texto:SetPoint("TOPLEFT", t.titulo, "BOTTOMLEFT", 0, -2)
  t.texto:SetPoint("RIGHT", t, "RIGHT", -64, 0)
  -- 9.7.4: el texto salta de línea (hasta tres) y el aviso crece; antes, en una línea, se cortaba
  if t.texto.SetWordWrap then t.texto:SetWordWrap(true) end
  if t.texto.SetMaxLines then t.texto:SetMaxLines(3) end
  if t.texto.SetJustifyH then t.texto:SetJustifyH("LEFT") end
  t.vale = GL.CrearBoton(t, L"Vale", function() local f = t.GetScript and t:GetScript("OnMouseUp"); if f then f(t) else t:Hide() end end, nil, 20)   -- 9.4.2: Vale hace lo mismo que el clic en el aviso
  t.vale:SetWidth(48)
  t.vale:SetPoint("RIGHT", t, "RIGHT", -8, 2)
  t.tiempo = t:CreateTexture(nil, "OVERLAY")
  t.tiempo:SetHeight(2)
  t.tiempo:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 1, 1)
  t:EnableMouse(true)
  t:SetScript("OnMouseUp", function(self)
    self:Hide()
    if type(self.abrir) == "function" then pcall(self.abrir); return end   -- 9.4.2: el aviso te lleva a arreglarlo
    if self.abrir and GL.AlternarVentana and not (GL.frame and GL.frame:IsShown()) then GL.AlternarVentana() end
    if self.abrir and GL.AbrirModo then pcall(GL.AbrirModo, self.abrir) end
  end)
  t:SetScript("OnUpdate", function(self)
    local pasado = Ahora() - (self.t0 or 0)
    local dura = 6
    self.tiempo:SetWidth(math.max(1, (self:GetWidth() - 2) * (1 - pasado / dura)))
    if pasado > dura then self:Hide() end
  end)
  t:Hide()
  tostadas[i] = t
  return t
end

local function Colocar()
  local y = -150
  for i = 1, #tostadas do
    local t = tostadas[i]
    if t:IsShown() then
      t:ClearAllPoints()
      t:SetPoint("TOP", UIParent, "TOP", 0, y)
      y = y - ((t.GetHeight and tonumber(t:GetHeight())) or 46) - 6
    end
  end
end

local function Lanzar(titulo, texto, urgente, abrir)
  local libre
  for i = 1, 2 do if not Tostada(i):IsShown() then libre = tostadas[i]; break end end
  if not libre then libre = tostadas[1] end   -- como mucho dos: la más vieja se sustituye
  local col = urgente and { 1, 0.30, 0.30 } or { 1, 0.82, 0 }
  local ca = GL.COLORES_AVISO
  if ca then local cu = ca[urgente and 1 or 2]; if cu and cu.borde then col = cu.borde end end
  GL.Caja(libre, { 0.082, 0.090, 0.122, 0.95 }, { col[1], col[2], col[3], 0.85 })
  libre.tiempo:SetColorTexture(col[1], col[2], col[3], 0.9)
  libre.icono:SetTexture(urgente and "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" or "Interface\\GossipFrame\\AvailableQuestIcon")
  libre.titulo:SetText((urgente and (GL.Icono("⚠") .. " |cffff7070") or C.AMARILLO) .. titulo .. C.FIN)
  libre.texto:SetText(texto or "")
  local h = libre.texto.GetStringHeight and tonumber(libre.texto:GetStringHeight()) or nil
  libre:SetHeight(math.max(46, math.min(3 * 12, h or 12) + 34))
  libre.abrir = abrir
  libre.t0 = Ahora()
  libre:Show()
  Colocar()
  if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING and DB().sonidos == true then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
end

local function Limpio(t)
  t = tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return (t:gsub("\n.*", ""))
end

-- 9.4.2: qué hace el clic en cada aviso (antes abría la Guía, que ya no enseña los avisos)
local PosaderoEn
local function AlPosadero(municion)
  local zona = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
  local p = PosaderoEn and PosaderoEn(zona)
  if p and GL.SeguirDesvio then
    GL.SeguirDesvio(p)
    if GL.Mensaje then GL.Mensaje(municion and L"la flecha te lleva a la posada: el vendedor de flechas y balas suele estar cerca."
      or L"la flecha te lleva al posadero: vende comida y bebida.") end
  elseif municion then
    if GL.Mensaje then GL.Mensaje(L"no conozco una posada en esta zona: compra flechas o balas en la próxima ciudad.") end
  elseif GL.Mensaje then
    GL.Mensaje(L"no conozco un posadero en esta zona: compra comida y bebida en el de la próxima ciudad.")
  end
end
local ACCION_AVISO = {
  comida = function()
    local _, clase = UnitClass and UnitClass("player")
    if clase == "MAGE" then   -- el mago la conjura: se lo recuerda
      if GL.Mensaje then GL.Mensaje(L"conjura comida y agua: Conjurar comida y Conjurar agua, en tu libro de hechizos.") end
      return
    end
    AlPosadero()
  end,
  bolsas = function() if OpenAllBags then OpenAllBags() elseif ToggleAllBags then ToggleAllBags() end end,
  equipo = "equipo",
  municion = function() AlPosadero(true) end,
}
-- los reactivos (venenos, polvos, velas...) se venden en las capitales: lo dice en el chat
local function AccionAviso(clave)
  if ACCION_AVISO[clave] then return ACCION_AVISO[clave] end
  if string.find(clave, "^reactivo") then
    return function() if GL.Mensaje then GL.Mensaje(L"los reactivos los vende el vendedor de reactivos de las capitales y de algunos pueblos grandes.") end end
  end
end

local TITULOS = { comida = "Sin comida ni bebida", bolsas = "Bolsas llenas", municion = "Poca munición", equipo = "Equipo a punto de romperse" }
GL.TITULOS_AVISO = TITULOS   -- 9.4
local function MirarAvisos()
  if not Si("avisosFuera") then return end   -- 9.4.2: también con la ventana abierta (ya no hay avisos en la Guía)
  if InCombatLockdown and InCombatLockdown() then return end
  local hay = {}
  if GL.ListaAvisos and GL.UrgenciaAviso then
    local ok, l = pcall(GL.ListaAvisos)
    if ok and type(l) == "table" then
      for _, a in ipairs(l) do
        local clave = a[1]
        local u = GL.UrgenciaAviso(clave)
        if u == 1 then
          hay[clave] = true
          if not vistas[clave] then
            vistas[clave] = true
            local titulo = (TITULOS[clave] and L(TITULOS[clave])) or (string.find(clave, "^reactivo") and L"Pocos reactivos") or L"Aviso"
            Lanzar(titulo, Limpio(a[2]), true, AccionAviso(clave))
          end
        end
      end
    end
  end
  -- talento por gastar
  local puntos = Num(UnitCharacterPoints and UnitCharacterPoints("player"))
  if puntos and puntos > 0 and Nivel() >= 10 then
    hay.talento = true
    if not vistas.talento then
      vistas.talento = true
      Lanzar(L"Talento disponible", puntos .. (puntos == 1 and L" punto" or L" puntos") .. L" por gastar · clic para verlo", false, "talentos")
    end
  end
  -- un aviso que se fue vuelve a poder salir
  for k in pairs(vistas) do if not hay[k] then vistas[k] = nil end end
end
GL.LanzarAvisoFuera = Lanzar

------------------------------------------------------------------------
-- «Antes de salir»: lo que conviene comprar antes de dejar la zona
------------------------------------------------------------------------
local PALABRAS_POSADA = { "Tabernero", "Tabernera", "Posadero", "Posadera", "Innkeeper" }
function PosaderoEn(zona)   -- 9.4.2: declarada arriba (la usa el clic de los avisos)
  if not GL.RUTA then return nil end
  local mejor, mejorDist
  for _, sec in ipairs(GL.RUTA.secciones) do
    for _, paso in ipairs(sec.pasos or {}) do
      for _, wp in ipairs(paso.wp or {}) do
        if wp.z == zona and wp.n then
          for _, pal in ipairs(PALABRAS_POSADA) do
            if string.find(wp.n, pal, 1, true) then
              local dist = 1e9
              if GL.Vector then
                local ok, este, _, dd = pcall(GL.Vector, wp)
                if ok and este and dd then dist = dd end
              end
              if not mejor or dist < mejorDist then mejor, mejorDist = wp, dist end
            end
          end
        end
      end
    end
  end
  return mejor, mejorDist
end

local function Metros(yardas)
  if not yardas or yardas >= 1e8 then return "" end
  local m = yardas * 0.9144
  if m >= 1000 then return GL.FormatoDecimal(string.format(L"%.1f km", m / 1000)) end
  return math.floor(m + 0.5) .. " m"
end

function GL.LineasAntesDeSalir(zona)
  local l = {}
  local nv = Nivel()
  local cache = GL.BolsasCache and GL.BolsasCache()
  local comida = type(cache) == "table" and Num(cache.comida)
  if comida and nv >= 5 and comida < 20 then
    local quien, dist = PosaderoEn(zona)
    local donde = quien and (C.GRIS .. " · " .. tostring(quien.n) .. (Metros(dist) ~= "" and (", " .. Metros(dist)) or "") .. C.FIN) or ""
    local clase = UnitClass and select(2, UnitClass("player"))
    if clase == "MAGE" then   -- 9.4.2: el mago la invoca, no hace falta ir al posadero
      table.insert(l, { L"Comida y bebida: tienes " .. C.AMARILLO .. comida .. C.FIN .. L", invoca hasta unas 20 con Crear comida y Crear agua" })
    else
      table.insert(l, { L"Comida y bebida: tienes " .. C.AMARILLO .. comida .. C.FIN .. ", " .. L"compra" .. L" hasta unas 20" .. donde, quien })
    end
  end
  if nv >= 5 and type(cache) == "table" and Num(cache.pociones) then
    table.insert(l, { L"Pociones de tu nivel en bolsas: " .. C.AMARILLO .. cache.pociones .. C.FIN .. L" · revisa las de salud y, si usas maná, las de maná." })
  end
  local clase = UnitClass and select(2, UnitClass("player"))
  for _, r in ipairs((GL.REACTIVOS and GL.REACTIVOS[clase or ""]) or {}) do
    local n = GetItemCount and Num(GetItemCount(r.id))
    if n and nv >= r.nivel and n < r.min * 3 then
      local nombre = (GetItemInfo and GetItemInfo(r.id)) or r.n
      table.insert(l, { nombre .. L": tienes " .. C.AMARILLO .. n .. C.FIN .. L", lleva " .. (r.min * 3) .. C.GRIS .. L" · vendedor de reactivos" .. C.FIN })
    end
  end
  if clase == "HUNTER" and nv >= 10 and type(cache) == "table" and Num(cache.municion) and cache.municion < 600 then
    table.insert(l, { L"Munición: tienes " .. C.AMARILLO .. cache.municion .. C.FIN .. L", lleva al menos 600" .. C.GRIS .. L" · armero o vendedor" .. C.FIN })
  end
  if type(cache) == "table" and Num(cache.libres) and cache.libres <= 4 then
    table.insert(l, { L"Bolsas: solo " .. C.AMARILLO .. cache.libres .. C.FIN .. (cache.libres == 1 and L" hueco libre" or L" huecos libres") .. L", vende lo gris antes de irte" })
  end
  return l
end

------------------------------------------------------------------------
-- Ajustes y arranque
------------------------------------------------------------------------
GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "pasosLinea", "Línea de tiempo: pasos siguientes",
  "Cuántos pasos se ven debajo del actual. Con 0 no sale la línea de tiempo.",
  function() return Cuantos() end, function(v) DB().pasosLinea = v; if GL.Refrescar then GL.Refrescar() end end,
  pestana = "paso", opciones = { { 0, "0" }, { 1, "1" }, { 2, "2" }, { 3, "3" } } })
table.insert(GL.ajustesInterfaz, { "pildoras", "Avisos en píldoras",
  "Cada aviso es una etiqueta pequeña; al pulsarla se abre. Los urgentes salen abiertos.",
  function() return Si("pildoras") end, function(v) DB().pildoras = v; if GL.Refrescar then GL.Refrescar() end end, pestana = "avisos" })
table.insert(GL.ajustesInterfaz, { "avisosFuera", "Avisos fuera de la ventana",
  "Con la ventana cerrada, compacta o en franja, los avisos urgentes y el talento por gastar salen unos segundos arriba en el centro.",
  function() return Si("avisosFuera") end, function(v) DB().avisosFuera = v end, pestana = "avisos" })

table.insert(GL.alIniciar, function()
  LeerXP()
  MirarPaso()
  EnvolverAhora()
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_XP_UPDATE")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:RegisterEvent("BAG_UPDATE_DELAYED")
  f:RegisterEvent("CHARACTER_POINTS_CHANGED")
  f:SetScript("OnEvent", function(_, evento)
    if evento == "PLAYER_XP_UPDATE" or evento == "PLAYER_LEVEL_UP" then pcall(LeerXP) end
    pcall(MirarAvisos)
  end)
  if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(5, function() pcall(MirarAvisos) end) end
end)
GL.trasRefrescar = GL.trasRefrescar or {}
table.insert(GL.trasRefrescar, function() pcall(MirarPaso) end)

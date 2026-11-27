-- Adornos.lua (8.9): más mejoras solo de aspecto. Creado por JKRiveroF.
-- Retrato del personaje en la cabecera, avisos en las pestañas,
-- ayudas con el estilo del addon, hitos de nivel en la barra de ruta, flecha que crece al llegar, aviso de
-- cueva o altura en la flecha y confeti al subir de nivel. Todo se apaga en Opciones > Ajustes > Aspecto.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"

local function DB() return GuiaAventureroDB or {} end
local function Si(k) return DB()[k] ~= false end
local function Probar(fn, nombre, ...)
  local ok, err = pcall(fn, ...)
  if not ok and GL.Fallo(nombre, err) and GL.Mensaje then GL.Mensaje(L"error en " .. nombre .. ": " .. tostring(err)) end
end
local function Num(v) return type(v) == "number" and v or nil end

------------------------------------------------------------------------
-- 14. Retrato del personaje en la cabecera
------------------------------------------------------------------------
local function RefrescarRetrato()
  local ui = GL.ui
  if not ui or not ui.icono or not ui.icono.icono then return end
  local tex = ui.icono.icono
  if Si("retratoCabecera") and SetPortraitTexture then
    SetPortraitTexture(tex, "player")
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  elseif GL.RUTA then
    GL.PonerIcono(tex, GL.RUTA.icono)
  end
end

-- 15 y 18 (barra de XP fina y mapa de fondo) se quitaron en la 9.0: la barra grande de Interfaz.lua y el estilo moderno los sustituyen.

------------------------------------------------------------------------
-- 16. Avisos en las pestañas: en Personaje, hechizos por aprender y puntos de talento libres
------------------------------------------------------------------------
local function Insignia(b)
  if rawget(b, "gInsignia") then return b.gInsignia end
  local i = CreateFrame("Frame", nil, b)
  i:SetWidth(16); i:SetHeight(14)
  i:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 6)
  i:SetFrameLevel((b:GetFrameLevel() or 1) + 5)
  i.fondo = i:CreateTexture(nil, "ARTWORK")
  i.fondo:SetAllPoints()
  i.fondo:SetColorTexture(0.80, 0.15, 0.12, 1)
  i.texto = i:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  i.texto:SetPoint("CENTER", i, "CENTER", 0, 0)
  i:Hide()
  b.gInsignia = i
  return i
end

local PERSONAJE = { personaje = true, talentos = true, hechizos = true, equipo = true, estadisticas = true }
local function RefrescarInsignias()
  local ui = GL.ui
  if not ui or not ui.modos then return end
  for _, b in ipairs(ui.modos) do
    if b.clave == "personaje" then
      local n, h, t = 0, 0, 0
      if Si("insignias") then
        local okH, vh = pcall(function() return GL.HechizosParaAprender and GL.HechizosParaAprender() end)
        if okH and Num(vh) then h = vh end
        local okT, vt = pcall(function() return UnitCharacterPoints and UnitCharacterPoints("player") end)
        if okT and Num(vt) then t = vt end
        n = h + t
      end
      -- 8.9.2: el número se quita al abrir Personaje y solo vuelve si cambia (otro hechizo nuevo u otro punto libre)
      local db = DB()
      local clave = h .. ":" .. t
      if PERSONAJE[db.modo or ""] then db.insigniaVista = clave end
      local i = Insignia(b)
      if n > 0 and db.insigniaVista ~= clave then
        i.texto:SetText(n > 9 and "9+" or tostring(n))
        i:SetWidth(n > 9 and 20 or 16)
        i:Show()
      else
        i:Hide()
      end
    end
  end
end

------------------------------------------------------------------------
-- 17. Ayudas (tooltips) del addon con su estilo: fondo oscuro y borde del tema
------------------------------------------------------------------------
local piel, tocada, bordeTocado, alphaAnterior
local ayudasEnganchadas = setmetatable({}, { __mode = "k" })
local function EsNuestro(owner)
  if not owner then return false end
  if type(owner) == "table" and rawget(owner, "ayudaTitulo") ~= nil then return true end
  local f, vueltas = owner, 0
  while f and vueltas < 12 do
    if f == GL.frame or f == GL.flecha or f == GL.panelOpciones then return true end
    f = f.GetParent and f:GetParent()
    vueltas = vueltas + 1
  end
  return false
end

local function Desvestir()
  if piel then piel:Hide() end
  local borde, anterior = bordeTocado, alphaAnterior
  tocada, bordeTocado, alphaAnterior = nil, nil, nil
  if borde then
    local ok, actual = pcall(borde.GetAlpha, borde)
    local publica = true
    if ok and type(issecretvalue) == "function" then
      local bien, secreto = pcall(issecretvalue, actual)
      publica = bien and not secreto
    end
    -- No sobrescribir una transparencia modificada después por otro addon.
    if ok and publica and actual == 0 then pcall(borde.SetAlpha, borde, anterior) end
  end
end

local function Vestir(tt)
  Desvestir()
  if not Si("ayudasEstilo") or not EsNuestro(tt.GetOwner and tt:GetOwner()) then return end
  if not piel then
    piel = CreateFrame("Frame", nil, UIParent, PLANTILLA)
    piel:SetFrameStrata("TOOLTIP")
    if piel.SetBackdrop then piel:SetBackdrop({ bgFile = BLANCO8, edgeFile = BLANCO8, edgeSize = 1 }) end
    piel.raya = piel:CreateTexture(nil, "ARTWORK")
    piel.raya:SetHeight(2)
    piel.raya:SetPoint("TOPLEFT", piel, "TOPLEFT", 1, -1)
    piel.raya:SetPoint("TOPRIGHT", piel, "TOPRIGHT", -1, -1)
  end
  local c, a = GL.COLOR.fondo, GL.COLOR.acento
  if piel.SetBackdropColor then piel:SetBackdropColor(c[1], c[2], c[3], 0.97); piel:SetBackdropBorderColor(a[1], a[2], a[3], 0.7) end
  piel.raya:SetColorTexture(a[1], a[2], a[3], 1)
  local nivel = tt:GetFrameLevel() or 1
  piel:SetFrameLevel(math.max(0, nivel - 1))
  piel:ClearAllPoints()
  piel:SetAllPoints(tt)
  piel:Show()
  tocada = tt
  local borde = tt.NineSlice
  if borde and type(borde.GetAlpha) == "function" and type(borde.SetAlpha) == "function" then
    local ok, alpha = pcall(borde.GetAlpha, borde)
    local publica = true
    if ok and type(issecretvalue) == "function" then
      local bien, secreto = pcall(issecretvalue, alpha)
      publica = bien and not secreto
    end
    if ok and publica and type(alpha) == "number" and alpha >= 0 and alpha <= 1 then
      bordeTocado, alphaAnterior = borde, alpha
      borde:SetAlpha(0)
    end
  end
end

local function EngancharAyudas()
  local tt = GameTooltip
  if not tt or type(tt.HookScript) ~= "function" then return end
  local estado = ayudasEnganchadas[tt] or {}
  ayudasEnganchadas[tt] = estado
  local function Hook(evento, fn)
    if estado[evento] then return true end
    local ok, valor = pcall(tt.HookScript, tt, evento, fn)
    estado[evento] = ok and valor ~= false
    return estado[evento]
  end
  -- No aplicar la piel si no se pudo registrar su limpieza.
  if not Hook("OnHide", function(self) if tocada == self then Probar(Desvestir, "ayudas") end end) then return end
  Hook("OnTooltipCleared", function(self) if tocada == self then Probar(Desvestir, "ayudas") end end)
  Hook("OnShow", function(self) if self == GameTooltip then Probar(Vestir, "ayudas", self) end end)
end

------------------------------------------------------------------------
-- 19. Hitos de nivel en la barra de ruta (10, 20, 30, 40 y 50)
------------------------------------------------------------------------
local hitos = {}
local function RefrescarHitos()
  local ui, R = GL.ui, GL.RUTA
  if not ui or not ui.progreso or not R or not R.secciones then return end
  local barra = ui.progreso
  for i = 1, #hitos do hitos[i]:Hide(); hitos[i].num:Hide() end
  if not Si("hitos") then return end
  local total, antes = 0, {}
  for i, s in ipairs(R.secciones) do antes[i] = total; total = total + #(s.pasos or {}) end
  local ancho = barra:GetWidth() or 0
  if total == 0 or ancho <= 0 then return end
  local n = 0
  for nivel = 10, 50, 10 do
    for i, s in ipairs(R.secciones) do
      if (s.min or 0) >= nivel then
        local frac = antes[i] / total
        if frac > 0.02 and frac < 0.98 then
          n = n + 1
          local h = hitos[n]
          if not h then
            h = barra:CreateTexture(nil, "ARTWORK", nil, 7)   -- 8.9.4: por debajo del texto de la barra
            h:SetWidth(1)
            h:SetColorTexture(1, 1, 1, 0.22)
            h.num = barra:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            hitos[n] = h
          end
          h:ClearAllPoints()
          h:SetPoint("TOPLEFT", barra, "TOPLEFT", math.floor(ancho * frac), 0)
          h:SetPoint("BOTTOMLEFT", barra, "BOTTOMLEFT", math.floor(ancho * frac), 0)
          h:Show()
          h.num:ClearAllPoints()
          h.num:SetPoint("LEFT", h, "RIGHT", 2, 0)   -- dentro de la barra, junto a la marca
          h.num:SetText(tostring(nivel))
          h.num:Hide()   -- 8.9.4: el número se montaba sobre el texto de la barra; queda solo la marca
        end
        break
      end
    end
  end
end

------------------------------------------------------------------------
-- 20 y 21. Flecha: crece al acercarte y avisa de cueva o altura cerca del destino
------------------------------------------------------------------------
local PALABRAS_ABAJO = { "cueva", "mina", "cripta", L"sótano", "subterr", L"túnel", "gruta", L"bajo tierra", "abajo" }
local PALABRAS_ARRIBA = { "torre", L"piso de arriba", L"planta de arriba", "arriba", "colina", "cima", "tejado", L"balcón" }
local function Busca(texto, lista)
  for _, p in ipairs(lista) do if string.find(texto, p, 1, true) then return true end end
  return false
end

-- Solo importa el texto del destino activo y del paso actual, no su coordenada.
local nombreAltura, pasoAltura, resultadoAltura
local function Altura(d)
  local _, p = GL.PasoActual()
  local nombre, paso = d.n or "", (p and p.t) or ""
  if resultadoAltura ~= nil and nombreAltura == nombre and pasoAltura == paso then return resultadoAltura end
  local texto = string.lower(nombre .. " " .. paso)
  local r = false
  if Busca(texto, PALABRAS_ABAJO) then r = "abajo" elseif Busca(texto, PALABRAS_ARRIBA) then r = "arriba" end
  nombreAltura, pasoAltura, resultadoAltura = nombre, paso, r
  return r
end

local aviso
function GL.TrasFlechaExtra(fl)
  local e = rawget(fl, "estado")
  local base = (DB().estiloFlecha == "brujula") and 40 or 56
  -- 20: hasta un 30 % más grande en los últimos 60 m
  local factor = 1
  if Si("flechaCrece") and e and e.dist and not e.llegado and e.dist < 66 then factor = 1 + 0.30 * (1 - e.dist / 66) end
  fl.tex:SetWidth(base * factor); fl.tex:SetHeight(base * factor)
  -- 21: a menos de 80 m de un destino en cueva, mina, torre...
  if not aviso then
    aviso = fl:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    aviso:SetPoint("TOPLEFT", fl, "TOPLEFT", 6, -6)
    aviso:SetShadowOffset(1, -1)
  end
  local alt = Si("alturaFlecha") and e and e.d and e.dist and e.dist < 87 and Altura(e.d)
  if alt == "abajo" then aviso:SetText(L"|cff69ccf0▼ bajo tierra|r"); aviso:Show()
  elseif alt == "arriba" then aviso:SetText(L"|cffffd100▲ en lo alto|r"); aviso:Show()
  else aviso:Hide() end
end

------------------------------------------------------------------------
-- 22. Confeti al subir de nivel (sobre la celebración)
------------------------------------------------------------------------
local COLORES = { { 1, 0.82, 0 }, { 0.41, 0.8, 0.94 }, { 0.25, 0.85, 0.35 }, { 1, 0.4, 0.33 }, { 0.74, 0.52, 1 }, { 1, 1, 1 } }
local capaConfeti, trozos = nil, {}
local DURACION, CANTIDAD = 2.6, 48

function GL.Confeti(sobre)
  if not Si("confeti") then return end
  if not capaConfeti then
    capaConfeti = CreateFrame("Frame", nil, UIParent)
    capaConfeti:SetFrameStrata("FULLSCREEN_DIALOG")
    capaConfeti:SetWidth(460); capaConfeti:SetHeight(320)
    for i = 1, CANTIDAD do
      local t = capaConfeti:CreateTexture(nil, "OVERLAY")
      t:SetTexture(BLANCO8)
      trozos[i] = t
    end
  end
  capaConfeti:ClearAllPoints()
  if sobre and sobre.GetTop and sobre:GetTop() then
    capaConfeti:SetPoint("TOP", sobre, "TOP", 0, 30)
  else
    capaConfeti:SetPoint("TOP", UIParent, "TOP", 0, -110)
  end
  local ancho = capaConfeti:GetWidth()
  for i, t in ipairs(trozos) do
    local c = COLORES[(i % #COLORES) + 1]
    t:SetVertexColor(c[1], c[2], c[3], 1)
    local lado = 3 + math.random() * 4
    t:SetWidth(lado); t:SetHeight(lado * (0.5 + math.random()))
    t.x, t.y = ancho / 2 + (math.random() - 0.5) * 120, -10 - math.random() * 20
    t.vx, t.vy = (math.random() - 0.5) * 360, 120 + math.random() * 200
    t:Show()
  end
  local tiempo = 0
  capaConfeti:SetAlpha(1)
  capaConfeti:Show()
  capaConfeti:SetScript("OnUpdate", function(self, dt)
    dt = math.min(dt or 0, 0.05)
    tiempo = tiempo + dt
    for _, t in ipairs(trozos) do
      t.vy = t.vy - 420 * dt          -- gravedad
      t.vx = t.vx * (1 - 0.6 * dt)    -- aire
      t.x, t.y = t.x + t.vx * dt, t.y + t.vy * dt
      t:ClearAllPoints()
      t:SetPoint("CENTER", self, "TOPLEFT", t.x, t.y)
    end
    if tiempo > DURACION - 0.6 then self:SetAlpha(math.max(0, (DURACION - tiempo) / 0.6)) end
    if tiempo >= DURACION then self:SetScript("OnUpdate", nil); self:Hide() end
  end)
end

------------------------------------------------------------------------
-- Ajustes (se suman a Opciones > Ajustes > Aspecto)
------------------------------------------------------------------------
local function Todo()
  Probar(RefrescarRetrato, "retrato"); if GL.RefrescarBarraXP then Probar(GL.RefrescarBarraXP, L"barra de XP") end
  Probar(RefrescarInsignias, L"avisos de pestañas"); Probar(RefrescarHitos, "hitos")
end

GL.casillasAdornos = {
  { "retratoCabecera", L"Tu retrato en la cabecera", L"La cara de tu personaje en vez del icono de la ruta.",
    function() return Si("retratoCabecera") end, function(v) DB().retratoCabecera = v; Todo() end },
  { "barraXP", L"Barra de experiencia arriba", L"La barra de XP de arriba (9.0): XP, misiones completadas sin entregar y descansada. Se oculta al 60.",
    function() return Si("barraXP") end, function(v) DB().barraXP = v; Todo() end },
  { "insignias", L"Avisos en las pestañas", L"Un número en Personaje con los hechizos recomendados que puedes aprender y los puntos de talento libres. Se quita al abrir Personaje y vuelve solo si hay algo nuevo.",
    function() return Si("insignias") end, function(v) DB().insignias = v; Todo() end },
  { "ayudasEstilo", L"Ayudas con el estilo de la guía", L"Las ventanas de ayuda de la guía con el fondo oscuro y el borde del tema.",
    function() return Si("ayudasEstilo") end, function(v) DB().ayudasEstilo = v end },
  { "hitos", L"Hitos de nivel en la barra de ruta", L"Marcas en la barra de ruta donde empiezan los niveles 10, 20, 30, 40 y 50.",
    function() return Si("hitos") end, function(v) DB().hitos = v; Todo() end },
  { "flechaCrece", L"La flecha crece al acercarte", L"En los últimos 60 m la flecha se hace hasta un 30 % más grande.",
    function() return Si("flechaCrece") end, function(v) DB().flechaCrece = v end },
  { "alturaFlecha", L"Aviso de cueva o altura en la flecha", L"Cerca de un destino en cueva, mina, cripta o torre, la flecha avisa «bajo tierra» o «en lo alto».",
    function() return Si("alturaFlecha") end, function(v) DB().alturaFlecha = v end },
  { "confeti", L"Confeti al subir de nivel", L"Una lluvia corta de confeti sobre la celebración de nivel.",
    function() return Si("confeti") end, function(v) DB().confeti = v end },
}
GL.AplicarAdornos = Todo

------------------------------------------------------------------------
-- Inicio, eventos y refresco
------------------------------------------------------------------------
table.insert(GL.alIniciar, function()
  EngancharAyudas()
  Todo()
  if GL.frame and GL.frame.HookScript then
    GL.frame:HookScript("OnSizeChanged", function() Probar(RefrescarHitos, "hitos") end)
  end
  local ev = CreateFrame("Frame")
  GL.Evento(ev, "PLAYER_XP_UPDATE"); GL.Evento(ev, "UPDATE_EXHAUSTION"); GL.Evento(ev, "PLAYER_LEVEL_UP")
  GL.Evento(ev, "UNIT_PORTRAIT_UPDATE"); GL.Evento(ev, "ZONE_CHANGED_NEW_AREA"); GL.Evento(ev, "PLAYER_ENTERING_WORLD")
  GL.Evento(ev, "CHARACTER_POINTS_CHANGED"); GL.Evento(ev, "SPELLS_CHANGED")
  ev:SetScript("OnEvent", function(self, evento, unidad)
    if evento == "UNIT_PORTRAIT_UPDATE" and unidad ~= "player" then return end
    Todo()
  end)
end)

table.insert(GL.trasRefrescar, function()
  Probar(RefrescarInsignias, L"avisos de pestañas")
  Probar(RefrescarHitos, "hitos")
end)

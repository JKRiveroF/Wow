-- Detalles.lua (8.9.1): más mejoras solo de aspecto. Creado por JKRiveroF.
-- Degradado del tema en la cabecera, separadores con adorno, objetos con el color de su calidad, recompensas en la
-- caja del paso, «+XP» flotante, aviso al completar un objetivo, brillo de la flecha, fundido de pestañas, brillo
-- en la barra de ruta y modo compacto con el estilo nuevo. Todo se apaga en Opciones > Ajustes > Aspecto.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"

local function DB() return GuiaAventureroDB or {} end
local function Si(k) return DB()[k] ~= false end
local function Probar(fn, nombre, ...)
  local ok, err = pcall(fn, ...)
  if not ok and GL.Fallo(nombre, err) and GL.Mensaje then GL.Mensaje(L"error en " .. nombre .. ": " .. tostring(err)) end
  return ok and err
end
local function Num(v) return type(v) == "number" and v or nil end
local function Ahora() return (GetTime and GetTime()) or 0 end

-- Degradado horizontal en una textura: de (r, g, b, a) a transparente. Vale con la API nueva y con la antigua.
local function Degradado(t, r, g, b, a)
  t:SetTexture(BLANCO8)
  if CreateColor and pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(r, g, b, a), CreateColor(r, g, b, 0)) then return end
  if t.SetGradientAlpha and pcall(t.SetGradientAlpha, t, "HORIZONTAL", r, g, b, a, r, g, b, 0) then return end
  t:SetVertexColor(r, g, b, a * 0.5)
end

------------------------------------------------------------------------
-- 24. Degradado del color del tema en la cabecera
------------------------------------------------------------------------
local degradado
local function RefrescarDegradado()
  local f = GL.frame
  if not f then return end
  if not degradado then
    degradado = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    degradado:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    degradado:SetHeight(55)
    degradado:SetWidth(260)
  end
  local a = GL.COLOR.acento
  Degradado(degradado, a[1], a[2], a[3], 0.16)
  GL.Mostrar(degradado, Si("degradado"))
end

------------------------------------------------------------------------
-- 32. Separadores con adorno en los títulos (SIGUIENTE, AVISOS...)
------------------------------------------------------------------------
local function Adornar(fs)
  if not fs then return end
  if not rawget(fs, "gIzq") then
    local padre = fs:GetParent()
    fs.gIzq = padre:CreateTexture(nil, "ARTWORK")
    fs.gIzq:SetHeight(1); fs.gIzq:SetWidth(8)
    fs.gDer = padre:CreateTexture(nil, "ARTWORK")
    fs.gDer:SetHeight(1)
    fs.gPunto = padre:CreateTexture(nil, "ARTWORK")
    fs.gPunto:SetWidth(3); fs.gPunto:SetHeight(3)
  end
  if not Si("separadores") or not fs:IsShown() then
    fs.gIzq:Hide(); fs.gDer:Hide(); fs.gPunto:Hide()
    return
  end
  -- RefrescarGuia lo pone en x = 0 cada vez: aquí se corre a la derecha para dejar sitio a la raya de la izquierda
  local p, rel, rp, x, y = fs:GetPoint(1)
  if p and (x or 0) < 12 then fs:ClearAllPoints(); fs:SetPoint(p, rel, rp, 12, y) end
  local a = GL.COLOR.acento
  fs.gIzq:SetColorTexture(a[1], a[2], a[3], 0.6)
  fs.gIzq:ClearAllPoints()
  fs.gIzq:SetPoint("RIGHT", fs, "LEFT", -3, 0)
  fs.gPunto:SetColorTexture(a[1], a[2], a[3], 0.9)
  fs.gPunto:ClearAllPoints()
  fs.gPunto:SetPoint("RIGHT", fs.gIzq, "LEFT", 0, 0)
  local largo = (fs.GetStringWidth and fs:GetStringWidth()) or 60
  fs.gDer:SetColorTexture(1, 1, 1, 0.10)
  fs.gDer:ClearAllPoints()
  fs.gDer:SetPoint("LEFT", fs, "LEFT", largo + 6, 0)
  fs.gDer:SetPoint("RIGHT", GL.ui.panelGuia, "RIGHT", 0, 0)
  fs.gIzq:Show(); fs.gDer:Show(); fs.gPunto:Show()
end

local function RefrescarSeparadores()
  local ui = GL.ui
  if not ui or not ui.grupos then return end
  for _, fs in pairs(ui.grupos) do Adornar(fs) end
  Adornar(ui.cabAvisos)
end

------------------------------------------------------------------------
-- 25. Objetos <...> del texto del paso con el color de su calidad (si el juego lo conoce)
------------------------------------------------------------------------
local CALIDAD = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000" }
function GL.ColorObjeto(nombre)
  if not Si("calidad") then return nil end
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not f then return nil end
  local ok, n, _, q = pcall(f, nombre)
  q = ok and n and Num(q)
  if not q or q < 2 then return nil end   -- lo normal (blanco o gris) se queda en verde como siempre
  return "|c" .. (CALIDAD[q] or CALIDAD[2])
end

------------------------------------------------------------------------
-- 26. Recompensas de la misión que entregas, en la caja del paso (la recomendada, marcada)
------------------------------------------------------------------------
local LADO_REC = 20
local iconosRec = {}

local function IndiceEnDiario(q)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
    local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, q)
    if ok and Num(i) and i > 0 and i < math.huge and i % 1 == 0 then return i end
  end
  if GetQuestLogIndexByID then
    local ok, i = pcall(GetQuestLogIndexByID, q)
    if ok and Num(i) and i > 0 and i < math.huge and i % 1 == 0 then return i end
  end
  return nil
end

local function Recompensas(p)
  if not (SelectQuestLogEntry and GetNumQuestLogChoices and GetQuestLogItemLink) then return nil end
  for _, d in ipairs(p.wp or {}) do
    if d.a == "T" and d.q and not GL.DestinoHecho(d) then
      local idx = IndiceEnDiario(d.q)
      if idx then
        local ok, lista = GL.ConSeleccionMisionR13(idx, function()
          local totalOpciones = GetNumQuestLogChoices() or 0
          local lista = { incompleta = totalOpciones > 6 }
          for i = 1, math.min(totalOpciones, 6) do
            local _, tex, cuantos, q = GetQuestLogChoiceInfo(i)
            table.insert(lista, { tex = tex, n = cuantos, q = q, enlace = GetQuestLogItemLink("choice", i), elegir = true })
          end
          for i = 1, math.min((GetNumQuestLogRewards and GetNumQuestLogRewards()) or 0, 6 - #lista) do
            local _, tex, cuantos, q = GetQuestLogRewardInfo(i)
            table.insert(lista, { tex = tex, n = cuantos, q = q, enlace = GetQuestLogItemLink("reward", i) })
          end
          return lista
        end)
        if ok and lista and #lista > 0 then return lista end
      end
    end
  end
  return nil
end

-- La mejor para tu equipo según los pesos de la ruta (lo mismo que hace Misiones.lua al entregar).
local function Recomendada(lista)
  local U, equipo = GL.EquipoUtil, GL.RUTA and GL.RUTA.equipo
  if not U or not U.ElegirRecompensa or not equipo then return nil end
  -- La vista previa solo destaca mejoras de equipo, no recompensas para vender.
  local mejor = U.ElegirRecompensa(lista, equipo)
  return mejor
end

GL.RecompensasPaso, GL.RecompensaRecomendada, GL.IndiceEnDiario = Recompensas, Recomendada, IndiceEnDiario   -- 9.0: Guia9.lua

local function IconoRec(caja, i)
  local b = iconosRec[i]
  if b then return b end
  b = CreateFrame("Button", nil, caja)
  b:SetWidth(LADO_REC); b:SetHeight(LADO_REC)
  b.borde = b:CreateTexture(nil, "BACKGROUND")
  b.borde:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
  b.borde:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
  b.icono = b:CreateTexture(nil, "ARTWORK")
  b.icono:SetAllPoints()
  b.icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.num = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.num:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, 0)
  b.marca = b:CreateTexture(nil, "OVERLAY")
  b.marca:SetWidth(12); b.marca:SetHeight(12)
  b.marca:SetPoint("TOPRIGHT", b, "TOPRIGHT", 4, 4)
  b.marca:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.enlace then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetHyperlink, GameTooltip, self.enlace)
    if self.recomendada then GameTooltip:AddLine(L"Recomendada para ti", 0.25, 0.85, 0.35) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  iconosRec[i] = b
  return b
end

-- RefrescarGuia la llama con la caja ya medida; devuelve el alto que añade (0 si no hay recompensas).
function GL.AltoRecompensas(caja, p, ancho, alto)
  for i = 1, #iconosRec do iconosRec[i]:Hide() end
  if not Si("recompensasPaso") then return 0 end
  local lista = Recompensas(p)
  if not lista then return 0 end
  local rec = Recomendada(lista)
  for i, r in ipairs(lista) do
    local b = IconoRec(caja, i)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", caja, "TOPLEFT", 14 + (i - 1) * (LADO_REC + 6), -(alto - 2))
    b.icono:SetTexture(r.tex or GL.INTERROGANTE)
    local col = CALIDAD[Num(r.q) or 1] or CALIDAD[1]
    b.borde:SetColorTexture(tonumber(col:sub(3, 4), 16) / 255, tonumber(col:sub(5, 6), 16) / 255, tonumber(col:sub(7, 8), 16) / 255, 0.9)
    b.num:SetText((Num(r.n) and r.n > 1) and r.n or "")
    b.enlace, b.recomendada = r.enlace, (i == rec)
    GL.Mostrar(b.marca, i == rec)
    b:Show()
  end
  return LADO_REC + 8
end

------------------------------------------------------------------------
-- 27. «+350 XP» flotante al entregar una misión
------------------------------------------------------------------------
local flotantes = {}
local function Flotar(texto)
  local ancla = (GL.frame and GL.frame:IsShown() and GL.frame) or (GL.flecha and GL.flecha:IsShown() and GL.flecha) or UIParent
  local f
  for _, x in ipairs(flotantes) do if not x:IsShown() then f = x; break end end
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetWidth(200); f:SetHeight(24)
    f.texto = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.texto:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.texto:SetShadowOffset(1, -1)
    table.insert(flotantes, f)
  end
  f.texto:SetText(texto)
  f:ClearAllPoints()
  f:SetPoint("BOTTOM", ancla, "TOP", 0, 4)
  f.t0 = Ahora()
  f:SetAlpha(1)
  f:Show()
  f:SetScript("OnUpdate", function(self)
    local t = Ahora() - self.t0
    self:ClearAllPoints()
    self:SetPoint("BOTTOM", ancla, "TOP", 0, 4 + t * 28)
    if t > 1 then self:SetAlpha(math.max(0, 1 - (t - 1) / 0.8)) end
    if t > 1.8 then self:SetScript("OnUpdate", nil); self:Hide() end
  end)
end

------------------------------------------------------------------------
-- 28. Aviso en el centro al completar un objetivo («Pañuelo de seda roja 10/10 ✔»)
------------------------------------------------------------------------
local banner
local function Banner(texto)
  if not banner then
    banner = CreateFrame("Frame", nil, UIParent)
    banner:SetFrameStrata("HIGH")
    banner:SetWidth(520); banner:SetHeight(40)
    banner:SetPoint("TOP", UIParent, "TOP", 0, -190)
    banner.fondo = banner:CreateTexture(nil, "BACKGROUND")
    banner.fondo:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
    banner.fondo:SetPoint("BOTTOMRIGHT", banner, "BOTTOM", 0, 0)
    banner.fondo2 = banner:CreateTexture(nil, "BACKGROUND")
    banner.fondo2:SetPoint("TOPLEFT", banner, "TOP", 0, 0)
    banner.fondo2:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
    banner.texto = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    banner.texto:SetPoint("CENTER", banner, "CENTER", 0, 0)
    banner.texto:SetShadowOffset(1, -1)
  end
  -- franja oscura que se desvanece hacia los lados
  Degradado(banner.fondo, 0, 0, 0, 0.6)
  if banner.fondo.SetTexCoord then banner.fondo:SetTexCoord(1, 0, 0, 1) end
  Degradado(banner.fondo2, 0, 0, 0, 0.6)
  banner.texto:SetText(texto)
  banner.t0 = Ahora()
  banner:SetAlpha(0)
  banner:Show()
  banner:SetScript("OnUpdate", function(self)
    local t = Ahora() - self.t0
    if t < 0.2 then self:SetAlpha(t / 0.2)
    elseif t < 2.2 then self:SetAlpha(1)
    elseif t < 2.9 then self:SetAlpha(1 - (t - 2.2) / 0.7)
    else self:SetScript("OnUpdate", nil); self:Hide() end
  end)
end

------------------------------------------------------------------------
-- 29. Brillo en la flecha cuando miras justo hacia el destino
------------------------------------------------------------------------
local brilloFlecha
local CERTERO = math.rad(12)
function GL.TrasFlechaBrillo(fl)
  local e = rawget(fl, "estado")
  if not brilloFlecha then
    brilloFlecha = fl:CreateTexture(nil, "BORDER")
    brilloFlecha:SetTexture(GL.RUTA_FLECHA)
    brilloFlecha:SetBlendMode("ADD")
    brilloFlecha:SetPoint("CENTER", fl.tex, "CENTER", 0, 0)
  end
  local rel = e and Num(e.rel)
  local certero = Si("brilloFlecha") and rel and not e.llegado and fl.tex:IsShown() and (rel < CERTERO or rel > 2 * math.pi - CERTERO)
  if not certero then brilloFlecha:Hide(); return end
  local lado = (fl.tex:GetWidth() or 56) * 1.35
  brilloFlecha:SetWidth(lado); brilloFlecha:SetHeight(lado)
  if brilloFlecha.SetRotation then pcall(brilloFlecha.SetRotation, brilloFlecha, -rel) end
  brilloFlecha:SetVertexColor(e.r or 1, e.g or 1, e.b or 1)
  brilloFlecha:SetAlpha(0.35 + 0.25 * math.sin(Ahora() * 6))
  brilloFlecha:Show()
end

------------------------------------------------------------------------
-- 30. Fundido al cambiar de pestaña
------------------------------------------------------------------------
local modoAnt
local function PanelDe(modo)
  local ui = GL.ui
  local extra = GL.modos[modo]
  if extra and extra.panel then return extra.panel end
  if modo == "talentos" then return ui.panelTal elseif modo == "oficios" then return ui.panelOfi end
  return ui.panelGuia
end

local function Fundido()
  local modo = DB().modo
  if modoAnt and modo ~= modoAnt and Si("fundido") then
    local p = PanelDe(modo)
    if p and p.CreateAnimationGroup then
      if not rawget(p, "gFundido") then
        local ag = p:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.22)
        p.gFundido = ag
      end
      p.gFundido:Stop(); p.gFundido:Play()
    end
  end
  modoAnt = modo
end

------------------------------------------------------------------------
-- 31. Brillo que recorre la barra de ruta cada pocos segundos
------------------------------------------------------------------------
local brilloBarra
local CICLO, PASADA, ANCHO_BRILLO = 7, 1.4, 46
local function MoverBrillo()
  local barra = GL.ui and GL.ui.progreso
  if not barra or not Si("brilloBarra") or not barra:IsVisible() or (InCombatLockdown and InCombatLockdown()) then
    if brilloBarra then brilloBarra:Hide() end
    return
  end
  if not brilloBarra then
    -- 8.9.4: el brillo va en la propia barra, por debajo del texto (antes lo tapaba)
    brilloBarra = { Show = function(self) self.izq:Show(); self.der:Show() end, Hide = function(self) self.izq:Hide(); self.der:Hide() end }
    brilloBarra.izq = barra:CreateTexture(nil, "ARTWORK", nil, 6)
    brilloBarra.der = barra:CreateTexture(nil, "ARTWORK", nil, 6)
    for _, t in ipairs({ brilloBarra.izq, brilloBarra.der }) do
      t:SetHeight(14); t:SetWidth(ANCHO_BRILLO / 2)
      if t.SetBlendMode then t:SetBlendMode("ADD") end
    end
    Degradado(brilloBarra.izq, 1, 1, 1, 0.22)
    brilloBarra.izq:SetTexCoord(1, 0, 0, 1)   -- de transparente a brillo
    Degradado(brilloBarra.der, 1, 1, 1, 0.22)
  end
  local min, max = barra:GetMinMaxValues()
  local lleno = ((barra:GetValue() or 0) - (min or 0)) / math.max(1, (max or 1) - (min or 0))
  local ancho = (barra:GetWidth() or 0) * lleno
  local t = Ahora() % CICLO
  if ancho < ANCHO_BRILLO or t > PASADA then brilloBarra:Hide(); return end
  local x = (ancho - ANCHO_BRILLO) * (t / PASADA)
  brilloBarra.izq:ClearAllPoints()
  brilloBarra.izq:SetPoint("LEFT", barra, "LEFT", x, 0)
  brilloBarra.der:ClearAllPoints()
  brilloBarra.der:SetPoint("LEFT", brilloBarra.izq, "RIGHT", 0, 0)
  brilloBarra:Show()
end

------------------------------------------------------------------------
-- 33. Modo compacto con el estilo nuevo: retrato, borde del tema, barrita del destino y marco clásico
------------------------------------------------------------------------
local function RefrescarCompacto()
  local c = _G.GuiaAventureroCompacto
  if not c or not c:IsShown() then return end
  local estilo = Si("compactoEstilo")
  local a = GL.COLOR.acento
  if c.SetBackdropBorderColor then
    if estilo then c:SetBackdropBorderColor(a[1], a[2], a[3], 0.8) else c:SetBackdropBorderColor(GL.COLOR.borde[1], GL.COLOR.borde[2], GL.COLOR.borde[3], 1) end
  end
  -- retrato en el icono pequeño (el marco del icono es el primer hijo con .icono)
  if not rawget(c, "gMarcoIcono") then
    for _, h in ipairs({ c:GetChildren() }) do
      if type(h) == "table" and rawget(h, "icono") and not rawget(c, "gMarcoIcono") then c.gMarcoIcono = h end
    end
  end
  local mi = rawget(c, "gMarcoIcono")
  if mi then
    if estilo and Si("retratoCabecera") and SetPortraitTexture then
      SetPortraitTexture(mi.icono, "player"); mi.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif GL.RUTA then
      GL.PonerIcono(mi.icono, GL.RUTA.icono)
    end
  end
  -- barrita del destino actual (6/10)
  if not rawget(c, "gBarra") then
    c.gFondo = c:CreateTexture(nil, "BORDER")
    c.gFondo:SetHeight(2)
    c.gFondo:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 10, 5)
    c.gFondo:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -10, 5)
    c.gFondo:SetColorTexture(1, 1, 1, 0.08)
    c.gBarra = c:CreateTexture(nil, "ARTWORK")
    c.gBarra:SetHeight(2)
    c.gBarra:SetPoint("BOTTOMLEFT", c.gFondo, "BOTTOMLEFT", 0, 0)
  end
  local d = GL.DestinoActual and GL.DestinoActual()
  local frac
  if estilo and d and d.q then
    local hecho = GL.DestinoHecho(d)
    local texto = GL.ProgresoDestino(d, hecho)
    local x, y = string.match(string.gsub(string.gsub(texto or "", "|c%x%x%x%x%x%x%x%x", ""), "|r", ""), "(%d+)%s*/%s*(%d+)")
    x, y = tonumber(x), tonumber(y)
    if hecho then frac = 1 elseif x and y and y > 0 then frac = math.min(1, x / y) end
  end
  if frac then
    c.gFondo:Show()
    c.gBarra:SetWidth(math.max(1, (c.gFondo:GetWidth() or 0) * frac))
    if frac >= 1 then c.gBarra:SetColorTexture(0.25, 0.85, 0.35, 1) else c.gBarra:SetColorTexture(a[1], a[2], a[3], 1) end
    GL.Mostrar(c.gBarra, frac > 0)
  else
    c.gFondo:Hide(); c.gBarra:Hide()
  end
  -- marco clásico también en el compacto
  if not rawget(c, "gMarco") and BackdropTemplateMixin then
    local m = CreateFrame("Frame", nil, c, "BackdropTemplate")
    m:SetPoint("TOPLEFT", c, "TOPLEFT", -5, 5)
    m:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 5, -5)
    m:SetFrameLevel((c:GetFrameLevel() or 1) + 30)
    m:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 18 })
    m:SetBackdropBorderColor(1, 0.92, 0.75, 1)
    c.gMarco = m
  end
  if rawget(c, "gMarco") then GL.Mostrar(c.gMarco, estilo and DB().marco == "clasico") end
end

------------------------------------------------------------------------
-- Ajustes
------------------------------------------------------------------------
local function Todo()
  Probar(RefrescarDegradado, "degradado"); Probar(RefrescarSeparadores, "separadores"); Probar(RefrescarCompacto, "compacto")
end
local function Refrescar() if GL.Refrescar then GL.Refrescar() end; Todo() end

GL.casillasDetalles = {
  { "degradado", L"Degradado del tema en la cabecera", L"El color del tema se funde de izquierda a derecha detrás del título.",
    function() return Si("degradado") end, function(v) DB().degradado = v; Todo() end },
  { "separadores", L"Separadores con adorno", L"Los títulos de la Guía (SIGUIENTE, AVISOS...) con una raya a cada lado.",
    function() return Si("separadores") end, function(v) DB().separadores = v; Refrescar() end },
  { "calidad", L"Objetos con el color de su calidad", L"Los objetos del texto del paso en verde, azul o morado según su calidad, si el juego ya los conoce.",
    function() return Si("calidad") end, function(v) DB().calidad = v; Refrescar() end },
  { "recompensasPaso", L"Recompensas en la caja del paso", L"Al ir a entregar una misión, los iconos de lo que da; la recomendada para ti lleva una marca verde.",
    function() return Si("recompensasPaso") end, function(v) DB().recompensasPaso = v; Refrescar() end },
  { "xpFlotante", L"«+XP» flotante al entregar", L"La experiencia que te da la misión sube desde la ventana y se desvanece.",
    function() return Si("xpFlotante") end, function(v) DB().xpFlotante = v end },
  { "avisoObjetivo", L"Aviso al completar un objetivo", L"En el centro de la pantalla, por ejemplo «Pañuelo de seda roja 10/10 ✔».",
    function() return Si("avisoObjetivo") end, function(v) DB().avisoObjetivo = v end },
  { "brilloFlecha", L"Brillo de la flecha al ir recto", L"La flecha brilla cuando miras justo hacia el destino.",
    function() return Si("brilloFlecha") end, function(v) DB().brilloFlecha = v end },
  { "fundido", L"Fundido al cambiar de pestaña", L"La pantalla nueva aparece con un fundido corto.",
    function() return Si("fundido") end, function(v) DB().fundido = v end },
  { "brilloBarra", L"Brillo en la barra de ruta", L"Un brillo suave recorre la barra de ruta cada pocos segundos.",
    function() return Si("brilloBarra") end, function(v) DB().brilloBarra = v end },
  { "compactoEstilo", L"Modo compacto con el estilo nuevo", L"Retrato, borde del tema, barrita del destino y marco clásico (si lo eliges) también en la ventana compacta.",
    function() return Si("compactoEstilo") end, function(v) DB().compactoEstilo = v; Todo() end },
}
GL.AplicarDetalles = Todo

------------------------------------------------------------------------
-- Inicio, eventos y refresco
------------------------------------------------------------------------
table.insert(GL.alIniciar, function()
  Todo()
  local ev = CreateFrame("Frame")
  GL.Evento(ev, "QUEST_TURNED_IN")
  GL.Evento(ev, "UI_INFO_MESSAGE")
  ev:SetScript("OnEvent", function(self, evento, a1, a2, a3)
    if evento == "QUEST_TURNED_IN" then
      local xp = Num(a2)
      if Si("xpFlotante") and xp and xp > 0 then Flotar("|cffbd85ff+" .. xp .. L" XP|r") end
    elseif evento == "UI_INFO_MESSAGE" and Si("avisoObjetivo") and (DB().avisoObjetivoTam == "pequeno" or not GL.AvisoObjetivoGrande) then   -- 9.2: el grande va en Objetivo.lua
      local texto = type(a2) == "string" and a2 or (type(a1) == "string" and a1) or nil
      if not texto then return end
      local nombre, x, y = string.match(texto, "^(.-):%s*(%d+)%s*/%s*(%d+)")
      if nombre and tonumber(x) and tonumber(x) == tonumber(y) then
        Banner("|cffffd100" .. nombre .. "|r  " .. x .. "/" .. y .. "  " .. GL.Icono("✔"))
      end
    end
  end)
  local acum = 0
  ev:SetScript("OnUpdate", function(self, dt)
    acum = acum + (dt or 0)
    if acum < 0.03 then return end
    acum = 0
    Probar(MoverBrillo, L"brillo de la barra")
  end)
  if GL.PorTema then GL.PorTema(function() Probar(RefrescarDegradado, "degradado") end) end
end)

table.insert(GL.trasRefrescar, function()
  Probar(RefrescarSeparadores, "separadores")
  Probar(Fundido, "fundido")
  Probar(RefrescarCompacto, "compacto")
end)

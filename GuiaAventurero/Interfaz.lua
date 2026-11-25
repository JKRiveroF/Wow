-- Interfaz.lua (9.0): estilo moderno. Barra de experiencia siempre visible arriba (con lo que darán las misiones
-- completadas sin entregar y la descansada), nivel en el retrato y la barra que se queda en pantalla durante el
-- combate cuando la ventana se oculta. La barra lateral de iconos la crea GuiaAventurero.lua (GL.BotonLateral).
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"

local function DB() return GuiaAventureroDB or {} end
local function Si(k) return DB()[k] ~= false end
local function Num(v) return type(v) == "number" and v or nil end
local function Probar(fn, nombre, ...)
  local ok, err = pcall(fn, ...)
  if not ok and GL.Fallo(nombre, err) and GL.Mensaje then GL.Mensaje(L"error en " .. nombre .. ": " .. tostring(err)) end
end
local function Miles(n)
  return GL.FormatoMiles(n)
end
local function Porcentaje(v)
  if v >= 10 or v == 0 then return tostring(math.floor(v + 0.5)) end
  return GL.FormatoDecimal(string.format("%.1f", v))
end

local NIVEL_MAX = 60
-- colores de la barra (9.0): morado la XP, naranja lo de las misiones completadas, azul la descansada
local COL = {
  xp = { 0.64, 0.30, 0.88 }, xp2 = { 0.42, 0.13, 0.62 },
  mision = { 1, 0.60, 0.18 }, misionTexto = "|cffff9a2e",
  descansada = { 0.29, 0.55, 1 }, descansadaTexto = "|cff5ea2ff",
}
GL.COLORES_XP = COL   -- el modo daltónico los cambia

------------------------------------------------------------------------
-- XP de las misiones del diario que ya están completas (listas para entregar)
------------------------------------------------------------------------
local function Completa(q, indice)
  if C_QuestLog and C_QuestLog.IsComplete then
    local ok, r = pcall(C_QuestLog.IsComplete, q)
    if ok and r ~= nil then return r and true or false end
  end
  if indice and GetQuestLogTitle then
    local ok, _, _, _, _, _, completa = pcall(GetQuestLogTitle, indice)
    if ok then return completa == 1 or completa == true end
  end
  return false
end

local function XPDeMision(q, indice)
  if not GetQuestLogRewardXP then return 0 end
  local ok, v = pcall(GetQuestLogRewardXP, q)
  if ok and Num(v) and v > 0 then return v end
  -- clientes antiguos: la recompensa es de la misión elegida en el diario
  if indice and SelectQuestLogEntry then
    local antes = GetQuestLogSelection and GetQuestLogSelection()
    pcall(SelectQuestLogEntry, indice)
    local ok2, v2 = pcall(GetQuestLogRewardXP)
    if antes then pcall(SelectQuestLogEntry, antes) end
    if ok2 and Num(v2) then return v2 end
  end
  return 0
end

local function XPCompletadas()
  local total, cuantas = 0, 0
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    local n = Num(C_QuestLog.GetNumQuestLogEntries()) or 0
    for i = 1, n do
      local info = C_QuestLog.GetInfo(i)
      if type(info) == "table" and not info.isHeader and info.questID and Completa(info.questID, i) then
        total = total + XPDeMision(info.questID, i); cuantas = cuantas + 1
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    local n = GetNumQuestLogEntries() or 0
    for i = 1, n do
      local _, _, _, cabecera, _, _, completa, id = GetQuestLogTitle(i)
      if not cabecera and id and (completa == 1 or completa == true) then
        total = total + XPDeMision(id, i); cuantas = cuantas + 1
      end
    end
  end
  return total, cuantas
end
GL.XPCompletadas, GL.XPDeMision = XPCompletadas, XPDeMision

------------------------------------------------------------------------
-- La barra
------------------------------------------------------------------------
local barra
local mini = {}   -- barras pequeñas (ventana compacta y franja)
local function Capa(padre, nivel, r, g, b, a)
  local t = padre:CreateTexture(nil, "ARTWORK", nil, nivel)
  t:SetTexture(BLANCO8)
  t:SetVertexColor(r, g, b, a or 1)
  t:SetPoint("TOP", padre, "TOP", 0, -1)
  t:SetPoint("BOTTOM", padre, "BOTTOM", 0, 1)
  return t
end

local function Construir(padre, nombre, alto)
  local barra = CreateFrame("Frame", nombre, padre, PLANTILLA)
  barra:SetHeight(alto or 34)
  barra.fondo = CreateFrame("Frame", nil, barra, PLANTILLA)   -- el fondo que se ve solo en combate
  barra.fondo:SetPoint("TOPLEFT", barra, "TOPLEFT", -6, 5)
  barra.fondo:SetPoint("BOTTOMRIGHT", barra, "BOTTOMRIGHT", 6, -3)
  GL.Caja(barra.fondo, { 0.082, 0.090, 0.122, 0.82 }, { 0.165, 0.176, 0.227, 1 })
  barra.fondo:SetFrameLevel(math.max(0, barra:GetFrameLevel() - 1))
  barra.fondo:Hide()

  local b = CreateFrame("Frame", nil, barra, PLANTILLA)
  b:SetPoint("TOPLEFT", barra, "TOPLEFT", 0, 0)
  b:SetPoint("TOPRIGHT", barra, "TOPRIGHT", 0, 0)
  b:SetHeight(math.min(16, alto or 16))
  GL.Caja(b, { 0.04, 0.045, 0.06, 0.95 }, { 0.165, 0.176, 0.227, 1 })
  barra.b = b
  barra.xp = Capa(b, 1, COL.xp[1], COL.xp[2], COL.xp[3])
  barra.xp:SetPoint("LEFT", b, "LEFT", 1, 0)
  if barra.xp.SetGradient and CreateColor then
    pcall(barra.xp.SetGradient, barra.xp, "VERTICAL", CreateColor(COL.xp2[1], COL.xp2[2], COL.xp2[3], 1), CreateColor(COL.xp[1], COL.xp[2], COL.xp[3], 1))
  end
  barra.mision = Capa(b, 2, COL.mision[1], COL.mision[2], COL.mision[3], 0.85)
  -- rayas finas sobre lo de las misiones, como en la maqueta
  barra.rayas = {}
  barra.descansada = Capa(b, 0, COL.descansada[1], COL.descansada[2], COL.descansada[3], 0.40)
  barra.brillo = Capa(b, 4, 1, 1, 1, 0.85)   -- 9.0: el trozo nuevo brilla al ganar XP
  barra.brillo:Hide()
  barra.marcas = {}
  for i = 1, 9 do
    local m = b:CreateTexture(nil, "ARTWORK", nil, 3)
    m:SetColorTexture(1, 1, 1, 0.12)
    m:SetWidth(1)
    m:SetPoint("TOP", b, "TOP", 0, -1)
    m:SetPoint("BOTTOM", b, "BOTTOM", 0, 1)
    barra.marcas[i] = m
  end
  local function T(alin)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetJustifyH(alin)
    t:SetShadowOffset(1, -1)
    t:SetShadowColor(0, 0, 0, 1)
    if t.SetWordWrap then t:SetWordWrap(false) end
    return t
  end
  barra.izq = T("LEFT"); barra.izq:SetPoint("LEFT", b, "LEFT", 6, 0)
  barra.centro = T("CENTER"); barra.centro:SetPoint("CENTER", b, "CENTER", 0, 0)
  barra.der = T("RIGHT"); barra.der:SetPoint("RIGHT", b, "RIGHT", -6, 0)
  barra.pie = barra:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  barra.pie:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -3)
  barra.pie:SetJustifyH("RIGHT")
  barra.combate = barra:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  barra.combate:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0, 3)
  barra.combate:SetText(L"|cffff5050COMBATE|r")
  barra.combate:Hide()
  barra:EnableMouse(true)
  barra:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.datos then return end
    local d = self.datos
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L"Experiencia · nivel " .. d.nivel, 1, 0.82, 0)
    GameTooltip:AddLine(Miles(d.actual) .. L" de " .. Miles(d.maximo) .. L"  (te faltan " .. Miles(d.maximo - d.actual) .. ")", 1, 1, 1)
    GameTooltip:AddLine(COL.misionTexto .. L"Misiones completadas sin entregar: " .. d.cuantas .. " · +" .. Miles(d.mision) .. L" XP|r", 1, 1, 1)
    GameTooltip:AddLine(COL.descansadaTexto .. L"Descansada: " .. Miles(d.desc) .. L" XP|r", 1, 1, 1)
    if d.subira then GameTooltip:AddLine(L"|cff40d959Al entregarlas subes al nivel " .. (d.nivel + 1) .. "|r", 1, 1, 1) end
    GameTooltip:Show()
  end)
  barra:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return barra
end
GL.ConstruirBarraXP = function(padre, alto)
  local b = Construir(padre, nil, alto or 16)
  b.pie:Hide(); b.combate:Hide()
  table.insert(mini, b)
  return b
end

local function CrearBarraXP()
  local f = GL.frame
  if barra or not f then return end
  barra = Construir(f, "GuiaAventureroBarraXP", 34)
  barra.Colocar = function()
    barra:SetParent(GL.frame)
    barra:ClearAllPoints()
    barra:SetPoint("TOPLEFT", GL.frame, "TOPLEFT", GL.IZQ, -8)
    barra:SetPoint("TOPRIGHT", GL.frame, "TOPRIGHT", -64, -8)
    barra:SetFrameStrata(GL.frame:GetFrameStrata() or "MEDIUM")
  end
  barra.Colocar()
end

local ultimaXP
local function Pintar(barra, d, brillar)
  local ancho = (barra.b:GetWidth() or 0) - 2
  local actual, maximo, mision, desc = d.actual, d.maximo, d.mision, d.desc
  local f1 = math.min(1, actual / maximo)
  local f2 = math.min(1, (actual + mision) / maximo)
  local f3 = math.min(1, (actual + mision + desc) / maximo)
  local function Tramo(t, desde, hasta)
    t:ClearAllPoints()
    t:SetPoint("TOP", barra.b, "TOP", 0, -1); t:SetPoint("BOTTOM", barra.b, "BOTTOM", 0, 1)
    t:SetPoint("LEFT", barra.b, "LEFT", 1 + ancho * desde, 0)
    t:SetWidth(math.max(1, ancho * (hasta - desde)))
  end
  if ancho > 0 then
    barra.xp:SetWidth(math.max(1, ancho * f1))
    barra.xp:SetVertexColor(COL.xp[1], COL.xp[2], COL.xp[3], 1)
    Tramo(barra.mision, f1, f2); GL.Mostrar(barra.mision, f2 > f1)
    barra.mision:SetVertexColor(COL.mision[1], COL.mision[2], COL.mision[3], 0.85)
    Tramo(barra.descansada, f2, f3); GL.Mostrar(barra.descansada, f3 > f2)
    barra.descansada:SetVertexColor(COL.descansada[1], COL.descansada[2], COL.descansada[3], 0.40)
    for i = 1, 9 do
      barra.marcas[i]:ClearAllPoints()
      barra.marcas[i]:SetPoint("TOP", barra.b, "TOP", 0, -1); barra.marcas[i]:SetPoint("BOTTOM", barra.b, "BOTTOM", 0, 1)
      barra.marcas[i]:SetPoint("LEFT", barra.b, "LEFT", 1 + ancho * i / 10, 0)
    end
    -- 9.0: el trozo recién ganado brilla y se apaga (Ajustes › Efectos › Brillo en la barra)
    if brillar and Si("brilloBarra") then
      local d0 = math.min(f1, brillar / maximo)
      Tramo(barra.brillo, d0, f1)
      barra.brillo:SetAlpha(0.85); barra.brillo:Show()
      barra.brilloT = 0
      barra:SetScript("OnUpdate", function(self, dt)
        self.brilloT = (self.brilloT or 0) + dt
        local a = 0.85 * (1 - self.brilloT / 0.9)
        if a <= 0 then self.brillo:Hide(); self:SetScript("OnUpdate", nil) else self.brillo:SetAlpha(a) end
      end)
    end
  end
  local p1, p2 = actual / maximo * 100, math.min(100, (actual + mision) / maximo * 100)
  barra.izq:SetText(C.BLANCO .. L"Nivel " .. d.nivel .. C.FIN)
  barra.centro:SetText(Miles(actual) .. " / " .. Miles(maximo) .. C.GRIS .. " (" .. Miles(maximo - actual) .. ")" .. C.FIN)
  barra.der:SetText(Porcentaje(p1) .. " %" .. (mision > 0 and (C.GRIS .. " (" .. Porcentaje(p2) .. " %)" .. C.FIN) or ""))
  -- con poco ancho, el centro se quita para que no se pisen los textos; en la barrita de la franja, ninguno
  local fina = (barra.b:GetHeight() or 16) < 10
  GL.Mostrar(barra.centro, not fina and (barra.b:GetWidth() or 0) >= 300)
  GL.Mostrar(barra.izq, not fina); GL.Mostrar(barra.der, not fina)
  barra.pie:SetText(C.GRIS .. L"Completadas " .. C.FIN .. COL.misionTexto .. Porcentaje(mision / maximo * 100) .. " %|r" ..
    C.GRIS .. L"  ·  Descansada " .. C.FIN .. COL.descansadaTexto .. Porcentaje(desc / maximo * 100) .. " %|r")
  barra.datos = d
end

local function RefrescarBarraXP()
  if not barra then return end
  local nivel = Num(UnitLevel and UnitLevel("player")) or 1
  local actual, maximo = Num(GL.Seguro and GL.Seguro(UnitXP and UnitXP("player"))), Num(GL.Seguro and GL.Seguro(UnitXPMax and UnitXPMax("player")))
  local todas = { barra }
  for i = 1, #mini do todas[#todas + 1] = mini[i] end
  if not Si("barraXP") or not actual or not maximo or maximo <= 0 or nivel >= NIVEL_MAX then
    for i = 1, #todas do todas[i]:Hide(); todas[i].datos = nil end
    return
  end
  local mision, cuantas = 0, 0
  local okM, m, c = pcall(XPCompletadas)
  if okM then mision, cuantas = m or 0, c or 0 end
  local desc = Num(GetXPExhaustion and GetXPExhaustion()) or 0
  local d = { nivel = nivel, actual = actual, maximo = maximo, mision = mision, cuantas = cuantas, desc = desc,
    subira = actual + mision >= maximo }
  local brillar = (ultimaXP and ultimaXP.nivel == nivel and actual > ultimaXP.actual) and ultimaXP.actual or nil
  ultimaXP = { nivel = nivel, actual = actual }
  for i = 1, #todas do
    todas[i]:Show()
    Pintar(todas[i], d, brillar)
  end
end
GL.RefrescarBarraXP = function() Probar(RefrescarBarraXP, L"barra de XP") end

------------------------------------------------------------------------
-- Durante el combate: si el modo discreto oculta la ventana, la barra se queda sola en el mismo sitio
------------------------------------------------------------------------
local enCombate = false
local function BarraACombate(si)
  if not barra then return end
  if si then
    if enCombate or not barra:IsShown() then return end
    local izq, arriba = barra:GetLeft(), barra:GetTop()
    local ancho = barra:GetWidth()
    if not (izq and arriba and ancho) then return end
    local escala = (GL.frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    enCombate = true
    barra:SetParent(UIParent)
    barra:ClearAllPoints()
    barra:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", izq * escala, arriba * escala)
    barra:SetWidth(ancho * escala)
    barra:SetScale(GL.frame:GetScale() or 1)
    barra:SetFrameStrata("MEDIUM")
    barra.fondo:Show()
    barra.combate:Show()
    barra:EnableMouse(false)
    barra:Show()
  else
    if not enCombate then return end
    enCombate = false
    barra.fondo:Hide()
    barra.combate:Hide()
    barra:SetScale(1)
    barra:EnableMouse(true)
    barra.Colocar()
    RefrescarBarraXP()
  end
end

local original = GL.ModoDiscretoCombate
GL.ModoDiscretoCombate = function(entra)
  local estabaVisible = GL.frame and GL.frame:IsShown()
  if entra and estabaVisible and Si("xpEnCombate") and (DB().discretoCombate == true) then Probar(BarraACombate, L"barra en combate", true) end
  if original then original(entra) end
  if not entra then Probar(BarraACombate, L"barra en combate", false) end
end


------------------------------------------------------------------------
-- 9.0: tres tamaños de ventana. Completa, compacta (barra de XP y el paso) y franja (una línea con el paso y
-- la distancia). El botón de tamaño de la barra lateral y el doble clic en el retrato van pasando de uno a otro.
------------------------------------------------------------------------
local franja
local function Distancia(d)
  if not d or not GL.Vector then return nil end
  local ok, _, _, dist = pcall(GL.Vector, d)
  if ok and Num(dist) then return dist end
  return nil
end
local function TextoDistancia(yd)
  if not yd then return "" end
  local m = yd * 0.9144
  if m >= 1000 then return GL.FormatoDecimal(string.format(L"%.1f km", m / 1000)) end
  return math.floor(m + 0.5) .. " m"
end

local function RefrescarFranja()
  if not franja or not franja:IsShown() or not GL.RUTA then return end
  local db = DB()
  local s = GL.RUTA.secciones[db.seccion]
  if not s then return end
  franja.linea1:SetText(string.upper(s.titulo or "") .. L"  ·  PASO " .. (db.paso or 1) .. "/" .. #s.pasos)
  local d = GL.DestinoActual and GL.DestinoActual()
  local texto
  if d and GL.TextoAhora then
    local ok, t = pcall(GL.TextoAhora, d)
    if ok and t then texto = t:gsub(L"^|cff%x%x%x%x%x%xAhora: |r", ""):gsub("|cff%x%x%x%x%x%x  ·  |r.*$", "") end
  end
  if not texto then
    local p = s.pasos[db.paso]
    texto = p and GL.Colorear(p.t or "") or ""
  end
  franja.linea2:SetText(texto)
  local yd = Distancia(d)
  franja.dist:SetText(yd and ("|cff40d959" .. TextoDistancia(yd) .. "|r") or "")
end

local function CrearFranja()
  if franja then return end
  local db = DB()
  franja = CreateFrame("Button", "GuiaAventureroFranja", UIParent, PLANTILLA)
  franja:SetWidth(340); franja:SetHeight(42)
  franja:SetFrameStrata("MEDIUM")
  franja:SetClampedToScreen(true)
  franja:SetMovable(true)
  franja:RegisterForDrag("LeftButton")
  franja:SetScript("OnDragStart", function(self) if not DB().bloqueada then self:StartMoving() end end)
  franja:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    DB().posFranja = { p, rp, x, y }
  end)
  GL.PorTema(function() GL.Caja(franja, GL.COLOR.fondo, GL.COLOR.borde) end)
  if GL.Sombra then pcall(GL.Sombra, franja) end
  if type(db.posFranja) == "table" then
    franja:SetPoint(db.posFranja[1], UIParent, db.posFranja[2], db.posFranja[3], db.posFranja[4])
  else
    franja:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -200)
  end
  local marco = GL.CrearMarcoIcono(franja, 26)
  marco:SetPoint("LEFT", franja, "LEFT", 8, 0)
  GL.PorTema(function() GL.Caja(marco, GL.COLOR.icono, GL.COLOR.acento) end)
  if SetPortraitTexture then pcall(SetPortraitTexture, marco.icono, "player") else GL.PonerIcono(marco.icono, GL.RUTA and GL.RUTA.icono) end
  franja.dist = franja:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  franja.dist:SetPoint("RIGHT", franja, "RIGHT", -34, 0)
  local abrir = GL.CrearBoton(franja, "+", function() GL.PonerTamano("completo") end, nil, 20)
  abrir:SetWidth(20)
  abrir:SetPoint("RIGHT", franja, "RIGHT", -8, 0)
  GL.Ayuda(abrir, L"Ventana completa", L"Vuelve a la ventana grande. Clic en la franja: paso siguiente con Mayúsculas.")
  franja.linea1 = franja:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  franja.linea1:SetPoint("TOPLEFT", marco, "TOPRIGHT", 8, 1)
  franja.linea1:SetPoint("RIGHT", franja.dist, "LEFT", -6, 0)
  franja.linea1:SetJustifyH("LEFT")
  GL.PorTema(function() franja.linea1:SetTextColor(GL.COLOR.acento[1], GL.COLOR.acento[2], GL.COLOR.acento[3]) end)
  franja.linea2 = franja:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  franja.linea2:SetPoint("TOPLEFT", franja.linea1, "BOTTOMLEFT", 0, -2)
  franja.linea2:SetPoint("RIGHT", franja.dist, "LEFT", -6, 0)
  franja.linea2:SetJustifyH("LEFT")
  if franja.linea1.SetWordWrap then franja.linea1:SetWordWrap(false); franja.linea2:SetWordWrap(false) end
  franja:SetScript("OnClick", function()
    if IsShiftKeyDown and IsShiftKeyDown() then GL.Siguiente() else GL.PonerTamano("completo") end
  end)
  franja.t = 0
  franja:SetScript("OnUpdate", function(self, dt)
    self.t = self.t + dt
    if self.t > 0.5 then self.t = 0; Probar(RefrescarFranja, "franja") end
  end)
  -- barrita de XP abajo, sin textos (los datos salen al pasar el ratón)
  if GL.ConstruirBarraXP then
    local bx = GL.ConstruirBarraXP(franja, 4)
    bx:SetPoint("BOTTOMLEFT", franja, "BOTTOMLEFT", 1, 1)
    bx:SetPoint("BOTTOMRIGHT", franja, "BOTTOMRIGHT", -1, 1)
    bx:SetHeight(4)
    bx:EnableMouse(false)
  end
  franja:SetScale(db.escala or 1)
  franja:Hide()
end

function GL.PonerTamano(t)
  local db = DB()
  CrearFranja()
  if t == "compacto" then
    if franja then franja:Hide() end
    db.franja = false
    if GL.EntrarCompacto then GL.EntrarCompacto() end
  elseif t == "franja" then
    if db.compacto and GL.SalirCompacto then GL.SalirCompacto() end
    if GL.frame then GL.frame:Hide() end
    db.franja = true
    franja:Show()
    Probar(RefrescarFranja, "franja")
  else
    db.franja = false
    if franja then franja:Hide() end
    if db.compacto and GL.SalirCompacto then GL.SalirCompacto() end
    db.oculto = false
    if GL.frame then GL.frame:Show() end
  end
  db.tamano = t
end
function GL.SiguienteTamano()
  local db = DB()
  local actual = db.franja and "franja" or (db.compacto and "compacto") or "completo"
  GL.PonerTamano(actual == "completo" and "compacto" or (actual == "compacto" and "franja") or "completo")
end
local alternarAntes = GL.AlternarVentana
function GL.AlternarVentana()
  if DB().franja and franja then
    if franja:IsShown() then franja:Hide() else franja:Show(); Probar(RefrescarFranja, "franja") end
    return
  end
  if alternarAntes then alternarAntes() end
end
GL.comandos = GL.comandos or {}
GL.comandos["franja"] = function() GL.PonerTamano(DB().franja and "completo" or "franja") end
GL.comandos["tamano"] = function() GL.SiguienteTamano() end


------------------------------------------------------------------------
-- 9.0: la ventana se pega a los bordes de la pantalla y debajo del minimapa al soltarla cerca (16 píxeles)
------------------------------------------------------------------------
local IMAN = 16
local function Imanes(f)
  local ui = UIParent
  local escala = (f:GetEffectiveScale() or 1) / (ui:GetEffectiveScale() or 1)
  local izq, der, arriba, abajo = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
  if not (izq and der and arriba and abajo) then return nil end
  izq, der, arriba, abajo = izq * escala, der * escala, arriba * escala, abajo * escala
  local W, H = ui:GetWidth() or 0, ui:GetHeight() or 0
  local x, y, que = nil, nil, nil
  if math.abs(izq) <= IMAN then x = 0; que = "borde" elseif math.abs(W - der) <= IMAN then x = W - (der - izq); que = "borde" end
  if math.abs(H - arriba) <= IMAN then y = H; que = "borde" elseif math.abs(abajo) <= IMAN then y = arriba - abajo; que = "borde" end
  local mm = Minimap and Minimap.GetBottom and Minimap:IsShown() and Minimap
  if mm and mm:GetBottom() then
    local me = (mm:GetEffectiveScale() or 1) / (ui:GetEffectiveScale() or 1)
    local mAbajo, mIzq, mDer = mm:GetBottom() * me, mm:GetLeft() * me, mm:GetRight() * me
    local bajo = mAbajo - 30   -- deja sitio para el texto de la zona del minimapa
    if math.abs(arriba - bajo) <= IMAN * 2 and der > mIzq - IMAN and izq < mDer + IMAN then
      y = bajo; x = x or (W - (der - izq) - 4); que = "minimapa"
    end
  end
  if not que then return nil end
  return (x or izq) / escala, (y or arriba) / escala, que
end

local guia
local function MostrarGuia(f, si)
  if not guia then
    guia = CreateFrame("Frame", nil, UIParent, PLANTILLA)
    guia:SetFrameStrata("HIGH")
    GL.PorTema(function() GL.Caja(guia, { 0, 0, 0, 0 }, GL.COLOR.acento) end)
    guia.texto = guia:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guia.texto:SetPoint("TOPRIGHT", guia, "BOTTOMRIGHT", 0, -3)
  end
  if not si then guia:Hide(); return end
  guia:ClearAllPoints()
  guia:SetAllPoints(f)
  guia:Show()
end

local function Pegable(f, guardar)
  if not f or rawget(f, "gIman") then return end
  f.gIman = true
  f:HookScript("OnDragStart", function(self)
    if DB().imanes == false then return end
    self.gT = 0
    self:SetScript("OnUpdate", function(me, dt)
      me.gT = me.gT + dt
      if me.gT < 0.05 then return end
      me.gT = 0
      local _, _, que = Imanes(me)
      MostrarGuia(me, que ~= nil)
      if guia and que then guia.texto:SetText(que == "minimapa" and L"Se pega bajo el minimapa" or L"Se pega al borde") end
    end)
  end)
  f:HookScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    MostrarGuia(self, false)
    if DB().imanes == false then return end
    local x, y = Imanes(self)
    if x and y then
      self:ClearAllPoints()
      self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
      if guardar then guardar(self) end
    end
  end)
end

------------------------------------------------------------------------
-- Retrato: nivel en la esquina
------------------------------------------------------------------------
local function RefrescarRetrato()
  local ui = GL.ui
  if not ui or not ui.icono or not ui.icono.nivel then return end
  ui.icono.nivel:SetText(tostring(Num(UnitLevel and UnitLevel("player")) or ""))
end

------------------------------------------------------------------------
-- Inicio, eventos y ajustes
------------------------------------------------------------------------
local function Todo()
  Probar(RefrescarBarraXP, L"barra de XP")
  Probar(RefrescarRetrato, "retrato")
  Probar(RefrescarFranja, "franja")
end

table.insert(GL.alIniciar, function()
  CrearBarraXP()
  CrearFranja()
  if DB().franja then GL.PonerTamano("franja") end
  GL.Pegable = Pegable   -- 9.0: también el modo mazmorra
  GL.franja = franja
  Pegable(GL.frame, function(f) local p, _, rp, x, y = f:GetPoint(); DB().pos = { p, rp, x, y } end)
  Pegable(franja, function(f) local p, _, rp, x, y = f:GetPoint(); DB().posFranja = { p, rp, x, y } end)
  Pegable(_G.GuiaAventureroCompacto, function(f) local p, _, rp, x, y = f:GetPoint(); DB().posCompacto = { p, rp, x, y } end)
  -- el botón de la barra lateral que era «modo compacto» ahora va pasando por los tres tamaños
  local ui = GL.ui
  if ui and ui.botonCompacto then
    ui.botonCompacto:SetScript("OnClick", function() GL.SiguienteTamano() end)
    ui.botonCompacto.ayudaTitulo = L"Tamaño de la ventana"
    ui.botonCompacto.ayudaTexto = L"Completa, compacta (barra de XP y el paso) o franja (una línea). También con doble clic en el retrato."
  end
  if ui and ui.icono and ui.icono.SetScript then
    ui.icono:SetScript("OnMouseUp", function(self)
      local t = GetTime and GetTime() or 0
      if self.ultimoClic and t - self.ultimoClic < 0.35 then GL.SiguienteTamano(); self.ultimoClic = nil else self.ultimoClic = t end
    end)
  end
  if GL.frame then GL.frame:HookScript("OnSizeChanged", function() Probar(RefrescarBarraXP, L"barra de XP") end) end
  Todo()
end)
table.insert(GL.trasRefrescar, Todo)

local ev = CreateFrame("Frame")
GL.Evento(ev, "PLAYER_XP_UPDATE")
GL.Evento(ev, "UPDATE_EXHAUSTION")
GL.Evento(ev, "PLAYER_LEVEL_UP")
GL.Evento(ev, "QUEST_LOG_UPDATE")
GL.Evento(ev, "PLAYER_UPDATE_RESTING")
ev:SetScript("OnEvent", function() if barra then Todo() end end)

-- ajustes nuevos (los pinta Opciones.lua si sabe; si no, se quedan con su valor por defecto)
GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "xpEnCombate", "Barra de XP visible en combate",
  "Con «Modo discreto durante el combate», la barra de XP se queda en pantalla aunque la ventana se oculte.",
  function() return Si("xpEnCombate") end, function(v) DB().xpEnCombate = v end, pestana = "general" })
table.insert(GL.ajustesInterfaz, { "imanes", "Pegar la ventana a los bordes",
  "Al soltar la ventana cerca de un borde de la pantalla o bajo el minimapa, se queda pegada y alineada.",
  function() return Si("imanes") end, function(v) DB().imanes = v end, pestana = "general" })

-- 9.0: el tamaño de la ventana, en Ajustes › General (sustituye a la casilla «Modo compacto»)
table.insert(GL.ajustesInterfaz, { "tamano", "Tamaño de la ventana",
  "Completa: todo. Compacta: la XP y el paso. Franja: una línea con el paso y la distancia. También con el botón de abajo de la barra o doble clic en el retrato.",
  function() return DB().tamano or "completo" end, function(v) if GL.PonerTamano then GL.PonerTamano(v) end end,
  pestana = "general", opciones = { { "completo", "Completa" }, { "compacto", "Compacta" }, { "franja", "Franja" } } })
-- 9.0: un solo ajuste para los efectos al cambiar de paso (destello, entrada de la caja y fundido de pestaña)
table.insert(GL.ajustesInterfaz, { "animaciones", "Animaciones",
  "Ninguna: sin efectos. Suaves: la caja entra deslizándose y las pestañas aparecen con un fundido. Todas: además, el destello de la caja al cambiar de paso.",
  function()
    local d = DB()
    local de, tr, fu = d.destello ~= false, d.transicion ~= false, d.fundido ~= false
    if not de and not tr and not fu then return "ninguna" end
    if de and tr and fu then return "todas" end
    return "suaves"
  end,
  function(v)
    local d = DB()
    d.destello = (v == "todas")
    d.transicion = (v ~= "ninguna")
    d.fundido = (v ~= "ninguna")
  end,
  pestana = "efectos", opciones = { { "ninguna", "Ninguna" }, { "suaves", "Suaves" }, { "todas", "Todas" } } })

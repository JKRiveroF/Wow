-- Pestanas96.lua (9.6): piezas para que Talentos, Exploración y Mazmorras se lean como la Guía clara:
-- una tarjeta arriba con lo que toca ahora y lo demás en un desplegable cerrado de serie.
-- Solo con «Guía clara» puesto (Ajustes › Avanzado › Paso); si no, las pestañas quedan como antes.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local MORADO = "|cffa48cff"

local function DB() return GuiaAventureroDB or {} end

function GL.PestanasClaras() return GL.GuiaClaraActiva and GL.GuiaClaraActiva() or false end

------------------------------------------------------------------------
-- Desplegable: una fila con + / - que abre o cierra lo de debajo. Guarda si está abierto en DB()[clave].
------------------------------------------------------------------------
function GL.CrearDesplegable96(panel, clave, alCambiar)
  local d = CreateFrame("Button", nil, panel, PLANTILLA)
  d:SetHeight(24)
  d.signo = d:CreateTexture(nil, "ARTWORK")
  d.signo:SetWidth(14); d.signo:SetHeight(14)
  d.signo:SetPoint("LEFT", d, "LEFT", 8, 0)
  d.der = GL.Texto(d, "GameFontHighlightSmall", "RIGHT")
  d.der:SetPoint("RIGHT", d, "RIGHT", -10, 0)
  d.titulo = GL.Texto(d, "GameFontHighlightSmall")
  d.titulo:SetPoint("LEFT", d.signo, "RIGHT", 6, 0)
  d.titulo:SetPoint("RIGHT", d.der, "LEFT", -8, 0)
  GL.UnaLinea(d.titulo)
  local brillo = d:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.04)
  d.clave = clave
  d:SetScript("OnClick", function(self)
    DB()[self.clave] = (DB()[self.clave] ~= true) or nil
    if alCambiar then alCambiar() end
  end)
  function d:Abierto() return DB()[self.clave] == true end
  -- Coloca la fila en y (desde arriba del panel) y devuelve su alto.
  function d:Pintar(y, titulo, cuenta, ayuda)
    local abierto = self:Abierto()
    self.signo:SetTexture(abierto and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    self.titulo:SetText(MORADO .. titulo .. C.FIN .. (cuenta and (C.GRIS .. "  (" .. cuenta .. ")" .. C.FIN) or ""))
    self.der:SetText(C.GRIS .. (abierto and L"pulsa para cerrar" or L"pulsa para ver") .. C.FIN)
    if GL.Caja then
      if abierto then GL.Caja(self, { 0.64, 0.55, 1, 0.05 }, { 0.64, 0.55, 1, 0.55 })
      else GL.Caja(self, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.10 }) end
    end
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
    self:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
    self:Show()
    return 24
  end
  d:Hide()
  return d
end

------------------------------------------------------------------------
-- Tarjeta: título, texto a la derecha, unas líneas y hasta dos botones abajo a la derecha.
------------------------------------------------------------------------
function GL.CrearTarjeta96(panel, actual)
  local t = CreateFrame("Frame", nil, panel, PLANTILLA)
  if GL.Caja and GL.COLOR then GL.Caja(t, GL.COLOR.caja or { 1, 1, 1, 0.04 }, GL.COLOR.cajaBorde or { 1, 1, 1, 0.10 }) end
  if actual then   -- el borde morado de la izquierda, como el paso al que va la flecha
    local raya = t:CreateTexture(nil, "ARTWORK")
    raya:SetWidth(3)
    raya:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
    raya:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
    raya:SetColorTexture(0.55, 0.42, 1.0, 1)
  end
  t.titulo = GL.Texto(t, "GameFontNormal")
  t.titulo:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -8)
  t.der = GL.Texto(t, "GameFontHighlightSmall", "RIGHT")
  t.der:SetPoint("TOPRIGHT", t, "TOPRIGHT", -10, -10)
  t.titulo:SetPoint("RIGHT", t.der, "LEFT", -8, 0)
  GL.UnaLinea(t.titulo)
  t.texto = GL.Texto(t, "GameFontHighlightSmall")
  t.texto:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -28)
  if t.texto.SetSpacing then t.texto:SetSpacing(2) end
  t.botones = {}
  for i = 1, 2 do
    local b = GL.CrearBoton(t, "", function(self) if self.accion then self.accion() end end, nil, 20, i == 1 and "accion" or nil)
    b:SetWidth(110)
    if i == 1 then b:SetPoint("TOPRIGHT", t, "TOPRIGHT", -10, -26)
    else b:SetPoint("TOPRIGHT", t.botones[1], "BOTTOMRIGHT", 0, -4) end
    b:Hide()
    t.botones[i] = b
  end
  -- botones = { { texto, función, ancho? }, ... }
  function t:Pintar(y, ancho, titulo, der, texto, botones)
    self.titulo:SetText(titulo or "")
    self.der:SetText(der or "")
    local nb = 0
    for i = 1, 2 do
      local b, def = self.botones[i], botones and botones[i]
      if def then
        nb = i
        b.texto:SetText(def[1]); b.accion = def[2]; b:SetWidth(def[3] or 110)
        b:Show()
      else
        b:Hide(); b.accion = nil
      end
    end
    local anchoTexto = math.max(80, (ancho or 360) - 24 - (nb > 0 and 118 or 0))
    self.texto:SetWidth(anchoTexto)
    self.texto:SetText(texto or "")
    local h = 28 + (texto and texto ~= "" and GL.Alto(self.texto, texto, 13, anchoTexto) or 0) + 10
    h = math.max(h, nb == 2 and 80 or (nb == 1 and 56 or 40))
    h = math.floor(h + 0.5)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
    self:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
    self:SetHeight(h)
    self:Show()
    return h
  end
  t:Hide()
  return t
end

------------------------------------------------------------------------
-- Talentos: tarjeta «Ahora» con el talento que toca y el plan completo en un desplegable
------------------------------------------------------------------------
local tal = {}

local function NombreTalento(t) return string.match(t.nombre or "", "^(.-)%s*%(.-%)%s*$") or t.nombre or "?" end

-- Talento del plan para un nivel: el que cubre ese nivel o, si ninguno, el siguiente.
local function TalentoDeNivel(plan, nivel)
  for i, t in ipairs(plan) do
    if t.h and t.h >= nivel then return t, i end
  end
  return nil
end
GL._TalentoDeNivel = TalentoDeNivel   -- para las pruebas

local function Icono(icono)
  if not icono then return "" end
  return "|T" .. tostring(icono) .. ":16:16:0:0|t "
end

-- Pinta la tarjeta y el desplegable desde y. Devuelve la y de debajo y si el plan está abierto.
function GL.PintarTalentoAhora(panel, y, ancho, refrescar)
  local R = GL.RUTA
  local plan = R and R.talentos or {}
  if not tal.tarjeta then
    tal.tarjeta = GL.CrearTarjeta96(panel, true)
    tal.desp = GL.CrearDesplegable96(panel, "talPlanAbierto", refrescar)
  end
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  local libres = GL.PuntosTalentoLibres and GL.PuntosTalentoLibres() or nil
  local titulo, texto, botones
  local t = TalentoDeNivel(plan, math.max(10, nivel))
  -- 9.7.4: si el juego deja leer tu árbol, manda lo que tienes puesto: lo que ya pusiste (antes de tiempo
  -- o en otro orden) no se vuelve a pedir y el siguiente es la primera fila del plan que aún te falta.
  local real = GL.EstadoTalentosReal and GL.EstadoTalentosReal() or nil
  local function Siguiente(desde)
    if not real then return nil end
    for i = desde or 1, #plan do if not real.hecho[i] then return plan[i], i end end
    return nil
  end
  if real then t = real.primero and plan[real.primero] or nil end
  local function Linea(x)
    local pts = x.puntos and (C.GRIS .. "  " .. x.puntos .. C.FIN) or ""
    return Icono(x.icono) .. C.BLANCO .. NombreTalento(x) .. C.FIN .. pts .. "\n" .. C.GRIS .. (x.rama or "") ..
      (x.fila and (L", fila " .. x.fila) or "") .. ". " .. (x.nota or "") .. C.FIN
  end
  local poner = { L"Poner", function() if GL.PonerTalentos then GL.PonerTalentos(true) end; if refrescar then refrescar() end end, 80 }
  if nivel < 10 then
    titulo = C.AMARILLO .. L"Los talentos empiezan al nivel 10." .. C.FIN
    local p = plan[1]
    texto = p and (L"Tu primer punto: " .. Linea(p)) or ""
  elseif libres == 0 then
    local sig = TalentoDeNivel(plan, nivel + 1)
    if real then sig = t end
    titulo = C.VERDE .. L"Nada que poner ahora" .. C.FIN
    texto = sig and (L"Tu siguiente punto llega al nivel " .. (nivel + 1) .. ":\n" .. Linea(sig)) or L"Ya tienes todo el plan."
  elseif t then
    titulo = C.AMARILLO .. ((libres and libres > 0) and (L"Ahora: " .. libres .. (libres == 1 and L" punto libre" or L" puntos libres")) or L"Ahora") .. C.FIN
    local sig = TalentoDeNivel(plan, (t.h or nivel) + 1)
    if real then sig = Siguiente((real.primero or 0) + 1) end
    texto = Linea(t) .. (sig and sig ~= t and ("\n" .. C.GRIS .. L"Siguiente: " .. NombreTalento(sig) ..
      (real and "" or (L" al " .. (sig.d or "?"))) .. "." .. C.FIN) or "")
    botones = { poner }
  else
    titulo = C.VERDE .. L"Ya tienes todo el plan." .. C.FIN
    texto = ""
  end
  local h = tal.tarjeta:Pintar(y, ancho, titulo, C.GRIS .. L"nivel " .. nivel .. C.FIN, texto, botones)
  y = y + h + 8
  y = y + tal.desp:Pintar(y, L"El plan completo, nivel a nivel", #plan) + 6
  return y, tal.desp:Abierto()
end

function GL.OcultarTalentoAhora()
  if tal.tarjeta then tal.tarjeta:Hide() end
  if tal.desp then tal.desp:Hide() end
end

-- Botin.lua (7.5.16): lista de botín con «Todo el botín» y «Útil para ti». La usan los jefes de Mazmorras,
-- los raros de la Biblioteca y, cuando exista, el mapa de la mazmorra (GL.VerBotin desde el icono del jefe).
-- Útil para ti: lo que puedes llevar según tu ruta (tipos de armadura y armas); «▲ mejor» si puntúa más que lo puesto.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local ALTO = 20
local bloques = setmetatable({}, { __mode = "k" })

local function Publico(v)
  if type(issecretvalue) ~= "function" then return true end
  local ok, secreto = pcall(issecretvalue, v)
  return ok and secreto == false
end

local function TextoSeguro(v)
  if Publico(v) and type(v) == "string" and v ~= "" then return v end
end

local function TexturaSegura(v)
  if not Publico(v) then return nil end
  if type(v) == "number" and v > 0 and v < math.huge and v % 1 == 0 then return v end
  return TextoSeguro(v)
end

local function ConsultarInfo(f, id)
  if type(f) ~= "function" then return nil end
  local ok, nombre, enlace, calidad, _, _, _, subtipo, _, ranura, icono = pcall(f, id)
  if not ok then return nil end
  nombre = TextoSeguro(nombre)
  if not nombre then return nil end
  if not Publico(calidad) or type(calidad) ~= "number" or calidad < 0 or calidad >= math.huge or calidad % 1 ~= 0 then calidad = nil end
  return { nombre = nombre, enlace = TextoSeguro(enlace), calidad = calidad, subtipo = TextoSeguro(subtipo), ranura = TextoSeguro(ranura), icono = TexturaSegura(icono) }
end

local function Info(id)
  local moderna = C_Item and C_Item.GetItemInfo
  local info = ConsultarInfo(moderna, id)
  if not info and GetItemInfo ~= moderna then info = ConsultarInfo(GetItemInfo, id) end
  return info
end

local function ConsultarIcono(f, id)
  if type(f) ~= "function" then return nil end
  local ok, t = pcall(f, id)
  if ok then return TexturaSegura(t) end
end

local function Icono(id, info)
  if info and info.icono then return info.icono end
  return ConsultarIcono(C_Item and C_Item.GetItemIconByID, id) or ConsultarIcono(GetItemIcon, id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ColorCalidad(q)
  local c = ITEM_QUALITY_COLORS and q and ITEM_QUALITY_COLORS[q]
  if type(c) == "table" and type(c.hex) == "string" then return c.hex end
  local t = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
  return t[q or 1] or "|cffffffff"
end

-- útil (lo puedes llevar) y mejor (puntúa más que lo que llevas en esa ranura)
local function EsUtil(id, infoConsultada)
  if type(id) ~= "number" or id <= 0 then return false, false end
  local u = GL.EquipoUtil
  local equipo = GL.RUTA and GL.RUTA.equipo
  if not u or not equipo then return false, false end
  local i = infoConsultada
  if i == nil then i = Info(id) end
  local enlace = i and i.enlace
  local info = enlace and u.InfoObjeto(enlace)
  if not info or not u.Usable(info, equipo) then return false, false end
  local ranuras = u.RANURAS and u.RANURAS[info.ranura or ""]
  if not ranuras or not u.PuntuacionEquipada then return true, false end
  local pesos = equipo.pesos or {}
  local suya, mia = u.Puntuar(enlace, info, pesos), u.CosteSustitucion(info, equipo, pesos)
  if mia == nil or suya == nil then return true, false, false end
  return true, suya > mia, suya < mia   -- 9.4.2: también si es peor que lo que llevas
end
GL.BotinUtil = EsUtil

local function CrearFila(b)
  local f = CreateFrame("Button", nil, b)
  f:SetHeight(ALTO)
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.06)
  f.icono = f:CreateTexture(nil, "ARTWORK")
  f.icono:SetWidth(16); f.icono:SetHeight(16)
  f.icono:SetPoint("LEFT", f, "LEFT", 2, 0)
  f.pct = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
  f.pct:SetPoint("RIGHT", f, "RIGHT", -2, 0)
  f.pct:SetWidth(40)
  f.nombre = GL.Texto(f, "GameFontHighlightSmall")
  f.nombre:SetPoint("LEFT", f.icono, "RIGHT", 5, 0)
  f.nombre:SetPoint("RIGHT", f.pct, "LEFT", -4, 0)
  GL.UnaLinea(f.nombre)
  f:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f:SetScript("OnClick", function(self)
    if self.enlace and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.enlace) end
  end)
  return f
end

-- Bloque de botín dentro de otro marco. b:Mostrar(objetos) devuelve su alto.
GL.CrearBloqueBotin = function(padre)
  local b = CreateFrame("Frame", nil, padre, PLANTILLA)
  if GL.Caja then GL.Caja(b, { 0, 0, 0, 0.35 }, { 1, 1, 1, 0.08 }) end
  bloques[b] = true
  b.modo, b.filas, b.objetos = "todo", {}, {}
  local function Cambiar(modo)
    b.modo = modo
    if b.alCambiar then b.alCambiar() else b:Mostrar(b.objetos) end
  end
  b.todo = GL.CrearBoton(b, L"Todo el botín", function() Cambiar("todo") end, nil, 18)
  b.todo:SetWidth(112)
  b.todo:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -5)
  b.util = GL.CrearBoton(b, L"Útil para ti", function() Cambiar("util") end, nil, 18)
  b.util:SetWidth(112)
  b.util:SetPoint("LEFT", b.todo, "RIGHT", 4, 0)
  b.vacio = GL.Texto(b, "GameFontHighlightSmall")
  b.vacio:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -28)
  b.vacio:SetPoint("RIGHT", b, "RIGHT", -6, 0)
  -- 9.4.2: como mucho MAX_FILAS a la vez; el resto con la rueda (el botín de una banda tiene casi 200 objetos)
  local MAX_FILAS = 22
  b.desde = 0
  b:EnableMouseWheel(true)
  b:SetScript("OnMouseWheel", function(self, delta)
    self.desde = math.max(0, (self.desde or 0) - delta * 3)
    if self.alCambiar then self.alCambiar() else self:Mostrar(self.objetos) end
  end)
  b.Mostrar = function(self, objetos)
    if objetos ~= self.objetos then self.desde = 0 end
    self.objetos = objetos or {}
    local lista, utiles = {}, 0
    for i = 1, #self.objetos do
      local o = self.objetos[i]
      local util, mejor, peor = false, false, false
      local info
      if o.id then
        info = Info(o.id) or false
        util, mejor, peor = EsUtil(o.id, info)
      end
      if util then utiles = utiles + 1 end
      if self.modo == "todo" or util then table.insert(lista, { o = o, mejor = mejor, peor = peor, info = info }) end
    end
    self.todo.texto:SetText(L"Todo el botín (" .. #self.objetos .. ")")
    self.util.texto:SetText(L"Útil para ti (" .. utiles .. ")")
    self.todo:SetActivo(self.modo == "todo"); self.util:SetActivo(self.modo == "util")
    for i = 1, #self.filas do self.filas[i]:Hide() end
    local y = -27
    self.desde = math.max(0, math.min(self.desde or 0, #lista - MAX_FILAS))
    local completa = lista
    lista = {}
    for i = self.desde + 1, math.min(#completa, self.desde + MAX_FILAS) do table.insert(lista, completa[i]) end
    for i = 1, #lista do
      local f = self.filas[i]
      if not f then f = CrearFila(self); self.filas[i] = f end
      local o = lista[i].o
      local info = lista[i].info
      f.id, f.enlace = o.id, info and info.enlace
      f.icono:SetTexture(o.id and Icono(o.id, info) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local tipo = info and ((info.ranura and info.ranura ~= "" and _G[info.ranura]) or info.subtipo) or nil
      f.nombre:SetText((info and (ColorCalidad(info.calidad) .. info.nombre .. C.FIN) or (o.n and ("|cffffffff" .. o.n .. C.FIN)) or (C.GRIS .. L"Objeto " .. tostring(o.id or "?") .. C.FIN)) ..
        (type(tipo) == "string" and (C.GRIS .. "  " .. tipo .. C.FIN) or "") .. (o.origen977 and (C.GRIS .. " — " .. L(o.origen977) .. C.FIN) or "") .. (lista[i].mejor and (C.VERDE .. L"  ▲ mejor" .. C.FIN) or "") .. (lista[i].peor and ("|cfff05050" .. L"  ▼ peor" .. C.FIN) or ""))
      f.pct:SetText(C.GRIS .. (o.p and (o.p .. " %") or "") .. C.FIN)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", self, "TOPLEFT", 4, y)
      f:SetPoint("TOPRIGHT", self, "TOPRIGHT", -4, y)
      f:Show()
      y = y - ALTO
    end
    local txt = ""
    if #self.objetos == 0 then txt = C.GRIS .. L"No se conoce botín propio confirmado. El contenido de Forever pendiente de verificar se incorporará en próximas versiones." .. C.FIN
    elseif #lista == 0 then txt = C.GRIS .. L"Nada útil para tu clase." .. C.FIN
    elseif #completa > MAX_FILAS then
      txt = C.GRIS .. (self.desde + 1) .. "-" .. (self.desde + #lista) .. L" de " .. #completa .. L" (rueda del ratón)" .. C.FIN
    end
    self.vacio:ClearAllPoints()   -- 9.4.2: debajo de las filas (con la rueda, aquí va «1-22 de 192»)
    self.vacio:SetPoint("TOPLEFT", self, "TOPLEFT", 8, y - 1)
    self.vacio:SetPoint("RIGHT", self, "RIGHT", -6, 0)
    self.vacio:SetText(txt)
    if txt ~= "" then y = y - 16 end
    local alto = -y + 6
    self:SetHeight(alto)
    return alto
  end
  return b
end

-- Ventana suelta (raros de la Biblioteca y, más adelante, el icono del jefe en el mapa de la mazmorra)
local ven = nil
GL.VerBotin = function(titulo, objetos)
  if not ven then
    ven = CreateFrame("Frame", "GuiaAventureroBotin", UIParent, PLANTILLA)
    ven:SetWidth(300); ven:SetHeight(120)
    ven:SetFrameStrata("DIALOG")
    ven:SetMovable(true); ven:EnableMouse(true)
    if ven.SetClampedToScreen then ven:SetClampedToScreen(true) end   -- 9.4
    ven:RegisterForDrag("LeftButton")
    ven:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ven:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "GuiaAventureroBotin") end   -- 9.7.6: Esc la cierra
    if GL.Caja and GL.COLOR then GL.Caja(ven, { 0.04, 0.05, 0.07, 0.97 }, GL.COLOR.botonBorde) end
    if GL.Acento then GL.Acento(ven, 2) end
    ven.titulo = GL.Texto(ven, "GameFontNormal")
    ven.titulo:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -9)
    ven.cerrar = GL.CrearBoton(ven, "x", function() ven:Hide() end, nil, 18, "cerrar")
    ven.cerrar:SetWidth(18)
    ven.cerrar:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -4, -4)
    ven.bloque = GL.CrearBloqueBotin(ven)
    ven.bloque:SetPoint("TOPLEFT", ven, "TOPLEFT", 8, -28)
    ven.bloque:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -8, -28)
    ven.bloque.alCambiar = function() ven:SetHeight(36 + ven.bloque:Mostrar(ven.bloque.objetos)) end
  end
  ven.titulo:SetText(titulo or L"Botín")
  ven:ClearAllPoints()
  local grande = GL._mapaMazmorra and GL._mapaMazmorra()   -- 9.4: con el mapa grande abierto, a su derecha
  if grande and grande.grande and grande:IsShown() then ven:SetPoint("TOPLEFT", grande, "TOPRIGHT", 8, 0)
  elseif GL.frame and GL.frame:IsShown() then ven:SetPoint("TOPLEFT", GL.frame, "TOPRIGHT", 8, -60)
  else ven:SetPoint("CENTER", UIParent, "CENTER", 0, 60) end
  ven:SetHeight(36 + ven.bloque:Mostrar(objetos))
  ven:Show()
  return ven
end

-- 9.4.2: el juego carga los objetos poco a poco; cuando llegan, la ventana se vuelve a pintar con sus nombres
local evBotin = CreateFrame("Frame")
local pendienteBotin = false
local bloquesPendientes = {}
if GL.Evento then GL.Evento(evBotin, "GET_ITEM_INFO_RECEIVED") else pcall(evBotin.RegisterEvent, evBotin, "GET_ITEM_INFO_RECEIVED") end
evBotin:SetScript("OnEvent", function(_, _, id, exito)
  -- Un evento de otro objeto no necesita repintar los paneles de botín.
  if not Publico(id) then id = nil end
  if not Publico(exito) then exito = nil end
  if exito == false then return end
  local filtrar = type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0
  local visible = false
  for b in pairs(bloques) do
    if b:IsVisible() then
      local afectado = not filtrar
      if filtrar then
        for _, o in ipairs(b.objetos or {}) do
          if o.id == id then afectado = true; break end
        end
      end
      if afectado then bloquesPendientes[b] = true; visible = true end
    end
  end
  if not visible or pendienteBotin then return end
  pendienteBotin = true
  local function Pintar()
    pendienteBotin = false
    local afectados = bloquesPendientes
    bloquesPendientes = {}
    for b in pairs(afectados) do
      if b:IsVisible() then
        if b.alCambiar then pcall(b.alCambiar) else pcall(b.Mostrar, b, b.objetos) end
      end
    end
  end
  if C_Timer and type(C_Timer.After) == "function" then
    if pcall(C_Timer.After, 0.5, Pintar) then return end
  end
  Pintar()
end)

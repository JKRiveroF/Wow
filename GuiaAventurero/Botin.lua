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

local function IdValido(v)
  return Publico(v) and type(v) == "number" and v > 0 and v < math.huge and v % 1 == 0
end

-- Una fila sin ID conserva su nombre, pero nunca se convierte en un enlace inventado.
-- Solo se eliminan duplicados exactos: un mismo objeto con otro origen o tasa sigue siendo otra asociación.
function GL.NormalizarBotin977(objetos)
  local out, grupos = {}, {}
  if type(objetos) ~= "table" then return out end
  for _, o in ipairs(objetos) do
    if type(o) == "table" and (IdValido(o.id) or TextoSeguro(o.n)) then
      local fila = {}
      for k,v in pairs(o) do fila[k] = v end
      if not IdValido(fila.id) then fila.id = nil; fila.pendiente977 = true end
      if not Publico(fila.p) or type(fila.p) ~= "number" or not (fila.p >= 0 and fila.p <= 100) then fila.p = nil end
      local clave = fila.id or fila.n
      local grupo = grupos[clave] or {}; grupos[clave] = grupo
      local repetida = false
      for _, anterior in ipairs(grupo) do
        local igual = true
        for k,v in pairs(fila) do if anterior[k] ~= v then igual = false; break end end
        if igual then for k,v in pairs(anterior) do if fila[k] ~= v then igual = false; break end end end
        if igual then repetida = true; break end
      end
      if not repetida then grupo[#grupo+1] = fila; out[#out+1] = fila end
    end
  end
  return out
end

function GL.BotinesDeJefes977(jefes)
  local out = {}
  for _, j in ipairs(jefes or {}) do
    for _, o in ipairs(GL.NormalizarBotin977(j.botin)) do
      o.origenGrupo977 = j.n
      out[#out+1] = o
    end
  end
  return GL.NormalizarBotin977(out)
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

-- La etiqueta visible puede usar el catálogo; el enlace y tooltip siguen siendo nativos.
local function NombreBotinR11(o, info)
  local nativo = info and TextoSeguro(info.nombre)
  local base = TextoSeguro(o.nombreOriginal977) or TextoSeguro(o.n)
  if GL.ingles == GL.clienteIngles and nativo then return nativo end
  if base then
    local traducido = L(base)
    if not GL.ingles or traducido ~= base then return traducido end
    if nativo and GL.clienteIngles then return nativo end
    if GL.ingles then return (nativo or base) .. " (" .. L"traducción sin confirmar" .. ")" end
    return base
  end
  if nativo then
    return nativo .. (GL.ingles ~= GL.clienteIngles and (" (" .. L"idioma del cliente" .. ")") or "")
  end
  return L"Objeto " .. tostring(o.id or "?")
end
GL.NombreBotinR11 = NombreBotinR11

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
local function EvaluarBotin(id, infoConsultada)
  if not IdValido(id) then return false, false end
  local u = GL.EquipoUtil
  local equipo = GL.RUTA and GL.RUTA.equipo
  if not u or not equipo then return false, false, false, false, "perfil" end
  local i = infoConsultada
  if i == nil then i = Info(id) end
  local enlace = i and i.enlace
  local info = enlace and u.InfoObjeto(enlace)
  if not info then return false, false, false, true end
  local nivel = type(UnitLevel) == "function" and UnitLevel("player") or nil
  if not IdValido(nivel) then return false, false, false, false, "nivel" end
  if not u.Usable(info, equipo, nivel) then return false, false end
  local requisitos = u.RequisitosEspeciales and u.RequisitosEspeciales(enlace, info)
  if requisitos == false then return false, false end
  local aviso = requisitos ~= true and "requisitos" or nil
  local ranuras = u.RANURAS and u.RANURAS[info.ranura or ""]
  if not ranuras or not u.CosteSustitucion or not u.DiferenciaEquipo then return true, false, false, false, aviso or "comparacion" end
  local pesos = equipo.pesos or {}
  local suya = u.Puntuar(enlace, info, pesos)
  local mia, _, piezas = u.CosteSustitucion(info, equipo, pesos)
  if u.ComparacionParcial and u.ComparacionParcial(info, piezas) then return true, false, false, false, "parcial" end
  local dif = u.DiferenciaEquipo(suya, mia)
  if dif == nil then return true, false, false, false, aviso or "comparacion" end
  return true, dif > 0, dif < 0, false, aviso
end
local function EsUtil(id, infoConsultada)
  local ok, util, mejor, peor, pendiente, aviso = pcall(EvaluarBotin, id, infoConsultada)
  if not ok then return false, false, false, false, "comparacion" end
  return util, mejor, peor, pendiente, aviso
end
local function AvisoBotin(aviso)
  if aviso == "requisitos" then return L"Requisitos especiales sin confirmar" end
  if aviso == "parcial" then return L"Estadísticas o efectos sin valorar" end
  if aviso == "nivel" then return L"Nivel del personaje sin confirmar" end
  if aviso == "perfil" then return L"Perfil de equipo no disponible" end
  if aviso == "comparacion" then return L"Comparación de equipo no disponible" end
end
GL.AvisoBotin977 = AvisoBotin
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
    if not GameTooltip or not self.objeto then return end
    local o = self.objeto
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.id then
      if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
    elseif GameTooltip.SetText then GameTooltip:SetText(NombreBotinR11(o)) end
    if o.origenGrupo977 then GameTooltip:AddLine(L(o.origenGrupo977), 1, 1, 1, true) end
    if o.origen977 then GameTooltip:AddLine(L(o.origen977), 1, 1, 1, true) end
    if o.pendiente977 then GameTooltip:AddLine(L"Asociación pendiente de contraste", 1, 0.8, 0, true) end
    if self.aviso then GameTooltip:AddLine(AvisoBotin(self.aviso), 1, 0.8, 0, true) end
    if o.mision977 then GameTooltip:AddLine(L"Objeto de misión", 1, 1, 1, true) end
    if not self.id then GameTooltip:AddLine(L"Identificador de objeto sin confirmar.", 1, 0.8, 0, true) end
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
    if objetos ~= self.objetos and objetos ~= self.fuenteObjetos then self.desde = 0 end
    if objetos ~= self.objetos then self.fuenteObjetos = objetos end
    self.objetos = GL.NormalizarBotin977(objetos)
    local lista, utiles, pendientes, sinID, sinComparar = {}, 0, 0, 0, 0
    for i = 1, #self.objetos do
      local o = self.objetos[i]
      local util, mejor, peor = false, false, false
      local info, aviso
      if o.id then
        info = Info(o.id) or false
        local pendiente
        util, mejor, peor, pendiente, aviso = EsUtil(o.id, info)
        if pendiente or not info or not info.enlace then pendientes = pendientes + 1 end
        if aviso and not util then sinComparar = sinComparar + 1 end
      end
      if not o.id then sinID = sinID + 1 end
      if o.mision977 then mejor, peor = false, false end
      if util then utiles = utiles + 1 end
      if self.modo == "todo" or util then table.insert(lista, { o = o, mejor = mejor, peor = peor, info = info, aviso = aviso }) end
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
      f.id, f.enlace, f.objeto, f.aviso = o.id, info and info.enlace, o, lista[i].aviso
      f.icono:SetTexture(o.id and Icono(o.id, info) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local tipo = info and ((info.ranura and info.ranura ~= "" and _G[info.ranura]) or info.subtipo) or nil
      f.nombre:SetText((info and (ColorCalidad(info.calidad) .. NombreBotinR11(o, info) .. C.FIN) or (o.n and ("|cffffffff" .. NombreBotinR11(o) .. C.FIN)) or (C.GRIS .. L"Objeto " .. tostring(o.id or "?") .. C.FIN)) ..
        (type(tipo) == "string" and (C.GRIS .. "  " .. tipo .. C.FIN) or "") .. (o.origenGrupo977 and (C.GRIS .. " — " .. L(o.origenGrupo977) .. C.FIN) or "") .. (o.origen977 and (C.GRIS .. " — " .. L(o.origen977) .. C.FIN) or "") .. (o.pendiente977 and (C.AMARILLO .. " [?]" .. C.FIN) or "") .. (o.mision977 and (C.GRIS .. " — " .. L"Objeto de misión" .. C.FIN) or "") .. (lista[i].aviso and (C.AMARILLO .. " — " .. AvisoBotin(lista[i].aviso) .. C.FIN) or "") .. (lista[i].mejor and ((lista[i].aviso and C.AMARILLO .. " · " .. L"posible mejora" or C.VERDE .. L"  ▲ mejor") .. C.FIN) or "") .. (lista[i].peor and not lista[i].aviso and ("|cfff05050" .. L"  ▼ peor" .. C.FIN) or ""))
      f.pct:SetText(C.GRIS .. (o.p and (o.p .. " %") or "") .. C.FIN)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", self, "TOPLEFT", 4, y)
      f:SetPoint("TOPRIGHT", self, "TOPRIGHT", -4, y)
      f:Show()
      y = y - ALTO
    end
    local txt = ""
    if #self.objetos == 0 then txt = C.GRIS .. L"No se conoce botín propio confirmado. El contenido de Forever pendiente de verificar se incorporará en próximas versiones." .. C.FIN
    elseif #lista == 0 and pendientes == 0 and sinID == 0 then txt = C.GRIS .. L"Nada útil para tu clase." .. C.FIN
    elseif #completa > MAX_FILAS then
      txt = C.GRIS .. (self.desde + 1) .. "-" .. (self.desde + #lista) .. L" de " .. #completa .. L" (rueda del ratón)" .. C.FIN
    end
    if pendientes > 0 then
      txt = txt .. (txt ~= "" and " — " or "") .. C.GRIS .. L"Datos de botín pendientes de cargar." .. C.FIN
    end
    if sinComparar > 0 then
      txt = txt .. (txt ~= "" and " — " or "") .. C.GRIS .. L"Comparación de equipo no disponible" .. C.FIN
    end
    if sinID > 0 then
      txt = txt .. (txt ~= "" and " — " or "") .. C.GRIS .. L"Identificador de objeto sin confirmar." .. C.FIN
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
    if UISpecialFrames then GL.RegistrarCierreEscapeR13("GuiaAventureroBotin") end   -- 9.7.6: Esc la cierra
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
for _, evento in ipairs({"PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "UPDATE_FACTION", "SKILL_LINES_CHANGED"}) do
  if GL.Evento then GL.Evento(evBotin, evento) else pcall(evBotin.RegisterEvent, evBotin, evento) end
end
evBotin:SetScript("OnEvent", function(_, evento, id, exito)
  if evento ~= "GET_ITEM_INFO_RECEIVED" then id, exito = nil, nil end
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

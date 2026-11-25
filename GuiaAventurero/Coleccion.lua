-- Coleccion.lua (7.5.16): botón Colección del lateral derecho. Monturas, mascotas y juguetes que se consiguen
-- subiendo, en una cuadrícula de 4 por fila con el icono del juego: en color si lo tienes y en gris si no.
-- Clic en uno: dónde se consigue, precio, reputación, coordenadas y Llevarme. Datos en DatosWowhead.lua.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local COLUMNAS, ALTO_CELDA, LADO_ICONO, ALTO_FICHA = 4, 66, 40, 132
local PESTANAS = { { "monturas", L"Monturas", "montura", "monturas" }, { "mascotas", L"Mascotas", "mascota", "mascotas" },
  { "juguetes", L"Juguetes", "juguete", "juguetes" } }

local panel, ui = nil, { celdas = {}, pest = {} }
local tipo, desde, sel = "monturas", 0, nil

-- 8.5: solo lo de tu facción (lado = "A" o "H") y lo neutral.
local filtradas = {}
local function Lista()
  local todas = (GL.WH and GL.WH.coleccion and GL.WH.coleccion[tipo]) or {}
  local lado = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
  local clave = tipo .. lado
  if not filtradas[clave] then
    local l = {}
    for _, e in ipairs(todas) do if not e.lado or e.lado == lado then table.insert(l, e) end end
    filtradas[clave] = l
  end
  return filtradas[clave]
end

local function Tiene(e)
  if e.hechizo and IsSpellKnown then local ok, s = pcall(IsSpellKnown, e.hechizo); if ok and s then return true end end
  if tipo == "juguetes" and e.id and PlayerHasToy then local ok, s = pcall(PlayerHasToy, e.id); if ok and s then return true end end
  if e.id and GetItemCount then local ok, n = pcall(GetItemCount, e.id, true); if ok and type(n) == "number" and n > 0 then return true end end
  return false
end

local function Icono(e)
  if e.id and C_Item and C_Item.GetItemIconByID then local ok, t = pcall(C_Item.GetItemIconByID, e.id); if ok and t then return t end end
  if e.id and GetItemIcon then local ok, t = pcall(GetItemIcon, e.id); if ok and t then return t end end
  if e.hechizo and GetSpellTexture then local ok, t = pcall(GetSpellTexture, e.hechizo); if ok and t then return t end end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- 7.9.2: este cliente puede no tener GetItemInfo global; se prueba C_Item y se pide el objeto al servidor
local function Nombre(e)
  if e.n then return e.n end
  if not e.id then return "?" end
  local fuentes = { C_Item and C_Item.GetItemNameByID, C_Item and C_Item.GetItemInfo, GetItemInfo }
  for _, f in ipairs(fuentes) do
    if f then local ok, n = pcall(f, e.id); if ok and type(n) == "string" and n ~= "" then return n end end
  end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, e.id) end
  return "?"
end

local function TextoFicha(e)
  local l = { C.GRIS .. (PESTANAS[1][1] == tipo and "montura" or (tipo == "mascotas" and "mascota" or "juguete")) .. " · " ..
    (Tiene(e) and (C.VERDE .. L"ya la tienes" .. C.FIN .. C.GRIS) or L"no la tienes") .. C.FIN }
  if e.como or e.donde then table.insert(l, C.AMARILLO .. L"Dónde: " .. C.FIN .. (e.como and (e.como .. ". ") or "") .. (e.donde or "")) end
  if e.precio then table.insert(l, C.AMARILLO .. L"Precio: " .. C.FIN .. ((GL.Dinero and GL.Dinero(e.precio)) or (e.precio .. " c"))) end
  if e.rep then table.insert(l, C.AMARILLO .. L"Reputación: " .. C.FIN .. (e.rep.n or "?") .. L" en " .. (e.rep.nivel or "?")) end
  if e.nivel then table.insert(l, C.AMARILLO .. L"Nivel: " .. C.FIN .. e.nivel) end
  if e.x and e.y then table.insert(l, C.AMARILLO .. L"Coordenadas: " .. C.FIN .. string.format("%.1f, %.1f", e.x, e.y) .. (e.zona and (" · " .. e.zona) or "")) end
  table.insert(l, C.GRIS .. L"Fuente: " .. (e.comprobado and "QuestieDB (Forever)" or "Wowhead") .. C.FIN)
  return table.concat(l, "\n")
end

local function Filas()
  local alto = (panel:GetHeight() or 400) - 54 - (ui.altoFicha or ALTO_FICHA) - 8
  return math.max(1, math.floor(alto / ALTO_CELDA))
end

local function Refrescar()
  if not panel or not panel:IsShown() then return end
  local lista = Lista()
  local tengo = 0
  for i = 1, #lista do if Tiene(lista[i]) then tengo = tengo + 1 end end
  for i = 1, #ui.pest do ui.pest[i]:SetActivo(ui.pest[i].clave == tipo) end
  local nombreTipo = (tipo == "monturas" and "monturas") or (tipo == "mascotas" and "mascotas") or "juguetes"
  ui.titulo:SetText(L"Colección" .. C.GRIS .. "  · " .. tengo .. L" de " .. #lista .. " " .. nombreTipo .. C.FIN)
  -- 7.9.2: la ficha crece con su texto (antes Llevarme tapaba las últimas líneas) y la cuadrícula se queda con el resto
  local valida = false
  for i = 1, #lista do if lista[i] == sel then valida = true end end
  if not valida then sel = nil end
  ui.altoFicha = ALTO_FICHA
  if sel then
    ui.fichaTitulo:SetText(string.upper(Nombre(sel)))
    ui.fichaTexto:SetText(TextoFicha(sel))
    local boton = sel.m ~= nil and sel.x ~= nil
    GL.Mostrar(ui.llevar, boton)
    ui.altoFicha = math.max(ALTO_FICHA, math.ceil(24 + (ui.fichaTexto:GetStringHeight() or 0) + 8 + (boton and 28 or 0)))
    ui.ficha:SetHeight(ui.altoFicha)
    ui.ficha:Show()
  else
    ui.ficha:Hide()
  end
  ui.vacio:ClearAllPoints()
  ui.vacio:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, ui.altoFicha + 8)
  ui.vacio:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  local filas = Filas()
  local total = math.ceil(#lista / COLUMNAS)
  desde = math.max(0, math.min(desde, total - filas))
  local ancho = ((panel:GetWidth() or 400)) / COLUMNAS
  for i = 1, #ui.celdas do ui.celdas[i]:Hide() end
  local n = 0
  for f = 0, filas - 1 do
    for c = 0, COLUMNAS - 1 do
      local k = (desde + f) * COLUMNAS + c + 1
      local e = lista[k]
      if e then
        n = n + 1
        local celda = ui.celdas[n]
        if not celda then celda = ui.CrearCelda(); ui.celdas[n] = celda end
        celda.e = e
        celda:SetWidth(ancho - 4)
        celda:ClearAllPoints()
        celda:SetPoint("TOPLEFT", panel, "TOPLEFT", c * ancho + 2, -54 - f * ALTO_CELDA)
        celda.icono:SetTexture(Icono(e))
        local tiene = Tiene(e)
        if celda.icono.SetDesaturated then celda.icono:SetDesaturated(not tiene) end
        celda.icono:SetVertexColor(tiene and 1 or 0.6, tiene and 1 or 0.6, tiene and 1 or 0.6)
        if GL.Caja then
          GL.Caja(celda.marco, { 0, 0, 0, 0 }, (sel == e and { 1, 0.82, 0, 1 }) or (tiene and { 0.25, 0.85, 0.35, 0.9 }) or { 0.45, 0.45, 0.45, 0.8 })
        end
        celda.nombre:SetText((tiene and "" or C.GRIS) .. Nombre(e) .. (tiene and "" or C.FIN))
        celda:Show()
      end
    end
  end
  if #lista == 0 then
    ui.vacio:SetText(C.GRIS .. L"No hay " .. nombreTipo .. L" en esta lista." .. C.FIN)
  elseif total > filas then
    ui.vacio:SetText(C.GRIS .. L"Filas " .. (desde + 1) .. "-" .. math.min(total, desde + filas) .. L" de " .. total .. L" (rueda del ratón)" .. C.FIN)
  else
    ui.vacio:SetText("")
  end
end

local function CrearCelda()
  local b = CreateFrame("Button", nil, panel)
  b:SetHeight(ALTO_CELDA - 4)
  b.marco = CreateFrame("Frame", nil, b, PLANTILLA)
  b.marco:SetWidth(LADO_ICONO + 4); b.marco:SetHeight(LADO_ICONO + 4)
  b.marco:SetPoint("TOP", b, "TOP", 0, 0)
  b.icono = b:CreateTexture(nil, "ARTWORK")
  b.icono:SetWidth(LADO_ICONO); b.icono:SetHeight(LADO_ICONO)
  b.icono:SetPoint("CENTER", b.marco, "CENTER", 0, 0)
  b.nombre = GL.Texto(b, "GameFontHighlightSmall", "CENTER")
  b.nombre:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -LADO_ICONO - 6)
  b.nombre:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -LADO_ICONO - 6)
  if b.nombre.SetMaxLines then b.nombre:SetMaxLines(2) end
  b:SetScript("OnClick", function(self)
    sel = (sel ~= self.e) and self.e or nil
    Refrescar()
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.e or not self.e.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.e.id) else GameTooltip:SetHyperlink("item:" .. self.e.id) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  ui.CrearCelda = CrearCelda

  ui.titulo = GL.Texto(panel, "GameFontNormal")
  ui.titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  ui.titulo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0); GL.UnaLinea(ui.titulo)   -- 7.6.1: dentro del marco
  for i = 1, #PESTANAS do
    local clave = PESTANAS[i][1]
    local b = GL.CrearBoton(panel, PESTANAS[i][2], function() tipo, desde, sel = clave, 0, nil; Refrescar() end, nil, 20)
    b:SetWidth(84)
    b.clave = clave
    if i == 1 then b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22) else b:SetPoint("LEFT", ui.pest[i - 1], "RIGHT", 4, 0) end
    ui.pest[i] = b
  end
  ui.vacio = GL.Texto(panel, "GameFontHighlightSmall")
  ui.vacio:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, ALTO_FICHA + 8)
  ui.vacio:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

  local ficha = CreateFrame("Frame", nil, panel, PLANTILLA)
  ficha:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 4)
  ficha:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
  ficha:SetHeight(ALTO_FICHA)
  if GL.Caja and GL.COLOR then GL.Caja(ficha, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  local borde = ficha:CreateTexture(nil, "ARTWORK")
  borde:SetWidth(3)
  borde:SetPoint("TOPLEFT", ficha, "TOPLEFT", 0, 0)
  borde:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 0, 0)
  borde:SetColorTexture(1, 0.78, 0.25, 1)
  ui.fichaTitulo = GL.Texto(ficha, "GameFontNormalSmall")
  ui.fichaTitulo:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -8)
  ui.fichaTitulo:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -8); GL.UnaLinea(ui.fichaTitulo)   -- 7.6.1: dentro del marco
  ui.fichaTexto = GL.Texto(ficha, "GameFontHighlightSmall")
  ui.fichaTexto:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -24)
  ui.fichaTexto:SetPoint("RIGHT", ficha, "RIGHT", -8, 0)
  if ui.fichaTexto.SetSpacing then ui.fichaTexto:SetSpacing(2) end
  ui.llevar = GL.CrearBoton(ficha, L"Llevarme", function()
    if sel and sel.m and GL.SeguirDesvio then GL.SeguirDesvio({ m = sel.m, x = sel.x, y = sel.y, n = Nombre(sel) }) end
  end, nil, 20, "accion")
  ui.llevar:SetWidth(110)
  ui.llevar:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 12, 8)
  ficha:Hide()
  ui.ficha = ficha

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta) desde = math.max(0, desde - delta); Refrescar() end)
  panel:SetScript("OnSizeChanged", function() Refrescar() end)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt)   -- los nombres e iconos llegan del servidor poco a poco
    espera = espera + dt
    if espera >= 2 then espera = 0; Refrescar() end
  end)
  GL.modos.coleccion = { panel = panel, refrescar = Refrescar }
end

-- 9.0: se crea al abrirla por primera vez (Ajustes › General › Cargar cada sección al abrirla)
GL.perezosos = GL.perezosos or {}
GL.perezosos.coleccion = CrearPanel
table.insert(GL.alIniciar, function() if type(GuiaAventureroDB) == "table" and GuiaAventureroDB.cargarAlAbrir == false then CrearPanel() end end)

-- Para las pruebas
GL._coleccion = { Tiene = Tiene, Elegir = function(t, e) tipo, sel = t or tipo, e; Refrescar() end, Refrescar = function() Refrescar() end }

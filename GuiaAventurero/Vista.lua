-- Vista.lua (9.1): vista previa de una sección sin mover tu progreso. Se abre con < y > en la pestaña Guía
-- (con Mayús siguen cambiando de sección como antes) o con /ga vista [número].
-- Enseña la zona y los niveles, las zonas por las que pasa, cuántos pasos tiene y el tiempo que llevan (lo que
-- tardaste o tardó otro personaje de la cuenta con esta ruta; si no, una media), los pasos con vuelos, las
-- mazmorras de esos niveles y los primeros pasos. «Ir a esta sección» sí te mueve (como antes < y >).
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local MIN_PASO = 240   -- 4 min por paso si no hay ningún tiempo guardado

local function DB() return GuiaAventureroDB or {} end
local function Limpio(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%[(.-)%]", "«%1»"):gsub("<(.-)>", "%1")) end
local function Duracion(seg)
  local m = math.floor(seg / 60 + 0.5)
  if m < 60 then return m .. L" min" end
  return math.floor(m / 60) .. " h " .. (m % 60) .. L" min"
end

local function Tiempos()
  local c = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.pasos9
  local id = GL.RUTA and GL.RUTA.id
  return (type(c) == "table" and id and type(c[id]) == "table") and c[id] or {}
end

local function Datos(n)
  local R = GL.RUTA
  local s = R and R.secciones[n]
  if not s then return nil end
  local d = { n = n, s = s, zonas = {}, vuelos = {}, mazmorras = {}, pasos = #s.pasos }
  local vistas = {}
  for _, p in ipairs(s.pasos) do
    for _, w in ipairs(p.wp or {}) do
      if w.z and not vistas[w.z] then vistas[w.z] = true; table.insert(d.zonas, w.z) end
    end
    local t = string.lower(Limpio(p.t))
    if t:find("vuelo", 1, true) then table.insert(d.vuelos, (p.wp and p.wp[1] and p.wp[1].z) or "?") end
  end
  -- tiempo: lo guardado de cada paso; los que faltan, con la media de lo guardado o 4 min
  local g, suma, n2, conocido = Tiempos(), 0, 0, 0
  for _, v in pairs(g) do if type(v) == "table" and type(v.t) == "number" then suma, n2 = suma + v.t, n2 + 1 end end
  local media = n2 >= 3 and suma / n2 or MIN_PASO
  local total = 0
  for i = 1, #s.pasos do
    local v = g[n .. ":" .. i]
    if type(v) == "table" and type(v.t) == "number" then total = total + v.t; conocido = conocido + 1 else total = total + media end
  end
  d.tiempo, d.conocido, d.estimado = total, conocido, n2 < 3
  -- 9.2: a tu ritmo (Tiempos.lua), y lo que tardó la cuenta sin corregir para compararlo
  if GL.EstimarSeccion then
    local ok, t2, c2 = pcall(GL.EstimarSeccion, n, 1)
    if ok and type(t2) == "number" then
      d.tiempo, d.conocido = t2, c2
      d.estimado = (c2 == 0 and n2 < 3)
      d.cuenta = (n2 >= 3) and total or nil
      local f = GL.TuRitmoPasos and select(1, GL.TuRitmoPasos())
      d.factor = (type(f) == "number" and f ~= 1) and f or nil
    end
  end
  if GL.DatosMazmorras then
    local ok, lista = pcall(GL.DatosMazmorras)
    if ok and type(lista) == "table" then
      for _, m in ipairs(lista) do
        if type(m.min) == "number" and type(m.max) == "number" and m.min <= (s.max or 60) and m.max >= (s.min or 1) then table.insert(d.mazmorras, m.n) end
      end
    end
  end
  return d
end
GL.DatosSeccion = Datos

local ven, ui, actual = nil, {}, nil
local Pintar
local function Crear()
  ven = CreateFrame("Frame", "GuiaAventureroVistaPrevia", UIParent, PLANTILLA)
  ven:SetSize(400, 420)
  ven:SetPoint("CENTER", UIParent, "CENTER", -260, 20)
  ven:SetFrameStrata("DIALOG")
  ven:SetMovable(true); ven:EnableMouse(true); ven:SetClampedToScreen(true)
  ven:RegisterForDrag("LeftButton")
  ven:SetScript("OnDragStart", function(self) self:StartMoving() end)
  ven:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  GL.Caja(ven, GL.COLOR.fondo, GL.COLOR.borde)
  if GL.Sombra then GL.Sombra(ven) end
  if GL.Acento then GL.Acento(ven, 2) end
  if UISpecialFrames then table.insert(UISpecialFrames, "GuiaAventureroVistaPrevia") end
  ui.etq = GL.Texto(ven, "GameFontDisableSmall")
  ui.etq:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -10)
  ui.titulo = GL.Texto(ven, "GameFontNormalLarge")
  ui.titulo:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -24)
  ui.titulo:SetPoint("RIGHT", ven, "RIGHT", -90, 0)
  local x = GL.CrearBoton(ven, "", function() ven:Hide() end, nil, 20, "cerrar")
  x:SetWidth(20); x:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -8, -8)
  ui.sig = GL.CrearBoton(ven, ">", function() if actual then actual = actual + 1; Pintar() end end, nil, 20)
  ui.sig:SetWidth(24); ui.sig:SetPoint("RIGHT", x, "LEFT", -6, 0)
  ui.ant = GL.CrearBoton(ven, "<", function() if actual then actual = actual - 1; Pintar() end end, nil, 20)
  ui.ant:SetWidth(24); ui.ant:SetPoint("RIGHT", ui.sig, "LEFT", -4, 0)
  ui.texto = GL.Texto(ven, "GameFontHighlightSmall")
  ui.texto:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -52)
  ui.texto:SetPoint("RIGHT", ven, "RIGHT", -14, 0)
  if ui.texto.SetJustifyH then ui.texto:SetJustifyH("LEFT") end
  ui.ir = GL.CrearBoton(ven, L"Ir a esta sección", function()
    if actual and GL.IrAPaso then GL.IrAPaso(actual, 1, 1) end
    ven:Hide()
  end, nil, 22, "accion")
  ui.ir:SetWidth(150)
  ui.ir:SetPoint("BOTTOMRIGHT", ven, "BOTTOMRIGHT", -14, 12)
  if GL.Ayuda then GL.Ayuda(ui.ir, L"Ir a esta sección", L"Mueve tu progreso al primer paso de esta sección.") end
  ui.cerrar = GL.CrearBoton(ven, L"Cerrar", function() ven:Hide() end, nil, 22)
  ui.cerrar:SetWidth(90)
  ui.cerrar:SetPoint("RIGHT", ui.ir, "LEFT", -6, 0)
  ui.nota = GL.Texto(ven, "GameFontDisableSmall")
  ui.nota:SetPoint("BOTTOMLEFT", ven, "BOTTOMLEFT", 14, 42)
  ui.nota:SetPoint("RIGHT", ven, "RIGHT", -14, 0)
  if ui.nota.SetJustifyH then ui.nota:SetJustifyH("LEFT") end
end

Pintar = function()
  local total = GL.NumSecciones and GL.NumSecciones() or 0
  if total == 0 then return end
  actual = math.max(1, math.min(actual or 1, total))
  local d = Datos(actual)
  if not d then return end
  local mia = DB().seccion
  ui.etq:SetText(L"VISTA PREVIA · SECCIÓN " .. actual .. L" DE " .. total .. (actual == mia and L"  ·  LA TUYA" or ""))
  ui.titulo:SetText(C.BLANCO .. Limpio(d.s.titulo) .. C.FIN .. C.GRIS .. L"  niv. " .. tostring(d.s.min) .. "-" .. tostring(d.s.max) .. C.FIN)
  local l = {}
  table.insert(l, C.AMARILLO .. L"Zonas: " .. C.FIN .. (#d.zonas > 0 and table.concat(d.zonas, ", ") or "—"))
  table.insert(l, C.AMARILLO .. L"Pasos: " .. C.FIN .. d.pasos .. "  ·  " .. C.AMARILLO .. L"Tiempo: " .. C.FIN .. L"unos " .. Duracion(d.tiempo) ..
    C.GRIS .. (d.estimado and L" (media de 4 min por paso)" or L" a tu ritmo") .. C.FIN)
  if not d.estimado and d.cuenta and d.factor then
    table.insert(l, C.GRIS .. L"   Media de la cuenta: " .. Duracion(d.cuenta) .. L" · vas un " .. math.floor(math.abs(1 - d.factor) * 100 + 0.5) .. L" % más " ..
      (d.factor < 1 and L"rápido" or "lento") .. C.FIN)
  end
  table.insert(l, C.AMARILLO .. L"Vuelos: " .. C.FIN .. (#d.vuelos > 0 and (#d.vuelos .. (#d.vuelos == 1 and L" paso" or L" pasos") .. L" con vuelo (" .. table.concat(d.vuelos, ", ", 1, math.min(#d.vuelos, 4)) .. ")") or "ninguno"))
  table.insert(l, C.AMARILLO .. L"Mazmorras de estos niveles: " .. C.FIN .. (#d.mazmorras > 0 and table.concat(d.mazmorras, ", ", 1, math.min(#d.mazmorras, 5)) or "ninguna"))
  table.insert(l, "")
  table.insert(l, C.GRIS .. L"PRIMEROS PASOS" .. C.FIN)
  for i = 1, math.min(8, #d.s.pasos) do
    local t = Limpio(d.s.pasos[i].t)
    local frase = t:match("^(.-[%.:;])%s") or t
    if #frase > 90 then frase = frase:sub(1, 90) .. "…" end
    local marca = (actual == mia and i == DB().paso) and GL.Icono("▶") .. " " or ""
    if GL.IconoTipo and DB().iconosPaso ~= false then marca = marca .. GL.IconoTipo(d.s.pasos[i], 11) .. " " end
    table.insert(l, marca .. C.BLANCO .. i .. ". " .. C.FIN .. frase)
  end
  if #d.s.pasos > 8 then table.insert(l, C.GRIS .. "… y " .. (#d.s.pasos - 8) .. L" más" .. C.FIN) end
  ui.texto:SetText(table.concat(l, "\n"))
  ui.nota:SetText(L"Mirar no cambia tu progreso. Con Mayús, < y > de la Guía cambian de sección como antes.")
  GL.Mostrar(ui.ir, actual ~= mia)
  ui.ant:SetEnabled(actual > 1)
  ui.sig:SetEnabled(actual < total)
  local h = (ui.texto.GetStringHeight and tonumber(ui.texto:GetStringHeight())) or 280
  ven:SetHeight(math.max(260, 52 + h + 80))
end

GL.VistaPrevia = function(n)
  if not GL.RUTA then return end
  if not ven then Crear() end
  actual = n or DB().seccion or 1
  Pintar()
  ven:Show()
end

GL.comandos = GL.comandos or {}
GL.comandos["vista"] = function(orden) GL.VistaPrevia(tonumber(orden)) end

GL._vista = { Datos = Datos, Pintar = function() Pintar() end, Actual = function() return actual end }

-- Resumen.lua (9.2): resumen al acabar una sección. Al pasar a la sección siguiente sale una ventana con lo que
-- tardaste (tiempo jugado en la sección), los niveles y la XP que ganaste, las misiones entregadas, las muertes, el
-- oro, cómo vas frente a la media de la cuenta, el paso que más te costó y lo que viene.
-- Se guarda cada sección (GuiaAventureroDB.resumenes); /ga resumen [n] los vuelve a enseñar.
-- Si saltas de sección a mano o la ruta te recoloca, no sale (no la has hecho entera).
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil

local function DB() return GuiaAventureroDB or {} end
local function Num(v) v = (GL.Seguro and GL.Seguro(v)) or v; return type(v) == "number" and v or nil end
local function Ahora() return (GetTime and GetTime()) or 0 end
local function Duracion(seg)
  local m = math.floor((seg or 0) / 60 + 0.5)
  if m < 60 then return m .. L" min" end
  return math.floor(m / 60) .. " h " .. (m % 60) .. L" min"
end
local function Miles(n)
  return GL.FormatoMiles(n)
end
local function Oro(c)
  c = math.floor(c or 0)
  local signo = c < 0 and "-" or "+"
  c = math.abs(c)
  local o, p = math.floor(c / 10000), math.floor((c % 10000) / 100)
  if o > 0 then return signo .. o .. " o " .. p .. " p" end
  return signo .. p .. " p " .. (c % 100) .. " c"
end

-- XP total desde el nivel 1 (para restar aunque subas de nivel)
local function XPTotal()
  local nivel = Num(UnitLevel and UnitLevel("player")) or 1
  local t = Num(UnitXP and UnitXP("player")) or 0
  for n = 1, nivel - 1 do t = t + ((GL.XP_NIVEL and GL.XP_NIVEL[n]) or 0) end
  return t
end
local function Dinero() return Num(GetMoney and GetMoney()) or 0 end

-- Lo que se está midiendo de la sección en la que estás (se guarda: sobrevive a salir del juego)
local marca = nil   -- GetTime() desde el que se cuenta el tiempo de esta sesión
local function Actual() return DB().resumenActual end
local function Empezar(s)
  DB().resumenActual = { s = s, seg = 0, nivel = Num(UnitLevel and UnitLevel("player")) or 1, xp = XPTotal(), oro = Dinero(), muertes = 0, misiones = 0 }
  marca = Ahora()
end
local function Sumar()
  local a = Actual()
  if a and marca then a.seg = (a.seg or 0) + math.max(0, Ahora() - marca); marca = Ahora() end
end

-- Lo que tardó la cuenta en la sección y el paso que más te costó a ti
local function Comparar(s)
  local c = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.pasos9
  local id = GL.RUTA and GL.RUTA.id
  local cuenta = (type(c) == "table" and id and type(c[id]) == "table") and c[id] or {}
  local mios = (type(DB().tiempos9) == "table" and id and type(DB().tiempos9[id]) == "table") and DB().tiempos9[id] or {}
  local sec = GL.RUTA and GL.RUTA.secciones[s]
  if not sec then return nil end
  local media, todos, peor, peorT = 0, true, nil, 0
  for i = 1, #sec.pasos do
    local v = cuenta[s .. ":" .. i]
    if type(v) == "table" and Num(v.t) and (Num(v.n) or 1) >= 2 then media = media + v.t else todos = false end
    local t = Num(mios[s .. ":" .. i])
    if t and t > peorT then peor, peorT = sec.pasos[i], t end
  end
  return todos and media or nil, peor, peorT
end

local function Corto(t)
  t = tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%[(.-)%]", "«%1»")
  t = t:match("^(.-)[%.:;]%s") or t
  if #t > 50 then t = t:sub(1, 50) .. "…" end
  return t
end

local function Cerrar(a)
  Sumar()
  local s = a.s
  local r = {
    s = s, titulo = GL.RUTA and GL.RUTA.secciones[s] and GL.RUTA.secciones[s].titulo, seg = math.floor(a.seg or 0),
    nivel0 = a.nivel, nivel1 = Num(UnitLevel and UnitLevel("player")) or a.nivel, xp = math.max(0, XPTotal() - (a.xp or 0)),
    oro = Dinero() - (a.oro or 0), muertes = a.muertes or 0, misiones = a.misiones or 0,
    pasos = GL.RUTA and GL.RUTA.secciones[s] and #GL.RUTA.secciones[s].pasos or 0,
    fecha = tostring((date and date("%d-%m-%Y")) or "?"),
  }
  local media, peor, peorT = Comparar(s)
  r.media = media and math.floor(media) or nil
  if peor then r.peor, r.peorT = Corto(peor.t), math.floor(peorT) end
  local db = DB()
  db.resumenes = type(db.resumenes) == "table" and db.resumenes or {}
  db.resumenes[s] = r
  return r
end

------------------------------------------------------------------------
-- Ventana
------------------------------------------------------------------------
local ven, ui = nil, {}
local function Caja(padre, x, y, w, etiqueta)
  local f = CreateFrame("Frame", nil, padre, PLANTILLA)
  f:SetSize(w, 38)
  f:SetPoint("TOPLEFT", padre, "TOPLEFT", x, y)
  GL.Caja(f, GL.COLOR.caja, GL.COLOR.cajaBorde)
  f.etq = GL.Texto(f, "GameFontDisableSmall")
  f.etq:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -5)
  f.etq:SetText(string.upper(etiqueta))
  f.valor = GL.Texto(f, "GameFontHighlight")
  f.valor:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -19)
  return f
end

local function Crear()
  ven = CreateFrame("Frame", "GuiaAventureroResumen", UIParent, PLANTILLA)
  ven:SetSize(400, 420)
  ven:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  ven:SetFrameStrata("DIALOG")
  ven:SetMovable(true); ven:EnableMouse(true); ven:SetClampedToScreen(true)
  ven:RegisterForDrag("LeftButton")
  ven:SetScript("OnDragStart", function(self) self:StartMoving() end)
  ven:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  GL.Caja(ven, GL.COLOR.fondo, GL.COLOR.borde)
  if GL.Sombra then GL.Sombra(ven) end
  if GL.Acento then GL.Acento(ven, 3) end
  if UISpecialFrames then GL.RegistrarCierreEscapeR13("GuiaAventureroResumen") end
  ui.icono = ven:CreateTexture(nil, "ARTWORK")
  ui.icono:SetSize(30, 30)
  ui.icono:SetPoint("TOP", ven, "TOP", 0, -12)
  ui.icono:SetTexture("Interface\\Icons\\INV_Misc_Map02")
  ui.etq = GL.Texto(ven, "GameFontNormalSmall")
  ui.etq:SetPoint("TOP", ui.icono, "BOTTOM", 0, -4)
  ui.titulo = GL.Texto(ven, "GameFontHighlightLarge")
  ui.titulo:SetPoint("TOP", ui.etq, "BOTTOM", 0, -2)
  local w = (400 - 28 - 12) / 3
  ui.c = {}
  local nombres = { L"Tiempo", L"Niveles", L"XP ganada", L"Misiones", L"Muertes", L"Oro" }
  for i, n in ipairs(nombres) do
    ui.c[i] = Caja(ven, 14 + ((i - 1) % 3) * (w + 6), -100 - math.floor((i - 1) / 3) * 44, w, n)
  end
  ui.texto = GL.Texto(ven, "GameFontHighlightSmall")
  ui.texto:SetPoint("TOPLEFT", ven, "TOPLEFT", 16, -196)
  ui.texto:SetPoint("RIGHT", ven, "RIGHT", -16, 0)
  if ui.texto.SetJustifyH then ui.texto:SetJustifyH("LEFT") end
  ui.seguir = GL.CrearBoton(ven, L"Seguir", function() ven:Hide() end, nil, 24, "accion")
  ui.seguir:SetWidth(170)
  ui.seguir:SetPoint("BOTTOMRIGHT", ven, "BOTTOMRIGHT", -14, 12)
  ui.vista = GL.CrearBoton(ven, L"Ver la siguiente", function() if ui.sig and GL.VistaPrevia then GL.VistaPrevia(ui.sig) end end, nil, 24)
  ui.vista:SetWidth(170)
  ui.vista:SetPoint("RIGHT", ui.seguir, "LEFT", -6, 0)
end

local function Pintar(r)
  if not ven then Crear() end
  local R = GL.RUTA
  local total = R and #R.secciones or 0
  ui.etq:SetText(L"SECCIÓN " .. r.s .. L" DE " .. total .. L" TERMINADA" .. (r.fecha and (C.GRIS .. "  ·  " .. r.fecha .. C.FIN) or ""))
  ui.titulo:SetText(tostring(r.titulo or "?"))
  local vals = {
    Duracion(r.seg),
    "|cffa48cff" .. r.nivel0 .. (r.nivel1 ~= r.nivel0 and (" " .. GL.Icono("→", 164, 140, 255) .. " " .. r.nivel1) or "") .. C.FIN,
    Miles(r.xp),
    C.VERDE .. r.misiones .. C.FIN,
    (r.muertes > 0 and "|cfff87171" or C.VERDE) .. r.muertes .. C.FIN,
    C.AMARILLO .. Oro(r.oro) .. C.FIN,
  }
  for i, v in ipairs(vals) do ui.c[i].valor:SetText(v) end
  local l = {}
  if r.media and r.seg > 0 then
    local dif = r.media - r.seg
    if math.abs(dif) >= 60 then
      table.insert(l, C.AMARILLO .. L"Comparado con la cuenta: " .. C.FIN .. (dif > 0 and (C.VERDE .. Duracion(dif) .. L" más rápido" .. C.FIN) or ("|cfff87171" .. Duracion(-dif) .. L" más lento" .. C.FIN)) ..
        L" que la media de esta sección (" .. Duracion(r.media) .. ").")
    else
      table.insert(l, C.AMARILLO .. L"Comparado con la cuenta: " .. C.FIN .. L"lo mismo que la media (" .. Duracion(r.media) .. ").")
    end
  end
  if r.peor then table.insert(l, C.AMARILLO .. L"El paso que más te costó: " .. C.FIN .. r.peor .. " (" .. Duracion(r.peorT) .. ").") end
  table.insert(l, "")
  local sig = R and R.secciones[r.s + 1]
  ui.sig = sig and (r.s + 1) or nil
  if sig then
    local t = GL.EstimarSeccion and select(2, pcall(GL.EstimarSeccion, r.s + 1, 1))
    table.insert(l, C.GRIS .. "SIGUIENTE" .. C.FIN)
    table.insert(l, C.BLANCO .. tostring(sig.titulo) .. C.FIN .. C.GRIS .. L"  niv. " .. tostring(sig.min) .. "-" .. tostring(sig.max) .. " · " .. #sig.pasos .. L" pasos" ..
      (type(t) == "number" and (L" · unos " .. Duracion(t)) or "") .. C.FIN)
  else
    table.insert(l, C.VERDE .. L"Era la última sección de la ruta." .. C.FIN)
  end
  local txt = table.concat(l, "\n")
  ui.texto:SetText(txt)
  GL.Mostrar(ui.vista, ui.sig ~= nil and GL.VistaPrevia ~= nil)
  local h = (GL.Alto and GL.Alto(ui.texto, txt, 12, 368)) or 80
  ven:SetHeight(196 + h + 54)
  ven:Show()
end
GL.MostrarResumenSeccion = Pintar

------------------------------------------------------------------------
-- Cuándo
------------------------------------------------------------------------
local function Mirar()
  local db = DB()
  if not GL.RUTA or not db.seccion then return end
  local a = Actual()
  if not a or not a.s then Empezar(db.seccion); return end
  if a.s == db.seccion then a.paso = db.paso; return end
  -- solo si vienes del último paso de la sección (no si saltas a mano o la ruta te recoloca)
  local secA = GL.RUTA.secciones[a.s]
  if db.seccion == a.s + 1 and secA and (a.paso or 0) >= #secA.pasos and (db.paso or 1) == 1 and (a.seg or 0) + (marca and (Ahora() - marca) or 0) >= 120 then
    local r = Cerrar(a)
    if db.resumenSeccion ~= false then
      local ok, err = pcall(Pintar, r)
      if not ok and GL.Fallo then GL.Fallo(L"resumen de sección", err) end
    end
  end
  Empezar(db.seccion)
end

table.insert(GL.alIniciar, function()
  marca = Ahora()
  pcall(Mirar)
end)
GL.trasRefrescar = GL.trasRefrescar or {}
table.insert(GL.trasRefrescar, function()
  local ok, err = pcall(Mirar)
  if not ok and GL.Fallo then GL.Fallo(L"resumen de sección", err) end
end)

local ev = CreateFrame("Frame")
GL.Evento(ev, "PLAYER_DEAD")
GL.Evento(ev, "QUEST_TURNED_IN")
GL.Evento(ev, "PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, evento)
  local a = Actual()
  if not a then return end
  if evento == "PLAYER_DEAD" then a.muertes = (a.muertes or 0) + 1
  elseif evento == "QUEST_TURNED_IN" then a.misiones = (a.misiones or 0) + 1
  elseif evento == "PLAYER_LOGOUT" then Sumar(); marca = nil end
end)

GL.comandos = GL.comandos or {}
GL.comandos["resumen"] = function(orden)
  local db = DB()
  local l = type(db.resumenes) == "table" and db.resumenes or {}
  local n = tonumber(orden)
  if not n then for s in pairs(l) do if not n or s > n then n = s end end end
  if n and l[n] then Pintar(l[n])
  elseif GL.Mensaje then GL.Mensaje(L"aún no has acabado ninguna sección con la 9.2" .. (n and (L" (ni la " .. n .. ")") or "") .. ".") end
end

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "resumenSeccion", "Resumen al acabar una sección",
  "Al pasar a la sección siguiente: tiempo, niveles, XP, misiones, muertes, oro y lo que viene. /ga resumen lo vuelve a enseñar.",
  function() return DB().resumenSeccion ~= false end, function(v) DB().resumenSeccion = v end, pestana = "paso" })

GL._resumen = { Mirar = Mirar, Pintar = Pintar, Cerrar = Cerrar, Empezar = Empezar, Actual = Actual }

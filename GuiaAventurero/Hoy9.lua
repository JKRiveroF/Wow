-- Hoy9.lua (9.0): Cuenta › Hoy. Lo que has hecho hoy (o esta semana) con todos tus personajes: XP, niveles,
-- oro, misiones, pasos y XP por hora; un gráfico de XP cada 15 minutos; cada personaje con lo suyo de hoy; y la
-- sesión actual y la anterior (antes en Personaje › Estadísticas), con el botón de compartir en el chat.
-- Los datos se guardan para toda la cuenta y se borran solos a los 8 días.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"
local function DB() return GuiaAventureroDB or {} end
local function Num(v) v = (GL.Seguro and GL.Seguro(v)) or v; return type(v) == "number" and v or nil end
local function Miles(n)
  return GL.FormatoMiles(n)
end
local function Duracion(seg)
  seg = math.floor((seg or 0) + 0.5)
  if seg < 60 then return seg .. " s" end
  local m = math.floor(seg / 60)
  if m < 60 then return m .. L" min" end
  return math.floor(m / 60) .. " h " .. (m % 60) .. L" min"
end
local function Hoy()
  local ok, d = pcall(function() return date and date("%Y-%m-%d") end)
  return (ok and type(d) == "string") and d or "hoy"
end
local function Franja()   -- cuarto de hora del día (0-95)
  local ok, t = pcall(function() return date and date("*t") end)
  if not ok or type(t) ~= "table" or not Num(t.hour) or not Num(t.min) then return 0 end
  return math.floor((t.hour * 60 + t.min) / 15)
end
local function Clave()
  local n = UnitName and UnitName("player")
  local r = GetRealmName and GetRealmName()
  return (n or "?") .. "-" .. (r or "")
end

------------------------------------------------------------------------
-- Datos
------------------------------------------------------------------------
local function Dias()
  if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
  local c = GuiaAventureroCuenta
  if type(c.dias9) ~= "table" then c.dias9 = {} end
  return c.dias9
end

local function Limpiar()
  if not time then return end
  local dias = Dias()
  local limite = date("%Y-%m-%d", time() - 8 * 86400)
  for k in pairs(dias) do if type(k) == "string" and k < limite then dias[k] = nil end end
end

local function Mio()
  local dias = Dias()
  local h = Hoy()
  if type(dias[h]) ~= "table" then dias[h] = {} end
  local k = Clave()
  local p = dias[h][k]
  if type(p) ~= "table" then
    local _, clase = UnitClass and UnitClass("player")
    p = { xp = 0, n0 = Num(UnitLevel and UnitLevel("player")) or 1, oro = 0, q = 0, pasos = 0, t = 0, b = {}, clase = clase,
      nombre = UnitName and UnitName("player") }
    dias[h][k] = p
  end
  p.n1 = Num(UnitLevel and UnitLevel("player")) or p.n0
  return p
end

local xpAntes, xpMaxAntes, nivelAntes, oroAntes = nil, nil, nil, nil
local function LeerXP()
  local xp, max, nv = Num(UnitXP and UnitXP("player")), Num(UnitXPMax and UnitXPMax("player")), Num(UnitLevel and UnitLevel("player")) or 1
  if not xp or not max then return end
  if xpAntes then
    local d = 0
    if nv > (nivelAntes or nv) then d = (xpMaxAntes - xpAntes) + xp elseif xp > xpAntes then d = xp - xpAntes end
    if d > 0 then
      local p = Mio()
      p.xp = p.xp + d
      local f = tostring(Franja())
      p.b[f] = (p.b[f] or 0) + d
    end
  end
  xpAntes, xpMaxAntes, nivelAntes = xp, max, nv
end

local function LeerOro()
  local o = Num(GetMoney and GetMoney())
  if not o then return end
  if oroAntes then local p = Mio(); p.oro = p.oro + (o - oroAntes) end
  oroAntes = o
end

local claveAnt
local function MirarPaso()
  local db = DB()
  if not db.seccion or not db.paso then return end
  local clave = db.seccion * 1000 + db.paso
  if claveAnt and clave > claveAnt then local p = Mio(); p.pasos = p.pasos + 1 end
  claveAnt = clave
end

-- suma de un día (o de varios) de todos los personajes
local function Sumar(dias)
  local r = { xp = 0, oro = 0, q = 0, pasos = 0, t = 0, b = {}, pj = {}, n0 = nil, n1 = nil }
  for _, d in ipairs(dias) do
    for k, p in pairs(d) do
      if type(p) == "table" then
        r.xp, r.oro, r.q, r.pasos, r.t = r.xp + (p.xp or 0), r.oro + (p.oro or 0), r.q + (p.q or 0), r.pasos + (p.pasos or 0), r.t + (p.t or 0)
        for f, v in pairs(p.b or {}) do r.b[f] = (r.b[f] or 0) + v end
        local e = r.pj[k]
        if not e then e = { nombre = p.nombre or k, clase = p.clase, xp = 0, q = 0, t = 0, n0 = p.n0, n1 = p.n1 }; r.pj[k] = e end
        e.xp, e.q, e.t = e.xp + (p.xp or 0), e.q + (p.q or 0), e.t + (p.t or 0)
        e.n0 = math.min(e.n0 or p.n0 or 1, p.n0 or 1); e.n1 = math.max(e.n1 or p.n1 or 1, p.n1 or 1)
      end
    end
  end
  local yo = r.pj[Clave()]
  if yo then r.n0, r.n1 = yo.n0, yo.n1 end
  return r
end

------------------------------------------------------------------------
-- Pantalla
------------------------------------------------------------------------
local ui
local function Tesela(padre)
  local t = CreateFrame("Frame", nil, padre, PLANTILLA)
  t:SetHeight(40)
  GL.Caja(t, GL.COLOR.caja, GL.COLOR.cajaBorde)
  t.k = GL.Texto(t, "GameFontHighlightSmall")
  t.k:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -6)
  t.v = GL.Texto(t, "GameFontHighlight")
  t.v:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -20)
  local f, _, o = t.v:GetFont()
  if type(f) == "string" then t.v:SetFont(f, 14, o) end
  return t
end

local function Crear(f)
  ui = { teselas = {}, barras = {}, pj = {} }
  local c = CreateFrame("Frame", nil, f)   -- lo de Hoy y Semana (se oculta en Por nivel)
  c:SetAllPoints(f)
  ui.c = c
  ui.titulo = GL.Texto(f, "GameFontNormalLarge")
  ui.titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  ui.sub = GL.Texto(c, "GameFontHighlightSmall")
  ui.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -20)
  ui.modo = {}
  for i, v in ipairs({ { "hoy", L"Hoy" }, { "semana", L"Semana" }, { "nivel", L"Por nivel" } }) do
    local b = GL.CrearBoton(f, v[2], function() DB().hoyModo = v[1]; GL.PintarHoy(f) end, nil, 18, "pestana")
    b:SetWidth(64)
    b.modo = v[1]
    ui.modo[i] = b
  end
  ui.modo[3]:SetWidth(72)
  ui.modo[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
  ui.modo[2]:SetPoint("RIGHT", ui.modo[3], "LEFT", -4, 0)
  ui.modo[1]:SetPoint("RIGHT", ui.modo[2], "LEFT", -4, 0)
  local nombres = { L"XP ganada", L"Niveles", L"Oro", L"Misiones", L"Pasos", L"XP / hora" }
  for i = 1, 6 do ui.teselas[i] = Tesela(c); ui.teselas[i].k:SetText(C.GRIS .. nombres[i] .. C.FIN) end
  ui.cabGrafico = GL.Texto(c, "GameFontHighlightSmall")
  ui.grafico = CreateFrame("Frame", nil, c, PLANTILLA)
  ui.grafico:SetHeight(64)
  GL.Caja(ui.grafico, { 0, 0, 0, 0.25 }, GL.COLOR.cajaBorde)
  ui.ejes = {}
  for i = 1, 3 do ui.ejes[i] = GL.Texto(c, "GameFontDisableSmall", i == 3 and "RIGHT" or "LEFT") end
  ui.cabPj = GL.Texto(c, "GameFontHighlightSmall")
  ui.cabSesion = GL.Texto(c, "GameFontHighlightSmall")
  ui.sesion = GL.Texto(c, "GameFontHighlightSmall")
  ui.anterior = GL.Texto(c, "GameFontHighlightSmall")
  ui.compartir = GL.CrearBoton(c, L"Compartir en el chat", function() if GL.Compartir then GL.Compartir() end end, nil, 20, "accion")
  if GL.Ayuda then GL.Ayuda(ui.compartir, L"Compartir en el chat", L"Pone tu nivel, tiempo y ritmo en el chat de grupo (o de hermandad si no estás en grupo).") end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function() end)
  local espera = 0
  f:SetScript("OnUpdate", function(self, dt) espera = espera + dt; if espera >= 2 then espera = 0; pcall(GL.PintarHoy, self) end end)
end

local function ColorClase(clase)
  local c = clase and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(clase)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[clase]))
  if c and c.r then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
  return C.BLANCO
end

function GL.PintarHoy(f)
  if not ui then Crear(f) end
  local W = f:GetWidth() or 360
  if W < 100 then W = 360 end
  local modoHoy = DB().hoyModo or "hoy"
  local semana = modoHoy == "semana"
  for _, b in ipairs(ui.modo) do b:SetActivo(b.modo == modoHoy) end
  -- 9.0: Por nivel es lo que era Personaje › Estadísticas (el resumen y la tabla de cada nivel)
  local est = GL.modos and GL.modos.estadisticas
  if modoHoy == "nivel" and est and est.panel then
    ui.c:Hide()
    ui.titulo:SetText(L"Por nivel")
    if est.panel:GetParent() ~= f then
      est.panel:SetParent(f)
      est.panel:ClearAllPoints()
      est.panel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
      est.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    end
    est.panel:Show()
    if est.refrescar then pcall(est.refrescar) end
    return
  end
  if est and est.panel and est.panel:GetParent() == f then est.panel:Hide() end
  ui.c:Show()
  local dias = Dias()
  local lista, etiquetas = {}, {}
  if semana and time then
    for i = 6, 0, -1 do
      local k = date("%Y-%m-%d", time() - i * 86400)
      table.insert(lista, dias[k] or {})
      table.insert(etiquetas, date("%d/%m", time() - i * 86400))
    end
  else
    table.insert(lista, dias[Hoy()] or {})
  end
  local r = Sumar(lista)
  local se = GL.SesionActual and GL.SesionActual()
  ui.titulo:SetText(semana and L"Esta semana" or L"Hoy")
  ui.sub:SetText(C.GRIS .. (se and (L"Sesión de " .. Duracion(se.t)) or "") .. (r.t > 0 and (L"  ·  jugado " .. (semana and L"en la semana " or L"hoy ") .. Duracion(r.t)) or "") .. C.FIN)
  -- teselas (3 x 2)
  local tw = math.floor((W - 2 * 6) / 3)
  local valores = {
    Miles(r.xp),
    (r.n0 and r.n1) and (r.n0 == r.n1 and tostring(r.n1) or (r.n0 .. " " .. GL.Icono("→") .. " " .. r.n1)) or "—",
    (GL.DineroConSigno and GL.DineroConSigno(r.oro)) or tostring(r.oro),
    tostring(r.q), tostring(r.pasos),
    (r.t >= 300) and Miles(r.xp / r.t * 3600) or "—",
  }
  for i, t in ipairs(ui.teselas) do
    local c, fila = (i - 1) % 3, math.floor((i - 1) / 3)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", c * (tw + 6), -40 - fila * 46)
    t:SetWidth(tw)
    t.v:SetText((i == 1 and "|cffa48cff" or C.BLANCO) .. valores[i] .. C.FIN)
  end
  local y = 40 + 2 * 46 + 6
  -- gráfico
  ui.cabGrafico:ClearAllPoints()
  ui.cabGrafico:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.cabGrafico:SetText(C.GRIS .. (semana and L"XP POR DÍA" or L"XP POR CADA 15 MIN") .. C.FIN)
  y = y + 16
  ui.grafico:ClearAllPoints()
  ui.grafico:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.grafico:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -y)
  local valoresG, etiq = {}, {}
  if semana then
    for i, d in ipairs(lista) do valoresG[i] = Sumar({ d }).xp; etiq[i] = etiquetas[i] end
  else
    local primero, ultimo = nil, Franja()
    for k, v in pairs(r.b) do local n = tonumber(k); if n and v > 0 and (not primero or n < primero) then primero = n end end
    primero = primero or ultimo
    if ultimo - primero > 31 then primero = ultimo - 31 end
    if ultimo - primero < 7 then primero = math.max(0, ultimo - 7) end
    for n = primero, ultimo do
      table.insert(valoresG, r.b[tostring(n)] or 0)
      table.insert(etiq, string.format("%d:%02d", math.floor(n / 4), (n % 4) * 15))
    end
  end
  local maxV = 1
  for _, v in ipairs(valoresG) do if v > maxV then maxV = v end end
  local nB = #valoresG
  local gw = W - 8
  local bw = math.max(2, math.floor(gw / math.max(1, nB)) - 2)
  local a = GL.COLOR.acento
  for i = 1, math.max(nB, #ui.barras) do
    local b = ui.barras[i]
    if i <= nB then
      if not b then b = ui.grafico:CreateTexture(nil, "ARTWORK"); b:SetTexture(BLANCO8); ui.barras[i] = b end
      local h = math.max(1, math.floor(54 * valoresG[i] / maxV))
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", ui.grafico, "BOTTOMLEFT", 4 + (i - 1) * (bw + 2), 4)
      b:SetSize(bw, h)
      local ultima = (i == nB)
      b:SetVertexColor(a[1], a[2], a[3], ultima and 1 or (valoresG[i] > 0 and 0.7 or 0.15))
      b:Show()
    elseif b then
      b:Hide()
    end
  end
  y = y + 64 + 2
  if nB > 0 then
    ui.ejes[1]:ClearAllPoints(); ui.ejes[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -y); ui.ejes[1]:SetText(etiq[1] or "")
    ui.ejes[2]:ClearAllPoints(); ui.ejes[2]:SetPoint("TOP", f, "TOP", 0, -y); ui.ejes[2]:SetText(etiq[math.floor((nB + 1) / 2)] or "")
    ui.ejes[3]:ClearAllPoints(); ui.ejes[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -y); ui.ejes[3]:SetText(etiq[nB] or "")
  end
  y = y + 18
  -- personajes
  local pjs = {}
  for _, p in pairs(r.pj) do if (p.xp or 0) > 0 or (p.q or 0) > 0 or (p.t or 0) > 0 then table.insert(pjs, p) end end
  table.sort(pjs, function(x, z) return (x.xp or 0) > (z.xp or 0) end)
  ui.cabPj:ClearAllPoints()
  ui.cabPj:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.cabPj:SetText(C.GRIS .. (semana and L"POR PERSONAJE, ESTA SEMANA" or L"POR PERSONAJE, HOY") .. C.FIN)
  y = y + 16
  for _, t in ipairs(ui.pj) do t:Hide() end
  for i = 1, math.min(#pjs, 5) do
    local p = pjs[i]
    local t = ui.pj[i]
    if not t then t = GL.Texto(ui.c, "GameFontHighlightSmall"); ui.pj[i] = t end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -y)
    t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -y)
    local niv = (p.n0 and p.n1 and p.n1 > p.n0) and (p.n0 .. " " .. GL.Icono("→") .. " " .. p.n1) or tostring(p.n1 or "?")
    t:SetText(ColorClase(p.clase) .. (p.nombre or "?") .. C.FIN .. C.GRIS .. L"  nivel " .. niv .. "  ·  " .. C.FIN ..
      "|cffa48cff" .. Miles(p.xp) .. " XP" .. C.FIN .. C.GRIS .. "  ·  " .. (p.q or 0) .. L" misiones  ·  " .. Duracion(p.t or 0) .. C.FIN)
    t:Show()
    y = y + 15
  end
  if #pjs == 0 then
    local t = ui.pj[1] or GL.Texto(ui.c, "GameFontHighlightSmall"); ui.pj[1] = t
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -y)
    t:SetText(C.GRIS .. L"Aún nada: se apunta mientras juegas." .. C.FIN); t:Show()
    y = y + 15
  end
  y = y + 8
  -- sesión (antes en Estadísticas)
  ui.cabSesion:ClearAllPoints()
  ui.cabSesion:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.cabSesion:SetText(C.GRIS .. L"ESTA SESIÓN" .. C.FIN)
  y = y + 16
  ui.sesion:ClearAllPoints()
  ui.sesion:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -y)
  ui.sesion:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -y)
  if se then
    ui.sesion:SetText(Duracion(se.t) .. C.GRIS .. "  ·  " .. C.FIN .. Miles(se.xp) .. " XP" ..
      (se.t >= 60 and (C.GRIS .. " (" .. Miles(se.xp / se.t * 3600) .. "/h)" .. C.FIN) or "") .. C.GRIS .. "  ·  " .. C.FIN ..
      ((se.oro >= 0) and C.VERDE or "|cffff7070") .. ((GL.DineroConSigno and GL.DineroConSigno(se.oro)) or se.oro) .. C.FIN ..
      C.GRIS .. "  ·  " .. C.FIN .. se.q .. (se.q == 1 and L" misión" or L" misiones"))
  else
    ui.sesion:SetText(C.GRIS .. "—" .. C.FIN)
  end
  y = y + 16
  local an = DB().sesionAnterior
  ui.anterior:ClearAllPoints()
  ui.anterior:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -y)
  ui.anterior:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -y)
  if GL.UnaLinea then GL.UnaLinea(ui.anterior) end
  ui.anterior:SetText(an and (C.GRIS .. L"Sesión anterior" .. (date and an.fin and (" (" .. date("%d/%m", an.fin) .. ")") or "") .. ": " ..
    Duracion(an.t) .. ", " .. Miles(an.xp) .. L" XP, " .. ((GL.DineroConSigno and GL.DineroConSigno(an.oro or 0)) or "") .. ", " .. (an.q or 0) .. L" misiones" .. C.FIN) or "")
  y = y + 18
  ui.compartir:ClearAllPoints()
  ui.compartir:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.compartir:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -y)
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
table.insert(GL.alIniciar, function()
  pcall(Limpiar)
  pcall(Mio)
  pcall(LeerXP); pcall(LeerOro); pcall(MirarPaso)
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "QUEST_TURNED_IN" }) do f:RegisterEvent(e) end
  f:SetScript("OnEvent", function(_, evento)
    if evento == "PLAYER_MONEY" then pcall(LeerOro)
    elseif evento == "QUEST_TURNED_IN" then pcall(function() local p = Mio(); p.q = p.q + 1 end)
    else pcall(LeerXP) end
  end)
  local reloj = 0
  f:SetScript("OnUpdate", function(_, dt)
    reloj = reloj + (dt or 0)
    if reloj >= 30 then pcall(function() local p = Mio(); p.t = p.t + reloj end); reloj = 0 end
  end)
end)
GL.trasRefrescar = GL.trasRefrescar or {}
table.insert(GL.trasRefrescar, function() pcall(MirarPaso) end)
GL._hoy = { Sumar = Sumar, Dias = Dias, Mio = Mio }

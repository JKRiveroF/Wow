-- Experiencia.lua (7.0): retrato del PNJ en la caja del paso (clic: lo selecciona si está cerca), celebración al
-- subir de nivel o acabar una sección (con los hechizos nuevos, su icono y su precio), destinos del paso en el
-- minimapa y bienvenida al conectar. Todo se apaga en Opciones > Ajustes. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local function DB() return GuiaAventureroDB end
local function EnCombate() return InCombatLockdown and InCombatLockdown() end
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil

------------------------------------------------------------------------
-- Retrato del PNJ
------------------------------------------------------------------------
local LADO = 58
local retrato = nil

-- "Recoger: Los enanos modistos (Sten Brazofuerte)" -> "Sten Brazofuerte"; un PNJ sin misión ya es su nombre.
local function NombrePNJ(d)
  if not d or type(d.n) ~= "string" then return nil end
  local entre = d.n:match("%(([^%)]+)%)%s*$")
  if entre then return entre end
  if d.npc then return d.n end
  return nil
end

local function CrearRetrato(caja)
  local r = CreateFrame("Frame", nil, caja, PLANTILLA)
  r:SetWidth(LADO); r:SetHeight(LADO)
  r:SetPoint("TOPLEFT", caja, "TOPLEFT", 12, -26)
  if GL.Caja and GL.COLOR then GL.Caja(r, { 0.1, 0.08, 0.06, 1 }, GL.COLOR.activoBorde) end
  r.modelo = CreateFrame("PlayerModel", nil, r)
  r.modelo:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
  r.modelo:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -1, 1)
  r.icono = r:CreateTexture(nil, "ARTWORK")
  r.icono:SetPoint("CENTER", r, "CENTER", 0, 0)
  r.icono:SetWidth(32); r.icono:SetHeight(32)
  -- botón seguro encima: /targetexact solo funciona con el PNJ a la vista (cerca). Cuelga de UIParent y se coloca
  -- fuera de combate con coordenadas fijas, para que mover la ventana en combate no choque con un marco protegido.
  r.boton = CreateFrame("Button", "GuiaAventureroRetratoBoton", UIParent, "SecureActionButtonTemplate")
  r.boton:SetFrameStrata("HIGH")
  r.boton:Hide()
  r.boton:RegisterForClicks("AnyUp", "AnyDown")
  r.boton:SetAttribute("type", "macro")
  r.boton:SetScript("OnEnter", function(self)
    if not GameTooltip or not r.nombre then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(r.nombre, 1, 0.82, 0)
    GameTooltip:AddLine(L"Clic: seleccionarlo (si está cerca).", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  r.boton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return r
end

-- Devuelve el hueco que ocupa el retrato (0 si no hay PNJ o está apagado).
GL.ActualizarRetrato = function(caja, d)
  if DB().retrato == false then
    if retrato then retrato:Hide() end
    return 0
  end
  local nombre = NombrePNJ(d)
  if not nombre then
    if retrato then retrato:Hide() end
    return 0
  end
  if not retrato then
    if EnCombate() then return 0 end
    retrato = CrearRetrato(caja)
  end
  -- 7.6.4: SetCreature(id) enseña en Forever un modelo que no es el del PNJ. El retrato 3D solo sale cuando
  -- lo tienes seleccionado (SetUnit es fiable); si no, el icono de la acción.
  local esObjetivo = UnitName and UnitName("target") == nombre and retrato.modelo.SetUnit and true or false
  if retrato.nombre ~= nombre or retrato.npc ~= d.npc or retrato.esObjetivo ~= esObjetivo then
    retrato.nombre, retrato.npc, retrato.esObjetivo = nombre, d.npc, esObjetivo
    local okM = false
    if esObjetivo then
      if retrato.modelo.ClearModel then retrato.modelo:ClearModel() end
      okM = pcall(retrato.modelo.SetUnit, retrato.modelo, "target")
      if okM and retrato.modelo.SetPortraitZoom then retrato.modelo:SetPortraitZoom(1) end
    end
    if okM then
      retrato.modelo:Show(); retrato.icono:Hide()
    else
      retrato.modelo:Hide()
      if GL.PonerIcono then GL.PonerIcono(retrato.icono, (GL.ICONO_ACCION and GL.ICONO_ACCION[d.a]) or GL.INTERROGANTE, false) end
      retrato.icono:Show()
    end
  end
  if retrato.macro ~= nombre and not EnCombate() then
    retrato.macro = nombre
    retrato.boton:SetAttribute("macrotext", "/targetexact " .. nombre)
  end
  retrato:Show()
  return LADO + 10
end

------------------------------------------------------------------------
-- Ventanas emergentes (celebración y bienvenida)
------------------------------------------------------------------------
-- Coloca el botón seguro sobre el retrato (solo fuera de combate).
local function ColocarBotonRetrato()
  if not retrato or EnCombate() then return end
  local b = retrato.boton
  if not retrato:IsVisible() or not retrato:GetLeft() then b:Hide(); return end
  local k = (retrato:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", retrato:GetLeft() * k, retrato:GetTop() * k)
  b:SetWidth(LADO * k); b:SetHeight(LADO * k)
  b:Show()
end

local function CrearPopup(ancho, y)
  local f = CreateFrame("Frame", nil, UIParent, PLANTILLA)
  f:SetWidth(ancho); f:SetHeight(120)
  f:SetPoint("TOP", UIParent, "TOP", 0, y)
  f:SetFrameStrata("DIALOG")
  if GL.Caja and GL.COLOR then GL.Caja(f, { 0.04, 0.05, 0.07, 0.96 }, GL.COLOR.botonBorde) end
  if GL.Acento then GL.Acento(f, 2) end
  f.titulo = GL.Texto(f, "GameFontNormalLarge", "CENTER")
  f.titulo:SetPoint("TOP", f, "TOP", 0, -14)
  f.texto = GL.Texto(f, "GameFontHighlight", "CENTER")
  f.texto:SetPoint("TOP", f.titulo, "BOTTOM", 0, -8)
  f.texto:SetWidth(ancho - 30)
  f.cerrar = GL.CrearBoton(f, "x", function() f:Hide() end, nil, 18, "cerrar")
  f.cerrar:SetWidth(18)
  f.cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  f:Hide()
  return f
end

-- Celebración
local cel, filasCel = nil, {}
local function Celebrar(titulo, texto, hechizos)
  if DB().celebracion == false then return end
  if not cel then
    cel = CrearPopup(380, -140)
    -- 9.7.9.8: sin la franja dorada de arriba; el panel entero es de un solo color, como los demás avisos
    if cel.titulo.GetFont then
      local fuente, _, op = cel.titulo:GetFont()
      if fuente then cel.titulo:SetFont(fuente, 26, op) end
    end
  end
  cel.titulo:SetText(C.AMARILLO .. titulo .. C.FIN)
  cel.texto:SetText(texto or "")
  for i = 1, #filasCel do filasCel[i]:Hide() end
  local y = -60 - ((cel.texto.GetStringHeight and cel.texto:GetStringHeight()) or 14)
  hechizos = hechizos or {}
  for i = 1, math.min(#hechizos, 6) do
    local h = hechizos[i]
    local f = filasCel[i]
    if not f then
      f = CreateFrame("Frame", nil, cel)
      f:SetHeight(20)
      f.icono = f:CreateTexture(nil, "ARTWORK")
      f.icono:SetWidth(18); f.icono:SetHeight(18)
      f.icono:SetPoint("LEFT", f, "LEFT", 0, 0)
      f.precio = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
      f.precio:SetPoint("RIGHT", f, "RIGHT", 0, 0)
      f.nombre = GL.Texto(f, "GameFontHighlightSmall")
      f.nombre:SetPoint("LEFT", f.icono, "RIGHT", 6, 0)
      f.nombre:SetPoint("RIGHT", f.precio, "LEFT", -6, 0)
      GL.UnaLinea(f.nombre)
      filasCel[i] = f
    end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", cel, "TOPLEFT", 24, y - (i - 1) * 22)
    f:SetPoint("TOPRIGHT", cel, "TOPRIGHT", -24, y - (i - 1) * 22)
    GL.PonerIcono(f.icono, h.icono or GL.INTERROGANTE)
    f.nombre:SetText(h.nombre)
    f.precio:SetText((GL.Dinero and GL.Dinero(h.coste)) or tostring(h.coste))
    f:Show()
  end
  cel:SetHeight(-y + math.min(#hechizos, 6) * 22 + 14)
  cel:Show()
  if GL.Confeti and string.find(titulo, L"Nivel", 1, true) then pcall(GL.Confeti, cel) end   -- 8.9
  if C_Timer and C_Timer.After then
    local este = titulo
    C_Timer.After(20, function() if cel and cel.titulo:GetText() and cel.titulo:GetText():find(este, 1, true) then cel:Hide() end end)
  end
end

local function Duracion(seg)
  seg = math.floor(seg or 0)
  local h, m = math.floor(seg / 3600), math.floor((seg % 3600) / 60)
  if h > 0 then return h .. " h " .. m .. L" min" end
  return math.max(m, 1) .. L" min"
end

local function CelebrarNivel(nivel)
  local db = DB()
  local e = db.estadisticas and db.estadisticas.niveles and db.estadisticas.niveles[nivel - 1]
  local texto = nil
  if e and e.t and e.t >= 60 then
    texto = L"El nivel " .. (nivel - 1) .. L" te llevó " .. C.AMARILLO .. Duracion(e.t) .. C.FIN .. " y " .. C.AMARILLO .. (e.q or 0) ..
      L" misiones" .. C.FIN .. " (" .. math.floor(e.xp / e.t * 3600) .. L" XP/h)."
  end
  local hechizos = GL.HechizosNuevos and GL.HechizosNuevos(nivel) or {}
  if #hechizos > 0 then
    texto = (texto and (texto .. "\n") or "") .. C.GRIS .. L"Ya puedes entrenar " .. (#hechizos == 1 and L"1 hechizo nuevo:" or (#hechizos .. L" hechizos nuevos:")) .. C.FIN
  end
  Celebrar(L"¡Nivel " .. nivel .. "!", texto, hechizos)
end

local seccionAnt = nil
local function MirarSeccion()
  local db = DB()
  if type(db) ~= "table" or not db.seccion then return end
  if seccionAnt and db.seccion == seccionAnt + 1 and GL.RUTA and GL.RUTA.secciones then
    local hecha, sig = GL.RUTA.secciones[seccionAnt], GL.RUTA.secciones[db.seccion]
    local okT, mostrada = false, false
    if GL.TarjetaSeccion then okT, mostrada = pcall(GL.TarjetaSeccion, seccionAnt, db.seccion) end   -- 8.8: tarjeta tipo logro
    if hecha and sig and not (okT and mostrada) then
      Celebrar(L"¡Sección completada!", C.BLANCO .. hecha.titulo .. C.FIN .. "\n" .. C.GRIS .. L"Ahora: " .. sig.titulo ..
        L" (niveles " .. sig.min .. "-" .. sig.max .. ")" .. C.FIN)
    end
  end
  seccionAnt = db.seccion
end

-- Bienvenida
local bien = nil
local function Bienvenida()
  local db = DB()
  if type(db) ~= "table" or db.bienvenida == false or not GL.RUTA or not db.seccion then return end
  if type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.bienvenida == false then return end   -- 9.0: apagada para toda la cuenta
  -- 9.0: si va a salir el tutorial, no sale también la bienvenida (una sola ventana al conectar)
  if not (type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.tutorial == false) then return end
  if (db.seccion or 1) == 1 and (db.paso or 1) <= 1 then return end   -- personaje nuevo: no hay nada que retomar
  local s = GL.RUTA.secciones[db.seccion]
  if not s then return end
  if not bien then
    bien = CrearPopup(360, -120)
    bien.seguir = GL.CrearBoton(bien, L"Seguir", function()
      bien:Hide()
      if GL.MostrarVentanaCompletaR10 then GL.MostrarVentanaCompletaR10() else
    if GL.frame then GL.frame:Show(); db.oculto = false end
  end
      if GL.AbrirModo then GL.AbrirModo("guia") end
    end, nil, 22, "accion")
    bien.seguir:SetWidth(150)
    bien.seguir:SetPoint("BOTTOMRIGHT", bien, "BOTTOM", -3, 12)
    bien.cerrar2 = GL.CrearBoton(bien, L"Cerrar", function() bien:Hide() end, nil, 22)
    bien.cerrar2:SetWidth(150)
    bien.cerrar2:SetPoint("BOTTOMLEFT", bien, "BOTTOM", 3, 12)
    -- 9.0: se puede quitar desde la propia ventana (para toda la cuenta); vuelve en Ajustes › General
    bien.nunca = GL.CrearBoton(bien, L"No volver a mostrar", function()
      if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
      GuiaAventureroCuenta.bienvenida = false
      bien:Hide()
      if GL.Mensaje then GL.Mensaje(L"la bienvenida ya no saldrá al conectar. Se vuelve a activar en Ajustes › General.") end
    end, nil, 18)
    bien.nunca:SetWidth(160)
    bien.nunca:SetPoint("BOTTOM", bien, "BOTTOM", 0, 40)
    if GL.Ayuda then GL.Ayuda(bien.nunca, L"No volver a mostrar", L"Quita esta ventana en todos tus personajes. Se vuelve a activar en Ajustes › General › Bienvenida al conectar.") end
  end
  local nombre = (UnitName and UnitName("player")) or "aventurero"
  local texto = L"Lo dejaste en " .. C.AMARILLO .. s.titulo .. C.FIN .. L", paso " .. db.paso .. L" de la sección " .. db.seccion .. "."
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  local e = db.estadisticas and db.estadisticas.niveles and db.estadisticas.niveles[nivel]
  local xp, max = UnitXP and UnitXP("player"), UnitXPMax and UnitXPMax("player")
  local t, g = 0, 0
  if db.estadisticas and db.estadisticas.niveles then
    for _, d in pairs(db.estadisticas.niveles) do t, g = t + (d.t or 0), g + (d.xp or 0) end
  end
  if type(xp) == "number" and type(max) == "number" and max > xp and t >= 600 and g > 0 then
    texto = texto .. L"\nTe faltan unos " .. C.VERDE .. Duracion((max - xp) / (g / t)) .. C.FIN .. L" para el nivel " .. (nivel + 1) .. "."
  end
  bien.titulo:SetText(C.AMARILLO .. L"De vuelta, " .. nombre .. C.FIN)
  bien.texto:SetText(texto)
  bien:SetHeight(116 + ((bien.texto.GetStringHeight and bien.texto:GetStringHeight()) or 30))
  bien:Show()
end

------------------------------------------------------------------------
-- Destinos del paso en el minimapa
------------------------------------------------------------------------
-- Diámetro del minimapa en yardas según el zoom (fuera y dentro de edificios), como en el cliente clásico.
local DIAMETRO = { [false] = { 466.67, 400, 333.33, 266.67, 200, 133.33 }, [true] = { 300, 240, 180, 120, 80, 50 } }
local pines = {}

local function Pin(i)
  if pines[i] then return pines[i] end
  local p = CreateFrame("Frame", nil, Minimap)
  p:SetWidth(14); p:SetHeight(14)
  p:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
  p.t = p:CreateTexture(nil, "OVERLAY")
  p.t:SetAllPoints()
  p:Hide()
  pines[i] = p
  return p
end

local function OcultarDesde(n)
  for i = n, #pines do if pines[i]:IsShown() then pines[i]:Hide() end end
end

local function ActualizarMinimapa()
  local db = DB()
  if type(db) ~= "table" or db.minimapaDestinos == false or not Minimap or not GL.PasoActual or not GL.Vector then OcultarDesde(1); return end
  local okP, _, p = pcall(GL.PasoActual)
  if not okP or not p or not p.wp then OcultarDesde(1); return end
  local dentro = IsIndoors and IsIndoors() and true or false
  local zoom = (Minimap.GetZoom and Minimap:GetZoom()) or 0
  local diam = DIAMETRO[dentro][zoom + 1] or 466.67
  local radio = (Minimap:GetWidth() or 140) / 2
  local girar = GetCVar and GetCVar("rotateMinimap") == "1"
  local cara = girar and GetPlayerFacing and GetPlayerFacing() or 0
  local n = 0
  for _, d in ipairs(p.wp) do
    if d.m and GL.DestinoHecho(d) ~= true then
      local este, sur = GL.Vector(d)
      if type(este) == "number" then
        local x, y = este, -sur
        if girar and cara then
          local c, s = math.cos(cara), math.sin(cara)
          x, y = x * c + y * s, -x * s + y * c
        end
        local px, py = x / (diam / 2) * radio, y / (diam / 2) * radio
        local dist = math.sqrt(px * px + py * py)
        if dist > radio - 6 then px, py = px / dist * (radio - 6), py / dist * (radio - 6) end   -- lejos: en el borde
        n = n + 1
        local pin = Pin(n)
        GL.PonerIcono(pin.t, (GL.ICONO_ACCION and GL.ICONO_ACCION[d.a]) or GL.ICONO_LUGAR, false)
        pin:SetAlpha(dist > radio - 6 and 0.6 or 1)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", Minimap, "CENTER", px, py)
        if not pin:IsShown() then pin:Show() end
      end
    end
  end
  OcultarDesde(n + 1)
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
GL.Evento(ev, "PLAYER_LEVEL_UP")
GL.Evento(ev, "PLAYER_ENTERING_WORLD")
GL.Evento(ev, "PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, evento, a1)
  if type(DB()) ~= "table" then return end
  if evento == "PLAYER_REGEN_DISABLED" then
    if retrato then retrato.boton:Hide() end   -- en combate no se puede tocar; se vuelve a poner al acabar
  elseif evento == "PLAYER_LEVEL_UP" then
    local nivel = GL.NivelJugadorR14(a1)
    if not nivel then return end
    if C_Timer and C_Timer.After then C_Timer.After(1, function() pcall(CelebrarNivel, nivel) end) else pcall(CelebrarNivel, nivel) end
  elseif evento == "PLAYER_ENTERING_WORLD" and a1 then   -- solo al conectar, no al cambiar de zona
    if C_Timer and C_Timer.After then C_Timer.After(4, function() pcall(Bienvenida) end) end
  end
end)
local espera = 0
ev:SetScript("OnUpdate", function(_, dt)
  espera = espera + dt
  if espera < 0.1 then return end
  espera = 0
  pcall(ActualizarMinimapa)
  -- 9.7.6: section and portrait checks do not need ten calls per second.
  ev.ga976Lento = (ev.ga976Lento or 0) + 0.1
  if ev.ga976Lento >= 0.5 then
    ev.ga976Lento = 0
    pcall(MirarSeccion)
    pcall(ColocarBotonRetrato)
  end
end)

-- Para las pruebas
GL._exp = { Celebrar = Celebrar, CelebrarNivel = CelebrarNivel, Bienvenida = Bienvenida, Minimapa = ActualizarMinimapa,
  NombrePNJ = NombrePNJ, MirarSeccion = MirarSeccion }

------------------------------------------------------------------------
-- 7.2: enlace de misión con Shift+clic, seguimiento automático de las misiones del paso, sonidos y primer uso
------------------------------------------------------------------------
-- Enlace de chat de una misión: "[Nombre]" en amarillo, como los que pone el juego.
local function EnlaceMision(q, nombre)
  if not q then return nil end
  if GetQuestLink then
    local ok, l = pcall(GetQuestLink, q)
    if ok and type(l) == "string" and l ~= "" then return l end
  end
  local titulo = nil
  if C_QuestLog and C_QuestLog.GetQuestInfo then
    local ok, t = pcall(C_QuestLog.GetQuestInfo, q)
    if ok and type(t) == "string" and t ~= "" then titulo = t end
  end
  titulo = titulo or (nombre and (nombre:match(":%s*(.-)%s*%(") or nombre:match(":%s*(.+)$")) or nombre) or (L"Misión " .. q)
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  return "|cffffff00|Hquest:" .. q .. ":" .. nivel .. "|h[" .. titulo .. "]|h|r"
end

GL.EnlazarMision = function(d)
  if not (d and d.q) then return false end
  local l = EnlaceMision(d.q, d.n)
  if not l then return false end
  if ChatEdit_InsertLink and ChatEdit_InsertLink(l) then return true end
  if ChatFrame_OpenChat then ChatFrame_OpenChat(l); return true end
  return false
end

-- Misiones del paso en el seguimiento de misiones. Solo quita las que puso el addon.
local function IndiceMision(q)
  if GetQuestLogIndexByID then
    local ok, i = pcall(GetQuestLogIndexByID, q)
    if ok and type(i) == "number" and i > 0 then return i end
  end
  return nil
end

-- Ownership is session-local: saved watches may have been changed by another addon.
local vigiladasPropias = {}
local function EstadoVigilada(i)
  local ok, v = pcall(IsQuestWatched, i)
  if not ok then return nil end
  if type(issecretvalue)=="function" then
    local comprobado, secreto=pcall(issecretvalue,v)
    if not comprobado or secreto then return nil end
  end
  if v==true or v==1 then return true end
  if v==false or v==0 then return false end
  return nil
end
local function SeguirMisionesPaso()
  local db = DB()
  if type(db) ~= "table" then return end
  if db.autoSeguimiento == false or (GL.QuestieConvivencia976 and GL.QuestieConvivencia976()) then
    -- Do not remove watches: Questie or the player may now be using them.
    vigiladasPropias = {}
    db.vigiladas = {}
    return
  end
  if not GL.PasoActual or not (AddQuestWatch and RemoveQuestWatch and IsQuestWatched) then return end
  local _, p = GL.PasoActual()
  if not p then return end
  local delPaso = {}
  for _, d in ipairs(p.wp or {}) do
    if d.q and (d.a == "C" or d.a == "T") then delPaso[d.q] = true end
  end
  for q in pairs(vigiladasPropias) do
    local i = IndiceMision(q)
    if not i then
      vigiladasPropias[q] = nil
    elseif not delPaso[q] then
      local v = EstadoVigilada(i)
      if v == true then pcall(RemoveQuestWatch, i); v = EstadoVigilada(i) end
      if v == false then vigiladasPropias[q] = nil end
    elseif EstadoVigilada(i) == false then
      vigiladasPropias[q] = nil
    end
  end
  for q in pairs(delPaso) do
    local i = IndiceMision(q)
    if i and EstadoVigilada(i) == false then
      local ok = pcall(AddQuestWatch, i)
      if ok and EstadoVigilada(i) == true then vigiladasPropias[q] = true end
    end
  end
  db.vigiladas = {} -- legacy field: never persist ownership across sessions
end
GL.ActualizarSeguimiento976 = SeguirMisionesPaso

-- Sonidos (apagados por defecto)
local SONIDO = {
  llegar = (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175,
  objetivo = (SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE) or 619,
  paso = (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960,
}
local function Sonar(tipo)
  local db = DB()
  if type(db) ~= "table" or db.sonidos ~= true or not PlaySound then return end
  pcall(PlaySound, SONIDO[tipo], "Master")
end

local ultimaLlegada = nil
GL.AlLlegar = function(d)
  if not d then return end
  local clave = tostring(d.n) .. (d.x or 0) .. (d.y or 0)
  if clave == ultimaLlegada then return end   -- una vez por destino
  ultimaLlegada = clave
  Sonar("llegar")
end

local pasoAnt, hechosAnt = nil, nil
local function MirarPaso()
  local db = DB()
  if type(db) ~= "table" or not (GL.PasoActual and GL.DestinoHecho) then return end
  local clave = tostring(db.seccion) .. ":" .. tostring(db.paso)
  local _, p = GL.PasoActual()
  local hechos = 0
  for _, d in ipairs((p and p.wp) or {}) do
    if d.a == "C" and GL.DestinoHecho(d) == true then hechos = hechos + 1 end
  end
  if pasoAnt and clave ~= pasoAnt then
    Sonar("paso")
    pcall(SeguirMisionesPaso)
  elseif pasoAnt and hechosAnt and hechos > hechosAnt then
    Sonar("objetivo")
  end
  pasoAnt, hechosAnt = clave, hechos
end

-- Primer uso: cuatro pantallas cortas para quien abre el addon por primera vez.
local PRIMER_USO = {
  { "Tu paso", "La caja de arriba dice qué hacer ahora. Debajo están los objetivos: clic en uno para seguirlo, posponerlo o ignorarlo. Con Shift+clic enlazas la misión en el chat." },
  { "La flecha", "Te lleva al objetivo y cambia de color con la distancia: verde cerca, amarillo a media distancia y rojo lejos. También te dice el rumbo." },
  { "Las guías", "Los botones de la derecha abren la Guía, la Reputación, las Mazmorras y la Biblioteca." },
  { "Opciones", "En Opciones > Ajustes cambias el tema, el tamaño y lo que se muestra: retrato, celebraciones, sonidos y seguimiento de misiones." },
}
local guia = nil
local function MostrarPrimerUso(i)
  if not guia then
    guia = CrearPopup(380, -300)   -- 7.3: más abajo que la bienvenida, que sale a la vez
    guia.paso = GL.Texto(guia, "GameFontHighlightSmall", "LEFT")
    guia.paso:SetPoint("TOPLEFT", guia, "TOPLEFT", 10, -8)
    guia.ant = GL.CrearBoton(guia, L"Anterior", function() MostrarPrimerUso(guia.i - 1) end, nil, 22)
    guia.ant:SetWidth(110)
    guia.ant:SetPoint("BOTTOMLEFT", guia, "BOTTOMLEFT", 12, 40)
    guia.sig = GL.CrearBoton(guia, L"Siguiente", function()
      if guia.i >= #PRIMER_USO then guia:Hide() else MostrarPrimerUso(guia.i + 1) end
    end, nil, 22, "accion")
    guia.sig:SetWidth(110)
    guia.sig:SetPoint("BOTTOMRIGHT", guia, "BOTTOMRIGHT", -12, 40)
    -- 7.3: la x y Empezar solo lo cierran; Desactivar tutorial lleva a la opción de Ajustes (para toda la cuenta)
    guia.desactivar = GL.CrearBoton(guia, L"Desactivar tutorial", function()
      guia:Hide()
      if GL.ResaltarAjuste then GL.ResaltarAjuste("tutorial") end
    end, nil, 22)
    guia.desactivar:SetPoint("BOTTOMLEFT", guia, "BOTTOMLEFT", 12, 12)
    guia.desactivar:SetPoint("BOTTOMRIGHT", guia, "BOTTOMRIGHT", -12, 12)
    GL.Ayuda(guia.desactivar, L"Desactivar tutorial", L"Abre Opciones > Ajustes: quita la marca de Mostrar el tutorial para no verlo más en esta cuenta.")
  end
  i = math.max(1, math.min(i or 1, #PRIMER_USO))
  guia.i = i
  guia.paso:SetText(C.GRIS .. i .. L" de " .. #PRIMER_USO .. C.FIN)
  guia.titulo:SetText(C.AMARILLO .. L(PRIMER_USO[i][1]) .. C.FIN)
  guia.texto:SetText(L(PRIMER_USO[i][2]))
  if guia.ant.SetEnabled then guia.ant:SetEnabled(i > 1) end
  if guia.ant.SetAlpha then guia.ant:SetAlpha(i > 1 and 1 or 0.4) end
  if guia.sig.texto then guia.sig.texto:SetText(i == #PRIMER_USO and L"Empezar" or L"Siguiente") end
  guia.ant:SetWidth(170); guia.sig:SetWidth(170)
  guia:SetHeight(120 + ((guia.texto.GetStringHeight and guia.texto:GetStringHeight()) or 30))
  guia:Show()
end
GL.comandos["tutorial"] = function() if GL.Tutorial9 then GL.Tutorial9(1) else MostrarPrimerUso(1) end end   -- 9.0

local ev2 = CreateFrame("Frame")
GL.Evento(ev2, "PLAYER_ENTERING_WORLD")
GL.Evento(ev2, "QUEST_ACCEPTED")
ev2:SetScript("OnEvent", function(_, evento, a1)
  local db = DB()
  if type(db) ~= "table" then return end
  if evento == "QUEST_ACCEPTED" then
    if C_Timer and C_Timer.After then C_Timer.After(0.5, function() pcall(SeguirMisionesPaso) end) else pcall(SeguirMisionesPaso) end
  elseif a1 then
    pcall(SeguirMisionesPaso)
    if not (type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.tutorial == false) and C_Timer and C_Timer.After then   -- 7.3: a todos
      C_Timer.After(4, function() pcall(GL.Tutorial9 or MostrarPrimerUso, 1) end)   -- 9.0: tutorial nuevo
    end
  end
end)
local espera2 = 0
ev2:SetScript("OnUpdate", function(_, dt)
  espera2 = espera2 + dt
  if espera2 < 0.5 then return end
  espera2 = 0
  pcall(MirarPaso)
end)

GL._exp.EnlaceMision, GL._exp.Seguir, GL._exp.PrimerUso, GL._exp.MirarPaso = EnlaceMision, SeguirMisionesPaso, MostrarPrimerUso, MirarPaso

------------------------------------------------------------------------
-- 7.4: nota propia en cada paso (botón Nota de la caja del paso)
------------------------------------------------------------------------
local editor = nil
GL.EditarNota = function()
  local db = DB()
  if type(db) ~= "table" or not db.seccion then return end
  local clave = db.seccion .. ":" .. db.paso
  if not editor then
    editor = CrearPopup(380, -160)
    local caja = CreateFrame("EditBox", nil, editor, PLANTILLA)
    caja:SetHeight(24)
    caja:SetPoint("TOPLEFT", editor, "TOPLEFT", 14, -44)
    caja:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -14, -44)
    caja:SetAutoFocus(false)
    caja:SetMaxLetters(200)
    caja:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    caja:SetTextInsets(6, 6, 0, 0)
    if GL.Caja and GL.COLOR then GL.Caja(caja, { 0, 0, 0, 0.4 }, GL.COLOR.botonBorde) end
    local function Guardar()
      local t = (caja:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
      local actual = DB()
      if actual ~= editor.db or actual.ruta ~= editor.ruta then caja:ClearFocus(); editor:Hide(); return end
      if type(actual.notas) ~= "table" then actual.notas = {} end
      actual.notas[editor.clave] = (t ~= "") and t or nil
      caja:ClearFocus(); editor:Hide()
      if GL.Refrescar then GL.Refrescar() end
    end
    caja:SetScript("OnEnterPressed", Guardar)
    caja:SetScript("OnEscapePressed", function(self) self:ClearFocus(); editor:Hide() end)
    editor.caja = caja
    editor.guardar = GL.CrearBoton(editor, L"Guardar", Guardar, nil, 22, "accion")
    editor.guardar:SetWidth(110)
    editor.guardar:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -14, 12)
    editor.borrar = GL.CrearBoton(editor, L"Borrar", function() caja:SetText(""); Guardar() end, nil, 22)
    editor.borrar:SetWidth(110)
    editor.borrar:SetPoint("RIGHT", editor.guardar, "LEFT", -6, 0)
    editor:SetHeight(112)
  end
  editor.clave, editor.db, editor.ruta = clave, db, db.ruta
  editor.titulo:SetText(C.AMARILLO .. L"Tu nota del paso " .. db.paso .. C.FIN)
  editor.texto:SetText("")
  editor.caja:SetText((db.notas and db.notas[clave]) or "")
  editor:Show()
  editor.caja:SetFocus()
end

-- 7.6.4: al cambiar de objetivo se repinta el retrato (modelo 3D solo del PNJ seleccionado).
local evObj = CreateFrame("Frame")
GL.Evento(evObj, "PLAYER_TARGET_CHANGED")
evObj:SetScript("OnEvent", function()
  if retrato and retrato:IsShown() and GL.ProgramarRefresco then pcall(GL.ProgramarRefresco) end
end)

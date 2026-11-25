-- Mapa.lua: marcas de los destinos en el mapa. Creado por JKRiveroF.
-- 1) Pone el punto de ruta del propio juego en el destino de la flecha (se ve en el mapa, en el minimapa
--    y como marca en pantalla con la distancia).
-- 2) Dibuja en el mapa del mundo todos los destinos del paso con su icono (recoger, objetivo, entregar).

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local LADO_PIN = 18

local ultimaMarca                     -- "mapa:x:y" del último punto de ruta que pusimos
local pines = {}
local puntosRuta = {}   -- 8.8: puntos de la línea que une los destinos en el mapa
local enganchado = false

local function DB() return GuiaAventureroDB end
local function Secreto(v) return issecretvalue and issecretvalue(v) end
local function NumeroValido(v)
  return not Secreto(v) and type(v) == "number" and v > -math.huge and v < math.huge
end

------------------------------------------------------------------------
-- Punto de ruta del juego
------------------------------------------------------------------------
local function PuedePoner(mapa)
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
  if C_Map.CanSetUserWaypointOnMap then
    local ok, r = pcall(C_Map.CanSetUserWaypointOnMap, mapa)
    return ok and not Secreto(r) and r == true
  end
  return true
end

local function LeerMarca()
  if not (C_Map and C_Map.GetUserWaypoint) then return false end
  local ok, p = pcall(C_Map.GetUserWaypoint)
  if not ok or Secreto(p) then return false end
  return true, p
end
local function MarcaPropia(p)
  if not ultimaMarca then return false end
  if not p then
    local ok; ok,p=LeerMarca(); if not ok then return false end
  end
  if Secreto(p) or not p or Secreto(p.position) or not p.position then return false end
  local m,x,y=ultimaMarca:match("^([^:]+):([^:]+):([^:]+)$")
  local px,py=p.position.x,p.position.y
  if p.position.GetXY then local k,a,b=pcall(p.position.GetXY,p.position); if k then px,py=a,b end end
  return NumeroValido(p.uiMapID) and tonumber(m)==p.uiMapID and NumeroValido(px) and NumeroValido(py) and math.abs(px-tonumber(x)/100)<0.00001 and math.abs(py-tonumber(y)/100)<0.00001
end
function GL.LiberarMarcaPropia976()
  local ok,p=LeerMarca()
  if not ok then return end -- conservar propiedad si no podemos verificarla
  if p and MarcaPropia(p) then
    if not C_Map.ClearUserWaypoint or not pcall(C_Map.ClearUserWaypoint) then return end
  end
  ultimaMarca=nil
end
-- Se llama tras cada refresco: solo cambia el punto si el destino ha cambiado (así respeta el que pongas tú).
function GL.ActualizarMarca(forzar)
  local db = DB()
  if not db then return end
  if GL.QuestieConvivencia976 and GL.QuestieConvivencia976() then if ultimaMarca then GL.LiberarMarcaPropia976() end; return end
  if db.marcaMapa == false then
    if ultimaMarca then GL.LiberarMarcaPropia976() end
    return
  end
  local d = GL.DestinoActual()
  if not d or not NumeroValido(d.m) or d.m <= 0 or d.m % 1 ~= 0 then
    if ultimaMarca then GL.LiberarMarcaPropia976() end
    return
  end
  if not NumeroValido(d.x) or not NumeroValido(d.y) or not (d.x>=0 and d.x<=100 and d.y>=0 and d.y<=100) then return end
  local leida,p=LeerMarca()
  if not leida then return end -- no sobrescribir un marcador que no podemos inspeccionar
  if p and not MarcaPropia(p) then ultimaMarca=nil; return end
  local clave = d.m .. ":" .. d.x .. ":" .. d.y
  if p and clave == ultimaMarca and not forzar then return end
  if not PuedePoner(d.m) then return end
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(d.m, d.x / 100, d.y / 100))
  end)
  if ok then
    ultimaMarca = clave
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      -- No desplazar una misión seleccionada por el jugador u otro addon.
      local libre = true
      if C_SuperTrack.GetSuperTrackedQuestID then
        local leido, q = pcall(C_SuperTrack.GetSuperTrackedQuestID)
        libre = leido and NumeroValido(q) and q == 0
      end
      if libre then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
    end
  end
end

-- 9.4.2: marcador en pantalla como en retail (CVar showInGameNavigation del cliente).
-- Al entrar solo lo enciende si el ajuste está activado; lo apaga solo cuando quitas la casilla.
function GL.AplicarMarcaPantalla(desdeAjuste)
  local db = DB()
  if not (db and SetCVar) or (GL.QuestieConvivencia976 and GL.QuestieConvivencia976()) then return end
  local quiere = db.marcaPantalla ~= false
  if not quiere and not desdeAjuste then return end
  local valor = quiere and "1" or "0"
  local ok, actual = false, nil
  if GetCVar then ok, actual = pcall(GetCVar, "showInGameNavigation") end
  if ok and not Secreto(actual) and actual ~= valor then pcall(SetCVar, "showInGameNavigation", valor) end
end

-- La distancia del marcador sale en metros (el juego la da en yardas): «450 m», «1.8 km».
local function TextoMarcador(yd)
  local m = math.floor(yd * 0.9144 + 0.5)
  if m >= 1000 then return string.format(L"%.1f km", m / 1000) end
  return m .. " m"
end
local marcadorEnganchado = false
function GL.EngancharMarcador()
  if marcadorEnganchado then return end
  local f = SuperTrackedFrame
  if not (f and f.HookScript) then return end
  marcadorEnganchado = true
  local espera, ultimoTexto = 0, nil
  f:HookScript("OnUpdate", function(self, dt)
    espera = espera + (dt or 0)
    if espera < 0.2 then return end
    espera = 0
    if GL.QuestieConvivencia976 and GL.QuestieConvivencia976() then ultimoTexto=nil; return end
    local db = DB()
    if not db or db.marcaPantalla == false then return end
    -- Sin prueba de propiedad no modificar el texto compartido del cliente.
    if not MarcaPropia() then ultimoTexto=nil; return end
    if C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint then
      local ok, siguiendo = pcall(C_SuperTrack.IsSuperTrackingUserWaypoint)
      if not ok or Secreto(siguiendo) or siguiendo ~= true then ultimoTexto=nil; return end
    end
    local texto = self.DistanceText
    if not (texto and texto.SetText and C_Navigation and C_Navigation.GetDistance) then return end
    local ok, yd = pcall(C_Navigation.GetDistance)
    if ok and NumeroValido(yd) and yd > 0 then
      local nuevo = TextoMarcador(yd)
      if nuevo ~= ultimoTexto or (texto.GetText and texto:GetText() ~= nuevo) then texto:SetText(nuevo); ultimoTexto=nuevo end
    end
  end)
end

------------------------------------------------------------------------
-- Destinos del paso en el mapa del mundo
------------------------------------------------------------------------
local function CrearPin(lienzo)
  local pin = CreateFrame("Button", nil, lienzo)
  pin:SetWidth(LADO_PIN)
  pin:SetHeight(LADO_PIN)
  pin.fondo = pin:CreateTexture(nil, "BACKGROUND")
  pin.fondo:SetPoint("TOPLEFT", pin, "TOPLEFT", -3, 3)
  pin.fondo:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 3, -3)
  pin.fondo:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  pin.icono = pin:CreateTexture(nil, "ARTWORK")
  pin.icono:SetAllPoints(pin)
  pin.numero = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  GL.Ayuda(pin)
  -- clic: la flecha apunta aquí; si ya apuntaba a uno de este sitio, pasa al siguiente del mismo sitio
  pin:SetScript("OnClick", function(self)
    local db = GuiaAventureroDB
    local g, destino = self.grupo or { self.indice }, self.indice
    for k = 1, #g do
      if g[k] == db.destino and #g > 1 then destino = g[k % #g + 1] end
    end
    db.destino = destino
    GL.Refrescar()
  end)
  return pin
end

local function PonerIconoDestino(textura, d)
  local hecho = GL.DestinoHecho(d)
  if hecho then
    GL.PonerIcono(textura, GL.ICONO_HECHO, false)
  elseif d.a and GL.ICONO_ACCION[d.a] then
    GL.PonerIcono(textura, GL.ICONO_ACCION[d.a], false)
  else
    GL.PonerIcono(textura, GL.ICONO_LUGAR)
  end
  textura:SetAlpha(hecho and 0.6 or 1)
end

-- Texto de ayuda de un destino: estado y progreso de su misión.
local function EstadoDestino(d)
  local hecho = GL.DestinoHecho(d)
  local _, detalle = GL.ProgresoDestino(d, hecho)
  local t = hecho and (C.VERDE .. L"Hecho" .. C.FIN) or ""
  if detalle and detalle ~= "" then t = t .. (t ~= "" and "\n" or "") .. detalle end
  return t
end

-- 8.8: línea de puntos que une en orden los destinos que quedan del paso (desde el de la flecha)
local SEPARACION, MAX_PUNTOS = 9, 400
local ordenRuta = {}
local function DibujarRuta(lienzo, idMapa, p, escala, ancho, alto)
  if DB().rutaMapa == false then return end
  local orden = ordenRuta
  for i = #orden, 1, -1 do orden[i] = nil end
  local desde = DB().destino or 1
  for i = desde, #p.wp do
    local d = p.wp[i]
    if d.m == idMapa and not GL.DestinoHecho(d) then
      local u = orden[#orden]
      if not u or math.abs(u.x - d.x) > 0.3 or math.abs(u.y - d.y) > 0.3 then table.insert(orden, d) end
    end
  end
  local usados = 0
  local ac = GL.COLOR.acento
  -- los puntos van en un marco por encima del mapa (las texturas del propio lienzo quedan debajo de las teselas)
  if not puntosRuta.capa or puntosRuta.capa:GetParent() ~= lienzo then
    if puntosRuta.capa then puntosRuta.capa:Hide() end
    for i = #puntosRuta, 1, -1 do puntosRuta[i] = nil end
    puntosRuta.capa = CreateFrame("Frame", nil, lienzo)
    puntosRuta.capa:SetAllPoints(lienzo)
  end
  local capa = puntosRuta.capa
  capa:SetFrameLevel((lienzo:GetFrameLevel() or 1) + 1999)
  capa:Show()
  for n = 2, #orden do
    local a, b = orden[n - 1], orden[n]
    -- en unidades del lienzo (sin escala): el punto y la separación se dividen por la escala para verse igual con zoom
    local x1, y1 = a.x / 100 * ancho, -a.y / 100 * alto
    local x2, y2 = b.x / 100 * ancho, -b.y / 100 * alto
    local largo = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) * escala
    local cuantos = math.floor(largo / SEPARACION)
    for k = 1, cuantos - 1 do
      if usados >= MAX_PUNTOS then return end
      usados = usados + 1
      local t = puntosRuta[usados]
      if not t then
        t = capa:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        puntosRuta[usados] = t
      end
      t:SetWidth(4 / escala); t:SetHeight(4 / escala)
      t:SetVertexColor(ac[1], ac[2], ac[3], 0.85)
      t:ClearAllPoints()
      local f = k / cuantos
      t:SetPoint("CENTER", lienzo, "TOPLEFT", x1 + (x2 - x1) * f, y1 + (y2 - y1) * f)
      t:Show()
    end
  end
end

-- Las listas se reutilizan; cada pin conserva su grupo hasta el siguiente refresco.
local grupos, porSitio, reservaGrupos, numeros = {}, {}, {}, {}
local function OcultarDesde(n)
  for i = n, #pines do pines[i]:Hide(); pines[i].grupo = nil end
end
function GL.ActualizarPines()
  local mapa = WorldMapFrame
  for i = 1, #puntosRuta do puntosRuta[i]:Hide() end
  if not mapa or not mapa.IsShown or not mapa:IsShown() or not DB() or DB().pinesMapa == false or (GL.QuestieConvivencia976 and GL.QuestieConvivencia976()) then OcultarDesde(1); return end
  if not (mapa.GetMapID and mapa.GetCanvas) then OcultarDesde(1); return end
  local idMapa = mapa:GetMapID()
  local lienzo = mapa:GetCanvas()
  if not idMapa or not lienzo then OcultarDesde(1); return end
  local _, p = GL.PasoActual()
  if not p or not p.wp then OcultarDesde(1); return end
  -- los destinos en el mismo sitio (un PNJ que da o recoge varias misiones) van en un solo icono
  for k in pairs(porSitio) do porSitio[k] = nil end
  for i = #grupos, 1, -1 do
    local g = grupos[i]
    for j = #g, 1, -1 do g[j] = nil end
    reservaGrupos[#reservaGrupos + 1] = g
    grupos[i] = nil
  end
  for i = 1, #p.wp do
    local d = p.wp[i]
    if d.m == idMapa then
      local clave = string.format("%.1f:%.1f", d.x, d.y)
      if not porSitio[clave] then
        porSitio[clave] = table.remove(reservaGrupos) or {}
        table.insert(grupos, porSitio[clave])
      end
      table.insert(porSitio[clave], i)
    end
  end
  local escala = lienzo:GetScale() or 1
  if escala <= 0 then escala = 1 end
  local ancho, alto = lienzo:GetWidth(), lienzo:GetHeight()
  local actual = DB().destino
  for n = 1, #grupos do
    local g = grupos[n]
    -- el icono es el del destino de la flecha si está aquí; si no, el del primero que falte
    local principal
    for k = 1, #g do
      if g[k] == actual then principal = g[k] end
    end
    for k = 1, #g do
      if not principal and not GL.DestinoHecho(p.wp[g[k]]) then principal = g[k] end
    end
    principal = principal or g[1]
    local d = p.wp[principal]
    local pin = pines[n]
    if not pin then
      pin = CrearPin(lienzo)
      pines[n] = pin
    end
    pin:SetParent(lienzo)
    pin:SetScale(1 / escala)                        -- mismo tamaño en pantalla con cualquier zoom
    pin:SetFrameLevel((lienzo:GetFrameLevel() or 1) + 2000)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", lienzo, "TOPLEFT", d.x / 100 * ancho * escala, -d.y / 100 * alto * escala)
    PonerIconoDestino(pin.icono, d)
    pin.indice, pin.grupo = principal, g
    for k = #numeros, 1, -1 do numeros[k] = nil end
    for k = 1, #g do
      numeros[k] = (g[k] == actual and C.AMARILLO or C.BLANCO) .. g[k] .. C.FIN
    end
    pin.numero:ClearAllPoints()
    if #g == 1 then
      pin.numero:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 4, -3)
    else
      pin.numero:SetPoint("LEFT", pin, "RIGHT", 1, -3)
    end
    pin.numero:SetText(table.concat(numeros, C.GRIS .. "," .. C.FIN))
    local texto = string.format("%.1f, %.1f", d.x, d.y)
    if #g == 1 then
      pin.ayudaTitulo = d.n
      local estado = EstadoDestino(d)
      if estado ~= "" then texto = texto .. "\n" .. estado end
      texto = texto .. "\n" .. C.GRIS .. L"Clic: la flecha apunta aquí." .. C.FIN
    else
      pin.ayudaTitulo = #g .. L" destinos en este sitio"
      for k = 1, #g do
        local dk = p.wp[g[k]]
        texto = texto .. "\n" .. (g[k] == actual and C.AMARILLO or C.BLANCO) .. g[k] .. ". " .. dk.n .. C.FIN
        local estado = EstadoDestino(dk)
        if estado ~= "" then texto = texto .. "\n    " .. string.gsub(estado, "\n", "\n    ") end
      end
      texto = texto .. "\n" .. C.GRIS .. L"Clic: la flecha apunta aquí (otro clic, al siguiente de este sitio)." .. C.FIN
    end
    pin.ayudaTexto = texto
    pin:Show()
  end
  OcultarDesde(#grupos + 1)
  pcall(DibujarRuta, lienzo, idMapa, p, escala, ancho, alto)
end

local function Enganchar()
  if enganchado or not WorldMapFrame then return end
  enganchado = true
  local function Actualizar() pcall(GL.ActualizarPines) end
  WorldMapFrame:HookScript("OnShow", Actualizar)
  if hooksecurefunc then
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", Actualizar) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", Actualizar) end
  end
end

table.insert(GL.alIniciar, function()
  Enganchar()
  GL.ActualizarMarca()
end)

table.insert(GL.trasRefrescar, function()
  GL.ActualizarMarca()
  if WorldMapFrame and WorldMapFrame:IsShown() then GL.ActualizarPines() end
end)

-- El mapa del mundo puede cargarse más tarde que el addon.
local eventos = CreateFrame("Frame")
GL.Evento(eventos, "ADDON_LOADED")
GL.Evento(eventos, "PLAYER_ENTERING_WORLD")
eventos:SetScript("OnEvent", function(self, event, nombre)
  if event == "PLAYER_ENTERING_WORLD" then GL.AplicarMarcaPantalla(); GL.EngancharMarcador(); if GL.SincronizarQuestie976 then GL.SincronizarQuestie976() end; return end
  if nombre == "Blizzard_QuestNavigation" then GL.EngancharMarcador() end
  if nombre == "Blizzard_WorldMap" then Enganchar() end
  if nombre == "Questie" and GL.CargaQuestie976 then GL.CargaQuestie976() end
end)

GL.comandos["marca"] = function()
  local db = DB()
  db.marcaMapa = (db.marcaMapa == false)
  GL.ActualizarMarca(true)
  GL.Mensaje(L"punto de ruta del juego en el destino " .. (db.marcaMapa and L"activado." or L"desactivado."))
end

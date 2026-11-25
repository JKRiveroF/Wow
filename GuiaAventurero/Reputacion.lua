-- Reputacion.lua: guía de reputación (6.6). Se abre con el botón Reputación del lateral derecho.
-- Lista las facciones del personaje (barra y rango leídos del juego) y, al pulsar una, su ficha:
-- cómo subirla, intendente y recompensas. Solo lee datos: no cambia la ruta ni el progreso.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local ALTO_FILA = 18
local FILAS = 8                  -- filas de la lista; el resto del panel es la ficha
local CADA = 2                   -- segundos entre lecturas mientras el panel está abierto

local panel, ui = nil, { filas = {} }
local desde, sel = 0, nil        -- desplazamiento de la lista y facción pulsada (factionID o nombre)
local FICHAS = nil               -- se rellenan al abrir el panel por primera vez

local RANGOS = { L"Odiado", L"Hostil", L"Adverso", L"Neutral", L"Amistoso", L"Honorable", L"Reverenciado", L"Exaltado" }
local COLORES = { { 0.8, 0.13, 0.13 }, { 0.8, 0.13, 0.13 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 },
  { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 } }

------------------------------------------------------------------------
-- Datos de las fichas (bajo demanda). confirmado = true: intendente y su sitio comprobados con QuestieDB (Forever) en la 7.8.
-- 7.6: vendedores de monturas de la guía de Wowhead (Forever) y el resto de las guías de reputación del clásico.
-- d = destino del intendente para la flecha ({ m = uiMapID, x, y, n }); sin d no sale "Llevarme".
------------------------------------------------------------------------
local function CargarFichas()
  return {
    [72] = { n = L"Ventormenta", confirmado = true,
      subir = { L"Misiones de Bosque de Elwynn, Páramos de Poniente y Ventormenta", L"Entregas de tela en Ventormenta" },
      intendente = L"Katie Hunter, vendedora de caballos en el campamento maderero del Valle del Este (Elwynn)",
      d = { m = 1429, x = 84.2, y = 65.5, n = "Katie Hunter" },
      recompensas = { L"Exaltado: caballos de Ventormenta (para cualquier raza de la Alianza)" } },
    [47] = { n = L"Forjaz", confirmado = true,
      subir = { L"Misiones de Dun Morogh, Loch Modan y Forjaz", L"Entregas de tela en Forjaz" },
      intendente = L"Veron Calmámbar, vendedor de carneros en la cantera de Gol'Bolar (Dun Morogh)",
      d = { m = 1426, x = 63.6, y = 50.6, n = L"Veron Calmámbar" },
      recompensas = { L"Exaltado: carneros de Forjaz (para cualquier raza de la Alianza)" } },
    [54] = { n = L"Exiliados de Gnomeregan", confirmado = true,
      subir = { L"Misiones de gnomos en Dun Morogh y Forjaz", L"Entregas de tela en Forjaz (Ciudad Manitas)" },
      intendente = L"Milli Plumasilba, vendedora de mecazancudos en Kharanos (Dun Morogh)",
      d = { m = 1426, x = 49.2, y = 48.0, n = L"Milli Plumasilba" },
      recompensas = { L"Exaltado: mecazancudos (para cualquier raza de la Alianza)" } },
    [69] = { n = "Darnassus", confirmado = true,
      subir = { L"Misiones de Teldrassil, Costa Oscura y Darnassus", L"Entregas de tela en Darnassus" },
      intendente = L"Lelanai, vendedora de sables en Darnassus",
      d = { m = 1457, x = 38.6, y = 15.6, n = "Lelanai" },
      recompensas = { L"Exaltado: sables de la noche (para cualquier raza de la Alianza)" } },
    -- 8.5: capitales de la Horda; vendedores de monturas comprobados con QuestieDB (Forever).
    [76] = { n = "Orgrimmar", confirmado = true,
      subir = { L"Misiones de Durotar, Los Baldíos y Orgrimmar", L"Entregas de tela en Orgrimmar" },
      intendente = L"Ogunaro Correlobo, vendedor de lobos en el Valle del Honor (Orgrimmar)",
      d = { m = 1454, x = 69.4, y = 12.2, n = L"Ogunaro Correlobo" },
      recompensas = { L"Exaltado: lobos de Orgrimmar (para cualquier raza de la Horda)" } },
    [530] = { n = L"Trols Lanza Negra", confirmado = true,
      subir = { L"Misiones de los trols en Durotar (Valle de los Retos y Poblado Sen'jin)", L"Entregas de tela en Orgrimmar (Valle de los Espíritus)" },
      intendente = L"Zjolnir, vendedor de raptores en el Poblado Sen'jin (Durotar)",
      d = { m = 1411, x = 55.2, y = 75.7, n = "Zjolnir" },
      recompensas = { L"Exaltado: raptores (para cualquier raza de la Horda)" } },
    [81] = { n = L"Cima del Trueno", confirmado = true,
      subir = { L"Misiones de Mulgore, Los Baldíos y Cima del Trueno", L"Entregas de tela en Cima del Trueno" },
      intendente = L"Harb Garrapezuña, vendedor de kodos en el Poblado Pezuña de Sangre (Mulgore)",
      d = { m = 1412, x = 46.6, y = 62.1, n = L"Harb Garrapezuña" },
      recompensas = { L"Exaltado: kodos (para cualquier raza de la Horda)" } },
    [68] = { n = L"Entrañas", confirmado = true,
      subir = { L"Misiones de Claros de Tirisfal, Bosque de Argénteos y Entrañas", L"Entregas de tela en Entrañas" },
      intendente = L"Zacarías Posta, vendedor de caballos esqueléticos en Rémol (Claros de Tirisfal)",
      d = { m = 1420, x = 59.9, y = 52.7, n = L"Zacarías Posta" },
      recompensas = { L"Exaltado: caballos esqueléticos (para cualquier raza de la Horda)" } },
    [21] = { n = L"Bahía del Botín", confirmado = true,
      subir = { L"Misiones de Bahía del Botín", L"Matar piratas Velasangre (baja la de los Velasangre)" },
      intendente = nil,
      recompensas = { L"Los guardias de los cárteles no te atacan" } },
    [609] = { n = L"Círculo Cenarion", confirmado = true,
      subir = { L"Misiones de Silithus", L"Matar cultistas del Martillo Crepuscular y entregar sus textos" },
      intendente = L"Vargus, intendente del Círculo Cenarion, en Fuerte Cenarion (Silithus 51.2, 38.9)",
      d = { m = 1451, x = 51.2, y = 38.9, n = "Vargus" },
      recompensas = { L"Recetas de peletería y sastrería, abalorios y piezas de equipo" } },
    [529] = { n = L"El Alba Argenta", confirmado = true,
      subir = { L"Matar no-muertos en las Tierras de la Peste (los normales hasta Amistoso, élites y mazmorras hasta Honorable)",
        L"Misiones de las Tierras de la Peste", L"Entregar piedras de la Plaga (25 + ficha de valor) e insignias" },
      intendente = L"Intendente Argenta Chispillo, en el Campamento Ventofrío (Tierras de la Peste del Oeste 42.8, 83.7); o la intendente Cerrobrecha, en la Capilla de la Esperanza de la Luz (Tierras de la Peste del Este 71.8, 50.2)",
      d = { m = 1422, x = 42.8, y = 83.7, n = L"Intendente Argenta Chispillo" },
      recompensas = { L"Honorable: planos, patrones y fórmulas de profesión", L"Reverenciado: hombreras de resistencia del Alba", L"Exaltado: Manto cromático del Alba" } },
    [576] = { n = L"Bastión Fauces de Madera", confirmado = true,
      subir = { L"Matar furbolgs Muertobosque (Frondavil) y Nevada (Cuna del Invierno), 5 cada uno, hasta Reverenciado",
        L"Misiones de Grazle, Nafien, Salfa y Meilosh", L"Entregar plumas y abalorios (hasta Exaltado)" },
      intendente = L"Meilosh, en el Bastión Fauces de Madera (Frondavil 65.7, 2.8)",
      d = { m = 1448, x = 65.7, y = 2.8, n = "Meilosh" },
      recompensas = { L"Amistoso: recetas y patrones de oso de guerra", L"Honorable: Encantar arma: agilidad", L"Exaltado: Defensor de los Fauces de Madera" } },
    [59] = { n = L"Hermandad del Torio", confirmado = true,
      subir = { L"Neutral a Amistoso: entregas al maestro herrero Cremación (La Garganta de Fuego 38.8, 28.5)",
        L"Amistoso a Honorable: 1000 residuos de hierro negro", L"Honorable a Exaltado: materiales del Núcleo de Magma a Lokhtos" },
      intendente = L"Lokhtos Tratoscuro, en la Taberna del Rencor (dentro de Profundidades de Roca Negra)",
      recompensas = { L"Recetas de herrería, peletería y sastrería de fuego" } },
    -- 7.6: facción nueva de Forever (guía de zona de Wowhead).
    [2826] = { n = L"Hermandad de la Caballería", confirmado = true,
      subir = { L"Las 75 misiones de Clarofluvial (Riverglades), sobre todo en Farholde; solo Alianza" },
      intendente = nil,
      recompensas = { L"Ninguna guía las ha publicado todavía" } },
  }
end

------------------------------------------------------------------------
-- Lectura del juego
------------------------------------------------------------------------
local function InfoFaccion(i)
  if C_Reputation and C_Reputation.GetFactionDataByIndex then
    local ok, d = pcall(C_Reputation.GetFactionDataByIndex, i)
    if ok and type(d) == "table" then
      return d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding,
        d.isHeader, d.isHeaderWithRep, d.factionID
    end
  end
  if not GetFactionInfo then return nil end
  local ok, nombre, _, rango, minimo, maximo, valor, _, _, cabecera, _, conRep, _, _, id = pcall(GetFactionInfo, i)
  if not ok then return nil end
  return nombre, rango, minimo, maximo, valor, cabecera, conRep, id
end

local function LeerFacciones()
  local lista = {}
  local n = (GetNumFactions and GetNumFactions()) or (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetNumFactions()) or 0
  for i = 1, n do
    local nombre, rango, minimo, maximo, valor, cabecera, conRep, id = InfoFaccion(i)
    if type(nombre) == "string" and (not cabecera or conRep) and type(rango) == "number" then
      table.insert(lista, { nombre = nombre, rango = rango, min = minimo or 0, max = maximo or 1, valor = valor or 0, id = id })
    end
  end
  return lista
end

local function Etiqueta(rango)
  local t = _G["FACTION_STANDING_LABEL" .. rango]
  if type(t) == "string" and t ~= "" then return t end
  return RANGOS[rango] or "?"
end

local function ColorRango(rango)
  local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[rango]
  if type(c) == "table" and c.r then return c.r, c.g, c.b end
  c = COLORES[rango] or COLORES[4]
  return c[1], c[2], c[3]
end

local function Hex(r, g, b)
  return string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

------------------------------------------------------------------------
-- Refrescar
------------------------------------------------------------------------
local function Ficha(f)
  local ficha = FICHAS and f.id and FICHAS[f.id]
  local r, g, b = ColorRango(f.rango)
  local actual, total = f.valor - f.min, f.max - f.min
  ui.fichaTitulo:SetText(string.upper(f.nombre))
  ui.fichaRango:SetText(Hex(r, g, b) .. Etiqueta(f.rango) .. C.FIN .. (total > 0 and (C.GRIS .. " · " .. actual .. " / " .. total .. C.FIN) or ""))
  local lineas = {}
  if not ficha then
    table.insert(lineas, C.GRIS .. L"Aún no hay ficha para esta facción." .. C.FIN)
  else
    table.insert(lineas, C.AMARILLO .. L"Cómo subirla" .. C.FIN)
    for i = 1, #ficha.subir do table.insert(lineas, "• " .. ficha.subir[i]) end
    if ficha.intendente then
      table.insert(lineas, " ")
      table.insert(lineas, C.AMARILLO .. L"Intendente" .. C.FIN)
      table.insert(lineas, "• " .. C.AZUL .. ficha.intendente .. C.FIN)
    end
    if ficha.recompensas and #ficha.recompensas > 0 then
      table.insert(lineas, " ")
      table.insert(lineas, C.AMARILLO .. L"Recompensas" .. C.FIN)
      for i = 1, #ficha.recompensas do table.insert(lineas, "• " .. ficha.recompensas[i]) end
    end
    table.insert(lineas, " ")
    table.insert(lineas, C.GRIS .. L"Fuente: guías de reputación de Wowhead" .. (ficha.confirmado and L"; intendentes comprobados con QuestieDB (Forever)." or ".") .. C.FIN)
  end
  ui.fichaTexto:SetText(table.concat(lineas, "\n"))
  ui.llevarme.destino = ficha and ficha.d
  GL.Mostrar(ui.llevarme, ficha and ficha.d and GL.SeguirDesvio and true or false)
  ui.ficha:Show()
end

local function Refrescar()
  if not panel or not panel:IsShown() then return end
  if not FICHAS then FICHAS = CargarFichas() end
  local lista = LeerFacciones()
  desde = math.max(0, math.min(desde, #lista - FILAS))
  local elegida = nil
  for i = 1, #lista do
    if sel and (lista[i].id or lista[i].nombre) == sel then elegida = lista[i] end
  end
  if not elegida and lista[1] then elegida = lista[1]; sel = lista[1].id or lista[1].nombre end
  for i = 1, FILAS do
    local fila, f = ui.filas[i], lista[desde + i]
    fila.faccion = f
    if f then
      local r, g, b = ColorRango(f.rango)
      local total = f.max - f.min
      fila.nombre:SetText(f.nombre)
      fila.barra:SetStatusBarColor(r, g, b, 0.95)
      fila.barra:SetValue(total > 0 and (f.valor - f.min) / total or 1)
      fila.rango:SetText(Hex(r, g, b) .. Etiqueta(f.rango) .. C.FIN)
      GL.Mostrar(fila.marca, f == elegida)
      fila:Show()
    else
      fila:Hide()
    end
  end
  if #lista > FILAS then
    ui.mas:SetText(C.GRIS .. L"Facciones " .. (desde + 1) .. "-" .. math.min(#lista, desde + FILAS) .. L" de " .. #lista .. L" (rueda del ratón)" .. C.FIN)
  elseif #lista == 0 then
    ui.mas:SetText(C.GRIS .. L"El juego aún no muestra ninguna reputación." .. C.FIN)
  else
    ui.mas:SetText("")
  end
  if elegida then Ficha(elegida) else ui.ficha:Hide() end
end

------------------------------------------------------------------------
-- Crear
------------------------------------------------------------------------
local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)   -- sin pestañas: empieza bajo la cabecera
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()

  local titulo = GL.Texto(panel, "GameFontNormal")
  titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  titulo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0); GL.UnaLinea(titulo)   -- 7.6.1: dentro del marco
  titulo:SetText(L"Tus reputaciones " .. C.GRIS .. L"(las lee del juego)" .. C.FIN)

  for i = 1, FILAS do
    local f = CreateFrame("Button", nil, panel)
    f:SetHeight(ALTO_FILA)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -20 - (i - 1) * ALTO_FILA)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -20 - (i - 1) * ALTO_FILA)
    f.marca = f:CreateTexture(nil, "BACKGROUND")
    f.marca:SetAllPoints()
    f.marca:SetColorTexture(1, 0.82, 0, 0.12)
    f.marca:Hide()
    local brillo = f:CreateTexture(nil, "HIGHLIGHT")
    brillo:SetAllPoints()
    brillo:SetColorTexture(1, 1, 1, 0.06)
    f.nombre = GL.Texto(f, "GameFontHighlightSmall")
    f.nombre:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.nombre:SetWidth(130)
    GL.UnaLinea(f.nombre)
    f.rango = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.rango:SetPoint("RIGHT", f, "RIGHT", -2, 0)
    f.rango:SetWidth(80)
    f.barra = GL.CrearBarra(f, 0, 0.6, 0.1)
    f.barra:SetHeight(10)
    f.barra:SetPoint("LEFT", f, "LEFT", 140, 0)
    f.barra:SetPoint("RIGHT", f.rango, "LEFT", -6, 0)
    f:SetScript("OnClick", function(self)
      if not self.faccion then return end
      sel = self.faccion.id or self.faccion.nombre
      Refrescar()
    end)
    ui.filas[i] = f
  end
  ui.mas = GL.Texto(panel, "GameFontHighlightSmall")
  ui.mas:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22 - FILAS * ALTO_FILA)
  ui.mas:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -22 - FILAS * ALTO_FILA); GL.UnaLinea(ui.mas)   -- 7.6.1: dentro del marco

  -- ficha de la facción pulsada
  local ficha = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ficha:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -40 - FILAS * ALTO_FILA)
  ficha:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
  if GL.Caja and GL.COLOR then GL.Caja(ficha, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  local borde = ficha:CreateTexture(nil, "ARTWORK")   -- línea dorada a la izquierda, como la caja del paso
  borde:SetWidth(3)
  borde:SetPoint("TOPLEFT", ficha, "TOPLEFT", 0, 0)
  borde:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 0, 0)
  borde:SetColorTexture(1, 0.78, 0.25, 1)
  ui.ficha = ficha
  ui.fichaTitulo = GL.Texto(ficha, "GameFontNormalSmall")
  ui.fichaTitulo:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -8)
  ui.fichaTitulo:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -8); GL.UnaLinea(ui.fichaTitulo)   -- 7.6.1: dentro del marco
  ui.fichaRango = GL.Texto(ficha, "GameFontHighlightSmall", "RIGHT")
  ui.fichaRango:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -8)
  ui.fichaTexto = GL.Texto(ficha, "GameFontHighlightSmall")
  ui.fichaTexto:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -26)
  ui.fichaTexto:SetPoint("BOTTOMRIGHT", ficha, "BOTTOMRIGHT", -8, 30)
  ui.llevarme = GL.CrearBoton(ficha, L"Llevarme al intendente", function()
    local d = ui.llevarme.destino
    if d and GL.SeguirDesvio then GL.SeguirDesvio(d) end
  end, nil, 20)
  ui.llevarme:SetWidth(150)
  ui.llevarme:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 12, 6)
  ui.llevarme:Hide()

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    desde = math.max(0, desde - delta * 2)
    Refrescar()
  end)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt)
    if not panel:IsShown() then return end
    espera = espera + dt
    if espera >= CADA then espera = 0; Refrescar() end
  end)
  GL.modos.reputacion = { panel = panel, refrescar = Refrescar }
end

-- 9.0: se crea al abrirla por primera vez (Ajustes › General › Cargar cada sección al abrirla)
GL.perezosos = GL.perezosos or {}
GL.perezosos.reputacion = CrearPanel
table.insert(GL.alIniciar, function() if type(GuiaAventureroDB) == "table" and GuiaAventureroDB.cargarAlAbrir == false then CrearPanel() end end)

-- 6.8: la Biblioteca usa las mismas fichas y abre una facción aquí.
GL.DatosReputacion = CargarFichas
GL.AbrirFaccion = function(id)
  sel = id
  if GL.AbrirModo then GL.AbrirModo("reputacion") end
end

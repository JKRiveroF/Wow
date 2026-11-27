-- Farmeo.lua (9.1): «Me falta XP». Cuando te faltan niveles para la sección (o lo pides con el botón de la
-- tarjeta de llegada al 60 o con /ga farmeo), una tarjeta en la Guía propone sitios con enemigos de tu
-- nivel para farmear: los tres más cercanos de tu facción o en disputa, con «Llevarme» para la flecha.
-- Los niveles de las zonas son los de la Biblioteca. 9.2: campamentos, niveles y coordenadas comprobados con la
-- base de datos de enemigos de Questie (Forever); por comprobar en el juego.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil

-- { nivel mínimo, máximo, uiMapID, zona, x, y, enemigos, lado (A, H o nada: los dos) }
local SITIOS = {
  { 5, 8, 1429, L"Bosque de Elwynn", 52.0, 66.0, L"Múrlocs del lago Cristal", "A" },
  { 7, 10, 1429, L"Bosque de Elwynn", 69.0, 79.0, L"Defias del huerto de calabazas de los Brackwell", "A" },
  { 6, 9, 1426, "Dun Morogh", 40.0, 44.0, L"Trols Crines de Escarcha de la Cresta Brillante", "A" },
  { 8, 11, 1426, "Dun Morogh", 70.0, 56.0, L"Troggs de la cantera de Gol'Bolar", "A" },
  { 6, 10, 1438, "Teldrassil", 52.0, 77.0, L"Furbolgs Tuercepiel", "A" },
  { 10, 13, 1436, L"Páramos de Poniente", 56.0, 31.0, L"Gólems de cosecha de la granja Saldean", "A" },
  { 14, 18, 1436, L"Páramos de Poniente", 26.5, 57.0, L"Múrlocs de la costa", "A" },
  { 11, 14, 1432, "Loch Modan", 34.0, 72.0, L"Troggs Rompepiedras", "A" },
  { 11, 15, 1439, L"Costa Oscura", 40.0, 40.0, L"Múrlocs y fieras de la costa", "A" },
  { 5, 9, 1411, "Durotar", 58.4, 57.0, L"Marines de Kul Tiras del Fuerte Tiragarde", "H" },
  { 7, 10, 1411, "Durotar", 42.0, 38.0, L"Jabalíes de Crines de Acero y escórpidos", "H" },
  { 5, 9, 1412, "Mulgore", 62.0, 42.0, L"Ventura y Cía. de la mina", "H" },
  { 5, 9, 1420, L"Claros de Tirisfal", 32.2, 48.0, L"Cruzados Escarlata de la granja Solliden", "H" },
  { 10, 14, 1413, L"Los Baldíos", 56.9, 25.6, L"Jabaespines Crines de Acero", "H" },
  { 11, 15, 1413, L"Los Baldíos", 44.6, 23.7, L"Centauros Kolkar", "H" },
  { 13, 17, 1421, L"Bosque de Argénteos", 45.0, 23.0, L"Huargos Rabialuna", "H" },
  { 17, 21, 1433, L"Montañas Crestagrana", 40.0, 15.0, L"Orcos Roca Negra del campamento de Render", nil },
  { 24, 29, 1431, L"Bosque del Ocaso", 16.0, 35.3, L"Esqueletos del cementerio de la Colina del Cuervo", nil },
  { 21, 25, 1437, L"Los Humedales", 55.0, 55.0, L"Orcos Faucedraco", nil },
  { 20, 24, 1440, L"Vallefresno", 30.0, 30.0, L"Furbolgs y sátiros", nil },
  { 29, 33, 1434, L"Vega de Tuercespina", 30.7, 11.2, L"Tigres y panteras del norte", nil },
  { 20, 24, 1424, L"Laderas de Trabalomas", 61.8, 36.5, L"Osos y arañas de las colinas", nil },
  { 30, 34, 1443, "Desolace", 72.0, 45.0, L"Centauros Kolkar", nil },
  { 33, 37, 1443, "Desolace", 70.0, 75.0, L"Centauros Magram", nil },
  { 33, 37, 1443, "Desolace", 35.0, 80.0, L"Centauros Gelkis", nil },
  { 32, 37, 1417, L"Tierras Altas de Arathi", 58.0, 70.0, L"Ogros Puño de Roca", nil },
  { 36, 40, 1445, L"Marjal Revolcafango", 48.5, 18.7, L"Arañas y raptores del marjal", nil },
  { 37, 41, 1418, L"Tierras Inhóspitas", 65.0, 40.0, L"Troggs Cripta Pétrea y coyotes", nil },
  { 41, 45, 1446, "Tanaris", 63.0, 30.0, L"Bandidos Rondadesierto", nil },
  { 41, 45, 1444, "Feralas", 73.0, 58.0, L"Gnolls Zarpaleña", nil },
  { 44, 48, 1446, "Tanaris", 40.0, 57.0, L"Ogros Machacaduna", nil },
  { 47, 51, 1425, L"Tierras del Interior", 63.0, 75.0, L"Trols Vilorrama", nil },
  { 48, 53, 1449, L"Cráter de Un'Goro", 65.0, 15.0, L"Gorilas y raptores", nil },
  { 50, 54, 1448, L"Frondavil", 38.0, 65.0, L"Sátiros del Claro de Fuego de Jade", nil },
  { 52, 56, 1428, L"Las Estepas Ardientes", 75.0, 48.0, L"Orcos Roca Negra", nil },
  { 54, 57, 1452, L"Cuna del Invierno", 67.0, 37.0, L"Furbolgs Nevada", nil },
  { 55, 59, 1422, L"Tierras de la Peste del Oeste", 45.0, 65.0, L"Plaga en Andorhal", nil },
  { 55, 60, 1451, "Silithus", 26.2, 34.0, L"Cultistas del Martillo Crepuscular", nil },
  { 57, 60, 1423, L"Tierras de la Peste del Este", 20.0, 32.0, L"Plaga del Bosque de la Peste", nil },
}
GL.SITIOS_FARMEO = SITIOS

local function DB() return GuiaAventureroDB or {} end
local function Nivel() local n = UnitLevel and UnitLevel("player"); n = GL.Seguro and GL.Seguro(n) or n; return type(n) == "number" and n or 1 end
local function Lado() return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A" end

local function Destino(s) return { m = s[3], z = s[4], x = s[5], y = s[6], n = s[7] .. L" (farmeo)" } end

-- Los sitios de tu nivel, los más cercanos primero (los de otro continente, al final)
local function Sitios(max)
  local nivel, lado, res = Nivel(), Lado(), {}
  for _, s in ipairs(SITIOS) do
    if nivel >= s[1] - 1 and nivel <= s[2] and (not s[8] or s[8] == lado) then
      local d = Destino(s)
      local ok, _, _, dist = false, nil, nil, nil
      if GL.Vector then ok, _, _, dist = pcall(GL.Vector, d) end
      table.insert(res, { s = s, d = d, dist = (ok and type(dist) == "number") and dist or nil })
    end
  end
  table.sort(res, function(a, b) return (a.dist or 1e9) < (b.dist or 1e9) end)
  while #res > (max or 3) do table.remove(res) end
  return res
end
GL.SitiosFarmeo = Sitios

-- ¿Te faltan niveles para la sección?
local function Corto()
  local R, db = GL.RUTA, DB()
  local s = R and db.seccion and R.secciones[db.seccion]
  return s and Nivel() < (s.min or 1) and Nivel() < 60
end

local abierto = false
GL.AbrirFarmeo = function() abierto = not abierto; if GL.Refrescar then GL.Refrescar() end end

local t
local function Crear(panel)
  t = CreateFrame("Frame", nil, panel, PLANTILLA)
  t.titulo = GL.Texto(t, "GameFontNormalSmall")
  t.titulo:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -7)
  t.cerrar = GL.CrearBoton(t, "", function() abierto = false; DB().farmeoVisto = DB().seccion; if GL.Refrescar then GL.Refrescar() end end, nil, 18, "cerrar")
  t.cerrar:SetWidth(18)
  t.cerrar:SetPoint("TOPRIGHT", t, "TOPRIGHT", -4, -4)
  t.filas = {}
  for i = 1, 3 do
    local f = CreateFrame("Frame", nil, t)
    f:SetHeight(30)
    f.texto = GL.Texto(f, "GameFontHighlightSmall")
    f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    if f.texto.SetJustifyH then f.texto:SetJustifyH("LEFT") end
    f.ir = GL.CrearBoton(f, L"Llevarme", function()
      if f.d and GL.SeguirDesvio then GL.SeguirDesvio(f.d) end
      if GL.Mensaje and f.d then GL.Mensaje(L"la flecha te lleva a " .. f.d.n .. " (" .. tostring(f.d.z) .. ").") end
    end, nil, 18, "accion")
    f.ir:SetWidth(76)
    f.ir:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.texto:SetPoint("RIGHT", f.ir, "LEFT", -6, 0)
    t.filas[i] = f
  end
  t.nota = GL.Texto(t, "GameFontDisableSmall")
end

local function Metros(y) return y and (y >= 1000 and GL.FormatoDecimal(string.format(L"%.1f km", y * 0.9144 / 1000)) or (math.floor(y * 0.9144 / 10 + 0.5) * 10 .. " m")) or L"otro continente" end

local function Tarjeta(panel, y, ancho)
  if t then t:Hide() end
  if DB().farmeo == false then return 0 end
  local auto = Corto() and DB().farmeoVisto ~= DB().seccion
  if not abierto and not auto then return 0 end
  local lista = Sitios(3)
  if #lista == 0 then return 0 end
  if not t then Crear(panel) end
  t:SetParent(panel)
  GL.Caja(t, GL.COLOR.caja, { 1, 0.82, 0, 0.45 })
  local s = GL.RUTA.secciones[DB().seccion]
  t.titulo:SetText(C.AMARILLO .. L"ME FALTA XP" .. C.FIN .. C.GRIS .. (Corto() and (L"  ·  la sección pide nivel " .. s.min .. L" y tienes " .. Nivel()) or (L"  ·  enemigos de tu nivel (" .. Nivel() .. ")")) .. C.FIN)
  local h = 24
  for i = 1, 3 do
    local f, e = t.filas[i], lista[i]
    if e then
      f.d = e.d
      f.texto:SetText(C.BLANCO .. e.s[7] .. C.FIN .. "\n" .. C.AZUL .. e.s[4] .. C.FIN .. C.GRIS .. string.format(L" %.0f, %.0f · niv. %d-%d · %s", e.s[5], e.s[6], e.s[1], e.s[2], Metros(e.dist)) .. C.FIN)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -h)
      f:SetPoint("TOPRIGHT", t, "TOPRIGHT", -8, -h)
      f:Show()
      h = h + 32
    else
      f:Hide()
    end
  end
  t.nota:ClearAllPoints()
  t.nota:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -h)
  t.nota:SetText(L"Sitios aproximados. También sirven las opcionales de tu nivel y las mazmorras.")
  h = h + 18
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  t:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  t:SetHeight(h)
  t:Show()
  return h
end
table.insert(GL.tarjetasGuia, Tarjeta)

GL.comandos = GL.comandos or {}
GL.comandos["farmeo"] = function()
  local l = Sitios(3)
  if #l == 0 then if GL.Mensaje then GL.Mensaje(L"no tengo sitios de farmeo para tu nivel.") end return end
  abierto = true
  if GL.MostrarVentanaCompletaR10 then GL.MostrarVentanaCompletaR10() else
    if GL.frame then GL.frame:Show(); DB().oculto = false end
  end
  if GL.AbrirModo then GL.AbrirModo("guia") end
end

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "farmeo", "«Me falta XP»: sitios para farmear",
  "Si te faltan niveles para la sección, la Guía te propone enemigos de tu nivel cerca, con Llevarme.",
  function() return DB().farmeo ~= false end, function(v) DB().farmeo = v; if GL.Refrescar then GL.Refrescar() end end, pestana = "paso" })

GL._farmeo = { Sitios = Sitios, Corto = Corto, Tarjeta = Tarjeta, Abrir = function() abierto = true end }

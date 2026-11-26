-- Opcionales.lua (7.6): misiones opcionales cerca, estilo de ruta y etiquetas ÉLITE / GRUPO.
-- Las rutas no se tocan: las opcionales salen aparte, en una tarjeta debajo de los objetivos del paso.
-- Datos: GL.WH.opcionales (misiones de las otras rutas de la Alianza), GL.WH.opcionalesNuevas (7.7: las que no
-- salen en ninguna ruta, de QuestieDB) y las misiones de Mazmorras.lua. 8.5: con la Horda, GL.WH.opcionalesH y
-- GL.WH.opcionalesNuevasH (OpcionalesHorda.lua) en su lugar.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local CERCA_M = 500        -- metros: en Normal se ofrecen las que tienes a menos de esto
local MAX_FILAS = 3
local ALTO_FILA = 32

local ESTILOS = {
  { id = "rapida", n = L"Solo ruta", d = L"Solo la ruta principal, sin misiones opcionales. Tendrás que matar enemigos para conseguir la experiencia que falte." },
  { id = "normal", n = L"Normal", d = L"La ruta principal, y te ofrece las opcionales que tengas cerca." },
  { id = "completa", n = L"Completa", d = L"Mete solas en la tarjeta todas las opcionales de la zona." },
  { id = "mazmorras", n = L"Con mazmorras", d = L"Normal, y además las misiones de mazmorra de tu nivel." },
}

local function DB() return GuiaAventureroDB or {} end
GL.ESTILOS_RUTA = ESTILOS   -- 9.0: el tutorial
local function Estilo() return DB().estiloRuta or "normal" end
local function Lista(k) local db = DB(); if type(db[k]) ~= "table" then db[k] = {} end; return db[k] end
local function Nivel() return (UnitLevel and UnitLevel("player")) or 1 end
local function Metros(yardas) return math.floor(yardas * 0.9144 + 0.5) end
local function Hecha(q) return GL.MisionCompletada and GL.MisionCompletada(q) end
local function EnDiario(q) return GL.MisionEnDiario and GL.MisionEnDiario(q) end

------------------------------------------------------------------------
-- Se muestra la etiqueta del juego o la categoría de referencia mientras llega la ficha.
------------------------------------------------------------------------
-- Categorías de los encargos de ruta según QuestInfo y las consultas de Forever.
local TIPOS_MISION = {
  [19] = 1, [99] = 1, [115] = 1, [166] = 81, [167] = 81, [168] = 81, [169] = 1,
  [176] = 1, [193] = 1, [197] = 1, [202] = 1, [206] = 1, [208] = 1, [211] = 1,
  [248] = 1, [253] = 1, [255] = 1, [256] = 1, [271] = 1, [304] = 1, [314] = 1,
  [377] = 81, [386] = 81, [388] = 81, [450] = 1, [452] = 1, [474] = 1, [517] = 1,
  [531] = 1, [543] = 1, [547] = 1, [611] = 1, [613] = 1, [628] = 1, [629] = 1,
  [631] = 1, [639] = 1, [640] = 1, [643] = 1, [644] = 1, [645] = 1, [646] = 1,
  [652] = 1, [656] = 1, [673] = 1, [680] = 1, [682] = 1, [684] = 1, [685] = 1,
  [694] = 1, [705] = 1, [706] = 1, [709] = 81, [721] = 81, [722] = 81, [735] = 1,
  [736] = 1, [762] = 1, [793] = 1, [914] = 81, [959] = 81, [962] = 81, [969] = 1,
  [971] = 81, [1013] = 81, [1014] = 81, [1049] = 81, [1050] = 81, [1089] = 1, [1090] = 1,
  [1102] = 81, [1107] = 1, [1109] = 81, [1113] = 81, [1139] = 81, [1151] = 1, [1160] = 81,
  [1166] = 1, [1172] = 1, [1173] = 1, [1199] = 81, [1221] = 81, [1275] = 81, [1360] = 81,
  [1424] = 1, [1445] = 81, [1446] = 81, [1448] = 1, [1475] = 81, [1486] = 81, [1489] = 81,
  [1490] = 81, [1491] = 81, [1701] = 1, [1713] = 1, [1740] = 81, [1951] = 81, [2040] = 81,
  [2202] = 81, [2203] = 1, [2283] = 81, [2342] = 81, [2359] = 1, [2418] = 81, [2478] = 1,
  [2499] = 1, [2768] = 81, [2769] = 81, [2770] = 81, [2841] = 81, [2846] = 81, [2861] = 81,
  [2864] = 81, [2865] = 81, [2922] = 81, [2923] = 81, [2924] = 81, [2927] = 81, [2928] = 81,
  [2930] = 81, [2944] = 1, [2991] = 81, [2993] = 1, [2994] = 1, [3042] = 81, [3062] = 1,
  [3127] = 1, [3341] = 81, [3372] = 1, [3380] = 81, [3452] = 1, [3463] = 1, [3527] = 81,
  [3528] = 81, [3566] = 1, [4023] = 1, [4024] = 81, [4123] = 81, [4128] = 81, [4136] = 81,
  [4143] = 81, [4146] = 81, [4148] = 81, [4286] = 81, [4324] = 81, [4729] = 81, [4734] = 81,
  [4735] = 81, [4787] = 1, [4788] = 81, [4862] = 81, [4866] = 81, [5065] = 1, [5088] = 1,
  [5127] = 81, [5151] = 1, [5153] = 1, [5156] = 1, [5168] = 1, [5212] = 81, [5213] = 81,
  [5214] = 81, [5243] = 81, [5247] = 1, [5281] = 81, [5282] = 81, [5305] = 81, [5306] = 81,
  [5307] = 81, [5341] = 81, [5343] = 81, [5522] = 81, [5526] = 81, [5529] = 81, [5725] = 81,
  [5761] = 81, [5848] = 81, [6025] = 1, [6041] = 1, [6135] = 1, [6163] = 81, [6182] = 1,
  [6183] = 1, [6184] = 1, [6185] = 1, [6186] = 1, [6283] = 1, [6284] = 1, [6562] = 81,
  [6563] = 81, [6921] = 81, [7068] = 81, [7070] = 81, [7494] = 81, [7701] = 1, [7816] = 1,
  [7845] = 1, [7846] = 1, [7847] = 1, [7849] = 1, [7850] = 1, [8181] = 62, [8182] = 62,
  [8232] = 81, [8236] = 81, [8253] = 81, [8257] = 81, [8258] = 81, [8283] = 1, [8413] = 81,
  [8418] = 81, [8422] = 81, [8425] = 81, [8481] = 1, [8551] = 1, [8868] = 62, [8913] = 81,
  [8914] = 81, [8915] = 81, [8916] = 81, [8917] = 81, [8918] = 81, [8919] = 81, [8920] = 81,
  [8927] = 81, [8928] = 1, [8938] = 81, [8939] = 81, [8940] = 81, [8942] = 81, [8943] = 81,
  [8941] = 81, [8944] = 81, [9023] = 62, [9051] = 1, [9053] = 81, [91752] = 1, [91775] = 1, [93318] = 1,
  [96222] = 1, [98427] = 1,
}

local cacheEtiqueta = {}
local function EtiquetaMision(q)
  if not q then return "", nil end
  if cacheEtiqueta[q] then return cacheEtiqueta[q][1], cacheEtiqueta[q][2] end
  local elite, grupo = false, nil
  local ok, info = pcall(function() return C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(q) end)
  local sabe = ok and type(info) == "table"
  local tipo = (sabe and info.tagID) or TIPOS_MISION[q]
  if sabe and info.isElite then elite = true end
  if tipo == 1 then grupo = 0; elite = true end
  local okN, n = pcall(function() return C_QuestLog and C_QuestLog.GetSuggestedGroupSize and C_QuestLog.GetSuggestedGroupSize(q) end)
  if okN and type(n) == "number" and n > 1 then grupo = n end
  local tabla = GL.WH and GL.WH.grupo
  if grupo == nil and type(tabla) == "table" and tabla[q] then grupo = tabla[q]; elite = true end
  local t = ""
  if elite then t = t .. L" |cffff8040ÉLITE|r" end
  if grupo then t = t .. L" |cff69ccf0GRUPO" .. ((grupo > 1) and (" " .. grupo) or "") .. "|r" end
  if tipo == 62 then t = t .. L" |cffa335eeBANDA|r" end
  if tipo == 81 then t = t .. L" |cffa335eeMAZMORRA|r" end
  -- Una vista previa sigue consultando la ficha y el tamaño ofrecidos por el juego.
  if sabe and info.tagID ~= nil and okN and type(n) == "number" then cacheEtiqueta[q] = { t, grupo } end
  return t, grupo
end
GL.EtiquetaMision = EtiquetaMision

------------------------------------------------------------------------
-- Candidatas
------------------------------------------------------------------------
local misQs, rutaVista = nil, nil
local function MisMisiones()
  if misQs and rutaVista == GL.RUTA then return misQs end
  misQs, rutaVista = {}, GL.RUTA
  for _, sec in ipairs((GL.RUTA and GL.RUTA.secciones) or {}) do
    for _, paso in ipairs(sec.pasos or {}) do
      for _, wp in ipairs(paso.wp or {}) do if wp.q then misQs[wp.q] = true end end
    end
  end
  return misQs
end

-- Siguiente destino de la opcional: recoger, objetivo o entregar (el primero que falte).
local function Siguiente(o)
  for _, wp in ipairs(o.wp or {}) do
    local w = { m = wp.m, x = wp.x, y = wp.y, z = wp.z, n = wp.n, q = o.q, a = wp.a }
    if not GL.DestinoHecho or GL.DestinoHecho(w) ~= true then return w end
  end
end

local function Distancia(w)
  if not (w and GL.Vector) then return nil end
  local ok, este, _, dist = pcall(GL.Vector, w)
  if ok and este and dist then return Metros(dist) end
end

-- 7.7: las opcionales nuevas (OpcionalesDatos.lua) dicen qué razas y clases las pueden coger y qué misiones piden antes
local BIT_RAZA = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
-- 8.6: el Skyborne tiene un bit por facción (2^32 Alianza, 2^33 Horda)
local function BitRaza()
  local r = GL.Raza and GL.Raza()
  if r == "Skyborne" then
    return (UnitFactionGroup and UnitFactionGroup("player") == "Alliance") and 4294967296 or 8589934592
  end
  return BIT_RAZA[r or ""]
end
local BIT_CLASE = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
local function Bit(n, b) return n and b and (math.floor(n / b) % 2 == 1) end
local function Disponible(o)
  if o.razas then
    local b = BitRaza()
    if b and not Bit(o.razas, b) then return false end
  end
  if o.clasesM then
    -- 8.6: "UnitClass and UnitClass(...)" se queda solo con el primer valor (el nombre): el token es el segundo
    local c = UnitClass and select(2, UnitClass("player"))
    local b = BIT_CLASE[c or ""]
    if b and not Bit(o.clasesM, b) then return false end
  end
  if o.pre1 then
    local alguna = false
    for _, q in ipairs(o.pre1) do if Hecha(q) or EnDiario(q) then alguna = true; break end end
    if not alguna then return false end
  end
  if o.preT then for _, q in ipairs(o.preT) do if not Hecha(q) then return false end end end
  if o.excl then for _, q in ipairs(o.excl) do if Hecha(q) or EnDiario(q) then return false end end end
  return true
end
-- 8.7: misiones de clase que enseñan lo mismo que otra: si ya hiciste (o llevas) la otra, no se ofrecen. Sirve sobre todo
-- al Skyborne, que puede coger las de los orcos, tauren, no-muertos y humanos pero aprende lo mismo en la Isla Zephras.
local EQUIVALENTES = {}
for _, g in ipairs({
  { 94003, { 1498, 1502, 1503, 1505, 1818, 1819, 1820, 1821, 1822, 1638, 1640, 1665, 1666, 1667, 1678, 1679, 1683, 1684, 1686 } }, -- Actitud defensiva
  { 92468, { 1462, 1463, 1516, 1517, 1518, 1519, 1520, 1521, 94373, 94374, 94375 } },  -- tótem de tierra
  { 97257, { 1464, 1522, 1523, 1524, 1525, 1526, 1527, 2983, 2984 } },                 -- tótem de fuego
  { 94050, { 94792, 94863, 94864, 94793 } },                                           -- Domesticar bestia (cazador)
  { 94638, { 5921, 5922, 5929, 5930, 5931, 5932, 6001, 6002 } },                         -- forma de oso
}) do for _, q in ipairs(g[2]) do EQUIVALENTES[q] = g[1] end end
local function YaEnsenada(q, mias)
  local e = EQUIVALENTES[q]
  return e and (mias[e] or Hecha(e) or EnDiario(e)) and true or false
end
local function EnMapa(o, mapa)
  for _, wp in ipairs(o.wp or {}) do if wp.m == mapa then return true end end
  return false
end

local function Candidatas()
  local res = {}
  local estilo = Estilo()
  if estilo == "rapida" then return res end
  local mias, anadidas, no = MisMisiones(), Lista("opcAnadidas"), Lista("opcNo")
  local nivel = Nivel()
  local mapa = GL.PosicionJugador and GL.PosicionJugador()
  local WH = GL.WH or {}
  local tablas = { WH.opcionales or {}, WH.opcionalesNuevas or {} }
  if UnitFactionGroup and UnitFactionGroup("player") == "Horde" then tablas = { WH.opcionalesH or {}, WH.opcionalesNuevasH or {} } end
  for _, tabla in ipairs(tablas) do
    for q, o in pairs(tabla) do
      local deNivel = (o.nivel or 1) <= nivel + 2 and (o.nivel or 1) >= nivel - 8
      if o.nivelMinimo then deNivel = nivel >= o.nivelMinimo end
      local pedida = anadidas[q]
      -- filtro barato primero: de tu nivel y en tu mapa (o añadida por ti)
      if (pedida or (deNivel and EnMapa(o, mapa))) and not mias[q] and not no[q] and not Hecha(q) and not YaEnsenada(q, mias) then
        local enDiario = EnDiario(q)
        if pedida or enDiario or Disponible(o) then
          o.q = q
          local w = Siguiente(o)
          local dist = w and Distancia(w)
          local anadida = pedida or enDiario
          if w and estilo == "completa" and w.m == mapa and deNivel then anadida = true end
          if w and (anadida or (dist and dist <= CERCA_M and deNivel)) then
            table.insert(res, { q = q, o = o, w = w, dist = dist, anadida = anadida })
          end
        end
      end
    end
  end
  table.sort(res, function(a, b)
    if (a.anadida and true or false) ~= (b.anadida and true or false) then return a.anadida and true or false end
    return (a.dist or 99999) < (b.dist or 99999)
  end)
  if estilo == "mazmorras" and GL.DatosMazmorras then
    local ok, datos = pcall(GL.DatosMazmorras)
    for _, m in ipairs((ok and datos) or {}) do
      if nivel >= m.min - 1 and nivel <= m.max then
        for _, mq in ipairs(m.misiones or {}) do
          if mq.q and not no[mq.q] and not Hecha(mq.q) and not EnDiario(mq.q) then
            table.insert(res, { q = mq.q, mazmorra = m, mq = mq })
          end
        end
      end
    end
  end
  return res
end
GL._opcionales = Candidatas   -- para las pruebas

------------------------------------------------------------------------
-- Tarjeta de la pestaña Guía
------------------------------------------------------------------------
local caja = nil
local function CrearCaja(panel)
  caja = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
  if GL.Caja then GL.Caja(caja, { 1, 1, 1, 0.045 }, { 1, 1, 1, 0.10 }) end
  local raya = caja:CreateTexture(nil, "ARTWORK")
  raya:SetWidth(3)
  raya:SetPoint("TOPLEFT", caja, "TOPLEFT", 0, 0)
  raya:SetPoint("BOTTOMLEFT", caja, "BOTTOMLEFT", 0, 0)
  raya:SetColorTexture(1, 0.78, 0.25, 1)
  caja.titulo = GL.Texto(caja, "GameFontNormalSmall")
  caja.titulo:SetPoint("TOPLEFT", caja, "TOPLEFT", 10, -6)
  caja.filas = {}
  for i = 1, MAX_FILAS do
    local f = CreateFrame("Frame", nil, caja)
    f:SetHeight(ALTO_FILA)
    f.no = GL.CrearBoton(f, L"No", function(self)
      local c = self:GetParent().c
      if c then Lista("opcNo")[c.q] = true; Lista("opcAnadidas")[c.q] = nil; if GL.Refrescar then GL.Refrescar() end end
    end, nil, 18)
    f.no:SetWidth(40)
    f.no:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
    if GL.BotonIcono then GL.BotonIcono(f.no, "no", L"No", L"No me la vuelvas a enseñar.") end   -- 8.9.5
    f.si = GL.CrearBoton(f, L"Añadir", function(self)
      local c = self:GetParent().c
      if not c then return end
      if c.mazmorra then if GL.AbrirMazmorra then GL.AbrirMazmorra(c.mazmorra.n) end return end
      if c.anadida then
        if c.w and GL.SeguirDesvio then GL.SeguirDesvio(c.w) end
      else
        Lista("opcAnadidas")[c.q] = true
        if c.w and GL.SeguirDesvio then GL.SeguirDesvio(c.w) end
      end
      if GL.Refrescar then GL.Refrescar() end
    end, nil, 18, "accion")
    f.si:SetWidth(64)
    f.si:SetPoint("RIGHT", f.no, "LEFT", -4, 0)
    -- 8.9.5: el nombre y el detalle pasan a dos líneas si no caben (antes se cortaban con «...»)
    f.texto = GL.Texto(f, "GameFontHighlightSmall")
    f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -1)
    if f.texto.SetMaxLines then f.texto:SetMaxLines(2) end
    f.det = GL.Texto(f, "GameFontHighlightSmall")
    f.det:SetPoint("TOPLEFT", f.texto, "BOTTOMLEFT", 0, -2)
    if f.det.SetMaxLines then f.det:SetMaxLines(2) end
    caja.filas[i] = f
  end
end

------------------------------------------------------------------------
-- 9.6: Guía clara: desplegable «Otras misiones cerca (N)», cerrado de serie. Al abrirlo, cada misión con su
-- nivel, la distancia y quién la da; clic en una: la flecha va allí. Clic derecho: no volver a enseñarla.
------------------------------------------------------------------------
local MAX_OTRAS = 8
local otras = nil
local function CrearOtras(panel)
  otras = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
  if GL.Caja then GL.Caja(otras, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.10 }) end
  otras.cab = CreateFrame("Button", nil, otras)
  otras.cab:SetHeight(26)
  otras.cab:SetPoint("TOPLEFT", otras, "TOPLEFT", 0, 0)
  otras.cab:SetPoint("TOPRIGHT", otras, "TOPRIGHT", 0, 0)
  local brillo = otras.cab:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.05)
  otras.signo = otras.cab:CreateTexture(nil, "ARTWORK")
  otras.signo:SetWidth(12); otras.signo:SetHeight(12)
  otras.signo:SetPoint("LEFT", otras.cab, "LEFT", 10, 0)
  otras.titulo = GL.Texto(otras.cab, "GameFontHighlightSmall")
  otras.titulo:SetPoint("LEFT", otras.signo, "RIGHT", 6, 0)
  otras.der = GL.Texto(otras.cab, "GameFontHighlightSmall", "RIGHT")
  otras.der:SetPoint("RIGHT", otras.cab, "RIGHT", -10, 0)
  otras.cab:SetScript("OnClick", function()
    DB().otrasAbiertas = not DB().otrasAbiertas
    if GL.Refrescar then GL.Refrescar() end
  end)
  otras.filas = {}
  for i = 1, MAX_OTRAS do
    local f = CreateFrame("Button", nil, otras)
    if f.RegisterForClicks then f:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    f.linea = f:CreateTexture(nil, "BACKGROUND")
    f.linea:SetHeight(1)
    f.linea:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.linea:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.linea:SetColorTexture(1, 1, 1, 0.07)
    local b = f:CreateTexture(nil, "HIGHLIGHT")
    b:SetAllPoints()
    b:SetColorTexture(1, 1, 1, 0.05)
    f.texto = GL.Texto(f, "GameFontHighlightSmall")
    f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
    f.der = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.der:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -6)
    f.texto:SetPoint("RIGHT", f.der, "LEFT", -8, 0)
    GL.UnaLinea(f.texto)
    f.det = GL.Texto(f, "GameFontHighlightSmall")
    f.det:SetPoint("TOPLEFT", f.texto, "BOTTOMLEFT", 0, -3)
    f.det:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    GL.UnaLinea(f.det)
    f:SetScript("OnClick", function(self, boton)
      local c = self.c
      if not c then return end
      if boton == "RightButton" then
        Lista("opcNo")[c.q] = true; Lista("opcAnadidas")[c.q] = nil
        if GL.Refrescar then GL.Refrescar() end
        return
      end
      if IsShiftKeyDown and IsShiftKeyDown() and c.w and GL.EnlazarMision and GL.EnlazarMision(c.w) then return end
      if c.mazmorra then if GL.AbrirMazmorra then GL.AbrirMazmorra(c.mazmorra.n) end return end
      if c.w and GL.SeguirDesvio then GL.SeguirDesvio(c.w) end   -- la flecha va allí sin cambiar de paso
    end)
    if GL.Ayuda then GL.Ayuda(f, L"Otras misiones cerca", L"Clic: la flecha te lleva allí sin cambiar de paso. Clic derecho: no volver a enseñarla.") end
    otras.filas[i] = f
  end
end

local function Lejos(m)
  if not m then return nil end
  if m >= 1000 then return string.format("%.1f km", m / 1000) end
  return m .. " m"
end

local function TarjetaOtras(panel, y, ancho)
  if otras then otras:Hide() end
  if Estilo() == "rapida" then return 0 end
  local ok, lista = pcall(Candidatas)
  if not ok or type(lista) ~= "table" or #lista == 0 then return 0 end
  if not otras then CrearOtras(panel) end
  local abierta = DB().otrasAbiertas == true
  otras.signo:SetTexture(abierta and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
  otras.titulo:SetText("|cffa48cff" .. L"Otras misiones cerca" .. C.FIN .. "  " .. C.GRIS .. "(" .. math.min(#lista, MAX_OTRAS) .. ")" .. C.FIN)
  otras.der:SetText(C.GRIS .. (abierta and L"no están en tu ruta" or L"pulsa para ver") .. C.FIN)
  if GL.Caja then
    if abierta then GL.Caja(otras, { 0.64, 0.55, 1, 0.05 }, { 0.64, 0.55, 1, 0.55 })
    else GL.Caja(otras, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.10 }) end
  end
  local alto = 26
  for i = 1, MAX_OTRAS do
    local f, c = otras.filas[i], lista[i]
    if abierta and c then
      f.c = c
      local nombre, nivel, quien
      if c.mazmorra then
        nombre = c.mq.n
        nivel = c.mazmorra.min .. "-" .. c.mazmorra.max
        quien = c.mazmorra.n .. " · " .. (c.mq.d or "")
      else
        nombre = c.o.n
        nivel = tostring(c.o.nivel or "?")
        local pnj = GL._PartirDestino and select(2, GL._PartirDestino(c.w.n))
        local que = (c.w.a == "T" and L"Entregar: ") or (c.w.a == "C" and L"Hacer: ") or L"Coger: "
        quien = que .. (pnj or tostring(c.w.n or "")) .. (c.w.z and (" · " .. c.w.z) or "")
      end
      f.texto:SetText("|cff8fb8ff[" .. tostring(nombre) .. "]|r" .. EtiquetaMision(c.q))
      f.der:SetText(C.GRIS .. L"nivel " .. nivel .. ((not c.mazmorra and c.dist) and (" · a " .. Lejos(c.dist)) or "") .. C.FIN)
      f.det:SetText(C.GRIS .. quien .. C.FIN)
      f:SetHeight(36)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", otras, "TOPLEFT", 0, -alto)
      f:SetPoint("TOPRIGHT", otras, "TOPRIGHT", 0, -alto)
      f:Show()
      alto = alto + 36
    else
      f.c = nil
      f:Hide()
    end
  end
  otras:ClearAllPoints()
  otras:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  otras:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  otras:SetHeight(alto + (abierta and 2 or 0))
  otras:Show()
  return alto + (abierta and 2 or 0)
end

local function TarjetaOpcionales(panel, y, ancho)
  if GL.GuiaClaraActiva and GL.GuiaClaraActiva() then   -- 9.6: desplegable
    if caja then caja:Hide() end
    return TarjetaOtras(panel, y, ancho)
  end
  if otras then otras:Hide() end
  if caja then caja:Hide() end
  if Estilo() == "rapida" then return 0 end
  local ok, lista = pcall(Candidatas)
  if not ok or type(lista) ~= "table" or #lista == 0 then return 0 end
  if not caja then CrearCaja(panel) end
  caja.titulo:SetText(L"OPCIONALES CERCA " .. C.GRIS .. L"(no están en tu ruta)" .. C.FIN)
  local n = math.min(#lista, MAX_FILAS)
  local usado = 0
  for i = 1, MAX_FILAS do
    local f, c = caja.filas[i], lista[i]
    f.c = (i <= n) and c or nil
    if i <= n then
      local etiqueta = EtiquetaMision(c.q)
      if c.mazmorra then
        local marca = L" |cffa335eeMAZMORRA|r"
        if not etiqueta:find(marca, 1, true) then etiqueta = marca .. etiqueta end
        f.texto:SetText(C.AMARILLO .. "[" .. c.mq.n .. "]" .. C.FIN .. etiqueta)
        f.det:SetText(C.GRIS .. c.mazmorra.n .. " (" .. c.mazmorra.min .. "-" .. c.mazmorra.max .. ") · " .. (c.mq.d or "") .. C.FIN)
        f.si.texto:SetText(L"Ver")
        if GL.BotonIcono then GL.BotonIcono(f.si, "ver", L"Ver", L"Abre la ficha de la mazmorra.") end
      else
        f.texto:SetText(C.AMARILLO .. "[" .. c.o.n .. "]" .. C.FIN .. " " .. C.GRIS .. "OPCIONAL" .. C.FIN .. etiqueta)
        local que = (c.w.a == "T" and "entregar") or (c.w.a == "C" and "objetivo") or "recoger"
        f.det:SetText(C.GRIS .. (c.dist and (L"a " .. c.dist .. " m · ") or (c.w.z and (L"en " .. c.w.z .. " · ") or "")) ..
          L"nivel " .. (c.o.nivel or "?") .. " · " .. que .. (c.anadida and L" · añadida" or "") ..
          C.FIN)
        f.si.texto:SetText(c.anadida and L"Llevarme" or L"Añadir")
        if GL.BotonIcono then
          if c.anadida then GL.BotonIcono(f.si, "llevar", L"Llevarme", L"La flecha te lleva a esta misión sin cambiar de paso.")
          else GL.BotonIcono(f.si, "anadir", L"Añadir", L"La añade a tu ruta y la flecha te lleva.") end
        end
      end
      local anchoTexto = math.max(80, (ancho or 360) - 18 - (f.si:GetWidth() or 64) - (f.no:GetWidth() or 40) - 10)
      f.texto:SetWidth(anchoTexto); f.det:SetWidth(anchoTexto)
      local hT = tonumber(f.texto.GetStringHeight and f.texto:GetStringHeight()) or 12
      local hD = tonumber(f.det.GetStringHeight and f.det:GetStringHeight()) or 12
      local altoFila = math.max(ALTO_FILA, math.floor(hT + hD + 6))
      f:SetHeight(altoFila)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", caja, "TOPLEFT", 10, -22 - usado)
      f:SetPoint("TOPRIGHT", caja, "TOPRIGHT", -8, -22 - usado)
      usado = usado + altoFila
      f:Show()
    else
      f:Hide()
    end
  end
  local alto = 26 + usado
  caja:ClearAllPoints()
  caja:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  caja:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  caja:SetHeight(alto)
  caja:Show()
  return alto
end
table.insert(GL.tarjetasGuia, 1, TarjetaOpcionales)

------------------------------------------------------------------------
-- Ajustes › Estilo de ruta
------------------------------------------------------------------------
GL.CrearEstiloRuta = function(padre)
  local cont = CreateFrame("Frame", nil, padre)
  cont:SetHeight(62)
  cont.altoFila = 66
  cont.texto = GL.Texto(cont, "GameFontHighlightSmall")
  cont.texto:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, 0)
  cont.texto:SetText(L"Estilo de ruta")
  cont.botones = {}
  local x = 0
  for _, e in ipairs(ESTILOS) do
    local b = GL.CrearBoton(cont, e.n, function()
      GuiaAventureroDB.estiloRuta = e.id
      cont.Actualizar()
      if GL.Refrescar then GL.Refrescar() end
    end, nil, 22)
    b:SetWidth(e.id == "mazmorras" and 100 or 72)
    b:SetPoint("TOPLEFT", cont, "TOPLEFT", x, -16)
    b.idEstilo = e.id
    if GL.Ayuda then GL.Ayuda(b, e.n, e.d) end
    table.insert(cont.botones, b)
    x = x + (e.id == "mazmorras" and 103 or 75)
  end
  cont.desc = GL.Texto(cont, "GameFontHighlightSmall")
  cont.desc:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, -44)
  cont.desc:SetPoint("RIGHT", cont, "RIGHT", 0, 0)
  GL.UnaLinea(cont.desc)
  cont.Actualizar = function()
    local elegido = Estilo()
    for _, b in ipairs(cont.botones) do b:SetActivo(b.idEstilo == elegido) end
    for _, e in ipairs(ESTILOS) do if e.id == elegido then cont.desc:SetText(C.GRIS .. e.d .. C.FIN) end end
  end
  return cont
end
GL._estilosRuta = ESTILOS

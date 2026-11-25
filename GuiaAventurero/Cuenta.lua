-- Cuenta.lua (7.4): botón Cuenta del lateral derecho. Lista los personajes de la cuenta con su nivel, zona y oro;
-- al pulsar uno se despliega su mochila (iconos, cantidades y tooltip). Abajo, el oro total de la cuenta.
-- Cada personaje se guarda en GuiaAventureroCuenta.personajes al conectar y al cambiar su oro o sus bolsas.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local ALTO_FILA, LADO_ICONO, MAX_FILAS, MAX_ICONOS = 20, 24, 10, 100

local function Cuenta()
  if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
  if type(GuiaAventureroCuenta.personajes) ~= "table" then GuiaAventureroCuenta.personajes = {} end
  -- 9.7.4: una vez por sesión, fuera lo guardado que no tiene la forma de ahora (la ventana fallaba con ello)
  if not GL._cuentaRevisada then
    GL._cuentaRevisada = true
    local function Lista(t, campo)
      if type(t) ~= "table" then return nil end
      local r = {}
      for _, o in ipairs(t) do if type(o) == "table" and type(o[campo]) == "string" then
        if campo == "l" then o.c = tonumber(o.c) or 1 end
        r[#r + 1] = o end end
      return r
    end
    for k, p in pairs(GuiaAventureroCuenta.personajes) do
      if type(p) ~= "table" or type(k) ~= "string" then GuiaAventureroCuenta.personajes[k] = nil
      else
        p.mochila, p.banco, p.profesiones = Lista(p.mochila, "l"), Lista(p.banco, "l"), Lista(p.profesiones, "n")
        p.oro = tonumber(p.oro); p.nivel = tonumber(p.nivel) or p.nivel
        if p.n ~= nil and type(p.n) ~= "string" then p.n = nil end
        if p.zona ~= nil and type(p.zona) ~= "string" then p.zona = nil end
      end
    end
  end
  return GuiaAventureroCuenta.personajes
end

local function ClavePersonaje()
  local n = UnitName and UnitName("player")
  if not n or n == "" then return nil end
  local r = GetRealmName and GetRealmName()
  if (not r or r == "") and GetNormalizedRealmName then r = GetNormalizedRealmName() end
  -- 9.7.7.3: en la 9.7.4 un personaje sin reino no se guardaba (al conectar el juego puede tardar en darlo y salía
  -- repetido). Si el juego no da nunca el reino, no se guardaba ninguno: «Aún no hay personajes guardados».
  -- Ahora se guarda como «Nombre-»; si después llega el reino, JuntarRepetidos junta los dos por su GUID.
  if type(r) ~= "string" then r = "" end
  return n .. "-" .. r
end
function GL.ClavePersonajeCuenta() return ClavePersonaje() end   -- para el informe de fallos

-- 9.7.4: el mismo personaje guardado con otra clave por versiones anteriores (sin reino, o antes de guardar
-- su GUID) se junta con el de ahora: se queda lo nuevo y, si al de ahora le falta, el banco de lo viejo
local function JuntarRepetidos(lista, clave, p)
  for k, q in pairs(lista) do
    if k ~= clave and type(q) == "table" then
      local mismo = (p.guid and q.guid == p.guid)
        or (not q.guid and q.n == p.n and q.clase == p.clase and q.raza == p.raza
            and (k == p.n or k == p.n .. "-" or (q.reino == nil and string.sub(k, 1, #p.n + 1) == p.n .. "-")))
      if mismo then
        if not p.banco and q.banco then p.banco, p.bancoUsados, p.bancoHuecos = q.banco, q.bancoUsados, q.bancoHuecos end
        lista[k] = nil
      end
    end
  end
end
GL._JuntarRepetidos = JuntarRepetidos

-- 9.7.4: quitar de la lista un personaje que ya no existe (clic derecho en su fila)
function GL.OlvidarPersonaje(clave)
  if not clave or clave == ClavePersonaje() then return false end
  local lista = Cuenta()
  if not lista[clave] then return false end
  lista[clave] = nil
  return true
end

------------------------------------------------------------------------
-- Guardar el personaje actual
------------------------------------------------------------------------
local BOLSAS, BANCO = { 0, 1, 2, 3, 4 }, { -1, 5, 6, 7, 8, 9, 10 }
local function LeerMochila(bolsas)
  local lista, usados, huecos = {}, 0, 0
  local num = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  if not num then return lista, 0, 0 end
  for _, b in ipairs(bolsas or BOLSAS) do
    local n = tonumber(num(b)) or 0
    huecos = huecos + n
    for s = 1, n do
      local link, cuenta, icono
      if C_Container and C_Container.GetContainerItemInfo then
        local i = C_Container.GetContainerItemInfo(b, s)
        if type(i) == "table" then link, cuenta, icono = i.hyperlink, i.stackCount, i.iconFileID end
      elseif GetContainerItemInfo then
        local tex, c, _, _, _, _, l = GetContainerItemInfo(b, s)
        link, cuenta, icono = l, c, tex
      end
      if link then
        usados = usados + 1
        if #lista < MAX_ICONOS then table.insert(lista, { l = link, c = cuenta or 1, i = icono }) end
      end
    end
  end
  return lista, usados, huecos
end

-- 7.5.5: habilidades del personaje (profesiones, equitación...) con su nivel
local PROFESIONES = { ["Sastrería"] = true, ["Encantamiento"] = true, ["Herrería"] = true, ["Ingeniería"] = true, ["Alquimia"] = true,
  ["Peletería"] = true, ["Minería"] = true, ["Herboristería"] = true, ["Desuello"] = true, ["Primeros auxilios"] = true,
  ["Cocina"] = true, ["Pesca"] = true }
-- 7.6.2: también por id de habilidad, por si el juego las nombra de otra forma
local PROF_ID = { [197] = "Sastrería", [333] = "Encantamiento", [164] = "Herrería", [202] = "Ingeniería", [171] = "Alquimia",
  [165] = "Peletería", [186] = "Minería", [182] = "Herboristería", [393] = "Desuello", [129] = "Primeros auxilios",
  [185] = "Cocina", [356] = "Pesca" }
GL.Habilidades = function()
  local r = {}
  if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
    for i = 1, (tonumber(C_SkillInfo.GetNumSkillLines()) or 0) do
      local info = C_SkillInfo.GetSkillLineInfo(i)
      if type(info) == "table" and not info.isHeader and info.name then
        table.insert(r, { n = info.name, id = info.skillID, rango = info.rank, tope = info.maxRank or info.skillMaxRank })
      end
    end
  elseif GetNumSkillLines and GetSkillLineInfo then
    for i = 1, (tonumber(GetNumSkillLines()) or 0) do
      local nom, cab, _, rango, _, _, tope = GetSkillLineInfo(i)
      if nom and not cab then table.insert(r, { n = nom, rango = rango, tope = tope }) end
    end
  end
  return r
end

-- 7.5.4: ajustes que se pueden copiar de un personaje a otro (no automatismos ni progreso)
local AJUSTES = { "tema", "escala", "opacidad", "escalaFlecha", "tamTexto", "bloqueada", "recompensa", "instructor", "marcaMapa", "marcaPantalla", "modoPesca", "rangosBarras", "rangosAuto", "guiaClara",
  "pinesMapa", "minimapa", "destello", "discretoCombate", "comparador", "avisos", "grupo", "retrato", "celebracion",
  "minimapaDestinos", "bienvenida", "flechaColor", "autoSeguimiento", "sonidos", "infoContextual", "ahorro", "barraBuffs",
  -- 8.8: aspecto
  "estiloFlecha", "marco", "fuentePaso", "fuenteContorno", "segmentos", "barritas", "iconosTipo", "escudo",
  "transicion", "anillo", "rutaMapa", "atenuar", "tarjetaSeccion",
  -- 8.9
  "retratoCabecera", "barraXP", "fondoZona", "insignias", "ayudasEstilo", "hitos", "flechaCrece", "alturaFlecha", "confeti",
  -- 8.9.1
  "degradado", "separadores", "calidad", "recompensasPaso", "xpFlotante", "avisoObjetivo", "brilloFlecha", "fundido", "brilloBarra", "compactoEstilo",
  -- 8.9.5
  "lineaAhora", "chips", "avisosPlegables", "resaltarPaso", "casillas", "distanciaColor" }
GL.AJUSTES_COPIABLES = AJUSTES

local function TiempoJugado()
  local db = GuiaAventureroDB
  local t = 0
  if type(db) == "table" and db.estadisticas and db.estadisticas.niveles then
    for _, d in pairs(db.estadisticas.niveles) do t = t + (d.t or 0) end
  end
  return t
end

local function Guardar(conMochila, evento)
  local clave = ClavePersonaje()
  if not clave then return end
  if evento == "PLAYER_LOGOUT" then return end   -- 7.6.2: al salir el juego ya da bolsas y oro vacíos y pisaba lo guardado
  local lista = Cuenta()
  local p = lista[clave] or {}
  p.n = UnitName("player")
  p.reino = GetRealmName and GetRealmName() or p.reino
  p.guid = (UnitGUID and UnitGUID("player")) or p.guid
  local clase = UnitClass and select(2, UnitClass("player"))
  p.clase = clase
  p.raza = UnitRace and UnitRace("player")
  p.nivel = UnitLevel and UnitLevel("player")
  -- 7.6.2: un 0 solo se cree si viene de un cambio de oro (al conectar el juego puede dar 0 un momento)
  local oro = GetMoney and GetMoney()
  if GL.Seguro then oro = GL.Seguro(oro) end
  if type(oro) == "number" and (oro > 0 or evento == "PLAYER_MONEY" or not p.oro) then p.oro = oro end
  p.oro = p.oro or 0
  p.zona = (GetZoneText and GetZoneText()) or p.zona
  local t = TiempoJugado()
  if t > 0 then p.tiempo = t end
  if conMochila then
    local m, usados, huecos = LeerMochila(BOLSAS)
    if huecos > 0 then p.mochila, p.usados, p.huecos = m, usados, huecos end   -- 7.6.2: sin huecos = el juego aún no ha cargado las bolsas
  end
  local prof, vistas = {}, {}
  for _, h in ipairs(GL.Habilidades()) do
    local nombre = (h.id and PROF_ID[h.id]) or (PROFESIONES[h.n] and h.n)
    if nombre then   -- 7.6.2: sin repetir (el juego puede listar la misma dos veces) y con su tope
      local r = tonumber(h.rango) or 0
      if vistas[nombre] then
        if r > vistas[nombre].r then vistas[nombre].r = r end
      else
        vistas[nombre] = { n = nombre, r = r, tope = tonumber(h.tope), id = h.id }
        table.insert(prof, vistas[nombre])
      end
    end
  end
  if #prof > 0 then p.profesiones = prof end
  local db = GuiaAventureroDB
  if type(db) == "table" then
    p.ajustes = {}
    for _, k in ipairs(AJUSTES) do p.ajustes[k] = db[k] end
  end
  p.visto = time and time() or nil
  lista[clave] = p
  pcall(JuntarRepetidos, lista, clave, p)
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------
-- 7.5.3: el banco se guarda al abrirlo y mientras está abierto
local bancoAbierto = false
local function GuardarBanco()
  local clave = ClavePersonaje()
  if not clave or not bancoAbierto then return end
  local p = Cuenta()[clave]
  if not p then return end
  p.banco, p.bancoUsados, p.bancoHuecos = LeerMochila(BANCO)
end

local panel, ui = nil, { filas = {}, iconos = {} }
local abierto = nil   -- clave del personaje desplegado
local verBanco = false
local busqueda = ""

-- 7.5.2: busca un objeto (por nombre) en las mochilas y bancos de todos los personajes
local function Buscar(texto)
  texto = string.lower(texto or "")
  local porObjeto, orden = {}, {}
  for k, p in pairs(Cuenta()) do
    for _, sitio in ipairs({ { "mochila", p.mochila }, { "banco", p.banco } }) do
      for _, o in ipairs(sitio[2] or {}) do
        local nombre = o.l and o.l:match("%[(.-)%]")
        if nombre and string.find(string.lower(nombre), texto, 1, true) then
          if not porObjeto[nombre] then porObjeto[nombre] = { n = nombre, i = o.i, l = o.l, donde = {} }; table.insert(orden, nombre) end
          local cl = (p.n or k) .. "|" .. sitio[1]
          porObjeto[nombre].donde[cl] = (porObjeto[nombre].donde[cl] or 0) + (o.c or 1)
        end
      end
    end
  end
  table.sort(orden)
  local r = {}
  for _, n in ipairs(orden) do table.insert(r, porObjeto[n]) end
  return r
end
GL.BuscarEnCuenta = Buscar

-- 9.7.4: cuántas unidades de un objeto (por su número) guarda cada personaje en la mochila y en el banco,
-- según lo último que vio la guía. propio = el personaje con el que juegas.
function GL.ContarObjetoCuenta(id)
  local res, mia = {}, ClavePersonaje()
  if not id then return res end
  for k, p in pairs(Cuenta()) do
    local m, b = 0, 0
    for _, o in ipairs(p.mochila or {}) do
      if tonumber(o.l and o.l:match("item:(%d+)")) == id then m = m + (o.c or 1) end
    end
    for _, o in ipairs(p.banco or {}) do
      if tonumber(o.l and o.l:match("item:(%d+)")) == id then b = b + (o.c or 1) end
    end
    if m > 0 or b > 0 or k == mia then table.insert(res, { n = p.n or k, mochila = m, banco = b, propio = (k == mia) }) end
  end
  table.sort(res, function(a, b2) return (a.mochila + a.banco) > (b2.mochila + b2.banco) end)
  return res
end

local function ColorClase(clase)
  local c = type(RAID_CLASS_COLORS) == "table" and clase and RAID_CLASS_COLORS[clase]
  if type(c) ~= "table" then return C.BLANCO end
  if c and c.colorStr then return "|c" .. c.colorStr end
  if c and c.r then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
  return C.BLANCO
end

local function Duracion(seg)
  seg = math.floor(seg or 0)
  local h, m = math.floor(seg / 3600), math.floor((seg % 3600) / 60)
  if h > 0 then return h .. " h " .. m .. L" min" end
  return m .. L" min"
end

local function Ordenados()
  local r = {}
  for k, p in pairs(Cuenta()) do table.insert(r, { k = k, p = p }) end
  table.sort(r, function(a, b)
    if (a.p.nivel or 0) ~= (b.p.nivel or 0) then return (a.p.nivel or 0) > (b.p.nivel or 0) end
    return a.k < b.k
  end)
  return r
end

-- 9.0: tres vistas en un selector: Hoy, Personajes y Buscar objeto
local function Vista() return (type(GuiaAventureroDB) == "table" and GuiaAventureroDB.vistaCuenta) or "hoy" end
local function Refrescar()
  if not panel then return end
  local vista = Vista()
  if ui.vistas then for _, b in ipairs(ui.vistas) do b:SetActivo(b.vista == vista) end end
  if ui.hoy then GL.Mostrar(ui.hoy, vista == "hoy") end
  if vista == "hoy" and ui.hoy and GL.PintarHoy then
    for i = 1, MAX_FILAS do ui.filas[i]:Hide() end
    for i = 1, #ui.iconos do ui.iconos[i]:Hide() end
    ui.det:Hide(); ui.buscar:Hide(); ui.resultados:SetText(""); ui.cab:Hide(); ui.cabOro:Hide(); ui.vacio:SetText("")
    ui.total:SetText(""); ui.totalOro:SetText(""); ui.nota:SetText("")
    local ok, err = pcall(GL.PintarHoy, ui.hoy)
    if not ok and GL.Mensaje then GL.Mensaje(L"error en Hoy: " .. tostring(err)) end
    return
  end
  if vista == "personajes" then
    ui.buscar:Hide()
    if busqueda ~= "" then busqueda = ""; ui.buscar:SetText("") end
  else
    ui.buscar:Show()
  end
  local lista = Ordenados()
  local nGuardados = #lista
  local total = 0
  for _, e in ipairs(lista) do total = total + (e.p.oro or 0) end
  local ancho = panel:GetWidth() or 360
  if ancho < 100 then ancho = 360 end
  local cols = math.max(4, math.floor((ancho - 20) / (LADO_ICONO + 3)))
  local y, usadas = -42, 0
  for i = 1, #ui.iconos do ui.iconos[i]:Hide() end
  ui.det:Hide()
  ui.resultados:SetText("")
  if busqueda ~= "" then   -- 7.5.2: resultados en lugar de la lista de personajes
    for i = 1, MAX_FILAS do ui.filas[i]:Hide() end
    local res = Buscar(busqueda)
    local l = { C.GRIS .. L"RESULTADOS DE «" .. string.upper(busqueda) .. "»" .. C.FIN }
    for i = 1, math.min(#res, 12) do
      local partes = {}
      for cl, n in pairs(res[i].donde) do
        local quien, sitio = cl:match("^(.-)|(.*)$")
        table.insert(partes, quien .. " " .. C.GRIS .. sitio .. C.FIN .. " " .. n)
      end
      table.sort(partes)
      table.insert(l, (res[i].i and ("|T" .. res[i].i .. ":14|t ") or "") .. res[i].n .. ":  " .. table.concat(partes, "  ·  "))
    end
    if #res == 0 then table.insert(l, C.GRIS .. L"Ningún personaje lo tiene (o aún no se ha visto su banco)." .. C.FIN) end
    if #res > 12 then table.insert(l, C.GRIS .. "Y " .. (#res - 12) .. L" objetos más: escribe más letras." .. C.FIN) end
    ui.resultados:SetText(table.concat(l, "\n"))
    lista = {}   -- 9.2: la cuenta de personajes de abajo sigue siendo la de todos (nGuardados)
  end
  for _, e in ipairs(lista) do
    if usadas >= MAX_FILAS then break end
    usadas = usadas + 1
    local f, p = ui.filas[usadas], e.p
    f.clave = e.k
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y)
    local abre = (abierto == e.k)
    f.flecha:SetText(C.GRIS .. (abre and "v" or ">") .. C.FIN)
    f.nombre:SetText(ColorClase(p.clase) .. (p.n or e.k) .. C.FIN)
    f.nivel:SetText(tostring(p.nivel or "?"))
    f.zona:SetText(C.GRIS .. (p.zona or "") .. C.FIN)
    f.oro:SetText(GL.Dinero and GL.Dinero(p.oro or 0) or tostring(p.oro or 0))
    GL.Mostrar(f.marca, abre)
    GL.Mostrar(f.par, usadas % 2 == 0)
    f:Show()
    y = y - ALTO_FILA
    if abre then
      local m = (verBanco and p.banco) or (not verBanco and p.mochila) or {}
      local filasIcono = math.max(1, math.ceil(#m / cols))
      local alto = 48 + filasIcono * (LADO_ICONO + 3) + 6
      ui.det:ClearAllPoints()
      ui.det:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y - 2)
      ui.det:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y - 2)
      ui.det:SetHeight(alto)
      local partes = {}
      local yaPuesta = {}
      for _, pr in ipairs(p.profesiones or {}) do
        if not yaPuesta[pr.n] then yaPuesta[pr.n] = true; table.insert(partes, pr.n .. " " .. C.BLANCO .. (tonumber(pr.r) or 0) .. C.FIN .. C.GRIS) end
      end
      if #partes == 0 then partes = { L"Sin profesiones guardadas" } end
      if p.tiempo then table.insert(partes, Duracion(p.tiempo) .. L" jugadas") end
      if p.visto and date then table.insert(partes, L"visto el " .. date(L"%d/%m a las %H:%M", p.visto)) end
      ui.det.cab:SetText(C.GRIS .. table.concat(partes, "  ·  ") .. C.FIN)
      ui.det.mochila.texto:SetText(L"Mochila " .. (p.huecos and ((p.usados or 0) .. "/" .. p.huecos) or ""))
      ui.det.banco.texto:SetText(L"Banco " .. (p.bancoHuecos and ((p.bancoUsados or 0) .. "/" .. p.bancoHuecos) or ""))
      ui.det.mochila:SetActivo(not verBanco); ui.det.banco:SetActivo(verBanco)
      ui.det.vacio:SetText(#m == 0 and (C.GRIS .. (verBanco and L"Abre el banco con este personaje para guardarlo." or L"Conecta con este personaje para ver su mochila.") .. C.FIN) or "")
      for j = 1, #m do
        local b = ui.iconos[j]
        if not b then
          b = CreateFrame("Button", nil, ui.det, PLANTILLA)
          b:SetWidth(LADO_ICONO); b:SetHeight(LADO_ICONO)
          if GL.Caja and GL.COLOR then GL.Caja(b, GL.COLOR.icono or { 0, 0, 0, 1 }, GL.COLOR.iconoBorde or GL.COLOR.botonBorde) end
          b.tex = b:CreateTexture(nil, "ARTWORK")
          b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
          b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
          b.num = GL.Texto(b, "NumberFontNormalSmall", "RIGHT")
          b.num:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
          b:SetScript("OnEnter", function(self)
            if not (GameTooltip and self.link) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
            GameTooltip:Show()
          end)
          b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
          b:SetScript("OnClick", function(self)   -- Shift+clic: enlazar en el chat
            if IsShiftKeyDown and IsShiftKeyDown() and self.link and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
          end)
          ui.iconos[j] = b
        end
        local fila, col = math.floor((j - 1) / cols), (j - 1) % cols
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", ui.det, "TOPLEFT", 8 + col * (LADO_ICONO + 3), -46 - fila * (LADO_ICONO + 3))
        b.link = m[j].l
        local icono = m[j].i
        if not icono and GetItemIcon then icono = GetItemIcon(m[j].l) end
        b.tex:SetTexture(icono or 134400)
        b.num:SetText((m[j].c or 1) > 1 and m[j].c or "")
        b:Show()
      end
      ui.det:Show()
      y = y - alto - 4
    end
  end
  for i = usadas + 1, MAX_FILAS do ui.filas[i]:Hide() end
  -- 9.7.7.3: sin personajes no sale la cabecera de columnas (el aviso de lista vacía se montaba encima)
  GL.Mostrar(ui.cab, busqueda == "" and nGuardados > 0); GL.Mostrar(ui.cabOro, busqueda == "" and nGuardados > 0)
  ui.cab:SetText(C.GRIS .. L"PERSONAJE  ·  NIVEL  ·  ZONA" .. C.FIN)
  ui.vacio:SetText(nGuardados == 0 and (C.GRIS .. L"Aún no hay personajes guardados." .. C.FIN) or "")
  if Vista() == "buscar" and busqueda == "" then   -- 9.0: en Buscar objeto, sin texto, una pista en lugar de la lista
    for i = 1, MAX_FILAS do ui.filas[i]:Hide() end
    ui.det:Hide(); ui.cab:Hide(); ui.cabOro:Hide(); ui.vacio:SetText("")
    ui.resultados:SetText(C.GRIS .. L"Escribe el nombre de un objeto: busca en las bolsas y el banco de todos tus personajes." .. C.FIN)
  end
  ui.total:SetText(C.AMARILLO .. L"ORO TOTAL DE LA CUENTA" .. C.FIN)
  ui.totalOro:SetText(GL.Dinero and GL.Dinero(total) or tostring(total))
  ui.nota:SetText(C.GRIS .. nGuardados .. (nGuardados == 1 and L" personaje" or L" personajes") .. L". Conecta una vez con cada uno para que salga." .. C.FIN)
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + GL.ALTO_SUB))   -- 9.0: debajo, el selector
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  -- 9.0: selector Hoy / Personajes / Buscar objeto, encima del panel (como las subpestañas)
  -- 9.2: el selector va en la ventana y no en el panel: el panel recorta lo que sale de él (7.6.1) y el selector,
  -- que está encima, no se veía (solo se veía Hoy y no se podía llegar a Personajes ni a Buscar objeto).
  local seg = CreateFrame("Frame", nil, frame, PLANTILLA)
  seg:SetFrameLevel((panel:GetFrameLevel() or 1) + 2)
  seg:Hide()
  panel:HookScript("OnShow", function() seg:Show() end)
  panel:HookScript("OnHide", function() seg:Hide() end)
  seg:SetHeight(GL.ALTO_SUB - 6)
  seg:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 4)
  seg:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 4)
  if GL.Caja and GL.COLOR then GL.Caja(seg, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  ui.vistas = {}
  for i, v in ipairs({ { "hoy", L"Hoy" }, { "personajes", L"Personajes" }, { "buscar", L"Buscar objeto" } }) do
    local b = GL.CrearBoton(seg, v[2], function()
      GuiaAventureroDB.vistaCuenta = v[1]
      Refrescar()
      if v[1] == "buscar" and ui.buscar then ui.buscar:SetFocus() end
    end, nil, GL.ALTO_SUB - 12, "pestana")
    b.vista = v[1]
    ui.vistas[i] = b
  end
  -- 9.7.4: también al abrirse (antes solo al cambiar de tamaño, y al abrir medían 90)
  local function ColocarVistas(w)
    w = tonumber(w) or 0
    if w < 100 then w = (seg.GetWidth and tonumber(seg:GetWidth())) or 0 end
    if w < 100 and GL.frame and GL.frame.GetWidth then w = (tonumber(GL.frame:GetWidth()) or 0) - 80 end
    if w < 100 then w = 300 end
    local bw = math.floor((w - 6 - 2 * 6) / 3)
    for i, b in ipairs(ui.vistas) do b:SetWidth(bw); b:ClearAllPoints(); b:SetPoint("TOPLEFT", seg, "TOPLEFT", 3 + (i - 1) * (bw + 6), -3) end
  end
  ui.ColocarVistas = ColocarVistas
  seg:SetScript("OnSizeChanged", function(self, w) ColocarVistas(w) end)
  seg:SetScript("OnShow", function(self) ColocarVistas() end)
  ColocarVistas()
  ui.hoy = CreateFrame("Frame", nil, panel)
  ui.hoy:SetAllPoints(panel)
  ui.hoy:Hide()
  -- 7.5.2: buscador
  local caja = CreateFrame("EditBox", nil, panel, PLANTILLA)
  caja:SetHeight(20)
  caja:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  caja:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  caja:SetAutoFocus(false)
  caja:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  caja:SetTextInsets(6, 6, 0, 0)
  if GL.Caja and GL.COLOR then GL.Caja(caja, { 0, 0, 0, 0.4 }, GL.COLOR.botonBorde) end
  local pista = GL.Texto(caja, "GameFontDisableSmall")
  pista:SetPoint("LEFT", caja, "LEFT", 6, 0)
  pista:SetText(L"Buscar un objeto en todos tus personajes...")
  caja:SetScript("OnTextChanged", function(self)
    busqueda = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    GL.Mostrar(pista, busqueda == "" and not self:HasFocus())
    Refrescar()
  end)
  caja:SetScript("OnEditFocusGained", function() pista:Hide() end)
  caja:SetScript("OnEditFocusLost", function() GL.Mostrar(pista, busqueda == "") end)
  caja:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  caja:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  ui.buscar = caja
  ui.resultados = GL.Texto(panel, "GameFontHighlightSmall")
  ui.resultados:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -28)
  ui.resultados:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -28)
  ui.cab = GL.Texto(panel, "GameFontHighlightSmall")
  ui.cab:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -26)
  ui.cab:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -26); GL.UnaLinea(ui.cab)   -- 7.6.1: dentro del marco
  ui.cabOro = GL.Texto(panel, "GameFontHighlightSmall", "RIGHT")
  ui.cabOro:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -26)
  ui.cabOro:SetText(C.GRIS .. "ORO" .. C.FIN)
  for i = 1, MAX_FILAS do
    local f = CreateFrame("Button", nil, panel)
    f:SetHeight(ALTO_FILA)
    f.par = f:CreateTexture(nil, "BACKGROUND")
    f.par:SetAllPoints(); f.par:SetColorTexture(1, 1, 1, 0.035)
    f.marca = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.marca:SetAllPoints(); f.marca:SetColorTexture(1, 0.82, 0, 0.12)
    local brillo = f:CreateTexture(nil, "HIGHLIGHT")
    brillo:SetAllPoints(); brillo:SetColorTexture(1, 1, 1, 0.06)
    f.flecha = GL.Texto(f, "GameFontHighlightSmall")
    f.flecha:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.nombre = GL.Texto(f, "GameFontHighlightSmall")
    f.nombre:SetPoint("LEFT", f, "LEFT", 16, 0)
    f.nombre:SetWidth(110)
    GL.UnaLinea(f.nombre)
    f.nivel = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.nivel:SetPoint("LEFT", f, "LEFT", 126, 0)
    f.nivel:SetWidth(22)
    f.oro = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.oro:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    f.zona = GL.Texto(f, "GameFontHighlightSmall")
    f.zona:SetPoint("LEFT", f.nivel, "RIGHT", 8, 0)
    f.zona:SetPoint("RIGHT", f.oro, "LEFT", -8, 0)
    GL.UnaLinea(f.zona)
    if f.RegisterForClicks then f:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    f:SetScript("OnClick", function(self, boton)
      if boton == "RightButton" then   -- 9.7.4: clic derecho, quitar un personaje que ya no existe
        if GL.OlvidarPersonaje(self.clave) then
          if abierto == self.clave then abierto = nil end
          Refrescar()
        end
        return
      end
      abierto = (abierto ~= self.clave) and self.clave or nil
      Refrescar()
    end)
    -- 9.7.4: la zona puede salir cortada; en el tooltip va entera, con el reino y cuándo se vio
    f:SetScript("OnEnter", function(self)
      local q = self.clave and Cuenta()[self.clave]
      if not q or not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine((q.n or self.clave) .. ((q.reino and q.reino ~= "") and (" - " .. q.reino) or ""), 1, 1, 1)
      if q.zona and q.zona ~= "" then GameTooltip:AddLine(q.zona, 0.8, 0.8, 0.8) end
      if q.visto and date then GameTooltip:AddLine(L"Visto por última vez: " .. date("%d/%m/%Y %H:%M", q.visto), 0.6, 0.6, 0.6) end
      if self.clave == ClavePersonaje() then
        GameTooltip:AddLine(L"Este personaje.", 0.4, 0.8, 1)
      else
        GameTooltip:AddLine(L"Clic derecho: quitarlo de la lista (si ya no existe o sale repetido). Vuelve a salir si conectas con él.", 0.6, 0.6, 0.6, true)
      end
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    ui.filas[i] = f
  end
  local det = CreateFrame("Frame", nil, panel, PLANTILLA)
  if GL.Caja and GL.COLOR then GL.Caja(det, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  local borde = det:CreateTexture(nil, "ARTWORK")
  borde:SetWidth(3)
  borde:SetPoint("TOPLEFT", det, "TOPLEFT", 0, 0)
  borde:SetPoint("BOTTOMLEFT", det, "BOTTOMLEFT", 0, 0)
  borde:SetColorTexture(1, 0.78, 0.25, 1)
  det.cab = GL.Texto(det, "GameFontHighlightSmall")
  det.cab:SetPoint("TOPLEFT", det, "TOPLEFT", 8, -5)
  det.cab:SetPoint("RIGHT", det, "RIGHT", -6, 0)
  GL.UnaLinea(det.cab)
  det.mochila = GL.CrearBoton(det, L"Mochila", function() verBanco = false; Refrescar() end, nil, 18)
  det.mochila:SetWidth(96)
  det.mochila:SetPoint("TOPLEFT", det, "TOPLEFT", 8, -22)
  det.banco = GL.CrearBoton(det, L"Banco", function() verBanco = true; Refrescar() end, nil, 18)
  det.banco:SetWidth(96)
  det.banco:SetPoint("LEFT", det.mochila, "RIGHT", 4, 0)
  det.vacio = GL.Texto(det, "GameFontHighlightSmall")
  det.vacio:SetPoint("TOPLEFT", det, "TOPLEFT", 8, -48)
  det:Hide()
  ui.det = det
  ui.vacio = GL.Texto(panel, "GameFontHighlightSmall")
  ui.vacio:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -20)
  ui.vacio:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -20); GL.UnaLinea(ui.vacio)   -- 7.6.1: dentro del marco
  local raya = panel:CreateTexture(nil, "ARTWORK")
  raya:SetHeight(1)
  raya:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 38)
  raya:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 38)
  raya:SetColorTexture(1, 1, 1, 0.12)
  ui.total = GL.Texto(panel, "GameFontNormal")
  ui.total:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 2, 20)
  ui.total:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 20); GL.UnaLinea(ui.total)   -- 7.6.1: dentro del marco
  ui.totalOro = GL.Texto(panel, "GameFontNormal", "RIGHT")
  ui.totalOro:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 20)
  ui.nota = GL.Texto(panel, "GameFontHighlightSmall")
  ui.nota:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 2, 4)
  ui.nota:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4); GL.UnaLinea(ui.nota)   -- 7.6.1: dentro del marco
  GL.modos.cuenta = { panel = panel, refrescar = function() pcall(Guardar, false); Refrescar() end }
end
table.insert(GL.alIniciar, CrearPanel)

------------------------------------------------------------------------
-- Eventos: guardar al conectar, al cambiar el oro, el nivel o las bolsas
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
GL.Evento(ev, "PLAYER_ENTERING_WORLD")
GL.Evento(ev, "PLAYER_MONEY")
GL.Evento(ev, "PLAYER_LEVEL_UP")
GL.Evento(ev, "BAG_UPDATE_DELAYED")
GL.Evento(ev, "PLAYER_LOGOUT")
GL.Evento(ev, "BANKFRAME_OPENED")
GL.Evento(ev, "BANKFRAME_CLOSED")
GL.Evento(ev, "PLAYERBANKSLOTS_CHANGED")
GL.Evento(ev, "SKILL_LINES_CHANGED")
ev:SetScript("OnEvent", function(_, evento)
  if evento == "BANKFRAME_OPENED" then bancoAbierto = true end
  pcall(Guardar, evento ~= "PLAYER_MONEY" and evento ~= "PLAYER_LEVEL_UP", evento)
  if bancoAbierto then pcall(GuardarBanco) end
  if evento == "BANKFRAME_CLOSED" then bancoAbierto = false end
  if panel and panel:IsShown() then pcall(Refrescar) end
end)

-- 7.6.2: profesiones de los otros personajes de la cuenta (para la Biblioteca). Devuelve { { n = personaje, r = nivel } }.
GL.ProfesionEnCuenta = function(nombre, id)
  local r, yo = {}, ClavePersonaje()
  for k, p in pairs(Cuenta()) do
    if k ~= yo then
      for _, pr in ipairs(p.profesiones or {}) do
        if pr.n == nombre or (id and pr.id == id) then table.insert(r, { n = p.n or k, r = pr.r or 0, tope = pr.tope }); break end
      end
    end
  end
  table.sort(r, function(a, b) return a.r > b.r end)
  return r
end

-- Para las pruebas
GL._cuenta = { Guardar = Guardar, Refrescar = Refrescar, Abrir = function(k) abierto = k end, Buscar = Buscar,
  Banco = function() bancoAbierto = true; GuardarBanco() end, VerBanco = function(v) verBanco = v end,
  Busqueda = function(t) busqueda = t or "" end }

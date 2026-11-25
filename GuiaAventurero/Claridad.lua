-- Claridad.lua (8.9.5): mejoras para que la Guía se lea más clara. Creado por JKRiveroF.
-- Línea «Ahora» encima del paso, etiquetas en la cabecera, avisos plegables, palabras clave resaltadas en el paso,
-- objetivos con casilla, distancia con color en Siguiente, botones con icono y modo lectura.
-- Todo (menos el modo lectura, que va con su botón) se apaga en Opciones > Ajustes (pestañas Paso y Avisos y ayudas).

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local function DB() return GuiaAventureroDB or {} end
local function Si(k) return DB()[k] ~= false end
local function Probar(fn, nombre, ...)
  local ok, err = pcall(fn, ...)
  if not ok and GL.Fallo(nombre, err) and GL.Mensaje then GL.Mensaje(L"error en " .. nombre .. ": " .. tostring(err)) end
  return ok and err
end
local function Num(v) return type(v) == "number" and v or nil end
local function Campo(t, k) return type(t) == "table" and rawget(t, k) or nil end

local VERDE_NPC = "|cff7ee08a"
local AZUL_LUGAR = "|cff69ccf0"
local DORADO_ACCION = "|cffffdf8a"

-- Distancia en yardas a un destino, o nil si no se sabe (otro mapa, dentro de una mazmorra...).
local function Yardas(d)
  if type(d) ~= "table" or not GL.Vector then return nil end
  local ok, este, _, dist = pcall(GL.Vector, d)
  if ok and este and type(dist) == "number" then return dist end
  return nil
end
local function Metros(yd) return math.floor(yd * 0.9144 + 0.5) end
-- 43: verde cerca (hasta 100 m), amarillo a media distancia (hasta 500 m) y blanco lejos
local function ColorDistancia(m)
  if m <= 100 then return GL.colorCerca or "|cff40d959" elseif m <= 500 then return "|cffffd100" end
  return "|cffffffff"
end
local function TextoMetros(yd)
  if not yd then return "" end
  local m = Metros(yd)
  local t = (m >= 1000) and string.format(L"%.1f km", m / 1000) or (m .. " m")
  return ColorDistancia(m) .. t .. "|r"
end
GL.TextoMetros = TextoMetros

------------------------------------------------------------------------
-- 39. Botones con icono (Llevarme, Añadir, Ver, No): más pequeños y con su ayuda al pasar el ratón
------------------------------------------------------------------------
GL.ICONOS_BOTON = {
  llevar = GL.RUTA_FLECHA or "Interface\\AddOns\\GuiaAventurero\\flecha",
  anadir = "Interface\\Buttons\\UI-PlusButton-Up",
  ver = "Interface\\Icons\\INV_Misc_Map_01",
  no = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
function GL.BotonIcono(b, clave, titulo, texto)
  if not b then return end
  local ic = Campo(b, "iconoBoton")
  if not ic then
    ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetWidth(14); ic:SetHeight(14)
    ic:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.iconoBoton = ic
  end
  local ruta = GL.ICONOS_BOTON[clave] or GL.INTERROGANTE
  if GL.PonerIcono then GL.PonerIcono(ic, ruta, clave == "ver") else ic:SetTexture(ruta) end
  if clave == "llevar" and ic.SetRotation then pcall(ic.SetRotation, ic, -math.pi / 2) end   -- la flecha apunta a la derecha
  ic:Show()
  local t = Campo(b, "texto")
  if t then t:SetText("") end
  b:SetWidth(24)
  if GL.Ayuda then GL.Ayuda(b, titulo, texto) end
end

------------------------------------------------------------------------
-- 34. Línea «Ahora» encima del texto del paso: qué hacer y a cuántos metros
------------------------------------------------------------------------
local VERBOS_DESTINO = { Recoger = L"Recoge", Entregar = L"Entrega", Objetivo = L"Completa" }
local ahora

local function TextoAhora(d)
  local n = tostring(d.n or "")
  local accion, resto = string.match(n, "^([^:]+):%s*(.+)$")
  local verbo, que, quien
  if accion and VERBOS_DESTINO[accion] then
    verbo = VERBOS_DESTINO[accion]
    que, quien = string.match(resto, "^(.-)%s*%(([^()]+)%)$")
    que = que or resto
  elseif string.find(n, "^Vuelo") then
    verbo, que = L"Activa el", string.lower(string.sub(n, 1, 1)) .. string.sub(n, 2)
  else
    verbo, que = L"Ve a", n
  end
  local t = C.AMARILLO .. L"Ahora: " .. C.FIN .. DORADO_ACCION .. verbo .. C.FIN .. " " .. C.BLANCO .. que .. C.FIN
  if quien then t = t .. " " .. C.GRIS .. L"con" .. C.FIN .. " " .. VERDE_NPC .. quien .. C.FIN end
  local yd = Yardas(d)
  if yd then t = t .. C.GRIS .. "  ·  " .. C.FIN .. TextoMetros(yd) end
  return t
end
GL.TextoAhora = TextoAhora

-- Devuelve el alto que ocupa (0 si no se pinta). La llama RefrescarGuia antes de colocar el texto del paso.
function GL.PintarAhora(caja, d, r, ancho)
  if ahora then ahora:Hide(); ahora.fondo:Hide() end
  if not Si("lineaAhora") or type(d) ~= "table" or not caja then return 0 end
  if not ahora then
    ahora = caja:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ahora:SetJustifyH("LEFT")
    if ahora.SetMaxLines then ahora:SetMaxLines(2) end   -- en ventanas estrechas pasa a dos líneas
    local f, _, o = ahora:GetFont()
    if type(f) == "string" then ahora:SetFont(f, 14, o) end
    ahora.fondo = caja:CreateTexture(nil, "BORDER")
    ahora.fondo:SetHeight(20)
  end
  ahora.d = d
  ahora:ClearAllPoints()
  ahora:SetPoint("TOPLEFT", caja, "TOPLEFT", 14 + (r or 0), -25)
  ahora:SetWidth(math.max(60, (ancho or 360) - 24 - (r or 0)))
  ahora:SetText(TextoAhora(d))
  ahora:Show()
  local a = (GL.COLOR and GL.COLOR.acento) or { 1, 0.78, 0.25 }
  local h = Num(ahora.GetStringHeight and ahora:GetStringHeight()) or 16
  if h < 14 or h > 40 then h = 16 end
  ahora.fondo:ClearAllPoints()
  ahora.fondo:SetPoint("TOPLEFT", caja, "TOPLEFT", 3 + (r or 0), -22)
  ahora.fondo:SetPoint("TOPRIGHT", caja, "TOPRIGHT", -1, -22)
  ahora.fondo:SetHeight(h + 6)
  ahora.fondo:SetColorTexture(a[1], a[2], a[3], 0.10)
  ahora.fondo:Show()
  return math.floor(h + 8)
end

------------------------------------------------------------------------
-- 40. Cabecera en etiquetas: Niveles, Sección, ritmo y descansada, cada uno en su chip
------------------------------------------------------------------------
local chips = {}
local function Chip(i, padre)
  local c = chips[i]
  if not c then
    c = CreateFrame("Frame", nil, padre, BackdropTemplateMixin and "BackdropTemplate" or nil)
    c:SetHeight(15)
    c.t = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.t:SetPoint("LEFT", c, "LEFT", 5, 0)
    if c.t.SetWordWrap then c.t:SetWordWrap(false) end
    chips[i] = c
  end
  return c
end

function GL.PintarChips(ui, s, db, ritmo)
  for i = 1, #chips do chips[i]:Hide() end
  if not Si("chips") or type(ui) ~= "table" or type(s) ~= "table" then return false end
  local panel = ui.panelGuia
  local lista = {}
  local nv = UnitLevel and Num(UnitLevel("player"))
  local colNivel = { 1, 1, 1 }
  if nv and s.min and s.max then
    if nv < s.min then colNivel = { 1, 0.82, 0 }          -- aún te falta nivel
    elseif nv > s.max then colNivel = { 0.6, 0.62, 0.7 }  -- ya te queda baja
    else colNivel = { 0.25, 0.85, 0.35 } end              -- de tu nivel
  end
  table.insert(lista, { L"Niveles " .. tostring(s.min) .. "-" .. tostring(s.max), colNivel })
  local total = (GL.RUTA and GL.RUTA.secciones and #GL.RUTA.secciones) or 0
  table.insert(lista, { L"Sección " .. tostring(db.seccion) .. "/" .. total, { 0.8, 0.8, 0.86 } })
  if type(ritmo) == "string" then
    local a, b = string.match(ritmo, "^(.-)%s+·%s+(.+)$")
    table.insert(lista, { a or ritmo, { 0.25, 0.85, 0.35 } })
    if b then table.insert(lista, { b, { 1, 0.82, 0 } }) end
  end
  -- 9.0: la descansada ya sale en la barra de XP de arriba
  local disponible = (ui.niveles and Num(ui.niveles:GetWidth())) or 300
  if disponible < 60 then disponible = 300 end
  local x = 0
  for i, e in ipairs(lista) do
    local c = Chip(i, panel)
    c.t:SetText(e[1])
    local w = math.floor((Num(c.t:GetStringWidth()) or 50) + 10)
    if x + w > disponible then break end
    c:SetWidth(w)
    if GL.Caja then GL.Caja(c, { e[2][1], e[2][2], e[2][3], 0.10 }, { e[2][1], e[2][2], e[2][3], 0.45 }) end
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -20)
    c:Show()
    x = x + w + 4
  end
  if ui.niveles then ui.niveles:SetText("") end
  return true
end

------------------------------------------------------------------------
-- 36. Avisos plegables: una barra «AVISOS (n)» que se abre y se cierra con un clic
------------------------------------------------------------------------
local botonAvisos
function GL.CabeceraAvisos(cab, n)
  if botonAvisos then botonAvisos:Hide() end
  if true or not cab then return true end   -- 9.0: las píldoras sustituyen a la barra plegable (Mejoras.lua)
  local db = DB()
  local abiertos = db.avisosAbiertos == true
  if not botonAvisos then
    botonAvisos = CreateFrame("Button", nil, cab:GetParent())
    botonAvisos:SetHeight(16)
    botonAvisos.brillo = botonAvisos:CreateTexture(nil, "HIGHLIGHT")
    botonAvisos.brillo:SetAllPoints()
    botonAvisos.brillo:SetColorTexture(1, 1, 1, 0.06)
    botonAvisos.icono = botonAvisos:CreateTexture(nil, "ARTWORK")
    botonAvisos.icono:SetWidth(12); botonAvisos.icono:SetHeight(12)
    botonAvisos.icono:SetPoint("RIGHT", botonAvisos, "RIGHT", -2, 0)
    botonAvisos.texto = botonAvisos:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    botonAvisos.texto:SetPoint("RIGHT", botonAvisos.icono, "LEFT", -4, 0)
    botonAvisos:SetScript("OnClick", function()
      local d = DB()
      d.avisosAbiertos = not (d.avisosAbiertos == true)
      if GL.Refrescar then GL.Refrescar() end
    end)
  end
  local filas = Num(GL._numAvisosFilas) or 0
  local total = (n or 0) + math.max(0, filas - 1)
  local urg = Num(GL._avisosUrgentes) or 0
  cab:SetText(C.GRIS .. L"AVISOS (" .. total .. ")" .. C.FIN ..
    (urg > 0 and ("  |cffff5a5a" .. urg .. (urg == 1 and L" urgente" or L" urgentes") .. "|r") or ""))
  botonAvisos:ClearAllPoints()
  botonAvisos:SetPoint("TOPLEFT", cab, "TOPLEFT", -2, 2)
  botonAvisos:SetPoint("RIGHT", cab:GetParent(), "RIGHT", 0, 0)
  botonAvisos.texto:SetText(C.AMARILLO .. (abiertos and L"ocultar" or L"ver") .. C.FIN)
  botonAvisos.icono:SetTexture(abiertos and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
  botonAvisos:Show()
  return abiertos
end

------------------------------------------------------------------------
-- 41. Palabras clave del paso: PNJ en verde, lugares en azul y acciones en dorado
------------------------------------------------------------------------
local VERBOS = { "habla", "recoge", "entrega", "acepta", "coge", "mata", "matar", "cruza", "sigue", "activa", "vuela",
  "compra", "vende", "aprende", "entra", "sube", "baja", "busca", "usa", "lee", "abre", "lleva", "toma",
  "entrena", "equipa", "pon", "haz", "viaja", "vuelve", "regresa", "ve", "vete", "despega", "camina", "corre",
  "rodea", "salta", "espera", "consigue", L"reúne", "recolecta", "despeja", "limpia", "explora",
  "descubre", "investiga", "examina", "elimina", "derrota", "acaba", "completa", "termina", "deja", "guarda",
  "repara", L"vacía", "fija", "coloca", "ignora" }
-- 9.3.5: los mismos verbos para la guía en inglés
local VERBOS_EN = { "talk", "accept", "turn in", "kill", "take", "pick up", "gather", "collect", "cross", "follow",
  "activate", "fly", "buy", "sell", "learn", "enter", "go", "climb", "look for", "find", "use", "read", "open",
  "bring", "train", "equip", "set", "travel", "return", "walk", "run", "jump", "wait", "get", "explore", "examine",
  "defeat", "complete", "leave", "keep", "repair", "put", "heal", "tame", "escort", "fill", "drink", "skin", "mine" }
local lugares, lugaresRuta = nil, nil
local function Lugares()
  if lugaresRuta == GL.RUTA and lugares then return lugares end
  local vistos, l = {}, {}
  for _, s in ipairs((GL.RUTA and GL.RUTA.secciones) or {}) do
    if type(s.titulo) == "string" and not vistos[s.titulo] then vistos[s.titulo] = true; table.insert(l, s.titulo) end
    for _, p in ipairs(s.pasos or {}) do
      for _, d in ipairs(p.wp or {}) do
        if type(d.z) == "string" and string.len(d.z) > 3 and not vistos[d.z] then vistos[d.z] = true; table.insert(l, d.z) end
      end
    end
  end
  lugares, lugaresRuta = l, GL.RUTA
  return l
end

local function EsLetra(c)
  if not c or c == "" then return false end
  local b = string.byte(c)
  return (b >= 128) or string.find(c, "%w") ~= nil
end

-- Aplica fn solo a los trozos que no tienen ya color (lo que va entre |c........ y |r se deja igual).
local function FueraDeColor(texto, fn)
  local out, i, n = {}, 1, string.len(texto)
  while i <= n do
    local a = string.find(texto, "|c%x%x%x%x%x%x%x%x", i)
    if not a then table.insert(out, fn(string.sub(texto, i))); break end
    if a > i then table.insert(out, fn(string.sub(texto, i, a - 1))) end
    local b = string.find(texto, "|r", a, true)
    if not b then table.insert(out, string.sub(texto, a)); break end
    table.insert(out, string.sub(texto, a, b + 1))
    i = b + 2
  end
  return table.concat(out)
end

-- Pinta cada aparición de la frase (como palabra entera) con el color dado.
local function Pintar(trozo, frase, color)
  local out, i = {}, 1
  while true do
    local a, b = string.find(trozo, frase, i, true)
    if not a then break end
    local antes, despues = string.sub(trozo, a - 1, a - 1), string.sub(trozo, b + 1, b + 1)
    if (a == 1 or not EsLetra(antes)) and not EsLetra(despues) then
      table.insert(out, string.sub(trozo, i, a - 1))
      table.insert(out, color .. frase .. "|r")
    else
      table.insert(out, string.sub(trozo, i, b))
    end
    i = b + 1
  end
  table.insert(out, string.sub(trozo, i))
  return table.concat(out)
end

local function Mayuscula(v) return string.upper(string.sub(v, 1, 1)) .. string.sub(v, 2) end

local cacheResaltado = {}
function GL.Resaltar(texto, p)
  if not Si("resaltarPaso") or type(texto) ~= "string" then return texto end
  local clave = texto
  if cacheResaltado[clave] then return cacheResaltado[clave] end
  local frases = {}
  -- PNJ: el nombre entre paréntesis de los destinos del paso («Recoger: X (Sten Brazofuerte)») y los destinos sin «:»
  for _, d in ipairs((type(p) == "table" and p.wp) or {}) do
    local n = tostring(d.n or "")
    local quien = string.match(n, "%(([^()]+)%)%s*$")
    if quien and string.len(quien) > 3 then table.insert(frases, { quien, VERDE_NPC }) end
    if not string.find(n, ":") and string.len(n) > 3 and string.find(n, "^%u") and not string.find(n, "^Vuelo") then
      table.insert(frases, { n, VERDE_NPC })
    end
  end
  for _, l in ipairs(Lugares()) do table.insert(frases, { l, AZUL_LUGAR }) end
  table.sort(frases, function(a, b) return string.len(a[1]) > string.len(b[1]) end)   -- primero las más largas
  local r = texto
  for _, f in ipairs(frases) do
    r = FueraDeColor(r, function(t) return Pintar(t, f[1], f[2]) end)
  end
  for _, v in ipairs(GL.ingles and VERBOS_EN or VERBOS) do
    r = FueraDeColor(r, function(t) return Pintar(Pintar(t, v, DORADO_ACCION), Mayuscula(v), DORADO_ACCION) end)
  end
  cacheResaltado[clave] = r
  return r
end

------------------------------------------------------------------------
-- 42 y 43. Objetivos con casilla y distancia con color en las filas de Siguiente
------------------------------------------------------------------------
local CASILLA = "Interface\\Buttons\\UI-CheckBox-Up"
local MARCA = "Interface\\Buttons\\UI-CheckBox-Check"

local function PrepararFila(f)
  if Campo(f, "casilla") then return end
  f.casilla = f:CreateTexture(nil, "ARTWORK")
  f.casilla:SetWidth(16); f.casilla:SetHeight(16)
  f.casilla:SetPoint("LEFT", f, "LEFT", 2, 0)
  f.casilla:SetTexture(CASILLA)
  f.marca = f:CreateTexture(nil, "OVERLAY")
  f.marca:SetAllPoints(f.casilla)
  f.marca:SetTexture(MARCA)
  f.dist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.dist:SetJustifyH("RIGHT")
  f.dist:SetWidth(54)
  if Campo(f, "coords") then f.dist:SetPoint("RIGHT", f.coords, "LEFT", -4, 0) end
end

local function AjustarFila(f)
  local e, g = Campo(f, "entrada"), Campo(f, "grupo")
  if not e or not f:IsShown() then return end
  PrepararFila(f)
  local casillas = Si("casillas") and (g == 1 or g == 3)
  if casillas then
    f.casilla:Show()
    if e.hecho then f.marca:Show() else f.marca:Hide() end
    f.icono:ClearAllPoints(); f.icono:SetPoint("LEFT", f, "LEFT", 21, 0)
    if e.hecho and e.d and e.d.a and GL.ICONO_ACCION and GL.ICONO_ACCION[e.d.a] and GL.PonerIcono then
      GL.PonerIcono(f.icono, GL.ICONO_ACCION[e.d.a], false)   -- la casilla ya dice «hecho»: el icono vuelve a decir qué era
    end
    if f.icono.SetDesaturated then f.icono:SetDesaturated(e.hecho and true or false) end
  else
    f.casilla:Hide(); f.marca:Hide()
    f.icono:ClearAllPoints(); f.icono:SetPoint("LEFT", f, "LEFT", 6, 0)
    if f.icono.SetDesaturated then f.icono:SetDesaturated(false) end
  end
  local conDist = Si("distanciaColor") and g ~= 3 and not e.hecho
  local yd = conDist and Yardas(e.d) or nil
  if yd then
    f.dist:SetText(TextoMetros(yd)); f.dist:SetWidth(54); f.dist:Show()
    f.progreso:ClearAllPoints(); f.progreso:SetPoint("RIGHT", f.dist, "LEFT", -6, 0)
    if g == 2 then f.progreso:SetText("") end   -- la distancia ya sale en su columna
  else
    f.dist:SetText(""); f.dist:Hide()
    f.progreso:ClearAllPoints(); f.progreso:SetPoint("RIGHT", f.coords, "LEFT", -8, 0)
  end
end

local function AjustarFilas()
  local ui = GL.ui
  if type(ui) ~= "table" or type(ui.destinos) ~= "table" then return end
  for i = 1, #ui.destinos do Probar(AjustarFila, L"fila de objetivo", ui.destinos[i]) end
end

-- La distancia y la línea «Ahora» se actualizan solas cada medio segundo mientras andas.
local function AlPaso()
  local ui = GL.ui
  if type(ui) ~= "table" or not ui.panelGuia or not ui.panelGuia:IsVisible() then return end
  if ahora and ahora:IsShown() and ahora.d then ahora:SetText(TextoAhora(ahora.d)) end
  if Si("distanciaColor") then
    for i = 1, #(ui.destinos or {}) do
      local f = ui.destinos[i]
      local e = Campo(f, "entrada")
      local dist = Campo(f, "dist")
      if dist and e and f:IsShown() and dist:IsShown() then
        local yd = Yardas(e.d)
        dist:SetText(TextoMetros(yd))
      end
    end
  end
end

------------------------------------------------------------------------
-- 44. Modo lectura: solo el paso, con letra más grande
------------------------------------------------------------------------
function GL.ModoLectura() return DB().lectura == true end
local botonLectura
local function CrearBotonLectura()
  local ui = GL.ui
  if botonLectura or type(ui) ~= "table" or not ui.caja or not GL.CrearBoton then return end
  botonLectura = GL.CrearBoton(ui.caja, L"Leer", function()
    local db = DB()
    db.lectura = not (db.lectura == true)
    if GL.AplicarTamTexto then GL.AplicarTamTexto() elseif GL.Refrescar then GL.Refrescar() end
  end, nil, 16)
  botonLectura:SetWidth(40)
  if ui.notaBoton then botonLectura:SetPoint("RIGHT", ui.notaBoton, "LEFT", -4, 0) end
  if GL.Ayuda then
    GL.Ayuda(botonLectura, L"Modo lectura", L"Solo el paso, con la letra más grande. Ideal para pantallas pequeñas. Otro clic lo quita.")
  end
end
local function RefrescarBotonLectura()
  if botonLectura and botonLectura.SetActivo then botonLectura:SetActivo(GL.ModoLectura()) end
end

------------------------------------------------------------------------
-- Opciones (Ajustes > Paso) e inicio
------------------------------------------------------------------------
local function Repintar() if GL.Refrescar then GL.Refrescar() end end
GL.casillasClaridad = {
  { "lineaAhora", L"Línea «Ahora» encima del paso", L"Lo primero que ves es qué hacer y a cuántos metros: «Ahora: Recoge ... con ... · 210 m».",
    function() return Si("lineaAhora") end, function(v) DB().lineaAhora = v; Repintar() end },
  { "chips", L"Cabecera en etiquetas", L"Niveles, sección, ritmo y descansada en etiquetas separadas. El nivel sale en verde si la sección es de tu nivel.",
    function() return Si("chips") end, function(v) DB().chips = v; Repintar() end },
  { "avisosPlegables", L"Avisos plegables", L"Los avisos se juntan en una barra «AVISOS (n)» que se abre con un clic. Los urgentes se cuentan en rojo.",
    function() return Si("avisosPlegables") end, function(v) DB().avisosPlegables = v; Repintar() end },
  { "resaltarPaso", L"Palabras clave en el paso", L"PNJ en verde, lugares en azul y acciones (cruza, activa, habla...) en dorado.",
    function() return Si("resaltarPaso") end, function(v) DB().resaltarPaso = v; Repintar() end },
  { "casillas", L"Objetivos con casilla", L"Cada objetivo del paso con su casilla: vacía si falta, marcada si está hecho.",
    function() return Si("casillas") end, function(v) DB().casillas = v; Repintar() end },
  { "distanciaColor", L"Distancia con color", L"En Siguiente, los metros hasta cada objetivo: verde cerca, amarillo a media distancia, blanco lejos.",
    function() return Si("distanciaColor") end, function(v) DB().distanciaColor = v; Repintar() end },
}

table.insert(GL.alIniciar, function()
  Probar(CrearBotonLectura, L"botón de lectura")
  local ev = CreateFrame("Frame")
  local acum = 0
  ev:SetScript("OnUpdate", function(_, dt)
    acum = acum + (dt or 0)
    if acum < 0.5 then return end
    acum = 0
    Probar(AlPaso, "distancias")
  end)
end)

table.insert(GL.trasRefrescar, function()
  Probar(CrearBotonLectura, L"botón de lectura")
  Probar(RefrescarBotonLectura, L"botón de lectura")
  Probar(AjustarFilas, L"filas de objetivos")
end)

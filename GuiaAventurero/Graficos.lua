-- Graficos.lua (8.8): mejoras solo de aspecto. Creado por JKRiveroF.
-- Barra por pasos, objetivos con barrita, iconos por tipo de destino, escudo de la facción, transición entre pasos,
-- anillo de cercanía y estilos de la flecha, ventana que se atenúa, marco clásico, tarjeta de sección acabada
-- y fuente del paso. Nada de esto cambia la ruta, las misiones ni los automatismos: todo se apaga en Ajustes.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"

local function DB() return GuiaAventureroDB or {} end
-- con /ga depurar, los fallos salen en el chat en vez de callarse
local function Probar(fn, nombre, ...)
  local ok, err = pcall(fn, ...)
  if not ok and GL.Fallo(nombre, err) and GL.Mensaje then GL.Mensaje(L"error en " .. nombre .. ": " .. tostring(err)) end
end
local function Si(k) return DB()[k] ~= false end   -- encendido salvo que se apague
local function Ahora() return (GetTime and GetTime()) or 0 end

------------------------------------------------------------------------
-- 2. Barra por pasos: un tramo por paso de la sección, debajo de la barra de ruta
------------------------------------------------------------------------
local MAX_SEG = 60
local seg = { tex = {} }

local function CrearSegmentos()
  local ui = GL.ui
  if seg.marco or not ui or not ui.progreso then return end
  local m = CreateFrame("Frame", nil, ui.progreso:GetParent())
  m:SetPoint("TOPLEFT", ui.progreso, "BOTTOMLEFT", 0, -1)
  m:SetPoint("TOPRIGHT", ui.progreso, "BOTTOMRIGHT", 0, -1)
  m:SetHeight(3)
  m:EnableMouse(true)
  GL.Ayuda(m, L"Pasos de la sección")
  for i = 1, MAX_SEG do
    local t = m:CreateTexture(nil, "ARTWORK")
    t:SetHeight(3)
    t:Hide()
    seg.tex[i] = t
  end
  seg.marco = m
end

local function RefrescarSegmentos()
  local m = seg.marco
  if not m then return end
  if not Si("segmentos") then m:Hide(); return end
  local db = DB()
  local okP, s = pcall(GL.PasoActual)
  if not okP or not s or not s.pasos then m:Hide(); return end
  local ancho = m:GetWidth() or 0
  local n = math.min(#s.pasos, MAX_SEG)
  if ancho <= 0 or n == 0 then m:Hide(); return end
  m:Show()
  local hueco = (ancho / n >= 6) and 1 or 0
  local w = (ancho - hueco * (n - 1)) / n
  local a, hechos = GL.COLOR.acento, 0
  for i = 1, MAX_SEG do
    local t = seg.tex[i]
    if i <= n then
      local okE, est = pcall(GL.EstadoPaso, s.pasos[i])
      est = okE and est or nil
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", m, "TOPLEFT", (i - 1) * (w + hueco), 0)
      t:SetWidth(math.max(1, w))
      if i == db.paso then
        t:SetColorTexture(a[1], a[2], a[3], 1)
      elseif est == "hecho" or (i < db.paso and est ~= "pendiente") then
        t:SetColorTexture(0.30, 0.72, 0.92, 0.95)
        hechos = hechos + 1
      elseif i < db.paso then
        t:SetColorTexture(a[1], a[2], a[3], 0.35)   -- saltado sin hacer
      else
        t:SetColorTexture(1, 1, 1, 0.10)
      end
      t:Show()
    else
      t:Hide()
    end
  end
  m.ayudaTexto = L"Paso " .. (db.paso or 1) .. L" de " .. #s.pasos .. L". Hechos: " .. hechos .. ".\n" ..
    C.GRIS .. L"Azul: hecho. Color del tema: el actual. Tenue: saltado sin hacer." .. C.FIN
end

------------------------------------------------------------------------
-- 3 y 4. Objetivos con barrita e iconos por tipo de destino
------------------------------------------------------------------------
local ICONOS_TIPO = {
  vuelo = { "Interface\\TaxiFrame\\UI-Taxi-Icon-Green", false },
  posada = { "Interface\\Icons\\INV_Misc_Rune_01", true },
  instructor = { "Interface\\Icons\\INV_Misc_Book_11", true },
  vendedor = { "Interface\\Icons\\INV_Misc_Coin_01", true },
}
local CLAVES_TIPO = {
  { "vuelo", { "vuelo", "vuela", "grifo", "hipogrifo", L"murciélago", L"jinete del viento", L"dracoleón", "nave" } },
  { "posada", { "hogar", "posada", "tabernero", "tabernera" } },
  { "instructor", { "entrena", "instructor", "instructora", "aprende" } },
  { "vendedor", { "compra", "vende", "repara" } },
}
local tipos, rutaTipos = {}, nil

-- Busca la palabra clave más cercana antes del nombre en el texto del paso.
local function TipoEnTexto(texto, nombre)
  local bajo = string.lower(texto)
  local pos = string.find(bajo, string.lower(nombre), 1, true)
  if not pos then return nil end
  local antes = string.sub(bajo, math.max(1, pos - 70), pos - 1)
  local mejor, mejorPos = nil, 0
  for _, par in ipairs(CLAVES_TIPO) do
    for _, palabra in ipairs(par[2]) do
      local ini = 1
      while true do
        local a = string.find(antes, palabra, ini, true)
        if not a then break end
        if a > mejorPos then mejor, mejorPos = par[1], a end
        ini = a + 1
      end
    end
  end
  return mejor
end

local function IndexarTipos()
  local R = GL.RUTA
  if not R or rutaTipos == R then return end
  rutaTipos, tipos = R, {}
  for _, s in ipairs(R.secciones or {}) do
    for _, p in ipairs(s.pasos or {}) do
      for _, d in ipairs(p.wp or {}) do
        if not d.q and d.n then
          local clave = d.npc or d.n
          if not tipos[clave] then
            local t = (string.find(d.n, L"^Tabern") and "posada") or (p.t and TipoEnTexto(p.t, d.n))
            if t then tipos[clave] = t end
          end
        end
      end
    end
  end
end

local function TipoDestino(d)
  if d.q or not d.n then return nil end
  IndexarTipos()
  return tipos[d.npc or d.n]
end
GL.TipoDestino = TipoDestino

local vistos = {}   -- clave del destino -> estaba hecho en el refresco anterior

local function PrepararFila(f)
  if rawget(f, "gBarra") then return end
  f.gFondo = f:CreateTexture(nil, "BORDER")
  f.gFondo:SetHeight(2)
  f.gFondo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 1)
  f.gFondo:SetPoint("BOTTOMRIGHT", f.coords, "BOTTOMLEFT", -8, 1)
  f.gFondo:SetColorTexture(1, 1, 1, 0.08)
  f.gBarra = f:CreateTexture(nil, "ARTWORK")
  f.gBarra:SetHeight(2)
  f.gBarra:SetPoint("BOTTOMLEFT", f.gFondo, "BOTTOMLEFT", 0, 0)
  f.gBrillo = f:CreateTexture(nil, "OVERLAY")
  f.gBrillo:SetAllPoints()
  f.gBrillo:SetColorTexture(0.25, 0.85, 0.35, 0.30)
  f.gBrillo:SetAlpha(0)
  if f.gBrillo.CreateAnimationGroup then
    local ag = f.gBrillo:CreateAnimationGroup()
    local e = ag:CreateAnimation("Alpha"); e:SetFromAlpha(0); e:SetToAlpha(1); e:SetDuration(0.15); e:SetOrder(1)
    local s = ag:CreateAnimation("Alpha"); s:SetFromAlpha(1); s:SetToAlpha(0); s:SetDuration(0.9); s:SetOrder(2)
    ag:SetScript("OnFinished", function() f.gBrillo:SetAlpha(0) end)
    f.gBrillo.anim = ag
  end
end

local function SinColores(t)
  t = string.gsub(t or "", "|c%x%x%x%x%x%x%x%x", "")
  return (string.gsub(t, "|r", ""))
end

local function RefrescarFilas()
  local ui = GL.ui
  if not ui or not ui.destinos then return end
  for _, f in ipairs(ui.destinos) do
    local e = rawget(f, "entrada")
    if f:IsShown() and e and e.d and f.coords then
      PrepararFila(f)
      local d = e.d
      -- 3: barrita de progreso (6/10) debajo del nombre
      local a, b = string.match(SinColores(f.progreso:GetText()), "(%d+)%s*/%s*(%d+)")
      a, b = tonumber(a), tonumber(b)
      if Si("barritas") and f.grupo ~= 2 and ((a and b and b > 0) or e.hecho) and d.q then
        local frac = e.hecho and 1 or math.min(1, a / b)
        local ancho = f.gFondo:GetWidth() or 0
        f.gFondo:Show()
        if frac > 0 and ancho > 0 then
          f.gBarra:SetWidth(math.max(1, ancho * frac))
          if frac >= 1 then f.gBarra:SetColorTexture(0.25, 0.85, 0.35, 1)
          else local ac = GL.COLOR.acento; f.gBarra:SetColorTexture(ac[1], ac[2], ac[3], 1) end
          f.gBarra:Show()
        else
          f.gBarra:Hide()
        end
      else
        f.gFondo:Hide(); f.gBarra:Hide()
      end
      -- brillo verde cuando un objetivo pasa a hecho mientras lo miras
      local clave = GL.ClaveDestino and GL.ClaveDestino(d) or d.n
      if e.hecho and vistos[clave] == false and Si("barritas") and f.gBrillo.anim then
        f.gBrillo.anim:Stop(); f.gBrillo.anim:Play()
      end
      vistos[clave] = e.hecho and true or false
      -- 4: icono según lo que haces allí (vuelo, posada, instructor, vendedor)
      if Si("iconosTipo") and not e.hecho and not d.a then
        local t = TipoDestino(d)
        if t and ICONOS_TIPO[t] then GL.PonerIcono(f.icono, ICONOS_TIPO[t][1], ICONOS_TIPO[t][2]) end
      end
    elseif rawget(f, "gBarra") then
      f.gFondo:Hide(); f.gBarra:Hide()
    end
  end
end

------------------------------------------------------------------------
-- 5. Escudo de la facción, muy tenue, en el fondo de la ventana
------------------------------------------------------------------------
local escudo
local function RefrescarEscudo()
  local f = GL.frame
  if not f then return end
  if not escudo then
    escudo = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    escudo:SetWidth(190); escudo:SetHeight(190)
    escudo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 30)
    local faccion = UnitFactionGroup and UnitFactionGroup("player")
    if faccion ~= "Alliance" and faccion ~= "Horde" then escudo.ninguna = true; escudo:Hide(); return end
    escudo:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faccion)
    escudo:SetTexCoord(0, 0.66, 0, 0.66)
    if escudo.SetDesaturated then escudo:SetDesaturated(true) end
    escudo:SetAlpha(0.06)
  end
  if escudo.ninguna then return end
  GL.Mostrar(escudo, Si("escudo"))
end

------------------------------------------------------------------------
-- 6. Transición: la caja del paso nuevo entra deslizándose desde la derecha
------------------------------------------------------------------------
function GL.AlCambiarPaso(caja)
  if not Si("transicion") or not caja or not caja.CreateAnimationGroup then return end
  if not rawget(caja, "gTransicion") then
    local ag = caja:CreateAnimationGroup()
    local m0 = ag:CreateAnimation("Translation"); m0:SetOffset(28, 0); m0:SetDuration(0.01); m0:SetOrder(1)
    local f0 = ag:CreateAnimation("Alpha"); f0:SetFromAlpha(0); f0:SetToAlpha(0); f0:SetDuration(0.01); f0:SetOrder(1)
    local m1 = ag:CreateAnimation("Translation"); m1:SetOffset(-28, 0); m1:SetDuration(0.28); m1:SetOrder(2)
    if m1.SetSmoothing then m1:SetSmoothing("OUT") end
    local f1 = ag:CreateAnimation("Alpha"); f1:SetFromAlpha(0); f1:SetToAlpha(1); f1:SetDuration(0.28); f1:SetOrder(2)
    caja.gTransicion = ag
  end
  caja.gTransicion:Stop()
  caja.gTransicion:Play()
end

------------------------------------------------------------------------
-- 7 y 8. Flecha: anillo de cercanía y estilos (clásica, brújula, mínima)
------------------------------------------------------------------------
local PUNTOS = 28
local RADIO = 32
local anillo
local LETRAS = { "N", "E", "S", "O" }

local function CrearAnillo(fl)
  anillo = CreateFrame("Frame", nil, fl)
  anillo:SetWidth(RADIO * 2 + 6); anillo:SetHeight(RADIO * 2 + 6)
  anillo:SetPoint("CENTER", fl.tex, "CENTER", 0, 0)
  anillo.puntos = {}
  for i = 1, PUNTOS do
    local t = anillo:CreateTexture(nil, "ARTWORK")
    t:SetTexture(BLANCO8)
    t:SetWidth(3); t:SetHeight(3)
    local ang = (i - 1) / PUNTOS * 2 * math.pi
    t:SetPoint("CENTER", anillo, "CENTER", RADIO * math.sin(ang), RADIO * math.cos(ang))
    anillo.puntos[i] = t
  end
  anillo.letras = {}
  for i = 1, 4 do
    local l = anillo:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l:SetText(i == 4 and GL.ingles and "W" or LETRAS[i])
    l:SetShadowOffset(1, -1)
    anillo.letras[i] = l
  end
  if anillo.CreateAnimationGroup then
    local ag = anillo:CreateAnimationGroup()
    local s1 = ag:CreateAnimation("Scale"); s1:SetDuration(0.18); s1:SetOrder(1)
    local s2 = ag:CreateAnimation("Scale"); s2:SetDuration(0.30); s2:SetOrder(2)
    if s1.SetScaleFrom then
      s1:SetScaleFrom(1, 1); s1:SetScaleTo(1.25, 1.25); s2:SetScaleFrom(1.25, 1.25); s2:SetScaleTo(1, 1)
    else
      s1:SetScale(1.25, 1.25); s2:SetScale(0.8, 0.8)
    end
    anillo.pulso = ag
  end
end

local function PintarAnillo(frac, r, g, b)
  local encendidos = math.floor(frac * PUNTOS + 0.5)
  -- R12: la distancia se actualiza igual; solo cambian los puntos cuyo color cambia.
  local previo = anillo.encendidos
  local mismoColor = anillo.r == r and anillo.g == g and anillo.b == b
  if previo == encendidos and mismoColor then return end
  for i = 1, PUNTOS do
    local activo = i <= encendidos
    if previo == nil or activo ~= (i <= previo) or (activo and not mismoColor) then
      if activo then anillo.puntos[i]:SetVertexColor(r, g, b, 1)
      else anillo.puntos[i]:SetVertexColor(1, 1, 1, 0.14) end
    end
  end
  anillo.encendidos, anillo.r, anillo.g, anillo.b = encendidos, r, g, b
end

local function EstiloFlecha()
  local e = DB().estiloFlecha
  if e == "brujula" or e == "minima" then return e end
  return "clasica"
end

local estiloPuesto
local function PonerEstilo(fl, estilo)
  if estiloPuesto == estilo then return end
  estiloPuesto = estilo
  local lado = (estilo == "brujula") and 40 or 56
  fl.tex:SetWidth(lado); fl.tex:SetHeight(lado)
  fl.tex:ClearAllPoints()
  fl.tex:SetPoint("TOP", fl, "TOP", 0, (estilo == "brujula") and -18 or -10)
  if estilo ~= "minima" then
    GL.Caja(fl, GL.COLOR.flechaFondo, GL.COLOR.flechaBorde)
    fl.texto:Show()
  end
  for i = 1, 4 do GL.Mostrar(anillo.letras[i], estilo == "brujula") end
end

function GL.TrasFlecha(fl)
  if not fl or not fl.tex then return end
  if not anillo then CrearAnillo(fl) end
  local estilo = EstiloFlecha()
  PonerEstilo(fl, estilo)
  if GL.TrasFlechaExtra then Probar(GL.TrasFlechaExtra, "flecha", fl) end
  if GL.TrasFlechaBrillo then Probar(GL.TrasFlechaBrillo, L"brillo de la flecha", fl) end   -- 8.9.1   -- 8.9: crece al llegar y aviso de cueva o altura
  if estilo == "minima" then
    -- solo la flecha y los metros, sin marco ni nombre
    if fl.SetBackdropColor then fl:SetBackdropColor(0, 0, 0, 0); fl:SetBackdropBorderColor(0, 0, 0, 0) end
    if rawget(fl, "fondoCaja") then fl.fondoCaja:SetAlpha(0) end
    -- Sin destino navegable, el aviso es la única información útil de la flecha.
    local estado = rawget(fl, "estado")
    GL.Mostrar(fl.texto, not fl.tex:IsShown() and (not estado or not estado.llegado))
  elseif rawget(fl, "fondoCaja") then
    fl.fondoCaja:SetAlpha(1)
  end
  local e = rawget(fl, "estado")
  local verAnillo = e and (fl.tex:IsShown() or e.llegado) and (Si("anillo") or estilo == "brujula")
  if not verAnillo then anillo:Hide(); return end
  anillo:Show()
  -- cuánto has recorrido desde que este destino pasó a ser el de la flecha
  local clave = (GL.ClaveDestino and GL.ClaveDestino(e.d)) or e.d.n
  if anillo.clave ~= clave then anillo.clave, anillo.d0, anillo.llego = clave, e.dist, false end
  if e.dist > (anillo.d0 or 0) then anillo.d0 = e.dist end
  local frac = e.llegado and 1 or (1 - e.dist / math.max(anillo.d0 or 1, 1))
  if frac < 0 then frac = 0 end
  local r, g, b = e.r or 0.25, e.g or 0.85, e.b or 0.35
  if e.llegado then r, g, b = 0.25, 0.85, 0.35 end
  if not Si("anillo") then frac = 0 end   -- brújula sin anillo: solo el aro y las letras
  PintarAnillo(frac, r, g, b)
  if e.llegado and not anillo.llego then
    anillo.llego = true
    if anillo.pulso then anillo.pulso:Stop(); anillo.pulso:Play() end
  end
  -- brújula: las letras giran con hacia dónde miras (el norte está en orient, en sentido horario desde arriba)
  if estilo == "brujula" then
    local norte = e.orient or 0
    for i = 1, 4 do
      local ang = norte + (i - 1) * math.pi / 2
      local l = anillo.letras[i]
      l:ClearAllPoints()
      l:SetPoint("CENTER", anillo, "CENTER", (RADIO - 9) * math.sin(ang), (RADIO - 9) * math.cos(ang))
      l:SetTextColor(i == 1 and 1 or 0.75, i == 1 and 0.35 or 0.75, i == 1 and 0.30 or 0.78)
    end
  end
end

------------------------------------------------------------------------
-- 10. Atenuar la ventana en combate o cuando no tienes el ratón encima
------------------------------------------------------------------------
local ESPERA = 4      -- segundos sin el ratón antes de atenuar
local TENUE = 0.30
local ultimoRaton, alfa = 0, 1
local function Atenuar()
  local f = GL.frame
  if not f then return end
  if DB().atenuar ~= true then
    if alfa ~= 1 then alfa = 1; f:SetAlpha(1) end
    return
  end
  local encima = f:IsShown() and f.IsMouseOver and f:IsMouseOver()
  if encima then ultimoRaton = Ahora() end
  local combate = UnitAffectingCombat and UnitAffectingCombat("player")
  local objetivo = 1
  if not encima and (combate or Ahora() - ultimoRaton > ESPERA) then objetivo = TENUE end
  if math.abs(alfa - objetivo) < 0.02 then alfa = objetivo else alfa = alfa + (objetivo - alfa) * 0.35 end
  f:SetAlpha(alfa)
end

------------------------------------------------------------------------
-- 11. Marco clásico: el borde del juego alrededor de la ventana y de la flecha
------------------------------------------------------------------------
local BORDE_CLASICO = "Interface\\DialogFrame\\UI-DialogBox-Border"
local function MarcoSobre(f, fuera, lado)
  local m = CreateFrame("Frame", nil, f, PLANTILLA)
  m:SetPoint("TOPLEFT", f, "TOPLEFT", -fuera, fuera)
  m:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", fuera, -fuera)
  m:SetFrameLevel((f:GetFrameLevel() or 1) + 40)
  if m.SetBackdrop then
    m:SetBackdrop({ edgeFile = BORDE_CLASICO, edgeSize = lado })
    m:SetBackdropBorderColor(1, 0.92, 0.75, 1)
  end
  m:Hide()
  return m
end

local marcos = {}
local function RefrescarMarco()
  local clasico = DB().marco == "clasico"
  if GL.frame and not marcos.ventana then marcos.ventana = MarcoSobre(GL.frame, 6, 24) end
  if GL.flecha and not marcos.flecha then marcos.flecha = MarcoSobre(GL.flecha, 4, 16) end
  if marcos.ventana then GL.Mostrar(marcos.ventana, clasico) end
  if marcos.flecha then GL.Mostrar(marcos.flecha, clasico and EstiloFlecha() ~= "minima") end
end

------------------------------------------------------------------------
-- 12. Tarjeta de sección acabada (tipo logro), con el tiempo y las misiones de la sección
------------------------------------------------------------------------
local tarjeta
local function Duracion(seg)
  seg = math.floor(seg or 0)
  local h, m = math.floor(seg / 3600), math.floor((seg % 3600) / 60)
  if h > 0 then return h .. " h " .. m .. L" min" end
  return math.max(m, 1) .. L" min"
end

-- Tiempo y misiones de cada sección (de este personaje, solo con el juego abierto)
local function Contador()
  local db = GuiaAventureroDB
  if type(db) ~= "table" or not db.seccion then return nil end
  if type(db.gSec) ~= "table" then db.gSec = { s = db.seccion, t = 0, q = 0 } end
  if db.gSec.s ~= db.seccion then
    db.gSecAnt = db.gSec
    db.gSec = { s = db.seccion, t = 0, q = 0 }
  end
  return db.gSec
end

local function CrearTarjeta()
  local f = CreateFrame("Button", "GuiaAventureroTarjetaSeccion", UIParent, PLANTILLA)
  f:SetWidth(380); f:SetHeight(66)
  f:SetPoint("TOP", UIParent, "TOP", 0, -110)
  f:SetFrameStrata("HIGH")
  GL.Caja(f, { 0.06, 0.05, 0.03, 0.96 }, GL.COLOR.acento)
  GL.Acento(f, 2)
  local brillo = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  brillo:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  brillo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  GL.PorTema(function() local a = GL.COLOR.acento; brillo:SetColorTexture(a[1], a[2], a[3], 0.10) end)
  f.icono = GL.CrearMarcoIcono(f, 44)
  f.icono:SetPoint("LEFT", f, "LEFT", 11, 0)
  GL.PorTema(function() GL.Caja(f.icono, GL.COLOR.icono, GL.COLOR.acento) end)
  f.linea1 = GL.Texto(f, "GameFontDisableSmall")
  f.linea1:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -10)
  f.linea2 = GL.Texto(f, "GameFontNormalLarge")
  f.linea2:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -24)
  f.linea2:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  GL.UnaLinea(f.linea2)
  f.linea3 = GL.Texto(f, "GameFontHighlightSmall")
  f.linea3:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -46)
  f.linea3:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  GL.UnaLinea(f.linea3)
  f:SetScript("OnClick", function(self) self:Hide() end)
  if f.CreateAnimationGroup then
    local entra = f:CreateAnimationGroup()
    local m0 = entra:CreateAnimation("Translation"); m0:SetOffset(0, 24); m0:SetDuration(0.01); m0:SetOrder(1)
    local a0 = entra:CreateAnimation("Alpha"); a0:SetFromAlpha(0); a0:SetToAlpha(0); a0:SetDuration(0.01); a0:SetOrder(1)
    local m1 = entra:CreateAnimation("Translation"); m1:SetOffset(0, -24); m1:SetDuration(0.35); m1:SetOrder(2)
    if m1.SetSmoothing then m1:SetSmoothing("OUT") end
    local a1 = entra:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.35); a1:SetOrder(2)
    f.entra = entra
    local sale = f:CreateAnimationGroup()
    local a2 = sale:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.8); a2:SetStartDelay(6)
    sale:SetScript("OnFinished", function() f:Hide() end)
    f.sale = sale
  end
  f:Hide()
  return f
end

-- Experiencia.lua la llama al pasar a la sección siguiente. Devuelve true si la ha mostrado.
function GL.TarjetaSeccion(ant, nueva)
  if not Si("tarjetaSeccion") or not GL.RUTA or not GL.RUTA.secciones then return false end
  local hecha, sig = GL.RUTA.secciones[ant], GL.RUTA.secciones[nueva]
  if not hecha then return false end
  if not tarjeta then tarjeta = CrearTarjeta() end
  Contador()
  local db = DB()
  local datos = (type(db.gSecAnt) == "table" and db.gSecAnt.s == ant) and db.gSecAnt or nil
  GL.PonerIcono(tarjeta.icono.icono, (GL.RUTA and GL.RUTA.icono) or GL.ICONO_LUGAR)
  tarjeta.linea1:SetText(L"SECCIÓN COMPLETADA  ·  " .. ant .. L" DE " .. GL.NumSecciones())
  tarjeta.linea2:SetText(hecha.titulo or "")
  local partes = {}
  if datos and (datos.t or 0) >= 60 then table.insert(partes, C.AMARILLO .. Duracion(datos.t) .. C.FIN) end
  if datos and (datos.q or 0) > 0 then table.insert(partes, C.AMARILLO .. datos.q .. C.FIN .. (datos.q == 1 and L" misión" or L" misiones")) end
  if sig then table.insert(partes, C.GRIS .. L"siguiente: " .. C.FIN .. sig.titulo) end
  tarjeta.linea3:SetText(table.concat(partes, C.GRIS .. "  ·  " .. C.FIN))
  tarjeta:SetAlpha(1)
  tarjeta:Show()
  if tarjeta.entra then
    tarjeta.sale:Stop(); tarjeta.entra:Stop(); tarjeta.entra:Play(); tarjeta.sale:Play()
  elseif C_Timer and C_Timer.After then
    C_Timer.After(7, function() tarjeta:Hide() end)
  end
  return true
end

------------------------------------------------------------------------
-- 13. Fuente del texto del paso
------------------------------------------------------------------------
local FUENTES = {
  { id = "juego", nombre = L"Juego" },
  { id = "friz", nombre = "Friz", f = "Fonts\\FRIZQT__.TTF" },
  { id = "arial", nombre = "Arial", f = "Fonts\\ARIALN.TTF" },
  { id = "morpheus", nombre = "Morpheus", f = "Fonts\\MORPHEUS.TTF" },
  { id = "skurri", nombre = "Skurri", f = "Fonts\\SKURRI.TTF" },
}
local original
local function AplicarFuente()
  local ui = GL.ui
  if not ui or not ui.pasoTexto then return end
  if not original then original = { ui.fuentePaso, ui.opcionesPaso } end
  local elegida = original[1]
  for _, f in ipairs(FUENTES) do
    if f.id == DB().fuentePaso and f.f then elegida = f.f end
  end
  local opciones = original[2]
  if DB().fuenteContorno == true then opciones = "OUTLINE" end
  -- Aplicar directamente al tamaño configurado y publicar solo la fuente aceptada.
  if GL.AplicarTamTexto and not GL.AplicarTamTexto(elegida, opciones) then
    if original[1] then GL.AplicarTamTexto(original[1], original[2]) end
  end
end

------------------------------------------------------------------------
-- Ajustes: casillas y selectores de Opciones > Ajustes (los pone Opciones.lua)
------------------------------------------------------------------------
local function Repintar()
  if GL.Refrescar then GL.Refrescar() end
  RefrescarEscudo(); RefrescarMarco()
end

function GL.OpcionesGraficos(h, CrearCasilla, CrearSelector)
  local lista = {}
  local cab = CreateFrame("Frame", nil, h)
  cab:SetHeight(20)
  cab.altoFila = 22
  cab.texto = GL.Texto(cab, "GameFontNormalSmall")
  cab.texto:SetPoint("BOTTOMLEFT", cab, "BOTTOMLEFT", 0, 4)
  cab.texto:SetText(L"Aspecto")
  cab.Actualizar = function() end
  cab:Hide(); cab.oculto = true   -- 8.9.5: Ajustes va por pestañas; la cabecera «Aspecto» sobra
  local function Clave(ctl, k) if type(ctl) == "table" then ctl.claveOpcion = k end; return ctl end
  table.insert(lista, Clave(CrearSelector(h, L"Estilo de la flecha", {
      { "clasica", L"Clásica" }, { "brujula", L"Brújula" }, { "minima", L"Mínima" } },
    function() return EstiloFlecha() end,
    function(v) DB().estiloFlecha = v; estiloPuesto = nil; RefrescarMarco() end), "estiloFlecha"))
  table.insert(lista, Clave(CrearSelector(h, L"Marco de las ventanas", { { "plano", L"Plano" }, { "clasico", L"Clásico" } },
    function() return DB().marco == "clasico" and "clasico" or "plano" end,
    function(v) DB().marco = v; RefrescarMarco() end), "marco"))
  local opcF = {}
  for _, f in ipairs(FUENTES) do table.insert(opcF, { f.id, f.nombre }) end
  table.insert(lista, Clave(CrearSelector(h, L"Fuente del texto del paso", opcF,
    function() return DB().fuentePaso or "juego" end,
    function(v) DB().fuentePaso = v; AplicarFuente() end), "fuentePaso"))
  local casillas = {
    { "fuenteContorno", L"Contorno en el texto del paso", L"Un borde fino alrededor de las letras: se lee mejor sobre fondos claros o con poca opacidad.",
      function() return DB().fuenteContorno == true end, function(v) DB().fuenteContorno = v; AplicarFuente() end },
    { "segmentos", L"Barra por pasos de la sección", L"Debajo de la barra de ruta, un tramo por paso: azul los hechos y del color del tema el actual.",
      function() return Si("segmentos") end, function(v) DB().segmentos = v; Repintar() end },
    { "barritas", L"Barrita de progreso en los objetivos", L"Cada objetivo con su barra (6/10). Se pone verde y brilla al completarlo.",
      function() return Si("barritas") end, function(v) DB().barritas = v; Repintar() end },
    { "iconosTipo", L"Iconos de vuelo, posada, instructor y vendedor", L"Los destinos sin misión llevan el icono de lo que haces allí.",
      function() return Si("iconosTipo") end, function(v) DB().iconosTipo = v; Repintar() end },
    { "escudo", L"Escudo de tu facción de fondo", L"El emblema de la Alianza o de la Horda, muy tenue, en el fondo de la ventana.",
      function() return Si("escudo") end, function(v) DB().escudo = v; Repintar() end },
    { "transicion", L"Transición al cambiar de paso", L"La caja del paso nuevo entra deslizándose desde la derecha.",
      function() return Si("transicion") end, function(v) DB().transicion = v end },
    { "anillo", L"Anillo de cercanía en la flecha", L"Un aro alrededor de la flecha que se llena según te acercas. Al llegar, da un pulso.",
      function() return Si("anillo") end, function(v) DB().anillo = v end },
    { "rutaMapa", L"Ruta en el mapa del mundo", L"Una línea de puntos une en orden los destinos que te quedan del paso.",
      function() return Si("rutaMapa") end, function(v) DB().rutaMapa = v; if GL.ActualizarPines then pcall(GL.ActualizarPines) end end },
    { "atenuar", L"Atenuar la ventana fuera de uso", L"En combate o tras unos segundos sin el ratón encima, la ventana se vuelve casi transparente. Vuelve al pasar el ratón.",
      function() return DB().atenuar == true end, function(v) DB().atenuar = v end },
    { "tarjetaSeccion", L"Tarjeta al acabar una sección", L"Arriba de la pantalla, tipo logro: la sección hecha, su tiempo, sus misiones y la siguiente. Se va sola.",
      function() return Si("tarjetaSeccion") end, function(v) DB().tarjetaSeccion = v end },
  }
  for _, grupo in ipairs({ casillas, GL.casillasClaridad or {}, GL.casillasDetalles or {}, GL.casillasAdornos or {} }) do   -- 8.8, 8.9.5, 8.9.1 y 8.9
    for _, c in ipairs(grupo) do table.insert(lista, Clave(CrearCasilla(h, c[2], c[3], c[4], c[5]), c[1])) end
  end
  return lista
end

GL.CLAVES_GRAFICOS = { "estiloFlecha", "marco", "fuentePaso", "fuenteContorno", "segmentos", "barritas", "iconosTipo", "escudo",
  "transicion", "anillo", "rutaMapa", "atenuar", "tarjetaSeccion" }
GL.AplicarGraficos = function() estiloPuesto = nil; RefrescarEscudo(); RefrescarMarco(); AplicarFuente(); Repintar(); if GL.AplicarAdornos then GL.AplicarAdornos() end; if GL.AplicarDetalles then GL.AplicarDetalles() end end

------------------------------------------------------------------------
-- Inicio y refresco
------------------------------------------------------------------------
table.insert(GL.alIniciar, function()
  CrearSegmentos()
  RefrescarEscudo()
  RefrescarMarco()
  AplicarFuente()
  Contador()
  local reloj = CreateFrame("Frame")
  local acum, acumSec = 0, 0
  reloj:SetScript("OnUpdate", function(self, dt)
    dt = dt or 0
    acum, acumSec = acum + dt, acumSec + dt
    if acum >= 0.05 then acum = 0; Probar(Atenuar, "atenuar") end
    if acumSec >= 5 then
      local c = Contador()
      if c then c.t = (c.t or 0) + acumSec end
      acumSec = 0
    end
  end)
  GL.Evento(reloj, "QUEST_TURNED_IN")
  reloj:SetScript("OnEvent", function()
    local c = Contador()
    if c then c.q = (c.q or 0) + 1 end
  end)
end)

table.insert(GL.trasRefrescar, function()
  Probar(RefrescarSegmentos, L"barra por pasos")
  Probar(RefrescarFilas, "objetivos")
end)

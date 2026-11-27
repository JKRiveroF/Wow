-- Llegada.lua (9.1): tarjeta en la pestaña Guía con
--  · la llegada al 60 con tu ritmo real: horas de juego que te faltan y, si juegas hoy X tiempo (botón para
--    cambiarlo: 30 min, 1, 2, 3 o 4 h), en qué nivel y en qué sección de la ruta acabarás;
--  · y al llegar al 60, «Y ahora qué»: lo que te queda según tus datos del juego (profesiones por subir a 300,
--    reputaciones de la guía sin exaltar y mazmorras de nivel 60 de la guía).
-- El ritmo real es la XP que has ganado entre el tiempo jugado en tus últimos niveles (Estadísticas por nivel);
-- si aún no hay bastante, el de los últimos días (Cuenta › Hoy). Necesita 15 minutos jugados.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil

-- XP de cada nivel (1-59) en el clásico; el del nivel actual se lee del juego
local XP_NIVEL = { 400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400, 16000,
  17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, 50800, 54500,
  58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800, 117500, 123200, 129100,
  135100, 141200, 147500, 153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800 }
GL.XP_NIVEL = XP_NIVEL
local HORAS = { 0.5, 1, 2, 3, 4 }
local MIN_SEG = 900

local function DB() return GuiaAventureroDB or {} end
local function Num(v) v = (GL.Seguro and GL.Seguro(v)) or v; return type(v) == "number" and v or nil end
local function Nivel() return Num(UnitLevel and UnitLevel("player")) or 1 end
local function Miles(n)
  return GL.FormatoMiles(n)
end
local function Horas(h)
  if h < 1 then return math.max(1, math.floor(h * 60 + 0.5)) .. L" min" end
  if h < 10 then
    local hh, mm = math.floor(h), math.floor((h - math.floor(h)) * 60 + 0.5)
    if mm == 60 then hh, mm = hh + 1, 0 end
    return hh .. " h" .. (mm > 0 and (" " .. mm .. L" min") or "")
  end
  return math.floor(h + 0.5) .. " h"
end
local function TextoHoras(h) return h < 1 and (math.floor(h * 60) .. L" min") or (h == math.floor(h) and (h .. " h") or (h .. " h")) end

------------------------------------------------------------------------
-- Ritmo real (XP por hora de juego)
------------------------------------------------------------------------
local function Ritmo()
  local db = DB()
  local e = db.estadisticas and db.estadisticas.niveles
  local nivel = Nivel()
  if type(e) == "table" then
    -- los últimos niveles, del actual hacia atrás, hasta juntar al menos 1 h (o los que haya)
    local xp, t = 0, 0
    for n = nivel, math.max(1, nivel - 6), -1 do
      local d = e[n]
      if type(d) == "table" and Num(d.t) and Num(d.xp) then xp, t = xp + d.xp, t + d.t end
      if t >= 3600 then break end
    end
    if t >= MIN_SEG and xp > 0 then return xp / t * 3600, L"tus últimos niveles" end
  end
  local H = GL._hoy
  if H and H.RitmoPropio then
    local ok,xp,t=pcall(H.RitmoPropio)
    if ok and Num(xp) and Num(t) and t>=MIN_SEG and xp>0 then return xp/t*3600,L"los últimos días" end
  end
  return nil
end
GL.RitmoReal = Ritmo

-- XP que te falta para el 60 (con la del nivel actual del juego)
local function FaltaAl60()
  local nivel = Nivel()
  if nivel >= 60 then return 0 end
  local xp, max = Num(UnitXP and UnitXP("player")), Num(UnitXPMax and UnitXPMax("player"))
  local falta = (max and xp) and (max - xp) or (XP_NIVEL[nivel] or 0)
  for n = nivel + 1, 59 do falta = falta + (XP_NIVEL[n] or 0) end
  return falta
end

-- Nivel y % al que llegas ganando 'ganada' XP
local function NivelTras(ganada)
  local nivel = Nivel()
  local xp, max = Num(UnitXP and UnitXP("player")) or 0, Num(UnitXPMax and UnitXPMax("player")) or XP_NIVEL[nivel] or 1
  local resto = ganada
  while nivel < 60 do
    local queda = max - xp
    if resto < queda then return nivel, (xp + resto) / max end
    resto = resto - queda
    nivel = nivel + 1
    xp, max = 0, XP_NIVEL[nivel] or 1
  end
  return 60, 0
end

local function Calcular()
  local r, fuente = Ritmo()
  if not r then return nil end
  local horas = DB().llegadaHoras or 2
  local falta = FaltaAl60()
  local nv, pct = NivelTras(r * horas)
  local sec
  if GL.SeccionPorNivel and GL.RUTA then
    local s = GL.SeccionPorNivel(nv)
    -- si ya vas por delante en la ruta, no te mando atrás
    if s and DB().seccion and s < DB().seccion then s = DB().seccion end
    sec = s and GL.RUTA.secciones[s]
  end
  local c = { ritmo = r, fuente = fuente, horas = horas, faltaH = falta / r, faltaXP = falta / r, nivel = nv, pct = pct, seccion = sec }
  -- 9.2: con tus tiempos por paso. Si al menos la mitad de lo que queda tiene tiempo de verdad, se mezcla con la XP/h.
  if GL.EstimarRestoRuta then
    local ok, seg, cubierto = pcall(GL.EstimarRestoRuta)
    if ok and type(seg) == "number" and seg > 0 then
      c.pasosH, c.cubierto = seg / 3600, cubierto
      if cubierto >= 0.5 then c.faltaH = (c.faltaXP + c.pasosH) / 2 end
    end
    local db = DB()
    if GL.EstimarSeccion and db.seccion then
      local ok2, t2 = pcall(GL.EstimarSeccion, db.seccion, db.paso or 1, true)
      if ok2 and type(t2) == "number" then c.seccionH = t2 / 3600 end
    end
    if GL.FiabilidadTiempos then c.fiable, c.medidos = GL.FiabilidadTiempos() end
  end
  return c
end
GL.LlegadaAl60 = Calcular

------------------------------------------------------------------------
-- Y ahora qué (nivel 60)
------------------------------------------------------------------------
local function YAhoraQue()
  local l = {}
  local R = GL.RUTA
  local profs = {}
  for _, p in ipairs((R and R.profesiones) or {}) do
    local ok, n = pcall(GL.NivelProfesion, p)
    if ok and Num(n) and n < 300 then table.insert(profs, p.nombre .. " " .. n .. "/300") end
  end
  if #profs > 0 then table.insert(l, { L"Profesiones", table.concat(profs, " · "), "oficios" }) end
  -- reputaciones con ficha en la guía que aún no están en exaltado
  if GL.DatosReputacion and GL.LeerReputaciones977 then
    local ok, fichas = pcall(GL.DatosReputacion)
    local okR, lista = pcall(GL.LeerReputaciones977)
    local reps = {}
    if ok and type(fichas) == "table" and okR and type(lista) == "table" then
      for _, f in ipairs(lista) do
        local ficha = f.id and fichas[f.id]
        if f.rango and f.rango < 8 and ficha and not ficha.pendiente
          and not (GL.AvisoFaccion977 and GL.AvisoFaccion977(ficha, f.id)) then
          local etiqueta = GL._reputacion977.Etiqueta(f.rango)
          table.insert(reps, f.nombre .. " (" .. etiqueta .. ")")
        end
      end
    end
    if #reps > 0 then table.insert(l, { L"Reputaciones", table.concat(reps, " · ", 1, math.min(#reps, 5)) .. (#reps > 5 and " · ..." or ""), "reputacion" }) end
  end
  if GL.DatosMazmorras then
    local ok, lista = pcall(GL.DatosMazmorras)
    local m60 = {}
    if ok and type(lista) == "table" then
      for _, m in ipairs(lista) do if Num(m.max) and m.max >= 58 and m.n then table.insert(m60, m.n) end end
    end
    if #m60 > 0 then table.insert(l, { L"Mazmorras de nivel 60", table.concat(m60, " · ", 1, math.min(#m60, 6)) .. (#m60 > 6 and " · ..." or ""), "mazmorras" }) end
  end
  return l
end
GL.YAhoraQue = YAhoraQue

------------------------------------------------------------------------
-- Tarjeta
------------------------------------------------------------------------
local t
local barras, pie = {}, nil
local function Crear(panel)
  t = CreateFrame("Frame", nil, panel, PLANTILLA)
  t.titulo = GL.Texto(t, "GameFontNormalSmall")
  t.titulo:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -7)
  t.texto = GL.Texto(t, "GameFontHighlightSmall")
  t.texto:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -22)
  if t.texto.SetJustifyH then t.texto:SetJustifyH("LEFT") end
  t.boton = GL.CrearBoton(t, "2 h", function()
    local h = DB().llegadaHoras or 2
    local sig = HORAS[1]
    for i, v in ipairs(HORAS) do if v == h then sig = HORAS[i % #HORAS + 1] end end
    DB().llegadaHoras = sig
    if GL.Refrescar then GL.Refrescar() end
  end, nil, 18)
  t.boton:SetWidth(62)
  t.boton:SetPoint("TOPRIGHT", t, "TOPRIGHT", -4, -4)
  if GL.Ayuda then GL.Ayuda(t.boton, L"Cuánto vas a jugar hoy", L"Clic: 30 min, 1, 2, 3 o 4 h.") end
  t.cerrar = GL.CrearBoton(t, "", function() DB().llegadaPlegada = not DB().llegadaPlegada; if GL.Refrescar then GL.Refrescar() end end, nil, 18)
  t.cerrar:SetWidth(22)
  t.boton:SetPoint("TOPRIGHT", t.cerrar, "TOPLEFT", -4, 0)
  t.cerrar:SetPoint("TOPRIGHT", t, "TOPRIGHT", -4, -4)
  if GL.Ayuda then GL.Ayuda(t.cerrar, L"Plegar", L"Deja solo la línea de arriba.") end
  t.farmeo = GL.CrearBoton(t, L"Me falta XP", function() if GL.AbrirFarmeo then GL.AbrirFarmeo() end end, nil, 18)
  t.farmeo:SetWidth(90)
  t.farmeo:SetPoint("TOPRIGHT", t.boton, "TOPLEFT", -4, 0)
  if GL.Ayuda then GL.Ayuda(t.farmeo, L"Me falta XP", L"Sitios con enemigos de tu nivel cerca de ti para farmear.") end
end

local function Tarjeta(panel, y, ancho)
  if t then t:Hide() end
  if DB().llegada60 == false or not GL.RUTA then return 0 end
  local nivel = Nivel()
  if nivel < 60 then return 0 end   -- 9.4.2: en la Guía solo al 60 (antes, solo la ruta)
  local titulo, lineas, conBoton
  if nivel >= 60 then
    local l = YAhoraQue()
    if #l == 0 then return 0 end
    titulo = C.AMARILLO .. L"NIVEL 60 · Y AHORA QUÉ" .. C.FIN
    lineas = {}
    for _, e in ipairs(l) do table.insert(lineas, C.BLANCO .. e[1] .. ": " .. C.FIN .. e[2]) end
  else
    local c = Calcular()
    if not c then return 0 end
    titulo = C.GRIS .. L"LLEGADA AL 60" .. C.FIN .. "  " .. C.BLANCO .. L"unas " .. Horas(c.faltaH) .. L" de juego" .. C.FIN
    local donde = c.seccion and (L", en " .. C.AMARILLO .. tostring(c.seccion.titulo) .. C.FIN) or ""
    lineas = {}
    if c.seccionH then
      table.insert(lineas, C.GRIS .. L"Esta sección: " .. C.FIN .. "|cffa48cff" .. Horas(c.seccionH) .. C.FIN ..
        (c.fiable and (C.GRIS .. L"  ·  Fiable: " .. C.FIN .. ((c.fiable == "alta" and C.VERDE) or (c.fiable == "media" and C.AMARILLO) or C.GRIS) .. c.fiable .. C.FIN) or ""))
    end
    for _, e in ipairs({
      L"Si juegas " .. TextoHoras(c.horas) .. L" hoy: " .. C.VERDE .. L"nivel " .. c.nivel .. (c.nivel < 60 and (" (" .. math.floor(c.pct * 100) .. " %)") or "") .. C.FIN .. donde .. ".",
      C.GRIS .. L"Tu ritmo: " .. Miles(c.ritmo) .. L" XP/h (" .. c.fuente .. ")" ..
        ((c.cubierto and c.cubierto >= 0.5) and (L" y tus tiempos de " .. (c.medidos or 0) .. L" pasos") or "") .. "." .. C.FIN,
    }) do table.insert(lineas, e) end
    if GL.PasosLentos then
      local ok, lentos = pcall(GL.PasosLentos, 2)
      if ok and type(lentos) == "table" and #lentos > 0 then
        local l = {}
        for _, x in ipairs(lentos) do
          local tt = tostring(x.paso.t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%[(.-)%]", "%1")
          tt = tt:match("^(.-[%.:;])%s") or tt
          if #tt > 40 then tt = tt:sub(1, 40) .. "…" end
          table.insert(l, tt .. " (" .. math.floor(x.t / 60 + 0.5) .. L" min, media " .. math.floor(x.media / 60 + 0.5) .. ")")
        end
        table.insert(lineas, C.GRIS .. L"Pasos lentos: " .. C.FIN .. table.concat(l, " · "))
      end
    end
    conBoton = TextoHoras(c.horas)
  end
  if not t then Crear(panel) end
  t:SetParent(panel)
  local a = GL.COLOR.acento
  GL.Caja(t, GL.COLOR.caja, { a[1], a[2], a[3], 0.35 })
  t.titulo:SetText(titulo)
  GL.Mostrar(t.boton, conBoton ~= nil and not DB().llegadaPlegada)
  GL.Mostrar(t.farmeo, conBoton ~= nil and not DB().llegadaPlegada and GL.AbrirFarmeo ~= nil and DB().farmeo ~= false)
  if conBoton then t.boton.texto:SetText(conBoton) end
  t.cerrar.texto:SetText(DB().llegadaPlegada and "+" or "–")
  local h = 26
  if DB().llegadaPlegada then
    t.texto:Hide()
  else
    local txt = table.concat(lineas, "\n")
    t.texto:SetWidth(ancho - 20)
    t.texto:SetText(txt)
    t.texto:Show()
    h = 26 + GL.Alto(t.texto, txt, 12, ancho - 20) + 4
  end
  -- 9.2: minutos por sección (tú), en barras; solo con 3 secciones o más medidas
  for _, b in ipairs(barras) do b:Hide() end
  if nivel < 60 and not DB().llegadaPlegada and GL.MinutosPorSeccion then
    local ok, l = pcall(GL.MinutosPorSeccion)
    if ok and type(l) == "table" and #l >= 3 then
      while #l > 10 do table.remove(l, 1) end
      local max = 1
      for _, x in ipairs(l) do max = math.max(max, x.min) end
      local anchoB = math.floor((ancho - 20 - (#l - 1) * 3) / #l)
      for i, x in ipairs(l) do
        local b = barras[i]
        if not b then b = t:CreateTexture(nil, "ARTWORK"); barras[i] = b end
        b:SetColorTexture(a[1], a[2], a[3], x.s == DB().seccion and 1 or 0.6)
        b:SetWidth(anchoB); b:SetHeight(math.max(2, 36 * x.min / max))
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", t, "TOPLEFT", 10 + (i - 1) * (anchoB + 3), -(h + 38))
        b:Show()
      end
      pie = pie or GL.Texto(t, "GameFontDisableSmall")
      pie:ClearAllPoints()
      pie:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -(h + 40))
      pie:SetText(L"min por sección (tú): de la " .. l[1].s .. L" a la " .. l[#l].s)
      pie:Show()
      h = h + 56
    elseif pie then pie:Hide() end
  elseif pie then pie:Hide() end
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  t:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  t:SetHeight(h)
  t:Show()
  return h
end
-- 9.4.2: en la Guía solo sale al 60 (antes del 60, la Guía es solo la ruta)
table.insert(GL.tarjetasGuia, Tarjeta)   -- 9.4.2: solo sale al 60

GL.comandos = GL.comandos or {}
GL.comandos["llegada"] = function()
  if not GL.Mensaje then return end
  if Nivel() >= 60 then
    local l = YAhoraQue()
    if #l == 0 then GL.Mensaje(L"nivel 60: no te queda nada de lo que la guía puede comprobar.") end
    for _, e in ipairs(l) do GL.Mensaje(e[1] .. ": " .. e[2]) end
    return
  end
  local c = Calcular()
  if not c then GL.Mensaje(L"aún no hay bastante tiempo jugado para saber tu ritmo (hacen falta 15 minutos).") return end
  GL.Mensaje(L"al 60 te faltan unas " .. Horas(c.faltaH) .. L" de juego a " .. Miles(c.ritmo) .. L" XP/h. Si juegas " ..
    TextoHoras(c.horas) .. L" hoy, acabas en el nivel " .. c.nivel .. (c.seccion and (" (" .. tostring(c.seccion.titulo) .. ")") or "") .. ".")
end

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "llegada60", "Llegada al 60",
  "En la Guía: las horas de juego que te faltan para el 60 con tu ritmo real y dónde acabarás hoy si juegas un rato. Al 60, lo que te queda por hacer.",
  function() return DB().llegada60 ~= false end, function(v) DB().llegada60 = v; if GL.Refrescar then GL.Refrescar() end end, pestana = "paso" })

GL._llegada = { Calcular = Calcular, Ritmo = Ritmo, Falta = FaltaAl60, NivelTras = NivelTras, YAhoraQue = YAhoraQue, Tarjeta = Tarjeta }

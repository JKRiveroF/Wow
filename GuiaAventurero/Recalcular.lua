-- Recalcular.lua (9.1): la guía cambia sola de paso en tres casos, y siempre se puede deshacer:
--  · Te has saltado pasos: el de ahora sigue pendiente, pero ya hiciste las misiones de 3 o más pasos de después.
--    Pasas al primero que falte detrás de lo que ya hiciste.
--  · Mueres mucho: 3 muertes en 10 minutos en el mismo paso. Si la sección es de más nivel que tú, vuelves a la
--    de tu nivel; si no, el paso se deja para luego y sigues con el siguiente.
--  · Vas adelantado: tienes 2 niveles o más por encima de la sección. Pasas a la sección de tu nivel.
-- Ajustes › Paso › «Recalcular la ruta»: Sola (de serie), Preguntar (tarjeta con botón) o No.
-- Si vuelves a mano a un paso anterior (con < o desde la lista), ese paso no se recalcula: lo has elegido tú.
-- Lo que hace queda en GuiaAventureroDB.recalculos (sale en /ga informe).
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil

local MIN_SALTADOS = 3       -- pasos ya hechos por delante para dar por saltado el de ahora
local MIN_EMPEZADO = 5       -- 9.7.9.4: los mismos, si el paso de ahora ya está empezado
local MIRAR = 25             -- pasos por delante que se miran
local MUERTES, VENTANA_MUERTES = 3, 600
local ADELANTO = 2           -- niveles por encima del máximo de la sección
local ESPERA = 60            -- segundos entre dos recalculados

local function DB() return GuiaAventureroDB or {} end
local function Ahora() return (GetTime and GetTime()) or 0 end
local function Modo() return DB().recalcular or "auto" end
local function Nivel() return GL.NivelJugadorR14() end

local muertes = {}           -- momentos de las muertes en el paso actual
local claveMuertes
local ultimo = -1000         -- último recalculado
local elegidoAMano = {}      -- pasos a los que volviste tú: no se tocan
local descartados = {}       -- "clave:motivo" que deshiciste o no quisiste
local indiceAntes
local enMundoR14, generacionR14 = true, 0
local pendiente              -- propuesta o cambio hecho: { motivo, texto, s, p, desde = {s, p, d}, hecho }

local function Clave() local db = DB(); return tostring(db.seccion) .. ":" .. tostring(db.paso) end

local function ConMisiones(p)
  for _, d in ipairs((p and p.wp) or {}) do if d.q then return true end end
  return false
end

local function Apuntar(texto)
  local db = DB()
  if type(db.recalculos) ~= "table" then db.recalculos = {} end
  table.insert(db.recalculos, tostring((date and date("%d-%m %H:%M")) or "?") .. " · " .. texto)
  while #db.recalculos > 20 do table.remove(db.recalculos, 1) end
end

------------------------------------------------------------------------
-- Los tres casos: cada uno devuelve la propuesta o nil
------------------------------------------------------------------------
-- 9.7.9.4 (Quini: «la ruta cambia el paso automáticamente si ya tienes completados algunos posteriores todo el rato»).
-- Antes contaba como hecho un paso de Recoger con solo tener la misión en el diario: al coger varias misiones de golpe
-- en un campamento, los pasos de Recoger de después salían hechos y la guía te sacaba del paso en el que estabas.
-- Ahora un paso solo prueba que te lo saltaste si sus misiones están ENTREGADAS (o ignoradas a mano); no cuentan las
-- misiones extra (REFUERZO_97, se hacen en cualquier orden), y si el paso de ahora ya está empezado (misión cogida o
-- algún destino hecho) hacen falta MIN_EMPEZADO pasos entregados por delante, no 3.
local function Extra(p)
  local t = p and p.t
  -- El texto de la ruta ya puede estar traducido por Idioma.lua.
  return type(t) == "string" and (t:find("^Misión extra") ~= nil or t:find("^Extra quest") ~= nil)
end
local function Entregado(p)
  local alguna = false
  for _, d in ipairs((p and p.wp) or {}) do
    if d.q then
      alguna = true
      local ignorado = GL.Marcado and GL.Marcado("ignorados", d)
      if not ignorado and not (GL.MisionCompletada and GL.MisionCompletada(d.q)) then return false end
    end
  end
  return alguna
end
local function Empezado(p)
  for _, d in ipairs((p and p.wp) or {}) do
    if d.q and (GL.DestinoHecho(d) == true or (GL.MisionEnDiario and GL.MisionEnDiario(d.q))) then return true end
  end
  return false
end

local function Saltados()
  local db = DB()
  local R = GL.RUTA
  local sec = R.secciones[db.seccion]
  local p = sec and sec.pasos[db.paso]
  if not p or GL.EstadoPaso(p) ~= "pendiente" then return nil end
  local s, q = db.seccion, db.paso
  local hechos, ultimoHecho = 0, nil
  for _ = 1, MIRAR do
    s, q = GL.PasoDespues(s, q)
    if not s then break end
    local paso = R.secciones[s].pasos[q]
    if ConMisiones(paso) and not Extra(paso) and Entregado(paso) then hechos = hechos + 1; ultimoHecho = { s, q } end
  end
  if hechos < (Empezado(p) and MIN_EMPEZADO or MIN_SALTADOS) or not ultimoHecho then return nil end
  local ds, dq = GL.PasoDespues(ultimoHecho[1], ultimoHecho[2])
  if not ds then return nil end
  return { motivo = "saltados", s = ds, p = dq,
    texto = L"Ya hiciste " .. hechos .. L" pasos de los siguientes: pasas a la sección " .. ds .. L", paso " .. dq .. "." }
end

local function Muertes()
  local n = 0
  for _, t in ipairs(muertes) do if Ahora() - t <= VENTANA_MUERTES then n = n + 1 end end
  if n < MUERTES then return nil end
  local db = DB()
  local sec = GL.RUTA.secciones[db.seccion]
  local nivel = Nivel()
  if not nivel then return nil end
  if sec and nivel < sec.min then
    local s = GL.SeccionPorNivel(nivel)
    if s and s < db.seccion then
      return { motivo = "muertes", s = s, p = 1,
        texto = n .. L" muertes en 10 min y esta sección es de nivel " .. sec.min .. L": vuelves a la de tu nivel (" .. tostring(GL.RUTA.secciones[s].titulo) .. ")." }
    end
  end
  local s, p = GL.PasoDespues(db.seccion, db.paso)
  if not s then return nil end
  return { motivo = "muertes", s = s, p = p, posponer = true,
    texto = n .. L" muertes en 10 min en este paso: lo dejas para luego y sigues con el siguiente." }
end

local function Adelantado()
  local db = DB()
  local sec = GL.RUTA.secciones[db.seccion]
  local nivel = Nivel()
  if not nivel or not sec or nivel < (sec.max or 60) + ADELANTO then return nil end
  local s = GL.SeccionPorNivel(nivel)
  if not s or s <= db.seccion then return nil end
  return { motivo = "nivel", s = s, p = 1,
    texto = L"Tienes nivel " .. nivel .. L" y la sección es " .. sec.min .. "-" .. sec.max .. L": pasas a " .. tostring(GL.RUTA.secciones[s].titulo) .. "." }
end

------------------------------------------------------------------------
-- Hacer, deshacer
------------------------------------------------------------------------
local function Aplicar(prop)
  if not enMundoR14 or not GL.PersonajeVivoR14() or not Nivel() or not GL.TransitoLibreR14() then return false end
  local db = DB()
  if prop.clave and prop.clave ~= Clave() then return false end
  if prop.motivo == "nivel" then
    local vigente = Adelantado()
    if not vigente or vigente.s ~= prop.s or vigente.p ~= prop.p then return false end
  end
  prop.desde = { db.seccion, db.paso, db.destino }
  if prop.posponer then
    local _, p = GL.PasoActual()
    for _, d in ipairs((p and p.wp) or {}) do
      if GL.DestinoHecho(d) == false and GL.Marcar then GL.Marcar("pospuestos", d, true) end
    end
  end
  if not GL.SaltarA(prop.s, prop.p, 1) then return false end
  prop.hecho = true
  ultimo = Ahora()
  muertes = {}
  Apuntar(prop.texto)
  return true
end

local function Deshacer()
  local prop = pendiente
  pendiente = nil
  if not prop then return end
  if prop.hecho and prop.desde then
    descartados[prop.desde[1] .. ":" .. prop.desde[2] .. ":" .. prop.motivo] = true
    elegidoAMano[prop.desde[1] .. ":" .. prop.desde[2]] = true
    GL.SaltarA(prop.desde[1], prop.desde[2], prop.desde[3])
    Apuntar(L"deshecho: " .. prop.texto)
  end
  if GL.Refrescar then GL.Refrescar() end
end

local function Mirar()
  if not enMundoR14 then return end
  if not GL.RUTA or not GL.frame or not GL.EstadoPaso or not GL.SaltarA then return end
  if Modo() == "no" then pendiente = nil; return end
  if not GL.PersonajeVivoR14() or not Nivel() then return end
  if InCombatLockdown and InCombatLockdown() then return end
  if not GL.TransitoLibreR14() then return end
  local db = DB()
  local clave = Clave()
  -- volver atrás no lo hace la guía: si el paso retrocede, lo has elegido tú
  local indice = GL.PosicionEnRuta and GL.PosicionEnRuta()
  if indiceAntes and indice and indice < indiceAntes and not (pendiente and pendiente.hecho) then elegidoAMano[clave] = true end
  indiceAntes = indice
  if clave ~= claveMuertes then claveMuertes = clave; muertes = {} end
  if pendiente and not pendiente.hecho then
    -- la propuesta ya no vale si te has movido
    if pendiente.clave ~= clave then pendiente = nil
    elseif pendiente.motivo == "nivel" then
      local vigente = Adelantado()
      if not vigente or vigente.s ~= pendiente.s or vigente.p ~= pendiente.p then pendiente = nil end
    end
  end
  if pendiente and pendiente.hecho and Ahora() - ultimo > 300 then pendiente = nil end   -- el aviso de lo hecho se va solo
  if Ahora() - ultimo < ESPERA then return end
  if pendiente and not pendiente.hecho then return end
  local prop
  for _, caso in ipairs({ Muertes, Adelantado, Saltados }) do
    local ok, r = pcall(caso)
    if ok and r then
      local manual = elegidoAMano[clave] and r.motivo ~= "muertes"
      if not manual and not descartados[clave .. ":" .. r.motivo] then prop = r; break end
    elseif not ok and GL.Fallo then GL.Fallo("recalcular", r) end
  end
  if not prop then return end
  prop.clave = clave
  if Modo() == "auto" then
    if not Aplicar(prop) then return end
    pendiente = prop
    if GL.LanzarAvisoFuera and not (GL.frame:IsShown() and (db.tamano or "completo") == "completo") then
      pcall(GL.LanzarAvisoFuera, L"Ruta recalculada", prop.texto, false, "guia")
    end
    if GL.Mensaje then GL.Mensaje(L"ruta recalculada. " .. prop.texto .. L" (Deshacer en la pestaña Guía.)") end
  else
    pendiente = prop
    ultimo = Ahora()
  end
  if GL.Refrescar then GL.Refrescar() end
end
GL.MirarRecalculo = Mirar

------------------------------------------------------------------------
-- Tarjeta en la pestaña Guía
------------------------------------------------------------------------
local tarjeta
local function Tarjeta(panel, y, ancho)
  if tarjeta then tarjeta:Hide() end
  if not pendiente or Modo() == "no" then return 0 end
  if not tarjeta then
    tarjeta = CreateFrame("Frame", nil, panel, PLANTILLA)
    tarjeta.icono = tarjeta:CreateTexture(nil, "ARTWORK")
    tarjeta.icono:SetSize(16, 16)
    tarjeta.icono:SetPoint("TOPLEFT", tarjeta, "TOPLEFT", 8, -7)
    tarjeta.icono:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    tarjeta.texto = GL.Texto(tarjeta, "GameFontHighlightSmall")
    tarjeta.texto:SetPoint("TOPLEFT", tarjeta, "TOPLEFT", 30, -8)
    if tarjeta.texto.SetJustifyH then tarjeta.texto:SetJustifyH("LEFT") end
    tarjeta.si = GL.CrearBoton(tarjeta, L"Deshacer", function()
      if pendiente and not pendiente.hecho then
        local prop = pendiente
        if not GL.PersonajeVivoR14() then return end
        if Aplicar(prop) then pendiente = prop else pendiente = nil end
        if GL.Refrescar then GL.Refrescar() end
      else
        Deshacer()
      end
    end, nil, 18, "accion")
    tarjeta.si:SetWidth(78)
    tarjeta.no = GL.CrearBoton(tarjeta, L"Vale", function()
      if pendiente and not pendiente.hecho then descartados[pendiente.clave .. ":" .. pendiente.motivo] = true end
      pendiente = nil
      if GL.Refrescar then GL.Refrescar() end
    end, nil, 18)
    tarjeta.no:SetWidth(52)
    tarjeta.no:SetPoint("TOPRIGHT", tarjeta, "TOPRIGHT", -4, -4)
    tarjeta.si:SetPoint("RIGHT", tarjeta.no, "LEFT", -4, 0)
    tarjeta.texto:SetPoint("RIGHT", tarjeta.si, "LEFT", -6, 0)
  end
  tarjeta:SetParent(panel)
  local a = GL.COLOR.acento
  GL.Caja(tarjeta, { a[1], a[2], a[3], 0.10 }, { a[1], a[2], a[3], 0.55 })
  local titulo = pendiente.hecho and L"Ruta recalculada" or L"¿Recalcular la ruta?"
  tarjeta.texto:SetText(C.AMARILLO .. titulo .. C.FIN .. "\n" .. pendiente.texto)
  if pendiente.hecho then
    tarjeta.si.texto:SetText(L"Deshacer"); tarjeta.no.texto:SetText(L"Vale")
  else
    tarjeta.si.texto:SetText(L"Recalcular"); tarjeta.no.texto:SetText(L"No")
  end
  local h = math.max(30, ((tarjeta.texto.GetStringHeight and tonumber(tarjeta.texto:GetStringHeight())) or 24) + 14)
  tarjeta:ClearAllPoints()
  tarjeta:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  tarjeta:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  tarjeta:SetHeight(h)
  tarjeta:Show()
  return h
end
table.insert(GL.tarjetasGuia, 1, Tarjeta)

------------------------------------------------------------------------
-- Eventos y ajuste
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
GL.Evento(ev, "PLAYER_DEAD")
GL.Evento(ev, "PLAYER_ALIVE")
GL.Evento(ev, "PLAYER_UNGHOST")
GL.Evento(ev, "PLAYER_LEVEL_UP")
GL.Evento(ev, "QUEST_TURNED_IN")
GL.Evento(ev, "ZONE_CHANGED_NEW_AREA")
GL.Evento(ev, "PLAYER_LEAVING_WORLD")
GL.Evento(ev, "PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, evento)
  if evento == "PLAYER_LEAVING_WORLD" then
    enMundoR14 = false
    generacionR14 = generacionR14 + 1
    if pendiente and not pendiente.hecho then pendiente = nil end
    return
  elseif evento == "PLAYER_ENTERING_WORLD" then
    enMundoR14 = true
    generacionR14 = generacionR14 + 1
  end
  if not enMundoR14 then return end
  if evento == "PLAYER_DEAD" then
    if Clave() ~= claveMuertes then claveMuertes = Clave(); muertes = {} end
    table.insert(muertes, Ahora())
  end
  local generacion = generacionR14
  local ejecutado = false
  local function ejecutar()
    if ejecutado or not enMundoR14 or generacion ~= generacionR14 then return end
    ejecutado = true
    pcall(Mirar)
  end
  if C_Timer and C_Timer.After then
    local ok, resultado = pcall(C_Timer.After, 2, ejecutar)
    if not ok or resultado == false then ejecutar() end
  else ejecutar() end
end)
local reloj = 0
ev:SetScript("OnUpdate", function(_, dt)
  reloj = reloj + (dt or 0)
  if reloj < 15 then return end
  reloj = 0
  pcall(Mirar)
end)

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "recalcular", "Recalcular la ruta",
  "Si te saltas pasos, mueres 3 veces en 10 min o vas 2 niveles por encima de la sección, la guía cambia de paso. Sola: lo hace y te deja deshacerlo. Preguntar: te lo propone en una tarjeta. No: nunca.",
  function() return Modo() end, function(v) DB().recalcular = v; pendiente = nil; if GL.Refrescar then GL.Refrescar() end end,
  pestana = "paso", opciones = { { "auto", "Sola" }, { "preguntar", "Preguntar" }, { "no", "No" } } })

GL._recalcular = { Mirar = Mirar, Saltados = Saltados, Muertes = Muertes, Adelantado = Adelantado, Deshacer = Deshacer,
  Pendiente = function() return pendiente end, Muerte = function() table.insert(muertes, Ahora()); claveMuertes = Clave() end,
  Reiniciar = function() ultimo = -1000; pendiente = nil; descartados = {}; elegidoAMano = {}; indiceAntes = nil end }

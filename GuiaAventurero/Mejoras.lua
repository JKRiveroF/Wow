-- Mejoras.lua (6.9): ritmo de subida, estadísticas por nivel (Personaje > Estadísticas), avisos de equipo,
-- bolsas y comida en la pestaña Guía, vender lo gris (automatismo, apagado de serie) y modo grupo
-- (paso de los compañeros que llevan la guía y misiones que puedes compartir). Solo datos del juego.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local function DB() return GuiaAventureroDB end
local function Num(v) return (GL.Seguro and GL.Seguro(v)) or v end

local function Miles(n)
  return GL.FormatoMiles(n)
end

local function Duracion(seg)
  seg = math.floor(seg or 0)
  if seg < 60 then return L"menos de 1 min" end
  local h, m = math.floor(seg / 3600), math.floor((seg % 3600) / 60)
  if h > 0 then return h .. " h " .. m .. L" min" end
  return m .. L" min"
end

local function Ahora() return (GetTime and GetTime()) or 0 end

------------------------------------------------------------------------
-- XP ganada (sirve para el ritmo y para las estadísticas)
------------------------------------------------------------------------
local xpPrev, xpMaxPrev = nil, nil
local ganado, muestras = 0, {}   -- XP de esta sesión y muestras { t, ganado } para el ritmo
local VENTANA = 15 * 60          -- el ritmo mira los últimos 15 minutos (o la sesión si es más corta)

local function Estad()
  local db = DB()
  if type(db) ~= "table" then return nil end
  db.estadisticas = db.estadisticas or { desde = (time and time()) or 0, niveles = {}, muertes = 0 }
  return db.estadisticas
end

local function DelNivel(n)
  local e = Estad()
  if not e then return nil end
  e.niveles[n] = e.niveles[n] or { t = 0, q = 0, xp = 0 }
  return e.niveles[n]
end

local function Nivel() return Num(UnitLevel and UnitLevel("player")) or 1 end

local function LeerXP()
  local xp, max = Num(UnitXP and UnitXP("player")), Num(UnitXPMax and UnitXPMax("player"))
  if type(xp) ~= "number" or type(max) ~= "number" then return end
  if xpPrev then
    local d = (xp >= xpPrev) and (xp - xpPrev) or ((xpMaxPrev or xpPrev) - xpPrev + xp)   -- con subida de nivel
    if d > 0 then
      ganado = ganado + d
      local n = DelNivel(xp >= xpPrev and Nivel() or Nivel() - 1)
      if n then n.xp = n.xp + d end
    end
  end
  xpPrev, xpMaxPrev = xp, max
  table.insert(muestras, { t = Ahora(), g = ganado })
  while #muestras > 2 and Ahora() - muestras[2].t > VENTANA do table.remove(muestras, 1) end
end

local inicio = nil
local function XPporHora()
  if not inicio then return nil end
  local seg, xp = Ahora() - inicio, ganado
  if seg > VENTANA then
    local base = muestras[1]
    for i = 1, #muestras do if Ahora() - muestras[i].t <= VENTANA then base = muestras[i]; break end end
    if base then seg, xp = Ahora() - base.t, ganado - base.g end
  end
  if seg < 120 or xp <= 0 then return nil end
  return xp / seg * 3600
end

GL.TextoRitmo = function()
  local r = XPporHora()
  if not r then return nil end
  local xp, max = Num(UnitXP and UnitXP("player")), Num(UnitXPMax and UnitXPMax("player"))
  local t = ""
  if type(xp) == "number" and type(max) == "number" and max > xp then
    t = "  ·  " .. C.AMARILLO .. L"nivel " .. (Nivel() + 1) .. L" en unos " .. Duracion((max - xp) / r * 3600) .. C.FIN
  end
  return C.VERDE .. Miles(r) .. L" XP/h" .. C.FIN .. t
end

------------------------------------------------------------------------
-- Avisos (tarjeta en la pestaña Guía)
------------------------------------------------------------------------
local descartados = {}
local hogarEnUso, hogarLista = false, false   -- 7.5.8
local cacheBolsas = { libres = nil, comida = nil }

local function InfoHueco(b, s)
  if C_Container and C_Container.GetContainerItemInfo then
    local i = C_Container.GetContainerItemInfo(b, s)
    if type(i) == "table" then
      if not i.hyperlink and i.itemID then error("enlace de objeto pendiente") end
      return i.hyperlink, i.stackCount, i.quality, i.hasNoValue, i.isLocked
    end
    if i ~= nil then error("datos de hueco no disponibles") end
    return nil
  end
  if GetContainerItemInfo then
    local textura, cuenta, bloqueado, calidad, _, _, link, _, sinValor = GetContainerItemInfo(b, s)
    if not link and (textura or cuenta and cuenta>0) then error("enlace de objeto pendiente") end
    return link, cuenta, calidad, sinValor, bloqueado
  end
  error("API de inventario no disponible")
end

local function EnteroBolsaR14(v)
  if type(issecretvalue)=="function" then
    local ok,secreto=pcall(issecretvalue,v)
    if not ok or secreto then return false end
  end
  return type(v)=="number" and v>=0 and v<math.huge and v%1==0
end
local function Huecos(b)
  local f = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local n = type(f)=="function" and f(b)
  if not EnteroBolsaR14(n) then error("inventario no disponible") end
  return n
end

-- Solo huecos generales; una lectura incompleta no equivale a bolsas llenas.
function GL.HuecosGenerales976()
  local f = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  if not f then return nil end
  local total = 0
  for b = 0, (NUM_BAG_SLOTS or 4) do
    local ok, n, tipo = pcall(f, b)
    if not ok or not EnteroBolsaR14(n) then return nil end
    if tipo ~= nil and not EnteroBolsaR14(tipo) then return nil end
    if tipo == 0 or (b == 0 and tipo == nil) then total = total + n
    elseif tipo == nil and n > 0 then return nil end
    if total >= math.huge then return nil end
  end
  return total
end

-- Nunca sugerir desechar objetos de misión por ausencia de texto en el diario.
local function Sobrante(link)
  local id = tonumber(link:match("item:(%d+)"))
  local q = id and GL.WH and GL.WH.objetosMision and GL.WH.objetosMision[id]
  return q and GL.MisionCompletada and GL.MisionEnDiario
    and GL.MisionCompletada(q) == true and GL.MisionEnDiario(q) == false
end

-- 9.4.2: comida y agua conjuradas del mago (en Forever no siempre vienen como «comida y bebida») y, por si acaso,
-- cualquier objeto cuyo efecto al usarlo sea comer o beber.
local CONJURADA = { [5350] = true, [2288] = true, [2136] = true, [3772] = true, [8077] = true, [8078] = true, [8079] = true,
  [5349] = true, [1113] = true, [1114] = true, [1487] = true, [8075] = true, [8076] = true, [22895] = true }
local EFECTO_COMIDA = { "comida", "bebida", "refrigerio", "food", "drink", "refreshment" }
local function EsComida(link, clase, sub)
  if clase == 0 and sub == 5 then return true end
  local id = tonumber(link:match("item:(%d+)"))
  if id and CONJURADA[id] then return true end
  if clase == 0 and GetItemSpell then
    local ok, efecto = pcall(GetItemSpell, link)
    efecto = ok and type(efecto) == "string" and string.lower(efecto) or ""
    for _, p in ipairs(EFECTO_COMIDA) do if efecto:find(p, 1, true) then return true end end
  end
  return false
end

-- Capacidades orientativas de bolsas generales de Classic; no asumir las de objetos desconocidos.
local CAPACIDAD_BOLSA = { [4496]=6, [4238]=6, [4240]=8, [4245]=10, [10050]=12, [14046]=14, [14155]=16 }
local function MejorBolsaDisponible()
  local slots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local libres = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  if not slots or not libres or not GetItemInfo then return nil end
  local menor, destino
  for b=1,(NUM_BAG_SLOTS or 4) do
    local ok, n = pcall(slots,b)
    if ok and type(n)=="number" and n>=0 then
      local bien, _, familia = pcall(libres,b)
      if (n==0 or (bien and familia==0)) and (not menor or n<menor) then menor,destino=n,b end
    end
  end
  if not destino then return nil end
  local mejor
  for b=0,(NUM_BAG_SLOTS or 4) do
    for j=1,Huecos(b) do
      local link=InfoHueco(b,j)
      local id=link and tonumber(link:match("item:(%d+)"))
      local cap=id and CAPACIDAD_BOLSA[id]
      if cap and cap>menor then
        local nombre,_,_,_,_,_,_,_,_,_,_,clase,sub=GetItemInfo(link)
        if nombre and clase==1 and sub==0 and (not mejor or cap>mejor.cap) then
          mejor={nombre=nombre,cap=cap,ganancia=cap-menor,destino=destino}
        end
      end
    end
  end
  return mejor
end
function GL.MejorBolsaDisponible9775()
  local ok, mejora = pcall(MejorBolsaDisponible)
  if ok then return mejora end
end

local function EscanearBolsasR14()
  local libres, comida, municion = GL.HuecosGenerales976(), 0, 0
  local pociones, pendientesDatos = 0, false
  local nivel = Nivel()
  local grises, sobrantes, baratos = {}, {}, {}
  for b = 0, (NUM_BAG_SLOTS or 4) do
    for s = 1, Huecos(b) do
      local link, cuenta, calidad, sinValor = InfoHueco(b, s)
      if link then
        if type(link)~="string" or not EnteroBolsaR14(cuenta) or cuenta==0 or type(GetItemInfo)~="function" then
          error("datos de objeto no disponibles")
        end
        local nombreItem, _, _, _, requerido, _, _, _, _, _, valor, clase, sub = GetItemInfo(link)
        if not nombreItem or clase == nil then pendientesDatos = true end
        if clase == 0 and sub == 1 then
          if type(requerido) == "number" and requerido <= nivel then pociones = pociones + (cuenta or 1)
          elseif type(requerido) ~= "number" then pendientesDatos = true end
        end
        if EsComida(link, clase, sub) then comida = comida + (cuenta or 1) end   -- comida y bebida (también la conjurada)
        if clase == 6 then municion = municion + (cuenta or 1) end            -- 7.4: flechas y balas
        -- 7.5.15: qué se puede tirar si las bolsas se llenan
        local nombre = link:match("%[(.-)%]") or "?"
        local precio = tonumber(Num(valor)) or 0
        local lista
        if calidad == 0 and not sinValor and precio > 0 then lista = grises
        elseif clase == 12 and Sobrante(link) then lista = sobrantes
        elseif (clase == 2 or clase == 4) and precio > 0 and (calidad or 1) <= 2 then lista = baratos end
        if lista then table.insert(lista, { n = nombre, c = cuenta or 1, p = precio * (cuenta or 1) }) end
      end
    end
  end
  local mejora = MejorBolsaDisponible()
  local porPrecio = function(a, b) return a.p < b.p end
  table.sort(grises, porPrecio); table.sort(baratos, porPrecio)
  return {libres=libres, comida=not pendientesDatos and comida or nil,
    municion=not pendientesDatos and municion or nil, pociones=not pendientesDatos and pociones or nil,
    mejora=mejora, grises=grises, sobrantes=sobrantes, baratos=baratos}
end
local function LeerBolsas()
  -- Publicar solo una lectura completa. Una lectura fallida invalida los avisos
  -- anteriores sin borrar datos guardados ni sustituir la tabla compartida.
  local ok, nueva = pcall(EscanearBolsasR14)
  for k in pairs(cacheBolsas) do cacheBolsas[k] = nil end
  if ok then for k,v in pairs(nueva) do cacheBolsas[k] = v end end
  return ok
end

-- 7.5.15: "Pata de lobo rota x4 (4 c)"
local function TextoObjeto(o, gris)
  local t = (gris and "|cff9d9d9d" or C.AMARILLO) .. o.n .. C.FIN .. (o.c > 1 and (" x" .. o.c) or "")
  if o.p and o.p > 0 then t = t .. C.GRIS .. " (" .. ((GL.Dinero and GL.Dinero(o.p)) or (o.p .. " c")) .. ")" .. C.FIN end
  return t
end

local function PeorPieza()
  if not GetInventoryItemDurability then return nil end
  local peor, pct, nombre = nil, 2, nil
  for slot = 1, 18 do
    local ok, act, max = pcall(GetInventoryItemDurability, slot)
    if ok and type(act) == "number" and type(max) == "number" and max > 0 and act / max < pct then
      pct, peor = act / max, slot
    end
  end
  if not peor then return nil end
  local link = GetInventoryItemLink and GetInventoryItemLink("player", peor)
  nombre = link and link:match("%[(.-)%]") or L"Una pieza"
  return nombre, pct
end

-- 7.4: reactivos por clase (id del objeto, nivel desde el que se usa y cuántos quedan para avisar)
local REACTIVOS = {
  MAGE = { { id = 17056, n = L"Pluma ligera", nivel = 12, min = 3 }, { id = 17031, n = L"Runa de teletransporte", nivel = 20, min = 3 },
    { id = 17032, n = L"Runa de portal", nivel = 40, min = 3 } },
  PRIEST = { { id = 17028, n = L"Vela sacra", nivel = 48, min = 5 } },
  PALADIN = { { id = 17033, n = L"Símbolo de divinidad", nivel = 30, min = 1 } },
  ROGUE = { { id = 5140, n = L"Polvo destellante", nivel = 22, min = 3 }, { id = 5530, n = L"Polvo cegador", nivel = 34, min = 3 } },
  SHAMAN = { { id = 17030, n = "Ankh", nivel = 30, min = 1 } },
  WARLOCK = { { id = 6265, n = L"Fragmento de alma", nivel = 10, min = 2 } },
}

GL.REACTIVOS = REACTIVOS   -- 9.0: la lista «Antes de salir» (Guia9.lua)

-- 7.4: experiencia descansada para la línea de niveles de la Guía
GL.TextoDescansada = function()
  if not GetXPExhaustion or Nivel() >= 60 then return nil end
  local d = GetXPExhaustion()
  if type(d) ~= "number" or d <= 0 then return nil end
  local txt = tostring(d)
  if BreakUpLargeNumbers then
    local ok, t = pcall(BreakUpLargeNumbers, d)
    if ok and type(t) == "string" then txt = t end
  end
  return L"  ·  |cff69ccf0descansada " .. txt .. L" XP|r"
end

local function Avisos()
  local l = {}
  local nombre, pct = PeorPieza()
  if nombre and pct < 0.25 then
    table.insert(l, { "equipo", C.AMARILLO .. nombre .. C.FIN .. L" al |cffff7070" .. math.floor(pct * 100) .. " %" .. C.FIN .. L": repara antes de salir." })
  end
  if cacheBolsas.libres and cacheBolsas.libres <= 2 then
    local txt = (cacheBolsas.libres == 1 and L"Solo te queda " or L"Solo te quedan ") .. C.AMARILLO .. cacheBolsas.libres .. (cacheBolsas.libres == 1 and L" hueco" or L" huecos") .. C.FIN .. L" en las bolsas."
    -- 7.5.15: hasta 4 sugerencias: grises, objetos de misión sobrantes y lo que menos vale
    local sug, todas = {}, {}
    for _, g in ipairs({ { cacheBolsas.grises, true }, { cacheBolsas.sobrantes, false }, { cacheBolsas.baratos, false } }) do
      for _, o in ipairs(g[1] or {}) do
        local t = TextoObjeto(o, g[2]) .. (g[1] == cacheBolsas.sobrantes and (C.GRIS .. L" (ya no lo usas)" .. C.FIN) or "")
        table.insert(todas, t)
        if #sug < 4 then table.insert(sug, t) end
      end
    end
    if #sug > 0 then txt = txt .. L" Puedes vender o tirar:\n" .. table.concat(sug, "  ·  ") end
    table.insert(l, { "bolsas", txt, #todas > 0 and table.concat(todas, "\n") or nil })
  end
  local mejora = cacheBolsas.mejora
  if mejora then
    table.insert(l, { "mejorabolsa", string.format(L"Revisa si puedes equipar %s: ganarías hasta %d huecos generales.", mejora.nombre, mejora.ganancia) })
  end
  local sob = cacheBolsas.sobrantes
  if sob and #sob > 0 then
    local nombres = {}
    for i = 1, math.min(#sob, 3) do nombres[i] = TextoObjeto({ n = sob[i].n, c = sob[i].c }) end
    local txt = L"Llevas " .. C.AMARILLO .. #sob .. (#sob == 1 and L" objeto de misión" or L" objetos de misión") .. C.FIN .. L" que ya no usas: " ..
      table.concat(nombres, ", ") .. (#sob > 3 and "..." or "") .. L". Puedes tirarlos."
    local todas = {}
    for i = 1, #sob do todas[i] = TextoObjeto({ n = sob[i].n, c = sob[i].c }) end
    table.insert(l, { "sobrantes", txt, table.concat(todas, "\n") })
  end
  -- 9.0: con poca comida lo dice «Antes de salir» al cambiar de zona; aquí solo si ya no te queda nada
  if cacheBolsas.comida and cacheBolsas.comida == 0 and Nivel() >= 5 then
    local mago = UnitClass and select(2, UnitClass("player")) == "MAGE"
    table.insert(l, { "comida", L"No te queda " .. C.AMARILLO .. L"comida ni bebida" .. C.FIN ..
      (mago and L": invoca más con Crear comida y Crear agua." or L": compra o invoca más.") })
  end
  -- 7.4: reactivos de la clase y munición del cazador
  local clase = UnitClass and select(2, UnitClass("player"))
  for _, r in ipairs(REACTIVOS[clase or ""] or {}) do
    local n = GetItemCount and GetItemCount(r.id) or nil
    if type(n) == "number" and Nivel() >= r.nivel and n <= r.min then
      local nombre = (GetItemInfo and GetItemInfo(r.id)) or r.n
      table.insert(l, { "reactivo" .. r.id, L"Te quedan " .. C.AMARILLO .. n .. " " .. nombre .. C.FIN .. L": compra más en el vendedor de reactivos." })
    end
  end
  if clase == "HUNTER" and Nivel() >= 10 and cacheBolsas.municion and cacheBolsas.municion < 200 then
    table.insert(l, { "municion", L"Te quedan " .. C.AMARILLO .. cacheBolsas.municion .. L" flechas o balas" .. C.FIN .. L": compra más antes de salir." })
  end
  -- 9.4: avisos de otros archivos: cada función devuelve { { clave, texto }, ... }
  for _, f in ipairs(GL.avisosExtra or {}) do
    local ok, r = pcall(f)
    if ok and type(r) == "table" then for _, a in ipairs(r) do table.insert(l, a) end end
  end
  -- 7.5.8: la piedra de hogar acaba de quedar lista
  if GL.EstadoHogar then
    local r = GL.EstadoHogar()
    if r and r > 0 then hogarEnUso = true; hogarLista = false
    elseif r == 0 and hogarEnUso then hogarEnUso = false; hogarLista = true end
    if hogarLista then table.insert(l, { "hogar", L"Tu " .. C.AMARILLO .. L"piedra de hogar" .. C.FIN .. L" ya está lista." }) end
  end
  -- 7.4: en una posada o ciudad, si aún cabe experiencia descansada
  if IsResting and IsResting() and Nivel() < 60 then
    local desc, max = GetXPExhaustion and GetXPExhaustion(), UnitXPMax and UnitXPMax("player")
    if type(max) == "number" and max > 0 and (desc or 0) < max * 1.5 then
      table.insert(l, { "posada", L"Estás en una posada o ciudad: si vas a desconectar, hazlo aquí y ganarás experiencia descansada." })
    end
  end
  -- un aviso descartado vuelve a salir cuando su motivo desaparece y vuelve
  local hay = {}
  for i = 1, #l do hay[l[i][1]] = true end
  for k in pairs(descartados) do if not hay[k] then descartados[k] = nil end end
  local r = {}
  for i = 1, #l do if not descartados[l[i][1]] then table.insert(r, l[i]) end end
  return r
end

local filasAviso = {}
-- 8.9.5: urgencia de cada aviso: 1 urgente (rojo), 2 útil (amarillo), 3 informativo (gris)
local URGENCIA = { mejorabolsa = 3, comida = 1, municion = 1, bolsas = 2, sobrantes = 2, hogar = 2, posada = 3 }
local COLORES_URGENCIA = {   -- 9.0: GL.COLORES_AVISO los cambia en el modo daltónico
  { fondo = { 1, 0.25, 0.25, 0.10 }, borde = { 1, 0.30, 0.30, 0.65 }, icono = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" },
  { fondo = { 1, 0.82, 0, 0.07 }, borde = { 1, 0.82, 0, 0.50 }, icono = "Interface\\GossipFrame\\AvailableQuestIcon" },
  { fondo = { 0.60, 0.62, 0.70, 0.07 }, borde = { 0.60, 0.62, 0.70, 0.40 }, icono = "Interface\\GossipFrame\\GossipGossipIcon" },
}
local function Urgencia(clave)
  if type(clave) ~= "string" then return 2 end
  if string.find(clave, "^reactivo") then return 1 end
  if clave == "bolsas" and cacheBolsas.libres == 0 then return 1 end
  return URGENCIA[clave] or 2
end
GL.ListaAvisos, GL.UrgenciaAviso, GL.BolsasCache = Avisos, Urgencia, function() return cacheBolsas end   -- 9.0: para Guia9.lua
GL.URGENCIA_AVISO = URGENCIA   -- 9.4: los avisos de otros archivos ponen aquí su urgencia
-- 9.0: píldoras. Cada aviso es una etiqueta corta; al pulsarla se abre debajo. Los urgentes salen abiertos.
local NOMBRE_PILDORA = { mejorabolsa = "Mejorar bolsa", equipo = "Reparar", bolsas = "Bolsas llenas", sobrantes = "Objetos de misión", comida = "Sin comida",
  municion = "Munición", hogar = "Piedra de hogar", posada = "Posada" }
GL.NOMBRE_PILDORA = NOMBRE_PILDORA   -- 9.4
local pildoras, abiertaPildora = {}, {}
local function Pildora(i, panel)
  local b = pildoras[i]
  if b then return b end
  b = CreateFrame("Button", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
  b:SetHeight(18)
  b.punto = b:CreateTexture(nil, "ARTWORK")
  b.punto:SetWidth(6); b.punto:SetHeight(6)
  b.punto:SetPoint("LEFT", b, "LEFT", 7, 0)
  b.texto = GL.Texto(b, "GameFontHighlightSmall")
  b.texto:SetPoint("LEFT", b.punto, "RIGHT", 5, 0)
  b:SetScript("OnClick", function(self)
    if self.clave then abiertaPildora[self.clave] = not self.abierta end
    if GL.Refrescar then GL.Refrescar() end
  end)
  if GL.Ayuda then GL.Ayuda(b) end
  pildoras[i] = b
  return b
end
local function NombrePildora(clave)
  if NOMBRE_PILDORA[clave] then return L(NOMBRE_PILDORA[clave]) end
  if type(clave) == "string" and string.find(clave, "^reactivo") then return L"Reactivos" end
  return L"Aviso"
end
local function TarjetaAvisos(panel, y, ancho)
  for i = 1, #filasAviso do filasAviso[i]:Hide() end
  for i = 1, #pildoras do pildoras[i]:Hide() end
  GL._numAvisosFilas, GL._avisosUrgentes = 0, 0
  if DB().avisos == false then return 0 end
  local todos = Avisos()
  local alto = 0
  GL._numAvisosFilas = #todos
  for i = 1, #todos do if Urgencia(todos[i][1]) == 1 then GL._avisosUrgentes = GL._avisosUrgentes + 1 end end
  local l = todos
  if DB().pildoras ~= false and #todos > 0 then
    l = {}
    local x, fila = 0, 0
    for i = 1, #todos do
      local clave, u = todos[i][1], Urgencia(todos[i][1])
      local abierta = abiertaPildora[clave]
      if abierta == nil then abierta = (u == 1) end
      local b = Pildora(i, panel)
      b.clave, b.abierta = clave, abierta
      local cu = (GL.COLORES_AVISO or COLORES_URGENCIA)[u] or COLORES_URGENCIA[2]
      local marca = (u == 1) and "! " or ""   -- 9.0: lo urgente no depende solo del color
      b.texto:SetText(marca .. NombrePildora(clave))
      local w = math.floor(((b.texto.GetStringWidth and tonumber(b.texto:GetStringWidth())) or 60) + 24)
      if x > 0 and x + w > ancho then x = 0; fila = fila + 1 end
      b:SetWidth(w)
      if GL.Caja then GL.Caja(b, abierta and { cu.borde[1], cu.borde[2], cu.borde[3], 0.20 } or { 1, 1, 1, 0.04 }, cu.borde) end
      b.punto:SetColorTexture(cu.borde[1], cu.borde[2], cu.borde[3], 1)
      b.ayudaTitulo = NombrePildora(clave)
      b.ayudaTexto = (abierta and L"Clic: cerrar." or L"Clic: ver el aviso.")
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -(y + fila * 22))
      b:Show()
      x = x + w + 4
      if abierta then table.insert(l, todos[i]) end
    end
    alto = (fila + 1) * 22
  end
  for i = 1, #l do
    local f = filasAviso[i]
    if not f then
      f = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
      f:SetHeight(24)
      if GL.Caja then GL.Caja(f, { 1, 0.47, 0.24, 0.08 }, { 1, 0.47, 0.24, 0.5 }) end
      f.icono = f:CreateTexture(nil, "ARTWORK")   -- 8.9.5
      f.icono:SetWidth(16); f.icono:SetHeight(16)
      f.icono:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4)
      f.texto = GL.Texto(f, "GameFontHighlightSmall")
      f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", 27, -6)
      if f.texto.SetJustifyH then f.texto:SetJustifyH("LEFT") end
      if GL.Ayuda then GL.Ayuda(f) end
      f.boton = GL.CrearBoton(f, L"Entendido", function()
        if f.clave then descartados[f.clave] = true end
        if GL.Refrescar then GL.Refrescar() end
      end, nil, 18)
      f.boton:SetWidth(76)
      f.boton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)
      f.texto:SetPoint("RIGHT", f.boton, "LEFT", -6, 0)
      filasAviso[i] = f
    end
    f.clave = l[i][1]
    f.texto:SetText(l[i][2])
    f.ayudaTitulo, f.ayudaTexto = l[i][3] and L"Lista completa" or nil, l[i][3]   -- 7.5.15
    local h = f.texto.GetStringHeight and tonumber(f.texto:GetStringHeight()) or nil
    local altoFila = math.max(24, (h or 12) + 12)
    f:SetHeight(altoFila)
    local cu = (GL.COLORES_AVISO or COLORES_URGENCIA)[Urgencia(f.clave)] or COLORES_URGENCIA[2]   -- 8.9.5: rojo urgente, amarillo útil, gris informativo
    if GL.Caja then GL.Caja(f, cu.fondo, cu.borde) end
    if GL.PonerIcono then GL.PonerIcono(f.icono, cu.icono, false) else f.icono:SetTexture(cu.icono) end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(y + alto))
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -(y + alto))
    f:Show()
    alto = alto + altoFila + 4
  end
  return alto > 0 and (alto - 4) or 0
end
-- 9.4.2: la pestaña Guía solo enseña la ruta, sus misiones y las opcionales; esta tarjeta ya no sale ahí
-- table.insert(GL.tarjetasGuia, TarjetaAvisos)   (los avisos salen en el centro de la pantalla, Guia9.lua)

------------------------------------------------------------------------
-- Vender lo gris (automatismo autoVender, apagado de serie)
------------------------------------------------------------------------
-- Una sola pasada por diálogo; no reintentar ventas rechazadas ni actuar fuera del vendedor.
local sesionVendedor, vendiendo, reparando
local function VentaPermitida(sesion)
  local db = DB()
  if sesion == nil or sesionVendedor ~= sesion or type(db) ~= "table" or db.autoVender ~= true then return false end
  -- R13: compartir el criterio conservador de combate de misiones y pesca.
  if type(GL.AccionProtegidaPermitidaR13) ~= "function" or not GL.AccionProtegidaPermitidaR13() then return false end
  if IsShiftKeyDown and IsShiftKeyDown() then return false end
  if MerchantFrame and MerchantFrame.IsShown and not MerchantFrame:IsShown() then return false end
  if not GetCursorInfo then return false end
  local ok, cursor = pcall(GetCursorInfo)
  return ok and cursor == nil
end

local function NoEsObjetoMision(b, s, id)
  if GL.WH and GL.WH.objetosMision and GL.WH.objetosMision[id] then return false end
  if C_Container and C_Container.GetContainerItemQuestInfo then
    local ok, info = pcall(C_Container.GetContainerItemQuestInfo, b, s)
    return ok and type(info) == "table" and not info.isQuestItem and (not info.questID or info.questID == 0) and not info.isActive
  elseif GetContainerItemQuestInfo then
    local ok, mision, idMision, activa = pcall(GetContainerItemQuestInfo, b, s)
    return ok and not mision and (not idMision or idMision == 0) and not activa
  end
  return false
end

local function PrecioBasura(b, s)
  local link, cuenta, calidad, sinValor, bloqueado = InfoHueco(b, s)
  if type(link) ~= "string" or calidad ~= 0 or sinValor or bloqueado or not GetItemInfo then return nil end
  local id = tonumber(link:match("item:(%d+)"))
  if not id or not NoEsObjetoMision(b, s, id) then return nil end
  local nombre, _, calidadReal, _, _, _, _, _, _, _, precio, clase, sub = GetItemInfo(link)
  -- Solo basura gris confirmada (clase Miscelánea, subclase Chatarra). Reservar equipo,
  -- materiales, objetos especiales y datos desconocidos para una decisión manual.
  if not nombre or calidadReal ~= 0 or clase ~= 15 or sub ~= 0 or type(precio) ~= "number"
    or not (precio > 0 and precio < math.huge and precio == math.floor(precio))
    or type(cuenta) ~= "number" or not (cuenta > 0 and cuenta < math.huge and cuenta == math.floor(cuenta))
    or precio * cuenta >= math.huge then return nil end
  return precio * cuenta, link, cuenta
end

local function VenderGris()
  local sesion = sesionVendedor
  if vendiendo or reparando or not sesion or sesion.procesada then return end
  sesion.procesada = true
  if not VentaPermitida(sesion) then return end
  local usar = (C_Container and C_Container.UseContainerItem) or UseContainerItem
  if type(usar) ~= "function" then return end
  vendiendo = true
  local n, total = 0, 0
  -- Liberar el bloqueo aunque falle una lectura de la API.
  pcall(function()
    -- R13: seleccionar antes de vender; un gestor de bolsas puede mover objetos
    -- durante UseContainerItem. No incorporar nuevos candidatos durante la pasada.
    local candidatos = {}
    for b = 0, (NUM_BAG_SLOTS or 4) do
      for s = 1, Huecos(b) do
        if not VentaPermitida(sesion) then return end
        local precio, link, cuenta = PrecioBasura(b, s)
        if precio then candidatos[#candidatos + 1] = { b = b, s = s, precio = precio, link = link, cuenta = cuenta } end
      end
    end
    for _, candidato in ipairs(candidatos) do
      if not VentaPermitida(sesion) then return end
      local b, s = candidato.b, candidato.s
      -- Revalidar también los datos de misión y el precio: pueden haber cambiado
      -- desde la selección inicial aunque el enlace y la cantidad coincidan.
      local precio, link, cuenta = PrecioBasura(b, s)
      if precio ~= candidato.precio or link ~= candidato.link or cuenta ~= candidato.cuenta then return end
      local actual, cantidad, calidad, sinValor, bloqueado = InfoHueco(b, s)
      if actual ~= link or cantidad ~= cuenta or calidad ~= 0 or sinValor or bloqueado then return end
      if not VentaPermitida(sesion) then return end
      local ok, resultado = pcall(usar, b, s)
      if not ok or resultado == false then return end
      n, total = n + 1, total + precio
    end
  end)
  vendiendo = false
  if n > 0 and GL.Mensaje then
    GL.Mensaje(L"Solicitudes de venta de basura: " .. n .. L". Valor estimado: " .. ((GL.Dinero and GL.Dinero(total)) or (total .. " c")) .. ".")
  end
end

-- Una solicitud de reparación por diálogo, con el oro personal y la reserva opcional.
local function ReparacionPermitida(sesion)
  local db = DB()
  if not sesion or sesionVendedor ~= sesion or type(db) ~= "table" or db.autoReparar == false then return false end
  -- R13: compartir el criterio conservador de combate de misiones y pesca.
  if type(GL.AccionProtegidaPermitidaR13) ~= "function" or not GL.AccionProtegidaPermitidaR13() then return false end
  if IsShiftKeyDown and IsShiftKeyDown() then return false end
  if MerchantFrame and MerchantFrame.IsShown and not MerchantFrame:IsShown() then return false end
  return true
end

local function CobreValido(n)
  return type(n) == "number" and n >= 0 and n < math.huge and n == math.floor(n)
end

local function Reparar()
  local sesion = sesionVendedor
  if reparando or vendiendo or not sesion or sesion.reparacionProcesada then return end
  sesion.reparacionProcesada = true
  reparando = true
  pcall(function()
    if not ReparacionPermitida(sesion) then return end
    if type(CanMerchantRepair) ~= "function" or type(GetRepairAllCost) ~= "function"
      or type(RepairAllItems) ~= "function" or type(GetMoney) ~= "function" or not CanMerchantRepair() then return end
    local coste, puede = GetRepairAllCost()
    if not CobreValido(coste) or coste == 0 or puede ~= true then return end
    local saldo = GetMoney()
    if not CobreValido(saldo) then return end
    local dinero = function(c) return (GL.Dinero and GL.Dinero(c)) or (c .. " c") end
    if saldo < coste then
      if GL.Mensaje then GL.Mensaje(L"|cffff7070no tienes oro para reparar todo|r (cuesta " .. dinero(coste) .. ").") end
      return
    end
    local reserva = 0
    if DB().reservaOro == true then
      if type(GL.ReservaOro) ~= "function" then return end
      reserva = GL.ReservaOro(true)
      if not CobreValido(reserva) then return end
    end
    if saldo - coste < reserva then
      if GL.Mensaje then GL.Mensaje(L"Reparación automática omitida para conservar la reserva de oro. Puedes reparar manualmente.") end
      return
    end
    -- Si los datos o preferencias cambian durante la lectura, no gastar con una cotización obsoleta.
    local nuevoCoste, nuevoPuede = GetRepairAllCost()
    if nuevoCoste ~= coste or nuevoPuede ~= true or GetMoney() ~= saldo or not CanMerchantRepair()
      or not ReparacionPermitida(sesion) then return end
    if DB().reservaOro == true then
      if type(GL.ReservaOro) ~= "function" or GL.ReservaOro(true) ~= reserva then return end
    end
    if not ReparacionPermitida(sesion) then return end
    local ok, resultado = pcall(RepairAllItems, false)
    if ok and resultado ~= false and GL.Mensaje then
      GL.Mensaje(L"Reparación solicitada. Coste estimado: " .. dinero(coste) .. ".")
    end
  end)
  reparando = false
end

------------------------------------------------------------------------
-- Modo grupo: cada uno manda su paso y sus misiones del diario por mensajes de addon
------------------------------------------------------------------------
local PREFIJO = "GuiaAventurero"
local companeros = {}             -- nombre -> { s, p, zona, qs = { [id] = true }, t }
local ultimoEnvio, ultimoTexto = 0, nil

local function EnGrupo() return (IsInGroup and IsInGroup()) or (GetNumGroupMembers and (GetNumGroupMembers() or 0) > 0) end

local function MisMisiones()
  local ids = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    local n = Num(C_QuestLog.GetNumQuestLogEntries()) or 0
    for i = 1, n do
      local info = C_QuestLog.GetInfo(i)
      if type(info) == "table" and not info.isHeader and info.questID then table.insert(ids, { id = info.questID, n = info.title }) end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    local n = GetNumQuestLogEntries() or 0
    for i = 1, n do
      local titulo, _, _, cabecera, _, _, _, id = GetQuestLogTitle(i)
      if not cabecera and id then table.insert(ids, { id = id, n = titulo }) end
    end
  end
  return ids
end

local function Enviar(forzar)
  local db = DB()
  if type(db) ~= "table" or db.grupo == false or not EnGrupo() or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  local qs = {}
  local mias = MisMisiones()
  for i = 1, math.min(#mias, 25) do table.insert(qs, mias[i].id) end
  local texto = "P|" .. (db.seccion or 0) .. "|" .. (db.paso or 0) .. "|" .. ((GetZoneText and GetZoneText()) or "") .. "|" .. table.concat(qs, ",")
  if not forzar and texto == ultimoTexto and Ahora() - ultimoEnvio < 60 then return end
  ultimoTexto, ultimoEnvio = texto, Ahora()
  local canal = (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
  pcall(C_ChatInfo.SendAddonMessage, PREFIJO, texto:sub(1, 250), canal)
end

local function Recibir(prefijo, texto, _, quien)
  if prefijo ~= PREFIJO or type(texto) ~= "string" or not quien then return end
  local nombre = quien:match("^([^%-]+)") or quien
  if UnitName and nombre == UnitName("player") then return end
  local tipo, s, p, zona, lista = texto:match("^(%a)|(%d+)|(%d+)|([^|]*)|(.*)$")
  if tipo ~= "P" then return end
  local qs = {}
  for id in (lista or ""):gmatch("%d+") do qs[tonumber(id)] = true end
  companeros[nombre] = { s = tonumber(s), p = tonumber(p), zona = zona, qs = qs, t = Ahora() }
  if GL.Refrescar then GL.Refrescar() end
end

GL.Companeros, GL.MisMisionesGrupo, GL.EnGrupo = function() return companeros end, MisMisiones, EnGrupo   -- 9.0: icono Grupo
GL.EnviarGrupo = function() pcall(Enviar, true) end
local cajaGrupo = nil
local function TarjetaGrupo(panel, y, ancho)
  if cajaGrupo then cajaGrupo:Hide() end
  local db = DB()
  if db.grupo == false or not EnGrupo() then return 0 end
  local lineas = { L"|cff69ccf0Grupo|r " .. C.GRIS .. L"(con la guía)" .. C.FIN }
  local mias = MisMisiones()
  local hay = false
  for nombre, c in pairs(companeros) do
    if Ahora() - c.t < 180 then
      hay = true
      local rel = ""
      if c.s == db.seccion then
        local d = (db.paso or 0) - (c.p or 0)
        if d > 0 then rel = C.GRIS .. " (" .. d .. L" pasos detrás)" .. C.FIN
        elseif d < 0 then rel = C.GRIS .. " (" .. (-d) .. L" pasos delante)" .. C.FIN
        else rel = C.VERDE .. L" (en tu paso)" .. C.FIN end
      elseif c.s then
        rel = C.GRIS .. L" (sección " .. c.s .. ")" .. C.FIN
      end
      table.insert(lineas, "• " .. C.BLANCO .. nombre .. C.FIN .. L": paso " .. (c.p or "?") .. ", " .. (c.zona ~= "" and c.zona or "?") .. rel)
      local comp = {}
      for i = 1, #mias do
        if not c.qs[mias[i].id] and #comp < 3 then table.insert(comp, C.AMARILLO .. "[" .. (mias[i].n or mias[i].id) .. "]" .. C.FIN) end
      end
      if #comp > 0 then table.insert(lineas, L"   Le puedes compartir: " .. table.concat(comp, ", ")) end
    end
  end
  if not hay then return 0 end
  if not cajaGrupo then
    cajaGrupo = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if GL.Caja then GL.Caja(cajaGrupo, { 0.41, 0.8, 0.94, 0.07 }, { 0.41, 0.8, 0.94, 0.45 }) end
    cajaGrupo.texto = GL.Texto(cajaGrupo, "GameFontHighlightSmall")
    cajaGrupo.texto:SetPoint("TOPLEFT", cajaGrupo, "TOPLEFT", 8, -6)
  end
  local texto = table.concat(lineas, "\n")
  cajaGrupo.texto:SetWidth(ancho - 18)
  cajaGrupo.texto:SetText(texto)
  local alto = 12 + #lineas * 13
  if cajaGrupo.texto.GetStringHeight then
    local h = cajaGrupo.texto:GetStringHeight()
    if type(h) == "number" and h > 0 then alto = h + 12 end
  end
  cajaGrupo:ClearAllPoints()
  cajaGrupo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  cajaGrupo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  cajaGrupo:SetHeight(alto)
  cajaGrupo:Show()
  return alto
end
-- 9.4.2: la pestaña Guía solo enseña la ruta, sus misiones y las opcionales; esta tarjeta ya no sale ahí
-- table.insert(GL.tarjetasGuia, TarjetaGrupo)   (está en el botón Grupo)

------------------------------------------------------------------------
-- Personaje > Estadísticas
------------------------------------------------------------------------
------------------------------------------------------------------------
-- 7.5.1: ahorro para el nivel 40 (equitación, montura y doble especialización)
------------------------------------------------------------------------
local function Precios()
  local c = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.precios
  if type(c) ~= "table" then c = {} end
  local function Precio(v, defecto)
    v = tonumber(v)
    return (v and v >= 0 and v < math.huge) and v or defecto
  end
  return { equitacion = Precio(c.equitacion, 100), montura = Precio(c.montura, 0), doble = Precio(c.doble, 10) }   -- 7.9.3: Forever, Equitación 100 o con la primera montura
end
GL.PreciosAhorro = Precios

local function Ahorro(mostrarTodas)
  local nivel = Nivel()
  if DB().ahorro == false and not mostrarTodas then return nil end   -- 7.9.3: desde el nivel 1
  local clase = UnitClass and select(2, UnitClass("player"))
  local pr = Precios()
  local metas = {}
  local montura = not (clase == "PALADIN" or clase == "WARLOCK")   -- su montura (y la equitación) la da su misión de clase
  local yaMonta = {}   -- lo que ya tienes no cuenta: equitación (y con ella la montura) y la segunda especialización
  for _, h in ipairs((GL.Habilidades and GL.Habilidades()) or {}) do
    if h.id == 762 or h.n == "Equitación" or h.n == "Riding" then yaMonta.equitacion, yaMonta.montura = true, true end
  end
  if GetNumTalentGroups then
    local ok, n = pcall(GetNumTalentGroups)
    if ok and type(n) == "number" and n >= 2 then yaMonta.doble = true end
  end
  if montura then
    table.insert(metas, { k = "equitacion", n = L"Equitación", o = pr.equitacion })
    if pr.montura > 0 then table.insert(metas, { k = "montura", n = L"Montura", o = pr.montura }) end   -- 0: viene con Equitación
  end
  table.insert(metas, { k = "doble", n = L"Doble especialización", o = pr.doble })
  local oro = ((GetMoney and Num(GetMoney())) or 0) / 10000
  local falta, quedan = 0, 0
  for _, m in ipairs(metas) do
    if yaMonta[m.k] then m.hecho = true; m.tengo = m.o
    else
      m.tengo = math.min(m.o, math.max(0, oro)); oro = oro - m.o
      falta = falta + (m.o - m.tengo); quedan = quedan + 1
    end
  end
  if quedan == 0 and not mostrarTodas then return nil end
  return metas, falta
end
GL.MetasAhorro = Ahorro   -- 9.1: la reserva de oro de las compras automáticas (Reserva.lua)

local tarjetaAhorro = nil
local function TarjetaAhorro(panel, y, ancho)
  if tarjetaAhorro then tarjetaAhorro:Hide() end
  local metas, falta = Ahorro()
  if not metas then return 0 end
  local f = tarjetaAhorro
  if not f then
    f = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if GL.Caja then GL.Caja(f, { 1, 0.82, 0, 0.06 }, { 1, 0.82, 0, 0.45 }) end
    f.titulo = GL.Texto(f, "GameFontHighlightSmall")
    f.titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
    f.falta = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.falta:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    f.filas = {}
    for i = 1, 3 do
      local r = {}
      r.n = GL.Texto(f, "GameFontHighlightSmall")
      r.n:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8 - i * 16)
      r.n:SetWidth(140)
      r.barra = GL.CrearBarra(f, 1, 0.82, 0)
      r.barra:SetHeight(9)
      r.barra:SetPoint("LEFT", f, "TOPLEFT", 152, -15 - i * 16)
      r.barra:SetPoint("RIGHT", f, "TOPRIGHT", -84, -15 - i * 16)
      r.v = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
      r.v:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8 - i * 16)
      f.filas[i] = r
    end
    -- 9.0: los precios ya no están en Ajustes › Avisos; este botón lleva a Ajustes › Datos
    if GL.CrearBoton then
      f.precios = GL.CrearBoton(f, L"Cambiar precios", function()
        GuiaAventureroDB.pestanaAjustes = "datos"
        if GL.AbrirModo then GL.AbrirModo("opciones") end
      end, nil, 16)
      f.precios:SetWidth(104)
      f.precios:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 5)
    end
    tarjetaAhorro = f
  end
  f.titulo:SetText(C.GRIS .. L"AHORRO PARA EL NIVEL 40" .. C.FIN)
  f.falta:SetText(C.GRIS .. L"te faltan " .. C.FIN .. C.AMARILLO .. math.ceil(falta) .. " o" .. C.FIN)
  for i = 1, 3 do
    local r, m = f.filas[i], metas[i]
    if m then
      r.n:SetText(m.n); r.n:Show()
      r.barra:SetMinMaxValues(0, math.max(1, m.o)); r.barra:SetValue(m.tengo); r.barra:Show()
      r.v:SetText((m.tengo >= m.o) and (C.VERDE .. m.o .. " o " .. GL.Icono("✓") .. C.FIN) or (math.floor(m.tengo) .. " / " .. m.o .. " o")); r.v:Show()
    else
      r.n:Hide(); r.barra:Hide(); r.v:Hide()
    end
  end
  local alto = 14 + #metas * 16 + 10 + (f.precios and 18 or 0)
  f:SetHeight(alto)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  f:Show()
  return alto
end
-- 9.4.2: la pestaña Guía solo enseña la ruta, sus misiones y las opcionales; esta tarjeta ya no sale ahí
-- table.insert(GL.tarjetasGuia, TarjetaAhorro)   (está en Oro › Ahorro)

------------------------------------------------------------------------
-- 7.5.7: tiempo medio por paso y tiempo estimado para acabar la sección
------------------------------------------------------------------------
local pasoClave, pasoDesde = nil, nil
local function MirarPaso()
  local db = DB()
  local clave = db.seccion .. ":" .. db.paso
  if pasoClave and clave ~= pasoClave and pasoDesde then
    local dt = Ahora() - pasoDesde
    local e = Estad()
    if e and dt >= 10 and dt <= 1800 then
      e.pasos = e.pasos or { n = 0, t = 0 }
      e.pasos.n, e.pasos.t = e.pasos.n + 1, e.pasos.t + dt
    end
  end
  if clave ~= pasoClave then pasoClave, pasoDesde = clave, Ahora() end
end

GL.TextoTiempoSeccion = function()
  local e = Estad()
  if not (e and e.pasos and e.pasos.n >= 5 and GL.RUTA and GL.EstadoPaso) then return nil end
  local db = DB()
  local sec = GL.RUTA.secciones[db.seccion]
  if not sec then return nil end
  local quedan = 0
  for i = db.paso, #sec.pasos do
    local ok, est = pcall(GL.EstadoPaso, sec.pasos[i])
    if not (ok and est == "hecho") then quedan = quedan + 1 end
  end
  if quedan == 0 and not mostrarTodas then return nil end
  return L"sección: " .. quedan .. (quedan == 1 and L" paso" or L" pasos") .. L", unos " .. Duracion(quedan * e.pasos.t / e.pasos.n)
end

------------------------------------------------------------------------
-- 7.5.6 y 7.5.9: resumen de la sesión y compartirlo en el chat
------------------------------------------------------------------------
local sesion = nil   -- { t0 = GetTime, oro0, q }
local function Sesion()
  if not sesion then return nil end
  local oro = (GetMoney and Num(GetMoney())) or sesion.oro0
  return { t = Ahora() - sesion.t0, xp = ganado, oro = oro - sesion.oro0, q = sesion.q }
end
GL.SesionActual = Sesion

local function Dinero(c)
  local signo = c < 0 and "-" or "+"
  return signo .. ((GL.Dinero and GL.Dinero(math.abs(c))) or tostring(math.abs(c)))
end

GL.DineroConSigno = Dinero   -- 9.0: Cuenta › Hoy

local function TextoCompartir()
  local e = Estad()
  local t, xp = 0, 0
  for _, d in pairs((e and e.niveles) or {}) do t, xp = t + d.t, xp + d.xp end
  local txt = L"Guía del Aventurero: nivel " .. Nivel() .. L" en " .. Duracion(t)
  if t >= 60 then txt = txt .. " (" .. Miles(xp / t * 3600) .. L" XP/h)" end
  local se = Sesion()
  if se and se.t >= 60 then
    txt = txt .. L". Esta sesión: " .. Duracion(se.t) .. ", " .. Miles(se.xp) .. L" XP y " .. se.q .. (se.q == 1 and L" misión" or L" misiones")
  end
  return txt .. "."
end

GL.Compartir = function()
  local txt = TextoCompartir()
  local canal = nil
  if IsInGroup and IsInGroup() then canal = "PARTY" elseif IsInGuild and IsInGuild() then canal = "GUILD" end
  if canal and SendChatMessage then SendChatMessage(txt, canal)
  elseif GL.Mensaje then GL.Mensaje(L"no estás en grupo ni en hermandad. " .. txt) end
end
GL.comandos["compartir"] = function() GL.Compartir() end

local panel, ui = nil, { filas = {} }
local desde = 0
local FILAS = 6

local function RefrescarEstad()
  if not panel or not panel:IsShown() then return end
  local e = Estad()
  if not e then return end
  local t, q, xp, lista = 0, 0, 0, {}
  for n, d in pairs(e.niveles) do
    t, q, xp = t + d.t, q + d.q, xp + d.xp
    table.insert(lista, n)
  end
  table.sort(lista, function(a, b) return a > b end)
  ui.tiempo:SetText(Duracion(t))
  ui.misiones:SetText(tostring(q))
  ui.ritmo:SetText(t >= 60 and (C.VERDE .. Miles(xp / t * 3600) .. L" XP/h" .. C.FIN) or C.GRIS .. "—" .. C.FIN)
  ui.muertes:SetText(tostring(e.muertes or 0))
  local se = Sesion()   -- 7.5.6
  if se and ui.sTiempo then
    ui.sTiempo:SetText(Duracion(se.t))
    ui.sXP:SetText(Miles(se.xp) .. " XP" .. (se.t >= 60 and (C.GRIS .. " (" .. Miles(se.xp / se.t * 3600) .. "/h)" .. C.FIN) or ""))
    ui.sOro:SetText((se.oro >= 0 and C.VERDE or "|cffff7070") .. Dinero(se.oro) .. C.FIN)
    ui.sMis:SetText(tostring(se.q))
  end
  local an = DB().sesionAnterior
  if ui.sAnt then ui.sAnt:SetText(an and (C.GRIS .. L"Sesión anterior" .. (date and an.fin and (" (" .. date("%d/%m", an.fin) .. ")") or "") .. ": " ..
    Duracion(an.t) .. ", " .. Miles(an.xp) .. L" XP, " .. Dinero(an.oro) .. ", " .. an.q .. L" misiones" .. C.FIN) or "") end
  desde = math.max(0, math.min(desde, #lista - FILAS))
  local actual = Nivel()
  for i = 1, FILAS do
    local f, n = ui.filas[i], lista[desde + i]
    if n then
      local d = e.niveles[n]
      f.c[1]:SetText(tostring(n))
      f.c[2]:SetText(n == actual and (C.AMARILLO .. L"en curso" .. C.FIN) or Duracion(d.t))
      f.c[3]:SetText(tostring(d.q))
      f.c[4]:SetText(d.t >= 60 and Miles(d.xp / d.t * 3600) or "—")
      f:Show()
    else
      f:Hide()
    end
  end
  ui.mas:SetText(C.GRIS .. (#lista > FILAS and (L"Niveles " .. (desde + 1) .. "-" .. math.min(#lista, desde + FILAS) .. L" de " .. #lista .. L" (rueda del ratón).") or "") ..
    C.FIN)   -- 9.4.2: sin «Cuenta desde la versión 6.9.»
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + GL.ALTO_SUB))
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  local function Seccion(texto, y)
    local t = GL.Texto(panel, "GameFontNormal")
    t:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    t:SetText(texto)
  end
  local function Par(texto, y)
    local k = GL.Texto(panel, "GameFontHighlightSmall")
    k:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    k:SetText(texto)
    local v = GL.Texto(panel, "GameFontHighlightSmall", "RIGHT")
    v:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y)
    return v
  end
  Seccion(L"Resumen", -4)
  ui.tiempo = Par(L"Tiempo jugado", -24)
  ui.misiones = Par(L"Misiones entregadas", -40)
  ui.ritmo = Par(L"Ritmo medio", -56)
  ui.muertes = Par(L"Muertes", -72)
  -- 7.5.6: esta sesión y la anterior; 7.5.9: compartir en el chat. 9.0: van a Cuenta › Hoy (Hoy9.lua)
  local enHoy = GL.PintarHoy ~= nil
  if not enHoy then
  Seccion(L"Esta sesión", -96)
  ui.sTiempo = Par(L"Tiempo", -116)
  ui.sXP = Par(L"Experiencia", -132)
  ui.sOro = Par(L"Oro", -148)
  ui.sMis = Par(L"Misiones", -164)
  ui.sAnt = GL.Texto(panel, "GameFontHighlightSmall")
  ui.sAnt:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -182)
  ui.sAnt:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -182); GL.UnaLinea(ui.sAnt)   -- 7.6.1: dentro del marco
  ui.compartir = GL.CrearBoton(panel, L"Compartir en el chat", function() GL.Compartir() end, nil, 20, "accion")
  ui.compartir:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -200)
  ui.compartir:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -200)
  GL.Ayuda(ui.compartir, L"Compartir en el chat", L"Pone tu nivel, tiempo y ritmo en el chat de grupo (o de hermandad si no estás en grupo).")
  end
  local B = enHoy and 0 or 128   -- lo que baja la tabla por la sesión
  Seccion(L"Por nivel", -96 - B)
  local cab = { L"Nivel", L"Tiempo", L"Misiones", L"XP/h" }
  local X = { 0, 0.30, 0.62, 1 }
  local function Fila(y, textos)
    local f = CreateFrame("Frame", nil, panel)
    f:SetHeight(16)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y)
    f.c = {}
    for i = 1, 4 do
      local t = GL.Texto(f, "GameFontHighlightSmall", i == 1 and "LEFT" or "RIGHT")
      if i == 1 then t:SetPoint("LEFT", f, "LEFT", 4, 0) else t:SetPoint("RIGHT", f, "LEFT", 0, 0) end
      f.c[i] = t
      if textos then t:SetText(C.GRIS .. textos[i] .. C.FIN) end
    end
    f:SetScript("OnSizeChanged", function(self, w)
      for i = 2, 4 do self.c[i]:ClearAllPoints(); self.c[i]:SetPoint("RIGHT", self, "LEFT", (w or 300) * X[i] - 4, 0) end
    end)
    return f
  end
  Fila(-116 - B, cab)
  for i = 1, FILAS do ui.filas[i] = Fila(-132 - B - (i - 1) * 16) end
  ui.mas = GL.Texto(panel, "GameFontHighlightSmall")
  ui.mas:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -136 - B - FILAS * 16)
  ui.mas:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -136 - B - FILAS * 16); GL.UnaLinea(ui.mas)   -- 7.6.1: dentro del marco
  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta) desde = math.max(0, desde - delta); RefrescarEstad() end)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt) espera = espera + dt; if espera >= 1 then espera = 0; RefrescarEstad() end end)
  GL.modos.estadisticas = { panel = panel, refrescar = RefrescarEstad }
end
table.insert(GL.alIniciar, CrearPanel)

------------------------------------------------------------------------
-- Eventos y reloj
------------------------------------------------------------------------
-- R12: agrupar ráfagas del diario y del inventario sin perder la última lectura.
local bolsasPendientesR12, fueraMundoR14
local function ProgramarBolsasR12()
  if bolsasPendientesR12 or fueraMundoR14 then return end
  local token = {}
  bolsasPendientesR12 = token
  local function Hacer()
    if bolsasPendientesR12 ~= token or fueraMundoR14 then return end
    bolsasPendientesR12 = nil
    if type(DB()) ~= "table" then return end
    pcall(LeerBolsas)
    if GL.ProgramarRefresco then GL.ProgramarRefresco() end
  end
  if C_Timer and type(C_Timer.After) == "function" then
    local ok, resultado = pcall(C_Timer.After, 0.05, Hacer)
    if not ok or resultado == false then Hacer() end
  else Hacer() end
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "BAG_UPDATE_DELAYED", "BAG_UPDATE")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "PLAYER_DEAD",
  "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "MERCHANT_SHOW", "MERCHANT_CLOSED", "GROUP_ROSTER_UPDATE", "CHAT_MSG_ADDON", "UPDATE_INVENTORY_DURABILITY", "PLAYER_LOGOUT", "QUEST_LOG_UPDATE" }) do
  GL.Evento(eventos, e)
end
eventos:SetScript("OnEvent", function(_, evento, ...)
  if evento == "MERCHANT_CLOSED" then sesionVendedor = nil; return end
  if evento == "PLAYER_LEAVING_WORLD" or evento == "PLAYER_LOGOUT" then
    sesionVendedor, bolsasPendientesR12, fueraMundoR14 = nil, nil, true
    if evento == "PLAYER_LEAVING_WORLD" then return end
  elseif evento == "PLAYER_ENTERING_WORLD" then
    sesionVendedor, bolsasPendientesR12, fueraMundoR14 = nil, nil, false
    ProgramarBolsasR12(); return
  elseif fueraMundoR14 then return end
  if type(DB()) ~= "table" then return end
  if evento == "PLAYER_LOGIN" then
    inicio = Ahora()
    sesion = { t0 = Ahora(), oro0 = (GetMoney and Num(GetMoney())) or 0, q = 0 }   -- 7.5.6
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIJO) end
    pcall(LeerXP); pcall(LeerBolsas); Enviar(true)
  elseif evento == "PLAYER_XP_UPDATE" or evento == "PLAYER_LEVEL_UP" then
    pcall(LeerXP)
  elseif evento == "QUEST_TURNED_IN" then
    local n = DelNivel(Nivel()); if n then n.q = n.q + 1 end
    if sesion then sesion.q = sesion.q + 1 end
    Enviar(true)
  elseif evento == "PLAYER_DEAD" then
    local e = Estad(); if e then e.muertes = (e.muertes or 0) + 1 end
  elseif evento == "BAG_UPDATE_DELAYED" or evento == "BAG_UPDATE" then
    ProgramarBolsasR12(); return
  elseif evento == "MERCHANT_SHOW" then
    if not sesionVendedor then sesionVendedor = {} end
    local sesion = sesionVendedor
    if reparando or vendiendo then return end
    pcall(Reparar)
    if sesionVendedor == sesion then pcall(VenderGris) end
  elseif evento == "QUEST_LOG_UPDATE" then
    ProgramarBolsasR12(); return
  elseif evento == "GROUP_ROSTER_UPDATE" then
    if not EnGrupo() then companeros = {} end
    Enviar(true)
  elseif evento == "PLAYER_LOGOUT" then   -- 7.5.6: guarda la sesión para verla la próxima vez
    local se = Sesion()
    if se and se.t >= 60 then
      DB().sesionAnterior = { fin = time and time() or nil, t = se.t, xp = se.xp, oro = se.oro, q = se.q }
    end
    return
  elseif evento == "CHAT_MSG_ADDON" then
    Recibir(...)
    return
  end
  if GL.ProgramarRefresco then GL.ProgramarRefresco() end
end)

-- cada segundo suma tiempo al nivel actual; cada 20 s manda el paso al grupo si ha cambiado
local acumulado, envio = 0, 0
eventos:SetScript("OnUpdate", function(_, dt)
  if fueraMundoR14 then acumulado, envio = 0, 0; return end
  acumulado, envio = acumulado + dt, envio + dt
  if acumulado >= 1 then
    local n = type(DB()) == "table" and DelNivel(Nivel())
    if n then n.t = n.t + acumulado end
    acumulado = 0
    if type(DB()) == "table" and DB().seccion then pcall(MirarPaso) end   -- 7.5.7
  end
  if envio >= 20 then envio = 0; Enviar(false) end
end)

-- Para las pruebas
GL._mejoras = { LeerXP = LeerXP, Avisos = Avisos, LeerBolsas = LeerBolsas, VenderGris = VenderGris, Reparar = Reparar, Recibir = Recibir,
  TarjetaGrupo = TarjetaGrupo, TarjetaAvisos = TarjetaAvisos, Estad = Estad, cache = cacheBolsas, ritmo = function() inicio = Ahora() - 600 end,
  TarjetaAhorro = TarjetaAhorro, Ahorro = Ahorro, TextoCompartir = TextoCompartir, sesion = function() sesion = { t0 = Ahora() - 3600, oro0 = 0, q = 3 } end }

-- Hechizos.lua: lista de los hechizos de tu clase con el nivel al que se aprenden y lo que cuestan, con filtro por
-- especialización. Lo que hace cada uno sale al pasar el ratón por su icono (la ventana del hechizo del juego).
-- Creado por JKRiveroF.
-- Datos de la ruta: R.entrenamiento (instructor de Forever), R.hechizosExtra (los del principio, los de talento y
-- los de misión), R.ramaHechizo (rama de cada hechizo por su primer rango) y R.especialidades (botones del filtro).
-- El nombre, el rango, el icono y la ventana del hechizo los da el juego, en el idioma del cliente.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local ROJO = "|cffff7060"
local TODAS = L"Todas"
local LADO_ICONO = 30
local ICONO_PESTANA = "Interface\\Icons\\INV_Misc_Book_09"
local ANCHO_SOLO = 150                -- botón "Solo lo disponible"

local panel, scroll, hijo, barra, resumen, botonSolo, botonIr
local filtros = {}                    -- botones del filtro por especialización
local filas = {}                      -- filas de la lista, se reutilizan
local cabeceras = {}                  -- 9.6: «Para aprender ya» y «Más adelante»
local rutaGrupos
local grupos                          -- hechizos agrupados por cadena de rangos
local indice = {}                     -- cada hechizo de la lista por su id
local pedidos = {}                    -- hechizos cuyo nombre se ha pedido al juego
local refrescoPendiente = false

local function DB() return GuiaAventureroDB end

------------------------------------------------------------------------
-- Datos: cada hechizo con todos sus rangos
------------------------------------------------------------------------
local function Armar()
  grupos = {}
  rutaGrupos = GL.RUTA
  local R = GL.RUTA
  if not R then return end
  local todas, porId = {}, {}
  for _, e in ipairs(R.entrenamiento or {}) do
    local f = { id = e.id, n = e.n, coste = e.coste or 0, req = e.req, ant = e.ant, origen = "instructor",
      donde = GL.DondeHechizo and GL.DondeHechizo(e.id), hab = e.hab }
    table.insert(todas, f)
    porId[e.id] = f
  end
  for _, e in ipairs(R.hechizosExtra or {}) do
    if not porId[e.id] then
      local f = { id = e.id, n = e.n, coste = 0, req = e.req, ant = e.ant, origen = e.origen, plan = e.plan,
        mision = e.mision, misionNombre = e.misionNombre }
      table.insert(todas, f)
      porId[e.id] = f
    end
  end
  indice = porId
  -- lo que pide además del rango anterior (una actitud, por ejemplo): solo se sabe si la ruta trae ant
  for _, f in ipairs(todas) do
    if f.ant ~= nil and f.req then
      for _, r in ipairs(f.req) do
        if r ~= f.ant then f.necesita = f.necesita or {}; table.insert(f.necesita, r) end
      end
    end
  end
  -- el rango anterior: ant si la ruta lo trae (0 = primer rango; así una actitud que se pide no cuenta como
  -- rango) y si no, el requisito que también está en la lista (el otro, si lo hay, es un talento)
  local function Previo(f)
    if f.ant ~= nil then
      if f.ant == 0 then return nil end
      local p = porId[f.ant]
      if p and p ~= f then return p end
      return nil
    end
    for _, r in ipairs(f.req or {}) do
      if porId[r] and porId[r] ~= f then return porId[r] end
    end
    return nil
  end
  local function Profundidad(f)
    if f.prof then return f.prof end
    local p, n = Previo(f), 0
    while p and n < 40 do n = n + 1; p = Previo(p) end
    f.prof = n
    return n
  end
  local porRaiz = {}
  for _, f in ipairs(todas) do
    local r, n = f, 0
    while Previo(r) and n < 40 do r = Previo(r); n = n + 1 end
    local g = porRaiz[r.id]
    if not g then
      local ramas = R.ramaHechizo and R.ramaHechizo[r.id]
      if type(ramas) == "string" then ramas = { ramas } end
      g = { raiz = r.id, rangos = {}, ramas = ramas or {} }
      porRaiz[r.id] = g
      table.insert(grupos, g)
    end
    table.insert(g.rangos, f)
  end
  for _, g in ipairs(grupos) do
    table.sort(g.rangos, function(a, b)
      local pa, pb = Profundidad(a), Profundidad(b)
      if pa ~= pb then return pa < pb end
      return a.id < b.id
    end)
    for _, f in ipairs(g.rangos) do
      if f.n and (not g.orden or f.n < g.orden) then g.orden = f.n end
    end
    g.orden = g.orden or 60
  end
  table.sort(grupos, function(a, b)
    if a.orden ~= b.orden then return a.orden < b.orden end
    return a.raiz < b.raiz
  end)
end

local function Nombre(id)
  local n = GL.NombreHechizo and GL.NombreHechizo(id)
  if n then return n end
  if C_Spell and C_Spell.RequestLoadSpellData and not pedidos[id] then
    pedidos[id] = true
    pcall(C_Spell.RequestLoadSpellData, id)
  end
  return L"Hechizo " .. id
end

local function Icono(id)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, id)
    if ok and t then return t end
  end
  return nil
end

local function Dinero(cobre)
  if GL.Dinero then return GL.Dinero(cobre) end
  return string.format("%.2f o", (cobre or 0) / 10000)
end

-- Lo que pide el primer rango y aún no tienes (la actitud de una misión de clase, por ejemplo).
local function Falta(f)
  for _, r in ipairs(f.necesita or {}) do
    if not GL.HechizoConocido(r) then return true end
  end
  return false
end

-- true si tienes el nivel de habilidad que pide el rango (los venenos piden un nivel de Venenos).
local function HabilidadLista(f)
  if not f.hab then return true end
  local n = GL.NivelHabilidad and GL.NivelHabilidad(f.hab[1])
  return n ~= nil and n >= (f.hab[2] or 0)
end

-- Estado de cada rango para tu nivel: aprendido, disponible, futuro o bloqueado (falta el talento que lo enseña,
-- lo que pide el primer rango o el nivel de habilidad).
local function Estados(g, nivel)
  local est = {}
  local conocido = false
  for i = #g.rangos, 1, -1 do
    -- si tienes un rango, los anteriores también cuentan como aprendidos
    if conocido or GL.HechizoConocido(g.rangos[i].id) or
       (GL.ConocidoFuera and GL.ConocidoFuera(g.rangos[i].id)) then conocido = true; est[i] = "aprendido" end
  end
  local primero = g.rangos[1]
  local sinTalento = primero.origen == "talento" and est[1] ~= "aprendido"
  local falta = est[1] ~= "aprendido" and (Falta(primero) or primero.origen == "mision")
  for i, f in ipairs(g.rangos) do
    if not est[i] then
      if not f.n or f.n > nivel then est[i] = "futuro"
      elseif sinTalento or falta or f.origen ~= "instructor" or Falta(f) then est[i] = "bloqueado"
      elseif f.n and f.n <= nivel and not HabilidadLista(f) then est[i] = "bloqueado"
      elseif f.n and f.n <= nivel then est[i] = "disponible"
      else est[i] = "futuro" end
    end
  end
  return est, sinTalento
end

-- Estado del hechizo entero: lo que ves en el color del nombre.
local function EstadoGrupo(g, est, sinTalento)
  local hay, conocidos = false, 0
  for i, f in ipairs(g.rangos) do
    if est[i] == "disponible" and f.origen == "instructor" then hay = true end
    if est[i] == "aprendido" then conocidos = conocidos + 1 end
  end
  if hay then return "disponible", conocidos end
  if sinTalento then return "talento", conocidos end
  if conocidos > 0 then return "aprendido", conocidos end
  if est[1] == "disponible" then return "disponible", conocidos end
  return "futuro", conocidos
end

local COLOR_ESTADO = { aprendido = C.VERDE, disponible = C.AMARILLO, futuro = C.GRIS, bloqueado = ROJO }

local function TextoRango(f, estado)
  local color = COLOR_ESTADO[estado] or C.GRIS
  local partes
  if f.origen == "instructor" then
    local hab = ""
    if f.hab and (f.hab[2] or 0) > 1 then
      hab = ", " .. ((GL.NombreHabilidad and GL.NombreHabilidad(f.hab[1])) or "habilidad") .. " " .. f.hab[2]
    end
    partes = (f.n or "?") .. " (" .. Dinero(f.coste) .. hab .. ")"
  elseif f.origen == "talento" then
    partes = "talento"
  elseif f.origen == "mision" then
    partes = (f.n and (f.n .. " ") or "") .. L"(misión)"
  else
    partes = L"1 (lo tienes desde el principio)"
  end
  return color .. partes .. C.FIN
end

-- Línea de origen del primer rango: talento, misión u otro instructor (el de mascotas del cazador). Lo que tienes
-- desde el principio ya lo dice el rango.
local function TextoOrigen(f)
  if f.donde then
    return C.AZUL .. L"Se compra en el " .. L(tostring(f.donde)) .. "." .. C.FIN
  elseif f.origen == "talento" then
    local t = L"Se aprende con un punto de talento"
    if f.n then t = t .. L" (desde el nivel " .. f.n .. ")" end
    if f.plan then t = t .. L"; la guía lo coge al " .. f.plan else t = t .. L"; la guía no lo coge" end
    return C.AZUL .. t .. "." .. C.FIN
  elseif f.origen == "mision" then
    return C.AZUL .. L"Se aprende con la misión " .. (f.misionNombre or ("#" .. tostring(f.mision))) ..
      (f.n and (L" (nivel " .. f.n .. ")") or "") .. "." .. C.FIN
  end
  return nil
end

local function DeLaRama(g, filtro)
  if filtro == TODAS then return true end
  for _, r in ipairs(g.ramas) do
    if r == filtro then return true end
  end
  return false
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------
local function Fila(i)
  local f = filas[i]
  if f then return f end
  f = CreateFrame("Frame", nil, hijo)
  f.marco = GL.CrearMarcoIcono(f, LADO_ICONO)
  f.marco:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.marco:EnableMouse(true)
  f.marco:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.idHechizo) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, self.idHechizo)
    if not ok then GameTooltip:SetText(self.nombre or "", 1, 0.82, 0) end
    if self.rangos then   -- 9.4.2: la lista de rangos sale aquí, no en la fila
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L"Rangos (nivel y precio): " .. self.rangos, 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  f.marco:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.nombre = GL.Texto(f, "GameFontNormal")
  f.nombre:SetPoint("TOPLEFT", f.marco, "TOPRIGHT", 8, -1)
  GL.UnaLinea(f.nombre)
  f.etiqueta = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
  f.etiqueta:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
  GL.UnaLinea(f.etiqueta)
  f.detalle = GL.Texto(f, "GameFontHighlightSmall")
  f.detalle:SetPoint("TOPLEFT", f.nombre, "BOTTOMLEFT", 0, -3)
  f.linea = f:CreateTexture(nil, "BACKGROUND")
  f.linea:SetHeight(1)
  f.linea:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, -5)
  f.linea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, -5)
  f.linea:SetColorTexture(1, 1, 1, 0.06)
  filas[i] = f
  return f
end

-- 9.4.2: se traduce al usarla (al cargar el archivo aún no se sabe el idioma elegido en Ajustes)
local ETIQUETA_BASE = { comprar = { C.VERDE, "Compra" }, opcional = { C.AMARILLO, "Opcional" }, saltar = { C.GRIS, "Sáltalo" } }
local ETIQUETA = setmetatable({}, { __index = function(_, k)
  local e = ETIQUETA_BASE[k]
  return e and (e[1] .. L(e[2]) .. C.FIN) or nil
end })

local function Colocar()
  if not panel then return end
  if not grupos or rutaGrupos ~= GL.RUTA then Armar() end
  local db = DB()
  local filtro = db.filtroHechizos or TODAS
  local valido = filtro == TODAS
  for _, b in ipairs(filtros) do
    b:SetActivo(b.clave == filtro)
    if b.clave == filtro then valido = true end
  end
  if not valido then filtro = TODAS; db.filtroHechizos = nil; filtros[1]:SetActivo(true) end
  botonSolo:SetActivo(db.soloDisponibles == true)
  -- 9.6: con la Guía clara, en vez de «Solo lo disponible» (ya va arriba), «Llevarme al instructor»
  local claraArriba = GL.GuiaClaraActiva and GL.GuiaClaraActiva()
  local destinoIr = claraArriba and GL.DestinoInstructor and GL.DestinoInstructor() or nil
  GL.Mostrar(botonSolo, not claraArriba)
  GL.Mostrar(botonIr, destinoIr ~= nil)
  botonIr.destino = destinoIr

  local ancho = scroll:GetWidth() or 0
  if ancho <= 60 then ancho = 330 end
  hijo:SetWidth(ancho)
  local anchoTexto = ancho - LADO_ICONO - 8
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  local y, usadas = 0, 0
  local pend = {}
  -- cuentas del resumen: todo lo de la lista y solo lo que recomienda la guía (Compra)
  local total, aprendidos = 0, 0
  local ya, costeYa, costeFalta, yaRec, costeYaRec, costeFaltaRec = 0, 0, 0, 0, 0, 0
  for _, g in ipairs(grupos) do
    if DeLaRama(g, filtro) then
      local est, sinTalento = Estados(g, nivel)
      local estado, conocidos = EstadoGrupo(g, est, sinTalento)
      -- el rango que se describe: el más alto que tienes o, si no tienes ninguno, el primero
      local mejor = g.rangos[1].id
      for i = #g.rangos, 1, -1 do
        if est[i] == "aprendido" then mejor = g.rangos[i].id; break end
      end
      local nombre = Nombre(mejor)
      local consejo = GL.ConsejoHechizo and GL.ConsejoHechizo(nombre)
      local recomendado = consejo and consejo.c == "comprar"
      total = total + 1
      if estado == "aprendido" then aprendidos = aprendidos + 1 end
      for i, f in ipairs(g.rangos) do
        if f.origen == "instructor" then
          if est[i] == "disponible" then
            ya = ya + 1; costeYa = costeYa + f.coste
            if recomendado then yaRec = yaRec + 1; costeYaRec = costeYaRec + f.coste end
          end
          if est[i] == "disponible" or est[i] == "futuro" then
            costeFalta = costeFalta + f.coste
            if recomendado then costeFaltaRec = costeFaltaRec + f.coste end
          end
        end
      end
      table.insert(pend, { g = g, est = est, estado = estado, conocidos = conocidos, mejor = mejor, nombre = nombre, consejo = consejo })
    end
  end
  -- 9.6: con la Guía clara, primero lo que puedes aprender ya y lo demás en un desplegable
  local clara = GL.GuiaClaraActiva and GL.GuiaClaraActiva()
  local ahora, resto = {}, {}
  for _, e in ipairs(pend) do
    if e.estado == "disponible" then table.insert(ahora, e) elseif not db.soloDisponibles then table.insert(resto, e) end
  end
  local cabUsadas = 0
  local function Cabecera(texto, clic)
    cabUsadas = cabUsadas + 1
    local c = cabeceras[cabUsadas]
    if not c then
      c = CreateFrame("Button", nil, hijo)
      c.texto = GL.Texto(c, "GameFontNormal")
      c.texto:SetPoint("LEFT", c, "LEFT", 0, 0)
      c.texto:SetPoint("RIGHT", c, "RIGHT", 0, 0)
      GL.UnaLinea(c.texto)
      c.linea = c:CreateTexture(nil, "ARTWORK")
      c.linea:SetHeight(1)
      c.linea:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
      c.linea:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
      c.linea:SetColorTexture(1, 1, 1, 0.10)
      cabeceras[cabUsadas] = c
    end
    c.texto:SetText(texto)
    c:SetScript("OnClick", clic)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", hijo, "TOPLEFT", 0, -y)
    c:SetWidth(ancho); c:SetHeight(18)
    c:Show()
    y = y + 26
  end
  local function Pintar(e)
    local g, est, estado, conocidos, mejor, nombre, consejo = e.g, e.est, e.estado, e.conocidos, e.mejor, e.nombre, e.consejo
    usadas = usadas + 1
    local fila = Fila(usadas)
    fila.marco.idHechizo = mejor
    fila.marco.nombre = nombre
    GL.PonerIcono(fila.marco.icono, Icono(mejor))
    fila.marco.icono:SetDesaturated(estado == "futuro" or estado == "talento")
    local color = COLOR_ESTADO[estado] or C.BLANCO
    if estado == "talento" then color = C.GRIS end
    local titulo = color .. nombre .. C.FIN
    if #g.rangos > 1 then
      titulo = titulo .. C.GRIS .. "  " .. conocidos .. "/" .. #g.rangos .. C.FIN
    end
    -- etiqueta: consejo de la guía y rama
    local etiqueta = table.concat(g.ramas, L" y ")
    if consejo and ETIQUETA[consejo.c] then etiqueta = ETIQUETA[consejo.c] .. C.GRIS .. "  ·  " .. etiqueta .. C.FIN
    else etiqueta = C.GRIS .. etiqueta .. C.FIN end
    fila.etiqueta:SetText(etiqueta)
    local anchoEtiqueta = (fila.etiqueta.GetStringWidth and fila.etiqueta:GetStringWidth()) or 90
    if not anchoEtiqueta or anchoEtiqueta <= 0 then anchoEtiqueta = 90 end
    fila.nombre:SetWidth(math.max(60, anchoTexto - anchoEtiqueta - 8))
    fila.nombre:SetText(titulo)
    -- detalle: niveles y precios de cada rango, origen y consejo (lo que hace sale en la ventana del icono)
    local lineas = {}
    local rangos = {}
    for i, f in ipairs(g.rangos) do table.insert(rangos, TextoRango(f, est[i])) end
    fila.marco.rangos = nil
    if #g.rangos == 1 then
      table.insert(lineas, C.GRIS .. L"Nivel " .. C.FIN .. rangos[1])
    else
      -- 9.4.2: solo el rango siguiente; todos los rangos, en la ventana del icono
      local sig
      for i = 1, #g.rangos do if est[i] ~= "aprendido" then sig = i; break end end
      if not sig then
        table.insert(lineas, C.VERDE .. L"Todos los rangos aprendidos" .. C.FIN)
      elseif g.rangos[sig].origen == "instructor" then
        table.insert(lineas, C.GRIS .. L"Siguiente rango: nivel " .. C.FIN .. rangos[sig])
      else
        table.insert(lineas, C.GRIS .. L"Siguiente rango: " .. C.FIN .. rangos[sig])
      end
      fila.marco.rangos = table.concat(rangos, C.GRIS .. " · " .. C.FIN)
    end
    local origen = TextoOrigen(g.rangos[1])
    if origen then table.insert(lineas, origen) end
    -- lo que pide además (una actitud de misión, por ejemplo), solo mientras no lo tengas
    for _, r in ipairs(g.rangos[1].necesita or {}) do
      if not GL.HechizoConocido(r) then
        local o = indice[r]
        local t = L"Necesita " .. Nombre(r)
        -- con su rango si no es el primero (la bendición superior pide el rango 6 de la normal)
        local rg = tonumber(string.match(GL.RangoHechizo and GL.RangoHechizo(r) or "", "(%d+)"))
        if rg and rg > 1 then t = t .. L" (rango " .. rg .. ")" end
        if o and o.origen == "mision" then
          t = t .. L", que se aprende con la misión " .. (o.misionNombre or ("#" .. tostring(o.mision)))
        end
        table.insert(lineas, ROJO .. t .. "." .. C.FIN)
      end
    end
    local ultimo = g.rangos[#g.rangos]
    if ultimo ~= g.rangos[1] and ultimo.origen == "mision" then table.insert(lineas, TextoOrigen(ultimo)) end
    if consejo and consejo.nota then table.insert(lineas, C.BLANCO .. L"Guía: " .. C.FIN .. consejo.nota) end
    local texto = table.concat(lineas, "\n")
    fila.detalle:SetWidth(anchoTexto)
    fila.detalle:SetText(texto)
    local alto = 16 + 3 + GL.Alto(fila.detalle, texto, 12, anchoTexto)
    if alto < LADO_ICONO then alto = LADO_ICONO end
    fila:ClearAllPoints()
    fila:SetPoint("TOPLEFT", hijo, "TOPLEFT", 0, -y)
    fila:SetWidth(ancho)
    fila:SetHeight(alto)
    fila:Show()
    y = y + alto + 10
  end
  local function Nada(detalle)
    usadas = usadas + 1
    local fila = Fila(usadas)
    fila.marco.idHechizo = nil; fila.marco.rangos = nil
    GL.PonerIcono(fila.marco.icono, ICONO_PESTANA)
    fila.marco.icono:SetDesaturated(true)
    fila.nombre:SetWidth(anchoTexto)
    fila.nombre:SetText(C.GRIS .. L"Nada que aprender ahora" .. C.FIN)
    fila.etiqueta:SetText("")
    fila.detalle:SetWidth(anchoTexto)
    fila.detalle:SetText(C.GRIS .. detalle .. C.FIN)
    fila:ClearAllPoints()
    fila:SetPoint("TOPLEFT", hijo, "TOPLEFT", 0, -y)
    fila:SetWidth(ancho)
    fila:SetHeight(LADO_ICONO)
    fila:Show()
    y = y + LADO_ICONO + 10
  end
  if clara then
    if #ahora == 0 then
      local sig = GL.SiguienteEntrenamiento and GL.SiguienteEntrenamiento(UnitLevel and UnitLevel("player") or 1)
      Nada(sig and (L"Vuelve al instructor al " .. sig .. ".") or L"Vuelve al instructor cuando subas de nivel.")
    end
    if #ahora > 0 then Cabecera(C.AMARILLO .. L"Para aprender ya" .. C.FIN .. C.GRIS .. "  (" .. #ahora .. ")" .. C.FIN) end
    for _, e in ipairs(ahora) do Pintar(e) end
    if #resto > 0 then
      local abierto = db.hechizosResto == true
      Cabecera((abierto and "v  " or ">  ") .. L"Más adelante y aprendidos" .. C.GRIS .. "  (" .. #resto .. ")" .. C.FIN, function()
        DB().hechizosResto = not abierto or nil
        Colocar()
      end)
      if abierto then for _, e in ipairs(resto) do Pintar(e) end end
    end
  else
    for _, e in ipairs(pend) do
      if not db.soloDisponibles or e.estado == "disponible" then Pintar(e) end
    end
  end
  if usadas == 0 and not clara then Nada(L"Quita \"Solo lo disponible\" para ver toda la lista.") end
  for i = cabUsadas + 1, #cabeceras do cabeceras[i]:Hide() end
  for i = usadas + 1, #filas do filas[i]:Hide() end
  -- 9.4.2: solo lo que puedes aprender ya (sin el total ni lo que cuesta hasta el 60)
  local texto = C.GRIS .. L"Nada que aprender ahora en el instructor." .. C.FIN
  if ya > 0 then
    texto = C.AMARILLO .. L"Puedes aprender ya " .. ya .. (ya == 1 and L" rango" or L" rangos") ..
      " (" .. Dinero(costeYa) .. ")" .. C.FIN
    if yaRec > 0 then
      texto = texto .. C.VERDE .. L"; la guía recomienda " .. yaRec .. " (" .. Dinero(costeYaRec) .. ")" .. C.FIN
    end
    texto = texto .. C.AMARILLO .. "." .. C.FIN
  end
  resumen:SetText(texto)
  -- la lista empieza debajo del resumen, que puede ocupar varias líneas
  local anchoResumen = math.max(60, ((panel:GetWidth() or 0) > 60 and panel:GetWidth() or 400) - ANCHO_SOLO - 8)
  local altoResumen = math.max(20, GL.Alto(resumen, texto, 12, anchoResumen))
  local arriba = 29 + altoResumen + 8
  if scroll.arriba ~= arriba then
    scroll.arriba = arriba
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -arriba)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 0)
    barra:ClearAllPoints()
    barra:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -arriba)
    barra:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  end

  hijo:SetHeight(math.max(1, y))
  local maximo = math.max(0, math.floor(y - (scroll:GetHeight() or 0) + 0.5))
  barra:SetMinMaxValues(0, maximo)
  GL.Mostrar(barra, maximo > 0)
  local actual = barra:GetValue() or 0
  if actual > maximo then actual = maximo end
  barra:SetValue(actual)
  scroll:SetVerticalScroll(actual)
end

local function Disponer()
  if not panel then return end
  local ancho = (panel:GetWidth() or 0)
  if ancho <= 60 then ancho = 400 end
  local n = #filtros
  -- 9.7.4: cada filtro mide su texto más una parte igual del hueco que sobra (antes, todos iguales:
  -- «Beast Mastery», «Restauración» o «Protección» salían cortados con seis filtros)
  local libre, anchos, suma = ancho - (n - 1) * 6, {}, 0
  for i, b in ipairs(filtros) do
    local tw = b.texto and b.texto.GetStringWidth and tonumber(b.texto:GetStringWidth()) or 0
    anchos[i] = math.ceil(tw) + 10 + (b.icono and 18 or 0); suma = suma + anchos[i]
  end
  if suma <= 10 * n then
    for i = 1, n do anchos[i] = libre / n end
  elseif suma > libre then
    for i = 1, n do anchos[i] = anchos[i] * libre / suma end
  else
    local extra = (libre - suma) / n
    for i = 1, n do anchos[i] = anchos[i] + extra end
  end
  for i, b in ipairs(filtros) do b:SetWidth(math.floor(anchos[i])) end
  resumen:SetWidth(math.max(60, ancho - ANCHO_SOLO - 8))
end

local function ElegirFiltro(clave)
  local db = DB()
  db.filtroHechizos = (clave ~= TODAS) and clave or nil
  if barra then barra:SetValue(0) end
  Colocar()
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame or not GL.RUTA then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + GL.ALTO_SUB))   -- debajo de las subpestañas
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()

  -- filtro: Todas y cada especialización de la ruta (con el icono de su rama de talentos si la hay)
  local claves = { TODAS }
  for _, e in ipairs(GL.RUTA.especialidades or {}) do table.insert(claves, e) end
  for i, clave in ipairs(claves) do
    local b = GL.CrearBoton(panel, clave, function() ElegirFiltro(clave) end, nil, 22)
    b.clave = clave
    if i == 1 then b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    else b:SetPoint("LEFT", filtros[i - 1], "RIGHT", 6, 0) end
    local ayuda = clave == TODAS and L"Todos los hechizos de tu clase." or
      (clave == "General" and L"Hechizos que usa cualquier especialización (utilidad, viaje, comida y bebida...)." or
       (L"Hechizos que usa la especialización " .. clave .. "."))
    GL.Ayuda(b, clave, ayuda)
    filtros[i] = b
  end
  resumen = GL.Texto(panel, "GameFontHighlightSmall")
  resumen:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -29)
  botonSolo = GL.CrearBoton(panel, L"Solo lo disponible", function()
    local db = DB()
    db.soloDisponibles = not db.soloDisponibles or nil
    if barra then barra:SetValue(0) end
    Colocar()
  end, nil, 20)
  botonSolo:SetWidth(ANCHO_SOLO)
  botonSolo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -28)
  GL.Ayuda(botonSolo, L"Solo lo disponible", L"Muestra solo los hechizos que puedes aprender ya en tu instructor.")
  botonIr = GL.CrearBoton(panel, L"Llevarme al instructor", function(self)
    if self.destino and GL.SeguirDesvio then GL.SeguirDesvio(self.destino) end
  end, nil, 20, "accion")
  botonIr:SetWidth(ANCHO_SOLO)   -- 9.7.4: ANCHO_SOLO pasa de 128 a 150, «Llevarme al instructor» no cabía
  botonIr:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -28)
  GL.Ayuda(botonIr, L"Llevarme al instructor", L"La flecha te lleva al instructor de tu clase de la ruta más cercano a tu paso.")
  botonIr:Hide()

  scroll = CreateFrame("ScrollFrame", nil, panel)
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -60)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 0)
  hijo = CreateFrame("Frame", nil, scroll)
  hijo:SetWidth(330)
  hijo:SetHeight(1)
  scroll:SetScrollChild(hijo)

  barra = CreateFrame("Slider", nil, panel)
  barra:SetOrientation("VERTICAL")
  barra:SetWidth(10)
  barra:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -60)
  barra:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  local pista = barra:CreateTexture(nil, "BACKGROUND")
  pista:SetPoint("TOP", barra, "TOP", 0, 0)
  pista:SetPoint("BOTTOM", barra, "BOTTOM", 0, 0)
  pista:SetWidth(4)
  pista:SetColorTexture(1, 1, 1, 0.12)
  local pulgar = barra:CreateTexture(nil, "OVERLAY")
  pulgar:SetWidth(8)
  pulgar:SetHeight(28)
  pulgar:SetColorTexture(0.41, 0.8, 0.94, 0.85)
  barra:SetThumbTexture(pulgar)
  barra:SetMinMaxValues(0, 0)
  barra:SetValueStep(1)
  barra:SetValue(0)
  barra:EnableMouse(true)
  barra:SetScript("OnValueChanged", function(self, v) scroll:SetVerticalScroll(v) end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local minimo, maximo = barra:GetMinMaxValues()
    local v = (barra:GetValue() or 0) - delta * 48
    if v < minimo then v = minimo end
    if v > maximo then v = maximo end
    barra:SetValue(v)
  end)
  panel:SetScript("OnSizeChanged", function() Disponer() end)
  Disponer()
  GL.modos.hechizos = { panel = panel, refrescar = function() Disponer(); Colocar() end }
end

-- Abre la pestaña Hechizos de la ventana.
function GL.AbrirHechizos(filtro)
  local db = DB()
  if db.compacto and GL.SalirCompacto then GL.SalirCompacto() end
  if GL.frame then GL.frame:Show(); db.oculto = false end
  if filtro then db.filtroHechizos = filtro end
  GL.AbrirModo("hechizos")
end

-- Refresco cuando cambian tus hechizos o llega el nombre de uno que se había pedido al juego.
local function ProgramarColocar()
  if refrescoPendiente then return end
  refrescoPendiente = true
  local function Hacer()
    refrescoPendiente = false
    if panel and panel:IsShown() then pcall(Colocar) end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.3, Hacer) else Hacer() end
end

GL.RefrescarHechizos = ProgramarColocar

-- 9.7.4: los rangos de un hechizo, del primero al último, según los datos de la ruta (para cambiar los rangos
-- de las barras sin depender de que el juego encuentre el hechizo por su nombre).
local cadenas, cadenasRuta = nil, nil
function GL.CadenaDeHechizo(id)
  if not GL.RUTA then return nil end
  if not cadenas or cadenasRuta ~= GL.RUTA then
    cadenas, cadenasRuta = {}, GL.RUTA
    local ok = pcall(Armar)
    if ok and grupos then
      for _, g in ipairs(grupos) do
        local ids = {}
        for _, f in ipairs(g.rangos or {}) do table.insert(ids, f.id) end
        if #ids > 1 then for _, x in ipairs(ids) do cadenas[x] = ids end end
      end
    end
  end
  return cadenas[id]
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "SPELLS_CHANGED")
GL.Evento(eventos, "LEARNED_SPELL_IN_SKILL_LINE")
pcall(eventos.RegisterEvent, eventos, "SPELL_DATA_LOAD_RESULT")
eventos:SetScript("OnEvent", function(self, event, id)
  if event == "SPELL_DATA_LOAD_RESULT" and not pedidos[id] then return end
  ProgramarColocar()
end)

table.insert(GL.alIniciar, CrearPanel)

GL.comandos["hechizos"] = function(resto)
  local filtro
  if resto and resto ~= "" and GL.RUTA then
    for _, e in ipairs(GL.RUTA.especialidades or {}) do
      if string.lower(e) == resto then filtro = e end
    end
  end
  GL.AbrirHechizos(filtro)
end

GL.ICONO_HECHIZOS = ICONO_PESTANA

-- 9.6: el instructor de clase de la ruta más cercano a tu paso (primero los que vienen, luego los de atrás)
function GL.DestinoInstructor()
  local R, db = GL.RUTA, DB()
  if not (R and R.secciones and GL.TipoPaso and db) then return nil end
  local lista, actual = {}, nil
  for s, sec in ipairs(R.secciones) do
    for p, paso in ipairs(sec.pasos or {}) do
      if s == db.seccion and p == db.paso then actual = #lista + 1 end
      local tx = string.lower(tostring(paso.t or ""))
      local esInstr = GL.TipoPaso(paso) == "instructor" or ((tx:find("^train") or tx:find("[%s:]train")) and not tx:find("[%s:]fly") and not (paso.wp and paso.wp[1] and paso.wp[1].q))
      if esInstr then
        for _, d in ipairs(paso.wp or {}) do
          if d.m and d.x and d.y then table.insert(lista, { m = d.m, x = d.x, y = d.y, z = d.z, n = d.n or L"Instructor" }); break end
        end
      elseif s == db.seccion and p == db.paso then actual = #lista + 1 end
    end
  end
  if #lista == 0 then return nil end
  actual = actual or 1
  return lista[actual] or lista[#lista]
end

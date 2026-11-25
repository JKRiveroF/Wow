-- Instructor.lua: qué hechizos aprender en el instructor de clase, por orden de prioridad, y los aprende solo. Creado por JKRiveroF.
-- Los consejos vienen de la ruta (R.hechizos, en orden de prioridad) con el id del hechizo; el nombre se pide al juego.
-- R.entrenamiento dice qué rango se aprende a cada nivel en Forever: con eso la guía avisa al subir de nivel
-- y la pestaña Hechizos muestra lo que puedes aprender ya.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local ANCHO = 300
local MAX_LINEAS = 16
local MAX_OLEADAS = 6                  -- comprar un rango puede abrir el siguiente: se repite unas cuantas veces

local panel
local rutaConsejos
local consejos                         -- nombre del hechizo en el idioma del cliente -> { c, nota, prioridad }
local oleadas = 0                      -- compras automáticas hechas desde que abriste el instructor
local comprando = false                -- esperando a que el instructor actualice la lista tras comprar
local sesionInstructor = 0
local sesionAbierta, autoSesion = false, false
local rutaSesion, compraPendiente


local ORDEN = { comprar = 1, opcional = 2, saltar = 3 }
-- 9.4.2: se traduce al usarla (al cargar el archivo aún no se sabe el idioma elegido en Ajustes)
local ETIQUETA_BASE = { comprar = { C.VERDE, "Compra" }, opcional = { C.AMARILLO, "Opcional" }, saltar = { C.GRIS, "Sáltalo" } }
local ETIQUETA = setmetatable({}, { __index = function(_, k)
  local e = ETIQUETA_BASE[k]
  return e and (e[1] .. L(e[2]) .. C.FIN) or nil
end })

local function DB() return GuiaAventureroDB end
local function AutoActivo() return DB().autoHechizos ~= false end

local function NombreHechizo(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then return n end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and n then return n end
  end
  return nil
end

local function RangoHechizo(id)
  if C_Spell and C_Spell.GetSpellSubtext then
    local ok, r = pcall(C_Spell.GetSpellSubtext, id)
    if ok and type(r) == "string" then return r end
  end
  return ""
end

-- Un consejo con "hasta" vale hasta ese nivel; por encima pasa a "saltar" (p. ej. Arma Muerdepiedras, que el
-- chamán cambia por Arma Viento Furioso al 30: sus rangos siguientes ya no se compran).
local function PrepararConsejos()
  consejos = {}
  rutaConsejos = GL.RUTA
  local lista = GL.RUTA and GL.RUTA.hechizos or {}
  for i = 1, #lista do
    local h = lista[i]
    local nombre = NombreHechizo(h.id)
    if nombre and not consejos[nombre] then
      local c = { c = h.c, nota = h.nota, prioridad = i, hasta = h.hasta }
      if h.hasta then
        c.despues = { c = "saltar", prioridad = i,
          nota = h.notaDespues or (L"Desde el nivel " .. (h.hasta + 1) .. L" ya no lo usas.") }
      end
      consejos[nombre] = c
    end
  end
end

-- nivel: para qué nivel es el consejo (por defecto, el tuyo).
local function Consejo(nombre, nivel)
  if not consejos or rutaConsejos ~= GL.RUTA then PrepararConsejos() end
  local c = nombre and consejos[nombre]
  if c and c.hasta and (nivel or UnitLevel("player") or 1) > c.hasta then return c.despues end
  return c
end

local function Dinero(cobre)
  cobre = cobre or 0
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
    local ok, t = pcall(C_CurrencyInfo.GetCoinTextureString, cobre)
    if ok and t then return t end
  end
  if GetCoinTextureString then return GetCoinTextureString(cobre) end
  if GetMoneyString then return GetMoneyString(cobre) end
  return string.format("%.2f o", cobre / 10000)
end

local function OrdenFila(a, b)
  if a.orden ~= b.orden then return a.orden < b.orden end
  if a.prioridad ~= b.prioridad then return a.prioridad < b.prioridad end
  return a.nombre < b.nombre
end

------------------------------------------------------------------------
-- Lo que te toca aprender según tu nivel (sin estar en el instructor)
------------------------------------------------------------------------
-- Índices de R.entrenamiento: qué ids son del instructor y qué rango pide a cuál (para saber el siguiente).
-- R.donde: hechizos que no vende tu instructor de clase (los del instructor de mascotas del cazador) por lugar.
local delInstructor, siguientes, dondeDe, rutaIndices
local function Indices()
  if delInstructor and rutaIndices == GL.RUTA then return end
  rutaIndices = GL.RUTA
  delInstructor, siguientes, dondeDe = {}, {}, {}
  local datos = GL.RUTA and GL.RUTA.entrenamiento or {}
  for i = 1, #datos do
    local e = datos[i]
    delInstructor[e.id] = true
    for _, r in ipairs(e.req or {}) do
      siguientes[r] = siguientes[r] or {}
      table.insert(siguientes[r], e.id)
    end
  end
  local donde = GL.RUTA and GL.RUTA.donde
  if type(donde) == "table" then
    for lugar, ids in pairs(donde) do
      for _, id in ipairs(ids) do dondeDe[id] = lugar end
    end
  end
end

-- Dónde se compra un hechizo que no vende tu instructor de clase (nil si lo vende él).
local function DondeHechizo(id)
  if not GL.RUTA then return nil end
  Indices()
  return dondeDe[id]
end

-- Los hechizos del instructor de mascotas no van a tu libro de hechizos, así que la guía apunta los que aprendes
-- (en GuiaAventureroDB.aprendidosFuera, por id): con el mensaje "Has aprendido..." y con las ventanas de instructor.
local function Apuntar(id)
  local db = DB()
  db.aprendidosFuera = db.aprendidosFuera or {}
  if db.aprendidosFuera[id] then return false end
  db.aprendidosFuera[id] = true
  return true
end

local function ConocidoFuera(id)
  if not DondeHechizo(id) then return false end
  local a = DB().aprendidosFuera
  return (a and a[id]) and true or false
end

-- Conocido también si ya tienes un rango superior (por si el juego deja de contar el rango anterior).
local function Conocido(id, prof)
  if GL.HechizoConocido(id) then return true end
  Indices()
  prof = (prof or 0) + 1
  local s = siguientes[id]
  if s and prof <= 20 then
    for _, sig in ipairs(s) do
      if Conocido(sig, prof) then return true end
    end
  end
  return false
end

-- Nivel de una habilidad que piden algunos hechizos (hab = { id, nivel }: los venenos del pícaro piden Venenos, la 40).
-- nil si no la tienes. El nombre (R.habilidades) solo hace falta si el juego no da el id de la habilidad. Se guarda
-- durante el fotograma: la pestaña Hechizos lo pregunta para muchos hechizos seguidos.
local cacheHab, cacheHabT, cacheHabRuta = {}, nil, nil
local function NivelHabilidad(skill)
  if not (skill and GL.NivelProfesion) then return nil end
  local t = GetTime and GetTime()
  if t == nil or t ~= cacheHabT or cacheHabRuta ~= GL.RUTA then
    for k in pairs(cacheHab) do cacheHab[k] = nil end
    cacheHabT, cacheHabRuta = t, GL.RUTA
  end
  local v = cacheHab[skill]
  if v == nil then
    local nombres = GL.RUTA and GL.RUTA.habilidades
    v = GL.NivelProfesion({ skill = skill, nombre = nombres and nombres[skill] or "" }) or false
    cacheHab[skill] = v
  end
  return v or nil
end

local function NombreHabilidad(skill)
  local nombres = GL.RUTA and GL.RUTA.habilidades
  return (nombres and nombres[skill]) or L"la habilidad"
end

-- true si tienes el nivel de habilidad que pide (o si no pide ninguno). Con soloTalentos (niveles que llegan ahora o
-- más adelante) basta con tener la habilidad: el nivel lo irás subiendo.
local function HabilidadCumplida(e, soloTalentos)
  if not e.hab then return true end
  local nivel = NivelHabilidad(e.hab[1])
  if not nivel then return false end
  if soloTalentos then return true end
  return nivel >= (e.hab[2] or 0)
end

-- "con Venenos 120": lo que te falta de habilidad para un hechizo, o nil si ya lo tienes.
local function FaltaHabilidad(hab)
  if not hab then return nil end
  local nivel = NivelHabilidad(hab[1])
  if nivel and nivel >= (hab[2] or 0) then return nil end
  return L"con " .. NombreHabilidad(hab[1]) .. " " .. (hab[2] or 0)
end

-- Requisitos de un hechizo: el rango anterior o un talento, y el nivel de habilidad si pide alguno. Con soloTalentos
-- se da por hecho que irás comprando los rangos anteriores (para avisar de niveles futuros) y solo se mira el talento.
local function RequisitosCumplidos(e, soloTalentos)
  if not HabilidadCumplida(e, soloTalentos) then return false end
  if not e.req then return true end
  Indices()
  for i = 1, #e.req do
    local r = e.req[i]
    if not (soloTalentos and delInstructor[r]) and not Conocido(r) then return false end
  end
  return true
end

-- Hechizos de tu instructor de esos niveles que puedes aprender y aún no tienes. Con todos = true (niveles
-- que llegan ahora o más adelante) no se mira si ya lo tienes ni el rango anterior, solo el talento.
local function Pendientes(desde, hasta, todos, soloDesconocidos)
  Indices()
  local lista = {}
  local datos = GL.RUTA and GL.RUTA.entrenamiento or {}
  for i = 1, #datos do
    local e = datos[i]
    local vale = e.n >= desde and e.n <= hasta
    if vale then
      if todos then vale = (not soloDesconocidos or not Conocido(e.id)) and RequisitosCumplidos(e, true)
      else vale = not Conocido(e.id) and RequisitosCumplidos(e, false) end
    end
    if vale then
      local nombre = NombreHechizo(e.id)
      if nombre then
        -- el consejo del nivel al que lo comprarías: el del rango o el tuyo si ya lo has pasado
        local c = Consejo(nombre, math.max(e.n, UnitLevel("player") or 1))
        table.insert(lista, { id = e.id, n = e.n, nombre = nombre, rango = RangoHechizo(e.id), coste = e.coste or 0,
          donde = dondeDe[e.id], hab = e.hab, c = c, orden = c and ORDEN[c.c] or 4, prioridad = c and c.prioridad or 999 })
      end
    end
  end
  table.sort(lista, OrdenFila)
  return lista
end

-- Lo recomendado de tu nivel que aún no tienes y que solo espera a que subas la habilidad que pide (Venenos), del
-- nivel de habilidad más bajo al más alto.
local function PendientesPorHabilidad(nivel)
  Indices()
  local lista = {}
  local datos = GL.RUTA and GL.RUTA.entrenamiento or {}
  for i = 1, #datos do
    local e = datos[i]
    if e.hab and e.n <= nivel and not Conocido(e.id) and HabilidadCumplida(e, true) and not HabilidadCumplida(e, false)
      and RequisitosCumplidos({ req = e.req }, false) then
      local nombre = NombreHechizo(e.id)
      local c = nombre and Consejo(nombre, math.max(e.n, nivel))
      if c and c.c == "comprar" then
        table.insert(lista, { id = e.id, n = e.n, nombre = nombre, rango = RangoHechizo(e.id), hab = e.hab,
          orden = e.hab[2] or 0, prioridad = c.prioridad or 999 })
      end
    end
  end
  table.sort(lista, OrdenFila)
  return lista
end

-- "Gran aguante (rango 2, en el instructor de mascotas)": el rango y, si no lo vende tu instructor, dónde se compra;
-- "Veneno instantáneo (rango 2, con Venenos 120)": el nivel de habilidad que pide, si aún no lo tienes.
local function NombreConRango(f)
  local extra = {}
  if f.rango and f.rango ~= "" then table.insert(extra, string.lower(f.rango)) end
  if f.donde then table.insert(extra, L"en el " .. f.donde) end
  local falta = FaltaHabilidad(f.hab)
  if falta then table.insert(extra, falta) end
  if #extra > 0 then return f.nombre .. " (" .. table.concat(extra, ", ") .. ")" end
  return f.nombre
end

-- "1. Descarga de Escarcha (rango 2), 2. Polimorfia" con los que hay que comprar.
local function ListaPrioridad(lista, maximo)
  local partes, coste, n = {}, 0, 0
  for i = 1, #lista do
    local f = lista[i]
    if f.c and f.c.c == "comprar" then
      n = n + 1
      coste = coste + f.coste
      if n <= maximo then table.insert(partes, n .. ". " .. NombreConRango(f)) end
    end
  end
  local texto = table.concat(partes, ", ")
  if n > maximo then texto = texto .. " y " .. (n - maximo) .. L" más" end
  return texto, n, coste
end

-- 9.7.4: cuándo vuelves al instructor y para qué: "nivel 32 (1. Descarga de Escarcha (rango 5))". nil si no queda nada.
function GL.SiguienteEntrenamiento(nivel)
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return nil end
  for siguiente = (nivel or 1) + 1, 60 do
    local ok, lista = pcall(Pendientes, siguiente, siguiente, true, true)
    if ok then
      local t, m = ListaPrioridad(lista, 3)
      if m > 0 then return L"nivel " .. siguiente .. " (" .. t .. ")", siguiente end
    end
  end
  return nil
end

-- Aviso al subir de nivel: lo nuevo de este nivel, lo importante primero. nil si no hay nada nuevo.
function GL.MensajeEntrenamiento(nivel)
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return nil end
  local nuevos = Pendientes(nivel, nivel, true)
  if #nuevos == 0 then return nil end
  local instructor = GL.RUTA.instructor or L"instructor de clase"
  local texto, n = ListaPrioridad(nuevos, 6)
  local otros = #nuevos - n
  local msg
  if n > 0 then
    msg = L"Nivel " .. nivel .. L": en tu " .. instructor .. L" aprende " .. texto .. "."
    if otros == 1 then msg = msg .. L" Hay 1 más que no hace falta."
    elseif otros > 1 then msg = msg .. L" Hay " .. otros .. L" más que no hacen falta." end
  else
    if #nuevos == 1 then
      msg = L"Nivel " .. nivel .. L": tu " .. instructor .. L" tiene 1 hechizo nuevo, pero no hace falta para subir."
    else
      msg = L"Nivel " .. nivel .. L": tu " .. instructor .. L" tiene " .. #nuevos .. L" hechizos nuevos, pero ninguno hace falta para subir."
    end
  end
  if n > 0 and AutoActivo() then msg = msg .. L" La guía los aprende sola al abrir la ventana del instructor." end
  return msg
end

-- Bloque de la pestaña Hechizos: lo que puedes aprender ya y cuándo es el siguiente entrenamiento.
-- 6.3: cuántos hechizos recomendados puedes aprender ya (para el aviso de preparación).
function GL.HechizosParaAprender()
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return 0 end
  local _, n = ListaPrioridad(Pendientes(1, UnitLevel("player") or 1), 5)
  return n or 0
end

-- Fase 5: solo compras de clase disponibles, no adiestramiento de mascotas ni otros lugares.
function GL.EntrenamientoClasePendiente()
  local n, coste = 0, 0
  for _, f in ipairs(Pendientes(1, UnitLevel("player") or 1)) do
    if not f.donde and f.c and f.c.c == "comprar" then
      n = n + 1
      coste = coste + f.coste
    end
  end
  return n, coste
end

-- 6.4: coste de lo recomendado que puedes aprender ya y del próximo nivel con entrenamiento.
function GL.CostesEntrenamiento()
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return nil end
  local nivel = UnitLevel("player") or 1
  local _, n, coste = ListaPrioridad(Pendientes(1, nivel), 5)
  local sigNivel, sigCoste, sigN
  for siguiente = nivel + 1, 60 do
    local _, m, c = ListaPrioridad(Pendientes(siguiente, siguiente, true, true), 5)
    if m > 0 then sigNivel, sigCoste, sigN = siguiente, c, m; break end
  end
  return n, coste, sigNivel, sigCoste, sigN
end

-- 7.0: lo recomendado que se aprende justo en este nivel, con icono y precio (para la celebración).
function GL.HechizosNuevos(nivel)
  local r = {}
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return r end
  local lista = Pendientes(nivel, nivel)
  for i = 1, #lista do
    local f = lista[i]
    if f.c and f.c.c == "comprar" then
      local icono = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(f.id)) or (GetSpellTexture and GetSpellTexture(f.id))
      table.insert(r, { nombre = NombreConRango(f), coste = f.coste or 0, icono = icono })
    end
  end
  return r
end

function GL.TextoHechizosNivel()
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return nil end
  local nivel = UnitLevel("player") or 1
  local lineas = {}
  local ya = Pendientes(1, nivel)
  local texto, n, coste = ListaPrioridad(ya, 5)
  if n > 0 then
    table.insert(lineas, C.AMARILLO .. L"Aprende ya en tu instructor, por prioridad: " .. C.FIN .. C.BLANCO .. texto .. C.FIN ..
      C.GRIS .. " (" .. Dinero(coste) .. ")" .. C.FIN)
  else
    table.insert(lineas, C.VERDE .. L"Ya tienes todo lo importante de tu nivel." .. C.FIN)
  end
  local falta = PendientesPorHabilidad(nivel)
  if #falta > 0 then
    local partes = {}
    for i = 1, math.min(#falta, 4) do table.insert(partes, NombreConRango(falta[i])) end
    local h = falta[1].hab
    local tienes = NivelHabilidad(h[1]) or 0
    table.insert(lineas, C.AMARILLO .. L"Sube " .. NombreHabilidad(h[1]) .. L" para aprender: " .. C.FIN .. C.BLANCO ..
      table.concat(partes, ", ") .. (#falta > 4 and (" y " .. (#falta - 4) .. L" más") or "") .. C.FIN ..
      C.GRIS .. L" (tienes " .. tienes .. ")." .. C.FIN)
  end
  for siguiente = nivel + 1, 60 do
    local lista = Pendientes(siguiente, siguiente, true)
    local t, m = ListaPrioridad(lista, 3)
    if m > 0 then
      table.insert(lineas, C.GRIS .. L"Siguiente entrenamiento: nivel " .. siguiente .. " (" .. t .. ")." .. C.FIN)
      break
    end
  end
  return table.concat(lineas, "\n")
end

------------------------------------------------------------------------
-- Panel junto a la ventana del instructor
------------------------------------------------------------------------
local AprenderRecomendado

local function CrearPanel()
  panel = CreateFrame("Frame", "GuiaAventureroInstructor", UIParent, PLANTILLA)
  panel:SetWidth(ANCHO)
  panel:SetHeight(120)
  panel:SetFrameStrata("HIGH")
  GL.Caja(panel, GL.COLOR.fondo, GL.COLOR.borde)
  GL.Sombra(panel)
  GL.Acento(panel, 2)
  panel.titulo = GL.Texto(panel, "GameFontNormal")
  panel.titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
  panel.titulo:SetText(L"Guía del Aventurero: qué aprender")
  panel.sub = GL.Texto(panel, "GameFontHighlightSmall")
  panel.sub:SetPoint("TOPLEFT", panel.titulo, "BOTTOMLEFT", 0, -2)
  panel.sub:SetText(C.GRIS .. L"Por orden de prioridad: lo de arriba primero." .. C.FIN)
  panel.lineas = {}
  for i = 1, MAX_LINEAS do
    local t = GL.Texto(panel, "GameFontHighlightSmall")
    t:SetWidth(ANCHO - 24)
    panel.lineas[i] = t
  end
  panel.pie = GL.Texto(panel, "GameFontHighlightSmall")
  panel.pie:SetWidth(ANCHO - 24)
  panel.boton = GL.CrearBoton(panel, L"Aprender lo recomendado", function() AprenderRecomendado(true) end, nil, 22, "accion")
  panel.boton:SetWidth(ANCHO - 24)
  GL.Ayuda(panel.boton, L"Aprender lo recomendado",
    L"Compra los hechizos marcados con Compra, en orden de prioridad, mientras te llegue el dinero.")
  panel:Hide()
end

local function Colocar()
  panel:ClearAllPoints()
  local trainer = ClassTrainerFrame
  if trainer and trainer.IsShown and trainer:IsShown() then
    panel:SetPoint("TOPLEFT", trainer, "TOPRIGHT", 4, 0)
  else
    panel:SetPoint("LEFT", UIParent, "LEFT", 420, 60)
  end
end

-- Hechizos que ofrece el instructor ahora mismo, con su consejo.
local function Servicios()
  local filas = {}
  for i = 1, ((GetNumTrainerServices and GetNumTrainerServices()) or 0) do
    local nombre, rango, tipo = GetTrainerServiceInfo(i)
    if tipo == "available" and nombre then
      local c = Consejo(nombre)
      local precio = (GetTrainerServiceCost and GetTrainerServiceCost(i)) or 0
      table.insert(filas, { i = i, nombre = nombre, rango = rango, precio = precio, c = c,
        orden = c and ORDEN[c.c] or 4, prioridad = c and c.prioridad or 999 })
    end
  end
  table.sort(filas, OrdenFila)
  return filas
end

local function Actualizar()
  if not panel then CrearPanel() end
  local filas = Servicios()
  local coste, n = 0, 0
  local y = -44
  for i = 1, MAX_LINEAS do
    local t = panel.lineas[i]
    local f = filas[i]
    if f then
      local nombre = C.BLANCO .. f.nombre .. C.FIN
      if f.rango and f.rango ~= "" then nombre = nombre .. C.GRIS .. " (" .. f.rango .. ")" .. C.FIN end
      local texto
      if f.c then
        local numero = ""
        if f.c.c == "comprar" then
          n = n + 1
          numero = C.AMARILLO .. n .. ". " .. C.FIN
        end
        texto = numero .. ETIQUETA[f.c.c] .. "  " .. nombre .. "\n" .. C.GRIS .. f.c.nota .. C.FIN
      else
        texto = C.GRIS .. L"Opcional" .. C.FIN .. "  " .. nombre .. "\n" .. C.GRIS .. L"La guía no lo usa para subir: cómpralo solo si lo quieres." .. C.FIN
      end
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
      t:SetText(texto)
      t:Show()
      y = y - GL.Alto(t, texto, 12, ANCHO - 24) - 5
    else
      t:Hide()
    end
  end
  for i = 1, #filas do
    if filas[i].c and filas[i].c.c == "comprar" then coste = coste + filas[i].precio end
  end
  local pie
  local hayCompra = coste > 0 or n > 0
  local sig = GL.SiguienteEntrenamiento and GL.SiguienteEntrenamiento(UnitLevel and UnitLevel("player") or 1)
  local vuelve = sig and ("\n" .. C.GRIS .. L"Vuelve al instructor al " .. sig .. "." .. C.FIN) or ""
  if #filas == 0 then
    pie = C.GRIS .. L"No hay nada nuevo que aprender ahora: no hace falta comprar nada." .. C.FIN .. vuelve
  elseif n == 0 then
    pie = C.VERDE .. L"Ya tienes todo lo recomendado." .. C.FIN .. C.GRIS .. L" Lo que queda no hace falta para subir: no lo compres si no lo quieres." .. C.FIN .. vuelve
  else
    local dinero = (GetMoney and GetMoney()) or 0
    pie = L"Lo recomendado cuesta " .. Dinero(coste) .. C.GRIS .. L"  (tienes " .. Dinero(dinero) .. ")" .. C.FIN
    if coste > dinero then pie = pie .. "\n" .. C.AMARILLO .. L"No te llega para todo: se compra en orden hasta donde llegue." .. C.FIN end
    if #filas > MAX_LINEAS then pie = pie .. "\n" .. C.GRIS .. "Y " .. (#filas - MAX_LINEAS) .. L" más en la lista del instructor." .. C.FIN end
    if AutoActivo() then
      pie = pie .. "\n" .. C.GRIS .. L"La guía compra sola lo marcado con Compra (Mayús al abrir el instructor para no hacerlo)." .. C.FIN
    end
  end
  panel.pie:ClearAllPoints()
  panel.pie:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y - 4)
  panel.pie:SetText(pie)
  local altoPie = GL.Alto(panel.pie, pie, 12, ANCHO - 24)
  local alto = -y + 4 + altoPie + 14
  if hayCompra then
    panel.boton:ClearAllPoints()
    panel.boton:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y - 4 - altoPie - 8)
    panel.boton:Show()
    alto = alto + 30
  else
    panel.boton:Hide()
  end
  panel:SetHeight(alto)
end

-- Compra lo marcado con Compra, por orden de prioridad, mientras llegue el dinero. Devuelve cuántos ha pedido.
AprenderRecomendado = function(manual)
  if not (GetNumTrainerServices and GetTrainerServiceInfo and BuyTrainerService) then return 0 end
  local filas = Servicios()
  local dinero = (GL.DineroParaComprar and GL.DineroParaComprar(manual)) or (GetMoney and GetMoney()) or 0   -- 9.1: reserva para el 40
  -- en orden estricto: si no llega para uno, se para ahí para no gastar el dinero en algo menos importante
  local elegidos, gasto, faltan, falta, primero = {}, 0, 0, 0, nil
  for _, f in ipairs(filas) do
    if f.c and f.c.c == "comprar" then
      if faltan == 0 and gasto + f.precio <= dinero then
        table.insert(elegidos, f)
        gasto = gasto + f.precio
      else
        faltan = faltan + 1
        falta = falta + f.precio
        primero = primero or f
      end
    end
  end
  if #elegidos == 0 then
    if manual then
      GL.Mensaje(primero and (L"no te llega el dinero para " .. primero.nombre .. L" (cuesta " .. Dinero(primero.precio) .. ").")
        or L"no hay nada recomendado que aprender ahora.")
    elseif primero and GL.AvisoReserva then
      GL.AvisoReserva(primero.precio)
    end
    return 0
  end
  local nombres = {}
  for _, f in ipairs(elegidos) do
    table.insert(nombres, f.nombre .. ((f.rango and f.rango ~= "") and (" (" .. f.rango .. ")") or ""))
  end
  -- de la última fila a la primera, para que una compra no mueva el número de las demás
  table.sort(elegidos, function(a, b) return a.i > b.i end)
  for _, f in ipairs(elegidos) do pcall(BuyTrainerService, f.i) end
  comprando = true
  GL.Mensaje(L"aprendo en el instructor: " .. table.concat(nombres, ", ") .. " (" .. Dinero(gasto) .. ").")
  if faltan > 0 then
    GL.Mensaje(L"no te llega el dinero para " .. faltan .. L" más (" .. Dinero(falta) .. L"): vuelve cuando lo tengas.")
  end
  return #elegidos
end

local function EsInstructorDeClase()
  if IsTradeskillTrainer then
    local ok, r = pcall(IsTradeskillTrainer)
    if ok and r then return false end
  end
  return true
end

-- En Forever, Adiestramiento de bestias abre una ventana de instructor con lo que tu cazador ya sabe para enseñar a
-- su mascota: no hay PNJ delante (o el PNJ es tu propia mascota). Ahí la guía solo apunta lo que sabes y no enseña
-- nada a tu mascota. El instructor de mascotas de verdad es un PNJ: ahí la guía compra como en tu instructor.
local function EsAdiestramiento()
  if C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType and Enum.TrainerType.Pet then
    local ok, t = pcall(C_Trainer.GetTrainerType)
    if ok and t ~= nil and t ~= Enum.TrainerType.Pet then return false end
  end
  if not UnitExists then return false end
  if not UnitExists("npc") then return true end
  if UnitIsUnit then
    local ok, r = pcall(UnitIsUnit, "npc", "pet")
    if ok and r then return true end
  end
  return false
end

-- Id del hechizo de una fila del instructor: el de su ventana de ayuda o, si no, por el nombre y el rango.
local function IdDelServicio(i, nombre, rango)
  if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
    local ok, t = pcall(C_TooltipInfo.GetTrainerService, i)
    if ok and type(t) == "table" and t.id then return t.id end
  end
  local nr = tonumber(string.match(rango or "", "(%d+)")) or 0
  for id in pairs(dondeDe) do
    if NombreHechizo(id) == nombre and (tonumber(string.match(RangoHechizo(id), "(%d+)")) or 0) == nr then return id end
  end
  return nil
end

-- Apunta los hechizos de R.donde que ya sabes según la ventana abierta: en Adiestramiento de bestias, todo lo que
-- sale; en un instructor, lo que sale como ya aprendido. true si ha apuntado alguno nuevo.
local function ApuntarDeLaVentana()
  Indices()
  if not next(dondeDe) or not (GetNumTrainerServices and GetTrainerServiceInfo) then return false end
  local todo = EsAdiestramiento()
  local nuevo = false
  for i = 1, (GetNumTrainerServices() or 0) do
    local nombre, rango, tipo = GetTrainerServiceInfo(i)
    if nombre and tipo ~= "header" and (todo or tipo == "used") then
      local id = IdDelServicio(i, nombre, rango)
      if id and dondeDe[id] and Apuntar(id) then nuevo = true end
    end
  end
  return nuevo
end

-- "Has aprendido un hechizo nuevo: [Gran aguante]": Forever pone el enlace del hechizo, con su id. Se miran los
-- tres mensajes del juego (hechizo, habilidad y pasiva) en el idioma del cliente.
local function Patron(s)
  if type(s) ~= "string" or s == "" then return nil end
  s = string.gsub(s, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  local p, n = string.gsub(s, "%%%%s", "(.+)")
  if n ~= 1 then return nil end
  return p
end
local PATRONES_APRENDIDO = {}
for _, clave in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S" }) do
  local p = Patron(_G[clave])
  if p then table.insert(PATRONES_APRENDIDO, p) end
end

local function AlMensajeDelSistema(texto)
  Indices()
  if not (#PATRONES_APRENDIDO > 0 and next(dondeDe) and type(texto) == "string") then return end
  for _, patron in ipairs(PATRONES_APRENDIDO) do
    local m = string.match(texto, patron)
    local id = m and tonumber(string.match(m, "|Hspell:(%d+)"))
    if id then
      if dondeDe[id] and Apuntar(id) and GL.RefrescarHechizos then GL.RefrescarHechizos() end
      return
    end
  end
end

local function MostrarPanel()
  local ok, err = pcall(Actualizar)
  if ok then
    Colocar()
    panel:Show()
  elseif GL.Fallo(L"panel del instructor", err) then
    GL.Mensaje(L"error: " .. tostring(err))
  end
end

local function CompraAutomatica()
  if not (sesionAbierta and autoSesion and GL.RUTA and GL.RUTA == rutaSesion) then return end
  if not AutoActivo() or oleadas >= MAX_OLEADAS then return end
  if not EsInstructorDeClase() or (dondeDe and next(dondeDe) and EsAdiestramiento()) then return end
  oleadas = oleadas + 1
  local ok, n = pcall(AprenderRecomendado, false)
  if not ok and GL.Fallo("instructor", n) then GL.Mensaje(L"error: " .. tostring(n)) end
end

local function ProgramarCompra()
  if not (sesionAbierta and autoSesion and AutoActivo()) or compraPendiente then return end
  local sesion = sesionInstructor
  local function ejecutar()
    if compraPendiente ~= ejecutar then return end
    compraPendiente = nil
    if sesion == sesionInstructor then CompraAutomatica() end
  end
  compraPendiente = ejecutar
  if C_Timer and C_Timer.After then C_Timer.After(0.3, ejecutar) else ejecutar() end
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "TRAINER_SHOW")
GL.Evento(eventos, "TRAINER_UPDATE")
GL.Evento(eventos, "TRAINER_CLOSED")
GL.Evento(eventos, "CHAT_MSG_SYSTEM")
eventos:SetScript("OnEvent", function(self, event, texto)
  if event == "TRAINER_SHOW" or event == "TRAINER_CLOSED" then
    sesionInstructor = sesionInstructor + 1
    sesionAbierta, autoSesion, compraPendiente = false, false, nil
    rutaSesion, comprando = nil, false
  end
  if event == "TRAINER_CLOSED" then
    if panel then panel:Hide() end
    comprando = false
    return
  end
  if not GL.RUTA then return end
  if event == "CHAT_MSG_SYSTEM" then
    pcall(AlMensajeDelSistema, texto)
    return
  end
  local ok, nuevo = pcall(ApuntarDeLaVentana)
  if ok and nuevo and GL.RefrescarHechizos then GL.RefrescarHechizos() end
  if not EsInstructorDeClase() or (dondeDe and next(dondeDe) and EsAdiestramiento()) then
    if panel then panel:Hide() end
    return
  end
  if event == "TRAINER_SHOW" then
    oleadas = 0
    comprando = false
    local conMayus = IsShiftKeyDown and IsShiftKeyDown()
    sesionAbierta, autoSesion, rutaSesion = true, not conMayus, GL.RUTA
    if DB().instructor ~= false then MostrarPanel() end
    ProgramarCompra()
    return
  end
  -- TRAINER_UPDATE: la lista cambió (por ejemplo tras comprar); comprar un rango puede abrir el siguiente
  if panel and panel:IsShown() then MostrarPanel() end
  if comprando then
    comprando = false
    ProgramarCompra()
  end
end)

GL.AprenderRecomendado = AprenderRecomendado
GL.NombreHechizo, GL.RangoHechizo, GL.ConsejoHechizo, GL.Dinero = NombreHechizo, RangoHechizo, Consejo, Dinero
GL.DondeHechizo, GL.ConocidoFuera = DondeHechizo, ConocidoFuera
GL.NivelHabilidad, GL.NombreHabilidad = NivelHabilidad, NombreHabilidad

GL.comandos["instructor"] = function()
  local db = DB()
  db.instructor = (db.instructor == false)
  GL.Mensaje(L"ayuda en los instructores " .. (db.instructor and L"activada." or L"desactivada."))
end

GL.comandos["autohechizos"] = function()
  local db = DB()
  db.autoHechizos = (db.autoHechizos == false)
  GL.Mensaje(db.autoHechizos and L"aprender solo lo recomendado en el instructor: activado (Mayús al abrirlo para no hacerlo)."
    or L"aprender solo lo recomendado en el instructor: desactivado (usa el botón del panel).")
end

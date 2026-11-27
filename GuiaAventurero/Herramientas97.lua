-- Herramientas97.lua: consultas no invasivas de profesiones, mazmorras y biblioteca.
-- No altera las misiones, el botin, las recetas ni la configuracion del personaje.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L
local function Mostrar(lineas)
  local texto = table.concat(lineas, "\n")
  if GL.MostrarInforme then
    local ok = pcall(GL.MostrarInforme, texto)
    if ok then return texto end
  end
  if GL.Mensaje then for _, linea in ipairs(lineas) do GL.Mensaje(linea) end end
  return texto
end
local function Nivel(prof)
  if type(GL.NivelProfesion) ~= "function" then return nil end
  local ok, nivel = pcall(GL.NivelProfesion, prof)
  return ok and tonumber(nivel) or nil
end
local function Contar(id)
  local cantidad = GL.BolsasProfesion975 and GL.BolsasProfesion975(id)
  return cantidad or 0, cantidad ~= nil
end
local function PlanMateriales()
  local lineas = { L"MATERIALES DE PROFESIONES" }
  local lista = GL.RUTA and GL.RUTA.profesiones or {}
  local vistos = 0
  for _, prof in ipairs(lista) do
    local nv = Nivel(prof)
    if nv then
      local paso
      for _, p in ipairs(prof.pasos or {}) do
        if nv >= (tonumber(p.d) or 0) and nv < (tonumber(p.h) or 0) then paso = p; break end
      end
      if paso then
        vistos = vistos + 1
        lineas[#lineas+1] = tostring(prof.nombre or "?") .. " " .. tostring(nv) .. "/300 (" .. tostring(paso.d) .. "-" .. tostring(paso.h) .. ")"
        local mat = paso.mat or {}
        if #mat == 0 then lineas[#lineas+1] = L"Este tramo no tiene materiales identificados." end
        local materiales, incompleto=GL.MaterialesTramo975(paso,nv)
        for _,m in ipairs(materiales) do
          local tengo, disponible=Contar(m.id)
          local necesario=m.incompleto and (m.cantidad>0 and (m.cantidad.."+?") or "?") or tostring(m.cantidad)
          lineas[#lineas+1]="  "..L(m.nombre)..": "..(disponible and tostring(tengo) or "?").."/"..necesario..
            (disponible and not m.incompleto and (" ("..L"faltan "..math.max(0,m.cantidad-tengo)..")") or "")
        end
        if incompleto then lineas[#lineas+1]=L"Cantidad necesaria sin confirmar." end
      end
    end
  end
  if vistos == 0 then lineas[#lineas+1] = L"No hay un tramo de profesión activo en esta ruta." end
  -- Mostrar la recolección realmente aprendida por el personaje, sin inventar
  -- la procedencia de los ingredientes de una receta.
  if type(GL.MisRecolecciones) == "function" then
    local ok, circuitos = pcall(GL.MisRecolecciones)
    if ok and type(circuitos) == "table" then
      for _, dato in ipairs(circuitos) do
        local zona = dato.zonas and dato.zonas[1]
        if zona then
          lineas[#lineas+1] = L"Recolección disponible: " .. tostring(dato.prof.nombre or "?") ..
            " (" .. tostring(dato.nivel or "?") .. ") - " .. tostring(zona.nombre or "?") ..
            L". Para seguir el circuito usa /ga recoleccion."
        end
      end
    end
  end
  lineas[#lineas+1] = L"Las cantidades son estimadas: una receta puede no conceder puntos de habilidad. Solo cuentan las bolsas; consulta la lista de compra para incluir el banco abierto."
  lineas[#lineas+1] = L"Las alternativas y el coste dependen de las recetas aprendidas y los precios de tu reino. Míralo en el plan y la Lista de compra de la tarjeta de la profesión."
  return lineas
end
local function DatosMazmorras()
  if not GL.DatosMazmorras then return {} end
  local ok, r = pcall(GL.DatosMazmorras)
  return ok and type(r) == "table" and r or {}
end
local function PreparaMazmorra(buscar)
  local lista = DatosMazmorras()
  local nivel = UnitLevel and tonumber(UnitLevel("player")) or 1
  local nombre = tostring(buscar or ""):lower()
  local lineas = { L"PREPARACIÓN DE MAZMORRAS" }
  local n = 0
  for _, m in ipairs(lista) do
    if (nombre ~= "" and tostring(m.n or ""):lower():find(nombre, 1, true)) or
       (nombre == "" and nivel >= (tonumber(m.min) or 1) and nivel <= (tonumber(m.max) or 60)) then
      n = n + 1
      if n > 5 then break end
      lineas[#lineas+1] = tostring(m.n or "?") .. " (" .. tostring(m.min or "?") .. "-" .. tostring(m.max or "?") .. ")"
      if m.z then lineas[#lineas+1] = "  " .. tostring(m.z) end
      if m.nota then lineas[#lineas+1] = "  " .. tostring(m.nota) end
      if m.e then lineas[#lineas+1] = "  " .. L"Entrada: mapa " .. tostring(m.e.m) .. " (" .. tostring(m.e.x) .. ", " .. tostring(m.e.y) .. ")" end
      for _, q in ipairs(m.misiones or {}) do
        local id = tonumber(q.q)
        local terminada = id and GL.MisionCompletada and GL.MisionCompletada(id)
        local diario = id and GL.MisionEnDiario and GL.MisionEnDiario(id)
        local estado = terminada and L"hecha" or diario and L"en diario" or L"revisar disponibilidad"
        lineas[#lineas+1] = "  [" .. estado .. "] " .. tostring(q.n or "?") .. (id and (" #" .. id) or "")
      end
    end
  end
  if n == 0 then lineas[#lineas+1] = L"No se encontró una mazmorra para el criterio indicado." end
  lineas[#lineas+1] = L"La lista es orientativa: comprueba facción, acceso, cadena previa y nivel del grupo dentro del juego."
  return lineas
end
local function Buscar(consulta)
  local normalizar = GL.NormalizarBusqueda97 or function(t) return tostring(t or ""):lower():match("^%s*(.-)%s*$") end
  local texto = normalizar(consulta)
  if #texto < 2 then return { L"Escribe al menos dos letras." } end
  local lineas = { L"RESULTADOS DE BÚSQUEDA" }
  local grupos, vistos = {{}, {}, {}}, {}
  local function Agregar(tipo, nombre)
    local n = normalizar(nombre)
    if n == "" then return end
    local rango = GL.PuntuacionBusqueda97 and GL.PuntuacionBusqueda97(nombre, texto)
    if not GL.PuntuacionBusqueda97 then rango = n == texto and 1 or n:find(texto, 1, true) == 1 and 2 or n:find(texto, 1, true) and 3 end
    local clave = tipo .. "\031" .. n
    if rango and not vistos[clave] then
      vistos[clave] = true
      grupos[rango][#grupos[rango]+1] = "[" .. tipo .. "] " .. tostring(nombre)
    end
  end
  for _, p in ipairs((GL.RUTA and GL.RUTA.profesiones) or {}) do Agregar(L"Profesión", p.nombre) end
  for _, m in ipairs(DatosMazmorras()) do
    Agregar(L"Mazmorra", m.n)
    for _, q in ipairs(m.misiones or {}) do Agregar(L"Misión", q.n) end
  end
  -- Solo nombres de la ruta activa; no se precargan las otras 46 rutas.
  for _, s in ipairs((GL.RUTA and GL.RUTA.secciones) or {}) do
    for _, paso in ipairs(s.pasos or {}) do
      for _, d in ipairs(paso.wp or {}) do Agregar(L"Destino", d.n) end
    end
  end
  for _, grupo in ipairs(grupos) do
    for _, linea in ipairs(grupo) do
      if #lineas >= 16 then return lineas end
      lineas[#lineas+1] = linea
    end
  end
  if #lineas == 1 then lineas[#lineas+1] = L"No hay coincidencias en la ruta, profesiones y mazmorras cargadas." end
  return lineas
end

local function Rendimiento()
  -- Consulta manual: no añade OnUpdate ni mide CPU de forma artificial.
  local lineas = { L"DIAGNÓSTICO BÁSICO" }
  local memoria = collectgarbage and math.floor(collectgarbage("count") + 0.5) or "?"
  lineas[#lineas+1] = L"Memoria Lua aproximada (KB): " .. tostring(memoria)
  if type(UpdateAddOnMemoryUsage) == "function" and type(GetAddOnMemoryUsage) == "function" then
    local actualizado = pcall(UpdateAddOnMemoryUsage)
    if actualizado then
      local ok, kb = pcall(GetAddOnMemoryUsage, "GuiaAventurero")
      if ok and type(kb) == "number" then
        lineas[#lineas+1] = L"Memoria estimada del addon (KB): " .. tostring(math.floor(kb + 0.5))
      end
    end
  end
  -- La instrumentación del cliente puede estar desactivada. No la activamos
  -- automáticamente porque requiere recargar y tiene coste de rendimiento.
  local perfilado = false
  if type(GetCVar) == "function" then
    local ok, valor = pcall(GetCVar, "scriptProfile")
    perfilado = ok and tostring(valor) == "1"
  end
  if perfilado and type(UpdateAddOnCPUUsage) == "function" and type(GetAddOnCPUUsage) == "function" then
    local ok = pcall(UpdateAddOnCPUUsage)
    if ok then
      local ok2, ms = pcall(GetAddOnCPUUsage, "GuiaAventurero")
      if ok2 and type(ms) == "number" then
        lineas[#lineas+1] = L"CPU acumulada del addon desde el inicio (ms): " .. tostring(math.floor(ms * 100 + 0.5) / 100)
      end
    end
  else
    lineas[#lineas+1] = L"CPU: sin datos. Activa el perfilado de addons en el cliente y recarga si quieres medirla; este comando no activa el perfilado."
  end
  lineas[#lineas+1] = L"Esta cifra no mide la CPU ni demuestra que todo el addon esté optimizado."
  lineas[#lineas+1] = L"Para medir rendimiento real, utiliza las herramientas del cliente WoW."
  return lineas
end

GL.Materiales97 = PlanMateriales
GL.Preparacion97 = PreparaMazmorra
GL.BuscarGlobal97 = Buscar
GL.Rendimiento97 = Rendimiento
GL.comandos = GL.comandos or {}
-- 9.7.6: /ga materiales quitado (lo hace el botón Lista de compra de la profesión)
GL.comandos["preparar"] = function(arg) Mostrar(PreparaMazmorra(arg)) end
GL.comandos["buscar"] = function(arg) Mostrar(Buscar(arg)) end
GL.comandos["rendimiento"] = function() Mostrar(Rendimiento()) end

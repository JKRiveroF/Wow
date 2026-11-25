-- Talentos.lua: pone solos los talentos de la guía al subir de nivel. Creado por JKRiveroF.
-- WoW Forever guarda los talentos con el sistema de rasgos del juego (C_Traits): cada talento es un nodo del árbol.
-- La guía busca cada talento del plan por su nombre (en español o en inglés) y gasta los puntos libres
-- en el mismo orden que el plan. Nunca quita puntos: si repartiste otros, solo sigue con lo que falte.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local pendiente = false               -- había que ponerlos en combate: se hace al salir
local ultimoIntento = -10
local avisado                         -- nivel en el que ya se avisó de que algo no se pudo poner
local aplicando                       -- momento en que la guía pidió aplicar los talentos (para reintentar si falla)
local configAplicando, rutaAplicando
local reintentos = 0

local function DB() return type(GuiaAventureroDB) == "table" and GuiaAventureroDB or nil end
local function Activo()
  local db = DB()
  return db ~= nil and db.autoTalentos ~= false and not (GL.EspecializacionPendiente and GL.EspecializacionPendiente())
end

-- "Descarga de Escarcha mejorada (Improved Frostbolt)" -> nombre en español y en inglés, sin tildes ni signos.
local TILDES = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
  ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n" }
local function Normalizar(s)
  s = string.lower(s or "")
  for k, v in pairs(TILDES) do s = string.gsub(s, k, v) end
  return (string.gsub(s, "[^%a%d]", ""))
end

local function NombresDelPlan(t)
  local es, en = string.match(t.nombre or "", "^(.-)%s*%((.-)%)%s*$")
  if not es then es = t.nombre end
  return Normalizar(es), en and Normalizar(en) or nil
end

-- Orden de los puntos del plan: { talento, rango } uno por punto.
local function Secuencia()
  local lista, hecho = {}, {}
  local talentos = GL.RUTA and GL.RUTA.talentos or {}
  for i = 1, #talentos do
    local t = talentos[i]
    local hasta = tonumber(string.match(t.puntos or "", "^(%d+)")) or 0
    local desde = hecho[t.nombre] or 0
    for r = desde + 1, hasta do table.insert(lista, { t = t, rango = r }) end
    if hasta > desde then hecho[t.nombre] = hasta end
  end
  return lista
end

------------------------------------------------------------------------
-- Árbol de talentos del personaje
------------------------------------------------------------------------
local function ConfigValida(id)
  if not id or not (C_Traits and C_Traits.GetConfigInfo) then return nil end
  local ok, info = pcall(C_Traits.GetConfigInfo, id)
  if ok and type(info) == "table" and type(info.treeIDs) == "table" and #info.treeIDs > 0 then return id, info end
  return nil
end

-- El árbol activo: Forever tiene su propio tipo de configuración (CamelotCombat), con alternativas por si cambia.
local function Configuracion()
  local si = C_SpecializationInfo
  if si and si.GetCombatConfigIDForSpecGroup then
    local grupo = 1
    if si.GetActiveSpecGroup then
      local ok, g = pcall(si.GetActiveSpecGroup)
      if ok and g then grupo = g end
    end
    local ok, id = pcall(si.GetCombatConfigIDForSpecGroup, grupo)
    local c, info = ConfigValida(ok and id)
    if c then return c, info end
  end
  if C_Traits and C_Traits.GetConfigsByType and Enum and Enum.TraitConfigType then
    local tipo = Enum.TraitConfigType.CamelotCombat or Enum.TraitConfigType.Combat
    local ok, ids = pcall(C_Traits.GetConfigsByType, tipo)
    if ok and type(ids) == "table" then
      for i = 1, #ids do
        local c, info = ConfigValida(ids[i])
        if c then return c, info end
      end
    end
  end
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
    local c, info = ConfigValida(ok and id)
    if c then return c, info end
  end
  return nil
end

-- Nombre e icono (número de archivo) del talento de una entrada del árbol.
local function NombreNodo(config, entrada)
  local ok, e = pcall(C_Traits.GetEntryInfo, config, entrada)
  if not ok or type(e) ~= "table" or not e.definitionID then return nil end
  local ok2, d = pcall(C_Traits.GetDefinitionInfo, e.definitionID)
  if not ok2 or type(d) ~= "table" then return nil end
  local icono = d.overrideIcon
  if (not icono or icono == 0) and d.spellID and C_Spell and C_Spell.GetSpellTexture then
    local ok3, t = pcall(C_Spell.GetSpellTexture, d.spellID)
    if ok3 then icono = t end
  end
  if d.overrideName and d.overrideName ~= "" then return d.overrideName, icono end
  if d.spellID and C_Spell and C_Spell.GetSpellName then
    local ok3, n = pcall(C_Spell.GetSpellName, d.spellID)
    if ok3 then return n, icono end
  end
  return nil, icono
end

-- Talentos visibles del árbol: por nombre normalizado y por icono (solo los iconos que no se repiten).
local function MapaNodos(config, info)
  local mapa, iconos = {}, {}
  for _, arbol in ipairs(info.treeIDs) do
    local ok, nodos = pcall(C_Traits.GetTreeNodes, arbol)
    if ok and type(nodos) == "table" then
      for _, nodo in ipairs(nodos) do
        local ok2, n = pcall(C_Traits.GetNodeInfo, config, nodo)
        if ok2 and type(n) == "table" and n.ID and n.ID ~= 0 and n.isVisible ~= false then
          for _, entrada in ipairs(n.entryIDs or {}) do
            local nombre, icono = NombreNodo(config, entrada)
            local dato = { nodo = nodo, entrada = entrada, nombre = nombre }
            if nombre and nombre ~= "" then
              local clave = Normalizar(nombre)
              if not mapa[clave] then mapa[clave] = dato end
            end
            if icono and icono ~= 0 then
              if iconos[icono] == nil then iconos[icono] = dato
              elseif iconos[icono] and iconos[icono].nodo ~= nodo then iconos[icono] = false end
            end
          end
        end
      end
    end
  end
  return mapa, iconos
end

-- Si el nombre no coincide (otra traducción), se prueba con el icono del plan, siempre que sea único en el árbol
-- y que ese talento no sea otro de los del plan.
local function BuscarPorIcono(t, iconos, mapa, nombresPlan)
  if not (t.icono and GetFileIDFromPath) then return nil end
  local ok, id = pcall(GetFileIDFromPath, t.icono)
  if not ok or not id then return nil end
  local dato = iconos[id]
  if not dato then return nil end
  local clave = dato.nombre and Normalizar(dato.nombre)
  if clave and nombresPlan[clave] then return nil end
  return dato
end

local function PuntosLibres(config, info)
  if not C_Traits.GetTreeCurrencyInfo then return nil end
  local total, alguno = 0, false
  for _, arbol in ipairs(info.treeIDs) do
    local ok, monedas = pcall(C_Traits.GetTreeCurrencyInfo, config, arbol, false)
    if not ok or type(monedas) ~= "table" then return nil end
    for _, m in ipairs(monedas) do
      if type(m) ~= "table" then return nil end
      local q = m.quantity
      if (issecretvalue and issecretvalue(q)) or type(q) ~= "number" or q < 0 or q >= math.huge or q % 1 ~= 0 then return nil end
      total = total + q; alguno = true
    end
  end
  return alguno and total or nil
end

local function RangoValido(v)
  return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v >= 0 and v < math.huge and v % 1 == 0
end

local function RangoActual(config, nodo)
  local ok, n = pcall(C_Traits.GetNodeInfo, config, nodo)
  if not ok or type(n) ~= "table" then return 0, nil end
  local rango = n.currentRank
  if issecretvalue and issecretvalue(rango) then return 0, nil end
  if rango == nil then rango = n.ranksPurchased end
  if not RangoValido(rango) then return 0, nil end
  return rango, n
end

-- La ventana de talentos del juego aplica con C_ClassTalents.CommitConfig (con la configuración guardada que
-- tengas elegida); si el árbol no es ese, se usa el sistema general de rasgos.
local function Guardada()
  local ct = C_ClassTalents
  if not (ct and ct.GetLastSelectedSavedConfigID and PlayerUtil and PlayerUtil.GetCurrentSpecID) then return nil end
  local ok, spec = pcall(PlayerUtil.GetCurrentSpecID)
  if not ok or not spec then return nil end
  local ok2, id = pcall(ct.GetLastSelectedSavedConfigID, spec)
  if ok2 and type(id) == "number" and id > 0 then return id end
  return nil
end

local function Aplicar(config)
  local ct = C_ClassTalents
  if ct and ct.CommitConfig and ct.GetActiveConfigID then
    local okA, activa = pcall(ct.GetActiveConfigID)
    if okA and activa == config then
      local guardada = Guardada()
      if guardada == config then guardada = nil end
      local ok, r = pcall(ct.CommitConfig, guardada)
      if ok and r then return true end
    end
  end
  if C_Traits.CommitConfig then
    local ok, r = pcall(C_Traits.CommitConfig, config)
    if ok and r then return true end
  end
  return false
end

------------------------------------------------------------------------
-- Poner los puntos libres siguiendo el plan
------------------------------------------------------------------------
-- manual = true cuando lo pide el jugador (botón o comando): entonces explica también por qué no hace nada.
function GL.PonerTalentos(manual)
  local function Decir(t) if manual then GL.Mensaje(t) end end
  if not (GL.RUTA and GL.RUTA.talentos and #GL.RUTA.talentos > 0) then return 0 end
  if InCombatLockdown and InCombatLockdown() then
    pendiente = true
    Decir(L"estás en combate: pongo los talentos al salir.")
    return 0
  end
  if not (C_Traits and C_Traits.PurchaseRank and C_Traits.GetNodeInfo) then
    Decir(L"este cliente no deja poner talentos desde un addon: ponlos a mano siguiendo la pestaña Talentos.")
    return 0
  end
  local config, info = Configuracion()
  if not config then
    Decir(L"no encuentro tu árbol de talentos: ponlos a mano siguiendo la pestaña Talentos.")
    return 0
  end
  if C_Traits.ConfigHasStagedChanges then
    local ok, hay = pcall(C_Traits.ConfigHasStagedChanges, config)
    if ok and hay then
      Decir(L"tienes cambios sin aplicar en la ventana de talentos: aplícalos o deshazlos y vuelve a probar.")
      return 0
    end
  end
  local libres = PuntosLibres(config, info)
  if libres == 0 then
    Decir(L"no tienes puntos de talento libres.")
    return 0
  end
  local mapa, iconos = MapaNodos(config, info)
  local secuencia = Secuencia()
  local nombresPlan = {}
  for _, paso in ipairs(secuencia) do
    local es, en = NombresDelPlan(paso.t)
    nombresPlan[es] = true
    if en then nombresPlan[en] = true end
  end
  local puestos, motivo = {}, nil
  local restantes = libres            -- nil si el juego no dice cuántos puntos quedan
  for _, paso in ipairs(secuencia) do
    if restantes and restantes <= 0 then break end
    local es, en = NombresDelPlan(paso.t)
    local nodo = mapa[es] or (en and mapa[en]) or BuscarPorIcono(paso.t, iconos, mapa, nombresPlan)
    local flexible = GL.RUTA.planFlexible   -- 9.4: especialización elegida; en Forever el árbol puede no tenerlo
    if not nodo then
      motivo = L"no encuentro el talento " .. paso.t.nombre .. L" en tu árbol"
      if not flexible then break end
    end
    local actual, n = 0, nil
    if nodo then
      actual, n = RangoActual(config, nodo.nodo)
      if not n then break end
    end
    local ok, puede = false, false
    if nodo and actual < paso.rango then ok, puede = pcall(C_Traits.CanPurchaseRank, config, nodo.nodo, nodo.entrada) end
    if nodo and actual < paso.rango and not (ok and puede) then
      if (PuntosLibres(config, info) or 1) > 0 then motivo = L"no puedo poner " .. paso.t.nombre .. L" todavía" end
      if not flexible then break end
    elseif nodo and actual < paso.rango then
      local okP, hecho
      if n and n.type ~= nil and Enum and Enum.TraitNodeType and n.type == Enum.TraitNodeType.Selection then   -- 9.6: sin tipo no es «elegir uno»
        okP, hecho = pcall(C_Traits.SetSelection, config, nodo.nodo, nodo.entrada)
      else
        okP, hecho = pcall(C_Traits.PurchaseRank, config, nodo.nodo)
      end
      if not (okP and hecho) then
        motivo = L"el juego no me deja poner " .. paso.t.nombre
        break
      end
      table.insert(puestos, paso)
      if restantes then restantes = restantes - 1 end
    end
  end
  if #puestos == 0 then
    if motivo then
      -- también en automático, pero una sola vez por nivel, para que sepas que hay que ponerlo a mano
      local nivel = (UnitLevel and UnitLevel("player")) or 0
      if manual or avisado ~= nivel then
        avisado = nivel
        GL.Mensaje(motivo .. L". Ponlo a mano o revisa la pestaña Talentos.")
      end
    else
      Decir(L"ya tienes puestos todos los talentos del plan para tus puntos.")
    end
    return 0
  end
  if not Aplicar(config) then
    if C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, config) end
    aplicando, configAplicando, rutaAplicando = nil, nil, nil
    GL.Mensaje(L"no he podido aplicar los talentos. Ponlos a mano: " .. puestos[1].t.nombre ..
      (#puestos > 1 and (L" y " .. (#puestos - 1) .. L" punto(s) más de la pestaña Talentos.") or "."))
    return 0
  end
  -- resumen: "Descarga de Escarcha mejorada 3/5"
  local partes, visto = {}, {}
  for _, paso in ipairs(puestos) do
    local maximo = string.match(paso.t.puntos or "", "/(%d+)") or "?"
    local nombre = string.match(paso.t.nombre, "^(.-)%s*%(") or paso.t.nombre
    visto[nombre] = paso.rango .. "/" .. maximo
  end
  for _, paso in ipairs(puestos) do
    local nombre = string.match(paso.t.nombre, "^(.-)%s*%(") or paso.t.nombre
    if visto[nombre] then table.insert(partes, nombre .. " " .. visto[nombre]); visto[nombre] = nil end
  end
  aplicando = (GetTime and GetTime()) or 0
  configAplicando, rutaAplicando = config, GL.RUTA
  GL.Mensaje(L"talentos de la guía puestos: " .. table.concat(partes, ", ") .. ".")
  if motivo then GL.Mensaje(motivo .. L": ponlo a mano o revisa la pestaña Talentos.") end
  if GL.Refrescar then GL.Refrescar() end
  return #puestos
end

function GL.AutoTalentos() return Activo() end

-- 9.6: puntos libres para la tarjeta «Ahora» de la pestaña Talentos (nil si el juego no lo dice)
function GL.PuntosTalentoLibres()
  if not (C_Traits and C_Traits.GetConfigInfo) then return nil end
  local ok, config, info = pcall(Configuracion)
  if not ok or not config or type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end
  local ok2, n = pcall(PuntosLibres, config, info)
  if ok2 then return n end
  return nil
end
GL.Normalizar = Normalizar

-- 9.7.7.1: puntos que tienes de verdad en cada rama. Quini tenía 12 puntos en Furia y la guía seguía el plan de
-- Armas (los puntos de las ramas eran los del plan). Cada talento con puntos se asigna a una rama por su nombre
-- (plan de la ruta y talentos clave de las especializaciones); si el juego da un árbol por rama, los que no
-- salen por nombre van a la rama de su árbol. Devuelve { ramas = { [rama] = puntos }, total = n } o nil.
local function RamasPorNombre()
  local mapa = {}
  local function Poner(nombre, rama)
    if type(nombre) ~= "string" or type(rama) ~= "string" then return end
    local es, en = string.match(nombre, "^(.-)%s*%((.-)%)%s*$")
    for _, n in ipairs({ es or nombre, en }) do
      if n and n ~= "" then local k = Normalizar(n); if mapa[k] == nil then mapa[k] = rama end end
    end
  end
  -- primero el plan original de la ruta (rama segura), después el plan en uso y las especializaciones
  for _, t in ipairs((GL.TalentosDeLaGuia and GL.TalentosDeLaGuia()) or {}) do Poner(t.nombre, t.rama) end
  for _, t in ipairs((GL.RUTA and GL.RUTA.talentos) or {}) do Poner(t.nombre, t.rama) end
  local clase = UnitClass and select(2, UnitClass("player"))
  for _, e in ipairs((GL.ESPECIALIZACIONES or {})[clase or ""] or {}) do
    for _, p in ipairs(e.plan or {}) do Poner(p[1], GL.L(p[3] or e.rama)) end
  end
  return mapa
end

local function PuntosRealesPorRama()
  if not (C_Traits and C_Traits.GetNodeInfo and C_Traits.GetTreeNodes) then return nil end
  local ok, config, info = pcall(Configuracion)
  if not ok or not config or type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end
  local porNombre = RamasPorNombre()
  local ramas, total, alguno, vistos = {}, 0, false, {}
  for _, arbol in ipairs(info.treeIDs) do
    local okN, nodos = pcall(C_Traits.GetTreeNodes, arbol)
    if okN and type(nodos) == "table" then
      local votos, sinRama = {}, 0
      for _, nodo in ipairs(nodos) do
        local okI, n = pcall(C_Traits.GetNodeInfo, config, nodo)
        if not okI or type(n) ~= "table" then return nil end
        if n.ID and n.ID ~= 0 and n.isVisible ~= false and not vistos[n.ID] then
          vistos[n.ID] = true
          alguno = true
          local rango = n.ranksPurchased
          if issecretvalue and issecretvalue(rango) then return nil end
          if rango == nil then rango = n.currentRank end
          if not RangoValido(rango) then return nil end
          local entrada = (type(n.activeEntry) == "table" and n.activeEntry.entryID) or (n.entryIDs and n.entryIDs[1])
          local nombre = entrada and NombreNodo(config, entrada)
          local rama = nombre and porNombre[Normalizar(nombre)]
          if rama then votos[rama] = (votos[rama] or 0) + 1 end
          if rango > 0 then
            total = total + rango
            if rama then ramas[rama] = (ramas[rama] or 0) + rango else sinRama = sinRama + rango end
          end
        end
      end
      -- con varios árboles, lo que no sale por nombre es de la rama que más talentos tiene en ese árbol
      if sinRama > 0 and #info.treeIDs > 1 then
        local mejor, empate
        for r, v in pairs(votos) do
          if not mejor or v > votos[mejor] then mejor, empate = r, false
          elseif v == votos[mejor] then empate = true end
        end
        if mejor and not empate then ramas[mejor] = (ramas[mejor] or 0) + sinRama end
      end
    else return nil end
  end
  if not alguno then return nil end
  return { ramas = ramas, total = total }
end

-- 9.7.4: lo que llevas puesto de verdad. Para cada fila del plan, si ya tiene en tu árbol los puntos que pide
-- (aunque los pusieras antes de tiempo o en otro orden). Devuelve nil si el juego no deja leer el árbol:
-- entonces la pestaña sigue el plan por nivel, como antes.
function GL.PuntosRealesPorRama()
  local ok, resultado = pcall(PuntosRealesPorRama)
  if ok then return resultado end
end

local function EstadoTalentosReal()
  local talentos = GL.RUTA and GL.RUTA.talentos
  if not (talentos and #talentos > 0 and C_Traits and C_Traits.GetNodeInfo and C_Traits.GetTreeNodes) then return nil end
  local ok, config, info = pcall(Configuracion)
  if not ok or not config or type(info) ~= "table" then return nil end
  local okM, mapa, iconos = pcall(MapaNodos, config, info)
  if not okM or type(mapa) ~= "table" then return nil end
  local nombresPlan = {}
  for _, t in ipairs(talentos) do
    local es, en = NombresDelPlan(t)
    nombresPlan[es] = true
    if en then nombresPlan[en] = true end
  end
  local hecho, rango, encontrados = {}, {}, 0
  for i, t in ipairs(talentos) do
    local es, en = NombresDelPlan(t)
    local nodo = mapa[es] or (en and mapa[en]) or BuscarPorIcono(t, iconos, mapa, nombresPlan)
    local quiere = tonumber(string.match(t.puntos or "", "^(%d+)")) or 1
    if nodo then
      encontrados = encontrados + 1
      local actual, estado = RangoActual(config, nodo.nodo)
      if not estado then return nil end
      local comprado = estado.ranksPurchased
      if issecretvalue and issecretvalue(comprado) then return nil end
      if comprado ~= nil then
        if not RangoValido(comprado) then return nil end
        actual = comprado
      end
      if type(estado.activeEntry) == "table" and estado.activeEntry.entryID and estado.activeEntry.entryID ~= nodo.entrada then actual = 0 end
      rango[i] = actual
      hecho[i] = actual >= quiere
    else
      hecho[i] = false
    end
  end
  if encontrados == 0 then return nil end
  local primero
  for i = 1, #talentos do if not hecho[i] then primero = i; break end end
  return { hecho = hecho, rango = rango, primero = primero }
end

function GL.EstadoTalentosReal()
  local ok, resultado = pcall(EstadoTalentosReal)
  if ok then return resultado end
end

-- Al cambiar los talentos (también a mano en la ventana del juego) se repinta la pestaña.
do
  local f = CreateFrame("Frame")
  for _, ev in ipairs({ "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED" }) do pcall(f.RegisterEvent, f, ev) end
  local esperando = false
  f:SetScript("OnEvent", function()
    if esperando then return end
    esperando = true
    local function ya()
      esperando = false
      if GL.ComprobarEspecializacionReal then pcall(GL.ComprobarEspecializacionReal) end   -- 9.7.7.1
      if GL.Refrescar then pcall(GL.Refrescar) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, ya) else ya() end
  end)
end

local function Intentar()
  if not Activo() then return end
  local ahora = (GetTime and GetTime()) or 0
  if ahora - ultimoIntento < 1 then return end
  ultimoIntento = ahora
  local ok, err = pcall(GL.PonerTalentos, false)
  if not ok and GL.Fallo("talentos", err) then GL.Mensaje(L"error: " .. tostring(err)) end
end

local function Despues(segundos, f)
  if C_Timer and C_Timer.After then C_Timer.After(segundos, f) else f() end
end

-- Tras un fallo, no aplicar ni deshacer cambios preparados: pueden incluir cambios manuales del jugador.
-- Solo se vuelve a ejecutar el plan si el árbol y la ruta siguen siendo los originales y no hay cambios pendientes.
local function Reintentar(ruta, configAnterior)
  if not (ruta and GL.RUTA == ruta and Activo()) then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local ok, config = pcall(Configuracion)
  if not ok or not config or config ~= configAnterior or not (C_Traits and C_Traits.ConfigHasStagedChanges) then return end
  local ok2, hay = pcall(C_Traits.ConfigHasStagedChanges, config)
  if not ok2 or hay ~= false then
    GL.Mensaje(L"el juego no aplicó los talentos. Pulsa 'Poner talentos' en la pestaña Talentos o ponlos a mano.")
    return
  end
  ultimoIntento = -10
  local ok3, err = pcall(GL.PonerTalentos, false)
  if not ok3 and GL.Fallo("talentos", err) then GL.Mensaje(L"error: " .. tostring(err)) end
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "PLAYER_LEVEL_UP")
GL.Evento(eventos, "PLAYER_REGEN_ENABLED")
GL.Evento(eventos, "PLAYER_ENTERING_WORLD")
pcall(eventos.RegisterEvent, eventos, "CONFIG_COMMIT_FAILED")
eventos:SetScript("OnEvent", function(self, event, ...)
  if not GL.RUTA then return end
  if event == "PLAYER_LEVEL_UP" then
    -- el punto nuevo llega un momento después de subir: se prueba varias veces
    reintentos = 0
    Despues(2, Intentar)
    Despues(6, Intentar)
    Despues(12, Intentar)
  elseif event == "CONFIG_COMMIT_FAILED" then
    -- el juego no aplicó lo que pidió la guía (por ejemplo, te moviste o entraste en combate): se reintenta una vez
    local ahora = (GetTime and GetTime()) or 0
    if aplicando and ahora - aplicando < 30 then
      local ruta, config = rutaAplicando, configAplicando
      aplicando, configAplicando, rutaAplicando = nil, nil, nil
      if reintentos < 1 and ruta == GL.RUTA and config and Activo() then
        reintentos = reintentos + 1
        GL.Mensaje(L"el juego no aplicó los talentos: lo intento otra vez en unos segundos.")
        Despues(4, function() Reintentar(ruta, config) end)
      else
        GL.Mensaje(L"el juego no aplicó los talentos. Pulsa 'Poner talentos' en la pestaña Talentos o ponlos a mano.")
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendiente then
      pendiente = false
      Despues(1, Intentar)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- al entrar solo se avisa: los puntos libres pueden ser a propósito
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    Despues(8, function()
      local libres = GL.PuntosTalentoLibres()
      if libres and libres > 0 then
        GL.Mensaje(L"tienes " .. libres .. L" punto(s) de talento libres. Pulsa 'Poner talentos' en la pestaña Talentos " ..
          L"para ponerlos como dice la guía.")
      end
    end)
  end
end)

GL.comandos["ponertalentos"] = function() GL.PonerTalentos(true) end
GL.comandos["autotalentos"] = function()
  local db = DB()
  if not db then return end
  db.autoTalentos = (db.autoTalentos == false)
  GL.Mensaje(db.autoTalentos and L"poner los talentos de la guía al subir de nivel: activado."
    or L"poner los talentos de la guía al subir de nivel: desactivado (usa el botón Poner talentos).")
end

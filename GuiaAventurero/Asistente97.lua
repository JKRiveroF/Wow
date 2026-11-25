-- Asistente97.lua: perfiles opcionales, comprobacion contextual y convivencia con Questie.
-- Solo lectura del diario y del paso; nunca acepta, abandona ni completa misiones.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L
local function DB() return type(GuiaAventureroDB) == "table" and GuiaAventureroDB or nil end
local function Decir(t) if GL.Mensaje then GL.Mensaje(t) end end

local AUTO = { "auto", "autoDestino", "autoMisiones", "autoHechizos", "autoRecetas", "autoVender", "autoTalentos" }
local function PonerPerfil(tipo)
  local db = DB()
  if not db then return false, "sin_configuracion" end
  local modos = {
    principiante = { guiaClara = true,  estiloRuta = "completa", automaticos = false },
    normal      = { guiaClara = true,  estiloRuta = "normal",   automaticos = false },
    veterano    = { guiaClara = true,  estiloRuta = "completa", automaticos = true  },
  }
  local m = modos[tipo]
  if not m then return false, "perfil_desconocido" end
  -- Un perfil se aplica SOLO si el jugador lo solicita; no cambia la configuracion de otros personajes.
  -- Mantener todas las acciones potencialmente destructivas desactivadas incluso en Veterano.
  db.guiaClara = m.guiaClara
  db.estiloRuta = m.estiloRuta
  for _, k in ipairs(AUTO) do db[k] = m.automaticos end
  db.autoVender = false
  db.perfil97 = tipo
  if GL.Refrescar then GL.Refrescar() end
  if GL.ProgramarSync then GL.ProgramarSync() end
  return true
end
GL.AplicarPerfil97 = PonerPerfil

-- Diagnóstico de solo lectura: una API no disponible no equivale a una respuesta negativa.
local function Consultar(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end
local function EstadoMision(q)
  if Consultar(GL.MisionCompletada, q) == true then return L"completada" end
  if Consultar(GL.MisionEnDiario, q) == true then return L"en el diario" end
  local completada = Consultar(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted, q)
  if completada == true then return L"completada" end
  local indice = Consultar(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, q)
  if type(indice) == "number" and indice > 0 then return L"en el diario" end
  -- GetLogIndexForQuestID puede devolver nil tanto por ausencia como por falta de datos.
  local diario = Consultar(C_QuestLog and C_QuestLog.IsOnQuest, q)
  if diario == true then return L"en el diario" end
  if completada == false and (diario == false or indice == 0) then
    return L"sin aceptar o no disponible", true
  end
  return L"estado de misión sin confirmar"
end

local function TextoComprobacion()
  local db = DB()
  if not db then return L"El personaje todavía no ha cargado su configuración." end
  if not GL.PasoActual then return L"La ruta no está disponible todavía." end
  local s, p = GL.PasoActual()
  if not p then return L"No hay un paso de ruta activo." end
  local lineas = { L"COMPROBACIÓN DEL PASO", tostring(s and s.titulo or "") .. " · " .. tostring(db.paso or "?") }
  if p.t then lineas[#lineas+1] = tostring(p.t) end
  local datos = type(p.wp) == "table" and p.wp or {}
  local vistos = {}
  local n = 0
  for _, d in ipairs(datos) do
    local q = type(d) == "table" and tonumber(d.q)
    if q and q > 0 and q < math.huge and q % 1 == 0 and not vistos[q] then
      vistos[q] = true; n = n + 1
      local situacion, ausente = EstadoMision(q)
      lineas[#lineas+1] = tostring(q) .. " · " .. tostring(d.n or "") .. " · " .. situacion
      -- Solo informar: el campo de nivel en el texto de las misiones extra
      -- no equivale al nivel mínimo necesario para aceptarlas.
      if ausente and type(p.t) == "string" and
         (p.t:find("Misión extra", 1, true) or p.t:find("Extra quest", 1, true)) then
        lineas[#lineas+1] = L"Misión adicional: comprueba en el PNJ el nivel mínimo y la cadena anterior; el nivel mostrado por la ruta es orientativo."
      end
    end
  end
  if n == 0 then lineas[#lineas+1] = L"Este paso no contiene una misión con identificador." end
  lineas[#lineas+1] = L"Si una misión no aparece, comprueba sus requisitos y tu registro de misiones antes de saltarla."
  if db.pasoAnterior then lineas[#lineas+1] = L"Has vuelto a un paso anterior: Mi nivel te lleva al tuyo." end
  lineas[#lineas+1] = L"Para informar de un fallo utiliza /ga atascado y /ga informe."
  return table.concat(lineas, "\n")
end
GL.TextoComprobacion97 = TextoComprobacion
-- nil significa que ninguna API pudo determinar el estado; no equivale a descargado.
local function QuestieEstado()
  local function consultar(fn)
    if type(fn) ~= "function" then return nil end
    local ok, activo = pcall(fn, "Questie")
    if not ok then return nil end
    if issecretvalue then
      local comprobado, secreto = pcall(issecretvalue, activo)
      if not comprobado or secreto then return nil end
    end
    if activo == true or activo == 1 then return true end
    if activo == false or activo == 0 then return false end
    return nil
  end
  local activo = consultar(C_AddOns and C_AddOns.IsAddOnLoaded)
  if activo ~= nil then return activo end
  return consultar(IsAddOnLoaded)
end
local function QuestieActivo()
  return QuestieEstado() == true
end
GL.QuestieEstado97 = QuestieEstado
GL.QuestieActivo97 = QuestieActivo
GL.comandos = GL.comandos or {}
GL.comandos["perfil"] = function(parametro)
  local tipo = tostring(parametro or ""):lower():match("^%s*(.-)%s*$")
  if tipo == "" then
    Decir(L"Perfiles: /ga perfil principiante | normal | veterano. Se aplica solo a este personaje.")
    return
  end
  local aplicado, motivo = PonerPerfil(tipo)
  if aplicado then
    Decir(L"Perfil aplicado a este personaje: " .. (tipo == "principiante" and L"Principiante" or tipo == "veterano" and L"Veterano" or L"Perfil normal") .. L". Puedes cambiar cualquier ajuste manualmente.")
  elseif motivo == "sin_configuracion" then
    Decir(L"El personaje todavía no ha cargado su configuración.")
  else
    Decir(L"Perfil desconocido. Opciones: principiante, normal, veterano.")
  end
end
GL.comandos["comprobar"] = function()
  local t = TextoComprobacion()
  if GL.MostrarInforme then
    local ok = pcall(GL.MostrarInforme, t)
    if ok then return end
  end
  for linea in (t .. "\n"):gmatch("(.-)\n") do Decir(linea) end
end
-- 9.7.6: /ga compatibilidad quitado (lo dice /ga questie)
GL._asistente97 = { Texto = TextoComprobacion, Perfil = PonerPerfil, Questie = QuestieActivo }

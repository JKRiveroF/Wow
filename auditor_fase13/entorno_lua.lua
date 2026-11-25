local function entorno()
  local env = {
    assert = assert, error = error, ipairs = ipairs, next = next,
    pairs = pairs, select = select, tonumber = tonumber, tostring = tostring,
    type = type, unpack = unpack,
  }
  for nombre, biblioteca in pairs({ math = math, string = string, table = table }) do
    env[nombre] = {}
    for k, v in pairs(biblioteca) do env[nombre][k] = v end
  end
  env.GuiaAventurero_Rutas = {}
  return env
end

local function ejecutar(funcion, ...)
  local restante = 5000000
  debug.sethook(function()
    restante = restante - 10000
    if restante <= 0 then
      debug.sethook()
      error("se superó el límite de instrucciones de la prueba", 0)
    end
  end, "", 10000)
  local bien, resultado = pcall(funcion, ...)
  debug.sethook()
  if not bien then error(resultado, 0) end
  return resultado
end

local function entorno_motor()
  local env = entorno()
  env.GuiaAventureroDB = {}
  env.GL = {
    L = function(texto) return texto end,
    Raza = function() return env.raza end,
    erroresCarga = {},
  }
  env.UnitClass = function() return nil, env.clase end
  env.UnitFactionGroup = function() return env.faccion end
  env.Mensaje = function() end
  env.pcall = pcall
  env.collectgarbage = function() end
  return env
end

local function identidad_de_tabla()
  local ids, siguiente = {}, 0
  return function(tabla)
    if not ids[tabla] then
      siguiente = siguiente + 1
      ids[tabla] = siguiente
    end
    return ids[tabla]
  end
end

local function comprobar_filtro(funcion, ruta, raza)
  local comparaciones, prueba = {}, { secciones = {} }

  local function copiar(registros, destino, campo, etiqueta)
    local esperados = registros
    if type(registros) == "table" then
      destino[campo], esperados = {}, {}
      for i, registro in ipairs(registros) do
        destino[campo][i] = registro
        if not registro.raza or registro.raza == raza then
          esperados[#esperados + 1] = registro
        end
      end
    else
      destino[campo] = registros
    end
    comparaciones[#comparaciones + 1] = { destino, campo, esperados, etiqueta or campo }
  end

  local function validar(antes, despues)
    if type(antes) ~= "table" then return despues == antes end
    if type(despues) ~= "table" or #despues ~= #antes then return false end
    for i, registro in ipairs(antes) do
      if despues[i] ~= registro then return false end
    end
    return true
  end
  for i, seccion in ipairs(ruta.secciones) do
    local pasos = {}
    prueba.secciones[i] = { pasos = pasos }
    for j, paso in ipairs(seccion.pasos) do
      pasos[j] = {}
      copiar(paso.wp, pasos[j], "wp", "puntos de ruta, sección " .. i .. ", paso " .. j)
    end
  end
  copiar(ruta.entrenamiento, prueba, "entrenamiento")
  copiar(ruta.hechizosExtra, prueba, "hechizosExtra")
  ejecutar(funcion, prueba)
  if prueba.adaptada ~= raza then return "marca de adaptación" end
  for _, comparacion in ipairs(comparaciones) do
    local destino, campo, esperados, etiqueta = unpack(comparacion, 1, 4)
    if not validar(esperados, destino[campo]) then return etiqueta end
  end
end

return {
  entorno = entorno, entorno_motor = entorno_motor, ejecutar = ejecutar,
  con_entorno = setfenv, identidad_de_tabla = identidad_de_tabla,
  comprobar_filtro = comprobar_filtro, misma_tabla = rawequal,
}

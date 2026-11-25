-- Revision975.lua: diagnóstico de viajes, cobertura de profesiones y convivencia con Questie.
-- Sólo lee las rutas. Nunca reordena misiones ni modifica la configuración de Questie.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L or function(x) return x end
local function Mensaje(lineas)
  local t = table.concat(lineas, "\n")
  if type(GL.MostrarInforme) == "function" then
    local ok = pcall(GL.MostrarInforme, t)
    if ok then return t end
  end
  if type(GL.Mensaje) == "function" then
    for _, linea in ipairs(lineas) do GL.Mensaje(linea) end
  end
  return t
end
local function Ruta() return GL.RUTA end
local function Viajes()
  local r = Ruta()
  local lineas = { L"AUDITORÍA DE VIAJES (solo lectura)" }
  if not r or type(r.secciones) ~= "table" then
    lineas[#lineas+1] = L"No hay una ruta activa."
    return lineas
  end
  local total, interzonas, regresos, anteriores = 0, 0, 0, {}
  local prev, zonas = nil, {}
  for si, sec in ipairs(r.secciones) do
    for pi, paso in ipairs(sec.pasos or {}) do
      local primerMapa, primerZona
      for _, d in ipairs(paso.wp or {}) do
        if type(d.m) == "number" then primerMapa = d.m; primerZona = d.z; break end
      end
      if primerMapa then
        total = total + 1
        if prev and primerMapa ~= prev then
          interzonas = interzonas + 1
          if zonas[primerMapa] and #anteriores < 8 then
            regresos = regresos + 1
            anteriores[#anteriores+1] = tostring(si) .. ":" .. tostring(pi) .. " - " .. tostring(primerZona or primerMapa)
          elseif zonas[primerMapa] then
            regresos = regresos + 1
          end
        end
        zonas[primerMapa] = true
        prev = primerMapa
      end
    end
  end
  lineas[#lineas+1] = L"Pasos con destino: " .. total
  lineas[#lineas+1] = L"Cambios de mapa entre pasos: " .. interzonas
  lineas[#lineas+1] = L"Regresos a mapas visitados: " .. regresos
  for _, z in ipairs(anteriores) do lineas[#lineas+1] = "  " .. z end
  lineas[#lineas+1] = L"Estos saltos no equivalen a viajes evitables: pueden ser entregas, cadenas, vuelos o misiones de otra zona. No se han reordenado pasos."
  return lineas
end
local function Profesiones()
  local r = Ruta()
  local lineas = { L"AUDITORÍA DE PROFESIONES (solo lectura)" }
  if not r then lineas[#lineas+1] = L"No hay una ruta activa."; return lineas end
  local lista = r.profesiones or {}
  if #lista == 0 then lineas[#lineas+1] = L"Esta ruta no incluye planes de profesiones." end
  for _, prof in ipairs(lista) do
    local pasos = {}
    for _, p in ipairs(prof.pasos or {}) do pasos[#pasos+1] = p end
    table.sort(pasos, function(a, b) return (tonumber(a.d) or 0) < (tonumber(b.d) or 0) end)
    local esperado, huecos, alertas = 1, {}, 0
    for _, p in ipairs(pasos) do
      local desde, hasta = tonumber(p.d), tonumber(p.h)
      if not desde or not hasta or hasta <= desde then alertas = alertas + 1
      else
        if desde > esperado then huecos[#huecos+1] = esperado .. "-" .. desde end
        esperado = math.max(esperado, hasta)
        if #(p.mat or {}) == 0 and #(p.crea or {}) == 0 and #(p.recetas or {}) == 0 then alertas = alertas + 1 end
        for _, m in ipairs(p.mat or {}) do
          if not tonumber(m[1]) or not tonumber(m[2]) or tonumber(m[2]) <= 0 then alertas = alertas + 1 end
        end
      end
    end
    if esperado < 300 then huecos[#huecos+1] = esperado .. "-300" end
    lineas[#lineas+1] = tostring(prof.nombre or "?") .. ": " .. (#huecos == 0 and L"tramos 1-300 cubiertos" or (L"huecos " .. table.concat(huecos, ", "))) .. "; " .. alertas .. L" entradas sin materiales exactos o receta"
  end
  -- Las guías generales cubren las profesiones no asociadas a una ruta de clase.
  local generales = GL.WH and GL.WH.profesiones or {}
  if #generales > 0 then
    lineas[#lineas+1] = L"Planes generales de la biblioteca:"
    for _, prof in ipairs(generales) do
      local anterior, huecos = 1, 0
      local tramos = {}
      for _, p in ipairs(prof.tramos or {}) do tramos[#tramos+1] = p end
      table.sort(tramos, function(a, b) return (tonumber(a.d) or 0) < (tonumber(b.d) or 0) end)
      for _, p in ipairs(tramos) do
        local d, h = tonumber(p.d), tonumber(p.h)
        if d and h and h > d then
          if d > anterior then huecos = huecos + 1 end
          anterior = math.max(anterior, h)
        end
      end
      if anterior < 300 then huecos = huecos + 1 end
      lineas[#lineas+1] = "  " .. tostring(prof.n or "?") .. ": " .. #tramos .. L" tramos, huecos numéricos: " .. huecos
    end
  end
  lineas[#lineas+1] = L"La continuidad de rangos NO verifica disponibilidad de recetas, probabilidades de subir, costes, vendedores ni desbloqueos de Forever."
  return lineas
end
local function MarcasPropias(valor)
  local db = GuiaAventureroDB
  if type(db) ~= "table" then return { L"No está disponible la configuración del personaje." } end
  local s = tostring(valor or ""):lower():match("^%s*(.-)%s*$")
  if s == "ocultar" or s == "off" then db.pinesMapa = false
  elseif s == "mostrar" or s == "on" then db.pinesMapa = true
  else return { L"Marcas de Guía del Aventurero: /ga marcaspropias ocultar | mostrar. No cambia los ajustes de Questie." } end
  if type(GL.ActualizarPines) == "function" then pcall(GL.ActualizarPines) end
  return { db.pinesMapa and L"Marcas propias del mapa activadas." or L"Marcas propias del mapa ocultas; Questie no se ha modificado." }
end
GL.RevisionViajes975 = Viajes
GL.RevisionProfesiones975 = Profesiones
GL.RevisionMarcas975 = MarcasPropias
GL.comandos = GL.comandos or {}
-- 9.7.6: /ga viajes, /ga revisarprofesiones y /ga marcaspropias quitados (los hacen /ga viajelocal, el plan de la profesión y /ga questie)

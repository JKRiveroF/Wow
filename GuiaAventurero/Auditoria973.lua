-- Auditoria973.lua - Diagnostico no invasivo de la ruta activa (version 9.7.3).
-- Solo cuenta los pasos ya cargados; NO inventa recompensa de PX ni modifica el avance.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L or function(s) return s end

local function Texto(lineas)
  local mensaje = table.concat(lineas, "\n")
  if type(GL.MostrarInforme) == "function" then
    local ok = pcall(GL.MostrarInforme, mensaje)
    if ok then return mensaje end
  end
  if type(GL.Mensaje) == "function" then
    for _, linea in ipairs(lineas) do GL.Mensaje(linea) end
  end
  return mensaje
end

local function Analizar()
  local ruta = GL.RUTA
  if type(ruta) ~= "table" or type(ruta.secciones) ~= "table" then
    return { L"Aún no hay una ruta activa cargada." }
  end
  local idsA, idsT = {}, {}
  local secciones, pasos, recogidas, entregas, extras = 0, 0, 0, 0, 0
  local avisos = {}
  local nivel = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or nil
  for i, sec in ipairs(ruta.secciones) do
    secciones = secciones + 1
    local demasiadoAltas = 0
    for _, paso in ipairs(sec.pasos or {}) do
      pasos = pasos + 1
      -- con la guía en inglés el texto del paso ya viene traducido («Extra quest ... (level N)»)
      if type(paso.t) == "string" and (paso.t:find("Misión extra", 1, true) or paso.t:find("Extra quest", 1, true)) then
        extras = extras + 1
        local recomendado = tonumber(paso.t:match("%(nivel (%d+)%)") or paso.t:match("%(level (%d+)%)"))
        if recomendado and recomendado > (tonumber(sec.max) or 60) then
          demasiadoAltas = demasiadoAltas + 1
        end
      end
      for _, d in ipairs(paso.wp or {}) do
        local q = tonumber(d.q)
        if q then
          if d.a == "A" then recogidas = recogidas + 1; idsA[q] = (idsA[q] or 0) + 1 end
          if d.a == "T" then entregas = entregas + 1; idsT[q] = (idsT[q] or 0) + 1 end
        end
      end
    end
    if demasiadoAltas > 0 and #avisos < 8 then
      avisos[#avisos+1] = tostring(sec.titulo or i) .. ": " .. demasiadoAltas .. L" misiones extra de nivel superior al máximo de la sección (se pueden coger si tu nivel llega)"
    end
  end
  local faltanA, faltanT, repetidas = 0, 0, 0
  for q in pairs(idsT) do if not idsA[q] then faltanA = faltanA + 1 end end
  for q in pairs(idsA) do if not idsT[q] then faltanT = faltanT + 1 end end
  for _, total in pairs(idsT) do if total > 1 then repetidas = repetidas + 1 end end
  local lineas = {
    L"AUDITORÍA DE RUTA (9.7.3)",
    tostring(ruta.nombre or ruta.id or "?") .. (nivel and (" · " .. L"nivel actual " .. nivel) or ""),
    L"Secciones: " .. secciones .. L" · pasos: " .. pasos .. L" · misiones extra: " .. extras,
    L"Recogidas: " .. recogidas .. L" · entregas: " .. entregas,
    L"Entregas sin recogida en esta ruta: " .. faltanA,
    L"Recogidas sin entrega en esta ruta: " .. faltanT,
    L"Misiones entregadas varias veces: " .. repetidas,
  }
  for _, aviso in ipairs(avisos) do lineas[#lineas+1] = "! " .. aviso end
  lineas[#lineas+1] = L"Llegar al 60 es un cálculo con la experiencia de cada misión de Questie Forever y los enemigos de sus objetivos; falta comprobarlo en el juego."
  lineas[#lineas+1] = L"La comprobación es informativa: no modifica tu ruta ni tu progreso."
  return lineas
end
GL.AuditoriaRuta973 = Analizar
GL.comandos = GL.comandos or {}
-- 9.7.6: /ga auditoriaruta quitado (solo servía para las pruebas)

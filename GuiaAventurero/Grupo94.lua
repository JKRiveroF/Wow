-- Grupo94.lua (9.4): más cosas en el botón Grupo.
--  · «Ir» en cada compañero: la flecha te lleva a donde está (el juego da su posición si estáis en el mismo continente).
--  · «Compartir misiones»: comparte con el grupo las misiones de tu diario que algún compañero con la guía no lleva,
--    una cada segundo (las que no se pueden compartir el juego las salta).
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local function NumeroSeguro(v)
  if issecretvalue and issecretvalue(v) then return false end
  return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end
local function IndiceValido(v)
  return NumeroSeguro(v) and v > 0 and v % 1 == 0
end

-- Destino de la flecha hacia un compañero (unidad party1, raid3...)
function GL.DestinoCompanero(unidad, nombre)
  if not (unidad and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local ok, m = pcall(C_Map.GetBestMapForUnit, unidad)
  if not (ok and IndiceValido(m)) then return nil end
  local ok2, pos = pcall(C_Map.GetPlayerMapPosition, m, unidad)
  if not ok2 or (issecretvalue and issecretvalue(pos)) or not pos then return nil end
  local ok3, x, y = pcall(function() return pos:GetXY() end)
  if not ok3 or not NumeroSeguro(x) or not NumeroSeguro(y) or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then return nil end
  return { m = m, x = x * 100, y = y * 100, n = nombre or unidad }
end

function GL.IrACompanero(unidad, nombre)
  local d = GL.DestinoCompanero(unidad, nombre)
  if d and GL.SeguirDesvio then GL.SeguirDesvio(d)
  elseif GL.Mensaje then GL.Mensaje(L"el juego no da dónde está " .. (nombre or L"tu compañero") .. L" (en otro continente o en una mazmorra).") end
end

-- Misiones de tu diario que algún compañero con la guía no lleva
local function QueCompartir()
  local comp = (GL.Companeros and GL.Companeros()) or {}
  local ahora = (GetTime and GetTime()) or 0
  local r = {}
  for _, q in ipairs((GL.MisMisionesGrupo and GL.MisMisionesGrupo()) or {}) do
    for _, c in pairs(comp) do
      if c.qs and ahora - (c.t or 0) < 180 and not c.qs[q.id] then table.insert(r, q); break end
    end
  end
  return r
end
GL.QueCompartirGrupo = QueCompartir

local function IndiceEnDiario(id)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
    local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, id)
    if ok and IndiceValido(i) then return i end
  end
  if GetQuestLogIndexByID then local ok, i = pcall(GetQuestLogIndexByID, id); if ok and IndiceValido(i) then return i end end
end

function GL.CompartirMisionesGrupo()
  local l = QueCompartir()
  if #l == 0 then if GL.Mensaje then GL.Mensaje(L"no hay misiones que compartir: tus compañeros con la guía ya llevan las tuyas.") end return end
  if not (SelectQuestLogEntry and QuestLogPushQuest and C_Timer and C_Timer.After) then return end
  for i, q in ipairs(l) do
    C_Timer.After((i - 1) * 1.2, function()
      local idx = IndiceEnDiario(q.id)
      if idx then
        local ok, result = pcall(SelectQuestLogEntry, idx)
        if ok and not (issecretvalue and issecretvalue(result)) and result ~= false then pcall(QuestLogPushQuest) end
      end
    end)
  end
  if GL.Mensaje then GL.Mensaje(L"compartiendo " .. #l .. (#l == 1 and L" misión" or L" misiones") .. L" con el grupo.") end
end

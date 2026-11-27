-- Reserva.lua (9.1): «Reservar oro para el 40». Con el ajuste encendido, las compras automáticas del
-- instructor de clase y del de profesión no gastan el oro que te falta para lo del ahorro (equitación, montura
-- y doble especialización, con los precios de Ajustes › Datos). Los botones «Aprender» de los paneles compran
-- igual con todo tu oro: lo decides tú. Apagado de serie.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local function DB() return GuiaAventureroDB or {} end

-- Cobre que se guarda: lo que cuesta lo del ahorro que aún no tienes
local function Reserva(estricta)
  if DB().reservaOro ~= true then return 0 end
  -- En reparaciones no confundir ocultar el panel de ahorro con desactivar la reserva.
  local function desconocida() if not estricta then return 0 end end
  if not GL.MetasAhorro then return desconocida() end
  local ok, metas = pcall(GL.MetasAhorro, estricta == true)
  if not ok or type(metas) ~= "table" then return desconocida() end
  local oro = 0
  for _, m in ipairs(metas) do
    if type(m) ~= "table" then return desconocida() end
    if not m.hecho then
      if type(m.o) == "number" and m.o >= 0 and m.o < math.huge then oro = oro + m.o
      elseif estricta then return nil end
    end
  end
  if oro >= math.huge then return desconocida() end
  return math.floor(oro * 10000)
end
GL.ReservaOro = Reserva

-- Dinero que pueden gastar las compras: todo si es a mano; si es automática, lo que sobra de la reserva
GL.DineroParaComprar = function(manual)
  local dinero = (GetMoney and GetMoney()) or 0
  if manual then return dinero end
  return math.max(0, dinero - Reserva())
end

local avisado = 0
GL.AvisoReserva = function(precio)
  local r = Reserva()
  if r <= 0 or not GL.Mensaje then return end
  local dinero = (GetMoney and GetMoney()) or 0
  if dinero < (precio or 0) then return end   -- no llegaba de todas formas
  local ahora = (GetTime and GetTime()) or 0
  if ahora - avisado < 30 then return end
  avisado = ahora
  local txt = GetMoneyString and GetMoneyString(r) or (math.floor(r / 10000) .. " o")
  GL.Mensaje(L"no compro solo: guardas " .. txt .. L" para el 40 (Ajustes › Avisos › Reservar oro). Pulsa «Aprender» en el panel para comprar igual.")
end

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "reservaOro", "Reservar oro para el 40",
  "Las compras automáticas en los instructores y las reparaciones automáticas no tocan el oro del ahorro (equitación, montura y doble especialización). Puedes comprar o reparar manualmente.",
  function() return DB().reservaOro == true end, function(v) DB().reservaOro = v end, pestana = "avisos" })

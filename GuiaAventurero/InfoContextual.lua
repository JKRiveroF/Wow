-- InfoContextual.lua: informacion adicional de objetos en sus tooltips.
-- No modifica objetos ni automatiza acciones; solo añade datos informativos.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local function Activo()
  return type(GuiaAventureroDB) == "table" and GuiaAventureroDB.infoContextual ~= false
end


local function AmpliarObjeto(tooltip)
  if not Activo() or not tooltip or not tooltip.GetItem then return end
  local ok, nombre, enlace = pcall(tooltip.GetItem, tooltip)
  if not ok or not enlace then return end
  local obtener = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not obtener then return end
  local datos = { pcall(obtener, enlace) }
  if not datos[1] then return end
  local nivel, requerido, clase, subclase, equip, venta = datos[5], datos[6], datos[7], datos[8], datos[10], datos[12]
  local lineas = {}
  -- 9.7.4: cuántos tienes en total (bolsas y banco) y cuántos guardan tus otros personajes
  local id = tonumber(tostring(enlace):match("item:(%d+)"))
  local contar = (C_Item and C_Item.GetItemCount) or GetItemCount
  if id and contar then
    local okB, bolsas = pcall(contar, id)
    local okT, todo = pcall(contar, id, true)
    bolsas = (okB and tonumber(bolsas)) or 0
    local banco = math.max(0, ((okT and tonumber(todo)) or bolsas) - bolsas)
    local otros = {}
    if GL.ContarObjetoCuenta then
      local okC, lista = pcall(GL.ContarObjetoCuenta, id)
      for _, p in ipairs(okC and lista or {}) do
        if p.propio then
          if banco == 0 and p.banco > 0 then banco = p.banco end   -- el banco que viste la última vez que lo abriste
        elseif p.mochila + p.banco > 0 then
          otros[#otros+1] = p.n .. " " .. (p.mochila + p.banco)
        end
      end
    end
    if bolsas + banco > 0 then
      lineas[#lineas+1] = L"Tienes en total: " .. (bolsas + banco) .. "  (" .. L"bolsas " .. bolsas .. " · " .. L"banco " .. banco .. ")"
    end
    if #otros > 0 then lineas[#lineas+1] = L"Otros personajes: " .. table.concat(otros, ", ") end
  end
  if tonumber(nivel) and nivel > 0 then lineas[#lineas+1] = L"Nivel de objeto: " .. nivel end
  if tonumber(requerido) and requerido > 0 then lineas[#lineas+1] = L"Nivel necesario: " .. requerido end
  if clase and clase ~= "" then
    local tipo = clase .. (subclase and subclase ~= "" and (" · " .. subclase) or "")
    -- 7.9.4: el juego da la ranura como código (INVTYPE_...); se traduce con su texto o no se pone
    if type(equip) == "string" and equip ~= "" and not equip:find("NON_EQUIP") then
      local texto = _G[equip]
      if type(texto) == "string" and texto ~= "" then tipo = tipo .. " · " .. texto end
    end
    if GL.ingles ~= GL.clienteIngles then tipo = tipo .. " (" .. L"idioma del cliente" .. ")" end
    lineas[#lineas+1] = tipo
  end
  -- 7.9.4: el precio de venta ya lo pone el juego en el tooltip; no se repite
  if #lineas == 0 then return end
  tooltip:AddLine(" ")
  tooltip:AddLine(L"Guía del Aventurero · Información", 0.41, 0.80, 0.94)
  for _, linea in ipairs(lineas) do tooltip:AddLine(linea, 0.85, 0.85, 0.85, true) end
  tooltip:Show()
end

if GL.EngancharTooltipObjeto then GL.EngancharTooltipObjeto(AmpliarObjeto, L"información de objetos", function() return L"Guía del Aventurero · Información" end) end

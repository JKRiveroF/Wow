-- Pesca.lua (9.5): modo pesca con un solo botón en pantalla.
--  · Sale si llevas una caña (en las bolsas o puesta) y no estás en combate ni montado. Mayús + arrastrar: moverlo.
--  · Clic: se pone la caña (guarda tus armas), baja música, ambiente y diálogos, sube los efectos y lanza.
--  · Con el corcho en el agua el botón pasa a «recoger»: otro clic cuando pica y sacas el pez.
--  · 5 s después de guardar el pez, o en cuanto se acaban los 20 s sin pez, vuelven tus armas y tus volúmenes.
--    Si lanzas otra vez antes, sigues con la caña.
--  · Brilla al pasar el ratón por un banco de peces.
-- El juego no deja que un addon lance ni recoja solo: cada lanzamiento y cada captura salen de un clic tuyo.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local function DB() return GuiaAventureroDB or {} end
local function Activo() return DB().modoPesca ~= false end

local PESCA_IDS = { [7620] = true, [7731] = true, [7732] = true, [18248] = true }
local ESPERA_PEZ = 5       -- segundos con la caña después de guardar el pez
local ICONO_PESCA = "Interface\\Icons\\Trade_Fishing"
local ICONO_RECOGER = "Interface\\Icons\\INV_Misc_Fish_02"

-- volúmenes que se tocan mientras pescas (y el despojo automático y el objetivo suave de interactuar)
local CVARS = {
  { "Sound_EnableAllSound", "1" }, { "Sound_EnableSFX", "1" }, { "Sound_SFXVolume", "1.0" },
  { "Sound_MusicVolume", "0" }, { "Sound_AmbienceVolume", "0" }, { "Sound_DialogVolume", "0" },
  { "autoLootDefault", "1" }, { "SoftTargetInteract", "3" },
}
local function Publico(v)
  if type(issecretvalue) ~= "function" then return true end
  local ok, secreto = pcall(issecretvalue, v)
  return ok and not secreto
end
local function LeerCVar(n)
  local ok, v = pcall(function() return (C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(n)) or (GetCVar and GetCVar(n)) end)
  if not ok or not Publico(v) then return nil end
  if type(v) == "string" or type(v) == "number" then return v end
end
local function IgualCVar(a, b)
  if a == nil or b == nil then return false end
  if tostring(a) == tostring(b) then return true end
  local x, y = tonumber(a), tonumber(b)
  return x ~= nil and y ~= nil and x == y
end
local function PonerCVar(n, v)
  local fn = (C_CVar and C_CVar.SetCVar) or SetCVar
  if type(fn) ~= "function" then return false end
  local ok, resultado = pcall(fn, n, v)
  return ok and Publico(resultado) and resultado ~= false
end
local function Despues(s, fn)
  if not (C_Timer and type(C_Timer.After) == "function") then return false end
  local ok, resultado = pcall(C_Timer.After, s, fn)
  return ok and Publico(resultado) and resultado ~= false
end

local function NombrePesca()
  local ok, n = pcall(function()
    if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(7620); return i and i.name end
    return GetSpellInfo and (GetSpellInfo(7620))
  end)
  if ok and type(n) == "string" and n ~= "" then return n end
  return GL.ingles and "Fishing" or "Pesca"
end

-- ¿es una caña? (armas, subclase 20)
local function EsCana(item)
  if not item or not GetItemInfoInstant then return false end
  local ok, _, _, _, _, _, clase, sub = pcall(GetItemInfoInstant, item)
  return ok and clase == 2 and sub == 20
end
local function ArmaPuesta(slot) return GetInventoryItemLink and GetInventoryItemLink("player", slot) end
local function CanaPuesta() return EsCana(ArmaPuesta(16)) end

local function BuscarCana()
  local puesta = ArmaPuesta(16)
  if EsCana(puesta) then return puesta end
  local CC = C_Container
  local num = (CC and CC.GetContainerNumSlots) or GetContainerNumSlots
  local enlace = (CC and CC.GetContainerItemLink) or GetContainerItemLink
  if not (num and enlace) then return nil end
  for b = 0, 4 do
    for s = 1, (num(b) or 0) do
      local l = enlace(b, s)
      if l and EsCana(l) then return l end
    end
  end
end
local function NombreItem(l)
  if not l then return nil end
  local n = GetItemInfo and GetItemInfo(l)
  return n or l:match("%[(.-)%]")
end

local function Pescando()
  if not UnitChannelInfo then return false end
  local nombre, _, _, _, _, _, _, id = UnitChannelInfo("player")
  return nombre ~= nil and (PESCA_IDS[id] or nombre == NombrePesca())
end

------------------------------------------------------------------------
-- Guardar y devolver (armas y volúmenes). Se guarda en la DB por si el juego se cierra a mitad.
------------------------------------------------------------------------
local turno = 0        -- cada lanzamiento nuevo anula la vuelta pendiente
local pescado = false  -- el último lanzamiento trajo pez
local reintentarArmas = false
local restauracionTurno, intentoRestauracion
local function EnCombate()
  return not GL.AccionProtegidaPermitidaR13()
end

local function GuardarVolumenes()
  local g = DB().pescaGuardado or {}
  if not g.vol then
    g.vol, g.volAplicado = {}, {}
    for _, c in ipairs(CVARS) do
      local v = LeerCVar(c[1])
      if v ~= nil and not IgualCVar(v, c[2]) then
        -- Guardar antes de solicitar: un hook puede lanzar un error después de escribir.
        g.vol[c[1]], g.volAplicado[c[1]] = v, c[2]
        PonerCVar(c[1], c[2])
      end
    end
  end
  if GuiaAventureroDB then GuiaAventureroDB.pescaGuardado = g end
end

local function GuardarArmas()
  if CanaPuesta() then return end
  local g = DB().pescaGuardado or {}
  -- No perder la mano izquierda si el jugador relanza antes de terminar la devolución.
  if not g.armas or ArmaPuesta(16) ~= g.armas[16] then
    -- Una nueva pesca tras un cambio manual de arma guarda el conjunto nuevo.
    g.armas = { [16] = ArmaPuesta(16), [17] = ArmaPuesta(17) }
  else
    g.armas.restaurando = nil
  end
  reintentarArmas = false
  if GuiaAventureroDB then GuiaAventureroDB.pescaGuardado = g end
end

local function DevolverVolumenes()
  local g = DB().pescaGuardado
  if not (g and type(g.vol) == "table") then return end
  local aplicados = g.volAplicado
  for _, c in ipairs(CVARS) do
    local n, objetivo = c[1], c[2]
    local anterior = g.vol[n]
    if anterior ~= nil then
      local esperado = type(aplicados) == "table" and aplicados[n] or objetivo
      local actual = LeerCVar(n)
      if actual ~= nil then
        if IgualCVar(actual, anterior) or not IgualCVar(actual, esperado) then
          -- Ya restaurado o cambiado por otro addon/jugador: no sobrescribirlo.
          g.vol[n] = nil
        else
          PonerCVar(n, anterior)
          if IgualCVar(LeerCVar(n), anterior) then g.vol[n] = nil end
        end
      end
      if g.vol[n] == nil and type(aplicados) == "table" then aplicados[n] = nil end
    end
  end
  if not next(g.vol) then g.vol, g.volAplicado = nil, nil end
end

local function DevolverArmas()
  local g = DB().pescaGuardado
  local armas = g and g.armas
  if type(armas) ~= "table" then reintentarArmas = false; return end
  local a16, a17 = armas[16], armas[17]
  local mio = turno
  if restauracionTurno == mio then return end
  local intento = {}
  intentoRestauracion = intento
  local function Vigente()
    local actual = DB().pescaGuardado
    return intentoRestauracion == intento and mio == turno and actual == g and actual.armas == armas
  end
  local function Terminar()
    if not Vigente() then return end
    g.armas = nil
    reintentarArmas = false
    restauracionTurno, intentoRestauracion = nil, nil
  end
  local function Pendiente()
    if not Vigente() then return end
    restauracionTurno, intentoRestauracion = nil, nil
    if not reintentarArmas and GL.Mensaje then
      GL.Mensaje(L"Modo pesca: armas pendientes de restaurar. Se reintentará al salir de combate o al volver a entrar.")
    end
    reintentarArmas = true
  end
  if EnCombate() or not GL.PersonajeVivoR14() then Pendiente(); return end
  local principal = ArmaPuesta(16)
  if not a16 then Terminar(); return end -- conserva la caña si antes no había arma
  -- Respetar un cambio manual a otra arma, sin sobrescribirla con la copia antigua.
  if not CanaPuesta() and principal ~= a16 then
    if armas.restaurando and not principal then Pendiente() else Terminar() end
    return
  end
  local function CursorLibre()
    if type(GetCursorInfo) ~= "function" then return false end
    local ok, v = pcall(GetCursorInfo)
    return ok and Publico(v) and v == nil
  end
  local function PuedeEquipar()
    local ok, pescando = pcall(Pescando)
    return ok and Publico(pescando) and pescando == false and CursorLibre() and not EnCombate() and GL.PersonajeVivoR14()
  end
  if type(EquipItemByName) ~= "function" or not PuedeEquipar() then Pendiente(); return end
  restauracionTurno = mio
  armas.restaurando = true
  local function Verificar()
    if not Vigente() then return end
    if not GL.PersonajeVivoR14() then Pendiente(); return end
    if ArmaPuesta(16) ~= a16 then Pendiente(); return end
    if not a17 or ArmaPuesta(17) == a17 then Terminar(); return end
    if not PuedeEquipar() then Pendiente(); return end
    -- Si el jugador ya puso otra pieza en la izquierda, no sustituirla.
    if ArmaPuesta(17) then Terminar(); return end
    local ok, resultado = pcall(EquipItemByName, a17, 17)
    if not ok or not Publico(resultado) or resultado == false then Pendiente(); return end
    if not Despues(1, function()
      if not Vigente() then return end
      if not GL.PersonajeVivoR14() then Pendiente(); return end
      if ArmaPuesta(16) == a16 and ArmaPuesta(17) == a17 then Terminar()
      else Pendiente() end
    end) then Pendiente() end
  end
  if principal == a16 then Verificar(); return end
  if not PuedeEquipar() then Pendiente(); return end
  local ok, resultado = pcall(EquipItemByName, a16, 16)
  if not ok or not Publico(resultado) or resultado == false then Pendiente(); return end
  if not Despues(0.3, Verificar) then Pendiente() end
end

local function Devolver()
  -- Una segunda devolución no duplica una solicitud de equipo todavía en curso.
  if restauracionTurno ~= turno then turno = turno + 1 end
  pescado = false
  DevolverVolumenes()
  DevolverArmas()
  if GL._botonPesca and GL._botonPesca.Pintar then GL._botonPesca.Pintar() end
end
GL.DevolverPesca = Devolver

-- vuelve dentro de s segundos, salvo que lances otra vez
local function DevolverEn(s)
  turno = turno + 1
  local mio = turno
  -- Si no se puede programar, conservar el respaldo para una devolución posterior.
  Despues(s, function() if mio == turno and not Pescando() then Devolver() end end)
end

------------------------------------------------------------------------
-- El botón
------------------------------------------------------------------------
local boton

local function Macro()
  if Pescando() then
    -- el corcho está en el agua: el clic lo recoge
    return "/interact"
  end
  local cana = BuscarCana()
  if not cana then return "" end
  local pesca = "/cast " .. NombrePesca()
  if CanaPuesta() then return pesca end
  return "/equip " .. (NombreItem(cana) or "") .. "\n" .. pesca
end

local function PuedeVerse()
  if not Activo() then return false end
  if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
  if IsMounted and IsMounted() then return false end
  if not GL.PersonajeVivoR14() then return false end
  return BuscarCana() ~= nil
end

local function Actualizar()
  if not boton or EnCombate() then return end
  if PuedeVerse() then
    boton:SetAttribute("type", "macro")
    boton:SetAttribute("macrotext", Macro())
    boton:Show()
  else
    boton:Hide()
  end
  boton.Pintar()
end
GL.ActualizarPesca = Actualizar

local function Brillar(seg)
  if not boton then return end
  boton.brillo:Show()
  boton.brilloHasta = GetTime() + (seg or 3)
end

local function CrearBoton()
  boton = CreateFrame("Button", "GuiaAventureroBotonPesca", UIParent, "SecureActionButtonTemplate")
  GL._botonPesca = boton
  boton:SetSize(44, 44)
  boton:SetFrameStrata("MEDIUM")
  boton:SetMovable(true)
  boton:SetClampedToScreen(true)
  boton:RegisterForClicks("AnyUp")
  boton:RegisterForDrag("LeftButton")
  local pos = DB().pescaPos
  if type(pos) == "table" and pos[1] then
    boton:SetPoint(pos[1], UIParent, pos[1], pos[2] or 0, pos[3] or 0)
  else
    boton:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
  end

  boton.fondo = boton:CreateTexture(nil, "BACKGROUND")
  boton.fondo:SetPoint("TOPLEFT", -3, 3)
  boton.fondo:SetPoint("BOTTOMRIGHT", 3, -3)
  boton.fondo:SetColorTexture(0, 0, 0, 0.75)
  boton.icono = boton:CreateTexture(nil, "ARTWORK")
  boton.icono:SetAllPoints()
  boton.icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  boton.brillo = boton:CreateTexture(nil, "OVERLAY")
  boton.brillo:SetPoint("TOPLEFT", -10, 10)
  boton.brillo:SetPoint("BOTTOMRIGHT", 10, -10)
  boton.brillo:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  boton.brillo:SetBlendMode("ADD")
  boton.brillo:SetVertexColor(0.3, 0.8, 1, 1)
  boton.brillo:Hide()
  boton.resalte = boton:CreateTexture(nil, "HIGHLIGHT")
  boton.resalte:SetAllPoints()
  boton.resalte:SetColorTexture(1, 1, 1, 0.15)

  -- barra de los 20 s
  boton.barra = CreateFrame("StatusBar", nil, boton)
  boton.barra:SetPoint("TOPLEFT", boton, "BOTTOMLEFT", -3, -4)
  boton.barra:SetPoint("TOPRIGHT", boton, "BOTTOMRIGHT", 3, -4)
  boton.barra:SetHeight(6)
  boton.barra:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  boton.barra:SetStatusBarColor(0.3, 0.75, 1)
  boton.barra.fondo = boton.barra:CreateTexture(nil, "BACKGROUND")
  boton.barra.fondo:SetAllPoints()
  boton.barra.fondo:SetColorTexture(0, 0, 0, 0.7)
  boton.barra:SetMinMaxValues(0, 1)
  boton.barra:Hide()
  boton.texto = boton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  boton.texto:SetPoint("TOP", boton.barra, "BOTTOM", 0, -2)
  boton.texto:SetShadowOffset(1, -1)

  function boton.Pintar()
    local recoger = Pescando()
    boton.icono:SetTexture(recoger and ICONO_RECOGER or ICONO_PESCA)
    boton.barra:SetShown(recoger and true or false)
    if recoger then
      boton.texto:SetText(L"Clic cuando pique")
    elseif DB().pescaGuardado and DB().pescaGuardado.armas and CanaPuesta() then
      boton.texto:SetText(C.GRIS .. L"Lanzar otra vez" .. C.FIN)
    else
      boton.texto:SetText("")
    end
  end

  -- justo antes del clic: elegir qué hace (lanzar, ponerse la caña y lanzar, o recoger) y guardar lo tuyo
  boton:SetScript("PreClick", function(self, _, abajo)
    if EnCombate() then return end
    if not PuedeVerse() or Macro() == "" then
      self:SetAttribute("macrotext", "")
      return
    end
    if not Pescando() then
      turno = turno + 1       -- anula la vuelta pendiente: sigues pescando
      pescado = false
      reintentarArmas = false
      GuardarArmas()
      GuardarVolumenes()
    end
    self:SetAttribute("type", "macro")
    self:SetAttribute("macrotext", Macro())
  end)
  boton:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown and IsShiftKeyDown() and not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
  end)
  boton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, _, x, y = self:GetPoint()
    if GuiaAventureroDB then GuiaAventureroDB.pescaPos = { p, x, y } end
  end)
  boton:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L"Modo pesca", 1, 1, 1)
    if Pescando() then
      GameTooltip:AddLine(L"Cuando oigas el chapoteo, clic para sacar el pez.", 0.8, 0.8, 0.85, true)
      GameTooltip:AddLine(L"Si no funciona, clic derecho sobre el corcho.", 0.6, 0.6, 0.65, true)
    else
      GameTooltip:AddLine(L"Clic: te pone la caña, baja la música y lanza.", 0.8, 0.8, 0.85, true)
      GameTooltip:AddLine(L"Tus armas y tus volúmenes vuelven 5 s después de guardar el pez.", 0.6, 0.6, 0.65, true)
    end
    GameTooltip:AddLine(L"Mayús + arrastrar: mover. Se quita en Ajustes › Avanzado › General.", 0.5, 0.5, 0.55, true)
    GameTooltip:Show()
  end)
  boton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  boton:SetScript("OnUpdate", function(self)
    if self.brilloHasta and GetTime() > self.brilloHasta then self.brillo:Hide(); self.brilloHasta = nil end
    if not self.barra:IsShown() or not UnitChannelInfo then return end
    local _, _, _, ini, fin = UnitChannelInfo("player")
    if ini and fin and fin > ini then
      local resta = math.max(0, fin / 1000 - GetTime())
      self.barra:SetValue(resta / ((fin - ini) / 1000))
    end
  end)
  boton:Hide()
end

------------------------------------------------------------------------
-- Bancos de peces: el botón brilla al señalarlos
------------------------------------------------------------------------
local BANCOS = { "^Banco de", "^Restos flotantes", "^Mancha de aceite", "^Vertido de aceite", "^Banco",
  "School$", "^Floating Wreckage", "^Oil Spill", "^Floating Debris", "Pool$" }
local function MirarTooltip(tt)
  if not boton or not boton:IsShown() or Pescando() then return end
  if tt.GetUnit and tt:GetUnit() then return end
  local linea = _G["GameTooltipTextLeft1"]
  local t = linea and linea.GetText and linea:GetText()
  if type(t) ~= "string" then return end
  for _, p in ipairs(BANCOS) do
    if t:find(p) then Brillar(3); return end
  end
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local function Registrar(e) pcall(ev.RegisterEvent, ev, e) end
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "LOOT_OPENED", "LOOT_CLOSED", "PLAYER_MOUNT_DISPLAY_CHANGED",
  "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE" }) do Registrar(e) end

ev:SetScript("OnEvent", function(_, e, unidad, _, id)
  if not boton then return end
  if e == "UNIT_SPELLCAST_CHANNEL_START" then
    if unidad == "player" and (PESCA_IDS[id] or Pescando()) then
      turno = turno + 1
      pescado = false
      if not EnCombate() then boton:SetAttribute("macrotext", Macro()) end
      boton.Pintar()
    end
  elseif e == "UNIT_SPELLCAST_CHANNEL_STOP" then
    if unidad ~= "player" then return end
    local g = DB().pescaGuardado
    if not (g and (g.vol or g.armas)) then return end
    -- si picó, enseguida llega el botín; si no (20 s sin pez, te moviste...), se devuelve ya
    turno = turno + 1
    local mio = turno
    Despues(0.8, function()
      if mio ~= turno or pescado or Pescando() then return end
      Devolver()
    end)
    if not EnCombate() then boton:SetAttribute("macrotext", Macro()) end
    boton.Pintar()
  elseif e == "LOOT_OPENED" then
    if IsFishingLoot and IsFishingLoot() then pescado = true; turno = turno + 1 end
  elseif e == "LOOT_CLOSED" then
    if pescado then DevolverEn(ESPERA_PEZ); pescado = false end
    Actualizar()
  elseif e == "PLAYER_DEAD" then
    turno = turno + 1
    restauracionTurno, intentoRestauracion = nil, nil
    pescado = false
    if DB().pescaGuardado then
      DevolverVolumenes()
      reintentarArmas = type(DB().pescaGuardado.armas) == "table"
    end
    Actualizar()
  elseif e == "PLAYER_ALIVE" or e == "PLAYER_UNGHOST" then
    if GL.PersonajeVivoR14() and DB().pescaGuardado then Devolver() end
    Actualizar()
  elseif e == "PLAYER_REGEN_DISABLED" then
    -- te atacan: devolver volúmenes y aplazar armas hasta salir de combate
    if DB().pescaGuardado then Devolver() end
    if not EnCombate() then boton:Hide() end
  elseif e == "PLAYER_REGEN_ENABLED" then
    if reintentarArmas then DevolverArmas() end
    Actualizar()
  else
    Actualizar()
  end
end)

table.insert(GL.alIniciar, function()
  if not boton then CrearBoton() end
  -- si el juego se cerró a mitad de pesca, lo tuyo vuelve al entrar
  if not Pescando() and DB().pescaGuardado then Devolver() end
  if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnShow", MirarTooltip) end
  Actualizar()
end)

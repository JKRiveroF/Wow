-- ObjetoMision.lua (9.1): botón para usar el objeto de misión junto a la flecha.
-- Sale cuando llevas en las bolsas un objeto de misión que se usa (tiene «Uso:») de una misión del paso y estás
-- a menos de 200 m de su objetivo. Un clic lo usa, como desde la mochila.
-- En combate el juego no deja cambiar ni esconder el botón: se prepara antes y se pone al día al salir.
-- Se apaga en Ajustes › Flecha.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local CERCA = 219   -- yardas

local function DB() return GuiaAventureroDB or {} end
local function EnCombate() return InCombatLockdown and InCombatLockdown() end

local function Bolsa(b, s)
  if C_Container and C_Container.GetContainerItemInfo then
    local i = C_Container.GetContainerItemInfo(b, s)
    return type(i) == "table" and i.itemID or nil
  end
  if GetContainerItemID then return GetContainerItemID(b, s) end
end
local function Huecos(b)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(b) or 0 end
  return (GetContainerNumSlots and GetContainerNumSlots(b)) or 0
end

-- Objetos de misión que se usan, en las bolsas: { id = { nombre, icono } }
local function DeMision()
  local res = {}
  for b = 0, 4 do
    for s = 1, Huecos(b) do
      local id = Bolsa(b, s)
      if id and not res[id] then
        local clase, icono
        if C_Item and C_Item.GetItemInfoInstant then
          local _, _, _, _, ic, cl = C_Item.GetItemInfoInstant(id); clase, icono = cl, ic
        elseif GetItemInfoInstant then
          local _, _, _, _, ic, cl = GetItemInfoInstant(id); clase, icono = cl, ic
        end
        local hechizo = (C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(id)) or (GetItemSpell and GetItemSpell(id))
        if clase == 12 and hechizo then
          local nombre = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and GetItemInfo(id))
          res[id] = { nombre = nombre, icono = icono }
        end
      end
    end
  end
  return res
end

-- Texto del paso y de los objetivos de sus misiones, para saber si el objeto es de este paso
local function TextosDelPaso(p)
  local t = { string.lower(tostring(p.t or "")) }
  for _, d in ipairs(p.wp or {}) do
    if d.n then table.insert(t, string.lower(d.n)) end
    if d.q and GL.IndiceEnDiario and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
      local idx = GL.IndiceEnDiario(d.q)
      if idx then
        for k = 1, (GetNumQuestLeaderBoards(idx) or 0) do
          local txt = GetQuestLogLeaderBoard(k, idx)
          if txt then table.insert(t, string.lower(txt)) end
        end
      end
    end
  end
  return table.concat(t, "\n")
end

-- El objeto que toca usar ahora (o nil)
local function Elegir()
  if DB().objetoMision == false or not GL.PasoActual then return nil end
  local _, p = GL.PasoActual()
  if not p or not p.wp then return nil end
  local cerca = false
  for _, d in ipairs(p.wp) do
    if d.a == "C" and GL.DestinoHecho(d) ~= true and GL.Vector then
      local ok, _, _, dist = pcall(GL.Vector, d)
      if ok and type(dist) == "number" and dist <= CERCA then cerca = true; break end
    end
  end
  if not cerca then return nil end
  local textos = TextosDelPaso(p)
  local objetos = DeMision()
  -- 9.7.4: el objeto que el propio juego da para las misiones del paso (el de su línea en el diario)
  local delJuego = {}
  if GetQuestLogSpecialItemInfo and GL.IndiceEnDiario then
    for _, d in ipairs(p.wp) do
      local idx = d.q and GL.IndiceEnDiario(d.q)
      if idx then
        local ok, link = pcall(GetQuestLogSpecialItemInfo, idx)
        local id = ok and type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if id then delJuego[id] = true end
      end
    end
  end
  for id, o in pairs(objetos) do
    local unico = { id = id, nombre = o.nombre, icono = o.icono }
    if delJuego[id] then return unico end
    if o.nombre and string.find(textos, string.lower(o.nombre), 1, true) then return unico end
  end
  -- 9.7.4: ya no se usa «si llevas uno solo, es el de este paso»: salía la ampolla de Gnogaine (Gnomeregan)
  -- en Las Mil Agujas, en un paso que no tenía nada que ver
  return nil
end
GL.ObjetoDeMisionAhora = Elegir

local boton
local function Crear()
  boton = CreateFrame("Button", "GuiaAventureroObjetoMision", UIParent, "SecureActionButtonTemplate")
  boton:SetSize(36, 36)
  boton:SetFrameStrata("HIGH")
  boton:RegisterForClicks("AnyUp", "AnyDown")
  boton:SetAttribute("type", "item")
  boton.icono = boton:CreateTexture(nil, "ARTWORK")
  boton.icono:SetAllPoints()
  boton.borde = boton:CreateTexture(nil, "OVERLAY")
  boton.borde:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  if boton.borde.SetBlendMode then boton.borde:SetBlendMode("ADD") end
  boton.borde:SetPoint("CENTER")
  boton.borde:SetSize(64, 64)
  boton.borde:SetVertexColor(1, 0.82, 0, 0.8)
  boton.texto = boton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  boton.texto:SetPoint("TOP", boton, "BOTTOM", 0, -2)
  boton.texto:SetText(C.AMARILLO .. L"Usar" .. C.FIN)
  boton:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.id and GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetText(tostring(self.nombre), 1, 0.82, 0) end
    GameTooltip:AddLine(L"Clic: usarlo (objeto de la misión del paso).", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  boton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  boton:Hide()
end

local function Actualizar()
  if EnCombate() then return end
  if not boton then Crear() end
  local o = Elegir()
  if not o or not GL.flecha or not GL.flecha:IsShown() then boton:Hide(); boton.id = nil; return end
  if boton.id ~= o.id then
    boton:SetAttribute("item", "item:" .. o.id)
    boton.id, boton.nombre = o.id, o.nombre
    boton.icono:SetTexture(o.icono or "Interface\\Icons\\INV_Misc_QuestionMark")
  end
  -- junto a la flecha, con coordenadas fijas de la pantalla (así moverla en combate no toca un marco protegido)
  local x, y = GL.flecha:GetCenter()
  local s, su = GL.flecha:GetEffectiveScale() or 1, UIParent:GetEffectiveScale() or 1
  local w = (GL.flecha:GetWidth() or 60) * s / su
  if x and y then
    boton:ClearAllPoints()
    boton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * s / su + w / 2 + 26, y * s / su)
  end
  boton:Show()
end

local ev = CreateFrame("Frame")
GL.Evento(ev, "PLAYER_REGEN_ENABLED")
GL.Evento(ev, "BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function() pcall(Actualizar) end)
local reloj = 0
ev:SetScript("OnUpdate", function(_, dt)
  reloj = reloj + (dt or 0)
  if reloj < 1 then return end
  reloj = 0
  local ok, err = pcall(Actualizar)
  if not ok and GL.Fallo then GL.Fallo(L"objeto de misión", err) end
end)

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "objetoMision", "Botón para usar el objeto de misión",
  "Junto a la flecha, cuando estás cerca del objetivo y la misión pide usar un objeto que llevas. Clic: lo usa.",
  function() return DB().objetoMision ~= false end, function(v) DB().objetoMision = v; pcall(Actualizar) end, pestana = "flecha" })

GL._objetoMision = { Elegir = Elegir, DeMision = DeMision, Actualizar = Actualizar, Boton = function() return boton end }

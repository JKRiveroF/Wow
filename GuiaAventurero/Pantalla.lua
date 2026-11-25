-- Pantalla.lua (7.5.10 y 7.5.11): barra de iconos en pantalla, fuera de la ventana (como la flecha).
-- Buffs de tu clase que te faltan (0/1; en grupo o banda, los que das a otros cuentan cuántos lo tienen) y la
-- mascota del cazador o el demonio del brujo con su estado. Cada icono se quita cuando ya está puesto.
-- Se mueve arrastrando y se apaga en Opciones > Ajustes. 7.9.8: también en combate. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local function DB() return GuiaAventureroDB end
local LADO, MAX = 36, 8

------------------------------------------------------------------------
-- Buffs por clase: ids del hechizo base (el nombre y el icono se leen del juego); alt = versiones que también
-- valen (las de grupo); grupo = se da a los demás y cuenta el grupo o la banda; uno = vale cualquiera de la lista.
------------------------------------------------------------------------
-- 7.9.2: todos los rangos de cada hechizo. Este cliente solo da por sabido el rango más alto, así que con el
-- rango 1 no salía ningún icono (el mago de nivel 19 tiene Armadura de escarcha rango 2, no el 1).
local BUFFS = {
  MAGE = { { ids = { 10157, 10156, 1461, 1460, 1459 }, alt = { 23028 }, grupo = true },
    { ids = { 22783, 22782, 6117, 10220, 10219, 7320, 7302, 7301, 7300, 168 }, uno = true, n = L"una armadura" } },
  PRIEST = { { ids = { 10938, 10937, 2791, 1245, 1244, 1243 }, alt = { 21562, 21564 }, grupo = true },
    { ids = { 10952, 10951, 1006, 602, 7128, 588 } } },
  DRUID = { { ids = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, alt = { 21849, 21850 }, grupo = true },
    { ids = { 9910, 9756, 8914, 1075, 782, 467 } } },
  PALADIN = { { ids = { 10293, 10292, 1032, 10291, 643, 10290, 465, 10301, 10300, 10299, 10298, 7294, 19746 }, uno = true, n = L"un aura" },
    { ids = { 25291, 19838, 19837, 19836, 19835, 19834, 19740, 25290, 19854, 19853, 19852, 19850, 19742, 20217, 1038 }, uno = true, n = L"una bendición" } },
  WARLOCK = { { ids = { 11735, 11734, 11733, 1086, 706, 696, 687 }, uno = true, n = L"una armadura" } },
  HUNTER = { { ids = { 25296, 14322, 14321, 14320, 14319, 14318, 13165, 13163, 5118, 13159 }, uno = true, n = L"un aspecto" } },
  SHAMAN = { { ids = { 10432, 10431, 8134, 945, 905, 325, 324 } } },
}

local function NombreHechizo(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, i = pcall(C_Spell.GetSpellInfo, id)
    if ok and type(i) == "table" then return i.name, i.iconID end
  end
  if GetSpellInfo then
    local n, _, icono = GetSpellInfo(id)
    return n, icono
  end
  return nil
end

-- Nombres de los hechizos del libro (se rehace al aprender hechizos)
local conocidos = nil
local function Conocidos()
  if conocidos then return conocidos end
  conocidos = {}
  local tipo = BOOKTYPE_SPELL or "spell"
  local leidos = 0
  if GetSpellBookItemName then
    for i = 1, 1000 do
      local ok, n = pcall(GetSpellBookItemName, i, tipo)
      if not ok or not n then break end
      conocidos[n] = true; leidos = leidos + 1
    end
  end
  -- 7.6.6: clientes sin la función antigua del libro
  if leidos == 0 and C_SpellBook and C_SpellBook.GetSpellBookItemName then
    local banco = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for i = 1, 1000 do
      local ok, n = pcall(C_SpellBook.GetSpellBookItemName, i, banco)
      if not ok or not n then break end
      conocidos[n] = true; leidos = leidos + 1
    end
  end
  local r = conocidos
  if leidos == 0 then conocidos = nil end   -- libro aún sin cargar: no se guarda vacío
  return r
end

-- 7.6.6: ¿sabes el hechizo? Por el libro (nombre) o, si el libro no lo da, preguntando al juego por el id.
local function Sabe(libro, nombre, id)
  if libro[nombre] then return true end
  local function Si(fn) if not fn then return false end local ok, v = pcall(fn, id); return ok and v and true or false end
  return Si(IsSpellKnown) or Si(IsPlayerSpell) or Si(C_SpellBook and C_SpellBook.IsSpellKnown) or false
end

-- 8.9.3: en combate el cliente de Forever da los nombres de los buffs como «valores secretos» que no se pueden
-- comparar: la guía no los veía y sacaba los iconos aunque los tuvieras puestos. Si pasa, se marca aquí.
local secreto = false
local function Secreto(v) return issecretvalue and issecretvalue(v) and true or false end

local function Buffs(unidad)
  local r = {}
  for i = 1, 40 do
    local n
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
      local ok, a = pcall(C_UnitAuras.GetBuffDataByIndex, unidad, i)
      n = ok and type(a) == "table" and a.name or nil
    elseif UnitBuff then
      n = UnitBuff(unidad, i)
    end
    if Secreto(n) then secreto = true; break end
    if not n then break end
    r[n] = true
  end
  return r
end

local function Unidades()
  local u = { "player" }
  if IsInRaid and IsInRaid() then
    u = {}
    for i = 1, 40 do if UnitExists("raid" .. i) then table.insert(u, "raid" .. i) end end
  elseif IsInGroup and IsInGroup() then
    for i = 1, 4 do if UnitExists("party" .. i) then table.insert(u, "party" .. i) end end
  end
  local vivas = {}
  for _, x in ipairs(u) do
    if not (UnitIsDeadOrGhost and UnitIsDeadOrGhost(x)) and not (UnitIsConnected and not UnitIsConnected(x)) then table.insert(vivas, x) end
  end
  return vivas
end

-- Lista de iconos: { icono, texto (0/1, 3/5), faltan = { nombres }, titulo, insignia = textura, coords }
local function Calcular()
  local lista = {}
  local clase = UnitClass and select(2, UnitClass("player"))
  local libro = Conocidos()
  local mios = Buffs("player")
  for _, b in ipairs(BUFFS[clase or ""] or {}) do
    local nombre, icono, sabe = nil, nil, false
    local valen = {}
    for _, id in ipairs(b.ids) do
      local n, ic = NombreHechizo(id)
      if n then
        valen[n] = true
        if not sabe and Sabe(libro, n, id) then sabe, nombre, icono = true, n, ic end
      end
    end
    for _, id in ipairs(b.alt or {}) do local n = NombreHechizo(id); if n then valen[n] = true end end
    if sabe then
      local function Tiene(buffs) for n in pairs(valen) do if buffs[n] then return true end end return false end
      if b.grupo then
        local us = Unidades()
        local con, faltan = 0, {}
        for _, u in ipairs(us) do
          if Tiene(u == "player" and mios or Buffs(u)) then con = con + 1 else table.insert(faltan, (UnitName and UnitName(u)) or u) end
        end
        if con < #us then
          table.insert(lista, { icono = icono, texto = con .. "/" .. #us, color = con > 0 and C.AMARILLO or "|cffff7070",
            titulo = nombre, faltan = faltan })
        end
      elseif not Tiene(mios) then
        table.insert(lista, { icono = icono, texto = "0/1", color = "|cffff7070", titulo = b.n and (L"Te falta " .. b.n .. ": " .. nombre) or nombre })
      end
    end
  end
  -- pícaro: armas sin veneno desde el nivel 20
  if clase == "ROGUE" and (UnitLevel and UnitLevel("player") or 1) >= 20 and GetWeaponEnchantInfo then
    local tiene = GetWeaponEnchantInfo()
    if not tiene then
      table.insert(lista, { icono = "Interface\\Icons\\Ability_Poisons", texto = "0/1", color = "|cffff7070", titulo = L"Arma sin veneno" })
    end
  end
  -- 7.5.11: mascota del cazador y demonio del brujo
  local llamar
  if clase == "HUNTER" then llamar = NombreHechizo(883) elseif clase == "WARLOCK" then llamar = NombreHechizo(688) end
  if llamar and Sabe(libro, llamar, clase == "HUNTER" and 883 or 688) then
    local _, iconoLlamar = NombreHechizo(clase == "HUNTER" and 883 or 688)
    -- 7.5.14: con el Sacrificio demoníaco puesto (la bonificación del demonio sacrificado) no hay que avisar
    local sacrificado = false
    if clase == "WARLOCK" then
      for _, id in ipairs({ 18789, 18790, 18791, 18792 }) do
        local n = NombreHechizo(id)
        if n and mios[n] then sacrificado = true end
      end
    end
    if sacrificado then
      -- nada: el demonio está sacrificado a propósito
    elseif not (UnitExists and UnitExists("pet")) then
      table.insert(lista, { icono = clase == "HUNTER" and "Interface\\Icons\\Ability_Hunter_BeastTaming" or "Interface\\Icons\\Spell_Shadow_SummonImp",
        desaturar = true, insignia = iconoLlamar, titulo = clase == "HUNTER" and L"Mascota sin llamar" or L"Sin demonio invocado" })
    else
      local icono = (GetPetIcon and GetPetIcon()) or iconoLlamar
      if UnitIsDead and UnitIsDead("pet") then
        table.insert(lista, { icono = icono, insignia = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", titulo = L"Tu mascota está muerta" })
      elseif clase == "HUNTER" and GetPetHappiness then
        local h = GetPetHappiness()
        local CARA = "Interface\\PetPaperDollFrame\\UI-PetHappiness"
        if h == 1 then
          table.insert(lista, { icono = icono, insignia = "Interface\\Icons\\INV_Misc_Food_14", titulo = L"Tu mascota está descontenta y hambrienta: dale de comer" })
        elseif h == 2 then
          table.insert(lista, { icono = icono, insignia = CARA, coords = { 0.1875, 0.375, 0, 0.359375 }, titulo = L"Tu mascota está contenta (pronto tendrá hambre)" })
        elseif h == 3 then
          table.insert(lista, { icono = icono, insignia = CARA, coords = { 0, 0.1875, 0, 0.359375 }, titulo = L"Tu mascota está alegre", alegre = true })
        end
      end
    end
  end
  return lista
end

------------------------------------------------------------------------
-- Barra
------------------------------------------------------------------------
local barra, botones = nil, {}
local alegreDesde = nil

local function Boton(i)
  if botones[i] then return botones[i] end
  local b = CreateFrame("Frame", nil, barra)
  b:SetWidth(LADO); b:SetHeight(LADO)
  b:SetPoint("TOPLEFT", barra, "TOPLEFT", 6 + (i - 1) * (LADO + 8), -6)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints()
  b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.insignia = b:CreateTexture(nil, "OVERLAY")
  b.insignia:SetWidth(18); b.insignia:SetHeight(18)
  b.insignia:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 6, -6)
  b.num = GL.Texto(b, "GameFontNormalSmall", "CENTER")
  b.num:SetPoint("TOP", b, "BOTTOM", 0, -2)
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.dato) then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.dato.titulo or "", 1, 0.82, 0)
    if self.dato.faltan and #self.dato.faltan > 0 then
      GameTooltip:AddLine(L"Sin él: " .. table.concat(self.dato.faltan, ", "), 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- 7.9.8: se arrastra con el botón izquierdo y se suelta al levantarlo (antes se quedaba pegada al ratón)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function() if not DB().bloqueada then barra:StartMoving(); barra.moviendo = true end end)
  b:SetScript("OnDragStop", function() barra.Soltar() end)
  botones[i] = b
  return b
end

local function Colocar()
  barra:ClearAllPoints()
  local p = DB().posBuffs
  if p then barra:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  elseif GL.flecha then barra:SetPoint("TOP", GL.flecha, "BOTTOM", 0, -6)
  else barra:SetPoint("TOP", UIParent, "TOP", 0, -260) end
end

local function Crear()
  if barra then return end
  barra = CreateFrame("Frame", "GuiaAventureroBuffs", UIParent)
  barra:SetHeight(LADO + 26)
  barra:SetMovable(true)
  barra:SetClampedToScreen(true)
  barra:SetFrameStrata("MEDIUM")
  barra.Guardar = function()
    local p, _, rp, x, y = barra:GetPoint()
    DB().posBuffs = { p, rp, x, y }
  end
  barra.Soltar = function()
    if not barra.moviendo then return end
    barra.moviendo = false
    barra:StopMovingOrSizing()
    barra.Guardar()
  end
  -- red de seguridad: si el botón del ratón ya no está pulsado, se suelta
  barra:SetScript("OnUpdate", function()
    if barra.moviendo and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then barra.Soltar() end
  end)
  Colocar()
  barra:Hide()
end

local function Actualizar()
  local db = DB()
  if type(db) ~= "table" then return end
  Crear()
  if db.barraBuffs == false then   -- 7.9.8: sigue en combate; solo se quita cada icono cuando el buff está puesto
    barra:Hide(); return
  end
  -- 8.9.3: en combate (o si los buffs vienen en secreto) se mantiene lo último que se vio fuera de combate,
  -- sin volver a leerlos; así no salen iconos de buffs que sí llevas puestos
  local enCombate = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
  secreto = false
  local lista
  if not enCombate then
    local ok, l = pcall(Calcular)
    if ok and type(l) == "table" and not secreto then lista = l; GL._ultimaListaBuffs = l end
  end
  if not lista then
    lista = {}
    for i, v in ipairs(GL._ultimaListaBuffs or {}) do lista[i] = v end
  end
  -- alegre se quita sola a los 10 s
  local hayAlegre = false
  for i = #lista, 1, -1 do
    if lista[i].alegre then
      hayAlegre = true
      alegreDesde = alegreDesde or ((GetTime and GetTime()) or 0)
      if ((GetTime and GetTime()) or 0) - alegreDesde > 10 then table.remove(lista, i) end
    end
  end
  if not hayAlegre then alegreDesde = nil end
  local n = math.min(#lista, MAX)
  for i = n + 1, #botones do botones[i]:Hide() end   -- 7.9.8: no se esconden los que siguen (esconderlos soltaba el arrastre)
  for i = 1, n do
    local b, d = Boton(i), lista[i]
    b.dato = d
    b.tex:SetTexture(d.icono or 134400)
    if b.tex.SetDesaturated then b.tex:SetDesaturated(d.desaturar and true or false) end
    if d.insignia then
      b.insignia:SetTexture(d.insignia)
      if d.coords then b.insignia:SetTexCoord(d.coords[1], d.coords[2], d.coords[3], d.coords[4]) else b.insignia:SetTexCoord(0, 1, 0, 1) end
      b.insignia:Show()
    else
      b.insignia:Hide()
    end
    b.num:SetText(d.texto and ((d.color or "") .. d.texto .. C.FIN) or "")
    b:Show()
  end
  barra:SetWidth(math.max(LADO + 12, 12 + n * (LADO + 8) - 8))
  if n > 0 or not barra.moviendo then GL.Mostrar(barra, n > 0) end
end

local ev = CreateFrame("Frame")
GL.Evento(ev, "SPELLS_CHANGED")
GL.Evento(ev, "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB")
GL.Evento(ev, "PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, evento)
  if evento == "PLAYER_REGEN_DISABLED" then return end   -- 7.9.8: en combate la barra sigue
  conocidos = nil
end)
local espera = 0
ev:SetScript("OnUpdate", function(_, dt)
  espera = espera + dt
  if espera < 0.5 then return end
  espera = 0
  local ok, e = pcall(Actualizar)
  if not ok and not GL._errorBuffs then   -- 7.6.6: antes el fallo se callaba
    GL._errorBuffs = true
    if GL.Mensaje then GL.Mensaje(L"error en los buffs en pantalla: " .. tostring(e)) elseif print then print(L"Guía del Aventurero: error en los buffs en pantalla: " .. tostring(e)) end
  end
end)
table.insert(GL.alReiniciar, function() if DB() then DB().posBuffs = nil end; if barra then Colocar() end end)

-- Para las pruebas
-- 7.9.2: para el informe de /ga depurar
GL.InformeBuffs = function()
  local db = DB() or {}
  local libro = Conocidos() or {}
  local nLibro = 0; for _ in pairs(libro) do nLibro = nLibro + 1 end
  local okL, lista = pcall(Calcular)
  local nombres = {}
  if okL then for _, d in ipairs(lista) do table.insert(nombres, tostring(d.titulo)) end end
  local mios = 0; for _ in pairs(Buffs("player")) do mios = mios + 1 end
  return L"opción " .. (db.barraBuffs == false and "apagada" or "encendida") ..
    L", hechizos en el libro " .. nLibro .. L", buffs puestos " .. mios ..
    L", iconos " .. (okL and (#lista .. (#lista > 0 and (" (" .. table.concat(nombres, ", ") .. ")") or "")) or (L"error: " .. tostring(lista))) ..
    L", barra " .. ((barra and barra:IsShown()) and "visible" or "oculta") .. (db.posBuffs and L", movida" or "")
end
GL._pantalla = { Calcular = Calcular, Actualizar = Actualizar, Olvidar = function() conocidos = nil end }

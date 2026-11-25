-- Misiones.lua: acepta y entrega solas las misiones de la guía y recomienda la recompensa. Creado por JKRiveroF.
-- Solo toca misiones que están en la ruta. Con Mayús pulsada al hablar con el PNJ no hace nada.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local aceptar, entregar = {}, {}      -- misiones de la ruta: las que se recogen y las que se entregan
local marca                           -- marca sobre la recompensa recomendada
local revisionDialogo = 0

local function DB() return GuiaAventureroDB end

local function PrepararMisiones()
  revisionDialogo = revisionDialogo + 1
  if marca then marca:Hide() end
  aceptar, entregar = {}, {}
  local secciones = GL.RUTA and GL.RUTA.secciones or {}
  for i = 1, #secciones do
    local pasos = secciones[i].pasos
    for j = 1, #pasos do
      local wp = pasos[j].wp or {}
      for k = 1, #wp do
        local d = wp[k]
        if d.q and d.a == "A" then aceptar[d.q] = true end
        if d.q and d.a == "T" then entregar[d.q] = true end
      end
    end
  end
end

local function Activo()
  if not DB() or DB().autoMisiones == false then return false end
  if GL.QuestieConvivencia976 and GL.QuestieConvivencia976() then return false end
  if IsShiftKeyDown and IsShiftKeyDown() then return false end
  return true
end

local function MisionDelDialogo()
  if not GetQuestID then return nil end
  local q = GL.Seguro(GetQuestID())
  if q == 0 then return nil end
  return q
end

local function Completa(q)
  if C_QuestLog and C_QuestLog.IsComplete then
    local ok, r = pcall(C_QuestLog.IsComplete, q)
    return ok and r
  end
  return false
end

------------------------------------------------------------------------
-- Recompensa recomendada
------------------------------------------------------------------------
-- Ranuras del equipo donde iría cada tipo de objeto (anillos y abalorios: se compara con el peor de los dos).
local RANURAS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
  INVTYPE_SHIELD = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
  INVTYPE_RELIC = { 18 },
}

local function Publico(v)
  return not (issecretvalue and issecretvalue(v))
end
local function Numero(v)
  return Publico(v) and type(v) == "number" and v > -math.huge and v < math.huge
end
local function Texto(v)
  return Publico(v) and type(v) == "string" and v ~= ""
end
local function LeerInfo(f, objeto)
  if type(f) ~= "function" then return nil end
  local ok, nombre, enlace, _, nivel, nivelReq, _, _, _, ranura, _, precio, clase, subclase = pcall(f, objeto)
  if not ok or not Texto(nombre) or not Texto(ranura) or not Numero(nivelReq) or nivelReq < 0
      or not Numero(clase) or not Numero(subclase) then return nil end
  if not Texto(enlace) then
    if not Texto(objeto) then return nil end
    enlace = objeto
  end
  return { nombre = nombre, enlace = enlace, ranura = ranura, precio = Numero(precio) and precio >= 0 and precio or 0,
    clase = clase, subclase = subclase, nivelReq = nivelReq, nivel = Numero(nivel) and nivel >= 0 and nivel or nil }
end
local function InfoObjeto(objeto)
  if not Publico(objeto) or not objeto then return nil end
  local f = C_Item and C_Item.GetItemInfo
  return LeerInfo(f, objeto) or (GetItemInfo ~= f and LeerInfo(GetItemInfo, objeto) or nil)
end
local function LeerStats(f, enlace)
  if type(f) ~= "function" then return nil end
  local ok, t = pcall(f, enlace)
  if not ok or not Publico(t) or type(t) ~= "table" or next(t) == nil then return nil end
  for k, v in pairs(t) do
    if not Texto(k) or not Numero(v) then return nil end
  end
  return t
end
local function Estadisticas(enlace)
  if not Publico(enlace) or not enlace then return nil end
  local f = C_Item and C_Item.GetItemStats
  return LeerStats(f, enlace) or (GetItemStats ~= f and LeerStats(GetItemStats, enlace) or nil)
end

local function Esta(lista, valor)
  for i = 1, #(lista or {}) do
    if lista[i] == valor then return true end
  end
  return false
end

-- Puedes llevarlo: armadura (clase 4) o arma (clase 2) de los tipos de la ruta; lo demás (bolsas, pociones) no cuenta.
-- equipo.nivelArmadura: tipos de armadura que se aprenden más tarde (la malla del chamán al 40).
-- equipo.dosManos: la ruta lleva arma de dos manos, así que escudos y objetos de la mano izquierda no sirven.
-- equipo.dobleArma: la ruta lleva un arma en cada mano (el pícaro): nada de armas de dos manos ni de objetos de la mano
-- izquierda que no son armas, y un arma de una mano se compara con la peor de las dos que llevas.
local MANO_IZQUIERDA = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true }
local NO_DOBLE = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_2HWEAPON = true }
local DOS_MANOS_ARMA = { 16, 17 }

-- Los requisitos especiales se consultan sin abrir ni modificar el tooltip visible.
-- Una API ausente o un resultado incompleto no demuestra que el objeto sea equipable.
local function RequisitosEspeciales(enlace)
  local f = C_TooltipInfo and C_TooltipInfo.GetHyperlink
  if not f or not enlace then return nil end
  local ok, datos = pcall(f, enlace)
  if not ok or type(datos) ~= "table" or type(datos.lines) ~= "table" or #datos.lines == 0 then return nil end
  local patrones = { "^requires%s", "^requirement%s", "^classes:", "^races:", "^requiere%s", "^requisito%s", "^clases:", "^razas:" }
  local incierto = false
  local completas = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item ~= nil and datos.type == Enum.TooltipDataType.Item and #datos.lines >= 2
  for _, linea in ipairs(datos.lines) do
    local texto = type(linea.leftText) == "string" and linea.leftText:lower() or ""
    -- Solo etiquetas explícitas: no confundir reputación o nombres de facciones con exclusividad.
    local faccion = ({["alliance only"]="Alliance", ["horde only"]="Horde", ["solo alianza"]="Alliance", ["solo horda"]="Horde", ["faction: alliance"]="Alliance", ["faction: horde"]="Horde", ["facción: alianza"]="Alliance", ["facción: horda"]="Horde"})[texto:match("^%s*(.-)%s*$")]
    if faccion then
      local okF, actual = false, nil
      if UnitFactionGroup then okF, actual = pcall(UnitFactionGroup, "player") end
      if okF and (actual == "Alliance" or actual == "Horde") then
        if actual ~= faccion then return false, linea.leftText end
      else incierto = true end
    end
    local color = linea.leftColor
    local rojo = type(color) == "table" and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" and color.r >= 0.7 and color.g < 0.35 and color.b < 0.35
    for _, patron in ipairs(patrones) do
      if texto:match(patron) and not texto:match("^requires level%s") and not texto:match("^requiere nivel%s") then
        if rojo then return false, linea.leftText end
        -- Solo colores explícitos de requisito satisfecho: otros colores o datos ausentes son inciertos.
        local verde = type(color) == "table" and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" and color.g >= 0.7 and color.r < 0.35 and color.b < 0.35
        if not verde then incierto = true end
      end
    end
  end
  -- Un tooltip de objeto identificado permite descartar avisos genéricos, no certificar requisitos ocultos.
  if completas and not incierto then return true end
  return nil
end

local function Usable(info, equipo, nivelObjetivo)
  if not info or not equipo or not RANURAS[info.ranura or ""] then return false end
  local nivelJugador = nivelObjetivo or ((UnitLevel and UnitLevel("player")) or 1)
  if (info.nivelReq or 0) > nivelJugador then return false end
  if RequisitosEspeciales(info.enlace) == false then return false end
  if equipo.dosManos and MANO_IZQUIERDA[info.ranura or ""] then return false end
  if equipo.dobleArma and NO_DOBLE[info.ranura or ""] then return false end
  if info.clase == 4 then
    local nivel = equipo.nivelArmadura and equipo.nivelArmadura[info.subclase]
    if nivel and nivelJugador < nivel then return false end
    return Esta(equipo.armadura, info.subclase)
  end
  if info.clase == 2 then return Esta(equipo.armas, info.subclase) end
  return false
end

-- Daño por segundo del arma: la varita (subclase 19) y las armas a distancia (arco 2, arma de fuego 3, arrojadiza 16
-- y ballesta 18) tienen su propio peso si la ruta lo trae (VARITA y DISTANCIA: el cazador, que vive de su arma a
-- distancia, y el pícaro, que casi no la usa); si no, cuentan como DPS.
local A_DISTANCIA = { [2] = true, [3] = true, [16] = true, [18] = true }

local function Puntuar(enlace, info, pesos)
  local total = 0
  local stats = Estadisticas(enlace)
  if not stats then return nil end
  -- Poder con hechizos y daño mágico pueden representar el mismo atributo.
  -- Solo deduplicar valores idénticos; si difieren, conservar la información.
  local poder = "ITEM_MOD_SPELL_POWER_SHORT"
  local dano = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"
  local duplicado = type(stats[poder]) == "number" and stats[poder] == stats[dano]
  for clave, valor in pairs(stats) do
    local peso = pesos[clave]
    if duplicado and pesos[poder] and pesos[dano] and clave == dano then peso = nil end
    if clave == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
      if info.clase == 2 and info.subclase == 19 then peso = pesos.VARITA or pesos.DPS or peso
      elseif info.clase == 2 and A_DISTANCIA[info.subclase] then peso = pesos.DISTANCIA or pesos.DPS or peso
      else peso = pesos.DPS or peso end
    end
    if peso and type(valor) == "number" then total = total + peso * valor end
  end
  return total
end

local function PuntuacionEquipada(ranuras, pesos)
  local peor
  for i = 1, #ranuras do
    local enlace = GetInventoryItemLink and GetInventoryItemLink("player", ranuras[i])
    local valor = 0
    if enlace then
      local info = InfoObjeto(enlace)
      if not info then return nil end
      valor = Puntuar(enlace, info, pesos)
      if valor == nil then return nil end
    end
    if peor == nil or valor < peor then peor = valor end
  end
  return peor or 0
end

-- Devuelve el coste de las piezas desplazadas, la ranura de destino y sus enlaces.
-- nil significa que no se puede comparar sin datos o sin cambiar otra arma.
-- Límites de categoría de equipo proporcionados por la API (si existe).
local function LimiteEquipo(enlace)
  local f = C_Item and C_Item.GetItemUniqueness
  if not f or not enlace then return nil end
  local ok, categoria, maximo = pcall(f, enlace)
  if ok and type(categoria) == "number" and categoria > 0 and type(maximo) == "number" and maximo >= 1 then
    return categoria, maximo
  end
end

local function RespetaLimite(info, destino)
  local categoria, maximo = LimiteEquipo(info.enlace)
  if not categoria then return true end
  local cantidad = 1
  for slot = 1, 19 do
    if slot ~= destino and not (info.ranura == "INVTYPE_2HWEAPON" and slot == 17) then
      local e = GetInventoryItemLink and GetInventoryItemLink("player", slot)
      if e and LimiteEquipo(e) == categoria then cantidad = cantidad + 1 end
    end
  end
  return cantidad <= maximo
end

local function CosteSustitucion(info, equipo, pesos)
  local tipo = info.ranura or ""
  local ranuras = RANURAS[tipo]
  if not ranuras then return nil end
  if equipo.dobleArma and tipo == "INVTYPE_WEAPON" then ranuras = DOS_MANOS_ARMA end
  local principal = GetInventoryItemLink and GetInventoryItemLink("player", 16)
  local ip = principal and InfoObjeto(principal)
  local dos = ip and ip.ranura == "INVTYPE_2HWEAPON"
  local mejor, destino, piezas
  for _, r in ipairs(ranuras) do
    if RespetaLimite(info, r) and not (r == 17 and (dos or (principal and not ip))) then
      local enlaces, total, valido = {}, 0, true
      local function Sumar(slot)
        local e = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if not e then return end
        local i = InfoObjeto(e)
        if not i then valido = false; return end
        enlaces[#enlaces + 1] = e
        local valor = Puntuar(e, i, pesos)
        if valor == nil then valido = false; return end
        total = total + valor
      end
      Sumar(r)
      if tipo == "INVTYPE_2HWEAPON" then Sumar(17) end
      if valido and (mejor == nil or total < mejor) then mejor, destino, piezas = total, r, enlaces end
    end
  end
  return mejor, destino, piezas
end

-- 6.4: lo usa Equipo.lua (comparador en los tooltips y pestaña Personaje > Equipo)
GL.EquipoUtil = { InfoObjeto = InfoObjeto, Estadisticas = Estadisticas, Usable = Usable, Puntuar = Puntuar, PuntuacionEquipada = PuntuacionEquipada,
  RequisitosEspeciales = RequisitosEspeciales, RANURAS = RANURAS, DOS_MANOS_ARMA = DOS_MANOS_ARMA, CosteSustitucion = CosteSustitucion }

local function BotonRecompensa(i)
  local f = QuestInfoRewardsFrame
  if f and f.RewardButtons then
    for _, b in pairs(f.RewardButtons) do
      if b.IsShown and b:IsShown() and b.type == "choice" and b.GetID and b:GetID() == i then return b end
    end
  end
  return _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
end

local function Marcar(i, motivo)
  local enlace = GetQuestItemLink and GetQuestItemLink("choice", i)
  GL.Mensaje(L"recompensa recomendada: " .. (enlace or (L"la número " .. i)) .. " (" .. motivo .. ").")
  local b = BotonRecompensa(i)
  if not b then return end
  if not marca then
    marca = CreateFrame("Frame", nil, b)
    marca.brillo = marca:CreateTexture(nil, "OVERLAY")
    marca.brillo:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    marca.brillo:SetBlendMode("ADD")
    marca.brillo:SetAllPoints(marca)
    marca.visto = marca:CreateTexture(nil, "OVERLAY")
    marca.visto:SetWidth(18)
    marca.visto:SetHeight(18)
    marca.visto:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    marca.visto:SetPoint("TOPLEFT", marca, "TOPLEFT", -6, 6)
  end
  marca:SetParent(b)
  marca:ClearAllPoints()
  marca:SetAllPoints(b.Icon or b.icon or b)
  marca:SetFrameLevel((b:GetFrameLevel() or 1) + 5)
  marca:Show()
end

local function Recomendar(n, intento, revision, q)
  if revision ~= revisionDialogo or not DB() or DB().recompensa == false then return end
  if q ~= MisionDelDialogo() or not GetNumQuestChoices or GetNumQuestChoices() ~= n then return end
  local equipo = GL.RUTA and GL.RUTA.equipo
  local mejor, mejora, caro, precio, faltan = nil, 0, nil, -1, false
  for i = 1, n do
    local enlace = GetQuestItemLink and GetQuestItemLink("choice", i)
    local info = InfoObjeto(enlace)
    if not info then
      faltan = true
    else
      local ranuras = RANURAS[info.ranura or ""]
      if equipo and equipo.dobleArma and info.ranura == "INVTYPE_WEAPON" then ranuras = DOS_MANOS_ARMA end
      if equipo and ranuras and Usable(info, equipo) then
        local coste = CosteSustitucion(info, equipo, equipo.pesos or {})
        local nota = Puntuar(enlace, info, equipo.pesos or {})
        local m = coste and nota and (nota - coste)
        if m == nil then faltan = true end
        if m and m > mejora then mejor, mejora = i, m end
      end
      if info.precio > precio then caro, precio = i, info.precio end
    end
  end
  -- el juego a veces aún no tiene los datos del objeto: se reintenta un momento después
  if faltan and (intento or 0) < 3 and C_Timer and C_Timer.After then
    C_Timer.After(0.4, function() Recomendar(n, (intento or 0) + 1, revision, q) end)
    return
  end
  if faltan then return end
  if mejor then
    Marcar(mejor, L"mejora tu equipo")
  elseif caro and precio > 0 then
    Marcar(caro, L"ninguna mejora tu equipo; es la que más vale en el vendedor")
  end
end

------------------------------------------------------------------------
-- Diálogos de misión
------------------------------------------------------------------------
local function AlDetalle()          -- te ofrecen una misión
  if not Activo() then return end
  local q = MisionDelDialogo()
  if q and aceptar[q] and AcceptQuest then AcceptQuest() end
end

local function AlProgreso()         -- vas a entregar: pide los objetos
  if not Activo() then return end
  local q = MisionDelDialogo()
  if q and entregar[q] and IsQuestCompletable and IsQuestCompletable() and CompleteQuest then CompleteQuest() end
end

local function AlCompletar()        -- ventana de recompensa
  local q = MisionDelDialogo()
  local n = (GetNumQuestChoices and GetNumQuestChoices()) or 0
  if n > 1 then
    if DB() and DB().recompensa ~= false then Recomendar(n, 0, revisionDialogo, q) end
    return
  end
  if Activo() and q and entregar[q] and GetQuestReward then GetQuestReward(n) end
end

local function AlSaludo()           -- PNJ con varias misiones (ventana de saludo)
  if not Activo() then return end
  for i = 1, ((GetNumActiveQuests and GetNumActiveQuests()) or 0) do
    local q = GetActiveQuestID and GetActiveQuestID(i)
    local lista = GetActiveTitle and select(2, GetActiveTitle(i))
    if SelectActiveQuest and q and entregar[q] and (lista or Completa(q)) then SelectActiveQuest(i); return end
  end
  for i = 1, ((GetNumAvailableQuests and GetNumAvailableQuests()) or 0) do
    local q = GetAvailableQuestInfo and select(5, GetAvailableQuestInfo(i))
    if SelectAvailableQuest and q and aceptar[q] then SelectAvailableQuest(i); return end
  end
end

local function AlChisme()           -- PNJ con opciones de diálogo
  if not Activo() or not C_GossipInfo then return end
  local activas = (C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()) or {}
  for i = 1, #activas do
    local info = activas[i]
    if C_GossipInfo.SelectActiveQuest and info.questID and entregar[info.questID] and (info.isComplete or Completa(info.questID)) then
      C_GossipInfo.SelectActiveQuest(info.questID)
      return
    end
  end
  local disponibles = (C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()) or {}
  for i = 1, #disponibles do
    local info = disponibles[i]
    if C_GossipInfo.SelectAvailableQuest and info.questID and aceptar[info.questID] then
      C_GossipInfo.SelectAvailableQuest(info.questID)
      return
    end
  end
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "QUEST_DETAIL")
GL.Evento(eventos, "QUEST_PROGRESS")
GL.Evento(eventos, "QUEST_COMPLETE")
GL.Evento(eventos, "QUEST_GREETING")
GL.Evento(eventos, "GOSSIP_SHOW")
GL.Evento(eventos, "QUEST_FINISHED")
eventos:SetScript("OnEvent", function(self, event)
  revisionDialogo = revisionDialogo + 1
  if marca then marca:Hide() end
  if not GL.RUTA then return end
  local f
  if event == "QUEST_DETAIL" then f = AlDetalle
  elseif event == "QUEST_PROGRESS" then f = AlProgreso
  elseif event == "QUEST_COMPLETE" then f = AlCompletar
  elseif event == "QUEST_GREETING" then f = AlSaludo
  elseif event == "GOSSIP_SHOW" then f = AlChisme
  elseif event == "QUEST_FINISHED" then
    if marca then marca:Hide() end
    return
  end
  if not f then return end
  local ok, err = pcall(f)
  if not ok and GL.Fallo("misiones", err) then GL.Mensaje(L"error: " .. tostring(err)) end
end)

table.insert(GL.alIniciar, PrepararMisiones)

GL.comandos["misiones"] = function()
  local db = DB()
  db.autoMisiones = (db.autoMisiones == false)
  GL.Mensaje(db.autoMisiones and L"aceptar y entregar solas las misiones de la guía: activado (Mayús para hacerlo a mano)."
    or L"aceptar y entregar solas las misiones de la guía: desactivado.")
end

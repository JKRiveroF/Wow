-- Equipo.lua (6.4): pestaña Personaje > Equipo (lo que busca la guía para tu clase, lo que llevas con su
-- durabilidad y el dinero) y comparador en los tooltips. Solo datos del juego y de la ruta: no inventa precios.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local ALTO_FILA = 16
local ROJO = "|cffff7070"
local NOMBRES_RANURA = {
  [1] = L"Cabeza", [2] = L"Cuello", [3] = L"Hombros", [5] = L"Pecho", [6] = L"Cintura", [7] = L"Piernas", [8] = L"Pies",
  [9] = L"Muñecas", [10] = L"Manos", [11] = L"Anillo 1", [12] = L"Anillo 2", [13] = L"Abalorio 1", [14] = L"Abalorio 2",
  [15] = L"Espalda", [16] = L"Mano derecha", [17] = L"Mano izquierda", [18] = L"A distancia",
}
local ORDEN = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
-- nombres de las estadísticas que más usan los pesos de las rutas (si el juego no da el suyo)
local NOMBRES_STAT = {
  ITEM_MOD_STRENGTH_SHORT = L"Fuerza", ITEM_MOD_AGILITY_SHORT = L"Agilidad", ITEM_MOD_STAMINA_SHORT = L"Aguante",
  ITEM_MOD_INTELLECT_SHORT = L"Intelecto", ITEM_MOD_SPIRIT_SHORT = L"Espíritu", RESISTANCE0_NAME = L"armadura",
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = L"daño por segundo", DPS = L"daño del arma", VARITA = L"daño de varita",
  DISTANCIA = L"daño a distancia",
  -- 7.9.5: las que faltaban (salían como ITEM_MOD_..._SHORT si el juego no las traía)
  ITEM_MOD_ATTACK_POWER_SHORT = L"poder de ataque", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = L"poder de ataque a distancia",
  ITEM_MOD_CRIT_RATING_SHORT = L"crítico", ITEM_MOD_HIT_RATING_SHORT = L"golpe",
  ITEM_MOD_CRIT_SPELL_RATING_SHORT = L"crítico con hechizos", ITEM_MOD_HIT_SPELL_RATING_SHORT = L"golpe con hechizos",
  ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = L"defensa", ITEM_MOD_DODGE_RATING_SHORT = L"esquivar",
  ITEM_MOD_MANA_REGENERATION_SHORT = L"maná cada 5 s", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = L"daño con hechizos",
  ITEM_MOD_SPELL_POWER_SHORT = L"poder con hechizos",
}

local function DB() return GuiaAventureroDB end
local function U() return GL.EquipoUtil end
local function Publico(v)
  return not (issecretvalue and issecretvalue(v))
end
local function NumeroValido(v)
  return Publico(v) and type(v) == "number" and v >= 0 and v < math.huge
end
local function Leer(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok and Publico(v) then return v end
end
local function Durabilidad(id)
  if type(GetInventoryItemDurability) ~= "function" then return nil end
  local ok, cur, max = pcall(GetInventoryItemDurability, id)
  if ok and NumeroValido(cur) and NumeroValido(max) and max > 0 and cur <= max then
    return cur / max
  end
end

local function NombreStat(clave)
  local g = NOMBRES_STAT[clave] or _G[clave]
  if type(g) == "string" and g ~= "" and not string.find(g, "%%") then return g end
  return NOMBRES_STAT[clave] or (string.find(clave, "^[A-Z0-9_]+$") and "" or clave)   -- 7.9.5: nunca un código
end

local function Equipo() return GL.RUTA and GL.RUTA.equipo end
local AVISO_REQUISITOS = L"Requisitos especiales sin confirmar"
local function RequisitosSinConfirmar(u, enlace)
  return not u.RequisitosEspeciales or u.RequisitosEspeciales(enlace) == nil
end

------------------------------------------------------------------------
-- Comparador en los tooltips
------------------------------------------------------------------------
local function Formato(n)
  local s = string.format("%.1f", n)
  s = string.gsub(s, "%.0$", "")
  return GL.FormatoDecimal(s)
end

local function Comparar(tooltip)
  if DB() == nil or DB().comparador == false or not U() or not Equipo() then return end
  if not tooltip or not tooltip.GetItem then return end
  local ok, _, enlace = pcall(tooltip.GetItem, tooltip)
  if not ok or not enlace then return end
  local u, equipo = U(), Equipo()
  local info = u.InfoObjeto(enlace)
  if not info then return end
  local valorEq, _, piezas = u.CosteSustitucion(info, equipo, equipo.pesos or {})
  if valorEq == nil then return end
  for _, e in ipairs(piezas) do if e == enlace then return end end
  local enlaceEq = piezas[1]
  tooltip:AddLine(" ")
  local nombreEq = enlaceEq and (u.InfoObjeto(enlaceEq) or {}).nombre
  if piezas[2] then nombreEq = (nombreEq or enlaceEq or "?") .. " + " .. ((u.InfoObjeto(piezas[2]) or {}).nombre or piezas[2]) end
  tooltip:AddLine(L"Guía del Aventurero" .. "  " .. C.GRIS .. (nombreEq and (L"frente a tu " .. nombreEq .. ":") or L"frente a la ranura vacía:") .. C.FIN,
    0.41, 0.80, 0.94)
  if not u.Usable(info, equipo) then
    tooltip:AddLine(L"No es para tu clase (o aún no puedes llevar ese tipo): la guía no la recomienda.", 0.6, 0.6, 0.6, true)
    tooltip:Show()
    return
  end
  if RequisitosSinConfirmar(u, enlace) then
    tooltip:AddLine(AVISO_REQUISITOS, 1, 0.82, 0, true)
  end
  -- diferencias de estadísticas
  local nuevas = u.Estadisticas(enlace)
  if not nuevas then return end
  local viejas = {}
  for _, e in ipairs(piezas) do
    local stats = u.Estadisticas(e)
    if not stats then return end
    for k, v in pairs(stats) do
      if type(v) == "number" then viejas[k] = (viejas[k] or 0) + v end
    end
  end
  local claves, partes = {}, {}
  for k in pairs(nuevas) do claves[k] = true end
  for k in pairs(viejas) do claves[k] = true end
  local lista = {}
  for k in pairs(claves) do table.insert(lista, k) end
  table.sort(lista, function(a, b)
    local pa, pb = (equipo.pesos or {})[a] or 0, (equipo.pesos or {})[b] or 0
    if pa ~= pb then return pa > pb end
    return a < b
  end)
  for _, k in ipairs(lista) do
    local d = (tonumber(nuevas[k]) or 0) - (tonumber(viejas[k]) or 0)
    if math.abs(d) >= 0.05 and NombreStat(k) ~= "" then
      -- 9.4.2: con flecha verde (sube) o roja (baja) delante, para verlo de un vistazo
      table.insert(partes, (d > 0 and (GL.Icono("▲") .. C.VERDE .. "+") or (GL.Icono("▼") .. ROJO)) .. Formato(d) .. " " .. NombreStat(k) .. C.FIN)
    end
  end
  tooltip:AddLine(#partes > 0 and table.concat(partes, ", ") or (C.GRIS .. L"Mismas estadísticas." .. C.FIN), 1, 1, 1, true)
  local nota = u.Puntuar(enlace, info, equipo.pesos or {})
  if nota == nil then return end
  local dif = nota - valorEq
  local veredicto
  -- 9.4.2: en % frente a lo que llevas (antes, puntos de la nota interna, que no se entendían)
  local base = valorEq or 0
  local pct = base > 0.05 and ((dif >= 0 and 1 or -1) * math.floor(math.abs(dif / base * 100) + 0.5)) or nil
  if dif > 0.05 and (not pct or pct >= 1) then
    veredicto = GL.Icono("▲") .. " " .. C.VERDE .. (pct and (L"mejor (+" .. pct .. " %)") or L"mejor (tienes la ranura vacía)") .. C.FIN
  elseif dif < -0.05 and (not pct or pct <= -1) then
    veredicto = GL.Icono("▼") .. " " .. ROJO .. (pct and (L"peor (" .. pct .. " %)") or L"peor") .. C.FIN
  else veredicto = L"igual" end
  tooltip:AddLine(L"Según lo que busca la guía para tu clase: " .. veredicto, 1, 0.82, 0, true)
  local nivel = UnitLevel and UnitLevel("player") or 1
  if (info.nivelReq or 0) > nivel then
    tooltip:AddLine(L"Aún no la puedes usar: requiere nivel " .. info.nivelReq .. ".", 0.6, 0.6, 0.6, true)
  end
  tooltip:Show()
end

-- 7.9.1: en este cliente el tooltip puede no tener OnTooltipSetItem; si falla, el resto del archivo (la pestaña) se carga igual
GL.EngancharTooltipObjeto(function(t) pcall(Comparar, t) end, L"comparador de Equipo")

------------------------------------------------------------------------
-- Personaje > Equipo
------------------------------------------------------------------------
local panel, ui = nil, { filas = {} }

local function Prioridad()
  local equipo = Equipo()
  if not equipo or not equipo.pesos then return C.GRIS .. L"Tu ruta no tiene pesos de equipo." .. C.FIN end
  local lista = {}
  for k, v in pairs(equipo.pesos) do
    if type(v) == "number" and v > 0 then table.insert(lista, { k = k, v = v }) end
  end
  table.sort(lista, function(a, b)
    if a.v ~= b.v then return a.v > b.v end
    return a.k < b.k
  end)
  local partes, vistos = {}, {}
  for _, e in ipairs(lista) do
    local n = NombreStat(e.k)
    if n ~= "" and not vistos[n] then vistos[n] = true; table.insert(partes, n) end
    if #partes >= 5 then break end
  end
  return table.concat(partes, C.GRIS .. "  ›  " .. C.FIN)
end

local function Color(enlace)
  local c = enlace and string.match(enlace, "|c(%x%x%x%x%x%x%x%x)")
  return c and ("|c" .. c) or C.BLANCO
end

-- 7.6: mejor pieza a tu nivel por ranura, del botín de las mazmorras de tu nivel (DatosWowhead.lua), con los pesos de tu ruta.
local MEJORES = 6   -- 9.4.2: sin el bloque Dinero caben más
local BASE = 6     -- 9.4.2: hueco que dejaba el dinero abajo (antes 96)
local cacheMejores, cacheT, cacheContexto = nil, -100, nil
-- Prioridad: mejoras equipables ahora, luego ganancia, nivel y orden estable.
local function Antes(a, b)
  if a.futura ~= b.futura then return not a.futura end
  if a.requisitosSinConfirmar ~= b.requisitosSinConfirmar then return not a.requisitosSinConfirmar end
  if a.gana ~= b.gana then return a.gana > b.gana end
  if a.nivelReq ~= b.nivelReq then return a.nivelReq < b.nivelReq end
  if a.mision ~= b.mision then return a.mision == true end
  if a.r ~= b.r then return a.r < b.r end
  return a.id < b.id
end
local function MejoresANivel()
  local ahora = (GetTime and GetTime()) or 0
  local u, equipo = U(), Equipo()
  local res = {}
  if not (u and equipo) then return res end
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  local pesos = equipo.pesos or {}
  local db = DB()
  if type(db) ~= "table" then db = {} end
  local contexto = table.concat({tostring(GL.RUTA), tostring(equipo), tostring(pesos), tostring(nivel), tostring(db.especializacion), tostring(db.seccion)}, "|")
  if cacheMejores and cacheContexto == contexto and ahora >= cacheT and ahora - cacheT < 10 then return cacheMejores end
  local function Ranuras(info)
    if not info then return nil end
    if equipo.dobleArma and info.ranura == "INVTYPE_WEAPON" then return u.DOS_MANOS_ARMA end
    return u.RANURAS[info.ranura or ""]
  end
  local ok, datos = false, nil
  if GL.WH and GL.WH.jefes and GL.DatosMazmorras then ok, datos = pcall(GL.DatosMazmorras) end
  local mejor = {}
  for _, m in ipairs((ok and datos) or {}) do
    if m.min <= nivel + 2 and m.max >= nivel - 4 then
      for _, j in ipairs((GL.JefesVisibles976 and GL.JefesVisibles976(m.clave or m.n)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[m.clave or m.n]) or {}) do
        for _, o in ipairs(j.botin or {}) do
          local info = u.InfoObjeto(o.id)
          local enlace = info and info.enlace
          local ranuras = Ranuras(info)
          if ranuras and info.nivelReq <= nivel and u.Usable(info, equipo) then
            local coste, r = u.CosteSustitucion(info, equipo, pesos)
            local nota = u.Puntuar(enlace, info, pesos)
            local gana = coste and nota and (nota - coste)
            if r and gana and gana > 0 then
              local e = { r = r, id = o.id, enlace = enlace, gana = gana, m = m, jefe = j.n,
                futura = false, nivelReq = info.nivelReq, mision = false, requisitosSinConfirmar = RequisitosSinConfirmar(u, enlace) }
              if not mejor[r] or Antes(e, mejor[r]) then mejor[r] = e end
            end
          end
        end
      end
    end
  end
  -- 9.2: también las recompensas de las misiones de tu ruta que aún no has entregado, desde tu sección hasta las de
  -- 2 niveles más (datos de RecompensasRuta.lua; lo que sale es la mejor de las que puedes elegir)
  local secs = GL.RUTA and GL.RUTA.secciones
  local s0 = math.max(1, math.floor(tonumber(db.seccion) or 1))
  if secs and GL.RecompensasMision then
    for s = s0, #secs do
      local sec = secs[s]
      if (sec.min or 1) > nivel + 2 then break end
      for _, paso in ipairs(sec.pasos or {}) do
        for _, d in ipairs(paso.wp or {}) do
          if d.a == "T" and d.q and not (GL.MisionCompletada and GL.MisionCompletada(d.q)) then
            for _, id in ipairs(GL.RecompensasMision(d.q) or {}) do
              local info = u.InfoObjeto(id)
              local enlace = info and info.enlace
              local ranuras = Ranuras(info)
              if ranuras and info.nivelReq <= nivel + 2 and u.Usable(info, equipo, nivel + 2) then
                local coste, r = u.CosteSustitucion(info, equipo, pesos)
                local nota = u.Puntuar(enlace, info, pesos)
            local gana = coste and nota and (nota - coste)
                if r and gana and gana > 0 then
                  local nombre = tostring(d.n or ""):match("^%S+: (.-) %(") or tostring(d.n or L"Misión")
                  local e = { r = r, id = id, enlace = enlace, gana = gana, m = { n = sec.titulo or L"Ruta" }, jefe = nombre,
                    mision = true, futura = info.nivelReq > nivel or not u.Usable(info, equipo, nivel), nivelReq = math.max(info.nivelReq, (equipo.nivelArmadura or {})[info.clase == 4 and info.subclase or -1] or 0), requisitosSinConfirmar = RequisitosSinConfirmar(u, enlace) }
                  if not mejor[r] or Antes(e, mejor[r]) then mejor[r] = e end
                end
              end
            end
          end
        end
      end
    end
  end
  for _, v in pairs(mejor) do table.insert(res, v) end
  table.sort(res, Antes)
  cacheMejores, cacheT, cacheContexto = res, ahora, contexto
  return res
end
GL.MejorEquipoANivel976 = MejoresANivel
GL._mejoresANivel = function() cacheMejores = nil; return MejoresANivel() end

-- 7.6.3: la pantalla se pinta por partes; si una falla, las demás salen igual y el error se dice una vez en el chat.
local avisados = {}
local function Parte(nombre, fn)
  local ok, err = pcall(fn)
  if not ok and not avisados[nombre] then
    avisados[nombre] = true
    if GL.Mensaje then GL.Mensaje(L"error en Equipo (" .. nombre .. "): " .. tostring(err)) end
  end
end

local function PintarMejores()
  -- 7.6: mejor a tu nivel
  local okM, mejores = pcall(MejoresANivel)
  mejores = (okM and mejores) or {}
  ui.mejorTitulo:SetText(L"Mejor a tu nivel " .. C.GRIS .. "(" .. ((UnitLevel and UnitLevel("player")) or 1) .. L", mazmorras y misiones de tu ruta)" .. C.FIN)
  for i = 1, MEJORES do
    local fm, e = ui.mejor[i], mejores[i]
    fm.e = e
    if e then
      fm.texto:SetText((NOMBRES_RANURA[e.r] or "?") .. ": " .. e.enlace .. " " .. C.VERDE .. "+" .. math.floor(e.gana + 0.5) .. C.FIN ..
        C.GRIS .. (e.futura and (" · " .. L"Nivel requerido" .. " " .. e.nivelReq) or "") .. (e.requisitosSinConfirmar and (" · " .. AVISO_REQUISITOS) or "") .. " · " .. e.m.n .. " (" .. e.jefe .. ")" .. C.FIN)
      fm:Show()
    else
      fm:Hide()
    end
  end
  ui.mejorVacio:SetText(#mejores == 0 and (C.GRIS .. L"Nada mejor que lo tuyo para tu nivel (o faltan objetos por cargar)." .. C.FIN) or "")
end

-- 9.0: muñeco. Las ranuras alrededor del personaje con el color de la calidad; flecha verde donde hay mejora cerca.
local LADO, PASO_R = 26, 28
local IZQ_R = { 1, 2, 3, 15, 5, 4, 19, 9 }
local DER_R = { 10, 6, 7, 8, 11, 12, 13, 14 }
local ABAJO_R = { 16, 17, 18 }
local NOMBRE_EXTRA = { [4] = L"Camisa", [19] = L"Tabardo" }
local function Ranura(padre, id)
  local b = CreateFrame("Button", nil, padre, BackdropTemplateMixin and "BackdropTemplate" or nil)
  b:SetSize(LADO, LADO)
  b.id = id
  b.borde = b:CreateTexture(nil, "BACKGROUND")
  b.borde:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
  b.borde:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
  b.icono = b:CreateTexture(nil, "ARTWORK")
  b.icono:SetAllPoints()
  b.icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.roto = b:CreateTexture(nil, "OVERLAY")
  b.roto:SetAllPoints()
  b.roto:SetColorTexture(1, 0.1, 0.1, 0.35)
  b.flecha = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.flecha:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 3)
  b.flecha:SetText(GL.Icono("↑"))
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local hay = GameTooltip.SetInventoryItem and GameTooltip:SetInventoryItem("player", self.id)
    if not hay then GameTooltip:AddLine(NOMBRES_RANURA[self.id] or NOMBRE_EXTRA[self.id] or L"Ranura", 1, 1, 1); GameTooltip:AddLine(L"Vacía", 0.6, 0.6, 0.6) end
    if self.mejora then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L"Mejora cerca: " .. (self.mejora.enlace or "?"), 0.25, 0.9, 0.35)
      GameTooltip:AddLine(self.mejora.m.n .. " · " .. self.mejora.jefe, 0.7, 0.7, 0.75)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local ALTO_MUNECO = #IZQ_R * PASO_R + PASO_R + 4
local function CrearMuneco()
  local m = CreateFrame("Frame", nil, panel)
  m:SetHeight(ALTO_MUNECO)
  m.ranuras = {}
  for i, id in ipairs(IZQ_R) do
    local b = Ranura(m, id); b:SetPoint("TOPLEFT", m, "TOPLEFT", 1, -(i - 1) * PASO_R - 1); m.ranuras[id] = b
  end
  for i, id in ipairs(DER_R) do
    local b = Ranura(m, id); b:SetPoint("TOPRIGHT", m, "TOPRIGHT", -1, -(i - 1) * PASO_R - 1); m.ranuras[id] = b
  end
  for i, id in ipairs(ABAJO_R) do
    local b = Ranura(m, id); b:SetPoint("TOP", m, "TOP", (i - 2) * (PASO_R + 4), -#IZQ_R * PASO_R - 2); m.ranuras[id] = b
  end
  m.fondo = m:CreateTexture(nil, "BACKGROUND")
  m.fondo:SetPoint("TOPLEFT", m, "TOPLEFT", LADO + 10, 0)
  m.fondo:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -LADO - 10, PASO_R + 6)
  m.fondo:SetColorTexture(1, 1, 1, 0.03)
  local okM, modelo = pcall(CreateFrame, "PlayerModel", nil, m)
  if okM and modelo then
    modelo:SetPoint("TOPLEFT", m.fondo, "TOPLEFT", 4, -4)
    modelo:SetPoint("BOTTOMRIGHT", m.fondo, "BOTTOMRIGHT", -4, 22)
    m.modelo = modelo
  end
  m.nivel = GL.Texto(m, "GameFontHighlightSmall")
  m.nivel:SetPoint("BOTTOM", m.fondo, "BOTTOM", 0, 6)
  return m
end

local function PintarMuneco(y)
  if not ui.muneco then ui.muneco = CrearMuneco() end
  local m = ui.muneco
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  m:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  m:Show()
  if m.modelo and m.modelo.SetUnit then pcall(m.modelo.SetUnit, m.modelo, "player") end
  local mejoras = {}
  local okM, lista = pcall(MejoresANivel)
  for _, e in ipairs((okM and lista) or {}) do if e.r and not e.futura and not e.requisitosSinConfirmar and not mejoras[e.r] then mejoras[e.r] = e end end
  local suma, n = 0, 0
  local fInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  for id, b in pairs(m.ranuras) do
    local tex = Leer(GetInventoryItemTexture, "player", id)
    if type(tex) ~= "string" and not NumeroValido(tex) then tex = nil end
    local enlace = Leer(GetInventoryItemLink, "player", id)
    if type(enlace) ~= "string" then enlace = nil end
    b.icono:SetTexture(tex or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    b.icono:SetDesaturated(not tex)
    local q = Leer(GetInventoryItemQuality, "player", id)
    if not NumeroValido(q) then q = nil end
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c and c.r then b.borde:SetColorTexture(c.r, c.g, c.b, 0.9) else b.borde:SetColorTexture(0.2, 0.2, 0.25, 1) end
    local dur = Durabilidad(id)
    local roto = dur ~= nil and dur < 0.3
    GL.Mostrar(b.roto, roto)
    b.mejora = mejoras[id]
    GL.Mostrar(b.flecha, b.mejora ~= nil)
    if enlace and fInfo and id ~= 4 and id ~= 19 then
      local ok, _, _, _, ni = pcall(fInfo, enlace)
      if ok and NumeroValido(ni) then suma, n = suma + ni, n + 1 end
    end
  end
  m.nivel:SetText(n > 0 and (C.GRIS .. L"nivel medio de objeto " .. C.FIN .. C.BLANCO .. math.floor(suma / n + 0.5) .. C.FIN) or "")
end

-- 9.4.2: lo de reparar va en la cabecera de «Lo que llevas» (el bloque Dinero ya está en Oro)
local function Reparar()
  local db = DB()
  local rep = type(db) == "table" and db.ultimaReparacion
  if not NumeroValido(rep) or rep <= 0 then return "" end
  local D = GL.Dinero or function(c) return tostring(c) end
  return C.GRIS .. L"  ·  reparar todo: " .. C.FIN .. D(rep)
end

local function PintarLlevas()
  local u = U()
  ui.prioridad:SetText(Prioridad())
  if type(GuiaAventureroDB) == "table" and GuiaAventureroDB.muneco ~= false then   -- 9.0: el muñeco en lugar de la lista
    local hP = math.max(14, math.ceil(ui.prioridad:GetStringHeight() or 14))
    ui.cabLlevas:ClearAllPoints()
    ui.cabLlevas:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(20 + hP + 8))
    ui.cabLlevas:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    local rep = Reparar()   -- 9.4.2: con precio de reparar no cabe también lo de la flecha (sale en la ayuda de las ranuras)
    ui.cabLlevas:SetText(rep ~= "" and (L"Lo que llevas" .. rep) or (L"Lo que llevas " .. C.GRIS .. L"(flecha verde: hay mejora cerca)" .. C.FIN))
    ui.yLista = 20 + hP + 8 + 20
    for _, f in ipairs(ui.filas) do f:Hide() end
    ui.resto:SetText("")
    PintarMuneco(ui.yLista)
    if ui.desp then ui.desp:Ajustar(ui.yLista + ALTO_MUNECO + 8 + (BASE + 22 + MEJORES * 18) + 20) end
    return
  end
  if ui.muneco then ui.muneco:Hide() end
  ui.cabLlevas:SetText(L"Lo que llevas (lo más gastado primero)" .. Reparar())
  -- 7.9.2: si lo que busca la guía ocupa dos líneas, lo de debajo baja (antes se pisaban)
  local hP = math.max(14, math.ceil(ui.prioridad:GetStringHeight() or 14))
  ui.cabLlevas:ClearAllPoints()
  ui.cabLlevas:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(20 + hP + 8))
  ui.cabLlevas:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  ui.yLista = 20 + hP + 8 + 20
  for i, f in ipairs(ui.filas) do
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -ui.yLista - (i - 1) * ALTO_FILA)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -ui.yLista - (i - 1) * ALTO_FILA)
  end
  -- lo que llevas: primero lo que tiene menos durabilidad
  local filas, vacias = {}, {}
  for _, r in ipairs(ORDEN) do
    local e = Leer(GetInventoryItemLink, "player", r)
    if type(e) == "string" then
      local nombre = string.match(e, "%[(.-)%]") or NOMBRES_RANURA[r]
      local nivelObj
      local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
      if f then local ok, _, _, _, ni = pcall(f, e); if ok and NumeroValido(ni) then nivelObj = ni end end
      local proporcion = Durabilidad(r)
      local dur = proporcion and math.floor(proporcion * 100 + 0.5)
      table.insert(filas, { nombre = Color(e) .. nombre .. C.FIN, nivel = nivelObj, dur = dur, orden = dur or 101 })
    else
      table.insert(vacias, NOMBRES_RANURA[r])
    end
  end
  table.sort(filas, function(a, b) return a.orden < b.orden end)
  local caben = #ui.filas
  local mostrar = math.min(#filas, (#vacias > 0) and (caben - 1) or caben)
  for i = 1, caben do
    local f, e = ui.filas[i], filas[i]
    if i <= mostrar and e then
      f.nombre:SetText(e.nombre)
      f.nivel:SetText(e.nivel and (C.GRIS .. L"nv " .. e.nivel .. C.FIN) or "")
      local col = C.VERDE
      if e.dur and e.dur < 30 then col = ROJO elseif e.dur and e.dur < 70 then col = C.AMARILLO end
      f.dur:SetText(e.dur and (col .. e.dur .. " %" .. C.FIN) or "")
      f:Show()
    else
      f:Hide()
    end
  end
  local resto = ""
  if #filas > mostrar then resto = L"y " .. (#filas - mostrar) .. L" piezas más. " end
  if #vacias > 0 then resto = resto .. L"Vacías: " .. table.concat(vacias, ", ", 1, math.min(#vacias, 6)) .. (#vacias > 6 and "..." or "") end
  ui.resto:SetText(C.GRIS .. resto .. C.FIN)
  ui.resto:ClearAllPoints()
  ui.resto:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -ui.yLista - mostrar * ALTO_FILA - 2)
  ui.resto:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  -- 7.9.2: alto que hace falta para que no se pise con lo de abajo; si no cabe, sale la barra
  if ui.desp then ui.desp:Ajustar(ui.yLista + mostrar * ALTO_FILA + 2 + 16 + 8 + (BASE + 22 + MEJORES * 18) + 20) end
end

local function Refrescar()
  if not panel or not panel:IsShown() then return end
  Parte(L"mejor a tu nivel", PintarMejores)
  Parte(L"lo que llevas", PintarLlevas)
end

local function Par(y, abajo)
  local k = GL.Texto(panel, "GameFontHighlightSmall")
  local v = GL.Texto(panel, "GameFontHighlightSmall", "RIGHT")
  if abajo then
    k:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, y)
    v:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, y)
  else
    k:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    v:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y)
  end
  GL.UnaLinea(k); GL.UnaLinea(v)
  return k, v
end

local function Seccion(texto, y, abajo)
  local t = GL.Texto(panel, "GameFontNormal")
  if abajo then t:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, y) else t:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y) end
  t:SetText(texto)
  local linea = panel:CreateTexture(nil, "ARTWORK")
  linea:SetHeight(1)
  linea:SetColorTexture(1, 1, 1, 0.08)
  linea:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -3)
  linea:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  return t
end

local function Disponer()
  if not panel then return end
  local visible = (ui.desp and ui.desp.sf:GetHeight()) or (panel:GetHeight() or 0)   -- 7.9.2: el alto de la ventana, no el del panel
  local libre = visible - ui.yLista - (BASE + 16) - 16 - 22 - MEJORES * 18   -- abajo: mejor a tu nivel y la línea de vacías
  local caben = math.max(3, math.floor(libre / ALTO_FILA))
  for i = #ui.filas + 1, caben do
    local f = CreateFrame("Frame", nil, panel)
    f:SetHeight(ALTO_FILA)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -ui.yLista - (i - 1) * ALTO_FILA)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -ui.yLista - (i - 1) * ALTO_FILA)
    f.dur = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.dur:SetPoint("RIGHT", f, "RIGHT", 0, 0); f.dur:SetWidth(44)
    f.nivel = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.nivel:SetPoint("RIGHT", f.dur, "LEFT", -4, 0); f.nivel:SetWidth(44)
    f.nombre = GL.Texto(f, "GameFontHighlightSmall")
    f.nombre:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.nombre:SetPoint("RIGHT", f.nivel, "LEFT", -4, 0)
    GL.UnaLinea(f.nombre)
    ui.filas[i] = f
  end
  for i = #ui.filas, caben + 1, -1 do ui.filas[i]:Hide(); ui.filas[i] = nil end
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + GL.ALTO_SUB))
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  Seccion(L"Lo que busca la guía para tu clase", 0)
  ui.prioridad = GL.Texto(panel, "GameFontHighlightSmall")
  ui.prioridad:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -20)
  ui.prioridad:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  ui.cabLlevas = Seccion(L"Lo que llevas (lo más gastado primero)", -42)
  ui.cabLlevas:SetPoint("RIGHT", panel, "RIGHT", 0, 0); GL.UnaLinea(ui.cabLlevas)   -- 9.4.2: con lo de reparar no se sale
  ui.yLista = 62
  ui.resto = GL.Texto(panel, "GameFontHighlightSmall")
  GL.UnaLinea(ui.resto)
  -- 7.6: mejor a tu nivel (encima del dinero)
  local yM = BASE + 22 + MEJORES * 18
  ui.mejorTitulo = GL.Texto(panel, "GameFontNormal")
  ui.mejorTitulo:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, yM)
  ui.mejorTitulo:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, yM); GL.UnaLinea(ui.mejorTitulo)   -- 7.6.1: dentro del marco
  ui.mejorVacio = GL.Texto(panel, "GameFontHighlightSmall")
  ui.mejorVacio:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, yM - 18)
  ui.mejorVacio:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  GL.UnaLinea(ui.mejorVacio)
  ui.mejor = {}
  for i = 1, MEJORES do
    local fm = CreateFrame("Frame", nil, panel)
    fm:SetHeight(18)
    fm:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, yM - 4 - i * 18)
    fm:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, yM - 4 - i * 18)
    fm.ver = GL.CrearBoton(fm, L"Ver", function(self)
      local e = self:GetParent().e
      if e and not e.mision and GL.AbrirMazmorra then GL.AbrirMazmorra(e.m.n) end
    end, nil, 16)
    fm.ver:SetWidth(40)
    fm.ver:SetPoint("RIGHT", fm, "RIGHT", 0, 0)
    if GL.Ayuda then GL.Ayuda(fm.ver, L"Ver", L"Abre la mazmorra en la guía de mazmorras, con sus jefes y su botín.") end
    fm.texto = GL.Texto(fm, "GameFontHighlightSmall")
    fm.texto:SetPoint("LEFT", fm, "LEFT", 0, 0)
    fm.texto:SetPoint("RIGHT", fm.ver, "LEFT", -4, 0)
    GL.UnaLinea(fm.texto)
    fm:Hide()
    ui.mejor[i] = fm
  end
  ui.desp = GL.Desplazable and GL.Desplazable(panel)   -- 7.9.2
  local hecho = false
  local function Cambio()   -- el panel cambia de alto al ajustarlo: no volver a entrar
    if hecho then return end
    hecho = true; pcall(Disponer); pcall(Refrescar); hecho = false
  end
  if ui.desp then ui.desp.sf:HookScript("OnSizeChanged", Cambio) else panel:SetScript("OnSizeChanged", Cambio) end
  Disponer()
  GL.modos.equipo = { panel = panel, refrescar = function() Disponer(); Refrescar() end }
end

table.insert(GL.alIniciar, CrearPanel)

-- coste de reparar todo, apuntado en cada vendedor que repara; y refresco al cambiar el equipo o el dinero
local eventos = CreateFrame("Frame")
GL.Evento(eventos, "MERCHANT_SHOW")
GL.Evento(eventos, "PLAYER_EQUIPMENT_CHANGED")
GL.Evento(eventos, "PLAYER_LEVEL_UP")
GL.Evento(eventos, "GET_ITEM_INFO_RECEIVED")
GL.Evento(eventos, "UPDATE_INVENTORY_DURABILITY")
GL.Evento(eventos, "PLAYER_MONEY")
GL.Evento(eventos, "QUEST_TURNED_IN")
GL.Evento(eventos, "QUEST_LOG_UPDATE")
eventos:SetScript("OnEvent", function(_, evento)
  if evento == "PLAYER_EQUIPMENT_CHANGED" or evento == "PLAYER_LEVEL_UP" or evento == "GET_ITEM_INFO_RECEIVED" or evento == "QUEST_TURNED_IN" or evento == "QUEST_LOG_UPDATE" then cacheMejores=nil end
  if evento == "MERCHANT_SHOW" and type(GuiaAventureroDB) == "table" and CanMerchantRepair and GetRepairAllCost then
    local ok, puede = pcall(CanMerchantRepair)
    if ok and Publico(puede) and (puede == true or puede == 1) then
      local ok2, coste = pcall(GetRepairAllCost)
      if ok2 and NumeroValido(coste) then GuiaAventureroDB.ultimaReparacion = coste end
    end
  end
  pcall(Refrescar)
end)

GL.ajustesInterfaz = GL.ajustesInterfaz or {}   -- 9.0
table.insert(GL.ajustesInterfaz, { "muneco", "Equipo con muñeco",
  "En Personaje › Equipo, las ranuras alrededor de tu personaje con el color de la calidad. Apagado: la lista de antes, con la durabilidad.",
  function() return type(GuiaAventureroDB) == "table" and GuiaAventureroDB.muneco ~= false end,
  function(v) GuiaAventureroDB.muneco = v; pcall(Refrescar) end, pestana = "aspecto" })

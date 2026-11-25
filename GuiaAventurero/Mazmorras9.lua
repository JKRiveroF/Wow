-- Mazmorras9.lua (9.0): modo mazmorra automático. Al entrar en una mazmorra que conoce la guía, la ventana
-- deja sitio a un panel compacto con los jefes en orden (los muertos tachados y el siguiente marcado), cuántos
-- objetos útiles tiene cada uno y las misiones de esa mazmorra. Clic en un jefe: su botín con «Todo el botín» y
-- «Útil para ti», como en la pestaña Mazmorras. Al salir de la mazmorra vuelve sola la guía. Se puede apagar.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local function DB() return GuiaAventureroDB or {} end
local function Si(k) return DB()[k] ~= false end
local function Minus(s)
  if issecretvalue and issecretvalue(s) then return "" end
  return (type(s) == "string") and s:lower() or ""
end
local function Ahora() return (time and time()) or 0 end
local function Consulta(f, ...)
  if type(f) ~= "function" then return nil end
  local ok, a, b = pcall(f, ...)
  if not ok then return nil end
  if issecretvalue and issecretvalue(a) then a = nil end
  if issecretvalue and issecretvalue(b) then b = nil end
  return a, b
end

-- cuántos objetos de un jefe te sirven (los puedes llevar según tu ruta); el juego tiene que conocer el objeto
function GL.UtilesDeJefe(j)
  if not (j and j.botin and GL.BotinUtil) then return 0, 0 end
  local n, mejor = 0, 0
  for _, o in ipairs(j.botin) do
    local ok, util, mej = pcall(GL.BotinUtil, o.id)
    if ok and util then n = n + 1; if mej then mejor = mejor + 1 end end
  end
  return n, mejor
end

local function NombreJefe(j) return ((j.n or "?"):gsub("^[^:]+: ", "")) end

local function BuscarMazmorra(nombre)
  if not GL.DatosMazmorras or Minus(nombre) == "" then return nil end
  local ok, datos = pcall(GL.DatosMazmorras)
  if not ok or type(datos) ~= "table" then return nil end
  local b = Minus(nombre)
  -- 9.3.5: el nombre del juego puede estar en español o en inglés (sea cual sea el idioma de la guía)
  local function Nombres(m) return Minus(m.clave or m.n), Minus(GL.EnIngles and GL.EnIngles(m.clave or m.n) or m.n) end
  for _, m in ipairs(datos) do
    local es, en = Nombres(m)
    if es == b or en == b then return m end
  end
  -- No elegir una instancia por un fragmento ambiguo del nombre.
  return nil
end

-- 9.7.6: una banda de Datos94 (Bandas.lua) con la forma de una mazmorra para el modo mazmorra
local function BuscarBanda(nombre)
  if Minus(nombre) == "" then return nil end
  local b = Minus(nombre)
  for _, r in ipairs((GL.D94 and GL.D94.bandas) or {}) do
    local es = r.clave or r.n
    for _, n in ipairs({ Minus(es), Minus(r.ing), Minus(r.n) }) do
      if n ~= "" and n == b then
        return { n = r.n, clave = es, banda = true, jugadores = r.jugadores, min = r.nivel, max = r.nivel, misiones = {},
          mapaNombre = (GL.clienteIngles and r.ing) or es }
      end
    end
  end
  return nil
end
GL._buscarMazmorra = BuscarMazmorra
GL._buscarBanda = BuscarBanda   -- para las pruebas

local actual   -- la mazmorra en la que estás (tabla de Mazmorras.lua)
local ven
local function Muertos()
  local db = DB()
  if type(db.mazMuertos) ~= "table" or db.mazMuertos.n ~= (actual and actual.n) then
    db.mazMuertos = { n = actual and actual.n, t = Ahora(), jefes = {} }
  end
  if type(db.mazMuertos.jefes) ~= "table" then db.mazMuertos.jefes = {} end
  return db.mazMuertos.jefes
end

-- 9.7.6: el jefe bajo el ratón en el mapa (resaltado) o elegido con clic, marcado en la lista
local resaltado, elegido = nil, nil
local function Clave(j) return GL.ClaveJefe and j and GL.ClaveJefe(j.n) or nil end
local function MarcarFilas()
  if not ven then return end
  local a = GL.COLOR.acento
  for _, f in ipairs(ven.filas) do
    local k = Clave(f.jefe)
    if f:IsShown() and k and (k == resaltado or k == elegido) then f.marca:SetColorTexture(1, 0.82, 0, k == resaltado and 0.26 or 0.18)
    else f.marca:SetColorTexture(a[1], a[2], a[3], f.esSig and 0.14 or 0) end
  end
end
function GL.ResaltarJefePanel(k) resaltado = k; MarcarFilas() end
function GL.ElegirJefePanel(k) elegido = k; MarcarFilas() end

local function Fila(i)
  local f = ven.filas[i]
  if f then return f end
  f = CreateFrame("Button", nil, ven)
  f:SetHeight(18)
  f.marca = f:CreateTexture(nil, "BACKGROUND")
  f.marca:SetAllPoints()
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.06)
  f.der = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
  f.der:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  f.texto = GL.Texto(f, "GameFontHighlightSmall")
  f.texto:SetPoint("LEFT", f, "LEFT", 6, 0)
  f.texto:SetPoint("RIGHT", f.der, "LEFT", -4, 0)
  if f.texto.SetWordWrap then f.texto:SetWordWrap(false) end
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnClick", function(self, boton)
    if not self.jefe then return end
    if boton == "RightButton" then   -- clic derecho: marcar o desmarcar como muerto a mano
      local m = Muertos()
      m[self.jefe.n] = not m[self.jefe.n] or nil
      GL.RefrescarModoMazmorra()
      return
    end
    -- 9.7.6: queda elegido en la lista y en el mapa
    elegido = Clave(self.jefe); MarcarFilas()
    local MM = GL.MapaModoMazmorra
    if MM then MM.Elegir(elegido) end
    if GL.VerBotin then
      local b = GL.VerBotin(NombreJefe(self.jefe), self.jefe.botin or {})
      if MM and MM.AnclarBotin then MM.AnclarBotin(b)
      elseif b and ven then b:ClearAllPoints(); b:SetPoint("TOPLEFT", ven, "TOPRIGHT", 8, 0) end
    end
  end)
  if GL.Ayuda then GL.Ayuda(f, L"Jefe", L"Clic: su botín (todo o lo útil para ti). Clic derecho: marcar como muerto.") end
  -- 9.7.6: al pasar el ratón, el jefe se resalta también en el mapa
  f:HookScript("OnEnter", function(self)
    resaltado = Clave(self.jefe); MarcarFilas()
    if GL.MapaModoMazmorra then GL.MapaModoMazmorra.Resaltar(resaltado) end
  end)
  f:HookScript("OnLeave", function()
    resaltado = nil; MarcarFilas()
    if GL.MapaModoMazmorra then GL.MapaModoMazmorra.Resaltar(nil) end
  end)
  ven.filas[i] = f
  return f
end

local function Crear()
  ven = CreateFrame("Frame", "GuiaAventureroModoMazmorra", UIParent, PLANTILLA)
  ven:SetWidth(300); ven:SetHeight(200)
  ven:SetFrameStrata("MEDIUM")
  ven:SetMovable(true); ven:EnableMouse(true); ven:SetClampedToScreen(true)
  ven:RegisterForDrag("LeftButton")
  ven:SetScript("OnDragStart", function(self) if not DB().bloqueada then self:StartMoving() end end)
  ven:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    DB().posMazmorra = { p, rp, x, y }
  end)
  GL.Caja(ven, GL.COLOR.fondo, GL.COLOR.borde)
  ven.raya = ven:CreateTexture(nil, "ARTWORK")
  ven.raya:SetHeight(2)
  ven.raya:SetPoint("TOPLEFT", ven, "TOPLEFT", 1, -1)
  ven.raya:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -1, -1)
  ven.etiqueta = GL.Texto(ven, "GameFontHighlightSmall")
  ven.etiqueta:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -9)
  ven.titulo = GL.Texto(ven, "GameFontNormal")
  ven.titulo:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -22)
  ven.titulo:SetPoint("RIGHT", ven, "RIGHT", -70, 0)
  if ven.titulo.SetWordWrap then ven.titulo:SetWordWrap(false) end
  ven.salir = GL.CrearBoton(ven, L"Salir", function() GL.SalirModoMazmorra(true) end, nil, 18)
  ven.salir:SetWidth(56)
  ven.salir:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -8, -8)
  if GL.Ayuda then GL.Ayuda(ven.salir, L"Salir del modo mazmorra", L"Vuelve la guía. En esta mazmorra no vuelve a salir hasta que entres otra vez.") end
  ven.cabJefes = GL.Texto(ven, "GameFontHighlightSmall")
  ven.cabMisiones = GL.Texto(ven, "GameFontHighlightSmall")
  ven.misiones = GL.Texto(ven, "GameFontHighlightSmall")
  ven.mapa = GL.CrearBoton(ven, L"Mapa", function()
    -- 9.7.6: el mapa vuelve debajo de las misiones; si no hay dibujo, la pestaña Mazmorras como antes
    if actual and GL.MapaModoMazmorra and GL.MapaModoMazmorra.Abrir(actual) then GL.RefrescarModoMazmorra(); return end
    if GL.frame and not GL.frame:IsShown() and GL.AlternarVentana then GL.AlternarVentana() end
    if actual and GL.AbrirMazmorra then GL.AbrirMazmorra(actual.n) end
    if actual and GL._abrirMapaMazmorra then pcall(GL._abrirMapaMazmorra, actual) end
  end, nil, 20)
  ven.mapa:SetWidth(80)
  ven.botin = GL.CrearBoton(ven, L"Botín útil", function()
    if not actual then return end
    local todos = {}
    for _, j in ipairs((GL.JefesVisibles976 and GL.JefesVisibles976(actual.clave or actual.n)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[actual.clave or actual.n]) or {}) do
      for _, o in ipairs(j.botin or {}) do table.insert(todos, o) end
    end
    local b = GL.VerBotin and GL.VerBotin(actual.n .. L" · todo el botín", todos)
    if b then b:ClearAllPoints(); b:SetPoint("TOPLEFT", ven, "TOPRIGHT", 8, 0) end
  end, nil, 20, "accion")
  ven.botin:SetWidth(100)
  ven.filas = {}
  local pos = DB().posMazmorra
  if type(pos) == "table" and pos[1] then ven:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  elseif GL.frame then ven:SetPoint("TOPLEFT", GL.frame, "TOPLEFT", 0, 0)
  else ven:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60) end
  if GL.Pegable then pcall(GL.Pegable, ven, function(f) local p, _, rp, x, y = f:GetPoint(); DB().posMazmorra = { p, rp, x, y } end) end
  if GL.ConstruirBarraXP then   -- la barra de XP también en el modo mazmorra
    ven.barraXP = GL.ConstruirBarraXP(ven, 14)
    ven.barraXP:SetPoint("BOTTOMLEFT", ven, "TOPLEFT", 0, 4)
    ven.barraXP:SetPoint("BOTTOMRIGHT", ven, "TOPRIGHT", 0, 4)
    ven.barraXP:SetHeight(14)
  end
  ven:Hide()
end

function GL.RefrescarModoMazmorra()
  if not ven or not actual then return end
  local a = GL.COLOR.acento
  ven.raya:SetColorTexture(a[1], a[2], a[3], 1)
  ven.etiqueta:SetText(string.format(L"|cff%02x%02x%02xMODO MAZMORRA|r", a[1] * 255, a[2] * 255, a[3] * 255))
  ven.titulo:SetText(C.BLANCO .. actual.n .. C.FIN .. C.GRIS .. "  " .. (actual.banda and (actual.jugadores and (actual.jugadores .. L" jugadores") or "")
    or (tostring(actual.min) .. "-" .. tostring(actual.max))) .. C.FIN)
  local jefes = (GL.JefesVisibles976 and GL.JefesVisibles976(actual.clave or actual.n)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[actual.clave or actual.n]) or {}
  local muertos = Muertos()
  local y = 44
  ven.cabJefes:ClearAllPoints()
  ven.cabJefes:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -y)
  ven.cabJefes:SetText(C.GRIS .. "JEFES" .. C.FIN .. ((#jefes == 0) and (C.GRIS .. L"  aún no se conocen" .. C.FIN) or ""))
  y = y + 16
  for _, f in ipairs(ven.filas) do f:Hide() end
  local siguiente = false
  for i, j in ipairs(jefes) do
    local f = Fila(i)
    f.jefe = j
    local ubicacion = GL.UbicacionJefe977 and GL.UbicacionJefe977(j)
    f.ayudaTexto = L"Clic: su botín (todo o lo útil para ti). Clic derecho: marcar como muerto."
    if ubicacion then f.ayudaTexto = f.ayudaTexto .. "\n" .. ubicacion end
    local muerto = muertos[j.n]
    local util, mejor = GL.UtilesDeJefe(j)
    local esSig = not muerto and not siguiente
    if esSig then siguiente = true end
    local nombre = NombreJefe(j)
    if muerto then f.texto:SetText(GL.Icono("✓") .. " " .. C.GRIS .. nombre .. C.FIN)
    elseif esSig then f.texto:SetText(C.AMARILLO .. "› " .. nombre .. C.FIN .. C.GRIS .. L"  siguiente" .. C.FIN)
    else f.texto:SetText("|cffd0d2dc" .. nombre .. C.FIN) end
    local der = ""
    if util > 0 then der = C.VERDE .. util .. (util == 1 and L" útil" or L" útiles") .. C.FIN .. ((mejor > 0) and (" " .. GL.Icono("▲")) or "") end
    f.der:SetText(der)
    f.esSig = esSig
    f.marca:SetColorTexture(a[1], a[2], a[3], esSig and 0.14 or 0)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", ven, "TOPLEFT", 6, -y)
    f:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -6, -y)
    f:Show()
    y = y + 18
  end
  -- misiones de la mazmorra
  y = y + 6
  ven.cabMisiones:ClearAllPoints()
  ven.cabMisiones:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -y)
  ven.cabMisiones:SetText(C.GRIS .. "MISIONES" .. C.FIN)
  y = y + 16
  local l = {}
  for _, q in ipairs(actual.misiones or {}) do
    local enDiario = q.q and GL.MisionEnDiario and GL.MisionEnDiario(q.q)
    local hecha = q.q and GL.MisionCompletada and GL.MisionCompletada(q.q)
    if enDiario then
      local prog = ""
      if GL.ProgresoDestino then
        local ok, p = pcall(GL.ProgresoDestino, { q = q.q, a = "C" }, false)
        if ok and type(p) == "string" then prog = "  " .. p end
      end
      table.insert(l, C.AMARILLO .. "• " .. q.n .. C.FIN .. prog)
    elseif hecha then
      table.insert(l, GL.Icono("✓") .. " " .. C.GRIS .. q.n .. C.FIN)
    end
  end
  if #l == 0 then l[1] = C.GRIS .. (actual.banda and L"No llevas misiones de esta banda." or L"No llevas misiones de esta mazmorra.") .. C.FIN end
  local txt = table.concat(l, "\n")
  ven.misiones:ClearAllPoints()
  ven.misiones:SetPoint("TOPLEFT", ven, "TOPLEFT", 12, -y)
  ven.misiones:SetWidth(276)
  ven.misiones:SetText(txt)
  y = y + ((GL.Alto and GL.Alto(ven.misiones, txt, 12, 276)) or (#l * 14)) + 10
  -- 9.7.6: el mapa, debajo de las misiones (con «Ampliar» se va a la derecha del panel)
  local mf = GL.MapaModoMazmorra and GL.MapaModoMazmorra.Frame()
  if mf and mf.modo == "dentro" and mf:IsShown() then
    mf:ClearAllPoints()
    mf:SetPoint("TOPLEFT", ven, "TOPLEFT", 6, -y)
    mf:SetSize((ven:GetWidth() or 300) - 12, GL.MapaModoMazmorra.ALTO)
    y = y + GL.MapaModoMazmorra.ALTO + 8
  end
  ven.mapa:ClearAllPoints()
  ven.mapa:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -y)
  ven.botin:ClearAllPoints()
  if GL.MAPAS_MAZMORRAS then
    ven.mapa:Show()
    ven.botin:SetPoint("LEFT", ven.mapa, "RIGHT", 6, 0)
  else   -- 9.4.2: mapas apagados: sin botón Mapa, Botín útil en su sitio
    ven.mapa:Hide()
    ven.botin:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -y)
  end
  ven:SetHeight(y + 30)
  MarcarFilas()
end

local ventanaAntes, descartada = nil, nil
local function Entrar(m)
  if not ven then Crear() end
  if not actual or actual.n ~= m.n then resaltado, elegido = nil, nil end
  local cambiando = actual ~= nil
  actual = m
  if not cambiando and GL.frame then
    ventanaAntes = GL.frame:IsShown()
    if ventanaAntes then GL.frame:Hide() end
  end
  if not cambiando and GL.franja and GL.franja:IsShown() then GL.franja:Hide(); ventanaAntes = "franja" end
  ven:Show()
  GL.RefrescarModoMazmorra()
  if Si("mapaModoMazmorra") and GL.MapaModoMazmorra then pcall(GL.MapaModoMazmorra.Abrir, m); GL.RefrescarModoMazmorra() end   -- 9.7.6
  if GL.Mensaje then GL.Mensaje((m.banda and L"modo banda: " or L"modo mazmorra: ") .. m.n .. L". Al salir vuelve la guía.") end
end

function GL.SalirModoMazmorra(aMano)
  if aMano and actual then descartada = actual.n end
  if ven then ven:Hide() end
  if GL.MapaModoMazmorra then pcall(GL.MapaModoMazmorra.Cerrar) end   -- 9.7.6
  if not actual then return end
  actual = nil
  if ventanaAntes == "franja" and GL.PonerTamano then pcall(GL.PonerTamano, "franja")
  elseif ventanaAntes and GL.frame then GL.frame:Show() end
  ventanaAntes = nil
  if GL.Refrescar then GL.Refrescar() end
end

local function Mirar()
  if not Si("modoMazmorra") then if actual then GL.SalirModoMazmorra() end return end
  local dentro, tipo = Consulta(IsInInstance)
  -- Una consulta fallida no equivale a abandonar la instancia.
  if type(dentro) ~= "boolean" or (dentro and type(tipo) ~= "string") then return end
  if dentro and (tipo == "party" or tipo == "raid") then
    local buscar = tipo == "party" and BuscarMazmorra or BuscarBanda
    local nombre = Consulta(GetInstanceInfo)
    local zona = Consulta(GetZoneText)
    if Minus(nombre) == "" and Minus(zona) == "" then return end
    local m = buscar(nombre) or buscar(zona)
    if m and descartada and m.n ~= descartada then descartada = nil end
    if m and m.n ~= descartada and (not actual or actual.n ~= m.n) then Entrar(m)
    elseif actual and (not m or m.n == descartada) then GL.SalirModoMazmorra() end
  else
    descartada = nil
    if actual then GL.SalirModoMazmorra() end
  end
end
GL._modoMazmorra = { Entrar = Entrar, Mirar = Mirar, Actual = function() return actual end }

-- jefe muerto: por el encuentro o por el registro de combate (con el nombre)
local function Matar(nombre)
  if not actual or Minus(nombre) == "" then return end
  local b = Minus(nombre)
  for _, j in ipairs((GL.JefesVisibles976 and GL.JefesVisibles976(actual.clave or actual.n)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[actual.clave or actual.n]) or {}) do
    local n = Minus(NombreJefe(j)):gsub(" %(.*%)$", "")
    local en = GL.EnIngles and Minus(GL.EnIngles(NombreJefe(j))):gsub(" %(.*%)$", "") or n
    if n ~= "" and (n == b or en == b) then
      local muertos = Muertos()
      if not muertos[j.n] then muertos[j.n] = true; GL.RefrescarModoMazmorra() end
      return
    end
  end
end

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "modoMazmorra", "Modo mazmorra automático",
  "Al entrar en una mazmorra o banda, un panel con sus jefes en orden, el botín útil y sus misiones. Al salir vuelve la guía.",
  function() return Si("modoMazmorra") end, function(v) DB().modoMazmorra = v; pcall(Mirar) end, pestana = "general" })
-- 9.7.6: el mapa dentro del panel al entrar
table.insert(GL.ajustesInterfaz, { "mapaModoMazmorra", "Mapa en el modo mazmorra",
  "Al entrar en una mazmorra o banda, su mapa sale en el panel, debajo de las misiones. «Ampliar» lo pone más grande a su derecha.",
  function() return Si("mapaModoMazmorra") end, function(v)
    DB().mapaModoMazmorra = v
    if not GL.MapaModoMazmorra then return end
    if v and actual then pcall(GL.MapaModoMazmorra.Abrir, actual) elseif not v then pcall(GL.MapaModoMazmorra.Cerrar) end
    pcall(GL.RefrescarModoMazmorra)
  end, pestana = "general" })

table.insert(GL.alIniciar, function()
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:RegisterEvent("QUEST_LOG_UPDATE")
  pcall(f.RegisterEvent, f, "ENCOUNTER_END")
  pcall(f.RegisterEvent, f, "BOSS_KILL")
  -- 9.7.4: en WoW Forever un addon no puede escuchar el registro de combate (COMBAT_LOG_EVENT_UNFILTERED):
  -- el juego lo bloquea y sale ADDON_ACTION_FORBIDDEN. Además del fin de encuentro, se mira si tu objetivo muere.
  pcall(f.RegisterEvent, f, "PLAYER_TARGET_CHANGED")
  if f.RegisterUnitEvent then pcall(f.RegisterUnitEvent, f, "UNIT_HEALTH", "target") end
  f:SetScript("OnEvent", function(_, evento, a1, a2, _, _, a5)
    if evento == "UNIT_HEALTH" or evento == "PLAYER_TARGET_CHANGED" then
      if not actual or Consulta(UnitExists, "target") ~= true then return end
      if Consulta(UnitIsDead, "target") == true then pcall(Matar, Consulta(UnitName, "target")) end
    elseif evento == "ENCOUNTER_END" then
      if not (issecretvalue and issecretvalue(a5)) and a5 == 1 then pcall(Matar, a2) end
    elseif evento == "BOSS_KILL" then
      pcall(Matar, a2)
    elseif evento == "QUEST_LOG_UPDATE" then
      if actual then pcall(GL.RefrescarModoMazmorra) end
    else
      pcall(Mirar)
    end
  end)
  pcall(Mirar)
end)

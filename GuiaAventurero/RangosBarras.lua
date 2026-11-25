-- RangosBarras.lua (9.5): al aprender un rango nuevo de un hechizo que tienes en las barras de acción, sale un aviso
-- para cambiar en las barras el rango viejo por el nuevo con un clic (o hacerlo siempre solo, si lo eliges).
-- Solo fuera de combate: en combate el juego no deja tocar las barras, y el aviso espera a que acabe.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local function DB() return GuiaAventureroDB or {} end
local function Activo() return DB().rangosBarras ~= false end
local function Auto() return DB().rangosAuto == true end

local MAX_RANURA = 144
local ESPERA = 1.5          -- el instructor enseña varios de golpe: se juntan en un solo aviso

local function Nombre(id)
  local ok, n = pcall(function()
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
  end)
  return ok and n or nil
end

-- número de rango («Rango 4», «Rank 4»); 0 si no tiene
local function NumRango(id)
  local ok, r = pcall(function()
    if C_Spell and C_Spell.GetSpellSubtext then return C_Spell.GetSpellSubtext(id) end
    return GetSpellSubtext and GetSpellSubtext(id)
  end)
  return (ok and type(r) == "string" and tonumber(r:match("(%d+)"))) or 0
end

-- el rango más alto que conoces de ese hechizo (el juego lo da al pedirlo por el nombre)
local function MejorRango(nombre)
  local ok, id = pcall(function()
    if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(nombre); return i and i.spellID end
    return GetSpellInfo and select(7, GetSpellInfo(nombre))
  end)
  return ok and id or nil
end

local function Conocido(id)
  if GL.HechizoConocido then local ok, r = pcall(GL.HechizoConocido, id); if ok and r then return true end end
  if IsPlayerSpell then local ok, r = pcall(IsPlayerSpell, id); if ok and r then return true end end
  if IsSpellKnown then local ok, r = pcall(IsSpellKnown, id); if ok and r then return true end end
  return false
end

local function EnCombate() return InCombatLockdown and InCombatLockdown() end

-- 9.7.4: el mejor rango que conoces de un hechizo de las barras. Se mira la cadena de rangos de la ruta y,
-- además, lo que da el juego por el nombre; gana el rango más alto. Devuelve nuevo, rangoNuevo, rangoViejo.
local function MejorQue(id, nombre)
  local cand = {}
  local cadena = GL.CadenaDeHechizo and GL.CadenaDeHechizo(id)
  if cadena then
    local pos
    for i, x in ipairs(cadena) do if x == id then pos = i end end
    if pos then
      for i = #cadena, pos + 1, -1 do
        if Conocido(cadena[i]) then
          local rn, rv = NumRango(cadena[i]), NumRango(id)
          if rn == 0 or rv == 0 then rn, rv = i, pos end   -- sin el texto «Rango N»: su lugar en la cadena
          table.insert(cand, { cadena[i], rn, rv })
          break
        end
      end
    end
  end
  local mejor = nombre and MejorRango(nombre)
  if mejor and mejor ~= id and Conocido(mejor) then
    local rn, rv = NumRango(mejor), NumRango(id)
    if rn > rv then table.insert(cand, { mejor, rn, rv }) end
  end
  local elegido
  for _, c in ipairs(cand) do if not elegido or c[2] > elegido[2] then elegido = c end end
  if elegido then return elegido[1], elegido[2], elegido[3] end
  return nil
end

-- Ranuras de las barras con un rango viejo de los hechizos aprendidos. nombres: { [nombre] = true } o nil (todos).
-- Devuelve una lista { { nombre, nuevo, viejo, rangoNuevo, rangoViejo, ranuras = {...} } }.
local function Buscar(nombres)
  local porHechizo, lista = {}, {}
  if not GetActionInfo then return lista end
  local ignorar = DB().rangosIgnorados or {}
  for ranura = 1, MAX_RANURA do
    local ok, tipo, id = pcall(GetActionInfo, ranura)
    if ok and tipo == "spell" and id then
      local nombre = Nombre(id)
      if (nombre or not nombres) and (not nombres or nombres[nombre]) then
        local mejor, rn, rv = MejorQue(id, nombre)
        if mejor and not ignorar[id .. ">" .. mejor] then
          local clave = id .. ">" .. mejor
          local h = porHechizo[clave]
          if not h then
            h = { nombre = nombre or Nombre(mejor) or "?", nuevo = mejor, viejo = id, rangoNuevo = rn, rangoViejo = rv, ranuras = {} }
            porHechizo[clave] = h
            table.insert(lista, h)
          end
          table.insert(h.ranuras, ranura)
        end
      end
    end
  end
  return lista
end

local function Sustituir(lista)
  if EnCombate() or not PickupSpell or not PlaceAction then return 0 end
  local n = 0
  for _, h in ipairs(lista) do
    for _, ranura in ipairs(h.ranuras) do
      local ok = pcall(function()
        ClearCursor()
        PickupSpell(h.nuevo)
        PlaceAction(ranura)
        ClearCursor()
      end)
      if ok then n = n + 1 end
    end
  end
  return n
end

local function Linea(h)
  local veces = #h.ranuras == 1 and L"1 botón" or (#h.ranuras .. L" botones")
  return C.AMARILLO .. h.nombre .. C.FIN .. C.GRIS .. "  " .. L"rango" .. " " .. h.rangoViejo .. " → " .. C.FIN ..
    C.VERDE .. h.rangoNuevo .. C.FIN .. C.GRIS .. "  (" .. veces .. ")" .. C.FIN
end

-- ventana del aviso
local aviso, pendiente
local function CrearAviso()
  local f = CreateFrame("Frame", "GuiaAventureroRangosBarras", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(360, 120)
  f:SetPoint("TOP", UIParent, "TOP", 0, -150)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if GL.Caja and GL.COLOR then GL.Caja(f, GL.COLOR.fondo, GL.COLOR.borde) end
  f.icono = f:CreateTexture(nil, "ARTWORK")
  f.icono:SetSize(32, 32)
  f.icono:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  f.titulo = GL.Texto(f, "GameFontNormal")
  f.titulo:SetPoint("TOPLEFT", f.icono, "TOPRIGHT", 8, -1)
  f.titulo:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.titulo:SetText(L"Rango nuevo en tus barras")
  f.sub = GL.Texto(f, "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", f.titulo, "BOTTOMLEFT", 0, -3)
  f.sub:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.sub:SetText(C.GRIS .. L"Tus botones siguen con el rango viejo. ¿Los cambio por el nuevo?" .. C.FIN)
  f.lista = GL.Texto(f, "GameFontHighlight")
  f.lista:SetPoint("TOPLEFT", f.icono, "BOTTOMLEFT", 2, -8)
  f.lista:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.lista:SetSpacing(3)
  f.si = GL.CrearBoton(f, L"Sustituir", function()
    local n = Sustituir(f.datos or {})
    if n > 0 and GL.Mensaje then GL.Mensaje(L"rangos nuevos puestos en " .. n .. (n == 1 and L" botón" or L" botones") .. ".") end
    f:Hide()
  end, nil, 22, "accion")
  f.si:SetWidth(100)
  f.no = GL.CrearBoton(f, L"Ahora no", function()
    local ig = DB().rangosIgnorados or {}
    for _, h in ipairs(f.datos or {}) do ig[h.viejo .. ">" .. h.nuevo] = true end
    if GuiaAventureroDB then GuiaAventureroDB.rangosIgnorados = ig end
    f:Hide()
  end, nil, 22)
  f.no:SetWidth(90)
  f.siempre = GL.CrearBoton(f, L"Siempre solo", function()
    if GuiaAventureroDB then GuiaAventureroDB.rangosAuto = true end
    local n = Sustituir(f.datos or {})
    if GL.Mensaje then GL.Mensaje(L"desde ahora los rangos nuevos se ponen solos en tus barras (se quita en Ajustes › General)." ) end
    f:Hide()
  end, nil, 22)
  f.siempre:SetWidth(110)
  f.si:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  f.no:SetPoint("LEFT", f.si, "RIGHT", 6, 0)
  f.siempre:SetPoint("LEFT", f.no, "RIGHT", 6, 0)
  if GL.Ayuda then
    GL.Ayuda(f.no, L"No vuelve a preguntar por estos rangos. Si cambias de idea, arrastra el hechizo nuevo desde el libro.")
    GL.Ayuda(f.siempre, L"Sustituye ahora y, desde ahora, sin preguntar. Se quita en Ajustes › General.")
  end
  f:Hide()
  return f
end

local function Mostrar(lista)
  aviso = aviso or CrearAviso()
  aviso.datos = lista
  local l = {}
  for i, h in ipairs(lista) do
    if i > 8 then table.insert(l, C.GRIS .. L"y " .. (#lista - 8) .. L" más" .. C.FIN); break end
    table.insert(l, Linea(h))
  end
  aviso.lista:SetText(table.concat(l, "\n"))
  local icono
  pcall(function()
    if C_Spell and C_Spell.GetSpellTexture then icono = C_Spell.GetSpellTexture(lista[1].nuevo)
    elseif GetSpellTexture then icono = GetSpellTexture(lista[1].nuevo) end
  end)
  aviso.icono:SetTexture(icono or "Interface\\Icons\\INV_Misc_Book_09")
  aviso:SetHeight(96 + math.min(#lista, 9) * 16)
  aviso:Show()
  if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPEN) end
end

local aprendidos = {}
local base = nil   -- 9.7.4: rangos viejos que ya había en las barras al conectar
local function Revisar()
  pendiente = false
  if not Activo() then aprendidos = {}; return end
  if EnCombate() then pendiente = true; return end
  -- 9.7.4: se mira toda la barra; salen los rangos que acabas de aprender y los que no estaban al conectar
  -- (por si el juego no avisa de lo aprendido). Los rangos viejos que ya tenías al entrar no se preguntan.
  local todos = Buscar(nil)
  local lista = {}
  for _, h in ipairs(todos) do
    local clave = h.viejo .. ">" .. h.nuevo
    if aprendidos[h.nombre] or (base and not base[clave]) then table.insert(lista, h) end
    if base then base[clave] = true end
  end
  aprendidos = {}
  if #lista == 0 then return end
  if Auto() then
    local n = Sustituir(lista)
    if n > 0 and GL.Mensaje then
      local nombres = {}
      for _, h in ipairs(lista) do table.insert(nombres, h.nombre .. " " .. h.rangoNuevo) end
      GL.Mensaje(L"rangos nuevos puestos en tus barras: " .. table.concat(nombres, ", ") .. ".")
    end
  else
    Mostrar(lista)
  end
end

local programado = false
local function Programar()
  if programado then return end
  programado = true
  local function Hacer() programado = false; Revisar() end
  if C_Timer and C_Timer.After then C_Timer.After(ESPERA, Hacer) else Hacer() end
end

local ev = CreateFrame("Frame")
-- 9.7.4: los dos avisos de «hechizo aprendido» (cada cliente usa uno) y, por si ninguno llega, el cambio del libro
for _, e in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, id)
  if event == "PLAYER_REGEN_ENABLED" then
    if pendiente then Programar() end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    local function Foto()
      if base then return end
      base = {}
      for _, h in ipairs(Buscar(nil)) do base[h.viejo .. ">" .. h.nuevo] = true end
    end
    if C_Timer and C_Timer.After then C_Timer.After(5, function() pcall(Foto) end) else pcall(Foto) end
    return
  end
  if event == "SPELLS_CHANGED" then
    if base then Programar() end
    return
  end
  local nombre = id and Nombre(id)
  if nombre then aprendidos[nombre] = true; Programar() end
end)

-- /ga rangos: buscar ahora en las barras todos los rangos viejos (aunque no los acabes de aprender)
GL.comandos = GL.comandos or {}
GL.comandos["rangos"] = function()
  if EnCombate() then if GL.Mensaje then GL.Mensaje(L"en combate no se pueden cambiar las barras.") end; return end
  local lista = Buscar(nil)
  if #lista == 0 then
    if GL.Mensaje then GL.Mensaje(L"tus barras ya tienen los rangos más altos que conoces.") end
  else
    Mostrar(lista)
  end
end

GL._rangosBarras = { Buscar = Buscar, Sustituir = Sustituir, Revisar = Revisar, Aprendido = function(n) aprendidos[n] = true end }

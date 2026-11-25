-- Oro.lua (9.4): botón Oro de la barra lateral, con tres pestañas.
--  · Ahorro (la principal): el oro que tienes, el de la cuenta y lo que llevas ganado hoy, y lo que te falta para
--    Equitación y montura y para la doble especialización (los mismos precios que la tarjeta de la Guía, en Ajustes › Datos).
--  · Farmear: sitios para sacar oro según tu nivel, con Llevarme. Los bichos y sus sitios, de QuestieDB (Classic).
--  · Profesiones: qué vender con cada profesión según tu nivel de habilidad; las tuyas primero.
-- Precios y sitios orientativos de Classic: en WoW Forever pueden cambiar. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local function DB() return GuiaAventureroDB end
local function Nivel() return (UnitLevel and UnitLevel("player")) or 1 end
local function Num(v) return (GL.Seguro and GL.Seguro(v)) or v end
local function Dinero(c) return (GL.Dinero and GL.Dinero(c)) or (math.floor((c or 0) / 10000) .. " o") end

------------------------------------------------------------------------
-- Farmear: { min, max, bicho, qué sacas, m, x, y, z }
------------------------------------------------------------------------
local SITIOS = {
  { 10, 14, L"Tejespina Crines de Acero", L"Lino, grises y monedas", 1413, 55.0, 26.2, L"Los Baldíos" },
  { 12, 15, L"Trampero Defias", L"Lino y grises", 1436, 46.4, 34.6, L"Páramos de Poniente" },
  { 12, 16, L"Brigadier del Mar del Sur", L"Lino, grises y monedas", 1413, 63.8, 46.2, L"Los Baldíos" },
  { 32, 36, L"Asaltante de caminos del Sindicato", L"Lana, seda y monedas", 1416, 57.7, 68.0, L"Montañas de Alterac" },
  { 34, 37, L"Ogro Aplastacresta", L"Seda y monedas; muchos y juntos", 1416, 50.1, 43.2, L"Montañas de Alterac" },
  { 37, 40, L"Elemental de piedra inferior", L"Tierra elemental: se vende bien en la casa de subastas", 1418, 19.2, 43.1, L"Tierras Inhóspitas" },
  { 41, 44, L"Pícaro Deambulador", L"Tejido mágico y monedas", 1446, 61.8, 38.1, "Tanaris" },
  { 41, 44, L"Brujo Velasangre", L"Tejido mágico y monedas", 1434, 27.5, 81.1, L"Vega de Tuercespina" },
  { 46, 49, L"Yeti Estigmodio", L"Cuero grueso si tienes Desuello", 1444, 53.1, 31.8, "Feralas" },
  { 48, 50, L"Guerrero Muertobosque", L"Paño rúnico y reputación con los Fauces de Madera", 1448, 48.6, 91.4, L"Frondavil" },
  { 53, 56, L"Llamarada viviente", L"Fuego elemental y esencias de fuego", 1449, 50.1, 48.4, L"Cráter de Un'Goro" },
  { 54, 56, L"Demosaurio", L"Cuero de demosaurio (muy caro) si tienes Desuello", 1449, 34.6, 23.7, L"Cráter de Un'Goro" },
  { 55, 58, L"Elemental obsidiano superior", L"Tierra elemental y esencias de tierra", 1428, 49.5, 46.3, L"Las Estepas Ardientes" },
  { 55, 58, L"Ursa Nevada", L"Paño rúnico y reputación con los Fauces de Madera", 1452, 66.8, 37.8, L"Cuna del Invierno" },
  { 56, 60, L"Taumaturgo oscuro", L"Paño rúnico y monedas", 1423, 59.2, 68.0, L"Tierras de la Peste del Este" },
  { 57, 60, L"Vengador Crepuscular", L"Paño rúnico y textos crepusculares", 1451, 26.9, 43.9, "Silithus" },
}

------------------------------------------------------------------------
-- Profesiones: por id de habilidad, consejos por tramos de habilidad { desde, texto }
------------------------------------------------------------------------
local PROF = {
  { id = 186, n = "Minería", ing = "Mining", tramos = {
    { 1, L"Cobre (Dun Morogh, Durotar, Elwynn): las barras de cobre se venden a los que suben Herrería e Ingeniería." },
    { 65, L"Estaño y plata (Laderas de Trabalomas, Sierra Espolón): el estaño y la plata se venden rápido." },
    { 125, L"Hierro y oro (Tierras Altas de Arathi, Desolace): el hierro lo compran herreros e ingenieros." },
    { 175, L"Mitril y verdinita (Tierras Inhóspitas, Tanaris): el mitril se vende siempre." },
    { 245, L"Torio (Cráter de Un'Goro, Las Estepas Ardientes): torio y las piedras preciosas que salen de él." } } },
  { id = 182, n = "Herboristería", ing = "Herbalism", tramos = {
    { 1, L"Flor de paz y hojaplata: los alquimistas las compran para subir." },
    { 70, L"Raíz de tierra, Brezospina y Sangrerregia: pociones de salud y de maná." },
    { 160, L"Hierba cardenal y Flor de khadgar: piden mucho para pociones de nivel medio." },
    { 230, L"Sansam dorado, Hoja de sueño y Muérdago de montaña (Un'Goro, Frondavil): para frascos y pociones de banda." } } },
  { id = 393, n = "Desuello", ing = "Skinning", tramos = {
    { 1, L"Cuero ligero: cualquier bestia de las primeras zonas." },
    { 100, L"Cuero medio y pesado (Tierras Altas de Arathi, Los Humedales)." },
    { 200, L"Cuero grueso (Feralas, Tanaris): muy buscado por los peleteros." },
    { 250, L"Cuero basto y de demosaurio (Un'Goro, Cuna del Invierno): de lo que más dinero da." } } },
  { id = 197, n = "Sastrería", ing = "Tailoring", tramos = {
    { 1, L"Bolsas de lino y de lana: todo el mundo necesita huecos." },
    { 175, L"Bolsas de tejido mágico y piezas verdes para desencantar." },
    { 260, L"Bolsas de paño rúnico y Paño lunar (cada 4 días)." } } },
  { id = 164, n = "Herrería", ing = "Blacksmithing", tramos = {
    { 1, L"Piedras de afilar y de peso: guerreros y pícaros las gastan siempre." },
    { 200, L"Piedras de afilar densas y piezas de mitril para desencantar." },
    { 275, L"Armas y armaduras de torio por encargo; arcanita si alguien la transmuta." } } },
  { id = 171, n = "Alquimia", ing = "Alchemy", tramos = {
    { 1, L"Pociones de salud y de maná: se venden a todos los niveles." },
    { 200, L"Pociones de maná superiores y elixires de banda." },
    { 275, L"Transmutar arcanita (cada 2 días) y frascos: lo que más se paga." } } },
  { id = 333, n = "Encantamiento", ing = "Enchanting", tramos = {
    { 1, L"Vende polvos y esencias de desencantar lo verde que no uses." },
    { 150, L"Encantamientos por encargo en las ciudades: pide los materiales y cobra la mano de obra." },
    { 250, L"Fragmentos grandes y encantamientos de arma de banda: muy buscados." } } },
  { id = 202, n = "Ingeniería", ing = "Engineering", tramos = {
    { 1, L"Munición y miras para cazadores." },
    { 150, L"Dinamita y bombas para los demás jugadores." },
    { 250, L"Balas de torio, miras de precisión y Termocañones de núcleo para cazadores de banda." } } },
  { id = 165, n = "Peletería", ing = "Leatherworking", tramos = {
    { 1, L"Kits de armadura: todos los que suben los compran." },
    { 200, L"Kits de armadura gruesos y piezas para desencantar." },
    { 275, L"Piezas de demosaurio y armaduras de banda por encargo." } } },
  { id = 185, n = "Cocina", ing = "Cooking", tramos = {
    { 1, L"Comida con bonificaciones: la gente la compra para las mazmorras." },
    { 225, L"Pescado y comida de estadísticas para las bandas." } } },
  { id = 356, n = "Pesca", ing = "Fishing", tramos = {
    { 1, L"Pescado para los cocineros y pescado aceitoso para los alquimistas." },
    { 225, L"Anguilas de escama pétrea: para los frascos y las pociones de banda." } } },
}

local function MisProfesiones()
  local r = {}
  for _, h in ipairs((GL.Habilidades and GL.Habilidades()) or {}) do
    for _, p in ipairs(PROF) do
      if h.id == p.id or h.n == p.n or h.n == p.ing then r[p.id] = h.rango or 0 end
    end
  end
  return r
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------
local panel, ui = nil, { metas = {} }
local function Pestana() return DB().pestanaOro or "ahorro" end

local function FilasFarmear()
  local nv, filas = Nivel(), {}
  local cerca, resto = {}, {}
  for _, s in ipairs(SITIOS) do
    local aqui = nv >= s[1] - 2 and nv <= s[2] + 3
    table.insert(aqui and cerca or resto, s)
  end
  local function Fila(s, aqui)
    table.insert(filas, { titulo = aqui or nil, texto = s[3] .. C.GRIS .. "  (" .. s[1] .. "-" .. s[2] .. ")" .. C.FIN,
      detalle = s[4] .. " · " .. s[8], destino = { m = s[5], x = s[6], y = s[7], z = s[8], n = s[3] .. " (" .. s[8] .. ")" },
      ayudaTitulo = s[3], ayudaTexto = s[4] .. ".\n" .. s[8] .. " " .. s[6] .. ", " .. s[7] })
  end
  for _, s in ipairs(cerca) do Fila(s, true) end
  for _, s in ipairs(resto) do Fila(s, false) end
  return filas, L"Sitios para sacar oro: lo de tu nivel arriba. Vende lo gris al comerciante y las telas, el cuero y los elementales en la casa de subastas. Orientativo de Classic."
end

local function FilasProfesiones()
  local mias, filas = MisProfesiones(), {}
  local function Poner(p, rango)
    local tengo = rango ~= nil
    table.insert(filas, { titulo = true, hecha = tengo or nil,
      texto = L(p.n) .. (tengo and (C.GRIS .. L"  · tienes " .. rango .. C.FIN) or ""), ayudaTitulo = L(p.n) })
    for i, t in ipairs(p.tramos) do
      local siguiente = p.tramos[i + 1]
      local ahora = tengo and rango >= t[1] and (not siguiente or rango < siguiente[1])
      table.insert(filas, { texto = (ahora and (GL.Icono("▶") .. " ") or "") .. L"Desde " .. t[1], detalle = t[2],
        ayudaTitulo = L(p.n) .. " " .. t[1] .. "+", ayudaTexto = t[2] })
    end
  end
  for _, p in ipairs(PROF) do if mias[p.id] then Poner(p, mias[p.id]) end end
  for _, p in ipairs(PROF) do if not mias[p.id] then Poner(p, nil) end end
  return filas, L"Cómo ganar oro con cada profesión según tu habilidad; las tuyas primero, con ▶ en lo que te toca ahora. Orientativo de Classic."
end

local function RefrescarAhorro()
  local oro = Num(GetMoney and GetMoney()) or 0
  ui.oro:SetText(Dinero(oro))
  local total, n = 0, 0
  local pjs = type(GuiaAventureroCuenta) == "table" and type(GuiaAventureroCuenta.personajes) == "table" and GuiaAventureroCuenta.personajes or {}
  for _, p in pairs(pjs) do if type(p) == "table" and type(p.oro) == "number" then total, n = total + p.oro, n + 1 end end
  local ses = GL.SesionActual and GL.SesionActual()
  local lineas = {}
  if n > 1 then table.insert(lineas, L"En la cuenta (" .. n .. L" personajes): " .. C.AMARILLO .. Dinero(total) .. C.FIN) end
  if ses and ses.oro and ses.t and ses.t > 300 then
    local porHora = ses.oro / ses.t * 3600
    table.insert(lineas, L"Esta sesión: " .. (ses.oro >= 0 and C.VERDE or "|cffff7070") .. Dinero(math.abs(ses.oro)) .. C.FIN ..
      (ses.oro > 0 and (C.GRIS .. "  (" .. Dinero(porHora) .. L" por hora)" .. C.FIN) or ""))
  end
  ui.cuenta:SetText(table.concat(lineas, "\n"))
  -- metas: las mismas que la tarjeta de la Guía (Mejoras.lua)
  local metas, falta
  if GL.MetasAhorro then metas, falta = GL.MetasAhorro(true) end
  if type(metas) ~= "table" or type(falta) ~= "number" then
    metas = {}
    ui.falta:SetText(L"Metas no disponibles")
  else
    ui.falta:SetText(falta > 0 and (L"Te faltan " .. C.AMARILLO .. math.ceil(falta) .. L" de oro" .. C.FIN) or (C.VERDE .. L"Tienes lo que necesitas" .. C.FIN))
  end
  local reserva = GL.ReservaOro and GL.ReservaOro() or 0
  local disponible = math.max(0, oro - reserva)
  local consejo = { L"Presupuesto para compras automáticas: " .. Dinero(disponible) }
  if DB().reservaOro == true and DB().ahorro ~= false then
    consejo[#consejo + 1] = L"Reserva objetivo: " .. Dinero(reserva)
  else
    consejo[#consejo + 1] = L"Reserva automática de oro inactiva"
  end
  consejo[#consejo + 1] = L"Las compras manuales pueden utilizar todo tu oro."
  ui.consejo:SetText(C.GRIS .. table.concat(consejo, "\n") .. C.FIN)
  for i = 1, math.max(#metas, #ui.metas) do
    local r, m = ui.metas[i], metas[i]
    if m and not r then
      r = {}
      r.n = GL.Texto(ui.ahorro, "GameFontHighlight")
      r.barra = GL.CrearBarra(ui.ahorro, 1, 0.82, 0)
      r.barra:SetHeight(12)
      r.v = GL.Texto(ui.ahorro, "GameFontHighlightSmall", "RIGHT")
      ui.metas[i] = r
    end
    if r then
      local y = -112 - (i - 1) * 40
      r.n:ClearAllPoints(); r.n:SetPoint("TOPLEFT", ui.ahorro, "TOPLEFT", 0, y)
      r.v:ClearAllPoints(); r.v:SetPoint("TOPRIGHT", ui.ahorro, "TOPRIGHT", 0, y)
      r.barra:ClearAllPoints()
      r.barra:SetPoint("TOPLEFT", ui.ahorro, "TOPLEFT", 0, y - 16)
      r.barra:SetPoint("TOPRIGHT", ui.ahorro, "TOPRIGHT", 0, y - 16)
      GL.Mostrar(r.n, m ~= nil); GL.Mostrar(r.v, m ~= nil); GL.Mostrar(r.barra, m ~= nil)
      if m then
        r.n:SetText(m.n)
        r.barra:SetMinMaxValues(0, math.max(1, m.o)); r.barra:SetValue(m.tengo or 0)
        r.v:SetText(m.hecho and (C.VERDE .. L"ya lo tienes ✓" .. C.FIN) or ((m.tengo or 0) >= m.o and (C.VERDE .. m.o .. " o " .. GL.Icono("✓") .. C.FIN))
          or (math.floor(m.tengo or 0) .. " / " .. m.o .. " o"))
      end
    end
  end
  ui.precios:ClearAllPoints()
  ui.precios:SetPoint("TOPLEFT", ui.ahorro, "TOPLEFT", 0, -112 - #metas * 40 - 6)
  ui.consejo:ClearAllPoints()
  ui.consejo:SetPoint("TOPLEFT", ui.precios, "BOTTOMLEFT", 0, -12)
  ui.consejo:SetPoint("RIGHT", ui.ahorro, "RIGHT", 0, 0)
end

local function Refrescar()
  if not panel or not panel:IsShown() then return end
  local p = Pestana()
  ui.pest.Marcar(p)
  GL.Mostrar(ui.ahorro, p == "ahorro")
  GL.Mostrar(ui.cuerpo, p ~= "ahorro")
  if p == "ahorro" then RefrescarAhorro(); return end
  local filas, cab
  if p == "farmear" then filas, cab = FilasFarmear() else filas, cab = FilasProfesiones() end
  ui.lista:Poner(filas, C.GRIS .. cab .. C.FIN)
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  ui.titulo = GL.Texto(panel, "GameFontNormal")
  ui.titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  ui.titulo:SetText(L"Oro")
  ui.pest = GL.CrearPestanas94(panel, { { "ahorro", L"Ahorro" }, { "farmear", L"Farmear" }, { "profesiones", L"Profesiones" } }, function(id)
    DB().pestanaOro = id; Refrescar()
  end, 104)
  ui.pest[1]:ClearAllPoints()
  ui.pest[1]:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22)
  -- Ahorro
  local a = CreateFrame("Frame", nil, panel)
  a:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -52)
  a:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  ui.ahorro = a
  local k = GL.Texto(a, "GameFontHighlightSmall")
  k:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0)
  k:SetText(C.GRIS .. L"TIENES AHORA" .. C.FIN)
  ui.oro = GL.Texto(a, "GameFontNormalLarge")
  ui.oro:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -16)
  ui.cuenta = GL.Texto(a, "GameFontHighlightSmall")
  ui.cuenta:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -42)
  ui.cuenta:SetPoint("RIGHT", a, "RIGHT", 0, 0)
  if ui.cuenta.SetSpacing then ui.cuenta:SetSpacing(2) end
  ui.metasTitulo = GL.Texto(a, "GameFontHighlightSmall")
  ui.metasTitulo:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -90)
  ui.metasTitulo:SetText(C.GRIS .. L"TUS METAS DE AHORRO" .. C.FIN)
  ui.metasTitulo:SetPoint("RIGHT", a, "RIGHT", 0, 0); if ui.metasTitulo.SetWordWrap then ui.metasTitulo:SetWordWrap(false) end; ui.metasTitulo:SetJustifyH("LEFT")
  ui.falta = GL.Texto(a, "GameFontHighlightSmall", "RIGHT")
  ui.falta:SetPoint("TOPRIGHT", a, "TOPRIGHT", 0, -16)
  ui.precios = GL.CrearBoton(a, L"Cambiar precios", function()
    DB().pestanaAjustes = "datos"
    if GL.AbrirModo then GL.AbrirModo("opciones") end
  end, nil, 18)
  ui.precios:SetWidth(120)
  GL.Ayuda(ui.precios, L"Cambiar precios", L"Los precios de Equitación, montura y doble especialización están en Ajustes › Datos.")
  ui.consejo = GL.Texto(a, "GameFontHighlightSmall")
  if ui.consejo.SetSpacing then ui.consejo:SetSpacing(2) end
  ui.consejo:SetText(C.GRIS .. L"Consejo: vende lo gris y no compres en la subasta." .. C.FIN)
  -- Farmear y Profesiones
  ui.cuerpo = CreateFrame("Frame", nil, panel)
  ui.cuerpo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -52)
  ui.cuerpo:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  ui.lista = GL.CrearLista(ui.cuerpo)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt)
    if not panel:IsShown() then return end
    espera = espera + dt
    if espera >= 2 then espera = 0; if Pestana() == "ahorro" then RefrescarAhorro() end end
  end)
  GL.modos.oro = { panel = panel, refrescar = Refrescar }
end

GL.perezosos = GL.perezosos or {}
GL.perezosos.oro = CrearPanel
GL.comandos = GL.comandos or {}
GL.comandos["oro"] = function() if GL.AbrirModo then GL.frame:Show(); GL.AbrirModo("oro") end end

-- Botón de la barra lateral, tras los de Mazmorras y bandas, Reputación... (antes que Mascotas y Grupo)
table.insert(GL.alIniciar, 1, function()
  local ui0 = GL.ui
  if not (ui0 and GL.BotonLateral and GL.frame) then return end
  if GL.LADO then GL.LADO.oro = true end
  local b = GL.BotonLateral("oro", L"Oro", "Interface\\Icons\\INV_Misc_Coin_01", L"Tu oro, el ahorro para la montura y la doble especialización, dónde farmear y qué vender con tus profesiones.", function()
    if DB().modo == "oro" then GL.AbrirModo(DB().modoGuia or "guia") else GL.AbrirModo("oro") end
  end)
  b:SetPoint("TOPLEFT", GL.frame, "TOPLEFT", (GL.RAIL - 36) / 2, ui0.yLateral or -300)
  ui0.yLateral = (ui0.yLateral or -300) - 34
  table.insert(ui0.lado, b)
  if DB().cargarAlAbrir == false then CrearPanel() end
end)

GL._oro = { Farmear = FilasFarmear, Profesiones = FilasProfesiones, SITIOS = SITIOS, PROF = PROF }   -- para las pruebas

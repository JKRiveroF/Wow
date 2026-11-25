-- Mascotas.lua (9.3): botón Mascotas de la barra lateral. Solo lo ven los cazadores y los brujos.
--  · Cazador: Familias (las 19 familias (9.5: Zorro y Ave rapaz de Forever) y sus bestias por nivel), Mis mascotas (la activa y las del establo) y
--    Establos, con dos subpestañas: Mascotas guardadas y Maestros de establos (con los instructores de mascotas
--    de tu facción, con Llevarme).
--  · Brujo: Demonios (cada demonio, su misión y sus habilidades), Mis demonios (el activo y los que sabes invocar)
--    e Instructores (instructores de demonios de tu facción, con Llevarme).
-- Datos de bestias y PNJ en Bestias.lua. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local COLUMNAS, ALTO_CELDA, LADO_ICONO, ALTO_FICHA, ALTO_FILA = 4, 66, 40, 132, 30
local ICONO_SI, ICONO_NO = "Interface\\RaidFrame\\ReadyCheck-Ready", "Interface\\RaidFrame\\ReadyCheck-NotReady"
local RANGO = { [1] = L"élite", [2] = L"raro élite", [4] = "raro" }

local function Clase() return UnitClass and select(2, UnitClass("player")) end
local function EsCazador() return Clase() == "HUNTER" end
local function EsBrujo() return Clase() == "WARLOCK" end
local function Lado() return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A" end
local function NivelJugador() return (UnitLevel and UnitLevel("player")) or 1 end
local function DB() if type(GuiaAventureroDB) ~= "table" then return {} end return GuiaAventureroDB end

local PESTANAS = {
  HUNTER = { { "familias", L"Familias" }, { "mias", L"Mis mascotas" }, { "establos", L"Establos" }, { "rangos", L"Rangos" } },   -- 9.4: Rangos abre su ventana
  WARLOCK = { { "demonios", L"Demonios" }, { "mias", L"Mis demonios" }, { "instructores", L"Instructores" } },
}

------------------------------------------------------------------------
-- Brujo: demonios. En «como», la misión por raza (Gnome, Scourge) o, si no, por facción (A, H).
-- Misiones de QuestieDB y cMaNGOS (Classic); habilidades y nombres en español, traducción propia.
------------------------------------------------------------------------
GL.demonios = {
  { n = L"Diablillo", ing = "Imp", nivel = 1, hechizo = 688, icono = "Interface\\Icons\\Spell_Shadow_SummonImp",
    rol = L"Daño a distancia y más aguante para el grupo",
    hab = { L"Descarga de fuego: daño de fuego a distancia", L"Pacto de sangre: más aguante para el grupo",
      L"Escudo de fuego: daña a quien golpea al aliado", L"Cambio de fase: no recibe daño pero tampoco ataca" },
    como = {
      Gnome = { L"Novato", "Alamar Grimm", "Dun Morogh", 1426, 28.7, 66.1 },
      Scourge = { L"Descubrir el misterio", L"Venya Martmani", L"Claros de Tirisfal", 1420, 31.0, 66.4 },
      A = { L"El libro robado", "Drusilla La Salle", L"Bosque de Elwynn", 1429, 49.9, 42.7 },
      H = { L"Familiares viles", "Ruzan", "Durotar", 1411, 42.6, 69.0 },
    } },
  { n = L"Abisario", ing = "Voidwalker", nivel = 10, hechizo = 697, icono = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
    rol = L"Tanque: aguanta los golpes por ti",
    hab = { L"Tormento: provoca al enemigo", L"Sacrificio: escudo para ti a costa de su vida",
      L"Consumir sombras: se cura fuera de combate", L"Sufrimiento: provoca a los enemigos cercanos" },
    como = {
      A = { L"La invocación de Gakin, Surena Caledon y El vínculo", L"Gakin el Presotenebra", L"Ciudad de Ventormenta", 1453, 25.3, 78.6 },
      Scourge = { L"Las invocaciones de Halgar, Criatura abisal y El vínculo", "Carendin Halgar", L"Entrañas", 1458, 85.1, 26.0 },
      H = { L"Las invocaciones de Gan'rul, Criatura abisal y El vínculo", L"Ojo sangriento de Gan'rul", "Orgrimmar", 1454, 48.3, 45.3 },
    } },
  { n = L"Súcubo", ing = "Succubus", nivel = 20, hechizo = 712, icono = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
    rol = L"Daño cuerpo a cuerpo y control (seducción)",
    hab = { L"Latigazo de dolor: daño de sombras", L"Beso tranquilizador: baja la amenaza",
      L"Seducción: deja quieto a un humanoide", L"Invisibilidad inferior: se hace invisible" },
    como = {
      A = { L"Devoradora de almas, Duramen (Takar el Vidente, Los Baldíos 49.3 57.1) y El vínculo", L"Gakin el Presotenebra", L"Ciudad de Ventormenta", 1453, 25.3, 78.6 },
      Scourge = { L"Devoradora de almas, Corazones puros (Godrick Farsan) y El vínculo", "Carendin Halgar", L"Entrañas", 1458, 85.1, 26.0 },
      H = { L"Devoradora de almas, Cazul el ciego, Noticias de Dogran, Poción de Ken'zigla, El cautiverio de Dogran, Un regalo de amor y El vínculo", L"Ojo sangriento de Gan'rul", "Orgrimmar", 1454, 48.3, 45.3 },
    } },
  { n = L"Manáfago", ing = "Felhunter", nivel = 30, hechizo = 691, icono = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
    rol = L"Contra lanzadores de hechizos",
    hab = { L"Devorar magia: quita magia a enemigos o aliados", L"Bloqueo de hechizo: corta un hechizo",
      L"Sangre corrupta: daña a quien lo golpea", L"Paranoia: el grupo ve a los enemigos en sigilo" },
    como = {
      A = { L"El Libro del Conciliábulo (Krom Brazorrecio, Forjaz 74.2 9.4) y El vínculo", "Strahad Farsan", L"Los Baldíos (Trinquete)", 1413, 62.6, 35.5 },
      H = { L"El Libro del Conciliábulo (Jorah Annison, Entrañas 75.9 37.9) y El vínculo", "Strahad Farsan", L"Los Baldíos (Trinquete)", 1413, 62.6, 35.5 },
    } },
  { n = "Infernal", ing = "Infernal", nivel = 50, hechizo = 1122, icono = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
    rol = L"Cae del cielo y aturde; luego hay que esclavizarlo para que no se vuelva contra ti",
    hab = { L"Inmolación: daño de fuego a su alrededor" },
    entrenador = L"Hechizo Infernal (Inferno) del instructor de brujos. Gasta una Piedra infernal (vendedor de componentes)." },
  { n = L"Guardia apocalíptico", ing = "Doomguard", nivel = 60, hechizo = 18540, icono = "Interface\\Icons\\Spell_Shadow_AntiMagicShell",
    rol = L"Demonio de élite; hay que esclavizarlo",
    hab = { L"Golpes cuerpo a cuerpo muy fuertes" },
    entrenador = L"Ritual de fatalidad del instructor de brujos. Hacen falta 5 jugadores y una Figurilla demoníaca; puede matar a uno del grupo." },
}

local function Raza() return UnitRace and select(2, UnitRace("player")) end
local function ComoDemonio(d)
  if not d.como then return nil end
  return d.como[Raza() or ""] or d.como[Lado()]
end

------------------------------------------------------------------------
-- Cazador: familias y bestias
------------------------------------------------------------------------
local porFamilia, familiaDe = nil, {}
local function Bestias()
  if porFamilia then return porFamilia end
  porFamilia = {}
  local B = GL.bestias or {}
  for _, f in ipairs(B.familias or {}) do porFamilia[f.f] = {}; familiaDe[f.f] = f end
  for _, b in ipairs(B.lista or {}) do if porFamilia[b.f] then table.insert(porFamilia[b.f], b) end end
  for _, f in ipairs(B.familias or {}) do f.cuantas = #porFamilia[f.f] end
  return porFamilia
end
local function FamiliaMascota()
  if not UnitCreatureFamily or not (UnitExists and UnitExists("pet")) then return nil end
  local ok, n = pcall(UnitCreatureFamily, "pet")
  return ok and n or nil
end

-- Bestias que tiene el cazador. El GUID de la mascota lleva el id de la bestia domesticada (Pet-0-...-<npc>-...):
-- se apunta cada vez que sale. Del establo el juego solo da nombre y familia, y solo con el establo abierto:
-- se guardan entonces. Una bestia apuntada cuenta como tuya si es la de ahora o si su nombre está en el establo.
local function Domadas() local db = DB(); db.domadas = db.domadas or {}; return db.domadas end
local function NpcMascota()
  if not (UnitExists and UnitExists("pet")) or not UnitGUID then return nil end
  local guid = UnitGUID("pet")
  if type(guid) ~= "string" or not strsplit then return nil end
  local t, _, _, _, _, id = strsplit("-", guid)
  if t ~= "Pet" then return nil end
  return tonumber(id)
end
local function ApuntarMascota()
  if not EsCazador() then return end
  local id = NpcMascota()
  if id then Domadas()[id] = (UnitName and UnitName("pet")) or true end
end
local function ApuntarEstablo()
  if not EsCazador() or not GetStablePetInfo then return end
  local est = {}
  local slots = (GetNumStableSlots and GetNumStableSlots()) or 2
  for i = 1, math.max(2, slots) do
    local ok, icono, nombre, nivel, familia = pcall(GetStablePetInfo, i)
    if ok and nombre then est[#est + 1] = { n = nombre, f = familia, nv = nivel, icono = icono } end
  end
  DB().establo = est
  DB().huecosEstablo = slots
end
local function EnEstablo(nombre)
  for _, p in ipairs(DB().establo or {}) do if p.n == nombre then return true end end
  return false
end
local function LaTengo(b)
  if NpcMascota() == b.npc then return true end
  local nombre = Domadas()[b.npc]
  return type(nombre) == "string" and EnEstablo(nombre)
end
local function EsRara(e) return e.npc ~= nil and (e.r == 2 or e.r == 4) end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------
local panel, ui = nil, { celdas = {}, pest = {}, filas = {} }
local pest, fam, sel, desde = nil, nil, nil, 0
local subEst = "guardadas"   -- 9.3: Establos tiene dos subpestañas: guardadas y maestros
local SUB_ESTABLO = { { "guardadas", L"Mascotas guardadas" }, { "maestros", L"Maestros de establos" } }
local function ArribaLista() return 54 + ((pest == "establos") and 26 or 0) end

local function Pestanas() return PESTANAS[Clase() or ""] or PESTANAS.HUNTER end
local function Rejilla() return pest == "familias" or pest == "demonios" end

local function Icono(e)
  if e.icono then return e.icono end
  if e.npc and e.f then Bestias(); local f = familiaDe[e.f]; if f and f.icono then return f.icono end end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function Habilidades(f, larga)
  local B, l = GL.bestias or {}, {}
  for _, h in ipairs(f.hab or {}) do
    local t = (B.habilidades and B.habilidades[h]) or h
    table.insert(l, larga and ("  · " .. t) or (t:match("^([^:]+)") or t))
  end
  return table.concat(l, larga and "\n" or ", ")
end

local function ListaRejilla()
  if pest == "demonios" then return GL.demonios end
  local pf = Bestias()
  if fam and pf[fam] then return pf[fam] end
  fam = nil
  return (GL.bestias and GL.bestias.familias) or {}
end

local function Vivo(e)
  if pest == "demonios" then return true end
  if e.hab and not e.npc then return true end   -- familias, siempre en color
  return (e.min or 1) <= NivelJugador()
end
local function Marca(e)   -- true tic, false X, nil nada
  if pest == "demonios" then return (IsSpellKnown and e.hechizo and IsSpellKnown(e.hechizo)) and true or false end
  if pest == "familias" and fam and e.npc and EsCazador() then return LaTengo(e) end
  return nil
end

local function TextoFicha(e)
  local l = {}
  if pest == "demonios" then
    local sabe = Marca(e)
    table.insert(l, C.GRIS .. L"demonio · desde el nivel " .. e.nivel .. " · " .. (sabe and (C.VERDE .. L"ya sabes invocarlo" .. C.FIN .. C.GRIS) or L"aún no sabes invocarlo") .. C.FIN)
    table.insert(l, C.AMARILLO .. L"Para qué: " .. C.FIN .. e.rol)
    local c = ComoDemonio(e)
    if c then
      table.insert(l, C.AMARILLO .. L"Misión: " .. C.FIN .. c[1])
      table.insert(l, C.AMARILLO .. L"Empieza con: " .. C.FIN .. c[2] .. " · " .. c[3] .. " " .. string.format("%.1f, %.1f", c[5], c[6]))
    elseif e.entrenador then
      table.insert(l, C.AMARILLO .. L"Cómo: " .. C.FIN .. e.entrenador)
    end
    table.insert(l, C.AMARILLO .. L"Habilidades:" .. C.FIN)
    for _, h in ipairs(e.hab or {}) do table.insert(l, "  · " .. h) end
    table.insert(l, C.GRIS .. L"Los rangos nuevos de sus habilidades se compran como grimorios al instructor de demonios." .. C.FIN)
    return table.concat(l, "\n")
  end
  local B = GL.bestias or {}
  if e.hab and not e.npc then
    table.insert(l, C.GRIS .. L"familia · " .. (e.cuantas or 0) .. L" bestias" .. ((FamiliaMascota() == e.n or FamiliaMascota() == e.ing) and (" · " .. C.VERDE .. L"tu mascota es de esta familia" .. C.FIN .. C.GRIS) or "") .. C.FIN)
    table.insert(l, C.AMARILLO .. L"Habilidades:" .. C.FIN .. "\n" .. Habilidades(e, true))
    table.insert(l, C.AMARILLO .. L"Todas: " .. C.FIN .. (B.comun or ""))
    table.insert(l, C.AMARILLO .. L"Dieta: " .. C.FIN .. (e.dieta or "?"))
    table.insert(l, C.GRIS .. L"Para aprender un rango nuevo, domestica una bestia que lo tenga y úsala hasta aprenderlo; luego enséñaselo a tu mascota en Entrenar bestia." .. C.FIN)
    return table.concat(l, "\n")
  end
  Bestias()
  local f = familiaDe[e.f] or {}
  local puedo = (e.min or 1) <= NivelJugador()
  table.insert(l, C.GRIS .. string.lower(f.n or "bestia") .. L" · nivel " .. (e.nv or "?") .. (RANGO[e.r] and (" · " .. RANGO[e.r]) or "") .. " · " ..
    (puedo and (C.VERDE .. L"ya puedes domesticarla" .. C.FIN .. C.GRIS) or (L"desde el nivel " .. (e.min or "?"))) .. C.FIN)
  if EsCazador() then table.insert(l, LaTengo(e) and (C.VERDE .. L"La tienes domesticada" .. C.FIN) or (C.GRIS .. L"No la tienes domesticada" .. C.FIN)) end
  if EsRara(e) then table.insert(l, C.GRIS .. L"Dragón plateado: bestia rara" .. C.FIN) end
  table.insert(l, C.AMARILLO .. L"Dónde: " .. C.FIN .. (e.zona or "?") .. (e.otras and (C.GRIS .. L" (también en " .. e.otras .. ")" .. C.FIN) or ""))
  if e.x and e.y then table.insert(l, C.AMARILLO .. L"Coordenadas: " .. C.FIN .. string.format("%.1f, %.1f", e.x, e.y)) end
  if e.v then table.insert(l, C.AMARILLO .. L"Velocidad de ataque: " .. C.FIN .. string.format("%.1f s", e.v) .. (e.v < 2 and (C.VERDE .. L" (rápida)" .. C.FIN) or "")) end
  table.insert(l, C.AMARILLO .. L"Habilidades: " .. C.FIN .. Habilidades(f, false))
  table.insert(l, C.AMARILLO .. L"Dieta: " .. C.FIN .. (f.dieta or "?"))
  table.insert(l, C.GRIS .. L"Fuente: base de datos de Classic (cMaNGOS y QuestieDB)" .. C.FIN)
  return table.concat(l, "\n")
end

-- Destino de Llevarme para la ficha
local function DestinoFicha(e)
  if pest == "demonios" then
    local c = ComoDemonio(e)
    if c then return { m = c[4], x = c[5], y = c[6], n = c[2] } end
    return nil
  end
  if e.m and e.x then return { m = e.m, x = e.x, y = e.y, n = e.n } end
  return nil
end

------------------------------------------------------------------------
-- Pestañas de lista: Mis mascotas / Mis demonios / Establos / Instructores
------------------------------------------------------------------------
local FELICIDAD = { L"Descontenta", L"Satisfecha", L"Contenta" }
local function HabilidadesMascota()
  local l = {}
  if not GetPetActionInfo then return l end
  for i = 1, 10 do
    local ok, nombre, _, esFija = pcall(GetPetActionInfo, i)   -- esFija: Atacar, Seguir, Quieto... (no son habilidades)
    if ok and nombre and not esFija then table.insert(l, nombre) end
  end
  return l
end

local function Cabecera()
  local l = {}
  local hay = UnitExists and UnitExists("pet")
  if pest == "mias" and EsCazador() then
    if hay then
      local nv = UnitLevel and UnitLevel("pet")
      table.insert(l, C.AMARILLO .. L"Activa: " .. C.FIN .. ((UnitName and UnitName("pet")) or "?") .. C.GRIS .. " · " .. (FamiliaMascota() or "?") .. (nv and (L" · nivel " .. nv) or "") .. C.FIN)
      if GetPetHappiness then
        local ok, h = pcall(GetPetHappiness)
        if ok and h then table.insert(l, C.AMARILLO .. L"Felicidad: " .. C.FIN .. (FELICIDAD[h] or h) .. (h < 3 and (C.GRIS .. L" (dale de comer para que haga más daño)" .. C.FIN) or "")) end
      end
      if GetPetLoyalty then local ok, t = pcall(GetPetLoyalty); if ok and t then table.insert(l, C.AMARILLO .. L"Lealtad: " .. C.FIN .. t) end end
      if GetPetTrainingPoints then
        local ok, total, gastados = pcall(GetPetTrainingPoints)
        if ok and total then table.insert(l, C.AMARILLO .. L"Puntos de entrenamiento libres: " .. C.FIN .. (total - (gastados or 0))) end
      end
      if GetPetFoodTypes then
        local ok, a, b, c, d, e2, f = pcall(GetPetFoodTypes)
        local comida = {}
        for _, x in ipairs({ a, b, c, d, e2, f }) do if x then table.insert(comida, x) end end
        if ok and #comida > 0 then table.insert(l, C.AMARILLO .. L"Come: " .. C.FIN .. table.concat(comida, ", ")) end
      end
      local hab = HabilidadesMascota()
      if #hab > 0 then table.insert(l, C.AMARILLO .. L"Sabe: " .. C.FIN .. table.concat(hab, ", ")) end
    else
      table.insert(l, C.GRIS .. L"No tienes ninguna mascota fuera." .. C.FIN)
    end
    table.insert(l, C.GRIS .. L"Puedes domesticar bestias hasta tu nivel (" .. NivelJugador() .. L"). Tus mascotas:" .. C.FIN)
  elseif pest == "mias" then
    if hay then
      table.insert(l, C.AMARILLO .. L"Activo: " .. C.FIN .. ((UnitName and UnitName("pet")) or "?") .. C.GRIS .. " · " .. (FamiliaMascota() or "?") .. C.FIN)
      local hab = HabilidadesMascota()
      if #hab > 0 then table.insert(l, C.AMARILLO .. L"Sabe: " .. C.FIN .. table.concat(hab, ", ")) end
    else
      table.insert(l, C.GRIS .. L"No tienes ningún demonio fuera." .. C.FIN)
    end
    local frag = GetItemCount and GetItemCount(6265) or 0
    table.insert(l, C.AMARILLO .. L"Fragmentos de alma: " .. C.FIN .. (frag or 0) .. C.GRIS .. L" (el Abisario y los siguientes gastan uno al invocarlos)" .. C.FIN)
    table.insert(l, C.GRIS .. L"Demonios que sabes invocar:" .. C.FIN)
  elseif pest == "establos" and subEst == "guardadas" then
    local huecos = DB().huecosEstablo
    local n = #(DB().establo or {})
    table.insert(l, C.AMARILLO .. L"Establo: " .. C.FIN .. (huecos and (n .. L" de " .. huecos .. L" huecos ocupados") or L"abre el establo una vez para verlo") .. C.GRIS .. L" (hasta 2 huecos en Classic)" .. C.FIN)
    table.insert(l, C.GRIS .. L"Se actualiza cada vez que abres el establo con un maestro de establos." .. C.FIN)
  elseif pest == "establos" then
    table.insert(l, C.GRIS .. L"Maestros de establos de tu facción (clic: Llevarme). Primero los de tu zona:" .. C.FIN)
  elseif pest == "instructores" then
    table.insert(l, C.GRIS .. L"Instructores de demonios de tu facción: venden los grimorios con los rangos nuevos de las habilidades de tus demonios (clic: Llevarme)." .. C.FIN)
  end
  return table.concat(l, "\n")
end

local function MapaActual()
  if C_Map and C_Map.GetBestMapForUnit then local ok, m = pcall(C_Map.GetBestMapForUnit, "player"); if ok then return m end end
  return nil
end
local function PNJDeMiLado(lista)
  local lado, aqui, res = Lado(), MapaActual(), {}
  for _, p in ipairs(lista or {}) do if not p.lado or p.lado == lado then table.insert(res, p) end end
  table.sort(res, function(a, b)
    local ea, eb = a.m == aqui, b.m == aqui
    if ea ~= eb then return ea end
    if a.zona ~= b.zona then return a.zona < b.zona end
    return a.n < b.n
  end)
  return res
end

local function FilaPNJ(p, icono)
  return { t = p.n, d = p.zona .. " · " .. string.format("%.1f, %.1f", p.x, p.y), icono = icono, destino = p }
end

-- Filas: { t = texto, d = detalle, icono, marca (true/false/nil), destino }
local function Filas()
  local r = {}
  if pest == "mias" and EsCazador() then
    local actual = UnitExists and UnitExists("pet") and UnitName and UnitName("pet")
    if actual then table.insert(r, { t = actual, d = C.VERDE .. "activa" .. C.FIN .. " · " .. (FamiliaMascota() or ""), marca = true, icono = (GetPetIcon and GetPetIcon()) }) end
    for _, p in ipairs(DB().establo or {}) do
      if p.n ~= actual then table.insert(r, { t = p.n, d = L"en el establo · " .. (p.f or "?") .. (p.nv and (L" · nivel " .. p.nv) or ""), marca = true, icono = p.icono }) end
    end
    if #r == 0 then table.insert(r, { t = C.GRIS .. L"Ninguna todavía" .. C.FIN, d = L"Domestica una bestia (pestaña Familias) o abre el establo para apuntar las tuyas." }) end
  elseif pest == "mias" then
    for _, d in ipairs(GL.demonios) do
      local sabe = IsSpellKnown and IsSpellKnown(d.hechizo)
      table.insert(r, { t = d.n, d = sabe and (C.VERDE .. L"lo sabes invocar" .. C.FIN) or (L"desde el nivel " .. d.nivel), icono = d.icono, marca = sabe and true or false })
    end
  elseif pest == "establos" and subEst == "guardadas" then
    for _, p in ipairs(DB().establo or {}) do
      table.insert(r, { t = p.n, d = (p.f or "?") .. (p.nv and (L" · nivel " .. p.nv) or ""), icono = p.icono, marca = true })
    end
    local huecos = DB().huecosEstablo or 0
    for _ = #r + 1, huecos do table.insert(r, { t = C.GRIS .. L"Hueco libre" .. C.FIN, d = "" }) end
    if #r == 0 then table.insert(r, { t = C.GRIS .. L"Nada guardado todavía" .. C.FIN, d = L"o aún no has abierto el establo con esta versión" }) end
  elseif pest == "establos" then
    for _, p in ipairs(PNJDeMiLado(GL.bestias and GL.bestias.establos)) do
      table.insert(r, FilaPNJ(p, "Interface\\Icons\\Ability_Hunter_BeastTaming"))
    end
    table.insert(r, { t = C.AMARILLO .. L"Instructores de mascotas" .. C.FIN, d = L"enseñan Gruñido, resistencias y los rangos de las habilidades comunes" })
    for _, p in ipairs(PNJDeMiLado(GL.bestias and GL.bestias.instructores)) do
      table.insert(r, FilaPNJ(p, "Interface\\Icons\\Ability_Hunter_BeastCall"))
    end
  elseif pest == "instructores" then
    for _, p in ipairs(PNJDeMiLado(GL.bestias and GL.bestias.demonios)) do
      table.insert(r, FilaPNJ(p, "Interface\\Icons\\INV_Misc_Book_06"))
    end
  end
  return r
end

------------------------------------------------------------------------
-- Refrescar
------------------------------------------------------------------------
local function PonerMarca(t, m)
  if m == nil then t:Hide(); return end
  t:SetTexture(m and ICONO_SI or ICONO_NO)
  t:Show()
end

local function RefrescarRejilla()
  local lista = ListaRejilla()
  local valida = false
  for i = 1, #lista do if lista[i] == sel then valida = true end end
  if not valida then sel = nil end
  ui.altoFicha = ALTO_FICHA
  local ficha = sel or (pest == "familias" and fam and familiaDe[fam]) or nil
  if ficha then
    ui.fichaTitulo:SetText(string.upper(ficha.n or "?") .. ((ficha.ing and ficha.ing ~= ficha.n) and (C.GRIS .. "  (" .. ficha.ing .. ")" .. C.FIN) or ""))
    ui.fichaTexto:SetText(TextoFicha(ficha))
    local destino = DestinoFicha(ficha)
    ui.destino = destino
    GL.Mostrar(ui.llevar, destino ~= nil)
    ui.altoFicha = math.max(ALTO_FICHA, math.ceil(24 + (ui.fichaTexto:GetStringHeight() or 0) + 8 + (destino and 28 or 0)))
    ui.ficha:SetHeight(ui.altoFicha)
    ui.ficha:Show()
  else
    ui.ficha:Hide()
  end
  local alto = (panel:GetHeight() or 400) - 54 - (ficha and ui.altoFicha or 0) - 8
  local filas = math.max(1, math.floor(alto / ALTO_CELDA))
  local total = math.ceil(#lista / COLUMNAS)
  desde = math.max(0, math.min(desde, total - filas))
  local ancho = (panel:GetWidth() or 400) / COLUMNAS
  local n = 0
  for f = 0, filas - 1 do
    for c = 0, COLUMNAS - 1 do
      local e = lista[(desde + f) * COLUMNAS + c + 1]
      if e then
        n = n + 1
        local celda = ui.celdas[n]
        if not celda then celda = ui.CrearCelda(); ui.celdas[n] = celda end
        celda.e = e
        celda:SetWidth(ancho - 4)
        celda:ClearAllPoints()
        celda:SetPoint("TOPLEFT", panel, "TOPLEFT", c * ancho + 2, -54 - f * ALTO_CELDA)
        celda.icono:SetTexture(Icono(e))
        local vivo = Vivo(e)
        if celda.icono.SetDesaturated then celda.icono:SetDesaturated(not vivo) end
        celda.icono:SetVertexColor(vivo and 1 or 0.6, vivo and 1 or 0.6, vivo and 1 or 0.6)
        if GL.Caja then GL.Caja(celda.marco, { 0, 0, 0, 0 }, (sel == e and ((GL.COLOR and GL.COLOR.acento) or { 1, 0.82, 0, 1 }))   -- 9.3: la seleccionada, con el color del tema
           or (vivo and { 0.25, 0.85, 0.35, 0.9 }) or { 0.45, 0.45, 0.45, 0.8 }) end
        local raro = EsRara(e)
        GL.Mostrar(celda.dragon, raro)
        PonerMarca(celda.marca, Marca(e))
        local extra = (e.npc and (" · " .. (e.nv or ""))) or ((e.hab and not e.nivel) and (" (" .. (e.cuantas or 0) .. ")")) or (e.nivel and (" · " .. e.nivel)) or ""
        celda.nombre:SetText((vivo and "" or C.GRIS) .. (e.n or "?") .. extra .. (vivo and "" or C.FIN))
        celda:Show()
      end
    end
  end
  for i = n + 1, #ui.celdas do ui.celdas[i]:Hide() end
  if pest == "familias" and fam then
    local puedo = 0
    for i = 1, #lista do if Vivo(lista[i]) then puedo = puedo + 1 end end
    ui.titulo:SetText(L"Mascotas" .. C.GRIS .. "  · " .. ((familiaDe[fam] and familiaDe[fam].n) or "") .. ": " .. puedo .. L" de " .. #lista .. L" a tu nivel" .. C.FIN)
  elseif pest == "familias" then
    ui.titulo:SetText(L"Mascotas" .. C.GRIS .. "  · " .. #lista .. L" familias de bestias" .. C.FIN)
  else
    local sabe = 0
    for _, d in ipairs(lista) do if Marca(d) then sabe = sabe + 1 end end
    ui.titulo:SetText(L"Mascotas" .. C.GRIS .. L"  · sabes invocar " .. sabe .. L" de " .. #lista .. L" demonios" .. C.FIN)
  end
  ui.pie:ClearAllPoints()
  ui.pie:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, (ficha and ui.altoFicha or 0) + 8)
  ui.pie:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  ui.pie:SetText(total > filas and (C.GRIS .. L"Filas " .. (desde + 1) .. "-" .. math.min(total, desde + filas) .. L" de " .. total .. L" (rueda del ratón)" .. C.FIN) or "")
end

local function RefrescarLista()
  ui.ficha:Hide()
  ui.cab:SetText(Cabecera())
  local altoCab = (ui.cab:GetStringHeight() or 0) + 8
  local filas = Filas()
  ui.cab:ClearAllPoints()
  ui.cab:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -ArribaLista())
  ui.cab:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  local caben = math.max(1, math.floor(((panel:GetHeight() or 400) - ArribaLista() - altoCab - 20) / ALTO_FILA))
  desde = math.max(0, math.min(desde, #filas - caben))
  local n = 0
  for i = 1, caben do
    local d = filas[desde + i]
    if d then
      n = n + 1
      local f = ui.filas[n]
      if not f then f = ui.CrearFila(); ui.filas[n] = f end
      f.d = d
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -ArribaLista() - altoCab - (i - 1) * ALTO_FILA)
      f:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
      f.icono:SetTexture(d.icono)
      GL.Mostrar(f.icono, d.icono ~= nil)
      PonerMarca(f.marca, d.marca)
      f.texto:SetText(d.t or "")
      f.detalle:SetText(C.GRIS .. (d.d or "") .. C.FIN .. (d.destino and (C.AMARILLO .. L"  · Llevarme" .. C.FIN) or ""))
      f:Show()
    end
  end
  for i = n + 1, #ui.filas do ui.filas[i]:Hide() end
  local titulos = { mias = EsCazador() and L"tus mascotas" or L"tus demonios", establos = "establos", instructores = L"instructores de demonios" }
  ui.titulo:SetText(L"Mascotas" .. C.GRIS .. "  · " .. (titulos[pest] or "") .. C.FIN)
  ui.pie:ClearAllPoints()
  ui.pie:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 4)
  ui.pie:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  ui.pie:SetText(#filas > caben and (C.GRIS .. (desde + 1) .. "-" .. math.min(#filas, desde + caben) .. L" de " .. #filas .. L" (rueda del ratón)" .. C.FIN) or "")
end

local function Refrescar()
  if not panel or not panel:IsShown() then return end
  local tabs = Pestanas()
  local ok = false
  for _, t in ipairs(tabs) do if t[1] == pest then ok = true end end
  if not ok then pest = tabs[1][1] end
  for i = 1, #ui.pest do ui.pest[i]:SetActivo(ui.pest[i].clave == pest) end
  GL.Mostrar(ui.volver, pest == "familias" and fam ~= nil)
  for i = 1, #ui.subs do GL.Mostrar(ui.subs[i], pest == "establos"); ui.subs[i]:SetActivo(ui.subs[i].clave == subEst) end
  local rejilla = Rejilla()
  GL.Mostrar(ui.cab, not rejilla)
  if rejilla then
    for i = 1, #ui.filas do ui.filas[i]:Hide() end
    RefrescarRejilla()
  else
    for i = 1, #ui.celdas do ui.celdas[i]:Hide() end
    RefrescarLista()
  end
end

------------------------------------------------------------------------
-- Crear
------------------------------------------------------------------------
local function CrearCelda()
  local b = CreateFrame("Button", nil, panel)
  b:SetHeight(ALTO_CELDA - 4)
  b.marco = CreateFrame("Frame", nil, b, PLANTILLA)
  b.marco:SetWidth(LADO_ICONO + 4); b.marco:SetHeight(LADO_ICONO + 4)
  b.marco:SetPoint("TOP", b, "TOP", 0, 0)
  -- 9.3: dragón plateado de los raros, como el del juego, en la esquina de arriba a la izquierda
  b.dragon = b:CreateTexture(nil, "OVERLAY", nil, 2)
  b.dragon:SetWidth(22); b.dragon:SetHeight(22)
  b.dragon:SetPoint("TOPLEFT", b.marco, "TOPLEFT", -9, 7)
  local ATLAS = "nameplates-icon-elite-silver"
  local hay = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ATLAS)
  if hay and b.dragon.SetAtlas then
    b.dragon:SetAtlas(ATLAS)
  else
    b.dragon:SetTexture("Interface\\Tooltips\\EliteNameplateIcon")   -- el dorado del juego, en gris plata
    if b.dragon.SetDesaturated then b.dragon:SetDesaturated(true) end
    b.dragon:SetVertexColor(0.92, 0.94, 1)
  end
  b.dragon:Hide()
  b.icono = b:CreateTexture(nil, "ARTWORK")
  b.icono:SetWidth(LADO_ICONO); b.icono:SetHeight(LADO_ICONO)
  b.icono:SetPoint("CENTER", b.marco, "CENTER", 0, 0)
  b.marca = b:CreateTexture(nil, "OVERLAY")   -- tic verde si la tienes, X roja si no
  b.marca:SetWidth(16); b.marca:SetHeight(16)
  b.marca:SetPoint("BOTTOMRIGHT", b.marco, "BOTTOMRIGHT", 4, -4)
  b.marca:Hide()
  b.nombre = GL.Texto(b, "GameFontHighlightSmall", "CENTER")
  b.nombre:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -LADO_ICONO - 6)
  b.nombre:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -LADO_ICONO - 6)
  if b.nombre.SetMaxLines then b.nombre:SetMaxLines(2) end
  b:SetScript("OnClick", function(self)
    if pest == "familias" and not fam and self.e and self.e.hab then fam, desde, sel = self.e.f, 0, nil; Refrescar(); return end
    sel = (sel ~= self.e) and self.e or nil
    Refrescar()
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.e.n or "?")
    if pest == "familias" and not fam then GameTooltip:AddLine(L"Clic: ver sus bestias", 0.7, 0.7, 0.7)
    elseif self.e.npc then GameTooltip:AddLine(L"Nivel " .. (self.e.nv or "?") .. " · " .. (self.e.zona or ""), 1, 1, 1)
    else GameTooltip:AddLine(L"Desde el nivel " .. (self.e.nivel or "?"), 1, 1, 1) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function CrearFila()
  local f = CreateFrame("Button", nil, panel)
  f:SetHeight(ALTO_FILA - 2)
  f.icono = f:CreateTexture(nil, "ARTWORK")
  f.icono:SetWidth(22); f.icono:SetHeight(22)
  f.icono:SetPoint("LEFT", f, "LEFT", 2, 0)
  f.marca = f:CreateTexture(nil, "OVERLAY")
  f.marca:SetWidth(12); f.marca:SetHeight(12)
  f.marca:SetPoint("BOTTOMRIGHT", f.icono, "BOTTOMRIGHT", 3, -3)
  f.marca:Hide()
  f.texto = GL.Texto(f, "GameFontHighlightSmall")
  f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -2)
  f.texto:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  f.detalle = GL.Texto(f, "GameFontHighlightSmall")
  f.detalle:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -15)
  f.detalle:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  if GL.UnaLinea then GL.UnaLinea(f.texto); GL.UnaLinea(f.detalle) end
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.05)
  f:SetScript("OnClick", function(self)
    local p = self.d and self.d.destino
    if p and GL.SeguirDesvio then GL.SeguirDesvio({ m = p.m, x = p.x, y = p.y, n = p.n }) end
  end)
  return f
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  ui.CrearCelda, ui.CrearFila = CrearCelda, CrearFila

  ui.titulo = GL.Texto(panel, "GameFontNormal")
  ui.titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  ui.titulo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  if GL.UnaLinea then GL.UnaLinea(ui.titulo) end
  local tabs = Pestanas()
  for i = 1, #tabs do
    local clave = tabs[i][1]
    local b = GL.CrearBoton(panel, tabs[i][2], function()
      if clave == "rangos" then if GL.AbrirRangosMascota then GL.AbrirRangosMascota() end return end   -- 9.4: CazadorBrujo94.lua
      pest, fam, sel, desde = clave, nil, nil, 0; Refrescar()
    end, nil, 20)
    b:SetWidth(#tabs > 3 and 84 or 96)
    b.clave = clave
    if i == 1 then b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22) else b:SetPoint("LEFT", ui.pest[i - 1], "RIGHT", 4, 0) end
    ui.pest[i] = b
  end
  ui.subs = {}
  for i = 1, #SUB_ESTABLO do
    local clave = SUB_ESTABLO[i][1]
    local b = GL.CrearBoton(panel, SUB_ESTABLO[i][2], function() subEst, desde = clave, 0; Refrescar() end, nil, 18)
    b:SetWidth(140)
    b.clave = clave
    if i == 1 then b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -50) else b:SetPoint("LEFT", ui.subs[i - 1], "RIGHT", 4, 0) end
    b:Hide()
    ui.subs[i] = b
  end
  ui.volver = GL.CrearBoton(panel, L"< Familias", function() fam, desde, sel = nil, 0, nil; Refrescar() end, nil, 20)
  ui.volver:SetWidth(84)
  ui.volver:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -22)
  ui.volver:Hide()
  ui.cab = GL.Texto(panel, "GameFontHighlightSmall")
  ui.cab:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -54)
  ui.cab:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  if ui.cab.SetSpacing then ui.cab:SetSpacing(2) end
  ui.pie = GL.Texto(panel, "GameFontHighlightSmall")

  local ficha = CreateFrame("Frame", nil, panel, PLANTILLA)
  ficha:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 4)
  ficha:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
  ficha:SetHeight(ALTO_FICHA)
  if GL.Caja and GL.COLOR then GL.Caja(ficha, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  local borde = ficha:CreateTexture(nil, "ARTWORK")
  borde:SetWidth(3)
  borde:SetPoint("TOPLEFT", ficha, "TOPLEFT", 0, 0)
  borde:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 0, 0)
  borde:SetColorTexture(1, 0.78, 0.25, 1)
  ui.fichaTitulo = GL.Texto(ficha, "GameFontNormalSmall")
  ui.fichaTitulo:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -8)
  ui.fichaTitulo:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -8)
  if GL.UnaLinea then GL.UnaLinea(ui.fichaTitulo) end
  ui.fichaTexto = GL.Texto(ficha, "GameFontHighlightSmall")
  ui.fichaTexto:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -24)
  ui.fichaTexto:SetPoint("RIGHT", ficha, "RIGHT", -8, 0)
  if ui.fichaTexto.SetSpacing then ui.fichaTexto:SetSpacing(2) end
  ui.llevar = GL.CrearBoton(ficha, L"Llevarme", function()
    if ui.destino and GL.SeguirDesvio then GL.SeguirDesvio(ui.destino) end
  end, nil, 20, "accion")
  ui.llevar:SetWidth(110)
  ui.llevar:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 12, 8)
  ficha:Hide()
  ui.ficha = ficha

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta) desde = math.max(0, desde - delta); Refrescar() end)
  panel:SetScript("OnSizeChanged", function() Refrescar() end)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt)
    if not panel:IsShown() then return end
    espera = espera + dt
    if espera >= 2 then espera = 0; Refrescar() end
  end)
  GL.modos.mascotas = { panel = panel, refrescar = Refrescar }
end

GL.perezosos = GL.perezosos or {}
GL.perezosos.mascotas = CrearPanel

-- Botón de la barra lateral: solo cazadores y brujos, justo encima del de Grupo
table.insert(GL.alIniciar, function()
  local ui0 = GL.ui
  if not (EsCazador() or EsBrujo()) then return end
  if not (ui0 and GL.BotonLateral and GL.frame) then return end
  if GL.LADO then GL.LADO.mascotas = true end
  local icono = EsCazador() and "Interface\\Icons\\Ability_Hunter_BeastTaming" or "Interface\\Icons\\Spell_Shadow_SummonImp"
  local ayuda = EsCazador() and L"Familias de bestias, tus mascotas y los establos." or L"Tus demonios, cómo conseguirlos y los instructores."
  local b = GL.BotonLateral("mascotas", L"Mascotas", icono, ayuda, function()
    if DB().modo == "mascotas" then GL.AbrirModo(DB().modoGuia or "guia") else GL.AbrirModo("mascotas") end
  end)
  b:SetPoint("TOPLEFT", GL.frame, "TOPLEFT", (GL.RAIL - 36) / 2, ui0.yLateral or -300)
  ui0.yLateral = (ui0.yLateral or -300) - 34   -- el de Grupo va debajo
  table.insert(ui0.lado, b)
  GL._botonMascotas = b
  if DB().cargarAlAbrir == false then CrearPanel() end
end)

do
  local f = CreateFrame and CreateFrame("Frame")
  if f then
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_PET", "PET_STABLE_SHOW", "PET_STABLE_UPDATE" }) do pcall(f.RegisterEvent, f, ev) end
    f:SetScript("OnEvent", function(_, ev, unidad)
      if ev == "UNIT_PET" and unidad ~= "player" then return end
      if ev == "PET_STABLE_SHOW" or ev == "PET_STABLE_UPDATE" then ApuntarEstablo() end
      ApuntarMascota()
      if panel and panel:IsShown() then Refrescar() end
    end)
  end
end

-- Para las pruebas
GL._mascotas = { Abrir = function(p, f, e, s) pest, fam, sel, desde = p, f, e, 0; if s then subEst = s end; Refrescar() end, Rejilla = function() return ListaRejilla() end,
  Filas = function() return Filas() end, Cabecera = function() return Cabecera() end, Ficha = function(e) return TextoFicha(e) end,
  LaTengo = LaTengo, Destino = function(e) return DestinoFicha(e) end }

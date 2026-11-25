-- Especializacion.lua (9.4): al tener el primer talento (nivel 10) la guía pregunta qué especialización quieres
-- y recomienda la que sube más rápido. La de la guía usa el plan de talentos de la ruta; las otras dos, una
-- lista de talentos clave por orden que la guía pone sola si los encuentra en tu árbol (Forever cambia algunos
-- talentos: los que no estén te los dice para que los pongas a mano). Se cambia con /ga especializacion.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local function DB() if type(GuiaAventureroDB) ~= "table" then return {} end return GuiaAventureroDB end
local function Clase()
  if type(UnitClass) ~= "function" then return nil end
  local ok, _, clase = pcall(UnitClass, "player")
  if ok and not (issecretvalue and issecretvalue(clase)) and type(clase) == "string" then return clase end
end
local function Nivel() return (UnitLevel and UnitLevel("player")) or 1 end

------------------------------------------------------------------------
-- Datos: por clase, las tres ramas (con el nombre que usan las rutas), su papel, lo rápido que sube (1 a 3) y,
-- para las que no son de la guía, los talentos clave en orden: { "Nombre (English)", rangos }.
------------------------------------------------------------------------
local ESPECIALIZACIONES = {
  DRUID = {
    { rama = "Equilibrio", rol = "Daño a distancia", ritmo = 2, texto = "Hechizos desde lejos (Cólera y Fuego lunar). Sube bien, pero gasta mucho maná: más descansos.",
      plan = { { "Ira mejorada (Improved Wrath)", 5 }, { "Fuego lunar mejorado (Improved Moonfire)", 5 }, { "Alcance de la naturaleza (Nature's Reach)", 2 },
        { "Augurio de claridad (Omen of Clarity)", 1 }, { "Raíces enredadoras mejoradas (Improved Entangling Roots)", 3 }, { "Venganza (Vengeance)", 5 },
        { "Fuego estelar mejorado (Improved Starfire)", 5 }, { "Gracia de la naturaleza (Nature's Grace)", 1 }, { "Resplandor lunar (Moonglow)", 3 },
        { "Furia lunar (Moonfury)", 5 }, { "Forma de lechúcico lunar (Moonkin Form)", 1 }, { "Corazón de lo Salvaje (Heart of the Wild)", 5 },
        { "Naturalista (Naturalist)", 5 }, { "Furor (Furor)", 5 } } },
    { rama = "Combate feral", rol = "Tanque y daño cuerpo a cuerpo", ritmo = 3, texto = "Forma de oso y de felino: matas rápido, aguantas mucho y casi no paras a beber." },
    { rama = "Restauración", rol = "Sanación", ritmo = 1, texto = "Para sanar en grupo y mazmorras. Sola sube despacio.",
      plan = { { "Corazón de lo Salvaje (Heart of the Wild)", 5 }, { "Naturalista (Naturalist)", 5 }, { "Furor (Furor)", 5 },
        { "Toque de sanación mejorado (Improved Healing Touch)", 5 }, { "Enfoque de la naturaleza (Nature's Focus)", 5 }, { "Reflejo (Reflection)", 3 },
        { "Enjambre de insectos (Insect Swarm)", 1 }, { "Sutileza (Subtlety)", 5 }, { "Rejuvenecimiento mejorado (Improved Rejuvenation)", 3 },
        { "Presteza de la naturaleza (Nature's Swiftness)", 1 }, { "Don de la naturaleza (Gift of Nature)", 5 }, { "Recrecimiento mejorado (Improved Regrowth)", 5 },
        { "Alivio presto (Swiftmend)", 1 }, { "Ira mejorada (Improved Wrath)", 5, "Equilibrio" } } },
  },
  HUNTER = {
    { rama = "Bestias", rol = "Daño a distancia con mascota", ritmo = 3, texto = "Tu mascota hace mucho daño y aguanta: la forma más rápida de subir." },
    { rama = "Puntería", rol = "Daño a distancia", ritmo = 2, texto = "Más daño con tus disparos. Muy buena en grupo y desde el nivel 40.",
      plan = { { "Ataques letales (Lethal Attacks)", 5 }, { "Eficiencia (Efficiency)", 5 }, { "Afinar la puntería (Careful Aim)", 5 },
        { "Disparo apuntado (Aimed Shot)", 1 }, { "Disparo Arcano mejorado (Improved Arcane Shot)", 5 }, { "Ojo de halcón (Hawk Eye)", 3 },
        { "Disparos mortales (Mortal Shots)", 5 }, { "Picadura de serpiente mejorada (Improved Serpent Sting)", 5 }, { "Tromba (Barrage)", 3 },
        { "Disparo de dispersión (Scatter Shot)", 1 }, { "Especialización en armas a distancia (Ranged Weapon Specialization)", 5 },
        { "Aura de disparo certero (Trueshot Aura)", 1 }, { "Aspectos letales (Deadly Aspects)", 5 }, { "Entrenamiento de robustez (Endurance Training)", 5 } } },
    { rama = "Supervivencia", rol = "Daño y control", ritmo = 2, texto = "Trampas, cuerpo a cuerpo y Agilidad. Aguanta bien cuando la mascota pierde el control.",
      plan = { { "Desviar (Deflection)", 5 }, { "Golpes salvajes (Savage Strikes)", 2 }, { "Superviviente (Survivalist)", 5 }, { "Disuasión (Deterrence)", 1 },
        { "Trampas astutas (Clever Traps)", 2 }, { "Atrapar (Entrapment)", 5 }, { "Paso firme (Surefooted)", 3 }, { "Instinto asesino (Killer Instinct)", 3 },
        { "Contraataque (Counterattack)", 1 }, { "Reflejos relámpago (Lightning Reflexes)", 5 }, { "Picadura de dracoleón (Wyvern Sting)", 1 },
        { "Matanza de humanoides (Humanoid Slaying)", 3 }, { "Matanza de monstruos (Monster Slaying)", 3 }, { "Eficiencia (Efficiency)", 5 },
        { "Ataques letales (Lethal Attacks)", 5 }, { "Afinar la puntería (Careful Aim)", 5 } } },
  },
  MAGE = {
    { rama = "Escarcha", rol = "Daño a distancia y control", ritmo = 3, texto = "Congelas y ralentizas: matas sin que te toquen. La más segura para subir." },
    { rama = "Arcano", rol = "Daño a distancia", ritmo = 1, texto = "Mucho maná y daño en ráfagas. Mejor como apoyo de otra rama que sola para subir.",
      plan = { { "Resiliencia arcana (Arcane Resilience)", 3 }, { "Especialización en varitas (Wand Specialization)", 2 }, { "Concentración arcana (Arcane Concentration)", 5 },
        { "Sutileza arcana (Arcane Subtlety)", 2 }, { "Enfoque arcano (Arcane Focus)", 5 }, { "Misiles Arcanos mejorados (Improved Arcane Missiles)", 5 },
        { "Absorción mágica (Magic Absorption)", 2 }, { "Explosión Arcana (Arcane Blast)", 1 }, { "Meditación arcana (Arcane Meditation)", 3 },
        { "Mente arcana (Arcane Mind)", 5 }, { "Presencia mental (Presence of Mind)", 1 }, { "Inestabilidad arcana (Arcane Instability)", 3 },
        { "Poder arcano (Arcane Power)", 1 }, { "Descarga de Escarcha mejorada (Improved Frostbolt)", 5 }, { "Mordedura de Escarcha (Frostbite)", 3 },
        { "Fragmentos de hielo (Ice Shards)", 5 } } },
    { rama = "Fuego", rol = "Daño a distancia", ritmo = 2, texto = "El que más daño hace, pero sin control: si fallas, te alcanzan. Muy bueno en grupo.",
      plan = { { "Bola de Fuego mejorada (Improved Fireball)", 5 }, { "Impacto (Impact)", 5 }, { "Ignición (Ignite)", 5 }, { "Lanzamiento de llamas (Flame Throwing)", 2 },
        { "Explosión de Fuego mejorada (Improved Fire Blast)", 3 }, { "Incinerar (Incinerate)", 2 }, { "Piroexplosión (Pyroblast)", 1 },
        { "Abrasar mejorado (Improved Scorch)", 3 }, { "Maestro de los elementos (Master of Elements)", 3 }, { "Masa crítica (Critical Mass)", 3 },
        { "Ola explosiva (Blast Wave)", 1 }, { "Poder del Fuego (Fire Power)", 5 }, { "Combustión (Combustion)", 1 },
        { "Concentración arcana (Arcane Concentration)", 5 }, { "Sutileza arcana (Arcane Subtlety)", 2 }, { "Enfoque arcano (Arcane Focus)", 5, "Arcano" } } },
  },
  PALADIN = {
    { rama = "Reprensión", rol = "Daño cuerpo a cuerpo", ritmo = 3, texto = "Arma de dos manos y sellos: la forma más rápida de subir con el paladín." },
    { rama = "Sagrado", rol = "Sanación", ritmo = 1, texto = "Para sanar en grupo y bandas. Sola sube despacio.",
      plan = { { "Intelecto divino (Divine Intellect)", 5 }, { "Enfoque espiritual (Spiritual Focus)", 5 }, { "Luz sanadora (Healing Light)", 3 },
        { "Consagración (Consecration)", 1 }, { "Iluminación (Illumination)", 5 }, { "Favor divino (Divine Favor)", 1 }, { "Poder sagrado (Holy Power)", 5 },
        { "Choque sagrado (Holy Shock)", 1 }, { "Fuerza divina (Divine Strength)", 5 }, { "Conducto sagrado (Holy Conduit)", 2 }, { "Reverencia (Reverence)", 2 },
        { "Poder purificador (Purifying Power)", 2 }, { "Bendición (Benediction)", 5 }, { "Sentencia mejorada (Improved Judgement)", 2 }, { "Convicción (Conviction)", 5 },
        { "Precisión (Precision)", 3, "Protección" } } },   -- 9.4.2: hasta los 51 puntos
    { rama = "Protección", rol = "Tanque", ritmo = 1, texto = "Para tanquear mazmorras. Aguanta grupos de enemigos, pero mata despacio.",
      plan = { { "Aura de devoción mejorada (Improved Devotion Aura)", 5 }, { "Reducto (Redoubt)", 5 }, { "Dureza (Toughness)", 5 }, { "Precisión (Precision)", 3 },
        { "Bendición de reyes (Blessing of Kings)", 1 }, { "Furia justa mejorada (Improved Righteous Fury)", 3 }, { "Especialización en escudos (Shield Specialization)", 3 },
        { "Anticipación (Anticipation)", 5 }, { "Martillo de justicia mejorado (Improved Hammer of Justice)", 3 }, { "Bendición de santuario (Blessing of Sanctuary)", 1 },
        { "Desagravio (Reckoning)", 5 }, { "Especialización en armas de una mano (One-Handed Weapon Specialization)", 5 }, { "Escudo sagrado (Holy Shield)", 1 },
        { "Bendición (Benediction)", 5 }, { "Sentencia mejorada (Improved Judgement)", 2 } } },
  },
  PRIEST = {
    { rama = "Sombra", rol = "Daño a distancia", ritmo = 3, texto = "Daño de sombras y Golpe de espíritu: recuperas maná al matar. La más rápida para subir." },
    { rama = "Sagrado", rol = "Sanación", ritmo = 1, texto = "Para sanar en grupo. Sola sube despacio: mejor después del 60 o en grupo.",
      plan = { { "Especialización sagrada (Holy Specialization)", 5 }, { "Renovar mejorado (Improved Renew)", 3 }, { "Furia divina (Divine Fury)", 5 },
        { "Nova sagrada (Holy Nova)", 1 }, { "Inspiración (Inspiration)", 3 }, { "Luz abrasadora (Searing Light)", 2 }, { "Sanación mejorada (Improved Healing)", 3 },
        { "Alcance sagrado (Holy Reach)", 2 }, { "Espíritu de redención (Spirit of Redemption)", 1 }, { "Guía espiritual (Spiritual Guidance)", 5 },
        { "Sanación espiritual (Spiritual Healing)", 5 }, { "Pozo de luz (Lightwell)", 1 }, { "Disciplinas gemelas (Twin Disciplines)", 5 },
        { "Fuerza mental (Mental Strength)", 5 }, { "Especialización en varitas (Wand Specialization)", 5 } } },   -- 9.4.2: hasta los 51 puntos
    { rama = "Disciplina", rol = "Sanación y escudos", ritmo = 1, texto = "Escudos, maná y Espíritu divino. Buena para grupo; sola, más lenta que Sombra.",
      plan = { { "Especialización en varitas (Wand Specialization)", 2 }, { "Disciplinas gemelas (Twin Disciplines)", 5 },
        { "Palabra de poder: escudo mejorada (Improved Power Word: Shield)", 3 }, { "Enfoque interno (Inner Focus)", 1 }, { "Meditación (Meditation)", 3 },
        { "Agilidad mental (Mental Agility)", 5 }, { "Fuerza mental (Mental Strength)", 5 }, { "Espíritu divino (Divine Spirit)", 1 },
        { "Fuerza de voluntad (Force of Will)", 5 }, { "Infusión de poder (Power Infusion)", 1 }, { "Voluntad inquebrantable (Unbreakable Will)", 5 },
        { "Golpe de espíritu (Spirit Tap)", 5 }, { "Palabra de las Sombras: dolor mejorada (Improved Shadow Word: Pain)", 2 },
        { "Explosión mental mejorada (Improved Mind Blast)", 5 }, { "Tortura mental (Mind Flay)", 1 }, { "Alcance de las Sombras (Shadow Reach)", 2 } } },
  },
  ROGUE = {
    { rama = "Combate", rol = "Daño cuerpo a cuerpo", ritmo = 3, texto = "Golpe siniestro y dos armas: el más constante y el que mejor aguanta para subir." },
    { rama = "Asesinato", rol = "Daño cuerpo a cuerpo", ritmo = 2, texto = "Críticos, venenos y Sangre fría: mucho daño de golpe. Muy buena a partir del 40.",
      plan = { { "Malicia (Malice)", 5 }, { "Destripar mejorado (Improved Eviscerate)", 3 }, { "Despiadado (Ruthlessness)", 3 }, { "Asesinato (Murder)", 2 },
        { "Hacer picadillo mejorado (Improved Slice and Dice)", 3 }, { "Golpes implacables (Relentless Strikes)", 1 }, { "Letalidad (Lethality)", 5 },
        { "Vigor (Vigor)", 2 }, { "Venenos viles (Vile Poisons)", 5 }, { "Sangre fría (Cold Blood)", 1 }, { "Venenos mejorados (Improved Poisons)", 5 },
        { "Sellar el destino (Seal Fate)", 5 }, { "Precisión (Precision)", 3 }, { "Desviar (Deflection)", 3 }, { "Reflejos relámpago (Lightning Reflexes)", 5 } } },
    { rama = "Sutileza", rol = "Daño y sigilo", ritmo = 1, texto = "Sigilo, Hemorragia y Preparación. Mejor para JcJ que para subir.",
      plan = { { "Maestro del engaño (Master of Deception)", 5 }, { "Oportunidad (Opportunity)", 5 }, { "Camuflaje (Camouflage)", 5 }, { "Iniciativa (Initiative)", 3 },
        { "Golpe fantasmal (Ghostly Strike)", 1 }, { "Emboscada mejorada (Improved Ambush)", 3 }, { "Hojas serradas (Serrated Blades)", 3 },
        { "Hemorragia (Hemorrhage)", 1 }, { "Preparación (Preparation)", 1 }, { "Malas artes (Dirty Deeds)", 2 }, { "Mortalidad (Deadliness)", 5 },
        { "Premeditación (Premeditation)", 1 }, { "Precisión (Precision)", 3 }, { "Desviar (Deflection)", 3 }, { "Reflejos relámpago (Lightning Reflexes)", 5 },
        { "Malicia (Malice)", 5 } } },
  },
  SHAMAN = {
    { rama = "Mejora", rol = "Daño cuerpo a cuerpo", ritmo = 3, texto = "Arma de dos manos, Aluvión y Golpe de tormenta: la más rápida y la que menos para." },
    { rama = "Elemental", rol = "Daño a distancia", ritmo = 2, texto = "Relámpagos y choques: mucho daño desde lejos, pero gasta maná rápido.",
      plan = { { "Concusión (Concussion)", 5 }, { "Convección (Convection)", 5 }, { "Llamada de la llama (Call of Flame)", 3 }, { "Enfoque elemental (Elemental Focus)", 1 },
        { "Reverberación (Reverberation)", 5 }, { "Llamada del trueno (Call of Thunder)", 5 }, { "Devastación elemental (Elemental Devastation)", 3 },
        { "Furia elemental (Elemental Fury)", 1 }, { "Alcance de la tormenta (Storm Reach)", 2 }, { "Maestría con relámpagos (Lightning Mastery)", 5 },
        { "Maestría elemental (Elemental Mastery)", 1 }, { "Golpes de trueno (Thundering Strikes)", 5 }, { "Conocimiento ancestral (Ancestral Knowledge)", 5, "Mejora" },
        { "Maña mental (Mental Dexterity)", 3 }, { "Escudo de relámpagos mejorado (Improved Lightning Shield)", 3 } } },
    { rama = "Restauración", rol = "Sanación", ritmo = 1, texto = "Para sanar en grupo y bandas. Sola sube despacio.",
      plan = { { "Ola de sanación mejorada (Improved Healing Wave)", 5 }, { "Enfoque de las mareas (Tidal Focus)", 5 }, { "Sanación ancestral (Ancestral Healing)", 3 },
        { "Enfoque totémico (Totemic Focus)", 5 }, { "Guía de la naturaleza (Nature's Guidance)", 3 }, { "Enfoque de sanación (Healing Focus)", 5 },
        { "Maestría totémica (Totemic Mastery)", 1 }, { "Gracia sanadora (Healing Grace)", 3 }, { "Tótems reconstituyentes (Restorative Totems)", 5 },
        { "Maestría de las mareas (Tidal Mastery)", 5 }, { "Camino de sanación (Healing Way)", 3 }, { "Presteza de la naturaleza (Nature's Swiftness)", 1 },
        { "Purificación (Purification)", 5 }, { "Tótem Marea de maná (Mana Tide Totem)", 1 }, { "Convección (Convection)", 5 } } },
  },
  WARLOCK = {
    { rama = "Aflicción", rol = "Daño a distancia con demonio", ritmo = 3, texto = "Maldiciones y drenajes: matas varios a la vez casi sin parar. La más rápida." },
    { rama = "Demonología", rol = "Daño con demonio", ritmo = 3, texto = "Tu demonio pega y aguanta mucho más: casi tan rápida como Aflicción y más segura.",
      plan = { { "Abrazo demoníaco (Demonic Embrace)", 5 }, { "Abisario mejorado (Improved Voidwalker)", 3 }, { "Intelecto vil (Fel Intellect)", 5 },
        { "Dominación vil (Fel Domination)", 1 }, { "Aguante vil (Fel Stamina)", 5 }, { "Poder profano (Unholy Power)", 5 }, { "Energías demoníacas (Demonic Energies)", 2 },
        { "Maestro invocador (Master Summoner)", 2 }, { "Sacrificio demoníaco (Demonic Sacrifice)", 1 }, { "Maestro demonólogo (Master Demonologist)", 5 },
        { "Vínculo de alma (Soul Link)", 1 }, { "Canalizar salud mejorado (Improved Health Funnel)", 2 }, { "Corrupción mejorada (Improved Corruption)", 5 },
        { "Supresión (Suppression)", 5 }, { "Drenajes mejorados (Improved Drains)", 3 }, { "Amplificar maldición (Amplify Curse)", 1 } } },
    { rama = "Destrucción", rol = "Daño a distancia", ritmo = 2, texto = "Descarga de las Sombras y fuego: mucho daño de golpe, pero gastas más maná y fragmentos.",
      plan = { { "Descarga de las Sombras mejorada (Improved Shadow Bolt)", 5 }, { "Cataclismo (Cataclysm)", 5 }, { "Perdición (Bane)", 5 }, { "Devastación (Devastation)", 5 },
        { "Quemadura de las Sombras (Shadowburn)", 1 }, { "Dolor abrasador mejorado (Improved Searing Pain)", 5 }, { "Inmolar mejorado (Improved Immolate)", 5 },
        { "Ruina (Ruin)", 1 }, { "Tormenta de ascuas (Emberstorm)", 5 }, { "Conflagrar (Conflagrate)", 1 }, { "Corrupción mejorada (Improved Corruption)", 5 },
        { "Supresión (Suppression)", 5 }, { "Drenajes mejorados (Improved Drains)", 3 } } },
  },
  WARRIOR = {
    { rama = "Armas", rol = "Daño cuerpo a cuerpo", ritmo = 3, texto = "Arma de dos manos, Heridas profundas y Golpe mortal: la más rápida para subir." },
    { rama = "Furia", rol = "Daño cuerpo a cuerpo", ritmo = 2, texto = "Dos armas, Aluvión y Sed de sangre. Muy buena desde el 40 y en grupo.",
      plan = { { "Crueldad (Cruelty)", 5 }, { "Cólera desenfrenada (Unbridled Wrath)", 5 }, { "Locura sangrienta (Blood Craze)", 3 }, { "Enfurecer (Enrage)", 5 },
        { "Especialización en doble arma (Dual Wield Specialization)", 5 }, { "Grito de batalla mejorado (Improved Battle Shout)", 5 },
        { "Deseo de muerte (Death Wish)", 1 }, { "Aluvión (Flurry)", 5 }, { "Sed de sangre (Bloodthirst)", 1 }, { "Ejecutar mejorado (Improved Execute)", 2 },
        { "Golpes temerarios (Reckless Swings)", 1 }, { "Aullido perforador (Piercing Howl)", 1 }, { "Golpe heroico mejorado (Improved Heroic Strike)", 3 },
        { "Heridas profundas (Deep Wounds)", 3 }, { "Control de la ira (Anger Management)", 1 }, { "Cargar mejorado (Improved Charge)", 2 },
        { "Abrumar mejorado (Improved Overpower)", 2 }, { "Empalar (Impale)", 2 } } },
    { rama = "Protección", rol = "Tanque", ritmo = 1, texto = "Escudo y aguante para tanquear mazmorras. Sola mata despacio.",
      plan = { { "Especialización en escudos (Shield Specialization)", 5 }, { "Anticipación (Anticipation)", 5 }, { "Dureza (Toughness)", 5 }, { "Último recurso (Last Stand)", 1 },
        { "Bloqueo con escudo mejorado (Improved Shield Block)", 3 }, { "Revancha mejorada (Improved Revenge)", 3 }, { "Desafío (Defiance)", 5 },
        { "Hender armadura mejorado (Improved Sunder Armor)", 3 }, { "Golpe conmocionador (Concussion Blow)", 1 },
        { "Especialización en armas de una mano (One-Handed Weapon Specialization)", 5 }, { "Embate con escudo (Shield Slam)", 1 },
        { "Golpe heroico mejorado (Improved Heroic Strike)", 3 }, { "Heridas profundas (Deep Wounds)", 3 }, { "Control de la ira (Anger Management)", 1 },
        { "Cargar mejorado (Improved Charge)", 2 }, { "Desgarrar mejorado (Improved Rend)", 3 }, { "Maestría táctica mejorada (Improved Tactical Mastery)", 2 } } },
  },
}
GL.ESPECIALIZACIONES = ESPECIALIZACIONES

------------------------------------------------------------------------
-- La de la guía es la rama con más puntos en el plan de la ruta
------------------------------------------------------------------------
local guia = nil   -- plan original de la ruta, intro y rama
local function GuardarGuia(R)
  if guia or not R then return end
  local cuenta, mejor = {}, nil
  for _, t in ipairs(R.talentos or {}) do
    local n = tonumber(string.match(t.puntos or "", "^(%d+)")) or 1
    cuenta[t.rama or "?"] = (cuenta[t.rama or "?"] or 0) + n
  end
  for r, n in pairs(cuenta) do if not mejor or n > cuenta[mejor] then mejor = r end end
  guia = { talentos = R.talentos, intro = R.talentosIntro, rama = mejor }
end

local function Lista()
  return ESPECIALIZACIONES[Clase() or ""] or {}
end

local function EsDeLaGuia(e) return guia and L(e.rama) == guia.rama end
function GL.TalentosDeLaGuia() return guia and guia.talentos or nil end   -- 9.7.7.1: para Talentos.lua

local function Rama(R, nombre)
  for _, r in ipairs(R.ramas or {}) do if r.nombre == nombre then return r end end
end

-- Pasa la lista de talentos clave al formato del plan de la ruta (d = nivel desde, h = nivel hasta, puntos = "n/máx").
local function Plan(e, R)
  local l, nivel = {}, 10
  local icono = (Rama(R, L(e.rama)) or {}).icono
  local hecho = {}
  for _, p in ipairs(e.plan or {}) do
    local nombre, rangos = p[1], p[2]
    if nivel > 60 then break end
    local desde = hecho[nombre] or 0
    local hasta = math.min(rangos, desde + (61 - nivel))
    if hasta > desde then
      local fin = nivel + (hasta - desde) - 1
      local rama = L(e.rama)
      -- los talentos de la otra rama (al final de la lista) llevan la rama que diga el plan de la ruta, si sale
      for _, t in ipairs(guia.talentos or {}) do if t.nombre and t.nombre:find(nombre:match("%((.-)%)") or "\0", 1, true) then rama = t.rama end end
      if p[3] then rama = L(p[3]) end   -- 9.4.2: rama puesta a mano (talentos de otra rama que no salen en la ruta)
      table.insert(l, { d = nivel, h = fin, rama = rama, nombre = nombre, puntos = hasta .. "/" .. rangos, icono = icono,
        nota = L"Talento clave de la especialización elegida." })
      hecho[nombre] = hasta
      nivel = fin + 1
    end
  end
  if GL.TraducirTalentos then GL.TraducirTalentos(l) end
  return l
end

-- 9.7.7: perfiles orientativos de leveo, no simulaciones de Forever.
-- Se conserva el equipo original por ruta; nunca se modifican sus tablas de pesos.
local originalesEquipo = setmetatable({}, { __mode = "k" })
local perfiles = {
  sanador = { INTELLECT=1.2, SPIRIT=1.0, STAMINA=0.5, SPELL_POWER=1.0, HEALING_DONE=1.4, MANA_REGENERATION=1.8, CRIT_SPELL_RATING=0.6 },
  lanzador = { INTELLECT=1.0, SPIRIT=0.5, STAMINA=0.6, SPELL_POWER=1.3, SPELL_DAMAGE_DONE=1.3, MANA_REGENERATION=1.0, HIT_SPELL_RATING=0.9, CRIT_SPELL_RATING=0.9 },
  tanque = { STAMINA=1.5, STRENGTH=0.8, AGILITY=0.7, DEFENSE_SKILL_RATING=1.2, DODGE_RATING=1.1, PARRY_RATING=1.0, BLOCK_RATING=0.9, HIT_RATING=0.6, ATTACK_POWER=0.3 },
  fisico = { STRENGTH=1.0, AGILITY=0.8, STAMINA=0.7, ATTACK_POWER=0.5, HIT_RATING=0.9, CRIT_RATING=0.9 },
}
local ramasEquipo = {
  MAGE={Escarcha="lanzador",Arcano="lanzador",Fuego="lanzador"},
  WARLOCK={["Aflicción"]="lanzador",["Demonología"]="lanzador",["Destrucción"]="lanzador"},
  HUNTER={Bestias="fisico",["Puntería"]="fisico",Supervivencia="fisico"},
  ROGUE={Combate="fisico",Asesinato="fisico",Sutileza="fisico"},
  DRUID={Equilibrio="lanzador",["Restauración"]="sanador"},
  PALADIN={Sagrado="sanador",["Protección"]="tanque",["Reprensión"]="fisico"},
  PRIEST={Sagrado="sanador",Disciplina="sanador",Sombra="lanzador"},
  SHAMAN={Elemental="lanzador",["Restauración"]="sanador",Mejora="fisico"},
  WARRIOR={["Protección"]="tanque",Furia="fisico",Armas="fisico"},
}
function GL.AplicarEquipoEspecializacion(R, clase, rama, esOriginal)
  if not R or type(R.equipo) ~= "table" then return end
  local original = originalesEquipo[R] or R.equipo
  originalesEquipo[R] = original
  local perfil = not esOriginal and (ramasEquipo[clase or ""] or {})[rama or ""]
  if not perfil then R.equipo = original; return end
  local equipo, pesos = {}, {}
  for k,v in pairs(original) do equipo[k]=v end
  for k,v in pairs(perfiles[perfil]) do pesos["ITEM_MOD_"..k.."_SHORT"]=v end
  pesos.DPS = perfil=="fisico" and 6 or perfil=="tanque" and 2 or 0.1
  pesos.VARITA = perfil=="lanzador" and 1 or 0.2
  pesos.RESISTANCE0_NAME = perfil=="tanque" and 0.08 or 0.02
  -- Ajustes orientativos por rama; no son simulaciones de DPS.
  local function peso(k,v) pesos["ITEM_MOD_"..k.."_SHORT"]=v end
  if clase=="MAGE" then
    if rama=="Arcano" then peso("INTELLECT",1.5); peso("MANA_REGENERATION",1.3)
    elseif rama=="Fuego" then peso("CRIT_SPELL_RATING",1.3)
    else peso("STAMINA",0.8) end
  elseif clase=="WARLOCK" then
    if rama=="Aflicción" then peso("SPELL_POWER",1.5); peso("SPELL_DAMAGE_DONE",1.5); peso("HIT_SPELL_RATING",1.1)
    elseif rama=="Demonología" then peso("STAMINA",1.2)
    else peso("CRIT_SPELL_RATING",1.3) end
  elseif clase=="HUNTER" then
    peso("STRENGTH",0.1); peso("AGILITY",1.5); peso("INTELLECT",0.6)
    pesos.DPS=0.4; pesos.DISTANCIA= rama=="Puntería" and 8 or 6
    if rama=="Supervivencia" then peso("AGILITY",1.8); peso("STAMINA",1.0) end
    if rama=="Bestias" then peso("STAMINA",0.9) end
  elseif clase=="ROGUE" then
    peso("STRENGTH",0.5); peso("AGILITY",1.4); pesos.DISTANCIA=0.1
    if rama=="Asesinato" then peso("CRIT_RATING",1.3)
    elseif rama=="Combate" then peso("HIT_RATING",1.3)
    else peso("STAMINA",0.9) end
  end
  equipo.pesos = pesos
  if perfil ~= "fisico" then equipo.dosManos=nil; equipo.dobleArma=nil end
  if clase=="WARRIOR" and rama=="Furia" then equipo.dosManos=nil; equipo.dobleArma=true end
  if (clase=="WARRIOR" and rama=="Armas") or (clase=="PALADIN" and rama=="Reprensión") then equipo.dosManos=true; equipo.dobleArma=nil end
  if clase=="ROGUE" then equipo.dobleArma=true; equipo.dosManos=nil end
  -- No se presupone aprendizaje de doble empuñadura del chamán en Forever.
  R.equipo=equipo
end

-- Aplica la especialización guardada a la ruta cargada (al iniciar y al elegir).
function GL.AplicarEspecializacion(R)
  R = R or GL.RUTA
  if not R then return end
  GuardarGuia(R)
  local elegida = DB().especializacion
  local e
  for _, x in ipairs(Lista()) do if x.rama == elegida then e = x end end
  GL.AplicarEquipoEspecializacion(R, Clase(), e and e.rama, not e or EsDeLaGuia(e))
  if not e or EsDeLaGuia(e) or not e.plan then
    R.talentos, R.talentosIntro, R.planFlexible = guia.talentos, guia.intro, nil
    return
  end
  R.talentos = Plan(e, R)
  R.talentosIntro = L(e.rama) .. ": " .. L(e.texto) .. " " ..
    L"La guía pone sola los talentos clave que encuentre en tu árbol; los que Forever haya cambiado te los dice para que los pongas a mano. El botón Especialización la cambia."
  R.planFlexible = true
end

------------------------------------------------------------------------
-- Ventana para elegir
------------------------------------------------------------------------
local function Estrellas(n) return GL.Simbolos(string.rep("★", n) .. "|cff555555" .. string.rep("★", 3 - n) .. "|r") end

local RamaMayoritaria   -- 9.7.7.1, más abajo

local function Elegir(e)
  DB().especializacion = e.rama
  -- 9.7.7.1: si eliges a mano otra rama que la de tus puntos, la guía no te la vuelve a cambiar por esos puntos
  DB().especializacionIgnorar = RamaMayoritaria and RamaMayoritaria() or nil
  GL.AplicarEspecializacion()
  GL.Mensaje(L"especialización elegida: " .. L(e.rama) .. (EsDeLaGuia(e) and L" (la de la guía)" or "") .. ".")
  if GL.ventanaEspecializacion then GL.ventanaEspecializacion:Hide() end
  if GL.Refrescar then GL.Refrescar() end
  if GL.PonerTalentos and GL.AutoTalentos and GL.AutoTalentos() and C_Timer then C_Timer.After(1, function() pcall(GL.PonerTalentos, false) end) end
end

function GL.AbrirEspecializacion()
  if not GL.RUTA then return end
  GuardarGuia(GL.RUTA)
  local v = GL.VentanaLista("especializacion", L"Elige tu especialización", 460, 300)
  GL.ventanaEspecializacion = v
  local filas = {}
  local elegida = DB().especializacion
  for _, e in ipairs(Lista()) do
    local deGuia = EsDeLaGuia(e)
    table.insert(filas, {
      texto = L(e.rama) .. "  " .. Estrellas(e.ritmo) .. (deGuia and (C.VERDE .. L"  Recomendada: la que más rápido sube" .. C.FIN) or ""),
      detalle = L(e.rol) .. " · " .. L(e.texto),
      boton = (elegida == e.rama) and L"Elegida" or L"Elegir",
      hecha = elegida == e.rama,
      accion = function() Elegir(e) end,
      ayudaTitulo = L(e.rama), ayudaTexto = L(e.texto) .. (deGuia and ("\n\n" .. L"Usa el plan de talentos de tu ruta, comprobado en Forever.") or
        ("\n\n" .. L"La guía pone sola los talentos clave que encuentre en tu árbol; los que Forever haya cambiado te los dice para que los pongas a mano.")),
    })
  end
  v.lista:Poner(filas, C.GRIS .. L"¿Qué especialización quieres? La recomendada es la que más rápido sube. Los talentos se ponen solos con cualquiera." .. C.FIN)
  v:Show()
end

GL.comandos = GL.comandos or {}
GL.comandos["especializacion"] = function() GL.AbrirEspecializacion() end
GL.comandos["especialización"] = GL.comandos["especializacion"]

-- Pregunta al llegar al 10 (primer talento); a quien ya pasó del 12 sin elegir no se le pregunta: sigue la de la guía.
local function Preguntar()
  local db = DB()
  if db.especializacion or not GL.RUTA or #Lista() == 0 then return end
  local n = Nivel()
  if n < 10 then return end
  if n > 12 then
    for _, e in ipairs(Lista()) do if EsDeLaGuia(e) then db.especializacion = e.rama end end
    return
  end
  GL.AbrirEspecializacion()
end

------------------------------------------------------------------------
-- 9.7.7.1: la especialización sale de tu árbol. Si casi todos tus puntos están en otra rama que la del plan
-- (por ejemplo Furia con el plan de Armas), la guía pasa a esa especialización y lo dice en el chat.
------------------------------------------------------------------------
RamaMayoritaria = function()
  local real = GL.PuntosRealesPorRama and GL.PuntosRealesPorRama()
  if not real or (real.total or 0) < 5 then return nil end
  local mejor
  for r, n in pairs(real.ramas or {}) do if not mejor or n > real.ramas[mejor] then mejor = r end end
  if not mejor or real.ramas[mejor] < real.total * 0.6 then return nil end   -- repartidos: no se decide
  return mejor, real
end

-- Puntos que el plan en uso pone en cada rama hasta un número de puntos.
local function PlanHasta(puntos)
  local ramas, n = {}, 0
  for _, t in ipairs((GL.RUTA and GL.RUTA.talentos) or {}) do
    local desde, hasta = tonumber(t.d) or 10, tonumber(t.h) or 10
    for _ = desde, hasta do
      if n >= puntos then return ramas end
      n = n + 1
      if t.rama then ramas[t.rama] = (ramas[t.rama] or 0) + 1 end
    end
  end
  return ramas
end

function GL.ComprobarEspecializacionReal()
  if type(GuiaAventureroDB) ~= "table" or not GL.RUTA or #Lista() == 0 then return end
  GuardarGuia(GL.RUTA)
  local db = DB()
  local mejor, real = RamaMayoritaria()
  if not mejor or mejor == db.especializacionIgnorar then return end
  local plan = PlanHasta(real.total)
  local enPlan = 0
  for _, n in pairs(plan) do enPlan = enPlan + n end
  if enPlan > 0 and (plan[mejor] or 0) >= enPlan * 0.6 then return end   -- el plan en uso ya va por esa rama
  for _, e in ipairs(Lista()) do
    if L(e.rama) == mejor and e.rama ~= db.especializacion and (e.plan or EsDeLaGuia(e)) then
      db.especializacion = e.rama
      db.especializacionIgnorar = nil
      GL.AplicarEspecializacion()
      GL.Mensaje(L"tus talentos están en " .. L(e.rama) .. L": la guía sigue ahora esa especialización. La cambias con el botón Especialización.")
      if GL.Refrescar then pcall(GL.Refrescar) end
      return e.rama
    end
  end
end

table.insert(GL.alIniciar, function()
  GL.AplicarEspecializacion(GL.RUTA)
  if C_Timer then
    C_Timer.After(6, Preguntar)
    C_Timer.After(7, function() pcall(GL.ComprobarEspecializacionReal) end)
  end
end)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, _, nivel)
  if tonumber(nivel) == 10 and C_Timer then C_Timer.After(1, Preguntar) end
end)

-- Para Talentos.lua: con una especialización que no es la de la guía, no se pone nada hasta que la elijas al 10
function GL.EspecializacionPendiente()
  return DB().especializacion == nil and Nivel() >= 10 and Nivel() <= 12 and #Lista() > 0
end

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
    -- B01: four independent leveling plans, client data published 26/11/2026.
    -- Distinct spec keys, same real Feral Combat tree. Spanish labels provisional.
    { rama = "Equilibrio", arbol = "Equilibrio", nombreEN = "Balance", rol = "Daño a distancia", rolEN = "Ranged damage", ritmo = 2, texto = "Leveo a distancia con Cólera, Fuegolunar, Enjambre de insectos y Eclipse. Forma de lechúcico lunar al 40; Estado de sueño después para apoyar al grupo.", textoEN = "Ranged leveling with Wrath, Moonfire, Insect Swarm and Eclipse. Moonkin Form at 40; Dreamstate later for group support.",
      plan = {
        { "Cólera estelar (Starlight Wrath)", 5, "Equilibrio", 1, 5 },
        { "Brillo lunar (Moonglow)", 3, "Equilibrio", 2, 3 },
        { "Luna y estrellas (Moon and Stars)", 2, "Equilibrio", 2, 2 },
        { "Majestad de la naturaleza (Nature's Majesty)", 2, "Equilibrio", 2, 2 },
        { "Alcance de la naturaleza (Nature's Reach)", 2, "Equilibrio", 2, 2 },
        { "Esplendor de la naturaleza (Nature's Splendor)", 1, "Equilibrio", 3, 1 },
        { "Enjambre de insectos (Insect Swarm)", 1, "Equilibrio", 4, 1 },
        { "Venganza (Vengeance)", 5, "Equilibrio", 4, 5 },
        { "Gracia de la naturaleza (Nature's Grace)", 1, "Equilibrio", 5, 1 },
        { "Eclipse (Eclipse)", 3, "Equilibrio", 5, 3 },
        { "Génesis (Genesis)", 5, "Equilibrio", 1, 5 },
        { "Forma de lechúcico lunar (Moonkin Form)", 1, "Equilibrio", 7, 1 },
        { "Estado de sueño (Dreamstate)", 5, "Equilibrio", 6, 5 },
        { "Corazón de lo Salvaje (Heart of the Wild)", 5, "Restauración", 1, 5 },
        { "Naturalista (Naturalist)", 5, "Restauración", 2, 5 },
        { "Reflejo (Reflection)", 3, "Restauración", 2, 3 },
        { "Cambio de forma natural (Natural Shapeshifter)", 2, "Restauración", 2, 3 },
      } },
    { rama = "Feral (gato)", arbol = "Combate feral", nombreEN = "Feral (cat)", rol = "Daño cuerpo a cuerpo", rolEN = "Melee damage", ritmo = 3, texto = "Leveo individual con movilidad en forma felina, sangrados y puntos de combo. Poder cambiante al 40; después, daño y ahorro de maná al cambiar de forma.", textoEN = "Solo leveling with Cat Form mobility, bleeds and combo points. Shifting Power at 40; then damage and shapeshifting mana efficiency.",
      plan = {
        { "Ferocidad (Ferocity)", 5, "Combate feral", 1, 5 },
        { "Presteza feral (Feral Swiftness)", 2, "Combate feral", 2, 2 },
        { "Furor (Furor)", 3, "Combate feral", 1, 5 },
        { "Ataques trituradores (Shredding Attacks)", 3, "Combate feral", 3, 3 },
        { "Furia salvaje (Savage Fury)", 2, "Combate feral", 3, 2 },
        { "Golpes depredadores (Predatory Strikes)", 3, "Combate feral", 4, 3 },
        { "Garras afiladas (Sharpened Claws)", 2, "Combate feral", 3, 2 },
        { "Disciplina depredadora (Predatory Discipline)", 1, "Combate feral", 4, 1 },
        { "Frenesí sangriento (Blood Frenzy)", 2, "Combate feral", 4, 2 },
        { "Líder de la manada (Leader of the Pack)", 1, "Combate feral", 5, 1 },
        { "Instinto natural (Natural Instinct)", 1, "Combate feral", 5, 2 },
        { "Desgarrar y rasgar (Rend and Tear)", 5, "Combate feral", 6, 5 },
        { "Poder cambiante (Shifting Power)", 1, "Combate feral", 7, 1 },
        { "Furor (Furor)", 5, "Combate feral", 1, 5 },
        { "Instinto natural (Natural Instinct)", 2, "Combate feral", 5, 2 },
        { "Instinto feral (Feral Instinct)", 3, "Combate feral", 2, 3 },
        { "Corazón de lo Salvaje (Heart of the Wild)", 5, "Restauración", 1, 5 },
        { "Naturalista (Naturalist)", 5, "Restauración", 2, 5 },
        { "Cambio de forma natural (Natural Shapeshifter)", 3, "Restauración", 2, 3 },
        { "Enfoque de la naturaleza (Nature's Focus)", 1, "Restauración", 1, 5 },
      } },
    { rama = "Feral (oso)", arbol = "Combate feral", nombreEN = "Feral (bear)", rol = "Tanque", rolEN = "Tank", ritmo = 2, texto = "Tanque de mazmorras en forma de oso: armadura, Lacerar, Carga feral y Reacción natural. Mordisco primigenio al 40; refuerza después el aguante.", textoEN = "Dungeon tank in Bear Form: armor, Lacerate, Feral Charge and Natural Reaction. Primal Bite at 40; strengthen Stamina afterwards.",
      plan = {
        { "Ferocidad (Ferocity)", 5, "Combate feral", 1, 5 },
        { "Pellejo grueso (Thick Hide)", 3, "Combate feral", 2, 3 },
        { "Instinto feral (Feral Instinct)", 2, "Combate feral", 2, 3 },
        { "Furia salvaje (Savage Fury)", 2, "Combate feral", 3, 2 },
        { "Garras afiladas (Sharpened Claws)", 2, "Combate feral", 3, 2 },
        { "Carga feral (Feral Charge)", 1, "Combate feral", 3, 1 },
        { "Lacerar (Lacerate)", 1, "Combate feral", 4, 1 },
        { "Golpes depredadores (Predatory Strikes)", 3, "Combate feral", 4, 3 },
        { "Instinto feral (Feral Instinct)", 3, "Combate feral", 2, 3 },
        { "Líder de la manada (Leader of the Pack)", 1, "Combate feral", 5, 1 },
        { "Instinto natural (Natural Instinct)", 2, "Combate feral", 5, 2 },
        { "Frenesí sangriento (Blood Frenzy)", 2, "Combate feral", 4, 2 },
        { "Reacción natural (Natural Reaction)", 5, "Combate feral", 6, 5 },
        { "Mordisco primigenio (Primal Bite)", 1, "Combate feral", 7, 1 },
        { "Corazón de lo Salvaje (Heart of the Wild)", 5, "Restauración", 1, 5 },
        { "Naturalista (Naturalist)", 5, "Restauración", 2, 5 },
        { "Desgarrar y rasgar (Rend and Tear)", 5, "Combate feral", 6, 5 },
        { "Furor (Furor)", 5, "Combate feral", 1, 5 },
      } },
    { rama = "Restauración", arbol = "Restauración", nombreEN = "Restoration", rol = "Sanación", rolEN = "Healing", ritmo = 1, texto = "Sanación de grupo con Alivio presto, Presteza de la naturaleza y Crecimiento salvaje al 40. Completa con daño de Equilibrio para misiones.", textoEN = "Group healing with Swiftmend, Nature’s Swiftness and Wild Growth at 40. Add Balance damage for quests.",
      plan = {
        { "Corazón de lo Salvaje (Heart of the Wild)", 5, "Restauración", 1, 5 },
        { "Naturalista (Naturalist)", 5, "Restauración", 2, 5 },
        { "Reflejo (Reflection)", 3, "Restauración", 2, 3 },
        { "Don de la naturaleza (Gift of Nature)", 2, "Restauración", 3, 5 },
        { "Alivio presto (Swiftmend)", 1, "Restauración", 4, 1 },
        { "Rejuvenecimiento mejorado (Improved Rejuvenation)", 3, "Restauración", 4, 3 },
        { "Floración (Bloom)", 1, "Restauración", 3, 1 },
        { "Espíritu vivo (Living Spirit)", 3, "Restauración", 5, 3 },
        { "Presteza de la naturaleza (Nature's Swiftness)", 1, "Restauración", 5, 1 },
        { "Don de la naturaleza (Gift of Nature)", 3, "Restauración", 3, 5 },
        { "Recrecimiento mejorado (Improved Regrowth)", 5, "Restauración", 6, 5 },
        { "Crecimiento salvaje (Wild Growth)", 1, "Restauración", 7, 1 },
        { "Don de la naturaleza (Gift of Nature)", 5, "Restauración", 3, 5 },
        { "Sutileza (Subtlety)", 3, "Restauración", 3, 3 },
        { "Cólera estelar (Starlight Wrath)", 5, "Equilibrio", 1, 5 },
        { "Génesis (Genesis)", 5, "Equilibrio", 1, 5 },
        { "Brillo lunar (Moonglow)", 3, "Equilibrio", 2, 3 },
        { "Alcance de la naturaleza (Nature's Reach)", 2, "Equilibrio", 2, 2 },
      } },
  },
  HUNTER = {
    -- Auditoría Cazador B01: TalentsForever 71139 (25/11/2026), hotfixes de 3 y 10/11.
    -- Planes orientativos de 51 puntos (sin ventaja Talented); etiquetas ES nuevas pendientes de cotejo en cliente.
    { rama = "Bestias", rol = "Daño a distancia con mascota", ritmo = 3, texto = "Leveo con mascota: potencia su daño y aguante, e incorpora Invocar halcón y Cólera de las bestias.",
      plan = {
        { "Aspectos letales (Deadly Aspects)", 5, "Bestias", 1, 5 },
        { "Fuego enfocado (Focused Fire)", 2, "Bestias", 2, 2 },
        { "Revivir mascota mejorado (Improved Revive Pet)", 2, "Bestias", 2, 2 },
        { "Entrenamiento de robustez (Endurance Training)", 1, "Bestias", 1, 5 },
        { "Furia desatada (Unleashed Fury)", 5, "Bestias", 3, 5 },
        { "Presteza bestial (Bestial Swiftness)", 1, "Bestias", 3, 1 },
        { "Ferocidad (Ferocity)", 5, "Bestias", 4, 5 },
        { "Invocar halcón (Summon Hawk)", 1, "Bestias", 4, 1 },
        { "Intimidación (Intimidation)", 1, "Bestias", 5, 1 },
        { "Disciplina bestial (Bestial Discipline)", 2, "Bestias", 5, 2 },
        { "Frenesí (Frenzy)", 5, "Bestias", 6, 5 },
        { "Cólera de las bestias (Bestial Wrath)", 1, "Bestias", 7, 1 },
        { "Ataques letales (Lethal Attacks)", 5, "Puntería", 1, 5 },
        { "Ojo de halcón (Hawk Eye)", 3, "Puntería", 1, 3 },
        { "Afinar la puntería (Careful Aim)", 5, "Puntería", 2, 5 },
        { "Matanza rápida (Rapid Killing)", 2, "Puntería", 3, 2 },
        { "Aura de disparo certero (Trueshot Aura)", 1, "Puntería", 4, 1 },
        { "Disparos mortales (Mortal Shots)", 4, "Puntería", 4, 5 },
      } },
    { rama = "Puntería", rol = "Daño a distancia", ritmo = 2, texto = "Leveo a distancia con mascota: disparos, gestión de maná y Disparo de francotirador.",
      plan = {
        { "Ataques letales (Lethal Attacks)", 5, "Puntería", 1, 5 },
        { "Ojo de halcón (Hawk Eye)", 3, "Puntería", 1, 3 },
        { "Afinar la puntería (Careful Aim)", 5, "Puntería", 2, 5 },
        { "Matanza rápida (Rapid Killing)", 2, "Puntería", 3, 2 },
        { "Aura de disparo certero (Trueshot Aura)", 1, "Puntería", 4, 1 },
        { "Disparos mortales (Mortal Shots)", 4, "Puntería", 4, 5 },
        { "Recuperación rápida (Rapid Recuperation)", 2, "Puntería", 5, 2 },
        { "Tromba (Barrage)", 3, "Puntería", 5, 3 },
        { "Especialización en armas a distancia (Ranged Weapon Specialization)", 5, "Puntería", 6, 5 },
        { "Disparo de francotirador (Sniper Shot)", 1, "Puntería", 7, 1 },
        { "Aspectos letales (Deadly Aspects)", 5, "Bestias", 1, 5 },
        { "Entrenamiento de robustez (Endurance Training)", 5, "Bestias", 1, 5 },
        { "Fuego enfocado (Focused Fire)", 2, "Bestias", 2, 2 },
        { "Revivir mascota mejorado (Improved Revive Pet)", 2, "Bestias", 2, 2 },
        { "Presteza bestial (Bestial Swiftness)", 1, "Bestias", 3, 1 },
        { "Furia desatada (Unleashed Fury)", 5, "Bestias", 3, 5 },
      } },
    { rama = "Supervivencia", rol = "Daño cuerpo a cuerpo y control", ritmo = 2, texto = "Leveo cuerpo a cuerpo con mascota: rastreo, trampas, Mordedura de mangosta y Golpes lacerantes.",
      plan = {
        { "Rastreo mejorado (Improved Tracking)", 5, "Supervivencia", 1, 5 },
        { "Golpes salvajes (Savage Strikes)", 2, "Supervivencia", 2, 2 },
        { "Superviviente (Survivalist)", 3, "Supervivencia", 2, 5 },
        { "Disuasión (Deterrence)", 1, "Supervivencia", 3, 1 },
        { "Paso firme (Surefooted)", 3, "Supervivencia", 3, 3 },
        { "Superviviente (Survivalist)", 4, "Supervivencia", 2, 5 },
        { "Filo del depredador (Predator's Edge)", 5, "Supervivencia", 4, 5 },
        { "Exponer presa (Expose Prey)", 2, "Supervivencia", 5, 2 },
        { "Ingenio (Resourcefulness)", 2, "Supervivencia", 5, 2 },
        { "Disciplina del superviviente (Survivalist's Discipline)", 1, "Supervivencia", 5, 2 },
        { "Reflejos relámpago (Lightning Reflexes)", 5, "Supervivencia", 6, 5 },
        { "Golpes lacerantes (Lacerating Strikes)", 1, "Supervivencia", 7, 1 },
        { "Aspectos letales (Deadly Aspects)", 5, "Bestias", 1, 5 },
        { "Ataques letales (Lethal Attacks)", 5, "Puntería", 1, 5 },
        { "Ojo de halcón (Hawk Eye)", 3, "Puntería", 1, 3 },
        { "Afinar la puntería (Careful Aim)", 5, "Puntería", 2, 5 },
        { "Matanza rápida (Rapid Killing)", 2, "Puntería", 3, 2 },
      } },
  },
  MAGE = {
    -- B01: tres planes de 51 puntos, datos Playfulls 25/11/2026 y ForeverWoW.es (70755).
    -- Progresión estándar sin Talented; nombres ES de referencia, pendientes de cotejo en cliente.
    { rama = "Escarcha", rol = "Daño a distancia y control", ritmo = 3, texto = "Leveo individual con control, Lanza de hielo contra objetivos congelados, Bloqueo de hielo y Barrera de hielo. Después, ahorro de maná en Arcano.", textoEN = "Solo leveling with control, Ice Lance against frozen targets, Ice Block and Ice Barrier. Then Arcane mana efficiency.",
      plan = {
        { "Precisión (Precision)", 3, "Escarcha", 1, 3 },
        { "Descarga de Escarcha mejorada (Improved Frostbolt)", 5, "Escarcha", 1, 5 },
        { "Fragmentos de hielo (Ice Shards)", 2, "Escarcha", 2, 5 },
        { "Lanza de hielo (Ice Lance)", 1, "Escarcha", 3, 1 },
        { "Fragmentos de hielo (Ice Shards)", 5, "Escarcha", 2, 5 },
        { "Canalización de Escarcha (Frost Channeling)", 1, "Escarcha", 3, 3 },
        { "Trizar (Shatter)", 3, "Escarcha", 4, 3 },
        { "Bloqueo de hielo (Ice Block)", 1, "Escarcha", 4, 1 },
        { "Alcance ártico (Arctic Reach)", 1, "Escarcha", 4, 2 },
        { "Mordedura helada (Cold Snap)", 1, "Escarcha", 5, 1 },
        { "Dedos de Escarcha (Fingers of Frost)", 2, "Escarcha", 5, 2 },
        { "Canalización de Escarcha (Frost Channeling)", 3, "Escarcha", 3, 3 },
        { "Escalofrío del invierno (Winter's Chill)", 5, "Escarcha", 6, 5 },
        { "Barrera de hielo (Ice Barrier)", 1, "Escarcha", 7, 1 },
        { "Alcance ártico (Arctic Reach)", 2, "Escarcha", 4, 2 },
        { "Custodia de Escarcha (Frost Warding)", 1, "Escarcha", 1, 2 },
        { "Canalización mejorada (Improved Channeling)", 5, "Arcano", 1, 5 },
        { "Concentración Arcana (Arcane Concentration)", 5, "Arcano", 2, 5 },
        { "Tromba de misiles (Missile Barrage)", 2, "Arcano", 2, 2 },
        { "Sutileza Arcana (Arcane Subtlety)", 2, "Arcano", 2, 2 },
        { "Absorción mágica (Magic Absorption)", 1, "Arcano", 2, 2 },
        { "Meditación Arcana (Arcane Meditation)", 3, "Arcano", 4, 3 },
      } },
    { rama = "Arcano", rol = "Daño a distancia", ritmo = 2, texto = "Daño arcano con Tromba de misiles, Explosión y Cólera Arcana; controla las acumulaciones y el gasto de maná.", textoEN = "Arcane damage with Missile Barrage, Arcane Blast and Arcane Wrath; manage stacks and mana expenditure.",
      plan = {
        { "Canalización mejorada (Improved Channeling)", 5, "Arcano", 1, 5 },
        { "Concentración Arcana (Arcane Concentration)", 5, "Arcano", 2, 5 },
        { "Explosión Arcana (Arcane Blast)", 1, "Arcano", 3, 1 },
        { "Tromba de misiles (Missile Barrage)", 2, "Arcano", 2, 2 },
        { "Impacto Arcano (Arcane Impact)", 2, "Arcano", 3, 3 },
        { "Cólera Arcana (Arcane Wrath)", 1, "Arcano", 4, 1 },
        { "Meditación Arcana (Arcane Meditation)", 3, "Arcano", 4, 3 },
        { "Impacto Arcano (Arcane Impact)", 3, "Arcano", 3, 3 },
        { "Presencia mental (Presence of Mind)", 1, "Arcano", 5, 1 },
        { "Mente Arcana (Arcane Mind)", 4, "Arcano", 5, 5 },
        { "Inestabilidad Arcana (Arcane Instability)", 3, "Arcano", 6, 3 },
        { "Mente Arcana (Arcane Mind)", 5, "Arcano", 5, 5 },
        { "Geometría Arcana (Arcane Geometry)", 1, "Arcano", 3, 2 },
        { "Poder Arcano (Arcane Power)", 1, "Arcano", 7, 1 },
        { "Precisión (Precision)", 3, "Escarcha", 1, 3 },
        { "Acelerante (Accelerant)", 5, "Fuego", 1, 5 },
        { "Incineración (Incineration)", 5, "Fuego", 1, 5 },
        { "Geometría Arcana (Arcane Geometry)", 2, "Arcano", 3, 2 },
        { "Sutileza Arcana (Arcane Subtlety)", 2, "Arcano", 2, 2 },
        { "Absorción mágica (Magic Absorption)", 2, "Arcano", 2, 2 },
        { "Protección Arcana (Arcane Shielding)", 2, "Arcano", 4, 2 },
      } },
    { rama = "Fuego", rol = "Daño a distancia", ritmo = 2, texto = "Daño de Fuego con Bola de Fuego, Piroexplosión y Calentamiento; complementa con regeneración de maná.", textoEN = "Fire damage with Fireball, Pyroblast and Heating Up; add mana regeneration.",
      plan = {
        { "Acelerante (Accelerant)", 5, "Fuego", 1, 5 },
        { "Ignición (Ignite)", 5, "Fuego", 2, 5 },
        { "Piroexplosión (Pyroblast)", 1, "Fuego", 3, 1 },
        { "Lanzallamas (Flame Throwing)", 2, "Fuego", 2, 2 },
        { "Impacto (Impact)", 2, "Fuego", 2, 3 },
        { "Calentamiento (Heating Up)", 1, "Fuego", 4, 1 },
        { "Chamuscar mejorado (Improved Scorch)", 3, "Fuego", 4, 3 },
        { "Maestro de los elementos (Master of Elements)", 3, "Fuego", 4, 3 },
        { "Masa crítica (Critical Mass)", 3, "Fuego", 5, 3 },
        { "Ola explosiva (Blast Wave)", 1, "Fuego", 5, 1 },
        { "Poder de Fuego (Fire Power)", 3, "Fuego", 6, 3 },
        { "Alma ardiente (Burning Soul)", 1, "Fuego", 3, 3 },
        { "Combustión (Combustion)", 1, "Fuego", 7, 1 },
        { "Precisión (Precision)", 3, "Escarcha", 1, 3 },
        { "Especialización en varitas (Wand Specialization)", 2, "Arcano", 1, 2 },
        { "Canalización mejorada (Improved Channeling)", 3, "Arcano", 1, 5 },
        { "Concentración Arcana (Arcane Concentration)", 5, "Arcano", 2, 5 },
        { "Tromba de misiles (Missile Barrage)", 2, "Arcano", 2, 2 },
        { "Sutileza Arcana (Arcane Subtlety)", 2, "Arcano", 2, 2 },
        { "Explosión Arcana (Arcane Blast)", 1, "Arcano", 3, 1 },
        { "Meditación Arcana (Arcane Meditation)", 2, "Arcano", 4, 3 },
      } },
  },
  PALADIN = {
    -- Auditoría B02: Forever 1.60.1.71139; nombres ES cotejados con talentsforever.com/es/paladin (70959) y ForeverWoW.es; validar en cliente actual.
    { rama = "Reprensión", rol = "Daño cuerpo a cuerpo", ritmo = 3, texto = "Leveo con arma de dos manos: sellos, sentencias, daño y ahorro de maná.",
      plan = {
        { "Oración (Benediction)", 5, "Reprensión", 1, 5 },
        { "Sentencia mejorada (Improved Judgement)", 2, "Reprensión", 2, 2 },
        { "Sentencia santificada (Sanctified Judgement)", 3, "Reprensión", 2, 3 },
        { "Sello de orden (Seal of Command)", 1, "Reprensión", 3, 1 },
        { "Búsqueda de justicia (Pursuit of Justice)", 2, "Reprensión", 3, 2 },
        { "Convicción (Conviction)", 2, "Reprensión", 2, 3 },
        { "Enjuiciador Sagrado (Sacred Arbiter)", 1, "Reprensión", 4, 1 },
        { "Especialización en armas de dos manos (Two-Handed Weapon Specialization)", 3, "Reprensión", 4, 3 },
        { "Convicción (Conviction)", 3, "Reprensión", 2, 3 },
        { "Arrepentimiento (Repentance)", 1, "Reprensión", 5, 1 },
        { "Venganza (Vengeance)", 3, "Reprensión", 5, 3 },
        { "Reivindicación (Vindication)", 1, "Reprensión", 3, 3 },
        { "Campeón de la Luz (Champion of the Light)", 5, "Reprensión", 6, 5 },
        { "Cólera desellada (Unsealed Wrath)", 1, "Reprensión", 7, 1 },
        { "Enfoque espiritual (Spiritual Focus)", 5, "Sagrado", 1, 5 },
        { "Sellos mejorados (Improved Seals)", 5, "Sagrado", 2, 5 },
        { "Intelecto divino (Divine Intellect)", 5, "Protección", 1, 5 },
        { "Precisión (Precision)", 3, "Protección", 2, 3 },
        { "Desvío (Deflection)", 2, "Reprensión", 1, 5 },
      } },
    { rama = "Sagrado", rol = "Sanación", ritmo = 1, texto = "Leveo como sanador: prioriza curación y maná para mazmorras, con apoyo de daño para misiones.",
      plan = {
        { "Enfoque espiritual (Spiritual Focus)", 5, "Sagrado", 1, 5 },
        { "Luz curativa (Healing Light)", 3, "Sagrado", 2, 3 },
        { "Reverencia (Reverence)", 2, "Sagrado", 2, 2 },
        { "Favor divino (Divine Favor)", 1, "Sagrado", 3, 1 },
        { "Iluminación (Illumination)", 5, "Sagrado", 3, 5 },
        { "Juramento de Luz (Oath of Light)", 1, "Sagrado", 4, 1 },
        { "Infusión de Luz (Infusion of Light)", 2, "Sagrado", 4, 2 },
        { "Conducto sagrado (Holy Conduit)", 1, "Sagrado", 3, 2 },
        { "Choque sagrado (Holy Shock)", 1, "Sagrado", 5, 1 },
        { "Luz sin límites (Boundless Light)", 2, "Sagrado", 5, 2 },
        { "Conducto sagrado (Holy Conduit)", 2, "Sagrado", 3, 2 },
        { "Sellos mejorados (Improved Seals)", 1, "Sagrado", 2, 5 },
        { "Poder sagrado (Holy Power)", 5, "Sagrado", 6, 5 },
        { "Vigilia de la Luz (Light's Vigil)", 1, "Sagrado", 7, 1 },
        { "Intelecto divino (Divine Intellect)", 5, "Protección", 1, 5 },
        { "Oración (Benediction)", 5, "Reprensión", 1, 5 },
        { "Convicción (Conviction)", 3, "Reprensión", 2, 3 },
        { "Sentencia mejorada (Improved Judgement)", 2, "Reprensión", 2, 2 },
        { "Sentencia santificada (Sanctified Judgement)", 3, "Reprensión", 2, 3 },
        { "Sellos mejorados (Improved Seals)", 3, "Sagrado", 2, 5 },
      } },
    { rama = "Protección", rol = "Tanque", ritmo = 2, texto = "Leveo con escudo: bloqueo, amenaza, mitigación y recuperación de maná para mazmorras.",
      plan = {
        { "Baluarte (Redoubt)", 5, "Protección", 1, 5 },
        { "Precisión (Precision)", 3, "Protección", 2, 3 },
        { "Deber sagrado (Sacred Duty)", 2, "Protección", 2, 2 },
        { "Baluarte de templario (Templar's Bulwark)", 1, "Protección", 3, 1 },
        { "Especialización en escudos (Shield Specialization)", 2, "Protección", 3, 2 },
        { "Dureza (Toughness)", 2, "Protección", 3, 5 },
        { "Juicio presto (Swift Judgement)", 1, "Protección", 4, 1 },
        { "Furia justa mejorada (Improved Righteous Fury)", 3, "Protección", 4, 3 },
        { "Anticipación (Anticipation)", 1, "Protección", 4, 5 },
        { "Escudo sagrado (Holy Shield)", 1, "Protección", 5, 1 },
        { "La hora de la verdad (Reckoning)", 4, "Protección", 5, 5 },
        { "Credo férreo (Iron Creed)", 3, "Protección", 6, 3 },
        { "La hora de la verdad (Reckoning)", 5, "Protección", 5, 5 },
        { "Anticipación (Anticipation)", 2, "Protección", 4, 5 },
        { "Juramento de escudo (Shieldsworn)", 1, "Protección", 7, 1 },
        { "Dureza (Toughness)", 5, "Protección", 3, 5 },
        { "Anticipación (Anticipation)", 5, "Protección", 4, 5 },
        { "Desvío (Deflection)", 5, "Reprensión", 1, 5 },
        { "Oración (Benediction)", 5, "Reprensión", 1, 5 },
        { "Sentencia mejorada (Improved Judgement)", 2, "Reprensión", 2, 2 },
        { "Convicción (Conviction)", 2, "Reprensión", 2, 3 },
      } },
  },
  PRIEST = {
    -- B01: planes propios basados en los árboles de Forever tras los hotfixes del 18/11/2026.
    -- 51 puntos ordinarios; etiquetas ES de guía pendientes de cotejo con el cliente.
    { rama = "Sombra", rol = "Daño a distancia", ritmo = 3, texto = "Leveo en solitario: Golpe de espíritu para recuperar maná, Tortura mental y Forma de las Sombras. Sal de la forma para curar.",
      plan = {
        { "Golpe de espíritu (Spirit Tap)", 5, "Sombra", 1, 5 },
        { "Palabra de las Sombras: dolor mejorada (Improved Shadow Word: Pain)", 2, "Sombra", 2, 2 },
        { "Alcance de las Sombras (Shadow Reach)", 2, "Sombra", 2, 2 },
        { "Enfoque de las Sombras (Shadow Focus)", 1, "Sombra", 1, 5 },
        { "Tortura mental (Mind Flay)", 1, "Sombra", 3, 1 },
        { "Tortura mental mejorada (Improved Mind Flay)", 2, "Sombra", 3, 2 },
        { "Enfoque de las Sombras (Shadow Focus)", 5, "Sombra", 1, 5 },
        { "Abrazo vampírico (Vampiric Embrace)", 1, "Sombra", 4, 1 },
        { "Tejido de las Sombras (Shadow Weaving)", 3, "Sombra", 4, 3 },
        { "Contagio devorador (Devouring Contagion)", 2, "Sombra", 5, 2 },
        { "Silencio (Silence)", 1, "Sombra", 5, 1 },
        { "Explosión mental mejorada (Improved Mind Blast)", 1, "Sombra", 2, 5 },
        { "Oscuridad (Darkness)", 5, "Sombra", 6, 5 },
        { "Forma de las Sombras (Shadowform)", 1, "Sombra", 7, 1 },
        { "Muerte prematura (Early Demise)", 2, "Sombra", 6, 2 },
        { "Inspiración oscura (Dark Inspiration)", 4, "Sombra", 4, 5 },
        { "Especialización en varitas (Wand Specialization)", 2, "Disciplina", 1, 2 },
        { "Disciplinas gemelas (Twin Disciplines)", 5, "Disciplina", 1, 5 },
        { "Fuerza mental (Mental Strength)", 3, "Disciplina", 2, 5 },
        { "Enfoque interno (Inner Focus)", 1, "Disciplina", 3, 1 },
        { "Meditación (Meditation)", 3, "Disciplina", 3, 3 },
      } },
    { rama = "Sagrado", rol = "Sanación", ritmo = 1, texto = "Leveo en grupo: sanación eficiente, Espíritu de redención y Rezo de alivio; al final refuerza escudos y maná.",
      plan = {
        { "Especialización sagrada (Holy Specialization)", 5, "Sagrado", 1, 5 },
        { "Furia divina (Divine Fury)", 5, "Sagrado", 2, 5 },
        { "Nova sagrada (Holy Nova)", 1, "Sagrado", 3, 1 },
        { "Inspiración (Inspiration)", 3, "Sagrado", 3, 3 },
        { "Renovar mejorado (Improved Renew)", 1, "Sagrado", 1, 3 },
        { "Sanación mejorada (Improved Healing)", 3, "Sagrado", 4, 3 },
        { "Vínculo sagrado (Holy Binding)", 1, "Sagrado", 4, 1 },
        { "Alcance sagrado (Holy Reach)", 1, "Sagrado", 4, 2 },
        { "Espíritu de redención (Spirit of Redemption)", 1, "Sagrado", 5, 1 },
        { "Guía espiritual (Spiritual Guidance)", 4, "Sagrado", 5, 5 },
        { "Sanación espiritual (Spiritual Healing)", 3, "Sagrado", 6, 3 },
        { "Guía espiritual (Spiritual Guidance)", 5, "Sagrado", 5, 5 },
        { "Renovar mejorado (Improved Renew)", 2, "Sagrado", 1, 3 },
        { "Rezo de alivio (Prayer of Mending)", 1, "Sagrado", 7, 1 },
        { "Especialización en varitas (Wand Specialization)", 2, "Disciplina", 1, 2 },
        { "Disciplinas gemelas (Twin Disciplines)", 5, "Disciplina", 1, 5 },
        { "Fuerza mental (Mental Strength)", 3, "Disciplina", 2, 5 },
        { "Enfoque interno (Inner Focus)", 1, "Disciplina", 3, 1 },
        { "Palabra de poder: escudo mejorada (Improved Power Word: Shield)", 3, "Disciplina", 3, 3 },
        { "Meditación (Meditation)", 3, "Disciplina", 3, 3 },
        { "Agilidad mental (Mental Agility)", 2, "Disciplina", 3, 3 },
        { "Protección del alma (Soul Warding)", 1, "Disciplina", 4, 1 },
      } },
    { rama = "Disciplina", rol = "Sanación y escudos", ritmo = 2, texto = "Leveo mixto: varitas al principio, escudos, Penitencia para daño o sanación, e Infusión de poder.",
      plan = {
        { "Especialización en varitas (Wand Specialization)", 2, "Disciplina", 1, 2 },
        { "Disciplinas gemelas (Twin Disciplines)", 5, "Disciplina", 1, 5 },
        { "Fuerza mental (Mental Strength)", 3, "Disciplina", 2, 5 },
        { "Enfoque interno (Inner Focus)", 1, "Disciplina", 3, 1 },
        { "Palabra de poder: escudo mejorada (Improved Power Word: Shield)", 3, "Disciplina", 3, 3 },
        { "Meditación (Meditation)", 3, "Disciplina", 3, 3 },
        { "Agilidad mental (Mental Agility)", 2, "Disciplina", 3, 3 },
        { "Protección del alma (Soul Warding)", 1, "Disciplina", 4, 1 },
        { "Penitencia (Penance)", 1, "Disciplina", 5, 1 },
        { "Esperanza renovada (Renewed Hope)", 4, "Disciplina", 5, 5 },
        { "Égida divina (Divine Aegis)", 3, "Disciplina", 6, 3 },
        { "Esperanza renovada (Renewed Hope)", 5, "Disciplina", 5, 5 },
        { "Agilidad mental (Mental Agility)", 3, "Disciplina", 3, 3 },
        { "Infusión de poder (Power Infusion)", 1, "Disciplina", 7, 1 },
        { "Fuerza mental (Mental Strength)", 5, "Disciplina", 2, 5 },
        { "Especialización sagrada (Holy Specialization)", 5, "Sagrado", 1, 5 },
        { "Furia divina (Divine Fury)", 5, "Sagrado", 2, 5 },
        { "Nova sagrada (Holy Nova)", 1, "Sagrado", 3, 1 },
        { "Inspiración (Inspiration)", 3, "Sagrado", 3, 3 },
        { "Renovar mejorado (Improved Renew)", 1, "Sagrado", 1, 3 },
        { "Sanación mejorada (Improved Healing)", 3, "Sagrado", 4, 3 },
      } },
  },
  ROGUE = {
    -- Auditoría Pícaro B01: TalentsForever, árbol posterior al 3/11; contrastado con catálogo de 54 talentos.
    -- Planes propios orientativos de 51 puntos, no requieren reinicio. Etiquetas ES pendientes de cliente.
    { rama = "Combate", rol = "Daño cuerpo a cuerpo", ritmo = 3, texto = "Leveo con dos armas: Golpe siniestro, Respuesta, Aluvión de acero y Subidón de adrenalina.",
      plan = {
        { "Golpes eficientes (Efficient Strikes)", 2, "Combate", 1, 2 },
        { "Golpe de gracia (Coup de Grace)", 3, "Combate", 1, 3 },
        { "Precisión (Precision)", 3, "Combate", 2, 3 },
        { "Desvío (Deflection)", 3, "Combate", 2, 3 },
        { "Respuesta (Riposte)", 1, "Combate", 3, 1 },
        { "Compostura (Composure)", 2, "Combate", 3, 2 },
        { "Aguante (Endurance)", 1, "Combate", 3, 2 },
        { "Ejecución impecable (Flawless Execution)", 1, "Combate", 4, 1 },
        { "Agresión (Aggression)", 3, "Combate", 4, 3 },
        { "Pericia con armas (Weapon Expertise)", 1, "Combate", 4, 2 },
        { "Aluvión de acero (Blade Flurry)", 1, "Combate", 5, 1 },
        { "Especialización en doble empuñadura (Dual Wield Specialization)", 2, "Combate", 5, 2 },
        { "Cortar y tajar (Hack and Slash)", 2, "Combate", 5, 5 },
        { "Destello de acero (Flash of Steel)", 5, "Combate", 6, 5 },
        { "Subidón de adrenalina (Adrenaline Rush)", 1, "Combate", 7, 1 },
        { "Cortar y tajar (Hack and Slash)", 5, "Combate", 5, 5 },
        { "Pericia con armas (Weapon Expertise)", 2, "Combate", 4, 2 },
        { "Malicia (Malice)", 5, "Asesinato", 1, 5 },
        { "Despiadado (Ruthlessness)", 3, "Asesinato", 2, 3 },
        { "Hacer picadillo mejorado (Improved Slice and Dice)", 3, "Asesinato", 2, 3 },
        { "Vigor (Vigor)", 2, "Asesinato", 3, 2 },
        { "Salpicadura de sangre (Blood Splatter)", 1, "Asesinato", 3, 1 },
        { "Letalidad (Lethality)", 2, "Asesinato", 3, 2 },
      } },
    { rama = "Asesinato", rol = "Daño cuerpo a cuerpo", ritmo = 2, texto = "Leveo con dagas, venenos y críticos: culmina en Mutilar, que requiere dos dagas.",
      plan = {
        { "Malicia (Malice)", 5, "Asesinato", 1, 5 },
        { "Despiadado (Ruthlessness)", 3, "Asesinato", 2, 3 },
        { "Hacer picadillo mejorado (Improved Slice and Dice)", 3, "Asesinato", 2, 3 },
        { "Vigor (Vigor)", 2, "Asesinato", 3, 2 },
        { "Salpicadura de sangre (Blood Splatter)", 1, "Asesinato", 3, 1 },
        { "Letalidad (Lethality)", 2, "Asesinato", 3, 2 },
        { "Venenos viles (Vile Poisons)", 5, "Asesinato", 4, 5 },
        { "Sangre fría (Cold Blood)", 1, "Asesinato", 4, 1 },
        { "Veneno (Venom)", 1, "Asesinato", 5, 1 },
        { "Golpes implacables (Relentless Strikes)", 4, "Asesinato", 5, 5 },
        { "Sellar el destino (Seal Fate)", 3, "Asesinato", 6, 3 },
        { "Mutilar (Mutilate)", 1, "Asesinato", 7, 1 },
        { "Golpes eficientes (Efficient Strikes)", 2, "Combate", 1, 2 },
        { "Golpe de gracia (Coup de Grace)", 3, "Combate", 1, 3 },
        { "Precisión (Precision)", 3, "Combate", 2, 3 },
        { "Heridas punzantes (Puncturing Wounds)", 3, "Combate", 2, 3 },
        { "Desvío (Deflection)", 3, "Combate", 2, 3 },
        { "Compostura (Composure)", 1, "Combate", 3, 2 },
        { "Oportunidad (Opportunity)", 5, "Sutileza", 1, 5 },
      } },
    { rama = "Sutileza", rol = "Daño cuerpo a cuerpo", ritmo = 2, texto = "Leveo con sigilo, sangrados y control: Hemorragia, Preparación y Marca de muerte.",
      plan = {
        { "Oportunidad (Opportunity)", 5, "Sutileza", 1, 5 },
        { "Emboscada mejorada (Improved Ambush)", 3, "Sutileza", 2, 3 },
        { "Malas artes (Dirty Deeds)", 2, "Sutileza", 2, 2 },
        { "Hojas serradas (Serrated Blades)", 3, "Sutileza", 3, 3 },
        { "Iniciativa (Initiative)", 3, "Sutileza", 3, 3 },
        { "Premeditación (Premeditation)", 1, "Sutileza", 3, 1 },
        { "Golpe fantasmal (Ghostly Strike)", 1, "Sutileza", 4, 1 },
        { "Elusión (Elusiveness)", 2, "Sutileza", 4, 2 },
        { "Preparación (Preparation)", 1, "Sutileza", 5, 1 },
        { "Hemorragia (Hemorrhage)", 1, "Sutileza", 5, 1 },
        { "Camuflaje (Camouflage)", 3, "Sutileza", 2, 3 },
        { "Cuchillo de bota (Boot Knife)", 5, "Sutileza", 6, 5 },
        { "Marca de muerte (Death Mark)", 1, "Sutileza", 7, 1 },
        { "Golpes eficientes (Efficient Strikes)", 2, "Combate", 1, 2 },
        { "Golpe de gracia (Coup de Grace)", 3, "Combate", 1, 3 },
        { "Precisión (Precision)", 3, "Combate", 2, 3 },
        { "Desvío (Deflection)", 2, "Combate", 2, 3 },
        { "Malicia (Malice)", 5, "Asesinato", 1, 5 },
        { "Despiadado (Ruthlessness)", 3, "Asesinato", 2, 3 },
        { "Hacer picadillo mejorado (Improved Slice and Dice)", 2, "Asesinato", 2, 3 },
      } },
  },
  SHAMAN = {
    -- B01: planes propios de 51 puntos, TalentsForever (hotfixes 3 y 10/11), comprobación 26/11/2026.
    -- Solo tres roles respaldados: Elemental, Mejora DPS y Restauración. Nombres ES pendientes de cliente.
    { rama = "Mejora", rol = "Daño cuerpo a cuerpo", ritmo = 3, texto = "Arma de dos manos; Muerdepiedras al inicio y Viento furioso desde el 30. Prioriza Golpe de tormenta, movilidad y maná.", textoEN = "Two-handed weapon; Rockbiter early and Windfury from 30. Prioritize Stormstrike, mobility and mana.",
      plan = {
        { "Golpes de trueno (Thundering Strikes)", 5, "Mejora", 1, 5 },
        { "Conocimiento ancestral (Ancestral Knowledge)", 2, "Mejora", 1, 5 },
        { "Maña mental (Mental Dexterity)", 3, "Mejora", 2, 3 },
        { "Enfoque chamánico (Shamanistic Focus)", 1, "Mejora", 3, 1 },
        { "Armas elementales (Elemental Weapons)", 3, "Mejora", 3, 3 },
        { "Anticipación (Anticipation)", 1, "Mejora", 3, 3 },
        { "Golpe de tormenta (Stormstrike)", 1, "Mejora", 4, 1 },
        { "Lobo fantasmal mejorado (Improved Ghost Wolf)", 2, "Mejora", 4, 2 },
        { "Aluvión (Flurry)", 2, "Mejora", 4, 5 },
        { "Golpe de tormenta mejorado (Improved Stormstrike)", 2, "Mejora", 5, 2 },
        { "Presura mental (Mental Quickness)", 2, "Mejora", 5, 2 },
        { "Armas de espíritu (Spirit Weapons)", 1, "Mejora", 5, 1 },
        { "Arma vorágine (Maelstrom Weapon)", 5, "Mejora", 6, 5 },
        { "Ira del clarividente (Rage of the Farseer)", 1, "Mejora", 7, 1 },
        { "Aluvión (Flurry)", 5, "Mejora", 4, 5 },
        { "Concusión (Concussion)", 5, "Elemental", 1, 5 },
        { "Convección (Convection)", 1, "Elemental", 1, 5 },
        { "Enfoque de las mareas (Tidal Focus)", 5, "Restauración", 1, 5 },
        { "Atención plena (Mindfulness)", 3, "Restauración", 2, 3 },
        { "Enfoque totémico (Totemic Focus)", 2, "Restauración", 2, 5 },
        { "Escudo de agua (Water Shield)", 1, "Restauración", 3, 1 },
      } },
    { rama = "Elemental", rol = "Daño a distancia", ritmo = 2, texto = "Relámpagos y choques con ahorro de maná; usa Escudo de agua cuando lo aprendas.", textoEN = "Lightning and shocks with mana efficiency; use Water Shield once learned.",
      plan = {
        { "Concusión (Concussion)", 5, "Elemental", 1, 5 },
        { "Convección (Convection)", 5, "Elemental", 1, 5 },
        { "Presteza elemental (Elemental Alacrity)", 3, "Elemental", 2, 3 },
        { "Enfoque elemental (Elemental Focus)", 1, "Elemental", 3, 1 },
        { "Resguardo elemental (Elemental Warding)", 1, "Elemental", 3, 3 },
        { "Ojo de la tormenta (Eye of the Storm)", 3, "Elemental", 4, 3 },
        { "Prueba de fuego (Trial by Fire)", 2, "Elemental", 4, 2 },
        { "Llamada del trueno (Call of Thunder)", 1, "Elemental", 5, 1 },
        { "Sobrecarga de relámpagos (Lightning Overload)", 3, "Elemental", 5, 3 },
        { "Alcance elemental (Elemental Reach)", 1, "Elemental", 5, 2 },
        { "Furia elemental (Elemental Fury)", 5, "Elemental", 6, 5 },
        { "Maestría con relámpagos (Lightning Mastery)", 1, "Elemental", 7, 1 },
        { "Enfoque de las mareas (Tidal Focus)", 5, "Restauración", 1, 5 },
        { "Atención plena (Mindfulness)", 3, "Restauración", 2, 3 },
        { "Enfoque totémico (Totemic Focus)", 2, "Restauración", 2, 5 },
        { "Escudo de agua (Water Shield)", 1, "Restauración", 3, 1 },
        { "Conocimiento ancestral (Ancestral Knowledge)", 5, "Mejora", 1, 5 },
        { "Golpes de trueno (Thundering Strikes)", 4, "Mejora", 1, 5 },
      } },
    { rama = "Restauración", rol = "Sanación", ritmo = 1, texto = "Sanación de grupos y mazmorras; añade daño físico para misiones en solitario.", textoEN = "Group and dungeon healing; add melee damage for solo quests.",
      plan = {
        { "Enfoque de las mareas (Tidal Focus)", 5, "Restauración", 1, 5 },
        { "Atención plena (Mindfulness)", 3, "Restauración", 2, 3 },
        { "Enfoque totémico (Totemic Focus)", 2, "Restauración", 2, 5 },
        { "Escudo de agua (Water Shield)", 1, "Restauración", 3, 1 },
        { "Sanación ancestral (Ancestral Healing)", 3, "Restauración", 3, 3 },
        { "Enfoque de sanación (Healing Focus)", 1, "Restauración", 3, 3 },
        { "Tótem Marea de maná (Mana Tide Totem)", 1, "Restauración", 4, 1 },
        { "Maestría de las mareas (Tidal Mastery)", 4, "Restauración", 4, 5 },
        { "Presteza de la naturaleza (Nature's Swiftness)", 1, "Restauración", 5, 1 },
        { "Camino de sanación (Healing Way)", 3, "Restauración", 5, 3 },
        { "Maestría de las mareas (Tidal Mastery)", 5, "Restauración", 4, 5 },
        { "Purificación (Purification)", 5, "Restauración", 6, 5 },
        { "Mareas vivas (Riptide)", 1, "Restauración", 7, 1 },
        { "Ola de sanación mejorada (Improved Healing Wave)", 5, "Restauración", 1, 5 },
        { "Golpes de trueno (Thundering Strikes)", 5, "Mejora", 1, 5 },
        { "Conocimiento ancestral (Ancestral Knowledge)", 2, "Mejora", 1, 5 },
        { "Maña mental (Mental Dexterity)", 3, "Mejora", 2, 3 },
        { "Enfoque chamánico (Shamanistic Focus)", 1, "Mejora", 3, 1 },
        { "Armas elementales (Elemental Weapons)", 3, "Mejora", 3, 3 },
        { "Anticipación (Anticipation)", 1, "Mejora", 3, 3 },
      } },

  },
  WARLOCK = {
    -- B01: tres planes de 51 puntos, datos Playfulls 25/11/2026 y ForeverWoW.es (70755).
    -- Nombres ES comunitarios, pendientes de cotejo en cliente. Sin planes de tanque.
    { rama = "Aflicción", rol = "Daño a distancia con demonio", ritmo = 3, texto = "Leveo con daño periódico y drenajes, Corrupción instantánea, Succionar vida y Arruinar; después, refuerza al demonio.", textoEN = "Solo leveling with damage over time and drains, instant Corruption, Siphon Life and Wrack; then strengthen your demon.",
      plan = {
        { "Corrupción mejorada (Improved Corruption)", 5, "Aflicción", 1, 5 },
        { "Transfusión de vida mejorada (Improved Life Tap)", 2, "Aflicción", 1, 2 },
        { "Drenajes mejorados (Improved Drains)", 3, "Aflicción", 2, 3 },
        { "Terror de agonía mejorado (Improved Bane of Agony)", 2, "Aflicción", 3, 2 },
        { "Pandemia (Pandemic)", 3, "Aflicción", 3, 3 },
        { "Ocaso (Nightfall)", 2, "Aflicción", 4, 2 },
        { "Malevolencia (Malevolence)", 3, "Aflicción", 4, 5 },
        { "Succionar vida (Siphon Life)", 1, "Aflicción", 5, 1 },
        { "Succión de alma (Soul Siphon)", 3, "Aflicción", 5, 3 },
        { "Malevolencia (Malevolence)", 4, "Aflicción", 4, 5 },
        { "Maestría de las Sombras (Shadow Mastery)", 5, "Aflicción", 6, 5 },
        { "Arruinar (Wrack)", 1, "Aflicción", 7, 1 },
        { "Abrazo demoníaco (Demonic Embrace)", 5, "Demonología", 1, 5 },
        { "Abisario mejorado (Improved Voidwalker)", 3, "Demonología", 2, 3 },
        { "Energías demoníacas (Demonic Energies)", 2, "Demonología", 2, 2 },
        { "Poder profano (Unholy Power)", 5, "Demonología", 1, 5 },
        { "Vitalidad vil (Fel Vitality)", 3, "Demonología", 2, 3 },
        { "Égida demoníaca (Demonic Aegis)", 2, "Demonología", 2, 2 },
      } },
    { rama = "Demonología", rol = "Daño con demonio", ritmo = 3, texto = "Leveo con mascota resistente, Sacrificio demoníaco, Vínculo de alma y Pacto demoníaco. Después, mejora Corrupción y los drenajes.", textoEN = "Solo leveling with a sturdy demon, Demonic Sacrifice, Soul Link and Demonic Pact. Then improve Corruption and drains.",
      plan = {
        { "Abrazo demoníaco (Demonic Embrace)", 5, "Demonología", 1, 5 },
        { "Abisario mejorado (Improved Voidwalker)", 3, "Demonología", 2, 3 },
        { "Energías demoníacas (Demonic Energies)", 2, "Demonología", 2, 2 },
        { "Sacrificio demoníaco (Demonic Sacrifice)", 1, "Demonología", 3, 1 },
        { "Maestro invocador (Master Summoner)", 2, "Demonología", 3, 2 },
        { "Vitalidad vil (Fel Vitality)", 2, "Demonología", 2, 3 },
        { "Dominio de lo maldito (Fel Domination)", 1, "Demonología", 4, 1 },
        { "Marca demoníaca (Demonic Brand)", 3, "Demonología", 4, 3 },
        { "Vitalidad vil (Fel Vitality)", 3, "Demonología", 2, 3 },
        { "Vínculo de alma (Soul Link)", 1, "Demonología", 5, 1 },
        { "Conocimiento demoníaco (Demonic Knowledge)", 3, "Demonología", 5, 3 },
        { "Manáfago mejorado (Improved Felhunter)", 1, "Demonología", 5, 3 },
        { "Maestro demonólogo (Master Demonologist)", 5, "Demonología", 6, 5 },
        { "Pacto demoníaco (Demonic Pact)", 1, "Demonología", 7, 1 },
        { "Corrupción mejorada (Improved Corruption)", 5, "Aflicción", 1, 5 },
        { "Transfusión de vida mejorada (Improved Life Tap)", 2, "Aflicción", 1, 2 },
        { "Drenajes mejorados (Improved Drains)", 3, "Aflicción", 2, 3 },
        { "Terror de agonía mejorado (Improved Bane of Agony)", 2, "Aflicción", 3, 2 },
        { "Pandemia (Pandemic)", 3, "Aflicción", 3, 3 },
        { "Ocaso (Nightfall)", 2, "Aflicción", 4, 2 },
        { "Malevolencia (Malevolence)", 3, "Aflicción", 4, 5 },
      } },
    { rama = "Destrucción", rol = "Daño a distancia", ritmo = 2, texto = "Daño directo con Inmolar, Conflagrar, Quemadura de las Sombras e Incinerar; complementa con economía de maná y supervivencia.", textoEN = "Direct damage with Immolate, Conflagrate, Shadowburn and Incinerate; add mana efficiency and survivability.",
      plan = {
        { "Aterrar (Bane)", 5, "Destrucción", 1, 5 },
        { "Secuelas (Aftermath)", 5, "Destrucción", 2, 5 },
        { "Quemadura de las Sombras (Shadowburn)", 1, "Destrucción", 3, 1 },
        { "Ruina (Ruin)", 4, "Destrucción", 3, 5 },
        { "Conflagrar (Conflagrate)", 1, "Destrucción", 4, 1 },
        { "Llamas agonizantes (Agonizing Flames)", 3, "Destrucción", 4, 3 },
        { "Ruina (Ruin)", 5, "Destrucción", 3, 5 },
        { "Terror de caos (Bane of Havoc)", 1, "Destrucción", 5, 1 },
        { "Fuego y azufre (Fire and Brimstone)", 3, "Destrucción", 5, 3 },
        { "Intensidad (Intensity)", 1, "Destrucción", 4, 3 },
        { "Sombras y llamas (Shadow and Flame)", 5, "Destrucción", 6, 5 },
        { "Incinerar (Incinerate)", 1, "Destrucción", 7, 1 },
        { "Corrupción mejorada (Improved Corruption)", 5, "Aflicción", 1, 5 },
        { "Transfusión de vida mejorada (Improved Life Tap)", 2, "Aflicción", 1, 2 },
        { "Supresión (Suppression)", 3, "Aflicción", 1, 5 },
        { "Abrazo demoníaco (Demonic Embrace)", 5, "Demonología", 1, 5 },
        { "Poder profano (Unholy Power)", 5, "Demonología", 1, 5 },
      } },
  },
  WARRIOR = {
    -- Referencias ES: https://foreverwow.es/talentos-guerrero.html y https://talentsforever.com/es/warrior (70959).
    -- Golpes temerarios: traducción comunitaria de Reckless Swings, pendiente del cliente esES.
    -- B02: plan principal centralizado para no alterar los archivos de rutas de la fase 13.
    { rama = "Armas", rol = "Daño cuerpo a cuerpo", ritmo = 3, texto = "Arma de dos manos, Heridas profundas y Golpe mortal: la más rápida para subir.",
      plan = { { "Desgarrar mejorado (Improved Rend)", 3, "Armas", 1 },
        { "Golpe heroico mejorado (Improved Heroic Strike)", 2, "Armas", 1, 3 },
        { "Maestría táctica mejorada (Improved Tactical Mastery)", 3, "Armas", 2 },
        { "Embestir mejorado (Improved Charge)", 2, "Armas", 2 },
        { "Control de furia (Anger Management)", 1, "Armas", 3 },
        { "Heridas profundas (Deep Wounds)", 3, "Armas", 3 },
        { "Abrumar mejorado (Improved Overpower)", 2, "Armas", 2 },
        { "Especialización en armas de dos manos (Two-Handed Weapon Specialization)", 3, "Armas", 4 },
        { "Clavar (Impale)", 1, "Armas", 4, 2 },
        { "Golpes de barrido (Sweeping Strikes)", 1, "Armas", 5 },
        { "Clavar (Impale)", 2, "Armas", 4 },
        { "Fragor de la sangre (Bloodthrill)", 2, "Armas", 5 },
        { "Maestro de armas (Weaponmaster)", 4, "Armas", 5, 5 },
        { "Embate mejorado (Improved Slam)", 2, "Armas", 6 },
        { "Golpe mortal (Mortal Strike)", 1, "Armas", 7 },
        { "Crueldad (Cruelty)", 5, "Furia", 1 },
        { "Cólera desbocada (Unbridled Wrath)", 5, "Furia", 2 },
        { "Manía sangrienta (Blood Craze)", 3, "Furia", 3 },
        { "Enfurecer (Enrage)", 5, "Furia", 3 },
        { "Golpes temerarios (Reckless Swings)", 1, "Furia", 4 },
        { "Aullido penetrante (Piercing Howl)", 1, "Furia", 3 } } },
    -- Auditoría de talentos B01: nombres y rangos contrastados con Forever 1.60.1.71139.
    -- Orden de leveo propuesto; la compra efectiva se valida con la API del cliente.
    { rama = "Furia", rol = "Daño cuerpo a cuerpo", ritmo = 2, texto = "Dos armas, Aluvión y Sed de sangre. Muy buena desde el 40 y en grupo.",
      plan = { { "Crueldad (Cruelty)", 5, "Furia", 1 },
        { "Cólera desbocada (Unbridled Wrath)", 5, "Furia", 2 },
        { "Precisión furiosa (Furious Precision)", 3, "Furia", 3 },
        { "Manía sangrienta (Blood Craze)", 3, "Furia", 3 },
        { "Enfurecer (Enrage)", 5, "Furia", 3 },
        { "Especialización en doble empuñadura (Dual Wield Specialization)", 5, "Furia", 4 },
        { "Golpes temerarios (Reckless Swings)", 1, "Furia", 4 },
        { "Deseo de la Muerte (Death Wish)", 1, "Furia", 5 },
        { "Aluvión (Flurry)", 2, "Furia", 6, 3 },
        { "Sed de sangre (Bloodthirst)", 1, "Furia", 7 },
        { "Aluvión (Flurry)", 3, "Furia", 6 },
        { "Ejecutar mejorado (Improved Execute)", 2, "Furia", 4 },
        { "Bebedor de entrañas (Gore Drinker)", 2, "Furia", 5 },
        { "Desvío (Deflection)", 5, "Armas", 1 },
        { "Golpe heroico mejorado (Improved Heroic Strike)", 3, "Armas", 1 },
        { "Desgarrar mejorado (Improved Rend)", 3, "Armas", 1 },
        { "Maestría táctica mejorada (Improved Tactical Mastery)", 3, "Armas", 2 },
        { "Control de furia (Anger Management)", 1, "Armas", 3 } } },
    { rama = "Protección", rol = "Tanque", ritmo = 1, texto = "Escudo y aguante para tanquear mazmorras. Sola mata despacio.",
      plan = { { "Especialización en escudos (Shield Specialization)", 5, "Protección", 1 },
        { "Sanguinario mejorado (Improved Bloodrage)", 2, "Protección", 1 },
        { "Revancha mejorada (Improved Revenge)", 3, "Protección", 2 },
        { "Última posición (Last Stand)", 1, "Protección", 3 },
        { "Maestro de defensa (Master of Defense)", 2, "Protección", 3 },
        { "Desafío (Defiance)", 2, "Protección", 3, 3 },
        { "Vanguardia (Vanguard)", 1, "Protección", 4 },
        { "Desafío (Defiance)", 3, "Protección", 3 },
        { "Trueno mejorado (Improved Thunder Clap)", 3, "Protección", 2 },
        { "Golpe de concusión (Concussion Blow)", 1, "Protección", 5 },
        { "Ira enfocada (Focused Rage)", 3, "Protección", 5 },
        { "Muro de escudo mejorado (Improved Shield Wall)", 1, "Protección", 5, 2 },
        { "Bastión (Bastion)", 5, "Protección", 6 },
        { "Embate con escudo (Shield Slam)", 1, "Protección", 7 },
        { "Muro de escudo mejorado (Improved Shield Wall)", 2, "Protección", 5 },
        { "Hender armadura mejorado (Improved Sunder Armor)", 3, "Protección", 4 },
        { "Anticipación (Anticipation)", 5, "Protección", 2 },
        { "Desvío (Deflection)", 5, "Armas", 1 },
        { "Golpe heroico mejorado (Improved Heroic Strike)", 3, "Armas", 1 },
        { "Maestría táctica mejorada (Improved Tactical Mastery)", 3, "Armas", 2 } } },
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

local function EsDeLaGuia(e)
  if Clase()=="DRUID" then return e.rama=="Feral (gato)" end
  return guia and L(e.rama) == guia.rama
end
local function NombrePlan(e) return GL.ingles and e.nombreEN or L(e.rama) end
local function TextoPlan(e) return GL.ingles and e.textoEN or L(e.texto) end
function GL.TalentosDeLaGuia() return guia and guia.talentos or nil end   -- 9.7.7.1: para Talentos.lua

local function Rama(R, nombre)
  for _, r in ipairs(R.ramas or {}) do if r.nombre == nombre then return r end end
end

-- Pasa la lista de talentos clave al formato del plan de la ruta (d = nivel desde, h = nivel hasta, puntos = "n/máx").
local function Plan(e, R)
  local l, nivel = {}, 10
  local icono = (Rama(R, L(e.arbol or e.rama)) or {}).icono
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
      table.insert(l, { d = nivel, h = fin, rama = rama, nombre = nombre, puntos = hasta .. "/" .. (p[5] or rangos), icono = icono, iconoGenerico = true, fila = p[4],
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
  DRUID={Equilibrio="lanzador",["Restauración"]="sanador",["Feral (gato)"]="fisico",["Feral (oso)"]="tanque"},
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
  elseif clase=="DRUID" then
    if rama=="Feral (oso)" then
      pesos.ITEM_MOD_PARRY_RATING_SHORT=nil; pesos.ITEM_MOD_BLOCK_RATING_SHORT=nil
      peso("STAMINA",1.6);peso("DODGE_RATING",1.2);peso("DEFENSE_SKILL_RATING",1.2)
    elseif rama=="Feral (gato)" then peso("AGILITY",1.4);peso("STRENGTH",1.2) end
    pesos.VARITA=nil
  elseif clase=="HUNTER" then
    -- Forever distingue Supervivencia cuerpo a cuerpo de Bestias/Puntería.
    -- Reutilizar los pesos orientativos existentes, no equivalencias de DPS verificadas.
    peso("AGILITY",1.5); peso("INTELLECT",0.6)
    if rama=="Supervivencia" then
      peso("AGILITY",1.8); peso("STAMINA",1.0)
      pesos.DPS=6; pesos.DISTANCIA=0.4
    else
      peso("STRENGTH",0.1)
      pesos.DPS=0.4; pesos.DISTANCIA= rama=="Puntería" and 8 or 6
      local p = original.pesos or {}
      peso("RANGED_ATTACK_POWER", p.ITEM_MOD_RANGED_ATTACK_POWER_SHORT or pesos.ITEM_MOD_ATTACK_POWER_SHORT)
      if rama=="Bestias" then peso("STAMINA",0.9) end
    end
  elseif clase=="PALADIN" and rama=="Protección" then
    -- El plan de tanque incluye recuperación de maná. Conservar los pesos
    -- orientativos de recursos ya definidos en la ruta, no inventar otros.
    local p = original.pesos or {}
    peso("INTELLECT", p.ITEM_MOD_INTELLECT_SHORT)
    peso("MANA_REGENERATION", p.ITEM_MOD_MANA_REGENERATION_SHORT)
  elseif clase=="PRIEST" and rama=="Disciplina" then
    -- El plan mixto recomienda varitas al principio del leveo.
    pesos.VARITA = (original.pesos or {}).VARITA or pesos.VARITA
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
  if clase=="DRUID" then equipo.dobleArma=nil end
  -- No se presupone aprendizaje de doble empuñadura del chamán en Forever.
  R.equipo=equipo
end

-- Aplica la especialización guardada a la ruta cargada (al iniciar y al elegir).
function GL.AplicarEspecializacion(R)
  R = R or GL.RUTA
  if not R then return end
  GuardarGuia(R)
  local db = DB()
  -- Migrar solo preferencias de la variante retirada. No modifica talentos del cliente.
  if Clase() == "SHAMAN" then
    for _, k in ipairs({"especializacion", "especializacionElegidaManual", "especializacionIgnorar"}) do
      if db[k] == "Mejora (tanque)" or db[k] == "Enhancement (tank)" then db[k] = "Mejora" end
    end
  end
  if Clase()=="DRUID" then
    -- The previous Feral plan was a bear tank plan; keep that role for existing users.
    for _,k in ipairs({"especializacion","especializacionElegidaManual"}) do
      if db[k]=="Combate feral" or db[k]=="Feral Combat" then db[k]="Feral (oso)" end
    end
  end
  local elegida = db.especializacion
  local e
  for _, x in ipairs(Lista()) do if x.rama == elegida then e = x end end
  local clase = Clase()
  if (clase == "WARRIOR" or clase == "PALADIN" or clase == "HUNTER" or clase == "ROGUE" or clase == "PRIEST" or clase == "SHAMAN" or clase == "MAGE" or clase == "WARLOCK" or clase == "DRUID") and not e then
    for _, x in ipairs(Lista()) do if EsDeLaGuia(x) then e = x; break end end
  end
  if (clase == "SHAMAN" or clase == "MAGE" or clase == "WARLOCK" or clase == "DRUID") and not e then e = Lista()[1] end
  -- Los perfiles auditados de cazador deben distinguir los roles incluso si
  -- la rama elegida coincide con la recomendación histórica de la ruta.
  GL.AplicarEquipoEspecializacion(R, clase, e and e.rama, not e or (clase~="DRUID" and clase~="HUNTER" and EsDeLaGuia(e)))
  if not e or (EsDeLaGuia(e) and clase ~= "WARRIOR" and clase ~= "PALADIN" and clase ~= "HUNTER" and clase ~= "ROGUE" and clase ~= "PRIEST" and clase ~= "SHAMAN" and clase ~= "MAGE" and clase ~= "WARLOCK" and clase ~= "DRUID") or not e.plan then
    R.talentos, R.talentosIntro, R.planFlexible = guia.talentos, guia.intro, nil
    return
  end
  R.talentos = Plan(e, R)
  R.talentosIntro = NombrePlan(e) .. ": " .. TextoPlan(e) .. " " ..
    L"La guía pone sola los talentos clave que encuentre en tu árbol; los que Forever haya cambiado te los dice para que los pongas a mano. El botón Especialización la cambia."
  -- Los planes auditados mantienen el orden: no saltar un requisito no reconocido.
  R.planFlexible = (clase ~= "WARRIOR" and clase ~= "PALADIN" and clase ~= "HUNTER" and clase ~= "ROGUE" and clase ~= "PRIEST" and clase ~= "SHAMAN" and clase ~= "MAGE" and clase ~= "WARLOCK" and clase ~= "DRUID") or nil
end

------------------------------------------------------------------------
-- Ventana para elegir
------------------------------------------------------------------------
local function Estrellas(n) return GL.Simbolos(string.rep("★", n) .. "|cff555555" .. string.rep("★", 3 - n) .. "|r") end

local RamaMayoritaria   -- 9.7.7.1, más abajo

local function RolFeral(real)
  local r = real and real.rangosPorNombre
  if type(r) ~= "table" then return nil end
  local function Tiene(es, en) return (r[es] or 0) > 0 or (r[en] or 0) > 0 end
  local gato = Tiene("disciplinadepredadora", "predatorydiscipline") or Tiene("podercambiante", "shiftingpower")
  local oso = Tiene("lacerar", "lacerate") or Tiene("reaccionnatural", "naturalreaction") or Tiene("mordiscoprimigenio", "primalbite")
  if gato and not oso then return "Feral (gato)" end
  if oso and not gato then return "Feral (oso)" end
end


local function Elegir(e)
  if GL.CancelarContextoTalentosR14 then GL.CancelarContextoTalentosR14() end
  DB().especializacion = e.rama
  DB().especializacionElegidaManual = e.rama
  -- 9.7.7.1: si eliges a mano otra rama que la de tus puntos, la guía no te la vuelve a cambiar por esos puntos
  DB().especializacionIgnorar = RamaMayoritaria and RamaMayoritaria() or nil
  GL.AplicarEspecializacion()
  GL.Mensaje(L"especialización elegida: " .. NombrePlan(e) .. (EsDeLaGuia(e) and L" (la de la guía)" or "") .. ".")
  if GL.ventanaEspecializacion then GL.ventanaEspecializacion:Hide() end
  if GL.Refrescar then GL.Refrescar() end
  if GL.ProgramarTalentosEspecializacion then GL.ProgramarTalentosEspecializacion() end
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
      texto = NombrePlan(e) .. "  " .. Estrellas(e.ritmo) .. (deGuia and (C.VERDE .. L"  Recomendada: la que más rápido sube" .. C.FIN) or ""),
      detalle = (GL.ingles and e.rolEN or L(e.rol)) .. " · " .. TextoPlan(e),
      boton = (elegida == e.rama) and L"Elegida" or L"Elegir",
      hecha = elegida == e.rama,
      accion = function() Elegir(e) end,
      ayudaTitulo = NombrePlan(e), ayudaTexto = TextoPlan(e) .. ((deGuia and Clase() ~= "WARRIOR" and Clase() ~= "PALADIN" and Clase() ~= "HUNTER" and Clase() ~= "ROGUE" and Clase() ~= "PRIEST" and Clase() ~= "SHAMAN" and Clase() ~= "MAGE" and Clase() ~= "WARLOCK" and Clase() ~= "DRUID") and ("\n\n" .. L"Usa el plan de talentos de tu ruta, comprobado en Forever.") or
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
  if GL.TalentosCambiosPendientes and GL.TalentosCambiosPendientes() then return end
  -- Detectar los puntos existentes antes de guardar la rama recomendada.
  GL.ComprobarEspecializacionReal()
  if db.especializacion then return end
  local rama, real = RamaMayoritaria()
  if Clase() == "DRUID" and rama == L"Combate feral" and not RolFeral(real) then
    GL.AbrirEspecializacion(); return
  end
  if n > 12 then
    -- No guardar una recomendación como elección si el árbol aún no está disponible.
    local puntos = GL.PuntosRealesPorRama and GL.PuntosRealesPorRama()
    if not puntos then return end
    -- Si la detección no resolvió una distribución ya significativa, no convertir
    -- la recomendación en una elección: habilitaría el gasto automático en híbridos.
    if (puntos.total or 0) >= 5 then GL.AbrirEspecializacion(); return end
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
  -- Una elección explícita prevalece sobre los puntos ya repartidos.
  if db.especializacionElegidaManual and db.especializacionElegidaManual == db.especializacion then return end
  local mejor, real = RamaMayoritaria()
  if not mejor or mejor == db.especializacionIgnorar then return end
  local plan = PlanHasta(real.total)
  local enPlan = 0
  for _, n in pairs(plan) do enPlan = enPlan + n end
  local feral = Clase() == "DRUID" and mejor == L"Combate feral"
  local rol = feral and RolFeral(real)
  if feral and not rol then return end
  if not feral and db.especializacion and enPlan > 0 and (plan[mejor] or 0) >= enPlan * 0.6 then return end   -- el plan en uso ya va por esa rama
  -- Un árbol compartido no identifica por sí solo el rol (feral gato/oso).
  local candidatos = 0
  for _, e in ipairs(Lista()) do
    if L(e.arbol or e.rama) == mejor and (e.plan or EsDeLaGuia(e)) then candidatos = candidatos + 1 end
  end
  if not rol and candidatos ~= 1 then return end
  for _, e in ipairs(Lista()) do
    if L(e.arbol or e.rama) == mejor and (not rol or e.rama == rol) and e.rama ~= db.especializacion and (e.plan or EsDeLaGuia(e)) then
      if GL.CancelarContextoTalentosR14 then GL.CancelarContextoTalentosR14() end
      db.especializacion = e.rama
      db.especializacionIgnorar = nil
      db.especializacionElegidaManual = nil
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
  if DB().especializacion ~= nil or Nivel() < 10 or #Lista() == 0 then return false end
  if Nivel() <= 12 then return true end
  local real = GL.PuntosRealesPorRama and GL.PuntosRealesPorRama()
  if not real then return true end
  local rama = RamaMayoritaria()
  -- Una distribución híbrida o sin clasificar no autoriza gastar puntos sin elegir plan.
  if (real.total or 0) >= 5 and not rama then return true end
  if Clase() == "DRUID" then
    return rama == L"Combate feral"
  end
  return false
end

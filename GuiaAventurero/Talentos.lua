-- Talentos.lua: pone solos los talentos de la guía al subir de nivel. Creado por JKRiveroF.
-- WoW Forever guarda los talentos con el sistema de rasgos del juego (C_Traits): cada talento es un nodo del árbol.
-- La guía busca cada talento del plan por su nombre (en español o en inglés) y gasta los puntos libres
-- en el mismo orden que el plan. Nunca quita puntos: si repartiste otros, solo sigue con lo que falte.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local pendiente
local generacionAuto = 0
local generacionConfigR14 = 0
function GL.CancelarTalentosAutomaticos()
  generacionAuto = generacionAuto + 1
  if pendiente and not pendiente.manual then pendiente = nil end
end
local ContextoAutomatico, ContextoVigente
local ultimoIntento = -10
local poniendo = false               -- impide reentradas mientras se compran y aplican puntos
local avisado                         -- nivel en el que ya se avisó de que algo no se pudo poner
local aplicando                       -- momento en que la guía pidió aplicar los talentos (para reintentar si falla)
local configAplicando, rutaAplicando, planAplicando, generacionAplicando
local reintentos = 0
function GL.CancelarContextoTalentosR14()
  generacionConfigR14 = generacionConfigR14 + 1
  GL.CancelarTalentosAutomaticos()
  pendiente = nil -- también una petición manual de otro árbol
  aplicando, configAplicando, rutaAplicando, planAplicando = nil, nil, nil, nil
end

local function DB() return type(GuiaAventureroDB) == "table" and GuiaAventureroDB or nil end
local function Activo()
  local db = DB()
  return db ~= nil and db.autoTalentos ~= false and not (GL.EspecializacionPendiente and GL.EspecializacionPendiente())
end

-- "Descarga de Escarcha mejorada (Improved Frostbolt)" -> nombre en español y en inglés, sin tildes ni signos.
local TILDES = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
  ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n" }
local function Normalizar(s)
  s = string.lower(s or "")
  for k, v in pairs(TILDES) do s = string.gsub(s, k, v) end
  return (string.gsub(s, "[^%a%d]", ""))
end

local function NombresDelPlan(t)
  local es, en = string.match(t.nombre or "", "^(.-)%s*%((.-)%)%s*$")
  if not es then es = t.nombre end
  return Normalizar(es), en and Normalizar(en) or nil
end

-- Explicaciones breves de guía; sin cifras variables por rango. Fuentes: ForeverWoW.es (70755), ForeverDiff (71091/71139).
local ResumenesClaseR12
local function CrearResumenesGuerrero()
local resumenesGuerrero = {
  ["improvedheroicstrike"] = {"Abarata Golpe heroico.", "Lowers Heroic Strike's rage cost."},
  ["deflection"] = {"Mejora la probabilidad de parar.", "Improves parry chance."},
  ["improvedrend"] = {"Refuerza el sangrado de Desgarrar.", "Strengthens Rend's bleed."},
  ["improvedcharge"] = {"Genera más ira con Cargar.", "Gain more rage from Charge."},
  ["improvedtacticalmastery"] = {"Conserva más ira al cambiar de actitud.", "Retain more rage through stance changes."},
  ["improvedoverpower"] = {"Aumenta los críticos de Abrumar.", "Improves Overpower's critical chance."},
  ["angermanagement"] = {"Ayuda a mantener y generar ira.", "Helps sustain and generate rage."},
  ["deepwounds"] = {"Los críticos provocan sangrado.", "Critical hits inflict a bleed."},
  ["spearingstrike"] = {"Desbloquea un golpe contra objetivos, especialmente gigantes, dragonantes y montados.", "Unlocks a strike especially useful against giants, dragonkin and mounted targets."},
  ["twohandedweaponspecialization"] = {"Mejora el daño con armas de dos manos.", "Boosts two-handed weapon damage."},
  ["impale"] = {"Refuerza el daño crítico de facultades.", "Boosts ability critical damage."},
  ["bloodthrill"] = {"Permite activar Abrumar al atacar objetivos con Desgarrar.", "Can enable Overpower against targets affected by Rend."},
  ["sweepingstrikes"] = {"Permite alcanzar un enemigo adicional con varios golpes.", "Lets several strikes hit an additional enemy."},
  ["weaponmaster"] = {"Concede ventajas según el tipo de arma.", "Grants benefits based on weapon type."},
  ["improvedslam"] = {"Mejora los tiempos de Embate.", "Improves Slam's timing."},
  ["improvedhamstring"] = {"Puede inmovilizar al usar Seccionar.", "Hamstring can root its target."},
  ["mortalstrike"] = {"Desbloquea el golpe que reduce la sanación enemiga.", "Unlocks a healing-reduction strike."},
  ["boomingvoice"] = {"Amplía el alcance y mejora el coste de los gritos.", "Improves shout reach and rage economy."},
  ["cruelty"] = {"Aumenta la probabilidad de crítico cuerpo a cuerpo.", "Raises melee critical chance."},
  ["lingeringrage"] = {"Retrasa la pérdida de ira al salir de combate.", "Delays rage decay outside combat."},
  ["unbridledwrath"] = {"Puede aportar ira adicional al golpear.", "Melee hits can grant extra rage."},
  ["furiousprecision"] = {"Mejora la precisión de la mano secundaria.", "Improves off-hand accuracy."},
  ["piercinghowl"] = {"Desbloquea una ralentización de área.", "Unlocks an area slow."},
  ["bloodcraze"] = {"Regenera salud después de determinados golpes recibidos.", "Regenerates health after certain incoming hits."},
  ["enrage"] = {"Puede aumentar el daño físico al recibir ataques.", "Incoming attacks can boost physical damage."},
  ["dualwieldspecialization"] = {"Refuerza los ataques y la generación de ira de la mano secundaria.", "Boosts off-hand damage and rage generation."},
  ["recklessswings"] = {"Desbloquea un refuerzo temporal de generación de ira.", "Unlocks a temporary rage-generation boost."},
  ["improvedexecute"] = {"Reduce el coste de Ejecutar.", "Lowers Execute's rage cost."},
  ["improvedberserkerrage"] = {"Mejora la generación de ira y la movilidad de Ira rabiosa.", "Improves Berserker Rage's rage and mobility benefits."},
  ["deathwish"] = {"Desbloquea un aumento ofensivo con riesgo defensivo.", "Unlocks an offensive boost with a defensive trade-off."},
  ["goredrinker"] = {"Determinadas habilidades permiten recuperar salud con golpes posteriores.", "Certain abilities enable healing from subsequent melee hits."},
  ["improvedintercept"] = {"Reduce la reutilización de Interceptar.", "Shortens Intercept's cooldown."},
  ["improvedwhirlwind"] = {"Mejora la reutilización y el daño de Torbellino.", "Improves Whirlwind's cooldown and damage."},
  ["flurry"] = {"Los críticos aumentan temporalmente la velocidad de ataque.", "Critical hits temporarily boost attack speed."},
  ["bloodthirst"] = {"Desbloquea un ataque basado en poder de ataque.", "Unlocks an attack-power-based strike."},
  ["improvedbloodrage"] = {"Refuerza la generación de ira de Ira sangrienta.", "Improves Bloodrage's rage generation."},
  ["shieldspecialization"] = {"Mejora el bloqueo y la ira al bloquear.", "Improves blocking and rage from blocks."},
  ["ironwill"] = {"Reduce la duración de miedo y aturdimiento recibidos.", "Shortens incoming fear and stun effects."},
  ["anticipation"] = {"Aumenta la habilidad de defensa.", "Raises defense skill."},
  ["improvedrevenge"] = {"Aumenta el daño de Revancha.", "Boosts Revenge damage."},
  ["improvedthunderclap"] = {"Abarata Atronar.", "Lowers Thunder Clap's rage cost."},
  ["laststand"] = {"Desbloquea un aumento temporal de salud máxima.", "Unlocks a temporary maximum-health boost."},
  ["masterofdefense"] = {"Puede generar ira al esquivar o parar con escudo.", "Dodges and parries can grant rage while using a shield."},
  ["improveddisarm"] = {"Reduce la reutilización de Desarmar.", "Shortens Disarm's cooldown."},
  ["defiance"] = {"Mejora la amenaza en actitud defensiva con escudo.", "Improves threat in Defensive Stance with a shield."},
  ["improvedsunderarmor"] = {"Reduce el coste de Hender armadura.", "Lowers Sunder Armor's rage cost."},
  ["vanguard"] = {"Permite utilizar Cargar en actitud defensiva.", "Enables Charge in Defensive Stance."},
  ["improvedshieldbash"] = {"Añade un silencio a Azote de escudo.", "Adds a silence to Shield Bash."},
  ["improvedshieldwall"] = {"Reduce la reutilización de Muro de escudo.", "Shortens Shield Wall's cooldown."},
  ["concussionblow"] = {"Desbloquea un aturdimiento.", "Unlocks a stun."},
  ["focusedrage"] = {"Reduce el coste de facultades ofensivas.", "Lowers offensive ability rage costs."},
  ["bastion"] = {"Aumenta el daño al llevar escudo.", "Boosts damage while wearing a shield."},
  ["shieldslam"] = {"Desbloquea un golpe de escudo de alta amenaza.", "Unlocks a high-threat shield strike."},
}
  return resumenesGuerrero
end
function GL.ResumenTalentoGuerrero(t)
  if not GL.RUTA or GL.RUTA.clase ~= "WARRIOR" or not t then return nil end
  local a, b = NombresDelPlan(t)
  local datos = ResumenesClaseR12("WARRIOR")
  local par = datos[a] or datos[b]
  if not par then return nil end
  return (GL.ingles and "Guide summary: " or "Resumen de la guía: ") .. par[GL.ingles and 2 or 1]
end

-- Paladín: resúmenes propios de los 51 talentos (17 por rama).
-- Contraste: https://www.forever-xp.com/changes/paladin/ (71037) y
-- https://talentsforever.com/es/paladin (árbol actual). El tooltip nativo prevalece.
local function CrearResumenesPaladin()
local resumenesPaladin = {
  ["spiritualfocus"] = {"Reduce el retraso de ciertos lanzamientos de sanación al recibir daño.", "Reduces damage-induced pushback on selected healing casts."},
  ["divinestrength"] = {"Aumenta la fuerza.", "Raises Strength."},
  ["healinglight"] = {"Potencia la sanación de Luz Sagrada, Destello de Luz y Choque sagrado.", "Boosts healing from Holy Light, Flash of Light and Holy Shock."},
  ["reverence"] = {"Mantiene parte de la regeneración de maná mientras lanzas hechizos.", "Retains some mana regeneration while casting."},
  ["improvedseals"] = {"Refuerza el daño de sellos y sentencias.", "Boosts Seal and Judgement damage."},
  ["purifyingpower"] = {"Abarata la limpieza de efectos y permite usar antes Exorcismo y Cólera Sagrada.", "Cuts dispel mana costs and shortens Exorcism and Holy Wrath cooldowns."},
  ["divinefavor"] = {"Garantiza el crítico de la siguiente sanación compatible.", "Guarantees a critical effect on the next eligible heal."},
  ["illumination"] = {"Recupera maná al lograr críticos con sanaciones compatibles.", "Refunds mana after critical eligible heals."},
  ["holyconduit"] = {"Reduce el coste de Consagración, Cólera Sagrada, Exorcismo y Martillo de cólera.", "Cuts mana costs for Consecration, Holy Wrath, Exorcism and Hammer of Wrath."},
  ["divineprecision"] = {"Mejora el acierto de hechizos Sagrados y reduce la duración del silencio.", "Improves Holy spell hit and shortens incoming silences."},
  ["infusionoflight"] = {"Los críticos de Choque sagrado y Destello de Luz aceleran la siguiente Luz Sagrada.", "Holy Shock and Flash of Light crits speed up the next Holy Light."},
  ["oathoflight"] = {"Refuerza tus sanaciones principales sobre un aliado elegido.", "Improves your main heals on a chosen ally."},
  ["consecratedground"] = {"Refuerza el daño Sagrado contra los primeros enemigos que entran en Consagración.", "Boosts Holy damage against the first enemies entering Consecration."},
  ["holyshock"] = {"Desbloquea daño Sagrado o sanación instantánea según el objetivo.", "Unlocks instant Holy damage or healing depending on the target."},
  ["boundlesslight"] = {"Aumenta el crítico de Choque sagrado en aliados sin tu Juramento de Luz.", "Improves Holy Shock crit chance on allies without your Oath of Light."},
  ["holypower"] = {"Refuerza la cantidad sanada por los críticos Sagrados.", "Increases the healing bonus of Holy critical effects."},
  ["lightsvigil"] = {"Marca a un aliado para que el siguiente Choque sagrado sane también a su grupo sin activar la reutilización.", "Marks an ally so the next Holy Shock heals their party without triggering its cooldown."},
  ["divineintellect"] = {"Aumenta el intelecto total.", "Raises total Intellect."},
  ["redoubt"] = {"Los ataques cuerpo a cuerpo recibidos pueden reforzar temporalmente el bloqueo.", "Incoming melee hits can temporarily boost block chance."},
  ["precision"] = {"Mejora la probabilidad de acertar.", "Improves hit chance."},
  ["guardiansfavor"] = {"Reduce la espera de Bendición de protección y prolonga Bendición de libertad.", "Shortens Blessing of Protection cooldown and extends Blessing of Freedom."},
  ["sacredduty"] = {"Reduce la reutilización de defensivos compatibles y la duración de Abstinencia.", "Shortens eligible defensive cooldowns and Forbearance."},
  ["templarsbulwark"] = {"Desbloquea un escudo de absorción temporal sujeto a Abstinencia.", "Unlocks a temporary absorb shield subject to Forbearance."},
  ["improvedhammerofjustice"] = {"Reduce la reutilización de Martillo de Justicia.", "Shortens Hammer of Justice cooldown."},
  ["shieldspecialization"] = {"Refuerza la absorción al bloquear y permite recuperar maná.", "Improves block value and enables mana recovery from blocks."},
  ["toughness"] = {"Aumenta la armadura aportada por los objetos.", "Increases armor from equipped items."},
  ["swiftjudgement"] = {"Desbloquea una sentencia adicional que conserva el sello activo.", "Unlocks an extra Judgement that preserves the active Seal."},
  ["improvedrighteousfury"] = {"Reduce el daño recibido mientras Furia justa está activa.", "Reduces damage taken with Righteous Fury active."},
  ["anticipation"] = {"Aumenta la habilidad de defensa.", "Raises defense skill."},
  ["stoicism"] = {"Reduce la duración de aturdimientos y embelesamientos recibidos.", "Shortens incoming stun and charm effects."},
  ["holyshield"] = {"Mejora el bloqueo y genera daño Sagrado y amenaza al bloquear.", "Improves blocking and produces Holy damage and threat on blocks."},
  ["reckoning"] = {"Los bloqueos y determinados críticos recibidos pueden generar ataques adicionales.", "Blocks and certain incoming critical hits can grant extra attacks."},
  ["ironcreed"] = {"Refuerza la amenaza de Golpe sagrado y reduce temporalmente el daño recibido con Furia justa.", "Boosts Holy Strike threat and briefly reduces damage taken with Righteous Fury."},
  ["shieldsworn"] = {"Adapta Golpe sagrado al escudo, activa efectos de bloqueo y permite bloquear hechizos temporalmente.", "Makes Holy Strike use the shield, trigger block effects and temporarily enable spell blocking."},
  ["deflection"] = {"Aumenta la probabilidad de parar ataques.", "Improves parry chance."},
  ["benediction"] = {"Abarata las facultades de lanzamiento instantáneo.", "Reduces mana costs of instant abilities."},
  ["improvedjudgement"] = {"Reduce la reutilización de Sentencia.", "Shortens Judgement cooldown."},
  ["conviction"] = {"Mejora el crítico de hechizos y ataques.", "Improves spell and attack critical chance."},
  ["sanctifiedjudgement"] = {"Permite recuperar parte del coste de maná del sello al usar Sentencia.", "Refunds some Seal mana cost when using Judgement."},
  ["vindication"] = {"Los golpes cuerpo a cuerpo pueden debilitar el poder de ataque del objetivo.", "Melee hits can weaken the target's attack power."},
  ["unyieldingfaith"] = {"Acorta el miedo y la desorientación recibidos.", "Shortens incoming fear and disorient effects."},
  ["sealofcommand"] = {"Desbloquea un sello ofensivo de daño Sagrado.", "Unlocks an offensive Holy-damage Seal."},
  ["pursuitofjustice"] = {"Aumenta la velocidad de movimiento a pie y en montura.", "Increases running and mounted movement speed."},
  ["eyeforaneye"] = {"Devuelve parte del daño de los críticos recibidos al atacante.", "Reflects some incoming critical damage to the attacker."},
  ["sacredarbiter"] = {"Refuerza Golpe sagrado y permite renovar las sentencias sobre el objetivo.", "Boosts Holy Strike and lets it refresh Judgements on the target."},
  ["twohandedweaponspecialization"] = {"Refuerza el daño físico y Sagrado con armas de dos manos y reduce la amenaza.", "Boosts Physical and Holy damage with two-handed weapons and lowers threat."},
  ["turnevil"] = {"Mejora Ahuyentar no-muertos y permite usarlo contra demonios.", "Improves Turn Undead and enables it against demons."},
  ["repentance"] = {"Desbloquea una incapacitación temporal de humanoides que se rompe con daño.", "Unlocks temporary humanoid incapacitation that breaks on damage."},
  ["vengeance"] = {"Los críticos no periódicos acumulan un refuerzo de daño físico y Sagrado.", "Non-periodic crits stack a Physical and Holy damage bonus."},
  ["championofthelight"] = {"Convierte parte del intelecto en daño de hechizos y acelera Martillo de cólera.", "Converts some Intellect into spell damage and speeds up Hammer of Wrath."},
  ["unsealedwrath"] = {"Almacena efectos del sello activo para aprovecharlos al atacar con otro sello.", "Stores active Seal effects for release when attacking with a different Seal."},
}
  return resumenesPaladin
end
-- Cazador B02: 50 talentos comunes a los árboles publicados; etiquetas ES de guía.
-- Fuentes: Forever DB 71139, Playfulls 25/11, Forever Builds y Class Deep Dives.
-- El nodo adicional Improved Serpent Sting se documenta aparte por discrepancia entre fuentes.
-- No se añade al plan ni se usa para inferir especialización sin nombre inequívoco.
local function CrearResumenesCazador()
local datosCazador = {
  {"Bestias","Deadly Aspects","Aspectos letales","Los ataques automáticos pueden acelerar el tipo de ataque correspondiente al aspecto activo.","Auto attacks can speed up attacks matching the active aspect."},
  {"Bestias","Endurance Training","Entrenamiento de robustez","Refuerza salud y armadura de la mascota.","Improves pet durability through health and armor."},
  {"Bestias","Focused Fire","Fuego enfocado","Potencia el daño conjunto mientras la mascota está activa.","Boosts combined damage while the pet is active."},
  {"Bestias","Improved Aspect of the Monkey","Aspecto del mono mejorado","Aumenta la esquiva del aspecto y beneficia también a la mascota.","Enhances the aspect's dodge and shares a benefit with the pet."},
  {"Bestias","Improved Revive Pet","Revivir mascota mejorado","Abarata y acelera la resurrección de la mascota, que vuelve con más salud.","Revives pets faster, more cheaply and with better health."},
  {"Bestias","Pathfinding","Encontrar camino","Mejora la velocidad de los aspectos de viaje.","Enhances travel aspects' speed."},
  {"Bestias","Bestial Swiftness","Presteza bestial","Acelera el desplazamiento de la mascota.","Improves pet movement speed."},
  {"Bestias","Unleashed Fury","Furia desatada","Refuerza el daño de mascotas y halcones.","Boosts pet and hawk damage."},
  {"Bestias","Improved Mend Pet","Aliviar mascota mejorado","Abarata la cura de mascota y puede limpiar perjuicios.","Makes pet healing cheaper and can remove harmful effects."},
  {"Bestias","Ferocity","Ferocidad","Aumenta los críticos de mascotas y halcones.","Improves pet and hawk critical strikes."},
  {"Bestias","Summon Hawk","Invocar halcón","Envía un halcón contra el enemigo durante un tiempo; comparte reutilización con Disparo Arcano.","Calls a temporary attacking hawk; shares Arcane Shot's cooldown."},
  {"Bestias","Spirit Bond","Vínculo de espíritu","Regenera salud del cazador y mascota mientras esta permanece activa.","Provides ongoing health recovery for hunter and active pet."},
  {"Bestias","Intimidation","Intimidación","Ordena a la mascota aturdir y generar amenaza con su próximo golpe válido.","Orders the pet to stun and build threat with its next successful strike."},
  {"Bestias","Bestial Discipline","Disciplina bestial","Mejora el enfoque de la mascota y permite regenerar maná al lanzar.","Improves pet Focus recovery and the hunter's in-cast mana recovery."},
  {"Bestias","Frenzy","Frenesí","Los críticos de mascota pueden acelerar sus ataques.","Pet critical strikes can accelerate its attacks."},
  {"Bestias","Bestial Wrath","Cólera de las bestias","La mascota entra en un estado temporal de mayor daño y resistencia al control.","Temporarily empowers the pet's damage and resistance to control."},
  {"Puntería","Hawk Eye","Ojo de halcón","Amplía el alcance de las armas a distancia.","Extends ranged weapon reach."},
  {"Puntería","Improved Concussive Shot","Disparo de conmoción mejorado","Añade una posibilidad de aturdir con el disparo de control.","Adds a stun chance to the control shot."},
  {"Puntería","Lethal Attacks","Ataques letales","Mejora la probabilidad de crítico de los ataques.","Boosts attack critical chance."},
  {"Puntería","Improved Stings","Picaduras mejoradas","Mejora Picadura de serpiente, la frecuencia de víbora y la duración de escórpido.","Enhances Serpent damage, Viper availability and Scorpid duration."},
  {"Puntería","Efficiency","Eficacia","Abarata disparos, picaduras y habilidades cuerpo a cuerpo.","Reduces mana use for shots, stings and melee skills."},
  {"Puntería","Careful Aim","Afinar la puntería","Convierte intelecto en poder de ataque.","Converts Intellect into attack power."},
  {"Puntería","Rapid Killing","Matanza rápida","Acorta Fuego rápido y potencia un disparo tras ciertas muertes de enemigos.","Shortens Rapid Fire's cooldown and empowers a shot after eligible kills."},
  {"Puntería","Improved Arcane Shot","Disparo Arcano mejorado","Acorta la reutilización propia de Disparo Arcano.","Shortens Arcane Shot's own cooldown."},
  {"Puntería","Lone Wolf","Lobo solitario","Refuerza el daño cuando no hay mascota activa.","Boosts damage without an active pet."},
  {"Puntería","Trueshot Aura","Aura de disparo certero","Aporta poder de ataque a distancia a aliados cercanos.","Grants nearby allies ranged attack power."},
  {"Puntería","Mortal Shots","Disparos mortales","Aumenta el daño adicional de los críticos de habilidades a distancia.","Increases the bonus damage of ranged ability critical strikes."},
  {"Puntería","Rapid Recuperation","Recuperación rápida","Picadura de serpiente ayuda a recuperar maná durante el lanzamiento, con sinergia de Matanza rápida.","Serpent Sting enables in-cast mana recovery, enhanced by Rapid Killing."},
  {"Puntería","Barrage","Tromba","Refuerza Multidisparo, Disparo apuntado y Salva.","Boosts Multi-Shot, Aimed Shot and Volley damage."},
  {"Puntería","Scatter Shot","Disparo de dispersión","Desorienta brevemente; el daño rompe el efecto.","Briefly disorients; damage breaks the effect."},
  {"Puntería","Ranged Weapon Specialization","Especialización en armas a distancia","Aumenta el daño de armas a distancia.","Raises ranged weapon damage."},
  {"Puntería","Sniper Shot","Disparo de francotirador","Ataque de largo alcance que amplía el alcance de disparos posteriores.","Long-range strike that extends follow-up shot reach."},
  {"Supervivencia","Improved Tracking","Rastreo mejorado","Potencia el daño contra el tipo de criatura que rastreas.","Boosts damage against the tracked creature type."},
  {"Supervivencia","Deflection","Desvío","Mejora la probabilidad de parada.","Improves parry chance."},
  {"Supervivencia","Entrapment","Atrapar","Las trampas pueden inmovilizar a los enemigos afectados.","Triggered traps can root affected foes."},
  {"Supervivencia","Savage Strikes","Golpes salvajes","Refuerza los críticos de habilidades cuerpo a cuerpo.","Boosts melee ability critical chance."},
  {"Supervivencia","Survivalist","Superviviente","Aumenta la salud total.","Raises maximum health."},
  {"Supervivencia","Improved Wing Clip","Cortar alas mejorado","Permite que Cortar alas inmovilice temporalmente.","Lets Wing Clip briefly immobilize a target."},
  {"Supervivencia","Clever Traps","Trampas ingeniosas","Mejora la duración del control y el daño de las trampas correspondientes.","Extends control trap effects and boosts damaging traps."},
  {"Supervivencia","Surefooted","Paso firme","Mejora el acierto y acorta los perjuicios de movimiento.","Improves hit chance and shortens movement impairments."},
  {"Supervivencia","Deterrence","Disuasión","Aumenta temporalmente esquiva y parada.","Temporarily improves dodge and parry."},
  {"Supervivencia","Survival Tactics","Tácticas de supervivencia","Mejora la fiabilidad de trampas y Fingir muerte.","Makes traps and Feign Death more reliable."},
  {"Supervivencia","Predator's Edge","Filo del depredador","Potencia críticos de habilidades cuerpo a cuerpo y daño de mano izquierda.","Boosts melee critical damage and off-hand damage."},
  {"Supervivencia","Counterattack","Contraataque","Tras parar un ataque, permite un golpe que inmoviliza.","After parrying, enables an immobilizing strike."},
  {"Supervivencia","Resourcefulness","Ingenio","Abarata trampas y ataques cuerpo a cuerpo; ciertos críticos favorecen recuperar maná.","Cuts trap and melee costs; eligible crits support mana recovery."},
  {"Supervivencia","Expose Prey","Exponer presa","Atacar a un enemigo marcado puede habilitar Mordedura de mangosta.","Attacking a marked target can enable Mongoose Bite."},
  {"Supervivencia","Survivalist's Discipline","Disciplina del superviviente","Acorta la reutilización de trampas y Disuasión.","Reduces trap and Deterrence cooldowns."},
  {"Supervivencia","Strider Kick","Patada de zancudo","Ataque de patada que acelera brevemente el desplazamiento.","Kicking attack that briefly boosts movement speed."},
  {"Supervivencia","Lightning Reflexes","Reflejos relámpago","Aumenta la agilidad.","Raises Agility."},
  {"Supervivencia","Lacerating Strikes","Golpes lacerantes","Mordedura de mangosta añade un sangrado.","Mongoose Bite applies an additional bleed."},
}
local resumenesCazador = {}
for _, e in ipairs(datosCazador) do
  local par = {e[4],e[5]}
  resumenesCazador[Normalizar(e[2])] = par
  resumenesCazador[Normalizar(e[3])] = par
end
-- Solo resumen si el nombre exacto aparece en el cliente; no se presupone disponible.
local resumenPicaduraDiscrepante = {"Refuerza el daño de Picadura de serpiente; presencia en el árbol pendiente de verificar.", "Boosts Serpent Sting damage; presence in the tree pending verification."}
resumenesCazador.improvedserpentsting = resumenPicaduraDiscrepante
resumenesCazador.picaduradeserpientemejorada = resumenPicaduraDiscrepante
  return resumenesCazador
end

-- Pícaro B02: 54 talentos, resúmenes de guía propios y etiquetas ES provisionales.
-- TalentsForever /rogue/talents, hotfix 3/11; Playfulls, 25/11/2026.
local function CrearResumenesPicaro()
local datosPicaro = {
  {"Asesinato","Improved Gouge","Gubia mejorada","Prolonga la incapacitación de Gubia.","Extends Gouge incapacitation."},
  {"Asesinato","Remorseless Attacks","Ataques despiadados","Tras derrotar a un enemigo válido, aumenta el crítico de ciertos ataques siguientes.","After an eligible kill, boosts the critical chance of selected follow-up attacks."},
  {"Asesinato","Malice","Malicia","Mejora los críticos de ataques y venenos.","Boosts attack and poison critical chance."},
  {"Asesinato","Ruthlessness","Despiadado","Los remates pueden devolver un punto de combo.","Finishing moves may grant a combo point."},
  {"Asesinato","Improved Expose Armor","Exponer armadura mejorado","Reduce el coste de Exponer armadura y devuelve puntos de combo al usarlo con cinco.","Makes Expose Armor cheaper and refunds combo points on a five-point cast."},
  {"Asesinato","Improved Slice and Dice","Hacer picadillo mejorado","Prolonga Hacer picadillo.","Extends Slice and Dice duration."},
  {"Asesinato","Vigor","Vigor","Aumenta la energía máxima.","Raises maximum Energy."},
  {"Asesinato","Blood Splatter","Salpicadura de sangre","Prolonga Ruptura y Garrote.","Extends Rupture and Garrote."},
  {"Asesinato","Lethality","Letalidad","Aumenta el daño adicional de críticos de varios generadores de combo.","Boosts critical damage bonuses for several combo builders."},
  {"Asesinato","Vile Poisons","Venenos viles","Refuerza el daño de los venenos y su resistencia a disipaciones.","Strengthens poison damage and resistance to dispels."},
  {"Asesinato","Cold Blood","Sangre fría","Garantiza el crítico del siguiente ataque compatible.","Guarantees a critical strike with the next eligible attack."},
  {"Asesinato","Improved Poisons","Venenos mejorados","Facilita aplicar venenos y conservar sus cargas.","Helps apply poisons and conserve charges."},
  {"Asesinato","Relentless Strikes","Golpes implacables","Los remates pueden recuperar energía en función de los puntos gastados.","Finishers can refund Energy based on combo points spent."},
  {"Asesinato","Venom","Veneno","Shank potencia temporalmente el daño y la aplicación de venenos.","Shank temporarily boosts poison damage and application."},
  {"Asesinato","Improved Kidney Shot","Golpe en los riñones mejorado","Los enemigos aturdidos por este remate reciben más daño del pícaro.","Enemies stunned by this finisher take more damage from the rogue."},
  {"Asesinato","Seal Fate","Sellar el destino","Los críticos de generadores pueden conceder otro punto de combo.","Critical combo builders can grant an extra combo point."},
  {"Asesinato","Mutilate","Mutilar","Ataca con ambas dagas, potencia el daño contra enemigos envenenados y genera dos puntos de combo.","Strikes with both daggers, deals extra damage to poisoned foes and builds two combo points."},
  {"Combate","Coup de Grace","Golpe de gracia","Refuerza Eviscerar y el daño acumulado por Marca de muerte.","Strengthens Eviscerate and Death Mark damage storage."},
  {"Combate","Efficient Strikes","Golpes eficientes","Abarata Golpe siniestro y Hemorragia.","Reduces Sinister Strike and Hemorrhage Energy costs."},
  {"Combate","Lightning Reflexes","Reflejos relámpago","Aumenta la esquiva.","Raises dodge chance."},
  {"Combate","Puncturing Wounds","Heridas punzantes","Mejora los críticos de Puñalada y Mutilar; Puñalada puede generar otro punto de combo.","Boosts Backstab and Mutilate critical chance; Backstab may grant another combo point."},
  {"Combate","Deflection","Desvío","Mejora la probabilidad de parar ataques.","Improves parry chance."},
  {"Combate","Precision","Precisión","Aumenta la probabilidad de acertar.","Improves hit chance."},
  {"Combate","Improved Sprint","Sprint mejorado","Sprint puede eliminar efectos que dificultan el movimiento.","Sprint can clear movement impairments."},
  {"Combate","Endurance","Aguante","Acorta la reutilización de Sprint y Evasión.","Shortens Sprint and Evasion cooldowns."},
  {"Combate","Riposte","Respuesta","Permite contraatacar tras parar un golpe y desarmar al enemigo.","Unlocks a counterattack after parrying that disarms the foe."},
  {"Combate","Composure","Compostura","Refuerza el ahorro de energía de Poised.","Enhances Poised Energy savings."},
  {"Combate","Improved Kick","Patada mejorada","Patada puede silenciar brevemente al objetivo.","Kick can briefly silence the target."},
  {"Combate","Flawless Execution","Ejecución impecable","Abarata Eviscerar.","Makes Eviscerate cheaper."},
  {"Combate","Weapon Expertise","Pericia con armas","Mejora la pericia de las armas cuerpo a cuerpo.","Improves melee weapon expertise."},
  {"Combate","Aggression","Agresión","Refuerza Golpe siniestro y Eviscerar.","Strengthens Sinister Strike and Eviscerate."},
  {"Combate","Dual Wield Specialization","Especialización en doble empuñadura","Aumenta el daño del arma secundaria.","Raises off-hand weapon damage."},
  {"Combate","Blade Flurry","Aluvión de acero","Acelera temporalmente los ataques y permite golpear a otro enemigo cercano.","Temporarily speeds attacks and lets them strike another nearby foe."},
  {"Combate","Hack and Slash","Cortar y tajar","Los golpes con armas compatibles pueden provocar un ataque extra.","Eligible weapon hits can trigger an extra attack."},
  {"Combate","Flash of Steel","Destello de acero","Shank recupera más energía y se puede usar con mayor frecuencia.","Shank restores more Energy and becomes available sooner."},
  {"Combate","Adrenaline Rush","Subidón de adrenalina","Acelera temporalmente la recuperación de energía.","Temporarily accelerates Energy regeneration."},
  {"Sutileza","Setup","Preparación táctica","Esquivar o resistir por completo un hechizo puede generar un punto de combo.","Dodging or fully resisting a spell may grant a combo point."},
  {"Sutileza","Master of Deception","Maestro del engaño","Dificulta que los enemigos detecten al pícaro en sigilo.","Makes the rogue harder to detect in Stealth."},
  {"Sutileza","Opportunity","Oportunidad","Refuerza Puñalada, Garrote, Emboscada y Mutilar.","Strengthens Backstab, Garrote, Ambush and Mutilate."},
  {"Sutileza","Dirty Deeds","Malas artes","Abarata Golpe bajo y Garrote; elimina la exigencia de atacar desde atrás con Garrote.","Cuts Cheap Shot and Garrote costs and removes Garrote's rear-position requirement."},
  {"Sutileza","Camouflage","Camuflaje","Mejora la movilidad en sigilo y acorta su reutilización.","Improves Stealth movement and shortens its cooldown."},
  {"Sutileza","Improved Ambush","Emboscada mejorada","Aumenta la probabilidad de crítico de Emboscada.","Boosts Ambush critical chance."},
  {"Sutileza","Dirty Tricks","Trucos sucios","Reduce el coste de energía de Porrazo y Ceguera.","Cuts Sap and Blind Energy costs."},
  {"Sutileza","Initiative","Iniciativa","Los ataques de apertura compatibles pueden añadir otro punto de combo.","Eligible opening attacks can grant an extra combo point."},
  {"Sutileza","Premeditation","Premeditación","Genera dos puntos de combo temporales antes de iniciar el ataque.","Grants two temporary combo points before attacking."},
  {"Sutileza","Serrated Blades","Hojas serradas","Permite ignorar parte de la armadura y potencia Ruptura.","Bypasses some armor and strengthens Rupture."},
  {"Sutileza","Elusiveness","Elusión","Acorta la reutilización de Esfumarse y Ceguera.","Shortens Vanish and Blind cooldowns."},
  {"Sutileza","Ghostly Strike","Golpe fantasmal","Ataque que mejora la esquiva y permite una apertura compatible sin sigilo.","Attack that improves dodge and enables an eligible opener without Stealth."},
  {"Sutileza","Quick Getaway","Huida rápida","Permite controlar un objetivo adicional con Porrazo y acelera brevemente el movimiento.","Enables an additional Sapped target and briefly speeds movement."},
  {"Sutileza","Heightened Senses","Sentidos agudizados","Mejora la detección de sigilo y la defensa frente a hechizos y ataques a distancia.","Improves Stealth detection and defense against spells and ranged attacks."},
  {"Sutileza","Preparation","Preparación","Reinicia la reutilización de habilidades compatibles.","Resets cooldowns of eligible abilities."},
  {"Sutileza","Hemorrhage","Hemorragia","Ataque que aumenta el daño de tus sangrados de Ruptura y Garrote sobre el objetivo.","Attack that amplifies your Rupture and Garrote bleeds on the target."},
  {"Sutileza","Boot Knife","Cuchillo de bota","Shank puede generar dos puntos de combo.","Shank can generate two combo points."},
  {"Sutileza","Death Mark","Marca de muerte","Remate que acumula parte del daño causado para liberarlo después, con especial beneficio de los sangrados.","Finisher that stores part of dealt damage for a later burst, favoring bleeds."},
}
local resumenesPicaro = {}
for _, e in ipairs(datosPicaro) do
  local par = {e[4],e[5]}
  resumenesPicaro[Normalizar(e[2])] = par
  resumenesPicaro[Normalizar(e[3])] = par
end
  return resumenesPicaro
end

-- Sacerdote B02: etiquetas ES de guía (provisionales) y resúmenes propios.
-- Fuentes: https://talentsforever.com/priest/talents (hotfix 18/11), https://forevertalents.net/talents/priest/ .
local function CrearResumenesSacerdote()
local datosSacerdote = {
  {"Disciplina", "Power in Light", "Poder en la Luz", "Potencia Punición y Penitencia contra objetivos afectados por tus perjuicios compatibles.", "Boosts Smite and Penance against targets with your eligible debuffs."},
  {"Disciplina", "Wand Specialization", "Especialización en varitas", "Aumenta el daño de las varitas.", "Boosts wand damage."},
  {"Disciplina", "Twin Disciplines", "Disciplinas gemelas", "Refuerza el daño y la sanación de tus hechizos instantáneos.", "Boosts instant spell damage and healing."},
  {"Disciplina", "Silent Resolve", "Resolución silenciosa", "Reduce la amenaza de hechizos compatibles y la duración de aturdimiento, miedo y silencio recibidos.", "Reduces eligible spell threat and incoming stun, fear and silence duration."},
  {"Disciplina", "Holy Precision", "Precisión sagrada", "Aumenta la probabilidad de acertar con hechizos sagrados.", "Improves Holy spell hit chance."},
  {"Disciplina", "Mental Strength", "Fuerza mental", "Aumenta el intelecto total.", "Raises total Intellect."},
  {"Disciplina", "Martyrdom", "Martirio", "Los críticos físicos recibidos pueden proteger temporalmente tus lanzamientos.", "Incoming physical critical hits can temporarily protect your casts."},
  {"Disciplina", "Mental Agility", "Agilidad mental", "Reduce el coste de maná de Punición, Fuego sagrado y hechizos instantáneos.", "Lowers Mana costs of Smite, Holy Fire and instant spells."},
  {"Disciplina", "Inner Focus", "Enfoque interno", "Permite lanzar un hechizo compatible sin coste de maná y con mayor probabilidad de crítico.", "Enables a free eligible spell with increased critical chance."},
  {"Disciplina", "Improved Power Word: Shield", "Palabra de poder: escudo mejorada", "Aumenta la absorción del escudo.", "Strengthens shield absorption."},
  {"Disciplina", "Meditation", "Meditación", "Mantiene parte de la regeneración de maná mientras lanzas hechizos.", "Retains some Mana regeneration while casting."},
  {"Disciplina", "Improved Inner Fire", "Fuego interno mejorado", "Refuerza los beneficios de Fuego interno.", "Enhances Inner Fire's benefits."},
  {"Disciplina", "Improved Mana Burn", "Quemadura de maná mejorada", "Acorta el lanzamiento de Quemadura de maná.", "Shortens Mana Burn's cast time."},
  {"Disciplina", "Soul Warding", "Protección del alma", "Reduce el coste de maná y la reutilización de Palabra de poder: escudo.", "Reduces Power Word: Shield Mana cost and cooldown."},
  {"Disciplina", "Penance", "Penitencia", "Canaliza una descarga que cura aliados o daña enemigos.", "Channels a volley that heals allies or damages foes."},
  {"Disciplina", "Renewed Hope", "Esperanza renovada", "Mejora los críticos de sanación compatibles sobre Alma debilitada y acorta ese perjuicio.", "Improves eligible healing crits against Weakened Soul and shortens that debuff."},
  {"Disciplina", "Divine Aegis", "Égida divina", "Las sanaciones críticas compatibles pueden generar absorción de daño.", "Eligible critical heals can create damage absorption."},
  {"Disciplina", "Power Infusion", "Infusión de poder", "Otorga temporalmente un refuerzo al lanzamiento de hechizos.", "Temporarily empowers spellcasting."},
  {"Sagrado", "Twilight Focus", "Enfoque crepuscular", "Reduce el retraso de lanzamiento provocado por recibir daño.", "Reduces cast pushback from incoming damage."},
  {"Sagrado", "Improved Renew", "Renovar mejorado", "Aumenta la sanación de Renovar.", "Boosts Renew healing."},
  {"Sagrado", "Holy Specialization", "Especialización sagrada", "Mejora los críticos de los hechizos sagrados.", "Improves Holy spell critical chance."},
  {"Sagrado", "Spell Warding", "Protección contra hechizos", "Reduce el daño recibido de hechizos.", "Reduces incoming spell damage."},
  {"Sagrado", "Divine Fury", "Furia divina", "Acorta el lanzamiento de hechizos de daño y sanación compatibles.", "Shortens eligible damage and healing casts."},
  {"Sagrado", "Holy Nova", "Nova sagrada", "Inflige daño a enemigos cercanos y sana aliados próximos.", "Damages nearby enemies and heals nearby allies."},
  {"Sagrado", "Blessed Recovery", "Recuperación bendita", "Permite recuperar salud después de recibir críticos físicos.", "Restores health after incoming physical critical hits."},
  {"Sagrado", "Inspiration", "Inspiración", "Las sanaciones críticas compatibles mejoran temporalmente la defensa física del objetivo.", "Eligible critical heals temporarily improve the target's physical defense."},
  {"Sagrado", "Holy Reach", "Alcance sagrado", "Amplía el alcance o radio de determinados hechizos sagrados.", "Extends the range or radius of selected Holy spells."},
  {"Sagrado", "Improved Healing", "Sanación mejorada", "Abarata los hechizos de sanación compatibles.", "Lowers eligible healing spell costs."},
  {"Sagrado", "Searing Light", "Luz abrasadora", "Refuerza hechizos ofensivos sagrados.", "Strengthens offensive Holy spells."},
  {"Sagrado", "Holy Binding", "Vínculo sagrado", "Sanación relámpago sobre otro objetivo también te cura, sin amenaza adicional por esa cura.", "Flash Heal on someone else also heals you without additional threat from that heal."},
  {"Sagrado", "Litany of Light", "Letanía de Luz", "Recupera parte del maná al alternar hechizos de sanación distintos.", "Refunds some Mana when alternating different heals."},
  {"Sagrado", "Spirit of Redemption", "Espíritu de redención", "Tras morir, permite sanar brevemente en forma espiritual.", "Briefly enables healing in spirit form after death."},
  {"Sagrado", "Spiritual Guidance", "Guía espiritual", "Convierte parte del espíritu en bonificación de sanación y daño mágico.", "Converts some Spirit into healing and spell damage bonuses."},
  {"Sagrado", "Spiritual Healing", "Sanación espiritual", "Refuerza la sanación de tus hechizos.", "Strengthens spell healing."},
  {"Sagrado", "Prayer of Mending", "Rezo de alivio", "Aplica una cura reactiva que puede pasar a otros aliados.", "Applies a reactive heal that can bounce to other allies."},
  {"Sombra", "Shadow Focus", "Enfoque de las Sombras", "Mejora la probabilidad de acertar con hechizos de Sombras.", "Improves Shadow spell hit chance."},
  {"Sombra", "Blackout", "Desmayo", "Los hechizos de daño de Sombras pueden aturdir al objetivo.", "Shadow damage spells may stun targets."},
  {"Sombra", "Spirit Tap", "Golpe de espíritu", "Favorece la recuperación de maná tras derrotar enemigos válidos.", "Supports Mana recovery after eligible kills."},
  {"Sombra", "Improved Mind Blast", "Explosión mental mejorada", "Reduce la reutilización de Explosión mental.", "Shortens Mind Blast cooldown."},
  {"Sombra", "Improved Shadow Word: Pain", "Palabra de las Sombras: dolor mejorada", "Prolonga el efecto de Palabra de las Sombras: dolor.", "Extends Shadow Word: Pain."},
  {"Sombra", "Shadow Reach", "Alcance de las Sombras", "Amplía el alcance de hechizos de Sombras compatibles.", "Extends eligible Shadow spell range."},
  {"Sombra", "Improved Psychic Scream", "Alarido psíquico mejorado", "Reduce la reutilización de Alarido psíquico.", "Shortens Psychic Scream cooldown."},
  {"Sombra", "Mind Flay", "Tortura mental", "Canaliza daño de Sombras y ralentiza al enemigo.", "Channels Shadow damage and slows the target."},
  {"Sombra", "Improved Mind Flay", "Tortura mental mejorada", "Los pulsos consecutivos de Tortura mental infligen daño creciente.", "Successive Mind Flay ticks deal increasing damage."},
  {"Sombra", "Dark Inspiration", "Inspiración oscura", "Explosión mental y Tortura mental completada refuerzan temporalmente el espíritu del grupo.", "Mind Blast and completed Mind Flay temporarily boost party Spirit."},
  {"Sombra", "Vampiric Embrace", "Abrazo vampírico", "Convierte parte del daño de Sombras en sanación del grupo.", "Converts some Shadow damage into party healing."},
  {"Sombra", "Shadow Weaving", "Tejido de las Sombras", "Aplica una vulnerabilidad acumulable al daño de Sombras que infliges.", "Applies a stacking vulnerability to your own Shadow damage."},
  {"Sombra", "Silence", "Silencio", "Impide temporalmente al enemigo lanzar hechizos.", "Temporarily prevents enemy spellcasting."},
  {"Sombra", "Devouring Contagion", "Contagio devorador", "Abarata Peste devoradora y permite que salte a otro enemigo al morir el objetivo válido.", "Lowers Devouring Plague cost and lets it spread after an eligible target dies."},
  {"Sombra", "Early Demise", "Muerte prematura", "Aumenta los críticos de Palabra de las Sombras: muerte contra objetivos con poca salud.", "Boosts Shadow Word: Death critical chance on low-health targets."},
  {"Sombra", "Darkness", "Oscuridad", "Aumenta el daño de Sombras.", "Increases Shadow damage."},
  {"Sombra", "Shadowform", "Forma de las Sombras", "Refuerza el daño y la economía de maná de Sombras, reduce daño físico recibido e impide sanar.", "Boosts Shadow damage and Mana efficiency, reduces physical damage taken and prevents healing."},
}
local resumenesSacerdote = {}
for _, e in ipairs(datosSacerdote) do
  local par = {e[4], e[5]}
  resumenesSacerdote[Normalizar(e[2])] = par
  resumenesSacerdote[Normalizar(e[3])] = par
end
  return resumenesSacerdote
end

-- Chamán B02: resúmenes propios de los 50 talentos; contrastados con Playfulls (25/11) y TalentsForever.
-- Nombres ES de guía, no certificados por el cliente. Los talentos defensivos se conservan dentro de Mejora.
local function CrearResumenesChaman()
local datosChaman = {
  {"Elemental", "Convection", "Convección", "Abarata los choques y los dos hechizos de relámpagos.", "Saves mana on shocks and both lightning spells."},
  {"Elemental", "Concussion", "Concusión", "Refuerza Descarga de relámpagos, Cadena de relámpagos y Choque de tierra.", "Boosts the damage of Lightning Bolt, Chain Lightning and Earth Shock."},
  {"Elemental", "Elemental Devastation", "Devastación elemental", "Un crítico mágico de daño directo facilita los críticos cuerpo a cuerpo durante unos segundos.", "Direct spell crits briefly improve melee crit chance."},
  {"Elemental", "Reverberation", "Reverberación", "Permite usar los choques con mayor frecuencia.", "Shortens shock cooldowns."},
  {"Elemental", "Elemental Alacrity", "Presteza elemental", "Acelera Descarga de relámpagos y Cadena de relámpagos.", "Speeds up casts of Lightning Bolt and Chain Lightning."},
  {"Elemental", "Call of Flame", "Llamada de la llama", "Potencia los tótems de fuego, Choque de llamas y Nova de fuego; prolonga Choque de llamas.", "Boosts fire totems, Flame Shock and Fire Nova; extends Flame Shock."},
  {"Elemental", "Elemental Focus", "Enfoque elemental", "El daño mágico puede activar Lanzamiento libre y ahorrar el maná del siguiente hechizo de daño.", "Offensive elemental spells can proc Clearcasting for a free damage spell."},
  {"Elemental", "Elemental Warding", "Resguardo elemental", "Mitiga el daño de Fuego, Escarcha y Naturaleza.", "Mitigates Fire, Frost and Nature damage."},
  {"Elemental", "Trial by Fire", "Prueba de fuego", "Potencia Nova de fuego y acorta su reutilización; prolonga Tótem de magma.", "Improves Fire Nova damage and cooldown, and extends Magma Totem."},
  {"Elemental", "Eye of the Storm", "Ojo de la tormenta", "Los golpes recibidos tienen menos probabilidad de retrasar los lanzamientos de relámpagos.", "Protects lightning casts from pushback when taking damage."},
  {"Elemental", "Earthbound", "Vínculo a la tierra", "Al colocar Tótem Nexo terrestre, inmoviliza brevemente a enemigos cercanos.", "Roots nearby enemies when Earthbind Totem is placed."},
  {"Elemental", "Elemental Reach", "Alcance elemental", "Amplía el alcance de los relámpagos y Nova de fuego.", "Extends the range of lightning spells and Fire Nova."},
  {"Elemental", "Call of Thunder", "Llamada del trueno", "Facilita los críticos de los dos hechizos de relámpagos.", "Raises the crit chance of both lightning spells."},
  {"Elemental", "Lightning Overload", "Sobrecarga de relámpagos", "Los relámpagos pueden duplicarse con daño reducido, sin maná ni amenaza adicional.", "Lightning casts may trigger a weaker duplicate without extra mana or threat."},
  {"Elemental", "Elemental Fury", "Furia elemental", "Refuerza el daño adicional de los críticos elementales y de los tótems abrasador y de magma.", "Strengthens elemental critical damage bonuses, including Searing and Magma Totems."},
  {"Elemental", "Lightning Mastery", "Maestría con relámpagos", "Facultad temporal que acelera Descarga de relámpagos y elimina la reutilización de Cadena de relámpagos.", "Temporary burst that speeds Lightning Bolt and removes Chain Lightning's cooldown."},
  {"Mejora", "Earth's Grasp", "Agarre de la tierra", "Aumenta la salud del Tótem Garra de piedra y el radio de Nexo terrestre.", "Improves Stoneclaw durability and Earthbind coverage."},
  {"Mejora", "Thundering Strikes", "Golpes de trueno", "Mejora los críticos de ataques y hechizos.", "Improves critical chance for attacks and spells."},
  {"Mejora", "Ancestral Knowledge", "Conocimiento ancestral", "Aumenta el intelecto, no solo el maná máximo.", "Raises Intellect rather than just maximum mana."},
  {"Mejora", "Guardian Totems", "Tótems guardianes", "Refuerza la mitigación de Piel de piedra y Muro de viento; acorta la reutilización de Derribo.", "Strengthens Stoneskin and Windwall mitigation and shortens Grounding cooldown."},
  {"Mejora", "Mental Dexterity", "Maña mental", "Convierte parte del intelecto en poder de ataque.", "Converts Intellect into attack power."},
  {"Mejora", "Improved Lightning Shield", "Escudo de relámpagos mejorado", "Refuerza el daño de las esferas de Escudo de relámpagos.", "Improves damage from Lightning Shield charges."},
  {"Mejora", "Elemental Weapons", "Armas elementales", "Potencia los cuatro encantamientos de arma del chamán.", "Strengthens the four Shaman weapon imbues."},
  {"Mejora", "Shamanistic Focus", "Enfoque chamánico", "Reduce el gasto de maná de los choques y Escudo de relámpagos.", "Cuts mana spent on shocks and Lightning Shield."},
  {"Mejora", "Anticipation", "Anticipación", "Aumenta la esquiva.", "Improves dodge chance."},
  {"Mejora", "Toughness", "Dureza", "Aumenta el aguante.", "Raises Stamina."},
  {"Mejora", "Flurry", "Aluvión", "Tras un crítico cuerpo a cuerpo, acelera los tres golpes siguientes.", "Melee crits speed up the next three swings."},
  {"Mejora", "Stormstrike", "Golpe de tormenta", "Golpe de arma que prepara el siguiente relámpago o Choque de tierra propio para infligir más daño.", "Weapon strike that amplifies your next eligible lightning spell or Earth Shock."},
  {"Mejora", "Improved Ghost Wolf", "Lobo fantasmal mejorado", "Reduce el tiempo necesario para adoptar la forma de lobo fantasmal.", "Shortens the Ghost Wolf transformation cast."},
  {"Mejora", "Spirit Weapons", "Armas de espíritu", "Permite parar golpes; con Muerdepiedras aumenta la amenaza y sin él reduce la de los ataques.", "Enables parrying; Rockbiter increases threat, while attacks without it generate less threat."},
  {"Mejora", "Mental Quickness", "Presura mental", "El intelecto aporta potencia de daño mágico y sanación.", "Intellect contributes spell damage and healing power."},
  {"Mejora", "Improved Stormstrike", "Golpe de tormenta mejorado", "Golpe de tormenta puede mejorar la regeneración al lanzar hechizos; esquivar o parar puede reiniciar su reutilización.", "Stormstrike can sustain mana regeneration while casting; dodges and parries can reset its cooldown."},
  {"Mejora", "Maelstrom Weapon", "Arma vorágine", "Los ataques pueden acumular reducciones de coste y lanzamiento de la próxima Descarga de relámpagos.", "Melee hits can stack cast-time and mana savings for the next Lightning Bolt."},
  {"Mejora", "Rage of the Farseer", "Ira del clarividente", "Aumenta temporalmente la velocidad de ataque.", "Temporarily accelerates weapon attacks."},
  {"Restauración", "Improved Healing Wave", "Ola de sanación mejorada", "Acelera el lanzamiento de Ola de sanación.", "Speeds up Healing Wave casts."},
  {"Restauración", "Tidal Focus", "Enfoque de las mareas", "Abarata las curas y mejora la probabilidad de acertar.", "Saves healing mana and improves hit chance."},
  {"Restauración", "Mindfulness", "Atención plena", "Mantiene parte de la regeneración de maná mientras lanzas hechizos.", "Preserves some mana regeneration during casting."},
  {"Restauración", "Natural Grace", "Gracia natural", "Reduce la amenaza causada por los hechizos.", "Lowers spell-generated threat."},
  {"Restauración", "Totemic Focus", "Enfoque totémico", "Abarata los tótems y los hechizos que los colocan o mueven.", "Saves mana on totems and their summoning or relocation spells."},
  {"Restauración", "Improved Reincarnation", "Reencarnación mejorada", "Aumenta la salud máxima y mejora la recuperación y reutilización de Reencarnación.", "Raises maximum health and improves Reincarnation recovery and cooldown."},
  {"Restauración", "Ancestral Healing", "Sanación ancestral", "Una cura crítica mejora temporalmente la armadura del objetivo.", "Critical heals briefly reinforce the target's armor."},
  {"Restauración", "Healing Focus", "Enfoque de sanación", "Protege los lanzamientos de sanación contra retrasos al recibir daño.", "Protects healing casts from damage pushback."},
  {"Restauración", "Water Shield", "Escudo de agua", "Las esferas restauran maná al recibir impactos o conseguir críticos mágicos; excluye otros escudos elementales.", "Charges restore mana on incoming hits or spell crits; mutually exclusive with other elemental shields."},
  {"Restauración", "Tidal Mastery", "Maestría de las mareas", "Aumenta los críticos de sanación.", "Improves healing crit chance."},
  {"Restauración", "Restorative Totems", "Tótems restauradores", "Potencia los tótems de regeneración de maná y de sanación.", "Strengthens Mana Spring and Healing Stream Totems."},
  {"Restauración", "Mana Tide Totem", "Tótem Marea de maná", "Despliega un tótem temporal que repone maná al grupo cercano.", "Places a temporary mana-restoring totem for nearby party members."},
  {"Restauración", "Healing Way", "Camino de sanación", "Aumenta directamente la sanación de Ola de sanación.", "Directly boosts Healing Wave healing."},
  {"Restauración", "Nature's Swiftness", "Presteza de la naturaleza", "Hace instantáneo el siguiente hechizo de Naturaleza compatible.", "Makes the next eligible Nature spell instant."},
  {"Restauración", "Purification", "Purificación", "Aumenta la eficacia de las curas.", "Improves healing output."},
  {"Restauración", "Riptide", "Mareas vivas", "Cura periódica que refuerza Sanación en cadena al empezar en ese objetivo.", "Healing over time that empowers Chain Heal when started on the affected target."},
}
-- Variantes de nombre de los mismos talentos (no asociar nombres antiguos ambiguos).
local variantesChaman = {
  ["Lightning Mastery"]={"Maestría de Relámpago"},
}
local resumenesChaman = {}
for _, e in ipairs(datosChaman) do
  local par = {e[4], e[5]}
  resumenesChaman[Normalizar(e[2])] = par
  resumenesChaman[Normalizar(e[3])] = par
  for _, nombre in ipairs(variantesChaman[e[2]] or {}) do resumenesChaman[Normalizar(nombre)] = par end
end
  return resumenesChaman
end

-- Mago B02: nombres de referencia ForeverWoW.es y resúmenes propios de los 53 talentos.
local function CrearResumenesMago()
local datosMago = {
  {"Arcano", "Wand Specialization", "Especialización en varitas", "Aumenta el daño de los ataques con varita.", "Boosts wand damage."},
  {"Arcano", "Improved Channeling", "Canalización mejorada", "Protege Misiles Arcanos, Explosión y Cólera Arcana de retrasos por daño recibido.", "Protects Arcane Missiles, Blast and Wrath from damage pushback."},
  {"Arcano", "Arcane Resilience", "Recuperación Arcana", "El intelecto aporta armadura adicional.", "Converts Intellect into additional armor."},
  {"Arcano", "Arcane Subtlety", "Sutileza Arcana", "Reduce resistencias enemigas frente a tus hechizos y amenaza arcana.", "Lowers enemy resistance to your spells and Arcane threat."},
  {"Arcano", "Magic Absorption", "Absorción mágica", "Mejora resistencias y recupera maná al resistir por completo un hechizo.", "Improves resistances and restores Mana on full spell resists."},
  {"Arcano", "Arcane Concentration", "Concentración Arcana", "Los hechizos ofensivos pueden activar Lanzamiento libre.", "Offensive spells can trigger Clearcasting."},
  {"Arcano", "Missile Barrage", "Tromba de misiles", "Ciertos ataques mágicos activan Misiles Arcanos rápidos y gratuitos.", "Eligible offensive spells trigger faster, free Arcane Missiles."},
  {"Arcano", "Arcane Geometry", "Geometría Arcana", "Amplía el alcance de los hechizos arcanos.", "Extends Arcane spell range."},
  {"Arcano", "Arcane Impact", "Impacto Arcano", "Aumenta la probabilidad de crítico de los hechizos arcanos.", "Raises Arcane spell critical chance."},
  {"Arcano", "Arcane Blast", "Explosión Arcana", "Ataque arcano que acumula potencia de hechizo y aumenta su propio coste de maná.", "Arcane attack that stacks spell power and increases its own Mana cost."},
  {"Arcano", "Arcane Shielding", "Protección Arcana", "Abarata la absorción del Escudo de maná y refuerza las resistencias de Armadura de mago.", "Saves Mana when Mana Shield absorbs damage and strengthens Mage Armor resistances."},
  {"Arcano", "Improved Counterspell", "Contrahechizo mejorado", "Añade silencio a Contrahechizo.", "Adds a silence to Counterspell."},
  {"Arcano", "Arcane Meditation", "Meditación Arcana", "Permite regenerar parte del maná durante el lanzamiento.", "Preserves some Mana regeneration during casting."},
  {"Arcano", "Arcane Wrath", "Cólera Arcana", "Proyectil arcano que se beneficia del maná máximo.", "Arcane projectile scaling with maximum Mana."},
  {"Arcano", "Presence of Mind", "Presencia mental", "Vuelve instantáneo el siguiente lanzamiento compatible.", "Makes the next eligible cast instant."},
  {"Arcano", "Arcane Mind", "Mente Arcana", "Aumenta intelecto y bonificación de daño crítico arcano.", "Raises Intellect and Arcane critical damage bonus."},
  {"Arcano", "Arcane Instability", "Inestabilidad Arcana", "Aumenta el daño y la probabilidad de crítico de los hechizos.", "Raises spell damage and critical chance."},
  {"Arcano", "Arcane Power", "Poder Arcano", "Potencia temporalmente el daño mágico a cambio de mayor consumo de maná.", "Temporarily trades increased Mana costs for stronger spells."},
  {"Fuego", "Incineration", "Incineración", "Mejora los críticos de Explosión de Fuego, Lanza de hielo, Explosión Arcana y Chamuscar.", "Improves crit chance for Fire Blast, Ice Lance, Arcane Blast and Scorch."},
  {"Fuego", "Accelerant", "Acelerante", "Acelera Bola de Fuego, Descarga de Pirofrío y Cólera Arcana.", "Speeds up Fireball, Frostfire Bolt and Arcane Wrath."},
  {"Fuego", "Ignite", "Ignición", "Los críticos de Fuego provocan daño adicional periódico.", "Fire crits cause additional burning damage."},
  {"Fuego", "Flame Throwing", "Lanzallamas", "Amplía el alcance de los hechizos de Fuego.", "Extends Fire spell range."},
  {"Fuego", "Impact", "Impacto", "Los ataques de Fuego pueden aturdir.", "Fire spells can stun."},
  {"Fuego", "Burning Soul", "Alma ardiente", "Reduce amenaza de Fuego y retrasos al lanzar bajo ataque.", "Reduces Fire threat and casting pushback."},
  {"Fuego", "Improved Flamestrike", "Fogonazo mejorado", "Mejora la probabilidad de crítico de Fogonazo.", "Improves Flamestrike critical chance."},
  {"Fuego", "Pyroblast", "Piroexplosión", "Potente proyectil ígneo con daño posterior periódico.", "Powerful Fire projectile followed by periodic damage."},
  {"Fuego", "Improved Fire Blast", "Explosión de Fuego mejorada", "Acorta la reutilización y amplía el alcance de Explosión de Fuego.", "Shortens Fire Blast cooldown and extends its range."},
  {"Fuego", "Improved Scorch", "Chamuscar mejorado", "Chamuscar puede acumular vulnerabilidad al daño de Fuego propio.", "Scorch can stack vulnerability to your Fire damage."},
  {"Fuego", "Improved Fire Ward", "Custodia de Fuego mejorada", "Puede reflejar magia de Fuego mientras la custodia esté activa.", "May reflect Fire magic while Fire Ward is active."},
  {"Fuego", "Heating Up", "Calentamiento", "Los críticos directos compatibles y Explosión de Fuego aceleran la siguiente Piroexplosión.", "Eligible direct crits and Fire Blast speed up the next Pyroblast."},
  {"Fuego", "Master of Elements", "Maestro de los elementos", "Los críticos mágicos compatibles devuelven parte del maná.", "Eligible spell crits refund some Mana."},
  {"Fuego", "Critical Mass", "Masa crítica", "Aumenta la probabilidad de crítico de Fuego.", "Raises Fire critical chance."},
  {"Fuego", "Blast Wave", "Ola explosiva", "Daño ígneo en área alrededor del mago con ralentización.", "Area Fire damage around the mage with a slow."},
  {"Fuego", "Fire Power", "Poder de Fuego", "Aumenta daño de Fuego según efectos propios de esa escuela en el objetivo.", "Fire damage scales with your qualifying Fire effects on the target."},
  {"Fuego", "Combustion", "Combustión", "Acumula probabilidad de crítico de Fuego hasta producir tres críticos directos.", "Builds Fire crit chance until three non-periodic Fire crits occur."},
  {"Escarcha", "Frost Warding", "Custodia de Escarcha", "Refuerza armaduras de Escarcha y hielo, absorciones y protección contra Escarcha.", "Strengthens Frost and Ice Armor, absorption and Frost protection."},
  {"Escarcha", "Improved Frostbolt", "Descarga de Escarcha mejorada", "Reduce el tiempo de lanzamiento de Descarga de Escarcha.", "Shortens Frostbolt cast time."},
  {"Escarcha", "Precision", "Precisión", "Aumenta el acierto de todos los hechizos.", "Improves hit chance for all spells."},
  {"Escarcha", "Ice Shards", "Fragmentos de hielo", "Aumenta la bonificación de daño de los críticos de Escarcha.", "Boosts Frost critical damage bonus."},
  {"Escarcha", "Frostbite", "Mordiescarcha", "Las ralentizaciones de Escarcha pueden congelar al enemigo.", "Chill effects may freeze enemies."},
  {"Escarcha", "Improved Frost Nova", "Nova de Escarcha mejorada", "Reduce la reutilización de Nova de Escarcha.", "Shortens Frost Nova cooldown."},
  {"Escarcha", "Permafrost", "Escarcha permanente", "Refuerza la ralentización y duración de los efectos de frío.", "Strengthens and extends Chill effects."},
  {"Escarcha", "Frost Channeling", "Canalización de Escarcha", "Reduce el coste de maná y la amenaza de los hechizos de Escarcha.", "Reduces Frost spell Mana cost and threat."},
  {"Escarcha", "Improved Blizzard", "Ventisca mejorada", "Añade ralentización a Ventisca.", "Adds a slowing effect to Blizzard."},
  {"Escarcha", "Ice Lance", "Lanza de hielo", "Ataque instantáneo de Escarcha especialmente eficaz contra objetivos congelados.", "Instant Frost attack especially effective against frozen targets."},
  {"Escarcha", "Arctic Reach", "Alcance ártico", "Amplía alcance o radio de facultades de Escarcha compatibles.", "Extends range or radius of eligible Frost spells."},
  {"Escarcha", "Ice Block", "Bloqueo de hielo", "Protección temporal que impide actuar mientras dure.", "Temporary protection that prevents acting while active."},
  {"Escarcha", "Shatter", "Trizar", "Aumenta los críticos mágicos contra objetivos congelados.", "Improves spell crit chance against frozen targets."},
  {"Escarcha", "Improved Cone of Cold", "Cono de frío mejorado", "Potencia el daño de Cono de frío.", "Boosts Cone of Cold damage."},
  {"Escarcha", "Cold Snap", "Mordedura helada", "Reinicia la reutilización de las demás facultades de Escarcha.", "Resets cooldowns of other Frost spells."},
  {"Escarcha", "Fingers of Frost", "Dedos de Escarcha", "Los efectos de frío pueden hacer que los siguientes hechizos traten al enemigo como congelado.", "Chills can make subsequent spells treat the enemy as frozen."},
  {"Escarcha", "Winter's Chill", "Escalofrío del invierno", "Descarga de Escarcha y Lanza de hielo potenciada acumulan daño adicional para el siguiente Cono de frío.", "Frostbolt and empowered Ice Lance stack bonuses for the next Cone of Cold."},
  {"Escarcha", "Ice Barrier", "Barrera de hielo", "Absorbe daño, refuerza el daño de Escarcha y evita retrasos de lanzamiento mientras resiste.", "Absorbs damage, strengthens Frost damage and prevents pushback while intact."},
}
local resumenesMago = {}
for _, e in ipairs(datosMago) do
  local par = {e[4], e[5]}
  resumenesMago[Normalizar(e[2])] = par
  resumenesMago[Normalizar(e[3])] = par
end
  return resumenesMago
end

-- Brujo B02: nombres de guía ForeverWoW.es y efectos contrastados con Playfulls (25/11), hotfix 10/11.
-- Nombres ES comunitarios: el tooltip del cliente prevalece.
local function CrearResumenesBrujo()
local datosBrujo = {
  {"Aflicción", "Improved Life Tap", "Transfusión de vida mejorada", "Obtienes más maná por cada Transfusión de vida.", "Gain extra mana per Life Tap."},
  {"Aflicción", "Suppression", "Supresión", "Mejora la precisión y reduce la amenaza.", "Improves hit and lowers threat."},
  {"Aflicción", "Improved Corruption", "Corrupción mejorada", "Acelera Corrupción y potencia su daño.", "Speeds up Corruption and boosts its damage."},
  {"Aflicción", "Grim Reach", "Alcance macabro", "Puedes lanzar Aflicción desde más lejos.", "Cast Affliction spells from farther away."},
  {"Aflicción", "Soul Harvest", "Cosecha de almas", "Una muerte válida con Drenar alma favorece la regeneración incluso durante lanzamientos.", "Qualifying kills with Drain Soul boost mana recovery during casting too."},
  {"Aflicción", "Improved Drains", "Drenajes mejorados", "Potencia los drenajes de vida, alma y maná.", "Strengthens Life, Soul and Mana drains."},
  {"Aflicción", "Improved Bane of Agony", "Terror de agonía mejorado", "Potencia el daño periódico de Terror de agonía.", "Boosts Bane of Agony damage."},
  {"Aflicción", "Fel Concentration", "Concentración vil", "Los golpes interrumpen menos los drenajes y Arruinar.", "Protects drains and Wrack from damage pushback."},
  {"Aflicción", "Amplify Curse", "Amplificar maldición", "Refuerza la siguiente Debilidad, Agonía o Agotamiento.", "Empowers the next Weakness, Agony or Exhaustion effect."},
  {"Aflicción", "Pandemic", "Pandemia", "Refuerza el daño crítico de los efectos periódicos y drenajes compatibles.", "Boosts critical damage of eligible periodic effects and drains."},
  {"Aflicción", "Malevolence", "Malevolencia", "Facilita los críticos de Sombras.", "Raises Shadow spell critical chance."},
  {"Aflicción", "Nightfall", "Ocaso", "Corrupción y ciertos drenajes pueden activar una Descarga de las Sombras instantánea.", "Corruption and selected drains can enable an instant Shadow Bolt."},
  {"Aflicción", "Curse of Exhaustion", "Maldición de agotamiento", "Ralentiza a un enemigo; ocupa el espacio de maldición propia.", "Slows one enemy and occupies your curse slot."},
  {"Aflicción", "Siphon Life", "Succionar vida", "Recupera salud a través de daño periódico al enemigo.", "Recovers health through periodic enemy damage."},
  {"Aflicción", "Soul Siphon", "Succión de alma", "Corrupción, Succionar vida y Agonía refuerzan Drenar vida, Drenar alma y Arruinar.", "Corruption, Siphon Life and Agony empower Life and Soul drains and Wrack."},
  {"Aflicción", "Shadow Mastery", "Maestría de las Sombras", "Refuerza el daño y drenaje de Sombras.", "Strengthens Shadow damage and life drain."},
  {"Aflicción", "Wrack", "Arruinar", "Canaliza daño y acelera al doble los pulsos de Corrupción, Succionar vida y Agonía sobre el objetivo.", "Channeled damage that doubles the tick rate of Corruption, Siphon Life and Agony on its target."},
  {"Demonología", "Improved Health Funnel", "Cauce de salud mejorado", "Curas al demonio con menos gasto de salud y amenaza, incluso sin heridas previas.", "Heal your demon with less health cost and threat, even when uninjured."},
  {"Demonología", "Improved Imp", "Diablillo mejorado", "Potencia Descarga de Fuego y Escudo de Fuego del diablillo.", "Strengthens the Imp's Firebolt and Fire Shield."},
  {"Demonología", "Demonic Embrace", "Abrazo demoníaco", "Aumenta tu aguante.", "Raises your Stamina."},
  {"Demonología", "Unholy Power", "Poder profano", "Mejora el daño de los cinco demonios habituales.", "Boosts damage from the five usual demons."},
  {"Demonología", "Demonic Aegis", "Égida demoníaca", "Potencia Piel de demonio y Armadura demoníaca.", "Strengthens Demon Skin and Demon Armor."},
  {"Demonología", "Improved Voidwalker", "Abisario mejorado", "Refuerza las cuatro facultades del abisario.", "Strengthens all four Voidwalker abilities."},
  {"Demonología", "Fel Vitality", "Vitalidad vil", "Amplía tu reserva de maná y las reservas de salud y maná del demonio.", "Expands your mana pool and your demon's health and mana pools."},
  {"Demonología", "Demonic Energies", "Energías demoníacas", "El daño mágico sana al demonio y Transfusión de vida le aporta maná.", "Spell damage heals your demon and Life Tap shares mana with it."},
  {"Demonología", "Improved Sayaad", "Sayaad mejorado", "Potencia las facultades de súcubo e íncubo.", "Strengthens Succubus and Incubus abilities."},
  {"Demonología", "Demonic Sacrifice", "Sacrificio demoníaco", "Sacrifica el demonio: diablillo para Sombras, abisario para maná, sayaad para Fuego o manáfago para salud.", "Sacrifice a demon for Shadow (Imp), mana (Voidwalker), Fire (Sayaad) or health (Felhunter)."},
  {"Demonología", "Master Summoner", "Maestro invocador", "Abarata y acelera las invocaciones habituales.", "Makes regular demon summons faster and cheaper."},
  {"Demonología", "Decimation", "Exterminio", "Facilita Fuego de alma contra enemigos con poca salud y acorta su reutilización.", "Makes Soul Fire easier to cast against low-health enemies and shortens its cooldown."},
  {"Demonología", "Fel Domination", "Dominio de lo maldito", "Prepara una invocación más rápida y económica.", "Prepares a quicker, cheaper demon summon."},
  {"Demonología", "Demonic Brand", "Marca demoníaca", "Dolor abrasador genera menos amenaza y potencia los siguientes ataques del demonio.", "Searing Pain reduces threat and empowers upcoming pet attacks."},
  {"Demonología", "Improved Felhunter", "Manáfago mejorado", "Potencia Sangre mácula, Devorar magia y Paranoia; acorta Bloqueo de hechizo.", "Improves Tainted Blood, Devour Magic and Paranoia; shortens Spell Lock cooldown."},
  {"Demonología", "Soul Link", "Vínculo de alma", "El demonio comparte el daño recibido y ambos ganan daño ofensivo.", "Your demon shares incoming damage and both gain offensive damage."},
  {"Demonología", "Demonic Knowledge", "Conocimiento demoníaco", "Un demonio activo potencia vuestro daño mágico según tu nivel.", "An active demon boosts both spell damage values based on your level."},
  {"Demonología", "Master Demonologist", "Maestro demonólogo", "Diablillo potencia Fuego; sayaad, Sombras; abisario y manáfago mitigan daño físico o mágico.", "Imp boosts Fire; Sayaad boosts Shadow; Voidwalker and Felhunter mitigate physical or magical damage."},
  {"Demonología", "Demonic Pact", "Pacto demoníaco", "Conservas Sacrificio demoníaco al invocar otro tipo de demonio, no el sacrificado.", "Retain Demonic Sacrifice with a different demon, not the sacrificed one."},
  {"Destrucción", "Destructive Reach", "Alcance destructivo", "Amplía la distancia de lanzamiento de Destrucción.", "Extends Destruction cast range."},
  {"Destrucción", "Improved Shadow Bolt", "Descarga de Sombras mejorada", "Un crítico de Descarga de las Sombras potencia tu daño posterior de Sombras contra el objetivo.", "Shadow Bolt crits boost your subsequent Shadow damage against that target."},
  {"Destrucción", "Bane", "Aterrar", "Acelera Descarga de las Sombras, Inmolar, Incinerar y Fuego de alma.", "Speeds up Shadow Bolt, Immolate, Incinerate and Soul Fire."},
  {"Destrucción", "Molten Skin", "Piel de arrabio", "Mitiga el daño recibido.", "Reduces incoming damage."},
  {"Destrucción", "Cataclysm", "Cataclismo", "Abarata Destrucción.", "Lowers Destruction mana costs."},
  {"Destrucción", "Aftermath", "Secuelas", "Refuerza el impacto inicial de Inmolar y permite ralentizar con Conflagrar.", "Boosts Immolate's initial hit and lets Conflagrate slow enemies."},
  {"Destrucción", "Ruin", "Ruina", "Potencia los críticos de Destrucción.", "Boosts Destruction critical damage."},
  {"Destrucción", "Shadowburn", "Quemadura de las Sombras", "Ataque instantáneo de Sombras; una muerte válida cercana puede devolver un fragmento.", "Instant Shadow attack; an eligible death shortly after can refund a shard."},
  {"Destrucción", "Intensity", "Intensidad", "Protege los lanzamientos de Destrucción al recibir golpes.", "Protects Destruction casts against damage pushback."},
  {"Destrucción", "Agonizing Flames", "Llamas agonizantes", "Mejora los críticos de Dolor abrasador y el daño de Destrucción.", "Boosts Searing Pain crit chance and Destruction damage."},
  {"Destrucción", "Conflagrate", "Conflagrar", "Explota Inmolar activo; puede consumirlo salvo mejoras de talentos.", "Ignites active Immolate and may consume it unless talents prevent that."},
  {"Destrucción", "Pyroclasm", "Piroclasma", "Fuego de alma y las áreas de fuego pueden aturdir.", "Soul Fire and fire area spells can stun."},
  {"Destrucción", "Bane of Havoc", "Terror de caos", "Comparte parte del daño a otros enemigos con el objetivo marcado; solo uno a la vez.", "Copies some damage to other enemies onto the marked target; only one at a time."},
  {"Destrucción", "Fire and Brimstone", "Fuego y azufre", "Aumenta los críticos de Conflagrar.", "Raises Conflagrate critical chance."},
  {"Destrucción", "Shadow and Flame", "Sombras y llamas", "Conflagrar potencia Sombras y Quemadura potencia Fuego; pueden conservar Inmolar y recuperar fragmentos respectivamente.", "Conflagrate boosts Shadow and Shadowburn boosts Fire; they may preserve Immolate and refund shards respectively."},
  {"Destrucción", "Incinerate", "Incinerar", "Daño directo de Fuego, reforzado si el objetivo tiene Inmolar.", "Direct Fire damage, stronger against targets with Immolate."},
}
local variantesBrujo = {
  ["Grim Reach"]={"Alcance siniestro"},
  ["Improved Bane of Agony"]={"Perdición de agonía mejorada"},
  ["Nightfall"]={"Anochecer"},
  ["Soul Siphon"]={"Sifón de alma","Succionar alma"},
  ["Shadow Mastery"]={"Maestría en las Sombras"},
  ["Fel Domination"]={"Dominación vil"},
  ["Improved Shadow Bolt"]={"Descarga de las Sombras mejorada"},
  ["Bane"]={"Perdición"},
  ["Molten Skin"]={"Piel fundida"},
  ["Pyroclasm"]={"Piroclasmo"},
  ["Bane of Havoc"]={"Perdición de estragos","Perdición del caos"},
  ["Shadow and Flame"]={"Sombra y llama"},
  ["Wrack"]={"Martirio"},
}
local resumenesBrujo, aliasBrujo = {}, {}
for _, e in ipairs(datosBrujo) do
  local par, nombres = {e[4],e[5]}, {Normalizar(e[2]),Normalizar(e[3])}
  for _,nombre in ipairs(variantesBrujo[e[2]] or {}) do nombres[#nombres+1]=Normalizar(nombre) end
  for _,nombre in ipairs(nombres) do
    resumenesBrujo[nombre]=par
    aliasBrujo[nombre]=nombres
  end
end
  return resumenesBrujo, aliasBrujo
end

-- Druida B02: 52 talentos, datos del cliente publicados 26/11/2026.
-- Nombres ES de guía y variantes comunitarias; prevalece el nombre real del cliente.
local function CrearResumenesDruida()
local datosDruida = {
  {"Equilibrio", "Starlight Wrath", "Cólera estelar", "Acelera Cólera y Fuego estelar y abarata Cólera.", "Shortens Wrath and Starfire casts and lowers Wrath mana cost."},
  {"Equilibrio", "Genesis", "Génesis", "Potencia el daño y la sanación periódicos.", "Boosts damage and healing over time."},
  {"Equilibrio", "Moonglow", "Brillo lunar", "Ahorra maná al usar hechizos ofensivos.", "Lowers mana costs of damaging spells."},
  {"Equilibrio", "Moon and Stars", "Luna y estrellas", "Refuerza Fuegolunar y protege el lanzamiento de Fuego estelar frente a golpes.", "Improves Moonfire and protects Starfire casts from pushback."},
  {"Equilibrio", "Nature's Majesty", "Majestad de la naturaleza", "Aumenta la probabilidad de crítico mágico y cuerpo a cuerpo.", "Raises spell and melee critical chance."},
  {"Equilibrio", "Nature's Reach", "Alcance de la naturaleza", "Amplía el alcance ofensivo de Equilibrio y mejora la probabilidad de golpear.", "Extends offensive Balance range and improves hit chance."},
  {"Equilibrio", "Improved Entangling Roots", "Raíces enredadoras mejoradas", "Las raíces dañan más y soportan más daño antes de romperse.", "Roots deal more damage and withstand more damage before breaking."},
  {"Equilibrio", "Nature's Splendor", "Esplendor de la naturaleza", "Prolonga Fuegolunar, Rejuvenecimiento, Recrecimiento y Enjambre de insectos.", "Extends Moonfire, Rejuvenation, Regrowth and Insect Swarm."},
  {"Equilibrio", "Insect Swarm", "Enjambre de insectos", "Aplica daño de Naturaleza periódico y dificulta que el enemigo acierte.", "Applies Nature damage over time and lowers enemy hit chance."},
  {"Equilibrio", "Vengeance", "Venganza", "Potencia el daño crítico Arcano y de Naturaleza.", "Boosts Arcane and Nature critical damage."},
  {"Equilibrio", "Improved Starfire", "Fuego estelar mejorado", "Fuego estelar puede aturdir. Ahora tiene dos rangos.", "Starfire can stun. Now has two ranks."},
  {"Equilibrio", "Overgrowth", "Sobrecrecimiento", "Permite enraizar más objetivos simultáneamente.", "Allows more simultaneous Entangling Roots targets."},
  {"Equilibrio", "Nature's Grace", "Gracia de la naturaleza", "Los críticos no periódicos aceleran brevemente los lanzamientos y la reutilización global.", "Nonperiodic critical spells briefly speed casts and global cooldowns."},
  {"Equilibrio", "Eclipse", "Eclipse", "Mejora los críticos de Cólera y acumula cargas que aceleran Fuego estelar.", "Improves Wrath crits and builds charges that speed Starfire."},
  {"Equilibrio", "Dreamstate", "Estado de sueño", "Recibes parte del efecto de Estimular cuando lo lanzas sobre otra persona.", "Shares Innervate's benefit when you cast it on someone else."},
  {"Equilibrio", "Moonkin Form", "Forma de lechúcico lunar", "Forma ofensiva con armadura, daño mágico, Augurio de claridad y aura de crítico; impide sanar.", "Offensive form with armor, spell damage, Omen of Clarity and a crit aura; prevents healing."},
  {"Combate feral", "Ferocity", "Ferocidad", "Reduce el coste de ira o energía de ataques ferales seleccionados.", "Lowers Rage or Energy costs of selected feral attacks."},
  {"Combate feral", "Furor", "Furor", "Facilita empezar con ira al cambiar a oso y recuperar energía al volver a gato.", "Helps start with Rage in Bear and regain Energy when returning to Cat."},
  {"Combate feral", "Feral Swiftness", "Presteza feral", "Acelera el movimiento felino y mejora la esquiva.", "Improves Cat movement speed and dodge."},
  {"Combate feral", "Feral Instinct", "Instinto feral", "Refuerza Flagelo y dificulta que te descubran al acechar.", "Improves Swipe and makes Prowl harder to detect."},
  {"Combate feral", "Brutal Impact", "Impacto brutal", "Prolonga los aturdimientos de Azote y Abalanzarse y acorta la reutilización de Azote.", "Extends Bash and Pounce stuns and shortens Bash cooldown."},
  {"Combate feral", "Thick Hide", "Pellejo grueso", "Mejora la armadura base en las formas de combate según nivel y defensa.", "Improves base armor in combat forms based on level and defense."},
  {"Combate feral", "Shredding Attacks", "Ataques trituradores", "Abarata Triturar y Lacerar.", "Reduces the costs of Shred and Lacerate."},
  {"Combate feral", "Savage Fury", "Furia salvaje", "Potencia ataques ferales de gato y oso.", "Boosts selected Cat and Bear attacks."},
  {"Combate feral", "Feral Charge", "Carga feral", "Acerca al enemigo; oso interrumpe e inmoviliza, gato salta a su espalda.", "Closes distance; Bear interrupts and roots, Cat leaps behind the enemy."},
  {"Combate feral", "Sharpened Claws", "Garras afiladas", "Mejora los críticos en forma felina y de oso.", "Raises critical chance in Cat and Bear forms."},
  {"Combate feral", "Predatory Strikes", "Golpes depredadores", "Aumenta el poder de ataque en las formas ferales según tu nivel.", "Increases feral attack power based on level."},
  {"Combate feral", "Lacerate", "Lacerar", "Sangrado acumulable de oso que genera amenaza elevada.", "Stacking Bear bleed that generates high threat."},
  {"Combate feral", "Predatory Discipline", "Disciplina depredadora", "Mordedura feroz aprovecha la energía sobrante para daño sin consumirla adicionalmente.", "Ferocious Bite benefits from excess Energy without spending that excess."},
  {"Combate feral", "Blood Frenzy", "Frenesí sangriento", "Los críticos generan ira extra en oso o puntos de combo extra en ataques directos de gato compatibles.", "Crits grant bonus Rage in Bear or bonus combo points from eligible direct Cat attacks."},
  {"Combate feral", "Leader of the Pack", "Líder de la manada", "Aura de crítico para aliados cercanos en forma felina o de oso.", "Crit aura for nearby allies in Cat or Bear form."},
  {"Combate feral", "Natural Instinct", "Instinto natural", "Mejora el daño crítico cuerpo a cuerpo y la sanación según intelecto.", "Improves melee critical damage and healing based on Intellect."},
  {"Combate feral", "Rend and Tear", "Desgarrar y rasgar", "Potencia tus ataques contra enemigos que sangran.", "Boosts melee abilities against bleeding enemies."},
  {"Combate feral", "Natural Reaction", "Reacción natural", "Aumenta esquiva y puede generar ira al esquivar.", "Raises dodge and can grant Rage on dodges."},
  {"Combate feral", "Primal Bite", "Mordisco primigenio", "Mordisco de oso orientado a generar amenaza.", "Bear bite designed for high threat."},
  {"Combate feral", "Shifting Power", "Poder cambiante", "Convierte maná en energía; las reducciones del coste de cambio de forma también lo abaratan.", "Converts Mana to Energy; shapeshifting cost reductions also apply."},
  {"Restauración", "Nature's Focus", "Enfoque de la naturaleza", "Protege los lanzamientos Arcanos y de Naturaleza frente a golpes.", "Protects Arcane and Nature casts from damage pushback."},
  {"Restauración", "Heart of the Wild", "Corazón de lo Salvaje", "Mejora intelecto, aguante de oso y fuerza de gato.", "Boosts Intellect, Bear Stamina and Cat Strength."},
  {"Restauración", "Naturalist", "Naturalista", "Potencia todo el daño y acelera Toque de sanación y Crecimiento salvaje.", "Boosts all damage and speeds Healing Touch and Wild Growth."},
  {"Restauración", "Reflection", "Reflejo", "Conserva parte de la regeneración de maná al lanzar hechizos.", "Retains some Mana regeneration while casting."},
  {"Restauración", "Natural Shapeshifter", "Cambio de forma natural", "Reduce el maná necesario para cambiar de forma.", "Lowers the Mana cost of shapeshifting."},
  {"Restauración", "Subtlety", "Sutileza", "Reduce la amenaza de los hechizos Arcanos y de Naturaleza.", "Lowers threat from Arcane and Nature spells."},
  {"Restauración", "Gift of Nature", "Don de la naturaleza", "Potencia la sanación de todos tus hechizos.", "Improves all your healing spells."},
  {"Restauración", "Bloom", "Floración", "Rejuvenecimiento o Recrecimiento sanan al terminar; disiparlos produce una curación menor basada en espíritu.", "Rejuvenation or Regrowth heal on expiration; dispelling triggers a smaller Spirit-based heal."},
  {"Restauración", "Tranquil Spirit", "Espíritu sosegado", "Abarata Toque de sanación y Tranquilidad.", "Lowers Healing Touch and Tranquility mana costs."},
  {"Restauración", "Improved Rejuvenation", "Rejuvenecimiento mejorado", "Refuerza la sanación de Rejuvenecimiento.", "Boosts Rejuvenation healing."},
  {"Restauración", "Swiftmend", "Alivio presto", "Sana al instante a un objetivo con tu Rejuvenecimiento o Recrecimiento sin consumirlo.", "Instantly heals a target with your Rejuvenation or Regrowth without consuming it."},
  {"Restauración", "Nature's Swiftness", "Presteza de la naturaleza", "Vuelve instantáneo el siguiente hechizo de Naturaleza.", "Makes your next Nature spell instant."},
  {"Restauración", "Living Spirit", "Espíritu vivo", "Aumenta el espíritu.", "Raises Spirit."},
  {"Restauración", "Improved Tranquility", "Tranquilidad mejorada", "Reduce la amenaza y el tiempo de reutilización de Tranquilidad.", "Lowers Tranquility threat and cooldown."},
  {"Restauración", "Improved Regrowth", "Recrecimiento mejorado", "Mejora la probabilidad de crítico de Recrecimiento.", "Raises Regrowth critical chance."},
  {"Restauración", "Wild Growth", "Crecimiento salvaje", "Sana al objetivo y su grupo cercano durante varios segundos, más intensamente al principio.", "Heals the target and nearby party over time, strongest at the start."},
}
local variantesDruida = {
  ["Starlight Wrath"]={"Ira estelar"},
  ["Nature's Majesty"]={"Majestuosidad de la naturaleza"},
  ["Feral Swiftness"]={"Rapidez feral","Velocidad feral"},
  ["Reflection"]={"Refracción"},
  ["Natural Shapeshifter"]={"Metamorfosis natural"},
  ["Gift of Nature"]={"Regalo de la Naturaleza"},
  ["Bloom"]={"Florecer"},
  ["Swiftmend"]={"Arreglo rápido"},
  ["Nature's Swiftness"]={"Rapidez de la Naturaleza"},
  ["Dreamstate"]={"Estado onírico"},
  ["Overgrowth"]={"Crecimiento excesivo"},
}
local resumenesDruida, aliasDruida = {}, {}
for _, e in ipairs(datosDruida) do
  local par, nombres = {e[4],e[5]}, {Normalizar(e[2]),Normalizar(e[3])}
  for _,nombre in ipairs(variantesDruida[e[2]] or {}) do nombres[#nombres+1]=Normalizar(nombre) end
  for _,nombre in ipairs(nombres) do
    resumenesDruida[nombre]=par
    aliasDruida[nombre]=nombres
  end
end
  return resumenesDruida, aliasDruida
end

-- R12: mantener solo los índices de resúmenes y alias de la clase consultada.
-- Los constructores conservan todos los datos de origen; no se comparte estado con los planes.
local constructoresR12 = {
  WARRIOR = CrearResumenesGuerrero, PALADIN = CrearResumenesPaladin,
  HUNTER = CrearResumenesCazador, ROGUE = CrearResumenesPicaro,
  PRIEST = CrearResumenesSacerdote, SHAMAN = CrearResumenesChaman,
  MAGE = CrearResumenesMago, WARLOCK = CrearResumenesBrujo, DRUID = CrearResumenesDruida,
}
local claseResumenR12, resumenR12, aliasR12
ResumenesClaseR12 = function(clase)
  if clase ~= claseResumenR12 then
    local crear = constructoresR12[clase]
    if not crear then return nil, nil end
    resumenR12, aliasR12 = crear()
    claseResumenR12 = clase
  end
  return resumenR12, aliasR12
end

function GL.ResumenTalento(t)
  if not GL.RUTA or not t then return nil end
  if GL.RUTA.clase == "WARRIOR" then return GL.ResumenTalentoGuerrero(t) end
  local datos = ResumenesClaseR12(GL.RUTA.clase)
  if not datos then return nil end
  local a, b = NombresDelPlan(t)
  local par = datos[a] or datos[b]
  if not par then return nil end
  return (GL.ingles and "Guide summary: " or "Resumen de la guía: ") .. par[GL.ingles and 2 or 1]
end

-- 9.7.9.2: nombres que en el árbol de Forever son otros (sacados de /ga informe › TALENTOS de Quini, guerrero 25).
-- Clave y valores normalizados (Normalizar). Se prueban después del nombre del plan en los dos idiomas.
local ALIAS = {
  lightningmastery = { "maestriaderelampago" },
  ultimorecurso = { "ultimaposicion" }, laststand = { "ultimaposicion" },
  -- Nombres localizados del guerrero contrastados con el árbol de Forever (71139).
  golpeconmocionador = { "golpedeconcusion" }, concussionblow = { "golpedeconcusion" },
  controldelaira = { "controldefuria" }, angermanagement = { "controldefuria" },
  cargarmejorado = { "embestirmejorado" }, improvedcharge = { "embestirmejorado" },
  empalar = { "clavar" }, impale = { "clavar" },
  emociondesangre = { "fragordelasangre" }, bloodthrill = { "fragordelasangre" },
  coleradesenfrenada = { "coleradesbocada" }, unbridledwrath = { "coleradesbocada" },
  locurasangrienta = { "maniasangrienta" }, bloodcraze = { "maniasangrienta" },
  aullidoperforador = { "aullidopenetrante" }, piercinghowl = { "aullidopenetrante" },
  especializacionendoblearma = { "especializacionendobleempunadura" }, dualwieldspecialization = { "especializacionendobleempunadura" },
  benediction = { "oracion", "bendicion" }, sacredarbiter = { "enjuiciadorsagrado", "arbitrosagrado" },
  unsealedwrath = { "coleradesellada", "coleradesatada" }, vindication = { "reivindicacion", "vindicacion" },
  healinglight = { "luzcurativa", "luzsanadora" }, redoubt = { "baluarte", "reducto" },
  templarsbulwark = { "baluartedetemplario", "baluartedeltemplario" },
  swiftjudgement = { "juiciopresto", "sentenciaveloz", "sentenciarapida" },
  reckoning = { "lahoradelaverdad", "desagravio" }, ironcreed = { "credoferreo", "credodehierro" },
  shieldsworn = { "juramentodeescudo", "juramentodelescudo" },

}
-- Un nombre o alias solo identifica un talento si todas las coincidencias apuntan a la misma entrada.
local function BuscarNodo(mapa, t)
  local ids = { "nodeID", "entryID", "spellID", "definitionID", "treeID" }
  local campos = { nodeID = "nodo", entryID = "entrada", spellID = "spellID", definitionID = "definitionID", treeID = "arbol" }
  local explicito = false
  for _, k in ipairs(ids) do if t[k] ~= nil then explicito = true end end
  if explicito then
    if not (t.nodeID or t.entryID or t.spellID or t.definitionID) then return nil end
    for _, k in ipairs(ids) do
      local v = t[k]
      if v ~= nil and (type(v) ~= "number" or v <= 0 or v >= math.huge or v % 1 ~= 0) then return nil end
    end
    local elegido
    for _, dato in ipairs(mapa.entradas) do
      local coincide = true
      for _, k in ipairs(ids) do
        if t[k] ~= nil and t[k] ~= dato[campos[k]] then coincide = false; break end
      end
      if coincide then
        if elegido then return nil end
        elegido = dato
      end
    end
    return elegido -- No degradar un ID explícito incorrecto a nombre o icono.
  end
  local es, en = NombresDelPlan(t)
  local elegido, ambiguo
  local function Considerar(clave)
    if not clave or clave == "" then return end
    local dato = mapa.nombres[clave]
    if dato == false or (dato and elegido and elegido ~= dato) then ambiguo = true
    elseif dato then elegido = dato end
  end
  Considerar(es); Considerar(en)
  if ambiguo then return nil end
  if elegido then return elegido end
  local alias
  if GL.RUTA and (GL.RUTA.clase == "WARLOCK" or GL.RUTA.clase == "DRUID") then
    local _, variantes = ResumenesClaseR12(GL.RUTA.clase)
    alias = variantes
  end
  for _, clave in ipairs({ es, en }) do
    if alias then
      for _, otro in ipairs(alias[clave] or {}) do Considerar(otro) end
    end
    for _, otro in ipairs(ALIAS[clave] or {}) do Considerar(otro) end
  end
  if not ambiguo then return elegido end
end

-- Orden de los puntos del plan: { talento, rango } uno por punto.
local function Secuencia()
  local lista, hecho = {}, {}
  local talentos = GL.RUTA and GL.RUTA.talentos or {}
  for i = 1, #talentos do
    local t = talentos[i]
    local hasta = tonumber(string.match(t.puntos or "", "^(%d+)")) or 0
    local desde = hecho[t.nombre] or 0
    for r = desde + 1, hasta do table.insert(lista, { t = t, rango = r }) end
    if hasta > desde then hecho[t.nombre] = hasta end
  end
  return lista
end

------------------------------------------------------------------------
-- Árbol de talentos del personaje
------------------------------------------------------------------------
local function IdConfigR14(v)
  if type(issecretvalue) == "function" then
    local ok, secreto = pcall(issecretvalue, v)
    if not ok or secreto then return false end
  end
  return type(v)=="number" and v>0 and v<math.huge and v%1==0
end
local function ConfigValida(id)
  if not IdConfigR14(id) or not (C_Traits and C_Traits.GetConfigInfo) then return nil end
  local ok, info = pcall(function()
    local dato = C_Traits.GetConfigInfo(id)
    if issecretvalue and issecretvalue(dato) then return nil end
    if type(dato)=="table" and type(dato.treeIDs)=="table" and #dato.treeIDs>0 then return dato end
  end)
  if ok and info then return id, info end
  return nil
end

-- El árbol activo: Forever tiene su propio tipo de configuración (CamelotCombat).
-- Solo se supone grupo 1 si la API de grupo no existe; una respuesta inválida no lo identifica.
local function Configuracion()
  local si = C_SpecializationInfo
  local grupo = 1
  if si and si.GetActiveSpecGroup ~= nil then
    if type(si.GetActiveSpecGroup) ~= "function" then return nil end
    local ok, g = pcall(si.GetActiveSpecGroup)
    if not ok or not IdConfigR14(g) then return nil end
    grupo = g
  end
  if si and si.GetCombatConfigIDForSpecGroup then
    local ok, id = pcall(si.GetCombatConfigIDForSpecGroup, grupo)
    local c, info = ConfigValida(ok and id)
    if c then return c, info, grupo end
    -- API de grupo disponible: no elegir otro árbol si no conocemos el activo.
    if si.GetActiveSpecGroup ~= nil then return nil end
  end
  if C_Traits and C_Traits.GetConfigsByType and Enum and Enum.TraitConfigType then
    local tipo = Enum.TraitConfigType.CamelotCombat or Enum.TraitConfigType.Combat
    local ok, ids = pcall(C_Traits.GetConfigsByType, tipo)
    if ok and type(ids) == "table" and #ids == 1 then
      for i = 1, #ids do
        local c, info = ConfigValida(ids[i])
        if c then return c, info, grupo end
      end
    end
  end
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
    local c, info = ConfigValida(ok and id)
    if c then return c, info, grupo end
  end
  return nil
end

-- No deducir especialización de cambios aún no confirmados por el jugador.
-- R13: una consulta fallida no demuestra que el árbol esté libre de cambios ajenos.
-- Sin esta API se conserva la compatibilidad histórica del cliente.
local function EstadoCambiosR13(config)
  if not (config and C_Traits and C_Traits.ConfigHasStagedChanges) then return false end
  local ok, hay = pcall(C_Traits.ConfigHasStagedChanges, config)
  if not ok then return nil end
  if type(issecretvalue) == "function" then
    local leido, secreto = pcall(issecretvalue, hay)
    if not leido or secreto then return nil end
  end
  if hay == true or hay == 1 then return true end
  if hay == false or hay == 0 then return false end
  return nil
end
local function CambiosPendientes(config)
  return EstadoCambiosR13(config) ~= false
end
function GL.TalentosCambiosPendientes()
  local config = Configuracion()
  if not config then return C_Traits and type(C_Traits.GetConfigInfo)=="function" or false end
  return CambiosPendientes(config)
end

-- Nombre e icono (número de archivo) del talento de una entrada del árbol.
local function NombreNodo(config, entrada)
  local ok, e = pcall(C_Traits.GetEntryInfo, config, entrada)
  if not ok or type(e) ~= "table" or not e.definitionID then return nil end
  local ok2, d = pcall(C_Traits.GetDefinitionInfo, e.definitionID)
  if not ok2 or type(d) ~= "table" then return nil end
  local icono = d.overrideIcon
  if (not icono or icono == 0) and d.spellID and C_Spell and C_Spell.GetSpellTexture then
    local ok3, t = pcall(C_Spell.GetSpellTexture, d.spellID)
    if ok3 then icono = t end
  end
  if d.overrideName and d.overrideName ~= "" then return d.overrideName, icono, d.spellID, e.definitionID end
  if d.spellID and C_Spell and C_Spell.GetSpellName then
    local ok3, n = pcall(C_Spell.GetSpellName, d.spellID)
    if ok3 then return n, icono, d.spellID, e.definitionID end
  end
  return nil, icono, d.spellID, e.definitionID
end

-- Índice de todas las entradas visibles: las colisiones no se resuelven por orden de recorrido.
-- Un icono, incluso único, no prueba identidad; se conserva solo como dato visual del talento identificado.
local function MapaNodos(config, info)
  local mapa = { nombres = {}, entradas = {} }
  local vistos = {}
  for _, arbol in ipairs(info.treeIDs) do
    local ok, nodos = pcall(C_Traits.GetTreeNodes, arbol)
    if not ok or type(nodos) ~= "table" then return nil end
    for _, nodo in ipairs(nodos) do
      local ok2, n = pcall(C_Traits.GetNodeInfo, config, nodo)
      if not ok2 or type(n) ~= "table" then return nil end
      if n.ID and n.ID ~= 0 and n.isVisible ~= false then
        if type(n.entryIDs) ~= "table" then return nil end
        for _, entrada in ipairs(n.entryIDs) do
          local identidad = nodo .. ":" .. entrada
          if not vistos[identidad] then
            vistos[identidad] = true
            local nombre, icono, spellID, definitionID = NombreNodo(config, entrada)
            if not definitionID then return nil end
            local dato = { nodo = nodo, entrada = entrada, nombre = nombre, icono = (icono ~= 0) and icono or nil, spellID = spellID, definitionID = definitionID, arbol = arbol }
            mapa.entradas[#mapa.entradas + 1] = dato
            local clave = Normalizar(nombre)
            if clave ~= "" then
              if mapa.nombres[clave] == nil then mapa.nombres[clave] = dato
              else mapa.nombres[clave] = false end
            end
          end
        end
      end
    end
  end
  return mapa
end

local function PuntosLibres(config, info)
  if not C_Traits.GetTreeCurrencyInfo then return nil end
  local total, alguno = 0, false
  for _, arbol in ipairs(info.treeIDs) do
    local ok, monedas = pcall(C_Traits.GetTreeCurrencyInfo, config, arbol, false)
    if not ok or type(monedas) ~= "table" then return nil end
    for _, m in ipairs(monedas) do
      if type(m) ~= "table" then return nil end
      local q = m.quantity
      if (issecretvalue and issecretvalue(q)) or type(q) ~= "number" or q < 0 or q >= math.huge or q % 1 ~= 0 then return nil end
      total = total + q; alguno = true
    end
  end
  return alguno and total or nil
end

local function RangoValido(v)
  return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v >= 0 and v < math.huge and v % 1 == 0
end

local function RangoActual(config, nodo)
  local ok, n = pcall(C_Traits.GetNodeInfo, config, nodo)
  if not ok or type(n) ~= "table" then return 0, nil end
  local rango = n.ranksPurchased
  if issecretvalue and issecretvalue(rango) then return 0, nil end
  if rango == nil then rango = n.currentRank end
  if not RangoValido(rango) then return 0, nil end
  return rango, n
end

-- La ventana de talentos del juego aplica con C_ClassTalents.CommitConfig (con la configuración guardada que
-- tengas elegida); si el árbol no es ese, se usa el sistema general de rasgos.
local function Guardada()
  local ct = C_ClassTalents
  if not (ct and ct.GetLastSelectedSavedConfigID and PlayerUtil and PlayerUtil.GetCurrentSpecID) then return nil end
  local ok, spec = pcall(PlayerUtil.GetCurrentSpecID)
  if not ok or not spec then return nil end
  local ok2, id = pcall(ct.GetLastSelectedSavedConfigID, spec)
  if ok2 and type(id) == "number" and id > 0 then return id end
  return nil
end

local function Aplicar(config)
  local ct = C_ClassTalents
  if ct and ct.CommitConfig and ct.GetActiveConfigID then
    local okA, activa = pcall(ct.GetActiveConfigID)
    if okA and activa == config then
      local guardada = Guardada()
      if guardada == config then guardada = nil end
      local ok, r = pcall(ct.CommitConfig, guardada)
      if ok and r then return true end
    end
  end
  if C_Traits.CommitConfig then
    local ok, r = pcall(C_Traits.CommitConfig, config)
    if ok and r then return true end
  end
  return false
end

------------------------------------------------------------------------
-- Poner los puntos libres siguiendo el plan
------------------------------------------------------------------------
-- manual = true cuando lo pide el jugador (botón o comando): entonces explica también por qué no hace nada.
local function PonerTalentos(manual)
  local function Decir(t) if manual then GL.Mensaje(t) end end
  if not manual and not Activo() then return 0 end
  if not (GL.RUTA and GL.RUTA.talentos and #GL.RUTA.talentos > 0) then return 0 end
  if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
    local contexto = ContextoAutomatico(manual)
    -- Un intento automático no debe reemplazar una petición explícita del jugador.
    if contexto and (manual or not pendiente or not pendiente.manual) then pendiente = contexto end
    Decir(L"estás en combate: pongo los talentos al salir.")
    return 0
  end
  if not (C_Traits and C_Traits.PurchaseRank and C_Traits.GetNodeInfo) then
    Decir(L"este cliente no deja poner talentos desde un addon: ponlos a mano siguiendo la pestaña Talentos.")
    return 0
  end
  local config, info = Configuracion()
  if not config then
    Decir(L"no encuentro tu árbol de talentos: ponlos a mano siguiendo la pestaña Talentos.")
    return 0
  end
  local estadoCambios = EstadoCambiosR13(config)
  if estadoCambios ~= false then
    if estadoCambios == true then
      Decir(L"tienes cambios sin aplicar en la ventana de talentos: aplícalos o deshazlos y vuelve a probar.")
    else
      Decir(L"No se pudo comprobar si hay cambios de talentos sin aplicar. Vuelve a intentarlo o ponlos a mano.")
    end
    return 0
  end
  local libres = PuntosLibres(config, info)
  -- 9.7.9.4: si el juego no dice cuántos puntos quedan (nil) se sigue como en la 9.7.9.3: manda CanPurchaseRank
  if libres == 0 then
    Decir(L"no tienes puntos de talento libres.")
    return 0
  end
  local mapa = MapaNodos(config, info)
  if not mapa then return 0 end
  local secuencia = Secuencia()
  local puestos, motivo = {}, nil
  local restantes = libres            -- nil si el juego no dice cuántos puntos quedan
  for _, paso in ipairs(secuencia) do
    if restantes and restantes <= 0 then break end
    local nodo = BuscarNodo(mapa, paso.t)
    local flexible = GL.RUTA.planFlexible   -- 9.4: especialización elegida; en Forever el árbol puede no tenerlo
    if not nodo then
      motivo = L"no encuentro el talento " .. paso.t.nombre .. L" en tu árbol"
      if not flexible then break end
    end
    local actual, n = 0, nil
    if nodo then
      actual, n = RangoActual(config, nodo.nodo)
      if not n then break end
      local activa = type(n.activeEntry) == "table" and n.activeEntry.entryID
      local tipoSeleccion = Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection ~= nil and n.type == Enum.TraitNodeType.Selection
      local seleccion = tipoSeleccion or (type(n.entryIDs) == "table" and #n.entryIDs > 1)
      -- Con varias entradas no comprar por ID de nodo si no podemos elegir la entrada.
      if actual < paso.rango and seleccion and not tipoSeleccion then
        motivo = L"no puedo poner " .. paso.t.nombre .. L" todavía"
        break
      end
      if actual > 0 and ((activa and activa ~= nodo.entrada) or (seleccion and not activa)) then
        motivo = L"no puedo poner " .. paso.t.nombre .. L" todavía"
        break
      end
    end
    local ok, puede = false, false
    if nodo and actual < paso.rango then
      -- No saltar rangos de un mismo talento aunque el plan sea flexible, ni confiar en una
      -- respuesta permisiva de la API si el nodo ya alcanzó el máximo del árbol real.
      local maximo = n.maxRanks
      local maximoConocido = RangoValido(maximo)
      if actual == paso.rango - 1 and (not maximoConocido or (actual < maximo and paso.rango <= maximo)) then
        ok, puede = pcall(C_Traits.CanPurchaseRank, config, nodo.nodo, nodo.entrada)
      end
    end
    if nodo and actual < paso.rango and not (ok and puede == true) then
      if (PuntosLibres(config, info) or 1) > 0 then motivo = L"no puedo poner " .. paso.t.nombre .. L" todavía" end
      if not flexible then break end
    elseif nodo and actual < paso.rango then
      local okP, hecho
      if n and n.type ~= nil and Enum and Enum.TraitNodeType and n.type == Enum.TraitNodeType.Selection then   -- 9.6: sin tipo no es «elegir uno»
        okP, hecho = pcall(C_Traits.SetSelection, config, nodo.nodo, nodo.entrada)
      else
        okP, hecho = pcall(C_Traits.PurchaseRank, config, nodo.nodo)
      end
      if not (okP and hecho) then
        motivo = L"el juego no me deja poner " .. paso.t.nombre
        break
      end
      table.insert(puestos, paso)
      if restantes then restantes = restantes - 1 end
    end
  end
  if #puestos == 0 then
    if motivo then
      -- también en automático, pero una sola vez por nivel, para que sepas que hay que ponerlo a mano
      local nivel = (UnitLevel and UnitLevel("player")) or 0
      if manual or avisado ~= nivel then
        avisado = nivel
        GL.Mensaje(motivo .. L". Ponlo a mano o revisa la pestaña Talentos.")
      end
    else
      Decir(L"ya tienes puestos todos los talentos del plan para tus puntos.")
    end
    return 0
  end
  if not Aplicar(config) then
    if C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, config) end
    aplicando, configAplicando, rutaAplicando, planAplicando = nil, nil, nil, nil
    GL.Mensaje(L"no he podido aplicar los talentos. Ponlos a mano: " .. puestos[1].t.nombre ..
      (#puestos > 1 and (L" y " .. (#puestos - 1) .. L" punto(s) más de la pestaña Talentos.") or "."))
    return 0
  end
  -- resumen: "Descarga de Escarcha mejorada 3/5"
  local partes, visto = {}, {}
  for _, paso in ipairs(puestos) do
    local maximo = string.match(paso.t.puntos or "", "/(%d+)") or "?"
    local nombre = string.match(paso.t.nombre, "^(.-)%s*%(") or paso.t.nombre
    visto[nombre] = paso.rango .. "/" .. maximo
  end
  for _, paso in ipairs(puestos) do
    local nombre = string.match(paso.t.nombre, "^(.-)%s*%(") or paso.t.nombre
    if visto[nombre] then table.insert(partes, nombre .. " " .. visto[nombre]); visto[nombre] = nil end
  end
  aplicando = (GetTime and GetTime()) or 0
  configAplicando, rutaAplicando, planAplicando = config, GL.RUTA, GL.RUTA.talentos
  generacionAplicando = generacionAuto
  GL.Mensaje(L"talentos de la guía puestos: " .. table.concat(partes, ", ") .. ".")
  if motivo then GL.Mensaje(motivo .. L": ponlo a mano o revisa la pestaña Talentos.") end
  if GL.Refrescar then GL.Refrescar() end
  return #puestos
end

function GL.PonerTalentos(manual)
  if poniendo then return 0 end
  poniendo = true
  local ok, resultado = pcall(PonerTalentos, manual)
  poniendo = false
  if not ok then error(resultado, 0) end
  return resultado
end

function GL.AutoTalentos() return Activo() end

-- 9.6: puntos libres para la tarjeta «Ahora» de la pestaña Talentos (nil si el juego no lo dice)
function GL.PuntosTalentoLibres()
  if not (C_Traits and C_Traits.GetConfigInfo) then return nil end
  local ok, config, info = pcall(Configuracion)
  if not ok or not config or type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end
  if CambiosPendientes(config) then return nil end
  local ok2, n = pcall(PuntosLibres, config, info)
  if ok2 then return n end
  return nil
end
GL.Normalizar = Normalizar

-- 9.7.7.1: puntos que tienes de verdad en cada rama. Quini tenía 12 puntos en Furia y la guía seguía el plan de
-- Armas (los puntos de las ramas eran los del plan). Cada talento con puntos se asigna a una rama por su nombre
-- (plan de la ruta y talentos clave de las especializaciones); si el juego da un árbol por rama, los que no
-- salen por nombre van a la rama de su árbol. Devuelve { ramas = { [rama] = puntos }, total = n } o nil.
local function RamasPorNombre()
  local mapa = {}
  local function Poner(nombre, rama)
    if type(nombre) ~= "string" or type(rama) ~= "string" then return end
    local es, en = string.match(nombre, "^(.-)%s*%((.-)%)%s*$")
    for _, n in ipairs({ es or nombre, en }) do
      if n and n ~= "" then local k = Normalizar(n); if mapa[k] == nil then mapa[k] = rama elseif mapa[k] ~= rama then mapa[k] = false end end
    end
  end
  -- Cazador: los puntos fuera de los tres planes también cuentan si el nombre coincide.
  -- No inferir equivalencias para traducciones sin confirmar ni para talentos retirados.
  if GL.RUTA and GL.RUTA.clase == "HUNTER" then
    for _, e in ipairs(datosCazador) do Poner(e[3] .. " (" .. e[2] .. ")", GL.L(e[1])) end
  elseif GL.RUTA and GL.RUTA.clase == "ROGUE" then
    for _, e in ipairs(datosPicaro) do Poner(e[3] .. " (" .. e[2] .. ")", GL.L(e[1])) end
  elseif GL.RUTA and GL.RUTA.clase == "PRIEST" then
    for _, e in ipairs(datosSacerdote) do Poner(e[3] .. " (" .. e[2] .. ")", GL.L(e[1])) end
  elseif GL.RUTA and GL.RUTA.clase == "SHAMAN" then
    for _, e in ipairs(datosChaman) do
      Poner(e[3] .. " (" .. e[2] .. ")", GL.L(e[1]))
      for _, nombre in ipairs(variantesChaman[e[2]] or {}) do Poner(nombre, GL.L(e[1])) end
    end
  elseif GL.RUTA and GL.RUTA.clase == "MAGE" then
    for _, e in ipairs(datosMago) do Poner(e[3] .. " (" .. e[2] .. ")", GL.L(e[1])) end
  elseif GL.RUTA and GL.RUTA.clase == "WARLOCK" then
    for _, e in ipairs(datosBrujo) do
      Poner(e[3] .. " (" .. e[2] .. ")", GL.L(e[1]))
      for _, nombre in ipairs(variantesBrujo[e[2]] or {}) do Poner(nombre, GL.L(e[1])) end
    end
  elseif GL.RUTA and GL.RUTA.clase == "DRUID" then
    for _, e in ipairs(datosDruida) do
      Poner(e[3] .. " (" .. e[2] .. ")", GL.L(e[1]))
      for _, nombre in ipairs(variantesDruida[e[2]] or {}) do Poner(nombre, GL.L(e[1])) end
    end
  end
  -- primero el plan original de la ruta (rama segura), después el plan en uso y las especializaciones
  for _, t in ipairs((GL.TalentosDeLaGuia and GL.TalentosDeLaGuia()) or {}) do Poner(t.nombre, t.rama) end
  for _, t in ipairs((GL.RUTA and GL.RUTA.talentos) or {}) do Poner(t.nombre, t.rama) end
  local clase = UnitClass and select(2, UnitClass("player"))
  for _, e in ipairs((GL.ESPECIALIZACIONES or {})[clase or ""] or {}) do
    for _, p in ipairs(e.plan or {}) do Poner(p[1], GL.L(p[3] or e.rama)) end
  end
  return mapa
end

local function PuntosRealesPorRama()
  if not (C_Traits and C_Traits.GetNodeInfo and C_Traits.GetTreeNodes) then return nil end
  local ok, config, info = pcall(Configuracion)
  if not ok or not config or type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end
  if CambiosPendientes(config) then return nil end
  local porNombre = RamasPorNombre()
  local ramas, total, alguno, vistos = {}, 0, false, {}
  local rangosPorNombre, sinClasificar = {}, 0
  for _, arbol in ipairs(info.treeIDs) do
    local okN, nodos = pcall(C_Traits.GetTreeNodes, arbol)
    if okN and type(nodos) == "table" then
      local sinRama = 0
      for _, nodo in ipairs(nodos) do
        local okI, n = pcall(C_Traits.GetNodeInfo, config, nodo)
        if not okI or type(n) ~= "table" then return nil end
        if n.ID and n.ID ~= 0 and n.isVisible ~= false and not vistos[n.ID] then
          vistos[n.ID] = true
          alguno = true
          local rango = n.ranksPurchased
          if issecretvalue and issecretvalue(rango) then return nil end
          if rango == nil then rango = n.currentRank end
          if not RangoValido(rango) then return nil end
          local entrada = type(n.activeEntry) == "table" and n.activeEntry.entryID or nil
          if not entrada and type(n.entryIDs) == "table" and #n.entryIDs == 1 then entrada = n.entryIDs[1] end
          if rango > 0 and not entrada then return nil end
          local nombre = entrada and NombreNodo(config, entrada)
          local rama = nombre and porNombre[Normalizar(nombre)]
          if rango > 0 then
            total = total + rango
            if nombre then local clave = Normalizar(nombre); rangosPorNombre[clave] = (rangosPorNombre[clave] or 0) + rango end
            if rama then ramas[rama] = (ramas[rama] or 0) + rango else sinRama = sinRama + rango end
          end
        end
      end
      -- Los puntos desconocidos cuentan en el total, pero no son evidencia de ninguna rama.
      sinClasificar = sinClasificar + sinRama
    else return nil end
  end
  if not alguno then return nil end
  return { ramas = ramas, total = total, rangosPorNombre = rangosPorNombre, sinClasificar = sinClasificar }
end

-- 9.7.4: lo que llevas puesto de verdad. Para cada fila del plan, si ya tiene en tu árbol los puntos que pide
-- (aunque los pusieras antes de tiempo o en otro orden). Devuelve nil si el juego no deja leer el árbol:
-- entonces la pestaña sigue el plan por nivel, como antes.
function GL.PuntosRealesPorRama()
  local ok, resultado = pcall(PuntosRealesPorRama)
  if ok then return resultado end
end

local function EstadoTalentosReal()
  local talentos = GL.RUTA and GL.RUTA.talentos
  if not (talentos and #talentos > 0 and C_Traits and C_Traits.GetNodeInfo and C_Traits.GetTreeNodes) then return nil end
  local ok, config, info = pcall(Configuracion)
  if not ok or not config or type(info) ~= "table" then return nil end
  if CambiosPendientes(config) then return nil end
  local okM, mapa = pcall(MapaNodos, config, info)
  if not okM or type(mapa) ~= "table" then return nil end
  -- 9.7.9.1 (Quini, guerrero tanque): cada fila lleva el icono de verdad de tu árbol, y la que no está en tu árbol
  -- (no existe en Forever o se llama distinto) se marca «falta» y no bloquea el siguiente talento.
  local hecho, rango, icono, falta, comprable = {}, {}, {}, {}, {}
  local nombres, descripciones = {}, {}
  local locale = GetLocale and GetLocale()
  local mismoIdioma = (GL.ingles and (locale == "enUS" or locale == "enGB")) or (not GL.ingles and (locale == "esES" or locale == "esMX"))
  for i, t in ipairs(talentos) do
    local nodo = BuscarNodo(mapa, t)
    local quiere = tonumber(string.match(t.puntos or "", "^(%d+)")) or 1
    if nodo then
      if mismoIdioma then
        nombres[i] = nodo.nombre
        if nodo.spellID and C_Spell and C_Spell.GetSpellDescription then
          local okD, desc = pcall(C_Spell.GetSpellDescription, nodo.spellID)
          if okD and type(desc) == "string" and not (issecretvalue and issecretvalue(desc)) and desc ~= "" then descripciones[i] = desc end
        end
      end
      icono[i] = nodo.icono
      local actual, estado = RangoActual(config, nodo.nodo)
      if not estado then return nil end
      local comprado = estado.ranksPurchased
      if issecretvalue and issecretvalue(comprado) then return nil end
      if comprado ~= nil then
        if not RangoValido(comprado) then return nil end
        actual = comprado
      end
      local activa = type(estado.activeEntry) == "table" and estado.activeEntry.entryID
      local seleccion = (Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection ~= nil and estado.type == Enum.TraitNodeType.Selection) or (type(estado.entryIDs) == "table" and #estado.entryIDs > 1)
      if (activa and activa ~= nodo.entrada) or (not activa and seleccion) then actual = 0 end
      rango[i] = actual
      hecho[i] = actual >= quiere
      if not hecho[i] and C_Traits.CanPurchaseRank then
        local okP, puede = pcall(C_Traits.CanPurchaseRank, config, nodo.nodo, nodo.entrada)
        comprable[i] = okP and puede == true
      end
    else
      hecho[i] = false
      falta[i] = true
    end
  end
  if #mapa.entradas == 0 then return nil end
  local primero
  local completo = true
  for i = 1, #talentos do if not hecho[i] then completo = false; break end end
  local libres = PuntosLibres(config, info)
  for i = 1, #talentos do
    if not hecho[i] and not falta[i] and (not libres or libres == 0 or not C_Traits.CanPurchaseRank or comprable[i]) then primero = i; break end
  end
  return { hecho = hecho, rango = rango, primero = primero, completo = completo, icono = icono, falta = falta, libres = libres, comprable = comprable, nombres = nombres, descripciones = descripciones }
end

-- 9.7.9.1: para /ga informe (Informe.lua): qué talentos del plan están en tu árbol y qué tienes puesto de verdad.
function GL.DiagnosticoTalentos979()
  local talentos = GL.RUTA and GL.RUTA.talentos
  if not (talentos and C_Traits and C_Traits.GetNodeInfo and C_Traits.GetTreeNodes) then return nil end
  local ok, config, info = pcall(Configuracion)
  if not ok or not config or type(info) ~= "table" then return nil end
  if CambiosPendientes(config) then return nil end
  local okM, mapa = pcall(MapaNodos, config, info)
  if not okM or type(mapa) ~= "table" then return nil end
  local fuera, vistos = {}, {}
  for _, t in ipairs(talentos) do
    if not BuscarNodo(mapa, t) and not vistos[t.nombre] then vistos[t.nombre] = true; table.insert(fuera, t.nombre) end
  end
  local puestos, resto = {}, {}
  for _, dato in ipairs(mapa.entradas) do
    local okR, n = pcall(C_Traits.GetNodeInfo, config, dato.nodo)
    if okR and type(n) == "table" then
      local r = n.ranksPurchased or n.currentRank
      local activa = type(n.activeEntry) == "table" and n.activeEntry.entryID
      if (activa and activa ~= dato.entrada) or (not activa and #n.entryIDs > 1) then r = 0 end
      local identidad = " [nodeID=" .. tostring(dato.nodo) .. "; entryID=" .. tostring(dato.entrada) ..
        "; spellID=" .. tostring(dato.spellID or "?") .. "; definitionID=" .. tostring(dato.definitionID or "?") ..
        "; treeID=" .. tostring(dato.arbol or "?") .. "]"
      if RangoValido(r) and r > 0 then
        table.insert(puestos, tostring(dato.nombre) .. " " .. r .. "/" .. tostring(n.maxRanks or "?") .. identidad)
      else
        table.insert(resto, tostring(dato.nombre) .. " 0/" .. tostring(n.maxRanks or "?") .. identidad)
      end
    end
  end
  table.sort(puestos); table.sort(resto)
  return { fuera = fuera, puestos = puestos, resto = resto }
end

function GL.EstadoTalentosReal()
  local ok, resultado = pcall(EstadoTalentosReal)
  if ok then return resultado end
end

-- Al cambiar los talentos (también a mano en la ventana del juego) se repinta la pestaña.
do
  local f = CreateFrame("Frame")
  for _, ev in ipairs({ "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED" }) do pcall(f.RegisterEvent, f, ev) end
  local esperando = false
  f:SetScript("OnEvent", function()
    if esperando then return end
    esperando = true
    local ejecutada = false
    local function ya()
      if ejecutada then return end
      ejecutada = true
      esperando = false
      if GL.ComprobarEspecializacionReal then pcall(GL.ComprobarEspecializacionReal) end   -- 9.7.7.1
      if GL.Refrescar then pcall(GL.Refrescar) end
    end
    if not (C_Timer and type(C_Timer.After)=="function" and pcall(C_Timer.After, 0.5, ya)) then ya() end
  end)
end

local function Intentar()
  if not Activo() then return end
  local ahora = (GetTime and GetTime()) or 0
  if ahora - ultimoIntento < 1 then return end
  ultimoIntento = ahora
  local ok, err = pcall(GL.PonerTalentos, false)
  if not ok and GL.Fallo("talentos", err) then GL.Mensaje(L"error: " .. tostring(err)) end
end

local function Despues(segundos, f)
  local ejecutada = false
  local function unaVez()
    if ejecutada then return end
    ejecutada = true
    f()
  end
  -- Si el temporizador existe pero falla, no adelantar una acción de talentos.
  if C_Timer and type(C_Timer.After)=="function" then
    local ok = pcall(C_Timer.After, segundos, unaVez)
    if not ok then ejecutada = true end
  else unaVez() end
end

-- Un trabajo diferido pertenece al plan y configuración que lo originaron.
ContextoAutomatico = function(manual)
  if not manual and not Activo() then return nil end
  local ruta, db = GL.RUTA, DB()
  if not ruta or not db then return nil end
  local config, _, grupo = Configuracion()
  if not config then return nil end
  local real = GL.PuntosRealesPorRama()
  return { ruta = ruta, plan = ruta.talentos, config = config, grupo = grupo, db = db,
    especializacion = db.especializacion, total = real and real.total, manual = manual == true,
    generacion = generacionAuto, generacionConfig = generacionConfigR14 }
end
ContextoVigente = function(c)
  if not (c and c.generacionConfig == generacionConfigR14 and c.db == DB() and c.db
    and c.especializacion == c.db.especializacion
    and (c.manual or (Activo() and c.generacion == generacionAuto)) and GL.RUTA == c.ruta and c.ruta.talentos == c.plan) then return false end
  local config, _, grupo = Configuracion()
  if not config or config ~= c.config or grupo ~= c.grupo or CambiosPendientes(config) then return false end
  local real = GL.PuntosRealesPorRama()
  if c.total and (not real or real.total < c.total) then return false end
  if real then c.total = real.total end
  return true
end
local function ProgramarIntento(segundos, contexto)
  if not contexto then return end
  Despues(segundos, function()
    if not ContextoVigente(contexto) then return end
    if contexto.manual then
      local ok, err = pcall(GL.PonerTalentos, true)
      if not ok and GL.Fallo("talentos", err) then GL.Mensaje(L"error: " .. tostring(err)) end
    else
      Intentar()
    end
  end)
end
function GL.ProgramarTalentosEspecializacion()
  if Activo() then
    ultimoIntento = -10
    ProgramarIntento(1, ContextoAutomatico())
  end
end

-- Tras un fallo, no aplicar ni deshacer cambios preparados: pueden incluir cambios manuales del jugador.
-- Solo se vuelve a ejecutar el plan si el árbol y la ruta siguen siendo los originales y no hay cambios pendientes.
local function Reintentar(ruta, configAnterior, planAnterior)
  if not (ruta and GL.RUTA == ruta and ruta.talentos == planAnterior and Activo()) then return end
  if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
  local ok, config = pcall(Configuracion)
  if not ok or not config or config ~= configAnterior or not (C_Traits and C_Traits.ConfigHasStagedChanges) then return end
  if EstadoCambiosR13(config) ~= false then
    GL.Mensaje(L"el juego no aplicó los talentos. Pulsa 'Poner talentos' en la pestaña Talentos o ponlos a mano.")
    return
  end
  ultimoIntento = -10
  local ok3, err = pcall(GL.PonerTalentos, false)
  if not ok3 and GL.Fallo("talentos", err) then GL.Mensaje(L"error: " .. tostring(err)) end
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "PLAYER_LEVEL_UP")
GL.Evento(eventos, "PLAYER_REGEN_ENABLED")
GL.Evento(eventos, "PLAYER_ENTERING_WORLD")
pcall(eventos.RegisterEvent, eventos, "CONFIG_COMMIT_FAILED")
for _, ev in ipairs({"ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LEAVING_WORLD"}) do
  pcall(eventos.RegisterEvent, eventos, ev)
end
eventos:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unidad = ...
    if unidad ~= nil and unidad ~= "player" then return end
  end
  if event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LEAVING_WORLD" then
    GL.CancelarContextoTalentosR14()
    return
  end
  if not GL.RUTA then return end
  if event == "PLAYER_LEVEL_UP" then
    -- el punto nuevo llega un momento después de subir: se prueba varias veces
    reintentos = 0
    local contexto = ContextoAutomatico()
    ProgramarIntento(2, contexto)
    ProgramarIntento(6, contexto)
    ProgramarIntento(12, contexto)
  elseif event == "CONFIG_COMMIT_FAILED" then
    -- el juego no aplicó lo que pidió la guía (por ejemplo, te moviste o entraste en combate): se reintenta una vez
    local ahora = (GetTime and GetTime()) or 0
    if aplicando and ahora - aplicando < 30 then
      local ruta, config, plan, g = rutaAplicando, configAplicando, planAplicando, generacionAplicando
      aplicando, configAplicando, rutaAplicando, planAplicando = nil, nil, nil, nil
      if g == generacionAuto and reintentos < 1 and ruta == GL.RUTA and ruta.talentos == plan and config and Activo() then
        reintentos = reintentos + 1
        GL.Mensaje(L"el juego no aplicó los talentos: lo intento otra vez en unos segundos.")
        local contexto = ContextoAutomatico()
        Despues(4, function()
          if g == generacionAuto and ContextoVigente(contexto) then Reintentar(ruta, config, plan) end
        end)
      else
        GL.Mensaje(L"el juego no aplicó los talentos. Pulsa 'Poner talentos' en la pestaña Talentos o ponlos a mano.")
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendiente then
      local contexto = pendiente
      pendiente = nil
      ProgramarIntento(1, contexto)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- al entrar solo se avisa: los puntos libres pueden ser a propósito
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    Despues(8, function()
      local libres = GL.PuntosTalentoLibres()
      if libres and libres > 0 then
        GL.Mensaje(L"tienes " .. libres .. L" punto(s) de talento libres. Pulsa 'Poner talentos' en la pestaña Talentos " ..
          L"para ponerlos como dice la guía.")
      end
    end)
  end
end)

GL.comandos["ponertalentos"] = function() GL.PonerTalentos(true) end
GL.comandos["autotalentos"] = function()
  local db = DB()
  if not db then return end
  db.autoTalentos = (db.autoTalentos == false)
  if not db.autoTalentos then GL.CancelarTalentosAutomaticos() end
  GL.Mensaje(db.autoTalentos and L"poner los talentos de la guía al subir de nivel: activado."
    or L"poner los talentos de la guía al subir de nivel: desactivado (usa el botón Poner talentos).")
end

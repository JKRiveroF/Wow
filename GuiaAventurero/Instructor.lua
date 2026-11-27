-- Instructor.lua: qué hechizos aprender en el instructor de clase, por orden de prioridad, y los aprende solo. Creado por JKRiveroF.
-- Los consejos vienen de la ruta (R.hechizos, en orden de prioridad) con el id del hechizo; el nombre se pide al juego.
-- R.entrenamiento dice qué rango se aprende a cada nivel en Forever: con eso la guía avisa al subir de nivel
-- y la pestaña Hechizos muestra lo que puedes aprender ya.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local ANCHO = 300
local MAX_LINEAS = 16
local MAX_OLEADAS = 6                  -- comprar un rango puede abrir el siguiente: se repite unas cuantas veces

local panel
local rutaConsejos
local consejos                         -- nombre del hechizo en el idioma del cliente -> { c, nota, prioridad }
local oleadas = 0                      -- compras automáticas hechas desde que abriste el instructor
local comprando = false                -- esperando a que el instructor actualice la lista tras comprar
local sesionInstructor = 0
local sesionAbierta, autoSesion = false, false
local rutaSesion, compraPendiente
local ejecutandoCompra = false


local ORDEN = { comprar = 1, opcional = 2, saltar = 3 }
-- 9.4.2: se traduce al usarla (al cargar el archivo aún no se sabe el idioma elegido en Ajustes)
local ETIQUETA_BASE = { comprar = { C.VERDE, "Compra" }, opcional = { C.AMARILLO, "Opcional" }, saltar = { C.GRIS, "Sáltalo" } }
local ETIQUETA = setmetatable({}, { __index = function(_, k)
  local e = ETIQUETA_BASE[k]
  return e and (e[1] .. L(e[2]) .. C.FIN) or nil
end })

local function DB() return GuiaAventureroDB end
local function AutoActivo() return DB().autoHechizos ~= false end

-- R14: no consumir valores opacos ni respuestas de un tipo inesperado.
local function PublicoInstructorR14(v)
  if type(issecretvalue) ~= "function" then return true end
  local ok, secreto = pcall(issecretvalue, v)
  return ok and not secreto
end
local function EnteroInstructorR14(v)
  return PublicoInstructorR14(v) and type(v)=="number" and v>=0 and v<math.huge and v%1==0
end
local function TextoInstructorR14(v)
  return PublicoInstructorR14(v) and type(v)=="string" and v~=""
end
local function NombreHechizo(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and TextoInstructorR14(n) then return n end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and TextoInstructorR14(n) then return n end
  end
  return nil
end

local function RangoHechizo(id)
  if C_Spell and C_Spell.GetSpellSubtext then
    local ok, r = pcall(C_Spell.GetSpellSubtext, id)
    if ok and PublicoInstructorR14(r) and type(r) == "string" then return r end
  end
  return ""
end

-- Consejos de leveo por especializacion de guerrero (no son restricciones del cliente).
-- Referencia: Mobalytics, Warrior Leveling Guide, 19-11-2026. Se conservan
-- habilidades de utilidad; los rangos de talento siguen exigiendo su desbloqueo real.
local consejosGuerrero = {
  Armas = {
    {1240193, "comprar", "Prioriza Embate con tu arma de dos manos.", "Prioritize Slam with your two-handed weapon."},
    {21551, "comprar", "Mejora Golpe mortal si ya has aprendido el talento.", "Upgrade Mortal Strike if you have learned the talent."},
    {674, "opcional", "Solo si decides usar dos armas.", "Only if you choose to dual wield."},
  },
  Furia = {
    {674, "comprar", "Aprende doble empuñadura para tu plan de Furia.", "Learn Dual Wield for your Fury plan."},
    {1240193, "opcional", "Embate es secundario en el plan de doble empuñadura.", "Slam is secondary in the dual-wield plan."},
    {23892, "comprar", "Mejora Sed de sangre tras desbloquear el talento.", "Upgrade Bloodthirst after unlocking the talent."},
    {21551, "opcional", "Solo si has elegido también Golpe mortal.", "Only if you have also chosen Mortal Strike."},
    {23923, "opcional", "Solo si has elegido también Embate con escudo.", "Only if you have also chosen Shield Slam."},
  },
  ["Protección"] = {
    {1160, "comprar", "Reduce el poder de ataque enemigo durante el tanqueo.", "Reduce enemy attack power while tanking."},
    {7405, "comprar", "Mantén la reducción de armadura cuando sea útil al grupo.", "Maintain armor reduction when useful to the group."},
    {72, "comprar", "Interrumpe lanzamientos cuando lleves escudo.", "Interrupt casts while using a shield."},
    {2565, "comprar", "Bloquea ataques y facilita Revancha.", "Block attacks and enable Revenge."},
    {871, "comprar", "Defensivo importante para encuentros difíciles.", "Important defensive for difficult encounters."},
    {6572, "comprar", "Prioriza Revancha como tanque.", "Prioritize Revenge as a tank."},
    {694, "comprar", "Herramienta de emergencia para recuperar un enemigo.", "Emergency tool to regain an enemy."},
    {1161, "comprar", "Control de emergencia para varios enemigos.", "Emergency control for multiple enemies."},
    {23923, "comprar", "Mejora Embate con escudo tras desbloquear el talento.", "Upgrade Shield Slam after unlocking the talent."},
    {1240193, "opcional", "Embate no es prioritario con arma y escudo.", "Slam is not a priority with a weapon and shield."},
    {21551, "opcional", "Solo si has elegido también Golpe mortal.", "Only if you have also chosen Mortal Strike."},
    {23892, "opcional", "Solo si has elegido también Sed de sangre.", "Only if you have also chosen Bloodthirst."},
  },
}
local function ConsejoGuerrero(nombre)
  if not GL.RUTA or GL.RUTA.clase ~= "WARRIOR" or not nombre then return nil end
  local rama = DB().especializacion or "Armas"
  for i, e in ipairs(consejosGuerrero[rama] or {}) do
    -- El nombre procede del ID en el idioma del cliente, no de una traduccion fija.
    if NombreHechizo(e[1]) == nombre then
      return { c = e[2], nota = GL.ingles and e[4] or e[3], prioridad = i }
    end
  end
end

-- Paladín: recomendaciones de leveo según función elegida (no requisitos de compra).
-- Referencias: WoW Forever Outpost, 9-11-2026; Mobalytics Ret/Protection, 17-11-2026.
-- Los rangos siguen sujetos a los requisitos del instructor y a los talentos aprendidos.
local consejosPaladin = {
  Sagrado = {
    {639,"comprar","Prioriza la cura grande para el grupo.","Prioritize your large group heal."},
    {19750,"comprar","Cura rápida para reaccionar al daño.","Fast heal to react to incoming damage."},
    {19742,"comprar","Recuperación de maná para combates largos.","Mana recovery for long encounters."},
    {1152,"comprar","Disipa venenos y enfermedades.","Remove poisons and diseases."},
    {4987,"comprar","Disipa también magia.","Also dispel magic."},
    {10322,"comprar","Mejora Redención si ya está desbloqueada.","Upgrade Redemption if unlocked."},
    {19746,"comprar","Reduce el retroceso al lanzar hechizos.","Reduce spellcasting pushback."},
    {20473,"comprar","Mejora Choque sagrado si ya tienes el talento.","Upgrade Holy Shock if talented."},
    {1311590,"comprar","Mejora Vigilia de la Luz si ya tienes el talento.","Upgrade Light's Vigil if talented."},
    {19752,"opcional","Sacrifica al paladín para proteger a un aliado; requiere el reactivo.","Sacrifice the paladin to protect an ally; requires the reagent."},
    {1022,"comprar","Protección física de emergencia para un aliado.","Emergency physical protection for an ally."},
    {1044,"comprar","Libera a un aliado de efectos de movimiento.","Free an ally from movement impairments."},
    {20217,"comprar","Bendición versátil para el grupo.","Versatile group blessing."},
    {25894,"comprar","Sabiduría superior para grupos.","Greater Wisdom for groups."},
    {25898,"comprar","Reyes superior para grupos.","Greater Kings for groups."},
    {20915,"opcional","Solo si también has desbloqueado Sello de orden.","Only if you also unlocked Seal of Command."},
    {20927,"opcional","Solo si también has desbloqueado Escudo sagrado.","Only if you also unlocked Holy Shield."},
  },
  ["Protección"] = {
    {25780,"comprar","Prioriza Furia justa para generar amenaza.","Prioritize Righteous Fury for threat."},
    {1311649,"comprar","Sello defensivo: daño Sagrado y absorción con escudo.","Defensive seal: Holy damage and absorption with a shield."},
    {26573,"comprar","Amenaza de área en grupos de enemigos.","Area threat against packs."},
    {7294,"comprar","Daño reactivo útil al tanquear varios enemigos.","Reactive damage when tanking packs."},
    {465,"comprar","Armadura adicional para mitigar daño físico.","Extra armor to mitigate physical damage."},
    {20927,"comprar","Mejora Escudo sagrado tras desbloquear el talento.","Upgrade Holy Shield after unlocking the talent."},
    {20217,"comprar","Bendición versátil de estadísticas.","Versatile stat blessing."},
    {19742,"comprar","Ayuda a mantener maná durante el tanqueo.","Helps sustain mana while tanking."},
    {21082,"opcional","Sello del cruzado; su Sentencia aumenta el daño Sagrado recibido por el objetivo.","Seal of the Crusader; its Judgement increases Holy damage taken by the target."},
    {19876,"opcional","Aura situacional de resistencia a sombras.","Situational Shadow resistance aura."},
    {19888,"opcional","Aura situacional de resistencia a escarcha.","Situational Frost resistance aura."},
    {19891,"opcional","Aura situacional de resistencia a fuego.","Situational Fire resistance aura."},
    {20915,"opcional","Solo si también has desbloqueado Sello de orden.","Only if you also unlocked Seal of Command."},
    {20473,"opcional","Solo si también has desbloqueado Choque sagrado.","Only if you also unlocked Holy Shock."},
  },
  ["Reprensión"] = {
    {20271,"comprar","Prioriza Sentencia; no consume el sello base.","Prioritize Judgement; it does not consume the base seal."},
    {679,"comprar","Prioriza Golpe sagrado con tu arma.","Prioritize Holy Strike with your weapon."},
    {20915,"comprar","Mejora Sello de orden si ya tienes el talento.","Upgrade Seal of Command if talented."},
    {19740,"comprar","Aumenta el poder de ataque.","Increase attack power."},
    {24275,"comprar","Remata enemigos con poca salud.","Finish low-health enemies."},
    {26573,"comprar","Daño de área para varios enemigos.","Area damage against several enemies."},
    {25780,"opcional","Solo para ocasiones en que debas generar amenaza.","Only for situations where you need threat."},
    {1311649,"opcional","Herramienta de tanqueo, secundaria para DPS.","Tank tool, secondary for DPS."},
    {19742,"opcional","Alternativa si necesitas maná.","Alternative if you need mana."},
    {20927,"opcional","Solo si también has desbloqueado Escudo sagrado.","Only if you also unlocked Holy Shield."},
    {20473,"opcional","Solo si también has desbloqueado Choque sagrado.","Only if you also unlocked Holy Shock."},
  },
}
local function ConsejoPaladin(nombre)
  if not GL.RUTA or GL.RUTA.clase ~= "PALADIN" or not nombre then return nil end
  local rama = DB().especializacion or "Reprensión"
  for i,e in ipairs(consejosPaladin[rama] or {}) do
    if NombreHechizo(e[1]) == nombre then
      return {c=e[2],nota=GL.ingles and e[4] or e[3],prioridad=i}
    end
  end
end

-- Prioridades orientativas por especialización de leveo, no restricciones del cliente.
-- Fuentes: Mobalytics (15-11-2026), WoW Forever Outpost, buildsforge.com/en/wow-forever/guides/hunter-leveling/.
-- Habilidades de talento conservan sus requisitos de instructor. No comprar lecciones de mascota automáticamente.
local consejosCazador = {
  Bestias = {
    {136,"comprar","Mantén viva a tu mascota durante el combate.","Keep your pet alive during combat."},
    {13165,"comprar","Potencia tus disparos a distancia.","Boost your ranged attacks."},
    {1978,"comprar","Aplica daño periódico en combates largos.","Apply periodic damage in longer fights."},
    {3044,"comprar","Disparo de daño Arcano.","Arcane damage shot."},
    {19434,"comprar","Disparo potente; utiliza según el maná y la situación.","Powerful shot; use according to mana and situation."},
    {13161,"opcional","Alternativa para combate cuerpo a cuerpo.","Alternative for melee combat."},
    {674,"opcional","Solo si eliges combatir con dos armas.","Only if you choose to dual wield."},
    {2973,"opcional","Ataque de emergencia si te alcanzan.","Emergency melee attack if enemies reach you."},
    {1495,"opcional","Ataque situacional cuerpo a cuerpo.","Situational melee attack."},
  },
  ["Puntería"] = {
    {19434,"comprar","Prioriza los rangos de este disparo de gran daño.","Prioritize ranks of this high-damage shot."},
    {13165,"comprar","Aumenta tu capacidad ofensiva a distancia.","Boost ranged offense."},
    {3044,"comprar","Refuerza tu daño a distancia.","Strengthen ranged damage."},
    {1978,"comprar","Daño periódico en objetivos que sobrevivan varios disparos.","Periodic damage on targets surviving several shots."},
    {1310687,"comprar","Mejora Disparo de francotirador si ya tienes el talento.","Upgrade Sniper Shot if talented."},
    {1299346,"comprar","Mejora Aura de disparo certero si ya tienes el talento.","Upgrade Trueshot Aura if talented."},
    {13161,"opcional","Aspecto alternativo para combate cuerpo a cuerpo.","Alternative aspect for melee combat."},
    {674,"opcional","Solo si eliges dos armas para sus estadísticas.","Only if you choose two weapons for their stats."},
    {2973,"opcional","Ataque de emergencia cuerpo a cuerpo.","Emergency melee attack."},
    {1495,"opcional","Ataque situacional cuerpo a cuerpo.","Situational melee attack."},
  },
  Supervivencia = {
    {13161,"comprar","Aspecto ofensivo para tu plan de combate cuerpo a cuerpo.","Offensive aspect for your melee plan."},
    {2973,"comprar","Prioriza Golpe de raptor y sus rangos.","Prioritize Raptor Strike and its ranks."},
    {1495,"comprar","Prioriza Mordedura de mangosta.","Prioritize Mongoose Bite."},
    {2974,"comprar","Ralentiza al objetivo cuerpo a cuerpo.","Slow targets in melee."},
    {13795,"comprar","Trampa de daño para combates adecuados.","Damage trap for suitable fights."},
    {13813,"comprar","Daño de área; útil frente a grupos.","Area damage; useful against groups."},
    {674,"opcional","Aprende solo si tu configuración utiliza dos armas.","Learn only if your setup uses two weapons."},
    {19434,"opcional","Ataque de apertura a distancia, secundario al combate cuerpo a cuerpo.","Ranged opener, secondary to melee combat."},
    {13165,"opcional","Aspecto alternativo para disparos a distancia.","Alternative aspect for ranged attacks."},
    {3044,"opcional","Daño a distancia cuando no puedas combatir cuerpo a cuerpo.","Ranged damage when you cannot fight in melee."},
    {1978,"comprar","Daño periódico para complementar tu combate.","Periodic damage to complement combat."},
  },
}
local comunesCazador = {
  {136,"comprar","Cura a tu mascota si la utilizas.","Heal your pet if you use one."},
  {1130,"comprar","Marca al objetivo para potenciar ataques a distancia.","Mark the target to strengthen ranged attacks."},
  {2643,"comprar","Ataque a varios enemigos; comparte recarga con Disparo apuntado.","Attack several enemies; shares a cooldown with Aimed Shot."},
  {5384,"comprar","Intenta salir del combate; comprueba si el enemigo resiste.","Attempt to leave combat; check whether enemies resist."},
  {1499,"comprar","Controla a un enemigo mediante la trampa congelante.","Control an enemy using Freezing Trap."},
  {8737,"comprar","Desbloquea malla a nivel 40.","Unlock mail at level 40."},
  {3127,"comprar","Permite parar ataques cuerpo a cuerpo.","Enables melee parries."},
  {20736,"opcional","Genera amenaza para proteger a un aliado en una emergencia.","Generate threat to protect an ally in an emergency."},
}
local function ConsejoCazador(nombre)
  if not GL.RUTA or GL.RUTA.clase ~= "HUNTER" or not nombre then return nil end
  local rama=DB().especializacion or "Bestias"
  local grupos={consejosCazador[rama] or {},comunesCazador}
  for j,g in ipairs(grupos) do
    for i,e in ipairs(g) do
      if NombreHechizo(e[1])==nombre then return {c=e[2],nota=GL.ingles and e[4] or e[3],prioridad=(j-1)*20+i} end
    end
  end
end

-- B08: prioridades orientativas de leveo; no alteran requisitos ni rangos del instructor.
-- En especializaciones distintas, nunca se compra automáticamente una habilidad situacional
-- solo porque aparezca en el plan clásico de la ruta. Los rangos de talento respetan la API real.
local consejosPicaro = {
  Asesinato={
    {53,"comprar","Generador con daga antes de Mutilar o cuando puedas atacar por detrás.","Dagger builder before Mutilate or when you can attack from behind."},
    {1310706,"comprar","Mejora Mutilar si ya tienes el talento y usas dos dagas.","Upgrade Mutilate if talented and using two daggers."},
    {1752,"comprar","Generador frontal alternativo; útil antes de Mutilar.","Alternative frontal builder; useful before Mutilate."},
    {2835,"comprar","Daño periódico en enemigos que vivan suficiente tiempo.","Periodic damage against enemies that live long enough."},
    {703,"comprar","Apertura de sangrado cuando sea viable.","Bleed opener when practical."},
    {1943,"comprar","Remate de sangrado para combates prolongados.","Bleed finisher for longer fights."},
    {8676,"opcional","Apertura alternativa con daga.","Alternative dagger opener."},
  },
  Combate={
    {1752,"comprar","Generador principal con un arma de mano principal de buen daño.","Main builder with a strong main-hand weapon."},
    {2098,"comprar","Remate directo para objetivos de vida corta.","Direct finisher for short-lived targets."},
    {5171,"comprar","Mantén el beneficio en combates prolongados.","Maintain the buff in longer fights."},
    {53,"opcional","Solo compensa si usas daga y puedes atacar desde atrás.","Useful only with a dagger and rear access."},
    {8676,"opcional","Apertura con daga, no necesaria en el plan frontal.","Dagger opener, not required for the frontal build."},
    {703,"opcional","Apertura de sangrado para encuentros largos.","Bleed opener for long fights."},
    {1943,"opcional","Alternativa a Eviscerar si el objetivo sobrevive.","Alternative to Eviscerate if the target survives."},
    {2835,"opcional","Útil en objetivos duraderos; considera el coste.","Useful against durable targets; consider cost."},
  },
  Sutileza={
    {1752,"comprar","Generador antes de Hemorragia o cuando no puedas usarla.","Builder before Hemorrhage or when it cannot be used."},
    {1943,"comprar","Sangrado que combina con Hemorragia y Marca de muerte.","Bleed that synergizes with Hemorrhage and Death Mark."},
    {703,"comprar","Apertura de sangrado desde sigilo.","Stealth bleed opener."},
    {1329283,"comprar","Recupera energía; Cuchillo de bota añade sinergia si lo has aprendido.","Restores Energy; Boot Knife adds synergy if learned."},
    {1316709,"comprar","Mejora Marca de muerte cuando tengas el talento.","Upgrade Death Mark when talented."},
    {53,"opcional","Útil con daga y acceso a la espalda del objetivo.","Useful with a dagger and access to the target's rear."},
    {8676,"opcional","Apertura potente si utilizas daga.","Powerful opener if using a dagger."},
    {2835,"opcional","Daño periódico adicional en objetivos duraderos.","Extra periodic damage on durable targets."},
  },
}
local comunesPicaro={
  {1310706,"opcional","Mejora solo si ya tienes el talento y utilizas dos dagas.","Upgrade only if already talented and using two daggers."},
  {1316709,"opcional","Mejora solo si ya has aprendido Marca de muerte.","Upgrade only if Death Mark has already been learned."},
  {674,"comprar","Desbloquea dos armas al nivel 10.","Unlocks dual wield at level 10."},
  {1328825,"comprar","Reduce el coste de una apertura con energía llena.","Makes a full-Energy opener cheaper."},
  {1329283,"comprar","Ataque de mano secundaria que recupera energía.","Off-hand attack that restores Energy."},
  {1766,"comprar","Interrumpe hechizos enemigos.","Interrupt enemy spellcasts."},
  {1784,"comprar","Mejora el sigilo y facilita las aperturas.","Improves Stealth and helps with openers."},
  {5277,"comprar","Defensa contra ataques cuerpo a cuerpo.","Defense against melee attacks."},
  {1856,"comprar","Herramienta de escape y reinicio del combate.","Escape and combat reset tool."},
  {2983,"comprar","Movilidad y escape.","Mobility and escape."},
  {2098,"comprar","Remate directo cuando convenga.","Direct finisher when appropriate."},
  {5171,"comprar","Beneficio de velocidad de ataque para combates largos.","Attack-speed buff for longer fights."},
  {8681,"comprar","Veneno de daño directo; exige habilidad y materiales.","Direct damage poison; requires skill and reagents."},
  {1804,"comprar","Necesaria para abrir cerraduras y practicar antes de los venenos.","Needed to open locks and practise before poisons."},
  {3127,"comprar","Permite parar ataques cuerpo a cuerpo.","Enables melee parries."},
  {1776,"comprar","Control breve y ocasión de recuperar energía.","Brief control and an opportunity to recover Energy."},
  {921,"comprar","Consigue objetos y monedas al robar.","Obtain items and coins by pickpocketing."},
  {1833,"comprar","Apertura con aturdimiento.","Stunning opener."},
  {408,"comprar","Remate de control.","Control finisher."},
  {6770,"comprar","Control de enemigos antes de iniciar combate.","Enemy control before engaging."},
  {3420,"opcional","Ralentiza; útil para huir o controlar corredores.","Slows; useful for escaping or controlling runners."},
  {5763,"opcional","Considera contra lanzadores de hechizos.","Consider against spellcasters."},
  {13220,"opcional","Considera contra enemigos que se curan.","Consider against enemies that heal."},
  {6510,"opcional","Fabrica el componente de Ceguera si lo necesitas.","Craft Blind's reagent if needed."},
  {2094,"opcional","Control de emergencia; comprueba componentes.","Emergency control; check reagents."},
  {1966,"opcional","Reduce amenaza en grupo.","Reduces threat in groups."},
  {8647,"opcional","Apoyo contra enemigos resistentes; coordina con el grupo.","Support against armored enemies; coordinate with your group."},
  {1725,"opcional","Facilita desplazarte en sigilo.","Helps move around in Stealth."},
  {2836,"opcional","Utilidad contra trampas.","Utility against traps."},
  {1842,"opcional","Utilidad cuando haya trampas compatibles.","Utility when eligible traps are present."},
  {1860,"opcional","Utilidad contra caídas; oferta observada en Forjaz al 40, verifica el precio.","Falling damage utility; trainer offer observed in Ironforge at 40, check price."},
}
local function ConsejoPicaro(nombre)
  if not GL.RUTA or GL.RUTA.clase~="ROGUE" or not nombre then return nil end
  local rama=DB().especializacion or "Combate"
  for j,g in ipairs({consejosPicaro[rama] or {},comunesPicaro}) do
    for i,e in ipairs(g) do
      if NombreHechizo(e[1])==nombre then return {c=e[2],nota=GL.ingles and e[4] or e[3],prioridad=(j-1)*40+i} end
    end
  end
end

-- Sacerdote B07: prioridades orientativas por especialización, sin cambiar los requisitos.
-- Mobalytics 18 y 21/11/2026, Forever Outpost 9/11/2026. La clave guardada sigue siendo Sombra.
local consejosSacerdote = {
  Disciplina={
    {402174,"comprar","Mejora Penitencia tras aprender el talento; sirve para sanar o hacer daño.","Upgrade Penance after unlocking the talent; it heals or deals damage."},
    {17,"comprar","Escudo prioritario para absorber daño.","Prioritize Shield to absorb damage."},
    {14914,"comprar","Ataque sagrado de apertura para levear en solitario.","Holy opener for solo leveling."},
    {585,"comprar","Ataque directo sagrado para combates en solitario.","Direct Holy attack for solo fights."},
    {2061,"comprar","Cura rápida de emergencia.","Fast emergency heal."},
    {2054,"comprar","Cura eficiente durante el leveo en grupo.","Efficient heal while leveling in groups."},
    {2060,"comprar","Cura grande para daño elevado.","Large heal for heavy damage."},
    {139,"comprar","Curación periódica de apoyo.","Supporting heal over time."},
    {596,"comprar","Cura de grupo cuando varios aliados reciben daño.","Group heal when several allies take damage."},
    {401859,"opcional","Solo si también has aprendido Rezo de alivio.","Only if you also learned Prayer of Mending."},
    {15237,"opcional","Solo si también has aprendido Nova sagrada.","Only if you also learned Holy Nova."},
    {15407,"opcional","Solo si también has aprendido Tortura mental.","Only if you also learned Mind Flay."},
  },
  Sagrado={
    {139,"comprar","Mantén actualizada la curación periódica.","Keep your heal over time up to date."},
    {2054,"comprar","Cura directa eficiente durante el leveo.","Efficient direct heal while leveling."},
    {2060,"comprar","Cura grande para daño elevado.","Large heal for heavy damage."},
    {2061,"comprar","Cura rápida para emergencias.","Fast heal for emergencies."},
    {596,"comprar","Prioriza la sanación de grupo.","Prioritize group healing."},
    {401859,"comprar","Mejora Rezo de alivio tras desbloquear el talento.","Upgrade Prayer of Mending after unlocking the talent."},
    {15237,"comprar","Mejora Nova sagrada tras aprender el talento; útil cerca del grupo.","Upgrade Holy Nova after unlocking the talent; useful near the group."},
    {14914,"comprar","Daño sagrado para misiones en solitario.","Holy damage for solo quests."},
    {585,"comprar","Daño directo para levear fuera de mazmorra.","Direct damage for leveling outside dungeons."},
    {402174,"opcional","Solo si también has aprendido Penitencia.","Only if you also learned Penance."},
    {15407,"opcional","Solo si también has aprendido Tortura mental.","Only if you also learned Mind Flay."},
  },
  Sombra={
    {589,"comprar","Daño periódico principal durante todo el leveo.","Core damage over time throughout leveling."},
    {2944,"comprar","Daño periódico y autocuración desde el 20; úsalo cuando compense el maná.","Damage over time and self-healing from 20; use when worth the Mana."},
    {8092,"comprar","Daño directo de Sombras.","Direct Shadow damage."},
    {15407,"comprar","Mejora Tortura mental tras aprender el talento.","Upgrade Mind Flay after unlocking the talent."},
    {1309595,"comprar","Remata objetivos; cuidado con el daño de retorno si sobreviven.","Finish targets; beware of backlash if they survive."},
    {2054,"comprar","Cura de apoyo fuera de Forma de las Sombras.","Supporting heal outside Shadowform."},
    {2061,"comprar","Cura rápida de emergencia fuera de Forma de las Sombras.","Fast emergency heal outside Shadowform."},
    {2060,"opcional","Mejora si también sanas grupos; sal antes de Forma de las Sombras.","Upgrade if also healing groups; leave Shadowform first."},
    {139,"opcional","Curación periódica de apoyo fuera de Forma de las Sombras.","Supporting heal over time outside Shadowform."},
    {596,"opcional","Útil para sanación de mazmorra fuera de Forma de las Sombras.","Useful for dungeon healing outside Shadowform."},
    {585,"opcional","Daño sagrado secundario antes de Forma de las Sombras.","Secondary Holy damage before Shadowform."},
    {14914,"opcional","Apertura sagrada antes de Forma de las Sombras.","Holy opener before Shadowform."},
    {402174,"opcional","Solo si también has aprendido Penitencia.","Only if you also learned Penance."},
    {401859,"opcional","Solo si también has aprendido Rezo de alivio.","Only if you also learned Prayer of Mending."},
    {15237,"opcional","Solo si también has aprendido Nova sagrada.","Only if you also learned Holy Nova."},
  },
}
local comunesSacerdote={
  {17,"comprar","Absorción para reducir el daño recibido.","Absorption to reduce incoming damage."},
  {589,"comprar","Daño periódico útil en solitario.","Useful solo damage over time."},
  {2944,"comprar","Daño periódico con autocuración; valora su coste de maná.","Damage over time with self-healing; consider its Mana cost."},
  {8092,"comprar","Daño directo para misiones.","Direct damage for quests."},
  {1309595,"comprar","Remate instantáneo; vigila el daño de retorno.","Instant finisher; watch for backlash."},
  {1243,"comprar","Aumenta el aguante del personaje y aliados.","Increases your and allies' Stamina."},
  {14752,"comprar","Beneficio de Espíritu, común a todas las razas.","Spirit buff, available to all races."},
  {588,"comprar","Armadura adicional para sobrevivir.","Additional armor for survival."},
  {2050,"comprar","Cura inicial hasta disponer de Sanar; no necesitas gastar de nuevo en rangos antiguos ya superados.","Early heal until Heal is available; no need to revisit obsolete lower ranks."},
  {527,"comprar","Disipa magia compatible.","Dispels eligible magic."},
  {528,"comprar","Elimina enfermedades.","Removes diseases."},
  {552,"comprar","Disipación periódica de enfermedades.","Periodic disease removal."},
  {2006,"comprar","Resucita aliados fuera de combate.","Resurrects allies out of combat."},
  {6346,"comprar","Protección situacional contra miedo.","Situational protection against fear."},
  {586,"comprar","Reduce amenaza al sanar o atacar en grupo.","Reduces threat when healing or attacking in groups."},
  {8122,"comprar","Control defensivo; cuidado con atraer otros enemigos.","Defensive crowd control; avoid pulling other enemies."},
  {976,"opcional","Resistencia a Sombras para encuentros concretos.","Shadow resistance for specific encounters."},
  {453,"opcional","Utilidad para evitar algunos humanoides.","Utility for avoiding some humanoids."},
  {605,"opcional","Control mental en objetivos compatibles.","Mind control on eligible targets."},
  {9484,"opcional","Control de no-muertos.","Undead crowd control."},
  {8129,"opcional","Útil contra enemigos con maná, especialmente en JcJ.","Useful against Mana users, especially in PvP."},
  {2096,"opcional","Utilidad de exploración.","Scouting utility."},
  {1706,"opcional","Utilidad de desplazamiento y caídas.","Movement and falling utility."},
  {1277370,"opcional","Cura racial humana de emergencia.","Human emergency racial heal."},
  {13896,"opcional","Racial humana contra lanzadores.","Human anti-caster racial."},
  {13908,"comprar","Cura racial enana de emergencia.","Dwarf emergency racial heal."},
  {1277331,"opcional","Daño y control racial enano.","Dwarf racial damage and control."},
  {10797,"opcional","Daño arcano racial; secundario para Sombra.","Racial Arcane damage; secondary for Shadow."},
  {2651,"opcional","Defensivo racial elfo.","Night Elf racial defensive."},
  {1277455,"opcional","Control racial gnomo.","Gnome racial crowd control."},
  {1277462,"opcional","Protección racial gnoma.","Gnome racial protection."},
  {2652,"opcional","Defensivo racial no-muerto.","Undead racial defensive."},
  {1277324,"opcional","Intercambio de salud por maná; vigila tu salud.","Trades Health for Mana; watch your Health."},
  {9035,"opcional","Debilitamiento racial trol.","Troll racial weakening effect."},
  {18137,"opcional","Daño reactivo racial trol.","Troll racial reactive damage."},
  {21562,"opcional","Rezo de grupo; obtención pendiente de confirmar, no comprar automáticamente.","Group prayer; acquisition unconfirmed, do not auto-buy."},
  {27683,"opcional","Rezo de grupo; obtención pendiente de confirmar, no comprar automáticamente.","Group prayer; acquisition unconfirmed, do not auto-buy."},
  {27681,"opcional","Rezo de grupo; comprueba su obtención.","Group prayer; check acquisition."},
}
local function ConsejoSacerdote(nombre,nivel)
  if not GL.RUTA or GL.RUTA.clase~="PRIEST" or not nombre then return nil end
  local rama=DB().especializacion or "Sombra"
  for j,g in ipairs({consejosSacerdote[rama] or consejosSacerdote.Sombra,comunesSacerdote}) do
    for i,e in ipairs(g) do
      if NombreHechizo(e[1])==nombre then
        local c,nota=e[2],GL.ingles and e[4] or e[3]
        if e[1]==2050 and (nivel or UnitLevel("player") or 1)>=16 then
          c="opcional";nota=GL.ingles and "Heal is available from 16; prioritize it." or "Sanar está disponible desde el 16; dale prioridad."
        end
        if rama=="Sombra" and e[1]==585 and (nivel or UnitLevel("player") or 1)<20 then
          c="comprar";nota=GL.ingles and "Early Holy damage before Mind Flay." or "Daño sagrado inicial antes de Tortura mental."
        end
        return {c=c,nota=nota,prioridad=(j-1)*60+i}
      end
    end
  end
  -- No convertir un registro no contrastado en compra automática por un consejo antiguo.
  return {c="opcional",nota=GL.ingles and "Check the spellbook and trainer before learning." or "Consulta el libro de hechizos y el instructor antes de aprender.",prioridad=999}
end

-- Chamán B07: prioridades de leveo orientativas; no alteran la oferta del instructor.
local consejosChaman={
  Elemental={
    {403,"comprar","Daño principal a distancia; mejora los rangos.","Core ranged damage; upgrade ranks."},
    {421,"comprar","Daño contra varios objetivos; vigila el maná.","Multi-target damage; watch Mana."},
    {8042,"comprar","Daño directo e interrupción.","Direct damage and interrupt."},
    {8050,"comprar","Daño de fuego periódico.","Periodic Fire damage."},
    {3599,"comprar","Daño sostenido de fuego.","Sustained Fire damage."},
    {408341,"comprar","Daño de área desde tu tótem de fuego activo.","Area damage from your active Fire Totem."},
    {8190,"comprar","Daño de área para varios enemigos.","Area damage against multiple enemies."},
    {8024,"opcional","Imbuición para ataques con arma; secundaria al lanzar hechizos.","Weapon imbue; secondary when casting."},
    {8232,"opcional","Solo si también combates cuerpo a cuerpo.","Only if also fighting in melee."},
    {16190,"opcional","Mejora solo si has aprendido el talento.","Upgrade only if you learned the talent."},
    {408521,"opcional","Mejora solo si has aprendido el talento.","Upgrade only if you learned the talent."},
  },
  Mejora={
    {8232,"comprar","Imbuición principal desde el 30 para ataques con arma.","Main weapon imbue from 30 for weapon attacks."},
    {403,"comprar","Ataque a distancia; aprovecha Arma vorágine si la has aprendido.","Ranged attack; use Maelstrom Weapon if talented."},
    {8042,"comprar","Daño e interrupción, útil con Golpe de tormenta.","Damage and interrupt, useful with Stormstrike."},
    {324,"comprar","Daño reactivo; alterna con Escudo de agua si lo has aprendido.","Reactive damage; alternate with Water Shield if talented."},
    {8075,"comprar","Fuerza para ataques físicos del grupo.","Strength for party melee attacks."},
    {8835,"comprar","Agilidad para ataques físicos del grupo.","Agility for party melee attacks."},
    {8512,"comprar","Apoyo al grupo físico; no sustituye tu imbuición propia.","Physical party support; does not replace your own imbue."},
    {8050,"comprar","Daño periódico según duración del combate.","Periodic damage depending on fight length."},
    {421,"opcional","Daño a varios objetivos si te sobra maná.","Multi-target damage if Mana allows."},
    {16190,"opcional","Solo si has aprendido el talento.","Only if you learned the talent."},
    {408521,"opcional","Solo si has aprendido el talento.","Only if you learned the talent."},
  },
  ["Restauración"]={
    {331,"comprar","Cura directa principal; conserva rangos útiles según maná.","Main direct heal; retain useful ranks for Mana management."},
    {8004,"comprar","Cura rápida de emergencia.","Fast emergency heal."},
    {1064,"comprar","Cura de grupo que salta entre aliados.","Group heal that jumps between allies."},
    {5394,"comprar","Curación periódica del grupo.","Periodic party healing."},
    {5675,"comprar","Regeneración de maná del grupo.","Party Mana regeneration."},
    {16190,"comprar","Mejora Marea de maná tras aprender el talento.","Upgrade Mana Tide after learning the talent."},
    {408521,"comprar","Mejora Mareas vivas tras aprender el talento.","Upgrade Riptide after learning the talent."},
    {403,"comprar","Daño para misiones en solitario.","Damage for solo questing."},
    {8050,"opcional","Daño de apoyo durante misiones.","Supporting damage during quests."},
    {421,"opcional","Daño de área para misiones; prioriza las curas.","Questing area damage; prioritize heals."},
    {8232,"opcional","Para misiones en solitario con arma cuerpo a cuerpo.","For solo questing with a melee weapon."},
  },
}
local comunesChaman={
  {331,"comprar","Cura directa para sobrevivir y apoyar al grupo.","Direct heal for survival and party support."},
  {8004,"comprar","Cura rápida de emergencia.","Fast emergency heal."},
  {1064,"opcional","Prioriza si también sanas grupos.","Prioritize if also healing groups."},
  {403,"comprar","Daño a distancia.","Ranged damage."},
  {8042,"comprar","Interrumpe lanzamientos compatibles.","Interrupts eligible casts."},
  {8056,"opcional","Ralentización situacional.","Situational slow."},
  {8050,"opcional","Daño periódico de fuego.","Periodic Fire damage."},
  {324,"comprar","Defensa reactiva; incompatible con Escudo de agua.","Reactive defense; incompatible with Water Shield."},
  {3599,"comprar","Tótem de daño de fuego.","Fire damage totem."},
  {5675,"comprar","Regeneración de maná.","Mana regeneration."},
  {5394,"comprar","Curación de apoyo.","Supporting healing."},
  {370,"comprar","Disipa beneficios mágicos del enemigo.","Dispels enemy Magic buffs."},
  {526,"comprar","Elimina venenos.","Removes poison."},
  {2870,"comprar","Elimina enfermedades.","Removes disease."},
  {2008,"comprar","Resucita a aliados fuera de combate.","Resurrects allies out of combat."},
  {2645,"comprar","Movilidad al aire libre.","Outdoor mobility."},
  {556,"comprar","Regreso al hogar vinculado.","Returns to bound home."},
  {20608,"comprar","Resurrección propia si está disponible.","Self-resurrection when available."},
  {36936,"comprar","Recoge los tótems y recupera maná.","Recalls totems and refunds Mana."},
  {437009,"comprar","Traslada tus tótems activos.","Moves your active totems."},
  {66842,"comprar","Primera configuración de tótems.","First totem preset."},
  {66843,"opcional","Segunda configuración de tótems.","Second totem preset."},
  {66844,"opcional","Tercera configuración de tótems.","Third totem preset."},
  {8737,"comprar","Permite equipar malla desde el 40.","Allows mail armor from 40."},
  {8143,"comprar","Protección situacional contra miedo.","Situational protection against Fear."},
  {8177,"comprar","Protección situacional contra hechizos hostiles.","Situational protection against hostile spells."},
  {2484,"comprar","Control de movimiento.","Movement control."},
  {8166,"opcional","Apoyo contra venenos.","Support against poison."},
  {8170,"opcional","Apoyo contra enfermedades.","Support against disease."},
  {8071,"opcional","Mitigación de daño físico.","Physical damage mitigation."},
  {8075,"opcional","Apoyo a aliados físicos.","Support for physical allies."},
  {8835,"opcional","Apoyo a aliados físicos.","Support for physical allies."},
  {8512,"opcional","Apoyo a aliados físicos.","Support for physical allies."},
  {5730,"opcional","Control ocasional de enemigos; no es un rol de tanque.","Situational enemy control; not a tank role."},
  {8181,"opcional","Resistencia a Escarcha situacional.","Situational Frost resistance."},
  {8184,"opcional","Resistencia a Fuego situacional.","Situational Fire resistance."},
  {10595,"opcional","Resistencia a Naturaleza situacional.","Situational Nature resistance."},
  {15107,"opcional","Protección situacional contra ataques a distancia.","Situational protection against ranged attacks."},
  {6495,"opcional","Exploración situacional.","Situational scouting."},
  {6196,"opcional","Exploración situacional.","Situational scouting."},
  {131,"opcional","Exploración acuática.","Underwater exploration."},
  {546,"opcional","Desplazamiento sobre el agua.","Movement on water."},
  {8227,"opcional","Apoyo de fuego al grupo.","Fire support for the party."},
  {8024,"opcional","Imbuición alternativa de Fuego.","Alternative Fire imbue."},
  {8033,"opcional","Imbuición situacional de Escarcha.","Situational Frost imbue."},
  {408341,"opcional","Daño de área situacional.","Situational area damage."},
  {8190,"opcional","Daño de área situacional.","Situational area damage."},
}
local function ConsejoChaman(nombre,nivel)
  if not GL.RUTA or GL.RUTA.clase~="SHAMAN" or not nombre then return nil end
  local rama=DB().especializacion or "Mejora"
  if NombreHechizo(8017)==nombre then
    local nv=nivel or UnitLevel("player") or 1
    local c=nv<30 and "comprar" or "opcional"
    return {c=c,prioridad=5,nota=GL.ingles and "Early weapon imbue; compare with Windfury from 30." or "Imbuición inicial; compara con Viento Furioso desde el 30."}
  end
  for j,g in ipairs({consejosChaman[rama] or consejosChaman.Mejora,comunesChaman}) do
    for i,e in ipairs(g) do
      if NombreHechizo(e[1])==nombre then return {c=e[2],nota=GL.ingles and e[4] or e[3],prioridad=(j-1)*60+i} end
    end
  end
  return {c="opcional",nota=GL.ingles and "Check the spellbook and trainer before learning." or "Consulta el libro de hechizos y el instructor antes de aprender.",prioridad=999}
end

-- Mago: prioridades por rama; no implican disponibilidad en el instructor.
local prioridadesMago={
  Arcano={5143,400574,1326079,1449,6117},
  Fuego={133,2136,2948,11366,11113,401502,2120},
  Escarcha={116,1312002,11426,120,401502,10},
}
local comunesMago={1459,5504,587,118,122,1953,2139,12051,475,759,3552,10053,10054,1296017}
local function ConsejoMago(nombre,nivel)
  if not GL.RUTA or GL.RUTA.clase~="MAGE" or not nombre then return nil end
  local rama=DB().especializacion or "Escarcha"
  local lista=prioridadesMago[rama] or prioridadesMago.Escarcha
  local nv=nivel or UnitLevel("player") or 1
  local en=GL.ingles
  local function c(accion,prioridad,es,ing) return {c=accion,prioridad=prioridad,nota=en and ing or es} end
  for i,id in ipairs(lista) do
    if NombreHechizo(id)==nombre then return c("comprar",i,"Prioridad de "..rama.."; aprende solo rangos disponibles y con requisitos cumplidos.","Specialization priority; learn only available ranks with prerequisites met.") end
  end
  if nombre==NombreHechizo(168) or nombre==NombreHechizo(7302) then
    local vigente=(nv<30 and nombre==NombreHechizo(168)) or (nv>=30 and nombre==NombreHechizo(7302))
    return c(vigente and "comprar" or "opcional",20,"Armadura de protección; elige según el nivel y tu maná.","Protective armor; choose according to level and Mana.")
  end
  if nombre==NombreHechizo(116) and nv<20 then return c("comprar",21,"Daño y control temprano antes de desbloquear los talentos principales.","Early damage and control before unlocking core talents.") end
  for i,id in ipairs(comunesMago) do
    if NombreHechizo(id)==nombre then return c("comprar",30+i,"Utilidad común; mejora los rangos disponibles.","Shared utility; upgrade available ranks.") end
  end
  if nombre==NombreHechizo(1302508) then return c("opcional",90,"Recompensa de Acceso a la investigación, no se compra al instructor.","Research Access quest reward, not a trainer purchase.") end
  return c("opcional",999,"Aprende manualmente si lo necesitas; confirma disponibilidad y coste.","Learn manually if needed; verify availability and cost.")
end

-- B07: prioridades de entrenamiento, no una rotación ni una garantía de oferta.
local prioridadesBrujo={
  ["Aflicción"]={172,980,689,18265,1316697,1120,686,348},
  ["Demonología"]={755,172,980,686,5676,6353,348,689},
  ["Destrucción"]={348,686,17877,1293817,412758,5676,172,980,5740},
}
local comunesBrujo={1454,1120,6201,693,5782,755,698,6789,710,440892}
local function ConsejoBrujo(nombre,nivel)
  if not GL.RUTA or GL.RUTA.clase~="WARLOCK" or not nombre then return nil end
  local rama=DB().especializacion or "Aflicción"
  local lista=prioridadesBrujo[rama] or prioridadesBrujo["Aflicción"]
  local nv=nivel or UnitLevel("player") or 1
  local en=GL.ingles
  local function c(accion,prioridad,es,ing) return {c=accion,prioridad=prioridad,nota=en and ing or es} end
  local function esId(id) return NombreHechizo(id)==nombre end
  if esId(687) or esId(706) then
    local vigente=(nv<20 and esId(687)) or (nv>=20 and esId(706))
    return c(vigente and "comprar" or "opcional",20,"Protección y recuperación; usa la armadura correspondiente a tu nivel.","Protection and recovery; use the armor appropriate for your level.")
  end
  for i,id in ipairs(lista) do
    if esId(id) then return c("comprar",i,"Prioridad de la especialización; aprende solo rangos disponibles con requisitos cumplidos.","Specialization priority; learn only available ranks with prerequisites met.") end
  end
  for i,id in ipairs(comunesBrujo) do
    if esId(id) then return c("comprar",30+i,"Utilidad común; mejora los rangos disponibles.","Shared utility; upgrade available ranks.") end
  end
  if esId(1949) then return c("opcional",90,"Área que también te daña; úsala con precaución en grupo.","Area damage that also hurts you; use with care in a group.") end
  return c("opcional",999,"Aprende manualmente si lo necesitas; confirma origen, disponibilidad y coste. Los grimorios de mascotas se revisan aparte.","Learn manually if needed; verify source, availability and cost. Pet grimoires are listed separately.")
end

-- B06: prioridad orientativa por rol. La oferta real y los requisitos prevalecen.
local prioridadesDruida={
  ["Equilibrio"]={5176,8921,2912,5570,16914,770},
  ["Feral (gato)"]={1082,1822,1079,5221,1328618,6785,9005,5215,1850,1328829},
  ["Feral (oso)"]={6807,779,99,1328617,407995,5211,5229,22842,5209},
  ["Restauración"]={5185,774,8936,18562,408120,740,17116,29166,437138},
}
local comunesDruida={1126,467,5185,774,8936,437138,20484,2782,2893,29166,22812,16864}
local function ConsejoDruida(nombre,nivel)
  if not GL.RUTA or GL.RUTA.clase~="DRUID" or not nombre then return nil end
  local nv=nivel or UnitLevel("player") or 1
  local rama=DB().especializacion or "Feral (gato)"
  local function c(accion,p,es,en) return {c=accion,prioridad=p,nota=GL.ingles and en or es} end
  local function esId(id) return NombreHechizo(id)==nombre end
  if esId(5176) and nv<20 then return c("comprar",1,"Daño antes de disponer de las formas y talentos principales.","Damage before acquiring core forms and talents.") end
  if esId(9634) or esId(783) then return c("comprar",1,"Forma de instructor; comprueba los requisitos.","Trainer-taught form; check prerequisites.") end
  for i,id in ipairs(prioridadesDruida[rama] or prioridadesDruida["Feral (gato)"]) do
    if esId(id) then return c("comprar",i,"Prioridad del plan elegido; aprende solo rangos disponibles con requisitos cumplidos.","Selected plan priority; learn only available ranks with prerequisites met.") end
  end
  for i,id in ipairs(comunesDruida) do
    if esId(id) then return c("comprar",30+i,"Utilidad común; mejora los rangos disponibles.","Shared utility; upgrade available ranks.") end
  end
  return c("opcional",999,"Aprende manualmente si lo necesitas; comprueba forma, origen y coste. Las competencias y los libros se revisan aparte.","Learn manually if needed; check form, source and cost. Proficiencies and books are handled separately.")
end

-- Un consejo con "hasta" vale hasta ese nivel; por encima pasa a "saltar" (p. ej. Arma Muerdepiedras, que el
-- chamán cambia por Arma Viento Furioso al 30: sus rangos siguientes ya no se compran).
local function PrepararConsejos()
  consejos = {}
  rutaConsejos = GL.RUTA
  local lista = GL.RUTA and GL.RUTA.hechizos or {}
  for i = 1, #lista do
    local h = lista[i]
    local nombre = NombreHechizo(h.id)
    if nombre and not consejos[nombre] then
      local c = { c = h.c, nota = h.nota, prioridad = i, hasta = h.hasta }
      if h.hasta then
        c.despues = { c = "saltar", prioridad = i,
          nota = h.notaDespues or (L"Desde el nivel " .. (h.hasta + 1) .. L" ya no lo usas.") }
      end
      consejos[nombre] = c
    end
  end
end

-- nivel: para qué nivel es el consejo (por defecto, el tuyo).
local function Consejo(nombre, nivel)
  if not consejos or rutaConsejos ~= GL.RUTA then PrepararConsejos() end
  local c = ConsejoGuerrero(nombre) or ConsejoPaladin(nombre) or ConsejoCazador(nombre) or ConsejoPicaro(nombre) or ConsejoSacerdote(nombre,nivel) or ConsejoChaman(nombre,nivel) or ConsejoMago(nombre,nivel) or ConsejoBrujo(nombre,nivel) or ConsejoDruida(nombre,nivel) or (nombre and consejos[nombre])
  if c and c.hasta and (nivel or UnitLevel("player") or 1) > c.hasta then return c.despues end
  return c
end

local function Dinero(cobre)
  cobre = cobre or 0
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
    local ok, t = pcall(C_CurrencyInfo.GetCoinTextureString, cobre)
    if ok and t then return t end
  end
  if GetCoinTextureString then return GetCoinTextureString(cobre) end
  if GetMoneyString then return GetMoneyString(cobre) end
  return string.format("%.2f o", cobre / 10000)
end

local function OrdenFila(a, b)
  if a.orden ~= b.orden then return a.orden < b.orden end
  if a.prioridad ~= b.prioridad then return a.prioridad < b.prioridad end
  return a.nombre < b.nombre
end

------------------------------------------------------------------------
-- Lo que te toca aprender según tu nivel (sin estar en el instructor)
------------------------------------------------------------------------
-- Índices de R.entrenamiento: qué ids son del instructor y qué rango pide a cuál (para saber el siguiente).
-- R.donde: hechizos que no vende tu instructor de clase (los del instructor de mascotas del cazador) por lugar.
-- Rangos de nivel 60 documentados mediante manuales (Pyroblast, 26-11-2026).
-- La disponibilidad efectiva y el precio de mercado no estan acreditados: fuera de compras y presupuestos.
-- Se usan para reconocer los rangos inferiores aunque el cliente solo muestre el superior.
local rangosGuerreroPendientes = {
  { id = 25286, n = 60, ant = 11567, libro = 21297 }, -- Heroic Strike IX
  { id = 25289, n = 60, ant = 11551, libro = 21298 }, -- Battle Shout VII
  { id = 25288, n = 60, ant = 11601, libro = 21299 }, -- Revenge VI
}
function GL.RangosGuerreroPendientes()
  if GL.RUTA and GL.RUTA.clase == "WARRIOR" then return rangosGuerreroPendientes end
  return {}
end

-- Forever: Pyroblast (26-11-2026) y Questing.wiki vinculan estos tres rangos a tratados.
-- La disponibilidad efectiva de los objetos y su precio de mercado quedan pendientes.
-- No entran en el presupuesto estimado de entrenamiento.
local rangosPaladinPendientes = {
  { id = 25290, n = 60, ant = 19854, libro = 21288 }, -- Blessing of Wisdom VI
  { id = 25291, n = 60, ant = 19838, libro = 21289 }, -- Blessing of Might VII
  { id = 25292, n = 60, ant = 10329, libro = 21290 }, -- Holy Light IX
}
function GL.RangosPaladinPendientes()
  if GL.RUTA and GL.RUTA.clase == "PALADIN" then return rangosPaladinPendientes end
  return {}
end
-- Cazador: registros de Forever (Questing.wiki, Icy Veins DB, Bind on Forever 71091).
-- Los manuales se documentan por ID, no se garantiza botín ni compra en el servidor.
-- Lacerar figura en el cliente; su oferta efectiva y coste no están contrastados.
-- Disparo múltiple V (25294 / 21304) se excluye: el catálogo actual muestra un solo rango.
local rangosCazadorPendientes = {
  { id=25295, n=60, ant=13555, libro=21306 }, -- Serpent Sting IX
  { id=25296, n=60, ant=14322, libro=21307 }, -- Aspect of the Hawk VII
  { id=19801, n=60, ant=0, libro=16665, rama="Bestias" }, -- Tranquilizing Shot
  { id=24118, n=30, ant=0, rama="Supervivencia" }, -- Lacerate I
  { id=24119, n=40, ant=24118 },
  { id=24120, n=50, ant=24119 },
  { id=1299332, n=60, ant=24120 },
}
function GL.RangosCazadorPendientes()
  if GL.RUTA and GL.RUTA.clase == "HUNTER" then return rangosCazadorPendientes end
  return {}
end
-- Forever: Questing.wiki 25300/25302/25347/31016 y ForeverDiff 21302/21303.
-- Manuales de nivel 60: existencia documentada, oferta efectiva y precio no acreditados.
local rangosPicaroPendientes = {
  { id=25300, n=60, ant=11281, libro=21300 }, -- Backstab IX
  { id=25347, n=60, ant=11358, libro=21302, hab={40,300} }, -- Deadly Poison V
  { id=25302, n=60, ant=11303, libro=21303 }, -- Feint V
  { id=31016, n=60, ant=11300, libro=24102 }, -- Eviscerate IX
}
function GL.RangosPicaroPendientes()
  if GL.RUTA and GL.RUTA.clase == "ROGUE" then return rangosPicaroPendientes end
  return {}
end
-- Sacerdote B04: seis rangos ausentes del catálogo de rutas. Los códices están
-- documentados, pero el origen efectivo no coincide entre los catálogos públicos.
-- No tratar el nivel del hechizo como nivel de uso del objeto ni automatizar la compra.
local rangosSacerdotePendientes = {
  {id=25314,n=60,ant=10965,libro=21284,libroNivel=60}, -- Greater Heal V
  {id=25315,n=60,ant=10929,libro=21285,libroNivel=60}, -- Renew X
  {id=25316,n=60,ant=10961,libro=21287,libroNivel=60}, -- Prayer of Healing V
  {id=21562,n=48,ant=0,libro=17413,libroNivel=48,rama="Disciplina"},
  {id=21564,n=60,ant=21562,libro=17414,libroNivel=60},
  {id=27683,n=56,ant=0,libro=22393,libroNivel=60,rama="General"},
}
function GL.RangosSacerdotePendientes()
  if GL.RUTA and GL.RUTA.clase=="PRIEST" then return rangosSacerdotePendientes end
  return {}
end
-- Chamán B04: tres tablillas documentadas, no se presupone su disponibilidad.
local rangosChamanPendientes={
  {id=25357,n=60,ant=10396,libro=21291,libroNivel=60},
  {id=25361,n=60,ant=10442,libro=21292,libroNivel=60},
  {id=25359,n=60,ant=10627,libro=21293,libroNivel=60},
}
function GL.RangosChamanPendientes()
  if GL.RUTA and GL.RUTA.clase=="SHAMAN" then return rangosChamanPendientes end
  return {}
end
-- Mago B04: libros documentados; disponibilidad y origen efectivos sin confirmar.
local rangosMagoPendientes={
  {id=25306,n=60,ant=10151,libro=21279,libroNivel=60},
  {id=25304,n=60,ant=10181,libro=21214,libroNivel=60},
  {id=25345,n=56,ant=10212,libro=21280,libroNivel=60},
  {id=23028,n=56,ant=0,libro=18600,libroNivel=56,rama="General"},
  {id=28612,n=60,ant=10145,libro=22897,libroNivel=60},
  {id=28271,n=60,ant=0,libro=22739,libroNivel=60,rama="General"},
}
function GL.RangosMagoPendientes()
  if GL.RUTA and GL.RUTA.clase=="MAGE" then
    local r={}
    for _,e in ipairs(rangosMagoPendientes) do r[#r+1]=e end
    -- Inferir facción del catálogo activo; los Skyborne tienen rutas separadas.
    for _,e in ipairs(GL.EntrenamientoAuditado(GL.RUTA)) do
      if e.id==3561 then r[#r+1]={id=1297659,n=50,ant=0,rama="General"};break end
    end
    return r
  end
  return {}
end
-- Brujo B04: libros de clase documentados, no disponibilidad real acreditada.
local rangosBrujoPendientes={
  {id=25307,n=60,ant=11661,libro=21281,libroNivel=60},
  {id=25309,n=60,ant=11668,libro=21282,libroNivel=60},
  {id=25311,n=60,ant=11672,libro=21283,libroNivel=60},
  {id=28610,n=60,ant=11740,libro=22891,libroNivel=60},
  -- Nivel del hechizo 60; el item 216748 tiene nivel de objeto 25, no de aprendizaje.
  {id=437169,n=60,ant=0,libro=216748,rama="Demonología"},
}
function GL.RangosBrujoPendientes()
  if GL.RUTA and GL.RUTA.clase=="WARLOCK" then return rangosBrujoPendientes end
  return {}
end
-- Druida B04: libros documentados; disponibilidad real pendiente.
local rangosDruidaPendientes={
  {id=25297,n=60,ant=9889,libro=21294,libroNivel=60},
  {id=25298,n=60,ant=9876,libro=21295,libroNivel=60},
  {id=25299,n=60,ant=9841,libro=21296,libroNivel=60},
  {id=21849,n=50,ant=0,libro=17682,libroNivel=50,rama="Restauración"},
  {id=21850,n=60,ant=21849,libro=17683,libroNivel=60},
}
function GL.RangosDruidaPendientes()
  if GL.RUTA and GL.RUTA.clase=="DRUID" then return rangosDruidaPendientes end
  return {}
end
function GL.RangosAuditadosPendientes()
  if GL.RUTA and GL.RUTA.clase=="DRUID" then return GL.RangosDruidaPendientes() end
  if GL.RUTA and GL.RUTA.clase=="WARLOCK" then return GL.RangosBrujoPendientes() end
  if GL.RUTA and GL.RUTA.clase=="MAGE" then return GL.RangosMagoPendientes() end
  if GL.RUTA and GL.RUTA.clase=="SHAMAN" then return GL.RangosChamanPendientes() end
  if GL.RUTA and GL.RUTA.clase=="PRIEST" then return GL.RangosSacerdotePendientes() end
  if GL.RUTA and GL.RUTA.clase == "ROGUE" then return GL.RangosPicaroPendientes() end
  if GL.RUTA and GL.RUTA.clase == "PALADIN" then return GL.RangosPaladinPendientes() end
  if GL.RUTA and GL.RUTA.clase == "HUNTER" then return GL.RangosCazadorPendientes() end
  return GL.RangosGuerreroPendientes()
end

-- Druida B03: normalizar el primer rango de Lacerar sin tocar Rutas/.
-- El antiguo 414647 no es el rango 1 del libro de hechizos actual.
function GL.EntrenamientoAuditado(R)
  local datos=R and R.entrenamiento or {}
  if not R or R.clase~="DRUID" then return datos end
  local r={}
  for _,e in ipairs(datos) do
    if e.id==1328616 then
      local f={};for k,v in pairs(e) do f[k]=v end
      f.ant=1328617;f.req={}
      for _,v in ipairs(e.req or {}) do f.req[#f.req+1]=v==414647 and 1328617 or v end
      r[#r+1]=f
    elseif e.id==3029 then
      local f={};for k,v in pairs(e) do f[k]=v end
      f.ant=1082;f.req={1082};r[#r+1]=f
    else r[#r+1]=e end
  end
  -- Observaciones de instructores: estimaciones, no precio universal.
  local presentes={};for _,e in ipairs(r) do presentes[e.id]=true end
  for _,e in ipairs({{id=1082,n=20,coste=4275,ant=0,req={768}},
      {id=1079,n=20,coste=4275,ant=0,req={768}},
      {id=5215,n=20,coste=14500,ant=0,req={768}}}) do
    if not presentes[e.id] then r[#r+1]=e end
  end
  return r
end
function GL.ExtrasAuditados(R)
  local datos=R and R.hechizosExtra or {}
  if not R or R.clase~="DRUID" then return datos end
  local r={}
  for _,e in ipairs(datos) do
    if e.id==414647 or e.id==16979 then
      local f={};for k,v in pairs(e) do f[k]=v end
      f.id=e.id==414647 and 1328617 or 1238122
      r[#r+1]=f
    else r[#r+1]=e end
  end
  local sky=R.id=="skyborne_a_druida" or R.id=="skyborne_druida"
  if sky then
    local alianza=R.id=="skyborne_a_druida"
    for i,e in ipairs(r) do if e.id==18960 then
      local t={};for k,v in pairs(e) do t[k]=v end
      t.mision=alianza and 94914 or 94913;t.misionNombre="Claro de la Luna";t.misionNombreEN="Moonglade";r[i]=t
    end end
    local ids={};for _,e in ipairs(r) do ids[e.id]=true end
    if not ids[8946] then r[#r+1]={id=8946,n=14,origen="mision",mision=alianza and 6125 or 6130,misionNombre="Poder contra el veneno",misionNombreEN="Power over Poison"} end
    if not ids[1066] then r[#r+1]={id=1066,n=16,origen="mision",mision=alianza and 5061 or 31,misionNombre="Forma acuática",misionNombreEN="Aquatic Form"} end
  end
  local oso,ya
  for _,e in ipairs(r) do if e.id==5487 then oso=e elseif e.id==6795 then ya=true end end
  if oso and not ya then r[#r+1]={id=6795,n=10,origen="mision",ant=0,mision=oso.mision,misionNombre=oso.misionNombre} end
  return r
end
-- Las versiones de Carga son variantes de forma, no rangos independientes.
function GL.CargaFeralConocida(id)
  if not GL.RUTA or GL.RUTA.clase~="DRUID" or (id~=1238122 and id~=16979 and id~=414924) then return false end
  return GL.HechizoConocido(1238122) or GL.HechizoConocido(16979) or GL.HechizoConocido(414924)
end

local delInstructor, siguientes, dondeDe, rutaIndices
local function Indices()
  if delInstructor and rutaIndices == GL.RUTA then return end
  rutaIndices = GL.RUTA
  delInstructor, siguientes, dondeDe = {}, {}, {}
  local datos = GL.EntrenamientoAuditado(GL.RUTA)
  for i = 1, #datos do
    local e = datos[i]
    delInstructor[e.id] = true
    -- Un requisito de actitud o de talento no demuestra que el jugador lo conozca.
    -- Si el catálogo declara ant, solo ese ID pertenece a la cadena de rangos.
    -- Los catálogos antiguos sin ant conservan la lógica anterior hasta su auditoría.
    local previos = e.ant ~= nil and (e.ant > 0 and { e.ant } or {}) or (e.req or {})
    -- Las tres llamadas de tótems son facultades distintas, no rangos.
    if GL.RUTA.clase=="SHAMAN" and (e.id==66843 or e.id==66844) then previos={} end
    for _, r in ipairs(previos) do
      siguientes[r] = siguientes[r] or {}
      table.insert(siguientes[r], e.id)
    end
  end
  if GL.RUTA and GL.RUTA.clase=="MAGE" then
    for _,e in ipairs(GL.ExtrasAuditados(GL.RUTA)) do
      if e.id==10140 then
        siguientes[10139]=siguientes[10139] or {}; table.insert(siguientes[10139],10140)
      end
    end
  end
  for _, e in ipairs(GL.RangosAuditadosPendientes()) do
    if not delInstructor[e.id] and e.ant and e.ant > 0 then
      siguientes[e.ant] = siguientes[e.ant] or {}
      table.insert(siguientes[e.ant], e.id)
    end
  end
  local donde = GL.RUTA and GL.RUTA.donde
  if type(donde) == "table" then
    for lugar, ids in pairs(donde) do
      for _, id in ipairs(ids) do dondeDe[id] = lugar end
    end
  end
end

-- Dónde se compra un hechizo que no vende tu instructor de clase (nil si lo vende él).
local function DondeHechizo(id)
  if not GL.RUTA then return nil end
  Indices()
  return dondeDe[id]
end

-- Los hechizos del instructor de mascotas no van a tu libro de hechizos, así que la guía apunta los que aprendes
-- (en GuiaAventureroDB.aprendidosFuera, por id): con el mensaje "Has aprendido..." y con las ventanas de instructor.
-- Cazador: familias de rangos del instructor de mascotas (45 IDs de R.donde).
-- Los niveles de aprendizaje del cazador y los de aplicación en mascota no son equivalentes.
local rangosInstructorMascota = {
  { es="Gran aguante", en="Great Stamina", ids={4187,4188,4189,4190,4191,4192,4193,4194,5041,5042} },
  { es="Armadura natural", en="Natural Armor", ids={24545,24549,24550,24551,24552,24553,24554,24555,24629,24630} },
  { es="Gruñido", en="Growl", ids={14917,14918,14919,14920,14921}, inicial=3 },
  { es="Resistencia al Fuego", en="Fire Resistance", ids={23992,24439,24444,24445} },
  { es="Resistencia a la Escarcha", en="Frost Resistance", ids={24446,24447,24448,24449} },
  { es="Resistencia a las Sombras", en="Shadow Resistance", ids={24488,24505,24506,24507} },
  { es="Resistencia a la Naturaleza", en="Nature Resistance", ids={24492,24502,24503,24504} },
  { es="Resistencia Arcana", en="Arcane Resistance", ids={24493,24497,24500,24501} },
}
local mascotaPorId = {}
for _, g in ipairs(rangosInstructorMascota) do
  for i, id in ipairs(g.ids) do mascotaPorId[id] = { grupo=g, rango=(g.inicial or 1)+i-1 } end
end
function GL.RangosInstructorMascota()
  if not GL.RUTA or GL.RUTA.clase ~= "HUNTER" then return {} end
  local filas, porId = {}, {}
  for _, e in ipairs(GL.RUTA.entrenamiento or {}) do porId[e.id]=e end
  for _, g in ipairs(rangosInstructorMascota) do
    for _, id in ipairs(g.ids) do
      local e=porId[id]
      if e and DondeHechizo(id) then
        filas[#filas+1]={id=id,es=g.es,en=g.en,rango=mascotaPorId[id].rango,n=e.n,coste=e.coste,
          nivelMascota=(id==4187 or id==24545) and 1 or e.n}
      end
    end
  end
  return filas
end
function GL.NombreRangoMascota(id)
  local m=mascotaPorId[id]
  if not m or not GL.RUTA or GL.RUTA.clase ~= "HUNTER" or not DondeHechizo(id) then return nil end
  return GL.ingles and m.grupo.en or m.grupo.es, m.rango
end

local function Apuntar(id)
  local db = DB()
  db.aprendidosFuera = db.aprendidosFuera or {}
  if db.aprendidosFuera[id] then return false end
  db.aprendidosFuera[id] = true
  return true
end

local function ConocidoFuera(id)
  if not DondeHechizo(id) then return false end
  local a = DB().aprendidosFuera
  return (a and a[id]) and true or false
end

-- Conocido también si ya tienes un rango superior (por si el juego deja de contar el rango anterior).
local function Conocido(id, prof)
  if GL.RUTA and GL.RUTA.clase=="DRUID" then
    if id==414647 then id=1328617 end
    -- Oso temible acredita el desbloqueo previo de oso, no al revés.
    if id==5487 and GL.HechizoConocido(9634) then return true end
    if GL.CargaFeralConocida(id) then return true end
  end
  if GL.HechizoConocido(id) or ConocidoFuera(id) then return true end
  -- Mutilate: the tree and spellbook exports use different IDs. Only recognize
  -- actual spells in the player's book; the earlier beta level is not a new unlock.
  if GL.RUTA and GL.RUTA.clase=="ROGUE" and id==1310706 and
      (GL.HechizoConocido(399956) or GL.HechizoConocido(1310707)) then return true end
  Indices()
  prof = (prof or 0) + 1
  local s = siguientes[id]
  if s and prof <= 20 then
    for _, sig in ipairs(s) do
      if Conocido(sig, prof) then return true end
    end
  end
  return false
end

-- Nivel de una habilidad que piden algunos hechizos (hab = { id, nivel }: los venenos del pícaro piden Venenos, la 40).
-- nil si no la tienes. El nombre (R.habilidades) solo hace falta si el juego no da el id de la habilidad. Se guarda
-- durante el fotograma: la pestaña Hechizos lo pregunta para muchos hechizos seguidos.
local cacheHab, cacheHabT, cacheHabRuta = {}, nil, nil
local function NivelHabilidad(skill)
  if not (skill and GL.NivelProfesion) then return nil end
  local t = GetTime and GetTime()
  if t == nil or t ~= cacheHabT or cacheHabRuta ~= GL.RUTA then
    for k in pairs(cacheHab) do cacheHab[k] = nil end
    cacheHabT, cacheHabRuta = t, GL.RUTA
  end
  local v = cacheHab[skill]
  if v == nil then
    local nombres = GL.RUTA and GL.RUTA.habilidades
    local ok, valor = pcall(GL.NivelProfesion, { skill = skill, nombre = nombres and nombres[skill] or "" })
    -- R15: una lectura desconocida no acredita un requisito ni bloquea el reintento.
    if not ok or not EnteroInstructorR14(valor) then return nil end
    v = valor
    cacheHab[skill] = v
  end
  return v or nil
end

local function NombreHabilidad(skill)
  local nombres = GL.RUTA and GL.RUTA.habilidades
  return (nombres and nombres[skill]) or L"la habilidad"
end

-- true si tienes el nivel de habilidad que pide (o si no pide ninguno). Con soloTalentos (niveles que llegan ahora o
-- más adelante) basta con tener la habilidad: el nivel lo irás subiendo.
local function HabilidadCumplida(e, soloTalentos)
  if not e.hab then return true end
  local nivel = NivelHabilidad(e.hab[1])
  if not nivel then return false end
  if soloTalentos then return true end
  return nivel >= (e.hab[2] or 0)
end

-- "con Venenos 120": lo que te falta de habilidad para un hechizo, o nil si ya lo tienes.
local function FaltaHabilidad(hab)
  if not hab then return nil end
  local nivel = NivelHabilidad(hab[1])
  if nivel and nivel >= (hab[2] or 0) then return nil end
  return L"con " .. NombreHabilidad(hab[1]) .. " " .. (hab[2] or 0)
end

-- Requisitos de un hechizo: el rango anterior o un talento, y el nivel de habilidad si pide alguno. Con soloTalentos
-- se da por hecho que irás comprando los rangos anteriores (para avisar de niveles futuros) y solo se mira el talento.
local function RequisitosCumplidos(e, soloTalentos)
  if not HabilidadCumplida(e, soloTalentos) then return false end
  Indices()
  -- Las bendiciones superiores II declaran ant aunque req incluya solo la bendición normal.
  -- No confundir la cadena del rango con los requisitos adicionales de la facultad.
  if GL.RUTA and e.ant and e.ant > 0 and
    not (soloTalentos and delInstructor[e.ant]) and not Conocido(e.ant) then return false end
  if not e.req then return true end
  for i = 1, #e.req do
    local r = e.req[i]
    if not (soloTalentos and delInstructor[r]) and not Conocido(r) then return false end
  end
  return true
end

-- Hechizos de tu instructor de esos niveles que puedes aprender y aún no tienes. Con todos = true (niveles
-- que llegan ahora o más adelante) no se mira si ya lo tienes ni el rango anterior, solo el talento.
local function Pendientes(desde, hasta, todos, soloDesconocidos)
  Indices()
  local lista = {}
  local datos = GL.EntrenamientoAuditado(GL.RUTA)
  for i = 1, #datos do
    local e = datos[i]
    local vale = e.n >= desde and e.n <= hasta
    if vale then
      if todos then vale = (not soloDesconocidos or not Conocido(e.id)) and RequisitosCumplidos(e, true)
      else vale = not Conocido(e.id) and RequisitosCumplidos(e, false) end
    end
    if vale then
      local nombre = NombreHechizo(e.id)
      if nombre then
        -- el consejo del nivel al que lo comprarías: el del rango o el tuyo si ya lo has pasado
        local c = Consejo(nombre, math.max(e.n, UnitLevel("player") or 1))
        table.insert(lista, { id = e.id, n = e.n, nombre = nombre, rango = RangoHechizo(e.id), coste = e.coste or 0,
          donde = dondeDe[e.id], hab = e.hab, c = c, orden = c and ORDEN[c.c] or 4, prioridad = c and c.prioridad or 999 })
      end
    end
  end
  table.sort(lista, OrdenFila)
  return lista
end

-- Lo recomendado de tu nivel que aún no tienes y que solo espera a que subas la habilidad que pide (Venenos), del
-- nivel de habilidad más bajo al más alto.
local function PendientesPorHabilidad(nivel)
  Indices()
  local lista = {}
  local datos = GL.EntrenamientoAuditado(GL.RUTA)
  for i = 1, #datos do
    local e = datos[i]
    if e.hab and e.n <= nivel and not Conocido(e.id) and HabilidadCumplida(e, true) and not HabilidadCumplida(e, false)
      and RequisitosCumplidos({ req = e.req, ant = e.ant }, false) then
      local nombre = NombreHechizo(e.id)
      local c = nombre and Consejo(nombre, math.max(e.n, nivel))
      if c and c.c == "comprar" then
        table.insert(lista, { id = e.id, n = e.n, nombre = nombre, rango = RangoHechizo(e.id), hab = e.hab,
          orden = e.hab[2] or 0, prioridad = c.prioridad or 999 })
      end
    end
  end
  table.sort(lista, OrdenFila)
  return lista
end

-- "Gran aguante (rango 2, en el instructor de mascotas)": el rango y, si no lo vende tu instructor, dónde se compra;
-- "Veneno instantáneo (rango 2, con Venenos 120)": el nivel de habilidad que pide, si aún no lo tienes.
local function NombreConRango(f)
  local extra = {}
  if f.rango and f.rango ~= "" then table.insert(extra, string.lower(f.rango)) end
  if f.donde then table.insert(extra, L"en el " .. f.donde) end
  local falta = FaltaHabilidad(f.hab)
  if falta then table.insert(extra, falta) end
  if #extra > 0 then return f.nombre .. " (" .. table.concat(extra, ", ") .. ")" end
  return f.nombre
end

-- "1. Descarga de Escarcha (rango 2), 2. Polimorfia" con los que hay que comprar.
local function ListaPrioridad(lista, maximo)
  local partes, coste, n = {}, 0, 0
  for i = 1, #lista do
    local f = lista[i]
    if f.c and f.c.c == "comprar" then
      n = n + 1
      coste = coste + f.coste
      if n <= maximo then table.insert(partes, n .. ". " .. NombreConRango(f)) end
    end
  end
  local texto = table.concat(partes, ", ")
  if n > maximo then texto = texto .. " y " .. (n - maximo) .. L" más" end
  return texto, n, coste
end

-- 9.7.4: cuándo vuelves al instructor y para qué: "nivel 32 (1. Descarga de Escarcha (rango 5))". nil si no queda nada.
function GL.SiguienteEntrenamiento(nivel)
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return nil end
  for siguiente = (nivel or 1) + 1, 60 do
    local ok, lista = pcall(Pendientes, siguiente, siguiente, true, true)
    if ok then
      local t, m = ListaPrioridad(lista, 3)
      if m > 0 then return L"nivel " .. siguiente .. " (" .. t .. ")", siguiente end
    end
  end
  return nil
end

-- Aviso al subir de nivel: lo nuevo de este nivel, lo importante primero. nil si no hay nada nuevo.
function GL.MensajeEntrenamiento(nivel)
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return nil end
  local nuevos = Pendientes(nivel, nivel, true)
  if #nuevos == 0 then return nil end
  local instructor = GL.RUTA.instructor or L"instructor de clase"
  local texto, n = ListaPrioridad(nuevos, 6)
  local otros = #nuevos - n
  local msg
  if n > 0 then
    msg = L"Nivel " .. nivel .. L": en tu " .. instructor .. L" aprende " .. texto .. "."
    if otros == 1 then msg = msg .. L" Hay 1 más que no hace falta."
    elseif otros > 1 then msg = msg .. L" Hay " .. otros .. L" más que no hacen falta." end
  else
    if #nuevos == 1 then
      msg = L"Nivel " .. nivel .. L": tu " .. instructor .. L" tiene 1 hechizo nuevo, pero no hace falta para subir."
    else
      msg = L"Nivel " .. nivel .. L": tu " .. instructor .. L" tiene " .. #nuevos .. L" hechizos nuevos, pero ninguno hace falta para subir."
    end
  end
  if n > 0 and AutoActivo() then msg = msg .. L" La guía los aprende sola al abrir la ventana del instructor." end
  return msg
end

-- Bloque de la pestaña Hechizos: lo que puedes aprender ya y cuándo es el siguiente entrenamiento.
-- 6.3: cuántos hechizos recomendados puedes aprender ya (para el aviso de preparación).
function GL.HechizosParaAprender()
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return 0 end
  local _, n = ListaPrioridad(Pendientes(1, UnitLevel("player") or 1), 5)
  return n or 0
end

-- Fase 5: solo compras de clase disponibles, no adiestramiento de mascotas ni otros lugares.
function GL.EntrenamientoClasePendiente()
  local n, coste = 0, 0
  for _, f in ipairs(Pendientes(1, UnitLevel("player") or 1)) do
    if not f.donde and f.c and f.c.c == "comprar" then
      n = n + 1
      coste = coste + f.coste
    end
  end
  return n, coste
end

-- 6.4: coste de lo recomendado que puedes aprender ya y del próximo nivel con entrenamiento.
function GL.CostesEntrenamiento()
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return nil end
  local nivel = UnitLevel("player") or 1
  local _, n, coste = ListaPrioridad(Pendientes(1, nivel), 5)
  local sigNivel, sigCoste, sigN
  for siguiente = nivel + 1, 60 do
    local _, m, c = ListaPrioridad(Pendientes(siguiente, siguiente, true, true), 5)
    if m > 0 then sigNivel, sigCoste, sigN = siguiente, c, m; break end
  end
  return n, coste, sigNivel, sigCoste, sigN
end

-- 7.0: lo recomendado que se aprende justo en este nivel, con icono y precio (para la celebración).
function GL.HechizosNuevos(nivel)
  local r = {}
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return r end
  local lista = Pendientes(nivel, nivel)
  for i = 1, #lista do
    local f = lista[i]
    if f.c and f.c.c == "comprar" then
      local icono = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(f.id)) or (GetSpellTexture and GetSpellTexture(f.id))
      table.insert(r, { nombre = NombreConRango(f), coste = f.coste or 0, icono = icono })
    end
  end
  return r
end

function GL.TextoHechizosNivel()
  if not (GL.RUTA and GL.RUTA.entrenamiento and #GL.RUTA.entrenamiento > 0) then return nil end
  local nivel = UnitLevel("player") or 1
  local lineas = {}
  local ya = Pendientes(1, nivel)
  local texto, n, coste = ListaPrioridad(ya, 5)
  if n > 0 then
    table.insert(lineas, C.AMARILLO .. L"Aprende ya en tu instructor, por prioridad: " .. C.FIN .. C.BLANCO .. texto .. C.FIN ..
      C.GRIS .. " (" .. (GL.ingles and "est. " or "aprox. ") .. Dinero(coste) .. ")" .. C.FIN)
  else
    table.insert(lineas, C.VERDE .. L"Ya tienes todo lo importante de tu nivel." .. C.FIN)
  end
  local falta = PendientesPorHabilidad(nivel)
  if #falta > 0 then
    local partes = {}
    for i = 1, math.min(#falta, 4) do table.insert(partes, NombreConRango(falta[i])) end
    local h = falta[1].hab
    local tienes = NivelHabilidad(h[1]) or 0
    table.insert(lineas, C.AMARILLO .. L"Sube " .. NombreHabilidad(h[1]) .. L" para aprender: " .. C.FIN .. C.BLANCO ..
      table.concat(partes, ", ") .. (#falta > 4 and (" y " .. (#falta - 4) .. L" más") or "") .. C.FIN ..
      C.GRIS .. L" (tienes " .. tienes .. ")." .. C.FIN)
  end
  for siguiente = nivel + 1, 60 do
    local lista = Pendientes(siguiente, siguiente, true)
    local t, m = ListaPrioridad(lista, 3)
    if m > 0 then
      table.insert(lineas, C.GRIS .. L"Siguiente entrenamiento: nivel " .. siguiente .. " (" .. t .. ")." .. C.FIN)
      break
    end
  end
  return table.concat(lineas, "\n")
end

------------------------------------------------------------------------
-- Panel junto a la ventana del instructor
------------------------------------------------------------------------
local AprenderRecomendado, EsAdiestramiento, IdDelServicio

local function CrearPanel()
  panel = CreateFrame("Frame", "GuiaAventureroInstructor", UIParent, PLANTILLA)
  panel:SetWidth(ANCHO)
  panel:SetHeight(120)
  panel:SetFrameStrata("HIGH")
  GL.Caja(panel, GL.COLOR.fondo, GL.COLOR.borde)
  GL.Sombra(panel)
  GL.Acento(panel, 2)
  panel.titulo = GL.Texto(panel, "GameFontNormal")
  panel.titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
  panel.titulo:SetText(L"Guía del Aventurero: qué aprender")
  panel.sub = GL.Texto(panel, "GameFontHighlightSmall")
  panel.sub:SetPoint("TOPLEFT", panel.titulo, "BOTTOMLEFT", 0, -2)
  panel.sub:SetText(C.GRIS .. L"Por orden de prioridad: lo de arriba primero." .. C.FIN)
  panel.lineas = {}
  for i = 1, MAX_LINEAS do
    local t = GL.Texto(panel, "GameFontHighlightSmall")
    t:SetWidth(ANCHO - 24)
    panel.lineas[i] = t
  end
  panel.pie = GL.Texto(panel, "GameFontHighlightSmall")
  panel.pie:SetWidth(ANCHO - 24)
  panel.boton = GL.CrearBoton(panel, L"Aprender lo recomendado", function() AprenderRecomendado(true) end, nil, 22, "accion")
  panel.boton:SetWidth(ANCHO - 24)
  GL.Ayuda(panel.boton, L"Aprender lo recomendado",
    L"Compra los hechizos marcados con Compra, en orden de prioridad, mientras te llegue el dinero.")
  panel:Hide()
end

local function Colocar()
  panel:ClearAllPoints()
  local trainer = ClassTrainerFrame
  if trainer and trainer.IsShown and trainer:IsShown() then
    panel:SetPoint("TOPLEFT", trainer, "TOPRIGHT", 4, 0)
  else
    panel:SetPoint("LEFT", UIParent, "LEFT", 420, 60)
  end
end

-- Para sacerdote, un consejo favorable no acredita por sí solo que la fila sea un
-- rango entrenable: no comprar un códice, talento inicial o una coincidencia ambigua.
local function ServicioSacerdoteSeguro(nombre,rango)
  local candidato
  local raza=GL.Raza and GL.Raza()
  local nivel=GL.NivelJugadorR14 and GL.NivelJugadorR14()
  if not nivel then return false end
  for _,e in ipairs(GL.EntrenamientoAuditado(GL.RUTA)) do
    if (not e.raza or e.raza==raza) and NombreHechizo(e.id)==nombre and RangoHechizo(e.id)==(rango or "") then
      if candidato then return false end
      candidato=e
    end
  end
  return candidato and candidato.n<=nivel and not Conocido(candidato.id) and RequisitosCumplidos(candidato,false)
end

-- No comprar automáticamente un rango ambiguo, tablilla, talento ni competencia externa.
local function ServicioChamanSeguro(nombre,rango)
  if not ServicioSacerdoteSeguro(nombre,rango) then return false end
  local function coincide(e) return NombreHechizo(e.id)==nombre and RangoHechizo(e.id)==(rango or "") end
  for _,e in ipairs(GL.RangosAuditadosPendientes()) do if coincide(e) then return false end end
  for _,e in ipairs(GL.ExtrasAuditados(GL.RUTA)) do if coincide(e) then return false end end
  return true
end

-- Una lectura fallida no equivale a una lista vacía. No usar filas parciales para comprar.
local function CantidadServiciosR14()
  if type(GetNumTrainerServices)~="function" or type(GetTrainerServiceInfo)~="function" then return nil end
  local ok,n=pcall(GetNumTrainerServices)
  if ok and EnteroInstructorR14(n) then return n end
end
local function FilaServicioR14(i)
  local ok,n,r,t=pcall(GetTrainerServiceInfo,i)
  if not ok or not TextoInstructorR14(t) or not TextoInstructorR14(n) or
      not PublicoInstructorR14(r) or (r~=nil and type(r)~="string") then return nil end
  return n,r,t
end
local function PrecioServicioR14(i)
  local ok,p=pcall(GetTrainerServiceCost,i)
  if ok and EnteroInstructorR14(p) then return p end
end
-- Hechizos que ofrece el instructor ahora mismo, con su consejo.
local function Servicios()
  local filas = {}
  local cantidad = CantidadServiciosR14()
  if not cantidad then return {},false end
  for i = 1,cantidad do
    local nombre, rango, tipo = FilaServicioR14(i)
    if not nombre then return {},false end
    if tipo == "available" then
      local c = Consejo(nombre)
      -- Nunca gastar puntos de mascota ni comprar sus recetas por nombre ambiguo.
      -- Las lecciones de mascota se compran desde la interfaz nativa; el addon solo informa.
      if GL.RUTA and GL.RUTA.clase == "HUNTER" then
        Indices()
        local id = IdDelServicio and IdDelServicio(i,nombre,rango)
        local coincide = id and dondeDe[id]
        if not coincide then
          for petId in pairs(dondeDe) do if NombreHechizo(petId) == nombre then coincide=true; break end end
        end
        if coincide then c={c="opcional",nota=GL.ingles and "Learn manually from the pet trainer; then teach your pet via Beast Training." or "Apréndelo manualmente con el instructor de mascotas; después enséñaselo con Entrenar bestia."} end
      end
      -- Same conservative identity and prerequisites check for all nine classes.
      if GL.RUTA and c and c.c=="comprar" and not ServicioChamanSeguro(nombre,rango) then
        c={c="opcional",nota=GL.ingles and "Trainer entry not uniquely verified; learn manually if appropriate." or "Entrada del instructor no identificada de forma inequívoca; aprende manualmente si procede.",prioridad=c.prioridad}
      end
      -- No confundir una lectura fallida con una leccion gratuita.
      local precio = PrecioServicioR14(i)
      if precio == nil then return {},false end
      table.insert(filas, { i = i, nombre = nombre, rango = rango, precio = precio, c = c,
        orden = c and ORDEN[c.c] or 4, prioridad = c and c.prioridad or 999 })
    end
  end
  if CantidadServiciosR14() ~= cantidad then return {},false end
  table.sort(filas, OrdenFila)
  return filas,true
end

local function Actualizar()
  if not panel then CrearPanel() end
  local filas, completa = Servicios()
  local coste, n = 0, 0
  local y = -44
  for i = 1, MAX_LINEAS do
    local t = panel.lineas[i]
    local f = filas[i]
    if f then
      local nombre = C.BLANCO .. f.nombre .. C.FIN
      if f.rango and f.rango ~= "" then nombre = nombre .. C.GRIS .. " (" .. f.rango .. ")" .. C.FIN end
      local texto
      if f.c then
        local numero = ""
        if f.c.c == "comprar" then
          n = n + 1
          numero = C.AMARILLO .. n .. ". " .. C.FIN
        end
        texto = numero .. ETIQUETA[f.c.c] .. "  " .. nombre .. "\n" .. C.GRIS .. f.c.nota .. C.FIN
      else
        texto = C.GRIS .. L"Opcional" .. C.FIN .. "  " .. nombre .. "\n" .. C.GRIS .. L"La guía no lo usa para subir: cómpralo solo si lo quieres." .. C.FIN
      end
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
      t:SetText(texto)
      t:Show()
      y = y - GL.Alto(t, texto, 12, ANCHO - 24) - 5
    else
      t:Hide()
    end
  end
  for i = 1, #filas do
    if filas[i].c and filas[i].c.c == "comprar" then coste = coste + filas[i].precio end
  end
  local pie
  local hayCompra = coste > 0 or n > 0
  local nivel = GL.NivelJugadorR14 and GL.NivelJugadorR14()
  local sig = nivel and GL.SiguienteEntrenamiento and GL.SiguienteEntrenamiento(nivel)
  local vuelve = sig and ("\n" .. C.GRIS .. L"Vuelve al instructor al " .. sig .. "." .. C.FIN) or ""
  if not completa then
    pie = C.AMARILLO .. L"No se pudo leer la lista del instructor. Vuelve a intentarlo." .. C.FIN
  elseif #filas == 0 then
    pie = C.GRIS .. L"No hay nada nuevo que aprender ahora: no hace falta comprar nada." .. C.FIN .. vuelve
  elseif n == 0 then
    pie = C.VERDE .. L"Ya tienes todo lo recomendado." .. C.FIN .. C.GRIS .. L" Lo que queda no hace falta para subir: no lo compres si no lo quieres." .. C.FIN .. vuelve
  else
    local okDinero, dinero = pcall(GetMoney)
    if not okDinero or not EnteroInstructorR14(dinero) then dinero=nil; hayCompra=false end
    pie = L"Lo recomendado cuesta " .. Dinero(coste) .. C.GRIS .. L"  (tienes " .. (dinero and Dinero(dinero) or "?") .. ")" .. C.FIN
    if dinero and coste > dinero then pie = pie .. "\n" .. C.AMARILLO .. L"No te llega para todo: se compra en orden hasta donde llegue." .. C.FIN end
    if #filas > MAX_LINEAS then pie = pie .. "\n" .. C.GRIS .. "Y " .. (#filas - MAX_LINEAS) .. L" más en la lista del instructor." .. C.FIN end
    if AutoActivo() then
      pie = pie .. "\n" .. C.GRIS .. L"La guía compra sola lo marcado con Compra (Mayús al abrir el instructor para no hacerlo)." .. C.FIN
    end
  end
  panel.pie:ClearAllPoints()
  panel.pie:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y - 4)
  panel.pie:SetText(pie)
  local altoPie = GL.Alto(panel.pie, pie, 12, ANCHO - 24)
  local alto = -y + 4 + altoPie + 14
  if hayCompra then
    panel.boton:ClearAllPoints()
    panel.boton:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y - 4 - altoPie - 8)
    panel.boton:Show()
    alto = alto + 30
  else
    panel.boton:Hide()
  end
  panel:SetHeight(alto)
end

local function EnCombateCompra()
  return not (GL.AccionProtegidaPermitidaR13 and GL.AccionProtegidaPermitidaR13()) or
    not (GL.PersonajeVivoR14 and GL.PersonajeVivoR14())
end

local function SaldoCompra(manual)
  local ok, total = pcall(GetMoney or function() end)
  if not ok or not EnteroInstructorR14(total) then return nil end
  if manual then return total end
  if GL.ReservaOro then
    local valido, reserva = pcall(GL.ReservaOro, true)
    if not valido or not EnteroInstructorR14(reserva) then return nil end
    return math.max(0, total - reserva)
  end
  if GL.DineroParaComprar then
    local valido, saldo = pcall(GL.DineroParaComprar, false)
    if valido and EnteroInstructorR14(saldo) then return math.min(total, saldo) end
    return nil
  end
  return total
end

local function CompraPermitida(manual, sesion)
  if EnCombateCompra() or not sesionAbierta or sesion ~= sesionInstructor or not GL.RUTA or GL.RUTA ~= rutaSesion then return false end
  if not manual and (not autoSesion or not AutoActivo() or (IsShiftKeyDown and IsShiftKeyDown())) then return false end
  if ClassTrainerFrame and ClassTrainerFrame.IsShown and not ClassTrainerFrame:IsShown() then return false end
  if IsTradeskillTrainer ~= nil then
    local ok, profesion = pcall(IsTradeskillTrainer)
    if not ok or not PublicoInstructorR14(profesion) or (profesion~=false and profesion~=0) then return false end
  end
  if GL.RUTA and GL.RUTA.clase == "HUNTER" then
    if not UnitExists or not UnitExists("npc") or (EsAdiestramiento and EsAdiestramiento()) then return false end
    if C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType and Enum.TrainerType.Pet then
      local ok,t=pcall(C_Trainer.GetTrainerType)
      if not ok or t==Enum.TrainerType.Pet then return false end
    end
  end
  return true
end

-- Compra lo marcado con Compra, por orden de prioridad, mientras llegue el dinero. Devuelve cuántos ha pedido.
local function SolicitarCompra(manual)
  local sesion = sesionInstructor
  if not CompraPermitida(manual, sesion) then return 0 end
  if not (GetNumTrainerServices and GetTrainerServiceInfo and BuyTrainerService) then return 0 end
  local filas, completa = Servicios()
  if not completa then return 0 end
  local dinero = SaldoCompra(manual)
  -- en orden estricto: si no llega para uno, se para ahí para no gastar el dinero en algo menos importante
  if type(dinero) ~= "number" or dinero < 0 or dinero >= math.huge or dinero ~= dinero then return 0 end
  local elegidos, gasto, faltan, falta, primero = {}, 0, 0, 0, nil
  for _, f in ipairs(filas) do
    if f.c and f.c.c == "comprar" then
      if faltan == 0 and gasto + f.precio <= dinero then
        table.insert(elegidos, f)
        gasto = gasto + f.precio
      else
        faltan = faltan + 1
        falta = falta + f.precio
        primero = primero or f
      end
    end
  end
  if #elegidos == 0 then
    if manual then
      GL.Mensaje(primero and (L"no te llega el dinero para " .. primero.nombre .. L" (cuesta " .. Dinero(primero.precio) .. ").")
        or L"no hay nada recomendado que aprender ahora.")
    elseif primero and GL.AvisoReserva then
      GL.AvisoReserva(primero.precio)
    end
    return 0
  end
  local nombres, solicitado = {}, 0
  -- Revalidar cada fila: una compra o un evento puede cambiar el diálogo, el índice o el precio.
  table.sort(elegidos, function(a, b) return a.i > b.i end)
  for _, f in ipairs(elegidos) do
    if not CompraPermitida(manual, sesion) then break end
    local nombre, sub, tipo = FilaServicioR14(f.i)
    local precio = PrecioServicioR14(f.i)
    if nombre ~= f.nombre or sub ~= f.rango or tipo ~= "available" or precio ~= f.precio then break end
    local saldo = SaldoCompra(manual)
    if type(saldo) ~= "number" or saldo ~= saldo or saldo < precio or saldo >= math.huge or not CompraPermitida(manual, sesion) then break end
    local pedido, resultado = pcall(BuyTrainerService, f.i)
    if not pedido or resultado == false then break end
    table.insert(nombres, f.nombre .. ((f.rango and f.rango ~= "") and (" (" .. f.rango .. ")") or ""))
    solicitado = solicitado + precio
  end
  if #nombres > 0 then
    if sesionAbierta and sesion == sesionInstructor then comprando = true end
    GL.Mensaje(L"solicito aprender en el instructor: " .. table.concat(nombres, ", ") .. " (" .. Dinero(solicitado) .. ").")
  end
  if #nombres == #elegidos and faltan > 0 then
    GL.Mensaje(L"no te llega el dinero para " .. faltan .. L" más (" .. Dinero(falta) .. L"): vuelve cuando lo tengas.")
  end
  return #nombres
end

AprenderRecomendado = function(manual)
  if ejecutandoCompra then return 0 end
  ejecutandoCompra = true
  local ok, n = pcall(SolicitarCompra, manual)
  ejecutandoCompra = false
  if not ok then
    if GL.Fallo then GL.Fallo("instructor",n) end
    return 0
  end
  return n
end

local function EsInstructorDeClase()
  if IsTradeskillTrainer ~= nil then
    local ok, r = pcall(IsTradeskillTrainer)
    if not ok or not PublicoInstructorR14(r) or (r~=false and r~=0) then return false end
  end
  return true
end

-- En Forever, Adiestramiento de bestias abre una ventana de instructor con lo que tu cazador ya sabe para enseñar a
-- su mascota: no hay PNJ delante (o el PNJ es tu propia mascota). Ahí la guía solo apunta lo que sabes y no enseña
-- nada a tu mascota. El instructor de mascotas de verdad es un PNJ: ahí la guía compra como en tu instructor.
EsAdiestramiento = function()
  local confirmado = false
  if C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType and Enum.TrainerType.Pet then
    local ok, t = pcall(C_Trainer.GetTrainerType)
    if ok and t ~= nil and t ~= Enum.TrainerType.Pet then return false end
    confirmado = ok and t == Enum.TrainerType.Pet
  end
  if not UnitExists then return false end
  if not UnitExists("npc") then return confirmado end
  if UnitIsUnit then
    local ok, r = pcall(UnitIsUnit, "npc", "pet")
    if ok and r then return true end
  end
  return false
end

-- Id del hechizo de una fila del instructor: el de su ventana de ayuda o, si no, por el nombre y el rango.
IdDelServicio = function(i, nombre, rango)
  if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
    local ok, t = pcall(C_TooltipInfo.GetTrainerService, i)
    if ok and type(t) == "table" and t.id then
      local id=tonumber(t.id); return id and dondeDe[id] and id or nil
    end
  end
  local nr = tonumber(string.match(rango or "", "(%d+)")) or 0
  if nr <= 0 then return nil end
  local encontrado
  for id in pairs(dondeDe) do
    local real = tonumber(string.match(RangoHechizo(id), "(%d+)")) or (mascotaPorId[id] and mascotaPorId[id].rango)
    if NombreHechizo(id) == nombre and real == nr then
      if encontrado then return nil end
      encontrado=id
    end
  end
  return encontrado
end

-- Apunta los hechizos de R.donde que ya sabes según la ventana abierta: en Adiestramiento de bestias, todo lo que
-- sale; en un instructor, lo que sale como ya aprendido. true si ha apuntado alguno nuevo.
local function ApuntarDeLaVentana()
  Indices()
  if not next(dondeDe) or not (GetNumTrainerServices and GetTrainerServiceInfo) then return false end
  local todo = EsAdiestramiento()
  if not todo and (not UnitExists or not UnitExists("npc")) then return false end
  local cantidad = CantidadServiciosR14()
  if not cantidad then return false end
  local candidatos = {}
  for i = 1,cantidad do
    local nombre, rango, tipo = FilaServicioR14(i)
    if not nombre then return false end
    if tipo ~= "header" and (todo or tipo == "used") then
      local id = IdDelServicio(i, nombre, rango)
      if id and dondeDe[id] then candidatos[id]=true end
    end
  end
  if CantidadServiciosR14()~=cantidad then return false end
  local nuevo = false
  for id in pairs(candidatos) do if Apuntar(id) then nuevo=true end end
  return nuevo
end

-- "Has aprendido un hechizo nuevo: [Gran aguante]": Forever pone el enlace del hechizo, con su id. Se miran los
-- tres mensajes del juego (hechizo, habilidad y pasiva) en el idioma del cliente.
local function Patron(s)
  if type(s) ~= "string" or s == "" then return nil end
  s = string.gsub(s, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  local p, n = string.gsub(s, "%%%%s", "(.+)")
  if n ~= 1 then return nil end
  return p
end
local PATRONES_APRENDIDO = {}
for _, clave in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S" }) do
  local p = Patron(_G[clave])
  if p then table.insert(PATRONES_APRENDIDO, p) end
end

local function AlMensajeDelSistema(texto)
  Indices()
  if not (#PATRONES_APRENDIDO > 0 and next(dondeDe) and type(texto) == "string") then return end
  for _, patron in ipairs(PATRONES_APRENDIDO) do
    local m = string.match(texto, patron)
    local id = m and tonumber(string.match(m, "|Hspell:(%d+)"))
    if id then
      if dondeDe[id] and Apuntar(id) and GL.RefrescarHechizos then GL.RefrescarHechizos() end
      return
    end
  end
end

local function MostrarPanel()
  local ok, err = pcall(Actualizar)
  if ok then
    Colocar()
    panel:Show()
  else
    if panel then panel:Hide() end
    if GL.Fallo(L"panel del instructor", err) then GL.Mensaje(L"error: " .. tostring(err)) end
  end
end

local function CompraAutomatica()
  if not (sesionAbierta and autoSesion and GL.RUTA and GL.RUTA == rutaSesion) then return end
  if not CompraPermitida(false, sesionInstructor) or oleadas >= MAX_OLEADAS then return end
  if not EsInstructorDeClase() or (dondeDe and next(dondeDe) and EsAdiestramiento()) then return end
  oleadas = oleadas + 1
  local ok, n = pcall(AprenderRecomendado, false)
  if not ok and GL.Fallo("instructor", n) then GL.Mensaje(L"error: " .. tostring(n)) end
end

function GL.CancelarCompraHechizos()
  autoSesion, compraPendiente = false, nil
end

local function ProgramarCompra()
  if not (sesionAbierta and autoSesion and AutoActivo()) or compraPendiente then return end
  local sesion = sesionInstructor
  local function ejecutar()
    if compraPendiente ~= ejecutar then return end
    compraPendiente = nil
    if sesion == sesionInstructor then
      local ok,err=pcall(CompraAutomatica)
      if not ok then
        autoSesion=false
        if GL.Fallo then GL.Fallo("instructor",err) end
      end
    end
  end
  compraPendiente = ejecutar
  if C_Timer and C_Timer.After then
    local ok,resultado=pcall(C_Timer.After,0.3,ejecutar)
    if (not ok or resultado==false) and compraPendiente==ejecutar then
      compraPendiente=nil
      autoSesion=false
      if GL.Fallo then GL.Fallo("instructor",resultado) end
    end
  else ejecutar() end
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "TRAINER_SHOW")
GL.Evento(eventos, "TRAINER_UPDATE")
GL.Evento(eventos, "TRAINER_CLOSED")
GL.Evento(eventos, "PLAYER_LEAVING_WORLD")
GL.Evento(eventos, "CHAT_MSG_SYSTEM")
eventos:SetScript("OnEvent", function(self, event, texto)
  if event == "TRAINER_SHOW" or event == "TRAINER_CLOSED" or event == "PLAYER_LEAVING_WORLD" then
    sesionInstructor = sesionInstructor + 1
    sesionAbierta, autoSesion, compraPendiente = false, false, nil
    rutaSesion, comprando = nil, false
  end
  if event == "TRAINER_CLOSED" or event == "PLAYER_LEAVING_WORLD" then
    if panel then panel:Hide() end
    comprando = false
    return
  end
  if not GL.RUTA then return end
  if event == "CHAT_MSG_SYSTEM" then
    pcall(AlMensajeDelSistema, texto)
    return
  end
  local ok, nuevo = pcall(ApuntarDeLaVentana)
  if ok and nuevo and GL.RefrescarHechizos then GL.RefrescarHechizos() end
  if not EsInstructorDeClase() or (dondeDe and next(dondeDe) and EsAdiestramiento()) then
    GL.CancelarCompraHechizos()
    sesionAbierta, rutaSesion, comprando = false, nil, false
    if panel then panel:Hide() end
    return
  end
  if event == "TRAINER_SHOW" then
    oleadas = 0
    comprando = false
    local conMayus = IsShiftKeyDown and IsShiftKeyDown()
    sesionAbierta, autoSesion, rutaSesion = true, not conMayus and AutoActivo(), GL.RUTA
    if DB().instructor ~= false then MostrarPanel() end
    ProgramarCompra()
    return
  end
  -- TRAINER_UPDATE: la lista cambió (por ejemplo tras comprar); comprar un rango puede abrir el siguiente
  if panel and panel:IsShown() then MostrarPanel() end
  if comprando then
    comprando = false
    ProgramarCompra()
  end
end)

GL.AprenderRecomendado = AprenderRecomendado
GL.NombreHechizo, GL.RangoHechizo, GL.ConsejoHechizo, GL.Dinero = NombreHechizo, RangoHechizo, Consejo, Dinero
GL.DondeHechizo, GL.ConocidoFuera = DondeHechizo, ConocidoFuera
GL.NivelHabilidad, GL.NombreHabilidad = NivelHabilidad, NombreHabilidad
GL.HechizoORangoConocido = Conocido

GL.comandos["instructor"] = function()
  local db = DB()
  db.instructor = (db.instructor == false)
  GL.Mensaje(L"ayuda en los instructores " .. (db.instructor and L"activada." or L"desactivada."))
end

GL.comandos["autohechizos"] = function()
  local db = DB()
  db.autoHechizos = (db.autoHechizos == false)
  if not db.autoHechizos then GL.CancelarCompraHechizos() end
  GL.Mensaje(db.autoHechizos and L"aprender solo lo recomendado en el instructor: activado (Mayús al abrirlo para no hacerlo)."
    or L"aprender solo lo recomendado en el instructor: desactivado (usa el botón del panel).")
end

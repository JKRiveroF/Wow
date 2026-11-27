-- Hechizos.lua: lista de los hechizos de tu clase con el nivel al que se aprenden y lo que cuestan, con filtro por
-- especialización. Lo que hace cada uno sale al pasar el ratón por su icono (la ventana del hechizo del juego).
-- Creado por JKRiveroF.
-- Datos de la ruta: R.entrenamiento (instructor de Forever), R.hechizosExtra (los del principio, los de talento y
-- los de misión), R.ramaHechizo (rama de cada hechizo por su primer rango) y R.especialidades (botones del filtro).
-- El nombre, el rango, el icono y la ventana del hechizo los da el juego, en el idioma del cliente.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local ROJO = "|cffff7060"
local TODAS = "Todas" -- clave interna; se traduce solo al pintar
local LADO_ICONO = 30
local ICONO_PESTANA = "Interface\\Icons\\INV_Misc_Book_09"
local ANCHO_SOLO = 150                -- botón "Solo lo disponible"

local panel, scroll, hijo, barra, resumen, botonSolo, botonIr
local filtros = {}                    -- botones del filtro por especialización
local filas = {}                      -- filas de la lista, se reutilizan
local cabeceras = {}                  -- 9.6: «Para aprender ya» y «Más adelante»
local rutaGrupos
local grupos                          -- hechizos agrupados por cadena de rangos
local indice = {}                     -- cada hechizo de la lista por su id
local pedidos = {}                    -- hechizos cuyo nombre se ha pedido al juego
local refrescoPendiente = false

local function DB() return GuiaAventureroDB end

------------------------------------------------------------------------
-- Datos: cada hechizo con todos sus rangos
------------------------------------------------------------------------
-- Habilidades activas de talentos de guerrero, no vendidas por instructor.
-- Fuente: wow-forever.gg/classes/warrior/spellbook y warcraftforever.games/classes/warrior/spells.
-- No se modifican las rutas de leveo; los nombres y tooltips los resuelve el cliente por ID.
local talentosGuerrero = {
  { id = 12975, n = 20, rama = "Protección", en = "Last Stand" },
  { id = 12323, n = 20, rama = "Furia", en = "Piercing Howl" },
  { id = 1329555, n = 25, rama = "Furia", en = "Reckless Swings" },
  { id = 1310222, n = 25, rama = "Armas", en = "Spearing Strike" },
  { id = 12809, n = 30, rama = "Protección", en = "Concussion Blow" },
  { id = 12328, n = 30, rama = "Furia", en = "Death Wish" },
  { id = 12292, n = 30, rama = "Armas", en = "Sweeping Strikes" },
}
local nombresPlanGuerrero = { [12294] = "Mortal Strike", [23881] = "Bloodthirst", [23922] = "Shield Slam" }
for _, e in ipairs(talentosGuerrero) do nombresPlanGuerrero[e.id] = e.en end

-- Paladín: talentos activos y nivel mínimo de la fila actual, no precio de instructor.
-- Fuentes: talentsforever.com/paladin/abilities (contraste 71139),
-- armorywowforever.com/talents/paladin (70790), questing.wiki y Warcraft Forever (IDs).
-- Etiquetas ES de guía según Especializacion.lua; el cliente prevalece en su idioma.
local talentosPaladin = {
  { id = 20216, n = 20, rama = "Sagrado", en = "Divine Favor", es = "Favor divino" },
  { id = 1328548, n = 25, rama = "Sagrado", en = "Oath of Light", es = "Juramento de Luz" },
  { id = 1311606, n = 30, rama = "Sagrado", en = "Holy Shock", es = "Choque sagrado" },
  { id = 1310911, n = 40, rama = "Sagrado", en = "Light's Vigil", es = "Vigilia de la Luz" },
  { id = 1311015, n = 20, rama = "Protección", en = "Templar's Bulwark", es = "Baluarte de templario" },
  { id = 1310994, n = 25, rama = "Protección", en = "Swift Judgement", es = "Juicio presto" },
  { id = 20925, n = 30, rama = "Protección", en = "Holy Shield", es = "Escudo sagrado" },
  { id = 20375, n = 20, rama = "Reprensión", en = "Seal of Command", es = "Sello de orden" },
  { id = 20066, n = 30, rama = "Reprensión", en = "Repentance", es = "Arrepentimiento" },
}
-- Nombres de familias con rango final añadido; el nombre nativo prevalece en su idioma.
-- Etiquetas de guía ES/EN; el cliente prevalece en su idioma.
local nombresRangosPaladin = {
  [465] = {"Aura de devoción", "Devotion Aura"},
  [498] = {"Protección divina", "Divine Protection"},
  [633] = {"Imposición de manos", "Lay on Hands"},
  [635] = {"Luz Sagrada", "Holy Light"},
  [642] = {"Escudo divino", "Divine Shield"},
  [679] = {"Golpe sagrado", "Holy Strike"},
  [750] = {"Armadura de placas", "Plate Mail"},
  [853] = {"Martillo de Justicia", "Hammer of Justice"},
  [879] = {"Exorcismo", "Exorcism"},
  [1022] = {"Bendición de protección", "Blessing of Protection"},
  [1044] = {"Bendición de libertad", "Blessing of Freedom"},
  [1152] = {"Purificar", "Purify"},
  [2812] = {"Cólera Sagrada", "Holy Wrath"},
  [2878] = {"Ahuyentar no-muertos", "Turn Undead"},
  [3127] = {"Parada", "Parry"},
  [4987] = {"Limpiar", "Cleanse"},
  [5502] = {"Captar no-muertos", "Sense Undead"},
  [6940] = {"Bendición de sacrificio", "Blessing of Sacrifice"},
  [7294] = {"Aura de reprensión", "Retribution Aura"},
  [7328] = {"Redención", "Redemption"},
  [13819] = {"Invocar caballo de guerra", "Summon Warhorse"},
  [1279399] = {"Invocar caballo de guerra", "Summon Warhorse"},
  [23214] = {"Invocar destrero", "Summon Charger"},
  [1296534] = {"Invocar destrero de los Renegados", "Summon Forsaken Charger"},
  [19740] = {"Bendición de poderío", "Blessing of Might"},
  [19742] = {"Bendición de sabiduría", "Blessing of Wisdom"},
  [19746] = {"Aura de concentración", "Concentration Aura"},
  [19750] = {"Destello de Luz", "Flash of Light"},
  [19752] = {"Intervención divina", "Divine Intervention"},
  [19876] = {"Aura de resistencia a las Sombras", "Shadow Resistance Aura"},
  [19888] = {"Aura de resistencia a la Escarcha", "Frost Resistance Aura"},
  [19891] = {"Aura de resistencia al Fuego", "Fire Resistance Aura"},
  [20154] = {"Sello de rectitud", "Seal of Righteousness"},
  [20164] = {"Sello de justicia", "Seal of Justice"},
  [20165] = {"Sello de luz", "Seal of Light"},
  [20166] = {"Sello de sabiduría", "Seal of Wisdom"},
  [20217] = {"Bendición de reyes", "Blessing of Kings"},
  [20271] = {"Sentencia", "Judgement"},
  [20375] = {"Sello de orden", "Seal of Command"},
  [20925] = {"Escudo sagrado", "Holy Shield"},
  [21082] = {"Sello del cruzado", "Seal of the Crusader"},
  [24275] = {"Martillo de cólera", "Hammer of Wrath"},
  [25780] = {"Furia justa", "Righteous Fury"},
  [25782] = {"Bendición de poderío superior", "Greater Blessing of Might"},
  [25894] = {"Bendición de sabiduría superior", "Greater Blessing of Wisdom"},
  [25898] = {"Bendición de reyes superior", "Greater Blessing of Kings"},
  [26573] = {"Consagración", "Consecration"},
  [1310911] = {"Vigilia de la Luz", "Light's Vigil"},
  [1311606] = {"Choque sagrado", "Holy Shock"},
  [1311649] = {"Sello de furia", "Seal of Fury"},
  [20216] = {"Favor divino", "Divine Favor"},
  [1328548] = {"Juramento de Luz", "Oath of Light"},
  [1311015] = {"Baluarte de templario", "Templar's Bulwark"},
  [1310994] = {"Juicio presto", "Swift Judgement"},
  [20066] = {"Arrepentimiento", "Repentance"},
}
local talentosPaladinPorId = {}
for _, e in ipairs(talentosPaladin) do talentosPaladinPorId[e.id] = e end

-- Cazador: habilidades activas de talento, no comprables como primer rango.
-- Contraste: TalentsForever (70755), Questing.wiki, ForeverDiff y RaidDex.
-- El nivel indicado es el mínimo de la fila, no una garantía de aprendizaje.
local talentosCazador = {
  { id=1293241,n=25,rama="Bestias",en="Summon Hawk",es="Invocar halcón" },
  { id=19577,n=30,rama="Bestias",en="Intimidation",es="Intimidación" },
  { id=19574,n=40,rama="Bestias",en="Bestial Wrath",es="Cólera de las bestias" },
  { id=1299346,n=25,rama="Puntería",en="Trueshot Aura",es="Aura de disparo certero" },
  { id=19503,n=30,rama="Puntería",en="Scatter Shot",es="Disparo de dispersión" },
  { id=1310687,n=40,rama="Puntería",en="Sniper Shot",es="Disparo de francotirador" },
  { id=19263,n=20,rama="Supervivencia",en="Deterrence",es="Disuasión" },
  { id=19306,n=25,rama="Supervivencia",en="Counterattack",es="Contraataque" },
  { id=1317257,n=30,rama="Supervivencia",en="Strider Kick",es="Patada de zancudo" },
}
-- Familias de los manuales y facultades sin precio de instructor acreditado.
-- Etiquetas de guía bilingües; nombres nativos preferidos si coincide el idioma.
local nombresRangosCazador = {
  [1494] = {"Rastrear bestias", "Track Beasts"},
  [2973] = {"Golpe de raptor", "Raptor Strike"},
  [1978] = {"Picadura de serpiente", "Serpent Sting"},
  [13163] = {"Aspecto del mono", "Aspect of the Monkey"},
  [1130] = {"Marca del cazador", "Hunter's Mark"},
  [3044] = {"Disparo Arcano", "Arcane Shot"},
  [3127] = {"Parada", "Parry"},
  [5116] = {"Disparo de conmoción", "Concussive Shot"},
  [883] = {"Llamar a mascota", "Call Pet"},
  [982] = {"Revivir mascota", "Revive Pet"},
  [1515] = {"Domesticar bestia", "Tame Beast"},
  [2641] = {"Retirar mascota", "Dismiss Pet"},
  [4187] = {"Gran aguante", "Great Stamina"},
  [5149] = {"Entrenar bestia", "Beast Training"},
  [6991] = {"Alimentar mascota", "Feed Pet"},
  [13165] = {"Aspecto del halcón", "Aspect of the Hawk"},
  [19883] = {"Rastrear humanoides", "Track Humanoids"},
  [24545] = {"Armadura natural", "Natural Armor"},
  [136] = {"Aliviar mascota", "Mend Pet"},
  [2974] = {"Cortar alas", "Wing Clip"},
  [20736] = {"Disparo de distracción", "Distracting Shot"},
  [1002] = {"Ojos de la bestia", "Eyes of the Beast"},
  [1513] = {"Asustar bestia", "Scare Beast"},
  [6197] = {"Ojo de águila", "Eagle Eye"},
  [1495] = {"Mordedura de mangosta", "Mongoose Bite"},
  [13795] = {"Trampa de inmolación", "Immolation Trap"},
  [2643] = {"Disparo múltiple", "Multi-Shot"},
  [19884] = {"Rastrear no-muertos", "Track Undead"},
  [674] = {"Doble empuñadura", "Dual Wield"},
  [781] = {"Separación", "Disengage"},
  [1499] = {"Trampa congelante", "Freezing Trap"},
  [5118] = {"Aspecto del guepardo", "Aspect of the Cheetah"},
  [14917] = {"Gruñido", "Growl"},
  [19263] = {"Disuasión", "Deterrence"},
  [19434] = {"Disparo apuntado", "Aimed Shot"},
  [23992] = {"Resistencia al Fuego", "Fire Resistance"},
  [24446] = {"Resistencia a la Escarcha", "Frost Resistance"},
  [24488] = {"Resistencia a las Sombras", "Shadow Resistance"},
  [24492] = {"Resistencia a la Naturaleza", "Nature Resistance"},
  [24493] = {"Resistencia Arcana", "Arcane Resistance"},
  [3043] = {"Picadura de escórpido", "Scorpid Sting"},
  [1462] = {"Conocimiento de bestias", "Beast Lore"},
  [19885] = {"Rastrear ocultos", "Track Hidden"},
  [19306] = {"Contraataque", "Counterattack"},
  [1293241] = {"Invocar halcón", "Summon Hawk"},
  [1299346] = {"Aura de disparo certero", "Trueshot Aura"},
  [3045] = {"Fuego rápido", "Rapid Fire"},
  [19880] = {"Rastrear elementales", "Track Elementals"},
  [13809] = {"Trampa de Escarcha", "Frost Trap"},
  [5384] = {"Fingir muerte", "Feign Death"},
  [13161] = {"Aspecto de la bestia", "Aspect of the Beast"},
  [19503] = {"Disparo de dispersión", "Scatter Shot"},
  [19577] = {"Intimidación", "Intimidation"},
  [24118] = {"Lacerar", "Lacerate"},
  [1317257] = {"Patada de zancudo", "Strider Kick"},
  [1543] = {"Bengala", "Flare"},
  [19878] = {"Rastrear demonios", "Track Demons"},
  [13813] = {"Trampa explosiva", "Explosive Trap"},
  [3034] = {"Picadura de víbora", "Viper Sting"},
  [1510] = {"Salva", "Volley"},
  [8737] = {"Malla", "Mail"},
  [13159] = {"Aspecto de la manada", "Aspect of the Pack"},
  [19574] = {"Cólera de las bestias", "Bestial Wrath"},
  [19882] = {"Rastrear gigantes", "Track Giants"},
  [1310687] = {"Disparo de francotirador", "Sniper Shot"},
  [20043] = {"Aspecto de lo salvaje", "Aspect of the Wild"},
  [19879] = {"Rastrear dragonantes", "Track Dragonkin"},
  [19801] = {"Disparo tranquilizante", "Tranquilizing Shot"},
}
local talentosCazadorPorId = {}
for _, e in ipairs(talentosCazador) do talentosCazadorPorId[e.id] = e end

-- Pícaro B03: facultades activas de talento (TalentsForever 70755; ForeverDiff 70938).
-- Etiquetas ES de guía, prevalece el cliente en su idioma. Los niveles son mínimos de árbol.
local talentosPicaro = {
  { id=14177,n=25,rama="Asesinato",en="Cold Blood",es="Sangre fría" },
  { id=1310706,n=40,rama="Asesinato",en="Mutilate",es="Mutilar" },
  { id=14251,n=20,rama="Combate",en="Riposte",es="Respuesta" },
  { id=13877,n=30,rama="Combate",en="Blade Flurry",es="Aluvión de acero" },
  { id=13750,n=40,rama="Combate",en="Adrenaline Rush",es="Subidón de adrenalina" },
  { id=14183,n=20,rama="Sutileza",en="Premeditation",es="Premeditación" },
  { id=14278,n=25,rama="Sutileza",en="Ghostly Strike",es="Golpe fantasmal" },
  { id=14185,n=30,rama="Sutileza",en="Preparation",es="Preparación" },
  { id=16511,n=30,rama="Sutileza",en="Hemorrhage",es="Hemorragia" },
  { id=1316709,n=40,rama="Sutileza",en="Death Mark",es="Marca de muerte" },
}
local talentosPicaroPorId = {}
for _, e in ipairs(talentosPicaro) do talentosPicaroPorId[e.id] = e end
-- B07: cinco recetas heredadas presentes en los datos de Forever, sin oferta observada.
-- IDs de fabricación (Create Item), no los IDs de aplicación ni de efecto.
local venenosPicaroPendientes = {
  {id=458822,n=54,ant=0}, {id=1214168,n=60,ant=458822},
  {id=439503,n=60,ant=0}, {id=439505,n=60,ant=0}, {id=439500,n=60,ant=0},
}
local nombresPicaroInicial = {
  [1752] = {"Golpe siniestro", "Sinister Strike"},
  [1784] = {"Sigilo", "Stealth"},
  [1776] = {"Gubia", "Gouge"},
  [5277] = {"Evasión", "Evasion"},
  [674] = {"Doble empuñadura", "Dual Wield"},
  [2983] = {"Sprint", "Sprint"},
  [5171] = {"Hacer picadillo", "Slice and Dice"},
  [6770] = {"Porrazo", "Sap"},
  [1766] = {"Patada", "Kick"},
  [3127] = {"Parada", "Parry"},
  [703] = {"Garrote", "Garrote"},
  [8647] = {"Exponer armadura", "Expose Armor"},
  [8676] = {"Emboscada", "Ambush"},
  [1943] = {"Ruptura", "Rupture"},
  [1725] = {"Distraer", "Distract"},
  [1856] = {"Esfumarse", "Vanish"},
  [2836] = {"Detectar trampas", "Detect Traps"},
  [1833] = {"Golpe bajo", "Cheap Shot"},
  [408] = {"Golpe en los riñones", "Kidney Shot"},
  [1842] = {"Desactivar trampa", "Disarm Trap"},
  [2094] = {"Ceguera", "Blind"},
  [1860] = {"Caída segura", "Safe Fall"},
  [438040] = {"Redirigir", "Redirect"},
  [1293712] = {"Competencia con armaduras", "Armor Proficiency"},

  [6510] = {"Polvo cegador", "Blinding Powder"},
  [458822] = {"Veneno oculto", "Occult Poison"},
  [439503] = {"Veneno atrófico", "Atrophic Poison"},
  [439505] = {"Veneno adormecedor", "Numbing Poison"},
  [439500] = {"Veneno sebáceo", "Sebacious Poison"},
  [1804] = {"Forzar cerradura", "Pick Lock"},
  [2842] = {"Venenos", "Poisons"},
  [921] = {"Robar", "Pick Pocket"},
  [53] = {"Puñalada", "Backstab"},
  [1966] = {"Amago", "Feint"},
  [2098] = {"Eviscerar", "Eviscerate"},
  [2835] = {"Veneno mortal", "Deadly Poison"},
  [3420] = {"Veneno incapacitante", "Crippling Poison"},
  [5763] = {"Veneno entorpecedor", "Mind-numbing Poison"},
  [8681] = {"Veneno instantáneo", "Instant Poison"},
  [13220] = {"Veneno hiriente", "Wound Poison"},
  [1328825] = {"Compostura inicial", "Poised"},
  [1329283] = {"Puyalada", "Shank"},
}
-- Resúmenes de guía; no sustituyen el tooltip nativo.
local descripcionPicaroInicial = {
  [1752] = {"Ataque directo con el arma principal que genera un punto de combo.", "Direct main-hand attack that builds a combo point."},
  [1784] = {"Permite ocultarte de los enemigos y usar aperturas de sigilo.", "Conceals you from enemies and enables stealth openers."},
  [1776] = {"Incapacita brevemente a un enemigo; el daño puede romper el efecto.", "Briefly incapacitates an enemy; damage may break the effect."},
  [5277] = {"Aumenta temporalmente tu probabilidad de esquivar.", "Temporarily raises your dodge chance."},
  [674] = {"Permite equipar un arma válida en cada mano desde nivel 10.", "Enables an eligible weapon in each hand from level 10."},
  [2983] = {"Aumenta temporalmente la velocidad de movimiento.", "Temporarily boosts movement speed."},
  [5171] = {"Remate que aumenta la velocidad de ataque cuerpo a cuerpo según los puntos de combo.", "Finisher increasing melee attack speed based on combo points."},
  [6770] = {"Incapacita a un objetivo válido fuera de combate mediante sigilo.", "Incapacitates an eligible out-of-combat target from Stealth."},
  [1766] = {"Interrumpe el lanzamiento de un hechizo enemigo.", "Interrupts an enemy spellcast."},
  [3127] = {"Permite parar ataques cuerpo a cuerpo.", "Enables melee parries."},
  [703] = {"Apertura de sigilo que aplica sangrado y genera un punto de combo.", "Stealth opener that applies a bleed and builds a combo point."},
  [8647] = {"Remate que reduce la armadura del enemigo.", "Finisher that reduces enemy armor."},
  [8676] = {"Apertura de sigilo con daga en la mano principal que causa daño elevado.", "Stealth opener using a main-hand dagger for high damage."},
  [1943] = {"Remate que inflige sangrado según los puntos de combo.", "Finisher dealing bleed damage based on combo points."},
  [1725] = {"Hace que enemigos cercanos miren hacia el punto elegido.", "Makes nearby enemies face the selected location."},
  [1856] = {"Intenta salir de combate y entrar en sigilo.", "Attempts to leave combat and enter Stealth."},
  [2836] = {"Facilita detectar trampas cercanas.", "Helps detect nearby traps."},
  [1833] = {"Apertura de sigilo que aturde y genera puntos de combo.", "Stealth opener that stuns and builds combo points."},
  [408] = {"Remate que aturde según los puntos de combo gastados.", "Finisher that stuns based on combo points spent."},
  [1842] = {"Desactiva una trampa compatible.", "Disarms an eligible trap."},
  [2094] = {"Desorienta a un enemigo; el daño puede romper el efecto.", "Disorients an enemy; damage may break the effect."},
  [1860] = {"Reduce el daño recibido por caídas.", "Reduces falling damage."},
  [438040] = {"Almacena los puntos de combo para transferirlos al siguiente enemigo no jugador alcanzado; obtención pendiente de verificar.", "Stores combo points for transfer to the next non-player enemy struck; acquisition unconfirmed."},
  [1293712] = {"Permite consultar los tipos de armadura utilizables: tela y cuero.", "Lists wearable armor types: cloth and leather."},

  [6510] = {"Fabrica el componente de Ceguera a partir de Pálida. Consulta los requisitos reales de fabricación.", "Crafts the reagent for Blind from Fadeleaf. Check actual crafting requirements."},
  [458822] = {"Referencia de cliente: daño de Naturaleza periódico y vulnerabilidad a daño mágico. Cuenta como veneno mortal; oferta sin acreditar.", "Client reference: periodic Nature damage and vulnerability to magic damage. Counts as Deadly Poison; availability unconfirmed."},
  [439503] = {"Referencia de cliente: reduce el poder de ataque cuerpo a cuerpo del enemigo.", "Client reference: reduces the enemy's melee attack power."},
  [439505] = {"Referencia de cliente: ralentiza los ataques cuerpo a cuerpo del enemigo.", "Client reference: slows the enemy's melee attacks."},
  [439500] = {"Referencia de cliente: reduce la armadura del enemigo.", "Client reference: reduces the enemy's armor."},
  [1804] = {"Abre cerraduras si tienes herramientas y habilidad suficiente; se aprende con el instructor al 16.", "Opens locks with sufficient skill and Thieves' Tools; train at level 16."},
  [2842] = {"Permite fabricar venenos tras completar la cadena de tu facción.", "Allows crafting poisons after completing your faction quest chain."},
  [921] = {"Roba objetos a objetivos válidos mientras estás en sigilo.", "Pickpockets eligible targets while stealthed."},
  [53] = {"Ataque con daga desde detrás del objetivo que genera un punto de combo.", "Dagger attack from behind the target that generates a combo point."},
  [1966] = {"Reduce la amenaza sin infligir daño.", "Reduces threat without dealing damage."},
  [2098] = {"Remate que inflige daño según los puntos de combo.", "Finisher dealing damage based on combo points."},
  [2835] = {"Veneno que inflige daño periódico acumulable.", "Poison dealing stacking periodic damage."},
  [3420] = {"Veneno que reduce la velocidad de movimiento del enemigo.", "Poison that reduces enemy movement speed."},
  [5763] = {"Veneno que ralentiza el lanzamiento de hechizos del enemigo.", "Poison that slows enemy spellcasting."},
  [8681] = {"Veneno que inflige daño de Naturaleza al activarse.", "Poison that deals Nature damage on proc."},
  [13220] = {"Veneno que reduce la sanación recibida por el enemigo.", "Poison that reduces healing received by the enemy."},
  [14177] = {"Asegura un crítico del siguiente ataque compatible.", "Guarantees a critical strike with the next eligible attack."},
  [1310706] = {"Ataque con dos dagas; genera puntos de combo y se beneficia de venenos.", "Dual-dagger attack; generates combo points and benefits from poisons."},
  [14251] = {"Contraataque tras parar un golpe enemigo.", "Counterattack after parrying an enemy attack."},
  [13877] = {"Aumenta la velocidad de ataque y permite alcanzar a otro enemigo cercano.", "Increases attack speed and lets attacks hit an additional nearby enemy."},
  [13750] = {"Acelera temporalmente la regeneración de energía.", "Temporarily accelerates Energy regeneration."},
  [14183] = {"Añade puntos de combo al objetivo antes de una apertura.", "Adds combo points to the target before an opener."},
  [14278] = {"Ataque que refuerza la esquiva y facilita una apertura sin sigilo.", "Attack that boosts dodge and enables an opener without Stealth."},
  [14185] = {"Reinicia los tiempos de reutilización de habilidades compatibles.", "Resets eligible ability cooldowns."},
  [16511] = {"Ataque que potencia tus sangrados de Garrote y Ruptura en el objetivo.", "Attack that amplifies your Garrote and Rupture bleeds on the target."},
  [1316709] = {"Remate que almacena parte del daño infligido y lo descarga después.", "Finisher that stores some damage dealt and releases it later."},
  [1328825] = {"Pasiva: fuera de combate y con energía llena, abarata tu siguiente habilidad de energía.", "Passive: out of combat at full Energy, reduces the cost of your next Energy ability."},
  [1329283] = {"Ataque de mano secundaria que genera energía; no falla.", "Off-hand attack that generates Energy and cannot miss."},
}

-- Sacerdote B03: nueve facultades activas de talento; árbol 18/11 y spellbook Forever.
-- Los rangos superiores siguen siendo del instructor y requieren el rango anterior.
-- Spirit of Redemption, Holy Binding y Soul Warding son pasivos, no compras.
-- Binding Heal fue retirado; no añadir las seis entradas antiguas del cliente beta.
local talentosSacerdote = {
  {id=14751,n=20,rama="Disciplina",en="Inner Focus",es="Enfoque interno"},
  {id=402174,n=30,rama="Disciplina",en="Penance",es="Penitencia"},
  {id=10060,n=40,rama="Disciplina",en="Power Infusion",es="Infusión de poder"},
  {id=15237,n=20,rama="Sagrado",en="Holy Nova",es="Nova sagrada"},
  {id=401859,n=40,rama="Sagrado",en="Prayer of Mending",es="Rezo de alivio"},
  {id=15407,n=20,rama="Sombra",en="Mind Flay",es="Tortura mental"},
  {id=15286,n=25,rama="Sombra",en="Vampiric Embrace",es="Abrazo vampírico"},
  {id=15487,n=30,rama="Sombra",en="Silence",es="Silencio"},
  {id=15473,n=40,rama="Sombra",en="Shadowform",es="Forma de las Sombras"},
}
local talentosSacerdotePorId = {}
for _,e in ipairs(talentosSacerdote) do talentosSacerdotePorId[e.id]=e end
local descripcionSacerdote = {
  [1293712]={"Permite consultar la competencia de armadura: tela.","Lists armor proficiency: cloth."},
  [5009]={"Permite equipar varitas desde el nivel 1.","Allows equipping wands from level 1."},
  [5019]={"Ataca a distancia con una varita equipada; no gasta maná.","Attacks at range with an equipped wand; costs no Mana."},
  [1277370]={"Cura de emergencia a otro aliado con poca salud y elimina Alma debilitada.","Emergency heal for another low-health ally; removes Weakened Soul."},
  [13896]={"Quema maná y causa daño de Sombras a lanzadores que te alcanzan con hechizos compatibles.","Burns Mana and deals Shadow damage to casters who hit you with eligible spells."},
  [13908]={"Cura instantánea personal de emergencia.","Instant emergency self-heal."},
  [1277331]={"Inflige daño Sagrado e inmoviliza brevemente a un humanoide.","Deals Holy damage and briefly immobilizes a humanoid."},
  [10797]={"Inflige daño Arcano durante su canalización.","Deals Arcane damage while channeling."},
  [2651]={"Reduce temporalmente la probabilidad de recibir ataques físicos cuerpo a cuerpo y a distancia.","Temporarily reduces the chance of being hit by melee and ranged attacks."},
  [1277455]={"Confunde brevemente a varios enemigos cercanos; el daño rompe el efecto.","Briefly confuses nearby enemies; damage breaks the effect."},
  [1277462]={"Protección sobre un aliado: al caer por debajo del umbral de salud, activa un escudo y curación.","Ward on an ally: falling below the health threshold triggers a shield and healing."},
  [2652]={"El siguiente atacante cuerpo a cuerpo recibe daño de Sombras y queda debilitado.","The next melee attacker takes Shadow damage and is weakened."},
  [1277324]={"Convierte salud propia en maná con el tiempo; el Espíritu contribuye a la recuperación.","Converts your own Health into Mana over time; Spirit contributes to the recovery."},
  [9035]={"Debilita el daño del enemigo y reduce la sanación recibida.","Weakens enemy damage and reduces healing received."},
  [18137]={"Cargas de sombras que dañan a atacantes al activarse.","Shadow charges damage attackers when triggered."},

  [17]={"Absorbe daño y protege al aliado de interrupciones por daño durante su efecto.","Absorbs damage and protects the ally from damage-induced spell pushback while active."},
  [139]={"Sana al objetivo periódicamente durante su duración.","Heals the target periodically over its duration."},
  [453]={"Reduce el alcance al que un humanoide válido detecta al sacerdote.","Reduces the detection radius of an eligible humanoid."},
  [527]={"Disipa efectos mágicos compatibles de aliados o enemigos.","Dispels eligible magic effects from allies or enemies."},
  [528]={"Elimina una enfermedad del aliado.","Removes one disease from an ally."},
  [552]={"Intenta eliminar enfermedades al lanzarse y periódicamente después.","Attempts to remove diseases on cast and periodically afterward."},
  [585]={"Inflige daño Sagrado directo al enemigo.","Deals direct Holy damage to an enemy."},
  [586]={"Reduce temporalmente la amenaza del sacerdote.","Temporarily reduces the priest's threat."},
  [588]={"Aumenta la armadura mientras queden cargas del efecto.","Increases armor while charges of the effect remain."},
  [589]={"Inflige daño periódico de Sombras.","Deals periodic Shadow damage."},
  [596]={"Sana al objetivo y a los miembros de su grupo cercanos.","Heals the target and nearby members of their party."},
  [605]={"Canaliza el control de un humanoide válido.","Channels control over an eligible humanoid."},
  [976]={"Aumenta la resistencia del objetivo a las Sombras.","Increases the target's Shadow resistance."},
  [1243]={"Aumenta el aguante del aliado.","Increases an ally's Stamina."},
  [1706]={"Permite flotar y caer lentamente; consulta los requisitos del cliente.","Allows floating and slow falling; check client requirements."},
  [2006]={"Devuelve a la vida a un aliado fuera de combate.","Brings an ally back to life out of combat."},
  [2050]={"Sanación directa básica de un aliado.","Basic direct single-target healing."},
  [2054]={"Sanación directa de un aliado, con tiempo de lanzamiento.","Direct single-target heal with a cast time."},
  [2060]={"Sanación directa de gran potencia con lanzamiento lento.","Powerful direct heal with a long cast time."},
  [2061]={"Sanación directa rápida de un aliado.","Fast direct single-target heal."},
  [2096]={"Permite ver temporalmente a través de los ojos del objetivo.","Temporarily sees through the target's eyes."},
  [2944]={"Inflige daño periódico de Sombras y sana al sacerdote. Disponible para todas las razas al 20.","Deals periodic Shadow damage and heals the priest. Available to all races at 20."},
  [6346]={"Protege contra el siguiente miedo compatible. Disponible para todas las razas al 20.","Protects against the next eligible Fear. Available to all races at 20."},
  [8092]={"Inflige daño directo de Sombras.","Deals direct Shadow damage."},
  [8122]={"Hace huir por miedo a enemigos cercanos compatibles.","Causes eligible nearby enemies to flee in fear."},
  [8129]={"Drena maná del enemigo e inflige daño en función del maná quemado.","Drains enemy Mana and deals damage based on the amount burned."},
  [9484]={"Incapacita a un no-muerto válido; el daño rompe el efecto.","Incapacitates an eligible Undead; damage breaks the effect."},
  [14914]={"Inflige daño Sagrado directo y periódico.","Deals direct and periodic Holy damage."},
  [21562]={"Aumenta el aguante de los miembros de grupo y banda. Requiere el componente del libro de hechizos.","Increases party and raid Stamina. Requires the spellbook reagent."},
  [27683]={"Aumenta la resistencia a las Sombras de grupo y banda. Requiere el componente del libro de hechizos.","Increases party and raid Shadow resistance. Requires the spellbook reagent."},
  [14751]={"El siguiente hechizo compatible no cuesta maná y puede obtener mayor probabilidad de crítico.", "The next eligible spell costs no Mana and may gain increased critical chance."},
  [402174]={"Canaliza descargas sagradas que sanan a un aliado o dañan a un enemigo.", "Channels holy bolts to heal an ally or damage an enemy."},
  [10060]={"Aumenta temporalmente el daño mágico y la sanación del objetivo.", "Temporarily increases the target's spell damage and healing."},
  [15237]={"Explosión sagrada alrededor del sacerdote que daña enemigos y sana miembros cercanos del grupo.", "Holy burst around the priest that damages enemies and heals nearby party members."},
  [401859]={"Sanación reactiva al recibir daño o una cura directa compatible; puede saltar a otros aliados.", "Reactive heal triggered by damage or eligible direct healing; can bounce to other allies."},
  [15407]={"Canaliza daño de Sombras y ralentiza al objetivo.", "Channels Shadow damage and slows the target."},
  [15286]={"Parte de tu daño de Sombras se convierte en sanación del grupo.", "Some of your Shadow damage is converted into party healing."},
  [15487]={"Interrumpe y silencia al objetivo temporalmente.", "Interrupts and temporarily silences the target."},
  [15473]={"Refuerza el daño de Sombras y su eficiencia de maná y reduce daño físico recibido. Impide lanzar sanaciones.", "Boosts Shadow damage and Mana efficiency and reduces physical damage taken. Prevents healing casts."},
  [1309595]={"Ataque instantáneo de Sombras; si el objetivo sobrevive, causa daño al sacerdote. No causa ese daño si falla.", "Instant Shadow attack; damages the priest if the target survives. Does not cause that backlash on a miss."},
  [14752]={"Aumenta el espíritu de un aliado. Es una facultad básica del instructor, no un talento.", "Increases an ally's Spirit. A baseline trainer ability, not a talent."},
  [27681]={"Aumenta el espíritu del grupo del objetivo; requiere el componente indicado en el libro de hechizos.", "Increases Spirit for the target's group; requires the reagent shown in the spellbook."},
}
local nombresSacerdoteInicial = {
  [5009]={"Varitas","Wands"}, [5019]={"Disparar","Shoot"},
  [1277370]={"Gracia divina","Divine Grace"},
  [13896]={"Reacción","Feedback"},
  [13908]={"Oración desesperada","Desperate Prayer"},
  [1277331]={"Castigo","Chastise"},
  [10797]={"Fragmentos estelares","Starshards"},
  [2651]={"Gracia de Elune","Elune's Grace"},
  [1277455]={"Destello desconcertante","Confounding Flash"},
  [1277462]={"Plan de contingencia","Contingency Plan"},
  [2652]={"Toque de debilidad","Touch of Weakness"},
  [1277324]={"Sacrificio oscuro","Dark Sacrifice"},
  [9035]={"Maleficio de debilidad","Hex of Weakness"},
  [18137]={"Guardia de las Sombras","Shadowguard"},

  [17]={"Palabra de poder: escudo","Power Word: Shield"},
  [139]={"Renovar","Renew"},
  [453]={"Calmar mente","Mind Soothe"},
  [527]={"Disipar magia","Dispel Magic"},
  [528]={"Curar enfermedad","Cure Disease"},
  [552]={"Suprimir enfermedad","Abolish Disease"},
  [585]={"Punición","Smite"},
  [586]={"Desvanecerse","Fade"},
  [588]={"Fuego interno","Inner Fire"},
  [589]={"Palabra de las Sombras: dolor","Shadow Word: Pain"},
  [596]={"Rezo de sanación","Prayer of Healing"},
  [605]={"Control mental","Mind Control"},
  [976]={"Protección contra las Sombras","Shadow Protection"},
  [1243]={"Palabra de poder: entereza","Power Word: Fortitude"},
  [1706]={"Levitar","Levitate"},
  [2006]={"Resurrección","Resurrection"},
  [2050]={"Sanación inferior","Lesser Heal"},
  [2054]={"Sanar","Heal"},
  [2060]={"Sanación superior","Greater Heal"},
  [2061]={"Sanación relámpago","Flash Heal"},
  [2096]={"Visión mental","Mind Vision"},
  [2944]={"Peste devoradora","Devouring Plague"},
  [6346]={"Resguardo de miedo","Fear Ward"},
  [8092]={"Explosión mental","Mind Blast"},
  [8122]={"Alarido psíquico","Psychic Scream"},
  [8129]={"Quemadura de maná","Mana Burn"},
  [9484]={"Encadenar no-muerto","Shackle Undead"},
  [14914]={"Fuego sagrado","Holy Fire"},
  [21562]={"Rezo de entereza","Prayer of Fortitude"},
  [27683]={"Rezo de protección contra las Sombras","Prayer of Shadow Protection"},
  [1309595]={"Palabra de las Sombras: muerte", "Shadow Word: Death"},
  [14752]={"Espíritu divino", "Divine Spirit"},
  [27681]={"Rezo de espíritu", "Prayer of Spirit"},
}

-- Chamán B03: facultades concedidas por talentos; árboles Forever 70755/71091.
-- Lightning Mastery modifica relámpagos, no recomendar su lanzamiento como Elemental Mastery de Classic.
local talentosChaman = {
  {id=16166,n=40,rama="Elemental",en="Lightning Mastery",es="Maestría con relámpagos"},
  {id=17364,n=25,rama="Mejora",en="Stormstrike",es="Golpe de tormenta"},
  {id=425336,n=40,rama="Mejora",en="Rage of the Farseer",es="Ira del clarividente"},
  {id=408510,n=20,rama="Restauración",en="Water Shield",es="Escudo de agua"},
  {id=16190,n=25,rama="Restauración",en="Mana Tide Totem",es="Tótem Marea de maná"},
  {id=16188,n=30,rama="Restauración",en="Nature's Swiftness",es="Presteza de la naturaleza"},
  {id=408521,n=40,rama="Restauración",en="Riptide",es="Mareas vivas"},
}
local talentosChamanPorId={}
for _,e in ipairs(talentosChaman) do talentosChamanPorId[e.id]=e end
-- B04: nombres de guía ES/EN, resúmenes propios de las familias comunes.
local nombresChaman = {
  [674]={"Doble empuñadura","Dual Wield"},
  [131]={"Respiración acuática","Water Breathing"},
  [324]={"Escudo de relámpagos","Lightning Shield"},
  [331]={"Ola de sanación","Healing Wave"},
  [370]={"Purgar","Purge"},
  [403]={"Descarga de relámpagos","Lightning Bolt"},
  [421]={"Cadena de relámpagos","Chain Lightning"},
  [526]={"Curar envenenamiento","Cure Poison"},
  [546]={"Caminar sobre el agua","Water Walking"},
  [556]={"Regreso astral","Astral Recall"},
  [1064]={"Sanación en cadena","Chain Heal"},
  [2008]={"Espíritu ancestral","Ancestral Spirit"},
  [2484]={"Tótem Nexo terrestre","Earthbind Totem"},
  [2645]={"Lobo fantasmal","Ghost Wolf"},
  [2870]={"Curar enfermedad","Cure Disease"},
  [3599]={"Tótem abrasador","Searing Totem"},
  [5394]={"Tótem Corriente de sanación","Healing Stream Totem"},
  [5675]={"Tótem Fuente de maná","Mana Spring Totem"},
  [5730]={"Tótem Garra de piedra","Stoneclaw Totem"},
  [6196]={"Visión lejana","Far Sight"},
  [6495]={"Tótem avizor","Sentry Totem"},
  [8004]={"Ola de sanación inferior","Lesser Healing Wave"},
  [8017]={"Arma Muerdepiedras","Rockbiter Weapon"},
  [8024]={"Arma Lengua de Fuego","Flametongue Weapon"},
  [8033]={"Arma Estigma de Escarcha","Frostbrand Weapon"},
  [8042]={"Choque de tierra","Earth Shock"},
  [8050]={"Choque de llamas","Flame Shock"},
  [8056]={"Choque de Escarcha","Frost Shock"},
  [8071]={"Tótem Piel de piedra","Stoneskin Totem"},
  [8075]={"Tótem Fuerza de la Tierra","Strength of Earth Totem"},
  [8143]={"Tótem de tremor","Tremor Totem"},
  [8166]={"Tótem de limpieza de veneno","Poison Cleansing Totem"},
  [8170]={"Tótem de limpieza de enfermedad","Disease Cleansing Totem"},
  [8177]={"Tótem derribador","Grounding Totem"},
  [8181]={"Tótem de resistencia a la Escarcha","Frost Resistance Totem"},
  [8184]={"Tótem de resistencia al Fuego","Fire Resistance Totem"},
  [8190]={"Tótem de magma","Magma Totem"},
  [8227]={"Tótem Lengua de Fuego","Flametongue Totem"},
  [8232]={"Arma Viento Furioso","Windfury Weapon"},
  [8512]={"Tótem Viento Furioso","Windfury Totem"},
  [8737]={"Malla","Mail"},
  [8835]={"Tótem Gracia del Aire","Grace of Air Totem"},
  [10595]={"Tótem de resistencia a la Naturaleza","Nature Resistance Totem"},
  [15107]={"Tótem Muro de viento","Windwall Totem"},
  [20608]={"Reencarnación","Reincarnation"},
  [36936]={"Retirada totémica","Totemic Recall"},
  [66842]={"Llamada de los elementos","Call of the Elements"},
  [66843]={"Llamada de los ancestros","Call of the Ancestors"},
  [66844]={"Llamada de los espíritus","Call of the Spirits"},
  [408341]={"Nova de Fuego","Fire Nova"},
  [437009]={"Llamada totémica","Totemic Call"},
}
local descripcionChaman={
  [1293712]={"Permite consultar los tipos de armadura: tela, cuero, escudo y malla desde el 40.","Lists armor proficiencies: cloth, leather, shield and mail from level 40."},
  [674]={"Referencia de cliente: doble empuñadura. No hay un método de aprendizaje acreditado; no forma parte del plan de Mejora.","Client reference: dual wield. No confirmed learning method; not part of the Enhancement plan."},
  [131]={"Permite respirar bajo el agua; requiere reactivo salvo excepciones.","Allows underwater breathing; requires a reagent unless exempt."},
  [324]={"Orbes que infligen daño de Naturaleza al activarse.","Orbs deal Nature damage when triggered."},
  [331]={"Sanación directa de lanzamiento normal.","Direct heal with a normal cast time."},
  [370]={"Elimina efectos mágicos beneficiosos de un enemigo.","Removes beneficial Magic effects from an enemy."},
  [403]={"Ataque a distancia de Naturaleza.","Ranged Nature attack."},
  [421]={"Daño de Naturaleza que salta entre enemigos.","Nature damage that jumps between enemies."},
  [526]={"Elimina un efecto de veneno de un aliado.","Removes a poison effect from an ally."},
  [546]={"Permite caminar sobre el agua; requiere reactivo salvo excepciones.","Allows walking on water; requires a reagent unless exempt."},
  [556]={"Regresa a la ubicación de hogar vinculada.","Returns to the bound home location."},
  [1064]={"Sanación que salta a aliados cercanos.","Healing that jumps to nearby allies."},
  [2008]={"Resucita a un aliado fuera de combate.","Resurrects an ally out of combat."},
  [2484]={"Ralentiza a enemigos cercanos.","Slows nearby enemies."},
  [2645]={"Forma de viaje que aumenta la velocidad al aire libre.","Travel form that increases outdoor movement speed."},
  [2870]={"Elimina una enfermedad de un aliado.","Removes a disease from an ally."},
  [3599]={"Ataca periódicamente a un enemigo cercano.","Periodically attacks a nearby enemy."},
  [5394]={"Restaura salud periódicamente a aliados del grupo.","Periodically restores health to party members."},
  [5675]={"Restaura maná periódicamente.","Periodically restores Mana."},
  [5730]={"Atrae la atención de enemigos cercanos; no convierte al chamán en tanque.","Draws nearby enemies' attention; does not make the shaman a tank."},
  [6196]={"Permite observar una ubicación distante.","Allows viewing a distant location."},
  [6495]={"Permite observar el entorno desde el tótem.","Allows viewing the surroundings from the totem."},
  [8004]={"Sanación directa rápida.","Fast direct heal."},
  [8017]={"Imbuye el arma con un efecto de combate cuerpo a cuerpo.","Imbues the weapon with a melee combat effect."},
  [8024]={"Imbuye el arma para infligir daño de Fuego.","Imbues the weapon to deal Fire damage."},
  [8033]={"Imbuye el arma para infligir daño de Escarcha y ralentizar.","Imbues the weapon to deal Frost damage and slow."},
  [8042]={"Daño instantáneo de Naturaleza e interrupción de lanzamiento.","Instant Nature damage and spellcasting interruption."},
  [8050]={"Daño inicial y periódico de Fuego.","Initial and periodic Fire damage."},
  [8056]={"Daño de Escarcha y ralentización.","Frost damage and slowing effect."},
  [8071]={"Reduce el daño físico recibido de ataques compatibles.","Reduces physical damage taken from eligible attacks."},
  [8075]={"Aumenta la fuerza de aliados dentro de su alcance.","Increases Strength of allies within range."},
  [8143]={"Elimina periódicamente efectos de miedo y otros efectos compatibles.","Periodically clears Fear and other eligible effects."},
  [8166]={"Elimina venenos periódicamente.","Periodically removes poisons."},
  [8170]={"Elimina enfermedades periódicamente.","Periodically removes diseases."},
  [8177]={"Redirige un hechizo hostil compatible hacia el tótem.","Redirects an eligible hostile spell to the totem."},
  [8181]={"Aumenta la resistencia a Escarcha.","Increases Frost resistance."},
  [8184]={"Aumenta la resistencia al Fuego.","Increases Fire resistance."},
  [8190]={"Inflige daño de Fuego periódico en área.","Deals periodic area Fire damage."},
  [8227]={"Otorga una mejora de Fuego al grupo; no se acumula con la imbuición propia equivalente.","Grants a party Fire buff; does not stack with the equivalent personal imbue."},
  [8232]={"Imbuye el arma para provocar ataques adicionales.","Imbues the weapon to trigger extra attacks."},
  [8512]={"Mejora los ataques del grupo; no beneficia al chamán con la imbuición equivalente.","Buffs party attacks; does not benefit the shaman using the matching imbue."},
  [8737]={"Permite equipar armaduras de malla al nivel 40.","Allows equipping mail armor at level 40."},
  [8835]={"Aumenta la agilidad de aliados dentro de su alcance.","Increases Agility of allies within range."},
  [10595]={"Aumenta la resistencia a Naturaleza.","Increases Nature resistance."},
  [15107]={"Reduce daño recibido de ataques a distancia compatibles.","Reduces damage from eligible ranged attacks."},
  [20608]={"Permite resucitar al propio chamán cuando está disponible.","Allows self-resurrection when available."},
  [36936]={"Retira los tótems activos y recupera parte del maná.","Recalls active totems and refunds some Mana."},
  [66842]={"Coloca hasta cuatro tótems de la primera configuración.","Places up to four totems from the first preset."},
  [66843]={"Coloca hasta cuatro tótems de otra configuración independiente.","Places up to four totems from another independent preset."},
  [66844]={"Coloca hasta cuatro tótems de una tercera configuración independiente.","Places up to four totems from a third independent preset."},
  [408341]={"Inflige daño de Fuego alrededor del tótem de fuego activo; no invoca otro tótem.","Deals Fire damage around the active Fire totem; does not summon another totem."},
  [437009]={"Traslada los tótems activos a la posición del chamán; cambio de noviembre.","Moves active totems to the shaman's position; November change."},

  [16166]={"Reduce el tiempo de lanzamiento de Descarga de relámpagos y elimina la reutilización de Cadena de relámpagos. No es la antigua Maestría elemental.","Reduces Lightning Bolt cast time and removes Chain Lightning's cooldown. Not the old Elemental Mastery."},
  [17364]={"Golpe con arma que potencia tu siguiente Descarga de relámpagos, Cadena de relámpagos o Choque de tierra sobre ese objetivo.","Weapon strike that empowers your next Lightning Bolt, Chain Lightning or Earth Shock on that target."},
  [425336]={"Aumenta temporalmente la velocidad de ataque.","Temporarily increases attack speed."},
  [408510]={"Orbes de agua que devuelven maná al recibir ataques válidos o lograr críticos de hechizos; incompatible con otros escudos elementales.","Water globes restore Mana on eligible incoming hits or spell criticals; mutually exclusive with other elemental shields."},
  [16190]={"Tótem temporal que restaura maná al grupo cercano; requiere el tótem de agua.","Temporary totem restoring Mana to nearby party members; requires the Water Totem."},
  [16188]={"Hace instantáneo el siguiente hechizo de Naturaleza compatible.","Makes the next eligible Nature spell instant."},
  [408521]={"Sanación periódica que potencia Sanación en cadena lanzada directamente sobre ese aliado; sin cura instantánea inicial tras el cambio de noviembre.","Periodic healing that empowers Chain Heal cast directly on that ally; no initial instant heal after the November change."},
}
-- Mago B03: facultades activas, no efectos pasivos ni runas de SoD.
local talentosMago = {
  {id=400574,n=20,rama="Arcano",en="Arcane Blast",es="Explosión Arcana"},
  {id=1326079,n=25,rama="Arcano",en="Arcane Wrath",es="Cólera Arcana"},
  {id=12043,n=30,rama="Arcano",en="Presence of Mind",es="Presencia mental"},
  {id=12042,n=40,rama="Arcano",en="Arcane Power",es="Poder Arcano"},
  {id=11366,n=20,rama="Fuego",en="Pyroblast",es="Piroexplosión"},
  {id=11113,n=30,rama="Fuego",en="Blast Wave",es="Ola explosiva"},
  {id=11129,n=40,rama="Fuego",en="Combustion",es="Combustión"},
  {id=1312002,n=20,rama="Escarcha",en="Ice Lance",es="Lanza de hielo"},
  {id=11958,n=25,rama="Escarcha",en="Ice Block",es="Bloqueo de hielo"},
  {id=12472,n=30,rama="Escarcha",en="Cold Snap",es="Mordedura helada"},
  {id=11426,n=40,rama="Escarcha",en="Ice Barrier",es="Barrera de hielo"},
}
local talentosMagoPorId={}
for _,e in ipairs(talentosMago) do talentosMagoPorId[e.id]=e end
local nombresMago = {
  [10]={"Ventisca","Blizzard"},
  [116]={"Descarga de Escarcha","Frostbolt"},
  [118]={"Polimorfia","Polymorph"},
  [120]={"Cono de frío","Cone of Cold"},
  [122]={"Nova de Escarcha","Frost Nova"},
  [130]={"Caída lenta","Slow Fall"},
  [133]={"Bola de Fuego","Fireball"},
  [168]={"Armadura de Escarcha","Frost Armor"},
  [475]={"Eliminar maldición inferior","Remove Lesser Curse"},
  [543]={"Resguardo de Fuego","Fire Ward"},
  [587]={"Conjurar comida","Conjure Food"},
  [604]={"Atenuar magia","Dampen Magic"},
  [759]={"Conjurar ágata de maná","Conjure Mana Agate"},
  [1008]={"Amplificar magia","Amplify Magic"},
  [1449]={"Deflagración Arcana","Arcane Explosion"},
  [1459]={"Intelecto Arcano","Arcane Intellect"},
  [1463]={"Escudo de maná","Mana Shield"},
  [1953]={"Traslación","Blink"},
  [2120]={"Fogonazo","Flamestrike"},
  [2136]={"Explosión de Fuego","Fire Blast"},
  [2139]={"Contrahechizo","Counterspell"},
  [2948]={"Agostar","Scorch"},
  [3561]={"Teletransporte: Ventormenta","Teleport: Stormwind"},
  [3562]={"Teletransporte: Forjaz","Teleport: Ironforge"},
  [3565]={"Teletransporte: Darnassus","Teleport: Darnassus"},
  [3563]={"Teletransporte: Entrañas","Teleport: Undercity"},
  [3567]={"Teletransporte: Orgrimmar","Teleport: Orgrimmar"},
  [3566]={"Teletransporte: Cima del Trueno","Teleport: Thunder Bluff"},
  [5143]={"Misiles Arcanos","Arcane Missiles"},
  [5504]={"Conjurar agua","Conjure Water"},
  [6117]={"Armadura de mago","Mage Armor"},
  [6143]={"Resguardo de Escarcha","Frost Ward"},
  [7302]={"Armadura de hielo","Ice Armor"},
  [10059]={"Portal: Ventormenta","Portal: Stormwind"},
  [11416]={"Portal: Forjaz","Portal: Ironforge"},
  [11419]={"Portal: Darnassus","Portal: Darnassus"},
  [11417]={"Portal: Orgrimmar","Portal: Orgrimmar"},
  [11418]={"Portal: Entrañas","Portal: Undercity"},
  [11420]={"Portal: Cima del Trueno","Portal: Thunder Bluff"},
  [12051]={"Evocación","Evocation"},
  [23028]={"Luminosidad Arcana","Arcane Brilliance"},
  [28272]={"Polimorfia: cerdo","Polymorph: Pig"},
  [28271]={"Polimorfia: tortuga","Polymorph: Turtle"},
  [1297659]={"Teletransporte: Dalaran","Teleport: Dalaran"},
  [401502]={"Descarga de Pirofrío","Frostfire Bolt"},
  [1296017]={"Comprender pergamino","Comprehend Scroll"},
  [1302508]={"Estudiar","Study"},
}
local descripcionMago={
  [10]={"Daño de Escarcha en área canalizado.","Channeled area Frost damage."},
  [116]={"Inflige daño de Escarcha y ralentiza al objetivo.","Deals Frost damage and slows the target."},
  [118]={"Incapacita a un objetivo compatible; el daño rompe el efecto.","Incapacitates an eligible target; damage breaks the effect."},
  [120]={"Daño de Escarcha y ralentización en un cono frontal.","Frost damage and slowing effect in a frontal cone."},
  [122]={"Inmoviliza a enemigos cercanos; el daño puede romper el efecto.","Roots nearby enemies; damage may break the effect."},
  [130]={"Reduce la velocidad de caída; requiere el reactivo indicado en el cliente.","Slows falling; requires the reagent specified by the client."},
  [133]={"Proyectil de Fuego con daño periódico adicional.","Fire projectile with additional periodic damage."},
  [168]={"Armadura defensiva que ralentiza a atacantes compatibles.","Defensive armor that slows eligible attackers."},
  [475]={"Elimina una maldición de un aliado válido.","Removes a Curse from an eligible ally."},
  [543]={"Absorbe daño de Fuego.","Absorbs Fire damage."},
  [587]={"Crea alimento temporal para recuperar salud fuera de combate.","Creates temporary food for recovering Health out of combat."},
  [604]={"Reduce daño mágico y sanación recibidos.","Reduces magical damage and healing received."},
  [759]={"Crea una gema temporal que restaura maná.","Creates a temporary Mana-restoring gem."},
  [1008]={"Aumenta daño mágico y sanación recibidos.","Increases magical damage and healing received."},
  [1449]={"Daño Arcano instantáneo alrededor del mago.","Instant Arcane damage around the mage."},
  [1459]={"Aumenta el intelecto de un aliado.","Increases an ally's Intellect."},
  [1463]={"Absorbe daño consumiendo maná.","Absorbs damage by consuming Mana."},
  [1953]={"Desplaza al mago hacia delante si el terreno lo permite.","Moves the mage forward when terrain permits."},
  [2120]={"Daño de Fuego en área con efecto periódico.","Area Fire damage with a periodic effect."},
  [2136]={"Daño instantáneo de Fuego; comparte reutilización con Lanza de hielo.","Instant Fire damage; shares a cooldown with Ice Lance."},
  [2139]={"Interrumpe un lanzamiento e impide temporalmente hechizos de esa escuela.","Interrupts a cast and temporarily locks its school."},
  [2948]={"Ataque de Fuego de lanzamiento rápido.","Fast-cast Fire attack."},
  [3561]={"Viaja a Ventormenta; solo Alianza.","Travels to Stormwind; Alliance only."},
  [3562]={"Viaja a Forjaz; solo Alianza.","Travels to Ironforge; Alliance only."},
  [3565]={"Viaja a Darnassus; solo Alianza.","Travels to Darnassus; Alliance only."},
  [3563]={"Viaja a Entrañas; solo Horda.","Travels to Undercity; Horde only."},
  [3567]={"Viaja a Orgrimmar; solo Horda.","Travels to Orgrimmar; Horde only."},
  [3566]={"Viaja a Cima del Trueno; solo Horda.","Travels to Thunder Bluff; Horde only."},
  [5143]={"Canaliza proyectiles arcanos sobre un enemigo.","Channels Arcane projectiles at an enemy."},
  [5504]={"Crea agua temporal para recuperar maná fuera de combate.","Creates temporary water for recovering Mana out of combat."},
  [6117]={"Aumenta resistencias y permite regenerar parte del maná durante el lanzamiento.","Raises resistances and allows some Mana regeneration while casting."},
  [6143]={"Absorbe daño de Escarcha.","Absorbs Frost damage."},
  [7302]={"Aumenta armadura y resistencia a Escarcha; ralentiza a atacantes compatibles.","Raises armor and Frost resistance; slows eligible attackers."},
  [10059]={"Abre un portal para miembros del grupo a Ventormenta.","Opens a portal for party members to Stormwind."},
  [11416]={"Abre un portal para miembros del grupo a Forjaz.","Opens a portal for party members to Ironforge."},
  [11419]={"Abre un portal para miembros del grupo a Darnassus.","Opens a portal for party members to Darnassus."},
  [11417]={"Abre un portal para miembros del grupo a Orgrimmar.","Opens a portal for party members to Orgrimmar."},
  [11418]={"Abre un portal para miembros del grupo a Entrañas.","Opens a portal for party members to Undercity."},
  [11420]={"Abre un portal para miembros del grupo a Cima del Trueno.","Opens a portal for party members to Thunder Bluff."},
  [12051]={"Canaliza regeneración acelerada de maná.","Channels accelerated Mana regeneration."},
  [23028]={"Mejora el intelecto de los aliados del grupo; requiere reactivo.","Buffs the Intellect of party members; requires a reagent."},
  [28272]={"Variante independiente de Polimorfia que transforma al objetivo en cerdo.","Independent Polymorph variant that transforms the target into a pig."},
  [28271]={"Variante cosmética independiente. Tomo #22739 asociado a Gahz'ranka en Zul'Gurub; disponibilidad pendiente.","Independent cosmetic variant. Tome #22739 associated with Gahz'ranka in Zul'Gurub; availability unconfirmed."},
  [1297659]={"Teletransporte personal de Alianza documentado en el cliente; método de aprendizaje aún sin confirmar. No existe un portal de grupo confirmado.","Alliance personal teleport documented in client data; learning method unconfirmed. No confirmed group portal."},
  [401502]={"Daño de Fuego y Escarcha que ralentiza y deja daño periódico; usa la menor resistencia de ambas escuelas.","Fire and Frost damage that slows and leaves periodic damage; uses the lower of both resistances."},
  [1296017]={"Descifra pergaminos misteriosos y mejora Comprensión cuando el nivel del pergamino es adecuado. Umbrales de descifrado: 1, 15, 50 y 175.","Deciphers mysterious scrolls and raises Comprehension when the scroll tier is appropriate. Deciphering thresholds: 1, 15, 50 and 175."},
  [1302508]={"En la biblioteca, consume una pluma ligera para obtener un lote de pergaminos; reutilización de una hora. No es Investigación ni aumenta por sí solo Comprensión.","At the library, consume a Light Feather for a bundle of scrolls; one-hour cooldown. Not Research; does not itself increase Comprehension."},

  [400574]={"Daño arcano que acumula potencia de hechizo y aumenta su propio coste de maná.","Arcane damage that stacks spell power and increases its own Mana cost."},
  [1326079]={"Proyectil arcano que obtiene potencia adicional del maná máximo.","Arcane projectile with bonus spell power from maximum Mana."},
  [12043]={"Hace instantáneo el siguiente lanzamiento compatible.","Makes the next eligible cast instant."},
  [12042]={"Aumenta temporalmente el daño mágico y el coste de maná.","Temporarily increases spell damage and Mana cost."},
  [11366]={"Potente proyectil de Fuego con daño periódico posterior; Calentamiento puede acelerar su lanzamiento.","Powerful Fire projectile with subsequent periodic damage; Heating Up can speed its cast."},
  [11113]={"Inflige daño de Fuego en área alrededor del mago y ralentiza.","Deals area Fire damage around the mage and slows enemies."},
  [11129]={"Aumenta progresivamente el crítico de Fuego hasta lograr tres críticos directos.","Builds Fire critical chance until three direct critical hits occur."},
  [1312002]={"Ataque instantáneo de Escarcha potenciado contra objetivos congelados; comparte reutilización con Explosión de Fuego.","Instant Frost attack empowered against frozen targets; shares a cooldown with Fire Blast."},
  [11958]={"Protección temporal que impide moverse, atacar o lanzar hechizos.","Temporary protection that prevents movement, attacks and spellcasting."},
  [12472]={"Reinicia la reutilización de las demás facultades de Escarcha.","Resets cooldowns of other Frost abilities."},
  [11426]={"Absorbe daño, refuerza el daño de Escarcha y protege de retrasos de lanzamiento mientras resiste.","Absorbs damage, strengthens Frost damage and prevents cast pushback while intact."},
}
-- Brujo B03: facultades de talento, no efectos pasivos ni hechizos internos.
local talentosBrujo = {
  {id=18288,n=20,rama="Aflicción",en="Amplify Curse",es="Amplificar maldición"},
  {id=18223,n=25,rama="Aflicción",en="Curse of Exhaustion",es="Maldición de agotamiento"},
  {id=18265,n=30,rama="Aflicción",en="Siphon Life",es="Succionar vida"},
  {id=1316697,n=40,rama="Aflicción",en="Wrack",es="Arruinar"},
  {id=18788,n=20,rama="Demonología",en="Demonic Sacrifice",es="Sacrificio demoníaco"},
  {id=18708,n=25,rama="Demonología",en="Fel Domination",es="Dominio de lo maldito"},
  {id=19028,n=30,rama="Demonología",en="Soul Link",es="Vínculo de alma"},
  {id=17877,n=20,rama="Destrucción",en="Shadowburn",es="Quemadura de las Sombras"},
  {id=1293817,n=25,rama="Destrucción",en="Conflagrate",es="Conflagrar"},
  {id=1225228,n=30,rama="Destrucción",en="Bane of Havoc",es="Terror de caos"},
  {id=412758,n=40,rama="Destrucción",en="Incinerate",es="Incinerar"},
}
local talentosBrujoPorId={}
for _,e in ipairs(talentosBrujo) do talentosBrujoPorId[e.id]=e end
local nombresBrujo={
  [126]={"Ojo de Kilrogg","Eye of Kilrogg"},
  [132]={"Detectar invisibilidad","Detect Invisibility"},
  [172]={"Corrupción","Corruption"},
  [348]={"Inmolar","Immolate"},
  [603]={"Terror de condena","Bane of Doom"},
  [686]={"Descarga de las Sombras","Shadow Bolt"},
  [687]={"Piel de demonio","Demon Skin"},
  [688]={"Invocar diablillo","Summon Imp"},
  [689]={"Drenar vida","Drain Life"},
  [691]={"Invocar manáfago","Summon Felhunter"},
  [693]={"Crear piedra de alma","Create Soulstone"},
  [697]={"Invocar abisario","Summon Voidwalker"},
  [698]={"Ritual de invocación","Ritual of Summoning"},
  [702]={"Maldición de debilidad","Curse of Weakness"},
  [704]={"Maldición de temeridad","Curse of Recklessness"},
  [706]={"Armadura demoníaca","Demon Armor"},
  [710]={"Desterrar","Banish"},
  [712]={"Invocar súcubo","Summon Succubus"},
  [713]={"Invocar íncubo","Summon Incubus"},
  [755]={"Cauce de salud","Health Funnel"},
  [980]={"Terror de agonía","Bane of Agony"},
  [1098]={"Esclavizar demonio","Enslave Demon"},
  [1120]={"Drenar alma","Drain Soul"},
  [1122]={"Inferno","Inferno"},
  [1454]={"Transfusión de vida","Life Tap"},
  [1714]={"Maldición de las lenguas","Curse of Tongues"},
  [1949]={"Llamas infernales","Hellfire"},
  [2362]={"Crear piedra de hechizo","Create Spellstone"},
  [5138]={"Drenar maná","Drain Mana"},
  [5484]={"Aullido de terror","Howl of Terror"},
  [5500]={"Sentir demonios","Sense Demons"},
  [5676]={"Dolor abrasador","Searing Pain"},
  [5697]={"Aliento inagotable","Unending Breath"},
  [5740]={"Lluvia de Fuego","Rain of Fire"},
  [5782]={"Miedo","Fear"},
  [5784]={"Corcel vil (Malignoecus)","Felsteed"},
  [23161]={"Corcel nefasto (Terrorecus)","Dreadsteed"},
  [6201]={"Crear piedra de salud","Create Healthstone"},
  [6229]={"Resguardo de las Sombras","Shadow Ward"},
  [6353]={"Fuego de alma","Soul Fire"},
  [6366]={"Crear piedra de fuego","Create Firestone"},
  [6789]={"Espiral de la muerte","Death Coil"},
  [18540]={"Ritual de fatalidad","Ritual of Doom"},
  [440892]={"Maldición de los elementos","Curse of the Elements"},
  [437169]={"Portal de invocación","Portal of Summoning"},
}
local descripcionBrujo={
  [126]={"Invoca un ojo controlable para explorar.","Summons a controllable scouting eye."},
  [132]={"Permite detectar efectos de invisibilidad compatibles.","Allows detection of eligible invisibility effects."},
  [172]={"Daño periódico de Sombras; los talentos pueden acelerar el lanzamiento.","Periodic Shadow damage; talents can speed up its cast."},
  [348]={"Daño inicial y periódico de Fuego; habilita Conflagrar si se ha aprendido.","Initial and periodic Fire damage; enables Conflagrate if learned."},
  [603]={"Daño de Sombras diferido; ocupa el espacio de terror, no el de maldición.","Delayed Shadow damage; occupies the bane slot, not the curse slot."},
  [686]={"Proyectil de daño directo de Sombras.","Direct Shadow damage projectile."},
  [687]={"Mejora la armadura y la regeneración de salud.","Improves armor and health regeneration."},
  [688]={"Invoca un diablillo que ataca a distancia y aporta apoyo.","Summons an Imp for ranged attacks and support."},
  [689]={"Canaliza daño y recupera salud.","Channels damage and restores health."},
  [691]={"Invoca un demonio especializado en utilidad contra lanzadores.","Summons a demon specialized in anti-caster utility."},
  [693]={"Crea una piedra que permite resucitar al aliado vinculado; requiere fragmento de alma.","Creates a stone allowing the bound ally to resurrect; requires a Soul Shard."},
  [697]={"Invoca un demonio resistente que puede atraer la atención de enemigos.","Summons a durable demon that can draw enemy attention."},
  [698]={"Invoca a un miembro del grupo con ayuda de otros jugadores y el reactivo necesario.","Summons a party member with assistance and the required reagent."},
  [702]={"Debilita los ataques del enemigo; ocupa el espacio de maldición propia.","Weakens enemy attacks; occupies your curse slot."},
  [704]={"Reduce armadura y altera la huida; ya no aumenta el daño del objetivo.","Reduces armor and affects fleeing; no longer increases the target's damage."},
  [706]={"Aumenta armadura, resistencia a Sombras y regeneración de salud.","Raises armor, Shadow resistance and health regeneration."},
  [710]={"Incapacita temporalmente a un demonio o elemental compatible.","Temporarily incapacitates an eligible demon or elemental."},
  [712]={"Invoca una sayaad con daño y control de enemigos compatibles.","Summons a Sayaad for damage and eligible crowd control."},
  [713]={"Invoca un sayaad íncubo con las mismas facultades que la súcubo; se aprende por separado.","Summons an Incubus Sayaad with the same abilities as a Succubus; learned separately."},
  [755]={"Transfiere salud al demonio mediante canalización.","Channels health into your demon."},
  [980]={"Daño periódico creciente de Sombras; puede coexistir con una maldición propia.","Increasing periodic Shadow damage; can coexist with your curse."},
  [1098]={"Controla temporalmente un demonio compatible.","Temporarily controls an eligible demon."},
  [1120]={"Canaliza daño de Sombras; puede obtener fragmentos en pulsos válidos.","Channels Shadow damage; eligible ticks can grant Soul Shards."},
  [1122]={"Invoca un infernal; requiere controlar al demonio y cumplir los requisitos de lanzamiento.","Summons an Infernal; requires demon control and cast requirements."},
  [1454]={"Convierte salud en maná y se beneficia del espíritu.","Converts Health into Mana and benefits from Spirit."},
  [1714]={"Ralentiza el lanzamiento de hechizos enemigos.","Slows enemy spellcasting."},
  [1949]={"Daño de Fuego canalizado alrededor del brujo que también le daña.","Channeled area Fire damage that also harms the caster."},
  [2362]={"Crea una imbuición de arma que potencia Sombras y la celeridad de hechizos; no es la antigua piedra de mano izquierda.","Creates a weapon imbue boosting Shadow spells and spell haste, not the old off-hand stone."},
  [5138]={"Canaliza extracción de maná de un enemigo compatible.","Channels Mana from an eligible enemy."},
  [5484]={"Provoca miedo en enemigos cercanos compatibles.","Fears eligible nearby enemies."},
  [5500]={"Muestra demonios cercanos en el minimapa.","Tracks nearby demons on the minimap."},
  [5676]={"Daño directo de Fuego; vigila la amenaza y los talentos que la modifican.","Direct Fire damage; mind threat and talents that modify it."},
  [5697]={"Permite respirar bajo el agua.","Allows underwater breathing."},
  [5740]={"Daño canalizado de Fuego en un área seleccionada.","Channeled Fire damage in a selected area."},
  [5782]={"Hace huir temporalmente al enemigo; el daño puede romper el efecto.","Temporarily causes an enemy to flee; damage may break it."},
  [5784]={"Montura de Colecciones, misión 4490 al nivel 40. La corrección del 9/11 concede equitación de aprendiz; si la completaste antes, invoca el corcel una vez. Si sigue faltando, consulta soporte.","Collection mount, quest 4490 at level 40. The Nov 9 fix grants Apprentice Riding; if completed earlier, summon the mount once. If still missing, contact support."},
  [23161]={"Montura de Colecciones, misión 7631 al nivel 60. La corrección del 25/11 concede equitación avanzada; si ya terminaste, habla con Ursula Deline (Alianza) o Zevrost (Horda).","Collection mount, quest 7631 at level 60. The Nov 25 fix grants Journeyman Riding; if already completed, speak to Ursula Deline (Alliance) or Zevrost (Horde)."},
  [6201]={"Crea una piedra consumible de sanación; requiere fragmento de alma.","Creates a healing consumable; requires a Soul Shard."},
  [6229]={"Absorbe daño de Sombras.","Absorbs Shadow damage."},
  [6353]={"Ataque de Fuego de lanzamiento largo; los talentos pueden acelerar su uso.","Long-cast Fire attack; talents can speed up its use."},
  [6366]={"Crea una imbuición de arma que mejora daño de Fuego y crítico de hechizos.","Creates a weapon imbue boosting Fire damage and spell critical chance."},
  [6789]={"Inflige daño de Sombras, devuelve salud y provoca horror breve.","Deals Shadow damage, restores health and briefly horrifies."},
  [18540]={"Ritual grupal para invocar un guardia apocalíptico; requiere los reactivos y control adecuados.","Group ritual to summon a Doomguard; requires appropriate reagents and control."},
  [440892]={"Reduce resistencias mágicas y aumenta el daño mágico recibido; afecta a todas las escuelas mágicas.","Reduces magic resistances and increases magic damage taken across all magic schools."},
  [437169]={"Referencia documentada del portal reutilizable de invocación; obtención real del grimorio sin confirmar.","Documented reusable summoning portal reference; actual grimoire availability unconfirmed."},

  [18288]={"Potencia la siguiente Maldición de debilidad, Terror de agonía o Maldición de agotamiento.","Empowers the next Curse of Weakness, Bane of Agony or Curse of Exhaustion."},
  [18223]={"Ralentiza a un enemigo; ocupa el espacio de maldición, no el de terror.","Slows an enemy; occupies the curse slot, not the bane slot."},
  [18265]={"Daño periódico de Sombras que devuelve salud.","Periodic Shadow damage that restores health."},
  [1316697]={"Canaliza daño de Sombras y acelera los pulsos de Corrupción, Succionar vida y Terror de agonía activos.","Channels Shadow damage and accelerates ticks of active Corruption, Siphon Life and Bane of Agony."},
  [18788]={"Sacrifica el demonio para obtener una mejora según su tipo. Pacto demoníaco permite conservarla al invocar otro tipo.","Sacrifices the demon for a type-specific buff. Demonic Pact allows retaining it when summoning a different type."},
  [18708]={"Acelera y abarata la siguiente invocación compatible.","Speeds up and reduces the cost of the next eligible summon."},
  [19028]={"Comparte daño recibido con el demonio activo y mejora el daño de ambos.","Shares incoming damage with the active demon and increases damage for both."},
  [17877]={"Daño instantáneo de Sombras; puede devolver un fragmento con una muerte válida.","Instant Shadow damage; an eligible kill can refund a shard."},
  [1293817]={"Detona Inmolar; Sombras y llamas puede evitar consumir el efecto.","Detonates Immolate; Shadow and Flame may prevent consuming the effect."},
  [1225228]={"Transfiere parte del daño infligido a otros enemigos al objetivo marcado. Solo un Terror propio por objetivo.","Copies some damage dealt to other enemies onto the marked target. One personal Bane per target."},
  [412758]={"Daño directo de Fuego reforzado contra objetivos afectados por Inmolar.","Direct Fire damage strengthened against targets affected by Immolate."},
}
-- Druida B03: nueve facultades activas; no incluir auras, efectos de proc ni talentos pasivos.
local talentosDruida={
  {id=5570,n=25,rama="Equilibrio",en="Insect Swarm",es="Enjambre de insectos"},
  {id=24858,n=40,rama="Equilibrio",en="Moonkin Form",es="Forma de lechúcico lunar"},
  {id=1238122,n=20,rama="Combate feral",en="Feral Charge",es="Carga feral"},
  {id=1328617,n=25,rama="Combate feral",en="Lacerate",es="Lacerar"},
  {id=407995,n=40,rama="Combate feral",en="Primal Bite",es="Mordisco primigenio"},
  {id=1322605,n=40,rama="Combate feral",en="Shifting Power",es="Poder cambiante"},
  {id=18562,n=25,rama="Restauración",en="Swiftmend",es="Alivio presto"},
  {id=17116,n=30,rama="Restauración",en="Nature's Swiftness",es="Presteza de la naturaleza"},
  {id=408120,n=40,rama="Restauración",en="Wild Growth",es="Crecimiento salvaje"},
}
local talentosDruidaPorId={}
for _,e in ipairs(talentosDruida) do talentosDruidaPorId[e.id]=e end
local nombresDruida={
  [6795]={"Bramido","Growl"},
  [1126]={"Marca de lo Salvaje","Mark of the Wild"},
  [774]={"Rejuvenecimiento","Rejuvenation"},
  [8921]={"Fuego lunar","Moonfire"},
  [467]={"Espinas","Thorns"},
  [339]={"Raíces enredadoras","Entangling Roots"},
  [99]={"Rugido desmoralizador","Demoralizing Roar"},
  [16689]={"Trabazón con la Naturaleza","Nature's Grasp"},
  [5229]={"Enfurecer","Enrage"},
  [8936]={"Recrecimiento","Regrowth"},
  [437138]={"Revivir","Revive"},
  [5211]={"Azote","Bash"},
  [779]={"Flagelo","Swipe"},
  [770]={"Fuego feérico","Faerie Fire"},
  [2637]={"Hibernar","Hibernate"},
  [2912]={"Fuego estelar","Starfire"},
  [5221]={"Triturar","Shred"},
  [16864]={"Augurio de claridad","Omen of Clarity"},
  [20484]={"Renacer","Rebirth"},
  [2908]={"Calmar animal","Soothe Animal"},
  [1822]={"Arañazo","Rake"},
  [2782]={"Eliminar maldición","Remove Curse"},
  [1328618]={"Mordedura feroz","Ferocious Bite"},
  [1850]={"Carrera","Dash"},
  [2893]={"Abolir veneno","Abolish Poison"},
  [5209]={"Rugido desafiante","Challenging Roar"},
  [8998]={"Agazapar","Cower"},
  [740]={"Tranquilidad","Tranquility"},
  [783]={"Forma de viaje","Travel Form"},
  [5225]={"Rastrear humanoides","Track Humanoids"},
  [6785]={"Devastar","Ravage"},
  [1328829]={"Disposición","Poised"},
  [9005]={"Abalanzarse","Pounce"},
  [22842]={"Regeneración frenética","Frenzied Regeneration"},
  [9634]={"Forma de oso temible","Dire Bear Form"},
  [16914]={"Huracán","Hurricane"},
  [20719]={"Gracia felina","Feline Grace"},
  [29166]={"Estimular","Innervate"},
  [22812]={"Piel de corteza","Barkskin"},
  [5176]={"Cólera","Wrath"},
  [5185]={"Toque de sanación","Healing Touch"},
  [18960]={"Teletransporte: Claro de la Luna","Teleport: Moonglade"},
  [5487]={"Forma de oso","Bear Form"},
  [6807]={"Magullar","Maul"},
  [8946]={"Curar veneno","Cure Poison"},
  [1066]={"Forma acuática","Aquatic Form"},
  [768]={"Forma felina","Cat Form"},
  [1082]={"Zarpa","Claw"},
  [1079]={"Destripar","Rip"},
  [5215]={"Acechar","Prowl"},
  [21849]={"Don de lo Salvaje","Gift of the Wild"},
}
local descripcionDruida={
  [6795]={"Provoca al enemigo para que ataque al druida en oso; no es un rango de Rugido desafiante.","Taunts the enemy to attack the Druid in Bear Form; not a rank of Challenging Roar."},
  [1126]={"Mejora armadura, atributos y resistencias de un aliado.","Buffs an ally's armor, attributes and resistances."},
  [774]={"Curación periódica instantánea de un aliado.","Instantly applies a heal over time to an ally."},
  [8921]={"Daño Arcano inicial y periódico.","Initial and periodic Arcane damage."},
  [467]={"Inflige daño de Naturaleza a atacantes cuerpo a cuerpo del aliado.","Deals Nature damage to melee attackers of the ally."},
  [339]={"Inmoviliza y daña periódicamente; puede romperse con daño.","Roots and deals periodic damage; damage may break it."},
  [99]={"Reduce el poder de ataque de enemigos cercanos en oso.","Reduces nearby enemies' attack power in Bear Form."},
  [16689]={"Prepara un efecto de raíces al recibir ataques; ahora se aprende sin talento.","Prepares a rooting effect when attacked; now learned without a talent."},
  [5229]={"Genera ira en oso; consulta el efecto defensivo del rango real.","Generates Rage in Bear Form; check the current defensive effect."},
  [8936]={"Curación directa seguida de sanación periódica.","Direct heal followed by healing over time."},
  [437138]={"Resucita a un aliado fuera de combate; no sustituye Renacer.","Resurrects an ally out of combat; does not replace Rebirth."},
  [5211]={"Aturde al enemigo en oso.","Stuns an enemy in Bear Form."},
  [779]={"Ataque de oso contra varios enemigos cercanos.","Bear attack against multiple nearby enemies."},
  [770]={"Reduce armadura e impide sigilo o invisibilidad.","Reduces armor and prevents stealth or invisibility."},
  [2637]={"Duerme a una bestia o dragón compatible.","Puts an eligible beast or dragon to sleep."},
  [2912]={"Daño Arcano directo con tiempo de lanzamiento.","Direct Arcane damage with a cast time."},
  [5221]={"Ataque de gato desde detrás del objetivo; genera un punto de combo.","Cat attack from behind the target; grants a combo point."},
  [16864]={"Pasivo de nivel 20: ataques y hechizos pueden activar lanzamiento libre; Cólera no consume ese efecto.","Level 20 passive: attacks and spells can trigger Clearcasting; Wrath does not consume it."},
  [20484]={"Resurrección que puede usarse en combate; consulta reactivo y reutilización.","Resurrection usable in combat; check reagent and cooldown."},
  [2908]={"Reduce el alcance de agresión de bestias compatibles.","Reduces aggro range of eligible beasts."},
  [1822]={"Ataque felino con daño inicial y sangrado; genera combo.","Cat attack with initial damage and bleed; grants a combo point."},
  [2782]={"Disipa una maldición o terror de un aliado.","Dispels a Curse or Bane from an ally."},
  [1328618]={"Remate felino que escala con puntos de combo y energía adicional; Disciplina depredadora modifica el gasto.","Cat finisher scaling with combo points and extra Energy; Predatory Discipline changes consumption."},
  [1850]={"Aumenta temporalmente la velocidad en gato.","Temporarily increases Cat movement speed."},
  [2893]={"Elimina venenos y vuelve a intentarlo periódicamente.","Removes poison and repeats the attempt periodically."},
  [5209]={"Fuerza temporalmente a enemigos cercanos a atacar al druida.","Temporarily forces nearby enemies to attack the druid."},
  [8998]={"Reduce amenaza en forma felina.","Lowers threat in Cat Form."},
  [740]={"Sanación canalizada para miembros cercanos del grupo.","Channeled healing for nearby party members."},
  [783]={"Forma de movimiento en exteriores; requisitos de terreno del cliente.","Outdoor movement form; terrain restrictions apply."},
  [5225]={"Muestra humanoides cercanos en el minimapa en gato.","Tracks nearby humanoids on the minimap in Cat Form."},
  [6785]={"Ataque felino desde sigilo y detrás del objetivo.","Cat attack from stealth and behind the target."},
  [1328829]={"Pasivo de gato al nivel 32: fuera de combate y con energía máxima, abarata la siguiente facultad.","Level 32 Cat passive: at full Energy out of combat, lowers the next ability's cost."},
  [9005]={"Ataque desde sigilo que aturde y aplica sangrado.","Stealth opener that stuns and bleeds."},
  [22842]={"Convierte ira en recuperación de salud en oso.","Converts Rage into Health recovery in Bear Form."},
  [9634]={"Forma avanzada de oso; aumenta resistencia y capacidad de tanque.","Advanced Bear form; improves durability and tanking."},
  [16914]={"Tormenta canalizada de Naturaleza en área que ralentiza ataques.","Channeled Nature storm in an area that slows attacks."},
  [20719]={"Reduce el daño por caída en gato.","Reduces fall damage in Cat Form."},
  [29166]={"Mejora temporalmente la regeneración de maná del objetivo.","Temporarily improves the target's Mana regeneration."},
  [22812]={"Reduce daño recibido temporalmente; consulta las restricciones del cliente.","Temporarily reduces damage taken; check current restrictions."},
  [5176]={"Daño de Naturaleza de lanzamiento rápido.","Fast-cast Nature damage."},
  [5185]={"Curación directa de un aliado.","Direct heal on an ally."},
  [18960]={"Viaja al Claro de la Luna.","Travels to Moonglade."},
  [5487]={"Forma resistente que utiliza ira para combatir.","Durable combat form using Rage."},
  [6807]={"Potencia el siguiente ataque de oso y genera amenaza.","Empowers the next Bear attack and generates threat."},
  [8946]={"Elimina un veneno de un aliado.","Removes one poison from an ally."},
  [1066]={"Permite respirar bajo el agua y nadar más rápido.","Allows underwater breathing and faster swimming."},
  [768]={"Forma que usa energía y puntos de combo.","Form using Energy and combo points."},
  [1082]={"Ataque de gato que genera un punto de combo.","Cat attack granting a combo point."},
  [1079]={"Remate felino que aplica sangrado según puntos de combo.","Cat finisher applying a bleed based on combo points."},
  [5215]={"Permite moverse en sigilo en forma felina.","Enables stealth movement in Cat Form."},
  [21849]={"Mejora armadura, atributos y resistencias del grupo y banda; requiere reactivo.","Buffs party and raid armor, attributes and resistances; requires a reagent."},

  [5570]={"Daño periódico de Naturaleza; reduce el acierto de ataques enemigos.","Nature damage over time; lowers enemy attack hit chance."},
  [24858]={"Forma ofensiva con armadura y aura de crítico; mejora Augurio de claridad e impide sanar.","Offensive form with armor and a critical strike aura; improves Omen of Clarity and prevents healing."},
  [1238122]={"En oso carga, interrumpe e inmoviliza; en gato salta detrás del enemigo. Variantes del mismo talento.","Bear charges, interrupts and roots; Cat leaps behind an enemy. Variants of one talent."},
  [1328617]={"Sangrado acumulable en oso con amenaza elevada; hasta cinco acumulaciones.","Stacking high-threat Bear bleed; up to five stacks."},
  [407995]={"Mordisco de oso que genera amenaza elevada.","Bear bite that generates high threat."},
  [1322605]={"Convierte maná en energía; las reducciones del coste de cambio de forma también lo abaratan.","Converts Mana into Energy; shapeshifting cost reductions also apply."},
  [18562]={"Sana al instante a un objetivo con tu propio Rejuvenecimiento o Recrecimiento sin consumirlo.","Instantly heals a target with your own Rejuvenation or Regrowth without consuming it."},
  [17116]={"Hace instantáneo el siguiente hechizo de Naturaleza compatible, incluido Crecimiento salvaje.","Makes the next eligible Nature spell instant, including Wild Growth."},
  [408120]={"Curación periódica del objetivo y miembros cercanos de su grupo; tiene tiempo de lanzamiento salvo mejoras.","Heals the target and nearby party members over time; has a cast time unless modified."},
}
local function NivelPlanTalento(id)
  local R = GL.RUTA
  local nombre = R and ((R.clase == "WARRIOR" and nombresPlanGuerrero[id]) or
    (R.clase == "PALADIN" and talentosPaladinPorId[id] and talentosPaladinPorId[id].en) or
    (R.clase == "HUNTER" and talentosCazadorPorId[id] and talentosCazadorPorId[id].en) or
    (R.clase == "ROGUE" and talentosPicaroPorId[id] and talentosPicaroPorId[id].en) or
    (R.clase == "PRIEST" and talentosSacerdotePorId[id] and talentosSacerdotePorId[id].en) or
    (R.clase == "SHAMAN" and talentosChamanPorId[id] and talentosChamanPorId[id].en) or
    (R.clase == "MAGE" and talentosMagoPorId[id] and talentosMagoPorId[id].en) or
    (R.clase == "WARLOCK" and talentosBrujoPorId[id] and talentosBrujoPorId[id].en) or
    (R.clase == "DRUID" and talentosDruidaPorId[id] and talentosDruidaPorId[id].en))
  if not nombre then return nil end
  for _, t in ipairs(R.talentos or {}) do
    local a, b = (t.nombre or ""):match("^(.-)%s*%((.-)%)%s*$")
    if a == nombre or b == nombre or t.nombre == nombre then return t.d end
  end
end

-- Nombres de presentación ES/EN por raíz de cadena. Referencias: Codex Forever,
-- TalentsForever (localización beta) y el informe esES de Última posición, build 71091.
-- Las variantes no observadas son etiquetas de guía, no equivalencias para comprar.
-- General: beta spellbook 70755 (playautotechnologies.org/wow-forever-spellbook-warrior),
-- ForeverCraft shared spell IDs and wowforeverclasses.com/articles/warrior-weapons-wow-forever.
-- These are not class-trainer purchases; weapon masters are listed in Biblioteca.
-- Unknown minimum training levels are intentionally absent; client names take priority.
local generalesGuerrero = {
  { id = 1293712, origen = "general", n = 1 },
  { id = 1293657, origen = "general", n = 1 },
  { id = 6603, origen = "general", n = 1 },
  { id = 107, origen = "general", n = 1 },
  { id = 81, origen = "general", n = 1 },
  { id = 2480, origen = "general", n = 1 },
  { id = 7919, origen = "general", n = 1 },
  { id = 7918, origen = "general", n = 1 },
  { id = 2764, origen = "general", n = 1 },
  { id = 196, origen = "arma" },
  { id = 197, origen = "arma" },
  { id = 198, origen = "arma" },
  { id = 199, origen = "arma" },
  { id = 200, origen = "arma", n = 20 },
  { id = 201, origen = "arma" },
  { id = 202, origen = "arma" },
  { id = 227, origen = "arma" },
  { id = 264, origen = "arma" },
  { id = 266, origen = "arma" },
  { id = 1180, origen = "arma" },
  { id = 2567, origen = "arma" },
  { id = 5011, origen = "arma" },
  { id = 15590, origen = "arma" },
  { id = 9078, origen = "general" },
  { id = 9077, origen = "general" },
  { id = 8737, origen = "general" },
  { id = 9116, origen = "general" },
}

local nombresGuerrero = {
  [1293712] = {"Competencia con armaduras", "Armor Proficiency"},
  [1293657] = {"Idiomas", "Languages"},
  [6603] = {"Atacar", "Attack"},
  [107] = {"Bloqueo", "Block"},
  [81] = {"Esquivar", "Dodge"},
  [2480] = {"Disparar con arco", "Shoot Bow"},
  [7919] = {"Disparar con ballesta", "Shoot Crossbow"},
  [7918] = {"Disparar con arma de fuego", "Shoot Gun"},
  [2764] = {"Lanzar", "Throw"},
  [196] = {"Hachas", "One-Handed Axes"},
  [197] = {"Hachas de dos manos", "Two-Handed Axes"},
  [198] = {"Mazas", "One-Handed Maces"},
  [199] = {"Mazas de dos manos", "Two-Handed Maces"},
  [200] = {"Armas de asta", "Polearms"},
  [201] = {"Espadas", "One-Handed Swords"},
  [202] = {"Espadas de dos manos", "Two-Handed Swords"},
  [227] = {"Bastones", "Staves"},
  [264] = {"Arcos", "Bows"},
  [266] = {"Armas de fuego", "Guns"},
  [1180] = {"Dagas", "Daggers"},
  [2567] = {"Armas arrojadizas", "Thrown"},
  [5011] = {"Ballestas", "Crossbows"},
  [15590] = {"Armas de puño", "Fist Weapons"},
  [9078] = {"Tela", "Cloth"},
  [9077] = {"Cuero", "Leather"},
  [8737] = {"Malla", "Mail"},
  [9116] = {"Escudos", "Shield"},

  [71] = {"Actitud defensiva", "Defensive Stance"},
  [72] = {"Azote de escudo", "Shield Bash"},
  [78] = {"Golpe heroico", "Heroic Strike"},
  [100] = {"Cargar", "Charge"},
  [355] = {"Provocar", "Taunt"},
  [674] = {"Doble empuñadura", "Dual Wield"},
  [676] = {"Desarmar", "Disarm"},
  [694] = {"Golpe burlón", "Mocking Blow"},
  [750] = {"Armadura de placas", "Plate Mail"},
  [772] = {"Desgarrar", "Rend"},
  [845] = {"Rajar", "Cleave"},
  [871] = {"Muro de escudo", "Shield Wall"},
  [1160] = {"Grito desmoralizador", "Demoralizing Shout"},
  [1161] = {"Grito desafiante", "Challenging Shout"},
  [1680] = {"Torbellino", "Whirlwind"},
  [1715] = {"Seccionar", "Hamstring"},
  [1719] = {"Temeridad", "Recklessness"},
  [2457] = {"Actitud de batalla", "Battle Stance"},
  [2458] = {"Actitud rabiosa", "Berserker Stance"},
  [2565] = {"Bloquear con escudo", "Shield Block"},
  [2687] = {"Ira sangrienta", "Bloodrage"},
  [3127] = {"Parada", "Parry"},
  [5246] = {"Grito intimidador", "Intimidating Shout"},
  [5308] = {"Ejecutar", "Execute"},
  [6343] = {"Atronar", "Thunder Clap"},
  [6552] = {"Zurrar", "Pummel"},
  [6572] = {"Revancha", "Revenge"},
  [6673] = {"Grito de batalla", "Battle Shout"},
  [7384] = {"Abrumar", "Overpower"},
  [7386] = {"Hender armadura", "Sunder Armor"},
  [12292] = {"Golpes de barrido", "Sweeping Strikes"},
  [12294] = {"Golpe mortal", "Mortal Strike"},
  [12323] = {"Aullido perforador", "Piercing Howl"},
  [12328] = {"Deseo de muerte", "Death Wish"},
  [12809] = {"Golpe conmocionador", "Concussion Blow"},
  [12975] = {"Última posición", "Last Stand"},
  [18499] = {"Ira rabiosa", "Berserker Rage"},
  [20230] = {"Represalias", "Retaliation"},
  [20252] = {"Interceptar", "Intercept"},
  [23881] = {"Sed de sangre", "Bloodthirst"},
  [23922] = {"Embate con escudo", "Shield Slam"},
  [402927] = {"Ataque de la victoria", "Victory Rush"},
  [1240193] = {"Embate", "Slam"},
  [1310185] = {"Maestría táctica", "Tactical Mastery"},
  [1310222] = {"Lanzazo", "Spearing Strike"},
  [1329555] = {"Golpes temerarios", "Reckless Swings"},
}
-- Paladín: subconjunto de habilidades generales compartidas; sin armas a distancia ni doble empuñadura.
-- Fuentes: wowforevertalents.com/abilities/paladin/ (71139, 25/11),
-- warcraftforever.games/classes/paladin/spells (General) y foreverwow.com/weapons/paladin/.
-- El nivel de uso de una competencia no acredita que el personaje ya la conozca.
local generalesPaladin = {
  { id = 1293712, origen = "general", n = 1 },
  { id = 1293657, origen = "general", n = 1 },
  { id = 6603, origen = "general", n = 1 },
  { id = 107, origen = "general", n = 1 },
  { id = 81, origen = "general", n = 1 },
  { id = 196, origen = "arma", n = 1 },
  { id = 197, origen = "arma", n = 1 },
  { id = 198, origen = "arma", n = 1 },
  { id = 199, origen = "arma", n = 1 },
  { id = 200, origen = "arma", n = 20 },
  { id = 201, origen = "arma", n = 1 },
  { id = 202, origen = "arma", n = 1 },
  { id = 9078, origen = "general", n = 1 },
  { id = 9077, origen = "general", n = 1 },
  { id = 8737, origen = "general", n = 1 },
  { id = 9116, origen = "general", n = 1 },
}
local generalPaladinPorId = {}
for _, e in ipairs(generalesPaladin) do generalPaladinPorId[e.id] = true end

-- Cazador: competencias documentadas en Forever (71139); solo las compatibles.
-- https://wowforevertalents.com/abilities/hunter/ ; https://wowclassicforever.info/classes/hunter/weapons/
-- Nivel de uso, no prueba de que ya se haya aprendido. Doble empuñadura y malla
-- permanecen en el instructor de clase (674/8737, niveles 20/40).
local generalesCazador = {
  {id=1293712,n=1,origen="general"}, {id=1293657,n=1,origen="general"},
  {id=6603,n=1,origen="general"}, {id=81,n=1,origen="general"},
  {id=75,n=1,origen="general"},
  {id=196,n=1,origen="arma"}, {id=197,n=1,origen="arma"},
  {id=201,n=1,origen="arma"}, {id=202,n=1,origen="arma"},
  {id=200,n=20,origen="arma"}, {id=227,n=1,origen="arma"},
  {id=264,n=1,origen="arma"}, {id=266,n=1,origen="arma"},
  {id=1180,n=1,origen="arma"}, {id=2567,n=1,origen="arma"},
  {id=5011,n=1,origen="arma"}, {id=15590,n=1,origen="arma"},
  {id=9078,n=1,origen="general"}, {id=9077,n=1,origen="general"},
}
local generalCazadorPorId = {}
for _,e in ipairs(generalesCazador) do generalCazadorPorId[e.id]=true end
local precioCazadorSinConfirmar = {[3127]=true,[674]=true,[8737]=true}

-- Pícaro B08: 9 tipos de armas y tela/cuero; nivel de uso, no aprendizaje automático.
-- ForeverMastery (70707), Pullwise y SenseOS; doble empuñadura permanece en el instructor al 10.
local generalesPicaro = {
  {id=1293712,n=1,origen="general"}, {id=1293657,n=1,origen="general"},
  {id=6603,n=1,origen="general"}, {id=81,n=1,origen="general"},
  {id=2480,n=1,origen="general"}, {id=7919,n=1,origen="general"},
  {id=7918,n=1,origen="general"}, {id=2764,n=1,origen="general"},
  {id=196,n=1,origen="arma"}, {id=198,n=1,origen="arma"},
  {id=201,n=1,origen="arma"}, {id=264,n=1,origen="arma"},
  {id=266,n=1,origen="arma"}, {id=1180,n=1,origen="arma"},
  {id=2567,n=1,origen="arma"}, {id=5011,n=1,origen="arma"},
  {id=15590,n=1,origen="arma"}, {id=9078,n=1,origen="general"},
  {id=9077,n=1,origen="general"},
}
local generalPicaroPorId={}
for _,e in ipairs(generalesPicaro) do generalPicaroPorId[e.id]=true end
-- Sacerdote B06: cuatro armas, tela, facultades generales. Maza y varita iniciales;
-- daga/bastón requieren maestro de armas. No son compras del instructor de clase.
local generalesSacerdote = {
  {id=1293712,n=1,origen="general"}, {id=1293657,n=1,origen="general"},
  {id=6603,n=1,origen="general"}, {id=81,n=1,origen="general"},
  {id=198,n=1,origen="general"}, {id=227,n=1,origen="arma"},
  {id=1180,n=1,origen="arma"}, {id=5009,n=1,origen="general"},
  {id=5019,n=1,origen="general"}, {id=9078,n=1,origen="general"},
}
local generalSacerdotePorId={}
for _,e in ipairs(generalesSacerdote) do generalSacerdotePorId[e.id]=true end
-- Chamán B06: siete tipos de armas; las de dos manos no requieren talento.
-- La competencia de malla ya está en el catálogo del instructor (40).
local generalesChaman={
  {id=1293712,n=1,origen="general"},{id=1293657,n=1,origen="general"},
  {id=6603,n=1,origen="general"},{id=81,n=1,origen="general"},{id=107,n=1,origen="general"},
  {id=198,n=1,origen="general"},{id=227,n=1,origen="general"},
  {id=196,n=1,origen="arma"},{id=197,n=1,origen="arma"},{id=199,n=1,origen="arma"},
  {id=1180,n=1,origen="arma"},{id=15590,n=1,origen="arma"},
  {id=9078,n=1,origen="general"},{id=9077,n=1,origen="general"},{id=9116,n=1,origen="general"},
}
local generalChamanPorId={}
for _,e in ipairs(generalesChaman) do generalChamanPorId[e.id]=true end
-- Mago B06: competencias de arma, no servicios del instructor de clase.
local generalesMago={
 {id=227,n=1,origen="general"},{id=1180,n=1,origen="arma"},{id=201,n=1,origen="arma"},
 {id=5009,n=1,origen="general"},{id=5019,n=1,origen="general"},{id=9078,n=1,origen="general"},
 {id=1293712,n=1,origen="general"},{id=1293657,n=1,origen="general"},{id=6603,n=1,origen="general"},{id=81,n=1,origen="general"},
}
local generalMagoPorId={}
for _,e in ipairs(generalesMago) do generalMagoPorId[e.id]=true end
-- Brujo B07: daga y varita iniciales; bastón y espada con maestro de armas.
local generalesBrujo={
 {id=1180,n=1,origen="general"},{id=227,n=1,origen="arma"},{id=201,n=1,origen="arma"},
 {id=5009,n=1,origen="general"},{id=5019,n=1,origen="general"},{id=9078,n=1,origen="general"},
 {id=1293712,n=1,origen="general"},{id=1293657,n=1,origen="general"},{id=6603,n=1,origen="general"},{id=81,n=1,origen="general"},
}
local generalBrujoPorId={}
for _,e in ipairs(generalesBrujo) do generalBrujoPorId[e.id]=true end
-- Druida B06: las competencias iniciales dependen de la raza; no se presupone Skyborne.
local generalesDruida={
 {id=1180,n=1,origen="arma"},{id=227,n=1,origen="general"},{id=198,n=1,origen="arma"},
 {id=199,n=1,origen="arma"},{id=15590,n=1,origen="arma"},{id=200,n=20,origen="arma"},
 {id=9078,n=1,origen="general"},{id=9077,n=1,origen="general"},{id=1293712,n=1,origen="general"},
 {id=1293657,n=1,origen="general"},{id=6603,n=1,origen="general"},{id=81,n=1,origen="general"},
}
local generalDruidaPorId={}
for _,e in ipairs(generalesDruida) do generalDruidaPorId[e.id]=true end
local precioGuerreroSinConfirmar = { [3127] = true, [674] = true, [750] = true }
-- Paladín: competencias generales excluidas de la tabla Pyroblast; otras fuentes difieren.
local precioPaladinSinConfirmar = { [3127] = true, [750] = true }
local raizPorId = {}

-- Resúmenes originales de uso, no traducciones literales del tooltip ni cifras de rango.
-- Contraste: ForeverDiff (71091/71139), ForeverDB (71139), calculadora de hechizos (70755).
local descripcionGuerrero = {
  [1293712] = {"Consulta los tipos de armadura permitidos; las placas se desbloquean por separado.", "Lists permitted armor types; plate unlocks separately."},
  [1293657] = {"Consulta los idiomas que conoce tu personaje.", "Lists your character’s known languages."},
  [6603] = {"Inicia el ataque cuerpo a cuerpo normal.", "Starts normal melee attacks."},
  [107] = {"Permite bloquear ataques con un escudo.", "Enables blocking attacks with a shield."},
  [81] = {"Permite esquivar ataques cuerpo a cuerpo.", "Enables dodging melee attacks."},
  [2480] = {"Ataca a distancia con un arco equipado y la competencia correspondiente.", "Ranged attack with an equipped bow and its proficiency."},
  [7919] = {"Ataca a distancia con una ballesta equipada y su competencia.", "Ranged attack with an equipped crossbow and its proficiency."},
  [7918] = {"Ataca a distancia con un arma de fuego equipada y su competencia.", "Ranged attack with an equipped gun and its proficiency."},
  [2764] = {"Ataca a distancia con un arma arrojadiza equipada y su competencia.", "Ranged attack with an equipped thrown weapon and its proficiency."},
  [196] = {"Permite utilizar hachas de una mano.", "Allows one-handed axes."},
  [197] = {"Permite utilizar hachas de dos manos.", "Allows two-handed axes."},
  [198] = {"Permite utilizar mazas de una mano.", "Allows one-handed maces."},
  [199] = {"Permite utilizar mazas de dos manos.", "Allows two-handed maces."},
  [200] = {"Permite utilizar armas de asta.", "Allows polearms."},
  [201] = {"Permite utilizar espadas de una mano.", "Allows one-handed swords."},
  [202] = {"Permite utilizar espadas de dos manos.", "Allows two-handed swords."},
  [227] = {"Permite utilizar bastones.", "Allows staves."},
  [264] = {"Permite utilizar arcos.", "Allows bows."},
  [266] = {"Permite utilizar armas de fuego.", "Allows guns."},
  [1180] = {"Permite utilizar dagas.", "Allows daggers."},
  [2567] = {"Permite utilizar armas arrojadizas.", "Allows thrown weapons."},
  [5011] = {"Permite utilizar ballestas.", "Allows crossbows."},
  [15590] = {"Permite utilizar armas de puño.", "Allows fist weapons."},
  [9078] = {"Competencia para equipar armadura de tela.", "Proficiency with cloth armor."},
  [9077] = {"Competencia para equipar armadura de cuero.", "Proficiency with leather armor."},
  [8737] = {"Competencia para equipar armadura de malla.", "Proficiency with mail armor."},
  [9116] = {"Competencia para equipar escudos.", "Proficiency with shields."},

  [71] = {"Actitud para generar amenaza y mitigar daño.", "Tank stance for threat and mitigation."},
  [72] = {"Interrumpe lanzamientos con el escudo.", "Interrupt casters using a shield."},
  [78] = {"Potencia el siguiente ataque normal; consume ira.", "Spend rage to strengthen the next normal swing."},
  [100] = {"Acércate rápidamente al enemigo y genera ira.", "Close the gap to an enemy and gain rage."},
  [355] = {"Recupera la atención de un enemigo.", "Pull an enemy's attention back to you."},
  [674] = {"Permite equipar un arma en la mano secundaria.", "Unlocks an off-hand weapon."},
  [676] = {"Impide temporalmente que el enemigo use su arma.", "Temporarily deprives an enemy of its weapon."},
  [694] = {"Fuerza temporalmente al objetivo a atacarte.", "Temporarily forces the target to attack you."},
  [750] = {"Permite equipar armadura de placas.", "Unlocks plate armor."},
  [772] = {"Aplica daño de sangrado a lo largo del tiempo.", "Applies a damaging bleed."},
  [845] = {"Potencia el siguiente golpe para alcanzar a dos enemigos.", "Enhances the next swing to hit two enemies."},
  [871] = {"Reduce fuertemente el daño recibido durante una emergencia.", "Major emergency damage mitigation."},
  [1160] = {"Debilita el poder de ataque cuerpo a cuerpo de enemigos cercanos.", "Weakens nearby enemies' melee attack power."},
  [1161] = {"Atrae temporalmente la atención de varios enemigos cercanos.", "Temporarily draws nearby enemies' attention."},
  [1680] = {"Ataca a varios enemigos alrededor del guerrero.", "Strike multiple surrounding enemies."},
  [1715] = {"Ralentiza al objetivo para dificultar su huida.", "Slow a target to hinder its escape."},
  [1719] = {"Potencia temporalmente los críticos a cambio de recibir más daño.", "Temporary critical-hit boost with increased damage taken."},
  [2457] = {"Actitud de combate general.", "General-purpose combat stance."},
  [2458] = {"Actitud ofensiva con más críticos y mayor daño recibido.", "Offensive stance with more critical hits and damage taken."},
  [2565] = {"Refuerza temporalmente el bloqueo con escudo.", "Temporarily strengthens shield blocking."},
  [2687] = {"Genera ira a cambio de salud.", "Trade health for rage."},
  [3127] = {"Permite parar ataques cuerpo a cuerpo.", "Enables melee parries."},
  [5246] = {"Provoca miedo para controlar enemigos cercanos.", "Control nearby enemies through fear."},
  [5308] = {"Remata enemigos con poca salud utilizando ira.", "Spend rage to finish low-health enemies."},
  [6343] = {"Daña y ralentiza los ataques de enemigos cercanos.", "Damage nearby enemies and slow their attacks."},
  [6552] = {"Interrumpe el lanzamiento enemigo.", "Interrupt an enemy cast."},
  [6572] = {"Contraataque tras bloquear, esquivar o parar; útil para generar amenaza.", "Threat-building counterattack after a block, dodge or parry."},
  [6673] = {"Refuerza el poder de ataque cuerpo a cuerpo de los aliados.", "Boost allies' melee attack power."},
  [7384] = {"Contraataque disponible cuando el enemigo esquiva.", "Counterattack available after an enemy dodge."},
  [7386] = {"Reduce la armadura enemiga y ayuda a generar amenaza.", "Lower enemy armor and build threat."},
  [12292] = {"Hace que varios ataques alcancen a un enemigo adicional.", "Lets several attacks hit an extra enemy."},
  [12294] = {"Golpe de arma que dificulta la sanación del objetivo.", "Weapon strike that hinders healing on the target."},
  [12323] = {"Ralentiza a los enemigos cercanos.", "Slow surrounding enemies."},
  [12328] = {"Aumenta el daño físico e impide el miedo a cambio de mayor daño recibido.", "Boost physical damage and resist fear at the cost of increased damage taken."},
  [12809] = {"Aturde al objetivo para controlar el combate.", "Stun a target for control."},
  [12975] = {"Aumenta temporalmente la salud máxima como recurso de emergencia.", "Temporary maximum-health boost for emergencies."},
  [18499] = {"Ayuda a resistir miedo e incapacitación y a generar ira al recibir daño.", "Helps resist fear and incapacitation while gaining rage from damage."},
  [20230] = {"Permite responder a ataques cuerpo a cuerpo recibidos.", "Retaliate against incoming melee attacks."},
  [20252] = {"Acércate al objetivo y atúrdelo.", "Close the gap and stun the target."},
  [23881] = {"Ataque ofensivo ligado al poder de ataque; aporta velocidad de movimiento.", "Attack-power-based strike with a movement speed benefit."},
  [23922] = {"Golpea con el escudo y genera mucha amenaza.", "Shield strike that builds substantial threat."},
  [402927] = {"Tras derrotar a un enemigo válido, permite un ataque que también cura.", "After a qualifying kill, enables a strike that also heals."},
  [1240193] = {"Golpe de arma con tiempo de lanzamiento y reutilización.", "Weapon strike with a cast time and cooldown."},
  [1310185] = {"Conserva parte de la ira al cambiar de actitud.", "Retain some rage when switching stances."},
  [1310222] = {"Golpe especialmente útil contra gigantes, dragonantes y objetivos montados.", "Strike especially useful against giants, dragonkin and mounted targets."},
  [1329555] = {"Aumenta la ira generada por los siguientes golpes cuerpo a cuerpo.", "Boost rage from upcoming melee hits."},
}
-- Resúmenes funcionales propios; contrastados con TalentsForever (70755/71139).
local descripcionPaladin = {
  [465] = {"Refuerza la armadura del grupo cercano.", "Boosts nearby party armor."},
  [498] = {"Defensa personal de emergencia; comprueba la Abstinencia.", "Emergency personal defense; check Forbearance."},
  [633] = {"Gran sanación de emergencia con coste importante de maná.", "Major emergency heal with a significant mana cost."},
  [635] = {"Sanación directa de lanzamiento relativamente lento.", "Direct heal with a relatively slow cast."},
  [642] = {"Protección personal temporal frente a ataques; comprueba la Abstinencia.", "Temporary personal protection from attacks; check Forbearance."},
  [679] = {"Ataque de arma que inflige daño Sagrado.", "Weapon attack dealing Holy damage."},
  [750] = {"Permite equipar armaduras de placas.", "Allows plate armor."},
  [853] = {"Aturde al objetivo para controlar el combate.", "Stuns the target for control."},
  [879] = {"Inflige daño Sagrado a objetivos válidos; consulta las restricciones del hechizo.", "Deals Holy damage to eligible targets; check spell restrictions."},
  [1022] = {"Protege temporalmente a un aliado de ataques físicos, con limitaciones de acción.", "Temporarily protects an ally from physical attacks, with action restrictions."},
  [1044] = {"Ayuda a un aliado a librarse de efectos que dificultan el movimiento.", "Helps an ally overcome movement impairments."},
  [1152] = {"Elimina efectos de enfermedad y veneno de un aliado.", "Removes disease and poison effects from an ally."},
  [2812] = {"Daño Sagrado de área contra objetivos válidos.", "Area Holy damage against eligible targets."},
  [2878] = {"Controla temporalmente a un enemigo no-muerto mediante miedo.", "Temporarily controls an undead enemy through fear."},
  [3127] = {"Permite parar ataques cuerpo a cuerpo.", "Enables melee parries."},
  [4987] = {"Disipa efectos de magia, veneno y enfermedad de un aliado.", "Dispels magic, poison and disease effects from an ally."},
  [5502] = {"Permite detectar no-muertos en el minimapa.", "Tracks undead on the minimap."},
  [6940] = {"Transfiere al paladín parte del daño que recibe un aliado.", "Transfers some damage taken by an ally to the paladin."},
  [7294] = {"Inflige daño reactivo a quienes atacan a miembros del grupo afectados.", "Deals reactive damage to attackers of affected party members."},
  [7328] = {"Devuelve a la vida a un aliado fuera de combate.", "Resurrects an ally outside combat."},
  [13819] = {"Invoca la montura de clase de nivel 40.", "Summons the level 40 class mount."},
  [1279399] = {"Invoca la montura de clase de los Renegados de nivel 40.", "Summons the level 40 Forsaken class mount."},
  [23214] = {"Invoca la montura épica de clase de la Alianza.", "Summons the Alliance epic class mount."},
  [1296534] = {"Invoca la montura épica de clase de los Renegados.", "Summons the Forsaken epic class mount."},
  [19740] = {"Refuerza el poder de ataque del beneficiario.", "Increases the recipient's attack power."},
  [19742] = {"Favorece la recuperación de maná del beneficiario.", "Supports the recipient's mana recovery."},
  [19746] = {"Reduce el retroceso de lanzamiento causado por el daño.", "Reduces spell pushback caused by damage."},
  [19750] = {"Sanación directa rápida.", "Fast direct heal."},
  [19752] = {"Sacrifica al paladín para proteger temporalmente a un aliado que no podrá actuar.", "Sacrifices the paladin to temporarily protect an ally who cannot act."},
  [19876] = {"Refuerza la resistencia a las Sombras del grupo cercano.", "Boosts nearby party Shadow resistance."},
  [19888] = {"Refuerza la resistencia a la Escarcha del grupo cercano.", "Boosts nearby party Frost resistance."},
  [19891] = {"Refuerza la resistencia al Fuego del grupo cercano.", "Boosts nearby party Fire resistance."},
  [20154] = {"Añade daño Sagrado a los golpes; su Sentencia inflige daño.", "Adds Holy damage to attacks; its Judgement deals damage."},
  [20164] = {"Ayuda a controlar enemigos y a impedir su huida con la Sentencia.", "Helps control enemies and prevent fleeing through Judgement."},
  [20165] = {"Los ataques pueden sanar; la Sentencia ofrece recuperación de salud.", "Attacks can heal; its Judgement supports health recovery."},
  [20166] = {"Los ataques pueden recuperar maná; la Sentencia ofrece recuperación de maná.", "Attacks can restore mana; its Judgement supports mana recovery."},
  [20217] = {"Aumenta los atributos del beneficiario.", "Increases the recipient's attributes."},
  [20271] = {"Libera el efecto de tu sello sobre el enemigo.", "Releases your seal's effect on the enemy."},
  [20375] = {"Talento de Reprensión que añade daño Sagrado a los ataques y la Sentencia.", "Retribution talent adding Holy damage to attacks and Judgement."},
  [20925] = {"Refuerza el bloqueo y causa daño reactivo al bloquear.", "Improves blocking and deals reactive damage on blocks."},
  [21082] = {"Modifica los ataques de arma y su Sentencia aumenta el daño Sagrado recibido por el objetivo.", "Modifies weapon attacks; its Judgement increases Holy damage taken by the target."},
  [24275] = {"Ataque Sagrado a distancia contra enemigos con poca salud.", "Ranged Holy attack against low-health enemies."},
  [25780] = {"Aumenta la amenaza de tus ataques Sagrados.", "Increases threat from your Holy attacks."},
  [25782] = {"Aplica el beneficio de poderío a aliados de la misma clase del objetivo.", "Applies the Might benefit to allies sharing the target's class."},
  [25894] = {"Aplica el beneficio de sabiduría a aliados de la misma clase del objetivo.", "Applies the Wisdom benefit to allies sharing the target's class."},
  [25898] = {"Aplica el beneficio de reyes a aliados de la misma clase del objetivo.", "Applies the Kings benefit to allies sharing the target's class."},
  [26573] = {"Inflige daño Sagrado periódico en el suelo alrededor del paladín.", "Deals periodic Holy damage in an area around the paladin."},
  [1310911] = {"Apoya la sanación de un aliado y potencia el siguiente Choque sagrado según el rango.", "Supports healing an ally and enhances the next Holy Shock according to rank."},
  [1311606] = {"Sanación instantánea o daño Sagrado, según el objetivo.", "Instant healing or Holy damage, depending on the target."},
  [1311649] = {"Añade daño Sagrado, puede otorgar absorción con escudo y su Sentencia provoca al enemigo.", "Adds Holy damage, can grant absorption with a shield, and its Judgement taunts."},
  [20216] = {"Potencia el siguiente hechizo de sanación válido.", "Empowers the next eligible healing spell."},
  [1328548] = {"Refuerza las sanaciones del paladín sobre un aliado elegido.", "Enhances the paladin's healing on a chosen ally."},
  [1311015] = {"Otorga un escudo de absorción temporal al paladín.", "Grants the paladin a temporary absorb shield."},
  [1310994] = {"Permite liberar la energía de un sello mediante una habilidad de talento.", "Allows releasing a seal's energy through a talent ability."},
  [20066] = {"Incapacita temporalmente a un enemigo válido.", "Temporarily incapacitates an eligible enemy."},
}
-- Resúmenes funcionales propios; no sustituyen los valores exactos del rango.
local descripcionCazador = {
  [75] = {"Dispara automáticamente con el arma a distancia equipada.", "Automatically fires the equipped ranged weapon."},
  [1293712] = {"Consulta las armaduras permitidas; la malla se desbloquea al nivel 40.", "Lists permitted armor types; mail unlocks at level 40."},
  [1494] = {"Muestra las bestias cercanas en el minimapa.", "Tracks nearby beasts on the minimap."},
  [2973] = {"Refuerza un ataque cuerpo a cuerpo con el arma.", "Empowers a melee weapon attack."},
  [1978] = {"Inflige daño de Naturaleza periódico.", "Deals periodic Nature damage."},
  [13163] = {"Mejora la probabilidad de esquivar.", "Improves dodge chance."},
  [1130] = {"Marca al enemigo y potencia los ataques a distancia contra él.", "Marks the enemy and strengthens ranged attacks against it."},
  [3044] = {"Disparo que inflige daño Arcano.", "Ranged attack dealing Arcane damage."},
  [3127] = {"Permite parar ataques cuerpo a cuerpo.", "Enables melee parries."},
  [5116] = {"Ralentiza al enemigo a distancia.", "Slows the enemy at range."},
  [883] = {"Llama a la mascota activa.", "Calls your active pet."},
  [982] = {"Devuelve a la vida a tu mascota.", "Resurrects your pet."},
  [1515] = {"Domestica una bestia válida para convertirla en mascota.", "Tames an eligible beast as your pet."},
  [2641] = {"Retira temporalmente a la mascota.", "Temporarily dismisses your pet."},
  [4187] = {"Aumenta el aguante de la mascota.", "Increases pet stamina."},
  [5149] = {"Permite enseñar a la mascota habilidades conocidas por el cazador.", "Teaches your pet skills known by the hunter."},
  [6991] = {"Da alimento compatible para recuperar felicidad.", "Feeds compatible food to restore happiness."},
  [13165] = {"Refuerza la capacidad ofensiva a distancia.", "Boosts ranged offense."},
  [19883] = {"Muestra humanoides cercanos en el minimapa.", "Tracks nearby humanoids on the minimap."},
  [24545] = {"Aumenta la armadura de la mascota.", "Increases pet armor."},
  [136] = {"Recupera salud de la mascota durante un periodo.", "Restores pet health over time."},
  [2974] = {"Ataque cuerpo a cuerpo que ralentiza.", "Melee attack that slows movement."},
  [20736] = {"Genera amenaza para atraer la atención del objetivo.", "Generates threat to draw the target's attention."},
  [1002] = {"Permite controlar temporalmente a tu mascota.", "Temporarily lets you control your pet."},
  [1513] = {"Hace huir a una bestia válida.", "Fears an eligible beast."},
  [6197] = {"Permite observar un lugar distante.", "Lets you view a distant location."},
  [1495] = {"Ataque cuerpo a cuerpo; consulta sus condiciones de activación.", "Melee attack; check its activation conditions."},
  [13795] = {"Coloca una trampa que aplica daño de Fuego periódico.", "Places a trap dealing periodic Fire damage."},
  [2643] = {"Dispara contra varios objetivos.", "Fires at multiple targets."},
  [19884] = {"Muestra no-muertos cercanos en el minimapa.", "Tracks nearby undead on the minimap."},
  [674] = {"Permite equipar un arma válida en cada mano.", "Enables an eligible weapon in each hand."},
  [781] = {"Reduce la amenaza frente al enemigo.", "Reduces threat against the enemy."},
  [1499] = {"Incapacita temporalmente al enemigo que activa la trampa.", "Temporarily incapacitates an enemy triggering the trap."},
  [5118] = {"Aumenta la velocidad de movimiento personal; comprueba sus penalizaciones.", "Increases personal movement speed; check its penalties."},
  [14917] = {"Genera amenaza de la mascota para atraer enemigos.", "Generates pet threat to draw enemies."},
  [19263] = {"Mejora temporalmente la defensa frente a ataques.", "Temporarily improves defense against attacks."},
  [19434] = {"Disparo potente con tiempo de lanzamiento.", "Powerful ranged attack with a cast time."},
  [23992] = {"Mejora la resistencia al Fuego de la mascota.", "Improves pet Fire resistance."},
  [24446] = {"Mejora la resistencia a la Escarcha de la mascota.", "Improves pet Frost resistance."},
  [24488] = {"Mejora la resistencia a las Sombras de la mascota.", "Improves pet Shadow resistance."},
  [24492] = {"Mejora la resistencia a la Naturaleza de la mascota.", "Improves pet Nature resistance."},
  [24493] = {"Mejora la resistencia Arcana de la mascota.", "Improves pet Arcane resistance."},
  [3043] = {"Debilita al objetivo con una picadura.", "Weakens the target with a sting."},
  [1462] = {"Consulta información sobre una bestia seleccionada.", "Inspects information about a selected beast."},
  [19885] = {"Facilita la detección de enemigos ocultos.", "Helps detect hidden enemies."},
  [19306] = {"Ataque reactivo cuerpo a cuerpo que dificulta el movimiento del enemigo.", "Reactive melee attack that impairs enemy movement."},
  [1293241] = {"Invoca un halcón auxiliar de combate.", "Summons a combat-assisting hawk."},
  [1299346] = {"Refuerza el poder de ataque de los aliados afectados.", "Boosts affected allies' attack power."},
  [3045] = {"Aumenta temporalmente la velocidad de ataque a distancia.", "Temporarily increases ranged attack speed."},
  [19880] = {"Muestra elementales cercanos en el minimapa.", "Tracks nearby elementals on the minimap."},
  [13809] = {"Crea una zona que ralentiza a los enemigos.", "Creates an area that slows enemies."},
  [5384] = {"Simula la muerte para intentar salir del combate.", "Feigns death to attempt to leave combat."},
  [13161] = {"Adopta un aspecto de combate cuerpo a cuerpo; los rangos superiores aumentan el poder de ataque cuerpo a cuerpo.", "Adopts a melee combat aspect; higher ranks increase melee attack power."},
  [19503] = {"Desorienta brevemente al enemigo.", "Briefly disorients the enemy."},
  [19577] = {"Ordena a la mascota aturdir al enemigo con un ataque.", "Commands the pet to stun the enemy with an attack."},
  [24118] = {"Aplica una herida de daño periódico; obtención pendiente de verificar.", "Applies a periodic-damage wound; acquisition remains unverified."},
  [1317257] = {"Patada de arma cuerpo a cuerpo que aumenta brevemente la velocidad de movimiento.", "Melee weapon kick that briefly increases movement speed."},
  [1543] = {"Revela enemigos ocultos en el área.", "Reveals hidden enemies in the area."},
  [19878] = {"Muestra demonios cercanos en el minimapa.", "Tracks nearby demons on the minimap."},
  [13813] = {"Coloca una trampa que inflige daño de Fuego en área.", "Places a trap dealing area Fire damage."},
  [3034] = {"Reduce el maná del enemigo durante un periodo.", "Drains enemy mana over time."},
  [1510] = {"Ataque a distancia canalizado contra una zona.", "Channeled ranged attack against an area."},
  [8737] = {"Permite equipar armaduras de malla.", "Allows mail armor."},
  [13159] = {"Aumenta la velocidad de movimiento del grupo afectado; consulta sus penalizaciones.", "Increases affected party movement speed; check its penalties."},
  [19574] = {"Potencia temporalmente el combate de la mascota.", "Temporarily empowers pet combat."},
  [19882] = {"Muestra gigantes cercanos en el minimapa.", "Tracks nearby giants on the minimap."},
  [1310687] = {"Disparo potente desbloqueado por Puntería.", "Powerful shot unlocked through Marksmanship."},
  [20043] = {"Mejora la resistencia a la Naturaleza de los aliados afectados.", "Improves affected allies' Nature resistance."},
  [19879] = {"Muestra dragonantes cercanos en el minimapa.", "Tracks nearby dragonkin on the minimap."},
  [19801] = {"Elimina efectos de enfurecimiento válidos del enemigo.", "Removes eligible enrage effects from the enemy."},
}
local function IdiomaCoincide()
  local locale = GetLocale and GetLocale()
  return (GL.ingles and (locale == "enUS" or locale == "enGB")) or
    (not GL.ingles and (locale == "esES" or locale == "esMX"))
end
local function ResumenHechizo(id)
  local clase = GL.RUTA and GL.RUTA.clase
  local datos = clase == "WARRIOR" and descripcionGuerrero or clase == "PALADIN" and descripcionPaladin or clase == "HUNTER" and descripcionCazador or clase == "ROGUE" and descripcionPicaroInicial or clase == "PRIEST" and descripcionSacerdote or clase == "SHAMAN" and descripcionChaman or clase == "MAGE" and descripcionMago or clase == "WARLOCK" and descripcionBrujo or clase == "DRUID" and descripcionDruida
  local raiz = raizPorId[id] or id
  local par = datos and datos[raiz] or nil
  if (clase=="MAGE" or clase=="WARLOCK") and raiz==5009 then par={"Permite equipar varitas.","Allows equipping wands."} elseif (clase=="MAGE" or clase=="WARLOCK") and raiz==5019 then par={"Ataca con una varita equipada sin gastar maná.","Attacks with an equipped wand without spending Mana."} end
  if clase=="WARLOCK" and raiz==1293712 then par={"Permite consultar la competencia de armadura: solo tela.","Lists armor proficiency: cloth only."} end
  if clase=="DRUID" then
    if raiz==1293712 then par={"Permite consultar la competencia de armaduras: tela y cuero.","Lists armor proficiencies: cloth and leather."}
    elseif raiz==200 then par={"Permite usar armas de asta desde el nivel 20 con un maestro de armas.","Allows polearms from level 20 via a weapon master."}
    elseif raiz==6603 then par={"Ataque normal. Gato y oso escalan con el arma equipada y tienen su propia habilidad de Combate feral.","Normal attack. Cat and Bear scale with the equipped weapon and have their own Feral Combat skill."} end
  end
  if not par and ((clase == "PALADIN" and generalPaladinPorId[raiz]) or (clase == "HUNTER" and generalCazadorPorId[raiz]) or (clase == "ROGUE" and generalPicaroPorId[raiz]) or (clase == "PRIEST" and generalSacerdotePorId[raiz]) or (clase == "SHAMAN" and generalChamanPorId[raiz]) or (clase=="MAGE" and generalMagoPorId[raiz]) or (clase=="WARLOCK" and generalBrujoPorId[raiz]) or (clase=="DRUID" and generalDruidaPorId[raiz])) then
    par = descripcionGuerrero[raiz]
  end
  return par and par[GL.ingles and 2 or 1]
end

-- En otro idioma no mezclar el tooltip nativo con un título traducido.
-- En el idioma del cliente conservar el tooltip exacto del rango.
local function MostrarTooltipHechizo(self)
  if not (GameTooltip and self.idHechizo) then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local resumen = ResumenHechizo(self.idHechizo)
  local nativo = not resumen or IdiomaCoincide()
  local ok = nativo and GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, self.idHechizo)
  if not ok then GameTooltip:SetText(self.nombre or "", 1, 0.82, 0) end
  if not resumen and not IdiomaCoincide() then
    GameTooltip:AddLine(L"Descripción disponible únicamente en el idioma del cliente.", 0.7, 0.7, 0.7, true)
  end
  if resumen then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine((GL.ingles and "Guide summary: " or "Resumen de la guía: ") .. resumen, 1, 1, 1, true)
    if not ok then
      GameTooltip:AddLine(GL.ingles and "Exact rank values: see the game's spellbook." or "Valores exactos del rango: consulta el libro de hechizos del juego.", 0.7, 0.7, 0.7, true)
    end
  end
  if self.rangos then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L"Rangos (nivel y precio): " .. self.rangos, 1, 1, 1, true)
  end
  GameTooltip:Show()
end


local function Armar()
  grupos = {}
  raizPorId = {}
  rutaGrupos = GL.RUTA
  local R = GL.RUTA
  if not R then return end
  local todas, porId = {}, {}
  for _, e in ipairs(GL.EntrenamientoAuditado and GL.EntrenamientoAuditado(R) or R.entrenamiento or {}) do
    local f = { id = e.id, n = e.n, coste = e.coste or 0, req = e.req, ant = e.ant, origen = "instructor",
      donde = GL.DondeHechizo and GL.DondeHechizo(e.id), hab = e.hab }
    table.insert(todas, f)
    porId[e.id] = f
  end
  for _, e in ipairs(GL.ExtrasAuditados and GL.ExtrasAuditados(R) or R.hechizosExtra or {}) do
    if not porId[e.id] then
      local f = { id = e.id, n = e.n, coste = 0, req = e.req, ant = e.ant, origen = e.origen, plan = e.plan,
        mision = e.mision, misionNombre = e.misionNombre }
      table.insert(todas, f)
      porId[e.id] = f
    end
  end
  if R.clase == "WARRIOR" then
    for _, e in ipairs(generalesGuerrero) do
      if not porId[e.id] then
        local f = { id = e.id, n = e.n, coste = 0, origen = e.origen, ant = 0, ramaAuditada = "General" }
        table.insert(todas, f)
        porId[e.id] = f
      end
    end
    for _, e in ipairs(talentosGuerrero) do
      if not porId[e.id] then
        local f = { id = e.id, n = e.n, coste = 0, origen = "talento", ant = 0, ramaAuditada = L(e.rama) }
        table.insert(todas, f)
        porId[e.id] = f
      end
    end
  end
  if R.clase == "PALADIN" then
    for _, e in ipairs(generalesPaladin) do
      if not porId[e.id] then
        local f = { id = e.id, n = e.n, coste = 0, origen = e.origen, ant = 0, ramaAuditada = L"General" }
        table.insert(todas, f)
        porId[e.id] = f
      end
    end
    -- IDs de invocación, no los hechizos internos que enseñan la montura.
    local monturas = R.id == "nomuerto_paladin" and {
      {id=1279399,n=40,mision=94971,es="El corcel de un paladín",en="A Paladin's Steed"},
      {id=1296534,n=60,mision=97185,es="Justicia y retribución",en="Justice and Retribution"},
    } or (R.id == "humano_paladin" or R.id == "enano_paladin") and {
      {id=13819,n=40,mision=1661,es="Libro de la nobleza",en="The Tome of Nobility"},
      {id=23214,n=60,mision=7647,es="Juzgar y redimir",en="Judgment and Redemption"},
    } or {}
    for _, e in ipairs(monturas) do
      local f=porId[e.id]
      if not f then f={id=e.id}; todas[#todas+1]=f; porId[e.id]=f end
      f.n,f.coste,f.origen,f.ant,f.mision=e.n,0,"mision",0,e.mision
      f.req,f.hab,f.donde=nil,nil,nil
      f.misionNombre,f.misionNombreEN=e.es,e.en
      f.ramaAuditada=L"General"
      f.montura=true
    end
    for _, e in ipairs(talentosPaladin) do
      local f = porId[e.id]
      if not f then
        f = { id = e.id }
        table.insert(todas, f)
        porId[e.id] = f
      end
      f.n, f.coste, f.origen, f.ant = e.n, 0, "talento", 0
      f.req, f.plan, f.donde = nil, nil, nil
      f.ramaAuditada = L(e.rama)
    end
  end
  if R.clase == "HUNTER" then
    for _, e in ipairs(generalesCazador) do
      if not porId[e.id] then
        local f={id=e.id,n=e.n,coste=0,origen=e.origen,ant=0,ramaAuditada="General"}
        table.insert(todas,f); porId[e.id]=f
      end
    end
    -- Las tres facultades de doma se obtienen en la tercera prueba; las otras tres en el entrenamiento final.
    -- No alterar hechizosExtra de la ruta ni inferir aprendizaje por el estado de una misión.
    local doma, entreno
    if GL.MisionesDomaCazador then doma,entreno=GL.MisionesDomaCazador(R) end
    if doma and entreno then
      for _, id in ipairs({1515,883,2641,5149,6991,982}) do
        local f=porId[id]
        if f then
          local primera=id==1515 or id==883 or id==2641
          f.mision=primera and doma or entreno
          f.misionNombre=primera and "Domesticar la bestia" or "Entrenar a la bestia"
          f.misionNombreEN=primera and "Taming the Beast" or "Training the Beast"
        end
      end
    end
    for _, e in ipairs(talentosCazador) do
      local f = porId[e.id]
      if not f then
        f = { id=e.id }; table.insert(todas, f); porId[e.id] = f
      end
      f.n, f.coste, f.origen, f.ant = e.n, 0, "talento", 0
      f.req, f.plan, f.donde, f.hab = nil, nil, nil, nil
      f.ramaAuditada = L(e.rama)
    end
    -- Disparo apuntado es de instructor al 20, no un talento de Puntería.
    local f = porId[19434]
    if f then f.ramaAuditada = L"Puntería" end
  end
  if R.clase == "ROGUE" then
    for _, e in ipairs(generalesPicaro) do
      if not porId[e.id] then
        local f={id=e.id,n=e.n,coste=0,origen=e.origen,ant=0,ramaAuditada=L"General"}
        table.insert(todas,f); porId[e.id]=f
      end
    end
    -- Redirect (438040) está en el cliente, sin oferta de instructor acreditada.
    if not porId[438040] then
      local f={id=438040,n=1,coste=0,origen="pendiente",ant=0,ramaAuditada=L"General"}
      table.insert(todas,f); porId[f.id]=f
    end
    for _, e in ipairs(venenosPicaroPendientes) do
      if not porId[e.id] then
        local f={id=e.id,n=e.n,ant=e.ant,coste=0,origen="pendiente",ramaAuditada=L"Asesinato"}
        table.insert(todas,f);porId[e.id]=f
      end
    end
    -- Los dos desbloqueos de venenos ya existen en las rutas; añadir título EN sin alterar su origen.
    for _, id in ipairs({2842,8681}) do
      local f=porId[id]
      if f and f.origen=="mision" then
        if f.mision==2359 then f.misionNombreEN="Klaven's Tower"
        elseif f.mision==2480 then f.misionNombreEN="Hinott's Assistance" end
      end
    end
    for _, e in ipairs(talentosPicaro) do
      local f = porId[e.id]
      if not f then f={id=e.id}; table.insert(todas,f); porId[e.id]=f end
      f.n,f.coste,f.origen,f.ant=e.n,0,"talento",0
      f.req,f.plan,f.donde,f.hab=nil,nil,nil,nil
      f.ramaAuditada=L(e.rama)
    end
    if porId[1328825] then porId[1328825].ramaAuditada=L"Sutileza" end
    if porId[1329283] then porId[1329283].ramaAuditada=L"Combate" end
  end
  if R.clase == "PRIEST" then
    for _,e in ipairs(generalesSacerdote) do
      if not porId[e.id] then
        local f={id=e.id,n=e.n,coste=0,origen=e.origen,ant=0,ramaAuditada=L"General"}
        table.insert(todas,f);porId[e.id]=f
      end
    end
    -- Los IDs de misión de la ruta se conservan; el nombre de recompensa es el vigente de Forever.
    local raciales = {
      [1277370]={"Sagrado","Gracia divina","Divine Grace"},
      [13896]={"Disciplina","La reacción arcana","Arcane Feedback"},
      [13908]={"Sagrado","Oración desesperada","Desperate Prayer"},
      [1277331]={"Sagrado","Castigo","Chastise"},
      [10797]={"Disciplina","Estrellas de Elune","Stars of Elune"},
      [2651]={"Disciplina","La gracia de Elune","Elune's Grace"},
      [1277455]={"Disciplina","Destello desconcertante","Confounding Flash"},
      [1277462]={"Disciplina","Plan de contingencia","Contingency Plan"},
      [2652]={"Sombra","Toque de debilidad","Touch of Weakness"},
      [1277324]={"Sombra","Sacrificio oscuro","Dark Sacrifice"},
      [9035]={"Sombra","Maleficio de debilidad","Hex of Weakness"},
      [18137]={"Sombra","Guardia de las Sombras","Shadowguard"},
    }
    for id, datos in pairs(raciales) do
      local f=porId[id]
      if f then f.ramaAuditada=L(datos[1]); f.misionNombre=datos[2]; f.misionNombreEN=datos[3] end
    end
    for _, e in ipairs(talentosSacerdote) do
      local f=porId[e.id]
      if not f then f={id=e.id}; table.insert(todas,f);porId[e.id]=f end
      f.n,f.coste,f.origen,f.ant=e.n,0,"talento",0
      f.req,f.plan,f.donde,f.hab=nil,nil,nil,nil
      f.ramaAuditada=L(e.rama)
    end
  end
  if R.clase == "SHAMAN" then
    local raza=GL.Raza and GL.Raza()
    for _,e in ipairs(generalesChaman) do
      if not porId[e.id] then
        local origen=e.origen
        if raza=="Skyborne" and (e.id==199 or e.id==1180) then origen="general" end
        local f={id=e.id,n=e.n,origen=origen,coste=0,ant=0,ramaAuditada=L"General"}
        table.insert(todas,f);porId[e.id]=f
      end
    end
    if not porId[674] then
      local f={id=674,origen="pendiente",coste=0,ant=0,ramaAuditada=L"General"}
      table.insert(todas,f);porId[f.id]=f
    end
    if R.id=="skyborne_chaman" and porId[8071] then porId[8071].n=3 end
    for _,id in ipairs({66843,66844}) do
      local f=porId[id]
      if f then f.ant=0; f.ramaAuditada=L"General" end
    end
    for _,e in ipairs(talentosChaman) do
      local f=porId[e.id]
      if not f then f={id=e.id}; table.insert(todas,f); porId[e.id]=f end
      f.n,f.coste,f.origen,f.ant=e.n,0,"talento",0
      f.req,f.plan,f.donde,f.hab=nil,nil,nil,nil
      f.ramaAuditada=L(e.rama)
    end
  end
  if R.clase == "MAGE" then
    -- Study is the quest reward; Research was explicitly retired by Blizzard on 6 Nov.
    if not porId[1302508] then
      local f={id=1302508,n=6,ant=0,req={1296017},origen="mision",coste=0,mision=97286,
        misionNombre="Acceso a la investigación",misionNombreEN="Research Access",ramaAuditada=L"General"}
      table.insert(todas,f);porId[f.id]=f
    end
    for _,e in ipairs(generalesMago) do
      if not porId[e.id] then
        local origen=e.origen
        if e.id==1180 and R.id=="skyborne_a_mago" then origen="general" end
        local f={id=e.id,n=e.n,origen=origen,coste=0,ant=0,ramaAuditada=L"General"}
        table.insert(todas,f);porId[e.id]=f
      end
    end
    if porId[10140] then porId[10140].misionNombreEN="Arcane Refreshment" end
    if porId[28272] then
      porId[28272].ant=0; porId[28272].misionNombreEN="Fragmented Magic"
    end
    for _,e in ipairs(talentosMago) do
      local f=porId[e.id]
      if not f then f={id=e.id}; table.insert(todas,f); porId[e.id]=f end
      f.n,f.coste,f.origen,f.ant=e.n,0,"talento",0
      f.req,f.plan,f.donde,f.hab=nil,nil,nil,nil
      f.ramaAuditada=L(e.rama)
    end
  end
  if R.clase == "WARLOCK" then
    for _,e in ipairs(generalesBrujo) do
      if not porId[e.id] then
        local f={id=e.id,n=e.n,origen=e.origen,coste=0,ant=0,ramaAuditada=L"General"}
        table.insert(todas,f);porId[e.id]=f
      end
    end
    local lado=R.id=="gnomo_brujo" or R.id=="humano_brujo"
    local noMuerto=R.id=="nomuerto_brujo"
    for _,e in ipairs({{5784,40,4490,"Invoca un malignoecus","Summon Felsteed"},{23161,60,7631,"Terrorecus de Xoroth","Dreadsteed of Xoroth"}}) do
      local f=porId[e[1]]
      if not f then f={id=e[1]};todas[#todas+1]=f;porId[f.id]=f end
      f.n,f.coste,f.origen,f.ant,f.mision=e[2],0,"mision",0,e[3]
      f.misionNombre,f.misionNombreEN=e[4],e[5]
      f.req,f.hab,f.donde=nil,nil,nil
      f.ramaAuditada=L"General";f.montura=true
    end
    if porId[688] then porId[688].n=1 end
    if noMuerto and porId[712] then porId[712].mision=1474 end
    local f={id=713,n=20,ant=0,coste=0,origen="mision",mision=lado and 65603 or noMuerto and 65597 or 65604,misionNombre="El vínculo (íncubo)",misionNombreEN="The Binding (Incubus)"}
    if not porId[713] then table.insert(todas,f);porId[713]=f end
    for _,e in ipairs(talentosBrujo) do
      local f=porId[e.id]
      if not f then f={id=e.id}; table.insert(todas,f); porId[e.id]=f end
      f.n,f.coste,f.origen,f.ant=e.n,0,"talento",0
      f.req,f.plan,f.donde,f.hab=nil,nil,nil,nil
      f.ramaAuditada=L(e.rama)
    end
  end
  if R.clase == "DRUID" then
    for _,e in ipairs(generalesDruida) do
      if not porId[e.id] then
        local origen=e.origen
        if (R.id=="elfo_druida" and e.id==1180) or (R.id=="tauren_druida" and e.id==198) then origen="general" end
        local f={id=e.id,n=e.n,origen=origen,coste=0,ant=0,ramaAuditada=L"General"}
        todas[#todas+1]=f;porId[e.id]=f
      end
    end
    for _,id in ipairs({1082,1079,5215,1328829,6795}) do
      if porId[id] then porId[id].ramaAuditada=L"Combate feral" end
    end
    for _,id in ipairs({437138,1126}) do
      if porId[id] then porId[id].ramaAuditada=L"Restauración" end
    end
    for _,e in ipairs(talentosDruida) do
      local f=porId[e.id]
      if not f then f={id=e.id};todas[#todas+1]=f;porId[e.id]=f end
      f.n,f.coste,f.origen,f.ant=e.n,0,"talento",0
      f.req,f.plan,f.donde,f.hab=nil,nil,nil,nil
      f.ramaAuditada=L(e.rama)
    end
  end
  -- Rangos de manual documentados; disponibilidad y precio de mercado pendientes.
  for _, e in ipairs(GL.RangosAuditadosPendientes and GL.RangosAuditadosPendientes() or
    (GL.RangosGuerreroPendientes and GL.RangosGuerreroPendientes() or {})) do
    if not porId[e.id] then
      local f = { id = e.id, n = e.n, ant = e.ant, coste = 0, origen = "pendiente", libro = e.libro, libroNivel = e.libroNivel, hab = e.hab }
      if e.rama then f.ramaAuditada = L(e.rama) end
      table.insert(todas, f)
      porId[e.id] = f
    end
  end
  indice = porId
  -- lo que pide además del rango anterior (una actitud, por ejemplo): solo se sabe si la ruta trae ant
  for _, f in ipairs(todas) do
    if f.ant ~= nil and f.req then
      for _, r in ipairs(f.req) do
        if r ~= f.ant then f.necesita = f.necesita or {}; table.insert(f.necesita, r) end
      end
    end
  end
  -- el rango anterior: ant si la ruta lo trae (0 = primer rango; así una actitud que se pide no cuenta como
  -- rango) y si no, el requisito que también está en la lista (el otro, si lo hay, es un talento)
  local function Previo(f)
    if f.ant ~= nil then
      if f.ant == 0 then return nil end
      local p = porId[f.ant]
      if p and p ~= f then return p end
      return nil
    end
    for _, r in ipairs(f.req or {}) do
      if porId[r] and porId[r] ~= f then return porId[r] end
    end
    return nil
  end
  local function Profundidad(f)
    if f.prof then return f.prof end
    local p, n = Previo(f), 0
    while p and n < 40 do n = n + 1; p = Previo(p) end
    f.prof = n
    return n
  end
  local porRaiz = {}
  for _, f in ipairs(todas) do
    local r, n = f, 0
    while Previo(r) and n < 40 do r = Previo(r); n = n + 1 end
    local g = porRaiz[r.id]
    if not g then
      local ramas = r.ramaAuditada or (R.ramaHechizo and R.ramaHechizo[r.id])
      if type(ramas) == "string" then ramas = { ramas } end
      g = { raiz = r.id, rangos = {}, ramas = ramas or {} }
      porRaiz[r.id] = g
      table.insert(grupos, g)
    end
    raizPorId[f.id] = r.id
    table.insert(g.rangos, f)
  end
  for _, g in ipairs(grupos) do
    table.sort(g.rangos, function(a, b)
      local pa, pb = Profundidad(a), Profundidad(b)
      if pa ~= pb then return pa < pb end
      return a.id < b.id
    end)
    for _, f in ipairs(g.rangos) do
      if f.n and (not g.orden or f.n < g.orden) then g.orden = f.n end
    end
    g.orden = g.orden or 60
  end
  table.sort(grupos, function(a, b)
    if a.orden ~= b.orden then return a.orden < b.orden end
    return a.raiz < b.raiz
  end)
end

local function Nombre(id)
  local n = GL.NombreHechizo and GL.NombreHechizo(id)
  if GL.RUTA and GL.RUTA.clase=="HUNTER" and GL.NombreRangoMascota then
    local nombre=GL.NombreRangoMascota(id)
    if nombre then return nombre end
  end
  if GL.RUTA and GL.RUTA.clase == "WARRIOR" then
    local par = nombresGuerrero[raizPorId[id] or id]
    local locale = GetLocale and GetLocale()
    local mismo = (GL.ingles and (locale == "enUS" or locale == "enGB")) or
      (not GL.ingles and (locale == "esES" or locale == "esMX"))
    if mismo and n then return n end
    if par then return par[GL.ingles and 2 or 1] end
  end
  if GL.RUTA and GL.RUTA.clase == "PALADIN" then
    local raiz = raizPorId[id] or id
    local par = nombresRangosPaladin[raiz] or (generalPaladinPorId[raiz] and nombresGuerrero[raiz])
    if par then
      if IdiomaCoincide() and n then return n end
      return par[GL.ingles and 2 or 1]
    end
    local e = talentosPaladinPorId[raiz]
    if e then
      if IdiomaCoincide() and n then return n end
      return GL.ingles and e.en or e.es
    end
  end
  if GL.RUTA and GL.RUTA.clase == "HUNTER" then
    local raiz = raizPorId[id] or id
    local par = nombresRangosCazador[raiz] or (generalCazadorPorId[raiz] and nombresGuerrero[raiz])
    if raiz == 75 then par = {"Disparo automático", "Auto Shot"} end
    if par then
      if IdiomaCoincide() and n then return n end
      return par[GL.ingles and 2 or 1]
    end
    local e = talentosCazadorPorId[raiz]
    if e then
      if IdiomaCoincide() and n then return n end
      return GL.ingles and e.en or e.es
    elseif raiz == 19434 then
      if IdiomaCoincide() and n then return n end
      return GL.ingles and "Aimed Shot" or "Disparo de puntería"
    end
  end
  if GL.RUTA and GL.RUTA.clase == "ROGUE" then
    local raiz=raizPorId[id] or id
    local e=talentosPicaroPorId[raiz]
    local par=nombresPicaroInicial[raiz] or (generalPicaroPorId[raiz] and nombresGuerrero[raiz])
    if e or par then
      if IdiomaCoincide() and n then return n end
      if e then return GL.ingles and e.en or e.es end
      return par[GL.ingles and 2 or 1]
    end
  end
  if GL.RUTA and GL.RUTA.clase == "PRIEST" then
    local raiz=raizPorId[id] or id
    local e=talentosSacerdotePorId[raiz]
    local par=nombresSacerdoteInicial[raiz] or (generalSacerdotePorId[raiz] and nombresGuerrero[raiz])
    if e or par then
      if IdiomaCoincide() and n then return n end
      if e then return GL.ingles and e.en or e.es end
      return par[GL.ingles and 2 or 1]
    end
  end
  if GL.RUTA and GL.RUTA.clase == "SHAMAN" then
    local raiz=raizPorId[id] or id
    local e=talentosChamanPorId[raiz]
    local par=nombresChaman[raiz] or (generalChamanPorId[raiz] and nombresGuerrero[raiz])
    if e or par then
      if IdiomaCoincide() and n then return n end
      if e then return GL.ingles and e.en or e.es end
      return par[GL.ingles and 2 or 1]
    end
  end
  if GL.RUTA and GL.RUTA.clase == "MAGE" then
    local raiz=raizPorId[id] or id
    local e=talentosMagoPorId[raiz]
    local par=nombresMago[raiz] or (generalMagoPorId[raiz] and nombresGuerrero[raiz])
    if raiz==5009 then par={"Varitas","Wands"} elseif raiz==5019 then par={"Disparar","Shoot"} end
    if e or par then
      if IdiomaCoincide() and n then return n end
      if e then return GL.ingles and e.en or e.es end
      return par[GL.ingles and 2 or 1]
    end
  end
  if GL.RUTA and GL.RUTA.clase == "WARLOCK" then
    local raiz=raizPorId[id] or id
    local e=talentosBrujoPorId[raiz]
    local par=nombresBrujo[raiz] or (generalBrujoPorId[raiz] and nombresGuerrero[raiz])
    if raiz==5009 then par={"Varitas","Wands"} elseif raiz==5019 then par={"Disparar","Shoot"} end
    if e or par then
      if IdiomaCoincide() and n then return n end
      if e then return GL.ingles and e.en or e.es end
      return par[GL.ingles and 2 or 1]
    end
  end
  if GL.RUTA and GL.RUTA.clase == "DRUID" then
    local raiz=raizPorId[id] or id
    local e=talentosDruidaPorId[raiz]
    local par=nombresDruida[raiz] or (generalDruidaPorId[raiz] and nombresGuerrero[raiz])
    if e or par then
      if IdiomaCoincide() and n then return n end
      if e then return GL.ingles and e.en or e.es end
      return par[GL.ingles and 2 or 1]
    end
  end
  if n then
    -- Sin nombre auditado, conservar el nombre real e indicar su procedencia.
    if not IdiomaCoincide() then return n .. " (" .. L"idioma del cliente" .. ")" end
    return n
  end
  if C_Spell and C_Spell.RequestLoadSpellData and not pedidos[id] then
    pedidos[id] = true
    pcall(C_Spell.RequestLoadSpellData, id)
  end
  return L"Hechizo " .. id
end

local function Icono(id)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, id)
    if ok and t then return t end
  end
  return nil
end

local function Dinero(cobre)
  if GL.Dinero then return GL.Dinero(cobre) end
  return string.format("%.2f o", (cobre or 0) / 10000)
end

-- Lo que pide el primer rango y aún no tienes (la actitud de una misión de clase, por ejemplo).
local function Falta(f)
  for _, r in ipairs(f.necesita or {}) do
    if not (GL.HechizoORangoConocido or GL.HechizoConocido)(r) then return true end
  end
  return false
end

-- true si tienes el nivel de habilidad que pide el rango (los venenos piden un nivel de Venenos).
local function HabilidadLista(f)
  if not f.hab then return true end
  local n = GL.NivelHabilidad and GL.NivelHabilidad(f.hab[1])
  return n ~= nil and n >= (f.hab[2] or 0)
end

-- Estado de cada rango para tu nivel: aprendido, disponible, futuro o bloqueado (falta el talento que lo enseña,
-- lo que pide el primer rango o el nivel de habilidad).
-- Forever puede guardar la montura en Colecciones en lugar del libro de hechizos.
-- Solo se acepta el ID de invocación exacto y la marca de colección, no el nombre.
local function MonturaConocida(f)
  if not f.montura or not C_MountJournal or not C_MountJournal.GetMountFromSpell or not C_MountJournal.GetMountInfoByID then return false end
  local ok, mid = pcall(C_MountJournal.GetMountFromSpell, f.id)
  if not ok or not mid or mid == 0 then return false end
  local datos = {pcall(C_MountJournal.GetMountInfoByID, mid)}
  return datos[1] == true and datos[3] == f.id and datos[12] == true
end
function GL.MonturaConocidaPorHechizo(id)
  return MonturaConocida({id=id,montura=true})
end
-- El paladín tiene cadenas ant auditadas: el nivel por sí solo no habilita el siguiente rango.
-- En el cálculo de coste se conserva la estimación de la cadena, pero no se anuncia como disponible.
local function FaltaRangoPaladin(f)
  return GL.RUTA and GL.RUTA.clase == "PALADIN" and f.origen == "instructor" and
    f.ant and f.ant > 0 and not (GL.HechizoORangoConocido or GL.HechizoConocido)(f.ant)
end
local function FaltaRangoCazador(g, i, est)
  -- All audited classes share the same predecessor rule.
  return GL.RUTA and i > 1 and est[i-1] ~= "aprendido"
end
local function Estados(g, nivel)
  local est = {}
  local conocido = false
  for i = #g.rangos, 1, -1 do
    -- si tienes un rango, los anteriores también cuentan como aprendidos
    local id=g.rangos[i].id
    local mutilar = GL.RUTA and GL.RUTA.clase=="ROGUE" and id==1310706 and
      (GL.HechizoConocido(399956) or GL.HechizoConocido(1310707))
    local soloColeccion=GL.RUTA and GL.RUTA.clase=="WARLOCK" and g.rangos[i].montura
    if conocido or mutilar or (GL.RUTA and GL.RUTA.clase=="DRUID" and id==5487 and GL.HechizoConocido(9634)) or (GL.CargaFeralConocida and GL.CargaFeralConocida(id)) or MonturaConocida(g.rangos[i]) or (not soloColeccion and (GL.HechizoConocido(id) or
       (GL.ConocidoFuera and GL.ConocidoFuera(id)))) then conocido = true; est[i] = "aprendido" end
  end
  local primero = g.rangos[1]
  local sinTalento = primero.origen == "talento" and est[1] ~= "aprendido"
  local falta = est[1] ~= "aprendido" and (Falta(primero) or primero.origen == "mision")
  for i, f in ipairs(g.rangos) do
    if not est[i] then
      if (f.origen == "general" or f.origen == "arma" or (GL.RUTA and GL.RUTA.clase=="SHAMAN" and f.id==674 and f.origen=="pendiente")) and not f.n then est[i] = "bloqueado"
      elseif not f.n or f.n > nivel then est[i] = "futuro"
      elseif sinTalento or falta or f.origen ~= "instructor" or Falta(f) or FaltaRangoPaladin(f) or FaltaRangoCazador(g, i, est) then est[i] = "bloqueado"
      elseif f.n and f.n <= nivel and not HabilidadLista(f) then est[i] = "bloqueado"
      elseif f.n and f.n <= nivel then est[i] = "disponible"
      else est[i] = "futuro" end
    end
  end
  return est, sinTalento
end

-- Estado del hechizo entero: lo que ves en el color del nombre.
local function EstadoGrupo(g, est, sinTalento)
  local hay, conocidos = false, 0
  for i, f in ipairs(g.rangos) do
    if est[i] == "disponible" and f.origen == "instructor" then hay = true end
    if est[i] == "aprendido" then conocidos = conocidos + 1 end
  end
  if hay then return "disponible", conocidos end
  if sinTalento then return "talento", conocidos end
  if conocidos > 0 then return "aprendido", conocidos end
  if est[1] == "disponible" then return "disponible", conocidos end
  if GL.RUTA and g.rangos[1].origen=="mision" and est[1]=="bloqueado" then return "bloqueado", conocidos end
  if g.rangos[1].origen == "pendiente" and est[1] == "bloqueado" then return "bloqueado", conocidos end
  if (g.rangos[1].origen == "general" or g.rangos[1].origen == "arma") and est[1] == "bloqueado" then
    return "bloqueado", conocidos
  end
  return "futuro", conocidos
end

local COLOR_ESTADO = { aprendido = C.VERDE, disponible = C.AMARILLO, futuro = C.GRIS, bloqueado = ROJO }

-- B06: cantidades de materiales y rangos de color documentados, no umbrales de compra.
-- ForeverDB (26/11) y WoWFAH (25/11); recetas clásicas presentes en la guía.
local materialesVeneno={f={"Pálida","Fadeleaf"},d={"Polvo de descomposición","Dust of Decay"},t={"Polvo de deterioro","Dust of Deterioration"},w={"Hierba de muerte","Deathweed"},p={"Esencia de dolor","Essence of Pain"},a={"Esencia de agonía","Essence of Agony"},v={"Vial vacío","Empty Vial"},l={"Vial emplomado","Leaded Vial"},c={"Vial de cristal","Crystal Vial"}}
local recetasVenenoPicaro={
  [6510]={170,220,"f1",3},
  [458822]={295,345,"w5 c1 a5"},
  [1214168]={300,350,"w7 c1"},
  [439503]={300,350,"t7 c1"},
  [439505]={300,350,"t3 c1 a1"},
  [439500]={300,350,"a4 c1"},
  [8681]={125,175,"d1 v1"},
  [8687]={165,215,"d3 l1"},
  [8691]={205,255,"t1 l1"},
  [11341]={245,295,"t2 c1"},
  [11342]={285,335,"t3 c1"},
  [11343]={325,375,"t4 c1"},
  [2835]={175,225,"w1 l1"},
  [2837]={215,265,"w2 l1"},
  [11357]={255,305,"w3 c1"},
  [11358]={295,345,"w5 c1"},
  [25347]={300,350,"w7 c1"},
  [3420]={125,175,"p1 v1"},
  [3421]={275,325,"a3 c1"},
  [5763]={150,200,"d1 p1 v1"},
  [8694]={215,265,"d4 p4 l1"},
  [11400]={285,335,"t2 a2 c1"},
  [13220]={185,235,"p1 w1 l1"},
  [13228]={225,275,"p1 w2 l1"},
  [13229]={265,315,"a1 w2 c1"},
  [13230]={305,355,"a2 w2 c1"},
}
local function ReferenciaVeneno(id)
  local r=recetasVenenoPicaro[id]
  if not r then return nil end
  local t={}
  for k,n in r[3]:gmatch("(%a)(%d+)") do t[#t+1]=n.." × "..materialesVeneno[k][GL.ingles and 2 or 1] end
  return (GL.ingles and " · Reference reagents: " or " · Materiales de referencia: ")..table.concat(t,", ")..
    (GL.ingles and " · Skill color range (not purchase requirement): " or " · Rango de color (no requisito de compra): ")..r[1].."–"..r[2] .. (r[4] and ((GL.ingles and " · Reference yield: " or " · Rendimiento de referencia: ")..r[4]) or "")
end

-- El límite de referencia es nivel x5; no sustituye el valor real leído del personaje.
-- No prometer un punto por fabricación: hay discrepancias entre fuentes y un fallo reportado de Reagent Economy.
local function ProgresoVenenos(nivel)
  local n=GL.NivelHabilidad and GL.NivelHabilidad(40)
  local cap=math.min(300, math.max(0, (tonumber(nivel) or 1)*5))
  local capReal=false
  if GL.NivelProfesion then
    local ok,real,tope=pcall(GL.NivelProfesion,{skill=40,nombre=(GetLocale and GetLocale()=="enUS") and "Poisons" or "Venenos"})
    if ok and type(real)=="number" and real>0 then n=real end
    if ok and type(tope)=="number" and tope>0 and type(n)=="number" and tope>=n then cap=tope;capReal=true end
  end
  local en=GL.ingles
  local pref=en and "Poisons: " or "Venenos: "
  if type(n)~="number" or n<=0 then
    return pref..(en and "skill not detected; complete your faction quest at level 20 and check the profession." or "habilidad no detectada; completa la misión de tu facción al 20 y consulta la profesión.")
  end
  local t=pref..n.."/"..cap..(capReal and (en and " (client skill cap). " or " (límite del cliente). ") or (en and " (reference cap). " or " (límite de referencia). "))
  if n>=300 then return t..(en and "Leveling target reached." or "Objetivo de 300 alcanzado.") end
  if n>=cap then return t..(capReal and (en and "At the current cap; check how to raise it before crafting for skill." or "Has alcanzado el límite actual; comprueba cómo aumentarlo antes de fabricar.") or (en and "Raise your character level before crafting for skill." or "Sube el nivel del personaje antes de fabricar para ganar habilidad.")) end
  return t..(en and "Craft known recipes in small batches and check actual skill gains. Reagent Economy may prevent skill-ups (reported Nov 26); delay choosing it until 300 if possible." or "Fabrica recetas conocidas en tandas pequeñas y comprueba los puntos ganados. Reagent Economy puede impedir subir la habilidad (informe del 26 de noviembre); aplázalo hasta 300 si puedes.")
end

-- Elemento necesario para invocar cada familia; no equivale a requisito de compra.
local objetosTotemChaman={
 [2484]=5175,[5730]=5175,[8071]=5175,[8075]=5175,[8143]=5175,
 [3599]=5176,[8181]=5176,[8190]=5176,[8227]=5176,
 [5394]=5177,[5675]=5177,[8166]=5177,[8170]=5177,[8184]=5177,[16190]=5177,
 [6495]=5178,[8177]=5178,[8512]=5178,[8835]=5178,[10595]=5178,[15107]=5178,
}
-- B05: reactivos para el lanzamiento, no requisitos de aprendizaje.
local viajesMago={
 [3561]={17031,"Ventormenta","Stormwind"},[10059]={17032,"Ventormenta","Stormwind"},
 [3562]={17031,"Forjaz","Ironforge"},[11416]={17032,"Forjaz","Ironforge"},
 [3565]={17031,"Darnassus","Darnassus"},[11419]={17032,"Darnassus","Darnassus"},
 [3563]={17031,"Entrañas","Undercity"},[11418]={17032,"Entrañas","Undercity"},
 [3567]={17031,"Orgrimmar","Orgrimmar"},[11417]={17032,"Orgrimmar","Orgrimmar"},
 [3566]={17031,"Cima del Trueno","Thunder Bluff"},[11420]={17032,"Cima del Trueno","Thunder Bluff"},
 [1297659]={17031,"Dalaran","Dalaran"},
}
local function TextoRango(f, estado)
  local color = COLOR_ESTADO[estado] or C.GRIS
  local partes
  if f.origen == "instructor" then
    local hab = ""
    if f.hab and (f.hab[2] or 0) > 1 then
      hab = ", " .. ((GL.NombreHabilidad and GL.NombreHabilidad(f.hab[1])) or L"habilidad") .. " " .. f.hab[2]
    end
    local clase = GL.RUTA and GL.RUTA.clase
    local dudoso = (clase == "WARRIOR" and precioGuerreroSinConfirmar[f.id]) or
      (clase == "PALADIN" and precioPaladinSinConfirmar[f.id]) or
      (clase == "HUNTER" and precioCazadorSinConfirmar[f.id]) or clase == "ROGUE" or clase == "PRIEST" or clase == "SHAMAN" or clase == "MAGE" or clase == "WARLOCK" or clase == "DRUID"
    local aviso = dudoso and (GL.ingles and "; price unconfirmed" or "; precio sin confirmar") or ""
    if estado == "bloqueado" and FaltaRangoPaladin(f) then
      aviso = aviso .. (GL.ingles and "; previous rank required" or "; requiere rango anterior")
    end
    partes = (f.n or "?") .. " (" .. (GL.ingles and "est. " or "aprox. ") .. Dinero(f.coste) .. hab .. aviso .. ")"
  elseif f.origen == "pendiente" then
    if f.libro then
      partes = (f.n or "?") .. (GL.ingles and " (manual #" or " (manual n.º ") .. f.libro ..
        (f.libroNivel and f.libroNivel ~= f.n and ((GL.ingles and "; book requires level " or "; el manual requiere nivel ") .. f.libroNivel) or "") ..
        (GL.ingles and "; availability unconfirmed)" or "; disponibilidad sin confirmar)")
    else
      partes = (f.n or "?") .. (GL.ingles and " (source/cost unconfirmed)" or " (origen/precio sin confirmar)")
    end
  elseif f.origen == "general" or f.origen == "arma" then
    local detalle = f.origen == "arma" and (GL.ingles and "weapon proficiency" or "competencia de arma") or
      (GL.ingles and "general ability" or "habilidad general")
    partes = (f.n or "?") .. " (" .. detalle .. ")"
  elseif f.origen == "talento" then
    partes = GL.ingles and "talent" or "talento"
  elseif f.origen == "mision" then
    partes = (f.n and (f.n .. " ") or "") .. L"(misión)"
  else
    partes = L"1 (lo tienes desde el principio)"
  end
  if GL.RUTA and GL.RUTA.clase == "ROGUE" then
    local raiz = raizPorId[f.id] or f.id
    if raiz==2835 or raiz==3420 or raiz==5763 or raiz==8681 or raiz==13220 or raiz==458822 then
      if f.origen == "pendiente" and f.hab then
        partes = partes .. (GL.ingles and " · Poisons " or " · Venenos ") .. f.hab[2]
      end
      partes = partes .. (GL.ingles and " · Crafted poison: bind on pickup (71091)" or " · Veneno fabricado: ligado al recoger (71091)") .. (ReferenciaVeneno(f.id) or "")
    elseif recetasVenenoPicaro[f.id] then
      partes = partes .. (ReferenciaVeneno(f.id) or "")
    end
    if f.id==2842 then partes=partes.." · "..ProgresoVenenos(UnitLevel and UnitLevel("player") or 1) end
  end
  if GL.RUTA and GL.RUTA.clase=="SHAMAN" then
    local raiz=raizPorId[f.id] or f.id
    local objeto=objetosTotemChaman[raiz]
    if objeto then
      local presente=GL.TotemChamanEnBolsas and GL.TotemChamanEnBolsas(objeto)
      partes=partes..(GL.ingles and " · Casting: totem #" or " · Lanzamiento: tótem #")..objeto..
        (presente==true and (GL.ingles and " in bags" or " en bolsas") or presente==false and (GL.ingles and " missing" or " ausente") or (GL.ingles and " status unknown" or " estado desconocido"))
    elseif raiz==408341 then partes=partes..(GL.ingles and " · Requires an active Fire totem" or " · Requiere un tótem de fuego activo") end
  end
  if GL.RUTA and GL.RUTA.clase=="MAGE" then
    local v=viajesMago[f.id]
    if v then
      local en=GL.ingles
      local reactivo=v[1]==17031 and (en and "Rune of Teleportation" or "Runa de teletransporte") or (en and "Rune of Portals" or "Runa de portales")
      partes=partes..(en and " · Casting: " or " · Lanzamiento: ")..reactivo.." (#"..v[1]..")"..(en and "; except Reagent Economy" or "; salvo Economía de reactivos (Reagent Economy)")
      if f.id~=1297659 then partes=partes..(en and " · Portal trainer in " or " · Instructor de portales en ")..v[en and 3 or 2] end
    end
  end
  return color .. partes .. C.FIN
end

-- Línea de origen del primer rango: talento, misión u otro instructor (el de mascotas del cazador). Lo que tienes
-- desde el principio ya lo dice el rango.
local function NombreMisionHechizo(f)
  local nombre = f.misionNombre or ("#" .. tostring(f.mision))
  if GL.ingles and f.misionNombreEN then return f.misionNombreEN end
  if GL.ingles and GL.NombreMisionIngles then return GL.NombreMisionIngles(f.mision, nombre) end
  return L(nombre)
end

local function TextoOrigen(f)
  if f.montura and GL.RUTA and GL.RUTA.clase=="WARLOCK" then
    return C.AZUL .. (GL.ingles and "Collection mount, not a class spell. Quest " or "Montura de Colecciones, no hechizo de clase. Misión ") .. NombreMisionHechizo(f).." (#"..f.mision..")." .. C.FIN
  end
  if f.donde and GL.RUTA and GL.RUTA.clase=="HUNTER" then
    return C.AZUL .. (GL.ingles and "Learn the lesson from the pet trainer; then teach the active pet through Beast Training. Learned means the hunter knows the lesson, not that the pet has it." or "Aprende la lección con el instructor de mascotas; después enséñasela a la mascota activa mediante Entrenar bestia. Aprendido indica que el cazador conoce la lección, no que la mascota la tenga.") .. C.FIN
  elseif f.donde then
    return C.AZUL .. L"Se compra en el " .. L(tostring(f.donde)) .. "." .. C.FIN
  elseif f.origen == "arma" then
    return C.AZUL .. (GL.ingles and "If not known, consult a weapon master (Library). Check availability and price in game." or
      "Si no la conoces, consulta a un maestro de armas (Biblioteca). Comprueba disponibilidad y precio en el juego.") .. C.FIN
  elseif f.origen == "general" then
    return C.AZUL .. (GL.ingles and "General spellbook entry; not a class-trainer purchase. Check your spellbook and equipment." or
      "Entrada general del libro de hechizos; no es una compra del instructor de clase. Consulta tu libro y equipo.") .. C.FIN
  elseif f.origen == "talento" then
    local t = L"Se aprende con un punto de talento"
    if f.n then t = t .. L" (desde el nivel " .. f.n .. ")" end
    local plan = f.plan
    if GL.RUTA and ((GL.RUTA.clase == "WARRIOR" and nombresPlanGuerrero[f.id]) or
      (GL.RUTA.clase == "PALADIN" and talentosPaladinPorId[f.id]) or
      (GL.RUTA.clase == "HUNTER" and talentosCazadorPorId[f.id]) or
      (GL.RUTA.clase == "ROGUE" and talentosPicaroPorId[f.id]) or
      (GL.RUTA.clase == "PRIEST" and talentosSacerdotePorId[f.id]) or
      (GL.RUTA.clase == "SHAMAN" and talentosChamanPorId[f.id]) or
      (GL.RUTA.clase == "MAGE" and talentosMagoPorId[f.id]) or
      (GL.RUTA.clase == "WARLOCK" and talentosBrujoPorId[f.id]) or
      (GL.RUTA.clase == "DRUID" and talentosDruidaPorId[f.id])) then
      plan = NivelPlanTalento(f.id)
    end
    if plan then t = t .. L"; la guía lo coge al " .. plan else t = t .. L"; la guía no lo coge" end
    return C.AZUL .. t .. "." .. C.FIN
  elseif f.origen == "mision" then
    return C.AZUL .. L"Se aprende con la misión " .. NombreMisionHechizo(f) ..
      (f.n and (L" (nivel " .. f.n .. ")") or "") .. "." .. C.FIN
  end
  return nil
end

-- La selección guardada puede proceder de una sesión en el otro idioma.
local function FiltroVisible(clave, R)
  if type(clave) ~= "string" then return nil end
  if clave == TODAS or clave == L(TODAS) or string.lower(clave) == "all" or string.lower(clave) == "todas" then return TODAS end
  local nombres = R and R.especialidades or {}
  local buscada = string.lower(clave)
  for _, e in ipairs(nombres) do if string.lower(e) == buscada then return e end end
  if GL.EnIngles then
    local canon = string.lower(GL.EnIngles(clave))
    for _, original in ipairs(R and R.especialidadesOriginalesR11 or {}) do
      if string.lower(original) == buscada then canon = string.lower(GL.EnIngles(original)); break end
    end
    for _, e in ipairs(nombres) do
      if string.lower(GL.EnIngles(e)) == canon then return e end
    end
  end
  return nil
end

local function DeLaRama(g, filtro)
  if filtro == TODAS then return true end
  for _, r in ipairs(g.ramas) do
    if r == filtro then return true end
  end
  return false
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------
local function Fila(i)
  local f = filas[i]
  if f then return f end
  f = CreateFrame("Frame", nil, hijo)
  f.marco = GL.CrearMarcoIcono(f, LADO_ICONO)
  f.marco:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.marco:EnableMouse(true)
  f.marco:SetScript("OnEnter", MostrarTooltipHechizo)
  f.marco:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.nombre = GL.Texto(f, "GameFontNormal")
  f.nombre:SetPoint("TOPLEFT", f.marco, "TOPRIGHT", 8, -1)
  GL.UnaLinea(f.nombre)
  f.etiqueta = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
  f.etiqueta:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
  GL.UnaLinea(f.etiqueta)
  f.detalle = GL.Texto(f, "GameFontHighlightSmall")
  f.detalle:SetPoint("TOPLEFT", f.nombre, "BOTTOMLEFT", 0, -3)
  f.linea = f:CreateTexture(nil, "BACKGROUND")
  f.linea:SetHeight(1)
  f.linea:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, -5)
  f.linea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, -5)
  f.linea:SetColorTexture(1, 1, 1, 0.06)
  filas[i] = f
  return f
end

-- 9.4.2: se traduce al usarla (al cargar el archivo aún no se sabe el idioma elegido en Ajustes)
local ETIQUETA_BASE = { comprar = { C.VERDE, "Compra" }, opcional = { C.AMARILLO, "Opcional" }, saltar = { C.GRIS, "Sáltalo" } }
local ETIQUETA = setmetatable({}, { __index = function(_, k)
  local e = ETIQUETA_BASE[k]
  return e and (e[1] .. L(e[2]) .. C.FIN) or nil
end })

local function Colocar()
  if not panel then return end
  if not grupos or rutaGrupos ~= GL.RUTA then Armar() end
  local db = DB()
  local filtro = FiltroVisible(db.filtroHechizos, GL.RUTA) or TODAS
  db.filtroHechizos = filtro ~= TODAS and filtro or nil
  local valido = filtro == TODAS
  for _, b in ipairs(filtros) do
    b:SetActivo(b.clave == filtro)
    if b.clave == filtro then valido = true end
  end
  if not valido then filtro = TODAS; db.filtroHechizos = nil; filtros[1]:SetActivo(true) end
  botonSolo:SetActivo(db.soloDisponibles == true)
  -- 9.6: con la Guía clara, en vez de «Solo lo disponible» (ya va arriba), «Llevarme al instructor»
  local claraArriba = GL.GuiaClaraActiva and GL.GuiaClaraActiva()
  local destinoIr = claraArriba and GL.DestinoInstructor and GL.DestinoInstructor() or nil
  GL.Mostrar(botonSolo, not claraArriba)
  GL.Mostrar(botonIr, destinoIr ~= nil)
  botonIr.destino = destinoIr

  local ancho = scroll:GetWidth() or 0
  if ancho <= 60 then ancho = 330 end
  hijo:SetWidth(ancho)
  local anchoTexto = ancho - LADO_ICONO - 8
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  local y, usadas = 0, 0
  local pend = {}
  -- cuentas del resumen: todo lo de la lista y solo lo que recomienda la guía (Compra)
  local total, aprendidos = 0, 0
  local ya, costeYa, costeFalta, yaRec, costeYaRec, costeFaltaRec = 0, 0, 0, 0, 0, 0
  for _, g in ipairs(grupos) do
    if DeLaRama(g, filtro) then
      local est, sinTalento = Estados(g, nivel)
      local estado, conocidos = EstadoGrupo(g, est, sinTalento)
      -- el rango que se describe: el más alto que tienes o, si no tienes ninguno, el primero
      local mejor = g.rangos[1].id
      for i = #g.rangos, 1, -1 do
        if est[i] == "aprendido" then mejor = g.rangos[i].id; break end
      end
      local nombre = Nombre(mejor)
      -- El instructor compara nombres del cliente, nunca la traducción de presentación.
      local nombreCliente = GL.NombreHechizo and GL.NombreHechizo(mejor)
      local tipo = g.rangos[1].origen
      local consejo = tipo ~= "general" and tipo ~= "arma" and tipo ~= "pendiente" and nombreCliente and GL.ConsejoHechizo and GL.ConsejoHechizo(nombreCliente)
      local recomendado = consejo and consejo.c == "comprar"
      total = total + 1
      if estado == "aprendido" then aprendidos = aprendidos + 1 end
      for i, f in ipairs(g.rangos) do
        if f.origen == "instructor" then
          if est[i] == "disponible" then
            ya = ya + 1; costeYa = costeYa + f.coste
            if recomendado then yaRec = yaRec + 1; costeYaRec = costeYaRec + f.coste end
          end
          if est[i] == "disponible" or est[i] == "futuro" or
             (est[i] == "bloqueado" and FaltaRangoPaladin(f) and not sinTalento and
              (est[1] == "aprendido" or est[1] == "disponible") and not Falta(f) and HabilidadLista(f)) then
            costeFalta = costeFalta + f.coste
            if recomendado then costeFaltaRec = costeFaltaRec + f.coste end
          end
        end
      end
      table.insert(pend, { g = g, est = est, estado = estado, conocidos = conocidos, mejor = mejor, nombre = nombre, consejo = consejo })
    end
  end
  -- 9.6: con la Guía clara, primero lo que puedes aprender ya y lo demás en un desplegable
  local clara = GL.GuiaClaraActiva and GL.GuiaClaraActiva()
  local ahora, resto = {}, {}
  for _, e in ipairs(pend) do
    if e.estado == "disponible" then table.insert(ahora, e) elseif not db.soloDisponibles then table.insert(resto, e) end
  end
  local cabUsadas = 0
  local function Cabecera(texto, clic)
    cabUsadas = cabUsadas + 1
    local c = cabeceras[cabUsadas]
    if not c then
      c = CreateFrame("Button", nil, hijo)
      c.texto = GL.Texto(c, "GameFontNormal")
      c.texto:SetPoint("LEFT", c, "LEFT", 0, 0)
      c.texto:SetPoint("RIGHT", c, "RIGHT", 0, 0)
      GL.UnaLinea(c.texto)
      c.linea = c:CreateTexture(nil, "ARTWORK")
      c.linea:SetHeight(1)
      c.linea:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
      c.linea:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
      c.linea:SetColorTexture(1, 1, 1, 0.10)
      cabeceras[cabUsadas] = c
    end
    c.texto:SetText(texto)
    c:SetScript("OnClick", clic)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", hijo, "TOPLEFT", 0, -y)
    c:SetWidth(ancho); c:SetHeight(18)
    c:Show()
    y = y + 26
  end
  local function Pintar(e)
    local g, est, estado, conocidos, mejor, nombre, consejo = e.g, e.est, e.estado, e.conocidos, e.mejor, e.nombre, e.consejo
    usadas = usadas + 1
    local fila = Fila(usadas)
    fila.marco.idHechizo = mejor
    fila.marco.nombre = nombre
    GL.PonerIcono(fila.marco.icono, Icono(mejor))
    fila.marco.icono:SetDesaturated(estado == "futuro" or estado == "talento")
    local color = COLOR_ESTADO[estado] or C.BLANCO
    if estado == "talento" then color = C.GRIS end
    local titulo = color .. nombre .. C.FIN
    if #g.rangos > 1 then
      titulo = titulo .. C.GRIS .. "  " .. conocidos .. "/" .. #g.rangos .. C.FIN
    end
    -- etiqueta: consejo de la guía y rama
    local etiqueta = table.concat(g.ramas, L" y ")
    if consejo and ETIQUETA[consejo.c] then etiqueta = ETIQUETA[consejo.c] .. C.GRIS .. "  ·  " .. etiqueta .. C.FIN
    else etiqueta = C.GRIS .. etiqueta .. C.FIN end
    fila.etiqueta:SetText(etiqueta)
    local anchoEtiqueta = (fila.etiqueta.GetStringWidth and fila.etiqueta:GetStringWidth()) or 90
    if not anchoEtiqueta or anchoEtiqueta <= 0 then anchoEtiqueta = 90 end
    fila.nombre:SetWidth(math.max(60, anchoTexto - anchoEtiqueta - 8))
    fila.nombre:SetText(titulo)
    -- detalle: niveles y precios de cada rango, origen y consejo (lo que hace sale en la ventana del icono)
    local lineas = {}
    local rangos = {}
    for i, f in ipairs(g.rangos) do table.insert(rangos, TextoRango(f, est[i])) end
    fila.marco.rangos = nil
    if #g.rangos == 1 then
      table.insert(lineas, C.GRIS .. L"Nivel " .. C.FIN .. rangos[1])
    else
      -- 9.4.2: solo el rango siguiente; todos los rangos, en la ventana del icono
      local sig
      for i = 1, #g.rangos do if est[i] ~= "aprendido" then sig = i; break end end
      if not sig then
        table.insert(lineas, C.VERDE .. L"Todos los rangos aprendidos" .. C.FIN)
      elseif g.rangos[sig].origen == "instructor" then
        table.insert(lineas, C.GRIS .. L"Siguiente rango: nivel " .. C.FIN .. rangos[sig])
      else
        table.insert(lineas, C.GRIS .. L"Siguiente rango: " .. C.FIN .. rangos[sig])
      end
      fila.marco.rangos = table.concat(rangos, C.GRIS .. " · " .. C.FIN)
    end
    local origen = TextoOrigen(g.rangos[1])
    if origen then table.insert(lineas, origen) end
    -- lo que pide además (una actitud de misión, por ejemplo), solo mientras no lo tengas
    for _, r in ipairs(g.rangos[1].necesita or {}) do
      if not (GL.HechizoORangoConocido or GL.HechizoConocido)(r) then
        local o = indice[r]
        local t = L"Necesita " .. Nombre(r)
        -- con su rango si no es el primero (la bendición superior pide el rango 6 de la normal)
        local rg = tonumber(string.match(GL.RangoHechizo and GL.RangoHechizo(r) or "", "(%d+)"))
        if rg and rg > 1 then t = t .. L" (rango " .. rg .. ")" end
        if o and o.origen == "mision" then
          t = t .. L", que se aprende con la misión " .. NombreMisionHechizo(o)
        end
        table.insert(lineas, ROJO .. t .. "." .. C.FIN)
      end
    end
    local ultimo = g.rangos[#g.rangos]
    if ultimo ~= g.rangos[1] and ultimo.origen == "mision" then table.insert(lineas, TextoOrigen(ultimo)) end
    if consejo and consejo.nota then table.insert(lineas, C.BLANCO .. L"Guía: " .. C.FIN .. consejo.nota) end
    local texto = table.concat(lineas, "\n")
    fila.detalle:SetWidth(anchoTexto)
    fila.detalle:SetText(texto)
    local alto = 16 + 3 + GL.Alto(fila.detalle, texto, 12, anchoTexto)
    if alto < LADO_ICONO then alto = LADO_ICONO end
    fila:ClearAllPoints()
    fila:SetPoint("TOPLEFT", hijo, "TOPLEFT", 0, -y)
    fila:SetWidth(ancho)
    fila:SetHeight(alto)
    fila:Show()
    y = y + alto + 10
  end
  local function Nada(detalle)
    usadas = usadas + 1
    local fila = Fila(usadas)
    fila.marco.idHechizo = nil; fila.marco.rangos = nil
    GL.PonerIcono(fila.marco.icono, ICONO_PESTANA)
    fila.marco.icono:SetDesaturated(true)
    fila.nombre:SetWidth(anchoTexto)
    fila.nombre:SetText(C.GRIS .. L"Nada que aprender ahora" .. C.FIN)
    fila.etiqueta:SetText("")
    fila.detalle:SetWidth(anchoTexto)
    fila.detalle:SetText(C.GRIS .. detalle .. C.FIN)
    fila:ClearAllPoints()
    fila:SetPoint("TOPLEFT", hijo, "TOPLEFT", 0, -y)
    fila:SetWidth(ancho)
    fila:SetHeight(LADO_ICONO)
    fila:Show()
    y = y + LADO_ICONO + 10
  end
  if clara then
    if #ahora == 0 then
      local sig = GL.SiguienteEntrenamiento and GL.SiguienteEntrenamiento(UnitLevel and UnitLevel("player") or 1)
      Nada(sig and (L"Vuelve al instructor al " .. sig .. ".") or L"Vuelve al instructor cuando subas de nivel.")
    end
    if #ahora > 0 then Cabecera(C.AMARILLO .. L"Para aprender ya" .. C.FIN .. C.GRIS .. "  (" .. #ahora .. ")" .. C.FIN) end
    for _, e in ipairs(ahora) do Pintar(e) end
    if #resto > 0 then
      local abierto = db.hechizosResto == true
      Cabecera((abierto and "v  " or ">  ") .. L"Más adelante y aprendidos" .. C.GRIS .. "  (" .. #resto .. ")" .. C.FIN, function()
        DB().hechizosResto = not abierto or nil
        Colocar()
      end)
      if abierto then for _, e in ipairs(resto) do Pintar(e) end end
    end
  else
    for _, e in ipairs(pend) do
      if not db.soloDisponibles or e.estado == "disponible" then Pintar(e) end
    end
  end
  if usadas == 0 and not clara then Nada(L"Quita \"Solo lo disponible\" para ver toda la lista.") end
  for i = cabUsadas + 1, #cabeceras do cabeceras[i]:Hide() end
  for i = usadas + 1, #filas do filas[i]:Hide() end
  -- 9.4.2: solo lo que puedes aprender ya (sin el total ni lo que cuesta hasta el 60)
  local texto = C.GRIS .. L"Nada que aprender ahora en el instructor." .. C.FIN
  if ya > 0 then
    texto = C.AMARILLO .. L"Puedes aprender ya " .. ya .. (ya == 1 and L" rango" or L" rangos") ..
      " (" .. (GL.ingles and "est. " or "aprox. ") .. Dinero(costeYa) .. ")" .. C.FIN
    if yaRec > 0 then
      texto = texto .. C.VERDE .. L"; la guía recomienda " .. yaRec .. " (" .. (GL.ingles and "est. " or "aprox. ") .. Dinero(costeYaRec) .. ")" .. C.FIN
    end
    texto = texto .. C.AMARILLO .. "." .. C.FIN
  end
  resumen:SetText(texto)
  -- la lista empieza debajo del resumen, que puede ocupar varias líneas
  local anchoResumen = math.max(60, ((panel:GetWidth() or 0) > 60 and panel:GetWidth() or 400) - ANCHO_SOLO - 8)
  local altoResumen = math.max(20, GL.Alto(resumen, texto, 12, anchoResumen))
  local arriba = 29 + altoResumen + 8
  if scroll.arriba ~= arriba then
    scroll.arriba = arriba
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -arriba)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 0)
    barra:ClearAllPoints()
    barra:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -arriba)
    barra:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  end

  hijo:SetHeight(math.max(1, y))
  local maximo = math.max(0, math.floor(y - (scroll:GetHeight() or 0) + 0.5))
  barra:SetMinMaxValues(0, maximo)
  GL.Mostrar(barra, maximo > 0)
  local actual = barra:GetValue() or 0
  if actual > maximo then actual = maximo end
  barra:SetValue(actual)
  scroll:SetVerticalScroll(actual)
end

local function Disponer()
  if not panel then return end
  local ancho = (panel:GetWidth() or 0)
  if ancho <= 60 then ancho = 400 end
  local n = #filtros
  -- 9.7.4: cada filtro mide su texto más una parte igual del hueco que sobra (antes, todos iguales:
  -- «Beast Mastery», «Restauración» o «Protección» salían cortados con seis filtros)
  local libre, anchos, suma = ancho - (n - 1) * 6, {}, 0
  for i, b in ipairs(filtros) do
    local tw = b.texto and b.texto.GetStringWidth and tonumber(b.texto:GetStringWidth()) or 0
    anchos[i] = math.ceil(tw) + 10 + (b.icono and 18 or 0); suma = suma + anchos[i]
  end
  if suma <= 10 * n then
    for i = 1, n do anchos[i] = libre / n end
  elseif suma > libre then
    for i = 1, n do anchos[i] = anchos[i] * libre / suma end
  else
    local extra = (libre - suma) / n
    for i = 1, n do anchos[i] = anchos[i] + extra end
  end
  for i, b in ipairs(filtros) do b:SetWidth(math.floor(anchos[i])) end
  resumen:SetWidth(math.max(60, ancho - ANCHO_SOLO - 8))
end

local function ElegirFiltro(clave)
  local db = DB()
  db.filtroHechizos = (clave ~= TODAS) and clave or nil
  if barra then barra:SetValue(0) end
  Colocar()
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame or not GL.RUTA then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + GL.ALTO_SUB))   -- debajo de las subpestañas
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()

  -- filtro: Todas y cada especialización de la ruta (con el icono de su rama de talentos si la hay)
  local claves = { TODAS }
  for _, e in ipairs(GL.RUTA.especialidades or {}) do table.insert(claves, e) end
  for i, clave in ipairs(claves) do
    local etiqueta = clave == TODAS and L(TODAS) or clave
    local b = GL.CrearBoton(panel, etiqueta, function() ElegirFiltro(clave) end, nil, 22)
    b.clave = clave
    if i == 1 then b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    else b:SetPoint("LEFT", filtros[i - 1], "RIGHT", 6, 0) end
    local ayuda = clave == TODAS and L"Todos los hechizos de tu clase." or
      (clave == "General" and L"Hechizos que usa cualquier especialización (utilidad, viaje, comida y bebida...)." or
       (L"Hechizos que usa la especialización " .. clave .. "."))
    GL.Ayuda(b, etiqueta, ayuda)
    filtros[i] = b
  end
  resumen = GL.Texto(panel, "GameFontHighlightSmall")
  resumen:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -29)
  botonSolo = GL.CrearBoton(panel, L"Solo lo disponible", function()
    local db = DB()
    db.soloDisponibles = not db.soloDisponibles or nil
    if barra then barra:SetValue(0) end
    Colocar()
  end, nil, 20)
  botonSolo:SetWidth(ANCHO_SOLO)
  botonSolo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -28)
  GL.Ayuda(botonSolo, L"Solo lo disponible", L"Muestra solo los hechizos que puedes aprender ya en tu instructor.")
  botonIr = GL.CrearBoton(panel, L"Llevarme al instructor", function(self)
    if self.destino and GL.SeguirDesvio then GL.SeguirDesvio(self.destino) end
  end, nil, 20, "accion")
  botonIr:SetWidth(ANCHO_SOLO)   -- 9.7.4: ANCHO_SOLO pasa de 128 a 150, «Llevarme al instructor» no cabía
  botonIr:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -28)
  GL.Ayuda(botonIr, L"Llevarme al instructor", L"La flecha te lleva al instructor de tu clase de la ruta más cercano a tu paso.")
  botonIr:Hide()

  scroll = CreateFrame("ScrollFrame", nil, panel)
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -60)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 0)
  hijo = CreateFrame("Frame", nil, scroll)
  hijo:SetWidth(330)
  hijo:SetHeight(1)
  scroll:SetScrollChild(hijo)

  barra = CreateFrame("Slider", nil, panel)
  barra:SetOrientation("VERTICAL")
  barra:SetWidth(10)
  barra:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -60)
  barra:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  local pista = barra:CreateTexture(nil, "BACKGROUND")
  pista:SetPoint("TOP", barra, "TOP", 0, 0)
  pista:SetPoint("BOTTOM", barra, "BOTTOM", 0, 0)
  pista:SetWidth(4)
  pista:SetColorTexture(1, 1, 1, 0.12)
  local pulgar = barra:CreateTexture(nil, "OVERLAY")
  pulgar:SetWidth(8)
  pulgar:SetHeight(28)
  pulgar:SetColorTexture(0.41, 0.8, 0.94, 0.85)
  barra:SetThumbTexture(pulgar)
  barra:SetMinMaxValues(0, 0)
  barra:SetValueStep(1)
  barra:SetValue(0)
  barra:EnableMouse(true)
  barra:SetScript("OnValueChanged", function(self, v) scroll:SetVerticalScroll(v) end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local minimo, maximo = barra:GetMinMaxValues()
    local v = (barra:GetValue() or 0) - delta * 48
    if v < minimo then v = minimo end
    if v > maximo then v = maximo end
    barra:SetValue(v)
  end)
  panel:SetScript("OnSizeChanged", function() Disponer() end)
  Disponer()
  GL.modos.hechizos = { panel = panel, refrescar = function() Disponer(); Colocar() end }
end

-- Abre la pestaña Hechizos de la ventana.
function GL.AbrirHechizos(filtro)
  local db = DB()
  if GL.MostrarVentanaCompletaR10 then GL.MostrarVentanaCompletaR10() else
    if db.compacto and GL.SalirCompacto then GL.SalirCompacto() end
  if GL.frame then GL.frame:Show(); db.oculto = false end
  end
  if filtro then
    local visible = FiltroVisible(filtro, GL.RUTA)
    if visible then db.filtroHechizos = visible ~= TODAS and visible or nil end
  end
  GL.AbrirModo("hechizos")
end

-- Refresco cuando cambian tus hechizos o llega el nombre de uno que se había pedido al juego.
local function ProgramarColocar()
  if refrescoPendiente then return end
  refrescoPendiente = true
  local hecho = false
  local function Hacer()
    if hecho then return end
    hecho = true
    refrescoPendiente = false
    if panel and panel:IsShown() then pcall(Colocar) end
  end
  if C_Timer and C_Timer.After then
    local ok, resultado = pcall(C_Timer.After, 0.3, Hacer)
    if not ok or resultado == false then Hacer() end
  else Hacer() end
end

GL.RefrescarHechizos = ProgramarColocar

-- 9.7.4: los rangos de un hechizo, del primero al último, según los datos de la ruta (para cambiar los rangos
-- de las barras sin depender de que el juego encuentre el hechizo por su nombre).
local cadenas, cadenasRuta = nil, nil
function GL.CadenaDeHechizo(id)
  if not GL.RUTA then return nil end
  if not cadenas or cadenasRuta ~= GL.RUTA then
    -- R15: no publicar una cadena parcial ni memorizar un fallo transitorio.
    local ruta = GL.RUTA
    local nuevas = {}
    local ok = pcall(Armar)
    if not ok or not grupos or GL.RUTA ~= ruta then
      grupos, rutaGrupos = nil, nil
      return nil
    end
    if grupos then
      for _, g in ipairs(grupos) do
        local ids = {}
        for _, f in ipairs(g.rangos or {}) do table.insert(ids, f.id) end
        if #ids > 1 then for _, x in ipairs(ids) do nuevas[x] = ids end end
      end
    end
    cadenas, cadenasRuta = nuevas, ruta
  end
  return cadenas[id]
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "SPELLS_CHANGED")
GL.Evento(eventos, "LEARNED_SPELL_IN_SKILL_LINE")
GL.Evento(eventos, "SKILL_LINES_CHANGED")
GL.Evento(eventos, "BAG_UPDATE_DELAYED")
pcall(eventos.RegisterEvent, eventos, "SPELL_DATA_LOAD_RESULT")
eventos:SetScript("OnEvent", function(self, event, id)
  if event == "SPELL_DATA_LOAD_RESULT" and not pedidos[id] then return end
  ProgramarColocar()
end)

table.insert(GL.alIniciar, CrearPanel)

GL.comandos["hechizos"] = function(resto)
  local filtro
  if resto and resto ~= "" and GL.RUTA then
    filtro = FiltroVisible(resto, GL.RUTA)
  end
  GL.AbrirHechizos(filtro)
end

GL.ICONO_HECHIZOS = ICONO_PESTANA

-- 9.6: el instructor de clase de la ruta más cercano a tu paso (primero los que vienen, luego los de atrás)
function GL.DestinoInstructor()
  local R, db = GL.RUTA, DB()
  if not (R and R.secciones and GL.TipoPaso and db) then return nil end
  local lista, actual = {}, nil
  for s, sec in ipairs(R.secciones) do
    for p, paso in ipairs(sec.pasos or {}) do
      if s == db.seccion and p == db.paso then actual = #lista + 1 end
      local tx = string.lower(tostring(paso.t or ""))
      local esInstr = GL.TipoPaso(paso) == "instructor" or ((tx:find("^train") or tx:find("[%s:]train")) and not tx:find("[%s:]fly") and not (paso.wp and paso.wp[1] and paso.wp[1].q))
      if esInstr then
        for _, d in ipairs(paso.wp or {}) do
          if d.m and d.x and d.y then table.insert(lista, { m = d.m, x = d.x, y = d.y, z = d.z, n = d.n or L"Instructor" }); break end
        end
      elseif s == db.seccion and p == db.paso then actual = #lista + 1 end
    end
  end
  if #lista == 0 then return nil end
  actual = actual or 1
  return lista[actual] or lista[#lista]
end

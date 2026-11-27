-- Reputacion.lua: guía de reputación (6.6). Se abre con el botón Reputación del lateral derecho.
-- Lista las facciones del personaje (barra y rango leídos del juego) y, al pulsar una, su ficha:
-- cómo subirla, intendente y recompensas. Solo lee datos: no cambia la ruta ni el progreso.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local ALTO_FILA = 18
local FILAS = 8                  -- filas de la lista; el resto del panel es la ficha
local CADA = 10                  -- sondeo de respaldo, solo con el panel visible
local DEMORA = 0.25              -- agrupar ráfagas de eventos

local panel, ui = nil, { filas = {} }
local desde, sel = 0, nil        -- desplazamiento de la lista y facción pulsada (factionID o nombre)
local FICHAS = nil               -- se rellenan al abrir el panel por primera vez

local RANGOS = { "Odiado", "Hostil", "Adverso", "Neutral", "Amistoso", "Honorable", "Reverenciado", "Exaltado" }
local COLORES = { { 0.8, 0.13, 0.13 }, { 0.8, 0.13, 0.13 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 },
  { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 } }

------------------------------------------------------------------------
-- Datos de las fichas (bajo demanda). confirmado = true: intendente y su sitio comprobados con QuestieDB (Forever) en la 7.8.
-- 7.6: vendedores de monturas de la guía de Wowhead (Forever) y el resto de las guías de reputación del clásico.
-- d = destino del intendente para la flecha ({ m = uiMapID, x, y, n }); sin d no sale "Llevarme".
------------------------------------------------------------------------
local function CargarFichas()
  return {
    [72] = { n = L"Ventormenta", confirmado = true, lado = "A",
      subir = { L"Misiones de Bosque de Elwynn, Páramos de Poniente y Ventormenta", L"Entregas de tela en Ventormenta", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Katie Hunter, vendedora de caballos en el campamento maderero del Valle del Este (Elwynn)",
      d = { m = 1429, x = 84.2, y = 65.5, n = "Katie Hunter" },
      recompensas = { L"Monturas raciales: caballos de Ventormenta. Exaltado para otras razas compatibles; comprueba la equitación y las restricciones." } },
    [47] = { n = L"Forjaz", confirmado = true, lado = "A",
      subir = { L"Misiones de Dun Morogh, Loch Modan y Forjaz", L"Entregas de tela en Forjaz", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Veron Calmámbar, vendedor de carneros en la cantera de Gol'Bolar (Dun Morogh)",
      d = { m = 1426, x = 63.6, y = 50.6, n = L"Veron Calmámbar" },
      recompensas = { L"Monturas raciales: carneros de Forjaz. Exaltado para otras razas compatibles; comprueba la equitación y las restricciones." } },
    [54] = { n = L"Exiliados de Gnomeregan", confirmado = true, lado = "A",
      subir = { L"Misiones de gnomos en Dun Morogh y Forjaz", L"Entregas de tela en Forjaz (Ciudad Manitas)", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Milli Plumasilba, vendedora de mecazancudos en Kharanos (Dun Morogh)",
      d = { m = 1426, x = 49.2, y = 48.0, n = L"Milli Plumasilba" },
      recompensas = { L"Monturas raciales: mecazancudos. Exaltado para otras razas compatibles; comprueba la equitación y las restricciones." } },
    [69] = { n = "Darnassus", confirmado = true, lado = "A",
      subir = { L"Misiones de Teldrassil, Costa Oscura y Darnassus", L"Entregas de tela en Darnassus", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Lelanai, vendedora de sables en Darnassus",
      d = { m = 1457, x = 38.6, y = 15.6, n = "Lelanai" },
      recompensas = { L"Monturas raciales: sables de la noche. Exaltado para otras razas compatibles; comprueba la equitación y las restricciones." } },
    -- 8.5: capitales de la Horda; vendedores de monturas comprobados con QuestieDB (Forever).
    [76] = { n = "Orgrimmar", confirmado = true, lado = "H",
      subir = { L"Misiones de Durotar, Los Baldíos y Orgrimmar", L"Entregas de tela en Orgrimmar", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Ogunaro Correlobo, vendedor de lobos en el Valle del Honor (Orgrimmar)",
      d = { m = 1454, x = 69.4, y = 12.2, n = L"Ogunaro Correlobo" },
      recompensas = { L"Monturas raciales: lobos de Orgrimmar. Exaltado para otras razas compatibles; comprueba la equitación y las restricciones." } },
    [530] = { n = L"Trols Lanza Negra", confirmado = true, lado = "H",
      subir = { L"Misiones de los trols en Durotar (Valle de los Retos y Poblado Sen'jin)", L"Entregas de tela en Orgrimmar (Valle de los Espíritus)", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Zjolnir, vendedor de raptores en el Poblado Sen'jin (Durotar)",
      d = { m = 1411, x = 55.2, y = 75.7, n = "Zjolnir" },
      recompensas = { L"Monturas raciales: raptores. Exaltado para otras razas compatibles; comprueba la equitación y las restricciones." } },
    [81] = { n = L"Cima del Trueno", confirmado = true, lado = "H",
      subir = { L"Misiones de Mulgore, Los Baldíos y Cima del Trueno", L"Entregas de tela en Cima del Trueno", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Harb Garrapezuña, vendedor de kodos en el Poblado Pezuña de Sangre (Mulgore)",
      d = { m = 1412, x = 46.6, y = 62.1, n = L"Harb Garrapezuña" },
      recompensas = { L"Monturas raciales: kodos. Exaltado para otras razas compatibles; comprueba la equitación y las restricciones." } },
    [68] = { n = L"Entrañas", confirmado = true, lado = "H",
      subir = { L"Misiones de Claros de Tirisfal, Bosque de Argénteos y Entrañas", L"Entregas de tela en Entrañas", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Zacarías Posta, vendedor de caballos esqueléticos en Rémol (Claros de Tirisfal)",
      d = { m = 1420, x = 59.9, y = 52.7, n = L"Zacarías Posta" },
      recompensas = { L"Monturas raciales: caballos esqueléticos. Exaltado para otras razas compatibles; comprueba la equitación y las restricciones." } },
    [21] = { n = L"Bahía del Botín", confirmado = true,
      subir = { L"Misiones de Bahía del Botín", L"Matar piratas Velasangre (baja la de los Velasangre)" },
      intendente = nil,
      recompensas = { L"Equipo con requisitos de reputación desde Amistoso; comprobar nivel, coste y disponibilidad de cada pieza.", L"La reputación con los Bucaneros Velasangre puede ser incompatible con la de los cárteles goblin; comprueba las consecuencias antes de atacar." } },
    [609] = { n = L"Círculo Cenarion", confirmado = true, fuente = L"Blizzard: correcciones de noviembre de 2026; intendente contrastado con QuestieDB (Forever).",
      subir = { L"Misiones de Silithus", L"Derrotar cultistas del Martillo Crepuscular; comprobar el límite de reputación.", L"Forever: la entrega repetible de textos crepusculares para reputación está deshabilitada. Still Believing puede dar recetas por correo." },
      intendente = L"Vargus, intendente del Círculo Cenarion, en Fuerte Cenarion (Silithus 51.2, 38.9)",
      d = { m = 1451, x = 51.2, y = 38.9, n = "Vargus" },
      recompensas = { L"Recetas de peletería y sastrería, abalorios y piezas de equipo" } },
    [529] = { n = L"El Alba Argenta", confirmado = true,
      subir = { L"Misiones de las Tierras de la Peste y jefes de Stratholme y Scholomance.",
        L"Desde nivel 50, consigue y equipa el abalorio Comisión del Alba Argenta para obtener piedras de la Plaga.",
        L"Entrega 20 piedras de esbirro, 10 de invasor o 1 de corruptor: 25 de reputación base y una ficha de valor." },
      intendente = L"Intendente Argenta Chispillo, en el Campamento Ventofrío (Tierras de la Peste del Oeste 42.8, 83.7); o la intendente Cerrobrecha, en la Capilla de la Esperanza de la Luz (Tierras de la Peste del Este 71.8, 50.2)",
      d = { m = 1422, x = 42.8, y = 83.7, n = L"Intendente Argenta Chispillo" },
      recompensas = { L"Honorable: planos, patrones y fórmulas de profesión", L"Reverenciado: hombreras de resistencia del Alba", L"Exaltado: Manto cromático del Alba" } },
    [576] = { n = L"Bastión Fauces de Madera", confirmado = true,
      subir = { L"Misiones y furbolgs Muertobosque (Frondavil) y Nevada (Cuna del Invierno); guarda las entregas para los rangos altos.",
        L"Tras desbloquear las entregas: 5 plumas Muertobosque o 5 abalorios Nevada por 50 de reputación base.",
        L"Forever: Ekkal en Azshara acepta 5 cuernos Legashi o 5 bolsas de Blackmaw (mazmorra), por 100 de reputación base en las repetibles." },
      intendente = L"Meilosh, en el Bastión Fauces de Madera (Frondavil 65.7, 2.8)",
      d = { m = 1448, x = 65.7, y = 2.8, n = "Meilosh" },
      recompensas = { L"Amistoso: recetas y patrones de oso de guerra", L"Honorable: Encantar arma: agilidad", L"Exaltado: Defensor de los Fauces de Madera" } },
    [59] = { n = L"Hermandad del Torio", confirmado = true,
      subir = { L"Neutral a Amistoso: desbloquea las entregas de flujo ígneo del maestro herrero Cremación (Garganta de Fuego).",
        L"Amistoso a Honorable: 4 residuos de hierro negro por 25 de reputación base; la cantidad total depende de tu progreso.",
        L"Desde Honorable: Lokhtos, en Profundidades de Roca Negra, acepta 10 menas de hierro negro por 50; otros materiales de banda requieren acceso confirmado." },
      intendente = L"Lokhtos Tratoscuro, en la Taberna del Rencor (dentro de Profundidades de Roca Negra)",
      recompensas = { L"Recetas de herrería, peletería y sastrería de fuego" } },
    -- 7.6: facción nueva de Forever (guía de zona de Wowhead).
    [2826] = { n = L"Hermandad de la Caballería", confirmado = false, lado = "A", pendiente = true, fuente = L"Wowhead (Forever): guías y datos de facción",
      subir = { L"Misiones de la Hermandad en Clarofluvial (Riverglades), especialmente en Farholde." },
      recompensas = { L"Recompensas y requisitos pendientes de confirmar." } },
    [2586] = { n = L"Autoridad Comercial de Azeroth", fuente = L"Wowhead (Forever): guías y datos de facción", confirmado = false, lado = "A",
      subir = { L"Libranzas de artesano: 75 (oficial), 125 (experto) o 200 (artesano) de reputación base; comprueba el límite diario.", L"Rellenar y entregar cajas de suministros para obtener Favor de mercader; no confundir la moneda con la reputación." },
      intendente = L"Huey Sunnydale, vendedor del kodo de carga en Montañas Crestagrana",
      d = { m = 1433, x = 8.5, y = 72.1, n = "Huey Sunnydale", z = L"Montañas Crestagrana" },
      recompensas = { L"Recetas, coleccionables y cosméticos; comprobar el rango y el coste de cada recompensa.", L"Exaltado: kodo de carga por 6000 de Favor del comerciante; nivel 60 y equitación avanzada." } },
    [2587] = { n = L"Suministros y Logística de Durotar", fuente = L"Wowhead (Forever): guías y datos de facción", confirmado = false, lado = "H",
      subir = { L"Libranzas de artesano: 75 (oficial), 125 (experto) o 200 (artesano) de reputación base; comprueba el límite diario.", L"Rellenar y entregar cajas de suministros para obtener Favor de mercader; no confundir la moneda con la reputación." },
      intendente = L"Okamache, vendedor del kodo de carga en Los Baldíos",
      d = { m = 1413, x = 49.7, y = 28.8, n = "Okamache", z = L"Los Baldíos" },
      recompensas = { L"Recetas, coleccionables y cosméticos; comprobar el rango y el coste de cada recompensa.", L"Exaltado: kodo de carga por 6000 de Favor del comerciante; nivel 60 y equitación avanzada." } },
    [2798] = { n = L"Asaltantes Lanza Negra", fuente = L"Blizzard y datos de Forever", confirmado = false, lado = "H",
      subir = { L"Participar en el campo de batalla Islas Lanza Negra." },
      recompensas = { L"Equipo JcJ: comprobar los requisitos y el coste de cada pieza.", L"Exaltado: un punto de Legado por campo de batalla, compartido por la cuenta en los reinos no Extremo; no uno por cada facción." } },
    [2799] = { n = L"Fuerza Expedicionaria de Theramore", fuente = L"Blizzard y datos de Forever", confirmado = false, lado = "A",
      subir = { L"Participar en el campo de batalla Islas Lanza Negra." },
      recompensas = { L"Equipo JcJ: comprobar los requisitos y el coste de cada pieza.", L"Exaltado: un punto de Legado por campo de batalla, compartido por la cuenta en los reinos no Extremo; no uno por cada facción." } },
    [2758] = { n = L"Druidas Garra Nocturna", fuente = L"Wowhead (Forever): guías y datos de facción", confirmado = false,
      subir = { L"Misiones de los druidas en el noreste de Isla Zephras.", L"Tras desbloquear la misión repetible de Vayn, entrega 5 orejas de cultista Al’Aketh por 200 de reputación base." },
      recompensas = { L"Amistoso: recetas de profesión; comprobar coste individual.", L"Reverenciado: ardilla de Shadowgale.", L"Exaltado: manto cosmético de los Nightclaw." },
      intendente = L"Vayn Moongaze, Isla Zephras",
      d = { m = 2521, x = 63.8, y = 36.0, n = "Vayn Moongaze", z = L"Isla Zephras" } },
    [92] = { n = L"Centauros del clan Gelkis", fuente = L"Wowhead (Forever): guías y datos de facción", confirmado = false,
      subir = { L"Misiones de los Gelkis en Desolace; derrotar centauros Magram favorece a los Gelkis.", L"Elegir un clan puede perjudicar la reputación con su rival." },
      recompensas = { L"Recetas de encantamiento, peletería y sastrería mediante misiones exclusivas." } },
    [93] = { n = L"Centauros del clan Magram", fuente = L"Wowhead (Forever): guías y datos de facción", confirmado = false,
      subir = { L"Misiones de los Magram en Desolace; derrotar centauros Gelkis favorece a los Magram.", L"Elegir un clan puede perjudicar la reputación con su rival." },
      recompensas = { L"Recetas de alquimia, herrería e ingeniería mediante misiones exclusivas." } },
    [2782] = { n = L"Clan Bolder'ok", fuente = L"Wowhead (Forever): guías y datos de facción", confirmado = false, lado = "H", pendiente = true,
      subir = { L"Misiones del clan en Clarofluvial (Riverglades)." },
      recompensas = { L"Recompensas y requisitos pendientes de confirmar." } },
    [2827] = { n = L"Powderfuse", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"Facción del puerto de Powderfuse en Clarofluvial (Riverglades).", L"Método de obtención de reputación pendiente de confirmar." },
      recompensas = { L"Recompensas y requisitos pendientes de confirmar." } },
    [2819] = { n = L"Los Vigilantes", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"Método de obtención de reputación pendiente de confirmar." },
      recompensas = { L"Anillos de nivel 60 documentados; disponibilidad y acceso pendientes de confirmar." } },
    [730] = { n = L"Guardia Pico Tormenta", fuente = L"Blizzard y datos de Forever", confirmado = false, lado = "A",
      subir = { L"Participar en el Valle de Alterac y completar objetivos y misiones; los ajustes del 25 de noviembre reducen la reputación por derrotar al general enemigo." },
      recompensas = { L"Equipo JcJ: comprobar los requisitos y el coste de cada pieza.", L"Exaltado: un punto de Legado por campo de batalla, compartido por la cuenta en los reinos no Extremo; no uno por cada facción." } },
    [729] = { n = L"Clan Lobo Gélido", fuente = L"Blizzard y datos de Forever", confirmado = false, lado = "H",
      subir = { L"Participar en el Valle de Alterac y completar objetivos y misiones; los ajustes del 25 de noviembre reducen la reputación por derrotar al general enemigo." },
      recompensas = { L"Equipo JcJ: comprobar los requisitos y el coste de cada pieza.", L"Exaltado: un punto de Legado por campo de batalla, compartido por la cuenta en los reinos no Extremo; no uno por cada facción." } },
    [890] = { n = L"Centinelas Ala de Plata", fuente = L"Blizzard y datos de Forever", confirmado = false, lado = "A",
      subir = { L"Participar en Garganta Grito de Guerra, capturar banderas y completar las misiones correspondientes." },
      recompensas = { L"Equipo JcJ: comprobar los requisitos y el coste de cada pieza.", L"Exaltado: un punto de Legado por campo de batalla, compartido por la cuenta en los reinos no Extremo; no uno por cada facción." } },
    [889] = { n = L"Escoltas Grito de Guerra", fuente = L"Blizzard y datos de Forever", confirmado = false, lado = "H",
      subir = { L"Participar en Garganta Grito de Guerra, capturar banderas y completar las misiones correspondientes." },
      recompensas = { L"Equipo JcJ: comprobar los requisitos y el coste de cada pieza.", L"Exaltado: un punto de Legado por campo de batalla, compartido por la cuenta en los reinos no Extremo; no uno por cada facción." } },
    [509] = { n = L"Liga de Arathor", fuente = L"Blizzard y datos de Forever", confirmado = false, lado = "A",
      subir = { L"Participar en Cuenca de Arathi, capturar y defender bases y completar las misiones correspondientes." },
      recompensas = { L"Equipo JcJ: comprobar los requisitos y el coste de cada pieza.", L"Exaltado: un punto de Legado por campo de batalla, compartido por la cuenta en los reinos no Extremo; no uno por cada facción." } },
    [510] = { n = L"Los Rapiñadores", fuente = L"Blizzard y datos de Forever", confirmado = false, lado = "H",
      subir = { L"Participar en Cuenca de Arathi, capturar y defender bases y completar las misiones correspondientes." },
      recompensas = { L"Equipo JcJ: comprobar los requisitos y el coste de cada pieza.", L"Exaltado: un punto de Legado por campo de batalla, compartido por la cuenta en los reinos no Extremo; no uno por cada facción." } },
    [749] = { n = L"Srs. del Agua de Hydraxis", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"La facción figura en los datos de Forever; su acceso, métodos y calendario de disponibilidad deben confirmarse." },
      recompensas = { L"Recetas y recompensas de reputación documentadas; acceso a las fuentes pendiente." } },
    [270] = { n = L"Tribu Zandalar", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"La facción figura en los datos de Forever; su acceso, métodos y calendario de disponibilidad deben confirmarse." },
      recompensas = { L"Recetas y recompensas de reputación documentadas; no se confirma su obtención actual." } },
    [910] = { n = L"Linaje de Nozdormu", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"La facción figura en los datos de Forever; su acceso, métodos y calendario de disponibilidad deben confirmarse." },
      recompensas = { L"Anillos de reputación presentes en los datos; obtención pendiente." } },
    [2740] = { n = L"Kirin Tor", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, lado = "A", pendiente = true,
      subir = { L"La facción figura en los datos de Forever; su acceso, métodos y calendario de disponibilidad deben confirmarse." },
      recompensas = { L"Patrones de profesión y recompensa de Exaltado documentados; comprobar acceso y coste." } },
    [2787] = { n = L"Anillo de la Tierra", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, lado = "H", pendiente = true,
      subir = { L"La facción figura en los datos de Forever; su acceso, métodos y calendario de disponibilidad deben confirmarse." },
      recompensas = { L"Patrones de profesión documentados; comprobar acceso y coste." } },
    [2765] = { n = L"Guardianes de Hyjal", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"La facción figura en los datos de Forever; su acceso, métodos y calendario de disponibilidad deben confirmarse." },
      recompensas = { L"Recompensas de Reverenciado y Exaltado documentadas; comprobar disponibilidad." } },
    [369] = { n = L"Gadgetzan", fuente = L"Forever: datos de facción y misiones", confirmado = false,
      subir = { L"Misiones de los goblins de Gadgetzan (Tanaris).", L"La reputación con los Bucaneros Velasangre puede ser incompatible con la de los cárteles goblin; comprueba las consecuencias antes de atacar." },
      recompensas = { L"Equipo con requisitos de reputación desde Amistoso; comprobar nivel, coste y disponibilidad de cada pieza." } },
    [470] = { n = L"Trinquete", fuente = L"Forever: datos de facción y misiones", confirmado = false,
      subir = { L"Misiones de los goblins de Trinquete (Los Baldíos).", L"La reputación con los Bucaneros Velasangre puede ser incompatible con la de los cárteles goblin; comprueba las consecuencias antes de atacar." },
      recompensas = { L"Equipo con requisitos de reputación desde Amistoso; comprobar nivel, coste y disponibilidad de cada pieza." } },
    [577] = { n = L"Vista Eterna", fuente = L"Forever: datos de facción y misiones", confirmado = false,
      subir = { L"Misiones de los goblins de Vista Eterna (Cuna del Invierno).", L"La reputación con los Bucaneros Velasangre puede ser incompatible con la de los cárteles goblin; comprueba las consecuencias antes de atacar." },
      recompensas = { L"Equipo con requisitos de reputación desde Amistoso; comprobar nivel, coste y disponibilidad de cada pieza." } },
    [2779] = { n = L"High Order", fuente = L"Forever: datos de facción y misiones", confirmado = false, lado = "A",
      subir = { L"Misiones de inicio de los Skyborne en Isla Zephras; no asumir que las misiones de otras capitales aumentan esta reputación.", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Genn Fairweather, instructor de equitación y vendedor de monturas en Isla Zephras",
      d = { m = 2521, x = 53.8, y = 81.3, n = "Genn Fairweather", z = L"Isla Zephras" },
      recompensas = { L"Genn Fairweather: descuento de equitación corregido tras el lanzamiento; consultar el precio real en el vendedor." } },
    [2778] = { n = L"Windshapers", fuente = L"Forever: datos de facción y misiones", confirmado = false, lado = "H",
      subir = { L"Misiones de inicio de los Skyborne en Isla Zephras; no asumir que las misiones de otras capitales aumentan esta reputación.", L"Donaciones únicas: 60 de lana, seda, tejido mágico y paño rúnico (150 de reputación cada una).", L"Tras las donaciones previas, desde nivel 50: 20 paños rúnicos por 50 de reputación base." },
      intendente = L"Genn Fairweather, instructor de equitación y vendedor de monturas en Isla Zephras",
      d = { m = 2521, x = 53.8, y = 81.3, n = "Genn Fairweather", z = L"Isla Zephras" },
      recompensas = { L"Genn Fairweather: descuento de equitación corregido tras el lanzamiento; consultar el precio real en el vendedor." } },
    [2747] = { n = L"Barkskin Burrow", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"Facción furbolg de Monte Hyjal documentada en los datos del cliente." },
      recompensas = { L"Método de obtención y disponibilidad de recompensas pendientes de verificar en Forever." } },
    [2719] = { n = L"Cenarion Scouts", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"Facción de exploradores del Círculo Cenarion documentada en los datos del cliente." },
      recompensas = { L"Método de obtención y disponibilidad de recompensas pendientes de verificar en Forever." } },
    [87] = { n = L"Bucaneros Velasangre", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"La reputación se relaciona con Bahía del Botín; atacar a sus guardias puede perjudicar gravemente las reputaciones goblin." },
      recompensas = { L"Recompensas de pirata documentadas; confirmar misiones y requisitos en Forever." } },
    [349] = { n = L"Ravenholdt", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"Facción vinculada a la Mansión Ravenholdt y a misiones de pícaro; comprobar métodos disponibles." },
      recompensas = { L"Método de obtención y disponibilidad de recompensas pendientes de verificar en Forever." } },
    [809] = { n = L"Shen'dralar", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"Misiones documentadas en La Masacre (Feralas); comprobar entregas y requisitos." },
      recompensas = { L"Método de obtención y disponibilidad de recompensas pendientes de verificar en Forever." } },
    [909] = { n = L"Feria de la Luna Negra", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, pendiente = true,
      subir = { L"Misiones y entregas de la feria; comprobar el calendario y la ubicación activos en Forever." },
      recompensas = { L"Método de obtención y disponibilidad de recompensas pendientes de verificar en Forever." } },
    [589] = { n = L"Instructores de sableinvernales", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, lado = "A", pendiente = true,
      subir = { L"Misiones de instructores de sableinvernales en Cuna del Invierno." },
      recompensas = { L"Montura de reputación documentada; comprobar requisitos actuales y precio." } },
    [630] = { n = L"Instructores de ravasaurios", fuente = L"Forever: datos del cliente; disponibilidad pendiente", confirmado = false, lado = "H", pendiente = true,
      subir = { L"Facción documentada en el Cráter de Un'Goro; comprobar acceso y misiones." },
      recompensas = { L"Método de obtención y disponibilidad de recompensas pendientes de verificar en Forever." } },
  }
end

------------------------------------------------------------------------
-- Lectura del juego
------------------------------------------------------------------------
local function Publico(v)
  return not (issecretvalue and issecretvalue(v))
end
local function Numero(v)
  return Publico(v) and type(v) == "number" and v == v and math.abs(v) < math.huge
end
local function Entero(v, min, max)
  return Numero(v) and v % 1 == 0 and v >= min and v <= max
end
local function Texto(v)
  return Publico(v) and type(v) == "string" and v ~= ""
end
local function Booleano(v)
  return Publico(v) and type(v) == "boolean"
end
local function Consulta(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok and Publico(v) then return v end
end
local function Faccion(nombre, rango, minimo, maximo, valor, cabecera, conRep, id)
  if not Texto(nombre) or not Booleano(cabecera) or (cabecera and (not Booleano(conRep) or conRep ~= true)) then return nil end
  local f = { nombre = nombre, rango = Entero(rango, 1, 8) and rango or nil,
    id = Entero(id, 1, 2147483647) and id or nil }
  if Numero(minimo) and Numero(maximo) and Numero(valor) and maximo >= minimo and valor >= minimo and valor <= maximo then
    f.min, f.max, f.valor = minimo, maximo, valor
  end
  return f
end
local function Moderno(d)
  if type(d) ~= "table" then return nil end
  return Faccion(d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding,
    d.isHeader, d.isHeaderWithRep, d.factionID)
end
local function Legado(fn, i)
  if type(fn) ~= "function" then return nil end
  local ok, nombre, _, rango, minimo, maximo, valor, _, _, cabecera, _, conRep, _, _, id = pcall(fn, i)
  if not ok then return nil end
  if Booleano(cabecera) and cabecera and Booleano(conRep) and not conRep then return nil, true end
  local f = Faccion(nombre, rango, minimo, maximo, valor, cabecera, conRep, id)
  return f, f ~= nil
end
local function InfoFaccion(i, moderna)
  if moderna then
    local d = Consulta(C_Reputation and C_Reputation.GetFactionDataByIndex, i)
    -- Una cabecera sin reputación es válida, no debe reinterpretarse con otro índice.
    if type(d) == "table" and Booleano(d.isHeader) and d.isHeader and Booleano(d.isHeaderWithRep) and not d.isHeaderWithRep then return nil, true end
    local f = Moderno(d)
    return f, f ~= nil
  end
  return Legado(GetFactionInfo, i)
end
local function LeerFuente(n, moderna)
  local lista, vistos, leidas = {}, {}, 0
  if not Entero(n, 0, 4096) then return lista, false end
  for i = 1, n do
    local f, ok = InfoFaccion(i, moderna)
    if ok then leidas = leidas + 1 end
    if f then
      local clave = f.id or f.nombre
      if not vistos[clave] then vistos[clave] = true; lista[#lista+1] = f end
    end
  end
  return lista, n == 0 or leidas > 0
end
local function LeerFacciones()
  local n = Consulta(C_Reputation and C_Reputation.GetNumFactions)
  if Entero(n, 0, 4096) and C_Reputation and type(C_Reputation.GetFactionDataByIndex) == "function" then
    local lista, ok = LeerFuente(n, true)
    if ok then return lista, true end
  end
  -- Cambiar de fuente completa, nunca mezclar índices de dos listas.
  return LeerFuente(Consulta(GetNumFactions), false)
end
local function FaccionPorID(id)
  if not Entero(id, 1, 2147483647) then return nil end
  local f = Moderno(Consulta(C_Reputation and C_Reputation.GetFactionDataByID, id))
  if f and f.id == id and f.rango then return f end
  local vieja = Legado(GetFactionInfoByID, id)
  if vieja and vieja.id == id and vieja.rango then return vieja end
  if f and f.id == id then return f end
end
local function Progreso(f)
  if not f.rango or not f.min or not f.max or not f.valor then return nil end
  local total, actual = f.max - f.min, f.valor - f.min
  if not Numero(total) or not Numero(actual) then return nil end
  if total > 0 then return actual / total, actual, total end
  if f.rango == 8 and actual == 0 then return 1 end
end
GL.LeerReputaciones977 = LeerFacciones
GL.ReputacionPorID977 = FaccionPorID

-- Requisitos estructurados: no inferir reputaciones a partir de descripciones de objetos.
local IDS_REP = { ["Ventormenta"]=72, ["Forjaz"]=47, ["Gnomeregan"]=54, ["Darnassus"]=69,
  ["Orgrimmar"]=76, ["Trols Lanza Negra"]=530, ["Cima del Trueno"]=81, ["Entrañas"]=68,
  ["Nightclaw Druids"]=2758, ["Azeroth Commerce Authority"]=2586, ["Durotar Supply and Logistics"]=2587,
  ["Autoridad Comercial de Azeroth"]=2586, ["Suministros y Logística de Durotar"]=2587 }
local RANGOS_REP = { ["Odiado"]=1, ["Hostil"]=2, ["Adverso"]=3, ["Neutral"]=4, ["Amistoso"]=5,
  ["Honorable"]=6, ["Venerado"]=7, ["Reverenciado"]=7, ["Exaltado"]=8 }
function GL.EstadoRequisitoReputacion977(rep)
  if type(rep) ~= "table" then return nil end
  local id = rep.id or IDS_REP[rep.n]
  local rango = RANGOS_REP[rep.nivel]
  if not Entero(id, 1, 2147483647) or not rango then return "desconocido" end
  local f = FaccionPorID(id)
  if not f or not f.rango then return "desconocido", id end
  return f.rango >= rango and "cumple" or "insuficiente", id
end
function GL.TextoEstadoReputacion977(estado)
  if estado == "cumple" then return L"Reputación requerida alcanzada." end
  if estado == "insuficiente" then return L"Reputación requerida aún no alcanzada." end
  if estado == "desconocido" then return L"Reputación actual sin confirmar." end
end

local function TextoProgreso(f)
  local _, actual, total = Progreso(f)
  if total and total > 0 then return tostring(actual) .. " / " .. tostring(total) end
  return ""
end
local LADOS = { [72]="A", [47]="A", [54]="A", [69]="A", [76]="H", [530]="H", [81]="H", [68]="H" }
local ZONAS = { [1429]="Bosque de Elwynn", [1426]="Dun Morogh", [1457]="Darnassus", [1454]="Orgrimmar", [1411]="Durotar", [1412]="Mulgore", [1420]="Claros de Tirisfal", [1451]="Silithus", [1422]="Tierras de la Peste del Oeste", [1448]="Frondavil" }
local function EstadoFaccion(ficha, id)
  local lado = ficha and ficha.lado or LADOS[id]
  if not lado then return nil end
  local actual = Consulta(UnitFactionGroup, "player")
  if actual ~= "Alliance" and actual ~= "Horde" then return "desconocido" end
  return actual == (lado == "A" and "Alliance" or "Horde") and "compatible" or "incompatible"
end
function GL.AvisoFaccion977(ficha, id)
  local estado = EstadoFaccion(ficha, id)
  if estado == "incompatible" then return L"Reputación de la facción contraria; comprueba las restricciones de acceso." end
  if estado == "desconocido" then return L"Facción del personaje sin confirmar." end
end
local function Destino(ficha, id)
  local d = ficha and not ficha.pendiente and ficha.d
  if type(d) ~= "table" or not Entero(d.m, 1, 2147483647) or not Numero(d.x) or not Numero(d.y) or d.x < 0 or d.x > 100 or d.y < 0 or d.y > 100 or (d.x == 0 and d.y == 0) or not Texto(d.n) then return nil end
  if GL.AvisoFaccion977(ficha, id) then return nil end
  local info = Consulta(C_Map and C_Map.GetMapInfo, d.m)
  local zona = type(info) == "table" and info.name or nil
  if not Texto(zona) then zona = d.z or (GL.LC or L)(ZONAS[d.m]) end
  if not Texto(zona) or not zona:find("%S") then return nil end
  return { m=d.m, x=d.x, y=d.y, n=d.n, z=zona }
end

local function Etiqueta(rango)
  if not Entero(rango, 1, 8) then return L"Reputación actual sin confirmar." end
  local t = _G["FACTION_STANDING_LABEL" .. rango]
  if GL.ingles == GL.clienteIngles and Texto(t) then return t end
  return L(RANGOS[rango]) or "?"
end

local function ColorRango(rango)
  if not Entero(rango, 1, 8) then return 0.5, 0.5, 0.5 end
  local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[rango]
  if type(c) == "table" and Numero(c.r) and Numero(c.g) and Numero(c.b) and c.r >= 0 and c.r <= 1 and c.g >= 0 and c.g <= 1 and c.b >= 0 and c.b <= 1 then return c.r, c.g, c.b end
  c = COLORES[rango] or COLORES[4]
  return c[1], c[2], c[3]
end

local function Hex(r, g, b)
  return string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

------------------------------------------------------------------------
-- Refrescar
------------------------------------------------------------------------
local function NombreFaccion(f)
  local ficha = FICHAS and f.id and FICHAS[f.id]
  if GL.ingles ~= GL.clienteIngles and ficha and Texto(ficha.n) then return ficha.n end
  return f.nombre
end

local function Ficha(f)
  local ficha = FICHAS and f.id and FICHAS[f.id]
  local r, g, b = ColorRango(f.rango)
  local _, actual, total = Progreso(f)
  ui.fichaTitulo:SetText(string.upper(NombreFaccion(f)))
  ui.fichaRango:SetText(Hex(r, g, b) .. Etiqueta(f.rango) .. C.FIN .. (total and total > 0 and (C.GRIS .. " · " .. actual .. " / " .. total .. C.FIN) or ""))
  local lineas = {}
  if not ficha then
    table.insert(lineas, C.GRIS .. L"Aún no hay ficha para esta facción." .. C.FIN)
  else
    if f.soloCatalogo then table.insert(lineas, C.GRIS .. L"Ficha del catálogo: progreso del personaje sin confirmar." .. C.FIN) end
    local aviso = GL.AvisoFaccion977(ficha, f.id)
    if aviso then table.insert(lineas, C.AMARILLO .. aviso .. C.FIN) end
    table.insert(lineas, C.AMARILLO .. L"Cómo subirla" .. C.FIN)
    for i = 1, #ficha.subir do table.insert(lineas, "• " .. ficha.subir[i]) end
    if ficha.intendente then
      table.insert(lineas, " ")
      table.insert(lineas, C.AMARILLO .. L"Intendente" .. C.FIN)
      table.insert(lineas, "• " .. C.AZUL .. ficha.intendente .. C.FIN)
    end
    if ficha.recompensas and #ficha.recompensas > 0 then
      table.insert(lineas, " ")
      table.insert(lineas, C.AMARILLO .. L"Recompensas" .. C.FIN)
      for i = 1, #ficha.recompensas do table.insert(lineas, "• " .. ficha.recompensas[i]) end
    end
    table.insert(lineas, " ")
    if ficha.pendiente then table.insert(lineas, C.AMARILLO .. L"Datos parciales: comprobar en Forever." .. C.FIN) end
    if ficha.fuente then
      table.insert(lineas, C.GRIS .. L"Fuente: " .. ficha.fuente .. C.FIN)
    else
    table.insert(lineas, C.GRIS .. L"Fuente: guías de reputación de Wowhead" .. (ficha.confirmado and ficha.d and L"; intendentes comprobados con QuestieDB (Forever)." or ".") .. C.FIN)
    end
  end
  ui.actualizarTexto(table.concat(lineas, "\n"), f.id or f.nombre)
  ui.llevarme.destino = Destino(ficha, f.id)
  GL.Mostrar(ui.llevarme, ui.llevarme.destino ~= nil and type(GL.SeguirDesvio) == "function")
  ui.ficha:Show()
end

local cache, disponibleCache, porID = nil, nil, {}
local espera, demora, sucio = 0, 0, true
local personaje = nil
local function Invalidar()
  cache, disponibleCache, porID = nil, nil, {}
  if not sucio then demora = 0 end
  sucio = true
end
local function Visible()
  return panel and panel:IsShown() and (not panel.IsVisible or panel:IsVisible())
end
local function Refrescar(reutilizar)
  if not Visible() then return end
  if not FICHAS then FICHAS = CargarFichas() end
  if not reutilizar or not cache then
    cache, disponibleCache = LeerFacciones()
    porID = {}
    espera, demora, sucio = 0, 0, false
  end
  local lista, disponible = cache, disponibleCache
  desde = math.max(0, math.min(desde, #lista - FILAS))
  local elegida = nil
  for i = 1, #lista do
    if sel and (lista[i].id or lista[i].nombre) == sel then elegida = lista[i] end
  end
  if not elegida and type(sel) == "number" then
    if porID[sel] == nil then porID[sel] = FaccionPorID(sel) or false end
    elegida = porID[sel] or nil
    if not elegida and FICHAS[sel] then
      elegida = { id = sel, nombre = FICHAS[sel].n, soloCatalogo = true }
    end
  end
  if not elegida and lista[1] and not sel then elegida = lista[1]; sel = lista[1].id or lista[1].nombre end
  for i = 1, FILAS do
    local fila, f = ui.filas[i], lista[desde + i]
    fila.faccion = f
    if f then
      local r, g, b = ColorRango(f.rango)
      local progreso = Progreso(f)
      fila.nombre:SetText(NombreFaccion(f))
      fila.barra:SetStatusBarColor(r, g, b, 0.95)
      fila.barra:SetValue(progreso or 0)
      fila.barra.texto:SetText(TextoProgreso(f))
      GL.Mostrar(fila.barra, progreso ~= nil)
      fila.rango:SetText(Hex(r, g, b) .. Etiqueta(f.rango) .. C.FIN)
      fila.ayudaTitulo = NombreFaccion(f)
      local valor = TextoProgreso(f)
      fila.ayudaTexto = Etiqueta(f.rango) .. (valor ~= "" and " · " .. valor or "")
      GL.Mostrar(fila.marca, f == elegida)
      fila:Show()
    else
      fila.barra.texto:SetText("")
      fila.ayudaTitulo, fila.ayudaTexto = nil, nil
      fila:Hide()
    end
  end
  if #lista > FILAS then
    ui.mas:SetText(C.GRIS .. L"Facciones " .. (desde + 1) .. "-" .. math.min(#lista, desde + FILAS) .. L" de " .. #lista .. L" (rueda del ratón)" .. C.FIN)
  elseif #lista == 0 then
    ui.mas:SetText(C.GRIS .. (disponible and L"El juego aún no muestra ninguna reputación." or L"Reputaciones: lectura no disponible.") .. C.FIN)
  else
    ui.mas:SetText("")
  end
  if elegida then Ficha(elegida) else ui.llevarme.destino = nil; ui.ficha:Hide() end
end

------------------------------------------------------------------------
-- Crear
------------------------------------------------------------------------
local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)   -- sin pestañas: empieza bajo la cabecera
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()

  local titulo = GL.Texto(panel, "GameFontNormal")
  titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  titulo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0); GL.UnaLinea(titulo)   -- 7.6.1: dentro del marco
  titulo:SetText(L"Tus reputaciones " .. C.GRIS .. L"(las lee del juego)" .. C.FIN)

  for i = 1, FILAS do
    local f = CreateFrame("Button", nil, panel)
    f:SetHeight(ALTO_FILA)
    f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -20 - (i - 1) * ALTO_FILA)
    f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -20 - (i - 1) * ALTO_FILA)
    f.marca = f:CreateTexture(nil, "BACKGROUND")
    f.marca:SetAllPoints()
    f.marca:SetColorTexture(1, 0.82, 0, 0.12)
    f.marca:Hide()
    local brillo = f:CreateTexture(nil, "HIGHLIGHT")
    brillo:SetAllPoints()
    brillo:SetColorTexture(1, 1, 1, 0.06)
    f.nombre = GL.Texto(f, "GameFontHighlightSmall")
    f.nombre:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.nombre:SetWidth(122)
    GL.UnaLinea(f.nombre)
    f.rango = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
    f.rango:SetPoint("RIGHT", f, "RIGHT", -2, 0)
    f.rango:SetWidth(78)
    GL.UnaLinea(f.rango)
    f.barra = GL.CrearBarra(f, 0, 0.6, 0.1)
    f.barra:SetHeight(14)
    f.barra:SetPoint("LEFT", f, "LEFT", 130, 0)
    f.barra:SetPoint("RIGHT", f.rango, "LEFT", -6, 0)
    f.barra.texto:ClearAllPoints()
    f.barra.texto:SetPoint("LEFT", f.barra, "LEFT", 2, 0)
    f.barra.texto:SetPoint("RIGHT", f.barra, "RIGHT", -2, 0)
    GL.UnaLinea(f.barra.texto)
    f.barra.texto:SetJustifyH("CENTER")
    if GL.Ayuda then GL.Ayuda(f) end
    f:SetScript("OnClick", function(self)
      if not self.faccion then return end
      sel = self.faccion.id or self.faccion.nombre
      Refrescar(true)
    end)
    ui.filas[i] = f
  end
  ui.mas = GL.Texto(panel, "GameFontHighlightSmall")
  ui.mas:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22 - FILAS * ALTO_FILA)
  ui.mas:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -22 - FILAS * ALTO_FILA); GL.UnaLinea(ui.mas)   -- 7.6.1: dentro del marco

  -- ficha de la facción pulsada
  local ficha = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ficha:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -40 - FILAS * ALTO_FILA)
  ficha:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
  if GL.Caja and GL.COLOR then GL.Caja(ficha, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  local borde = ficha:CreateTexture(nil, "ARTWORK")   -- línea dorada a la izquierda, como la caja del paso
  borde:SetWidth(3)
  borde:SetPoint("TOPLEFT", ficha, "TOPLEFT", 0, 0)
  borde:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 0, 0)
  borde:SetColorTexture(1, 0.78, 0.25, 1)
  ui.ficha = ficha
  ui.fichaTitulo = GL.Texto(ficha, "GameFontNormalSmall")
  ui.fichaTitulo:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -8)
  ui.fichaTitulo:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -8)
  ui.fichaTitulo:SetHeight(28)
  if ui.fichaTitulo.SetWordWrap then ui.fichaTitulo:SetWordWrap(true) end
  if ui.fichaTitulo.SetMaxLines then ui.fichaTitulo:SetMaxLines(2) end
  ui.fichaRango = GL.Texto(ficha, "GameFontHighlightSmall", "RIGHT")
  ui.fichaRango:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -38)
  ui.fichaRango:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -38)
  GL.UnaLinea(ui.fichaRango)
  if GL.CrearTextoDesplazableR10 then
    ui.fichaTexto, ui.actualizarTexto = GL.CrearTextoDesplazableR10(ficha, 55, 30)
  else
    ui.fichaTexto = GL.Texto(ficha, "GameFontHighlightSmall")
    ui.fichaTexto:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -55)
    ui.fichaTexto:SetPoint("BOTTOMRIGHT", ficha, "BOTTOMRIGHT", -8, 30)
    ui.actualizarTexto = function(t) ui.fichaTexto:SetText(t) end
  end
  ui.llevarme = GL.CrearBoton(ficha, L"Llevarme al intendente", function()
    local d = type(sel) == "number" and Destino(FICHAS and FICHAS[sel], sel)
    if d and type(GL.SeguirDesvio) == "function" then GL.SeguirDesvio(d) end
  end, nil, 20)
  ui.llevarme:SetWidth(150)
  ui.llevarme:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 12, 6)
  ui.llevarme:Hide()

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    desde = math.max(0, desde - delta * 2)
    Refrescar(true)
  end)
  local eventos = { UPDATE_FACTION=true, PLAYER_ENTERING_WORLD=true, PLAYER_LOGIN=true,
    PLAYER_LEVEL_UP=true, MAJOR_FACTION_RENOWN_LEVEL_CHANGED=true, UPDATE_FACTION_STANDING=true }
  for evento in pairs(eventos) do pcall(panel.RegisterEvent, panel, evento) end
  panel:SetScript("OnEvent", function(_, evento, inicial)
    if not eventos[evento] then return end
    local guid = Consulta(UnitGUID, "player")
    local cambio = Texto(guid) and personaje and guid ~= personaje
    if Texto(guid) then personaje = guid end
    if cambio or evento == "PLAYER_LOGIN" or (evento == "PLAYER_ENTERING_WORLD" and Booleano(inicial) and inicial) then
      desde, sel = 0, nil
      -- No permitir una ruta de la selección anterior durante la carga.
      ui.llevarme.destino = nil
      ui.ficha:Hide()
      for _, fila in ipairs(ui.filas) do
        fila.faccion = nil; fila.barra.texto:SetText(""); fila:Hide()
      end
      ui.mas:SetText("")
    end
    Invalidar()
  end)
  panel:SetScript("OnShow", function()
    local guid = Consulta(UnitGUID, "player")
    if Texto(guid) then
      if personaje and guid ~= personaje then desde, sel = 0, nil end
      personaje = guid
    end
    Invalidar()
    Refrescar()
  end)
  panel:SetScript("OnHide", function()
    Invalidar(); espera, demora = 0, 0
  end)
  panel:SetScript("OnUpdate", function(_, dt)
    if not Visible() or not Numero(dt) or dt < 0 then return end
    espera = espera + dt
    if sucio then demora = demora + dt end
    if espera >= CADA or (sucio and demora >= DEMORA) then Refrescar() end
  end)
  GL.modos.reputacion = { panel = panel, refrescar = Refrescar }
end

-- 9.0: se crea al abrirla por primera vez (Ajustes › General › Cargar cada sección al abrirla)
GL.perezosos = GL.perezosos or {}
GL.perezosos.reputacion = CrearPanel
table.insert(GL.alIniciar, function() if type(GuiaAventureroDB) == "table" and GuiaAventureroDB.cargarAlAbrir == false then CrearPanel() end end)

-- 6.8: la Biblioteca usa las mismas fichas y abre una facción aquí.
GL.DatosReputacion = CargarFichas
GL._reputacion977 = { Progreso=Progreso, Etiqueta=Etiqueta, Color=ColorRango, Leer=LeerFacciones, PorID=FaccionPorID, TextoProgreso=TextoProgreso, Destino=Destino }
GL.AbrirFaccion = function(id)
  sel = id
  if GL.AbrirModo then GL.AbrirModo("reputacion") end
end

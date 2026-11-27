-- Mazmorras.lua: guía de mazmorras (6.7). Se abre con el botón Mazmorras del lateral derecho.
-- Lista de mazmorras por nivel; al pulsar una se despliega: entrada, misiones de tu facción (8.5: también de la Horda) y botones
-- Marcar entrada (punto del mapa del mundo) y Llevarme (la flecha, como un desvío, sin perder el paso).
-- Solo lee datos: no cambia la ruta ni el progreso. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local ALTO_FILA = 18
local ALTO_LINEA = 14
local CADA = 2

local panel, ui = nil, { filas = {} }
local desde, abierta = 0, nil     -- primera mazmorra visible y la desplegada (índice)
local px = 0                      -- 9.4.2: cuánto se ha bajado la lista, en píxeles
local jefeAbierto = nil           -- 7.5.16: jefe desplegado de la mazmorra abierta (índice)
local DATOS = nil                 -- se rellenan al abrir el panel por primera vez
local arribaL = 20                -- 9.6: dónde empieza la lista (más abajo con la tarjeta «Para tu nivel ahora»)
local clara = {}                  -- 9.6: tarjeta y desplegable con la Guía clara

------------------------------------------------------------------------
-- Datos (bajo demanda). 7.6: de Wowhead (Forever), sin comprobar en el juego. e = entrada { m = uiMapID, x, y } con las coordenadas de ese mapa (0-100).
-- Misiones: n = nombre, d = quién la da y dónde, q = id (solo si es seguro: sirve para decir si la llevas).
------------------------------------------------------------------------
local function CargarDatos()
  -- 7.6: niveles, entradas y misiones de la Alianza sacados de las guías de Wowhead (Forever). Nombres en español
  -- cuando la guía en español los trae; si no, en inglés (no se traducen a mano). Sin comprobar en el juego. q = id de la misión (sirve para decir si la llevas o ya la hiciste).
  return {
    { n = "Cavernas de los Lamentos", min = 15, max = 25, z = L"Los Baldíos (oasis al suroeste del Cruce)", e = { m = 1413, x = 45.5, y = 35.5 },
      misiones = { { n = L"Pellejo de los descarriados", q = 1486, d = L"Nalpak, en la cueva sobre la entrada" },
        { n = L"Erradicación de descarriados", q = 1487, d = L"Ebru, en la cueva sobre la entrada" },
        { n = L"Las bebidas astutas", q = 1491, d = L"Mebok Mizzyrix, en Trinquete" },
        { n = L"¡A por la botella!", q = 959, d = L"Operador de grúa Pelardo, en Trinquete" },
        { n = L"El fragmento brillante", q = 6981, d = L"La suelta Mutanus el Devorador" } } },
    { n = "Las Minas de la Muerte", min = 18, max = 23, z = L"Páramos de Poniente (Arroyo de la Luna)", e = { m = 1436, x = 42.4, y = 70.4 },
      misiones = { { n = L"La hermandad de los Defias", q = 166, d = L"Gryan Mantorrecio, en la Colina del Centinela (final de la cadena)" },
        { n = L"Pañuelos rojos de seda", q = 214, d = L"Exploradora Riell, en la torre de la Colina del Centinela" },
        { n = L"Destrucción en las Minas de la Muerte", q = 92753, d = L"Alba Fairmoon, en la Colina del Centinela" },
        { n = L"La recolección de Tarjetas del Sindicato Minero", q = 168, d = L"Wilder Cardortiga, en Ventormenta (Distrito de los Enanos)" },
        { n = L"Oh hermano. . .", q = 167, d = L"Wilder Cardortiga, en Ventormenta (Distrito de los Enanos)" },
        { n = L"Asalto subterráneo", q = 2040, d = L"Shoni la Silenciosa, en Ventormenta (Distrito de los Enanos)" },
        { n = L"La carta sin enviar", q = 373, d = L"La suelta Edwin VanCleef" } } },
    { n = "Castillo de Colmillo Oscuro", min = 22, max = 30, z = L"Bosque de Argénteos (al norte de Aldea Piroleña)", e = { m = 1421, x = 42.6, y = 66.6 },
      misiones = { { n = L"La prueba de rectitud", q = 1654, d = L"Jordan Fontana, en Forjaz junto a las puertas" } },
      nota = L"Casi todas las misiones de aquí son de la Horda." },
    { n = "Mazmorras de Ventormenta", min = 24, max = 30, z = L"Ciudad de Ventormenta", e = { m = 1453, x = 41.0, y = 57.0 },
      misiones = { { n = L"Lo que sucece alrededor…", q = 386, d = L"Guardia Berton, en Villa del Lago" },
        { n = L"Crimen y castigo", q = 377, d = L"Concejal Millstipe, en Villa Oscura" },
        { n = L"La furia mora en las profundidades", q = 378, d = L"Motley Garmason, en Dun Modr" },
        { n = L"Detener el motín", q = 387, d = L"Celador Thelwater, en la entrada" },
        { n = L"El color de la sangre", q = 388, d = L"Nikova Raskol, en Ventormenta" },
        { n = L"El motín de las Mazmorras", q = 391, d = L"Celador Thelwater, en la entrada" } } },
    { n = "Cavernas de Brazanegra", min = 24, max = 32, z = L"Vallefresno (Playa de Zoram)", e = { m = 1440, x = 13.4, y = 12.8 },
      misiones = { { n = L"Investigaciones acerca de la corrupción", q = 1275, d = L"Gershala Noctusurro, en Auberdine" },
        { n = L"El conocimiento de las profundidades", q = 971, d = L"Gerrig Agarrahueso, en Forjaz (Cueva Abandonada)" },
        { n = L"Buscando a Thaelrid", q = 1198, d = L"Shaedlass Guardalbas, en Darnassus (Bancal del Artesano)" },
        { n = L"La vileza de Brazanegra", q = 1200, d = L"Guardia Argenta Thaelrid, dentro de la mazmorra" },
        { n = L"Cascada del Crepúsculo", q = 1199, d = L"Guardia Argenta Manados, en Darnassus" },
        { n = "The Heart of the Void", q = 78916, d = L"Empieza con la Perla de Brazanegra perfecta (en el cadáver de Aku'mai); se entrega a Selgorm Guardalbas, en Darnassus", nueva = true } } },
    { n = "Excavación", min = 26, max = 33, z = L"Los Humedales (en lo alto de la colina)", e = { m = 1437, x = 48.1, y = 56.5 }, nueva = true,
      misiones = { { n = L"En busca de Filosón", q = 95772, d = L"Dorin Filosón, en las Montañas Crestagrana" },
        { n = L"Perdido en la espesura", q = 95647, d = L"Caitlin, tras «En busca de Caitlin» que da Llana en Vallefresno" },
        { n = L"Pellejos de las Tierras Altas", q = 98815, d = L"James Halloran, en Puerto de Menethil" },
        { n = L"Horrores en las Tierras Altas", q = 95646, d = L"Rethiel el Guardaverde, en Los Humedales" },
        { n = L"Transporte de reliquia perdida", q = 95810, d = L"Botín de la Reliquia titánica, dentro (sigue: Prisma prehistórico)" },
        { n = L"En busca de Caitlin", q = 95737, d = L"Llana, en Vallefresno", nueva = true },
        { n = L"Muerte en el pantano", q = 95795, d = L"Dorin Filosón, en Villa del Lago (Montañas Crestagrana)", nueva = true },
        { n = L"Tejido en el corazón", q = 95809, d = L"Caitlin Grassman, en Puerto de Menethil (Los Humedales)", nueva = true },
        { n = L"Prisma prehistórico", q = 98824, d = L"Prospector Whelgar, en Los Humedales", nueva = true } } },
    { n = "Ciudad de Dalaran", min = 28, max = 35, z = L"Montañas de Alterac (alcantarillas)", e = { m = 1416, x = 14.3, y = 59.6 }, nueva = true,
      misiones = { { n = L"Una petición alarmante", q = 92432, d = L"Emisario Jacques, en Costasur (empieza la armonización)" },
        { n = L"Arcana famélica", q = 92457, d = L"Imagen de la archimaga Modera, junto a la entrada" },
        { n = L"El corazón de la perturbación", q = 92458, d = L"Imagen de la archimaga Modera, Bosque de Argénteos (68.6, 45.2)" },
        { n = L"Poder sobrecogedor", q = 92489, d = L"Alto hechicero Andromath, en Ventormenta" },
        { n = L"Una muestra verde", q = 92456, d = L"Shylamiir, en Ventormenta" },
        { n = "Unstable Magic", q = 96603, d = L"Archimaga Celindra, en Montañas de Alterac", nueva = true },
        { n = L"El sabor del hogar", q = 96609, d = L"Arille Mirada Azur, en Montañas de Alterac", nueva = true },
        { n = "Thicker Than Water", q = 96812, d = L"Sergeant Danneth, dentro de la mazmorra", nueva = true } },
      },
    { n = "Monasterio Escarlata", min = 30, max = 46, z = L"Claros de Tirisfal", e = { m = 1420, x = 83.5, y = 32.0 },
      misiones = { { n = L"Mitología de los Titanes", q = 1050, d = L"Bibliotecaria Mae Palipolvo, en Forjaz (Biblioteca)" },
        { n = L"Fuera de plazo", q = 96800, d = L"Magus Olvek, en Dalaran (Biblioteca)" },
        { n = L"Hermano Antón", q = 6141, d = L"Hermano Cuerviz, en la catedral de Ventormenta (opcional)" },
        { n = L"El sendero Escarlata", q = 261, d = L"Hermano Antón, en la Atalaya de Nijel (Desolace)" },
        { n = L"En el nombre de la Luz", q = 1053, d = L"Raleigh el Devoto, en Costasur (Catedral)" } },
      },
    { n = "Gnomeregan", min = 29, max = 38, z = "Dun Morogh", e = { m = 1426, x = 30.5, y = 36.3 },
      misiones = { { n = L"¡Salva el cerebro de Techrobot!", q = 2922, d = L"Maestro manitas Sobrechispa, en Forjaz (Ciudad Manitas)" },
        { n = "Gnogaine", q = 2926, d = L"Oci Voltiflop, en Kharanos" },
        { n = L"Necesitamos más material verdoso", q = 2962, d = L"Oci Voltiflop, en Kharanos" },
        { n = "Gyrodrillmatic Excavationators", q = 2928, d = L"Shoni la Silenciosa, en Ventormenta" },
        { n = L"Esencias artificiales", q = 2924, d = L"Klockmort Palmalicate, en Forjaz (Ciudad Manitas)" },
        { n = L"Rescatar los datos", q = 2930, d = L"Maestro mecánico Funditubo, en Forjaz (Ciudad Manitas)" },
        { n = L"La gran traición", q = 2929, d = L"Manitas mayor Mekkatorque, en Forjaz (Ciudad Manitas)" },
        { n = L"Un buen lío", q = 2904, d = L"Kernobee, dentro de la mazmorra (escolta)" } },
      },
    { n = "Horado Rajacieno", min = 30, max = 40, z = L"Los Baldíos (sur)", e = { m = 1413, x = 42.6, y = 88.5 },
      misiones = { { n = L"Los tubérculos hojazul", q = 1221, d = L"Mebok Mizzyrix, en Trinquete" },
        { n = L"Decaída mortal", q = 1142, d = L"Heralath Arroyobarbecho, dentro de la mazmorra" },
        { n = L"Willix el Importador", q = 1144, d = L"Willix, en la tienda junto al último jefe" },
        { n = L"La bruja del Horado", q = 1101, d = L"Díscolo Falfildel, en Feralas" } } },
    { n = "La Ciudad Sumergida", min = 35, max = 40, z = L"Vega de Tuercespina (cueva en el mar, al sur de la Isla Encantada)", e = { m = 1434, x = 21.4, y = 27.9 }, nueva = true,
      misiones = { { n = L"La magia de la Ciudad Sumergida", q = 95788, d = L"Maestro cultural Dibbs, en Costasur" },
        { n = L"Segunda prueba con el agua", q = 95787, d = L"Maestro cultural Dibbs, en Costasur" },
        { n = L"Antiguos secretos Gurubashi", q = 97130, d = L"Archimago Tiemporeja, en Dalaran" },
        { n = L"Videntesal sospechosos", q = 95789, d = L"Krazek, en Bahía del Botín" },
        { n = "El capitán Videntesal", q = 95791, d = L"Krazek, en Bahía del Botín" } } },
    { n = "Bastión Krol'dok", min = 40, max = 45, z = L"Clarofluvial (al norte de Sunnyglade; vuelo a Farholde Keep, o a pie desde Crestagrana)", nueva = true,
      e = { nombres = { "Clarofluvial", "Riverglades" }, x = 37.5, y = 37.5 },
      misiones = { { n = L"La venganza del Altonato", q = 96771, d = L"Ranath Zancanoche, en Dalaran" },
        { n = L"Recuerdos Crepusculares", q = 94983, d = L"Sargento Riftan, en Clarofluvial (Twilight's Shroud)" },
        { n = L"El ojo de Mugg", q = 94982, d = L"Demar Brant, en Clarofluvial (Farholde Keep)" },
        { n = L"El escrito del Crepúsculo", q = 94984, d = L"Ashe Amberhall, en Clarofluvial (Farholde Keep)" },
        { n = "Kroldok Moulding", q = 94980, d = L"La suelta Tunk, dentro (sigue: Key Ingredients)" } } },
    { n = "Zahúrda Rajacieno", min = 40, max = 50, z = L"Los Baldíos (sur, junto a Las Mil Agujas)", e = { m = 1413, x = 50.0, y = 92.0 },
      misiones = { { n = L"Un anfitrión del mal", q = 6626, d = L"Myriam Cantolunar, en la entrada" },
        { n = L"La plaga de la Zahúrda", q = 3523, d = L"Belnistrasz, dentro de la mazmorra" },
        { n = L"Extinguir el ídolo", q = 3525, d = L"Belnistrasz, dentro de la mazmorra" },
        { n = L"Trae la Luz", q = 3636, d = L"Arzobispo Benedictus, en Ventormenta (Catedral de la Luz)" },
        { n = L"El ojo del Gélido", q = 96773, d = L"Archimago Lan'dalock, en Dalaran" } } },
    { n = "Uldaman", min = 42, max = 52, z = L"Tierras Inhóspitas (frontera con Loch Modan)", e = { m = 1418, x = 42.6, y = 10.8 },
      misiones = { { n = L"Los enanos desaparecidos", q = 2398, d = L"Prospector Pico Tormenta, en Forjaz" },
        { n = L"La cámara oculta", q = 2240, d = L"Diario de Baelog, dentro de la mazmorra" },
        { n = L"Los tesoros reclamados", q = 1360, d = L"Krom Brazorrecio, en Forjaz" },
        { n = L"Las piedras de energía", q = 2418, d = L"Aparejez, en Tierras Inhóspitas" },
        { n = L"La solución a la maldición", q = 709, d = L"Theldurin el Perdido, en Tierras Inhóspitas" },
        { n = L"El sino de Agmond", q = 704, d = L"Prospector Vetaferro, en Loch Modan" },
        { n = L"Componentes de Uldaman", q = 17, d = L"Ghak Sanadón, en Thelsamar" },
        { n = L"El amuleto de los secretos", q = 722, d = L"Prospector Ryedol, en la cueva junto a la entrada" },
        { n = L"Las tablillas perdidas de Voluntad", q = 1139, d = L"Historiador Karnik, en Forjaz" },
        { n = L"Los discos de platino", q = 2278, d = L"Discos de Norgannon, dentro tras Archaedas" } } },
    { n = "Zul'Farrak", min = 44, max = 54, z = "Tanaris", e = { m = 1446, x = 39.5, y = 21.3 },
      misiones = { { n = L"Temple trol", q = 3042, d = L"Trenton Mazaligera, en Gadgetzan" },
        { n = L"Caparazones de escarabajo", q = 2865, d = L"Tran'rek, en Gadgetzan" },
        { n = L"Tiara de la Profundidad", q = 2846, d = L"Tabetha, en el Marjal Revolcafango" },
        { n = "Gahz'rilla", q = 2770, d = L"Wizzle Pernolatón, en Las Mil Agujas (El Desierto de Sal)" },
        { n = L"Cetro Divinomático", q = 2768, d = L"Ingeniero jefe Silvaina, en Gadgetzan" },
        { n = L"La profecía de Mosh'aru", q = 3527, d = L"Yeh'kinya, en Puerto Bonvapor" },
        { n = L"La cabeza del médico brujo", q = 96770, d = L"Archimago Lan'dalock, en Montañas de Alterac", nueva = true } } },
    { n = "Maraudon", min = 45, max = 57, z = L"Desolace (Valle de las Lanzas)", e = { m = 1443, x = 29.5, y = 57.8 },
      misiones = { { n = L"La corrupción de Lenguavil", q = 7041, d = L"Talendria, en la Atalaya de Nijel" },
        { n = L"Corrupción de la tierra y de la semilla", q = 7065, d = L"Vigilante Marandis, en la Atalaya de Nijel" },
        { n = L"Leyendas de Maraudón", q = 7044, d = L"Cavindra, en la entrada (lado naranja)" },
        { n = L"Los males de Maraudón", q = 7028, d = L"Willow, en Desolace" },
        { n = L"Las instrucciones del Paria", q = 7067, d = L"Paria centauro, en Desolace" },
        { n = L"Fragmentos Oscuros", q = 7070, d = L"Archimago Tervosh, en Theramore" },
        { n = L"El cetro de Celebras", q = 7046, d = L"Celebras el Redimido, dentro (lado morado)" },
        { n = L"La semilla de la vida", q = 7066, d = L"Espíritu de Zaetar, dentro tras la princesa Theradras" } } },
    { n = "Prisión de Alcaz", min = 48, max = 53, z = L"Marjal Revolcafango (Isla de Alcaz)", e = { m = 1445, x = 75.0, y = 15.0 }, nueva = true,
      misiones = { { n = "The Dragon's Journal", q = 96772, d = L"Se consigue en Dalaran" },
        { n = "The Man in the Iron Chains", q = 96335, d = L"Mason Connery, dentro (con la llave que suelta El Interrogador)" } },
      estadoForever977 = L"Prisión de Alcaz: disponible en Forever. Botín parcial documentado; mapa pendiente de comprobar." },
    { n = "Templo de Atal'Hakkar", min = 50, max = 60, z = L"Pantano de las Penas (en el lago)", e = { m = 1435, x = 69.6, y = 53.2 },
      misiones = { { n = L"En El Templo de Atal'Hakkar", q = 1475, d = L"Brohann Barriliga, en Ventormenta" },
        { n = L"El profeta Jammal'an", q = 1446, d = L"Exiliado Atal'ai, en Tierras del Interior" },
        { n = L"En las profundidades", q = 3446, d = L"Marvon Buscarroblones, en Tanaris" },
        { n = L"El secreto del círculo", q = 3447, d = L"Marvon Buscarroblones, en Tanaris" },
        { n = L"Bruma del mal", q = 4143, d = L"Gregan Tirabirras, en Feralas" },
        { n = L"El dios Hakkar", q = 3528, d = L"Yeh'kinya, en Puerto Bonvapor" },
        { n = L"La esencia de Eranikus", q = 3373, d = L"La suelta la Sombra de Eranikus" },
        { n = L"Eranikus, el Tirano del Sueño", q = 8733, d = L"Malfurion Tempestira, dentro de la mazmorra", nueva = true } } },
    { n = "Profundidades de Roca Negra", min = 52, max = 60, z = L"Montaña Roca Negra (por la Garganta de Fuego o Las Estepas Ardientes)", e = { m = 1427, x = 35.2, y = 84.2 },
      misiones = { { n = L"El legado de los Hierro Negro", q = 3802, d = L"Franclorn Forjador, en Montaña Roca Negra (solo se ve muerto)" },
        { n = L"El Corazón de la Montaña", q = 4123, d = L"Maxwort Suprandor, en Las Estepas Ardientes" },
        { n = L"Un sabor a llamarada", q = 4024, d = L"Cyrus Therepentio, en Las Estepas Ardientes" },
        { n = L"¡Incendius!", q = 4263, d = L"Jalinda Espiga, en Las Estepas Ardientes" },
        { n = L"Buena mercancía", q = 4286, d = L"Jalinda Espiga, en Las Estepas Ardientes" },
        { n = L"Ribbly Llavenrosca", q = 4136, d = L"Yorba Llavenrosca, en Tanaris" },
        { n = L"Hurley Negrálito", q = 4126, d = L"Enohar Cebatruenos, en Las Tierras Devastadas" },
        { n = L"Kharan Martillazo", q = 4341, d = L"Rey Magni Barbabronce, en Forjaz" },
        { n = L"El destino del reino", q = 4362, d = L"Rey Magni Barbabronce, en Forjaz" },
        { n = L"La poción de enamoramiento", q = 4201, d = L"Maestra Nagmara, dentro (Tabernas del Rencor)" },
        { n = L"Armonización con el Núcleo", q = 7848, d = L"Lothos Levantagrietas, en Montaña Roca Negra" },
        { n = L"El cáliz espectral", q = 4083, d = L"Cáliz espectral, dentro de la mazmorra", nueva = true },
        { n = L"Ragnar Cebatruenos", q = 4128, d = L"Enohar Cebatruenos, dentro de la mazmorra", nueva = true },
        { n = L"El alguacil Windsor", q = 4241, d = L"Mariscal Maxwell, dentro de la mazmorra", nueva = true },
        { n = L"Esperanza perdida", q = 4242, d = L"Alguacil Windsor, dentro de la mazmorra", nueva = true },
        { n = L"Una nota arrugada", q = 4264, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"Una brizna de esperanza", q = 4282, d = L"Alguacil Windsor, dentro de la mazmorra", nueva = true },
        { n = L"Yuka Llavenrosca", q = 4324, d = L"Yorba Llavenrosca, en Tanaris", nueva = true },
        { n = L"Portador de malas noticias", q = 4361, d = L"Kharan Martillazo, dentro de la mazmorra", nueva = true },
        { n = L"La sorpresa de la princesa", q = 4363, d = L"Princesa Moira Barbabronce, dentro de la mazmorra", nueva = true },
        { n = L"Un contrato vinculante", q = 7604, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"El reto", q = 9015, d = L"Falrin Tallarbol, dentro de la mazmorra", nueva = true } } },
    { n = "Cumbre de Roca Negra", min = 55, max = 60, z = L"Montaña Roca Negra (por la Garganta de Fuego o Las Estepas Ardientes)", e = { m = 1427, x = 35.2, y = 84.2 },
      misiones = { { n = L"Acaba con el origen de la amenaza", q = 4701, d = L"Helendis Rivacuerno, en Las Estepas Ardientes (inferior)" },
        { n = L"Las pertenencias de Bijou", q = 5001, d = L"Bijou, dentro (inferior)" },
        { n = L"Bestia amaestrada", q = 4862, d = L"Kibler, en Flame Crest (inferior)" },
        { n = L"Las mascotas exóticas de Kibler", q = 4729, d = L"Kibler, en Flame Crest (inferior)" },
        { n = L"La leche de la madre", q = 4866, d = L"John Andrajoso, en Flame Crest (inferior)" },
        { n = L"Urok Aullasino", q = 4867, d = L"Warosh, dentro (inferior)" },
        { n = L"El sello de ascensión", q = 4742, d = L"Vaelan, dentro (inferior; llave de la superior)" },
        { n = L"Las últimas tablillas", q = 4788, d = L"Prospector Ferrobota, en Tanaris (inferior)" },
        { n = L"Orden del general Drakkisath", q = 5089, d = L"La suelta el Señor Supremo Vermiothalak (inferior)" },
        { n = L"Muerte al general Drakkisath", q = 5102, d = L"Alguacil Maxwell, en la Vigilia de Morgan (superior)" },
        { n = L"El Broche de Equipasino", q = 4764, d = L"Mayara Alasol, en la Vigilia de Morgan (superior)" },
        { n = L"Amuleto Pirodraco", q = 6502, d = L"Haleh, en Cuna del Invierno (superior)" },
        { n = L"La orden de Puño Negro", q = 7761, d = L"Objeto del Intendente Escudo del Estigma (superior)" },
        { n = L"El Protectorado de la matrona", q = 5160, d = L"Awbee, dentro (superior)" },
        { n = L"La colecta de huevos", q = 4735, d = L"Tinkee Vaporio, en Flame Crest (superior)" },
        { n = L"Ojo de brasadivino", q = 6821, d = L"Duque Hydraxis, en Azshara (superior)" },
        { n = L"La forja demoníaca", q = 5127, d = L"Lorax, en Cuna del Invierno (superior)" },
        { n = L"El sello de ascensión", q = 4743, d = L"Vaelan, dentro de la mazmorra", nueva = true },
        { n = L"Entrega a Crestabuena", q = 4765, d = L"Mayara Alasol, dentro de la mazmorra", nueva = true },
        { n = L"Mayara Alasol", q = 4766, d = L"Conde Remington Bonacresta, en Ciudad de Ventormenta", nueva = true },
        { n = L"Tinkee Vaporino", q = 4907, d = L"Felnok Acerovera, en Cuna del Invierno", nueva = true },
        { n = L"Un mensaje para Maxwell", q = 5002, d = L"Bijou, dentro de la mazmorra", nueva = true },
        { n = L"¡Pip Perspicaz, a su servicio!", q = 5047, d = L"Pip Perspicaz, dentro de la mazmorra", nueva = true },
        { n = L"La misión de Maxwell", q = 5081, d = L"Mariscal Maxwell, dentro de la mazmorra", nueva = true },
        { n = L"La parte izquierda del amuleto de Lord Valthalak", q = 8966, d = L"Bodley, dentro de la mazmorra", nueva = true },
        { n = L"La parte derecha del amuleto de Lord Valthalak", q = 8989, d = L"Bodley, dentro de la mazmorra", nueva = true },
        { n = "Mea Culpa, Lord Valthalak", q = 8995, d = L"Bodley, dentro de la mazmorra", nueva = true } },
      },
    { n = "Bastión Faucenegra", min = 55, max = 60, z = L"Azshara (al oeste del Bastión Fauces de Madera)", e = { m = 1447, x = 38.7, y = 33.4 }, nueva = true, misiones = { { n = "Blackmaw Reclamation", q = 92065, d = L"Gatekeeper Rageroar, en Ursolan (Azshara). Después de Blackmaw Counter-Offensive; lleva la cabeza de Varrox. Comprueba la reputación requerida." } },
      estadoForever977 = L"Bastión Faucenegra: disponible en Forever. Catálogo parcial; botín, mapa y misiones restantes pendientes de contraste." },
    { n = "La Masacre", min = 56, max = 60, z = "Feralas", e = { m = 1444, x = 58.9, y = 41.5 },
      misiones = { { n = L"La Membrana de Lethtendris", q = 7488, d = L"Latronicus Lanzaluna, en el Bastión Plumaluna (Este)" },
        { n = L"Pusillín y el ancestro Azj'Tordin", q = 7441, d = L"Azj'Tordin, en el Pabellón de Lariss (Este)" },
        { n = L"Fragmentos de gangrevid", q = 5526, d = L"Rabine Saturna, en Claro de la Luna (Este)" },
        { n = L"El refresco arcano", q = 7463, d = L"Tradicionalista Lydros, dentro (Biblioteca)" },
        { n = L"Locura interior", q = 7461, d = L"Antiguo Shen'dralar, dentro (Oeste)" },
        { n = L"El traje de orgo Gordok", q = 5518, d = L"Knot Llavededo, dentro (Norte)" },
        { n = L"El aunto inacabado de Gordok", q = 7703, d = L"Capitán Kromcrush, dentro (Norte)" },
        { n = L"Leyendas élficas", q = 7482, d = L"Erudita Runathorn, en el Bastión Plumaluna" },
        { n = L"Una trampa rota", q = 1193, d = L"Trampa rota, dentro de la mazmorra", nueva = true },
        { n = L"Asunto Gordok sin finiquitar", q = 1318, d = L"Capitán Kromcrush, dentro (norte); se entrega al guardia Mol'dar", nueva = true },
        { n = L"¡Libera a Knot!", q = 5525, d = L"Knot Llavededo, dentro de la mazmorra", nueva = true },
        { n = L"La cata de los Gordok", q = 5528, d = L"Vapuleador Kreeg, dentro de la mazmorra", nueva = true },
        { n = L"El tesoro de los Shen'dralar", q = 7462, d = L"Anciano Shen'dralar, dentro de la mazmorra", nueva = true },
        { n = L"El Tratado de Concentración", q = 7484, d = L"Tradicionalista Lydros, dentro de la mazmorra", nueva = true },
        { n = L"Bastión Plumaluna", q = 7494, d = L"Crier Bonombre, en Ciudad de Ventormenta", nueva = true },
        { n = L"Garona: un estudio acerca de la discreción y la traición", q = 7498, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"Códice de Defensa", q = 7499, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"El libro de cocina del Arcanista", q = 7500, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"La Luz y cómo alterarla", q = 7501, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"Controlar las Sombras", q = 7502, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"La mayor raza de cazadores", q = 7503, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"Sagrada Bologna: lo que la Luz nunca te dirá", q = 7504, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"El choque de Escarcha y tú", q = 7505, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"El Sueño Esmeralda", q = 7506, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"Compendio de Nostro", q = 7507, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"Forjar Quel'Serrar", q = 7508, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"Un viejo amigo de Anthion", q = 8948, d = L"Anthion Harmon, en Tierras de la Peste del Este", nueva = true },
        { n = L"La vendetta de Falrin", q = 8949, d = L"Falrin Tallarbol, dentro de la mazmorra", nueva = true },
        { n = L"El encantamiento del provocador", q = 8950, d = L"Falrin Tallarbol, dentro de la mazmorra", nueva = true },
        { n = L"La parte izquierda del amuleto de Lord Valthalak", q = 8967, d = L"Bodley, dentro de la mazmorra", nueva = true },
        { n = L"La parte derecha del amuleto de Lord Valthalak", q = 8990, d = L"Bodley, dentro de la mazmorra", nueva = true } },
      },
    { n = "Scholomance", min = 58, max = 60, z = L"Tierras de la Peste del Oeste (Castel Darrow)", e = { m = 1422, x = 69.8, y = 76.0 },
      misiones = { { n = L"Crías de dragón apestadas", q = 5529, d = L"Betina Bigglezink, en la Capilla de la Esperanza de la Luz" },
        { n = L"Escama sana de dragón", q = 5582, d = L"La suelta un Trampedor infestado" },
        { n = L"Doctor Theolen Krastinov, el Carnicero", q = 5382, d = L"Eva Sarkhoff, en Castel Darrow" },
        { n = L"Bolsa de los horrores de Krastinov", q = 5515, d = L"Eva Sarkhoff, en Castel Darrow. Referencia Classic: completa antes la misión 5382." },
        { n = L"Kirtonos el Heraldo", q = 5384, d = L"Eva Sarkhoff, en Castel Darrow. Referencia Classic: completa antes la misión 5515." },
        { n = L"Gambito del Alba", q = 4771, d = L"Betina Bigglezink, en la Capilla de la Esperanza de la Luz. Prerrequisito de referencia: 5531. Usa el objeto de misión en la sala de observación." },
        { n = L"El Lich, Ras Levescarcha", q = 5466, d = L"Magistrado Marduke, en Castel Darrow. Prerrequisito de referencia: 5465. Usa el objeto de misión antes de derrotar a Ras." },
        { n = L"La fortuna de la familia Barov", q = 5343, d = L"Weldon Barov, en el Campamento Ventofrío" },
        { n = L"La llave de Scholomance", q = 5505, d = L"Alquimista Arbington, en el Campamento Ventofrío. Referencia Classic: requiere la cadena de la llave y el escarabajo de Araj." },
        { n = "Betina Bigglezink", q = 5531, d = L"Leonid Barthalomew el Venerado, en Tierras de la Peste del Este", nueva = true },
        { n = L"La parte izquierda del amuleto de Lord Valthalak", q = 8969, d = L"Bodley, dentro de la mazmorra", nueva = true },
        { n = L"La parte derecha del amuleto de Lord Valthalak", q = 8992, d = L"Bodley, dentro de la mazmorra", nueva = true } } },
    { n = "Stratholme", min = 58, max = 60, z = L"Tierras de la Peste del Este (lado vivo 30.9, 15.2; lado no-muerto 48.3, 21.8)", e = { m = 1423, x = 30.9, y = 15.2 },
      misiones = { { n = L"El gran Ezra Grimm", q = 5214, d = L"Smokey LaRue, en la Capilla de la Esperanza de la Luz" },
        { n = L"El archivista", q = 5251, d = L"Duque Nicolas Zverenhoff, en la Capilla" },
        { n = L"Espíritus inquietos", q = 5281, d = L"Custodio Alen, en la Capilla" },
        { n = L"El medallón de Fe", q = 5122, d = L"Aurius, dentro (lado no-muerto)" },
        { n = L"La verdad cae del cielo", q = 5262, d = L"Cabeza de Balnazzar (la suelta él). Prerrequisito de referencia Classic: 5251; comprueba en Forever." },
        { n = L"Del amor y la familia", q = 5848, d = L"Artista Renfray, en Tierras de la Peste del Oeste" },
        { n = L"La carne no miente", q = 5212, d = L"Betina Bigglezink, en la Capilla" },
        { n = L"El agente activo", q = 5213, d = L"Betina Bigglezink, en la Capilla. Prerrequisito de referencia Classic: 5212; comprueba en Forever." },
        { n = L"Las casas de lo sagrado", q = 5243, d = L"Leonid Barthalomew el Venerado, en la Capilla" },
        { n = L"Por encima y más allá", q = 5263, d = L"Duque Nicolas Zverenhoff, en la Capilla. Prerrequisito de referencia Classic: 5262; comprueba en Forever." },
        { n = L"El Obsequio de Menethil", q = 5463, d = L"Leonid Barthalomew el Venerado, en la Capilla" },
        { n = L"La estimación de Aurius", q = 5125, d = L"Aurius, dentro de la mazmorra", nueva = true },
        { n = L"Espíritus inquietos", q = 5282, d = L"Egan, en Tierras de la Peste del Este. Prerrequisito de referencia Classic: 5281; comprueba en Forever.", nueva = true },
        { n = L"La súplica de un muerto", q = 8945, d = L"Anthion Harmon, en Tierras de la Peste del Este", nueva = true },
        { n = L"La parte izquierda del amuleto de Lord Valthalak", q = 8968, d = L"Bodley, dentro de la mazmorra", nueva = true },
        { n = L"La parte derecha del amuleto de Lord Valthalak", q = 8991, d = L"Bodley, dentro de la mazmorra", nueva = true } } },
    { n = "Bancal del Creador", min = 58, max = 60, z = L"Cráter de Un'Goro (colina sobre el Refugio del Señor)", e = { m = 1449, x = 48.1, y = 6.1 }, nueva = true, misiones = { { n = "Digestible Research", q = 95790, d = L"PNJ que inicia la misión pendiente de confirmar en Forever", nueva = true },
        { n = "Panic at the Digsite", q = 95924, d = L"Comisario Torio, en Forjaz", nueva = true },
        { n = "Mapping the Way Forward", q = 95925, d = L"Comisario Torio, en Forjaz", nueva = true } },
      nota = L"Mapa ilustrado disponible. Los cristales de poder de Un'Goro sirven para invocar encuentros en las consolas del bancal. King Op: ubicación y botín pendientes de confirmar." },
    { n = "Salón de los Feudales", min = 13, max = 18, z = L"Forjaz (Sede Real, puerta de la izquierda, abajo a Forjaz Antigua)", e = { m = 1455, x = 43.5, y = 52.0 }, nueva = true,
      misiones = { { n = L"Reliquias importantes", q = 96403, d = L"Thom Filch, en Forjaz Antigua" },
        { n = L"Incursión en la Antigua Forjaz", q = 96393, d = L"Vidente de la tierra Farsen, en la cantera de Gol'Bolar (Dun Morogh)" },
        { n = L"Los muertos sin descanso", q = 96394, d = L"Afadra Dunwall, en Forjaz Antigua" },
        { n = L"Un agravio antiguo", q = 96395, d = L"Asistente fantasmal, en el Descanso de Anvilmar" },
        { n = L"El tratado de entendimiento", q = 98423, d = L"Cámara del Relicario de los Reyes (último jefe); se entrega al rey Magni" } },
      nota = L"Debajo de Forjaz: se entra por Forjaz Antigua." },
    { n = "Ruinas de Lordaeron", min = 15, max = 22, z = L"Claros de Tirisfal (la Alianza entra por el camino de Tirisfal)", nueva = true,
      misiones = { { n = L"La insignia ensangrentada", q = 95195, d = L"La sueltan los no-muertos de dentro; se entrega en Ventormenta" },
        { n = L"Recuerda el amor que te tengo", q = 92415, d = L"Carta manchada de sangre, dentro; se entrega en Ventormenta" },
        { n = L"El blasón de Lordaeron", q = 95189, d = L"la suelta un enemigo (objeto que empieza la misión)", nueva = true },
        { n = L"Criaturas abominables", q = 95250, d = L"Capitán Truman, dentro", nueva = true } },
      nota = L"Está en territorio de la Horda." },
    -- 8.5: mazmorra de la Horda (en Orgrimmar). La Alianza no la ve en la lista.
    { n = "Sima Ígnea", min = 13, max = 18, z = L"Orgrimmar (en el centro de la ciudad)", e = { m = 1454, x = 52.8, y = 49.6 }, horda = true,
      misiones = {} },
  }
end

------------------------------------------------------------------------
-- 8.5: misiones de la Horda por mazmorra (se muestran en lugar de las de la Alianza si juegas con la Horda).
-- De QuestieDB (Forever); las de Clarofluvial y la Isla de Alcaz, que aún no están en QuestieDB, de las guías de
-- Warcraft Tavern (Forever). Las compartidas llevan el mismo texto que en la lista de la Alianza. Sin comprobar en el juego.
-- NOTA_HORDA: nota que sustituye a la de la mazmorra con la Horda (false = ninguna).
------------------------------------------------------------------------
local function MisionesHordaR11() return {
    ["Sima Ígnea"] = {
      { n = L"Enemigos ocultos", q = 5728, d = L"Thrall, en Orgrimmar" },
      { n = L"Matar a la bestia", q = 5761, d = L"Neeru Hojafuego, en Orgrimmar" },
      { n = L"Poder destructivo", q = 5725, d = L"Varimathras, en Entrañas (Barrio Real)" },
      { n = L"Midiendo fuerzas con el enemigo", q = 5723, d = L"Rahauro, en Cima del Trueno" },
      { n = L"Buscando la cartera perdida", q = 5722, d = L"Rahauro, en Cima del Trueno" },
      { n = L"La vuelta de la cartera perdida", q = 5724, d = L"Maur Tótem Siniestro, dentro (sigue a «Buscando la cartera perdida»)" } },
    ["Cavernas de los Lamentos"] = {
      { n = L"Pellejo de los descarriados", q = 1486, d = L"Nalpak, en la cueva sobre la entrada" },
      { n = L"Erradicación de descarriados", q = 1487, d = L"Ebru, en la cueva sobre la entrada" },
      { n = L"Las bebidas astutas", q = 1491, d = L"Mebok Mizzyrix, en Trinquete" },
      { n = L"¡A por la botella!", q = 959, d = L"Operador de grúa Pelardo, en Trinquete" },
      { n = L"El fragmento brillante", q = 6981, d = L"La suelta Mutanus el Devorador" },
      { n = L"Líderes del Colmillo", q = 914, d = L"Nara Bravacrín, en Cima del Trueno" },
      { n = L"Repitilia", q = 962, d = L"Boticaria Zamah, en Cima del Trueno" },
      { n = L"Nara Bravacrín", q = 1490, d = L"Archidruida Hamuul Runatótem, en Cima del Trueno (tras «Hamuul Runatótem», de Tonga en El Cruce)" } },
    ["Castillo de Colmillo Oscuro"] = {
      { n = L"Mortacechadores en Colmillo Oscuro", q = 1098, d = L"Sumo Ejecutor Hadrec, en Bosque de Argénteos" },
      { n = L"El Libro de Ur", q = 1013, d = L"Vigilante Bel'dugur, en Entrañas" },
      { n = L"Arugal debe morir", q = 1014, d = L"Dalar Tejalba, en Bosque de Argénteos" } },
    ["Cavernas de Brazanegra"] = {
      { n = L"La esencia de Aku'Mai", q = 6563, d = L"Je'neu Sancrea, en Vallefresno" },
      { n = L"Lealtad a los dioses antiguos", q = 6565, d = L"Je'neu Sancrea, en Vallefresno" },
      { n = L"Entre ruinas", q = 6921, d = L"Je'neu Sancrea, en Vallefresno" },
      { n = L"Problemas en las profundidades", q = 6562, d = L"Tsunaman, en Sierra Espolón" },
      { n = L"La vileza de Brazanegra", q = 6561, d = L"Guardia Argenta Thaelrid, dentro de la mazmorra" },
      { n = L"Barón Aquanis", q = 6922, d = L"La suelta el Barón Aquanis, dentro" } },
    ["Excavación"] = {
      { n = L"Abre las Fauces", q = 95682, d = L"Agente mortacechador, en Los Humedales (tras «Dragonmaw Rumors», de Zaruk en Arathi)" },
      { n = "Changing Tastes", q = 95697, d = L"Borstan, en Orgrimmar" },
      { n = "Elder Knowledge", q = 95664, d = L"La suelta el guardián de reliquias, dentro; se entrega a Bashana Runatótem, en Cima del Trueno" },
      { n = "Earthen Echo", q = 98823, d = L"Tras Elder Knowledge, Bashana Runatótem en Cima del Trueno; entrega a Muln Furia Terrestre en Mulgore" } },
    ["Ciudad de Dalaran"] = {
      { n = L"Fuente de poder", q = 96988, d = L"Doctor Martin Felben, en Entrañas" },
      { n = L"El Caballero de la Tumba", q = 96986, d = L"Melisara, en Laderas de Trabalomas" },
      { n = "Opportunistic Education", q = 96987, d = L"Rexxie Copperclutch, dentro, a la derecha de la entrada" },
      { n = L"El corazón de la perturbación", q = 96984, d = L"Imagen de la archimaga Modera, en el Bosque de Argénteos (tras «Blood in the Streets»)" } },
    ["Monasterio Escarlata"] = {
      { n = L"Corazones de fervor", q = 1113, d = L"Maestro boticario Faranell, en Entrañas" },
      { n = L"Prueba de conocimiento", q = 1160, d = L"Parqual Fintallas, en Entrañas" },
      { n = L"La venganza de Vorrel", q = 1051, d = L"Vorrel Sengutz, dentro de la mazmorra" },
      { n = L"El Compendio de los Caídos", q = 1049, d = L"Sabio Buscaverdad, en Cima del Trueno" },
      { n = L"En el Monasterio Escarlata", q = 1048, d = L"Varimathras, en Entrañas" } },
    ["Gnomeregan"] = {
      { n = L"Un buen lío", q = 2904, d = L"Kernobee, dentro de la mazmorra (escolta)" },
      { n = L"Las guerras de la plataforma", q = 2841, d = L"Nogg, en Orgrimmar" },
      { n = L"Scooty, ingeniero jefe", q = 2842, d = L"Sovik, en Orgrimmar (sigue en Bahía del Botín con Scooty)" },
      { n = L"Un anillo sucio", q = 2945, d = L"Empieza con un anillo que se suelta dentro" } },
    ["Horado Rajacieno"] = {
      { n = L"Los tubérculos hojazul", q = 1221, d = L"Mebok Mizzyrix, en Trinquete" },
      { n = L"Willix el Importador", q = 1144, d = L"Willix, en la tienda junto al último jefe" },
      { n = L"Guano del Horado", q = 1109, d = L"Maestro boticario Faranell, en Entrañas" },
      { n = L"Un destino vengador", q = 1102, d = L"Auld Picopiedra, en Cima del Trueno" } },
    ["La Ciudad Sumergida"] = {
      { n = L"La Ciudad Sumergida", q = 95775, d = L"Kin'weelay, en el Campamento Grom'gol (Vega de Tuercespina)" },
      { n = L"El único Escamasalada bueno...", q = 95776, d = L"En el Campamento Grom'gol (Vega de Tuercespina)" },
      { n = "Ancient Gurubashi Idol", q = 96774, d = L"Mazu'kon, en Mulgore (norte)" },
      { n = L"Videntesal sospechosos", q = 95789, d = L"Krazek, en Bahía del Botín" },
      { n = "El capitán Videntesal", q = 95791, d = L"Krazek, en Bahía del Botín" } },
    ["Bastión Krol'dok"] = {
      { n = L"Una prueba de venganza", q = 94975, d = L"Da'grosh, en Clarofluvial (33.4, 38.0)" },
      { n = L"El ojo de Mugg", q = 94968, d = L"Krom'rosh, en Clarofluvial (Rom'gar)" },
      { n = L"El escrito del Crepúsculo", q = 94972, d = L"Tran'gul, en Clarofluvial (Rom'gar)" },
      { n = "Krol'dok Moulding", q = 94973, d = L"La suelta Tunk, dentro" } },
    ["Zahúrda Rajacieno"] = {
      { n = L"Un anfitrión del mal", q = 6626, d = L"Myriam Cantolunar, en la entrada" },
      { n = L"La plaga de la Zahúrda", q = 3523, d = L"Belnistrasz, dentro de la mazmorra" },
      { n = L"Extinguir el ídolo", q = 3525, d = L"Belnistrasz, dentro de la mazmorra" },
      { n = L"Una alianza nefasta", q = 6521, d = L"Varimathras, en Entrañas" },
      { n = L"Acaba con la amenaza", q = 3341, d = L"Andrew Brownell, en Entrañas" } },
    ["Uldaman"] = {
      { n = L"Las piedras de energía", q = 2418, d = L"Aparejez, en Tierras Inhóspitas" },
      { n = L"La solución a la maldición", q = 709, d = L"Theldurin el Perdido, en Tierras Inhóspitas" },
      { n = L"La recuperación del collar", q = 2283, d = L"Dran Droffers, en Orgrimmar" },
      { n = L"La traducción del diario", q = 2318, d = L"Restos de un paladín, dentro (sigue a «La recuperación del collar, 2ª parte»)" },
      { n = L"Los tesoros reclamados", q = 2342, d = L"Patrick Garrett, en Entrañas" },
      { n = L"Componentes de Uldaman", q = 2202, d = L"Jarkal Musgofusión, en Tierras Inhóspitas" },
      { n = L"Los discos de platino", q = 2280, d = L"Empieza en los discos de platino, dentro" } },
    ["Zul'Farrak"] = {
      { n = L"Temple trol", q = 3042, d = L"Trenton Mazaligera, en Gadgetzan" },
      { n = L"Caparazones de escarabajo", q = 2865, d = L"Tran'rek, en Gadgetzan" },
      { n = L"Tiara de la Profundidad", q = 2846, d = L"Tabetha, en el Marjal Revolcafango" },
      { n = "Gahz'rilla", q = 2770, d = L"Wizzle Pernolatón, en Las Mil Agujas (El Desierto de Sal)" },
      { n = L"Cetro Divinomático", q = 2768, d = L"Ingeniero jefe Silvaina, en Gadgetzan" },
      { n = L"La profecía de Mosh'aru", q = 3527, d = L"Yeh'kinya, en Puerto Bonvapor" },
      { n = "Tran'rek", q = 2864, d = L"Krazek, en Vega de Tuercespina" },
      { n = L"Diosa araña", q = 2936, d = L"Maestro Gadrin, en Durotar" } },
    ["Maraudon"] = {
      { n = L"Leyendas de Maraudón", q = 7044, d = L"Cavindra, en la entrada (lado naranja)" },
      { n = L"Los males de Maraudón", q = 7028, d = L"Willow, en Desolace" },
      { n = L"Las instrucciones del Paria", q = 7067, d = L"Paria centauro, en Desolace" },
      { n = L"El cetro de Celebras", q = 7046, d = L"Celebras el Redimido, dentro (lado morado)" },
      { n = L"La semilla de la vida", q = 7066, d = L"Espíritu de Zaetar, dentro tras la princesa Theradras" },
      { n = L"Fragmentos Oscuros", q = 7068, d = L"Uthel'nay, en Orgrimmar" },
      { n = L"La corrupción de Lenguavil", q = 7029, d = L"Vark Marcaguerra, en Desolace" },
      { n = L"Corrupción de la tierra y de la semilla", q = 7064, d = L"Selendra, en Desolace" } },
    ["Bastión Faucenegra"] = { { n = "Blackmaw Reclamation", q = 92065, d = L"Gatekeeper Rageroar, en Ursolan (Azshara). Después de Blackmaw Counter-Offensive; lleva la cabeza de Varrox. Comprueba la reputación requerida." } },
    ["Prisión de Alcaz"] = {
      { n = "A Little Payback", q = 96332, d = L"Sargento Ulka, en la Isla de Alcaz (70.3, 19.0)" },
      { n = "Blood Red Bandanas", q = 96334, d = L"Sargento Ulka, en la Isla de Alcaz" },
      { n = "No Orc Left Behind", q = 95309, d = L"Sargento Ulka, en la Isla de Alcaz" },
      { n = "The Honor of the Kor'kron", q = 95454, d = L"Comandante Folkar, dentro" },
      { n = "Bad News for Folkar", q = 96369, d = L"Empieza con una nota perfumada que suelta Blazeroar" },
      { n = "The Man in the Iron Chains", q = 96335, d = L"Mason Connery, dentro" },
      { n = "More Valuable Than Gold", q = 96337, d = L"Mason Connery, dentro" } },
    ["Templo de Atal'Hakkar"] = {
      { n = L"El profeta Jammal'an", q = 1446, d = L"Exiliado Atal'ai, en Tierras del Interior" },
      { n = L"En las profundidades", q = 3446, d = L"Marvon Buscarroblones, en Tanaris" },
      { n = L"El secreto del círculo", q = 3447, d = L"Marvon Buscarroblones, en Tanaris" },
      { n = L"El dios Hakkar", q = 3528, d = L"Yeh'kinya, en Puerto Bonvapor" },
      { n = L"La esencia de Eranikus", q = 3373, d = L"La suelta la Sombra de Eranikus" },
      { n = L"Eranikus, el Tirano del Sueño", q = 8733, d = L"Malfurion Tempestira, dentro de la mazmorra" },
      { n = L"El Templo de Atal'Hakkar", q = 1445, d = L"Fel'zerul, en Pantano de las Penas" },
      { n = L"El Templo Sumergido", q = 3380, d = L"Médico brujo Uzer'i, en Feralas" } },
    ["Profundidades de Roca Negra"] = {
      { n = L"El legado de los Hierro Negro", q = 3802, d = L"Franclorn Forjador, en Montaña Roca Negra (solo se ve muerto)" },
      { n = L"El Corazón de la Montaña", q = 4123, d = L"Maxwort Suprandor, en Las Estepas Ardientes" },
      { n = L"Un sabor a llamarada", q = 4024, d = L"Cyrus Therepentio, en Las Estepas Ardientes" },
      { n = L"Ribbly Llavenrosca", q = 4136, d = L"Yorba Llavenrosca, en Tanaris" },
      { n = L"La poción de enamoramiento", q = 4201, d = L"Maestra Nagmara, dentro (Tabernas del Rencor)" },
      { n = L"Armonización con el Núcleo", q = 7848, d = L"Lothos Levantagrietas, en Montaña Roca Negra" },
      { n = L"El cáliz espectral", q = 4083, d = L"Cáliz espectral, dentro de la mazmorra" },
      { n = L"Yuka Llavenrosca", q = 4324, d = L"Yorba Llavenrosca, en Tanaris" },
      { n = L"Un contrato vinculante", q = 7604, d = L"la suelta un enemigo (objeto que empieza la misión)" },
      { n = L"El reto", q = 9015, d = L"Falrin Tallarbol, dentro de la mazmorra" },
      { n = L"Comandante Gor'shak", q = 3981, d = L"Galamav el Preciso, en Tierras Inhóspitas" },
      { n = L"El rescate real", q = 4003, d = L"Thrall, en Orgrimmar (tras «¿Qué pasa?» y «Los Reinos del Este»)" },
      { n = L"Operación: muerte a Forjainquina", q = 4132, d = L"Señor de la guerra Dientegore, en Tierras Inhóspitas" },
      { n = L"La receta perdida de Cebatruenos", q = 4134, d = L"Maga oscura Vivian Latumba, en Kargath (Tierras Inhóspitas)" },
      { n = L"La revuelta de las máquinas", q = 4063, d = L"Lotwil Veriatus, en Tierras Inhóspitas" },
      { n = L"La discordia de las llamas", q = 3907, d = L"Truenozón, en Tierras Inhóspitas" },
      { n = L"El último elemento", q = 7201, d = L"Maga oscura Vivian Latumba, en Kargath (Tierras Inhóspitas)" },
      { n = L"MATAR INMEDIATAMENTE: enanos Hierro Negro", q = 4081, d = L"Cartel de Kargath (Tierras Inhóspitas)" } },
    ["Cumbre de Roca Negra"] = {
      { n = L"La maestra de la manada", q = 4724, d = L"Galamav el Preciso, en Tierras Inhóspitas" },
      { n = L"La orden del Señor de la Guerra", q = 4903, d = L"Señor de la guerra Dientegore, en Tierras Inhóspitas" },
      { n = L"¡Por la Horda!", q = 4974, d = L"Thrall, en Orgrimmar" },
      { n = L"La espía Bijou", q = 4981, d = L"Lexlort, en Tierras Inhóspitas" },
      { n = L"La tablilla de Rocanegra", q = 4768, d = L"Maga oscura Vivian Latumba, en Kargath (Tierras Inhóspitas)" },
      { n = L"Ilusiones oculares", q = 6569, d = L"Myranda la Fada, en Tierras de la Peste del Oeste" },
      { n = L"La sangre de dragón negro campeón", q = 6602, d = L"Rexxar, en Desolace" } },
    ["La Masacre"] = {
      { n = L"La Membrana de Lethtendris", q = 7489, d = L"Talo Pezuñahendida, en Feralas" },
      { n = L"Leyendas élficas", q = 7481, d = L"Sabio Korolusk, en Feralas" },
      { n = L"El tesoro de los Shen'dralar", q = 7877, d = L"Anciano Shen'dralar, dentro de la mazmorra", nueva = true } },
    ["Scholomance"] = {
      { n = L"La fortuna de la familia Barov", q = 5341, d = L"Alexi Barov, en Claros de Tirisfal" },
      { n = L"La llave de Scholomance", q = 5511, d = L"Boticario Dithers, en el Baluarte. Referencia Classic: requiere la cadena de la llave y el escarabajo de Araj." } },
    ["Stratholme"] = {
      { n = "Ramstein", q = 6163, d = L"Nathanos Clamañublo, en las Tierras de la Peste del Este (tras «Alatardecer, cómo te odio…»)" } },
    ["Ruinas de Lordaeron"] = {
      { n = "Light's Justice", q = 92421, d = L"Morbin Lightbane, en Entrañas" },
      { n = L"La nueva peste", q = 95216, d = L"Theodore Griffs, en Entrañas" },
      { n = L"La cólera de Rath'mael", q = 92422, d = "Deathguard Kristof, en Claros de Tirisfal" },
      { n = L"Una petición aterradora", q = 92401, d = L"Tabitha Heartweaver, en Bosque de Argénteos" },
      { n = L"El blasón de Lordaeron", q = 95204, d = L"Empieza con un emblema que aparece dentro, en sitios al azar" },
      { n = "Unending Torment", q = 97288, d = L"La suelta el Barón, dentro" } },
} end
local function NotaHordaR11() return {
  ["Gnomeregan"] = L"Horda: acepta Las guerras de la plataforma (25), habla con Sovik y después con Scooty en Bahía del Botín. Conserva el transpondedor goblin para usar el teletransportador.",
  ["Las Minas de la Muerte"] = L"Está en los Páramos de Poniente: la Horda no tiene misiones aquí.",
  ["Mazmorras de Ventormenta"] = L"Está dentro de Ventormenta: la Horda no puede entrar.",
  ["Salón de los Feudales"] = L"Está debajo de Forjaz: la Horda no tiene misiones aquí.",
  ["Castillo de Colmillo Oscuro"] = false,
  ["Ruinas de Lordaeron"] = L"La Horda entra desde la puerta de Entrañas.",
  ["Bastión Krol'dok"] = L"Misiones de la guía de Warcraft Tavern (aún no están en QuestieDB).",
  ["Prisión de Alcaz"] = L"Misiones de la guía de Warcraft Tavern (aún no están en QuestieDB).",
} end

local function EsHorda()
  return UnitFactionGroup and UnitFactionGroup("player") == "Horde"
end

------------------------------------------------------------------------
-- Ayudas
------------------------------------------------------------------------
-- 7.6: zonas nuevas sin uiMapID conocido (Clarofluvial): se busca el mapa por su nombre entre las zonas de los
-- Reinos del Este (1415). Si el juego no lo encuentra, la mazmorra se queda sin entrada (sin Marcar ni Llevarme).
local function ResolverMapas(datos)
  for _, m in ipairs(datos) do
    local e = m.entradaPendienteR15 or m.e
    if e and not e.m and e.nombres then
      local ok, hijos = pcall(function() return C_Map.GetMapChildrenInfo(1415, nil, true) end)
      for _, h in ipairs((ok and type(hijos) == "table") and hijos or {}) do
        if type(h) == "table" and type(h.mapID) == "number" and h.mapID > 0 and h.mapID < math.huge and h.mapID % 1 == 0 then
          for _, nombre in ipairs(e.nombres) do if h.name == nombre then e.m = h.mapID end end
        end
      end
      if e.m then m.e, m.entradaPendienteR15 = e, nil
      else m.e, m.entradaPendienteR15 = nil, e end
    end
  end
end

local function NivelJugador() return GL.NivelJugadorR14() end

-- Color según tu nivel, como el de las misiones: gris (fácil) a rojo (muy alta).
local function ColorNivel(m)
  local nivel = NivelJugador()
  if not nivel then return C.GRIS end
  local d = math.floor((m.min + m.max) / 2) - nivel
  if d >= 5 then return "|cffff4040" elseif d >= 3 then return "|cffff8040" elseif d >= -2 then return "|cffffd100"
  elseif d >= -8 then return "|cff40c040" end
  return "|cff9d9d9d"
end

local function Destino(m)
  if not m or type(m.e) ~= "table" or type(m.n) ~= "string" then return nil end
  local e = m.e
  local function Coord(v) return type(v) == "number" and v >= 0 and v <= 100 end
  if type(e.m) ~= "number" or e.m <= 0 or e.m >= math.huge or e.m % 1 ~= 0 or not Coord(e.x) or not Coord(e.y) then return nil end
  return { m = e.m, x = e.x, y = e.y, z = type(m.z) == "string" and m.z or m.n, n = L"Entrada de " .. m.n, mazmorraEntrada = m.clave or m.n }
end

local function MarcarEntrada(m)
  local d = Destino(m)
  if not d then return end
  if not GL.MarcarEntradaR13 then
    GL.Mensaje(L"este cliente no deja poner puntos en el mapa.")
    return
  end
  local ok, motivo = GL.MarcarEntradaR13(d)
  if motivo == "externa" or motivo == "desconocida" then
    GL.Mensaje(L"Conserva el marcador existente; retíralo antes de marcar la entrada.")
    return
  end
  GL.Mensaje(ok and (L"marcada la entrada de " .. L(m.n) .. L" en el mapa.") or L"no se pudo poner la marca en el mapa.")
end

local function Jefes(m)
  return (GL.JefesVisibles976 and GL.JefesVisibles976(m.clave or m.n)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[m.clave or m.n]) or {}
end

-- 9.7.7: referencias de sala Classic sin atribuir coordenadas al dibujo propio.
local UBICACIONES977 = {
  [3864] = "Patio inferior y establos; referencia de aparición alternativa.",
  [3886] = "Cocina, junto al comedor.",
  [4279] = "Balcón, antes del ascenso a la torre.",
  [3872] = "Muralla; aparición rara, no garantizada.",
  [3927] = "Torre superior, antes de Arugal.",
}
local UBICACIONES_TEMPLO977 = {
  ["Atal'alarion"] = "Planta inferior: aparece al resolver el puzle de las seis estatuas.",
  ["Loh'ro"] = "Anillo superior: uno de los seis guardianes de los balcones.",
  ["Gasher"] = "Anillo superior: uno de los seis guardianes de los balcones.",
  ["Mijan"] = "Anillo superior: uno de los seis guardianes de los balcones.",
  ["Zolo"] = "Anillo superior: uno de los seis guardianes de los balcones.",
  ["Zul'Lor"] = "Anillo superior: uno de los seis guardianes de los balcones.",
  ["Hukku"] = "Anillo superior: uno de los seis guardianes de los balcones.",
  ["Ogom el Desdichado"] = "Sala del Profeta, junto a Jammal'an.",
  ["Sastrón"] = "Foso del Sacrificio: aparece tras derrotar a Jammal'an.",
  ["Hazzas"] = "Pasillo de acceso a la Cámara del Soñador; encuentro de dos dragones.",
  ["Morphaz"] = "Pasillo de acceso a la Cámara del Soñador; encuentro de dos dragones.",
}
local UBICACIONES_CUMBRE977 = {
  ["Inferior: Gizrul el esclavista"] = "Guarida de Halycon: aparece después de derrotarla.",
  ["Superior: Piroguardián brasadivino"] = "Sala de la Vinculación: encuentro activado mediante el altar.",
  ["Superior: Solakar Corona de Fuego"] = "Criadero de dragones: evento de la llama de los huevos.",
  ["Superior: Goraluk Yunquegrieta"] = "Forja de la cumbre superior.",
  ["Superior: Jed Observarrunas (raro)"] = "Extremo oriental de la sala de Goraluk; aparición rara.",
  ["Superior: Gyth"] = "Arena de Desgarro Puño Negro: comparte el encuentro.",
  ["Superior: Lord Valthalak (invocado)"] = "Sala de La Bestia: encuentro invocado mediante una misión.",
}
local UBICACIONES_ESTUDIO977 = {
  ["Ayudante de sangre de Kirtonos"] = "Relicario.",
  ["Marduz Pozonegro"] = "Sala de Observación, junto a Vectus.",
  ["Vectus"] = "Sala de Observación.",
  ["Instructor Malicia"] = "Estudio superior, cámara sur (Classic).",
  ["Doctor Theolen Krastinov"] = "Estudio superior, cámara este (Classic).",
  ["Tradicionalista Polkelt"] = "Estudio superior, cámara norte (Classic).",
  ["El Devorador"] = "Estudio inferior, cámara sur (Classic).",
  ["Lord Alexei Barov"] = "Estudio inferior, cámara este (Classic).",
  ["Lady Illucia Barov"] = "Estudio inferior, cámara norte (Classic).",
  ["Kormok"] = "Laboratorio de Ras Levescarcha; encuentro invocado.",
  ["Death Knight Darkreaver"] = "Gran Osario, sala de Rattlegore; encuentro invocado.",
  ["Vivo: Ezra Grimm"] = "Plaza del Rey, junto a la tabaquería; encuentro activado.",
  ["Vivo: Skul (raro)"] = "Tramo cercano a Ezra Grimm; aparición rara.",
  ["Vivo: Jefe de correos Gassol"] = "Aparece al abrir el tercer buzón; ubicación variable.",
  ["No-muerto: Pidrespina"] = "Patrulla entre los zigurat de Nerub’enkan y Anastari.",
  ["No-muerto: Armero Guardia Negra"] = "Planos de herrería junto al primer zigurat; encuentro activado.",
  ["Vivo: Sothos y Jarien (invocados)"] = "Sala de Balnazzar; encuentro invocado.",
}
local UBICACIONES_BLOQUE9977 = {
  ["Lord Roccor"] = "Patrulla de los corredores de la zona de prisión.",
  ["Bael'Gar"] = "Túnel más allá de Lord Incendius.",
  ["Verek"] = "Cámara acorazada, junto a Stilgiss.",
  ["Hurley Negrálito"] = "Taberna Tragapenas; se activa al romper barriles.",
  ["Vigía Presaletal"] = "Cámara acorazada; aparece al abrir los doce cofres de reliquias.",
  ["Este: Pusillín"] = "Ala este: recorrido de persecución desde el patio.",
  ["Oeste: Tsu'zee"] = "Patio de los Altonato, cerca de las rampas; aparición rara.",
  ["Norte: Cho'Rush el Observador"] = "Sala del trono, junto al rey Gordok.",
  ["Sacerdote oscuro Sezz'ziz"] = "Evento de la escalinata, junto a Nekrum.",
  ["Sargento Bly"] = "Escalinata: encuentro posterior al evento de rescate.",
  ["Hidromántica Velratha"] = "Patrulla en una sala cercana al final de la mazmorra.",
  ["Zerillis"] = "Patrulla variable por Zul’Farrak: revisa los caminos y grupos de trols; aparición rara sin punto fijo.",
}
local UBICACIONES_BLOQUE10977 = {
  ["Minero Johnson (raro)"] = "Túnel lateral después de Rhahk’Zor; aparición rara.",
  ["Cocinitas"] = "Cubierta inferior del barco de los Defias, cerca de la pasarela.",
  ["Capitán Verdetez"] = "Patrulla la cubierta superior del barco de los Defias, antes del camarote de VanCleef.",
  ["Targor el Pavoroso"] = "Sala de la prisión con guardias Defias; primer encuentro de la ruta de referencia.",
  ["Dextren Tutor"] = "Sector de celdas posterior a Bazil en la ruta de referencia.",
  ["Bruegal Nudoferro (raro)"] = "Celdas de la prisión: aparición rara; revisa las distintas celdas, sin sala fija confirmada.",
  ["Baelog"] = "Sala de los tres enanos perdidos, cerca de la entrada principal.",
  ["Eric «The Swift»"] = "Sala de los tres enanos perdidos, cerca de la entrada principal.",
  ["Olaf"] = "Sala de los tres enanos perdidos, cerca de la entrada principal.",
  ["Meshlok el Cosechador"] = "Cascadas Venenosas: patrulla las aguas cercanas al comienzo de la zona; aparición rara.",
}
local UBICACIONES_BLOQUE11977 = {
  ["Lorgus Jett"] = "Cuevas centrales cerca de Gelihast y del estanque de los sectarios Crepusculares; revisa los ramales y la orilla. Aparición variable.",
  ["Dragón feérico descarriado (raro)"] = "Ramal hacia Lord Serpentis; aparición rara.",
  ["Embajador Hierro Negro (raro)"] = "Sector norte del túnel final entre Electrocutor 6000 y Mekigeniero Termochufe; patrulla rara.",
  ["Médium Jargba"] = "Tramo de encuentros entre Aggem y Ramtusk en la ruta Classic de referencia.",
  ["Cazador ciego (raro)"] = "Sector entre Agathelos y Charlga; aparición rara.",
  ["Clamor de Tierra Halmgar"] = "Mesetas después de Colmicarnero, en el tramo hacia Agathelos; aparición rara. Punto exacto pendiente.",
  ["Morrandrajos"] = "Aparición rara con tres puntos posibles en Classic, en el sector de la Espiral de Espinas; no hay un punto fijo confirmado en este dibujo.",
  ["Fauzpeste el Putrefacto"] = "Ídolo al final de la escolta de Belnistrasz (Extinguir el ídolo): aparece en la última oleada del ritual; posición exacta pendiente.",
  ["Catedral: Alto Inquisidor Fairbanks"] = "Cámara secreta a la derecha del altar de la catedral: acciona la palanca con forma de antorcha. La cámara no está representada en el mapa.",
}
local UBICACIONES_FOREVER977 = {
  ["King Op"] = "Encuentro raro; zona de aparición y botín sin confirmar.",
  ["Machacaesclavos Grox"] = "Primer encuentro, junto a los prisioneros de Crestagrana.",
  ["Comandante Crepuscular Zarmok"] = "Recinto anterior a la gran puerta que se abre al derrotarlo; patrulla por el recinto.",
  ["Cuidadora de guerra Ashka"] = "Recinto de los lobos, inmediatamente después de la puerta de Zarmok; junto a sus dos lobos.",
  ["Nar'gurk"] = "Círculo de invocación, acompañado por sectarios.",
  ["Jefazo Toof"] = "Final del tramo de los dos puentes.",
  ["Señor supremo Mugg"] = "Edificio en lo alto de la colina, al final del camino posterior a los dos puentes.",
  ["Zul'Alai"] = "Extremo oriental de la ciudad, al salir del camino de la cueva.",
  ["Var'Taka"] = "Archivos profundos.",
  ["Primeval Elemental"] = "Túneles inundados bajo los archivos; encuentro opcional.",
  ["Capitán Alzapavor"] = "Altar de la Serpiente, sector norte del estanque central.",
  ["Deathless Marrow"] = "Anfiteatro Eterno.",
  ["Min'loth the Serpent"] = "Estrado Abisal, encuentro final de la ciudad.",
  ["Branquia"] = "Cerca del acceso a la zona del Elemental primigenio; aparición rara.",
  ["Umbra"] = "Junto a una escalera camino de Var’Taka; aparición rara.",
  ["\"Pyromancer\" Braxton"] = "En el sector que conduce al Capitán Alzapavor; aparición rara.",
  ["Horror de las Tierras Altas"] = "Al norte de la excavación perdida; objetivo de misión.",
  ["Capitán de Lordaeron (raro, Horda)"] = "Calles del oeste; aparición rara, punto variable.",
}
-- Los encuentros móviles se distinguen de los raros con posición no confirmada.
local MOVILES977 = {
  ["Embajador Hierro Negro (raro)"] = true,
  ["Bruegal Nudoferro (raro)"] = true,
  -- Raro con varios puntos de aparición; no implica que patrulle.
  ["Morrandrajos"] = true,
  ["Capitán Verdetez"] = true,
  ["Lorgus Jett"] = true,
  ["Vivo: Jefe de correos Gassol"] = true,
  ["No-muerto: Pidrespina"] = true,
  ["Lord Roccor"] = true,
  ["Este: Pusillín"] = true,
  ["Hidromántica Velratha"] = true,
  ["Zerillis"] = true,
  ["Meshlok el Cosechador"] = true,
  ["Capitán de Lordaeron (raro, Horda)"] = true,
}
function GL.JefeUbicacionVariable977(j)
  return type(j) == "table" and MOVILES977[j.nombreOriginal977 or j.n] == true
end
local EVENTOS977 = {
  ["Inferior: Gizrul el esclavista"] = true,
  ["Superior: Piroguardián brasadivino"] = true,
  ["Superior: Solakar Corona de Fuego"] = true,
  ["Superior: Lord Valthalak (invocado)"] = true,
  ["Kormok"] = true,
  ["Death Knight Darkreaver"] = true,
  ["Vivo: Ezra Grimm"] = true,
  ["No-muerto: Armero Guardia Negra"] = true,
  ["Vivo: Sothos y Jarien (invocados)"] = true,
  ["Hurley Negrálito"] = true,
  ["Vigía Presaletal"] = true,
  ["Atal'alarion"] = true,
  ["Sastrón"] = true,
  ["Fauzpeste el Putrefacto"] = true,
  ["Sacerdote oscuro Sezz'ziz"] = true,
  ["Sargento Bly"] = true,
}
function GL.JefeActivado977(j)
  return type(j) == "table" and EVENTOS977[j.nombreOriginal977 or j.n] == true
end
-- Cierre de alcance: las referencias de sala, sector o activación son válidas
-- sin inventar coordenadas. Las referencias demasiado generales siguen abiertas.
local REFERENCIA_INSUFICIENTE977 = {
  ["King Op"] = true,
}
function GL.UbicacionJefe977(j)
  local forever = type(j) == "table" and UBICACIONES_FOREVER977[j.nombreOriginal977 or j.n]
  if forever then return L"Referencia Forever; posición exacta sin confirmar: " .. L(forever) end
  local t = type(j) == "table" and (UBICACIONES977[j.npc] or UBICACIONES_TEMPLO977[j.nombreOriginal977 or j.n] or UBICACIONES_CUMBRE977[j.nombreOriginal977 or j.n] or UBICACIONES_ESTUDIO977[j.nombreOriginal977 or j.n] or UBICACIONES_BLOQUE9977[j.nombreOriginal977 or j.n] or UBICACIONES_BLOQUE10977[j.nombreOriginal977 or j.n] or UBICACIONES_BLOQUE11977[j.nombreOriginal977 or j.n])
  if t then return L"Referencia Classic; posición exacta sin confirmar: " .. L(t) end
end

-- 9.7.7: misma información de ubicación en la lista y en las calaveras.
function GL.TextoUbicacionJefe977(j)
  local partes = {}
  local ubicacion = GL.UbicacionJefe977(j)
  if ubicacion then partes[#partes + 1] = ubicacion end
  if type(j) == "table" and REFERENCIA_INSUFICIENTE977[j.nombreOriginal977 or j.n] then
    partes[#partes + 1] = L"Sala o sector aún por concretar."
  elseif ubicacion then
    partes[#partes + 1] = L"Consulta la referencia de sala, sector o activación; no se presupone una coordenada exacta."
  end
  if GL.JefeUbicacionVariable977(j) then
    partes[#partes + 1] = L"Encuentro móvil o de aparición variable; consulta la zona indicada."
  end
  if GL.JefeActivado977(j) then
    partes[#partes + 1] = L"Encuentro activado o invocado; su posición exacta sigue pendiente de confirmar."
  end
  return table.concat(partes, "\n")
end

-- 7.5.16: filas de los jefes y el botín del abierto, debajo del texto. Devuelve el alto que ocupan.
local function PintarJefes(d, m, arriba)
  local jefes = Jefes(m)
  for i = 1, #d.jefes do d.jefes[i]:Hide() end
  d.botin:Hide()
  local y = arriba
  for i = 1, #jefes do
    local f = d.jefes[i]
    if not f then
      f = CreateFrame("Button", nil, d)
      f:SetHeight(18)
      f.marca = f:CreateTexture(nil, "BACKGROUND")
      f.marca:SetAllPoints()
      f.marca:SetColorTexture(1, 0.82, 0, 0.10)
      local brillo = f:CreateTexture(nil, "HIGHLIGHT")
      brillo:SetAllPoints()
      brillo:SetColorTexture(1, 1, 1, 0.06)
      f.texto = GL.Texto(f, "GameFontHighlightSmall")
      f.texto:SetPoint("LEFT", f, "LEFT", 4, 0)
      f:SetScript("OnClick", function(self)
        jefeAbierto = (jefeAbierto ~= self.indice) and self.indice or nil
        if ui.Refrescar then ui.Refrescar() end
      end)
      if GL.Ayuda then GL.Ayuda(f) end
      d.jefes[i] = f
    end
    local j = jefes[i]
    -- También accesible desde la lista completa, no solo en el mapa ampliado.
    local nombre = GL.NombreJefeGuiaR11 and GL.NombreJefeGuiaR11(j) or j.n or "?"
    f.ayudaTitulo = nombre
    f.ayudaTexto = L"Clic: su botín."
    local ubicacion = GL.TextoUbicacionJefe977(j)
    if ubicacion ~= "" then f.ayudaTexto = f.ayudaTexto .. "\n" .. ubicacion end
    f.indice = i
    f.texto:SetPoint("RIGHT", f, "RIGHT", -4, 0); GL.UnaLinea(f.texto)   -- 7.6.1
    local utiles = (GL.UtilesDeJefe and GL.UtilesDeJefe(j)) or 0   -- 9.0: cuántos objetos te sirven
    f.texto:SetText((jefeAbierto == i and C.AMARILLO or "") .. i .. ". " .. nombre .. (jefeAbierto == i and C.FIN or "") ..
      (j.nivel and (C.GRIS .. L"  · nivel " .. j.nivel .. C.FIN) or "") ..
      ((utiles > 0) and (C.VERDE .. "  · " .. utiles .. (utiles == 1 and L" útil para ti" or L" útiles para ti") .. C.FIN) or ""))
    GL.Mostrar(f.marca, jefeAbierto == i)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -y)
    f:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -y)
    f:Show()
    y = y + 18
    if jefeAbierto == i then
      d.botin:ClearAllPoints()
      d.botin:SetPoint("TOPLEFT", d, "TOPLEFT", 26, -y - 2)
      d.botin:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -y - 2)
      y = y + d.botin:Mostrar(j.botin or {}) + 6
      d.botin:Show()
    end
  end
  return y - arriba
end

-- 9.4.2: la desplegada tiene dos pestañas, Misiones y Jefes y botín. Cuántas misiones de la mazmorra tienes hechas.
local function MisionesHechas(m)
  local n = 0
  for _, q in ipairs(m.misiones or {}) do if q.q and GL.MisionCompletada and GL.MisionCompletada(q.q) then n = n + 1 end end
  return n, #(m.misiones or {})
end
-- La pestaña que se ve: la que elegiste en esa mazmorra; si no, con todas sus misiones hechas, Jefes; si no, la última.
local elegidaEn = {}
local function PestanaDetalle(m)
  if elegidaEn[m.clave or m.n] then return elegidaEn[m.clave or m.n] end
  local hechas, total = MisionesHechas(m)
  if total > 0 and hechas == total then return "jefes" end
  return GuiaAventureroDB.pestanaDetMaz or "misiones"
end

local ACCESO_MAZ977 = {
  ["Monasterio Escarlata"] = { texto = "Referencia Classic: Cementerio y Biblioteca no requieren llave; Armería y Catedral tienen cerradura. Llave Escarlata del cofre de Doan o apertura compatible. Comprueba los requisitos en Forever." },
  ["Gnomeregan"] = { texto = "Referencia Classic: la llave del taller de Electrocutor 6000 abre la entrada lateral; no es requisito de la entrada principal." },
  ["Profundidades de Roca Negra"] = { texto = "Referencia Classic: la llave de Forjatiniebla abre atajos interiores; no es un requisito general del portal." },
  ["Cumbre de Roca Negra"] = { texto = "La parte superior requiere que un miembro del grupo abra la puerta con el Sello de Ascensión; no confundir con el acceso inferior." },
  ["La Masacre"] = { texto = "Este: acceso separado; Oeste y Norte: Llave creciente de Pusillín (o apertura compatible). Referencia de guía: confirma las cerraduras en el cliente." },
  ["Scholomance"] = { texto = "La llave esquelética se obtiene mediante la cadena de tu facción; un compañero o una apertura compatible puede abrir la puerta.", id = 13704 },
  ["Stratholme"] = { texto = "La llave de la ciudad abre el acceso lateral no-muerto; la entrada principal es distinta. La Llave Escarlata abre puertas del bastión interior. Comprueba las cerraduras en Forever." },
  ["Maraudon"] = { texto = "Referencia Classic: el Cetro de Celebras permite un atajo interior; no es requisito general del portal." },
  ["Uldaman"] = { texto = "Referencia Classic: el Bastón de Prehistoria activa un encuentro interior; no es una llave del portal." },
  ["Prisión de Alcaz"] = { texto = "La llave del Interrogador se utiliza en una misión interior; no se ha confirmado que sea requisito del portal." },
}
local function FaccionMaz977()
  if type(UnitFactionGroup) ~= "function" then return nil end
  local ok, f = pcall(UnitFactionGroup, "player")
  if not ok or (issecretvalue and issecretvalue(f)) then return nil end
  if f == "Alliance" or f == "Horde" then return f end
end
local function AccesoDetalle(m)
  local clave = m.clave or m.n
  local dato = ACCESO_MAZ977[clave]
  local texto, id
  if clave == "Ciudad de Dalaran" then
    local f = FaccionMaz977()
    texto = (f == "Alliance" and L"Alianza: empieza con Una petición alarmante en Costasur o habla con la Imagen de la archimaga Modera junto a las alcantarillas para conseguir la llave." or (f == "Horde" and L"Horda: empieza Key to the City y Prison Break-In con Magus Wordeen Voidglare en Molino Tarren; sigue Dalaran Patrols, Blood in the Streets y El corazón de la perturbación." or L"Facción sin confirmar: consulta la cadena de acceso correspondiente.")) .. " " .. L"Al menos un jugador debe poder abrir la reja de las alcantarillas con la llave; no implica acceso libre a la ciudad exterior."
    id = 277507
  elseif dato then texto, id = L(dato.texto), dato.id
  else return L"Requisitos de acceso no documentados aquí; el rango recomendado no garantiza la entrada." end
  if id then
    local ok, n = false, nil
    if type(GL.BolsasProfesion975) == "function" then ok, n = pcall(GL.BolsasProfesion975, id) end
    -- Una lectura de bolsas negativa no acredita ausencia en el llavero ni en el grupo.
    local presente = ok and not (issecretvalue and issecretvalue(n)) and type(n) == "number" and n > 0 and n < math.huge and n % 1 == 0
    texto = texto .. " " .. (presente and L"Llave detectada en el inventario del personaje." or L"Llave no confirmada: comprueba también el llavero y los miembros del grupo.")
  end
  return texto
end

local function ZonaDetalle(m)
  local donde = m.e and (L" · entrada en " .. string.format("%.1f, %.1f", m.e.x, m.e.y)) or L" · entrada sin coordenadas comprobadas"
  return C.GRIS .. m.z .. donde .. C.FIN
end

local function TextoDetalle(m, pestana)
  -- 9.7.7: aviso informativo, sin retirar datos disponibles ni crear ventanas.
  local aviso = (tonumber(m.max) or 0) >= 60 and (C.AMARILLO .. L"El contenido de nivel alto aún sin confirmar se añadirá en próximas versiones." .. C.FIN) or nil
  if pestana == "jefes" then
    local l = { C.AMARILLO .. L"Jefes" .. C.FIN .. (#Jefes(m) > 0 and (C.GRIS .. L" (clic para ver el botín)" .. C.FIN)
      or ("  " .. C.GRIS .. L"aún no se conocen (mazmorra nueva)." .. C.FIN)) }
    table.insert(l, C.GRIS .. AccesoDetalle(m) .. C.FIN)
    if m.estadoForever977 then table.insert(l, C.GRIS .. m.estadoForever977 .. C.FIN) end
    if aviso then table.insert(l, aviso) end
    return table.concat(l, "\n"), #l
  end
  local faccion = FaccionMaz977()
  local horda = faccion == "Horde"
  local lista = faccion and m.misiones or {}
  local l = { C.AMARILLO .. (faccion and (horda and L"Misiones de la Horda" or L"Misiones de la Alianza") or L"Facción sin confirmar: consulta la cadena de acceso correspondiente.") .. C.FIN }
  if #lista == 0 then table.insert(l, C.GRIS .. L"Aún no se conocen misiones." .. C.FIN) end
  for i = 1, #lista do
    local q = lista[i]
    local estado = ""
    if q.q and GL.MisionCompletada and GL.MisionCompletada(q.q) then estado = C.VERDE .. L" (hecha)" .. C.FIN
    elseif q.q and GL.MisionEnDiario and GL.MisionEnDiario(q.q) then estado = C.VERDE .. L" (en el diario)" .. C.FIN end
    table.insert(l, "• " .. C.AMARILLO .. "[" .. q.n .. "]" .. C.FIN .. " " .. C.GRIS .. q.d .. C.FIN .. estado)
  end
  table.insert(l, C.GRIS .. AccesoDetalle(m) .. C.FIN)
  if m.nota then table.insert(l, C.GRIS .. m.nota .. C.FIN) end
  if m.estadoForever977 then table.insert(l, C.GRIS .. m.estadoForever977 .. C.FIN) end
  if aviso then table.insert(l, aviso) end
  if faccion then table.insert(l, C.GRIS .. (horda and L"Fuente: QuestieDB y Warcraft Tavern (Forever)." or L"Fuente: Wowhead y QuestieDB (Forever) · misiones comprobadas con QuestieDB.") .. C.FIN) end
  return table.concat(l, "\n"), #l
end

------------------------------------------------------------------------
-- Refrescar
------------------------------------------------------------------------
-- 8.5: la lista de mazmorras de tu facción: con la Alianza, sin las de la Horda (Sima Ígnea); con la Horda, con
-- sus misiones (MISIONES_HORDA) y sus notas (NOTA_HORDA) en lugar de las de la Alianza.
local function CargarLista()
  local datos = CargarDatos()
  local faccion = FaccionMaz977()
  local horda = faccion == "Horde"
  local MISIONES_HORDA, NOTA_HORDA
  if horda then MISIONES_HORDA, NOTA_HORDA = MisionesHordaR11(), NotaHordaR11() end
  for i = #datos, 1, -1 do
    local m = datos[i]
    m.clave = m.n
    m.n = L(m.n)   -- 9.3.5: el nombre en el idioma de la guía (la clave sigue en español)
    if not faccion then
      m.misiones = {}; m.nota = nil
    elseif horda then
      if m.clave == "Scholomance" then
        -- Las misiones neutrales se conservan; solo se sustituyen las de facción.
        local comunes = {}
        for _, q in ipairs(m.misiones or {}) do
          if q.q ~= 5343 and q.q ~= 5505 then comunes[#comunes + 1] = q end
        end
        for _, q in ipairs(MISIONES_HORDA[m.clave] or {}) do comunes[#comunes + 1] = q end
        m.misiones = comunes
      elseif m.clave == "Stratholme" then
        -- Las misiones neutrales son comunes; Ramstein es exclusiva de la Horda.
        for _, q in ipairs(MISIONES_HORDA[m.clave] or {}) do
          m.misiones[#m.misiones + 1] = q
        end
      else
        m.misiones = MISIONES_HORDA[m.clave] or {}
      end
      if NOTA_HORDA[m.clave] ~= nil then m.nota = NOTA_HORDA[m.clave] or nil end
    elseif m.horda then
      table.remove(datos, i)
    end
  end
  ResolverMapas(datos)
  return datos
end

local faccionDatos
local ultimoMapaR15
local function AsegurarDatos()
  local faccion = FaccionMaz977()
  if DATOS and faccionDatos == faccion then
    -- Reintentar solo entradas pendientes, con intervalo para no cargar la UI.
    local ok, ahora = pcall(function() return GetTime() end)
    if ok and type(ahora) == "number" and ahora >= 0 and ahora < math.huge and (not ultimoMapaR15 or ahora < ultimoMapaR15 or ahora - ultimoMapaR15 >= 5) then
      ultimoMapaR15 = ahora
      for _, m in ipairs(DATOS) do if m.entradaPendienteR15 then ResolverMapas(DATOS); break end end
    end
    return
  end
  local anterior = DATOS and abierta and DATOS[abierta]
  DATOS = CargarLista(); faccionDatos = faccion; ultimoMapaR15 = nil
  table.sort(DATOS, function(a, b) return a.min < b.min or (a.min == b.min and a.max < b.max) end)
  abierta, jefeAbierto = nil, nil
  if anterior then for i, m in ipairs(DATOS) do if m.clave == anterior.clave then abierta = i; break end end end
end

local function Refrescar()
  if not panel or not panel:IsShown() then return end
  if ui.bandas then   -- 9.4: pestaña Bandas
    local bandas = GuiaAventureroDB.pestanaMaz == "bandas"
    ui.pestanas.Marcar(bandas and "bandas" or "mazmorras")
    ui.titulo:SetText(bandas and (L"Bandas " .. C.GRIS .. L"(acceso y equipo)" .. C.FIN) or (L"Mazmorras por nivel"))
    GL.Mostrar(ui.bandas, bandas)
    if bandas and clara.tarjeta then clara.tarjeta:Hide(); clara.desp:Hide() end
    if bandas then
      ui.detalle:Hide(); ui.mas:SetText("")
      for i = 1, #ui.filas do ui.filas[i]:Hide() end
      ui.bandas.Refrescar()
      return
    end
  end
  AsegurarDatos()
  -- 9.6: con la Guía clara, arriba «Para tu nivel ahora» y la lista entera en un desplegable
  if ui.Clara then
    local arriba, abiertoTodo = ui.Clara()
    if arriba then
      if not abiertoTodo then
        ui.vista:Hide(); ui.detalle:Hide(); ui.mas:SetText("")
        for i = 1, #ui.filas do ui.filas[i]:Hide() end
        return
      end
      arribaL = arriba
    else
      arribaL = 20
    end
    ui.vista:ClearAllPoints()
    ui.vista:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -arribaL)
    ui.vista:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 18)
    ui.vista:Show()
  end
  -- 9.4.2: desplazamiento por píxeles. Antes la rueda saltaba de mazmorra en mazmorra y, con una desplegada más
  -- alta que la ventana, su parte de abajo (misiones, PNJ, jefes) no se llegaba a ver.
  local alto = panel:GetHeight() or 400
  local ARRIBA_L, ABAJO_L = -arribaL, -(alto - 18)   -- franja visible de la lista (debajo del título, encima del pie)
  local visible = ARRIBA_L - ABAJO_L
  px = math.max(0, px or 0)
  local y, usadas, primera, ultima = ARRIBA_L + px, 0, nil, 0
  ui.detalle:Hide()
  for i = 1, #ui.filas do ui.filas[i]:Hide() end
  for k = 1, #DATOS do
    local m = DATOS[k]
    if y - ALTO_FILA < ARRIBA_L + 2 and y > ABAJO_L then   -- la fila entra (aunque sea en parte) en la franja
      usadas = usadas + 1
      local fila = ui.filas[usadas]
      if not fila then fila = ui.CrearFila(); ui.filas[usadas] = fila end
      fila.indice = k
      fila:ClearAllPoints()
      fila:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
      fila:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y)
      fila.flecha:SetText(C.GRIS .. (abierta == k and "v" or ">") .. C.FIN)
      fila.nombre:SetText(m.n)
      fila.nivel:SetText(ColorNivel(m) .. m.min .. "-" .. m.max .. C.FIN)
      GL.Mostrar(fila.marca, abierta == k)
      fila:Show()
      if y - ALTO_FILA >= ABAJO_L - 1 and y <= ARRIBA_L + 1 then primera = primera or k; ultima = k end
    end
    y = y - ALTO_FILA
    if abierta == k then
      local d = ui.detalle
      local pestana = PestanaDetalle(m)
      local ancho = (panel:GetWidth() or 400) - 6
      -- zona y entrada, arriba de las pestañas
      d.zona:SetWidth(ancho - 18); d.zona:SetText(ZonaDetalle(m))
      local zh = (d.zona.GetStringHeight and d.zona:GetStringHeight()) or ALTO_LINEA
      if type(zh) ~= "number" or zh <= 0 then zh = ALTO_LINEA end
      local yPest = 6 + zh + 5
      d.pest[1]:ClearAllPoints(); d.pest[1]:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -yPest)
      local hechas, total = MisionesHechas(m)
      d.pest[1].texto:SetText(total > 0 and (L"Misiones (" .. hechas .. L" de " .. total .. L" hechas)") or L"Misiones")
      d.pest[2].texto:SetText(L"Jefes y botín (" .. #Jefes(m) .. ")")
      d.pest.Marcar(pestana)
      local yTexto = yPest + 20 + 7
      d.texto:ClearAllPoints()
      d.texto:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -yTexto)
      d.texto:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -yTexto)
      local texto, lineas = TextoDetalle(m, pestana)
      d.texto:SetText(texto)
      local th = lineas * ALTO_LINEA
      if d.texto.GetStringHeight then
        d.texto:SetWidth(ancho - 18)
        local sh = d.texto:GetStringHeight()
        if type(sh) == "number" and sh > 0 then th = sh end
      end
      local h = yTexto + th + 6
      if pestana == "jefes" then h = h + PintarJefes(d, m, h)
      else for i = 1, #d.jefes do d.jefes[i]:Hide() end; d.botin:Hide() end
      h = h + 30   -- botones de abajo
      ui.detalle:ClearAllPoints()
      ui.detalle:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, y - 2)
      ui.detalle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, y - 2)
      ui.detalle:SetHeight(h)
      ui.detalle.m = m
      GL.Mostrar(ui.detalle.marcar, m.e ~= nil); GL.Mostrar(ui.detalle.llevar, m.e ~= nil)
      if y - 2 - h < ARRIBA_L and y - 2 > ABAJO_L then ui.detalle:Show() end
      y = y - h - 6
    end
  end
  -- no pasar del final: lo último queda pegado abajo
  local total = (ARRIBA_L + px) - y
  local maximo = math.max(0, total - visible)
  ui.pxMax = maximo
  if px > maximo then px = maximo; return Refrescar() end
  ui.mas:ClearAllPoints()
  ui.mas:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 2)
  if maximo > 0 then
    local donde = (px <= 0 and L"arriba del todo") or (px >= maximo and L"abajo del todo") or (math.floor(px / maximo * 100 + 0.5) .. " %")
    ui.mas:SetText(C.GRIS .. L"Mazmorras " .. (primera or 1) .. "-" .. math.max(ultima, primera or 1) .. L" de " .. #DATOS .. "  ·  " .. donde .. L" (rueda del ratón)" .. C.FIN)
  else
    ui.mas:SetText("")
  end
end

------------------------------------------------------------------------
-- Crear
------------------------------------------------------------------------
local function CrearFila()
  local f = CreateFrame("Button", nil, ui.vista or panel)
  f:SetHeight(ALTO_FILA)
  f.marca = f:CreateTexture(nil, "BACKGROUND")
  f.marca:SetAllPoints()
  f.marca:SetColorTexture(1, 0.82, 0, 0.12)
  f.marca:Hide()
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.06)
  f.flecha = GL.Texto(f, "GameFontHighlightSmall")
  f.flecha:SetPoint("LEFT", f, "LEFT", 4, 0)
  f.flecha:SetWidth(12)
  f.nivel = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
  f.nivel:SetPoint("RIGHT", f, "RIGHT", -2, 0)
  f.nivel:SetWidth(60)
  f.nombre = GL.Texto(f, "GameFontHighlightSmall")
  f.nombre:SetPoint("LEFT", f, "LEFT", 18, 0)
  f.nombre:SetPoint("RIGHT", f.nivel, "LEFT", -4, 0)
  GL.UnaLinea(f.nombre)
  f:SetScript("OnClick", function(self)
    abierta = (abierta ~= self.indice) and self.indice or nil
    jefeAbierto = nil
    if abierta then px = (abierta - 1) * ALTO_FILA end   -- 9.4.2: la desplegada sube arriba para verla entera
    Refrescar()
  end)
  return f
end

------------------------------------------------------------------------
-- 7.6: mapa de la mazmorra (botón Mapa). Fondo = mapa que trae el juego; jefes = posiciones del diario de encuentros.
------------------------------------------------------------------------
------------------------------------------------------------------------
-- 9.6: «Para tu nivel ahora»: la mazmorra de tu facción que más te conviene a tu nivel (y otra si la hay)
------------------------------------------------------------------------
local function ParaTuNivel()
  local nivel, lista = NivelJugador(), {}
  if not nivel then return lista end
  for i, m in ipairs(DATOS or {}) do
    if m.e and nivel >= m.min - 1 and nivel <= m.max then
      local coger, diario, hechas, total = 0, 0, 0, 0
      local vistos = {}
      for _, q in ipairs(m.misiones or {}) do
        local id = tonumber(q.q)
        if id and not vistos[id] then
          vistos[id] = true; total = total + 1
          if GL.MisionCompletada and GL.MisionCompletada(id) then hechas = hechas + 1
          elseif GL.MisionEnDiario and GL.MisionEnDiario(id) then diario = diario + 1
          else coger = coger + 1 end
        end
      end
      table.insert(lista, { m = m, i = i, coger = coger, diario = diario, hechas = hechas, total = total })
    end
  end
  -- Primero mazmorras dentro del rango, luego misiones activas y pendientes.
  table.sort(lista, function(a, b)
    local apta, aptb = nivel >= a.m.min, nivel >= b.m.min
    if apta ~= aptb then return apta end
    if a.diario ~= b.diario then return a.diario > b.diario end
    if a.coger ~= b.coger then return a.coger > b.coger end
    local da, db = math.abs(a.m.min - nivel), math.abs(b.m.min - nivel)
    if da ~= db then return da < db end
    return a.i < b.i
  end)
  return lista
end
GL._paraTuNivel = function() AsegurarDatos(); return ParaTuNivel() end   -- para las pruebas

local function Clara()
  if not (GL.PestanasClaras and GL.PestanasClaras() and GL.CrearTarjeta96) then
    if clara.tarjeta then clara.tarjeta:Hide(); clara.desp:Hide() end
    return nil
  end
  if not clara.tarjeta then
    clara.tarjeta = GL.CrearTarjeta96(panel, true)
    clara.desp = GL.CrearDesplegable96(panel, "mazTodas", function() Refrescar() end)
  end
  local ancho = (panel:GetWidth() or 0) > 60 and panel:GetWidth() or 400
  local lista = ParaTuNivel()
  local nivel = NivelJugador()
  local texto, botones
  local function Linea(e)
    local m = e.m
    local lugar = m.z:match("%((.-)%)") or m.z
    local dist = ""
    if GL.Vector then
      local ok, este, _, d = pcall(GL.Vector, Destino(m))
      if ok and este and type(d) == "number" then dist = L" · a " .. (d * 0.9144 >= 1000 and string.format("%.1f km", d * 0.0009144) or (math.floor(d * 0.9144 + 0.5) .. " m")) end
    end
    local mis
    if e.total == 0 then mis = L"sin misiones conocidas"
    elseif e.hechas == e.total then mis = L"misiones conocidas completadas"
    else mis = e.coger .. L" para revisar" .. ", " .. e.diario .. L" en el diario" end
    if nivel < m.min then mis = L"Próximamente: " .. mis end
    return ColorNivel(m) .. m.n .. C.FIN .. C.GRIS .. "  " .. m.min .. "-" .. m.max .. C.FIN .. "\n" .. C.GRIS .. lugar .. " · " .. mis .. dist .. C.FIN
  end
  local e = lista[1]
  if e then
    texto = Linea(e)
    if lista[2] then texto = texto .. "\n" .. C.GRIS .. L"También: " .. C.FIN .. lista[2].m.n .. C.GRIS .. " (" .. lista[2].m.min .. "-" .. lista[2].m.max .. ")" .. C.FIN end
    botones = {
      { L"Llevarme", function() local d = Destino(e.m); if d and GL.SeguirDesvio then GL.SeguirDesvio(d) end end, 96 },
      { L"Ver ficha", function()
        GuiaAventureroDB.mazTodas = true
        abierta, jefeAbierto = e.i, nil
        px = (e.i - 1) * ALTO_FILA
        Refrescar()
      end, 96 },
    }
  elseif not nivel then
    texto = C.GRIS .. L"Nivel del personaje sin confirmar" .. C.FIN
  else
    local sig
    for _, m in ipairs(DATOS or {}) do if m.e and m.min > nivel then sig = m; break end end
    texto = C.GRIS .. L"Ninguna mazmorra de tu facción a tu nivel." .. C.FIN ..
      (sig and ("\n" .. L"La siguiente: " .. C.AMARILLO .. sig.n .. C.FIN .. C.GRIS .. L" desde el nivel " .. sig.min .. "." .. C.FIN) or "")
  end
  local y = 22
  y = y + clara.tarjeta:Pintar(y, ancho, C.AMARILLO .. L"Para tu nivel ahora" .. C.FIN, C.GRIS .. (nivel and (L"nivel " .. nivel) or L"Nivel del personaje sin confirmar") .. C.FIN, texto, botones) + 8
  y = y + clara.desp:Pintar(y, L"Todas las mazmorras por nivel", #(DATOS or {})) + 6
  return y, clara.desp:Abierto()
end
ui.Clara = Clara

local mapa = nil
local indiceMapas = nil   -- nombre (minúsculas) -> { uiMapID, ... } de mapas de tipo mazmorra/micro

local function Minus(s) return (type(s) == "string") and s:lower() or "" end

local function IndiceMapas()
  if indiceMapas and next(indiceMapas) then return indiceMapas end
  indiceMapas = {}
  if not (C_Map and C_Map.GetMapInfo) then return indiceMapas end
  for id = 1, 2600 do
    local ok, info = pcall(C_Map.GetMapInfo, id)
    if ok and type(info) == "table" and type(info.name) == "string" and (info.mapType == 4 or info.mapType == 5) then
      local k = Minus(info.name)
      indiceMapas[k] = indiceMapas[k] or {}
      table.insert(indiceMapas[k], id)
    end
  end
  return indiceMapas
end

-- 7.6.5 y 7.6.6: mapas incluidos en el addon (carpeta Mapas), para los clientes que no traen el de las mazmorras.
-- 9.4.1: dibujos propios de la guía (solo la forma de las salas, con colores y bordes propios); sustituyen a las
-- imágenes de Wowhead y Warcraft Tavern. Las tres vistas aéreas sin jefes (Bancal, Ciudad Sumergida, Krol'dok)
-- y la planta clásica de Atal'Hakkar se quitan: esas mazmorras salen con su lista de jefes.
-- Cada planta: f = archivo, n = nombre, w/h = proporción, jefes = { { x, y, nombre en DatosWowhead } } (0-1).
-- 9.5: mapas nuevos dibujados con IA, todos cuadrados (1024×1024), con la entrada y las calaveras ya pintadas.
-- Las coordenadas son x/1024, y/1024 de la imagen. Krol'dok y la Ciudad Sumergida van sin jefes (no se sabe dónde están).
local MAPAS_ADDON = {
  ["Bancal del Creador"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "t-bancal", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.1974, 0.6541 } }, jefes = { { 0.1016, 0.2429, L"Garfanieve" }, { 0.4759, 0.2663, L"Vitrix" }, { 0.4851, 0.3352, L"Izha'Rel y Tor'Rel" }, { 0.0824, 0.4318, L"Titanosaurio" }, { 0.5490, 0.5028, L"Pezuñatrueno" }, { 0.7408, 0.5405, L"Nanaya" }, { 0.0689, 0.5433, L"Cenizas" }, { 0.3977, 0.6044, L"Rayo" }, { 0.8665, 0.6491, L"Matriarca cuernoatroz" }, { 0.3487, 0.6839, L"Crestaveneno" } } },
  } },
  ["Sima Ígnea"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m243-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.6504, 0.2051 } }, jefes = { { 0.5872, 0.4077, L"Ogglesílex" }, { 0.3906, 0.5373, L"Taragaman el Hambriento" }, { 0.3047, 0.6897, L"Jergosh el Conjurador" }, { 0.4056, 0.7431, L"Bazzalan" } } },
  } },
  ["Cavernas de los Lamentos"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m718-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.570, 0.662 } }, jefes = { { 0.642, 0.548, "Lady Anacondra" }, { 0.701, 0.612, "Lord Pythas" }, { 0.296, 0.487, "Lord Cobrahn" }, { 0.487, 0.443, "Kresh" }, { 0.699, 0.800, "Lord Serpentis" }, { 0.452, 0.247, L"Mutanus el Devorador" }, { 0.407, 0.517, "Skum" }, { 0.261, 0.642, L"Verdan el Eterno" } } },
  } },
  ["Las Minas de la Muerte"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m1581-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.346, 0.153 } }, jefes = { { 0.393, 0.644, "Rhahk'Zor" }, { 0.550, 0.894, "Sneed's Shredder / Sneed" } } },
    { f = "m1581-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.132, 0.794, "Gilnid" }, { 0.655, 0.470, L"Don Mamporro" }, { 0.655, 0.388, "Edwin VanCleef" } } },
  } },
  ["Castillo de Colmillo Oscuro"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m209-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.888, 0.555 } }, jefes = { { 0.354, 0.546, "Rethilgore" }, { 0.836, 0.696, L"Barón Filargenta" } } },
    { f = "m209-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.348, 0.867, L"Comandante Vallefont" } } },
    { f = "m209-3", n = "3", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = {  } },
    { f = "m209-4", n = "4", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.553, 0.565, L"Fenrus el Devorador" } } },
    { f = "m209-5", n = "5", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = {  } },
    { f = "m209-6", n = "6", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.577, 0.349, L"Archimago Arugal" } } },
    { f = "m209-7", n = "7", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = {  } },
  } },
  ["Mazmorras de Ventormenta"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m717-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.497, 0.858 } }, jefes = { { 0.164, 0.297, "Hamhock" }, { 0.828, 0.488, "Bazil Thredd" }, { 0.495, 0.242, L"Kam Furiahonda" } } },
  } },
  ["Cavernas de Brazanegra"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m719-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.562, 0.159 } }, jefes = { { 0.448, 0.642, "Ghamoo-ra" }, { 0.241, 0.444, "Lady Sarevess" }, { 0.651, 0.607, "Gelihast" } } },
    { f = "m719-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.411, 0.837, L"Señor Crepuscular Kelris" }, { 0.827, 0.894, "Aku'mai" } } },
    { f = "m719-3", n = "3", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.630, 0.307, L"Viejo Serra'kis" } } },
  } },
  ["Monasterio Escarlata"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m796-1", entrada = true, n = L"Cementerio", w = 1024, h = 1024, retratos = false, entradas = { { 0.936, 0.836 } }, jefes = { { 0.777, 0.522, L"Cementerio: Interrogador Vishas" }, { 0.098, 0.489, L"Cementerio: Mago sangriento Thalnos" }, { 0.179, 0.431, L"Cementerio: Azshir el Insomne" }, { 0.261, 0.538, L"Cementerio: Campeón caído" }, { 0.350, 0.428, L"Cementerio: Dorsacerado" } } },
    { f = "m796-2", entrada = true, n = L"Biblioteca", w = 1024, h = 1024, retratos = false, entradas = { { 0.051, 0.291 } }, jefes = { { 0.242, 0.894, L"Biblioteca: Domador de jaurías Loksey" }, { 0.857, 0.791, L"Biblioteca: Arcanista Doan" } } },
    { f = "m796-3", entrada = true, n = L"Arsenal", w = 1024, h = 1024, retratos = false, entradas = { { 0.389, 0.925 } }, jefes = { { 0.578, 0.221, L"Armería: Herod" } } },
    { f = "m796-4", entrada = true, n = L"Catedral", w = 1024, h = 1024, retratos = false, entradas = { { 0.629, 0.947 } }, jefes = { { 0.477, 0.165, L"Catedral: Alta Inquisidora Melenablanca" }, { 0.477, 0.280, L"Catedral: Comandante Escarlata Mograine" } } },
  } },
  ["Gnomeregan"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m721-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.602, 0.255 } }, jefes = { { 0.741, 0.646, "Grubbis" } } },
    { f = "m721-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.219, 0.633, L"Electrocutor 6000" }, { 0.831, 0.434, L"Radiactivo viscoso" } } },
    { f = "m721-3", entrada = true, n = "3", w = 1024, h = 1024, retratos = false, entradas = { { 0.893, 0.533 } }, jefes = { { 0.368, 0.935, L"Gopleamasa 9-60" } } },
    { f = "m721-4", n = "4", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.336, 0.325, L"Mekigeniero Termochufe" } } },
  } },
  ["Horado Rajacieno"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m491-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.753, 0.866 } }, jefes = { { 0.840, 0.521, L"Aggem Malaespina" }, { 0.908, 0.413, "Roogug" }, { 0.592, 0.296, L"Señor Supremo Colmicarnero" }, { 0.220, 0.293, L"Agathelos el Furioso" }, { 0.081, 0.692, L"Charlga Filonavaja" } } },
  } },
  ["Zahúrda Rajacieno"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m722-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.128, 0.223 } }, jefes = { { 0.528, 0.401, "Tuten'kash" }, { 0.821, 0.552, L"Mordresh Ojo de Fuego" }, { 0.234, 0.745, L"Glotón" }, { 0.347, 0.682, L"Amnennar el Gélido" } } },
  } },
  ["Uldaman"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m1337-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.258, 0.678 }, { 0.746, 0.678 } }, jefes = { { 0.341, 0.742, L"Los enanos perdidos (Baelog, Eric y Olaf)" }, { 0.430, 0.667, "Revelosh" }, { 0.513, 0.809, L"Hierraya" }, { 0.653, 0.919, L"Centinela Obsidiano" }, { 0.586, 0.475, L"Vigilante pétreo anciano" }, { 0.314, 0.495, L"Galgann Flamartillo" }, { 0.283, 0.389, "Grimlok" } } },
    { f = "m1337-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.450, 0.584, "Archaedas" } } },
  } },
  ["Zul'Farrak"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m1176", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.561, 0.863 } }, jefes = { { 0.678, 0.343, "Antu'sul" }, { 0.570, 0.335, L"Theka el Mártir" }, { 0.491, 0.253, L"Médico brujo Zum'rah" }, { 0.466, 0.403, L"Nekrum Cometripas" }, { 0.341, 0.452, "Gahz'rilla" }, { 0.350, 0.246, L"Jefe Ukorz Cabellarena" } } },
  } },
  ["Maraudon"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m2100-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.639, 0.343 }, { 0.814, 0.681 } }, jefes = { { 0.391, 0.211, "Noxxion" }, { 0.192, 0.406, L"Latisable" }, { 0.408, 0.737, L"Lord Lenguavil" }, { 0.543, 0.563, L"Celebras el Maldito" } } },
    { f = "m2100-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.406, 0.353, L"Derrumblo" }, { 0.567, 0.513, L"Manitas Gizlock" }, { 0.558, 0.787, L"Escamapodrida" }, { 0.382, 0.762, L"Princesa Theradras" } } },
  } },
  ["Templo de Atal'Hakkar"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m1477-1", entrada = true, n = L"Moderno", w = 1024, h = 1024, retratos = false, entradas = { { 0.525, 0.161 } }, jefes = { { 0.632, 0.908, L"Sombra de Eranikus" }, { 0.380, 0.891, L"Avatar de Hakkar" }, { 0.806, 0.524, L"Jammal'an el Profeta" }, { 0.209, 0.524, L"Guadañasueños" } } },
  } },
  ["Profundidades de Roca Negra"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m1584-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.357, 0.787 } }, jefes = { { 0.516, 0.907, L"Alto Interrogador Gerstahn" }, { 0.607, 0.633, L"Gorosh el Endemoniado" }, { 0.608, 0.656, L"Domador de jaurías Grebmar" }, { 0.269, 0.511, L"Piromántico Fruto del Saber" }, { 0.696, 0.213, L"Finoso Virunegro" }, { 0.609, 0.306, "Lord Incendius" }, { 0.510, 0.593, L"Grisez" }, { 0.580, 0.589, L"Eviscerador" }, { 0.509, 0.651, L"Ok'thor el Rompedor" }, { 0.580, 0.648, "Anub'shiah" }, { 0.545, 0.571, L"Hedrum el Trepador" }, { 0.545, 0.679, "Theldren" } } },
    { f = "m1584-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.803, 0.242, L"Emperador Dagran Thaurissan" }, { 0.659, 0.237, "Magmus" }, { 0.406, 0.531, L"Embajador Latifuego" }, { 0.363, 0.655, L"Falange" }, { 0.229, 0.666, L"Señor Gólem Argelmach" }, { 0.229, 0.816, L"General Forjainquina" }, { 0.470, 0.685, L"Guarda Stilgiss" } } },
  } },
  ["Cumbre de Roca Negra"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m1583-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.634, 0.709 } }, jefes = { { 0.543, 0.579, L"Inferior: Alto Señor Omokk" } } },
    { f = "m1583-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.589, 0.739, L"Inferior: Cazador de las Sombras Vosh'gajin" }, { 0.669, 0.783, L"Inferior: Maestro de guerra Voone" } } },
    { f = "m1583-3", n = "3", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.417, 0.633, L"Inferior: Urok Aullapocalipsis" } } },
    { f = "m1583-4", n = "4", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.467, 0.573, L"Inferior: Madre Telabrasada" } } },
    { f = "m1583-5", n = "5", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.393, 0.938, L"Inferior: Halycon" }, { 0.585, 0.938, L"Inferior: Intendente Zigris" } } },
    { f = "m1583-6", n = "6", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.630, 0.616, L"Inferior: Señor Supremo Vermiothalak" } } },
    { f = "m1583-7", n = L"Sup.", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.352, 0.539, L"Superior: General Drakkisath" }, { 0.518, 0.284, L"Superior: Jefe de Guerra Desgarro Puño Negro" }, { 0.706, 0.346, L"Superior: La Bestia" } } },
  } },
  ["La Masacre"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m2557-1", entrada = true, n = L"Norte", w = 1024, h = 1024, retratos = false, entradas = { { 0.747, 0.920 } }, jefes = { { 0.735, 0.749, L"Norte: Guardia Mol'dar" }, { 0.640, 0.676, L"Norte: Vapuleador Kreeg" }, { 0.495, 0.787, L"Norte: Guardia Fengus" }, { 0.215, 0.569, L"Norte: Guardia Slip'kik" }, { 0.284, 0.500, L"Norte: Capitán Kromcrush" }, { 0.284, 0.289, L"Norte: Rey Gordok" } } },
    { f = "m2557-2", entrada = true, n = L"Oeste 1", w = 1024, h = 1024, retratos = false, entradas = { { 0.939, 0.548 }, { 0.937, 0.739 } }, jefes = { { 0.135, 0.823, L"Oeste: Tendris Alabeo" }, { 0.269, 0.558, L"Oeste: Illyanna Roblecuervo" } } },
    { f = "m2557-3", n = L"Oeste 2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.390, 0.492, L"Oeste: Magister Kalendris" } } },
    { f = "m2557-4", n = L"Oeste 3", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.351, 0.634, L"Oeste: Immol'thar" }, { 0.629, 0.309, L"Oeste: Príncipe Tortheldrin" } } },
    { f = "m2557-5", entrada = true, n = L"Este 1", w = 1024, h = 1024, retratos = false, entradas = { { 0.946, 0.536 }, { 0.046, 0.432 }, { 0.134, 0.872 } }, jefes = { { 0.396, 0.516, L"Este: Zevrim Pezuñahendida" } } },
    { f = "m2557-6", entrada = true, n = L"Este 2", w = 1024, h = 1024, retratos = false, entradas = { { 0.255, 0.563 } }, jefes = { { 0.591, 0.303, L"Este: Alzzin el Formaferal" }, { 0.541, 0.718, L"Este: Lethtendris" }, { 0.596, 0.735, L"Este: Hidromilecio" } } },
  } },
  ["Scholomance"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m2057-1", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.076, 0.766 } }, jefes = { { 0.665, 0.658, L"Kirtonos el Heraldo" } } },
    { f = "m2057-2", n = "2", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.584, 0.273, "Jandice Barov" }, { 0.429, 0.349, L"Traquesangre" }, { 0.500, 0.532, L"Ras Levescarcha" } } },
    { f = "m2057-3", n = "3", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.210, 0.360, L"Instructor Malicia", overlay977 = true }, { 0.500, 0.770, L"Doctor Theolen Krastinov", overlay977 = true }, { 0.790, 0.360, L"Tradicionalista Polkelt", overlay977 = true } } },
    { f = "m2057-4", n = "4", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.496, 0.331, L"Maestro oscuro Gandling" }, { 0.260, 0.330, L"El Devorador", overlay977 = true }, { 0.495, 0.850, L"Lord Alexei Barov", overlay977 = true }, { 0.790, 0.330, L"Lady Illucia Barov", overlay977 = true } } },
  } },
  ["Stratholme"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "m2017-1", entrada = true, n = L"Vivo", w = 1024, h = 1024, retratos = false, entradas = { { 0.673, 0.894 } }, jefes = { { 0.760, 0.300, L"Vivo: El imperdonable" }, { 0.595, 0.378, L"Vivo: Escupezones Foreste (raro)" }, { 0.489, 0.239, L"Vivo: Timmy el Cruel" }, { 0.286, 0.447, L"Vivo: Malor el Entusiasta" }, { 0.275, 0.754, L"Vivo: Maestro cañonero Willey" }, { 0.051, 0.545, L"Vivo: Archivista Galford" }, { 0.205, 0.821, L"Vivo: Gran Cruzado Dathrohan / Balnazzar" } } },
    { f = "m2017-2", entrada = true, n = L"No-muerto", w = 1024, h = 1024, retratos = false, entradas = { { 0.500, 0.898 } }, jefes = { { 0.492, 0.220, L"No-muerto: Magistrado Barthilas" }, { 0.680, 0.492, L"No-muerto: Nerub'enkan" }, { 0.610, 0.276, L"No-muerto: Baronesa Anastari" }, { 0.496, 0.492, L"No-muerto: Maleki el Pálido" }, { 0.358, 0.259, L"No-muerto: Ramstein el Empachador" }, { 0.288, 0.259, L"No-muerto: Barón Osahendido" } } },
  } },
  ["Salón de los Feudales"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "t-feudales", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.495, 0.928 } }, jefes = { { 0.495, 0.155, "Durgen Dirgehammer" }, { 0.785, 0.457, "Magmatus" }, { 0.495, 0.613, "Plunder" }, { 0.495, 0.787, "Faldrim Anvilmar" } } },
  } },
  ["Ruinas de Lordaeron"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "t-lordaeron", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.519, 0.325 } }, jefes = { { 0.784, 0.496, L"Colmimarchito" }, { 0.605, 0.764, L"El barón" }, { 0.278, 0.732, L"Viktor el Abyecto" }, { 0.325, 0.583, L"El Abandonado" }, { 0.412, 0.656, "Rath'mael" }, { 0.304, 0.305, "Bjork" } } },
  } },
  ["Excavación"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "t-excavacion", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.070, 0.617 } }, jefes = { { 0.386, 0.586, L"Espinasal" }, { 0.645, 0.396, L"Sombradiente" }, { 0.905, 0.646, L"Guardián de reliquias" } } },
  } },
  ["Ciudad de Dalaran"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "t-dalaran", n = L"Ciudad", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.153, 0.439, "Shade of the Archmage" }, { 0.432, 0.346, "Arcane Anomaly" }, { 0.614, 0.285, "Arcanic Enigma" }, { 0.561, 0.546, "Fel Ancient" }, { 0.750, 0.784, "Unstable Sentinel" }, { 0.898, 0.615, "Mana Devourer" } } },
    { f = "t-dalaran-2", n = L"Alcantarillas", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = { { 0.844, 0.238, "Atrexis the Grave Knight" }, { 0.311, 0.675, "Lyn the Ignored" } } },
  } },
  ["Bastión Krol'dok"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "t-kroldok", entrada = true, n = "1", w = 1024, h = 1024, retratos = false, entradas = { { 0.142, 0.753 } }, jefes = {  } },
  } },
  ["La Ciudad Sumergida"] = { fuente = L"dibujo de la guía", plantas = {
    { f = "t-sumergida-1", n = L"Ciudad", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = {  } },
    { f = "t-sumergida-2", n = L"Templo", w = 1024, h = 1024, retratos = false, entradas = {  }, jefes = {  } },
  } },
}
local CARPETA_MAPAS = "Interface\\AddOns\\GuiaAventurero\\Mapas\\"

local function PlantasAddon(m)
  local d = MAPAS_ADDON[m.clave or m.n] or MAPAS_ADDON[m.n]   -- 9.7.6: con la guía en inglés m.n ya va traducido
  if not d then return {} end
  local plantas = {}
  for i, pl in ipairs(d.plantas) do
    plantas[i] = { img = CARPETA_MAPAS .. pl.f, n = pl.n, w = pl.w, h = pl.h, jefes = pl.jefes, entradas = pl.entradas, retratos = pl.retratos, entrada = pl.entrada, fuente = pl.fuente or d.fuente, archivo = pl.f }
  end
  return plantas
end
GL._mapasAddon = MAPAS_ADDON

-- Plantas de la mazmorra: { { id, nombre }, ... } ordenadas de arriba abajo.
local PlantasJuego
local function EnteroMapa(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return type(v) == "number" and v > 0 and v < math.huge and v == math.floor(v) and v or nil
end
local function ArteJuego(id)
  if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) or not EnteroMapa(id) then return end
  local ok, capas = pcall(C_Map.GetMapArtLayers, id)
  local capa = ok and type(capas) == "table" and capas[1]
  if type(capa) ~= "table" or not (EnteroMapa(capa.layerWidth) and EnteroMapa(capa.layerHeight) and EnteroMapa(capa.tileWidth) and EnteroMapa(capa.tileHeight)) then return end
  local cantidad = math.ceil(capa.layerWidth / capa.tileWidth) * math.ceil(capa.layerHeight / capa.tileHeight)
  if cantidad > 1024 then return end -- límite defensivo de recursos, no un dato del juego
  local okT, texturas = pcall(C_Map.GetMapArtLayerTextures, id, 1)
  if not okT or type(texturas) ~= "table" or #texturas ~= cantidad then return end
  for i = 1, cantidad do
    local t = texturas[i]
    if (issecretvalue and issecretvalue(t)) or not (EnteroMapa(t) or (type(t) == "string" and t ~= "")) then return end
  end
  return capa, texturas
end
local function GeometriaLoseta(capa,i)
  local cols = math.ceil(capa.layerWidth / capa.tileWidth)
  local x,y = ((i-1)%cols)*capa.tileWidth, math.floor((i-1)/cols)*capa.tileHeight
  local w,h = math.min(capa.tileWidth,capa.layerWidth-x),math.min(capa.tileHeight,capa.layerHeight-y)
  return x,y,w,h,w/capa.tileWidth,h/capa.tileHeight
end
local function Plantas(m, preferirJuego)
  local propias = PlantasAddon(m)
  if not preferirJuego and #propias > 0 then return propias, "dibujo" end
  local ok, pl = pcall(PlantasJuego, m)
  local validas = {}
  if ok and type(pl) == "table" then
    for _, p in ipairs(pl) do if ArteJuego(p.id) then validas[#validas + 1] = p end end
  end
  if #validas > 0 then return validas, "cliente" end
  return propias, "dibujo"
end
GL._plantasCartografia = Plantas
local function CoordMapa(x, y)
  if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return false end
  return type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1
end
GL._coordMapaValida = CoordMapa
function GL._posicionPlantaMazmorra(id)
  if not EnteroMapa(id) then return end
  local ok, x, y = pcall(function()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local actual = EnteroMapa(C_Map.GetBestMapForUnit("player"))
    if actual ~= id then return end
    local pos = C_Map.GetPlayerMapPosition(id, "player")
    if pos and pos.GetXY then return pos:GetXY() end
  end)
  if ok and CoordMapa(x,y) and (x~=0 or y~=0) then return x,y end
end
PlantasJuego = function(m)
  local idx = IndiceMapas()
  local nombreCliente = m.mapaNombre or (GL.LC and GL.LC(m.clave or m.n)) or m.n
  local ids = idx[Minus(nombreCliente)] or idx[Minus(m.n)] or idx[Minus(m.clave)]
  -- Sin coincidencia exacta no se elige una mazmorra distinta por prefijo.
  if not ids then return {} end
  local plantas, vistos = {}, {}
  local function Grupo(id)
    if not C_Map.GetMapGroupID then return nil end
    local ok,g = pcall(C_Map.GetMapGroupID,id)
    return ok and EnteroMapa(g) or nil
  end
  local grupo = Grupo(ids[1])
  -- Nombres idénticos no prueban que las plantas pertenezcan a la misma instancia.
  if #ids > 1 then
    if not grupo then return {} end
    for i=2,#ids do if Grupo(ids[i]) ~= grupo then return {} end end
  end
  if grupo and C_Map.GetMapGroupMembersInfo then
    local ok, miembros = pcall(C_Map.GetMapGroupMembersInfo, grupo)
    if ok and type(miembros) == "table" then
      local orden = {}
      for _, f in ipairs(miembros) do
        if type(f) == "table" and EnteroMapa(f.mapID) and Grupo(f.mapID) == grupo then
          local okM, info = pcall(C_Map.GetMapInfo, f.mapID)
          if okM and type(info) == "table" and (info.mapType == 4 or info.mapType == 5) then
            local h = f.relativeHeightIndex
            if (issecretvalue and issecretvalue(h)) or type(h) ~= "number" or h ~= h or math.abs(h) == math.huge then h = 0 end
            orden[#orden+1] = {id=f.mapID,n=f.name,h=h}
          end
        end
      end
      table.sort(orden,function(a,b) if a.h==b.h then return a.id<b.id end return a.h>b.h end)
      for _, f in ipairs(orden) do if not vistos[f.id] then vistos[f.id]=true; plantas[#plantas+1]=f end end
    end
  end
  for _, id in ipairs(ids) do if not vistos[id] then vistos[id] = true; table.insert(plantas, { id = id }) end end
  for i, p in ipairs(plantas) do p.n = (type(p.n) == "string" and p.n ~= "") and p.n or (L"Planta " .. i) end
  return plantas
end

-- Jefe de DatosWowhead que corresponde a un nombre del diario (sin el prefijo "Cementerio: " y sin "(raro)").
local function ClaveCartografica(n)
  if type(n) ~= "string" or (issecretvalue and issecretvalue(n)) then return nil end
  n = n:gsub("^[^:]+: ", "")
  if GL.EnIngles then n = GL.EnIngles(n) end
  n = n:gsub(" %(.*%)$", "")
  if GL.EnIngles then n = GL.EnIngles(n) end
  return Minus(n):gsub(" %(.*%)$", "")
end
-- Primero la identidad completa (incluida el ala); solo después el nombre corto.
local function IdentidadJefeMapa(n)
  if type(n) ~= "string" or (issecretvalue and issecretvalue(n)) then return nil end
  if GL.EnIngles then n = GL.EnIngles(n) end
  return Minus(n)
end
local function JefePorNombre(m, nombre)
  local completa, buscado = IdentidadJefeMapa(nombre), ClaveCartografica(nombre)
  if not buscado or buscado == "" then return nil end
  local function Buscar(clave, fn)
    local encontrado
    for _, j in ipairs(Jefes(m)) do
      if fn(j.n) == clave or fn(j.ing) == clave or fn(j.nombreOriginal977) == clave then
        if encontrado and encontrado ~= j then return nil, true end
        encontrado = j
      end
    end
    return encontrado, false
  end
  local exacto, ambiguo = Buscar(completa, IdentidadJefeMapa)
  if exacto or ambiguo then return exacto end
  return Buscar(buscado, ClaveCartografica)
end

-- 9.4.1: con el mapa en grande, el botín sale dentro del mapa, a la derecha de la lista de jefes
local ABAJO_GRANDE = 200      -- alto de la zona de jefes y botín, debajo del dibujo

-- 9.7.6: en el modo mazmorra, el jefe bajo el ratón (o el elegido con clic) se resalta en el mapa y en la lista
local GRUPOS_CARTOGRAFICOS = {
    -- Zul'Farrak: referencia al área del evento, no a un punto de aparición fijo.
    { "Nekrum Cometripas", "Nekrum Gutchewer", "Sacerdote oscuro Sezz'ziz", "Shadowpriest Sezz'ziz", "Sargento Bly", "Sergeant Bly" },
    -- Atal'Hakkar: sala compartida; la planta disponible es moderna.
    { "Jammal'an el Profeta", "Jammal'an the Prophet", "Ogom el Desdichado", "Ogom the Wretched" },
    { "Inferior: Halycon", "Inferior: Gizrul el esclavista", "Gizrul the Slavener" },
    { "Superior: Jefe de Guerra Desgarro Puño Negro", "Superior: Gyth" },
    { "Vivo: Gran Cruzado Dathrohan / Balnazzar", "Vivo: Sothos y Jarien (invocados)", "Sothos and Jarien" },
    { "Superior: La Bestia", "Superior: Lord Valthalak (invocado)" },
    { "Norte: Rey Gordok", "King Gordok", "Norte: Cho'Rush el Observador", "Cho'Rush the Observer" },
    { "Guarda Stilgiss", "Warder Stilgiss", "Verek", "Vigía Presaletal", "Watchman Doomgrip" },
    -- Scholomance: referencias de sala, no punto exacto de invocación.
    { "Ras Levescarcha", "Ras Frostwhisper", "Kormok" },
    { "Traquesangre", "Rattlegore", "Death Knight Darkreaver" },
  }
-- Índice fijo: las traducciones se cargan antes de este módulo en el TOC.
local INDICE_CARTOGRAFICO = {}
local function IndexarGrupoCartografico(grupo)
  local destino = ClaveCartografica(grupo[1])
  for _, nombre in ipairs(grupo) do
    local clave = ClaveCartografica(nombre)
    assert(not INDICE_CARTOGRAFICO[clave] or INDICE_CARTOGRAFICO[clave] == destino, "Grupo cartográfico ambiguo: " .. nombre)
    INDICE_CARTOGRAFICO[clave] = destino
  end
end
for _, grupo in ipairs(GRUPOS_CARTOGRAFICOS) do IndexarGrupoCartografico(grupo) end
IndexarGrupoCartografico({ "Los enanos perdidos (Baelog, Eric y Olaf)", "Baelog", "Eric «The Swift»", "Eric the Swift", "Olaf" })
local function ClaveJefe(n)
  if type(n) ~= "string" then return nil end
  local k = ClaveCartografica(n)
  return INDICE_CARTOGRAFICO[k] or IdentidadJefeMapa(n)
end
GL.ClaveJefe = ClaveJefe
-- Un grupo compartido representa una referencia de sala, no botín ni muerte compartidos.
local function MarcadorValido(j)
  return type(j) == "table" and CoordMapa(j[1], j[2]) and type(j[3]) == "string" and not (issecretvalue and issecretvalue(j[3])) and j[3] ~= ""
end
local function JefesConMarca(m, plantas)
  local marcados, grupos = {}, {}
  for _, pl in ipairs(plantas or {}) do
    for _, j in ipairs(pl.jefes or {}) do
      if MarcadorValido(j) then
        local jefe = JefePorNombre(m, j[3])
        if jefe then marcados[jefe] = true end
        local grupo = INDICE_CARTOGRAFICO[ClaveCartografica(j[3])]
        if grupo then grupos[grupo] = true end
      end
    end
  end
  return marcados, grupos
end
local function TieneMarca(j, marcados, grupos)
  if marcados[j] then return true end
  for _, n in pairs({j.n, j.ing, j.nombreOriginal977}) do
    local grupo = INDICE_CARTOGRAFICO[ClaveCartografica(n)]
    if grupo and grupos[grupo] then return true end
  end
  return false
end
local function EncuentrosEnPlanta(id)
  local salida, vistos = {}, {}
  if not EnteroMapa(id) or not (C_EncounterJournal and C_EncounterJournal.GetEncountersOnMap) then return salida end
  local ok, enc = pcall(C_EncounterJournal.GetEncountersOnMap, id)
  if not ok or type(enc) ~= "table" then return salida end
  for _, e in ipairs(enc) do
    if type(e) == "table" then
      local eid = EnteroMapa(e.encounterID)
      if eid and CoordMapa(e.mapX, e.mapY) and not vistos[eid] then
        local okN, nombre = pcall(EJ_GetEncounterInfo, eid)
        if okN and type(nombre) == "string" and not (issecretvalue and issecretvalue(nombre)) and nombre ~= "" then
          vistos[eid] = true
          salida[#salida+1] = {nombre=nombre, mapX=e.mapX, mapY=e.mapY, encounterID=eid}
        end
      end
    end
  end
  return salida
end

-- Solo cambiar de planta al elegir un jefe con una ubicación individual inequívoca.
local function PlantaDelJefe(f, nombre)
  if not f or not f.m then return nil end
  local objetivo = JefePorNombre(f.m, nombre)
  if not objetivo then return nil end
  local hallada
  for i, pl in ipairs(f.plantas or {}) do
    local coincide = false
    if pl.img then
      for _, j in ipairs(pl.jefes or {}) do
        if MarcadorValido(j) and JefePorNombre(f.m, j[3]) == objetivo then coincide = true; break end
      end
    elseif pl.id then
      for _, e in ipairs(EncuentrosEnPlanta(pl.id)) do
        if JefePorNombre(f.m, e.nombre) == objetivo then coincide = true; break end
      end
    end
    if coincide then
      if hallada then return nil end
      hallada = i
    end
  end
  return hallada
end

local function ClavePin(b)
  if b.jefe then return ClaveJefe(b.jefe.n) end
  -- Solo un grupo declarado permite resaltar una referencia sin identidad individual.
  return INDICE_CARTOGRAFICO[ClaveCartografica(b.nombre)]
end
local function PintarResalte()
  local f = mapa
  if not f then return end
  local k = f.modo and (f.resaltado or f.jefeSelModo) or nil
  for _, b in ipairs(f.pinsImg or {}) do
    if b.resalte then
      if k and b:IsShown() and ClavePin(b) == k then b.resalte:Show() else b.resalte:Hide() end
    end
  end
  for _, b in ipairs(f.pins or {}) do
    if b.fondo then
      local si = k and ClavePin(b) == k
      if si then b.fondo:SetColorTexture(0.85, 0.62, 0.08, 0.95) else b.fondo:SetColorTexture(0.35, 0.05, 0.05, 0.9) end
    end
  end
end
-- el botín suelto, junto al panel del modo mazmorra (o junto al mapa ampliado, para no taparlo)
local function AnclarBotin(b)
  if not b or not b.ClearAllPoints then return end
  local ven = _G.GuiaAventureroModoMazmorra
  local ref = (mapa and mapa.modo == "lado" and mapa:IsShown()) and mapa or ven
  if not ref then return end
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", ref, "TOPRIGHT", 8, 0)
end
local function PasarJefe(self, dentro)
  if not (mapa and mapa.modo) then return end
  local k = dentro and ClavePin(self) or nil
  mapa.resaltado = k
  PintarResalte()
  if GL.ResaltarJefePanel then GL.ResaltarJefePanel(k) end
end

local function BotinJefe(nombre, botin, identidad)
  local f = mapa
  if f and f.modo then   -- 9.7.6: modo mazmorra: queda elegido en el mapa y en la lista, y sale su botín
    f.jefeSelModo = ClaveJefe(identidad or nombre)
    PintarResalte()
    if GL.ElegirJefePanel then GL.ElegirJefePanel(f.jefeSelModo) end
    AnclarBotin(GL.VerBotin and GL.VerBotin(nombre, botin or {}))
    return
  end
  if f and f.grande and f.botinMapa then
    f.jefeSel = identidad or nombre
    f.botinTitulo:SetText(nombre or L"Botín")
    f.botinMapa.desp = 0
    f.botinMapa:ClearAllPoints()
    f.botinMapa:SetPoint("TOPLEFT", f.zonaBotin, "TOPLEFT", 0, 0)
    f.botinMapa:SetPoint("TOPRIGHT", f.zonaBotin, "TOPRIGHT", 0, 0)
    f.botinMapa:Mostrar(botin or {})
    for _, b in ipairs(f.listaJefes or {}) do if b.SetActivo then b:SetActivo(b.identidad == f.jefeSel) end end
    return
  end
  if GL.VerBotin then GL.VerBotin(nombre, botin or {}) end
end

-- Las ilustraciones pequeñas son estáticas; los cambios de planta, fuente,
-- tamaño y selección conservan sus propios controladores de repintado.
local function NecesitaRefrescoMapa977(f)
  if not f or not f:IsShown() then return false end
  local p = f.plantas and f.plantas[f.planta]
  -- La vista grande contiene botín y el mapa del cliente muestra la posición.
  return f.grande == true or not (p and p.img)
end
GL._necesitaRefrescoMapa977 = NecesitaRefrescoMapa977

local function ActualizarPosicionMapa(f)
  if not f or not f.tu then return end
  f.tu:Hide()
  local p = f.plantas and f.plantas[f.planta]
  if not (f:IsShown() and p and not p.img and f.escala) then return end
  local x, y = GL._posicionPlantaMazmorra(p.id)
  if x then
    f.tu:ClearAllPoints()
    f.tu:SetPoint("CENTER", f.lienzo, "TOPLEFT", f.ox + x * f.aw, -(f.oy + y * f.ah))
    f.tu:Show()
  end
end
local function LimpiarResalte(f)
  f.resaltado = nil
  if f.modo and GL.ResaltarJefePanel then GL.ResaltarJefePanel(nil) end
end
local function PintarMapa()
  local f = mapa
  if not f or not f:IsShown() or not f.m then return end
  local m, p = f.m, f.plantas[f.planta]
  for _, b in ipairs(f.botonesPlanta) do b:Hide() end
  for _, t in ipairs(f.losetas) do t:Hide() end
  for _, b in ipairs(f.pins) do b:Hide() end
  for _, b in ipairs(f.pinsImg) do b:Hide() end
  f.tu:Hide()
  f.escala = nil
  local x0, fila = 0, 0
  local anchoPlantas = math.max(24, (f:GetWidth() or 400) - 16)
  for i, pl in ipairs(f.plantas) do
    local b = f.botonesPlanta[i]
    if not b then
      b = GL.CrearBoton(f, "", function(self) LimpiarResalte(mapa); mapa.planta = self.i; PintarMapa() end, nil, 18)
      f.botonesPlanta[i] = b
    end
    b.i = i
    b.texto:SetText(pl.n)
    b:SetWidth(math.min(120, (b.texto.GetStringWidth and b.texto:GetStringWidth() or 60) + 16))
    b:ClearAllPoints()
    b:SetWidth(math.min(anchoPlantas, b:GetWidth()))
    if x0 > 0 and x0 + b:GetWidth() > anchoPlantas then x0, fila = 0, fila + 1 end
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + x0, -28 - fila * 22)
    if b.SetActivo then b:SetActivo(i == f.planta) end
    b:Show()
    x0 = x0 + b:GetWidth() + 4
  end
  local arriba = (#f.plantas > 0) and (50 + fila * 22) or 28
  local lienzo = f.lienzo
  lienzo:ClearAllPoints()
  lienzo:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -arriba)
  lienzo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, f.grande and (30 + ABAJO_GRANDE) or 40)
  -- 9.4.1: en grande, debajo del dibujo la lista de jefes (clic: su botín) y a su derecha el botín
  for _, b in ipairs(f.listaJefes) do b:Hide() end
  GL.Mostrar(f.tituloJefes, f.grande == true)
  GL.Mostrar(f.zonaBotin, f.grande == true)
  GL.Mostrar(f.botinTitulo, f.grande == true)
  if f.grande then
    local filas = math.max(1, math.floor((ABAJO_GRANDE - 26) / 22))
    local jefes = Jefes(m)
    local cols = math.min(2, math.max(1, math.ceil(#jefes / filas)))
    local i = 0
    for _, j in ipairs(jefes) do
      if i >= filas * cols then break end
      i = i + 1
      local b = f.listaJefes[i]
      if not b then
        b = GL.CrearBoton(f, "", function(self) BotinJefe(self.nombre, self.botin or {}, self.identidad) end, nil, 20)
        b:SetWidth(200)
        GL.UnaLinea(b.texto)
        if GL.Ayuda then GL.Ayuda(b) end
        f.listaJefes[i] = b
      end
      b.nombre, b.botin, b.identidad = (j.n:gsub("^[^:]+: ", "")), j.botin, j.n
      b.texto:SetText(b.nombre .. ((j.botin and #j.botin > 0) and (C.GRIS .. "  (" .. #j.botin .. ")" .. C.FIN) or ""))
      b.ayudaTitulo, b.ayudaTexto = b.nombre, L"Clic: su botín."
      local ubicacion = GL.TextoUbicacionJefe977(j)
      if ubicacion ~= "" then b.ayudaTexto = b.ayudaTexto .. "\n" .. ubicacion end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", f.tituloJefes, "BOTTOMLEFT", math.floor((i - 1) / filas) * 204, -4 - ((i - 1) % filas) * 22)
      b:Show()
    end
    f.zonaBotin:ClearAllPoints()
    f.zonaBotin:SetPoint("TOPLEFT", f.tituloJefes, "BOTTOMLEFT", cols * 204 + 8, -4)
    f.zonaBotin:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 26)
    -- el primer jefe (o el elegido) con su botín ya a la vista
    local sel
    for _, j in ipairs(jefes) do
      if j.n == f.jefeSel then sel = j end
    end
    sel = sel or jefes[1]
    if sel then BotinJefe((sel.n:gsub("^[^:]+: ", "")), sel.botin or {}, sel.n)
    else f.botinTitulo:SetText(""); f.botinMapa:Mostrar({}) end
  end
  if not p then
    f.aviso:SetText(C.GRIS .. (m.banda and L"El juego no da el dibujo de esta banda. Debajo, sus jefes: clic en uno para ver su botín."
      or ((m.n == "Bastión Faucenegra" or m.n == L"Bastión Faucenegra" or m.n == "Prisión de Alcaz" or m.n == L"Prisión de Alcaz") and L"Mapa aplazado para próximas versiones. Debajo, sus jefes y su botín.")
      or (m.nueva and L"Mapa no disponible en esta versión de la guía.")
      or L"La guía todavía no tiene el dibujo de esta mazmorra. Debajo, sus jefes: clic en uno para ver su botín.") .. C.FIN)
    f.leyenda:SetText("")
    return
  end
  if p.img then   -- 7.6.5: imagen incluida en el addon; 7.6.6: jefes en su sitio
    local W, H = lienzo:GetWidth() or 0, lienzo:GetHeight() or 0
    if W <= 0 or H <= 0 then W, H = 300, 200 end
    local iw, ih = p.w or 772, p.h or 515
    local s = math.min(W / iw, H / ih)
    local aw, ah = iw * s, ih * s
    local ox = (W - aw) / 2
    local t = f.losetas[1]
    if not t then t = lienzo:CreateTexture(nil, "ARTWORK"); f.losetas[1] = t end
    t:SetTexture(p.img)
    if t.SetTexCoord then t:SetTexCoord(0, 1, 0, 1) end
    t:SetSize(aw, ah)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", lienzo, "TOPLEFT", ox, 0)
    t:Show()
    f.escala = nil
    f.aviso:SetText("")
    local lado = math.max(14, aw * 0.05)   -- 9.5: zona del tamaño de la calavera pintada
    for i, j in ipairs(p.jefes or {}) do
      if MarcadorValido(j) then
      local b = f.pinsImg[i]
      if not b then
        b = CreateFrame("Button", nil, lienzo)
        b.icono = b:CreateTexture(nil, "OVERLAY")
        b.icono:SetAllPoints()
        b.icono:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        b.luz = b:CreateTexture(nil, "HIGHLIGHT")
        b.luz:SetAllPoints()
        b.luz:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        if b.luz.SetBlendMode then b.luz:SetBlendMode("ADD") end
        b.resalte = b:CreateTexture(nil, "OVERLAY")   -- 9.7.6: resaltado desde la lista del modo mazmorra
        b.resalte:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.resalte:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        if b.resalte.SetBlendMode then b.resalte:SetBlendMode("ADD") end
        b.resalte:SetVertexColor(1, 0.82, 0)
        b.resalte:Hide()
        b:SetScript("OnClick", function(self)
          local jf = self.jefe
          if jf then BotinJefe(self.nombre, jf.botin or {}, jf.n) end
        end)
        b:SetScript("OnEnter", function(self)
          PasarJefe(self, true)
          local jf = self.jefe
          if jf and mapa and mapa.grande then BotinJefe(self.nombre, jf.botin or {}, jf.n) end   -- 9.5: el botín al pasar el ratón
          if not GameTooltip then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText(self.nombre, 1, 0.82, 0)
          GameTooltip:AddLine(not jf and L"Identidad del jefe sin confirmar; consulta la lista de jefes." or (mapa and mapa.grande and L"Su botín sale debajo del mapa." or L"Clic: su botín."), 1, 1, 1, true)
          local ubicacion = GL.TextoUbicacionJefe977(jf)
          if ubicacion ~= "" then GameTooltip:AddLine(ubicacion, 1, 1, 1, true) end
          GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) PasarJefe(self, false); if GameTooltip then GameTooltip:Hide() end end)
        f.pinsImg[i] = b
      end
      local jefe = JefePorNombre(m, j[3])
      b.jefe = jefe
      b.nombre = ((jefe and jefe.n or j[3]):gsub("^[^:]+: ", ""))
      b:SetSize(lado, lado)
      b.resalte:SetSize(lado * 1.9, lado * 1.9)
      GL.Mostrar(b.icono, j.overlay977 == true)   -- 9.7.7: nuevas marcas visibles sin modificar las imágenes; las antiguas ya están pintadas
      b:ClearAllPoints()
      if CoordMapa(j[1], j[2]) then
        b:SetPoint("CENTER", lienzo, "TOPLEFT", ox + j[1] * aw, -(j[2] * ah))
        b:Show()
      end
      end
    end
    local sin, sinNombres = 0, {}
    local marcados, grupos = JefesConMarca(m, f.plantas)
    for _, x in ipairs(Jefes(m)) do
      if not TieneMarca(x, marcados, grupos) and x.botin and not x.comun977 and not x.n:find(L"otín sin jefe") and not x.n:find(L"^Bichos") then
        sin = sin + 1
        if #sinNombres < 4 then table.insert(sinNombres, (x.n:gsub("^[^:]+: ", ""))) end
      end
    end
    local pie = (#f.plantas > 1) and (L"Planta " .. f.planta .. L" de " .. #f.plantas .. ". ") or ""
    local jefesTxt = (#(p.jefes or {}) > 0) and L"Pasa el ratón por una calavera: su botín. " or ""
    PintarResalte()
    f.leyenda:SetText(C.GRIS .. pie .. jefesTxt .. (sin > 0 and (L"Sin marca en el dibujo: " .. table.concat(sinNombres, ", ") .. (sin > #sinNombres and (" y " .. (sin - #sinNombres) .. L" más") or "") .. ". " .. L"Las posiciones sin confirmar se incorporarán en próximas versiones. ") or "") .. L"Mapa: " .. L"Ilustración orientativa; geometría no certificada." .. (p.archivo == "m1477-1" and (" " .. L"Solo planta moderna; faltan zonas clásicas.") or "") .. (p.entrada and L" El remolino azul es la entrada." or "") .. C.FIN)
    return
  end
  local capa, texturas = ArteJuego(p.id)
  local W, H = lienzo:GetWidth() or 0, lienzo:GetHeight() or 0
  if not (capa and texturas and W > 0 and H > 0) then
    f.aviso:SetText(C.GRIS .. L"No se pudo cargar el dibujo del mapa de esta planta." .. C.FIN)
  else
    f.aviso:SetText("")
    local s = math.min(W / capa.layerWidth, H / capa.layerHeight)
    local ox, oy = (W - capa.layerWidth * s) / 2, (H - capa.layerHeight * s) / 2
    f.escala, f.ox, f.oy, f.aw, f.ah = s, ox, oy, capa.layerWidth * s, capa.layerHeight * s
    for i, tex in ipairs(texturas) do
      local t = f.losetas[i]
      if not t then t = lienzo:CreateTexture(nil, "ARTWORK"); f.losetas[i] = t end
      local x,y,w,h,u,v = GeometriaLoseta(capa,i)
      t:SetTexture(tex)
      if t.SetTexCoord then t:SetTexCoord(0,u,0,v) end
      t:SetSize(w*s,h*s)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", lienzo, "TOPLEFT", ox+x*s, -(oy+y*s))
      t:Show()
    end
  end
  -- jefes del diario de encuentros en esta planta
  local nombres = {}
  if f.escala then
    for i, e in ipairs(EncuentrosEnPlanta(p.id)) do
      local nombre = e.nombre
      local b = f.pins[i]
      if not b then
        b = CreateFrame("Button", nil, lienzo)
        b:SetSize(20, 20)
        b.fondo = b:CreateTexture(nil, "OVERLAY")
        b.fondo:SetAllPoints()
        b.fondo:SetColorTexture(0.35, 0.05, 0.05, 0.9)
        b.num = GL.Texto(b, "GameFontNormalSmall")
        b.num:SetPoint("CENTER", b, "CENTER", 0, 0)
        b:SetScript("OnClick", function(self)
          local j = self.jefe
          if j then BotinJefe(j.n, j.botin or {}, j.n) end
        end)
        b:SetScript("OnEnter", function(self)
          PasarJefe(self, true)
          if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.nombre); if not self.jefe then GameTooltip:AddLine(L"Identidad del jefe sin confirmar; consulta la lista de jefes.",1,1,1,true) end; GameTooltip:Show() end
        end)
        b:SetScript("OnLeave", function(self) PasarJefe(self, false); if GameTooltip then GameTooltip:Hide() end end)
        f.pins[i] = b
      end
      b.nombre, b.jefe = nombre, JefePorNombre(m, nombre)
      b.num:SetText(tostring(i))
      b:ClearAllPoints()
      b:SetSize(f.grande and 26 or 20, f.grande and 26 or 20)
      if CoordMapa(e.mapX, e.mapY) then
        b:SetPoint("CENTER", lienzo, "TOPLEFT", f.ox + e.mapX * f.aw, -(f.oy + e.mapY * f.ah))
        b:Show()
        table.insert(nombres, i .. " " .. nombre)
      end
    end
  end
  ActualizarPosicionMapa(f)
  PintarResalte()
  f.leyenda:SetText(C.GRIS .. L"Mapa del cliente; puede corresponder a otra versión." .. " " .. (#nombres > 0 and (table.concat(nombres, " · ") .. L"  (clic en un número: su botín)") or L"El juego no da la posición de los jefes en esta planta.") .. C.FIN)
end

-- 9.4: el mapa en grande, en medio de la pantalla (se recuerda: GuiaAventureroDB.mapaGrande). El botín sale a su derecha.
local function TamanoMapa(grande, guardar)
  local f = mapa
  if not f then return end
  f.grande = grande and true or false
  if guardar ~= false then GuiaAventureroDB.mapaGrande = f.grande end
  f:ClearAllPoints()
  if f.grande then
    f:SetParent(UIParent)
    f:SetFrameStrata("HIGH")
    local W, H = UIParent:GetWidth() or 1280, UIParent:GetHeight() or 800
    local ancho = math.max(640, math.min(1000, W - 120))
    f:SetSize(ancho, math.max(560, math.min(860, H * 0.92)))
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)   -- 9.4.1: jefes y botín van dentro, debajo del dibujo
    local suelta = _G.GuiaAventureroBotin
    if suelta and suelta.Hide then suelta:Hide() end
  else
    f:SetParent(panel)
    f:SetFrameStrata(panel:GetFrameStrata() or "MEDIUM")
    f:SetAllPoints(panel)
    f:SetFrameLevel((panel:GetFrameLevel() or 1) + 20)
  end
  if UISpecialFrames then   -- Esc cierra el mapa grande
    GL.RegistrarCierreEscapeR13("GuiaAventureroMapaMazmorra", f.grande == true)
  end
  f.ampliar.texto:SetText(f.grande and L"Reducir" or L"Ampliar")
  f.ampliar.ayudaTexto = f.grande and L"Vuelve a ponerlo dentro de la guía." or L"Abre el mapa en grande en medio de la pantalla, con los jefes."
  PintarMapa()
end

-- 9.4.2: los mapas de mazmorras y bandas, apagados hasta que estén todos bien. Para volver a verlos: true.
-- No se borra nada: el código sigue entero, solo se ocultan los botones Mapa y no se abre la ventana del mapa.
GL.MAPAS_MAZMORRAS = true   -- 9.5: encendidos con los mapas nuevos

-- 9.7.6: en el modo mazmorra el mapa va dentro de su panel, debajo de las misiones ("dentro"); con «Ampliar»,
-- más grande a la derecha del panel ("lado"). El sitio de "dentro" lo pone GL.RefrescarModoMazmorra.
local ANCHO_LADO, ALTO_LADO, ALTO_DENTRO = 560, 600, 310
local function ColocarEnModo(modo)
  local f, ven = mapa, _G.GuiaAventureroModoMazmorra
  if not f or not ven then return end
  f.modo, f.grande = modo, false
  f:ClearAllPoints()
  f:SetFrameStrata(ven:GetFrameStrata() or "MEDIUM")
  if modo == "lado" then
    f:SetParent(UIParent)
    f:SetSize(ANCHO_LADO, ALTO_LADO)
    f:SetPoint("TOPLEFT", ven, "TOPRIGHT", 8, 0)
  else
    f:SetParent(ven)
    f:SetSize((ven:GetWidth() or 300) - 12, ALTO_DENTRO)
    f:SetPoint("TOPLEFT", ven, "TOPLEFT", 6, -200)
  end
  f:SetFrameLevel((ven:GetFrameLevel() or 1) + 5)
  if UISpecialFrames then GL.RegistrarCierreEscapeR13("GuiaAventureroMapaMazmorra", false) end
  if f.m then f.titulo:SetText(modo == "lado" and (f.m.n .. C.GRIS .. L"  · mapa" .. C.FIN) or f.m.n) end   -- estrecho: solo el nombre
  f.ampliar.texto:SetText(modo == "lado" and L"Reducir" or L"Ampliar")
  f.ampliar.ayudaTexto = (modo == "lado") and L"Vuelve a ponerlo debajo de las misiones." or L"Abre el mapa más grande, a la derecha del panel."
  f:Show()
  PintarMapa()
end

local AbrirMapa
GL.MapaModoMazmorra = {
  ALTO = ALTO_DENTRO,
  -- abre el mapa de m dentro del panel; false si la guía no tiene dibujo ni el juego da el mapa
  Abrir = function(m)
    if not GL.MAPAS_MAZMORRAS or not panel or not m then return false end
    local ok, pl = pcall(Plantas, m)
    if not ok or type(pl) ~= "table" or #pl == 0 then
      if mapa and mapa.modo then mapa:Hide(); mapa.modo = nil end
      return false
    end
    if not (mapa and mapa.modo and mapa.m and mapa.m.n == m.n) and mapa then mapa.jefeSelModo, mapa.resaltado = nil, nil end
    AbrirMapa(m, true)
    ColocarEnModo("dentro")
    return true
  end,
  -- desde la lista de jefes del panel: resaltar (al pasar el ratón) o elegir (clic) en el mapa
  Resaltar = function(k) if mapa then mapa.resaltado = k; PintarResalte() end end,
  Elegir = function(k, identidad)
    if not (mapa and mapa.modo and mapa:IsShown()) then return end
    LimpiarResalte(mapa)
    mapa.jefeSelModo = k
    local i = PlantaDelJefe(mapa, identidad)
    if i and i ~= mapa.planta then mapa.planta = i; PintarMapa() else PintarResalte() end
  end,
  AnclarBotin = AnclarBotin,
  Ampliar = function()
    if not mapa or not mapa.modo then return end
    ColocarEnModo(mapa.modo == "lado" and "dentro" or "lado")
    if GL.RefrescarModoMazmorra then GL.RefrescarModoMazmorra() end
  end,
  Cerrar = function()
    if mapa and mapa.modo then LimpiarResalte(mapa); mapa.jefeSelModo = nil; mapa:Hide(); mapa.modo = nil; TamanoMapa(GuiaAventureroDB.mapaGrande == true, false); mapa:Hide() end
  end,
  Frame = function() return mapa end,
}

local function SeleccionMapa(f,m)
  local misma = f.m and (f.m.clave or f.m.n) == (m.clave or m.n) and (not not f.m.banda) == (not not m.banda)
  local anterior = misma and f.plantas and f.plantas[f.planta]
  local plantas, fuente = Plantas(m, misma and f.fuenteActiva == "cliente")
  local indice = 1
  if anterior then
    for i,p in ipairs(plantas) do
      if (anterior.id and p.id == anterior.id) or (anterior.archivo and p.archivo == anterior.archivo) then indice=i;break end
    end
  end
  return plantas, fuente, indice
end

AbrirMapa = function(m, enModo)
  if not GL.MAPAS_MAZMORRAS then return end
  if not mapa then
    local f = CreateFrame("Frame", "GuiaAventureroMapaMazmorra", panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetAllPoints(panel)
    f:SetFrameLevel((panel:GetFrameLevel() or 1) + 20)
    f:EnableMouse(true)
    if GL.Caja and GL.COLOR then GL.Caja(f, { 0.04, 0.05, 0.07, 0.98 }, GL.COLOR.cajaBorde) end
    f.titulo = GL.Texto(f, "GameFontNormal")
    f.titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    f.titulo:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -7); GL.UnaLinea(f.titulo)   -- 7.6.1
    f.cerrar = GL.CrearBoton(f, "X", function()
      mapa:Hide()
      if mapa.modo and GL.RefrescarModoMazmorra then GL.RefrescarModoMazmorra() end   -- 9.7.6: el panel se encoge
    end, nil, 20, "cerrar")
    f.cerrar:SetWidth(22)
    f.cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.ampliar = GL.CrearBoton(f, L"Ampliar", function()   -- 9.4
      if mapa.modo and GL.MapaModoMazmorra then GL.MapaModoMazmorra.Ampliar(); return end   -- 9.7.6: modo mazmorra
      TamanoMapa(not mapa.grande)
    end, nil, 20)
    f.ampliar:SetWidth(72)
    f.ampliar.texto:SetJustifyH("CENTER")
    f.ampliar:SetPoint("RIGHT", f.cerrar, "LEFT", -4, 0)
    if GL.Ayuda then GL.Ayuda(f.ampliar, L"Mapa grande") end
    f.fuenteMapa = GL.CrearBoton(f, L"Cliente", function()
      local preferir = f.fuenteActiva ~= "cliente"
      local plantas, fuente = Plantas(f.m, preferir)
      if (preferir and fuente ~= "cliente") or (not preferir and fuente ~= "dibujo") or #plantas == 0 then
        GL.Mensaje(L"No hay otra fuente de mapa disponible en este cliente.")
        return
      end
      LimpiarResalte(f)
      f.plantas, f.planta, f.fuenteActiva = plantas, 1, fuente
      f.fuenteMapa.texto:SetText(fuente == "cliente" and L"Dibujo" or L"Cliente")
      PintarMapa()
    end, nil, 20)
    f.fuenteMapa:SetWidth(70)
    f.fuenteMapa:SetPoint("RIGHT", f.ampliar, "LEFT", -4, 0)
    f.titulo:SetPoint("TOPRIGHT", f, "TOPRIGHT", -180, -7)
    f.tituloJefes = GL.Texto(f, "GameFontNormal")
    f.tituloJefes:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 30 + ABAJO_GRANDE - 22)
    f.tituloJefes:SetWidth(200)
    f.tituloJefes:SetText(L"Jefes")
    f.listaJefes = {}
    -- 9.4.1: el botín del jefe elegido, a la derecha de la lista (rueda del ratón si no cabe)
    f.zonaBotin = CreateFrame("Frame", nil, f)
    if f.zonaBotin.SetClipsChildren then f.zonaBotin:SetClipsChildren(true) end
    f.zonaBotin:EnableMouseWheel(true)
    f.botinTitulo = GL.Texto(f, "GameFontNormal")
    f.botinTitulo:SetPoint("BOTTOMLEFT", f.zonaBotin, "TOPLEFT", 0, 4)
    f.botinTitulo:SetPoint("RIGHT", f.zonaBotin, "RIGHT", 0, 0); GL.UnaLinea(f.botinTitulo)
    f.botinMapa = GL.CrearBloqueBotin(f.zonaBotin)
    f.botinMapa:SetPoint("TOPLEFT", f.zonaBotin, "TOPLEFT", 0, 0)
    f.botinMapa:SetPoint("TOPRIGHT", f.zonaBotin, "TOPRIGHT", 0, 0)
    f.zonaBotin:SetScript("OnMouseWheel", function(self, d)
      local b = mapa.botinMapa
      local sobra = math.max(0, (b:GetHeight() or 0) - (self:GetHeight() or 0))
      b.desp = math.max(0, math.min(sobra, (b.desp or 0) - d * 20))
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", self, "TOPLEFT", 0, b.desp)
      b:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, b.desp)
    end)
    f.zonaBotin:Hide(); f.botinTitulo:Hide()
    f:SetMovable(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if self.grande then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.lienzo = CreateFrame("Frame", nil, f)
    if f.lienzo.SetClipsChildren then f.lienzo:SetClipsChildren(true) end
    f.aviso = GL.Texto(f.lienzo, "GameFontHighlightSmall")
    f.aviso:SetPoint("TOPLEFT", f.lienzo, "TOPLEFT", 4, -4)
    f.aviso:SetPoint("RIGHT", f.lienzo, "RIGHT", -4, 0)
    f.tu = GL.Texto(f.lienzo, "GameFontNormal")
    f.tu:SetText(GL.Icono("▲"))
    f.leyenda = GL.Texto(f, "GameFontHighlightSmall")
    f.leyenda:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
    f.leyenda:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
    f.botonesPlanta, f.losetas, f.pins, f.pinsImg = {}, {}, {}, {}
    f:SetScript("OnSizeChanged", function() PintarMapa() end)
    local esperaPos, esperaBotin = 0, 0
    f:SetScript("OnUpdate", function(self, dt)
      esperaPos, esperaBotin = esperaPos + dt, esperaBotin + dt
      if esperaPos >= 0.25 then esperaPos = 0; ActualizarPosicionMapa(self) end
      -- Refrescar la vista grande (datos de objetos) también fuera de la lista.
      if esperaBotin >= CADA then
        esperaBotin = 0
        if self.grande and NecesitaRefrescoMapa977(self) then PintarMapa() end
      end
    end)
    f:SetScript("OnHide", function(self) self.tu:Hide(); LimpiarResalte(self) end)
    mapa = f
  end
  local plantas, fuente, indice = SeleccionMapa(mapa,m)
  if not mapa.m or (mapa.m.clave or mapa.m.n) ~= (m.clave or m.n) then mapa.jefeSel, mapa.jefeSelModo, mapa.resaltado = nil, nil, nil end
  mapa.m, mapa.plantas, mapa.planta, mapa.fuenteActiva = m, plantas, indice, fuente
  mapa.fuenteMapa.texto:SetText(fuente == "cliente" and L"Dibujo" or L"Cliente")
  mapa.titulo:SetText(m.n .. C.GRIS .. L"  · mapa" .. C.FIN)
  if enModo then return end   -- 9.7.6: lo coloca ColocarEnModo
  mapa:Show()
  if mapa.modo then mapa.modo = nil; TamanoMapa(GuiaAventureroDB.mapaGrande == true)   -- 9.7.6: venía del modo mazmorra
  elseif (GuiaAventureroDB.mapaGrande == true) ~= (mapa.grande == true) then TamanoMapa(GuiaAventureroDB.mapaGrande == true) else PintarMapa() end
end
-- 9.4: mapa de una banda (Bandas.lua): siempre en grande, con sus jefes (DatosBandas94.lua)
GL.AbrirMapaBanda = function(b)
  if not panel then return end
  local es = b.clave or b.n   -- nombre en español (b.n puede estar ya en inglés)
  AbrirMapa({ n = b.n, clave = es, banda = true, mapaNombre = (GL.clienteIngles and b.ing) or es })
  if not mapa then return end   -- 9.4.2: mapas apagados
  if not mapa.grande then TamanoMapa(true, false) end
end
GL._abrirMapaMazmorra = AbrirMapa   -- para las pruebas
GL._mapaMazmorra = function() return mapa end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)   -- sin pestañas: empieza bajo la cabecera
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  ui.CrearFila = CrearFila
  ui.Refrescar = Refrescar

  local titulo = GL.Texto(panel, "GameFontNormal")
  titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  titulo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -190, 0); GL.UnaLinea(titulo)   -- 9.4: a la derecha, las pestañas
  titulo:SetText(L"Mazmorras por nivel")
  ui.titulo = titulo
  ui.mas = GL.Texto(panel, "GameFontHighlightSmall")
  -- 9.4: pestañas Mazmorras y Bandas (Bandas.lua)
  if GL.CrearPestanas94 and GL.CrearVistaBandas then
    ui.pestanas = GL.CrearPestanas94(panel, { { "mazmorras", L"Mazmorras" }, { "bandas", L"Bandas" } }, function(id)
      GuiaAventureroDB.pestanaMaz = id; Refrescar()
    end, 90)
    ui.pestanas[1]:ClearAllPoints()
    ui.pestanas[1]:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -94, 2)
    ui.bandas = GL.CrearVistaBandas(panel)
  end

  -- desplegable de la mazmorra abierta
  -- 9.4.2: la lista va dentro de una franja que recorta lo que sobresale (al bajar con la rueda)
  ui.vista = CreateFrame("Frame", nil, panel)
  ui.vista:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -20)
  ui.vista:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 18)
  if ui.vista.SetClipsChildren then ui.vista:SetClipsChildren(true) end
  local d = CreateFrame("Frame", nil, ui.vista, BackdropTemplateMixin and "BackdropTemplate" or nil)
  if GL.Caja and GL.COLOR then GL.Caja(d, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  local borde = d:CreateTexture(nil, "ARTWORK")
  borde:SetWidth(3)
  borde:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
  borde:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0)
  borde:SetColorTexture(1, 0.78, 0.25, 1)
  -- 9.4.2: zona arriba, pestañas Misiones / Jefes y botín, y debajo el texto de la pestaña elegida
  d.zona = GL.Texto(d, "GameFontHighlightSmall")
  d.zona:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -6)
  d.zona:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -6)
  d.pest = GL.CrearPestanas94(d, { { "misiones", L"Misiones" }, { "jefes", L"Jefes y botín" } }, function(id)
    GuiaAventureroDB.pestanaDetMaz = id
    if d.m then elegidaEn[d.m.clave or d.m.n] = id end
    jefeAbierto = nil
    Refrescar()
  end, 150)
  d.texto = GL.Texto(d, "GameFontHighlightSmall")
  d.texto:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -32)
  d.texto:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -32)
  if d.texto.SetSpacing then d.texto:SetSpacing(2) end
  d.marcar = GL.CrearBoton(d, L"Marcar entrada", function() if d.m then MarcarEntrada(d.m) end end, nil, 20)
  d.marcar:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 10, 6)
  d.marcar:SetWidth(104)   -- 7.6.1: los tres botones caben con la ventana estrecha
  d.llevar = GL.CrearBoton(d, L"Llevarme", function()
    local destino = d.m and Destino(d.m)
    if destino and GL.SeguirDesvio then GL.SeguirDesvio(destino) end
  end, nil, 20, "accion")
  d.llevar:SetPoint("LEFT", d.marcar, "RIGHT", 6, 0)
  d.llevar:SetWidth(84)
  d.mapa = GL.CrearBoton(d, L"Mapa", function() if d.m then AbrirMapa(d.m) end end, nil, 20)   -- 7.6
  d.mapa:SetPoint("LEFT", d.llevar, "RIGHT", 6, 0)
  d.mapa:SetWidth(60)
  if not GL.MAPAS_MAZMORRAS then d.mapa:Hide() end   -- 9.4.2: mapas apagados
  d.jefes = {}   -- 7.5.16
  d.botin = GL.CrearBloqueBotin(d)
  d.botin.alCambiar = function() Refrescar() end
  d.botin:Hide()
  d:Hide()
  ui.detalle = d

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    if GuiaAventureroDB.pestanaMaz == "bandas" then return end
    px = math.max(0, math.min(ui.pxMax or 0, px - delta * 3 * ALTO_FILA))   -- 9.4.2: tres líneas por paso
    Refrescar()
  end)
  panel:SetScript("OnSizeChanged", function() Refrescar() end)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt)
    if not panel:IsShown() then return end
    espera = espera + dt
    if espera >= CADA then
      espera = 0
      Refrescar()
      -- El mapa visible actualiza su propia posición incluso si esta lista está oculta.
    end
  end)
  GL.modos.mazmorras = { panel = panel, refrescar = Refrescar }
end

table.insert(GL.alIniciar, CrearPanel)

-- Para las pruebas
GL._mazmorras = function() return CargarDatos() end

-- 6.8: la Biblioteca usa los mismos datos y abre una mazmorra aquí, desplegada.
GL.DatosMazmorras = CargarLista
GL.AbrirMazmorra = function(nombre, jefe, npc)
  if type(GuiaAventureroDB)=="table" then GuiaAventureroDB.pestanaMaz="mazmorras"; GuiaAventureroDB.mazTodas=true end
  AsegurarDatos()
  for i = 1, #DATOS do
    if DATOS[i].n == nombre or DATOS[i].clave == nombre then
      local m = DATOS[i]
      abierta = i; jefeAbierto = nil; px = math.max(0, i - 2) * ALTO_FILA
      if jefe then
        for k, j in ipairs(Jefes(m)) do
          if (npc and j.npc == npc) or j.n == jefe or j.nombreOriginal977 == jefe or j.ing == jefe then jefeAbierto = k; break end
        end
        elegidaEn[m.clave or m.n] = "jefes"
      end
      if GL.AbrirModo then GL.AbrirModo("mazmorras") end
      return true
    end
  end
  return false
end

------------------------------------------------------------------------
-- 8.7: aviso de mazmorra en la pestaña Guía. Al llegar al nivel de una mazmorra de tu facción (de su mínimo a 3 niveles
-- más) sale una tarjeta: Llevarme pone la flecha en la entrada como un desvío (no pierdes el paso), Ver abre su ficha y
-- No la quita para siempre. Una a la vez (la de mínimo más alto). No sale con el estilo Rápida ni con los avisos quitados.
------------------------------------------------------------------------
local tarjeta = nil
local function MazmorraANivel()
  local db = GuiaAventureroDB or {}
  if db.avisos == false or db.estiloRuta == "rapida" then return nil end
  AsegurarDatos()
  local nivel, mejor = NivelJugador(), nil
  if not nivel then return nil end
  for _, m in ipairs(DATOS) do
    -- sin misiones de tu facción (Salón de los Feudales o Mazmorras de Ventormenta para la Horda) no se avisa
    if m.e and #(m.misiones or {}) > 0 and nivel >= m.min and nivel <= m.min + 3 and not (db.mazNo and db.mazNo[m.n]) then
      if not mejor or m.min > mejor.min then mejor = m end
    end
  end
  return mejor
end
GL._mazmorraANivel = MazmorraANivel   -- para las pruebas

local function CrearTarjeta(panel)
  tarjeta = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
  if GL.Caja then GL.Caja(tarjeta, { 0.64, 0.21, 0.93, 0.07 }, { 0.64, 0.21, 0.93, 0.35 }) end
  local raya = tarjeta:CreateTexture(nil, "ARTWORK")
  raya:SetWidth(3)
  raya:SetPoint("TOPLEFT", tarjeta, "TOPLEFT", 0, 0)
  raya:SetPoint("BOTTOMLEFT", tarjeta, "BOTTOMLEFT", 0, 0)
  raya:SetColorTexture(0.64, 0.21, 0.93, 1)
  tarjeta.titulo = GL.Texto(tarjeta, "GameFontNormalSmall")
  tarjeta.titulo:SetPoint("TOPLEFT", tarjeta, "TOPLEFT", 10, -6)
  tarjeta.niveles = GL.Texto(tarjeta, "GameFontHighlightSmall")
  tarjeta.niveles:SetPoint("TOPRIGHT", tarjeta, "TOPRIGHT", -8, -6)
  tarjeta.texto = GL.Texto(tarjeta, "GameFontHighlightSmall")
  tarjeta.texto:SetPoint("TOPLEFT", tarjeta, "TOPLEFT", 10, -21)
  tarjeta.texto:SetPoint("RIGHT", tarjeta, "RIGHT", -8, 0)
  if tarjeta.texto.SetMaxLines then tarjeta.texto:SetMaxLines(2) end   -- 8.9.5: dos líneas en vez de cortar
  tarjeta.det = GL.Texto(tarjeta, "GameFontHighlightSmall")
  tarjeta.det:SetPoint("TOPLEFT", tarjeta.texto, "BOTTOMLEFT", 0, -2)
  tarjeta.det:SetPoint("RIGHT", tarjeta, "RIGHT", -8, 0)
  if tarjeta.det.SetMaxLines then tarjeta.det:SetMaxLines(2) end
  tarjeta.no = GL.CrearBoton(tarjeta, L"No", function()
    local m = tarjeta.m
    if not m then return end
    GuiaAventureroDB.mazNo = GuiaAventureroDB.mazNo or {}
    GuiaAventureroDB.mazNo[m.n] = true
    if GL.Refrescar then GL.Refrescar() end
  end, nil, 18)
  tarjeta.no:SetWidth(40)
  tarjeta.no:SetPoint("BOTTOMRIGHT", tarjeta, "BOTTOMRIGHT", -8, 6)
  tarjeta.ver = GL.CrearBoton(tarjeta, L"Ver", function()
    if tarjeta.m then GL.AbrirMazmorra(tarjeta.m.n) end
  end, nil, 18)
  tarjeta.ver:SetWidth(44)
  tarjeta.ver:SetPoint("RIGHT", tarjeta.no, "LEFT", -4, 0)
  tarjeta.llevar = GL.CrearBoton(tarjeta, L"Llevarme", function()
    local d = tarjeta.m and Destino(tarjeta.m)
    if d and GL.SeguirDesvio then GL.SeguirDesvio(d) end
  end, nil, 18, "accion")
  tarjeta.llevar:SetWidth(76)
  tarjeta.llevar:SetPoint("RIGHT", tarjeta.ver, "LEFT", -4, 0)
  if GL.BotonIcono then   -- 8.9.5: botones con icono
    GL.BotonIcono(tarjeta.no, "no", L"No", L"No me la vuelvas a enseñar.")
    GL.BotonIcono(tarjeta.ver, "ver", L"Ver", L"Abre la ficha de la mazmorra.")
    GL.BotonIcono(tarjeta.llevar, "llevar", L"Llevarme", L"La flecha te lleva a la entrada.")
  end
end

local function TarjetaMazmorra(panel, y, ancho)
  if tarjeta then tarjeta:Hide() end
  local m = MazmorraANivel()
  if not m then return 0 end
  if not tarjeta then CrearTarjeta(panel) end
  tarjeta.m = m
  tarjeta.titulo:SetText(L"|cffc88cffMAZMORRA A TU NIVEL|r")
  tarjeta.niveles:SetText(C.GRIS .. m.min .. "-" .. m.max .. C.FIN)
  local lugar = m.z:match("%((.-)%)") or m.z
  local dist = ""
  if GL.Vector then
    local ok, este, _, d = pcall(GL.Vector, Destino(m))
    if ok and este and type(d) == "number" then dist = L", a " .. math.floor(d * 0.9144 + 0.5) .. " m" end
  end
  tarjeta.texto:SetText(C.AMARILLO .. m.n .. C.FIN .. C.GRIS .. " · " .. lugar .. dist .. C.FIN)
  local coger, diario = 0, 0
  for _, q in ipairs(m.misiones or {}) do
    if q.q then
      if GL.MisionEnDiario and GL.MisionEnDiario(q.q) then diario = diario + 1
      elseif not (GL.MisionCompletada and GL.MisionCompletada(q.q)) then coger = coger + 1 end
    end
  end
  local mis = (coger + diario == 0) and L"sin misiones conocidas" or (L"misiones: " .. coger .. L" para coger" .. (diario > 0 and (", " .. diario .. L" en el diario") or ""))
  tarjeta.det:SetText(C.GRIS .. mis .. L" · mejor en grupo de 5" .. C.FIN)
  local anchoT = math.max(80, (ancho or 360) - 18)
  tarjeta.texto:SetWidth(anchoT); tarjeta.det:SetWidth(anchoT)
  local hT = tonumber(tarjeta.texto.GetStringHeight and tarjeta.texto:GetStringHeight()) or 12
  local hD = tonumber(tarjeta.det.GetStringHeight and tarjeta.det:GetStringHeight()) or 12
  local alto = math.max(74, math.floor(21 + hT + 2 + hD + 6 + 18 + 8))
  tarjeta:ClearAllPoints()
  tarjeta:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  tarjeta:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  tarjeta:SetHeight(alto)
  tarjeta:Show()
  return alto
end
-- 9.4.2: la pestaña Guía solo enseña la ruta, sus misiones y las opcionales; esta tarjeta ya no sale ahí
-- table.insert(GL.tarjetasGuia, 1, TarjetaMazmorra)

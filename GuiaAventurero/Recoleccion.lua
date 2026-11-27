-- Recoleccion.lua (9.1): rutas de recolección por zona para Minería, Herboristería y Desuello según tu nivel
-- de la profesión. Solo sale si tienes alguna de las tres, y solo la de las que tienes (si tienes Minería,
-- solo la de Minería). Va en una tarjeta de la pestaña Profesiones: zona recomendada para tu tramo (de tu
-- facción o en disputa), lo que sale allí y un botón para seguir la vuelta con la flecha; en el mapa se ve
-- el circuito. Al llegar a cada parada, la flecha pasa sola a la siguiente (la vuelta no se acaba).
-- Los circuitos recorren las partes de la zona con más filones, hierbas o bestias de tu tramo. 9.2: cada parada
-- comprobada con los puntos de filones y hierbas de Questie (Forever); las que no tenían nada cerca se movieron
-- al sitio con más cerca. Por comprobar en el juego.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local LLEGADA = 30   -- yardas para dar por alcanzada una parada

local function DB() return GuiaAventureroDB or {} end
local function Entero(n)
  if issecretvalue and issecretvalue(n) then return nil end
  if type(n)=="number" and n>=0 and n<math.huge and n%1==0 then return n end
end
local function Indice(v,n)
  return ((Entero(v) or 1)-1)%n+1
end

-- Circuitos por zona (uiMapID): puntos x, y del mapa de la zona (0-100), en orden de vuelta
local CIRCUITO = {
  [1426] = { "Dun Morogh", { { 40, 38 }, { 46, 50 }, { 52, 58 }, { 60, 55 }, { 68, 57 }, { 75, 55 }, { 68, 54 }, { 56, 40 } } },
  [1429] = { "Bosque de Elwynn", { { 38, 80 }, { 44, 72 }, { 52, 66 }, { 61, 53 }, { 70, 62 }, { 80, 70 }, { 84, 79 }, { 62, 76 } } },
  [1438] = { "Teldrassil", { { 40, 30 }, { 50, 35 }, { 65, 57 }, { 60, 60 }, { 52, 70 }, { 42, 62 }, { 36, 48 } } },
  [1411] = { "Durotar", { { 52, 23 }, { 58, 30 }, { 53, 40 }, { 43, 46 }, { 40, 56 }, { 46, 70 }, { 55, 74 }, { 58, 58 } } },
  [1412] = { "Mulgore", { { 31, 63 }, { 36, 52 }, { 45, 40 }, { 53, 22 }, { 62, 40 }, { 60, 62 }, { 48, 72 } } },
  [1420] = { "Claros de Tirisfal", { { 41, 47 }, { 48, 40 }, { 55, 49 }, { 63, 47 }, { 70, 52 }, { 64, 60 }, { 52, 60 } } },
  [1436] = { "Páramos de Poniente", { { 36, 30 }, { 45, 24 }, { 56, 30 }, { 60, 45 }, { 55, 62 }, { 45, 72 }, { 36, 60 }, { 33, 45 } } },
  [1432] = { "Loch Modan", { { 28, 20 }, { 36, 45 }, { 48, 30 }, { 62, 20 }, { 70, 40 }, { 73, 62 }, { 60, 70 }, { 38, 72 } } },
  [1439] = { "Costa Oscura", { { 47, 25 }, { 44, 35 }, { 42, 47 }, { 40, 60 }, { 43, 72 }, { 37, 78 } } },
  [1413] = { "Los Baldíos", { { 41, 25 }, { 46, 40 }, { 40, 50 }, { 48, 58 }, { 44, 72 }, { 52, 78 }, { 59, 48 }, { 56, 40 } } },
  [1421] = { "Bosque de Argénteos", { { 40, 20 }, { 48, 30 }, { 55, 40 }, { 52, 55 }, { 45, 68 }, { 50, 52 }, { 46, 31 } } },
  [1433] = { "Montañas Crestagrana", { { 18, 30 }, { 30, 25 }, { 45, 30 }, { 55, 40 }, { 65, 50 }, { 75, 60 }, { 60, 72 }, { 38, 65 } } },
  [1437] = { "Los Humedales", { { 20, 40 }, { 30, 30 }, { 45, 25 }, { 55, 35 }, { 60, 50 }, { 52, 65 }, { 49, 64 }, { 28, 58 } } },
  [1442] = { "Sierra Espolón", { { 36, 25 }, { 40, 40 }, { 55, 48 }, { 66, 60 }, { 58, 72 }, { 33, 65 } } },
  [1424] = { "Laderas de Trabalomas", { { 30, 40 }, { 40, 35 }, { 55, 30 }, { 65, 40 }, { 70, 55 }, { 55, 60 }, { 42, 55 } } },
  [1440] = { "Vallefresno", { { 20, 35 }, { 30, 45 }, { 40, 55 }, { 50, 65 }, { 62, 55 }, { 72, 60 }, { 80, 50 }, { 60, 40 }, { 40, 35 } } },
  [1417] = { "Tierras Altas de Arathi", { { 25, 30 }, { 35, 40 }, { 45, 55 }, { 55, 65 }, { 68, 70 }, { 78, 48 }, { 60, 30 }, { 40, 25 } } },
  [1443] = { "Desolace", { { 35, 23 }, { 45, 20 }, { 55, 30 }, { 65, 25 }, { 75, 45 }, { 60, 60 }, { 45, 75 }, { 32, 60 } } },
  [1441] = { "Las Mil Agujas", { { 15, 15 }, { 25, 35 }, { 40, 40 }, { 55, 50 }, { 70, 60 }, { 85, 75 }, { 65, 85 } } },
  [1434] = { "Vega de Tuercespina", { { 30, 15 }, { 40, 20 }, { 45, 30 }, { 35, 40 }, { 30, 50 }, { 40, 60 }, { 35, 75 }, { 45, 85 } } },
  [1435] = { "Pantano de las Penas", { { 15, 40 }, { 25, 50 }, { 40, 45 }, { 55, 40 }, { 70, 50 }, { 80, 40 }, { 60, 60 }, { 40, 60 } } },
  [1445] = { "Marjal Revolcafango", { { 35, 20 }, { 45, 30 }, { 55, 45 }, { 50, 60 }, { 40, 75 }, { 39, 49 }, { 41, 46 } } },
  [1418] = { "Tierras Inhóspitas", { { 10, 40 }, { 19, 39 }, { 51, 17 }, { 55, 35 }, { 65, 50 }, { 55, 70 }, { 35, 75 }, { 20, 60 } } },
  [1425] = { "Tierras del Interior", { { 27, 59 }, { 35, 35 }, { 50, 30 }, { 65, 35 }, { 75, 55 }, { 60, 70 }, { 40, 65 } } },
  [1446] = { "Tanaris", { { 38, 25 }, { 45, 40 }, { 55, 45 }, { 62, 62 }, { 50, 70 }, { 38, 60 } } },
  [1427] = { "La Garganta de Fuego", { { 25, 35 }, { 40, 30 }, { 55, 40 }, { 65, 55 }, { 50, 65 }, { 35, 55 } } },
  [1444] = { "Feralas", { { 40, 15 }, { 50, 25 }, { 55, 40 }, { 65, 50 }, { 70, 65 }, { 60, 75 }, { 45, 60 }, { 40, 40 } } },
  [1448] = { "Frondavil", { { 45, 85 }, { 40, 70 }, { 45, 55 }, { 50, 40 }, { 55, 25 }, { 62, 15 }, { 53, 21 }, { 39, 63 } } },
  [1449] = { "Cráter de Un'Goro", { { 30, 25 }, { 50, 15 }, { 70, 25 }, { 78, 50 }, { 65, 78 }, { 45, 82 }, { 25, 70 }, { 20, 45 } } },
  [1452] = { "Cuna del Invierno", { { 55, 30 }, { 62, 45 }, { 65, 60 }, { 60, 72 }, { 50, 55 }, { 48, 40 } } },
  [1422] = { "Tierras de la Peste del Oeste", { { 35, 70 }, { 45, 60 }, { 55, 50 }, { 65, 40 }, { 60, 40 }, { 45, 30 }, { 40, 50 } } },
  [1423] = { "Tierras de la Peste del Este", { { 20, 30 }, { 35, 25 }, { 50, 30 }, { 70, 40 }, { 75, 60 }, { 60, 75 }, { 40, 70 }, { 32, 68 } } },
  [1428] = { "Las Estepas Ardientes", { { 20, 35 }, { 35, 40 }, { 50, 35 }, { 65, 40 }, { 80, 50 }, { 70, 60 }, { 50, 60 }, { 30, 55 } } },
}
GL.CIRCUITOS_RECOLECCION = CIRCUITO

-- Profesiones: tramos de nivel con lo que sale y las zonas (A Alianza, H Horda, nada: las dos)
local PROFESIONES = {
  { id = "mineria", nombre = "Minería", skill = 186, icono = "Interface\\Icons\\Trade_Mining", color = { 0.85, 0.65, 0.35 }, tramos = {
    { d = 1, h = 65, que = "Filón de cobre", zonas = { { 1426, "A" }, { 1429, "A" }, { 1439, "A" }, { 1411, "H" }, { 1412, "H" }, { 1420, "H" } } },
    { d = 65, h = 125, que = "Filón de estaño (y algo de plata)", zonas = { { 1432, "A" }, { 1433 }, { 1413, "H" }, { 1442 } } },
    { d = 125, h = 175, que = "Depósito de hierro, filones de plata y oro", zonas = { { 1417 }, { 1443 }, { 1441 } } },
    { d = 175, h = 245, que = "Depósito de mitril (y veraplata)", zonas = { { 1418 }, { 1425 }, { 1446 }, { 1427 } } },
    { d = 245, h = 275, que = "Filones pequeños de torio", zonas = { { 1449 }, { 1428 }, { 1452 }, { 1423 } } },
    { d = 275, h = 301, que = "Vetas de torio (pequeñas y ricas)", zonas = { { 1449 }, { 1428 }, { 1452 }, { 1423 } } },
  } },
  { id = "herboristeria", nombre = "Herboristería", skill = 182, icono = "Interface\\Icons\\Trade_Herbalism", color = { 0.35, 0.85, 0.40 }, tramos = {
    { d = 1, h = 15, que = "Flor de paz, Hojaplata", zonas = { { 1429, "A" }, { 1426, "A" }, { 1438, "A" }, { 1411, "H" }, { 1412, "H" }, { 1420, "H" } } },
    { d = 15, h = 50, que = "Flor de paz, Hojaplata, Raíz de tierra", zonas = { { 1429, "A" }, { 1426, "A" }, { 1438, "A" }, { 1411, "H" }, { 1412, "H" }, { 1420, "H" } } },
    { d = 50, h = 70, que = "Marregal, Raíz de tierra", zonas = { { 1436, "A" }, { 1432, "A" }, { 1439, "A" }, { 1413, "H" }, { 1421, "H" } } },
    { d = 70, h = 100, que = "Marregal, Brezospina", zonas = { { 1436, "A" }, { 1432, "A" }, { 1439, "A" }, { 1413, "H" }, { 1421, "H" } } },
    { d = 100, h = 115, que = "Hierba cardenal, Brezospina", zonas = { { 1433 }, { 1437, "A" }, { 1442 }, { 1424 }, { 1440 } } },
    { d = 115, h = 125, que = "Hierba cardenal, Acérita salvaje", zonas = { { 1433 }, { 1437, "A" }, { 1442 }, { 1424 }, { 1440 } } },
    { d = 125, h = 150, que = "Acérita salvaje, Sangrerregia", zonas = { { 1433 }, { 1437, "A" }, { 1442 }, { 1424 }, { 1440 } } },
    { d = 150, h = 170, que = "Sangrerregia, Vidarraíz", zonas = { { 1417 }, { 1434 }, { 1445 } } },
    { d = 170, h = 185, que = "Vidarraíz, Espina de oro", zonas = { { 1417 }, { 1434 }, { 1445 } } },
    { d = 185, h = 205, que = "Espina de oro, Mostacho de Khadgar", zonas = { { 1417 }, { 1434 }, { 1445 } } },
    { d = 205, h = 210, que = "Flor de fuego, Mostacho de Khadgar", zonas = { { 1446 }, { 1427 } } },
    { d = 210, h = 230, que = "Flor de fuego, Loto morado", zonas = { { 1446 }, { 1427 } } },
    { d = 230, h = 250, que = "Solea, Loto morado (Champiñón fantasma desde 245, en cuevas)", zonas = { { 1425 }, { 1444 } } },
    { d = 250, h = 260, que = "Solea, Gromsanguina", zonas = { { 1448 } } },
    { d = 260, h = 270, que = "Gromsanguina, Sansam dorado", zonas = { { 1448 } } },
    { d = 270, h = 280, que = "Sansam dorado, Hojasueño", zonas = { { 1448 }, { 1422 } } },
    { d = 280, h = 285, que = "Hojasueño, Salviargenta de montaña", zonas = { { 1448 }, { 1422 } } },
    { d = 285, h = 290, que = "Hojasueño, Flor de peste", zonas = { { 1448 }, { 1422 } } },
    { d = 290, h = 301, que = "Hojasueño, Flor de peste, Setelo (en Cuna del Invierno)", zonas = { { 1448 }, { 1422 }, { 1452 } } },
  } },
  { id = "desuello", nombre = "Desuello", skill = 393, icono = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", color = { 0.90, 0.55, 0.30 }, tramos = {
    { d = 1, h = 75, que = "Bestias desollables de las zonas iniciales; pueden dar habilidad hasta 75", zonas = { { 1429, "A" }, { 1426, "A" }, { 1438, "A" }, { 1411, "H" }, { 1412, "H" }, { 1420, "H" } } },
    { d = 75, h = 130, que = "Jabalíes y osos de Loch Modan o raptores y zhebras de Los Baldíos; selecciona criaturas según tu habilidad", zonas = { { 1432, "A" }, { 1413, "H" } } },
    { d = 130, h = 150, que = "Raptores de Los Humedales o bestias de Los Baldíos; desde 135 puedes desollar criaturas de nivel 27", zonas = { { 1437, "A" }, { 1413, "H" } } },
    { d = 150, h = 160, que = "Osos y leones cerca de la cueva de yetis de Trabalomas; yetis de nivel 30 desde 150", zonas = { { 1424 } } },
    { d = 160, h = 225, que = "Yetis de nivel 30-32 de Trabalomas", zonas = { { 1424 } } },
    { d = 225, h = 230, que = "Yetis de Feralas de nivel 43-45; evita los de nivel 46 hasta 230", zonas = { { 1444 } } },
    { d = 230, h = 280, que = "Yetis de Feralas de nivel 43-46", zonas = { { 1444 } } },
    { d = 280, h = 301, que = "Dinosaurios del oeste de Un'Goro de nivel 50-55", zonas = { { 1449 } } },
  } },
}
GL.PROFESIONES_RECOLECCION = PROFESIONES

-- Forever: nivel máximo estándar según habilidad efectiva, sin excepciones especiales.
function GL.NivelMaxDesuello977(habilidad)
  local n=Entero(habilidad) or 0
  if n < 1 then return 0 end
  if n < 100 then return 10 + math.floor(n/10) end
  return math.floor(n/5)
end


-- Materiales directos de desuello; no presupone botín ni zona concreta.
local CUEROS977 = {[2934]=true,[2318]=true,[2319]=true,[4234]=true,[4304]=true,[8170]=true,[783]=true,[4232]=true,[4235]=true,[8169]=true,[8171]=true}
function GL.NecesidadesDesuello977(profesiones,obtenerNivel,contar)
  local lista={}
  obtenerNivel=obtenerNivel or GL.NivelProfesion
  if not obtenerNivel or not GL.ComprasProfesion975 then return lista end
  for _,p in ipairs(profesiones or {}) do
    if p.skill==165 then
      local n=obtenerNivel(p)
      if type(n)=="number" and n>0 and n<300 then
        for _,m in ipairs(GL.ComprasProfesion975(p,n,contar or GL.BolsasProfesion975 or function() return nil end)) do
          if CUEROS977[m.id] and m.falta>0 then lista[#lista+1]=m end
        end
      end
      break
    end
  end
  table.sort(lista,function(a,b) if a.falta==b.falta then return a.id<b.id end return a.falta>b.falta end)
  return lista
end

-- IDs de objetos (no IDs de nodos). Umbrales de Forever; los secundarios no son garantizados.
local HIERBAS977 = {
  [2447]=1,[765]=1,[2449]=15,[785]=50,[2450]=70,[2452]=50,[3820]=85,
  [2453]=100,[3355]=115,[3369]=120,[3356]=125,[3357]=150,[3818]=160,
  [3821]=170,[3358]=185,[3819]=195,[4625]=205,[8831]=210,[8153]=210,
  [8836]=220,[8838]=230,[8839]=235,[8845]=245,[8846]=250,[13464]=260,
  [13463]=270,[13465]=280,[13466]=285,[13467]=290,[13468]=300,
}
-- Estimación conjunta de los planes activos; no cambia recetas, inventario ni compras.
function GL.NecesidadesHierbas977(profesiones,nivel,obtenerNivel,contar)
  local total,lista={},{}
  if not GL.ComprasProfesion975 then return lista end
  obtenerNivel=obtenerNivel or GL.NivelProfesion
  if not obtenerNivel then return lista end
  contar=contar or GL.BolsasProfesion975 or function() return nil end
  local vistas={}
  for _,p in ipairs(profesiones or {}) do
    if (p.skill==171 or p.skill==129) and not vistas[p.skill] then
      vistas[p.skill]=true
      local n=obtenerNivel(p)
      if type(n)=="number" and n>0 and n<300 then
        local mats=GL.ComprasProfesion975(p,n,function() return 0 end)
        for _,m in ipairs(mats) do
          if HIERBAS977[m.id] and m.falta>0 then
            local t=total[m.id] or {id=m.id,nombre=m.nombre,cantidad=0,minimo=HIERBAS977[m.id]}
            t.cantidad=t.cantidad+m.falta; total[m.id]=t
          end
        end
      end
    end
  end
  for id,t in pairs(total) do
    local ok,n=pcall(contar,id)
    t.desconocido=not ok or (issecretvalue and issecretvalue(n)) or type(n)~="number" or n~=n or n<0 or n>=math.huge or n%1~=0
    t.falta=math.max(0,t.cantidad-(t.desconocido and 0 or n))
    if t.falta>0 and t.minimo<=(tonumber(nivel) or 0) then lista[#lista+1]=t end
  end
  table.sort(lista,function(a,b) if a.falta==b.falta then return a.id<b.id end return a.falta>b.falta end)
  return lista
end


-- Instructores Forever: Icy Veins, guia de herboristeria, 24-11-2026.
local instructoresHierbas977 = {
  {lado="A", m=1429, x=52.4, y=43.8, nombre="Nancy Songflower", max=75},
  {lado="A", m=1426, x=28.8, y=66.6, nombre="Emrys Flintbeard", max=75},
  {lado="A", m=1438, x=59.8, y=41.4, nombre="Eleyna Duskbreeze", max=75},
  {lado="A", m=1453, x=44.8, y=77, nombre="Tannysa", max=300},
  {lado="A", m=1455, x=55.6, y=58.4, nombre="Reyna Stonebranch", max=300},
  {lado="A", m=1457, x=48, y=68.4, nombre="Firodren Mooncaller", max=300},
  {lado="A", m=1429, x=39.8, y=48.4, nombre="Herbalist Pomeroy", max=300},
  {lado="A", m=1438, x=57.6, y=60.6, nombre="Malorne Bladeleaf", max=300},
  {lado="A", m=1432, x=36.6, y=48.4, nombre="Kali Healtouch", max=300},
  {lado="A", m=1433, x=21.8, y=45.8, nombre="Alma Jainrose", max=300},
  {lado="A", m=1437, x=8, y=55.8, nombre="Telurinon Moonshadow", max=300},
  {lado="A", m=1445, x=64, y=47.6, nombre="Brant Jasperbloom", max=300},
  {lado="H", m=1411, x=42.6, y=67.4, nombre="Zor'la", max=75},
  {lado="H", m=1412, x=44.2, y=77.8, nombre="Garan Sunstrider", max=75},
  {lado="H", m=1420, x=32.4, y=65.2, nombre="Florence Nightshade", max=75},
  {lado="H", m=1454, x=55.6, y=39.6, nombre="Jandi", max=300},
  {lado="H", m=1456, x=49.8, y=39.8, nombre="Komin Winterhoof", max=300},
  {lado="H", m=1458, x=54.6, y=50.4, nombre="Martha Alliestar", max=300},
  {lado="H", m=1411, x=55.4, y=75, nombre="Mishiki", max=300},
  {lado="H", m=1420, x=59.8, y=52, nombre="Faruza", max=300},
  {lado="H", m=1424, x=61.6, y=19.6, nombre="Aranae Venomblood", max=300},
  {lado="H", m=1434, x=32.2, y=27.6, nombre="Angrun", max=300},
  {lado="H", m=1444, x=76, y=43.4, nombre="Ruw", max=300},
  {lado="N", m=2521, x=43, y=43.6, nombre="Halassa Fernbreeze", max=300},
  {lado="N", m=2521, x=57.8, y=75.4, nombre="Syriel Nightrain", max=300},
  {lado="N", m=1434, x=27.6, y=77.8, nombre="Flora Silverwind", max=300},
  {lado="N", m=1450, x=45.6, y=46.8, nombre="Malvor", max=300},
}
function GL.InstructorHierbas977(lado,mapa)
  local alternativa
  for _,v in ipairs(instructoresHierbas977) do
    if v.max==300 and (v.lado==lado or v.lado=="N") then
      if v.m==mapa then return v end
      alternativa=alternativa or v
    end
  end
  return alternativa
end


-- Icy Veins Forever, instructores de todos los rangos, 24-11-2026.
local instructoresDesuello977 = {
  {lado="A",m=1455,x=39.6,y=32.6,nombre="Balthus Stoneflayer"},
  {lado="A",m=1457,x=64.2,y=21.8,nombre="Eladriel"},
  {lado="A",m=1453,x=67.8,y=49,nombre="Maris Granger"},
  {lado="A",m=1429,x=46.2,y=62.2,nombre="Helene Peltskinner"},
  {lado="A",m=1438,x=42,y=50,nombre="Radnaal Maneweaver"},
  {lado="A",m=1433,x=88.8,y=71,nombre="Wilma Ranthal"},
  {lado="A",m=1440,x=50,y=67.2,nombre="Jayla"},
  {lado="H",m=1454,x=63.2,y=45.2,nombre="Thuwd"},
  {lado="H",m=1456,x=44.6,y=43,nombre="Mooranta"},
  {lado="H",m=1458,x=70.4,y=59.2,nombre="Killian Hagey"},
  {lado="H",m=1412,x=45.6,y=57.8,nombre="Yonn Deepcut"},
  {lado="H",m=1420,x=65.6,y=60,nombre="Rand Rhobart"},
  {lado="H",m=1413,x=45,y=59,nombre="Dranh"},
  {lado="H",m=1443,x=23.2,y=69.8,nombre="Malux"},
  {lado="H",m=1444,x=74.6,y=42.8,nombre="Kulleg Stonehorn"},
  {lado="N",m=2521,x=43.2,y=43.4,nombre="Mendalass Tattermend"},
  {lado="N",m=2521,x=59.6,y=76,nombre="Ishlee Breezewhisper"},

}
function GL.InstructorDesuello977(lado,mapa)
  local alternativa
  for _,v in ipairs(instructoresDesuello977) do
    if v.lado==lado or v.lado=="N" then
      if v.m==mapa then return v end
      alternativa=alternativa or v
    end
  end
  return alternativa
end

local function Lado()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return f == "Horde" and "H" or f == "Alliance" and "A" or nil
end

-- Las de recolección que tienes: { prof, nivel, tramo, zonas = { { m, nombre, puntos } } }
local function Recoleccion(p,lado)
  if not GL.NivelProfesion then return nil end
  local ok,nivel,tope=pcall(GL.NivelProfesion,p)
  if not ok or not Entero(nivel) or nivel<1 then return nil end
  local tramo
  local base=math.min(nivel,300)
  for _,t in ipairs(p.tramos) do if base>=t.d and base<t.h then tramo=t;break end end
  if not tramo then return nil end
  local zonas={}
  for _,z in ipairs(tramo.zonas) do
    local c=CIRCUITO[z[1]]
    if c and (not z[2] or z[2]==lado) then zonas[#zonas+1]={m=z[1],nombre=L(c[1]),nombreCliente=(GL.LC and GL.LC(c[1])) or c[1],puntos=c[2]} end
  end
  if #zonas==0 then return nil end
  return {prof=p,nivel=nivel,tope=Entero(tope),tramo=tramo,zonas=zonas}
end
local function MisRecolecciones()
  local res,lado={},Lado()
  for _,p in ipairs(PROFESIONES) do
    local rec=Recoleccion(p,lado)
    if rec then res[#res+1]=rec end
  end
  return res
end
GL.MisRecolecciones = MisRecolecciones

------------------------------------------------------------------------
-- Seguir la vuelta con la flecha
------------------------------------------------------------------------
local sigo   -- { prof, zona, i, d, clavePaso }
local function ClavePaso() local db = DB(); return tostring(db.seccion) .. ":" .. tostring(db.paso) end
local function Parada(i)
  local z = sigo.zona
  local pt = z.puntos[i]
  return { m = z.m, z = z.nombreCliente or z.nombre, x = pt[1], y = pt[2], n = L(sigo.prof.nombre) .. L": parada " .. i .. L" de " .. #z.puntos .. " (" .. z.nombre .. ")" }
end

-- La más cercana de la vuelta para empezar por ella
local function MasCercana(z)
  local mejor, md = 1, nil
  for i, pt in ipairs(z.puntos) do
    local ok, _, _, dist = pcall(GL.Vector, { m = z.m, z = z.nombreCliente or z.nombre, x = pt[1], y = pt[2] })
    if ok and not (issecretvalue and issecretvalue(dist)) and type(dist) == "number" and dist>=0 and dist<math.huge and (not md or dist < md) then mejor, md = i, dist end
  end
  return mejor
end

local function Seguir(rec, zona)
  if DB().recoleccion==false or not (rec and zona and GL.SeguirDesvio) then return end
  local vigente=Recoleccion(rec.prof,Lado())
  if not vigente then return end
  local permitida
  for _,z in ipairs(vigente.zonas) do if z.m==zona.m then permitida=z;break end end
  if not permitida then return end
  zona=permitida
  sigo = { prof = rec.prof, zona = zona }
  sigo.i = MasCercana(zona)
  sigo.d = Parada(sigo.i)
  sigo.clavePaso = ClavePaso()
  DB().recoleccionSigo = rec.prof.id .. ":" .. zona.m
  if GL.SeguirDesvio then GL.SeguirDesvio(sigo.d) end
  if GL.Mensaje then GL.Mensaje(L"ruta de " .. L(rec.prof.nombre) .. L" en " .. zona.nombre .. L": la flecha te lleva por las " .. #zona.puntos .. L" paradas.") end
end

local function Parar()
  local anterior=sigo
  sigo = nil
  DB().recoleccionSigo = nil
  if anterior and GL.DestinoActual and GL.DestinoActual() == anterior.d and GL.SeguirDesvio then GL.SeguirDesvio(nil) end
  if GL.ActualizarPines then pcall(GL.ActualizarPines) end
end

GL.RutaRecoleccion = function()
  if not sigo then return nil end
  return { m = sigo.zona.m, puntos = sigo.zona.puntos, color = sigo.prof.color }
end

local function RevisarCircuito()
  if not sigo then return false end
  if DB().recoleccion==false then Parar();return false end
  local rec=Recoleccion(sigo.prof,Lado())
  if rec then
    for _,z in ipairs(rec.zonas) do if z.m==sigo.zona.m then return true end end
  end
  Parar();return false
end
local function Avanzar()
  if not sigo then return end
  if DB().recoleccion==false then Parar();return end
  local actual = GL.DestinoActual and GL.DestinoActual()
  if actual ~= sigo.d then
    -- No pisar otro desvío elegido manualmente, ni siquiera al cambiar de paso.
    if ClavePaso() ~= sigo.clavePaso and GL.DesvioActual and not GL.DesvioActual() and RevisarCircuito() then
      sigo.clavePaso = ClavePaso()
      if GL.SeguirDesvio then GL.SeguirDesvio(sigo.d) end
    else Parar() end
    return
  end
  local ok, _, _, dist, otraZona = pcall(GL.Vector, sigo.d)
  if ok and otraZona==false and not (issecretvalue and issecretvalue(dist)) and type(dist)=="number" and dist>=0 and dist<=LLEGADA then
    if not RevisarCircuito() then return end
    sigo.i = sigo.i % #sigo.zona.puntos + 1
    sigo.d = Parada(sigo.i)
    if GL.SeguirDesvio then GL.SeguirDesvio(sigo.d) end
  end
end

local reloj = 0
local ev = CreateFrame("Frame")
for _,e in ipairs({"SKILL_LINES_CHANGED","CHAT_MSG_SKILL","PLAYER_ENTERING_WORLD"}) do pcall(ev.RegisterEvent,ev,e) end
ev:SetScript("OnEvent",function() if sigo then pcall(RevisarCircuito) end end)
ev:SetScript("OnUpdate", function(_, dt)
  reloj = reloj + (dt or 0)
  if reloj < 0.5 then return end
  reloj = 0
  if sigo then pcall(Avanzar) end
end)

------------------------------------------------------------------------
-- Tarjeta de la pestaña Profesiones
------------------------------------------------------------------------
local t
local function Crear(panel)
  t = CreateFrame("Frame", nil, panel, PLANTILLA)
  t.icono = t:CreateTexture(nil, "ARTWORK")
  t.icono:SetSize(18, 18)
  t.icono:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -7)
  t.titulo = GL.Texto(t, "GameFontNormalSmall")
  t.titulo:SetPoint("TOPLEFT", t, "TOPLEFT", 32, -9)
  t.texto = GL.Texto(t, "GameFontHighlightSmall")
  t.texto:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -30)
  if t.texto.SetJustifyH then t.texto:SetJustifyH("LEFT") end
  t.otra = GL.CrearBoton(t, L"Otra", function()
    DB().recoleccionVer = (Entero(DB().recoleccionVer) or 1) + 1
    if GL.Refrescar then GL.Refrescar() end
  end, nil, 18)
  t.otra:SetWidth(86)
  t.otra:SetPoint("TOPRIGHT", t, "TOPRIGHT", -4, -4)
  if GL.Ayuda then GL.Ayuda(t.otra, L"Otra profesión", L"Tienes dos de recolección: cambia de una a otra.") end
  t.zona = GL.CrearBoton(t, L"Otra zona", function()
    DB().recoleccionZona = (Entero(DB().recoleccionZona) or 1) + 1
    if GL.Refrescar then GL.Refrescar() end
  end, nil, 20)
  t.zona:SetWidth(90)
  t.seguir = GL.CrearBoton(t, L"Seguir la vuelta", function()
    if t.rec and t.zonaSel then
      if sigo and sigo.prof == t.rec.prof and sigo.zona.m == t.zonaSel.m then Parar() else Seguir(t.rec, t.zonaSel) end
    end
    if GL.Refrescar then GL.Refrescar() end
  end, nil, 20, "accion")
  t.seguir:SetWidth(130)
end

function GL.TarjetaRecoleccion(panel, y, ancho)
  if t then t:Hide() end
  if DB().recoleccion == false then return 0 end
  local mias = MisRecolecciones()
  if #mias == 0 then return 0 end   -- sin Minería, Herboristería ni Desuello no sale nada
  local rec = mias[Indice(DB().recoleccionVer,#mias)]
  if #rec.zonas == 0 then return 0 end
  local zona = rec.zonas[Indice(DB().recoleccionZona,#rec.zonas)]
  if not t then Crear(panel) end
  t:SetParent(panel)
  t.rec, t.zonaSel = rec, zona
  local col = rec.prof.color
  GL.Caja(t, { col[1], col[2], col[3], 0.07 }, { col[1], col[2], col[3], 0.45 })
  if GL.PonerIcono then GL.PonerIcono(t.icono, rec.prof.icono) else t.icono:SetTexture(rec.prof.icono) end
  t.titulo:SetText(C.GRIS .. L"RUTA DE RECOLECCIÓN · " .. C.FIN .. C.BLANCO .. L(rec.prof.nombre) .. " " .. rec.nivel .. C.FIN)
  GL.Mostrar(t.otra, #mias > 1)
  if #mias > 1 then
    local otra = mias[Indice((Entero(DB().recoleccionVer) or 1)+1,#mias)]
    t.otra.texto:SetText(L(otra.prof.nombre))
  end
  local siguiendo = sigo and sigo.prof == rec.prof and sigo.zona.m == zona.m
  local txt = L"Tramo " .. rec.tramo.d .. "-" .. math.min(300, rec.tramo.h - 1) .. ": " .. C.AMARILLO .. L(rec.tramo.que) .. C.FIN .. ".\n" ..
    L"Zona: " .. C.AZUL .. zona.nombre .. C.FIN .. L" · vuelta de " .. #zona.puntos .. L" paradas" ..
    (#rec.zonas > 1 and (C.GRIS .. " (" .. #rec.zonas .. L" zonas para tu tramo)" .. C.FIN) or "") ..
    (siguiendo and ("\n" .. C.VERDE .. L"Siguiendo: parada " .. sigo.i .. L" de " .. #zona.puntos .. "." .. C.FIN) or "") ..
    "\n" .. C.GRIS .. L"Paradas orientativas: no se ha verificado la densidad de recursos ni la accesibilidad de cada punto." .. C.FIN
  if rec.tope and rec.tope<300 and rec.nivel>=rec.tope then
    txt=txt.."\n"..C.AMARILLO..L"Límite de profesión alcanzado: puedes recolectar materiales, pero no ganar más habilidad hasta desbloquear el siguiente rango."..C.FIN
  end
  if rec.prof.skill == 393 then
    txt=txt.."\n"..L"Nivel máximo orientativo de criatura: "..GL.NivelMaxDesuello977(rec.nivel)..". "..L"Comprueba el requisito del cadáver y lleva un cuchillo de desuello."
    txt=txt.."\n"..L"Paradas orientativas: no se ha verificado la densidad de bestias ni la accesibilidad de cada punto."
    txt=txt.."\n"..L"Desuella cadáveres aptos después de saquearlos por completo; el cuero depende de la criatura."
    txt=txt.."\n"..L"Bonificaciones de Desuello: Cuchillo de desollar afilado +3 equipado; encantamientos de guantes +5 o +10 (no acumulables entre sí)."
    txt=txt.."\n"..L"Conserva Cuero prístino, Pellejo prístino y Escama prístina: materiales escasos adicionales para fabricación; no tienen un botín garantizado."
    if rec.nivel>=300 then txt=txt.."\n"..L"Campamento: banco de trampero (300), contiene una trampa con una bestia desollable."
    elseif rec.nivel>=140 then txt=txt.."\n"..L"Campamento: guía de campo (140), permite rastrear bestias."
    elseif rec.nivel>=20 then txt=txt.."\n"..L"Campamento: silla (20), bonificación de golpe crítico." end
    if rec.nivel>=140 then txt=txt.."\n"..L"Los campamentos avanzados requieren planos; reutilización compartida de 60 min." end
    if rec.nivel>=250 then txt=txt.."\n"..L"Los materiales viles de nivel alto se incorporarán en próximas versiones cuando se confirmen sus requisitos." end
    if rec.nivel<300 then
      local mapa=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
      local inst=GL.InstructorDesuello977(Lado(),mapa or zona.m)
      if inst then
        local info=C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(inst.m)
        txt=txt.."\n"..L"Instructor de rangos: "..inst.nombre.." ("..(info and info.name or (L"mapa "..inst.m))..", "..inst.x..", "..inst.y..")"
      end
      txt=txt.."\n"..L"Rangos: Oficial desde 50, Experto desde 125, Artesano desde 200."
    end
    local faltan=GL.NecesidadesDesuello977(GL.RUTA and GL.RUTA.profesiones)
    if #faltan>0 then
      local partes={}
      for i=1,math.min(4,#faltan) do
        local m=faltan[i]
        partes[#partes+1]=((GL.NombreMaterialR11 and GL.NombreMaterialR11(m.id,m.nombre)) or L(m.nombre)).." ×"..m.falta..(m.tengo==nil and " (?)" or "")
      end
      txt=txt.."\n"..L"Cueros y pellejos pendientes para Peletería (estimación del plan activo; no necesariamente en esta zona): "..table.concat(partes,", ")
    end
  end
  if rec.prof.skill == 182 then
    txt=txt.."\n"..L"Activa Buscar hierbas y vuelve a activarlo después de morir."
    if rec.nivel < 70 then txt=txt.."\n"..L"Busca plantas de inicio en terreno abierto; Raíz de tierra cerca de laderas."
    elseif rec.nivel < 115 then txt=txt.."\n"..L"Desde 85, busca Alga estranguladora bajo el agua si puedes hacerlo con seguridad."
    elseif rec.nivel < 170 then txt=txt.."\n"..L"Desde 115, busca Acérita salvaje en laderas; Vidarraíz junto al agua desde 150."
    elseif rec.nivel < 205 then txt=txt.."\n"..L"Prioriza bordes de bosque y colinas de Arathi o Tuercespina."
    elseif rec.nivel < 230 then txt=txt.."\n"..L"Busca Flor de fuego en terreno seco y Loto morado cerca de ruinas desde 210."
    elseif rec.nivel < 250 then txt=txt.."\n"..L"En Tierras del Interior, busca Champiñón fantasma en cuevas desde 245."
    else txt=txt.."\n"..L"En Frondavil, recorre el camino principal y los claros cercanos." end

    if rec.nivel >= 300 then
      txt=txt.."\n"..L"Campamento: hibridador de semillas (300), permite combinar semillas."
    elseif rec.nivel >= 140 then
      txt=txt.."\n"..L"Campamento: invernadero (140), permite cultivar hierbas a partir de semillas."
    elseif rec.nivel >= 20 then
      txt=txt.."\n"..L"Campamento: vela de incienso (20), bonificación de intelecto."
    end
    if rec.nivel < 300 then
      local mapa=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
      local inst=GL.InstructorHierbas977(Lado(),mapa or zona.m)
      if inst then
        local info=C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(inst.m)
        txt=txt.."\n"..L"Instructor de rangos: "..inst.nombre.." ("..(info and info.name or (L"mapa "..inst.m))..", "..inst.x..", "..inst.y..")"
      end
      txt=txt.."\n"..L"Rangos: Oficial desde 50, Experto desde 125, Artesano desde 200."
    end
    if rec.nivel >= 140 then
      txt=txt.."\n"..L"Invernadero e hibridador requieren planos; reutilización compartida de campamento: 60 min."
    end
    if rec.nivel >= 140 then
      txt=txt.."\n"..L"El invernadero admite una semilla por colocación; espera unos 8 minutos para cosechar."
      txt=txt.."\n"..L"Plano del invernadero: Sombradiente (Excavación, Los Humedales)."
      txt=txt.."\n"..L"Semillas: comunes, poco comunes, inusuales y escasas (categorías orientativas)."
    end
    if rec.nivel >= 300 then
      txt=txt.."\n"..L"Plano del hibridador: Tendris Alabeo (Jardines de la Capital, La Masacre oeste)."
      txt=txt.."\n"..L"Combina semillas del mismo grado; puede fallar. Las semillas escasas no se pueden hibridar."
    end
    local faltan=GL.NecesidadesHierbas977(GL.RUTA and GL.RUTA.profesiones,rec.nivel)
    if #faltan>0 then
      local partes={}
      for i=1,math.min(4,#faltan) do
        local m=faltan[i]
        local nombre=(GL.NombreMaterialR11 and GL.NombreMaterialR11(m.id,m.nombre)) or L(m.nombre)
        partes[#partes+1]=nombre.." ×"..m.falta..(m.desconocido and " (?)" or "")
      end
      txt=txt.."\n"..L"Hierbas pendientes para Alquimia y Primeros auxilios (planes activos, estimación en bolsas; no necesariamente en esta zona): "..table.concat(partes,", ")
    end
  end
  local w = ancho - 20
  t.texto:SetWidth(w)
  t.texto:SetText(txt)
  local h = 30 + GL.Alto(t.texto, txt, 12, w) + 6
  t.seguir.texto:SetText(siguiendo and L"Dejar de seguir" or L"Seguir la vuelta")
  t.seguir:ClearAllPoints()
  t.seguir:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -h)
  t.zona:ClearAllPoints()
  t.zona:SetPoint("LEFT", t.seguir, "RIGHT", 6, 0)
  GL.Mostrar(t.zona, #rec.zonas > 1)
  h = h + 28
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  t:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  t:SetHeight(h)
  t:Show()
  return h
end

GL.comandos = GL.comandos or {}
GL.comandos["recoleccion"] = function(orden)
  if orden == "parar" then Parar(); if GL.Mensaje then GL.Mensaje(L"ya no sigues la ruta de recolección.") end return end
  local mias = MisRecolecciones()
  if #mias == 0 then if GL.Mensaje then GL.Mensaje(L"no tienes Minería, Herboristería ni Desuello.") end return end
  if GL.MostrarVentanaCompletaR10 then GL.MostrarVentanaCompletaR10() else
    if GL.frame then GL.frame:Show(); DB().oculto = false end
  end
  if GL.AbrirModo then GL.AbrirModo("oficios") end
end
GL.comandos["recolección"] = GL.comandos["recoleccion"]

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "recoleccion", "Profesiones: ruta de recolección",
  "Si tienes Minería, Herboristería o Desuello: zona para tu nivel de la profesión y una vuelta que sigue la flecha. Solo sale la de las que tienes.",
  function() return DB().recoleccion ~= false end, function(v) DB().recoleccion = v; if not v then Parar() end; if GL.Refrescar then GL.Refrescar() end end, pestana = "aspecto" })

GL._recoleccion = { Mias = MisRecolecciones, Seguir = Seguir, Parar = Parar, Avanzar = Avanzar, Sigo = function() return sigo end }

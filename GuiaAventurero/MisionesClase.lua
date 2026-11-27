-- MisionesClase.lua (9.4): pestaña Personaje › Clase. Las misiones de clase importantes como rutas cortas: forma
-- de oso, tótems, demonios y monturas del brujo, Destrero del paladín, Rhok'delar del cazador, actitudes del
-- guerrero, venenos del pícaro... Cada misión con Llevarme (a recogerla o, si ya la llevas, a entregarla).
-- Datos en Datos94.lua (QuestieDB). Arriba, tu especialización y el botón para cambiarla. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local BIT_RAZA = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local function Publico(v)
  if type(issecretvalue) ~= "function" then return true end
  local ok, secreto = pcall(issecretvalue, v)
  return ok and not secreto
end
local function Clase()
  if type(UnitClass) ~= "function" then return nil end
  local ok, _, clase = pcall(UnitClass, "player")
  if ok and Publico(clase) and type(clase) == "string" then return clase end
end
local function Lado()
  if type(UnitFactionGroup) ~= "function" then return nil end
  local ok, lado = pcall(UnitFactionGroup, "player")
  if not ok or not Publico(lado) then return nil end
  if lado == "Horde" then return "H" end
  if lado == "Alliance" then return "A" end
end
local function Nivel() return GL.NivelJugadorR14() or 0 end
local function ObjetivoListo(q)
  return GL.ConsultarMisionR14(type(C_QuestLog)=="table" and C_QuestLog.IsComplete, q)==true
end
local function Hecha(q) return GL.MisionCompletada and GL.MisionCompletada(q) or false end
local function Llevo(q) return GL.MisionEnDiario and GL.MisionEnDiario(q) or false end

local function DeMiRaza(razas)
  if not razas or razas == 0 then return true end
  local bit = BIT_RAZA[(GL.Raza and GL.Raza()) or ""]
  if not bit then return true end   -- Skyborne y otras razas nuevas: se enseñan todas las de su facción
  return math.floor(razas / bit) % 2 == 1
end

-- Guerreros: usa los destinos de la ruta activa, no una cadena genérica de la facción.
-- Fuentes: icy-veins.com/wow-forever/warrior-class-quests y questing.wiki/wow-forever/spells/71/.
local defensiva = {
  humano_guerrero = {1638,1639,1640,1665}, enano_gnomo_guerrero = {1679,1678},
  elfo_guerrero = {1684,1683}, nomuerto_guerrero = {1818,1819},
  orco_trol_guerrero = {1498}, tauren_guerrero = {1505,1498},
  skyborne_guerrero = {94003}, skyborne_a_guerrero = {94003},
}
local nombresActitud = {
  [1638]={"Instrucción de guerrero","A Warrior's Training"}, [1639]={"Bartleby, el borracho","Bartleby the Drunk"},
  [1640]={"Vence a Bartleby","Beat Bartleby"}, [1665]={"La jarra de Bartleby","Bartleby's Mug"},
  [1679]={"Muren Pico Tormenta","Muren Stormpike"}, [1678]={"Vejrek","Vejrek"},
  [1684]={"Elanaria","Elanaria"}, [1683]={"Vorlus Pezuñavil","Vorlus Vilehoof"},
  [1818]={"Habla con Dillinger","Speak with Dillinger"}, [1819]={"Ulag, el cuchillero","Ulag the Cleaver"},
  [1505]={"Uzzek, el veterano","Veteran Uzzek"}, [1498]={"Camino de defensa","Path of Defense"},
  [94003]={"El Baluarte Skybreaker","The Skybreaker Bulwark"},
  [1718]={"El isleño","The Islander"}, [1719]={"La Reyerta","The Affray"},
}
local function CadenasActitudes(R)
  if not R or R.clase ~= "WARRIOR" or not defensiva[R.id] or not R.secciones then return {} end
  local raza = GL.Raza and GL.Raza()
  if raza then
    local coincide = false
    for _, r in ipairs(R.razas or {}) do if r == raza then coincide = true end end
    if not coincide then return {} end
    if raza == "Skyborne" and ((R.id == "skyborne_a_guerrero") ~= (Lado() == "A")) then return {} end
  end
  local destinos = {}
  for _, sec in ipairs(R.secciones) do
    for _, paso in ipairs(sec.pasos or {}) do
      for _, w in ipairs(paso.wp or {}) do
        if nombresActitud[w.q] and (w.a == "A" or w.a == "T") then
          local d = destinos[w.q] or {}; destinos[w.q] = d
          if not d[w.a] then d[w.a] = w end
        end
      end
    end
  end
  local function cadena(ids, nivel, titulo, nota, hechizos)
    local c = { clase="WARRIOR", nivel=nivel, titulo=titulo, nota=nota, pasos={}, hechizos=hechizos }
    for _, q in ipairs(ids) do
      local d = destinos[q] or {}; local wp = {}
      if d.A then wp[#wp+1] = d.A end
      if d.T then wp[#wp+1] = d.T end
      local n = nombresActitud[q]
      c.pasos[#c.pasos+1] = {q=q, n=n[GL.ingles and 2 or 1], nivel=nivel, wp=wp, actitud=true}
    end
    return c
  end
  return {
    cadena(defensiva[R.id], 10, L"Actitud defensiva", GL.ingles and "Unlocks Defensive Stance, Taunt and Sunder Armor." or "Desbloquea Actitud defensiva, Provocar y Hender armadura.", {71,355,7386}),
    cadena({1718,1719}, 30, L"Actitud rabiosa", GL.ingles and "Unlocks Berserker Stance and Intercept." or "Desbloquea Actitud rabiosa e Interceptar.", {2458,20252}),
  }
end

-- Paladín de Forever: no mezclar la cadena de montura de la Alianza con la de los Renegados.
-- Redención: Efficient Games 70959 (94441), Questing.wiki (3681/2999); destinos de la ruta activa.
-- Monturas: Forever XP 97022/94971, Wowhead Forever 1279399/1296534 y 97185.
-- Los títulos ES nuevos son etiquetas de la guía mientras no haya traducción esES observada.
local function CadenasPaladin(R)
  local raza, lado = GL.Raza and GL.Raza(), Lado()
  local horda = raza == "Scourge" and lado == "H"
  local alianza = (raza == "Human" or raza == "Dwarf") and lado == "A"
  if not horda and not alianza then return {} end
  local r, destinos = {}, {}
  local function idioma(es, en) return GL.ingles and en or es end
  local idRuta = horda and "nomuerto_paladin" or (raza == "Human" and "humano_paladin" or "enano_paladin")
  local valida = R and R.clase == "PALADIN" and R.id == idRuta and R.secciones
  if valida then
    for _, sec in ipairs(R.secciones) do
      for _, paso in ipairs(sec.pasos or {}) do
        for _, w in ipairs(paso.wp or {}) do
          if w.q and (w.a == "A" or w.a == "T") then
            local d = destinos[w.q] or {}; destinos[w.q] = d
            if not d[w.a] then d[w.a] = w end
          end
        end
      end
    end
  end
  local function punto(q, a, m, x, y, z, npc, es, en)
    return {q=q,a=a,m=m,x=x,y=y,z=L(z),n=idioma(a=="A" and "Recoger: " or "Entregar: ",a=="A" and "Accept: " or "Turn in: ")..idioma(es,en).." ("..npc..")"}
  end
  local function paso(q, nv, es, en, wp)
    if not wp then
      local d = destinos[q] or {}; wp = {}
      if d.A then wp[#wp+1] = d.A end
      if d.T then wp[#wp+1] = d.T end
    end
    return {q=q,n=idioma(es,en),nivel=nv,wp=wp,actitud=true}
  end
  local function cadena(nv, es, en, notaES, notaEN, hechizos, pasos, final)
    r[#r+1] = {clase="PALADIN",nivel=nv,titulo=idioma(es,en),nota=idioma(notaES,notaEN),hechizos=hechizos,pasos=pasos,final=final}
    return r[#r]
  end
  -- Fuentes (26-11-2026): wowhandbook.com/classes/paladin/mounts/;
  -- wofwforever.com/en/questlines/paladin-class-quests/ y /forsaken-paladin-quests/;
  -- zephras.com/forever/enUS/quest/97182/ (70938), Wowhead Forever 97174-97186 y 7648.
  -- Orden recomendado, no dependencias obligatorias: la gualdrapa y el exorcismo tienen ramas.
  -- No inventar posiciones interiores. Los títulos ES nuevos son traducciones de guía.
  local function epico(q, es, en, origen, destino, notaES, notaEN, preparacion)
    local wp = {}
    for _, a in ipairs({{"A",origen},{"T",destino}}) do
      local d = a[2]
      if d then wp[#wp+1] = punto(q,a[1],d[1],d[2],d[3],d[4],d[5],es,en) end
    end
    local p = paso(q,60,es,en,wp)
    p.nota = idioma(notaES,notaEN); p.preparacion = preparacion
    return p
  end
  local dan = {1420,22.1,44.7,"Claros de Tirisfal","Danitha Morr"}
  local zay = {1454,35.7,86.9,"Orgrimmar","Zayus"}
  local ott = {1424,60.4,26.2,"Laderas de Trabalomas","Ott"}
  local nath = {1423,26.6,74.8,"Tierras de la Peste del Este","Nathanos Clamañublo"}
  local gr = {1453,48.4,50.2,"Ciudad de Ventormenta","Lord Grisillo Quiebrasombras"}
  local du = {1453,50.5,47.5,"Ciudad de Ventormenta","Duthorian Rall"}
  local ro = {1455,24.7,8.2,"Forjaz","Sumo Sacerdote Rohan"}
  local grim = {1453,59.7,33.8,"Ciudad de Ventormenta","Grimand Elmore"}
  local mer = {1424,52.2,55.5,"Laderas de Trabalomas","Merideth Carlson"}
  local matES = "Reúne 40 paños rúnicos, 6 barras de arcanita, 10 lágrimas de Arthas, 5 aguas benditas de Stratholme y 150 de oro."
  local matEN = "Collect 40 Runecloth, 6 Arcanite Bars, 10 Arthas' Tears, 5 Stratholme Holy Water and 150 gold."
  local exES = "Usa el incensario en Valle del Terror, Tierras de la Peste del Este; derrota 25 espíritus y regresa."
  local exEN = "Use the censer in Terrordale, Eastern Plaguelands; defeat 25 spirits and return."
  local feedES = "Prepara 20 galletas de maná enriquecido y 50 de oro. Canje repetible: omítelo si ya tienes el alimento."
  local feedEN = "Prepare 20 Enriched Manna Biscuits and 50 gold. Repeatable exchange: skip if you already have the feed."
  local dmES = "En La Masacre (oeste), derrota a Tendris Alabeo y entrega alimento y gualdrapa al espíritu equino."
  local dmEN = "In Dire Maul West, defeat Tendris Warpwood and give the freed equine spirit the feed and barding."
  local finES = "En Scholomance, lleva el cristal y la gualdrapa; derrota a Darkreaver con tu grupo y entrega la misión al destrero caído. Comprueba la equitación después."
  local finEN = "In Scholomance, bring the scryer and barding; defeat Darkreaver with your group and turn in to the fallen charger. Check riding afterward."
  if horda then
    cadena(2,"Luz Sagrada","Holy Light","Aprende Luz Sagrada con Aramis Hammerhand; cura a los guardias heridos.","Learn Holy Light from Aramis Hammerhand; heal the injured guards.",{635},
      {paso(90902,2,"Redescubrir la Luz","Rediscovering the Light")},90902)
    local p = {}
    for _, q in ipairs({94427,94434,94435,94436,94438,94440,94441}) do
      p[#p+1] = paso(q,12,"Una lección de divinidad","A Lesson in Divinity")
    end
    cadena(12,"Redención: Renegados","Redemption: Forsaken","Cadena de Bandarion. Lleva 10 paños de lino y utiliza el Símbolo de vida cuando lo pida la misión.","Bandarion chain. Bring 10 Linen Cloth and use the Symbol of Life when the quest asks for it.",{7328},p,94441)
    local es1,en1,es2,en2 = "Preséntate ante Danitha","Report to Danitha","El corcel de un paladín","A Paladin's Steed"
    local montura40 = cadena(40,"Montura: caballo de guerra","Mount: Warhorse","Consulta tu instructor y a Danitha Morr. Verifica la equitación y la montura en Colecciones; no se presupone el coste.","See your trainer and Danitha Morr. Check riding and the mount in Collections; cost is not assumed.",nil,{
      paso(97022,40,es1,en1,{punto(97022,"A",1458,47.5,15,"Entrañas","Garen Largo",es1,en1),punto(97022,"T",1420,22.1,44.7,"Claros de Tirisfal","Danitha Morr",es1,en1)}),
      paso(94971,40,es2,en2,{punto(94971,"A",1420,22.1,44.7,"Claros de Tirisfal","Danitha Morr",es2,en2),punto(94971,"T",1420,22.1,44.7,"Claros de Tirisfal","Danitha Morr",es2,en2)})},94971)
    montura40.montura = 1279399; montura40.hechizos = {1279399}
    local c = cadena(60,"Montura épica: Destrero de los Renegados","Epic mount: Forsaken Charger",
      "12 encargos documentados; itinerario recomendado, con ramas y canje de alimento. Confirma ofertas y requisitos en el diario. Costes documentados: 350 de oro más materiales; pueden cambiar.",
      "12 documented quests; suggested itinerary with branches and a feed exchange. Check offers and requirements in your journal. Documented fees: 350 gold plus materials; subject to change.", {1296534}, {
      epico(97174,"Un esfuerzo digno","A Worthy Endeavor",nil,dan,"Consulta a tu instructor (la oferta puede variar); vuelve a Danitha.","Ask your trainer (offer may vary); return to Danitha."),
      epico(97175,"El sacrificio debido","Due Sacrifice",dan,zay,"Prepara 150 de oro para el incensario.","Prepare 150 gold for the censer."),
      epico(97177,"Actos de misericordia","Acts of Mercy",zay,dan,"Devuelve el incensario a Danitha.","Return the censer to Danitha."),
      epico(97176,"Exorcismo en Valle del Terror","Exorcising Terrordale",dan,dan,exES,exEN),
      epico(97178,"Ott de Molino Tarren","Ott of Tarren Mill",dan,ott,"Habla con el herrero.","Speak to the blacksmith."),
      epico(97179,"Recopilación de artículos","Collection of Goods",ott,ott,matES,matEN),
      epico(97180,"La mejor obra de Ott","Ott's Finest Work",ott,dan,"Entrega la gualdrapa a Danitha.","Return the barding to Danitha."),
      epico(97186,"Alimento para caballos enriquecido con maná","Manna-Enriched Horse Feed",nath,nath,feedES,feedEN,true),
      epico(97182,"Una ofrenda de venganza","An Offering of Vengeance",dan,nil,dmES,dmEN),
      epico(97183,"La gualdrapa de arcanita bendecida","Blessed Arcanite Barding",nil,dan,"Recoge la misión del espíritu en La Masacre y vuelve a Danitha.","Accept from the spirit in Dire Maul and return to Danitha."),
      epico(97184,"El cristal de adivinación","The Divination Scryer",dan,dan,"Lleva un diamante de Azeroth y un diamante negro prístino.","Bring an Azerothian Diamond and a Pristine Black Diamond."),
      epico(97185,"Justicia y retribución","Justice and Retribution",dan,nil,finES,finEN)
    },97185)
    c.incompleta = true; c.epica = true; c.montura = 1296534
    c.pasos[1].opcionalInicio = true

  else
    -- Conservar la variante de la ruta (3681/2999), no añadir el inicio alternativo 1641/1645.
    local ids = raza == "Human" and {3681,1642,1643,1644,1780,1781,1786,1787,1788} or {2999,1646,1647,1648,1778,1779,1783,1784,1785}
    if valida then
      local p = {}
      for _, q in ipairs(ids) do p[#p+1] = paso(q,12,"El Libro de la Divinidad","The Tome of Divinity") end
      p[1].opcionalInicio = true
      cadena(12,"Redención: Libro de la Divinidad","Redemption: Tome of Divinity","Lleva 10 paños de lino y usa el Símbolo de vida. El encargo inicial puede variar según el instructor.","Bring 10 Linen Cloth and use the Symbol of Life. The introductory quest may vary by trainer.",{7328},p,ids[#ids])
    else
      for _, c in ipairs((GL.D94 and GL.D94.clase) or {}) do
        if c.clase == "PALADIN" and c.nivel == 12 and c.lado == "A" and DeMiRaza(c.razas) then
          local copia = {}; for k,v in pairs(c) do copia[k]=v end
          copia.hechizos={7328}; copia.final=ids[#ids]; r[#r+1]=copia
        end
      end
    end
    local es,en="Libro del valor","The Tome of Valor"
    local function sw(q,a) return punto(q,a,1453,50.5,47.5,"Ciudad de Ventormenta","Duthorian Rall",es,en) end
    local function wp(q,a) return punto(q,a,1436,41.7,89.2,"Páramos de Poniente","Daphne Stilwell",es,en) end
    cadena(20,"Captar no-muertos","Sense Undead","Inicia el libro del valor (objeto del instructor), protege a Daphne y vuelve a Duthorian.","Start the Tome of Valor (trainer item), defend Daphne and return to Duthorian.",{5502},{
      paso(1649,20,es,en,{sw(1649,"T")}),paso(1650,20,es,en,{sw(1650,"A"),wp(1650,"T")}),
      paso(1651,20,es,en,{wp(1651,"A"),wp(1651,"T")}),paso(1652,20,es,en,{wp(1652,"A"),sw(1652,"T")})},1652)
    local ne,ni="Libro de la nobleza","The Tome of Nobility"
    local montura40 = cadena(40,"Montura: caballo de guerra","Mount: Warhorse","Habla con Duthorian Rall. Comprueba la equitación y la montura en Colecciones.","Speak to Duthorian Rall. Check riding and the mount in Collections.",nil,
      {paso(1661,40,ne,ni,{punto(1661,"A",1453,50.5,47.5,"Ciudad de Ventormenta","Duthorian Rall",ne,ni),punto(1661,"T",1453,50.5,47.5,"Ciudad de Ventormenta","Duthorian Rall",ne,ni)})},1661)
    montura40.montura = 13819; montura40.hechizos = {13819}
    local c = cadena(60,"Montura épica: Destrero","Epic mount: Charger",
      "12 encargos documentados; itinerario recomendado, con ramas y canje de alimento. Confirma ofertas y requisitos en el diario. Costes documentados: 350 de oro más materiales; pueden cambiar.",
      "12 documented quests; suggested itinerary with branches and a feed exchange. Check offers and requirements in your journal. Documented fees: 350 gold plus materials; subject to change.", {23214}, {
      epico(7638,"Lord Grisillo Quiebrasombras","Lord Grayson Shadowbreaker",du,gr,"Consulta a tu instructor; los enanos pueden recibir otra introducción.","Ask your trainer; dwarves may get another introduction."),
      epico(7637,"Énfasis en el sacrificio","Emphasis on Sacrifice",gr,ro,"Prepara 150 de oro para el incensario.","Prepare 150 gold for the censer."),
      epico(7639,"Mostrarse juicioso","To Show Due Judgment",ro,gr,"Devuelve el incensario a Grisillo.","Return the censer to Grayson."),
      epico(7640,"Exorcismo en Valle del Terror","Exorcising Terrordale",gr,gr,exES,exEN),
      epico(7641,"El trabajo de Grimand Elmore","The Work of Grimand Elmore",gr,grim,"Habla con el herrero.","Speak to the blacksmith."),
      epico(7642,"Recopilación de artículos","Collection of Goods",grim,grim,matES,matEN),
      epico(7648,"La mejor obra de Grimand","Grimand's Finest Work",grim,gr,"Entrega la gualdrapa a Grisillo.","Return the barding to Grayson."),
      epico(7645,"Alimento para caballos enriquecido con maná","Manna-Enriched Horse Feed",mer,mer,feedES,feedEN,true),
      epico(7643,"El antiguo espíritu equino","Ancient Equine Spirit",gr,nil,dmES,dmEN),
      epico(7644,"La gualdrapa de arcanita bendecida","Blessed Arcanite Barding",nil,gr,"Recoge la misión del espíritu en La Masacre y vuelve a Grisillo.","Accept from the spirit in Dire Maul and return to Grayson."),
      epico(7646,"El cristal de adivinación","The Divination Scryer",gr,gr,"Lleva un diamante de Azeroth y un diamante negro prístino.","Bring an Azerothian Diamond and a Pristine Black Diamond."),
      epico(7647,"Juzgar y redimir","Judgment and Redemption",gr,nil,finES,finEN)
    },7647)
    c.incompleta = true; c.epica = true; c.montura = 23214
    c.pasos[1].opcionalInicio = true

  end
  return r
end

-- Cazador: los IDs de doma se contrastan con Questing.wiki, Pullwise (71037),
-- Efficient Games (70959) y Wowhead Forever. Las posiciones A/C/T proceden de la ruta activa;
-- son aproximaciones, no observaciones independientes de cada objetivo en el cliente.
local domaCazador = {
  humano_cazador={"A",94792,94863,94864,94793}, enano_cazador={"A",6064,6084,6085,6086},
  elfo_cazador={"A",6063,6101,6102,6103}, orco_trol_cazador={"H",6062,6083,6082,6081},
  tauren_cazador={"H",6061,6087,6088,6089}, skyborne_a_cazador={"A",94978,94979,94013,94050},
  skyborne_cazador={"H",94978,94979,94013,94050},
}
function GL.MisionesDomaCazador(R)
  if not R or R.clase ~= "HUNTER" then return nil end
  local d = domaCazador[R.id]
  if d then return d[4], d[5] end
end
local bestiasDoma = {
  [94792]={"Jabalí Ocultorroca","Rockhide Boar"}, [94863]={"Lobo gris del bosque","Gray Forest Wolf"}, [94864]={"Oso del bosque joven","Young Forest Bear"},
  [6064]={"Gran jabalí del risco","Large Crag Boar"}, [6084]={"Leopardo de la nieve","Snow Leopard"}, [6085]={"Oso zarpahelada","Ice Claw Bear"},
  [6063]={"Rondador Tejemadera","Webwood Lurker"}, [6101]={"Acechador sable de la noche","Nightsaber Stalker"}, [6102]={"Estridador estrígido","Strigid Screecher"},
  [6062]={"Jabalí jaspeado feroz","Dire Mottled Boar"}, [6083]={"Reptador de espuma","Surf Crawler"}, [6082]={"Escórpido acorazado","Armored Scorpid"},
  [6061]={"Zancudo de llanura adulto","Adult Plainstrider"}, [6087]={"Acechador de pradera","Prairie Stalker"}, [6088]={"Aguilón","Swoop"},
  [94978]={"Cangrejo cantoviento","Windsong Crawler"}, [94979]={"Galestrider arisco","Ornery Galestrider"}, [94013]={"Vuldren alfa","Vuldren Alpha"},
}
local function CadenasCazador(R)
  local d = R and R.clase == "HUNTER" and domaCazador[R.id]
  if not d or d[1] ~= Lado() or not R.secciones then return {} end
  local raza = GL.Raza and GL.Raza()
  if raza then
    local coincide=false
    for _, token in ipairs(R.razas or {}) do if token == raza then coincide=true end end
    if not coincide then return {} end
  end
  local function idioma(es,en) return GL.ingles and en or es end
  local destinos, ids = {}, {[8151]=true,[8153]=true,[8231]=true,[8232]=true}
  for i=2,5 do ids[d[i]]=true end
  for _, sec in ipairs(R.secciones) do
    for _, p in ipairs(sec.pasos or {}) do
      for _, w in ipairs(p.wp or {}) do
        if ids[w.q] and (w.a=="A" or w.a=="C" or w.a=="T") then
          local t=destinos[w.q] or {}; destinos[w.q]=t
          if not t[w.a] then t[w.a]=w end
        end
      end
    end
  end
  local function paso(q,nv,es,en,nota,objetivo)
    local t=destinos[q] or {}; local wp={}
    for _, a in ipairs({"A","C","T"}) do
      if t[a] then
        local v={}; for k,x in pairs(t[a]) do v[k]=x end
        if GL.ingles then v.n= (a=="A" and "Accept: " or a=="T" and "Turn in: " or "Objective: ")..en end
        wp[#wp+1]=v
      end
    end
    return {q=q,n=idioma(es,en),nivel=nv,wp=wp,actitud=true,objetivo=objetivo,nota=nota}
  end
  local p={}
  for i=2,4 do
    local b=bestiasDoma[d[i]]
    p[#p+1]=paso(d[i],10,"Domesticar la bestia: "..b[1],"Taming the Beast: "..b[2],
      idioma("Usa la fusta de esta misión y no ataques a la bestia durante la doma. Consulta el objetivo del diario si el nombre localizado difiere.","Use this quest's taming rod and do not attack during taming. Check the quest log if the localized name differs."),true)
  end
  local doma={clase="HUNTER",nivel=10,titulo=idioma("Domesticación de mascotas","Pet taming"),
    nota=idioma("Tres pruebas de tu raza. Desbloquean Domesticar bestia, Llamar a mascota y Retirar mascota. Si el instructor ofrece una introducción, complétala primero.","Three racial trials unlock Tame Beast, Call Pet and Dismiss Pet. If your trainer offers a breadcrumb quest, complete it first."),
    pasos=p,final=d[4],hechizos={1515,883,2641}}
  local entrenamiento={clase="HUNTER",nivel=10,titulo=idioma("Entrenamiento de mascotas","Pet training"),
    nota=idioma("Tras las tres pruebas, habla con el instructor de mascotas para aprender Entrenar bestia, Alimentar mascota y Revivir mascota.","After the trials, speak to the pet trainer to learn Beast Training, Feed Pet and Revive Pet."),
    pasos={paso(d[5],10,"Entrenar a la bestia","Training the Beast",idioma("No abandones la cadena tras la tercera doma.","Do not stop after the third tame."))},
    final=d[5],hechizos={5149,6991,982},requiereCadena=doma}
  -- La ruta de refuerzo 8151 usa un instructor de Horda incluso en Alianza.
  -- No reutilizar esa aceptación: escoger un instructor de tu facción en el juego.
  local a=paso(8151,50,"El talismán del cazador","The Hunter's Charm",idioma("Pide el encargo a un instructor de cazador de tu facción; después visita a Ogtinc en Azshara.","Ask a hunter trainer of your faction, then visit Ogtinc in Azshara."))
  for i=#a.wp,1,-1 do if a.wp[i].a=="A" then table.remove(a.wp,i) end end
  a.opcionalInicio=true
  local talisman={clase="HUNTER",nivel=50,titulo=idioma("El talismán del cazador","The Hunter's Charm"),
    nota=idioma("Cadena opcional de equipo, disponible desde nivel 50 según el requisito del catálogo; verifica la oferta en el instructor. Termina en el Templo Sumergido.","Optional gear chain, minimum level 50 in the catalogue; verify the trainer offer. Ends in Sunken Temple."),
    pasos={a,paso(8153,50,"Cuernos de corcel","Courser Antlers",nil,true),paso(8231,50,"Los vándalos marinos","Wavethrashing",nil,true),
      paso(8232,50,"El draco verde","The Green Drake",idioma("Completa el objetivo en el Templo Sumergido con un grupo; vuelve a Ogtinc.","Complete the objective in Sunken Temple with a group; return to Ogtinc."),true)},final=8232}
  local r={doma,entrenamiento,talisman}
  -- Rhok'delar: datos históricos conservados, no presentar como cadena disponible hoy.
  for _, c in ipairs((GL.D94 and GL.D94.clase) or {}) do
    if c.clase=="HUNTER" and c.titulo=="Rhok'delar" then
      local v={}; for k,x in pairs(c) do v[k]=x end
      v.incompleta=true; v.sinGuiado=true
      v.nota=idioma("Cadena histórica de equipo. El acceso a la Hoja antigua y su banda no está confirmado en Forever. Se incorporará el recorrido operativo cuando se confirme.","Historical gear chain. Access to the Ancient Leaf and its raid is unconfirmed in Forever. Operational guidance will be added when verified.")
      v.pasos={}
      for _, q in ipairs(c.pasos or {}) do local z={}; for k,x in pairs(q) do z[k]=x end; if GL.ingles then z.n=z.ing or z.n end; v.pasos[#v.pasos+1]=z end
      r[#r+1]=v
    end
  end
  return r
end

-- Pícaro: cadenas de práctica y desbloqueo separadas; fuentes Forever 26-11-2026:
-- questing.wiki/wow-forever/quests/series/2281/, /series/2378/, /series/2478/;
-- mobalytics.gg/wow-forever/profile/roguesdiary/guides/rogue-lockpicking-guide.
-- Los destinos se reutilizan de la ruta activa, no son una nueva verificación de coordenadas.
local rutasPicaro = {humano_picaro="A",enano_gnomo_picaro="A",elfo_picaro="A",skyborne_a_picaro="A",
  nomuerto_picaro="H",orco_trol_picaro="H",skyborne_picaro="H"}
local function CadenasPicaro(R)
  local lado = R and R.clase=="ROGUE" and rutasPicaro[R.id]
  if not lado or lado~=Lado() or not R.secciones then return {} end
  local raza=GL.Raza and GL.Raza()
  if raza then
    local coincide=false
    for _,token in ipairs(R.razas or {}) do if token==raza then coincide=true end end
    if not coincide then return {} end
  end
  local function I(es,en) return GL.ingles and en or es end
  local ids={ [2281]=true,[2282]=true,[2379]=true,[2382]=true,[2381]=true,
    [2360]=true,[2359]=true,[2607]=true,[2608]=true,[2609]=true,[2460]=true,[2458]=true,[2478]=true,[2479]=true,[2480]=true }
  local destinos={}
  local function guardar(w)
    if ids[w.q] and (w.a=="A" or w.a=="C" or w.a=="T") then
      local d=destinos[w.q] or {};destinos[w.q]=d
      if not d[w.a] then d[w.a]=w end
    end
  end
  for _,sec in ipairs(R.secciones) do for _,p in ipairs(sec.pasos or {}) do
    for _,w in ipairs(p.wp or {}) do guardar(w) end
  end end
  -- Los destinos de la cura opcional de Alianza ya estaban en Datos94; conservarlos sin prometer verificación.
  for _,c in ipairs((GL.D94 and GL.D94.clase) or {}) do
    if c.clase=="ROGUE" and c.lado==lado then
      for _,p in ipairs(c.pasos or {}) do for _,w in ipairs(p.wp or {}) do guardar(w) end end
    end
  end
  local function P(q,n,es,en,notaES,notaEN,objetivo,opcional)
    local wp={};local d=destinos[q] or {}
    for _,a in ipairs({"A","C","T"}) do if d[a] then
      local v={};for k,x in pairs(d[a]) do v[k]=x end
      if GL.ingles then v.n=(a=="A" and "Accept: " or a=="T" and "Turn in: " or "Objective: ")..en end
      wp[#wp+1]=v
    end end
    return {q=q,n=I(es,en),nivel=n,wp=wp,actitud=true,objetivo=objetivo,opcionalInicio=opcional,nota=I(notaES,notaEN)}
  end
  local function cadena(n,es,en,notaES,notaEN,pasos,final,hechizos)
    return {clase="ROGUE",nivel=n,titulo=I(es,en),nota=I(notaES,notaEN),pasos=pasos,final=final,hechizos=hechizos}
  end
  local practicaES="Aprende Forzar cerradura con el instructor al 16. Consigue herramientas de ladrón (misión o vendedor); practica hasta 80 antes de los venenos. Esta cadena es opcional si ya tienes habilidad suficiente."
  local practicaEN="Train Pick Lock at 16. Obtain Thieves' Tools (quest or vendor); practise to 80 before poisons. This chain is optional if you already have enough skill."
  local venES="Empieza al 20; se recomienda 80 de Forzar cerraduras y nivel 22 para Esfumarse. El requisito exacto del cofre de Alianza varía entre fuentes."
  local venEN="Start at 20; 80 Lockpicking and level 22 for Vanish are recommended. Sources disagree on the exact Alliance chest requirement."
  local r={}
  if lado=="A" then
    r[1]=cadena(16,"Práctica de cerraduras","Lockpicking practice",practicaES,practicaEN,{
      P(2281,16,"Cita en Crestagrana","Redridge Rendezvous","Habla con Renzik; el instructor puede ofrecer una introducción alternativa según tu raza.","Speak to Renzik; your trainer may offer an alternative racial introduction.",false,true),
      P(2282,16,"Molino de Alther","Alther's Mill","Practica con los arcones y abre el de Lucius cuando tengas habilidad suficiente.","Practise on lockboxes and open Lucius's box once you have sufficient skill.",true)},2282)
    r[2]=cadena(20,"Desbloqueo de venenos","Unlock Poisons",venES,venEN,{
      P(2360,20,"Mathias y los Defias","Mathias and the Defias","Habla con Mathias y después con la agente Kearnen.","Speak to Mathias, then Agent Kearnen."),
      P(2359,20,"La torre de Klaven","Klaven's Tower","Roba la llave al zángano, abre el cofre y vuelve a Mathias. El nivel del encargo no es el nivel mínimo de oferta.","Pickpocket the key from the drone, open the chest and return to Mathias. Quest level is not the minimum offer level.",true)},2359,{2842,8681})
    r[2].habilidad=40
    r[3]=cadena(20,"Cura de Zanzil (opcional)","Zanzil cure (optional)","Cadena posterior a Klaven; no es necesaria para aprender Venenos. Consulta al instructor si tienes el efecto.","Follow-up to Klaven; not required to learn Poisons. Ask your trainer if you have the debuff.",{
      P(2607,20,"Toque de Zanzil","The Touch of Zanzil"),P(2608,20,"Toque de Zanzil","The Touch of Zanzil","Consulta los ingredientes y objetivos del diario.","Check ingredients and objectives in your journal.",true),P(2609,20,"Toque de Zanzil","The Touch of Zanzil")},2609)
    r[3].requiereCadena=r[2]
  else
    r[1]=cadena(16,"Práctica de cerraduras","Lockpicking practice",practicaES,practicaEN,{
      P(2379,16,"Zando'zan","Zando'zan","La introducción puede variar; si ya tienes el encargo de Trinquete, sigue con él.","The introduction can vary; if you already have the Ratchet quest, continue with it.",false,true),
      P(2382,16,"Desdio de Trinquete","Wrenix of Ratchet","Habla con Desdio y su aparato para obtener las herramientas.","Speak to Wrenix and his apparatus for the tools."),
      P(2381,16,"Saquear a los saqueadores","Plundering the Plunderers","Practica en los arcones del barco; comprueba el requisito del cofre de la misión.","Practise on the ship's lockboxes; check the quest chest requirement.",true)},2381)
    r[2]=cadena(20,"Desbloqueo de venenos","Unlock Poisons",venES,venEN,{
      P(2460,20,"El saludo de los Mano Destrozada","The Shattered Salute","Saluda al instructor cuando te lo indique.","Salute the trainer when prompted.",true),
      P(2458,20,"Agente encubierto","Deep Cover","Usa la bengala según el diario y saluda al agente.","Use the flare as instructed and salute the agent.",true),
      P(2478,20,"Misión: posible, pero no probable","Mission: Possible But Not Probable","Roba la llave, completa los objetivos y abre el cofre. Aún no termina el desbloqueo.","Pickpocket the key, complete objectives and open the chest. The unlock is not finished yet.",true),
      P(2479,20,"La ayuda de Hinott","Hinott's Assistance","Viaja a Molino Tarren; habla con Serge Hinott.","Travel to Tarren Mill; speak to Serge Hinott."),
      P(2480,20,"La ayuda de Hinott","Hinott's Assistance","Espera a que prepare la cura y entrega el último encargo para aprender Venenos.","Wait for the cure and turn in the final quest to learn Poisons.",true)},2480,{2842,8681})
    r[2].habilidad=40
  end
  -- B06: encargos opcionales comunes a ambas facciones. Sin coordenadas no verificadas.
  -- El orden de las misiones independientes del Sindicato no implica prerrequisitos.
  local function referencia(n,es,en,ne,nn,pasos,final)
    local c=cadena(n,es,en,ne,nn,pasos,final)
    c.sinGuiado=true
    for _,p in ipairs(c.pasos) do p.wp={};p.referencia=true end
    r[#r+1]=c
  end
  referencia(24,"Ravenholdt (opcional)","Ravenholdt (optional)",
    "Solicita la carta al instructor de pícaro. Si no aparece, consulta la oferta real; no es requisito de Venenos.",
    "Ask a rogue trainer for the letter. If absent, check the actual offer; not required for Poisons.",{
      P(6681,24,"La mansión Ravenholdt","The Manor, Ravenholdt","Lleva el sello a Fahrad, en la mansión de las Montañas de Alterac.","Take the seal to Fahrad at the manor in Alterac Mountains.")},6681)
  referencia(24,"Emblemas del Sindicato (repetible)","Syndicate Emblems (repeatable)",
    "Tras 6681, consulta al guardia de Ravenholdt. Canje de reputación; no se cuenta como XP de leveo.",
    "After 6681, ask a Ravenholdt guard. Reputation turn-in; not counted as leveling XP.",{
      P(6701,24,"Emblemas del Sindicato","Syndicate Emblems","Roba emblemas a miembros del Sindicato y entrégalos al guardia; consulta el límite de reputación.","Pickpocket Syndicate emblems and turn them in to the guard; check the reputation cap.",true)},nil)
  r[#r].repetible=true
  referencia(24,"Sabotaje del Sindicato (opcional)","Syndicate Sabotage (optional)",
    "Encargo nuevo. Consulta a Myrokos Silenforma en Ravenholdt; no se presupone un requisito de reputación.",
    "New quest. Ask Myrokos Silentform at Ravenholdt; no reputation prerequisite assumed.",{
      P(96779,24,"Sabotaje del Sindicato","Syndicate Sabotage","Derrota a Lord Tomas en Durnholde y vuelve a Myrokos.","Defeat Lord Tomas in Durnholde and return to Myrokos.",true)},96779)
  referencia(24,"Investigación del Sindicato (opcional)","Syndicate investigation (optional)",
    "Consulta a Myrokos en Ravenholdt. Encargo de nivel 36, mínimo 24; no es una fase obligatoria del sabotaje.",
    "Ask Myrokos at Ravenholdt. Quest level 36, minimum 24; not a mandatory stage of Sabotage.",{
      P(96781,24,"¿Cuál es la gran idea?","What's the Big Idea?","Sigue los objetivos del diario; requisitos exactos pendientes.","Follow your quest journal; exact prerequisites unconfirmed.",true)},96781)
  referencia(24,"Infiltración del Sindicato (opcional)","Syndicate infiltration (optional)",
    "Misiones de nivel 36 con mínimo de oferta 24 documentado para el inicio. Revisa el nivel de los enemigos antes de intentar la infiltración.",
    "Level-36 quests with a documented minimum starting level of 24. Check enemy levels before attempting infiltration.",{
      P(96783,24,"Una forma de entrar","A Way In","Consigue un uniforme del Sindicato en Northfold Manor.","Obtain a Syndicate uniform at Northfold Manor.",true),
      P(96784,24,"Maestro del disfraz","Master of Disguise","Sigue las instrucciones del disfraz en el diario.","Follow the disguise instructions in your journal.",true),
      P(96785,24,"No se sabe","Ain't No Telling","Continúa con el contacto indicado en el diario.","Continue with the contact specified in your journal.",true),
      P(96786,24,"El golpe del Sindicato","The Syndicate Sting","Completa el objetivo en Arathi y consulta la entrega indicada en el diario.","Complete the Arathi objective and check the turn-in in your journal.",true)},96786)
  referencia(50,"La llave azur (equipo opcional)","The Azure Key (optional gear)",
    "Cadena de equipo de nivel 52, disponible desde 50. El último objetivo requiere el Templo Sumergido. Consulta un instructor de tu facción.",
    "Level-52 gear chain, available from 50. The final objective requires Sunken Temple. Ask a trainer of your faction.",{
      P(8233,50,"Un pedido sencillo","A Simple Request","Habla con Lord Jorach Ravenholdt; la introducción del instructor puede omitirse.","Speak to Lord Jorach Ravenholdt; the trainer breadcrumb may be skipped.",false,true),
      P(8234,50,"Bolsa azur sellada","Sealed Azure Bag","Roba la bolsa a chamanes Fauces de Madera y entrégala al archimago Xylem en Azshara.","Pickpocket Timbermaw shamans for the bag and deliver it to Archmage Xylem in Azshara.",true),
      P(8235,50,"Fragmentos codificados","Encoded Fragments","Reúne los 10 fragmentos que solicita Xylem.","Collect the 10 fragments requested by Xylem.",true),
      P(8236,50,"La llave azur","The Azure Key","Consigue la llave de Morphaz en el Templo Sumergido y vuelve a Jorach. Confirma acceso y recompensa.","Obtain the key from Morphaz in Sunken Temple and return to Jorach. Confirm access and reward.",true)},8236)
  return r
end

-- Sacerdote B05: dos facultades por raza. Las variantes son alternativas, no una cadena obligatoria.
-- Questing.wiki y WoW Forever Outpost (26/11); conservar los destinos ya existentes de la ruta.
local racialesSacerdote = {
  Human={"A",{1277370,94774,"Gracia divina","Divine Grace",{94773,94775,94776,94777,94778,94779}},{13896,5676,"Reacción","Arcane Feedback",{5677,5678}}},
  Dwarf={"A",{13908,5637,"Oración desesperada","Desperate Prayer",{5634,5635,5636,5638,5639}},{1277331,5645,"Castigo","Chastise",{5641,5647}}},
  Gnome={"A",{1277455,94824,"Destello desconcertante","Confounding Flash",{94817,94821,94822,94823,94825,94826}},{1277462,94819,"Plan de contingencia","Contingency Plan",{94818,94820}}},
  NightElf={"A",{10797,5627,"Fragmentos estelares","Stars of Elune",{5628,5629,5630,5631,5632,5633}},{2651,5672,"Gracia de Elune","Elune's Grace",{5673,5674,5675}}},
  Scourge={"H",{2652,5658,"Toque de debilidad","Touch of Weakness",{5660,5661,5662,5663}},{1277324,5679,"Sacrificio oscuro","Dark Sacrifice",{5644,5646}}},
  Troll={"H",{9035,5654,"Maleficio de debilidad","Hex of Weakness",{5652,5655,5656,5657}},{18137,5680,"Guardia de las Sombras","Shadowguard",{5642,5643}}},
}
local function CadenasSacerdote(R)
  local raza=GL.Raza and GL.Raza()
  local datos=racialesSacerdote[raza]
  if not R or R.clase~="PRIEST" or not datos or datos[1]~=Lado() then return {} end
  local coincide=false
  for _,v in ipairs(R.razas or {}) do if v==raza then coincide=true end end
  if not coincide then return {} end
  local function I(es,en) return GL.ingles and en or es end
  local destinos={}
  for _,sec in ipairs(R.secciones or {}) do for _,p in ipairs(sec.pasos or {}) do
    for _,w in ipairs(p.wp or {}) do if w.q and (not w.raza or w.raza==raza) and (w.a=="A" or w.a=="C" or w.a=="T") then
      destinos[w.q]=destinos[w.q] or {}; if not destinos[w.q][w.a] then destinos[w.q][w.a]=w end
    end end
  end end
  local function wp(q,n,original)
    local r={};local d=destinos[q] or {}
    for _,a in ipairs({"A","C","T"}) do
      local w=d[a]; if not w then for _,v in ipairs(original or {}) do if v.a==a then w=v;break end end end
      if w then local v={};for k,x in pairs(w) do v[k]=x end
        v.n=I(a=="A" and "Recoger: " or a=="C" and "Objetivo: " or "Entregar: ",a=="A" and "Accept: " or a=="C" and "Objective: " or "Turn in: ")..n.." "..(w.n and w.n:match("(%b())$") or "")
        r[#r+1]=v
      end
    end
    return r
  end
  local r={}
  -- Las prendas de enano son también de gnomo (5625); no enseñan la racial del 10.
  for _,c in ipairs((GL.D94 and GL.D94.clase) or {}) do
    if c.clase=="PRIEST" and c.nivel==5 and c.lado==datos[1] and (DeMiRaza(c.razas) or (raza=="Gnome" and c.razas==4)) then
      local prendas={clase="PRIEST",nivel=5,titulo=I("Prendas de sacerdote","Priest garments"),nota=I("Cura al herido con Sanación inferior II y aplica Palabra de poder: entereza. Recompensa de equipo opcional.","Cast Lesser Heal II and Power Word: Fortitude on the injured ally. Optional gear reward."),pasos={}}
      for i,p in ipairs(c.pasos) do local n=I(p.n,p.ing or p.n); prendas.pasos[i]={q=p.q,n=n,nivel=5,wp=wp(p.q,n,p.wp),actitud=true,objetivo=i==#c.pasos,opcionalInicio=i==1} end
      prendas.final=prendas.pasos[#prendas.pasos].q;r[#r+1]=prendas
    end
  end
  for i=2,3 do
    local e=datos[i];local nv=(i-1)*10; local id,preferida=e[1],e[2];local n=I(e[3],e[4]);local q=preferida
    -- Seleccionar primero la variante ya completada o activa; nunca exigir las alternativas restantes.
    local ids={preferida};for _,v in ipairs(e[5]) do ids[#ids+1]=v end
    for _,v in ipairs(ids) do if Llevo(v) then q=v;break end end
    for _,v in ipairs(ids) do if Hecha(v) then q=v;break end end
    local nombreMision=(e[1]==10797 and q~=preferida) and I("Regreso a casa","Returning Home") or n
    local w=wp(q,nombreMision); local referencia=#w==0
    local nota=I("Consulta el instructor de tu raza. Las misiones con el mismo hechizo son alternativas; confirma el aprendizaje en el libro. No se han verificado las coordenadas en el cliente.","Ask your racial trainer. Quests granting the same spell are alternatives; confirm learning in the spellbook. Coordinates are not client-verified.")
    r[#r+1]={clase="PRIEST",nivel=nv,titulo=n,nota=nota,hechizos={id},final=q,pasos={{q=q,n=nombreMision,nivel=nv,wp=w,actitud=true,referencia=referencia,nota=I("Misión #","Quest #")..q}}}
  end
  -- B06: equipo opcional. Los niveles 50/60 son de oferta, no el nivel de misión.
  -- Fuentes: Questing.wiki 8254-8257; Wowhead guía 21/11/2026; Blizzard 24303862.
  local function Equipo(q,nv,es,en,nes,nen,objetivo,acciones)
    local n=I(es,en);local w={}
    for _,v in ipairs(wp(q,n)) do if acciones and acciones[v.a] then w[#w+1]=v end end
    -- Las rutas Horda no contienen esta cadena. Los puntos comunes A/T están
    -- documentados en Questing.wiki 8254-8257; no se crean puntos de objetivo.
    if acciones and q>=8254 and q<=8257 then
      local presentes={};for _,v in ipairs(w) do presentes[v.a]=true end
      for _,act in ipairs({"A","T"}) do
        if acciones[act] and not presentes[act] then
          local greta=q==8257 and act=="T"
          w[#w+1]={q=q,a=act,m=greta and 1448 or 1447,z=greta and "Frondavil" or "Azshara",
            x=greta and 51.2 or 42.4,y=greta and 82.1 or 42.6,
            n=I(act=="A" and "Recoger: " or "Entregar: ",act=="A" and "Accept: " or "Turn in: ")..n..(greta and " (Greta Mosshoof)" or " (Ogtinc)")}
        end
      end
    end
    return {q=q,n=n,nivel=nv,wp=w,actitud=true,objetivo=objetivo,referencia=#w==0,nota=I(nes,nen)}
  end
  local AT={A=true,T=true}
  r[#r+1]={clase="PRIEST",nivel=50,titulo=I("Templo Sumergido: equipo opcional","Sunken Temple: optional gear"),
    nota=I("Cuatro misiones de nivel 52 disponibles desde el 50. Requiere grupo para Morphaz. Elige una recompensa de equipo; no desbloquea hechizos. Posiciones documentadas o reutilizadas; pendientes de verificar en cliente.","Four level-52 quests available from 50. A group is needed for Morphaz. Choose one gear reward; no spell unlock. Documented or reused locations are not client-verified."),final=8257,pasos={
      Equipo(8254,50,"Ayuda a Cenarion","Cenarion Aid","Consulta al instructor de sacerdotes de tu facción y viaja a Ogtinc en Azshara (42.4, 42.6).","Ask your faction's priest trainer and travel to Ogtinc in Azshara (42.4, 42.6).",false,{T=true}),
      Equipo(8255,50,"Los trotadores Pezuñamusgo","Of Coursers We Know","Consigue 4 glándulas de corcel sano de los Pezuñamusgo de Azshara; vuelve a Ogtinc.","Collect 4 Healthy Courser Glands from Mosshoof coursers in Azshara; return to Ogtinc.",true,AT),
      Equipo(8256,50,"El icor de los no-muertos","The Ichor of Undeath","Entrega 1 icor de los no-muertos a Ogtinc.","Bring 1 Ichor of Undeath to Ogtinc.",true,AT),
      Equipo(8257,50,"La sangre de Morphaz","Blood of Morphaz","Derrota a Morphaz en Atal'Hakkar y entrega la sangre a Greta Pezuñamusgo en Frondavil (51.2, 82.1). Recompensas a elegir: objetos #19990, #20082, #20006.","Defeat Morphaz in Atal'Hakkar and bring his blood to Greta Mosshoof in Felwood (51.2, 82.1). Choose one reward: items #19990, #20082, #20006.",true,AT),
    }}
  r[#r+1]={clase="PRIEST",nivel=60,titulo=I("Bendición y Anatema (referencia)","Benediction and Anathema (reference)"),sinGuiado=true,epica=true,
    nota=I("Contenido de banda pendiente: Núcleo de Magma no tiene apertura acreditada a 26/11/2026. Consigue Ojo de Divinidad (#18646), Ojo de las Sombras (#18665) y Astilla de Nordrassil (#18659). Usa la astilla con los dos ojos para crear Bendición (#18608), convertible en Anatema (#18609). Completar las misiones no equivale a poseer el bastón. Confirma disponibilidad y reglas del evento en futuras versiones.","Raid content pending: Molten Core has no confirmed opening as of 26 Nov 2026. Obtain Eye of Divinity (#18646), Eye of Shadow (#18665), and Splinter of Nordrassil (#18659). Use the splinter with both eyes to create Benediction (#18608), convertible to Anathema (#18609). Quest completion is not staff ownership. Confirm availability and event rules in future releases."),final=7622,pasos={
      Equipo(7621,60,"Una advertencia","A Warning","Referencia: Eris Havenfire; requiere verificar acceso con el Ojo de Divinidad.","Reference: Eris Havenfire; verify access with the Eye of Divinity.",false),
      Equipo(7622,60,"Equilibrio de Luz y Sombras","The Balance of Light and Shadow","Evento de rescate de campesinos; recompensa Astilla de Nordrassil. No iniciar hasta confirmar acceso y reglas en Forever.","Peasant rescue event; rewards Splinter of Nordrassil. Do not start until access and rules are confirmed in Forever.",true),
    }}
  return r
end

-- B05: cada perfil sigue sus propias misiones de elemento. Las posiciones se
-- reutilizan de la ruta activa; no se atribuyen las coordenadas a pruebas en cliente.
-- La posesión del objeto y el historial de misión son comprobaciones distintas.
function GL.TotemChamanEnBolsas(id)
  local api=(C_Item and C_Item.GetItemCount) or GetItemCount
  if type(api)~="function" then return nil end
  local ok,n=pcall(api,id,false)
  if ok and type(n)=="number" then return n>0 end
  return nil
end
local datosTotemsChaman={
  enano_chaman={{94373,94374,94375},{94449,94465,94466,94467,94468},{94494,94495,94497,94499,94500,94501,94502,94503,94505},{94789}},
  orco_trol_chaman={{1516,1517,1518},{2983,1524,1525,1526,1527},{1528,1530,1535,1536,1534,220,63,100,96},{1531}},
  tauren_chaman={{1519,1520,1521},{2984,1524,1525,1526,1527},{1528,1530,1535,1536,1534,220,63,100,96},{1531}},
  skyborne_chaman={{92466,92467,92468},{97243,97244,97245,97257},{1528,1530,1535,1536,1534,220,63,100,96},{96136}},
}
local elementosChaman={
  {5175,4,"Tierra","Earth",8071}, {5176,10,"Fuego","Fire",3599},
  {5177,20,"Agua","Water",5394}, {5178,30,"Aire","Air"},
}
local function CadenasChaman(R)
  if not R or R.clase~="SHAMAN" then return {} end
  local perfil=datosTotemsChaman[R.id]; if not perfil then return {} end
  local raza=GL.Raza and GL.Raza(); local coincide=false
  for _,v in ipairs(R.razas or {}) do if v==raza then coincide=true end end
  if not coincide or Lado()~=(R.id=="enano_chaman" and "A" or "H") then return {} end
  local function I(es,en) return GL.ingles and en or es end
  local destinos={}
  for _,sec in ipairs(R.secciones or {}) do for _,p in ipairs(sec.pasos or {}) do
    for _,w in ipairs(p.wp or {}) do if w.q and (not w.raza or w.raza==raza) and (w.a=="A" or w.a=="C" or w.a=="T") then
      destinos[w.q]=destinos[w.q] or {}; if not destinos[w.q][w.a] then destinos[w.q][w.a]=w end
    end end
  end end
  local function W(q,a,m,z,x,y,n)
    destinos[q]=destinos[q] or {}; destinos[q][a]={q=q,a=a,m=m,z=z,x=x,y=y,n=n}
  end
  -- Oferta específica de Skyborne confirmada: Mulgore -> Mil Agujas (#96136).
  if raza=="Skyborne" then
    W(96136,"A",1412,"Mulgore",33.4,22.4,"Alaana Stormwalker")
    W(96136,"T",1441,"Las Mil Agujas",53.5,42.7,"Prate Cloudseer")
  end
  -- Las introducciones de Agua y Aire son alternativas, nunca pasos consecutivos.
  local function variante(ids,def)
    for _,q in ipairs(ids) do if Llevo(q) then return q end end
    for _,q in ipairs(ids) do if Hecha(q) then return q end end
    return def
  end
  local r={}
  for i,e in ipairs(elementosChaman) do
    local nivel=(i==1 and raza=="Skyborne") and 3 or e[2]
    local titulo=I("Tótem de "..e[3]:lower(),e[4].." Totem")
    local nombre=I(({"La llamada de la tierra","La llamada del fuego","La llamada del agua","La llamada del aire"})[i],"Call of "..e[4])
    local c={clase="SHAMAN",nivel=nivel,titulo=titulo,objetoTotem=e[1],pasos={},nota=I("Conserva el objeto #"..e[1].." en las bolsas para usar los tótems de este elemento. Coordenadas de ruta o fuentes externas, pendientes de comprobación en cliente.","Keep item #"..e[1].." in your bags to use this element's totems. Route or external coordinates, pending client verification.")}
    if i==2 and raza=="Skyborne" then c.nota=c.nota..I(" En 97257, entrega la antorcha dentro de los 5 minutos indicados."," In 97257, turn in the torch within the stated 5 minutes.") end
    local ids={};for j,q in ipairs(perfil[i]) do ids[j]=q end
    if i==2 and Lado()=="H" and raza~="Skyborne" then
      ids[1]=variante({1522,1523,2983,2984},ids[1])
    elseif i==3 and Lado()=="H" then
      ids[1]=variante({1528,1529,2985,2986},ids[1])
      if raza=="Skyborne" then c.nota=c.nota..I(" Oferta inicial de Agua para Skyborne pendiente de confirmar: consulta primero al instructor."," Skyborne Water lead-in availability unconfirmed: ask your trainer first.") end
    elseif i==4 and Lado()=="H" then
      ids[1]=variante(raza=="Skyborne" and {96136,1531,1532} or {1531,1532},ids[1])
    end
    c.final=ids[#ids]
    for j,q in ipairs(ids) do
      local w={};local d=destinos[q] or {}
      for _,a in ipairs({"A","C","T"}) do if d[a] then
        local v={};for k,x in pairs(d[a]) do v[k]=x end
        v.n=I(a=="A" and "Recoger: " or a=="C" and "Objetivo: " or "Entregar: ",a=="A" and "Accept: " or a=="C" and "Objective: " or "Turn in: ")..nombre.." "..(d[a].n and d[a].n:match("(%b())$") or "")
        w[#w+1]=v
      end end
      if i==3 and j==1 and raza=="Skyborne" and not Llevo(q) and not Hecha(q) then w={} end
      local intro=(i==2 and j==1 and raza~="Skyborne") or (i==3 and j==1)
      c.pasos[#c.pasos+1]={q=q,n=nombre,nivel=nivel,wp=w,actitud=true,objetivo=true,referencia=#w==0,opcionalInicio=intro,nota=I("Misión #","Quest #")..q}
    end
    r[#r+1]=c
  end
  -- B06: equipo opcional; no desbloquea talentos ni roles de tanque.
  -- No inventar destinos de objetivos o entregas que las fuentes no acreditan.
  local function Punto(q,a,p,n)
    return {q=q,a=a,m=p[1],z=p[2],x=p[3],y=p[4],n=n.." ("..p[5]..")"}
  end
  local veyric={1417,"Tierras Altas de Arathi",59.8,27.6,"Veyric Thunderhame"}
  local rau={1441,"Las Mil Agujas",46.1,51.7,"Rau Cliffrunner"}
  local prate={1441,"Las Mil Agujas",53.5,42.6,"Prate Cloudseer"}
  local bath={1416,"Montañas de Alterac",80.5,66.9,"Bath'rah the Windwatcher"}
  local function Paso(q,nv,es,en,nes,nen,acepta,entrega,objetivo)
    local n=I(es,en);local w={}
    if acepta then w[#w+1]=Punto(q,"A",acepta,I("Recoger: ","Accept: ")..n) end
    if entrega then w[#w+1]=Punto(q,"T",entrega,I("Entregar: ","Turn in: ")..n) end
    return {q=q,n=n,nivel=nv,wp=w,actitud=true,objetivo=objetivo,referencia=#w==0,nota=I(nes,nen)}
  end
  local alianza=Lado()=="A"
  local armas={clase="SHAMAN",nivel=30,titulo=I("Armas de la tempestad (equipo opcional)","The Tempest's Weapons (optional gear)"),
    requiereCadena=r[4],priorizarActiva=true,final=alianza and 96016 or 79442,pasos={},
    nota=I("Completa Aire primero. Algunas ofertas y entregas de Horda difieren entre fuentes; consulta a Prate o Rau si no aparece el encargo. Misiones de nivel 33–43, disponibles desde el 30; reúne un grupo para Horado Rajacieno y el ritual. Recibirás Elementalist's Guard y elegirás un arma: Lightning's Grasp (Elemental), Rage of the Storm (Mejora, dos manos) o Tidebringer's Claw (Restauración). Comprueba estadísticas y oferta en el cliente.","Complete Air first. Some Horde quest givers differ between sources; ask Prate or Rau if unavailable. Level 33–43 quests available from 30; group up for Razorfen Kraul and the ritual. Receive Elementalist's Guard and choose one weapon: Lightning's Grasp (Elemental), Rage of the Storm (Enhancement, two-handed), or Tidebringer's Claw (Restoration). Check stats and availability in the client.")}
  local ap=armas.pasos
  ap[#ap+1]=Paso(alianza and 96264 or 79360,30,"Ayuda elemental","Elemental Aid","Derrota a Charlga Razorflank en Horado Rajacieno y recoge la información de la trama jabaespín.","Defeat Charlga Razorflank in Razorfen Kraul and collect information about the quilboar plot.",alianza and veyric or prate,nil,true)
  if not alianza then ap[#ap+1]=Paso(79364,30,"Ojos en el cielo","Eyes on the Sky","Consulta a Rau y sigue las instrucciones hacia Prate; verifica el diario para la entrega.","Speak to Rau and follow directions to Prate; check the quest log for turn-in.",rau,prate,false) end
  ap[#ap+1]=Paso(alianza and 79358 or 79361,30,"Tormenta, tierra y fuego","Storm, Earth, and Fire","Reúne cinco tótems retorcidos de cada elemento: fuego, tierra, aire y agua. Consulta el diario para localizar los objetivos.","Gather five twisted totems of each element: fire, earth, air and water. Consult the quest log for targets.",alianza and veyric or prate,alianza and veyric or prate,true)
  ap[#ap+1]=Paso(alianza and 96135 or 79366,30,"Escucha mi llamada","Heed My Call","Usa los tótems retorcidos para interrumpir el ritual jabaespín y consigue el Ojo de la Tempestad. Recomendado en grupo.","Use the twisted totems to stop the quilboar ritual and obtain the Eye of the Tempest. Group recommended.",alianza and veyric or prate,nil,true)
  ap[#ap+1]=Paso(armas.final,30,"Las armas de la tempestad","The Tempest's Weapons","Lleva el Ojo de la Tempestad a Bath'rah en Alterac. Elige el arma según tu especialización.","Bring the Eye of the Tempest to Bath'rah in Alterac. Choose the weapon for your spec.",alianza and veyric or rau,bath,false)
  r[#r+1]=armas
  -- La continuación 79365 exige nivel 100 en los datos actuales: no es una misión de leveo.
  -- Templo: 8410 y 8411 son alternativas, no dos encargos obligatorios.
  local inicio=alianza and 8411 or variante({8410,8411},8410)
  local st={clase="SHAMAN",nivel=50,titulo=I("Templo Sumergido: equipo opcional","Sunken Temple: optional gear"),final=8413,priorizarActiva=true,sinGuiado=alianza,
    nota=I("Completa la cadena para obtener equipo, no hechizos. Las fuentes recientes indican las tres recompensas: Azurite Fists, Wildstaff y Enamored Water Spirit. Confirma la recompensa en el diario.","Complete this chain for gear, not spells. Recent sources report all three rewards: Azurite Fists, Wildstaff and Enamored Water Spirit. Confirm rewards in the quest log."),pasos={}}
  if alianza then st.nota=st.nota..I(" Oferta para enanos discutida; referencia sin navegación hasta confirmar acceso."," Dwarf availability disputed; reference without navigation until confirmed.") end
  st.pasos[1]=Paso(inicio,50,inicio==8410 and "Maestría elemental" or "Dominar los elementos",inicio==8410 and "Elemental Mastery" or "Mastering the Elements","Consigue una unidad de aire, fuego, tierra y agua elementales. Consulta a Bath'rah; para Horda también hay instructores. 8410 y 8411 son alternativas.","Collect one each of Elemental Air, Fire, Earth and Water. Ask Bath'rah; Horde trainers are also an option. 8410 and 8411 are alternatives.",inicio==8411 and bath or nil,bath,true)
  if not alianza then st.pasos[1].opcionalInicio=true end
  st.pasos[2]=Paso(8412,50,"Tótem de espíritu","Spirit Totem","Consigue ocho ojos de araña inyectados en sangre y ocho garras negras gruesas de las criaturas de las Tierras de la Peste del Oeste.","Collect eight Bloodshot Spider Eyes and eight Thick Black Claws in Western Plaguelands.",bath,bath,true)
  st.pasos[3]=Paso(8413,50,"Vudú","Da Voodoo","Consigue dos plumas de vudú de cada color de los seis minijefes trols del Templo Sumergido y vuelve a Bath'rah.","Collect two of each Voodoo Feather color from the six troll minibosses in Sunken Temple and return to Bath'rah.",bath,bath,true)
  r[#r+1]=st
  r[#r+1]={clase="SHAMAN",nivel=37,titulo=I("Desafío del lobo del desierto (referencia)","Challenge of the Desert Wolf (reference)"),sinGuiado=true,final=95753,
    nota=I("Misión opcional de Tanaris, nivel de misión 45. Consulta el tótem extraño y sigue el diario. Oferta y recompensa exacta pendientes de prueba.","Optional Tanaris quest, quest level 45. Consult the Odd Totem and follow the quest log. Availability and exact reward pending verification."),pasos={Paso(95753,37,"Desafío del lobo del desierto","Challenge of the Desert Wolf","Referencia manual.","Manual reference.",nil,nil,true)}}
  -- B07: Scholomance, misión 60 disponible al 58; equipo opcional.
  local maestro=alianza and {1455,"Forjaz",47.1,13.8,"Eldrun Stormbreaker"} or {1454,"Orgrimmar",38.7,35.9,"Sagorne Creststrider"}
  local final=alianza and 97169 or variante({8258,7668},8258)
  local asistencia=alianza and 97168 or 7667
  local cielo={clase="SHAMAN",nivel=58,final=final,priorizarActiva=true,
    titulo=I("La amenaza de Atracoscuro (equipo opcional)","The Darkreaver Menace (optional gear)"),
    nota=I("Cadena de Scholomance de nivel 60, disponible desde el 58. Requiere dos diamantes y un grupo; elige una recompensa: Skyfury Helm o Skyfury Gauntlets. Compara sus estadísticas con tu equipo actual. Coordenadas de fuentes externas, pendientes de verificar en el cliente.","Level-60 Scholomance chain available at 58. Requires two diamonds and a group; choose Skyfury Helm or Skyfury Gauntlets. Compare their stats with your current gear. External coordinates, pending client verification."),pasos={}}
  cielo.pasos[1]=Paso(asistencia,58,"Asistencia material","Material Assistance","Entrega un diamante de Azeroth y un diamante negro prístino al instructor. No compres materiales sin confirmar la oferta y el precio.","Bring one Azerothian Diamond and one Pristine Black Diamond to the trainer. Confirm availability and cost before buying materials.",maestro,maestro,true)
  cielo.pasos[2]=Paso(final,58,"La amenaza de Atracoscuro","The Darkreaver Menace","Usa el arúspice en el sótano del Gran Osario de Scholomance, supera el evento de espíritus y derrota a Atracoscuro. Entrega su cabeza al instructor.","Use the Divination Scryer in the Great Ossuary basement in Scholomance, defeat the spirits and Darkreaver, then return his head to the trainer.",maestro,maestro,true)
  if raza=="Skyborne" then cielo.nota=cielo.nota..I(" Oferta racial no confirmada: consulta a Sagorne antes de adquirir los diamantes."," Racial availability unconfirmed: ask Sagorne before acquiring diamonds."); if not (Llevo(asistencia) or Hecha(asistencia) or Llevo(final) or Hecha(final)) then cielo.sinGuiado=true end end
  r[#r+1]=cielo
  if not alianza then
    r[#r+1]={clase="SHAMAN",nivel=58,final=7669,repetible=true,sinGuiado=true,
      titulo=I("De nuevo al Gran Osario (referencia)","Again Into the Great Ossuary (reference)"),
      nota=I("Referencia repetible para recuperar el arúspice tras Atracoscuro; consulta a Sagorne. No es otra misión de equipo obligatoria.","Repeatable reference to recover the Divination Scryer after Darkreaver; ask Sagorne. Not another mandatory gear quest."),
      pasos={Paso(7669,58,"De nuevo al Gran Osario","Again Into the Great Ossuary","Consulta al instructor; disponibilidad efectiva pendiente.","Ask the trainer; actual availability unconfirmed.",nil,nil,false)}}
  end
  return r
end

-- B05: misión cosmética, independiente de los rangos de Polimorfia normal.
local function CadenaCerdoMago()
  local function I(es,en) return GL.ingles and en or es end
  local function paso(q,es,en,notaES,notaEN)
    local wp={}
    for _,a in ipairs({"A","T"}) do
      wp[#wp+1]={q=q,a=a,m=1447,z="Azshara",x=29.2,y=40.2,npc="Archmage Xylem",n=I(es,en).." (Archmage Xylem)"}
    end
    return {q=q,n=I(es,en),nivel=60,nota=I(notaES,notaEN),objetivo=true,actitud=true,wp=wp}
  end
  return {clase="MAGE",nivel=60,final=9364,hechizos={28272},priorizarActiva=true,
    titulo=I("Polimorfia: cerdo (opcional)","Polymorph: Pig (optional)"),
    nota=I("Visita al archimago Xylem en Azshara. Usa Polimorfia normal (oveja), no tortuga, y conserva la concha de la primera misión. Recompensa cosmética, no mejora de rango. Coordenadas de referencia pendientes de prueba en cliente.","Visit Archmage Xylem in Azshara. Use regular sheep Polymorph, not Turtle, and keep the shell from the first quest. Cosmetic reward, not a rank upgrade. Reference coordinates pending client verification."),
    pasos={paso(9362,"Señor de la guerra Krellian","Warlord Krellian","Derrota a Krellian y entrega la concha al archimago Xylem.","Defeat Krellian and bring the shell to Archmage Xylem."),
      paso(9364,"Magia fragmentada","Fragmented Magic","Polimorfa nagas Spitelash y derrota los clones; consulta el contador real de la misión.","Polymorph Spitelash naga and defeat their clones; use the actual quest counter.")}}
end

-- B06: reutiliza destinos existentes, sin escribir las rutas ni inventar interiores.
local function CadenasMago(R)
  local r={CadenaCerdoMago()}
  if not R or R.clase~="MAGE" then return r end
  local raza=GL.Raza and GL.Raza(); local lado=Lado()
  local coincide=false; for _,v in ipairs(R.razas or {}) do if v==raza then coincide=true end end
  if not coincide then return {} end
  local alianza=R.id=="humano_mago" or R.id=="gnomo_mago" or R.id=="skyborne_a_mago"
  if alianza~=(lado=="A") then return {} end
  local function I(es,en) return GL.ingles and en or es end
  local destinos={}
  for _,sec in ipairs(R.secciones or {}) do for _,p in ipairs(sec.pasos or {}) do for _,w in ipairs(p.wp or {}) do
    if w.q and (not w.raza or w.raza==raza) and (w.a=="A" or w.a=="T") then
      local d=destinos[w.q] or {}; destinos[w.q]=d; if not d[w.a] then d[w.a]=w end
    end
  end end end
  local function P(q,n,es,en,nes,nen,manual)
    local d=destinos[q] or {};local wp={}
    if not manual then for _,a in ipairs({"A","T"}) do if d[a] then wp[#wp+1]=d[a] end end end
    return {q=q,n=I(es,en),nivel=n,nota=I(nes,nen),wp=wp,actitud=true,objetivo=true,referencia=manual}
  end
  local function C(n,es,en,nes,nen,pasos,hechizos)
    local c={clase="MAGE",nivel=n,titulo=I(es,en),nota=I(nes,nen),pasos=pasos,final=pasos[#pasos].q,hechizos=hechizos,priorizarActiva=true}
    r[#r+1]=c;return c
  end
  local inicial={
    Human={1860,1861,"Habla con Jennea","Speak with Jennea","Lago Espejo","Mirror Lake"},
    Gnome={1879,1880,"Habla con Bink","Speak with Bink","Trastónitor maguitronic","Mage-tastic Gizmonitor"},
    Scourge={1881,1882,"Habla con Anastasia","Speak with Anastasia","La hacienda Balnir","The Balnir Farmstead"},
    Orc={1883,1884,"Habla con Un'thuwa","Speak with Un'thuwa","Montones de juju","Ju-Ju Heaps"},
    Troll={1883,1884,"Habla con Un'thuwa","Speak with Un'thuwa","Montones de juju","Ju-Ju Heaps"},
    Skyborne={93791,93797,"Habla con Belann","Speak with Belann","Ramas en el viento","Boughs in the Wind"},
  }
  local v=inicial[raza]
  if v then
    local c=C(10,"Equipo inicial de mago (opcional)","Early mage gear (optional)",raza=="Skyborne" and "Recompensa: Windbough Wand." or "Elige bastón u orbe según tu equipo; no es una facultad.",raza=="Skyborne" and "Reward: Windbough Wand." or "Choose a staff or orb based on your gear; not a spell.",{
      P(v[1],10,v[3],v[4],"Consulta al instructor de mago de tu raza.","Ask your racial mage trainer."),
      P(v[2],10,v[5],v[6],"Sigue los objetivos del diario y regresa al instructor.","Follow the quest log objectives and return to the trainer.")})
    c.pasos[1].opcionalInicio=true
  end
  -- Conservar las cadenas existentes, copiarlas antes de adaptar sus campos.
  for _,orig in ipairs((GL.D94 and GL.D94.clase) or {}) do
    local q=orig.pasos and orig.pasos[1] and orig.pasos[1].q
    local permite=orig.razas==0 or (raza~="Skyborne" and (DeMiRaza(orig.razas) or (raza=="Orc" and lado=="H")))
    if orig.clase=="MAGE" and orig.lado==lado and permite then
      local c={};for k,v in pairs(orig) do c[k]=v end;c.pasos={};c.priorizarActiva=true
      for _,p in ipairs(orig.pasos) do
        local t={};for k,v in pairs(p) do t[k]=v end;t.n=I(p.n,p.ing or p.n);t.nivel=c.nivel;t.actitud=true;t.objetivo=true
        c.pasos[#c.pasos+1]=t
      end
      c.pasos[1].opcionalInicio=true;c.final=c.pasos[#c.pasos].q
      if q==1947 then
        local t=P(1948,30,"Objetos de poder","Items of Power","Entrega un jade y la zarza cargada a Tabetha. Comprueba los requisitos antes de gastar oro.","Bring a Jade and the Bolt Charged Bramble to Tabetha. Check requirements before spending gold.")
        if #t.wp==0 then for _,w in ipairs(c.pasos[2].wp or {}) do if w.a=="A" then for _,a in ipairs({"A","T"}) do local d={};for k,v in pairs(w) do d[k]=v end;d.q=1948;d.a=a;d.n=I("Objetos de poder (Tabetha)","Items of Power (Tabetha)");t.wp[#t.wp+1]=d end end end end
        table.insert(c.pasos,2,t)
        local spec=nil
        local db=GuiaAventureroDB or {};spec=db.especializacion or spec
        local reward=({Arcano="Nether Force Wand",Fuego="Ragefire Wand",Escarcha="Icefury Wand"})[spec]
        c.titulo=I("Varitas de mago (opcional)","Mage's Wand (optional)")
        c.nota=I("Elige una varita: Nether Force Wand (Arcano), Ragefire Wand (Fuego) o Icefury Wand (Escarcha). Requiere el libro de la Biblioteca del Monasterio Escarlata.","Choose a wand: Nether Force Wand (Arcane), Ragefire Wand (Fire) or Icefury Wand (Frost). Requires the Scarlet Monastery Library book.")..(reward and I(" Recomendada: "," Recommended: ")..reward or "")
      elseif q==1953 then c.titulo=I("Poder celestial (opcional)","Celestial Power (optional)");c.nota=I("Bastón u orbe; requiere grupo para Uldaman. Confirma la recompensa en el diario.","Staff or orb; requires an Uldaman group. Confirm the quest reward in the log.")
      else
        c.titulo=I(orig.titulo,orig.pasos[#orig.pasos].ing)..I(" (opcional)"," (optional)")
        c.nota=I("Equipo opcional; confirma la oferta de tu instructor y los materiales en el diario.","Optional gear; confirm trainer availability and materials in the quest log.")
        if raza=="Orc" and q==1943 then c.sinGuiado=true;c.nota=c.nota..I(" Oferta racial pendiente."," Racial availability unconfirmed.") end
      end
      r[#r+1]=c
    end
  end
  C(6,"Estudiar: biblioteca","Study: library",
    "Aprende Comprender pergamino al nivel 6 antes de entregar un libro. Lleva un libro de biblioteca al bibliotecario de tu facción (torre de magos de Ventormenta o Entrañas). Completa Acceso a la investigación. Estudiar consume una pluma ligera y crea un lote de pergaminos en la biblioteca, una vez por hora. La oferta exacta y el acceso racial requieren confirmación.",
    "Train Comprehend Scroll at level 6 before turning in a book. Bring a library book to your faction librarian (Stormwind mage tower or Undercity). Complete Research Access. Study consumes a Light Feather and creates a scroll bundle at the library, once per hour. Exact quest availability and racial access need confirmation.",
    {P(97286,6,"Acceso a la investigación","Research Access","Consulta al bibliotecario tras aprender Comprender pergamino y entregar el primer libro.","Ask the librarian after learning Comprehend Scroll and donating your first book.",true)},{1302508})
  C(42,"Libro de hechizos personal (opcional)","Personal Spellbook (optional)",
    "Recompensa: Personal Spellbook (#221344). Consigue una pluma prístina de lechúcico de Tierras del Interior y resina silítida; consulta los materiales restantes y el PNJ de tu facción en el diario.",
    "Reward: Personal Spellbook (#221344). Obtain a pristine owlbeast quill in the Hinterlands and silithid resin; check remaining materials and your faction NPC in the quest log.",
    {P(82084,42,"Una lección de alfabetización","A Lesson in Literacy","Confirma el instructor y los requisitos de la misión antes de reunir materiales.","Confirm the quest giver and requirements before collecting materials.",true)})
  local st=C(50,"Templo Sumergido: equipo opcional","Sunken Temple: optional gear",
    "Cadena desde nivel 50. Recompensas documentadas: Glacial Spike, Arcane Crystal Pendant y Fire Ruby. Las fuentes discrepan sobre si se elige una o se reciben todas; comprueba el diario. Último paso en grupo.",
    "Chain from level 50. Documented rewards: Glacial Spike, Arcane Crystal Pendant and Fire Ruby. Sources disagree whether you choose one or receive all; check the quest log. Final step requires a group.",{
    P(8250,50,"Artesanía mágica","Magecraft","Consulta al instructor de mago y viaja a Azshara.","Ask your mage trainer and travel to Azshara.",true),
    P(8251,50,"Polvo mágico","Magic Dust","Recoge el polvo de los elfos de sangre de Azshara y vuelve a Xylem.","Collect dust from Azshara blood elves and return to Xylem.",true),
    P(8252,50,"El coral de las sirenas","The Siren's Coral","Recoge el coral de las sirenas de Azshara y vuelve a Xylem.","Collect coral from the sirens of Azshara and return to Xylem.",true),
    P(8253,50,"Destruye a Morphaz","Destroy Morphaz","Consigue el fragmento arcano de Morphaz en el Templo Sumergido y vuelve a Xylem.","Retrieve the Arcane Shard from Morphaz in Sunken Temple and return to Xylem.",true)})
  st.pasos[1].opcionalInicio=true
  C(60,"El refresco arcano","Arcane Refreshment","Aprende Conjurar agua VII. Habla con el erudito Lydros en La Masacre (biblioteca), derrota a Hydrospawn en el ala este y regresa. Sin coordenadas interiores verificadas.","Learn Conjure Water rank 7. Speak with Lorekeeper Lydros in the Dire Maul library, defeat Hydrospawn in the east wing and return. Interior coordinates unverified.",{P(7463,60,"El refresco arcano","Arcane Refreshment","Consulta la oferta y completa la misión en grupo.","Check availability and complete the quest with a group.",true)},{10140})
  return r
end

-- B05: desbloqueos independientes; no se presupone que una forma sayaad enseña la otra.
local function CadenasBrujo(R)
  local r={};if not R or R.clase~="WARLOCK" then return r end
  local lado=Lado();local en=GL.ingles
  local function I(es,ing) return en and ing or es end
  local function P(q,n,es,ing,nota)
    return {q=q,n=I(es,ing),nivel=n,nota=nota,objetivo=true,actitud=true,referencia=true,wp={}}
  end
  local function C(n,es,ing,id,pasos,nota)
    r[#r+1]={clase="WARLOCK",nivel=n,titulo=I(es,ing),nota=nota,hechizos={id},pasos=pasos,final=pasos[#pasos].q,priorizarActiva=true}
  end
  local humano=R.id=="humano_brujo";local gnomo=R.id=="gnomo_brujo";local noMuerto=R.id=="nomuerto_brujo"
  if (humano or gnomo)~=(lado=="A") then return r end
  local imp=humano and 1598 or gnomo and 1599 or noMuerto and 1470 or 1485
  C(1,"Diablillo","Imp",688,{P(imp,1,"Misión inicial del diablillo","Starting Imp quest",I("Consulta al instructor de tu zona inicial.","Ask the trainer in your starting zone."))},I("Disponible desde el nivel 1; la misión puede mostrar nivel 3 o 4.","Available from level 1; quest may display level 3 or 4."))
  local finales={[1689]=697,[1471]=697,[1504]=697,[1739]=712,[1474]=712,[1513]=712,[1795]=691}
  for _,orig in ipairs((GL.D94 and GL.D94.clase) or {}) do
    if orig.clase=="WARLOCK" and (not orig.lado or orig.lado==lado) and DeMiRaza(orig.razas) then
      local c={};for k,v in pairs(orig) do c[k]=v end
      local ultimo=orig.pasos[#orig.pasos].q;local id=finales[ultimo]
      if id then
        c.pasos={};for _,p in ipairs(orig.pasos) do local t={};for k,v in pairs(p) do t[k]=v end;t.n=I(p.n,p.ing or p.n);t.objetivo=true;t.actitud=true;c.pasos[#c.pasos+1]=t end
        c.final=ultimo;c.hechizos={id};c.priorizarActiva=true;c.pasos[1].opcionalInicio=true
        c.titulo=I(orig.titulo,id==697 and "Voidwalker" or id==712 and "Succubus" or "Felhunter")
        c.nota=I("Cadena de invocación; confirma oferta y posiciones con el diario de Forever.","Summoning chain; verify quest availability and locations in Forever.")
      end
      if ultimo~=4490 and ultimo~=7631 then r[#r+1]=c end
    end
  end
  local pasos
  if lado=="A" then pasos={P(1716,20,"Devoradora de almas","Devourer of Souls"),P(65602,20,"¿Qué es el amor?","What Is Love?"),P(65603,20,"El vínculo (íncubo)","The Binding (Incubus)")}
  elseif noMuerto then pasos={P(1472,20,"Devoradora de almas","Devourer of Souls"),P(65593,20,"Corazones de los amantes","Hearts of the Lovers"),P(65597,20,"El vínculo (íncubo)","The Binding (Incubus)")}
  else pasos={P(1507,20,"Devoradora de almas","Devourer of Souls"),P(65601,20,"El amor duele","Love Hurts"),P(65610,20,"Ojalá estuvieras aquí","Wish You Were Here"),P(65604,20,"El vínculo (íncubo)","The Binding (Incubus)")} end
  pasos[1].opcionalInicio=true
  C(20,"Íncubo","Incubus",713,pasos,I("Cadena alternativa del sayaad. Puedes aprender ambas invocaciones; si tu instructor no ofrece la segunda, consulta la otra rama disponible. Oferta racial y coordenadas pendientes de verificación.","Alternative Sayaad chain. Both summons can be learned; if your trainer does not offer the second, check the other available branch. Racial availability and coordinates unverified."))
  C(50,"Infernal","Infernal",1122,{P(7601,50,"Lo que Niby ordena","What Niby Commands"),P(7602,50,"Esencia vil impecable","Flawless Fel Essence"),P(7603,50,"El núcleo infernal de Kroshius","Kroshius' Infernal Core")},I("Niby e Impsy, Frondavil. Comprueba los objetivos y el acceso; requiere Piedra infernal al lanzar.","Niby and Impsy, Felwood. Check objectives and access; casting requires Infernal Stone."))
  C(60,"Guardia apocalíptico","Doomguard",18540,{P(7581,60,"Las ataduras de la prisión","The Prison's Bindings"),P(7582,60,"La carcasa de la prisión","The Prison's Casing"),P(7583,60,"Supresión","Suppression")},I("Daio en Tierras Devastadas. Completa ambos preparativos (en cualquier orden); el ritual requiere grupo y puede sacrificar a un participante.","Daio in Blasted Lands. Complete both preparations (either order); ritual needs a group and may sacrifice a participant."))
  -- B06: las monturas viven en Colecciones; la misión hecha no certifica equitación aprendida.
  local function activo(q) return Hecha(q) or Llevo(q) end
  local function alternativa(ids,preferido)
    for _,q in ipairs(ids) do if activo(q) then return q end end
    return preferido
  end
  local function E(n,es,ing,ps,nota)
    local c={clase="WARLOCK",nivel=n,titulo=I(es,ing),nota=nota,pasos=ps,final=ps[#ps].q,priorizarActiva=true}
    r[#r+1]=c;return c
  end
  local function punto(p,m,x,y,z,npc,soloA)
    local function w(a) return {a=a,q=p.q,m=m,x=x,y=y,z=z,n=I(a=="A" and "Recoger: " or "Entregar: ",a=="A" and "Accept: " or "Turn in: ")..p.n.." ("..npc..")"} end
    p.wp={w("A")};if not soloA then p.wp[2]=w("T") end;p.referencia=nil;return p
  end
  local q40=alternativa(lado=="A" and {4487,4488} or {3631,4489},humano and 4488 or gnomo and 4487 or noMuerto and 4489 or 3631)
  local inicio=P(q40,40,"Invoca un malignoecus (inicio)","Summon Felsteed (introduction)",I("Consulta al instructor de tu facción; solo necesitas una introducción.","Ask your faction trainer; only one introduction is needed."));inicio.opcionalInicio=true
  local m40=E(40,"Montura: Corcel vil","Mount: Felsteed",{inicio,punto(P(4490,40,"Invoca un malignoecus","Summon Felsteed"),1413,62.6,35.5,"Los Baldíos","Strahad Farsan")},I("Montura en Colecciones. Corrección del 9/11: concede equitación de aprendiz; si terminaste antes, invoca el corcel una vez. Si aún falta, consulta soporte.","Mount in Collections. Nov 9 fix: grants Apprentice Riding; if completed earlier, summon the mount once. If still missing, contact support."));m40.montura=5784
  local epic={P(7562,58,"Mor'zul Sangredoble","Mor'zul Bloodbringer",I("Consulta a un instructor; después viaja a Estepas Ardientes.","Ask a trainer, then travel to Burning Steppes.")),
    punto(P(7563,58,"La ira de sangre","Rage of Blood"),1428,12.7,31.6,"Las Estepas Ardientes","Mor'zul Bloodbringer"),
    P(7564,58,"Ojosalvajes","Wildeyes"),P(7623,58,"Lord Banehollow","Lord Banehollow"),P(7624,58,"Ulathek el traidor","Ulathek the Traitor"),P(7625,58,"Polvo estelar de Xoroth","Xorothian Stardust"),
    P(7626,60,"Campana de Dethmoora","Bell of Dethmoora"),P(7627,60,"Rueda de la Marcha Negra","Wheel of the Black March"),P(7628,60,"Vela del Juicio Final","Doomsday Candle"),
    P(7629,60,"Entrega de diablillo","Imp Delivery",I("Entrega del diablillo en Scholomance; confirma el laboratorio y la entrega en el diario.","Imp delivery in Scholomance; verify the lab and turn-in in the quest log.")),
    P(7630,60,"Arcanita","Arcanite",I("Tres barras de arcanita; confirma que las otras preparaciones estén completas.","Three Arcanite Bars; verify the other preparations are complete.")),
    punto(P(7631,60,"Terrorecus de Xoroth","Dreadsteed of Xoroth",I("Final: ritual en La Masacre oeste, en grupo; habla con el espíritu del corcel tras vencerlo.","Final: ritual in Dire Maul West, with a group; speak to the steed spirit after defeating it.")),1428,12.7,31.6,"Las Estepas Ardientes","Mor'zul Bloodbringer",true)}
  epic[1].opcionalInicio=true
  local m60=E(58,"Montura épica: Corcel nefasto","Epic mount: Dreadsteed",epic,I("Preparación desde 58; final al 60. Las preparaciones pueden solaparse, verifica requisitos y materiales antes de gastar. Corrección 25/11: equitación avanzada; si ya completaste 7631, habla con ","Preparation from 58; finish at 60. Preparations may overlap, check requirements and materials before spending. Nov 25 fix: Journeyman Riding; if 7631 already completed, speak to ")..(lado=="A" and I("Ursula Deline, El Cordero Degollado (Ventormenta).","Ursula Deline, Slaughtered Lamb (Stormwind).") or I("Zevrost, Caverna de las Sombras (Orgrimmar).","Zevrost, Cleft of Shadow (Orgrimmar).")));m60.montura=23161;m60.epica=true
  E(20,"Orbe de Soran'ruk (opcional)","Orb of Soran'ruk (optional)",{P(1740,20,"El orbe de Soran'ruk","The Orb of Soran'ruk")},I("Doan Karhan en Los Baldíos: tres fragmentos en Cavernas de Brazanegra y uno grande en Castillo de Colmillo Oscuro. Elige la recompensa según tu equipo; no es un desbloqueo de hechizo.","Doan Karhan in the Barrens: three fragments in Blackfathom Deeps and one large fragment in Shadowfang Keep. Choose the reward based on gear; not a spell unlock."))
  local rb={P(1796,31,"Componentes de la toga de sangre de oro encantado","Components for the Enchanted Gold Bloodrobe")}
  for _,q in ipairs({4781,4782,4783,4784}) do rb[#rb+1]=P(q,31,"Componentes de la toga","Components for the Enchanted Gold Bloodrobe") end
  rb[#rb+1]=P(4786,31,"La toga terminada","The Completed Robe")
  E(31,"Toga de sangre (opcional)","Enchanted Gold Bloodrobe (optional)",rb,I("Consulta a Menara Voidrender en Trinquete; una introducción 4736–4739 puede enviarte allí. Confirma los materiales de cada entrega; hilo de oro fino (4785) si hace falta. No compres materiales de toda la cadena sin revisar tu equipo.","Ask Menara Voidrender in Ratchet; an introduction 4736–4739 can send you there. Check materials for each hand-in; Fine Gold Thread (4785) if needed. Do not buy all materials without checking your gear."))
  local orb={P(1799,35,"Fragmentos del orbe de Orahil","Fragments of the Orb of Orahil",I("Antes de entregar, elige una rama de fragmento (4962 o 4963), no ambas.","Before turning in, choose one shard branch (4962 or 4963), not both."))}
  local fel=activo(4962) or activo(4964);local inf=activo(4963) or activo(4975)
  if fel and not inf then orb[#orb+1]=P(4962,35,"Fragmento de un manáfago","Shard of a Felhound")
  elseif inf and not fel then orb[#orb+1]=P(4963,35,"Fragmento de un infernal","Shard of an Infernal") end
  orb[#orb+1]=P(4961,35,"Purificación del orbe de Orahil","Cleansing of the Orb of Orahil");orb[#orb+1]=P(4976,35,"Devolver el orbe purificado","Returning the Cleansed Orb")
  if fel and not inf then orb[#orb+1]=P(4964,35,"Orbe de Dar'Orahil terminado","The Completed Orb of Dar'Orahil") elseif inf and not fel then orb[#orb+1]=P(4975,35,"Orbe de Noh'Orahil terminado","The Completed Orb of Noh'Orahil") end
  local co=E(35,"Orbe de Orahil (opcional)","Orb of Orahil (optional)",orb,I("Introducción de instructor 4965/4967/4968/4969 según ciudad. Menara y Tabetha; la decisión manáfago (Dar'Orahil, Sombras) o infernal (Noh'Orahil, Fuego) es excluyente. Revisa recompensa antes de elegir. Hasta elegir no se muestra una rama final obligatoria.","Trainer introduction 4965/4967/4968/4969 by city. Menara and Tabetha; Felhound (Dar'Orahil, Shadow) or Infernal (Noh'Orahil, Fire) is an exclusive choice. Check reward before choosing. No mandatory final branch until selected."));co.finalAlternativos={4964,4975};co.final=nil;co.incompleta=true
  local st={P(alternativa({8419,8420},8419),50,"Encargo de Impsy (introducción)","Impsy's request (introduction)",I("Una sola introducción: 8419 o 8420 según oferta.","Only one introduction: 8419 or 8420 depending on availability.")),
    punto(P(8421,50,"Los materiales equivocados","The Wrong Stuff",I("10 maderas podridas y 4 esencias de veneno de sangre.","10 Rotting Wood and 4 Bloodvenom Essence.")),1448,41.4,45,"Frondavil","Impsy"),
    punto(P(8422,50,"Plumas de trol","Trolls of a Feather",I("Dos plumas de cada uno de los tres colores de los seis minijefes del Templo Sumergido.","Two feathers of each of the three colors from six Sunken Temple minibosses.")),1448,41.4,45,"Frondavil","Impsy")}
  st[1].opcionalInicio=true
  E(50,"Templo Sumergido: equipo opcional","Sunken Temple: optional gear",st,I("Recompensas documentadas: 20536, 20534 y 20530. Las fuentes discrepan sobre elección o las tres; comprueba el diario.","Documented rewards: 20536, 20534 and 20530. Sources disagree whether you choose one or receive all; check the quest log."))
  return r
end

-- B05: separar las cuatro variantes raciales; no alterar los archivos de ruta.
local function CadenasDruida(R)
  local r={};if not R or R.clase~="DRUID" then return r end
  local lado=Lado();local alianza=R.id=="elfo_druida" or R.id=="skyborne_a_druida"
  if alianza~=(lado=="A") then return r end
  local sky=R.id=="skyborne_a_druida" or R.id=="skyborne_druida"
  local function I(es,en) return GL.ingles and en or es end
  local function copia(t) local v={};for k,x in pairs(t) do v[k]=x end;return v end
  local wp={}
  for _,sec in ipairs(R.secciones or {}) do for _,p in ipairs(sec.pasos or {}) do for _,w in ipairs(p.wp or {}) do
    if w.q and (w.a=="A" or w.a=="C" or w.a=="T") then
      wp[w.q]=wp[w.q] or {};local t=wp[w.q];if not t[w.a] then t[w.a]=w end
    end
  end end end
  local function P(q,n,es,en,nota,original)
    local p={q=q,n=I(es,en),nivel=n,nota=nota,wp={},objetivo=true,actitud=true}
    local t=wp[q] or {}
    for _,a in ipairs({"A","C","T"}) do
      local w=t[a]
      if not w and original then for _,v in ipairs(original.wp or {}) do if v.a==a then w=v;break end end end
      if w then local x=copia(w);x.q=q;p.wp[#p.wp+1]=x end
    end
    if #p.wp==0 then p.referencia=true end
    return p
  end
  local function C(n,es,en,ids,ps,nota)
    local c={clase="DRUID",nivel=n,titulo=I(es,en),hechizos=ids,pasos=ps,final=ps[#ps].q,nota=nota,priorizarActiva=true}
    r[#r+1]=c;return c
  end
  if sky then
    C(10,"Forma de oso","Bear Form",{5487,6807,6795},{P(94006,10,"El gran espíritu ursera","The Great Ursera Spirit"),P(94638,10,"Fuerza y piedad","Strength and Mercy")},I("Isla Zephras: completa las dos misiones raciales. Comprueba las facultades concedidas en el libro.","Zephras Isle: complete both racial quests. Check awarded abilities in your spellbook."))
    C(10,"Teletransporte: Claro de la Luna","Teleport: Moonglade",{18960},{P(alianza and 94912 or 94911,10,"Hijo de la naturaleza","Child of Nature"),P(alianza and 94914 or 94913,10,"Claro de la Luna","Moonglade")},I("Tras llegar al continente, acepta Claro de la Luna para aprender el teletransporte. Confirma el instructor que te ofrece la introducción.","After reaching the mainland, accept Moonglade to learn the teleport. Confirm the trainer offering the introduction."))
    -- La introducción de Alianza tiene fuentes discrepantes: no indicar un PNJ sin verificar.
    if alianza then r[#r].pasos[1].wp={};r[#r].pasos[1].referencia=true end
  end
  for _,orig in ipairs((GL.D94 and GL.D94.clase) or {}) do
    if orig.clase=="DRUID" and orig.lado==lado and not (sky and orig.nivel==10) then
      local ps={};for i,t in ipairs(orig.pasos) do
        local q=t.q
        if orig.nivel==16 and i==1 then q=alianza and 26 or 27 end
        local paso=P(q,t.nivel,t.n,t.ing or t.n,nil,t)
        -- El primer paso acuático estaba invertido; conservar sus PNJ, corregir ID.
        if orig.nivel==16 and i==1 then paso.wp={};for _,w in ipairs(t.wp or {}) do local x=copia(w);x.q=q;paso.wp[#paso.wp+1]=x end end
        ps[#ps+1]=paso
      end
      local ids=orig.nivel==10 and {5487,6807,6795,18960} or orig.nivel==14 and {8946} or {1066}
      local c=C(orig.nivel,orig.titulo,orig.nivel==10 and "Bear Form" or orig.nivel==14 and "Cure Poison" or "Aquatic Form",ids,ps,I("Completa la cadena de tu facción; usa el diario para comprobar los objetivos y la recompensa.","Complete your faction chain; check objectives and reward in the quest log."))
      if orig.nivel==10 then ps[1].opcionalInicio=true end
      if sky and orig.nivel==14 then c.nota=I("Skyborne: cadena de tu facción. Comprueba si el instructor racial ofrece la introducción; el final enseña Curar veneno.","Skyborne: faction chain. Check whether your racial trainer offers the introduction; the final quest teaches Cure Poison.");ps[1].wp={};ps[1].referencia=true end
    end
  end
  local cat={}
  if alianza then cat[#cat+1]=P(98393,20,"El gran espíritu felino","The Great Cat Spirit") else cat[#cat+1]=P(98340,20,"El gran espíritu felino","The Great Cat Spirit") end
  cat[1].opcionalInicio=true
  if sky then
    cat[#cat+1]=P(98341,20,"El gran espíritu felino del viento","The Great Windborne Cat Spirit")
    cat[#cat+1]=P(98404,20,"El gran espíritu felino del viento","The Great Windborne Cat Spirit",I("Recoge las tres reliquias en el túmulo.","Collect the three relics in the den."))
    cat[#cat+1]=P(98738,20,"Bendiciones del gran espíritu felino del viento","Blessings of the Great Windborne Cat Spirit")
  else
    cat[#cat+1]=P(alianza and 98394 or 98405,20,"El gran espíritu felino","The Great Cat Spirit")
    cat[#cat+1]=P(alianza and 98396 or 98342,20,"El gran espíritu felino","The Great Cat Spirit",I("Recoge las tres reliquias en el túmulo.","Collect the three relics in the den."))
    cat[#cat+1]=P(alianza and 98731 or 98739,20,"Bendiciones del gran espíritu felino","Blessings of the Great Cat Spirit")
  end
  cat[#cat+1]=P(alianza and 98397 or 98362,20,alianza and "A Darnassus" or "A Cima del Trueno",alianza and "To Darnassus" or "To Thunder Bluff")
  C(20,"Forma felina","Cat Form",{768},cat,I("Cadena nueva de Forever. Usa Teletransporte: Claro de la Luna; las reliquias se recogen en el túmulo. Los destinos proceden de la ruta existente, no de posiciones verificadas en esta sesión.","New Forever chain. Use Teleport: Moonglade; collect the relics in the den. Waypoints come from the existing route, not positions verified this session."))
  -- Equipo opcional: no marcar como desbloqueo de facultad.
  local guardian=P(81924,40,"Sabiduría de los guardianes","Wisdom of the Guardians")
  C(40,"Sabiduría de los guardianes (opcional)","Wisdom of the Guardians (optional)",nil,{guardian},I("Tyrisius en Feralas (aprox. 57,69): supera las pruebas de los guardianes de Feralas, Azshara y Tierras del Interior. Recompensa documentada Semilla de renovación; confirma el objeto y su funcionamiento en el cliente.","Tyrisius in Feralas (approx. 57,69): complete the guardian trials in Feralas, Azshara and the Hinterlands. Documented Seed of Renewal reward; verify the item and its function in the client."))
  local torwa={P(9063,50,"Torwa Abrecaminos","Torwa Pathfinder"),P(9052,50,"Veneno de pétalo de sangre","Bloodpetal Poison"),P(9051,50,"Prueba de toxicidad","Toxic Test"),P(9053,50,"Un ingrediente mejor","A Better Ingredient")}
  -- La introducción de las rutas puede dirigir a Cima del Trueno incluso en Alianza. No reutilizar ese destino.
  torwa[1].wp={};torwa[1].referencia=true;torwa[1].opcionalInicio=true
  torwa[3].nota=I("Usa la púa de Torwa contra un demosaurio compatible; revisa el objetivo en el diario.","Use Torwa's barb on an eligible Devilsaur; check the quest log objective.")
  torwa[4].nota=I("Derrota a Atal'alarion en el Templo Sumergido y recupera la liana pútrida.","Defeat Atal'alarion in Sunken Temple and retrieve the Putrid Vine.")
  C(50,"Templo Sumergido: equipo (opcional)","Sunken Temple: gear (optional)",nil,torwa,I("Torwa en Un'Goro (71.6,76). Recompensas documentadas: Grizzled Pelt, Forest's Embrace y Moonshadow Stave. Comprueba si el diario entrega todas o exige elegir; valora según tu rol.","Torwa in Un'Goro (71.6,76). Documented rewards: Grizzled Pelt, Forest's Embrace and Moonshadow Stave. Check whether the quest awards all or requires a choice; assess for your role."))
  local libro=P(7506,54,"El Sueño Esmeralda...","The Emerald Dream...")
  C(54,"La Masacre: libro de clase (opcional)","Dire Maul: class book (optional)",nil,{libro},I("Consigue el libro El Sueño Esmeralda y entrégalo en el Ateneo de La Masacre. Recompensa documentada Sello real de Eldre'Thalas (18470). Comprueba disponibilidad y requisitos de acceso.","Obtain The Emerald Dream book and turn it in at the Dire Maul Athenaeum. Documented Royal Seal of Eldre'Thalas reward (18470). Check availability and access requirements."))
  table.sort(r,function(a,b) if a.nivel~=b.nivel then return a.nivel<b.nivel end;return a.final<b.final end)
  return r
end

local function HabilidadesAprendidas(c)
  if c.habilidad and GL.NivelProfesion then
    local ok,n=pcall(GL.NivelProfesion,{skill=c.habilidad,nombre=GL.ingles and "Poisons" or "Venenos"})
    if ok and type(n)=="number" and n>0 then return true end
  end
  if c.montura and GL.MonturaConocidaPorHechizo and GL.MonturaConocidaPorHechizo(c.montura) then return true end
  if not c.hechizos or not GL.HechizoConocido then return false end
  local conocido = GL.HechizoORangoConocido or GL.HechizoConocido
  for _, id in ipairs(c.hechizos) do if not conocido(id) then return false end end
  return true
end

-- Las cadenas que te tocan: tu clase, tu facción y tu raza (las de raza concreta van antes que las generales).
function GL.CadenasDeClase(clase)
  local objetivo = clase or Clase()
  local r, lado = {}, Lado()
  -- No ofrecer cadenas de otra facción durante la carga del personaje.
  if not lado or not objetivo then return r end
  if objetivo == "PALADIN" then return CadenasPaladin(GL.RUTA) end
  if objetivo == "HUNTER" then return CadenasCazador(GL.RUTA) end
  if objetivo == "ROGUE" then return CadenasPicaro(GL.RUTA) end
  if objetivo == "PRIEST" then return CadenasSacerdote(GL.RUTA) end
  if objetivo == "SHAMAN" then return CadenasChaman(GL.RUTA) end
  if objetivo == "MAGE" then return CadenasMago(GL.RUTA) end
  if objetivo == "WARLOCK" then return CadenasBrujo(GL.RUTA) end
  if objetivo == "DRUID" then return CadenasDruida(GL.RUTA) end
  if objetivo == "WARRIOR" then r = CadenasActitudes(GL.RUTA) end
  for _, c in ipairs((GL.D94 and GL.D94.clase) or {}) do
    local q = c.pasos and c.pasos[1] and c.pasos[1].q
    local actitudGenerica = c.clase == "WARRIOR" and (q == 1639 or q == 1505 or q == 1718)
    if not actitudGenerica and c.clase == objetivo and (not c.lado or c.lado == lado) and DeMiRaza(c.razas) then table.insert(r, c) end
  end
  return r
end

-- El destino siguiente de un paso: entregar si la llevas, recoger si no.
local function DestinoPaso(p)
  local quiero = Llevo(p.q) and "T" or "A"
  if quiero=="T" and p.objetivo then
    if not ObjetivoListo(p.q) then
      -- Si no hay destino de objetivo, no caer en el primer waypoint (puede ser la entrega).
      for _, w in ipairs(p.wp or {}) do if w.a == "C" then return w end end
      return nil
    end
  end
  for _, w in ipairs(p.wp or {}) do if w.a == quiero then return w end end
  if not p.actitud then return p.wp and p.wp[1] end
end

local function EstadoCadena(c)
  local hechas = 0
  for _, p in ipairs(c.pasos) do if Hecha(p.q) then hechas = hechas + 1 end end
  return hechas, #c.pasos
end

local function Filas()
  local filas = {}
  local cadenas = GL.CadenasDeClase()
  for _, c in ipairs(cadenas) do
    local hechas, total = EstadoCadena(c)
    if c.repetible then hechas=0 end
    local aprendidas = HabilidadesAprendidas(c)
    local finalHecho = c.final and Hecha(c.final)
    for _,q in ipairs(c.finalAlternativos or {}) do if Hecha(q) then finalHecho=true;break end end
    local objetoPresente=c.objetoTotem and GL.TotemChamanEnBolsas(c.objetoTotem)
    local notaObjeto=""
    if c.objetoTotem then
      if objetoPresente==true then notaObjeto=GL.ingles and "Totem in bags. " or "Tótem en las bolsas. "
      elseif objetoPresente==false then notaObjeto=GL.ingles and "Totem missing from bags; check bank or trainer if already completed. " or "Tótem ausente de las bolsas; revisa el banco o instructor si ya lo completaste. "
      else notaObjeto=GL.ingles and "Bag status unknown. " or "Estado de bolsas desconocido. " end
    end
    local previo = c.requiereCadena
    local bloqueado = previo and not (HabilidadesAprendidas(previo) or (previo.final and Hecha(previo.final))) and not Llevo(c.pasos[1].q)
    if bloqueado and c.clase=="SHAMAN" then
      for _,p in ipairs(c.pasos) do if Llevo(p.q) or Hecha(p.q) then bloqueado=false;break end end
    end
    local porNivel = (c.clase=="PALADIN" or c.clase=="HUNTER" or c.clase=="ROGUE" or c.clase=="PRIEST" or c.clase=="SHAMAN" or c.clase=="MAGE" or c.clase=="WARLOCK" or c.clase=="DRUID") and Nivel()<c.nivel
    local siguiente, inicioSuperado
    for i, p in ipairs(c.pasos) do
      if i > 1 and (Hecha(p.q) or Llevo(p.q)) then inicioSuperado = true end
    end
    if c.epica or c.objetoTotem or c.priorizarActiva then
      for _, p in ipairs(c.pasos) do
        if Llevo(p.q) then siguiente = p; break end
      end
    end
    if not siguiente then
      for _, p in ipairs(c.pasos) do
        if not Hecha(p.q) and not p.preparacion and not (p.opcionalInicio and inicioSuperado) then siguiente = p; break end
      end
    end
    if aprendidas or finalHecho or objetoPresente or c.sinGuiado or bloqueado or porNivel or (c.clase=="WARLOCK" and siguiente and Nivel()<(siguiente.nivel or c.nivel)) then siguiente = nil end
    local idiomaPendiente = GL.ingles and "Partial chain" or "Cadena parcial"
    local nv = Nivel()
    local color = (objetoPresente or aprendidas or finalHecho or hechas == total or bloqueado) and C.GRIS or (nv >= c.nivel and C.VERDE or C.GRIS)
    table.insert(filas, {
      titulo = true, hecha = objetoPresente or aprendidas or finalHecho or (not c.incompleta and hechas == total),
      texto = c.titulo .. C.GRIS .. L"  · nivel " .. c.nivel .. C.FIN,
      detalle = color .. (objetoPresente and (GL.ingles and "Totem obtained" or "Tótem obtenido") or aprendidas and (GL.ingles and "Abilities learned" or "Habilidades aprendidas") or ((finalHecho or (not c.incompleta and hechas == total)) and L"Hecha" or (c.repetible and (GL.ingles and "Repeatable" or "Repetible") or (c.incompleta and idiomaPendiente or (hechas .. "/" .. total .. L" misiones"))))) .. C.FIN .. " · " .. (bloqueado and (c.clase=="ROGUE" and (GL.ingles and "Complete the Poisons unlock first. " or "Completa primero el desbloqueo de venenos. ") or (c.clase=="SHAMAN" and (GL.ingles and "Complete Call of Air first. " or "Completa primero la llamada del aire. ") or (GL.ingles and "Complete taming first. " or "Completa primero la doma. "))) or "") .. notaObjeto .. (c.nota or ""),
      destino = siguiente and DestinoPaso(siguiente), boton = siguiente and DestinoPaso(siguiente) and L"Siguiente" or nil,
      ayudaTitulo = c.titulo, ayudaTexto = c.nota,
    })
    for i, p in ipairs(c.pasos) do
      local d = DestinoPaso(p)
      local hecha = not c.repetible and Hecha(p.q)
      local estado = hecha and (C.VERDE .. L"hecha" .. C.FIN) or (Llevo(p.q) and (C.AMARILLO .. L"en tu diario: entrégala" .. C.FIN)) or
        (d and (L"recógela en " .. (d.z or "?")) or L"empieza con un objeto o dentro de una mazmorra")
      if p.objetivo and Llevo(p.q) and not hecha then
        if not ObjetivoListo(p.q) then estado=GL.ingles and "In your log: complete the objective" or "En tu diario: completa el objetivo" end
      end
      if p.referencia and not hecha and not Llevo(p.q) then estado=GL.ingles and "Manual reference: check quest availability" or "Referencia manual: comprueba la oferta" end
      if objetoPresente and not Hecha(p.q) then estado=GL.ingles and "Totem already obtained" or "Tótem ya obtenido"
      elseif aprendidas and not Hecha(p.q) then estado = GL.ingles and "Abilities already learned" or "Habilidades ya aprendidas"
      elseif finalHecho and not Hecha(p.q) then estado = GL.ingles and "Final quest completed" or "Misión final completada"
      elseif p.opcionalInicio and inicioSuperado and not Hecha(p.q) then estado = GL.ingles and "Alternative introduction" or "Introducción alternativa"
      elseif p.preparacion and not Llevo(p.q) and not Hecha(p.q) then estado = GL.ingles and "Repeatable preparation (if needed)" or "Preparación repetible (si hace falta)"
      elseif c.incompleta and not Hecha(p.q) then estado = estado .. (GL.ingles and " · Route pending verification" or " · Recorrido pendiente de verificar") end
      table.insert(filas, {
        hecha = hecha, texto = i .. ". " .. p.n .. C.GRIS .. " (" .. p.nivel .. ")" .. C.FIN,
        detalle = estado .. (p.nota and (" · " .. p.nota) or "") .. ((d and d.n) and (" · " .. (d.n:match("%((.-)%)$") or "")) or ""),
        destino = (not objetoPresente and not aprendidas and not finalHecho and not c.sinGuiado and not bloqueado and not porNivel and not (c.clase=="WARLOCK" and Nivel()<(p.nivel or c.nivel)) and not (p.opcionalInicio and inicioSuperado) and not Hecha(p.q)) and d or nil,
        ayudaTitulo = p.n, ayudaTexto = p.nota or (d and d.n or nil),
      })
    end
  end
  return filas, #cadenas
end

local panel, lista, boton
local function Refrescar()
  if not panel or not panel:IsShown() then return end
  local filas, n = Filas()
  local esp = GuiaAventureroDB and GuiaAventureroDB.especializacion
  boton.texto:SetText(L"Especialización" .. (esp and (": " .. L(esp)) or ""))
  lista:Poner(filas, nil,   -- 9.4.2: sin la frase de explicación (Llevarme ya tiene su ayuda)
    n == 0 and L"Tu clase no tiene misiones de clase importantes en la guía." or nil)
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + (GL.ALTO_SUB or 0)))
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  boton = GL.CrearBoton(panel, L"Especialización", function() if GL.AbrirEspecializacion then GL.AbrirEspecializacion() end end, nil, 20)
  boton:SetWidth(200)
  boton:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  GL.Ayuda(boton, L"Especialización", L"La rama de talentos que sigue la guía. Púlsalo para cambiarla.")
  local cuerpo = CreateFrame("Frame", nil, panel)
  cuerpo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -26)
  cuerpo:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  lista = GL.CrearLista(cuerpo)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt)
    if not panel:IsShown() then return end
    espera = espera + dt
    if espera >= 2 then espera = 0; Refrescar() end
  end)
  GL.modos.clase = { panel = panel, refrescar = Refrescar }
end

GL.perezosos = GL.perezosos or {}
GL.perezosos.clase = CrearPanel
GL.comandos = GL.comandos or {}
GL.comandos["clase"] = function() if GL.AbrirModo then if GL.MostrarVentanaCompletaR10 then GL.MostrarVentanaCompletaR10() elseif GL.frame then GL.frame:Show() end; GL.AbrirModo("clase") end end

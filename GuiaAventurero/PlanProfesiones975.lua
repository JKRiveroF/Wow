-- Planes de profesión 9.7.5. Solo consultas y estimaciones; nunca fabrica, compra ni aprende recetas.
local _, GL = ...
if type(GL) ~= "table" or not GL.WH then return end
local L = GL.L
local function T(s) return s and L(s) or "" end
local BASE, MODOS, AYUDA, NOTAH = {}, {}, {}, {}
-- Conservar los orígenes de Horda antes de que Idioma traduzca los textos de WH.
local PH = GL.WH.profesionesHorda or {}
for _, p in ipairs(GL.WH.profesiones or {}) do
  BASE[p.skill] = p
  NOTAH[p.skill] = PH.nota and PH.nota[p.n]
  for _, t in ipairs(p.tramos or {}) do
    t.horda975 = t.horda975 or (PH.de and PH.de[t.de])
  end
end
local ALC_H = "Horda: Rane Yorick, norte del Bosque de Argénteos. Completa Corazones salvajes, Regreso a Quinn y Ojos salvajes. Lleva 3 corazones de huargo descoloridos y 3 ojos de múrloc. Aprende la receta con el boticario Renferrel en El Sepulcro."
BASE[171].tramos[#BASE[171].tramos].horda975 = ALC_H
-- Cantidades por tramo (no por punto). IDs de hechizos y reactivos; conservar ingredientes originales.
local function F(d,h,r,sp,c,mat,de,hd,ayuda)
  return {d=d,h=h,r=r,sp=sp,c=c,mat=mat,de=de,horda975=hd,ayuda975=ayuda}
end
local function R(d,h,r,z) return {d=d,h=h,r=r,zonas=z} end
local ENT = "Instructor"
local FORJA = "Instructor de Minería que enseñe fundición; necesitas una forja."
local FUNDIR = {
  F(1,65,"Fundir cobre",2657,130,{{2770,130,"Mineral de cobre"}},FORJA,nil,"Reserva al menos 60 lingotes de cobre para el bronce."),
  F(65,75,"Fundir estaño",3304,60,{{2771,60,"Mineral de estaño"}},FORJA,nil,"Conserva los 60 lingotes; puedes necesitar fundir estaño aunque ya no suba habilidad."),
  F(75,100,"Fundir bronce",2659,60,{{2840,60,"Lingote de cobre"},{3576,60,"Lingote de estaño"}},FORJA,nil,"Cada fabricación da 2 lingotes de bronce."),
  F(100,125,"Fundir plata",2658,70,{{2775,70,"Mineral de plata"}},FORJA),
  F(125,140,"Fundir hierro",3307,35,{{2772,35,"Mineral de hierro"}},FORJA),
  R(140,155,"Extrae filones de hierro; la ruta de fundición no cubre este intervalo.","Tierras Altas de Arathi, Desolace, Las Mil Agujas"),
  F(155,185,"Fundir oro",3308,60,{{2776,60,"Mineral de oro"}},FORJA),
  R(185,225,"Extrae mitril y los filones que aún den habilidad.","Azshara, Tanaris, Tierras del Interior"),
  R(225,245,"Mitril, veraplata y hierro negro desde 230.","La Garganta de Fuego, Las Estepas Ardientes, Tanaris"),
  R(245,275,"Extrae filones pequeños de torio desde 245.","Cráter de Un'Goro, Silithus, Cuna del Invierno"),
  R(275,300,"Extrae filones de torio enriquecido desde 275.","Cráter de Un'Goro, Cuna del Invierno, Tierras de la Peste del Este"),
}
MODOS[186] = {fundicion=FUNDIR}
local OME_A = "Receta: Kendor Kabonka, Ventormenta."
local OME_H = "Receta: Keena, Sentencia, Tierras Altas de Arathi."
local RAP_A = "Receta: Hammon Karwn, Refugio de la Zaga, Tierras Altas de Arathi."
local RAP_H = OME_H
local CARNE = {
  F(1,50,"Carne de jabalí a la brasa",2540,52,{{769,52,"Trozo de carne de jabalí"}},"Conocido"),
  F(50,90,"Filete de coyote",2541,40,{{2673,40,"Carne de coyote"}},ENT),
  F(90,130,"Costillas de cerdo secas",2546,42,{{2677,42,"Costillas de jabalí"},{2678,42,"Especias suaves"}},ENT),
  F(130,150,"Omelet curiosamente sabroso",3376,20,{{2676,20,"Huevo de raptor"},{2692,20,"Especias picantes"}},OME_A,OME_H),
  F(150,175,"Omelet curiosamente sabroso",3376,26,{{2676,26,"Huevo de raptor"},{2692,26,"Especias picantes"}},OME_A,OME_H),
  F(175,225,"Raptor asado",15855,52,{{12184,52,"Carne de raptor"},{2692,52,"Especias picantes"}},RAP_A,RAP_H),
  F(225,285,"Filete de lobo tierno",22480,68,{{12208,68,"Carne de lobo tierna"},{3713,68,"Especias calmantes"}},"Receta: Dirge Hojágil, Gadgetzan, tras desbloquear Artesano."),
  F(285,300,"Filete de lobo tierno",22480,52,{{12208,52,"Carne de lobo tierna"},{3713,52,"Especias calmantes"}},"Receta: Dirge Hojágil, Gadgetzan, tras desbloquear Artesano.",nil,"Receta verde: compra en tandas y detente al llegar a 300."),
}
MODOS[185] = {carne=CARNE}

-- Cocina: primeros tramos de pesca, cantidades estimadas y recetas por facción.
for _,t in ipairs(BASE[185].tramos) do
  if t.sp==7751 then
    t.c=55; t.mat[1][2]=55; t.colores977={1,45,65,85}
    t.de="Receta 6325: Tharynn Bouden, Villadorada."
    t.horda975="Receta 6325: Sewa Mistrunner, Cima del Trueno."
  elseif t.sp==7753 then
    t.c=55; t.mat[1][2]=55; t.colores977={50,90,110,130}
    t.de="Receta 6328: Tharynn Bouden, Villadorada."
    t.horda975="Receta 6328: Naal Mistrunner, Cima del Trueno."
  elseif t.sp==20916 then
    t.c=55; t.mat[1][2]=55; t.colores977={175,215,235,255}
    t.ayuda975="Cantidad estimada: cocina por tandas desde 215. Desbloquea Artesano antes de superar 225."
  elseif t.sp==18238 then
    t.h=265; t.c=40; t.mat[1][2]=40; t.colores977={225,265,285,305}
  elseif t.sp==18246 then
    t.d=265; t.r="Sopa de pargo nocturno"; t.sp=18243; t.c=40
    t.mat={{13759,40,"Pargo nocturno crudo"},{159,40,"Agua de manantial refrescante"}}
    t.de="Receta 13945: Gikkix, Puerto Bonvapor, Tanaris."
    t.horda975=t.de; t.colores977={250,290,310,330}
    t.ayuda975="Usa un fuego de cocina. Cocina por tandas desde 290; cantidad estimada. El filete de vigorpez requiere horno de hierro."
  elseif t.sp==7755 then
    t.colores977={100,140,160,180}
    t.de="Receta 6330: Lindea Rabonne, Costasur, Laderas de Trabalomas."
    t.horda975="Receta 6330: Derak Nightfall, Molino Tarren, Laderas de Trabalomas; o Naal Mistrunner, Cima del Trueno."
    t.ayuda975="Cantidad estimada: cocina por tandas, especialmente desde 160. Aprende Experto antes de superar 150."
  end
end
for _,t in ipairs(CARNE) do
  if t.sp==15855 then
    t.c=55; t.mat[1][2]=55; t.mat[2][2]=55; t.colores977={175,215,235,255}
    t.ayuda975="Cantidad estimada: cocina por tandas desde 215. Desbloquea Artesano antes de superar 225."
  elseif t.sp==22480 then
    t.colores977={225,265,285,305}
    t.de="Receta 18046: Dirge Hojágil, Gadgetzan, o Truk Wildbeard, Tierras del Interior."
    t.horda975="Receta 18046: Dirge Hojágil, Gadgetzan, Tanaris."
    t.ayuda975="Cantidad estimada: cocina por tandas desde 265; desde 285 la receta es verde."
  elseif t.sp==2546 then t.colores977={80,120,140,160}
  elseif t.sp==3376 then
    t.colores977={130,170,190,210}
    if t.d==150 then t.ayuda975="Aprende Experto antes de superar 150. Cantidad estimada; cocina por tandas." end
  end
end

-- Cocina: combina rutas revisadas en el límite común de Artesano (225).
local function CocinaMixta(inicio,final)
  local salida={}
  for _,t in ipairs(inicio) do if t.h<=225 then salida[#salida+1]=t end end
  for _,t in ipairs(final) do if t.d>=225 then salida[#salida+1]=t end end
  return salida
end
MODOS[185].pescadocarne=CocinaMixta(BASE[185].tramos,CARNE)
MODOS[185].carnepescado=CocinaMixta(CARNE,BASE[185].tramos)

-- Encantamiento: opción de inicio sin objetos para desencantar.
local ENC = BASE[333].tramos
local function AjustarEnc(t,n)
  local anterior=t.c
  for _,m in ipairs(t.mat) do m[2]=m[2]/anterior*n end
  t.c=n
end
local ENC_UMBRAL = {
  [13501]="Instructor. Forever: aprendizaje 130; amarillo/verde/gris: 155/175/195. Cantidad estimada.",
  [13661]="Instructor. Forever: aprendizaje 180; amarillo/verde/gris: 200/220/240. Cantidad estimada.",
  [13746]="Instructor. Forever: aprendizaje 205; amarillo/verde/gris: 225/245/265. Cantidad estimada.",
  [13815]="Instructor. Forever: aprendizaje 210; amarillo/verde/gris: 230/250/270. Cantidad estimada.",
  [13836]="Instructor. Forever: aprendizaje 215; amarillo/verde/gris: 235/255/275. Cantidad estimada.",
  [13858]="Instructor. Forever: aprendizaje 220; amarillo/verde/gris: 240/260/280. Cantidad estimada.",
  [7421]="Conocido al aprender Encantamiento. Forever: aprendizaje 1; amarillo/verde/gris: 5/7/10.",
  [7426]="Instructor. Forever: aprendizaje 40; amarillo/verde/gris: 90/110/130.",
  [7457]="Instructor. Forever: aprendizaje 50; amarillo/verde/gris: 100/120/140.",
  [7795]="Instructor. Forever: aprendizaje 100; amarillo/verde/gris: 130/150/170.",
  [14807]="Instructor. Forever: aprendizaje 70; amarillo/verde/gris: 110/130/150.",
  [13628]="Instructor. Forever: aprendizaje 150; amarillo/verde/gris: 175/195/215.",
  [13702]="Instructor. Forever: aprendizaje 200; amarillo/verde/gris: 220/240/260.",
  [20051]="Vendedor: Lorelae Cantinvernal, Claro de la Luna (fórmula 16243). Forever: aprendizaje 290; amarillo/verde/gris: 310/330/350.",
}
for _,t in ipairs(ENC) do
  if t.sp==13858 then AjustarEnc(t,19) end
  if ENC_UMBRAL[t.sp] then
    t.de=ENC_UMBRAL[t.sp]
    t.horda975=nil
  elseif t.sp==13419 then
    t.de="Vendedor: Dalria (fórmula 11039). Forever: aprendizaje 110; amarillo/verde/gris: 135/155/175. Cantidad estimada."
    t.horda975="Vendedor: Kulwia, Sierra Espolón (fórmula 11039). Forever: aprendizaje 110; amarillo/verde/gris: 135/155/175. Cantidad estimada."
  elseif t.sp==13536 then
    t.de="Vendedor: Dalria (fórmula 11101). Forever: aprendizaje 140; amarillo/verde/gris: 165/185/205. Cantidad estimada."
    t.horda975="Vendedor: Kulwia, Sierra Espolón (fórmula 11101). Forever: aprendizaje 140; amarillo/verde/gris: 165/185/205. Cantidad estimada."
  elseif t.sp==14293 then
    AjustarEnc(t,62)
    t.de="Instructor. Forever: aprendizaje 10; amarillo/verde/gris: 75/95/115. Cantidad estimada."
  elseif t.sp==25127 then
    AjustarEnc(t,18)
    t.de="Vendedor: Kania, Silithus; alternativa Lokhtos Tratoscuro, Profundidades de Roca Negra (fórmula 20754). Forever: aprendizaje 250; amarillo/verde/gris: 260/270/280. Cantidad estimada."
  elseif t.sp==20017 then
    AjustarEnc(t,32)
    t.de="Vendedor: Mythrin'dir, Darnassus (fórmula 16217, ligada al recoger; existencias limitadas). Forever: aprendizaje 265; amarillo/verde/gris: 285/305/325. Cantidad estimada."
    t.horda975="Vendedor: Daniel Bartlett, Entrañas (fórmula 16217, ligada al recoger; existencias limitadas). Forever: aprendizaje 265; amarillo/verde/gris: 285/305/325. Cantidad estimada."
  elseif t.sp==20015 then
    t.de="Vendedor: Lorelae Cantinvernal, Claro de la Luna (fórmula 16224). Forever: aprendizaje 285; amarillo/verde/gris: 305/325/345."
  end
end
local SINDE = {ENC[1], F(2,20,"Encantar brazal: aguante ínfimo",7418,18,{{247786,18,"Mota de magia"}},"Conocido; consigue motas de magia. Forever: aprendizaje 1; amarillo/verde/gris: 20/22/25.")}
for i=3,#ENC do SINDE[#SINDE+1]=ENC[i] end
MODOS[333]={sindesencantar=SINDE}
local HOMBRERAS = {}
for _, t in ipairs(BASE[197].tramos) do if t.h <= 280 then HOMBRERAS[#HOMBRERAS+1]=t end end
HOMBRERAS[#HOMBRERAS+1] = F(280,300,"Hombreras de paño rúnico",18449,58,{{14048,406,"Madeja de paño rúnico"},{14227,116,"Seda de araña Tejehierro"},{8170,232,"Cuero basto"},{14341,58,"Hilo rúnico"}},"Patrón 14504: botín del mundo o subasta. Aprende la receta a 260. Amarillo/verde/gris: 275/290/305. Cantidad estimada, no garantizada.",nil,"Alternativa sin telar. No es siempre la más barata: compara el coste del patrón y del cuero.")
-- Ruta principal alternativa 250-300 sin depender del patrón de Pexmit. Conservamos hasta 250.
local SINPEXM = {}
for _, t in ipairs(BASE[197].tramos) do if t.h <= 250 then SINPEXM[#SINPEXM+1]=t end end
SINPEXM[#SINPEXM+1] = F(250,260,"Guantes de paño rúnico",18417,19,{{14048,76,"Madeja de paño rúnico"},{8170,76,"Cuero basto"},{14341,19,"Hilo rúnico"}},"Patrón: Qia, Cuna del Invierno (61.2, 37.2; 1 oro 60 plata, existencias limitadas). Forever: aprendizaje 230; amarillo/verde/gris: 245/260/275. Cantidad estimada, no garantizada.")
SINPEXM[#SINPEXM+1] = F(260,280,"Hombreras de paño rúnico",18449,21,{{14048,147,"Madeja de paño rúnico"},{14227,42,"Seda de araña Tejehierro"},{8170,84,"Cuero basto"},{14341,21,"Hilo rúnico"}},"Patrón 14504: botín del mundo o subasta. Aprende la receta a 260. Amarillo/verde/gris: 275/290/305. Cantidad estimada, no garantizada.")
SINPEXM[#SINPEXM+1] = HOMBRERAS[#HOMBRERAS]
MODOS[197] = {hombreras=HOMBRERAS, sinpexmit=SINPEXM}
-- Variante explícita: no se presupone que la receta alternativa esté aprendida.
-- Las cantidades son estimaciones; al elegirla se recalcula la compra con sus ingredientes.
local function SedaAlternativa(tramos)
  local res={}
  for _,t in ipairs(tramos) do
    if t.d==132 and t.h==139 and t.sp==6690 then
      res[#res+1]=F(132,135,"Capucha de seda azur",8760,6,{{4305,12,"Madeja de paño de seda"},{6260,12,"Tinte azul"},{2321,6,"Hilo refinado"}},"Comprueba que la receta esté aprendida y aún dé puntos. Cantidad estimada.")
      res[#res+1]=F(135,140,"Toga de zahorí inferior",6690,7,{{4305,14,"Madeja de paño de seda"},{2321,14,"Hilo refinado"},{3182,14,"Seda de araña"}},"Comprueba que la receta esté aprendida y aún dé puntos. Cantidad estimada.")
    elseif not (t.d==139 and t.h==140 and t.sp==3871) then
      res[#res+1]=t
    end
  end
  return res
end
MODOS[197].sedalternativa=SedaAlternativa(BASE[197].tramos)
MODOS[197].hombrerasseda=SedaAlternativa(HOMBRERAS)
MODOS[197].sinpexmitseda=SedaAlternativa(SINPEXM)

-- Recuperación parcial de Alquimia (fase 3): variante sin cadena final.
local ALC_A = "Vendedor: Ulthir, Darnassus (receta 13477). Forever: aprendizaje 260; amarillo/verde/gris: 275/295/315. Cantidad estimada; puede requerir más fabricaciones."
local ALC_B = "Vendedor: Algernon, Entrañas (receta 13477). Forever: aprendizaje 260; amarillo/verde/gris: 275/295/315. Cantidad estimada; puede requerir más fabricaciones."
local ALC_ALT = {}
for _,t in ipairs(BASE[171].tramos) do
  if t.sp==17553 then t.de=ALC_A; t.horda975=ALC_B end
  if t.d<270 then ALC_ALT[#ALC_ALT+1]=t end
end
ALC_ALT[#ALC_ALT+1]=F(270,300,"Poción excelente de maná",17553,44,{{8838,88,"Solea"},{8839,88,"Carolina"},{8925,44,"Vial de cristal"}},ALC_A,ALC_B)
MODOS[171]={sinmision=ALC_ALT}

-- Herrería: reconstrucción de la variante 215–225, sin alterar la referencia.
local HERR_ALMOFAR = {}
for _,t in ipairs(BASE[164].tramos) do
  if t.d==215 and t.h==225 then
    HERR_ALMOFAR[#HERR_ALMOFAR+1]=F(215,225,"Almófar de mitril",9961,10,{{3860,100,"Lingote de mitril"},{4338,60,"Tela de paño mágico"}},"Instructor. Forever: aprendizaje 205; amarillo/verde/gris: 225/235/245. Confirma el color en juego.")
  else HERR_ALMOFAR[#HERR_ALMOFAR+1]=t end
end
MODOS[164]={almofar=HERR_ALMOFAR}

-- Reconstrucción provisional: exige diseños de botín, sin arcanita ni Pexmit.
local function HerrSinArcanita(tramos)
  local res={}
  for _,t in ipairs(tramos) do if t.h<=250 then res[#res+1]=t end end
  local botas="Diseño 251439: botín de vigía Hierro Negro, Garganta de Fuego; ligado al recoger. Aprendizaje 240; amarillo/verde/gris: 260/270/280. Cantidad estimada."
  res[#res+1]=F(250,260,"Botas de placas benditas",1252336,10,{{12359,240,"Lingote de torio"},{12361,10,"Zafiro azul"},{8170,60,"Cuero basto"}},botas)
  res[#res+1]=F(260,270,"Botas de placas benditas",1252336,18,{{12359,432,"Lingote de torio"},{12361,18,"Zafiro azul"},{8170,108,"Cuero basto"}},botas)
  res[#res+1]=F(270,280,"Cinturón de placas benditas",1252341,10,{{12359,180,"Lingote de torio"},{12361,10,"Zafiro azul"},{7071,10,"Hebilla de hierro"},{8170,60,"Cuero basto"}},"Diseño 251444: botín de murciélago de peste, Tierras de la Peste del Este; ligado al recoger. Aprendizaje 270; amarillo/verde/gris: 290/300/310.")
  res[#res+1]=F(280,300,"Peto de placas benditas",1252343,20,{{12359,720,"Lingote de torio"},{12361,40,"Zafiro azul"}},"Diseño 251446: botín de Monte Hyjal; ligado al recoger. Aprendizaje 280; amarillo/verde/gris: 300/310/320. Comprueba acceso antes de elegir el plan.")
  return res
end
MODOS[164].sinarcanita=HerrSinArcanita(BASE[164].tramos)
MODOS[164].almofarsinarcanita=HerrSinArcanita(HERR_ALMOFAR)
-- Alternativa reconstruida sin plata en 75-80; no equivale al original perdido.
local function HerrCobre(tramos)
  local res={}
  for _,t in ipairs(tramos) do
    if t.d==75 and t.h==80 then
      res[#res+1]=F(75,80,"Guanteletes de cobre rúnico",3323,7,{{2840,56,"Lingote de cobre"},{3470,14,"Piedra de pulir férrea"}},"Instructor. Forever: amarillo 75, gris 115; compra en tandas y confirma habilidad de aprendizaje. Cantidad estimada.")
    else res[#res+1]=t end
  end
  return res
end
MODOS[164].cobre=HerrCobre(BASE[164].tramos)
MODOS[164].cobrealmofar=HerrCobre(HERR_ALMOFAR)
MODOS[164].cobresinarcanita=HerrCobre(MODOS[164].sinarcanita)
MODOS[164].cobrealmofarsinarcanita=HerrCobre(MODOS[164].almofarsinarcanita)



-- Consejos puntuales en los 12 oficios, sin convertir recetas aún dudosas en pasos obligatorios.
AYUDA[197] = "Puedes elegir hombreras (280-300) o sinpexmit (250-300) para evitar el telar. Comprueba el patrón antes de comprar materiales. Combina con Encantamiento para aprovechar objetos fabricados. Las madejas fabricadas para subir habilidad no cubren todo el consumo posterior: consulta la compra estimada y fabrica las restantes aunque la receta sea gris, o cómpralas. No compres a la vez esas madejas y la tela necesaria para fabricarlas."
AYUDA[171] = "El plan sin misión final usa Poción excelente de maná hasta 300. Desde 295 es verde: compra materiales adicionales si los necesitas. La piedra de filósofo se usa en transmutaciones."
AYUDA[164] = "Compara el precio de las piedras, barras y gemas. Aprovecha Minería y conserva las piedras de pulir para las recetas posteriores. La parte alta aún necesita validación de recetas y acceso."
AYUDA[333] = "Aprovecha los materiales de desencantar, conserva las varas rúnicas y comprueba los requisitos de fórmulas antes de viajar. La cantidad de polvo necesaria depende del color real de cada encantamiento."
AYUDA[202] = "Fabrica 60 pólvoras bastas y 30 puñados de tornillos aunque alcances antes el objetivo de habilidad. Reserva los componentes para las bombas; las cantidades de subida son estimadas. Prepara 60 unidades de pólvora burda para las dinamitas y conserva los tubos de bronce y cacharros zumbones sobrantes. Antes de habilidad 160, reserva 30 unidades de pólvora pesada (puedes fabricarlas desde 125 con 30 piedras pesadas o comprarlas; la lista de compra las muestra como componente). Fabrica 15 marcos de bronce aunque alcances antes 160. Conserva el microajustador giromático. Reserva 60 unidades de pólvora sólida, 20 activadores inestables y 40 envolturas de mitril para las 20 fabricaciones estimadas de bombas altamente explosivas. Conserva los tubos de mitril. Si la pólvora deja de dar puntos antes de 194, usa una receta que aún suba habilidad."
-- Peletería: reservar cinturones para los dos tramos de cinturón oscuro.
for _,t in ipairs(BASE[165].tramos) do
  if t.sp==3763 then
    t.c=25; t.mat[1][2]=150; t.mat[2][2]=50
    t.ayuda975="Fabrica y conserva 25 cinturones finos aunque alcances antes habilidad 100; se consumen en los tramos de cinturón oscuro."
  elseif t.sp==3818 then
    t.ayuda975="Reserva 20 pellejos pesados curados para las hombreras y los guantes. El plan fabrica 22; conserva al menos 20 aunque alcances antes el objetivo. La receta es gris a 145."
  elseif t.sp==3770 then
    t.sp=3764; t.r="Guantes de cuero del montañero"; t.c=20
    t.mat={{2319,280,"Cuero medio"},{2321,80,"Hilo refinado"}}
    t.ayuda975="Aprende a 120; amarillo 145, verde 157, gris 170. Cantidad estimada; fabrica por tandas hasta 155."
  elseif t.sp==3766 then
    for _,m in ipairs(t.mat) do if m[1]==4246 then m[3]="Cinturón fino de cuero" end end
    t.ayuda975="Reserva 25 pellejos medios curados para los dos tramos de cinturón oscuro. Puedes curarlos desde habilidad 75 con 25 pellejos medios y 25 unidades de sal, o comprarlos; no compres ambas opciones. La compra general muestra el producto curado."
  end
end
-- Ruta Forever 155-225 sin cinturones de gemas; cantidades estimadas.
local piel={}
for _,t in ipairs(BASE[165].tramos) do if t.h<=155 then piel[#piel+1]=t end end
local avisoPiel="Forever: cantidades estimadas; fabrica por tandas y comprueba el color de la receta."
piel[#piel+1]=F(155,165,"Hombreras barbáricas",7151,10,{{4234,80,"Cuero pesado"},{4236,10,"Pellejo pesado curado"},{2321,20,"Hilo refinado"}},ENT,nil,avisoPiel)
piel[#piel+1]=F(165,175,"Guantes del Guardián",7156,10,{{4234,40,"Cuero pesado"},{4236,10,"Pellejo pesado curado"},{4291,10,"Hilo de seda"}},ENT,nil,avisoPiel)
piel[#piel+1]=F(175,195,"Complemento grueso para armadura",10487,20,{{4304,100,"Cuero grueso"},{4291,20,"Hilo de seda"}},ENT,nil,avisoPiel)
piel[#piel+1]=F(195,210,"Cinta Nochefugaz",10507,20,{{4304,100,"Cuero grueso"},{4291,40,"Hilo de seda"}},ENT,nil,avisoPiel)
piel[#piel+1]=F(210,225,"Pantalones Nochefugaz",10548,15,{{4304,210,"Cuero grueso"},{4291,60,"Hilo de seda"}},"Instructor de Artesano: Drakk Stonehand, Tierras del Interior.","Instructor de Artesano: Hahrana Ironhide, Feralas.",avisoPiel)
for _,t in ipairs(BASE[165].tramos) do if t.d>=225 then piel[#piel+1]=t end end
BASE[165].tramos=piel
-- Forever: 19047 produces two hides per craft, unlike the old estimate.
for _,t in ipairs(piel) do
  if t.sp==19047 then
    t.r="Pellejo basto curado"
    t.ayuda975="Aprende a 225; requiere estación de curtido. Cada fabricación produce dos pellejos bastos curados. Reserva los 12 previstos para los yelmos; adquiere o fabrica los 21 restantes según el inventario. Amarillo 225, verde 230, gris 235."
  elseif t.sp==19049 then
    t.de="Vendedor: Leonard Porter, Tierras de la Peste del Oeste (patrón 15725, existencias limitadas)."
    t.horda975="Vendedor: Werg Thickblade, Claros de Tirisfal (patrón 15725, existencias limitadas)."
    t.ayuda975="Aprendizaje 235 según Forever Tavern; amarillo 255. Confirma el requisito del patrón en el cliente y fabrica por tandas."
  elseif t.sp==19048 then
    t.de="Vendedor: Zannok Perforapieles, Silithus (patrón 15724). Ambas facciones."
    t.horda975=t.de
    t.ayuda975="Aprende a 255; ya puede estar amarillo. Gris desde 270 según los datos del cliente 1.60.1. Amarillo 250 y verde 260 son referencias discrepantes entre fuentes; confirma el color en el juego y fabrica por tandas."
  elseif t.sp==19088 then
    t.de="Vendedor: Zannok Perforapieles, Silithus (patrón 15762). Ambas facciones."
    t.horda975=t.de
    t.ayuda975="Aprende a 270; amarillo 290, verde 300, gris 310. Las 33 fabricaciones son una estimación; compra por tandas y conserva los pellejos curados."
  end
end
-- Umbrales contrastados de Peletería; no completar valores dudosos por extrapolación.
local PIEL_COLORES = {
  [7135]={90,115,127,140},
  [2167]={75,100,112,125},
  [3766]={100,125,137,150},
  [3818]={125,135,140,145},
  [19049]={235,255,265,275},
  [2881]={1,20,30,40},
  [2152]={1,30,45,60},
  [3816]={35,50,60,70},
  [3756]={40,70,85,100},
  [3763]={55,85,100,115},
  [3764]={120,145,157,170},
  [7151]={150,170,180,190},
  [7156]={165,185,195,205},
  [10487]={175,195,205,215},
  [10507]={180,200,210,220},
  [10548]={205,225,235,245},
  [19047]={225,225,230,235},
  [19048]={255,250,260,270}, -- amarillo anterior al aprendizaje; no hay fase naranja accesible según esta fuente.
  [19088]={270,290,300,310},
}
for _,t in ipairs(piel) do t.colores977=PIEL_COLORES[t.sp] end
AYUDA[165] = "Conserva los pellejos curados y piezas usadas como ingredientes. Combina con Desuello y compara el precio de los materiales especiales antes de elegir las recetas finales."
AYUDA[185] = "El plan referencia aprovecha Pesca; el plan carne permite subir sin Pesca. Reserva por separado los 12 huevos gigantes, 10 carnes de almeja sabrosa y 20 quesos suizos de Alterac para desbloquear Artesano."
AYUDA[129] = "Compra los manuales por facción y desbloquea Artesano antes de llegar a su límite. Reserva telas suficientes para fabricaciones amarillas o verdes; detente cuando alcances el objetivo."
AYUDA[186] = "El plan fundicion alterna forja y filones hasta 185; a partir de ahí continúa extrayendo. Compra minerales solo si te compensa; un instructor de inicio puede no enseñar fundición."
AYUDA[182] = "Prioriza las plantas que tu habilidad efectiva permite recoger y las que necesita Alquimia. Cambia de zona cuando las plantas frecuentes dejen de dar puntos."
AYUDA[393] = "Desuella las bestias que ya matas durante tus misiones y comprueba el requisito real de desuello de cada cadáver. Guarda cuero para Peletería."
AYUDA[356] = "Elige aguas adecuadas a tu habilidad y al pescado que necesita Cocina. No cambies de zona solo por subir habilidad si puedes pescar sin fallos donde estás; usa señuelos cuando hagan falta."

-- Productos que se pueden reservar. Se contabilizan solo rendimientos mínimos explícitos,
-- no se supone que todos los objetos de una receta vayan a estar en las bolsas.
local PRODUCTOS = {
  [2963]={2996,1},[2964]={2997,1},[3839]={4305,1},[3865]={4339,1},[18401]={14048,1},
  [2657]={2840,1},[3304]={3576,1},[2659]={2841,2},[2658]={2842,1},[3307]={3575,1},[3308]={3577,1},
  [3918]={4357,1},[3922]={4359,1},[3929]={4364,1},[3973]={4404,1},[3938]={4371,1},[3942]={4375,1},[3953]={4382,1},[3955]={4384,1},[12585]={10505,1},[12589]={10559,1},[12619]={10562,4},[12591]={10560,1},[12599]={10561,1},[19788]={15992,1},
  [3763]={4246,1},[3816]={4231,1},[3817]={4233,1},[3818]={4236,1},[19047]={15407,2},[2881]={2318,1},
  [3320]={3470,1},[3326]={3478,1},[2674]={2871,1},[3337]={3486,2},[9920]={7966,1},[16639]={12644,1},
}
function GL.ResultadoProfesion975(sp)
  local r=PRODUCTOS[sp]; if r then return r[1],r[2] end
end
function GL.PlanProfesion975(skill, modo)
  local p=BASE[skill]; if not p then return nil end
  local a=MODOS[skill] and MODOS[skill][modo]
  if not a then return p end
  local copia={}; for k,v in pairs(p) do copia[k]=v end
  copia.tramos=a; copia.modo975=modo; return copia
end
-- Umbrales de color de referencia Forever (cliente 1.60.1); no certifican el instructor.
local ING_COLORES = {
  [7430]={50,70,80,90},
  [12590]={175,175,195,215},
  [19791]={260,280,290,300},
  [3918]={1,20,30,40},
  [3922]={30,45,52,60},
  [3923]={30,60,75,90},
  [3929]={75,85,90,95},
  [3931]={75,90,97,105},
  [3973]={90,110,125,140},
  [3938]={105,105,130,155},
  [3978]={110,135,147,160},
  [3942]={125,125,150,175},
  [3953]={145,145,170,195},
  [3955]={150,175,187,200},
  [12585]={175,175,185,195},
  [12589]={195,195,215,235},
  [12591]={200,200,220,240},
  [12599]={215,215,235,255},
  [12619]={235,235,255,275},
  [19788]={250,250,255,260},
  [19795]={275,295,305,315},
}
for _,t in ipairs(BASE[202].tramos) do
  t.colores977=ING_COLORES[t.sp]
end
-- Ingeniería: variantes opcionales, sin modificar la ruta de referencia.
local function IngAlternativa(cobre,torio)
  local res={}
  for _,t in ipairs(BASE[202].tramos) do
    local nuevo=t
    if cobre and t.d==51 and t.h==75 then
      nuevo=F(51,75,"Tubo de cobre",3924,24,{{2840,48,"Lingote de cobre"},{2880,24,"Flujo débil"}},"Instructor. Aprende a 50; alternativa sin bombas en este tramo.")
      nuevo.colores977={50,80,95,110}
    elseif torio and t.d==285 and t.h==300 then
      nuevo=F(285,300,"Proyectiles de torio",19800,15,{{12359,30,"Lingote de torio"},{15992,15,"Pólvora densa"}},"Esquema 16051: botín o subasta. Aprende a 285; elige solo si tienes el esquema. Reserva 15 pólvoras densas.")
      nuevo.colores977={285,305,315,325}
    end
    res[#res+1]=nuevo
  end
  return res
end
MODOS[202]={ingtubocobre=IngAlternativa(true,false),ingproyectiles=IngAlternativa(false,true),ingcombinado=IngAlternativa(true,true)}
-- Variante de Peletería: evita el patrón de brazales, reutilizando el de guanteletes.
local pielSinBrazales={}
for _,t in ipairs(BASE[165].tramos) do
  local nuevo=t
  if t.sp==19048 and t.d==255 and t.h==260 then
    local fuente
    for _,v in ipairs(BASE[165].tramos) do if v.sp==19049 and v.d==260 then fuente=v; break end end
    assert(fuente,"Falta tramo de guanteletes")
    nuevo=F(255,260,fuente.r,19049,10,{{8170,80,"Cuero basto"},{2325,10,"Tinte negro"},{14341,10,"Hilo rúnico"}},fuente.de,fuente.horda975,"Alternativa sin brazales: fabrica por tandas; amarillo 255, verde 265, gris 275. Cantidad estimada.")
    nuevo.colores977=PIEL_COLORES[19049]
  end
  pielSinBrazales[#pielSinBrazales+1]=nuevo
end
MODOS[165]=MODOS[165] or {}
MODOS[165].pielsinbrazales=pielSinBrazales
-- Variante de menor consumo de pellejo basto: conserva cinco niveles de yelmos.
local function PielMenosPellejos(base)
  local res={}
  for _,t in ipairs(base) do
    if t.sp==19088 and t.d==270 and t.h==300 then
      local y=F(270,275,t.r,19088,5,{{8170,40,"Cuero basto"},{15408,60,"Escama de escórpido pesado"},{15407,5,"Pellejo basto curado"},{14341,5,"Hilo rúnico"}},t.de,t.horda975,"Reserva cinco pellejos bastos curados para este tramo.")
      y.colores977=PIEL_COLORES[19088]; res[#res+1]=y
      local c=F(275,300,"Cinturón de cuero maligno",19092,28,{{8170,392,"Cuero basto"},{2325,56,"Tinte negro"},{14341,56,"Hilo rúnico"}},"Patrón 15768: botín o subasta. Comprueba que se aprende a 275 en el cliente.",nil,"Alternativa con menos pellejos: amarillo 295, verde 305, gris 315 según fuentes de Forever; fabrica por tandas. Cantidad estimada.")
      c.colores977={275,295,305,315}; res[#res+1]=c
    else res[#res+1]=t end
  end
  return res
end
MODOS[165].pielmenospellejos=PielMenosPellejos(BASE[165].tramos)
MODOS[165].pielcombinado=PielMenosPellejos(pielSinBrazales)

function GL.OrigenProfesion975(t, fac)
  local origen=(fac=="Horde" and t.horda975) or t.de
  if t.colores977 then
    local c=t.colores977
    if t.sp==19048 then return T(origen).." "..string.format(T("Forever: aprendizaje %d, amarillo %d, verde %d, gris %d (referencia; confirma el color)."),c[1],c[2],c[3],c[4]) end
    return T(origen).." "..string.format(T("Forever: naranja %d, amarillo %d, verde %d, gris %d (referencia)."),c[1],c[2],c[3],c[4])
  end
  return origen and T(origen) or nil
end
function GL.NotaProfesion975(p, fac)
  local nota=T((fac=="Horde" and NOTAH[p.skill]) or p.nota)
  if p.skill==202 then
    local rangos=T("Aprendiz: nivel 5; Oficial: habilidad 50 y nivel 10; Experto: habilidad 125 y nivel 20; Artesano: habilidad 200 y nivel 35. Aprende el rango siguiente antes de alcanzar su límite.")
    local instructor=T(fac=="Horde" and "Horda: Roxxik, Orgrimmar (76.2, 25.2), para Experto." or "Alianza: Springspindle Fizzlegear, Forjaz (68.5, 43.5), para Experto.")
    local artesano=T("Artesano: Buzzek Bracketswing, Gadgetzan, Tanaris (52.3, 27.7), ambas facciones. Alternativa: Kaylaena Springwhisper, Monte Hyjal (60.2, 61.4), si tienes acceso. Disponibilidad por confirmar en el cliente.")
    return table.concat({nota or "",rangos,instructor,artesano}," ")
  end
  if p.skill==165 then
    local rangos=T("Aprendiz: sin nivel mínimo según las guías de Forever; Oficial: habilidad 50 y nivel 10; Experto: habilidad 125 y nivel 20; Artesano: habilidad 200 y nivel 35. Aprende el rango siguiente antes de alcanzar su límite.")
    local instructor=T(fac=="Horde" and "Horda: Karolek, Orgrimmar, para Oficial; Una, Cima del Trueno (41.5, 42.6), para Experto; Hahrana Ironhide, Feralas (74.4, 43.1), para Artesano." or "Alianza: Simon Tanner, Ventormenta, para Oficial; Telonis, Darnassus (64.4, 21.5), para Experto; Drakk Stonehand, Tierras del Interior (13.4, 43.5), para Artesano.")
    return table.concat({nota or "",rangos,instructor}," ")
  end
  if p.skill==333 then
    local rangos=T("Aprendiz: 1-75; Oficial: habilidad 50 y nivel 10; Experto: habilidad 125 y nivel 20; Artesano: habilidad 200 y nivel 35.")
    local instructor=T(fac=="Horde" and "Horda: Hgarth, Sierra Espolón (49.2, 57.2), para Experto." or "Alianza: Kitta Firewind, Bosque de Elwynn (64.8, 70.6), para Experto.")
    local artesano=T("Artesano: Annora, Uldaman, tras limpiar los escorpiones cercanos. Lleva materiales para aprender recetas antes de salir.")
    return table.concat({nota or "",rangos,instructor,artesano}," ")
  end
  if p.skill==129 then return (nota and nota.." " or "")..T("Antes de superar 225, completa Triaje y aprende Artesano según tu facción.") end
  return nota
end
local function DB()
  local db=GuiaAventureroDB
  if type(db)~="table" then return nil end
  if type(db.planProfesiones975)~="table" then db.planProfesiones975={} end
  return db.planProfesiones975
end
local function RutaAntigua(skill)
  local r=GL.RUTA
  if r then for _,p in ipairs(r.profesionesRuta or {}) do if p.skill==skill then return true end end end
end
local ETIQUETAS={referencia="Referencia",fundicion="Fundición",carne="Carne",pescadocarne="Pescado hasta 225 + carne",carnepescado="Carne hasta 225 + pescado",hombreras="Hombreras 280-300",sinpexmit="Sin Pexmit 250-300",sedalternativa="Seda alternativa",hombrerasseda="Hombreras + seda alternativa",sinpexmitseda="Sin Pexmit + seda alternativa",sindesencantar="Sin desencantar 2-20",sinmision="Sin misión final 270-300",almofar="Almófar 215-225",sinarcanita="Sin arcanita ni Pexmit",almofarsinarcanita="Almófar + sin arcanita",cobre="Cobre alternativo",cobrealmofar="Cobre + almófar",cobresinarcanita="Cobre + sin arcanita",cobrealmofarsinarcanita="Cobre + almófar + sin arcanita",ingtubocobre="Tubos de cobre 51-75",ingproyectiles="Proyectiles de torio 285-300",ingcombinado="Tubos de cobre + proyectiles",pielsinbrazales="Sin patrón de brazales 255-260",pielmenospellejos="Menos pellejos bastos 270-300",pielcombinado="Sin brazales + menos pellejos",ruta="Plan anterior"}
function GL.ModalidadesProfesion975(skill)
  local res={"referencia"}
  for _,m in ipairs({"fundicion","carne","pescadocarne","carnepescado","hombreras","sinpexmit","sedalternativa","hombrerasseda","sinpexmitseda","sindesencantar","sinmision","almofar","sinarcanita","almofarsinarcanita","cobre","cobrealmofar","cobresinarcanita","cobrealmofarsinarcanita","ingtubocobre","ingproyectiles","ingcombinado","pielsinbrazales","pielmenospellejos","pielcombinado"}) do if MODOS[skill] and MODOS[skill][m] then res[#res+1]=m end end
  if RutaAntigua(skill) then res[#res+1]="ruta" end
  return res
end
function GL.EtiquetaPlan975(m) return T(ETIQUETAS[m] or m) end
function GL.ModoProfesion975(skill)
  local db=DB(); local m=db and db[skill]
  for _,v in ipairs(GL.ModalidadesProfesion975(skill)) do if m==v then return m end end
  return "referencia"
end
function GL.AyudaPlan975(skill, modo)
  local texto = T("Plan: ")..GL.EtiquetaPlan975(modo or "referencia")..". "..T(AYUDA[skill])
  if skill==202 then texto=texto.."\n"..T("Especialización gnómica (opcional): nivel de personaje 30 e Ingeniería 200. Alianza: Maestro manitas Sobrechispa, Forjaz (misión 3641). Horda: Oglethorpe Obnoticus, Bahía del Botín (misión 3643). Tras aceptar la promesa del secreto, entrega 6 tubos de mitril, 2 muñecos-diana avanzados y 1 mira de precisión. Reserva los tubos del plan; los otros objetos son adicionales y no están incluidos en la compra general. No necesitas especializarte para seguir el plan 1-300.") end
  if skill==202 then texto=texto.."\n"..T("Especialización goblin (opcional): nivel de personaje 30 e Ingeniería 200. Ambas facciones: Nixx Muellepiñón, Gadgetzan, Tanaris (52.5, 27.3). Promesa del secreto (3638) y Muestra tu trabajo (3639): entrega 20 bombas grandes de hierro, 20 dinamitas sólidas y 5 ovejas explosivas. Reserva 5 ovejas del tramo 160-175 si las has fabricado; adquiere las que falten. Los demás objetos son adicionales y no están incluidos en la compra general. No necesitas especializarte para seguir el plan 1-300.") end
  if skill==165 then texto=texto.."\n"..T("Peletería elemental (opcional): nivel de personaje 40 y habilidad 225 (confirma el requisito en el cliente). Alianza: Sarah Tanner, Garganta de Fuego (63.6, 75.8), misión 5144. Horda: Brumm Pezuña Invernal, Tierras Altas de Arathi (28.2, 45.0), misión 5146. Entrega 2 corazones de fuego, 2 globos de agua, 2 núcleos de tierra y 2 alientos de viento. Estos materiales son adicionales a la compra general. Elige solo una especialización; no es necesaria para subir a 300.") end
  if skill==165 then texto=texto.."\n"..T("Peletería tribal (opcional): nivel de personaje 40 y habilidad 225 (confirma la habilidad en el cliente). Completa primero Maestro del cuero salvaje. Alianza: Caryssia Moonhunter, Feralas (89.4, 46.4), misión 5143; patrones de las misiones 2849 y 2850. Horda: Se'Jib, Vega de Tuercespina (36.5, 34.1), misión 5148; patrones de las misiones 2856 y 2857. Entrega 1 jubón de cuero salvaje y 1 yelmo de cuero salvaje. Materiales adicionales a la compra general. Elige solo una especialización.") end
  if skill==165 then texto=texto.."\n"..T("Peletería de escamas de dragón (opcional): nivel de personaje 40 y habilidad 225 (confirma la habilidad en el cliente). Alianza: Peter Galen, Azshara (37.4, 65.4), misión 5141. Horda: Thorkaf Dragonojo, Tierras Inhóspitas (62.6, 57.4), misión 5145. Entrega 2 petos de escórpido resistente, 2 guantes de escórpido resistente y 10 escamas de dragón desgastadas. Para fabricar los cuatro objetos: 36 cueros gruesos, 40 escamas de escórpido y 12 hilos de seda. Patrones de bandidos y ladrones de Tanaris o subasta. Compra los objetos terminados o sus reactivos, no ambos. Elige solo una especialización.") end
  local a=GL.ModalidadesProfesion975(skill)
  if #a>1 then texto=texto.." "..T("Cambia de plan en la tarjeta de profesión.") end
  return texto
end
function GL.CambiarPlanProfesion975(skill, modo)
  if not BASE[skill] or not DB() then return false end
  local permitido=false
  for _,v in ipairs(GL.ModalidadesProfesion975(skill)) do if v==modo then permitido=true end end
  if not permitido then return false end
  DB()[skill]=modo
  if GL.OFI and GL.OFI.reconstruir then GL.OFI.reconstruir() elseif GL.ProfesionesDelPersonaje and GL.RUTA then GL.ProfesionesDelPersonaje(GL.RUTA) end
  if GL.Refrescar then GL.Refrescar() end
  return true
end
-- Estimación por tramo, no punto garantizado. Cálculo proporcional de fabricaciones
-- restantes, redondeado hacia arriba; al comienzo mantiene el total original exacto.
local function Fabricaciones(d,h,c,nivel)
  if not c or c<=0 or h<=d then return nil end
  if not nivel or nivel<=d then return c end
  if nivel>=h then return 0 end
  return math.min(c,math.ceil(c*(h-nivel)/(h-d)))
end
GL.FabricacionesProfesion975=Fabricaciones
function GL.NecesarioProfesion975(p,m,nivel)
  if not m or not m[2] or m[2]<=0 then return 0 end
  if p.c975 and m.total975 then
    local n=Fabricaciones(p.d,p.h,p.c975,nivel)
    if not n then return 0 end
    if n==p.c975 then return m.total975 end
    return math.ceil(n*m.total975/p.c975)
  end
  return math.ceil(m[2]*math.max(0,p.h-math.max(p.d,nivel or p.d)))
end
function GL.MaterialBiblioteca975(t,m,nivel)
  local n=Fabricaciones(t.d,t.h,t.c,nivel)
  if n==nil then return m[2] end
  if n==t.c then return m[2] end
  return math.ceil(n*m[2]/t.c)
end
local function CantidadSegura(f,id)
  if type(f)~="function" then return nil end
  local ok,n=pcall(f,id)
  if not ok or (issecretvalue and issecretvalue(n)) or type(n)~="number" or n~=n or n<0 or n==math.huge or n%1~=0 then return nil end
  return n
end
local function Inventario(id)
  local moderno=C_Item and C_Item.GetItemCount
  local n=CantidadSegura(function(i) return moderno(i,true) end,id)
  if n~=nil then return n end
  if type(GetItemCount)=="function" and GetItemCount~=moderno then
    return CantidadSegura(function(i) return GetItemCount(i,true) end,id)
  end
  return nil
end
GL.InventarioProfesion975=Inventario
-- Mantener la incertidumbre incluso al reutilizar el stock simulado.
local stockIncierto=setmetatable({}, {__mode="k"})
local function ExistenciasReserva(stock,contar,id)
  local n=stock and stock[id]
  if n==nil then
    n=CantidadSegura(contar,id)
    return n or 0,n==nil
  end
  n=CantidadSegura(function() return n end,id)
  local incierto=stockIncierto[stock]
  return n or 0,n==nil or (incierto and incierto[id]) or false
end
-- No se suma dos veces un componente producido en un paso anterior. Simulación
-- conservadora de las cantidades del plan, no predicción exacta de skill-ups.
function GL.ComprasProfesion975(prof,nivel,contar)
  local stock, faltan, datos, orden = {}, {}, {}, {}
  nivel=tonumber(nivel) or 1
  contar=contar or Inventario
  local desconocido=false
  local inciertos={}
  stockIncierto[stock]=inciertos
  local function Inicializar(id,nombre)
    if stock[id]==nil then
      local n=CantidadSegura(contar,id)
      if n==nil then desconocido=true; inciertos[id]=true end
      stock[id]=n or 0
      datos[id]={id=id,nombre=nombre or tostring(id),tengo=n,usado=0,producido=0,falta=0}
      orden[#orden+1]=id
    elseif nombre then datos[id].nombre=nombre end
  end
  local sinDatos=0
  for _,p in ipairs(prof.pasos or {}) do
    if nivel<p.h then
      local tramoSinDatos=not p.mat or #p.mat==0
      for _,m in ipairs(p.mat or {}) do
        if type(m[1])=="number" and m[1]>0 and m[1]%1==0 and type(m[2])=="number" and m[2]>0 then
          Inicializar(m[1],m[3]); local n=GL.NecesarioProfesion975(p,m,nivel)
          local sobra=math.max(0,stock[m[1]]-n)
          local falta=math.max(0,n-stock[m[1]])
          stock[m[1]]=sobra
          datos[m[1]].usado=datos[m[1]].usado+n
          datos[m[1]].falta=datos[m[1]].falta+falta
        else tramoSinDatos=true end
      end
      if tramoSinDatos then sinDatos=sinDatos+1 end
      -- Only known outputs and reference counts; no assumptions for legacy routes.
      if p.c975 and p.produce975 and p.crea and p.crea[1] then
        local id=p.crea[1]; Inicializar(id)
        local n=(Fabricaciones(p.d,p.h,p.c975,nivel) or 0)*p.produce975
        stock[id]=stock[id]+n; datos[id].producido=datos[id].producido+n
      end
    end
  end
  for _,id in ipairs(orden) do if datos[id].usado>0 then faltan[#faltan+1]=datos[id] end end
  table.sort(faltan,function(a,b)
    local na,nb=tostring(a.nombre),tostring(b.nombre)
    if na~=nb then return na<nb end
    return a.id<b.id
  end)
  return faltan,sinDatos,desconocido,stock
end
-- Materiales de desbloqueo separados de fabricación: no duplicar inventario.
function GL.MaterialesMisionAlquimia977(prof,nivel,fac,hecha)
  if prof.skill~=171 or prof.modo975~="referencia" or nivel>=300 then return {} end
  if fac~="Alliance" and fac~="Horde" then return {} end
  local function completada(id)
    local f=hecha or (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    if not f then return false end
    local ok,v=pcall(f,id); return ok and (v==true or v==1)
  end
  local a={}
  local function add(q,id,n,nombre)
    if not completada(q) then a[#a+1]={q=q,id=id,cantidad=n,nombre=nombre} end
  end
  if fac=="Alliance" then
    add(92109,3371,5,"Vial vacío"); add(92109,2447,5,"Flor de paz"); add(92109,765,5,"Hojaplata")
    add(92110,730,3,"Ojo de múrloc")
  else
    add(429,3164,3,"Corazón de huargo descolorido"); add(91920,730,3,"Ojo de múrloc")
  end
  return a
end
function GL.AvisoMaterialesMisionAlquimia977(prof,nivel,fac,hecha)
  local out={}
  for _,m in ipairs(GL.MaterialesMisionAlquimia977(prof,nivel,fac,hecha)) do
    out[#out+1]=T("Reserva adicional para misión (si falta completar): ")..m.q.." - "..T(m.nombre).." x"..m.cantidad
    if m.q==429 then out[#out+1]=T("Corazones: algunas fuentes indican 6; confirma el objetivo en el diario.") end
  end
  return out
end
-- Optional alternatives, each calculated independently against remaining plan stock.
function GL.ReservasIngenieria977(prof,nivel,fac,contar,hecha,stock)
  if prof.skill~=202 or (fac~="Alliance" and fac~="Horde") then return {} end
  contar=contar or Inventario
  hecha=hecha or (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
  local function done(q)
    if not hecha then return false end
    local ok,v=pcall(hecha,q); return ok and (v==true or v==1)
  end
  local q=fac=="Alliance" and 3641 or 3643
  if done(3641) or done(3643) or done(3639) then return {} end
  if not stock then local _,_,_,r=GL.ComprasProfesion975(prof,nivel,contar); stock=r end
  local out={}
  for _,grupo in ipairs({{nombre="Ingeniería gnómica",q=q,items={{10559,6,"Tubo de mitril"},{4392,2,"Muñeco-diana avanzado"},{4407,1,"Mira de precisión"}}},{nombre="Ingeniería goblin",q=3639,items={{4394,20,"Bomba grande de hierro"},{10507,20,"Dinamita sólida"},{4384,5,"Oveja explosiva"}}}}) do
    for _,m in ipairs(grupo.items) do
      local n,incierto=ExistenciasReserva(stock,contar,m[1])
      out[#out+1]={grupo=grupo.nombre,q=grupo.q,id=m[1],nombre=m[3],cantidad=m[2],falta=math.max(0,m[2]-n),desconocido=incierto}
    end
  end
  return out
end
-- Reservas independientes de Peletería: objetos de entrega, no reactivos duplicados.
function GL.ReservasPeleteria977(prof,nivel,fac,contar,hecha,stock)
  if prof.skill~=165 or (fac~="Alliance" and fac~="Horde") then return {} end
  contar=contar or Inventario
  hecha=hecha or (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
  for _,q in ipairs({5141,5143,5144,5145,5146,5148}) do
    if hecha then local ok,v=pcall(hecha,q); if ok and (v==true or v==1) then return {} end end
  end
  if not stock then local _,_,_,r=GL.ComprasProfesion975(prof,nivel,contar); stock=r end
  local a=fac=="Alliance"
  local out={}
  for _,g in ipairs({
    {nombre="Peletería elemental",q=a and 5144 or 5146,items={{7077,2,"Corazón de fuego"},{7079,2,"Globo de agua"},{7075,2,"Núcleo de tierra"},{7081,2,"Aliento de viento"}}},
    {nombre="Peletería tribal",q=a and 5143 or 5148,items={{8211,1,"Jubón de cuero salvaje"},{8214,1,"Yelmo de cuero salvaje"}}},
    {nombre="Peletería de escamas de dragón",q=a and 5141 or 5145,items={{8203,2,"Peto de escórpido resistente"},{8204,2,"Guantes de escórpido resistente"},{8165,10,"Escama de dragón desgastada"}}}
  }) do
    for _,m in ipairs(g.items) do
      local n,incierto=ExistenciasReserva(stock,contar,m[1])
      out[#out+1]={grupo=g.nombre,q=g.q,id=m[1],nombre=m[3],cantidad=m[2],falta=math.max(0,m[2]-n),desconocido=incierto}
    end
  end
  return out
end
local function Seleccionada()
  local lista=GL.RUTA and GL.RUTA.profesiones or {}
  local db=GuiaAventureroDB or {}
  local p=lista[db.profesion or 1]
  return p and p.skill and p or nil
end
local function Mostrar(lineas)
  local texto=table.concat(lineas,"\n")
  if GL.MostrarInforme then local ok=pcall(GL.MostrarInforme,texto); if ok then return texto end end
  if GL.Mensaje then for _,s in ipairs(lineas) do GL.Mensaje(s) end end
  return texto
end
GL.comandos=GL.comandos or {}
GL.comandos.planprofesion=function(arg)
  local p=Seleccionada(); if not p then return Mostrar({T("Abre Profesiones y selecciona una profesión aprendida.")}) end
  local modo=tostring(arg or ""):match("^%s*(%S+)")
  if modo and GL.CambiarPlanProfesion975(p.skill,modo) then return Mostrar({p.nombre..": "..GL.EtiquetaPlan975(modo)}) end
  local l={p.nombre.." - "..T("Planes disponibles")}
  for _,v in ipairs(GL.ModalidadesProfesion975(p.skill)) do l[#l+1]="/ga planprofesion "..v.." - "..GL.EtiquetaPlan975(v) end
  l[#l+1]=GL.AyudaPlan975(p.skill,GL.ModoProfesion975(p.skill)); return Mostrar(l)
end
-- El límite aprendido, no la habilidad actual, determina si falta el libro.
function GL.LibroCocina977(prof,nivel,tope,contar)
  if prof.skill~=185 or type(tope)~="number" or tope<=0 or tope>150 or (tonumber(nivel) or 0)>=225 then return nil end
  local n=CantidadSegura(contar or Inventario,16072)
  return {id=16072, cantidad=1, falta=math.max(0,1-(n or 0)), desconocido=n==nil}
end
-- Cocina Artesano: reserva independiente de los reactivos de fabricación.
function GL.ReservaCocinaArtesano977(prof,nivel,tope,contar,hecha,stock)
  if prof.skill~=185 or type(tope)~="number" or tope<=0 or tope>225 or (tonumber(nivel) or 0)>=300 then return {} end
  hecha=hecha or (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
  if hecha then local ok,v=pcall(hecha,6610); if ok and (v==true or v==1) then return {} end end
  contar=contar or Inventario
  local out={}
  for _,m in ipairs({{12207,12,"Huevo gigante"},{7974,10,"Carne de almeja sabrosa"},{8932,20,"Queso suizo de Alterac"}}) do
    local n,incierto=ExistenciasReserva(stock,contar,m[1])
    out[#out+1]={id=m[1],nombre=m[3],cantidad=m[2],falta=math.max(0,m[2]-n),desconocido=incierto}
  end
  return out
end
GL.comandos.compraprofesion=function()
  local p=Seleccionada(); if not p then return Mostrar({T("Abre Profesiones y selecciona una profesión aprendida.")}) end
  local nivel,tope=GL.NivelProfesion(p); if not nivel then return Mostrar({T("No tienes esta profesión.")}) end
  local lista,sinDatos,desconocido,stock=GL.ComprasProfesion975(p,nivel)
  local l={T("COMPRA ESTIMADA HASTA 300")..": "..p.nombre.." "..nivel.."/300"}
  if tope and tope<300 then l[#l+1]=T("Límite actual de habilidad: ")..tope..". "..T("Aprende el siguiente rango antes de alcanzarlo.") end
  local libro=GL.LibroCocina977(p,nivel,tope)
  if libro then
    l[#l+1]=T("Desbloqueo de Cocina Experto: Libro de cocina para expertos (16072), desde habilidad 125; precio base 1 oro.")
    l[#l+1]=T("Libro de cocina para expertos")..": "..T("faltan ")..libro.falta..(libro.desconocido and " (?)" or "")
  end
  local cocina=GL.ReservaCocinaArtesano977(p,nivel,tope,nil,nil,stock)
  if #cocina>0 then
    l[#l+1]=T("Cocina Artesano: misión 6610, Dirge Hojágil, Gadgetzan (52.6, 28.1). Nivel 35 y Cocina 225. Reserva estos objetos aparte de la fabricación.")
    for _,m in ipairs(cocina) do l[#l+1]=T(m.nombre)..": "..T("faltan ")..m.falta..(m.desconocido and " (?)" or "") end
  end
  local faltantes=0
  for _,m in ipairs(lista) do
    if m.falta>0 then faltantes=faltantes+1; l[#l+1]=T(m.nombre)..": "..T("faltan ")..m.falta.." ("..T("producción prevista: ")..m.producido..")" end
  end
  if #lista==0 and sinDatos==0 then l[#l+1]=T("No hay materiales de fabricación en los tramos restantes.")
  elseif faltantes==0 and not desconocido then l[#l+1]=T("Tienes los materiales cuantificados necesarios para la fabricación estimada.") end
  if desconocido then l[#l+1]=T("Inventario no disponible para algunos objetos; se ha supuesto cero para la estimación.") end
  l[#l+1]=T("Tramos sin materiales cuantificados: ")..sinDatos
  l[#l+1]=T("Estimación, no compra garantizada: revisa la habilidad, recetas aprendidas, existencias, límites de rango y precios. Los componentes producidos en el plan se descuentan solo después de fabricarlos en la simulación. No se descuentan los materiales de las misiones de desbloqueo.")
  for _,aviso in ipairs(GL.AvisoMaterialesMisionAlquimia977(p,nivel,UnitFactionGroup and UnitFactionGroup("player"))) do l[#l+1]=aviso end
  local reservas=GL.ReservasIngenieria977(p,nivel,UnitFactionGroup and UnitFactionGroup("player"),nil,nil,stock)
  if p.skill==165 then reservas=GL.ReservasPeleteria977(p,nivel,UnitFactionGroup and UnitFactionGroup("player"),nil,nil,stock) end
  if #reservas>0 then l[#l+1]=T("Especializaciones opcionales: elige solo una. Faltantes tras completar el plan, no disponibles necesariamente ahora.") end
  for _,m in ipairs(reservas) do l[#l+1]=T(m.grupo).." - "..T(m.nombre)..": "..T("faltan ")..m.falta..(m.desconocido and " (?)" or "") end
  return Mostrar(l)
end
-- Traducir los textos de alternativas al construirlas, no mutar el catálogo original.
-- Las tablas de alternativas son españolas; construir la vista con las cadenas traducidas.
local PlanBase=GL.PlanProfesion975
function GL.PlanProfesion975(skill,modo)
  local p=PlanBase(skill,modo)
  if not p or not (MODOS[skill] and MODOS[skill][modo]) or not GL.ingles then return p end
  local lista={}
  for _,t in ipairs(p.tramos) do
    local c={}; for k,v in pairs(t) do c[k]=v end
    c.recetaOriginal9775=t.recetaOriginal9775 or t.r; c.r=T(t.r); c.zonas=t.zonas; c.de=t.de and T(t.de); c.horda975=t.horda975
    lista[#lista+1]=c
  end
  p.tramos=lista; return p
end

-- Secundarias.lua (9.5): la pestaña Profesiones enseña las profesiones que el personaje ha aprendido (no las
-- que recomienda la ruta), cada una con su guía para subirla. Si la ruta trae guía de esa profesión, se usa la de
-- la ruta; si no, se arma con las guías de profesiones de DatosWowhead.lua (las mismas de la Biblioteca) y, con
-- la Horda, sus instructores y vendedores (profesionesHorda). Cocina y Pesca salen así para todas las rutas.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local ICONOS = { [185] = "Interface\\Icons\\INV_Misc_Food_15", [356] = "Interface\\Icons\\Trade_Fishing",
  [197] = "Interface\\Icons\\Trade_Tailoring", [171] = "Interface\\Icons\\Trade_Alchemy", [164] = "Interface\\Icons\\Trade_BlackSmithing",
  [333] = "Interface\\Icons\\Trade_Engraving", [202] = "Interface\\Icons\\Trade_Engineering", [165] = "Interface\\Icons\\Trade_LeatherWorking",
  [186] = "Interface\\Icons\\Trade_Mining", [182] = "Interface\\Icons\\Trade_Herbalism", [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
  [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" }
-- en el orden de la ventana de habilidades: principales y luego secundarias. es/en: para reconocerlas por el nombre.
local ORDEN = {
  { 171, "Alquimia", "Alchemy" }, { 164, "Herrería", "Blacksmithing" }, { 333, "Encantamiento", "Enchanting" },
  { 202, "Ingeniería", "Engineering" }, { 182, "Herboristería", "Herbalism" }, { 165, "Peletería", "Leatherworking" },
  { 186, "Minería", "Mining" }, { 393, "Desuello", "Skinning" }, { 197, "Sastrería", "Tailoring" },
  { 129, "Primeros auxilios", "First Aid" }, { 185, "Cocina", "Cooking" }, { 356, "Pesca", "Fishing" },
  { 40, "Venenos", "Poisons" },   -- del pícaro: va con las secundarias
}
local SECUNDARIAS = { [129] = true, [185] = true, [356] = true, [40] = true }
local NOMBRES, NOMBRES_EN = {}, {}
for _, o in ipairs(ORDEN) do NOMBRES[o[1]], NOMBRES_EN[o[1]] = o[2], o[3] end
local function NombreCliente(skill, fallback)
  return (GL.clienteIngles and NOMBRES_EN[skill] or NOMBRES[skill]) or fallback
end

-- Instructores de Cocina contrastados documentalmente en Forever; rango Oficial pendiente de confirmar en cliente.
local INTRO_COCINA = {
  Alliance = "No ocupa una de tus dos profesiones. Instructores: Tomas (Villadorada), Gremlock Pilsnor (Kharanos), Zarrin (Dolanaar), Stephen Ryback (Ventormenta), Daryl Riknussun (Forjaz) y Alegorn (Darnassus). Aprendiz hasta 75 sin requisito de nivel según guías de Forever. Aprende Oficial desde habilidad 50 antes de llegar a 75; algunas fuentes indican nivel 10, otras no exigen nivel de personaje. Confirma con el instructor. Hasta 150 con instructor; para Experto, desde habilidad 125 y antes de superar 150, compra el <Libro de cocina para expertos> (ID 16072; precio base 1 oro) a Shandrina (Vallefresno, 49.6, 67.0), vendedora de la Alianza, o búscalo en la subasta. A 225 y nivel de personaje 35, completa <Sorpresa de almejates> de Dirge Hojágil (Gadgetzan, Tanaris, 52.6, 28.0): necesitas 12 huevos gigantes, 10 carnes de almeja sabrosa y 20 quesos suizos de Alterac. Así desbloqueas Artesano 225-300. Las recetas y materiales dependen de tu habilidad y de la disponibilidad de ingredientes.",
  Horde = "No ocupa una de tus dos profesiones. Instructores: Cocinero Torka (Cerrotajo), Pyall Trancosilencio (Poblado Pezuña de Sangre), William Pickman (Brill), Zamja (Orgrimmar) y Aska Mistrunner (Cima del Trueno). Aprendiz hasta 75 sin requisito de nivel según guías de Forever. Aprende Oficial desde habilidad 50 antes de llegar a 75; algunas fuentes indican nivel 10, otras no exigen nivel de personaje. Confirma con el instructor. Hasta 150 con instructor; para Experto, desde habilidad 125 y antes de superar 150, compra el <Libro de cocina para expertos> (ID 16072; precio base 1 oro) a Wulan (Poblado Cazasombras, Desolace, 26.2, 69.8), vendedora de la Horda, o búscalo en la subasta. A 225 y nivel de personaje 35, completa <Sorpresa de almejates> de Dirge Hojágil (Gadgetzan, Tanaris, 52.6, 28.0): necesitas 12 huevos gigantes, 10 carnes de almeja sabrosa y 20 quesos suizos de Alterac. Así desbloqueas Artesano 225-300. Las recetas y materiales dependen de tu habilidad y de la disponibilidad de ingredientes.",
}
-- 9.7: Wowhead Forever exige manual para Experto y misión de triaje para Artesano.
local INTRO_PRIMEROS_AUXILIOS = {
  Alliance = "Primeros auxilios: hasta 150 con instructor (aprende Oficial antes de llegar a 75). Para Experto 150-225, compra <Primeros auxilios para expertos: Entre vendas>, <Manual: venda de seda gruesa> y <Manual: venda de tejido mágico> a Deneb Camino (Castillo de Stromgarde, Tierras Altas de Arathi, 27.0, 58.8), o en la subasta. A habilidad 225 y nivel de personaje 35, habla con la doctora Nissa Piedra de Fuego en Forjaz para la misión de introducción <Trauma de la Alianza>, o ve a la misión <Triaje> del doctor Gustaf VanHowzen (Theramore, 67.6, 48.8). La misión de introducción normalmente es opcional, pero si Triaje no aparece hazla primero. Tras Triaje, aprende allí las recetas nuevas al 240, 260 y 290. Las cantidades de vendajes son estimadas.",
  Horde = "Primeros auxilios: hasta 150 con instructor (aprende Oficial antes de llegar a 75). Para Experto 150-225, compra <Primeros auxilios para expertos: Entre vendas>, <Manual: venda de seda gruesa> y <Manual: venda de tejido mágico> a Balai Lok'Wein (Poblado Murohelecho, Marjal Revolcafango, 36.4, 30.4), o en la subasta. A habilidad 225 y nivel de personaje 35, habla con Arnok en Orgrimmar para la misión de introducción <Trauma de la Horda>, o ve a la misión <Triaje> del doctor Gregory Victor (Sentencia, Tierras Altas de Arathi, 73.4, 36.8). La misión de introducción normalmente es opcional, pero si Triaje no aparece hazla primero. Tras Triaje, aprende allí las recetas nuevas al 240, 260 y 290. Las cantidades de vendajes son estimadas.",
}
local INTRO_CANTIDADES = "Las cantidades de fabricación son estimaciones, no una garantía: las recetas amarillas y verdes pueden necesitar materiales adicionales. Antes de alcanzar los límites 75, 150 y 225, comprueba el siguiente rango de la profesión."
local INTRO_PESCA_EXTRA = "No ocupa una de tus dos profesiones. Con el modo pesca (botón en pantalla) un clic te pone la caña y lanza, y otro saca el pez."

local INTRO_RANGOS = "Los rangos se aprenden con el instructor de la profesión en tu ciudad: Oficial a 50 (nivel 10), Experto a 125 (nivel 20) y Artesano a 200 (nivel 35). Tramos de las guías de profesiones de Wowhead (Forever)."

local function Faccion() return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "Horde" or "Alliance" end

local function DeWowhead(skill)
  for _, p in ipairs((GL.WH and GL.WH.profesiones) or {}) do
    if p.skill == skill then return p end
  end
end

local function Pasos(p, PH)
  local pasos = {}
  for _, t in ipairs(p.tramos or {}) do
    local texto
    if not t.mat then
      local zonas = t.zonas
      if zonas and GL.LC then zonas = zonas:gsub("[^,]+", function(z) local a, b, c = z:match("^(%s*)(.-)(%s*)$"); return a .. GL.LC(b) .. c end) end
      texto = L(t.r) .. (zonas and ("\n" .. L"Dónde: " .. zonas) or "")
    else
      local mats = {}
      for _, m in ipairs(t.mat or {}) do table.insert(mats, "<" .. ((GL.T and GL.T(m[3])) or m[3]) .. ">") end
      texto = "<" .. L(t.r) .. ">" .. (t.c and (" ×" .. t.c) or "") ..
        (#mats > 0 and (L" con " .. table.concat(mats, ", ")) or "") .. "."
      local de = GL.OrigenProfesion975 and GL.OrigenProfesion975(t, Faccion()) or (t.de and ((PH and PH.de and PH.de[t.de]) or t.de))
      if de and de ~= "Conocido" and de ~= "Known" then texto = texto .. " " .. L"Receta: " .. de .. "." end
    end
    local mat
    if t.mat and t.c and t.c > 0 then
      mat = {}
      for _, m in ipairs(t.mat) do table.insert(mat, { m[1], m[2] / t.c, m[3], total975 = m[2] }) end
    end
    if t.ayuda975 then texto = texto .. " " .. L(t.ayuda975) end
    local receta = t.sp and t.r or nil
    local recetas = receta and {receta} or nil
    if receta then
      local original = t.recetaOriginal9775 or receta
      local cliente = GL.LC and GL.LC(original) or original
      if cliente ~= receta then recetas[#recetas+1] = cliente end
      if original ~= receta and original ~= cliente then recetas[#recetas+1] = original end
      local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
      if fn then
        local ok, nombre = pcall(fn, t.sp)
        if ok and type(nombre)=="string" and nombre~="" and nombre~=receta then recetas[#recetas+1]=nombre end
      end
    end
    local crea, unidades
    if GL.ResultadoProfesion975 then crea, unidades = GL.ResultadoProfesion975(t.sp) end
    table.insert(pasos, { d = t.d, h = t.h, icono = ICONOS[p.skill], t = texto, mat = mat,
      c975 = t.c, sp975 = t.sp, r975 = receta, recetas = recetas,
      crea = crea and { crea } or nil, produce975 = unidades, de975 = t.de, tramos975 = true })
  end
  return pasos
end

local function Hacer(skill, modo)
  local p = GL.PlanProfesion975 and GL.PlanProfesion975(skill, modo) or DeWowhead(skill)
  if not p or not p.tramos then return nil end
  local PH = (Faccion() == "Horde") and GL.WH.profesionesHorda or nil
  local intro
  if skill == 185 then
    intro = L(INTRO_COCINA[Faccion()]) .. " " .. L(INTRO_CANTIDADES)
  elseif skill == 129 then
    intro = L(INTRO_PRIMEROS_AUXILIOS[Faccion()])
  else
    local nota = (GL.NotaProfesion975 and GL.NotaProfesion975(p, Faccion())) or (PH and PH.nota and (PH.nota[p.n] or PH.nota[NOMBRES[skill]])) or p.nota or ""
    if nota == "" then nota = L(INTRO_RANGOS) end
    intro = (skill == 356 and (L(INTRO_PESCA_EXTRA) .. " ") or "") .. nota
    if not p.recoleccion then intro = intro .. " " .. L(INTRO_CANTIDADES) end
  end
  if skill == 356 then
    intro = intro .. "\n" .. L("Misión de Nat Pagle: con la misión activa, pesca Ahi de Feralas (Feralas), Mahi mahi de Juncobruma (Pantano de las Penas), Lucio de Sar’theris (Desolace) y Pez vela azul de la Costa Salvaje (Vega de Tuercespina) en aguas abiertas de las zonas correspondientes.") .. "\n" .. L("Señuelos: desde habilidad 1, Abalorio brillante +25; desde 50, Lombrices nocturnas o Lente acuadinámica para peces +50; desde 100, Abalorios relucientes o Gusano carnívoro +75 (10 min cada uno), o Atrayente acuadinámico para peces +100 (5 min).") .. "\n" .. L("Equipo: sombrero de pesca y botas de Nat Pagle +5 cada uno; sedal de eternio +5 en la caña; encantamiento de guantes +2. Las bonificaciones no sustituyen la habilidad base para aprender rangos.") .. "\n" .. L("Puedes subir Pesca hasta 300 en aguas iniciales tras desbloquear cada rango. Cambia de zona para conseguir ingredientes específicos de Cocina o Alquimia, no para acelerar los puntos.")
  end
  if skill == 356 then
    intro = intro .. "\n" .. L("Cañas: la caña de la familia Blump (Alianza, Auberdine) desde Pesca 1; Caña de pescar resistente desde 10 y nivel 5, vendedor; Gran caña de pescar de hierro desde 100 y nivel 25, trampas de marisco de Desolace; FC-5000 +25 desde 100, misión de Horda en Tierras del Interior; Caña de pescar de arcanita +35 desde 300, premio del concurso.")
    intro = intro .. "\n" .. L("Comida de pesca (15 min tras comer 10 s): Delicia de frenesí del lago +3 y Filete de frenesí +5 (nivel 5); Siluro mostacherizo +8 (15); Bacalao escamarroca +12 (25); Filete de agallas rojas +18 (35); Fletán aletaespina +18 (45).")
    intro = intro .. "\n" .. L("Alquimia: conserva Bocanegra aceitosa (costas de Los Baldíos, Humedales y Tuercespina), Pargo aletafuego (Humedales, Tanaris y Tuercespina) y Anguila escamapiedra (Azshara, Tanaris y Feralas) para aceites.")
    intro = intro .. "\n" .. L("Campamentos de pesca: pecera (20), secadero de pescado (140, peces poco comunes) y cabaña de pesca (300, peces raros). Los dos últimos requieren planos y dan acceso a capturas especiales durante una hora.")
    intro = intro .. "\n" .. L("Usa Cebos y aparejos para fabricar los campamentos. Colócalos junto a una hoguera de Cocina; comparten 60 minutos de reutilización. La bonificación de atributos no se acumula con Bendición de reyes.")
    intro = intro .. "\n" .. L("Concurso de Tuercespina: domingos de 14:00 a 16:00 (hora del servidor, horario previsto). Entrega 40 Pezsabroso moteado a Riggle Anzuelo en Bahía del Botín. Hasta 50 ganadores previstos; se han comunicado cierres anticipados.")
    intro = intro .. "\n" .. L("Premios: cambia la moneda del concurso con Jang. Los peces raros Pez ángel de Keefer, Corredor rayado azul de Brownell y Reina deziana permiten conseguir sombrero, botas y sedal respectivamente sin ganar el concurso principal.")
    intro = intro .. "\n" .. L("Aletacapricho: pesca en el río o lago pequeño al este del lago Plácido, Crestagrana, para Cocina. Los filetes de pescado de temporada se preparan con calamar de invierno o lubina de verano y se usan para la cabaña de pesca. La lista completa de capturas especiales se ampliará en próximas versiones.")
  end
  if GL.AyudaPlan975 then intro = intro .. "\n" .. GL.AyudaPlan975(skill, modo) end
  return { nombre = NombreCliente(skill, p.n), skill = skill, icono = ICONOS[skill], intro = intro, pasos = Pasos(p, PH), secundaria = true, modo975 = modo, plan975 = true }
end

-- Read-only builder for comparing the available plans, without selecting one.
GL.ConstruirPlanProfesion976 = Hacer

-- ¿la ha aprendido? (por id o por su nombre en español o inglés)
local function Aprendida(o)
  if not GL.NivelProfesion then return nil end
  for k = 2, 3 do
    local ok, r = pcall(GL.NivelProfesion, { nombre = o[k], skill = o[1] })
    if ok and r then return r end
  end
end

-- Se llama al cargar la ruta (ya traducida, GuiaAventurero.lua Iniciar) y cuando cambian tus habilidades.
-- Devuelve true si la lista ha cambiado.
function GL.ProfesionesDelPersonaje(R)
  if type(R) ~= "table" then return false end
  if not R.profesionesRuta then R.profesionesRuta = R.profesiones or {} end
  local deRuta = {}
  for _, p in ipairs(R.profesionesRuta) do if p.skill then deRuta[p.skill] = p end end
  R.guiasHechas = R.guiasHechas or {}
  local lista, firma = {}, {}
  for _, o in ipairs(ORDEN) do
    if Aprendida(o) then
      local modo = GL.ModoProfesion975 and GL.ModoProfesion975(o[1]) or "referencia"
      local clave = tostring(o[1]) .. ":" .. modo
      local prof = (modo == "ruta" and deRuta[o[1]]) or R.guiasHechas[clave]
      if not prof and not DeWowhead(o[1]) then prof = deRuta[o[1]] end
      if not prof then
        local ok, hecha = pcall(Hacer, o[1], modo)
        prof = ok and hecha or { nombre = NombreCliente(o[1], o[2]), skill = o[1], icono = ICONOS[o[1]], pasos = {},
          intro = L"Todavía no hay guía para subir esta profesión." }
        R.guiasHechas[clave] = prof
      end
      prof.icono = prof.icono or ICONOS[o[1]]
      table.insert(lista, prof)
      table.insert(firma, clave)
    end
  end
  -- las principales que recomienda la ruta para tu clase
  local recom = {}
  for _, p in ipairs(R.profesionesRuta) do
    if p.skill and NOMBRES[p.skill] and not SECUNDARIAS[p.skill] then table.insert(recom, p) end
  end
  if #lista == 0 then
    -- 9.5: a la vista, con iconos: qué principales recomienda la guía y que las tres secundarias van todas
    local AMA, VER, BLA, GRI, FIN = "|cffffd100", "|cff4dd966", "|cffffffff", "|cffb4b4b8", "|r"
    local function Icono(skill, icono) return "|T" .. (icono or ICONOS[skill] or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":18:18|t " end
    local l = { AMA .. L"Puedes aprender 2 profesiones principales" .. FIN }
    if #recom > 0 then
      table.insert(l, GRI .. L"Las que recomienda la guía para tu clase:" .. FIN)
      local r = {}
      for _, p in ipairs(recom) do table.insert(r, Icono(p.skill, p.icono) .. VER .. p.nombre .. FIN) end
      table.insert(l, "   " .. table.concat(r, "     "))
    end
    table.insert(l, " ")
    table.insert(l, AMA .. L"Y las 3 secundarias, todas a la vez" .. FIN .. GRI .. L" (no cuentan para ese límite):" .. FIN)
    table.insert(l, "   " .. Icono(129) .. BLA .. L(NOMBRES[129]) .. FIN .. "     " .. Icono(185) .. BLA .. L(NOMBRES[185]) .. FIN ..
      "     " .. Icono(356) .. BLA .. L(NOMBRES[356]) .. FIN)
    table.insert(l, " ")
    table.insert(l, GRI .. L"Cuando aprendas una con su instructor, aquí saldrá su guía para subirla." .. FIN)
    table.insert(lista, { nombre = L"Elige tus profesiones", vacia = true, icono = "Interface\\Icons\\INV_Pick_02", pasos = {},
      intro = table.concat(l, "\n") })
  end
  firma = table.concat(firma, ",")
  local cambia = firma ~= R.firmaProfesiones
  R.firmaProfesiones = firma
  R.profesiones = lista
  return cambia
end

-- Estimación conjunta de ingredientes de pescado de los planes activos, sin duplicar bolsas.
local PECES977 = {[6291]=true,[6289]=true,[6308]=true,[8365]=true,[4603]=true,[13893]=true,[13759]=true,[13758]=true,[13760]=true,[13888]=true,[13889]=true,[13754]=true,[13755]=true,[6361]=true,[6362]=true,[6358]=true,[6359]=true,[13422]=true}
function GL.NecesidadesPesca977(profesiones, obtenerNivel, contar)
  local total,lista,vistas={},{},{}
  obtenerNivel=obtenerNivel or GL.NivelProfesion
  if not obtenerNivel or not GL.ComprasProfesion975 then return lista end
  contar=contar or function(id)
    local f=(C_Item and C_Item.GetItemCount) or GetItemCount
    if f then local ok,n=pcall(f,id,false); if ok and type(n)=="number" then return n end end
  end
  for _,prof in ipairs(profesiones or {}) do
    if (prof.skill==185 or prof.skill==171) and not vistas[prof.skill] then
      vistas[prof.skill]=true
      local n=obtenerNivel(prof)
      if type(n)=="number" and n>0 and n<300 then
        for _,m in ipairs(GL.ComprasProfesion975(prof,n,function() return 0 end)) do
          if PECES977[m.id] and m.falta>0 then
            local t=total[m.id] or {id=m.id,nombre=m.nombre,cantidad=0}
            t.cantidad=t.cantidad+m.falta; total[m.id]=t
          end
        end
      end
    end
  end
  for id,t in pairs(total) do
    local n=contar(id); t.desconocido=type(n)~="number"
    t.falta=math.max(0,t.cantidad-math.max(0,tonumber(n) or 0))
    if t.falta>0 then lista[#lista+1]=t end
  end
  table.sort(lista,function(a,b) if a.falta==b.falta then return a.id<b.id end return a.falta>b.falta end)
  return lista
end

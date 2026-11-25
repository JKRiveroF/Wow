-- 9.7.6: on-demand tools. No changes to leveling routes, XP, or other addons.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L or function(x) return x end
local function DB() return type(GuiaAventureroDB)=="table" and GuiaAventureroDB or nil end
local function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end
local function norm(s)
  s=trim(s):lower()
  for a,b in pairs({["á"]="a",["é"]="e",["í"]="i",["ó"]="o",["ú"]="u",["Á"]="a",["É"]="e",["Í"]="i",["Ó"]="o",["Ú"]="u",["Ñ"]="n",["ñ"]="n"}) do s=s:gsub(a,b) end
  return s
end
local function call(f,...)
  if type(f)~="function" then return nil end
  local ok,a,b,c=pcall(f,...); if ok then return a,b,c end
end
local function show(lines)
  local s=table.concat(lines,"\n")
  if GL.MostrarInforme then GL.MostrarInforme(s) elseif GL.Mensaje then GL.Mensaje(s) end
  return s
end
function GL.JefesVisibles976(z)
 local src=GL.WH and GL.WH.jefes and GL.WH.jefes[z] or {}; local fac=call(UnitFactionGroup,"player"); local out={}
 if issecretvalue then
   local ok, secreto=pcall(issecretvalue,fac)
   if not ok or secreto then fac=nil end
 end
 if fac~="Alliance" and fac~="Horde" then fac=nil end
 for _,b in ipairs(src) do if not b.fac or b.fac==fac then out[#out+1]=b end end; return out
end
local function EstadoQuestieSeguro()
  local estado=call(GL.QuestieEstado97)
  if issecretvalue then
    local ok, secreto=pcall(issecretvalue,estado)
    if not ok or secreto then return nil end
  end
  if type(estado)=="boolean" then return estado end
  return nil
end
local function ConvivenciaSegunEstado(estado)
  local db=DB()
  return db ~= nil and db.questie976==true and estado~=false
end
function GL.QuestieConvivencia976()
  local db=DB(); if not db or db.questie976~=true then return false end
  return ConvivenciaSegunEstado(EstadoQuestieSeguro())
end
local ultimoEstadoQuestie
-- Shared transition handler for configuration and late loading. No polling.
function GL.SincronizarQuestie976(forzar, antes)
  if not DB() then return false end
  local ahora=GL.QuestieConvivencia976()
  if antes==nil then antes=ultimoEstadoQuestie end
  if not forzar and antes==ahora then return false end
  ultimoEstadoQuestie=ahora
  if ahora then
    call(GL.LiberarMarcaPropia976)
  elseif antes==true then
    call(GL.ActualizarMarca,true)
  end
  call(GL.ActualizarPines)
  call(GL.ActualizarSeguimiento976)
  return true
end
function GL.ConfigurarQuestie976(value)
  local db=DB(); if not db then return false end
  -- Restaurar segun el ultimo estado aplicado, no una lectura transitoria.
  local antes=ultimoEstadoQuestie
  if antes==nil then antes=GL.QuestieConvivencia976() end
  db.questie976=value==true
  GL.SincronizarQuestie976(true,antes)
  return true
end
function GL.CargaQuestie976()
  GL.SincronizarQuestie976(true)
  -- Some clients expose the loaded state only after ADDON_LOADED returns.
  if C_Timer and type(C_Timer.After)=="function" then
    call(C_Timer.After,0,function() GL.SincronizarQuestie976() end)
  end
end
-- No periodic search: traverse data only on explicit request. Search both the original and translated names.
function GL.Buscar976(query,limit)
  local q=norm(query); limit=math.min(100,math.max(1,tonumber(limit) or 40))
  if #q<2 then return {L"Escribe al menos dos letras."} end
  local out,seen={},{}; local idq=tonumber(q)
  local function add(kind,name,id,context)
    if #out>=limit then return end
    name=tostring(name or ""); context=tostring(context or "")
    if name=="" and not id then return end
    if (idq and idq==tonumber(id)) or norm(name):find(q,1,true) or norm(L(name)):find(q,1,true) or norm(context):find(q,1,true) then
      local key=kind..":"..tostring(id or name)..":"..context
      if not seen[key] then seen[key]=true; out[#out+1]="["..L(kind).."] "..L(name)..(id and (" #"..id) or "")..(context~="" and (" — "..L(context)) or "") end
    end
  end
  local wh=GL.WH or {}
  local names={}; for k in pairs(wh.jefes or {}) do names[#names+1]=k end; table.sort(names)
  for _,zone in ipairs(names) do
    add("Mazmorra o banda",zone)
    for _,b in ipairs(GL.JefesVisibles976(zone)) do
      add("Jefe",b.n,b.npc,zone)
      for _,o in ipairs(b.botin or {}) do
        local id=tonumber(o.id); local name=o.n or (id and call(GetItemInfo,id)) or (id and (L"Objeto".." "..id))
        add("Botín",name,id,zone.." / "..tostring(b.n))
      end
    end
    if #out>=limit then break end
  end
  for _,p in ipairs(wh.profesiones or {}) do
    add("Profesión",p.n,p.skill)
    for _,mode in ipairs(call(GL.ModalidadesProfesion975,p.skill) or {"referencia"}) do
      local plan=call(GL.PlanProfesion975,p.skill,mode) or p
      for _,t in ipairs(plan.tramos or {}) do
        add("Receta",t.r,t.sp,p.n)
        for _,m in ipairs(t.mat or {}) do add("Material",m[3],m[1],p.n) end
      end
    end
  end
  for _,d in ipairs(call(GL.DatosMazmorras) or {}) do
    for _,m in ipairs(d.misiones or {}) do add("Misión",m.n,m.q,d.n); add("Destino",m.d,nil,m.n) end
  end
  local r=GL.RUTA or {}
  for _,s in ipairs(r.secciones or {}) do
    if #out>=limit then break end
    for _,p in ipairs(s.pasos or {}) do
      for _,w in ipairs(p.wp or {}) do
        add("Destino",w.n,w.q,w.z)
        local npc=type(w.n)=="string" and w.n:match("%(([^()]*)%)%s*$")
        if npc then add("PNJ (texto de ruta)",npc,nil,w.z) end
      end
      if #out>=limit then break end
    end
  end
  -- Optional quest tables may have nested metadata: only use the known flat ID tables.
  for _,k in ipairs({"opcionales","opcionalesH","opcionalesNuevas","opcionalesNuevasH"}) do
    if #out>=limit then break end
    local tab=wh[k] or {}
    for id,m in pairs(tab) do
      if type(m)=="table" and type(m.n)=="string" and type(id)=="number" then add("Misión",m.n,id) end
      if #out>=limit then break end
    end
  end
  if #out==0 then out[1]=L"No hay coincidencias. Los nombres de objetos sin caché pueden requerir una consulta por ID." end
  return out
end
-- Offer only same-step active quests/turn-ins in the current map. Never reorder or autoaccept future quests.
function GL.ViajeLocal976()
  local _,p=call(GL.PasoActual)
  local map=C_Map and call(C_Map.GetBestMapForUnit,"player")
  local out={L"Destinos pendientes de este paso en tu mapa"}; local n=0
  if map and p then
    for _,w in ipairs(p.wp or {}) do
      if w.m==map and not call(GL.DestinoHecho,w) then
        -- Keep the original order; do not suggest accepting a later mission out of sequence.
        n=n+1; out[#out+1]=tostring(w.n or w.q or "?")..(w.x and w.y and string.format(" (%.1f, %.1f)",w.x,w.y) or "")
      end
    end
  end
  if n==0 then out[#out+1]=L"No hay destinos locales pendientes confirmados." end
  out[#out+1]=L"Combina las visitas locales sin cambiar el orden de las cadenas. No se han modificado los pasos ni la experiencia."
  return out
end
-- Manual unit prices in copper; missing prices are not treated as free.
function GL.Precio976(id,precio)
  local db=DB(); id,precio=tonumber(id),tonumber(precio)
  if not db or not id or id<=0 or id%1~=0 or not precio or precio<0 or precio%1~=0 or precio>1000000000 then return false end
  db.precios976=type(db.precios976)=="table" and db.precios976 or {}; db.precios976[id]=precio; return true
end
function GL.Coste976(lista,precios)
  local total,faltan=0,0
  for _,m in ipairs(lista or {}) do
    local n=math.max(0,tonumber(m.falta) or 0)
    if n>0 then
      local p=precios and tonumber(precios[m.id]); if p and p>=0 then total=total+n*p else faltan=faltan+1 end
    end
  end
  return total,faltan
end
local function compraActual()
  local db=DB() or {}; local prof=GL.RUTA and GL.RUTA.profesiones and GL.RUTA.profesiones[db.profesion or 1]
  if not prof then return {L"Abre Profesiones y selecciona una profesión aprendida."} end
  local nivel=call(GL.NivelProfesion,prof); if not nivel then return {L"No tienes esta profesión."} end
  local lista,sinDatos,desconocido=call(GL.ComprasProfesion975,prof,nivel)
  if not lista then return {L"No hay datos de materiales para esta profesión."} end
  local coste,sinPrecio=GL.Coste976(lista,db.precios976)
  local out={prof.nombre or "?", L"Coste parcial estimado (cobre): "..coste, L"Materiales sin precio: "..sinPrecio, L"Tramos sin datos: "..tostring(sinDatos or "?")}
  for _,m in ipairs(lista) do if m.falta>0 then out[#out+1]=L(m.nombre or tostring(m.id)).." #"..m.id.." x"..m.falta end end
  if desconocido then out[#out+1]=L"Inventario incompleto; comprueba las existencias." end
  out[#out+1]=L"Introduce precios por unidad en cobre: /ga precio ID PRECIO. No se consulta la subasta ni se compran objetos."
  return out
end
local function personaje()
  local out={L"Resumen del personaje", (call(UnitLevel,"player") or "?").." / 60"}
  local gold=call(GetMoney); if type(gold)=="number" then out[#out+1]=L"Dinero (cobre): "..gold end
  local free=call(GL.HuecosGenerales976)
  if type(free)=="number" then out[#out+1]=L"Huecos libres en bolsas: "..free end
  local t=call(GL.PuntosTalentoLibres); if type(t)=="number" then out[#out+1]=L"Puntos de talento libres: "..t end
  local db=DB() or {}; if db.especializacion then out[#out+1]=L"Especialización"..": "..L(db.especializacion) end
  out[#out+1]=L"Consulta Personaje para comparar equipo, talentos y hechizos."
  return out
end
-- Tips authored from Icy Veins / Wowhead, not a live encounter journal.
local consejos={
  ["Vivo: Ezra Grimm"]="Despeja los enemigos cercanos antes de atacar al raro; evita atraer grupos adicionales. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Skul (raro)"]="Despeja la calle antes de atraer al raro y reserva interrupciones para sus hechizos. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Escupezones Foreste (raro)"]="Despeja la zona del raro y mantén al sanador fuera del alcance cuerpo a cuerpo. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: El imperdonable"]="Despeja la calle y reserva defensivos para el tanque; evita atraer patrullas. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Jefe de correos Gassol"]="Comprueba los buzones y las oleadas antes de activar el encuentro; protege al sanador. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Timmy el Cruel"]="Despeja el patio y prepara defensivos para el daño cuerpo a cuerpo. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Malor el Entusiasta"]="Controla los cruzados cercanos antes de entrar en combate y revisa el objetivo de misión. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Maestro cañonero Willey"]="Evita el fuego de los cañones y prioriza los refuerzos si aparecen. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Archivista Galford"]="Interrumpe los hechizos cuando sea posible y aléjate del fuego de área. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Gran Cruzado Dathrohan / Balnazzar"]="Reserva recursos para la transformación y reacciona al miedo y al control mental. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["No-muerto: Magistrado Barthilas"]="Despeja la entrada antes de combatir y comprueba si necesitas la llave de la ciudad. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["No-muerto: Pidrespina"]="Controla las criaturas cercanas y evita atraer patrullas durante el combate. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["No-muerto: Nerub'enkan"]="Prioriza los acompañantes si aparecen y elimina venenos cuando sea posible. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["No-muerto: Armero Guardia Negra"]="Despeja la zona de la forja y verifica el objetivo de misión antes de salir. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["No-muerto: Baronesa Anastari"]="Prepárate para la posesión; controla al jugador afectado sin matarlo. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["No-muerto: Maleki el Pálido"]="Interrumpe los hechizos de hielo y disipa efectos mágicos cuando sea posible. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["No-muerto: Ramstein el Empachador"]="Elimina las abominaciones previas y reserva recursos para las oleadas posteriores. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["No-muerto: Barón Osahendido"]="Mantén al grupo lejos del aura cuando sea posible y elimina los esqueletos invocados. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",
  ["Vivo: Sothos y Jarien (invocados)"]="Encuentro opcional: verifica el objeto de invocación y controla ambos enemigos; concentra el daño en uno. Consejo orientativo; mecánicas de Forever pendientes de confirmar.",

  ["Ayudante de sangre de Kirtonos"]="Recoge la Sangre de inocentes si vas a invocar a Kirtonos. Referencia Classic; pendiente de validar en Forever.",
  ["Kirtonos el Heraldo"]="Invoca con la sangre en el brasero y evita luchar junto al borde. Referencia Classic; pendiente de validar en Forever.",
  ["Jandice Barov"]="Identifica a la verdadera Jandice entre las ilusiones antes de concentrar el daño. Referencia Classic; pendiente de validar en Forever.",
  ["Traquesangre"]="Despeja los esqueletos cercanos y recoge la llave de la sala de observación. Referencia Classic; pendiente de validar en Forever.",
  ["Marduz Pozonegro"]="Mantén a los lanzadores alejados de su aura y controla los enemigos cercanos. Referencia Classic; pendiente de validar en Forever.",
  ["Vectus"]="Prepara el evento del Gambito del Alba y evita el fuego de área. Referencia Classic; pendiente de validar en Forever.",
  ["Ras Levescarcha"]="Mantén espacio para reaccionar al control de masas y protege al sanador. Si haces la misión, usa el objeto antes de matarlo. Referencia Classic; pendiente de validar en Forever.",
  ["Instructor Malicia"]="Interrumpe las curaciones y disipa los efectos mágicos cuando sea posible. Referencia Classic; pendiente de validar en Forever.",
  ["Doctor Theolen Krastinov"]="Despeja la sala y reserva defensivos para el daño intenso al tanque. Referencia Classic; pendiente de validar en Forever.",
  ["Tradicionalista Polkelt"]="Separa a los jugadores afectados por enfermedades y disípalas si es posible. Referencia Classic; pendiente de validar en Forever.",
  ["El Devorador"]="Despeja la sala y deja espacio para reaccionar a los ataques cuerpo a cuerpo. Referencia Classic; pendiente de validar en Forever.",
  ["Lord Alexei Barov"]="Controla los acompañantes y mantén al grupo fuera del alcance de su aura cuando sea posible. Referencia Classic; pendiente de validar en Forever.",
  ["Lady Illucia Barov"]="Prepárate para efectos de control y evita atraer otros enemigos de la sala. Referencia Classic; pendiente de validar en Forever.",
  ["Maestro oscuro Gandling"]="Limpia las seis salas y sus enemigos. Si te teletransporta, derrota a los esqueletos para regresar. Referencia Classic; pendiente de validar en Forever.",
  ["Death Knight Darkreaver"]="Encuentro opcional de clase: verifica que el evento esté disponible en Forever. En la referencia de Classic, activa el objeto de misión en el osario, derrota las oleadas y recoge el objeto de misión correspondiente.",
  ["Kormok"]="Encuentro opcional de invocación: comprueba la misión y el brasero antes de activarlo. Elimina los esqueletos y protege al sanador. Referencia de Classic; mecánicas de Forever pendientes de confirmar.",
  ["Cementerio: Interrogador Vishas"]="Controla los acompañantes y disipa Inmolar.",
  ["Cementerio: Mago sangriento Thalnos"]="Mantén distancia del fuego de área e interrumpe las descargas de sombras.",
  ["Cementerio: Azshir el Insomne"]="Raro: despeja la zona antes de su miedo e interrumpe el drenaje.",
  ["Cementerio: Campeón caído"]="Raro: ataca por detrás y prepara defensivos para el final.",
  ["Cementerio: Dorsacerado"]="Raro: sal de la nube venenosa y elimina la maldición de debilidad.",
  ["Biblioteca: Domador de jaurías Loksey"]="Elimina los perros primero y reserva defensivos para su aumento de velocidad de ataque.",
  ["Biblioteca: Arcanista Doan"]="Aléjate de la detonación, disipa la magia y recoge la llave del cofre tras el jefe.",
  ["Armería: Herod"]="Evita el torbellino y reúne al grupo para eliminar los aprendices al terminar.",
  ["Catedral: Comandante Escarlata Mograine"]="Prepara defensivos para los aturdimientos; tras la resurrección prioriza a Melenablanca.",
  ["Catedral: Alta Inquisidora Melenablanca"]="Tras el sueño colectivo y la resurrección, concentra el daño en Melenablanca.",
  ["Catedral: Alto Inquisidor Fairbanks"]="Accede a la sala secreta mediante la antorcha; interrumpe su curación y disipa la maldición.",

  ["Charlga Filonavaja"]="Interrumpe sus hechizos y llévala fuera de su plataforma; puede hacerse inmune y curarse.",
  ["Clamor de Tierra Halmgar"]="Raro: controla el elemental y destruye los tótems de nexo terrestre.",
  ["Cazador ciego (raro)"]="Raro: deja de lanzar hechizos al comenzar su explosión sónica.",
  ["Agathelos el Furioso"]="Prepara curas para el golpe reforzado después de su carga.",
  ["Señor Supremo Colmicarnero"]="Controla sus dos guardias y ayuda a curar al tanque si es necesario.",
  ["Aggem Malaespina"]="Cambia de objetivo para eliminar el espíritu de jabalí cuando aparezca.",
  ["Médium Jargba"]="Controla o elimina sus dos lanzadores; no mates al aliado dominado.",
  ["Roogug"]="Jefe opcional: controla el elemental de tierra y limpia los enemigos cercanos.",
  ["Mekigeniero Termochufe"]="Desactiva dispensadores con sus botones o elimina las bombas; recupera amenaza tras el empujón.",
  ["Embajador Hierro Negro (raro)"]="Interrumpe bola de fuego, elimina sus invocaciones y evita el daño de fuego durante su escudo.",
  ["Gopleamasa 9-60"]="Ataca por detrás y mantén a los lanzadores lejos de su interrupción de área.",
  ["Electrocutor 6000"]="Separa al grupo y evita el cono frontal; recoge la llave del taller si aparece.",
  ["Radiactivo viscoso"]="Despeja una zona del piso inferior antes de atraer su patrulla.",
  ["Grubbis"]="Habla con Emi para comenzar el evento y controla las oleadas de troggs.",
  ["Aku'mai"]="Evita las nubes de veneno; reserva curas para su furia.",
  ["Señor Crepuscular Kelris"]="Interrumpe sus ataques mentales y mantén a los sanadores fuera del sueño cercano. Después enciende los cuatro braseros de uno en uno.",
  ["Viejo Serra'kis"]="Prepara respiración acuática antes de entrar en su cueva sumergida.",
  ["Lorgus Jett"]="Separa al jefe de las patrullas y disipa su escudo de relámpagos antes de golpearlo cuerpo a cuerpo.",
  ["Gelihast"]="Atrae los múrlocs hacia el pasillo para evitar más grupos; libera al tanque de la red.",
  ["Lady Sarevess"]="Controla los dos nagas, separa al grupo y elimina la nova de escarcha del tanque.",
  ["Ghamoo-ra"]="Aléjate del pisotón si atacas a distancia; reduce su armadura.",
  ["Rethilgore"]="Interrumpe el drenaje de alma y despeja los huargen del piso superior.",
  ["Zarpador el Carnicero"]="Evita las patrullas cercanas y cura el daño de su drenaje.",
  ["Barón Filargenta"]="Disipa la maldición que reduce la sanación un 75%.",
  ["Comandante Vallefont"]="Prioriza al guardia que silencia e interrumpe la cura del comandante.",
  ["Odo el Cegato"]="Controla los dos murciélagos; orienta sus golpes frontales lejos del grupo.",
  ["Capitán Juramorte (raro)"]="Raro: elimina a sus dos acompañantes antes de concentrarte en él.",
  ["Fenrus el Devorador"]="Recoge los cuatro abisarios al 50% de vida: siguen vivos tras morir Fenrus.",
  ["Maestro de lobos Nandos"]="Separa los huargos iniciales y mata los refuerzos al aparecer.",
  ["Archimago Arugal"]="Usa las esquinas para cortar sus lanzamientos; vigila la amenaza después de cada teletransporte.",
  ["Fel Steed / Shadow Charger"]="Los tres caballos entran juntos en combate; controla uno o usa un segundo tanque.",

  ["Rhahk'Zor"]="Separa a los guardias antes de entrar; prepara curas cuando aturda al tanque.",
  ["Minero Johnson (raro)"]="Raro: elimina a los mineros cercanos antes del combate.",
  ["Sneed's Shredder / Sneed"]="Limpia la sala por el miedo de la trituradora; al salir Sneed, vigila su desarme.",
  ["Gilnid"]="Controla al ingeniero que invoca robots y vigila la amenaza del tanque.",
  ["Don Mamporro"]="Mata los dos guardias antes de los aturdimientos al 66% y 33%; reserva defensivos para el final.",
  ["Cocinitas"]="Aléjalo del barco e interrumpe su curación.",
  ["Capitán Verdetez"]="Prioriza al lanzador de su patrulla; ataca al capitán por detrás.",
  ["Edwin VanCleef"]="Elimina los dos guardias al inicio y los dos adicionales al 50%; protege al tanque.",
  ["Targor el Pavoroso"]="Controla los acompañantes y reserva curas para su enfurecimiento al 30%.",
  ["Dextren Tutor"]="Limpia las salas cercanas antes de atraerlo: su miedo puede provocar más combates.",
  ["Kam Furiahonda"]="Controla los acompañantes y vigila el aturdimiento de su golpe de escudo.",
  ["Hamhock"]="Separa al grupo para limitar su relámpago en cadena.",
  ["Bazil Thredd"]="Mantén al tanque sano antes de la bomba de humo; los híbridos pueden ayudar a curar.",
  ["Bruegal Nudoferro (raro)"]="Raro: controla los presos cercanos antes de enfrentarte al jefe.",

  ["Ogglesílex"]="Evita atraer a los troggs cercanos; ataca por detrás para esquivar su golpe frontal.",
  ["Taragaman el Hambriento"]="Tanquea lejos del borde de lava; los lanzadores deben evitar su nova de fuego.",
  ["Jergosh el Conjurador"]="Controla las dos patrullas que lo acompañan; disipa Inmolar y la maldición de debilidad cuando sea posible.",
  ["Bazzalan"]="Controla a sus dos acompañantes y prioriza al jefe; vigila el veneno sobre el tanque.",
  ["Faldrim Anvilmar"]="Despeja las apariciones cercanas, interrumpe su ataque mental y vigila la reducción de velocidad de ataque del tanque.",
  ["Magmatus"]="Prioriza al invocador Hierro Negro y separa al jefe del grupo para evitar la nova de fuego.",
  ["Plunder"]="Lleva al jefe a una zona despejada para evitar atraer enemigos con su empujón.",
  ["Durgen Dirgehammer"]="Limpia la sala y mata los dos gólems antes del jefe; prepara curas para el sangrado y el miedo.",
  ["Lady Anacondra"]="Interrumpe sus curas y sueño; controla las patrullas adicionales.",
  ["Kresh"]="Reduce su elevada armadura si dispones de habilidades para ello.",
  ["Lord Cobrahn"]="Elimina las pitones, interrumpe sueño y prepara curas cuando se transforme en serpiente.",
  ["Dragón feérico descarriado (raro)"]="Raro: controla los druidas cercanos e interrumpe sus efectos de sueño.",
  ["Lord Pythas"]="Controla patrullas, interrumpe sueño y evita su daño cercano si atacas a distancia.",
  ["Skum"]="Separa al grupo para evitar que el rayo encadenado alcance a varios jugadores.",
  ["Lord Serpentis"]="Interrumpe sueño, descargas y curas; mantén las interrupciones coordinadas.",
  ["Verdan el Eterno"]="Los jugadores a distancia deben alejarse de sus raíces y empujones; cura el daño de grupo.",
  ["Mutanus el Devorador"]="Derrota a los cuatro druidas y escolta al discípulo de Naralex; controla oleadas y evita el daño de área del jefe.",
  ["Zul'Alai"]="Reserva defensivos para su enfurecimiento; disipa la ralentización del tanque.",
  ["Var'Taka"]="Elimina primero a las sacerdotisas; orienta el frontal lejos del grupo.",
  ["Primeval Elemental"]="Prepara respiración acuática; elimina las ofrendas para invocarlo.",
  ["Capitán Alzapavor"]="Interrumpe las descargas y rompe la burbuja que atrapa al aliado.",
  ["Deathless Marrow"]="Controla las oleadas; prioriza guardianes y alterna daño al jefe y esbirros.",
  ["Min'loth the Serpent"]="Interrumpe la descarga de área; en forma de serpiente limpia veneno y prepara miedo.",
  ["Umbra"]="Raro: elimina sus múrlocs antes de que saturen al tanque.",
  ["Branquia"]="Raro: limpia enemigos cercanos y vigila la dinamita.",
  ["\"Pyromancer\" Braxton"]="Raro: el tanque debe prever el aturdimiento.",
  ["Colmimarchito"]="Evita atraer su patrulla con otros grupos; vigila el veneno.",
  ["El barón"]="Ataca por detrás; el tanque debe recuperar amenaza tras el empujón.",
  ["Viktor el Abyecto"]="Activa la hoguera; administra recursos durante las oleadas previas.",
  ["El Abandonado"]="Acércate a la estatua; supera tres oleadas e interrumpe drenaje de vida.",
  ["Bjork"]="Evita que el empujón te lleve a otro grupo.",
  ["Rath'mael"]="Interrumpe fogonazo y cura el daño de área cercano.",
  ["Capitán de Lordaeron (raro, Horda)"]="Raro de la Horda tras los demás jefes; cuidado con su patrulla.",

  ["Atrexis the Grave Knight"]="El tanque recibe desarme; recoge los esqueletos invocados y evita quitarle la amenaza.",
  ["Lyn the Ignored"]="Invócalo con el tomo de Dalaran: libro de Arugal, foco de Molino Ámbar, runas de las alcantarillas. Disipa la maldición y cura la descarga de sombras.",
  ["Arcane Anomaly"]="Esquiva el rayo giratorio cerca del centro, interrumpe descargas arcanas y controla los esbirros.",
  ["Mana Devourer"]="Limpia los enemigos cercanos antes de atraerlo. Prioriza el daño antes de que el grupo se quede sin maná.",
  ["Fel Ancient"]="Sal de los charcos y reserva habilidades para liberar a los aliados enraizados.",
  ["Unstable Sentinel"]="Elimina los tomos hostiles cercanos. Aléjate durante su descarga de área (25 yardas).",
  ["Arcanic Enigma"]="Mata primero los dos fantasmas de maná, evita el silencio y disipa Manamorph.",
  ["Shade of the Archmage"]="Accede mediante el portal de Modera. Separa al grupo, esquiva Bounding Mana y mantén distancia de la explosión arcana.",

  ["Espinasal"]="Si eres lanzador, mantente fuera del alcance de la tormenta de polvo. El tanque debe prever ralentizaciones.",
  ["Sombradiente"]="Limpia las criaturas cercanas antes del combate. Controla o elimina los dos acompañantes; guarda aturdimientos para el enfurecimiento.",
  ["Horror de las Tierras Altas"]="Objetivo de misión en el exterior de Los Humedales; no es uno de los tres jefes de Excavación.",
  ["Guardián de reliquias"]="Activa el panel de archivo. Evita permanecer cerca si no necesitas atacar cuerpo a cuerpo; el tanque sufrirá aturdimientos y empujones."
}
function GL.ConsejoJefe976(nombre)
  for k,v in pairs(consejos) do if norm(k)==norm(nombre) or norm(L(k))==norm(nombre) then return L(v) end end
end
function GL.Jefes976(query)
  local q=norm(query); if #q<2 then return {L"Escribe el nombre de una mazmorra o jefe: /ga jefes Excavación"} end
  local out={}; local wh=GL.WH or {}; local keys={}; for k in pairs(wh.jefes or {}) do keys[#keys+1]=k end; table.sort(keys)
  for _,z in ipairs(keys) do
    for _,b in ipairs(GL.JefesVisibles976(z)) do
      if norm(z):find(q,1,true) or norm(L(z)):find(q,1,true) or norm(b.n):find(q,1,true) or norm(L(b.n or "")):find(q,1,true) then
        out[#out+1]=L(z).." / "..L(b.n).." ("..#(b.botin or {}).." "..L"objetos"..")"
        if b.fuente977 then out[#out+1]=L"PNJ y botín señalado contrastados; tasas observadas.".." "..b.fuente977 end
        if b.npc and (z=="La Ciudad Sumergida" or z=="Ruinas de Lordaeron" or z=="Ciudad de Dalaran") then out[#out+1]=L"Referencia contrastada: Icy Veins Forever (tasas observadas, no garantizadas)." end
        out[#out+1]=GL.ConsejoJefe976(b.n) or L"Estrategia de Forever pendiente de verificar."
        for _,o in ipairs(b.botin or {}) do
          local name=o.n or (o.id and call(GetItemInfo,o.id)) or (L"Objeto".." #"..tostring(o.id or "?"))
          local tag=""; if o.id and GL.BotinUtil then local usable,better=call(GL.BotinUtil,o.id); if better then tag=" — "..L"posible mejora" elseif usable then tag=" — "..L"utilizable" end end
          out[#out+1]="  "..name..(o.p and (" ~"..o.p.."%") or "")..tag..(o.origen977 and (" — "..L(o.origen977)) or "")..(o.mision977 and (" — "..L"Objeto de misión") or "")..(o.fuente977 and o.fuente977~=b.fuente977 and (" — "..o.fuente977) or "")..(o.pendiente977 and (" — "..L"Asociación pendiente de contraste") or "")
        end
      end
      if #out>=150 then break end
    end
    if #out>=150 then break end
  end
  if #out==0 then out[1]=L"No hay coincidencias." end
  out[#out+1]=L"Botín orientativo: los porcentajes son observaciones y los datos heredados de Classic pueden cambiar."
  return out
end
local function openMode(mode)
  if GL.frame then GL.frame:Show(); local db=DB(); if db then db.oculto=false end end
  if GL.AbrirModo then GL.AbrirModo(mode) end
end
GL.comandos=GL.comandos or {}; local cmd=GL.comandos
cmd.buscar=function(q) if GL.AbrirBuscador976 and GL.AbrirBuscador976(q) then return end; return show(GL.Buscar976(q)) end
cmd.jefes=function(q) return show(GL.Jefes976(q)) end
cmd.viajelocal=function() return show(GL.ViajeLocal976()) end
cmd.resumenpersonaje=function() return show(personaje()) end
-- 9.7.6: /ga costeprofesion quitado (lo hace el botón Lista de compra de la profesión)
cmd.precio=function(q) local id,p=trim(q):match("^(%d+)%s+(%d+)$"); return show({GL.Precio976(id,p) and L"Precio manual guardado." or L"Uso: /ga precio ID PRECIO (cobre por unidad)."}) end
cmd.questie=function(q)
  q=norm(q)
  if q=="on" or q=="si" then GL.ConfigurarQuestie976(true) elseif q=="off" or q=="no" then GL.ConfigurarQuestie976(false) end
  local estado = EstadoQuestieSeguro()
  local texto = estado == true and L"Questie cargado." or (estado == false and L"Questie no cargado." or L"Estado de Questie no verificable.")
  local efectivo = ConvivenciaSegunEstado(estado) and L"Suspensión de funciones propias activa." or L"Suspensión de funciones propias inactiva."
  return show({L"Convivencia con Questie: "..((DB() or {}).questie976 and L"activada" or L"desactivada"), texto, efectivo, L"Usa /ga questie on|off. No se cambian los ajustes de Questie.", L"Con la convivencia activa, se suspenden los marcadores propios del mapa y el seguimiento, la aceptación y la entrega automáticos de misiones si Questie está cargado o su estado no se puede verificar."})
end
-- 9.7.6: /ga centro no abre una ventana propia (Quini: nada de ventanas que no estuvieran en la 9.7.5).
-- Enseña sus herramientas, con su comando, en la ventana de informes de siempre.
local function QuestieTexto() return ((DB() or {}).questie976 and L"Questie: activada" or L"Questie: desactivada") end
cmd.centro=function()
  return show({
    L"Centro de herramientas (escribe el comando en el chat):",
    "",
    L"Buscar",
    L"  El botón Buscar: objetos, jefes, recetas, materiales y misiones.",
    L"  /ga jefes nombre: jefes y su botín.",
    "",
    L"Personaje y viajes",
    L"  /ga resumenpersonaje · /ga contexto · /ga viajelocal · /ga visitas",
    L"  /ga preparar: lista «Antes de salir» de la zona.",
    "",
    L"Profesiones",
    L"  Lista de compra: botón de la tarjeta de la profesión.",
    L"  /ga profesionesjuntas · /ga compararplanes · /ga recetasconocidas",
    L"  /ga precio ID PRECIO (cobre por unidad) · /ga preciosubasta ID",
    "",
    L"Otros",
    L"  /ga rendimiento",
    "  /ga questie on|off  (" .. QuestieTexto() .. ")",
  })
end

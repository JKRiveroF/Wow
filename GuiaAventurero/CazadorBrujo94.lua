-- CazadorBrujo94.lua (9.4): ayudas de clase para cazadores y brujos.
--  · Cazador: pestaña Rangos en Mascotas. Rangos y candidatos documentados, sin guiado a coordenadas no verificadas.
--    Aprende el rango usando la habilidad de la bestia domada; luego consulta Entrenar bestia. Bestias de Bestias.lua.
--  · Avisos nuevos: mascota descontenta (dale de comer, con lo que come) y, para el brujo, sin piedra de salud con
--    fragmentos de sobra. La munición y los fragmentos de alma ya los avisaba la Guía.
-- Rangos de Classic 1.12: en Forever pueden cambiar. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local function Clase() return UnitClass and select(2, UnitClass("player")) end
local function Nivel() return (UnitLevel and UnitLevel("player")) or 1 end

-- habilidad -> niveles de cada rango
local RANGOS = {
  { "encogerse", { 5, 15, 25, 35, 45, 55 } },
  { "mordisco", { 1, 8, 16, 24, 32, 40, 48, 56 } },
  { "zarpa", { 1, 8, 16, 24, 32, 40, 48, 56 } },
  { "cargar", { 1, 12, 24, 36, 48, 60 } },
  { "aliento", { 1, 12, 24, 36, 48, 60 } },
  { "chillido", { 8, 24, 48, 56 } },
  { "veneno", { 8, 24, 40, 56 } },
  { "aullido", { 10, 24, 40, 56 } },
  { "escudo", { 20 } },
  { "carrera", { 30, 40, 50 } },
  { "picado", { 30, 40, 50 } },
  { "acechar", { 30, 40, 50 } },
  { "pisoton", { 30, 40, 50, 60 } },
  { "sonico", { 12, 24, 36, 48, 60 } },
  { "vapulear", { 12, 24, 36, 48, 60 } },
  { "pellizco", { 12, 24, 36, 48, 60 } },
  { "desmembrar", { 12, 24, 36, 48, 60 } },
  { "tendones", { 12, 24, 36, 48, 60 } },
  { "salvaje", { 12, 24, 36, 48, 60 } },
  { "telarana", { 12, 24, 36, 48, 60 } },
  { "polvo", { 12, 24, 36, 48, 60 } },
  { "mio", { 10, 20, 30, 40, 50 } },
  { "danza", { 20 } },
}
local ROMANO = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

local function Familias(h)
  local r = {}
  for _, f in ipairs((GL.bestias and GL.bestias.familias) or {}) do
    if h == "encogerse" then r[f.f] = f end
    for _, x in ipairs(f.hab or {}) do if x == h then r[f.f] = f end end
  end
  return r
end

-- No deducir donantes por familia y nivel: no demuestra que sepan la habilidad.
-- Se recuperará el guiado solo al disponer de una relación NPC/rango acreditada.
local function Maestras(h, rango, nv, incluirFuturos)
  local ids = GL.donantesBestia and GL.donantesBestia[h] and GL.donantesBestia[h][rango]
  local resultado, usados = {}, {}
  if not ids or (not incluirFuturos and (not nv or nv < 10)) then return resultado end
  local familias = Familias(h)
  for _, id in ipairs(ids) do
    local b = GL.donantesBestiaReferencia and GL.donantesBestiaReferencia[id]
    if not b then
      for _, e in ipairs((GL.bestias and GL.bestias.lista) or {}) do
        if e.npc == id then b=e; break end
      end
    end
    local max = b and tonumber((b.nv or ""):match("(%d+)$"))
    if b and not b.familiaPendiente and familias[b.f] and max and (incluirFuturos or nv >= max) and not usados[id] then
      resultado[#resultado+1] = b; usados[id]=true
    end
  end
  return resultado
end
local function Maestra(h, rango, nv) return Maestras(h, rango, nv)[1] end
local function Txt(es,en) return GL.ingles and en or es end
-- B12: la cobertura documental no depende del nivel ni de la mascota del jugador.
-- Un candidato de nivel superior sigue siendo una referencia; nunca se ofrece como domable ahora.
local function CoberturaDonantes()
  local c={total=0,documentados=0,pendientes=0,relaciones=0,npc=0}; local vistos={}
  for _,e in ipairs(RANGOS) do
    for i in ipairs(e[2]) do
      c.total=c.total+1
      local candidatos=Maestras(e[1],i,nil,true)
      if #candidatos>0 then c.documentados=c.documentados+1 else c.pendientes=c.pendientes+1 end
      for _,b in ipairs(candidatos) do c.relaciones=c.relaciones+1; if not vistos[b.npc] then vistos[b.npc]=true; c.npc=c.npc+1 end end
    end
  end
  return c
end
local function NombreDonante(d)
  local n=GL.ingles and (d.ing or d.n) or d.n
  local zona=GL.ingles and (d.zonaEN or L(d.zona)) or d.zona
  return n.." (NPC "..d.npc..", "..d.nv..(zona and ", "..zona or "")..(d.instancia and Txt(", instancia: verifica acceso",", instance: check access") or "")..")"
end
local function Filas()
  local filas, nv = {}, Nivel()
  local petNv = UnitExists and UnitExists("pet") and UnitLevel and UnitLevel("pet") or nil
  local H = (GL.bestias and GL.bestias.habilidades) or {}
  table.insert(filas,{titulo=true,texto=Txt("Instructor de mascotas (conocimiento del cazador)","Pet trainer (hunter knowledge)"),
    detalle=Txt("Aprende la lección con el PNJ. Después abre Entrenar bestia y revisa los puntos de la mascota. No son el mismo estado.","Learn the lesson from the NPC. Then open Beast Training and check the pet's points. These are separate states.")})
  for _, f in ipairs(GL.RangosInstructorMascota and GL.RangosInstructorMascota() or {}) do
    local aprendido=GL.HechizoORangoConocido and GL.HechizoORangoConocido(f.id) or GL.ConocidoFuera and GL.ConocidoFuera(f.id)
    local nombre=Txt(f.es,f.en).." "..(ROMANO[f.rango] or f.rango)
    local estado=aprendido and Txt("Lección conocida; aplicación a mascota no verificada","Lesson known; pet application unverified") or
      (nv < f.n and Txt("Nivel de cazador pendiente","Hunter level pending") or Txt("Consultar instructor (precio/oferta sin confirmar)","Check trainer (price/offer unconfirmed)"))
    local pet=Txt(" · Mascota nv. ref. "," · Reference pet lv. ")..f.nivelMascota
    if petNv and petNv>0 and petNv<f.nivelMascota then pet=pet..Txt(" (aún no)"," (not yet)") end
    table.insert(filas,{texto=nombre,detalle=Txt("Cazador nv. ","Hunter lv. ")..f.n..pet.." · "..estado,
      ayudaTitulo=nombre,ayudaTexto=Txt("Precio estimado de la lección: ","Estimated lesson price: ")..(GL.Dinero and GL.Dinero(f.coste or 0) or tostring(f.coste or 0))..Txt(". No equivale a puntos de entrenamiento.",". This is not the training point cost.")})
  end
  table.insert(filas,{titulo=true,texto=Txt("Gruñido I–II","Growl I–II"),detalle=Txt("Consulta Entrenar bestia tras la doma; no se presupone compra ni aplicación.","Check Beast Training after taming; purchase and application are not assumed.")})
  table.insert(filas,{titulo=true,texto=Txt("Habilidades de bestias: rangos de referencia","Beast abilities: reference ranks"),detalle=Txt("Se aprende de una bestia que conoce el rango usándolo; no basta con domarla. Algunos donantes se documentan como candidatos; confirma tras la doma.","Learn from a beast that knows the rank by having it use the ability; taming alone is not sufficient. Some donors are documented as candidates; check after taming.")})
  local cobertura=CoberturaDonantes()
  table.insert(filas,{texto=Txt("Cobertura de donantes documentados: ","Documented donor coverage: ")..cobertura.documentados.."/"..cobertura.total,
    detalle=cobertura.pendientes..Txt(" rangos sin donante acreditado; disponibilidad real pendiente de confirmar. Se muestran también referencias de nivel superior."," ranks without a documented donor; actual availability still unverified. Higher-level references are also shown.")})
  for _, e in ipairs(RANGOS) do
    local h, niveles = e[1], e[2]
    local nombre = GL.HabilidadBestia and GL.HabilidadBestia(h,true) or h
    local fams = {}
    for _, f in pairs(Familias(h)) do table.insert(fams, GL.ingles and (f.ing or f.n) or f.n) end
    table.sort(fams)
    table.insert(filas, { titulo = true, texto = nombre .. C.GRIS .. "  · " .. #niveles .. (#niveles == 1 and L" rango" or L" rangos") .. C.FIN,
      detalle = table.concat(fams, ", "), ayudaTitulo = nombre, ayudaTexto = GL.HabilidadBestia and GL.HabilidadBestia(h) or H[h] })
    for i, n in ipairs(niveles) do
      local det=Txt("Donante y nivel exactos pendientes de confirmar en Forever","Donor and exact level pending Forever verification")
      if h=="picado" and i==1 then
        det=Txt("Nivel 30 de referencia; murciélagos: fuentes discrepan sobre rango I.","Reference level 30; bats: sources disagree on rank I.")
      end
      if h=="mordisco" then
        local tp=({1,4,7,10,13,17,21,25})[i]
        det=Txt("Nivel mascota documentado; puntos totales: ","Documented pet level; total points: ")..tp.." · "..Txt("donante pendiente","donor pending")
      end
      local donantes=Maestras(h,i,nv)
      local todos=Maestras(h,i,nil,true)
      if #donantes > 0 then
        local nombres={}
        for _,d in ipairs(donantes) do nombres[#nombres+1]=NombreDonante(d) end
        det=Txt("Candidato documentado (confirma el rango después de domar): ","Documented candidate (check rank after taming): ")..table.concat(nombres,"; ")
      elseif #todos>0 then
        det=Txt("Donante documentado, aún no disponible por nivel de cazador:","Documented donor, not yet eligible at your Hunter level:")
      elseif GL.donantesBestia and GL.donantesBestia[h] and GL.donantesBestia[h][i] then
        det=det..Txt(" · Referencias pendientes de resolver."," · References pending resolution.")
      end
      local actuales, futuros={},{}
      for _,d in ipairs(donantes) do actuales[d.npc]=true end
      for _,d in ipairs(todos) do if not actuales[d.npc] then futuros[#futuros+1]=NombreDonante(d) end end
      if #futuros>0 then det=det..Txt(" · Para más adelante: "," · For later: ")..table.concat(futuros,"; ") end
      if h=="mordisco" and #todos>0 then det=det..Txt(" · Puntos totales de referencia: "," · Reference total points: ")..({1,4,7,10,13,17,21,25})[i] end
      table.insert(filas,{texto=nombre.." "..(ROMANO[i] or i)..C.GRIS..Txt(" (nivel mascota de referencia "," (reference pet level ")..n..")"..C.FIN,
        detalle=det,ayudaTitulo=nombre.." "..(ROMANO[i] or i),ayudaTexto=Txt("Comprueba la habilidad real de la bestia y el nivel, familia y puntos de tu mascota antes de sustituirla o enseñarle nada.","Check the beast's actual skill and your pet's level, family and points before replacing or teaching anything.")})
    end
  end
  return filas
end

local ventana
local function Refrescar()
  if not (ventana and ventana:IsShown()) then return end
  ventana.lista:Poner(Filas(), C.GRIS .. Txt("Rangos de instructor y referencias de bestias. No se presume que una lección conocida esté aplicada a tu mascota.","Trainer ranks and beast references. Knowing a lesson does not mean it has been taught to your pet.") .. C.FIN)
end
function GL.AbrirRangosMascota()
  ventana = GL.VentanaLista("rangos", L"Rangos de habilidades de mascota", 440, 440)
  if not ventana.hecha then
    ventana.hecha = true
    local espera = 0
    ventana:HookScript("OnUpdate", function(_, dt) espera = espera + dt; if espera >= 3 then espera = 0; Refrescar() end end)
  end
  ventana:Show()
  Refrescar()
end

------------------------------------------------------------------------
-- Avisos (Mejoras.lua llama a GL.avisosExtra; urgencia y nombre de la píldora en sus tablas)
------------------------------------------------------------------------
local PIEDRA_SALUD = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 }
GL.avisosExtra = GL.avisosExtra or {}
table.insert(GL.avisosExtra, function()
  local l, clase = {}, Clase()
  if clase == "HUNTER" and HasPetUI and HasPetUI() and GetPetHappiness then
    local feliz = GetPetHappiness()
    if feliz == 1 or feliz == 2 then
      local come = GetPetFoodTypes and { GetPetFoodTypes() } or {}
      table.insert(l, { "mascota", L"Tu mascota está " .. C.AMARILLO .. (feliz == 1 and L"descontenta" or L"normal") .. C.FIN ..
        L": dale de comer (Alimentar mascota) para que haga más daño" .. (#come > 0 and (L". Come: " .. table.concat(come, ", ")) or "") .. "." })
    end
  end
  if clase == "WARLOCK" and Nivel() >= 10 and GetItemCount then
    local tengo = false
    for _, id in ipairs(PIEDRA_SALUD) do if (GetItemCount(id) or 0) > 0 then tengo = true; break end end
    local fragmentos = GetItemCount(6265) or 0
    if not tengo and fragmentos >= 3 and not (InCombatLockdown and InCombatLockdown()) then
      table.insert(l, { "piedrasalud", L"No llevas " .. C.AMARILLO .. L"piedra de salud" .. C.FIN .. L" y te sobran fragmentos de alma: crea una antes de salir." })
    end
  end
  return l
end)
table.insert(GL.alIniciar, function()
  if GL.URGENCIA_AVISO then GL.URGENCIA_AVISO.mascota = 1; GL.URGENCIA_AVISO.piedrasalud = 3 end
  if GL.NOMBRE_PILDORA then GL.NOMBRE_PILDORA.mascota = "Mascota"; GL.NOMBRE_PILDORA.piedrasalud = "Piedra de salud" end
  if GL.TITULOS_AVISO then GL.TITULOS_AVISO.mascota = "Mascota descontenta" end
end)

GL._rangosMascota = { Filas = Filas, Maestra = Maestra, Maestras = Maestras, Cobertura = CoberturaDonantes }   -- para las pruebas

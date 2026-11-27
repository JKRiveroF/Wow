-- Idioma.lua (9.3.5): idioma de la guía. Los textos se escriben en español en el código y pasan por GL.L:
-- en español sale el texto tal cual; en inglés sale su traducción de Idioma\enUS*.lua (si no hay, el español).
-- El idioma es el del cliente (enUS o enGB: inglés; el resto: español) salvo que se elija otro en Ajustes > General
-- o con /ga idioma es|en|auto (se guarda en la cuenta y vale al recargar).
-- Las traducciones de las rutas y de los datos van en un texto aparte que solo se lee si la guía está en inglés.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end

local cliente = "esES"
if type(GetLocale) == "function" then
  local ok, valor = pcall(GetLocale)
  local secreto = false
  if ok and type(issecretvalue) == "function" then
    local comprobado, resultado = pcall(issecretvalue, valor)
    secreto = not comprobado or resultado == true
  end
  if ok and not secreto and type(valor) == "string" and valor ~= "" then cliente = valor end
end
GL.clienteIngles = (cliente == "enUS" or cliente == "enGB")
GL.ingles = GL.clienteIngles

local EN = {}          -- texto en español -> texto en inglés
local bloques = {}     -- traducciones guardadas como texto (rutas, datos): se leen solo en inglés
GL.textosIngles = EN

-- Idioma\enUS*.lua añaden sus tablas con esto. Una tabla se mezcla ya; un texto ("return { ... }") se guarda
-- y se convierte en tabla cuando se necesita su idioma o una consulta explícita de nombres.
-- destino = "misiones": la tabla es [id de misión] = nombre inglés (GL.misionesIngles).
GL.misionesIngles = {}
function GL.AnadirIngles(t, destino, categoria)
  local tabla = (destino == "misiones") and GL.misionesIngles or EN
  if type(t) == "table" then
    for k, v in pairs(t) do tabla[k] = v end
  elseif type(t) == "string" then
    table.insert(bloques, { t, tabla, categoria })
  end
end

-- R11: los nombres ingleses también se consultan con la guía en español.
-- Separar los bloques de nombres/misiones de los textos largos de rutas evita
-- cargar todas las traducciones solo para reconocer un PNJ o una mazmorra.
local function LeerBloques(destino)
  if #bloques == 0 then return end
  local cargar = loadstring or load
  local pendientes = {}
  for i = 1, #bloques do
    local b = bloques[i]
    if destino and (b[2] ~= destino or b[3] == "rutas") then
      pendientes[#pendientes + 1] = b
    else
      local compilado, f = false, nil
      if type(cargar) == "function" then compilado, f = pcall(cargar, b[1]) end
      local leido = false
      if compilado and type(f) == "function" then
        local ok, t = pcall(f)
        if ok and type(t) == "table" then
          for k, v in pairs(t) do if b[2][k] == nil then b[2][k] = v end end
          leido = true
        end
      end
      -- R15: un fallo temporal no debe perder el diccionario para toda la sesión.
      -- Limitar los reintentos para no recompilar un bloque dañado en cada texto.
      if not leido then
        b[4] = (b[4] or 0) + 1
        if b[4] < 2 then pendientes[#pendientes + 1] = b end
      end
    end
  end
  bloques = pendientes
end

-- R13: cambios temporales del diario, sin apropiarse de la selección de otro addon.
-- R13: una respuesta desconocida del cliente no autoriza una acción protegida.
function GL.AccionProtegidaPermitidaR13()
  local conocida = false
  local function libre(fn, ...)
    if type(fn) ~= "function" then return fn == nil end
    local ok, v = pcall(fn, ...)
    if not ok then return false end
    if type(issecretvalue) == "function" then
      local leido, secreto = pcall(issecretvalue, v)
      if not leido or secreto then return false end
    end
    if v ~= false and v ~= 0 then return false end
    conocida = true
    return true
  end
  return libre(InCombatLockdown) and libre(UnitAffectingCombat, "player") and conocida
end

-- R14: solo un estado vital conocido permite automatismos de progreso.
function GL.PersonajeVivoR14()
  local function vivo(fn)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, "player")
    if not ok then return false end
    if type(issecretvalue) == "function" then
      local leido, secreto = pcall(issecretvalue, v)
      if not leido or secreto then return false end
    end
    return v == false or v == 0
  end
  if UnitIsDeadOrGhost ~= nil then return vivo(UnitIsDeadOrGhost) end
  return vivo(UnitIsDead) and vivo(UnitIsGhost)
end

local seleccionOcupadaR13
local function PublicoDiarioR13(v)
  if type(issecretvalue) ~= "function" then return true end
  local ok, secreto = pcall(issecretvalue, v)
  return ok and not secreto
end
local function IndiceDiarioR13(v)
  return PublicoDiarioR13(v) and type(v)=="number" and v>=0 and v<math.huge and v%1==0
end
-- R14: distinguir estados confirmados de valores desconocidos o secretos.
function GL.EstadoMisionR14(v)
  if not PublicoDiarioR13(v) then return nil end
  if v == true or v == 1 then return true end
  if v == false or v == 0 then return false end
  return nil
end
-- R14: un nivel desconocido no equivale al nivel 1. No imponer un máximo del servidor.
function GL.NivelValidoR14(v)
  if IndiceDiarioR13(v) and v > 0 then return v end
end
function GL.NivelJugadorR14(evento)
  local nivel = GL.NivelValidoR14(evento)
  if nivel then return nivel end
  if type(UnitLevel) ~= "function" then return nil end
  local ok, v = pcall(UnitLevel, "player")
  if ok then return GL.NivelValidoR14(v) end
end
-- R14: la posición y los padres de un mapa pueden faltar durante una transición.
function GL.MapaUnidadR14(unidad)
  local fn = type(C_Map)=="table" and C_Map.GetBestMapForUnit
  if type(fn)~="function" then return nil end
  local ok,m=pcall(fn,unidad or "player")
  if ok and IndiceDiarioR13(m) and m>0 then return m end
end
function GL.InfoMapaR14(m)
  if not IndiceDiarioR13(m) or m==0 then return nil end
  local fn=type(C_Map)=="table" and C_Map.GetMapInfo
  if type(fn)~="function" then return nil end
  local ok,tipo,padre=pcall(function()
    local info=fn(m)
    if not PublicoDiarioR13(info) or type(info)~="table" then return nil end
    local t,p=info.mapType,info.parentMapID
    if not IndiceDiarioR13(t) then return nil end
    return t,IndiceDiarioR13(p) and p>0 and p or nil
  end)
  if ok then return tipo,padre end
end
function GL.MapasZonaR14()
  local mapas={}
  local origen=GL.MapaUnidadR14()
  local m=origen
  for _=1,6 do
    if not m or mapas[m] then break end
    local tipo,padre=GL.InfoMapaR14(m)
    if not tipo or tipo<=2 then break end
    mapas[m]=true
    m=padre
  end
  if not origen or not mapas[origen] or GL.MapaUnidadR14()~=origen then return {},nil end
  return mapas,origen
end
function GL.EnMapaR14(objetivo)
  if not IndiceDiarioR13(objetivo) or objetivo==0 then return false end
  local origen=GL.MapaUnidadR14()
  local m=origen
  local vistos={}
  for _=1,6 do
    if not m or vistos[m] then return false end
    if m==objetivo then return GL.MapaUnidadR14()==origen end
    vistos[m]=true
    local _,padre=GL.InfoMapaR14(m)
    m=padre
  end
  return false
end
function GL.ZonaTextoR14(fn)
  if type(fn)~="function" then return "" end
  local ok,v=pcall(fn)
  if ok and PublicoDiarioR13(v) and type(v)=="string" then return v end
  return ""
end
-- Mantener clientes antiguos sin estas API; si existen, solo false/0 confirma que no hay tránsito.
function GL.TransitoLibreR14()
  local function libre(fn,...)
    if fn==nil then return true end
    if type(fn)~="function" then return false end
    local ok,v=pcall(fn,...)
    return ok and GL.EstadoMisionR14(v)==false
  end
  return libre(IsInInstance) and libre(UnitOnTaxi,"player")
end
function GL.IdMisionR14(q)
  return IndiceDiarioR13(q) and q > 0
end
function GL.ConsultarMisionR14(fn, q)
  if type(fn) ~= "function" or not GL.IdMisionR14(q) then return nil end
  local ok, v = pcall(fn, q)
  if ok then return GL.EstadoMisionR14(v) end
  return nil
end
function GL.IndiceMisionR14(q)
  if not GL.IdMisionR14(q) then return nil end
  local function leer(fn)
    if type(fn) ~= "function" then return nil end
    local ok, i = pcall(fn, q)
    if ok and IndiceDiarioR13(i) then return i end
    return nil
  end
  local i = leer(C_QuestLog and C_QuestLog.GetLogIndexForQuestID)
  if i and i > 0 then return i end
  local antiguo = leer(GetQuestLogIndexByID)
  if antiguo and antiguo > 0 then return antiguo end
  if i == 0 or antiguo == 0 then return 0 end
  return nil
end
function GL.ConSeleccionMisionR13(indice, accion)
  if seleccionOcupadaR13 or not IndiceDiarioR13(indice) or indice==0 or type(accion)~="function"
    or type(GetQuestLogSelection)~="function" or type(SelectQuestLogEntry)~="function" then return false end
  local ok, antes=pcall(GetQuestLogSelection)
  if not ok or not IndiceDiarioR13(antes) then return false end
  seleccionOcupadaR13=true
  local seleccionada, aceptada=true,true
  if antes~=indice then seleccionada, aceptada=pcall(SelectQuestLogEntry, indice) end
  local leida, actual=pcall(GetQuestLogSelection)
  local exito, resultado=false,nil
  if seleccionada and PublicoDiarioR13(aceptada) and aceptada~=false and leida and IndiceDiarioR13(actual) and actual==indice then
    exito, resultado=pcall(accion)
  end
  -- Restaurar incluso si la lectura falla; no sustituir una selección distinta
  -- realizada entretanto por el jugador u otro addon.
  if antes~=indice then
    local comprobada, despues=pcall(GetQuestLogSelection)
    if comprobada and IndiceDiarioR13(despues) and despues==indice then
      local restaurada, respuesta=pcall(SelectQuestLogEntry, antes)
      local verificada, final=pcall(GetQuestLogSelection)
      if not restaurada or not PublicoDiarioR13(respuesta) or respuesta==false or not verificada or not IndiceDiarioR13(final) or final~=antes then exito=false end
    elseif not comprobada or not IndiceDiarioR13(despues) then exito=false end
  end
  seleccionOcupadaR13=nil
  return exito, exito and resultado or nil
end

-- Formatos de presentación según el idioma elegido para la guía.
function GL.FormatoMiles(n)
  local s = tostring(math.floor((n or 0) + 0.5))
  local signo = s:sub(1, 1) == "-" and "-" or ""
  if signo ~= "" then s = s:sub(2) end
  local sep = GL.ingles and "," or "."
  local r = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if r:sub(1, 1) == sep then r = r:sub(2) end
  return signo .. r
end
function GL.FormatoDecimal(texto)
  if GL.ingles then return texto end
  return (texto:gsub("%.", ","))
end

-- 9.4.2: la letra del juego no tiene ▲ ✓ ★ ▶ ■ → (salían como cuadrados vacíos). GL.Simbolos los cambia por
-- iconos pequeños de la carpeta Iconos, del color del texto que los rodea (|cffRRGGBB) o del suyo por defecto.
local ICONOS = "Interface\\AddOns\\GuiaAventurero\\Iconos\\"
local SIMBOLOS = {   -- símbolo = { icono, color por defecto (r, g, b de 0 a 255) }
  ["▲"] = { "arriba", 64, 217, 89 }, ["↑"] = { "arriba", 64, 217, 89 },
  ["▼"] = { "abajo", 240, 80, 80 }, ["▾"] = { "abajo", 200, 200, 210 },
  ["→"] = { "derecha", 200, 200, 210 }, ["➜"] = { "derecha", 255, 209, 0 },
  ["▶"] = { "triangulo", 64, 217, 89 }, ["■"] = { "cuadro", 200, 200, 210 },
  ["★"] = { "estrella", 255, 209, 0 }, ["✓"] = { "ok", 64, 217, 89 }, ["✔"] = { "ok", 64, 217, 89 },
  ["⚠"] = { "aviso", 255, 112, 112 },
}
local function Icono(sim, r, g, b)
  local d = SIMBOLOS[sim]
  return "|T" .. ICONOS .. d[1] .. ":0:0:0:0:32:32:0:32:0:32:" .. (r or d[2]) .. ":" .. (g or d[3]) .. ":" .. (b or d[4]) .. "|t"
end
local function Simbolos(s)
  if type(s) ~= "string" or not s:find("[\226]") then return s end
  local fuera, color, i = {}, nil, 1
  while i <= #s do
    local cc = s:match("^|c%x%x(%x%x%x%x%x%x)", i)
    if cc then color = cc; table.insert(fuera, s:sub(i, i + 9)); i = i + 10
    elseif s:sub(i, i + 1) == "|r" then color = nil; table.insert(fuera, "|r"); i = i + 2
    else
      local hecho
      for sim in pairs(SIMBOLOS) do
        if s:sub(i, i + #sim - 1) == sim then
          local r, g, b
          if color then r, g, b = tonumber(color:sub(1, 2), 16), tonumber(color:sub(3, 4), 16), tonumber(color:sub(5, 6), 16) end
          table.insert(fuera, Icono(sim, r, g, b)); i = i + #sim; hecho = true; break
        end
      end
      if not hecho then table.insert(fuera, s:sub(i, i)); i = i + 1 end
    end
  end
  return table.concat(fuera)
end
GL.Simbolos = Simbolos
GL.Icono = Icono

local function Traducir(s)
  if type(s) ~= "string" then return s end
  if not GL.ingles then return Simbolos(s) end
  if #bloques > 0 then LeerBloques() end
  return Simbolos(EN[s] or s)
end

-- Los nombres que da el juego (zonas, rutas de vuelo, profesiones) van en el idioma del cliente: así se pueden
-- comparar con lo que dice el juego, sea cual sea el idioma de la guía.
local function TraducirCliente(s)
  if not GL.clienteIngles or type(s) ~= "string" then return s end
  if EN[s] == nil and #bloques > 0 then LeerBloques(EN) end
  return EN[s] or s
end
GL.LC = TraducirCliente

-- L"texto" o L["texto"]: el texto en el idioma de la guía
GL.L = setmetatable({}, {
  __index = function(_, k) return Traducir(k) end,
  __call = function(_, k) return Traducir(k) end,
})
GL.T = Traducir
-- El nombre inglés de un texto, sea cual sea el idioma de la guía (para reconocer lo que dice un cliente en inglés)
function GL.EnIngles(s)
  if type(s) ~= "string" then return s end
  if EN[s] == nil and #bloques > 0 then LeerBloques(EN) end
  return EN[s] or s
end

-- Presentación de jefes: no modificar el alias del cliente ni la identidad del encuentro.
function GL.NombreJefeGuiaR11(j)
  if type(j) ~= "table" then return "?" end
  local original = j.nombreOriginal977 or j.n
  if GL.ingles then return j.ing or GL.L(original or "?") end
  return original or j.ing or "?"
end

-- Materiales: priorizar el idioma de la guía cuando difiere del cliente.
-- Los IDs y cantidades no se alteran; una respuesta nativa sin traducir se identifica.
function GL.NombreMaterialR11(id, original)
  local base = type(original) == "string" and original ~= "" and original or nil
  local nombre
  if type(GetItemInfo) == "function" then
    local ok, v = pcall(GetItemInfo, id)
    if ok and type(issecretvalue) == "function" then
      local comprobado, secreto = pcall(issecretvalue, v)
      ok = comprobado and not secreto
    end
    if ok and type(v) == "string" and v ~= "" then nombre = v end
  end
  if GL.ingles == GL.clienteIngles and nombre then return nombre end
  if base then
    if GL.ingles then GL.EnIngles(base) end
    if not GL.ingles or EN[base] ~= nil then return GL.L(base) end
    if nombre and GL.clienteIngles then return nombre end
    return (nombre or base) .. " (" .. GL.L"traducción sin confirmar" .. ")"
  end
  if nombre then
    return nombre .. (GL.ingles ~= GL.clienteIngles and (" (" .. GL.L"idioma del cliente" .. ")") or "")
  end
  return GL.L"Objeto " .. tostring(id or "?")
end

-- El idioma elegido en la cuenta (las variables guardadas llegan con ADDON_LOADED). Lo que se crea al
-- iniciar la guía (después) ya sale en ese idioma; un cambio de idioma vale del todo al recargar (/reload).
function GL.IdiomaElegido()
  local c = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.idioma
  if c == "es" or c == "en" then return c end
  return "auto"
end

-- Si las SavedVariables ya están disponibles al ejecutar los archivos, usar
-- la preferencia desde el primer texto. ADDON_LOADED vuelve a comprobarla.
local idiomaInicial = GL.IdiomaElegido()
if idiomaInicial == "en" then GL.ingles = true elseif idiomaInicial == "es" then GL.ingles = false end

function GL.PonerIdioma(codigo)
  if codigo ~= "es" and codigo ~= "en" and codigo ~= "auto" then return false end
  if type(GuiaAventureroCuenta) ~= "table" then
    local anterior = GuiaAventureroCuenta
    GuiaAventureroCuenta = {}
    if anterior ~= nil then GuiaAventureroCuenta.reparacionesR14 = { raiz = GL.CopiaDiagnosticoR14(anterior) } end
  end
  if codigo == "es" or codigo == "en" then GuiaAventureroCuenta.idioma = codigo else GuiaAventureroCuenta.idioma = nil end
  return true
end

-- 9.5: el addon se llamaba GuiaLeveo. Si el jugador renombra sus archivos de WTF\...\SavedVariables de
-- GuiaLeveo.lua a GuiaAventurero.lua, lo guardado llega con los nombres de antes: se pasa a los nuevos.
-- Este es el primer ADDON_LOADED del addon (Idioma.lua va primero en el .toc), así que los demás ya lo ven.
-- R13: las SavedVariables antiguas pueden pertenecer a otro addon aún cargado.
-- Las API modernas y antiguas devuelven booleanos o 0/1; un error no prueba que esté descargado.
local function EstadoGuiaLeveoR13()
  local function consultar(fn)
    if type(fn) ~= "function" then return nil end
    local ok, valor = pcall(fn, "GuiaLeveo")
    if not ok then return nil end
    if type(issecretvalue) == "function" then
      local comprobado, secreto = pcall(issecretvalue, valor)
      if not comprobado or secreto then return nil end
    end
    if valor == true or valor == 1 then return true end
    if valor == false or valor == 0 then return false end
    return nil
  end
  local moderna = type(C_AddOns) == "table" and C_AddOns.IsAddOnLoaded
  local estado = consultar(moderna)
  if estado ~= nil then return estado end
  estado = consultar(IsAddOnLoaded)
  if estado ~= nil then return estado end
  if type(moderna) == "function" or type(IsAddOnLoaded) == "function" then return nil end
  return false -- clientes sin API: conservar la migración histórica
end

local function TraerNombreViejo()
  if GuiaLeveoCuenta ~= nil or GuiaLeveoRespaldo ~= nil or GuiaLeveoDB ~= nil then
    if EstadoGuiaLeveoR13() ~= false then
      GL.erroresCarga = GL.erroresCarga or {}
      local aviso = GL.L"No se migraron los datos de GuiaLeveo: desactiva el addon antiguo y recarga."
      for _, texto in ipairs(GL.erroresCarga) do if texto == aviso then return end end
      table.insert(GL.erroresCarga, aviso)
      return
    end
  end
  for _, par in ipairs({ { "GuiaLeveoCuenta", "GuiaAventureroCuenta" }, { "GuiaLeveoRespaldo", "GuiaAventureroRespaldo" },
      { "GuiaLeveoDB", "GuiaAventureroDB" } }) do
    local viejo, actual = _G[par[1]], _G[par[2]]
    if type(viejo) == "table" and (type(actual) ~= "table" or next(actual) == nil) then
      if actual ~= nil and type(actual) ~= "table" then
        local a = viejo.reparacionesNombreR09
        if type(a) ~= "table" then a = { anterior = a }; viejo.reparacionesNombreR09 = a end
        local k = par[2] .. ":raiz"; local i = 1
        while a[k] ~= nil and a[k] ~= actual do i = i + 1; k = par[2] .. ":raiz#" .. i end
        a[k] = type(actual) == "number" and (actual ~= actual or math.abs(actual) == math.huge) and tostring(actual) or actual
      end
      _G[par[2]] = viejo
    elseif viejo ~= nil and viejo ~= actual then
      -- Conservar ambos orígenes si existen; no mezclar campos con identidad desconocida.
      if type(actual) ~= "table" then actual = { raizAnteriorR09 = actual }; _G[par[2]] = actual end
      local a = actual.reparacionesNombreR09
      if type(a) ~= "table" then a = { anterior = a }; actual.reparacionesNombreR09 = a end
      local k = par[1]; local i = 1
      while a[k] ~= nil and a[k] ~= viejo do i = i + 1; k = par[1] .. "#" .. i end
      a[k] = viejo
    end
    _G[par[1]] = nil
  end
end
GL._TraerNombreViejo = TraerNombreViejo   -- para las pruebas

-- R13: UISpecialFrames pertenece al cliente y se comparte con los demás addons.
-- Solo registrar/retirar nombres propios, sin reemplazar la tabla ni tocar entradas ajenas.
function GL.RegistrarCierreEscapeR13(nombre, activar)
  if type(nombre) ~= "string" or nombre:sub(1, 14) ~= "GuiaAventurero" then return false end
  local lista = UISpecialFrames
  if type(lista) ~= "table" then return false end
  local primero
  for i = 1, #lista do
    if lista[i] == nombre then primero = i; break end
  end
  for i = #lista, 1, -1 do
    if lista[i] == nombre and (activar == false or i ~= primero) then table.remove(lista, i) end
  end
  if activar ~= false and not primero then table.insert(lista, nombre) end
  return true
end

-- 9.7.4: lo guardado por versiones anteriores puede tener un dato con otro tipo (una tabla donde ahora va
-- un número, un texto donde va una tabla...). Con eso la ventana no se abría. Se quita y vale lo de serie.
local TIPOS_DB = {
  table = { "aprendidosFuera", "atascos", "domadas", "establo", "estadisticas", "gSec", "ignorados", "mazMuertos", "mazNo",
    "notas", "pescaGuardado", "pescaPos", "pos", "posBuffs", "posCompacto", "posFlecha", "posFranja", "posMazmorra",
    "posNormal", "rangosIgnorados", "recalculos", "resumenActual", "resumenes", "sesionAnterior", "tam", "titulos",
    "vigiladas", "vuelos", "vuelosNPC" },
  number = { "escala", "alphaVentana", "escalaFlecha", "opacidad", "anguloMinimapa", "tamTexto" },
  boolean = { "alturaFlecha" },
  string = { "especializacion", "rutaElegida", "ruta" },
}
-- Límites de los deslizadores existentes (Opciones.lua).
local LIMITES_DB = {
  escala = { 0.6, 1.5 }, alphaVentana = { 0.3, 1 },
  escalaFlecha = { 0.6, 2 }, opacidad = { 0.2, 1 }, tamTexto = { 0.8, 1.5 },
}
-- Copia diagnóstica independiente de los datos reparados: no introducir valores
-- que SavedVariables ni el respaldo estricto puedan representar de forma segura.
function GL.CopiaDiagnosticoR14(valor)
  local function copiar(v, vistos, profundidad)
    local tipo=type(v)
    if tipo=="number" then
      return (v~=v or v==math.huge or v==-math.huge) and tostring(v) or v
    elseif tipo=="string" or tipo=="boolean" or tipo=="nil" then return v
    elseif tipo~="table" then return "[tipo:"..tipo.."]" end
    if vistos[v] then return "[ciclo]" end
    if profundidad>64 then return "[profundidad]" end
    vistos[v]=true
    local r, omitidas={},0
    for k,x in pairs(v) do
      local t=type(k)
      if t=="string" or t=="boolean" or (t=="number" and k==k and k>-math.huge and k<math.huge) then
        r[k]=copiar(x,vistos,profundidad+1)
      else omitidas=omitidas+1 end
    end
    if omitidas>0 then
      local k="[claves no serializables]";while r[k]~=nil do k=k.."#" end;r[k]=omitidas
    end
    vistos[v]=nil
    return r
  end
  return copiar(valor,{},0)
end
local function LimpiarGuardado()
  local db = GuiaAventureroDB
  if type(db) ~= "table" then return 0 end
  local n = 0
  local function reparar(k, v, nuevo, archivo)
    local a = db.reparacionesR09
    if type(a) ~= "table" then a = { anterior = GL.CopiaDiagnosticoR14(a) }; db.reparacionesR09 = a end
    archivo=archivo or k
    if a[archivo] == nil then
      a[archivo] = GL.CopiaDiagnosticoR14(v)
    end
    db[k] = nuevo
    n = n + 1
  end
  for tipo, claves in pairs(TIPOS_DB) do
    for _, k in ipairs(claves) do
      local v = db[k]
      if v ~= nil then
        if tipo == "number" then
          local numero = (type(v) == "number" or type(v) == "string") and tonumber(v)
          if not numero or numero ~= numero or numero == math.huge or numero == -math.huge then
            reparar(k, v, nil)
          else
            local limites = LIMITES_DB[k]
            if limites then numero = math.max(limites[1], math.min(limites[2], numero)) end
            if k == "anguloMinimapa" then numero = numero % 360 end
            if type(v) ~= "number" or v ~= numero then reparar(k, v, numero) end
          end
        elseif type(v) ~= tipo then
          reparar(k, v, nil)
        end
      end
    end
  end
  -- R14: conservar las estadísticas originales si hay que reparar una parte interna.
  local function numero(v, negativo)
    local x = (type(v)=="number" or type(v)=="string") and tonumber(v)
    if x and x==x and x>-math.huge and x<math.huge and (negativo or x>=0) then return x end
  end
  local function copiar(t)
    local c={}; for k,v in pairs(t) do c[k]=v end; return c
  end
  local e = db.estadisticas
  if type(e)=="table" then
    local nuevo, cambio = copiar(e), false
    local niveles = {}
    if type(e.niveles)=="table" then
      for k,d in pairs(e.niveles) do
        -- No convertir claves de nivel ambiguas ni fusionar dos registros.
        if type(k)=="number" and k>=0 and k<math.huge and k%1==0 and type(d)=="table" then
          local fila, mal = copiar(d), false
          for _, campo in ipairs({"t","q","xp"}) do
            local x=numero(d[campo]) or 0
            if x~=d[campo] then fila[campo]=x; mal=true end
          end
          niveles[k]=mal and fila or d; cambio=cambio or mal
        else cambio=true end
      end
    else cambio=true end
    if cambio then nuevo.niveles=niveles end
    if e.muertes~=nil then
      local x=numero(e.muertes) or 0
      if x~=e.muertes then nuevo.muertes=x; cambio=true end
    end
    if cambio then reparar("estadisticas",e,nuevo,"estadisticas.R14") end
  end
  local an=db.sesionAnterior
  if type(an)=="table" then
    local nuevo, cambio=copiar(an),false
    for _,k in ipairs({"t","xp","q","oro"}) do
      local x=numero(an[k],k=="oro") or 0
      if x~=an[k] then nuevo[k]=x; cambio=true end
    end
    if an.fin~=nil then
      local x=numero(an.fin)
      if x and (x%1~=0 or x>253402300799) then x=nil end
      if x~=an.fin then nuevo.fin=x; cambio=true end
    end
    if cambio then reparar("sesionAnterior",an,nuevo,"sesionAnterior.R14") end
  end
  return n
end
GL._LimpiarGuardado = LimpiarGuardado   -- para las pruebas

local function PrepararIdiomaGuardadoR13()
  local c = GL.IdiomaElegido()
  if c == "en" then GL.ingles = true elseif c == "es" then GL.ingles = false else GL.ingles = GL.clienteIngles end
  if GL.ingles then LeerBloques() else
    -- Solo los textos narrativos de rutas son innecesarios con la guía en español.
    -- Conservar los diccionarios para consultas explícitas en inglés.
    local pendientes = {}
    for _, b in ipairs(bloques) do if b[3] ~= "rutas" then pendientes[#pendientes + 1] = b end end
    bloques = pendientes
  end
  if GL.TraducirDatos then GL.TraducirDatos(GL.WH) end   -- los opcionales se traducen al juntarlos (Continentes.lua)
end

-- El orden de entrega de ADDON_LOADED a distintos marcos no es una dependencia fiable.
-- Ejecutar las fases una sola vez, con los módulos del TOC ya cargados.
local estadoCargaR13
function GL.InicializarGuardadosR13()
  if estadoCargaR13 then return estadoCargaR13 == "fin" end
  estadoCargaR13 = "en curso"
  local function fase(nombre, fn)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn)
    if not ok then
      GL.erroresCarga = GL.erroresCarga or {}
      table.insert(GL.erroresCarga, nombre .. ": " .. tostring(err))
    end
  end
  fase("Idioma/migración", TraerNombreViejo)
  -- Captura el contenido ya recuperado del nombre antiguo, antes de repararlo.
  fase("Respaldo", GL.CapturarGuardadosAlCargarR13)
  fase("Guardados", LimpiarGuardado)
  fase("Idioma", PrepararIdiomaGuardadoR13)
  fase("Editor", GL.RegistrarRutasPropiasR13)
  fase("Novedades", GL.LeerVersionAnteriorR13)
  estadoCargaR13 = "fin"
  return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, _, nombre)
  if nombre ~= "GuiaAventurero" then return end
  self:UnregisterEvent("ADDON_LOADED")
  GL.InicializarGuardadosR13()
end)

------------------------------------------------------------------------
-- Rutas en inglés: al cargar la ruta se cambian sus textos por los ingleses.
-- Los destinos «Recoger: misión (PNJ)» se rehacen con el nombre inglés de la misión (por su id) y del PNJ.
------------------------------------------------------------------------
local PREFIJOS = { ["Recoger"] = "Accept", ["Entregar"] = "Turn in", ["Objetivo"] = "Objective" }
GL.prefijosIngles = PREFIJOS

-- GL.misionesIngles[id] = nombre inglés de la misión (Idioma\enUS_Nombres.lua)
local function NombreMision(q, es)
  local t = GL.misionesIngles
  if q and t then
    if t[q] == nil and #bloques > 0 then LeerBloques(t) end
    if t[q] then return t[q] end
  end
  return Simbolos(GL.EnIngles(es))
end
GL.NombreMisionIngles = NombreMision

local function TraducirDestino(d)
  if GL.ingles and type(d.n) == "string" then
    local pre, resto = d.n:match("^([^:]+): (.+)$")
    if pre and PREFIJOS[pre] then
      local mision, pnj = resto:match("^(.*) (%b())$")
      if pnj then pnj = pnj:sub(2, -2) end
      if not mision then mision = resto end
      local t = PREFIJOS[pre] .. ": " .. NombreMision(d.q, mision)
      if pnj then t = t .. " (" .. Traducir(pnj) .. ")" end
      d.n = t
    else
      d.n = Traducir(d.n)
    end
  end
  if type(d.z) == "string" then
    d.zonaOriginalR11 = d.zonaOriginalR11 or d.z
    d.z = TraducirCliente(d.zonaOriginalR11)
  end
end
-- La zona de navegación sigue siendo la del cliente; la visible usa la clave original.
function GL.ZonaDestinoGuiaR11(d)
  if type(d) ~= "table" then return "" end
  local z = d.zonaOriginalR11 or d.z
  return type(z) == "string" and Traducir(z) or ""
end
GL.TraducirDestino = TraducirDestino

-- Textos de la guía (idioma de la guía) y nombres del juego (idioma del cliente). Los nombres de los talentos
-- no se tocan: ya llevan los dos idiomas («Ferocidad (Ferocity)») y así se buscan en el árbol.
local GUIA = { "t", "nota", "notaDespues", "titulo", "entrenar", "equipo", "profesion", "intro", "talentosIntro",
  "nombre", "rama", "misionNombre", "instructor", "desc", "d" }
local CLIENTE = { "z", "zona", "vuelo", "lugar" }

local function TraducirTabla(t, vistos, talentos)
  if type(t) ~= "table" or vistos[t] then return end
  vistos[t] = true
  if t.wp == nil and type(t.n) == "string" and (t.m or t.x) then TraducirDestino(t) end
  if GL.ingles then
    for _, k in ipairs(GUIA) do
      if type(t[k]) == "string" and not (k == "nombre" and (talentos or t.skill)) then t[k] = Traducir(t[k]) end
    end
  end
  for _, k in ipairs(CLIENTE) do
    if type(t[k]) == "string" then t[k] = TraducirCliente(t[k]) end
  end
  if t.skill and type(t.nombre) == "string" then t.nombre = TraducirCliente(t.nombre) end   -- profesiones: como en el juego
  for k, v in pairs(t) do
    if type(v) == "table" then
      if k == "wp" then
        for _, d in ipairs(v) do if type(d) == "table" then TraducirDestino(d) end end
      else
        TraducirTabla(v, vistos, talentos)
      end
    end
  end
end

-- Un plan de talentos: rama y nota en inglés; «Ferocidad (Ferocity)» pasa a «Ferocity (Ferocidad)» (Talentos.lua
-- busca los dos nombres, en cualquier orden).
function GL.TraducirTalentos(lista)
  if not GL.ingles or type(lista) ~= "table" then return end
  for _, t in ipairs(lista) do
    if type(t) == "table" and not t.traducido then
      t.traducido = true
      if type(t.rama) == "string" then t.rama = Traducir(t.rama) end
      if type(t.nota) == "string" then t.nota = Traducir(t.nota) end
      local es, en
      if type(t.nombre) == "string" then es, en = t.nombre:match("^(.-)%s*%((.-)%)%s*$") end
      if es and en and en ~= "" then t.nombre = en .. " (" .. es .. ")" end
    end
  end
end

-- Se llama tras cargar la ruta (GuiaAventurero.lua, Iniciar). Las ramas se cambian en todas partes por igual
-- (ramas, talentos, especialidades y ramaHechizo) para que sigan casando entre sí.
function GL.TraducirRuta(R)
  if not (GL.ingles or GL.clienteIngles) or type(R) ~= "table" or R.traducida then return end
  R.traducida = true
  local vistos = {}
  if type(R.talentos) == "table" then vistos[R.talentos] = true; GL.TraducirTalentos(R.talentos) end
  if GL.ingles then
    R.especialidadesOriginalesR11 = {}
    for i, e in ipairs(R.especialidades or {}) do
      R.especialidadesOriginalesR11[i] = e
      R.especialidades[i] = Traducir(e)
    end
    vistos[R.especialidadesOriginalesR11] = true
    for id, r in pairs(R.ramaHechizo or {}) do
      if type(r) == "string" then R.ramaHechizo[id] = Traducir(r)
      elseif type(r) == "table" then for i, x in ipairs(r) do r[i] = Traducir(x) end end
      vistos[r] = true
    end
    if type(R.especialidades) == "table" then vistos[R.especialidades] = true end
    if type(R.nombresPropios) == "table" then vistos[R.nombresPropios] = true end
  end
  for k, v in pairs(R) do
    if type(v) == "table" then TraducirTabla(v, vistos)
    elseif type(v) == "string" and GL.ingles and (k == "nombre" or k == "talentosIntro" or k == "instructor") then R[k] = Traducir(v) end
  end
end

------------------------------------------------------------------------
-- Datos (DatosWowhead.lua y los opcionales de Continentes.lua): sus textos cortos y nombres en inglés.
-- Lo que tiene nombre inglés propio (ing) lo usa; los jefes van como en el juego (se reconocen al morir).
------------------------------------------------------------------------
local DATOS = { "n", "d", "de", "donde", "r", "desc", "quien", "vendedor", "como", "fuente", "nota", "t", "titulo",
  "rol", "mat", "nombre", "lado" }
local LISTAS_GUIA = { armas = true }
local LISTAS_CLIENTE = { zonas = true }

local function TraducirDato(t, vistos, jefes)
  if type(t) ~= "table" or vistos[t] then return end
  vistos[t] = true
  if t.wp == nil and type(t.n) == "string" and (t.m or t.x) and t.n:find(": ", 1, true) then
    TraducirDestino(t)
  elseif type(t.n) == "string" then
    if jefes then
      t.nombreOriginal977 = t.nombreOriginal977 or t.n
      t.n = (GL.clienteIngles and t.ing) or TraducirCliente(t.nombreOriginal977)
    elseif GL.ingles then t.n = t.ing or Traducir(t.n) end
  end
  if t.sp and type(t.r) == "string" then t.recetaOriginal9775 = t.recetaOriginal9775 or t.r end
  if GL.ingles then
    for _, k in ipairs(DATOS) do
      if k ~= "n" and type(t[k]) == "string" then t[k] = Traducir(t[k]) end
    end
  end
  for _, k in ipairs(CLIENTE) do
    if type(t[k]) == "string" then t[k] = TraducirCliente(t[k]) end
  end
  for k, v in pairs(t) do
    if type(v) == "table" then
      if k == "wp" then
        for _, d in ipairs(v) do if type(d) == "table" then TraducirDestino(d) end end
      elseif LISTAS_GUIA[k] or LISTAS_CLIENTE[k] then
        local f = LISTAS_GUIA[k] and Traducir or TraducirCliente
        for i, x in ipairs(v) do if type(x) == "string" then v[i] = f(x) end end
      else
        if GL.ingles and type(k) == "number" and v.wp and type(v.n) == "string" then v.n = NombreMision(k, v.n) end
        TraducirDato(v, vistos, jefes or k == "jefes")
      end
    end
  end
end

function GL.TraducirDatos(t)
  if not (GL.ingles or GL.clienteIngles) or type(t) ~= "table" then return end
  TraducirDato(t, {}, false)
end

------------------------------------------------------------------------
-- Ajustes > General: Idioma (Automático, Español, English). Vale al recargar la interfaz.
------------------------------------------------------------------------
local L = GL.L
local function AvisarRecarga()
  local nombres = { auto = L"automático (el del juego)", es = "español", en = "English" }
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fb3ff" .. L"Guía del Aventurero" .. ":|r " .. L"idioma: " .. nombres[GL.IdiomaElegido()] ..
      ". " .. L"Escribe /reload para cambiarlo.")
  end
end

-- /ga idioma es|en|auto
function GL.ComandoIdioma(arg)
  arg = (type(arg) == "string" and arg or ""):match("^%s*(.-)%s*$"):lower()
  if arg == "es" or arg == "español" or arg == "espanol" then GL.PonerIdioma("es")
  elseif arg == "en" or arg == "english" or arg == "inglés" or arg == "ingles" then GL.PonerIdioma("en")
  elseif arg == "auto" or arg == "automático" or arg == "automatico" then GL.PonerIdioma("auto")
  else
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(L"Uso: /ga idioma es|en|auto")
    end
    return
  end
  AvisarRecarga()
end

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "idioma", "Idioma de la guía (Language)",
  "Automático: el del juego. Español o English: siempre ese. Vale al recargar (/reload).",
  function() return GL.IdiomaElegido() end,
  function(v) GL.PonerIdioma(v); AvisarRecarga() end,
  opciones = { { "auto", "Automático" }, { "es", "Español" }, { "en", "English" } }, pestana = "general" })

-- Informe.lua (9.1): /ga informe junta en un solo texto lo que hace falta para avisar de un fallo:
-- versión del addon y del cliente, personaje y dónde estás, el paso actual, los errores de esta sesión
-- (también los del juego que nombran a la guía), los pasos apuntados con /ga atascado, los cambios de
-- ruta automáticos y, al final, el diagnóstico completo de /ga depurar. Se abre en una ventana para
-- copiarlo con Ctrl+C. /ga informe borrar vacía los errores apuntados.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L

local function DB() return GuiaAventureroDB or {} end

------------------------------------------------------------------------
-- Errores de Lua del juego que vienen de la guía: se apuntan y se pasan al manejador de siempre
------------------------------------------------------------------------
local enganchado = false
local function EngancharErrores()
  if enganchado or not (geterrorhandler and seterrorhandler) then return end
  enganchado = true
  local anterior = geterrorhandler()
  seterrorhandler(function(msg, ...)
    local texto = tostring(msg)
    if string.find(texto, "GuiaAventurero", 1, true) and GL.Fallo then pcall(GL.Fallo, "juego", texto) end
    if anterior then return anterior(msg, ...) end
  end)
end
pcall(EngancharErrores)

------------------------------------------------------------------------
-- Texto del informe
------------------------------------------------------------------------
local function Corto(t, max)
  t = tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  if #t > max then t = t:sub(1, max) .. "..." end
  return t
end

local function TextoInforme()
  local lineas = {}   -- 9.7.4: antes se llamaba L y tapaba la traducción: /ga informe fallaba
  local function Linea(t) table.insert(lineas, t) end
  local function Bloque(nombre, fn)
    local ok, err = pcall(fn)
    if not ok then Linea(nombre .. L": no se pudo consultar (" .. tostring(err) .. ")") end
  end
  local db = DB()
  Linea(L"GUÍA DEL AVENTURERO · INFORME PARA AVISAR DE UN FALLO")
  Linea(L"Fecha: " .. tostring((date and date("%d-%m-%Y %H:%M")) or "?"))
  Bloque(L"Versión", function()
    local leer = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local toc = leer and leer("GuiaAventurero", "Version") or "?"
    local version, build = "?", "?"
    if GetBuildInfo then version, build = GetBuildInfo() end
    Linea(L"Versión de la guía: " .. tostring(GL.VERSION or "?") .. " (toc " .. tostring(toc) .. L") · cliente " ..
      tostring(version) .. " (" .. tostring(build) .. L") · idioma " .. tostring(GetLocale and GetLocale() or "?"))
  end)
  Bloque(L"Personaje", function()
    local _, clase = UnitClass("player")
    local fac = UnitFactionGroup and UnitFactionGroup("player") or "?"
    Linea(L"Personaje: " .. tostring(clase) .. ", " .. tostring(GL.Raza and GL.Raza()) .. ", " .. tostring(fac) ..
      L", nivel " .. tostring(UnitLevel("player")))
    -- 9.7.7.3: para ver por qué no se guarda un personaje en Cuenta
    local n = 0
    if type(GuiaAventureroCuenta) == "table" and type(GuiaAventureroCuenta.personajes) == "table" then
      for _ in pairs(GuiaAventureroCuenta.personajes) do n = n + 1 end
    end
    Linea(L"Cuenta: reino «" .. tostring(GetRealmName and GetRealmName()) .. L"», clave «" ..
      tostring(GL.ClavePersonajeCuenta and GL.ClavePersonajeCuenta()) .. L"», personajes guardados: " .. n)
  end)
  Bloque(L"Dónde", function()
    local zona = (GetZoneText and GetZoneText()) or "?"
    local sub = (GetSubZoneText and GetSubZoneText()) or ""
    local m, x, y
    if GL.PosicionJugador then m, x, y = GL.PosicionJugador() end
    Linea(L"Dónde: " .. tostring(zona) .. (sub ~= "" and (" (" .. sub .. ")") or "") .. L" · mapa " .. tostring(m) ..
      (x and string.format(" · %.1f, %.1f", x * 100, y * 100) or "") ..
      (GL.ContinenteActual and (L" · datos cargados: " .. GL.ContinenteActual()) or ""))
  end)
  Bloque(L"Paso", function()
    local R = GL.RUTA
    if not R then Linea(L"Ruta: NINGUNA cargada"); return end
    Linea(L"Ruta: " .. tostring(R.id) .. L" · sección " .. tostring(db.seccion) .. L", paso " .. tostring(db.paso) ..
      L", destino " .. tostring(db.destino) .. (db.rutaElegida and (L" · elegida a mano: " .. tostring(db.rutaElegida)) or ""))
    local s, p = GL.PasoActual()
    if s then Linea(L"Sección: " .. Corto(s.titulo, 60) .. " (" .. tostring(s.min) .. "-" .. tostring(s.max) .. ")") end
    if p then
      Linea(L"Paso: " .. Corto(p.t, 200))
      Linea(L"Estado del paso: " .. tostring(GL.EstadoPaso and GL.EstadoPaso(p)))
    end
  end)

  Linea("")
  local errores = GL.erroresJuego or {}
  local carga = GL.erroresCarga or {}
  Linea(L"ERRORES (" .. (#errores + #carga) .. ")")
  if #errores + #carga == 0 then Linea(L"  ninguno en esta sesión") end
  for i = 1, #carga do Linea(L"  al cargar: " .. Corto(carga[i], 300)) end
  for i = 1, #errores do
    local e = errores[i]
    Linea("  " .. tostring(e.hora) .. (e.veces > 1 and (" (x" .. e.veces .. ")") or "") .. " " .. Corto(e.texto, 400))
  end

  Linea("")
  local atascos = (type(db.atascos) == "table") and db.atascos or {}
  Linea(L"PASOS ATASCADOS (" .. #atascos .. ")" .. (#atascos == 0 and L"  ·  apunta uno con /ga atascado" or ""))
  for i = 1, #atascos do Linea("#" .. i .. "  " .. tostring(atascos[i])) end

  local hist = (type(db.recalculos) == "table") and db.recalculos or {}
  if #hist > 0 then
    Linea("")
    Linea(L"CAMBIOS DE RUTA AUTOMÁTICOS (últimos " .. math.min(#hist, 10) .. ")")
    for i = math.max(1, #hist - 9), #hist do Linea("  " .. tostring(hist[i])) end
  end

  -- 9.7.9.1: talentos del plan que no están en tu árbol y lo que tienes puesto (para ver si cambian los nombres en Forever)
  local okT, dt = pcall(function() return GL.DiagnosticoTalentos979 and GL.DiagnosticoTalentos979() end)
  if okT and type(dt) == "table" then
    Linea("")
    Linea(L"TALENTOS")
    Linea(L"  Del plan que no están en tu árbol con ese nombre (" .. #dt.fuera .. "): " .. (#dt.fuera > 0 and table.concat(dt.fuera, ", ") or L"ninguno"))
    Linea(L"  Puestos en tu árbol (" .. #dt.puestos .. "): " .. (#dt.puestos > 0 and table.concat(dt.puestos, ", ") or L"ninguno"))
    if dt.resto then Linea(L"  Sin puntos en tu árbol (" .. #dt.resto .. "): " .. (#dt.resto > 0 and table.concat(dt.resto, ", ") or L"ninguno")) end
  end
  Linea("")
  Linea(L"--- DIAGNÓSTICO COMPLETO ---")
  if GL.InformeDiagnostico then
    local ok, t = pcall(GL.InformeDiagnostico)
    Linea(ok and t or (L"no se pudo preparar: " .. tostring(t)))
  end
  return table.concat(lineas, "\n")
end
GL.TextoInforme = TextoInforme

GL.comandos = GL.comandos or {}
GL.comandos["informe"] = function(orden)
  if orden == "borrar" then
    GL.erroresJuego = {}
    if GL.Mensaje then GL.Mensaje(L"errores apuntados borrados (los pasos atascados se borran con /ga atascado borrar).") end
    return
  end
  local ok, texto = pcall(TextoInforme)
  if not ok then if GL.Mensaje then GL.Mensaje(L"no se pudo preparar el informe: " .. tostring(texto)) end return end
  local ok2 = GL.MostrarInforme and pcall(GL.MostrarInforme, texto)
  if ok2 then
    if GL.Mensaje then GL.Mensaje(L"informe abierto: pulsa Ctrl+C para copiarlo y pégalo donde te lo pidan.") end
  elseif GL.Mensaje then
    for linea in string.gmatch(texto .. "\n", "(.-)\n") do GL.Mensaje(linea) end
  end
end
GL._informe = { Texto = TextoInforme }   -- para las pruebas

-- Respaldo.lua (9.1): copia de seguridad de lo guardado antes de que una versión nueva lo cambie.
-- Al cargar el addon (antes de las migraciones), si la versión con la que se guardó este personaje no es la de
-- ahora, se copia GuiaAventureroDB (este personaje) y GuiaAventureroCuenta (toda la cuenta, sin los propios respaldos) en
-- GuiaAventureroRespaldo. Solo se guarda la última copia de cada personaje y de la cuenta.
-- /ga restaurar dice qué copia hay; /ga restaurar si la pone en lugar de lo de ahora (este
-- personaje) y /ga restaurar cuenta, también lo de la cuenta. Después se recarga la interfaz.
-- También en Ajustes › Datos.
-- Creado por JKRiveroF.

local nombreAddon, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

-- Una copia incompleta no es un respaldo válido. Rechazarla sin modificar los originales.
local function Finito(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function Escalar(v) return type(v)=="string" or type(v)=="boolean" or Finito(v) end
local function Copia(v, prof, vistos)
  if type(v) ~= "table" then
    if Escalar(v) then return v end
    return nil, "tipo"
  end
  if prof > 64 or vistos[v] then return nil, "estructura" end
  vistos[v] = true
  local t = {}
  for k, x in pairs(v) do
    if not Escalar(k) then return nil, "clave" end
    local c, err = Copia(x, prof+1, vistos)
    if err then return nil, err end
    t[k] = c
  end
  vistos[v] = nil
  return t
end
local function Clave()
  if type(GL.ClavePersonajeCuenta) ~= "function" then return nil end
  local ok, k, n, r, guid = pcall(GL.ClavePersonajeCuenta)
  if ok and type(k)=="string" and type(guid)=="string" and guid:match("^Player%-%w+%-%w+$") then
    return guid, k
  end
end
-- No vaciar un almacén dañado ni atribuir una copia histórica por nombre a otro GUID.
local function Almacen(crear)
  local A = GuiaAventureroRespaldo
  if A == nil and crear then A = {pj={}}; GuiaAventureroRespaldo = A end
  if type(A) ~= "table" then return nil end
  if A.pj == nil and crear then A.pj = {} end
  if A.pj ~= nil and type(A.pj) ~= "table" then return nil end
  return A
end
local function Fecha() return (date and date("%d-%m-%Y %H:%M")) or "?" end
local function RegistroValido(p) return type(p)=="table" and type(p.datos)=="table" end
local function Registro(d, motivo, guid, nombre)
  return { version = d.version, nueva = GL.VERSION, fecha = Fecha(), motivo = motivo, datos = d, guid=guid, nombre=nombre }
end
local function Fallo()
  return false, L"No se pudo completar la copia o restauración; no se sustituyeron los datos activos."
end
-- Capturar antes de migrar; si aún no hay GUID, conservar la captura en memoria hasta PLAYER_LOGIN.
local pendiente, completado = nil, false
local function Captura()
  local db, cuenta = GuiaAventureroDB, GuiaAventureroCuenta
  if db ~= nil and type(db)~="table" then return nil end
  if cuenta ~= nil and type(cuenta)~="table" then return nil end
  local d, c = Copia(db or {},0,{}), Copia(cuenta or {},0,{})
  if not d or not c then return nil end
  return {db=d, cuenta=c}
end
local function Hacer(motivo, captura)
  local guid, nombre = Clave()
  if not guid then return false, L"Identidad del personaje aún sin confirmar." end
  local A = Almacen(false)
  if GuiaAventureroRespaldo ~= nil and not A then return Fallo() end
  captura = captura or Captura()
  if not captura then return Fallo() end
  local anterior = A and A.pj and A.pj[guid]
  local cuentaAnterior = A and A.cuenta
  if (anterior ~= nil and (not RegistroValido(anterior) or anterior.guid ~= guid)) or (cuentaAnterior ~= nil and not RegistroValido(cuentaAnterior)) then return Fallo() end
  local db, cuenta = captura.db, captura.cuenta
  local manual = motivo == L"a mano"
  local guardarPJ = next(db) ~= nil and (manual or db.version ~= GL.VERSION)
  local guardarCuenta = next(cuenta) ~= nil and (manual or not cuentaAnterior or cuentaAnterior.nueva ~= GL.VERSION)
  if not guardarPJ and not guardarCuenta then
    if manual then return Fallo() end
    return true
  end
  -- Una copia dañada por dentro también se conserva: no sobrescribirla silenciosamente.
  -- Validar solo los registros que se van a sustituir, sin copiar los ajenos.
  if guardarPJ and anterior and not Copia(anterior.datos,0,{}) then return Fallo() end
  if guardarCuenta and cuentaAnterior and not Copia(cuentaAnterior.datos,0,{}) then return Fallo() end
  local p = guardarPJ and Registro(db,motivo,guid,nombre)
  local c = guardarCuenta and Registro(cuenta,motivo)
  if c then c.version = cuentaAnterior and cuentaAnterior.nueva or nil end
  A = Almacen(true)
  if not A then return Fallo() end
  if p then A.pj[guid] = p end
  if c then A.cuenta = c end
  return true
end
local function AlCargar()
  if completado then return true end
  local guid = Clave()
  if pendiente == nil then pendiente = Captura() or false end
  if not guid then return false, L"Identidad del personaje aún sin confirmar." end
  local A = Almacen(false)
  if A and A.saltar == guid then
    A.saltar = nil; pendiente=nil; completado=true; return true
  end
  if not pendiente then return Fallo() end
  local ok, err = Hacer(L"versión nueva", pendiente)
  if ok then pendiente=nil; completado=true end
  return ok, err
end
local function IntentarAlCargar(final)
  local ok, hecho, err = pcall(AlCargar)
  if final and (not ok or not hecho) then
    if type(GL.erroresCarga)=="table" then table.insert(GL.erroresCarga,L"copia de seguridad: "..tostring(ok and err or hecho)) end
    if GL.Mensaje then GL.Mensaje(L"No se pudo completar la copia automática antes de migrar; revisa tus respaldos.") end
  end
  return ok and hecho
end
GL.RespaldoAntesDeMigrarR09 = function() return IntentarAlCargar(true) end
-- Idioma.lua coordina esta captura antes de LimpiarGuardado.
GL.CapturarGuardadosAlCargarR13 = function() return IntentarAlCargar(false) end
local function Texto()
  local A = Almacen(false)
  if not A then return nil end
  local guid, nombre = Clave()
  local p, c = guid and A.pj and A.pj[guid], A.cuenta
  local l = {}
  if RegistroValido(p) and p.guid == guid then table.insert(l, L"personaje: del " .. tostring(p.fecha) .. L" (guardado con la " .. tostring(p.version or "?") .. L", antes de la " .. tostring(p.nueva) .. ")") end
  if RegistroValido(c) then table.insert(l, L"cuenta: del " .. tostring(c.fecha) .. L" (antes de la " .. tostring(c.nueva) .. ")") end
  if nombre and A.pj and A.pj[nombre] ~= nil then table.insert(l,L"Copia histórica sin GUID conservada; no se restaura automáticamente.") end
  if #l>0 then return table.concat(l,"; ") end
end
GL.TextoRespaldo = Texto
local function Restaurar(conCuenta)
  local A = Almacen(false)
  local guid, nombre = Clave()
  local p = guid and A and A.pj and A.pj[guid]
  if not RegistroValido(p) or p.guid ~= guid then GL.Mensaje(L"no hay copia de este personaje."); return false end
  if conCuenta and not RegistroValido(A.cuenta) then GL.Mensaje(L"No hay una copia válida de la cuenta; no se restauró nada."); return false end
  if type(ReloadUI) ~= "function" or not GL.AccionProtegidaPermitidaR13 or not GL.AccionProtegidaPermitidaR13() then
    GL.Mensaje(L"La restauración requiere poder recargar la interfaz fuera de combate."); return false
  end
  local ahora = Captura()
  local nuevo = Copia(p.datos,0,{})
  local nuevaCuenta = conCuenta and Copia(A.cuenta.datos,0,{})
  if not ahora or not nuevo or (conCuenta and not nuevaCuenta) then local _,err=Fallo();GL.Mensaje(err);return false end
  -- Preparar ambas sustituciones y sus copias de vuelta antes de modificar ninguna variable.
  local regreso = Registro(ahora.db,L"antes de restaurar",guid,nombre)
  local regresoCuenta = conCuenta and Registro(ahora.cuenta,L"antes de restaurar")
  local dbAnterior, cuentaAnterior, respaldoCuenta, saltarAnterior = GuiaAventureroDB, GuiaAventureroCuenta, A.cuenta, A.saltar
  GuiaAventureroDB = nuevo
  if conCuenta then GuiaAventureroCuenta = nuevaCuenta; A.cuenta = regresoCuenta end
  A.pj[guid] = regreso
  A.saltar = guid
  local ok, resultado = pcall(ReloadUI)
  if not ok or resultado == false then
    GuiaAventureroDB, GuiaAventureroCuenta = dbAnterior, cuentaAnterior
    A.pj[guid], A.cuenta, A.saltar = p, respaldoCuenta, saltarAnterior
    local _,err=Fallo();GL.Mensaje(err);return false
  end
  GL.Mensaje(L"copia restaurada" .. (conCuenta and L" (personaje y cuenta)" or "") .. L". Lo que tenías queda como copia por si quieres volver. Recargando...")
  return true
end

GL.comandos = GL.comandos or {}
GL.comandos["restaurar"] = function(orden)
  if orden == "si" or orden == "sí" then Restaurar(false) return end
  if orden == "cuenta" then Restaurar(true) return end
  if orden == "copia" then local ok, err = Hacer(L"a mano"); GL.Mensaje(ok and (L"copia hecha: " .. tostring(Texto() or "")) or err) return end
  local t = Texto()
  if not t then GL.Mensaje(L"aún no hay copia de seguridad: se hace sola al instalar una versión nueva (o con /ga restaurar copia).") return end
  GL.Mensaje(L"copia de seguridad: " .. t .. L". /ga restaurar si la pone en este personaje; /ga restaurar cuenta, también en la cuenta.")
end

-- Fila de Ajustes › Datos
GL.CrearFilaRespaldo = function(padre)
  local cont = CreateFrame("Frame", nil, padre)
  cont:SetHeight(58)
  cont.altoFila = 62
  cont.texto = GL.Texto(cont, "GameFontHighlightSmall")
  cont.texto:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, 0)
  cont.texto:SetPoint("RIGHT", cont, "RIGHT", 0, 0)
  if cont.texto.SetJustifyH then cont.texto:SetJustifyH("LEFT") end
  cont.copia = GL.CrearBoton(cont, L"Hacer copia", function() local ok,err=Hacer(L"a mano"); if not ok then GL.Mensaje(err) end; cont.Actualizar() end, nil, 22)
  cont.copia:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, -28)
  cont.copia:SetPoint("RIGHT", cont, "CENTER", -2, 0)
  cont.restaurar = GL.CrearBoton(cont, L"Restaurar", function()
    if not cont.confirmar then cont.confirmar = true; cont.restaurar.texto:SetText(L"¿Seguro? Clic otra vez"); return end
    cont.confirmar = nil
    Restaurar(false)
  end, nil, 22, "accion")
  cont.restaurar:SetPoint("TOPRIGHT", cont, "TOPRIGHT", 0, -28)
  cont.restaurar:SetPoint("LEFT", cont, "CENTER", 2, 0)
  if GL.Ayuda then GL.Ayuda(cont.restaurar, L"Restaurar la copia", L"Vuelve a lo que tenía este personaje antes de la última versión nueva y recarga. Lo de ahora queda como copia. Para la cuenta: /ga restaurar cuenta.") end
  cont.Actualizar = function()
    cont.confirmar = nil
    cont.restaurar.texto:SetText(L"Restaurar")
    local t = Texto()
    cont.texto:SetText(L"Copia de seguridad de lo guardado\n" .. C.GRIS .. (t or L"Aún no hay: se hace sola al instalar una versión nueva.") .. C.FIN)
    local A, guid = Almacen(false), Clave()
    local p = guid and A and A.pj and A.pj[guid]
    GL.Mostrar(cont.restaurar, RegistroValido(p) and p.guid==guid)
  end
  cont.Actualizar()
  return cont
end

GL._respaldo = { Hacer = Hacer, AlCargar = AlCargar, Restaurar = Restaurar, Texto = Texto, Copia = Copia }

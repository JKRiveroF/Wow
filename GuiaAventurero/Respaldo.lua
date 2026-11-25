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

local function Copia(v, prof, vistos)
  if type(v) ~= "table" then return v end
  if prof > 20 or vistos[v] then return nil end
  vistos[v] = true
  local t = {}
  for k, x in pairs(v) do
    local tk = type(k)
    if tk == "string" or tk == "number" or tk == "boolean" then
      local tx = type(x)
      if tx == "table" then t[k] = Copia(x, prof + 1, vistos)
      elseif tx == "string" or tx == "number" or tx == "boolean" then t[k] = x end
    end
  end
  vistos[v] = nil
  return t
end

local function Clave()
  local n = UnitName and UnitName("player")
  local r = GetRealmName and GetRealmName()
  return (n or "?") .. "-" .. (r or "")
end

local function Almacen()
  if type(GuiaAventureroRespaldo) ~= "table" then GuiaAventureroRespaldo = {} end
  if type(GuiaAventureroRespaldo.pj) ~= "table" then GuiaAventureroRespaldo.pj = {} end
  return GuiaAventureroRespaldo
end

local function Fecha() return (date and date("%d-%m-%Y %H:%M")) or "?" end

-- La versión con la que se guardó por última vez (Novedades.lua la pone en db.version al conectar)
local function Hacer(motivo)
  local A = Almacen()
  local db = GuiaAventureroDB
  if type(db) == "table" and next(db) then
    A.pj[Clave()] = { version = db.version, nueva = GL.VERSION, fecha = Fecha(), motivo = motivo, datos = Copia(db, 0, {}) }
  end
  if type(GuiaAventureroCuenta) == "table" and next(GuiaAventureroCuenta) then
    local version = A.cuenta and A.cuenta.nueva
    if motivo == L"a mano" or version ~= GL.VERSION then
      A.cuenta = { version = version, nueva = GL.VERSION, fecha = Fecha(), motivo = motivo, datos = Copia(GuiaAventureroCuenta, 0, {}) }
    end
  end
end

local function AlCargar()
  local db = GuiaAventureroDB
  if type(db) ~= "table" or not next(db) then return end   -- personaje nuevo: no hay nada que proteger
  if db.version == GL.VERSION then return end
  local A = Almacen()
  if A.saltar == Clave() then A.saltar = nil; return end   -- recién restaurado: la copia de lo de antes se queda
  Hacer(L"versión nueva")
end

local ev = CreateFrame("Frame")
GL.Evento(ev, "ADDON_LOADED")
ev:SetScript("OnEvent", function(self, _, nombre)
  if nombre ~= nombreAddon and nombre ~= "GuiaAventurero" then return end
  self:UnregisterEvent("ADDON_LOADED")
  local ok, err = pcall(AlCargar)
  if not ok then table.insert(GL.erroresCarga, L"copia de seguridad: " .. tostring(err)) end
end)

local function Texto()
  local A = Almacen()
  local p, c = A.pj[Clave()], A.cuenta
  if not p and not c then return nil end
  local l = {}
  if p then table.insert(l, L"personaje: del " .. tostring(p.fecha) .. L" (guardado con la " .. tostring(p.version or "?") .. L", antes de la " .. tostring(p.nueva) .. ")") end
  if c then table.insert(l, L"cuenta: del " .. tostring(c.fecha) .. L" (antes de la " .. tostring(c.nueva) .. ")") end
  return table.concat(l, "; ")
end
GL.TextoRespaldo = Texto

local function Restaurar(conCuenta)
  local A = Almacen()
  local p = A.pj[Clave()]
  if not p or type(p.datos) ~= "table" then GL.Mensaje(L"no hay copia de este personaje.") return false end
  local ahora = Copia(GuiaAventureroDB or {}, 0, {})
  GuiaAventureroDB = Copia(p.datos, 0, {})
  GuiaAventureroDB.version = p.version   -- así la versión de ahora vuelve a migrar desde ahí
  A.saltar = Clave()
  A.pj[Clave()] = { version = ahora.version, nueva = GL.VERSION, fecha = Fecha(), motivo = L"antes de restaurar", datos = ahora }
  if conCuenta and A.cuenta and type(A.cuenta.datos) == "table" then
    local cuentaAhora = Copia(GuiaAventureroCuenta or {}, 0, {})
    GuiaAventureroCuenta = Copia(A.cuenta.datos, 0, {})
    A.cuenta = { version = nil, nueva = GL.VERSION, fecha = Fecha(), motivo = L"antes de restaurar", datos = cuentaAhora }
  end
  GL.Mensaje(L"copia restaurada" .. (conCuenta and L" (personaje y cuenta)" or "") .. L". Lo que tenías queda como copia por si quieres volver. Recargando...")
  if ReloadUI then ReloadUI() end
  return true
end

GL.comandos = GL.comandos or {}
GL.comandos["restaurar"] = function(orden)
  if orden == "si" or orden == "sí" then Restaurar(false) return end
  if orden == "cuenta" then Restaurar(true) return end
  if orden == "copia" then Hacer(L"a mano"); GL.Mensaje(L"copia hecha: " .. tostring(Texto())) return end
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
  cont.copia = GL.CrearBoton(cont, L"Hacer copia", function() Hacer(L"a mano"); cont.Actualizar() end, nil, 22)
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
    GL.Mostrar(cont.restaurar, Almacen().pj[Clave()] ~= nil)
  end
  cont.Actualizar()
  return cont
end

GL._respaldo = { Hacer = Hacer, AlCargar = AlCargar, Restaurar = Restaurar, Texto = Texto, Copia = Copia }

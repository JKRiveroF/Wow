-- Editor.lua (9.1): editor de rutas en el juego y compartir una ruta con un código de texto.
-- /ga editor (o Ajustes › Datos › Editor de rutas) abre la ventana:
--  · Nueva ruta vacía o «Copiar sección»: la sección de la guía en la que estás, para cambiarla a tu gusto.
--  · Pasos: «Paso aquí» crea uno con tu posición; cada paso lleva su texto y sus destinos («Destino aquí» añade
--    tu posición, con la misión y la acción si las pones: así el paso avanza solo como los de la guía).
--  · Subir, Bajar y Borrar ordenan los pasos.
--  · Compartir da un código (GLR1:...) para pegarlo en el chat o a un amigo; Importar lee uno.
--  · «Usar esta ruta» la pone en lugar de la de tu clase (con /reload); «Volver a la guía» te devuelve a tu
--    sitio de la ruta normal. La ruta propia usa los talentos, hechizos y profesiones de la de tu clase.
-- Las rutas se guardan para toda la cuenta (GuiaAventureroCuenta.rutasPropias). El código no se ejecuta: se lee con el
-- lector de Traspaso.lua, que solo entiende números, textos, sí/no y tablas.
-- Creado por JKRiveroF.

local nombreAddon, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local PREFIJO = "GLR1:"
local FILAS = 8
local MAX_PASOS, MAX_DESTINOS = 300, 12

local function DB() return GuiaAventureroDB or {} end
local function Cuenta()
  if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
  if type(GuiaAventureroCuenta.rutasPropias) ~= "table" then GuiaAventureroCuenta.rutasPropias = {} end
  return GuiaAventureroCuenta.rutasPropias
end
local function Msg(t) if GL.Mensaje then GL.Mensaje(t) end end

------------------------------------------------------------------------
-- Datos: limpiar lo que llega (de un código o de lo guardado)
------------------------------------------------------------------------
local ACCIONES = { A = true, C = true, T = true }
local function Limpia(r)
  if type(r) ~= "table" or type(r.pasos) ~= "table" then return nil end
  local out = { nombre = tostring(r.nombre or L"Ruta sin nombre"):sub(1, 40), autor = r.autor and tostring(r.autor):sub(1, 40) or nil, pasos = {} }
  for i = 1, math.min(#r.pasos, MAX_PASOS) do
    local p = r.pasos[i]
    if type(p) == "table" then
      local q = { t = tostring(p.t or ""):sub(1, 600):gsub("|", "/"), wp = {} }
      for j = 1, math.min(type(p.wp) == "table" and #p.wp or 0, MAX_DESTINOS) do
        local d = p.wp[j]
        if type(d) == "table" and tonumber(d.m) and tonumber(d.x) and tonumber(d.y) then
          local e = { m = tonumber(d.m), x = math.floor(tonumber(d.x) * 10 + 0.5) / 10, y = math.floor(tonumber(d.y) * 10 + 0.5) / 10,
            z = d.z and tostring(d.z):sub(1, 50) or nil, n = tostring(d.n or (L"Destino " .. j)):sub(1, 80):gsub("|", "/") }
          if tonumber(d.q) and ACCIONES[d.a] then e.q, e.a = math.floor(tonumber(d.q)), d.a end
          table.insert(q.wp, e)
        end
      end
      table.insert(out.pasos, q)
    end
  end
  return out
end

local function Codigo(r)
  return PREFIJO .. (GL.CodificarDatos and GL.CodificarDatos(Limpia(r)) or "")
end
local function LeerCodigo(texto)
  texto = tostring(texto or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if texto:sub(1, #PREFIJO) ~= PREFIJO then return nil, L"el código no empieza por " .. PREFIJO end
  local datos = GL.LeerDatos and GL.LeerDatos(texto, #PREFIJO + 1)
  local r = Limpia(datos)
  if not r then return nil, L"el código está incompleto o cambiado" end
  if #r.pasos == 0 then return nil, L"la ruta no tiene pasos" end
  return r
end

local function NuevoId()
  local n = 1
  while Cuenta()["propia" .. n] do n = n + 1 end
  return "propia" .. n
end

local function Guardar(r)
  r.id = r.id or NuevoId()
  Cuenta()[r.id] = r
  return r
end

-- Posición del jugador como destino
local function DestinoAqui(nombre)
  if not GL.PosicionJugador then return nil end
  local m, x, y = GL.PosicionJugador()
  if not m then return nil end
  return { m = m, x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10,
    z = (GetZoneText and GetZoneText()) or nil, n = nombre }
end

------------------------------------------------------------------------
-- Las rutas propias como rutas de la guía (se apuntan al cargar el addon, antes de elegir la ruta)
------------------------------------------------------------------------
local function RutaDeLaClase()
  local _, clase = UnitClass("player")
  local raza = GL.Raza and GL.Raza()
  local faccion = UnitFactionGroup and UnitFactionGroup("player")
  local deLaClase
  for _, r in ipairs(GuiaAventurero_Rutas or {}) do
    if not r.propia and r.clase == clase and (not r.faccion or not faccion or r.faccion == faccion) then
      for _, z in ipairs(r.razas or {}) do if z == raza then return r end end
      deLaClase = deLaClase or r
    end
  end
  return deLaClase
end

local function Registrar()
  GuiaAventurero_Rutas = GuiaAventurero_Rutas or {}
  for id, guardada in pairs(Cuenta()) do
    local r = Limpia(guardada)
    if r and #r.pasos > 0 then
      local R = { id = id, nombre = r.nombre .. L" (propia)", propia = true, clase = "-", instructor = L"instructor de clase" }
      R.cargar = function(R)
        local base = RutaDeLaClase()
        if base and base.cargar then pcall(base.cargar, base) end
        for k, v in pairs(base or {}) do if R[k] == nil and k ~= "cargar" and k ~= "secciones" then R[k] = v end end
        R.talentos = R.talentos or {}
        R.profesiones = R.profesiones or { { nombre = L"Primeros auxilios", skill = 129, icono = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", intro = "", pasos = { { d = 1, h = 300, t = "" } } } }
        local pasos = {}
        for _, p in ipairs(r.pasos) do table.insert(pasos, { t = p.t, wp = p.wp }) end
        R.secciones = { { titulo = r.nombre, min = 1, max = 61, pasos = pasos } }
      end
      table.insert(GuiaAventurero_Rutas, R)
    end
  end
end

-- Registrar después de recuperar los datos antiguos y preparar el idioma.
GL.RegistrarRutasPropiasR13 = Registrar

local function Usar(r)
  local db = DB()
  if not (GL.RUTA and GL.RUTA.propia) then db.posNormal = { ruta = db.ruta, seccion = db.seccion, paso = db.paso } end
  db.rutaElegida = r.id
  Msg(L"ruta «" .. r.nombre .. L"» elegida. Escribe /reload para cargarla (con Ajustes › Datos › Editor y «Volver a la guía» vuelves a la tuya).")
end

local function VolverALaGuia()
  local db = DB()
  db.rutaElegida = nil
  local p = db.posNormal
  if type(p) == "table" and p.ruta then db.ruta, db.seccion, db.paso, db.destino = p.ruta, p.seccion, p.paso, 1 end
  db.posNormal = nil
  Msg(L"vuelves a la ruta de tu clase donde la dejaste. Escribe /reload para cargarla.")
end

------------------------------------------------------------------------
-- Ventana
------------------------------------------------------------------------
local ven, ui = nil, {}
local actual, sel, desde = nil, nil, 0   -- ruta que se edita, paso elegido, primera fila

local function Lista()
  local l = {}
  for id, r in pairs(Cuenta()) do r.id = id; table.insert(l, r) end
  table.sort(l, function(a, b) return tostring(a.nombre) < tostring(b.nombre) end)
  return l
end

local function Caja(padre, multilinea)
  local e = CreateFrame("EditBox", nil, padre, PLANTILLA)
  e:SetAutoFocus(false)
  e:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  e:SetTextInsets(6, 6, 2, 2)
  if multilinea then e:SetMultiLine(true) end
  GL.Caja(e, { 0, 0, 0, 0.5 }, GL.COLOR.botonBorde)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return e
end

local Pintar
local function Elegir(r)
  actual, sel, desde = r, (r and #r.pasos > 0) and 1 or nil, 0
  Pintar()
end

local function Boton(texto, fn, ancho, estilo)
  local b = GL.CrearBoton(ven, texto, fn, nil, 20, estilo)
  b:SetWidth(ancho or 90)
  return b
end

local function GuardarTexto()
  if actual and sel and actual.pasos[sel] and ui.texto then
    actual.pasos[sel].t = tostring(ui.texto:GetText() or ""):gsub("|", "/")
  end
  if actual and ui.nombre then
    local n = tostring(ui.nombre:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if n ~= "" then actual.nombre = n:sub(1, 40) end
  end
end

local function VentanaCodigo(modo)
  if not ui.codigo then
    local f = CreateFrame("Frame", "GuiaAventureroCodigoRuta", UIParent, PLANTILLA)
    f:SetSize(420, 130)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    f:SetFrameStrata("DIALOG")
    GL.Caja(f, { 0.04, 0.05, 0.07, 0.97 }, GL.COLOR.botonBorde)
    if GL.Acento then GL.Acento(f, 2) end
    f.titulo = GL.Texto(f, "GameFontNormalLarge")
    f.titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    f.caja = Caja(f)
    f.caja:SetHeight(24)
    f.caja:SetMaxLetters(0)
    f.caja:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    f.caja:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -40)
    f.caja:SetScript("OnTextChanged", function(self, usuario)
      if f.modo == "compartir" and usuario then self:SetText(f.fijo or ""); self:HighlightText() end
    end)
    f.aviso = GL.Texto(f, "GameFontHighlightSmall")
    f.aviso:SetPoint("TOPLEFT", f.caja, "BOTTOMLEFT", 0, -6)
    f.aviso:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.cerrar = GL.CrearBoton(f, L"Cerrar", function() f:Hide() end, nil, 22)
    f.cerrar:SetWidth(100)
    f.cerrar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    f.aceptar = GL.CrearBoton(f, L"Importar", function()
      local r, err = LeerCodigo(f.caja:GetText())
      if not r then f.aviso:SetText(L"|cffff7070No se puede importar: " .. err .. ".|r"); return end
      Guardar(r)
      f:Hide()
      Msg(L"ruta «" .. r.nombre .. L"» importada con " .. #r.pasos .. L" pasos.")
      Elegir(r)
    end, nil, 22, "accion")
    f.aceptar:SetWidth(100)
    f.aceptar:SetPoint("RIGHT", f.cerrar, "LEFT", -6, 0)
    if UISpecialFrames then GL.RegistrarCierreEscapeR13("GuiaAventureroCodigoRuta") end
    ui.codigo = f
  end
  local f = ui.codigo
  f.modo = modo
  if modo == "compartir" then
    f.fijo = Codigo(actual)
    f.titulo:SetText(C.AMARILLO .. L"Compartir «" .. actual.nombre .. "»" .. C.FIN)
    f.caja:SetText(f.fijo)
    f.aviso:SetText(C.GRIS .. L"Ctrl+C para copiarlo. Quien lo reciba: Ajustes › Datos › Editor › Importar y Ctrl+V. (" .. #f.fijo .. L" letras)" .. C.FIN)
    f.aceptar:Hide()
    f:Show(); f.caja:SetFocus(); f.caja:HighlightText()
  else
    f.titulo:SetText(C.AMARILLO .. L"Importar una ruta" .. C.FIN)
    f.caja:SetText("")
    f.aviso:SetText(C.GRIS .. L"Pega el código (empieza por " .. PREFIJO .. L") y pulsa Importar. Se guarda como una ruta tuya más." .. C.FIN)
    f.aceptar:Show()
    f:Show(); f.caja:SetFocus()
  end
end

local function Crear()
  ven = CreateFrame("Frame", "GuiaAventureroEditor", UIParent, PLANTILLA)
  ven:SetSize(470, 470)
  ven:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
  ven:SetFrameStrata("DIALOG")
  ven:SetMovable(true); ven:EnableMouse(true); ven:SetClampedToScreen(true)
  ven:RegisterForDrag("LeftButton")
  ven:SetScript("OnDragStart", function(self) self:StartMoving() end)
  ven:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  GL.Caja(ven, GL.COLOR.fondo, GL.COLOR.borde)
  if GL.Sombra then GL.Sombra(ven) end
  if GL.Acento then GL.Acento(ven, 2) end
  if UISpecialFrames then GL.RegistrarCierreEscapeR13("GuiaAventureroEditor") end
  ui.titulo = GL.Texto(ven, "GameFontNormalLarge")
  ui.titulo:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -12)
  ui.titulo:SetText(C.BLANCO .. L"Editor de rutas" .. C.FIN)
  local x = GL.CrearBoton(ven, "", function() GuardarTexto(); ven:Hide() end, nil, 20, "cerrar")
  x:SetWidth(20); x:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -8, -8)

  -- fila de la ruta
  ui.ruta = Boton(L"Ruta: ninguna", function()
    GuardarTexto()
    local l = Lista()
    if #l == 0 then return end
    local i = 1
    for k, r in ipairs(l) do if r == actual then i = k % #l + 1 end end
    Elegir(l[i])
  end, 200)
  ui.ruta:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -40)
  if GL.Ayuda then GL.Ayuda(ui.ruta, L"Tus rutas", L"Clic: la siguiente de tus rutas guardadas.") end
  ui.nueva = Boton(L"Nueva", function() GuardarTexto(); Elegir(Guardar({ nombre = L"Mi ruta", pasos = {} })) end, 70)
  ui.nueva:SetPoint("LEFT", ui.ruta, "RIGHT", 4, 0)
  ui.copiar = Boton(L"Copiar sección", function()
    GuardarTexto()
    local s = GL.PasoActual and GL.PasoActual()
    if not s then return end
    local r = { nombre = tostring(s.titulo):sub(1, 30), pasos = {} }
    for _, p in ipairs(s.pasos or {}) do
      local wp = {}
      for _, d in ipairs(p.wp or {}) do table.insert(wp, { m = d.m, x = d.x, y = d.y, z = d.z, n = d.n, q = d.q, a = d.a }) end
      table.insert(r.pasos, { t = (tostring(p.t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), wp = wp })
    end
    Elegir(Guardar(Limpia(r)))
    Msg(L"sección «" .. r.nombre .. L"» copiada al editor con " .. #r.pasos .. L" pasos.")
  end, 110)
  ui.copiar:SetPoint("LEFT", ui.nueva, "RIGHT", 4, 0)
  if GL.Ayuda then GL.Ayuda(ui.copiar, L"Copiar sección", L"Crea una ruta tuya con los pasos de la sección de la guía en la que estás, para cambiarlos.") end

  ui.etqNombre = GL.Texto(ven, "GameFontHighlightSmall")
  ui.etqNombre:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -70)
  ui.etqNombre:SetText(C.GRIS .. L"Nombre" .. C.FIN)
  ui.nombre = Caja(ven)
  ui.nombre:SetHeight(22)
  ui.nombre:SetPoint("TOPLEFT", ven, "TOPLEFT", 64, -66)
  ui.nombre:SetPoint("RIGHT", ven, "RIGHT", -110, 0)
  ui.nombre:SetMaxLetters(40)
  ui.nombre:SetScript("OnEnterPressed", function(self) self:ClearFocus(); GuardarTexto(); Pintar() end)
  ui.borrarRuta = Boton(L"Borrar ruta", function()
    if not actual then return end
    if not ui.confirmar then ui.confirmar = true; ui.borrarRuta.texto:SetText(L"¿Seguro?"); return end
    ui.confirmar = nil
    Cuenta()[actual.id] = nil
    Msg(L"ruta «" .. tostring(actual.nombre) .. L"» borrada.")
    local l = Lista()
    Elegir(l[1])
  end, 90)
  ui.borrarRuta:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -14, -66)

  -- lista de pasos
  ui.filas = {}
  for i = 1, FILAS do
    local f = CreateFrame("Button", nil, ven, PLANTILLA)
    f:SetHeight(20)
    f:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -96 - (i - 1) * 22)
    f:SetPoint("RIGHT", ven, "RIGHT", -14, 0)
    f.texto = GL.Texto(f, "GameFontHighlightSmall")
    f.texto:SetPoint("LEFT", f, "LEFT", 6, 0)
    f.texto:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    if f.texto.SetWordWrap then f.texto:SetWordWrap(false) end
    f:SetScript("OnClick", function(self) GuardarTexto(); sel = self.i; Pintar() end)
    ui.filas[i] = f
  end
  ven:EnableMouseWheel(true)
  ven:SetScript("OnMouseWheel", function(_, d)
    if not actual then return end
    desde = math.max(0, math.min(desde - d, #actual.pasos - FILAS))
    Pintar()
  end)

  -- botones de pasos
  local y = -96 - FILAS * 22 - 4
  ui.pasoAqui = Boton(L"Paso aquí", function()
    if not actual then actual = Guardar({ nombre = L"Mi ruta", pasos = {} }) end
    GuardarTexto()
    local d = DestinoAqui(L"Ir aquí")
    if not d then Msg(L"no se sabe dónde estás (dentro de una mazmorra no se puede).") return end
    local pos = (sel or #actual.pasos) + 1
    table.insert(actual.pasos, pos, { t = L"Paso nuevo en " .. tostring(d.z or "?") .. L": escribe aquí qué hacer.", wp = { d } })
    sel = pos
    desde = math.max(0, math.min(sel - 1, #actual.pasos - FILAS))
    Pintar()
  end, 86, "accion")
  ui.pasoAqui:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, y)
  if GL.Ayuda then GL.Ayuda(ui.pasoAqui, L"Paso aquí", L"Crea un paso detrás del elegido, con un destino donde estás.") end
  ui.subir = Boton(L"Subir", function()
    if not (actual and sel and sel > 1) then return end
    GuardarTexto()
    actual.pasos[sel], actual.pasos[sel - 1] = actual.pasos[sel - 1], actual.pasos[sel]
    sel = sel - 1; Pintar()
  end, 60)
  ui.subir:SetPoint("LEFT", ui.pasoAqui, "RIGHT", 4, 0)
  ui.bajar = Boton(L"Bajar", function()
    if not (actual and sel and sel < #actual.pasos) then return end
    GuardarTexto()
    actual.pasos[sel], actual.pasos[sel + 1] = actual.pasos[sel + 1], actual.pasos[sel]
    sel = sel + 1; Pintar()
  end, 60)
  ui.bajar:SetPoint("LEFT", ui.subir, "RIGHT", 4, 0)
  ui.borrar = Boton(L"Borrar paso", function()
    if not (actual and sel and actual.pasos[sel]) then return end
    table.remove(actual.pasos, sel)
    if sel > #actual.pasos then sel = #actual.pasos > 0 and #actual.pasos or nil end
    Pintar()
  end, 90)
  ui.borrar:SetPoint("LEFT", ui.bajar, "RIGHT", 4, 0)

  -- texto y destinos del paso elegido
  y = y - 26
  ui.texto = Caja(ven, true)
  ui.texto:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, y)
  ui.texto:SetPoint("RIGHT", ven, "RIGHT", -14, 0)
  ui.texto:SetHeight(46)
  ui.texto:SetMaxLetters(600)
  ui.texto:SetScript("OnEditFocusLost", function() GuardarTexto() end)
  y = y - 52
  ui.destinos = GL.Texto(ven, "GameFontHighlightSmall")
  ui.destinos:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, y)
  ui.destinos:SetPoint("RIGHT", ven, "RIGHT", -14, 0)
  if ui.destinos.SetJustifyH then ui.destinos:SetJustifyH("LEFT") end
  y = y - 30
  ui.etqMision = GL.Texto(ven, "GameFontHighlightSmall")
  ui.etqMision:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, y - 4)
  ui.etqMision:SetText(C.GRIS .. L"Misión (id)" .. C.FIN)
  ui.mision = Caja(ven)
  ui.mision:SetSize(70, 22)
  ui.mision:SetNumeric(true)
  ui.mision:SetPoint("TOPLEFT", ven, "TOPLEFT", 86, y)
  ui.accion = Boton(L"Recoger", function()
    local orden = { "A", "C", "T" }
    local i = 1
    for k, a in ipairs(orden) do if a == ui.accionValor then i = k % 3 + 1 end end
    ui.accionValor = orden[i]
    Pintar()
  end, 76)
  ui.accionValor = "A"
  ui.accion:SetPoint("LEFT", ui.mision, "RIGHT", 4, 0)
  ui.destinoAqui = Boton(L"Destino aquí", function()
    if not (actual and sel and actual.pasos[sel]) then return end
    local p = actual.pasos[sel]
    if #p.wp >= MAX_DESTINOS then Msg(L"como mucho " .. MAX_DESTINOS .. L" destinos por paso.") return end
    local q = tonumber(ui.mision:GetText() or "")
    local nombre = q and ((ui.accionValor == "A" and L"Recoger" or ui.accionValor == "C" and L"Objetivo" or L"Entregar") .. L": misión " .. q) or (L"Destino " .. (#p.wp + 1))
    local d = DestinoAqui(nombre)
    if not d then Msg(L"no se sabe dónde estás.") return end
    if q then d.q, d.a = q, ui.accionValor end
    table.insert(p.wp, d)
    ui.mision:SetText("")
    Pintar()
  end, 100, "accion")
  ui.destinoAqui:SetPoint("LEFT", ui.accion, "RIGHT", 4, 0)
  ui.quitar = Boton(L"Quitar último", function()
    if actual and sel and actual.pasos[sel] and #actual.pasos[sel].wp > 0 then table.remove(actual.pasos[sel].wp); Pintar() end
  end, 96)
  ui.quitar:SetPoint("LEFT", ui.destinoAqui, "RIGHT", 4, 0)

  -- abajo
  ui.compartir = Boton(L"Compartir", function() GuardarTexto(); if actual and #actual.pasos > 0 then VentanaCodigo("compartir") end end, 84)
  ui.compartir:SetPoint("BOTTOMLEFT", ven, "BOTTOMLEFT", 14, 12)
  ui.importar = Boton(L"Importar", function() VentanaCodigo("importar") end, 80)
  ui.importar:SetPoint("LEFT", ui.compartir, "RIGHT", 4, 0)
  ui.usar = Boton(L"Usar esta ruta", function()
    GuardarTexto()
    if GL.RUTA and actual and GL.RUTA.id == actual.id then VolverALaGuia() elseif actual and #actual.pasos > 0 then Usar(actual) end
    Pintar()
  end, 130, "accion")
  ui.usar:SetPoint("BOTTOMRIGHT", ven, "BOTTOMRIGHT", -14, 12)
  ui.ayuda = GL.Texto(ven, "GameFontDisableSmall")
  ui.ayuda:SetPoint("BOTTOMLEFT", ven, "BOTTOMLEFT", 14, 38)
  ui.ayuda:SetPoint("RIGHT", ven, "RIGHT", -14, 0)
  if ui.ayuda.SetJustifyH then ui.ayuda:SetJustifyH("LEFT") end
end

Pintar = function()
  if not ven then return end
  ui.confirmar = nil
  ui.borrarRuta.texto:SetText(L"Borrar ruta")
  ui.ruta.texto:SetText(actual and (L"Ruta: " .. actual.nombre) or L"Ruta: ninguna")
  ui.nombre:SetText(actual and actual.nombre or "")
  local pasos = actual and actual.pasos or {}
  desde = math.max(0, math.min(desde, #pasos - FILAS))
  if sel and (sel <= desde or sel > desde + FILAS) then desde = math.max(0, math.min(sel - 1, #pasos - FILAS)) end
  local a = GL.COLOR.acento
  for i = 1, FILAS do
    local f, k = ui.filas[i], desde + i
    local p = pasos[k]
    f.i = k
    if p then
      local zona = p.wp[1] and p.wp[1].z or L"sin destino"
      local corto = tostring(p.t):gsub("\n", " ")
      if #corto > 60 then corto = corto:sub(1, 60) .. "…" end
      f.texto:SetText((k == sel and C.AMARILLO or C.BLANCO) .. k .. ". " .. C.FIN .. corto .. C.GRIS .. "  · " .. zona .. " · " .. #p.wp .. C.FIN)
      GL.Caja(f, k == sel and { a[1], a[2], a[3], 0.15 } or { 1, 1, 1, 0.03 }, k == sel and { a[1], a[2], a[3], 0.6 } or { 1, 1, 1, 0.06 })
      f:Show()
    elseif i == 1 then
      f.texto:SetText(C.GRIS .. (actual and L"Sin pasos: ve a un sitio y pulsa «Paso aquí»." or L"Pulsa Nueva o «Copiar sección» para empezar, o Importar si te han pasado un código.") .. C.FIN)
      GL.Caja(f, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
      f:Show()
    else
      f:Hide()
    end
  end
  local p = actual and sel and actual.pasos[sel]
  ui.texto:SetText(p and p.t or "")
  if p then
    local l = {}
    for j, d in ipairs(p.wp) do
      table.insert(l, j .. ". " .. tostring(d.n) .. C.GRIS .. string.format(" (%s %.1f, %.1f)", tostring(d.z or d.m), d.x, d.y) .. C.FIN)
    end
    ui.destinos:SetText(#l > 0 and table.concat(l, "   ", 1, math.min(#l, 3)) .. (#l > 3 and (C.GRIS .. "  y " .. (#l - 3) .. L" más" .. C.FIN) or "") or (C.GRIS .. L"Sin destinos: el paso se pasa con Siguiente." .. C.FIN))
  else
    ui.destinos:SetText("")
  end
  ui.accion.texto:SetText(({ A = L"Recoger", C = L"Objetivo", T = L"Entregar" })[ui.accionValor])
  local usando = GL.RUTA and actual and GL.RUTA.id == actual.id
  ui.usar.texto:SetText(usando and L"Volver a la guía" or L"Usar esta ruta")
  ui.ayuda:SetText((usando and (C.VERDE .. L"Estás usando esta ruta. " .. C.FIN) or "") ..
    L"Con misión y acción, el destino se marca solo al recoger, completar o entregar. Los cambios se guardan al momento; «Usar esta ruta» pide /reload.")
end

local function Abrir()
  if not ven then Crear() end
  if not actual then
    local l = Lista()
    if GL.RUTA and GL.RUTA.propia then for _, r in ipairs(l) do if r.id == GL.RUTA.id then actual = r end end end
    actual = actual or l[1]
    sel = actual and #actual.pasos > 0 and 1 or nil
  end
  Pintar()
  ven:Show()
end
GL.AbrirEditor = Abrir

GL.comandos = GL.comandos or {}
GL.comandos["editor"] = function(orden)
  if orden == "volver" then VolverALaGuia() return end
  Abrir()
end

-- Fila en Ajustes › Datos
GL.CrearFilaEditor = function(padre)
  local cont = CreateFrame("Frame", nil, padre)
  cont:SetHeight(46)
  cont.altoFila = 50
  cont.texto = GL.Texto(cont, "GameFontHighlightSmall")
  cont.texto:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, 0)
  cont.texto:SetText(L"Rutas propias: hacer, cambiar y compartir")
  cont.abrir = GL.CrearBoton(cont, L"Editor de rutas", function() Abrir() end, nil, 22, "accion")
  cont.abrir:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, -16)
  cont.abrir:SetPoint("RIGHT", cont, "RIGHT", 0, 0)
  cont.Actualizar = function() end
  return cont
end

GL._editor = { Limpia = Limpia, Codigo = Codigo, Leer = LeerCodigo, Guardar = Guardar, Registrar = Registrar, Abrir = Abrir,
  Elegir = function(r) Elegir(r) end, Usar = Usar, Volver = VolverALaGuia, Lista = Lista, Ui = function() return ui end }

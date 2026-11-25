-- Traspaso.lua (7.5.13): copiar el progreso de un ordenador a otro con un código de texto.
-- Exportar: ruta, sección, paso, notas, pospuestos, ignorados, puntos de vuelo y ajustes. Importar: pide confirmar.
-- El código no se ejecuta: se lee con un lector propio que solo entiende números, textos, sí/no y tablas.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local PREFIJO = "GL1:"
local CLAVES = { "ruta", "seccion", "paso", "destino", "profesion", "notas", "pospuestos", "ignorados", "vuelos" }

------------------------------------------------------------------------
-- Codificar y leer
------------------------------------------------------------------------
local function Codificar(v, out)
  local t = type(v)
  if t == "number" then table.insert(out, "n" .. tostring(v) .. ";")
  elseif t == "string" then table.insert(out, "s" .. #v .. ":" .. v)
  elseif t == "boolean" then table.insert(out, v and "b1" or "b0")
  elseif t == "table" then
    table.insert(out, "t")
    for k, x in pairs(v) do
      local tk, tx = type(k), type(x)
      if (tk == "string" or tk == "number") and (tx == "string" or tx == "number" or tx == "boolean" or tx == "table") then
        Codificar(k, out); Codificar(x, out)
      end
    end
    table.insert(out, "e")
  end
end

local function Leer(s, i, prof)
  if prof > 8 then return nil, nil end
  local c = s:sub(i, i)
  if c == "n" then
    local fin = s:find(";", i, true)
    if not fin then return nil, nil end
    local n = tonumber(s:sub(i + 1, fin - 1))
    if not n then return nil, nil end
    return n, fin + 1
  elseif c == "s" then
    local dos = s:find(":", i, true)
    local largo = dos and tonumber(s:sub(i + 1, dos - 1))
    if not largo or largo < 0 then return nil, nil end
    return s:sub(dos + 1, dos + largo), dos + largo + 1
  elseif c == "b" then
    return s:sub(i + 1, i + 1) == "1", i + 2
  elseif c == "t" then
    local t, j = {}, i + 1
    while s:sub(j, j) ~= "e" do
      if j > #s then return nil, nil end
      local k, j2 = Leer(s, j, prof + 1)
      if k == nil then return nil, nil end
      local v, j3 = Leer(s, j2, prof + 1)
      if v == nil then return nil, nil end
      t[k] = v
      j = j3
    end
    return t, j + 1
  end
  return nil, nil
end

local function Exportar()
  local db = GuiaAventureroDB
  if type(db) ~= "table" then return "" end
  local datos = { v = 1, ajustes = {} }
  for _, k in ipairs(CLAVES) do datos[k] = db[k] end
  for _, k in ipairs(GL.AJUSTES_COPIABLES or {}) do datos.ajustes[k] = db[k] end
  local out = {}
  Codificar(datos, out)
  return PREFIJO .. table.concat(out)
end

local function LeerCodigo(texto)
  texto = (texto or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if texto:sub(1, #PREFIJO) ~= PREFIJO then return nil, L"el código no empieza por " .. PREFIJO end
  local ok, datos = pcall(Leer, texto, #PREFIJO + 1, 0)
  if not ok or type(datos) ~= "table" then return nil, L"el código está incompleto o cambiado" end
  if type(datos.seccion) ~= "number" or type(datos.paso) ~= "number" then return nil, L"al código le falta el paso" end
  return datos
end

local function Importar(datos)
  local db = GuiaAventureroDB
  local cambiaRuta = datos.ruta and GL.RUTA and datos.ruta ~= GL.RUTA.id
  for _, k in ipairs(CLAVES) do if datos[k] ~= nil then db[k] = datos[k] end end
  for k, v in pairs(datos.ajustes or {}) do db[k] = v end
  if cambiaRuta then
    db.rutaElegida = datos.ruta
    if GL.Mensaje then GL.Mensaje(L"progreso importado de otra ruta. Escribe /reload para cargarla.") end
    return
  end
  local secs = GL.RUTA and GL.RUTA.secciones
  if secs then
    if not secs[db.seccion] then db.seccion = 1 end
    if not secs[db.seccion].pasos[db.paso] then db.paso = 1 end
  end
  db.destino = db.destino or 1
  if GL.CambiarTema then GL.CambiarTema(db.tema or "dorado") end
  if GL.AplicarAjustes then GL.AplicarAjustes() end
  if GL.Refrescar then GL.Refrescar() end
  if GL.Mensaje then GL.Mensaje(L"progreso importado: sección " .. db.seccion .. L", paso " .. db.paso .. ".") end
end

------------------------------------------------------------------------
-- Ventana
------------------------------------------------------------------------
local ven = nil
local function Ventana(modo)
  if not ven then
    ven = CreateFrame("Frame", "GuiaAventureroTraspaso", UIParent, PLANTILLA)
    ven:SetWidth(420); ven:SetHeight(150)
    ven:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    ven:SetFrameStrata("DIALOG")
    -- 9.7.6: se mueve arrastrando y se cierra con Esc, como las demás ventanas
    ven:EnableMouse(true); ven:SetMovable(true)
    if ven.SetClampedToScreen then ven:SetClampedToScreen(true) end
    ven:RegisterForDrag("LeftButton")
    ven:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ven:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "GuiaAventureroTraspaso") end
    if GL.Caja and GL.COLOR then GL.Caja(ven, { 0.04, 0.05, 0.07, 0.97 }, GL.COLOR.botonBorde) end
    if GL.Acento then GL.Acento(ven, 2) end
    ven.titulo = GL.Texto(ven, "GameFontNormalLarge")
    ven.titulo:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -12)
    local caja = CreateFrame("EditBox", nil, ven, PLANTILLA)
    caja:SetHeight(24)
    caja:SetPoint("TOPLEFT", ven, "TOPLEFT", 14, -40)
    caja:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -14, -40)
    caja:SetAutoFocus(false)
    caja:SetMaxLetters(0)
    caja:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    caja:SetTextInsets(6, 6, 0, 0)
    if GL.Caja and GL.COLOR then GL.Caja(caja, { 0, 0, 0, 0.5 }, GL.COLOR.botonBorde) end
    caja:SetScript("OnEscapePressed", function() ven:Hide() end)
    caja:SetScript("OnTextChanged", function(self, usuario)
      if ven.modo == "exportar" and usuario then self:SetText(ven.codigo or ""); self:HighlightText() end
      ven.aviso:SetText("")
      ven.pendiente = nil
      if ven.modo == "importar" then ven.aceptar.texto:SetText(L"Aceptar") end
    end)
    ven.caja = caja
    ven.ayuda = GL.Texto(ven, "GameFontHighlightSmall")
    ven.ayuda:SetPoint("TOPLEFT", caja, "BOTTOMLEFT", 0, -6)
    ven.ayuda:SetPoint("RIGHT", ven, "RIGHT", -14, 0)
    ven.aviso = GL.Texto(ven, "GameFontHighlightSmall")
    ven.aviso:SetPoint("TOPLEFT", ven.ayuda, "BOTTOMLEFT", 0, -4)
    ven.aviso:SetPoint("RIGHT", ven, "RIGHT", -14, 0)
    ven.cerrar = GL.CrearBoton(ven, L"Cerrar", function() ven:Hide() end, nil, 22)
    ven.cerrar:SetWidth(110)
    ven.cerrar:SetPoint("BOTTOMRIGHT", ven, "BOTTOMRIGHT", -14, 12)
    ven.aceptar = GL.CrearBoton(ven, L"Aceptar", function()
      local datos, err = LeerCodigo(ven.caja:GetText())
      if not datos then ven.aviso:SetText(L"|cffff7070No se puede importar: " .. err .. ".|r"); return end
      if not ven.pendiente then   -- primer clic: avisa de lo que va a cambiar
        ven.pendiente = true
        ven.aviso:SetText(C.AMARILLO .. L"Se cambiará tu progreso a la sección " .. datos.seccion .. L", paso " .. datos.paso ..
          (datos.ruta and (L" de la ruta " .. tostring(datos.ruta)) or "") .. L". Pulsa Confirmar." .. C.FIN)
        ven.aceptar.texto:SetText(L"Confirmar")
        return
      end
      Importar(datos)
      ven:Hide()
    end, nil, 22, "accion")
    ven.aceptar:SetWidth(110)
    ven.aceptar:SetPoint("RIGHT", ven.cerrar, "LEFT", -6, 0)
    ven:Hide()
  end
  ven.modo = modo
  ven.pendiente = nil
  ven.aviso:SetText("")
  if modo == "exportar" then
    ven.codigo = Exportar()
    ven.titulo:SetText(C.AMARILLO .. L"Exportar progreso" .. C.FIN)
    ven.caja:SetText(ven.codigo)
    ven.ayuda:SetText(C.GRIS .. L"Pulsa Ctrl+C para copiarlo. En el otro ordenador: Opciones > Ajustes > Importar, Ctrl+V y Aceptar." .. C.FIN)
    ven.aceptar:Hide()
    ven:Show()
    ven.caja:SetFocus()
    ven.caja:HighlightText()
  else
    ven.titulo:SetText(C.AMARILLO .. L"Importar progreso" .. C.FIN)
    ven.caja:SetText("")
    ven.ayuda:SetText(C.GRIS .. L"Pega aquí el código (Ctrl+V) y pulsa Aceptar. Lleva el paso, la ruta, las notas, lo pospuesto e ignorado, los vuelos y los ajustes." .. C.FIN)
    ven.aceptar.texto:SetText(L"Aceptar")
    ven.aceptar:Show()
    ven:Show()
    ven.caja:SetFocus()
  end
end
GL.TraspasoVentana = Ventana

-- Fila de Opciones > Ajustes con los botones Exportar e Importar
GL.CrearTraspaso = function(padre)
  local cont = CreateFrame("Frame", nil, padre)
  cont:SetHeight(46)
  cont.altoFila = 50
  cont.texto = GL.Texto(cont, "GameFontHighlightSmall")
  cont.texto:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, 0)
  cont.texto:SetText(L"Copiar el progreso a otro ordenador")
  cont.exportar = GL.CrearBoton(cont, L"Exportar", function() Ventana("exportar") end, nil, 22, "accion")
  cont.exportar:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, -16)
  cont.exportar:SetPoint("RIGHT", cont, "CENTER", -2, 0)
  cont.importar = GL.CrearBoton(cont, L"Importar", function() Ventana("importar") end, nil, 22)
  cont.importar:SetPoint("TOPRIGHT", cont, "TOPRIGHT", 0, -16)
  cont.importar:SetPoint("LEFT", cont, "CENTER", 2, 0)
  cont.Actualizar = function() end
  return cont
end

-- Para las pruebas
GL._traspaso = { Exportar = Exportar, Leer = LeerCodigo, Importar = Importar }
GL.CodificarDatos = function(v) local out = {}; Codificar(v, out); return table.concat(out) end   -- 9.1: Editor de rutas
GL.LeerDatos = function(s, i) local ok, v = pcall(Leer, s, i or 1, 0); if ok then return v end end

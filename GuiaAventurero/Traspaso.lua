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
local MAX_BYTES, MAX_NODOS, MAX_PROF = 1048576, 100000, 8
local function Finito(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
local function Entero(v) return Finito(v) and v >= 1 and v <= 2147483647 and v % 1 == 0 end
local function ClaveValida(k) return type(k) == "string" or Finito(k) end
local function Codificar(v, out, estado, prof)
  estado.n = estado.n + 1
  if prof > MAX_PROF or estado.n > MAX_NODOS then error("limite") end
  local t, trozo = type(v), nil
  if Finito(v) then trozo = "n" .. tostring(v) .. ";"
  elseif t == "string" then trozo = "s" .. #v .. ":" .. v
  elseif t == "boolean" then trozo = v and "b1" or "b0"
  elseif t == "table" then
    if estado.vistos[v] then error("ciclo") end
    estado.vistos[v] = true
    estado.bytes = estado.bytes + 2
    if estado.bytes > MAX_BYTES then error("limite") end
    out[#out+1] = "t"
    for k, x in pairs(v) do
      if not ClaveValida(k) then error("clave") end
      Codificar(k, out, estado, prof+1); Codificar(x, out, estado, prof+1)
    end
    out[#out+1] = "e"; estado.vistos[v] = nil; return
  else error("tipo") end
  estado.bytes = estado.bytes + #trozo
  if estado.bytes > MAX_BYTES then error("limite") end
  out[#out+1] = trozo
end
local function CodificarSeguro(v)
  local out = {}
  if not pcall(Codificar, v, out, {n=0,bytes=0,vistos={}}, 0) then return nil end
  return table.concat(out)
end
local function Leer(s, i, prof, estado)
  estado.n = estado.n + 1
  if prof > MAX_PROF or estado.n > MAX_NODOS or i > #s then return nil end
  local c = s:sub(i, i)
  if c == "n" then
    local fin = s:find(";", i, true)
    if not fin or fin-i > 64 then return nil end
    local n = tonumber(s:sub(i + 1, fin - 1))
    if not Finito(n) then return nil end
    return n, fin + 1
  elseif c == "s" then
    local dos = s:find(":", i, true)
    if not dos or dos-i > 9 then return nil end
    local digits = s:sub(i+1,dos-1)
    if not digits:match("^%d+$") then return nil end
    local largo = tonumber(digits)
    if largo > #s-dos then return nil end
    return s:sub(dos + 1, dos + largo), dos + largo + 1
  elseif c == "b" then
    local bit = s:sub(i+1,i+1)
    if bit ~= "0" and bit ~= "1" then return nil end
    return bit == "1", i+2
  elseif c == "t" then
    local t, j = {}, i+1
    while s:sub(j,j) ~= "e" do
      local k,j2 = Leer(s,j,prof+1,estado)
      if not ClaveValida(k) or t[k] ~= nil then return nil end
      local v,j3 = Leer(s,j2,prof+1,estado)
      if v == nil then return nil end
      t[k],j = v,j3
    end
    return t,j+1
  end
end
local function LeerCompleto(s,i)
  if type(s) ~= "string" or not Entero(i) or i > 16 or #s-i+1 > MAX_BYTES then return nil end
  local ok,v,fin = pcall(Leer,s,i,0,{n=0})
  if ok and fin == #s+1 then return v end
end
local function Exportar()
  local db = GuiaAventureroDB
  if type(db) ~= "table" then return "" end
  local datos = { v = 1, ajustes = {} }
  for _, k in ipairs(CLAVES) do datos[k] = db[k] end
  for _, k in ipairs(GL.AJUSTES_COPIABLES or {}) do datos.ajustes[k] = db[k] end
  local cuerpo = CodificarSeguro(datos)
  return cuerpo and PREFIJO .. cuerpo or ""
end
local LIMITES = {escala={0.6,1.5},opacidad={0.2,1},escalaFlecha={0.6,2},tamTexto={0.8,1.5},alphaVentana={0.3,1}}
local TEXTOS = {tema=true,estiloFlecha=true,marco=true,fuentePaso=true}
-- No activar acciones automáticas por un código recibido de terceros.
local ACCIONES = {rangosAuto=true,rangosBarras=true,modoPesca=true,autoSeguimiento=true}
local function AjusteValido(k,v)
  local lim = LIMITES[k]
  if lim then return Finito(v) and v >= lim[1] and v <= lim[2] end
  if TEXTOS[k] then return type(v)=="string" and #v>0 and #v<=128 end
  return type(v)=="boolean"
end
local function RutaConocida(id)
  if GL.RUTA and GL.RUTA.id == id then return GL.RUTA end
  for _,r in ipairs(GuiaAventurero_Rutas or {}) do if r.id==id then return r end end
end
local function Validar(datos)
  if type(datos) ~= "table" or datos.v ~= 1 then return nil,L"versión de código no compatible" end
  if not Entero(datos.seccion) or not Entero(datos.paso) then return nil,L"al código le falta el paso" end
  if datos.ruta ~= nil and (type(datos.ruta)~="string" or not RutaConocida(datos.ruta)) then return nil,L"la ruta del código no está instalada" end
  for _,k in ipairs({"destino","profesion"}) do if datos[k]~=nil and not Entero(datos[k]) then return nil,L"datos de progreso o ajustes no válidos" end end
  for _,k in ipairs({"notas","pospuestos","ignorados","vuelos"}) do
    local t = datos[k]
    if t ~= nil then
      if type(t) ~= "table" then return nil,L"datos de progreso o ajustes no válidos" end
      for clave,v in pairs(t) do
        if type(clave)~="string" or (k=="notas" and type(v)~="string") or (k~="notas" and v~=true) then return nil,L"datos de progreso o ajustes no válidos" end
      end
    end
  end
  local ruta = datos.ruta and RutaConocida(datos.ruta) or GL.RUTA
  if ruta and type(ruta.secciones)=="table" then
    local sec = ruta.secciones[datos.seccion]
    local paso = sec and sec.pasos and sec.pasos[datos.paso]
    if not paso or (datos.destino and datos.destino > math.max(1,#(paso.wp or {}))) then return nil,L"el paso o destino no existe en la ruta" end
  end
  if datos.ajustes~=nil and type(datos.ajustes)~="table" then return nil,L"datos de progreso o ajustes no válidos" end
  for _,k in ipairs(GL.AJUSTES_COPIABLES or {}) do
    local v = datos.ajustes and datos.ajustes[k]
    if v~=nil and not AjusteValido(k,v) then return nil,L"datos de progreso o ajustes no válidos" end
  end
  return true
end
local function LeerCodigo(texto)
  if type(texto) ~= "string" or #texto > MAX_BYTES+#PREFIJO then return nil,L"el código está incompleto o cambiado" end
  texto = texto:gsub("^%s+", ""):gsub("%s+$", "")
  if texto:sub(1, #PREFIJO) ~= PREFIJO then return nil, L"el código no empieza por " .. PREFIJO end
  local datos = LeerCompleto(texto,#PREFIJO+1)
  if type(datos) ~= "table" then return nil,L"el código está incompleto o cambiado" end
  local ok,err = Validar(datos); if not ok then return nil,err end
  return datos
end
local function CopiaSuperficial(t)
  local r = {}; for k,v in pairs(t) do r[k]=v end; return r
end
local function Importar(datos)
  local valido,err = Validar(datos); if not valido then return false,err end
  local db = GuiaAventureroDB
  if type(db)~="table" then return false,L"datos de progreso o ajustes no válidos" end
  local anterior = Exportar()
  if anterior=="" then return false,L"no se pudo conservar el progreso anterior" end
  local cambios = CopiaSuperficial(db)
  local cambiaRuta = datos.ruta and GL.RUTA and datos.ruta ~= GL.RUTA.id
  if cambiaRuta then
    if type(GL.PrepararProgresoImportadoR09)~="function" then return false,L"no se pudo conservar el progreso anterior" end
    for _,k in ipairs({"progresoR09","reparacionesR09"}) do if type(db[k])=="table" then cambios[k]=CopiaSuperficial(db[k]) end end
    local ok,hecho=pcall(GL.PrepararProgresoImportadoR09,cambios,datos)
    if not ok or not hecho then return false,L"no se pudo conservar el progreso anterior" end
    if datos.vuelos~=nil then cambios.vuelos=datos.vuelos end
  else
    for _,k in ipairs(CLAVES) do if datos[k]~=nil then cambios[k]=datos[k] end end
    cambios.bloqueoPasoR09=nil
    cambios.destino=datos.destino or 1
    if datos.profesion then cambios.profesionSkill=nil end
  end
  for _,k in ipairs(GL.AJUSTES_COPIABLES or {}) do
    local v = datos.ajustes and datos.ajustes[k]
    if v~=nil and not ACCIONES[k] then cambios[k]=v end
  end
  -- Guardar el código previo del personaje sin tocar las copias de Respaldo.lua.
  cambios.traspasoAnteriorR09=anterior
  local previo=CopiaSuperficial(db)
  for k in pairs(db) do if cambios[k]==nil then db[k]=nil end end
  for k,v in pairs(cambios) do db[k]=v end
  if not cambiaRuta then
    local ok=pcall(function()
      if GL.BloqueoPasoR09 then GL.BloqueoPasoR09(false) end
      if GL.CambiarTema and db.tema then GL.CambiarTema(db.tema) end
      if GL.AplicarAjustes then GL.AplicarAjustes() end
      if GL.Refrescar then GL.Refrescar() end
    end)
    if not ok then
      for k in pairs(db) do db[k]=nil end; for k,v in pairs(previo) do db[k]=v end
      if GL.BloqueoPasoR09 then pcall(GL.BloqueoPasoR09,previo.bloqueoPasoR09 or false) end
      return false,L"no se pudo aplicar la importación; recarga la interfaz"
    end
  end
  if GL.Mensaje then
    if cambiaRuta then GL.Mensaje(L"progreso importado de otra ruta. Escribe /reload para cargarla.")
    else GL.Mensaje(L"progreso importado: sección " .. db.seccion .. L", paso " .. db.paso .. ".") end
  end
  return true
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
    if UISpecialFrames then GL.RegistrarCierreEscapeR13("GuiaAventureroTraspaso") end
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
      local ok,fallo = Importar(datos)
      if not ok then
        ven.pendiente=nil; ven.aceptar.texto:SetText(L"Aceptar")
        ven.aviso:SetText(L"|cffff7070No se puede importar: " .. fallo .. ".|r"); return
      end
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
    if ven.codigo == "" then ven.aviso:SetText(L"No se pudo exportar: datos dañados o demasiado grandes.") end
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
GL.CodificarDatos = function(v) return CodificarSeguro(v) or "" end   -- 9.1: Editor de rutas
GL.LeerDatos = function(s, i) return LeerCompleto(s, i or 1) end

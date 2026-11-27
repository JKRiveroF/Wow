-- Mazmorras9.lua (9.0): modo mazmorra automático. Al entrar en una mazmorra que conoce la guía, la ventana
-- deja sitio a un panel compacto con los jefes en orden (los muertos tachados y el siguiente marcado), cuántos
-- objetos útiles tiene cada uno y las misiones de esa mazmorra. Clic en un jefe: su botín con «Todo el botín» y
-- «Útil para ti», como en la pestaña Mazmorras. Al salir de la mazmorra vuelve sola la guía. Se puede apagar.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local function DB() return GuiaAventureroDB or {} end
local function Si(k) return DB()[k] ~= false end
local function Minus(s)
  if issecretvalue and issecretvalue(s) then return "" end
  return (type(s) == "string") and s:lower() or ""
end
local function Ahora() return (time and time()) or 0 end
local function Consulta(f, ...)
  if type(f) ~= "function" then return nil end
  local ok, a, b, c, d, e, g, h, i = pcall(f, ...)
  if not ok then return nil end
  local function Seguro(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
  end
  return Seguro(a), Seguro(b), Seguro(c), Seguro(d), Seguro(e), Seguro(g), Seguro(h), Seguro(i)
end

-- cuántos objetos de un jefe te sirven (los puedes llevar según tu ruta); el juego tiene que conocer el objeto
function GL.UtilesDeJefe(j)
  if not (j and j.botin and GL.BotinUtil) then return 0, 0 end
  local n, mejor, vistos, mejoras = 0, 0, {}, {}
  for _, o in ipairs(GL.NormalizarBotin977 and GL.NormalizarBotin977(j.botin) or j.botin) do
    if o.id then
      local ok, util, mej, _, _, aviso = pcall(GL.BotinUtil, o.id)
      if ok and util then
        if not vistos[o.id] then n = n + 1; vistos[o.id] = true end
        if mej and not aviso and not o.mision977 and not mejoras[o.id] then mejor = mejor + 1; mejoras[o.id] = true end
      end
    end
  end
  return n, mejor
end

local function NombreJefe(j) return ((j.n or "?"):gsub("^[^:]+: ", "")) end

local function NombreVisibleR11(j)
  local nombre = GL.NombreJefeGuiaR11 and GL.NombreJefeGuiaR11(j) or j.n or "?"
  return (nombre:gsub("^[^:]+: ", ""))
end

local function BuscarMazmorra(nombre)
  if not GL.DatosMazmorras or Minus(nombre) == "" then return nil, false end
  local ok, datos = pcall(GL.DatosMazmorras)
  if not ok or type(datos) ~= "table" or #datos == 0 then return nil, false end
  local b, encontrada = Minus(nombre), nil
  for _, m in ipairs(datos) do
    local es = m.clave or m.n
    local en = GL.EnIngles and GL.EnIngles(es) or es
    if Minus(es) == b or Minus(en) == b or Minus(m.n) == b or Minus(m.ing) == b then
      if encontrada and (encontrada.clave or encontrada.n) ~= es then return nil, true end
      encontrada = m
    end
  end
  return encontrada, true
end

-- Una banda del catálogo con la forma de una mazmorra para el panel existente.
local function BuscarBanda(nombre)
  if Minus(nombre) == "" or not (GL.D94 and type(GL.D94.bandas) == "table" and #GL.D94.bandas > 0) then return nil, false end
  local b, encontrada = Minus(nombre), nil
  for _, r in ipairs(GL.D94.bandas) do
    local es = r.clave or r.n
    if Minus(es) == b or Minus(r.ing) == b or Minus(r.n) == b then
      if encontrada and encontrada.clave ~= es then return nil, true end
      encontrada = { n = r.n, clave = es, banda = true, jugadores = r.jugadores, min = r.nivel, max = r.nivel, misiones = {},
        mapaNombre = (GL.clienteIngles and r.ing) or es }
    end
  end
  return encontrada, true
end
GL._buscarMazmorra = BuscarMazmorra
GL._buscarBanda = BuscarBanda   -- para las pruebas

local actual   -- la mazmorra en la que estás (tabla de Mazmorras.lua)
local ven, contexto
local function Muertos()
  local db = DB()
  local p = db.mazMuertos
  if type(p) ~= "table" or type(p.jefes) ~= "table" or p.activa ~= true then return {} end
  return p.jefes
end

-- 9.7.6: el jefe bajo el ratón en el mapa (resaltado) o elegido con clic, marcado en la lista
local resaltado, elegido = nil, nil
local function Clave(j) return GL.ClaveJefe and j and GL.ClaveJefe(j.n) or nil end
local function IdentidadJefe(j)
  return type(j) == "table" and (j.nombreOriginal977 or j.ing or j.n) or nil
end
local function MarcarFilas()
  if not ven then return end
  local a = GL.COLOR.acento
  for _, f in ipairs(ven.filas) do
    local k = Clave(f.jefe)
    if f:IsShown() and k and (k == resaltado or k == elegido) then f.marca:SetColorTexture(1, 0.82, 0, k == resaltado and 0.26 or 0.18)
    else f.marca:SetColorTexture(a[1], a[2], a[3], f.esSig and 0.14 or 0) end
  end
end
function GL.ResaltarJefePanel(k) resaltado = k; MarcarFilas() end
function GL.ElegirJefePanel(k) elegido = k; MarcarFilas() end

local function Fila(i)
  local f = ven.filas[i]
  if f then return f end
  f = CreateFrame("Button", nil, ven)
  f:SetHeight(18)
  f.marca = f:CreateTexture(nil, "BACKGROUND")
  f.marca:SetAllPoints()
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.06)
  f.der = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
  f.der:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  f.texto = GL.Texto(f, "GameFontHighlightSmall")
  f.texto:SetPoint("LEFT", f, "LEFT", 6, 0)
  f.texto:SetPoint("RIGHT", f.der, "LEFT", -4, 0)
  if f.texto.SetWordWrap then f.texto:SetWordWrap(false) end
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:SetScript("OnClick", function(self, boton)
    if not actual or not self.jefe or not self:IsShown() or not ven:IsShown() then return end
    if boton == "RightButton" then   -- clic derecho: marcar o desmarcar como muerto a mano
      local m = Muertos()
      local k = IdentidadJefe(self.jefe)
      if k then m[k] = m[k] ~= true or nil end
      GL.RefrescarModoMazmorra()
      return
    end
    -- 9.7.6: queda elegido en la lista y en el mapa
    elegido = Clave(self.jefe); MarcarFilas()
    local MM = GL.MapaModoMazmorra
    if MM then MM.Elegir(elegido, self.jefe.n) end
    if GL.VerBotin then
      local b = GL.VerBotin(NombreVisibleR11(self.jefe), self.jefe.botin or {})
      if MM and MM.AnclarBotin then MM.AnclarBotin(b)
      elseif b and ven then b:ClearAllPoints(); b:SetPoint("TOPLEFT", ven, "TOPRIGHT", 8, 0) end
    end
  end)
  if GL.Ayuda then GL.Ayuda(f, L"Jefe", L"Clic: su botín (todo o lo útil para ti). Clic derecho: marcar como muerto.") end
  -- 9.7.6: al pasar el ratón, el jefe se resalta también en el mapa
  f:HookScript("OnEnter", function(self)
    resaltado = Clave(self.jefe); MarcarFilas()
    if GL.MapaModoMazmorra then GL.MapaModoMazmorra.Resaltar(resaltado) end
  end)
  f:HookScript("OnLeave", function()
    resaltado = nil; MarcarFilas()
    if GL.MapaModoMazmorra then GL.MapaModoMazmorra.Resaltar(nil) end
  end)
  ven.filas[i] = f
  return f
end

-- Si falta el mapa integrado, abrir el catálogo correspondiente, no otra instancia.
local function AbrirMapaActual()
  if not actual then return end
  if GL.MapaModoMazmorra and GL.MapaModoMazmorra.Abrir(actual) then
    GL.RefrescarModoMazmorra(); return
  end
  if GL.frame and not GL.frame:IsShown() and GL.AlternarVentana then GL.AlternarVentana() end
  if actual.banda then
    if GL.AbrirBanda976 then GL.AbrirBanda976(actual.clave or actual.n) end
    return
  end
  if GL.AbrirMazmorra then GL.AbrirMazmorra(actual.clave or actual.n) end
  if GL._abrirMapaMazmorra then pcall(GL._abrirMapaMazmorra, actual) end
end

local function Crear()
  ven = CreateFrame("Frame", "GuiaAventureroModoMazmorra", UIParent, PLANTILLA)
  ven:SetWidth(300); ven:SetHeight(200)
  ven:SetFrameStrata("MEDIUM")
  ven:SetMovable(true); ven:EnableMouse(true); ven:SetClampedToScreen(true)
  ven:RegisterForDrag("LeftButton")
  ven:SetScript("OnDragStart", function(self) if not DB().bloqueada then self:StartMoving() end end)
  ven:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    DB().posMazmorra = { p, rp, x, y }
  end)
  GL.Caja(ven, GL.COLOR.fondo, GL.COLOR.borde)
  ven.raya = ven:CreateTexture(nil, "ARTWORK")
  ven.raya:SetHeight(2)
  ven.raya:SetPoint("TOPLEFT", ven, "TOPLEFT", 1, -1)
  ven.raya:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -1, -1)
  ven.etiqueta = GL.Texto(ven, "GameFontHighlightSmall")
  ven.etiqueta:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -9)
  ven.titulo = GL.Texto(ven, "GameFontNormal")
  ven.titulo:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -22)
  ven.titulo:SetPoint("RIGHT", ven, "RIGHT", -70, 0)
  if ven.titulo.SetWordWrap then ven.titulo:SetWordWrap(false) end
  ven.salir = GL.CrearBoton(ven, L"Salir", function() GL.SalirModoMazmorra(true) end, nil, 18)
  ven.salir:SetWidth(56)
  ven.salir:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -8, -8)
  if GL.Ayuda then GL.Ayuda(ven.salir, L"Salir del modo mazmorra", L"Vuelve la guía. En esta mazmorra no vuelve a salir hasta que entres otra vez.") end
  ven.cabJefes = GL.Texto(ven, "GameFontHighlightSmall")
  ven.cabMisiones = GL.Texto(ven, "GameFontHighlightSmall")
  ven.misiones = GL.Texto(ven, "GameFontHighlightSmall")
  ven.mapa = GL.CrearBoton(ven, L"Mapa", AbrirMapaActual, nil, 20)
  ven.mapa:SetWidth(80)
  ven.botin = GL.CrearBoton(ven, L"Botín útil", function()
    if not actual then return end
    local clave = actual.clave or actual.n
    local jefes = (GL.JefesVisibles976 and GL.JefesVisibles976(clave)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[clave]) or {}
    local todos = GL.BotinesDeJefes977(jefes)
    local b = GL.VerBotin and GL.VerBotin(actual.n .. L" · todo el botín", todos)
    if b then b:ClearAllPoints(); b:SetPoint("TOPLEFT", ven, "TOPRIGHT", 8, 0) end
  end, nil, 20, "accion")
  ven.botin:SetWidth(100)
  ven.filas = {}
  local pos = DB().posMazmorra
  if type(pos) == "table" and pos[1] then ven:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  elseif GL.frame then ven:SetPoint("TOPLEFT", GL.frame, "TOPLEFT", 0, 0)
  else ven:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60) end
  if GL.Pegable then pcall(GL.Pegable, ven, function(f) local p, _, rp, x, y = f:GetPoint(); DB().posMazmorra = { p, rp, x, y } end) end
  if GL.ConstruirBarraXP then   -- la barra de XP también en el modo mazmorra
    ven.barraXP = GL.ConstruirBarraXP(ven, 14)
    ven.barraXP:SetPoint("BOTTOMLEFT", ven, "TOPLEFT", 0, 4)
    ven.barraXP:SetPoint("BOTTOMRIGHT", ven, "TOPRIGHT", 0, 4)
    ven.barraXP:SetHeight(14)
  end
  ven:Hide()
end

-- No cambiar el estado de la visita al restablecer sus coordenadas.
GL.alReiniciar = GL.alReiniciar or {}
table.insert(GL.alReiniciar, function()
  DB().posMazmorra = nil
  if ven then
    ven:ClearAllPoints()
    if GL.frame then ven:SetPoint("TOPLEFT", GL.frame, "TOPLEFT", 0, 0)
    else ven:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60) end
  end
end)

function GL.RefrescarModoMazmorra()
  if not ven or not actual then return end
  local a = GL.COLOR.acento
  ven.raya:SetColorTexture(a[1], a[2], a[3], 1)
  ven.etiqueta:SetText(string.format(L"|cff%02x%02x%02xMODO MAZMORRA|r", a[1] * 255, a[2] * 255, a[3] * 255))
  ven.titulo:SetText(C.BLANCO .. actual.n .. C.FIN .. C.GRIS .. "  " .. (actual.banda and (actual.jugadores and (actual.jugadores .. L" jugadores") or "")
    or (tostring(actual.min) .. "-" .. tostring(actual.max))) .. C.FIN)
  local jefes = (GL.JefesVisibles976 and GL.JefesVisibles976(actual.clave or actual.n)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[actual.clave or actual.n]) or {}
  local muertos = Muertos()
  local y = 44
  ven.cabJefes:ClearAllPoints()
  ven.cabJefes:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -y)
  ven.cabJefes:SetText(C.GRIS .. L"JEFES · PROGRESO DE ESTA VISITA" .. C.FIN .. ((#jefes == 0) and (C.GRIS .. L"  aún no se conocen" .. C.FIN) or ""))
  y = y + 16
  for _, f in ipairs(ven.filas) do f:Hide() end
  local siguiente = false
  for i, j in ipairs(jefes) do
    local f = Fila(i)
    f.jefe = j
    local ubicacion = GL.UbicacionJefe977 and GL.UbicacionJefe977(j)
    f.ayudaTexto = L"Clic: su botín (todo o lo útil para ti). Clic derecho: marcar como muerto."
    if ubicacion then f.ayudaTexto = f.ayudaTexto .. "\n" .. ubicacion end
    local muerto = muertos[IdentidadJefe(j)] == true
    local util, mejor = GL.UtilesDeJefe(j)
    local esSig = not muerto and not siguiente
    if esSig then siguiente = true end
    local nombre = NombreVisibleR11(j)
    if muerto then f.texto:SetText(GL.Icono("✓") .. " " .. C.GRIS .. nombre .. C.FIN)
    elseif esSig then f.texto:SetText(C.AMARILLO .. "› " .. nombre .. C.FIN .. C.GRIS .. L"  siguiente" .. C.FIN)
    else f.texto:SetText("|cffd0d2dc" .. nombre .. C.FIN) end
    local der = ""
    if util > 0 then der = C.VERDE .. util .. (util == 1 and L" útil" or L" útiles") .. C.FIN .. ((mejor > 0) and (" " .. GL.Icono("▲")) or "") end
    f.der:SetText(der)
    f.esSig = esSig
    f.marca:SetColorTexture(a[1], a[2], a[3], esSig and 0.14 or 0)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", ven, "TOPLEFT", 6, -y)
    f:SetPoint("TOPRIGHT", ven, "TOPRIGHT", -6, -y)
    f:Show()
    y = y + 18
  end
  -- misiones de la mazmorra
  y = y + 6
  ven.cabMisiones:ClearAllPoints()
  ven.cabMisiones:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -y)
  ven.cabMisiones:SetText(C.GRIS .. L"MISIONES" .. C.FIN)
  y = y + 16
  local l = {}
  for _, q in ipairs(actual.misiones or {}) do
    local enDiario = q.q and GL.MisionEnDiario and GL.MisionEnDiario(q.q)
    local hecha = q.q and GL.MisionCompletada and GL.MisionCompletada(q.q)
    if enDiario then
      local prog = ""
      if GL.ProgresoDestino then
        local ok, p = pcall(GL.ProgresoDestino, { q = q.q, a = "C" }, false)
        if ok and type(p) == "string" then prog = "  " .. p end
      end
      table.insert(l, C.AMARILLO .. "• " .. q.n .. C.FIN .. prog)
    elseif hecha then
      table.insert(l, GL.Icono("✓") .. " " .. C.GRIS .. q.n .. C.FIN)
    end
  end
  if #l == 0 then l[1] = C.GRIS .. (actual.banda and L"No llevas misiones de esta banda." or L"No llevas misiones de esta mazmorra.") .. C.FIN end
  local txt = table.concat(l, "\n")
  ven.misiones:ClearAllPoints()
  ven.misiones:SetPoint("TOPLEFT", ven, "TOPLEFT", 12, -y)
  ven.misiones:SetWidth(276)
  ven.misiones:SetText(txt)
  y = y + ((GL.Alto and GL.Alto(ven.misiones, txt, 12, 276)) or (#l * 14)) + 10
  -- 9.7.6: el mapa, debajo de las misiones (con «Ampliar» se va a la derecha del panel)
  local mf = GL.MapaModoMazmorra and GL.MapaModoMazmorra.Frame()
  if mf and mf.modo == "dentro" and mf:IsShown() then
    mf:ClearAllPoints()
    mf:SetPoint("TOPLEFT", ven, "TOPLEFT", 6, -y)
    mf:SetSize((ven:GetWidth() or 300) - 12, GL.MapaModoMazmorra.ALTO)
    y = y + GL.MapaModoMazmorra.ALTO + 8
  end
  ven.mapa:ClearAllPoints()
  ven.mapa:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -y)
  ven.botin:ClearAllPoints()
  if GL.MAPAS_MAZMORRAS then
    ven.mapa:Show()
    ven.botin:SetPoint("LEFT", ven.mapa, "RIGHT", 6, 0)
  else   -- 9.4.2: mapas apagados: sin botón Mapa, Botín útil en su sitio
    ven.mapa:Hide()
    ven.botin:SetPoint("TOPLEFT", ven, "TOPLEFT", 10, -y)
  end
  ven:SetHeight(y + 30)
  MarcarFilas()
end

local ventanaAntes, descartada = nil, nil
-- Identidad del catálogo independiente del idioma, con datos de instancia reales si existen.
-- Un mapID de instancia no es un ID de mapa de interfaz ni una identificación de lockout.
local function EnteroPositivo(v)
  if not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v > 0 and v < math.huge and v == math.floor(v) then return v end
end
local function Contexto(m, id, dificultad)
  return { clave = m.clave or m.n, banda = m.banda == true, id = EnteroPositivo(id), dificultad = EnteroPositivo(dificultad) }
end
local function Mismo(a, b)
  return a and b and a.clave == b.clave and a.banda == b.banda
    and (not a.id or not b.id or a.id == b.id)
    and (not a.dificultad or not b.dificultad or a.dificultad == b.dificultad)
end
local function Completar(a,b)
  a.id = a.id or b.id; a.dificultad = a.dificultad or b.dificultad
end
-- El ID de GetInstanceInfo identifica el tipo de mapa, no el bloqueo individual.
-- Tras una salida confirmada no reutilizar las muertes como si fueran de la nueva visita.
local function CerrarProgreso()
  local p = DB().mazMuertos
  if type(p) == "table" and p.activa == true then p.activa = false end
end
local function SincronizarProgreso(m, nuevo)
  local db = DB()
  local p = db.mazMuertos
  if type(p) == "table" and p.activa == true and Mismo(p, nuevo) and type(p.jefes) == "table" then
    Completar(p, nuevo)
    return
  end
  -- Conservar el registro legado sin atribuirlo a una visita nueva.
  local legado = type(p) == "table" and p.legado or nil
  if type(p) == "table" and p.clave == nil and type(p.jefes) == "table" then
    legado = { n = p.n, t = p.t, jefes = p.jefes }
  end
  local anterior
  if type(p) == "table" and p.clave and type(p.jefes) == "table" then
    anterior = { n = p.n, clave = p.clave, banda = p.banda, id = p.id, dificultad = p.dificultad, t = p.t, jefes = p.jefes }
  end
  db.mazMuertos = { n = m.n, clave = nuevo.clave, banda = nuevo.banda, id = nuevo.id,
    dificultad = nuevo.dificultad, activa = true, t = Ahora(), jefes = {}, legado = legado, anterior = anterior }
end
local function Entrar(m, nuevo)
  nuevo = nuevo or Contexto(m)
  if not ven then Crear() end
  if not Mismo(contexto, nuevo) then
    resaltado, elegido = nil, nil
    if actual and GL.MapaModoMazmorra then pcall(GL.MapaModoMazmorra.Cerrar) end
  end
  contexto = nuevo
  SincronizarProgreso(m, nuevo)
  local cambiando = actual ~= nil
  actual = m
  -- Al entrar en la instancia buscada ya no se necesita su entrada exterior.
  local desvio = GL.DesvioActual and GL.DesvioActual()
  if type(desvio) == "table" and desvio.mazmorraEntrada and GL.SeguirDesvio
      and (Minus(desvio.mazmorraEntrada) == Minus(m.clave or m.n)
        or Minus(desvio.mazmorraEntrada) == Minus(m.n)) then
    GL.SeguirDesvio(nil)
  end
  if not cambiando and GL.frame then
    ventanaAntes = GL.frame:IsShown()
    if ventanaAntes then GL.frame:Hide() end
  end
  if not cambiando and GL.franja and GL.franja:IsShown() then GL.franja:Hide(); ventanaAntes = "franja" end
  ven:Show()
  GL.RefrescarModoMazmorra()
  if Si("mapaModoMazmorra") and GL.MapaModoMazmorra then pcall(GL.MapaModoMazmorra.Abrir, m); GL.RefrescarModoMazmorra() end   -- 9.7.6
  if GL.Mensaje then GL.Mensaje((m.banda and L"modo banda: " or L"modo mazmorra: ") .. m.n .. L". Al salir vuelve la guía.") end
end

function GL.SalirModoMazmorra(aMano)
  if aMano and actual then descartada = contexto or Contexto(actual) end
  if ven then ven:Hide() end
  if GL.MapaModoMazmorra then pcall(GL.MapaModoMazmorra.Cerrar) end   -- 9.7.6
  if not actual then return end
  actual, contexto = nil, nil
  if ventanaAntes == "franja" and GL.PonerTamano then pcall(GL.PonerTamano, "franja")
  elseif ventanaAntes and GL.frame then GL.frame:Show() end
  ventanaAntes = nil
  if GL.Refrescar then GL.Refrescar() end
end

local function Mirar()
  local habilitado = Si("modoMazmorra")
  if not habilitado and actual then GL.SalirModoMazmorra() end
  local dentro, tipo = Consulta(IsInInstance)
  -- Una consulta fallida no equivale a abandonar la instancia.
  if type(dentro) ~= "boolean" or (dentro and type(tipo) ~= "string") then return end
  if dentro and (tipo == "party" or tipo == "raid") then
    local buscar = tipo == "party" and BuscarMazmorra or BuscarBanda
    local nombre, tipoInfo, dificultad, _, _, _, _, id = Consulta(GetInstanceInfo)
    if type(tipoInfo) == "string" and tipoInfo ~= "" and tipoInfo ~= tipo then return end
    local nombreReal = Minus(nombre) ~= ""
    if not nombreReal then nombre = Consulta(GetZoneText) end
    if Minus(nombre) == "" then return end
    local m, catalogo = buscar(nombre)
    if not catalogo then return end
    if not m then
      -- Zona de respaldo desconocida puede ser una sala de la instancia actual.
      if not nombreReal then return end
      descartada = nil
      CerrarProgreso()
      if actual then GL.SalirModoMazmorra() end
      return
    end
    local nuevo = Contexto(m, id, dificultad)
    -- Una sala con nombre de otra instancia no basta para cambiar de contexto.
    local guardado = DB().mazMuertos
    if not nombreReal and ((contexto and not Mismo(contexto, nuevo)) or (descartada and not Mismo(descartada, nuevo))
        or (type(guardado) == "table" and guardado.activa == true and not Mismo(guardado, nuevo))) then return end
    if habilitado or (type(DB().mazMuertos) == "table" and DB().mazMuertos.activa == true) then SincronizarProgreso(m, nuevo) end
    if not habilitado then return end
    if descartada then
      if Mismo(descartada, nuevo) then
        Completar(descartada, nuevo)
        if actual then GL.SalirModoMazmorra() end
        return
      end
      descartada = nil
    end
    if not actual or not Mismo(contexto, nuevo) then Entrar(m, nuevo)
    else Completar(contexto, nuevo) end
  else
    descartada = nil
    CerrarProgreso()
    if actual then GL.SalirModoMazmorra() end
  end
end
GL._modoMazmorra = { Entrar = Entrar, Mirar = Mirar, Actual = function() return actual end }

-- Identificación inequívoca, sin compartir el progreso de un grupo cartográfico.
local function Matar(nombre, dificultad, npc, encuentro)
  if not actual or Minus(nombre) == "" then return end
  local anterior = contexto
  -- Revalidar la instancia antes de aceptar un evento retrasado de otra zona.
  local dentro, tipo = Consulta(IsInInstance)
  if dentro ~= true or tipo ~= (actual.banda and "raid" or "party") then return end
  local nom, tipoInfo, dif, _, _, _, _, id = Consulta(GetInstanceInfo)
  if tipoInfo and tipoInfo ~= tipo then return end
  if Minus(nom) == "" then nom = Consulta(GetZoneText) end
  local buscar = tipo == "raid" and BuscarBanda or BuscarMazmorra
  local m = buscar(nom)
  if not m or not Mismo(anterior, Contexto(m, id, dif)) then return end
  if issecretvalue and (issecretvalue(dificultad) or issecretvalue(encuentro)) then return end
  if dificultad ~= nil and not EnteroPositivo(dificultad) then return end
  if encuentro ~= nil and not EnteroPositivo(encuentro) then return end
  local difEvento, difActual = EnteroPositivo(dificultad), EnteroPositivo(dif) or anterior.dificultad
  if difEvento and difActual and difEvento ~= difActual then return end
  local b, encontrado = Minus(nombre), nil
  for _, j in ipairs((GL.JefesVisibles976 and GL.JefesVisibles976(actual.clave or actual.n)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[actual.clave or actual.n]) or {}) do
    local coincide = false
    for _, alias in pairs({ j.n, j.ing, j.nombreOriginal977, NombreJefe(j), GL.EnIngles and GL.EnIngles(NombreJefe(j)) }) do
      local n = Minus(alias):gsub(" %(.*%)$", "")
      if n ~= "" and (n == b or Minus(alias) == b) then coincide = true end
    end
    if coincide and (not npc or not EnteroPositivo(j.npc) or j.npc == npc) then
      if encontrado and encontrado ~= j then return end
      encontrado = j
    end
  end
  local k = IdentidadJefe(encontrado)
  if not k then return end
  -- Vincular el ID de evento solo después de resolver un nombre inequívoco.
  -- No equiparar ID de diario, PNJ o mapa con el ID del evento.
  if encuentro then
    local p = DB().mazMuertos
    if type(p) ~= "table" or p.activa ~= true then return end
    if type(p.encuentros977) ~= "table" then p.encuentros977 = {} end
    local e = p.encuentros977
    if e[encuentro] and e[encuentro] ~= k then return end
    for idEvento, jefe in pairs(e) do if jefe == k and idEvento ~= encuentro then return end end
    e[encuentro] = k
  end
  local muertos = Muertos()
  if muertos[k] ~= true then muertos[k] = true; GL.RefrescarModoMazmorra() end
end


local function ReinicioConfirmado(mensaje)
  local p = DB().mazMuertos
  if type(p) ~= "table" or p.activa ~= true or Minus(mensaje) == "" or type(INSTANCE_RESET) ~= "string" then return end
  for _, nombre in pairs({p.n, p.clave, GL.EnIngles and GL.EnIngles(p.clave)}) do
    if type(nombre) == "string" and nombre ~= "" then
      local ok, texto = pcall(string.format, INSTANCE_RESET, nombre)
      if ok and texto == mensaje then
        CerrarProgreso()
        if actual and contexto then SincronizarProgreso(actual, contexto); GL.RefrescarModoMazmorra() end
        return
      end
    end
  end
end

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "modoMazmorra", "Modo mazmorra automático",
  "Al entrar en una mazmorra o banda, un panel con sus jefes en orden, el botín útil y sus misiones. Al salir vuelve la guía.",
  function() return Si("modoMazmorra") end, function(v) DB().modoMazmorra = v; pcall(Mirar) end, pestana = "general" })
-- 9.7.6: el mapa dentro del panel al entrar
table.insert(GL.ajustesInterfaz, { "mapaModoMazmorra", "Mapa en el modo mazmorra",
  "Al entrar en una mazmorra o banda, su mapa sale en el panel, debajo de las misiones. «Ampliar» lo pone más grande a su derecha.",
  function() return Si("mapaModoMazmorra") end, function(v)
    DB().mapaModoMazmorra = v
    if not GL.MapaModoMazmorra then return end
    if v and actual then pcall(GL.MapaModoMazmorra.Abrir, actual) elseif not v then pcall(GL.MapaModoMazmorra.Cerrar) end
    pcall(GL.RefrescarModoMazmorra)
  end, pestana = "general" })

table.insert(GL.alIniciar, function()
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
  pcall(f.RegisterEvent, f, "ZONE_CHANGED_NEW_AREA")
  pcall(f.RegisterEvent, f, "QUEST_LOG_UPDATE")
  pcall(f.RegisterEvent, f, "PLAYER_DIFFICULTY_CHANGED")
  pcall(f.RegisterEvent, f, "UPDATE_INSTANCE_INFO")
  pcall(f.RegisterEvent, f, "ENCOUNTER_END")
  pcall(f.RegisterEvent, f, "BOSS_KILL")
  pcall(f.RegisterEvent, f, "CHAT_MSG_SYSTEM")
  -- 9.7.4: en WoW Forever un addon no puede escuchar el registro de combate (COMBAT_LOG_EVENT_UNFILTERED):
  -- el juego lo bloquea y sale ADDON_ACTION_FORBIDDEN. Además del fin de encuentro, se mira si tu objetivo muere.
  pcall(f.RegisterEvent, f, "PLAYER_TARGET_CHANGED")
  if f.RegisterUnitEvent then pcall(f.RegisterUnitEvent, f, "UNIT_HEALTH", "target") end
  local eventosEquipo = { PLAYER_EQUIPMENT_CHANGED=true, PLAYER_LEVEL_UP=true, SPELLS_CHANGED=true, PLAYER_TALENT_UPDATE=true, UPDATE_FACTION=true, SKILL_LINES_CHANGED=true, GET_ITEM_INFO_RECEIVED=true }
  for e in pairs(eventosEquipo) do pcall(f.RegisterEvent, f, e) end
  local pendienteEquipo = false
  local function RefrescarEquipo(id)
    if not actual then return end
    if id then
      local relevante = false
      local clave = actual.clave or actual.n
      local jefes = (GL.JefesVisibles976 and GL.JefesVisibles976(clave)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[clave]) or {}
      for _, j in ipairs(jefes) do
        for _, o in ipairs(j.botin or {}) do if o.id == id then relevante = true; break end end
        if relevante then break end
      end
      if not relevante then return end
    end
    if pendienteEquipo then return end
    pendienteEquipo = true
    local function Pintar()
      pendienteEquipo = false
      if actual then pcall(GL.RefrescarModoMazmorra) end
    end
    if C_Timer and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0.5, Pintar) then return end
    Pintar()
  end
  f:SetScript("OnEvent", function(_, evento, a1, a2, a3, _, a5)
    if eventosEquipo[evento] then
      if evento == "GET_ITEM_INFO_RECEIVED" then
        if EnteroPositivo(a1) and not (issecretvalue and issecretvalue(a2)) and a2 ~= false then RefrescarEquipo(a1) end
      else RefrescarEquipo() end
    elseif evento == "UNIT_HEALTH" or evento == "PLAYER_TARGET_CHANGED" then
      if not actual or Consulta(UnitExists, "target") ~= true then return end
      local guid = Consulta(UnitGUID, "target")
      if type(guid) ~= "string" or not guid:match("^Creature%-") then return end
      if Consulta(UnitIsPlayer, "target") ~= false or Consulta(UnitIsFriend, "player", "target") ~= false then return end
      local npc = tonumber(guid:match("^Creature%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-[^-]+$"))
      if not EnteroPositivo(npc) then return end
      if Consulta(UnitIsDead, "target") == true then pcall(Matar, Consulta(UnitName, "target"), nil, npc) end
    elseif evento == "ENCOUNTER_END" then
      if not (issecretvalue and issecretvalue(a5)) and (a5 == 1 or a5 == true) and EnteroPositivo(a1) then pcall(Matar, a2, a3, nil, a1) end
    elseif evento == "BOSS_KILL" then
      if EnteroPositivo(a1) then pcall(Matar, a2, nil, nil, a1) end
    elseif evento == "CHAT_MSG_SYSTEM" then
      pcall(ReinicioConfirmado, a1)
    elseif evento == "QUEST_LOG_UPDATE" then
      if actual then pcall(GL.RefrescarModoMazmorra) end
    else
      pcall(Mirar)
    end
  end)
  pcall(Mirar)
end)

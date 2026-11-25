-- Opciones.lua: panel de opciones, modo compacto y botón del minimapa. Creado por JKRiveroF.
-- Usa lo que exporta GuiaAventurero.lua en la tabla del addon (GL).

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local ICONO_OPCIONES = "Interface\\Icons\\INV_Misc_Gear_01"
local ICONO_COMPACTO = "Interface\\Icons\\INV_Misc_Note_02"

local compacto, boton                 -- ventana compacta y botón del minimapa
local controles = {}                  -- deslizadores y casillas del panel de opciones
local scrollOp, hijoOp, barraOp       -- las opciones bajan con la rueda si la ventana es pequeña
local altoOpciones = 0

local function DB() return GuiaAventureroDB end

------------------------------------------------------------------------
-- Aplicar escala, transparencia y bloqueo
------------------------------------------------------------------------
local function AplicarFondo(f)
  if f and f.SetBackdropColor then
    local c = GL.COLOR.fondo
    f:SetBackdropColor(c[1], c[2], c[3], c[4])   -- 9.0: la transparencia de toda la ventana sustituye a la opacidad del fondo
  end
end

local function Aplicar()
  local db = DB()
  if GL.frame then
    GL.frame:SetScale(db.escala or 1)
    AplicarFondo(GL.frame)
  end
  if compacto then
    compacto:SetScale(db.escala or 1)
    AplicarFondo(compacto)
  end
  if GL.flecha then GL.flecha:SetScale(db.escalaFlecha or 1); if GL.FlechaAlPixel then GL.FlechaAlPixel() end end
  if GL.AplicarTransparencia then GL.AplicarTransparencia() end
end
GL.AplicarAjustes = Aplicar

-- 9.0: transparencia de toda la ventana (texto y cajas incluidos) para ver el juego que hay detrás.
-- Con «opaca al pasar el ratón», se ve entera mientras el ratón está encima.
function GL.AplicarTransparencia()
  local db = DB()
  if type(db) ~= "table" then return end
  local a = tonumber(db.alphaVentana) or 1
  for _, f in ipairs({ GL.frame, compacto, GL.franja, _G.GuiaAventureroModoMazmorra }) do
    if f and f.SetAlpha then
      local encima = a < 1 and db.alphaRaton ~= false and f:IsShown() and MouseIsOver and MouseIsOver(f)
      f:SetAlpha(encima and 1 or a)
    end
  end
end
local relojAlpha, esperaAlpha = CreateFrame("Frame"), 0
relojAlpha:SetScript("OnUpdate", function(_, dt)   -- mira si el ratón entra o sale de la ventana
  esperaAlpha = esperaAlpha + (dt or 0)
  if esperaAlpha < 0.15 then return end
  esperaAlpha = 0
  if type(DB()) == "table" and (tonumber(DB().alphaVentana) or 1) < 1 then GL.AplicarTransparencia() end
end)   -- 7.1: el tema Pergamino repinta el fondo con la opacidad elegida

------------------------------------------------------------------------
-- Modo compacto: una ventana pequeña con el paso actual y el destino
------------------------------------------------------------------------
local function RefrescarCompacto()
  if not compacto or not compacto:IsShown() then return end
  local db = DB()
  local s, p = GL.PasoActual()
  if not s or not p then return end
  compacto.titulo:SetText(C.AMARILLO .. s.titulo .. C.FIN .. C.GRIS .. L"  ·  paso " .. db.paso .. "/" .. #s.pasos .. C.FIN)
  local texto = GL.Colorear(p.t)
  compacto.texto:SetText(texto)
  local d = GL.DestinoActual()
  if d then
    local hecho = GL.DestinoHecho(d)
    if hecho then
      GL.PonerIcono(compacto.icono, GL.ICONO_HECHO, false)
    elseif d.a and GL.ICONO_ACCION[d.a] then
      GL.PonerIcono(compacto.icono, GL.ICONO_ACCION[d.a], false)
    else
      GL.PonerIcono(compacto.icono, GL.ICONO_LUGAR)
    end
    compacto.icono:Show()
    local progreso = GL.ProgresoDestino(d, hecho)
    compacto.destino:SetText(C.BLANCO .. d.n .. C.FIN .. (progreso and progreso ~= "" and ("  " .. progreso) or ""))
  else
    compacto.icono:Hide()
    compacto.destino:SetText(C.GRIS .. L"Este paso no tiene destino para la flecha." .. C.FIN)
  end
  -- 9.7.4: una línea por cada misión del paso que llevas en el diario, con lo que llevas de ella
  -- (antes solo salía la del destino de la flecha)
  local lineas = {}
  if GL.MisionesDelPaso and GL.MisionEnDiario then
    for _, t in ipairs(GL.MisionesDelPaso(p)) do
      -- 9.7.7.2: la misión de la línea del objetivo (la de la flecha) ya sale abajo con su progreso: no se repite
      local deLaFlecha = d and d.q and tonumber(d.q) == tonumber(t.q)
      if t.q and not deLaFlecha and GL.MisionEnDiario(t.q) and not (GL.MisionCompletada and GL.MisionCompletada(t.q)) then
        -- 9.7.5: solo los números (1/6 · 0/10); el nombre del objetivo repetía el de la misión y la línea se cortaba
        local obj
        if C_QuestLog and C_QuestLog.GetQuestObjectives then
          local ok, lista = pcall(C_QuestLog.GetQuestObjectives, t.q)
          if ok and type(lista) == "table" then
            local partes = {}
            for _, o in ipairs(lista) do
              local h, n = tonumber(GL.Seguro and GL.Seguro(o.numFulfilled) or o.numFulfilled), tonumber(GL.Seguro and GL.Seguro(o.numRequired) or o.numRequired)
              if h and n and n > 0 then table.insert(partes, ((h >= n) and C.VERDE or C.BLANCO) .. h .. "/" .. n .. C.FIN) end
            end
            if #partes > 0 then obj = table.concat(partes, C.GRIS .. " · " .. C.FIN) end
          end
        end
        if not obj then obj = GL.ObjetivosDeMision and GL.ObjetivosDeMision(t.q) end
        local listo = GL.ObjetivosListos and GL.ObjetivosListos(t.q)
        local estado = listo and (C.VERDE .. L"lista para entregar" .. C.FIN) or (obj or "")
        table.insert(lineas, { texto = C.AMARILLO .. (t.nombre or L"Misión") .. C.FIN .. ((estado ~= "") and ("  " .. estado) or ""), listo = listo })
      end
    end
  end
  compacto.misiones = compacto.misiones or {}
  local MAX = 5
  local n = math.min(#lineas, MAX)
  -- 9.7.6: cada misión con su icono, como la línea del objetivo (objetivos por hacer, o entregar si está lista)
  for i = 1, MAX do
    local fs = compacto.misiones[i]
    if not fs and i <= n then
      fs = GL.Texto(compacto, "GameFontHighlightSmall")
      GL.UnaLinea(fs)
      fs.icono = compacto:CreateTexture(nil, "ARTWORK")
      fs.icono:SetWidth(13); fs.icono:SetHeight(13)
      compacto.misiones[i] = fs
    end
    if fs then
      if i <= n then
        local y = 10 + 18 + (n - i) * 14
        fs.icono:ClearAllPoints()
        fs.icono:SetPoint("BOTTOMLEFT", compacto, "BOTTOMLEFT", 10, y)
        local ic = GL.ICONO_ACCION and GL.ICONO_ACCION[lineas[i].listo and "T" or "C"]
        if ic then GL.PonerIcono(fs.icono, ic, false); fs.icono:Show() else fs.icono:Hide() end
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", fs.icono, "RIGHT", 5, 0)
        fs:SetPoint("RIGHT", compacto, "RIGHT", -10, 0)
        fs:SetText(lineas[i].texto); fs:Show()
      else
        fs:SetText(""); fs:Hide(); fs.icono:Hide()
      end
    end
  end
  local alto = GL.Alto(compacto.texto, texto, 12, compacto:GetWidth() - 20)
  compacto:SetHeight(32 + alto + 6 + 16 + 10 + n * 14 + (n > 0 and 4 or 0) + ((compacto.barraXP and compacto.barraXP:IsShown()) and 22 or 0))   -- 9.0: barra de XP
end

local function GuardarPosicionCompacto()
  local p, _, rp, x, y = compacto:GetPoint()
  DB().posCompacto = { p, rp, x, y }
end

local function CrearCompacto()
  local db = DB()
  compacto = CreateFrame("Frame", "GuiaAventureroCompacto", UIParent, PLANTILLA)
  compacto:SetWidth(320)
  compacto:SetHeight(96)
  compacto:SetFrameStrata("MEDIUM")
  compacto:SetClampedToScreen(true)
  compacto:SetMovable(true)
  compacto:EnableMouse(true)
  compacto:RegisterForDrag("LeftButton")
  compacto:SetScript("OnDragStart", function(self)
    if not DB().bloqueada then self:StartMoving() end
  end)
  compacto:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    GuardarPosicionCompacto()
  end)
  GL.Caja(compacto, GL.COLOR.fondo, GL.COLOR.borde)
  GL.Sombra(compacto)
  GL.Acento(compacto, 2)
  AplicarFondo(compacto)
  if db.posCompacto then
    compacto:SetPoint(db.posCompacto[1], UIParent, db.posCompacto[2], db.posCompacto[3], db.posCompacto[4])
  else
    compacto:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -200)
  end

  local marco = GL.CrearMarcoIcono(compacto, 20)
  marco:SetPoint("TOPLEFT", compacto, "TOPLEFT", 8, -8)
  GL.PorTema(function() GL.Caja(marco, GL.COLOR.icono, GL.COLOR.acento) end)
  GL.PonerIcono(marco.icono, GL.RUTA.icono)

  local abrir = GL.CrearBoton(compacto, L"Abrir", function() GL.SalirCompacto() end, nil, 18)
  -- 9.0: botón para pasar a la franja (lo más pequeño)
  local plegar = GL.CrearBoton(compacto, "_", function() if GL.PonerTamano then GL.PonerTamano("franja") end end, nil, 18)
  plegar:SetWidth(20)
  plegar:SetPoint("TOPRIGHT", compacto, "TOPRIGHT", -8, -9)
  GL.Ayuda(plegar, L"Franja", L"Deja solo una franja con el paso y la distancia.")
  abrir:SetWidth(44)
  abrir:SetPoint("RIGHT", plegar, "LEFT", -4, 0)
  GL.Ayuda(abrir, L"Ventana completa", L"Vuelve a la ventana grande de la guía.")
  local sig = GL.CrearBoton(compacto, ">", function() GL.Siguiente() end, nil, 18)
  sig:SetWidth(22)
  sig:SetPoint("RIGHT", abrir, "LEFT", -4, 0)
  GL.Ayuda(sig, L"Paso siguiente")
  local ant = GL.CrearBoton(compacto, "<", function() GL.Anterior() end, nil, 18)
  ant:SetWidth(22)
  ant:SetPoint("RIGHT", sig, "LEFT", -4, 0)
  GL.Ayuda(ant, L"Paso anterior")

  compacto.titulo = GL.Texto(compacto, "GameFontNormalSmall")
  compacto.titulo:SetPoint("TOPLEFT", compacto, "TOPLEFT", 34, -12)
  compacto.titulo:SetPoint("RIGHT", ant, "LEFT", -6, 0)
  GL.UnaLinea(compacto.titulo)

  compacto.texto = GL.Texto(compacto, "GameFontHighlightSmall")
  compacto.texto:SetPoint("TOPLEFT", compacto, "TOPLEFT", 10, -32)
  compacto.texto:SetPoint("TOPRIGHT", compacto, "TOPRIGHT", -10, -32)
  -- 9.0: la barra de XP también en la ventana compacta (encima del texto del paso)
  if GL.ConstruirBarraXP then
    compacto.barraXP = GL.ConstruirBarraXP(compacto, 14)
    compacto.barraXP:SetPoint("TOPLEFT", compacto, "TOPLEFT", 10, -32)
    compacto.barraXP:SetPoint("TOPRIGHT", compacto, "TOPRIGHT", -10, -32)
    compacto.barraXP:SetHeight(14)
    compacto.barraXP:SetScript("OnShow", function() compacto.texto:SetPoint("TOPLEFT", compacto, "TOPLEFT", 10, -54); compacto.texto:SetPoint("TOPRIGHT", compacto, "TOPRIGHT", -10, -54) end)
    compacto.barraXP:SetScript("OnHide", function() compacto.texto:SetPoint("TOPLEFT", compacto, "TOPLEFT", 10, -32); compacto.texto:SetPoint("TOPRIGHT", compacto, "TOPRIGHT", -10, -32) end)
  end

  compacto.icono = compacto:CreateTexture(nil, "ARTWORK")
  compacto.icono:SetWidth(13)
  compacto.icono:SetHeight(13)
  compacto.icono:SetPoint("BOTTOMLEFT", compacto, "BOTTOMLEFT", 10, 10)
  compacto.destino = GL.Texto(compacto, "GameFontHighlightSmall")
  compacto.destino:SetPoint("LEFT", compacto.icono, "RIGHT", 5, 0)
  compacto.destino:SetPoint("RIGHT", compacto, "RIGHT", -10, 0)
  GL.UnaLinea(compacto.destino)

  compacto:SetScale(db.escala or 1)
  compacto:SetScript("OnShow", RefrescarCompacto)
  compacto:Hide()
end

function GL.EntrarCompacto()
  local db = DB()
  db.compacto = true
  db.ocultoCompacto = false
  if GL.frame then GL.frame:Hide() end
  compacto:Show()
  RefrescarCompacto()
  if controles.compacto then controles.compacto.Actualizar() end
end

function GL.SalirCompacto()
  local db = DB()
  db.compacto = false
  db.oculto = false
  compacto:Hide()
  if GL.frame then GL.frame:Show() end
  if controles.compacto then controles.compacto.Actualizar() end
end

-- /ga sin nada y el botón del minimapa: muestran u ocultan la ventana que toque.
local alternarNormal = GL.AlternarVentana
function GL.AlternarVentana()
  local db = DB()
  if db.compacto and compacto then
    if compacto:IsShown() then
      compacto:Hide(); db.ocultoCompacto = true
    else
      compacto:Show(); db.ocultoCompacto = false
    end
  else
    alternarNormal()
  end
end

------------------------------------------------------------------------
-- Panel de opciones (dentro de la ventana, como una pestaña más)
------------------------------------------------------------------------
local function Redondear(v, paso)
  return math.floor(v / paso + 0.5) * paso
end

local function CrearDeslizador(padre, etiqueta, minimo, maximo, paso, leer, escribir, formato)
  local cont = CreateFrame("Frame", nil, padre)
  cont:SetHeight(30)
  cont.texto = GL.Texto(cont, "GameFontHighlightSmall")
  cont.texto:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, 0)
  cont.texto:SetText(etiqueta)
  local s = CreateFrame("Slider", nil, cont)
  s:SetOrientation("HORIZONTAL")
  s:SetHeight(14)
  s:SetPoint("TOPLEFT", cont, "TOPLEFT", 4, -14)
  s:SetPoint("TOPRIGHT", cont, "TOPRIGHT", -54, -14)
  s:SetMinMaxValues(minimo, maximo)
  s:SetValueStep(paso)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true)
  local pista = s:CreateTexture(nil, "BACKGROUND")
  pista:SetPoint("LEFT", s, "LEFT", 0, 0)
  pista:SetPoint("RIGHT", s, "RIGHT", 0, 0)
  pista:SetHeight(4)
  pista:SetColorTexture(1, 1, 1, 0.18)
  s:SetThumbTexture(GL.BLANCO8)
  local pulgar = s:GetThumbTexture()
  if pulgar then
    pulgar:SetWidth(10)
    pulgar:SetHeight(18)
    GL.PorTema(function()
      local a = GL.COLOR.acento
      pulgar:SetVertexColor(a[1], a[2], a[3], 1)
    end)
  end
  cont.valor = GL.Texto(cont, "GameFontHighlightSmall", "RIGHT")
  cont.valor:SetPoint("LEFT", s, "RIGHT", 10, 0)
  local cargando = false
  s:SetScript("OnValueChanged", function(self, v)
    v = Redondear(v, paso)
    cont.valor:SetText(C.AMARILLO .. (formato and formato(v) or (math.floor(v * 100 + 0.5) .. "%")) .. C.FIN)
    if not cargando then escribir(v) end
  end)
  cont.Actualizar = function()
    cargando = true
    s:SetValue(leer())
    cont.valor:SetText(C.AMARILLO .. (formato and formato(leer()) or (math.floor(leer() * 100 + 0.5) .. "%")) .. C.FIN)
    cargando = false
  end
  cont.deslizador = s
  return cont
end

-- 9.0: las casillas pasan a interruptores (pista con el color del acento y una bolita que se mueve)
local function CrearCasilla(padre, etiqueta, ayuda, leer, escribir)
  local c = CreateFrame("CheckButton", nil, padre, PLANTILLA)
  c:SetWidth(30)
  c:SetHeight(16)
  local apagado = { 0.06, 0.06, 0.09, 1 }
  c.bola = c:CreateTexture(nil, "OVERLAY")
  c.bola:SetTexture(GL.BLANCO8)
  c.bola:SetSize(10, 10)
  local function Pintar(encima)
    local si = c:GetChecked() and true or false
    local a = GL.COLOR.acento
    if si then GL.Caja(c, { a[1], a[2], a[3], 0.85 }, encima and GL.COLOR.activoBorde or { a[1], a[2], a[3], 1 })
    else GL.Caja(c, apagado, encima and GL.COLOR.activoBorde or GL.COLOR.botonBorde) end
    c.bola:ClearAllPoints()
    c.bola:SetPoint(si and "RIGHT" or "LEFT", c, si and "RIGHT" or "LEFT", si and -3 or 3, 0)
    c.bola:SetVertexColor(si and 1 or 0.55, si and 1 or 0.56, si and 1 or 0.62, 1)
  end
  GL.PorTema(function() Pintar(false) end)
  c.texto = GL.Texto(c, "GameFontHighlightSmall")
  c.texto:SetPoint("LEFT", c, "RIGHT", 6, 0)
  c.texto:SetText(etiqueta)
  c.etiqueta = etiqueta
  c:SetScript("OnClick", function(self)
    escribir(self:GetChecked() and true or false)
    Pintar(true)
  end)
  GL.Ayuda(c, etiqueta, ayuda)
  c:HookScript("OnEnter", function() Pintar(true) end)
  c:HookScript("OnLeave", function() Pintar(false) end)
  c.Actualizar = function() c:SetChecked(leer() and true or false); Pintar(false) end
  return c
end
GL.CrearCasilla = CrearCasilla   -- también la usa Exploracion.lua

local function AjustarScroll()
  if not scrollOp then return end
  local ancho = scrollOp:GetWidth() or 0
  if ancho <= 0 and GL.frame then ancho = (GL.frame:GetWidth() or 0) - GL.IZQ - GL.MARGEN - 16 end
  if ancho > 0 then hijoOp:SetWidth(ancho) end
  hijoOp:SetHeight(math.max(1, altoOpciones))
  local maximo = math.max(0, math.floor(altoOpciones - (scrollOp:GetHeight() or 0) + 0.5))
  barraOp:SetMinMaxValues(0, maximo)
  GL.Mostrar(barraOp, maximo > 0)
  local actual = barraOp:GetValue() or 0
  if actual > maximo then actual = maximo end
  barraOp:SetValue(actual)
  scrollOp:SetVerticalScroll(actual)
end

-- 7.5.4: copiar los ajustes de otro personaje de la cuenta (los guarda Cuenta.lua al conectar con cada uno)
local function OtrosPersonajes()
  local r = {}
  local yo = (UnitName and UnitName("player") or "") .. "-" .. ((GetRealmName and GetRealmName()) or "")
  local lista = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.personajes
  if type(lista) ~= "table" then lista = {} end
  for k, p in pairs(lista) do if k ~= yo and type(p.ajustes) == "table" then table.insert(r, { k = k, p = p }) end end
  table.sort(r, function(a, b) return a.k < b.k end)
  return r
end

local function CrearCopiar(padre)
  local cont = CreateFrame("Frame", nil, padre)
  cont:SetHeight(46)
  cont.altoFila = 50
  cont.texto = GL.Texto(cont, "GameFontHighlightSmall")
  cont.texto:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, 0)
  cont.texto:SetText(L"Copiar ajustes de otro personaje")
  cont.i = 1
  cont.quien = GL.CrearBoton(cont, "", function()
    local l = OtrosPersonajes()
    if #l > 0 then cont.i = cont.i % #l + 1 end
    cont.Actualizar()
  end, nil, 22)
  cont.quien:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, -16)
  cont.quien:SetPoint("TOPRIGHT", cont, "TOPRIGHT", -84, -16)
  GL.Ayuda(cont.quien, L"Personaje", L"Clic: pasa al siguiente personaje de la cuenta.")
  cont.copiar = GL.CrearBoton(cont, L"Copiar", function()
    local e = OtrosPersonajes()[cont.i]
    if not e then return end
    for _, k in ipairs(GL.AJUSTES_COPIABLES or {}) do DB()[k] = e.p.ajustes[k] end
    if GL.CambiarTema then GL.CambiarTema(DB().tema or "dorado") end
    Aplicar()
    if GL.AplicarTamTexto then GL.AplicarTamTexto() end
    if GL.AplicarGraficos then pcall(GL.AplicarGraficos) end   -- 8.8
    if GL.Mensaje then GL.Mensaje(L"ajustes copiados de " .. (e.p.n or e.k) .. ".") end
    for _, ctl in pairs(controles) do if ctl.Actualizar then ctl.Actualizar() end end
    if GL.Refrescar then GL.Refrescar() end
  end, nil, 22, "accion")
  cont.copiar:SetWidth(80)
  cont.copiar:SetPoint("TOPRIGHT", cont, "TOPRIGHT", 0, -16)
  GL.Ayuda(cont.copiar, L"Copiar", L"Copia tema, tamaños, opacidad y casillas de Ajustes. No toca automatismos ni el progreso de la ruta.")
  cont.Actualizar = function()
    local l = OtrosPersonajes()
    if cont.i > #l then cont.i = 1 end
    local e = l[cont.i]
    cont.quien.texto:SetText(e and ((e.p.n or e.k) .. " " .. GL.Icono("▾")) or L"Ningún otro personaje guardado")
    GL.Mostrar(cont.copiar, e ~= nil)
  end
  return cont
end

-- Fila de temas: un botón por color. El cambio se ve al momento.
local function CrearTemas(padre)
  local cont = CreateFrame("Frame", nil, padre)
  local porFila = 5   -- 8.9.1: con diez temas van en dos filas de cinco
  local visibles = {}   -- 9.2: el tema del estilo Clásico Blizzard no sale aquí (va en el selector de estilo)
  for _, t in ipairs(GL.TEMAS) do if not t.oculto then table.insert(visibles, t) end end
  local filas = math.ceil(#visibles / porFila)
  cont:SetHeight(46 + (filas - 1) * 25)
  cont.altoFila = 50 + (filas - 1) * 25
  cont.texto = GL.Texto(cont, "GameFontHighlightSmall")
  cont.texto:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, 0)
  cont.texto:SetText(L"Tema")
  cont.botones = {}
  local x = 0
  for i = 1, #visibles do
    local t = visibles[i]
    local b = GL.CrearBoton(cont, t.nombre, function()
      GL.CambiarTema(t.id)
      cont.Actualizar()
    end, nil, 22)
    b:SetWidth(60)
    b:SetPoint("TOPLEFT", cont, "TOPLEFT", ((i - 1) % porFila) * 63, -16 - math.floor((i - 1) / porFila) * 25)
    local muestra = b:CreateTexture(nil, "OVERLAY")
    muestra:SetHeight(2)
    muestra:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    muestra:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    local mr, mg, mb = t.acento[1], t.acento[2], t.acento[3]
    if t.clase and GL.ColorDeClase then   -- 8.8: el tema Clase se muestra con el color de tu clase
      local okC, r, g, b = pcall(GL.ColorDeClase)
      if okC and r then mr, mg, mb = r, g, b end
    end
    muestra:SetColorTexture(mr, mg, mb, 1)
    b.tema = t.id
    table.insert(cont.botones, b)
  end
  cont.Actualizar = function()
    local elegido = GL.BuscarTema(DB().tema).id
    for _, b in ipairs(cont.botones) do b:SetActivo(b.tema == elegido) end
  end
  return cont
end

-- 8.8: fila de botones para elegir una opción (estilo de flecha, marco, fuente). opciones = { { id, nombre }, ... }
local function CrearSelector(padre, etiqueta, opciones, leer, escribir)
  local cont = CreateFrame("Frame", nil, padre)
  cont:SetHeight(46)
  cont.altoFila = 48
  cont.texto = GL.Texto(cont, "GameFontHighlightSmall")
  cont.texto:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, 0)
  cont.texto:SetText(L(etiqueta))   -- 9.4.2: traducido al pintarlo (ver CrearBoton)
  cont.botones = {}
  local ancho = (#opciones >= 5) and 60 or 76
  local x = 0
  for i = 1, #opciones do
    local o = opciones[i]
    local b = GL.CrearBoton(cont, o[2], function()
      escribir(o[1])
      cont.Actualizar()
    end, nil, 22)
    b:SetWidth(ancho)
    b:SetPoint("TOPLEFT", cont, "TOPLEFT", x, -16)
    b.valor = o[1]
    table.insert(cont.botones, b)
    x = x + ancho + 3
  end
  cont.Actualizar = function()
    local elegido = leer()
    for _, b in ipairs(cont.botones) do b:SetActivo(b.valor == elegido) end
  end
  return cont
end
GL.CrearSelector = CrearSelector

-- 8.9.5: Ajustes por pestañas, según para qué sirve cada opción. Cada lista va en el orden en que se ve.
-- 9.0: cada pestaña empieza por lo básico (las "basicas" primeras claves); el resto sale con "Ver más ajustes".
local PESTANAS_AJUSTES = {
  { id = "general", nombre = "General", desc = "Ventana, combate, minimapa, sonido y bienvenida.", basicas = 10,
    claves = { "idioma", "escala", "alphaVentana", "alphaRaton", "tamano", "bloqueada", "discretoCombate", "minimapa", "sonidos", "bienvenida",
      "xpEnCombate", "imanes", "modoPesca", "rangosBarras", "rangosAuto" } },
  { id = "aspecto", nombre = "Aspecto", desc = "Colores, marcos, fuentes y cabecera.", basicas = 4,
    claves = { "tema", "marco", "fuentePaso", "barraXP", "fuenteContorno", "degradado", "separadores", "retratoCabecera", "fondoZona",
      "escudo", "insignias", "ayudasEstilo", "compactoEstilo" } },
  { id = "paso", nombre = "Paso", desc = "Lo que ves en la caja del paso y en Siguiente.", basicas = 5,
    claves = { "guiaClara", "tamTexto", "estiloRuta", "lineaAhora", "chips", "resaltarPaso", "casillas", "distanciaColor", "segmentos", "barritas",
      "iconosTipo", "hitos", "calidad", "recompensasPaso", "recompensa", "retrato", "autoSeguimiento" } },
  { id = "flecha", nombre = "Flecha", desc = "Cómo te guía la flecha y qué sale en los mapas.", basicas = 5,
    claves = { "flecha", "verFlecha", "estiloFlecha", "pines", "rutaMapa", "flechaColor", "anillo", "flechaCrece", "alturaFlecha",
      "brilloFlecha", "marca", "marcaPantalla", "minimapaDestinos" } },
  { id = "avisos", nombre = "Avisos", desc = "Avisos de la pestaña Guía y ayudas en tooltips y vendedores.", basicas = 5,
    claves = { "avisos", "instructor", "comparador", "autoReparar", "ahorro", "avisosPlegables", "barraBuffs", "grupo", "infoContextual" } },
  { id = "efectos", nombre = "Efectos", desc = "Animaciones y celebraciones.", basicas = 3,
    claves = { "animaciones", "celebracion", "confeti", "brilloBarra", "atenuar", "tarjetaSeccion", "xpFlotante" } },
  { id = "datos", nombre = "Datos", desc = "Precios del ahorro, copiar y pasar datos, tutorial y carga.", basicas = 99,
    claves = { "pEquitacion", "pMontura", "pDoble", "copiar", "traspaso", "editor", "respaldo", "tutorial", "cargarAlAbrir" } },
}
GL.PESTANAS_AJUSTES = PESTANAS_AJUSTES
-- 9.4.2: «Básico» con lo que necesita casi todo el mundo; las 7 pestañas de antes quedan en «Avanzado».
-- Va aparte de PESTANAS_AJUSTES para que el buscador no saque cada ajuste dos veces.
local BASICO = { id = "basico", nombre = "Básico", desc = "Lo que más se usa. Todo lo demás está en Avanzado.",
  claves = { "idioma", "escala", "alphaVentana", "tamTexto", "verFlecha", "marcaPantalla", "avisos", "comparador", "instructor", "minimapa", "sonidos" } }
local listaOpciones, botonesAjustes, descAjustes = {}, {}, nil
local botonesNivel = {}   -- 9.4.2: Básico y Avanzado

local function PestanaAjustes()
  local id = DB().pestanaAjustes
  if id == nil or id == "basico" then return BASICO end
  for _, t in ipairs(PESTANAS_AJUSTES) do if t.id == id then return t end end
  return PESTANAS_AJUSTES[1]
end

-- Coloca solo los controles de la pestaña elegida (los demás se ocultan). Lo que no tenga pestaña va a General.
-- 9.0: ajustes quitados porque otra cosa de la 9.0 hace lo mismo (siguen guardados, pero no se ven)
local QUITADOS = { compacto = true, opacidad = true, avisosPlegables = true, fondoZona = true, destello = true, transicion = true, fundido = true }
GL.AJUSTES_QUITADOS = QUITADOS
local RepartirPestanas   -- 9.4.2: se usa en ColocarOpciones, se define debajo
local verMas, botonVerMas = {}, nil   -- verMas[pestaña] = true: se ven también los ajustes avanzados
local function ColocarOpciones()
  if not hijoOp then return end
  local t = PestanaAjustes()
  local enPestana, orden = {}, {}
  for _, p in ipairs(PESTANAS_AJUSTES) do for i, k in ipairs(p.claves) do enPestana[k] = p.id; orden[k] = i end end
  if t == BASICO then   -- 9.4.2: en Básico manda su propia lista, sin «Ver más ajustes»
    enPestana, orden = {}, {}
    for i, k in ipairs(BASICO.claves) do enPestana[k] = "basico"; orden[k] = i end
  end
  -- desde el buscador: si el ajuste buscado es avanzado, la pestaña se abre entera
  local buscado = DB().ajusteBuscado
  if buscado then
    if enPestana[buscado] == t.id and (orden[buscado] or 0) > (t.basicas or 99) then verMas[t.id] = true end
    DB().ajusteBuscado = nil
  end
  local mostrar, avanzados = {}, 0
  for i, ctl in ipairs(listaOpciones) do
    local k = rawget(ctl, "claveOpcion")
    local pest = (k and enPestana[k]) or (t == BASICO and "-" or "general")
    if rawget(ctl, "oculto") or (k and QUITADOS[k]) then ctl:Hide()
    elseif pest == t.id then
      local o = (k and orden[k]) or (100 + i)
      if o > (t.basicas or 99) and not verMas[t.id] then avanzados = avanzados + 1; ctl:Hide()
      else
        if o > (t.basicas or 99) then avanzados = avanzados + 1 end
        table.insert(mostrar, { ctl = ctl, o = o })
      end
    else ctl:Hide() end
  end
  table.sort(mostrar, function(a, b) return a.o < b.o end)
  local y = 0
  for _, e in ipairs(mostrar) do
    local ctl = e.ctl
    ctl:ClearAllPoints()
    if type(rawget(ctl, "altoFila")) == "number" then
      ctl:SetPoint("TOPLEFT", hijoOp, "TOPLEFT", 0, y)
      ctl:SetPoint("TOPRIGHT", hijoOp, "TOPRIGHT", 0, y)
      y = y - ctl.altoFila
    elseif rawget(ctl, "deslizador") then
      ctl:SetPoint("TOPLEFT", hijoOp, "TOPLEFT", 0, y)
      ctl:SetPoint("TOPRIGHT", hijoOp, "TOPRIGHT", 0, y)
      y = y - 32
    else
      ctl:SetPoint("TOPLEFT", hijoOp, "TOPLEFT", 0, y - 2)
      y = y - 21
    end
    ctl:Show()
  end
  if botonVerMas then
    if avanzados > 0 then
      botonVerMas:ClearAllPoints()
      botonVerMas:SetPoint("TOPLEFT", hijoOp, "TOPLEFT", 0, y - 6)
      botonVerMas.texto:SetText(verMas[t.id] and L"Ver menos" or (L"Ver más ajustes (" .. avanzados .. ")"))
      botonVerMas:Show()
      y = y - 6 - 20
    else
      botonVerMas:Hide()
    end
  end
  altoOpciones = -y + 4
  if descAjustes then descAjustes:SetText(GL.colores.GRIS .. L(t.desc) .. GL.colores.FIN) end
  for _, b in ipairs(botonesAjustes) do b:SetActivo(b.pestana == t.id) end
  if botonesNivel[1] then
    botonesNivel[1]:SetActivo(t == BASICO); botonesNivel[2]:SetActivo(t ~= BASICO)
    if GL.panelOpciones then RepartirPestanas(GL.panelOpciones) end
  end
end

-- Los botones de las pestañas reparten el ancho del panel (también al cambiar el tamaño de la ventana).
RepartirPestanas = function(p)
  local n = #botonesAjustes
  if n == 0 then return end
  local ancho = (p and p:GetWidth()) or 0
  if type(ancho) ~= "number" or ancho <= 0 then ancho = ((GL.frame and GL.frame:GetWidth()) or 430) - GL.IZQ - GL.MARGEN end
  -- 9.4.2: arriba Básico y Avanzado; las 7 pestañas, en una segunda fila solo en Avanzado
  local avanzado = PestanaAjustes() ~= BASICO
  local y = 0
  if botonesNivel[1] then
    local wn = math.floor((ancho - 3) / 2)
    for i, b in ipairs(botonesNivel) do
      b:SetWidth(math.max(30, wn))
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * (wn + 3), 0)
    end
    y = -23
  end
  -- 9.4.2: con Básico/Avanzado arriba, las 7 pestañas van en dos filas (4 y 3): en una no cabían los nombres
  local porFila = botonesNivel[1] and 4 or n
  local filas = math.ceil(n / porFila)
  for i, b in ipairs(botonesAjustes) do
    local fila = math.floor((i - 1) / porFila)
    local enFila = math.min(porFila, n - fila * porFila)
    local w = math.floor((ancho - 3 * (enFila - 1)) / enFila)
    local col = (i - 1) % porFila
    b:SetWidth(math.max(30, w))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", p, "TOPLEFT", col * (w + 3), y - fila * 23)
    GL.Mostrar(b, avanzado)
  end
  local extra = avanzado and (y - (filas - 1) * 23) or 0
  if descAjustes then descAjustes:ClearAllPoints(); descAjustes:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -26 + extra) end
  if scrollOp then
    scrollOp:ClearAllPoints()
    scrollOp:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -44 + extra)
    scrollOp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 0)
  end
  if barraOp then
    barraOp:ClearAllPoints()
    barraOp:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -44 + extra)
    barraOp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  end
end

local function RefrescarOpciones()
  for _, ctl in pairs(controles) do ctl.Actualizar() end
  if GL.panelOpciones then RepartirPestanas(GL.panelOpciones) end
  ColocarOpciones()
  AjustarScroll()
end

local function CrearScroll(p)
  scrollOp = CreateFrame("ScrollFrame", nil, p)
  scrollOp:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -44)   -- 8.9.5: encima van las pestañas de Ajustes
  scrollOp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 0)
  hijoOp = CreateFrame("Frame", nil, scrollOp)
  hijoOp:SetWidth(math.max(1, (GL.frame and GL.frame:GetWidth() or 430) - GL.IZQ - GL.MARGEN - 16))
  hijoOp:SetHeight(1)
  scrollOp:SetScrollChild(hijoOp)
  barraOp = CreateFrame("Slider", nil, p)
  barraOp:SetOrientation("VERTICAL")
  barraOp:SetWidth(10)
  barraOp:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -44)
  barraOp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  local pista = barraOp:CreateTexture(nil, "BACKGROUND")
  pista:SetPoint("TOP", barraOp, "TOP", 0, 0)
  pista:SetPoint("BOTTOM", barraOp, "BOTTOM", 0, 0)
  pista:SetWidth(4)
  pista:SetColorTexture(1, 1, 1, 0.12)
  local pulgar = barraOp:CreateTexture(nil, "OVERLAY")
  pulgar:SetWidth(8)
  pulgar:SetHeight(28)
  pulgar:SetColorTexture(0.41, 0.8, 0.94, 0.85)
  barraOp:SetThumbTexture(pulgar)
  barraOp:SetMinMaxValues(0, 0)
  barraOp:SetValueStep(1)
  barraOp:SetValue(0)
  barraOp:EnableMouse(true)
  barraOp:SetScript("OnValueChanged", function(self, v) scrollOp:SetVerticalScroll(v) end)
  scrollOp:EnableMouseWheel(true)
  scrollOp:SetScript("OnMouseWheel", function(self, delta)
    local minimo, maximo = barraOp:GetMinMaxValues()
    local v = (barraOp:GetValue() or 0) - delta * 36
    if v < minimo then v = minimo end
    if v > maximo then v = maximo end
    barraOp:SetValue(v)
  end)
  GL.Mostrar(barraOp, false)
  return hijoOp
end

local function CrearPanelOpciones()
  local frame = GL.frame
  local p = CreateFrame("Frame", nil, frame)
  -- 6.0.1: sin título ni botón Novedades; las subpestañas Ajustes y Novedades van encima
  p:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + GL.ALTO_SUB))
  p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  p:Hide()

  local db = DB()
  local lista = {}
  local h = CrearScroll(p)
  -- 8.9.5: fila de pestañas y una línea que dice qué hay en la elegida
  botonesNivel = {}
  for i, n in ipairs({ { "basico", L"Básico" }, { "avanzado", L"Avanzado" } }) do
    local b = GL.CrearBoton(p, n[2], function()
      if n[1] == "basico" then DB().pestanaAjustes = "basico"
      elseif PestanaAjustes() == BASICO then DB().pestanaAjustes = "general" end
      if barraOp then barraOp:SetValue(0) end
      ColocarOpciones(); AjustarScroll()
    end, nil, 20)
    if GL.Ayuda then GL.Ayuda(b, n[2], i == 1 and L(BASICO.desc) or L"Todos los ajustes, por temas.") end
    botonesNivel[i] = b
  end
  botonesAjustes = {}
  for _, t in ipairs(PESTANAS_AJUSTES) do
    local b = GL.CrearBoton(p, t.nombre, function()
      DB().pestanaAjustes = t.id
      if barraOp then barraOp:SetValue(0) end
      ColocarOpciones(); AjustarScroll()
    end, nil, 20)
    b.pestana = t.id
    if GL.Ayuda then GL.Ayuda(b, L(t.nombre), L(t.desc)) end
    table.insert(botonesAjustes, b)
  end
  RepartirPestanas(p)
  botonVerMas = GL.CrearBoton(h, L"Ver más ajustes", function()
    local id = PestanaAjustes().id
    verMas[id] = not verMas[id]
    ColocarOpciones(); AjustarScroll()
  end, nil, 20)
  botonVerMas:SetWidth(170)
  if GL.Ayuda then GL.Ayuda(botonVerMas, L"Ver más ajustes", L"Arriba van los ajustes que más se usan. Aquí salen los demás de esta pestaña.") end
  descAjustes = GL.Texto(p, "GameFontHighlightSmall")
  descAjustes:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -26)
  controles.escala = CrearDeslizador(h, L"Tamaño de la ventana", 0.6, 1.5, 0.05,
    function() return DB().escala or 1 end,
    function(v) DB().escala = v; Aplicar() end)
  controles.opacidad = CrearDeslizador(h, L"Opacidad del fondo", 0.2, 1, 0.05,
    function() return DB().opacidad or GL.COLOR.fondo[4] end,
    function(v) DB().opacidad = v; Aplicar() end)
  controles.alphaVentana = CrearDeslizador(h, L"Transparencia de la ventana", 0.3, 1, 0.05,   -- 9.0
    function() return DB().alphaVentana or 1 end,
    function(v) DB().alphaVentana = v; if GL.AplicarTransparencia then GL.AplicarTransparencia() end end,
    function(v) return math.floor(v * 100 + 0.5) .. " %" end)
  table.insert(lista, controles.alphaVentana)
  controles.flecha = CrearDeslizador(h, L"Tamaño de la flecha", 0.6, 2, 0.1,
    function() return DB().escalaFlecha or 1 end,
    function(v) DB().escalaFlecha = v; Aplicar() end)
  controles.tamTexto = CrearDeslizador(h, L"Tamaño del texto del paso", 0.8, 1.5, 0.05,
    function() return DB().tamTexto or 1 end,
    function(v) DB().tamTexto = v; if GL.AplicarTamTexto then GL.AplicarTamTexto() end end)
  -- 7.3: el tutorial sale al conectar con todos los personajes hasta que se quite esta marca (guardado en la cuenta)
  controles.tutorial = CrearCasilla(h, L"Mostrar el tutorial al conectar (toda la cuenta)",
    L"Quita la marca para no verlo más con ningún personaje de esta cuenta. Con /ga tutorial se puede ver igual.",
    function() return not (type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.tutorial == false) end,
    function(v) if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end; GuiaAventureroCuenta.tutorial = v end)
  table.insert(lista, controles.tutorial)
  controles.tema = CrearTemas(h)
  table.insert(lista, controles.tema)
  controles.copiar = CrearCopiar(h)   -- 7.5.4
  table.insert(lista, controles.copiar)
  if GL.CrearTraspaso then   -- 7.5.13
    controles.traspaso = GL.CrearTraspaso(h)
    table.insert(lista, controles.traspaso)
  end
  if GL.CrearFilaEditor then   -- 9.1: Editor de rutas
    controles.editor = GL.CrearFilaEditor(h)
    table.insert(lista, controles.editor)
  end
  if GL.CrearFilaRespaldo then   -- 9.1: copia de seguridad
    controles.respaldo = GL.CrearFilaRespaldo(h)
    table.insert(lista, controles.respaldo)
  end
  if GL.CrearEstiloRuta then   -- 7.6
    controles.estiloRuta = GL.CrearEstiloRuta(h)
    table.insert(lista, controles.estiloRuta)
  end
  if GL.OpcionesGraficos then   -- 8.8: Aspecto (Graficos.lua)
    local okG, extra = pcall(GL.OpcionesGraficos, h, CrearCasilla, CrearSelector)
    if okG and type(extra) == "table" then
      for i, ctl in ipairs(extra) do
        controles["grafico" .. i] = ctl
        table.insert(lista, ctl)
      end
    elseif not okG and GL.erroresCarga then
      table.insert(GL.erroresCarga, L"opciones de aspecto: " .. tostring(extra))
    end
  end
  table.insert(lista, controles.escala)
  table.insert(lista, controles.opacidad)
  table.insert(lista, controles.flecha)
  table.insert(lista, controles.tamTexto)
  -- 7.5.1: precios del ahorro (para toda la cuenta). 7.9.3: Equitación 100 o en Forever, con la primera montura (montura 0).
  local function Precio(k, def)
    return function() local c = type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.precios; return (type(c) == "table" and tonumber(c[k])) or def end,
      function(v) if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
        if type(GuiaAventureroCuenta.precios) ~= "table" then GuiaAventureroCuenta.precios = {} end; GuiaAventureroCuenta.precios[k] = v
        if GL.Refrescar then GL.Refrescar() end end
  end
  local function Oro(v) return math.floor(v + 0.5) .. " o" end
  local l1, e1 = Precio("equitacion", 100)
  controles.pEquitacion = CrearDeslizador(h, L"Ahorro: precio de la equitación", 0, 200, 1, l1, e1, Oro)
  local l2, e2 = Precio("montura", 0)
  controles.pMontura = CrearDeslizador(h, L"Ahorro: precio de la montura", 0, 200, 1, l2, e2, Oro)
  local l3, e3 = Precio("doble", 10)
  controles.pDoble = CrearDeslizador(h, L"Ahorro: precio de la doble especialización", 0, 100, 1, l3, e3, Oro)
  table.insert(lista, controles.pEquitacion)
  table.insert(lista, controles.pMontura)
  table.insert(lista, controles.pDoble)

  local casillas = {
    { "alphaRaton", L"Ventana opaca al pasar el ratón", L"Con la ventana transparente, se ve entera mientras tienes el ratón encima.",
      function() return DB().alphaRaton ~= false end, function(v) DB().alphaRaton = v; if GL.AplicarTransparencia then GL.AplicarTransparencia() end end },
    { "bloqueada", L"Bloquear ventanas y flecha", L"No se mueven ni cambian de tamaño al arrastrarlas.",
      function() return DB().bloqueada end, function(v) DB().bloqueada = v end },
    { "verFlecha", L"Mostrar la flecha", L"La flecha que te lleva al destino del paso.",
      function() return GL.flecha and GL.flecha:IsShown() end,
      function(v) if (GL.flecha:IsShown() and true or false) ~= v then GL.AlternarFlecha() end end },
    { "recompensa", L"Recomendar la recompensa", L"Marca la recompensa que mejora tu equipo o la que más vale.",
      function() return DB().recompensa ~= false end, function(v) DB().recompensa = v end },
    { "instructor", L"Ayuda en los instructores",
      L"En el de clase, qué hechizos comprar por orden de prioridad y cuáles saltarte; en el de profesión, las recetas que usa la guía.",
      function() return DB().instructor ~= false end, function(v) DB().instructor = v end },
    { "marca", L"Punto de ruta del juego en el destino",
      L"Pone la marca del juego (mapa, minimapa y en pantalla) en el destino de la flecha.",
      function() return DB().marcaMapa ~= false end,
      function(v) DB().marcaMapa = v; if GL.ActualizarMarca then GL.ActualizarMarca(true) end end },
    { "marcaPantalla", L"Marcador en pantalla (como en retail)",
      L"Un rombo sobre el mundo con la distancia al destino de la flecha. Usa el punto de ruta del juego.",
      function() return DB().marcaPantalla ~= false end,
      function(v) DB().marcaPantalla = v; if v then DB().marcaMapa = true end
        if GL.AplicarMarcaPantalla then GL.AplicarMarcaPantalla(true) end
        if GL.ActualizarMarca then GL.ActualizarMarca(true) end end },
    { "modoPesca", L"Modo pesca (botón en pantalla)",
      L"Si llevas caña, un botón que te la pone, baja la música y lanza. Otro clic cuando pica saca el pez. Tus armas y tus volúmenes vuelven solos.",
      function() return DB().modoPesca ~= false end,
      function(v) DB().modoPesca = v; if not v and GL.DevolverPesca then GL.DevolverPesca() end
        if GL.ActualizarPesca then GL.ActualizarPesca() end end },
    { "rangosBarras", L"Rangos nuevos en las barras",
      L"Al aprender un rango nuevo de un hechizo que tienes en las barras, te pregunta si cambias los botones por el nuevo. /ga rangos lo busca cuando quieras.",
      function() return DB().rangosBarras ~= false end,
      function(v) DB().rangosBarras = v end },
    { "rangosAuto", L"Poner los rangos nuevos sin preguntar",
      L"Cambia solo los botones de las barras al rango nuevo, sin el aviso (fuera de combate).",
      function() return DB().rangosAuto == true end,
      function(v) DB().rangosAuto = v; if v then DB().rangosBarras = true end end },
    { "guiaClara", L"Guía clara (Coger, Hacer, Entregar)",
      L"Cada misión del paso en una tarjeta con lo que hay que coger, hacer y entregar. Apagado: la caja del paso de antes, con Siguiente, Cerca de ti y Después.",
      function() return DB().guiaClara ~= false end,
      function(v) DB().guiaClara = v; if GL.Refrescar then GL.Refrescar() end end },
    { "pines", L"Destinos del paso en el mapa del mundo", L"Iconos de recoger, objetivo y entregar en el mapa.",
      function() return DB().pinesMapa ~= false end,
      function(v) DB().pinesMapa = v; if GL.ActualizarPines then GL.ActualizarPines() end end },
    { "minimapa", L"Botón en el minimapa", L"Clic: mostrar u ocultar la guía. Clic derecho: opciones.",
      function() return DB().minimapa ~= false end,
      function(v) DB().minimapa = v; if boton then GL.Mostrar(boton, v) end end },
    { "destello", L"Destello al cambiar de paso", L"La caja del paso brilla un momento cuando pasas a otro paso.",
      function() return DB().destello ~= false end, function(v) DB().destello = v end },
    { "compacto", L"Modo compacto", L"Una ventana pequeña con el paso actual y el destino.",
      function() return DB().compacto end,
      function(v) if v then GL.EntrarCompacto() else GL.SalirCompacto() end end },
    { "discretoCombate", L"Modo discreto durante el combate", L"Oculta la ventana principal y la flecha mientras estás en combate. Al terminar, restaura solo lo que estaba visible. No modifica la ruta ni el progreso.",
      function() return DB().discretoCombate == true end,
      function(v) DB().discretoCombate = v; if v and InCombatLockdown and InCombatLockdown() and GL.ModoDiscretoCombate then GL.ModoDiscretoCombate(true) end end },
    { "comparador", L"Comparador de equipo en los tooltips", L"En las piezas que puedes equiparte: diferencia de estadísticas con lo que llevas en esa ranura y si es mejor o peor según lo que busca la guía para tu clase.",
      function() return DB().comparador ~= false end, function(v) DB().comparador = v end },
    { "autoReparar", L"Reparar solo en el vendedor", L"Al abrir un vendedor que repara, arregla todo tu equipo con tu oro. Shift al abrirlo: no repara.",
      function() return DB().autoReparar ~= false end, function(v) DB().autoReparar = v end },
    { "avisos", L"Avisos de equipo, bolsas y comida", L"En la pestaña Guía: pieza a punto de romperse, pocos huecos en las bolsas (con qué tirar), objetos de misión que ya no usas y poca comida o agua.",
      function() return DB().avisos ~= false end, function(v) DB().avisos = v; if GL.Refrescar then GL.Refrescar() end end },
    { "grupo", L"Compartir tu paso con el grupo", L"Con compañeros de grupo que lleven la guía: ves en qué paso va cada uno y qué misiones podéis compartir.",
      function() return DB().grupo ~= false end, function(v) DB().grupo = v; if GL.Refrescar then GL.Refrescar() end end },
    { "retrato", L"Retrato del PNJ en el paso", L"El PNJ al que vas, en la caja del paso. Clic en el retrato: lo selecciona si está cerca.",
      function() return DB().retrato ~= false end, function(v) DB().retrato = v; if GL.Refrescar then GL.Refrescar() end end },
    { "celebracion", L"Celebración al subir de nivel", L"Al subir de nivel o acabar una sección: un resumen y los hechizos nuevos con su icono y su precio.",
      function() return DB().celebracion ~= false end, function(v) DB().celebracion = v end },
    { "minimapaDestinos", L"Destinos del paso en el minimapa", L"Los iconos de recoger, objetivo y entregar también en el minimapa.",
      function() return DB().minimapaDestinos ~= false end, function(v) DB().minimapaDestinos = v end },
    { "bienvenida", L"Bienvenida al conectar", L"La ventana con dónde lo dejaste y cuánto te falta para el siguiente nivel. Vale para todos tus personajes (también se quita con «No volver a mostrar» en la propia ventana).",
      function() return DB().bienvenida ~= false and not (type(GuiaAventureroCuenta) == "table" and GuiaAventureroCuenta.bienvenida == false) end,
      function(v)
        if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
        GuiaAventureroCuenta.bienvenida = v; DB().bienvenida = v
      end },
    { "flechaColor", L"Flecha de colores según la distancia", L"Verde cerca, amarilla a media distancia y roja lejos. Apagado: siempre del mismo color.",
      function() return DB().flechaColor ~= false end, function(v) DB().flechaColor = v end },
    { "autoSeguimiento", L"Seguir las misiones del paso", L"Pone en el seguimiento de misiones las del paso actual y quita las que puso el addon al cambiar de paso.",
      function() return DB().autoSeguimiento ~= false end, function(v) DB().autoSeguimiento = v; if GL.ActualizarSeguimiento976 then pcall(GL.ActualizarSeguimiento976) end end },
    { "sonidos", L"Sonidos", L"Suena al llegar a un destino, al completar los objetivos de una misión y al pasar de paso.",
      function() return DB().sonidos == true end, function(v) DB().sonidos = v end },
    { "barraBuffs", L"Buffs y mascota en pantalla", L"Iconos debajo de la flecha con los buffs que te faltan (en grupo, cuántos lo tienen) y el estado de tu mascota o demonio.",
      function() return DB().barraBuffs ~= false end, function(v) DB().barraBuffs = v end },
    { "ahorro", L"Ahorro para el nivel 40", L"Desde el nivel 1, en Guía > Avisos: el oro para equitación (con la primera montura) y doble especialización.",
      function() return DB().ahorro ~= false end, function(v) DB().ahorro = v; if GL.Refrescar then GL.Refrescar() end end },
    { "infoContextual", L"Información contextual en objetos", L"Añade al tooltip de los objetos su nivel, nivel requerido, tipo y valor de venta cuando el cliente proporciona esos datos. Solo informa: no vende ni modifica objetos.",
      function() return DB().infoContextual ~= false end, function(v) DB().infoContextual = v end },
  }
  -- 9.0: ajustes que añaden otros archivos (Interfaz.lua y demás), cada uno en su pestaña
  for _, c in ipairs(GL.ajustesInterfaz or {}) do
    table.insert(casillas, c)
    local dentro = false
    for _, t in ipairs(PESTANAS_AJUSTES) do for _, k in ipairs(t.claves) do if k == c[1] then dentro = true end end end
    if not dentro and c.pestana then
      for _, t in ipairs(PESTANAS_AJUSTES) do if t.id == c.pestana then table.insert(t.claves, c[1]) end end
    end
  end
  for i = 1, #casillas do
    local c = casillas[i]
    if c.opciones then   -- 9.0: ajuste de elegir entre varios valores
      controles[c[1]] = CrearSelector(h, c[2], c.opciones, c[4], c[5])
    else
      controles[c[1]] = CrearCasilla(h, L(c[2]), L(c[3]), c[4], c[5])
    end
    table.insert(lista, controles[c[1]])
  end

  -- 8.9.5: cada control sabe su clave para ir a su pestaña
  local claves = { escala = controles.escala, opacidad = controles.opacidad, alphaVentana = controles.alphaVentana, flecha = controles.flecha, tamTexto = controles.tamTexto,
    tutorial = controles.tutorial, tema = controles.tema, copiar = controles.copiar, traspaso = controles.traspaso, editor = controles.editor, respaldo = controles.respaldo,
    estiloRuta = controles.estiloRuta, pEquitacion = controles.pEquitacion, pMontura = controles.pMontura, pDoble = controles.pDoble }
  for i = 1, #casillas do claves[casillas[i][1]] = controles[casillas[i][1]] end
  for k, ctl in pairs(claves) do if type(ctl) == "table" then ctl.claveOpcion = k end end
  listaOpciones = lista
  if p.HookScript then p:HookScript("OnSizeChanged", function() RepartirPestanas(p) end) end
  ColocarOpciones()
  GL.modos.opciones = { panel = p, refrescar = RefrescarOpciones }
  GL.EtiquetaAjuste = function(k)   -- 9.0: el buscador
    local c = controles[k]
    if type(c) ~= "table" then return nil end
    if rawget(c, "etiqueta") then return c.etiqueta end
    local t = rawget(c, "texto")
    if t and t.GetText then local ok, x = pcall(t.GetText, t); if ok and type(x) == "string" and x ~= "" then return x end end
    return nil
  end
  GL.panelOpciones = p
end

------------------------------------------------------------------------
-- Automatismos (6.0.2): lo que la guía hace sola, cada uno con su descripción a la vista y su estado
------------------------------------------------------------------------
local AUTOS = {
  { "Pasos", {
    { "auto", "Avance automático de pasos", "Pasa solo los pasos cuyas misiones ya tienes hechas." },
    { "autoDestino", "Siguiente destino al llegar", "Al llegar a un destino del paso, la flecha pasa sola al siguiente." },
  } },
  { "Misiones", {
    { "autoMisiones", "Aceptar y entregar las misiones de la guía", "Solo las de la ruta. Mayús al hablar con el PNJ para hacerlo a mano." },
  } },
  { "Instructores", {
    { "autoHechizos", "Aprender los hechizos recomendados", "Compra los marcados con Compra, lo más importante primero. Mayús al abrirlo para no hacerlo." },
    { "autoRecetas", "Aprender las recetas de la guía", "En el instructor de profesión: el rango nuevo y las recetas que usa la guía." },
  } },
  { "Vendedor", {
    { "autoVender", "Vender lo gris", "Al abrir un vendedor, vende los objetos grises y te dice cuánto has ganado. Mayús al abrirlo para no hacerlo." },
  } },
  { "Talentos", {
    { "autoTalentos", "Poner los talentos de la guía al subir de nivel", "Sigue el plan de Personaje > Talentos. Nunca quita puntos." },
  } },
}

local filasAuto, cuentaAuto, modoAuto = {}, nil, nil

local function Encendido(k) return DB()[k] ~= false end

local function PonerAuto(k, v)
  if k == "auto" then
    if Encendido("auto") ~= v then GL.AlternarAuto() end   -- avisa en el chat y sincroniza como /ga auto
  else
    DB()[k] = v
  end
end

local function RefrescarAutomatismos()
  local n = 0
  for i = 1, #filasAuto do
    local f = filasAuto[i]
    local on = Encendido(f.clave)
    if on then n = n + 1 end
    f.estado.texto:SetText(on and L"Encendido" or L"Apagado")
    f.estado:SetActivo(on)
    if not on then f.estado.texto:SetTextColor(GL.COLOR.gris[1], GL.COLOR.gris[2], GL.COLOR.gris[3]) end
  end
  cuentaAuto:SetText(L"Encendidos: " .. GL.colores.AMARILLO .. n .. L" de " .. #filasAuto .. GL.colores.FIN)
  -- 9.6: el interruptor de arriba, como en el tutorial
  if modoAuto then
    local a, b, c = Encendido("auto"), Encendido("autoDestino"), Encendido("autoTalentos")
    local todo, nada = a and b and c, not a and not b and not c
    modoAuto.auto:SetActivo(todo); modoAuto.mano:SetActivo(nada)
    modoAuto.texto:SetText(todo and L"La guía avanza sola, mueve la flecha al llegar y pone tus talentos al subir de nivel."
      or nada and L"Tú pulsas «Saltar paso», eliges adónde va la flecha y pones los talentos."
      or L"A tu medida: tienes unos encendidos y otros no. Cámbialos uno a uno aquí debajo.")
  end
end

local function CrearPanelAutomatismos()
  local frame = GL.frame
  local p = CreateFrame("Frame", nil, frame)
  p:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + GL.ALTO_SUB))
  p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  p:Hide()
  if p.SetClipsChildren then p:SetClipsChildren(true) end   -- con la ventana muy baja, no se sale por el pie
  -- 9.6: arriba, Automático o Lo hago yo (lo mismo que se elige en el tutorial)
  local function Modo(v)
    for _, k in ipairs({ "auto", "autoDestino", "autoTalentos" }) do PonerAuto(k, v) end
    if GL.ProgramarSync then GL.ProgramarSync() end
    RefrescarAutomatismos()
  end
  modoAuto = {}
  modoAuto.auto = GL.CrearBoton(p, L"Automático", function() Modo(true) end, nil, 22)
  modoAuto.mano = GL.CrearBoton(p, L"Lo hago yo", function() Modo(false) end, nil, 22)
  modoAuto.auto:SetWidth(120); modoAuto.mano:SetWidth(120)
  modoAuto.auto:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  modoAuto.mano:SetPoint("LEFT", modoAuto.auto, "RIGHT", 6, 0)
  GL.Ayuda(modoAuto.auto, L"Automático", L"La guía avanza y pone los talentos")
  GL.Ayuda(modoAuto.mano, L"Lo hago yo", L"Tú avanzas y pones los talentos")
  modoAuto.texto = GL.Texto(p, "GameFontDisableSmall")
  modoAuto.texto:SetPoint("TOPLEFT", modoAuto.auto, "BOTTOMLEFT", 0, -5)
  modoAuto.texto:SetPoint("RIGHT", p, "RIGHT", 0, 0)
  cuentaAuto = GL.Texto(p, "GameFontHighlightSmall")
  cuentaAuto:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -56)
  cuentaAuto:SetPoint("RIGHT", p, "RIGHT", -104, 0); GL.UnaLinea(cuentaAuto)   -- 7.6.1: dentro del marco
  local apagar = GL.CrearBoton(p, L"Apagar todos", function()
    for i = 1, #filasAuto do PonerAuto(filasAuto[i].clave, false) end
    RefrescarAutomatismos()
  end, nil, 20)
  apagar:SetWidth(96)
  apagar:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -52)
  GL.Ayuda(apagar, L"Apagar todos", L"Apaga todos los automatismos de este personaje. Luego enciendes los que quieras.")

  local y = -80
  for _, grupo in ipairs(AUTOS) do
    local t = GL.Texto(p, "GameFontNormal")
    t:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y)
    t:SetText(L(grupo[1]))
    local linea = p:CreateTexture(nil, "ARTWORK")
    linea:SetHeight(1)
    linea:SetColorTexture(1, 1, 1, 0.08)
    linea:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -3)
    linea:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    y = y - 20
    for _, a in ipairs(grupo[2]) do
      local f = { clave = a[1] }
      f.estado = GL.CrearBoton(p, "", function()
        PonerAuto(f.clave, not Encendido(f.clave))
        RefrescarAutomatismos()
      end, nil, 18)
      f.estado:SetWidth(74)
      f.estado:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, y)
      GL.Ayuda(f.estado, L(a[2]), L(a[3]))
      f.nombre = GL.Texto(p, "GameFontHighlight")
      f.nombre:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y - 1)
      f.nombre:SetPoint("RIGHT", f.estado, "LEFT", -8, 0)
      GL.UnaLinea(f.nombre)
      f.nombre:SetText(L(a[2]))
      f.desc = GL.Texto(p, "GameFontDisableSmall")
      f.desc:SetPoint("TOPLEFT", f.nombre, "BOTTOMLEFT", 0, -2)
      f.desc:SetPoint("RIGHT", f.estado, "LEFT", -8, 0)
      f.desc:SetText(L(a[3]))
      local lineas = math.max(1, math.ceil(string.len(L(a[3])) / 58))   -- estimado: el alto real no se sabe hasta mostrarlo
      y = y - 18 - lineas * 12 - 6
      table.insert(filasAuto, f)
    end
  end
  GL.modos.automatismos = { panel = p, refrescar = RefrescarAutomatismos }
end

function GL.AbrirAutomatismos()
  local db = DB()
  if db.compacto then GL.SalirCompacto() end
  if GL.frame then GL.frame:Show(); db.oculto = false end
  GL.AbrirModo("automatismos")
end

function GL.AbrirOpciones()
  local db = DB()
  if db.compacto then GL.SalirCompacto() end
  if GL.frame then GL.frame:Show(); db.oculto = false end
  GL.AbrirModo("opciones")
end

-- 7.3: abre Ajustes y resalta una opción (marco del color del aviso que parpadea unos segundos)
local resalte = nil
function GL.ResaltarAjuste(clave)
  GL.AbrirOpciones()
  local c = controles[clave]
  if not c then return end
  if scrollOp then scrollOp:SetVerticalScroll(0); if barraOp then barraOp:SetValue(0) end end
  if not resalte then
    resalte = CreateFrame("Frame", nil, hijoOp, PLANTILLA)
    GL.Caja(resalte, { 1, 0.82, 0, 0.12 }, { 1, 0.82, 0, 1 })
    resalte:SetScript("OnUpdate", function(self, dt)
      self.t = (self.t or 0) + dt
      if self.t > 5 then self:Hide(); return end
      self:SetAlpha(0.55 + 0.45 * math.abs(math.cos(self.t * 3)))
    end)
  end
  resalte:ClearAllPoints()
  resalte:SetPoint("TOPLEFT", c, "TOPLEFT", -4, 4)
  resalte:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", -4, -4)
  resalte:SetPoint("RIGHT", hijoOp, "RIGHT", 0, 0)
  resalte:SetFrameLevel(math.max(0, (c:GetFrameLevel() or 1) - 1))
  resalte.t = 0
  resalte:SetAlpha(1)
  resalte:Show()
end

------------------------------------------------------------------------
-- Botones de la cabecera: modo compacto y opciones (junto al de la flecha)
------------------------------------------------------------------------
local function BotonCabecera(icono, x, funcion, titulo, ayuda)
  -- 9.0: van abajo en la barra lateral (x: -70 el de tamaño, -100 el de opciones)
  if GL.BotonLateral then
    local b = GL.BotonLateral(nil, titulo, icono, ayuda, funcion)
    b:SetPoint("BOTTOMLEFT", GL.frame, "BOTTOMLEFT", (GL.RAIL - 36) / 2, x == -100 and 8 or 42)
    return b
  end
  local b = GL.CrearBoton(GL.frame, "", funcion, nil, 26)
  b:SetWidth(26)
  b:SetPoint("TOPRIGHT", GL.frame, "TOPRIGHT", x, -12)
  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  GL.PonerIcono(t, icono)
  GL.Ayuda(b, titulo, ayuda)
  return b
end

------------------------------------------------------------------------
-- Botón del minimapa
------------------------------------------------------------------------
local function ColocarBoton()
  local angulo = math.rad(DB().anguloMinimapa or 200)
  local radio = (Minimap:GetWidth() or 140) / 2 + 8
  boton:ClearAllPoints()
  boton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angulo) * radio, math.sin(angulo) * radio)
end

local function CrearBotonMinimapa()
  if not Minimap then return end
  boton = CreateFrame("Button", "GuiaAventureroBotonMinimapa", Minimap)
  boton:SetWidth(31)
  boton:SetHeight(31)
  boton:SetFrameStrata("MEDIUM")
  boton:SetFrameLevel(8)
  boton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  boton:RegisterForDrag("LeftButton")
  boton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local fondo = boton:CreateTexture(nil, "BACKGROUND")
  fondo:SetWidth(20)
  fondo:SetHeight(20)
  fondo:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  fondo:SetPoint("TOPLEFT", boton, "TOPLEFT", 7, -5)
  local icono = boton:CreateTexture(nil, "ARTWORK")
  icono:SetWidth(18)
  icono:SetHeight(18)
  icono:SetPoint("TOPLEFT", boton, "TOPLEFT", 7, -6)
  GL.PonerIcono(icono, GL.RUTA.icono)
  local borde = boton:CreateTexture(nil, "OVERLAY")
  borde:SetWidth(53)
  borde:SetHeight(53)
  borde:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  borde:SetPoint("TOPLEFT", boton, "TOPLEFT", 0, 0)

  boton:SetScript("OnClick", function(self, raton)
    if raton == "RightButton" then GL.AbrirOpciones() else GL.AlternarVentana() end
  end)
  boton:SetScript("OnDragStart", function(self)
    if DB().bloqueada then return end
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local escala = Minimap:GetEffectiveScale()
      px, py = px / escala, py / escala
      DB().anguloMinimapa = math.deg(math.atan2(py - my, px - mx)) % 360
      ColocarBoton()
    end)
  end)
  boton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  boton:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L"Guía del Aventurero", 1, 0.82, 0)
    local s = GL.PasoActual()
    if s then GameTooltip:AddLine(s.titulo .. L" · paso " .. DB().paso .. "/" .. #s.pasos, 1, 1, 1) end
    GameTooltip:AddLine(L"Clic: mostrar u ocultar la guía", 0.62, 0.62, 0.62)
    GameTooltip:AddLine(L"Clic derecho: opciones", 0.62, 0.62, 0.62)
    GameTooltip:AddLine(L"Arrastra para moverlo alrededor del minimapa", 0.62, 0.62, 0.62)
    GameTooltip:Show()
  end)
  boton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  ColocarBoton()
  GL.Mostrar(boton, DB().minimapa ~= false)
end

-- Botón de la lista de addons del minimapa (cliente moderno): lo pide el .toc con AddonCompartmentFunc.
function GuiaAventurero_Compartimento(_, raton)
  if not GL.frame then return end
  if raton == "RightButton" then GL.AbrirOpciones() else GL.AlternarVentana() end
end

-- Entrada en Opciones > AddOns del juego, que explica dónde están las opciones.
local function RegistrarEnAjustes()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
  local panel = CreateFrame("Frame")
  local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  t:SetText(L"Guía del Aventurero")
  local d = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
  d:SetWidth(520)
  d:SetJustifyH("LEFT")
  d:SetText(L"Las opciones están en la propia ventana de la guía: botón de la rueda dentada, clic derecho en el " ..
    L"botón del minimapa.\n\n" .. GL.AUTOR)
  local ok, abrir = pcall(CreateFrame, "Button", nil, panel, "UIPanelButtonTemplate")
  if ok and abrir then
    abrir:SetWidth(200)
    abrir:SetHeight(24)
    abrir:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -16)
    abrir:SetText(L"Abrir las opciones de la guía")
    abrir:SetScript("OnClick", function()
      if SettingsPanel and HideUIPanel then pcall(HideUIPanel, SettingsPanel) end
      GL.AbrirOpciones()
    end)
  end
  local ok2, categoria = pcall(Settings.RegisterCanvasLayoutCategory, panel, L"Guía del Aventurero")
  if ok2 and categoria then pcall(Settings.RegisterAddOnCategory, categoria) end
end

------------------------------------------------------------------------
-- Inicio, refresco y comandos
------------------------------------------------------------------------
table.insert(GL.alIniciar, function()
  local db = DB()
  CrearCompacto()
  CrearPanelOpciones()
  CrearPanelAutomatismos()
  GL.ui.botonCompacto = BotonCabecera(ICONO_COMPACTO, -70, function() GL.EntrarCompacto() end,
    L"Modo compacto", L"Una ventana pequeña con el paso actual y el destino.")
  GL.ui.botonOpciones = BotonCabecera(ICONO_OPCIONES, -100, function()
    if db.modo == "opciones" or db.modo == "automatismos" or db.modo == "novedades" then GL.AbrirModo("guia") else GL.AbrirModo("opciones") end
  end, L"Opciones", L"Tamaño, transparencia, misiones automáticas, mapa y más.")
  CrearBotonMinimapa()
  pcall(RegistrarEnAjustes)
  Aplicar()
  if db.compacto then
    GL.frame:Hide()
    if not db.ocultoCompacto then compacto:Show() end
  end
end)

table.insert(GL.trasRefrescar, function()
  RefrescarCompacto()
  if GL.ui.botonOpciones then GL.ui.botonOpciones:SetActivo(DB().modo == "opciones") end
end)

table.insert(GL.alReiniciar, function()
  local db = DB()
  db.escala, db.opacidad, db.escalaFlecha, db.posCompacto, db.anguloMinimapa = nil, nil, nil, nil, nil
  db.tamTexto = nil
  if GL.AplicarTamTexto then GL.AplicarTamTexto() end
  if db.compacto then GL.SalirCompacto() end
  if compacto then
    compacto:ClearAllPoints()
    compacto:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -200)
  end
  if boton then ColocarBoton() end
  Aplicar()
end)

GL.comandos["opciones"] = function() GL.AbrirOpciones() end
GL.comandos["compacto"] = function()
  if DB().compacto then GL.SalirCompacto() else GL.EntrarCompacto() end
end
GL.comandos["minimapa"] = function()
  local db = DB()
  db.minimapa = (db.minimapa == false)
  if boton then GL.Mostrar(boton, db.minimapa) end
  GL.Mensaje(L"botón del minimapa " .. (db.minimapa and L"visible." or L"oculto."))
end

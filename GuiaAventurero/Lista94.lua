-- Lista94.lua (9.4): lista con filas de texto y un botón por fila (Llevarme, Elegir...), con pestañas y rueda del
-- ratón. La usan Misiones de clase, Bandas, Vuelos por descubrir, Dónde ganar oro y Especialización.
-- GL.CrearLista(padre) pone la lista en un marco; GL.VentanaLista(clave, titulo) la pone en una ventana propia.
-- Cada fila: { texto = "...", detalle = "...", boton = "Llevarme", accion = function() end, destino = {m, x, y, n},
-- hecha = true, titulo = true, boton2 = "Mapa", accion2 = function(d) end }. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local ALTO_FILA = 30

-- Datos94.lua y DatosBandas94.lua: nombres y textos en inglés si la guía o el cliente lo están (Idioma.lua)
table.insert(GL.alIniciar, 1, function()
  if not (GL.TraducirDatos and GL.D94) then return end
  for _, b in ipairs(GL.D94.bandas or {}) do b.clave = b.clave or b.n end   -- la clave de sus jefes sigue en español
  GL.TraducirDatos(GL.D94)
end)

local function Seguir(d) if d and GL.SeguirDesvio then GL.SeguirDesvio(d) end end

function GL.CrearLista(padre, arriba)
  local lista = CreateFrame("Frame", nil, padre)
  lista:SetPoint("TOPLEFT", padre, "TOPLEFT", 0, -(arriba or 0))
  lista:SetPoint("BOTTOMRIGHT", padre, "BOTTOMRIGHT", 0, 0)
  lista.filas, lista.datos, lista.desde = {}, {}, 0
  lista.cab = GL.Texto(lista, "GameFontHighlightSmall")
  lista.cab:SetPoint("TOPLEFT", lista, "TOPLEFT", 0, 0)
  lista.cab:SetPoint("RIGHT", lista, "RIGHT", 0, 0)
  if lista.cab.SetSpacing then lista.cab:SetSpacing(2) end
  lista.pie = GL.Texto(lista, "GameFontHighlightSmall")
  lista.pie:SetPoint("BOTTOMLEFT", lista, "BOTTOMLEFT", 0, 0)

  local function Fila(i)
    local f = lista.filas[i]
    if f then return f end
    f = CreateFrame("Button", nil, lista)
    f:SetHeight(ALTO_FILA)
    local brillo = f:CreateTexture(nil, "HIGHLIGHT")
    brillo:SetAllPoints()
    brillo:SetColorTexture(1, 1, 1, 0.05)
    f.fondo = f:CreateTexture(nil, "BACKGROUND")
    f.fondo:SetAllPoints()
    f.fondo:SetColorTexture(1, 0.82, 0, 0.08)
    f.marca = f:CreateTexture(nil, "ARTWORK")
    f.marca:SetWidth(12); f.marca:SetHeight(12)
    f.marca:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -3)
    f.marca:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    f.boton = GL.CrearBoton(f, L"Llevarme", function(self)
      local d = self:GetParent().dato
      if d and d.accion then d.accion(d) elseif d then Seguir(d.destino) end
    end, nil, 18, "accion")
    f.boton:SetWidth(76)
    f.boton:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
    f.boton2 = GL.CrearBoton(f, L"Mapa", function(self)   -- segundo botón opcional (boton2, accion2)
      local d = self:GetParent().dato
      if d and d.accion2 then d.accion2(d) end
    end, nil, 18)
    f.boton2:SetWidth(56)
    f.boton2.texto:SetJustifyH("CENTER")
    f.boton2:SetPoint("RIGHT", f.boton, "LEFT", -4, 0)
    f.texto = GL.Texto(f, "GameFontHighlightSmall")
    f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -2)
    f.texto:SetPoint("RIGHT", f.boton, "LEFT", -4, 0)
    f.detalle = GL.Texto(f, "GameFontHighlightSmall")
    f.detalle:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -15)
    f.detalle:SetPoint("RIGHT", f.boton, "LEFT", -4, 0)
    if GL.UnaLinea then GL.UnaLinea(f.texto); GL.UnaLinea(f.detalle) end
    f:SetScript("OnClick", function(self)
      local d = self.dato
      if d and d.alPulsar then d.alPulsar(d) elseif d and d.destino then Seguir(d.destino) end
    end)
    if GL.Ayuda then GL.Ayuda(f) end
    -- 9.4.2: icono opcional a la izquierda (d.icono) y, si es un objeto (d.objeto), su tooltip del juego
    f.icono = f:CreateTexture(nil, "ARTWORK")
    f.icono:SetSize(24, 24)
    f.icono:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    f.icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.icono:Hide()
    local ayuda = f:GetScript("OnEnter")
    f:SetScript("OnEnter", function(self)
      if self.objeto and GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.objeto) else GameTooltip:SetHyperlink("item:" .. self.objeto) end
        GameTooltip:Show()
      elseif ayuda then ayuda(self) end
    end)
    lista.filas[i] = f
    return f
  end

  function lista:Pintar()
    local alto = self:GetHeight() or 300
    local yCab = 0
    local cab = self.cabecera or ""
    self.cab:SetText(cab)
    if cab ~= "" then
      local h = self.cab.GetStringHeight and self.cab:GetStringHeight()
      yCab = ((type(h) == "number" and h > 0) and h or 14) + 6
    end
    local caben = math.max(1, math.floor((alto - yCab - 16) / ALTO_FILA))
    self.desde = math.max(0, math.min(self.desde, #self.datos - caben))
    for _, f in ipairs(self.filas) do f:Hide() end
    for i = 1, caben do
      local d = self.datos[self.desde + i]
      if not d then break end
      local f = Fila(i)
      f.dato = d
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -yCab - (i - 1) * ALTO_FILA)
      f:SetPoint("RIGHT", self, "RIGHT", 0, 0)
      f.texto:SetText((d.titulo and C.AMARILLO or "") .. (d.texto or "") .. (d.titulo and C.FIN or ""))
      f.detalle:SetText(d.detalle and (C.GRIS .. d.detalle .. C.FIN) or "")
      GL.Mostrar(f.fondo, d.titulo == true)
      GL.Mostrar(f.marca, d.hecha == true)
      -- 9.4.2: con icono, el texto empieza más a la derecha y la marca de «hecho» va en su esquina
      local x = d.icono and 32 or 18
      f.icono:SetTexture(d.icono); GL.Mostrar(f.icono, d.icono ~= nil)
      f.objeto = d.objeto
      f.marca:ClearAllPoints()
      if d.icono then f.marca:SetPoint("BOTTOMRIGHT", f.icono, "BOTTOMRIGHT", 3, -3) else f.marca:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -3) end
      f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", x, -2)
      f.detalle:SetPoint("TOPLEFT", f, "TOPLEFT", x, -15)
      local etiqueta = d.boton or (d.destino and L"Llevarme") or nil
      if etiqueta then f.boton.texto:SetText(etiqueta); f.boton:Show() else f.boton:Hide() end
      if d.boton2 then f.boton2.texto:SetText(d.boton2); f.boton2:Show() else f.boton2:Hide() end
      local ancla = d.boton2 and f.boton2 or f.boton
      f.texto:SetPoint("RIGHT", ancla, "LEFT", -4, 0)
      f.detalle:SetPoint("RIGHT", ancla, "LEFT", -4, 0)
      f.ayudaTitulo, f.ayudaTexto = d.ayudaTitulo, d.ayudaTexto
      f:Show()
    end
    local ultima = math.min(#self.datos, self.desde + caben)
    if #self.datos > caben then
      self.pie:SetText(C.GRIS .. (self.desde + 1) .. "-" .. ultima .. L" de " .. #self.datos .. L" (rueda del ratón)" .. C.FIN)
    elseif #self.datos == 0 then
      self.pie:SetText(C.GRIS .. (self.vacio or L"No hay nada que mostrar.") .. C.FIN)
    else
      self.pie:SetText("")
    end
  end

  function lista:Poner(datos, cabecera, vacio)
    if datos ~= self.datos then self.desde = 0 end
    self.datos, self.cabecera, self.vacio = datos or {}, cabecera, vacio
    self:Pintar()
  end

  lista:EnableMouseWheel(true)
  lista:SetScript("OnMouseWheel", function(self, delta) self.desde = math.max(0, self.desde - delta); self:Pintar() end)
  lista:SetScript("OnSizeChanged", function(self) self:Pintar() end)
  return lista
end

-- Pestañas encima de una lista: { { "id", "Etiqueta" }, ... }; al pulsar, alElegir(id).
function GL.CrearPestanas94(padre, lista, alElegir, ancho)
  local botones = {}
  for i, p in ipairs(lista) do
    local b = GL.CrearBoton(padre, p[2], function() alElegir(p[1]) end, nil, 20, "pestana")
    b:SetWidth(ancho or 110)
    b.clave = p[1]
    b.texto:SetJustifyH("CENTER")
    if i == 1 then b:SetPoint("TOPLEFT", padre, "TOPLEFT", 0, 0) else b:SetPoint("LEFT", botones[i - 1], "RIGHT", 4, 0) end
    botones[i] = b
  end
  -- 9.7.4: cada pestaña mide al menos su texto, y si juntas no caben en el ancho del marco se lo reparten
  -- (antes medían siempre 110: «Profesiones» de Oro se salía y «Equipo antes de banda» no cabía)
  local function Colocar(w)
    w = tonumber(w) or 0
    if w < 60 then w = (padre.GetWidth and tonumber(padre:GetWidth())) or 0 end
    local n = #botones
    if n == 0 then return end
    local anchos, suma = {}, 0
    for i, b in ipairs(botones) do
      local tw = b.texto and b.texto.GetStringWidth and tonumber(b.texto:GetStringWidth()) or 0
      anchos[i] = math.max(ancho or 110, math.ceil(tw) + 20); suma = suma + anchos[i]
    end
    local libre = w - 4 * (n - 1)
    if w >= 60 and suma > libre then
      local extra, textos = 0, 0
      for i, b in ipairs(botones) do
        local tw = b.texto and b.texto.GetStringWidth and tonumber(b.texto:GetStringWidth()) or 0
        anchos[i] = math.ceil(tw) + 12; textos = textos + anchos[i]
      end
      if textos > libre or textos == n * 12 then
        for i = 1, n do anchos[i] = libre / n end
      else
        extra = (libre - textos) / n
        for i = 1, n do anchos[i] = anchos[i] + extra end
      end
    end
    -- la primera se queda donde la puso quien creó las pestañas (Mazmorras las lleva a la derecha)
    for i, b in ipairs(botones) do
      b:SetWidth(math.floor(anchos[i]))
      if i > 1 then b:ClearAllPoints(); b:SetPoint("LEFT", botones[i - 1], "RIGHT", 4, 0) end
    end
  end
  botones.Colocar = Colocar
  if padre.HookScript then
    padre:HookScript("OnSizeChanged", function(self, w) Colocar(w) end)
    padre:HookScript("OnShow", function(self) Colocar() end)
  end
  Colocar()
  botones.Marcar = function(id) Colocar(); for _, b in ipairs(botones) do b:SetActivo(b.clave == id) end end
  return botones
end

-- Ventana propia (se puede mover y cerrar con Esc). v.lista es la lista; v.titulo, el título.
local ventanas = {}
function GL.VentanaLista(clave, titulo, ancho, alto)
  local v = ventanas[clave]
  if v then v.titulo:SetText(titulo or ""); return v end
  v = CreateFrame("Frame", "GuiaAventurero94" .. clave, UIParent, PLANTILLA)
  v:SetWidth(ancho or 420); v:SetHeight(alto or 380)
  v:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  v:SetFrameStrata("DIALOG")
  v:SetMovable(true); v:EnableMouse(true); v:RegisterForDrag("LeftButton")
  v:SetScript("OnDragStart", v.StartMoving); v:SetScript("OnDragStop", v.StopMovingOrSizing)
  if v.SetClampedToScreen then v:SetClampedToScreen(true) end
  if GL.Caja and GL.COLOR then GL.Caja(v, GL.COLOR.fondo or { 0.06, 0.07, 0.09, 0.96 }, GL.COLOR.borde or { 0.3, 0.3, 0.35, 1 }) end
  v.titulo = GL.Texto(v, "GameFontNormal")
  v.titulo:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -10)
  v.titulo:SetPoint("RIGHT", v, "RIGHT", -34, 0)
  v.titulo:SetText(titulo or "")
  if GL.UnaLinea then GL.UnaLinea(v.titulo) end
  local cerrar = GL.CrearBoton(v, "X", function() v:Hide() end, nil, 20, "cerrar")
  cerrar:SetWidth(22)
  cerrar.texto:SetJustifyH("CENTER")
  cerrar:SetPoint("TOPRIGHT", v, "TOPRIGHT", -6, -6)
  v.arriba = CreateFrame("Frame", nil, v)   -- pestañas
  v.arriba:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -32)
  v.arriba:SetPoint("TOPRIGHT", v, "TOPRIGHT", -12, -32)
  v.arriba:SetHeight(22)
  v.cuerpo = CreateFrame("Frame", nil, v)
  v.cuerpo:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -34)
  v.cuerpo:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", -12, 10)
  v.lista = GL.CrearLista(v.cuerpo)
  v.ConPestanas = function(self, si)   -- con pestañas, la lista baja
    self.cuerpo:ClearAllPoints()
    self.cuerpo:SetPoint("TOPLEFT", self, "TOPLEFT", 12, si and -60 or -34)
    self.cuerpo:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, 10)
  end
  if UISpecialFrames then table.insert(UISpecialFrames, v:GetName()) end
  v:Hide()
  ventanas[clave] = v
  return v
end

-- Secciones9.lua (9.0): lo nuevo de Profesiones y Exploración con el estilo moderno.
--  · Profesiones: el tramo actual en una tarjeta (barra, cuántos te faltan y los materiales que llevas).
--  · Exploración › Tu viaje: un mapa del continente con las zonas de tu ruta unidas por el camino:
--    verdes las hechas, en el color del acento la actual y grises las que faltan. Clic en una zona: sus misiones.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"
local function DB() return GuiaAventureroDB or {} end
local function Num(v) v = (GL.Seguro and GL.Seguro(v)) or v; return type(v) == "number" and v or nil end

------------------------------------------------------------------------
-- Profesiones: tarjeta del tramo actual
------------------------------------------------------------------------
local tramo
local function CrearTramo(panel)
  tramo = CreateFrame("Frame", nil, panel, PLANTILLA)
  tramo.titulo = GL.Texto(tramo, "GameFontNormalSmall")
  tramo.titulo:SetPoint("TOPLEFT", tramo, "TOPLEFT", 10, -8)
  tramo.rango = GL.Texto(tramo, "GameFontHighlightSmall", "RIGHT")
  tramo.rango:SetPoint("TOPRIGHT", tramo, "TOPRIGHT", -10, -8)
  tramo.barra = GL.CrearBarra(tramo, 0.49, 0.42, 1)
  tramo.barra:SetPoint("TOPLEFT", tramo, "TOPLEFT", 10, -24)
  tramo.barra:SetPoint("TOPRIGHT", tramo, "TOPRIGHT", -10, -24)
  tramo.texto = GL.Texto(tramo, "GameFontHighlight")
  tramo.texto:SetPoint("TOPLEFT", tramo, "TOPLEFT", 10, -46)
  tramo.mat = GL.Texto(tramo, "GameFontHighlightSmall")
  tramo.plan = CreateFrame("Button", nil, tramo, "UIPanelButtonTemplate")
  tramo.plan:SetHeight(22)
  tramo.plan:SetScript("OnClick", function(self)
    local skill=self.skill
    if not skill or not GL.ModalidadesProfesion975 then return end
    local modos=GL.ModalidadesProfesion975(skill)
    local actual=GL.ModoProfesion975(skill)
    for i,m in ipairs(modos) do
      if m==actual then GL.CambiarPlanProfesion975(skill,modos[i % #modos + 1]); return end
    end
  end)
  tramo.compra = CreateFrame("Button", nil, tramo, "UIPanelButtonTemplate")
  tramo.compra:SetHeight(22)
  tramo.compra:SetText(L"Lista de compra")
  tramo.compra:SetScript("OnClick", function() if GL.comandos and GL.comandos.compraprofesion then GL.comandos.compraprofesion() end end)
  tramo.raya = tramo:CreateTexture(nil, "ARTWORK")
  tramo.raya:SetWidth(3)
  tramo.raya:SetPoint("TOPLEFT", tramo, "TOPLEFT", 0, 0)
  tramo.raya:SetPoint("BOTTOMLEFT", tramo, "BOTTOMLEFT", 0, 0)
end

function GL.TarjetaTramo(panel, y, ancho, prof, nivel, tope)
  if tramo then tramo:Hide() end
  if DB().tarjetaTramo == false or not (prof and prof.pasos and nivel) then return 0 end
  local paso
  for _, p in ipairs(prof.pasos) do
    if nivel >= p.d and nivel < p.h then paso = p; break end
  end
  if not paso then return 0 end
  if not tramo then CrearTramo(panel) end
  local a = GL.COLOR.acento
  GL.Caja(tramo, { a[1], a[2], a[3], 0.08 }, { a[1], a[2], a[3], 0.45 })
  tramo.raya:SetColorTexture(a[1], a[2], a[3], 1)
  local bloqueado = type(tope)=="number" and tope<300 and nivel>=tope
  tramo.titulo:SetText(C.GRIS .. (bloqueado and L"TRAMO PENDIENTE (LÍMITE ALCANZADO)" or L"TRAMO ACTUAL") .. C.FIN)
  tramo.rango:SetText(C.BLANCO .. paso.d .. " " .. GL.Icono("→", 255, 255, 255) .. " " .. paso.h .. C.FIN)
  tramo.barra:SetMinMaxValues(paso.d, paso.h)
  tramo.barra:SetValue(nivel)
  local faltan = paso.h - nivel
  if tramo.barra.texto then tramo.barra.texto:SetText(nivel .. " / " .. paso.h .. L"  ·  faltan " .. faltan .. (faltan == 1 and L" punto" or L" puntos")) end
  local pt = GL.TextoPasoProfesion979 and GL.TextoPasoProfesion979(paso, true, tope) or paso.t
  local t = (GL.Colorear and GL.Colorear(pt)) or pt
  local w = ancho - 20
  tramo.texto:SetWidth(w)
  tramo.texto:SetText(t)
  local h = 46 + GL.Alto(tramo.texto, t, 13, w) + 6
  local mat = GL.MaterialesPaso and GL.MaterialesPaso(paso, nivel)
  if mat then
    tramo.mat:ClearAllPoints()
    tramo.mat:SetPoint("TOPLEFT", tramo, "TOPLEFT", 10, -h)
    tramo.mat:SetWidth(w)
    tramo.mat:SetText(mat)
    tramo.mat:Show()
    h = h + GL.Alto(tramo.mat, mat, 12, w) + 4
  else
    tramo.mat:Hide()
  end
  tramo.plan:Hide(); tramo.compra:Hide()
  if prof.skill and GL.ModalidadesProfesion975 and GL.PlanProfesion975(prof.skill) then
    local opciones=GL.ModalidadesProfesion975(prof.skill)
    local mitad=math.max(60, math.floor((w-6)/2))
    tramo.compra:ClearAllPoints(); tramo.compra:SetPoint("TOPRIGHT",tramo,"TOPRIGHT",-10,-h)
    tramo.compra:SetWidth(#opciones>1 and mitad or w); tramo.compra:Show()
    if #opciones>1 then
      tramo.plan.skill=prof.skill; tramo.plan:SetText(L"Cambiar plan")
      tramo.plan:ClearAllPoints(); tramo.plan:SetPoint("TOPLEFT",tramo,"TOPLEFT",10,-h)
      tramo.plan:SetWidth(mitad); tramo.plan:Show()
    end
    h=h+26
  end
  tramo:ClearAllPoints()
  tramo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  tramo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  tramo:SetHeight(h + 6)
  tramo:Show()
  return h + 6
end

------------------------------------------------------------------------
-- Exploración › Tu viaje
------------------------------------------------------------------------
local CONTINENTES = { { id = 1415, nombre = "Este" }, { id = 1414, nombre = "Kalimdor" } }
local viaje

-- zonas de la ruta por orden de aparición: { zona, m, x, y, primera, ultima } (secciones)
local function ZonasDelViaje()
  local R = GL.RUTA
  local orden, por = {}, {}
  if not R or not R.secciones then return orden end
  for s, sec in ipairs(R.secciones) do
    for _, paso in ipairs(sec.pasos or {}) do
      for _, wp in ipairs(paso.wp or {}) do
        if wp.z and wp.m then
          local z = por[wp.z]
          if not z then
            z = { zona = wp.z, m = wp.m, x = wp.x or 50, y = wp.y or 50, primera = s, ultima = s, n = 0, sx = 0, sy = 0 }
            por[wp.z] = z
            table.insert(orden, z)
          end
          z.ultima = math.max(z.ultima, s)
          if wp.m == z.m then z.n = z.n + 1; z.sx = z.sx + (wp.x or 50); z.sy = z.sy + (wp.y or 50) end
        end
      end
    end
  end
  for _, z in ipairs(orden) do if z.n > 0 then z.x, z.y = z.sx / z.n, z.sy / z.n end end
  return orden
end

-- posición de la zona en el mapa del continente (0-1), o nil si está en otro
local function EnContinente(z, cont)
  if not (C_Map and C_Map.GetMapRectOnMap) then return nil end
  local ok, x0, x1, y0, y1 = pcall(C_Map.GetMapRectOnMap, z.m, cont)
  if not ok or not Num(x0) or not Num(x1) or not Num(y0) or not Num(y1) or x1 <= x0 then return nil end
  return x0 + (x1 - x0) * z.x / 100, y0 + (y1 - y0) * z.y / 100
end

local function Estado(z)
  local s = DB().seccion or 1
  local R = GL.RUTA
  local actual = R and R.secciones[s]
  local zonaActual
  for _, paso in ipairs((actual and actual.pasos) or {}) do
    local wp = paso.wp and paso.wp[1]
    if wp and wp.z then zonaActual = zonaActual or wp.z end
  end
  local okP, _, pa = pcall(GL.PasoActual)
  local d = okP and type(pa) == "table" and pa.wp and pa.wp[1]
  if d and d.z then zonaActual = d.z end
  if z.zona == zonaActual then return "ahora" end
  if z.ultima < s then return "hecho" end
  return "falta"
end

local function CrearViaje(panel)
  viaje = CreateFrame("Frame", nil, panel, PLANTILLA)
  viaje:SetAllPoints(panel)
  viaje:SetFrameLevel(panel:GetFrameLevel() + 20)
  GL.Caja(viaje, GL.COLOR.fondo, GL.COLOR.fondo)
  viaje:EnableMouse(true)
  viaje.titulo = GL.Texto(viaje, "GameFontNormalLarge")
  viaje.titulo:SetPoint("TOPLEFT", viaje, "TOPLEFT", 0, 0)
  viaje.titulo:SetText(L"Tu viaje")
  viaje.sub = GL.Texto(viaje, "GameFontHighlightSmall")
  viaje.sub:SetPoint("TOPLEFT", viaje, "TOPLEFT", 0, -22)
  viaje.cerrar = GL.CrearBoton(viaje, L"Volver", function() viaje:Hide() end, nil, 18)
  viaje.cerrar:SetWidth(60)
  viaje.cerrar:SetPoint("TOPRIGHT", viaje, "TOPRIGHT", 0, 0)
  viaje.botones = {}
  for i, c in ipairs(CONTINENTES) do
    local b = GL.CrearBoton(viaje, L(c.nombre), function() DB().contViaje = c.id; GL.PintarViaje() end, nil, 18, "pestana")
    b:SetWidth(72)
    b.id = c.id
    viaje.botones[i] = b
  end
  viaje.botones[2]:SetPoint("RIGHT", viaje.cerrar, "LEFT", -8, 0)
  viaje.botones[1]:SetPoint("RIGHT", viaje.botones[2], "LEFT", -4, 0)
  viaje.lienzo = CreateFrame("Frame", nil, viaje, PLANTILLA)
  viaje.lienzo:SetPoint("TOPLEFT", viaje, "TOPLEFT", 0, -42)
  viaje.lienzo:SetPoint("BOTTOMRIGHT", viaje, "BOTTOMRIGHT", 0, 40)
  GL.Caja(viaje.lienzo, { 0, 0, 0, 0.4 }, GL.COLOR.cajaBorde)
  if viaje.lienzo.SetClipsChildren then viaje.lienzo:SetClipsChildren(true) end
  viaje.teselas, viaje.puntos, viaje.lineas = {}, {}, {}
  viaje.leyenda = GL.Texto(viaje, "GameFontHighlightSmall")
  viaje.leyenda:SetPoint("BOTTOMLEFT", viaje, "BOTTOMLEFT", 0, 22)
  viaje.pie = GL.Texto(viaje, "GameFontHighlightSmall")
  viaje.pie:SetPoint("BOTTOMLEFT", viaje, "BOTTOMLEFT", 0, 4)
  viaje.pie:SetPoint("BOTTOMRIGHT", viaje, "BOTTOMRIGHT", 0, 4)
  viaje.aviso = GL.Texto(viaje.lienzo, "GameFontHighlightSmall")
  viaje.aviso:SetPoint("CENTER", viaje.lienzo, "CENTER", 0, 0)
  viaje:Hide()
end

local COLORES = { hecho = { 0.30, 0.85, 0.40 }, falta = { 0.55, 0.56, 0.62 } }

local function Punto(i)
  local b = viaje.puntos[i]
  if b then return b end
  b = CreateFrame("Button", nil, viaje.lienzo)
  b:SetSize(14, 14)
  b:SetFrameLevel(viaje.lienzo:GetFrameLevel() + 3)
  b.borde = b:CreateTexture(nil, "ARTWORK")
  b.borde:SetAllPoints()
  b.borde:SetTexture(BLANCO8)
  b.borde:SetVertexColor(0, 0, 0, 0.85)
  b.dentro = b:CreateTexture(nil, "OVERLAY")
  b.dentro:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.dentro:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.dentro:SetTexture(BLANCO8)
  b.nombre = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.nombre:SetPoint("LEFT", b, "RIGHT", 3, 0)
  b.nombre:SetShadowOffset(1, -1)
  b:SetScript("OnClick", function(self)
    viaje:Hide()
    if GL._zonas and GL._zonas.Fija then GL._zonas.Fija(self.zona) end
    if GL.Refrescar then GL.Refrescar() end
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.zona, 1, 1, 1)
    local R = GL.RUTA
    local s1, s2 = self.datos.primera, self.datos.ultima
    GameTooltip:AddLine(L"Secciones " .. s1 .. (s2 ~= s1 and ("-" .. s2) or "") .. L" · niveles " ..
      R.secciones[s1].min .. "-" .. R.secciones[s2].max, 0.75, 0.75, 0.8)
    GameTooltip:AddLine(L"Clic: misiones de la guía en esta zona.", 0.6, 0.6, 0.65)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  viaje.puntos[i] = b
  return b
end

local function Linea(i)
  local l = viaje.lineas[i]
  if l then return l end
  if viaje.lienzo.CreateLine then
    l = viaje.lienzo:CreateLine(nil, "ARTWORK")
    l:SetThickness(2)
    l:SetTexture(BLANCO8)
  end
  viaje.lineas[i] = l or false
  return l
end

-- 9.5: las etiquetas de las zonas ya no se pisan. Cada nombre prueba 8 sitios alrededor de su punto
-- (derecha, izquierda, arriba, abajo y las esquinas) y se queda en el primero que no choca con otro
-- nombre ni con otro punto y cabe en el mapa. Primero la zona de ahora; si a otra no le cabe en
-- ningún sitio, su nombre se oculta (sale al pasar el ratón).
-- items: { px, py (desde arriba a la izquierda, py hacia abajo), r (medio lado del punto), w, h, fija }
-- Devuelve para cada item la esquina de arriba a la izquierda de su nombre { x, y } o false.
local SITIOS = {
  function(i) return i.px + i.r + 3, i.py - i.h / 2 end,            -- derecha
  function(i) return i.px - i.r - 3 - i.w, i.py - i.h / 2 end,      -- izquierda
  function(i) return i.px - i.w / 2, i.py - i.r - 1 - i.h end,      -- arriba
  function(i) return i.px - i.w / 2, i.py + i.r + 1 end,            -- abajo
  function(i) return i.px + i.r, i.py - i.r - i.h end,              -- arriba a la derecha
  function(i) return i.px - i.r - i.w, i.py - i.r - i.h end,        -- arriba a la izquierda
  function(i) return i.px + i.r, i.py + i.r end,                    -- abajo a la derecha
  function(i) return i.px - i.r - i.w, i.py + i.r end,              -- abajo a la izquierda
}
local function Choque(ax, ay, aw, ah, bx, by, bw, bh)
  local w = math.min(ax + aw, bx + bw) - math.max(ax, bx)
  local h = math.min(ay + ah, by + bh) - math.max(ay, by)
  if w <= 0 or h <= 0 then return 0 end
  return w * h
end
function GL._ColocarEtiquetas(items, W, H)
  local res, puestos = {}, {}
  local orden = {}
  for k = 1, #items do orden[k] = k end
  table.sort(orden, function(a, b)
    local fa, fb = items[a].fija and 1 or 0, items[b].fija and 1 or 0
    if fa ~= fb then return fa > fb end
    return a < b
  end)
  for _, k in ipairs(orden) do
    local it = items[k]
    local mejor, mejorX, mejorY = nil, nil, nil
    for _, Sitio in ipairs(SITIOS) do
      local x, y = Sitio(it)
      local malo = 0
      if x < 1 or y < 1 or x + it.w > W - 1 or y + it.h > H - 1 then malo = malo + 1e6 end
      for _, p in ipairs(puestos) do malo = malo + Choque(x, y, it.w, it.h, p[1] - 2, p[2] - 1, p[3] + 4, p[4] + 2) end
      for j, o in ipairs(items) do
        if j ~= k then malo = malo + Choque(x, y, it.w, it.h, o.px - o.r - 1, o.py - o.r - 1, 2 * o.r + 2, 2 * o.r + 2) end
      end
      if not mejor or malo < mejor then mejor, mejorX, mejorY = malo, x, y end
      if malo == 0 then break end
    end
    if mejor == 0 or (it.fija and mejorX) then
      res[k] = { mejorX, mejorY }
      table.insert(puestos, { mejorX, mejorY, it.w, it.h })
    else
      res[k] = false
    end
  end
  return res
end

function GL.PintarViaje()
  if not viaje then return end
  local cont = DB().contViaje
  local zonas = ZonasDelViaje()
  -- si no has elegido, el continente de la zona actual
  if not cont then
    for _, z in ipairs(zonas) do
      if Estado(z) == "ahora" then
        for _, c in ipairs(CONTINENTES) do if EnContinente(z, c.id) then cont = c.id end end
      end
    end
    cont = cont or CONTINENTES[1].id
  end
  for _, b in ipairs(viaje.botones) do b:SetActivo(b.id == cont) end
  local W, H = viaje.lienzo:GetWidth() or 0, viaje.lienzo:GetHeight() or 0
  for _, t in ipairs(viaje.teselas) do t:Hide() end
  for _, p in ipairs(viaje.puntos) do p:Hide() end
  for _, l in ipairs(viaje.lineas) do if l then l:Hide() end end
  viaje.aviso:SetText("")
  if W <= 0 or H <= 0 then return end
  -- dibujo del continente
  local ox, oy, aw, ah = 0, 0, W, H
  local okC, capas = pcall(function() return C_Map.GetMapArtLayers(cont) end)
  local capa = okC and type(capas) == "table" and capas[1]
  local okT, texturas = pcall(function() return C_Map.GetMapArtLayerTextures(cont, 1) end)
  if type(capa) == "table" and Num(capa.layerWidth) and okT and type(texturas) == "table" and #texturas > 0 then
    local s = math.min(W / capa.layerWidth, H / capa.layerHeight)
    aw, ah = capa.layerWidth * s, capa.layerHeight * s
    ox, oy = (W - aw) / 2, (H - ah) / 2
    local cols = math.ceil(capa.layerWidth / capa.tileWidth)
    for i, tex in ipairs(texturas) do
      local t = viaje.teselas[i]
      if not t then t = viaje.lienzo:CreateTexture(nil, "BACKGROUND"); viaje.teselas[i] = t end
      local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
      t:SetTexture(tex)
      t:SetSize(capa.tileWidth * s, capa.tileHeight * s)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", viaje.lienzo, "TOPLEFT", ox + c * capa.tileWidth * s, -(oy + r * capa.tileHeight * s))
      t:SetVertexColor(0.55, 0.55, 0.6)
      t:Show()
    end
  else
    viaje.aviso:SetText(C.GRIS .. L"No se pudo cargar el dibujo del continente." .. C.FIN)
  end
  -- zonas y camino
  local a = GL.COLOR.acento
  local hechas, total, n, ant = 0, #zonas, 0, nil
  local fuera = 0
  local etiquetas = {}
  for _, z in ipairs(zonas) do
    local est = Estado(z)
    if est == "hecho" then hechas = hechas + 1 end
    local x, y = EnContinente(z, cont)
    if x then
      n = n + 1
      local px, py = ox + x * aw, -(oy + y * ah)
      local b = Punto(n)
      b.zona, b.datos = z.zona, z
      local col = (est == "ahora") and a or COLORES[est]
      b.dentro:SetVertexColor(col[1], col[2], col[3], 1)
      b:SetSize(est == "ahora" and 16 or 12, est == "ahora" and 16 or 12)
      b.nombre:SetText(((est == "ahora") and C.BLANCO or (est == "hecho" and "|cff9fe0a8" or C.GRIS)) .. z.zona .. C.FIN)
      b:ClearAllPoints()
      b:SetPoint("CENTER", viaje.lienzo, "TOPLEFT", px, py)
      b:Show()
      local w = Num(b.nombre:GetStringWidth()) or (#z.zona * 6)
      table.insert(etiquetas, { px = px, py = -py, r = (est == "ahora") and 8 or 6, w = w + 2, h = 12, fija = (est == "ahora"), b = b })
      if ant then
        local l = Linea(n)
        if l then
          l:SetStartPoint("TOPLEFT", viaje.lienzo, ant[1], ant[2])
          l:SetEndPoint("TOPLEFT", viaje.lienzo, px, py)
          local colL = (est == "falta") and { 1, 1, 1, 0.18 } or { col[1], col[2], col[3], 0.6 }
          l:SetVertexColor(colL[1], colL[2], colL[3], colL[4])
          l:Show()
        end
      end
      ant = { px, py }
    else
      fuera = fuera + 1
      ant = nil   -- el camino sigue en el otro continente
    end
  end
  -- 9.5: los nombres, sin pisarse
  local sitios = GL._ColocarEtiquetas(etiquetas, W, H)
  for k, e in ipairs(etiquetas) do
    local nm = e.b.nombre
    nm:ClearAllPoints()
    if sitios[k] then
      nm:SetPoint("TOPLEFT", viaje.lienzo, "TOPLEFT", sitios[k][1] + 1, -sitios[k][2])
      nm:Show()
    else
      nm:Hide()
    end
  end
  local actual, totalPasos = 0, 1
  if GL.PosicionEnRuta then actual, totalPasos = GL.PosicionEnRuta() end
  viaje.sub:SetText(C.GRIS .. L"Ruta 1-60 · " .. math.floor(actual * 100 / math.max(1, totalPasos)) .. L" % hecho" ..
    ((fuera > 0) and (" · " .. fuera .. (fuera == 1 and L" zona" or L" zonas") .. L" en el otro continente") or "") .. C.FIN)
  viaje.leyenda:SetText(L"|cff4dd966■|r hecho   " .. GL.Simbolos(string.format("|cff%02x%02x%02x■|r", a[1] * 255, a[2] * 255, a[3] * 255)) .. L" ahora   " .. C.GRIS .. L"■ falta" .. C.FIN)
  viaje.pie:SetText(L"Zonas hechas " .. C.BLANCO .. hechas .. " / " .. total .. C.FIN .. C.GRIS .. L"  ·  clic en una zona: sus misiones" .. C.FIN)
end

local function AbrirViaje()
  local m = GL.modos and GL.modos.exploracion
  if not (m and m.panel) then return end
  if not viaje then CrearViaje(m.panel) end
  if viaje:IsShown() then viaje:Hide(); return end
  viaje:Show()
  local ok, err = pcall(GL.PintarViaje)
  if not ok and GL.Mensaje then GL.Mensaje(L"error en Tu viaje: " .. tostring(err)) end
end
GL.AbrirViaje = AbrirViaje

table.insert(GL.alIniciar, function()
  local u = GL._exploUI
  local m = GL.modos and GL.modos.exploracion
  if not (u and u.cerca and m and m.panel) then return end
  local b = GL.CrearBoton(u.interior or m.panel, L"Tu viaje", AbrirViaje, nil, 16)   -- 9.6: en la vista de siempre
  b:SetWidth(64)
  b:SetPoint("RIGHT", u.cerca, "LEFT", -4, 0)
  if GL.Ayuda then GL.Ayuda(b, L"Tu viaje", L"Mapa del continente con las zonas de tu ruta: hechas, la de ahora y las que faltan.") end
  if u.tituloLista then u.tituloLista:SetPoint("TOPRIGHT", m.panel, "TOPRIGHT", -258, -62) end
  m.panel:HookScript("OnHide", function() if viaje then viaje:Hide() end end)
end)

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "tarjetaTramo", "Profesiones: tarjeta del tramo actual",
  "Arriba de la lista, el tramo en el que estás con su barra, lo que te falta y los materiales que llevas.",
  function() return DB().tarjetaTramo ~= false end, function(v) DB().tarjetaTramo = v; if GL.Refrescar then GL.Refrescar() end end, pestana = "aspecto" })

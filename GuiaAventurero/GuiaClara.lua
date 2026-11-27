-- GuiaClara.lua (9.6): la pestaña Guía más clara (maqueta rediseno/9.6/guia-clara-v2.png).
--  · Cada misión del paso es una tarjeta con tres pasos fijos: Coger (PNJ y lugar), Hacer (dónde y lo que
--    llevas según el registro de misiones) y Entregar (PNJ y lugar). Los destinos del paso se juntan por misión.
--  · El paso al que apunta la flecha va en morado; los hechos, en gris con la marca de hecho.
--  · Lo que no es una misión (entrenar, volar, piedra de hogar) es una tarjeta con un solo paso «Ir».
--  · Sin retrato del PNJ, sin «Hecho», sin «Siguiente/Cerca de ti/Completado» y sin «Después»:
--    abajo, una sola línea «Luego» y los botones Atrás y Saltar paso.
--  · El texto largo del paso sale al pasar el ratón por la tarjeta.
--  · Las opcionales cercanas van en el desplegable «Otras misiones cerca» (Opcionales.lua).
-- Se quita en Ajustes › Avanzado › Paso › «Guía clara (Coger, Hacer, Entregar)».
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"
local MARCA_HECHO = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ICONO_IR = "Interface\\Icons\\Ability_Tracking"

local function DB() return GuiaAventureroDB or {} end

function GL.GuiaClaraActiva() return DB().guiaClara ~= false end

-- colores de la maqueta
local COL = {
  titulo = "|cffffd100", gris = "|cff8a8d99", claro = "|cffd0d2dc", blanco = "|cffffffff",
  A = "|cffa48cff", C = "|cff5ab4ff", T = "|cff4ade80", IR = "|cffa48cff", mision = "|cff8fb8ff",
}
local MORADO = { 0.55, 0.42, 1.0 }
local ETIQUETA = { A = "COGER", C = "HACER", T = "ENTREGAR", IR = "IR" }

------------------------------------------------------------------------
-- Datos: nombre de la misión y PNJ de cada destino, y los destinos de cada misión en toda la ruta
------------------------------------------------------------------------
local PREFIJO = { ["Recoger"] = "A", ["Accept"] = "A", ["Entregar"] = "T", ["Turn in"] = "T", ["Objetivo"] = "C", ["Objective"] = "C" }

-- «Recoger: Morcillas de Thelsamar (Vidra Hogartufa)» -> «Morcillas de Thelsamar», «Vidra Hogartufa»
local function Partir(n)
  local pre, resto = string.match(tostring(n or ""), "^([^:]+): (.+)$")
  if not pre or not PREFIJO[pre] then return nil, nil end
  local mision, pnj = string.match(resto, "^(.-) %(([^()]+)%)$")
  return mision or resto, pnj
end
GL._PartirDestino = Partir   -- para las pruebas

-- indice[q] = { A = {d, s, p}, C = ..., T = ... } con el primer destino de cada tipo en la ruta
local indice, indiceDe = nil, nil
local function Indice()
  local R = GL.RUTA
  if not R then return {} end
  if indice and indiceDe == R then return indice end
  indice, indiceDe = {}, R
  for s, sec in ipairs(R.secciones or {}) do
    for p, paso in ipairs(sec.pasos or {}) do
      for _, d in ipairs(paso.wp or {}) do
        if d.q and (d.a == "A" or d.a == "C" or d.a == "T") then
          local e = indice[d.q]
          if not e then e = {}; indice[d.q] = e end
          if not e[d.a] then e[d.a] = { d = d, s = s, p = p } end
        end
      end
    end
  end
  return indice
end

local function Coords(d)
  if not (d and d.x and d.y) then return "" end
  return string.format(" (%.1f, %.1f)", d.x, d.y)
end

local function Donde(d)
  if not d then return "" end
  return COL.gris .. ((d.z and (" · " .. (GL.ZonaDestinoGuiaR11 and GL.ZonaDestinoGuiaR11(d) or d.z))) or "") .. Coords(d) .. C.FIN
end

local function Hecho(d) return GL.DestinoHecho and GL.DestinoHecho(d) == true or false end
local function EnDiario(q) return GL.MisionEnDiario and GL.MisionEnDiario(q) or false end
local function Completada(q) return GL.MisionCompletada and GL.MisionCompletada(q) or false end

-- Lo que llevas de cada objetivo según el registro de misiones: «Carne de oso 2/3 · Tripas de jabalí 3/3»
local function Objetivos(q)
  if not (q and C_QuestLog and C_QuestLog.GetQuestObjectives and EnDiario(q)) then return nil, 0 end
  local ok, lista = pcall(C_QuestLog.GetQuestObjectives, q)
  if not ok or type(lista) ~= "table" or #lista == 0 then return nil, 0 end
  local partes = {}
  for _, o in ipairs(lista) do
    local texto = GL.Seguro and GL.Seguro(o.text) or o.text
    local listo = GL.Seguro and GL.Seguro(o.finished) or o.finished
    if type(texto) == "string" and texto ~= "" then
      -- el juego lo da como «Carne de oso: 2/3»; aquí va sin los dos puntos
      texto = string.gsub(texto, ":%s*(%d+%s*/%s*%d+)", " %1")
      table.insert(partes, (listo and C.VERDE or COL.claro) .. texto .. C.FIN)
    end
  end
  if #partes == 0 then return nil, 0 end
  local texto = table.concat(partes, COL.gris .. " · " .. C.FIN)
  if GL.ingles ~= GL.clienteIngles and GL.clienteIngles ~= nil then
    texto = texto .. COL.gris .. " (" .. L"idioma del cliente" .. ")" .. C.FIN
  end
  return texto, #lista
end

-- 9.6: la frase del texto del paso que dice qué hacer en una misión («Mata lobos para [Los enanos modistos]»).
-- Se saltan las de solo coger o entregar. Sin corchetes, recortada.
local SOLO_TRAMITE = { "^acepta", "^entrega", "^entrég", "^turn it in", "^habla", "^recoge", "^coge", "^y acepta", "^accept", "^turn in", "^talk", "^pick up", "^hand in", "^and accept",
  " te da ", " gives you ", " te dará ", " will give you " }
local function EsTramite(t)
  local min = string.lower(t)
  for _, pat in ipairs(SOLO_TRAMITE) do if min:find(pat) then return true end end
  return false
end
-- un trozo que solo nombra misiones («[A], [B] y [C]») no dice qué hacer
local function Dice(t)
  local sin = t:gsub("%[.-%]", ""):gsub("%(.-%)", "")
  local n = 0
  for _ in sin:gmatch("%a%a%a+") do n = n + 1 end
  return n >= 2
end
local function Pulir(f)
  f = f:gsub("^%s+", ""):gsub("[%s%.;,:]+$", ""):gsub("%[(.-)%]", "%1"):gsub("<(.-)>", "%1")
  if #f > 140 then f = (f:sub(1, 140):match("^(.*)%s") or f:sub(1, 140)) .. "..." end
  return (f:gsub("^%l", string.upper))
end
local function FraseHacer(texto, nombre)
  if type(texto) ~= "string" or not nombre or nombre == "" then return nil end
  local limpio = texto:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local marca = "[" .. nombre .. "]"
  for frase in (limpio .. ". "):gmatch("(.-[%.;])%s") do
    if frase:find(marca, 1, true) then
      -- trozos separados por «, » y «: » (se guarda el separador de después)
      local trozos = {}
      local resto = frase
      while true do
        local a, b, sep = resto:find("([,:])%s")
        if not a then table.insert(trozos, { resto, nil }); break end
        table.insert(trozos, { resto:sub(1, a - 1), sep })
        resto = resto:sub(b + 1)
      end
      for k, tr in ipairs(trozos) do
        if tr[1]:find(marca, 1, true) then
          if not EsTramite(tr[1]) and Dice(tr[1]) then return Pulir(tr[1]) end
          -- «X te da [misión]: las tres cajas están...» -> lo que va tras los dos puntos
          if tr[2] == ":" and trozos[k + 1] then
            local t = {}
            for m = k + 1, #trozos do t[#t + 1] = trozos[m][1] .. (trozos[m][2] and m < #trozos and (trozos[m][2] .. " ") or "") end
            local f = table.concat(t)
            if not EsTramite(f) and Dice(f) then return Pulir(f) end
          end
        end
      end
    end
  end
  return nil
end
GL._FraseHacer = FraseHacer   -- para las pruebas

-- Las tarjetas del paso: una por misión (en el orden en que salen) y una para lo que no es misión.
local function Tarjetas(paso)
  local lista, porQ, sueltos = {}, {}, {}
  for i, d in ipairs(paso.wp or {}) do
    if d.q and (d.a == "A" or d.a == "C" or d.a == "T") then
      local t = porQ[d.q]
      if not t then
        t = { q = d.q, A = {}, C = {}, T = {} }
        porQ[d.q] = t
        table.insert(lista, t)
      end
      table.insert(t[d.a], { d = d, i = i })
      if not t.nombre then t.nombre = (Partir(d.n)) end
    else
      table.insert(sueltos, { d = d, i = i })
    end
  end
  return lista, sueltos
end

-- 9.7.4: para la ventana compacta, las misiones del paso y lo que llevas de cada una
GL.MisionesDelPaso = function(paso) return (Tarjetas(paso or {})) end
GL.ObjetivosDeMision = Objetivos

-- Las tres filas de una misión. Si el paso no trae Coger o Entregar, se busca en el resto de la ruta.
local function FilasMision(t, textoPaso)
  local idx = Indice()[t.q] or {}
  local filas = {}
  -- Coger
  local a = t.A[1]
  if a then
    local _, pnj = Partir(a.d.n)
    filas[1] = { k = "A", d = a.d, i = a.i, hecho = Hecho(a.d), texto = COL.blanco .. (pnj or L"Recoger la misión") .. C.FIN .. Donde(a.d) }
  else
    local hecho = EnDiario(t.q) or Completada(t.q)
    local otro = idx.A and idx.A.d
    local _, pnj = Partir(otro and otro.n)
    filas[1] = { k = "A", d = (not hecho) and otro or nil, hecho = hecho,
      texto = (pnj and (COL.blanco .. pnj .. C.FIN .. Donde(otro)) or (COL.gris .. (hecho and L"Ya la llevas" or L"Cógela antes") .. C.FIN)) }
  end
  -- Hacer
  local objetivos, nObj = Objetivos(t.q)
  local frase = FraseHacer(textoPaso, t.nombre)
  local QUE = frase and (COL.blanco .. frase .. C.FIN) or (COL.blanco .. L"Completa los objetivos" .. C.FIN)
  local c, cTodos = nil, true
  for _, e in ipairs(t.C) do
    if not Hecho(e.d) then cTodos = false; c = c or e end
  end
  if #t.C > 0 then
    c = c or t.C[1]
    local hecho = cTodos
    local resto = (#t.C > 1) and (COL.gris .. "  (+" .. (#t.C - 1) .. L" sitios)" .. C.FIN) or ""
    filas[2] = { k = "C", d = c.d, i = c.i, hecho = hecho,
      texto = QUE .. Donde(c.d) .. resto, sub = objetivos }
  else
    local otro = idx.C and idx.C.d
    local listo = (EnDiario(t.q) and GL.DestinoHecho and GL.DestinoHecho({ q = t.q, a = "C" }) == true) or Completada(t.q)
    if otro then
      filas[2] = { k = "C", d = (not listo) and otro or nil, hecho = listo,
        texto = QUE .. Donde(otro), sub = objetivos }
    elseif objetivos and nObj > 0 then
      filas[2] = { k = "C", hecho = listo, texto = QUE, sub = objetivos }
    else
      filas[2] = { k = "C", hecho = Completada(t.q), nada = true,
        texto = COL.claro .. L"Nada que hacer: se entrega al momento" .. C.FIN }
    end
  end
  -- Entregar
  local e = t.T[1]
  if e then
    local _, pnj = Partir(e.d.n)
    local mismo = a and a.d.m == e.d.m and math.abs((a.d.x or 0) - (e.d.x or 99)) < 0.5 and math.abs((a.d.y or 0) - (e.d.y or 99)) < 0.5
    filas[3] = { k = "T", d = e.d, i = e.i, hecho = Hecho(e.d),
      texto = COL.blanco .. (pnj or L"Entregar la misión") .. C.FIN .. (mismo and (COL.gris .. L" · mismo sitio" .. C.FIN) or Donde(e.d)) }
  else
    local otro = idx.T and idx.T.d
    local _, pnj = Partir(otro and otro.n)
    filas[3] = { k = "T", d = otro, hecho = Completada(t.q),
      texto = (pnj and (COL.blanco .. pnj .. C.FIN .. Donde(otro)) or (COL.gris .. L"Se entrega más adelante" .. C.FIN)) ..
        ((otro and idx.T) and (COL.gris .. L" · más adelante en la ruta" .. C.FIN) or "") }
  end
  -- «Nada que hacer» cuenta como hecho cuando ya la llevas
  if filas[2].nada and filas[1].hecho then filas[2].hecho = true end
  return filas
end

------------------------------------------------------------------------
-- Marcos
------------------------------------------------------------------------
local tarjetas, extras = {}, {}
local plegadas, cabPlegadas = {}, nil   -- 9.7.9.7
local abiertaPaso, abiertaQ, PintarCabeceraPlegadas, PintarPlegada

local function Fila(card, j)
  card.filas = card.filas or {}
  local f = card.filas[j]
  if f then return f end
  f = CreateFrame("Button", nil, card)
  f.linea = f:CreateTexture(nil, "BACKGROUND")
  f.linea:SetHeight(1)
  f.linea:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.linea:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  f.linea:SetColorTexture(1, 1, 1, 0.06)
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.04)
  f.circulo = f:CreateTexture(nil, "ARTWORK")
  f.circulo:SetWidth(16); f.circulo:SetHeight(16)
  f.circulo:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -5)
  f.circulo:SetTexture(BLANCO8)
  f.num = GL.Texto(f, "GameFontHighlightSmall", "CENTER")
  f.num:SetPoint("CENTER", f.circulo, "CENTER", 0, 0)
  f.marca = f:CreateTexture(nil, "OVERLAY")
  f.marca:SetWidth(14); f.marca:SetHeight(14)
  f.marca:SetPoint("CENTER", f.circulo, "CENTER", 0, 0)
  f.marca:SetTexture(MARCA_HECHO)
  f.etiqueta = GL.Texto(f, "GameFontNormalSmall")
  f.etiqueta:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -7)
  f.etiqueta:SetWidth(70)
  GL.UnaLinea(f.etiqueta)
  f.texto = GL.Texto(f, "GameFontHighlightSmall")
  f.texto:SetPoint("TOPLEFT", f, "TOPLEFT", 96, -7)
  f.sub = GL.Texto(f, "GameFontHighlightSmall")
  f:SetScript("OnClick", function(self)
    local r = self.datos
    if not (r and r.d) then return end
    if IsShiftKeyDown and IsShiftKeyDown() and r.d.q and GL.EnlazarMision and GL.EnlazarMision(r.d) then return end
    if r.i then
      GuiaAventureroDB.destino = r.i
      if GL.SeguirDesvio then GL.SeguirDesvio(nil) end   -- vuelve al paso y repinta
    elseif r.d.m and GL.SeguirDesvio then
      GL.SeguirDesvio(r.d)                               -- fuera del paso: desvío sin cambiar de paso
    end
  end)
  f:SetScript("OnEnter", function(self)
    local tarjeta = self:GetParent()
    if tarjeta and tarjeta:GetScript("OnEnter") then tarjeta:GetScript("OnEnter")(tarjeta) end
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  card.filas[j] = f
  return f
end

local function Tarjeta(panel, i)
  local t = tarjetas[i]
  if t then return t end
  t = CreateFrame("Frame", nil, panel, PLANTILLA)
  GL.Caja(t, GL.COLOR.caja or { 1, 1, 1, 0.04 }, GL.COLOR.cajaBorde or { 1, 1, 1, 0.10 })
  t.titulo = GL.Texto(t, "GameFontNormal")
  t.titulo:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -9)
  t.der = GL.Texto(t, "GameFontHighlightSmall", "RIGHT")
  t.der:SetPoint("TOPRIGHT", t, "TOPRIGHT", -12, -11)
  t.titulo:SetPoint("RIGHT", t.der, "LEFT", -8, 0)
  GL.UnaLinea(t.titulo)
  t:EnableMouse(true)
  t:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.ayudaTitulo) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.ayudaTitulo, 1, 0.82, 0)
    if self.ayudaTexto and self.ayudaTexto ~= "" then GameTooltip:AddLine(self.ayudaTexto, 1, 1, 1, true) end
    GameTooltip:AddLine(L"Clic en una fila: la flecha va allí. Mayús+clic: enlazar la misión en el chat.", 0.6, 0.6, 0.65, true)
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- 9.7.9.7: en un paso con varias misiones, pulsar la tarjeta abierta la vuelve a plegar
  t:SetScript("OnMouseUp", function(self)
    if self.plegarQ and abiertaQ == self.plegarQ then
      abiertaQ = nil
      if GL.Refrescar then GL.Refrescar() end
    end
  end)
  tarjetas[i] = t
  return t
end

-- Pinta una fila y devuelve su alto.
local function PintarFila(card, j, r, y, ancho, numero, objetivo)
  local f = Fila(card, j)
  f.datos = r
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -y)
  f:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -y)
  local anchoTexto = math.max(80, ancho - 24 - 96)
  -- marca: hecho (gris con la marca), el de la flecha (morado) o número
  -- 9.7.9.7 (Quini): sin números en Coger, Hacer y Entregar. Hecho: la marca; el de la flecha: un cuadro morado.
  f.num:SetText("")
  if r.hecho then
    f.circulo:SetVertexColor(0.25, 0.85, 0.35, 0.18); f.circulo:Show(); f.marca:Show()
  elseif objetivo then
    f.circulo:SetVertexColor(MORADO[1], MORADO[2], MORADO[3], 1); f.circulo:Show(); f.marca:Hide()
  else
    f.circulo:Hide(); f.marca:Hide()
  end
  local col = r.hecho and COL.gris or (COL[r.k] or COL.blanco)
  f.etiqueta:SetText(col .. L(ETIQUETA[r.k] or "IR") .. C.FIN)
  local texto = r.texto or ""
  if r.hecho then texto = COL.gris .. string.gsub(texto, "|c%x%x%x%x%x%x%x%x", "") .. C.FIN end
  f.texto:SetWidth(anchoTexto)
  f.texto:SetText(texto)
  local h = GL.Alto(f.texto, texto, 13, anchoTexto)
  if r.sub and r.sub ~= "" and not r.hecho then
    f.sub:ClearAllPoints()
    f.sub:SetPoint("TOPLEFT", f.texto, "BOTTOMLEFT", 0, -3)
    f.sub:SetWidth(anchoTexto)
    f.sub:SetText(r.sub)
    f.sub:Show()
    h = h + 3 + GL.Alto(f.sub, r.sub, 13, anchoTexto)
  else
    f.sub:SetText(""); f.sub:Hide()
  end
  h = math.max(26, math.floor(h + 14))
  f:SetHeight(h)
  GL.Mostrar(f.linea, j > 1)
  f:Show()
  return h
end

-- Pinta una tarjeta con sus filas y devuelve su alto.
local function PintarTarjeta(panel, i, y, ancho, titulo, derecha, filas, ayudaTitulo, ayudaTexto)
  local card = Tarjeta(panel, i)
  card:ClearAllPoints()
  card:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  card:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  card.titulo:SetText(COL.titulo .. (titulo or "") .. C.FIN)
  card.der:SetText(derecha or "")
  card.ayudaTitulo, card.ayudaTexto = ayudaTitulo or titulo, ayudaTexto
  local destino = GL.DestinoActual and GL.DestinoActual()
  local h = 32
  for j, r in ipairs(filas) do
    h = h + PintarFila(card, j, r, h, ancho, j, (not r.hecho) and destino ~= nil and r.d == destino)
  end
  for j = #filas + 1, #(card.filas or {}) do card.filas[j]:Hide() end
  h = h + 6
  card:SetHeight(h)
  card:Show()
  return h
end

------------------------------------------------------------------------
-- 9.7.9.7: misiones plegadas (pasos con dos o más misiones). Una línea por misión con lo que toca:
-- Coger (quién y dónde) y Llévame; Hacer con el contador de cada objetivo y Llévame; Entregar (a quién,
-- «lista para entregar») y Llévame; Entregada en verde y tachada. Pulsar la línea abre la tarjeta normal.
------------------------------------------------------------------------
local function Metros(d)
  if not (d and d.x and GL.Vector) then return nil end
  local ok, este, _, dist = pcall(GL.Vector, d)
  if not (ok and este and type(dist) == "number") then return nil end
  local m = math.floor(dist * 0.9144 + 0.5)
  if m >= 1000 then return string.format("%.1f km", m / 1000) end
  return m .. " m"
end
local function Llevar(r)
  if not (r and r.d) then return end
  if r.i then
    GuiaAventureroDB.destino = r.i
    if GL.SeguirDesvio then GL.SeguirDesvio(nil) end
  elseif r.d.m and GL.SeguirDesvio then
    GL.SeguirDesvio(r.d)
  end
end
GL._LlevarFila = Llevar   -- para las pruebas
-- Lo que toca de una misión: etiqueta, fila de destino y texto de debajo.
local function LoQueToca(t, filas)
  if Completada(t.q) or filas[3].hecho then return "ENTREGADA", nil, nil end
  if not filas[1].hecho then return "A", filas[1], filas[1].texto end
  if not filas[2].hecho then
    local r = filas[2]
    return "C", r, (r.sub and r.sub ~= "") and r.sub or r.texto
  end
  return "T", filas[3], (filas[3].texto or "") .. COL.gris .. L" · lista para entregar" .. C.FIN
end
GL._LoQueToca = function(t, paso) return LoQueToca(t, FilasMision(t, paso and paso.t)) end   -- para las pruebas

PintarCabeceraPlegadas = function(panel, y, ancho, n, entregadas)
  if not cabPlegadas then cabPlegadas = GL.Texto(panel, "GameFontHighlightSmall") end
  cabPlegadas:SetParent(panel)
  cabPlegadas:ClearAllPoints()
  cabPlegadas:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -(y + 2))
  cabPlegadas:SetWidth(ancho - 4)
  cabPlegadas:SetText(COL.titulo .. n .. L" misiones en este paso" .. C.FIN .. COL.gris .. "  ·  " .. entregadas .. L" entregadas" ..
    "  ·  " .. L"pulsa una para verla entera" .. C.FIN)
  cabPlegadas:Show()
  return 20
end

local function Plegada(panel, i)
  local f = plegadas[i]
  if f then return f end
  f = CreateFrame("Button", nil, panel, PLANTILLA)
  GL.Caja(f, GL.COLOR.caja or { 1, 1, 1, 0.04 }, GL.COLOR.cajaBorde or { 1, 1, 1, 0.10 })
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.04)
  f.raya = f:CreateTexture(nil, "ARTWORK")
  f.raya:SetWidth(3)
  f.raya:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.raya:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  f.raya:SetColorTexture(1, 0.82, 0, 1)
  f.flecha = GL.Texto(f, "GameFontHighlightSmall")
  f.flecha:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
  f.etiqueta = GL.Texto(f, "GameFontNormalSmall")
  f.etiqueta:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -8)
  f.etiqueta:SetWidth(76)
  GL.UnaLinea(f.etiqueta)
  f.nombre = GL.Texto(f, "GameFontHighlightSmall")
  f.nombre:SetPoint("TOPLEFT", f, "TOPLEFT", 98, -8)
  GL.UnaLinea(f.nombre)
  f.sub = GL.Texto(f, "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", f.nombre, "BOTTOMLEFT", 0, -3)
  f.llevar = GL.CrearBoton(f, L"Llévame", function(b) Llevar(b:GetParent().fila) end, nil, 18)
  f.llevar:SetWidth(64)
  f.llevar:SetPoint("RIGHT", f, "RIGHT", -6, 0)
  if GL.Ayuda then GL.Ayuda(f.llevar, L"Llévame", L"La flecha te lleva a esta misión para hacerla antes que las demás.") end
  f:SetScript("OnClick", function(self)
    if IsShiftKeyDown and IsShiftKeyDown() and self.fila and self.fila.d and GL.EnlazarMision and GL.EnlazarMision(self.fila.d) then return end
    abiertaQ = self.q
    if GL.Refrescar then GL.Refrescar() end
  end)
  f:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.titulo or "", 1, 0.82, 0)
    GameTooltip:AddLine(L"Clic: ver la misión entera (Coger, Hacer, Entregar). Mayús+clic: enlazar la misión en el chat.", 0.6, 0.6, 0.65, true)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  plegadas[i] = f
  return f
end

PintarPlegada = function(panel, i, y, ancho, t, filas, etiquetaMision)
  local f = Plegada(panel, i)
  f.q = t.q
  f.titulo = t.nombre
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  local tipo, r, sub = LoQueToca(t, filas)
  f.fila = r
  local destino = GL.DestinoActual and GL.DestinoActual()
  local actual = false
  if destino then for _, x in ipairs(filas) do if x.d and x.d == destino then actual = true end end end
  GL.Mostrar(f.raya, actual and tipo ~= "ENTREGADA")
  local anchoTexto = math.max(80, ancho - 98 - 76)
  f.nombre:SetWidth(anchoTexto)
  if tipo == "ENTREGADA" then
    f.flecha:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t")
    f.etiqueta:SetText(COL.T .. L"ENTREGADA" .. C.FIN)
    f.nombre:SetText("|cff66cc66" .. (t.nombre or L"Misión") .. C.FIN)
    f.sub:SetText(""); f.sub:Hide()
    f.llevar:Hide()
    f:SetHeight(26)
    f:Show()
    return 26
  end
  f.flecha:SetText("|TInterface\\Buttons\\UI-PlusButton-Up:12|t")
  f.etiqueta:SetText((COL[tipo] or COL.blanco) .. L(ETIQUETA[tipo] or "") .. C.FIN)
  f.nombre:SetText(COL.titulo .. (t.nombre or L"Misión") .. (etiquetaMision or "") .. C.FIN)
  local lejos = r and r.d and Metros(r.d)
  local texto = (sub or "") .. (lejos and (COL.gris .. " · " .. lejos .. C.FIN) or "")
  f.sub:SetWidth(anchoTexto)
  f.sub:SetText(texto)
  f.sub:Show()
  local h = 8 + 14 + 3 + GL.Alto(f.sub, texto, 13, anchoTexto) + 7
  GL.Mostrar(f.llevar, r and r.d ~= nil)
  h = math.max(34, math.floor(h))
  f:SetHeight(h)
  f:Show()
  return h
end

------------------------------------------------------------------------
-- Pintar la Guía clara. Devuelve el alto que ocupa (desde y).
------------------------------------------------------------------------
function GL.PintarGuiaClara(panel, y, ancho)
  local _, paso = GL.PasoActual()
  if not paso then return 0 end
  local textoPaso = GL.Colorear and GL.Colorear(paso.t or "") or (paso.t or "")
  local lista, sueltos = Tarjetas(paso)
  local usadas, alto, plegadasUsadas = 0, 0, 0
  -- 9.7.9.7 (Quini): con dos o más misiones en el paso, todas plegadas en una línea con lo que toca;
  -- al pulsar una se abre su tarjeta normal (Coger, Hacer, Entregar). Solo una abierta a la vez.
  local db = DB()
  local clavePaso = tostring(db.seccion) .. ":" .. tostring(db.paso)
  if abiertaPaso ~= clavePaso then abiertaPaso, abiertaQ = clavePaso, nil end
  local plegar = #lista >= 2
  if plegar then
    local entregadas = 0
    for _, t in ipairs(lista) do if Completada(t.q) then entregadas = entregadas + 1 end end
    alto = alto + PintarCabeceraPlegadas(panel, y, ancho, #lista, entregadas)
  end
  for _, t in ipairs(lista) do
    local filas = FilasMision(t, paso.t)
    local hechos = 0
    for _, r in ipairs(filas) do if r.hecho then hechos = hechos + 1 end end
    local etiqueta = (GL.EtiquetaMision and not filas[3].hecho) and GL.EtiquetaMision(t.q) or ""
    if plegar and abiertaQ ~= t.q then
      plegadasUsadas = plegadasUsadas + 1
      alto = alto + PintarPlegada(panel, plegadasUsadas, y + alto, ancho, t, filas, etiqueta) + 4
    else
      usadas = usadas + 1
      local card
      alto = alto + PintarTarjeta(panel, usadas, y + alto, ancho, (plegar and "|TInterface\\Buttons\\UI-MinusButton-Up:12|t " or "") .. (t.nombre or L"Misión") .. (etiqueta or ""),
        COL.gris .. hechos .. L" de " .. #filas .. L" hechos" .. C.FIN, filas, t.nombre, textoPaso) + 8
      card = tarjetas[usadas]
      card.plegarQ = plegar and t.q or nil
    end
  end
  for i = plegadasUsadas + 1, #plegadas do plegadas[i]:Hide() end
  if not plegar and cabPlegadas then cabPlegadas:Hide() end
  -- lo que no es misión: una tarjeta con un paso «Ir» por destino (o solo el texto si no hay destino)
  if #sueltos > 0 or #lista == 0 then
    local filas = {}
    for _, e in ipairs(sueltos) do
      local hecho = Hecho(e.d)
      table.insert(filas, { k = "IR", d = e.d, i = e.i, hecho = hecho,
        texto = COL.blanco .. tostring(e.d.n or "") .. C.FIN .. Donde(e.d) })
    end
    if #lista == 0 then
      if filas[1] then filas[1].sub = textoPaso
      else filas[1] = { k = "IR", texto = textoPaso } end
    end
    local tipo = L"Ir"
    if GL.TipoPaso then
      local okT, _, ti = pcall(GL.TipoPaso, paso)
      if okT and type(ti) == "table" and ti.n then tipo = ti.n end
    end
    if #lista > 0 then tipo = L"Además" end
    usadas = usadas + 1
    alto = alto + PintarTarjeta(panel, usadas, y + alto, ancho, tipo, "", filas, tipo, textoPaso) + 8
  end
  for i = usadas + 1, #tarjetas do tarjetas[i]:Hide() end
  return alto
end

-- «Luego: ...» y los botones Atrás y Saltar paso, debajo de todo. Devuelve el alto.
local function Corto(p, max)
  local t = (p and p.t) or ""
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("%[(.-)%]", "%1"):gsub("<(.-)>", "%1")
  local frase = t:match("^(.-[%.:;])%s") or t
  frase = frase:gsub("[%.:;]$", "")
  max = max or 90
  if #frase > max then
    frase = (frase:sub(1, max):match("^(.*)%s") or frase:sub(1, max)) .. "..."
  end
  return frase
end

function GL.PintarLuego(panel, y, ancho)
  local db = DB()
  if not extras.luego then
    extras.raya = panel:CreateTexture(nil, "ARTWORK")
    extras.raya:SetHeight(1)
    extras.raya:SetColorTexture(1, 1, 1, 0.08)
    extras.luego = GL.Texto(panel, "GameFontHighlightSmall")
    extras.atras = GL.CrearBoton(panel, L"< Atrás", function() if GL.Anterior then GL.Anterior() end end, nil, 22)
    extras.atras:SetWidth(80)
    if GL.Ayuda then GL.Ayuda(extras.atras, L"Atrás", L"Vuelve al paso anterior.") end
    extras.saltar = GL.CrearBoton(panel, L"Saltar paso >", function() if GL.Siguiente then GL.Siguiente() end end, nil, 22)
    extras.saltar:SetWidth(100)
    if GL.Ayuda then GL.Ayuda(extras.saltar, L"Saltar paso", L"Pasa al paso siguiente aunque este no esté hecho.") end
    -- 9.6: «Mi nivel» también abajo (los avisos y el tutorial lo nombran)
    extras.minivel = GL.CrearBoton(panel, L"Mi nivel", function() if GL.IrAMiNivel then GL.IrAMiNivel() end end, nil, 22)
    extras.minivel:SetWidth(80)
    if GL.Ayuda then GL.Ayuda(extras.minivel, L"Mi nivel", L"Si te pierdes: la guía vuelve a la sección de tu nivel y al primer paso que te falta.") end
    -- 9.7: recuperación del paso desde la pantalla principal, sin memorizar comandos.
    extras.comprobar = GL.CrearBoton(panel, L"¿Atascado? Comprobar paso", function()
      if GL.comandos and GL.comandos["comprobar"] then GL.comandos["comprobar"]() end
    end, nil, 20)
    if GL.Ayuda then GL.Ayuda(extras.comprobar, L"Comprobar paso", L"Comprueba qué misiones están en el diario y cuáles están entregadas; no altera tu progreso.") end
  end
  local alto = 0
  local cs, cp
  if GL.PasoDespues then cs, cp = GL.PasoDespues(db.seccion, db.paso) end   -- (con «and» solo llegaba la sección)
  extras.raya:ClearAllPoints()
  extras.raya:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
  extras.raya:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
  extras.raya:Show()
  if cs and GL.RUTA and GL.RUTA.secciones[cs] then
    local sig = GL.RUTA.secciones[cs].pasos[cp]
    local t = C.BLANCO .. L"Luego: " .. C.FIN .. COL.gris .. Corto(sig, 110) .. "." .. C.FIN
    extras.luego:ClearAllPoints()
    extras.luego:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -(y + 7))
    extras.luego:SetWidth(ancho - 4)
    extras.luego:SetText(t)
    extras.luego:Show()
    alto = 7 + GL.Alto(extras.luego, t, 13, ancho - 4) + 6
  else
    extras.luego:Hide()
    alto = 6
  end
  -- 9.7.9.7 (Quini): Atrás, Mi nivel, Siguiente y «?» (¿Atascado?) van arriba, debajo de la barra de la ruta
  -- (fila ui.nav de GuiaAventurero.lua); con muchas misiones en el paso, abajo no se veían.
  extras.atras:Hide(); extras.saltar:Hide(); extras.minivel:Hide(); extras.comprobar:Hide()
  return alto
end

-- 9.7.9.7: los botones de arriba (Atrás, Mi nivel, Siguiente, ?) se ven siempre; con la Guía clara apagada,
-- se ocultan las tarjetas. Lo llama RefrescarGuia en cada refresco.
function GL.GuiaClaraOcultar(clara)
  local ui = GL.ui
  if ui and ui.nav then for _, b in ipairs(ui.nav) do GL.Mostrar(b, true) end end   -- 9.7.9.7: siempre a la vista
  if not clara then
    for _, t in ipairs(tarjetas) do t:Hide() end
    for _, k in ipairs({ "raya", "luego", "atras", "saltar", "minivel", "comprobar" }) do if extras[k] then extras[k]:Hide() end end
    for _, f in ipairs(plegadas) do f:Hide() end
    if cabPlegadas then cabPlegadas:Hide() end
  end
end

-- Tras quitar la fila de botones de arriba, los avisos de desvío y de zona suben lo mismo.
function GL.SubirAvisos(panel, cuanto)
  local ui = GL.ui
  for _, f in ipairs({ ui.desvio, ui.aviso, ui.prep }) do
    if f and f:IsShown() then
      local _, _, _, _, dy = f:GetPoint(1)
      dy = tonumber(dy) or 0
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, dy + cuanto)
      f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, dy + cuanto)
    end
  end
end
GL._tarjetasClara = tarjetas
GL._plegadasClara = plegadas   -- 9.7.9.7: para las pruebas

-- 9.6: ¿el mapa m está en otro continente que el tuyo? (sube por los mapas padre hasta el de tipo continente)
local function MapaValido(m)
  if GL.Seguro then m = GL.Seguro(m) end
  if type(m) == "number" and m > 0 and m < math.huge and m % 1 == 0 then return m end
end
local function MapaInfo(m, cache)
  if cache and cache[m] ~= nil then return cache[m] or nil end
  -- El fallo solo se recuerda durante esta consulta, nunca entre consultas.
  if cache then cache[m] = false end
  if not (C_Map and C_Map.GetMapInfo) then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, m)
  if not ok then return nil end
  if GL.Seguro then info = GL.Seguro(info) end
  if type(info) == "table" then
    if cache then cache[m] = info end
    return info
  end
end
local function Continente(m, cache)
  for _ = 1, 8 do
    m = MapaValido(m)
    if not m then return nil end
    local info = MapaInfo(m, cache)
    if not info then return nil end
    local tipo = info.mapType
    if GL.Seguro then tipo = GL.Seguro(tipo) end
    if tipo == 2 then return m end
    m = info.parentMapID
  end
end
function GL.OtroContinente(m)
  if not (C_Map and C_Map.GetBestMapForUnit) then return false end
  local ok, mio = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok then return false end
  local cache = {}
  local a, b = Continente(mio, cache), Continente(m, cache)
  return (a and b and a ~= b) and true or false
end


-- 9.7.7: cruces intercontinentales documentados. Solo sugerencias; nunca cambian la ruta.
-- Menethil/Southshore/Auberdine es un circuito dirigido, no una conexión reversible.
local cruces = {
  { "A", 1453, "Puerto de Ventormenta", 1439, "Auberdine", "Barco" },
  { "A", 1437, "Puerto de Menethil", 1445, "Theramore", "Barco" },
  { "A", 1439, "Auberdine", 1437, "Puerto de Menethil", "Barco", true },
  { "A", 1424, "Costasur", 1439, "Auberdine", "Barco", true },
  { "H", 1454, "Orgrimmar", 1420, "Claros de Tirisfal", "Zepelín" },
  { "H", 1454, "Orgrimmar", 1434, "Campamento Grom'gol", "Zepelín" },
  { "N", 1413, "Trinquete", 1434, "Bahía del Botín", "Barco" },
}
local function Dentro(m, objetivo, cache)
  for _ = 1, 8 do
    m = MapaValido(m)
    if not m then return false end
    if m == objetivo then return true end
    local info = MapaInfo(m, cache)
    if not info then return false end
    m = info.parentMapID
  end
  return false
end
-- 9.7.7: transportes directos entre zonas concretas, incluso si una isla no tiene continente en la API.
local directos = {
  { "A", 1453, "Ventormenta", 1455, "Forjaz", "Tranvía" },
  { "A", 1438, "Aldea Rut'theran", 1439, "Auberdine", "Barco" },
  { "A", 1457, "Aldea Rut'theran", 1439, "Auberdine", "Barco" },
  { "A", 1437, "Puerto de Menethil", 1424, "Costasur", "Barco", true },
  { "H", 1420, "Claros de Tirisfal", 1434, "Campamento Grom'gol", "Zepelín" },
  { "H", 1458, "Claros de Tirisfal", 1434, "Campamento Grom'gol", "Zepelín" },
  { "A", 2521, "Valanaar", 1416, "Dalaran", "Nave celeste" },
  { "H", 2521, "Valanaar", 1412, "Meseta Skywatcher", "Nave celeste" },
}
function GL.TransporteDirecto(origen, destino, faccion)
  origen, destino = MapaValido(origen), MapaValido(destino)
  if not origen or not destino or origen == destino then return nil end
  if GL.Seguro then faccion = GL.Seguro(faccion) end
  local lado = faccion == "Alliance" and "A" or faccion == "Horde" and "H" or "N"
  local cache = {}
  for _, r in ipairs(directos) do
    if r[1] == lado or r[1] == "N" then
      if Dentro(origen, r[2], cache) and Dentro(destino, r[4], cache) then
        return { salida = r[3], llegada = r[5], tipo = r[6] }
      elseif not r[7] and Dentro(origen, r[4], cache) and Dentro(destino, r[2], cache) then
        return { salida = r[5], llegada = r[3], tipo = r[6] }
      end
    end
  end
end
function GL.TextoTransporteDirecto(destino)
  local ok, r = pcall(function()
    return GL.TransporteDirecto(C_Map.GetBestMapForUnit("player"), destino, UnitFactionGroup and UnitFactionGroup("player"))
  end)
  if ok and r then return L"Opción de transporte: " .. L(r.tipo) .. " · " .. L(r.salida) .. " → " .. L(r.llegada) end
end
function GL.TransporteEntreContinentes(origen, destino, faccion)
  local cache = {}
  local a, b = Continente(origen, cache), Continente(destino, cache)
  if not a or not b or a == b then return nil end
  if GL.Seguro then faccion = GL.Seguro(faccion) end
  local lado = faccion == "Alliance" and "A" or faccion == "Horde" and "H" or "N"
  local mejor, puntos
  local function Candidato(r, i, j)
    if Continente(r[i], cache) ~= a or Continente(r[j], cache) ~= b then return end
    local valor = (Dentro(origen, r[i], cache) and 4 or 0) + (Dentro(destino, r[j], cache) and 4 or 0) + (r[1] == lado and 1 or 0)
    if not puntos or valor > puntos then
      puntos = valor
      mejor = { salida = r[i+1], llegada = r[j+1], tipo = r[6] }
    end
  end
  for _, r in ipairs(cruces) do
    if r[1] == lado or r[1] == "N" then
      Candidato(r, 2, 4)
      if not r[7] then Candidato(r, 4, 2) end
    end
  end
  return mejor
end
function GL.TextoTransporte(destino)
  local directo = GL.TextoTransporteDirecto(destino)
  if directo then return directo end
  local ok, r = pcall(function()
    local origen = C_Map.GetBestMapForUnit("player")
    local faccion = UnitFactionGroup and UnitFactionGroup("player")
    return GL.TransporteEntreContinentes(origen, destino, faccion)
  end)
  if ok and r then
    return L"Opción de transporte: " .. L(r.tipo) .. " · " .. L(r.salida) .. " → " .. L(r.llegada)
  end
  return L"Vuelve en barco, zepelín o con la piedra de hogar; la flecha te guía al llegar."
end

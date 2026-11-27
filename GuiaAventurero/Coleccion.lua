-- Coleccion.lua (7.5.16): botón Colección del lateral derecho. Monturas, mascotas y juguetes que se consiguen
-- subiendo, en una cuadrícula de 4 por fila con el icono del juego: en color si lo tienes y en gris si no.
-- Clic en uno: dónde se consigue, precio, reputación, coordenadas y Llevarme. Datos en DatosWowhead.lua.
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" then return end
local L = GL.L

local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local COLUMNAS, ALTO_CELDA, LADO_ICONO, ALTO_FICHA = 4, 66, 40, 132
local PESTANAS = { { "monturas", "Monturas", "montura", "monturas" }, { "mascotas", "Mascotas", "mascota", "mascotas" },
  { "juguetes", "Juguetes", "juguete", "juguetes" } }

local panel, ui = nil, { celdas = {}, pest = {} }
local tipo, desde, sel = "monturas", 0, nil

-- La posesión de un objeto no equivale a haberlo aprendido en el diario de Forever.
local function Publico(v)
  if type(issecretvalue) ~= "function" then return true end
  local ok, secreto = pcall(issecretvalue, v)
  return ok and secreto == false
end
local function IdValido(v) return Publico(v) and type(v) == "number" and v > 0 and v < math.huge and v % 1 == 0 end
local function Consulta(f, ...)
  if type(f) ~= "function" then return nil end
  local ok, v = pcall(f, ...)
  if ok and Publico(v) then return v end
end
local function Retorno(n, f, ...)
  if type(f) ~= "function" then return nil end
  local datos = {pcall(f, ...)}
  if datos[1] and Publico(datos[n+1]) then return datos[n+1] end
end
local function Lado()
  local f = Consulta(UnitFactionGroup, "player")
  return f == "Alliance" and "A" or (f == "Horde" and "H" or nil)
end
local function RazaActual()
  local r = Consulta(GL.Raza)
  if type(r) == "string" and r ~= "" then return r end
  r = Retorno(2, UnitRace, "player")
  local id = Retorno(3, UnitRace, "player")
  if id == 95 or id == 96 or (type(r) == "string" and r:lower():find("skyborne", 1, true)) then return "Skyborne" end
  return type(r) == "string" and r or nil
end
local function ClaseActual()
  return Retorno(2, UnitClass, "player")
end
local filtradas = {}
local function Lista()
  local todas = (GL.WH and GL.WH.coleccion and GL.WH.coleccion[tipo]) or {}
  local lado = Lado()
  local raza, clase = RazaActual(), ClaseActual()
  local clave = tipo .. (lado or "?") .. ":" .. (raza or "?") .. ":" .. (type(clase) == "string" and clase or "?")
  if not filtradas[clave] or filtradas[clave].fuente ~= todas then
    local l = {}
    for _, e in ipairs(todas) do
      if (tipo == "mascotas" or not e.lado or e.lado == lado) and (not e.clase977 or e.clase977 == clase)
        and (not e.razaClase977 or e.razaClase977 == raza)
        and (not e.razasClase977 or (raza and e.razasClase977[raza])) then l[#l+1] = e end
    end
    filtradas[clave] = { fuente = todas, lista = l }
  end
  return filtradas[clave].lista
end
local function CoordenadasValidas(d)
  return type(d) == "table" and Publico(d.x) and Publico(d.y) and type(d.x) == "number" and type(d.y) == "number"
    and d.x >= 0 and d.x <= 100 and d.y >= 0 and d.y <= 100 and (d.x ~= 0 or d.y ~= 0)
end
local function FuenteDestino(e)
  if type(e) ~= "table" or e.pendienteObtencion977 or e.temporal977 then return nil end
  local lado, raza, clase = Lado(), RazaActual(), ClaseActual()
  if (e.ladoUso977 and e.ladoUso977 ~= lado) or (e.lado and e.lado ~= lado)
    or (e.clase977 and e.clase977 ~= clase) or (e.razaClase977 and e.razaClase977 ~= raza)
    or (e.razasClase977 and not (raza and e.razasClase977[raza])) then return nil end
  if e.destinos977 then
    if type(e.destinos977) == "table" and lado then return e.destinos977[lado] end
    return nil
  end
  return e
end
local function DestinoColeccion(e)
  local d = FuenteDestino(e)
  if not CoordenadasValidas(d) or not IdValido(d.m) then return nil end
  return d
end
local function TextoValido(v)
  return Publico(v) and type(v) == "string" and v:find("%S") ~= nil
end
-- El ID cartográfico no sustituye al nombre de zona que necesita la flecha.
local function DestinoNavegacion(e)
  local d = DestinoColeccion(e)
  if not d then return nil end
  local zona = (GL.LC or function(v) return v end)(d.zona)
  if not TextoValido(zona) then
    local info = Consulta(C_Map and C_Map.GetMapInfo, d.m)
    zona = type(info) == "table" and info.name or nil
  end
  if not TextoValido(zona) then return nil end
  return { m = d.m, x = d.x, y = d.y, z = zona }
end
local function CuentaValida(n) return Publico(n) and type(n) == "number" and n >= 0 and n < math.huge and n % 1 == 0 end
local function Estado(e, categoria)
  categoria = categoria or tipo
  if type(e) ~= "table" then return "desconocido" end
  local id = IdValido(e.id) and e.id or nil
  local hechizo = IdValido(e.hechizo) and e.hechizo or nil
  local aprendido
  if categoria == "monturas" and C_MountJournal then
    local mid = id and Consulta(C_MountJournal.GetMountFromItem, id)
    if not IdValido(mid) and hechizo then mid = Consulta(C_MountJournal.GetMountFromSpell, hechizo) end
    if IdValido(mid) then
      aprendido = Retorno(11, C_MountJournal.GetMountInfoByID, mid)
    end
  elseif categoria == "mascotas" and C_PetJournal and id then
    local especie = Retorno(13, C_PetJournal.GetPetInfoByItemID, id)
    if IdValido(especie) then
      local n = Consulta(C_PetJournal.GetNumCollectedInfo, especie)
      if CuentaValida(n) then aprendido = n > 0 end
    end
  elseif categoria == "juguetes" and id then
    aprendido = Consulta(PlayerHasToy, id)
  end
  if aprendido == true then return "aprendido" end
  -- Solo hechizos explícitos del catálogo. GetItemSpell puede devolver un hechizo genérico de aprendizaje.
  if aprendido ~= false and hechizo and (Consulta(IsSpellKnown, hechizo) == true or Consulta(GL.HechizoConocido, hechizo) == true) then return "aprendido" end
  local n
  if id then
    n = Consulta(C_Item and C_Item.GetItemCount, id, true)
    if not CuentaValida(n) then n = Consulta(GetItemCount, id, true) end
  end
  if CuentaValida(n) and n > 0 then return "objeto" end
  if aprendido == false and not (categoria == "juguetes" and (e.tipoJugueteSinConfirmar977 or e.temporal977)) and (not id or (CuentaValida(n) and n == 0)) then return "ausente" end
  return "desconocido"
end
-- Instantáneas exclusivamente de interfaz: nunca persistir estados entre personajes.
local instantaneas, identidad = {}, nil
local nombresSolicitados = {}
local function Identidad()
  local guid = Consulta(UnitGUID, "player")
  if type(guid) == "string" and guid ~= "" then return guid end
  local nombre = Consulta(UnitName, "player")
  local reino = Retorno(2, UnitName, "player")
  if not TextoValido(reino) then reino = Consulta(GetRealmName) end
  if TextoValido(nombre) and TextoValido(reino) then return nombre .. "@" .. reino end
end
local function Invalidar(categoria)
  if categoria then instantaneas[categoria] = nil else instantaneas = {} end
end
local function EstadosLista(lista)
  local actual = Identidad()
  if actual ~= identidad then Invalidar(); identidad = actual; nombresSolicitados = {} end
  local cache = instantaneas[tipo]
  if actual and cache and cache.lista == lista then return cache end
  cache = { lista = lista, estados = {}, tengo = 0, objetos = 0, desconocidos = 0 }
  for _, e in ipairs(lista) do
    local estado = Estado(e, tipo); cache.estados[e] = estado
    if estado == "aprendido" then cache.tengo = cache.tengo + 1
    elseif estado == "objeto" then cache.objetos = cache.objetos + 1
    elseif estado == "desconocido" then cache.desconocidos = cache.desconocidos + 1 end
  end
  if actual then instantaneas[tipo] = cache end
  return cache
end
local function Tiene(e)
  local estado = Estado(e)
  return estado == "aprendido" or estado == "objeto"
end
local function TextoEstado(estado)
  if estado == "aprendido" then return C.VERDE .. L"Aprendido en la colección" .. C.FIN end
  if estado == "objeto" then return C.AMARILLO .. L"Objeto en posesión; aprendizaje sin confirmar" .. C.FIN end
  if estado == "ausente" then return L"no la tienes" end
  return C.AMARILLO .. L"Estado de colección sin confirmar" .. C.FIN
end

local function Icono(e)
  local function Valido(t) return IdValido(t) or TextoValido(t) end
  local t
  if IdValido(e.id) then
    t = Consulta(C_Item and C_Item.GetItemIconByID, e.id)
    if Valido(t) then return t end
    t = Consulta(GetItemIcon, e.id)
    if Valido(t) then return t end
  end
  if IdValido(e.hechizo) then
    t = Consulta(C_Spell and C_Spell.GetSpellTexture, e.hechizo)
    if Valido(t) then return t end
    t = Consulta(GetSpellTexture, e.hechizo)
    if Valido(t) then return t end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- 7.9.2: este cliente puede no tener GetItemInfo global; se prueba C_Item y se pide el objeto al servidor
local function Nombre(e, limitar)
  if TextoValido(e.n) then return L(e.n) end
  if not IdValido(e.id) then
    if IdValido(e.hechizo) then
      local n = Consulta(C_Spell and C_Spell.GetSpellName, e.hechizo)
      if not TextoValido(n) then n = Consulta(GetSpellInfo, e.hechizo) end
      if TextoValido(n) then return n .. (GL.ingles ~= GL.clienteIngles and (" (" .. L"idioma del cliente" .. ")") or "") end
    end
    return L"Nombre sin confirmar"
  end
  local function NombreValido(f)
    local n = Consulta(f, e.id)
    if TextoValido(n) then return n end
  end
  local nombre = NombreValido(C_Item and C_Item.GetItemNameByID) or NombreValido(C_Item and C_Item.GetItemInfo) or NombreValido(GetItemInfo)
  if nombre then return nombre .. (GL.ingles ~= GL.clienteIngles and (" (" .. L"idioma del cliente" .. ")") or "") end
  if C_Item and C_Item.RequestLoadItemDataByID then
    -- No repetir peticiones del mismo objeto en cada repintado; el sondeo rearma los fallidos.
    if not limitar or not nombresSolicitados[e.id] then
      if limitar then nombresSolicitados[e.id] = true end
      pcall(C_Item.RequestLoadItemDataByID, e.id)
    end
  end
  return "?"
end

-- IDs de facción independientes de la traducción del nombre. No confundir con índices del diario.
local REP_IDS = { ["Ventormenta"]=72, ["Forjaz"]=47, ["Gnomeregan"]=54, ["Darnassus"]=69,
  ["Orgrimmar"]=76, ["Trols Lanza Negra"]=530, ["Cima del Trueno"]=81, ["Entrañas"]=68,
  ["Nightclaw Druids"]=2758 }
local REP_RANGOS = { ["Odiado"]=1, ["Hostil"]=2, ["Adverso"]=3, ["Neutral"]=4, ["Amistoso"]=5, ["Honorable"]=6,
  ["Venerado"]=7, ["Reverenciado"]=7, ["Exaltado"]=8 }
local function RequisitoReputacion(e)
  if type(e.repPorLado977) == "table" then return e.repPorLado977[Lado()] end
  return e.rep
end
local function EstadoReputacion(e)
  local rep = RequisitoReputacion(e)
  if type(rep) ~= "table" then return e.repPorLado977 and "desconocido" or nil end
  if e.razaMontura977 and RazaActual() == e.razaMontura977 then return nil end
  if GL.EstadoRequisitoReputacion977 then return GL.EstadoRequisitoReputacion977(rep) end
  local requerido = REP_RANGOS[rep.nivel]
  local id = rep.id or REP_IDS[rep.n]
  if not id or not requerido then return "desconocido" end
  local d = Consulta(C_Reputation and C_Reputation.GetFactionDataByID, id)
  local rango = type(d) == "table" and d.reaction or nil
  local function Valido(v) return IdValido(v) and v <= 8 end
  if not Valido(rango) then rango = Retorno(3, GetFactionInfoByID, id) end
  if not Valido(rango) then return "desconocido" end
  return rango >= requerido and "cumple" or "insuficiente"
end
local function ReputacionMontura(e)
  local rep = RequisitoReputacion(e)
  if not rep then return e.repPorLado977 and L"Exaltado con la organización comercial de tu facción; facción sin confirmar." or nil end
  if e.razaMontura977 then
    local raza = RazaActual()
    if raza == e.razaMontura977 then return L"Tu raza: no se exige Exaltado para la montura racial." end
    local texto = L(e.rep.n or "?") .. " — " .. L(e.rep.nivel or "?")
    if not raza then return texto .. " · " .. L"Solo para otra raza; raza del personaje sin confirmar." end
    return texto .. " · " .. L"Requiere aprender la equitación de esa raza (100 o de base)."
  end
  return L(rep.n or "?") .. " — " .. L(rep.nivel or "?")
end
local function TextoFicha(e, estado)
  local l = { C.GRIS .. (PESTANAS[1][1] == tipo and L"montura" or (tipo == "mascotas" and L"mascota" or L"juguete")) .. " · " ..
    TextoEstado(estado or Estado(e)) .. C.FIN }
  if e.como or e.donde then table.insert(l, C.AMARILLO .. L"Dónde: " .. C.FIN .. (e.como and (L(e.como) .. ". ") or "") .. (e.donde and L(e.donde) or "")) end
  if tipo == "mascotas" and e.lado then
    table.insert(l, C.AMARILLO .. L"Facción de la fuente: " .. C.FIN .. (e.lado == "A" and L"Alianza" or L"Horda"))
    if Lado() ~= e.lado then table.insert(l, L"Origen de otra facción o facción sin confirmar; comprueba otras vías de obtención.") end
  end
  if tipo == "juguetes" then
    if e.tipoJugueteSinConfirmar977 then table.insert(l, C.AMARILLO .. L"Objeto utilitario; pertenencia al diario de juguetes sin confirmar." .. C.FIN) end
    if e.temporal977 then table.insert(l, C.AMARILLO .. L"Juguete temporal: Blizzard anuncia su retirada al terminar el evento de lanzamiento a principios de diciembre de 2026." .. C.FIN) end
    if e.ladoUso977 then table.insert(l, C.AMARILLO .. L"Facción de uso: " .. C.FIN .. (e.ladoUso977 == "A" and L"Alianza" or L"Horda")) end
  end
  if e.pendienteObtencion977 then
    table.insert(l, C.AMARILLO .. L"Disponibilidad o método de obtención sin confirmar; no se recomienda viajar por esta ficha." .. C.FIN)
  end
  if CuentaValida(e.precio) then
    local etiqueta = e.razaMontura977 and L"Precio base de montura adicional: " or L"Precio: "
    table.insert(l, C.AMARILLO .. etiqueta .. C.FIN .. ((GL.Dinero and GL.Dinero(e.precio)) or (e.precio .. " c")))
  end
  if e.razaMontura977 then
    if e.nivel == 40 then table.insert(l, L"Equitación de aprendiz: 100 o; primera montura de tu raza por misión, sin coste adicional. Descuentos según reputación.")
    elseif e.nivel == 60 then table.insert(l, L"Equitación avanzada: 1000 o de base; montura aparte. Descuentos según reputación.") end
    if not e.rep and RazaActual() ~= e.razaMontura977 then table.insert(l, L"Equitación racial adicional: comprueba reputación y vendedor.") end
  end
  if e.clase977 then
    table.insert(l, L"Montura de clase: cadena de misión y equitación del nivel correspondiente; la cadena épica puede requerir materiales de pago.")
    if e.mision977 then table.insert(l, L"Misión (ID): " .. e.mision977) end
  end
  local rep = ReputacionMontura(e)
  if rep then
    table.insert(l, C.AMARILLO .. L"Reputación: " .. C.FIN .. rep)
    local estadoRep = EstadoReputacion(e)
    if estadoRep then table.insert(l, L(estadoRep == "cumple" and "Reputación requerida alcanzada." or (estadoRep == "insuficiente" and "Reputación requerida aún no alcanzada." or "Reputación actual sin confirmar."))) end
  end
  if IdValido(e.nivel) then
    table.insert(l, C.AMARILLO .. L"Nivel: " .. C.FIN .. e.nivel)
    local actual = Consulta(UnitLevel, "player")
    if IdValido(actual) and actual < e.nivel then table.insert(l, L"Nivel requerido aún no alcanzado.") end
  end
  local d = FuenteDestino(e)
  if CoordenadasValidas(d) then
    table.insert(l, C.AMARILLO .. L"Coordenadas: " .. C.FIN .. string.format("%.1f, %.1f", d.x, d.y) .. (d.zona and (" · " .. L(d.zona)) or ""))
    if not DestinoNavegacion(e) then table.insert(l, L"Mapa sin confirmar; navegación no disponible.") end
  end
  if e.como == "Vendedor" and not CuentaValida(e.precio) then table.insert(l, L"Consulta el coste y la moneda en el vendedor.") end
  table.insert(l, C.GRIS .. L"Fuente: " .. L(e.fuente977 or (e.comprobado and "QuestieDB (Forever)" or "Wowhead")) .. C.FIN)
  return table.concat(l, "\n")
end

local function Filas()
  local alto = (panel:GetHeight() or 400) - 54 - (ui.altoFicha or ALTO_FICHA) - 8
  return math.max(1, math.floor(alto / ALTO_CELDA))
end

local function Refrescar()
  if not panel or not panel:IsShown() or (panel.IsVisible and not panel:IsVisible()) then return end
  local lista = Lista()
  local cache = EstadosLista(lista)
  local tengo, objetos, desconocidos, estados = cache.tengo, cache.objetos, cache.desconocidos, cache.estados
  for i = 1, #ui.pest do ui.pest[i]:SetActivo(ui.pest[i].clave == tipo) end
  local nombreTipo = L(tipo)
  ui.titulo:SetText(L"Colección" .. C.GRIS .. " · " .. tengo .. "/" .. #lista .. " " .. L"aprendidos" .. C.FIN)
  local resumen = objetos > 0 and (objetos .. " " .. L"en posesión") or ""
  if desconocidos > 0 then resumen = resumen .. (resumen ~= "" and " · " or "") .. desconocidos .. " " .. L"sin confirmar" end
  -- 7.9.2: la ficha crece con su texto (antes Llevarme tapaba las últimas líneas) y la cuadrícula se queda con el resto
  local valida = false
  for i = 1, #lista do if lista[i] == sel then valida = true end end
  if not valida then sel = nil end
  ui.altoFicha = ALTO_FICHA
  if sel then
    ui.fichaTitulo:SetText(string.upper(Nombre(sel, true)))
    ui.fichaTexto:SetText(TextoFicha(sel, estados[sel]))
    local boton = DestinoNavegacion(sel) ~= nil
    GL.Mostrar(ui.llevar, boton)
    ui.altoFicha = math.max(ALTO_FICHA, math.ceil(24 + (ui.fichaTexto:GetStringHeight() or 0) + 8 + (boton and 28 or 0)))
    ui.ficha:SetHeight(ui.altoFicha)
    ui.ficha:Show()
  else
    ui.ficha:Hide()
  end
  ui.vacio:ClearAllPoints()
  ui.vacio:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, ui.altoFicha + 8)
  ui.vacio:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  local filas = Filas()
  local total = math.ceil(#lista / COLUMNAS)
  desde = math.max(0, math.min(desde, total - filas))
  local ancho = ((panel:GetWidth() or 400)) / COLUMNAS
  for i = 1, #ui.celdas do ui.celdas[i]:Hide() end
  local n = 0
  for f = 0, filas - 1 do
    for c = 0, COLUMNAS - 1 do
      local k = (desde + f) * COLUMNAS + c + 1
      local e = lista[k]
      if e then
        n = n + 1
        local celda = ui.celdas[n]
        if not celda then celda = ui.CrearCelda(); ui.celdas[n] = celda end
        celda.e = e
        celda:SetWidth(ancho - 4)
        celda:ClearAllPoints()
        celda:SetPoint("TOPLEFT", panel, "TOPLEFT", c * ancho + 2, -54 - f * ALTO_CELDA)
        celda.icono:SetTexture(Icono(e))
        local estado = estados[e]
        local tiene = estado == "aprendido"
        local pendiente = estado == "objeto" or estado == "desconocido"
        if celda.icono.SetDesaturated then celda.icono:SetDesaturated(estado == "ausente") end
        celda.icono:SetVertexColor(tiene and 1 or 0.75, tiene and 1 or 0.75, tiene and 1 or 0.75)
        if GL.Caja then
          GL.Caja(celda.marco, { 0, 0, 0, 0 }, (sel == e and { 1, 0.82, 0, 1 }) or (tiene and { 0.25, 0.85, 0.35, 0.9 }) or (pendiente and { 0.85, 0.67, 0.2, 0.9 }) or { 0.45, 0.45, 0.45, 0.8 })
        end
        celda.nombre:SetText((pendiente and C.AMARILLO or (tiene and "" or C.GRIS)) .. Nombre(e, true) .. (pendiente and " [?]" or "") .. C.FIN)
        celda:Show()
      end
    end
  end
  if #lista == 0 then
    ui.vacio:SetText(C.GRIS .. L"No hay " .. nombreTipo .. L" en esta lista." .. C.FIN)
  elseif total > filas then
    ui.vacio:SetText(C.GRIS .. L"Filas " .. (desde + 1) .. "-" .. math.min(total, desde + filas) .. L" de " .. total .. L" (rueda del ratón)" .. (resumen ~= "" and " · " .. resumen or "") .. C.FIN)
  else
    ui.vacio:SetText(resumen)
  end
end

local function CrearCelda()
  local b = CreateFrame("Button", nil, panel)
  b:SetHeight(ALTO_CELDA - 4)
  b.marco = CreateFrame("Frame", nil, b, PLANTILLA)
  b.marco:SetWidth(LADO_ICONO + 4); b.marco:SetHeight(LADO_ICONO + 4)
  b.marco:SetPoint("TOP", b, "TOP", 0, 0)
  b.icono = b:CreateTexture(nil, "ARTWORK")
  b.icono:SetWidth(LADO_ICONO); b.icono:SetHeight(LADO_ICONO)
  b.icono:SetPoint("CENTER", b.marco, "CENTER", 0, 0)
  b.nombre = GL.Texto(b, "GameFontHighlightSmall", "CENTER")
  b.nombre:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -LADO_ICONO - 6)
  b.nombre:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -LADO_ICONO - 6)
  if b.nombre.SetMaxLines then b.nombre:SetMaxLines(2) end
  b:SetScript("OnClick", function(self)
    sel = (sel ~= self.e) and self.e or nil
    Refrescar()
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.e or not (self.e.id or self.e.hechizo) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.e.id then
      if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.e.id) else GameTooltip:SetHyperlink("item:" .. self.e.id) end
    elseif GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(self.e.hechizo)
    elseif GameTooltip.SetText then GameTooltip:SetText(Nombre(self.e)) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  ui.CrearCelda = CrearCelda

  ui.titulo = GL.Texto(panel, "GameFontNormal")
  ui.titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  ui.titulo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0); GL.UnaLinea(ui.titulo)   -- 7.6.1: dentro del marco
  for i = 1, #PESTANAS do
    local clave = PESTANAS[i][1]
    local b = GL.CrearBoton(panel, L(PESTANAS[i][2]), function() tipo, desde, sel = clave, 0, nil; Refrescar() end, nil, 20)
    b:SetWidth(84)
    b.clave = clave
    if i == 1 then b:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22) else b:SetPoint("LEFT", ui.pest[i - 1], "RIGHT", 4, 0) end
    ui.pest[i] = b
  end
  ui.vacio = GL.Texto(panel, "GameFontHighlightSmall")
  ui.vacio:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, ALTO_FICHA + 8)
  ui.vacio:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

  local ficha = CreateFrame("Frame", nil, panel, PLANTILLA)
  ficha:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 4)
  ficha:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
  ficha:SetHeight(ALTO_FICHA)
  if GL.Caja and GL.COLOR then GL.Caja(ficha, GL.COLOR.caja, GL.COLOR.cajaBorde) end
  local borde = ficha:CreateTexture(nil, "ARTWORK")
  borde:SetWidth(3)
  borde:SetPoint("TOPLEFT", ficha, "TOPLEFT", 0, 0)
  borde:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 0, 0)
  borde:SetColorTexture(1, 0.78, 0.25, 1)
  ui.fichaTitulo = GL.Texto(ficha, "GameFontNormalSmall")
  ui.fichaTitulo:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -8)
  ui.fichaTitulo:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -8, -8); GL.UnaLinea(ui.fichaTitulo)   -- 7.6.1: dentro del marco
  ui.fichaTexto = GL.Texto(ficha, "GameFontHighlightSmall")
  ui.fichaTexto:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, -24)
  ui.fichaTexto:SetPoint("RIGHT", ficha, "RIGHT", -8, 0)
  if ui.fichaTexto.SetSpacing then ui.fichaTexto:SetSpacing(2) end
  ui.llevar = GL.CrearBoton(ficha, L"Llevarme", function()
    local d = DestinoNavegacion(sel)
    if d and GL.SeguirDesvio then d.n = Nombre(sel); GL.SeguirDesvio(d) end
  end, nil, 20, "accion")
  ui.llevar:SetWidth(110)
  ui.llevar:SetPoint("BOTTOMLEFT", ficha, "BOTTOMLEFT", 12, 8)
  ficha:Hide()
  ui.ficha = ficha

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta) desde = math.max(0, desde - delta); Refrescar() end)
  panel:SetScript("OnSizeChanged", function() Refrescar() end)
  local espera, demora, sucio = 0, 0, false
  local porTipo = {
    NEW_MOUNT_ADDED="monturas", MOUNT_JOURNAL_USABILITY_CHANGED="monturas", SPELLS_CHANGED="monturas",
    NEW_PET_ADDED="mascotas", PET_JOURNAL_LIST_UPDATE="mascotas", PET_JOURNAL_PET_DELETED="mascotas",
    NEW_TOY_ADDED="juguetes", TOYS_UPDATED="juguetes",
  }
  local generales = { COMPANION_UPDATE=true, PLAYER_ENTERING_WORLD=true, PLAYER_LOGIN=true, BAG_UPDATE_DELAYED=true, BANKFRAME_OPENED=true,
    BANKFRAME_CLOSED=true, PLAYERBANKSLOTS_CHANGED=true, UPDATE_FACTION=true, PLAYER_LEVEL_UP=true, SKILL_LINES_CHANGED=true }
  local metadatos = { GET_ITEM_INFO_RECEIVED=true, ITEM_DATA_LOAD_RESULT=true }
  for _, grupo in ipairs({porTipo, generales, metadatos}) do
    for evento in pairs(grupo) do pcall(panel.RegisterEvent, panel, evento) end
  end
  panel:SetScript("OnEvent", function(_, evento, id, exito)
    if porTipo[evento] then
      Invalidar(porTipo[evento])
      if porTipo[evento] == tipo then sucio = true end
    elseif generales[evento] then
      Invalidar(); sucio = true
      if evento == "PLAYER_ENTERING_WORLD" or evento == "PLAYER_LOGIN" then nombresSolicitados = {}; identidad = nil end
    elseif metadatos[evento] and IdValido(id) and Publico(exito) and exito ~= false then
      -- Puede terminar de cargar un objeto de una pestaña que ya no está activa.
      -- Invalidar solo las categorías que lo contienen, sin consultar diarios ocultos.
      local coleccion = GL.WH and GL.WH.coleccion or {}
      for _, categoria in ipairs({"monturas", "mascotas", "juguetes"}) do
        for _, e in ipairs(coleccion[categoria] or {}) do
          if e.id == id then
            Invalidar(categoria)
            if categoria == tipo then sucio = true end
            break
          end
        end
      end
    end
  end)
  panel:SetScript("OnShow", function()
    Invalidar(); nombresSolicitados = {}; espera, demora, sucio = 0, 0, false
    Refrescar()
  end)
  panel:SetScript("OnHide", function()
    Invalidar(); nombresSolicitados = {}; espera, demora, sucio = 0, 0, false
  end)
  panel:SetScript("OnUpdate", function(_, dt)
    if not panel:IsShown() or (panel.IsVisible and not panel:IsVisible()) then return end
    espera, demora = espera + dt, demora + dt
    -- Compatibilidad con clientes sin todos los eventos: sondeo limitado y solo visible.
    if espera >= 10 then
      espera = 0; Invalidar(); nombresSolicitados = {}; sucio = true
    end
    -- Agrupar ráfagas de eventos sin programar temporizadores que sobrevivan al cierre.
    if sucio and demora >= 0.25 then demora, sucio = 0, false; Refrescar() end
  end)
  GL.modos.coleccion = { panel = panel, refrescar = Refrescar }
end

-- 9.0: se crea al abrirla por primera vez (Ajustes › General › Cargar cada sección al abrirla)
GL.perezosos = GL.perezosos or {}
GL.perezosos.coleccion = CrearPanel
table.insert(GL.alIniciar, function() if type(GuiaAventureroDB) == "table" and GuiaAventureroDB.cargarAlAbrir == false then CrearPanel() end end)

-- Para las pruebas
GL._coleccion = { Identidad = Identidad, Icono = Icono, DestinoNavegacion = DestinoNavegacion, EstadoReputacion = EstadoReputacion, Lista = Lista, Destino = DestinoColeccion, Ficha = TextoFicha, Tiene = Tiene, Estado = Estado, Nombre = Nombre, TextoEstado = TextoEstado, Elegir = function(t, e) tipo, sel = t or tipo, e; Refrescar() end, Refrescar = function() Refrescar() end }

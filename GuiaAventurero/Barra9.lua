-- Barra9.lua (9.0): lo que va en la barra lateral y en toda la ventana.
--  · Contadores en los iconos: rojo urgente, amarillo útil, verde oportunidad; al pasar el ratón dice qué es.
--  · Buscador (lupa): misiones, PNJ, objetos de misión, mazmorras y ajustes a la vez, por tipo.
--  · Icono Grupo: solo en grupo; en qué paso va cada compañero con la guía y las misiones que compartís.
--  · Modo daltónico (rojo-verde o azul-amarillo) y el tutorial de la 9.0 (tres pantallas).
--  · /ga memoria: cuánto ocupa el addon y qué secciones están cargadas.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local function DB() return GuiaAventureroDB or {} end
local function Si(k) return DB()[k] ~= false end
local function Num(v) v = (GL.Seguro and GL.Seguro(v)) or v; return type(v) == "number" and v or nil end
local function Nivel() return Num(UnitLevel and UnitLevel("player")) or 1 end
local function Minus(s)
  if GL.NormalizarBusqueda97 then return GL.NormalizarBusqueda97(s) end
  if type(s) ~= "string" then return "" end
  for a,b in pairs({["á"]="a",["é"]="e",["í"]="i",["ó"]="o",["ú"]="u",["ü"]="u",["ñ"]="n",["Á"]="a",["É"]="e",["Í"]="i",["Ó"]="o",["Ú"]="u",["Ü"]="u",["Ñ"]="n"}) do s=s:gsub(a,b) end
  return s:lower():match("^%s*(.-)%s*$")
end

------------------------------------------------------------------------
-- Contadores
------------------------------------------------------------------------
local COL_CONT = { urgente = { 0.85, 0.20, 0.18 }, util = { 0.95, 0.70, 0.10 }, oportunidad = { 0.20, 0.70, 0.30 } }
GL.COLORES_CONTADOR = COL_CONT

local function Contador(b)
  if rawget(b, "gContador") then return b.gContador end
  local i = CreateFrame("Frame", nil, b)
  i:SetSize(15, 13)
  i:SetPoint("TOPRIGHT", b, "TOPRIGHT", 1, 1)
  i:SetFrameLevel((b:GetFrameLevel() or 1) + 6)
  i.fondo = i:CreateTexture(nil, "ARTWORK")
  i.fondo:SetAllPoints()
  i.texto = i:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  i.texto:SetPoint("CENTER", i, "CENTER", 0, 0)
  i:Hide()
  b.gContador = i
  if b.ayudaTexto ~= nil or b.ayudaTitulo ~= nil then b.ayudaBase = b.ayudaTexto or "" end
  return i
end

local function Poner(b, n, tipo, explica)
  if not b then return end
  local i = Contador(b)
  if b.ayudaBase == nil then b.ayudaBase = b.ayudaTexto or "" end
  if not n or n <= 0 or not Si("insignias") then
    i:Hide()
    b.ayudaTexto = b.ayudaBase
    return
  end
  local c = COL_CONT[tipo] or COL_CONT.util
  i.fondo:SetColorTexture(c[1], c[2], c[3], 1)
  i.texto:SetText(n > 9 and "9+" or tostring(n))
  i:SetWidth(n > 9 and 19 or 15)
  i:Show()
  b.ayudaTexto = (b.ayudaBase ~= "" and (b.ayudaBase .. "\n") or "") .. string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) .. n .. "|r  " .. (explica or "")
end

local function Boton(clave)
  local ui = GL.ui
  if not ui then return nil end
  for _, lista in ipairs({ ui.modos or {}, ui.lado or {} }) do
    for _, b in ipairs(lista) do if b.clave == clave then return b end end
  end
  return nil
end

local function MaterialesQueFaltan()
  local R = GL.RUTA
  if not (R and R.profesiones and GL.NivelProfesion and GL.InventarioProfesion975) then return 0 end
  local faltan = 0
  for _, prof in ipairs(R.profesiones) do
    local ok, nivel = pcall(GL.NivelProfesion, prof)
    if ok and nivel then
      for _, paso in ipairs(prof.pasos or {}) do
        if nivel >= paso.d and nivel < paso.h then
          for _, m in ipairs(paso.mat or {}) do
            if m[2] and m[2] > 0 then
              local tengo = GL.InventarioProfesion975(m[1])
              if tengo ~= nil and tengo < (GL.NecesarioProfesion975 and GL.NecesarioProfesion975(paso, m, nivel) or m[2] * math.max(1, paso.h - nivel)) then faltan = faltan + 1 end
            end
          end
          break
        end
      end
    end
  end
  return faltan
end

local function MazmorrasANivel()
  if not GL.DatosMazmorras then return 0 end
  local ok, datos = pcall(GL.DatosMazmorras)
  if not ok or type(datos) ~= "table" then return 0 end
  local n, nv = 0, Nivel()
  for _, m in ipairs(datos) do if m.min <= nv and nv <= m.max and #(m.misiones or {}) > 0 then n = n + 1 end end
  return n
end

local cacheCont = { t = -100 }
local function Contadores()
  local ahora = (GetTime and GetTime()) or 0
  local db = DB()
  -- Guía: avisos urgentes (la cuenta la hace la tarjeta de avisos)
  local urg = GL._avisosUrgentes or 0
  Poner(Boton("guia"), (db.modo ~= "guia") and urg or 0, "urgente", urg == 1 and L"aviso urgente en la Guía" or L"avisos urgentes en la Guía")
  if ahora - cacheCont.t > 5 then
    cacheCont.t = ahora
    local okM, mat = pcall(MaterialesQueFaltan)
    cacheCont.mat = okM and mat or 0
    local okZ, maz = pcall(MazmorrasANivel)
    cacheCont.maz = okZ and maz or 0
  end
  Poner(Boton("oficios"), cacheCont.mat, "util", cacheCont.mat == 1 and L"material que te falta para el tramo de tu profesión" or L"materiales que te faltan para el tramo de tus profesiones")
  local vistaMaz = db.mazVista == Nivel()
  if db.modo == "mazmorras" then db.mazVista = Nivel(); vistaMaz = true end
  Poner(Boton("mazmorras"), vistaMaz and 0 or cacheCont.maz, "oportunidad", cacheCont.maz == 1 and L"mazmorra de tu nivel con misiones" or L"mazmorras de tu nivel con misiones")
  -- Grupo: compañeros con la guía
  local b = GL._botonGrupo
  if b then
    local n = 0
    for _, c in pairs((GL.Companeros and GL.Companeros()) or {}) do if (((GetTime and GetTime()) or 0) - (c.t or 0)) < 180 then n = n + 1 end end
    Poner(b, n, "oportunidad", n == 1 and L"compañero con la guía" or L"compañeros con la guía")
  end
end

------------------------------------------------------------------------
-- Grupo
------------------------------------------------------------------------
local grupo = { filas = {} }
local function CrearGrupo()
  if grupo.panel or not GL.frame then return end
  local frame = GL.frame
  local p = CreateFrame("Frame", nil, frame)
  p:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)
  p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  p:Hide()
  grupo.panel = p
  grupo.titulo = GL.Texto(p, "GameFontNormalLarge")
  grupo.titulo:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  grupo.titulo:SetText(L"Grupo")
  grupo.sub = GL.Texto(p, "GameFontHighlightSmall")
  grupo.sub:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -22)
  grupo.cabMis = GL.Texto(p, "GameFontHighlightSmall")
  grupo.mis = GL.Texto(p, "GameFontHighlightSmall")
  grupo.nota = GL.Texto(p, "GameFontHighlightSmall")
  grupo.nota:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 4)
  grupo.nota:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 4)
  grupo.nota:SetText(C.GRIS .. L"Usa «Compartir tu paso con el grupo» (Ajustes › Avisos). Los compañeros sin el addon salen sin paso." .. C.FIN)
  grupo.avisar = GL.CrearBoton(p, L"Enviar mi paso ahora", function() if GL.EnviarGrupo then GL.EnviarGrupo() end end, nil, 20)
  grupo.avisar:SetWidth(150)
  if GL.CompartirMisionesGrupo then   -- 9.4
    grupo.compartir = GL.CrearBoton(p, L"Compartir misiones", function() GL.CompartirMisionesGrupo() end, nil, 20)
    grupo.compartir:SetWidth(150)
    grupo.compartir:SetPoint("LEFT", grupo.avisar, "RIGHT", 6, 0)
    GL.Ayuda(grupo.compartir, L"Compartir misiones", L"Comparte con el grupo las misiones de tu diario que algún compañero con la guía no lleva.")
  end
  local espera = 0
  p:SetScript("OnUpdate", function(_, dt) espera = espera + dt; if espera > 2 then espera = 0; pcall(GL.RefrescarGrupo) end end)
  GL.modos.grupo = { panel = p, refrescar = function() GL.RefrescarGrupo() end }
end

local function Miembros()
  local l = {}
  local n = Num(GetNumGroupMembers and GetNumGroupMembers()) or 0
  local raid = IsInRaid and IsInRaid()
  for i = 1, math.max(0, raid and n or (n - 1)) do
    local u = raid and ("raid" .. i) or ("party" .. i)
    local nombre = UnitName and UnitName(u)
    if nombre and nombre ~= (UnitName and UnitName("player")) then table.insert(l, { u = u, n = nombre, nivel = Num(UnitLevel and UnitLevel(u)) }) end
  end
  return l
end

function GL.RefrescarGrupo()
  local p = grupo.panel
  if not p or not p:IsShown() then return end
  local db = DB()
  local comp = (GL.Companeros and GL.Companeros()) or {}
  local ahora = (GetTime and GetTime()) or 0
  local miembros = Miembros()
  local con = 0
  for _, m in ipairs(miembros) do local c = comp[m.n]; if c and ahora - (c.t or 0) < 180 then con = con + 1 end end
  grupo.sub:SetText(C.GRIS .. (con + 1) .. L" de " .. (#miembros + 1) .. L" lleváis Guía del Aventurero" .. C.FIN)
  for _, f in ipairs(grupo.filas) do f:Hide() end
  local function Fila(i)
    local f = grupo.filas[i]
    if not f then
      f = CreateFrame("Frame", nil, p, PLANTILLA)
      f:SetHeight(34)
      GL.Caja(f, GL.COLOR.caja, GL.COLOR.cajaBorde)
      f.nivel = GL.Texto(f, "GameFontNormal")
      f.nivel:SetPoint("LEFT", f, "LEFT", 8, 0)
      f.nombre = GL.Texto(f, "GameFontHighlight")
      f.nombre:SetPoint("TOPLEFT", f, "TOPLEFT", 36, -5)
      f.paso = GL.Texto(f, "GameFontHighlightSmall")
      f.paso:SetPoint("TOPLEFT", f, "TOPLEFT", 36, -19)
      f.paso:SetPoint("RIGHT", f, "RIGHT", -46, 0)
      f.ir = GL.CrearBoton(f, L"Ir", function(self) local fila = self:GetParent(); if GL.IrACompanero then GL.IrACompanero(fila.unidad, fila.quien) end end, nil, 16, "accion")   -- 9.4
      f.ir:SetWidth(34)
      f.ir.texto:SetJustifyH("CENTER")
      f.ir:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 4)
      GL.Ayuda(f.ir, L"Ir", L"La flecha te lleva a donde está tu compañero.")
      if f.paso.SetWordWrap then f.paso:SetWordWrap(false) end
      f.rel = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
      f.rel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
      grupo.filas[i] = f
    end
    return f
  end
  local y = 42
  local function Pintar(i, nombre, nivel, s, pp, rel, tu, unidad)
    local f = Fila(i)
    f.unidad, f.quien = unidad, nombre
    GL.Mostrar(f.ir, unidad ~= nil and GL.IrACompanero ~= nil)
    f.nivel:SetText(C.AMARILLO .. (nivel or "?") .. C.FIN)
    f.nombre:SetText(C.BLANCO .. nombre .. C.FIN .. (tu and (C.GRIS .. L" (tú)" .. C.FIN) or ""))
    local texto = C.GRIS .. L"sin el addon" .. C.FIN
    if s and pp and GL.RUTA and GL.RUTA.secciones[s] then
      local paso = GL.RUTA.secciones[s].pasos[pp]
      local t = paso and (paso.t or ""):gsub("%[(.-)%]", "«%1»"):gsub("<(.-)>", "%1") or ""
      t = t:match("^(.-[%.:])%s") or t
      texto = C.GRIS .. L"Paso " .. pp .. "/" .. #GL.RUTA.secciones[s].pasos .. " · " .. C.FIN .. t
    end
    f.paso:SetText(texto)
    f.rel:SetText(rel or "")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y)
    f:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -y)
    f:Show()
    y = y + 38
  end
  Pintar(1, (UnitName and UnitName("player")) or "?", Nivel(), db.seccion, db.paso, nil, true)
  for i, m in ipairs(miembros) do
    local c = comp[m.n]
    if c and ahora - (c.t or 0) >= 180 then c = nil end
    local rel
    if c and c.s == db.seccion then
      local d = (c.p or 0) - (db.paso or 0)
      if d > 0 then rel = C.AMARILLO .. L"va " .. d .. (d == 1 and L" paso" or L" pasos") .. L" por delante" .. C.FIN
      elseif d < 0 then rel = C.GRIS .. L"va " .. (-d) .. (d == -1 and L" paso" or L" pasos") .. L" por detrás" .. C.FIN
      else rel = C.VERDE .. L"mismo paso" .. C.FIN end
    elseif c and c.s then
      rel = C.GRIS .. L"sección " .. c.s .. C.FIN
    end
    Pintar(i + 1, m.n, m.nivel, c and c.s, c and c.p, rel, nil, m.u)
  end
  -- misiones que compartís y las que tienen ellos y tú no
  local mias = (GL.MisMisionesGrupo and GL.MisMisionesGrupo()) or {}
  local tengo = {}
  for _, q in ipairs(mias) do tengo[q.id] = q.n or tostring(q.id) end
  local l = {}
  for _, q in ipairs(mias) do
    local quien = {}
    for nombre, c in pairs(comp) do if c.qs and c.qs[q.id] then table.insert(quien, nombre) end end
    if #quien > 0 then table.insert(l, C.AMARILLO .. "• " .. (q.n or q.id) .. C.FIN .. C.GRIS .. L"  también: " .. table.concat(quien, ", ") .. C.FIN) end
  end
  for _, q in ipairs(mias) do
    local faltan = {}
    for nombre, c in pairs(comp) do if c.qs and not c.qs[q.id] then table.insert(faltan, nombre) end end
    if #faltan > 0 and #l < 8 then table.insert(l, "• " .. (q.n or q.id) .. C.GRIS .. L"  la puedes compartir con " .. table.concat(faltan, ", ") .. C.FIN) end
  end
  y = y + 6
  grupo.cabMis:ClearAllPoints()
  grupo.cabMis:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y)
  grupo.cabMis:SetText(C.GRIS .. L"MISIONES QUE COMPARTÍS" .. C.FIN)
  y = y + 16
  if #l == 0 then l[1] = C.GRIS .. L"Ninguna por ahora." .. C.FIN end
  while #l > 8 do table.remove(l) end
  local txt = table.concat(l, "\n")
  grupo.mis:ClearAllPoints()
  grupo.mis:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -y)
  grupo.mis:SetPoint("RIGHT", p, "RIGHT", -2, 0)
  grupo.mis:SetText(txt)
  y = y + ((GL.Alto and GL.Alto(grupo.mis, txt, 12, (p:GetWidth() or 360) - 4)) or #l * 14) + 8
  grupo.avisar:ClearAllPoints()
  grupo.avisar:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y)
end

local function MirarGrupo()
  local b = GL._botonGrupo
  if not b then return end
  local en = GL.EnGrupo and GL.EnGrupo()
  GL.Mostrar(b, en and true or false)
  if not en and DB().modo == "grupo" and GL.AbrirModo then GL.AbrirModo(DB().modoGuia or "guia") end
end

------------------------------------------------------------------------
-- Buscador
------------------------------------------------------------------------
local busca = { filas = {}, pagina = 1, filtro = 1 }
local function HabilitarBusca(b, si)
  if not b then return end
  if b.SetEnabled then b:SetEnabled(si) elseif si and b.Enable then b:Enable() elseif not si and b.Disable then b:Disable() end
  if b.SetAlpha then b:SetAlpha(si and 1 or 0.45) end
end
local function ControlesBusca(b, pendiente, pagina, paginas, capacidad)
  local disponible = not pendiente and capacidad > 0
  HabilitarBusca(b.prev, disponible and pagina > 1)
  HabilitarBusca(b.next, disponible and pagina < paginas)
end
local FILTROS_CATALOGO = { false, "Banda", "Jefe", "Botín", "Profesión", "Receta", "Material", "Misión" }
local TIPOS = { { "todo", L"Todo" }, { "mision", L"Misiones" }, { "pnj", "PNJ" }, { "mazmorra", L"Mazmorras" }, { "ajuste", L"Ajustes" }, { "catalogo", L"Catálogo" } }

local function Resultados(texto, filtroCatalogo)
  local r = { mision = {}, pnj = {}, mazmorra = {}, ajuste = {}, catalogo = {} }
  local t = Minus(texto)
  if #t < 3 and not tonumber(t) then return r end
  if GL.Catalogo976 then r.catalogo=GL.Catalogo976(texto,100,filtroCatalogo) end
  local R = GL.RUTA
  local vistos = {}
  local id = tonumber(t)
  local function coincide(nombre)
    return type(nombre)=="string" and (Minus(nombre):find(t,1,true) or Minus(L(nombre)):find(t,1,true))
  end
  for s, sec in ipairs((R and R.secciones) or {}) do
    for p, paso in ipairs(sec.pasos or {}) do
      for i, wp in ipairs(paso.wp or {}) do
        local n = wp.n or ""
        local mision = n:match("^[^:]+: (.-) %(") or n:match("^[^:]+: (.*)$")
        local pnj = n:match("%((.-)%)$")
        local porMision = id and id==tonumber(wp.q)
        local porPNJ = id and id==tonumber(wp.npc)
        local alias = wp.q and GL.misionesIngles and GL.misionesIngles[wp.q]
        if wp.q and mision and (porMision or coincide(mision) or coincide(alias)) then
          if not vistos["q" .. wp.q] then vistos["q" .. wp.q] = true; table.insert(r.mision, { n = mision, d = sec.titulo .. L" · paso " .. p, s = s, p = p, i = i }) end
        end
        local quien = pnj or ((wp.npc or not wp.q) and n) or nil
        if quien and (porPNJ or coincide(quien)) and not vistos["n" .. quien] then
          vistos["n" .. quien] = true
          table.insert(r.pnj, { n = quien, d = tostring(wp.z) .. " · " .. string.format("%.1f, %.1f", wp.x or 0, wp.y or 0), wp = wp })
        end
      end
    end
  end
  local okM, datos = pcall(function() return GL.DatosMazmorras and GL.DatosMazmorras() end)
  for _, m in ipairs((okM and datos) or {}) do
    if coincide(m.n) then table.insert(r.mazmorra, { n = m.n, d = L"niveles " .. m.min .. "-" .. m.max, m = m }) end
    for _, j in ipairs((GL.JefesVisibles976 and GL.JefesVisibles976(m.clave or m.n)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[m.clave or m.n]) or {}) do
      if coincide(j.n) or (id and id==tonumber(j.npc)) then table.insert(r.mazmorra, { n = j.n, d = L"jefe de " .. m.n, m = m, jefe = j.n, id = j.npc }) end
    end
  end
  for _, pe in ipairs(GL.PESTANAS_AJUSTES or {}) do
    for _, k in ipairs(pe.claves) do
      local etiqueta = not (GL.AJUSTES_QUITADOS and GL.AJUSTES_QUITADOS[k]) and GL.EtiquetaAjuste and GL.EtiquetaAjuste(k)
      if etiqueta and Minus(etiqueta):find(t, 1, true) then table.insert(r.ajuste, { n = etiqueta, d = L"Ajustes › " .. L(pe.nombre), pestana = pe.id, clave = k }) end
    end
  end
  return r
end

local function CrearBuscador()
  if busca.panel or not GL.frame then return end
  local frame = GL.frame
  local p = CreateFrame("Frame", nil, frame)
  p:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -GL.ARRIBA)
  p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  p:Hide()
  busca.panel = p
  local caja = CreateFrame("EditBox", nil, p, PLANTILLA)
  caja:SetHeight(24)
  caja:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  caja:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  caja:SetAutoFocus(false)
  caja:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  caja:SetTextInsets(8, 8, 0, 0)
  GL.Caja(caja, { 0, 0, 0, 0.4 }, GL.COLOR.acento)
  local pista = GL.Texto(caja, "GameFontDisableSmall")
  pista:SetPoint("LEFT", caja, "LEFT", 8, 0)
  pista:SetText(L"Busca misiones, PNJ, jefes o ajustes")
  caja:SetScript("OnTextChanged", function(self)
    GL.Mostrar(pista, (self:GetText() or "") == "" and not self:HasFocus())
    busca.pagina=1; busca.pendiente=true; ControlesBusca(busca,true,1,1,0); if busca.estado then busca.estado:SetText("") end; for _,f in ipairs(busca.filas) do f.e=nil; f:Hide() end; busca.generacion=(busca.generacion or 0)+1; local g=busca.generacion
    if C_Timer and C_Timer.After then C_Timer.After(0.18,function() if g==busca.generacion then GL.RefrescarBuscador() end end) else GL.RefrescarBuscador() end
  end)
  caja:SetScript("OnEditFocusGained", function() pista:Hide() end)
  caja:SetScript("OnEditFocusLost", function(self) GL.Mostrar(pista, (self:GetText() or "") == "") end)
  caja:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  caja:SetScript("OnEnterPressed", function(self) self:ClearFocus(); busca.generacion=(busca.generacion or 0)+1; GL.RefrescarBuscador() end)
  busca.caja = caja
  busca.tipos = {}
  for i, t in ipairs(TIPOS) do
    local b = GL.CrearBoton(p, t[2], function() busca.tipo = t[1]; busca.pagina=1; GL.RefrescarBuscador() end, nil, 18, "pestana")
    b.tipo = t[1]
    busca.tipos[i] = b
  end
  busca.botonFiltro = GL.CrearBoton(p, L"Todo", function()
    busca.filtro = busca.filtro % #FILTROS_CATALOGO + 1
    busca.pagina = 1; GL.RefrescarBuscador()
  end, nil, 20)
  busca.botonFiltro:Hide()
  -- 9.7.4: las cinco pestañas se reparten el ancho del panel (antes, al abrirlo, medían 70 y «Ajustes» se salía)
  local function ColocarTipos(w)
    w = tonumber(w) or 0
    if w < 100 then w = (p.GetWidth and p:GetWidth()) or 0 end
    if w < 100 and GL.frame and GL.frame.GetWidth then w = (GL.frame:GetWidth() or 0) - 80 end
    if w < 100 then w = 300 end
    -- Dos filas en paneles estrechos: cada etiqueta conserva espacio suficiente.
    local cols = w < 480 and 3 or #TIPOS
    local bw = math.max(1, math.floor((w-4*(cols-1))/cols))
    for i,b in ipairs(busca.tipos) do
      b:SetWidth(bw); b:ClearAllPoints()
      b:SetPoint("TOPLEFT",p,"TOPLEFT",((i-1)%cols)*(bw+4),-30-math.floor((i-1)/cols)*22)
    end
    busca.inicio=58+((cols<#TIPOS) and 22 or 0)
    local filtro = busca.tipo == "catalogo"
    busca.botonFiltro:ClearAllPoints()
    busca.botonFiltro:SetPoint("TOPLEFT",p,"TOPLEFT",0,-busca.inicio)
    busca.botonFiltro:SetWidth(w)
    GL.Mostrar(busca.botonFiltro, filtro)
    if filtro then busca.inicio=busca.inicio+26 end
    if busca.vacio then
      busca.vacio:ClearAllPoints(); busca.vacio:SetPoint("TOPLEFT",p,"TOPLEFT",2,-busca.inicio)
      busca.vacio:SetWidth(math.max(1,w-4))
    end
    pista:SetWidth(math.max(60, w - 16))
  end
  busca.ColocarTipos = ColocarTipos
  p:SetScript("OnSizeChanged", function(self, w)
    ColocarTipos(w)
    if busca.estado and (p.IsVisible and p:IsVisible() or not p.IsVisible and p:IsShown()) then GL.RefrescarBuscador(true) end
  end)
  p:SetScript("OnShow", function(self)
    ColocarTipos(self:GetWidth())
    if busca.estado and busca.pendiente then GL.RefrescarBuscador() end
  end)
  if pista.SetWordWrap then pista:SetWordWrap(false) end
  pista:SetJustifyH("LEFT")
  ColocarTipos()
  busca.vacio = GL.Texto(p, "GameFontHighlightSmall")
  busca.vacio:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -58)
  if busca.vacio.SetWordWrap then busca.vacio:SetWordWrap(true) end
  busca.tipo = "todo"
  busca.prev = GL.CrearBoton(p, L"Anterior", function() busca.pagina=math.max(1,busca.pagina-1); GL.RefrescarBuscador() end,nil,20)
  busca.next = GL.CrearBoton(p, L"Siguiente", function() busca.pagina=busca.pagina+1; GL.RefrescarBuscador() end,nil,20)
  busca.prev:SetWidth(78); busca.next:SetWidth(78)
  busca.prev:SetPoint("BOTTOMLEFT",p,"BOTTOMLEFT",0,0); busca.next:SetPoint("BOTTOMRIGHT",p,"BOTTOMRIGHT",0,0)
  busca.estado = GL.Texto(p,"GameFontHighlightSmall")
  busca.estado:SetPoint("LEFT",busca.prev,"RIGHT",4,0); busca.estado:SetPoint("RIGHT",busca.next,"LEFT",-4,0)
  busca.estado:SetJustifyH("CENTER")
  p:EnableMouseWheel(true); p:SetScript("OnMouseWheel",function(_,delta) if busca.pendiente or delta==0 or (busca.capacidadVisible or 0)<=0 then return end; local nueva=math.max(1,math.min(busca.paginas or 1,busca.pagina+(delta<0 and 1 or -1))); if nueva~=busca.pagina then busca.pagina=nueva; GL.RefrescarBuscador() end end)
  ColocarTipos(p:GetWidth())
  GL.modos.buscar = { panel = p, refrescar = function() GL.RefrescarBuscador() end }
end

local function FilaBusca(i)
  local f = busca.filas[i]
  if f then return f end
  f = CreateFrame("Button", nil, busca.panel)
  f:SetHeight(30)
  local brillo = f:CreateTexture(nil, "HIGHLIGHT")
  brillo:SetAllPoints()
  brillo:SetColorTexture(1, 1, 1, 0.06)
  f.n = GL.Texto(f, "GameFontHighlight")
  f.n:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -3)
  f.d = GL.Texto(f, "GameFontHighlightSmall")
  f.d:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -17)
  f.ir = GL.Texto(f, "GameFontHighlightSmall", "RIGHT")
  f.ir:SetPoint("RIGHT", f, "RIGHT", -6, 0)
  -- Reserva el ancho de la acción sin desplazar verticalmente ninguna línea.
  if GL.UnaLinea then GL.UnaLinea(f.ir) end
  f.ir:SetJustifyV("MIDDLE")
  if GL.UnaLinea then GL.UnaLinea(f.n); GL.UnaLinea(f.d) end
  f:SetScript("OnEnter",function(self)
    if not self.e or not GameTooltip then return end
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self.e.n or "",1,1,1,1,true); GameTooltip:AddLine(self.e.d or "",1,1,1,true); GameTooltip:Show()
  end)
  f:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
  f:SetScript("OnHide",function(self)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
  f:SetScript("OnClick", function(self)
    local e = self.e
    if not e then return end
    if e.s and GL.IrAPaso then GL.IrAPaso(e.s, e.p, e.i)
    elseif e.wp and GL.SeguirDesvio then GL.SeguirDesvio(e.wp); if GL.AbrirModo then GL.AbrirModo("guia") end
    elseif e.m and GL.AbrirMazmorra then GL.AbrirMazmorra(e.m.n,e.jefe,e.id)
    elseif e.zonaJefe and GL.AbrirMazmorra and GL.AbrirMazmorra(e.zonaJefe,e.jefe,e.id) then return
    elseif e.banda and GL.AbrirBanda976 and GL.AbrirBanda976(e.banda) then return
    elseif e.objetos and GL.VerBotin then GL.VerBotin(e.n,e.objetos)
    elseif e.informe and GL.MostrarInforme then GL.MostrarInforme(e.informe)
    elseif e.skill and GL.AbrirProfesion976 then GL.AbrirProfesion976(e.skill)
    elseif e.banda and GL.AbrirModo then DB().pestanaMaz="bandas"; GL.AbrirModo("mazmorras")
    elseif e.modo and GL.AbrirModo then GL.AbrirModo(e.modo)
    elseif e.pestana then DB().pestanaAjustes = e.pestana; DB().ajusteBuscado = e.clave; if GL.AbrirModo then GL.AbrirModo("opciones") end end
  end)
  busca.filas[i] = f
  return f
end

local IR = { mision = L"Ir al paso", pnj = L"Flecha ➜", mazmorra = L"Ver", ajuste = L"Abrir", catalogo=L"Ver" }
local CAB = { mision = L"MISIONES", pnj = L"PNJ Y LUGARES", mazmorra = L"MAZMORRAS Y JEFES", ajuste = L"AJUSTES", catalogo=L"Catálogo" }
-- Conserva el primer resultado visible al cambiar la capacidad de una página.
local function PaginaBusca(pagina, anterior, capacidad, cantidad, redimensionar)
  pagina = math.max(1, pagina or 1)
  local paginas = math.max(1, math.ceil(cantidad / math.max(1, capacidad)))
  if capacidad <= 0 then return pagina, paginas end
  if redimensionar and anterior and anterior > 0 then
    pagina = math.floor((pagina - 1) * anterior / capacidad) + 1
  end
  return math.min(paginas, pagina), paginas
end
function GL.RefrescarBuscador(redimensionar)
  local p = busca.panel
  if not p or not busca.estado then return end
  if (p.IsVisible and not p:IsVisible()) or (not p.IsVisible and not p:IsShown()) then
    busca.pendiente=true
    return
  end
  if busca.ColocarTipos then pcall(busca.ColocarTipos, p:GetWidth()) end
  busca.pendiente=false
  busca.generacion=(busca.generacion or 0)+1
  local texto = busca.caja:GetText() or ""
  local t=Minus(texto)
  local valido=#t>=3 or tonumber(t)~=nil
  local filtro=FILTROS_CATALOGO[busca.filtro]
  local r = Resultados(texto, busca.tipo=="catalogo" and filtro or nil)
  local total = #r.mision + #r.pnj + #r.mazmorra + #r.ajuste + #r.catalogo
  for _, b in ipairs(busca.tipos) do
    b:SetActivo(b.tipo == busca.tipo)
    local n = (b.tipo == "todo") and total or #(r[b.tipo] or {})
    local nombre = ({ todo = L"Todo", mision = L"Misiones", pnj = "PNJ", mazmorra = L"Mazmorras", ajuste = L"Ajustes", catalogo=L"Catálogo" })[b.tipo]
    b.texto:SetText(nombre .. (valido and (" " .. n .. (b.tipo=="catalogo" and n==100 and "+" or "")) or ""))
  end
  for _, f in ipairs(busca.filas) do f:Hide(); f.e=nil end
  local lista={}
  busca.botonFiltro.texto:SetText(L"Categoría del catálogo" .. ": " .. (filtro and L(filtro) or L"Todo") .. "  ›")
  -- Intercala categorías en Todo: el catálogo no oculta todas las misiones de ruta.
  local tipos={"mision","pnj","mazmorra","ajuste","catalogo"}
  if busca.tipo=="todo" then
    local max=0; for _,tipo in ipairs(tipos) do max=math.max(max,#r[tipo]) end
    for k=1,max do for _,tipo in ipairs(tipos) do if r[tipo][k] then lista[#lista+1]={tipo=tipo,e=r[tipo][k]} end end end
  else for _,e in ipairs(r[busca.tipo] or {}) do lista[#lista+1]={tipo=busca.tipo,e=e} end end
  local inicio=busca.inicio or 58
  local capacidad=math.max(0,math.floor(((p:GetHeight() or 400)-inicio-28)/32))
  local paginas
  busca.pagina, paginas = PaginaBusca(busca.pagina, busca.capacidad, capacidad, #lista, redimensionar)
  if capacidad > 0 then busca.capacidad = capacidad end
  busca.paginas = paginas
  busca.capacidadVisible = capacidad
  ControlesBusca(busca,false,busca.pagina,paginas,capacidad)
  busca.estado:SetText(#lista>0 and capacidad>0 and (busca.pagina.."/"..paginas.." · "..#lista..(busca.tipo=="catalogo" and #lista==100 and "+" or "")) or "")
  if not valido then busca.vacio:SetText(C.GRIS..L"Escribe al menos 3 letras."..C.FIN); return end
  if #lista==0 then busca.vacio:SetText(C.GRIS..(total==0 and L"Sin coincidencias." or L"Sin coincidencias en esta categoría.")..C.FIN); return end
  if capacidad==0 then busca.vacio:SetText(C.GRIS..L"Amplía la ventana para ver resultados."..C.FIN); return end
  busca.vacio:SetText("")
  local primero=(busca.pagina-1)*capacidad+1
  for k=primero,math.min(#lista,primero+capacidad-1) do
    local entrada=lista[k]; local tipo,e=entrada.tipo,entrada.e
    local pos=k-primero; local y=inicio+pos*32; local f=FilaBusca(pos+1); f.e=e
    f.n:SetText((tipo=="mision" and C.AMARILLO or C.BLANCO)..e.n..C.FIN)
    f.d:SetText(C.GRIS..(e.d or CAB[tipo])..C.FIN)
    f.ir:SetText(C.AZUL..IR[tipo]..C.FIN)
    local anchoAccion = (f.ir.GetStringWidth and f.ir:GetStringWidth()) or 74
    local anchoFila = math.max(1, p:GetWidth() or 0)
    local margen = math.min(math.ceil(math.max(0,anchoAccion))+12, math.max(12, math.floor(anchoFila * 0.4)))
    f.ir:SetWidth(math.max(1, margen - 12))
    f.n:ClearAllPoints(); f.n:SetPoint("TOPLEFT",f,"TOPLEFT",6,-3); f.n:SetPoint("TOPRIGHT",f,"TOPRIGHT",-margen,-3)
    f.d:ClearAllPoints(); f.d:SetPoint("TOPLEFT",f,"TOPLEFT",6,-17); f.d:SetPoint("TOPRIGHT",f,"TOPRIGHT",-margen,-17)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",p,"TOPLEFT",0,-y); f:SetPoint("TOPRIGHT",p,"TOPRIGHT",0,-y); f:Show()
  end
end

function GL.AbrirBuscador976(q)
  if not GL.AbrirModo or not GL.frame then return false end
  if not busca.caja then CrearBuscador() end
  if not busca.caja then return false end
  if (DB().franja or DB().compacto) and GL.PonerTamano then GL.PonerTamano("completo") end
  GL.frame:Show(); if DB() then DB().oculto=false end
  GL.AbrirModo("buscar"); busca.tipo="todo"; busca.filtro=1; busca.pagina=1; busca.caja:SetText(tostring(q or "")); GL.RefrescarBuscador(); return true
end

------------------------------------------------------------------------
-- Modo daltónico
------------------------------------------------------------------------
local ORIGINAL
local PALETAS = {
  rojoverde = { verde = { 0.30, 0.62, 1 }, rojo = { 1, 0.42, 0.80 }, amarillo = { 1, 0.82, 0.20 }, azul = { 0.30, 0.62, 1 } },
  azulamarillo = { verde = { 0.25, 0.85, 0.35 }, rojo = { 1, 0.30, 0.30 }, amarillo = { 1, 0.45, 0.72 }, azul = { 0.10, 0.80, 0.75 } },
}
local function Hex(c) return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end
local function Copiar(t) local r = {}; for k, v in pairs(t) do r[k] = v end; return r end

function GL.AplicarDaltonico()
  if not ORIGINAL then
    ORIGINAL = { verdeTexto = C.VERDE, verde = Copiar(GL.COLOR.verde or {}), dist = { cerca = Copiar(GL.COLORES_DIST.cerca), medio = Copiar(GL.COLORES_DIST.medio), lejos = Copiar(GL.COLORES_DIST.lejos) },
      xpDesc = GL.COLORES_XP and Copiar(GL.COLORES_XP.descansada), xpDescT = GL.COLORES_XP and GL.COLORES_XP.descansadaTexto,
      cont = { urgente = Copiar(COL_CONT.urgente), oportunidad = Copiar(COL_CONT.oportunidad) } }
  end
  local modo = DB().daltonico
  local p = PALETAS[modo or ""]
  local function En(t, c) if t and c then t[1], t[2], t[3] = c[1], c[2], c[3] end end
  if not p then
    C.VERDE = ORIGINAL.verdeTexto
    En(GL.COLOR.verde, ORIGINAL.verde)
    for k, v in pairs(ORIGINAL.dist) do En(GL.COLORES_DIST[k], v) end
    if GL.COLORES_XP and ORIGINAL.xpDesc then En(GL.COLORES_XP.descansada, ORIGINAL.xpDesc); GL.COLORES_XP.descansadaTexto = ORIGINAL.xpDescT end
    En(COL_CONT.urgente, ORIGINAL.cont.urgente); En(COL_CONT.oportunidad, ORIGINAL.cont.oportunidad)
    GL.colorCerca, GL.COLORES_AVISO = nil, nil
  else
    C.VERDE = Hex(p.verde)
    GL.colorCerca = Hex(p.verde)
    En(GL.COLOR.verde, p.verde)
    En(GL.COLORES_DIST.cerca, p.verde); En(GL.COLORES_DIST.medio, p.amarillo); En(GL.COLORES_DIST.lejos, p.rojo)
    if GL.COLORES_XP then En(GL.COLORES_XP.descansada, p.azul); GL.COLORES_XP.descansadaTexto = Hex(p.azul) end
    En(COL_CONT.urgente, p.rojo); En(COL_CONT.oportunidad, p.verde)
    GL.COLORES_AVISO = {
      { fondo = { p.rojo[1], p.rojo[2], p.rojo[3], 0.10 }, borde = { p.rojo[1], p.rojo[2], p.rojo[3], 0.70 } },
      { fondo = { p.amarillo[1], p.amarillo[2], p.amarillo[3], 0.07 }, borde = { p.amarillo[1], p.amarillo[2], p.amarillo[3], 0.55 } },
      { fondo = { 0.60, 0.62, 0.70, 0.07 }, borde = { 0.60, 0.62, 0.70, 0.40 } },
    }
    for i = 1, 3 do GL.COLORES_AVISO[i].icono = ({ "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew", "Interface\\GossipFrame\\AvailableQuestIcon", "Interface\\GossipFrame\\GossipGossipIcon" })[i] end
  end
  if GL.RefrescarBarraXP then pcall(GL.RefrescarBarraXP) end
  if GL.Refrescar then pcall(GL.Refrescar) end
end

------------------------------------------------------------------------
-- Tutorial 9.0: estilo de ruta, tamaño de la ventana y color
------------------------------------------------------------------------
local tuto
local SIN_OPCIONES = function() return {} end
local PANTALLAS = {
  -- 9.4.2: primero, cómo se usa la guía (tres pantallas que solo explican); después, lo que puedes elegir
  { L"Tu ruta", L"La pestaña Guía te dice qué misión toca ahora, dónde recogerla y dónde entregarla. Pulsa un paso de la tarjeta y la flecha te lleva allí.", SIN_OPCIONES },
  { L"La flecha", L"La flecha de la pantalla te lleva a cada sitio y te dice a cuántos metros está. Si te pierdes, pulsa «Mi nivel» y la guía vuelve a lo que te toca.", SIN_OPCIONES },
  { L"Lo demás", L"En la barra de la izquierda tienes Personaje (talentos, hechizos y equipo), Oro, Exploración y Mazmorras y bandas.", SIN_OPCIONES },
  -- 9.6: los automatismos vienen apagados en un personaje nuevo; aquí se elige (antes el tutorial decía que todo iba solo)
  { L"Lo que hace la guía sola", L"|cffa48cffAutomático:|r la guía pasa sola los pasos que ya has hecho, la flecha salta al siguiente destino al llegar y tus talentos se ponen solos al subir de nivel.\n|cffa48cffLo hago yo:|r al acabar un paso pulsas «Saltar paso», eliges en la tarjeta adónde va la flecha y pones los talentos tú, siguiendo Personaje › Talentos.\n|cffb4b4b8Con los dos, la guía te dice qué misión toca, dónde y cuánto te falta. Lo cambias cuando quieras en Ajustes › Automatismos.|r", function()
      local function Poner(v) for _, k in ipairs({ "auto", "autoDestino", "autoTalentos" }) do DB()[k] = v end
        if v and GL.ProgramarSync then GL.ProgramarSync() end end
      return {
        { L"Automático", L"La guía avanza y pone los talentos", function() Poner(true) end, function() return DB().auto ~= false and DB().autoTalentos ~= false end },
        { L"Lo hago yo", L"Tú avanzas y pones los talentos", function() Poner(false) end, function() return DB().auto == false end },
      }
    end },
  { L"Estilo de ruta", L"Cuántas misiones extra mete la guía.", function()
      local l = {}
      for _, e in ipairs(GL.ESTILOS_RUTA or {}) do table.insert(l, { e.n, e.d, function() DB().estiloRuta = e.id end, function() return (DB().estiloRuta or "normal") == e.id end }) end
      return l
    end },
  { L"Tamaño de la ventana", L"Lo puedes cambiar luego con el botón de abajo de la barra o con doble clic en el retrato.", function()
      return {
        { L"Completa", L"Todo a la vista", function() DB().tamanoElegido = "completo" end, function() return (DB().tamanoElegido or DB().tamano or "completo") == "completo" end },
        { L"Compacta", L"XP y el paso", function() DB().tamanoElegido = "compacto" end, function() return (DB().tamanoElegido or DB().tamano) == "compacto" end },
        { L"Franja", L"Lo mínimo", function() DB().tamanoElegido = "franja" end, function() return (DB().tamanoElegido or DB().tamano) == "franja" end },
      }
    end },
  -- 9.4.2: el color se elige en Ajustes › Aspecto (el tutorial, más corto)
  -- { L"Color de acento", L"Morado, dorado, el color de tu clase o verde.", function()
  --     local l = {}
  --     for _, id in ipairs({ "morado", "dorado", "clase", "verde" }) do
  --       local t = GL.BuscarTema and GL.BuscarTema(id)
  --       if t then table.insert(l, { t.nombre, nil, function() if GL.CambiarTema then GL.CambiarTema(id) end end, function() return GL.temaActivo == id end, t }) end
  --     end
  --     return l
  --   end },
}

local function PintarTuto()
  local i = tuto.i
  local pt = PANTALLAS[i]
  tuto.paso:SetText(C.GRIS .. L"Paso " .. i .. L" de " .. #PANTALLAS .. " · " .. string.lower(pt[1]) .. C.FIN)
  tuto.desc:SetText(pt[2])
  -- 9.6: las opciones van debajo del texto, que puede ocupar varias líneas; la ventana crece con él
  local hDesc = tonumber(tuto.desc.GetStringHeight and tuto.desc:GetStringHeight()) or 24
  local yOps = 50 + math.max(30, math.floor(hDesc + 10))
  tuto:SetHeight(yOps + 150)
  for _, b in ipairs(tuto.opciones) do b:Hide() end
  local ops = pt[3]()
  local w = math.floor((tuto:GetWidth() - 20 - (#ops - 1) * 6) / math.max(1, #ops))
  for k, o in ipairs(ops) do
    local b = tuto.opciones[k]
    if not b then
      b = CreateFrame("Button", nil, tuto, PLANTILLA)
      b:SetHeight(74)   -- 9.4.2: caben tres líneas de descripción (antes se salían por abajo)
      b.n = GL.Texto(b, "GameFontHighlight")
      b.n:SetPoint("TOP", b, "TOP", 0, -10)
      b.d = GL.Texto(b, "GameFontHighlightSmall")
      b.d:SetPoint("TOP", b.n, "BOTTOM", 0, -4)
      b.d:SetWidth(90)
      b.muestra = b:CreateTexture(nil, "ARTWORK")
      b.muestra:SetHeight(3)
      b.muestra:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 5)
      b.muestra:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 5)
      tuto.opciones[k] = b
    end
    b:SetWidth(w)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", tuto, "TOPLEFT", 10 + (k - 1) * (w + 6), -yOps)
    b.n:SetText(o[1])
    b.d:SetText(o[2] and (C.GRIS .. o[2] .. C.FIN) or "")
    b.d:SetWidth(w - 10)
    local elegido = o[4] and o[4]()
    local a = (o[5] and o[5].acento) or GL.COLOR.acento
    GL.Caja(b, elegido and { a[1], a[2], a[3], 0.18 } or GL.COLOR.caja, elegido and { a[1], a[2], a[3], 1 } or GL.COLOR.cajaBorde)
    if o[5] then b.muestra:SetColorTexture(a[1], a[2], a[3], 1); b.muestra:Show() else b.muestra:Hide() end
    b:SetScript("OnClick", function() o[3](); PintarTuto() end)
    b:Show()
  end
  GL.Mostrar(tuto.atras, i > 1)
  if tuto.siguiente.texto then tuto.siguiente.texto:SetText(i == #PANTALLAS and L"Empezar" or L"Siguiente ›") end
  local ac = GL.COLOR.acento
  tuto.raya:SetColorTexture(ac[1], ac[2], ac[3], 1)
end

local function Terminar()
  tuto:Hide()
  local t = DB().tamanoElegido
  if t and GL.PonerTamano then pcall(GL.PonerTamano, t) end
  DB().tamanoElegido = nil
end

function GL.Tutorial9(i)
  if not tuto then
    tuto = CreateFrame("Frame", "GuiaAventureroTutorial", UIParent, PLANTILLA)
    tuto:SetSize(400, 230)   -- 9.4.2: más alto para las tarjetas de 74
    tuto:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    tuto:SetFrameStrata("DIALOG")
    tuto:EnableMouse(true)
    GL.Caja(tuto, GL.COLOR.fondo, GL.COLOR.borde)
    tuto.raya = tuto:CreateTexture(nil, "ARTWORK")
    tuto.raya:SetHeight(2)
    tuto.raya:SetPoint("TOPLEFT", tuto, "TOPLEFT", 1, -1)
    tuto.raya:SetPoint("TOPRIGHT", tuto, "TOPRIGHT", -1, -1)
    tuto.titulo = GL.Texto(tuto, "GameFontNormalLarge")
    tuto.titulo:SetPoint("TOPLEFT", tuto, "TOPLEFT", 10, -10)
    tuto.titulo:SetText(L"Bienvenido a la Guía del Aventurero")
    tuto.paso = GL.Texto(tuto, "GameFontHighlightSmall")
    tuto.paso:SetPoint("TOPLEFT", tuto, "TOPLEFT", 10, -32)
    tuto.desc = GL.Texto(tuto, "GameFontHighlightSmall")
    tuto.desc:SetPoint("TOPLEFT", tuto, "TOPLEFT", 10, -50)
    tuto.desc:SetPoint("RIGHT", tuto, "RIGHT", -10, 0)
    tuto.opciones = {}
    tuto.atras = GL.CrearBoton(tuto, L"‹ Atrás", function() tuto.i = math.max(1, tuto.i - 1); PintarTuto() end, nil, 22)
    tuto.atras:SetWidth(90)
    tuto.atras:SetPoint("BOTTOMLEFT", tuto, "BOTTOMLEFT", 10, 30)
    tuto.siguiente = GL.CrearBoton(tuto, L"Siguiente ›", function()
      if tuto.i >= #PANTALLAS then Terminar() else tuto.i = tuto.i + 1; PintarTuto() end
    end, nil, 22, "accion")
    tuto.siguiente:SetWidth(110)
    tuto.siguiente:SetPoint("BOTTOMRIGHT", tuto, "BOTTOMRIGHT", -10, 30)
    tuto.saltar = GL.CrearBoton(tuto, L"Saltar", Terminar, nil, 22)
    tuto.saltar:SetWidth(80)
    tuto.saltar:SetPoint("RIGHT", tuto.siguiente, "LEFT", -6, 0)
    tuto.nunca = GL.CrearBoton(tuto, L"No volver a mostrarlo en la cuenta", function()
      if type(GuiaAventureroCuenta) ~= "table" then GuiaAventureroCuenta = {} end
      GuiaAventureroCuenta.tutorial = false
      Terminar()
    end, nil, 18)
    tuto.nunca:SetPoint("BOTTOMLEFT", tuto, "BOTTOMLEFT", 10, 6)
    tuto.nunca:SetPoint("BOTTOMRIGHT", tuto, "BOTTOMRIGHT", -10, 6)
    if GL.Ayuda then GL.Ayuda(tuto.nunca, L"No volver a mostrarlo", L"Con /ga tutorial lo puedes ver igual. También en Ajustes › General.") end
  end
  tuto.i = math.max(1, math.min(tonumber(i) or 1, #PANTALLAS))
  tuto:Show()
  PintarTuto()
end

------------------------------------------------------------------------
-- /ga memoria
------------------------------------------------------------------------
local SECCIONES = { { "guia", L"Guía" }, { "talentos", L"Talentos" }, { "oficios", L"Profesiones" }, { "exploracion", L"Exploración" },
  { "mazmorras", L"Mazmorras y bandas" }, { "reputacion", L"Reputación" }, { "biblioteca", L"Biblioteca" }, { "cuenta", L"Cuenta" }, { "coleccion", L"Colección" } }
function GL.TextoMemoria()
  local kb
  if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
    pcall(UpdateAddOnMemoryUsage)
    local nombre = "GuiaAventurero"
    local ok, v = pcall(GetAddOnMemoryUsage, nombre)
    if ok then kb = Num(v) end
  end
  local cargadas, sin = {}, {}
  for _, s in ipairs(SECCIONES) do
    if s[1] == "guia" or s[1] == "talentos" or s[1] == "oficios" or GL.modos[s[1]] then table.insert(cargadas, s[2]) else table.insert(sin, s[2]) end
  end
  local mem = kb and ((kb >= 1024) and GL.FormatoDecimal(string.format("%.1f MB", kb / 1024)) or (math.floor(kb) .. " KB")) or L"el juego no lo dice"
  local txt = L"memoria: " .. mem .. L". Cargadas: " .. table.concat(cargadas, ", ") .. "."
  if #sin > 0 then txt = txt .. L" Sin cargar todavía: " .. table.concat(sin, ", ") .. "." end
  if GL.ContinenteActual then txt = txt .. L" Opcionales cargadas: " .. GL.ContinenteActual() .. "." end
  if GetAddOnCPUUsage and GetCVar and GetCVar("scriptProfile") == "1" then
    local ok, ms = pcall(GetAddOnCPUUsage, "GuiaAventurero")
    if ok and Num(ms) then txt = txt .. L" CPU: " .. math.floor(ms) .. L" ms desde que cargó." end
  end
  return txt
end
GL.comandos = GL.comandos or {}
GL.comandos["memoria"] = function() if GL.Mensaje then GL.Mensaje(GL.TextoMemoria()) end end

------------------------------------------------------------------------
-- Ajustes y arranque
------------------------------------------------------------------------
GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "daltonico", "Colores para daltónicos",
  "Cambia los verdes y rojos (distancia, flecha, avisos, contadores y la barra de XP) por colores que se distinguen mejor. Lo urgente lleva además «!».",
  function() return DB().daltonico or "no" end, function(v) DB().daltonico = (v ~= "no") and v or nil; GL.AplicarDaltonico() end,
  pestana = "aspecto", opciones = { { "no", "No" }, { "rojoverde", "Rojo-verde" }, { "azulamarillo", "Azul-amarillo" } } })
table.insert(GL.ajustesInterfaz, { "cargarAlAbrir", "Cargar cada sección al abrirla",
  "Reputación, Biblioteca, Colección, Grupo y Buscar se crean al abrirlos por primera vez. /ga memoria dice cuánto ocupa.",
  function() return Si("cargarAlAbrir") end, function(v) DB().cargarAlAbrir = v end, pestana = "datos" })

GL.perezosos = GL.perezosos or {}
GL.perezosos.grupo = CrearGrupo
GL.perezosos.buscar = CrearBuscador

table.insert(GL.alIniciar, function()
  local ui = GL.ui
  if not (ui and GL.BotonLateral and GL.frame) then return end
  if GL.LADO then GL.LADO.grupo = true; GL.LADO.buscar = true end
  local x = (GL.RAIL - 36) / 2
  -- Grupo: tras los iconos de abajo de la raya; solo se ve en grupo
  local bg = GL.BotonLateral("grupo", L"Grupo", "Interface\\Icons\\INV_Misc_GroupLooking", L"En qué paso va cada compañero y qué misiones compartís.", function()
    if DB().modo == "grupo" then GL.AbrirModo(DB().modoGuia or "guia") else GL.AbrirModo("grupo") end
  end)
  bg:SetPoint("TOPLEFT", GL.frame, "TOPLEFT", x, ui.yLateral or -300)
  table.insert(ui.lado, bg)
  GL._botonGrupo = bg
  -- Buscar: abajo, encima del de tamaño
  local bb = GL.BotonLateral("buscar", L"Buscar", "Interface\\Icons\\Spell_Holy_MindVision", L"Misiones, PNJ, mazmorras, jefes y ajustes.", function()
    if DB().modo == "buscar" then GL.AbrirModo(DB().modoGuia or "guia") else GL.AbrirModo("buscar"); if busca.caja then busca.caja:SetFocus() end end
  end)
  bb:SetPoint("BOTTOMLEFT", GL.frame, "BOTTOMLEFT", x, 76)
  -- 9.5: Buscar llevaba el mismo catalejo que Exploración. Ahora una lupa (la de las cajas de búsqueda del juego);
  -- si el cliente no la trae, se queda el ojo de Visión mental.
  if bb.icono and bb.icono.SetTexture then
    local ok, puesto = pcall(bb.icono.SetTexture, bb.icono, "Interface\\Common\\UI-Searchbox-Icon")
    if not ok or puesto == false then bb.icono:SetTexture("Interface\\Icons\\Spell_Holy_MindVision") else bb.icono:SetTexCoord(0, 1, 0, 1) end
  end
  table.insert(ui.lado, bb)
  if not Si("cargarAlAbrir") or DB().modo == "grupo" then CrearGrupo() end
  if not Si("cargarAlAbrir") or DB().modo == "buscar" then CrearBuscador() end
  MirarGrupo()
  if DB().daltonico then pcall(GL.AplicarDaltonico) end
  local f = CreateFrame("Frame")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:SetScript("OnEvent", function(_, evento, prefijo)
    if evento == "CHAT_MSG_ADDON" then
      if issecretvalue and issecretvalue(prefijo) then return end
      if prefijo ~= "GuiaAventurero" then return end
    elseif evento ~= "GROUP_ROSTER_UPDATE" then return end
    if evento == "GROUP_ROSTER_UPDATE" then pcall(MirarGrupo) end
    pcall(Contadores)
    if DB().modo == "grupo" and grupo.panel and grupo.panel:IsVisible() then pcall(GL.RefrescarGrupo) end
  end)
end)
GL.trasRefrescar = GL.trasRefrescar or {}
table.insert(GL.trasRefrescar, function() pcall(Contadores) end)
GL._barra9 = { Resultados = Resultados, Contadores = Contadores, CrearBuscador = CrearBuscador }

-- (el fundido al cambiar de pestaña ya lo hace Detalles.lua desde la 8.9.1: ajuste «fundido»)

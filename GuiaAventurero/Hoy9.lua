-- Hoy9.lua (9.0): Cuenta › Hoy. Lo que has hecho hoy (o esta semana) con todos tus personajes: XP, niveles,
-- oro, misiones, pasos y XP por hora; un gráfico de XP cada 15 minutos; cada personaje con lo suyo de hoy; y la
-- sesión actual y la anterior (antes en Personaje › Estadísticas), con el botón de compartir en el chat.
-- Los datos se guardan para toda la cuenta y se borran solos a los 8 días.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"
local function DB() return type(GuiaAventureroDB) == "table" and GuiaAventureroDB or {} end
local function Num(v)
  if issecretvalue and issecretvalue(v) then return nil end
  if GL.Seguro then v = GL.Seguro(v) end
  return type(v) == "number" and v == v and math.abs(v) <= 9007199254740991 and v or nil
end
local function Contador(v, signo)
  v = Num(v)
  return v and (signo or v >= 0) and v or nil
end
local function Texto(v)
  return not (issecretvalue and issecretvalue(v)) and type(v) == "string" and v:find("%S") and v or nil
end
local function Consulta(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok and not (issecretvalue and issecretvalue(v)) then return v end
end
local function Miles(n) return GL.FormatoMiles(n) end
local function Duracion(seg)
  seg = math.floor((Contador(seg) or 0) + 0.5)
  if seg < 60 then return seg .. " s" end
  local m = math.floor(seg / 60)
  if m < 60 then return m .. L" min" end
  return math.floor(m / 60) .. " h " .. (m % 60) .. L" min"
end
local function FechaValida(v)
  if not Texto(v) then return nil end
  local y,m,d = v:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  y,m,d = tonumber(y),tonumber(m),tonumber(d)
  if not y or y < 1 or m < 1 or m > 12 or d < 1 then return nil end
  local dias = ({31, (y%4==0 and (y%100~=0 or y%400==0)) and 29 or 28,31,30,31,30,31,31,30,31,30,31})[m]
  return d <= dias and v or nil
end
local function Hoy() return FechaValida(Consulta(date, "%Y-%m-%d")) end
local function Franja()
  local t = Consulta(date, "*t")
  local h,m = type(t)=="table" and Num(t.hour), type(t)=="table" and Num(t.min)
  if not h or not m or h < 0 or h >= 24 or m < 0 or m >= 60 or h%1~=0 or m%1~=0 then return nil end
  return math.floor((h*60+m)/15)
end
local function GUID(v) return Texto(v) and v:match("^Player%-%w+%-%w+$") and v or nil end
local function Identidad()
  local k,n,r,g
  if type(GL.ClavePersonajeCuenta)=="function" then
    local ok; ok,k,n,r,g=pcall(GL.ClavePersonajeCuenta)
    if not ok then return nil end
  end
  if not Texto(k) or not Texto(n) or not Texto(r) or not GUID(g) then return nil end
  return "guid:"..g,n,r,g
end

------------------------------------------------------------------------
-- Datos
------------------------------------------------------------------------
-- Los registros sin GUID se conservan como históricos independientes.
-- Nunca asociar automáticamente un nombre reutilizado a un GUID nuevo.
local function Archivar(k,v)
  local c = GuiaAventureroCuenta
  if type(c) ~= "table" then return false end
  if c.dias9Recuperacion9794 == nil then c.dias9Recuperacion9794 = {} end
  local a = c.dias9Recuperacion9794
  if type(a) ~= "table" then return false end
  if a[k] == nil then a[k] = v end
  return true
end
local function Dias(escribir)
  if GuiaAventureroCuenta == nil and escribir then GuiaAventureroCuenta = {} end
  if type(GuiaAventureroCuenta) ~= "table" then if escribir then return nil end; return {} end
  local c = GuiaAventureroCuenta
  if type(c.dias9) == "table" then return c.dias9 end
  if not escribir then return {} end
  if c.dias9 ~= nil and not Archivar("dias9",c.dias9) then return nil end
  c.dias9 = {}; return c.dias9
end
local function Limpiar()
  local ahora = Num(Consulta(time))
  local limite = ahora and FechaValida(Consulta(date,"%Y-%m-%d",ahora - 8*86400))
  if not limite then return end
  for k in pairs(Dias()) do if FechaValida(k) and k < limite then Dias()[k] = nil end end
end
local CAMPOS = {"xp","oro","q","pasos","t"}
local function FranjaClave(k)
  local n = type(k)=="string" and tonumber(k) or Num(k)
  return n and n>=0 and n<=95 and n%1==0 and string.format("%d",n) or nil
end
local function Vista(p)
  if type(p) ~= "table" then return nil end
  local v = { b={}, nombre=Texto(p.nombre), clase=Texto(p.clase), guid=GUID(p.guid), reino=Texto(p.reino) }
  for _, k in ipairs(CAMPOS) do v[k] = Contador(p[k],k=="oro") or 0 end
  v.n0,v.n1 = Contador(p.n0),Contador(p.n1)
  if type(p.b)=="table" then
    for k,x in pairs(p.b) do local f=FranjaClave(k); if f and Contador(x) then v.b[f]=(v.b[f] or 0)+x end end
  end
  return v
end
local function Mio()
  local h=Hoy(); local k,n,r,g=Identidad()
  if not h or not k then return nil end
  local dias=Dias(true); if not dias then return nil end
  if type(dias[h]) ~= "table" then
    if dias[h]~=nil and not Archivar(h,dias[h]) then return nil end
    dias[h]={}
  end
  local d=dias[h]; local p=d[k]; local pref=h..":"..k
  if type(p)~="table" or GUID(p.guid)~=g then
    if p~=nil and not Archivar(pref,p) then return nil end
    p={guid=g};d[k]=p
  end
  local function Reparar(campo,valor)
    if p[campo]~=nil and not Archivar(pref..":"..campo,p[campo]) then return false end
    p[campo]=valor;return true
  end
  for _,campo in ipairs(CAMPOS) do
    if not Contador(p[campo],campo=="oro") and not Reparar(campo,0) then return nil end
  end
  local nv=Contador(Consulta(UnitLevel,"player"))
  if not Contador(p.n0) and not Reparar("n0",nv or 1) then return nil end
  if type(p.b)~="table" and not Reparar("b",{}) then return nil end
  -- Normalizar solo la tabla de franjas si contiene datos inválidos o claves numéricas antiguas.
  local cambio=false
  for f,v in pairs(p.b) do if FranjaClave(f)~=f or not Contador(v) then cambio=true;break end end
  if cambio and not Reparar("b",Vista(p).b) then return nil end
  if p.n1~=nil and not Contador(p.n1) and not Reparar("n1",nv or p.n0) then return nil end
  if nv and nv>0 then p.n1=nv end
  p.nombre,p.reino,p.guid=n,r,g
  if type(UnitClass)=="function" then local ok,_,clase=pcall(UnitClass,"player"); if ok and Texto(clase) then p.clase=clase end end
  return p
end

local xpAntes,xpMaxAntes,nivelAntes,oroAntes,claveAnt,identAnterior
local function Contexto()
  local k=Identidad()
  if k~=identAnterior then xpAntes,xpMaxAntes,nivelAntes,oroAntes,claveAnt=nil,nil,nil,nil,nil;identAnterior=k end
  return k
end
local function LeerXP()
  if not Contexto() then return end
  local xp,max,nv=Contador(Consulta(UnitXP,"player")),Contador(Consulta(UnitXPMax,"player")),Contador(Consulta(UnitLevel,"player"))
  if not xp or not max or not nv or xp>max or nv<1 then xpAntes,xpMaxAntes,nivelAntes=nil,nil,nil;return end
  if xpAntes then
    local d=0
    if nv==nivelAntes+1 then d=(xpMaxAntes-xpAntes)+xp elseif nv==nivelAntes and xp>xpAntes then d=xp-xpAntes end
    if d>0 then local p=Mio(); if p then p.xp=p.xp+d; local f=Franja(); if f then f=tostring(f);p.b[f]=(p.b[f] or 0)+d end end end
  end
  xpAntes,xpMaxAntes,nivelAntes=xp,max,nv
end
local function LeerOro()
  if not Contexto() then return end
  local o=Contador(Consulta(GetMoney))
  if not o then oroAntes=nil;return end
  if oroAntes then local p=Mio();if p then p.oro=p.oro+(o-oroAntes) end end
  oroAntes=o
end
local function MirarPaso()
  if not Contexto() then return end
  local db=DB(); local sec,paso=Contador(db.seccion),Contador(db.paso)
  if not sec or not paso then claveAnt=nil;return end
  local clave=sec*1000+paso
  if claveAnt and clave>claveAnt then local p=Mio();if p then p.pasos=p.pasos+1 end end
  claveAnt=clave
end
local function Sumar(dias)
  local r={xp=0,oro=0,q=0,pasos=0,t=0,b={},pj={}}
  for _,d in ipairs(dias) do
    if type(d)=="table" then for k,p in pairs(d) do
      local v=Vista(p)
      if v and type(k)=="string" then
        for _,campo in ipairs(CAMPOS) do r[campo]=r[campo]+v[campo] end
        for f,x in pairs(v.b) do r.b[f]=(r.b[f] or 0)+x end
        local id=v.guid and ("guid:"..v.guid) or ("historico:"..k)
        local e=r.pj[id]
        if not e then e={xp=0,q=0,t=0,n0=v.n0,n1=v.n1};r.pj[id]=e end
        e.nombre,e.clase,e.reino=v.nombre or k,v.clase or e.clase,v.reino or e.reino
        e.xp,e.q,e.t=e.xp+v.xp,e.q+v.q,e.t+v.t
        if v.n0 then e.n0=math.min(e.n0 or v.n0,v.n0) end
        if v.n1 then e.n1=math.max(e.n1 or v.n1,v.n1) end
      end
    end end
  end
  local k=Identidad();local yo=k and r.pj[k]
  if yo then r.n0,r.n1=yo.n0,yo.n1 end
  return r
end
local function RitmoPropio()
  local k=Identidad();if not k then return 0,0 end
  local lista={};for h,d in pairs(Dias()) do if FechaValida(h) and type(d)=="table" then lista[#lista+1]=d end end
  local p=Sumar(lista).pj[k];return p and p.xp or 0,p and p.t or 0
end

------------------------------------------------------------------------
-- Pantalla
------------------------------------------------------------------------
local ui
local function Tesela(padre)
  local t = CreateFrame("Frame", nil, padre, PLANTILLA)
  t:SetHeight(40)
  GL.Caja(t, GL.COLOR.caja, GL.COLOR.cajaBorde)
  t.k = GL.Texto(t, "GameFontHighlightSmall")
  t.k:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -6)
  t.v = GL.Texto(t, "GameFontHighlight")
  t.v:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -20)
  local f, _, o = t.v:GetFont()
  if type(f) == "string" then t.v:SetFont(f, 14, o) end
  return t
end

local function Crear(f)
  ui = { teselas = {}, barras = {}, pj = {} }
  local c = CreateFrame("Frame", nil, f)   -- lo de Hoy y Semana (se oculta en Por nivel)
  c:SetAllPoints(f)
  ui.c = c
  ui.titulo = GL.Texto(f, "GameFontNormalLarge")
  ui.titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  ui.sub = GL.Texto(c, "GameFontHighlightSmall")
  ui.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -20)
  ui.modo = {}
  for i, v in ipairs({ { "hoy", L"Hoy" }, { "semana", L"Semana" }, { "nivel", L"Por nivel" } }) do
    local b = GL.CrearBoton(f, v[2], function() DB().hoyModo = v[1]; GL.PintarHoy(f) end, nil, 18, "pestana")
    b:SetWidth(64)
    b.modo = v[1]
    ui.modo[i] = b
  end
  ui.modo[3]:SetWidth(72)
  ui.modo[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
  ui.modo[2]:SetPoint("RIGHT", ui.modo[3], "LEFT", -4, 0)
  ui.modo[1]:SetPoint("RIGHT", ui.modo[2], "LEFT", -4, 0)
  local nombres = { L"XP ganada", L"Niveles", L"Oro", L"Misiones", L"Pasos", L"XP / hora" }
  for i = 1, 6 do ui.teselas[i] = Tesela(c); ui.teselas[i].k:SetText(C.GRIS .. nombres[i] .. C.FIN) end
  ui.cabGrafico = GL.Texto(c, "GameFontHighlightSmall")
  ui.grafico = CreateFrame("Frame", nil, c, PLANTILLA)
  ui.grafico:SetHeight(64)
  GL.Caja(ui.grafico, { 0, 0, 0, 0.25 }, GL.COLOR.cajaBorde)
  ui.ejes = {}
  for i = 1, 3 do ui.ejes[i] = GL.Texto(c, "GameFontDisableSmall", i == 3 and "RIGHT" or "LEFT") end
  ui.cabPj = GL.Texto(c, "GameFontHighlightSmall")
  ui.cabSesion = GL.Texto(c, "GameFontHighlightSmall")
  ui.sesion = GL.Texto(c, "GameFontHighlightSmall")
  ui.anterior = GL.Texto(c, "GameFontHighlightSmall")
  ui.compartir = GL.CrearBoton(c, L"Compartir en el chat", function() if GL.Compartir then GL.Compartir() end end, nil, 20, "accion")
  if GL.Ayuda then GL.Ayuda(ui.compartir, L"Compartir en el chat", L"Pone tu nivel, tiempo y ritmo en el chat de grupo (o de hermandad si no estás en grupo).") end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function() end)
  local espera = 0
  f:SetScript("OnUpdate", function(self, dt) espera = espera + dt; if espera >= 2 then espera = 0; pcall(GL.PintarHoy, self) end end)
end

local function ColorClase(clase)
  local c=Texto(clase) and (Consulta(C_ClassColor and C_ClassColor.GetClassColor,clase) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[clase]))
  if type(c)=="table" and Num(c.r) and Num(c.g) and Num(c.b) then
    local function Canal(v) return math.floor(math.max(0,math.min(1,v))*255+0.5) end
    return string.format("|cff%02x%02x%02x",Canal(c.r),Canal(c.g),Canal(c.b))
  end
  return C.BLANCO
end

function GL.PintarHoy(f)
  if not ui then Crear(f) end
  local W = f:GetWidth() or 360
  if W < 100 then W = 360 end
  local modoHoy = DB().hoyModo or "hoy"
  local semana = modoHoy == "semana"
  for _, b in ipairs(ui.modo) do b:SetActivo(b.modo == modoHoy) end
  -- 9.0: Por nivel es lo que era Personaje › Estadísticas (el resumen y la tabla de cada nivel)
  local est = GL.modos and GL.modos.estadisticas
  if modoHoy == "nivel" and est and est.panel then
    ui.c:Hide()
    ui.titulo:SetText(L"Por nivel")
    if est.panel:GetParent() ~= f then
      est.panel:SetParent(f)
      est.panel:ClearAllPoints()
      est.panel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
      est.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    end
    est.panel:Show()
    if est.refrescar then pcall(est.refrescar) end
    return
  end
  if est and est.panel and est.panel:GetParent() == f then est.panel:Hide() end
  ui.c:Show()
  local dias = Dias()
  local lista, etiquetas = {}, {}
  local ahora=Num(Consulta(time))
  if semana and ahora then
    for i = 6, 0, -1 do
      local k = FechaValida(Consulta(date,"%Y-%m-%d",ahora-i*86400))
      table.insert(lista, k and dias[k] or {})
      table.insert(etiquetas, Texto(Consulta(date,"%d/%m",ahora-i*86400)) or "—")
    end
  else
    table.insert(lista, dias[Hoy()] or {})
  end
  local r = Sumar(lista)
  local se = Vista(Consulta(GL.SesionActual))
  ui.titulo:SetText(semana and L"Esta semana" or L"Hoy")
  ui.sub:SetText(C.GRIS .. (se and (L"Sesión de " .. Duracion(se.t)) or "") .. (r.t > 0 and (L"  ·  jugado " .. (semana and L"en la semana " or L"hoy ") .. Duracion(r.t)) or "") .. C.FIN)
  -- teselas (3 x 2)
  local tw = math.floor((W - 2 * 6) / 3)
  local valores = {
    Miles(r.xp),
    (r.n0 and r.n1) and (r.n0 == r.n1 and tostring(r.n1) or (r.n0 .. " " .. GL.Icono("→") .. " " .. r.n1)) or "—",
    (GL.DineroConSigno and GL.DineroConSigno(r.oro)) or tostring(r.oro),
    tostring(r.q), tostring(r.pasos),
    (r.t >= 300) and Miles(r.xp / r.t * 3600) or "—",
  }
  for i, t in ipairs(ui.teselas) do
    local c, fila = (i - 1) % 3, math.floor((i - 1) / 3)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", c * (tw + 6), -40 - fila * 46)
    t:SetWidth(tw)
    t.v:SetText((i == 1 and "|cffa48cff" or C.BLANCO) .. valores[i] .. C.FIN)
  end
  local y = 40 + 2 * 46 + 6
  -- gráfico
  ui.cabGrafico:ClearAllPoints()
  ui.cabGrafico:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.cabGrafico:SetText(C.GRIS .. (semana and L"XP POR DÍA" or L"XP POR CADA 15 MIN") .. C.FIN)
  y = y + 16
  ui.grafico:ClearAllPoints()
  ui.grafico:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.grafico:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -y)
  local valoresG, etiq = {}, {}
  if semana then
    for i, d in ipairs(lista) do valoresG[i] = Sumar({ d }).xp; etiq[i] = etiquetas[i] end
  else
    local primero, ultimo = nil, Franja() or 0
    for k, v in pairs(r.b) do local n = tonumber(k); if n and v > 0 and (not primero or n < primero) then primero = n end end
    primero = primero or ultimo
    if ultimo - primero > 31 then primero = ultimo - 31 end
    if ultimo - primero < 7 then primero = math.max(0, ultimo - 7) end
    for n = primero, ultimo do
      table.insert(valoresG, r.b[tostring(n)] or 0)
      table.insert(etiq, string.format("%d:%02d", math.floor(n / 4), (n % 4) * 15))
    end
  end
  local maxV = 1
  for _, v in ipairs(valoresG) do if v > maxV then maxV = v end end
  local nB = #valoresG
  local gw = W - 8
  local bw = math.max(2, math.floor(gw / math.max(1, nB)) - 2)
  local a = GL.COLOR.acento
  for i = 1, math.max(nB, #ui.barras) do
    local b = ui.barras[i]
    if i <= nB then
      if not b then b = ui.grafico:CreateTexture(nil, "ARTWORK"); b:SetTexture(BLANCO8); ui.barras[i] = b end
      local h = math.max(1, math.floor(54 * valoresG[i] / maxV))
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", ui.grafico, "BOTTOMLEFT", 4 + (i - 1) * (bw + 2), 4)
      b:SetSize(bw, h)
      local ultima = (i == nB)
      b:SetVertexColor(a[1], a[2], a[3], ultima and 1 or (valoresG[i] > 0 and 0.7 or 0.15))
      b:Show()
    elseif b then
      b:Hide()
    end
  end
  y = y + 64 + 2
  if nB > 0 then
    ui.ejes[1]:ClearAllPoints(); ui.ejes[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -y); ui.ejes[1]:SetText(etiq[1] or "")
    ui.ejes[2]:ClearAllPoints(); ui.ejes[2]:SetPoint("TOP", f, "TOP", 0, -y); ui.ejes[2]:SetText(etiq[math.floor((nB + 1) / 2)] or "")
    ui.ejes[3]:ClearAllPoints(); ui.ejes[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -y); ui.ejes[3]:SetText(etiq[nB] or "")
  end
  y = y + 18
  -- personajes
  local pjs = {}
  for _, p in pairs(r.pj) do if (p.xp or 0) > 0 or (p.q or 0) > 0 or (p.t or 0) > 0 then table.insert(pjs, p) end end
  table.sort(pjs, function(x, z) return (x.xp or 0) > (z.xp or 0) end)
  ui.cabPj:ClearAllPoints()
  ui.cabPj:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.cabPj:SetText(C.GRIS .. (semana and L"POR PERSONAJE, ESTA SEMANA" or L"POR PERSONAJE, HOY") .. C.FIN)
  y = y + 16
  for _, t in ipairs(ui.pj) do t:Hide() end
  for i = 1, math.min(#pjs, 5) do
    local p = pjs[i]
    local t = ui.pj[i]
    if not t then t = GL.Texto(ui.c, "GameFontHighlightSmall"); ui.pj[i] = t end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -y)
    t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -y)
    local niv = (p.n0 and p.n1 and p.n1 > p.n0) and (p.n0 .. " " .. GL.Icono("→") .. " " .. p.n1) or tostring(p.n1 or "?")
    t:SetText(ColorClase(p.clase) .. (p.nombre or "?") .. (p.reino and (" - "..p.reino) or "") .. C.FIN .. C.GRIS .. L"  nivel " .. niv .. "  ·  " .. C.FIN ..
      "|cffa48cff" .. Miles(p.xp) .. " XP" .. C.FIN .. C.GRIS .. "  ·  " .. (p.q or 0) .. L" misiones  ·  " .. Duracion(p.t or 0) .. C.FIN)
    t:Show()
    y = y + 15
  end
  if #pjs == 0 then
    local t = ui.pj[1] or GL.Texto(ui.c, "GameFontHighlightSmall"); ui.pj[1] = t
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -y)
    t:SetText(C.GRIS .. L"Aún nada: se apunta mientras juegas." .. C.FIN); t:Show()
    y = y + 15
  end
  y = y + 8
  -- sesión (antes en Estadísticas)
  ui.cabSesion:ClearAllPoints()
  ui.cabSesion:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.cabSesion:SetText(C.GRIS .. L"ESTA SESIÓN" .. C.FIN)
  y = y + 16
  ui.sesion:ClearAllPoints()
  ui.sesion:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -y)
  ui.sesion:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -y)
  if se then
    ui.sesion:SetText(Duracion(se.t) .. C.GRIS .. "  ·  " .. C.FIN .. Miles(se.xp) .. " XP" ..
      (se.t >= 60 and (C.GRIS .. " (" .. Miles(se.xp / se.t * 3600) .. "/h)" .. C.FIN) or "") .. C.GRIS .. "  ·  " .. C.FIN ..
      ((se.oro >= 0) and C.VERDE or "|cffff7070") .. ((GL.DineroConSigno and GL.DineroConSigno(se.oro)) or se.oro) .. C.FIN ..
      C.GRIS .. "  ·  " .. C.FIN .. se.q .. (se.q == 1 and L" misión" or L" misiones"))
  else
    ui.sesion:SetText(C.GRIS .. "—" .. C.FIN)
  end
  y = y + 16
  local an = Vista(DB().sesionAnterior)
  if an then an.fin=Contador(DB().sesionAnterior.fin) end
  ui.anterior:ClearAllPoints()
  ui.anterior:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -y)
  ui.anterior:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -y)
  if GL.UnaLinea then GL.UnaLinea(ui.anterior) end
  ui.anterior:SetText(an and (C.GRIS .. L"Sesión anterior" .. (an.fin and (" (" .. (Texto(Consulta(date,"%d/%m",an.fin)) or "—") .. ")") or "") .. ": " ..
    Duracion(an.t) .. ", " .. Miles(an.xp) .. L" XP, " .. ((GL.DineroConSigno and GL.DineroConSigno(an.oro or 0)) or "") .. ", " .. (an.q or 0) .. L" misiones" .. C.FIN) or "")
  y = y + 18
  ui.compartir:ClearAllPoints()
  ui.compartir:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  ui.compartir:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -y)
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
table.insert(GL.alIniciar, function()
  pcall(Limpiar);pcall(Mio);pcall(LeerXP);pcall(LeerOro);pcall(MirarPaso)
  local f=CreateFrame("Frame")
  for _,e in ipairs({"PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","PLAYER_MONEY","QUEST_TURNED_IN","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT"}) do pcall(f.RegisterEvent,f,e) end
  local reloj,acumulado,registro,dia,ident=0,0,Mio(),Hoy(),Identidad()
  local function Volcar()
    if registro and acumulado>0 then registro.t=(Contador(registro.t) or 0)+acumulado end
    acumulado=0
  end
  f:SetScript("OnEvent",function(_,evento)
    if evento=="PLAYER_LOGOUT" then Volcar();return end
    if evento=="PLAYER_ENTERING_WORLD" then
      Volcar();registro,dia,ident=nil,nil,nil;reloj=0
      xpAntes,xpMaxAntes,nivelAntes,oroAntes,claveAnt=nil,nil,nil,nil,nil
      pcall(LeerXP);pcall(LeerOro);pcall(MirarPaso);return
    end
    if evento=="PLAYER_MONEY" then pcall(LeerOro)
    elseif evento=="QUEST_TURNED_IN" then pcall(function() local p=Mio();if p then p.q=p.q+1 end end)
    else pcall(LeerXP) end
  end)
  f:SetScript("OnUpdate",function(_,dt)
    dt=Contador(dt);if not dt or dt>60 then return end
    reloj=reloj+dt;if reloj<1 then return end
    local h,k=Hoy(),Identidad()
    if h~=dia or k~=ident then
      Volcar();registro,dia,ident=nil,h,k
      if h and k then registro=Mio();pcall(Limpiar) end
    elseif registro then acumulado=acumulado+reloj;if acumulado>=30 then Volcar() end
    elseif h and k then registro=Mio() end
    reloj=0
  end)
end)
GL.trasRefrescar=GL.trasRefrescar or {}
table.insert(GL.trasRefrescar,function() pcall(MirarPaso) end)
GL._hoy={Sumar=Sumar,Dias=Dias,Mio=Mio,RitmoPropio=RitmoPropio,Limpiar=Limpiar,FechaValida=FechaValida,LeerXP=LeerXP,LeerOro=LeerOro,MirarPaso=MirarPaso}

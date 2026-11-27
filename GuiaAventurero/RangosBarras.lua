-- RangosBarras.lua (9.5): al aprender un rango nuevo de un hechizo que tienes en las barras de acción, sale un aviso
-- para cambiar en las barras el rango viejo por el nuevo con un clic (o hacerlo siempre solo, si lo eliges).
-- Solo fuera de combate: en combate el juego no deja tocar las barras, y el aviso espera a que acabe.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local function DB() return GuiaAventureroDB or {} end
local function Activo() return DB().rangosBarras ~= false end
local function Auto() return DB().rangosAuto == true end

local MAX_RANURA = 144
local ESPERA = 1.5          -- el instructor enseña varios de golpe: se juntan en un solo aviso

-- Los IDs del libro del jugador son la fuente de aprendizaje; no usar los
-- equivalentes de misión ni los hechizos apuntados fuera del libro por la guía.
local function Seguro(f, ...)
  if type(f)~="function" then return nil end
  local ok,a,b,c,d,e,g,h=pcall(f,...)
  if ok then return a,b,c,d,e,g,h end
end
local function Nombre(id)
  return Seguro(C_Spell and C_Spell.GetSpellName,id) or Seguro(GetSpellInfo,id)
end
local function NumRango(id, texto)
  local r=texto or Seguro(C_Spell and C_Spell.GetSpellSubtext,id) or Seguro(GetSpellSubtext,id)
  if not r or r=="" then local _,sub=Seguro(GetSpellInfo,id);r=sub end
  return type(r)=="string" and tonumber(r:match("(%d+)")) or 0
end
local function Banco() return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0 end
local function Libro()
  local porId,porNombre={},{}
  local function Anotar(id,slot,moderno,nombre,sub)
    if type(id)~="number" or id<=0 or porId[id] then return end
    nombre=nombre or Nombre(id)
    local f={id=id,slot=slot,moderno=moderno,nombre=nombre,rango=NumRango(id,sub)}
    porId[id]=f
    if nombre and f.rango>0 then
      porNombre[nombre]=porNombre[nombre] or {};table.insert(porNombre[nombre],f)
    end
  end
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
    for i=1,Seguro(C_SpellBook.GetNumSpellBookSkillLines) or 0 do
      local t=Seguro(C_SpellBook.GetSpellBookSkillLineInfo,i)
      if t then for j=(t.itemIndexOffset or 0)+1,(t.itemIndexOffset or 0)+(t.numSpellBookItems or 0) do
        local f=Seguro(C_SpellBook.GetSpellBookItemInfo,j,Banco())
        if f and f.itemType==(Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1) and not f.isPassive and not f.isOffSpec then
          -- No considerar una sustitución temporal como otro rango del hechizo.
          if not f.spellID or not f.actionID or f.spellID==f.actionID then Anotar(f.spellID or f.actionID,j,true,f.name,f.subName) end
        end
      end end
    end
  end
  if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
    for i=1,Seguro(GetNumSpellTabs) or 0 do
      local _,_,offset,n=Seguro(GetSpellTabInfo,i)
      if offset and n then for j=offset+1,offset+n do
        local tipo,id=Seguro(GetSpellBookItemInfo,j,BOOKTYPE_SPELL or "spell")
        if tipo=="SPELL" and not Seguro(IsPassiveSpell,id) then
          local nombre,sub=Seguro(GetSpellBookItemName,j,BOOKTYPE_SPELL or "spell")
          Anotar(id,j,false,nombre,sub)
        end
      end end
    end
  end
  return porId,porNombre
end
local function Conocido(id,libro)
  if libro and libro[id] then return true end
  return Seguro(C_SpellBook and C_SpellBook.IsSpellKnown,id,Banco())==true or
    Seguro(IsSpellKnown,id,false)==true or Seguro(IsPlayerSpell,id)==true
end
local function EnCombate() return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) end
local function Temporal()
  return Seguro(HasVehicleActionBar) or Seguro(HasOverrideActionBar) or Seguro(HasPossessBar) or
    Seguro(C_ActionBar and C_ActionBar.HasVehicleActionBar) or Seguro(C_ActionBar and C_ActionBar.HasOverrideActionBar) or
    Seguro(C_ActionBar and C_ActionBar.HasPossessBar)
end
local function Accion(ranura)
  return Seguro(GetActionInfo or (C_ActionBar and C_ActionBar.GetActionInfo),ranura)
end
-- Primero la cadena auditada. Fuera de ella solo el libro real, con nombre y
-- rangos explícitos no ambiguos. Nunca usar el ID resuelto por un nombre a secas.
local function MejorQue(id,nombre,libro,porNombre)
  local cadena=Seguro(GL.CadenaDeHechizo,id)
  if cadena then
    local pos
    for i,x in ipairs(cadena) do if x==id then pos=i;break end end
    if pos then
      for i=#cadena,pos+1,-1 do
        if Conocido(cadena[i],libro) then
          local rn,rv=NumRango(cadena[i]),NumRango(id)
          if rn==0 or rv==0 then rn,rv=i,pos end
          if rn>rv then return cadena[i],rn,rv end
        end
      end
      return nil
    end
  end
  local rv=NumRango(id);if rv==0 or not nombre then return nil end
  local rangos={[rv]=id};local mejor,rn=nil,rv
  for _,f in ipairs(porNombre[nombre] or {}) do
    if rangos[f.rango] and rangos[f.rango]~=f.id then return nil end
    rangos[f.rango]=f.id
    -- Una cadena de la guía distinta invalida la coincidencia por nombre.
    if Seguro(GL.CadenaDeHechizo,f.id) then return nil end
    if f.rango>rn then mejor,rn=f.id,f.rango end
  end
  return mejor,rn,rv
end

-- Ranuras de las barras con un rango viejo de los hechizos aprendidos. nombres: { [nombre] = true } o nil (todos).
-- Devuelve una lista { { nombre, nuevo, viejo, rangoNuevo, rangoViejo, ranuras = {...} } }.
local function Buscar(nombres, incluirIgnorados)
  local porHechizo, lista = {}, {}
  if not GetActionInfo and not (C_ActionBar and C_ActionBar.GetActionInfo) then return lista end
  local libro,porNombre=Libro()
  local ignorar = DB().rangosIgnorados or {}
  for ranura = 1, MAX_RANURA do
    local tipo,id=Accion(ranura)
    if tipo == "spell" and type(id)=="number" then
      local nombre = Nombre(id)
      if (nombre or not nombres) and (not nombres or nombres[nombre]) then
        local mejor, rn, rv = MejorQue(id,nombre,libro,porNombre)
        if mejor and (incluirIgnorados or not ignorar[id .. ">" .. mejor]) then
          local clave = id .. ">" .. mejor
          local h = porHechizo[clave]
          if not h then
            h = { nombre = nombre or Nombre(mejor) or "?", nuevo = mejor, viejo = id, rangoNuevo = rn, rangoViejo = rv, ranuras = {} }
            porHechizo[clave] = h
            table.insert(lista, h)
          end
          table.insert(h.ranuras, ranura)
        end
      end
    end
  end
  return lista
end

-- 9.7.9.3 (Quini: «los hechizos siguen sin cambiarse solos, aunque le des al botón»): antes, si el juego no tenía
-- PickupSpell (los clientes nuevos lo tienen en C_Spell) no se hacía nada y no se decía nada. Ahora se recoge con lo que
-- haya, se comprueba que el botón ha cambiado de verdad y, si no, se dice por qué (y queda en /ga informe).
local ultimoMotivo
local modificando=false
local function Cursor()
  if not GetCursorInfo then return "unknown" end
  local ok,tipo,slot,banco,id=pcall(GetCursorInfo)
  if not ok then return "unknown" end
  if tipo~="spell" then return tipo,nil end
  -- La segunda devolución es el índice del libro, NO el ID de hechizo.
  if type(id)=="number" then return tipo,id end
  if type(slot)=="number" then
    if type(banco)=="number" and C_SpellBook then
      local f=Seguro(C_SpellBook.GetSpellBookItemInfo,slot,banco)
      if f then return tipo,f.spellID or f.actionID end
    elseif banco=="spell" or banco==BOOKTYPE_SPELL then
      local t,x=Seguro(GetSpellBookItemInfo,slot,banco)
      if t=="SPELL" then return tipo,x end
    end
  end
  return tipo,nil
end
local function Recoger(id,libro)
  if not GetCursorInfo or not ClearCursor then return false,L"API de cursor no disponible" end
  if Cursor() then return false,L"cursor ocupado" end
  local formas={};local f=libro[id]
  -- El índice exacto del libro evita resolver por nombre o recoger otro rango.
  if f and f.moderno and C_SpellBook and C_SpellBook.PickupSpellBookItem then
    formas[#formas+1]=function() C_SpellBook.PickupSpellBookItem(f.slot,Banco()) end
  elseif f and not f.moderno and PickupSpellBookItem then
    formas[#formas+1]=function() PickupSpellBookItem(f.slot,BOOKTYPE_SPELL or "spell") end
  end
  if C_Spell and C_Spell.PickupSpell then formas[#formas+1]=function() C_Spell.PickupSpell(id) end end
  if PickupSpell then formas[#formas+1]=function() PickupSpell(id) end end
  for _,accion in ipairs(formas) do
    if EnCombate() or Temporal() then return false,L"barras bloqueadas" end
    pcall(accion)
    local t,x=Cursor()
    if t=="spell" and x==id then return true end
    if t then pcall(ClearCursor) end -- solo lo que acaba de recoger el addon
  end
  return false,L"no se pudo recoger el ID "..id
end
local function Sustituir(lista)
  if modificando then return 0,{} end
  ultimoMotivo=nil
  local n,fallos=0,{}
  modificando=true
  local libro,porNombre=Libro()
  local function Fallo(h,ranura,motivo)
    ultimoMotivo=motivo;fallos[#fallos+1]={viejo=h.viejo,nuevo=h.nuevo,ranura=ranura,motivo=motivo}
  end
  for _,h in ipairs(lista) do for _,ranura in ipairs(h.ranuras) do
    local tipo,id=Accion(ranura)
    if tipo=="spell" and id==h.viejo then
      local mejor=MejorQue(id,Nombre(id),libro,porNombre)
      if mejor~=h.nuevo then Fallo(h,ranura,L"rango aprendido cambiado; vuelve a revisar")
      elseif EnCombate() or Temporal() then Fallo(h,ranura,L"barras bloqueadas")
      elseif not PlaceAction or not GetCursorInfo or not ClearCursor then Fallo(h,ranura,L"API de barras no disponible")
      elseif Cursor() then Fallo(h,ranura,L"cursor ocupado")
      else
        local cogido,motivo=Recoger(h.nuevo,libro)
        if not cogido then Fallo(h,ranura,motivo)
        else
          local t,x=Accion(ranura)
          if t~="spell" or x~=h.viejo or EnCombate() or Temporal() then
            pcall(ClearCursor);Fallo(h,ranura,L"botón cambiado o bloqueado")
          else
            local ok,err=pcall(PlaceAction,ranura)
            local nt,nid=Accion(ranura)
            if nt=="spell" and nid==h.nuevo then n=n+1
            else
              -- Si la API cambió el botón a otra cosa y dejó el original en
              -- el cursor, restaurarlo antes de limpiar nuestro cursor.
              local ct,cid=Cursor()
              if (nt~="spell" or nid~=h.viejo) and ct=="spell" and cid==h.viejo and not EnCombate() then
                pcall(PlaceAction,ranura)
              end
              Fallo(h,ranura,L"botón "..ranura..L": esperado "..h.nuevo..L", recibido "..tostring(nid)..(ok and "" or " ("..tostring(err)..")"))
            end
            pcall(ClearCursor)
          end
        end
      end
    end -- una macro, objeto, botón vacío o hechizo movido nunca se sobreescribe
  end end
  modificando=false
  if #fallos>0 and GL.Fallo then GL.Fallo("rangos",ultimoMotivo) end
  return n,fallos
end
local function AvisarResultado(n,fallos)
  if not GL.Mensaje then return end
  if n>0 then GL.Mensaje(L"rangos nuevos puestos en "..n..(n==1 and L" botón" or L" botones")..".") end
  if fallos and #fallos>0 then
    GL.Mensaje((GL.ingles and "Ranks still pending: " or "Rangos pendientes: ")..#fallos..". "..tostring(ultimoMotivo or "?")..". /ga rangos")
  end
end

local function Linea(h)
  local veces = #h.ranuras == 1 and L"1 botón" or (#h.ranuras .. L" botones")
  return C.AMARILLO .. h.nombre .. C.FIN .. C.GRIS .. "  " .. L"rango" .. " " .. h.rangoViejo .. " → " .. C.FIN ..
    C.VERDE .. h.rangoNuevo .. C.FIN .. C.GRIS .. "  (" .. veces .. ")" .. C.FIN
end

-- ventana del aviso
local aviso, pendiente
local function CerrarAviso()
  if aviso then aviso.datos={};aviso.manual=nil;aviso:Hide() end
end
local function AvisoValido(f)
  return f:IsShown() and (f.manual or Activo())
end
local Programar, Reintentar
local function CrearAviso()
  local f = CreateFrame("Frame", "GuiaAventureroRangosBarras", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(360, 120)
  f:SetPoint("TOP", UIParent, "TOP", 0, -150)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if GL.Caja and GL.COLOR then GL.Caja(f, GL.COLOR.fondo, GL.COLOR.borde) end
  f.icono = f:CreateTexture(nil, "ARTWORK")
  f.icono:SetSize(32, 32)
  f.icono:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  f.titulo = GL.Texto(f, "GameFontNormal")
  f.titulo:SetPoint("TOPLEFT", f.icono, "TOPRIGHT", 8, -1)
  f.titulo:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.titulo:SetText(L"Rango nuevo en tus barras")
  f.sub = GL.Texto(f, "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", f.titulo, "BOTTOMLEFT", 0, -3)
  f.sub:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.sub:SetText(C.GRIS .. L"Tus botones siguen con el rango viejo. ¿Los cambio por el nuevo?" .. C.FIN)
  f.lista = GL.Texto(f, "GameFontHighlight")
  f.lista:SetPoint("TOPLEFT", f.icono, "BOTTOMLEFT", 2, -8)
  f.lista:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.lista:SetSpacing(3)
  f.si = GL.CrearBoton(f, L"Sustituir", function()
    if not AvisoValido(f) then CerrarAviso();return end
    local n,fallos=Sustituir(f.datos or {}); AvisarResultado(n,fallos)
    CerrarAviso()
    if #fallos>0 and Reintentar then Reintentar(fallos) end
  end, nil, 22, "accion")
  f.si:SetWidth(100)
  f.no = GL.CrearBoton(f, L"Ahora no", function()
    if not AvisoValido(f) then CerrarAviso();return end
    local ig = DB().rangosIgnorados or {}
    for _, h in ipairs(f.datos or {}) do ig[h.viejo .. ">" .. h.nuevo] = true end
    if GuiaAventureroDB then GuiaAventureroDB.rangosIgnorados = ig end
    CerrarAviso()
  end, nil, 22)
  f.no:SetWidth(90)
  f.siempre = GL.CrearBoton(f, L"Siempre solo", function()
    if not AvisoValido(f) then CerrarAviso();return end
    if GuiaAventureroDB then GuiaAventureroDB.rangosAuto = true; GuiaAventureroDB.rangosBarras = true end
    local n,fallos=Sustituir(f.datos or {}); AvisarResultado(n,fallos)
    if #fallos>0 and Reintentar then Reintentar(fallos) end
    if GL.Mensaje then GL.Mensaje(L"desde ahora los rangos nuevos se ponen solos en tus barras (se quita en Ajustes › General)." ) end
    CerrarAviso()
  end, nil, 22)
  f.siempre:SetWidth(110)
  f.si:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  f.no:SetPoint("LEFT", f.si, "RIGHT", 6, 0)
  f.siempre:SetPoint("LEFT", f.no, "RIGHT", 6, 0)
  if GL.Ayuda then
    GL.Ayuda(f.no, L"No vuelve a preguntar por estos rangos. Si cambias de idea, arrastra el hechizo nuevo desde el libro.")
    GL.Ayuda(f.siempre, L"Sustituye ahora y, desde ahora, sin preguntar. Se quita en Ajustes › General.")
  end
  f:Hide()
  return f
end

local function Mostrar(lista,manual,silencio)
  aviso = aviso or CrearAviso()
  aviso.datos = lista
  aviso.manual = manual == true
  local l = {}
  for i, h in ipairs(lista) do
    if i > 8 then table.insert(l, C.GRIS .. L"y " .. (#lista - 8) .. L" más" .. C.FIN); break end
    table.insert(l, Linea(h))
  end
  aviso.lista:SetText(table.concat(l, "\n"))
  local icono
  pcall(function()
    if C_Spell and C_Spell.GetSpellTexture then icono = C_Spell.GetSpellTexture(lista[1].nuevo)
    elseif GetSpellTexture then icono = GetSpellTexture(lista[1].nuevo) end
  end)
  aviso.icono:SetTexture(icono or "Interface\\Icons\\INV_Misc_Book_09")
  aviso:SetHeight(96 + math.min(#lista, 9) * 16)
  aviso:Show()
  if not silencio and PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPEN) end
end

local aprendidos,base,esperando={},nil,{}
local programado=false
local generacion=0
local function Clave(h) return h.viejo..">"..h.nuevo end
local function Revisar()
  if modificando then return end
  pendiente=false
  local activo=Activo()
  local manual=aviso and aviso:IsShown() and aviso.manual
  if not activo then
    aprendidos={};esperando={};base=nil
    if not manual then CerrarAviso();return end
  end
  if EnCombate() or Temporal() or Cursor() then pendiente=true;return end
  -- Un aviso manual puede incluir rangos ignorados; no convertirlos en acciones automáticas.
  if manual then
    local actuales,claves={},{}
    for _,h in ipairs(aviso.datos or {}) do claves[Clave(h)]=true end
    for _,h in ipairs(Buscar(nil,true)) do if claves[Clave(h)] then actuales[#actuales+1]=h end end
    if #actuales>0 then
      -- Una solicitud manual conserva la prioridad hasta que el jugador decida.
      Mostrar(actuales,true,true)
      return
    else CerrarAviso() end
    if not activo then return end
  end
  local todos=Buscar(nil)
  local lista={}
  local vistos={}
  for _,h in ipairs(todos) do
    local k=Clave(h);vistos[k]=true
    if (not base and Auto()) or aprendidos[h.nombre] or (base and not base[k]) or esperando[k] then
      lista[#lista+1]=h
    end
  end
  base=base or {}
  for _,h in ipairs(todos) do base[Clave(h)]=true end
  for k in pairs(esperando) do if not vistos[k] then esperando[k]=nil end end
  aprendidos={}
  if Auto() then
    if aviso and aviso:IsShown() and not aviso.manual then CerrarAviso() end
    if #lista==0 then return end
    for _,h in ipairs(lista) do esperando[Clave(h)]=nil end
    local n,fallos=Sustituir(lista)
    AvisarResultado(n,fallos)
    if #fallos>0 then Reintentar(fallos) end
  else
    -- Conservar avisos anteriores aún válidos al llegar otro lote de rangos.
    local claves={}
    for _,h in ipairs(lista) do claves[Clave(h)]=true end
    if aviso and aviso:IsShown() then
      for _,h in ipairs(aviso.datos or {}) do claves[Clave(h)]=true end
    end
    local esManual=aviso and aviso:IsShown() and aviso.manual
    local actuales={};for _,h in ipairs(esManual and Buscar(nil,true) or todos) do if claves[Clave(h)] then actuales[#actuales+1]=h end end
    if #actuales>0 then Mostrar(actuales,esManual,#lista==0) else CerrarAviso() end
  end
end
Programar=function(demora)
  if programado then return end
  programado=true
  local g=generacion
  local function Hacer()
    if g~=generacion then return end
    programado=false;Revisar()
  end
  if C_Timer and C_Timer.After then C_Timer.After(demora or ESPERA,Hacer) else Hacer() end
end
-- Reintentos limitados por lote; los siguientes eventos del juego vuelven a
-- comprobar las parejas pendientes sin dar por exitoso un cambio fallido.
local intentos=0
Reintentar=function(fallos)
  for _,f in ipairs(fallos) do esperando[Clave(f)]=true end
  if Auto() and intentos<3 and C_Timer and C_Timer.After then intentos=intentos+1;Programar(2*intentos) end
end
local ev=CreateFrame("Frame")
for _,e in ipairs({"LEARNED_SPELL_IN_SKILL_LINE","LEARNED_SPELL_IN_TAB","SPELLS_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","UPDATE_SHAPESHIFT_FORM","UPDATE_BONUS_ACTIONBAR","ACTIONBAR_PAGE_CHANGED","ACTIONBAR_SLOT_CHANGED","UPDATE_VEHICLE_ACTIONBAR","CURSOR_CHANGED","SPELL_DATA_LOAD_RESULT"}) do
  pcall(ev.RegisterEvent,ev,e)
end
ev:SetScript("OnEvent",function(_,event,id)
  if modificando then return end
  if event=="ACTIONBAR_SLOT_CHANGED" then
    if aviso and aviso:IsShown() then Programar() end
    return
  end
  if not Activo() and not (aviso and aviso:IsShown() and aviso.manual) then return end
  if event=="PLAYER_ENTERING_WORLD" then
    intentos=0;Programar(2);return
  end
  if event=="LEARNED_SPELL_IN_SKILL_LINE" or event=="LEARNED_SPELL_IN_TAB" then
    local nombre=type(id)=="number" and Nombre(id);if nombre then aprendidos[nombre]=true end
    intentos=0;Programar()
    -- Algunos clientes notifican antes de actualizar el libro.
    if C_Timer and C_Timer.After then
      local g=generacion
      C_Timer.After(4,function() if g==generacion and Activo() then Programar() end end)
    end
    return
  end
  if event=="SPELLS_CHANGED" then Programar();return end
  if event=="SPELL_DATA_LOAD_RESULT" then if next(esperando) or not base then Programar() end;return end
  if pendiente or next(esperando) then Programar() end
end)

-- /ga rangos: buscar ahora en las barras todos los rangos viejos (aunque no los acabes de aprender)
GL.comandos = GL.comandos or {}
GL.comandos["rangos"] = function()
  if EnCombate() then if GL.Mensaje then GL.Mensaje(L"en combate no se pueden cambiar las barras.") end; return end
  if Temporal() then if GL.Mensaje then GL.Mensaje(L"barras bloqueadas") end; return end
  local lista = Buscar(nil,true)
  if #lista == 0 then
    CerrarAviso()
    if GL.Mensaje then GL.Mensaje(L"tus barras ya tienen los rangos más altos que conoces.") end
  else
    Mostrar(lista,true)
  end
end

GL.ActualizarRangosBarras = function(cambio)
  if cambio or not Activo() then
    aprendidos={};esperando={};base=nil;pendiente=false
    generacion=generacion+1;programado=false;intentos=0
    if not (aviso and aviso:IsShown() and aviso.manual) then CerrarAviso() end
  end
end

GL._rangosBarras = { Buscar = Buscar, Sustituir = Sustituir, Revisar = Revisar, Aprendido = function(n) aprendidos[n] = true end }

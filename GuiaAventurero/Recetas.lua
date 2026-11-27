-- Recetas.lua: en el instructor de una profesión, aprende solas las recetas que usa la guía para seguir subiendo
-- y el rango siguiente de la profesión (oficial, experto, artesano). Creado por JKRiveroF.
-- Cada paso de profesión de la ruta dice qué fabrica (crea = ids de objeto) y, si la receta no hace un objeto
-- (los encantamientos), su nombre (recetas). Solo se aprenden las de los pasos que aún te quedan por subir.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores
local PLANTILLA = BackdropTemplateMixin and "BackdropTemplate" or nil
local ANCHO = 300
local MAX_LINEAS = 12
local MAX_OLEADAS = 6                  -- un rango nuevo abre recetas nuevas: se repite unas cuantas veces

local panel
local oleadas = 0
local comprando = false
local sesionInstructor = 0
local sesionAbierta, autoSesion = false, false
local rutaSesion, compraPendiente
local ejecutandoCompra = false


local function DB() return GuiaAventureroDB end
local function AutoActivo() return DB().autoRecetas ~= false end

local function Normalizar(s)
  if GL.Normalizar then return GL.Normalizar(s) end
  return (string.gsub(string.lower(s or ""), "[^%a%d]", ""))
end

local function Dinero(cobre)
  if GL.Dinero then return GL.Dinero(cobre) end
  return string.format("%.2f o", (cobre or 0) / 10000)
end

local function EsInstructorDeProfesion()
  if not IsTradeskillTrainer then return false end
  local ok, r = pcall(IsTradeskillTrainer)
  return ok and r and true or false
end

-- Objeto que fabrica la receta de ese servicio del instructor (nil si no fabrica nada).
local function ObjetoDelServicio(i)
  if not GetTrainerServiceItemLink then return nil end
  local ok, enlace = pcall(GetTrainerServiceItemLink, i)
  if ok and type(enlace) == "string" then return tonumber(string.match(enlace, "item:(%d+)")) end
  return nil
end

-- Identificador del hechizo, si el cliente ofrece un enlace de servicio.
local function HechizoDelServicio(i)
  if not GetTrainerServiceSpellLink then return nil end
  local ok, enlace = pcall(GetTrainerServiceSpellLink, i)
  if ok and type(enlace) == "string" then return tonumber(enlace:match("spell:(%d+)")) end
end

-- Habilidad y nivel requeridos por el servicio, cuando el cliente los informa.
local function HabilidadQuePide(i)
  if not GetTrainerServiceSkillReq then return nil end
  local ok, nombre, nivel = pcall(GetTrainerServiceSkillReq, i)
  if not ok then return nil end
  local clave = type(nombre) == "string" and Normalizar(nombre) or nil
  if clave == "" then clave = nil end
  return clave, type(nivel) == "number" and nivel >= 0 and nivel < math.huge and nivel or nil
end

-- Rangos de profesión tal como salen junto al nombre en el instructor.
local RANGOS = {}
for _, r in ipairs({ "Aprendiz", "Oficial", "Experto", "Artesano", "Maestro", "Gran maestro",
  "Apprentice", "Journeyman", "Expert", "Artisan", "Master", "Grand Master" }) do RANGOS[Normalizar(r)] = true end

-- Lo que les hace falta a los pasos que aún te quedan de una profesión: lo que fabrican, sus materiales
-- (una madeja de paño, por ejemplo) y las recetas sin objeto (los encantamientos). Guarda el primer paso que lo pide.
local function Necesidades(prof, nivel)
  local necesidades = {}
  for j, paso in ipairs(prof.pasos or {}) do
    if paso.h > nivel then
      local n = { j = j, paso = paso, hechizo = paso.sp975, objetos = {}, materiales = {}, nombres = {} }
      for _, id in ipairs(paso.crea or {}) do n.objetos[id] = true end
      for _, mat in ipairs(paso.mat or {}) do if mat[1] then n.materiales[mat[1]] = true end end
      for _, r in ipairs(paso.recetas or {}) do
        local k = Normalizar(r)
        if k ~= "" then n.nombres[k] = true end
        -- Las rutas antiguas guardan nombres españoles incluso en cliente inglés.
        -- Solo añadir equivalencias existentes en el diccionario (sin inferir IDs).
        local en = GL.clienteIngles and GL.EnIngles and GL.EnIngles(r)
        if type(en) == "string" and en ~= r then
          local alias = Normalizar(en)
          if alias ~= "" then n.nombres[alias] = true end
        end
      end
      necesidades[#necesidades + 1] = n
    end
  end
  return necesidades
end

local function MisProfesiones()
  local lista = {}
  if not (GL.RUTA and GL.NivelProfesion) then return lista end
  for _, prof in ipairs(GL.RUTA.profesiones or {}) do
    local ok, nivel, tope = pcall(GL.NivelProfesion, prof)
    if ok and type(nivel) == "number" and nivel > 0 and nivel < math.huge then
      table.insert(lista, { prof = prof, nivel = nivel, tope = tope, clave = Normalizar(prof.nombre),
        necesidades = Necesidades(prof, nivel) })
    end
  end
  return lista
end

-- Un ID explícito contradictorio no se sustituye por un nombre o producto coincidente.
-- Los componentes indirectos solo se compran si se conoce la profesión requerida.
local function Coincidencia(m, clave, sub, objeto, hechizo, pide)
  if GL.RequisitoEspecialidad975 then
    if GL.RequisitoEspecialidad975(clave) or (clave==m.clave and GL.RequisitoEspecialidad975(sub)) then return nil end
    local sk,ix=GL.RequisitoEspecialidad975(pide)
    if sk then
      if sk~=m.prof.skill or not GL.EstadoEspecialidades975 then return nil end
      local estado,_,indices=GL.EstadoEspecialidades975(sk)
      if estado~="aprendida" or not indices[ix] then return nil end
      pide=m.clave
    end
  end
  if pide and pide ~= m.clave then return nil end
  if not objeto and RANGOS[Normalizar(sub)] and (clave == m.clave or pide == m.clave)
      and m.prof.skill ~= 40 and m.prof.skill ~= 633 and (not m.tope or m.tope < 300) then
    return { orden = 0, m = m, rango = true, fuerza = 4 }
  end
  local mejor
  for _, n in ipairs(m.necesidades) do
    local fuerza, material
    if hechizo and n.hechizo == hechizo then fuerza = 3
    elseif not (hechizo and n.hechizo) and n.nombres[clave] then fuerza = 2
    elseif not (hechizo and n.hechizo) and objeto and n.objetos[objeto] then fuerza = 1
    elseif objeto and pide == m.clave and n.materiales[objeto] and not n.objetos[objeto] then fuerza, material = 1, true end
    if fuerza and (not mejor or fuerza > mejor.fuerza) then
      mejor = { orden = n.j, m = m, paso = n.paso, material = material, fuerza = fuerza }
    end
  end
  return mejor
end

local function Servicios()
  local filas, otras, luego, mias = {}, {}, {}, MisProfesiones()
  local sinConfirmar = 0
  if not (GetNumTrainerServices and GetTrainerServiceInfo) then return filas, otras, luego, mias, sinConfirmar end
  for i = 1, (GetNumTrainerServices() or 0) do
    local nombre, sub, tipo = GetTrainerServiceInfo(i)
    if nombre and (tipo == "available" or tipo == "unavailable") then
      local clave, objeto, hechizo = Normalizar(nombre), ObjetoDelServicio(i), HechizoDelServicio(i)
      local pide, nivelPide = HabilidadQuePide(i)
      local elegido, ambiguo, contradiccion
      for _, m in ipairs(mias) do
        local n = Coincidencia(m, clave, sub, objeto, hechizo, pide)
        if not n and hechizo and (not pide or pide == m.clave) then
          for _, necesidad in ipairs(m.necesidades) do
            if necesidad.hechizo and necesidad.hechizo ~= hechizo and
                (necesidad.nombres[clave] or (objeto and necesidad.objetos[objeto])) then contradiccion = true; break end
          end
        end
        if n then
          if not elegido or n.fuerza > elegido.fuerza then elegido, ambiguo = n, false
          elseif n.fuerza == elegido.fuerza and n.m ~= elegido.m then ambiguo = true end
        end
      end
      if not elegido and GL.RequisitoEspecialidad975 and
          (GL.RequisitoEspecialidad975(pide) or GL.RequisitoEspecialidad975(clave) or GL.RequisitoEspecialidad975(sub)) then
        contradiccion = true -- requisito o desbloqueo de especialización: revisar manualmente
      end
      if ambiguo then elegido = nil end
      if elegido and (tipo == "unavailable" or (nivelPide and nivelPide > elegido.m.nivel)) then
        table.insert(luego, { nombre = nombre, sub = sub, pide = nivelPide, prof = elegido.m.prof })
      elseif tipo == "available" then
        local okP, precio = pcall(GetTrainerServiceCost or function() end, i)
        if okP and type(precio) == "number" and precio >= 0 and precio < math.huge then
          if elegido then
            table.insert(filas, { i = i, nombre = nombre, sub = sub, precio = precio, orden = elegido.orden,
              prof = elegido.m.prof, tope = elegido.m.tope, paso = elegido.paso, rango = elegido.rango,
              material = elegido.material, hechizo = hechizo, objeto = objeto, habilidad = pide })
          elseif not ambiguo and not contradiccion then
            table.insert(otras, { i = i, nombre = nombre, sub = sub, precio = precio })
          end
        elseif elegido then sinConfirmar = sinConfirmar + 1 end
        if not elegido and (ambiguo or contradiccion) then sinConfirmar = sinConfirmar + 1 end
      end
    end
  end
  table.sort(filas, function(a, b)
    if a.orden ~= b.orden then return a.orden < b.orden end
    return a.i < b.i
  end)
  return filas, otras, luego, mias, sinConfirmar
end

-- 9.7.4: ¿la guía tiene plan para la profesión de este instructor? (por la habilidad que piden sus recetas)
local function ProfesionDelInstructor(mias)
  if not GetNumTrainerServices then return nil, false end
  local primera
  for i = 1, (GetNumTrainerServices() or 0) do
    local pide = HabilidadQuePide(i)
    if pide then
      primera = primera or pide
      for _, m in ipairs(mias) do if m.clave == pide then return pide, true end end
    end
  end
  if primera then return primera, false end
  return nil, #mias > 0
end

-- Lista corta de nombres: "A, B, C y 4 más".
local function ListaCorta(t, max)
  local n = {}
  for i, f in ipairs(t) do
    if i > max then break end
    table.insert(n, f.nombre)
  end
  local s = table.concat(n, ", ")
  if #t > max then s = s .. L" y " .. (#t - max) .. L" más" end
  return s
end

local function Motivo(f)
  if f.rango then
    return L"Rango nuevo de " .. f.prof.nombre .. (f.tope and (L": sin él no pasas de " .. f.tope) or "") .. "."
  end
  local tramo = f.prof.nombre .. L" de " .. f.paso.d .. " a " .. f.paso.h
  if f.material then return L"Hace el material que pide " .. tramo .. "." end
  return L"Para subir " .. tramo .. "."
end

local function NombreServicio(f)
  if f.sub and f.sub ~= "" then return f.nombre .. " (" .. f.sub .. ")" end
  return f.nombre
end

------------------------------------------------------------------------
-- Panel junto a la ventana del instructor
------------------------------------------------------------------------
local Aprender

local function CrearPanel()
  panel = CreateFrame("Frame", "GuiaAventureroRecetas", UIParent, PLANTILLA)
  panel:SetWidth(ANCHO)
  panel:SetHeight(120)
  panel:SetFrameStrata("HIGH")
  GL.Caja(panel, GL.COLOR.fondo, GL.COLOR.borde)
  GL.Sombra(panel)
  GL.Acento(panel, 2)
  panel.titulo = GL.Texto(panel, "GameFontNormal")
  panel.titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
  panel.titulo:SetText(L"Guía del Aventurero: recetas que hacen falta")
  panel.sub = GL.Texto(panel, "GameFontHighlightSmall")
  panel.sub:SetPoint("TOPLEFT", panel.titulo, "BOTTOMLEFT", 0, -2)
  panel.sub:SetText(C.GRIS .. L"Lo que usa la guía para seguir subiendo, en orden." .. C.FIN)
  panel.lineas = {}
  for i = 1, MAX_LINEAS do
    local t = GL.Texto(panel, "GameFontHighlightSmall")
    t:SetWidth(ANCHO - 24)
    panel.lineas[i] = t
  end
  panel.pie = GL.Texto(panel, "GameFontHighlightSmall")
  panel.pie:SetWidth(ANCHO - 24)
  panel.boton = GL.CrearBoton(panel, L"Aprender lo de la guía", function() Aprender(true) end, nil, 22, "accion")
  panel.boton:SetWidth(ANCHO - 24)
  GL.Ayuda(panel.boton, L"Aprender lo de la guía",
    L"Aprende el rango nuevo y las recetas de la guía, en orden, mientras te llegue el dinero.")
  panel:Hide()
end

local function Colocar()
  panel:ClearAllPoints()
  local trainer = ClassTrainerFrame
  if trainer and trainer.IsShown and trainer:IsShown() then
    panel:SetPoint("TOPLEFT", trainer, "TOPRIGHT", 4, 0)
  else
    panel:SetPoint("LEFT", UIParent, "LEFT", 420, 60)
  end
end

local function Actualizar()
  if not panel then CrearPanel() end
  local filas, otras, luego, mias, sinConfirmar = Servicios()
  local _, conPlan = ProfesionDelInstructor(mias or {})
  local coste = 0
  local y = -44
  for i = 1, MAX_LINEAS do
    local t = panel.lineas[i]
    local f = filas[i]
    if f then
      local texto = C.AMARILLO .. i .. ". " .. C.FIN .. C.BLANCO .. NombreServicio(f) .. C.FIN ..
        C.GRIS .. "  " .. Dinero(f.precio) .. "\n" .. Motivo(f) .. C.FIN
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
      t:SetText(texto)
      t:Show()
      y = y - GL.Alto(t, texto, 12, ANCHO - 24) - 5
    else
      t:Hide()
    end
  end
  for _, f in ipairs(filas) do coste = coste + f.precio end
  local pie
  if not conPlan then
    pie = C.AMARILLO .. L"La guía no tiene plan para esta profesión con tu personaje." .. C.FIN .. "\n" ..
      C.GRIS .. L"Compra solo las recetas de lo que vayas a fabricar o vender." .. C.FIN
  elseif #filas == 0 and sinConfirmar > 0 then
    pie = ""
  elseif #filas == 0 then
    pie = C.VERDE .. L"Ya tienes todo lo que la guía usa de este instructor: no hace falta comprar nada ahora." .. C.FIN
  else
    local dinero = (GetMoney and GetMoney()) or 0
    pie = L"Cuesta " .. Dinero(coste) .. C.GRIS .. L"  (tienes " .. Dinero(dinero) .. ")" .. C.FIN
    if coste > dinero then pie = pie .. "\n" .. C.AMARILLO .. L"No te llega para todo: se aprende en orden lo que puedas pagar." .. C.FIN end
    if #filas > MAX_LINEAS then pie = pie .. "\n" .. C.GRIS .. "Y " .. (#filas - MAX_LINEAS) .. L" más." .. C.FIN end
    if AutoActivo() then
      pie = pie .. "\n" .. C.GRIS .. L"La guía lo aprende sola al abrir el instructor (Mayús para no hacerlo)." .. C.FIN
    end
  end
  if sinConfirmar > 0 then
    pie = pie .. (pie ~= "" and "\n" or "") .. C.AMARILLO .. L"Hay recetas con identidad o coste sin confirmar. Revísalas manualmente." .. C.FIN
  end
  -- 9.7.4: lo que no hace falta y lo que vendrá, para saber qué comprar y qué no
  if conPlan and otras and #otras > 0 then
    pie = pie .. "\n\n" .. C.GRIS .. L"No hace falta comprar (la guía no las usa para subir): " .. C.FIN ..
      ListaCorta(otras, 6) .. "."
  end
  if conPlan and luego and #luego > 0 then
    local l = luego[1]
    pie = pie .. "\n\n" .. C.GRIS .. L"Más adelante la guía usará: " .. C.FIN .. ListaCorta(luego, 4) ..
      (l.pide and (C.GRIS .. L" (la primera pide " .. l.pide .. L" de habilidad)" .. C.FIN) or "") .. "."
  end
  panel.pie:ClearAllPoints()
  panel.pie:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y - 4)
  panel.pie:SetText(pie)
  local altoPie = GL.Alto(panel.pie, pie, 12, ANCHO - 24)
  local alto = -y + 4 + altoPie + 14
  if #filas > 0 then
    panel.boton:ClearAllPoints()
    panel.boton:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y - 4 - altoPie - 8)
    panel.boton:Show()
    alto = alto + 30
  else
    panel.boton:Hide()
  end
  panel:SetHeight(alto)
end

-- Texto de lo que no se puede pagar: "Encantador artesano (5o)" o "Encantador artesano (5o) y 2 más".
local function TextoFaltan(faltan)
  local f = faltan[1]
  local t = NombreServicio(f) .. " (" .. Dinero(f.precio) .. ")"
  if #faltan > 1 then t = t .. " y " .. (#faltan - 1) .. L" más" end
  return t
end

local function EnCombateCompra()
  return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function SaldoCompra(manual)
  local ok, total = pcall(GetMoney or function() end)
  if not ok or type(total) ~= "number" or total < 0 or total >= math.huge or total ~= total then return nil end
  if manual then return total end
  if GL.ReservaOro then
    local valido, reserva = pcall(GL.ReservaOro, true)
    if not valido or type(reserva) ~= "number" or reserva < 0 or reserva >= math.huge or reserva ~= reserva then return nil end
    return math.max(0, total - reserva)
  end
  if GL.DineroParaComprar then
    local valido, saldo = pcall(GL.DineroParaComprar, false)
    if valido and type(saldo) == "number" and saldo >= 0 and saldo < math.huge then return math.min(total, saldo) end
    return nil
  end
  return total
end

local function CompraPermitida(manual, sesion)
  if EnCombateCompra() or not sesionAbierta or sesion ~= sesionInstructor or not GL.RUTA or GL.RUTA ~= rutaSesion then return false end
  if not manual and (not autoSesion or not AutoActivo() or (IsShiftKeyDown and IsShiftKeyDown())) then return false end
  if ClassTrainerFrame and ClassTrainerFrame.IsShown and not ClassTrainerFrame:IsShown() then return false end
  if IsTradeskillTrainer then
    local ok, profesion = pcall(IsTradeskillTrainer)
    if not ok or (not not profesion) ~= true then return false end
  else return false end
  return true
end

-- Aprende en orden lo que pide la guía. Si no llega el dinero para algo, lo salta y sigue con lo siguiente que se
-- pueda pagar: el rango va primero, así que nunca se queda sin él por comprar recetas, y una receta barata que ya
-- puedes usar no espera a que tengas el oro del rango.
local function SolicitarCompra(manual)
  local sesion = sesionInstructor
  if not CompraPermitida(manual, sesion) then return 0 end
  if not (GetNumTrainerServices and GetTrainerServiceInfo and BuyTrainerService) then return 0 end
  local filas = Servicios()
  local dinero = SaldoCompra(manual)
  if type(dinero) ~= "number" or dinero < 0 or dinero >= math.huge or dinero ~= dinero then return 0 end
  local elegidos, faltan, gasto = {}, {}, 0
  for _, f in ipairs(filas) do
    if gasto + f.precio <= dinero then
      table.insert(elegidos, f)
      gasto = gasto + f.precio
    else
      table.insert(faltan, f)
    end
  end
  if #elegidos == 0 then
    if manual then
      GL.Mensaje(#faltan > 0 and (L"no te llega el dinero para " .. TextoFaltan(faltan) .. ".")
        or L"no hay ninguna receta de la guía que aprender aquí ahora.")
    elseif #faltan > 0 and GL.AvisoReserva then
      GL.AvisoReserva(faltan[1].precio)
    end
    return 0
  end
  local nombres, solicitado = {}, 0
  -- Revalidar cada fila: una compra o un evento puede cambiar el diálogo, el índice o el precio.
  table.sort(elegidos, function(a, b) return a.i > b.i end)
  for _, f in ipairs(elegidos) do
    if not CompraPermitida(manual, sesion) then break end
    local ok, nombre, sub, tipo = pcall(GetTrainerServiceInfo, f.i)
    local okP, precio = pcall(GetTrainerServiceCost or function() end, f.i)
    if not ok or nombre ~= f.nombre or sub ~= f.sub or tipo ~= "available" or not okP or precio ~= f.precio then break end
    local vigente
    for _, actual in ipairs(Servicios()) do
      if actual.i == f.i and actual.nombre == f.nombre and actual.sub == f.sub and actual.precio == f.precio
          and actual.prof == f.prof and actual.paso == f.paso and actual.rango == f.rango
          and actual.hechizo == f.hechizo and actual.objeto == f.objeto and actual.habilidad == f.habilidad then
        vigente = true; break
      end
    end
    if not vigente then break end
    local saldo = SaldoCompra(manual)
    if type(saldo) ~= "number" or saldo ~= saldo or saldo < precio or saldo >= math.huge or not CompraPermitida(manual, sesion) then break end
    local pedido, resultado = pcall(BuyTrainerService, f.i)
    if not pedido or resultado == false then break end
    table.insert(nombres, NombreServicio(f))
    solicitado = solicitado + precio
  end
  if #nombres > 0 then
    if sesionAbierta and sesion == sesionInstructor then comprando = true end
    GL.Mensaje(L"solicito aprender en el instructor de profesión: " .. table.concat(nombres, ", ") .. " (" .. Dinero(solicitado) .. ").")
  end
  if #nombres == #elegidos and #faltan > 0 then
    GL.Mensaje(L"no te llega el dinero para " .. TextoFaltan(faltan) .. L": vuelve cuando lo tengas.")
  end
  return #nombres
end

Aprender = function(manual)
  if ejecutandoCompra then return 0 end
  ejecutandoCompra = true
  local ok, n = pcall(SolicitarCompra, manual)
  ejecutandoCompra = false
  if not ok then error(n) end
  return n
end

local function MostrarPanel()
  local ok, err = pcall(Actualizar)
  if ok then
    Colocar()
    panel:Show()
  elseif GL.Fallo(L"panel de recetas", err) then
    GL.Mensaje(L"error: " .. tostring(err))
  end
end

local function CompraAutomatica()
  if not (sesionAbierta and autoSesion and GL.RUTA and GL.RUTA == rutaSesion) then return end
  if not CompraPermitida(false, sesionInstructor) or oleadas >= MAX_OLEADAS then return end
  if not EsInstructorDeProfesion() then return end
  oleadas = oleadas + 1
  local ok, n = pcall(Aprender, false)
  if not ok and GL.Fallo("recetas", n) then GL.Mensaje(L"error: " .. tostring(n)) end
end

function GL.CancelarCompraRecetas()
  autoSesion, compraPendiente = false, nil
end

local function ProgramarCompra()
  if not (sesionAbierta and autoSesion and AutoActivo()) or compraPendiente then return end
  local sesion = sesionInstructor
  local function ejecutar()
    if compraPendiente ~= ejecutar then return end
    compraPendiente = nil
    if sesion == sesionInstructor then CompraAutomatica() end
  end
  compraPendiente = ejecutar
  if C_Timer and C_Timer.After then C_Timer.After(0.3, ejecutar) else ejecutar() end
end

local eventos = CreateFrame("Frame")
GL.Evento(eventos, "TRAINER_SHOW")
GL.Evento(eventos, "TRAINER_UPDATE")
GL.Evento(eventos, "TRAINER_CLOSED")
eventos:SetScript("OnEvent", function(self, event)
  if event == "TRAINER_SHOW" or event == "TRAINER_CLOSED" then
    sesionInstructor = sesionInstructor + 1
    sesionAbierta, autoSesion, compraPendiente = false, false, nil
    rutaSesion, comprando = nil, false
  end
  if event == "TRAINER_CLOSED" then
    if panel then panel:Hide() end
    comprando = false
    return
  end
  if not GL.RUTA then return end
  if not EsInstructorDeProfesion() then
    if panel then panel:Hide() end
    return
  end
  if event == "TRAINER_SHOW" then
    oleadas = 0
    comprando = false
    local conMayus = IsShiftKeyDown and IsShiftKeyDown()
    sesionAbierta, autoSesion, rutaSesion = true, not conMayus and AutoActivo(), GL.RUTA
    if DB().instructor ~= false then MostrarPanel() end
    ProgramarCompra()
    return
  end
  -- TRAINER_UPDATE: tras aprender un rango salen recetas nuevas
  if panel and panel:IsShown() then MostrarPanel() end
  if comprando then
    comprando = false
    ProgramarCompra()
  end
  if GL.ProgramarRefresco then GL.ProgramarRefresco() end
end)

GL.AprenderRecetas = Aprender

GL.comandos["autorecetas"] = function()
  local db = DB()
  db.autoRecetas = (db.autoRecetas == false)
  if not db.autoRecetas then GL.CancelarCompraRecetas() end
  GL.Mensaje(db.autoRecetas and L"aprender solas las recetas de la guía en el instructor de profesión: activado (Mayús al abrirlo para no hacerlo)."
    or L"aprender solas las recetas de la guía en el instructor de profesión: desactivado (usa el botón del panel).")
end

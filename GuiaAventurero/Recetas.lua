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

-- Nombre (normalizado) de la habilidad que pide ese servicio: en un instructor de sastrería, "sastreria".
local function HabilidadQuePide(i)
  if not GetTrainerServiceSkillReq then return nil end
  local ok, nombre = pcall(GetTrainerServiceSkillReq, i)
  if ok and type(nombre) == "string" and nombre ~= "" then return Normalizar(nombre) end
  return nil
end

-- Rangos de profesión tal como salen junto al nombre en el instructor.
local RANGOS = {}
for _, r in ipairs({ "Aprendiz", "Oficial", "Experto", "Artesano", "Maestro", "Gran maestro",
  "Apprentice", "Journeyman", "Expert", "Artisan", "Master", "Grand Master" }) do RANGOS[Normalizar(r)] = true end

-- Lo que les hace falta a los pasos que aún te quedan de una profesión: lo que fabrican, sus materiales
-- (una madeja de paño, por ejemplo) y las recetas sin objeto (los encantamientos). Guarda el primer paso que lo pide.
local function Necesidades(prof, nivel)
  local objetos, nombres = {}, {}
  for j, paso in ipairs(prof.pasos or {}) do
    if paso.h > nivel then
      for _, id in ipairs(paso.crea or {}) do objetos[id] = objetos[id] or { j = j } end
      for _, mat in ipairs(paso.mat or {}) do
        if mat[1] then objetos[mat[1]] = objetos[mat[1]] or { j = j, material = true } end
      end
      for _, r in ipairs(paso.recetas or {}) do
        local k = Normalizar(r)
        nombres[k] = nombres[k] or { j = j }
      end
    end
  end
  return objetos, nombres
end

-- Profesiones de la ruta que ya tienes, con tu nivel en cada una y lo que les falta.
local function MisProfesiones()
  local lista = {}
  if not (GL.RUTA and GL.NivelProfesion) then return lista end
  for _, prof in ipairs(GL.RUTA.profesiones or {}) do
    local ok, nivel, tope = pcall(GL.NivelProfesion, prof)
    if ok and nivel then
      local objetos, nombres = Necesidades(prof, nivel)
      table.insert(lista, { prof = prof, nivel = nivel, tope = tope, clave = Normalizar(prof.nombre),
        objetos = objetos, nombres = nombres })
    end
  end
  return lista
end

-- Lo que la guía quiere de este instructor: el rango siguiente primero y luego las recetas por orden de paso.
-- El rango de aprendiz no está aquí: solo se sube lo que ya tienes (elegir profesión es cosa tuya).
local function Servicios()
  local filas = {}
  local otras, luego = {}, {}          -- 9.7.4: lo que no hace falta comprar y lo que la guía querrá más adelante
  local mias = MisProfesiones()
  if not GetNumTrainerServices then return filas, otras, luego, mias end
  for i = 1, (GetNumTrainerServices() or 0) do
    local nombre, sub, tipo = GetTrainerServiceInfo(i)
    if tipo == "unavailable" and nombre then
      local clave = Normalizar(nombre)
      local objeto = ObjetoDelServicio(i)
      for _, m in ipairs(mias) do
        if (objeto and m.objetos[objeto]) or m.nombres[clave] then
          local okR, _, nivelPide = pcall(GetTrainerServiceSkillReq or function() end, i)
          table.insert(luego, { nombre = nombre, sub = sub, pide = okR and nivelPide or nil, prof = m.prof })
          break
        end
      end
    elseif tipo == "available" and nombre then
      local clave = Normalizar(nombre)
      local objeto = ObjetoDelServicio(i)
      local pide = HabilidadQuePide(i)
      local elegido
      for _, m in ipairs(mias) do
        local esRango = clave == m.clave or (not objeto and RANGOS[Normalizar(sub)] and pide == m.clave)
        if esRango then
          elegido = { orden = 0, m = m, rango = true }
          break
        end
        local n = (objeto and m.objetos[objeto]) or m.nombres[clave]
        if n and (not elegido or n.j < elegido.orden) then
          elegido = { orden = n.j, m = m, paso = m.prof.pasos[n.j], material = n.material }
        end
      end
      local precio = (GetTrainerServiceCost and GetTrainerServiceCost(i)) or 0
      if elegido then
        table.insert(filas, { i = i, nombre = nombre, sub = sub, precio = precio, orden = elegido.orden,
          prof = elegido.m.prof, tope = elegido.m.tope, paso = elegido.paso, rango = elegido.rango,
          material = elegido.material })
      else
        table.insert(otras, { i = i, nombre = nombre, sub = sub, precio = precio })
      end
    end
  end
  table.sort(filas, function(a, b)
    if a.orden ~= b.orden then return a.orden < b.orden end
    return a.i < b.i
  end)
  return filas, otras, luego, mias
end

-- 9.7.4: ¿la guía tiene plan para la profesión de este instructor? (por la habilidad que piden sus recetas)
local function ProfesionDelInstructor(mias)
  if not GetNumTrainerServices then return nil, false end
  for i = 1, (GetNumTrainerServices() or 0) do
    local pide = HabilidadQuePide(i)
    if pide then
      for _, m in ipairs(mias) do if m.clave == pide then return pide, true end end
      return pide, false
    end
  end
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
  local filas, otras, luego, mias = Servicios()
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

-- Aprende en orden lo que pide la guía. Si no llega el dinero para algo, lo salta y sigue con lo siguiente que se
-- pueda pagar: el rango va primero, así que nunca se queda sin él por comprar recetas, y una receta barata que ya
-- puedes usar no espera a que tengas el oro del rango.
Aprender = function(manual)
  if not (GetNumTrainerServices and GetTrainerServiceInfo and BuyTrainerService) then return 0 end
  local filas = Servicios()
  local dinero = (GL.DineroParaComprar and GL.DineroParaComprar(manual)) or (GetMoney and GetMoney()) or 0   -- 9.1: reserva para el 40
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
  local nombres = {}
  for _, f in ipairs(elegidos) do table.insert(nombres, NombreServicio(f)) end
  -- de la última fila a la primera, para que una compra no mueva el número de las demás
  table.sort(elegidos, function(a, b) return a.i > b.i end)
  for _, f in ipairs(elegidos) do pcall(BuyTrainerService, f.i) end
  comprando = true
  GL.Mensaje(L"aprendo en el instructor de profesión: " .. table.concat(nombres, ", ") .. " (" .. Dinero(gasto) .. ").")
  if #faltan > 0 then
    GL.Mensaje(L"no te llega el dinero para " .. TextoFaltan(faltan) .. L": vuelve cuando lo tengas.")
  end
  return #elegidos
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
  if not AutoActivo() or oleadas >= MAX_OLEADAS then return end
  if not EsInstructorDeProfesion() then return end
  oleadas = oleadas + 1
  local ok, n = pcall(Aprender, false)
  if not ok and GL.Fallo("recetas", n) then GL.Mensaje(L"error: " .. tostring(n)) end
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
    sesionAbierta, autoSesion, rutaSesion = true, not conMayus, GL.RUTA
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
  GL.Mensaje(db.autoRecetas and L"aprender solas las recetas de la guía en el instructor de profesión: activado (Mayús al abrirlo para no hacerlo)."
    or L"aprender solas las recetas de la guía en el instructor de profesión: desactivado (usa el botón del panel).")
end

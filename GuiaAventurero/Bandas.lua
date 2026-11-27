-- Bandas.lua (9.4): pestaña Bandas del botón Mazmorras y bandas. Cada banda con su entrada (Llevarme) y los
-- pasos para poder entrar (attunement) de tu facción, cada misión con su estado y Llevarme; abajo, el equipo
-- antes de banda de tu clase con dónde sale (marcado si ya lo tienes). Mapa: la banda en grande con sus jefes y su
-- botín (DatosBandas94.lua). Datos en Datos94.lua (QuestieDB).
-- Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local function Seguro(f, ...)
  if type(f) ~= "function" then return nil end
  local ok, r, segundo = pcall(f, ...)
  if not ok or (issecretvalue and issecretvalue(r)) then return nil end
  if issecretvalue and issecretvalue(segundo) then segundo = nil end
  return r, segundo
end
local function Lado()
  local f = Seguro(UnitFactionGroup, "player")
  if f == "Horde" then return "H" elseif f == "Alliance" then return "A" end
end
local function Clase() local _, c = Seguro(UnitClass, "player"); return type(c) == "string" and c or nil end
local function Hecha(q) return Seguro(GL.MisionCompletada, q) == true end
local function Llevo(q) return Seguro(GL.MisionEnDiario, q) == true end
local function Tengo(id)
  local n = Seguro(GL.InventarioProfesion975, id)
  if type(n) ~= "number" or n ~= n or n < 0 or n == math.huge or n % 1 ~= 0 then return nil end
  return n > 0
end
local function IconoEquipo(id)
  local t = Seguro(C_Item and C_Item.GetItemIconByID, id)
  if type(t) ~= "number" and type(t) ~= "string" then t = Seguro(GetItemIcon, id) end
  if type(t) == "number" and t > 0 and t < math.huge and t % 1 == 0 then return t end
  if type(t) == "string" and t ~= "" then return t end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function EnlaceEquipo(id, nombre)
  local _, enlace = Seguro(C_Item and C_Item.GetItemInfo, id)
  if type(enlace) ~= "string" or enlace == "" then _, enlace = Seguro(GetItemInfo, id) end
  return type(enlace) == "string" and enlace ~= "" and enlace or nombre
end

local function DestinoPaso(p, enDiario)
  local quiero = enDiario and "T" or "A"
  for _, w in ipairs(p.wp or {}) do if w.a == quiero then return w end end
end
-- El amuleto tiene que estar con el personaje; el banco no acredita el acceso.
local function AmuletoOnyxia()
  local n = Seguro(GL.BolsasProfesion975, 16309)
  if type(n) == "number" and n == n and n > 0 and n < math.huge and n % 1 == 0 then return true end
  local equipado = Seguro(GetInventoryItemID, "player", 2)
  if equipado == 16309 then return true end
  if n == 0 then return false end
end
local function NotaAcceso(b)
  if b.anuncioForever977 then return L"Apertura anunciada para el 9 de diciembre de 2026; contenido pendiente de validar." .. " " .. L(b.nota or "") end
  if (b.clave or b.n) == "Guarida de Onyxia" or b.ing == "Onyxia's Lair" then
    local a = AmuletoOnyxia()
    return L"Onyxia: apertura anunciada para el 9 de diciembre de 2026. Ambas facciones necesitan llevar el Amuleto de Pirodraco." .. " " ..
      (a == true and L"Amuleto detectado." or (a == false and L"Amuleto no detectado en el inventario." or L"Inventario sin confirmar."))
  end
  return L"Referencia de Classic; disponibilidad y acceso en Forever sin confirmar." .. " " .. (b.nota or "")
end

local verEquipo = false
local bandaBuscada
function GL.AbrirBanda976(nombre)
  if not GL.AbrirModo or not GuiaAventureroDB then return false end
  for _, b in ipairs((GL.D94 and GL.D94.bandas) or {}) do
    if nombre == b.clave or nombre == b.n or nombre == b.ing then
      bandaBuscada = b.clave or b.n; verEquipo = false
      GuiaAventureroDB.pestanaMaz = "bandas"; GL.AbrirModo("mazmorras"); return true
    end
  end
  return false
end
local function Filas()
  local filas = {}
  if verEquipo then
    local lista = (GL.D94 and GL.D94.prebanda and GL.D94.prebanda[Clase() or ""]) or {}
    local tengo, desconocidos = 0, 0
    for _, o in ipairs(lista) do
      local si = Tengo(o.id)
      if si then tengo = tengo + 1 elseif si == nil then desconocidos = desconocidos + 1 end
      local consejo = ""
      if GL.BotinUtil then
        local ok, util, mejor, _, pendiente, aviso = pcall(GL.BotinUtil, o.id)
        if ok then
          if mejor then consejo = " · " .. L"posible mejora"
          elseif util then consejo = " · " .. L"utilizable" end
          if aviso and GL.AvisoBotin977 then consejo = consejo .. " · " .. GL.AvisoBotin977(aviso) end
          if pendiente then consejo = consejo .. " · " .. L"Datos de botín pendientes de cargar." end
        end
      end
      -- 9.4.2: con el icono de la pieza y su tooltip del juego al pasar el ratón
      local icono = IconoEquipo(o.id)
      table.insert(filas, { hecha = si == true, texto = EnlaceEquipo(o.id, o.n), detalle = (o.fuente or "") .. consejo,
        ayudaTitulo = o.n, ayudaTexto = o.fuente, icono = icono, objeto = o.id })
    end
    return filas, L"Equipo antes de banda para tu clase: lo que conviene tener antes del Núcleo de Magma. Lista orientativa de Classic (en Forever puede cambiar). Tienes " .. tengo .. L" de " .. #lista .. "." .. (desconocidos > 0 and (" " .. L"Existencias sin confirmar: " .. desconocidos .. ".") or "") .. "\n" .. L"El contenido de nivel alto aún sin confirmar se añadirá en próximas versiones."
  end
  local lado = Lado()
  for _, b in ipairs((GL.D94 and GL.D94.bandas) or {}) do
    local pasos
    local comun, especifica
    for _, a in ipairs(b.acceso or {}) do
      if a.lado == nil then comun = a.pasos elseif a.lado == lado then especifica = a.pasos end
    end
    pasos = especifica or comun
    local accesoDesconocido = pasos == nil and #(b.acceso or {}) > 0
    local hechas = 0
    for _, p in ipairs(pasos or {}) do if Hecha(p.q) then hechas = hechas + 1 end end
    local abierta = pasos == nil or hechas == #pasos
    table.insert(filas, { titulo = true, hecha = pasos ~= nil and abierta,
      bandaClave = b.clave or b.n, texto = b.n .. C.GRIS .. "  · " .. b.jugadores .. L" jugadores · nivel " .. b.nivel .. C.FIN,
      detalle = (pasos and ((abierta and (C.VERDE .. L"Cadena de acceso completada" .. C.FIN) or (hechas .. "/" .. #pasos .. L" pasos para entrar")) .. " · ") or (accesoDesconocido and (C.AMARILLO .. L"Requisitos por confirmar para tu facción" .. C.FIN .. " · ") or (C.GRIS .. L"Sin cadena de acceso registrada" .. C.FIN .. " · "))) .. NotaAcceso(b),
      destino = b.e and { m = b.e.m, x = b.e.x, y = b.e.y, z = b.e.z, n = L"Entrada de " .. b.n }, boton = L"Entrada",
      -- 9.4.2: con los mapas apagados, el botón enseña el botín de todos sus jefes (lo que antes se veía en el mapa)
      boton2 = not b.anuncioForever977 and ((GL.AbrirMapaBanda and GL.MAPAS_MAZMORRAS) and L"Mapa" or (GL.VerBotin and L"Botín") or nil) or nil,
      accion2 = function()
        if b.anuncioForever977 then return end
        if GL.MAPAS_MAZMORRAS and GL.AbrirMapaBanda then GL.AbrirMapaBanda(b); return end
        if not GL.VerBotin then return end   -- mapa grande con los jefes
        local clave = b.clave or b.n
        local jefes = (GL.JefesVisibles976 and GL.JefesVisibles976(clave)) or (GL.WH and GL.WH.jefes and GL.WH.jefes[clave]) or {}
        local todos = GL.BotinesDeJefes977(jefes)
        GL.VerBotin(b.n .. L" · todo el botín", todos)
      end,
      ayudaTitulo = b.n, ayudaTexto = NotaAcceso(b) })
    for i, p in ipairs(pasos or {}) do
      local hecha, diario = Hecha(p.q), Llevo(p.q)
      local d = DestinoPaso(p, diario)
      table.insert(filas, { hecha = hecha, texto = i .. ". " .. p.n .. C.GRIS .. " (" .. p.nivel .. ")" .. C.FIN,
        detalle = hecha and (C.VERDE .. L"hecha" .. C.FIN) or (diario and (C.AMARILLO .. L"En tu diario: comprueba los objetivos antes de entregarla." .. C.FIN)) or
          (d and (L"recógela en " .. (d.z or "?")) or L"empieza con un objeto o dentro de una mazmorra"),
        destino = (not hecha) and d or nil, ayudaTitulo = p.n, ayudaTexto = d and d.n or nil })
    end
  end
  return filas, L"Bandas de nivel 60: dónde están y qué necesitas para entrar. Llevarme te lleva a la siguiente misión." .. "\n" .. L"El contenido de nivel alto aún sin confirmar se añadirá en próximas versiones."
end

-- Se crea dentro del panel de Mazmorras (Mazmorras.lua la enseña en la pestaña Bandas).
function GL.CrearVistaBandas(padre)
  local v = CreateFrame("Frame", nil, padre)
  v:SetPoint("TOPLEFT", padre, "TOPLEFT", 0, -22)
  v:SetPoint("BOTTOMRIGHT", padre, "BOTTOMRIGHT", 0, 0)
  v.sub = GL.CrearPestanas94(v, { { "bandas", L"Bandas y acceso" }, { "equipo", L"Equipo antes de banda" } }, function(id)
    verEquipo = (id == "equipo"); v.lista.desde = 0; v.Refrescar()
  end, 150)
  local cuerpo = CreateFrame("Frame", nil, v)
  cuerpo:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -26)
  cuerpo:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 0, 0)
  v.lista = GL.CrearLista(cuerpo)
  v.Refrescar = function()
    v.sub.Marcar(verEquipo and "equipo" or "bandas")
    local filas, cab = Filas()
    local desde = v.lista.desde or 0
    if bandaBuscada then
      for i, fila in ipairs(filas) do if fila.bandaClave == bandaBuscada then desde = i - 1; break end end
      bandaBuscada = nil
    end
    v.lista:Poner(filas, C.GRIS .. cab .. C.FIN)
    v.lista.desde = desde; v.lista:Pintar()
  end
  v:Hide()
  return v
end

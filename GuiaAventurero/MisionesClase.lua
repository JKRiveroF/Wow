-- MisionesClase.lua (9.4): pestaña Personaje › Clase. Las misiones de clase importantes como rutas cortas: forma
-- de oso, tótems, demonios y monturas del brujo, Destrero del paladín, Rhok'delar del cazador, actitudes del
-- guerrero, venenos del pícaro... Cada misión con Llevarme (a recogerla o, si ya la llevas, a entregarla).
-- Datos en Datos94.lua (QuestieDB). Arriba, tu especialización y el botón para cambiarla. Creado por JKRiveroF.
local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local BIT_RAZA = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local function Clase() return UnitClass and select(2, UnitClass("player")) end
local function Lado() return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A" end
local function Nivel() return (UnitLevel and UnitLevel("player")) or 1 end
local function Hecha(q) return GL.MisionCompletada and GL.MisionCompletada(q) or false end
local function Llevo(q) return GL.MisionEnDiario and GL.MisionEnDiario(q) or false end

local function DeMiRaza(razas)
  if not razas or razas == 0 then return true end
  local bit = BIT_RAZA[(GL.Raza and GL.Raza()) or ""]
  if not bit then return true end   -- Skyborne y otras razas nuevas: se enseñan todas las de su facción
  return math.floor(razas / bit) % 2 == 1
end

-- Las cadenas que te tocan: tu clase, tu facción y tu raza (las de raza concreta van antes que las generales).
function GL.CadenasDeClase(clase)
  local r, lado = {}, Lado()
  for _, c in ipairs((GL.D94 and GL.D94.clase) or {}) do
    if c.clase == (clase or Clase()) and (not c.lado or c.lado == lado) and DeMiRaza(c.razas) then table.insert(r, c) end
  end
  return r
end

-- El destino siguiente de un paso: entregar si la llevas, recoger si no.
local function DestinoPaso(p)
  local quiero = Llevo(p.q) and "T" or "A"
  for _, w in ipairs(p.wp or {}) do if w.a == quiero then return w end end
  return p.wp and p.wp[1]
end

local function EstadoCadena(c)
  local hechas = 0
  for _, p in ipairs(c.pasos) do if Hecha(p.q) then hechas = hechas + 1 end end
  return hechas, #c.pasos
end

local function Filas()
  local filas = {}
  local cadenas = GL.CadenasDeClase()
  for _, c in ipairs(cadenas) do
    local hechas, total = EstadoCadena(c)
    local siguiente
    for _, p in ipairs(c.pasos) do if not Hecha(p.q) then siguiente = p; break end end
    local nv = Nivel()
    local color = (hechas == total) and C.GRIS or (nv >= c.nivel and C.VERDE or C.GRIS)
    table.insert(filas, {
      titulo = true, hecha = hechas == total,
      texto = c.titulo .. C.GRIS .. L"  · nivel " .. c.nivel .. C.FIN,
      detalle = color .. ((hechas == total) and L"Hecha" or (hechas .. "/" .. total .. L" misiones")) .. C.FIN .. " · " .. (c.nota or ""),
      destino = siguiente and DestinoPaso(siguiente), boton = siguiente and DestinoPaso(siguiente) and L"Siguiente" or nil,
      ayudaTitulo = c.titulo, ayudaTexto = c.nota,
    })
    for i, p in ipairs(c.pasos) do
      local d = DestinoPaso(p)
      local estado = Hecha(p.q) and (C.VERDE .. L"hecha" .. C.FIN) or (Llevo(p.q) and (C.AMARILLO .. L"en tu diario: entrégala" .. C.FIN)) or
        (d and (L"recógela en " .. (d.z or "?")) or L"empieza con un objeto o dentro de una mazmorra")
      table.insert(filas, {
        hecha = Hecha(p.q), texto = i .. ". " .. p.n .. C.GRIS .. " (" .. p.nivel .. ")" .. C.FIN,
        detalle = estado .. ((d and d.n) and (" · " .. (d.n:match("%((.-)%)$") or "")) or ""),
        destino = (not Hecha(p.q)) and d or nil,
        ayudaTitulo = p.n, ayudaTexto = d and d.n or nil,
      })
    end
  end
  return filas, #cadenas
end

local panel, lista, boton
local function Refrescar()
  if not panel or not panel:IsShown() then return end
  local filas, n = Filas()
  local esp = GuiaAventureroDB and GuiaAventureroDB.especializacion
  boton.texto:SetText(L"Especialización" .. (esp and (": " .. L(esp)) or ""))
  lista:Poner(filas, nil,   -- 9.4.2: sin la frase de explicación (Llevarme ya tiene su ayuda)
    n == 0 and L"Tu clase no tiene misiones de clase importantes en la guía." or nil)
end

local function CrearPanel()
  local frame = GL.frame
  if panel or not frame then return end
  panel = CreateFrame("Frame", nil, frame)
  panel:SetPoint("TOPLEFT", frame, "TOPLEFT", GL.IZQ, -(GL.ARRIBA + (GL.ALTO_SUB or 0)))
  panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -GL.MARGEN, GL.ABAJO)
  panel:Hide()
  boton = GL.CrearBoton(panel, L"Especialización", function() if GL.AbrirEspecializacion then GL.AbrirEspecializacion() end end, nil, 20)
  boton:SetWidth(200)
  boton:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  GL.Ayuda(boton, L"Especialización", L"La rama de talentos que sigue la guía. Púlsalo para cambiarla.")
  local cuerpo = CreateFrame("Frame", nil, panel)
  cuerpo:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -26)
  cuerpo:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  lista = GL.CrearLista(cuerpo)
  local espera = 0
  panel:SetScript("OnUpdate", function(_, dt)
    if not panel:IsShown() then return end
    espera = espera + dt
    if espera >= 2 then espera = 0; Refrescar() end
  end)
  GL.modos.clase = { panel = panel, refrescar = Refrescar }
end

GL.perezosos = GL.perezosos or {}
GL.perezosos.clase = CrearPanel
GL.comandos = GL.comandos or {}
GL.comandos["clase"] = function() if GL.AbrirModo then GL.frame:Show(); GL.AbrirModo("clase") end end

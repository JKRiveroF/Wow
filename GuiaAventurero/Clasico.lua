-- Clasico.lua (9.2): selector de estilo en Ajustes › Aspecto: «Moderno» (el de la 9.0) o «Clásico Blizzard».
-- El clásico imita las ventanas del juego: borde dorado de los cuadros de diálogo, cabecera con el nombre, fondo
-- casi negro, acento dorado y botones de acción rojos con borde dorado. Al volver a Moderno se recupera el tema
-- de color que tenías. Elegir un tema de color también te devuelve al estilo moderno.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores or not GL.TEMAS then return end
local L = GL.L

local function DB() return GuiaAventureroDB or {} end

-- El tema del clásico va con los demás, pero oculto: no sale en la fila de temas de Ajustes.
table.insert(GL.TEMAS, { id = "clasico", nombre = L"Clásico Blizzard", oculto = true,
  acento = { 1, 0.82, 0 }, oscuro = { 0.30, 0.05, 0.05 }, accion = { 0.50, 0.07, 0.07 }, accionBorde = { 0.79, 0.64, 0.15 },
  fondo = { 0.045, 0.035, 0.02 }, borde = { 0.79, 0.64, 0.15 } })

local deco
local function Decorar(mostrar)
  local f = GL.frame
  if not f then return end
  if not deco and mostrar then
    deco = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    deco:SetPoint("TOPLEFT", f, "TOPLEFT", -6, 6)
    deco:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 6, -6)
    deco:SetFrameLevel((f:GetFrameLevel() or 1) + 40)
    if deco.SetBackdrop then
      deco:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 26 })
      deco:SetBackdropBorderColor(1, 1, 1, 1)
    end
    deco:EnableMouse(false)
    deco.cabecera = deco:CreateTexture(nil, "OVERLAY")
    deco.cabecera:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    deco.cabecera:SetSize(250, 62)
    deco.cabecera:SetPoint("TOP", deco, "TOP", 0, 14)
    deco.titulo = deco:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deco.titulo:SetPoint("TOP", deco.cabecera, "TOP", 0, -14)
    deco.titulo:SetText(L"Guía del Aventurero")
  end
  if deco then GL.Mostrar(deco, mostrar) end
end

local function Aplicar(estilo, alIniciar)
  local db = DB()
  if estilo == "clasico" then
    if db.tema ~= "clasico" then db.temaModerno = db.tema end
    db.estiloVentana = "clasico"
    if GL.CambiarTema and (db.tema ~= "clasico" or alIniciar) then GL.CambiarTema("clasico") end
    Decorar(true)
  else
    db.estiloVentana = "moderno"
    if db.tema == "clasico" and GL.CambiarTema then GL.CambiarTema(db.temaModerno or "morado") end
    Decorar(false)
  end
end
GL.AplicarEstiloVentana = Aplicar

-- Elegir un tema de color en Ajustes te devuelve al estilo moderno
local cambiar = GL.CambiarTema
if cambiar then
  GL.CambiarTema = function(id)
    cambiar(id)
    if id ~= "clasico" and DB().estiloVentana == "clasico" then DB().estiloVentana = "moderno"; Decorar(false) end
  end
end

table.insert(GL.alIniciar, function()
  local db = DB()
  if db.estiloVentana == "clasico" then Aplicar("clasico", true)
  elseif db.tema == "clasico" then Aplicar("moderno") end   -- por si quedó el tema sin el estilo
end)

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "estiloVentana", "Estilo de la ventana",
  "Moderno: el de siempre. Clásico Blizzard: borde dorado, cabecera y botones rojos, como las ventanas del juego.",
  function() return DB().estiloVentana == "clasico" and "clasico" or "moderno" end,
  function(v) Aplicar(v) end,
  pestana = "aspecto", opciones = { { "moderno", "Moderno" }, { "clasico", "Clásico Blizzard" } } })

GL._clasico = { Aplicar = Aplicar, Deco = function() return deco end }

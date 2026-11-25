-- Objetivo.lua (9.2): aviso grande al completar un objetivo de misión. En el centro, unos 3 segundos: un círculo
-- verde con ✓, «¡Objetivo listo!» y el objetivo (10/10 Troggs Piedrapiel), con sonido. Si con eso el paso ya no tiene
-- objetivos por hacer, dice dónde entregar. Ajustes › Avisos › Aviso al completar un objetivo: Grande, Pequeño (el de
-- la 8.9.1, una franja) o No.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local function DB() return GuiaAventureroDB or {} end
local function Ahora() return (GetTime and GetTime()) or 0 end
local function Modo()
  local db = DB()
  if db.avisoObjetivo == false then return "no" end
  return db.avisoObjetivoTam or "grande"
end

local av
local revisionAviso = 0
local function Crear()
  av = CreateFrame("Frame", "GuiaAventureroAvisoObjetivo", UIParent)
  av:SetFrameStrata("HIGH")
  av:SetSize(420, 150)
  av:SetPoint("TOP", UIParent, "TOP", 0, -150)
  av:EnableMouse(false)
  av.circulo = av:CreateTexture(nil, "ARTWORK")
  av.circulo:SetSize(56, 56)
  av.circulo:SetPoint("TOP", av, "TOP", 0, 0)
  av.circulo:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  av.halo = av:CreateTexture(nil, "BACKGROUND")
  av.halo:SetSize(110, 110)
  av.halo:SetPoint("CENTER", av.circulo, "CENTER", 0, 0)
  av.halo:SetTexture("Interface\\Cooldown\\star4")
  av.halo:SetVertexColor(0.3, 1, 0.45, 0.8)
  if av.halo.SetBlendMode then av.halo:SetBlendMode("ADD") end
  av.titulo = av:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  av.titulo:SetPoint("TOP", av.circulo, "BOTTOM", 0, -6)
  av.titulo:SetTextColor(0.53, 0.94, 0.67)
  av.titulo:SetShadowOffset(1, -1)
  av.sub = av:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  av.sub:SetPoint("TOP", av.titulo, "BOTTOM", 0, -2)
  av.sub:SetShadowOffset(1, -1)
  av.pie = CreateFrame("Frame", nil, av, BackdropTemplateMixin and "BackdropTemplate" or nil)
  av.pie:SetPoint("TOP", av.sub, "BOTTOM", 0, -8)
  av.pie:SetHeight(26)
  av.pie.texto = av.pie:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  av.pie.texto:SetPoint("CENTER", av.pie, "CENTER", 0, 0)
  if GL.Caja then GL.Caja(av.pie, { 0.08, 0.09, 0.12, 0.92 }, { 0.13, 0.77, 0.37, 0.55 }) end
  av:Hide()
end

-- Si el paso ya no tiene objetivos por hacer: dónde entregar
local function DondeEntregar()
  if not GL.PasoActual then return nil end
  local _, p = GL.PasoActual()
  if not p or not p.wp then return nil end
  local quedan, entrega = false, nil
  for _, d in ipairs(p.wp) do
    if d.a == "C" and GL.DestinoHecho(d) ~= true then quedan = true end
    if d.a == "T" and not entrega then entrega = d end
  end
  if quedan then return nil end
  if entrega then return entrega.n or entrega.z or L"el siguiente destino" end
  local R, db = GL.RUTA, DB()
  local sig = GL.PasoDespues and R and select(2, pcall(function()
    local s2, p2 = GL.PasoDespues(db.seccion, db.paso)
    return s2 and R.secciones[s2].pasos[p2]
  end))
  if type(sig) == "table" then
    for _, d in ipairs(sig.wp or {}) do if d.a == "T" then return d.n or d.z end end
  end
  return nil
end

local function Sonar()
  if DB().sonidoObjetivo == false or not PlaySound or not SOUNDKIT then return end
  local s = SOUNDKIT.IG_QUEST_LIST_COMPLETE or SOUNDKIT.READY_CHECK
  if s then pcall(PlaySound, s, "Master") end
end

local function Mostrar(nombre, x, y)
  if not av then Crear() end
  av.titulo:SetText(L"¡Objetivo listo!")
  av.sub:SetText(x .. "/" .. y .. " " .. nombre)
  av.pie:Hide()
  av.t0 = Ahora()
  av:SetAlpha(0)
  av:Show()
  Sonar()
  -- La consulta diferida pertenece a este aviso y a este paso, no al que se abra después.
  revisionAviso = revisionAviso + 1
  local revision = revisionAviso
  local ruta = GL.RUTA
  local seccion, paso
  if GL.PasoActual then seccion, paso = GL.PasoActual() end
  local function Mirar()
    if revision ~= revisionAviso or Modo() ~= "grande" or not av:IsShown() then return end
    if not ruta or not paso or GL.RUTA ~= ruta or not GL.PasoActual then return end
    local s, p = GL.PasoActual()
    if s ~= seccion or p ~= paso then return end
    local ok, donde = pcall(DondeEntregar)
    if ok and donde then
      -- La flecha puede estar en otro destino (o pertenecer a Questie).
      av.pie.texto:SetText(L"Misión lista: entrégala en " .. C.AZUL .. tostring(donde) .. C.FIN)
      av.pie:SetWidth((av.pie.texto:GetStringWidth() or 300) + 28)
      av.pie:Show()
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.4, Mirar) else Mirar() end
  av:SetScript("OnUpdate", function(self)
    local t = Ahora() - self.t0
    local esc = t < 0.25 and (0.6 + t / 0.25 * 0.4) or 1
    self.circulo:SetSize(56 * esc, 56 * esc)
    self.halo:SetAlpha(math.max(0, 0.8 - t * 0.4))
    if t < 0.2 then self:SetAlpha(t / 0.2)
    elseif t < 3 then self:SetAlpha(1)
    elseif t < 3.7 then self:SetAlpha(1 - (t - 3) / 0.7)
    else self:SetScript("OnUpdate", nil); self:Hide() end
  end)
end
GL.AvisoObjetivoGrande = Mostrar

local ev = CreateFrame("Frame")
GL.Evento(ev, "UI_INFO_MESSAGE")
ev:SetScript("OnEvent", function(_, _, a1, a2)
  if Modo() ~= "grande" then return end
  local texto = type(a2) == "string" and a2 or (type(a1) == "string" and a1) or nil
  if not texto then return end
  local nombre, x, y = string.match(texto, "^(.-):%s*(%d+)%s*/%s*(%d+)")
  if nombre and tonumber(x) and tonumber(x) == tonumber(y) then
    local ok, err = pcall(Mostrar, nombre, x, y)
    if not ok and GL.Fallo then GL.Fallo(L"aviso de objetivo", err) end
  end
end)

GL.ajustesInterfaz = GL.ajustesInterfaz or {}
table.insert(GL.ajustesInterfaz, { "avisoObjetivoTam", "Aviso al completar un objetivo",
  "Grande: en el centro con ✓, sonido y dónde entregar. Pequeño: una franja, como antes. No: sin aviso.",
  function() return Modo() end,
  function(v) local db = DB(); db.avisoObjetivo = (v ~= "no"); db.avisoObjetivoTam = v end,
  pestana = "avisos", opciones = { { "grande", "Grande" }, { "pequeno", "Pequeño" }, { "no", "No" } } })

GL._objetivo = { Mostrar = Mostrar, DondeEntregar = DondeEntregar, Modo = Modo }

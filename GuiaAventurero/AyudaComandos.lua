-- AyudaComandos.lua (9.1): /ga ayuda por temas. Sin tema, los temas y los cinco comandos más usados;
-- /ga ayuda <tema> lista los de ese tema con lo que hacen.
-- Creado por JKRiveroF.

local _, GL = ...
if type(GL) ~= "table" or not GL.colores then return end
local L = GL.L
local C = GL.colores

local TEMAS = {
  { id = "ruta", n = L"Ruta", c = {
    { "", L"muestra u oculta la ventana" },
    { "nivel", L"va a la sección de tu nivel" },
    { L"sig / ant", L"paso siguiente o anterior" },
    { L"vista [n]", L"mira una sección sin mover tu progreso" },
    { "preparar", L"lista «Antes de salir» de la zona" },
    { "ignorados", L"vuelven a contar los objetivos ignorados" },
    { "llegada", L"horas que te faltan para el 60 a tu ritmo" },
    { "centro", L"herramientas de la guía con su comando" },
    { L"resumen [n]", L"resumen de la última sección acabada (o de la n)" },
    { L"rutas / ruta <id>", L"lista las rutas o elige otra (con /reload)" },
    { "idioma es / en / auto", L"idioma de la guía: español, inglés o el del juego (con /reload)" },
  } },
  { id = "personaje", n = L"Personaje", c = {
    { "rangos", L"cambia en tus barras los rangos viejos por el más alto que conoces" },
  } },
  { id = "profesiones", n = L"Profesiones", c = {
    { L"recoleccion [parar]", L"ruta de recolección de Minería, Herboristería o Desuello" },
  } },
  { id = "ventana", n = L"Ventana", c = {
    { "tutorial", L"vuelve a ver el tutorial" },
    { "reset", L"vuelve a colocar las ventanas" },
  } },
  { id = "datos", n = L"Datos", c = {
    { L"restaurar [si | cuenta | copia]", L"copia de seguridad de lo guardado antes de una versión nueva" },
    { "memoria", L"cuánto ocupa el addon y qué datos ha cargado" },
  } },
  { id = "diagnostico", n = L"Diagnóstico", c = {
    { "informe", L"todo lo que hace falta para avisar de un fallo, para copiar" },
    { L"atascado [nota | ver | borrar]", L"apunta el paso que no avanza" },
    { L"depurar [errores]", L"diagnóstico completo; errores también en el chat" },
  } },
}
GL.TEMAS_AYUDA = TEMAS

-- 9.7.6: comandos quitados porque ya tienen su botón o su casilla, o hacían lo mismo que otro.
-- Las funciones siguen (los botones las usan); /ga <nombre> solo dice dónde está ahora.
GL.COMANDOS_QUITADOS = {
  ["personaje"] = "el botón Personaje",
  ["talentos"] = "Personaje › Talentos",
  ["hechizos"] = "Personaje › Hechizos",
  ["clase"] = "Personaje › Clase",
  ["oficios"] = "el botón Profesiones",
  ["profesiones"] = "el botón Profesiones",
  ["exploracion"] = "el botón Exploración",
  ["exploración"] = "el botón Exploración",
  ["oro"] = "el botón Oro",
  ["opciones"] = "el botón Ajustes o el clic derecho en el botón del minimapa",
  ["automatismos"] = "Ajustes › Automatismos",
  ["novedades"] = "Ajustes › Novedades",
  ["cambios"] = "Ajustes › Novedades",
  ["version"] = "Ajustes › Novedades",
  ["versión"] = "Ajustes › Novedades",
  ["compacto"] = "los botones de tamaño de la ventana",
  ["franja"] = "los botones de tamaño de la ventana",
  ["tamano"] = "los botones de tamaño de la ventana",
  ["minimapa"] = "su casilla en Ajustes",
  ["marca"] = "su casilla en Ajustes",
  ["misiones"] = "su casilla en Ajustes",
  ["flecha"] = "su casilla en Ajustes",
  ["auto"] = "su casilla en Ajustes",
  ["autohechizos"] = "su casilla en Ajustes",
  ["autorecetas"] = "su casilla en Ajustes",
  ["autotalentos"] = "su casilla en Ajustes",
  ["instructor"] = "su casilla en Ajustes",
  ["editor"] = "Ajustes › Datos",
  ["ponertalentos"] = "el botón Poner talentos",
  ["especializacion"] = "el botón Especialización",
  ["especialización"] = "el botón Especialización",
  ["vuelos"] = "Exploración › Por descubrir",
  ["compartir"] = "el botón Compartir en el chat",
  ["farmeo"] = "el botón Me falta XP",
  ["compraprofesion"] = "el botón Lista de compra de la profesión",
  ["costeprofesion"] = "el botón Lista de compra de la profesión",
  ["materiales"] = "el botón Lista de compra de la profesión",
  ["planprofesion"] = "el botón del plan en la tarjeta de la profesión",
  ["revisarprofesiones"] = "el botón del plan en la tarjeta de la profesión",
  ["buscar"] = "el botón Buscar",
  ["viajes"] = "/ga viajelocal",
  ["preparacion"] = "/ga preparar",
  ["compatibilidad"] = "/ga questie",
  ["marcaspropias"] = "/ga questie on|off",
  ["auditoriaruta"] = true,
}

local function Quitar(t) return (string.lower(t):gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u")) end

GL.comandos = GL.comandos or {}
GL.comandos["ayuda"] = function(tema)
  local M = GL.Mensaje
  if not M then return end
  tema = Quitar(tema or "")
  for _, t in ipairs(TEMAS) do
    if tema ~= "" and (t.id == tema or Quitar(t.n) == tema) then
      M(C.AMARILLO .. t.n .. C.FIN .. ":")
      for _, c in ipairs(t.c) do M("  /ga " .. C.BLANCO .. c[1] .. C.FIN .. (c[1] ~= "" and " · " or "") .. c[2]) end
      return
    end
  end
  -- 9.4.2: sin tema, solo los comandos que necesita un jugador normal; el resto, con «ayuda todo»
  if tema == "todo" or tema == "all" then
    local nombres = {}
    for _, t in ipairs(TEMAS) do table.insert(nombres, C.BLANCO .. t.id .. C.FIN) end
    M(L"ayuda por temas: /ga ayuda " .. table.concat(nombres, ", ") .. ".")
    return
  end
  M(L"Comandos útiles:")
  for _, c in ipairs({ { "", L"muestra u oculta la ventana" }, { "nivel", L"va a la sección de tu nivel" },
      { "rutas", L"lista las rutas" }, { "idioma es / en / auto", L"idioma de la guía" },
      { "informe", L"todo lo que hace falta para avisar de un fallo, para copiar" } }) do
    M("  /ga " .. C.BLANCO .. c[1] .. C.FIN .. (c[1] ~= "" and " · " or "") .. c[2])
  end
  M(C.GRIS .. L"Todos los comandos: /ga ayuda todo" .. C.FIN)
end

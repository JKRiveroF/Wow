-- Traducciones de la auditoría 9.7.5
local _, GL = ...
if type(GL) ~= "table" or type(GL.AnadirIngles) ~= "function" then return end
GL.AnadirIngles({
 ["Planes generales de la biblioteca:"] = "General profession plans in the library:",
 [" tramos, huecos numéricos: "] = " ranges, numeric gaps: ",
 ["Questie está cargado. Si ves marcas dobles, usa /ga marcaspropias ocultar para ocultar solo las marcas de esta guía (puedes recuperarlas con /ga marcaspropias mostrar)."] = "Questie is loaded. If you see duplicate pins, use /ga marcaspropias ocultar to hide only this guide's pins (restore them with /ga marcaspropias mostrar).",
 ["CPU acumulada del addon desde el inicio (ms): "] = "Accumulated addon CPU time since startup (ms): ",
 ["CPU: sin datos. Activa el perfilado de addons en el cliente y recarga si quieres medirla; este comando no activa el perfilado."] = "CPU: unavailable. Enable addon profiling in the game client and reload to measure it; this command does not enable profiling.",
 ["AUDITORÍA DE VIAJES (solo lectura)"] = "TRAVEL AUDIT (read only)",
 ["AUDITORÍA DE PROFESIONES (solo lectura)"] = "PROFESSION AUDIT (read only)",
 ["No hay una ruta activa."] = "No active route.",
 ["Pasos con destino: "] = "Steps with destinations: ",
 ["Cambios de mapa entre pasos: "] = "Map changes between steps: ",
 ["Regresos a mapas visitados: "] = "Returns to previously visited maps: ",
 ["Estos saltos no equivalen a viajes evitables: pueden ser entregas, cadenas, vuelos o misiones de otra zona. No se han reordenado pasos."] = "These hops are not necessarily avoidable trips: they may be turn-ins, quest chains, flights or out-of-zone quests. No steps were reordered.",
 ["Esta ruta no incluye planes de profesiones."] = "This route has no profession plans.",
 ["tramos 1-300 cubiertos"] = "1-300 skill ranges covered",
 ["huecos "] = "gaps ",
 [" entradas sin materiales exactos o receta"] = " entries missing exact materials or recipe",
 ["La continuidad de rangos NO verifica disponibilidad de recetas, probabilidades de subir, costes, vendedores ni desbloqueos de Forever."] = "Continuous skill ranges do NOT verify recipe availability, skill-up chances, costs, vendors or Forever unlocks.",
 ["No está disponible la configuración del personaje."] = "Character settings are not available.",
 ["Marcas de Guía del Aventurero: /ga marcaspropias ocultar | mostrar. No cambia los ajustes de Questie."] = "Adventurer's Guide pins: /ga marcaspropias ocultar | mostrar. Does not change Questie settings.",
 ["Marcas propias del mapa activadas."] = "Our map pins enabled.",
 ["Marcas propias del mapa ocultas; Questie no se ha modificado."] = "Our map pins hidden; Questie has not been modified.",
})

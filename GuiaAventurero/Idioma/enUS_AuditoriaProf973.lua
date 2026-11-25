-- English translations for 9.7.3 audit and gathering additions.
local _, GL = ...
if type(GL) ~= "table" or type(GL.AnadirIngles) ~= "function" then return end
GL.AnadirIngles({
  ["Misión adicional: comprueba en el PNJ el nivel mínimo y la cadena anterior; el nivel mostrado por la ruta es orientativo."] = "Extra quest: check the minimum acceptance level and prerequisite chain with the quest giver; the route level is only a guide.",
  ["Memoria estimada del addon (KB): "] = "Estimated addon memory (KB): ",
  ["Recolección disponible: "] = "Available gathering: ",
  [". Para seguir el circuito usa /ga recoleccion."] = ". To follow the route use /ga recoleccion.",
  ["No se han comprobado aquí las alternativas de recetas ni su coste: consulta la siguiente receta del plan si esta deja de dar habilidad."] = "Alternative recipes and costs have not been verified here; check the next recipe in the plan if this one stops granting skill.",
})

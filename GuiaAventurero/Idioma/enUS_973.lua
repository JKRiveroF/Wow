-- New route audit texts for 9.7.3 (English localization).
local _, GL = ...
if type(GL) ~= "table" or not GL.AnadirIngles then return end
GL.AnadirIngles({
  ["Aún no hay una ruta activa cargada."] = "No active route is loaded yet.",
  ["AUDITORÍA DE RUTA (9.7.3)"] = "ROUTE AUDIT (9.7.3)",
  ["nivel actual "] = "current level ",
  ["Secciones: "] = "Sections: ",
  [" · pasos: "] = " · steps: ",
  [" · misiones extra: "] = " · extra quests: ",
  ["Recogidas: "] = "Pickups: ",
  [" · entregas: "] = " · turn-ins: ",
  ["Entregas sin recogida en esta ruta: "] = "Turn-ins without a pickup in this route: ",
  ["Recogidas sin entrega en esta ruta: "] = "Pickups without a turn-in in this route: ",
  ["Misiones entregadas varias veces: "] = "Quests turned in more than once: ",
  [" misiones extra de nivel superior al máximo de la sección (se pueden coger si tu nivel llega)"] = " extra quests above the section's maximum level (you can take them once your level allows)",
  ["Llegar al 60 es un cálculo con la experiencia de cada misión de Questie Forever y los enemigos de sus objetivos; falta comprobarlo en el juego."] = "Reaching 60 is an estimate from each quest's experience in Questie Forever and the enemies of its objectives; it still needs checking in game.",
  ["La comprobación es informativa: no modifica tu ruta ni tu progreso."] = "This check is informational and does not change your route or progress.",
})

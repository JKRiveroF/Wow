-- Idioma/enUS_9797.lua (9.7.9.7): textos en inglés de las misiones plegadas de la pestaña Guía.
local _, GL = ...
if type(GL) ~= "table" or type(GL.AnadirIngles) ~= "function" then return end
GL.AnadirIngles({
  ["Llévame"] = "Take me",
  ["ENTREGADA"] = "TURNED IN",
  [" · lista para entregar"] = " · ready to turn in",
  [" misiones en este paso"] = " quests in this step",
  [" entregadas"] = " turned in",
  ["pulsa una para verla entera"] = "click one to see it in full",
  ["La flecha te lleva a esta misión para hacerla antes que las demás."] = "The arrow takes you to this quest so you can do it before the others.",
  ["Clic: ver la misión entera (Coger, Hacer, Entregar). Mayús+clic: enlazar la misión en el chat."] = "Click: see the whole quest (Accept, Do, Turn in). Shift+click: link the quest in chat.",
})

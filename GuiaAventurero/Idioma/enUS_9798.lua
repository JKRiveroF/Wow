-- Idioma/enUS_9798.lua (9.7.9.8): textos en inglés del tutorial que marca en amarillo cada botón y de los iconos de la compacta.
local _, GL = ...
if type(GL) ~= "table" or type(GL.AnadirIngles) ~= "function" then return end
GL.AnadirIngles({
  ["La pestaña |cffffd100Guía|r (marcada en amarillo) te dice qué misión toca ahora, dónde recogerla y dónde entregarla. Pulsa una misión de la tarjeta para ver sus pasos, y «Llévame» para que la flecha te lleve."] = "The |cffffd100Guide|r tab (highlighted in yellow) tells you which quest is next, where to pick it up and where to turn it in. Click a quest on the card to see its steps, and “Take me” to have the arrow lead you there.",
  ["Moverte por la ruta"] = "Moving along the route",
  ["Debajo de la barra de la ruta: |cffffd100Atrás|r y |cffffd100Siguiente|r cambian de paso a mano, |cffffd100Mi nivel|r te lleva al paso que te toca ahora y |cffffd100?|r te dice por qué un paso no avanza."] = "Under the route bar: |cffffd100Back|r and |cffffd100Next|r change step by hand, |cffffd100My level|r takes you to the step you should be on now and |cffffd100?|r tells you why a step does not move on.",
  ["paso anterior"] = "previous step",
  ["tu paso"] = "your step",
  ["salta el paso"] = "skip the step",
  ["¿qué falta?"] = "what's left?",
  ["La |cffffd100flecha|r de la pantalla te lleva a cada sitio y te dice a cuántos metros está. El botón marcado arriba a la derecha de la ventana la enseña o la esconde."] = "The on-screen |cffffd100arrow|r leads you to each place and tells you how many yards away it is. The highlighted button at the top right of the window shows or hides it.",
  ["Flecha sí / no"] = "Arrow on / off",
  ["La barra de la izquierda"] = "The left bar",
  ["Cada icono de la barra abre una parte de la guía: te los marcamos todos con su nombre. Pasa el ratón por encima de cualquiera y te dice qué hace."] = "Each icon on the bar opens a part of the guide: they are all highlighted with their name. Hover over any of them and it tells you what it does.",
  ["|cffa48cffAutomático:|r la guía pasa sola los pasos que ya has hecho, la flecha salta al siguiente destino al llegar y tus talentos se ponen solos al subir de nivel.\n|cffa48cffLo hago yo:|r al acabar un paso pulsas «Siguiente», eliges en la tarjeta adónde va la flecha y pones los talentos tú, siguiendo Personaje › Talentos.\n|cffb4b4b8Con los dos, la guía te dice qué misión toca, dónde y cuánto te falta. Lo cambias cuando quieras en Ajustes › Automatismos.|r"] = "|cffa48cffAutomatic:|r the guide skips the steps you have already done, the arrow jumps to the next destination when you arrive and your talents are placed when you level up.\n|cffa48cffI'll do it:|r when a step is done you click “Next”, choose on the card where the arrow goes and place your talents yourself, following Character › Talents.\n|cffb4b4b8With both, the guide tells you which quest is next, where and what is left. Change it any time in Settings › Automation.|r",
  ["Lo puedes cambiar luego con el botón marcado, abajo en la barra de la izquierda, o con doble clic en el retrato."] = "You can change it later with the highlighted button at the bottom of the left bar, or by double-clicking the portrait.",
  ["Tú pulsas «Siguiente», eliges adónde va la flecha y pones los talentos."] = "You press “Next”, choose where the arrow goes and spend your talents.",
  ["Abre la ventana grande en esta pestaña. Con «Volver a compacta» regresas tal como estabas."] = "Opens the big window on this tab. “Back to compact” returns you to where you were.",
  ["‹ Volver a compacta"] = "‹ Back to compact",
  ["Volver a compacta"] = "Back to compact",
  ["Vuelve a la ventana compacta, con el paso y la flecha como estaban."] = "Goes back to the compact window, with the step and the arrow as they were.",
})

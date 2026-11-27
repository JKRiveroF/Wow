# Correcciones de facción en la 9.8.0

El ZIP validado por Claude coincide byte a byte en los 221 archivos instalables con `version-9.8.0` en `6eeee28`. Se guardó una copia íntegra del ZIP recibido antes de editar. Su SHA-256 es `f5becbc50485dc89304344b2714e04d7aaf98230772c414b75bffcffd7b8da1c`.

El cruce recorrió las 47 rutas, las tablas opcionales por continente, el catálogo base y las misiones de mazmorra que pueden aparecer como opcionales. Se contrastaron por ID los requisitos de facción, los PNJ de aceptación y entrega y los mapas de los destinos. Una coordenada en territorio enemigo por sí sola se trató como indicio. [Base de misiones de QuestieDB 1.1.6](https://github.com/Questie/QuestieDB/blob/v1.1.6/data/Forever/foreverQuestDB.lua) · [PNJ](https://github.com/Questie/QuestieDB/blob/v1.1.6/data/Forever/foreverNpcDB.lua) · [Objetos](https://github.com/Questie/QuestieDB/blob/v1.1.6/data/Forever/foreverObjectDB.lua) · [Datos generados de Forever](https://github.com/Questie/QuestieDB/blob/v1.1.6/src/corrections/Forever/generated/foreverBaseQuest.lua).

## Cambios

| Casos | Corrección aplicada |
| --- | --- |
| 8796, 8797 y variantes de Alterac 7142, 7162, 7168–7171 | Se retiraron de la facción equivocada. Las rutas ya incluyen sus variantes válidas, como 8794 en Horda y 7141 en Alianza. Los 74 pasos incompatibles conservan su número y muestran un aviso bilingüe. Con el avance automático activo, el motor los da por hechos. |
| 687 y 737 | Las 22 rutas de Horda usan a Zaruk en Sentencia para 687 y a Bel'dugur en Entrañas para 737. La entrega en Theldurin y las variantes de Alianza se conservan. |
| 4736, 4968 y misiones de entrenamiento compartidas | Las rutas de brujo de Horda pasan a 4739 y 4969 con Revientalmas Kaal. Las misiones 8151, 8233, 8250, 8417 y 9063 conservan sus IDs y sus entregas. Los puntos de aceptación de Alianza pasan al instructor de su facción. |
| 8867 y regalos de invierno | Fuegos artificiales lunares tiene destinos de Alianza en Ventormenta y de Horda en Entrañas. Se añadió la entrada opcional de Alianza. Los regalos 8744, 8767–8769 y 8803 usan sus objetos de Forjaz u Orgrimmar según corresponda. El Conservante de acebo 8799 y los iniciadores 8828 y 8861 apuntan a contactos accesibles para Horda. |
| Catálogos de Kalimdor y Reinos del Este | Se pasaron a Horda 90854, 92844, 92847, 92893, 92894, 93035, 93037, 93062, 93066, 93125, 93196 y 95769, conservando los datos de sus fichas. 6606 queda en Horda según la consulta del servidor. 5401–5404 quedan en Alianza, con 5405–5408 disponibles para Horda. La Horda usa 9386 en Orgrimmar y el Explorador Argenta para 9154. |
| 1513 | Se retiró el marcador de objetivo que mandaba a Ventormenta. Gan'rul sigue como contacto de recogida y entrega en Orgrimmar. El círculo de invocación de la Falla de las Sombras queda pendiente de coordenadas confirmadas. |
| Tesoro de los Shen'dralar | El catálogo de La Masacre ofrece 7462 a Alianza y 7877 a Horda. |

Se corrigieron 207 pasos manteniendo su orden, los números de sección y paso y el orden de los destinos válidos. Los ancestros neutrales 8646, 8718 y 8866 siguen disponibles durante el evento en sus ciudades originales. El diff instalable afecta a los datos de 47 rutas, dos catálogos de continente, el catálogo de mazmorras y el diccionario EN. [Reglas de facción por misión](https://github.com/Questie/QuestieDB/blob/v1.1.6/src/corrections/Forever/foreverQuestFixes.lua) · [Entregas observadas por EG Link](https://github.com/JIVESCORP/eg-link-output-wowf/blob/1339ce5600bbc2b12e8f1081e584f548f62fa57f/data/wowf/1.60.1.71139/turn_ins.json) · [Festival Lunar, Blizzard](https://worldofwarcraft.blizzard.com/en-us/news/23901948/).

## Comprobaciones en Forever

- Durante los eventos, comprobar la oferta y entrega de 8867 en las dos capitales, los regalos de invierno, los operadores de 8828 y 8861, los ancestros neutrales y las variantes del esfuerzo de guerra. Confirmar el acceso a las variantes de Alterac con un personaje de cada facción.
- En Horda, comprobar la oferta de 687 tras 688 y la de 737 tras 736. Con brujo, comprobar qué instructor ofrece 4739 y 4969 y registrar mapa y posición del círculo de 1513. Registrar los IDs ofrecidos a las clases de Alianza en los cinco contactos reubicados.
- Verificar cómo distingue Forever las variantes 5237 y 5238 de «¡Misión cumplida!». La referencia heredada intercambia sus facciones frente a las fichas de los comandantes, por lo que se conservó la asignación actual. Los IDs 26/27, el bálsamo de Frondavil y el folleto 8228 tienen evidencias de Forever que prevalecen frente a las discrepancias de la tabla heredada.
- Reanudar un guardado en un paso corregido. Comprobar que conserva sección y paso y que el avance automático omite la variante cuando corresponda. Probar la variante de La Masacre con el requisito previo 7461 completado.

## Verificación local y paquete

- **4 de 4 pruebas de facción** superadas. Las pruebas cargan las 47 rutas y 56 perfiles, recorren los catálogos y comprueban los pasos, las traducciones y las excepciones neutrales. [Pruebas](pruebas/test_faccion_980.py).
- **149 de 149 pruebas de regresión existentes** superadas sobre una copia del addon corregido. En esa copia se ajustaron las dos comparaciones históricas de integridad para admitir exclusivamente las modificaciones documentadas y seguir contrastando el resto con la base. Se comprobó también la carga Lua de las 47 rutas.
- `GuiaAventurero-9.8.0-corregida.zip` contiene los 221 archivos instalables. SHA-256 `bd8c03f687b2d27121d38b25bea61b1067a669fd943fe705a0273cbb2018f5f2`.

# Plan de la fase 13 · Auditoría de leveo

## Preparación

- [x] Verificar el commit de restauración `592d887`, la versión 9.7.9, el estado de Git y los 219 SHA-256 del addon y el ZIP. Comprobar la concordancia entre la rama local y `origin`.
- [x] Confirmar Git y Python. Preparar Lua 5.1 mediante Lupa en el entorno Python del auditor. El equipo carece de un ejecutable `lua` independiente en el PATH.
- [x] Identificar las 47 rutas en el TOC. Mantener `AGENTS.md`, `PROGRESO_FASE13.md` y el auditor fuera del addon.

## Criterios de medición

Cada fila enumera criterios que se completan cuando se cumple toda su cobertura. En los bloques 1–6 se mide cada criterio aplicable por ruta. Un criterio específico de una ruta queda pendiente si le falta evidencia obligatoria. Las pruebas transversales de sintaxis de módulos y regresión se miden para el addon completo. El porcentaje del bloque es `comprobaciones completas ÷ comprobaciones aplicables × 100`. El porcentaje global suma el porcentaje de cada bloque multiplicado por su peso. Los porcentajes se redondean solo al mostrarlos.

| Bloque | Peso | Criterios de finalización |
| --- | ---: | --- |
| 1. Estructura | 10 % | Compilar los Lua del TOC. Cargar el registro y comprobar campos, secuencias, cobertura declarada 1–60 y duplicados de paso. Probar selección, carga y filtros raciales del motor con las 56 combinaciones. |
| 2. Misiones | 25 % | Comprobar IDs y acciones locales, con secuencias A/C/T y duplicados por raza. Verificar identidad y nombres ES/EN con evidencia. Validar orden, dependencias y requisitos con evidencia. Confirmar condiciones especiales, exclusiones y desbloqueos. |
| 3. Cartografía | 20 % | Comprobar formato de IDs, coordenadas y referencias locales. Verificar mapas y posiciones de objetivos y PNJ. Confirmar cambios de zona, interiores y puntos de vuelo en Forever. |
| 4. Experiencia | 15 % | Comprobar cobertura, saltos y requisitos locales. Estimar XP de misiones y combates con datos trazables. Validar saldo y bloqueos por tramo en el modelo de Forever. |
| 5. Viaje | 15 % | Identificar distancias relativas y visitas repetidas con contexto local. Verificar alternativas, disponibilidad y desbloqueos de transporte. Medir ahorros y confirmar secuencias mejoradas en condiciones comparables. |
| 6. Clase, raza y facción | 10 % | Comprobar cabeceras, ramas, filtros y particularidades locales. Verificar zonas iniciales, clases y restricciones con evidencia de Forever. Confirmar acceso real, desbloqueos y traducciones específicas. |
| 7. Regresión y preparación | 5 % | Ejecutar regresión local y pruebas con API simulada. Completar y documentar las pruebas obligatorias en Forever. Preparar novedades ES/EN, documentación y ZIP definitivo. Verificar la sincronización del cierre en GitHub. |

Una ruta completamente verificada requiere todos sus criterios aplicables, incluidas las pruebas obligatorias del cliente. Una ruta revisada localmente ya pasó por los conjuntos de reglas disponibles en todos los bloques de ruta, con sus hallazgos y dependencias de datos registrados. Una ruta en revisión ya tiene alguna auditoría ejecutada. Las pruebas preparadas para el cliente se registran como pendientes hasta observar sus resultados.

## Secuencia de trabajo

- [x] Ejecutar y cerrar la auditoría estructural inicial con los archivos originales protegidos por el manifiesto.
- [x] Ejecutar las comprobaciones locales de misiones, cartografía, experiencia, viajes y particularidades en las 47 rutas. Registrar los hallazgos y el alcance de la evidencia.
- [x] Aplicar las correcciones respaldadas y repetir la auditoría y la regresión local. Preparar el borrador de novedades ES/EN y el protocolo de pruebas en Forever.
- [x] Generar fichas por ID para las misiones originales y las incorporadas, cruzar trazas y reglas estáticas, y separar inferencias, documentación y pruebas del cliente.
- [x] Contrastar los comienzos de las 47 rutas y los 56 perfiles. Deducir ventanas compartidas de los 22 avisos de agrupamiento y contrastar sus dependencias disponibles.
- [ ] Completar la evidencia por misión y perfil, especialmente las cadenas, restricciones, objetos, desbloqueos y títulos ES/EN. Validar posiciones, ganancias de XP y alternativas de viaje donde falten observaciones.
- [x] Resolver las exclusiones `324/526` y `94484/94493` y los requisitos `98221 → 465` y `93680 → 545`.
- [x] Cruzar el registro de misiones y las observaciones de Efficient Games por ID y compilación con los títulos, requisitos, objetivos, XP y vuelos de las rutas.
- [x] Cruzar los historiales de entregas con las continuaciones sugeridas que coinciden con la base heredada. Aplicar la evidencia a las secuencias A/T de las rutas.
- [x] Contrastar los requisitos heredados de una sola entrega con las trazas de oferta de mayor confianza.
- [x] Resolver y probar los avisos de orden y acceso de 473, 1840 y 1948. Mantener los índices de los pasos y documentar los desvíos opcionales.
- [x] Contrastar las categorías de misión y los temporizadores expresos con la extracción de Forever.
- [x] Mostrar las categorías verificadas mediante las etiquetas de destino. Probar con Lua el caso sin datos de la misión, la respuesta posterior y los textos ES/EN.
- [x] Corregir los textos de 30 refuerzos sin XP base y conservar el historial de respuestas del servidor por ID.
- [x] Corregir las variantes de Frondavil y los pasos de invasión que llevaban a ciudades de la otra facción.
- [x] Contrastar los objetos, el temporizador y el riesgo de las tres ventanas de agrupamiento y corregir sus instrucciones.
- [x] Contrastar las relaciones entre los tres pares de objetivos con la base de QuestieDB que hereda Forever y sus datos de servidor. Clasificar las 51 apariciones en las 22 rutas para la prueba de recorrido.
- [ ] Cronometrar ambas secuencias de las tres ventanas en Forever. Anotar trazado transitable, esperas de objetivos y margen antes de que caduque la piedra de 924.
- [x] Actualizar los IDs de las dos entregas de Kum'isha y contrastar los pasos previos en Pantano de las Penas y Desolace.
- [x] Contrastar las fichas con la tabla QuestV2 del cliente y comprobar los casos de oferta sin fila y fila sin oferta observada.
- [x] Contrastar el encargo 96222 de Umarak y las variantes de Gelkis y Magram en Desolace.
- [x] Colocar la cadena opcional de Kum'isha y probar los seis pasos previos en ambos catálogos con Lua.
- [x] Corregir las variantes acuáticas de druida, añadir el encargo previo de Forma felina y completar la cadena de Ivar.
- [x] Ajustar la rama de Klockmort para enano y gnomo, y distinguir las dos variantes documentadas de Forja de armaduras de la Horda.
- [x] Incorporar de forma opcional las dos cadenas de Forma acuática de Skyborne y señalar las visitas de ruta donde recoger las mitades.
- [x] Contrastar la rama actual de Traición en Azshara y aplicar sus tres encargos de Forever en las 22 rutas Horda.
- [x] Revisar los 25 IDs activos sin evidencia de oferta, acreditar el canje 5227 y corregir los pasos y destinos de los encargos opcionales.
- [ ] Resolver los campos investigables de los 24 IDs restantes, con prioridad para los ocho sin fila en QuestV2. Verificar la oferta estacional y de banda con observaciones de la fase correspondiente.
- [x] Resolver las discrepancias de títulos españoles detectadas y verificar sus claves inglesas.
- [x] Cotejar las etiquetas de los 195 IDs sin título español observado con la localización heredada. Guardar el resultado por ID y señalar 85712 y 93686 para contraste directo.
- [x] Corregir 26 encargos de canje, reputación, eventos y JcJ que aparecían como refuerzos de XP.
- [x] Contrastar y corregir los 32 refuerzos restantes con XP base cero. Distinguir pasos de cadena, de transporte, de clase y de Alterac.
- [ ] Revisar los requisitos de perfil y buscar evidencia para los títulos que siguen sin fuente.
- [ ] Probar dentro de Forever los aspectos que dependen del cliente, incluidos Questie, datos guardados, traducciones y selección de ruta.
- [ ] Actualizar las novedades ES/EN y preparar el ZIP definitivo con los archivos distribuibles, tras superar los criterios de cierre local.
- [ ] Verificar la sincronización del cierre únicamente en la rama de desarrollo con `origin`. La fusión y las Releases quedan pendientes de autorización expresa.

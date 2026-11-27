# Plan de la fase 13 · Auditoría de leveo

## Preparación

- [x] Verificar el commit de restauración `592d887`, la versión 9.7.9, el estado de Git y los 219 SHA-256 del addon y el ZIP. Comprobar la concordancia entre la rama local y `origin`.
- [x] Confirmar Git y Python. Preparar Lua 5.1 mediante Lupa en el entorno Python del auditor. El equipo carece de un ejecutable `lua` independiente en el PATH.
- [x] Identificar las 47 rutas en el TOC. Mantener `AGENTS.md`, `PROGRESO_FASE13.md` y el auditor fuera del addon.

## Criterios de medición

El **progreso certificado** conserva los criterios siguientes. En los bloques 1–6, cada criterio se cuenta por ruta salvo la compilación Lua global. El bloque 7 contiene cuatro criterios transversales. El certificado del bloque es `criterios completos ÷ criterios aplicables × 100`. Cada criterio se cierra cuando cumple todos sus requisitos y existe evidencia obligatoria. Los pesos globales se conservan.

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

### Progreso efectivo

Para cada criterio, el auditor calcula `C = unidades certificadas ÷ unidades aplicables`. Para cada familia de comprobaciones con unidades aplicables calcula `F = comprobaciones superadas ÷ comprobaciones aplicables`. El efectivo del criterio es `(C + suma de F) ÷ (1 + número de familias)`. La revisión integral y cada familia tienen el mismo peso dentro del criterio. El 100 % exige completar la revisión integral y todas las comprobaciones de sus familias. Un criterio sin familias tiene efectivo igual a su certificado.

Cada bloque pondera el efectivo de sus criterios por la misma cantidad de unidades que usa el certificado. Los dos globales ponderan los siete bloques con los pesos de la tabla. El cálculo usa fracciones exactas. Se muestran hasta dos decimales y se reserva **100 %** para el valor exacto. La variación compara cortes medidos en puntos porcentuales. `—` indica que aún falta un corte comparable. Se conserva el último corte distinto cuando se repite la misma ejecución.

| Bloque | Familias de cobertura efectiva |
| --- | --- |
| Estructura | Compilación, contrato y motor ejecutado con API simulada. |
| Misiones | Identidad, títulos por idioma, nivel mínimo, requisitos acumulativos y alternativos, seguimientos, exclusiones, repetición, objetos y condiciones especiales. Cada combinación de ID activo y campo se mide una vez para las 47 rutas. |
| Cartografía | UiMapID, destinos por misión y acción, destinos de PNJ y orientación, y pruebas por ruta de transiciones, interiores y puntos de vuelo. |
| Experiencia | Umbrales de nivel, XP base por ID, estimación de combate por tramo, entregas con XP observada, saldo y bloqueos en Forever. |
| Viajes | Nodos por facción, alternativas y desbloqueos por ruta, ventanas geométricas únicas y su medición de tiempos en Forever. |
| Clase, raza y facción | Evidencia de clase, raza y facción por misión, aprendizajes por par único de misión y hechizo, verificación de la matriz y arranques, y pruebas por ruta de acceso, desbloqueos y traducciones. |
| Regresión y preparación | Pruebas locales ejecutadas y superadas, casos del protocolo de cliente, borradores ES/EN y protocolo, validación del paquete y sincronización del cierre. |

La evidencia **confirmada** supera todas las etapas de la unidad. Los títulos ES/EN, las coordenadas, el acceso por clase, raza y facción y el aprendizaje tienen dos comprobaciones por unidad, una de contraste y otra de confirmación. Superan el contraste un cotejo heredado de título, una posición cercana, una entrega observada con el perfil documentado o un indicio de recompensa. En clase se exige una máscara heredada de una única clase que coincida con la categoría de Forever y el título de la misma misión. Las entregas observadas acreditan únicamente la raza y facción que constan en la muestra. La confirmación exige evidencia del alcance de la condición o del aprendizaje. Una inferencia o una comprobación pendiente queda registrada sin superar ninguna etapa. Las correcciones se reflejan en la concordancia acreditada y las pruebas superadas. Los datos compartidos se contabilizan una vez por campo y unidad, aunque aparezcan en varias rutas. Los pendientes agrupados del auditor y las unidades específicas del protocolo se presentan por separado.

El corte que incorpora perfiles de entrega y aprendizaje conserva la comparación con el último corte publicado. Su variación efectiva incluye la ampliación de la medición. El certificado mantiene sus unidades y sus criterios.

### Progreso funcional

Ambos indicadores miden `comprobaciones funcionales superadas ÷ comprobaciones aplicables × 100` por bloque. Cada comprobación cuenta una vez. Los totales ponderados usan los siete pesos originales y fracciones exactas. El primer corte funcional local se publica sin variación histórica.

- **Funcional local** · Para marcadores y flecha, continuidad, desplazamiento, desbloqueos y textos, instalación y ZIP se exigen las pruebas específicas que lista el auditor. Para el ZIP también se verifica el archivo generado. Los demás criterios usan la medida común. Este indicador debe llegar al 100 % antes de integrar.
- **Funcional global** · Conserva los criterios funcionales anteriores. Las pruebas de Forever cuentan con evidencia real ligada a la huella del addon que se haya ejecutado. La sesión se hará después de integrar la fase 13 con las mejoras de Claude y ChatGPT para validar la futura 9.8.0 estable.

| Bloque | Comprobaciones funcionales |
| --- | --- |
| Estructura | Lua 5.1 y TOC, integridad frente a la base, carga y niveles 1–60 de las 47 rutas y selección de las 56 combinaciones. |
| Misiones | IDs, oferta y dependencias del recorrido principal, orden e instrucciones revisadas ES/EN, y omisión segura de misiones opcionales. |
| Cartografía | Mapas y coordenadas válidos, contradicciones corregidas y prueba representativa en Forever de marcadores y flecha. |
| Experiencia | Tramos y requisitos de nivel, misiones sin XP y opciones separadas, continuidad observada en Forever. Se mantiene el cálculo existente. |
| Viajes | Cambios de zona y transportes conocidos, nodos y facción, y desplazamiento representativo en Forever. |
| Clase, raza y facción | Selección y filtros, zonas y misiones iniciales, y muestra real de perfiles, textos ES/EN y desbloqueos esenciales. |
| Regresión y preparación | Regresión completa, Questie y guardados en local, instalación y casos representativos en Forever, documentación y cero P0/P1, ZIP verificado y rama sincronizada. |

El cierre funcional requiere el 100 %, cero P0/P1 y todos los criterios de regresión y entrega. Se pueden aplazar P2 y P3 con su evidencia, alcance y método de verificación. La clasificación funcional conserva los pendientes y coberturas de los dos indicadores de datos. [Registro de investigación](auditor_fase13/PENDIENTES_INVESTIGACION_FOREVER.md) · [Protocolo funcional](auditor_fase13/VALIDACION_FOREVER.md#protocolo-reducido-de-cierre-funcional).

### Lectura automática del avance

<!-- medicion-fase13:inicio -->

**Progreso certificado global · 40,83 %**

`████████░░░░░░░░░░░░`

**Progreso efectivo global · 57,21 %**

`███████████░░░░░░░░░`

**Progreso funcional local · 100 %**

`████████████████████`

**Progreso funcional global · 75 %**

`███████████████░░░░░`

| Bloque | Peso | Criterios completos | Certificado anterior | Certificado actual | Variación | Efectivo anterior | Efectivo actual | Variación | Funcional local anterior | Funcional local actual | Variación local | Funcional global anterior | Funcional global actual | Variación global | Estado global |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Estructura | 10 % | 95/95 | 100 % | 100 % | 0 pp | 100 % | 100 % | 0 pp | — | 100 % | — | 100 % | 100 % | 0 pp | Completo |
| Misiones | 25 % | 47/188 | 25 % | 25 % | 0 pp | 52,33 % | 52,33 % | 0 pp | — | 100 % | — | 100 % | 100 % | 0 pp | Completo |
| Cartografía | 20 % | 47/141 | 33,33 % | 33,33 % | 0 pp | 46,45 % | 46,45 % | 0 pp | — | 100 % | — | 50 % | 50 % | 0 pp | Pendiente |
| Experiencia | 15 % | 47/141 | 33,33 % | 33,33 % | 0 pp | 53,58 % | 53,58 % | 0 pp | — | 100 % | — | 66,67 % | 66,67 % | 0 pp | Pendiente |
| Viajes | 15 % | 47/141 | 33,33 % | 33,33 % | 0 pp | 50 % | 50 % | 0 pp | — | 100 % | — | 66,67 % | 66,67 % | 0 pp | Pendiente |
| Clase, raza y facción | 10 % | 94/141 | 66,67 % | 66,67 % | 0 pp | 74,21 % | 74,21 % | 0 pp | — | 100 % | — | 66,67 % | 66,67 % | 0 pp | Pendiente |
| Regresión y preparación | 5 % | 1/4 | 25 % | 25 % | 0 pp | 37,5 % | 37,5 % | 0 pp | — | 100 % | — | 66,67 % | 66,67 % | 0 pp | Pendiente |
| **Global ponderado** | 100 % |  | 40,83 % | 40,83 % | 0 pp | 57,21 % | 57,21 % | 0 pp | — | 100 % | — | 75 % | 75 % | 0 pp | Pendiente |

**Última actualización de la medición · 2026-11-27 10:43:51+01:00 (Madrid)**

El auditor registra **235 grupos de investigación** y **116 grupos de validación en Forever**. Las coberturas por criterio están en `progreso_medicion.json`.

**Incidencias por impacto** · P0 0 · P1 0 · P2 313 · P3 94

- **Rutas analizadas localmente** · 47/47
- **Rutas con P0/P1** · 0
- **Pruebas locales superadas** · 145/145
- **Pruebas reales de Forever** · 0/6 superadas, 6 pendientes, 0 con fallo
- **Incidencias aplazables** · 407

<!-- medicion-fase13:fin -->

El auditor conserva las coberturas y los cortes en [`progreso_medicion.json`](auditor_fase13/progreso_medicion.json). La ejecución oficial con `--actualizar-progreso` regenera esta tabla y la de `PROGRESO_FASE13.md` después de la regresión. Las ejecuciones parciales no reemplazan el corte compartido. [Comando y registro de validaciones](auditor_fase13/README.md#actualizar-la-medición-de-la-fase).

## Secuencia de trabajo

La certificación de datos conserva sus pendientes. Las incidencias P2 y P3 quedan registradas para revisiones posteriores. La secuencia de cierre es preparación local, integración autorizada y validación real del corte combinado. [Preparación e inventario de integración](auditor_fase13/INTEGRACION_FASE13.md).

- [x] Ejecutar y cerrar la auditoría estructural inicial con los archivos originales protegidos por el manifiesto.
- [x] Ejecutar las comprobaciones locales de misiones, cartografía, experiencia, viajes y particularidades en las 47 rutas. Registrar los hallazgos y el alcance de la evidencia.
- [x] Aplicar las correcciones respaldadas y repetir la auditoría y la regresión local. Preparar el borrador de novedades ES/EN y el protocolo de pruebas en Forever.
- [x] Generar fichas por ID para las misiones originales y las incorporadas, cruzar trazas y reglas estáticas, y separar inferencias, documentación y pruebas del cliente.
- [x] Contrastar los comienzos de las 47 rutas y los 56 perfiles. Deducir ventanas compartidas de los 22 avisos de agrupamiento y contrastar sus dependencias disponibles.
- [ ] Completar la evidencia por misión y perfil, especialmente las cadenas, restricciones, objetos, desbloqueos y títulos ES/EN. Validar posiciones, ganancias de XP y alternativas de viaje donde falten observaciones.
- [x] Contrastar la XP observada de entrega por raza, facción e intervalo. Excluir de la medición las muestras al nivel máximo o con la XP desactivada.
- [x] Resolver las exclusiones `324/526` y `94484/94493` y los requisitos `98221 → 465` y `93680 → 545`.
- [x] Cruzar el registro de misiones y las observaciones de Efficient Games por ID y compilación con los títulos, requisitos, objetivos, XP y vuelos de las rutas.
- [x] Identificar los 29 nodos por nombre y facción con TaxiNodes, corregir la asociación de Molino Tarren y verificar los tres nombres que muestra el cliente esES.
- [ ] Comprobar el acceso a los nodos con los perfiles de ruta. Registrar las conexiones con escalas y las alternativas de transporte en condiciones comparables.
- [x] Incorporar las observaciones faltantes de objetivos, destinos y entregas de la revisión fijada de Efficient Games. Conservar las muestras por acción y compilación.
- [x] Incorporar la compilación 71139, contrastar los 24 IDs pendientes y completar la ficha de equipo de pícaro 8941.
- [x] Cruzar los historiales de entregas con las continuaciones sugeridas que coinciden con la base heredada. Aplicar la evidencia a las secuencias A/T de las rutas.
- [x] Contrastar los requisitos heredados de una sola entrega con las trazas de oferta de mayor confianza.
- [x] Contrastar los requisitos múltiples de 737 y 1119. Validar la entrega alternativa por facción y la acumulación de dos entregas en 33 pares de misión y ruta.
- [x] Contrastar los 118 pares de misión y habilidad de las rutas con los efectos de la recompensa. Corregir los orígenes y los textos de las siete rutas de cazador.
- [x] Incorporar al efectivo las entregas contrastadas por raza y facción y los pares de aprendizaje. Separar en el protocolo las confirmaciones de aprendizaje que requieren Forever.
- [x] Contrastar las máscaras de clase heredadas con las categorías y los títulos de las consultas de Forever. Conservar en el inventario las coincidencias y las inferencias por separado.
- [ ] Confirmar las restricciones de clase que tienen contraste parcial mediante una ficha con requisito explícito o una oferta observada en los perfiles pertinentes. Priorizar los cambios de categoría y los casos con máscaras de varias clases.
- [x] Cruzar por tipo e ID los objetivos del servidor con observaciones de criaturas y objetos de Forever. Reproyectar tres destinos a partir de sus coordenadas de mundo y conservarlos como contraste parcial.
- [x] Contrastar por acción las posiciones de recogida y entrega con las trazas de entidades, las observaciones de Forever y el catálogo estático de QuestieDB. Conservar la procedencia del vínculo y de cada posición.
- [x] Aplicar las correcciones de botín de QuestieDB, contrastar los 39 candidatos del cruce por objeto y entidad e incorporar el destino adicional de 92553.
- [x] Contrastar los 11 candidatos preliminares de botín de Efficient Games y ampliar la comprobación a nueve instantáneas. Conservar por separado el vínculo al origen y la posición observada de la entidad.
- [x] Contrastar los candidatos heredados con el botín vinculado a la misión activa y las respuestas `questItems` del servidor. Se acreditó cercanía en 134 de los 151 destinos, incluidos los siete compartidos por las 47 rutas.
- [x] Incorporar el botín de interacciones con entidad y hechizo identificados. Se acreditó cercanía en 8 destinos y el contraste acumulado cubre 136 de los 151 candidatos heredados.
- [x] Cruzar las observaciones de GoldScout y Forever Scout con las posiciones archivadas. El contraste acumulado acredita cercanía en 144 de los 151 candidatos heredados.
- [x] Precisar las instrucciones ES/EN de Peletería y de los brotes de Un’Goro usando cantidades y orígenes identificados. Los marcadores aproximados permanecen en la investigación. [Objetivos y fuentes](auditor_fase13/FUENTES.md#instrucciones-de-materiales-en-feralas-y-ungoro).
- [ ] Resolver los siete destinos heredados que quedan, agrupados por los objetos 8153 en Feralas y 11315 en Un'Goro. Contrastar una observación de botín próxima al marcador o comprobar la obtención en Forever. Validar también el punto exacto donde las fuentes acreditan cercanía. [Protocolo](auditor_fase13/VALIDACION_FOREVER.md#botín-en-feralas-y-ungoro).
- [ ] Verificar el punto exacto y el acceso a los destinos con contraste parcial. Para los puntos aún sin observación cercana, priorizar posiciones documentadas de iniciadores, receptores y objetivos compartidos.
- [ ] Verificar en Forever los ocho pares de aprendizaje pendientes o parciales, con prioridad para el desbloqueo de 18960 y los efectos de recompensa de mago, paladín y chamán.
- [x] Cruzar objetos auxiliares y exclusiones heredadas con registros de Forever y añadir las marcas expresas de repetición documentadas en el corte.
- [x] Sustituir los textos genéricos por instrucciones ES/EN en las 17 misiones con objetos auxiliares contrastados que todavía los tenían.
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
- [x] Contrastar los 24 IDs pendientes en las seis instantáneas iniciales y documentar los requisitos de prueba y las rutas afectadas por ID.
- [x] Inventariar las interacciones de oferta y entrega por PNJ u objeto. Contrastar con ellas el inicio de Ongeku y de la cadena de Ag'tor.
- [x] Detallar los objetivos y requisitos contrastados de 1371, 1373 y 8318 en ES/EN. Unificar la referencia a Mensajes secretos en los pasos de 8319.
- [x] Contrastar los umbrales heredados de 5201 y 9266 y distinguir 6848 de 6847 y 8319 de 8324. Registrar las pruebas que distinguen las ofertas.
- [x] Cruzar las doce instantáneas adicionales de lanzamiento con las fichas de las rutas. Acreditar el acceso de ambas facciones mediante entregas con una ficha de acceso estable y conservar las observaciones de XP y posición.
- [x] Contrastar las cadenas de Forever que se relacionan con 1374 y 1375. Distinguir sus condiciones de las heredadas y registrar el salto 93044 → 93045 para validación con un mismo personaje.
- [x] Auditar el estado de oferta según las misiones activas y entregadas. Verificar los cinco bloqueos temporales y la oferta de Disturbios elementales en las diez rutas Skyborne.
- [x] Contrastar los requisitos de profesión y objetivos de 1578, 1618 y 91751. Corregir las instrucciones ES/EN y separar las dos entregas de Herrería de la XP principal.
- [x] Contrastar visitas reales a Hydraxis, Arantir y Belgrom. Sus cinco IDs pasan a comprobación en el cliente con condiciones y muestras documentadas. [Informes](auditor_fase13/FUENTES.md#ofertas-de-hydraxis-arantir-y-belgrom).
- [ ] Buscar evidencia de iniciador, variante y requisitos para las seis ofertas restantes por investigación, con prioridad para 5201, 6848, 8319 y 9266, que carecen de fila en QuestV2.
- [x] Completar la cadena opcional de 1085 en las 14 rutas afectadas. Incorporar la aceptación y entrega de 1070 en ES/EN y conservar las posiciones de 1085. [Condiciones de entrega](auditor_fase13/FUENTES.md#dos-condiciones-de-entrega).
- [ ] Validar en Forever el avance de la guía al hacer u omitir la cadena opcional de la Sierra Espolón. [Protocolo](auditor_fase13/VALIDACION_FOREVER.md#cadena-de-la-sierra-espolón).
- [ ] Verificar las cinco ofertas estacionales y los ocho casos vinculados a botín de banda cuando haya cliente y se cumplan las condiciones de contenido. Confirmar las cantidades heredadas de los siete canjes de Ahn'Qiraj.
- [x] Resolver las discrepancias de títulos españoles detectadas y verificar sus claves inglesas.
- [x] Cotejar las etiquetas de los 195 IDs sin título español observado con la localización heredada. Guardar el resultado por ID y señalar 85712 y 93686 para contraste directo.
- [x] Corregir 26 encargos de canje, reputación, eventos y JcJ que aparecían como refuerzos de XP.
- [x] Contrastar y corregir los 32 refuerzos restantes con XP base cero. Distinguir pasos de cadena, de transporte, de clase y de Alterac.
- [x] Incorporar las trazas esES de 2972, 4222 y 6609 y contrastarlas con las etiquetas de las rutas.
- [ ] Revisar los requisitos de perfil y buscar evidencia para los títulos que siguen sin fuente.
- [x] Completar la preparación funcional local de los siete bloques, verificar el ZIP de integración e inventariar los cambios frente a 9.7.9. [Paquete e inventario](auditor_fase13/INTEGRACION_FASE13.md).
- [x] Integrar la fase 13 con la 9.7.9.9, revisar los archivos coincidentes y actualizar las novedades ES/EN en la candidata 9.8.0. [Inventario de integración](auditor_fase13/INTEGRACION_FASE13.md).
- [x] Ejecutar la regresión local de la candidata 9.8.0 y verificar su ZIP de 221 archivos.
- [ ] Ejecutar en Forever los seis casos del protocolo reducido sobre la candidata 9.8.0 y anotar la huella del corte probado.
- [ ] Verificar el paquete de la versión combinada tras la validación real. La fusión y las Releases requieren autorización expresa.

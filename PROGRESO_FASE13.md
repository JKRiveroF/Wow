# Progreso de la fase 13

**Avance global · 40,83 %**

`████████░░░░░░░░░░░░`

**Última actualización · 2026-11-26 13:01:17 +01:00 (Madrid)**

**Tarea actual** · Revisar las condiciones de los 24 IDs sin oferta acreditada y las instrucciones sobre los objetos auxiliares confirmados.

## Preparación completada · 25 de noviembre de 2026

- Confirmada la versión 9.7.9 de la fase 12 en `GuiaAventurero.toc`, en la versión que expone `Novedades.lua` y en la documentación de la distribución.
- Inicializado Git en la raíz. El commit `592d887a021ec136696e460895630982737fec95` contiene los 218 archivos originales de `GuiaAventurero/` y el ZIP original. La rama local activa es `fase-13-auditoria-leveo`. La configuración local `core.autocrlf=false` conserva los finales de línea originales.
- Verificados los 219 SHA-256 tanto en el commit inicial como en los archivos del disco. El ZIP superó la comprobación de CRC y sus 218 archivos coinciden byte a byte con la carpeta extraída. El manifiesto es `auditor_fase13/SHA256_ORIGINALES.sha256` y sus rutas parten de la raíz del repositorio.
- Verificado que las 144 entradas Lua del TOC existen, tienen la capitalización exacta y aparecen una sola vez. Las referencias a los 61 mapas y a los 8 iconos coinciden con los recursos incluidos. La textura `flecha.tga` también está presente.
- Inventariadas las 47 rutas en `auditor_fase13/INVENTARIO_RUTAS.md`. Cada una tiene un ID único y un cargador. Sus secciones declaran cobertura de los niveles 1 a 60. Se identificaron 25 rutas de Alianza, 22 de Horda y 56 combinaciones únicas de facción, raza y clase, porque nueve rutas cubren dos razas.
- Preparada `auditor_fase13/` para el desarrollo posterior. Contiene el inventario y los hashes. Se añadieron las instrucciones permanentes en `AGENTS.md` y las tareas pendientes en `PLAN_FASE13.md`.
- Verificados Git 2.44.0.windows.1 y Python 3.13.0 con `python`. No se detectó Lua ni `luac` en el `PATH` ni en las ubicaciones habituales comprobadas. El lanzador `py` instalado no detectó Python, aunque el comando `python` funciona.

## Estructura comprobada

| Ubicación | Archivos | Contenido |
| --- | ---: | --- |
| `GuiaAventurero/` (directos) | 88 | 83 Lua, el TOC, la licencia, dos TXT y la textura de flecha TGA |
| `GuiaAventurero/Iconos/` | 8 | Iconos TGA |
| `GuiaAventurero/Idioma/` | 14 | Módulos Lua de traducción |
| `GuiaAventurero/Mapas/` | 61 | Texturas BLP de mapas |
| `GuiaAventurero/Rutas/` | 47 | Rutas de leveo Lua |
| `GuiaAventurero-9.7.9.zip` | 1 | Distribución original comprimida |

## Estado de la auditoría · 25 de noviembre de 2026

La rama local partió del mismo commit que GitHub, `83fab5b`. `git fsck --full` terminó sin errores. Al iniciar, los 219 SHA-256 coincidían con el disco y con los blobs del commit de restauración `592d887`.

El auditor externo compiló los 144 ficheros Lua del TOC con Lupa 2.8 (Lua 5.1) y cargó 47 rutas. Las 56 combinaciones pasaron selección, carga y filtro racial con las funciones originales y API simulada. La comprobación estructural no registró errores, avisos ni pendientes. Los originales seguían intactos al cerrar el bloque.

| Área | Peso | Comprobaciones completas | Anterior | Actual |
| --- | ---: | ---: | ---: | ---: |
| Estructura | 10 % | 95/95 | 100 % | 100 % |
| Misiones | 25 % | 47/188 | 25 % | 25 % |
| Cartografía | 20 % | 47/141 | 33,33 % | 33,33 % |
| Experiencia | 15 % | 47/141 | 33,33 % | 33,33 % |
| Viajes | 15 % | 47/141 | 33,33 % | 33,33 % |
| Clase, raza y facción | 10 % | 94/141 | 40,43 % | 66,67 % |
| Regresión y preparación | 5 % | 1/4 | 25 % | 25 % |
| **Global ponderado** | **100 %** | | **38,21 %** | **40,83 %** |

Las 95 comprobaciones estructurales son una compilación global, 47 verificaciones del contrato de ruta y 47 validaciones del motor por ruta con todas sus combinaciones declaradas.

| Rutas pendientes | En revisión | Revisadas localmente | Verificadas por completo |
| ---: | ---: | ---: | ---: |
| 0 | 0 | 47 | 0 |

- Errores detectados, corregidos y pendientes en la auditoría estructural: 0, 0 y 0.
- Primera comprobación en cliente pendiente: arranque, selección, carga de destinos, compatibilidad con Questie, traducciones y continuidad de datos guardados.

## Misiones y perfiles · avance local

- Revisados los 103.896 destinos de misión de las 47 rutas, con 2.462 IDs distintos. Las secuencias A/C/T, las variantes raciales y los títulos A/T en las tablas ES/EN del addon se comprobaron sin errores locales. Los 240 títulos EN comparables con trazas coincidieron.
- Las 47 rutas conservan comprobaciones externas pendientes de misiones y de perfil. Las trazas separan existencia, título y XP base por cada campo. No cubren todos los nombres ES, dependencias, exclusiones, requisitos, objetivos especiales ni desbloqueos.
- Referencia del cierre estructural publicado, `a7ed567`. Último corte de misiones y perfiles en Git, `Contrasta las misiones y perfiles de las rutas`.

## Cartografía · avance local

- Comprobados formato y existencia documentada de los 47 UiMapID usados. QuestieDB 1.1.6 identifica los mapas canónicos de la build 1.60.1.69893. Las coordenadas reales de objetivos, interiores y desplazamientos todavía requieren evidencia específica.
- Actualizada la misión 3520 en las 47 rutas tras el cambio de Blizzard del 16 de noviembre. Se retiraron 22 destinos de objetivo obsoletos en rutas y dos en la tabla opcional de Kalimdor. La aceptación y entrega se mantienen. La prueba del motor confirmó que el paso sigue pendiente hasta la entrega.
- Completadas 454 etiquetas necesarias para el mapa 1459 y normalizadas 69 etiquetas preexistentes. La zona se presenta como Valle de Alterac en español y Alterac Valley en inglés. Sus IDs y coordenadas permanecen intactos.
- Alineadas las dos ubicaciones del catálogo de vuelos para los PNJ 352 y 931 con sus posiciones de ruta, respaldadas por observaciones de Forever. Evidencia y fecha de consulta en `auditor_fase13/FUENTES.md`.
- La repetición del bloque registró 0 errores y 0 avisos. Conserva un pendiente de posiciones por cada ruta.
- Último corte previo publicado, `c42d537`. Último corte cartográfico en Git, `Corrige destinos y etiquetas de cartografía de leveo`.

## Experiencia · avance local

- Comprobada la cobertura 1–59 con la regla real de selección de tramo. El nivel 60 usa el tramo final. El informe guarda el subtotal de XP de misiones por perfil y su cobertura frente a la curva de cliente 1.60.1.70959.
- Actualizadas 38 instrucciones de la misión 1878, intercambio repetible de Tanaris. Blizzard retiró su XP. El texto bilingüe lo ofrece como actividad opcional y conserva la primera entrega 1707, todos los destinos y los requisitos existentes.
- El bloque volvió a ejecutarse en las 47 rutas con 0 errores y 0 avisos. Las estimaciones de combate, XP efectiva y saldo por tramo quedan pendientes del cliente y de evidencia adicional.
- Último corte de cartografía publicado, `4d2466e`. Último corte de experiencia en Git, `Contrasta la progresión y corrige el refuerzo sin XP de Tanaris`.

## Viajes · avance local

- Analizados los cambios de mapa y agrupamientos locales en 47 rutas. En 22 rutas hay candidatos de agrupamiento geométrico que necesitan contrastar dependencias, acceso y tiempos. Se mantienen pendientes los tiempos reales, la piedra de hogar, barcos y zepelines.
- Corregido el avance de los pasos de vuelo cuando el guardado está en un idioma distinto al cliente. Se conservan las claves guardadas y el estado de los vuelos desconocidos. La simulación cubrió los 28 nombres de las 567 comprobaciones de vuelo.
- El bloque de viajes volvió a ejecutarse con 0 errores y 0 avisos. Se añadió evidencia de nombres para Forjaz, El Cruce y Entrañas.
- Último corte de experiencia publicado, `ad6022b`. Último corte de viajes en Git, `Reconoce puntos de vuelo guardados en ambos idiomas`.

## Clase, raza y facción · avance local

- La matriz oficial de Blizzard contiene las 56 combinaciones seleccionables del addon. Se contrastaron los arranques de diez rutas Skyborne y sus 60 hitos de misión por clase y facción. Las restricciones completas del resto de zonas iniciales y los desbloqueos dentro de Forever siguen pendientes.
- Corregidas cinco descripciones de Skysight y precisadas cinco de Read Leyline. Los diez textos se verificaron en español e inglés. La duración exacta de Skysight queda pendiente por discrepancia entre las fuentes.
- Actualizada la entrega de Camping 101: Herbalism (97968) a Halassa Fernbreeze en Shen'dar. Se conservaron la recogida, los requisitos y el resto de misiones opcionales.
- Último corte de viajes publicado, `d831b04`. Último corte de perfiles en Git, `Verifica perfiles y ajusta las rutas Skyborne`.

## Regresión global · corte local

- La misma auditoría y el mismo catálogo obtuvieron 60 errores y 454 avisos en la base extraída del ZIP. Tras las correcciones, el resultado en la rama fue 0 errores y 0 avisos en los controles ejecutados, con 351 grupos de comprobaciones pendientes. Los grupos resumen datos o pruebas aún abiertos y pueden contener varias observaciones.
- Pasaron 31 pruebas locales. Se cotejaron las rutas con el ZIP de restauración, los 219 hashes originales y los archivos fuera del alcance de los cambios. Las simulaciones ejecutaron las funciones de Questie y de migración de datos guardados del addon.
- Preparados el borrador bilingüe de novedades y el protocolo de validación. Las pruebas efectivas en Forever quedan pendientes. No se detectó un cliente instalado en las ubicaciones consultadas. El ZIP final depende de los criterios de cierre.
- Último corte de perfiles publicado, `a8e5218`. Último corte de regresión en Git, `Verifica regresiones y documenta el siguiente corte de fase 13`.
- Siguiente tarea: ejecutar los escenarios de `auditor_fase13/VALIDACION_FOREVER.md` con la compilación registrada, empezando por arranque, datos guardados y Questie, y después las misiones 3520 y 1878, los vuelos bilingües y los raciales Skyborne. Continuar el contraste por ruta con las nuevas observaciones.

## Últimas mejoras y comprobaciones

- Inventario individual de 2.464 IDs en las 47 rutas. Incluye los 2.462 del corte anterior y dos añadidos verificados. Las fichas reutilizan evidencia por ID y destino y conservan las relaciones inferidas por separado.
- Cobertura de fuentes por ID. Existencia 2.098, título ES 2.262, título EN 250, nivel mínimo 246, clase 84, raza y facción 214, XP base 2.089, objetos objetivo 70. Se documentaron 15 listas acumulativas, 187 listas de alternativas y 154 seguimientos. Una ficha puede tener evidencia de un campo y conservar otros pendientes.
- Contraste de los 56 perfiles de inicio. Las 37 rutas añadidas a esta comprobación cubren 46 perfiles, seis zonas compartidas y 92 hitos de apertura. Se añadió la introducción de sacerdote gnomo 98574 y se conservaron los destinos del enano.
- Corregidos los pasos del odre de chamán enano para aceptar cada misión tras entregar la anterior. Las 25 rutas de Alianza incluyen Bloqueo Roca Negra (98387) antes de los dos encargos que lo requieren.
- Corregidos los objetivos de 5386 y 1430 en las 22 rutas Horda, las instrucciones opcionales de herrería 5283 y 5301 y cuatro títulos de misión. Los cambios de texto y recorrido conservan sus traducciones al inglés.
- La evidencia cartográfica respalda 20 combinaciones únicas de misión, acción y posición reutilizadas en 466 apariciones por ruta. Los 22 avisos de agrupamiento se desglosaron en 51 apariciones de tres ventanas compartidas. [Detalle de los agrupamientos](auditor_fase13/AGRUPAMIENTOS_FASE13.md).

## Incidencias y regresión del corte

| Resultado | Antes con las fuentes ampliadas | Después |
| --- | ---: | ---: |
| Errores automáticos | 0 | 0 |
| Avisos por contraste de datos | 722 | 632 |
| Grupos pendientes de investigación | 304 | 304 |
| Grupos que requieren el cliente | 94 | 94 |

Pasaron 48 pruebas, incluida la compilación Lua, la comprobación de las cadenas corregidas, la regresión de integridad y las simulaciones de datos guardados y Questie. El contraste dejó 90 avisos menos con las mismas fuentes. Los avisos restantes incluyen variantes legítimas por resolver, no constituyen 632 defectos demostrados. El inventario anterior tenía 351 grupos; el nuevo separa 47 grupos de evidencia de vuelos que estaban mezclados con las mediciones del cliente.

## Cadenas y alternativas · corte verificado

- Los Humedales y la Isla Zephras indican qué misiones son excluyentes. Se marcaron las dos opciones en cada uno de los 124 destinos de aceptación y entrega afectados. El motor reconoce la alternativa activa o completada y conserva los índices de las rutas guardadas.
- Se incorporaron los requisitos 98221 de la misión 465 en 25 rutas y 93680 de la misión 545 en 22 rutas. Hay 2.466 IDs inventariados, incluidos los 2.462 originales. El contraste respalda 560 apariciones de destinos en las rutas.
- Se resolvieron 33 avisos de exclusión y 56 de prerrequisitos. El auditor registró 0 errores y 543 avisos por contrastar. Quedan 304 grupos de investigación y 94 de cliente. La cobertura parcial de estos grupos mantiene el avance global en 40,83 %.
- Pasaron las 52 pruebas locales. Incluyen la carga de las 47 rutas, las conexiones de las nuevas cadenas, la selección de misiones alternativas, el cálculo de XP y la regresión de datos guardados. [Fuentes y método](auditor_fase13/FUENTES.md).

## Datos del servidor y observaciones · corte verificado

| Campo | IDs con evidencia | Antes |
| --- | ---: | ---: |
| Existencia | 2.434 | 2.100 |
| Título inglés | 2.434 | 252 |
| Título español | 2.264 | 2.264 |
| Nivel mínimo | 2.434 | 248 |
| XP base | 2.434 | 2.090 |
| Objetos objetivo | 1.520 | 71 |

- Contrastados los 2.466 IDs con consultas del servidor y trazas. Se corrigieron 18 títulos ingleses en las tablas del addon, que explicaban 275 avisos por ruta. La misión 92551 se observó completada por un Skyborne Horda y se corrigió el catálogo para los recorridos de ambas facciones.
- El auditor encontró 14.217 apariciones de destinos cerca de observaciones del mismo mapa y acción, además de las 560 apariciones ya cotejadas con coordenadas documentadas.
- Se vincularon 20 nodos de vuelo por ID del maestro. Hay 111 conexiones registradas entre ellos, con tiempos observados en 25. Tres rutas dejaron de tener el grupo pendiente de evidencia de nodos. Se conservan los pendientes de acceso y tiempos reales.
- Hubo 0 errores en la auditoría y 3.038 avisos. De ellos, 2.275 corresponden a 98 misiones recomendadas como refuerzo cuya XP base calculada es cero. Quedan 487 avisos de títulos ES, 268 de perfil y 8 de prerrequisitos alternativos. Los avisos cuentan apariciones en rutas, por lo que un mismo ID puede aparecer varias veces.
- Pasaron las 55 pruebas locales, incluidas las de máscaras raciales, XP cero, coordenadas por acción y conexiones por facción.
- Quedan 301 grupos de investigación y 94 de cliente. El global sigue en 40,83 % con los criterios completos de la tabla. [Método, compilaciones y fuentes](auditor_fase13/FUENTES.md#consultas-del-servidor-y-observaciones-de-efficient-games--26-de-noviembre-de-2026).

## Refuerzos y disponibilidad · corte verificado

- Corregidas las instrucciones de 30 misiones que figuraban como refuerzos sin aportar XP base. Las 1.136 apariciones revisadas describen su finalidad en ES y EN. Los canjes especifican sus materiales y recompensas, y los pasos intermedios y de transporte indican cómo continuar.
- Documentado el requisito de llevar el alijo de Mau'ari en las bolsas para que caiga e'ko. Se aplica a siete objetivos de Cuna del Invierno.
- Confirmada la existencia de 8941 mediante el escaneo de Forever. Hay evidencia de existencia para 2.435 de los 2.466 IDs. Para 21 de los 31 restantes consta al menos una consulta sin respuesta.
- El auditor registró **0 errores y 1.902 avisos**. Se resolvieron 1.136 avisos y quedan 1.139 de refuerzo para 68 IDs. Los 301 grupos de investigación y los 94 de cliente mantienen el avance en **40,83 %**. [Fuentes de los refuerzos](auditor_fase13/FUENTES.md#refuerzos-sin-xp-base--26-de-noviembre-de-2026).
- Pasaron las 57 pruebas locales. La regresión verificó las traducciones y que los pasos corregidos conservan su orden, destinos e IDs.

## Frondavil e invasión · corte verificado

- Las 47 rutas ya distinguen las primeras entregas de bálsamo de Frondavil de sus canjes repetibles. Se corrigieron 219 primeras entregas y 215 canjes con las variantes de cada facción, sus traducciones y la baliza Cenarion. La XP de estas entregas opcionales se desglosa en el informe.
- Se retiraron dos encargos de invasión de la Horda de las cinco rutas de elfos de la noche. Los diez espacios de paso conservan su índice. Las dos misiones conservan sus fichas en la auditoría original.
- El inventario contiene 2.466 fichas y 2.464 IDs activos. La comparación con el ZIP 9.7.9 confirmó que las fichas incluyen los 2.462 IDs originales y los cuatro añadidos.
- La auditoría pasó de 1.902 a **1.448 avisos** con 0 errores. Se resolvieron 240 avisos de perfil y 214 de XP. Quedan 925 avisos de refuerzo para 58 IDs, 487 avisos de títulos ES, 28 de perfil y 8 de prerrequisitos alternativos. [Fuentes de Frondavil e invasión](auditor_fase13/FUENTES.md#variantes-de-frondavil-e-invasión--26-de-noviembre-de-2026).
- Siguen abiertos 301 grupos de investigación y 94 de cliente. El avance global ponderado sigue en 40,83 %.
- Pasaron las 58 pruebas locales. La regresión ejecutó la carga de las rutas y cotejó el orden de los pasos de Frondavil, los textos ES/EN y los archivos de la distribución original.

## Objetivos y desplazamientos compartidos · corte verificado

- Se repitió el contraste de los 22 avisos de agrupamiento. Abarcan 51 apariciones en tres ventanas. Se documentó una relación adicional en cada ventana y quedaron 21 campos de relación por contrastar. Los recorridos conservan el orden hasta medir el acceso y confirmar las relaciones que faltan. [Resultados de agrupamiento](auditor_fase13/AGRUPAMIENTOS_FASE13.md).
- Se corrigieron los textos ES/EN de la Mano de Iruxos y la Charca de Lágrimas en 22 rutas, y de la Semilla del Demonio en siete. La guía indica el uso del pico, el cristal, la piedra que dura 30 minutos y el riesgo de las patrullas élite.
- El cristal de Iruxos respalda 22 apariciones de su destino. La cobertura total de coordenadas documentadas sube a 582 apariciones, más 14.217 cerca de observaciones.
- La auditoría local de las 47 rutas registró 0 errores, 1.448 avisos y 395 grupos pendientes. Los criterios completos mantienen el avance global en 40,83 %.
- Pasaron las 58 pruebas locales. La regresión conservó los destinos, las traducciones y el orden de las tres ventanas.

## Kum'isha · corte verificado

- Los 94 pasos de Kum'isha de las 47 rutas usan los IDs de Forever 93685 y 93686. Conservan sus índices. Cada entrega pide una esfera de draenetista perfecta. Las rutas identifican el requisito El Encontrado y dejan el viaje como opcional.
- Se contrastaron las seis misiones previas y los PNJ del Pantano de las Penas, Desolace y las Tierras Devastadas. La recogida y entrega de ambos encargos respaldan 188 nuevas apariciones de coordenadas. Total contrastado de forma directa, 770 apariciones.
- El inventario incluye 2.468 fichas, con los 2.462 IDs de 9.7.9, cuatro retirados del recorrido y seis añadidos durante la fase. De los 2.464 IDs activos quedan 29 sin evidencia de oferta del servidor.
- Pasaron las 59 pruebas locales. El auditor registró 0 errores y 1.504 avisos. Los 56 avisos nuevos indican que El Encontrado está documentado pero falta colocar el desvío completo en las rutas. La XP de Kum'isha se muestra aparte.
- Se mantienen 301 grupos de investigación, 94 de cliente y el 40,83 % de avance por criterios completos. [Cadena y fuentes de Kum'isha](auditor_fase13/FUENTES.md#cadena-opcional-de-kumisha--26-de-noviembre-de-2026).

## Registro de misiones del cliente · corte verificado

- Se cruzaron las 2.468 fichas con QuestV2 de Forever 1.60.1.71139. Hay 2.317 filas coincidentes. De los 151 IDs sin fila, 141 tienen evidencia de existencia por otras fuentes del servidor.
- De los 29 IDs activos sin evidencia de oferta, 20 figuran en la tabla del cliente. Los nueve restantes son 5201, 5227, 6848, 8319, 8353, 8355, 8356, 8863 y 9266. El informe conserva ambos resultados para cada ID. [QuestV2 1.60.1.71139](https://wago.tools/db2/QuestV2/csv?build=1.60.1.71139).
- Resultado de la auditoría de las 47 rutas. 0 errores, 1.504 avisos, 301 grupos de investigación y 94 de cliente. El avance global se mantiene en 40,83 % por criterios completos.
- Pasaron las 60 pruebas locales. El control del índice comprobó que una fila del cliente y una oferta del servidor conservan resultados independientes y detectó cambios en el CSV.

## Títulos españoles · corte verificado

- Se ajustaron 28 títulos a las trazas de Forever esES/esMX. Se verificaron 1.052 etiquetas de destino y se añadieron 55 claves inglesas para las nuevas etiquetas e instrucciones. El título de la misión 2584 conserva la ortografía «espíritu» y el auditor reconoce la errata que aparece en la referencia del juego. [Títulos y procedencia por ID](auditor_fase13/titulos_es_revisados.json).
- Se resolvieron los 487 avisos por discrepancia de título ES. Hay evidencia de existencia para 2.437 IDs, títulos ES para 2.265, títulos EN para 2.436 y XP base para 2.436, sobre las 2.468 fichas que incluyen el histórico original.
- La auditoría dejó **0 errores y 1.017 avisos** en las 47 rutas. Quedan 925 avisos de refuerzos, 64 de prerrequisitos alternativos y 28 de perfil. Se mantienen 301 grupos de investigación, 94 de cliente y el 40,83 % global por criterios completos.
- Pasaron las 60 pruebas locales. La regresión cotejó la distribución 9.7.9 y comprobó que los cambios de título conservan las acciones, los IDs y las posiciones.

## Canjes, eventos y campos de batalla · corte verificado

- Se corrigieron las instrucciones ES/EN de 26 encargos sin XP base en 481 pasos. Los textos muestran los materiales, canjes, reputación y recompensas de JcJ. Los regalos y entregas de evento indican cuándo se pueden hacer. [Recompensas y fuentes](auditor_fase13/FUENTES.md#refuerzos-sin-xp-base--26-de-noviembre-de-2026).
- La auditoría de las 47 rutas dejó **0 errores y 536 avisos**. Quedan 444 avisos de refuerzos para 32 IDs, 64 de prerrequisitos alternativos y 28 de perfil.
- Permanecen abiertos 301 grupos de investigación y 94 de cliente. El avance global por criterios completos es 40,83 %.
- Pasaron las 60 pruebas locales. La regresión comprobó los textos de los refuerzos y sus traducciones, y cotejó los destinos, el orden y los IDs con la base original.

## Refuerzos restantes · corte verificado

- Se corrigieron las instrucciones ES/EN de los últimos 32 encargos sin XP base, en 444 pasos de las 47 rutas. Los textos identifican las entregas que activan otro paso, los transportes, las recetas, el material de reputación y las actividades de Alterac. [Fuentes y condiciones](auditor_fase13/FUENTES.md#refuerzos-sin-xp-base--26-de-noviembre-de-2026).
- La auditoría pasó de 536 a **92 avisos y 0 errores**. Quedan 64 avisos de prerrequisitos alternativos y 28 de perfil. Los 301 grupos de investigación y 94 de cliente mantienen el avance en 40,83 % por criterios completos.
- Pasaron las 60 pruebas locales. La regresión comprobó las instrucciones y traducciones de los encargos revisados y la integridad de sus acciones, IDs y coordenadas.

## Desolace · corte verificado

- Se incorporó el encargo opcional 96222 de Umarak a 34 rutas. Se comprobó el nivel mínimo 35, el fragmento de llave 6077 y los tres destinos por ruta. La instrucción indica usar la boquilla en el cuerno y formar un grupo para el khan de élite. Las rutas conservan 1380 y 1381 en el inventario histórico y mantienen la posición de sus pasos guardados. [Evidencia de Desolace](auditor_fase13/FUENTES.md#khan-hratha-y-ramas-de-desolace--26-de-noviembre-de-2026).
- Se condicionaron los encargos 1374 y 1375 a la oferta de Gelkis y Magram en 32 y 34 rutas, respectivamente. Las misiones homónimas 93128 y 93196 tienen otros PNJ, objetivos y requisitos, y quedan identificadas en las fuentes.
- Hay 2.469 fichas y 2.463 IDs activos. Se cotejaron los 2.462 IDs de la base 9.7.9. Hay evidencia de existencia para 2.438 fichas, título español para 2.266, título inglés y XP base para 2.437. De los 27 IDs activos sin evidencia de oferta, 18 tienen fila en QuestV2.
- Pasaron las **61 pruebas locales**, incluida la verificación de la misión 96222, el orden guardado y las instrucciones en ambos idiomas. La auditoría registró **0 errores, 92 avisos**, 301 grupos de investigación y 94 de cliente. El avance se mantiene en 40,83 % por criterios completos.

## Kum'isha · corte verificado

- El catálogo opcional de Alianza y Horda incorpora los seis pasos de Magtoor y Azore hasta El Encontrado, con sus destinos e instrucciones ES/EN. Los pasos se desbloquean al entregar el anterior y respetan los niveles mínimos de 30 y 45. Las misiones de la cadena son legibles al reconectar en otro continente. [Cadena, objetos y coordenadas](auditor_fase13/FUENTES.md#cadena-opcional-de-kumisha--26-de-noviembre-de-2026).
- Pasaron las **62 pruebas locales**. La nueva prueba ejecuta la carga en Lua y comprueba requisitos, destinos, traducciones y el modo Solo ruta en ambas facciones. Se compararon los resultados de cada una de las 47 rutas con la tabla individual.
- La auditoría mantiene **0 errores, 92 avisos**, 301 grupos de investigación y 94 de cliente. De los 64 avisos de prerrequisitos alternativos, 56 identifican que la ruta principal no entrega El Encontrado. El requisito queda accesible por el catálogo opcional. El global por criterios completos sigue en **40,83 %**.
- Queda por observar la oferta efectiva de la cadena en Forever para cada facción y medir el tiempo del desvío. [Comprobación en cliente](auditor_fase13/VALIDACION_FOREVER.md).

## Ivar y formas de druida · corte verificado

- Se corrigieron los IDs 26 y 27 de Forma acuática para el elfo de la noche y el tauren. El elfo y el Skyborne de Alianza recogen el encargo 98393 en Darnassus y lo entregan antes de seguir con Forma felina.
- Las seis rutas de no-muertos añaden 91920 y 91921 antes de Ivar. Los pasos conservan su índice y los tres destinos de Ivar mantienen su posición dentro del paso. Se comprobaron la costa de Lordamere, los tres ojos de múrloc, la poción, los niveles y los títulos ES/EN. [Variantes, dependencias y destinos](auditor_fase13/FUENTES.md#dependencias-de-ivar-y-de-druida--26-de-noviembre-de-2026).
- Pasaron las **65 pruebas locales**. La auditoría de las 47 rutas quedó en **0 errores y 80 avisos**, 12 menos que en el corte anterior. Quedan 56 avisos de la entrega opcional previa a Kum'isha y 24 de perfil. Hay 301 grupos de investigación y 94 de cliente. El global por criterios completos sigue en **40,83 %**.
- El inventario tiene 2.472 fichas y 2.466 IDs activos e incluye los 2.462 IDs originales. Hay evidencia de existencia para 2.441 IDs, título español para 2.269 y título inglés y XP base para 2.440.

## Herrería y rama de Klockmort · corte verificado

- La ruta de enano y gnomo guerrero toma las notas de Furen, las entrega en Forjaz y marca dónde reunir el coral al pasar por Menethil. El encargo final de Klockmort da los guanteletes de mallas. La ruta humana conserva la cadena de Grimand.
- Se eligió 85712 como variante opcional de Forja de armaduras en 17 rutas Horda. Cinco rutas de Guerrero y Paladín conservan 5301. Ambas variantes comparten PNJ, materiales y hechizo de recompensa. Quedan por comprobar la oferta efectiva y el requisito profesional de 85712. [Máscaras, datos y ubicaciones](auditor_fase13/FUENTES.md#herrería-y-rama-de-klockmort--26-de-noviembre-de-2026).
- Pasaron las **67 pruebas locales**. Las 47 rutas registraron **0 errores y 56 avisos**, 24 menos que en el corte anterior. Todos corresponden al requisito opcional de Kum'isha. Quedan 301 grupos de investigación y 94 de cliente. El avance global por criterios completos sigue en **40,83 %**.
- El inventario tiene 2.473 fichas, 2.467 IDs activos y los 2.462 IDs de 9.7.9. Hay evidencia de existencia para 2.442 IDs y título inglés y XP base para 2.441. La prioridad siguiente incluye los 27 IDs activos sin evidencia de oferta.

## Forma acuática de Skyborne · corte verificado

- Las dos rutas Skyborne de druida muestran cómo iniciar Forma acuática desde nivel 16. Cada facción tiene sus cuatro misiones en el catálogo opcional. El requisito del paso anterior se comprueba antes de ofrecer el siguiente. La habilidad figura en ambas listas de hechizos.
- Las notas ES/EN indican dónde recoger las dos mitades del colgante durante el recorrido. Los puntos de Argénteos son aproximados. Queda por probar en Forever la oferta, la duración del adorno y el tiempo de los desvíos. [Máscaras, cadenas y arcones](auditor_fase13/FUENTES.md#forma-acuática-de-skyborne--26-de-noviembre-de-2026).
- Pasaron las **68 pruebas locales**, con una prueba nueva de nivel, clase, raza, facción, orden de las entregas y traducciones. Se repitió la auditoría de las 47 rutas con **0 errores, 56 avisos**, 301 grupos de investigación y 94 de cliente. El avance global por criterios completos sigue en **40,83 %**.

## Traición en Azshara · corte verificado

- Las 22 rutas Horda siguen 3505 → 91497 → 91500 → 91531. Se corrigieron las cantidades de la primera tarea, se añadieron los tres sellos con sus ubicaciones de búsqueda y se detalló el uso de los cristales. El último encargo aprovecha el regreso a Orgrimmar.
- Se conservaron los índices de paso y los IDs 3506 y 3507 en el inventario histórico. La carta 3504 sigue condicionada a la oferta de Belgrom. El auditor reutiliza los destinos contrastados en 242 apariciones de ruta. [Dependencias, objetos y fuentes](auditor_fase13/FUENTES.md#traición-en-azshara--26-de-noviembre-de-2026).
- Pasaron las **69 pruebas locales**. Las 47 rutas registran **0 errores y 56 avisos**, todos por el requisito opcional de Kum'isha. Quedan 301 grupos de investigación y 94 de cliente. El global por criterios completos sigue en **40,83 %**.
- El inventario contiene 2.476 fichas y 2.468 IDs activos. Se cotejó la presencia de los 2.462 IDs de 9.7.9. Hay 2.445 IDs con evidencia de existencia, 2.272 con título español y 2.444 con título inglés y XP base. Los pendientes de oferta bajan de 27 a 25 al sustituir los dos pasos heredados.

## Oferta, canjes y eventos · corte verificado

- Se contrastaron los 25 IDs activos sin observación de oferta y se actualizaron **307 pasos de las 47 rutas** para 22 IDs con instrucciones opcionales en ES/EN. Las seis rutas Horda que señalaban Forjaz para el regalo 8788 apuntan ahora al árbol de Orgrimmar.
- Se acreditó el canje 5227 en la compilación 1.60.1.70938, con nivel mínimo 50, 620 XP base, tres materiales y el caldero como destino de oferta y entrega. La XP del canje se calcula por separado del recorrido principal. Quedan **24 IDs activos** con oferta pendiente de acreditar, de los que 16 tienen fila en QuestV2 y ocho carecen de ella. La oferta de banda, estacional y de Alterac queda condicionada al contenido habilitado. [Fuentes por ID](auditor_fase13/FUENTES.md#oferta-canjes-y-eventos--26-de-noviembre-de-2026).
- Pasaron **2 pruebas específicas** y la **regresión de 70 pruebas**. El auditor comprobó 2.476 fichas, 2.468 IDs activos y los 2.462 IDs de 9.7.9. Hay 2.446 fichas con evidencia de existencia, 2.273 con título español y 2.445 con título inglés y XP base.
- Las 47 rutas registran **0 errores y 56 avisos** por el requisito opcional de Kum'isha. Quedan **301 grupos de investigación y 94 de cliente**. El avance global por criterios completos sigue en **40,83 %**.

## Relaciones de los agrupamientos · corte verificado

- Se contrastaron los tres pares en las bases de QuestieDB y con las consultas de servidor ya disponibles. Los 51 casos de las 22 rutas contemplan ambas aceptaciones antes de los objetivos. El auditor revisa también los enlaces inferidos y las condiciones por perfil.
- Los 22 grupos pasan a **validación en el cliente**. La comparación local conserva ambos órdenes. Falta medir el terreno, las esperas, las patrullas y el tiempo de la piedra en Los Baldíos. Los huecos generales de relaciones siguen registrados por misión. [Ventanas, resultados y fuentes](auditor_fase13/AGRUPAMIENTOS_FASE13.md).
- Pasaron **16 pruebas específicas** y la **regresión de 72 pruebas**. El auditor registró **0 errores y 56 avisos**. Quedan **279 grupos de investigación y 116 de cliente**. El global sigue en **40,83 %** por criterios completos.

## Seguimientos de misión · corte verificado

- Se acreditaron **165 seguimientos nuevos** mediante el enlace heredado, la sugerencia del servidor y el historial del sucesor. El inventario pasó de 161 a **326 seguimientos documentados**. Ambos IDs aparecen juntos en ruta en 153 pares y la evidencia se reutilizó en 2.832 combinaciones de par y ruta. [Método y fuentes](auditor_fase13/FUENTES.md#seguimientos-contrastados--26-de-noviembre-de-2026).
- La comprobación de orden registró **0 errores y 56 avisos**, todos por el requisito opcional anterior a Kum'isha. Pasaron la prueba específica de fuentes y la **regresión de 73 pruebas**. Siguen abiertos 279 grupos de investigación y 116 de cliente. El avance por criterios completos permanece en **40,83 %**.

## Títulos españoles heredados · corte verificado

- Se cotejaron las etiquetas de recogida y entrega de los 195 IDs sin título español observado. **193 coinciden** con la localización heredada que QuestieDB empaqueta para Forever. Los IDs 85712 y 93686 carecen de entrada en ese archivo. El informe individual conserva los resultados, incluida la línea de cada título cotejado. [Fuente y alcance](auditor_fase13/FUENTES.md#localización-española-heredada--26-de-noviembre-de-2026).
- La cobertura observada queda en **2.273 títulos ES**. La comprobación heredada complementa ese dato. Pasaron la prueba específica y la **regresión de 74 pruebas**. Las 47 rutas registraron **0 errores y 56 avisos**, con **279 grupos de investigación y 116 de cliente**. El global se mantiene en **40,83 %**.

## Categorías y temporizadores · corte verificado

- Se contrastaron las categorías de **302 misiones activas**. Hay 111 de élite, 125 de mazmorra, cuatro de banda y 62 de JcJ. Se añadieron 22 temporizadores expresos. La categoría identifica el tipo de misión y el tamaño de grupo sigue dependiendo de la ficha del cliente. [Tabla y metodología](auditor_fase13/FUENTES.md#categorías-de-misión-y-temporizadores--26-de-noviembre-de-2026).
- Las nuevas fuentes revelaron **5.205 apariciones de 237 IDs** sin indicación de grupo, mazmorra o élite en el texto del paso. Se registran con el ID para resolverlas de forma compartida. Las 47 rutas muestran **0 errores y 5.261 avisos** que incluyen los 56 de Kum'isha. Quedan 279 grupos de investigación y 116 de cliente.
- Pasaron **5 pruebas específicas** y la **regresión de 75 pruebas**. La exportación de EverlookDB aportó referencias heredadas para 18 de las 24 misiones sin oferta acreditada. Las 24 siguen pendientes de confirmación en Forever. El avance por criterios completos se mantiene en **40,83 %**.

## Etiquetas de élite, mazmorra y banda · corte verificado

- Los destinos de **240 misiones** muestran su categoría de referencia antes de que responda el juego. Las etiquetas existentes aparecen en ES/EN. Cuando llega la ficha, su categoría y tamaño recomendado tienen prioridad. Se mantiene una sola etiqueta de mazmorra en cada tarjeta opcional. [Datos por ID y alcance](auditor_fase13/FUENTES.md#categorías-de-misión-y-temporizadores--26-de-noviembre-de-2026).
- Las 47 rutas resuelven los **5.205 avisos** de grupo para 237 IDs. El auditor ejecuta la función del addon en Lua y exige que la etiqueta corresponda a la categoría o que el paso lo indique. Quedan **0 errores y 56 avisos** por el requisito opcional previo a Kum'isha.
- Pasaron **9 pruebas específicas** y la **regresión de 76 pruebas**. Siguen abiertos **279 grupos de investigación y 116 de cliente**. El avance por criterios completos se mantiene en **40,83 %**. [Comprobaciones en la interfaz de Forever](auditor_fase13/VALIDACION_FOREVER.md).

## Prerrequisitos observados en las ofertas · corte verificado

- Se documentaron **477 fichas nuevas** con un prerrequisito de una sola entrega. El campo pasa de 193 a **670 fichas documentadas**. El auditor reutilizó el contraste en 7.222 combinaciones de misión y ruta. [Regla de contraste y fuentes](auditor_fase13/FUENTES.md#requisitos-de-una-sola-entrega--26-de-noviembre-de-2026).
- Se detectaron **33 avisos nuevos**. Las rutas afectadas deben entregar 455 antes de 473, 1848 antes de 1840 y 1947 antes de 1948. Los 56 avisos anteriores corresponden a la cadena opcional previa a Kum’isha.
- Pasaron **16 pruebas específicas** y la **regresión de 77 pruebas**. Las 47 rutas registran **0 errores y 89 avisos**. Quedan **279 grupos de investigación y 116 de cliente**. El avance por criterios completos sigue en **40,83 %**.

## Algaz, Armadura brutal y Tabetha · corte verificado

- Se corrigieron **31 rutas**. Las 25 de la Alianza muestran 455 antes de 473, con los objetivos de Dun Algaz y los niveles 19 y 23. Ocho pasan por Rockgar o ya incluían el asedio. Las demás presentan el desvío como opcional si se llega por mar.
- Las cuatro rutas de guerrero de la Horda entregan 1848 antes de recoger el encargo de Orm. Las dos rutas de mago de la Horda recogen 1947 con Deino en Orgrimmar, entregan a Tabetha y detallan los materiales de 1948 y su carga en Arathi. Se conservan los índices de paso y se añadieron textos ES/EN. [Puntos, cadenas y materiales](auditor_fase13/FUENTES.md#algaz-armadura-brutal-y-tabetha--26-de-noviembre-de-2026).
- Pasaron **2 pruebas específicas** y la **regresión de 78 pruebas**. Desaparecieron los **33 avisos de orden y acceso**. Las 47 rutas registran **0 errores y 56 avisos** de Kum’isha. El inventario conserva los 2.462 IDs originales. Quedan **279 grupos de investigación y 116 de cliente**. El avance por criterios completos permanece en **40,83 %**.

## Observaciones de posición y entrega · corte verificado

- Se incorporaron siete instantáneas de Efficient Games. Hay **520 destinos únicos adicionales** cerca de una posición observada, en 11.545 combinaciones de destino y ruta. Las fichas con entregas observadas pasan de 274 a **492**, diferenciadas por compilación y efecto Legacy. [Fuentes y alcance](auditor_fase13/FUENTES.md#observaciones-de-posiciones-y-entregas--26-de-noviembre-de-2026).
- El corte mantiene **24 IDs activos** sin evidencia positiva de oferta. Se conserva la comprobación directa de los casos estacionales y de banda cuando se habiliten. La cercanía de un destino y la XP efectiva de una entrega quedan en campos separados de la posición exacta y la XP base.
- Pasaron **14 pruebas específicas** y la **regresión de 79 pruebas**. Las 47 rutas registran **0 errores y 56 avisos** de Kum’isha. Quedan **279 grupos de investigación y 116 de cliente**. El avance por criterios completos sigue en **40,83 %**.

## Último bloque verificado · Objetos auxiliares, canjes y exclusiones

- Se documentaron objetos auxiliares en **28 misiones** mediante coincidencia con los campos de entrega o botín del servidor. Se acreditó la exclusión de las ofertas 3681 y 2998 de Libro de la Divinidad. También se registraron **24 misiones repetibles** con indicador explícito, incluidos los diez canjes de Frondavil. [Método y fuentes](auditor_fase13/FUENTES.md#objetos-auxiliares-canjes-y-exclusiones--26-de-noviembre-de-2026).
- El inventario tiene **43 fichas con objetos auxiliares**, **45 con exclusiones** y **26 con repetición acreditada**. Estos datos se incorporan por ID a todas sus rutas.
- Pasaron **17 pruebas específicas** y la **regresión de 80 pruebas**. Las 47 rutas mantienen **0 errores y 56 avisos** de Kum’isha, con **279 grupos de investigación y 116 de cliente**. El avance por criterios completos sigue en **40,83 %**.

## Comprobaciones que impiden cerrar los criterios

| Bloque | Investigación pendiente | Validación en Forever |
| --- | --- | --- |
| Misiones y dependencias | Entre 2.468 IDs activos faltan 24 acreditaciones de oferta, 195 títulos ES observados (193 cotejados con la referencia heredada), 25 EN, 25 niveles mínimos, 2.142 seguimientos y 2.444 fichas de prerrequisitos acumulativos y 1.798 de requisitos alternativos o de una sola entrega. Faltan también campos de exclusión, repetición, objetos, grupo y desbloqueos. | Oferta por fase o perfil cuando los registros externos no la acrediten. |
| Clase, raza y facción | 2.378 fichas sin condición de clase acreditada, 1.985 sin condición racial y 1.971 sin condición de facción. Incluye determinar si cada misión aplica una restricción. | Acceso real, raciales, desbloqueos y selección con los perfiles documentados. |
| Cartografía | 4.743 destinos únicos sin una referencia específica o cercana. Los 47 UiMapID ya están contrastados. | Coordenadas y accesos que queden sin observación, incluidos puntos reubicados. |
| Experiencia | 25 IDs activos sin XP base y estimación de combate pendiente en las 47 rutas. | XP efectiva, nivel inicial y bloqueos por tramo en las 47 rutas. |
| Viajes | Posiciones, transporte y requisitos de nodos en 44 rutas. | Costes y esperas en 47 rutas, incluidas las 22 con ventanas de agrupamiento. |
| Regresión y preparación | Novedades, documentación y ZIP final tras cerrar la auditoría local. Falta verificar la sincronización del cierre. | Pruebas de juego, Questie, persistencia y textos ES/EN. |

## Siguientes tareas

1. Contrastar la oferta de los ocho IDs sin fila en QuestV2 y los campos de repetición, objetos, exclusiones y desbloqueos.
2. Continuar por clase, raza y facción, cartografía, experiencia, viajes y regresión, en ese orden.
3. Ejecutar las comprobaciones de cliente cuando haya acceso a Forever. [Escenarios de validación](auditor_fase13/VALIDACION_FOREVER.md).

La fase sigue abierta. El corte previo es `ae1eb64`.

## Avance individual

Las 47 rutas completaron seis bloques de análisis local y ocho de los 18 criterios por ruta. Cada ruta conserva evidencia de investigación pendiente. Cero rutas están verificadas por completo en Forever.

| Ruta | Estado | Bloques locales | Criterios | Avisos | Investigación | Cliente |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `gnomo_mago` | Revisada localmente | 6/6 | 8/18 | 1 | 5 | 2 |
| `enano_chaman` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `enano_gnomo_guerrero` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 2 |
| `enano_paladin` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `enano_gnomo_sacerdote` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 2 |
| `enano_cazador` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `enano_gnomo_picaro` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 2 |
| `gnomo_brujo` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `humano_guerrero` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `humano_paladin` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `humano_picaro` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `humano_brujo` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `humano_mago` | Revisada localmente | 6/6 | 8/18 | 1 | 5 | 2 |
| `humano_sacerdote` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `humano_cazador` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `elfo_cazador` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `elfo_druida` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `elfo_guerrero` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `elfo_picaro` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `elfo_sacerdote` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `orco_trol_guerrero` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 3 |
| `orco_trol_cazador` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 3 |
| `orco_trol_picaro` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 3 |
| `orco_trol_chaman` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 3 |
| `orco_trol_brujo` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 3 |
| `orco_trol_mago` | Revisada localmente | 6/6 | 8/18 | 2 | 6 | 3 |
| `trol_sacerdote` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `tauren_guerrero` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `tauren_cazador` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `tauren_chaman` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `tauren_druida` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `nomuerto_guerrero` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `nomuerto_picaro` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `nomuerto_mago` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `nomuerto_sacerdote` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `nomuerto_brujo` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `nomuerto_paladin` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `skyborne_guerrero` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `skyborne_cazador` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `skyborne_picaro` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `skyborne_chaman` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `skyborne_druida` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 3 |
| `skyborne_a_guerrero` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `skyborne_a_cazador` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `skyborne_a_picaro` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |
| `skyborne_a_mago` | Revisada localmente | 6/6 | 8/18 | 1 | 5 | 2 |
| `skyborne_a_druida` | Revisada localmente | 6/6 | 8/18 | 1 | 6 | 2 |

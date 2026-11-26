# Progreso de la fase 13

**Avance global · 40,83 %**

`████████░░░░░░░░░░░░`

**Última actualización · 2026-11-26 01:01:32 +01:00 (Madrid)**

**Tarea actual** · Contrastar los refuerzos con XP base cero, las variantes de facción y los 32 IDs sin registro de existencia por ID.

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

## Último bloque verificado · Datos del servidor y observaciones

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

## Siguientes tareas

1. Revisar los 98 refuerzos con XP base calculada cero mediante entregas observadas, recompensas y fichas de Forever. Resolver las variantes de Bálsamo de Frondavil y los encargos de invasión entre facciones.
2. Contrastar los 32 IDs sin evidencia de existencia, los nombres ES y los 567 historiales de misiones previas. Buscar requisitos confirmados y separar los casos que dependen de un evento o condición del cliente.
3. Resolver las dependencias, el acceso y los objetos de las tres ventanas de viaje antes de cambiar su orden. La piedra temporal de 924 requiere una medición real hacia el altar.
4. Registrar en Forever los tiempos de recorrido y la XP efectiva cuando estén disponibles. [Escenarios de validación](auditor_fase13/VALIDACION_FOREVER.md).

La fase sigue abierta. El corte previo es `15b1a02`.

## Avance individual

Las 47 rutas completaron seis bloques de análisis local y ocho de los 18 criterios por ruta. Cada ruta conserva evidencia de investigación pendiente. Cero rutas están verificadas por completo en Forever.

| Ruta | Estado | Bloques locales | Criterios | Avisos | Investigación | Cliente |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `gnomo_mago` | Revisada localmente | 6/6 | 8/18 | 55 | 5 | 2 |
| `enano_chaman` | Revisada localmente | 6/6 | 8/18 | 56 | 6 | 2 |
| `enano_gnomo_guerrero` | Revisada localmente | 6/6 | 8/18 | 93 | 6 | 2 |
| `enano_paladin` | Revisada localmente | 6/6 | 8/18 | 88 | 6 | 2 |
| `enano_gnomo_sacerdote` | Revisada localmente | 6/6 | 8/18 | 93 | 6 | 2 |
| `enano_cazador` | Revisada localmente | 6/6 | 8/18 | 83 | 6 | 2 |
| `enano_gnomo_picaro` | Revisada localmente | 6/6 | 8/18 | 95 | 6 | 2 |
| `gnomo_brujo` | Revisada localmente | 6/6 | 8/18 | 82 | 6 | 2 |
| `humano_guerrero` | Revisada localmente | 6/6 | 8/18 | 80 | 6 | 2 |
| `humano_paladin` | Revisada localmente | 6/6 | 8/18 | 85 | 6 | 2 |
| `humano_picaro` | Revisada localmente | 6/6 | 8/18 | 82 | 6 | 2 |
| `humano_brujo` | Revisada localmente | 6/6 | 8/18 | 81 | 6 | 2 |
| `humano_mago` | Revisada localmente | 6/6 | 8/18 | 53 | 5 | 2 |
| `humano_sacerdote` | Revisada localmente | 6/6 | 8/18 | 82 | 6 | 2 |
| `humano_cazador` | Revisada localmente | 6/6 | 8/18 | 81 | 6 | 2 |
| `elfo_cazador` | Revisada localmente | 6/6 | 8/18 | 86 | 6 | 2 |
| `elfo_druida` | Revisada localmente | 6/6 | 8/18 | 83 | 6 | 2 |
| `elfo_guerrero` | Revisada localmente | 6/6 | 8/18 | 84 | 6 | 2 |
| `elfo_picaro` | Revisada localmente | 6/6 | 8/18 | 86 | 6 | 2 |
| `elfo_sacerdote` | Revisada localmente | 6/6 | 8/18 | 86 | 6 | 2 |
| `orco_trol_guerrero` | Revisada localmente | 6/6 | 8/18 | 48 | 7 | 2 |
| `orco_trol_cazador` | Revisada localmente | 6/6 | 8/18 | 45 | 7 | 2 |
| `orco_trol_picaro` | Revisada localmente | 6/6 | 8/18 | 49 | 7 | 2 |
| `orco_trol_chaman` | Revisada localmente | 6/6 | 8/18 | 49 | 7 | 2 |
| `orco_trol_brujo` | Revisada localmente | 6/6 | 8/18 | 49 | 7 | 2 |
| `orco_trol_mago` | Revisada localmente | 6/6 | 8/18 | 45 | 7 | 2 |
| `trol_sacerdote` | Revisada localmente | 6/6 | 8/18 | 46 | 7 | 2 |
| `tauren_guerrero` | Revisada localmente | 6/6 | 8/18 | 48 | 7 | 2 |
| `tauren_cazador` | Revisada localmente | 6/6 | 8/18 | 44 | 7 | 2 |
| `tauren_chaman` | Revisada localmente | 6/6 | 8/18 | 46 | 7 | 2 |
| `tauren_druida` | Revisada localmente | 6/6 | 8/18 | 50 | 7 | 2 |
| `nomuerto_guerrero` | Revisada localmente | 6/6 | 8/18 | 50 | 7 | 2 |
| `nomuerto_picaro` | Revisada localmente | 6/6 | 8/18 | 52 | 7 | 2 |
| `nomuerto_mago` | Revisada localmente | 6/6 | 8/18 | 47 | 7 | 2 |
| `nomuerto_sacerdote` | Revisada localmente | 6/6 | 8/18 | 54 | 7 | 2 |
| `nomuerto_brujo` | Revisada localmente | 6/6 | 8/18 | 52 | 7 | 2 |
| `nomuerto_paladin` | Revisada localmente | 6/6 | 8/18 | 56 | 7 | 2 |
| `skyborne_guerrero` | Revisada localmente | 6/6 | 8/18 | 50 | 7 | 2 |
| `skyborne_cazador` | Revisada localmente | 6/6 | 8/18 | 47 | 7 | 2 |
| `skyborne_picaro` | Revisada localmente | 6/6 | 8/18 | 50 | 7 | 2 |
| `skyborne_chaman` | Revisada localmente | 6/6 | 8/18 | 45 | 7 | 2 |
| `skyborne_druida` | Revisada localmente | 6/6 | 8/18 | 49 | 7 | 2 |
| `skyborne_a_guerrero` | Revisada localmente | 6/6 | 8/18 | 73 | 6 | 2 |
| `skyborne_a_cazador` | Revisada localmente | 6/6 | 8/18 | 76 | 6 | 2 |
| `skyborne_a_picaro` | Revisada localmente | 6/6 | 8/18 | 78 | 6 | 2 |
| `skyborne_a_mago` | Revisada localmente | 6/6 | 8/18 | 55 | 5 | 2 |
| `skyborne_a_druida` | Revisada localmente | 6/6 | 8/18 | 71 | 6 | 2 |

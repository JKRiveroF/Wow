# Progreso de la fase 13

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
| Clase, raza y facción | 10 % | 57/141 | 40,43 % | 40,43 % |
| Regresión y preparación | 5 % | 1/4 | 0 % | 25 % |
| **Global ponderado** | **100 %** | | **36,96 %** | **38,21 %** |

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

## Avance individual

Cada ruta completó los seis bloques de análisis local. La columna de criterios considera las 18 comprobaciones aplicables por ruta. Se completaron ocho para cada ruta Skyborne y siete para las restantes. Las comprobaciones globales se contabilizan en la tabla de áreas.

| ID | Bloques locales | Criterios completos | Grupos pendientes | Validación en Forever |
| --- | ---: | ---: | ---: | --- |
| `gnomo_mago` | 6/6 | 7/18 | 7 | Pendiente |
| `enano_chaman` | 6/6 | 7/18 | 7 | Pendiente |
| `enano_gnomo_guerrero` | 6/6 | 7/18 | 7 | Pendiente |
| `enano_paladin` | 6/6 | 7/18 | 7 | Pendiente |
| `enano_gnomo_sacerdote` | 6/6 | 7/18 | 7 | Pendiente |
| `enano_cazador` | 6/6 | 7/18 | 7 | Pendiente |
| `enano_gnomo_picaro` | 6/6 | 7/18 | 7 | Pendiente |
| `gnomo_brujo` | 6/6 | 7/18 | 7 | Pendiente |
| `humano_guerrero` | 6/6 | 7/18 | 7 | Pendiente |
| `humano_paladin` | 6/6 | 7/18 | 7 | Pendiente |
| `humano_picaro` | 6/6 | 7/18 | 7 | Pendiente |
| `humano_brujo` | 6/6 | 7/18 | 7 | Pendiente |
| `humano_mago` | 6/6 | 7/18 | 7 | Pendiente |
| `humano_sacerdote` | 6/6 | 7/18 | 7 | Pendiente |
| `humano_cazador` | 6/6 | 7/18 | 7 | Pendiente |
| `elfo_cazador` | 6/6 | 7/18 | 7 | Pendiente |
| `elfo_druida` | 6/6 | 7/18 | 7 | Pendiente |
| `elfo_guerrero` | 6/6 | 7/18 | 7 | Pendiente |
| `elfo_picaro` | 6/6 | 7/18 | 7 | Pendiente |
| `elfo_sacerdote` | 6/6 | 7/18 | 7 | Pendiente |
| `orco_trol_guerrero` | 6/6 | 7/18 | 8 | Pendiente |
| `orco_trol_cazador` | 6/6 | 7/18 | 8 | Pendiente |
| `orco_trol_picaro` | 6/6 | 7/18 | 8 | Pendiente |
| `orco_trol_chaman` | 6/6 | 7/18 | 8 | Pendiente |
| `orco_trol_brujo` | 6/6 | 7/18 | 8 | Pendiente |
| `orco_trol_mago` | 6/6 | 7/18 | 8 | Pendiente |
| `trol_sacerdote` | 6/6 | 7/18 | 8 | Pendiente |
| `tauren_guerrero` | 6/6 | 7/18 | 8 | Pendiente |
| `tauren_cazador` | 6/6 | 7/18 | 8 | Pendiente |
| `tauren_chaman` | 6/6 | 7/18 | 8 | Pendiente |
| `tauren_druida` | 6/6 | 7/18 | 8 | Pendiente |
| `nomuerto_guerrero` | 6/6 | 7/18 | 8 | Pendiente |
| `nomuerto_picaro` | 6/6 | 7/18 | 8 | Pendiente |
| `nomuerto_mago` | 6/6 | 7/18 | 8 | Pendiente |
| `nomuerto_sacerdote` | 6/6 | 7/18 | 8 | Pendiente |
| `nomuerto_brujo` | 6/6 | 7/18 | 8 | Pendiente |
| `nomuerto_paladin` | 6/6 | 7/18 | 8 | Pendiente |
| `skyborne_guerrero` | 6/6 | 8/18 | 8 | Pendiente |
| `skyborne_cazador` | 6/6 | 8/18 | 8 | Pendiente |
| `skyborne_picaro` | 6/6 | 8/18 | 8 | Pendiente |
| `skyborne_chaman` | 6/6 | 8/18 | 8 | Pendiente |
| `skyborne_druida` | 6/6 | 8/18 | 8 | Pendiente |
| `skyborne_a_guerrero` | 6/6 | 8/18 | 7 | Pendiente |
| `skyborne_a_cazador` | 6/6 | 8/18 | 7 | Pendiente |
| `skyborne_a_picaro` | 6/6 | 8/18 | 7 | Pendiente |
| `skyborne_a_mago` | 6/6 | 8/18 | 7 | Pendiente |
| `skyborne_a_druida` | 6/6 | 8/18 | 7 | Pendiente |

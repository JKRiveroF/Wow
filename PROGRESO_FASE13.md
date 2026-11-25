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

La rama local partió del mismo commit que GitHub, `83fab5b`. `git fsck --full` terminó sin errores. Los 219 SHA-256 coinciden con el disco y con los blobs del commit de restauración `592d887`.

El auditor externo compiló los 144 ficheros Lua del TOC con Lupa 2.8 (Lua 5.1) y cargó 47 rutas. Las 56 combinaciones pasaron selección, carga y filtro racial con las funciones originales y API simulada. La comprobación estructural no registró errores, avisos ni pendientes. Los originales seguían intactos al cerrar el bloque.

| Área | Peso | Comprobaciones completas | Anterior | Actual |
| --- | ---: | ---: | ---: | ---: |
| Estructura | 10 % | 95/95 | 100 % | 100 % |
| Misiones | 25 % | 47/188 | 25 % | 25 % |
| Cartografía | 20 % | 47/141 | 0 % | 33,33 % |
| Experiencia | 15 % | 0/141 | 0 % | 0 % |
| Viajes | 15 % | 0/141 | 0 % | 0 % |
| Clase, raza y facción | 10 % | 47/141 | 33,33 % | 33,33 % |
| Regresión y preparación | 5 % | 0/4 | 0 % | 0 % |
| **Global ponderado** | **100 %** | | **19,58 %** | **26,25 %** |

Las 95 comprobaciones estructurales son una compilación global, 47 verificaciones del contrato de ruta y 47 validaciones del motor por ruta con todas sus combinaciones declaradas.

| Rutas pendientes | En revisión | Revisadas localmente | Verificadas por completo |
| ---: | ---: | ---: | ---: |
| 0 | 47 | 0 | 0 |

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
- Siguiente tarea: corregir la recomendación de XP de la repetible 1878 y volver a ejecutar el bloque de experiencia.

## Avance individual

| ID | Bloques auditados localmente | Validación en Forever |
| --- | ---: | --- |
| `gnomo_mago` | 4/6 | Pendiente |
| `enano_chaman` | 4/6 | Pendiente |
| `enano_gnomo_guerrero` | 4/6 | Pendiente |
| `enano_paladin` | 4/6 | Pendiente |
| `enano_gnomo_sacerdote` | 4/6 | Pendiente |
| `enano_cazador` | 4/6 | Pendiente |
| `enano_gnomo_picaro` | 4/6 | Pendiente |
| `gnomo_brujo` | 4/6 | Pendiente |
| `humano_guerrero` | 4/6 | Pendiente |
| `humano_paladin` | 4/6 | Pendiente |
| `humano_picaro` | 4/6 | Pendiente |
| `humano_brujo` | 4/6 | Pendiente |
| `humano_mago` | 4/6 | Pendiente |
| `humano_sacerdote` | 4/6 | Pendiente |
| `humano_cazador` | 4/6 | Pendiente |
| `elfo_cazador` | 4/6 | Pendiente |
| `elfo_druida` | 4/6 | Pendiente |
| `elfo_guerrero` | 4/6 | Pendiente |
| `elfo_picaro` | 4/6 | Pendiente |
| `elfo_sacerdote` | 4/6 | Pendiente |
| `orco_trol_guerrero` | 4/6 | Pendiente |
| `orco_trol_cazador` | 4/6 | Pendiente |
| `orco_trol_picaro` | 4/6 | Pendiente |
| `orco_trol_chaman` | 4/6 | Pendiente |
| `orco_trol_brujo` | 4/6 | Pendiente |
| `orco_trol_mago` | 4/6 | Pendiente |
| `trol_sacerdote` | 4/6 | Pendiente |
| `tauren_guerrero` | 4/6 | Pendiente |
| `tauren_cazador` | 4/6 | Pendiente |
| `tauren_chaman` | 4/6 | Pendiente |
| `tauren_druida` | 4/6 | Pendiente |
| `nomuerto_guerrero` | 4/6 | Pendiente |
| `nomuerto_picaro` | 4/6 | Pendiente |
| `nomuerto_mago` | 4/6 | Pendiente |
| `nomuerto_sacerdote` | 4/6 | Pendiente |
| `nomuerto_brujo` | 4/6 | Pendiente |
| `nomuerto_paladin` | 4/6 | Pendiente |
| `skyborne_guerrero` | 4/6 | Pendiente |
| `skyborne_cazador` | 4/6 | Pendiente |
| `skyborne_picaro` | 4/6 | Pendiente |
| `skyborne_chaman` | 4/6 | Pendiente |
| `skyborne_druida` | 4/6 | Pendiente |
| `skyborne_a_guerrero` | 4/6 | Pendiente |
| `skyborne_a_cazador` | 4/6 | Pendiente |
| `skyborne_a_picaro` | 4/6 | Pendiente |
| `skyborne_a_mago` | 4/6 | Pendiente |
| `skyborne_a_druida` | 4/6 | Pendiente |

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

## Pendiente

- Implementar el auditor y determinar si las comprobaciones de ejecución requieren un intérprete Lua compatible con el cliente.
- Validar el funcionamiento dentro de WoW Forever. La documentación original de la 9.7.9 ya marca esta prueba como pendiente.

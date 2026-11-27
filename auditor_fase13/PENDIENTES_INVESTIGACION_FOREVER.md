# Registro permanente de investigación en WoW Forever

El auditor conserva los grupos por prioridad, bloque y ruta. Los informes `incidencias_funcionales.json` y `misiones_individuales.json` reconstruyen el detalle, las posiciones y la evidencia por ID con la ejecución documentada. Un P0 o P1 requiere resolución antes del cierre funcional. P2 y P3 pueden pasar a futuras versiones si el recorrido principal funciona y la evidencia sigue registrada. [Comando de auditoría](README.md#actualizar-la-medición-de-la-fase).

<!-- incidencias-fase13:inicio -->

| Prioridad | Bloque | Comprobación | ID de misión | Casos | Rutas | Confianza y motivo | Fuente o comprobación futura |
| --- | ---: | --- | ---: | ---: | --- | --- | --- |
| P2 | 2 | `MISION_REQUISITO_ALTERNATIVO` | 93685 | 56 | Todas las rutas | dependencia de canje opcional comprobada | [Evidencia](https://github.com/Questie/QuestieDB/blob/v1.1.6/src/corrections/Forever/foreverQuestFixes.lua#L2493) |
| P2 | 3 | `posiciones_sin_evidencia_forever` | — | 47 | Todas las rutas | estimación o precisión pendiente | Cruzar el inventario por ID con fuentes de Forever |
| P2 | 4 | `xp_escenario_misiones` | — | 47 | Todas las rutas | estimación o precisión pendiente | Cruzar el inventario por ID con fuentes de Forever |
| P2 | 4 | `xp_evidencia_incompleta` | — | 47 | Todas las rutas | estimación o precisión pendiente | Cruzar el inventario por ID con fuentes de Forever |
| P2 | 4 | `xp_real_cliente` | — | 47 | Todas las rutas | estimación o precisión pendiente | [Protocolo de cliente](VALIDACION_FOREVER.md) |
| P2 | 5 | `objetivos_agrupables` | — | 22 | `nomuerto_brujo`, `nomuerto_guerrero`, `nomuerto_mago`, `nomuerto_paladin`, `nomuerto_picaro`, `nomuerto_sacerdote`, `orco_trol_brujo`, `orco_trol_cazador`, `orco_trol_chaman`, `orco_trol_guerrero`, `orco_trol_mago`, `orco_trol_picaro`, `skyborne_cazador`, `skyborne_chaman`, `skyborne_druida`, `skyborne_guerrero`, `skyborne_picaro`, `tauren_cazador`, `tauren_chaman`, `tauren_druida`, `tauren_guerrero`, `trol_sacerdote` | estimación o precisión pendiente | [Protocolo de cliente](VALIDACION_FOREVER.md) |
| P2 | 5 | `viajes_coste_cliente` | — | 47 | Todas las rutas | estimación o precisión pendiente | [Protocolo de cliente](VALIDACION_FOREVER.md) |
| P3 | 2 | `MISION_FUENTES_INCOMPLETAS` | — | 47 | Todas las rutas | dato pendiente | Cruzar el inventario por ID con fuentes de Forever |
| P3 | 6 | `PERFIL_REQUISITOS_PENDIENTES` | — | 47 | Todas las rutas | dato pendiente | Cruzar el inventario por ID con fuentes de Forever |

<!-- incidencias-fase13:fin -->

## Casos abiertos que se conservan por ID

| Prioridad | Afectación | Confianza y motivo | Comprobación futura |
| --- | --- | --- | --- |
| P3 | 1374, 1375, 5201, 6848, 8319 y 9266 en 32, 34, 24, 1, 46 y 20 rutas respectivamente | La oferta carece de confirmación suficiente. Las instrucciones de estas misiones permiten seguir el recorrido sin aceptarlas. | Contrastar iniciador, requisitos y variante con una oferta actual. [Matriz por ID](VALIDACION_FOREVER.md#matriz-de-oferta-pendiente-por-misión). |
| P3 | 2358, 3504, 6804, 6805, 6821, 7622, 8353, 8355, 8356, 8556, 8689, 8691, 8692, 8693, 8694, 8696, 8788 y 8863 | Hay pruebas parciales de oferta, requisitos de fase o acceso al contenido. Las rutas conservan los canjes y encargos condicionados. | Repetir por perfil, fase o evento. La matriz detalla rutas y evidencia. [Pruebas por ID](VALIDACION_FOREVER.md#matriz-de-oferta-pendiente-por-misión). |
| P2 | 5921/18960, 5922/18960, 7463/10140, 9364/28272, 90902/635, 94505/5394, 94911/18960 y 94912/18960 | Hay indicios de recompensa o aprendizaje. Sigue pendiente el momento exacto y el origen de algunas habilidades. La prueba esencial de clase tiene su propio requisito funcional. | Comparar el libro de hechizos antes y después del instructor, la oferta y la entrega. [Matriz de aprendizaje](VALIDACION_FOREVER.md#aprendizaje-de-habilidades-por-misión). |
| P2 | 2855–2859 y 4148/5150, dos lugares y siete destinos compartidos en 22 rutas por destino | Hay botín observado en otros lugares o en la planta de Un’Goro. Falta atribuirlo al punto exacto de cada marcador. | Registrar el objeto, la entidad y el avance con la misión activa. [Prueba de los dos lugares](VALIDACION_FOREVER.md#botín-en-feralas-y-ungoro). |
| P2 | 93685 y 93686 en las 47 rutas | Canjes opcionales. El motor permite omitir ambos pasos por separado. Falta conocer condiciones y ubicación exactas de oferta para todos los perfiles. | Probar con y sin 93684 en el historial, con el necesario objeto 8244 y con el perfil correspondiente. [Evidencia de Kum’isha](FUENTES.md#cadena-opcional-de-kumisha--26-de-noviembre-de-2026). |
| P2 | 22 rutas con ventanas de agrupamiento | Los candidatos locales conservan dependencias y distancias. El ahorro real depende del acceso y las esperas. | Medir secuencias comparables, guardar tiempos y descartar pasos inviables. [Detalle de agrupamientos](AGRUPAMIENTOS_FASE13.md). |
| P3 | Campos secundarios y restricciones genéricas de las misiones activas | Confirmada es una condición acreditada. La ausencia de restricción requiere un dato explícito. Las coincidencias entre referencias pueden ser probables. Un campo vacío por falta de evidencia queda desconocido. | Contrastar campo por campo y reutilizar la evidencia por ID sin sobrescribir observaciones confirmadas. [Fuentes](FUENTES.md). |

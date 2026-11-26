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
- [ ] Resolver los refuerzos con XP base cero, los avisos de facción, los títulos ES discrepantes y los 32 IDs sin identidad confirmada en el catálogo.
- [ ] Probar dentro de Forever los aspectos que dependen del cliente, incluidos Questie, datos guardados, traducciones y selección de ruta.
- [ ] Actualizar las novedades ES/EN y preparar el ZIP definitivo con los archivos distribuibles, tras superar los criterios de cierre local.
- [ ] Verificar la sincronización del cierre únicamente en la rama de desarrollo con `origin`. La fusión y las Releases quedan pendientes de autorización expresa.

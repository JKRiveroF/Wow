# Auditor externo de Guía del Aventurero

El auditor toma la carpeta instalable como entrada. Lua 5.1 compila los módulos que declara el TOC, carga las rutas y ejecuta las funciones originales de selección, carga y filtrado racial con una API simulada. El entorno local sirve para verificar el código y los datos. Las comprobaciones del cliente quedan registradas por separado.

Con Python 3.11 o posterior, ejecuta estos comandos desde la raíz del repositorio en PowerShell:

```powershell
python -m venv auditor_fase13/.venv
auditor_fase13/.venv/Scripts/python.exe -m pip install -r auditor_fase13/requirements.txt
auditor_fase13/.venv/Scripts/python.exe auditor_fase13/auditar.py
```

La salida contiene `INFORME.md`, `resultados.json` y un informe por ruta en `rutas/`. El proceso devuelve `1` si encuentra errores y `2` si falla la lectura o la preparación de la salida. Usa `--addon` para auditar otra carpeta y `--salida` para guardar ejecuciones por separado. Las salidas por defecto y el entorno virtual permanecen fuera de los archivos versionados.

## Actualizar la medición de la fase

Al cerrar un bloque verificado, ejecuta desde la raíz del repositorio la auditoría completa con las cuatro fuentes locales. La opción `--actualizar-progreso` ejecuta la regresión y regenera los indicadores de `PROGRESO_FASE13.md`, `PLAN_FASE13.md` y `auditor_fase13/progreso_medicion.json`. Una consulta sin esa opción guarda su medición bajo `--salida`. `--regresion` permite añadir las pruebas a una consulta local.

```powershell
$fuentes = 'auditor_fase13/cache_fuentes'
auditor_fase13/.venv/Scripts/python.exe -B auditor_fase13/auditar.py --trazas-questie $fuentes --datos-questie $fuentes --datos-eg $fuentes --questv2 "$fuentes/QuestV2-1.60.1.71139.csv" --actualizar-progreso
```

El procedimiento reutiliza el inventario de misiones, posiciones, vuelos y agrupamientos de esa misma ejecución. El JSON versionado conserva las fracciones exactas, los numeradores y denominadores de las familias, los estados de evidencia y las diferencias con el último corte medido. [Fórmula y criterios](../PLAN_FASE13.md#criterios-de-medición).

Las comprobaciones realizadas en Forever se pueden añadir a `auditor_fase13/validaciones_progreso.json` o indicar con `--validaciones`. El archivo contiene una lista JSON. Usa el ID de ruta como `unidad` para los criterios de ruta, el título de la fila del protocolo para `7.caso_cliente`, la clave publicada en `ventanas_agrupamiento` para `5.ahorro` y el par `misión/hechizo` para `6.aprendizaje`, por ejemplo `7463/10140`. Las revisiones `7.paquete` y `7.sincronizacion` usan `final`. Cada resultado cita la sesión o fichero que documenta el alcance de la comprobación. Los resultados `fallo` y `pendiente` quedan abiertos. Registra como `verificado` cada comprobación completa según el plan, con la compilación en las pruebas de cliente. Para un par de aprendizaje, incluye evidencia de los perfiles de ruta que sigan pendientes. [Protocolo de Forever](VALIDACION_FOREVER.md).

| Comprobación en Forever | Claves de registro |
| --- | --- |
| Transiciones, interiores y puntos de vuelo | `3.transiciones`, `3.interiores`, `3.puntos_vuelo` |
| Saldo y bloqueos de XP por tramo | `4.saldo`, `4.bloqueos` |
| Tiempos y secuencias de viaje, medición de agrupamientos | `5.tiempos_secuencias`, `5.ahorro` |
| Acceso, desbloqueos y traducciones por perfil | `6.acceso`, `6.desbloqueos`, `6.traducciones` |
| Confirmación del aprendizaje de un hechizo concreto | `6.aprendizaje` |
| Casos transversales de regresión | `7.caso_cliente` |

Las revisiones de investigación usan `2.identidad`, `2.dependencias`, `2.especiales`, `3.posiciones`, `4.estimacion`, `5.transporte`, `5.desbloqueos` y `5.alternativas`. Cita la ficha de contraste y completa su evidencia en el catálogo antes de cerrar un criterio. Para las unidades sin aplicación, la revisión debe justificarlo en la evidencia citada.

```json
[
  {
    "criterio": "3.interiores",
    "unidad": "gnomo_mago",
    "resultado": "pendiente",
    "fecha": "2026-11-26",
    "compilacion": "1.60.1.71139",
    "fuente": "VALIDACION_FOREVER.md#evidencia-de-la-sesión"
  }
]
```

El bloque 2 genera también `misiones_individuales.json`, con un registro por ID, sus rutas y posiciones compartidas, evidencia por campo e indicios por contrastar. Las misiones de 9.7.9 retiradas de las rutas conservan sus fichas y el motivo. Los informes distinguen los pendientes de investigación de los que requieren ejecutar el cliente.

`--bloque` permite seleccionar uno o más ámbitos. La estructura siempre se comprueba porque los demás bloques dependen de las rutas cargadas. Usa `--catalogo` para aportar evidencia JSON adicional. `evidencia_forever.json` muestra ejemplos con fuente fechada y procedencia por campo. Las claves de misiones, mapas y PNJ son sus IDs como texto. Una ficha ausente deja la verificación pendiente.

`--trazas-questie` acepta una carpeta local con `foreverQuestTraces.lua`, `xpDB-traces.lua` y `uiMapIdToAreaId.lua` de QuestieDB 1.1.6. El auditor verifica los hashes y lee las filas de datos sin ejecutar esos módulos. La cobertura alcanza la existencia observada, los títulos EN presentes, la XP base registrada y los mapas canónicos de la build 1.60.1.69893. Las fichas confirmadas de `evidencia_forever.json` tienen prioridad sobre las trazas. El catálogo adicional puede aportar evidencia posterior por campo. Consulta [las fuentes y su alcance](FUENTES.md).

Con `--datos-questie`, guarda opcionalmente los [títulos esES heredados de Forever](https://raw.githubusercontent.com/Questie/QuestieDB/v1.1.6/l10n/Forever/lookupQuests/esES.lua) como `questie-forever-heredado-esES.lua` en `cache_fuentes/`. Para las misiones sin título español observado, `contraste_es_heredado` reúne el título de referencia y las etiquetas de ruta que difieren. La cobertura de títulos observados se calcula por separado.

`--datos-questie` añade `foreverBaseQuest.lua`, `foreverQuestFixes.lua` y `foreverQuestRelationTraces.lua` de esa misma revisión. Opcionalmente lee `questie-forever-quests-esES.lua` y `questie-forever-quests-esMX.lua` si están en la carpeta. Las relaciones inferidas se muestran por separado de los requisitos contrastados. Consulta los archivos y enlaces en [FUENTES.md](FUENTES.md).

`--datos-eg` incorpora los JSON de [EG Link](FUENTES.md#consultas-del-servidor-y-observaciones-de-efficient-games--26-de-noviembre-de-2026) y `QuestXP-1.60.1.71091.csv`. Guarda cada JSON como `eg-1.60.1.<compilación>-<dataset>.json` en `cache_fuentes/`. Los nombres, las compilaciones y los hashes están en `eg_link.py`. El bloque 5 genera también `vuelos_observados.json`. Guarda el CSV [TaxiNodes esES de 71139](https://wago.tools/db2/TaxiNodes/csv?build=1.60.1.71139&locale=esES) en `cache_fuentes/TaxiNodes-esES-1.60.1.71139.csv` y las instantáneas opcionales `flights` indicadas en `EXTRA_HASHES`. El informe conserva las conexiones por sentido, variante de talento y compilación y señala los nodos sin maestro observado. El cálculo de XP base completa huecos de la traza y conserva método y fuente. Las observaciones de entregas y de progreso siguen en sus propios campos.

```powershell
auditor_fase13/.venv/Scripts/python.exe -B auditor_fase13/auditar.py --trazas-questie auditor_fase13/cache_fuentes --datos-questie auditor_fase13/cache_fuentes
auditor_fase13/.venv/Scripts/python.exe -B auditor_fase13/agrupamientos.py --trazas-questie auditor_fase13/cache_fuentes --datos-questie auditor_fase13/cache_fuentes
```

Añade `--datos-eg auditor_fase13/cache_fuentes` cuando tengas la revisión de Efficient Games y la tabla de XP.

Puedes añadir las instantáneas de observación indicadas en `EXTRA_HASHES` de `eg_link.py`. El auditor conserva las coordenadas distintas por acción y las filas de entrega por compilación. Identifica las filas que la fuente registra en `withLegacy`. El cálculo de XP base usa los campos de dificultad y multiplicador. El informe conserva las referencias de cada compilación utilizada.

Las siete instantáneas de misión de la [revisión 71139 de Efficient Games](https://github.com/JIVESCORP/eg-link-output-wowf/tree/1339ce5600bbc2b12e8f1081e584f548f62fa57f/data/wowf/1.60.1.71139) usan el mismo patrón `eg-1.60.1.71139-<dataset>.json`. Con [QuestXP 71139](https://wago.tools/db2/QuestXP/csv?build=1.60.1.71139) en el archivo `QuestXP-1.60.1.71139.csv`, el auditor cita la tabla más reciente. Las tablas de XP 71091 y 71139 tienen el mismo SHA-256.

Los archivos `quest_scan` y `npcs` de 70790, 70862 y 70888 son opcionales y usan el mismo patrón. Amplían las muestras de PNJ y el historial de consultas sin respuesta. [Instantáneas y alcance](FUENTES.md#oferta-en-las-compilaciones-iniciales--26-de-noviembre-de-2026).

El mismo patrón permite incorporar `quests.enUS` y `turn_ins` de 70790, 70840, 70862 y 70888, `npcs` y `quest_scan` de 70840, y `npcs` y `turn_ins` de 70938. Las entregas guardan la compilación y el contexto, incluido el talento Legado cuando se observó. Para acreditar ambas facciones, el auditor exige una entrega de cada una con título, nivel mínimo y máscara racial del servidor iguales a los de la ficha más reciente. Conserva las fuentes de las dos entregas y las fichas comparadas. [Datos y límites](FUENTES.md#entregas-y-facciones-de-las-compilaciones-iniciales--26-de-noviembre-de-2026).

`interlocutores_observados` reúne iniciadores (`A`) y receptores (`T`) por misión, con el tipo de entidad, su ID y la compilación. Las coordenadas y los requisitos de la misión se consultan en sus propios campos. [Iniciadores y entregas](FUENTES.md#iniciadores-y-entregas-observados--26-de-noviembre-de-2026).

Puedes añadir `foreverNpcTraces.lua`, `foreverObjectTraces.lua` y `foreverQuestDB.lua` de QuestieDB 1.1.6 al caché de `--datos-questie`. El auditor comprueba los SHA-256 fijados en `contactos.py`. `referencias_interaccion` separa el vínculo de recogida o entrega de la observación de la posición, con una fuente para cada uno. Los registros diferencian la interacción observada y el vínculo del catálogo estático. Las apariciones de PNJ de las trazas usan las asignaciones de mapa canónicas. [Archivos y procedimiento](FUENTES.md#coordenadas-de-iniciadores-y-receptores).

Las instantáneas `creatures.json` fijadas en `EXTRA_HASHES` de `eg_link.py` siguen el patrón del resto del caché de Efficient Games. El auditor cruza las observaciones de bajas y las interacciones o aproximaciones a PNJ y objetos con `objetivos_servidor`. `referencias_objetivo` conserva tipo, ID, posición y compilación. Solo se usa como cercanía para la acción `C` dentro del mismo UiMapID. Las conversiones documentadas de 1486 y 6563 se conservan por acción en `posiciones_reproyectadas`. [Método y fuentes cartográficas](FUENTES.md#posiciones-de-entidades-de-objetivo--26-de-noviembre-de-2026).

Puedes añadir `foreverItemTraces.lua` y `foreverItemFixes.lua` de QuestieDB 1.1.6 al caché de `--datos-questie`. El auditor aplica las correcciones antes de cruzar las fuentes de botín. `referencias_botin` registra el objeto de misión, su entidad de origen y la fuente de su posición. La cercanía solo acredita contraste parcial para la acción `C`. [Fuentes de botín y método](FUENTES.md#botín-y-posiciones-de-obtención).

Los `loot.json` de Efficient Games fijados en `EXTRA_HASHES` siguen el mismo patrón que las demás instantáneas. El auditor acepta observaciones positivas atribuidas a un PNJ u objeto por su ID, aplica las correcciones de QuestieDB y conserva el vínculo en `origenes_botin` aunque falten coordenadas. La posición de la entidad y el botín tienen referencias separadas. [Botín observado](FUENTES.md#botín-observado-en-efficient-games).

Con `--datos-eg`, puedes añadir `creature_details.enUS.json` y `object_details.enUS.json` de las compilaciones fijadas en `EXTRA_HASHES` con el mismo patrón de nombre del caché. El auditor lee `questItems` de la última respuesta disponible por tipo e ID de entidad. Las referencias de `consulta_entidad` acreditan el vínculo declarado por el servidor. Una observación directa de botín tiene prioridad para el mismo vínculo. Las coordenadas de la entidad se comprueban por separado. [Consultas de entidades](FUENTES.md#objetos-de-misión-en-las-consultas-de-entidades).

`acceso_observado` conserva una entrega representativa por combinación de raza y facción con ficha estable. Una observación de acceso cuenta como contraste parcial del campo correspondiente. Las restricciones explícitas y las comprobaciones de cliente se registran por separado. Las muestras carecen de clase.

Guarda el [CSV QuestSort de Forever 1.60.1.71139](https://wago.tools/db2/QuestSort/csv?build=1.60.1.71139) como `QuestSort-1.60.1.71139.csv` en el caché de `--datos-eg`. Con las dos bases heredadas de `--datos-questie`, el auditor coteja la máscara de clase con el título EN y la categoría observados por ID. `contraste_clase_heredada` separa las coincidencias parciales de las inferencias. Los cambios dinámicos y las restricciones explícitas de Forever tienen prioridad. La máscara heredada queda como referencia para investigar el acceso y la cobertura certificada usa la evidencia de `clases`.

Con `--datos-eg`, guarda `SpellEffect-1.60.1.71139.csv` y `SkillLineAbility-1.60.1.71139.csv` en el mismo caché para contrastar las habilidades. El auditor verifica ambos SHA-256 y registra las pruebas en `aprendizaje_recompensa`. El apartado `aprendizaje_en_rutas` compara las declaraciones de las rutas una vez por par de misión y hechizo. Distingue el efecto directo, el aprendizaje por rango, el indicio de recompensa, el efecto con destino sin declarar y los casos pendientes. El efectivo acredita el par completo cuando existe evidencia para todos sus perfiles o una validación documentada en Forever. [Fuentes y criterios](FUENTES.md#aprendizaje-por-misión--26-de-noviembre-de-2026).

El [CSV QuestInfo de Forever 1.60.1.71091](https://wago.tools/db2/QuestInfo/csv?build=1.60.1.71091) es opcional. Guárdalo como `QuestInfo-1.60.1.71091.csv` junto a los JSON de Efficient Games. Con él, el auditor identifica las categorías expresas de élite, mazmorra, banda y JcJ. Los límites de tiempo se leen de las consultas de misión cuando incluyen ese dato.

Con `--datos-questie` y `--datos-eg`, puedes añadir dos fuentes opcionales para el contraste de relaciones. Guarda la [base Classic de QuestieDB 1.1.6](https://raw.githubusercontent.com/Questie/QuestieDB/v1.1.6/data/Classic/classicQuestDB.lua) como `classicQuestDB.lua` y las [correcciones heredadas por Forever](https://raw.githubusercontent.com/Questie/QuestieDB/v1.1.6/src/corrections/Forever/legacy/classicQuestFixes.lua) como `legacyForeverClassicQuestFixes.lua` en `cache_fuentes/`. El auditor verifica ambos hashes. Para los seguimientos cruza el enlace heredado, la sugerencia del servidor y el historial del sucesor. Para los requisitos contrasta el tipo de lista heredada y sus ID con la oferta observada en las trazas. En listas múltiples exige también coocurrencia. [Criterios de admisión](FUENTES.md#requisitos-de-varias-entregas--26-de-noviembre-de-2026).

Para contrastar si cada ID figura en el índice del cliente, guarda el [CSV QuestV2](https://wago.tools/db2/QuestV2/csv?build=1.60.1.71139) en la carpeta de fuentes y añade `--questv2 auditor_fase13/cache_fuentes/QuestV2-1.60.1.71139.csv`. El auditor verifica el hash y registra la fila del cliente y la evidencia del servidor en campos independientes.

El informe de experiencia compara un subtotal de entregas registradas con la curva documentada de `curva_xp_forever.json`. El campo `cobertura_xp_por_perfil` cuenta las entregas obligatorias que tienen una observación de XP compatible con la raza, la facción y el intervalo del tramo. Un catálogo adicional puede incluir estimaciones de combate por ruta y tramo en `xp_combates.<id de ruta>.tramos.<número de tramo>`, con `xp`, `estado` y `fuente`. Los tramos sin evidencia quedan pendientes y los subtotales se muestran como escenario, con el número de entregas cubiertas. El escenario cuenta una opción por grupo de misiones excluyentes en el orden de la ruta y desglosa la XP opcional de especialización de herrería, del bálsamo de Frondavil y de Kum'isha.

El manifiesto `SHA256_ORIGINALES.sha256` identifica los 219 archivos del commit de restauración 9.7.9. Sus rutas parten de la raíz del repositorio.

Ejecuta la regresión local con `auditor_fase13/.venv/Scripts/python.exe -B -m unittest discover -s auditor_fase13 -v`. Los escenarios de juego pendientes están en [VALIDACION_FOREVER.md](VALIDACION_FOREVER.md).

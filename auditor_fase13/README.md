# Auditor externo de Guía del Aventurero

El auditor toma la carpeta instalable como entrada. Lua 5.1 compila los módulos que declara el TOC, carga las rutas y ejecuta las funciones originales de selección, carga y filtrado racial con una API simulada. El entorno local sirve para verificar el código y los datos. Las comprobaciones del cliente quedan registradas por separado.

Con Python 3.11 o posterior, ejecuta estos comandos desde la raíz del repositorio en PowerShell:

```powershell
python -m venv auditor_fase13/.venv
auditor_fase13/.venv/Scripts/python.exe -m pip install -r auditor_fase13/requirements.txt
auditor_fase13/.venv/Scripts/python.exe auditor_fase13/auditar.py
```

La salida contiene `INFORME.md`, `resultados.json` y un informe por ruta en `rutas/`. El proceso devuelve `1` si encuentra errores y `2` si falla la lectura o la preparación de la salida. Usa `--addon` para auditar otra carpeta y `--salida` para guardar ejecuciones por separado. Las salidas por defecto y el entorno virtual permanecen fuera de los archivos versionados.

El bloque 2 genera también `misiones_individuales.json`, con un registro por ID, sus rutas y posiciones compartidas, evidencia por campo e indicios por contrastar. Las misiones de 9.7.9 retiradas de las rutas conservan sus fichas y el motivo. Los informes distinguen los pendientes de investigación de los que requieren ejecutar el cliente.

`--bloque` permite seleccionar uno o más ámbitos. La estructura siempre se comprueba porque los demás bloques dependen de las rutas cargadas. Usa `--catalogo` para aportar evidencia JSON adicional. `evidencia_forever.json` muestra ejemplos con fuente fechada y procedencia por campo. Las claves de misiones, mapas y PNJ son sus IDs como texto. Una ficha ausente deja la verificación pendiente.

`--trazas-questie` acepta una carpeta local con `foreverQuestTraces.lua`, `xpDB-traces.lua` y `uiMapIdToAreaId.lua` de QuestieDB 1.1.6. El auditor verifica los hashes y lee las filas de datos sin ejecutar esos módulos. La cobertura alcanza la existencia observada, los títulos EN presentes, la XP base registrada y los mapas canónicos de la build 1.60.1.69893. Las fichas confirmadas de `evidencia_forever.json` tienen prioridad sobre las trazas. El catálogo adicional puede aportar evidencia posterior por campo. Consulta [las fuentes y su alcance](FUENTES.md).

Con `--datos-questie`, guarda opcionalmente los [títulos esES heredados de Forever](https://raw.githubusercontent.com/Questie/QuestieDB/v1.1.6/l10n/Forever/lookupQuests/esES.lua) como `questie-forever-heredado-esES.lua` en `cache_fuentes/`. Para las misiones sin título español observado, `contraste_es_heredado` reúne el título de referencia y las etiquetas de ruta que difieren. La cobertura de títulos observados se calcula por separado.

`--datos-questie` añade `foreverBaseQuest.lua`, `foreverQuestFixes.lua` y `foreverQuestRelationTraces.lua` de esa misma revisión. Opcionalmente lee `questie-forever-quests-esES.lua` y `questie-forever-quests-esMX.lua` si están en la carpeta. Las relaciones inferidas se muestran por separado de los requisitos contrastados. Consulta los archivos y enlaces en [FUENTES.md](FUENTES.md).

`--datos-eg` incorpora los JSON de [EG Link](FUENTES.md#consultas-del-servidor-y-observaciones-de-efficient-games--26-de-noviembre-de-2026) y `QuestXP-1.60.1.71091.csv`. Guarda cada JSON como `eg-1.60.1.<compilación>-<dataset>.json` en `cache_fuentes/`. Los nombres, las compilaciones y los hashes están en `eg_link.py`. El bloque 5 genera también `vuelos_observados.json`. El cálculo de XP base completa huecos de la traza y conserva método y fuente. Las observaciones de entregas y de progreso siguen en sus propios campos.

```powershell
auditor_fase13/.venv/Scripts/python.exe -B auditor_fase13/auditar.py --trazas-questie auditor_fase13/cache_fuentes --datos-questie auditor_fase13/cache_fuentes
auditor_fase13/.venv/Scripts/python.exe -B auditor_fase13/agrupamientos.py --trazas-questie auditor_fase13/cache_fuentes --datos-questie auditor_fase13/cache_fuentes
```

Añade `--datos-eg auditor_fase13/cache_fuentes` cuando tengas la revisión de Efficient Games y la tabla de XP.

Puedes añadir las instantáneas de observación indicadas en `EXTRA_HASHES` de `eg_link.py`. El auditor conserva las coordenadas distintas por acción y las filas de entrega por compilación. Identifica las filas que la fuente registra en `withLegacy`. El cálculo de XP base usa los campos de dificultad y multiplicador. El informe conserva las referencias de cada compilación utilizada.

Las siete instantáneas de misión de la [revisión 71139 de Efficient Games](https://github.com/JIVESCORP/eg-link-output-wowf/tree/1339ce5600bbc2b12e8f1081e584f548f62fa57f/data/wowf/1.60.1.71139) usan el mismo patrón `eg-1.60.1.71139-<dataset>.json`. Con [QuestXP 71139](https://wago.tools/db2/QuestXP/csv?build=1.60.1.71139) en el archivo `QuestXP-1.60.1.71139.csv`, el auditor cita la tabla más reciente. Las tablas de XP 71091 y 71139 tienen el mismo SHA-256.

Los archivos `quest_scan` y `npcs` de 70790, 70862 y 70888 son opcionales y usan el mismo patrón. Amplían las muestras de PNJ y el historial de consultas sin respuesta. [Instantáneas y alcance](FUENTES.md#oferta-en-las-compilaciones-iniciales--26-de-noviembre-de-2026).

`interlocutores_observados` reúne iniciadores (`A`) y receptores (`T`) por misión, con el tipo de entidad, su ID y la compilación. Las coordenadas y los requisitos de la misión se consultan en sus propios campos. [Iniciadores y entregas](FUENTES.md#iniciadores-y-entregas-observados--26-de-noviembre-de-2026).

El [CSV QuestInfo de Forever 1.60.1.71091](https://wago.tools/db2/QuestInfo/csv?build=1.60.1.71091) es opcional. Guárdalo como `QuestInfo-1.60.1.71091.csv` junto a los JSON de Efficient Games. Con él, el auditor identifica las categorías expresas de élite, mazmorra, banda y JcJ. Los límites de tiempo se leen de las consultas de misión cuando incluyen ese dato.

Con `--datos-questie` y `--datos-eg`, puedes añadir dos fuentes opcionales para el contraste de relaciones. Guarda la [base Classic de QuestieDB 1.1.6](https://raw.githubusercontent.com/Questie/QuestieDB/v1.1.6/data/Classic/classicQuestDB.lua) como `classicQuestDB.lua` y las [correcciones heredadas por Forever](https://raw.githubusercontent.com/Questie/QuestieDB/v1.1.6/src/corrections/Forever/legacy/classicQuestFixes.lua) como `legacyForeverClassicQuestFixes.lua` en `cache_fuentes/`. El auditor verifica ambos hashes. Para los seguimientos cruza el enlace heredado, la sugerencia del servidor y el historial del sucesor. Para los requisitos de una sola entrega cruza la lista heredada con la observación de oferta en las trazas de QuestieDB.

Para contrastar si cada ID figura en el índice del cliente, guarda el [CSV QuestV2](https://wago.tools/db2/QuestV2/csv?build=1.60.1.71139) en la carpeta de fuentes y añade `--questv2 auditor_fase13/cache_fuentes/QuestV2-1.60.1.71139.csv`. El auditor verifica el hash y registra la fila del cliente y la evidencia del servidor en campos independientes.

El informe de experiencia compara un subtotal de entregas registradas con la curva documentada de `curva_xp_forever.json`. Un catálogo adicional puede incluir estimaciones de combate por ruta y tramo en `xp_combates.<id de ruta>.tramos.<número de tramo>`, con `xp`, `estado` y `fuente`. Los tramos sin evidencia quedan pendientes y los subtotales se muestran como escenario, con el número de entregas cubiertas. El escenario cuenta una opción por grupo de misiones excluyentes en el orden de la ruta y desglosa la XP opcional de especialización de herrería, del bálsamo de Frondavil y de Kum'isha.

El manifiesto `SHA256_ORIGINALES.sha256` identifica los 219 archivos del commit de restauración 9.7.9. Sus rutas parten de la raíz del repositorio.

Ejecuta la regresión local con `auditor_fase13/.venv/Scripts/python.exe -B -m unittest discover -s auditor_fase13 -v`. Los escenarios de juego pendientes están en [VALIDACION_FOREVER.md](VALIDACION_FOREVER.md).

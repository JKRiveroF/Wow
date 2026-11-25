# Auditor externo de Guía del Aventurero

El auditor toma la carpeta instalable como entrada. Lua 5.1 compila los módulos que declara el TOC, carga las rutas y ejecuta las funciones originales de selección, carga y filtrado racial con una API simulada. El entorno local sirve para verificar el código y los datos. Las comprobaciones del cliente quedan registradas por separado.

Desde la raíz del repositorio, en PowerShell:

```powershell
python -m venv auditor_fase13/.venv
auditor_fase13/.venv/Scripts/python.exe -m pip install -r auditor_fase13/requirements.txt
auditor_fase13/.venv/Scripts/python.exe auditor_fase13/auditar.py
```

La salida contiene `INFORME.md`, `resultados.json` y un informe por ruta en `rutas/`. El proceso devuelve `1` si encuentra errores y `2` si falla la lectura o la preparación de la salida. Usa `--addon` para auditar otra carpeta y `--salida` para guardar ejecuciones por separado. Las salidas por defecto y el entorno virtual permanecen fuera de los archivos versionados.

`--bloque` permite seleccionar uno o más ámbitos. La estructura siempre se comprueba porque los demás bloques dependen de las rutas cargadas. Usa `--catalogo` para aportar evidencia JSON adicional. `evidencia_forever.json` muestra ejemplos con fuente fechada y procedencia por campo. Las claves de misiones, mapas y PNJ son sus IDs como texto. Una ficha ausente deja la verificación pendiente.

`--trazas-questie` acepta una carpeta local con `foreverQuestTraces.lua`, `xpDB-traces.lua` y `uiMapIdToAreaId.lua` de QuestieDB 1.1.6. El auditor verifica los hashes y lee las filas de datos sin ejecutar esos módulos. La cobertura alcanza la existencia observada, los títulos EN presentes, la XP base registrada y los mapas canónicos de la build 1.60.1.69893. Las fichas confirmadas de `evidencia_forever.json` tienen prioridad sobre las trazas. El catálogo adicional puede aportar evidencia posterior por campo. Consulta [las fuentes y su alcance](FUENTES.md).

El informe de experiencia compara un subtotal de entregas registradas con la curva documentada de `curva_xp_forever.json`. Un catálogo adicional puede incluir estimaciones de combate por ruta y tramo en `xp_combates.<id de ruta>.tramos.<número de tramo>`, con `xp`, `estado` y `fuente`. Los tramos sin evidencia quedan pendientes y los subtotales se muestran como escenario, con el número de entregas cubiertas.

El manifiesto `SHA256_ORIGINALES.sha256` identifica los 219 archivos del commit de restauración 9.7.9. Sus rutas parten de la raíz del repositorio.

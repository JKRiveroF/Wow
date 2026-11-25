# Auditor externo de Guía del Aventurero

El auditor toma la carpeta instalable como entrada. Lua 5.1 compila los módulos que declara el TOC, carga las rutas y ejecuta las funciones originales de selección, carga y filtrado racial con una API simulada. El entorno local sirve para verificar el código y los datos. Las comprobaciones del cliente quedan registradas por separado.

Desde la raíz del repositorio, en PowerShell:

```powershell
python -m venv auditor_fase13/.venv
auditor_fase13/.venv/Scripts/python.exe -m pip install -r auditor_fase13/requirements.txt
auditor_fase13/.venv/Scripts/python.exe auditor_fase13/auditar.py --bloque 1
```

La salida contiene `INFORME.md`, `resultados.json` y un informe por ruta en `rutas/`. El proceso devuelve `1` si encuentra errores y `2` si falla la lectura o la preparación de la salida. Usa `--addon` para auditar otra carpeta y `--salida` para guardar ejecuciones por separado. Las salidas por defecto y el entorno virtual permanecen fuera de los archivos versionados.

El manifiesto `SHA256_ORIGINALES.sha256` identifica los 219 archivos del commit de restauración 9.7.9. Sus rutas parten de la raíz del repositorio.

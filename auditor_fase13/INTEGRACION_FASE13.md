# Integración de la fase 13 en Guía del Aventurero 9.8.0

## Candidata 9.8.0 para pruebas

La comparación de tres vías parte de la versión original 9.7.9 (`592d887`), la fase 13 con preparación local cerrada (`c63c86d`) y el ZIP 9.7.9.9 aportado por JKRiveroF con las mejoras de Claude y ChatGPT. El ZIP de entrada tiene SHA-256 `405c07e7067b372a1f3fa5d1e9cc496b580a9955981f473af4b2589dbe38497c`. [Inventario de entradas y hashes](entradas_integracion_980.json).

- El paquete combinado contiene **221 archivos**. Conserva las **47 rutas de la fase 13 byte a byte** y añade los tres módulos de idioma de 9.7.9.9 al TOC. Importa los cambios exclusivos de ambos cortes y actualiza el TOC, el historial y la documentación a 9.8.0 candidata.
- Siete archivos cambiaron en ambos cortes. `GuiaAventurero.lua` conserva los estados confirmados del diario y los límites por localidad de 9.7.9.9. También incorpora el avance por alternativa de la fase 13 cuando la misión principal consta como inactiva y reconoce vuelos guardados en otro idioma. `Idioma.lua` conserva la presentación de la zona de navegación y separa el PNJ por el último grupo de paréntesis, incluidos nombres con paréntesis anidados. Los otros cinco archivos se combinaron sin conflictos de texto.
- El paquete `GuiaAventurero-9.8.0-fase13-integracion.zip` pasó la instalación aislada en limpio y sobre 9.7.9 y 9.7.9.9. El auditor verificó el contenido y el ensayo conservó los datos guardados de prueba. Los seis casos reales usan la misma huella e instalación. [Medición](progreso_medicion.json) · [Protocolo para Forever](VALIDACION_FOREVER.md#protocolo-reducido-de-cierre-funcional).

| Identificador de la candidata | SHA-256 |
| --- | --- |
| ZIP | `15e7b038e77b4c1f93b73cb4daa11ac50f005bd04fa74ea713ba74439dddd33a` |
| Huella funcional del contenido para registrar pruebas reales | `6d4230dbee4684952c34d2cec253c45873d8b16309d774d849cc7b89673db629` |

Desde la raíz del clon actualizado, se reproduce el paquete con el siguiente comando. [Entorno del auditor](README.md).

```powershell
auditor_fase13/.venv/Scripts/python.exe -B auditor_fase13/auditar.py --empaquetar --integracion --salida auditor_fase13/salida/integracion-980
```

## Paquete anterior de la fase 13 sobre 9.7.9

`GuiaAventurero-9.7.9-fase13-integracion.zip` contiene 218 archivos bajo `GuiaAventurero/`. La versión interna sigue siendo 9.7.9 en este paquete de integración. La versión 9.8.0 corresponde al corte combinado posterior.

| Verificación | Valor |
| --- | --- |
| SHA-256 del ZIP de integración | `7ed7ccdac59bd450b6e043cf6b915b8725413020582ea3c45dbfce4689e10df2` |
| Huella funcional de la carpeta | `a655f6d428af8ef2a1fada84f9995c83aafabf61139a8c351ed6c715ffe1b11e` |
| SHA-256 del ZIP original 9.7.9 | `00e57a7bb485c45f4fdb8f3455147c1ff4d44812c538543d989b4608a2e413ae` |

En este equipo el paquete anterior está en `auditor_fase13/salida/integracion-fase13/`. Se puede reproducir recuperando el corte `c63c86d` en un directorio independiente. La huella de los 218 archivos identifica ese corte en cualquier equipo. [Preparación del entorno](README.md).

```powershell
auditor_fase13/.venv/Scripts/python.exe -B auditor_fase13/auditar.py --empaquetar --integracion --salida auditor_fase13/salida/integracion-fase13
```

La instalación local se ensayó en una carpeta vacía y sobre una extracción del ZIP base. Se verificaron CRC, huella de los archivos instalados, TOC, carga Lua de las 47 rutas, 56 perfiles y conservación del archivo de datos guardados de la prueba. La migración y Questie tienen pruebas independientes con API simuladas. El ZIP original y su manifiesto siguen conservados. [Manifiesto original](SHA256_ORIGINALES.sha256) · [Pruebas de preparación](test_preparacion_funcional.py).

## Archivos modificados respecto a 9.7.9

El corte anterior de la fase 13 cambió 58 archivos instalables, todos existentes en la base. Los cambios de auditoría se encuentran fuera de `GuiaAventurero/`.

| Archivos relativos a `GuiaAventurero/` | Puntos que revisar al integrar |
| --- | --- |
| `GuiaAventurero.lua` | Equivalencias de misión en `DestinoHecho` y reconocimiento bilingüe de vuelos en `VueloConocido`. |
| `Datos94.lua` | Misiones raciales de sacerdote y coordenadas de maestros de vuelo. |
| `Idioma.lua`, `Idioma/enUS_Datos.lua`, `Idioma/enUS_Interfaz.lua`, `Idioma/enUS_Refuerzos97.lua`, `Idioma/enUS_Rutas.lua` | Localización ES/EN. Comparar claves, títulos y textos de los pasos que también cambien en las otras mejoras. |
| `Opcionales.lua`, `OpcionalesKalimdor.lua`, `OpcionalesOtras.lua`, `OpcionalesReinos.lua` | Misiones opcionales, variantes y requisitos. Comparar los cambios por ID, perfil y destino. |
| `Rutas/*.lua` (47 archivos) | Cadenas y alternativas, información de misión y coordenadas revisadas, opcionales, desbloqueos e instrucciones de leveo. Comparar los pasos por misión, mapa y perfil. |

Para obtener los 58 nombres exactos o el parche de código y datos, compara la base con el árbol de la fase 13. Estos comandos son de consulta.

```powershell
git diff --name-status 592d887:GuiaAventurero 0943970674fd6b48c0a84a09cd2a9cb35ffdab8e
git diff 592d887:GuiaAventurero 0943970674fd6b48c0a84a09cd2a9cb35ffdab8e
```

Para consultar los cambios de la candidata respecto al corte anterior de la fase 13, ejecuta `git diff c63c86d HEAD -- GuiaAventurero` desde la rama de desarrollo. El manifiesto de 9.7.9 sigue siendo la referencia de restauración.

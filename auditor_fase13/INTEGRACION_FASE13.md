# Integración de la fase 13 en Guía del Aventurero 9.8.0

La integración parte de la versión 9.7.9 registrada en `592d887a021ec136696e460895630982737fec95`. El árbol instalable de la fase 13 preparado para incorporar es `0943970674fd6b48c0a84a09cd2a9cb35ffdab8e`. Los seis casos reales se ejecutarán sobre la futura 9.8.0 con todas las mejoras de Claude y ChatGPT incorporadas. [Protocolo reducido](VALIDACION_FOREVER.md#protocolo-reducido-de-cierre-funcional).

## Paquete de integración

`GuiaAventurero-9.7.9-fase13-integracion.zip` contiene 218 archivos bajo `GuiaAventurero/`. La versión interna sigue siendo 9.7.9 en este paquete de integración. La versión 9.8.0 corresponde al corte combinado posterior.

| Verificación | Valor |
| --- | --- |
| SHA-256 del ZIP de integración | `7ed7ccdac59bd450b6e043cf6b915b8725413020582ea3c45dbfce4689e10df2` |
| Huella funcional de la carpeta | `a655f6d428af8ef2a1fada84f9995c83aafabf61139a8c351ed6c715ffe1b11e` |
| SHA-256 del ZIP original 9.7.9 | `00e57a7bb485c45f4fdb8f3455147c1ff4d44812c538543d989b4608a2e413ae` |

En este equipo el paquete está en `auditor_fase13/salida/integracion-fase13/`. En otro equipo, desde la raíz del clon con el entorno del auditor instalado, el siguiente comando reproduce el paquete y verifica el contenido. El SHA-256 del contenedor depende de la implementación de compresión. La huella de los 218 archivos identifica el corte en cualquier equipo. [Preparación del entorno](README.md).

```powershell
auditor_fase13/.venv/Scripts/python.exe -B auditor_fase13/auditar.py --empaquetar --integracion --salida auditor_fase13/salida/integracion-fase13
```

La instalación local se ensayó en una carpeta vacía y sobre una extracción del ZIP base. Se verificaron CRC, huella de los archivos instalados, TOC, carga Lua de las 47 rutas, 56 perfiles y conservación del archivo de datos guardados de la prueba. La migración y Questie tienen pruebas independientes con API simuladas. El ZIP original y su manifiesto siguen conservados. [Manifiesto original](SHA256_ORIGINALES.sha256) · [Pruebas de preparación](test_preparacion_funcional.py).

## Archivos modificados respecto a 9.7.9

Hay 58 archivos instalables modificados, todos existentes en la base. Los cambios de auditoría se encuentran fuera de `GuiaAventurero/`.

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

Para detectar coincidencias con el corte de Claude y ChatGPT, compara ambos conjuntos de cambios desde el mismo origen 9.7.9. Revisa primero los archivos instalables modificados en ambos cortes y conserva los cambios compatibles de cada uno. Usa el ZIP como referencia del contenido de la fase 13 y el diff para incorporar sus cambios. Al asignar la versión combinada, actualiza las expectativas de regresión que fijan la versión y el alcance de los cambios. Conserva el manifiesto de 9.7.9 como referencia de restauración. Ejecuta la regresión del corte combinado, empaquétalo y registra su nueva huella para la sesión en Forever.

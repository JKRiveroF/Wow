# Guía del Aventurero para WoW Forever

## Ramas y versiones

- Conserva en `main` el último corte aprobado. El punto de partida es el respaldo original 9.7.9 del commit `592d887`, con su ZIP y sus notas de prueba. La primera versión estable se identificará tras la validación en Forever.
- Crea cada rama `version-<versión>` desde la punta de `main`. Desarrolla, empaqueta y ejecuta las pruebas de esa versión en su propia rama.
- Actualiza `main` mediante el merge de la rama de versión, después de superar la regresión local y la validación en WoW Forever y de contar con autorización para integrar. Etiqueta el corte aprobado como `v<versión>` para conservar una referencia de respaldo al comenzar la siguiente versión.
- Usa `JKRiveroF` en los commits. La publicación de Releases requiere autorización expresa.

## Addon instalable

- El TOC de `GuiaAventurero/` fija la versión y el orden de carga. Mantén las novedades en español e inglés y empaqueta únicamente la carpeta del addon.
- Conserva los datos guardados, la compatibilidad con Questie y las rutas y traducciones verificadas al introducir mejoras.
- Registra por separado los resultados del análisis local, las simulaciones y las comprobaciones reales en el cliente.

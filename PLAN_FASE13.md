# Plan de la fase 13 · Auditoría de leveo

## Preparación

- [x] Verificar la base 9.7.9, su estructura, el ZIP y las herramientas locales.
- [x] Crear el commit inicial local con los originales y activar `fase-13-auditoria-leveo`.
- [x] Inventariar las 47 rutas, guardar los SHA-256 y preparar `auditor_fase13/`.
- [x] Registrar las instrucciones permanentes y el avance de la preparación.

## Desarrollo pendiente

- [ ] Definir las entradas del auditor, las reglas de comprobación y el formato del informe. Usar el TOC de la 9.7.9 y las 47 rutas inventariadas como alcance inicial.
- [ ] Implementar el auditor en `auditor_fase13/` con lectura del addon y comprobaciones de registro, carga y selección de rutas por facción, raza y clase.
- [ ] Comprobar las secciones de nivel y los datos de los pasos. Revisar los campos de mapa y coordenadas, los IDs de misión y la secuencia de aceptar, cumplir objetivos y entregar, teniendo en cuenta las misiones de clase, las cadenas y las ramas de ruta.
- [ ] Identificar las transformaciones que aplican los módulos compartidos a la ruta activa y determinar qué reglas deben comprobarse después de aplicarlas.
- [ ] Determinar si la auditoría requiere ejecutar Lua. Si hace falta, comprobar la disponibilidad de un intérprete compatible antes de ejecutar las pruebas que lo usen.
- [ ] Ejecutar el auditor sobre las 47 rutas, revisar los hallazgos y registrar evidencias y limitaciones en `PROGRESO_FASE13.md`. Volver a comparar los originales con `auditor_fase13/SHA256_ORIGINALES.sha256`.
- [ ] Validar en WoW Forever los hallazgos que dependan del cliente y registrar la versión del cliente, la ruta usada y el resultado observado.

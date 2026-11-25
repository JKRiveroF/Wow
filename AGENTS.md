# Guía del Aventurero para WoW Forever

## Base del proyecto

- La única base autorizada para la fase 13 es la versión 9.7.9 de la Guía del Aventurero, que incorpora las fases 1 a 12. El commit inicial `592d887a021ec136696e460895630982737fec95` conserva la distribución original.
- El addon instalable está en `GuiaAventurero/`. El ZIP `GuiaAventurero-9.7.9.zip` conserva el paquete original. Usa `auditor_fase13/SHA256_ORIGINALES.sha256` para verificar la integridad de ambos desde la raíz del repositorio.
- Trabaja en Git local. No publiques ni subas archivos a GitHub ni a otros servicios externos salvo que el responsable lo solicite explícitamente.

## Auditoría de leveo

- Trabaja en la rama `fase-13-auditoria-leveo` durante la fase 13. Desarrolla el auditor y guarda su inventario y sus resultados en `auditor_fase13/`, fuera del addon instalable.
- Durante la preparación y la auditoría, trata la distribución original como entrada de solo lectura. Aplica correcciones al addon cuando el responsable autorice esa etapa.
- Usa `GuiaAventurero/GuiaAventurero.toc` como referencia del conjunto y orden de carga. Identifica las rutas por su ID y conserva los tokens originales de clase, raza y facción al documentarlas.
- Registra cada hallazgo con la ruta del archivo, el ID de ruta cuando corresponda y la ubicación de la evidencia. Distingue las comprobaciones estáticas, las ejecuciones locales con intérprete y las pruebas en WoW Forever.
- Mantén `PLAN_FASE13.md` al día con los próximos trabajos y `PROGRESO_FASE13.md` con las operaciones ejecutadas, sus resultados y los bloqueos comprobados.

## Correcciones, validación y sincronización de la fase 13

- Completa la auditoría estructural inicial antes de editar las rutas. En la rama de desarrollo, corrige únicamente errores concretos con evidencia local reproducible o fuentes fiables. Conserva los datos de Forever cuya corrección siga pendiente de confirmar.
- Conserva las mejoras de las fases 1 a 12, los datos guardados, la compatibilidad con Questie y los textos en español e inglés. Mantén las ventanas, los atajos, los mapas y las posiciones confirmadas de jefes. Justifica cualquier cambio fuera de las rutas.
- Registra la fuente y la fecha de cada verificación externa. Identifica los datos confirmados para Forever, los de Classic compatibles con la evidencia disponible, las contradicciones y las comprobaciones pendientes, incluidas las que requieren jugar en Forever.
- Crea commits descriptivos con el nombre `JKRiveroF` al cerrar trabajo verificado y sincroniza exclusivamente `fase-13-auditoria-leveo` con `origin`. Conserva el commit de restauración y el historial. Mantén `main`, las ramas y etiquetas anteriores, la visibilidad, permisos y seguridad del repositorio.
- Prepara el ZIP definitivo al cerrar la fase local. La fusión y la publicación de versiones requieren autorización expresa. Mantén `auditor_fase13/` fuera del paquete distribuible.

# Validación pendiente en WoW Forever

Registra la compilación e interfaz del cliente, idioma del cliente y de la guía, ID de ruta, clase, raza, facción, nivel y resultado observado. Usa una copia de los datos guardados para las pruebas de migración. Registra evidencia por ruta en `PROGRESO_FASE13.md`.

| Comprobación | Evidencia requerida |
| --- | --- |
| Arranque y selección | La guía carga la ruta correcta para las 56 combinaciones del inventario. Selecciona un tramo adecuado al nivel y conserva sección, paso y destino al recargar. |
| Questie, mapas y flecha | Con y sin Questie, registra las marcas visibles y el destino activo. Confirma que ambas guías pueden convivir y que los mapas de jefes y sus marcas coinciden con la base. |
| Misión 3520 | Verifica aceptación y entrega en Puerto Bonvapor. Registra mapa y posición de varios estriadores en la costa de la Isla del Terror. Confirma progreso y entrega en ambos idiomas. |
| Misión 1878 y experiencia | Registra la XP efectiva de la primera entrega 1707 y de la repetible 1878. Empieza un tramo al nivel recomendado, anota XP inicial, descanso, entregas y combates, y compara el resultado con la curva de la compilación. |
| Vuelos y viajes | Prueba un guardado ES en cliente EN y el caso inverso. Comprueba que un nodo desconocido no completa el paso. Confirma posiciones de Dungar y Ariena y cronometra los cambios de ruta candidatos, incluyendo accesos, esperas, vuelos y piedra de hogar. |
| Agrupamientos | En Desolace, el Pantano de las Penas y Los Baldíos, prueba ambos órdenes de los objetivos con las dos misiones aceptadas. Registra tiempo desde el mismo inicio al mismo destino, accesibilidad, patrullas y esperas. En Los Baldíos, anota además cuándo recoges la piedra y cuánto tiempo le queda al llegar al altar. [Ventanas y rutas](AGRUPAMIENTOS_FASE13.md). |
| Perfiles y raciales | Verifica el acceso de los Skyborne de ambas facciones y los efectos de Skysight, Charged, Read Leyline y Attuned en el cliente. Registra la duración de Skysight, la entrega de Camping 101: Herbalism en Shen'dar y los desbloqueos dependientes de clase o raza. |
| Cadena opcional de Kum'isha | Comprueba la oferta desde Magtoor en ambas facciones y registra la recogida de 93465 con Azore. Comprueba los umbrales de 30 y 45, la visión de Onku, la entrega al reconectar en otro continente y el tiempo entre Magtoor, Azore y Kum'isha. |
| Ivar y formas de druida | Comprueba el avance de 91920 con y sin los tres ojos en el inventario, la entrega de la poción y la oferta de Ivar. Verifica 26 para el elfo de la noche y 27 para el tauren. Recorre la entrega de 98393 antes de los pasos de Forma felina para el elfo y el Skyborne de Alianza. |
| Herrería y guerrero | Registra qué variante ofrece Okothos a cada clase Horda y el nivel de Herrería al aceptarla. Con enano y gnomo, comprueba la entrega de las notas a Klockmort antes de visitar Menethil, la ubicación de los depósitos y la entrega de 1709. |
| Forma acuática de Skyborne | Empieza a nivel 16 como druida de cada facción. Confirma los plazos del lago y del adorno, la posición de los arcones, el desbloqueo del hechizo y el coste de recoger las mitades en viajes de la ruta. |
| Traición en Azshara | Comprueba la oferta de la carta 3504, la entrega en el tomo kaldorei y las tres patrullas. Registra cómo se activan los cristales y la secuencia de entrega 91500 y 91531. |
| Oferta y eventos | Registra el caldero 5227 tras completar su cadena, la primera XP y la XP de un canje posterior. Consulta la matriz de oferta para los demás IDs. |
| Etiquetas de destino | Antes y después de aceptar una misión de élite, mazmorra o banda, revisa las etiquetas ES/EN y el tamaño recomendado cuando responda el cliente. Comprueba también una misión normal y una tarjeta de mazmorra opcional. |
| Prerrequisitos de ruta | En Menethil, comprueba 473 a nivel 23 con y sin 455 entregada. Con Guerrero de la Horda, entrega 1838 y 1848 antes de pedir el encargo de Orm. Con Mago de la Horda, visita a Deino, entrega 1947 y verifica la obtención, carga y entrega de la zarza de 1948. |
| Canje 8941 | Con un pícaro de la Horda de nivel 58 o superior, comprueba la oferta después de 8978, el canje de las dos piezas Oficioscuro y la oferta posterior de 8930. Registra la XP efectiva y el nivel al entregar. |
| Comportamiento anterior | Abre guía, talentos, equipo, misiones, profesiones y secciones de mapas con datos previos de 9.7.9. Verifica los textos ES/EN y registra cualquier error de arranque, selección o traducción. |

Los resultados de las pruebas simuladas quedan en las pruebas del auditor. El estado de cada comprobación de esta tabla sigue pendiente de observación en el cliente.

## Protocolo reducido de cierre funcional

Usa el ZIP de la candidata 9.8.0, que reúne la fase 13 y las mejoras de la 9.7.9.9. Registra los seis casos contra la misma huella del addon integrado, calculada por el auditor. Puedes usar personajes existentes de ambas facciones. Guarda una copia de `Interface/AddOns/GuiaAventurero` y de sus `SavedVariables` con el juego cerrado. Para la prueba de actualización, sustituye únicamente la carpeta del addon y abre el cliente con una copia válida de los datos previos. Anota con cada caso la compilación, idioma, ruta, facción, raza, clase, nivel y resultado. Una captura o una secuencia breve de acciones y resultados sirve como evidencia. [Paquete y huella](INTEGRACION_FASE13.md#candidata-980-para-pruebas).

| Caso | Perfil y pasos | Resultado que hay que observar |
| --- | --- | --- |
| `instalacion_migracion` | Instala el candidato primero con datos limpios. Repite sobre una copia de 9.7.9 con ruta, sección, paso, destino y preferencias ya guardados. Reinicia el cliente. | Arranque en ambos casos, conservación de posición y preferencias, persistencia de nuevos cambios y ausencia de errores Lua. |
| `alianza_inicio` | En esES, usa una ruta Alianza entre niveles 1 y 15. Comprueba selección automática, tramo y una secuencia de aceptar, completar y entregar. | Ruta, nivel, instrucciones y avance correctos. Un perfil incompatible queda fuera de la secuencia. |
| `horda_inicio` | En enUS, usa una ruta Horda entre niveles 1 y 15 con raza y clase diferentes a la muestra de Alianza. Repite la secuencia básica y revisa un texto específico de clase. | Ruta, idioma, filtro y avance correctos. |
| `mapa_questie` | Prueba un destino de misión y una transición de mapa con Questie y después sin Questie. Abre la guía y el mapa y sigue un destino confirmado. | Marcador y flecha apuntan al mismo destino. Questie conserva sus propias misiones, y la guía actualiza sus marcas al cambiar de zona. |
| `nivel_viaje` | Entre niveles 17 y 44, usa «Mi nivel» y verifica un vuelo disponible de tu facción. Prueba también un nodo aún no descubierto y omite un paso opcional sin oferta. Si usas una de las 14 rutas corregidas en la Sierra Espolón, prueba la cadena con 1070 y el avance al omitirla. | Tramo correcto, transición practicable, nodo desconocido sin falsa finalización y recorrido capaz de continuar. |
| `desbloqueos_clase` | En un tramo de nivel 45 a 60, comprueba selección y progreso. Con ese personaje u otro que tenga acceso, verifica un desbloqueo esencial de clase, como forma, mascota, hechizo aprendido por misión o por instructor. Compara el libro antes y después cuando sea posible. | La guía conduce al aprendizaje o a una alternativa válida. El paso se puede continuar al cumplir la condición real y muestra instrucciones correctas. |

En `instalacion_migracion`, repite la actualización con una copia de los guardados de 9.7.9.9 si están disponibles. Cambia el idioma en vivo, abre el tutorial y prueba el regreso desde la ventana grande a la compacta. En `mapa_questie`, comprueba que la posición de ruta se conserva durante una transición y que la guía respeta las marcas y selecciones ajenas. En `nivel_viaje`, incluye un guardado de vuelos de otro idioma y comprueba el regreso de pesca a las armas y volúmenes previos si usas ese modo. Anota los fallos de interfaz, automatismos en combate o recuperación tras muerte con la acción que los reproduce.

Los seis casos son obligatorios para el indicador funcional. Las matrices de certificación siguientes conservan el trabajo de investigación y las comprobaciones detalladas por misión. [Formato de registro](README.md#registro-de-pruebas-funcionales).

Si tienes un no-muerto paladín de nivel inicial, aprovecha la prueba Horda para comprobar cuándo aparece Luz Sagrada (635) durante 90902. Si pruebas un enano chamán en el tramo intermedio, anota cuándo aparece 5394 respecto de 94505. Para 18960, el libro de hechizos permite distinguir el instructor de las cuatro entregas de druida de la matriz. Conserva estas observaciones con el ID de misión y de hechizo.

## Nodos y conexiones de vuelo

En esES, abre el mapa de vuelo con Shardi, Brakkar y Thalon. Registra el nombre y estado que devuelve el cliente. Comprueba que el paso que verifica Juncobrezo, Sangrevenenosa o Sombraprensa se completa tras guardar el nodo. Verifica el acceso a Gadgetzan y Theramore con Alianza y al Puesto del Veneno con Horda. Para una conexión con escalas, anota sentido, compilación, talento, precios y tiempo. [Nodos, nombres y observaciones](FUENTES.md#nodos-y-conexiones-de-vuelo).

## Aprendizaje de habilidades por misión

Compara el libro de hechizos antes de aceptar y tras aceptar y entregar el encargo. En cazador, comprueba Llamar y Retirar mascota al entregar la tercera doma, y Alimentar, Revivir y Adiestramiento tras la entrega final. En pícaro, anota el rango inicial de Venenos y la aparición de la receta 8681 al entregar 2359 o 2480.

| Misión declarada | Hechizo | Vía | Evidencia pendiente |
| ---: | ---: | --- | --- |
| 5921 | 18960 | Cliente | Con elfo de la noche, revisa el libro antes y después del instructor, de entregar 5925 y de aceptar 5921. |
| 5922 | 18960 | Cliente | Con tauren, revisa el libro antes y después del instructor, de entregar 5928 y de aceptar 5922. |
| 7463 | 10140 | Cliente | Tras la entrega, confirma el ID que aprende el mago y que el efecto se aplica al personaje. |
| 9364 | 28272 | Cliente | Tras la entrega, confirma el ID que aprende el mago y que el efecto se aplica al personaje. |
| 90902 | 635 | Cliente | Comprueba Luz Sagrada al aceptar, antes de empezar a curar y tras la entrega. |
| 94505 | 5394 | Cliente | Comprueba el libro del chamán antes de aceptar y tras la entrega. Registra el ID aprendido. |
| 94911 | 18960 | Cliente | Con Skyborne Horda, revisa el libro al hablar con el instructor, al entregar 94911 y al aceptar 94913. |
| 94912 | 18960 | Cliente | Con Skyborne Alianza, revisa el libro al hablar con el instructor, al entregar 94912 y al aceptar 94914. |

Registra el momento del aprendizaje y el ID observado. [Distinción y fuentes](FUENTES.md#aprendizaje-por-misión--26-de-noviembre-de-2026).

## Ofertas y restricciones de clase

Compara personajes de igual facción y nivel que cumplan los mismos requisitos de raza, profesión, objetos y entregas previas. Registra el ID que ofrece el iniciador a cada clase. Para 8249, lleva cinco cajas de trastos pesadas (16885) con pícaro y con otra clase a partir de nivel 50 cuando el canje esté disponible. Para 5126, parte de nivel 55 y compara herreros con Herrería 270 o superior en una de las tres clases de la referencia heredada y en otra clase. Para 98341 y 98738, registra la oferta con druida Skyborne de cada facción antes y después de la etapa anterior. Mantén separada la variante estacional 8767/8788. [Contraste y fuentes](FUENTES.md#categorías-y-máscaras-de-clase--26-de-noviembre-de-2026).

## Destinos reubicados en mapas de zona

Para 1486, registra el UiMapID y la posición al encontrar a Nalpak en las Cuevas de los Lamentos y comprueba la entrada, la aceptación y la entrega. Para 6563, registra la entrada a Cavernas de Brazanegra, el UiMapID activo dentro de la cueva y el punto donde aumenta el contador del objetivo. [Origen y conversión de las muestras](FUENTES.md#posiciones-de-entidades-de-objetivo--26-de-noviembre-de-2026).

En los destinos con `referencias_interaccion`, registra por separado el ID de la entidad, la posición que muestra el mapa y el ID de la misión ofrecida o entregada. En los vínculos de catálogo que sigan sin oferta documentada, comprueba 977 con el PNJ 10305 y 3503 con el PNJ 8395 como casos compartidos por las rutas. Conserva la distinción entre la interacción de cada misión y la mera presencia de la entidad. [Fuentes de los vínculos](FUENTES.md#coordenadas-de-iniciadores-y-receptores).

Para 92553, registra el botín de 6889 en la criatura 251291 cerca de 39,9 / 54,3 y comprueba por separado la obtención de 5469 en la criatura 251661 con la misión activa. Anota el punto y el avance de cada contador. Para 4289, registra la obtención de 11478 en la criatura 6514 y distingue su posición de las de 11479 y 11480. [Botín y posiciones observadas](FUENTES.md#botín-con-misión-activa).

Para 2781, registra el botín de 8723 al derrotar a 7847 en Tanaris y la posición del encuentro. En 8466 y 8467, registra la obtención de 21377 con cada misión activa, el punto de botín y cualquier cambio tras la primera entrega. [Observaciones de origen y posición](FUENTES.md#botín-observado-en-efficient-games).

Para 86 y 385, registra por separado los objetos obtenidos y la posición real de la criatura. En 385, comprueba el origen de 2925 con la misión activa después de verificar 2924. [Referencias por entidad](FUENTES.md#botín-observado-en-efficient-games).

### Botín en Feralas y Un'Goro

| Misiones | UiMapID y marcador de la guía | Comprobación compartida |
| --- | --- | --- |
| 2855–2859 | Feralas, 1444, 60,2 / 68,7 | Registrar si se obtiene 8153 de un Gordunni 5236, 5238 o 5239, o del nodo 142140 con el oficio pertinente. Anotar entidad, método, punto y cantidad. Un registro de obtención permite contrastar el origen en los cinco encargos de Peletería. |
| 4148 y 5150 | Cráter de Un'Goro, 1449, 66 / 16,5 | Buscar la planta 164958 y registrar la obtención de 11315 y el avance. Repetir con cada misión activa si cambia el avance. El origen observado es la planta. |

Registra la compilación y el UiMapID que muestra el juego junto a la entidad, el objeto y las coordenadas. Si solo encuentras el objeto en otro lugar, anota el hallazgo con su posición. [Alcance de las observaciones archivadas](FUENTES.md#botín-registrado-por-jugadores).

### Cadena de la Sierra Espolón

Con un personaje de la Alianza desde nivel 17, acepta 1070 de la centinela Thenysil en Astranaar y entrégala a Kaela en la Sierra Espolón. Acepta 1085 de Kaela y entrégala a Gaxim. Registra los cuatro IDs y acciones en la guía y el cliente, y comprueba el avance al omitir el paso opcional en una ruta que no pasa por Astranaar. [Condiciones y posiciones](FUENTES.md#dos-condiciones-de-entrega).

## Matriz de oferta pendiente por misión

Los 24 ID carecen de oferta acreditada en el inventario. Las condiciones de partida y los materiales proceden de las fichas de referencia y de la base heredada. Registra el ID que ofrece el iniciador, el perfil y los requisitos cumplidos. [Evidencia disponible y límites](FUENTES.md#oferta-en-las-compilaciones-iniciales--26-de-noviembre-de-2026).

5201, 6848, 8319, 8353, 8355, 8356, 8863 y 9266 carecen de registro en los tres escaneos iniciales y de fila en QuestV2 de 71139. Los otros 16 aparecen como consultas sin respuesta en las tres compilaciones iniciales.

Para 6804, 6805 y 6821, registra la lista de ofertas del duque 13278 en una misma visita por perfil y compilación. Comprueba primero si ofrece 6804 y 6805. Si se habilitan, vuelve después de cada entrega para comprobar 6821. Los informes 70959 y 71037 documentan visitas sin las dos primeras ofertas. Registra la fase y el estado de las misiones previas. [Contraste de ofertas](FUENTES.md#ofertas-de-hydraxis-arantir-y-belgrom).

El calendario extraído sitúa el Festival de Invierno del 15 de diciembre de 2026 al 2 de enero de 2027, el Festival Lunar del 2 al 16 de febrero de 2027 y el próximo Halloween del 18 de octubre al 2 de noviembre de 2027. Comprueba la ventana al empezar la prueba. [Calendario de WoW Forever DB](https://wowfdb.com/events/).

| ID | Rutas | Vía prioritaria | Comprobación pendiente |
| ---: | ---: | --- | --- |
| 1374 | 32 | Investigar oferta | Uthek ofrece 1373 y el servidor propone 93034 como continuación. Tras entregar 1373, registra si ofrece 1374 y si exige los 3.000 puntos heredados. Comprueba por separado 93044 → 93045 y el acceso a 93128 con el mismo personaje. |
| 1375 | 34 | Investigar oferta | Con Warug, tras 1371 y con 3.000 puntos Magram, comprueba si ofrece Khan Shaka (1375). Para Khan Jehn (93196) comprueba la oferta con Orgrul tras 93188 y el ritual con el objeto 257517. |
| 2358 | 4 | Cliente con un pícaro de la Alianza | Repite la visita a la Sombra de Arantir (7009) tras entregar 2282 en la compilación actual. Compara un gnomo de nivel 20 con otro perfil de pícaro. Si aparece la oferta, registra el nivel, el objeto 7906 y el acceso para Skyborne. |
| 3504 | 22 | Cliente con un personaje Horda | Comprueba si Belgrom (4485) ofrece la carta en la compilación actual. Ag'tor ya tiene ofertas observadas de 3505 sin 3504 aceptada ni entregada. Verifica si existe alguna variante que aún ofrezca la carta. |
| 5201 | 24 | Investigar oferta | Comprueba a Rivern con Alianza desde nivel 58 antes y después de entregar 4970. Compara por debajo y a partir de 1.500 puntos con los Instructores de Sableinvernales, el umbral heredado. Si aparece 5201, registra si pide cinco chamanes y cinco ursas Nevada y vuelve a ofrecerse. |
| 6804 | 47 | Cliente con Hydraxis | Comprueba a Hydraxis desde nivel 55. Si la ofrece, registra cuándo entrega el Aspecto de Neptulon (17310) y si conserva el objetivo de 12 brazales (17309). |
| 6805 | 47 | Cliente con Hydraxis | Comprueba a Hydraxis desde nivel 55, con y sin 6804 aceptada o entregada. Registra si ofrece 6805 y pide 15 elementales de cada tipo. |
| 6821 | 47 | Cliente tras habilitar las dos primeras ofertas de Hydraxis | Comprueba a Hydraxis desde nivel 56, con cada entrega anterior por separado y tras completar 6804 y 6805. Registra si pide el ojo 17322, si procede del Piroguardián brasadivino y si la entrega ofrece 6822. |
| 6848 | 1 | Investigar oferta | En Valle de Alterac, busca al PNJ 13151 con Alianza y Horda. Distingue 6848 de la variante 6847 de la Horda en la base heredada. Registra el ID de oferta y la posición del ojo en las cuevas de los Hacha Invernal. |
| 7622 | 3 | Cliente con objeto de banda | Con sacerdote al nivel 60, comprueba cómo se consigue el Ojo de la Divinidad en Forever. Equípalo, busca a Eris y registra la oferta y el resultado del reto de los campesinos. |
| 8319 | 46 | Investigar oferta | Tras 8318, comprueba si Bor ofrece el canje de diez textos 20404 y vuelve a ofrecerlo después de entregarlo. Identifica al receptor 15306 para distinguirlo de 8324, el canje ya observado con Ortell. |
| 8353 | 1 | Cliente durante Halloween | Con 8311 activa, usa `/chicken` frente al tabernero Fuegobrezo en Forjaz. Verifica el ID y el caramelo. |
| 8355 | 1 | Cliente durante Halloween | Con 8311 activa, usa `/train` frente a Talvash en Forjaz. Verifica el ID y el caramelo. |
| 8356 | 1 | Cliente durante Halloween | Con 8311 activa, usa `/flex` frente a la tabernera Allison en Ventormenta. Verifica el ID y el caramelo. |
| 8556 | 4 | Cliente con botín de Ahn'Qiraj | Con guerrero de nivel 60 y Honorable, comprueba el canje con Yessendra. Referencia heredada: 1 × 20884, 2 × 20868, 5 × 20861 y 5 × 20865. |
| 8689 | 1 | Cliente con botín de Ahn'Qiraj | Con sacerdote de nivel 60 y Reverenciado, comprueba el canje con Keyl. Referencia heredada: 1 × 20885, 2 × 20870, 5 × 20859 y 5 × 20863. |
| 8691 | 3 | Cliente con botín de Ahn'Qiraj | Con mago de nivel 60 y Reverenciado, comprueba el canje con Keyl. Referencia heredada: 1 × 20885, 2 × 20873, 5 × 20858 y 5 × 20862. |
| 8692 | 3 | Cliente con botín de Ahn'Qiraj | Con druida de nivel 60 y Reverenciado, comprueba el canje con Keyl. Referencia heredada: 1 × 20889, 2 × 20872, 5 × 20864 y 5 × 20860. |
| 8693 | 1 | Cliente con botín de Ahn'Qiraj | Con pícaro de nivel 60 y Reverenciado, comprueba el canje con Keyl. Referencia heredada: 1 × 20885, 2 × 20866, 5 × 20861 y 5 × 20865. |
| 8694 | 1 | Cliente con botín de Ahn'Qiraj | Con brujo de nivel 60 y Reverenciado, comprueba el canje con Keyl. Referencia heredada: 1 × 20889, 2 × 20869, 5 × 20865 y 5 × 20861. |
| 8696 | 2 | Cliente con botín de Ahn'Qiraj | Con cazador de nivel 60 y Reverenciado, comprueba el canje con Keyl. Referencia heredada: 1 × 20889, 2 × 20868, 5 × 20858 y 5 × 20862. |
| 8788 | 6 | Cliente durante Festival de Invierno | Abre el regalo 180746 de Orgrimmar (52,3 / 69,4). Contrasta el ID que reciben un paladín, un Skyborne y otro personaje de la Horda. |
| 8863 | 43 | Cliente durante Festival Lunar | Comprueba si el PNJ 15864 acepta una moneda 21100 y vuelve a ofrecer el canje con un personaje de cada facción. |
| 9266 | 20 | Investigar oferta | Comprueba el canje de 40 paños rúnicos (14047) y cuatro carbones (3857) con Bronn en Vista Eterna. Compara la oferta por debajo y al alcanzar 0 de reputación con Vista Eterna. Registra el cambio de reputación y si vuelve a ofrecerse. |

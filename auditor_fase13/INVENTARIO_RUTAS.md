# Inventario de rutas de leveo de la 9.7.9

Las 47 rutas figuran en el orden de carga de `GuiaAventurero/GuiaAventurero.toc`. Los archivos se indican con rutas relativas a `GuiaAventurero/`. Cada archivo registra un ID único, tiene un cargador y declara secciones que cubren los niveles 1 a 60. La cobertura se comprobó mediante lectura del código.

Hay 25 rutas de Alianza y 22 de Horda. Nueve rutas cubren dos razas, con 56 combinaciones únicas de facción, raza y clase en total. La facción de Skyborne está declarada en cada ruta. Para las demás se aplicó la regla de `ElegirRuta` de `GuiaAventurero.lua`, que deduce la facción de la primera raza declarada.

| Línea TOC | Archivo | ID | Nombre | Clase (token) | Razas (tokens) | Facción efectiva | Secciones |
| ---: | --- | --- | --- | --- | --- | --- | ---: |
| 31 | `Rutas/GnomoMago.lua` | `gnomo_mago` | Gnomo mago | `MAGE` | `Gnome` | Alianza (por raza) | 17 |
| 32 | `Rutas/EnanoChaman.lua` | `enano_chaman` | Enano chamán | `SHAMAN` | `Dwarf` | Alianza (por raza) | 18 |
| 33 | `Rutas/EnanoGnomoGuerrero.lua` | `enano_gnomo_guerrero` | Enano o gnomo guerrero | `WARRIOR` | `Dwarf`, `Gnome` | Alianza (por raza) | 17 |
| 34 | `Rutas/EnanoPaladin.lua` | `enano_paladin` | Enano paladín | `PALADIN` | `Dwarf` | Alianza (por raza) | 17 |
| 35 | `Rutas/EnanoGnomoSacerdote.lua` | `enano_gnomo_sacerdote` | Enano o gnomo sacerdote | `PRIEST` | `Dwarf`, `Gnome` | Alianza (por raza) | 17 |
| 36 | `Rutas/EnanoCazador.lua` | `enano_cazador` | Enano cazador | `HUNTER` | `Dwarf` | Alianza (por raza) | 17 |
| 37 | `Rutas/EnanoGnomoPicaro.lua` | `enano_gnomo_picaro` | Enano o gnomo pícaro | `ROGUE` | `Dwarf`, `Gnome` | Alianza (por raza) | 18 |
| 38 | `Rutas/GnomoBrujo.lua` | `gnomo_brujo` | Gnomo brujo | `WARLOCK` | `Gnome` | Alianza (por raza) | 17 |
| 39 | `Rutas/HumanoGuerrero.lua` | `humano_guerrero` | Humano guerrero | `WARRIOR` | `Human` | Alianza (por raza) | 21 |
| 40 | `Rutas/HumanoPaladin.lua` | `humano_paladin` | Humano paladín | `PALADIN` | `Human` | Alianza (por raza) | 21 |
| 41 | `Rutas/HumanoPicaro.lua` | `humano_picaro` | Humano pícaro | `ROGUE` | `Human` | Alianza (por raza) | 22 |
| 42 | `Rutas/HumanoBrujo.lua` | `humano_brujo` | Humano brujo | `WARLOCK` | `Human` | Alianza (por raza) | 21 |
| 43 | `Rutas/HumanoMago.lua` | `humano_mago` | Humano mago | `MAGE` | `Human` | Alianza (por raza) | 21 |
| 44 | `Rutas/HumanoSacerdote.lua` | `humano_sacerdote` | Humano sacerdote | `PRIEST` | `Human` | Alianza (por raza) | 21 |
| 45 | `Rutas/HumanoCazador.lua` | `humano_cazador` | Humano cazador | `HUNTER` | `Human` | Alianza (por raza) | 21 |
| 46 | `Rutas/ElfoCazador.lua` | `elfo_cazador` | Elfo de la noche cazador | `HUNTER` | `NightElf` | Alianza (por raza) | 20 |
| 47 | `Rutas/ElfoDruida.lua` | `elfo_druida` | Elfo de la noche druida | `DRUID` | `NightElf` | Alianza (por raza) | 20 |
| 48 | `Rutas/ElfoGuerrero.lua` | `elfo_guerrero` | Elfo de la noche guerrero | `WARRIOR` | `NightElf` | Alianza (por raza) | 20 |
| 49 | `Rutas/ElfoPicaro.lua` | `elfo_picaro` | Elfo de la noche pícaro | `ROGUE` | `NightElf` | Alianza (por raza) | 21 |
| 50 | `Rutas/ElfoSacerdote.lua` | `elfo_sacerdote` | Elfo de la noche sacerdote | `PRIEST` | `NightElf` | Alianza (por raza) | 20 |
| 51 | `Rutas/OrcoTrolGuerrero.lua` | `orco_trol_guerrero` | Orco o trol guerrero | `WARRIOR` | `Orc`, `Troll` | Horda (por raza) | 23 |
| 52 | `Rutas/OrcoTrolCazador.lua` | `orco_trol_cazador` | Orco o trol cazador | `HUNTER` | `Orc`, `Troll` | Horda (por raza) | 23 |
| 53 | `Rutas/OrcoTrolPicaro.lua` | `orco_trol_picaro` | Orco o trol pícaro | `ROGUE` | `Orc`, `Troll` | Horda (por raza) | 23 |
| 54 | `Rutas/OrcoTrolChaman.lua` | `orco_trol_chaman` | Orco o trol chamán | `SHAMAN` | `Orc`, `Troll` | Horda (por raza) | 23 |
| 55 | `Rutas/OrcoTrolBrujo.lua` | `orco_trol_brujo` | Orco o trol brujo | `WARLOCK` | `Orc`, `Troll` | Horda (por raza) | 23 |
| 56 | `Rutas/OrcoTrolMago.lua` | `orco_trol_mago` | Orco o trol mago | `MAGE` | `Orc`, `Troll` | Horda (por raza) | 23 |
| 57 | `Rutas/TrolSacerdote.lua` | `trol_sacerdote` | Trol sacerdote | `PRIEST` | `Troll` | Horda (por raza) | 23 |
| 58 | `Rutas/TaurenGuerrero.lua` | `tauren_guerrero` | Tauren guerrero | `WARRIOR` | `Tauren` | Horda (por raza) | 24 |
| 59 | `Rutas/TaurenCazador.lua` | `tauren_cazador` | Tauren cazador | `HUNTER` | `Tauren` | Horda (por raza) | 24 |
| 60 | `Rutas/TaurenChaman.lua` | `tauren_chaman` | Tauren chamán | `SHAMAN` | `Tauren` | Horda (por raza) | 24 |
| 61 | `Rutas/TaurenDruida.lua` | `tauren_druida` | Tauren druida | `DRUID` | `Tauren` | Horda (por raza) | 24 |
| 62 | `Rutas/NoMuertoGuerrero.lua` | `nomuerto_guerrero` | No-muerto guerrero | `WARRIOR` | `Scourge` | Horda (por raza) | 24 |
| 63 | `Rutas/NoMuertoPicaro.lua` | `nomuerto_picaro` | No-muerto pícaro | `ROGUE` | `Scourge` | Horda (por raza) | 24 |
| 64 | `Rutas/NoMuertoMago.lua` | `nomuerto_mago` | No-muerto mago | `MAGE` | `Scourge` | Horda (por raza) | 24 |
| 65 | `Rutas/NoMuertoSacerdote.lua` | `nomuerto_sacerdote` | No-muerto sacerdote | `PRIEST` | `Scourge` | Horda (por raza) | 24 |
| 66 | `Rutas/NoMuertoBrujo.lua` | `nomuerto_brujo` | No-muerto brujo | `WARLOCK` | `Scourge` | Horda (por raza) | 24 |
| 67 | `Rutas/NoMuertoPaladin.lua` | `nomuerto_paladin` | No-muerto paladín | `PALADIN` | `Scourge` | Horda (por raza) | 24 |
| 68 | `Rutas/SkyborneGuerrero.lua` | `skyborne_guerrero` | Skyborne guerrero | `WARRIOR` | `Skyborne` | Horda (explícita) | 25 |
| 69 | `Rutas/SkyborneCazador.lua` | `skyborne_cazador` | Skyborne cazador | `HUNTER` | `Skyborne` | Horda (explícita) | 25 |
| 70 | `Rutas/SkybornePicaro.lua` | `skyborne_picaro` | Skyborne pícaro | `ROGUE` | `Skyborne` | Horda (explícita) | 25 |
| 71 | `Rutas/SkyborneChaman.lua` | `skyborne_chaman` | Skyborne chamán | `SHAMAN` | `Skyborne` | Horda (explícita) | 25 |
| 72 | `Rutas/SkyborneDruida.lua` | `skyborne_druida` | Skyborne druida | `DRUID` | `Skyborne` | Horda (explícita) | 25 |
| 73 | `Rutas/SkyborneAGuerrero.lua` | `skyborne_a_guerrero` | Skyborne guerrero | `WARRIOR` | `Skyborne` | Alianza (explícita) | 22 |
| 74 | `Rutas/SkyborneACazador.lua` | `skyborne_a_cazador` | Skyborne cazador | `HUNTER` | `Skyborne` | Alianza (explícita) | 22 |
| 75 | `Rutas/SkyborneAPicaro.lua` | `skyborne_a_picaro` | Skyborne pícaro | `ROGUE` | `Skyborne` | Alianza (explícita) | 23 |
| 76 | `Rutas/SkyborneAMago.lua` | `skyborne_a_mago` | Skyborne mago | `MAGE` | `Skyborne` | Alianza (explícita) | 22 |
| 77 | `Rutas/SkyborneADruida.lua` | `skyborne_a_druida` | Skyborne druida | `DRUID` | `Skyborne` | Alianza (explícita) | 21 |

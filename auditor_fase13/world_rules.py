"""Comprueba cartografía, progresión y desplazamientos de rutas de leveo."""

from collections import Counter
from math import hypot
import re


XP_REFUERZO = re.compile(r"no quedarte corto de nivel|refuerzo de (?:xp|experiencia)", re.IGNORECASE)
XP_OPCIONAL = re.compile(
    r"^(?:Misión opcional:|Misión opcional de (?:especialización\b|Kum'isha:|guerrero:|mago:|pícaro:)|"
    r"Bálsamo de Frondavil:|Encargo opcional de Desolace:)"
)


def _dict(value):
    return value if isinstance(value, dict) else {}


def _list(value):
    return value if isinstance(value, list) else []


def _id(value):
    return type(value) is int and value > 0


def _coordinate(value):
    return type(value) in (int, float) and 0 <= value <= 100


def _catalog_entry(index, key):
    records = _dict(index)
    return _dict(records.get(str(key), records.get(key)))


def _source(entry, field):
    fields = entry.get("evidencia")
    record = _dict(fields.get(field)) if isinstance(fields, dict) else entry
    if record.get("estado") == "forever":
        return record.get("fuente")
    return None


def _position(point):
    map_id, x, y = (point.get(field) for field in ("m", "x", "y"))
    if _id(map_id) and _coordinate(x) and _coordinate(y):
        return map_id, x, y
    return None


def _proximity(first, second):
    return hypot(first[1] - second[1], first[2] - second[2])


def _places(raw):
    return [position for entry in _list(raw) if (position := _position(_dict(entry)))]


def _positions_by_action(entry, field, action):
    positions = entry.get(field)
    return _places(_dict(positions).get(action) if action else positions)


def _matches_positions(position, references, tolerance):
    return any(position[0] == other[0] and _proximity(position, other) <= tolerance for other in references)


def _matches_observation(entry, action, position, tolerance):
    return any(_source(entry, field)
               and _matches_positions(position, _positions_by_action(entry, field, action), tolerance)
               for field in ("posiciones_observadas", "progreso_observado", "referencias_objetivo",
                             "posiciones_reproyectadas", "referencias_interaccion", "posiciones_trazas", "referencias_botin"))


def valid_xp_sample(sample):
    xp, level, sources = (sample.get(field) for field in ("xp", "level", "sources"))
    return (type(xp) is int and xp >= 0 and type(level) is int and 1 <= level < 60
            and type(sources) is int and sources > 0
            and not sample.get("maxLevel") and not sample.get("xpDisabled"))


class WorldAudit:
    def __init__(self, route, context):
        self.route = route
        self.catalog = _dict(context.get("catalogo", context))
        self.sections = _list(route.get("secciones"))
        self.findings = []
        self.unverified_maps = set()
        self.unverified_positions = Counter()
        self.flight_checks = set()
        self.legs = []
        self.checks_xp = set()
        self.turn_ins = []

    def add(self, block, severity, code, detail, location=None):
        finding = {
            "bloque": block, "gravedad": severity, "codigo": code,
            "archivo": self.route.get("_archivo"), "ruta": self.route.get("id"),
            "detalle": detail,
        }
        if location:
            finding["ubicacion"] = location
        self.findings.append(finding)

    def check_map(self, map_id, location):
        if not _id(map_id):
            self.add(3, "error", "mapa_invalido", f"El UiMapID debe ser un entero positivo. Valor: {map_id!r}.", location)
            return
        record = _catalog_entry(self.catalog.get("mapas"), map_id)
        source = _source(record, "existe")
        if not source or type(record.get("existe")) is not bool:
            self.unverified_maps.add(map_id)
        elif record["existe"] is False:
            self.add(3, "error", "mapa_inexistente_forever",
                     f"El UiMapID {map_id} figura como inexistente en Forever. Fuente: {source}.", location)

    def check_waypoint(self, point, location):
        self.check_map(point.get("m"), location)
        for field in ("x", "y"):
            value = point.get(field)
            if not _coordinate(value):
                self.add(3, "error", "coordenada_invalida",
                         f"La coordenada {field} debe ser numérica y estar entre 0 y 100. Valor: {value!r}.", location)
        npc, quest, action = (point.get(field) for field in ("npc", "q", "a"))
        if npc is not None and not _id(npc):
            self.add(3, "error", "pnj_invalido", f"El ID de PNJ debe ser un entero positivo. Valor: {npc!r}.", location)

        position = _position(point)
        if position is None:
            return None
        if not isinstance(point.get("z"), str) or not point["z"].strip():
            self.add(3, "aviso", "nombre_mapa_ausente", "El destino carece de nombre de zona para mostrar.", location)

        if _id(npc):
            record = _catalog_entry(self.catalog.get("pnj"), npc)
            self.check_reference(record, f"PNJ {npc}", position, "PNJ", location)
        elif _id(quest) and action in ("A", "C", "T"):
            record = _catalog_entry(self.catalog.get("misiones"), quest)
            self.check_reference(record, f"misión {quest} ({action})", position, action, location, action)
        else:
            self.unverified_positions["orientación"] += 1
        return position

    def check_reference(self, record, name, position, category, location, action=None):
        existing_source = _source(record, "posiciones")
        rejected_source = _source(record, "posiciones_descartadas")
        allowed = _positions_by_action(record, "posiciones", action) if existing_source else []
        rejected = _positions_by_action(record, "posiciones_descartadas", action) if rejected_source else []
        if position in rejected:
            self.add(3, "error", "posicion_descartada_forever",
                     f"{name} usa el punto descartado {position}. Fuente: {rejected_source}.", location)
            return
        tolerance = record.get("tolerancia", 1)
        if not _coordinate(tolerance):
            tolerance = 1
        nearby = (_matches_positions(position, allowed, tolerance)
                  or _matches_observation(record, action, position, tolerance))
        if not nearby:
            self.unverified_positions[category] += 1
            if allowed and record.get("posiciones_completas") is True:
                self.add(3, "aviso", "posicion_difiere_forever",
                         f"{name} en {position} difiere de las posiciones documentadas. Fuente: {existing_source}.", location)

    def check_section_step(self, step, level_range, location):
        check = _dict(step.get("comprobar"))
        if "llegar" in check:
            self.check_map(check["llegar"], f"{location}, comprobación de llegada")
        if "vuelo" in check:
            flight = check["vuelo"]
            if isinstance(flight, str) and flight.strip():
                self.flight_checks.add(flight)
            else:
                self.add(5, "error", "vuelo_invalido",
                         f"La comprobación de vuelo requiere un nombre de nodo. Valor: {flight!r}.", location)
        if "nivel" in check:
            level = check["nivel"]
            if not _id(level) or level > 60:
                self.add(4, "error", "nivel_comprobacion_invalido",
                         f"El nivel de comprobación debe ser un entero entre 1 y 60. Valor: {level!r}.", location)
            elif level_range and level > level_range[1]:
                self.add(4, "aviso", "nivel_fuera_de_tramo",
                         f"El paso pide nivel {level} y el tramo anuncia hasta {level_range[1]}.", location)

    def check_steps(self, section, section_index, level_range):
        section_turn_ins = []
        step_lines = _list(self.route.get("_lineas_pasos"))
        lines = _list(step_lines[section_index - 1]) if section_index <= len(step_lines) else []
        for step_index, step in enumerate(_list(section.get("pasos")), 1):
            if not isinstance(step, dict):
                continue
            location = f"tramo {section_index}, paso {step_index}"
            if step_index <= len(lines):
                location = f"línea {lines[step_index - 1]}, {location}"
            self.check_section_step(step, level_range, location)
            optional = isinstance(step.get("t"), str) and bool(XP_OPCIONAL.match(step["t"]))
            for index, point in enumerate(_list(step.get("wp")), 1):
                if not isinstance(point, dict):
                    continue
                waypoint_location = f"{location}, destino {index}"
                position = self.check_waypoint(point, waypoint_location)
                quest_id = point.get("q")
                if point.get("a") == "T" and _id(quest_id):
                    self.check_turn_in(quest_id, step, waypoint_location)
                    alternative = point.get("alternativa")
                    section_turn_ins.append((quest_id, point.get("raza"), alternative if _id(alternative) else None, optional))
                if position and not point.get("raza"):
                    if not self.legs or position[0] != self.legs[-1]:
                        self.legs.append(position[0])
        self.turn_ins.append(section_turn_ins)

    def check_turn_in(self, quest_id, step, location):
        record = _catalog_entry(self.catalog.get("misiones"), quest_id)
        text = step.get("t")
        source = _source(record, "xp")
        if not source or type(record.get("xp")) is not int or record["xp"] < 0:
            self.checks_xp.add(quest_id)
        elif record["xp"] == 0 and isinstance(text, str) and XP_REFUERZO.search(text) and all(
            _dict(point).get("a") != "T" or _dict(point).get("q") == quest_id for point in _list(step.get("wp"))
        ):
            calculated = _dict(_dict(record.get("evidencia")).get("xp")).get("metodo") == "calculada"
            if calculated:
                self.add(4, "aviso", "refuerzo_xp_base_cero",
                         f"La misión {quest_id} figura como refuerzo y su XP base calculada es 0. "
                         f"Contrastar la entrega y las recompensas especiales. Fuente: {source}.", location)
            else:
                self.add(4, "error", "mision_sin_xp_usada_como_refuerzo",
                         f"La misión {quest_id} se recomienda como refuerzo de nivel pero no da XP en Forever. "
                         f"Fuente: {source}.", location)

    def check_ranges(self):
        covered = set()
        required = set(range(1, 60))
        ranges = []
        for section_index, section in enumerate(self.sections, 1):
            if not isinstance(section, dict):
                section = {}
            start, end = section.get("min"), section.get("max")
            valid = _id(start) and _id(end) and 1 <= start <= end <= 60
            level_range = (start, end) if valid else None
            ranges.append(level_range)
            if valid:
                # SeccionPorNivel usa min inclusivo y max exclusivo en 9.7.9.
                covered.update(range(start, end))
            else:
                self.add(4, "error", "rango_niveles_invalido",
                         f"El tramo declara un rango de niveles inválido: {start!r}–{end!r}.", f"tramo {section_index}")
            self.check_steps(section, section_index, level_range)
        missing = sorted(required - covered)
        if missing:
            self.add(4, "error", "nivel_sin_tramo_automatico",
                     "Ir a mi nivel caería en el último tramo para estos niveles sin intervalo: "
                     + ", ".join(map(str, missing)) + ".")
        return ranges

    def check_xp(self, ranges):
        curve = _dict(self.catalog.get("xp_por_nivel"))
        thresholds = [_dict(curve.get("niveles")).get(str(i)) for i in range(1, 60)]
        has_curve = _source(curve, "niveles") and all(_id(value) for value in thresholds)
        if self.checks_xp or not has_curve:
            curve_status = "curva 1–60 documentada" if has_curve else "curva 1–60 sin evidencia completa"
            self.add(4, "pendiente", "xp_evidencia_incompleta",
                     f"{len(self.checks_xp)} entregas distintas con XP pendiente de confirmar en Forever. {curve_status.capitalize()}.")
        self.compare_xp_scenario(ranges, thresholds if has_curve else None)
        self.add(4, "pendiente", "xp_real_cliente",
                 "Verificar recompensas por nivel, XP de combate, estado de descanso y progreso efectivo en Forever.")

    def compare_xp_scenario(self, ranges, thresholds):
        # La curva y la XP registrada son comparables solo como escenario teórico.
        # Contamos una entrega por ID y por raza porque AdaptarARaza elimina destinos.
        races = _list(self.route.get("razas")) or [None]
        observed = []
        coverage = {}
        faction = self.route.get("_faccion")
        combat_catalog = _catalog_entry(self.catalog.get("xp_combates"), self.route.get("id"))
        combat_sections = _dict(combat_catalog.get("tramos"))
        for race in races:
            counted = set()
            race_xp = 0
            combat_xp = 0
            known = 0
            sampled = 0
            optional_count = 0
            optional_xp = 0
            below, above = [], []
            for index, (levels, turn_ins) in enumerate(zip(ranges, self.turn_ins), 1):
                section_xp = 0
                for quest_id, point_race, alternative, optional in turn_ins:
                    if quest_id in counted or alternative in counted or (point_race and point_race != race):
                        continue
                    counted.add(quest_id)
                    record = _catalog_entry(self.catalog.get("misiones"), quest_id)
                    optional_count += int(optional)
                    if (levels and not optional and _source(record, "entregas_observadas")
                            and any(valid_xp_sample(row) and row.get("race") == race and row.get("faction") == faction
                                    and levels[0] <= row["level"] < levels[1]
                                    for row in _list(record.get("entregas_observadas")))):
                        sampled += 1
                    if _source(record, "xp") and type(record.get("xp")) is int and record["xp"] >= 0:
                        if optional:
                            optional_xp += record["xp"]
                        else:
                            section_xp += record["xp"]
                            known += 1
                race_xp += section_xp
                combat = _dict(combat_sections.get(str(index)))
                estimate = combat.get("xp")
                if not _source(combat, "xp") or type(estimate) is not int or estimate < 0:
                    estimate = 0
                combat_xp += estimate
                if thresholds and levels and levels[0] < levels[1]:
                    start, end = levels
                    needed = sum(thresholds[start - 1:end - 1])
                    if section_xp + estimate < needed:
                        below.append(index)
                    elif section_xp + estimate > needed:
                        above.append(index)
            mandatory = len(counted) - optional_count
            coverage[race or "ruta"] = {"observadas": sampled, "aplicables": mandatory}
            if known or combat_xp or optional_xp or sampled:
                detail = f"{race or 'ruta'}: {race_xp} XP de misión registrada ({known}/{mandatory} entregas)"
                if optional_count:
                    detail += f", {optional_xp} XP documentada aparte en misiones opcionales"
                if combat_xp:
                    detail += f", {combat_xp} XP de combate estimada en los tramos documentados"
                if thresholds:
                    detail += f", subtotal inferior al intervalo en {len(below)} tramos y superior en {len(above)}"
                if mandatory:
                    detail += f", {sampled}/{mandatory} entregas con muestra de XP para la raza y facción en el intervalo"
                observed.append(detail)
        if observed:
            self.add(4, "pendiente", "xp_escenario_misiones",
                     ". ".join(observed) + ". Escenario parcial con una entrega por ID y perfil, "
                     "que toma la primera alternativa de cada par. "
                     "Requiere validar la XP efectiva, las actividades adicionales y el nivel inicial de cada tramo.")
            self.findings[-1]["cobertura_xp_por_perfil"] = coverage

    def check_travel(self):
        flight_index = _dict(self.catalog.get("vuelos"))
        faction = self.route.get("_faccion")
        observed_nodes = _dict(_dict(self.catalog.get("vuelos_por_faccion")).get(faction))
        unverified = []
        for name in sorted(self.flight_checks):
            flight = _catalog_entry(flight_index, name)
            existence = _source(flight, "existe")
            factions = _source(flight, "facciones")
            if not (existence or factions or name in observed_nodes):
                unverified.append(name)
                continue
            contradicts_existence = existence and flight.get("existe") is False
            contradicts_faction = factions and _list(flight.get("facciones")) and faction not in flight["facciones"]
            if contradicts_existence or contradicts_faction:
                source = existence if contradicts_existence else factions
                self.add(5, "error", "vuelo_no_disponible",
                         f"El nodo {name!r} no está disponible para {faction}. Fuente: {source}.")
        returns = sum(first == last for first, last in zip(self.legs, self.legs[2:]))
        if unverified:
            self.add(5, "pendiente", "viajes_fuente_pendiente",
                     f"{len(unverified)} nodos de vuelo sin evidencia suficiente: {', '.join(unverified)}. "
                     "Contrastar disponibilidad, requisitos y conexiones con fuentes de Forever.")
        self.add(5, "pendiente", "viajes_coste_cliente",
                 f"{returns} retornos inmediatos a un mapa. Medir recorridos transitables, esperas y tiempos reales "
                 "en las alternativas que superen el contraste de requisitos.")

    def run(self):
        ranges = self.check_ranges()
        if self.unverified_maps:
            ids = ", ".join(map(str, sorted(self.unverified_maps)))
            self.add(3, "pendiente", "mapas_sin_evidencia_forever",
                     f"{len(self.unverified_maps)} UiMapID sin confirmación de Forever en el catálogo: {ids}.")
        if self.unverified_positions:
            counts = ", ".join(f"{name}: {count}" for name, count in sorted(self.unverified_positions.items()))
            self.add(3, "pendiente", "posiciones_sin_evidencia_forever",
                     f"Destinos sin posición comprobada en Forever ({counts}), incluidas entradas cuando corresponda.")
        self.check_xp(ranges)
        self.check_travel()
        return self.findings


def audit_world(route, context):
    """Devuelve hallazgos localizables de los bloques 3, 4 y 5."""
    return WorldAudit(route, context).run()

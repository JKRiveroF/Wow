"""Comprueba hitos documentados de las zonas de inicio de Forever."""


def _hallazgo(route, severity, code, detail, source, location="Sección 1"):
    return {
        "bloque": 6,
        "gravedad": severity,
        "codigo": code,
        "archivo": route.get("_archivo"),
        "ruta": route.get("id"),
        "detalle": detail,
        "ubicacion": location,
        "fuente": source,
    }


def _puntos_del_arranque(section, race):
    for step in section.get("pasos", []):
        for point in step.get("wp", []):
            if point.get("q") and point.get("raza") in (None, race):
                yield point


def _contrastar_hito(route, race, milestone, points, map_id, is_class_mission):
    quest = milestone["q"]
    source = milestone["fuente"]
    positions = [(index, point.get("a")) for index, point in enumerate(points)
                 if point.get("q") == quest and point.get("m") == map_id]
    sequence = "".join(action or "?" for _, action in positions)
    if sequence != milestone["acciones"]:
        code = "ARRANQUE_MISION_CLASE_AUSENTE" if is_class_mission and not sequence else "ARRANQUE_HITO_DISTINTO"
        return _hallazgo(
            route, "aviso", code,
            f"Para {race}, la misión {quest} requiere revisar las acciones en su mapa de inicio: "
            f"{sequence or 'ausente'} frente a {milestone['acciones']}.", source,
        )
    previous = milestone.get("previa")
    if previous and not any(point.get("q") == previous and point.get("a") == "T"
                            for point in points[:positions[0][0]]):
        return _hallazgo(
            route, "error", "ARRANQUE_MISION_CLASE_ANTES_DE_REQUISITO",
            f"Para {race}, falta entregar {previous} antes de aceptar {quest}.", milestone.get("fuente_previa", source),
        )
    return None


def audit_arranques(route, catalog):
    """Contrasta únicamente hitos atestiguados del primer tramo por raza."""
    evidence = catalog.get("arranques")
    sections = route.get("secciones")
    if not evidence or not sections:
        return []

    section = sections[0]
    findings = []
    class_missions = {record["q"]: record for record in evidence["clases_nuevas"]}
    for race in route.get("razas", []):
        if race == "Skyborne":
            continue
        zone = next((zone for zone in evidence["zonas"] if race in zone["razas"]), None)
        if zone is None:
            findings.append(_hallazgo(
                route, "pendiente", "ARRANQUE_SIN_ZONA_DOCUMENTADA",
                f"Falta contrastar la zona de inicio de {race} en Forever.", None,
            ))
            continue

        points = list(_puntos_del_arranque(section, race))
        source = zone["hitos"][0]["fuente"]
        first_pickup = next((point for point in points if point.get("a") == "A"), None)
        if section.get("min") != 1 or first_pickup is None or first_pickup.get("m") != zone["m"]:
            findings.append(_hallazgo(
                route, "aviso", "ARRANQUE_ZONA_INESPERADA",
                f"El primer tramo para {race} difiere del inicio documentado en {zone['nombre']} (mapa {zone['m']}, nivel 1).",
                source,
            ))

        profile = (race, route.get("clase"))
        for quest in sorted({point["q"] for point in points} & class_missions.keys()):
            record = class_missions[quest]
            if (record["raza"], record["clase"]) != profile:
                findings.append(_hallazgo(
                    route, "error", "ARRANQUE_MISION_CLASE_INCOMPATIBLE",
                    f"La misión {quest} aparece para {profile[0]} / {profile[1]} tras el filtro racial, "
                    f"pero corresponde a {record['raza']} / {record['clase']}.", record["fuente"],
                ))

        class_mission = next((record for record in class_missions.values()
                              if (record["raza"], record["clase"]) == profile), None)
        milestones = list(zone["hitos"])
        if class_mission:
            milestones.append(class_mission)
        for milestone in milestones:
            finding = _contrastar_hito(route, race, milestone, points, zone["m"], milestone == class_mission)
            if finding:
                findings.append(finding)
    return findings

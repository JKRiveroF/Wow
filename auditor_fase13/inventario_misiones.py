"""Agrupa la verificación por ID y conserva las rutas que reutilizan sus datos."""

from collections import Counter, defaultdict

from eg_link import EG_FIELDS
from mission_rules import (PHASE_SIX_FIELDS, PHASE_TWO_FIELDS, _collect, _confirmed, _entry,
                           _evidence, _mission_title, _norm)
from world_rules import _matches_observation, _matches_positions, _position, _positions_by_action, _source

FIELDS = (*PHASE_TWO_FIELDS, *PHASE_SIX_FIELDS, "prerrequisitos_alternativos", "objeto_entregado",
          "objetos_objetivo", "cantidades_objetivo", "mision_activa", "desactivada_por", "disponible_desde",
          "disponible_hasta_entrega", "oficio_minimo", "xp")


def _coordinate_result(entry, action, position):
    if _source(entry, "posiciones_descartadas") and position in _positions_by_action(entry, "posiciones_descartadas", action):
        return "contradice_fuente"
    if _source(entry, "posiciones") and _matches_positions(
        position, _positions_by_action(entry, "posiciones", action), 1
    ):
        return "compatible_con_fuente"
    if _matches_observation(entry, action, position, 1):
        return "cerca_de_observacion"
    return "investigacion"


def inventory_missions(routes, catalog, quest_v2=None):
    missions = defaultdict(lambda: {"rutas": set(), "acciones": Counter(), "posiciones": defaultdict(set),
                                    "titulos_guia": set()})
    for route in routes:
        route_id = route.get("id") or route["_archivo"]
        for point in _collect(route, []):
            mission = missions[point.quest]
            mission["rutas"].add(route_id)
            mission["acciones"][point.action] += 1
            if point.action in ("A", "T") and (title := _mission_title(point.waypoint)[1]):
                mission["titulos_guia"].add(title)
            if location := _position(point.waypoint):
                mission["posiciones"][point.action, *location].add(route_id)

    active_count = len(missions)
    retired = catalog.get("misiones_originales_retiradas", {})
    quest_ids = missions.keys() | {int(quest) for quest in retired}

    coverage = Counter()
    table = Counter()
    reports = []
    fields_to_check = (*FIELDS, *EG_FIELDS) if "vuelos_observados" in catalog else FIELDS
    candidates = catalog.get("candidatos_por_mision", {})
    inherited = catalog.get("titulos_es_heredados", {})
    for quest in sorted(quest_ids):
        lookup = missions[quest]
        entry = _entry(catalog, quest)
        fields = {}
        for field in fields_to_check:
            if source := _confirmed(entry, field):
                status, _ = _evidence(entry, field)
                value = entry["nombres"][field[-2:]] if field.startswith("nombre_") else entry[field]
                fields[field] = {"estado": status, "valor": value, "fuente": source}
                provenance = entry.get("evidencia", {})
                details = provenance.get(field, provenance.get("nombres", {})) if field.startswith("nombre_") else provenance.get(field, {})
                fields[field].update({k: details[k] for k in ("build", "tabla", "metodo", "fuentes_adicionales") if k in details})
                coverage[field] += 1
        positions = []
        for (action, map_id, x, y), shared in sorted(lookup["posiciones"].items()):
            result = _coordinate_result(entry, action, (map_id, x, y))
            positions.append({"accion": action, "mapa": map_id, "x": x, "y": y,
                              "rutas": len(shared), "estado": result})
        record = {"id": quest, "rutas": sorted(lookup["rutas"]), "acciones": dict(lookup["acciones"]),
                  "evidencia": fields, "pendientes_de_fuente": [field for field in FIELDS if field not in fields],
                  "posiciones": positions, "indicios": candidates.get(str(quest), [])}
        if "nombre_es" not in fields and (title := inherited.get(str(quest))):
            labels = lookup["titulos_guia"]
            different = sorted(label for label in labels if _norm(label) != _norm(title["valor"]))
            record["contraste_es_heredado"] = {
                **title, "titulo_guia_cotejado": bool(labels), "titulos_guia_distintos": different,
            }
        if str(quest) in retired:
            record["retirada_de_rutas_originales"] = retired[str(quest)]
        if quest_v2 is not None:
            present = quest in quest_v2["ids"]
            server_evidence = fields.get("existe", {}).get("valor")
            record["fila_questv2"] = present
            table["con_fila" if present else "sin_fila"] += 1
            if not present and server_evidence is True:
                table["sin_fila_con_evidencia_servidor"] += 1
            if lookup["rutas"] and server_evidence is None:
                table["activa_sin_evidencia_servidor"] += 1
                if present:
                    table["activa_sin_evidencia_servidor_con_fila"] += 1
        reports.append(record)

    result = {"total": len(reports), "total_en_rutas": active_count,
              "cobertura": {field: coverage[field] for field in fields_to_check},
              "misiones": reports}
    if quest_v2 is not None:
        result["questv2"] = {"build": quest_v2["build"], "fuente": quest_v2["fuente"],
                             "recuentos": dict(table)}
    return result

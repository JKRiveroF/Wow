"""Cruza los maestros de vuelo de las rutas con sus nodos y conexiones observadas."""

from collections import defaultdict

from world_rules import _dict, _list


def link_flights(routes, flight_data):
    masters = flight_data["maestros"]
    matches = defaultdict(lambda: defaultdict(set))
    requested = defaultdict(set)
    for route in routes:
        faction = route["_faccion"]
        for section in route["secciones"]:
            for step in section["pasos"]:
                name = _dict(step.get("comprobar")).get("vuelo")
                if not isinstance(name, str) or not name.strip():
                    continue
                requested[faction].add(name)
                for point in _list(step.get("wp")):
                    npc = str(point.get("npc"))
                    master = masters.get(npc)
                    if master and master.get("sources") and master.get("node"):
                        matches[faction][name].add((int(npc), master["node"]))

    by_faction = {}
    for faction, names in requested.items():
        supported = by_faction[faction] = {}
        for name in sorted(names):
            if len(matches[faction][name]) == 1:
                npc, node = next(iter(matches[faction][name]))
                supported[name] = {"pnj": npc, "nodo": node, "registros": masters[str(npc)]["sources"]}

    routes_by_faction = {}
    for faction, places in by_faction.items():
        names_by_node = defaultdict(list)
        for name, observation in places.items():
            names_by_node[observation["nodo"]].append(name)
        connections = routes_by_faction[faction] = {}
        for key, data in flight_data["conexiones"].items():
            nodes, _, talent = key.partition("|")
            start, end = map(int, nodes.split(">"))
            if start in names_by_node and end in names_by_node:
                connections[key] = {**data, "origen": names_by_node[start], "destino": names_by_node[end],
                                    "talento": talent or None}

    return {
        "fuente": flight_data["fuente"], "build": flight_data["build"],
        "nodos": by_faction, "conexiones": routes_by_faction,
        "nodos_sin_indicio": {faction: sorted(names - by_faction[faction].keys())
                             for faction, names in requested.items()},
    }

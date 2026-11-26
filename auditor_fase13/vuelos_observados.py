"""Identifica nodos de vuelo y conserva las observaciones por compilación."""

from collections import defaultdict
import csv
from hashlib import sha256

from world_rules import _dict, _list


TAXI_BUILD = "1.60.1.71139"
TAXI_SOURCE = f"https://wago.tools/db2/TaxiNodes/csv?build={TAXI_BUILD}&locale=esES"
TAXI_HASH = "d69384110b75be0b36e5d43322b78932fef4403c9acabd57e40d9f4d718e3c14"
FACTION_FLAGS = {"Alliance": 1, "Horde": 2}
PLACE_NAMES = {
    "Hachazo": "Puesto del Hachazo",
    "Juncobrezo": "Poblado Murohelecho",
    "Menethil": "Puerto de Menethil",
    "Mojache": "Campamento Mojache",
    "Roca del Sol": "Refugio Roca del sol",
    "Sangrevenenosa": "Puesto del Veneno",
    "Sañadiente": "Poblado Sañadiente",
    "Sombraprensa": "Aldea Cazasombras",
    "Taurajo": "Campamento Taurajo",
    "Viento Libre": "Poblado Viento Libre",
}


def load_taxi_nodes(directory):
    file = directory / f"TaxiNodes-esES-{TAXI_BUILD}.csv"
    if not file.is_file():
        return {}
    content = file.read_bytes()
    if sha256(content).hexdigest() != TAXI_HASH:
        raise ValueError(f"SHA-256 inesperado en {file}. Consulta {TAXI_SOURCE}.")
    by_place = defaultdict(list)
    for row in csv.DictReader(content.decode("utf-8-sig").splitlines()):
        name = row["Name_lang"]
        by_place[name.partition(",")[0]].append((int(row["ID"]), name, int(row["Flags"])))
    return by_place


def link_flights(routes, flight_data):
    snapshots = flight_data.get("instantaneas", [flight_data])
    masters, journeys = defaultdict(dict), defaultdict(list)
    for snapshot in sorted(snapshots, key=lambda row: int(row["build"].rsplit(".", 1)[-1])):
        provenance = {key: snapshot[key] for key in ("fuente", "build")}
        for npc, row in snapshot["maestros"].items():
            if row.get("sources") and (node := row.get("node")):
                masters[int(npc)][node] = {"pnj": int(npc), "nodo": node, "registros": row["sources"], **provenance}
        for key, row in snapshot["conexiones"].items():
            journeys[key].append({**row, **provenance})

    requested = defaultdict(lambda: defaultdict(set))
    for route in routes:
        places = requested[route["_faccion"]]
        for section in route["secciones"]:
            for step in section["pasos"]:
                name = _dict(step.get("comprobar")).get("vuelo")
                if isinstance(name, str) and name.strip():
                    places[name].update(point["npc"] for point in _list(step.get("wp"))
                                        if type(point.get("npc")) is int)

    table = flight_data.get("tabla_nodos")
    by_faction, routes_by_faction = {}, {}
    for faction, places in requested.items():
        supported = by_faction[faction] = {}
        names_by_node = defaultdict(list)
        for name, npcs in sorted(places.items()):
            observed = [row for npc in npcs for row in masters.get(npc, {}).values()]
            if table:
                official = PLACE_NAMES.get(name, name)
                candidates = [(node, label) for node, label, flags in table.get(official, [])
                              if flags & FACTION_FLAGS.get(faction, 0)]
                if len(candidates) != 1:
                    continue
                node, label = candidates[0]
                proof = {"nodo": node, "nombre_cliente": label, "fuente_tabla": TAXI_SOURCE}
                observed = [row for row in observed if row["nodo"] == node]
            else:
                # Este paso recorre tres maestros. El nodo documentado de Molino Tarren es el 13.
                if faction == "Horde" and name == "Molino Tarren":
                    observed = [row for row in observed if row["nodo"] == 13]
                if len(observed) != 1:
                    continue
                node, proof = observed[0]["nodo"], {}
            if observed:
                proof.update(max(observed, key=lambda row: (int(row["build"].rsplit(".", 1)[-1]), -row["pnj"])))
            supported[name] = proof
            names_by_node[node].append(name)

        connections = routes_by_faction[faction] = {}
        for key, rows in sorted(journeys.items()):
            nodes, _, talent = key.partition("|")
            start, end = map(int, nodes.split(">"))
            if start in names_by_node and end in names_by_node:
                connections[key] = {**rows[-1], "origen": names_by_node[start], "destino": names_by_node[end],
                                    "talento": talent or None, "observaciones": rows}

    return {
        "fuente": flight_data["fuente"], "build": flight_data["build"],
        "fuentes": [{k: snapshot[k] for k in ("fuente", "build")} for snapshot in snapshots],
        "nodos": by_faction, "conexiones": routes_by_faction,
        "nodos_sin_indicio": {faction: sorted(places.keys() - by_faction[faction].keys())
                             for faction, places in requested.items()},
        "nodos_sin_observacion_de_maestro": {faction: [name for name, proof in places.items() if "pnj" not in proof]
                                           for faction, places in by_faction.items()},
    }

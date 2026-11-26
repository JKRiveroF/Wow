"""Importa los títulos españoles registrados por QuestieDB en Forever."""

import json
import re
from hashlib import sha256
from pathlib import Path


REVISION = "4377c981ac368d1593ec92788218e0a689a6a02b"
SOURCE_URL = f"https://github.com/Questie/QuestieDB/blob/{REVISION}/"
SPANISH_TRACES = {
    "esES": "c6cc3ec0234157990e56f62e61b18a5363dfd069c7a091a26a1eaaea4560d44e",
    "esMX": "3578d5a312faa5735cc306cf8e313b54f77a3cc08d8057232145f534c71b5da0",
}
TITLE_ROW = re.compile(r'^\[([1-9][0-9]*)\] = \{("(?:[^"\\]|\\.)*"),')
INHERITED_ES = "l10n/Forever/lookupQuests/esES.lua"
INHERITED_ES_HASH = "aa73cd9be0da92d0b5af501b92c896dd0c58a6881d28d8c907ee242f283e2fcd"


def _title_rows(data):
    for number, line in enumerate(data.decode("utf-8-sig").splitlines(), 1):
        row = TITLE_ROW.match(line)
        if row:
            quest, literal = row.groups()
            title = json.loads(literal)
            if title.strip():
                yield number, quest, title


def import_spanish_titles(directory: Path) -> dict:
    """Lee los archivos opcionales de trazas, fuera de la localización heredada de Era."""
    quests = {}
    for locale, expected_hash in SPANISH_TRACES.items():
        path = directory / f"questie-forever-quests-{locale}.lua"
        if not path.exists():
            continue
        data = path.read_bytes()
        if sha256(data).hexdigest() != expected_hash:
            raise ValueError(f"SHA-256 inesperado en {path}. Se requieren las trazas de QuestieDB 1.1.6.")

        source = SOURCE_URL + f"l10n/Forever/traces/lookupQuests/{locale}.lua"
        for line_number, quest_id, title in _title_rows(data):
            link = f"{source}#L{line_number}"
            entry = quests.setdefault(quest_id, {
                "nombres": {"es": []},
                "evidencia": {"nombre_es": {"estado": "forever", "fuente": link, "fuentes_por_locale": {}}},
            })
            names = entry["nombres"]["es"]
            if title not in names:
                names.append(title)
            entry["evidencia"]["nombre_es"]["fuentes_por_locale"][locale] = link

    return {"misiones": quests}


def import_inherited_spanish_titles(directory):
    path = directory / "questie-forever-heredado-esES.lua"
    if not path.is_file():
        return {}
    data = path.read_bytes()
    if sha256(data).hexdigest() != INHERITED_ES_HASH:
        raise ValueError(f"SHA-256 inesperado en {path}. Se requiere la localización heredada de QuestieDB 1.1.6.")
    return {quest: {"valor": title, "estado": "classic_compatible", "fuente": f"{SOURCE_URL}{INHERITED_ES}#L{number}"}
            for number, quest, title in _title_rows(data)}

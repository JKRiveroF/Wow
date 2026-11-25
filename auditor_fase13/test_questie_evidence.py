from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from questie_evidence import import_spanish_titles


class QuestieEvidenceTest(unittest.TestCase):
    def test_preserves_observed_locales_and_ignores_lua_outside_rows(self):
        snippets = {
            "esES": '-- [1] = {"Comentario", nil},\n[7] = {"Misión \\"uno\\"", nil},\n[8] = {"Misión dos", nil},\n',
            "esMX": '[7] = {"Misión primera", nil},\n[8] = {"Misión dos", {"Objetivo"}},\n',
        }
        with TemporaryDirectory() as temp:
            directory = Path(temp)
            hashes = {}
            for locale, snippet in snippets.items():
                data = snippet.encode("utf-8")
                (directory / f"questie-forever-quests-{locale}.lua").write_bytes(data)
                hashes[locale] = sha256(data).hexdigest()
            with patch("questie_evidence.SPANISH_TRACES", hashes):
                quests = import_spanish_titles(directory)["misiones"]

        self.assertEqual(set(quests), {"7", "8"})
        self.assertEqual(quests["7"]["nombres"]["es"], ['Misión "uno"', "Misión primera"])
        self.assertEqual(quests["8"]["nombres"]["es"], ["Misión dos"])
        evidence = quests["7"]["evidencia"]["nombre_es"]
        self.assertEqual(evidence["estado"], "forever")
        self.assertTrue(evidence["fuentes_por_locale"]["esES"].endswith("/esES.lua#L2"))
        self.assertTrue(evidence["fuentes_por_locale"]["esMX"].endswith("/esMX.lua#L1"))

    def test_old_cache_is_compatible_and_changed_bytes_are_rejected(self):
        with TemporaryDirectory() as temp:
            directory = Path(temp)
            self.assertEqual(import_spanish_titles(directory), {"misiones": {}})
            (directory / "questie-forever-quests-esES.lua").write_bytes(b"return {}")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                import_spanish_titles(directory)

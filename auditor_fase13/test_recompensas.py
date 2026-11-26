import unittest

from recompensas import _learning, audit_learning


class RewardTests(unittest.TestCase):
    def test_learning_uses_player_effects_and_automatic_skill_recipes(self):
        base = {"DifficultyID": "0", "ImplicitTarget_0": "1", "ImplicitTarget_1": "0", "SpellID": "60"}
        effects = [
            {**base, "Effect": "36", "EffectTriggerSpell": "256"},
            {**base, "Effect": "36", "EffectTriggerSpell": "257", "ImplicitTarget_0": "5"},
            {**base, "Effect": "36", "EffectTriggerSpell": "258", "DifficultyID": "1"},
            {**base, "Effect": "36", "EffectTriggerSpell": "259", "ImplicitTarget_0": "0"},
            {**base, "Effect": "36", "EffectTriggerSpell": "260", "ImplicitTarget_0": "0", "ImplicitTarget_1": "5"},
            {**base, "Effect": "44", "EffectMiscValue_0": "40", "EffectBasePointsF": "2"},
        ]
        recipe = {"SkillLine": "40", "AcquireMethod": "1", "MinSkillLineRank": "1", "ClassMask": "8",
                  "RaceMasks_0": "0", "RaceMasks_1": "0"}
        recipes = [{**recipe, "Spell": "8681"}, {**recipe, "Spell": "8682", "AcquireMethod": "0"},
                   {**recipe, "Spell": "8683", "MinSkillLineRank": "2"}, {**recipe, "Spell": "8684", "RaceMasks_0": "1"}]
        result = _learning(effects, recipes)
        self.assertEqual(result, {60: {"directo": [256], "destino_sin_declarar": [259], "por_habilidad": [
            {"hechizo": 8681, "linea": 40, "rango": 1, "mascara_clase": 8}]}})

    def test_route_audit_deduplicates_and_distinguishes_reward_display_from_learning(self):
        entries = [{"origen": "mision", "mision": 1, "id": spell} for spell in (2, 3, 4, 5, 6)]
        a = {"id": "a", "clase": "ROGUE", "hechizosExtra": entries}
        b = {**a, "id": "b"}
        c = {**a, "id": "c", "clase": "HUNTER"}
        catalog = {"misiones": {"1": {"estado": "forever", "fuente": "tabla", "habilidades_recompensa": {"mostradas": [6]},
                                       "aprendizaje_recompensa": {"directo": [2], "destino_sin_declarar": [4],
                                                                  "por_habilidad": [{"hechizo": 3, "mascara_clase": 8}]}}}}
        result = audit_learning([a, b], catalog)
        self.assertEqual(result["total"], 5)
        self.assertEqual(result["resumen"], {"efecto_de_aprendizaje": 1, "aprendizaje_por_habilidad": 1,
                                             "destino_de_aprendizaje_pendiente": 1, "pendiente": 1, "indicio_de_recompensa": 1})
        self.assertEqual(result["declaraciones"][0]["rutas_por_estado"], {"efecto_de_aprendizaje": ["a", "b"]})
        mixed = audit_learning([a, c], catalog)
        self.assertEqual(mixed["declaraciones"][1]["rutas_por_estado"], {"aprendizaje_por_habilidad": ["a"], "pendiente": ["c"]})


if __name__ == "__main__":
    unittest.main()

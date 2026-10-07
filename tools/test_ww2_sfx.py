#!/usr/bin/env python3
"""Offline, asset-level audio QA; run with python3 tools/test_ww2_sfx.py."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np

import build_ww2_sfx as bank
import sfx_dsp as dsp


class EffectsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.specs, cls.research, cls.categories = bank.specifications()
        cls.by_key = {cue.key: cue for cue in cls.specs}

    def test_every_technology_has_four_unique_phases(self):
        source = json.loads((bank.ROOT / "data/common/technologies.json").read_text())
        self.assertEqual(set(self.research), set(source["techs"]))
        for phases in self.research.values():
            self.assertEqual(set(phases), set(bank.PHASES))
            self.assertEqual(len(set(phases.values())), 4)
            self.assertTrue(all(key in self.by_key for key in phases.values()))

    def test_repeatable_and_future_branches_have_fallbacks(self):
        source = json.loads((bank.ROOT / "data/common/technologies.json").read_text())
        self.assertEqual(set(self.categories), set(source["categories"]))
        for phases in self.categories.values():
            self.assertEqual(set(phases), set(bank.PHASES))

    def test_render_is_identical_independent_of_build_order(self):
        cue = self.by_key["research_radar_1_done"]
        first = bank.render(cue, 0)
        bank.render(self.by_key["war_declared_on"], 1)
        np.testing.assert_array_equal(first, bank.render(cue, 0))

    def test_variations_and_phases_are_real_distinct_buffers(self):
        outputs = [bank.render(self.by_key["select_infantry"], i) for i in range(3)]
        outputs += [bank.render(self.by_key[key], 0) for key in self.research["radar_1"].values()]
        hashes = [hashlib.sha256(x.tobytes()).digest() for x in outputs]
        self.assertEqual(len(set(hashes)), len(hashes))

    def test_versioned_bank_has_no_music_paths_or_music_recipes(self):
        catalog = json.loads((bank.DEFAULT_OUT / "catalog.json").read_text())
        for cue in catalog["sounds"].values():
            for path in cue["files"]:
                self.assertTrue(path.startswith("res://assets/audio/ww2/"))
                self.assertTrue(path.endswith(".wav"))
                self.assertNotIn("/music/", path)
        self.assertEqual(len(catalog["sounds"]), len(self.specs))

    def test_entire_bank_passes_format_clipping_duplicates_and_attack_checks(self):
        report = bank.validate(bank.DEFAULT_OUT, self.specs)
        self.assertEqual(report["problems"], [])
        self.assertEqual(report["files"], sum(cue.variants for cue in self.specs))

    def test_pcm_roundtrip_stays_within_quantization_error(self):
        import wave
        x = bank.render(self.by_key["ui_click"], 0)
        with tempfile.TemporaryDirectory(prefix="iron-front-sfx-test-") as folder:
            path = Path(folder) / "roundtrip.wav"
            dsp.write_wav(path, x)
            with wave.open(str(path), "rb") as stream:
                self.assertEqual(stream.getparams()[:3], (1, 2, 48000))
                y = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2") / 32767
            self.assertLess(float(np.max(np.abs(x-y))), 1 / 32767)
            self.assertEqual(float(y[0]), 0)
            self.assertEqual(float(y[-1]), 0)


if __name__ == "__main__": unittest.main(verbosity=2)

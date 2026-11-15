"""tools/seeds/test_teleports.py — teleports.py without the network: tiny fixture tables, the real
seed file read as data, and the apply writer on a fixture copy.

Run: python3 -m unittest discover -s tools/seeds -p 'test_*.py'

Mutation check (2026-11-15): deleting the `if unruled:` refusal at the top of
teleports.plan_apply turns test_apply_refuses_while_anything_is_unruled red; restoring it turns it
green again.
"""

from __future__ import annotations

import gzip
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import teleports  # noqa: E402

MAP = """ID,Directory,MapName_lang,InstanceType,ExpansionID
1001,ScarletHalls,"Scarlet Halls",1,0
1004,ScarletMonastery,"Scarlet Monastery",1,0
1007,Scholomance,"Scholomance",1,0
289,OldScholomance,"Scholomance",1,0
2520,Brackenhide,"Brackenhide Hollow",1,9
2652,Stonevault,"The Stonevault",1,10
2296,Nathria,"Castle Nathria",2,8
0,Azeroth,"Eastern Kingdoms",0,0
"""
GFA = """ID,FullName_lang,MapID
1,"Scarlet Halls (Normal)",1001
2,"Scarlet Monastery (Normal)",1004
3,"Scholomance (Normal)",1007
4,"Brackenhide Hollow (Mythic Keystone)",2520
5,"The Stonevault (Mythic Keystone)",2652
6,"Castle Nathria",2296
7,"Questing",0
"""
SPELL_NAME = """ID,Name_lang
131229,"Path of the Scarlet Mitre"
131231,"Path of the Scarlet Blade"
131232,"Path of the Necromancer"
393267,"Path of the Rotting Woods"
445269,"Path of the Corrupted Foundry"
373190,"Path of the Sire"
900001,"Path of the Brand New Vault"
900002,"Path of Nowhere"
900003,"Path of the Passive Thing"
900004,"Path of the Muddle"
"""
SPELL = """ID,NameSubtext_lang,Description_lang,AuraDescription_lang
131229,"Scarlet Monastery","Teleport to the entrance to Scarlet Monastery.",
131231,"Scarlet Halls","Teleport to the entrance to Scarlet Halls.",
131232,"Scholomance","Teleport to the entrance of Scholomance.",
393267,"Brackenhide Hollow","Teleport to the entrance to Brackenhide Hollow.",
445269,"The Stonevault","Teleport to the entrance to The Stonevault.",
373190,"Castle Nathria","Teleport to the entrance of Castle Nathria.",
900001,"The Stonevault","Teleport to the entrance to the Stonevault.",
900002,,"Returns you to $z.",
900003,,"Teleport to the entrance to Scarlet Halls.",
900004,"Waterworks","Teleport to the entrance to Scarlet Halls.",
"""
SPELL_EFFECT = """ID,DifficultyID,EffectIndex,Effect,ImplicitTarget_0,ImplicitTarget_1,SpellID
1,0,0,252,1,17,131229
2,0,0,252,1,17,131231
3,0,0,252,1,17,131232
4,0,0,252,1,17,393267
5,0,0,252,1,17,445269
6,0,0,252,1,17,373190
7,0,0,252,1,17,900001
8,0,0,252,1,9,900002
9,0,0,6,1,0,900003
10,1,0,252,1,17,900003
11,0,0,15,1,17,900004
"""
TABLES = {"Map": MAP, "GroupFinderActivity": GFA, "SpellName": SPELL_NAME, "Spell": SPELL,
          "SpellEffect": SPELL_EFFECT}

SEEDS = "\r\n".join([
    "local _, NS = ...",
    "",
    "NS.TeleportSpells = {",
    "",
    "    -- ===== Mists of Pandaria =====",
    "    -- Dungeons",
    "    [1001] = 131229,              -- Scarlet Monastery               (Path of the Scarlet Mitre)",
    "    [1004] = 131231,              -- Scarlet Halls                   (Path of the Scarlet Blade)",
    "    [1007] = 131232,              -- Scholomance                     (Path of the Necromancer)",
    "",
    "    -- ===== Shadowlands =====",
    "    -- Raids",
    "    [2296] = 373190,              -- Castle Nathria                  (Path of the Sire)",
    "",
    "    -- ===== Dragonflight =====",
    "    -- Dungeons",
    "    [2080] = 393267,              -- Brackenhide Hollow              (Path of the Rotting Woods)",
    "",
    "    -- ===== The War Within =====",
    "    -- Dungeons",
    "    [2652] = 445269,              -- The Stonevault                  (Path of the Corrupted Foundry)",
    "}",
    "",
])


def fixture_tables(root: Path, gz: bool = False) -> dict[str, Path]:
    out = {}
    for name, text in TABLES.items():
        if gz:
            path = root / ("%s.csv.gz" % name)
            with gzip.open(path, "wb") as handle:
                handle.write(text.encode("utf-8"))
        else:
            path = root / ("%s.csv" % name)
            path.write_text(text, encoding="utf-8")
        out[name] = path
    return out


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.build = teleports.Build(fixture_tables(self.root))
        self.rows = teleports.read_seeds(SEEDS)
        self.doc = teleports.derive_doc(self.build, self.rows, "1.2.3.4", "2026-11-15", "fixture")

    def tearDown(self):
        self.tmp.cleanup()

    def keys(self):
        return set(teleports.all_keys(self.doc))


class TheSeedFile(unittest.TestCase):
    def test_format_row_reproduces_every_shipped_row_byte_for_byte(self):
        text = teleports.SEEDS_PATH.read_bytes().decode("utf-8")
        lines = text.replace("\r\n", "\n").split("\n")
        rows = teleports.read_seeds(text)
        self.assertGreater(len(rows), 50)
        for row in rows:
            self.assertEqual(teleports.format_row(row["indent"], row["map"], row["spells"], row["dungeon"],
                                                  row["names"]), lines[row["line"]])

    def test_list_rows_and_their_names(self):
        rows = {r["map"]: r for r in teleports.read_seeds(teleports.SEEDS_PATH.read_text(encoding="utf-8"))}
        self.assertEqual(rows[1209]["spells"], [159898, 1254557])
        self.assertEqual(rows[1209]["names"], ["Path of the Skies", "Path of the Crowning Pinnacle"])
        self.assertEqual(rows[1822]["names"], ["Path of the Besieged Harbor"] * 2)
        self.assertEqual(rows[2296]["subsection"], "Raids")
        self.assertNotIn(0, rows)  # the commented `[xxxx]` reserved slots are not rows

    def test_a_duplicate_map_is_refused(self):
        with self.assertRaises(SystemExit):
            teleports.read_seeds(SEEDS.replace("[1004]", "[1001]"))


class Destination(Base):
    def test_exact_name_resolves(self):
        self.assertEqual(self.build.destination(393267)["resolved"], 2520)

    def test_a_leading_the_is_tried_both_ways(self):
        self.assertEqual(self.build.destination(445269)["resolved"], 2652)
        self.assertEqual(self.build.destination(900001)["resolved"], 2652)

    def test_two_maps_of_one_name_narrow_to_the_one_with_an_activity(self):
        dest = self.build.destination(131232)
        self.assertEqual(dest["named"], [289, 1007])
        self.assertEqual(dest["resolved"], 1007)

    def test_no_entrance_text_is_unresolved(self):
        dest = self.build.destination(900002)
        self.assertIsNone(dest["resolved"])
        self.assertIn("no entrance", dest["why"])

    def test_a_subtext_naming_somewhere_else_is_a_conflict(self):
        self.assertIn("Waterworks", self.build.destination(900004)["conflict"])
        self.assertEqual(self.build.destination(131229)["conflict"], "")


class Flags(Base):
    def test_the_swapped_scarlet_pair_is_flagged_with_its_rekey(self):
        by_key = {f["key"]: f for f in self.doc["flags"]}
        self.assertEqual(by_key["shipped:pairing:1001:131229"]["rekeyTo"], 1004)
        self.assertEqual(by_key["shipped:pairing:1004:131231"]["rekeyTo"], 1001)
        self.assertIn("shipped:map-renamed:1001", by_key)

    def test_a_missing_map_is_flagged_three_ways(self):
        self.assertTrue({"shipped:map-missing:2080", "shipped:no-activity:2080",
                         "shipped:pairing:2080:393267"} <= self.keys())

    def test_good_rows_raise_nothing(self):
        for map_id in (1007, 2296, 2652):
            self.assertFalse([f for f in self.doc["flags"] if f["map"] == map_id], map_id)

    def test_spell_flags(self):
        text = SEEDS.replace("131232,  ", "999999,  ").replace("(Path of the Sire)", "(Path of the Sir)")
        doc = teleports.derive_doc(self.build, teleports.read_seeds(text), "b", "2026-11-15", "f")
        keys = set(teleports.all_keys(doc))
        self.assertIn("shipped:spell-missing:1007:999999", keys)
        self.assertIn("shipped:spell-renamed:2296:373190", keys)

    def test_not_a_teleport_and_wrong_subsection(self):
        text = SEEDS.replace("[2652] = 445269,", "[2652] = 900003,").replace(
            "(Path of the Corrupted Foundry)", "(Path of the Passive Thing)").replace(
            "    -- Raids\r\n    [2296]", "    -- Dungeons\r\n    [2296]")
        doc = teleports.derive_doc(self.build, teleports.read_seeds(text), "b", "2026-11-15", "f")
        keys = set(teleports.all_keys(doc))
        self.assertIn("shipped:not-teleport:2652:900003", keys)  # effect 252 only at DifficultyID 1
        self.assertIn("shipped:wrong-section:2296", keys)


class Candidates(Base):
    def test_only_unshipped_path_of_teleports(self):
        got = {c["spell"]: c for c in self.doc["candidates"]}
        self.assertEqual(sorted(got), [900001, 900002, 900004])  # 900003 is not a teleport at difficulty 0
        self.assertEqual(got[900001]["resolved"], 2652)
        self.assertIsNone(got[900002]["resolved"])


class Rulings(unittest.TestCase):
    def test_well_formed_rulings_record(self):
        r = {}
        teleports.set_ruling(r, "shipped:pairing:1001:131229", "rekey", "swapped")
        teleports.set_ruling(r, "shipped:map-renamed:2441", "keep", "abbreviated")
        teleports.set_ruling(r, "candidate:412555", "reject", "a hearthstone")
        self.assertEqual(len(r), 3)

    def test_malformed_rulings_are_refused(self):
        for key, ruling, reason in (("pairing:1001", "keep", "x"),
                                    ("shipped:nonsense:1001", "keep", "x"),
                                    ("shipped:pairing:1001", "keep", "x"),        # a spell kind with no spell
                                    ("shipped:map-missing:2080:1", "keep", "x"),  # a map kind with a spell
                                    ("candidate:1", "keep", "x"),
                                    ("shipped:map-missing:2080", "accept", "x"),
                                    ("candidate:1", "accept", ""),
                                    ("candidate:1", "accept", "two\nlines")):
            with self.assertRaises(SystemExit, msg=key):
                teleports.set_ruling({}, key, ruling, reason)


class Apply(Base):
    def rule_all(self, **overrides):
        rulings = {}
        for key in teleports.all_keys(self.doc):
            ruling = "reject" if key.startswith("candidate:") else "keep"
            if key.startswith("shipped:") and (":1001" in key or ":1004" in key or ":2080" in key):
                ruling = "rekey"
            ruling = overrides.get(key, ruling)
            rulings[key] = {"ruling": ruling, "reason": "test"}
        return rulings

    def test_apply_refuses_while_anything_is_unruled(self):
        rulings = self.rule_all()
        rulings.pop("candidate:900001")
        with self.assertRaises(SystemExit):
            teleports.apply_seeds(SEEDS, self.doc, rulings)

    def test_rekeys_swap_sort_and_keep_crlf(self):
        out, changes = teleports.apply_seeds(SEEDS, self.doc, self.rule_all())
        self.assertNotIn("\n", out.replace("\r\n", ""))
        lines = out.split("\r\n")
        mop = [l for l in lines if "Scarlet" in l]
        self.assertTrue(mop[0].startswith("    [1001] = 131231,"))
        self.assertIn("Scarlet Halls", mop[0])
        self.assertTrue(mop[1].startswith("    [1004] = 131229,"))
        self.assertIn("    [2520] = 393267,              -- Brackenhide Hollow              (Path of the Rotting Woods)",
                      lines)
        self.assertEqual(len(changes), 3)

    def test_a_second_apply_changes_nothing(self):
        out, _ = teleports.apply_seeds(SEEDS, self.doc, self.rule_all())
        again, _ = teleports.apply_seeds(out, self.doc, self.rule_all())
        self.assertEqual(again, out)

    def test_an_all_keep_ruling_leaves_the_file_byte_identical(self):
        rulings = {k: {"ruling": "keep" if k.startswith("shipped:") else "reject", "reason": "t"}
                   for k in teleports.all_keys(self.doc)}
        self.assertEqual(teleports.apply_seeds(SEEDS, self.doc, rulings)[0], SEEDS)

    def test_remove_a_row(self):
        out, _ = teleports.apply_seeds(SEEDS, self.doc, self.rule_all(**{"shipped:map-missing:2080": "remove",
                                                                        "shipped:no-activity:2080": "keep",
                                                                        "shipped:pairing:2080:393267": "keep"}))
        self.assertNotIn("393267", out)

    def test_remove_and_rekey_on_one_row_is_refused(self):
        with self.assertRaises(SystemExit):
            teleports.apply_seeds(SEEDS, self.doc, self.rule_all(**{"shipped:map-missing:2080": "remove"}))

    def test_an_accepted_candidate_joins_its_row(self):
        out, _ = teleports.apply_seeds(SEEDS, self.doc, self.rule_all(**{"candidate:900001": "accept"}))
        self.assertIn("[2652] = { 445269, 900001 },  -- The Stonevault                  "
                      "(Path of the Corrupted Foundry / Path of the Brand New Vault)", out)

    def test_an_unresolved_or_conflicted_candidate_is_never_accepted(self):
        for key in ("candidate:900002", "candidate:900004"):
            with self.assertRaises(SystemExit, msg=key):
                teleports.apply_seeds(SEEDS, self.doc, self.rule_all(**{key: "accept"}))


class Bundle(unittest.TestCase):
    def test_replay_and_the_command_loop_run_offline(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bundle = root / "2026-11-15-retail"
            (bundle / "raw").mkdir(parents=True)
            fixture_tables(bundle / "raw", gz=True)
            (bundle / "candidates.json").write_text(json.dumps({"build": "1.2.3.4", "fetched": "then"}))
            seeds, rulings = root / "TeleportSpells.lua", root / "rulings.json"
            seeds.write_bytes(SEEDS.encode("utf-8"))
            common = ["--seeds", str(seeds), "--rulings", str(rulings)]
            self.assertEqual(teleports.main(common + ["derive", "--flavor", "retail", "--bundle", str(bundle),
                                                      "--date", "2026-11-15", "--replay"]), 0)
            doc = json.loads((bundle / "candidates.json").read_text(encoding="utf-8"))
            self.assertEqual(doc["build"], "1.2.3.4")
            self.assertTrue((bundle / "SOURCES.md").read_bytes().count(b"\r\n") > 5)
            self.assertEqual(teleports.main(common + ["check", "--bundle", str(bundle)]), 1)
            tsv = root / "r.tsv"
            tsv.write_text("\n".join("%s\t%s\tfixture" % (k, "reject" if k.startswith("candidate") else "keep")
                                     for k in teleports.all_keys(doc)), encoding="utf-8")
            teleports.main(common + ["rule", "--tsv", str(tsv), "--bundle", str(bundle)])
            self.assertEqual(teleports.main(common + ["check", "--bundle", str(bundle)]), 0)
            teleports.main(common + ["report", "--bundle", str(bundle), "--date", "2026-11-15"])
            self.assertIn("None: the file already matches", (bundle / "RULINGS.md").read_text(encoding="utf-8"))
            teleports.main(common + ["apply", "--bundle", str(bundle), "--date", "2026-11-15"])
            self.assertEqual(seeds.read_bytes(), SEEDS.encode("utf-8"))
            with self.assertRaises(SystemExit):  # a key the bundle never proposed
                tsv.write_text("candidate:1\treject\tx", encoding="utf-8")
                teleports.main(common + ["rule", "--tsv", str(tsv), "--bundle", str(bundle)])

    def test_status_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(teleports.status_line("9.9", []), "NEW 9.9 (no bundle yet)")
            b = root / "2026-11-15-retail"
            b.mkdir()
            (b / "candidates.json").write_text(json.dumps({"build": "9.9"}))
            self.assertEqual(teleports.status_line("9.9", [b]), "CURRENT 9.9 (2026-11-15-retail)")
            self.assertEqual(teleports.status_line("10.0", [b]), "NEW 10.0 (last ruled 9.9, 2026-11-15-retail)")


if __name__ == "__main__":
    unittest.main()

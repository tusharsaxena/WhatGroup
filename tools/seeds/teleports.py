#!/usr/bin/env python3
"""tools/seeds/teleports.py — re-validate defaults/TeleportSpells.lua against a wago.tools build.

WHAT THIS IS
    defaults/TeleportSpells.lua maps a dungeon's (or raid's) instance map id to its "Path of ..."
    teleport spell id, one row per map, with the dungeon's name and the spell's own name in the
    trailing comment. Nothing in the client reports a wrong row: a wrong spell id renders grayed and
    "(not learned)", and a wrong map id never matches anything (the file's own header says so).
    This tool re-checks every row against ONE pinned Retail build (wago.tools product `wow`,
    Ka0s WoW Addon Standard clients-§10) and turns what it finds into FLAGS and CANDIDATES, each of
    which needs a ruling recorded as data. A ruling is keyed by map and spell id, never by build,
    and it holds until the thing it ruled on stops being proposed, so a later run shows only what
    is new.

    The destination. A Path-of spell is effect 252 (TELEPORT_UNITS_WITH_VISUAL_LOADING_SCREEN) or 15
    (TELEPORT_UNITS) on target 17 (DEST_DB): the coordinates are server-side and no client table
    holds them. What the client does hold is the spell's own text, `Spell.Description_lang`,
    "Teleport to the entrance to <name>." That name is matched exactly against `Map.MapName_lang`
    over the party and raid maps (InstanceType 1 and 2); when more than one map carries the name,
    the ones with a `GroupFinderActivity` row win, because that is the table
    C_LFGList.GetActivityInfoTable's mapID (this file's key) comes from. One map left is a resolved
    destination. Anything else is unresolved, and an unresolved destination is never applied.

    Flags (key `shipped:<kind>:<map>` or `shipped:<kind>:<map>:<spell>`; keep, remove or rekey):
        map-missing     the build's Map table has no row for the key
        not-instance    the map is not a party or raid instance (InstanceType 1 or 2)
        wrong-section   the map's InstanceType disagrees with the file's Dungeons / Raids subsection
                        (ExpansionID is not checked: the build files the MoP Scarlet and Scholomance
                        remakes and Manaforge Omega under 0, Classic, so it is no witness)
        map-renamed     the dungeon name in the comment disagrees with Map.MapName_lang
        no-activity     no GroupFinderActivity row carries the map, so the LFG API never hands it over
        spell-missing   the build's SpellName has no row for the spell
        spell-renamed   the spell's name disagrees with the name in the comment's parentheses
        not-teleport    the spell has no effect 15 or 252 at DifficultyID 0
        pairing         the spell's destination is not the row's map (resolved elsewhere, or not at all)

    Candidates (key `candidate:<spell>`; accept or reject): a SpellName row named "Path of ..."
    with a teleport effect that no row ships. Its destination is resolved as above; `apply` refuses
    to insert one whose destination is unresolved.

THE STEPS (the contract is docs/validate-seeds.md)
    python3 tools/seeds/teleports.py status --flavor retail
    python3 tools/seeds/teleports.py derive --flavor retail --bundle docs/seed-research/<date>-retail --date <date>
    python3 tools/seeds/teleports.py check  --bundle docs/seed-research/<date>-retail
    python3 tools/seeds/teleports.py rule   --tsv <file> --bundle docs/seed-research/<date>-retail
    python3 tools/seeds/teleports.py report --bundle docs/seed-research/<date>-retail --date <date>
    python3 tools/seeds/teleports.py apply  --bundle docs/seed-research/<date>-retail --date <date>

    `derive` pins one build (`--build`, else the live `wow` build), fetches the tables into the
    git-ignored .cache/, freezes them into the bundle's raw/*.csv.gz and writes SOURCES.md and
    candidates.json; `--replay` re-derives from the bundle's raw/ alone, with no network. `rule` is
    the only writer of retail_rulings.json. `apply` refuses while anything is unruled, writes only
    what a ruling says, keeps the file's line endings and layout, and changes nothing on a second run.

The shape (status / derive / rule / check / report / apply, rulings as data keyed by id) is copied
from Aura Master's tools/spell-research/retail.py, not imported: a shared helper for the build pin,
the cache, the bundle and the rulings is the open question of LibKa0s#91.

Python 3.8+ and its standard library only.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import re
import shutil
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SEEDS_PATH = ROOT / "defaults" / "TeleportSpells.lua"
RULINGS_PATH = HERE / "retail_rulings.json"
RESEARCH = ROOT / "docs" / "seed-research"
CACHE_DIR = HERE / ".cache"

FLAVORS = {"retail": "wow"}  # the roster lists WhatGroup as Retail only (WowAddonStandards ADDONS.md)
BUILDS_URL = "https://wago.tools/api/builds"
CSV_URL = "https://wago.tools/db2/{table}/csv?build={build}"
USER_AGENT = "WhatGroup-seed-check/1.0 (+https://github.com/tusharsaxena/WhatGroup)"
CHUNK = 1 << 20  # SpellEffect is ~57 MB and is streamed, never read into one string

TABLES = (
    ("Map", "MapName_lang, InstanceType, ExpansionID: the key exists, is a dungeon or raid, and its name"),
    ("GroupFinderActivity", "MapID: the map ids C_LFGList.GetActivityInfoTable can hand the addon"),
    ("SpellName", "Name_lang: the spell exists, its name, and the \"Path of ...\" candidate set"),
    ("Spell", "Description_lang, NameSubtext_lang: the destination the spell's own text names"),
    ("SpellEffect", "Effect 15 / 252 at DifficultyID 0: the spell really is a teleport"),
)

TELEPORT_EFFECTS = frozenset({15, 252})  # TELEPORT_UNITS, TELEPORT_UNITS_WITH_VISUAL_LOADING_SCREEN
INSTANCE_TYPES = {1: "Dungeons", 2: "Raids"}
EXPANSIONS = {0: "Classic", 1: "The Burning Crusade", 2: "Wrath of the Lich King", 3: "Cataclysm",
              4: "Mists of Pandaria", 5: "Warlords of Draenor", 6: "Legion", 7: "Battle for Azeroth",
              8: "Shadowlands", 9: "Dragonflight", 10: "The War Within", 11: "Midnight"}
CANDIDATE_PREFIX = "Path of "
DESTINATION = re.compile(r"^Teleport to the entrance (?:to|of) (?P<name>.+?)\.?\s*$")

FLAG_KINDS = ("map-missing", "not-instance", "wrong-section", "map-renamed", "no-activity",
              "spell-missing", "spell-renamed", "not-teleport", "pairing")
SPELL_KINDS = frozenset({"spell-missing", "spell-renamed", "not-teleport", "pairing"})
FLAG_RULINGS = ("keep", "remove", "rekey")
CANDIDATE_RULINGS = ("accept", "reject")
KEY = re.compile(r"^(?:candidate:(?P<cand>\d+)|shipped:(?P<kind>[a-z-]+):(?P<map>\d+)(?::(?P<spell>\d+))?)$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

ROW = re.compile(r"^(?P<indent>\s*)\[(?P<map>\d+)\]\s*=\s*(?P<value>\{[^}]*\}|\d+)\s*,\s*--\s*"
                 r"(?P<dungeon>.+?)\s+\((?P<names>.+)\)\s*$")
SECTION = re.compile(r"^\s*--\s*=====\s*(?P<name>.+?)\s*=====\s*$")
SUBSECTION = re.compile(r"^\s*--\s*(?P<name>Dungeons|Raids)\s*$")


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Files: every text file this tool writes is CRLF (the repo's .gitattributes, line-endings-§2)
# ---------------------------------------------------------------------------

def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))


def write_json(path: Path, doc) -> None:
    write_text(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


def load_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# wago.tools
# ---------------------------------------------------------------------------

def http_get(url: str, accept: str = "*/*"):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    try:
        return urllib.request.urlopen(req, timeout=300)
    except urllib.error.HTTPError as err:  # 403: the User-Agent; 400: a table the build lacks
        raise SystemExit("HTTP %s fetching %s: %s" % (err.code, url, err.reason))
    except urllib.error.URLError as err:
        raise SystemExit("Could not reach %s: %s (a run that is not --replay needs the network)"
                         % (url, err.reason))


def live_build(product: str) -> str:
    data = json.load(http_get(BUILDS_URL, accept="application/json"))
    builds = data.get(product) or []
    if not builds:
        raise SystemExit("The builds API returned no %r builds; pass --build." % product)
    return builds[0]["version"]


def fetch_table(table: str, build: str, cache_dir: Path) -> tuple[Path, str]:
    """`(cached csv, the response's Date header or "cached")`: one table of one build, streamed to a
    `.part` file that is renamed only once complete, so a broken transfer is never parsed."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    dest = cache_dir / ("%s-%s.csv" % (table, build))
    if dest.exists():
        log("  %-20s cached (%.1f MB)" % (table, dest.stat().st_size / 1e6))
        return dest, "cached"
    tmp = dest.with_suffix(".csv.part")
    url = CSV_URL.format(table=table, build=build)
    log("  %-20s fetching %s" % (table, url))
    with http_get(url, accept="text/csv") as response, tmp.open("wb") as handle:
        stamp = response.headers.get("Date", "unknown")
        shutil.copyfileobj(response, handle, CHUNK)
    tmp.replace(dest)
    return dest, stamp


def iter_csv(path: Path):
    """Rows of a CSV or .csv.gz as dicts, streamed; columns are addressed by header name only."""
    if path.suffix == ".gz":
        handle = io.TextIOWrapper(gzip.open(path, "rb"), encoding="utf-8", newline="")
    else:
        handle = path.open("r", encoding="utf-8", newline="")
    with handle:
        yield from csv.DictReader(handle)


def _int(value) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


# ---------------------------------------------------------------------------
# The build's facts
# ---------------------------------------------------------------------------

class Build:
    """The few columns of the five tables this check reads."""

    def __init__(self, tables: dict[str, Path]):
        self.maps: dict[int, dict] = {}
        for row in iter_csv(tables["Map"]):
            self.maps[_int(row["ID"])] = {"name": row["MapName_lang"], "type": _int(row["InstanceType"]),
                                          "expansion": _int(row["ExpansionID"])}
        self.activity = {_int(r["MapID"]) for r in iter_csv(tables["GroupFinderActivity"])} - {0}
        self.names = {_int(r["ID"]): r["Name_lang"] for r in iter_csv(tables["SpellName"])}
        self.text: dict[int, tuple[str, str]] = {}
        for row in iter_csv(tables["Spell"]):
            self.text[_int(row["ID"])] = (row["Description_lang"], row["NameSubtext_lang"])
        self.teleports: set[int] = set()
        for row in iter_csv(tables["SpellEffect"]):
            if _int(row["Effect"]) in TELEPORT_EFFECTS and _int(row["DifficultyID"]) == 0:
                self.teleports.add(_int(row["SpellID"]))
        self.by_name: dict[str, list[int]] = defaultdict(list)
        for map_id, m in self.maps.items():
            if m["type"] in INSTANCE_TYPES:
                self.by_name[m["name"].lower()].append(map_id)

    def destination(self, spell: int) -> dict:
        """`{text, named, resolved, why}`: the maps the spell's description names, and the one map
        it resolves to (or None, with why)."""
        desc, subtext = self.text.get(spell, ("", ""))
        match = DESTINATION.match(desc or "")
        out = {"text": desc or "", "subtext": subtext or "", "named": [], "resolved": None, "why": "",
               "conflict": ""}
        if not match:
            out["why"] = "the description names no entrance"
            return out
        name = match.group("name").strip()
        named = list(self.by_name.get(name.lower(), ()))
        if not named and name.lower().startswith("the "):
            named = list(self.by_name.get(name[4:].lower(), ()))
        out["named"] = sorted(named)
        if not named:
            out["why"] = "no party or raid map is named %r" % name
            return out
        narrowed = [m for m in named if m in self.activity] if len(named) > 1 else named
        if len(narrowed) == 1:
            out["resolved"] = narrowed[0]
        else:
            out["why"] = "%d maps are named %r" % (len(named), name)
            return out
        sub = (subtext or "").strip().lower()
        if sub and sub != self.maps[out["resolved"]]["name"].lower() and sub != name.lower():
            out["conflict"] = "the subtext names %r" % subtext
        return out


# ---------------------------------------------------------------------------
# The seed file
# ---------------------------------------------------------------------------

def split_names(names: str, count: int) -> list[str]:
    """The parenthetical's names, one per spell: "A / B" for two that differ, one name for a
    re-issued spell under a second id (the file header's convention)."""
    parts = [p.strip() for p in names.split(" / ")]
    if len(parts) == count:
        return parts
    if len(parts) == 1:
        return parts * count
    raise SystemExit("TeleportSpells.lua: %r names %d spells for %d ids." % (names, len(parts), count))


def read_seeds(text: str) -> list[dict]:
    """Every live row, in file order, with its line index, section and subsection."""
    rows, section, subsection = [], None, None
    for index, line in enumerate(text.split("\n")):
        line = line.rstrip("\r")
        sec = SECTION.match(line)
        if sec:
            section, subsection = sec.group("name"), None
            continue
        sub = SUBSECTION.match(line)
        if sub:
            subsection = sub.group("name")
            continue
        row = ROW.match(line)
        if not row:
            continue
        spells = [int(s) for s in re.findall(r"\d+", row.group("value"))]
        rows.append({"line": index, "map": int(row.group("map")), "spells": spells,
                     "indent": row.group("indent"), "dungeon": row.group("dungeon"),
                     "names": split_names(row.group("names"), len(spells)),
                     "section": section, "subsection": subsection})
    seen = set()
    for row in rows:
        if row["map"] in seen:
            raise SystemExit("TeleportSpells.lua: map %d has two rows." % row["map"])
        seen.add(row["map"])
    return rows


def _pad(text: str, width: int) -> str:
    return text + " " * max(1, width - len(text))


def format_row(indent: str, map_id: int, spells: list[int], dungeon: str, names: list[str]) -> str:
    """One row in the file's own column layout (key 6, value 21, dungeon 32)."""
    value = ("%d," % spells[0]) if len(spells) == 1 else "{ %s }," % ", ".join(str(s) for s in spells)
    unique = []
    for name in names:
        if name not in unique:
            unique.append(name)
    return "%s%s= %s-- %s(%s)" % (indent, _pad("[%d]" % map_id, 7), _pad(value, 21), _pad(dungeon, 32),
                                  " / ".join(unique))


# ---------------------------------------------------------------------------
# Flags and candidates
# ---------------------------------------------------------------------------

def row_flags(build: Build, row: dict) -> list[dict]:
    out = []
    map_id, m = row["map"], build.maps.get(row["map"])
    dests = {s: build.destination(s) for s in row["spells"]}
    targets = {d["resolved"] for d in dests.values()}
    rekey_to = targets.pop() if len(targets) == 1 and None not in targets else None
    if rekey_to == map_id:
        rekey_to = None

    def flag(kind, detail, spell=None, **extra):
        key = "shipped:%s:%d" % (kind, map_id) + (":%d" % spell if spell is not None else "")
        doc = {"key": key, "kind": kind, "map": map_id, "spell": spell, "dungeon": row["dungeon"],
               "spells": list(row["spells"]), "detail": detail, "rekeyTo": rekey_to}
        doc.update(extra)
        out.append(doc)

    if m is None:
        flag("map-missing", "the build's Map has no row %d" % map_id)
    else:
        if m["type"] not in INSTANCE_TYPES:
            flag("not-instance", "InstanceType %d" % m["type"])
        elif row["subsection"] != INSTANCE_TYPES[m["type"]]:
            flag("wrong-section", "filed under %s; the map is InstanceType %d (%s)"
                 % (row["subsection"], m["type"], INSTANCE_TYPES[m["type"]]))
        if m["name"].lower() != row["dungeon"].lower():
            flag("map-renamed", "Map %d is %r" % (map_id, m["name"]), mapName=m["name"])
    if map_id not in build.activity:
        flag("no-activity", "no GroupFinderActivity row has MapID %d" % map_id)
    for spell, comment in zip(row["spells"], row["names"]):
        name = build.names.get(spell)
        if not name:
            flag("spell-missing", "the build's SpellName has no row %d" % spell, spell)
            continue
        if name.lower() != comment.lower():
            flag("spell-renamed", "%d is %r" % (spell, name), spell, spellName=name)
        if spell not in build.teleports:
            flag("not-teleport", "%d has no effect 15 or 252 at DifficultyID 0" % spell, spell)
        dest = dests[spell]
        if map_id not in dest["named"]:
            where = ("resolves to %d (%s)" % (dest["resolved"], build.maps[dest["resolved"]]["name"])
                     if dest["resolved"] else "unresolved: " + dest["why"])
            flag("pairing", "%r %s" % (dest["text"], where), spell, destination=dest["resolved"])
    return out


def candidates(build: Build, shipped: set[int]) -> list[dict]:
    out = []
    for spell in sorted(build.names):
        name = build.names[spell]
        if not name.startswith(CANDIDATE_PREFIX) or spell in shipped or spell not in build.teleports:
            continue
        dest = build.destination(spell)
        resolved = dest["resolved"]
        m = build.maps.get(resolved) if resolved else None
        out.append({"key": "candidate:%d" % spell, "spell": spell, "name": name,
                    "description": dest["text"], "subtext": dest["subtext"], "named": dest["named"],
                    "resolved": resolved, "why": dest["why"], "conflict": dest["conflict"],
                    "mapName": m["name"] if m else "", "instanceType": m["type"] if m else None,
                    "expansion": m["expansion"] if m else None,
                    "activity": bool(resolved and resolved in build.activity)})
    return out


def derive_doc(build: Build, rows: list[dict], build_id: str, date: str, fetched: str) -> dict:
    flags = [f for row in rows for f in row_flags(build, row)]
    shipped = {s for row in rows for s in row["spells"]}
    cands = candidates(build, shipped)
    return {"client": "retail", "product": FLAVORS["retail"], "build": build_id, "date": date,
            "fetched": fetched, "tool": "tools/seeds/teleports.py derive",
            "shipped": {"rows": len(rows), "spells": len(shipped)},
            "flags": flags, "candidates": cands}


def all_keys(doc: dict) -> list[str]:
    return [f["key"] for f in doc["flags"]] + [c["key"] for c in doc["candidates"]]


def unruled_keys(doc: dict, rulings: dict) -> list[str]:
    return [k for k in all_keys(doc) if k not in rulings]


# ---------------------------------------------------------------------------
# Rulings
# ---------------------------------------------------------------------------

def set_ruling(rulings: dict, key: str, ruling: str, reason: str) -> None:
    match = KEY.match(key or "")
    if not match:
        raise SystemExit("%r is not candidate:<spell> or shipped:<kind>:<map>[:<spell>]." % key)
    kind = match.group("kind")
    if kind is not None:
        if kind not in FLAG_KINDS:
            raise SystemExit("%r: unknown flag kind %r." % (key, kind))
        if (kind in SPELL_KINDS) != (match.group("spell") is not None):
            raise SystemExit("%r: a %s flag %s a spell id." % (key, kind,
                             "needs" if kind in SPELL_KINDS else "takes no"))
    allowed = FLAG_RULINGS if kind else CANDIDATE_RULINGS
    if ruling not in allowed:
        raise SystemExit("the ruling for %s must be %s; got %r." % (key, " or ".join(allowed), ruling))
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        raise SystemExit("the reason for %s must be one non-empty line." % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


def read_tsv(path: Path) -> list[tuple[str, str, str]]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit("%s: a ruling line is key<TAB>ruling<TAB>reason; got %r" % (path, line))
        out.append(tuple(p.strip() for p in parts))
    return out


# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

def plan_apply(doc: dict, rulings: dict, rows: list[dict]) -> dict:
    """`{map: {"rekey": map|None, "drop": set, "remove": bool, "add": [(spell, name)]}}` plus
    `inserts`, or a SystemExit naming what blocks it. Nothing unruled, nothing ambiguous."""
    unruled = unruled_keys(doc, rulings)
    if unruled:  # the guard test_teleports.py's mutation check was run against
        raise SystemExit("apply refused: %d key(s) unruled (`check` lists them)." % len(unruled))
    by_map = {row["map"]: row for row in rows}
    plan = {m: {"rekey": None, "drop": set(), "remove": False} for m in by_map}
    for f in doc["flags"]:
        ruling = rulings[f["key"]]["ruling"]
        # A flag acts only on the row it was raised on: once applied, the row has moved, gone or
        # changed, and a second apply against the same candidates.json must change nothing.
        if ruling == "keep" or f["map"] not in by_map or by_map[f["map"]]["spells"] != f["spells"]:
            continue
        entry = plan[f["map"]]
        if ruling == "rekey":
            if not f.get("rekeyTo"):
                raise SystemExit("apply refused: %s is ruled rekey but its destination is not resolved "
                                 "to one map." % f["key"])
            entry["rekey"] = f["rekeyTo"]
        elif f["spell"] is not None:
            entry["drop"].add(f["spell"])
        else:
            entry["remove"] = True
    for map_id, entry in plan.items():
        if entry["remove"] and entry["rekey"]:
            raise SystemExit("apply refused: map %d is ruled both remove and rekey." % map_id)
        if set(by_map[map_id]["spells"]) <= entry["drop"]:
            entry["remove"] = True
    final = {}
    for map_id, entry in plan.items():
        if entry["remove"]:
            continue
        target = entry["rekey"] or map_id
        if target in final:
            raise SystemExit("apply refused: maps %d and %d would both be keyed %d."
                             % (final[target], map_id, target))
        final[target] = map_id
    inserts = []
    for c in doc["candidates"]:
        if rulings[c["key"]]["ruling"] != "accept":
            continue
        if not c["resolved"] or c.get("conflict"):
            raise SystemExit("apply refused: %s is accepted but its destination is not one clear map (%s)."
                             % (c["key"], c["why"] or c["conflict"]))
        if any(c["spell"] in row["spells"] for row in rows):
            continue
        inserts.append(c)
    return {"rows": plan, "inserts": inserts, "final": final}


def _insert_at(lines: list[str], rows: list[dict], cand: dict) -> int:
    """The line index to insert a new row at: after the last row of the map's section and
    subsection, which must already exist (an owner adds a new expansion's header by hand)."""
    section = EXPANSIONS.get(cand["expansion"])
    sub = INSTANCE_TYPES.get(cand["instanceType"])
    lines_in = [r["line"] for r in rows if r["section"] == section and r["subsection"] == sub]
    if not lines_in:
        raise SystemExit("apply refused: %s goes under %s / %s, which the file has no rows in; add "
                         "the section by hand first." % (cand["key"], section, sub))
    return max(lines_in) + 1


def apply_seeds(text: str, doc: dict, rulings: dict) -> tuple[str, list[str]]:
    """The new file text and a change log. Keeps the file's terminator and every line it does not
    change; a second run on its own output changes nothing."""
    eol = "\r\n" if "\r\n" in text else "\n"
    lines = text.replace("\r\n", "\n").split("\n")
    rows = read_seeds("\n".join(lines))
    plan = plan_apply(doc, rulings, rows)
    by_map = {row["map"]: row for row in rows}
    names = {c["spell"]: c["name"] for c in doc["candidates"]}
    changes: list[str] = []
    rekeyed: set[int] = set()
    for map_id, entry in plan["rows"].items():
        row = by_map[map_id]
        if entry["remove"]:
            lines[row["line"]] = None
            changes.append("-[%d] %s" % (map_id, row["dungeon"]))
            continue
        spells = [s for s in row["spells"] if s not in entry["drop"]]
        kept = [n for s, n in zip(row["spells"], row["names"]) if s not in entry["drop"]]
        target = entry["rekey"] or map_id
        if spells == row["spells"] and target == map_id:
            continue
        lines[row["line"]] = format_row(row["indent"], target, spells, row["dungeon"], kept)
        if target != map_id:
            rekeyed.add(row["line"])
            changes.append("[%d] -> [%d] %s" % (map_id, target, row["dungeon"]))
        for spell in set(row["spells"]) - set(spells):
            changes.append("[%d] -%d" % (map_id, spell))
    for line_index in sorted(rekeyed):
        _sort_run(lines, line_index)
    lines = [l for l in lines if l is not None]
    for cand in sorted(plan["inserts"], key=lambda c: (c["resolved"], c["spell"])):
        target = cand["resolved"]
        current = read_seeds("\n".join(lines))
        existing = next((r for r in current if r["map"] == target), None)
        if existing:
            lines[existing["line"]] = format_row(existing["indent"], target,
                                                 existing["spells"] + [cand["spell"]], existing["dungeon"],
                                                 existing["names"] + [names[cand["spell"]]])
        else:
            at = _insert_at(lines, current, cand)
            lines.insert(at, format_row(current[0]["indent"], target, [cand["spell"]], cand["mapName"],
                                        [cand["name"]]))
            _sort_run(lines, at)
        changes.append("+[%d] %d %s" % (target, cand["spell"], cand["name"]))
    return eol.join(lines), changes


def _sort_run(lines: list, index: int) -> None:
    """Sort the contiguous run of row lines around `index` by map id, so a rekeyed row sits where
    the file's own order puts it."""
    def is_row(i):
        return 0 <= i < len(lines) and lines[i] is not None and ROW.match(lines[i] or "")
    lo = hi = index
    while is_row(lo - 1):
        lo -= 1
    while is_row(hi + 1):
        hi += 1
    run = lines[lo:hi + 1]
    run.sort(key=lambda l: int(ROW.match(l).group("map")))
    lines[lo:hi + 1] = run


# ---------------------------------------------------------------------------
# RULINGS.md
# ---------------------------------------------------------------------------

def _cell(text) -> str:
    return str(text if text is not None else "").replace("|", "\\|")


def format_rulings_md(doc: dict, rulings: dict, date: str, planned: list[str] | None = None) -> str:
    tally: dict[str, int] = defaultdict(int)
    for key in all_keys(doc):
        tally[rulings.get(key, {}).get("ruling", "unruled")] += 1
    lines = ["# Rulings — TeleportSpells re-validation, %s (Retail build %s)" % (doc["date"], doc["build"]), "",
             "Generated by `tools/seeds/teleports.py report` on %s from this bundle's `candidates.json` "
             "and `tools/seeds/retail_rulings.json`. Do not edit by hand." % date, "",
             "%d rows (%d spell ids) checked; %d flags, %d candidates: %s." % (
                 doc["shipped"]["rows"], doc["shipped"]["spells"], len(doc["flags"]), len(doc["candidates"]),
                 ", ".join("%d %s" % (n, r) for r, n in sorted(tally.items())) or "nothing to rule"), ""]
    unruled = unruled_keys(doc, rulings)
    if unruled:
        lines += ["## Unruled — %d" % len(unruled), ""] + ["- `%s`" % k for k in unruled] + [""]
    lines += ["## Shipped-row flags — %d" % len(doc["flags"]), ""]
    if doc["flags"]:
        lines += ["| Kind | Map | Spell | File comment | Build says | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- | --- | --- |"]
        for f in doc["flags"]:
            r = rulings.get(f["key"], {})
            lines.append("| %s | `%d` | %s | %s | %s | %s | %s |" % (
                f["kind"], f["map"], "`%d`" % f["spell"] if f["spell"] else "-", _cell(f["dungeon"]),
                _cell(f["detail"]), r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
    else:
        lines.append("None.")
    lines += ["", "## Candidates — %d" % len(doc["candidates"]), ""]
    if doc["candidates"]:
        lines += ["| Spell | Name | Description | Destination | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- | --- |"]
        for c in doc["candidates"]:
            r = rulings.get(c["key"], {})
            dest = ("`%d` %s" % (c["resolved"], c["mapName"])) if c["resolved"] else "unresolved: " + c["why"]
            if c.get("conflict"):
                dest += "; conflict: " + c["conflict"]
            lines.append("| `%d` | %s | %s | %s | %s | %s |" % (
                c["spell"], _cell(c["name"]), _cell(c["description"]), _cell(dest),
                r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
    else:
        lines.append("None.")
    lines.append("")
    if planned is not None:
        lines += ["## What `apply` writes — %d change(s) to `defaults/TeleportSpells.lua`" % len(planned), ""]
        lines += ["- `%s`" % c for c in planned] or ["None: the file already matches every ruling."]
        lines.append("")
    return "\n".join(lines)


def format_sources_md(doc: dict, sizes: dict[str, int]) -> str:
    lines = ["# Sources — TeleportSpells re-validation, %s" % doc["date"], "",
             "Generated by `tools/seeds/teleports.py derive`. Frozen: this directory is never edited after "
             "the run, apart from the hand-written `ANALYSIS.md` and the generated `RULINGS.md`.", "",
             "| Field | Value |", "| --- | --- |",
             "| Client | `retail` (Retail, wago product `%s`) |" % doc["product"],
             "| Build | `%s` |" % doc["build"],
             "| Fetched | %s |" % doc["fetched"],
             "| Builds API | <%s> |" % BUILDS_URL,
             "| Rows checked | %d (%d spell ids) |" % (doc["shipped"]["rows"], doc["shipped"]["spells"]), "",
             "## Tables", "", "| Table | Why | Gzipped | URL |", "| --- | --- | --- | --- |"]
    for table, why in TABLES:
        url = CSV_URL.format(table=table, build=doc["build"])
        lines.append("| `%s` | %s | %.1f MB | <%s> |" % (table, why, sizes.get(table, 0) / 1e6, url))
    lines += ["", "The gzipped exports are in `raw/`; `teleports.py derive --replay` re-derives this bundle "
              "from them with no network and no cache.", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def bundles(root: Path, flavor: str) -> list[Path]:
    return sorted(p for p in root.glob("*-%s" % flavor) if (p / "candidates.json").exists())


def status_line(live: str, found: list[Path]) -> str:
    if not found:
        return "NEW %s (no bundle yet)" % live
    built = load_json(found[-1] / "candidates.json", {}).get("build")
    if built == live:
        return "CURRENT %s (%s)" % (live, found[-1].name)
    return "NEW %s (last ruled %s, %s)" % (live, built, found[-1].name)


def _date(value: str) -> str:
    if not DATE_RE.match(value):
        raise argparse.ArgumentTypeError("a date is YYYY-MM-DD; got %r" % value)
    return value


def load_candidates(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        raise SystemExit("%s has no candidates.json: run `derive` first." % bundle)
    return load_json(path, {})


def cmd_status(args) -> int:
    print(status_line(live_build(FLAVORS[args.flavor]), bundles(args.root, args.flavor)))
    return 0


def cmd_derive(args) -> int:
    raw = args.bundle / "raw"
    tables: dict[str, Path] = {}
    if args.replay:
        prior = load_json(args.bundle / "candidates.json", {})
        build = args.build or prior.get("build")
        if not build:
            raise SystemExit("--replay: %s has no candidates.json to take the build from; pass --build."
                             % args.bundle)
        fetched = "%s (replayed from %s)" % (prior.get("fetched", "unknown").split(" (replayed")[0],
                                             args.bundle.as_posix())
        for table, _why in TABLES:
            member = raw / ("%s.csv.gz" % table)
            if not member.exists():
                raise SystemExit("--replay: %s is missing raw/%s.csv.gz." % (args.bundle, table))
            tables[table] = member
    else:
        build = args.build or live_build(FLAVORS[args.flavor])
        log("Build %s (wago product %s)" % (build, FLAVORS[args.flavor]))
        raw.mkdir(parents=True, exist_ok=True)
        stamps = []
        for table, _why in TABLES:
            source, stamp = fetch_table(table, build, args.cache_dir)
            stamps.append(stamp)
            member = raw / ("%s.csv.gz" % table)
            with source.open("rb") as src, gzip.GzipFile(member, "wb", compresslevel=9, mtime=0) as dst:
                shutil.copyfileobj(src, dst, CHUNK)
            tables[table] = member
        dated = [s for s in stamps if s not in ("cached", "unknown")]
        prior = load_json(args.bundle / "candidates.json", {})
        if dated:
            fetched = dated[0]
        elif prior.get("build") == build and prior.get("fetched"):
            fetched = prior["fetched"].split(" (replayed")[0]  # the cache holds that first fetch's bytes
        else:
            fetched = "from the cache of build %s" % build
    rows = read_seeds(args.seeds.read_text(encoding="utf-8"))
    doc = derive_doc(Build(tables), rows, build, args.date, fetched)
    write_json(args.bundle / "candidates.json", doc)
    write_text(args.bundle / "SOURCES.md",
               format_sources_md(doc, {t: p.stat().st_size for t, p in tables.items()}))
    unruled = unruled_keys(doc, load_json(args.rulings, {}))
    by_kind: dict[str, int] = defaultdict(int)
    for f in doc["flags"]:
        by_kind[f["kind"]] += 1
    log("%d rows, %d spells; %d flags (%s), %d candidates, %d unruled" % (
        doc["shipped"]["rows"], doc["shipped"]["spells"], len(doc["flags"]),
        ", ".join("%s %d" % kv for kv in sorted(by_kind.items())) or "none",
        len(doc["candidates"]), len(unruled)))
    return 0


def cmd_rule(args) -> int:
    todo = [(k, args.ruling, args.reason) for k in (args.key or ())]
    if args.tsv:
        todo += read_tsv(args.tsv)
    if not todo:
        raise SystemExit("rule needs --key (with --ruling and --reason) or --tsv.")
    known = set(all_keys(load_candidates(args.bundle))) if args.bundle else None
    rulings = load_json(args.rulings, {})
    for key, ruling, reason in todo:
        if known is not None and key not in known:
            raise SystemExit("%s is not a flag or candidate in %s/candidates.json." % (key, args.bundle))
        set_ruling(rulings, key, ruling, reason)
    write_text(args.rulings, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    log("Recorded %d ruling(s) in %s" % (len(todo), args.rulings))
    return 0


def cmd_check(args) -> int:
    doc = load_candidates(args.bundle)
    unruled = unruled_keys(doc, load_json(args.rulings, {}))
    if not unruled:
        print("OK: every flag and candidate in %s is ruled." % args.bundle.name)
        return 0
    rows = {f["key"]: f.get("detail", "") for f in doc["flags"]}
    rows.update({c["key"]: "%s -> %s" % (c["name"], c["resolved"] or "unresolved") for c in doc["candidates"]})
    print("%d unruled:" % len(unruled))
    for key in unruled:
        print("  %s  %s" % (key, rows[key]))
    return 1


def cmd_report(args) -> int:
    doc = load_candidates(args.bundle)
    rulings = load_json(args.rulings, {})
    planned = None
    if not unruled_keys(doc, rulings):
        planned = apply_seeds(args.seeds.read_bytes().decode("utf-8"), doc, rulings)[1]
    write_text(args.bundle / "RULINGS.md", format_rulings_md(doc, rulings, args.date, planned))
    log("Wrote %s" % (args.bundle / "RULINGS.md"))
    return 0


def cmd_apply(args) -> int:
    doc = load_candidates(args.bundle)
    data = args.seeds.read_bytes().decode("utf-8")
    out, changes = apply_seeds(data, doc, load_json(args.rulings, {}))
    for line in changes:
        log("  " + line)
    if out != data:
        args.seeds.write_bytes(out.encode("utf-8"))
    log("%d change(s) to %s" % (len(changes) if out != data else 0, args.seeds))
    return 0


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Re-validate defaults/TeleportSpells.lua against wago.tools.",
                                     epilog="The contract is docs/validate-seeds.md.")
    parser.add_argument("--rulings", type=Path, default=RULINGS_PATH)
    parser.add_argument("--seeds", type=Path, default=SEEDS_PATH)
    parser.add_argument("--cache-dir", type=Path, default=CACHE_DIR)
    sub = parser.add_subparsers(dest="command", required=True)
    status = sub.add_parser("status", help="is there a live build newer than the newest bundle?")
    status.add_argument("--flavor", choices=sorted(FLAVORS), default="retail")
    status.add_argument("--root", type=Path, default=RESEARCH)
    derive = sub.add_parser("derive", help="flags and candidates into the bundle's candidates.json")
    derive.add_argument("--flavor", choices=sorted(FLAVORS), required=True)
    derive.add_argument("--bundle", type=Path, required=True)
    derive.add_argument("--date", type=_date, required=True)
    derive.add_argument("--build", help="pin this build instead of the live one")
    derive.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    rule = sub.add_parser("rule", help="record rulings (the only writer of the rulings file)")
    rule.add_argument("--key", action="append")
    rule.add_argument("--ruling")
    rule.add_argument("--reason")
    rule.add_argument("--tsv", type=Path, help="key<TAB>ruling<TAB>reason lines")
    rule.add_argument("--bundle", type=Path, help="refuse keys this bundle's candidates.json lacks")
    for name, helptext in (("check", "exit 1 while anything is unruled"),
                           ("report", "write the bundle's RULINGS.md"),
                           ("apply", "write the ruled changes into defaults/TeleportSpells.lua")):
        cmd = sub.add_parser(name, help=helptext)
        cmd.add_argument("--bundle", type=Path, required=True)
        if name != "check":
            cmd.add_argument("--date", type=_date, required=True)
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    return {"status": cmd_status, "derive": cmd_derive, "rule": cmd_rule, "check": cmd_check,
            "report": cmd_report, "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())

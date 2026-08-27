#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Adopt-package MERGE 1 — .claude/settings.json  (research § 6 PRE-7)

WHAT THIS IS
  A standalone, testable unit. It merges LogicLoom's hook registrations into a
  .claude/settings.json the ADOPTER already owns. It is NOT the applier: it
  reads, decides, and either prints the result (default) or writes it. Nothing
  else in the adopt CLI has to exist for this to run.

WHY IT IS NOT `json.load` + `json.dump`
  Round-tripping through Python's json module reformats the whole file: key
  order survives (3.7+ dicts), but indentation, spacing, and the adopter's own
  style do not. That produces a diff nobody can review, on a file we do not own.
  So this does a TEXTUAL SPLICE: a span-aware scanner locates the exact byte
  offset where a new member or array element belongs, and the insert is written
  there in the adopter's own indent unit and line ending. Every pre-existing
  byte is preserved verbatim. (husky's `init`, which sniffs the consumer's
  package.json indentation before editing it, is the precedent for the care
  level — research § 6 PRE-7.)

MERGE RULE
  Per JSON KEY PATH, never file-level.
    * A key path the adopter already set is KEEP-THEIRS, full stop. This unit
      never overwrites a value.
    * A key path we need and they lack is ADDITIVE.
    * `hooks.<Event>` is the one array case: we APPEND our matcher groups to
      the end of their list. That sets no key of theirs, removes nothing, and
      reorders nothing — it is the additive case, not an overwrite. Claude Code
      composes hook decisions most-restrictive, so appending ours cannot weaken
      theirs.
  Consequence worth stating plainly: `statusLine` and every other top-level key
  is out of scope. This merges hooks and only hooks.

IDEMPOTENCY AND THE REFUSAL
  JSON has no comment syntax, so the added region cannot be fenced in-band the
  way .gitignore's can. Provenance is recorded in a SIDECAR next to the file
  (default `.claude/.logicloom-adopt-settings.json`) holding the canonical form
  (sorted keys, compact) of every matcher group we inserted.

  On a re-run:
    * every recorded group still present, byte-identical after canonicalization
      → NO-OP. Running twice changes nothing the second time.
    * a recorded group missing or altered → REFUSE. That is the human-edit
      detector: canonicalization ignores whitespace and key order, so a REFUSE
      means a value actually changed (a timeout tuned, a command edited, a hook
      deleted from one of our groups) — not that the file was reformatted.
    * a hook entry whose `command` names a LogicLoom script path but which sits
      outside every recorded group → REFUSE. Something installed or hand-wrote
      our hooks by another route; re-inserting would duplicate them.
    * no sidecar, but LogicLoom commands already present → REFUSE. We cannot
      tell what is ours, and a guess here duplicates governance hooks.

  A refusal never writes and never partially writes.

EXIT CODES
  0  merged, or already merged (no-op)
  10 refused — reason on stderr, target untouched
  1  usage / unparseable input

DEPENDENCIES
  python3 only. No jq (not guaranteed present on an adopter's machine; python3
  is already a CI dependency of this repo — .github/workflows/plugin-tests.yml
  sets up python 3.11 and runs validate-plugin-manifests.py). Written against
  the 3.9.6 that ships with macOS, so: no match statement, no PEP 604 unions.
"""

from __future__ import unicode_literals

import argparse
import json
import os
import re
import sys

# What counts as "a LogicLoom hook" is DERIVED FROM THE FRAGMENT, not from a
# hardcoded prefix list. An earlier draft matched on `.claude/hooks/`, which an
# adopter may legitimately use for their OWN hook scripts — that would have
# refused the merge on a file containing nothing of ours. Matching the exact
# script paths our fragment registers cannot false-positive, and it stays
# correct when the fragment changes.
_SCRIPT_PATH_RE = re.compile(r"[\w./-]+\.(?:sh|py|js|mjs|ts)")

SIDECAR_VERSION = 1


# ---------------------------------------------------------------------------
# Span-aware JSON scanner.
#
# Python's json module gives no byte offsets, and offsets are the whole point
# here: we need to know where a container's last member ENDS so a new one can
# be spliced in after it without touching a single existing byte. This is a
# minimal recursive-descent scanner that records (start, end) for every value.
# It validates nothing beyond what it must to find spans — json.loads() is run
# first, so the document is already known to be well-formed.
# ---------------------------------------------------------------------------

class _Node(object):
    __slots__ = ("kind", "start", "end", "pairs", "items")

    def __init__(self, kind, start, end, pairs=None, items=None):
        self.kind = kind
        self.start = start
        self.end = end
        self.pairs = pairs or []   # object: list of (key, value_node)
        self.items = items or []   # array: list of value_node


_WS = " \t\r\n"


def _skip_ws(s, i):
    n = len(s)
    while i < n and s[i] in _WS:
        i += 1
    return i


def _end_of_string(s, i):
    # s[i] == '"'; returns index one past the closing quote.
    j = i + 1
    n = len(s)
    while j < n:
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == '"':
            return j + 1
        j += 1
    raise ValueError("unterminated string at offset %d" % i)


def _parse_value(s, i):
    i = _skip_ws(s, i)
    c = s[i]
    if c == "{":
        return _parse_object(s, i)
    if c == "[":
        return _parse_array(s, i)
    if c == '"':
        return _Node("string", i, _end_of_string(s, i))
    j = i
    n = len(s)
    while j < n and s[j] not in ",}]" and s[j] not in _WS:
        j += 1
    return _Node("scalar", i, j)


def _parse_object(s, i):
    start = i
    i = _skip_ws(s, i + 1)
    pairs = []
    if s[i] == "}":
        return _Node("object", start, i + 1, pairs=pairs)
    while True:
        i = _skip_ws(s, i)
        ke = _end_of_string(s, i)
        key = json.loads(s[i:ke])
        i = _skip_ws(s, ke)
        i += 1  # ':'
        v = _parse_value(s, i)
        pairs.append((key, v))
        i = _skip_ws(s, v.end)
        if s[i] == ",":
            i += 1
            continue
        if s[i] == "}":
            return _Node("object", start, i + 1, pairs=pairs)
        raise ValueError("expected ',' or '}' at offset %d" % i)


def _parse_array(s, i):
    start = i
    i = _skip_ws(s, i + 1)
    items = []
    if s[i] == "]":
        return _Node("array", start, i + 1, items=items)
    while True:
        v = _parse_value(s, i)
        items.append(v)
        i = _skip_ws(s, v.end)
        if s[i] == ",":
            i += 1
            continue
        if s[i] == "]":
            return _Node("array", start, i + 1, items=items)
        raise ValueError("expected ',' or ']' at offset %d" % i)


def _member(node, key):
    for k, v in node.pairs:
        if k == key:
            return v
    return None


# ---------------------------------------------------------------------------
# Style sniffing + rendering in the adopter's style
# ---------------------------------------------------------------------------

def sniff_indent_unit(text):
    m = re.search(r'[\r\n]([ \t]+)"', text)
    if m:
        return m.group(1)
    return "  "


def sniff_newline(text):
    if "\r\n" in text:
        return "\r\n"
    return "\n"


def _line_indent_at(text, offset):
    """Leading whitespace of the line containing `offset`."""
    bol = text.rfind("\n", 0, offset) + 1
    j = bol
    while j < len(text) and text[j] in " \t":
        j += 1
    return text[bol:j]


def render(value, unit, base, nl):
    """json.dumps, re-indented into `unit`, every line after the first
    prefixed with `base`. A sentinel indent char keeps the level count exact
    regardless of what `unit` is (tabs included)."""
    sentinel = "\x01"
    raw = json.dumps(value, indent=sentinel, ensure_ascii=False)
    lines = raw.split("\n")
    out = [lines[0]]
    for ln in lines[1:]:
        depth = len(ln) - len(ln.lstrip(sentinel))
        out.append(base + unit * depth + ln[depth:])
    return nl.join(out)


def insert_object_member(text, node, key, value, unit, nl):
    base = _line_indent_at(text, node.start) + unit
    frag = json.dumps(key, ensure_ascii=False) + ": " + render(value, unit, base, nl)
    if node.pairs:
        at = node.pairs[-1][1].end
        ins = "," + nl + base + frag
    else:
        at = node.start + 1
        ins = nl + base + frag + nl + _line_indent_at(text, node.start)
    return text[:at] + ins + text[at:]


def append_array_items(text, node, values, unit, nl):
    base = _line_indent_at(text, node.start) + unit
    rendered = [render(v, unit, base, nl) for v in values]
    if node.items:
        at = node.items[-1].end
        ins = "".join("," + nl + base + r for r in rendered)
    else:
        at = node.start + 1
        ins = (nl + base + ("," + nl + base).join(rendered)
               + nl + _line_indent_at(text, node.start))
    return text[:at] + ins + text[at:]


# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

def canon(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def group_commands(group):
    out = []
    for h in group.get("hooks", []) or []:
        c = h.get("command")
        if isinstance(c, str):
            out.append(c)
    return out


def loom_script_paths(hooks_obj):
    """Every script path our fragment registers, e.g.
    `.claude/hooks/freeze-write-scope.sh`."""
    paths = set()
    for groups in hooks_obj.values():
        for g in groups or []:
            for cmd in group_commands(g):
                for m in _SCRIPT_PATH_RE.findall(cmd):
                    paths.add(m)
    return paths


def is_loom_command(cmd, paths):
    for p in paths:
        if p in cmd:
            return True
    return False


def default_sidecar(target):
    d = os.path.dirname(os.path.abspath(target))
    return os.path.join(d, ".logicloom-adopt-settings.json")


class Refuse(Exception):
    pass


# ---------------------------------------------------------------------------
# The merge
# ---------------------------------------------------------------------------

def merge(target_text, fragment, record):
    """Returns (merged_text, new_record, status) where status is
    'merged' | 'nochange'. Raises Refuse with a human reason."""
    our_hooks = fragment.get("hooks")
    if not isinstance(our_hooks, dict) or not our_hooks:
        raise Refuse("fragment has no 'hooks' object to merge")

    if target_text is None:
        # No file at all — write ours whole, in the conventional 2-space style.
        text = json.dumps({"hooks": our_hooks}, indent=2, ensure_ascii=False) + "\n"
        rec = {"version": SIDECAR_VERSION,
               "inserted": dict((ev, [canon(g) for g in gs])
                                for ev, gs in our_hooks.items())}
        return text, rec, "merged"

    try:
        data = json.loads(target_text)
    except ValueError as e:
        raise Refuse("target is not valid JSON: %s" % e)
    if not isinstance(data, dict):
        raise Refuse("target's top-level value is not a JSON object")

    recorded = {}
    if record is not None:
        if record.get("version") != SIDECAR_VERSION:
            raise Refuse("provenance record has unknown version %r"
                         % (record.get("version"),))
        recorded = record.get("inserted") or {}

    ours_paths = loom_script_paths(our_hooks)

    present = data.get("hooks") or {}
    if not isinstance(present, dict):
        raise Refuse("target's 'hooks' key is not an object")

    # -- canonical index of what is in the target now --------------------
    present_canon = {}
    for ev, groups in present.items():
        if not isinstance(groups, list):
            raise Refuse("target's hooks.%s is not an array" % ev)
        present_canon[ev] = [canon(g) for g in groups]

    # -- 1. verify every recorded group is still there, unaltered --------
    for ev, cgs in recorded.items():
        for cg in cgs:
            if cg not in present_canon.get(ev, []):
                raise Refuse(
                    "a LogicLoom hook group recorded under hooks.%s is missing or "
                    "was edited in place; refusing to overwrite a human edit. "
                    "Resolve by hand, or delete the provenance record to start over."
                    % ev)

    # -- 2. no stray LogicLoom hooks outside the recorded region ---------
    for ev, groups in present.items():
        for i, g in enumerate(groups):
            if not isinstance(g, dict):
                continue
            cg = canon(g)
            if cg in recorded.get(ev, []):
                continue
            for cmd in group_commands(g):
                if is_loom_command(cmd, ours_paths):
                    if record is None:
                        raise Refuse(
                            "hooks.%s[%d] already runs a LogicLoom command (%r) but "
                            "there is no provenance record; cannot tell which entries "
                            "are ours. Refusing rather than duplicating them."
                            % (ev, i, cmd))
                    raise Refuse(
                        "hooks.%s[%d] runs a LogicLoom command (%r) from outside the "
                        "recorded region; refusing rather than duplicating it."
                        % (ev, i, cmd))

    # -- 3. work out what is missing -------------------------------------
    to_add = {}
    for ev, groups in our_hooks.items():
        missing = [g for g in groups if canon(g) not in present_canon.get(ev, [])]
        if missing:
            to_add[ev] = missing

    new_record = {"version": SIDECAR_VERSION, "inserted": {}}
    for ev, cgs in recorded.items():
        new_record["inserted"][ev] = list(cgs)

    if not to_add:
        return target_text, new_record, "nochange"

    unit = sniff_indent_unit(target_text)
    nl = sniff_newline(target_text)
    text = target_text

    for ev, groups in to_add.items():
        root = _parse_object(text, _skip_ws(text, 0))
        hooks_node = _member(root, "hooks")
        if hooks_node is None:
            # Whole 'hooks' key is additive.
            text = insert_object_member(text, root, "hooks",
                                        dict([(ev, groups)]), unit, nl)
        else:
            ev_node = _member(hooks_node, ev)
            if ev_node is None:
                text = insert_object_member(text, hooks_node, ev, groups, unit, nl)
            else:
                text = append_array_items(text, ev_node, groups, unit, nl)
        new_record["inserted"].setdefault(ev, [])
        new_record["inserted"][ev].extend(canon(g) for g in groups)

    # The splice must not have changed meaning anywhere else.
    try:
        after = json.loads(text)
    except ValueError as e:
        raise Refuse("internal: splice produced invalid JSON (%s)" % e)
    before = json.loads(target_text)
    for k, v in before.items():
        if k == "hooks":
            continue
        if canon(after.get(k)) != canon(v):
            raise Refuse("internal: splice altered unrelated key %r" % k)

    return text, new_record, "merged"


def main(argv):
    ap = argparse.ArgumentParser(
        prog="merge_settings_json.py",
        description="Additively merge LogicLoom hook registrations into an "
                    "adopter's .claude/settings.json. Dry-run by default.")
    ap.add_argument("--target", required=True,
                    help="the adopter's .claude/settings.json (may not exist)")
    ap.add_argument("--fragment", required=True,
                    help="settings-hooks-fragment.json")
    ap.add_argument("--record",
                    help="provenance sidecar path "
                         "(default: <target dir>/.logicloom-adopt-settings.json)")
    ap.add_argument("--write", action="store_true",
                    help="write the result; without it the merged file is "
                         "printed to stdout and nothing is written")
    args = ap.parse_args(argv)

    try:
        with open(args.fragment) as fh:
            fragment = json.load(fh)
    except (IOError, OSError, ValueError) as e:
        sys.stderr.write("error: cannot read fragment: %s\n" % e)
        return 1

    target_text = None
    if os.path.exists(args.target):
        try:
            with open(args.target) as fh:
                target_text = fh.read()
        except (IOError, OSError) as e:
            sys.stderr.write("error: cannot read target: %s\n" % e)
            return 1
        if target_text.strip() == "":
            target_text = None

    record_path = args.record or default_sidecar(args.target)
    record = None
    if os.path.exists(record_path):
        try:
            with open(record_path) as fh:
                record = json.load(fh)
        except (IOError, OSError, ValueError) as e:
            sys.stderr.write("refused: provenance record is unreadable: %s\n" % e)
            return 10

    try:
        text, new_record, status = merge(target_text, fragment, record)
    except Refuse as e:
        sys.stderr.write("refused: %s\n" % e)
        return 10

    if args.write:
        if status == "merged":
            with open(args.target, "w") as fh:
                fh.write(text)
        with open(record_path, "w") as fh:
            fh.write(json.dumps(new_record, indent=2, sort_keys=True) + "\n")
    else:
        sys.stdout.write(text)

    sys.stderr.write("status: %s\n" % status)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

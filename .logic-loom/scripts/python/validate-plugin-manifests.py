#!/usr/bin/env python3
"""Validate LogicLoom plugin manifests (`plugins/*/.claude-plugin/plugin.json`).

This is the SAME contract the CI "Validate All Manifests" step has always
enforced, lifted out of an inline heredoc so it can be run and tested locally:

  1. the manifest parses as JSON
  2. `name`, `version`, `dependencies` are present

plus TWO additions:

  3. IF an optional `eval` block is present, its SHAPE is valid (backlog §3.4).
     If it is absent, nothing is checked and nothing is reported.

  4. The optional inventory blocks (`agents`, `skills`, `commands`) TELL THE
     TRUTH (LOOM-0012). Each declares a `list` and nothing else — the former
     `count` field is rejected, not merely ignored — and that list must equal
     what is on disk. A block may be omitted entirely, but only when the
     corresponding directory holds nothing; omitting it to silence the check is
     itself an error. Before this, `count` and `list` were verified against
     neither each other nor disk, and both had silently drifted.

Scope guard: this validates METADATA ONLY. LogicLoom ships no eval judge, no
eval runner, and no scoring engine — shipping one would make the harness an
evaluation engine, contradicting the ratified "ride native, don't reimplement"
position. Do not grow this file into a runner.

Schema reference: plugins/MANIFEST-SCHEMA.md

Usage:
    python3 .logic-loom/scripts/python/validate-plugin-manifests.py [--root DIR]

Exit status: 0 = all manifests valid, 1 = at least one error.
"""

import argparse
import json
import os
import sys

# Fields whose presence CI has always required.
REQUIRED_FIELDS = ("name", "version", "dependencies")

# --- optional `eval` block -------------------------------------------------
EVAL_ALLOWED_KEYS = {"suites"}
SUITE_REQUIRED_KEYS = ("id", "path")
SUITE_ALLOWED_KEYS = {"id", "path", "description", "metric", "threshold"}


def _validate_eval(block, errors, plugin):
    """Shape-check an optional `eval` block. Appends to `errors`."""
    where = f"{plugin}: eval"

    if not isinstance(block, dict):
        errors.append(f"{where} must be an object")
        return

    unknown = sorted(set(block) - EVAL_ALLOWED_KEYS)
    if unknown:
        errors.append(f"{where} has unknown key(s): {', '.join(unknown)}")

    if "suites" not in block:
        errors.append(f"{where} missing required key 'suites'")
        return

    suites = block["suites"]
    if not isinstance(suites, list):
        errors.append(f"{where}.suites must be an array")
        return
    if not suites:
        errors.append(f"{where}.suites must not be empty")
        return

    seen_ids = set()
    for i, suite in enumerate(suites):
        at = f"{where}.suites[{i}]"

        if not isinstance(suite, dict):
            errors.append(f"{at} must be an object")
            continue

        unknown = sorted(set(suite) - SUITE_ALLOWED_KEYS)
        if unknown:
            errors.append(f"{at} has unknown key(s): {', '.join(unknown)}")

        for key in SUITE_REQUIRED_KEYS:
            if key not in suite:
                errors.append(f"{at} missing required key '{key}'")
            elif not isinstance(suite[key], str) or not suite[key].strip():
                errors.append(f"{at}.{key} must be a non-empty string")

        suite_id = suite.get("id")
        if isinstance(suite_id, str) and suite_id.strip():
            if suite_id in seen_ids:
                errors.append(f"{at}.id duplicates an earlier suite id: {suite_id!r}")
            seen_ids.add(suite_id)

        if "description" in suite and not isinstance(suite["description"], str):
            errors.append(f"{at}.description must be a string")

        if "metric" in suite and not isinstance(suite["metric"], str):
            errors.append(f"{at}.metric must be a string")

        if "threshold" in suite:
            threshold = suite["threshold"]
            # bool is a subclass of int in Python; reject it explicitly.
            if isinstance(threshold, bool) or not isinstance(threshold, (int, float)):
                errors.append(f"{at}.threshold must be a number")
            elif not (0 <= threshold <= 1):
                errors.append(f"{at}.threshold must be between 0 and 1 (got {threshold})")


# --- inventory blocks: agents / skills / commands --------------------------
INVENTORY_KINDS = ("agents", "skills", "commands")
INVENTORY_ALLOWED_KEYS = {"list"}


def _inventory_on_disk(plugin_dir, kind):
    """What the plugin actually ships for `kind`, sorted.

    agents/commands -> `*.md` basenames without the extension.
    skills          -> subdirectory names under skills/.
    """
    base = os.path.join(plugin_dir, kind)
    if not os.path.isdir(base):
        return []
    if kind == "skills":
        return sorted(
            entry for entry in os.listdir(base)
            if os.path.isdir(os.path.join(base, entry))
        )
    return sorted(
        entry[:-3] for entry in os.listdir(base)
        if entry.endswith(".md") and os.path.isfile(os.path.join(base, entry))
    )


def _validate_inventory(data, plugin_dir, errors, plugin):
    """Check the agents/skills/commands blocks against the filesystem."""
    for kind in INVENTORY_KINDS:
        on_disk = _inventory_on_disk(plugin_dir, kind)
        where = f"{plugin}: {kind}"

        if kind not in data:
            # Omission is legal ONLY when there is nothing to declare.
            if on_disk:
                errors.append(
                    f"{where} block is missing but {kind}/ holds {len(on_disk)} "
                    f"entr{'y' if len(on_disk) == 1 else 'ies'}: {', '.join(on_disk)}"
                )
            continue

        block = data[kind]
        if not isinstance(block, dict):
            errors.append(f"{where} must be an object")
            continue

        unknown = sorted(set(block) - INVENTORY_ALLOWED_KEYS)
        if unknown:
            if "count" in unknown:
                errors.append(
                    f"{where} declares 'count', which was removed — a number "
                    "nothing derives is a number that drifts. The list IS the "
                    "inventory (see plugins/MANIFEST-SCHEMA.md)"
                )
            other = [key for key in unknown if key != "count"]
            if other:
                errors.append(f"{where} has unknown key(s): {', '.join(other)}")

        if "list" not in block:
            errors.append(f"{where} missing required key 'list'")
            continue

        declared = block["list"]
        if not isinstance(declared, list) or not all(
            isinstance(entry, str) for entry in declared
        ):
            errors.append(f"{where}.list must be an array of strings")
            continue

        if sorted(declared) != on_disk:
            missing = [entry for entry in on_disk if entry not in declared]
            extra = [entry for entry in declared if entry not in on_disk]
            detail = []
            if missing:
                detail.append(f"on disk but undeclared: {', '.join(missing)}")
            if extra:
                detail.append(f"declared but absent from disk: {', '.join(extra)}")
            if not detail:  # same members, wrong order or duplicated
                detail.append(f"expected {on_disk}, got {declared}")
            errors.append(f"{where}.list does not match disk — " + "; ".join(detail))


def validate(root):
    """Return (errors, checked_count) for every manifest under <root>/plugins."""
    errors = []
    checked = 0
    plugins_dir = os.path.join(root, "plugins")

    if not os.path.isdir(plugins_dir):
        return [f"no plugins/ directory under {root}"], 0

    for name in sorted(os.listdir(plugins_dir)):
        manifest = os.path.join(plugins_dir, name, ".claude-plugin", "plugin.json")
        if not os.path.exists(manifest):
            continue

        checked += 1
        try:
            with open(manifest, encoding="utf-8") as fh:
                data = json.load(fh)
        except json.JSONDecodeError as exc:
            errors.append(f"{name}: invalid JSON - {exc}")
            continue

        if not isinstance(data, dict):
            errors.append(f"{name}: manifest must be a JSON object")
            continue

        for field in REQUIRED_FIELDS:
            if field not in data:
                errors.append(f"{name}: missing {field}")

        # Optional. Absence is never an error.
        if "eval" in data:
            _validate_eval(data["eval"], errors, name)

        _validate_inventory(data, os.path.join(plugins_dir, name), errors, name)

    return errors, checked


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=os.environ.get("LOOM_MANIFEST_ROOT", "."),
        help="repo root containing plugins/ (default: cwd, or $LOOM_MANIFEST_ROOT)",
    )
    args = parser.parse_args()

    errors, checked = validate(args.root)

    if errors:
        for err in errors:
            print(f"❌ {err}")
        return 1

    print(f"✅ All plugin manifests valid ({checked} checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

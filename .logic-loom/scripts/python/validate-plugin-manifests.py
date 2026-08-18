#!/usr/bin/env python3
"""Validate LogicLoom plugin manifests (`plugins/*/.claude-plugin/plugin.json`).

This is the SAME contract the CI "Validate All Manifests" step has always
enforced, lifted out of an inline heredoc so it can be run and tested locally:

  1. the manifest parses as JSON
  2. `name`, `version`, `dependencies` are present

plus ONE addition (backlog §3.4):

  3. IF an optional `eval` block is present, its SHAPE is valid.
     If it is absent, nothing is checked and nothing is reported.

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

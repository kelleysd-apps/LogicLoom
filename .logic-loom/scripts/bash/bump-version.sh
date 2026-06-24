#!/usr/bin/env bash
# bump-version.sh — coherently set the LogicLoom FRAMEWORK version across every
# stamp site, or verify they all match (--check). Single source of the canonical
# stamp sites so a release can never ship half-bumped. Maintainer release tooling
# (stripped from the template at promote — see template-strip-manifest.txt).
#
# Usage:
#   bump-version.sh <version>           # set every stamp to <version>
#   bump-version.sh --check <version>   # exit 0 iff every stamp already == <version>
#
# <version> accepts 'X.Y.Z' or 'vX.Y.Z' (the leading v is normalized off; sites
# that print a v-prefix keep it). The CHANGELOG roll and AGENTS history row are
# intentionally NOT automated here (they need human prose) — /promote does those.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

MODE=set
if [ "${1:-}" = "--check" ]; then MODE=check; shift; fi
RAW="${1:-}"
[ -n "$RAW" ] || { echo "usage: bump-version.sh [--check] <X.Y.Z>" >&2; exit 2; }

cd "$ROOT"
python3 - "$MODE" "$RAW" <<'PY'
import sys, re, os
from collections import OrderedDict

mode, raw = sys.argv[1], sys.argv[2]
ver = raw.lstrip('v')
if not re.fullmatch(r'\d+\.\d+\.\d+', ver):
    print(f"bad version '{raw}' (want X.Y.Z)", file=sys.stderr); sys.exit(2)

S = r'\d+\.\d+\.\d+'  # a semver run
# Each site is (file, regex). The regex must contain exactly one SEMVER run; the
# surrounding text anchors it to the right stamp so unrelated versions are safe.
SITES = [
    ('.logic-loom/config/architecture.conf', r'# Framework: logic-loom v'+S),
    ('.logic-loom/config/architecture.conf', r'(?m)^CONFIG_VERSION='+S),
    ('.logic-loom/config/architecture.conf', r'(?m)^FRAMEWORK_VERSION='+S),
    ('.logic-loom/config/architecture.conf', r'(?m)^ARCHITECTURE_VERSION='+S),
    ('CLAUDE.md', r'\*\*Framework\*\*: logic-loom v'+S),
    ('AGENTS.md', r'(?m)^\*\*Version\*\*: '+S),
    ('README.md', r'\*\*Framework\*\*: LogicLoom v'+S),
    ('TEMPLATE_INIT.md', r'\*\*Framework\*\*: LogicLoom v'+S),
    ('.logic-loom/scripts/bash/sanitize-for-template.sh', r'\*\*Framework\*\*: LogicLoom v'+S),
    ('.docs/architecture/governance-threat-model.md', r'\*\*Status:\*\* v'+S),
    ('package.json', r'"version": "'+S+r'"'),
]

byfile = OrderedDict()
for f, p in SITES:
    byfile.setdefault(f, []).append(p)

problems, changed = [], []
for f, pats in byfile.items():
    if not os.path.exists(f):
        problems.append(f"missing file: {f}"); continue
    txt = open(f).read(); orig = txt
    for p in pats:
        rx = re.compile(p)
        m = rx.search(txt)
        if not m:
            problems.append(f"{f}: stamp not found: /{p}/"); continue
        if mode == 'check':
            cur = re.search(S, m.group(0)).group(0)
            if cur != ver:
                problems.append(f"{f}: '{m.group(0)}' != {ver}")
        else:
            txt = rx.sub(lambda mm: re.sub(S, ver, mm.group(0), count=1), txt)
    if mode == 'set' and txt != orig:
        open(f, 'w').write(txt); changed.append(f)

if problems:
    hdr = "VERSION STAMPS NOT COHERENT" if mode == 'check' else "BUMP INCOMPLETE"
    print(f"{hdr} (target {ver}):", file=sys.stderr)
    for x in problems: print("  - " + x, file=sys.stderr)
    sys.exit(1)

if mode == 'check':
    print(f"OK: all framework stamps == {ver}")
else:
    print(f"bumped framework version -> {ver} ({len(changed)} files):")
    for c in changed: print("  " + c)
PY

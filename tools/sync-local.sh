#!/usr/bin/env bash
# Sync this repo's skills into the locally-installed copies (~/.claude/skills)
# and report drift. The install channel is `npx skills add/update` from the
# GitHub repo, so the real release step is commit+push — this script covers the
# local dev loop and doubles as a drift CHECK (--check exits 1 on any diff
# without writing).
#
# Usage: tools/sync-local.sh [--check] [TARGET_DIR]
#   TARGET_DIR defaults to ~/.claude/skills

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
TARGET="${1:-$HOME/.claude/skills}"

status=0
for dir in "$HERE"/skills/*/; do
    name="$(basename "$dir")"
    dest="$TARGET/$name"
    if [ ! -d "$dest" ]; then
        echo "[$name] not installed at $dest — skipping (install with: npx skills add forgent3d/forgent3d-skills)"
        continue
    fi
    if diff -rq "$dir" "$dest" >/dev/null 2>&1; then
        echo "[$name] in sync"
        continue
    fi
    if [ "$CHECK" = 1 ]; then
        echo "[$name] DRIFT between repo and $dest:"
        diff -rq "$dir" "$dest" || true
        status=1
    else
        rsync -a --delete "$dir" "$dest/"
        echo "[$name] synced -> $dest"
    fi
done

if [ "$CHECK" = 1 ] && [ "$status" = 1 ]; then
    echo "drift found — run tools/sync-local.sh to update the installed copy (and commit+push so npx installs match)"
fi
exit $status

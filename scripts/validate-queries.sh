#!/usr/bin/env bash
# Validates the extension's tree-sitter queries and test fixtures against the
# grammars pinned in extension.toml:
#
#   1. Clones each [grammars.*] entry at its pinned rev into a temp dir.
#   2. Runs every languages/<lang>/*.scm query file against the fixtures for
#      that language (tree-sitter exits non-zero on unknown node types,
#      fields, or malformed patterns — this catches query/grammar drift).
#   3. Parses the fixtures and fails if any produce ERROR or MISSING nodes.
#
# Requires: tree-sitter CLI (npm install -g tree-sitter-cli), git, cc.
# Used by `just test-queries` and the CI "queries" job.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Extract (name, repository, rev) for each [grammars.*] section.
grammars=$(awk '
    /^\[/              { in_grammar = ($0 ~ /^\[grammars\./); repo = ""; rev = "" }
    in_grammar && /^\[grammars\./ {
        name = $0; sub(/^\[grammars\./, "", name); sub(/\].*$/, "", name)
    }
    in_grammar && /^repository = / { repo = $3; gsub(/"/, "", repo) }
    in_grammar && /^rev = /        { rev  = $3; gsub(/"/, "", rev);
                                     printf "%s\t%s\t%s\n", name, repo, rev }
' extension.toml)

if [ -z "$grammars" ]; then
    echo "error: no [grammars.*] sections found in extension.toml" >&2
    exit 1
fi

# Clone each grammar at its pinned rev.
while IFS=$'\t' read -r name repo rev; do
    echo "==> grammar $name @ ${rev:0:7}"
    dir="$WORK/$name"
    mkdir -p "$dir"
    git init -q "$dir"
    git -C "$dir" remote add origin "$repo"
    # GitHub serves arbitrary reachable SHAs, so a depth-1 fetch pins exactly.
    git -C "$dir" fetch -q --depth 1 origin "$rev"
    git -C "$dir" checkout -q FETCH_HEAD
done <<< "$grammars"

status=0

for lang_dir in languages/*/; do
    lang=$(basename "$lang_dir")
    grammar=$(sed -n 's/^grammar = "\(.*\)"$/\1/p' "$lang_dir/config.toml" | head -1)
    gdir="$WORK/$grammar"

    if [ ! -d "$gdir" ]; then
        echo "error: language '$lang' references grammar '$grammar' with no matching [grammars.$grammar] section" >&2
        status=1
        continue
    fi

    # Collect fixtures whose names end in any of the language's path_suffixes.
    fixtures=()
    suffixes=$(sed -n 's/^path_suffixes = \[\(.*\)\]$/\1/p' "$lang_dir/config.toml" | tr ',' '\n' | tr -d ' "')
    while IFS= read -r suffix; do
        [ -n "$suffix" ] || continue
        while IFS= read -r f; do
            fixtures+=("$ROOT/$f")
        done < <(find test-fixtures -type f -name "*$suffix" | sort)
    done <<< "$suffixes"

    if [ ${#fixtures[@]} -eq 0 ]; then
        echo "error: no fixtures in test-fixtures/ match language '$lang' (suffixes: $suffixes)" >&2
        status=1
        continue
    fi

    # Validate every query file for this language.
    for scm in "$lang_dir"*.scm; do
        [ -e "$scm" ] || continue
        echo "==> query $scm"
        if ! (cd "$gdir" && tree-sitter query --quiet "$ROOT/$scm" "${fixtures[@]}"); then
            echo "error: query validation failed: $scm" >&2
            status=1
        fi
    done

    # Fixtures must parse without ERROR/MISSING nodes.
    echo "==> parse ${fixtures[*]#"$ROOT"/}"
    if ! (cd "$gdir" && tree-sitter parse --quiet "${fixtures[@]}"); then
        echo "error: fixtures for language '$lang' contain parse errors" >&2
        status=1
    fi
done

if [ "$status" -eq 0 ]; then
    echo "All queries valid and all fixtures parse cleanly."
fi
exit "$status"

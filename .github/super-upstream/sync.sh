#!/bin/bash
# Merge upstream/master into the fork's master, keeping the fork's own bits:
#  - upstream workflows stay deleted (they would release/tag in this fork),
#  - README.md is always upstream's README with our banner on top.
# Usage: sync.sh <upstream-ref>
set -euo pipefail

up="${1:-upstream/master}"
ours_dir=.github/super-upstream
our_workflows=".github/workflows/super-upstream.yml"

export GIT_AUTHOR_NAME="github-actions[bot]"
export GIT_AUTHOR_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

if git merge-base --is-ancestor "$up" HEAD; then
	echo "Already contains $(git rev-parse --short "$up")"
	exit 0
fi

git merge --no-ff --no-commit -X theirs "$up" || true
git rev-parse -q --verify MERGE_HEAD >/dev/null || { echo "merge did not start" >&2; exit 1; }

# Whatever is still unmerged (modify/delete etc.) goes upstream's way.
git diff --name-only --diff-filter=U | while read -r f; do
	if git cat-file -e "$up:$f" 2>/dev/null; then
		git checkout "$up" -- "$f"
	else
		git rm -q --cached --ignore-unmatch -- "$f"
		rm -f -- "$f"
	fi
done

# Drop every workflow that is not ours.
git ls-files -- .github/workflows | while read -r f; do
	case " $our_workflows " in *" $f "*) continue ;; esac
	git rm -q -f -- "$f"
done

{ cat "$ours_dir/banner.md"; git show "$up:README.md"; } > README.md
git add -A

git commit -q -m "Merge upstream $(git rev-parse --short "$up")" \
    -m "$(git log -1 --format='%h %s' "$up")"
git log --oneline -1

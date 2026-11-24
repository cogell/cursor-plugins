#!/usr/bin/env bash
# Sync pstack's Amp skills into an Amp skills repository checkout.
#
#   scripts/sync-amp-skills.sh [--dry-run] [--base <fork-sha>] <skills-checkout>
#
# Rebases this branch onto upstream cursor/plugins main, regenerates harness/pstack/amp,
# and replaces only the skill folders pstack owns in <skills-checkout>. pstack owns a folder
# when the last synced Amp tree or the new one has it, so other skills are never touched.
# The commit in <skills-checkout> carries a `Pstack-Source: cursor/plugins@<sha>` trailer,
# which the next run reads as its baseline. Pass --base <fork-sha> only on the first run,
# before any commit carries the trailer. Nothing is pushed.
set -euo pipefail

UPSTREAM_URL=https://github.com/cursor/plugins.git
BRANCH=amp-harness
TREE=harness/pstack/amp/skills
GENERATOR=scripts/generate-pstack-harness-trees.mjs
# Paths whose upstream changes can change the Amp tree.
SOURCES=(pstack "$GENERATOR")

die() { echo "sync-amp-skills: $*" >&2; exit 1; }

dry_run=false base_fork=
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) dry_run=true; shift ;;
    --base) base_fork=${2:?--base needs a fork commit}; shift 2 ;;
    -*) die "unknown option $1" ;;
    *) break ;;
  esac
done
[[ $# -eq 1 ]] || die "usage: $0 [--dry-run] [--base <fork-sha>] <skills-checkout>"
skills=$(cd "$1" && pwd) || die "no such directory: $1"
fork=$(cd "$(dirname "$0")/.." && pwd)

git -C "$skills" rev-parse --git-dir >/dev/null 2>&1 || die "$skills is not a git checkout"
[[ -z $(git -C "$skills" status --porcelain) ]] || die "$skills has uncommitted changes"
cd "$fork"
[[ $(git branch --show-current) == "$BRANCH" ]] || die "check out $BRANCH in $fork first"
[[ -z $(git status --porcelain) ]] || die "$fork has uncommitted changes"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch --quiet upstream main
upstream=$(git rev-parse upstream/main)

# Baseline: the fork commit the skills checkout was last synced from.
last=$(git -C "$skills" log -1 --grep '^Pstack-Source: ' --format=%B || true)
if [[ -z $base_fork ]]; then
  base_fork=$(sed -n 's#^Pstack-Fork: .*@\([0-9a-f]\{7,\}\)$#\1#p' <<<"$last" | tail -1)
  [[ -n $base_fork ]] || die "no Pstack-Source commit in $skills; pass --base <fork commit the skills were copied from>"
fi
if ! git cat-file -e "$base_fork^{commit}" 2>/dev/null; then
  git fetch --quiet origin "$base_fork" 2>/dev/null || true
  git cat-file -e "$base_fork^{commit}" 2>/dev/null || die "fork commit $base_fork is not in $fork or on origin"
fi
base_upstream=$(sed -n 's#^Pstack-Source: cursor/plugins@\([0-9a-f]\{7,\}\)$#\1#p' <<<"$last" | tail -1)
[[ -n $base_upstream ]] || base_upstream=$(git merge-base "$base_fork" upstream/main)

new_upstream=$(git rev-list --count "$base_upstream..upstream/main" -- "${SOURCES[@]}")
if [[ $new_upstream -eq 0 ]] && git diff --quiet "$base_fork" HEAD -- "$TREE"; then
  echo "Up to date: no pstack commits upstream since cursor/plugins@${base_upstream:0:7}, and $BRANCH's Amp tree matches ${base_fork:0:7}."
  exit 0
fi
echo "$new_upstream upstream pstack commit(s) since cursor/plugins@${base_upstream:0:7}."

if ! git merge-base --is-ancestor upstream/main HEAD; then
  echo "Rebasing $BRANCH onto cursor/plugins@${upstream:0:7}."
  if ! git rebase --quiet upstream/main >/dev/null 2>&1; then
    conflicts=$(git diff --name-only --diff-filter=U)
    stopped_at=$(git log -1 --format='%h %s' REBASE_HEAD 2>/dev/null || true)
    git rebase --abort
    die "rebase onto upstream conflicted at ${stopped_at:-a fork commit}. $BRANCH is unchanged. Conflicting files:
$conflicts
Run \`git rebase upstream/main\` in $fork, resolve these (rerun node $GENERATOR for files under harness/pstack/), then rerun this script."
  fi
fi

node "$GENERATOR" >/dev/null
node "$GENERATOR" --check >/dev/null || die "node $GENERATOR --check failed after regenerating"
if [[ -n $(git status --porcelain) ]]; then
  git add -A harness/pstack
  git commit --quiet -m "chore(pstack): regenerate the harness trees on cursor/plugins@${upstream:0:7}"
fi
head=$(git rev-parse HEAD)

old=$(git ls-tree --name-only "$base_fork:$TREE" | sort)
new=$(ls "$TREE" | sort)
added=$(comm -13 <(echo "$old") <(echo "$new"))
removed=$(comm -23 <(echo "$old") <(echo "$new"))
kept=$(comm -12 <(echo "$old") <(echo "$new"))

# A new pstack skill must not overwrite a skill that came from elsewhere.
for skill in $added; do
  [[ ! -e $skills/$skill ]] || die "pstack added $skill, but $skills already has a $skill folder that pstack does not own"
done

updated=()
for skill in $kept; do
  if ! diff -r -q "$TREE/$skill" "$skills/$skill" >/dev/null 2>&1; then updated+=("$skill"); fi
done
gone=()
for skill in $removed; do [[ -e $skills/$skill ]] && gone+=("$skill"); done

list() { if [[ $# -eq 0 ]]; then echo none; else echo "$*" | sed 's/ /, /g'; fi; }
summary="Added ($(wc -w <<<"$added")): $(list $added)
Removed (${#gone[@]}): $(list "${gone[@]}")
Updated (${#updated[@]}): $(list "${updated[@]}")"
echo "$summary"

if $dry_run; then
  echo "Dry run: $skills is unchanged. $BRANCH is at ${head:0:7}."
  exit 0
fi

for skill in "${gone[@]}"; do rm -rf "${skills:?}/$skill"; done
for skill in $added "${updated[@]}"; do
  rm -rf "${skills:?}/$skill"
  cp -a "$TREE/$skill" "$skills/$skill"
done
paths=($added "${gone[@]}" "${updated[@]}")
[[ ${#paths[@]} -eq 0 ]] || git -C "$skills" add -A -- "${paths[@]}"

git -C "$skills" commit --quiet --allow-empty -F - <<EOF
Sync pstack skills to cursor/plugins@${upstream:0:7}

From $TREE in github.com/cogell/cursor-plugins, branch $BRANCH at ${head:0:7},
rebased on cursor/plugins@${upstream:0:7}.

$summary

Pstack-Source: cursor/plugins@$upstream
Pstack-Fork: cogell/cursor-plugins@$head
EOF
echo "Committed $(git -C "$skills" rev-parse --short HEAD) in $skills. Nothing was pushed."

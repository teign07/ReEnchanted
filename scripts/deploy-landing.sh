#!/usr/bin/env bash
#
# deploy-landing.sh — publish the landing site to production.
#
# Source of truth: this monorepo's  LandingPage/  folder (private repo).
# Deploy target:    teign07/landingpage  (public), which GitHub Pages builds
#                   and serves at https://reenchanted.app via a workflow.
#
# The two repos have independent git histories; the deploy repo is a content
# MIRROR of LandingPage/, plus its own infrastructure files that must never be
# overwritten (the Pages workflow, CNAME, .nojekyll, etc). This script rsyncs
# the content across (deleting stale files) while protecting that infra, then
# commits and pushes — which triggers the Pages deploy.
#
# Usage:
#   scripts/deploy-landing.sh            # sync + commit + push (deploys)
#   scripts/deploy-landing.sh --check    # report drift only; no commit/push
#
# Requires: gh (authenticated), git, rsync.
set -euo pipefail

DEPLOY_REPO="teign07/landingpage"
DEPLOY_BRANCH="main"
CACHE_DIR="${LANDING_DEPLOY_DIR:-$HOME/.cache/reenchanted-landingpage-deploy}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/LandingPage"

# Files/dirs that live ONLY in the deploy repo. rsync --delete must not touch
# them: excluded paths are neither copied from source nor deleted in the target.
PROTECT=(
  ".git" ".github" ".gitignore" ".nojekyll"
  "CNAME" "README.md" "package.json" "scripts"
  ".DS_Store"
)

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

command -v gh   >/dev/null || { echo "error: gh not found" >&2; exit 1; }
command -v rsync >/dev/null || { echo "error: rsync not found" >&2; exit 1; }
[[ -f "$SRC/index.html" ]] || { echo "error: $SRC/index.html missing" >&2; exit 1; }

# ── refresh a pristine checkout of the deploy repo ──
if [[ -d "$CACHE_DIR/.git" ]]; then
  git -C "$CACHE_DIR" fetch --quiet origin "$DEPLOY_BRANCH"
  git -C "$CACHE_DIR" reset --hard --quiet "origin/$DEPLOY_BRANCH"
  git -C "$CACHE_DIR" clean -fd --quiet
else
  echo "Cloning $DEPLOY_REPO into $CACHE_DIR ..."
  gh repo clone "$DEPLOY_REPO" "$CACHE_DIR" -- --quiet
fi

# ── mirror content across, protecting the deploy-only infra ──
RSYNC_ARGS=(-a --delete)
for p in "${PROTECT[@]}"; do RSYNC_ARGS+=(--exclude="/$p"); done
rsync "${RSYNC_ARGS[@]}" "$SRC"/ "$CACHE_DIR"/

cd "$CACHE_DIR"
git add -A

if git diff --cached --quiet; then
  echo "✓ Deploy repo already matches LandingPage/ — nothing to publish."
  exit 0
fi

echo "Pending changes to publish:"
git diff --cached --stat

if [[ "$CHECK_ONLY" == "1" ]]; then
  echo ""
  echo "DRIFT: LandingPage/ differs from the live deploy repo (shown above)."
  echo "Run without --check to publish."
  exit 2
fi

SRC_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
DIRTY=""
git -C "$REPO_ROOT" diff --quiet -- LandingPage/ 2>/dev/null || DIRTY=" +uncommitted"
git commit --quiet -m "Sync landing site from ReEnchanted@${SRC_SHA}${DIRTY}"
git push --quiet origin "$DEPLOY_BRANCH"
echo "✓ Published. GitHub Pages workflow will deploy https://reenchanted.app shortly."

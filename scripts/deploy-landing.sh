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

# Paths rsync must leave alone entirely — neither copied from source nor
# deleted in the target. Two kinds live here:
#
#   deploy-only   infrastructure that exists only in the deploy repo and would
#                 be destroyed by --delete (the Pages workflow, CNAME, ...)
#   source-only   work that lives in LandingPage/ but must NOT go public —
#                 unlinked prototypes and experiments. Publishing them would
#                 put unfinished work at a real reenchanted.app URL, where it
#                 gets fetched and cached whether or not anything links to it.
PROTECT=(
  ".git" ".github" ".gitignore" ".nojekyll"
  "CNAME" "README.md" "package.json" "scripts"
  ".DS_Store"
)

# Paths that must NOT exist on the public site, even though they live in
# LandingPage/. Unlike PROTECT these are actively removed from the target if
# they are ever found there, so something published by mistake gets retracted
# on the next deploy instead of quietly staying up.
#
# An unlinked page is still a real, fetchable, cacheable URL. Anything here is
# unfinished work that has no business being one yet.
NEVER_PUBLISH=(
  "lab"           # hero-v2 / day-spine design prototypes
  "outer-stacks"  # experimental world; needs its own node server to run
  "experience"    # The First Fall 3D prologue — still in development. Its
                  # <link> and <script> tags in index.html are commented out to
                  # match. Re-enable both together, never one alone, or the
                  # hero's "Fall through the cover" button 404s.
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
for p in "${NEVER_PUBLISH[@]}"; do RSYNC_ARGS+=(--exclude="/$p"); done
rsync "${RSYNC_ARGS[@]}" "$SRC"/ "$CACHE_DIR"/

# Retract anything on the NEVER_PUBLISH list that made it out previously.
for p in "${NEVER_PUBLISH[@]}"; do
  if [[ -e "$CACHE_DIR/$p" ]]; then
    echo "Retracting /$p from the public site ..."
    rm -rf "${CACHE_DIR:?}/$p"
  fi
done

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
DEPLOY_SHA="$(git rev-parse HEAD)"
git push --quiet origin "$DEPLOY_BRANCH"
echo "✓ Published mirror commit ${DEPLOY_SHA:0:7}. Waiting for GitHub Pages ..."

RUN_ID=""
RUN_URL=""
RUN_STATUS=""
RUN_CONCLUSION=""
for _ in {1..40}; do
  RUN_JSON="$(gh api "repos/$DEPLOY_REPO/actions/runs?branch=$DEPLOY_BRANCH&head_sha=$DEPLOY_SHA&per_page=1" 2>/dev/null || true)"
  RUN_ID="$(printf '%s' "$RUN_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); r=(d.get("workflow_runs") or [{}])[0]; print(r.get("id",""))' 2>/dev/null || true)"
  RUN_URL="$(printf '%s' "$RUN_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); r=(d.get("workflow_runs") or [{}])[0]; print(r.get("html_url",""))' 2>/dev/null || true)"
  RUN_STATUS="$(printf '%s' "$RUN_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); r=(d.get("workflow_runs") or [{}])[0]; print(r.get("status",""))' 2>/dev/null || true)"
  RUN_CONCLUSION="$(printf '%s' "$RUN_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); r=(d.get("workflow_runs") or [{}])[0]; print(r.get("conclusion",""))' 2>/dev/null || true)"

  if [[ "$RUN_STATUS" == "completed" ]]; then
    if [[ "$RUN_CONCLUSION" == "success" ]]; then
      echo "✓ GitHub Pages deployed https://reenchanted.app"
      exit 0
    fi
    echo "error: GitHub Pages workflow failed (${RUN_CONCLUSION:-unknown})." >&2
    [[ -n "$RUN_URL" ]] && echo "See: $RUN_URL" >&2
    exit 1
  fi
  sleep 5
done

echo "warning: timed out waiting for GitHub Pages workflow." >&2
[[ -n "$RUN_URL" ]] && echo "Still running: $RUN_URL" >&2
exit 1

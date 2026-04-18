#!/usr/bin/env bash
set -euo pipefail

: "${RMAPI_HOST:?set to https://remarkable.opipomio.ch}"
: "${VAULT_REPO_URL:?set to git@github.com:phylaxe/obsidian_vault.git}"
VAULT_SUBDIR="${VAULT_SUBDIR:-reMarkable}"
VAULT_BRANCH="${VAULT_BRANCH:-main}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-rmfakecloud-sync@opipomio.ch}"
GIT_USER_NAME="${GIT_USER_NAME:-rmfakecloud-sync}"

RMAPI_STATE_DIR="${RMAPI_STATE_DIR:-/state/rmapi}"
VAULT_CHECKOUT="${VAULT_CHECKOUT:-/state/vault}"
DOWNLOAD_DIR="/tmp/rmapi-dl"
XOCHITL_DIR="/tmp/xochitl"

export HOME=/root
export XDG_CONFIG_HOME=/state
mkdir -p "$RMAPI_STATE_DIR" "$VAULT_CHECKOUT" "$HOME/.ssh" "$DOWNLOAD_DIR" "$XOCHITL_DIR"

if [ ! -f "$RMAPI_STATE_DIR/rmapi.conf" ] && [ -n "${RMAPI_AUTH_B64:-}" ]; then
  echo "[init] seeding rmapi auth from env"
  echo "$RMAPI_AUTH_B64" | base64 -d > "$RMAPI_STATE_DIR/rmapi.conf"
fi

if [ -n "${SSH_DEPLOY_KEY_B64:-}" ]; then
  echo "$SSH_DEPLOY_KEY_B64" | base64 -d > "$HOME/.ssh/id_ed25519"
  chmod 600 "$HOME/.ssh/id_ed25519"
  ssh-keyscan -t ed25519 github.com > "$HOME/.ssh/known_hosts" 2>/dev/null
fi

git config --global user.email "$GIT_USER_EMAIL"
git config --global user.name "$GIT_USER_NAME"
git config --global pull.rebase true

echo "[git] preparing checkout at $VAULT_CHECKOUT"
if [ ! -d "$VAULT_CHECKOUT/.git" ]; then
  git clone --branch "$VAULT_BRANCH" "$VAULT_REPO_URL" "$VAULT_CHECKOUT"
fi
cd "$VAULT_CHECKOUT"
git fetch origin "$VAULT_BRANCH"
git reset --hard "origin/$VAULT_BRANCH"
mkdir -p "$VAULT_SUBDIR"

echo "[rmapi] pulling all documents (full refresh)"
rm -rf "$DOWNLOAD_DIR" && mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"
rmapi -ni mget / || echo "[rmapi] mget reported errors, continuing"
echo "[rmapi] downloaded $(find "$DOWNLOAD_DIR" -name '*.rmdoc' | wc -l) .rmdoc files"

echo "[extract] unpacking .rmdoc archives into xochitl layout"
rm -rf "$XOCHITL_DIR" && mkdir -p "$XOCHITL_DIR"
find "$DOWNLOAD_DIR" -name '*.rmdoc' -print0 | while IFS= read -r -d '' rmdoc; do
  unzip -oq "$rmdoc" -d "$XOCHITL_DIR"
done

echo "[convert] clearing $VAULT_SUBDIR and regenerating from scratch"
rm -rf "${VAULT_CHECKOUT:?}/${VAULT_SUBDIR:?}"
mkdir -p "$VAULT_CHECKOUT/$VAULT_SUBDIR"
python /app/convert_all.py "$XOCHITL_DIR" "$VAULT_CHECKOUT/$VAULT_SUBDIR"

cd "$VAULT_CHECKOUT"
if [ -z "$(git status --porcelain "$VAULT_SUBDIR")" ]; then
  echo "[git] no changes"
  exit 0
fi

git add "$VAULT_SUBDIR"
git commit -m "rmfakecloud sync $(date -u +%FT%TZ)"
git push origin "$VAULT_BRANCH"
echo "[done] pushed"

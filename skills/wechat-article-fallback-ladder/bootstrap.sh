#!/usr/bin/env bash
# One-line installer:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Backtthefuture/huangshu/main/skills/wechat-article-fallback-ladder/bootstrap.sh)

set -euo pipefail

REPO="Backtthefuture/huangshu"
SKILL="wechat-article-fallback-ladder"
TARGET="$HOME/.claude/skills/$SKILL"

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_BLUE='\033[34m'
C_GRAY='\033[90m'

say() { printf "${C_BLUE}▸${C_RESET} %s\n" "$1"; }
ok() { printf "  ${C_GREEN}✓${C_RESET} %s\n" "$1"; }
warn() { printf "  ${C_YELLOW}!${C_RESET} %s\n" "$1"; }
err() { printf "  ${C_RED}x${C_RESET} %s\n" "$1"; }
bar() { printf "${C_GRAY}═══════════════════════════════════════════════════════${C_RESET}\n"; }

bar
printf "${C_BOLD}  wechat-article-fallback-ladder 一键安装${C_RESET}\n"
bar

if [ -e "$TARGET" ]; then
  warn "检测到已安装: $TARGET"
  printf "  覆盖重装? [y/N]: "
  read -r yn < /dev/tty || yn=""
  case "$yn" in
    [Yy]*) rm -rf "$TARGET" ;;
    *) say "保留现有文件，只运行安装检查"; bash "$TARGET/install.sh"; exit 0 ;;
  esac
fi

mkdir -p "$HOME/.claude/skills"
fetched=""

if [ -z "$fetched" ] && command -v npx >/dev/null 2>&1; then
  say "使用 npx skills add 安装..."
  if npx -y skills add "$REPO" --skill "$SKILL" -a claude-code -g -y; then
    if [ -f "$TARGET/SKILL.md" ]; then
      fetched="npx"
      ok "已安装到 $TARGET"
    fi
  fi
  [ -z "$fetched" ] && warn "npx 安装失败，尝试 git sparse-checkout"
fi

if [ -z "$fetched" ] && command -v git >/dev/null 2>&1; then
  say "使用 git sparse-checkout 安装..."
  TMP="$(mktemp -d)"
  if git clone --depth=1 --filter=blob:none --sparse "https://github.com/$REPO.git" "$TMP/repo"; then
    (cd "$TMP/repo" && git sparse-checkout set "skills/$SKILL")
    if [ -d "$TMP/repo/skills/$SKILL" ]; then
      mv "$TMP/repo/skills/$SKILL" "$TARGET"
      fetched="git"
      ok "已安装到 $TARGET"
    fi
  fi
  rm -rf "$TMP"
  [ -z "$fetched" ] && warn "git 安装失败，尝试 tarball"
fi

if [ -z "$fetched" ]; then
  say "使用 tarball 安装..."
  TMP="$(mktemp -d)"
  if curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar xz -C "$TMP"; then
    SUBDIR="$(find "$TMP" -maxdepth 3 -type d -path "*/skills/$SKILL" | head -1)"
    if [ -n "$SUBDIR" ] && [ -d "$SUBDIR" ]; then
      mv "$SUBDIR" "$TARGET"
      fetched="tarball"
      ok "已安装到 $TARGET"
    fi
  fi
  rm -rf "$TMP"
fi

if [ -z "$fetched" ]; then
  err "安装失败。请手动执行："
  printf "  git clone https://github.com/%s.git\n" "$REPO"
  printf "  bash huangshu/skills/%s/install.sh\n" "$SKILL"
  exit 1
fi

bash "$TARGET/install.sh"

#!/usr/bin/env bash
# Install/check wechat-article-fallback-ladder for Claude Code and Codex.

set -euo pipefail

SKILL="wechat-article-fallback-ladder"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${TARGET_DIR:-$HOME/.claude/skills/$SKILL}"

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

find_qiaomu_dir() {
  local dir
  for dir in \
    "$HOME/.claude/skills/qiaomu-markdown-proxy" \
    "$HOME/.codex/skills/qiaomu-markdown-proxy" \
    "$HOME/.Codex/skills/qiaomu-markdown-proxy" \
    "$HOME/.agents/skills/qiaomu-markdown-proxy"
  do
    if [ -d "$dir" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  return 1
}

register_codex() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local codex_target="$codex_home/skills/$SKILL"

  if [ ! -d "$codex_home" ]; then
    warn "未检测到 $codex_home，跳过 Codex 注册"
    return 0
  fi

  mkdir -p "$codex_home/skills"
  if [ -L "$codex_target" ]; then
    rm "$codex_target"
  elif [ -e "$codex_target" ]; then
    warn "$codex_target 已存在且不是软链，保留现状"
    return 0
  fi

  ln -s "$TARGET_DIR" "$codex_target"
  ok "Codex 已注册: $codex_target -> $TARGET_DIR"
}

bar
printf "${C_BOLD}  wechat-article-fallback-ladder 安装检查${C_RESET}\n"
bar

if [ "$SOURCE_DIR" != "$TARGET_DIR" ]; then
  say "安装到 Claude Code 全局目录: $TARGET_DIR"
  rm -rf "$TARGET_DIR"
  mkdir -p "$(dirname "$TARGET_DIR")"
  cp -R "$SOURCE_DIR" "$TARGET_DIR"
  SOURCE_DIR="$TARGET_DIR"
  ok "文件已复制"
else
  ok "已在目标目录: $TARGET_DIR"
fi

chmod +x "$TARGET_DIR/scripts/fetch_weixin_robust.sh" 2>/dev/null || true
chmod +x "$TARGET_DIR/install.sh" 2>/dev/null || true

say "检查基础依赖"
if command -v python3 >/dev/null 2>&1; then
  ok "python3: $(python3 --version 2>&1)"
else
  err "未找到 python3"
  exit 1
fi

if command -v curl >/dev/null 2>&1; then
  ok "curl 可用"
else
  err "未找到 curl"
  exit 1
fi

if bash -n "$TARGET_DIR/scripts/fetch_weixin_robust.sh"; then
  ok "fetch_weixin_robust.sh 语法正常"
fi

say "检查 qiaomu-markdown-proxy"
QIAOMU_DIR_FOUND="$(find_qiaomu_dir || true)"
if [ -n "$QIAOMU_DIR_FOUND" ]; then
  ok "已找到: $QIAOMU_DIR_FOUND"
else
  warn "未找到 qiaomu-markdown-proxy；仍可使用 r.jina.ai / defuddle.md 兜底，但本地 Playwright 抓取会跳过"
  printf "  ${C_GRAY}如需增强：安装 qiaomu-markdown-proxy 到 ~/.claude/skills/qiaomu-markdown-proxy，或运行时设置 QIAOMU_DIR=/path/to/qiaomu-markdown-proxy${C_RESET}\n"
fi

register_codex

bar
printf "${C_BOLD}  安装完成${C_RESET}\n"
bar
cat <<EOF
  Claude Code:
    完全退出并重新打开，然后说：
    读这篇公众号：https://mp.weixin.qq.com/s/...

  终端测试:
    bash $TARGET_DIR/scripts/fetch_weixin_robust.sh "https://mp.weixin.qq.com/s/..." /tmp/wechat-fallback-test

  说明文档:
    $TARGET_DIR/README.md
EOF

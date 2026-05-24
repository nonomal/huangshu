#!/usr/bin/env bash
# Robust WeChat article fetch wrapper for qiaomu-markdown-proxy.
# Usage: fetch_weixin_robust.sh <mp.weixin.qq.com URL> [output_dir]
# Emits a JSON status report to stdout and saves artifacts into output_dir.
set -euo pipefail

URL="${1:?Usage: fetch_weixin_robust.sh <weixin_url> [output_dir]}"
OUT="${2:-$HOME/Downloads/wechat_article_fallback/$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT"

MIN_CHARS="${MIN_CHARS:-800}"
MIN_LINES="${MIN_LINES:-8}"
COMMAND_TIMEOUT="${COMMAND_TIMEOUT:-75}"
CURL_TIMEOUT="${CURL_TIMEOUT:-30}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-8}"
BAD_PATTERN='(^Error:|^ERROR:|环境异常|验证后即可继续访问|CAPTCHA|captcha|Access Denied|Could not find article content|Failed to load page|Weixin Official Accounts Platform|WeChat Official Accounts Platform|去验证|登录后可继续|404 Not Found|Page not found|Target URL returned error)'

files=()
warnings=()

add_file() {
  local rel="$1"
  local existing
  [ -e "$OUT/$rel" ] || return 0
  if [ "${#files[@]}" -gt 0 ]; then
    for existing in "${files[@]}"; do
      [ "$existing" = "$rel" ] && return 0
    done
  fi
  files+=("$rel")
}

add_nonempty_file() {
  local rel="$1"
  [ -s "$OUT/$rel" ] || return 0
  files+=("$rel")
}

add_warning() {
  warnings+=("$1")
}

find_qiaomu_dir() {
  if [ -n "${QIAOMU_DIR:-}" ] && [ -d "$QIAOMU_DIR" ]; then
    printf '%s\n' "$QIAOMU_DIR"
    return 0
  fi

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

run_cmd() {
  local stdout="$1"
  local stderr="$2"
  local timeout_seconds="$3"
  shift 3

  python3 - "$stdout" "$stderr" "$timeout_seconds" "$@" <<'PY'
import subprocess
import sys

stdout_path, stderr_path, timeout_seconds, *cmd = sys.argv[1:]

with open(stdout_path, "wb") as out, open(stderr_path, "ab") as err:
    try:
        proc = subprocess.run(cmd, stdout=out, stderr=err, timeout=float(timeout_seconds))
    except subprocess.TimeoutExpired:
        err.write(f"\nTimed out after {timeout_seconds}s\n".encode("utf-8"))
        sys.exit(124)
    sys.exit(proc.returncode)
PY
}

printf '%s\n' "$URL" > "$OUT/original_url.txt"
add_file "original_url.txt"

is_good_markdown() {
  local file="$1"
  [ -s "$file" ] || return 1
  local chars lines
  chars=$(wc -m < "$file" | tr -d ' ')
  lines=$(awk 'NF { count++ } END { print count + 0 }' "$file")
  [ "$chars" -ge "$MIN_CHARS" ] || return 1
  [ "$lines" -ge "$MIN_LINES" ] || return 1
  ! grep -Eiq "$BAD_PATTERN" "$file"
}

status="blocked"
evidence="不可访问"
if [ -n "${QIAOMU_DIR:-}" ] && [ ! -d "$QIAOMU_DIR" ]; then
  add_warning "QIAOMU_DIR is set but does not exist: $QIAOMU_DIR"
fi
QIAOMU_DIR_FOUND="$(find_qiaomu_dir || true)"
if [ -z "$QIAOMU_DIR_FOUND" ]; then
  add_warning "qiaomu-markdown-proxy skill directory not found"
fi

# 1. Local Playwright fetch_weixin.py
if [ -n "$QIAOMU_DIR_FOUND" ] && [ -f "$QIAOMU_DIR_FOUND/scripts/fetch_weixin.py" ]; then
  if run_cmd "$OUT/article.md" "$OUT/fetch_weixin.err" "$COMMAND_TIMEOUT" python3 "$QIAOMU_DIR_FOUND/scripts/fetch_weixin.py" "$URL"; then
    add_file "article.md"
    add_nonempty_file "fetch_weixin.err"
    if is_good_markdown "$OUT/article.md"; then
      status="full_text"
      evidence="全文已读"
    else
      add_warning "fetch_weixin.py returned non-substantive or blocked content"
    fi
  else
    add_file "article.md"
    add_nonempty_file "fetch_weixin.err"
    add_warning "fetch_weixin.py failed or timed out; see fetch_weixin.err"
  fi
else
  add_warning "qiaomu fetch_weixin.py not found"
fi

# 2. qiaomu proxy cascade if still not full_text
if [ "$status" != "full_text" ] && [ -n "$QIAOMU_DIR_FOUND" ] && [ -f "$QIAOMU_DIR_FOUND/scripts/fetch.sh" ]; then
  if run_cmd "$OUT/proxy.md" "$OUT/proxy.err" "$COMMAND_TIMEOUT" bash "$QIAOMU_DIR_FOUND/scripts/fetch.sh" "$URL"; then
    add_file "proxy.md"
    add_nonempty_file "proxy.err"
    if is_good_markdown "$OUT/proxy.md"; then
      status="partial"
      evidence="proxy可读正文"
    else
      add_warning "qiaomu fetch.sh returned blocked or weak content"
    fi
  else
    add_file "proxy.md"
    add_nonempty_file "proxy.err"
    add_warning "qiaomu fetch.sh failed or timed out; see proxy.err"
  fi
elif [ "$status" != "full_text" ]; then
  add_warning "qiaomu fetch.sh not found"
fi

# 3. Direct proxies for diagnostics and occasional success
if [ "$status" != "full_text" ]; then
  if ! run_cmd "$OUT/jina.md" "$OUT/jina.err" "$CURL_TIMEOUT" curl -sSL --connect-timeout "$CONNECT_TIMEOUT" --max-time "$CURL_TIMEOUT" "https://r.jina.ai/$URL"; then
    add_warning "r.jina.ai fetch failed or timed out; see jina.err"
  fi
  add_file "jina.md"
  add_nonempty_file "jina.err"
  if [ "$status" = "blocked" ] && is_good_markdown "$OUT/jina.md"; then
    status="partial"
    evidence="jina可读正文"
  elif [ -s "$OUT/jina.md" ] && ! is_good_markdown "$OUT/jina.md"; then
    add_warning "r.jina.ai returned blocked or weak content"
  fi

  if ! run_cmd "$OUT/defuddle.md" "$OUT/defuddle.err" "$CURL_TIMEOUT" curl -sSL --connect-timeout "$CONNECT_TIMEOUT" --max-time "$CURL_TIMEOUT" "https://defuddle.md/$URL"; then
    add_warning "defuddle.md fetch failed or timed out; see defuddle.err"
  fi
  add_file "defuddle.md"
  add_nonempty_file "defuddle.err"
  if [ "$status" = "blocked" ] && is_good_markdown "$OUT/defuddle.md"; then
    status="partial"
    evidence="defuddle可读正文"
  elif [ -s "$OUT/defuddle.md" ] && ! is_good_markdown "$OUT/defuddle.md"; then
    add_warning "defuddle.md returned blocked or weak content"
  fi
fi

# 4. Write human-readable report
{
  printf '# WeChat Article Fetch Report\n\n'
  printf 'URL: %s\n' "$URL"
  printf 'Status: %s\n' "$status"
  printf 'Evidence: %s\n\n' "$evidence"
  printf '## Files\n'
  if [ "${#files[@]}" -eq 0 ]; then
    printf -- '- none\n'
  else
    printf -- '- %s\n' "${files[@]}"
  fi
  printf '\n## Warnings\n'
  if [ "${#warnings[@]}" -eq 0 ]; then
    printf -- '- none\n'
  else
    printf -- '- %s\n' "${warnings[@]}"
  fi
  printf '\nIf status is blocked or partial, continue manually with browser DOM extraction, local WeChat context, mirror/source search, and OCR per this skill.\n'
} > "$OUT/README.md"

add_file "README.md"
: > "$OUT/report.json"
add_file "report.json"

files_list="$OUT/files.list"
warnings_list="$OUT/warnings.list"
: > "$files_list"
: > "$warnings_list"
printf '%s\n' "${files[@]}" > "$files_list"
if [ "${#warnings[@]}" -gt 0 ]; then
  printf '%s\n' "${warnings[@]}" > "$warnings_list"
fi

python3 - "$URL" "$OUT" "$status" "$evidence" "$files_list" "$warnings_list" > "$OUT/report.json" <<'PY'
import json
import sys
from pathlib import Path

url, out, status, evidence, files_path, warnings_path = sys.argv[1:]

def read_lines(path):
    return [line for line in Path(path).read_text(encoding="utf-8").splitlines() if line]

print(json.dumps({
    "url": url,
    "output_dir": out,
    "status": status,
    "evidence_level": evidence,
    "files": read_lines(files_path),
    "warnings": read_lines(warnings_path),
}, ensure_ascii=False, indent=2))
PY

rm -f "$files_list" "$warnings_list"
cat "$OUT/report.json"

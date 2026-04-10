"""Shared small utilities for social-sbti."""
from __future__ import annotations

import re

_ILLEGAL_FS = re.compile(r'[/\\:*?"<>|\x00-\x1f]')
_WHITESPACE = re.compile(r"\s+")


def sanitize_name(name: str | None, fallback: str = "sbti") -> str:
    """文件名安全化:
    - 剥离 Windows/Mac 非法字符(/ \\ : * ? " < > | + 控制字符)
    - 折叠连续空白到单个连字符
    - 截到 30 字符
    - 去首尾连字符
    - 空字符串兜底到 fallback
    """
    if not name:
        return fallback
    s = _ILLEGAL_FS.sub("", name)
    s = _WHITESPACE.sub("-", s).strip("-")
    if len(s) > 30:
        s = s[:30].rstrip("-")
    return s or fallback

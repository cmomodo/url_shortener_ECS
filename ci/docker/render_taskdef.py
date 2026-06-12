#!/usr/bin/env python3
"""Render an ECS task definition template by substituting ${VAR} placeholders
with environment variables. Usage: render_taskdef.py <template> <output>."""
import os
import string
import sys


def main() -> int:
    if len(sys.argv) != 3:
        sys.stderr.write("usage: render_taskdef.py <template> <output>\n")
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as handle:
        template = string.Template(handle.read())
    with open(dst, "w", encoding="utf-8") as handle:
        handle.write(template.safe_substitute(os.environ))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

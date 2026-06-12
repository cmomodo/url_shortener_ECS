#!/usr/bin/env python3
"""Render an ECS task definition template by substituting ${VAR} placeholders
with environment variables. Usage: render_taskdef.py <template> <output>

Required environment variables:
  IMAGE_URI             Full ECR image URI including tag
  AWS_REGION            AWS region (e.g. us-east-1)
  EXECUTION_ROLE_ARN    ECS task execution role ARN
  TASK_ROLE_ARN         API task role ARN
  DATABASE_URL_ARN      SSM parameter ARN for DATABASE_URL
  SQS_QUEUE_URL_ARN     SSM parameter ARN for SQS_QUEUE_URL
  REDIS_URL_ARN         SSM parameter ARN for REDIS_URL
  LOG_GROUP             CloudWatch log group name (e.g. /ecs/api)
"""
import os
import re
import string
import sys


_REQUIRED_VARS = [
    "IMAGE_URI",
    "AWS_REGION",
    "EXECUTION_ROLE_ARN",
    "TASK_ROLE_ARN",
    "DATABASE_URL_ARN",
    "SQS_QUEUE_URL_ARN",
    "REDIS_URL_ARN",
    "LOG_GROUP",
]


def main() -> int:
    if len(sys.argv) != 3:
        sys.stderr.write("usage: render_taskdef.py <template> <output>\n")
        return 2

    missing = [v for v in _REQUIRED_VARS if not os.environ.get(v)]
    if missing:
        sys.stderr.write(
            "render_taskdef: missing required environment variables:\n"
            + "".join(f"  {v}\n" for v in missing)
        )
        return 1

    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as fh:
        template = string.Template(fh.read())

    try:
        rendered = template.substitute(os.environ)
    except KeyError as exc:
        sys.stderr.write(f"render_taskdef: unresolved placeholder {exc} in {src}\n")
        return 1

    remaining = re.findall(r"\$\{[^}]+\}", rendered)
    if remaining:
        sys.stderr.write(
            f"render_taskdef: unreplaced placeholders after substitution: {remaining}\n"
        )
        return 1

    with open(dst, "w", encoding="utf-8") as fh:
        fh.write(rendered)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

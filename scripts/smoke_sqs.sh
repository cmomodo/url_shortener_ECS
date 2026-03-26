#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

required_vars=(
  SQS_QUEUE_URL
  AWS_REGION
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
)

missing=()
for key in "${required_vars[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    missing+=("$key")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required env vars: %s\n' "${missing[*]}" >&2
  exit 1
fi

if [[ -n "${AWS_ENDPOINT_URL:-}" ]]; then
  printf 'AWS_ENDPOINT_URL is set to %s; this smoke test expects default AWS, not LocalStack.\n' "$AWS_ENDPOINT_URL" >&2
  exit 1
fi

if docker compose ps -q worker | grep -q .; then
  printf 'Worker container is running. Stop it before this smoke test or it may consume the message before verification.\n' >&2
  exit 1
fi

QUEUE_NAME="${SQS_QUEUE_URL##*/}"
CORRELATION_SEED="$(python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
)"
SHORT_URL="https://example.com/sqs-smoke-${CORRELATION_SEED}"
USER_AGENT="sqs-smoke-test/${CORRELATION_SEED}"
REFERER="https://smoke.local/test/${CORRELATION_SEED}"
export SHORT_URL

printf 'Queue URL: %s\n' "$SQS_QUEUE_URL"
printf 'Queue name: %s\n' "$QUEUE_NAME"
printf 'AWS region: %s\n' "$AWS_REGION"
printf 'Smoke URL: %s\n' "$SHORT_URL"
printf 'User-Agent: %s\n' "$USER_AGENT"

printf 'Starting API, Postgres, and Redis containers...\n'
docker compose up -d --build postgres redis api >/dev/null

printf 'Waiting for API health...\n'
for _ in $(seq 1 30); do
  if curl -fsS "http://localhost:8080/healthz" >/dev/null; then
    break
  fi
  sleep 2
done

if ! curl -fsS "http://localhost:8080/healthz" >/dev/null; then
  printf 'API health check did not become ready.\n' >&2
  exit 1
fi

printf 'Creating short URL...\n'
SHORTEN_RESPONSE="$(
  curl -fsS \
    -X POST \
    -H 'Content-Type: application/json' \
    -d "$(python3 - <<'PY'
import json, os
print(json.dumps({"url": os.environ["SHORT_URL"]}))
PY
)" \
    "http://localhost:8080/shorten"
)"
export SHORTEN_RESPONSE

SHORT_CODE="$(
  python3 - <<'PY'
import json, os
data = json.loads(os.environ["SHORTEN_RESPONSE"])
print(data["short"])
PY
)"

printf 'Short code: %s\n' "$SHORT_CODE"
printf 'Shorten response: %s\n' "$SHORTEN_RESPONSE"

printf 'Triggering redirect route to publish the SQS event...\n'
curl -fsS \
  -o /dev/null \
  -D /tmp/sqs_smoke_headers.$$ \
  -H "User-Agent: $USER_AGENT" \
  -H "Referer: $REFERER" \
  "http://localhost:8080/$SHORT_CODE" || true

printf 'Polling SQS for the matching click event...\n'
FOUND_JSON=""
for _ in $(seq 1 12); do
  RECEIVE_JSON="$(
    aws sqs receive-message \
      --queue-url "$SQS_QUEUE_URL" \
      --max-number-of-messages 10 \
      --wait-time-seconds 2 \
      --visibility-timeout 0 \
      --message-attribute-names All \
      --attribute-names All \
      --region "$AWS_REGION" \
      --output json
  )"
  if FOUND_JSON="$(
    SHORT_CODE="$SHORT_CODE" USER_AGENT="$USER_AGENT" RECEIVE_JSON="$RECEIVE_JSON" python3 - <<'PY'
import json, os, sys
short_code = os.environ["SHORT_CODE"]
user_agent = os.environ["USER_AGENT"]
payload = json.loads(os.environ["RECEIVE_JSON"])
for msg in payload.get("Messages", []):
    body = msg.get("Body", "")
    attrs = msg.get("MessageAttributes", {})
    msg_corr = attrs.get("CorrelationId", {}).get("StringValue", "")
    if short_code in body or user_agent in body or short_code == msg_corr:
        print(json.dumps(msg))
        sys.exit(0)
sys.exit(1)
PY
  )"; then
    break
  fi
done

if [[ -z "$FOUND_JSON" ]]; then
  printf 'No matching SQS message found for short code %s.\n' "$SHORT_CODE" >&2
  printf 'This usually means the publish path did not run, the queue was empty, or another consumer removed the message first.\n' >&2
  exit 1
fi

printf 'Matched SQS message:\n%s\n' "$FOUND_JSON"
printf 'Smoke test PASS: redirect path published a queue message.\n'

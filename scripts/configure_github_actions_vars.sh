#!/usr/bin/env bash
set -euo pipefail

REPO=""
ENV_FILE=".env"
LOAD_ENV_FILE="true"
DRY_RUN="false"
LIST_ONLY="false"
SKIP_SECRET="false"

usage() {
  cat <<'EOF'
Configure GitHub Actions repository variables and secrets for the Terraform pipeline.

By default this script loads values from .env, then pushes them into GitHub
Actions as repository variables and secrets. Use .env.example as the template.

Usage:
  scripts/configure_github_actions_vars.sh [options]

Options:
  --repo OWNER/REPO              GitHub repository. Defaults to the current gh repo.
  --env-file PATH                Load values from a different env file.
  --no-env-file                  Do not load an env file; use exported shell values and flags only.
  --aws-region VALUE            Set AWS_REGION.
  --tf-state-bucket VALUE       Set TF_STATE_BUCKET.
  --tf-state-key VALUE          Set TF_STATE_KEY.
  --tf-bootstrap-state-key VALUE
                                Set TF_BOOTSTRAP_STATE_KEY.
  --tf-in-automation VALUE      Set TF_IN_AUTOMATION.
  --role-arn VALUE              Set AWS_TERRAFORM_ROLE_ARN secret.
  --skip-secret                 Only manage variables, not AWS_TERRAFORM_ROLE_ARN.
  --list                        List current Actions variables and secrets, then exit.
  --dry-run                     Print what would change without calling GitHub.
  -h, --help                    Show this help.

Examples:
  scripts/configure_github_actions_vars.sh --repo OWNER/REPO

  scripts/configure_github_actions_vars.sh --env-file .env.production --dry-run
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "missing required command: $1"
  fi
}

load_env_file() {
  if [[ "$LOAD_ENV_FILE" != "true" ]]; then
    return
  fi

  if [[ ! -f "$ENV_FILE" ]]; then
    return
  fi

  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
}

resolve_repo() {
  if [[ -n "$REPO" ]]; then
    printf '%s\n' "$REPO"
    return
  fi

  gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null ||
    die "could not determine repository. Pass --repo OWNER/REPO."
}

run_or_print() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] %s\n' "$*"
    return
  fi

  "$@"
}

set_variable() {
  local repo="$1"
  local name="$2"
  local value="$3"

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] gh variable set %s --repo %s --body %q\n' "$name" "$repo" "$value"
    return
  fi

  gh variable set "$name" --repo "$repo" --body "$value"
}

set_secret() {
  local repo="$1"
  local name="$2"
  local value="$3"

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] gh secret set %s --repo %s <redacted>\n' "$name" "$repo"
    return
  fi

  printf '%s' "$value" | gh secret set "$name" --repo "$repo"
}

for ((i = 1; i <= $#; i++)); do
  arg="${!i}"
  case "$arg" in
    --env-file)
      next_index=$((i + 1))
      ENV_FILE="${!next_index:-}"
      [[ -n "$ENV_FILE" ]] || die "--env-file requires a value"
      ;;
    --no-env-file)
      LOAD_ENV_FILE="false"
      ;;
  esac
done

load_env_file

AWS_REGION_VALUE="${AWS_REGION:-}"
TF_STATE_BUCKET_VALUE="${TF_STATE_BUCKET:-}"
TF_STATE_KEY_VALUE="${TF_STATE_KEY:-}"
TF_BOOTSTRAP_STATE_KEY_VALUE="${TF_BOOTSTRAP_STATE_KEY:-}"
TF_IN_AUTOMATION_VALUE="${TF_IN_AUTOMATION:-true}"
AWS_TERRAFORM_ROLE_ARN_VALUE="${AWS_TERRAFORM_ROLE_ARN:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --no-env-file)
      LOAD_ENV_FILE="false"
      shift
      ;;
    --aws-region)
      AWS_REGION_VALUE="${2:-}"
      shift 2
      ;;
    --tf-state-bucket)
      TF_STATE_BUCKET_VALUE="${2:-}"
      shift 2
      ;;
    --tf-state-key)
      TF_STATE_KEY_VALUE="${2:-}"
      shift 2
      ;;
    --tf-bootstrap-state-key)
      TF_BOOTSTRAP_STATE_KEY_VALUE="${2:-}"
      shift 2
      ;;
    --tf-in-automation)
      TF_IN_AUTOMATION_VALUE="${2:-}"
      shift 2
      ;;
    --role-arn)
      AWS_TERRAFORM_ROLE_ARN_VALUE="${2:-}"
      shift 2
      ;;
    --skip-secret)
      SKIP_SECRET="true"
      shift
      ;;
    --list)
      LIST_ONLY="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

require_command gh

[[ -n "$AWS_REGION_VALUE" ]] || die "AWS_REGION cannot be empty"
[[ -n "$TF_STATE_BUCKET_VALUE" ]] || die "TF_STATE_BUCKET cannot be empty"
[[ -n "$TF_STATE_KEY_VALUE" ]] || die "TF_STATE_KEY cannot be empty"
[[ -n "$TF_BOOTSTRAP_STATE_KEY_VALUE" ]] || die "TF_BOOTSTRAP_STATE_KEY cannot be empty"
[[ -n "$TF_IN_AUTOMATION_VALUE" ]] || die "TF_IN_AUTOMATION cannot be empty"
[[ "$TF_STATE_KEY_VALUE" != "$TF_BOOTSTRAP_STATE_KEY_VALUE" ]] ||
  die "TF_STATE_KEY and TF_BOOTSTRAP_STATE_KEY must be different state keys"

repo="$(resolve_repo)"

if [[ "$LIST_ONLY" == "true" ]]; then
  printf 'GitHub Actions variables for %s:\n' "$repo"
  run_or_print gh variable list --repo "$repo"
  printf '\nGitHub Actions secrets for %s:\n' "$repo"
  run_or_print gh secret list --repo "$repo"
  exit 0
fi

printf 'Configuring GitHub Actions variables for %s...\n' "$repo"
set_variable "$repo" AWS_REGION "$AWS_REGION_VALUE"
set_variable "$repo" TF_STATE_BUCKET "$TF_STATE_BUCKET_VALUE"
set_variable "$repo" TF_STATE_KEY "$TF_STATE_KEY_VALUE"
set_variable "$repo" TF_BOOTSTRAP_STATE_KEY "$TF_BOOTSTRAP_STATE_KEY_VALUE"
set_variable "$repo" TF_IN_AUTOMATION "$TF_IN_AUTOMATION_VALUE"

if [[ "$SKIP_SECRET" == "true" ]]; then
  printf 'Skipping AWS_TERRAFORM_ROLE_ARN secret.\n'
elif [[ -z "$AWS_TERRAFORM_ROLE_ARN_VALUE" ]]; then
  die "AWS_TERRAFORM_ROLE_ARN is required. Set it in the environment, pass --role-arn, or use --skip-secret."
else
  printf 'Configuring GitHub Actions secret AWS_TERRAFORM_ROLE_ARN for %s...\n' "$repo"
  set_secret "$repo" AWS_TERRAFORM_ROLE_ARN "$AWS_TERRAFORM_ROLE_ARN_VALUE"
fi

printf 'Done.\n'

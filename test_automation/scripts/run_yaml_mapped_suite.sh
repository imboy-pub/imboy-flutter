#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAN_FILE="$PROJECT_DIR/test_automation/scenarios/executable_cases.yaml"
STATE_ROOT="$PROJECT_DIR/test_automation/.state_yaml"
RESULT_ROOT="$PROJECT_DIR/test_automation/reports/yaml_runs"
NULL_FIELD="__YAML_RUNNER_EMPTY__"

RUN_ID_INPUT="${RUN_ID:-}"
RESUME=0
DRY_RUN=0
RERUN_FAILED=0
MAX_RETRIES="${MAX_RETRIES:-0}"
TASK_TIMEOUT_SECONDS="${TASK_TIMEOUT_SECONDS:-1200}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

usage() {
  cat <<'EOF'
YAML mapped suite runner (resumable, machine-readable reports)

Usage:
  test_automation/scripts/run_yaml_mapped_suite.sh [options]

Options:
  --plan-file <file>     YAML mapping file (default: test_automation/scenarios/executable_cases.yaml)
  --run-id <id>          Fixed RUN_ID.
  --resume               Resume existing RUN_ID state (or latest when --run-id omitted).
  --dry-run              Parse plan and print planned execution only.
  --rerun-failed         Re-run cases with FAIL state.
  --max-retries <n>      Global retry cap for retryable failures (default: 0).
  --task-timeout-seconds <sec>  Per-case hard timeout (default: 1200).
  -h, --help             Show help.
EOF
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_quotes() {
  local value
  value="$(trim "$1")"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

latest_run_id() {
  if [[ ! -d "$STATE_ROOT" ]]; then
    return 1
  fi
  local latest
  latest=$(find "$STATE_ROOT" -mindepth 1 -maxdepth 1 -type d -print | sed 's#.*/##' | sort | tail -1)
  [[ -n "$latest" ]] || return 1
  echo "$latest"
}

status_file() {
  local run_state_dir="$1"
  local case_id="$2"
  echo "$run_state_dir/${case_id}.status"
}

meta_file() {
  local run_state_dir="$1"
  local case_id="$2"
  echo "$run_state_dir/${case_id}.meta"
}

read_status() {
  local run_state_dir="$1"
  local case_id="$2"
  local file
  file="$(status_file "$run_state_dir" "$case_id")"
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo "PENDING"
  fi
}

write_status() {
  local run_state_dir="$1"
  local case_id="$2"
  local status="$3"
  echo "$status" >"$(status_file "$run_state_dir" "$case_id")"
}

write_meta() {
  local run_state_dir="$1"
  local case_id="$2"
  local started_at="$3"
  local ended_at="$4"
  local rc="$5"
  local attempt="$6"
  local scenario_file="$7"
  local test_file="$8"
  local action="$9"
  local timeout_seconds="${10}"
  local retry="${11}"
  local precondition="${12}"
  local assertions="${13}"
  local log_file="${14}"
  local enabled="${15}"
  local test_layer="${16}"
  local verification_level="${17}"
  local truth_source="${18}"

  cat >"$(meta_file "$run_state_dir" "$case_id")" <<EOF
case_id=$case_id
started_at=$started_at
ended_at=$ended_at
rc=$rc
attempt=$attempt
scenario_file=$scenario_file
test_file=$test_file
action=$action
timeout_seconds=$timeout_seconds
retry=$retry
precondition=$precondition
assertions=$assertions
log_file=$log_file
enabled=$enabled
test_layer=$test_layer
verification_level=$verification_level
truth_source=$truth_source
EOF
}

is_retryable_failure() {
  local rc="$1"
  local log_file="$2"
  if [[ "$rc" -eq 124 ]]; then
    return 0
  fi
  if [[ ! -f "$log_file" ]]; then
    return 1
  fi
  grep -Eiq "timed out|connection reset|temporary failure|socketexception|handshakeexception|service unavailable|too many requests|network unavailable|future not completed|failed to foreground app|步骤超时" "$log_file"
}

is_soft_skip_log() {
  local log_file="$1"
  if [[ ! -f "$log_file" ]]; then
    return 1
  fi
  grep -Eq "\[AUTO-SKIP\]|skip.*自动化测试|跳过.*自动化测试" "$log_file"
}

is_infra_soft_skip_failure() {
  local rc="$1"
  local log_file="$2"
  if [[ "$rc" -eq 0 || ! -f "$log_file" ]]; then
    return 1
  fi
  grep -Eiq \
    "No profiles for '.*' were found|Automatic signing is disabled|Unable to find a destination matching the provided destination specifier|Could not build the application for the simulator|Unable to start the app on the device" \
    "$log_file"
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  "$@" &
  local cmd_pid=$!
  local elapsed=0
  while kill -0 "$cmd_pid" >/dev/null 2>&1; do
    if [[ "$elapsed" -ge "$timeout_seconds" ]]; then
      warn "Case timeout reached (${timeout_seconds}s)"
      kill "$cmd_pid" >/dev/null 2>&1 || true
      sleep 2
      kill -9 "$cmd_pid" >/dev/null 2>&1 || true
      wait "$cmd_pid" >/dev/null 2>&1 || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$cmd_pid"
  return $?
}

parse_plan_to_tsv() {
  local plan_file="$1"
  local output_tsv="$2"
  awk -v null_field="$NULL_FIELD" '
  function trim(s) {
    gsub(/^[ \t]+|[ \t]+$/, "", s);
    return s;
  }
  function deq(s) {
    s = trim(s);
    if (s ~ /^".*"$/) {
      s = substr(s, 2, length(s) - 2);
    }
    return s;
  }
  function nz(s) {
    if (s == "") {
      return null_field;
    }
    return s;
  }
  function emit_case() {
    if (case_id == "") {
      return;
    }
    if (enabled == "") enabled = def_enabled;
    if (action == "") action = def_action;
    if (device == "") device = def_device;
    if (timeout_seconds == "") timeout_seconds = def_timeout;
    if (retry == "") retry = def_retry;
    if (dart_defines == "") dart_defines = def_dart_defines;
    if (test_layer == "") test_layer = def_test_layer;
    if (verification_level == "") verification_level = def_verification_level;
    if (truth_source == "") truth_source = def_truth_source;
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", \
      nz(case_id), nz(scenario_file), nz(test_file), nz(action), nz(device), nz(timeout_seconds), nz(retry), nz(enabled), nz(precondition), nz(assertions), nz(dart_defines), nz(test_layer), nz(verification_level), nz(truth_source);
  }
  BEGIN {
    def_action = "flutter_test";
    def_device = "macos";
    def_timeout = "900";
    def_retry = "0";
    def_enabled = "true";
    def_dart_defines = "";
    def_test_layer = "";
    def_verification_level = "strict";
    def_truth_source = "";
    in_defaults = 0;
    in_cases = 0;
    case_id = "";
  }
  {
    line = $0;
    sub(/#.*/, "", line);
    line = trim(line);
    if (line == "") next;

    if (line == "defaults:") {
      in_defaults = 1;
      in_cases = 0;
      next;
    }
    if (line == "cases:") {
      in_defaults = 0;
      in_cases = 1;
      next;
    }

    if (in_defaults == 1) {
      if (line ~ /^action:/) {
        sub(/^action:[ \t]*/, "", line);
        def_action = deq(line);
      } else if (line ~ /^device:/) {
        sub(/^device:[ \t]*/, "", line);
        def_device = deq(line);
      } else if (line ~ /^timeout_seconds:/) {
        sub(/^timeout_seconds:[ \t]*/, "", line);
        def_timeout = deq(line);
      } else if (line ~ /^retry:/) {
        sub(/^retry:[ \t]*/, "", line);
        def_retry = deq(line);
      } else if (line ~ /^enabled:/) {
        sub(/^enabled:[ \t]*/, "", line);
        def_enabled = tolower(deq(line));
      } else if (line ~ /^dart_defines:/) {
        sub(/^dart_defines:[ \t]*/, "", line);
        def_dart_defines = deq(line);
      } else if (line ~ /^test_layer:/) {
        sub(/^test_layer:[ \t]*/, "", line);
        def_test_layer = deq(line);
      } else if (line ~ /^verification_level:/) {
        sub(/^verification_level:[ \t]*/, "", line);
        def_verification_level = deq(line);
      } else if (line ~ /^truth_source:/) {
        sub(/^truth_source:[ \t]*/, "", line);
        def_truth_source = deq(line);
      }
      next;
    }

    if (in_cases == 1) {
      if (line ~ /^-[ \t]*case_id:/) {
        emit_case();
        sub(/^-[ \t]*case_id:[ \t]*/, "", line);
        case_id = deq(line);
        enabled = "";
        scenario_file = "";
        precondition = "";
        action = "";
        test_file = "";
        device = "";
        assertions = "";
        timeout_seconds = "";
        retry = "";
        dart_defines = "";
        test_layer = "";
        verification_level = "";
        truth_source = "";
      } else if (line ~ /^enabled:/) {
        sub(/^enabled:[ \t]*/, "", line);
        enabled = tolower(deq(line));
      } else if (line ~ /^scenario_file:/) {
        sub(/^scenario_file:[ \t]*/, "", line);
        scenario_file = deq(line);
      } else if (line ~ /^precondition:/) {
        sub(/^precondition:[ \t]*/, "", line);
        precondition = deq(line);
      } else if (line ~ /^action:/) {
        sub(/^action:[ \t]*/, "", line);
        action = deq(line);
      } else if (line ~ /^test_file:/) {
        sub(/^test_file:[ \t]*/, "", line);
        test_file = deq(line);
      } else if (line ~ /^device:/) {
        sub(/^device:[ \t]*/, "", line);
        device = deq(line);
      } else if (line ~ /^assertions:/) {
        sub(/^assertions:[ \t]*/, "", line);
        assertions = deq(line);
      } else if (line ~ /^timeout_seconds:/) {
        sub(/^timeout_seconds:[ \t]*/, "", line);
        timeout_seconds = deq(line);
      } else if (line ~ /^retry:/) {
        sub(/^retry:[ \t]*/, "", line);
        retry = deq(line);
      } else if (line ~ /^dart_defines:/) {
        sub(/^dart_defines:[ \t]*/, "", line);
        dart_defines = deq(line);
      } else if (line ~ /^test_layer:/) {
        sub(/^test_layer:[ \t]*/, "", line);
        test_layer = deq(line);
      } else if (line ~ /^verification_level:/) {
        sub(/^verification_level:[ \t]*/, "", line);
        verification_level = deq(line);
      } else if (line ~ /^truth_source:/) {
        sub(/^truth_source:[ \t]*/, "", line);
        truth_source = deq(line);
      }
    }
  }
  END {
    emit_case();
  }
  ' "$plan_file" >"$output_tsv"
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s' "$value"
}

restore_null_field() {
  local value="$1"
  if [[ "$value" == "$NULL_FIELD" ]]; then
    printf ''
    return
  fi
  printf '%s' "$value"
}

normalize_plan_record_vars() {
  local field value
  for field in \
    case_id scenario_file test_file action device timeout_seconds retry enabled \
    precondition assertions dart_defines test_layer verification_level truth_source; do
    value="${!field-}"
    printf -v "$field" '%s' "$(restore_null_field "$value")"
  done
}

derive_test_layer() {
  local explicit="$1"
  local test_file="$2"
  if [[ -n "$explicit" ]]; then
    printf '%s' "$explicit"
    return
  fi

  case "$test_file" in
    integration_test/*)
      printf '%s' "client_ui_integration"
      ;;
    test/integration/*)
      printf '%s' "client_logic_integration"
      ;;
    test/page/*|test/component/*)
      printf '%s' "client_component_regression"
      ;;
    test/service/*|test/store/*)
      printf '%s' "client_logic_regression"
      ;;
    *)
      printf '%s' "client_mixed_regression"
      ;;
  esac
}

derive_verification_level() {
  local explicit="$1"
  if [[ -n "$explicit" ]]; then
    printf '%s' "$explicit"
    return
  fi
  printf '%s' "strict"
}

derive_truth_source() {
  local explicit="$1"
  local action="$2"
  local test_file="$3"
  if [[ -n "$explicit" ]]; then
    printf '%s' "$explicit"
    return
  fi

  if [[ "$test_file" == integration_test/* ]]; then
    printf '%s' "flutter_integration_test"
    return
  fi

  case "$action" in
    flutter_test)
      printf '%s' "flutter_test"
      ;;
    *)
      printf '%s' "$action"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-file)
      [[ $# -ge 2 ]] || { error "--plan-file requires a value"; exit 2; }
      PLAN_FILE="$2"
      shift 2
      ;;
    --run-id)
      [[ $# -ge 2 ]] || { error "--run-id requires a value"; exit 2; }
      RUN_ID_INPUT="$2"
      shift 2
      ;;
    --resume)
      RESUME=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --rerun-failed)
      RERUN_FAILED=1
      shift
      ;;
    --max-retries)
      [[ $# -ge 2 ]] || { error "--max-retries requires a value"; exit 2; }
      MAX_RETRIES="$2"
      shift 2
      ;;
    --task-timeout-seconds)
      [[ $# -ge 2 ]] || { error "--task-timeout-seconds requires a value"; exit 2; }
      TASK_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ ! -f "$PLAN_FILE" ]]; then
  error "Plan file not found: $PLAN_FILE"
  exit 2
fi

if ! [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]]; then
  error "--max-retries must be a non-negative integer"
  exit 2
fi

if ! [[ "$TASK_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$TASK_TIMEOUT_SECONDS" -le 0 ]]; then
  error "--task-timeout-seconds must be a positive integer"
  exit 2
fi

RUN_ID="$RUN_ID_INPUT"
if [[ $RESUME -eq 1 ]]; then
  if [[ -z "$RUN_ID" ]]; then
    if ! RUN_ID="$(latest_run_id)"; then
      error "No previous YAML state found. Use fresh run without --resume."
      exit 2
    fi
    info "Auto-selected latest RUN_ID for resume: $RUN_ID"
  fi
else
  if [[ -z "$RUN_ID" ]]; then
    RUN_ID="yaml_$(date +%Y%m%d_%H%M%S)"
  fi
fi

RUN_STATE_DIR="$STATE_ROOT/$RUN_ID"
RUN_RESULT_DIR="$RESULT_ROOT/$RUN_ID"
PARSED_PLAN_TSV="$RUN_RESULT_DIR/parsed_plan.tsv"
SUMMARY_TSV="$RUN_RESULT_DIR/summary.tsv"
SUMMARY_MD="$RUN_RESULT_DIR/summary.md"
RESULT_JSON="$RUN_RESULT_DIR/results.json"
JUNIT_XML="$RUN_RESULT_DIR/results.junit.xml"

mkdir -p "$RUN_STATE_DIR" "$RUN_RESULT_DIR"

parse_plan_to_tsv "$PLAN_FILE" "$PARSED_PLAN_TSV"

if [[ ! -s "$PARSED_PLAN_TSV" ]]; then
  error "No cases parsed from plan: $PLAN_FILE"
  exit 2
fi

if [[ ! -f "$RUN_STATE_DIR/run.meta" ]]; then
  cat >"$RUN_STATE_DIR/run.meta" <<EOF
run_id=$RUN_ID
created_at=$(date +'%Y-%m-%d %H:%M:%S')
plan_file=$PLAN_FILE
project_dir=$PROJECT_DIR
EOF
fi

while IFS=$'\t' read -r case_id _; do
  normalize_plan_record_vars
  if [[ ! -f "$(status_file "$RUN_STATE_DIR" "$case_id")" ]]; then
    write_status "$RUN_STATE_DIR" "$case_id" "PENDING"
  fi
done <"$PARSED_PLAN_TSV"

log "YAML mapped suite started. RUN_ID=$RUN_ID"
info "Plan: $PLAN_FILE"
info "State dir: $RUN_STATE_DIR"
info "Result dir: $RUN_RESULT_DIR"
info "Task timeout: ${TASK_TIMEOUT_SECONDS}s | Global retries: ${MAX_RETRIES}"

if [[ $DRY_RUN -eq 1 ]]; then
  warn "Dry run enabled. No case will be executed."
fi

any_failed=0
total_cases=0

while IFS=$'\t' read -r case_id scenario_file test_file action device timeout_seconds retry enabled precondition assertions dart_defines test_layer verification_level truth_source; do
  normalize_plan_record_vars
  total_cases=$((total_cases + 1))
  case_status="$(read_status "$RUN_STATE_DIR" "$case_id")"
  case_log="$RUN_RESULT_DIR/${case_id}.runner.log"
  resolved_test_layer="$(derive_test_layer "$test_layer" "$test_file")"
  resolved_verification_level="$(derive_verification_level "$verification_level")"
  resolved_truth_source="$(derive_truth_source "$truth_source" "$action" "$test_file")"

  enabled_lc="$(echo "$enabled" | tr '[:upper:]' '[:lower:]')"
  if [[ "$enabled_lc" != "true" && "$enabled_lc" != "1" && "$enabled_lc" != "yes" ]]; then
    write_status "$RUN_STATE_DIR" "$case_id" "SKIPPED"
    write_meta "$RUN_STATE_DIR" "$case_id" "-" "-" "0" "0" "$scenario_file" "$test_file" "$action" "$timeout_seconds" "$retry" "$precondition" "$assertions" "$case_log" "$enabled_lc" "$resolved_test_layer" "$resolved_verification_level" "$resolved_truth_source"
    info "Skip $case_id (disabled in plan)"
    continue
  fi

  if [[ "$case_status" == "PASS_STRICT" ]]; then
    info "Skip $case_id (already PASS_STRICT)"
    continue
  fi
  if [[ "$case_status" == "PASS_WEAK" ]]; then
    info "Skip $case_id (already PASS_WEAK)"
    continue
  fi
  if [[ "$case_status" == "BLOCKED" ]]; then
    info "Skip $case_id (already BLOCKED)"
    continue
  fi
  if [[ "$case_status" == "FAIL" && $RERUN_FAILED -eq 0 ]]; then
    warn "Skip $case_id (FAIL). Use --rerun-failed to retry."
    any_failed=1
    continue
  fi

  if [[ ! -f "$PROJECT_DIR/$scenario_file" ]]; then
    error "Scenario file missing for $case_id: $scenario_file"
    write_status "$RUN_STATE_DIR" "$case_id" "FAIL"
    write_meta "$RUN_STATE_DIR" "$case_id" "$(date +'%Y-%m-%d %H:%M:%S')" "$(date +'%Y-%m-%d %H:%M:%S')" "127" "0" "$scenario_file" "$test_file" "$action" "$timeout_seconds" "$retry" "$precondition" "$assertions" "$case_log" "$enabled_lc" "$resolved_test_layer" "$resolved_verification_level" "$resolved_truth_source"
    any_failed=1
    continue
  fi

  if [[ ! -f "$PROJECT_DIR/$test_file" ]]; then
    error "Test file missing for $case_id: $test_file"
    write_status "$RUN_STATE_DIR" "$case_id" "FAIL"
    write_meta "$RUN_STATE_DIR" "$case_id" "$(date +'%Y-%m-%d %H:%M:%S')" "$(date +'%Y-%m-%d %H:%M:%S')" "127" "0" "$scenario_file" "$test_file" "$action" "$timeout_seconds" "$retry" "$precondition" "$assertions" "$case_log" "$enabled_lc" "$resolved_test_layer" "$resolved_verification_level" "$resolved_truth_source"
    any_failed=1
    continue
  fi

  if [[ "$action" != "flutter_test" ]]; then
    error "Unsupported action for $case_id: $action"
    write_status "$RUN_STATE_DIR" "$case_id" "FAIL"
    write_meta "$RUN_STATE_DIR" "$case_id" "$(date +'%Y-%m-%d %H:%M:%S')" "$(date +'%Y-%m-%d %H:%M:%S')" "2" "0" "$scenario_file" "$test_file" "$action" "$timeout_seconds" "$retry" "$precondition" "$assertions" "$case_log" "$enabled_lc" "$resolved_test_layer" "$resolved_verification_level" "$resolved_truth_source"
    any_failed=1
    continue
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    info "Plan case: $case_id -> $action $test_file (layer=$resolved_test_layer verification=$resolved_verification_level truth=$resolved_truth_source device=$device timeout=${timeout_seconds}s retry=$retry defines=$dart_defines)"
    continue
  fi

  log "Run case: $case_id"
  attempt=0
  case_retry="$retry"
  if ! [[ "$case_retry" =~ ^[0-9]+$ ]]; then
    case_retry=0
  fi
  effective_retry="$case_retry"
  if [[ "$MAX_RETRIES" -gt "$effective_retry" ]]; then
    effective_retry="$MAX_RETRIES"
  fi

  while true; do
    attempt=$((attempt + 1))
    started_at="$(date +'%Y-%m-%d %H:%M:%S')"
    case_timeout="$timeout_seconds"
    if ! [[ "$case_timeout" =~ ^[0-9]+$ ]] || [[ "$case_timeout" -le 0 ]]; then
      case_timeout="$TASK_TIMEOUT_SECONDS"
    fi
    if [[ "$case_timeout" -gt "$TASK_TIMEOUT_SECONDS" ]]; then
      case_timeout="$TASK_TIMEOUT_SECONDS"
    fi

    cmd=(flutter test "$test_file" --reporter=github)
    if [[ -n "$device" && "$device" != "any" ]]; then
      cmd+=(-d "$device")
    fi
    if [[ -n "$dart_defines" ]]; then
      IFS=',' read -ra define_pairs <<<"$dart_defines"
      for pair in "${define_pairs[@]}"; do
        pair="$(trim "$pair")"
        [[ -z "$pair" ]] && continue
        cmd+=("--dart-define=$pair")
      done
    fi

    set +e
    run_with_timeout "$case_timeout" "${cmd[@]}" >"$case_log" 2>&1
    rc=$?
    set -e

    ended_at="$(date +'%Y-%m-%d %H:%M:%S')"
    write_meta "$RUN_STATE_DIR" "$case_id" "$started_at" "$ended_at" "$rc" "$attempt" "$scenario_file" "$test_file" "$action" "$case_timeout" "$effective_retry" "$precondition" "$assertions" "$case_log" "$enabled_lc" "$resolved_test_layer" "$resolved_verification_level" "$resolved_truth_source"

    if [[ "$rc" -eq 0 ]]; then
      if is_soft_skip_log "$case_log"; then
        write_status "$RUN_STATE_DIR" "$case_id" "BLOCKED"
        warn "Case BLOCKED: $case_id (soft-skip attempt=$attempt)"
      elif [[ "$resolved_verification_level" == "weak" ]]; then
        write_status "$RUN_STATE_DIR" "$case_id" "PASS_WEAK"
        warn "Case PASS_WEAK: $case_id (attempt=$attempt)"
      else
        write_status "$RUN_STATE_DIR" "$case_id" "PASS_STRICT"
        log "Case PASS_STRICT: $case_id (attempt=$attempt)"
      fi
      break
    fi

    if is_infra_soft_skip_failure "$rc" "$case_log"; then
      write_status "$RUN_STATE_DIR" "$case_id" "BLOCKED"
      warn "Case BLOCKED: $case_id (infra rc=$rc, attempt=$attempt)"
      break
    fi

    if [[ "$attempt" -le "$effective_retry" ]] && is_retryable_failure "$rc" "$case_log"; then
      warn "Case retry: $case_id (attempt=$attempt/$((effective_retry + 1)))"
      sleep 2
      continue
    fi

    write_status "$RUN_STATE_DIR" "$case_id" "FAIL"
    error "Case FAIL: $case_id (rc=$rc, attempt=$attempt)"
    warn "See case log: $case_log"
    any_failed=1
    break
  done
done <"$PARSED_PLAN_TSV"

{
  echo -e "case_id\tstatus\trc\tattempt\tscenario_file\ttest_file\taction\ttest_layer\tverification_level\ttruth_source\ttimeout_seconds\tretry\tprecondition\tassertions\tstarted_at\tended_at\tduration_seconds\tlog_file"
  while IFS=$'\t' read -r case_id scenario_file test_file action device timeout_seconds retry enabled precondition assertions dart_defines test_layer verification_level truth_source; do
    normalize_plan_record_vars
    status="$(read_status "$RUN_STATE_DIR" "$case_id")"
    mfile="$(meta_file "$RUN_STATE_DIR" "$case_id")"
    rc="-"
    attempt="-"
    started_at="-"
    ended_at="-"
    log_file="-"
    timeout_from_meta="$timeout_seconds"
    retry_from_meta="$retry"
    duration_seconds="-"
    test_layer_from_meta="$(derive_test_layer "$test_layer" "$test_file")"
    verification_from_meta="$(derive_verification_level "$verification_level")"
    truth_from_meta="$(derive_truth_source "$truth_source" "$action" "$test_file")"
    if [[ -f "$mfile" ]]; then
      rc="$(awk -F= '$1=="rc"{print $2}' "$mfile" | tail -1)"
      attempt="$(awk -F= '$1=="attempt"{print $2}' "$mfile" | tail -1)"
      started_at="$(awk -F= '$1=="started_at"{print $2}' "$mfile" | tail -1)"
      ended_at="$(awk -F= '$1=="ended_at"{print $2}' "$mfile" | tail -1)"
      log_file="$(awk -F= '$1=="log_file"{print $2}' "$mfile" | tail -1)"
      timeout_from_meta="$(awk -F= '$1=="timeout_seconds"{print $2}' "$mfile" | tail -1)"
      retry_from_meta="$(awk -F= '$1=="retry"{print $2}' "$mfile" | tail -1)"
      test_layer_from_meta="$(awk -F= '$1=="test_layer"{print $2}' "$mfile" | tail -1)"
      verification_from_meta="$(awk -F= '$1=="verification_level"{print $2}' "$mfile" | tail -1)"
      truth_from_meta="$(awk -F= '$1=="truth_source"{print $2}' "$mfile" | tail -1)"
      if [[ "$started_at" != "-" && "$ended_at" != "-" ]]; then
        start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$started_at" "+%s" 2>/dev/null || echo "")
        end_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$ended_at" "+%s" 2>/dev/null || echo "")
        if [[ -n "$start_epoch" && -n "$end_epoch" && "$end_epoch" -ge "$start_epoch" ]]; then
          duration_seconds="$((end_epoch - start_epoch))"
        fi
      fi
    fi
    echo -e "${case_id}\t${status}\t${rc}\t${attempt}\t${scenario_file}\t${test_file}\t${action}\t${test_layer_from_meta}\t${verification_from_meta}\t${truth_from_meta}\t${timeout_from_meta}\t${retry_from_meta}\t${precondition}\t${assertions}\t${started_at}\t${ended_at}\t${duration_seconds}\t${log_file}"
  done <"$PARSED_PLAN_TSV"
} >"$SUMMARY_TSV"

strict_pass=0
weak_pass=0
blocked=0
skipped=0
pending=0
failures=0
while IFS=$'\t' read -r case_id status _; do
  if [[ "$case_id" == "case_id" ]]; then
    continue
  fi
  case "$status" in
    PASS_STRICT) strict_pass=$((strict_pass + 1)) ;;
    PASS_WEAK) weak_pass=$((weak_pass + 1)) ;;
    BLOCKED) blocked=$((blocked + 1)) ;;
    SKIPPED) skipped=$((skipped + 1)) ;;
    PENDING) pending=$((pending + 1)) ;;
    FAIL) failures=$((failures + 1)) ;;
  esac
done <"$SUMMARY_TSV"

{
  echo "# YAML Mapped Suite Summary"
  echo ""
  echo "- RUN_ID: \`$RUN_ID\`"
  echo "- Generated At: \`$(date +'%Y-%m-%d %H:%M:%S')\`"
  echo "- Plan File: \`$PLAN_FILE\`"
  echo "- Parsed Plan: \`$PARSED_PLAN_TSV\`"
  echo "- Summary TSV: \`$SUMMARY_TSV\`"
  echo "- JSON Result: \`$RESULT_JSON\`"
  echo "- JUnit XML: \`$JUNIT_XML\`"
  echo "- PASS_STRICT: \`$strict_pass\`"
  echo "- PASS_WEAK: \`$weak_pass\`"
  echo "- BLOCKED: \`$blocked\`"
  echo "- SKIPPED: \`$skipped\`"
  echo "- PENDING: \`$pending\`"
  echo "- FAIL: \`$failures\`"
  echo ""
  echo "| Case | Layer | Verification | Truth | Status | RC | Attempt | Timeout | Retry | Started | Ended | Duration(s) | Log |"
  echo "|------|-------|--------------|-------|--------|----|---------|---------|-------|---------|-------|-------------|-----|"
  while IFS=$'\t' read -r case_id status rc attempt scenario_file test_file action test_layer verification_level truth_source timeout_seconds retry precondition assertions started_at ended_at duration_seconds log_file; do
    if [[ "$case_id" == "case_id" ]]; then
      continue
    fi
    echo "| $case_id | $test_layer | $verification_level | $truth_source | $status | $rc | $attempt | $timeout_seconds | $retry | $started_at | $ended_at | $duration_seconds | $log_file |"
  done <"$SUMMARY_TSV"
} >"$SUMMARY_MD"

awk -F'\t' '
function esc(s) {
  gsub(/\\/,"\\\\",s);
  gsub(/"/,"\\\"",s);
  gsub(/\r/,"\\r",s);
  gsub(/\n/,"\\n",s);
  return s;
}
BEGIN {
  print "{";
  print "  \"cases\": [";
  first=1;
}
NR==1 { next }
{
  if (!first) print ",";
  first=0;
  printf "    {\"case_id\":\"%s\",\"status\":\"%s\",\"rc\":\"%s\",\"attempt\":\"%s\",\"scenario_file\":\"%s\",\"test_file\":\"%s\",\"action\":\"%s\",\"test_layer\":\"%s\",\"verification_level\":\"%s\",\"truth_source\":\"%s\",\"timeout_seconds\":\"%s\",\"retry\":\"%s\",\"precondition\":\"%s\",\"assertions\":\"%s\",\"started_at\":\"%s\",\"ended_at\":\"%s\",\"duration_seconds\":\"%s\",\"log_file\":\"%s\"}", esc($1), esc($2), esc($3), esc($4), esc($5), esc($6), esc($7), esc($8), esc($9), esc($10), esc($11), esc($12), esc($13), esc($14), esc($15), esc($16), esc($17), esc($18);
}
END {
  print "";
  print "  ]";
  print "}";
}
' "$SUMMARY_TSV" >"$RESULT_JSON"

total_tests=0
failures=0
skipped=0
while IFS=$'\t' read -r case_id status rc _; do
  if [[ "$case_id" == "case_id" ]]; then
    continue
  fi
  total_tests=$((total_tests + 1))
  if [[ "$status" == "PASS_STRICT" || "$status" == "PASS_WEAK" ]]; then
    :
  elif [[ "$status" == "SKIPPED" || "$status" == "PENDING" || "$status" == "BLOCKED" ]]; then
    skipped=$((skipped + 1))
  else
    failures=$((failures + 1))
  fi
done <"$SUMMARY_TSV"

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<testsuite name=\"yaml_mapped_suite\" tests=\"$total_tests\" failures=\"$failures\" skipped=\"$skipped\" timestamp=\"$(date +'%Y-%m-%dT%H:%M:%S')\">"
  while IFS=$'\t' read -r case_id status rc attempt scenario_file test_file action test_layer verification_level truth_source timeout_seconds retry precondition assertions started_at ended_at duration_seconds log_file; do
    if [[ "$case_id" == "case_id" ]]; then
      continue
    fi
    classname="$(xml_escape "$action")"
    name="$(xml_escape "$case_id")"
    duration_attr="0"
    if [[ "$duration_seconds" =~ ^[0-9]+$ ]]; then
      duration_attr="$duration_seconds"
    fi
    echo "  <testcase classname=\"$classname\" name=\"$name\" time=\"$duration_attr\">"
    if [[ "$status" == "PASS_STRICT" ]]; then
      :
    elif [[ "$status" == "PASS_WEAK" ]]; then
      detail="$(xml_escape "test_layer=$test_layer verification_level=$verification_level truth_source=$truth_source")"
      echo "    <system-out>$detail</system-out>"
    elif [[ "$status" == "SKIPPED" || "$status" == "PENDING" || "$status" == "BLOCKED" ]]; then
      msg="$(xml_escape "status=$status")"
      echo "    <skipped message=\"$msg\"/>"
    else
      msg="$(xml_escape "status=$status rc=$rc attempt=$attempt")"
      detail="$(xml_escape "scenario=$scenario_file test=$test_file layer=$test_layer verification=$verification_level truth=$truth_source timeout=$timeout_seconds retry=$retry log=$log_file precondition=$precondition assertions=$assertions")"
      echo "    <failure message=\"$msg\">$detail</failure>"
    fi
    echo "  </testcase>"
  done <"$SUMMARY_TSV"
  echo '</testsuite>'
} >"$JUNIT_XML"

if [[ $DRY_RUN -eq 1 ]]; then
  log "YAML mapped suite dry-run completed."
  info "Summary: $SUMMARY_MD"
  exit 0
fi

if [[ "$any_failed" -eq 1 ]]; then
  error "YAML mapped suite finished with failures."
  info "Summary: $SUMMARY_MD"
  exit 1
fi

log "YAML mapped suite finished successfully."
info "Summary: $SUMMARY_MD"
exit 0

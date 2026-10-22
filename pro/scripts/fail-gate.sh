#!/usr/bin/env bash
# Inputs (env): USINGS_COUNT, TOOL_ERROR, BUILD_FAILED, LICENSED,
#               VULN_FAILED, SCAN_ERROR, SECRETS_COUNT,
#               NEW_USINGS, NEW_SECRETS (optional, baseline mode)
# Optional (from .relgate.yml): USINGS_SEVERITY (default blocking),
#   NULLABLE_SEVERITY (default advisory), SECRETS_SEVERITY (default
#   blocking), VULNS_SEVERITY (default blocking), NULLABLE_COUNT
#
# Only a check whose severity is "blocking" can fail the job; "advisory"
# findings are reported but never fail, and "off" checks didn't run.
# Build health is not configurable - a build that doesn't compile always
# blocks.
 
usings_severity="${USINGS_SEVERITY:-blocking}"
nullable_severity="${NULLABLE_SEVERITY:-advisory}"
secrets_severity="${SECRETS_SEVERITY:-blocking}"
vulns_severity="${VULNS_SEVERITY:-blocking}"
 
if [ "$BUILD_FAILED" = "true" ]; then
  echo "::error::RelGate: build failed to compile."
  exit 1
fi
if [ "$usings_severity" = "blocking" ] && [ "$TOOL_ERROR" = "true" ]; then
  echo "::error::RelGate: unused-usings check failed to run."
  exit 1
fi
# With baseline-file set, NEW_USINGS / NEW_SECRETS hold only the findings
# beyond the baseline and replace the raw counts; otherwise they're empty
# and the raw counts apply.
usings="${NEW_USINGS:-$USINGS_COUNT}"
secrets="${NEW_SECRETS:-$SECRETS_COUNT}"
 
if [ "$usings_severity" = "blocking" ] \
  && [ "$usings" != "0" ] && [ -n "$usings" ]; then
  echo "::error::RelGate found unused usings. See PR comment."
  exit 1
fi
if [ "$nullable_severity" = "blocking" ] \
  && [ "${NULLABLE_COUNT:-0}" != "0" ]; then
  echo "::error::RelGate found nullable warnings (blocking in .relgate.yml). See PR comment."
  exit 1
fi
 
if [ "$LICENSED" != "true" ]; then
  exit 0
fi
 
if [ "$vulns_severity" = "blocking" ] && [ "$SCAN_ERROR" = "true" ]; then
  echo "::error::RelGate Pro: vulnerability scan failed to run."
  exit 1
fi
if [ "$vulns_severity" = "blocking" ] && [ "$VULN_FAILED" = "true" ]; then
  echo "::error::RelGate Pro: vulnerability readiness below threshold."
  exit 1
fi
if [ "$secrets_severity" = "blocking" ] \
  && [ -n "$secrets" ] && [ "$secrets" != "0" ]; then
  echo "::error::RelGate Pro: potential secrets found. See report."
  exit 1
fi
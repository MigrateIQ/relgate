#!/usr/bin/env bash
# Inputs (env): USINGS_COUNT, TOOL_ERROR, BUILD_FAILED
# Optional (from .relgate.yml): USINGS_SEVERITY (default blocking),
#   NULLABLE_SEVERITY (default advisory), NULLABLE_COUNT
#
# Only a check whose severity is "blocking" can fail the job; "advisory"
# findings are reported but never fail, and "off" checks didn't run.
# Build health is not configurable - a build that doesn't compile always
# blocks.
 
usings_severity="${USINGS_SEVERITY:-blocking}"
nullable_severity="${NULLABLE_SEVERITY:-advisory}"
 
if [ "$BUILD_FAILED" = "true" ]; then
  echo "::error::RelGate: build failed to compile."
  exit 1
fi
if [ "$usings_severity" = "blocking" ] && [ "$TOOL_ERROR" = "true" ]; then
  echo "::error::RelGate: unused-usings check failed to run."
  exit 1
fi
if [ "$usings_severity" = "blocking" ] \
  && [ "$USINGS_COUNT" != "0" ] && [ -n "$USINGS_COUNT" ]; then
  echo "::error::RelGate found unused usings. See PR comment."
  exit 1
fi
if [ "$nullable_severity" = "blocking" ] \
  && [ "${NULLABLE_COUNT:-0}" != "0" ]; then
  echo "::error::RelGate found nullable warnings (blocking in .relgate.yml). See PR comment."
  exit 1
fi
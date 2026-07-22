#!/usr/bin/env bash
# Inputs (env): USINGS_COUNT, TOOL_ERROR, BUILD_FAILED, LICENSED,
#               VULN_FAILED, SCAN_ERROR, SECRETS_COUNT

if [ "$BUILD_FAILED" = "true" ]; then
  echo "::error::RelGate: build failed to compile."
  exit 1
fi
if [ "$TOOL_ERROR" = "true" ]; then
  echo "::error::RelGate: unused-usings check failed to run."
  exit 1
fi
if [ "$USINGS_COUNT" != "0" ] && [ -n "$USINGS_COUNT" ]; then
  echo "::error::RelGate found unused usings. See PR comment."
  exit 1
fi

if [ "$LICENSED" != "true" ]; then
  exit 0
fi

if [ "$SCAN_ERROR" = "true" ]; then
  echo "::error::RelGate Pro: vulnerability scan failed to run."
  exit 1
fi
if [ "$VULN_FAILED" = "true" ]; then
  echo "::error::RelGate Pro: vulnerability readiness below threshold."
  exit 1
fi
if [ -n "$SECRETS_COUNT" ] && [ "$SECRETS_COUNT" != "0" ]; then
  echo "::error::RelGate Pro: potential secrets found. See report."
  exit 1
fi

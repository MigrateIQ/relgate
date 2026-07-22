#!/usr/bin/env bash
# Inputs (env): USINGS_COUNT, TOOL_ERROR, BUILD_FAILED

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

#!/usr/bin/env bash
# Inputs (env): USINGS, BUILD_FAILED

if [ "$USINGS" != "0" ]; then
  echo "::error::expected 0 unused usings, got $USINGS"
  exit 1
fi
if [ "$BUILD_FAILED" != "false" ]; then
  echo "::error::expected the clean fixture to build"
  exit 1
fi

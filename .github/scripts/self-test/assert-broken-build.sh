#!/usr/bin/env bash
# Inputs (env): BUILD_FAILED

if [ "$BUILD_FAILED" != "true" ]; then
  echo "::error::expected build-failed=true, got $BUILD_FAILED"
  exit 1
fi

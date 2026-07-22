#!/usr/bin/env bash
# Inputs (env): USINGS, NULLABLE

if [ "$USINGS" = "0" ]; then
  echo "::error::expected unused-using violations, got 0"
  exit 1
fi
if [ "$NULLABLE" = "0" ]; then
  echo "::error::expected nullable warnings, got 0"
  exit 1
fi

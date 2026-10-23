#!/usr/bin/env bash
# Inputs (env): USINGS, NULLABLE
# The dirty fixture's only source file is excluded by the config, so
# neither its unused using nor its nullable warning may be counted.
 
if [ "$USINGS" != "0" ]; then
  echo "::error::expected excluded file to yield 0 unused usings, got '$USINGS'"
  exit 1
fi
if [ "$NULLABLE" != "0" ]; then
  echo "::error::expected excluded file to yield 0 nullable warnings, got '$NULLABLE'"
  exit 1
fi
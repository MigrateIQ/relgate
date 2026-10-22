#!/usr/bin/env bash
# Inputs (env): USINGS
# The dirty fixture has unused usings; with the check set to advisory they
# must still be reported (the job already passed fail-on-issues=true).
 
if [ -z "$USINGS" ] || [ "$USINGS" = "0" ]; then
  echo "::error::expected advisory usings to still be reported, got '$USINGS'"
  exit 1
fi
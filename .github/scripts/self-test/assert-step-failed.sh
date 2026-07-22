#!/usr/bin/env bash
# Inputs (env): OUTCOME, MESSAGE

if [ "$OUTCOME" != "failure" ]; then
  echo "::error::$MESSAGE"
  exit 1
fi

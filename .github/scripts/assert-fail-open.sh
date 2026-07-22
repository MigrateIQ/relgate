#!/usr/bin/env bash
# Inputs (env): LICENSED, OUTCOME

if [ "$LICENSED" != "false" ]; then
  echo "::error::expected licensed=false, got $LICENSED"
  exit 1
fi
if [ "$OUTCOME" != "success" ]; then
  echo "::error::expected the job to succeed despite the outage"
  exit 1
fi

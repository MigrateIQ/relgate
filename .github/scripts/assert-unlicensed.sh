#!/usr/bin/env bash
# Inputs (env): LICENSED
# Shared by pro-invalid-key and pro-wrong-product — both expect the same
# outcome (licensed=false) from different rejection reasons.

if [ "$LICENSED" != "false" ]; then
  echo "::error::expected licensed=false, got $LICENSED"
  exit 1
fi

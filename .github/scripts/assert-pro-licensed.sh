#!/usr/bin/env bash
# Inputs (env): LICENSED, SCORE, FAILED, SECRETS

if [ "$LICENSED" != "true" ]; then
  echo "::error::expected licensed=true, got $LICENSED"
  exit 1
fi
if [ "$SCORE" != "40" ]; then
  echo "::error::expected vuln-score=40 (Critical+High), got $SCORE"
  exit 1
fi
if [ "$FAILED" != "true" ]; then
  echo "::error::expected vuln-readiness-failed=true, got $FAILED"
  exit 1
fi
if [ "$SECRETS" != "3" ]; then
  echo "::error::expected 3 secret findings, got $SECRETS"
  exit 1
fi

#!/usr/bin/env bash
# Starts the mock Lemon Squeezy server used by the pro-* self-test jobs.

python3 test-fixtures/mock-lemon-squeezy/server.py 8085 &
sleep 1

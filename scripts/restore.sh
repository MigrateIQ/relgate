#!/usr/bin/env bash
# Inputs (env): PROJECT_PATH

if [ -n "$PROJECT_PATH" ]; then
  dotnet restore "$PROJECT_PATH"
else
  dotnet restore
fi

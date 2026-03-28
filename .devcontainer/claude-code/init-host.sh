#!/bin/bash
# Pre-container initialization: runs on the HOST before the container is created.
# Ensures required directories exist for bind mounts.
set -e

mkdir -p "$HOME/.claude"

#!/bin/bash
# Quick script to run download_models.py with the correct uv environment

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/.venv/bin/activate"

cd "$SCRIPT_DIR/../model-manager"
python download_models.py "$@"

#!/usr/bin/env bash
set -e

pip install -r requirements.txt
python -m playwright install chromium
python -m playwright install chromium-headless-shell || true

#!/usr/bin/env bash
set -euo pipefail

VENV_PATH=".venv"
REQUIREMENTS_PATH="requirements.txt"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. Install it via your package manager." >&2
  exit 1
fi

# Ensure venv tooling exists (Ubuntu/Debian commonly need this)
if ! python3 -c "import venv" >/dev/null 2>&1; then
  echo "python3 venv module missing. Run: sudo apt install -y python3-venv python3-full" >&2
  exit 1
fi

if [[ ! -d "${VENV_PATH}" ]]; then
  rm -rf "${VENV_PATH}"
  python3 -m venv "${VENV_PATH}"
fi

# shellcheck disable=SC1091
source "${VENV_PATH}/bin/activate"

python -m pip install --upgrade pip setuptools wheel

if [[ -f "${REQUIREMENTS_PATH}" ]]; then
  python -m pip install -r "${REQUIREMENTS_PATH}"
fi

echo "Done. Virtual environment ready at ${VENV_PATH}"

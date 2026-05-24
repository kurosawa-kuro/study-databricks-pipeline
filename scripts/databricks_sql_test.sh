#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="${ROOT_DIR}/.venv/bin/python"

export PYTHONPATH="${ROOT_DIR}:${PYTHONPATH:-}"

if [[ ! -x "${VENV_PYTHON}" ]]; then
  echo "Missing ${VENV_PYTHON}. Run 'make install' first." >&2
  exit 2
fi

"${VENV_PYTHON}" -m src.sql_connectivity "$@"

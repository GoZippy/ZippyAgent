#!/bin/sh
set -e
PORT=${SUPERVISOR_PORT:-8000}
exec uvicorn supervisor.app:app --host 0.0.0.0 --port $PORT 
#!/bin/bash

SUPERVISOR_URL="http://supervisor:5000/register"
AGENT_NAME=$(hostname)
curl -X POST $SUPERVISOR_URL -d "{\"name\": \"$AGENT_NAME\"}"

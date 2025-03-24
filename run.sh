#!/bin/bash

MAELSTROM="./maelstrom/maelstrom"

# Install maelstrom if it doesn't exist. install-maelstrom is defined in .devenv file.
ls "${MAELSTROM}" > /dev/null 2>&1
exit_code=$?
if [ "${exit_code}" -ne 0 ]; then
  install-maelstrom
fi

set -e  # Bail on failures after this point

BINARY="./${1}"

MODULE="${1}" mix escript.build

if [ "$1" = "echo" ]; then
  $MAELSTROM test -w echo --bin "${BINARY}" --time-limit 5 --log-stderr --node-count 1 --rate 100 --latency 120
elif [ "$1" = "broadcast" ]; then
  $MAELSTROM test -w broadcast --bin "${BINARY}" --time-limit 5 --log-stderr --rate 10 --node-count 2
else
  echo "unknown command: '$1'"
fi
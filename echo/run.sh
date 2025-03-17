#!/bin/bash

MAELSTROM="./maelstrom/maelstrom"
BINARY="./mix_run.sh"

if [ "$1" = "lin-kv" ]; then
  $MAELSTROM test -w lin-kv --bin "${BINARY}" --time-limit 15 --log-stderr --node-count 3 --concurrency 2n --rate 100 --latency 120
elif [ "$1" = "echo" ]; then
  $MAELSTROM test -w echo --bin "${BINARY}" --time-limit 5 --log-stderr --node-count 1 --rate 100 --latency 120
else
  echo "unknown command: '$1'"
fi

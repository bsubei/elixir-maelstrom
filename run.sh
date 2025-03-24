#!/bin/bash
set -e

MAELSTROM="./maelstrom/maelstrom"
BINARY="./echo"
mix escript.build

if [ "$1" = "echo" ]; then
  $MAELSTROM test -w echo --bin "${BINARY}" --time-limit 5 --log-stderr --node-count 1 --rate 100 --latency 120
elif [ "$1" = "broadcast" ]; then
  $MAELSTROM test -w broadcast --bin "${BINARY}" --time-limit 5 --log-stderr
else
  echo "unknown command: '$1'"
fi
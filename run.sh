#!/bin/bash

MAELSTROM="./maelstrom/maelstrom"
BINARY="./target/debug/maelstrom-tutorial"

if [ "$1" = "lin-kv" ]; then
  $MAELSTROM test -w lin-kv --bin <(echo "mix run") --time-limit 15 --log-stderr --node-count 3 --concurrency 2n --rate 100 --latency 120
else
  echo "unknown command"
fi

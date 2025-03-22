#!/bin/bash
# When maelstrom runs this script, it does it under "/tmp", so we have to change directories because "mix run" needs to run inside the project context.
project_dir=$(dirname $0)
cd "${project_dir}"
# Explicitly compile before running and redirect any output to stderr so maelstrom doesn't explode.
mix compile 1>&2
# Can only write to stderr because stdin is reserved for actual maelstrom messages.
echo "Starting up mix run under the dir ${project_dir}!" 1>&2
mix run --no-halt "$@"
echo "Finished mix run!" 1>&2
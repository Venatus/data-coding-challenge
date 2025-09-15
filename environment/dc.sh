#!/bin/sh

chver=25.3.3.42

script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cd ${script_dir}
CHVER=$chver CHKVER=$chver-alpine docker compose "${@}"

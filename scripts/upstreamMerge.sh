#!/usr/bin/env bash

set -euo pipefail

function git {
  command git -c commit.gpgsign=false "${@}"
}

readonly basedir="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly workdir="${basedir}/work"

function update {
  local -r submodule="${1?Submodule is missing}"
  local -r submodule_dir="${workdir}/${submodule}"
  cd "${submodule_dir}"
  git fetch && git clean -fd && git reset --hard origin/master || return 1
  cd "${basedir}"
  git add --force "${submodule_dir}"
}

function main {
  local -r update_all="${1:-}"
  local -r skip_rebuild="${2:-}"
  cd "${basedir}"
  git submodule update --init
  update Bukkit
  update CraftBukkit
  update Spigot
  if [[ "${update_all}" == @(all|a|yes|y) ]]; then
    update BuildData
  fi
  if ! git diff --cached --quiet --exit-code -- "${workdir}" && [[ "${skip_rebuild,,}" != @(yes|y) ]]; then
    echo "Rebuilding patches without filtering to improve apply ability"
    cd "${basedir}"
    ./gradlew cleanCache || exit 1 # todo: Figure out why this is necessary
    ./gradlew applyPatches -Dpaperweight.debug=true || exit 1
    ./gradlew rebuildPatches || exit 1
  fi
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

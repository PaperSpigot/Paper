#!/usr/bin/env bash

set -euo pipefail

function changelog() {
  local -r submodule_dir="${1?Missing submodule dir}"
  local base
  base="$(git ls-tree HEAD "${submodule_dir}"  | awk '{ print $3 }')"
  git -C "${submodule_dir}" log --oneline "${base}"...HEAD
}

function main() {
  local disclaimer="${*:-}"

  if [ -z "${disclaimer:-}" ]; then
    disclaimer="Upstream has released updates that appear to apply and compile correctly.\nThis update has not been tested by PaperMC and as with ANY update, please do your own testing"
  fi

  local submodule updated logsuffix changes
  for submodule in Bukkit CraftBukkit Spigot; do
    changes="$(changelog work/"${submodule}")"
    if [ -n "${changes:-}" ]; then
      if [ -z "${updated:-}" ]; then
        updated="${submodule}"
      else
        updated="${updated}/${submodule}"
      fi
      logsuffix="${logsuffix:-}\n\n${submodule} Changes:\n${changes}"
    fi
  done

  if [ -n "${updated:-}" ]; then
    log="${UP_LOG_PREFIX:-}Updated Upstream ($updated)\n\n${disclaimer}${logsuffix}"
    echo -e "${log}" | git commit -F -
  fi
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

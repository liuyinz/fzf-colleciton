#!/usr/bin/env bash

# PIP
# -----------------------
# [P]ip [I]nstall
ppi() {
  local inst
  inst=$(curl -s "$(pip3 config get global.index-url)/" |
    grep '</a>' | sed 's/^.*">//g' | sed 's/<.*$//g' |
    eval "fzf ${FZF_DEFAULT_OPTS} --exact --header='[pip:install]'")

  if [[ $inst ]]; then
    for prog in $(echo "$inst"); do
      pip3 install --user "$prog"
    done
  fi
}

# [P]ip [U]pgrade
ppu() {
  local inst
  inst=$(pip3 list --outdated | tail -n +3 | awk '{print $1}' |
    eval "fzf ${FZF_DEFAULT_OPTS} --header='[pip:upgrade]'")

  if [[ $inst ]]; then
    for prog in $(echo "$inst"); do
      pip3 install --user --upgrade "$prog"
    done
  fi
}

# [P]ip [C]lean
ppc() {
  local inst
  inst=$(pip3 list | tail -n +3 | awk '{print $1}' |
    eval "fzf ${FZF_DEFAULT_OPTS} --header='[pip:uninstall]'")

  if [[ $inst ]]; then
    for prog in $(echo "$inst"); do
      pip3 uninstall --yes "$prog"
    done
  fi
}
#!/usr/bin/env bash

_brewf_list_format() {
  local input fle

  input="$([[ -p /dev/stdin ]] && cat - || return)"

  if [ -n "$input" ]; then

    fle=$(brew formulae)

    # SEE https://stackoverflow.com/a/3322211/13194984
    echo "$input" \
      | perl -sane '
$sign = ($fle =~ /^\Q$F[0]\E$/im ? "\x1b[33mformula" : "\x1b[31mcask" );
printf "%s \x1b[34m%s %s%s\x1b[0m\n", $F[0], join" ",@F[1 .. $#F], $sign;
' -- -fle="$fle" \
      | column -t -s ' '
  fi
}

# SEE https://gist.github.com/steakknife/8294792

_brewf_switch() {

  subcmd=$(echo "${@:2}" | perl -pe 's/ /\n/g' | _fzf_single_header)

  if [ -n "$subcmd" ]; then
    for f in $(echo "$1"); do
      case $subcmd in
        rollback)
          _brewf_rollback "$f"
          ;;
        edit)
          $EDITOR "$(brew formula "$f")"
          ;;
        upgrade | uninstall | untap)
          if brew "$subcmd" "$f"; then
            # SEE https://stackoverflow.com/a/24493085/13194984
            perl -i -slne '/$f/||print' -- -f="$f" "$tmpfile"
          fi
          ;;
        uses)
          brew uses --installed "$f"
          ;;
        *) brew "$subcmd" "$f" ;;
      esac
      echo ""
    done

    case $subcmd in
      upgrade | uninstall | untap | rollback) return 0 ;;
    esac

  else
    return 0
  fi

  _brewf_switch "$@"

}

_brewf_rollback() {
  local f dir sha header

  header="Brew Rollback"
  f="$1.rb"
  dir=$(dirname "$(find "$(brew --repository)" -name "$f")")

  if [ -n "$dir" ]; then
    sha=$(
      git -C "$dir" log --color=always -- "$f" \
        | _fzf_single_header --tiebreak=index --query="$1 update" \
        | perl -lane 'print $F[0]'
    )

    if [ -n "$sha" ]; then
      brew unpin "$1" &>/dev/null

      git -C "$dir" checkout "$sha" "$f"
      (HOMEBREW_NO_AUTO_UPDATE=1 && brew reinstall "$1")
      git -C "$dir" checkout HEAD "$f"

      if ! brew outdated "$1" &>/dev/null; then
        brew pin "$1" &>/dev/null
      fi

    else
      echo "No commit selected." && return 0
    fi

  else
    echo "No formulae or cask exists." && return 0
  fi

}

brewf-search() {
  local tmpfile inst opt header

  header="Brew Search"
  tmpfile=$(_fzf_temp_file)

  opt=("install" "rollback" "options" "homepage" "info" "deps" "uses" "edit" "cat"
    "uninstall" "link" "unlink" "pin" "unpin")

  if [ ! -e $tmpfile ]; then
    touch $tmpfile

    inst=$(
      {
        brew formulae
        brew casks
      } \
        | tee $tmpfile \
        | _fzf_multi_header \
        | perl -lane 'print $F[0]'
    )

  else
    inst=$(cat <$tmpfile | _fzf_multi_header | perl -lane 'print $F[0]')
  fi

  if [ -n "$inst" ]; then
    _brewf_switch "$inst" "${opt[@]}"
  else
    rm -f $tmpfile && return 0
  fi

  brewf-search

}

brewf-manage() {
  local tmpfile inst opt header

  header="Brew Manage"
  tmpfile=$(_fzf_temp_file)

  opt=("uninstall" "rollback" "homepage" "link" "unlink" "pin" "unpin"
    "options" "info" "deps" "uses" "edit" "cat")

  if [ ! -e $tmpfile ]; then
    touch $tmpfile

    inst=$(
      {
        brew list --formulae --versions
        brew list --cask --versions
      } \
        | perl -ane 'printf "%s %s\n", $F[0], join"|",@F[1 .. $#F]' \
        | _brewf_list_format \
        | tee $tmpfile \
        | _fzf_multi_header \
        | perl -lane 'print $F[0]'
    )

  else
    inst=$(cat <$tmpfile | _fzf_multi_header | perl -lane 'print $F[0]')
  fi

  if [ -n "$inst" ]; then
    _brewf_switch "$inst" "${opt[@]}"
  else
    rm -f $tmpfile && return 0
  fi

  brewf-manage

}

brewf-outdated() {
  local tmpfile outdate_list inst opt header

  header="Brew Outdated"
  tmpfile=$(_fzf_temp_file)
  opt=("upgrade" "uninstall" "rollback" "options" "homepage" "info" "deps" "edit" "cat")

  if [ ! -e $tmpfile ]; then
    brew update

    outdate_list=$(
      {
        brew outdated --formula --verbose
        brew outdated --cask --greedy --verbose
      } \
        | grep -Fv "pinned at" \
        | perl -pe 's/, /|/g; tr/()//d' \
        | _brewf_list_format
    )

    if [ -n "$outdate_list" ]; then
      touch $tmpfile
      inst=$(
        echo "$outdate_list" \
          | tee $tmpfile \
          | _fzf_multi_header \
          | perl -lane 'print $F[0]'
      )
    else
      echo "No updates within installed formulae or cask."
      return 0
    fi

  else

    if [ -s $tmpfile ]; then
      inst=$(cat <$tmpfile | _fzf_multi_header | perl -lane 'print $F[0]')
    else
      echo "Upgrade finished."
      rm -f $tmpfile && return 0
    fi

  fi

  if [ -n "$inst" ]; then
    _brewf_switch "$inst" "${opt[@]}"
  else
    echo "Upgrade cancel."
    rm -f $tmpfile && return 0
  fi

  brewf-outdated
}

brewf-tap() {
  local tmpfile inst opt header

  header="Brew Tap"
  tmpfile=$(_fzf_temp_file)
  opt=("untap" "tap-info")

  if [ ! -e $tmpfile ]; then
    tap_list=$(brew tap)

    if [ -n "$tap_list" ]; then
      touch $tmpfile
      inst=$(echo "$tap_list" | tee $tmpfile | _fzf_multi_header)
    else
      echo "No taps used."
      return 0
    fi

  else

    if [ -s $tmpfile ]; then
      inst=$(cat <$tmpfile | _fzf_multi_header)
    else
      echo "Tap finished."
      rm -f $tmpfile && return 0
    fi
  fi

  if [ -n "$inst" ]; then
    _brewf_switch "$inst" "${opt[@]}"
  else
    echo "Tap cancel."
    rm -f $tmpfile && return 0
  fi

  brewf-tap

}

brewf-pinned() {
  local tmpfile inst opt header

  header="Brew Pinned"
  tmpfile=$(_fzf_temp_file)

  if [ ! -e $tmpfile ]; then
    pinned_list=$(brew ls --pinned)

    if [ -n "$pinned_list" ]; then
      touch $tmpfile
      inst=$(echo "$pinned_list" | tee $tmpfile | _fzf_multi_header)
    else
      echo "No formulae is pinned."
      return 0
    fi

  else

    if [ -s $tmpfile ]; then
      inst=$(cat <$tmpfile | _fzf_multi_header)
    else
      echo "No formulae is pinned."
      rm -f $tmpfile && return 0
    fi
  fi

  if [ -n "$inst" ]; then
    for f in $(echo "$inst"); do
      if brew unpin "$f"; then
        perl -i -slne '/$f/||print' -- -f="$f" "$tmpfile"
      fi
    done
  else
    echo "Unpin cancel."
    rm -f $tmpfile && return 0
  fi

  brewf-pinned

}

brewf() {
  local opt select header

  header="Brew Fzf"
  opt=("outdated" "search" "manage" "pinned" "tap")
  select=$(
    echo "${opt[@]}" \
      | perl -pe 's/ /\n/g' \
      | _fzf_single_header
  )

  if [ -n "$select" ]; then
    case $select in
      outdated) brewf-outdated ;;
      search) brewf-search ;;
      manage) brewf-manage ;;
      pinned) brewf-pinned ;;
      tap) brewf-tap ;;
    esac
  fi

}

#!/usr/bin/env bash

_pipf_list() {
  pip list --version "$@" | tail -n +3
}

_pipf_list_format() {
  local input pkg

  input="$([[ -p /dev/stdin ]] && cat - || return)"

  if [[ -n "$input" ]]; then

    pkg=$(pip list --not-required | tail -n +3 | perl -lane 'print $F[0]')

    echo "$input" \
      | perl -sane '
$sign = ($pkg !~ /^\Q$F[0]\E$/im ? "\x1b[31mdep" : "\x1b[33mpkg" );
printf "%s \x1b[34m%s %s\x1b[0m\n", $F[0], join" ",@F[1 .. $#F], $sign;
' -- -pkg="$pkg" \
      | column -s ' ' -t
  fi
}

_pipf_switch() {

  subcmd=$(echo "${@:2}" | perl -pe 's/ /\n/g' | _fzf_single_header)

  if [ -n "$subcmd" ]; then
    for f in $(echo "$1"); do
      case $subcmd in
        upgrade)
          if pip install --user --upgrade "$f"; then
            perl -i -slne '/$f/||print' -- -f="$f" "$tmpfile"
          fi
          ;;
        uninstall)
          if pip uninstall --yes "$f"; then
            perl -i -slne '/$f/||print' -- -f="$f" "$tmpfile"
          fi
          ;;
        install)
          pip install --user "$f"
          ;;
        rollback)
          _pipf_rollback "$f"
          ;;
        info)
          pip show "$f"
          ;;
        *) pip "$subcmd" "$f" ;;
      esac
      echo ""
    done

    case $subcmd in
      upgrade | uninstall | rollback) return 0 ;;
    esac

  else
    return 0
  fi

  _pipf_switch "$@"

}

_pipf_rollback() {
  local version_list version header

  header="Pip Rollback"
  version_list=$(
    pip index versions --pre "$1" 2>/dev/null \
      | perl -lne '/Available versions: (.*)$/m && print $1' \
      | perl -pe 's/, /\n/g'
  )

  if [ -n "$version_list" ]; then

    version=$(echo "$version_list" | _fzf_single_header)

    if [ -n "$version" ]; then
      pip install --upgrade --force-reinstall "$f==$version" 2>/dev/null
    else
      echo "Rollback cancel." && return 0
    fi

  else
    echo "No version provided for package $1." && return 0
  fi
}

pipf-search() {
  local tmpfile inst opt header

  header="Pip Search"
  tmpfile=$(_fzf_temp_file)

  opt=("install" "uninstall" "rollback")

  if [ ! -e $tmpfile ]; then
    touch $tmpfile

    inst=$(
      curl -s "$(pip config get global.index-url)/" \
        | perl -lne '/">(.*?)<\/a>/ && print $1' \
        | tee $tmpfile \
        | _fzf_multi_header --tiebreak=begin,index \
        | perl -lane 'print $F[0]'
    )

  else
    inst=$(cat <$tmpfile | _fzf_multi_header | perl -lane 'print $F[0]')
  fi

  if [ -n "$inst" ]; then
    _pipf_switch "$inst" "${opt[@]}"
  else
    rm -f $tmpfile && return 0
  fi

  pipf-search

}

pipf-manage() {
  local tmpfile inst header opt

  header="Pip Manage"
  tmpfile=$(_fzf_temp_file)
  opt=("uninstall" "rollback" "info")

  if [ ! -e $tmpfile ]; then
    touch $tmpfile

    inst=$(
      _pipf_list \
        | perl -lane 'print join" ",@F[0..$#F]' \
        | _pipf_list_format \
        | tee $tmpfile \
        | _fzf_multi_header --tiebreak=begin,index \
        | perl -lane 'print $F[0]'
    )

  else
    inst=$(cat <$tmpfile | _fzf_multi_header | perl -lane 'print $F[0]')
  fi

  if [ -n "$inst" ]; then
    _pipf_switch "$inst" "${opt[@]}"
  else
    rm -f $tmpfile && return 0
  fi

  pipf-manage

}

pipf-outdated() {
  local inst header opt

  header="Pip Outdated"
  tmpfile=$(_fzf_temp_file)
  opt=("upgrade" "uninstall" "info" "rollback")

  if [ ! -e $tmpfile ]; then

    outdate_list=$(
      _pipf_list --outdated \
        | perl -lane 'printf "%s %s -> %s\n", $F[0], $F[1], $F[2]' \
        | _pipf_list_format
    )

    if [ -n "$outdate_list" ]; then
      touch $tmpfile
      inst=$(
        echo "$outdate_list" \
          | tee $tmpfile \
          | _fzf_multi_header --tiebreak=begin,index \
          | perl -lane 'print $F[0]'
      )
    else
      echo "No updates in pip packages."
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
    _pipf_switch "$inst" "${opt[@]}"
  else
    echo "Upgrade cancel."
    rm -f $tmpfile && return 0
  fi

  pipf-outdated
}

pipf() {
  local cmd select header

  header="Pip Fzf"
  cmd=("outdated" "search" "manage")
  select=$(
    echo "${cmd[@]}" \
      | perl -pe 's/ /\n/g' \
      | _fzf_single_header
  )

  if [ -n "$select" ]; then
    case $select in
      outdated) pipf-outdated ;;
      search) pipf-search ;;
      manage) pipf-manage ;;
    esac
  fi

}

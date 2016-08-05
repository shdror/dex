#
# lib.d/function.sh for dex -*- shell-script -*-
#

error(){
  printf "\e[31m%s\n\e[0m" "$@" >&2
  exit ${ERRCODE:-1}
}

log(){
  printf "\e[33m%s\n\e[0m" "$@" >&2
}

prompt_confirm() {
  while true; do
    echo
    read -r -n 1 -p "  ${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input"
    esac
  done
}

runfunc(){
  [ "$(type -t $1)" = "function" ] || error \
    "$1 is not a valid runfunc target"

  $@
}

unrecognized_arg(){

  if [ $CMD = "main" ]; then
    printf "\n\n$1 is an unrecognized command\n\n"
  else
    printf "\n\n$1 is an unrecognized argument to the $CMD command.\n\n"
  fi

  display_help 127

}


vars_load(){
  while [ $# -ne 0 ]; do
    case $1 in
      DEX_HOME) DEX_HOME=${DEX_HOME:-~/.dex} ;;
      DEX_BINDIR) DEX_BINDIR=${DEX_BINDIR:-/usr/local/bin} ;;
      DEX_PREFIX) DEX_PREFIX=${DEX_PREFIX:-'d'} ;;
      DEX_NETWORK) DEX_NETWORK=${DEX_NETWORK:-true} ;;
      *) ERRCODE=127; error "$1 has no default configuration value" ;;
    esac
    shift
  done
}

vars_reset(){
  while [ $# -ne 0 ]; do
    unset $1
    shift
  done
}

vars_print(){
  while [ $# -ne 0 ]; do
    eval "printf \"$1=\$$1\n\""
    shift
  done
}

vars_print_export(){
  # TODO -- shell detection for fish|export
  while [ $# -ne 0 ]; do
    eval "printf \"export $1=\$$1\n\""
    shift
  done

  printf "# Run this command to configure your shell: \n"
  printf "# eval \$($ORIG_CMD)\n\n"
}


#
# dex
#


dex-ping(){
  echo "${1:-pong}"
  exit 0
}

# usage: dex-fetch <url> <target-path> [errmessage]
dex-fetch(){

  # fail if errmessage provided and DEX_NETWORK is disabled
  if ! $DEX_NETWORK; then
    [ ! -z "$3" ] && error "$3"
    return 0
  fi

  if ( type wget >/dev/null 2>&1 ); then
    wget $1 -O $2
  elif ( type curl >/dev/null 2>&1 ); then
    curl -Lfo $2 $1
  else
    true
  fi

  # if curl or wget exited with non zero, and errmessage provided, error out.
  [ ! $? -eq 0 ] && [ ! -z "$3" ] && error "$3"

  return 0
}

dex-fetch-sources(){

  dex-fetch "https://raw.githubusercontent.com/dockerland/dex/briceburg/wonky/sources.list" $DEX_HOME/sources.list.fetched

  if [ ! -e $DEX_HOME/sources.list ]; then
    if [ -e $DEX_HOME/sources.list.fetched ]; then
      cat $DEX_HOME/sources.list.fetched > $DEX_HOME/sources.list || error \
        "error writing sources.list from fetched file"
    else
      dex-cat-sources > $DEX_HOME/sources.list || error \
        "error creating $DEX_HOME/sources.list"
    fi
  fi

}

dex-setup(){
  ERRCODE=126

  [ -d $DEX_HOME ] || mkdir -p $DEX_HOME || error \
    "could not create working directory \$DEX_HOME"

  [ -d $DEX_HOME/checkouts ] || mkdir -p $DEX_HOME/checkouts || error \
    "could not create checkout directory under \$DEX_HOME"

  [ -e $DEX_HOME/sources.list ] || dex-fetch-sources

  for path in $DEX_HOME $DEX_HOME/checkouts $DEX_HOME/sources.list; do
    [ -w $path ] || error "$path is not writable"
  done

  ERRCODE=1
  return 0
}

dex-cat-sources(){
  cat <<-EOF
#
# dex sources.list
#

core git@github.com:dockerland/dex-dockerfiles-core.git
extra git@github.com:dockerland/dex-dockerfiles-extra.git

EOF
}

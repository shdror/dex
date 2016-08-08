#
# lib.d/main_image.sh for dex -*- shell-script -*-
#

#@TODO implement package building (in repositories as well -- symlink strategy)
#@TODO implement --pull to update sources
#@TODO fix argparsing, build only accepts a single argument

main_image(){

  local runstr="display_help"
  FORCE_FLAG=false
  QUIET_FLAG=

  if [ $# -eq 0 ]; then
    display_help 2
  else
    while [ $# -ne 0 ]; do

      case $1 in
        build|rm|ls)      runstr="dex-image-$1"
                          arg_var "$2" LOOKUP && shift
                          ;;
        -f|--force)       FORCE_FLAG=true ;;
        -h|--help)        display_help ;;
        -q|--quiet)       QUIET_FLAG="-q" ;;
        --api-version)    arg_var "$2" DEX_API && shift ;;
        *)                unrecognized_arg "$1" ;;
      esac
      shift
    done
  fi

  dex-setup
  $runstr
  exit $?

}


dex-image-build(){
  # when installing, we prefix with "dex/$DEX_API-install"
  local tag_prefix=${1:-$DEX_TAG_PREFIX}
  local built_image=false

  if [ -z "$LOOKUP" ]; then
    ERRCODE=2
    error "image-add requires an image name, package name, or wildcard match to install"
  fi

  dex-lookup-parse $LOOKUP || error "lookup failed to parse $1" 
  for dockerfile in $(dex-lookup-dockerfiles); do
    local image=$(basename $(dirname $dockerfile))
    local tag="$tag_prefix/$image:$DEX_REMOTE_IMAGETAG"
    log "building $tag ..."
    (
      set -e
      cd $(dirname $dockerfile)
      docker build -t $tag \
        --label=dex-api=$DEX_API \
        --label=dex-tag-prefix=$tag_prefix \
        --label=dex-image=$image \
        --label=dex-tag=$DEX_REMOTE_IMAGETAG \
        --label=dex-remote=$DEX_REMOTE \
        -f $(basename $dockerfile) .
    ) && built_image=true
  done

  $built_image && {
    log "built $DEX_REMOTE/$DEX_REMOTE_IMAGESTR"
    exit 0
  }

  error "failed to find images matching $DEX_REMOTE/$DEX_REMOTE_IMAGESTR"
}


dex-image-ls(){
  local tag_prefix=${1:-$DEX_TAG_PREFIX}
  local filters="--filter=label=dex-tag-prefix=$tag_prefix"

  if [ ! -z "$LOOKUP" ]; then
    dex-lookup-parse $LOOKUP

    [ ! "$DEX_REMOTE" = "*" ] && \
      filters="$filters --filter=label=dex-remote=$DEX_REMOTE"

    [ ! "$DEX_REMOTE_IMAGESTR" = "*" ] && \
      filters="$filters --filter=label=dex-image=$DEX_REMOTE_IMAGESTR"

    [ ! "$DEX_REMOTE_IMAGETAG" = "latest" ] && \
      filters="$filters --filter=label=dex-tag=$DEX_REMOTE_IMAGETAG"
  fi


  docker images $QUIET_FLAG $filters
}


dex-image-rm(){
  local tag_prefix=${1:-$DEX_TAG_PREFIX}

  if [ -z "$LOOKUP" ]; then
    ERRCODE=2
    error "image-rm requires an image name, package name, or wildcard match to install"
  fi

  dex-lookup-parse $LOOKUP

  local removed_image=false
  local filters="--filter=label=dex-tag-prefix=$tag_prefix"
  local force_flag=
  $FORCE_FLAG && force_flag="--force"


  [ ! "$DEX_REMOTE" = "*" ] && \
    filters="$filters --filter=label=dex-remote=$DEX_REMOTE"

  [ ! "$DEX_REMOTE_IMAGESTR" = "*" ] && \
    filters="$filters --filter=label=dex-image=$DEX_REMOTE_IMAGESTR"

  [ ! "$DEX_REMOTE_IMAGETAG" = "latest" ] && \
    filters="$filters --filter=label=dex-tag=$DEX_REMOTE_IMAGETAG"

  for image in $(docker images -q $filters); do
    #@TODO stop running containers?
    docker rmi $force_flag $image && removed_image=true
  done

  $removed_image && {
    log "removed $DEX_REMOTE/$DEX_REMOTE_IMAGESTR"
    exit 0
  }

  error "failed to remove any images matching $DEX_REMOTE/$DEX_REMOTE_IMAGESTR"
}
#!/bin/bash

set -uo pipefail

IGTOP=$(readlink -f "$(dirname "$0")")

source "${IGTOP}/scripts/common"
source "${IGTOP}/scripts/dependencies_check"
dependencies_check "${IGTOP}/depends" || exit 1


usage()
{
cat <<-EOF >&2
Usage
  $(basename "$0") [options]

Root filesystem and image generation utility.

Options:
  [-c <config>]    Name of config file, location defaults to config/
  [-D <directory>] Directory that takes precedence over the default in-tree
                   hierarchy when searching for config files, profiles, meta
                   layers and image layouts.
  [-N <namespace>] Optional namespace to specify an additional sub-directory
                   hierarchy within the directory provided by -D of where to
                   search for meta layers.
  [-o <file>]      Path to shell-style fragment specifying variables as
                   key=value. These variables can override the defaults, those
                   set by the config file, or provide completely new variables
                   available to both rootfs and image generation stages.
  Developer Options
  [-r]             Establish configuration, build rootfs, exit after post-build.
  [-i]             Establish configuration, skip rootfs, run hooks, generate image.
EOF
}


# Arg parser and defaults
EXT_DIR=
EXT_META=
EXT_NS=
EXT_NSDIR=
EXT_NSMETA=
INOPTIONS=
INCONFIG=generic64-apt-simple
ONLY_ROOTFS=0
ONLY_IMAGE=0

while getopts "c:D:hiN:o:r" flag ; do
   case "$flag" in
      c)
         INCONFIG="$OPTARG"
         ;;
      h)
         usage ; exit 0
         ;;
      D)
         EXT_DIR=$(realpath -m "$OPTARG")
         [[ -d $EXT_DIR ]] || { usage ; die "Invalid external directory: $EXT_DIR" ; }
         ;;
      i)
         ONLY_IMAGE=1
         ;;
      N)
         EXT_NS="$OPTARG"
         ;;
      o)
         INOPTIONS=$(realpath -m "$OPTARG")
         [[ -s $INOPTIONS ]] || { usage ; die "Invalid options file: $INOPTIONS" ; }
         ;;
      r)
         ONLY_ROOTFS=1
         ;;
      ?|*)
         usage ; exit 1
         ;;
   esac
done


[[ -d $EXT_DIR ]] && EXT_META=$(realpath -e "${EXT_DIR}/meta" 2>/dev/null)

[[ -n $EXT_NS && ! -d $EXT_DIR ]] && die "External namespace supplied without external dir"

if [[ -d $EXT_DIR && -n $EXT_NS ]] ; then
   EXT_NSDIR=$(realpath -e "${EXT_DIR}/$EXT_NS" 2>/dev/null)
   [[ -d $EXT_NSDIR ]] || die "External namespace dir $EXT_NS does not exist in $EXT_DIR"
   EXT_NSMETA=$(realpath -e "${EXT_DIR}/$EXT_NS/meta" 2>/dev/null)
fi


# Constants
IGTOP_CONFIG="${IGTOP}/config"
IGTOP_BOARD="${IGTOP}/board"
IGTOP_IMAGE="${IGTOP}/image"
IGTOP_PROFILE="${IGTOP}/profile"
IGTOP_SBOM="${IGTOP}/sbom"
META="${IGTOP}/meta"
META_HOOKS="${IGTOP}/meta-hooks"
RPI_TEMPLATES="${IGTOP}/templates/rpi"


# Establish the top level directory hierarchy by first reading the config
if [[ -d "${EXT_DIR}/config" && -s "${EXT_DIR}/config/${INCONFIG}.cfg" ]] ; then
   IGTOP_CONFIG="${EXT_DIR}/config"
elif [[ -s "${IGTOP}/config/${INCONFIG}.cfg" ]] ; then
   IGTOP_CONFIG="${IGTOP}/config"
else
   die "config "$INCONFIG" not found or invalid"
fi

msg "Reading $INCONFIG from $IGTOP_CONFIG with options [$INOPTIONS]"
[[ -d $EXT_META ]] && msg "External meta at $EXT_META"
[[ -d $EXT_NSMETA ]] && msg "External [$EXT_NS] meta at $EXT_NSMETA"


# Defaults
IGconf_target_board=pi5
IGconf_image_version=$(date +%Y-%m-%d)
IGconf_image_name="${IGconf_target_board}-$(echo "${INCONFIG}"|sed -s 's|\/|\-|g')-${IGconf_image_version}"
IGconf_image_suffix=img
IGconf_image_compression=none
unset IGconf_apt_proxy
IGconf_target_hostname=raspberrypi
IGconf_first_user_name=pi
unset IGconf_first_user_pass
IGconf_locale_default="en_GB.UTF-8"
IGconf_keyboard_keymap=gb
IGconf_keyboard_layout="English (UK)"
IGconf_timezone_default="Europe/London"
unset IGconf_ext_dir
unset IGconf_ext_nsdir
unset IGconf_apt_keydir
IGconf_sbom_output_format="spdx-json"


# Provide external directory paths
[[ -d $EXT_DIR ]] && IGconf_ext_dir="$EXT_DIR"
[[ -d $EXT_NSDIR ]] && IGconf_ext_nsdir="$EXT_NSDIR"


read_config "${IGTOP_CONFIG}/${INCONFIG}.cfg"


# Config must provide
[[ -z ${IGconf_image_layout+x} ]] && die "Config has no image layout"
[[ -z ${IGconf_system_profile+x} ]] && die "Config has no system profile"


# Internalise hierarchy paths, prioritising the external sub-directory tree
[[ -d $EXT_DIR ]] && IGBOARD=$(realpath -e "${EXT_DIR}/board/$IGconf_target_board" 2>/dev/null)
: ${IGBOARD:=${IGTOP_BOARD}/$IGconf_target_board}

[[ -d $EXT_DIR ]] && IGIMAGE=$(realpath -e "${EXT_DIR}/image/$IGconf_image_layout" 2>/dev/null)
: ${IGIMAGE:=${IGTOP_IMAGE}/$IGconf_image_layout}

[[ -d $EXT_DIR ]] && IGPROFILE=$(realpath -e "${EXT_DIR}/profile/$IGconf_system_profile" 2>/dev/null)
: ${IGPROFILE:=${IGTOP_PROFILE}/$IGconf_system_profile}


# Final path validation
for i in IGBOARD IGIMAGE IGPROFILE ; do
   msg "$i ${!i}"
   realpath -e ${!i} > /dev/null 2>&1 || die "$i is invalid"
done


# Load options
[[ -s "$INOPTIONS" ]] && read_options "$INOPTIONS"


# Remaining defaults
: "${IGconf_work_dir:=${IGTOP}/work/${IGconf_image_name}}"
: "${IGconf_image_outputdir:=${IGconf_work_dir}/artefacts}"
: "${IGconf_image_deploydir:=${IGconf_work_dir}/deploy}"


# Assemble keys
if [[ -z ${IGconf_apt_keydir+z} ]] ; then
   IGconf_apt_keydir="${IGconf_work_dir}/keys"
   mkdir -p "$IGconf_apt_keydir"
   [[ -d /usr/share/keyrings ]] && rsync -a /usr/share/keyrings/ $IGconf_apt_keydir
   [[ -d "$USER/.local/share/keyrings" ]] && rsync -a "$USER/.local/share/keyrings/" $IGconf_apt_keydir
   rsync -a "$IGTOP/keydir/" $IGconf_apt_keydir
fi
[[ -d $IGconf_apt_keydir ]] || die "apt keydir $IGconf_apt_keydir is invalid"


# Assemble environment for rootfs and image creation, propagating IG variables
# to rootfs and post-build stages as appropriate.
ENV_ROOTFS=()
ENV_POST_BUILD=()
for v in $(compgen -A variable -X '!IGconf*') ; do
   case $v in
      IGconf_timezone_default)
         ENV_ROOTFS+=('--env' IGconf_timezone_area="${!v%%/*}")
         ENV_ROOTFS+=('--env' IGconf_timezone_city="${!v##*/}")
         ENV_POST_BUILD+=(IGconf_timezone_area="${!v%%/*}")
         ENV_POST_BUILD+=(IGconf_timezone_city="${!v##*/}")
         ;;
      IGconf_apt_proxy)
         IGconf_apt_proxy_http="${!v}"
         ;&
      IGconf_apt_proxy_http)
         err=$(curl --head --silent --write-out "%{http_code}" --output /dev/null "${!v}")
         [[ $? -ne 0 ]] && die "unreachable proxy : ${!v}"
         msg "$err ${!v}"
         ENV_ROOTFS+=('--aptopt' "Acquire::http { Proxy \"${!v}\"; }")
         ENV_ROOTFS+=('--env' IGconf_apt_proxy_http="${!v}")
         ;;
      IGconf_apt_keydir)
         ENV_ROOTFS+=('--aptopt' "Dir::Etc::TrustedParts ${!v}")
         ENV_ROOTFS+=('--env' IGconf_apt_keydir="${!v}")
         ;;
      *)
         ENV_ROOTFS+=('--env' ${v}="${!v}")
         ENV_POST_BUILD+=(${v}="${!v}")
         ;;
   esac
done
ENV_ROOTFS+=('--env' IGTOP=$IGTOP)
ENV_ROOTFS+=('--env' META_HOOKS=$META_HOOKS)
ENV_ROOTFS+=('--env' RPI_TEMPLATES=$RPI_TEMPLATES)

for i in IGBOARD IGIMAGE IGPROFILE ; do
   ENV_POST_BUILD+=(${i}="${!i}")
done


# If needed, hooks can install to here. This location will take precedence in their PATH.
mkdir -p ${IGconf_work_dir}/host/bin
ENV_POST_BUILD+=(PATH="${IGconf_work_dir}/host/bin:${PATH}")


# Assemble meta layers from profile
ARGS_LAYERS=()
while read -r line; do
   [[ "$line" =~ ^#.*$ ]] && continue
   [[ "$line" =~ ^$ ]] && continue
   if [[ -n $EXT_NSMETA && -s ${EXT_NSMETA}/$line.yaml ]] ; then
      ARGS_LAYERS+=('--config' "${EXT_NSMETA}/$line.yaml")
   elif [[ -n $EXT_META && -s ${EXT_META}/$line.yaml ]] ; then
      ARGS_LAYERS+=('--config' "${EXT_META}/$line.yaml")
   elif [[ -s ${META}/$line.yaml ]] ; then
      ARGS_LAYERS+=('--config' "${META}/$line.yaml")
   else
      die "Invalid meta specifier: $line (not found)"
   fi
done < "${IGPROFILE}"


# Generate rootfs
[[ $ONLY_IMAGE = 1 ]] && true || run podman unshare bdebstrap \
   "${ARGS_LAYERS[@]}" \
   "${ENV_ROOTFS[@]}" \
   --name "$IGconf_image_name" \
   --hostname "$IGconf_target_hostname" \
   --output "$IGconf_image_outputdir" \
   --target "${IGconf_work_dir}/rootfs" \
   --setup-hook '$IGTOP/scripts/runner setup $IGTOP/scripts/bdebstrap "${IGconf_work_dir}/rootfs"' \
   --essential-hook '$IGTOP/scripts/runner essential $IGTOP/scripts/bdebstrap "${IGconf_work_dir}/rootfs"' \
   --customize-hook '$IGTOP/scripts/runner customize $IGTOP/scripts/bdebstrap "${IGconf_work_dir}/rootfs"' \
   --cleanup-hook '$IGTOP/scripts/runner cleanup $IGTOP/scripts/bdebstrap "${IGconf_work_dir}/rootfs"'


# hook execution
runh()
{
   local hookdir=$(dirname "$1")
   local hook=$(basename "$1")
   shift 1
   msg "$hookdir"["$hook"] "$@"
   env -C $hookdir "${ENV_POST_BUILD[@]}" ./"$hook" "$@"
   ret=$?
   if [[ $ret -ne 0 ]]
   then
      die "Hook Error: ["$hookdir"/"$hook"] ($ret)"
   fi
}


# post-build: apply rootfs overlays - image layout then board
if [ -d ${IGIMAGE}/rootfs-overlay ] ; then
   run rsync -a ${IGIMAGE}/rootfs-overlay/ ${IGconf_work_dir}/rootfs
fi
if [ -d ${IGBOARD}/rootfs-overlay ] ; then
   run rsync -a ${IGBOARD}/rootfs-overlay/ ${IGconf_work_dir}/rootfs
fi


# post-build: hooks - image layout then board
if [ -x ${IGIMAGE}/post-build.sh ] ; then
   runh ${IGIMAGE}/post-build.sh ${IGconf_work_dir}/rootfs
fi
if [ -x ${IGBOARD}/post-build.sh ] ; then
   runh ${IGBOARD}/post-build.sh ${IGconf_work_dir}/rootfs
fi


[[ $ONLY_ROOTFS = 1 ]] && exit $?


# pre-image: hooks - board has priority over image layout
if [ -x ${IGBOARD}/pre-image.sh ] ; then
   runh ${IGBOARD}/pre-image.sh ${IGconf_work_dir}/rootfs ${IGconf_image_outputdir}
elif [ -x ${IGIMAGE}/pre-image.sh ] ; then
   runh ${IGIMAGE}/pre-image.sh ${IGconf_work_dir}/rootfs ${IGconf_image_outputdir}
else
   die "no pre-image hook"
fi


# SBOM
if [ -x ${IGTOP_SBOM}/gen.sh ] ; then
   runh ${IGTOP_SBOM}/gen.sh ${IGconf_work_dir}/rootfs ${IGconf_image_outputdir}
fi


GTMP=$(mktemp -d)
trap 'rm -rf $GTMP' EXIT
mkdir -p "$IGconf_image_deploydir"


# Generate image(s)
for f in "${IGconf_image_outputdir}"/genimage*.cfg; do
   run podman unshare env "${ENV_POST_BUILD[@]}" genimage \
      --rootpath ${IGconf_work_dir}/rootfs \
      --tmppath $GTMP \
      --inputpath ${IGconf_image_outputdir}   \
      --outputpath ${IGconf_image_outputdir} \
      --loglevel=1 \
      --config $f | pv -t -F 'Generating image...%t' || die "genimage error"
done


# post-image: hooks - board has priority over image layout
if [ -x ${IGBOARD}/post-image.sh ] ; then
   runh ${IGBOARD}/post-image.sh $IGconf_image_deploydir
elif [ -x ${IGIMAGE}/post-image.sh ] ; then
   runh ${IGIMAGE}/post-image.sh $IGconf_image_deploydir
else
   runh ${IGTOP_IMAGE}/post-image.sh $IGconf_image_deploydir
fi

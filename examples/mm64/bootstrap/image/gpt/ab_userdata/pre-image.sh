#!/bin/sh

image_top=$(readlink -f $(dirname "$0"))
rootfs=$1
genimg_in=$2

# Set up the partition layout for tryboot support. Partition numbering
# relates directly to the layout in genimage.cfg.in

cat << EOF > "${genimg_in}/autoboot.txt"
[all]
tryboot_a_b=1
boot_partition=2
[tryboot]
boot_partition=3
EOF

# Generate the config for genimage to ingest:
# FIXME - calc dynamically
FW_SIZE=60M
ROOT_SIZE=700M

SLOTP_PROCESS=$(readlink -f ${image_top}/slot-post-process.sh)

cat $image_top/genimage.cfg.in | sed \
   -e "s|<DEPLOY_DIR>|$IGconf_deploydir|g" \
   -e "s|<IMAGE_NAME>|${IGconf_board}-ab|g" \
   -e "s|<FW_SIZE>|$FW_SIZE|g" \
   -e "s|<ROOT_SIZE>|$ROOT_SIZE|g" \
   -e "s|<SLOTP>|'$SLOTP_PROCESS'|g" \
   > ${genimg_in}/genimage.cfg

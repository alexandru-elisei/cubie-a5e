#!/bin/bash

REAL_DIR="$(dirname $(readlink -f $0))"
source "$REAL_DIR"/common.bash

DEV=""
IMAGE=""

START_DIR=$(pwd)

function usage() {
	cat <<EOF
Usage: $0 [options]

Options:
    --dev=DEV         path to block device to write the uboot image (required)
    --image=IMAGE     image file to write to DEV, usually
                      u-boot-sunxi-with-spl.bin in the u-boot source directory.
                      If left unset, it will be read from the file
                      $BUILD_ARTIFACT, if present in the current directory.
    --help            show this help message
EOF
}

optno=1
argc=$#
while [[ $optno -le $argc ]]; do
	opt="$1"
	shift 1
	arg=""
	if [[ "$opt" = *=* ]]; then
		arg="${opt#*=}"
		opt="${opt%%=*}"
	fi

	optno=$(($optno+1))

	case "$opt" in
	--image)
		IMAGE="$arg"
		;;
	--dev)
		DEV="$arg"
		;;
	--help)
		usage
		exit 0
		;;
	*)
		echo "Unknown option '$opt'"
		echo
		usage
		exit 1
		;;
	esac
done

if [[ ! -b "$DEV" ]]; then
	echo "file '$DEV' is not a block device"
	usage
	exit 1
fi

if [[ -z "$IMAGE" ]]; then
	if [[ ! -f "$START_DIR"/"$BUILD_ARTIFACT" ]]; then
		echo "IMAGE not set and '$BUILD_ARTIFACT' not found"
		usage
		exit 1
	fi
	IMAGE=$(cat "$BUILD_ARTIFACT")
	echo "found image '$IMAGE' in $BUILD_ARTIFACT"
fi

if [[ ! -f "$IMAGE" ]]; then
	echo "image '$IMAGE' does not exist or is not a regular file"
	usage
	exit 1
fi

echo "copying '$IMAGE' to '$DEV'"
read -p "press any key to continue..."

trap sigint_handler SIGINT

# Documentation in $UBOOT_DIR/doc/board/allwiner/sunxi.rst
dd if="$IMAGE" of="$DEV" conv=fsync oflag=direct status=progress bs=1k seek=128
check_return_code $? "error copying '$IMAGE' to block device '$DEV'"

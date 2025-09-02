#!/bin/bash

REAL_DIR="$(dirname $(readlink -f $0))"
source "$REAL_DIR"/common.bash

TFTP_DIR=$HOME/data/tftpboot/cubie-a5e
DTB_SRC_NAME=sun55i-a527-cubie-a5e.dtb
IMAGE_LINK=Image
DTB_LINK=dtb

KERNEL_DIR=""
CONFIG=""
LABEL=""

START_DIR=$(pwd)
NCPUS=$(getconf _NPROCESSORS_ONLN)

function usage() {
	cat <<EOF
Usage: $0 [options]

Options:
    --kernel-dir=KERNEL_DIR   path to kernel directory (required)
    --config=CONFIG           path to config file to apply to kernel (optional)
    --label=LABEL             label to append to kernel image and dtb (required)
    --help                    show this help message
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
	--kernel-dir)
		KERNEL_DIR="${arg/#\~/$HOME}"
		;;
	--config)
		CONFIG="${arg/#\~/$HOME}"
		;;
	--label)
		LABEL="$arg"
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

if [[ ! -d "$KERNEL_DIR" ]]; then
	echo "kernel directory '$KERNEL_DIR' is not a directory"
	usage
	exit 1
fi

if [[ -z "$LABEL" ]]; then
	echo 'missing --label'
	usage
	exit 1
fi

if [[ "$CONFIG" ]] && [[ ! -f "$CONFIG" ]]; then
	echo "config file '$CONFIG' not found or not a regular file"
	usage
	exit 1
fi

pushd "$KERNEL_DIR"
check_return_code $? "error changing directory to '$KERNEL_DIR'"

trap sigint_handler SIGINT
check_return_code $? "error installing SIGINT trap handler"

if [[ "$CONFIG" ]]; then
	cp "$CONFIG" .config
	check_return_code $? "error copying config '$CONFIG'"

	make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$NCPUS olddefconfig
	check_return_code $? "error making olddefconfig"
fi

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$NCPUS
check_return_code $? "error making olddefconfig"

popd

IMAGE_NAME=Image-$LABEL
DTB_NAME="$DTB_SRC_NAME-$LABEL"

IMAGE_SRC="$KERNEL_DIR"/arch/arm64/boot/Image
IMAGE_DEST="$TFTP_DIR/$IMAGE_NAME"
/usr/bin/cp "$IMAGE_SRC" "$IMAGE_DEST"
check_return_code $? "error copying image '$IMAGE_SRC' to '$IMAGE_DEST'"

DTB_SRC="$KERNEL_DIR/arch/arm64/boot/dts/allwinner/$DTB_SRC_NAME"
DTB_DEST="$TFTP_DIR/$DTB_NAME"
/usr/bin/cp "$DTB_SRC" "$DTB_DEST"
check_return_code $? "error copying dtb '$DTB_SRC' to '$DTB_DEST'"

pushd "$TFTP_DIR"

IMAGE_LINK=Image
rm -f "$IMAGE_LINK"
check_return_code $? "error deleting symbolic link '$IMAGE_LINK'"
ln -s "$IMAGE_NAME" "$IMAGE_LINK"
check_return_code $? "error creating symbolic link '$IMAGE_LINK' to '$IMAGE_NAME'"

DTB_LINK=dtb
rm -f "$DTB_LINK"
check_return_code $? "error deleting symbolic link '$DTB_LINK'"
ln -s "$DTB_NAME" "$DTB_LINK"
check_return_code $? "error creating symbolic link '$DTB_LINK' to '$DTB_NAME'"

popd

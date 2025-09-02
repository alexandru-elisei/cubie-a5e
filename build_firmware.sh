#!/bin/bash

REAL_DIR="$(dirname $(readlink -f $0))"
source "$REAL_DIR"/common.bash

UBOOT_DIR=""
TFA_DIR=""
GENERATE_DEFCONFIG=n

START_DIR="$(pwd)"
NCPUS=$(getconf _NPROCESSORS_ONLN)

function usage() {
	cat <<EOF
Usage: $0 [options]

Options:
    --uboot-dir=UBOOT_DIR      path to uboot source directory (required)
    --tfa-dir=TFA_DIR          path to TFA source directory (required)
    --generate-defconfig=[n|y] generate Cubie A5E defconfig for u-boot ($GENERATE_DEFCONFIG)
                               (optional).
    --help                     show this help message
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
	--uboot-dir)
		UBOOT_DIR="$arg"
		;;
	--tfa-dir)
		TFA_DIR="$arg"
		;;
	--generate-defconfig)
		GENERATE_DEFCONFIG="$arg"
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

if [[ ! -d "$UBOOT_DIR" ]]; then
	echo "'$UBOOT_DIR' is not a valid directory"
	exit 1
fi
if [[ ! -d "$TFA_DIR" ]]; then
	echo "'$TFA_DIR' is not a valid directory"
	exit 1
fi
if [[ "$GENERATE_DEFCONFIG" != n ]] && [[ "$GENERATE_DEFCONFIG" != y ]]; then
	echo "unknown value '$GENERATE_DEFCONFIG' for --generate-defconfig"
	usage
	exit 1
fi

pushd "$TFA_DIR"
check_return_code $? "error changing directory to '$TFA_DIR'"

trap sigint_handler SIGINT
check_return_code $? "error installing SIGINT trap handler"

# Documentation in $TFA_DIR/docs/plat/allwiner.rst
make \
	CROSS_COMPILE=aarch64-linux-gnu- \
	PLAT=sun55i_a523 \
	-j$NCPUS
check_return_code $? "error building TFA"

export BL31="$TFA_DIR"/build/sun55i_a523/release/bl31.bin
export CROSS_COMPILE=aarch64-linux-gnu-

popd
pushd "$UBOOT_DIR"
check_return_code $? "error changing directory to '$UBOOT_DIR'"

# Documentation in $UBOOT_DIR/doc/board/allwiner/sunxi.rst
if [[ "$GENERATE_DEFCONFIG" == y ]]; then
	make radxa-cubie-a5e_defconfig
	check_return_code $? "error making radxia-cubie-a5e_defconfig"
fi

make -j$NCPUS
check_return_code $? "error in make"

popd
check_return_code $? "error popping '$START_DIR'"

IMAGE="$UBOOT_DIR/u-boot-sunxi-with-spl.bin"
if [[ ! -f "$IMAGE" ]]; then
	echo "u-boot image '$IMAGE' not found"
	exit 1
fi
echo "$IMAGE" > "$BUILD_ARTIFACT"
check_return_code $? "error writing '$BUILD_ARTIFACT'"
echo "u-boot image '$IMAGE' written to '$BUILD_ARTIFACT'"

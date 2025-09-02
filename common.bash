# Source me, don't execute me.

BUILD_ARTIFACT=build.out

function print_msg() {
	echo ""
	echo "$@"
	echo ""
}

function sigint_handler() {
	if [[ "$(pwd)" != "$CURR_DIR" ]]; then
		popd
	fi
	exit 130
}

function check_return_code() {
	local err=$1
	shift 1
	local msg="$@"

	if [[ "$err" != 0 ]]; then
		print_msg "$msg"
		if [[ "$(pwd)" != "$START_DIR" ]]; then
			popd
		fi
		exit $err
	fi
}

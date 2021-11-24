function metrics_jitter()
{
	local query="${1}"
	local bt=`build_bt`
	local res=`"${bt}" metrics jitter -u "${url}" -q "${query}" -b "${begin}" -e "${end}" | grep jitter | awk '{print $2,$4,$6}' | tr -d ,`
	echo "${res}"
}

function metrics_aggregate()
{
	local query="${1}"
	local bt=`build_bt`
	local res=`"${bt}" metrics aggregate -u "${url}" -q "${query}" -b "${begin}" -e "${end}" | awk '{print $2,$4,$6}' | tr -d ,`
	echo "${res}"
}

function build_bin()
{
	local dir="${1}"
	local bin_path="${2}"
	local make_cmd="${3}"
	(
		cd "${dir}"
		if [ -f "${bin_path}" ]; then
			return
		fi
		${make_cmd} 1>&2
		if [ ! -f "${bin_path}" ]; then
			echo "[:(] can't build '${bin_path}' from build dir: '${dir}'" >&2
			exit 1
		fi
		echo "[:)] build '${bin_path}' in build dir: '${dir}'" >&2
	)
	echo "${dir}/${bin_path}"
}

function build_bt()
{
	local bt_repo_path="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../../repos/bench-toolset"
	build_bin "${bt_repo_path}" 'bin/bench-toolset' 'make'
}

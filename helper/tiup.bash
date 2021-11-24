function confirm_str()
{
	local env="${1}"
	local confirm=`must_env_val "${env}" 'tidb.op.confirm'`
	local is_false=`to_false "${confirm}"`
	if [ "${is_false}" != 'false' ]; then
		echo ''
	else
		# skip confirm
		echo ' --yes'
	fi
}

function maybe_enable_opt()
{
	local value=`to_true "${1}"`
	local opt="${2}"
	if [ "${value}" == 'true' ]; then
		echo " ${opt}"
	else
		echo ''
	fi
}

function cluster_patch()
{
	local role="${1}"
	local os=`_must_get_os`
	local arch=`_must_get_arch`
	tar -czvf "${role}-local-${os}-${arch}.tar.gz" "${role}-server"
	tiup cluster patch "${name}" "${role}-local-${os}-${arch}.tar.gz" -R "${role}" --yes --offline
	echo "[:)] patched local '${role}' to cluster '${name}'"
}

function path_patch()
{
	local path="${1}"
	if [ -d "${path}" ]; then
		(
			cd "${path}";
			if [ -f "tidb-server" ]; then
				cluster_patch 'tidb'
			fi
			if [ -f "tikv-server" ]; then
				cluster_patch 'tikv'
			fi
			if [ -f "pd-server" ]; then
				cluster_patch 'pd'
			fi
		)
	elif [ -f "${path}" ]; then
		local base=`basename ${path}`
		local dir=`dirname ${path}`
		local role="${base%*-server}"
		if [ ! "${role}" ]; then
			echo "[:(] unrecognized file '${path}'" >&2
			exit 1
		fi
		(
			cd "${dir}";
			cluster_patch "${role}"
		)
	fi
}

function _must_get_os()
{
	if [[ "${OSTYPE}" == 'linux-gnu'* ]]; then
		local os='linux'
	elif [[ "${OSTYPE}" == 'darwin'* ]]; then
		local os='darwin'
	else
		echo "[:(] not support os '${OSTYPE}'" >&2
		exit 1
	fi
	echo "${os}"
}

function _must_get_arch()
{
	case $(uname -m) in
		i386)   local arch='386' ;;
		i686)   local arch='386' ;;
		x86_64) local arch='amd64' ;;
		arm)    local arch='arm64' ;;
	esac
	echo "${arch}"
}

function expand_version_and_path()
{
	ver_path=`expr "${ver}" : '\(.*+\)' || true`
	if [ "${ver_path}" ]; then
		path="${ver#*+}"
		ver="${ver_path%+}"
	else
		path=''
	fi
	echo "${ver} ${path}"
}

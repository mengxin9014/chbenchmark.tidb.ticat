function to_true()
{
	local val="${1}"
	local trues=('true' 't' 'yes' 'y' 'on' '1')
	for t in ${trues[@]}; do
		if [ "${t}" == "${val}" ]; then
			echo 'true'
			return
		fi
	done
	echo 'false'
}

function to_false()
{
	local val="${1}"
	local trues=('false' 'f' 'no' 'n' 'off' '0')
	for t in ${trues[@]}; do
		if [ "${t}" == "${val}" ]; then
			echo 'false'
			return
		fi
	done
	echo 'true'
}

function env_val()
{
	local env="${1}"
	local key="${2}="
	local key_len=${#key}
	local val_line=`echo "${env}" | { grep "^${key}" || test $? = 1; } | tail -n 1`
	local val="${val_line:$key_len}"
	echo "${val}"
}

function must_env_val()
{
	local env="${1}"
	local key="${2}"
	local val=`env_val "${env}" "${key}"`
	if [ -z "${val}" ]; then
		echo "[:(] no env val '${key}'" >&2
		exit 1
	fi
	echo "${val}"
}

function ssh_exe()
{
	local host="${1}"
	local cmd="${2}"
	ssh -i "${pri_key}" -o BatchMode=yes "${user}"@"${host}" ${cmd} </dev/null
}

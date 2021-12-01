set -euo pipefail
. "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../helper/helper.bash"

env_file="${1}/env"
env=`cat "${env_file}"`
shift
chbench_path=`must_env_val "${env}" 'chbench.chbench_path'`
sf=`must_env_val "${env}" 'chbench.scalefactor'`
host=`must_env_val "${env}" 'mysql.host'`
port=`must_env_val "${env}" 'mysql.port'`
user=`must_env_val "${env}" 'mysql.user'`

function set_tiflash()
{
  local database="$1"
  local tables="$2"
  local mysql_client="$3"
  local tiflash_replica=1

  for table in $tables
  do
    $mysql_client "alter table $database.$table set tiflash replica $tiflash_replica"
  done
}

loadconfig="${chbench_path}/config/tidb/chbenchmark_config_base.xml"
jarfile="${chbench_path}/benchbase.jar"
url="jdbc:mysql:\/\/${host}:${port}\/benchbase?rewriteBatchedStatements=true"
tables="CUSTOMER ITEM HISTORY DISTRICT NEW_ORDER OORDER ORDER_LINE STOCK WAREHOUSE nation region supplier"

mysql --host ${host} --port ${port} -u ${user} -e "create database if not exists benchbase"
cd ${chbench_path}
cat  ${loadconfig} | sed "s/<scalefactor>.*<\/scalefactor>/<scalefactor>${sf}<\/scalefactor>/g" | sed "s/<url>.*<\/url>/<url>${url}<\/url>/g" > load_config_temp.xml
java -jar ${jarfile} -b tpcc,chbenchmark -c load_config_temp.xml --create=true --load=true --execute=false &
sleep 20
set_tiflash benchbase "$tables" "mysql --host $host --port $port -u root -e"
wait
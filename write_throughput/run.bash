. "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../helper/helper.bash"

env_file="${1}/env"
env=`cat "${env_file}"`
shift
chbench_path=`must_env_val "${env}" 'write_throughput.chbench_path'`
host=`must_env_val "${env}" 'mysql.host'`
port=`must_env_val "${env}" 'mysql.port'`
user=`must_env_val "${env}" 'mysql.user'`
pd_host=`must_env_val "${env}" 'pd.host'`
pd_port=`must_env_val "${env}" 'pd.port'`

br_storage="${1}"
thread="${2}"
table_number="${3}"

function br_wait_table()
{
  local database="$1"
  local tables="$2"
  local mysql_client="$3"
  local tiflash_replica=1
  local time_out=3600
  time=0

  count_table=""
  for table in $tables
  do
      $mysql_client "LOAD STATS '$chbench_path/benchbase_table_static/$table.json'"
      count_table="${count_table};select count(*) from benchbase.$table"
  done

  while true
  do
    if [ ${time} -eq ${time_out} ]
    then
      echo "br wait tiflash table failed!"
      exit 1
    fi
    $mysql_client "set tidb_isolation_read_engines='tiflash'${count_table}"
    if [ ${?} -eq 0 ]
    then
      break
    else
      sleep 1
      time=${time}+1
    fi
  done
}

echo -e "mysql-host=$ip" > ./sysbench.config
echo -e "mysql-port=$port" >> ./sysbench.config
echo -e "mysql-user=root" >> ./sysbench.config
echo -e "mysql-password=" >> ./sysbench.config
echo -e "mysql-db=sbtest" >> ./sysbench.config
echo -e "time=60" >> ./sysbench.config
echo -e "threads=16" >> ./sysbench.config
echo -e "report-interval=10" >> ./sysbench.config
echo -e "db-driver=mysql" >> ./sysbench.config
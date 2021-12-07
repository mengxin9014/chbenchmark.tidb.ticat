. "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../helper/helper.bash"

env_file="${1}/env"
env=`cat "${env_file}"`
shift
chbench_path=`must_env_val "${env}" 'write_throughput.chbench_path'`
thread=`must_env_val "${env}" 'write_throughput.thread'`
host=`must_env_val "${env}" 'mysql.host'`
port=`must_env_val "${env}" 'mysql.port'`
user=`must_env_val "${env}" 'mysql.user'`
pd_host=`must_env_val "${env}" 'pd.host'`
pd_port=`must_env_val "${env}" 'pd.port'`

br_storage="${1}"
table_number="${2}"
table_size="${3}"
duration="${4}"

result_dir="${chbench_path}/result"
if [ -d "$result_dir" ]
then
	echo $result_dir already exists
	rm -rf ${chbench_path}/result
fi

mkdir $result_dir

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
      $mysql_client "LOAD STATS '$chbench_path/sbtest_table_static/$table.json'"
      count_table="${count_table};select count(*) from sbtest.$table"
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

echo -e "mysql-host=$host" > ./sysbench.config
echo -e "mysql-port=$port" >> ./sysbench.config
echo -e "mysql-user=root" >> ./sysbench.config
echo -e "mysql-password=" >> ./sysbench.config
echo -e "mysql-db=sbtest" >> ./sysbench.config
echo -e "time=$duration" >> ./sysbench.config
echo -e "threads=$thread" >> ./sysbench.config
echo -e "report-interval=$duration" >> ./sysbench.config
echo -e "db-driver=mysql" >> ./sysbench.config


tables="sbtest1"
for ((i=2; i<=$table_number; i++))
do
    tables="$tables sbtest$i"
done
url="jdbc:mysql:\/\/${host}:${port}\/benchbase?rewriteBatchedStatements=true"

cat config/tidb/querys/chbenchmark_config_sbtest_base.xml  | sed "s/<url>.*<\/url>/<url>${url}<\/url>/g" | sed "s/<tableNumber>.*<\/tableNumber>/<tableNumber>${table_number}<\/tableNumber>/g" > config/tidb/querys/chbenchmark_config_sbtest.xml

mysql --host $host --port $port -u root -e "drop database if exists sbtest"
mysql --host $host --port $port -u root -e "set global tidb_disable_txn_auto_retry=off"
AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin br restore db --pd ${pd_host}:${pd_port} --db sbtest -s ${br_storage} --s3.endpoint http://minio.pingcap.net:9000 --send-credentials-to-tikv=true
br_wait_table sbtest "$tables" "mysql --host $host --port $port -u root -e"

sysbench --config-file=./sysbench.config oltp_write_only --tables=$table_number --table-size=$table_size run &
java -jar benchbase.jar -b chbenchmark -c config/tidb/querys/chbenchmark_config_sbtest.xml  --create=false --load=false --execute=true -d $result_dir/write_throughput_table_result &
wait
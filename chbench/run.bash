. "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../helper/helper.bash"

env_file="${1}/env"
env=`cat "${env_file}"`
shift
query=`must_env_val "${env}" 'chbench.query'`
thread=`must_env_val "${env}" 'chbench.thread'`
chbench_path=`must_env_val "${env}" 'chbench.chbench_path'`
sf=`must_env_val "${env}" 'chbench.scalefactor'`
host=`must_env_val "${env}" 'mysql.host'`
port=`must_env_val "${env}" 'mysql.port'`
user=`must_env_val "${env}" 'mysql.user'`
pd_host=`must_env_val "${env}" 'pd.host'`
pd_port=`must_env_val "${env}" 'pd.port'`

br_storage="${1}"
duration="${2}"
db_name="${3}"

function br_wait_table()
{
  local database="$1"
  local tables="$2"
  local mysql_client="$3"
  local time_out=3600
  time=0

  count_table=""
  for table in $tables
  do
      $mysql_client "LOAD STATS '$chbench_path/benchbase_table_static/$table.json'"
      count_table="${count_table};select count(*) from $database.$table"
  done

  while true
  do
    if [ "${time}" -eq ${time_out} ]
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
      time=$(expr $time + 1)
    fi
  done

  if [ -f "$chbench_path/querys_map.txt" ]
  then
    sql=$(cat $chbench_path/querys_map.txt | grep -w $query | awk -F "#" '{print $2}')
    echo "$query explain:"
    $mysql_client "use $database;explain $sql"
  fi
}

apconfig="${chbench_path}/config/tidb/querys/chbenchmark_config_ap_base.xml"
tpconfig="${chbench_path}/config/tidb/querys/chbenchmark_config_tp_base.xml"
jarfile="${chbench_path}/benchbase.jar"
result_dir="${chbench_path}/result"
if [ -d "$result_dir" ]
then
	echo $result_dir already exists
	rm -rf ${chbench_path}/result
fi

mkdir $result_dir
url="jdbc:mysql:\/\/${host}:${port}\/$db_name?rewriteBatchedStatements=true"
tables="CUSTOMER ITEM HISTORY DISTRICT NEW_ORDER OORDER ORDER_LINE STOCK WAREHOUSE nation region supplier"

mysql --host ${host} --port $port -u root -e "create database if not exists $db_name"

cd ${chbench_path}

if [ "${br_storage}" != "" ]
then
  AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin br restore db --pd ${pd_host}:${pd_port} --db $db_name -s ${br_storage} --s3.endpoint http://minio.pingcap.net:9000 --send-credentials-to-tikv=true
  br_wait_table $db_name "$tables" "mysql --host $host --port $port -u root -e"
else
  echo br_storage should not be null.
  exit 1
fi
cat ${tpconfig} | sed "s/<scalefactor>.*<\/scalefactor>/<scalefactor>${sf}<\/scalefactor>/g" | sed "s/<url>.*<\/url>/<url>${url}<\/url>/g" | sed "s/<time>.*<\/time>/<time>${duration}<\/time>/g" > tp_config_temp.xml
java -jar ${jarfile} -b tpcc -c tp_config_temp.xml --create=false --load=false --execute=true -d $result_dir/outputfile_tidb_query_${query}_ap_${thread}_tp &

cat ${apconfig} | sed "s/<scalefactor>.*<\/scalefactor>/<scalefactor>${sf}<\/scalefactor>/g" | sed "s/<url>.*<\/url>/<url>${url}<\/url>/g" | sed "s/<time>.*<\/time>/<time>${duration}<\/time>/g" | sed "s/<name>.*<\/name>/<name>${query}<\/name>/g" | sed "s/<active_terminals bench=\"chbenchmark\">.*<\/active_terminals>/<active_terminals bench=\"chbenchmark\">${thread}<\/active_terminals>/g" | sed "s/<terminals>.*<\/terminals>/<terminals>${thread}<\/terminals>/g" > ap_config_temp.xml
java -jar ${jarfile} -b chbenchmark -c ap_config_temp.xml --create=false --load=false --execute=true -d $result_dir/outputfile_tidb_query_${query}_ap_${thread}_ap &
wait

rm -rf load_config_temp.xml
rm -rf ap_config_temp.xml
rm -rf tp_config_temp.xml
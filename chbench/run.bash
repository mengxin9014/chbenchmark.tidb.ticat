. "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../helper/helper.bash"

env_file="${1}/env"
env=`cat "${env_file}"`
shift
chbench_path=`must_env_val "${env}" 'chbench.chbench_path'`
sf=`must_env_val "${env}" 'chbench.scalefactor'`
host=`must_env_val "${env}" 'mysql.host'`
port=`must_env_val "${env}" 'mysql.port'`
user=`must_env_val "${env}" 'mysql.user'`

br_storage="${1}"

function wait_table()
{
  local database="$1"
  local tables="$2"
  local mysql_client="$3"
  local tiflash_replica=1

  for table in $tables
  do
    $mysql_client "alter table benchbase.$table set tiflash replica $tiflash_replica"
    $mysql_client "analyze table benchbase.$table"
  done
	python2 ${chbench_path}/scripts/wait_tiflash_table_available.py "$database" $tables "$mysql_client" ; return $?
}

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

loadconfig="${chbench_path}/config/tidb/chbenchmark_config_base.xml"
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
ap_threads="1 5 10 20 30"
url="jdbc:mysql:\/\/${host}:${port}\/benchbase?rewriteBatchedStatements=true"
tables="CUSTOMER ITEM HISTORY DISTRICT NEW_ORDER OORDER ORDER_LINE STOCK WAREHOUSE nation region supplier"

mysql --host ${host} --port $port -u root -e "create database if not exists benchbase"

cd ${chbench_path}

for ap in $ap_threads
do
  if [ ${ap} -ne 1 ]
  then
    querys="Q6 Q12 Q13 Q14"
  else
    querys="Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10 Q11 Q12 Q13 Q14 Q15 Q16 Q17 Q18 Q19 Q20 Q21 Q22"
  fi

  for query in $querys
  do
    if [ ${br_storage} != "" ]
    then
      AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin br restore db --pd 10.233.75.203:2379 --db benchbase ${br_storage} --s3.endpoint http://minio.pingcap.net:9000 --send-credentials-to-tikv=true
      br_wait_table benchbase "$tables" "mysql --host $host --port $port -u root -e"
    else
      cat  ${loadconfig} | sed "s/<scalefactor>.*<\/scalefactor>/<scalefactor>${sf}<\/scalefactor>/g" | sed "s/<url>.*<\/url>/<url>${url}<\/url>/g" > load_config_temp.xml
      java -jar ${jarfile} -b tpcc,chbenchmark -c load_config_temp.xml --create=true --load=true --execute=false
      wait_table benchbase "$tables" "mysql --host $host --port $port -u root -e"
    fi
    cat ${tpconfig} | sed "s/<scalefactor>.*<\/scalefactor>/<scalefactor>${sf}<\/scalefactor>/g" | sed "s/<url>.*<\/url>/<url>${url}<\/url>/g" > tp_config_temp.xml
    java -jar ${jarfile} -b tpcc -c tp_config_temp.xml --create=false --load=false --execute=true -d $result_dir/outputfile_tidb_query_${query}_ap_${ap}_tp &

  	cat ${apconfig} | sed "s/<scalefactor>.*<\/scalefactor>/<scalefactor>${sf}<\/scalefactor>/g" | sed "s/<url>.*<\/url>/<url>${url}<\/url>/g" | sed "s/<name>.*<\/name>/<name>${query}<\/name>/g" | sed "s/<active_terminals bench=\"chbenchmark\">.*<\/active_terminals>/<active_terminals bench=\"chbenchmark\">${ap}<\/active_terminals>/g" | sed "s/<terminals>.*<\/terminals>/<terminals>${ap}<\/terminals>/g" > ap_config_temp.xml
    java -jar ${jarfile} -b chbenchmark -c ap_config_temp.xml --create=false --load=false --execute=true -d $result_dir/outputfile_tidb_query_${query}_ap_${ap}_ap &
    wait
  done
done

rm -rf load_config_temp.xml
rm -rf ap_config_temp.xml
rm -rf tp_config_temp.xml
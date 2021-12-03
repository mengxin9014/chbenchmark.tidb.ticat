. "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../helper/helper.bash"

env_file="${1}/env"
env=`cat "${env_file}"`
shift

chbench_path=`must_env_val "${env}" 'chbench.chbench_path'`

query="${1}"
thread="${2}"
result_dir="${chbench_path}/result"
record_dir="${chbench_path}/record"

if [ -d "$record_dir" ]
then
	echo $record_dir already exists
	rm -rf ${chbench_path}/record
fi

mkdir $record_dir

rm -rf $record_dir/ch_benchmark_test.txt
rm -rf $record_dir/ch_benchmark_small_query_test.txt

echo -e "workload\tApAvgRT(μs)\tTpP99RT(μs)\tApQPS\tTPS" > $record_dir/ch_benchmark_test.txt
echo -e "\tQ6(QPS)\tQ12(QPS)\tQ13(QPS)\tQ14(QPS)" > $record_dir/ch_benchmark_small_query_test.txt

apThreads="1 5 10 20 30"
#for ap in $apThreads
#do
#  if [ ${ap} -ne 1 ]
#  then
#    querys="Q6 Q12 Q13 Q14"
#  else
#    querys="Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10 Q11 Q12 Q13 Q14 Q15 Q16 Q17 Q18 Q19 Q20 Q21 Q22"
#  fi
#
#  qps_line="${ap}_threads: "
#  for query in $querys
#  do
#    if [ ${ap} -ne 1 ]
#    then
#      qps=$(grep Throughput $result_dir/outputfile_tidb_query_${query}_ap_${ap}_ap/chbenchmark_*.summary.json | awk -F':' '{print $NF}')
#      qps_line="$qps_line$qps\t"
#    else
#      qps=$(grep Throughput $result_dir/outputfile_tidb_query_${query}_ap_${ap}_ap/chbenchmark_*.summary.json | awk -F':' '{print $NF}')
#      tps=$(grep Throughput $result_dir/outputfile_tidb_query_${query}_ap_${ap}_tp/tpcc_*.summary.json | awk -F':' '{print $NF}')
#      ap_avg_rt=$(grep "Average Latency" $result_dir/outputfile_tidb_query_${query}_ap_${ap}_ap/chbenchmark_*.summary.json | awk -F':' '{print $NF}')
#      tp_p99_rt=$(grep 99th $result_dir/outputfile_tidb_query_${query}_ap_${ap}_tp/tpcc_*.summary.json | awk -F':' '{print $NF}' | sed 's/,//g')
#
#      echo -e "$query\t$ap_avg_rt\t$tp_p99_rt\t$qps\t$tps" >> $record_dir/ch_benchmark_test.txt
#    fi
#   done
#   if [ ${ap} -ne 1 ]
#   then
#     echo -e $qps_line >> $record_dir/ch_benchmark_small_query_test.txt
#   fi
#done

if [ ${thread} -ne 1 ]
then
  qps=$(grep Throughput $result_dir/outputfile_tidb_query_${query}_ap_${thread}_ap/chbenchmark_*.summary.json | awk -F':' '{print $NF}')
  qps_line="$qps_line$qps\t"
else
  qps=$(grep Throughput $result_dir/outputfile_tidb_query_${query}_ap_${thread}_ap/chbenchmark_*.summary.json | awk -F':' '{print $NF}')
  tps=$(grep Throughput $result_dir/outputfile_tidb_query_${query}_ap_${thread}_tp/tpcc_*.summary.json | awk -F':' '{print $NF}')
  ap_avg_rt=$(grep "Average Latency" $result_dir/outputfile_tidb_query_${query}_ap_${thread}_ap/chbenchmark_*.summary.json | awk -F':' '{print $NF}')
  tp_p99_rt=$(grep 99th $result_dir/outputfile_tidb_query_${query}_ap_${thread}_tp/tpcc_*.summary.json | awk -F':' '{print $NF}' | sed 's/,//g')
  echo -e "$query\t$ap_avg_rt\t$tp_p99_rt\t$qps\t$tps" >> $record_dir/ch_benchmark_test.txt
fi

if [ ${thread} -ne 1 ]
then
  echo -e $qps_line >> $record_dir/ch_benchmark_small_query_test.txt
fi
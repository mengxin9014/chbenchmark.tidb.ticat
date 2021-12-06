. "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../helper/helper.bash"

env_file="${1}/env"
env=`cat "${env_file}"`
shift

chbench_path=`must_env_val "${env}" 'write_throughput.chbench_path'`
thread=`must_env_val "${env}" 'write_throughput.thread'`

result_dir="${chbench_path}/result"
record_dir="${chbench_path}/record"

if [ -d "$record_dir" ]
then
	echo $record_dir already exists
	rm -rf ${chbench_path}/record
fi

rm -rf $record_dir/write_throughput_test.txt

echo -e "thread\tApQPS\tRT_P99(μs)" > $record_dir/write_throughput_test.txt

qps=$(grep Throughput $result_dir/write_throughput_table_result/chbenchmark_*.summary.json | awk -F':' '{print $NF}')
p99_rt=$(grep 99th $result_dir/write_throughput_table_result/chbenchmark_*.summary.json | awk -F':' '{print $NF}' | sed 's/,//g')
echo -e "$thread\t$qps\t$p99_rt" >> $record_dir/write_throughput_test.txt
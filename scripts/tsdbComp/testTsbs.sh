time=`date +%Y_%m%d_%H%M%S`
echo "nohup bash tsdbComparison.sh  &> log/testAll_${time}.log   &"
echo "please check log/testAll_${time}.log to monitor the test "
mkdir -p log
nohup bash tsdbComparison.sh &> log/testAll_${time}.log   &
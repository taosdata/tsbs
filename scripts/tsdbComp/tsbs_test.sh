time=`date +%Y_%m%d_%H%M%S`
mkdir -p log

# set load_format、query_format and caseTypes in test.ini
function set_formats_and_caseTypes() {
    local load_formats=$1
    local query_formats=$2
    local case_types=$3
    sed -i "s/^load_formats=.*/load_formats=\"${load_formats}\"/" test.ini
    sed -i "s/^query_formats=.*/query_formats=\"${query_formats}\"/" test.ini
    sed -i "s/^caseTypes=.*/caseTypes=\"${case_types}\"/" test.ini
}

# Update the 'load_scales' value within the specified load section (either [Load] or [LoadTest])
# and manage the LoadTimeScale entries within the corresponding time scale section (either [LoadTimeScale] or [LoadTestTimeScale])
function set_load_scales_and_timeScale() {
    local ini_file="test.ini"
    local load_section=$1
    local load_time_scale_section=$2
    local load_scales=$3
    shift 3
    local new_timescales=("$@")

    # Replace the load_scales line in the [Load] or [LoadTest] section
    sed -i "/^\[${load_section}\]/,/^\[/{s|^load_scales=.*|load_scales=\"${load_scales}\"|}" "$ini_file"

    # Clear the contents of the [LoadTimeScale] or [LoadTestTimeScale] section, but keep the label
    sed -i "/^\[${load_time_scale_section}\]/,/^\[/{//!d;}" "$ini_file"

    # Add new LoadTimeScale configurations after the [LoadTimeScale] or [LoadTestTimeScale] label
    for ((i=${#new_timescales[@]}-1; i>=0; i--)); do
        if [ $i -eq $((${#new_timescales[@]}-1)) ]; then
            sed -i "/^\[${load_time_scale_section}\]/a ${new_timescales[i]}\n" "$ini_file"
        else
            sed -i "/^\[${load_time_scale_section}\]/a ${new_timescales[i]}" "$ini_file"
        fi
    done

}

# update [Query] or [QueryTest]
function set_query_section() {
    local ini_file="test.ini"
    local section=$1
    local new_query_ts_start=$2
    local new_query_load_ts_end=$3
    local new_query_ts_end=$4
    local new_query_cpu_scale_times=$5
    local new_query_iot_scale_times=$6

    # update query_ts_start
    sed -i "/^\[${section}\]/,/^\[/{s|^query_ts_start=.*|query_ts_start=\"${new_query_ts_start}\"|}" "$ini_file"

    # update query_load_ts_end
    sed -i "/^\[${section}\]/,/^\[/{s|^query_load_ts_end=.*|query_load_ts_end=\"${new_query_load_ts_end}\"|}" "$ini_file"

    # update query_ts_end
    sed -i "/^\[${section}\]/,/^\[/{s|^query_ts_end=.*|query_ts_end=\"${new_query_ts_end}\"|}" "$ini_file"

    # update query_cpu_scale_times
    if [[ -n "${new_query_cpu_scale_times}" ]]; then
        sed -i "/^\[${section}\]/,/^\[/{s|^query_cpu_scale_times=.*|query_cpu_scale_times=\"${new_query_cpu_scale_times}\"|}" "$ini_file"
    fi

    # update query_iot_scale_times
    if [[ -n "${new_query_iot_scale_times}" ]]; then
        sed -i "/^\[${section}\]/,/^\[/{s|^query_iot_scale_times=.*|query_iot_scale_times=\"${new_query_iot_scale_times}\"|}" "$ini_file"
    fi
}

function show_help() {
    echo "Usage: $0 -s <scenario>"
    echo "Available scenarios:"
    echo "  scenario1  - Load: TDengine vs influx vs timescaledb. Query: TDengine vs influx vs timescaledb, caseTypes: cpu-only and iot."
    echo "              Note: This scenario involves large datasets and requires high system resources. Suggested configuration:"
    echo "                    - Disk: > 500GB"
    echo "                    - Memory: > 128GB"
    echo "                    - CPU: > 24 cores"
    echo "  scenario2  - Load: TDengineStmt2 vs influx3 vs influx. Query: TDengineStmt2 vs influx3 vs influx, caseTypes: cpu-only and iot."
    echo "              Note: This scenario involves large datasets and requires high system resources. Suggested configuration:"
    echo "                    - Disk: > 500GB"
    echo "                    - Memory: > 128GB"
    echo "                    - CPU: > 24 cores"
    echo "  scenario3  - Quick Test. Load/Query: TDengineStmt2 vs influx3 vs influx vs timescaledb, caseTypes: cputest."
    echo "  scenario4  - Quick Test. Load/Query: TDengineStmt2 vs influx vs timescaledb, caseTypes: cputest."
    echo "  scenario5  - Quick Test. Load/Query: TDengineStmt2 vs influx3 vs influx, caseTypes: cputest."
    echo "  help       - Show this help message."
    echo "By default, scenario4 is used."
    echo "Example: $0 -s scenario1"
    echo "         $0 -s scenario2"
    echo "         $0 -s scenario3"
    echo "         $0 -s scenario4"
    echo "         $0 -s scenario5"
    echo "         $0"
    echo "         $0 -h"
    echo ""
    echo "Set test.ini manually for more config, then execute the command to start the test: nohup bash tsbs_comparison.sh > testAll_2025_0311_1500.log & "
    
}

scenario="scenario4"
while getopts ":s:h" opt; do
    case ${opt} in
        s)
            scenario=$OPTARG
            ;;
        h)
            show_help
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

case $scenario in
    "scenario1")
        echo "scenario1: Load: TDengine vs influx vs timescaledb. Query: TDengine vs influx vs timescaledb, caseTypes: cpu-only and iot."
        set_formats_and_caseTypes "TDengine influx timescaledb" "TDengine influx timescaledb" "cpu iot"
        set_load_scales_and_timeScale "Load" "LoadTimeScale" "100 4000 100000 1000000 10000000" \
            '100="2016-01-01T00:00:00Z 2016-02-01T00:00:00Z 10s"' \
            '4000="2016-01-01T00:00:00Z 2016-01-05T00:00:00Z 10s"' \
            '100000="2016-01-01T00:00:00Z 2016-01-01T03:00:00Z 10s"' \
            '1000000="2016-01-01T00:00:00Z 2016-01-01T00:03:00Z 10s"' \
            '10000000="2016-01-01T00:00:00Z 2016-01-01T00:03:00Z 10s"'   
        set_query_section "Query" "2016-01-01T00:00:00Z" "2016-01-05T00:00:00Z" "2016-01-05T00:00:01Z" "100,4000 4000,4000" "100,10000 4000,500"
        ;;
    "scenario2")
        echo "scenario2: Load: TDengineStmt2 vs influx3 vs influx. Query: TDengineStmt2 vs influx3 vs influx, caseTypes: cpu-only and iot."
        set_formats_and_caseTypes "TDengineStmt2 influx3 influx" "TDengineStmt2 influx3 influx" "cpu iot"
        set_load_scales_and_timeScale "Load" "LoadTimeScale" "100 4000 100000 1000000 10000000" \
            '100="2016-01-01T00:00:00Z 2016-01-03T00:00:00Z 10s"' \
            '4000="2016-01-01T00:00:00Z 2016-01-03T00:00:00Z 10s"' \
            '100000="2016-01-01T00:00:00Z 2016-01-01T03:00:00Z 10s"' \
            '1000000="2016-01-01T00:00:00Z 2016-01-01T00:03:00Z 10s"' \
            '10000000="2016-01-01T00:00:00Z 2016-01-01T00:03:00Z 10s"' 
        set_query_section "Query" "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z" "100,4000 4000,4000" "100,10000 4000,500"
        ;;
    "scenario3")
        echo "scenario3: Quick Test. Load/Query: TDengineStmt2 vs influx3 vs influx vs timescaledb."
        set_formats_and_caseTypes "TDengineStmt2 influx3 influx timescaledb" "TDengineStmt2 influx3 influx timescaledb" "cputest"
        set_load_scales_and_timeScale "LoadTest" "LoadTestTimeScale" "200" \
            '200="2016-01-01T00:00:00Z 2016-01-01T12:00:00Z 10s"'
        set_query_section "QueryTest" "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z" "100,100"
        ;;
    "scenario4")
        echo "scenario4: Quick Test. Load/Query: TDengineStmt2 vs influx vs timescaledb."
        set_formats_and_caseTypes "TDengineStmt2 influx timescaledb" "TDengineStmt2 influx timescaledb" "cputest"
        set_load_scales_and_timeScale "LoadTest" "LoadTestTimeScale" "200" \
            '200="2016-01-01T00:00:00Z 2016-01-01T12:00:00Z 10s"'
        set_query_section "QueryTest" "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z" "100,100"
        ;;
    "scenario5")
        echo "scenario5: Quick Test. Load/Query: TDengineStmt2 vs influx3 vs influx."
        set_formats_and_caseTypes "TDengineStmt2 influx3 influx" "TDengineStmt2 influx3 influx" "cputest"
        set_load_scales_and_timeScale "LoadTest" "LoadTestTimeScale" "200" \
            '200="2016-01-01T00:00:00Z 2016-01-01T12:00:00Z 10s"'
        set_query_section "QueryTest" "2016-01-01T00:00:00Z" "2016-01-02T00:00:00Z" "2016-01-02T00:00:01Z" "100,100"
        ;;
    *)
        echo "Unknown scenario: $scenario. Use '-h' to see available scenarios."
        exit 1
        ;;
esac

# run tsbs_comparison.sh
echo "nohup bash tsbs_comparison.sh &> log/testAll_${time}.log &"
echo "please check log/testAll_${time}.log to monitor the test"
nohup bash tsbs_comparison.sh &> log/testAll_${time}.log &
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

function show_help() {
    echo "Usage: $0 -s <scenario>"
    echo "Available scenarios:"
    echo "  scenario1  - Load: TDengine vs influx vs timescaledb. Query: TDengine vs influx vs timescaledb, caseTypes: cpu-only and iot."
    echo "  scenario2  - Load: TDengineStmt2 vs influx3 vs influx. Query: TDengineStmt2 vs influx3 vs influx, caseTypes: cpu-only and iot."
    echo "  scenario3  - Quick Test. Load/Query: TDengineStmt2 vs influx3 vs influx vs timescaledb, caseTypes: cputest."
    echo "  scenario4  - Quick Test. Load/Query: TDengineStmt2 vs influx vs timescaledb, caseTypes: cputest."
    echo "  help       - Show this help message."
    echo "By default, scenario3 is used."
    echo "Example: $0 -s scenario1"
    echo "         $0 -s scenario2"
    echo "         $0 -s scenario3"
    echo "         $0 -s scenario4"
    echo "         $0"
    echo "         $0 -h"
    echo ""
    echo "Set test.ini manually for more config, then execute the command to start the test: nohup bash tsbs_comparison.sh > testAll_2025_0311_1500.log & "
    
}

scenario="scenario3"
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
        ;;
    "scenario2")
        echo "scenario2: Load: TDengineStmt2 vs influx3 vs influx. Query: TDengineStmt2 vs influx3 vs influx, caseTypes: cpu-only and iot."
        set_formats_and_caseTypes "TDengineStmt2 influx3 influx" "TDengineStmt2 influx3 influx" "cpu iot"
        ;;
    "scenario3")
        echo "scenario3: Quick Test. Load/Query: TDengineStmt2 vs influx3 vs influx vs timescaledb."
        set_formats_and_caseTypes "TDengineStmt2 influx3 influx timescaledb" "TDengineStmt2 influx3 influx timescaledb" "cputest"
        ;;
    "scenario4")
        echo "scenario4: Quick Test. Load/Query: TDengineStmt2 vs influx vs timescaledb."
        set_formats_and_caseTypes "TDengineStmt2 influx timescaledb" "TDengineStmt2 influx timescaledb" "cputest"
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
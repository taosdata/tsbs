package main

import (
	"fmt"
	"log"
	"os"
	"runtime/pprof"

	"github.com/blagojts/viper"
	"github.com/spf13/pflag"
	"github.com/taosdata/tsbs/internal/utils"
	"github.com/taosdata/tsbs/pkg/query"
	"github.com/taosdata/tsbs/pkg/targets/tdenginerest/connector"
)

var (
	user   string
	pass   string
	host   string
	port   int
	runner *query.BenchmarkRunner
)

func init() {
	var config query.BenchmarkRunnerConfig
	config.AddToFlagSet(pflag.CommandLine)

	pflag.String("user", "root", "User to connect to TDengine")
	pflag.String("pass", "taosdata", "Password for the user connecting to TDengine")
	pflag.String("host", "localhost", "taosAdapter host")
	pflag.Int("port", 6041, "taosAdapter Port")
	pflag.Parse()
	err := utils.SetupConfigFile()

	if err != nil {
		panic(fmt.Errorf("fatal error config file: %s", err))
	}
	if err := viper.Unmarshal(&config); err != nil {
		panic(fmt.Errorf("unable to decode config: %s", err))
	}
	user = viper.GetString("user")
	pass = viper.GetString("pass")
	host = viper.GetString("host")
	port = viper.GetInt("port")
	runner = query.NewBenchmarkRunner(config)
}
func main() {
	f, err := os.Create("./cpu.prof")
	if err != nil {
		log.Fatal("could not create CPU profile: ", err)
	}
	if err := pprof.StartCPUProfile(f); err != nil {
		log.Fatal("could not start CPU profile: ", err)
	}
	defer pprof.StopCPUProfile()
	runner.Run(&query.TDenginePool, newProcessor)
}

type queryExecutorOptions struct {
	debug         bool
	printResponse bool
}

type processor struct {
	db       *connector.TaosConn
	opts     *queryExecutorOptions
	lastData []byte
}

func (p *processor) Init(workerNum int) {
	dbName := runner.DatabaseName()
	dsn := fmt.Sprintf("%s:%s@http(%s:%d)/%s", user, pass, host, port, dbName)
	p.db = mustConnect(dsn)
	p.opts = &queryExecutorOptions{
		debug:         runner.DebugLevel() > 0,
		printResponse: runner.DoPrintResponses(),
	}
	p.lastData = make([]byte, 0, 4<<10)
}

func (p *processor) ProcessQuery(q query.Query, _ bool) ([]*query.Stat, error) {
	tq := q.(*query.TDengine)
	qry := tq.SqlQuery
	if p.opts.debug {
		fmt.Println(string(qry))
	}
	var took float64
	var err error
	p.lastData = p.lastData[:0]
	took, p.lastData, err = p.db.TaosQuery(nil, qry, p.lastData)
	if err != nil {
		return nil, err
	}
	if p.opts.printResponse {
		fmt.Println(string(p.lastData))
	}
	stat := query.GetStat()
	stat.Init(q.HumanLabelName(), took)

	return []*query.Stat{stat}, err
}

func newProcessor() query.Processor { return &processor{} }

func mustConnect(dsn string) *connector.TaosConn {
	db, err := connector.NewTaosConn(dsn)
	if err != nil {
		panic(err)
	}
	return db
}

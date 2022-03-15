package main

import (
	"database/sql/driver"
	"fmt"
	"time"

	"github.com/blagojts/viper"
	"github.com/spf13/pflag"
	"github.com/timescale/tsbs/internal/utils"
	"github.com/timescale/tsbs/pkg/query"
	"github.com/timescale/tsbs/pkg/targets/tdengine/async"
	"github.com/timescale/tsbs/pkg/targets/tdengine/commonpool"
)

var (
	user   string
	pass   string
	runner *query.BenchmarkRunner
)

func init() {
	var config query.BenchmarkRunnerConfig
	config.AddToFlagSet(pflag.CommandLine)

	pflag.String("user", "postgres", "User to connect to TDengine as")
	pflag.String("pass", "", "Password for the user connecting to TDengine")
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
	runner = query.NewBenchmarkRunner(config)
}
func main() {
	runner.Run(&query.TDenginePool, newProcessor)
}

type queryExecutorOptions struct {
	debug         bool
	printResponse bool
}

type processor struct {
	db   *commonpool.Conn
	opts *queryExecutorOptions
}

func (p *processor) Init(workerNum int) {
	async.Init()
	db, err := commonpool.GetConnection(user, pass)
	if err != nil {
		panic(err)
	}
	dbName := runner.DatabaseName()
	err = async.GlobalAsync.TaosExecWithoutResult(db.TaosConnection, "use "+dbName)
	if err != nil {
		panic(err)
	}
	p.db = db
	p.opts = &queryExecutorOptions{
		debug:         runner.DebugLevel() > 0,
		printResponse: runner.DoPrintResponses(),
	}
	fmt.Println(p.opts)
}

func (p *processor) ProcessQuery(q query.Query, _ bool) ([]*query.Stat, error) {
	tq := q.(*query.TDengine)

	start := time.Now()
	qry := string(tq.SqlQuery)
	if p.opts.debug {
		fmt.Println(qry)
	}
	data, err := async.GlobalAsync.TaosExec(p.db.TaosConnection, qry, func(ts int64, precision int) driver.Value {
		return ts
	})
	if err != nil {
		return nil, err
	}
	if p.opts.printResponse {
		fmt.Printf("%#v\n", data)
	}
	took := float64(time.Since(start).Nanoseconds()) / 1e6
	stat := query.GetStat()
	stat.Init(q.HumanLabelName(), took)

	return []*query.Stat{stat}, err
}

func newProcessor() query.Processor { return &processor{} }

package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/blagojts/viper"
	"github.com/pkg/errors"
	"github.com/spf13/pflag"
	_ "github.com/taosdata/driver-go/v3/taosRestful"
	"github.com/taosdata/tsbs/internal/utils"
	"github.com/taosdata/tsbs/pkg/query"
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
	runner.Run(&query.TDenginePool, newProcessor)
}

type queryExecutorOptions struct {
	debug         bool
	printResponse bool
}

type processor struct {
	db   *sql.DB
	opts *queryExecutorOptions
}

func (p *processor) Init(workerNum int) {

	dbName := runner.DatabaseName()
	dsn := fmt.Sprintf("%s:%s@http(%s:%d)/%s", user, pass, host, port, dbName)
	p.db = mustConnect(dsn)
	p.opts = &queryExecutorOptions{
		debug:         runner.DebugLevel() > 0,
		printResponse: runner.DoPrintResponses(),
	}
}

func (p *processor) ProcessQuery(q query.Query, _ bool) ([]*query.Stat, error) {
	tq := q.(*query.TDengine)

	start := time.Now()
	qry := string(tq.SqlQuery)
	if p.opts.debug {
		fmt.Println(qry)
	}
	querys := strings.Split(qry, ";")
	if len(querys) > 1 {
		var preQuerys []string
		for i := 0; i < len(querys); i++ {
			if len(querys[i]) > 0 {
				preQuerys = append(preQuerys, querys[i])
			}
		}
		if len(preQuerys) > 1 {
			for i := 0; i < len(preQuerys)-1; i++ {
				err := execWithoutResult(p.db, preQuerys[i])
				if err != nil {
					return nil, err
				}
			}
		}
		qry = querys[len(preQuerys)-1]
	}
	rows, err := p.db.Query(qry)
	if err != nil {
		return nil, err
	}
	if p.opts.printResponse {
		prettyPrintResponse(rows, tq)
	}
	for rows.Next() {
	}
	rows.Close()
	took := float64(time.Since(start).Nanoseconds()) / 1e6
	stat := query.GetStat()
	stat.Init(q.HumanLabelName(), took)

	return []*query.Stat{stat}, err
}

func newProcessor() query.Processor { return &processor{} }

func mustConnect(dsn string) *sql.DB {
	db, err := sql.Open("taosRestful", dsn)
	if err != nil {
		panic(err)
	}
	return db
}

func execWithoutResult(db *sql.DB, sql string) error {
	_, err := db.Exec(sql)
	return err
}

// prettyPrintResponse prints a Query and its response in JSON format with two
// keys: 'query' which has a value of the SQL used to generate the second key
// 'results' which is an array of each row in the return set.
func prettyPrintResponse(rows *sql.Rows, q *query.TDengine) {
	resp := make(map[string]interface{})
	resp["query"] = string(q.SqlQuery)
	resp["results"] = mapRows(rows)

	line, err := json.MarshalIndent(resp, "", "  ")
	if err != nil {
		panic(err)
	}

	fmt.Println(string(line) + "\n")
}

func mapRows(r *sql.Rows) []map[string]interface{} {
	rows := []map[string]interface{}{}
	cols, _ := r.Columns()
	for r.Next() {
		row := make(map[string]interface{})
		values := make([]interface{}, len(cols))
		for i := range values {
			values[i] = new(interface{})
		}

		err := r.Scan(values...)
		if err != nil {
			panic(errors.Wrap(err, "error while reading values"))
		}

		for i, column := range cols {
			row[column] = *values[i].(*interface{})
		}
		rows = append(rows, row)
	}
	return rows
}

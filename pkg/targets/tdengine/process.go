package tdengine

import (
	"fmt"
	"strings"

	tErrors "github.com/taosdata/driver-go/v2/errors"
	"github.com/timescale/tsbs/pkg/targets"
	"github.com/timescale/tsbs/pkg/targets/tdengine/async"
	"github.com/timescale/tsbs/pkg/targets/tdengine/commonpool"
)

type insertData struct {
	tbName string
	tags   string
	fields string
}
type processor struct {
	opts   *LoadingOptions
	dbName string
	_db    *commonpool.Conn
}

func newProcessor(opts *LoadingOptions, dbName string) *processor {
	return &processor{opts: opts, dbName: dbName}
}

func (p *processor) Init(_ int, doLoad, _ bool) {
	if !doLoad {
		return
	}
	var err error
	p._db, err = commonpool.GetConnection(p.opts.User, p.opts.Pass, p.opts.Host, p.opts.Port)
	if err != nil {
		panic(err)
	}
	err = async.GlobalAsync.TaosExecWithoutResult(p._db.TaosConnection, "use "+p.dbName)
	if err != nil {
		panic(err)
	}
}

func (p *processor) ProcessBatch(b targets.Batch, doLoad bool) (metricCount, rowCount uint64) {
	batches := b.(*hypertableArr)
	rowCnt := 0
	metricCnt := uint64(0)
	for hypertable, rows := range batches.m {
		rowCnt += len(rows)
		if doLoad {
			metricCnt += p.processCSI(hypertable, rows)
		}
	}
	batches.m = map[string][]*insertData{}
	batches.cnt = 0
	return metricCnt, uint64(rowCnt)
}

func (p *processor) Close(doLoad bool) {
	if doLoad {
		p._db.Put()
	}
}

func (p *processor) processCSI(hypertable string, rows []*insertData) uint64 {
	numMetrics := uint64(0)
	for _, row := range rows {
		metrics := strings.Split(row.fields, ",")
		numMetrics += uint64(len(metrics) - 1)

		var fieldKeys []string
		var fieldValues []string
		for _, pair := range metrics {
			field := strings.Split(pair, "=")
			switch aType(field[1]) {
			case Null:
				continue
			default:
				fieldKeys = append(fieldKeys, field[0])
				fieldValues = append(fieldValues, field[1])
			}
		}
		tagPairs := strings.Split(row.tags, ",")
		var tagValues []string
		var tagKeys []string
		for _, pair := range tagPairs {
			tag := strings.Split(pair, "=")
			switch aType(tag[1]) {
			case Null:
				continue
			case StringType:
				tagKeys = append(tagKeys, tag[0])
				tagValues = append(tagValues, tag[1])
			case NumberType:
				fieldKeys = append(fieldKeys, tag[0])
				fieldValues = append(fieldValues, tag[1])
			}
		}
		//insert into %s using %s (%s) tags (%s) (%s) values (%s)
		sql := fmt.Sprintf("insert into %s using %s (%s) tags (%s) (%s) values (%s)", row.tbName, hypertable, strings.Join(tagKeys, ","), strings.Join(tagValues, ","), strings.Join(fieldKeys, ","), strings.Join(fieldValues, ","))
		err := async.GlobalAsync.TaosExecWithoutResult(p._db.TaosConnection, sql)
		if err != nil {
			e := err.(*tErrors.TaosError)
			switch e.Code {
			case tErrors.MND_INVALID_TABLE_NAME:
				createTableSql := fmt.Sprintf("create table %s (ts timestamp,%s double) tags (%s binary(128))", hypertable, strings.Join(fieldKeys[1:], " double,"), strings.Join(tagKeys, " binary(128),"))
				_ = async.GlobalAsync.TaosExecWithoutResult(p._db.TaosConnection, createTableSql)
			case tErrors.TSC_INVALID_OPERATION:
				//todo
			}
			err = async.GlobalAsync.TaosExecWithoutResult(p._db.TaosConnection, sql)
			if err != nil {
				fmt.Println(sql)
				panic(err)
			}
		}

	}
	return numMetrics
}

const (
	StringType = iota + 1
	NumberType
	Null
)

func aType(v string) int {
	switch v[0] {
	case '\'':
		return StringType
	case 'n':
		return Null
	default:
		return NumberType
	}
}

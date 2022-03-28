package tdenginesml

import (
	"bytes"

	"github.com/taosdata/driver-go/v2/wrapper"
	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/async"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/commonpool"
)

type processor struct {
	opts   *LoadingOptions
	dbName string
	buf    *bytes.Buffer
	_db    *commonpool.Conn
}

func newProcessor(opts *LoadingOptions, dbName string) *processor {
	return &processor{opts: opts, dbName: dbName, buf: &bytes.Buffer{}}
}
func (p *processor) Init(workerNum int, doLoad, _ bool) {
	if !doLoad {
		return
	}
	p.buf.Grow(4 * 1024 * 1024)
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
	batch := b.(*batch)
	metricCnt := batch.metrics
	rowCnt := batch.rows
	if doLoad {
		result := wrapper.TaosSchemalessInsert(p._db.TaosConnection, batch.lines, wrapper.InfluxDBLineProtocol, "ns")
		code := wrapper.TaosError(result)
		if code != 0 {
			errStr := wrapper.TaosErrorStr(result)
			wrapper.TaosFreeResult(result)
			fatal("schemaless error %d %s %#v", code, errStr, batch.lines)
		}
		wrapper.TaosFreeResult(result)
	}
	return metricCnt, uint64(rowCnt)
}

func (p *processor) Close(doLoad bool) {
	if doLoad {
		p._db.Put()
	}
}

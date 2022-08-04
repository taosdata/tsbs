package tdengine

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"unsafe"

	"github.com/taosdata/driver-go/v3/errors"
	taosTypes "github.com/taosdata/driver-go/v3/types"
	"github.com/taosdata/driver-go/v3/wrapper"
	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/async"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/commonpool"
)

type syncCSI struct {
	m sync.Map //table:ctx
}

type Ctx struct {
	c      context.Context
	cancel context.CancelFunc
}

var globalSCI = &syncCSI{}

var stableTypesLocker = sync.RWMutex{}
var stableTypes = map[string][]*taosTypes.ColumnType{}

//var subTableFieldMap = map[string]int{} //sub table : column count
//var subTableStableMap = map[string]string{}
var subTableStableMap = sync.Map{}

type processor struct {
	stmts  map[int]unsafe.Pointer
	opts   *LoadingOptions
	dbName string
	sci    *syncCSI
	_db    *commonpool.Conn
	wg     *sync.WaitGroup
}

func newProcessor(opts *LoadingOptions, dbName string) *processor {
	return &processor{opts: opts, dbName: dbName, sci: globalSCI, wg: &sync.WaitGroup{}, stmts: map[int]unsafe.Pointer{}}
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
	rowCnt := uint64(0)
	metricCnt := batches.totalMetric
	if !doLoad {
		for _, sqls := range batches.m {
			rowCnt += uint64(len(sqls))
		}
		return metricCnt, rowCnt
	}
	for _, row := range batches.createSql {
		switch row.sqlType {
		case CreateSTable:
			c, cancel := context.WithCancel(context.Background())
			ctx := &Ctx{
				c:      c,
				cancel: cancel,
			}
			actual, _ := p.sci.m.LoadOrStore(row.superTable, ctx)
			err := async.GlobalAsync.TaosExecWithoutResult(p._db.TaosConnection, row.sql)
			if err != nil {
				fmt.Println(row.sql)
				panic(err)
			}
			GlobalTable.Store(row.subTable, nothing)
			actual.(*Ctx).cancel()
		case CreateSubTable:
			c, cancel := context.WithCancel(context.Background())
			ctx := &Ctx{
				c:      c,
				cancel: cancel,
			}
			actual, _ := p.sci.m.LoadOrStore(row.subTable, ctx)

			//check super table created
			_, ok := GlobalTable.Load(row.superTable)
			if !ok {
				v, ok := p.sci.m.Load(row.superTable)
				if ok {
					<-v.(*Ctx).c.Done()
					err := async.GlobalAsync.TaosExecWithoutResult(p._db.TaosConnection, row.sql)
					if err != nil {
						fmt.Println(row.sql)
						panic(err)
					}
					GlobalTable.Store(row.subTable, nothing)
					actual.(*Ctx).cancel()
					continue
				}
				// wait for super table created
				superTableC, superTableCancel := context.WithCancel(context.Background())
				superTableCtx := &Ctx{
					c:      superTableC,
					cancel: superTableCancel,
				}
				superTableActual, _ := p.sci.m.LoadOrStore(row.superTable, superTableCtx)
				<-superTableActual.(*Ctx).c.Done()

			}
			err := async.GlobalAsync.TaosExecWithoutResult(p._db.TaosConnection, row.sql)
			if err != nil {
				fmt.Println(row.sql)
				panic(err)
			}
			GlobalTable.Store(row.subTable, nothing)
			actual.(*Ctx).cancel()
		default:
			panic("impossible")
		}
	}
	p.wg.Add(len(batches.m))
	for tableName := range batches.m {
		tableName := tableName
		go func() {
			defer p.wg.Done()
			_, ok := GlobalTable.Load(tableName)
			if ok {
				return
			}
			v, ok := p.sci.m.Load(tableName)
			if ok {
				<-v.(*Ctx).c.Done()
				return
			}
			c, cancel := context.WithCancel(context.Background())
			ctx := &Ctx{
				c:      c,
				cancel: cancel,
			}
			actual, _ := p.sci.m.LoadOrStore(tableName, ctx)
			<-actual.(*Ctx).c.Done()
			return
		}()
	}
	p.wg.Wait()
	usingStmt := map[int]unsafe.Pointer{}
	for tableName, colData := range batches.m {
		sv, _ := subTableStableMap.Load(tableName)
		stableName := sv.(string)
		stableTypesLocker.RLock()
		colTypes := stableTypes[stableName]
		stableTypesLocker.RUnlock()
		columnCount := len(colTypes)
		stmt, exist := p.stmts[columnCount]
		if !exist {
			stmt = wrapper.TaosStmtInit(p._db.TaosConnection)
			builder := &strings.Builder{}
			builder.WriteString("insert into ? values(")
			for i := 0; i < columnCount; i++ {
				builder.WriteByte('?')
				if i != columnCount-1 {
					builder.WriteByte(',')
				}
			}
			builder.WriteByte(')')
			code := wrapper.TaosStmtPrepare(stmt, builder.String())
			if code != 0 {
				errStr := wrapper.TaosStmtErrStr(stmt)
				panic(errors.NewError(code, errStr))
			}
			p.stmts[columnCount] = stmt
		}
		usingStmt[columnCount] = stmt
		rowCnt += uint64(len(colData[0]))
		code := wrapper.TaosStmtSetTBName(stmt, tableName)
		if code != 0 {
			errStr := wrapper.TaosStmtErrStr(stmt)
			panic(errors.NewError(code, errStr))
		}

		code = wrapper.TaosStmtBindParamBatch(stmt, colData, colTypes)
		if code != 0 {
			errStr := wrapper.TaosStmtErrStr(stmt)
			panic(errors.NewError(code, errStr))
		}
		code = wrapper.TaosStmtAddBatch(stmt)
		if code != 0 {
			errStr := wrapper.TaosStmtErrStr(stmt)
			panic(errors.NewError(code, errStr))
		}
	}
	for _, stmt := range usingStmt {
		code := wrapper.TaosStmtExecute(stmt)
		if code != 0 {
			errStr := wrapper.TaosStmtErrStr(stmt)
			panic(errors.NewError(code, errStr))
		}
	}
	batches.Reset()
	return metricCnt, rowCnt
}

func (p *processor) Close(doLoad bool) {
	if p._db != nil {
		p._db.Put()
	}
	for _, stmt := range p.stmts {
		wrapper.TaosStmtClose(stmt)
	}
}

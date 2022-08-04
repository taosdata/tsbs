package tdengine

import (
	"database/sql/driver"
	"strconv"
	"strings"
	"sync"
	"time"

	taosTypes "github.com/taosdata/driver-go/v3/types"
	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/targets"
)

// indexer is used to consistently send the same hostnames to the same worker
type indexer struct {
	partitions uint
	index      uint
	tmp        map[string]uint
}

func (i *indexer) GetIndex(item data.LoadedPoint) uint {
	p := item.Data.(*point)
	switch p.sqlType {
	case CreateSTable:
		fallthrough
	case CreateSubTable:
		fallthrough
	case Insert:
		idx, exist := i.tmp[p.subTable]
		if exist {
			return idx
		}
		i.index += 1
		idx = i.index % i.partitions
		i.tmp[p.subTable] = idx
		return idx
	default:
		return 0
	}
}

// point is a single row of data keyed by which superTable it belongs
type point struct {
	sqlType    byte
	superTable string
	subTable   string
	fieldCount int
	sql        string
	values     string
}

var GlobalTable = sync.Map{}

type hypertableArr struct {
	createSql   []*point
	m           map[string][][]driver.Value
	totalMetric uint64
	cnt         uint
}

func (ha *hypertableArr) Len() uint {
	return ha.cnt
}

func (ha *hypertableArr) Append(item data.LoadedPoint) {
	that := item.Data.(*point)
	if that.sqlType == Insert {
		sv, _ := subTableStableMap.Load(that.subTable)
		stableName := sv.(string)
		stableTypesLocker.RLock()
		colTypes := stableTypes[stableName]
		stableTypesLocker.RUnlock()
		columnCount := len(colTypes)
		if _, exist := ha.m[that.subTable]; !exist {
			ha.m[that.subTable] = make([][]driver.Value, columnCount)
		}
		vs := strings.Split(that.values, ",")
		for i := 0; i < columnCount; i++ {
			var v driver.Value
			if vs[i] == "null" {
				v = nil
			} else {
				switch colTypes[i].Type {
				case taosTypes.TaosBigintType:
					vv, err := strconv.ParseInt(vs[i], 10, 64)
					if err != nil {
						panic(err)
					}
					v = taosTypes.TaosBigint(vv)
				case taosTypes.TaosTimestampType:
					vv, err := strconv.ParseInt(vs[i], 10, 64)
					if err != nil {
						panic(err)
					}
					v = taosTypes.TaosTimestamp{
						T: time.Unix(0, vv*1e6),
					}
				case taosTypes.TaosDoubleType:
					vv, err := strconv.ParseFloat(vs[i], 64)
					if err != nil {
						panic(err)
					}
					v = taosTypes.TaosDouble(vv)
				case taosTypes.TaosBinaryType:
					v = taosTypes.TaosBinary(vs[i])
				case taosTypes.TaosBoolType:
					vv, err := strconv.ParseBool(vs[i])
					if err != nil {
						panic(err)
					}
					v = taosTypes.TaosBool(vv)
				}
			}
			ha.m[that.subTable][i] = append(ha.m[that.subTable][i], v)
		}
		ha.totalMetric += uint64(that.fieldCount)
		ha.cnt++
	} else {
		ha.createSql = append(ha.createSql, that)
	}
}

func (ha *hypertableArr) Reset() {
	ha.m = map[string][][]driver.Value{}
	ha.cnt = 0
	ha.createSql = ha.createSql[:0]
}

type factory struct{}

func (f *factory) New() targets.Batch {
	return &hypertableArr{
		m:   map[string][][]driver.Value{},
		cnt: 0,
	}
}

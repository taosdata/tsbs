package tdengine

import (
	"database/sql/driver"
	"sync"

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
	switch p.SqlType {
	case CreateSTable:
		fallthrough
	case CreateSubTable:
		fallthrough
	case Insert:
		idx, exist := i.tmp[p.SubTable]
		if exist {
			return idx
		}
		i.index += 1
		idx = i.index % i.partitions
		i.tmp[p.SubTable] = idx
		return idx
	default:
		return 0
	}
}

// point is a single row of data keyed by which SuperTable it belongs
type point struct {
	SqlType    byte
	SuperTable string
	SubTable   string
	Sql        string
	Types      []byte
	Values     []driver.Value
}

var GlobalTable = sync.Map{}

type hypertableArr struct {
	createSql   []*point
	m           map[string][][]driver.Value
	t           map[string][]byte
	totalMetric uint64
	cnt         uint
}

func (ha *hypertableArr) Len() uint {
	return ha.cnt
}

func (ha *hypertableArr) Append(item data.LoadedPoint) {
	p := item.Data.(*point)
	if p.SqlType == Insert {
		if _, exist := ha.t[p.SubTable]; !exist {
			ha.t[p.SubTable] = p.Types
		}
		ha.m[p.SubTable] = append(ha.m[p.SubTable], p.Values)
		ha.totalMetric += uint64(len(p.Values) - 1)
		ha.cnt++
	} else {
		ha.createSql = append(ha.createSql, p)
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
		t:   map[string][]byte{},
		cnt: 0,
	}
}

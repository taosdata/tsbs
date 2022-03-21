package tdengine

import (
	"sync"

	"github.com/timescale/tsbs/pkg/data"
	"github.com/timescale/tsbs/pkg/targets"
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
}

var GlobalTable = sync.Map{}

type hypertableArr struct {
	createSql   []*point
	m           map[string][]string
	totalMetric uint64
	cnt         uint
}

func (ha *hypertableArr) Len() uint {
	return ha.cnt
}

func (ha *hypertableArr) Append(item data.LoadedPoint) {
	that := item.Data.(*point)
	if that.sqlType == Insert {
		ha.m[that.subTable] = append(ha.m[that.subTable], that.sql)
		ha.totalMetric += uint64(that.fieldCount)
		ha.cnt++
	} else {
		ha.createSql = append(ha.createSql, that)
	}
}

func (ha *hypertableArr) Reset() {
	ha.m = map[string][]string{}
	ha.cnt = 0
	ha.createSql = ha.createSql[:0]
}

type factory struct{}

func (f *factory) New() targets.Batch {
	return &hypertableArr{
		m:   map[string][]string{},
		cnt: 0,
	}
}

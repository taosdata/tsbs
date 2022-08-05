package tdengine

import (
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
	case Insert, CreateSTable, CreateSubTable:
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
	Values     string
	Metrics    int
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
	p := item.Data.(*point)
	if p.SqlType == Insert {
		ha.m[p.SubTable] = append(ha.m[p.SubTable], p.Values)
		ha.totalMetric += uint64(p.Metrics)
		ha.cnt++
	} else {
		ha.createSql = append(ha.createSql, p)
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

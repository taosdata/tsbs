package tdenginestmt2

import (
	"bytes"
	"fmt"
	"sync"

	"github.com/spaolacci/murmur3"
	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/targets"
)

// indexer is used to consistently send the same hostnames to the same worker
type indexer struct {
	cache [3][]uint
}

func NewIndexer(prefix []byte, partitions int, hashEndGroups []uint32, useCase byte, scale uint32) *indexer {
	cache := [3][]uint{}
	buf := &bytes.Buffer{}
	switch useCase {
	case CpuCase:
		cache[SuperTableHost] = make([]uint, scale+1)
		tbPrefix := append(prefix, []byte("host_")...)
		for i := uint32(0); i < scale; i++ {
			buf.Write(tbPrefix)
			_, err := fmt.Fprintf(buf, "%d", i)
			if err != nil {
				panic(err)
			}
			hash := murmur3.Sum32WithSeed(buf.Bytes(), 0x12345678)
			buf.Reset()
			for j := 0; j < partitions; j++ {
				if hash <= hashEndGroups[j] {
					cache[SuperTableHost][i+1] = uint(j)
					break
				}
			}
		}
	case IoTCase:
		cache[SuperTableReadings] = make([]uint, scale+1)
		tbPrefix := append(prefix, []byte("r_truck_")...)
		for i := uint32(0); i < scale; i++ {
			buf.Write(tbPrefix)
			_, err := fmt.Fprintf(buf, "%d", i)
			if err != nil {
				panic(err)
			}
			hash := murmur3.Sum32WithSeed(buf.Bytes(), 0x12345678)
			buf.Reset()
			for j := 0; j < partitions; j++ {
				if hash <= hashEndGroups[j] {
					cache[SuperTableReadings][i+1] = uint(j)
					break
				}
			}
		}
		cache[SuperTableDiagnostics] = make([]uint, scale+1)
		tbPrefix = append(prefix, []byte("d_truck_")...)
		for i := uint32(0); i < scale; i++ {
			buf.Write(tbPrefix)
			_, err := fmt.Fprintf(buf, "%d", i)
			if err != nil {
				panic(err)
			}
			hash := murmur3.Sum32WithSeed(buf.Bytes(), 0x12345678)
			buf.Reset()
			for j := 0; j < partitions; j++ {
				if hash <= hashEndGroups[j] {
					cache[SuperTableDiagnostics][i+1] = uint(j)
					break
				}
			}
		}
	default:
		fatal("invalid use case: %d", useCase)
	}
	return &indexer{
		cache: cache,
	}
}

func (i *indexer) GetIndex(item data.LoadedPoint) uint {
	p := item.Data.(*point)
	return i.cache[p.tableType][p.tableIndex]
}

type point struct {
	commandType byte
	tableType   byte
	tableIndex  uint32
	duplicate   bool
	data        []byte
}

var pointPool = sync.Pool{
	New: func() interface{} {
		return &point{}
	},
}

func getPoint() *point {
	return pointPool.Get().(*point)
}

func putPoint(p *point) {
	p.data = nil
	pointPool.Put(p)
}

type hypertableArr struct {
	createSql   []*point
	data        [3]map[uint32][][]byte
	totalMetric uint64
	cnt         uint
}

func (ha *hypertableArr) Len() uint {
	return ha.cnt
}

func (ha *hypertableArr) Append(item data.LoadedPoint) {
	p := item.Data.(*point)
	if p.commandType == InsertData {
		switch p.tableType {
		case SuperTableHost:
			if !p.duplicate {
				ha.data[SuperTableHost][p.tableIndex] = append(ha.data[SuperTableHost][p.tableIndex], p.data)
			}
			ha.totalMetric += 10
		case SuperTableReadings:
			if !p.duplicate {
				ha.data[SuperTableReadings][p.tableIndex] = append(ha.data[SuperTableReadings][p.tableIndex], p.data)
			}
			ha.totalMetric += 7
		case SuperTableDiagnostics:
			if !p.duplicate {
				ha.data[SuperTableDiagnostics][p.tableIndex] = append(ha.data[SuperTableDiagnostics][p.tableIndex], p.data)
			}
			ha.totalMetric += 3
		default:
			fatal("invalid table type:%d", p.tableType)
		}
		ha.cnt++
		putPoint(p)
	} else {
		ha.createSql = append(ha.createSql, p)
	}
}

func (ha *hypertableArr) reset() {
	for i := 0; i < 3; i++ {
		for _, rows := range ha.data[i] {
			for j := 0; j < len(rows); j++ {
				bytesPool.Put(rows[j])
			}
		}
		ha.data[i] = make(map[uint32][][]byte)
	}
	ha.cnt = 0
	ha.totalMetric = 0
	ha.createSql = ha.createSql[:0]
}

type BatchFactory struct {
	pool *sync.Pool
}

func (b *BatchFactory) New() targets.Batch {
	return b.pool.Get().(*hypertableArr)
}

func NewBatchFactory(useCase byte) *BatchFactory {
	switch useCase {
	case CpuCase:
		pool := &sync.Pool{New: func() interface{} {
			return &hypertableArr{
				data: [3]map[uint32][][]byte{
					make(map[uint32][][]byte),
				},
			}
		}}
		return &BatchFactory{pool: pool}
	case IoTCase:
		pool := &sync.Pool{New: func() interface{} {
			return &hypertableArr{
				data: [3]map[uint32][][]byte{
					nil,
					make(map[uint32][][]byte),
					make(map[uint32][][]byte),
				},
			}
		}}
		return &BatchFactory{pool: pool}
	default:
		fatal("invalid use case: %d", useCase)
		return nil
	}
}

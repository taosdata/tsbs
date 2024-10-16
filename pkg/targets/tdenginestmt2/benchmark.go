package tdenginestmt2

import "C"
import (
	"math"

	"github.com/taosdata/tsbs/pkg/data/source"
	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/tdengine"
)

func NewBenchmark(dbName string, opts *tdengine.LoadingOptions, dataSourceConfig *source.DataSourceConfig) (targets.Benchmark, error) {
	var ds targets.DataSource
	if dataSourceConfig.Type == source.FileDataSourceType {
		ds = newFileDataSource(dataSourceConfig.File.Location)
		useCase, scale := ds.(*fileDataSource).Init()
		switch useCase {
		case CpuCase:
			C.malloc(C.size_t(20 * scale))
		case IoTCase:
		default:
			fatal("invalid use case: %d", useCase)
		}
		return &benchmark{
			opts:       opts,
			dataSource: ds,
			dbName:     dbName,
			factory:    NewBatchFactory(useCase),
			useCase:    useCase,
			scale:      scale,
		}, nil
	} else {
		panic("not implement")
	}
}

type benchmark struct {
	opts       *tdengine.LoadingOptions
	dataSource targets.DataSource
	dbName     string
	batchSize  uint
	factory    *BatchFactory
	useCase    byte
	scale      uint32
}

func (b *benchmark) GetDataSource() targets.DataSource {
	return b.dataSource
}

func (b *benchmark) GetBatchFactory() targets.BatchFactory {
	return b.factory
}

func (b *benchmark) GetPointIndexer(maxPartitions uint) targets.PointIndexer {
	if maxPartitions > 1 {
		interval := uint32(math.MaxUint32 / maxPartitions)
		hashEndGroups := make([]uint32, maxPartitions)
		for i := 0; i < int(maxPartitions); i++ {
			if i == int(maxPartitions)-1 {
				hashEndGroups[i] = math.MaxUint32
			} else {
				hashEndGroups[i] = interval*uint32(i+1) - 1
			}
		}
		prefix := []byte("1." + b.dbName + ".")
		return NewIndexer(prefix, int(maxPartitions), hashEndGroups, b.useCase, b.scale)

	}
	return &targets.ConstantIndexer{}
}

func (b *benchmark) GetProcessor() targets.Processor {
	return newProcessor(b.opts, b.dbName, b.batchSize, b.factory.pool, b.useCase, b.scale)
}

func (b *benchmark) GetDBCreator() targets.DBCreator {
	return &DbCreator{
		DbCreator: tdengine.DbCreator{Opts: b.opts},
		useCase:   b.useCase,
		ds:        b.dataSource.(*fileDataSource),
	}
}

func (b *benchmark) SetConfig(batchSize uint, workers uint) {
	b.batchSize = batchSize
	b.dataSource.(*fileDataSource).maxCache = int(batchSize * workers * 10)
}

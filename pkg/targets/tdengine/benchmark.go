package tdengine

import (
	"errors"

	"github.com/taosdata/tsbs/pkg/data/source"
	"github.com/taosdata/tsbs/pkg/targets"
)

func NewBenchmark(dbName string, opts *LoadingOptions, dataSourceConfig *source.DataSourceConfig) (targets.Benchmark, error) {
	if dataSourceConfig.Type != source.FileDataSourceType {
		return nil, errors.New("only FILE data source implemented for TDengine")
	}

	var ds targets.DataSource
	if dataSourceConfig.Type == source.FileDataSourceType {
		ds = newFileDataSource(dataSourceConfig.File.Location)
	}

	return &benchmark{
		opts:   opts,
		ds:     ds,
		dbName: dbName,
	}, nil
}

type benchmark struct {
	opts   *LoadingOptions
	ds     targets.DataSource
	dbName string
}

func (b *benchmark) GetDataSource() targets.DataSource {
	return b.ds
}

func (b *benchmark) GetBatchFactory() targets.BatchFactory {
	return &factory{}
}

func (b *benchmark) GetPointIndexer(maxPartitions uint) targets.PointIndexer {
	if maxPartitions > 1 {
		return &indexer{partitions: maxPartitions, tmp: map[string]uint{}}
	}
	return &targets.ConstantIndexer{}
}

func (b *benchmark) GetProcessor() targets.Processor {
	return newProcessor(b.opts, b.dbName)
}

func (b *benchmark) GetDBCreator() targets.DBCreator {
	return &dbCreator{opts: b.opts, ds: b.ds}
}

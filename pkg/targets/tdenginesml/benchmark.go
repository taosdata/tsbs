package tdenginesml

import (
	"bufio"

	"github.com/taosdata/tsbs/load"
	"github.com/taosdata/tsbs/pkg/data/source"
	"github.com/taosdata/tsbs/pkg/targets"
)

func NewBenchmark(dbName string, opts *LoadingOptions, dataSourceConfig *source.DataSourceConfig) (targets.Benchmark, error) {
	var ds targets.DataSource
	if dataSourceConfig.Type == source.FileDataSourceType {
		br := load.GetBufferedReader(dataSourceConfig.File.Location)
		ds = &fileDataSource{scanner: bufio.NewScanner(br)}
	} else {
		panic("not implement")
	}

	return &benchmark{
		opts:   opts,
		ds:     ds,
		dbName: dbName,
	}, nil
}

type benchmark struct {
	dbName string
	opts   *LoadingOptions
	ds     targets.DataSource
}

func (b *benchmark) GetDataSource() targets.DataSource {
	return b.ds
}

func (b *benchmark) GetBatchFactory() targets.BatchFactory {
	return &factory{}
}

func (b *benchmark) GetPointIndexer(_ uint) targets.PointIndexer {
	return &targets.ConstantIndexer{}
}

func (b *benchmark) GetProcessor() targets.Processor {
	return newProcessor(b.opts, b.dbName)
}

func (b *benchmark) GetDBCreator() targets.DBCreator {
	return &dbCreator{
		opts: b.opts,
		ds:   b.ds,
	}
}

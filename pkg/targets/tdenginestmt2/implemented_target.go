package tdenginestmt2

import (
	"bytes"

	"github.com/blagojts/viper"
	"github.com/spf13/pflag"
	"github.com/taosdata/tsbs/pkg/data/serialize"
	"github.com/taosdata/tsbs/pkg/data/source"
	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/constants"
	"github.com/taosdata/tsbs/pkg/targets/tdengine"
)

func NewTarget() targets.ImplementedTarget {
	return &tdengineStmt2Target{}
}

type tdengineStmt2Target struct {
}

func (t *tdengineStmt2Target) TargetSpecificFlags(flagPrefix string, flagSet *pflag.FlagSet) {
	tdengine.TargetSpecificFlags(flagPrefix, flagSet)
}

func (t *tdengineStmt2Target) TargetName() string {
	return constants.FormatTDengineStmt2
}

func (t *tdengineStmt2Target) Serializer() serialize.PointSerializer {
	return &Serializer{
		tmpBuf:   &bytes.Buffer{},
		writeBuf: &bytes.Buffer{},
	}
}

func (t *tdengineStmt2Target) Benchmark(targetDB string, dataSourceConfig *source.DataSourceConfig, v *viper.Viper,
) (targets.Benchmark, error) {
	var loadingOptions tdengine.LoadingOptions
	if err := v.Unmarshal(&loadingOptions); err != nil {
		return nil, err
	}
	return NewBenchmark(targetDB, &loadingOptions, dataSourceConfig)
}

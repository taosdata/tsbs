package tdengine

import (
	"bytes"

	"github.com/blagojts/viper"
	"github.com/spf13/pflag"
	"github.com/taosdata/tsbs/pkg/data/serialize"
	"github.com/taosdata/tsbs/pkg/data/source"
	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/constants"
)

func NewTarget() targets.ImplementedTarget {
	return &tdengineTarget{}
}

type tdengineTarget struct {
}

func (t *tdengineTarget) TargetSpecificFlags(flagPrefix string, flagSet *pflag.FlagSet) {
	flagSet.String(flagPrefix+"user", "root", "User to connect to TDengine")
	flagSet.String(flagPrefix+"pass", "taosdata", "Password for user connecting to TDengine")
	flagSet.String(flagPrefix+"host", "", "TDengine host")
	flagSet.Int(flagPrefix+"port", 6030, "TDengine Port")
	flagSet.Int(flagPrefix+"vgroups", 0, "TDengine DB vgroups")
}

func (t *tdengineTarget) TargetName() string {
	return constants.FormatTDengine
}

func (t *tdengineTarget) Serializer() serialize.PointSerializer {
	return &Serializer{
		tableMap:   map[string]struct{}{},
		superTable: map[string]*Table{},
		tmpBuf:     &bytes.Buffer{},
	}
}

func (t *tdengineTarget) Benchmark(targetDB string, dataSourceConfig *source.DataSourceConfig, v *viper.Viper,
) (targets.Benchmark, error) {
	var loadingOptions LoadingOptions
	if err := v.Unmarshal(&loadingOptions); err != nil {
		return nil, err
	}
	return NewBenchmark(targetDB, &loadingOptions, dataSourceConfig)
}

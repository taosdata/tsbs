package tdenginerest

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
	flagSet.String(flagPrefix+"host", "localhost", "taosAdapter host")
	flagSet.Int(flagPrefix+"port", 6041, "taosAdapter Port")
	flagSet.Int(flagPrefix+"vgroups", 0, "TDengine DB vgroups")
	flagSet.Int(flagPrefix+"pages", 0, "TDengine DB pages")
	flagSet.Int(flagPrefix+"buffer", 0, "TDengine DB buffer")
	flagSet.Int(flagPrefix+"stt_trigger", 0, "TDengine DB stt_trigger")
	flagSet.Int(flagPrefix+"wal_fsync_period", 3000, "TDengine DB wal_fsync_period")
}

func (t *tdengineTarget) TargetName() string {
	return constants.FormatTDengineRest
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

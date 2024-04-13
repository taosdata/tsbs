package tdenginesml

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
	return &influxTarget{}
}

type influxTarget struct {
}

func (t *influxTarget) TargetSpecificFlags(flagPrefix string, flagSet *pflag.FlagSet) {
	flagSet.String(flagPrefix+"user", "root", "User to connect to TDengine")
	flagSet.String(flagPrefix+"pass", "taosdata", "Password for user connecting to TDengine")
	flagSet.String(flagPrefix+"host", "", "TDengine host")
	flagSet.Int(flagPrefix+"port", 6030, "TDengine Port")
	flagSet.Int(flagPrefix+"vgroups", 0, "TDengine DB vgroups")
	flagSet.Int(flagPrefix+"pages", 0, "TDengine DB pages")
	flagSet.Int(flagPrefix+"buffer", 0, "TDengine DB buffer")
	flagSet.Int(flagPrefix+"stt_trigger", 0, "TDengine DB stt_trigger")
	flagSet.Int(flagPrefix+"wal_fsync_period", 3000, "TDengine DB wal_fsync_period")
	flagSet.Int(flagPrefix+"wal_level", 1, "TDengine DB wal_level")
	flagSet.String(flagPrefix+"db_parameters", "", "TDengine DB parameters")
}

func (t *influxTarget) TargetName() string {
	return constants.FormatTDengineSML
}

func (t *influxTarget) Serializer() serialize.PointSerializer {
	buf := &bytes.Buffer{}
	buf.Grow(1024 * 1024)
	return &Serializer{tmpBuf: buf}
}

func (t *influxTarget) Benchmark(targetDB string, dataSourceConfig *source.DataSourceConfig, v *viper.Viper,
) (targets.Benchmark, error) {
	var loadingOptions LoadingOptions
	if err := v.Unmarshal(&loadingOptions); err != nil {
		return nil, err
	}
	return NewBenchmark(targetDB, &loadingOptions, dataSourceConfig)
}

package influx3

import (
	"time"

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
	flagSet.String(flagPrefix+"urls", "http://localhost:8086", "InfluxDB URLs, comma-separated. Will be used in a round-robin fashion.")
	flagSet.Int(flagPrefix+"replication-factor", 1, "Cluster replication factor (only applies to clustered databases).")
	flagSet.String(flagPrefix+"consistency", "all", "Write consistency. Must be one of: any, one, quorum, all.")
	flagSet.Duration(flagPrefix+"backoff", time.Second, "Time to sleep between requests when server indicates backpressure is needed.")
	flagSet.Bool(flagPrefix+"gzip", true, "Whether to gzip encode requests (default true).")
	flagSet.String(flagPrefix+"auth-token", "", "Authentication token for InfluxDB 3.0")
}

func (t *influxTarget) TargetName() string {
	return constants.FormatInflux3
}

func (t *influxTarget) Serializer() serialize.PointSerializer {
	return &Serializer{}
}

func (t *influxTarget) Benchmark(string, *source.DataSourceConfig, *viper.Viper) (targets.Benchmark, error) {
	panic("not implemented")
}

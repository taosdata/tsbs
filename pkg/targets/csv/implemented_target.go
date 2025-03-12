package csv

import (
	"os"

	"github.com/blagojts/viper"
	"github.com/spf13/pflag"
	"github.com/taosdata/tsbs/pkg/data/serialize"
	"github.com/taosdata/tsbs/pkg/data/source"
	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/constants"
)

func NewTarget() targets.ImplementedTarget {
	return &csvTarget{}
}

type csvTarget struct {
}

func (t *csvTarget) TargetSpecificFlags(flagPrefix string, flagSet *pflag.FlagSet) {
	return
}

func (t *csvTarget) TargetName() string {
	return constants.FormatCsv
}

func (t *csvTarget) Serializer() serialize.PointSerializer {
	outDir := os.Getenv("TSBS_CSV_OUT_DIR")
	return &Serializer{
		outDir: outDir,
	}
}

func (t *csvTarget) Benchmark(targetDB string, dataSourceConfig *source.DataSourceConfig, v *viper.Viper,
) (targets.Benchmark, error) {
	panic("not implemented")
}

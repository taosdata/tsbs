package source

import (
	"github.com/taosdata/tsbs/pkg/data/usecases/common"
)

const (
	FileDataSourceType      = "FILE"
	SimulatorDataSourceType = "SIMULATOR"
)

var (
	ValidDataSourceTypes = []string{FileDataSourceType, SimulatorDataSourceType}
)

type DataSourceConfig struct {
	Type      string                      `yaml:"type"`
	File      *FileDataSourceConfig       `yaml:"file,omitempty"`
	Simulator *common.DataGeneratorConfig `yaml:"simulator,omitempty"`
}

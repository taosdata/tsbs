package initializers

import (
	"fmt"
	"strings"

	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/akumuli"
	"github.com/taosdata/tsbs/pkg/targets/cassandra"
	"github.com/taosdata/tsbs/pkg/targets/clickhouse"
	"github.com/taosdata/tsbs/pkg/targets/constants"
	"github.com/taosdata/tsbs/pkg/targets/crate"
	"github.com/taosdata/tsbs/pkg/targets/influx"
	"github.com/taosdata/tsbs/pkg/targets/influx3"
	"github.com/taosdata/tsbs/pkg/targets/mongo"
	"github.com/taosdata/tsbs/pkg/targets/prometheus"
	"github.com/taosdata/tsbs/pkg/targets/questdb"
	"github.com/taosdata/tsbs/pkg/targets/siridb"
	"github.com/taosdata/tsbs/pkg/targets/tdengine"
	"github.com/taosdata/tsbs/pkg/targets/tdenginesml"
	"github.com/taosdata/tsbs/pkg/targets/tdenginestmt2"
	"github.com/taosdata/tsbs/pkg/targets/timescaledb"
	"github.com/taosdata/tsbs/pkg/targets/timestream"
	"github.com/taosdata/tsbs/pkg/targets/victoriametrics"
)

func GetTarget(format string) targets.ImplementedTarget {
	switch format {
	case constants.FormatTimescaleDB:
		return timescaledb.NewTarget()
	case constants.FormatAkumuli:
		return akumuli.NewTarget()
	case constants.FormatCassandra:
		return cassandra.NewTarget()
	case constants.FormatClickhouse:
		return clickhouse.NewTarget()
	case constants.FormatCrateDB:
		return crate.NewTarget()
	case constants.FormatInflux:
		return influx.NewTarget()
	case constants.FormatInflux3:
		return influx3.NewTarget()
	case constants.FormatMongo:
		return mongo.NewTarget()
	case constants.FormatPrometheus:
		return prometheus.NewTarget()
	case constants.FormatSiriDB:
		return siridb.NewTarget()
	case constants.FormatVictoriaMetrics:
		return victoriametrics.NewTarget()
	case constants.FormatTimestream:
		return timestream.NewTarget()
	case constants.FormatQuestDB:
		return questdb.NewTarget()
	case constants.FormatTDengine:
		return tdengine.NewTarget()
	case constants.FormatTDengineStmt2:
		return tdenginestmt2.NewTarget()
	case constants.FormatTDengineSML:
		return tdenginesml.NewTarget()
	}

	supportedFormatsStr := strings.Join(constants.SupportedFormats(), ",")
	panic(fmt.Sprintf("Unrecognized format %s, supported: %s", format, supportedFormatsStr))
}

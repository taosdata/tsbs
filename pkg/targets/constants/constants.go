package constants

// Formats supported for generation
const (
	FormatCassandra       = "cassandra"
	FormatClickhouse      = "clickhouse"
	FormatInflux          = "influx"
	FormatInflux3         = "influx3"
	FormatMongo           = "mongo"
	FormatSiriDB          = "siridb"
	FormatTimescaleDB     = "timescaledb"
	FormatAkumuli         = "akumuli"
	FormatCrateDB         = "cratedb"
	FormatPrometheus      = "prometheus"
	FormatVictoriaMetrics = "victoriametrics"
	FormatTimestream      = "timestream"
	FormatQuestDB         = "questdb"
	FormatTDengine        = "TDengine"
	FormatTDengineStmt2   = "TDengineStmt2"
	FormatTDengineSML     = "TDengineSML"
	FormatCsv             = "csv"
)

func SupportedFormats() []string {
	return []string{
		FormatCassandra,
		FormatClickhouse,
		FormatInflux,
		FormatInflux3,
		FormatMongo,
		FormatSiriDB,
		FormatTimescaleDB,
		FormatAkumuli,
		FormatCrateDB,
		FormatPrometheus,
		FormatVictoriaMetrics,
		FormatTimestream,
		FormatQuestDB,
		FormatTDengine,
		FormatTDengineStmt2,
		FormatTDengineSML,
		FormatCsv,
	}
}

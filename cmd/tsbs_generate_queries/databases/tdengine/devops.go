package tdengine

import (
	"fmt"
	"strings"
	"time"

	"github.com/taosdata/tsbs/cmd/tsbs_generate_queries/uses/devops"
	"github.com/taosdata/tsbs/pkg/query"
)

// TODO: Remove the need for this by continuing to bubble up errors
func panicIfErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}

// Devops produces TimescaleDB-specific queries for all the devops query types.
type Devops struct {
	*BaseGenerator
	*devops.Core
}

// getHostWhereWithHostnames creates WHERE SQL statement for multiple hostnames.
// NOTE 'WHERE' itself is not included, just hostname filter clauses, ready to concatenate to 'WHERE' string
func (d *Devops) getHostWhereWithHostnames(hostnames []string) string {
	var hostnameClauses []string
	for _, s := range hostnames {
		hostnameClauses = append(hostnameClauses, fmt.Sprintf("'%s'", s))
	}
	return fmt.Sprintf("hostname IN (%s)", strings.Join(hostnameClauses, ","))
}

// getHostWhereString gets multiple random hostnames and creates a WHERE SQL statement for these hostnames.
func (d *Devops) getHostWhereString(nHosts int) string {
	hostnames, err := d.GetRandomHosts(nHosts)
	panicIfErr(err)
	return d.getHostWhereWithHostnames(hostnames)
}

func (d *Devops) getSelectClausesAggMetrics(agg string, metrics []string) []string {
	selectClauses := make([]string, len(metrics))
	for i, m := range metrics {
		selectClauses[i] = fmt.Sprintf("%s(%s)", agg, m)
	}

	return selectClauses
}

func (d *Devops) GroupByTime(qi query.Query, nHosts, numMetrics int, timeRange time.Duration) {
	interval := d.Interval.MustRandWindow(timeRange)
	metrics, err := devops.GetCPUMetricsSlice(numMetrics)
	panicIfErr(err)
	selectClauses := d.getSelectClausesAggMetrics("max", metrics)
	if len(selectClauses) < 1 {
		panic(fmt.Sprintf("invalid number of select clauses: got %d", len(selectClauses)))
	}

	sql := fmt.Sprintf(`SELECT %s FROM cpu WHERE %s AND ts >= %d AND ts < %d INTERVAL(1m) ORDER BY ts ASC`,
		strings.Join(selectClauses, ", "),
		d.getHostWhereString(nHosts),
		interval.StartUnixNano(),
		interval.EndUnixNano())

	humanLabel := fmt.Sprintf("TDengine %d cpu metric(s), random %4d hosts, random %s by 1m", numMetrics, nHosts, timeRange)
	humanDesc := fmt.Sprintf("%s: %s", humanLabel, interval.StartString())
	d.fillInQuery(qi, humanLabel, humanDesc, devops.TableName, sql)
}

func (d *Devops) GroupByOrderByLimit(qi query.Query) {
	interval := d.Interval.MustRandWindow(time.Hour)
	sql := fmt.Sprintf(`SELECT max(usage_user) FROM cpu WHERE ts < %d INTERVAL(1m) ORDER BY ts DESC LIMIT 5`,
		interval.EndUnixNano())

	humanLabel := "TDengine max cpu over last 5 min-intervals (random end)"
	humanDesc := fmt.Sprintf("%s: %s", humanLabel, interval.EndString())
	d.fillInQuery(qi, humanLabel, humanDesc, devops.TableName, sql)
}

// GroupByTimeAndPrimaryTag selects the AVG of numMetrics metrics under 'cpu' per device per hour for a day,
func (d *Devops) GroupByTimeAndPrimaryTag(qi query.Query, numMetrics int) {
	metrics, err := devops.GetCPUMetricsSlice(numMetrics)
	panicIfErr(err)
	interval := d.Interval.MustRandWindow(devops.DoubleGroupByDuration)

	selectClauses := d.getSelectClausesAggMetrics("avg", metrics)
	sql := fmt.Sprintf("SELECT %s from cpu where ts >= %d and ts < %d interval(1h) group by hostname,ts order by ts", strings.Join(selectClauses, ", "), interval.StartUnixNano(), interval.StartUnixNano())

	humanLabel := devops.GetDoubleGroupByLabel("TDengine", numMetrics)
	humanDesc := fmt.Sprintf("%s: %s", humanLabel, interval.StartString())
	d.fillInQuery(qi, humanLabel, humanDesc, devops.TableName, sql)
}

func (d *Devops) MaxAllCPU(qi query.Query, nHosts int, duration time.Duration) {
	interval := d.Interval.MustRandWindow(duration)

	metrics := devops.GetAllCPUMetrics()
	selectClauses := d.getSelectClausesAggMetrics("max", metrics)

	sql := fmt.Sprintf(`SELECT %s FROM cpu WHERE %s AND ts >= %d AND ts < %d ORDER BY ts`,
		strings.Join(selectClauses, ", "),
		d.getHostWhereString(nHosts),
		interval.StartUnixNano(),
		interval.EndUnixNano())

	humanLabel := devops.GetMaxAllLabel("TDengine", nHosts)
	humanDesc := fmt.Sprintf("%s: %s", humanLabel, interval.StartString())
	d.fillInQuery(qi, humanLabel, humanDesc, devops.TableName, sql)
}

func (d *Devops) LastPointPerHost(qi query.Query) {
	sql := "SELECT last_row(*) from cpu group by hostname order by ts desc"
	humanLabel := "TDengine last row per host"
	humanDesc := humanLabel
	d.fillInQuery(qi, humanLabel, humanDesc, devops.TableName, sql)
}

func (d *Devops) HighCPUForHosts(qi query.Query, nHosts int) {
	var hostWhereClause string
	if nHosts == 0 {
		hostWhereClause = ""
	} else {
		hostWhereClause = fmt.Sprintf("AND %s", d.getHostWhereString(nHosts))
	}
	interval := d.Interval.MustRandWindow(devops.HighCPUDuration)

	sql := fmt.Sprintf(`SELECT * FROM cpu WHERE usage_user > 90.0 and ts >= %d AND ts < %d %s`,
		interval.StartUnixNano(), interval.EndUnixNano(), hostWhereClause)

	humanLabel, err := devops.GetHighCPULabel("TDengine", nHosts)
	panicIfErr(err)
	humanDesc := fmt.Sprintf("%s: %s", humanLabel, interval.StartString())
	d.fillInQuery(qi, humanLabel, humanDesc, devops.TableName, sql)
}

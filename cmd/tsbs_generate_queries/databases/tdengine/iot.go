package tdengine

import (
	"fmt"
	"strings"
	"time"

	"github.com/taosdata/tsbs/cmd/tsbs_generate_queries/uses/iot"
	"github.com/taosdata/tsbs/pkg/query"
)

// IoT produces TDengine-specific queries for all the iot query types.
type IoT struct {
	*iot.Core
	*BaseGenerator
}

//last-loc
//single-last-loc
//low-fuel
//avg-vs-projected-fuel-consumption
//avg-daily-driving-duration
//daily-activity

func (i *IoT) getTrucksWhereWithNames(names []string) string {
	var nameClauses []string

	for _, s := range names {
		nameClauses = append(nameClauses, fmt.Sprintf("'%s'", s))
	}
	return fmt.Sprintf("name IN (%s)", strings.Join(nameClauses, ","))
}

// getHostWhereString gets multiple random hostnames and creates a WHERE SQL statement for these hostnames.
func (i *IoT) getTruckWhereString(nTrucks int) string {
	names, err := i.GetRandomTrucks(nTrucks)
	panicIfErr(err)
	return i.getTrucksWhereWithNames(names)
}

// LastLocByTruck finds the truck location for nTrucks.
func (i *IoT) LastLocByTruck(qi query.Query, nTrucks int) {
	sql := fmt.Sprintf(`SELECT last_row(ts),last_row(latitude),last_row(longitude) FROM readings WHERE %s GROUP BY name`,
		i.getTruckWhereString(nTrucks))

	humanLabel := "TDengine last location by specific truck"
	humanDesc := fmt.Sprintf("%s: random %4d trucks", humanLabel, nTrucks)

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// LastLocPerTruck finds all the truck locations along with truck and driver names.
func (i *IoT) LastLocPerTruck(qi query.Query) {
	//SELECT last(ts),name,driver,latitude,longitude FROM readings WHERE fleet='South' and name IS NOT NULL partition BY name,driver order by name,driver;
	sql := fmt.Sprintf(`SELECT last(ts),name,driver,latitude,longitude FROM readings WHERE fleet='%s' and name IS NOT NULL partition BY name,driver order by name,driver`,
		i.GetRandomFleet())

	humanLabel := "TDengine last location per truck"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// TrucksWithLowFuel finds all trucks with low fuel (less than 10%).
func (i *IoT) TrucksWithLowFuel(qi query.Query) {
	//SELECT last(ts),name,driver,fuel_state FROM diagnostics WHERE fuel_state <= 0.1 AND fleet = 'South' and name IS NOT NULL GROUP BY name,driver order by name;
	sql := fmt.Sprintf(`SELECT last(ts),name,driver,fuel_state FROM diagnostics WHERE fuel_state <= 0.1 AND fleet = '%s' and name IS NOT NULL GROUP BY name,driver order by name`,
		i.GetRandomFleet())

	humanLabel := "TDengine trucks with low fuel"
	humanDesc := fmt.Sprintf("%s: under 10 percent", humanLabel)

	i.fillInQuery(qi, humanLabel, humanDesc, iot.DiagnosticsTableName, sql)
}

//TrucksWithHighLoad finds all trucks that have load over 90%.
func (i *IoT) TrucksWithHighLoad(qi query.Query) {
	//SELECT ts,name,driver,current_load,load_capacity FROM (SELECT last(ts) as ts,name,driver, current_load,load_capacity FROM diagnostics WHERE fleet = 'South' partition by name,driver) WHERE current_load>= (0.9 * load_capacity) partition by name ORDER BY name desc, ts DESC ;
	sql := fmt.Sprintf("SELECT ts,name,driver,current_load,load_capacity FROM (SELECT last(ts) as ts,name,driver, current_load,load_capacity FROM diagnostics WHERE fleet = '%s' partition by name,driver) WHERE current_load>= (0.9 * load_capacity) partition by name ORDER BY name desc, ts DESC ", i.GetRandomFleet())

	humanLabel := "TDengine trucks with high load"
	humanDesc := fmt.Sprintf("%s: over 90 percent", humanLabel)

	i.fillInQuery(qi, humanLabel, humanDesc, iot.DiagnosticsTableName, sql)
}

// StationaryTrucks finds all trucks that have low average velocity in a time window.
func (i *IoT) StationaryTrucks(qi query.Query) {
	interval := i.Interval.MustRandWindow(iot.StationaryDuration)
	//select name,driver from (SELECT name,driver,fleet ,avg(velocity) as mean_velocity FROM readings WHERE ts > '2016-01-01T15:07:21Z' AND ts <= '2016-01-01T16:17:21Z' partition BY name,driver,fleet interval(10m) LIMIT 1) WHERE fleet = 'West' AND mean_velocity < 1 partition BY name;
	sql := fmt.Sprintf("select name,driver from (SELECT name,driver,fleet ,avg(velocity) as mean_velocity FROM readings WHERE ts > %d AND ts <= %d partition BY name,driver,fleet interval(10m) LIMIT 1) WHERE fleet = '%s' AND mean_velocity < 1 partition BY name;", interval.StartUnixMillis(), interval.EndUnixMillis(), i.GetRandomFleet())
	humanLabel := "TDengine stationary trucks"
	humanDesc := fmt.Sprintf("%s: with low avg velocity in last 10 minutes", humanLabel)

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// TrucksWithLongDrivingSessions finds all trucks that have not stopped at least 20 mins in the last 4 hours.
func (i *IoT) TrucksWithLongDrivingSessions(qi query.Query) {
	interval := i.Interval.MustRandWindow(iot.LongDrivingSessionDuration)
	//SELECT name,driver FROM(SELECT name,driver,count(*) AS ten_min FROM(SELECT _wstart as ts,name,driver,avg(velocity) as mean_velocity FROM readings WHERE fleet ="West" AND ts > '2016-01-03T13:46:34Z' AND ts <= '2016-01-03T17:46:34Z' partition BY name,driver interval(10m)) WHERE mean_velocity > 1 GROUP BY name,driver) WHERE ten_min > 22
	sql := fmt.Sprintf("SELECT name,driver FROM(SELECT name,driver,count(*) AS ten_min FROM(SELECT _wstart as ts,name,driver,avg(velocity) as mean_velocity FROM readings WHERE fleet =\"%s\" AND ts > %d AND ts <= %d partition BY name,driver interval(10m)) WHERE mean_velocity > 1 GROUP BY name,driver) WHERE ten_min > %d", i.GetRandomFleet(), interval.StartUnixMillis(), interval.EndUnixMillis(), tenMinutePeriods(5, iot.LongDrivingSessionDuration))
	humanLabel := "TDengine trucks with longer driving sessions"
	humanDesc := fmt.Sprintf("%s: stopped less than 20 mins in 4 hour period", humanLabel)

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// TrucksWithLongDailySessions finds all trucks that have driven more than 10 hours in the last 24 hours.
func (i *IoT) TrucksWithLongDailySessions(qi query.Query) {
	//SELECT name,driver FROM(SELECT name,driver,count(*) AS ten_min FROM(SELECT name,driver,avg(velocity) as mean_velocity FROM readings WHERE fleet ='West' AND ts > '2016-01-01T12:31:37Z' AND ts <= '2016-01-05T12:31:37Z' partition BY name,driver interval(10m) ) WHERE mean_velocity > 1 GROUP BY name,driver) WHERE ten_min > 60

	interval := i.Interval.MustRandWindow(iot.DailyDrivingDuration)
	sql := fmt.Sprintf("SELECT name,driver FROM(SELECT name,driver,count(*) AS ten_min FROM(SELECT name,driver,avg(velocity) as mean_velocity FROM readings WHERE fleet ='%s' AND ts > %d AND ts <= %d partition BY name,driver interval(10m) ) WHERE mean_velocity > 1 GROUP BY name,driver) WHERE ten_min > %d", i.GetRandomFleet(), interval.StartUnixMillis(), interval.EndUnixMillis(), tenMinutePeriods(35, iot.DailyDrivingDuration))

	humanLabel := "TDengine trucks with longer daily sessions"
	humanDesc := fmt.Sprintf("%s: drove more than 10 hours in the last 24 hours", humanLabel)

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// AvgVsProjectedFuelConsumption calculates average and projected fuel consumption per fleet.
func (i *IoT) AvgVsProjectedFuelConsumption(qi query.Query) {
	//select avg(fuel_consumption) as avg_fuel_consumption,avg(nominal_fuel_consumption) as nominal_fuel_consumption from readings where velocity > 1 group by fleet
	sql := fmt.Sprintf("select avg(fuel_consumption) as avg_fuel_consumption,avg(nominal_fuel_consumption) as nominal_fuel_consumption from readings where velocity > 1 group by fleet")
	humanLabel := "TDengine average vs projected fuel consumption per fleet"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// AvgDailyDrivingDuration finds the average driving duration per driver.
func (i *IoT) AvgDailyDrivingDuration(qi query.Query) {
	//select _wstart as ts,fleet,name,driver,count(mv)/6 as hours_driven from ( select _wstart as ts,fleet,name,driver,avg(velocity) as mv from readings where ts > '2016-01-01T00:00:00Z' and ts < '2016-01-05T00:00:01Z' partition by fleet,name,driver interval(10m)) where ts > '2016-01-01T00:00:00Z' and ts < '2016-01-05T00:00:01Z' partition by fleet,name,driver interval(1d)
	sql := fmt.Sprintf("select _wstart as ts,fleet,name,driver,count(mv)/6 as hours_driven from ( select _wstart as ts,fleet,name,driver,avg(velocity) as mv from readings where ts > '2016-01-01T00:00:00Z' and ts < '2016-01-05T00:00:01Z' partition by fleet,name,driver interval(10m)) where ts > %d and ts < %d partition by fleet,name,driver interval(1d)", i.Interval.StartUnixMillis(), i.Interval.EndUnixMillis())

	humanLabel := "TDengine average driver driving duration per day"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// AvgDailyDrivingSession finds the average driving session without stopping per driver per day.
func (i *IoT) AvgDailyDrivingSession(qi query.Query) {
	//create table random_measure2_1 (ts timestamp,ela float, name binary(40))
	//
	//insert into random_measure2_1 (select name,ela (SELECT name, diff(difka) as dif, elapsed(difka, 1m) as ela FROM (SELECT name,difka FROM (SELECT ts,name,diff(mv) AS difka FROM (SELECT _wstart as ts,name,floor(avg(velocity)/10)/floor(avg(velocity)/10) AS mv FROM readings WHERE name!='' AND ts > '2016-01-01T00:00:00Z' AND ts < '2016-01-05T00:00:01Z' partition by name interval(10m) fill(value,0)) partition BY name) WHERE difka!=0 partition BY name) partition BY name) WHERE dif = -2 partition BY name)
	//
	//SELECT avg(ela) FROM random_measure2_1 WHERE time > '2016-01-01T00:00:00Z' AND time < '2016-01-05T00:00:01Z' partition BY name interval(1d);
	interval := i.Interval.MustRandWindow(iot.StationaryDuration)
	sql := fmt.Sprintf("insert into random_measure2_1 (select name,ela (SELECT name, diff(difka) as dif, elapsed(difka, 1m) as ela FROM (SELECT name,difka FROM (SELECT ts,name,diff(mv) AS difka FROM (SELECT _wstart as ts,name,floor(avg(velocity)/10)/floor(avg(velocity)/10) AS mv FROM readings WHERE name!='' AND ts > %d AND ts < %d partition by name interval(10m) fill(value,0)) partition BY name) WHERE difka!=0 partition BY name) partition BY name) WHERE dif = -2 partition BY name);SELECT avg(ela) FROM random_measure2_1 WHERE time > %d AND time < %d partition BY name interval(1d)", interval.StartUnixMillis(), interval.EndUnixMillis(), interval.StartUnixMillis(), interval.EndUnixMillis())
	humanLabel := "TDengine average driver driving session without stopping per day"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// AvgLoad finds the average load per truck model per fleet.
func (i *IoT) AvgLoad(qi query.Query) {
	//SELECT fleet, model,avg(ml) AS mean_load_percentage FROM (SELECT fleet, model,current_load/load_capacity AS ml FROM diagnostics partition BY name, fleet, model) partition BY fleet, model order by fleet,model ;
	sql := fmt.Sprintf("SELECT fleet, model,avg(ml) AS mean_load_percentage FROM (SELECT fleet, model,current_load/load_capacity AS ml FROM diagnostics partition BY name, fleet, model) partition BY fleet, model order by fleet,model")

	humanLabel := "TDengine average load per truck model per fleet"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// DailyTruckActivity returns the number of hours trucks has been active (not out-of-commission) per day per fleet per model.
func (i *IoT) DailyTruckActivity(qi query.Query) {
	//SELECT _wstart as ts,model,fleet,count(ms1)/144 FROM (SELECT _wstart as ts1,model, fleet,avg(status) AS ms1 FROM diagnostics WHERE ts >= '2016-01-01T00:00:00Z' AND ts < '2016-01-05T00:00:01Z' partition by model, fleet interval(10m) fill(value,0)) WHERE ts1 >= '2016-01-01T00:00:00Z' AND ts1 < '2016-01-05T00:00:01Z' AND ms1<1 partition by model, fleet interval(1d)
	sql := fmt.Sprintf("SELECT _wstart as ts,model,fleet,count(ms1)/144 FROM (SELECT _wstart as ts1,model, fleet,avg(status) AS ms1 FROM diagnostics WHERE ts >= %d AND ts < %d partition by model, fleet interval(10m) fill(value,0)) WHERE ts1 >= %d AND ts1 < %d AND ms1<1 partition by model, fleet interval(1d)", i.Interval.StartUnixMillis(), i.Interval.EndUnixMillis(), i.Interval.StartUnixMillis(), i.Interval.EndUnixMillis())
	humanLabel := "TDengine daily truck activity per fleet per model"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// TruckBreakdownFrequency calculates the amount of times a truck model broke down in the last period.
func (i *IoT) TruckBreakdownFrequency(qi query.Query) {
	//SELECT model,count(state_changed) FROM (SELECT model,diff(broken_down) AS state_changed FROM (SELECT model,cast(cast(floor(2*(sum(nzs)/count(nzs))) as bool) as int) AS broken_down FROM (SELECT ts,model, cast(cast(status as bool) as int) AS nzs FROM diagnostics WHERE ts >= '2016-01-01T00:00:00Z' AND ts < '2023-01-05T00:00:01Z' ) WHERE ts >= '2016-01-01T00:00:00Z' AND ts < '2023-01-05T00:00:01Z' partition BY model interval(10m)) partition BY model) WHERE state_changed = 1 partition BY model
	sql := fmt.Sprintf("SELECT model,count(state_changed) FROM (SELECT model,diff(broken_down) AS state_changed FROM (SELECT model,cast(cast(floor(2*(sum(nzs)/count(nzs))) as bool) as int) AS broken_down FROM (SELECT ts,model, cast(cast(status as bool) as int) AS nzs FROM diagnostics WHERE ts >= %d AND ts < %d ) WHERE ts >= %d AND ts < %d partition BY model interval(10m)) partition BY model) WHERE state_changed = 1 partition BY model", i.Interval.StartUnixMillis(), i.Interval.EndUnixMillis(), i.Interval.StartUnixMillis(), i.Interval.EndUnixMillis())

	humanLabel := "TDengine truck breakdown frequency per model"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

func tenMinutePeriods(minutesPerHour float64, duration time.Duration) int {
	durationMinutes := duration.Minutes()
	leftover := minutesPerHour * duration.Hours()
	return int((durationMinutes - leftover) / 10)
}

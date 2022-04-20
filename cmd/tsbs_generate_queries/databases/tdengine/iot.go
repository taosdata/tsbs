package tdengine

import (
	"fmt"
	"strings"

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
	sql := fmt.Sprintf(`SELECT  last_row(ts),last_row(latitude),last_row(longitude) FROM readings WHERE fleet='%s' AND name is not null GROUP BY name,driver`,
		i.GetRandomFleet())

	humanLabel := "TDengine last location per truck"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// TrucksWithLowFuel finds all trucks with low fuel (less than 10%).
func (i *IoT) TrucksWithLowFuel(qi query.Query) {
	sql := fmt.Sprintf(`SELECT last_row(fuel_state),driver FROM diagnostics WHERE fuel_state <= 0.1 AND fleet = '%s' and name IS NOT NULL GROUP BY name`,
		i.GetRandomFleet())

	humanLabel := "TDengine trucks with low fuel"
	humanDesc := fmt.Sprintf("%s: under 10 percent", humanLabel)

	i.fillInQuery(qi, humanLabel, humanDesc, iot.DiagnosticsTableName, sql)
}

//TrucksWithHighLoad finds all trucks that have load over 90%.
//todo
//func (i *IoT) TrucksWithHighLoad(qi query.Query) {
//	sql := fmt.Sprintf("select name,driver,current_load,load_capacity from (select current_load/load_capacity as rate,name,driver,current_load,load_capacity from diagnostics WHERE fleet = '%s' group by name) where rate > 0.9", i.GetRandomFleet())
//
//	humanLabel := "TDengine trucks with high load"
//	humanDesc := fmt.Sprintf("%s: over 90 percent", humanLabel)
//
//	i.fillInQuery(qi, humanLabel, humanDesc, iot.DiagnosticsTableName, sql)
//}

// StationaryTrucks finds all trucks that have low average velocity in a time window.
//todo
//func (i *IoT) StationaryTrucks(qi query.Query) {
//interval := i.Interval.MustRandWindow(iot.StationaryDuration)
//sql := fmt.Sprintf("select name,driver from (select avg(velocity) as a from readings where ts > %d and ts <= %d and feet = '%s' interval(10m) group by name,driver,feet limit 1) where a < 1 group by name", interval.StartUnixMillis(), interval.EndUnixMillis(), i.GetRandomFleet())
//humanLabel := "TDengine stationary trucks"
//humanDesc := fmt.Sprintf("%s: with low avg velocity in last 10 minutes", humanLabel)
//
//i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
//}

// TrucksWithLongDrivingSessions finds all trucks that have not stopped at least 20 mins in the last 4 hours.
//todo
//func (i *IoT) TrucksWithLongDrivingSessions(qi query.Query) {
//	interval := i.Interval.MustRandWindow(iot.LongDrivingSessionDuration)
//	sql := fmt.Sprintf("select name,driver from(select count(*) as c from (select avg(velocity) as a from readings where fleet = '%s' and ts > %d and ts <= %d interval(10m) group by name,driver) where a > 1 group by name,driver)where c > %d")
//}

// TrucksWithLongDailySessions finds all trucks that have driven more than 10 hours in the last 24 hours.
//todo
//func (i *IoT) TrucksWithLongDailySessions(qi query.Query) {
//}

// AvgVsProjectedFuelConsumption calculates average and projected fuel consumption per fleet.
func (i *IoT) AvgVsProjectedFuelConsumption(qi query.Query) {
	sql := fmt.Sprintf("select avg(fuel_consumption),avg(nominal_fuel_consumption) from readings where velocity > 1 group by fleet")
	humanLabel := "TDengine average vs projected fuel consumption per fleet"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// AvgDailyDrivingDuration finds the average driving duration per driver.
func (i *IoT) AvgDailyDrivingDuration(qi query.Query) {
	sql := fmt.Sprintf("select count(mv)/6 as hours_driven from (select avg(velocity) as mv from readings where ts > %d and ts < %d interval(10m) group by fleet,name,driver) interval(1d)", i.Interval.StartUnixMillis(), i.Interval.EndUnixMillis())

	humanLabel := "TDengine average driver driving duration per day"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// AvgDailyDrivingSession finds the average driving session without stopping per driver per day.
//todo
//func (i *IoT) AvgDailyDrivingSession(qi query.Query) {
//}

//AvgLoad finds the average load per truck model per fleet.
//func (i *IoT) AvgLoad(qi query.Query) {
//	fmt.Sprintf("select avg(ml) as mean_load_percentage from (select current_load/load_capacity as ml ,name,fleet,model from diagnostics) group by fleet,model")
//}

// DailyTruckActivity returns the number of hours trucks has been active (not out-of-commission) per day per fleet per model.
func (i *IoT) DailyTruckActivity(qi query.Query) {
	sql := fmt.Sprintf("select count(ms)/144 from (select avg(status) as ms from diagnostics where ts >= %d and ts < %d interval(10m) group by model,fleet) where ms < 1", i.Interval.StartUnixMillis(), i.Interval.EndUnixMillis())
	humanLabel := "TDengine daily truck activity per fleet per model"
	humanDesc := humanLabel

	i.fillInQuery(qi, humanLabel, humanDesc, iot.ReadingsTableName, sql)
}

// TruckBreakdownFrequency calculates the amount of times a truck model broke down in the last period.
//todo
//func (i *IoT) TruckBreakdownFrequency(qi query.Query) {
//
//}

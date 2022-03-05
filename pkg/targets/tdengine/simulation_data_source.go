package tdengine

import (
	"bytes"
	"fmt"

	"github.com/timescale/tsbs/pkg/data"
	"github.com/timescale/tsbs/pkg/data/usecases/common"
	"github.com/timescale/tsbs/pkg/targets"
)

func newSimulationDataSource(sim common.Simulator) targets.DataSource {
	return &simulationDataSource{
		simulator: sim,
		headers:   sim.Headers(),
		buf:       &bytes.Buffer{},
		tmpBuf:    &bytes.Buffer{},
	}
}

type simulationDataSource struct {
	simulator common.Simulator
	headers   *common.GeneratedDataHeaders
	buf       *bytes.Buffer
	tmpBuf    *bytes.Buffer
}

func (d *simulationDataSource) Headers() *common.GeneratedDataHeaders {
	return nil
}

func (d *simulationDataSource) NextItem() data.LoadedPoint {
	if d.headers == nil {
		fatal("headers not read before starting to read points")
		return data.LoadedPoint{}
	}
	newSimulatorPoint := data.NewPoint()
	var write bool
	for !d.simulator.Finished() {
		write = d.simulator.Next(newSimulatorPoint)
		if write {
			break
		}
		newSimulatorPoint.Reset()
	}
	if d.simulator.Finished() || !write {
		return data.LoadedPoint{}
	}
	newLoadPoint := &insertData{}
	tagValues := newSimulatorPoint.TagValues()
	tagKeys := newSimulatorPoint.TagKeys()
	measurement := newSimulatorPoint.MeasurementName()
	d.tmpBuf.Write(measurement)
	for i, v := range tagValues {
		d.tmpBuf.WriteByte(',')
		d.tmpBuf.Write(tagKeys[i])
		d.tmpBuf.WriteByte('=')
		FastFormat(d.tmpBuf, v)
		if i > 0 {
			d.buf.WriteByte(',')
		}
		d.buf.Write(tagKeys[i])
		d.buf.WriteByte('=')
		FastFormat(d.buf, v)
	}
	subTable := calculateTable(d.tmpBuf.Bytes())
	newLoadPoint.tbName = subTable
	d.tmpBuf.Reset()
	newLoadPoint.tags = d.buf.String()
	d.buf.Reset()
	fmt.Fprintf(d.buf, "ts=%d", newSimulatorPoint.Timestamp().UTC().UnixNano())
	fieldValues := newSimulatorPoint.FieldValues()
	fieldKeys := newSimulatorPoint.FieldKeys()
	for i, v := range fieldValues {
		d.buf.WriteByte(',')
		d.buf.Write(fieldKeys[i])
		d.buf.WriteByte('=')
		FastFormat(d.buf, v)
	}

	newLoadPoint.fields = d.buf.String()
	return data.NewLoadedPoint(&point{
		hypertable: string(measurement),
		row:        newLoadPoint,
	})
}

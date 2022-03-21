package tdengine

import (
	"bytes"
	"container/list"
	"fmt"
	"strings"

	"github.com/timescale/tsbs/pkg/data"
	"github.com/timescale/tsbs/pkg/data/usecases/common"
	"github.com/timescale/tsbs/pkg/targets"
)

func newSimulationDataSource(sim common.Simulator) targets.DataSource {
	return &simulationDataSource{
		simulator:  sim,
		headers:    sim.Headers(),
		tmpBuf:     &bytes.Buffer{},
		superTable: map[string]*Table{},
		tableMap:   map[string]struct{}{},
		tmpData:    list.New(),
	}
}

type simulationDataSource struct {
	simulator  common.Simulator
	headers    *common.GeneratedDataHeaders
	tmpBuf     *bytes.Buffer
	superTable map[string]*Table
	tableMap   map[string]struct{}
	tmpData    *list.List
}

func (s *simulationDataSource) Headers() *common.GeneratedDataHeaders {
	return nil
}

func (s *simulationDataSource) NextItem() data.LoadedPoint {
	if s.tmpData.Len() > 0 {
		f := s.tmpData.Front()
		p := f.Value.(data.LoadedPoint)
		s.tmpData.Remove(f)
		return p
	}
	var write bool
	p := data.NewPoint()
	for !s.simulator.Finished() {
		write = s.simulator.Next(p)
		if write {
			break
		}
		p.Reset()
	}
	if s.simulator.Finished() || !write {
		return data.LoadedPoint{}
	}

	haveOthers := false
	var fieldKeys []string
	var fieldValues []string
	var fieldTypes []string
	var tagValues []string
	var tagKeys []string
	tKeys := p.TagKeys()
	tValues := p.TagValues()
	fKeys := p.FieldKeys()
	fValues := p.FieldValues()
	superTable := string(p.MeasurementName())
	for i, value := range fValues {
		fType := FastFormat(s.tmpBuf, value)
		if value != nil {
			fieldKeys = append(fieldKeys, string(fKeys[i]))
			fieldTypes = append(fieldTypes, fType)
		}
		fieldValues = append(fieldValues, s.tmpBuf.String())
		s.tmpBuf.Reset()
	}

	for i, value := range tValues {
		if value == nil {
			stable, exist := s.superTable[superTable]
			if exist {
				_, exist = stable.columns[string(tKeys[i])]
				if exist {
					FastFormat(s.tmpBuf, tKeys[i])
					fieldValues = append(fieldValues, s.tmpBuf.String())
					s.tmpBuf.Reset()
				}
			} else {
				//todo 可能类型错误
				tagKeys = append(tagKeys, string(tKeys[i]))
				FastFormat(s.tmpBuf, value)
				tagValues = append(tagValues, s.tmpBuf.String())
				s.tmpBuf.Reset()
			}
			continue
		}
		switch value.(type) {
		case string:
			tagKeys = append(tagKeys, string(tKeys[i]))
			FastFormat(s.tmpBuf, value)
			tagValues = append(tagValues, s.tmpBuf.String())
			s.tmpBuf.Reset()
		default:
			fType := FastFormat(s.tmpBuf, tKeys[i])
			fieldKeys = append(fieldKeys, string(tKeys[i]))
			fieldTypes = append(fieldTypes, fType)
			fieldValues = append(fieldValues, s.tmpBuf.String())
			s.tmpBuf.Reset()
		}
	}
	s.tmpBuf.WriteString(superTable)
	for i, v := range tagValues {
		s.tmpBuf.WriteByte(',')
		s.tmpBuf.Write(tKeys[i])
		s.tmpBuf.WriteByte('=')
		s.tmpBuf.WriteString(v)
	}
	subTable := calculateTable(s.tmpBuf.Bytes())
	s.tmpBuf.Reset()
	stable, exist := s.superTable[superTable]
	var returnData data.LoadedPoint
	if !exist {
		for i := 0; i < len(fieldTypes); i++ {
			s.tmpBuf.WriteByte(',')
			s.tmpBuf.WriteString(fieldKeys[i])
			s.tmpBuf.WriteByte(' ')
			s.tmpBuf.WriteString(fieldTypes[i])
		}
		returnData = data.NewLoadedPoint(&point{
			sqlType:    CreateSTable,
			superTable: superTable,
			subTable:   subTable,
			fieldCount: 0,
			sql:        fmt.Sprintf("create table %s (ts timestamp%s) tags (%s binary(30))", superTable, s.tmpBuf.String(), strings.Join(tagKeys, " binary(30),")),
		})
		haveOthers = true
		table := &Table{
			columns: map[string]struct{}{},
			tags:    map[string]struct{}{},
		}
		for _, key := range fieldKeys {
			table.columns[key] = nothing
		}
		for _, key := range tagKeys {
			table.tags[key] = nothing
		}
		s.superTable[superTable] = table
	} else {
		for _, key := range fieldKeys {
			if _, exist = stable.columns[key]; !exist {
				dp := data.NewLoadedPoint(&point{
					sqlType:    Modify,
					superTable: superTable,
					subTable:   subTable,
					fieldCount: 0,
					sql:        fmt.Sprintf("alter table %s add COLUMN %s double", superTable, key),
				})
				if haveOthers {
					s.tmpData.PushBack(dp)
				} else {
					returnData = dp
					haveOthers = true
				}
				stable.columns[key] = nothing
			}
		}
		for _, key := range tagKeys {
			if _, exist = stable.tags[key]; !exist {
				dp := data.NewLoadedPoint(&point{
					sqlType:    Modify,
					superTable: superTable,
					subTable:   subTable,
					fieldCount: 0,
					sql:        fmt.Sprintf("alter table %s add TAG %s binary(30)", superTable, key),
				})
				if haveOthers {
					s.tmpData.PushBack(dp)
				} else {
					returnData = dp
					haveOthers = true
				}
				stable.tags[key] = nothing
			}
		}
	}
	_, exist = s.tableMap[subTable]
	if !exist {
		dp := data.NewLoadedPoint(&point{
			sqlType:    CreateSubTable,
			superTable: superTable,
			subTable:   subTable,
			fieldCount: 0,
			sql:        fmt.Sprintf("create table %s using %s (%s) tags (%s)", subTable, superTable, strings.Join(tagKeys, ","), strings.Join(tagValues, ",")),
		})
		if haveOthers {
			s.tmpData.PushBack(dp)
		} else {
			returnData = dp
			haveOthers = true
		}
		s.tableMap[subTable] = nothing
	}
	dp := data.NewLoadedPoint(&point{
		sqlType:    Insert,
		superTable: superTable,
		subTable:   subTable,
		fieldCount: len(fieldValues),
		sql:        fmt.Sprintf("(%d,%s)", p.TimestampInUnixMs(), strings.Join(fieldValues, ",")),
	})
	if haveOthers {
		s.tmpData.PushBack(dp)
	} else {
		returnData = dp
		haveOthers = true
	}
	return returnData
}

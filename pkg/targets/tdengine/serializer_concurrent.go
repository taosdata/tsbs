package tdengine

import (
	"bytes"
	"fmt"
	"log"
	"strings"
	"sync"
	"unsafe"

	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/data/usecases/common"
)

var bufferPool = sync.Pool{
	New: func() interface{} {
		return &bytes.Buffer{}
	},
}

// CREATE STABLE `readings` (`ts` TIMESTAMP, `latitude` DOUBLE, `longitude` DOUBLE, `elevation` DOUBLE, `velocity` DOUBLE, `heading` DOUBLE, `grade` DOUBLE, `fuel_consumption` DOUBLE) TAGS (`name` VARCHAR(30), `fleet` VARCHAR(30), `driver` VARCHAR(30), `model` VARCHAR(30), `device_version` VARCHAR(30), `load_capacity` DOUBLE, `fuel_capacity` DOUBLE, `nominal_fuel_consumption` DOUBLE)
// CREATE STABLE `diagnostics` (`ts` TIMESTAMP, `fuel_state` DOUBLE, `current_load` DOUBLE, `status` BIGINT) TAGS (`name` VARCHAR(30), `fleet` VARCHAR(30), `driver` VARCHAR(30), `model` VARCHAR(30), `device_version` VARCHAR(30), `load_capacity` DOUBLE, `fuel_capacity` DOUBLE, `nominal_fuel_consumption` DOUBLE)
// create stable cpu (ts timestamp,usage_user bigint,usage_system bigint,usage_idle bigint,usage_nice bigint,usage_iowait bigint,usage_irq bigint,usage_softirq bigint,usage_steal bigint,usage_guest bigint,usage_guest_nice bigint)
func getBytesBuffer() *bytes.Buffer {
	return bufferPool.Get().(*bytes.Buffer)
}

func putBytesBuffer(buf *bytes.Buffer) {
	buf.Reset()
	bufferPool.Put(buf)
}

type Serializer struct {
	tmpBuf       *bytes.Buffer
	tableMap     map[string]struct{}
	tableMapSafe sync.Map
	superTable   map[string]*Table
}

var tmpMD5Safe = sync.Map{}
var md5Locker = sync.RWMutex{}
var tmpIndexSafe = 0

func calculateTableSafe(src []byte) string {
	key := BytesToString(src)
	v, exist := tmpMD5Safe.Load(src)
	if exist {
		return v.(string)
	}
	md5Locker.Lock()
	defer md5Locker.Unlock()
	v, exist = tmpMD5Safe.Load(src)
	if exist {
		return v.(string)
	}
	tmpIndexSafe += 1
	vs := fmt.Sprintf("t_%d", tmpIndexSafe)
	tmpMD5Safe.Store(key, vs)
	return vs
}

const cpuSql = "2,cpu,cpu,create stable cpu (" +
	"ts timestamp," +
	"usage_user bigint," +
	"usage_system bigint," +
	"usage_idle bigint," +
	"usage_nice bigint," +
	"usage_iowait bigint," +
	"usage_irq bigint," +
	"usage_softirq bigint," +
	"usage_steal bigint," +
	"usage_guest bigint," +
	"usage_guest_nice bigint) " +
	"tags (" +
	"hostname varchar(30)," +
	"region varchar(30)," +
	"datacenter varchar(30)," +
	"rack varchar(30)," +
	"os varchar(30)," +
	"arch varchar(30)," +
	"team varchar(30)," +
	"service varchar(30)," +
	"service_version varchar(30)," +
	"service_environment varchar(30))\n"
const readingsSql = "2,readings,readings,CREATE STABLE `readings` (" +
	"`ts` TIMESTAMP, " +
	"`latitude` DOUBLE, " +
	"`longitude` DOUBLE, " +
	"`elevation` DOUBLE, " +
	"`velocity` DOUBLE, " +
	"`heading` DOUBLE, " +
	"`grade` DOUBLE, " +
	"`fuel_consumption` DOUBLE) " +
	"TAGS (" +
	"`name` VARCHAR(30), " +
	"`fleet` VARCHAR(30), " +
	"`driver` VARCHAR(30), " +
	"`model` VARCHAR(30), " +
	"`device_version` VARCHAR(30), " +
	"`load_capacity` DOUBLE, " +
	"`fuel_capacity` DOUBLE, " +
	"`nominal_fuel_consumption` DOUBLE)\n"

const diagnosticsSql = "2,diagnostics,diagnostics,CREATE STABLE `diagnostics` (" +
	"`ts` TIMESTAMP, " +
	"`fuel_state` DOUBLE, " +
	"`current_load` DOUBLE, " +
	"`status` BIGINT) " +
	"TAGS (" +
	"`name` VARCHAR(30), " +
	"`fleet` VARCHAR(30), " +
	"`driver` VARCHAR(30), " +
	"`model` VARCHAR(30), " +
	"`device_version` VARCHAR(30), " +
	"`load_capacity` DOUBLE, " +
	"`fuel_capacity` DOUBLE, " +
	"`nominal_fuel_consumption` DOUBLE)\n"

func (s *Serializer) Supported(use string) bool {
	switch use {
	case common.UseCaseCPUOnly, common.UseCaseCPUSingle, common.UseCaseIoT:
		return true
	}
	return false
}
func (s *Serializer) PrePare(use string) string {
	switch use {
	case common.UseCaseCPUOnly, common.UseCaseCPUSingle:
		s.superTable = map[string]*Table{
			"cpu": {
				sortColumns: map[string]int{
					"usage_user":       0,
					"usage_system":     1,
					"usage_idle":       2,
					"usage_nice":       3,
					"usage_iowait":     4,
					"usage_irq":        5,
					"usage_softirq":    6,
					"usage_steal":      7,
					"usage_guest":      8,
					"usage_guest_nice": 9,
				},
				valueBase: []string{
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
				},
				sortTags: map[string]int{
					"hostname":            0,
					"region":              1,
					"datacenter":          2,
					"rack":                3,
					"os":                  4,
					"arch":                5,
					"team":                6,
					"service":             7,
					"service_version":     8,
					"service_environment": 9,
				},
				tagBase: []string{
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
				},
			},
		}
		return cpuSql
	case common.UseCaseIoT:
		s.superTable = map[string]*Table{
			"readings": {
				sortColumns: map[string]int{
					"latitude":         0,
					"longitude":        1,
					"elevation":        2,
					"velocity":         3,
					"heading":          4,
					"grade":            5,
					"fuel_consumption": 6,
				},
				valueBase: []string{
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
				},
				sortTags: map[string]int{
					"name":                     0,
					"fleet":                    1,
					"driver":                   2,
					"model":                    3,
					"device_version":           4,
					"load_capacity":            5,
					"fuel_capacity":            6,
					"nominal_fuel_consumption": 7,
				},
				tagBase: []string{
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
				},
			},
			"diagnostics": {
				sortColumns: map[string]int{
					"fuel_state":   0,
					"current_load": 1,
					"status":       2,
				},
				valueBase: []string{
					"null",
					"null",
					"null",
				},
				sortTags: map[string]int{
					"name":                     0,
					"fleet":                    1,
					"driver":                   2,
					"model":                    3,
					"device_version":           4,
					"load_capacity":            5,
					"fuel_capacity":            6,
					"nominal_fuel_consumption": 7,
				},
				tagBase: []string{
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
					"null",
				},
			},
		}
		return readingsSql + diagnosticsSql
	default:
		return ""
	}
}

func (s *Serializer) SerializeConcurrent(points []*data.Point) ([]byte, []byte, error) {
	highLevelSql := &bytes.Buffer{}
	tmpBuf := getBytesBuffer()
	sqlBuilder := &bytes.Buffer{}
	defer putBytesBuffer(tmpBuf)
	for i := 0; i < len(points); i++ {
		p := points[i]
		if p.MeasurementName() == nil {
			break
		}
		tmpBuf.Reset()
		tKeys := p.TagKeys()
		tValues := p.TagValues()
		fKeys := p.FieldKeys()
		fValues := p.FieldValues()
		superTable := string(p.MeasurementName())

		rule, exist := tbRuleMap[superTable]
		if !exist {
			log.Fatalf("table: %s rule not found", superTable)
		}
		fixedName := ""
		for index, value := range tValues {
			if rule != nil && len(fixedName) == 0 && BytesToString(tKeys[index]) == rule.tag {
				str, is := value.(string)
				if is {
					fixedName = str
				}
			}
		}

		subTable := ""
		if rule != nil {
			if len(fixedName) != 0 {
				if len(rule.prefix) == 0 {
					subTable = fixedName
				} else {
					tmpBuf.WriteString(rule.prefix)
					tmpBuf.WriteString(fixedName)
					subTable = tmpBuf.String()
					tmpBuf.Reset()
				}
			} else {
				subTable = rule.nilValue
			}
		}
		stable, exist := s.superTable[superTable]
		if !exist {
			log.Fatalf("table: %s not found", superTable)
		}
		var colValues = make([]string, len(stable.sortColumns))
		copy(colValues, stable.valueBase)
		for index, key := range fKeys {
			colIndex, exist := stable.sortColumns[BytesToString(key)]
			if !exist {
				log.Fatalf("stable: %s column: %s not found", superTable, key)
			}
			tmpBuf.Reset()
			FastFormat(tmpBuf, fValues[index])
			colValues[colIndex] = tmpBuf.String()
		}
		tmpBuf.Reset()
		_, exist = s.tableMapSafe.LoadOrStore(subTable, nothing)
		if !exist {
			var tagValues = make([]string, len(stable.sortTags))
			copy(tagValues, stable.tagBase)
			for index, key := range tKeys {
				tagIndex, exist := stable.sortTags[BytesToString(key)]
				if !exist {
					log.Fatalf("stable: %s tag: %s not found", superTable, key)
				}
				tmpBuf.Reset()
				FastFormat(tmpBuf, tValues[index])
				tagValues[tagIndex] = tmpBuf.String()
			}
			tmpBuf.Reset()
			for index, value := range tagValues {
				tmpBuf.WriteString(value)
				if index != len(tagValues)-1 {
					tmpBuf.WriteByte(',')
				}
			}
			fmt.Fprintf(highLevelSql, "%c,%s,%s,create table %s using %s tags (%s)\n", CreateSubTable, superTable, subTable, subTable, superTable, tmpBuf.String())
			tmpBuf.Reset()
		}
		fmt.Fprintf(sqlBuilder, "%c,%s,%d,(%d,%s)\n", Insert, subTable, len(colValues), p.TimestampInUnixMs(), strings.Join(colValues, ","))
	}
	return sqlBuilder.Bytes(), highLevelSql.Bytes(), nil
}

func BytesToString(b []byte) string {
	return *(*string)(unsafe.Pointer(&b))
}

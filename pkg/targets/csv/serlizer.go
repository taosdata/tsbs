package csv

import (
	"compress/gzip"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"path"
	"strconv"
	"unsafe"

	"github.com/taosdata/tsbs/pkg/data"
)

type Table struct {
	Fields    []string
	FieldInfo map[string]*Field
	FileName  string
	MetaName  string
}

type Field struct {
	Id int
}

var cpuTable = &Table{
	Fields: []string{
		"ts",
		"usage_user",
		"usage_system",
		"usage_idle",
		"usage_nice",
		"usage_iowait",
		"usage_irq",
		"usage_softirq",
		"usage_steal",
		"usage_guest",
		"usage_guest_nice",
		"hostname",
		"region",
		"datacenter",
		"rack",
		"os",
		"arch",
		"team",
		"service",
		"service_version",
		"service_environment",
	},
	FileName: "cpu.csv.gz",
	MetaName: "cpu_meta.json",
}

var readingsTable = &Table{
	Fields: []string{
		"ts",
		"latitude",
		"longitude",
		"elevation",
		"velocity",
		"heading",
		"grade",
		"fuel_consumption",
		"name",
		"fleet",
		"driver",
		"model",
		"device_version",
		"load_capacity",
		"fuel_capacity",
		"nominal_fuel_consumption",
	},
	FileName: "readings.csv.gz",
	MetaName: "readings_meta.json",
}

var diagnosticsTable = &Table{
	Fields: []string{
		"ts",
		"fuel_state",
		"current_load",
		"status",
		"name",
		"fleet",
		"driver",
		"model",
		"device_version",
		"load_capacity",
		"fuel_capacity",
		"nominal_fuel_consumption",
	},
	FileName: "diagnostics.csv.gz",
	MetaName: "diagnostics_meta.json",
}

const (
	CpuIndex         = 0
	ReadingIndex     = 1
	DiagnosticsIndex = 2
)

var tables = [3]*Table{
	cpuTable,
	readingsTable,
	diagnosticsTable,
}

var metricNames = [3]string{
	"cpu",
	"readings",
	"diagnostics",
}

type Serializer struct {
	files     [3]*os.File
	gzWriter  [3]*gzip.Writer
	csvWriter [3]*csv.Writer
	totalRows [3]uint64
	outDir    string
}

func FastFormat(v interface{}) string {
	switch v.(type) {
	case int:
		return strconv.Itoa(v.(int))
	case int64:
		return strconv.FormatInt(v.(int64), 10)
	case float64:
		return strconv.FormatFloat(v.(float64), 'f', -1, 64)
	case float32:
		return strconv.FormatFloat(float64(v.(float32)), 'f', -1, 32)
	case bool:
		return strconv.FormatBool(v.(bool))
	case []byte:
		return ToUnsafeString(v.([]byte))
	case string:
		return v.(string)
	case nil:
		return ""
	default:
		panic(fmt.Sprintf("unknown field type for %#v", v))
	}
}

func (s *Serializer) Serialize(p *data.Point, w io.Writer) (err error) {
	measurement := ToUnsafeString(p.MeasurementName())
	measurementIndex := -1
	var writer *csv.Writer
	var table *Table
	switch measurement {
	case "cpu":
		measurementIndex = CpuIndex
	case "readings":
		measurementIndex = ReadingIndex
	case "diagnostics":
		measurementIndex = DiagnosticsIndex
	default:
		log.Panicf("unknown measurement: %s", measurement)
	}
	writer = s.csvWriter[measurementIndex]
	if writer == nil {
		err = s.open(measurementIndex)
		if err != nil {
			return err
		}
		writer = s.csvWriter[measurementIndex]
	}
	table = tables[measurementIndex]

	values := make([]string, len(table.FieldInfo))
	tags := p.TagKeys()
	tagValues := p.TagValues()
	field := p.FieldKeys()
	fieldValues := p.FieldValues()
	values[0] = strconv.FormatInt(p.TimestampInUnixMs(), 10)
	for i := 0; i < len(tags); i++ {
		fieldInfo, ok := table.FieldInfo[ToUnsafeString(tags[i])]
		if !ok {
			panic(fmt.Sprintf("unknown field type for %s", ToUnsafeString(tags[i])))
		}
		v := FastFormat(tagValues[i])
		values[fieldInfo.Id] = v
	}
	for i := 0; i < len(field); i++ {
		fieldInfo, ok := table.FieldInfo[ToUnsafeString(field[i])]
		if !ok {
			panic(fmt.Sprintf("unknown field type for %s", ToUnsafeString(field[i])))
		}
		v := FastFormat(fieldValues[i])
		values[fieldInfo.Id] = v
	}
	err = writer.Write(values)
	if err != nil {
		return fmt.Errorf("cannot write to csv: %v, values: %v", err, values)
	}
	s.totalRows[measurementIndex] += 1
	return nil
}

func (s *Serializer) Close() error {
	for i := 0; i < 3; i++ {
		if s.csvWriter[i] != nil {
			fmt.Printf("generate %d rows for %s\n", s.totalRows[i], metricNames[i])
			s.csvWriter[i].Flush()
			err := s.gzWriter[i].Flush()
			if err != nil {
				return fmt.Errorf("cannot flush gzip writer: %v", err)
			}
			err = s.gzWriter[i].Close()
			if err != nil {
				return fmt.Errorf("cannot close gzip writer: %v", err)
			}
		}
	}
	return nil
}

type Meta struct {
	Parse map[string]*ParseField `json:"parse"`
	Model *Model                 `json:"model"`
}

type ParseField struct {
	As string `json:"as"`
}

type Model struct {
	Name    string   `json:"name"`
	Using   string   `json:"using"`
	Tags    []string `json:"tags"`
	Columns []string `json:"columns"`
}

var cpuMeta = &Meta{
	Parse: map[string]*ParseField{
		"ts":                  {As: "TIMESTAMP(ms)"},
		"usage_user":          {As: "BIGINT"},
		"usage_system":        {As: "BIGINT"},
		"usage_idle":          {As: "BIGINT"},
		"usage_nice":          {As: "BIGINT"},
		"usage_iowait":        {As: "BIGINT"},
		"usage_irq":           {As: "BIGINT"},
		"usage_softirq":       {As: "BIGINT"},
		"usage_steal":         {As: "BIGINT"},
		"usage_guest":         {As: "BIGINT"},
		"usage_guest_nice":    {As: "BIGINT"},
		"hostname":            {As: "VARCHAR(30)"},
		"region":              {As: "VARCHAR(30)"},
		"datacenter":          {As: "VARCHAR(30)"},
		"rack":                {As: "VARCHAR(30)"},
		"os":                  {As: "VARCHAR(30)"},
		"arch":                {As: "VARCHAR(30)"},
		"team":                {As: "VARCHAR(30)"},
		"service":             {As: "VARCHAR(30)"},
		"service_version":     {As: "VARCHAR(30)"},
		"service_environment": {As: "VARCHAR(30)"},
	},
	Model: &Model{
		Name:  "host_${hostname}",
		Using: "host",
		Tags: []string{
			"hostname",
			"region",
			"datacenter",
			"rack",
			"os",
			"arch",
			"team",
			"service",
			"service_version",
			"service_environment",
		},
		Columns: []string{
			"ts",
			"usage_user",
			"usage_system",
			"usage_idle",
			"usage_nice",
			"usage_iowait",
			"usage_irq",
			"usage_softirq",
			"usage_steal",
			"usage_guest",
			"usage_guest_nice",
		},
	},
}

var readingMeta = &Meta{
	Parse: map[string]*ParseField{
		"ts":                       {As: "TIMESTAMP(ms)"},
		"latitude":                 {As: "DOUBLE"},
		"longitude":                {As: "DOUBLE"},
		"elevation":                {As: "DOUBLE"},
		"velocity":                 {As: "DOUBLE"},
		"heading":                  {As: "DOUBLE"},
		"grade":                    {As: "DOUBLE"},
		"fuel_consumption":         {As: "DOUBLE"},
		"name":                     {As: "VARCHAR(30)"},
		"fleet":                    {As: "VARCHAR(30)"},
		"driver":                   {As: "VARCHAR(30)"},
		"model":                    {As: "VARCHAR(30)"},
		"device_version":           {As: "VARCHAR(30)"},
		"load_capacity":            {As: "DOUBLE"},
		"fuel_capacity":            {As: "DOUBLE"},
		"nominal_fuel_consumption": {As: "DOUBLE"},
	},
	Model: &Model{
		Name:  "r_${name}",
		Using: "readings",
		Tags: []string{
			"name",
			"fleet",
			"driver",
			"model",
			"device_version",
			"load_capacity",
			"fuel_capacity",
			"nominal_fuel_consumption",
		},
		Columns: []string{
			"ts",
			"latitude",
			"longitude",
			"elevation",
			"velocity",
			"heading",
			"grade",
			"fuel_consumption",
		},
	},
}

var diagnosticsMeta = &Meta{
	Parse: map[string]*ParseField{
		"ts":                       {As: "TIMESTAMP(ms)"},
		"fuel_state":               {As: "DOUBLE"},
		"current_load":             {As: "DOUBLE"},
		"status":                   {As: "BIGINT"},
		"name":                     {As: "VARCHAR(30)"},
		"fleet":                    {As: "VARCHAR(30)"},
		"driver":                   {As: "VARCHAR(30)"},
		"model":                    {As: "VARCHAR(30)"},
		"device_version":           {As: "VARCHAR(30)"},
		"load_capacity":            {As: "DOUBLE"},
		"fuel_capacity":            {As: "DOUBLE"},
		"nominal_fuel_consumption": {As: "DOUBLE"},
	},
	Model: &Model{
		Name:  "d_${name}",
		Using: "diagnostics",
		Tags: []string{
			"name",
			"fleet",
			"driver",
			"model",
			"device_version",
			"load_capacity",
			"fuel_capacity",
			"nominal_fuel_consumption",
		},
		Columns: []string{
			"ts",
			"fuel_state",
			"current_load",
			"status",
		},
	},
}

var metas = [3]*Meta{
	cpuMeta,
	readingMeta,
	diagnosticsMeta,
}

func (s *Serializer) open(measurement int) error {
	if s.outDir != "" {
		err := os.MkdirAll(s.outDir, 0755)
		if err != nil {
			return fmt.Errorf("cannot create output directory %s: %v", s.outDir, err)
		}
	}
	table := tables[measurement]
	csvPath := path.Join(s.outDir, table.FileName)
	f, err := os.Create(csvPath)
	if err != nil {
		return fmt.Errorf("cannot open file for write %s: %v", csvPath, err)
	}
	s.files[measurement] = f
	gzWriter := gzip.NewWriter(f)
	s.gzWriter[measurement] = gzWriter
	csvWriter := csv.NewWriter(gzWriter)
	s.csvWriter[measurement] = csvWriter
	err = csvWriter.Write(table.Fields)
	if err != nil {
		return fmt.Errorf("cannot write csv header: %v", err)
	}
	meta := metas[measurement]
	metaPath := path.Join(s.outDir, table.MetaName)
	metaFile, err := os.Create(metaPath)
	if err != nil {
		return fmt.Errorf("cannot create file for write %s: %v", metaPath, err)
	}
	defer metaFile.Close()
	bs, err := json.Marshal(meta)
	if err != nil {
		return fmt.Errorf("cannot marshal meta: %v", err)
	}
	_, err = metaFile.Write(bs)
	if err != nil {
		return fmt.Errorf("cannot write meta: %v", err)
	}
	return nil
}

func ToUnsafeString(b []byte) string {
	return *(*string)(unsafe.Pointer(&b))
}

func init() {
	// init field info
	cpuTable.FieldInfo = make(map[string]*Field, len(cpuTable.Fields))
	for i, field := range cpuTable.Fields {
		cpuTable.FieldInfo[field] = &Field{Id: i}
	}
	readingsTable.FieldInfo = make(map[string]*Field, len(readingsTable.Fields))
	for i, field := range readingsTable.Fields {
		readingsTable.FieldInfo[field] = &Field{Id: i}
	}
	diagnosticsTable.FieldInfo = make(map[string]*Field, len(diagnosticsTable.Fields))
	for i, field := range diagnosticsTable.Fields {
		diagnosticsTable.FieldInfo[field] = &Field{Id: i}
	}
}

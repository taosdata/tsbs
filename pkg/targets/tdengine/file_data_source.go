package tdengine

import (
	"bufio"
	"strconv"
	"strings"

	taosTypes "github.com/taosdata/driver-go/v3/types"
	"github.com/taosdata/tsbs/load"
	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/data/usecases/common"
	"github.com/taosdata/tsbs/pkg/targets"
)

func newFileDataSource(fileName string) targets.DataSource {
	br := load.GetBufferedReader(fileName)

	return &fileDataSource{scanner: bufio.NewScanner(br)}
}

type fileDataSource struct {
	scanner *bufio.Scanner
	headers *common.GeneratedDataHeaders
}

func (d *fileDataSource) Headers() *common.GeneratedDataHeaders {
	return nil
}

func (d *fileDataSource) NextItem() data.LoadedPoint {
	ok := d.scanner.Scan()
	if !ok && d.scanner.Err() == nil { // nothing scanned & no error = EOF
		return data.LoadedPoint{}
	} else if !ok {
		fatal("scan error: %v", d.scanner.Err())
		return data.LoadedPoint{}
	}
	p := &point{}
	line := d.scanner.Text()
	p.sqlType = line[0]
	switch line[0] {
	case Insert:
		parts := strings.SplitN(line, ",", 4)
		p.subTable = parts[1]
		p.fieldCount, _ = strconv.Atoi(parts[2])
		p.values = parts[3]
	case CreateSTable:
		parts := strings.SplitN(line, ",", 4)
		p.superTable = parts[1]
		p.subTable = parts[2]
		p.sql = parts[3]
		ok = d.scanner.Scan()
		if !ok {
			panic(d.scanner.Err())
		}
		types := d.scanner.Bytes()

		stableTypesLocker.Lock()
		for i := 0; i < len(types); i++ {
			switch types[i] {
			case TypeInt:
				stableTypes[p.superTable] = append(stableTypes[p.superTable], &taosTypes.ColumnType{Type: taosTypes.TaosBigintType})
			case TypeTS:
				stableTypes[p.superTable] = append(stableTypes[p.superTable], &taosTypes.ColumnType{Type: taosTypes.TaosTimestampType})
			case TypeDouble:
				stableTypes[p.superTable] = append(stableTypes[p.superTable], &taosTypes.ColumnType{Type: taosTypes.TaosDoubleType})
			case TypeBool:
				stableTypes[p.superTable] = append(stableTypes[p.superTable], &taosTypes.ColumnType{Type: taosTypes.TaosBoolType})
			case TypeString:
				stableTypes[p.superTable] = append(stableTypes[p.superTable], &taosTypes.ColumnType{
					Type:   taosTypes.TaosBinaryType,
					MaxLen: 30,
				})
			}
		}
		stableTypesLocker.Unlock()

	case CreateSubTable:
		parts := strings.SplitN(line, ",", 4)
		p.superTable = parts[1]
		p.subTable = parts[2]
		p.sql = parts[3]
		subTableStableMap.Store(p.subTable, p.superTable)
	default:
		panic(line)
	}
	return data.NewLoadedPoint(p)
}

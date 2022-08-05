package tdengine

import (
	"encoding/gob"
	"io"
	"os"

	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/data/usecases/common"
	"github.com/taosdata/tsbs/pkg/targets"
)

func newFileDataSource(fileName string) targets.DataSource {
	var decoder *gob.Decoder
	if len(fileName) == 0 {
		// Read from STDIN
		decoder = gob.NewDecoder(os.Stdin)
	} else {
		file, err := os.Open(fileName)
		if err != nil {
			fatal("cannot open file for read %s: %v", fileName, err)
			return nil
		}
		decoder = gob.NewDecoder(file)
	}

	return &fileDataSource{decoder: decoder}
}

type fileDataSource struct {
	decoder *gob.Decoder
	headers *common.GeneratedDataHeaders
}

func (d *fileDataSource) Headers() *common.GeneratedDataHeaders {
	return nil
}

func (d *fileDataSource) NextItem() data.LoadedPoint {
	var p = point{}
	err := d.decoder.Decode(&p)
	if err != nil {
		if err == io.EOF {
			return data.LoadedPoint{}
		} else {
			fatal("gob decode error: %v", err)
			return data.LoadedPoint{}
		}
	}
	return data.NewLoadedPoint(&p)
	//ok := d.scanner.Scan()
	//if !ok && d.scanner.Err() == nil { // nothing scanned & no error = EOF
	//	return data.LoadedPoint{}
	//} else if !ok {
	//	fatal("scan error: %v", d.scanner.Err())
	//	return data.LoadedPoint{}
	//}
	//p := &point{}
	//line := d.scanner.Text()
	//p.SqlType = line[0]
	//switch line[0] {
	//case Insert:
	//	parts := strings.SplitN(line, ",", 4)
	//	p.SubTable = parts[1]
	//	p.FieldCount, _ = strconv.Atoi(parts[2])
	//	p.Values = parts[3]
	//case CreateSTable:
	//	parts := strings.SplitN(line, ",", 4)
	//	p.SuperTable = parts[1]
	//	p.SubTable = parts[2]
	//	p.Sql = parts[3]
	//	ok = d.scanner.Scan()
	//	if !ok {
	//		panic(d.scanner.Err())
	//	}
	//	types := d.scanner.Bytes()
	//
	//	stableTypesLocker.Lock()
	//	for i := 0; i < len(types); i++ {
	//		switch types[i] {
	//		case TypeInt:
	//			stableTypes[p.SuperTable] = append(stableTypes[p.SuperTable], &taosTypes.ColumnType{Type: taosTypes.TaosBigintType})
	//		case TypeTS:
	//			stableTypes[p.SuperTable] = append(stableTypes[p.SuperTable], &taosTypes.ColumnType{Type: taosTypes.TaosTimestampType})
	//		case TypeDouble:
	//			stableTypes[p.SuperTable] = append(stableTypes[p.SuperTable], &taosTypes.ColumnType{Type: taosTypes.TaosDoubleType})
	//		case TypeBool:
	//			stableTypes[p.SuperTable] = append(stableTypes[p.SuperTable], &taosTypes.ColumnType{Type: taosTypes.TaosBoolType})
	//		case TypeString:
	//			stableTypes[p.SuperTable] = append(stableTypes[p.SuperTable], &taosTypes.ColumnType{
	//				Type:   taosTypes.TaosBinaryType,
	//				MaxLen: 30,
	//			})
	//		}
	//	}
	//	stableTypesLocker.Unlock()
	//
	//case CreateSubTable:
	//	parts := strings.SplitN(line, ",", 4)
	//	p.SuperTable = parts[1]
	//	p.SubTable = parts[2]
	//	p.Sql = parts[3]
	//	subTableStableMap.Store(p.SubTable, p.SuperTable)
	//default:
	//	panic(line)
	//}
	//return data.NewLoadedPoint(p)
}

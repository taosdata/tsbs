package tdenginerest

import (
	"bufio"
	"bytes"
	"strconv"

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

var sep = []byte{','}

func (d *fileDataSource) NextItem() data.LoadedPoint {
	ok := d.scanner.Scan()
	if !ok && d.scanner.Err() == nil { // nothing scanned & no error = EOF
		return data.LoadedPoint{}
	} else if !ok {
		fatal("scan error: %v", d.scanner.Err())
		return data.LoadedPoint{}
	}
	p := &point{}
	line := d.scanner.Bytes()
	p.sqlType = line[0]
	switch line[0] {
	case Insert:
		parts := bytes.SplitN(line, sep, 4)
		p.subTable = string(parts[1])
		p.fieldCount, _ = strconv.Atoi(string(parts[2]))
		p.sql = make([]byte, len(parts[3]))
		copy(p.sql, parts[3])
	case CreateSTable:
		parts := bytes.SplitN(line, sep, 4)
		p.superTable = string(parts[1])
		p.subTable = string(parts[2])
		p.sql = make([]byte, len(parts[3]))
		copy(p.sql, parts[3])
	case CreateSubTable:
		parts := bytes.SplitN(line, sep, 4)
		p.superTable = string(parts[1])
		p.subTable = string(parts[2])
		p.sql = make([]byte, len(parts[3])-12)
		copy(p.sql, parts[3][12:])
	default:
		panic(line)
	}
	return data.NewLoadedPoint(p)
}

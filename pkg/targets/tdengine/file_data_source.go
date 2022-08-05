package tdengine

import (
	"bufio"
	"strconv"
	"strings"

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
	p.SqlType = line[0]
	var err error
	switch line[0] {
	case Insert:
		parts := strings.SplitN(line, ",", 4)
		p.Metrics, err = strconv.Atoi(parts[1])
		if err != nil {
			panic(err)
		}
		p.SubTable = parts[2]
		p.Values = parts[3]
	case CreateSTable:
		parts := strings.SplitN(line, ",", 4)
		p.SuperTable = parts[1]
		p.SubTable = parts[2]
		p.Sql = parts[3]
	case CreateSubTable:
		parts := strings.SplitN(line, ",", 4)
		p.SuperTable = parts[1]
		p.SubTable = parts[2]
		p.Sql = parts[3]
	default:
		panic(line)
	}
	return data.NewLoadedPoint(p)
}

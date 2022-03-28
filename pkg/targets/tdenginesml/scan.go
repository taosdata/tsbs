package tdenginesml

import "C"
import (
	"bufio"
	"log"
	"strings"

	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/data/usecases/common"
	"github.com/taosdata/tsbs/pkg/targets"
)

const errNotThreeTuplesFmt = "parse error: line does not have 3 tuples, has %d"

var fatal = log.Fatalf

type fileDataSource struct {
	scanner *bufio.Scanner
}

func (d *fileDataSource) NextItem() data.LoadedPoint {
	ok := d.scanner.Scan()
	if !ok && d.scanner.Err() == nil { // nothing scanned & no error = EOF
		return data.LoadedPoint{}
	} else if !ok {
		fatal("scan error: %v", d.scanner.Err())
		return data.LoadedPoint{}
	}
	return data.NewLoadedPoint(d.scanner.Bytes())
}

func (d *fileDataSource) Headers() *common.GeneratedDataHeaders { return nil }

type batch struct {
	lines   []string
	rows    uint
	metrics uint64
}

func (b *batch) Len() uint {
	return b.rows
}

func (b *batch) Append(item data.LoadedPoint) {
	that := item.Data.([]byte)
	thatStr := string(that)
	b.rows++
	args := strings.Split(thatStr, " ")
	if len(args) != 3 {
		fatal(errNotThreeTuplesFmt, len(args))
		return
	}
	b.metrics += uint64(len(strings.Split(args[1], ",")))
	b.lines = append(b.lines, string(that))
}

type factory struct{}

func (f *factory) New() targets.Batch {
	return &batch{}
}

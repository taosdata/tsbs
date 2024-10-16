package tdenginestmt2

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"io"
	"log"
	"sync"
	"unsafe"

	"github.com/taosdata/tsbs/load"
	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/data/usecases/common"
	"github.com/taosdata/tsbs/pkg/targets"
)

var fatal = log.Fatalf

func newFileDataSource(fileName string) targets.DataSource {
	br := load.GetBufferedReader(fileName)
	return &fileDataSource{br: br, tmpBuf: &bytes.Buffer{}}
}

type fileDataSource struct {
	br        *bufio.Reader
	tmpBuf    *bytes.Buffer
	cacheData []*point
	scale     int
	maxCache  int
}

/*
 fixed header

| version(1 byte) | case (1 byte) | scale (4 bytes)

*/

func (d *fileDataSource) Init() (byte, uint32) {
	buf := make([]byte, 6)
	_, err := io.ReadFull(d.br, buf)
	if err != nil {
		fatal("cannot read header: %v", err)
	}
	if buf[0] != 1 {
		fatal("invalid version: %d", buf[0])
	}
	scale := binary.LittleEndian.Uint32(buf[2:])
	d.scale = int(scale)
	return buf[1], scale
}

func (d *fileDataSource) PreReadCreateTable() []*point {
	var commandType byte
	var err error
	var createTableSqls []*point
	for {
		if len(createTableSqls) == d.scale || len(d.cacheData) >= d.maxCache {
			break
		}
		commandType, err = d.br.ReadByte()
		if err != nil {
			if err == io.EOF {
				break
			} else {
				fatal("cannot read command type: %v", err)
			}
		}
		switch commandType {
		case CreateTable:
			p := d.parseCreateTableCommand()
			createTableSqls = append(createTableSqls, p)
		case InsertData:
			p := d.parseInsertDataCommand()
			d.cacheData = append(d.cacheData, p)
		default:
			fatal("invalid command type:%d", commandType)
		}
	}
	return createTableSqls
}

var bytesPool = sync.Pool{
	New: func() interface{} {
		return make([]byte, 95)
	},
}

/*

  create table sql

  | type (1 byte,1) | table type(1 byte) | table index (uint32 4 bytes) | sql length (2 bytes,uint16) | sql buffer |
*/

func (d *fileDataSource) parseCreateTableCommand() *point {
	// table type
	tableType, err := d.br.ReadByte()
	if err != nil {
		panic(err)
	}
	var tableIndex uint32
	err = binary.Read(d.br, binary.LittleEndian, &tableIndex)
	if err != nil {
		panic(err)
	}
	// sql
	var sqlLen uint16
	err = binary.Read(d.br, binary.LittleEndian, &sqlLen)
	if err != nil {
		panic(err)
	}
	sql := make([]byte, sqlLen)
	_, err = io.ReadFull(d.br, sql)
	if err != nil {
		panic(err)
	}
	p := getPoint()
	p.commandType = CreateTable
	p.tableType = tableType
	p.tableIndex = tableIndex
	p.data = sql
	return p
}

/*
  insert data
  | type (1 byte,2) | table type(1 byte) | table index (uint32 4 bytes)
  | duplicate (bool 1 byte)
  | is null bit | column data|
*/

func (d *fileDataSource) parseInsertDataCommand() *point {
	// table type
	tableType, err := d.br.ReadByte()
	if err != nil {
		panic(err)
	}
	bufLength := 0
	switch tableType {
	case SuperTableHost:
		bufLength = 95
	case SuperTableReadings:
		bufLength = 70
	case SuperTableDiagnostics:
		bufLength = 38
	default:
		panic("invalid table type")
	}
	buf := bytesPool.Get().([]byte)
	buf = buf[:bufLength]
	_, err = io.ReadFull(d.br, buf)
	if err != nil {
		panic(err)
	}
	// table index
	tableIndex := *(*uint32)(unsafe.Pointer(&buf[0]))
	p := getPoint()
	p.commandType = InsertData
	p.tableType = tableType
	p.tableIndex = tableIndex
	p.duplicate = buf[4] == 1
	p.data = buf
	return p
}

func (d *fileDataSource) Headers() *common.GeneratedDataHeaders {
	return nil
}

func (d *fileDataSource) NextItem() data.LoadedPoint {
	if len(d.cacheData) > 0 {
		p := d.cacheData[0]
		d.cacheData = d.cacheData[1:]
		return data.NewLoadedPoint(p)
	}
	commandType, err := d.br.ReadByte()
	if err != nil {
		if err == io.EOF {
			return data.LoadedPoint{}
		}
		panic(err)
	}
	var p *point
	switch commandType {
	case CreateTable:
		p = d.parseCreateTableCommand()
	case InsertData:
		p = d.parseInsertDataCommand()
	default:
		log.Fatalf("invalid command type:%d", commandType)
	}
	return data.NewLoadedPoint(p)
}

package tdenginestmt2

import (
	"bufio"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/data/usecases/common"
	"github.com/taosdata/tsbs/pkg/targets"
)

var fatal = log.Fatalf

func newFileDataSource(fileName string) targets.DataSource {
	//br := GetBufferedReader(fileName)
	f := GetFile(fileName)
	return &fileDataSource{f: f, exchange: make(chan struct{}, 1), exchangeStatus: make(chan int, 1)}
}

const (
	defaultReadSize = 4 << 20 // 4 MB
)

func GetFile(fileName string) *os.File {
	if len(fileName) == 0 {
		return os.Stdin
	}
	file, err := os.Open(fileName)
	if err != nil {
		fatal("cannot open file for read %s: %v", fileName, err)
		return nil
	}
	return file
}

func GetBufferedReader(fileName string) *bufio.Reader {
	if len(fileName) == 0 {
		// Read from STDIN
		return bufio.NewReaderSize(os.Stdin, defaultReadSize)
	}
	// Read from specified file
	file, err := os.Open(fileName)
	if err != nil {
		fatal("cannot open file for read %s: %v", fileName, err)
		return nil
	}
	return bufio.NewReaderSize(file, defaultReadSize)
}

type fileDataSource struct {
	f   *os.File
	buf []byte
	r   int
	w   int
	err error

	readCache      [][]byte
	writeCache     [][]byte
	exchange       chan struct{}
	exchangeStatus chan int
	readDirect     bool
	scale          int
	maxCache       int
}

/*
 fixed header

| version(1 byte) | case (1 byte) | scale (4 bytes)

*/

func (d *fileDataSource) readHeader() (byte, uint32) {
	buf := make([]byte, 6)
	_, err := io.ReadFull(d.f, buf)
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

func (d *fileDataSource) SetMaxCache(max int) {
	d.maxCache = max
	d.readCache = make([][]byte, 0, max)
	d.writeCache = make([][]byte, 0, max)
}

func (d *fileDataSource) FillCache() [][]byte {
	var createTableSqls [][]byte
	for {
		if len(d.readCache) >= d.maxCache {
			break
		}
		p := d.readData()
		if p == nil {
			d.readCache = append(d.readCache, p)
			return createTableSqls
		}
		switch p[0] {
		case CreateTable:
			sql := p[6:]
			createTableSqls = append(createTableSqls, sql)
		case InsertData:
			d.readCache = append(d.readCache, p)
		default:
			fatal("invalid command type:%d", p[0])
		}
	}
	return createTableSqls
}

func (d *fileDataSource) Headers() *common.GeneratedDataHeaders {
	return nil
}

func (d *fileDataSource) NextItem() data.LoadedPoint {
	if len(d.readCache) > 0 {
		p := d.readCache[0]
		d.readCache = d.readCache[1:]
		if p == nil {
			return data.NewLoadedPoint(nil)
		}
		return data.NewLoadedPoint(p)
	}
	if d.readDirect {
		p := d.readData()
		if p == nil {
			return data.NewLoadedPoint(nil)
		}
		return data.NewLoadedPoint(p)
	}
	d.exchange <- struct{}{}
	exchangeStatus := <-d.exchangeStatus
	if exchangeStatus == ExchangeStatusDone {
		p := d.readCache[0]
		d.readCache = d.readCache[1:]
		if p == nil {
			return data.NewLoadedPoint(nil)
		}
		return data.NewLoadedPoint(p)
	}
	if exchangeStatus == ExchangeStatusConsumeTooFast {
		d.readDirect = true
		p := d.readData()
		if p == nil {
			return data.NewLoadedPoint(nil)
		}
		return data.NewLoadedPoint(p)
	}
	if exchangeStatus == ExchangeStatusFinish {
		d.readDirect = true
		p := d.readCache[0]
		d.readCache = d.readCache[1:]
		if p == nil {
			return data.NewLoadedPoint(nil)
		}
		return data.NewLoadedPoint(p)
	}
	return data.NewLoadedPoint(nil)
}

const (
	ExchangeStatusDone           = 0
	ExchangeStatusConsumeTooFast = 1
	ExchangeStatusFinish         = 2
)

func (d *fileDataSource) startLoop() {
	go func() {
		for {
			select {
			case <-d.exchange:
				if len(d.writeCache) == 0 {
					d.exchangeStatus <- ExchangeStatusConsumeTooFast
					return
				}
				d.readCache = d.writeCache
				d.writeCache = make([][]byte, 0, d.maxCache)
				d.exchangeStatus <- ExchangeStatusDone
			default:
				if len(d.writeCache) == d.maxCache {
					<-d.exchange
					d.readCache = d.writeCache
					d.writeCache = make([][]byte, 0, d.maxCache)
					d.exchangeStatus <- ExchangeStatusDone
				}
				rowData := d.readData()
				if rowData == nil {
					d.writeCache = append(d.writeCache, nil)
					<-d.exchange
					d.readCache = d.writeCache
					d.writeCache = nil
					d.exchangeStatus <- ExchangeStatusFinish
					return
				}
				d.writeCache = append(d.writeCache, rowData)
			}
		}
	}()
}

var errNegativeRead = errors.New("reader returned negative count from Read")

func (d *fileDataSource) readData() []byte {
	var n int
	if d.r == d.w {
		if d.err != nil {
			return nil
		}
		d.r = 0
		d.w = 0
		buf := make([]byte, defaultReadSize)
		n, d.err = d.f.Read(buf)
		if n < 0 {
			panic(errNegativeRead)
		}
		if n == 0 {
			if d.err == io.EOF {
				return nil
			}
			panic(d.err)
		}
		d.w = n
		d.buf = buf[:d.w]
	}
	u8length := d.buf[d.r]
	d.r++
	if u8length < 128 {
		if d.r+int(u8length) > d.w {
			buf := make([]byte, defaultReadSize)
			n = copy(buf, d.buf[d.r:d.w])
			d.r = 0
			d.w = n
			for {
				n, d.err = d.f.Read(buf[d.w:])
				if n < 0 {
					panic(errNegativeRead)
				}
				if n == 0 {
					if d.err == io.EOF {
						break
					}
					panic(d.err)
				}
				d.w += n
				if d.w >= int(u8length) {
					break
				}
			}
			d.buf = buf[:d.w]
		}
		end := d.r + int(u8length)
		ret := d.buf[d.r:end]
		d.r += int(u8length)
		if ret[0] != 1 && ret[0] != 2 {
			fmt.Println("readData", ret)
		}
		return ret
	} else {
		if d.r == d.w {
			if d.err != nil {
				return nil
			}
			d.r = 0
			d.w = 0
			buf := make([]byte, defaultReadSize)
			n, d.err = d.f.Read(buf)
			if n < 0 {
				panic(errNegativeRead)
			}
			if n == 0 {
				if d.err == io.EOF {
					return nil
				}
				panic(d.err)
			}
			d.w = n
			d.buf = buf[:d.w]
		}
		u16Length := int(u8length&0x7f) + int(d.buf[d.r]<<7)
		d.r++
		if d.r+u16Length > d.w {
			buf := make([]byte, defaultReadSize)
			n = copy(buf, d.buf[d.r:d.w])
			d.r = 0
			d.w = n
			for {
				n, d.err = d.f.Read(buf[d.w:])
				if n < 0 {
					panic(errNegativeRead)
				}
				if n == 0 {
					if d.err == io.EOF {
						break
					}
					panic(d.err)
				}
				d.w += n
				if d.w >= u16Length {
					break
				}
			}
			d.buf = buf[:d.w]
		}
		ret := d.buf[d.r : d.r+u16Length]
		d.r += u16Length
		if ret[0] != 1 && ret[0] != 2 {
			fmt.Println("readData", ret)
		}
		return ret
	}
}

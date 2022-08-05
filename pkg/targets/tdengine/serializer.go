package tdengine

import (
	"bytes"
	"crypto/md5"
	"database/sql/driver"
	"encoding/gob"
	"encoding/hex"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/cstmt"
)

type Serializer struct {
	encoder    *gob.Encoder
	tmpBuf     *bytes.Buffer
	tableMap   map[string]struct{}
	superTable map[string]*Table
}

var nothing = struct{}{}

type Table struct {
	columns map[string]struct{}
	tags    map[string]struct{}
	types   []byte
}

func FastFormat(buf *bytes.Buffer, v interface{}, write bool) (byte, driver.Value, string) {
	if v == nil {
		if write {
			buf.WriteString("null")
		}
		return cstmt.TypeNull, nil, "null"
	}
	switch vv := v.(type) {
	case int:
		if write {
			buf.WriteString(strconv.Itoa(vv))
		}
		return cstmt.TypeInt, int64(vv), "bigint"
	case int64:
		if write {
			buf.WriteString(strconv.FormatInt(vv, 10))
		}
		return cstmt.TypeInt, vv, "bigint"
	case float64:
		if write {
			buf.WriteString(strconv.FormatFloat(vv, 'f', -1, 64))
		}
		return cstmt.TypeDouble, vv, "double"
	case float32:
		vvv := float64(vv)
		if write {
			buf.WriteString(strconv.FormatFloat(vvv, 'f', -1, 32))
		}
		return cstmt.TypeDouble, vvv, "double"
	case bool:
		if write {
			buf.WriteString(strconv.FormatBool(vv))
		}
		return cstmt.TypeBool, vv, "bool"
	case []byte:
		vvv := string(vv)
		if write {
			buf.WriteByte('\'')
			buf.WriteString(vvv)
			buf.WriteByte('\'')
		}
		return cstmt.TypeString, vvv, "binary(30)"
	case string:
		if write {
			buf.WriteByte('\'')
			buf.WriteString(vv)
			buf.WriteByte('\'')
		}
		return cstmt.TypeString, vv, "binary(30)"
	default:
		panic(fmt.Sprintf("unknown field type for %#v", v))
	}
}

var tmpMD5 = map[string]string{}

func calculateTable(src []byte) string {
	key := string(src)
	v, exist := tmpMD5[key]
	if exist {
		return v
	}
	s := md5.Sum(src)
	v = fmt.Sprintf("t_%s", hex.EncodeToString(s[:]))
	tmpMD5[key] = v
	return v
}

const (
	Insert         = '1'
	CreateSTable   = '2'
	CreateSubTable = '3'
	Modify         = '4'
)

func (s *Serializer) Serialize(p *data.Point, w io.Writer) error {
	if s.encoder == nil {
		s.encoder = gob.NewEncoder(w)
	}
	var fieldKeys []string
	var fieldTypes []string
	var tagValues []string
	var tagKeys []string
	var tagTypes []string
	tKeys := p.TagKeys()
	tValues := p.TagValues()
	fKeys := p.FieldKeys()
	byteTypes := make([]byte, len(fKeys)+1)
	byteTypes[0] = cstmt.TypeTS
	fieldValues := make([]driver.Value, len(fKeys)+1)
	fieldValues[0] = p.TimestampInUnixMs()
	fValues := p.FieldValues()
	superTable := string(p.MeasurementName())
	for i, value := range fValues {
		fieldKeys = append(fieldKeys, convertKeywords(string(fKeys[i])))
		byteType, driverValue, fType := FastFormat(nil, value, false)
		fieldTypes = append(fieldTypes, fType)
		byteTypes[i+1] = byteType
		fieldValues[i+1] = driverValue
	}

	for i, value := range tValues {
		_, _, tType := FastFormat(s.tmpBuf, value, true)
		tagKeys = append(tagKeys, convertKeywords(string(tKeys[i])))
		tagTypes = append(tagTypes, tType)
		tagValues = append(tagValues, s.tmpBuf.String())
		s.tmpBuf.Reset()
	}
	s.tmpBuf.WriteString(superTable)
	for i, v := range tagValues {
		s.tmpBuf.WriteByte(',')
		s.tmpBuf.WriteString(tagKeys[i])
		s.tmpBuf.WriteByte('=')
		s.tmpBuf.WriteString(v)
	}
	subTable := calculateTable(s.tmpBuf.Bytes())
	s.tmpBuf.Reset()
	stable, exist := s.superTable[superTable]
	if !exist {
		for i := 0; i < len(fieldTypes); i++ {
			s.tmpBuf.WriteByte(',')
			s.tmpBuf.WriteString(fieldKeys[i])
			s.tmpBuf.WriteByte(' ')
			s.tmpBuf.WriteString(fieldTypes[i])
		}
		fieldStr := s.tmpBuf.String()
		s.tmpBuf.Reset()
		for i := 0; i < len(tagTypes); i++ {
			s.tmpBuf.WriteString(tagKeys[i])
			s.tmpBuf.WriteByte(' ')
			s.tmpBuf.WriteString(tagTypes[i])
			if i != len(tagTypes)-1 {
				s.tmpBuf.WriteByte(',')
			}
		}
		tagStr := s.tmpBuf.String()
		s.tmpBuf.Reset()
		pd := point{
			SqlType:    CreateSTable,
			SuperTable: superTable,
			SubTable:   subTable,
			Sql:        fmt.Sprintf("create table %s (ts timestamp%s) tags (%s)", superTable, fieldStr, tagStr),
		}
		s.encoder.Encode(pd)
		table := &Table{
			columns: map[string]struct{}{},
			tags:    map[string]struct{}{},
			types:   byteTypes,
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
				panic("not support modify column")
			}
		}
		for _, key := range tagKeys {
			if _, exist = stable.tags[key]; !exist {
				panic("not support modify tag")
			}
		}
	}
	_, exist = s.tableMap[subTable]
	if !exist {
		pd := point{
			SqlType:    CreateSubTable,
			SuperTable: superTable,
			SubTable:   subTable,
			Sql:        fmt.Sprintf("create table %s using %s (%s) tags (%s)", subTable, superTable, strings.Join(tagKeys, ","), strings.Join(tagValues, ",")),
		}
		s.encoder.Encode(pd)
		s.tableMap[subTable] = nothing
	}
	pd := point{
		SqlType:    Insert,
		SuperTable: "",
		SubTable:   subTable,
		Sql:        "",
		Types:      s.superTable[superTable].types,
		Values:     fieldValues,
	}
	s.encoder.Encode(pd)
	return nil
}

var keyWords = map[string]bool{
	"port": true,
}

func convertKeywords(s string) string {
	if is := keyWords[s]; is {
		return fmt.Sprintf("`%s`", s)
	}
	return s
}

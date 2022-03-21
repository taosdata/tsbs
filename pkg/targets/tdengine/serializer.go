package tdengine

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/timescale/tsbs/pkg/data"
)

type Serializer struct {
	tmpBuf     *bytes.Buffer
	tableMap   map[string]struct{}
	superTable map[string]*Table
}

var nothing = struct{}{}

type Table struct {
	columns map[string]struct{}
	tags    map[string]struct{}
}

func FastFormat(buf *bytes.Buffer, v interface{}) string {
	switch v.(type) {
	case int:
		buf.WriteString(strconv.Itoa(v.(int)))
		return "bigint"
	case int64:
		buf.WriteString(strconv.FormatInt(v.(int64), 10))
		return "bigint"
	case float64:
		buf.WriteString(strconv.FormatFloat(v.(float64), 'f', -1, 64))
		return "double"
	case float32:
		buf.WriteString(strconv.FormatFloat(float64(v.(float32)), 'f', -1, 32))
		return "double"
	case bool:
		buf.WriteString(strconv.FormatBool(v.(bool)))
		return "bool"
	case []byte:
		buf.WriteByte('\'')
		buf.WriteString(string(v.([]byte)))
		buf.WriteByte('\'')
		return "binary(30)"
	case string:
		buf.WriteByte('\'')
		buf.WriteString(v.(string))
		buf.WriteByte('\'')
		return "binary(30)"
	case nil:
		buf.WriteString("null")
		return "null"
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
	var fieldKeys []string
	var fieldValues []string
	var fieldTypes []string
	var tagValues []string
	var tagKeys []string
	tKeys := p.TagKeys()
	tValues := p.TagValues()
	fKeys := p.FieldKeys()
	fValues := p.FieldValues()
	superTable := string(p.MeasurementName())
	for i, value := range fValues {
		fType := FastFormat(s.tmpBuf, value)
		if value != nil {
			fieldKeys = append(fieldKeys, string(fKeys[i]))
			fieldTypes = append(fieldTypes, fType)
		}
		fieldValues = append(fieldValues, s.tmpBuf.String())
		s.tmpBuf.Reset()
	}

	for i, value := range tValues {
		if value == nil {
			stable, exist := s.superTable[superTable]
			if exist {
				_, exist = stable.columns[string(tKeys[i])]
				if exist {
					FastFormat(s.tmpBuf, tKeys[i])
					fieldValues = append(fieldValues, s.tmpBuf.String())
					s.tmpBuf.Reset()
				}
			} else {
				//todo 可能类型错误
				tagKeys = append(tagKeys, string(tKeys[i]))
				FastFormat(s.tmpBuf, value)
				tagValues = append(tagValues, s.tmpBuf.String())
				s.tmpBuf.Reset()
			}
			continue
		}
		switch value.(type) {
		case string:
			tagKeys = append(tagKeys, string(tKeys[i]))
			FastFormat(s.tmpBuf, value)
			tagValues = append(tagValues, s.tmpBuf.String())
			s.tmpBuf.Reset()
		default:
			fType := FastFormat(s.tmpBuf, tKeys[i])
			fieldKeys = append(fieldKeys, string(tKeys[i]))
			fieldTypes = append(fieldTypes, fType)
			fieldValues = append(fieldValues, s.tmpBuf.String())
			s.tmpBuf.Reset()
		}
	}
	s.tmpBuf.WriteString(superTable)
	for i, v := range tagValues {
		s.tmpBuf.WriteByte(',')
		s.tmpBuf.Write(tKeys[i])
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
		fmt.Fprintf(w, "%c,%s,%s,create table %s (ts timestamp%s) tags (%s binary(30))\n", CreateSTable, superTable, subTable, superTable, s.tmpBuf.String(), strings.Join(tagKeys, " binary(30),"))
		s.tmpBuf.Reset()
		table := &Table{
			columns: map[string]struct{}{},
			tags:    map[string]struct{}{},
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
				fmt.Fprintf(w, "%c,%s,%s,alter table %s add COLUMN %s double\n", Modify, superTable, subTable, superTable, key)
				stable.columns[key] = nothing
			}
		}
		for _, key := range tagKeys {
			if _, exist = stable.tags[key]; !exist {
				fmt.Fprintf(w, "%c,%s,%s,alter table %s add TAG %s binary(30)\n", Modify, superTable, subTable, superTable, key)
				stable.tags[key] = nothing
			}
		}
	}
	_, exist = s.tableMap[subTable]
	if !exist {
		fmt.Fprintf(w, "%c,%s,%s,create table %s using %s (%s) tags (%s)\n", CreateSubTable, superTable, subTable, subTable, superTable, strings.Join(tagKeys, ","), strings.Join(tagValues, ","))
		s.tableMap[subTable] = nothing
	}

	fmt.Fprintf(w, "%c,%s,%d,(%d,%s)\n", Insert, subTable, len(fieldValues), p.TimestampInUnixMs(), strings.Join(fieldValues, ","))
	return nil
}

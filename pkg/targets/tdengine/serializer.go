package tdengine

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"strconv"

	"github.com/taosdata/tsbs/pkg/data"
)

type Serializer struct {
	writeBuf   *bytes.Buffer
	tmpBuf     *bytes.Buffer
	tableMap   map[string]struct{}
	superTable map[string]*Table
}

var nothing = struct{}{}

type Table struct {
	columns map[string]struct{}
	tags    map[string]struct{}
}

func FastFormatField(buf *bytes.Buffer, v interface{}) string {
	if v == nil {
		buf.WriteString("")
		return ""
	}
	switch vv := v.(type) {
	case int:
		buf.WriteString(strconv.Itoa(vv))
	case int64:
		buf.WriteString(strconv.FormatInt(vv, 10))
	case float64:
		buf.WriteString(strconv.FormatFloat(vv, 'f', -1, 32))
	case float32:
		buf.WriteString(strconv.FormatFloat(float64(vv), 'f', -1, 32))
	default:
		panic(fmt.Sprintf("unknown field type for %#v", v))
	}
	return "double"
}

func FastFormatTag(buf *bytes.Buffer, v interface{}) string {
	if v == nil {
		buf.WriteString("null")
		return "null"
	}
	switch vv := v.(type) {
	case int:
		buf.WriteString(strconv.Itoa(vv))
		return "bigint"
	case int64:
		buf.WriteString(strconv.FormatInt(vv, 10))
		return "bigint"
	case float64:
		buf.WriteString(strconv.FormatFloat(vv, 'f', -1, 64))
		return "double"
	case float32:
		buf.WriteString(strconv.FormatFloat(float64(vv), 'f', -1, 32))
		return "double"
	case bool:
		buf.WriteString(strconv.FormatBool(vv))
		return "bool"
	case []byte:
		vvv := string(vv)
		buf.WriteByte('\'')
		buf.WriteString(vvv)
		buf.WriteByte('\'')
		return "binary(30)"
	case string:
		buf.WriteByte('\'')
		buf.WriteString(vv)
		buf.WriteByte('\'')
		return "binary(30)"
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
	var fieldTypes []string
	var tagValues []string
	var tagKeys []string
	var tagTypes []string
	tKeys := p.TagKeys()
	tValues := p.TagValues()
	fKeys := p.FieldKeys()
	var fieldValue string
	fValues := p.FieldValues()
	superTable := string(p.MeasurementName())
	s.tmpBuf.WriteString(strconv.FormatInt(p.TimestampInUnixMs(), 10))
	s.tmpBuf.WriteByte(',')
	for i, value := range fValues {
		fieldKeys = append(fieldKeys, convertKeywords(string(fKeys[i])))
		fType := FastFormatField(s.tmpBuf, value)
		fieldTypes = append(fieldTypes, fType)
		if i != len(fValues)-1 {
			s.tmpBuf.WriteByte(',')
		}
	}
	fieldValue = s.tmpBuf.String()
	s.tmpBuf.Reset()

	for i, value := range tValues {
		tType := FastFormatTag(s.tmpBuf, value)
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
		s.writeBuf.WriteByte(CreateSTable)
		s.writeBuf.WriteByte(',')
		s.writeBuf.WriteString(superTable)
		s.writeBuf.WriteByte(',')
		s.writeBuf.WriteString(subTable)
		s.writeBuf.WriteString(",create table ")
		s.writeBuf.WriteString(superTable)
		s.writeBuf.WriteString(" (ts timestamp")
		for i := 0; i < len(fieldTypes); i++ {
			s.writeBuf.WriteByte(',')
			s.writeBuf.WriteString(fieldKeys[i])
			s.writeBuf.WriteByte(' ')
			s.writeBuf.WriteString(fieldTypes[i])
		}
		s.writeBuf.WriteString(") tags (")
		for i := 0; i < len(tagTypes); i++ {
			s.writeBuf.WriteString(tagKeys[i])
			s.writeBuf.WriteByte(' ')
			s.writeBuf.WriteString(tagTypes[i])
			if i != len(tagTypes)-1 {
				s.writeBuf.WriteByte(',')
			}
		}
		s.writeBuf.WriteString(")\n")
		//Sql:        fmt.Sprintf("create table %s (ts timestamp%s) tags (%s)", superTable, fieldStr, tagStr),
		_, err := s.writeBuf.WriteTo(w)
		if err != nil {
			panic(err)
		}
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
		s.writeBuf.WriteByte(CreateSubTable)
		s.writeBuf.WriteByte(',')
		s.writeBuf.WriteString(superTable)
		s.writeBuf.WriteByte(',')
		s.writeBuf.WriteString(subTable)
		s.writeBuf.WriteString(",create table ")
		s.writeBuf.WriteString(subTable)
		s.writeBuf.WriteString(" using ")
		s.writeBuf.WriteString(superTable)
		s.writeBuf.WriteString(" (")
		for i := 0; i < len(tagKeys); i++ {
			s.writeBuf.WriteString(tagKeys[i])
			if i != len(tagTypes)-1 {
				s.writeBuf.WriteByte(',')
			}
		}
		s.writeBuf.WriteString(") tags (")
		for i := 0; i < len(tagValues); i++ {
			s.writeBuf.WriteString(tagValues[i])
			if i != len(tagTypes)-1 {
				s.writeBuf.WriteByte(',')
			}
		}
		s.writeBuf.WriteString(")\n")
		_, err := s.writeBuf.WriteTo(w)
		if err != nil {
			panic(err)
		}
		//fmt.Fprintf(w, "%d,%s,%s,create table %s using %s (%s) tags (%s)", CreateSubTable, superTable, subTable, subTable, superTable, strings.Join(tagKeys, ","), strings.Join(tagValues, ","))
		s.tableMap[subTable] = nothing
	}
	s.writeBuf.WriteByte(Insert)
	s.writeBuf.WriteByte(',')
	s.writeBuf.WriteString(strconv.Itoa(len(fieldKeys)))
	s.writeBuf.WriteByte(',')
	s.writeBuf.WriteString(subTable)
	s.writeBuf.WriteByte(',')
	s.writeBuf.WriteString(fieldValue)
	s.writeBuf.WriteByte('\n')
	_, err := s.writeBuf.WriteTo(w)
	if err != nil {
		panic(err)
	}

	//fmt.Fprintf(w, "%d,%d,%s,%s", Insert, len(fieldKeys), subTable, fieldValue)
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

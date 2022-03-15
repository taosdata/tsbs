package tdengine

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"strconv"

	"github.com/timescale/tsbs/pkg/data"
)

type Serializer struct {
	buf    *bytes.Buffer
	tmpBuf *bytes.Buffer
}

func (s *Serializer) Serialize(p *data.Point, w io.Writer) error {
	if s.buf == nil {
		s.buf = &bytes.Buffer{}
	}
	if s.tmpBuf == nil {
		s.tmpBuf = &bytes.Buffer{}
	}
	tagKeys := p.TagKeys()
	tagValues := p.TagValues()
	measurement := p.MeasurementName()
	s.tmpBuf.Write(measurement)
	s.buf.WriteString("tags")
	for i, v := range tagValues {
		s.buf.WriteByte(',')
		s.buf.Write(tagKeys[i])
		s.buf.WriteByte('=')
		FastFormat(s.buf, v)

		s.tmpBuf.WriteByte(',')
		s.tmpBuf.Write(tagKeys[i])
		s.tmpBuf.WriteByte('=')
		FastFormat(s.tmpBuf, v)
	}
	s.buf.WriteByte('\n')
	_, err := w.Write(s.buf.Bytes())
	if err != nil {
		return err
	}
	s.buf.Reset()
	subTable := calculateTable(s.tmpBuf.Bytes())
	s.tmpBuf.Reset()
	// Field row second
	s.buf.Write(measurement)
	s.buf.WriteByte(',')
	s.buf.WriteString(subTable)
	s.buf.WriteByte(',')
	fmt.Fprintf(s.buf, "ts=%d", p.Timestamp().UTC().UnixNano())
	fieldValues := p.FieldValues()
	fieldKeys := p.FieldKeys()
	for i, v := range fieldValues {
		s.buf.WriteByte(',')
		s.buf.Write(fieldKeys[i])
		s.buf.WriteByte('=')
		FastFormat(s.buf, v)
	}
	s.buf.WriteByte('\n')
	_, err = w.Write(s.buf.Bytes())
	s.buf.Reset()
	return err
}

func FastFormat(buf *bytes.Buffer, v interface{}) string {
	switch v.(type) {
	case int:
		buf.WriteString(strconv.Itoa(v.(int)))
		return "int"
	case int64:
		buf.WriteString(strconv.FormatInt(v.(int64), 10))
		return "int64"
	case float64:
		buf.WriteString(strconv.FormatFloat(v.(float64), 'f', -1, 64))
		return "float64"
	case float32:
		buf.WriteString(strconv.FormatFloat(float64(v.(float32)), 'f', -1, 32))
		return "float32"
	case bool:
		buf.WriteString(strconv.FormatBool(v.(bool)))
		return "bool"
	case []byte:
		buf.WriteByte('\'')
		buf.WriteString(string(v.([]byte)))
		buf.WriteByte('\'')
		return "string"
	case string:
		buf.WriteByte('\'')
		buf.WriteString(v.(string))
		buf.WriteByte('\'')
		return "string"
	case nil:
		buf.WriteString("null")
		return "null"
	default:
		panic(fmt.Sprintf("unknown field type for %#v", v))
	}
}

func calculateTable(src []byte) string {
	s := md5.Sum(src)
	return fmt.Sprintf("t_%s", hex.EncodeToString(s[:]))
}

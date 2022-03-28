package tdenginesml

import (
	"bytes"
	"io"

	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/data/serialize"
)

// Serializer writes a Point in a serialized form for MongoDB
type Serializer struct {
	tmpBuf *bytes.Buffer
	tmp    []byte
}

// Serialize writes Point data to the given writer, conforming to the
// InfluxDB wire protocol.
//
// This function writes output that looks like:
// <measurement>,<tag key>=<tag value> <field name>=<field value> <timestamp>\n
//
// For example:
// foo,tag0=bar baz=-1.0 100\n
func (s *Serializer) Serialize(p *data.Point, w io.Writer) (err error) {
	s.tmpBuf.Write(p.MeasurementName())

	fakeTags := make([]int, 0)
	tagKeys := p.TagKeys()
	tagValues := p.TagValues()
	for i := 0; i < len(tagKeys); i++ {
		if tagValues[i] == nil {
			continue
		}
		switch v := tagValues[i].(type) {
		case string:
			s.tmpBuf.WriteByte(',')
			s.tmpBuf.Write(tagKeys[i])
			s.tmpBuf.WriteByte('=')
			s.tmpBuf.WriteString(v)
		default:
			fakeTags = append(fakeTags, i)
		}
	}
	fieldKeys := p.FieldKeys()
	if len(fakeTags) > 0 || len(fieldKeys) > 0 {
		s.tmpBuf.WriteByte(' ')
	}
	firstFieldFormatted := false
	for i := 0; i < len(fakeTags); i++ {
		tagIndex := fakeTags[i]
		// don't append a comma before the first field
		if firstFieldFormatted {
			s.tmpBuf.WriteByte(',')
		}
		firstFieldFormatted = true
		s.appendField(s.tmpBuf, tagKeys[tagIndex], tagValues[tagIndex])
	}

	fieldValues := p.FieldValues()
	for i := 0; i < len(fieldKeys); i++ {
		value := fieldValues[i]
		if value == nil {
			continue
		}
		// don't append a comma before the first field
		if firstFieldFormatted {
			s.tmpBuf.WriteByte(',')
		}
		firstFieldFormatted = true
		s.appendField(s.tmpBuf, fieldKeys[i], value)
	}

	// first field wasn't formatted, because all the fields were nil, InfluxDB will reject the insert
	if !firstFieldFormatted {
		return nil
	}
	s.tmpBuf.WriteByte(' ')
	s.tmp = serialize.FastFormatAppend(p.Timestamp().UTC().UnixNano(), s.tmp)
	s.tmpBuf.Write(s.tmp)
	s.tmp = s.tmp[:0]
	s.tmpBuf.WriteByte('\n')
	_, err = w.Write(s.tmpBuf.Bytes())
	s.tmpBuf.Reset()
	return err
}

func (s *Serializer) appendField(buf *bytes.Buffer, key []byte, v interface{}) {
	buf.Write(key)
	buf.WriteByte('=')

	s.tmp = serialize.FastFormatAppend(v, s.tmp)
	buf.Write(s.tmp)
	s.tmp = s.tmp[:0]
	// Influx uses 'i' to indicate integers:
	switch v.(type) {
	case int, int64:
		buf.WriteByte('i')
	}
}

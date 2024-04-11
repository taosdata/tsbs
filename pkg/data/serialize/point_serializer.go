package serialize

import (
	"io"

	"github.com/taosdata/tsbs/pkg/data"
)

// PointSerializer serializes a Point for writing
type PointSerializer interface {
	Serialize(p *data.Point, w io.Writer) error
}

type PointSerializerConcurrent interface {
	Supported(use string) bool
	PrePare(use string) string
	SerializeConcurrent(points []*data.Point) ([]byte, []byte, error)
}

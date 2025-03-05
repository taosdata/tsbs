package influx3

import (
	"fmt"
	"net/url"
	"time"

	"github.com/taosdata/tsbs/cmd/tsbs_generate_queries/uses/devops"
	"github.com/taosdata/tsbs/cmd/tsbs_generate_queries/uses/iot"
	"github.com/taosdata/tsbs/cmd/tsbs_generate_queries/utils"
	"github.com/taosdata/tsbs/pkg/query"
)

// BaseGenerator contains settings specific for Influx database.
type BaseGenerator struct {
}

// GenerateEmptyQuery returns an empty query.HTTP.
func (g *BaseGenerator) GenerateEmptyQuery() query.Query {
	return query.NewHTTP()
}

// fillInQuery fills the query struct with data.
func (g *BaseGenerator) fillInQuery(qi query.Query, humanLabel, humanDesc, influxql string) {
	v := url.Values{}
	v.Set("q", influxql)
	q := qi.(*query.HTTP)
	q.HumanLabel = []byte(humanLabel)
	q.RawQuery = []byte(influxql)
	q.HumanDescription = []byte(humanDesc)
	q.Method = []byte("GET")
	q.Path = []byte(fmt.Sprintf("/api/v3/query_influxql?%s", v.Encode()))
	q.Body = nil
}

// NewDevops creates a new devops use case query generator.
func (g *BaseGenerator) NewDevops(start, end time.Time, scale int) (utils.QueryGenerator, error) {
	core, err := devops.NewCore(start, end, scale)

	if err != nil {
		return nil, err
	}

	devops := &Devops{
		BaseGenerator: g,
		Core:          core,
	}

	return devops, nil
}

// NewIoT creates a new iot use case query generator.
func (g *BaseGenerator) NewIoT(start, end time.Time, scale int) (utils.QueryGenerator, error) {
	core, err := iot.NewCore(start, end, scale)

	if err != nil {
		return nil, err
	}

	devops := &IoT{
		BaseGenerator: g,
		Core:          core,
	}

	return devops, nil
}

package inputs

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"math/rand"
	"os"
	"runtime"
	"sort"
	"sync"

	"github.com/taosdata/tsbs/pkg/data"
	"github.com/taosdata/tsbs/pkg/data/serialize"
	"github.com/taosdata/tsbs/pkg/data/usecases"
	"github.com/taosdata/tsbs/pkg/data/usecases/common"
	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/constants"
)

// Error messages when using a DataGenerator
const (
	ErrNoConfig          = "no GeneratorConfig provided"
	ErrInvalidDataConfig = "invalid config: DataGenerator needs a DataGeneratorConfig"
)

// DataGenerator is a type of Generator for creating data that will be consumed
// by a database's write/insert operations. The output is specific to the type
// of database, but is consumed by TSBS loaders like tsbs_load_timescaledb.
type DataGenerator struct {
	// Out is the writer where data should be written. If nil, it will be
	// os.Stdout unless File is specified in the GeneratorConfig passed to
	// Generate.
	Out io.Writer

	config *common.DataGeneratorConfig

	// bufOut represents the buffered writer that should actually be passed to
	// any operations that write out data.
	bufOut *bufio.Writer
}

func (g *DataGenerator) init(config common.GeneratorConfig) error {
	if config == nil {
		return fmt.Errorf(ErrNoConfig)
	}
	switch config.(type) {
	case *common.DataGeneratorConfig:
	default:
		return fmt.Errorf(ErrInvalidDataConfig)
	}
	g.config = config.(*common.DataGeneratorConfig)

	err := g.config.Validate()
	if err != nil {
		return err
	}

	if g.Out == nil {
		g.Out = os.Stdout
	}
	g.bufOut, err = getBufferedWriter(g.config.File, g.Out)
	if err != nil {
		return err
	}

	return nil
}

func (g *DataGenerator) Generate(config common.GeneratorConfig, target targets.ImplementedTarget) error {
	err := g.init(config)
	if err != nil {
		return err
	}

	rand.Seed(g.config.Seed)

	scfg, err := usecases.GetSimulatorConfig(g.config)
	if err != nil {
		return err
	}

	sim := scfg.NewSimulator(g.config.LogInterval, g.config.Limit)
	serializer, err := g.getSerializer(sim, target)
	if err != nil {
		return err
	}
	concurrentSerializer, ok := serializer.(serialize.PointSerializerConcurrent)
	if ok && concurrentSerializer.Supported(g.config.Use) {
		return g.runSimulatorBatch(sim, concurrentSerializer, g.config)
	}
	return g.runSimulator(sim, serializer, g.config)
}

func (g *DataGenerator) CreateSimulator(config *common.DataGeneratorConfig) (common.Simulator, error) {
	err := g.init(config)
	if err != nil {
		return nil, err
	}
	rand.Seed(g.config.Seed)
	scfg, err := usecases.GetSimulatorConfig(g.config)
	if err != nil {
		return nil, err
	}

	return scfg.NewSimulator(g.config.LogInterval, g.config.Limit), nil
}

func (g *DataGenerator) runSimulator(sim common.Simulator, serializer serialize.PointSerializer, dgc *common.DataGeneratorConfig) error {
	defer g.bufOut.Flush()

	currGroupID := uint(0)
	point := data.NewPoint()
	for !sim.Finished() {
		write := sim.Next(point)
		if !write {
			point.Reset()
			continue
		}

		// in the default case this is always true
		if currGroupID == dgc.InterleavedGroupID {
			err := serializer.Serialize(point, g.bufOut)
			if err != nil {
				return fmt.Errorf("can not serialize point: %s", err)
			}
		}
		point.Reset()

		currGroupID = (currGroupID + 1) % dgc.InterleavedNumGroups
	}
	return nil
}

func (g *DataGenerator) runSimulatorBatch(sim common.Simulator, serializer serialize.PointSerializerConcurrent, dgc *common.DataGeneratorConfig) error {
	defer g.bufOut.Flush()
	batchSize := 32767
	preData := serializer.PrePare(dgc.Use)
	g.bufOut.WriteString(preData)
	points := make([]*data.Point, batchSize)
	for i := 0; i < batchSize; i++ {
		points[i] = data.NewPoint()
	}
	index := 0
	workerCount := runtime.NumCPU() * 2
	worker := make([]chan []*data.Point, workerCount)
	workerDataTemp := make([][]*data.Point, workerCount)
	highLevelDataBuf := &bytes.Buffer{}
	normalDataBuf := &bytes.Buffer{}
	dataLocker := &sync.Mutex{}
	wg := &sync.WaitGroup{}
	for i := 0; i < batchSize; i++ {
		ha := i % workerCount
		workerDataTemp[ha] = append(workerDataTemp[ha], points[i])
	}
	for i := 0; i < workerCount; i++ {
		worker[i] = make(chan []*data.Point, 1)
		i := i
		go func() {
			for {
				select {
				case d := <-worker[i]:
					normalData, highLevelData, err := serializer.SerializeConcurrent(d)
					if err != nil {
						panic(err)
					}
					dataLocker.Lock()
					highLevelDataBuf.Write(highLevelData)
					normalDataBuf.Write(normalData)
					dataLocker.Unlock()
					wg.Done()
				}
			}
		}()
	}
	var doPostData = func() error {
		for i := 0; i < workerCount; i++ {
			wg.Add(1)
			worker[i] <- workerDataTemp[i]
		}
		wg.Wait()
		highLevelDataBuf.WriteTo(g.bufOut)
		normalDataBuf.WriteTo(g.bufOut)
		for i := 0; i < index; i++ {
			points[i].Reset()
		}
		return nil
	}

	for !sim.Finished() {
		write := sim.Next(points[index])
		if !write {
			points[index].Reset()
			continue
		}
		index += 1
		if index == batchSize {
			err := doPostData()
			if err != nil {
				return err
			}
			index = 0
		}
	}
	if index != 0 {
		err := doPostData()
		if err != nil {
			return err
		}
	}
	return nil
}

func (g *DataGenerator) getSerializer(sim common.Simulator, target targets.ImplementedTarget) (serialize.PointSerializer, error) {
	switch target.TargetName() {
	case constants.FormatCrateDB:
		fallthrough
	case constants.FormatClickhouse:
		fallthrough
	case constants.FormatTimescaleDB:
		g.writeHeader(sim.Headers())
	}
	return target.Serializer(), nil
}

// TODO should be implemented in targets package
func (g *DataGenerator) writeHeader(headers *common.GeneratedDataHeaders) {
	g.bufOut.WriteString("tags")

	types := headers.TagTypes
	for i, key := range headers.TagKeys {
		g.bufOut.WriteString(",")
		g.bufOut.Write([]byte(key))
		g.bufOut.WriteString(" ")
		g.bufOut.WriteString(types[i])
	}
	g.bufOut.WriteString("\n")
	// sort the keys so the header is deterministic
	keys := make([]string, 0)
	fields := headers.FieldKeys
	for k := range fields {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, measurementName := range keys {
		g.bufOut.WriteString(measurementName)
		for _, field := range fields[measurementName] {
			g.bufOut.WriteString(",")
			g.bufOut.Write([]byte(field))
		}
		g.bufOut.WriteString("\n")
	}
	g.bufOut.WriteString("\n")
}

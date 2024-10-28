package tdenginestmt2

import (
	"github.com/taosdata/tsbs/pkg/targets/tdengine"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/async"
)

type DbCreator struct {
	tdengine.DbCreator
	useCase byte
	ds      *fileDataSource
}

func (d *DbCreator) PostCreateDB(dbName string) error {
	err := async.GlobalAsync.TaosExecWithoutResult(d.Db.TaosConnection, "use "+dbName)
	if err != nil {
		return err
	}
	switch d.useCase {
	case CpuCase:
		err = async.GlobalAsync.TaosExecWithoutResult(d.Db.TaosConnection, CpuSql)
		if err != nil {
			return err
		}
	case IoTCase:
		err = async.GlobalAsync.TaosExecWithoutResult(d.Db.TaosConnection, ReadingsSql)
		if err != nil {
			return err
		}
		err = async.GlobalAsync.TaosExecWithoutResult(d.Db.TaosConnection, DiagnosticsSql)
		if err != nil {
			return err
		}
	}
	//points := d.ds.FillCache()
	//log.Debugf("create table count: %d", len(points))
	//pointsArray := SplitBytes(points, runtime.NumCPU())
	//wg := &sync.WaitGroup{}
	//wg.Add(len(pointsArray))
	//for i := 0; i < len(pointsArray); i++ {
	//	go func(points [][]byte) {
	//		for j := 0; j < len(points); j++ {
	//			p := points[j]
	//			err := async.GlobalAsync.TaosExecWithoutResult(d.Db.TaosConnection, BytesToString(p))
	//			if err != nil {
	//				panic(err)
	//			}
	//		}
	//		wg.Done()
	//	}(pointsArray[i])
	//}
	//wg.Wait()
	return nil
}

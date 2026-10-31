package tdenginestmt2

import (
	"github.com/taosdata/tsbs/pkg/targets/tdengine"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/async"
	"os"
	"strings"
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
	if path := d.Opts.PrecreateSQLFile; path != "" {
		body, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		for _, statement := range strings.Split(string(body), ";") {
			if strings.TrimSpace(statement) == "" {
				continue
			}
			if err := async.GlobalAsync.TaosExecWithoutResult(d.Db.TaosConnection, statement); err != nil {
				return err
			}
		}
	}
	return nil
}

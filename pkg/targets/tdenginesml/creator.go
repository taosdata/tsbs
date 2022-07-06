package tdenginesml

import (
	"fmt"

	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/async"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/commonpool"
)

type dbCreator struct {
	opts *LoadingOptions
	ds   targets.DataSource
	db   *commonpool.Conn
}

func (d *dbCreator) Init() {
	async.Init()
	db, err := commonpool.GetConnection(d.opts.User, d.opts.Pass, d.opts.Host, d.opts.Port)
	if err != nil {
		panic("TDengine can not get connection")
	}
	d.db = db
}

func (d *dbCreator) DBExists(dbName string) bool {
	err := async.GlobalAsync.TaosExecWithoutResult(d.db.TaosConnection, "use "+dbName)
	return err == nil
}

func (d *dbCreator) CreateDB(dbName string) error {
	sql := fmt.Sprintf("create database %s precision 'ms' buffer  768", dbName)
	return async.GlobalAsync.TaosExecWithoutResult(d.db.TaosConnection, sql)
}

func (d *dbCreator) RemoveOldDB(dbName string) error {
	sql := fmt.Sprintf("drop database %s", dbName)
	return async.GlobalAsync.TaosExecWithoutResult(d.db.TaosConnection, sql)
}

func (d *dbCreator) Close() {
	if d.db != nil {
		d.db.Put()
	}
}

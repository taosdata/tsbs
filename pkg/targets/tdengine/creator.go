package tdengine

import (
	"fmt"
	"log"

	"github.com/timescale/tsbs/pkg/targets"
	"github.com/timescale/tsbs/pkg/targets/tdengine/async"
	"github.com/timescale/tsbs/pkg/targets/tdengine/commonpool"
)

var fatal = log.Fatalf

type dbCreator struct {
	opts   *LoadingOptions
	ds     targets.DataSource
	dbName string
	db     *commonpool.Conn
}

var GlobalConnect *commonpool.Conn

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
	sql := fmt.Sprintf("create database %s precision 'ms'", dbName)
	return async.GlobalAsync.TaosExecWithoutResult(d.db.TaosConnection, sql)
}

func (d *dbCreator) RemoveOldDB(dbName string) error {
	sql := fmt.Sprintf("drop database %s", dbName)
	return async.GlobalAsync.TaosExecWithoutResult(d.db.TaosConnection, sql)
}

func (d *dbCreator) PostCreateDB(dbName string) error {
	db, err := commonpool.GetConnection(d.opts.User, d.opts.Pass, d.opts.Host, d.opts.Port)
	if err != nil {
		return err
	}
	err = async.GlobalAsync.TaosExecWithoutResult(db.TaosConnection, "use "+dbName)
	if err != nil {
		return err
	}
	GlobalConnect = db
	return nil
}

func (d *dbCreator) Close() {
	if d.db != nil {
		d.db.Put()
	}
}

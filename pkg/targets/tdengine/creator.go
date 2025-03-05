package tdengine

import (
	"fmt"
	"log"
	"strconv"

	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/async"
	"github.com/taosdata/tsbs/pkg/targets/tdengine/commonpool"
)

var fatal = log.Fatalf

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
	sql := fmt.Sprintf("create database %s precision 'ms'", dbName)
	if d.opts.Buffer > 0 {
		sql += " buffer " + strconv.Itoa(d.opts.Buffer)
	}
	if d.opts.Pages > 0 {
		sql += " pages " + strconv.Itoa(d.opts.Pages)
	}
	if d.opts.VGroups > 0 {
		sql += " vgroups " + strconv.Itoa(d.opts.VGroups)
	}
	if d.opts.SttTrigger > 0 {
		sql += " stt_trigger " + strconv.Itoa(d.opts.SttTrigger)
	}
	if d.opts.WalFsyncPeriod != nil {
		sql += " wal_fsync_period " + strconv.Itoa(*d.opts.WalFsyncPeriod)
	}
	if d.opts.WalLevel != nil {
		sql += " wal_level " + strconv.Itoa(*d.opts.WalLevel)
	}
	if d.opts.DBParameters != "" {
		sql += " " + d.opts.DBParameters
	}
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

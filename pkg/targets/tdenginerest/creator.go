package tdenginerest

import (
	"fmt"
	"log"
	"strconv"

	"github.com/taosdata/tsbs/pkg/targets"
	"github.com/taosdata/tsbs/pkg/targets/tdenginerest/connector"
)

var fatal = log.Fatalf

type dbCreator struct {
	opts *LoadingOptions
	ds   targets.DataSource
	db   *connector.TaosConn
}

func (d *dbCreator) Init() {
	d.db = mustConnect(d.opts.GetConnectString(""))
}

func (d *dbCreator) DBExists(dbName string) bool {
	_, err := d.db.Exec([]byte("use " + dbName))
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
	_, err := d.db.Exec([]byte(sql))
	return err
}

func (d *dbCreator) RemoveOldDB(dbName string) error {
	sql := fmt.Sprintf("drop database %s", dbName)
	_, err := d.db.Exec([]byte(sql))
	return err
}

func (d *dbCreator) Close() {
	if d.db != nil {
		d.db.Close()
	}
}

func mustConnect(dsn string) *connector.TaosConn {
	db, err := connector.NewTaosConn(dsn)
	if err != nil {
		panic(err)
	}
	return db
}

func execWithoutResult(db *connector.TaosConn, sql []byte) error {
	_, err := db.Exec(sql)
	return err
}

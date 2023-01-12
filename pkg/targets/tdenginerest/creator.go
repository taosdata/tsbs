package tdenginerest

import (
	"database/sql"
	"fmt"
	"log"
	"strconv"

	_ "github.com/taosdata/driver-go/v3/taosRestful"
	"github.com/taosdata/tsbs/pkg/targets"
)

var fatal = log.Fatalf

type dbCreator struct {
	opts *LoadingOptions
	ds   targets.DataSource
	db   *sql.DB
}

func (d *dbCreator) Init() {
	d.db = mustConnect(d.opts.GetConnectString(""))
}

func (d *dbCreator) DBExists(dbName string) bool {
	_, err := d.db.Exec("use " + dbName)
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
	_, err := d.db.Exec(sql)
	return err
}

func (d *dbCreator) RemoveOldDB(dbName string) error {
	sql := fmt.Sprintf("drop database %s", dbName)
	_, err := d.db.Exec(sql)
	return err
}

func (d *dbCreator) Close() {
	if d.db != nil {
		d.db.Close()
	}
}

func mustConnect(dsn string) *sql.DB {
	db, err := sql.Open("taosRestful", dsn)
	if err != nil {
		panic(err)
	}
	return db
}

func execWithoutResult(db *sql.DB, sql string) error {
	_, err := db.Exec(sql)
	return err
}

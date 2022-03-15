package tdengine

import (
	"fmt"
	"log"

	"github.com/timescale/tsbs/pkg/targets"
	"github.com/timescale/tsbs/pkg/targets/tdengine/async"
	"github.com/timescale/tsbs/pkg/targets/tdengine/commonpool"
)

const (
	tagsKey = "tags"
)

var fatal = log.Fatalf

type dbCreator struct {
	opts   *LoadingOptions
	ds     targets.DataSource
	dbName string
	db     *commonpool.Conn
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
	sql := fmt.Sprintf("create database %s precision 'ns'", dbName)
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

//func (d *dbCreator) PostCreateDB(dbName string) error {
//	headers := d.ds.Headers()
//	tagNames := headers.TagKeys
//	tagTypes := headers.TagTypes
//	fields := headers.FieldKeys
//	sql := &bytes.Buffer{}
//	prefix := fmt.Sprintf("create table if not exists %s.", dbName)
//	tags := &bytes.Buffer{}
//	tags.WriteString("tags(")
//	for i := 0; i < len(tagNames); i++ {
//		if i > 0 {
//			tags.WriteByte(',')
//		}
//		fieldType := dbType(tagTypes[i])
//		tags.WriteString(tagNames[i])
//		tags.WriteByte(' ')
//		tags.WriteString(fieldType)
//	}
//	tags.WriteByte(')')
//	tagSql := tags.Bytes()
//	for tbName, columns := range fields {
//		sql.WriteString(prefix)
//		sql.WriteString(tbName)
//		sql.WriteString("(ts timestamp")
//		for _, column := range columns {
//			sql.WriteByte(',')
//			sql.WriteString(column)
//			sql.WriteByte(' ')
//			sql.WriteString("double")
//		}
//		sql.WriteByte(')')
//		sql.Write(tagSql)
//		s := sql.String()
//		err := async.GlobalAsync.TaosExecWithoutResult(d.db.TaosConnection, s)
//		if err != nil {
//			return err
//		}
//		sql.Reset()
//	}
//	return nil
//}

//func extractTagNamesAndTypes(tags []string) ([]string, []string) {
//	tagNames := make([]string, len(tags))
//	tagTypes := make([]string, len(tags))
//	for i, tagWithType := range tags {
//		tagAndType := strings.Split(tagWithType, " ")
//		if len(tagAndType) != 2 {
//			panic("tag header has invalid format")
//		}
//		tagNames[i] = tagAndType[0]
//		tagTypes[i] = tagAndType[1]
//	}
//
//	return tagNames, tagTypes
//}
//
//func dbType(goType string) string {
//	switch goType {
//	case "int", "int64":
//		return "bigint"
//	case "int8":
//		return "tinyint"
//	case "int16":
//		return "smallint"
//	case "int32":
//		return "int"
//	case "float32":
//		return "float"
//	case "float64":
//		return "double"
//	case "string":
//		return "binary(128)"
//	default:
//		panic("unsupported type:" + goType)
//	}
//}

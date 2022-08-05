package cstmt

/*
#cgo CFLAGS: -IC:/TDengine/include -I/usr/include
#cgo linux LDFLAGS: -L/usr/lib -ltaos
#cgo windows LDFLAGS: -LC:/TDengine/driver -ltaos
#cgo darwin LDFLAGS: -L/usr/local/taos/driver -ltaos
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <taos.h>
*/
import "C"
import (
	"database/sql/driver"
	"unsafe"
)

const (
	TypeInt    = 'i'
	TypeTS     = 't'
	TypeDouble = 'f'
	TypeBool   = 'b'
	TypeString = 's'
	TypeNull   = 'n'
)

// TaosStmtInit TAOS_STMT *taos_stmt_init(TAOS *taos);
func TaosStmtInit(taosConnect unsafe.Pointer) unsafe.Pointer {
	return C.taos_stmt_init(taosConnect)
}

// TaosStmtPrepare int        taos_stmt_prepare(TAOS_STMT *stmt, const char *sql, unsigned long length);
func TaosStmtPrepare(stmt unsafe.Pointer, sql string) int {
	cSql := C.CString(sql)
	cLen := C.ulong(len(sql))
	defer C.free(unsafe.Pointer(cSql))
	return int(C.taos_stmt_prepare(stmt, cSql, cLen))
}

// TaosStmtSetTBName int        taos_stmt_set_tbname(TAOS_STMT* stmt, const char* name);
func TaosStmtSetTBName(stmt unsafe.Pointer, name string) int {
	cStr := C.CString(name)
	defer C.free(unsafe.Pointer(cStr))
	return int(C.taos_stmt_set_tbname(stmt, cStr))
}

// TaosStmtAddBatch int        taos_stmt_add_batch(TAOS_STMT *stmt);
func TaosStmtAddBatch(stmt unsafe.Pointer) int {
	return int(C.taos_stmt_add_batch(stmt))
}

// TaosStmtExecute int        taos_stmt_execute(TAOS_STMT *stmt);
func TaosStmtExecute(stmt unsafe.Pointer) int {
	return int(C.taos_stmt_execute(stmt))
}

// TaosStmtClose int        taos_stmt_close(TAOS_STMT *stmt);
func TaosStmtClose(stmt unsafe.Pointer) int {
	return int(C.taos_stmt_close(stmt))
}

// TaosStmtErrStr char       *taos_stmt_errstr(TAOS_STMT *stmt);
func TaosStmtErrStr(stmt unsafe.Pointer) string {
	return C.GoString(C.taos_stmt_errstr(stmt))
}

// TaosStmtBindParamBatch int        taos_stmt_bind_param_batch(TAOS_STMT* stmt, TAOS_MULTI_BIND* bind);
func TaosStmtBindParamBatch(stmt unsafe.Pointer, multiBind [][]driver.Value, columnTypes []byte) int {
	columnCount := len(multiBind[0])
	rowLen := len(multiBind)
	var binds = make([]C.TAOS_MULTI_BIND, columnCount)
	var needFreePointer []unsafe.Pointer
	defer func() {
		for _, pointer := range needFreePointer {
			C.free(pointer)
		}
	}()
	for columnIndex := 0; columnIndex < columnCount; columnIndex++ {
		bind := C.TAOS_MULTI_BIND{}
		//malloc
		bind.num = C.int(rowLen)
		nullList := unsafe.Pointer(C.malloc(C.size_t(C.uint(rowLen))))
		needFreePointer = append(needFreePointer, nullList)
		lengthList := unsafe.Pointer(C.malloc(C.size_t(C.uint(rowLen * 4))))
		needFreePointer = append(needFreePointer, lengthList)
		var p unsafe.Pointer
		if columnIndex == 0 {
			p = unsafe.Pointer(C.malloc(C.size_t(C.uint(8 * rowLen))))
			bind.buffer_type = C.TSDB_DATA_TYPE_TIMESTAMP
			bind.buffer_length = C.uintptr_t(8)
			for row := 0; row < rowLen; row++ {
				currentNull := unsafe.Pointer(uintptr(nullList) + uintptr(row))
				if multiBind[row][columnIndex] == nil {
					*(*C.char)(currentNull) = C.char(1)
				} else {
					*(*C.char)(currentNull) = C.char(0)
					value := multiBind[row][columnIndex].(int64)
					current := unsafe.Pointer(uintptr(p) + uintptr(8*row))
					*(*C.int64_t)(current) = C.int64_t(value)
				}
			}
		} else {
			switch columnTypes[columnIndex] {
			case TypeBool:
				//1
				p = unsafe.Pointer(C.malloc(C.size_t(C.uint(rowLen))))
				bind.buffer_type = C.TSDB_DATA_TYPE_BOOL
				bind.buffer_length = C.uintptr_t(1)
				for row := 0; row < rowLen; row++ {
					currentNull := unsafe.Pointer(uintptr(nullList) + uintptr(row))
					if multiBind[row][columnIndex] == nil {
						*(*C.char)(currentNull) = C.char(1)
					} else {
						*(*C.char)(currentNull) = C.char(0)
						value := multiBind[row][columnIndex].(bool)
						current := unsafe.Pointer(uintptr(p) + uintptr(row))
						if value {
							*(*C.int8_t)(current) = C.int8_t(1)
						} else {
							*(*C.int8_t)(current) = C.int8_t(0)
						}
					}
				}
			case TypeInt:
				//8
				p = unsafe.Pointer(C.malloc(C.size_t(C.uint(8 * rowLen))))
				bind.buffer_type = C.TSDB_DATA_TYPE_BIGINT
				bind.buffer_length = C.uintptr_t(8)
				for row := 0; row < rowLen; row++ {
					currentNull := unsafe.Pointer(uintptr(nullList) + uintptr(row))
					if multiBind[row][columnIndex] == nil {
						*(*C.char)(currentNull) = C.char(1)
					} else {
						*(*C.char)(currentNull) = C.char(0)
						value := multiBind[row][columnIndex].(int64)
						current := unsafe.Pointer(uintptr(p) + uintptr(8*row))
						*(*C.int64_t)(current) = C.int64_t(value)
					}
				}
			case TypeDouble:
				//8
				p = unsafe.Pointer(C.malloc(C.size_t(C.uint(8 * rowLen))))
				bind.buffer_type = C.TSDB_DATA_TYPE_DOUBLE
				bind.buffer_length = C.uintptr_t(8)
				for row := 0; row < rowLen; row++ {
					currentNull := unsafe.Pointer(uintptr(nullList) + uintptr(row))
					if multiBind[row][columnIndex] == nil {
						*(*C.char)(currentNull) = C.char(1)
					} else {
						*(*C.char)(currentNull) = C.char(0)
						value := multiBind[row][columnIndex].(float64)
						current := unsafe.Pointer(uintptr(p) + uintptr(8*row))
						*(*C.double)(current) = C.double(value)
					}
				}
			case TypeString:
				p = unsafe.Pointer(C.malloc(C.size_t(C.uint(30 * rowLen))))
				bind.buffer_type = C.TSDB_DATA_TYPE_BINARY
				bind.buffer_length = C.uintptr_t(30)
				for row := 0; row < rowLen; row++ {
					currentNull := unsafe.Pointer(uintptr(nullList) + uintptr(row))
					if multiBind[row][columnIndex] == nil {
						*(*C.char)(currentNull) = C.char(1)
					} else {
						*(*C.char)(currentNull) = C.char(0)
						value := multiBind[row][columnIndex].(string)
						for j := 0; j < len(value); j++ {
							*(*C.char)(unsafe.Pointer(uintptr(p) + uintptr(30*row+j))) = (C.char)(value[j])
						}
						l := unsafe.Pointer(uintptr(lengthList) + uintptr(4*row))
						*(*C.int32_t)(l) = C.int32_t(len(value))
					}
				}
			}
		}
		needFreePointer = append(needFreePointer, p)
		bind.buffer = p
		bind.length = (*C.int32_t)(lengthList)
		bind.is_null = (*C.char)(nullList)
		binds[columnIndex] = bind
	}
	return int(C.taos_stmt_bind_param_batch(stmt, (*C.TAOS_MULTI_BIND)(&binds[0])))
}
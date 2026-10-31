import ctypes as C
import os
from pathlib import Path
B=Path(os.environ['TSBS_BENCH_ROOT']).resolve()
HOST=os.environ.get('TSBS_HOST','127.0.0.1')
PORT=int(os.environ.get('TSBS_PORT','6130'))
def td_query(db, sql):
    lib = C.CDLL(str(B/'lib/libtaos.so'))
    def api(name, restype, argtypes):
        fn = getattr(lib,name); fn.restype=restype; fn.argtypes=argtypes; return fn
    options=api('taos_options', C.c_int, [C.c_int,C.c_char_p])
    options(3,str(B/'config').encode()); options(2,b'UTC')
    connect=api('taos_connect', C.c_void_p, [C.c_char_p]*4+[C.c_uint16])
    conn=connect(HOST.encode(),b'root',b'taosdata',db.encode(),PORT)
    if not conn: raise RuntimeError('TDengine connection failed')
    query=api('taos_query', C.c_void_p,[C.c_void_p,C.c_char_p])
    errno=api('taos_errno',C.c_int,[C.c_void_p])
    errstr=api('taos_errstr',C.c_char_p,[C.c_void_p])
    free=api('taos_free_result',None,[C.c_void_p])
    close=api('taos_close',None,[C.c_void_p])
    class Field(C.Structure):
        _fields_=[('name',C.c_char*65),('type',C.c_int8),('bytes',C.c_int32)]
    nfields=api('taos_num_fields',C.c_int,[C.c_void_p])
    fields=api('taos_fetch_fields',C.POINTER(Field),[C.c_void_p])
    fetch=api('taos_fetch_row',C.POINTER(C.c_void_p),[C.c_void_p])
    lengths=api('taos_fetch_lengths',C.POINTER(C.c_int),[C.c_void_p])
    types={1:C.c_bool,2:C.c_int8,3:C.c_int16,4:C.c_int32,5:C.c_int64,
        6:C.c_float,7:C.c_double,9:C.c_int64,11:C.c_uint8,12:C.c_uint16,13:C.c_uint32,14:C.c_uint64}
    data=[]
    try:
        for statement in sql.split(';'):
            if not statement.strip(): continue
            result=query(conn,statement.encode())
            try:
                if errno(result): raise RuntimeError(errstr(result).decode())
                nf=nfields(result); fs=fields(result); data=[]
                while True:
                    row=fetch(result)
                    if not row: break
                    sizes=lengths(result); values={}
                    for j in range(nf):
                        name=fs[j].name.decode(); kind=fs[j].type; ptr=row[j]
                        if ptr is None: value=None
                        elif kind in types: value=C.cast(ptr,C.POINTER(types[kind])).contents.value
                        else: value=C.string_at(ptr,sizes[j]).decode(errors='replace')
                        values[name]=value
                    data.append(values)
                if errno(result): raise RuntimeError(errstr(result).decode())
            finally: free(result)
        return data
    finally: close(conn)

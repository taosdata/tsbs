package main

import (
	"encoding/gob"
	"encoding/json"
	"fmt"
	"io"
	"os"
)

// Decode the TDengine query fields without executing the queries.
func main() {
	decoder := gob.NewDecoder(os.Stdin)
	encoder := json.NewEncoder(os.Stdout)
	for {
		var q struct{ HumanLabel, SqlQuery, RawQuery, Path []byte }
		err := decoder.Decode(&q)
		if err == io.EOF {
			return
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		sql := q.SqlQuery
		if len(sql) == 0 {
			sql = q.RawQuery
		}
		if err := encoder.Encode(map[string]string{"label": string(q.HumanLabel), "sql": string(sql), "path": string(q.Path)}); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}
}

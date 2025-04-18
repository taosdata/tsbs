package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"time"
)

type dbCreator struct {
	daemonURL string
}

func (d *dbCreator) Init() {
	d.daemonURL = daemonURLs[0] // pick first one since it always exists
}

func (d *dbCreator) DBExists(dbName string) bool {
	dbs, err := d.listDatabases()
	if err != nil {
		log.Fatal(err)
	}

	for _, db := range dbs {
		if db == loader.DatabaseName() {
			return true
		}
	}
	return false
}

func (d *dbCreator) listDatabases() ([]string, error) {
	u := fmt.Sprintf("%s/api/v3/configure/database?show_deleted=true&format=csv", d.daemonURL)
	req, err := http.NewRequest("GET", u, nil)
	req.Header = http.Header{
		headerAuthorization: []string{fmt.Sprintf("Token %s", authToken)},
	}
	client := http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("listDatabases error: %s", err.Error())
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// issue: 使用/api/v3/configure/database 接口，指定 format = json，当 database 为空时， 返回的值不正确，返回值是右括号']'。 改为使用 format = csv
	lines := bytes.Split(body, []byte("\n"))
	if len(lines) == 1 {
		// No databases found
		return []string{}, nil
	}

	ret := []string{}
	for _, line := range lines[1:] {
		if len(line) == 0 {
			continue
		}
		fields := bytes.Split(line, []byte(","))
		if len(fields) != 2 {
			return nil, fmt.Errorf("invalid response format")
		}
		dbName := string(fields[0])
		deleted := string(fields[1]) == "true"
		if !deleted {
			ret = append(ret, dbName)
		}
	}
	return ret, nil
}

func (d *dbCreator) RemoveOldDB(dbName string) error {
	u := fmt.Sprintf("%s/api/v3/configure/database?db=%s", d.daemonURL, dbName)
	req, err := http.NewRequest("DELETE", u, nil)
	req.Header = http.Header{
		"Content-Type":      []string{"text/plain"},
		headerAuthorization: []string{fmt.Sprintf("Token %s", authToken)},
	}
	client := http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("drop db error: %s", err.Error())
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("drop db returned non-200 code: %d", resp.StatusCode)
	}
	time.Sleep(time.Second)
	return nil
}

func (d *dbCreator) CreateDB(dbName string) error {
	u := fmt.Sprintf("%s/api/v3/configure/database?db=%s", d.daemonURL, dbName)
	// Create the JSON payload
	payload := fmt.Sprintf(`{"db": "%s"}`, dbName)
	req, err := http.NewRequest("POST", u, bytes.NewBuffer([]byte(payload)))
	if err != nil {
		return err
	}

	// Set the content type to application/json
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+authToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	// does the body need to be read into the void?

	if resp.StatusCode != 200 {
		return fmt.Errorf("bad db create")
	}

	time.Sleep(time.Second)
	return nil
}

package connector

import (
	"bytes"
	"compress/gzip"
	"context"
	"database/sql/driver"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"sync"
	"time"

	jsoniter "github.com/json-iterator/go"
)

var jsonI = jsoniter.ConfigCompatibleWithStandardLibrary

type TaosConn struct {
	cfg    *config
	client *http.Client
	url    *url.URL
	uri    []byte
	header map[string][]string
	basic  string
	//fastHttpClient fasthttp.Client
}

func NewTaosConn(dsn string) (*TaosConn, error) {
	cfg, err := parseDSN(dsn)
	if err != nil {
		return nil, err
	}
	tc := &TaosConn{cfg: cfg}
	tc.client = &http.Client{
		Transport: &http.Transport{
			Proxy: http.ProxyFromEnvironment,
			DialContext: (&net.Dialer{
				Timeout:   30 * time.Second,
				KeepAlive: 30 * time.Second,
			}).DialContext,
			IdleConnTimeout:       90 * time.Second,
			TLSHandshakeTimeout:   10 * time.Second,
			ExpectContinueTimeout: 1 * time.Second,
			DisableCompression:    cfg.disableCompression,
		},
	}
	path := "/rest/sql"
	if len(cfg.dbName) != 0 {
		path = fmt.Sprintf("%s/%s", path, cfg.dbName)
	}
	tc.url = &url.URL{
		Scheme: cfg.net,
		Host:   fmt.Sprintf("%s:%d", cfg.addr, cfg.port),
		Path:   path,
	}

	tc.header = map[string][]string{
		"Connection": {"keep-alive"},
	}
	if cfg.token != "" {
		tc.url.RawQuery = fmt.Sprintf("token=%s", cfg.token)
	} else {
		basic := base64.StdEncoding.EncodeToString([]byte(cfg.user + ":" + cfg.passwd))
		tc.basic = fmt.Sprintf("Basic %s", basic)
		tc.header["Authorization"] = []string{fmt.Sprintf("Basic %s", basic)}
	}
	if !cfg.disableCompression {
		tc.header["Accept-Encoding"] = []string{"gzip"}
	}
	//tc.fastHttpClient = fasthttp.Client{}
	tc.uri = []byte(tc.url.String())
	return tc, nil
}

//func (tc *TaosConn) TaosQuery(ctx context.Context, sql []byte, _ []byte) (float64, []byte, error) {
//	req := fasthttp.AcquireRequest()
//	defer fasthttp.ReleaseRequest(req)
//	req.SetRequestURIBytes(tc.uri)
//	req.Header.SetMethod(fasthttp.MethodPost)
//	req.Header.Add(fasthttp.HeaderAuthorization, tc.basic)
//	req.SetBody(sql)
//	resp := fasthttp.AcquireResponse()
//	defer fasthttp.ReleaseResponse(resp)
//	start := time.Now()
//	err := tc.fastHttpClient.Do(req, resp)
//	if err != nil {
//		return 0, nil, err
//	}
//	body := resp.Body()
//	if resp.StatusCode() != fasthttp.StatusOK {
//		return 0, nil, fmt.Errorf("server response: %d - %s", resp.StatusCode(), string(body))
//	}
//	if !bytes.HasPrefix(body, []byte("{\"code\":0,")) {
//		return 0, nil, errors.New(string(body))
//	}
//	lag := float64(time.Since(start).Nanoseconds()) / 1e6 // milliseconds
//	return lag, body, nil
//}

func (tc *TaosConn) TaosQuery(ctx context.Context, sql []byte, data []byte) (float64, []byte, error) {
	body := ioutil.NopCloser(bytes.NewBuffer(sql))
	req := &http.Request{
		Method:     http.MethodPost,
		URL:        tc.url,
		Proto:      "HTTP/1.1",
		ProtoMajor: 1,
		ProtoMinor: 1,
		Header:     tc.header,
		Body:       body,
		Host:       tc.url.Host,
	}
	if ctx != nil {
		req = req.WithContext(ctx)
	}
	start := time.Now()
	resp, err := tc.client.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	respBody := resp.Body
	if !tc.cfg.disableCompression && equalFold(resp.Header.Get("Content-Encoding"), "gzip") {
		respBody, err = gzip.NewReader(resp.Body)
		if err != nil {
			return 0, nil, err
		}
	}
	if resp.StatusCode != http.StatusOK {
		body, err := ReadAll(resp.Body, data)
		if err != nil {
			return 0, nil, err
		}
		return 0, nil, fmt.Errorf("server response: %s - %s", resp.Status, string(body))
	}
	data, err = ReadAll(respBody, data)
	if err != nil {
		return 0, nil, err
	}
	lag := float64(time.Since(start).Nanoseconds()) / 1e6 // milliseconds
	if !bytes.HasPrefix(data, []byte("{\"code\":0,")) {
		return 0, nil, errors.New(string(data))
	}
	return lag, data, nil
}

type ByteBuffer struct {
	B []byte
}

func (bb *ByteBuffer) Reset() {
	bb.B = bb.B[:0]
}

func (bb *ByteBuffer) Write(p []byte) (int, error) {
	bb.B = append(bb.B, p...)
	return len(p), nil
}

type ByteBufferPool struct {
	p sync.Pool
}

func (bbp *ByteBufferPool) Get() *ByteBuffer {
	bbv := bbp.p.Get()
	if bbv == nil {
		return &ByteBuffer{}
	}
	return bbv.(*ByteBuffer)
}

func (bbp *ByteBufferPool) Put(bb *ByteBuffer) {
	bb.Reset()
	bbp.p.Put(bb)
}

var bufferPool ByteBufferPool

func (tc *TaosConn) Exec(sql []byte) (driver.Result, error) {
	bb := bufferPool.Get()
	_, _, err := tc.TaosQuery(nil, sql, bb.B)
	bufferPool.Put(bb)
	return nil, err
}

func (tc *TaosConn) Close() error {
	return nil
}

// equalFold is strings.EqualFold, ASCII only. It reports whether s and t
// are equal, ASCII-case-insensitively.
func equalFold(s, t string) bool {
	if len(s) != len(t) {
		return false
	}
	for i := 0; i < len(s); i++ {
		if lower(s[i]) != lower(t[i]) {
			return false
		}
	}
	return true
}

// lower returns the ASCII lowercase version of b.
func lower(b byte) byte {
	if 'A' <= b && b <= 'Z' {
		return b + ('a' - 'A')
	}
	return b
}

func ReadAll(r io.Reader, b []byte) ([]byte, error) {
	for {
		if len(b) == cap(b) {
			// Add more capacity (let append pick how much).
			b = append(b, 0)[:len(b)]
		}
		n, err := r.Read(b[len(b):cap(b)])
		b = b[:len(b)+n]
		if err != nil {
			if err == io.EOF {
				err = nil
			}
			return b, err
		}
	}
}

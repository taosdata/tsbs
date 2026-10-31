package tdengine

import (
	"math/rand"
	"strings"
	"testing"
	"time"

	"github.com/taosdata/tsbs/pkg/query"
)

// A discarded host sample changes both the current host and every later window.
// Preserve the first two CPU benchmark samples for the documented seed.
func TestHighCPUSingleHostSeededSamples(t *testing.T) {
	t.Setenv("GODEBUG", "randseednop=0")
	rand.Seed(123)
	start := time.Date(2016, 1, 1, 0, 0, 0, 0, time.UTC)
	base := BaseGenerator{}
	generator, err := base.NewDevops(start, start.Add(24*time.Hour), 4000)
	if err != nil {
		t.Fatal(err)
	}
	d := generator.(*Devops)
	want := []string{
		"SELECT * FROM host_249 WHERE usage_user > 90.0 and ts >= 1451628982646 AND ts < 1451672182646",
		"SELECT * FROM host_1435 WHERE usage_user > 90.0 and ts >= 1451627250894 AND ts < 1451670450894",
	}
	for i, expected := range want {
		q := d.GenerateEmptyQuery()
		d.HighCPUForHosts(q, 1)
		if got := strings.TrimSpace(string(q.(*query.TDengine).SqlQuery)); got != expected {
			t.Errorf("sample %d: got %q, want %q", i, got, expected)
		}
		q.Release()
	}
}

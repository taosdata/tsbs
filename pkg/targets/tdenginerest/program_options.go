package tdenginerest

import (
	"fmt"
)

type LoadingOptions struct {
	User           string
	Pass           string
	Host           string
	Port           int
	VGroups        int
	Buffer         int
	Pages          int
	SttTrigger     int
	WalFsyncPeriod *int
}

func (o *LoadingOptions) GetConnectString(db string) string {
	//user:passwd@http(fqdn:6041)/dbname
	return fmt.Sprintf("%s:%s@http(%s:%d)/%s", o.User, o.Pass, o.Host, o.Port, db)

}

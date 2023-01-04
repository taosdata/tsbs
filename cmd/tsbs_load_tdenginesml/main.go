package main

import (
	"fmt"
	"net/http"
	_ "net/http/pprof"

	"github.com/blagojts/viper"
	"github.com/spf13/pflag"
	"github.com/taosdata/tsbs/internal/utils"
	"github.com/taosdata/tsbs/load"
	"github.com/taosdata/tsbs/pkg/data/source"
	"github.com/taosdata/tsbs/pkg/targets/tdenginesml"
)

func initProgramOptions() (*tdenginesml.LoadingOptions, load.BenchmarkRunner, *load.BenchmarkRunnerConfig) {
	target := tdenginesml.NewTarget()
	loaderConf := load.BenchmarkRunnerConfig{}
	loaderConf.AddToFlagSet(pflag.CommandLine)
	target.TargetSpecificFlags("", pflag.CommandLine)
	pflag.Parse()
	err := utils.SetupConfigFile()

	if err != nil {
		panic(fmt.Errorf("fatal error config file: %s", err))
	}

	if err := viper.Unmarshal(&loaderConf); err != nil {
		panic(fmt.Errorf("unable to decode config: %s", err))
	}
	opts := tdenginesml.LoadingOptions{}
	viper.SetTypeByDefaultValue(true)
	opts.User = viper.GetString("user")
	opts.Pass = viper.GetString("pass")
	opts.Host = viper.GetString("host")
	opts.Port = viper.GetInt("port")
	vgroups := viper.GetInt("vgroups")
	if vgroups > 0 {
		opts.VGroups = vgroups
	}
	buffer := viper.GetInt("buffer")
	if buffer > 0 {
		opts.Buffer = buffer
	}
	pages := viper.GetInt("pages")
	if pages > 0 {
		opts.Pages = pages
	}
	sttTrigger := viper.GetInt("stt_trigger")
	if sttTrigger > 0 {
		opts.SttTrigger = sttTrigger
	}
	if viper.IsSet("wal_fsync_period") {
		walFsyncPeriod := viper.GetInt("wal_fsync_period")
		opts.WalFsyncPeriod = &walFsyncPeriod
	}
	loader := load.GetBenchmarkRunner(loaderConf)
	return &opts, loader, &loaderConf
}
func main() {
	go http.ListenAndServe(":6060", nil)
	//f, err := os.Create("./cpu.prof")
	//if err != nil {
	//	log.Fatal("could not create CPU profile: ", err)
	//}
	//if err := pprof.StartCPUProfile(f); err != nil {
	//	log.Fatal("could not start CPU profile: ", err)
	//}
	//defer pprof.StopCPUProfile()
	opts, loader, loaderConf := initProgramOptions()
	benchmark, err := tdenginesml.NewBenchmark(loaderConf.DBName, opts, &source.DataSourceConfig{
		Type: source.FileDataSourceType,
		File: &source.FileDataSourceConfig{Location: loaderConf.FileName},
	})
	if err != nil {
		panic(err)
	}
	loader.RunBenchmark(benchmark)
}

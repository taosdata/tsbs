package tdengine

type LoadingOptions struct {
	User       string
	Pass       string
	Host       string
	Port       int
	VGroups    int
	Buffer     int
	Pages      int
	SstTrigger int
}

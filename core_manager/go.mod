module github.com/troodi/xray-desktop/core-manager

go 1.26

require (
	github.com/miekg/dns v1.1.72
	github.com/xtls/xray-core v0.0.0
	golang.org/x/net v0.53.0
	golang.org/x/sys v0.43.0
	google.golang.org/grpc v1.80.0
)

require (
	github.com/asaskevich/govalidator v0.0.0-20210307081110-f21760c49a8d // indirect
	github.com/aymansor/gohosts v0.1.1 // indirect
	github.com/dimchansky/utfbom v1.1.1 // indirect
	github.com/goodhosts/hostsfile v0.1.7 // indirect
	github.com/magefile/mage v1.15.0 // indirect
	github.com/pires/go-proxyproto v0.12.0 // indirect
	go4.org/netipx v0.0.0-20231129151722-fdeea329fbba // indirect
	golang.org/x/mod v0.34.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/text v0.36.0 // indirect
	golang.org/x/tools v0.43.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260120221211-b8f7ae30c516 // indirect
	google.golang.org/protobuf v1.36.11 // indirect
)

replace github.com/xtls/xray-core => ../xray_runtime/xray-core

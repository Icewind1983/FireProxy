package xray

import "github.com/troodi/xray-desktop/core-manager/internal/config"

type Config map[string]any

type BuildOptions struct {
	BindInterface string
	BindAddress   string
	TUNInterface  string
	TUNAddress    string
	TUNMTU        int
	
}

func DefaultBuildOptions() BuildOptions {
	return BuildOptions{
		TUNInterface: "xray0",
		TUNAddress:   "198.18.0.1",
		TUNMTU:       1500,
	}
}

func Build(cfg config.AppConfig) Config {
	return BuildWithOptions(cfg, DefaultBuildOptions())
}

func BuildWithOptions(cfg config.AppConfig, opts BuildOptions) Config {
	cfg.ProxyDomains = filterDisabled(cfg.ProxyDomains, cfg.DisabledProxyDomains)
	cfg.DirectDomains = filterDisabled(cfg.DirectDomains, cfg.DisabledDirectDomains)
	cfg.BlockedDomains = filterDisabled(cfg.BlockedDomains, cfg.DisabledBlockedDomains)

	rules := make([]map[string]any, 0, len(cfg.ProxyDomains)+len(cfg.DirectDomains)+len(cfg.BlockedDomains)+8)
	activeProfile := findActiveProfile(cfg)

	if cfg.TUNEnabled {
		rules = append(rules, map[string]any{
			"type":        "field",
			"inboundTag":  []string{"tun-in"},
			"port":        53,
			"network":     "tcp,udp",
			"outboundTag": "dns-out",
		})
	}

	if len(cfg.BlockedDomains) > 0 {
		rules = appendDomainRule(rules, cfg.BlockedDomains, "block")
	}

	if cfg.RulesProfile == config.RulesProfileRussia {
		rules = appendRussiaSmartRules(rules, cfg)
	} else {
		if len(cfg.ProxyDomains) > 0 {
			rules = appendDomainRule(rules, cfg.ProxyDomains, "proxy")
		}

		switch cfg.RoutingMode {
		case config.RoutingWhitelist:
			rules = append(rules, map[string]any{
				"type":        "field",
				"port":        "0-65535",
				"outboundTag": "direct",
			})
		case config.RoutingBlacklist:
			rules = appendDomainRule(rules, cfg.DirectDomains, "direct")
			rules = append(rules, map[string]any{
				"type":        "field",
				"port":        "0-65535",
				"outboundTag": "proxy",
			})
		default:
			rules = appendDomainRule(rules, cfg.DirectDomains, "direct")
			rules = append(rules, map[string]any{
				"type":        "field",
				"port":        "0-65535",
				"outboundTag": "proxy",
			})
		}
	}

	return Config{
		"log":      map[string]any{"loglevel": "error"},
		"dns":      buildDNS(cfg),
		"inbounds": buildInbounds(cfg, opts),
		"outbounds": []map[string]any{
			buildProxyOutbound(activeProfile, opts.BindInterface, opts.BindAddress),
			buildFreedomOutbound("direct", opts.BindInterface, opts.BindAddress, cfg.RulesProfile == config.RulesProfileRussia),
			{"tag": "dns-out", "protocol": "dns"},
			{"tag": "block", "protocol": "blackhole"},
		},
		"routing": map[string]any{
			"domainStrategy": domainStrategy(cfg),
			"rules":          rules,
		},
		"api": map[string]any{
			"tag":      "api",
			"listen":   LocalLoopbackStatsAPI,
			"services": []string{"StatsService"},
		},
		"stats": map[string]any{},
		"policy": map[string]any{
			"system": map[string]any{
				"statsInboundUplink":    true,
				"statsInboundDownlink":  true,
				"statsOutboundUplink":   true,
				"statsOutboundDownlink": true,
			},
		},
	}
}

func buildDNS(cfg config.AppConfig) map[string]any {
	//if cfg.RulesProfile == config.RulesProfileRussia {
		//servers := make([]any, 0, 8)
		
		//if len(cfg.BlockedDomains) > 0 {
		//	servers = append(servers, dnsServer("quic+local://searx.my.to:853", cfg.BlockedDomains, nil, true))
		//}

		//if len(cfg.ProxyDomains) > 0 {
		//	servers = append(servers, dnsServer("quic+local://searx.my.to:853", cfg.ProxyDomains, nil, true))
		//}
		//if len(cfg.DirectDomains) > 0 {
		//	servers = append(servers, dnsServer("quic+local://searx.my.to:853", cfg.DirectDomains, []string{"geoip:private", "geoip:ru"}, true))
		//}

		//servers = append(servers,
		    //dnsServer("188.137.180.163", []string{"domain:searx.my.to"}, nil, true),
			//dnsServer("quic+local://searx.my.to:853", nil, nil, true),
		//	dnsServer("quic+local://searx.my.to:853", []string{"geosite:ru-blocked"}, nil, true),
		//	dnsServer("188.137.180.163", []string{"full:https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat", "full:https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat", "full:https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat", "full:https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"}, nil, true),
		//	dnsServer("localhost", []string{"geosite:private"}, []string{"geoip:private"}, true),
		//	dnsServer("quic+local://searx.my.to:853", []string{"geosite:ru-available-only-inside"}, []string{"geoip:ru"}, true),
		//	dnsServer("quic+local://searx.my.to:853", []string{"regexp:(^|\\.).*\\.ru$", "regexp:(^|\\.).*\\.xn--p1ai$"},  []string{"geoip:ru"}, true),
		//)

		//return map[string]any{
		//	"servers":       servers,
		//	"queryStrategy": "UseIPv4",
		//	"finalQuery": true,
		//}
	//}

	dnsServers := []string{"quic+local://searx.my.to:853"}
	//if cfg.DNSMode == config.DNSDirect {
	//	dnsServers = []string{"quic+local://searx.my.to:853"}
	//}

	//if cfg.DNSMode == config.DNSAuto {
	//	dnsServers = []string{"quic+local://searx.my.to:853"}
	//}

	//if cfg.DNSMode == config.DNSProxy {
	//	dnsServers = []string{"quic+local://searx.my.to:853"}
	//}

	dnsConfig := map[string]any{"servers": dnsServers}
	dnsConfig["queryStrategy"] = "UseIPv4"
	//dnsConfig["finalQuery"] = true
	if cfg.TUNEnabled {
		dnsConfig["queryStrategy"] = "UseIPv4"
	}
	return dnsConfig
}

func dnsServer(address string, domains []string, expectIPs []string, disableFallback bool) map[string]any {
	server := map[string]any{
		"address":      address,
		"skipFallback": true,
	}
	if disableFallback {
		server["disableFallbackIfMatch"] = true
	}
	if len(domains) > 0 {
		server["domains"] = domains
	}
	if len(expectIPs) > 0 {
		server["expectIPs"] = expectIPs
	}
	return server
}

func appendRussiaSmartRules(rules []map[string]any, cfg config.AppConfig) []map[string]any {
	// Keep local/private destinations outside the tunnel even when TUN or
	// system proxy is enabled, so LAN traffic does not loop through Xray.
	rules = appendIPRule(rules, []string{"geoip:private"}, "direct")
	rules = appendDomainRule(rules, []string{"domain:localhost"}, "direct")	

	if len(cfg.BlockedDomains) > 0 {
		rules = appendDomainRule(rules, cfg.BlockedDomains, "block")
	}

	if len(cfg.ProxyDomains) > 0 {
		rules = appendDomainRule(rules, cfg.ProxyDomains, "proxy")
	}

	// Smart Russia routing order:
	// 1. Resources blocked in Russia -> proxy
	// 2. Resources available only from inside Russia -> direct
	// 3. Other Russian traffic -> direct
	// 4. Everything else -> proxy
	
	if len(cfg.DirectDomains) > 0 {
		rules = appendDomainRule(rules, cfg.DirectDomains, "direct")
	}
	
	//rules = appendDomainRule(rules, []string{"full:https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat", "full:https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat", "full:https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat", "full:https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"}, "direct")
	
	//rules = appendDomainRule(rules, []string{"process:uTorrent.exe", "process:BitTorrent.exe", "process:qbittorrent.exe", "process:deluge.exe"}, "direct")
	
	rules = appendDomainRule(rules, []string{"geosite:category-ads", "geosite:kaspersky", "geosite:qihoo360", "geosite:win-spy"}, "block")
	rules = appendDomainRule(rules, []string{"domain:browser.rpc.alice.yandex.ru", "domain:browser.yandex.ru", "domain:browser.yandex.net", "domain:common.dot.dns.yandex.net"}, "block")
	rules = appendDomainRule(rules, []string{"ext:dlc.dat:ads"}, "block")
	
	rules = appendDomainRule(rules, []string{"ext:dlc.dat:direct-ru"}, "direct")
	rules = appendDomainRule(rules, []string{"domain:hcaptcha.com", "domain:geetest.com"}, "direct")
	
	rules = appendDomainRule(rules, []string{"geosite:ru-blocked"}, "proxy")
	rules = appendIPRule(rules, []string{"geoip:ru-blocked"}, "proxy")
	rules = appendDomainRule(rules, []string{"domain:google.ru"}, "proxy")

	rules = appendDomainRule(rules, []string{"geosite:ru-available-only-inside", "geosite:category-ip-geo-detect"}, "direct")
	rules = appendDomainRule(rules, []string{"geosite:tld-ru", "geosite:category-ru", "geosite:category-gov-ru", "geosite:category-bank-ru", "geosite:category-travel-ru", "geosite:sber", "geosite:timeweb", "geosite:tilda", "geosite:vk", "geosite:mailru", "geosite:group-ib", "geosite:mailru-group", "geosite:rostelecom", "geosite:yandex", "geosite:habr", "geosite:wildberries", "geosite:x5", "geosite:ozon",  "geosite:mts-ru"}, "direct")
	rules = appendDomainRule(rules, []string{"domain:whatismyip.io", "domain:nettools.club", "domain:changeip.com", "domain:opera.com", "domain:operacdn.com",}, "direct")
	rules = appendDomainRule(rules, []string{"regexp:(^|\\.).*\\.ru$", "regexp:(^|\\.).*\\.xn--p1ai$", "regexp:(^|\\.).*\\.by$", "regexp:(^|\\.).*\\.cloud$", "regexp:(^|\\.).*\\.moscow$", "regexp:(^|\\.).*\\.xn--80adxhks$", "regexp:(^|\\.).*\\.su$", "regexp:(^|\\.).*\\.biz$", "regexp:(^|\\.).*\\.yandex$", "regexp:(^|\\.).*\\.media$", "regexp:burp$", "regexp:(^|\\.).*\\.press$", "regexp:(^|\\.).*\\.tatar$", "regexp:(^|\\.).*\\.fm$"}, "direct")
	rules = appendIPRule(rules, []string{"ext:geoip.dat:ru"}, "direct")

	return append(rules, map[string]any{
		"type":        "field",
		"port":        "0-65535",
		"outboundTag": "proxy",
	})
}

func appendDomainRule(rules []map[string]any, domains []string, outboundTag string) []map[string]any {
	if len(domains) == 0 {
		return rules
	}
	return append(rules, map[string]any{
		"type":        "field",
		"domain":      domains,
		"outboundTag": outboundTag,
	})
}

func appendIPRule(rules []map[string]any, ips []string, outboundTag string) []map[string]any {
	if len(ips) == 0 {
		return rules
	}
	return append(rules, map[string]any{
		"type":        "field",
		"ip":          ips,
		"outboundTag": outboundTag,
	})
}

//Стратегия разрешения доменных имен. Используются разные стратегии в зависимости от настройки.

//    "AsIs": для выбора маршрута используются только доменные имена. Значение по умолчанию.
//    "IPIfNonMatch": если доменное имя не соответствует ни одному правилу, доменное имя разрешается в IP-адрес (запись A или запись AAAA) для повторного сопоставления;
//        Если у доменного имени несколько записей A, предпринимается попытка сопоставить все записи A, пока одна из них не будет соответствовать какому-либо правилу;
//        Разрешенный IP-адрес используется только при выборе маршрута, в пересылаемых пакетах данных по-прежнему используется исходное доменное имя;
//    "IPOnDemand": если при сопоставлении встречается любое правило на основе IP-адреса, доменное имя немедленно разрешается в IP-адрес для сопоставления;

func domainStrategy(cfg config.AppConfig) string {
	if cfg.RulesProfile == config.RulesProfileRussia {
		return "IPIfNonMatch"
	}
	return "AsIs"
}

func findActiveProfile(cfg config.AppConfig) config.ServerProfile {
	for _, profile := range cfg.Profiles {
		if profile.ID == cfg.ActiveProfileID {
			return profile
		}
	}
	if len(cfg.Profiles) > 0 {
		return cfg.Profiles[0]
	}
	return config.ServerProfile{}
}

func buildFreedomOutbound(tag, bindInterface, bindAddress string, useIPv4Resolver bool) map[string]any {
	outbound := map[string]any{
		"tag":      tag,
		"protocol": "freedom",
	}

	if bindAddress != "" {
		outbound["sendThrough"] = bindAddress
	}

	if useIPv4Resolver {
		outbound["settings"] = map[string]any{
			"domainStrategy": "UseIPv4",
		}
	}

	if bindInterface != "" {
		outbound["streamSettings"] = map[string]any{
			"sockopt": map[string]any{
				"interface": bindInterface,
			},
		}
	}

	return outbound
}

func buildProxyOutbound(profile config.ServerProfile, bindInterface, bindAddress string) map[string]any {
	if profile.Protocol == "" || profile.Address == "" || profile.Port <= 0 {
		return buildFreedomOutbound("proxy", bindInterface, bindAddress, false)
	}

	outbound := map[string]any{
		"tag":      "proxy",
		"protocol": profile.Protocol,
	}
	if bindAddress != "" {
		outbound["sendThrough"] = bindAddress
	}

	if settings := buildOutboundSettings(profile); settings != nil {
		outbound["settings"] = settings
	}
	if streamSettings := buildStreamSettings(profile, bindInterface); streamSettings != nil {
		outbound["streamSettings"] = streamSettings
	}

	return outbound
}

func buildOutboundSettings(profile config.ServerProfile) map[string]any {
	switch profile.Protocol {
	case "vless":
		user := map[string]any{
			"id":         profile.UserID,
			"encryption": "none",
		}
		if profile.Flow != "" {
			user["flow"] = profile.Flow
		}
		return map[string]any{
			"vnext": []map[string]any{
				{
					"address": profile.Address,
					"port":    profile.Port,
					"users":   []map[string]any{user},
				},
			},
		}
	case "vmess":
		user := map[string]any{
			"id":       profile.UserID,
			"security": "auto",
		}
		return map[string]any{
			"vnext": []map[string]any{
				{
					"address": profile.Address,
					"port":    profile.Port,
					"users":   []map[string]any{user},
				},
			},
		}
	case "trojan":
		server := map[string]any{
			"address":  profile.Address,
			"port":     profile.Port,
			"password": profile.Password,
		}
		if profile.Flow != "" {
			server["flow"] = profile.Flow
		}
		return map[string]any{
			"servers": []map[string]any{server},
		}
	default:
		return nil
	}
}

func buildStreamSettings(profile config.ServerProfile, bindInterface string) map[string]any {
	network := profile.Transport
	if network == "" {
		network = "tcp"
	}

	security := profile.Security
	if security == "" {
		security = "none"
	}

	streamSettings := map[string]any{
		"network":  network,
		"security": security,
	}

	if bindInterface != "" {
		streamSettings["sockopt"] = map[string]any{
			"interface": bindInterface,
		}
	}

	switch network {
	case "ws":
		ws := map[string]any{}
		if profile.Path != "" {
			ws["path"] = profile.Path
		}
		headers := map[string]any{}
		if profile.Host != "" {
			headers["Host"] = profile.Host
		}
		if len(headers) > 0 {
			ws["headers"] = headers
		}
		if len(ws) > 0 {
			streamSettings["wsSettings"] = ws
		}
	case "grpc":
		grpc := map[string]any{}
		if profile.Path != "" {
			grpc["serviceName"] = profile.Path
		}
		if profile.Host != "" {
			grpc["authority"] = profile.Host
		}
		if len(grpc) > 0 {
			streamSettings["grpcSettings"] = grpc
		}
	case "httpupgrade":
		httpUpgrade := map[string]any{}
		if profile.Host != "" {
			httpUpgrade["host"] = profile.Host
		}
		if profile.Path != "" {
			httpUpgrade["path"] = profile.Path
		}
		if len(httpUpgrade) > 0 {
			streamSettings["httpupgradeSettings"] = httpUpgrade
		}
	}

	switch security {
	case "tls":
		tlsSettings := map[string]any{}
		if profile.SNI != "" {
			tlsSettings["serverName"] = profile.SNI
		}
		if profile.Fingerprint != "" {
			tlsSettings["fingerprint"] = profile.Fingerprint
		}
		if profile.ALPN != "" {
			tlsSettings["alpn"] = splitAndTrim(profile.ALPN)
		}
		if len(tlsSettings) > 0 {
			streamSettings["tlsSettings"] = tlsSettings
		}
	case "reality":
		realitySettings := map[string]any{}
		if profile.SNI != "" {
			realitySettings["serverName"] = profile.SNI
		}
		if profile.Fingerprint != "" {
			realitySettings["fingerprint"] = profile.Fingerprint
		}
		if profile.RealityPublicKey != "" {
			realitySettings["publicKey"] = profile.RealityPublicKey
		}
		if profile.RealityShortID != "" {
			realitySettings["shortId"] = profile.RealityShortID
		}
		if profile.SpiderX != "" {
			realitySettings["spiderX"] = profile.SpiderX
		}
		if realitySettings["fingerprint"] == nil {
			realitySettings["fingerprint"] = "firefox"
		}
		streamSettings["realitySettings"] = realitySettings
	}

	return streamSettings
}

func filterDisabled(all []string, disabled []string) []string {
	if len(disabled) == 0 {
		return all
	}
	set := make(map[string]bool, len(disabled))
	for _, d := range disabled {
		set[d] = true
	}
	result := make([]string, 0, len(all))
	for _, item := range all {
		if !set[item] {
			result = append(result, item)
		}
	}
	return result
}

func splitAndTrim(value string) []string {
	items := make([]string, 0, 2)
	current := ""
	for _, ch := range value {
		if ch == ',' {
			if current != "" {
				items = append(items, current)
				current = ""
			}
			continue
		}
		if ch != ' ' && ch != '\t' {
			current += string(ch)
		}
	}
	if current != "" {
		items = append(items, current)
	}
	return items
}

func buildInbounds(cfg config.AppConfig, opts BuildOptions) []map[string]any {
	inbounds := []map[string]any{
		{
			"tag":      "mixed-in",
			"port":     config.DefaultMixedInboundPort,
			"listen":   "127.0.0.1",
			"protocol": "mixed",
			"settings": map[string]any{
				"auth": "noauth",
				"udp":  true,
			},
			"sniffing": map[string]any{
				"enabled":      true,
				"routeOnly":    false,
				"destOverride": []string{"http", "tls", "quic"},
			},
		},
	}

	if cfg.TUNEnabled {
		inbounds = append(inbounds, map[string]any{
			"tag":      "tun-in",
			"port":     0,
			"protocol": "tun",
			"settings": map[string]any{
				"name": opts.TUNInterface,
				"MTU":  opts.TUNMTU,
			},
			"sniffing": map[string]any{
				"enabled":      true,
				"routeOnly":    false,
				"destOverride": []string{"http", "tls", "quic"},
			},
		})
	}

	return inbounds
}

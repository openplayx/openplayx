package main

import (
	"context"
	"errors"
	"net"
	"runtime"

	"github.com/sagernet/sing-box/adapter"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/dns"
	"github.com/sagernet/sing-box/dns/transport/local"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"

	mDNS "github.com/miekg/dns"
)

// useSystemResolver is true where sing-box's own "local" DNS transport cannot
// work. On Android it reads /etc/resolv.conf, which does not exist, falls back
// to [::1]:53 and every relay host lookup fails before any TCP is attempted.
// Go's resolver uses the platform's getaddrinfo there (cgo), which follows the
// active network and Private DNS. Darwin with cgo already uses the system.
var useSystemResolver = runtime.GOOS == "android"

// lookupNetIP is replaced in tests.
var lookupNetIP = net.DefaultResolver.LookupNetIP

// registerLocalDNS registers the "local" DNS type that relay outbounds use to
// resolve their server host.
func registerLocalDNS(registry *dns.TransportRegistry) {
	if !useSystemResolver {
		local.RegisterTransport(registry)
		return
	}
	dns.RegisterTransport[option.LocalDNSServerOptions](registry, C.DNSTypeLocal, newSystemTransport)
}

// systemTransport answers A/AAAA through the system resolver and leaves every
// other query type to sing-box's own local transport.
type systemTransport struct {
	adapter.DNSTransport
}

func newSystemTransport(ctx context.Context, logger log.ContextLogger, tag string, options option.LocalDNSServerOptions) (adapter.DNSTransport, error) {
	transport, err := local.NewTransport(ctx, logger, tag, options)
	if err != nil {
		return nil, err
	}
	return &systemTransport{DNSTransport: transport}, nil
}

func (t *systemTransport) Exchange(ctx context.Context, message *mDNS.Msg) (*mDNS.Msg, error) {
	question := message.Question[0]
	var network string
	switch question.Qtype {
	case mDNS.TypeA:
		network = "ip4"
	case mDNS.TypeAAAA:
		network = "ip6"
	default:
		return t.DNSTransport.Exchange(ctx, message)
	}
	addresses, err := lookupNetIP(ctx, network, dns.FqdnToDomain(question.Name))
	if err != nil {
		var dnsError *net.DNSError
		if errors.As(err, &dnsError) && dnsError.IsNotFound {
			return nil, dns.RcodeNameError
		}
		return nil, err
	}
	return dns.FixedResponse(message.Id, question, addresses, C.DefaultDNSTTL), nil
}

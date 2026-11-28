package main

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/netip"
	"sync"
	"testing"
	"time"

	M "github.com/sagernet/sing/common/metadata"
)

func TestForwardAndClose(t *testing.T) {
	target, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer target.Close()
	go func() {
		for {
			c, e := target.Accept()
			if e != nil {
				return
			}
			go func() { defer c.Close(); io.Copy(c, c) }()
		}
	}()
	port, err := startSession(fmt.Sprintf(`{"outbound":{"type":"direct"},"targetPort":%d}`, target.Addr().(*net.TCPAddr).Port))
	if err != nil {
		t.Fatal(err)
	}
	c, err := net.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", port))
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	c.SetDeadline(time.Now().Add(5 * time.Second))
	c.Write([]byte("media"))
	buf := make([]byte, 5)
	if _, err = io.ReadFull(c, buf); err != nil || string(buf) != "media" {
		t.Fatalf("forward failed: %v", err)
	}
	stopSession(port)
	stopSession(port)
	if _, err = c.Read(buf); err == nil {
		t.Fatal("active connection was not cancelled")
	}
	if _, err = net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", port), time.Second); err == nil {
		t.Fatal("listener remained open")
	}
}

// Android's sing-box local DNS queries [::1]:53 and fails; relay hosts must
// resolve through the system resolver instead.
func TestRelayHostUsesSystemResolver(t *testing.T) {
	target, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer target.Close()
	accepted := make(chan struct{}, 1)
	go func() {
		c, e := target.Accept()
		if e == nil {
			accepted <- struct{}{}
			c.Close()
		}
	}()
	previous, previousLookup := useSystemResolver, lookupNetIP
	defer func() { useSystemResolver, lookupNetIP = previous, previousLookup }()
	useSystemResolver = true
	// sing-box resolves A and AAAA concurrently: guard the recorded lookups.
	var askedMu sync.Mutex
	var asked []string
	lookupNetIP = func(_ context.Context, network, host string) ([]netip.Addr, error) {
		askedMu.Lock()
		asked = append(asked, network+" "+host)
		askedMu.Unlock()
		if host != "relay.example.test" {
			return nil, &net.DNSError{Name: host, IsNotFound: true}
		}
		if network == "ip6" {
			return nil, &net.DNSError{Name: host, IsNotFound: true}
		}
		return []netip.Addr{netip.MustParseAddr("127.0.0.1")}, nil
	}
	port, err := startSession(fmt.Sprintf(`{"outbound":{"type":"direct"},"targetPort":%d}`, target.Addr().(*net.TCPAddr).Port))
	if err != nil {
		t.Fatal(err)
	}
	defer stopSession(port)
	core := handles.entries[port].box
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c, err := core.Outbound().Default().DialContext(ctx, "tcp", M.ParseSocksaddrHostPort("relay.example.test", uint16(target.Addr().(*net.TCPAddr).Port)))
	if err != nil {
		askedMu.Lock()
		defer askedMu.Unlock()
		t.Fatalf("dial via system resolver failed: %v (lookups %v)", err, asked)
	}
	c.Close()
	select {
	case <-accepted:
	case <-time.After(5 * time.Second):
		t.Fatal("target never accepted")
	}
	askedMu.Lock()
	n := len(asked)
	askedMu.Unlock()
	if n == 0 {
		t.Fatal("system resolver was not used")
	}
}

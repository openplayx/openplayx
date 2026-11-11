// Application-only transport: one loopback listener per allocated service.
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"encoding/json"
	"io"
	"net"
	"sync"
	"time"
	"unsafe"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter/endpoint"
	"github.com/sagernet/sing-box/adapter/inbound"
	"github.com/sagernet/sing-box/adapter/outbound"
	S "github.com/sagernet/sing-box/adapter/service"
	"github.com/sagernet/sing-box/dns"
	"github.com/sagernet/sing-box/dns/transport/local"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing-box/protocol/direct"
	"github.com/sagernet/sing-box/protocol/vless"
	SJ "github.com/sagernet/sing/common/json"
	M "github.com/sagernet/sing/common/metadata"
)

type request struct {
	Outbound   json.RawMessage `json:"outbound"`
	TargetPort uint16          `json:"targetPort"`
}
type session struct {
	box         *box.Box
	listener    net.Listener
	cancel      context.CancelFunc
	mu          sync.Mutex
	closed      bool
	connections map[net.Conn]bool
}

var handles = struct {
	sync.Mutex
	entries map[int]*session
}{entries: make(map[int]*session)}

func transportContext() context.Context {
	out := outbound.NewRegistry()
	direct.RegisterOutbound(out)
	vless.RegisterOutbound(out)
	dnsRegistry := dns.NewTransportRegistry()
	local.RegisterTransport(dnsRegistry)
	return box.Context(context.Background(), inbound.NewRegistry(), out, endpoint.NewRegistry(), dnsRegistry, S.NewRegistry())
}
func startSession(input string) (int, error) {
	var req request
	if err := json.Unmarshal([]byte(input), &req); err != nil {
		return 0, err
	}
	ctx, cancel := context.WithCancel(transportContext())
	opts, err := SJ.UnmarshalExtendedContext[option.Options](ctx, []byte(`{"log":{"disabled":true},"outbounds":[`+string(req.Outbound)+`]}`))
	if err != nil {
		cancel()
		return 0, err
	}
	core, err := box.New(box.Options{Options: opts, Context: ctx})
	if err != nil {
		cancel()
		return 0, err
	}
	if err = core.Start(); err != nil {
		core.Close()
		cancel()
		return 0, err
	}
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		core.Close()
		cancel()
		return 0, err
	}
	s := &session{box: core, listener: listener, cancel: cancel, connections: make(map[net.Conn]bool)}
	port := listener.Addr().(*net.TCPAddr).Port
	handles.Lock()
	handles.entries[port] = s
	handles.Unlock()
	go func() {
		for {
			client, err := listener.Accept()
			if err != nil {
				return
			}
			if !s.track(client) {
				client.Close()
				continue
			}
			go func() {
				defer s.remove(client)
				dialCtx, stop := context.WithTimeout(ctx, 15*time.Second)
				upstream, err := core.Outbound().Default().DialContext(dialCtx, "tcp", M.ParseSocksaddrHostPort("127.0.0.1", req.TargetPort))
				stop()
				if err != nil {
					return
				}
				if !s.track(upstream) {
					upstream.Close()
					return
				}
				defer s.remove(upstream)
				done := make(chan struct{})
				go func() {
					io.Copy(upstream, client)
					if tcp, ok := upstream.(interface{ CloseWrite() error }); ok {
						tcp.CloseWrite()
					}
					close(done)
				}()
				io.Copy(client, upstream)
				client.Close()
				upstream.Close()
				<-done
			}()
		}
	}()
	return port, nil
}
func (s *session) track(c net.Conn) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return false
	}
	s.connections[c] = true
	return true
}
func (s *session) remove(c net.Conn) { c.Close(); s.mu.Lock(); delete(s.connections, c); s.mu.Unlock() }
func stopSession(port int) {
	handles.Lock()
	s := handles.entries[port]
	delete(handles.entries, port)
	handles.Unlock()
	if s == nil {
		return
	}
	s.cancel()
	s.listener.Close()
	s.mu.Lock()
	s.closed = true
	for c := range s.connections {
		c.Close()
	}
	s.mu.Unlock()
	s.box.Close()
}

//export opx_remote_start
func opx_remote_start(data *C.char) C.int {
	var req request
	if json.Unmarshal([]byte(C.GoString(data)), &req) != nil || req.TargetPort == 0 {
		return -1
	}
	var outbound struct {
		Type string `json:"type"`
		TLS  struct {
			Enabled  bool `json:"enabled"`
			Insecure bool `json:"insecure"`
		} `json:"tls"`
	}
	if json.Unmarshal(req.Outbound, &outbound) != nil || outbound.Type != "vless" || !outbound.TLS.Enabled || outbound.TLS.Insecure {
		return -1
	}
	port, err := startSession(C.GoString(data))
	if err != nil {
		return -1
	}
	return C.int(port)
}

//export opx_remote_stop
func opx_remote_stop(port C.int) { stopSession(int(port)) }

//export opx_remote_alloc
func opx_remote_alloc(size C.int) unsafe.Pointer {
	if size <= 0 || size > 1024*1024 {
		return nil
	}
	return C.malloc(C.size_t(size))
}

//export opx_remote_free
func opx_remote_free(ptr unsafe.Pointer) { C.free(ptr) }
func main()                              {}

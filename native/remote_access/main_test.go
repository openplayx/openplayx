package main

import (
	"fmt"
	"io"
	"net"
	"testing"
	"time"
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

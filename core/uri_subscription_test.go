package main

import (
	"encoding/base64"
	"testing"
)

func TestHandleConvertURISubscriptionPlaintextAndBase64(t *testing.T) {
	line := "vless://00112233-4455-6677-8899-aabbccddeeff%23pure@example.com:443?type=ws&security=tls&alpn=http%2F1.1&path=%2Fwebsocket#Pure"
	for name, input := range map[string]string{
		"plaintext": line,
		"base64":    base64.StdEncoding.EncodeToString([]byte(line)),
	} {
		t.Run(name, func(t *testing.T) {
			proxies, err := handleConvertURISubscription(input)
			if err != nil {
				t.Fatal(err)
			}
			if len(proxies) != 1 {
				t.Fatalf("got %d proxies", len(proxies))
			}
			if got := proxies[0]["uuid"]; got != "00112233-4455-6677-8899-aabbccddeeff#pure" {
				t.Fatalf("uuid=%v", got)
			}
		})
	}
}

func TestHandleConvertURISubscriptionRejectsUnsupportedInput(t *testing.T) {
	_, err := handleConvertURISubscription("not a subscription")
	if err == nil {
		t.Fatal("unsupported input was accepted")
	}
}

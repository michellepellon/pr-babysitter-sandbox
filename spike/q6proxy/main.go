// ABOUTME: Task 0 spike Q6 (throwaway): a logging proxy between Claude Code and the Anthropic API.
// ABOUTME: Logs each request's method, path, betas, model, and tools, and swaps the agent's key for the WIF token.
package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"maps"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"slices"
	"strings"
)

var out = json.NewEncoder(os.Stdout)

func main() {
	token, err := os.ReadFile(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	bearer := "Bearer " + strings.TrimSpace(string(token))
	upstream, _ := url.Parse("https://api.anthropic.com")

	proxy := &httputil.ReverseProxy{
		Rewrite: func(r *httputil.ProxyRequest) {
			r.SetURL(upstream)
			r.Out.Header.Del("X-Api-Key")
			// Without this, Go's transport asks for gzip and decodes it, so error bodies log as text.
			r.Out.Header.Del("Accept-Encoding")
			r.Out.Header.Set("Authorization", bearer)
		},
		ModifyResponse: func(resp *http.Response) error {
			entry := map[string]any{"event": "response", "path": resp.Request.URL.Path, "status": resp.StatusCode}
			if resp.StatusCode >= 400 {
				body, err := io.ReadAll(resp.Body)
				if err != nil {
					return err
				}
				resp.Body = io.NopCloser(bytes.NewReader(body))
				entry["error"] = string(body)
			}
			out.Encode(entry)
			return nil
		},
	}

	log.Fatal(http.ListenAndServe("127.0.0.1:8199", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))

		var fields map[string]json.RawMessage
		var req struct {
			Model string `json:"model"`
			Tools []struct {
				Name string `json:"name"`
				Type string `json:"type"`
			} `json:"tools"`
		}
		json.Unmarshal(body, &fields)
		json.Unmarshal(body, &req)
		out.Encode(map[string]any{
			"event": "request", "method": r.Method, "path": r.URL.Path, "query": r.URL.RawQuery,
			"beta": r.Header.Get("Anthropic-Beta"), "user_agent": r.Header.Get("User-Agent"),
			"model": req.Model, "body_keys": slices.Sorted(maps.Keys(fields)), "tools": req.Tools,
		})
		proxy.ServeHTTP(w, r)
	})))
}

# Lab 12. WebAssembly Containers
## Task 1

Tools that was used: Spin 3.6.3, TinyGo 0.41.1, Go 1.26.9, Binaryen 131.

The component was created from the Spin `http-go` template. \
Component source: [main.go](../wasm/moscow-time/main.go) \
Component configuration: [spin.toml](../wasm/moscow-time/spin.toml). It uses Spin Go SDK v2.2.1. 

Spin routes `/time` to the component. \
Outbound hosts were disabled with ```allowed_outbound_hosts = []```

### Build

```text
thebruh@thebruh-PC MINGW64 ~/Desktop/DevOpsCourse/DevOps-Intro/wasm/moscow-time (feature/lab12)
$ spin build
Building component moscow-time with `tinygo build -target=wasip1 -gc=leaking -buildmode=c-shared -no-debug -o main.wasm .`
Finished building all Spin components
```

[main.wasm](../wasm/moscow-time/main.wasm) has size 313,784 bytes.

### HTTP response

```text
PS C:\Windows\system32> curl.exe -i http://127.0.0.1:3000/time
HTTP/1.1 200 OK
content-type: application/json
content-length: 103
date: Wed, 14 Oct 2026 18:48:39 GMT

{"unix":1792003719,"iso":"2026-10-14T21:48:39+03:00","hour_minute":"21:48","timezone":"Europe/Moscow"}
```


### Design questions

#### a) Browser WASM vs server WASM: go build -o m.wasm -target=js/wasm vs tinygo build -target=wasip1. What's missing in the server target, and what do you gain?
Server target misses the built-in ability to communicate with JavaScript and browser functions. But instead, it can launch without browser and do whatever the environment allowed it to do.

#### b) Why does the build command need -buildmode=c-shared? (Hint: what does the Spin host expect the module to export? Try removing it and see what spin up does.)
Without it, Spin would not be able to call the HTTP handler in main.wasm

#### c) allowed_outbound_hosts = [] is the strictest setting. Explain the capability-based security model and compare it to Docker's --network none.
`allowed_outbound_hosts = []` forbids the component to send a new requests to any servers. However, the component still can recieve the request and respond to it. In the same time, `docker --network none` completely disables external network for the whole container, in this mode, sending a request to the container would not be possible too.

#### d) TinyGo stdlib gaps: which part of upstream Go's stdlib does TinyGo not fully support that you hit during this lab? (Time-zone data and reflection-heavy encoding/json of map[string]any are common ones.)
I didn't encounter such problems during my lab implementation. However, on https://tinygo.org/docs/guides/compatibility/, i found that it doesn't support part of the `reflect` package. \
Direct citate from the website:
```
TinyGo does have limited support for the reflect package, but it is not complete. This is especially noticeable with serialization/deserialization packages such as encoding/json
```

## Task 2

### Test machine:
- AMD Ryzen 9 5950X
- Windows build 26200 (25H2)
- amd64

### Software:
- Docker Engine 29.8.0
- hyperfine 1.20.0 were used.

Warm latency was measured with `hyperfine --warmup 5 --runs 50`. Using `curl.exe`, for Spin - `/time` was called and for Docker - `/health` was called. 
Cold start was measured five times per each service. Time was calculated as time elapsed from the start command until the first successful HTTP response.

### Comparison table

| Dimension | Lab 6 Docker | Lab 12 WASM/Spin |
|---|---:|---:|
| Artifact size | 23,011,045 bytes | 313,784 bytes |
| Cold start p50 | 672.78 ms | 524.92 ms |
| Warm latency p50 | 8.711 ms | 8.426 ms |
| Warm latency p95 | 23.844 ms | 9.703 ms |

Raw results: [Docker cold starts](lab12-docker-cold.csv), [Spin cold starts](lab12-spin-cold.csv), [Docker warm requests](lab12-docker-warm.json), [Spin warm requests](lab12-spin-warm.json).

### Design questions
#### e) What dominates each platform's cold start? (Container: image extract + namespace init. Spin: wasmtime instantiation + WASM module load.)
Docker launches existing container, sets up the environment and starts the app inside. Spin starts the server and loads the wasm module using Wasmtime.

#### f) For what workloads is WASM clearly better, and where is Docker still right? (See Reading 12's trade-offs table.)
WASM is a good choice for small request handlers, huge amount of tiny isolated apps, because it has much smaller size than Docker containers. Docker is better for more complex apps that requre OS, heavy dependencies, heavy languages such as Python, Java, Node.js or high interactivity. These functions are almost impossible and very hard to setup on WASM.
 
#### g) Multi-tenant safety: WASM's capability sandbox is stronger than Linux namespaces. What concrete attack does a WASM platform make harder?
For example, hacker may try to escape isolation and do something malicious. On Linux, hacker can try to use vulneraiblity in Linux kernel to leave it's own container and possibly even gain full kernel control. In WASM, hacker won't even be able to call kernel functions in the first place, they can only communicate using runtime and given permissions, so it's much harder. Of course, runtime vulnerabilities are also a possibility, but the possibility is much lower.

## Bonus task. Two WASM execution models

The [WASM CLI main.go](../wasm-cli/main.go) uses the same Moscow-time logic but without the Spin SDK. It reads `REQUEST_METHOD` and `PATH_INFO` from the environment, reads stdin, prints JSON to stdout, and exits. It was run with Wasmtime 49.0.2.

### Build and run commands

Spin HTTP component [main.wasm](../wasm/moscow-time/main.wasm):

```bash
spin build
spin up
```

Standalone WASI CLI module (from the repository root):

```bash
thebruh@thebruh-PC MINGW64 ~/Desktop/DevOpsCourse/DevOps-Intro (feature/lab12)
$ tinygo build -target=wasi -no-debug -o wasm-cli/main.wasm wasm-cli/main.go

thebruh@thebruh-PC MINGW64 ~/Desktop/DevOpsCourse/DevOps-Intro (feature/lab12)
$ printf '' | MSYS_NO_PATHCONV=1 wasmtime run --env REQUEST_METHOD=GET --env PATH_INFO=/time wasm-cli/main.wasm
```
Standalone WASI CLI module output:
```json
{"unix":1792078974,"iso":"2026-10-15T18:42:54+03:00","hour_minute":"18:42","timezone":"Europe/Moscow"}
```

### Size and cold start comparison table

| Execution model | Module size | Cold start p50 |
|---|---:|---:|
| Spin HTTP component | 313,784 bytes | 524.92 ms |
| `wasmtime run` invocation | 198,079 bytes | 21.32 ms |

For the Spin HTTP component, data was taken from the previous table. For the WASI CLI, time was calculated as a time elapsed from `wasmtime run` invocation to recieving the result.
Raw tests: [Spin cold starts](lab12-spin-cold.csv) and [WASI CLI invocations](lab12-cli-cold.csv).

### Design questions

#### h) Why can't the Task 1 Spin component run under bare `wasmtime run`?
`wasmtime run` expects a program that will launch, call the main() and finish. Task 1, however, designed to be a HTTP-handler that needs to be called from Spin when `/time` request arrives.

#### i) What does Spin add on top of Wasmtime?
Spin organizes a web service around wasmtime, it listens to the HTTP requests, calls a modules handlers, sends the outputs back to the client and applies policy from the `spin.toml` 

#### j) When does each execution model fit?
`wasmtime run` fits when you need a one command that gets input, returns a result and stops. Spin fits when you need a HTTP service that handles many requests and communicates with clients.

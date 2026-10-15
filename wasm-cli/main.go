package main

import (
	"fmt"
	"io"
	"os"
	"time"
)

func main() {
	if os.Getenv("REQUEST_METHOD") != "GET" || os.Getenv("PATH_INFO") != "/time" {
		os.Exit(1)
	}

	_, _ = io.ReadAll(os.Stdin)
	moscow := time.Now().In(time.FixedZone("MSK", 3*60*60))

	fmt.Printf(
		"{\"unix\":%d,\"iso\":%q,\"hour_minute\":%q,\"timezone\":\"Europe/Moscow\"}\n",
		moscow.Unix(),
		moscow.Format(time.RFC3339),
		moscow.Format("15:04"),
	)
}
package main

import (
	"fmt"
	"github.com/dvsekhvalnov/jose2go"
	"io/ioutil"
	"os"
)

func main() {
	passphrase, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		fmt.Printf("%v", err)
		return
	}

	token, err := ioutil.ReadFile(os.Args[1])
	if err != nil {
		fmt.Printf("%v", err)
		return
	}

	payload, _, err := jose.Decode(string(token), string(passphrase))
	if err != nil {
		fmt.Printf("%v", err)
		return
	}

	fmt.Printf("%v", payload)
}

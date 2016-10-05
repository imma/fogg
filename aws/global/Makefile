fmt:
	runmany 'terraform fmt $$1' $(shell find . -name '*.tf')

remote:
	terraform remote config -backend=s3 -backend-config="bucket=imma-io-remote-state" -backend-config="key=$(shell basename $(shell pwd))/terraform.tfstate"

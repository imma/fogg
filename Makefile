fmt:
	@runmany 'terraform fmt $$1' $(shell find . -name '*.tf' -o -name '*.tfvars')

export:
	hcltool variables.tf | jq --arg tfmod $(shell basename $(PWD)) '{variable: (.variable | reduce keys[] as $$v ({}; .[$$v] = {})), output: (.output | reduce keys[] as $$o ({}; .[$$o] = {value: "$${module.\($$tfmod).\($$o)}"}))}' > export.json.1
	mv export.json.1 export.json

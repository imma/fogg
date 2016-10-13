all: fmt export

fmt:
	@runmany 'terraform fmt $$1' $(shell find . -name '*.tf' -o -name '*.tfvars')

export: export.json
	@true

export.json: variables.tf
	hcltool variables.tf | jq --arg tfmod $(shell basename $(PWD)) '{provider: (.provider//{}), variable: (.variable//{} as $$vars | reduce (.variable | keys[]) as $$v ({}; .[$$v] = $$vars[$$v])), output: (.output//{} | reduce keys[] as $$o ({}; .[$$o] = {value: "$${module.\($$tfmod).\($$o)}"}))}' > export.json.1
	mv export.json.1 export.json

.PHONY: bootstrap tf-init tf-plan tf-apply tf-destroy \
        build-% push-% deploy \
        seed init-catalog run-pipeline query \
        generate-data fmt validate

# --- One-time setup ---

bootstrap: ## Create the remote Terraform state bucket + lock table (run once)
	cd bootstrap && terraform init && terraform apply

# --- Terraform ---

tf-init: ## terraform init (run after `make bootstrap`, once backend.tf is filled in)
	cd terraform && terraform init

tf-plan:
	cd terraform && terraform plan

tf-apply:
	cd terraform && terraform apply

tf-destroy:
	cd terraform && terraform destroy

fmt:
	cd bootstrap && terraform fmt
	cd terraform && terraform fmt -recursive

validate:
	cd bootstrap && terraform validate
	cd terraform && terraform validate

# --- Lambda images ---

build-%: ## e.g. `make build-transform`
	./scripts/build_and_push_image.sh $*

deploy: ## Build+push all 4 Lambda images, then terraform apply (see docs/architecture.md build order)
	./scripts/deploy.sh

# --- Data / pipeline ---

generate-data: ## Regenerate data/seed/*.csv
	uv run data/generator/generate_mock_data.py

seed: ## Upload data/seed/*.csv to the raw bucket's source-drop/ prefix
	./scripts/upload_seed_to_raw.sh

init-catalog: ## One-time (idempotent) DuckLake catalog bootstrap
	./scripts/init_catalog.sh

run-pipeline: ## Manually trigger the Ingest->Transform Step Functions pipeline
	./scripts/run_pipeline.sh

query: ## make query SQL="SELECT * FROM mart_order_summary LIMIT 10"
	uv run scripts/query_cli.py "$(SQL)"

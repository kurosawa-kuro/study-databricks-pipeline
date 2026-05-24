.PHONY: help venv install \
	sql-test sql-catalog sql-values sql-query \
	volume-create volume-upload volume-clean \
	table-create table-copy table-verify \
	gcs-bucket-create gcs-upload secret-create job-deploy job-run clean

VENV_DIR := .venv
PYTHON := python3
VENV_PYTHON := $(VENV_DIR)/bin/python
PIP := $(VENV_DIR)/bin/pip

# ── Databricks (SQL Warehouse / Files API) ──
DATABRICKS_SERVER_HOSTNAME ?= dbc-8d3d115b-6eef.cloud.databricks.com
DATABRICKS_HTTP_PATH ?= /sql/1.0/warehouses/37b50097cbed6e52
DATABRICKS_TOKEN ?= $(DWH_DATABRICKS_TOKEN)
DATABRICKS_FILES_TOKEN ?= $(or $(DWH_DATABRICKS_FILES_TOKEN),$(DWH_DATABRICKS_TOKEN))

# ── GCP (GCS / Cloud Run Jobs / Artifact Registry / Secret Manager) ──
GCP_PROJECT ?= mlops-dev-a
GCP_REGION ?= asia-northeast1
GCS_BUCKET ?= mlops-dev-a-databricks-pipeline
AR_REPO ?= databricks-pipeline
JOB_NAME ?= csv-to-volume
SECRET_NAME ?= databricks-pat
IMAGE ?= $(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT)/$(AR_REPO)/$(JOB_NAME):latest
RUNTIME_SA ?=

help:
	@echo "Setup:"
	@echo "  make install         - create .venv and pip install -e ."
	@echo "Databricks SQL (prefix with 'doppler run --'):"
	@echo "  make sql-test        - SELECT 1 (connectivity)"
	@echo "  make sql-catalog     - current_catalog() -> workspace"
	@echo "  make sql-values      - create customers/orders from SQL VALUES"
	@echo "  make sql-query QUERY=\"SELECT 42\" - run arbitrary SQL"
	@echo "  make volume-create   - create managed volume workspace.default.raw_csv"
	@echo "  make table-create    - create target table workspace.default.customers"
	@echo "  make table-copy      - COPY INTO from volume CSV (idempotent)"
	@echo "  make table-verify    - verify row count / sample"
	@echo "  make volume-clean    - drop table and volume"
	@echo "  make volume-upload LOCAL_FILE=./data/customers.csv VOLUME_PATH=/Volumes/workspace/default/raw_csv/customers.csv"
	@echo "                       - upload local file straight to volume (Phase 1, GCS/Cloud Run なしで検証)"
	@echo "GCP pipeline (gcloud auth required):"
	@echo "  make gcs-bucket-create - create GCS bucket (once)"
	@echo "  make gcs-upload CSV=./data/customers.csv - local CSV -> GCS incoming/"
	@echo "  make secret-create   - store DWH_DATABRICKS_TOKEN into Secret Manager (run via doppler)"
	@echo "  make job-deploy      - build/push image + deploy Cloud Run Job"
	@echo "  make job-run OBJECT=incoming/customers.csv - run job: GCS -> volume"
	@echo "  make clean           - drop table/volume + delete job/secret"

venv:
	$(PYTHON) -m venv $(VENV_DIR)

install: venv
	$(PIP) install -e .

# ─────────────────────────── Databricks SQL ───────────────────────────

sql-test:
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh

sql-catalog:
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh --mode catalog

sql-values:
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh --mode values

sql-query:
	@test -n "$(QUERY)" || (echo 'Usage: make sql-query QUERY="SELECT 42 AS answer"' && exit 2)
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh --query "$(QUERY)"

volume-create:
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh --sql-file ./databricks/sql/volume/01_create_managed_volume.sql

volume-upload:
	@test -n "$(LOCAL_FILE)" || (echo 'Usage: make volume-upload LOCAL_FILE=./data/customers.csv VOLUME_PATH=/Volumes/workspace/default/raw_csv/customers.csv' && exit 2)
	@test -n "$(VOLUME_PATH)" || (echo 'Usage: make volume-upload LOCAL_FILE=./data/customers.csv VOLUME_PATH=/Volumes/workspace/default/raw_csv/customers.csv' && exit 2)
	@test -n "$(DATABRICKS_FILES_TOKEN)" || (echo 'Missing DWH_DATABRICKS_TOKEN, DWH_DATABRICKS_FILES_TOKEN, DATABRICKS_TOKEN, or DATABRICKS_FILES_TOKEN' && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_FILES_TOKEN="$(DATABRICKS_FILES_TOKEN)" \
	./scripts/databricks_volume_upload.sh "$(LOCAL_FILE)" "$(VOLUME_PATH)"

table-create:
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh --sql-file ./databricks/sql/table/01_create_target_table.sql

table-copy:
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh --sql-file ./databricks/sql/table/02_copy_into_from_volume.sql

table-verify:
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh --sql-file ./databricks/sql/table/03_verify_table.sql

volume-clean:
	@test -x "$(VENV_PYTHON)" || (echo "Missing $(VENV_PYTHON). Run 'make install' first." && exit 2)
	@test -n "$(DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN or DATABRICKS_TOKEN" && exit 2)
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" \
	DATABRICKS_HTTP_PATH="$(DATABRICKS_HTTP_PATH)" \
	DATABRICKS_TOKEN="$(DATABRICKS_TOKEN)" \
	./scripts/databricks_sql_test.sh --sql-file ./databricks/sql/volume/02_drop_volume_artifacts.sql

# ─────────────────────────── GCP pipeline ───────────────────────────

gcs-bucket-create:
	gcloud storage buckets describe "gs://$(GCS_BUCKET)" --project="$(GCP_PROJECT)" >/dev/null 2>&1 \
	  || gcloud storage buckets create "gs://$(GCS_BUCKET)" --project="$(GCP_PROJECT)" --location="$(GCP_REGION)"

gcs-upload:
	@test -n "$(CSV)" || (echo 'Usage: make gcs-upload CSV=./data/customers.csv' && exit 2)
	GCS_BUCKET="$(GCS_BUCKET)" ./scripts/gcs_upload.sh "$(CSV)"

secret-create:
	@test -n "$(DWH_DATABRICKS_TOKEN)" || (echo "Missing DWH_DATABRICKS_TOKEN (run via 'doppler run -- make secret-create')" && exit 2)
	gcloud secrets describe "$(SECRET_NAME)" --project="$(GCP_PROJECT)" >/dev/null 2>&1 \
	  || gcloud secrets create "$(SECRET_NAME)" --replication-policy=automatic --project="$(GCP_PROJECT)"
	printf '%s' "$(DWH_DATABRICKS_TOKEN)" | gcloud secrets versions add "$(SECRET_NAME)" --data-file=- --project="$(GCP_PROJECT)"

job-deploy:
	GCP_PROJECT="$(GCP_PROJECT)" GCP_REGION="$(GCP_REGION)" AR_REPO="$(AR_REPO)" \
	JOB_NAME="$(JOB_NAME)" IMAGE="$(IMAGE)" SECRET_NAME="$(SECRET_NAME)" \
	DATABRICKS_SERVER_HOSTNAME="$(DATABRICKS_SERVER_HOSTNAME)" RUNTIME_SA="$(RUNTIME_SA)" \
	./scripts/deploy_cloudrun_job.sh

job-run:
	@test -n "$(OBJECT)" || (echo 'Usage: make job-run OBJECT=incoming/customers.csv' && exit 2)
	GCP_PROJECT="$(GCP_PROJECT)" GCP_REGION="$(GCP_REGION)" JOB_NAME="$(JOB_NAME)" \
	GCS_BUCKET="$(GCS_BUCKET)" \
	./scripts/run_cloudrun_job.sh "$(OBJECT)"

clean: volume-clean
	-gcloud run jobs delete "$(JOB_NAME)" --region="$(GCP_REGION)" --project="$(GCP_PROJECT)" --quiet
	-gcloud secrets delete "$(SECRET_NAME)" --project="$(GCP_PROJECT)" --quiet

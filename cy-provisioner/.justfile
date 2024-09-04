uid := `id -u`
workdir := justfile_directory()

set dotenv-load := true

default:
  @just --list

validate:
  shellcheck cy-provisioner
  shfmt -w cy-provisioner

build: validate
	docker build . -t "cycloid/cy-provisioner:latest"

test: validate
  docker compose run -it cy-provisioner

test-init:
  #!/usr/bin/env bash
  set -euxo pipefail

  export ENV="fbh-tests-init"
  export PROJECT="cycloid-playground"
  export CY_TARGET_API_URL="https://api-${ENV}.staging.cycloid.io"
  export CY_SOURCE_API_KEY=$(op read "op://Cycloid/cycloid_admin_api_key/password")
  export ENABLE_PROVISIONING=true

  ./cy-initializer.py

test-help:
  ./cy-initializer.py

exec +command:
  docker compose run -it cy-provisioner -- {{command}}

watch +command:
	watchexec -w . -rc -- just {{command}}

uid := `id -u`
workdir := justfile_directory()

set dotenv-load := true
set export

CY_SOURCE_API_KEY := `op read "op://Cycloid/cycloid_admin_api_key/password"`

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
  export ENABLE_PROVISIONING=true

  ./cy-initializer.py

test-delete:
  #!/usr/bin/env bash
  set -euxo pipefail

  export ENV="fbh-tests-init"
  export PROJECT="cycloid-playground"
  export CY_TARGET_API_URL="https://api-${ENV}.staging.cycloid.io"
  export CY_SOURCE_API_KEY=$(op read "op://Cycloid/cycloid_admin_api_key/password")

  ./cy-initializer.py --delete

test-provision:
  #!/usr/bin/env bash
  set -euxo pipefail

  export CY_SOURCE_API_KEY=$(op read "op://Cycloid/cycloid_admin_api_key/password")
  export CY_TARGET_API_KEY="eyJhbGciOiJIUzI1NiIsImtpZCI6ImYwMjA4ODg0LTFiNTktN2E3ZC1hMWJkLTQ4ZDk4MmY0NWY0YSIsInR5cCI6IkpXVCJ9.eyJjeWNsb2lkIjp7InVzZXIiOnsiaWQiOjAsInVzZXJuYW1lIjoiYWRtaW4tdG9rZW4iLCJnaXZlbl9uYW1lIjoiIiwiZmFtaWx5X25hbWUiOiIiLCJwaWN0dXJlX3VybCI6IiIsImxvY2FsZSI6IiJ9LCJhcGlfa2V5IjoiYWRtaW4tdG9rZW4iLCJvcmdhbml6YXRpb24iOnsiaWQiOjEsImNhbm9uaWNhbCI6ImN5Y2xvaWQiLCJuYW1lIjoiY3ljbG9pZCIsImJsb2NrZWQiOltdLCJoYXNfY2hpbGRyZW4iOmZhbHNlLCJzdWJzY3JpcHRpb24iOnsiZXhwaXJlc19hdCI6LTYyMTM1NTk2ODAwLCJwbGFuIjp7Im5hbWUiOiJJbnZhbGlkIiwiY2Fub25pY2FsIjoiaW52YWxpZCJ9fSwiYXBwZWFyYW5jZSI6eyJuYW1lIjoiIiwiY2Fub25pY2FsIjoiIiwiZGlzcGxheV9uYW1lIjoiIiwibG9nbyI6IiIsImZhdmljb24iOiIiLCJmb290ZXIiOiIiLCJpc19hY3RpdmUiOmZhbHNlLCJjb2xvciI6eyJiIjowLCJnIjowLCJyIjowfX19LCJoYXNoIjoiODQxMjEwZjBjNmMyOTM4NTY1YjM0MGI2M2M0ZTQwNzVjNmY4Y2RlNSJ9LCJzY29wZSI6ImFwaS1rZXkiLCJhdWQiOiJjdXN0b21lciIsImp0aSI6IjBiODAyZjQ5LTY4MjgtNGE0MS1hMjAzLWQ3OTkwODE0N2ZhZiIsImlhdCI6MTcyNjE0MzgwMSwiaXNzIjoiaHR0cHM6Ly9jeWNsb2lkLmlvIiwibmJmIjoxNzI2MTQzODAxLCJzdWIiOiJodHRwczovL2N5Y2xvaWQuaW8ifQ.-y8g4UXis3lPK7LHWasm7KMjrZJS1KcQn1wWCF0WQSo"
  export CY_TARGET_API_URL="https://34.251.60.165/api"

  ./cy-provisioner provision


test-help:
  ./cy-initializer.py

exec +command:
  docker compose run -it cy-provisioner -- {{command}}

watch +command:
	watchexec -w . -rc -- just {{command}}

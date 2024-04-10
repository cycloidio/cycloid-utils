uid := `id -u`
workdir := justfile_directory()
export ENV := `whoami`

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

exec +command:
  docker compose run -it cy-provisioner -- {{command}}

watch +command:
	watchexec -N -w src --stop-timeout=3 -prc -- {{command}}

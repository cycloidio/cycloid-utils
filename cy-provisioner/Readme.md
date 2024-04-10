# Cycloid provisioner script

This script is meant to easily provision some fixture for dev environment on a target cycloid instance.

## Installation

Just curl the raw script and make it executable:

```console
$ curl -LO https://raw.githubusercontent.com/cycloidio/cycloid-utils/master/cy-provisioner/cy-provisioner
$ chmod +x cy-provisioner
```

## Requirements and usage:

See the script help directly:

```console
$ ./cy-provisioner --help
```

## Contribute

Requires:
- docker with compose plugin
- [just](https://just.systems)

To develop on the script, create yourself a cycloid env using our [cycloid playground](https://console.cycloid.io/organizations/cycloid/projects/cycloid-playground).

Add the required env var in the [.env](./.env) file.

You can use the justfile with [just](https://just.systems/) for using the repo dev command.

You can lookup projects command with this:
```console
just --list
```

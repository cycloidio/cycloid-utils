#! /usr/bin/env bash

set -eux -o pipefail

#   curl 'https://http-api.cycloid.io/organizations/cycloid-sandbox/service_catalogs/cycloid-io:blank-sample/template' --compressed -X POST -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:123.0) Gecko/20100101 Firefox/123.0' -H 'Accept: */*' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Referer: https://console.cycloid.io/' -H 'authorization: Bearer eyJhbGciOiJIUzI1NiIsImtpZCI6IjJmMjEyMmRlLTYzZjItNGVlYy05YzZmLWM2YWJiM2UxZjAwNyIsInR5cCI6IkpXVCJ9.eyJjeWNsb2lkIjp7InVzZXIiOnsiaWQiOjE2OTcsInVzZXJuYW1lIjoiZmhhbXBlbCIsImdpdmVuX25hbWUiOiJGcsOpZMOpcmljIiwiZmFtaWx5X25hbWUiOiJCQVJSQVMgSEFNUEVMIiwicGljdHVyZV91cmwiOiIiLCJsb2NhbGUiOiJlbiJ9LCJvcmdhbml6YXRpb24iOnsiaWQiOjQ2LCJjYW5vbmljYWwiOiJjeWNsb2lkLXNhbmRib3giLCJuYW1lIjoiQ3ljbG9pZC1zYW5kYm94IiwiYmxvY2tlZCI6W10sImhhc19jaGlsZHJlbiI6dHJ1ZSwic3Vic2NyaXB0aW9uIjp7ImV4cGlyZXNfYXQiOi02MjEzNTU5NjgwMCwicGxhbiI6eyJuYW1lIjoiSW52YWxpZCIsImNhbm9uaWNhbCI6ImludmFsaWQifX0sImFwcGVhcmFuY2UiOnsibmFtZSI6ImN1c3RvbSIsImNhbm9uaWNhbCI6ImN1c3RvbSIsImRpc3BsYXlfbmFtZSI6IkRhcmsgbWFnaWMiLCJsb2dvIjoiaHR0cHM6Ly9jZG4uc2hvcGlmeS5jb20vcy9maWxlcy8xLzAwMzMvOTMwNi8wOTI4L2ZpbGVzL2RhcmstbWFnaWMtbGFycC1jaGFyYWN0ZXIucG5nP3Y9MTYxMTI2MDM2MiIsImZhdmljb24iOiJodHRwczovL2NvbnNvbGUuY3ljbG9pZC5pby9zdGF0aWMvZmF2aWNvbnMvcHJvZC9mYXZpY29uLmljbyIsImZvb3RlciI6IiIsImlzX2FjdGl2ZSI6dHJ1ZSwiY29sb3IiOnsiYiI6MTMxLCJnIjoyLCJyIjo5NH19fSwicm9sZSI6Ik9yZ2FuaXphdGlvbiBBZG1pbiIsImhhc2giOiJjMmI4ODIyMjg0ZDQzNjdlY2ZhZWNhYWNlNzQ2Y2E3ZmJkMDgwYTBjIn0sInNjb3BlIjoidXNlciIsImF1ZCI6ImN1c3RvbWVyIiwiZXhwIjoxNzEyMDY2MzgyLCJqdGkiOiIyNmQ5MjRmOC1iY2E1LTQzY2ItOGM3OS1jNGE4YWZmNWU3OGMiLCJpYXQiOjE3MTE0NjE1ODIsImlzcyI6Imh0dHBzOi8vY3ljbG9pZC5pbyIsIm5iZiI6MTcxMTQ2MTU4Miwic3ViIjoiaHR0cHM6Ly9jeWNsb2lkLmlvIn0.QNm18Kf_uNON5MnpPsdMLEnx2CoMvRQ1QT2RVUdmUfM' -H 'content-type: application/vnd.cycloid.io.v1+json' -H 'Origin: https://console.cycloid.io' -H 'Connection: keep-alive' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-site' -H 'Sec-GPC: 1' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' -H 'TE: trailers' --data-raw $'{"author":"Fr\xe9d\xe9ric BARRAS HAMPEL","use_case":"default","created_at":1711461606353,"updated_at":1711461606353,"service_catalog_source_canonical":"step-by-step-fbh","canonical":"test-fbh","name":"test-fbh"}'
TMPDIR="${XDG_RUNTIME_DIR:-/tmp}/cycloid-playground"
GIT_DIR="$TMPDIR/catalog-repo-template"
ENV="wip-provisioning-fbh"

rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"

git clone --bare git@github.com:cycloidio/catalog-repo-template.git "$GIT_DIR"
cd "$GIT_DIR" || exit_failed 1 "Failed to cd into $GIT_DIR"

STACKS_BRANCH="${ENV}-stacks"
CONFIG_BRANCH="${ENV}-config"
git_put_branch stacks "${STACKS_BRANCH}" "branches/${ENV}-stacks"
git_put_branch config "${CONFIG_BRANCH}" "branches/${ENV}-config"

cy_cmd login --api-key $API_KEY
cy_cmd credential create ssh --name cycloid-stacks-ro --ssh-key <(echo "$CYCLOID_STACKS_SSH_KEY") || true

cycloid_stacks_canonical="cycloid-stacks-ro"
cy_cmd catalog-repository create \
  --branch stacks --cred "cycloid-stacks-ro" \
  --url "git@github.com:cycloidio/cycloid-stacks.git" --name "$cycloid_stacks_canonical" || true
cy_cmd catalog-repository refresh --canonical "$cycloid_stacks_canonical"

boostrap_canonical="cycloid-bootstrap-stacks"
cy_cmd catalog-repository create \
  --branch master --cred "github" \
  --url "git@github.com:cycloidio/bootstrap-stacks.git" --name "$boostrap_canonical"
cy_cmd catalog-repository refresh --canonical "$boostrap_canonical"

cycloid_stack_test_cred="cycloid-stacks-test"
cy_cmd credential create ssh --name "$cycloid_stack_test_cred" --ssh-key <(echo "$CYCLOID_STACK_TEST_SSH_KEY") || true
{
  set +e
  cy_cmd catalog-repository create \
    --branch "stacks" --cred "$cycloid_stack_test_cred" \
    --url "git@github.com:cycloidio/cycloid-stacks-test.git" --name "Cycloid stack test" \
  && cy_cmd catalog-repository refresh --canonical "cycloid-stack-test"
} || {
  # If this failed, this could be because the catalog has invalid stacks
  warn "Cycloid stacks test had an error while refreshing"
  warn "This could be due to invalid stack in the repository"
  warn "You will have to check it manually"
}

cy_cmd config-repository create \
  --branch "config" --cred "$cycloid_stack_test_cred" \
  --url "git@github.com:cycloidio/cycloid-stacks-test.git" \
  --name "stacks-test-config"

# Add the ssh key for the template catalog
cy_cmd credential create ssh \
  --name cycloid-template-catalog \
  --ssh-key <(echo "$CYCLOID_TEMPLATE_CATALOG_SSH_KEY") || true
cy_cmd catalog-repository create \
  --branch "${STACKS_BRANCH}" --cred "cycloid-template-catalog" \
  --url "git@github.com:cycloidio/catalog-repo-template.git" \
  --name "cycloid-template-catalog"
cy_cmd catalog-repository refresh --canonical "cycloid-template-catalog"

cy_cmd config-repository create \
  --branch "${CONFIG_BRANCH}" --cred "cycloid-template-catalog" \
  --url "git@github.com:cycloidio/catalog-repo-template.git" \
  --name "cycloid-template-catalog-config" \
  --default

ADMIN_USERNAME="admin cycloid"
cy_template "cycloid:blank-sample" "Dummy stack templated" "dummy-stack-templated" \
  "$ADMIN_USERNAME" "cycloid-template-catalog" "default"

cy_template "cycloid:terraform-sample" "Terraform aws stack templated" "terraform-aws-stack-templated" \
  "$ADMIN_USERNAME" "cycloid-template-catalog" "aws"

cy_template "cycloid:terraform-sample" "Terraform azure stack templated" "terraform-azure-stack-templated" \
  "$ADMIN_USERNAME" "cycloid-template-catalog" "azure"

cy_template "cycloid:terraform-sample" "Terraform gcp stack templated" "terraform-gcp-stack-templated" \
  "$ADMIN_USERNAME" "cycloid-template-catalog" "gcp"

cy_template "cycloid:terraform-sample" "Terraform basic stack templated" "terraform-basic-stack-templated" \
  "$ADMIN_USERNAME" "cycloid-template-catalog" "vanilla"


# curl 'https://54.220.250.246/api/organizations/cycloid/projects' \
#   -X POST \
#   -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:123.0) Gecko/20100101 Firefox/123.0' \
#   -H 'Accept: */*' \
#   -H 'Accept-Language: en-US,en;q=0.5' \
#   -H 'Accept-Encoding: gzip, deflate, br' \
#   -H 'Referer: https://54.220.250.246/organizations/cycloid/projects/toto/service/client' \
#   -H 'authorization: Bearer eyJhbGciOiJIUzI1NiIsImtpZCI6IjJmMjEyMmRlLTYzZjItNGVlYy05YzZmLWM2YWJiM2UxZjAwNyIsInR5cCI6IkpXVCJ9.eyJjeWNsb2lkIjp7InVzZXIiOnsiaWQiOjEsInVzZXJuYW1lIjoiYWRtaW4iLCJnaXZlbl9uYW1lIjoiYWRtaW4iLCJmYW1pbHlfbmFtZSI6ImN5Y2xvaWQiLCJwaWN0dXJlX3VybCI6IiIsImxvY2FsZSI6ImVuIn0sIm9yZ2FuaXphdGlvbiI6eyJpZCI6MSwiY2Fub25pY2FsIjoiY3ljbG9pZCIsIm5hbWUiOiJDeWNsb2lkIiwiYmxvY2tlZCI6W10sImhhc19jaGlsZHJlbiI6ZmFsc2UsInN1YnNjcmlwdGlvbiI6eyJleHBpcmVzX2F0IjotNjIxMzU1OTY4MDAsInBsYW4iOnsibmFtZSI6IkludmFsaWQiLCJjYW5vbmljYWwiOiJpbnZhbGlkIn19LCJhcHBlYXJhbmNlIjp7Im5hbWUiOiJEZWZhdWx0IiwiY2Fub25pY2FsIjoiZGVmYXVsdCIsImRpc3BsYXlfbmFtZSI6IkN5Y2xvaWQiLCJsb2dvIjoiaHR0cHM6Ly9jb25zb2xlLmN5Y2xvaWQuaW8vc3RhdGljL2ltYWdlcy9hcHAtbG9nby1zcXVhcmUucG5nIiwiZmF2aWNvbiI6Imh0dHBzOi8vY29uc29sZS5jeWNsb2lkLmlvL3N0YXRpYy9mYXZpY29ucy9mYXZpY29uLmljbyIsImZvb3RlciI6IiIsImlzX2FjdGl2ZSI6dHJ1ZSwiY29sb3IiOnsiYiI6MTUxLCJnIjoxNTEsInIiOjI4fX19LCJyb2xlIjoiT3JnYW5pemF0aW9uIEFkbWluIiwiaGFzaCI6IjFhN2Y1MTgyZmYxYTJhNjRmZDg1MGExNGYxMWYwNTA3OWNmNWRlMjYifSwic2NvcGUiOiJ1c2VyIiwiYXVkIjoiY3VzdG9tZXIiLCJleHAiOjE3MTI3MzUxMTUsImp0aSI6IjllN2RjM2E1LWNiYjgtNDVhMy04ZGM2LWJjMDU0MmJmOGEzYSIsImlhdCI6MTcxMjEzMDMxNSwiaXNzIjoiaHR0cHM6Ly9jeWNsb2lkLmlvIiwibmJmIjoxNzEyMTMwMzE1LCJzdWIiOiJodHRwczovL2N5Y2xvaWQuaW8ifQ.G-wiouo_I8-a_YzM15vGSIdtvUONOqBQNu_HqegcLds' -H 'content-type: application/vnd.cycloid.io.v1+json' -H 'Origin: https://54.220.250.246' -H 'Connection: keep-alive' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'Sec-GPC: 1' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' \
#   --data-raw '{"config_repository_canonical":"cycloid-template-catalog-config","description":"","name":"toto","owner":"admin","canonical":"toto","favorite":false,"service_catalog_ref":"cycloid:terraform-gcp-stack-templated","pipelines":[{"pipeline_name":"toto-test","use_case":"gcp","environment":{"canonical":"test","cloud_provider_canonical":"google"}}],"inputs":[{"use_case":"gcp","environment_canonical":"test","vars":{"Cloud provider":{"access":{"gcp_project":"cycloid-demo","gcp_zone":"europe-west1-b","gcp_credentials_json":"((gcp_admin_gcp_cycloid-sandbox.json_key))"}},"App":{"config":{"module.myapp.instance_type":"medium"}},"Git":{"config":{"config_git_private_key":"((ssh_cycloid-template-catalog.ssh_key))"},"stack":{"stack_git_private_key":"((ssh_cycloid-template-catalog.ssh_key))"}}}}]}'

timestamp=$(date +%s)

# GCP
use_case="gcp"
env="test"
pname="gcp-from-templated-${timestamp}"
CY_PROJECT_NAME="${pname}" \
CY_PROJECT_DESCRIPTION="Test project" \
CY_PROJECT_CONFIG_REPOSITORY_CANONICAL="cycloid-template-catalog-config" \
CY_PROJECT_PIPELINE="$(cat <<EOF
[
  {
    "pipeline_name": "${pname}-${env}",
    "use_case": "${use_case}",
    "environment":
    {
      "canonical": "${env}",
      "cloud_provider_canonical": "google"
    }
  }
]
EOF
)" \
CY_PROJECT_INPUTS="$(cat <<EOF
[
  {
    "use_case": "${use_case}",
    "environment_canonical": "${env}",
    "vars":
    {
      "Cloud provider":
      {
        "access":
        {
          "gcp_project": "cycloid-demo",
          "gcp_zone": "europe-west1-b",
          "gcp_credentials_json": "((gcp_admin_gcp_cycloid-sandbox.json_key))"
        }
      },
      "App":
      {
        "config":
        {
          "module.myapp.instance_type": "medium"
        }
      },
      "Git":
      {
        "config":
        {
          "config_git_private_key": "((ssh_cycloid-template-catalog.ssh_key))"
        },
        "stack":
        {
          "stack_git_private_key": "((ssh_cycloid-template-catalog.ssh_key))"
        }
      }
    }
  }
]
EOF
)" \
CY_PROJECT_OWNER="admin" \
CY_PROJECT_SERVICE_CATALOG_REF="cycloid:terraform-gcp-stack-templated" \
CY_PROJECT_ORG="${ORG}" \
cy_create_project

# AZURE
use_case="azure"
env="test"
pname="azure-from-templated-${timestamp}"
CY_PROJECT_NAME="${pname}" \
CY_PROJECT_DESCRIPTION="Project created from azure bootsrapped stack" \
CY_PROJECT_CONFIG_REPOSITORY_CANONICAL="cycloid-template-catalog-config" \
CY_PROJECT_PIPELINE="$(cat <<EOF
[
  {
    "pipeline_name": "${pname}-${env}",
    "use_case": "${use_case}",
    "environment":
    {
      "canonical": "${env}",
      "cloud_provider_canonical": "azurerm"
    }
  }
]
EOF
)" \
CY_PROJECT_INPUTS="$(cat <<EOF
[
  {
    "use_case": "${use_case}",
    "environment_canonical": "${env}",
    "vars": {
      "Cloud provider": {
        "access": {
          "azure_cred": "((azure_admin_azure))",
          "azure_env": "public"
        }
      },
      "App": {
        "config": {
          "module.myapp.instance_type": "medium"
        }
      },
      "Git": {
        "config": {
          "config_git_private_key": "((ssh_cycloid-template-catalog.ssh_key))"
        },
        "stack": {
          "stack_git_private_key": "((ssh_cycloid-template-catalog.ssh_key))"
        }
      }
    }
  }
]
EOF
)" \
CY_PROJECT_OWNER="admin" \
CY_PROJECT_SERVICE_CATALOG_REF="cycloid:terraform-azure-stack-templated" \
CY_PROJECT_ORG="${ORG}" \
cy_create_project

# AWS
use_case="aws"
env="test"
pname="aws-from-templated-${timestamp}"
CY_PROJECT_NAME="${pname}" \
CY_PROJECT_DESCRIPTION="Project created from aws bootsrapped stack" \
CY_PROJECT_CONFIG_REPOSITORY_CANONICAL="cycloid-template-catalog-config" \
CY_PROJECT_PIPELINE="$(cat <<EOF
[
  {
    "pipeline_name": "${pname}-${env}",
    "use_case": "${use_case}",
    "environment": {
      "canonical": "${env}",
      "cloud_provider_canonical": "aws"
    }
  }
]
EOF
)" \
CY_PROJECT_INPUTS="$(cat <<EOF
[
  {
    "use_case": "${use_case}",
    "environment_canonical": "${env}",
    "vars": {
      "Cloud provider": {
        "access": {
          "aws_cred": "((aws_admin_aws))",
          "aws_default_region": "eu-west-1"
        }
      },
      "App": {
        "config": {
          "module.myapp.instance_type": "nano"
        }
      },
      "Git": {
        "config": {
          "config_git_private_key": "((ssh_cycloid-template-catalog.ssh_key))"
        },
        "stack": {
          "stack_git_private_key": "((ssh_cycloid-template-catalog.ssh_key))"
        }
      }
    }
  }
]
EOF
)" \
CY_PROJECT_OWNER="admin" \
CY_PROJECT_SERVICE_CATALOG_REF="cycloid:terraform-aws-stack-templated" \
CY_PROJECT_ORG="${ORG}" \
cy_create_project


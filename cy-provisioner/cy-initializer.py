#! /usr/bin/env python3

import argparse
import json
import os
import secrets
import string
import sys
import textwrap

import requests
import urllib3

urllib3.disable_warnings()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog='cy-initializer', 
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent('''\
        Cycloid internal environment provisioner.
        It will use and existing "source" console to initialize a "target" console.

        Will generate admin username, password, api_key and root org.

        Configuration is set using env vars:

        ENV (default: local): specify the env - used for the generated cred name
        PROJECT (default: cy-initializer): specify the project - used for the generated cred name
        CY_SOURCE_API_KEY: specify the api key for cycloid source console
        CY_SOURCE_API_URL (default: https://http-api.cycloid.io): specify the url for the source console
        CY_TARGET_API_URL: specify the "target" console url
        EMAIL (default: "admin+${project}-${env}@cycloid.io"): specify the admin email
        ENABLE_PROVISIONING (default: false): enable provisioning using cy-provisioner.
        PROVISIONER_SCRIPT_URL (default: https://raw.githubusercontent.com/cycloidio/cycloid-utils/master/cy-provisioner/cy-provisioner): specify the provisioner script url to curl | bash
        CY_LICENCE_CREDENTIAL (default: determined by the api version): specify the licence credential to use.
        ''')
    )
    parser.parse_args()

class Settings():
    def __init__(self):
        self.project: str = os.environ.get("PROJECT", "cy-initializer").lower()
        self.env: str = os.environ.get("ENV", "local").lower()
        self.credential_name: str = f"{self.project}-{self.env}" 
        self.host_api_url: str = os.environ.get("CY_SOURCE_API_URL", "https://http-api.cycloid.io")
        self.admin_email: str = os.environ.get("EMAIL", f"admin+{self.project}-{self.env}@cycloid.io")
        self.licence_credential: str = os.environ.get("CY_LICENCE_CREDENTIAL", "")
        if self.licence_credential == "":
            self.infer_credential_per_api_version()
        self.provisioning_enabled: bool = os.environ.get("ENABLE_PROVISIONING", "false").lower() == "true"

        try:
            self.target_api_url: str = os.environ["CY_TARGET_API_URL"]
            self.source_api_token: str = os.environ["CY_SOURCE_API_KEY"]
        except KeyError as e:
            raise Exception(f"missing env var for metadata handling: {e}")


    def infer_credential_per_api_version(self):
        response = requests.get(self.target_api_url + "/version")
        if response.status_code != 200:
            raise Exception(
                f"failed to check api version to determine wich licence to use, check backend or override CY_LICENCE_CREDENTIAL: {response.url} {response.status_code}: {response.text}"
            )
        
        try:
            if response.json()["data"]["branch"] == "master":
                self.licence_credential = "scaleway-cycloid-backend-prod"
            else:
                self.licence_credential = "scaleway-cycloid-backend"
        except Exception as e:
            raise Exception(
                f"failed to decode /version payload from api, reponse:\n{response.text}\n{e}"
            )

def log(*args, **kwargs):
    print("\033[0;32minfo:\033[0m", *args, **kwargs, file=sys.stderr)


def error(*args, **kwargs):
    print("\033[0;31merror:\033[0m", *args, **kwargs, file=sys.stderr)

class Credential:
    def __init__(self, settings):
        try:
            self.env: str = settings.env
            self.project: str = settings.project
            self.credential_name: str = settings.credential_name
            self.token: str = settings.source_api_token
            self.base_url: str = settings.host_api_url
            self.data: dict = {}
            self.session = requests.Session()
            self.session.headers.update(
                {
                    "Content-Type": "application/vnd.cycloid.io.v1+json",
                    "Authorization": f"Bearer {self.token}",
                }
            )
            self.session.verify = False
        except KeyError as e:
            raise Exception(f"missing env var for metadata handling: {e}")

    def credential_exists(self) -> bool:
        response = self.session.get(
            self.base_url + f"/organizations/cycloid/credentials/{self.credential_name}"
        )

        match response.status_code:
            case 404:
                return False
            case 200:
                return True
            case _:
                raise Exception(
                    f"failed to get credentials from api: {response.url} {response.status_code}: {response.text}"
                )

    def read(self):
        self.data = {}

        if self.credential_exists():
            response = self.session.get(
                self.base_url
                + f"/organizations/cycloid/credentials/{self.credential_name}"
            )

            try:
                self.data = response.json()["data"]["raw"]["raw"]
            except Exception as e:
                raise Exception(
                    f"failed to read credential from api: {response.url} {response.status_code}: {response.text}\n{e}"
                )

    def write(self):
        url = self.base_url + "/organizations/cycloid/credentials"
        body = {
            "name": f"initializer-{self.credential_name}",
            "canonical": self.credential_name,
            "type": "custom",
            "path": self.credential_name,
            "description": f"""
                Generated by the Cycloid playground env {self.credential_name}.
                Contains access to the console and API Token.
            """,
            "raw": {
                "raw": self.data,
            },
        }
        if self.credential_exists():
            url = url + "/" + self.credential_name
            response = self.session.put(url, json=body)
        else:
            response = self.session.post(url, json=body)
        match response.status_code:
            case 201 | 200:
                log("uploaded metadata to credential:", self.credential_name)
            case 403:
                raise Exception(
                    f"unauthorized when writing metadata, check CY_SOURCE_API_KEY: {response.url} {response.status_code}: {response.text}"
                )
            case _:
                raise Exception(
                    f"failed to write metadata: {response.url} {response.status_code}: {response.text}"
                )


class CycloidProvisionner:
    def __init__(self, settings):
        try:
            self.target_url: str = settings.target_api_url
            self.source_url: str = settings.host_api_url
            self.env: str = settings.env
            self.project: str = settings.project
            self.email: str = settings.admin_email
            self.licence: str = settings.licence_credential
            self.session = requests.Session()
            self.credential: Credential = Credential(settings)
            self.credential.read()
            self.source_token = settings.source_api_token

            if self.credential.data.get("password") is None:
                self.set_password()
            else:
                log("using password from credential")

            self.token = ""

            headers = {
                "Content-Type": "application/vnd.cycloid.io.v1+json",
            }

            self.session.headers.update(headers)
            self.session.verify = False

            log("initialized provisioner with params:")
            log(json.dumps(settings.__dict__, indent=2))

        except KeyError as e:
            raise KeyError(
                "You must set CY_LICENCE, CY_TARGET_API_URL, CY_ENV, CY_EMAIL and CY_PASSWORD environment variables",
                e,
            )

    def set_password(self):
        self.credential.data["password"] = "".join(
            secrets.choice(string.digits + string.ascii_letters) for _ in range(16)
        )

    def login(self):
        log("logging in")
        login_resp = self.session.post(
            f"{self.target_url}/user/login",
            json={"email": self.email, "password": self.credential.data["password"]},
        )

        if login_resp.status_code != 200:
            raise Exception(f"failed to login: {login_resp.text}")

        json_data = login_resp.json()
        try:
            self.token = json_data["data"]["token"]
            self.session.headers.update({"Authorization": f"Bearer {self.token}"})
        except KeyError as e:
            raise Exception(
                f"token not found in login response:\n{login_resp.text}",
                e,
            )

    def refresh_token(self):
        log("refreshing token")
        try:
            self.session.headers.update({"Authorization": f"Bearer {self.token}"})
            refresh_resp = self.session.get(
                f"{self.target_url}/user/refresh_token",
                params={"organization_canonical": "cycloid"},
            )
            if refresh_resp.status_code != 200:
                raise Exception(
                    f"failed to refresh token: {refresh_resp.status_code}: {refresh_resp.text}"
                )
            self.token = refresh_resp.json()["data"]["token"]
            self.session.headers.update({"Authorization": f"Bearer {self.token}"})
        except Exception as e:
            raise Exception(f"failed to refresh token: {e}")

    def create_admin_user(self):
        log("creating admin user")
        body = {
            "email": self.email,
            "password": self.credential.data["password"],
            "username": "admin",
            "family_name": "admin",
            "given_name": "admin",
        }

        resp = self.session.post(f"{self.target_url}/user", json=body)
        match resp.status_code:
            case 204 | 409:
                log("Admin user created.")

                self.credential.data.update(
                    {
                        "username": "admin",
                        "email": self.email,
                        "password": self.credential.data["password"],
                    }
                )
                return
            case _:
                raise Exception(
                    f"failed to create admin user: {resp.status_code}: {resp.text}"
                )

    def init_token(self):
        self.login()

    def create_org(self):
        log("creating organization")
        org_resp = self.session.post(
            f"{self.target_url}/organizations",
            json={"name": "cycloid", "canonical": "cycloid"},
        )

        if org_resp.status_code not in [200, 409]:
            raise Exception(
                f"failed to create first organization: {org_resp.status_code}: {org_resp.text}"
            )

        self.credential.data.update({"org": "cycloid"})

    def fetch_license(self):
        response = requests.get(
                f"{self.source_url}/organizations/cycloid/credentials/{self.licence}",
                headers={
                    "Content-Type": "application/vnd.cycloid.io.v1+json",
                    "Authorization": f"Bearer {self.source_token}",
                },
            )
        if response.status_code != 200:
            raise Exception(
                    f"failed to fetch licence with credential name {self.licence}: {response.status_code}: {response.text}"
            )

        try:
            self.licence_key = response.json()["data"]["raw"]["raw"]["licence_key"]
        except Exception as e:
            e.add_note("failed to decode payload from api, reponse:\n{responses.text}")
            raise e

    def add_license(self):
        log("adding licence")
        self.fetch_license()
        self.refresh_token()
        licence_resp = self.session.post(
            f"{self.target_url}/organizations/cycloid/licence",
            json={
                "key": self.licence_key,
            },
        )
        if licence_resp.status_code != 204:
            raise Exception(
                f"failed to add licence: {licence_resp.status_code}: {licence_resp.text}"
            )

    def create_api_key(self):
        log("creating api key")
        self.refresh_token()
        api_resp = self.session.post(
            f"{self.target_url}/organizations/cycloid/api_keys",
            json={
                "name": "admin-token",
                "description": "first admin token generated for this cycloid instance.",
                "canonical": "admin-token",
                "rules": [
                    {"action": "organization:**", "effect": "allow", "resources": []}
                ],
            },
        )
        match api_resp.status_code:
            case 200:
                try:
                    self.credential.data["token"] = api_resp.json()["data"]["token"]
                except Exception as e:
                    raise Exception(
                        f"failed to get api_key from response data: {api_resp.status_code}: {api_resp.text}\n",
                        e,
                    )
            case 409:
                log("api_key already exists, recreating....")
                delete_resp = self.session.delete(
                    f"{self.target_url}/organizations/cycloid/api_keys/admin-token"
                )
                if delete_resp.status_code != 204:
                    raise Exception(
                        f"failed to delete api_key: {delete_resp.status_code}: {delete_resp.text}"
                    )
                return self.create_api_key()
            case _:
                raise Exception(
                    f"failed to create api token: {api_resp.status_code}: {api_resp.text}"
                )

    def report(self):
        log("reporting")
        try:
            self.credential.write()
        except Exception as e:
            raise Exception(
                f"failed to write output file at init/output.json\nerr: {e}"
            )
        finally:
            print(json.dumps(self.credential.data, indent=2), file=sys.stdout)
            self.session.close()

    def provision(self):
        try:
            self.create_admin_user()
            self.init_token()
            self.create_org()
            self.add_license()
            self.create_api_key()
        except Exception as e:
            raise Exception(f"provisioning failed: {e}")
        finally:
            self.report()


if __name__ == "__main__":
    settings = Settings()
    cy_initializer = CycloidProvisionner(settings)
    cy_initializer.provision()

    if settings.provisioning_enabled:
        log("Starting provisioning")
        response = requests.get("https://raw.githubusercontent.com/cycloidio/cycloid-utils/master/cy-provisioner/cy-provisioner")
        script = response.text
         
        import subprocess

        env = os.environ.copy() | {
            "CY_SOURCE_API_KEY": settings.source_api_token,
            "CY_TARGET_API_URL": settings.target_api_url,
            "CY_TARGET_API_KEY": cy_initializer.credential.data["token"],
        }
        cmd = ["-xc", script]

        sub_process = subprocess.Popen(
                executable="bash",
                args=cmd,
                close_fds=True,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                encoding="utf-8",
                env=env
            )

        while True:
            out = sub_process.stdout.readline()
            sys.stdout.write(out)
            sys.stdout.flush()

            err = sub_process.stderr.readline()
            sys.stderr.write(err)
            sys.stderr.flush()

            if sub_process.poll() is not None:
                break

        if sub_process.returncode != 0:
            error("provisioning failed")

        sys.exit(sub_process.returncode)




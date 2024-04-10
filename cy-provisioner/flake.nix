{
  description = "A basic dev shell for nix users";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-unstable"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;

          cy_sources = import ./ci/_sources/generated.nix { inherit (pkgs) fetchgit fetchurl fetchFromGitHub dockerTools; };
          cy = pkgs.buildGoModule rec {
            name = "cy";
            inherit (cy_sources.cy) src version;

            ldflags =
              let
                repo_path = "github.com/cycloidio/cycloid-cli";
              in
              [
                "-X ${repo_path}/internal/version.Version=${version}"
                "-X ${repo_path}/internal/version.Revision=${version}"
                "-X ${repo_path}/internal/version.Branch=${version}"
                "-X ${repo_path}/internal/version.BuildOrigin=github-nix"
                "-X ${repo_path}/internal/version.BuildDate=osef"
              ];

            # Fix the CLI executable name
            postInstall = ''
              mv "$out/bin/cycloid-cli" "$out/bin/cy"
            '';

            vendorHash = "sha256-Z0ISg8xeISPrN2gUbgehdhowB+KM1ci3bFJiyK72vRY=";

            meta = with lib; {
              description = "Cycloid command line";
              homepage = "https://github.com/cycloidio/cycloid-cli";
              license = licenses.mit;
            };
          };

          runtimeDependencies = with pkgs; [
            bashInteractive
            coreutils-full
            jq
            curl
            openssh
            git
            gnugrep
            xdg-utils
          ] ++ [ cy ];

          buildDependencies = with pkgs; [
            just
            watchexec
            bashly
            libyaml
          ];
        in
        {
          packages = rec {
            cy-provisioner = pkgs.stdenv.mkDerivation {
              name = "cy-provisioner";
              src = ./.;
              version = "0.1.0";
              buildInputs = buildDependencies;
              runtimeInputs = runtimeDependencies;
              buildPhase = ''
                ls -la 
                just build
              '';

              installPhase = ''
                mkdir -p "$out/bin"
                mv cy-provisioner "$out/bin/cy-provisioner"
              '';
            };

            docker = pkgs.dockerTools.buildImage {
              name = "dev-provisioner";
              tag = "dev";

              copyToRoot = pkgs.buildEnv {
                name = "image-root";
                paths = with pkgs.dockerTools; [ usrBinEnv binSh caCertificates fakeNss ]
                  ++ runtimeDependencies
                  ++ [ cy-provisioner ];
                pathsToLink = [ "/bin" "/lib" "/share" ];
              };

              # Add unprivileged user + required xdg folder for cycloid cli
              runAsRoot = ''
                #!${pkgs.runtimeShell}
                ${pkgs.dockerTools.shadowSetup}
                ${pkgs.shadow}/bin/groupadd -r cy
                ${pkgs.shadow}/bin/useradd -r -g cy cy -d /home/cy -m -s /bin/bash -u 1000
                ${pkgs.coreutils}/bin/mkdir -p /etc/xdg/cycloid-cli /home/cy/.config/cycloid-cli
                ${pkgs.coreutils}/bin/chmod -R 0777 /etc/xdg /tmp
                ${pkgs.coreutils}/bin/chown -R cy:cy /home/cy
                ${pkgs.coreutils}/bin/chmod -R 0771 /home/cy
                ${pkgs.coreutils}/bin/mkdir -p /usr/bin
                ${pkgs.coreutils}/bin/ln -sf ${pkgs.coreutils}/bin/env /usr/bin/env
              '';

              config = {
                Entrypoint = [ "/bin/cy-provisioner" ];
                Cmd = [ "provision" ];
                Workdir = "/home/cy";
                User = "cy";
                Env = [
                  "CY_SOURCE_API_KEY"
                  "CY_SOURCE_ORG"
                  "CY_SOURCE_API_URL"
                  "CY_SOURCE_CREDENTIAL_CANONICAL"
                  "CY_SOURCE_CREDENTIAL_RAW"
                  "CY_TARGET_API_KEY"
                  "CY_TARGET_ORG"
                  "CY_TARGET_API_URL"
                ];
              };
            };
          };

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs;
              [
                just
                ruby
              ] ++ runtimeDependencies;
          };
        });
}

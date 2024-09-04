{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = builtins.attrValues {
    cyInitPython = pkgs.python312.withPackages (p: with p; [
      requests
    ]);
    inherit (pkgs)
      watchexec
      ruff
      ruff-lsp
      pyright
      ;
  };
}


{
  description = "shen-scheme development environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { nixpkgs, ... }: let systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ]; each = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system}); in {
    packages = each (pkgs: { toolchain = pkgs.buildEnv { name = "shen-scheme-toolchain"; paths = with pkgs; [ gnumake gcc chez ]; }; default = pkgs.buildEnv { name = "shen-scheme-toolchain"; paths = with pkgs; [ gnumake gcc chez ]; }; });
    devShells = each (pkgs: { default = pkgs.mkShell { packages = with pkgs; [ gnumake gcc chez ]; }; });
  };
}

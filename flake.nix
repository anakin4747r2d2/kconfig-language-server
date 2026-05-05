{
  description = "Language server for the Kernel configuration language used in Linux, U-boot, Zephyr, and coreboot";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, neovim-nightly }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        nvim = neovim-nightly.packages.${system}.default;

        kconfig-language-server = pkgs.writeShellApplication {
          name = "kconfig-language-server";
          runtimeInputs = with pkgs; [ bash coreutils jq ripgrep gnused gnugrep gawk ];
          checkPhase = "";
          text = builtins.readFile ./kconfig-language-server;
        };

        vscode-extension = pkgs.buildNpmPackage {
          pname = "kconfig-language-server-vscode";
          version = "0.0.1";
          src = ./vscode-extension;
          npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          buildPhase = ''
            npx esbuild src/extension.ts \
              --bundle \
              --outfile=out/extension.js \
              --external:vscode \
              --format=cjs \
              --platform=node
          '';
          installPhase = ''
            mkdir -p $out
            cp -r out package.json $out/
          '';
        };

        tryout = pkgs.writeShellApplication {
          name = "tryout";
          runtimeInputs = with pkgs; [ nvim coreutils gnugrep kconfig-language-server ];
          checkPhase = "";
          text = ''
            set +e +u +o pipefail
            kconfig_root="$(pwd)"

            kconfig_file="$(find "$kconfig_root" \( -name 'Kconfig' -o -name 'Kconfig.*' \) 2>/dev/null | grep -v '\.git' | shuf -n 1 || true)"
            if [[ -z "$kconfig_file" ]]; then
              echo "tryout: no Kconfig files found under $kconfig_root" >&2
              echo "Run this from the root of a Linux/Zephyr/U-Boot source tree." >&2
              exit 1
            fi

            nvim_config=$(mktemp -d)
            cat > "$nvim_config/init.lua" <<EOF
            vim.lsp.set_log_level("debug")
            vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
                pattern = { "Kconfig", "Kconfig.*" },
                callback = function()
                    vim.lsp.start({
                        name = "kconfig-language-server",
                        cmd = { "kconfig-language-server" },
                        root_dir = "${kconfig_root}",
                        filetypes = { "kconfig" },
                    })
                end,
            })
            EOF

            log_path="$(cat /tmp/nvim-lsp.log 2>/dev/null || echo '/tmp/nvim-lsp.log')"
            echo "LSP log: $log_path"
            exec nvim -u "$nvim_config/init.lua" "$kconfig_file"
          '';
        };

        tryout-vscode = pkgs.writeShellApplication {
          name = "tryout-vscode";
          runtimeInputs = with pkgs; [ vscodium kconfig-language-server ];
          checkPhase = "";
          text = ''
            set +e +u +o pipefail
            kconfig_root="$(pwd)"

            kconfig_file="$(find "$kconfig_root" \( -name 'Kconfig' -o -name 'Kconfig.*' \) 2>/dev/null | grep -v '\.git' | shuf -n 1 || true)"
            if [[ -z "$kconfig_file" ]]; then
              echo "tryout-vscode: no Kconfig files found under $kconfig_root" >&2
              echo "Run this from the root of a Linux/Zephyr/U-Boot source tree." >&2
              exit 1
            fi

            ext_dir="${vscode-extension}"
            profile_dir="$(mktemp -d)"

            codium \
              --extensions-dir "$profile_dir/extensions" \
              --install-extension "$ext_dir" \
              --wait \
              "$kconfig_file" || true
          '';
        };

      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation rec {
            pname = "kconfig-language-server";
            version = "1.0.1";

            src = pkgs.fetchFromGitHub {
              owner = "anakin4747";
              repo = pname;
              rev = version;
              sha256 = "sha256-c6GeIRMyXUkJ/Mffq0wM6ARVP3fLQdVLVVCvaLiqpqg=";
            };

            propagatedBuildInputs = with pkgs; [
              gawk
              gnused
              jq
              ripgrep
            ];

            dontBuild = true;

            installPhase = ''
              make install DESTDIR=$out PREFIX=
            '';

            meta = with pkgs.lib; {
              description = "Language server for the Kernel configuration language used in Linux, U-boot, Zephyr, and coreboot";
              homepage = "https://github.com/anakin4747/kconfig-language-server";
              license = licenses.gpl2;
              platforms = platforms.unix;
              maintainers = [ maintainers.anakin4747 ];
              mainProgram = pname;
            };
          };

          inherit tryout tryout-vscode;
        };

        apps = {
          tryout = {
            type = "app";
            program = "${tryout}/bin/tryout";
          };
          tryout-vscode = {
            type = "app";
            program = "${tryout-vscode}/bin/tryout-vscode";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ bats jq ripgrep shellcheck ];
        };
      }
    );
}

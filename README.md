# Kconfig LSP

A language server for the Kconfig language used for build system configuration
in Linux, U-Boot, Zephyr, coreboot, and other projects.

![CI](https://github.com/anakin4747r2d2/kconfig-language-server/actions/workflows/ci.yml/badge.svg?branch=feature/lsts-integration)

## Features

| LSP Method | Status |
|---|---|
| `textDocument/hover` | ✅ |
| `textDocument/definition` | ✅ |
| `textDocument/completion` | ✅ |
| `textDocument/references` | ✅ |
| `textDocument/documentSymbol` | ✅ |
| `textDocument/documentHighlight` | ✅ |
| `textDocument/rename` | ✅ |
| `textDocument/publishDiagnostics` | ✅ |
| `textDocument/didOpen` | ✅ |
| `textDocument/didChange` | ✅ |

### hover

Provides documentation for Kconfig keywords and symbols on hover. Documentation
is sourced from `Documentation/kbuild/kconfig-language.rst` in the open
project if available, otherwise falls back to the copy bundled with this server.

### definition

Go-to-definition for `config` and `menuconfig` symbols across the workspace.
Handles both single and multiple definitions and computes correct character
offsets for both `config` and `menuconfig` keyword lengths.

### completion

Completes all Kconfig keywords (`config`, `depends`, `select`, `bool`,
`tristate`, etc.) and symbol names from the workspace.

### references

Finds all uses of a symbol: `depends on`, `select`, `imply`, and `default`
references across the workspace. Respects `includeDeclaration`.

### documentSymbol

Lists all `config`, `menuconfig`, `menu`, and `choice` symbols defined in the
current file.

### documentHighlight

Highlights all occurrences of the symbol under the cursor in the current file.
Declarations are marked with kind Write (3), references with kind Text (1).

### rename

Renames a Kconfig symbol across all Kconfig files in the workspace, producing
a `WorkspaceEdit` with per-file text edits.

### publishDiagnostics

Diagnostics are pushed automatically on `didOpen` and `didChange`:

- **Undefined symbol** (error) — any symbol in `depends on`, `select`, or
  `imply` that has no `config`/`menuconfig` definition in the workspace
- **Bad `range`** (error) — `range` statement with fewer than two values

Help block content is excluded from diagnostic checks.

## Try it out

The quickest way to try the language server against a real codebase is with the
provided Nix apps. Run from the root of a Linux, Zephyr, or U-Boot source tree:

```sh
# With Neovim
nix run github:anakin4747r2d2/kconfig-language-server#tryout

# With VSCodium
nix run github:anakin4747r2d2/kconfig-language-server#tryout-vscode
```

Each command picks a random Kconfig file from the tree, starts the language
server, and opens it with the LSP already configured.

> **Requirements:** [Nix](https://nixos.org/download/) must be installed with
> the `nix-command` and `flakes` experimental features enabled. Add the
> following to `~/.config/nix/nix.conf` (or `/etc/nix/nix.conf`):
>
> ```
> experimental-features = nix-command flakes
> ```

## Demo

<div align="center">

[![Demo of kconfig-language-server](https://img.youtube.com/vi/N20begB_v9s/mqdefault.jpg)](https://www.youtube.com/watch?v=N20begB_v9s)

</div>

## Dependencies

- `rg` (ripgrep)
- `jq`
- `awk`
- `sed`
- `bats` (optional, for testing)

## Installation

Being a single file bash script, no building is required.

```sh
sudo make install
# or
sudo make dev-install  # installs as a symlink
# and
sudo make uninstall
```

## Testing

Tests use the [`bats`](https://github.com/bats-core/bats-core) framework and
the [`lsts`](https://github.com/anakin4747/lsts) language server test library
as a git submodule.

```sh
make test
```

This runs both the unit tests (`test/test_kconfig-language-server.bats`) and
the end-to-end LSP integration tests (`test/test_lsts.bats`).

## Configuration

### Neovim

```lua
vim.lsp.config.kconfig = {
    root_markers = { '.git' },
    cmd = { 'kconfig-language-server' },
    filetypes = { 'kconfig' },
}

vim.lsp.enable('kconfig')
```

## Troubleshooting

If the server fails immediately, run it directly to see any error output:

```sh
kconfig-language-server
```

For verbose debug output:

```sh
bash -x kconfig-language-server
```

## License

GPL-2.0. The bundled `kconfig-language.rst` is derived from the Linux kernel
source and is provided under the same license.

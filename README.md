# Aptos Move Extension for Zed

Language support for Aptos Move in the Zed editor, including syntax highlighting and LSP integration.

## Features

- Syntax highlighting for Move language
- Language Server Protocol (LSP) integration with `aptos-language-server`
- Auto-completion, go-to-definition, and diagnostics
- Bracket matching and auto-indentation
- Support for Move-specific syntax (modules, structs, functions, specs, etc.)
- Unit test, coverage, and Move Prover workflows via ▶ run indicators and Zed tasks
- Debugging with `aptos-dap`: step through `#[test]` functions or replay on-chain transactions
- Formatting via `movefmt` (format-on-save ready, binary resolved automatically)
- Linting: inline language-server diagnostics plus `aptos move lint` tasks
- Full `Move.toml` support: syntax highlighting for TOML plus Move-specific
  sections (`package`, `dependencies`, `dev-dependencies`, `addresses`,
  `dev-addresses`), bracket matching, auto-indentation, and outline, cursor
  navigation, and LSP completions

## Installation

### 1. Install the Aptos Language Server

The extension requires the `aptos-language-server` binary to be installed and available in your PATH.

Download the latest pre-built binary for your platform from the [releases page](https://github.com/aptos-labs/move-vscode-extension/releases):

**macOS (Apple Silicon):**
```bash
curl -L https://github.com/aptos-labs/move-vscode-extension/releases/latest/download/aptos-language-server-aarch64-apple-darwin.gz | gunzip > aptos-language-server
chmod +x aptos-language-server
sudo mv aptos-language-server /usr/local/bin/
```

**macOS (Intel):**
```bash
curl -L https://github.com/aptos-labs/move-vscode-extension/releases/latest/download/aptos-language-server-x86_64-apple-darwin.gz | gunzip > aptos-language-server
chmod +x aptos-language-server
sudo mv aptos-language-server /usr/local/bin/
```

**Linux (x86_64):**
```bash
curl -L https://github.com/aptos-labs/move-vscode-extension/releases/latest/download/aptos-language-server-x86_64-unknown-linux-gnu.gz | gunzip > aptos-language-server
chmod +x aptos-language-server
sudo mv aptos-language-server /usr/local/bin/
```

**Windows (x86_64):**
Download [aptos-language-server-x86_64-pc-windows-msvc.zip](https://github.com/aptos-labs/move-vscode-extension/releases/latest/download/aptos-language-server-x86_64-pc-windows-msvc.zip), extract it, and add the directory to your PATH.

**Verify installation:**
```bash
aptos-language-server --version
```

### 2. Install the Extension

#### From Source (Development)

1. Clone this repository:
   ```bash
   git clone https://github.com/0xbe1/aptos-move-zed-extension.git
   cd aptos-move-zed-extension
   ```

2. Build the extension:
   ```bash
   cargo build --target wasm32-wasip2 --release
   cp target/wasm32-wasip2/release/aptos_move_zed_extension.wasm extension.wasm
   ```

3. Link it to Zed's extensions directory:
   ```bash
   mkdir -p ~/.config/zed/extensions
   ln -s $(pwd) ~/.config/zed/extensions/aptos-move
   ```

4. Restart Zed

#### From Zed Extensions (Future)

Once published to the Zed extension registry:
- Open Zed
- Press `Cmd+Shift+P` and search for "Extensions"
- Search for "Aptos Move" and install

## Usage

Open any `.move` file in Zed and the extension will automatically activate, providing:
- Syntax highlighting
- LSP features (hover, completion, diagnostics)
- Code navigation

### Important: Trust Your Workspace

**Zed requires you to trust your workspace before starting the language server** for security reasons.

When you first open a Move project, you'll see a banner asking to trust the folder. Click **"Trust"** to enable LSP features (go-to-definition, hover, diagnostics, etc.).

## Tests, Coverage & the Move Prover

The extension shows ▶ run indicators next to `#[test]` functions and module
declarations. Clicking an indicator runs the Zed task bound to its tag.

### One-time setup: install the task bindings

Zed resolves run indicators through task templates, which live in your project
(`.zed/tasks.json`) or globally (`~/.config/zed/tasks.json`). Copy — or merge —
[`templates/tasks.json`](templates/tasks.json) into one of those locations:

```bash
mkdir -p .zed && cp templates/tasks.json .zed/tasks.json   # per project
```

The templates bind:

| Tag | Indicator | Runs |
|---|---|---|
| `move-test` | ▶ on `#[test]` functions | `aptos move test --filter <fn>` |
| `move-prove` | ▶ on module declarations | `aptos move prove --filter <module>` |

and add task-modal entries (open with `task: spawn`) for the rest of the
workflow: test all / test at cursor, prove package / function at cursor,
`test --coverage`, `coverage summary | source | bytecode`, `move lint`
(default / strict / list checks), and compile-with-warnings.

### Coverage

1. Run **move test: with coverage** — runs the suite instrumented (`aptos move test --coverage`)
2. Run **move coverage: summary** or **move coverage: source** — reads the trace
   produced by step 1

### Move Prover

The `move prove: ...` tasks wrap `aptos move prove` (`--filter <module>`,
`--only <fn>`). The prover needs its own toolchain (Z3, Boogie) on `PATH`; see
the [Move Prover docs](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/prover).

> **Why tasks instead of code lenses?** The VS Code extension's clickable
> "Run Test" lenses work because its client code spawns the `aptos` CLI — the
> language server itself never runs tests, and Zed has no handler for the
> `move-on-aptos.runTest` commands. Zed tasks are the native equivalent, with
> full terminal output. Requires the [`aptos` CLI](https://aptos.dev/tools/install-cli/) on `PATH`.

## Debugging

Two debug adapters built on
[`aptos-dap`](https://github.com/aptos-labs/aptos-debugger), downloaded
automatically on first use (prebuilt binaries exist for macOS arm64/x64 and
Linux x64; on other platforms build it from source and put `aptos-dap` on your
`PATH`):

- **Aptos Move Test** — debug a package's `#[test]` functions
- **Aptos Move Replay** — replay and step through an executed on-chain transaction

Add a `.zed/debug.json` to your project:

```json
[
  {
    "label": "Debug this package's tests",
    "adapter": "Aptos Move Test",
    "request": "launch",
    "packagePath": "$ZED_WORKTREE_ROOT",
    "testFilter": "test_"
  },
  {
    "label": "Replay a mainnet transaction",
    "adapter": "Aptos Move Replay",
    "request": "launch",
    "network": "mainnet",
    "txnId": "0x123...",
    "useLocalPackages": ["$ZED_WORKTREE_ROOT"]
  }
]
```

Supported fields (names match the VS Code extension's launch schema):
`testFilter`, `packagePath`, `network`, `txnId`, `useLocalPackages`,
`namedAddresses`, `extraArgs`, `env`. Set breakpoints in `.move` files and
start the session from Zed's debugger.

## Formatting

Formatting is provided by [movefmt](https://github.com/aptos-labs/movefmt)
(≥ 1.2.1), which the language server shells out to for `editor: format` and
format-on-save:

```json
// settings.json
"languages": {
  "Move": { "format_on_save": "on" }
}
```

The extension resolves the binary in this order: `movefmt` on `PATH` → a copy
downloaded automatically from the
[aptos-labs/movefmt releases](https://github.com/aptos-labs/movefmt/releases)
(prebuilts for macOS arm64/x64, Linux arm64/x64, and Windows x64). To manage
it yourself instead:

```bash
aptos update movefmt        # installs the pinned version to ~/.local/bin
```

movefmt reads a `movefmt.toml` next to your `Move.toml` (`max_width`,
`tab_spaces`, …) — see the
[movefmt usage docs](https://github.com/movebit/movefmt/blob/develop/doc/how_to_use.md).

> The VS Code extension prompts to run `aptos update movefmt` via a custom
> notification when the binary is missing or too old; Zed doesn't surface that
> notification, which is why this extension resolves and downloads movefmt
> itself.

## Linting

Two layers:

- **Inline diagnostics** come from the language server as you edit — unused
  imports/variables, redundant casts, "can be replaced with method call"
  suggestions, missing doc comments on error constants, and more, several with
  quickfixes (⌘.). They are on by default; `missing-const-doc-comment` is
  disabled upstream by default.
- **Package-level lint tasks** wrap `aptos move lint` (Move 2 compiler lints
  on top of ordinary warnings): **move lint: package** (default tier),
  **move lint: strict**, and **move lint: list checks**, which prints every
  check grouped by tier (`default` / `strict` / `experimental` / `all`) for
  use with `--checks`. Also included: **move check: compile (warnings fail)**.

## Project Structure

```
aptos-move-zed-extension/
├── extension.toml           # Extension metadata (grammars pinned by rev; LSP + debug adapters)
├── Cargo.toml              # Rust dependencies
├── Justfile                # Task runner recipes (build, clippy, test, ci)
├── src/
│   └── lib.rs              # LSP + debug adapter integration code
├── languages/
│   ├── move/               # Move language (.move files)
│   │   ├── config.toml     # Language configuration
│   │   ├── highlights.scm  # Syntax highlighting rules
│   │   ├── runnables.scm   # ▶ run indicators (test, prove)
│   │   ├── outline.scm     # Outline / breadcrumbs
│   │   ├── brackets.scm    # Bracket matching
│   │   └── indents.scm     # Auto-indentation rules
│   └── move-toml/          # Move.toml support
├── templates/
│   └── tasks.json           # Task bindings for test / coverage / prover / fmt / lint
├── scripts/
│   └── validate-queries.sh # Checks queries & fixtures against pinned grammars
└── test-fixtures/          # Move package used for manual & automated testing
    ├── Move.toml
    └── sources/            # .move fixtures exercising the grammar's features
```

## Development

### Prerequisites

- Rust toolchain — pinned via `rust-toolchain.toml` (currently 1.96.0 with
  `wasm32-wasip2`, rustfmt, and clippy; rustup installs it automatically)
- Zed editor
- Optional, for query validation: `npm install -g tree-sitter-cli`

### Building

```bash
cargo build --target wasm32-wasip2 --release
cp target/wasm32-wasip2/release/aptos_move_zed_extension.wasm extension.wasm
```

### Testing

Automated checks (all run in CI; `just ci` runs everything locally):

- `just fmt-check` — formatting
- `just clippy` — lints (warnings are errors)
- `just test` — Rust unit tests
- `just test-queries` — validates every `languages/**/*.scm` query against the
  grammars pinned in `extension.toml` and checks that all `test-fixtures/`
  files parse without errors (requires the tree-sitter CLI)

For manual end-to-end testing, open a Move project (e.g. `test-fixtures/`) in
Zed with the extension linked.

## Contributing

Contributions welcome! Please open issues or pull requests on GitHub.

## License

MIT

## Acknowledgments

- Tree-sitter grammar: [aptos-labs/tree-sitter-move-on-aptos](https://github.com/aptos-labs/tree-sitter-move-on-aptos)
- Language server: [aptos-labs/move-vscode-extension](https://github.com/aptos-labs/move-vscode-extension)

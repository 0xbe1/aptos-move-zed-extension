# Aptos Move Zed Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Aptos Move Zed extension to feature parity with the VS Code Move on Aptos extension, covering binary auto-download, Move 2 grammar, LSP configuration, Move.toml language support, and (via LSP changes) auto-import, test runner, Move Prover, and Move.toml completions.

**Architecture:** Track A items live entirely in `aptos-move-zed-extension`. Track B items require parallel changes to `aptos-labs/move-vscode-extension` (the LSP server); those tasks are written assuming you have a local checkout of that repo. Both tracks can be worked concurrently — the Zed extension side of Track B is wired up in A3/A5 and just needs the server to respond.

**Tech Stack:** Rust, `zed_extension_api = "0.7.0"`, Tree-sitter, LSP protocol, `aptos-language-server` (Rust binary from `aptos-labs/move-vscode-extension`)

---

## File Map

### `aptos-move-zed-extension` (this repo)

| File | Change |
|---|---|
| `src/lib.rs` | Full rewrite: stateful struct, auto-download (A0), init options (A3), aptos CLI env (A5) |
| `Cargo.toml` | Verify 0.7.0 is current (A2 — no change expected) |
| `extension.toml` | Grammar rev bump (A1), add move-toml language + LSP languages entry (A4/B4) |
| `languages/move/highlights.scm` | Complete rewrite — all node names changed in new grammar (A1) |
| `languages/move/indents.scm` | Fix node names (A1) |
| `languages/move-toml/config.toml` | New file: Move.toml language definition (A4) |
| `languages/move-toml/highlights.scm` | New file: Move.toml highlights (A4) |

### `aptos-labs/move-vscode-extension` (Track B — separate repo)

| Area | Change |
|---|---|
| Completion provider | Add `additionalTextEdits` for unimported symbols (B1) |
| Code action provider | Add `source.organizeImports` + `source.removeUnusedImports` (B2) |
| Code lens provider | Add `textDocument/codeLens` for `#[test]` functions + `aptos-move.runTest` command (B3) |
| Move.toml handler | Register `Move.toml` in `documentSelector`, add completions (B4) |
| Prover command | Add `aptos-move.proveModule` command with `$/progress` streaming (B5) |

---

## Track A — Zed Extension Only

---

### Task 1: Update grammar and fix all node names (A1)

The tree-sitter grammar was rewritten for Move 2 — every declaration node was renamed and the `binary_operator` node was removed. The current `highlights.scm` produces no highlighting for functions, structs, modules, etc. This is the highest-impact fix.

**Confirmed node name mapping** (verified against `aptos-labs/tree-sitter-move-on-aptos` HEAD `12906b341de7cef81cf03d7d91dae51d8a9299e7`):

| Old | New |
|---|---|
| `(number)` | `(num_literal)` |
| `(byte_string)` | `(byte_string_literal)` |
| `(numerical_addr)` | `(numerical_address)` |
| `(module name:` | `(module_declaration name:` |
| `(function_decl name:` | `(function_declaration name:` |
| `(struct_decl name:` | `(struct_declaration name:` |
| `(enum_decl name:` | `(enum_declaration name:` |
| `(constant_decl name:` | `(constant_declaration name:` |
| `(field_annot field:` | `(field_declaration name:` |
| `(parameter variable:` | `(function_parameter name:` |
| `(access_field field:` | `(dot_expression field:` |
| `(break_expr)` | `(break_expression)` |
| `(continue_expr)` | `(continue_expression)` |
| `(return_expr)` | `(return_expression)` |
| `(abort_expr)` | `(abort_expression)` |
| `(binary_operator) @operator` | **removed** — no standalone operator node |

New nodes added for Move 2:
- `(enum_variant name: (identifier) @constructor)` — enum variant names
- `(hex_string_literal) @string` — hex string literals `x"DEADBEEF"`

**Files:**
- Modify: `extension.toml`
- Modify: `languages/move/highlights.scm`
- Modify: `languages/move/indents.scm`

- [ ] **Step 1.1: Update grammar rev in `extension.toml`**

Replace the `[grammars.move_on_aptos]` rev:

```toml
[grammars.move_on_aptos]
repository = "https://github.com/aptos-labs/tree-sitter-move-on-aptos"
rev = "12906b341de7cef81cf03d7d91dae51d8a9299e7"
```

- [ ] **Step 1.2: Rewrite `languages/move/highlights.scm`**

Replace the entire file:

```scheme
; Comments
(line_comment) @comment
(block_comment) @comment

; Literals
(bool_literal) @boolean
(num_literal) @number
(byte_string_literal) @string
(hex_string_literal) @string
(numerical_address) @constant.builtin

; Module declarations
(module_declaration
  name: (identifier) @namespace)

; Function declarations
(function_declaration
  name: (identifier) @function)

; Struct declarations
(struct_declaration
  name: (identifier) @type)

; Enum declarations
(enum_declaration
  name: (identifier) @type)

; Enum variants (Move 2)
(enum_variant
  name: (identifier) @constructor)

; Constant declarations
(constant_declaration
  name: (identifier) @constant)

; Type references
(primitive_type) @type.builtin

; Abilities
(ability) @attribute

; Attributes
(attribute) @attribute

; Struct field declarations
(field_declaration
  name: (identifier) @property)

; Parameters
(function_parameter
  name: (identifier) @variable.parameter)

; Field access via dot
(dot_expression
  field: (identifier) @property)

; Control flow
(break_expression) @keyword.control
(continue_expression) @keyword.control
(return_expression) @keyword.control
(abort_expression) @keyword.control

; Built-in functions
((identifier) @function.builtin
  (#match? @function.builtin "^(assert|move_to|move_from|borrow_global|borrow_global_mut|exists|freeze|vector)$"))

; All other identifiers
(identifier) @variable
```

- [ ] **Step 1.3: Rewrite `languages/move/indents.scm`**

Replace the entire file:

```scheme
; Generic blocks
(block) @indent

; Function bodies
(function_declaration
  body: (block) @indent)

; Module body
(module_declaration) @indent

; If/else expressions
(if_expression) @indent

; Loop expressions
(while_expression) @indent
(loop_expression) @indent
(for_expression) @indent
```

- [ ] **Step 1.4: Commit**

```bash
git add extension.toml languages/move/highlights.scm languages/move/indents.scm
git commit -m "feat: update grammar to Move 2, fix all tree-sitter node names"
```

---

### Task 2: Verify zed_extension_api version (A2)

- [ ] **Step 2.1: Confirm 0.7.0 is current**

```bash
cargo search zed_extension_api 2>/dev/null | head -5
```

Expected: version `0.7.0` listed. If a newer version exists, bump `Cargo.toml` and resolve any API changes before proceeding.

- [ ] **Step 2.2: Commit if changed, skip if no-op**

```bash
# Only if version was bumped:
git add Cargo.toml
git commit -m "chore: bump zed_extension_api to <new-version>"
```

---

### Task 3: Refactor lib.rs to stateful struct (foundation for A0 and A5)

The current extension is a unit struct. Auto-download requires caching the binary path across calls. This task converts the struct to hold state, which all subsequent `lib.rs` tasks build on.

**Files:**
- Modify: `src/lib.rs`

- [ ] **Step 3.1: Replace the entire `src/lib.rs` with stateful foundation**

```rust
use zed_extension_api::{self as zed, Result};

struct AptosMoveExtension {
    cached_binary_path: Option<String>,
}

impl zed::Extension for AptosMoveExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let server_path = worktree
            .which("aptos-language-server")
            .ok_or_else(|| "aptos-language-server not found in PATH. Install: cargo install --git https://github.com/aptos-labs/move-vscode-extension.git aptos-language-server")?;

        Ok(zed::Command {
            command: server_path,
            args: vec!["lsp-server".to_string()],
            env: Default::default(),
        })
    }
}

zed::register_extension!(AptosMoveExtension);
```

- [ ] **Step 3.2: Verify it still compiles**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -5
```

Expected: `Compiling aptos-move-zed-extension` then `Finished`. No errors.

- [ ] **Step 3.3: Commit**

```bash
git add src/lib.rs
git commit -m "refactor: convert to stateful extension struct"
```

---

### Task 4: Implement binary auto-download (A0)

Extends Task 3's `lib.rs`. The logic: PATH first (user override) → cached path from prior run → download from GitHub Releases.

**Files:**
- Modify: `src/lib.rs`

- [ ] **Step 4.1: Replace `src/lib.rs` with full auto-download implementation**

```rust
use zed_extension_api::{
    self as zed,
    DownloadedFileType, GithubReleaseOptions, LanguageServerInstallationStatus, Result,
    download_file, latest_github_release, make_file_executable,
};

struct AptosMoveExtension {
    cached_binary_path: Option<String>,
}

impl AptosMoveExtension {
    fn language_server_binary(
        &mut self,
        language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<String> {
        // 1. Prefer binary on PATH (user-installed or managed by package manager)
        if let Some(path) = worktree.which("aptos-language-server") {
            return Ok(path);
        }

        // 2. Return cached path if the file still exists from a prior download
        if let Some(ref path) = self.cached_binary_path {
            if std::fs::metadata(path).map(|m| m.len() > 0).unwrap_or(false) {
                return Ok(path.clone());
            }
        }

        // 3. Download from GitHub Releases
        zed::set_language_server_installation_status(
            language_server_id,
            &LanguageServerInstallationStatus::CheckingForUpdate,
        );

        let release = latest_github_release(
            "aptos-labs/move-vscode-extension",
            GithubReleaseOptions {
                require_assets: true,
                pre_release: false,
            },
        )
        .map_err(|e| format!("Failed to fetch latest release: {e}"))?;

        let (os, arch) = zed::current_platform();
        let (triple, file_type) = match (os, arch) {
            (zed::Os::Mac, zed::Architecture::Aarch64) => {
                ("aarch64-apple-darwin", DownloadedFileType::Gzip)
            }
            (zed::Os::Mac, zed::Architecture::X8664) => {
                ("x86_64-apple-darwin", DownloadedFileType::Gzip)
            }
            (zed::Os::Linux, zed::Architecture::X8664) => {
                ("x86_64-unknown-linux-gnu", DownloadedFileType::Gzip)
            }
            (zed::Os::Windows, zed::Architecture::X8664) => {
                ("x86_64-pc-windows-msvc", DownloadedFileType::Zip)
            }
            _ => {
                return Err(format!(
                    "Unsupported platform: {os:?} / {arch:?}. Install manually: \
                     cargo install --git https://github.com/aptos-labs/move-vscode-extension.git \
                     aptos-language-server"
                ))
            }
        };

        let asset_suffix = match file_type {
            DownloadedFileType::Zip => ".zip",
            _ => ".gz",
        };
        let asset_name = format!("aptos-language-server-{triple}{asset_suffix}");

        let asset = release
            .assets
            .iter()
            .find(|a| a.name == asset_name)
            .ok_or_else(|| {
                format!(
                    "No release asset found for {asset_name}. \
                     Install manually: cargo install --git \
                     https://github.com/aptos-labs/move-vscode-extension.git aptos-language-server"
                )
            })?;

        // Binary path includes version so different releases don't collide in the cache
        let binary_name = format!("aptos-language-server-{}", release.version);

        zed::set_language_server_installation_status(
            language_server_id,
            &LanguageServerInstallationStatus::Downloading,
        );

        download_file(&asset.download_url, &binary_name, file_type).map_err(|e| {
            format!(
                "Failed to download aptos-language-server: {e}. \
                 Install manually: cargo install --git \
                 https://github.com/aptos-labs/move-vscode-extension.git aptos-language-server"
            )
        })?;

        make_file_executable(&binary_name)?;

        zed::set_language_server_installation_status(
            language_server_id,
            &LanguageServerInstallationStatus::Downloaded,
        );

        self.cached_binary_path = Some(binary_name.clone());
        Ok(binary_name)
    }
}

impl zed::Extension for AptosMoveExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let binary = self.language_server_binary(language_server_id, worktree)?;

        Ok(zed::Command {
            command: binary,
            args: vec!["lsp-server".to_string()],
            env: Default::default(),
        })
    }
}

zed::register_extension!(AptosMoveExtension);
```

- [ ] **Step 4.2: Build and verify**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -10
```

Expected: `Finished release [optimized]`. No errors. Warnings about unused imports are OK if A5 isn't wired up yet.

- [ ] **Step 4.3: Commit**

```bash
git add src/lib.rs
git commit -m "feat(A0): auto-download aptos-language-server from GitHub Releases"
```

---

### Task 5: Add LSP initialization options and Aptos CLI env (A3 + A5)

Passes configuration to the server at startup. Also checks for the `aptos` CLI and passes its path in the server environment — used by Track B's test runner and prover commands.

**Files:**
- Modify: `src/lib.rs`

- [ ] **Step 5.1: Add `aptos_cli_path` field and `language_server_initialization_options` + `language_server_command` env to `src/lib.rs`**

Replace the `impl zed::Extension` block (keep `AptosMoveExtension` struct and `language_server_binary` helper as-is, only update the trait impl):

```rust
impl zed::Extension for AptosMoveExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let binary = self.language_server_binary(language_server_id, worktree)?;

        // Pass aptos CLI path so server can spawn it for tests and prover (Track B).
        // Server gracefully ignores this env var until B3/B5 land.
        let aptos_env = worktree
            .which("aptos")
            .map(|p| ("APTOS_CLI_PATH".to_string(), p))
            .into_iter()
            .collect();

        Ok(zed::Command {
            command: binary,
            args: vec!["lsp-server".to_string()],
            env: aptos_env,
        })
    }

    fn language_server_initialization_options(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<String>> {
        let aptos_available = worktree.which("aptos").is_some();

        let options = serde_json::json!({
            "inlayHints": {
                "typeHints": { "enable": true },
                "parameterHints": { "enable": true }
            },
            "diagnostics": {
                "disabled": []
            },
            "movefmt": {
                "path": null,
                "extraArgs": []
            },
            "aptosCliAvailable": aptos_available
        });

        Ok(Some(options.to_string()))
    }
}
```

- [ ] **Step 5.2: Add `serde_json` to `Cargo.toml`**

```toml
[dependencies]
zed_extension_api = "0.7.0"
serde_json = { version = "1", features = ["std"] }
```

- [ ] **Step 5.3: Add `use serde_json` to top of `src/lib.rs`**

The `use` block at the top of the file should now be:

```rust
use zed_extension_api::{
    self as zed,
    DownloadedFileType, GithubReleaseOptions, LanguageServerInstallationStatus, Result,
    download_file, latest_github_release, make_file_executable,
};
```

Note: `serde_json` is used via its full path (`serde_json::json!`) — no additional `use` needed.

- [ ] **Step 5.4: Build and verify**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -10
```

Expected: `Finished release [optimized]`.

- [ ] **Step 5.5: Commit**

```bash
git add src/lib.rs Cargo.toml
git commit -m "feat(A3+A5): add LSP init options and aptos CLI env passthrough"
```

---

### Task 6: Add Move.toml language definition (A4)

`Move.toml` gets syntax highlighting using Zed's built-in TOML grammar, plus semantic highlighting for Move-specific section names. Move.toml is added to the LSP's language list so completions (B4) work without further changes when the server supports them.

**Files:**
- Create: `languages/move-toml/config.toml`
- Create: `languages/move-toml/highlights.scm`
- Modify: `extension.toml`

- [ ] **Step 6.1: Create `languages/move-toml/config.toml`**

```toml
name = "Move.toml"
grammar = "toml"
path_suffixes = []
file_names = ["Move.toml"]
line_comments = ["# "]
```

Note: `path_suffixes = []` prevents matching all `.toml` files. `file_names = ["Move.toml"]` matches exactly the `Move.toml` filename. If Zed rejects `file_names` as an unknown field, the fallback is `path_suffixes = ["Move.toml"]` — this matches any file ending in `Move.toml`, which is close enough in practice.

- [ ] **Step 6.2: Create `languages/move-toml/highlights.scm`**

```scheme
; Inherit standard TOML highlighting by not overriding it.
; The TOML grammar highlights table headers, keys, strings, numbers, and booleans.
; We add semantic distinction for known Move.toml table names.

; Known Move.toml section headers get namespace highlighting
((table (bare_key) @namespace)
 (#match? @namespace "^(package|dependencies|dev-dependencies|addresses|dev-addresses)$"))

; Known dependency keys
((pair (bare_key) @property)
 (#match? @property "^(git|rev|subdir|local|addr)$"))

; Named address values (hex addresses) get constant.builtin
((string) @constant.builtin
 (#match? @constant.builtin "^\"0x[0-9a-fA-F]+\"$"))
```

- [ ] **Step 6.3: Add Move.toml to `extension.toml`**

Add the language entry and extend the LSP languages list:

```toml
[language_servers.aptos-move-lsp]
name = "Aptos Move Language Server"
languages = ["Move", "Move.toml"]
```

The language itself is automatically discovered from `languages/move-toml/config.toml` — no explicit `[languages]` entry needed in `extension.toml`.

- [ ] **Step 6.4: Verify the directory was created correctly**

```bash
ls languages/move-toml/
```

Expected output:
```
config.toml   highlights.scm
```

- [ ] **Step 6.5: Build and verify**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -5
```

Expected: `Finished release [optimized]`.

- [ ] **Step 6.6: Commit**

```bash
git add extension.toml languages/move-toml/
git commit -m "feat(A4): add Move.toml language definition with syntax highlighting"
```

---

### Task 7: Rebuild extension.wasm and verify Track A

Track A is now complete. Rebuild the wasm and do a smoke-test.

**Files:**
- Modify: `extension.wasm`

- [ ] **Step 7.1: Build final wasm**

```bash
cargo build --target wasm32-wasip1 --release
cp target/wasm32-wasip1/release/aptos_move_zed_extension.wasm extension.wasm
```

- [ ] **Step 7.2: Install the extension in Zed for manual testing**

In Zed: `Cmd+Shift+P` → `zed: install dev extension` → select this repo directory.

Open a `.move` file. Verify:
- Syntax highlighting works for functions, structs, modules, enums, constants, keywords
- Open `Move.toml` — verify table headers and keys are highlighted

Open a new project directory (no `aptos-language-server` in PATH if possible) and verify Zed shows a "Downloading" status indicator then starts the LSP.

- [ ] **Step 7.3: Commit wasm**

```bash
git add extension.wasm
git commit -m "build: rebuild extension.wasm with Track A features"
```

---

## Track B — aptos-language-server Changes

These tasks are in the `aptos-labs/move-vscode-extension` repo. Each task is a self-contained LSP capability addition. All changes are additive — existing VS Code behavior is preserved because LSP capabilities are negotiated at handshake time.

**Before starting Track B:** Identify where in the `aptos-language-server` source the following live:
- The completion handler (`textDocument/completion`)
- The code action handler (`textDocument/codeAction`)
- The server capability registration (where `ServerCapabilities` is built)
- The `workspace/executeCommand` handler

These tasks assume a typical rust-analyzer-derived LSP structure.

---

### Task 8: Auto-import completions (B1)

When a user accepts a completion for a symbol from an unimported module, the completion item includes `additionalTextEdits` inserting the correct `use` declaration.

**LSP repo files to modify:**
- Completion provider (wherever `CompletionItem` structs are built)
- Dependency: needs access to the current file's existing `use` declarations and the module's symbol index

- [ ] **Step 8.1: In the completion provider, collect existing use declarations for the current file**

For each completion item that refers to a symbol in a module not yet imported, add `additional_text_edits` that insert a `use <module_path>::<symbol>;` line. Insert position: after the last existing `use` declaration in the module, or at the start of the module body if none exist. Sort among existing uses alphabetically.

The edit should be a `TextEdit` with the insertion range set to the line after the last use statement:

```rust
// Pseudocode — adapt to actual LSP server types
fn make_use_edit(module_path: &str, symbol: &str, file: &ParsedFile) -> TextEdit {
    let insert_line = file.last_use_line().map(|l| l + 1).unwrap_or(file.module_body_start_line());
    TextEdit {
        range: Range {
            start: Position { line: insert_line, character: 0 },
            end: Position { line: insert_line, character: 0 },
        },
        new_text: format!("    use {}::{};\n", module_path, symbol),
    }
}
```

- [ ] **Step 8.2: Mark unimported completions distinctly**

In the `CompletionItem`, set `label_details.description` (or `detail`) to the module path so the user can see where the symbol comes from:

```rust
item.label_details = Some(CompletionItemLabelDetails {
    description: Some(module_path.to_string()),
    ..Default::default()
});
```

- [ ] **Step 8.3: Skip duplicate inserts**

Before adding the `additional_text_edits`, check if the module is already imported. If a `use module_path::symbol` or `use module_path::*` already exists in the file, omit the edit:

```rust
if file.has_use(module_path, symbol) {
    item.additional_text_edits = None;
}
```

- [ ] **Step 8.4: Test with a Move file that uses an unimported symbol**

Create a test file:
```move
module 0x1::test {
    fun example() {
        let t = Table::new();  // Table not imported
    }
}
```

Trigger completion on `Table`. Verify the completion item shows `aptos_std::table` in the description, and accepting it inserts `use aptos_std::table::Table;` at the top of the module.

- [ ] **Step 8.5: Commit in LSP repo**

```bash
git add -p
git commit -m "feat(B1): add additionalTextEdits for auto-import in completions"
```

---

### Task 9: Import organization code actions (B2)

Two code actions: `source.organizeImports` (sort + deduplicate) and `source.removeUnusedImports` (detect and remove unused).

**LSP repo files to modify:**
- Code action provider

- [ ] **Step 9.1: Implement `source.organizeImports`**

When the code action is requested:
1. Collect all `use` declarations from the module body.
2. Parse each into `(group, path)` where group is: `0=std`, `1=aptos_std`, `2=aptos_framework`, `3=local` (anything else).
3. Sort within each group alphabetically by full path.
4. Remove exact duplicates.
5. Return a `WorkspaceEdit` replacing the original use block with the sorted one.

```rust
// Group assignment
fn use_group(path: &str) -> u8 {
    if path.starts_with("std::") { 0 }
    else if path.starts_with("aptos_std::") { 1 }
    else if path.starts_with("aptos_framework::") { 2 }
    else { 3 }
}
```

Register the code action in `ServerCapabilities`:
```rust
code_action_provider: Some(CodeActionProviderCapability::Options(CodeActionOptions {
    code_action_kinds: Some(vec![
        CodeActionKind::SOURCE_ORGANIZE_IMPORTS,
        CodeActionKind::new("source.removeUnusedImports"),
    ]),
    ..Default::default()
})),
```

- [ ] **Step 9.2: Implement `source.removeUnusedImports`**

For each `use` declaration in the module:
1. Extract the set of symbols it brings into scope.
2. Scan the module body (excluding the `use` statements themselves) for references to those symbols.
3. If no references found, mark the `use` for removal.
4. Return a `WorkspaceEdit` deleting each unused `use` line.

- [ ] **Step 9.3: Test**

Create a test file:
```move
module 0x1::test {
    use aptos_framework::coin;
    use aptos_std::table;
    use std::string;

    fun example(): std::string::String {
        std::string::utf8(b"hello")
    }
}
```

Request code actions. Verify:
- `source.organizeImports` reorders to `std::string`, `aptos_std::table`, `aptos_framework::coin`.
- `source.removeUnusedImports` removes `aptos_std::table` and `aptos_framework::coin` (unused).

- [ ] **Step 9.4: Commit in LSP repo**

```bash
git commit -m "feat(B2): add organizeImports and removeUnusedImports code actions"
```

---

### Task 10: Test runner code lens (B3)

Displays a `▶ Run Test` lens above each `#[test]`-annotated function. On click, runs `aptos move test --filter <name>` and streams output via `$/progress`.

**LSP repo files to modify:**
- Server capability registration (enable `codeLensProvider`)
- Add code lens handler (`textDocument/codeLens`)
- Add command handler (`workspace/executeCommand` for `aptos-move.runTest`)

- [ ] **Step 10.1: Register code lens capability**

```rust
code_lens_provider: Some(CodeLensOptions {
    resolve_provider: Some(false),
}),
```

Also register the command:
```rust
execute_command_provider: Some(ExecuteCommandOptions {
    commands: vec!["aptos-move.runTest".to_string()],
    ..Default::default()
}),
```

- [ ] **Step 10.2: Implement `textDocument/codeLens` handler**

For the requested file, find all functions annotated with `#[test]` (not `#[test_only]`). For each:

```rust
CodeLens {
    range: function_name_range,
    command: Some(Command {
        title: "▶ Run Test".to_string(),
        command: "aptos-move.runTest".to_string(),
        arguments: Some(vec![serde_json::json!({
            "function": function_name,
            "file": file_path,
        })]),
    }),
    data: None,
}
```

- [ ] **Step 10.3: Implement `workspace/executeCommand` for `aptos-move.runTest`**

```rust
"aptos-move.runTest" => {
    let args = &params.arguments[0];
    let function_name = args["function"].as_str().unwrap();
    let file_path = args["file"].as_str().unwrap();

    // Find Move.toml by walking up from file_path
    let package_root = find_package_root(file_path)?;

    // Get aptos CLI path from the env var passed at startup
    let aptos_path = std::env::var("APTOS_CLI_PATH")
        .unwrap_or_else(|_| "aptos".to_string());

    // Stream output via $/progress
    let token = format!("run-test-{function_name}");
    client.send_notification::<lsp_types::notification::Progress>(ProgressParams {
        token: ProgressToken::String(token.clone()),
        value: ProgressParamsValue::WorkDone(WorkDoneProgress::Begin(WorkDoneProgressBegin {
            title: format!("Running {function_name}"),
            ..Default::default()
        })),
    });

    let output = std::process::Command::new(&aptos_path)
        .args(["move", "test", "--filter", function_name])
        .current_dir(&package_root)
        .output()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let passed = output.status.success();

    client.send_notification::<lsp_types::notification::Progress>(ProgressParams {
        token: ProgressToken::String(token),
        value: ProgressParamsValue::WorkDone(WorkDoneProgress::End(WorkDoneProgressEnd {
            message: Some(if passed {
                format!("✓ {function_name} passed")
            } else {
                format!("✗ {function_name} failed")
            }),
        })),
    });

    // Show full output in a message
    client.show_message(MessageType::INFO, stdout.to_string());
}
```

- [ ] **Step 10.4: Implement `find_package_root` helper**

```rust
fn find_package_root(file_path: &str) -> Result<std::path::PathBuf, String> {
    let mut dir = std::path::Path::new(file_path)
        .parent()
        .ok_or("file has no parent")?
        .to_path_buf();
    loop {
        if dir.join("Move.toml").exists() {
            return Ok(dir);
        }
        dir = dir.parent()
            .ok_or_else(|| format!("No Move.toml found above {file_path}"))?
            .to_path_buf();
    }
}
```

- [ ] **Step 10.5: Guard against missing aptos CLI**

At server startup, check if `APTOS_CLI_PATH` is set and points to a valid binary. If not, omit code lenses entirely rather than showing lenses that fail silently:

```rust
fn aptos_cli_available() -> bool {
    std::env::var("APTOS_CLI_PATH")
        .map(|p| std::path::Path::new(&p).exists())
        .unwrap_or(false)
        || which::which("aptos").is_ok()
}
```

In the code lens handler: `if !aptos_cli_available() { return Ok(vec![]); }`

- [ ] **Step 10.6: Test**

Open a `.move` file with a `#[test]` function. Verify the `▶ Run Test` lens appears. Click it. Verify:
- Zed shows a progress indicator.
- A message appears with pass/fail.
- No lens appears if `aptos` is not in PATH.

- [ ] **Step 10.7: Commit in LSP repo**

```bash
git commit -m "feat(B3): add test runner code lens for #[test] functions"
```

---

### Task 11: Move.toml smart completions (B4)

Registers `Move.toml` in the server's `documentSelector` and provides completions for `git`, `rev`, and `[addresses]` values.

**LSP repo files to modify:**
- Document selector / file type registration
- Completion provider (add a branch for `Move.toml` files)

**Zed extension side:** Already done in Task 6 (`extension.toml` lists `Move.toml` in LSP languages). No further Zed changes needed.

- [ ] **Step 11.1: Add `Move.toml` to the server's document selector**

In the server's initialization response, add the TOML file type:

```rust
document_selector: Some(vec![
    DocumentFilter {
        language: Some("move".to_string()),
        pattern: None,
        scheme: None,
    },
    DocumentFilter {
        language: None,
        pattern: Some("**/Move.toml".to_string()),
        scheme: None,
    },
]),
```

- [ ] **Step 11.2: Implement completions for `Move.toml` files**

In the completion handler, detect when the file being completed is a `Move.toml` and handle the three completion sites:

```rust
// Known framework git URLs
const FRAMEWORK_REPOS: &[(&str, &str)] = &[
    ("https://github.com/aptos-labs/aptos-core.git", "Aptos Core"),
    ("https://github.com/aptos-labs/aptos-framework.git", "Aptos Framework"),
];

// In the completion handler:
if file_name == "Move.toml" {
    return complete_move_toml(&params, &document_text);
}

fn complete_move_toml(params: &CompletionParams, text: &str) -> Vec<CompletionItem> {
    let line = get_current_line(text, params.text_document_position.position.line);
    
    if line.trim_start().starts_with("git") {
        return FRAMEWORK_REPOS.iter().map(|(url, label)| CompletionItem {
            label: label.to_string(),
            insert_text: Some(format!("\"{}\"", url)),
            kind: Some(CompletionItemKind::VALUE),
            ..Default::default()
        }).collect();
    }
    
    if line.trim_start().starts_with("rev") {
        // Fetch recent release tags from GitHub API
        // Cache the result for the session to avoid repeated network calls
        let tags = fetch_release_tags("aptos-labs/aptos-core").unwrap_or_default();
        return tags.iter().map(|tag| CompletionItem {
            label: tag.clone(),
            insert_text: Some(format!("\"{}\"", tag)),
            kind: Some(CompletionItemKind::VALUE),
            ..Default::default()
        }).collect();
    }
    
    if is_in_addresses_table(text, params.text_document_position.position.line) {
        return vec![CompletionItem {
            label: "0x...".to_string(),
            insert_text: Some("\"0x\"".to_string()),
            insert_text_format: Some(InsertTextFormat::PLAIN_TEXT),
            documentation: Some(Documentation::String(
                "Named address value (32-byte hex, e.g. 0x1)".to_string()
            )),
            kind: Some(CompletionItemKind::VALUE),
            ..Default::default()
        }];
    }
    
    vec![]
}
```

- [ ] **Step 11.3: Implement `fetch_release_tags` with session caching**

Use whatever HTTP client the LSP server already has (e.g., `reqwest`, `ureq`, or `tower-lsp`'s client). The endpoint is `https://api.github.com/repos/{repo}/releases?per_page=10` and returns a JSON array with `tag_name` fields.

```rust
use std::sync::OnceLock;

static CACHED_TAGS: OnceLock<Vec<String>> = OnceLock::new();

fn fetch_release_tags(repo: &str) -> Result<Vec<String>, String> {
    if let Some(tags) = CACHED_TAGS.get() {
        return Ok(tags.clone());
    }

    // Use whatever HTTP client is already imported in the server.
    // Example using reqwest (blocking):
    let url = format!("https://api.github.com/repos/{repo}/releases?per_page=10");
    let body: serde_json::Value = reqwest::blocking::Client::new()
        .get(&url)
        .header("User-Agent", "aptos-language-server")
        .send()
        .map_err(|e| e.to_string())?
        .json()
        .map_err(|e| e.to_string())?;

    let tags: Vec<String> = body
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|r| r["tag_name"].as_str().map(|s| s.to_string()))
        .collect();

    let _ = CACHED_TAGS.set(tags.clone());
    Ok(tags)
}
```

If the server uses `tower-lsp` and is `async`, replace `reqwest::blocking` with `reqwest::Client` and `.await`.

- [ ] **Step 11.4: Test**

Open `Move.toml`. In `[dependencies]`, type `git = ` and verify completions appear. Type `rev = ` and verify recent release tags appear.

- [ ] **Step 11.5: Commit in LSP repo**

```bash
git commit -m "feat(B4): add Move.toml completions for git, rev, and addresses"
```

---

### Task 12: Move Prover command (B5)

Registers `aptos-move.proveModule` as a workspace command. On execution, runs `aptos move prove` and surfaces failures as inline diagnostics.

**LSP repo files to modify:**
- Command registration (add `aptos-move.proveModule` to `executeCommandProvider`)
- `workspace/executeCommand` handler
- Diagnostic publisher

- [ ] **Step 12.1: Register the prover command**

```rust
execute_command_provider: Some(ExecuteCommandOptions {
    commands: vec![
        "aptos-move.runTest".to_string(),    // from B3
        "aptos-move.proveModule".to_string(), // new
    ],
    ..Default::default()
}),
```

- [ ] **Step 12.2: Implement `aptos-move.proveModule` handler**

```rust
"aptos-move.proveModule" => {
    let file_path = params.arguments[0].as_str()
        .ok_or("proveModule: missing file argument")?;

    let package_root = find_package_root(file_path)?; // reuse from B3

    if !aptos_cli_available() {
        client.show_message(
            MessageType::ERROR,
            "Move Prover requires the aptos CLI with boogie and z3. \
             See https://aptos.dev/tools/install-cli".to_string(),
        );
        return Ok(());
    }

    let aptos_path = std::env::var("APTOS_CLI_PATH")
        .unwrap_or_else(|_| "aptos".to_string());

    let token = "move-prover";
    client.send_notification::<lsp_types::notification::Progress>(ProgressParams {
        token: ProgressToken::String(token.to_string()),
        value: ProgressParamsValue::WorkDone(WorkDoneProgress::Begin(WorkDoneProgressBegin {
            title: "Running Move Prover".to_string(),
            cancellable: Some(false),
            ..Default::default()
        })),
    });

    let output = std::process::Command::new(&aptos_path)
        .args(["move", "prove"])
        .current_dir(&package_root)
        .output()
        .map_err(|e| format!("Failed to run aptos move prove: {e}"))?;

    let stderr = String::from_utf8_lossy(&output.stderr);
    let diagnostics = parse_prover_output(&stderr, &package_root);

    // Publish diagnostics per file
    for (uri, diags) in &diagnostics {
        client.publish_diagnostics(uri.clone(), diags.clone(), None);
    }

    client.send_notification::<lsp_types::notification::Progress>(ProgressParams {
        token: ProgressToken::String(token.to_string()),
        value: ProgressParamsValue::WorkDone(WorkDoneProgress::End(WorkDoneProgressEnd {
            message: Some(if output.status.success() {
                "Move Prover: all properties verified ✓".to_string()
            } else {
                format!("Move Prover: {} verification error(s)", diagnostics.values().map(|v| v.len()).sum::<usize>())
            }),
        })),
    });
}
```

- [ ] **Step 12.3: Implement `parse_prover_output`**

The Move Prover outputs errors in a format like:
```
error: post-condition does not hold
   --> sources/my_module.move:42:9
```

Parse lines matching `-->` to extract file path and line number, then create `Diagnostic` structs:

```rust
fn parse_prover_output(
    stderr: &str,
    package_root: &std::path::Path,
) -> std::collections::HashMap<lsp_types::Url, Vec<lsp_types::Diagnostic>> {
    let mut map: std::collections::HashMap<lsp_types::Url, Vec<lsp_types::Diagnostic>> =
        std::collections::HashMap::new();
    
    let mut current_message = String::new();
    for line in stderr.lines() {
        if line.starts_with("error:") || line.starts_with("warning:") {
            current_message = line.to_string();
        } else if let Some(rest) = line.trim().strip_prefix("-->") {
            // Format: " path/to/file.move:line:col"
            let parts: Vec<&str> = rest.trim().splitn(3, ':').collect();
            if parts.len() >= 2 {
                if let Ok(line_num) = parts[1].parse::<u32>() {
                    let file = package_root.join(parts[0]);
                    if let Ok(uri) = lsp_types::Url::from_file_path(&file) {
                        let diag = lsp_types::Diagnostic {
                            range: lsp_types::Range {
                                start: lsp_types::Position { line: line_num.saturating_sub(1), character: 0 },
                                end: lsp_types::Position { line: line_num.saturating_sub(1), character: u32::MAX },
                            },
                            severity: Some(lsp_types::DiagnosticSeverity::ERROR),
                            message: current_message.clone(),
                            source: Some("move-prover".to_string()),
                            ..Default::default()
                        };
                        map.entry(uri).or_default().push(diag);
                    }
                }
            }
        }
    }
    map
}
```

- [ ] **Step 12.4: Wire up command in Zed extension**

Back in the Zed extension repo. Check if `zed_extension_api` exposes command registration. If not, the command palette entry surfaces automatically when Zed sees the command in the LSP's `executeCommandProvider` capability — no extension-side registration needed. Verify by opening the command palette and searching `Move Prover`.

- [ ] **Step 12.5: Test**

Open a `.move` file with a spec block or function that should verify. Open command palette → `Move Prover`. Verify:
- Progress indicator appears.
- On failure, red underlines appear at the failing lines.
- On success, "all properties verified" message appears.
- If `aptos` CLI missing, a clear error message shows.

- [ ] **Step 12.6: Commit in LSP repo**

```bash
git commit -m "feat(B5): add Move Prover command with inline diagnostic output"
```

---

## Post-Track-B: Zed extension wiring cleanup

Once Track B is merged and a new `aptos-language-server` release is published:

- [ ] Update `A0` to prefer the new release by bumping the pinned version check (if any)
- [ ] Open a Zed upstream issue requesting `on_will_save` extension hook (enables on-save organize-imports in a future iteration)
- [ ] Open a Zed upstream issue requesting a Testing API (enables the test results sidebar panel)
- [ ] Bump `extension.toml` version from `0.0.1` to `0.1.0` and tag a release

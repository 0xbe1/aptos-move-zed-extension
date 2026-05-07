# Aptos Move Zed Extension — Full Feature Design

**Date:** 2026-05-07  
**Status:** Approved  

## Goal

Bring the Aptos Move Zed extension to feature parity with the VS Code Move on Aptos extension, prioritized around the highest-friction developer workflows: import management, formatting, test running, Move Prover, and Move.toml editing.

## Priority Order

1. Auto-import (auto-insert on completion + organize/remove unused)
2. Test runner (inline code lens + future panel)
3. Move Prover UI
4. Move.toml smart completions
5. Formatting configuration
6. All other LSP surface (inlay hints, diagnostics filtering)

## Phasing

### Track A — Zed extension only (no LSP changes)

Shippable immediately. No coordination with `aptos-language-server` required.

| # | Item |
|---|---|
| A0 | Binary auto-download |
| A1 | Grammar refresh |
| A2 | `zed_extension_api` upgrade |
| A3 | LSP initialization options wiring |
| A4 | Move.toml language definition (syntax only) |
| A5 | Aptos CLI presence check |

### Track B — Requires `aptos-language-server` changes

Each item is a self-contained LSP addition. Zed extension side is designed here so both land together.

| # | Item |
|---|---|
| B1 | Auto-import completions |
| B2 | Import organization (organizeImports + removeUnused) |
| B3 | Test runner code lens |
| B4 | Move.toml smart completions |
| B5 | Move Prover command |

---

## Architecture

### Repository boundary

```
aptos-move-zed-extension               aptos-labs/move-vscode-extension
────────────────────────               ────────────────────────────────
src/lib.rs                             aptos-language-server/
  launch + download binary       ───▶    completion provider (B1)
  pass initialization options            code action provider (B2)
  check aptos CLI                        code lens provider (B3)
  register prover command                Move.toml handler (B4)
                                         prover command handler (B5)
languages/
  move/          (existing)
  move-toml/     (new, A4)
```

### Two repos, clean split

- **Zed extension** owns: binary lifecycle, editor configuration surface, language definitions, command registration.
- **`aptos-language-server`** owns: all language intelligence (completions, code actions, code lenses, diagnostics, commands).
- LSP protocol is the interface. All Track B additions are additive LSP capabilities — they do not break VS Code.

---

## Detailed Feature Designs

### A0 — Binary Auto-Download

**Problem:** Extension silently fails if `aptos-language-server` is not in PATH. Users need Rust and `cargo install` to get started.

**Solution:** Use `zed_extension_api`'s `download_file` and `make_file_executable` to fetch a pre-built binary from GitHub Releases on first use and cache it.

**Prerequisite:** The `aptos-language-server` CI pipeline (in `aptos-labs/move-vscode-extension`) must publish platform-specific pre-built binaries to GitHub Releases before this can be implemented. Currently the only distribution path is `cargo install`. Adding release artifact publishing is a required prerequisite for A0.

**Implementation in `lib.rs`:**
- In `language_server_command()`, first check `worktree.which("aptos-language-server")` (respects user PATH override).
- If not found, resolve the latest release tag from `aptos-labs/move-vscode-extension` GitHub Releases via the GitHub API.
- Download the platform-appropriate binary (`aptos-language-server-{os}-{arch}`).
- Cache in the `zed_extension_api`-provided extension storage directory (do not hardcode a path).
- Make executable and return path.
- Surface a clear error message if download fails, including a fallback install instruction.

**Platform matrix:** `linux-x86_64`, `linux-aarch64`, `macos-x86_64`, `macos-aarch64`. Windows support follows Zed's own Windows availability.

---

### A1 — Grammar Refresh

**Problem:** Tree-sitter grammar pinned to `c820eb4716e` which may predate Move v2 features (enums, receiver functions).

**Solution:** Update `extension.toml` `[grammars.move_on_aptos]` rev to the latest commit on `aptos-labs/tree-sitter-move-on-aptos`.

**Also review `highlights.scm`** for any new node types introduced for Move v2 (e.g., `enum_declaration`, `receiver_function`) and add highlight rules.

---

### A2 — `zed_extension_api` Upgrade

Bump `Cargo.toml` from `zed_extension_api = "0.7.0"` to the current release. Resolve any API changes. Recompile `extension.wasm`.

---

### A3 — LSP Initialization Options

**Problem:** Extension passes no configuration to the server, relying on defaults. No way to configure inlay hints, diagnostics, movefmt path.

**Solution:** Implement `language_server_initialization_options()` in `lib.rs`, returning a JSON object.

**Initial options structure (mirrors VS Code `move-on-aptos.*` namespace):**

```json
{
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
  }
}
```

These match the server's existing configuration keys so VS Code and Zed behave consistently.

---

### A4 — Move.toml Language Definition

**Problem:** `Move.toml` files have no language support — no highlighting, no structure awareness.

**Solution:** Add `languages/move-toml/` with:
- `config.toml`: name `"Move.toml"`, grammar `"toml"` (built-in Zed TOML grammar), file association `Move.toml` exactly (not `*.toml`).
- `highlights.scm`: inherit TOML highlighting; add semantic highlights for known Move.toml sections (`[package]`, `[dependencies]`, `[addresses]`, `[dev-dependencies]`, `[dev-addresses]`).

Move.toml completions (B4) come later once the LSP handles the file type.

---

### A5 — Aptos CLI Presence Check

**Problem:** Test runner (B3) and Move Prover (B5) silently fail if `aptos` CLI is not installed.

**Solution:** In `language_server_command()`, after resolving the LSP binary, check `worktree.which("aptos")`. If absent, the extension returns an error from `language_server_command()` with a human-readable message:

```
Move: `aptos` CLI not found in PATH. Test runner and Move Prover will be unavailable.
Install from https://aptos.dev/tools/install-cli
```

This is handled entirely in the extension — no LSP changes needed. Zed surfaces it as a notification. When Track B lands, the absence flag can additionally be passed via initialization options so the server omits code lenses it cannot execute.

---

### B1 — Auto-Import Completions

**LSP changes required in `aptos-language-server`:**

When the user accepts a completion for a symbol not yet imported (e.g., `Table` from `aptos_std`), the completion item must include `additionalTextEdits` inserting the correct `use` statement at the top of the module, sorted among existing uses.

**Behavior:**
- Completions for unimported symbols are included in `textDocument/completion` responses, marked with a distinct label detail (e.g., `(use aptos_std::table)`).
- On accept, `additionalTextEdits` inserts the `use` statement in the correct position (after existing uses, before module body).
- Duplicate `use` statements are not inserted if the import already exists.

**Zed extension side:** No changes needed. Zed applies `additionalTextEdits` automatically.

---

### B2 — Import Organization

**LSP changes required:**

Two new code actions:

1. **`source.organizeImports`** — sorts `use` statements alphabetically within each group (std, aptos_std, aptos_framework, local), removes duplicates.
2. **`source.removeUnusedImports`** (or inline unused-import diagnostic with a remove fix) — detects `use` statements where no symbol from the import is referenced in the module body.

**Trigger in Zed:**
- Available as an explicit code action (⌘. or right-click → Code Actions).
- On-save trigger: `zed_extension_api` (as of 0.7.0) does not expose a save hook for extensions. On-save organize-imports is **not achievable** in the current API. Deliverable is manual command only. File a Zed upstream issue requesting a `on_will_save` extension hook.

---

### B3 — Test Runner Code Lens

**LSP changes required:**

Implement `textDocument/codeLens` to return a lens above each function annotated with `#[test]` (the attribute that marks an executable test function). `#[test_only]` marks code compiled only in test mode but is not itself a runnable test — no lens for those.

```
▶ Run Test
```

On click, Zed sends `codeLens/resolve` then `workspace/executeCommand` with:
```json
{
  "command": "aptos-move.runTest",
  "arguments": [{ "module": "my_module", "function": "test_foo", "file": "/path/to/file.move" }]
}
```

The LSP handler:
1. Resolves the package root (walks up from the file to find `Move.toml`).
2. Spawns `aptos move test --filter <function_name>` in the package root.
3. Streams output via `$/progress` notifications (token per test run).
4. Sends a final `window/showMessage` with pass/fail summary.

**Output display:** Zed surfaces `$/progress` in its activity indicator and output panel. No terminal window needed.

**Aptos CLI dependency:** Guarded by A5 check. If `aptos` is absent, the lens is omitted and the diagnostic from A5 explains why.

---

### B4 — Move.toml Smart Completions

**LSP changes required:**

Register the server to handle `Move.toml` files (add to `documentSelector` in server capabilities).

Provide `textDocument/completion` for:

| Location in Move.toml | Completions |
|---|---|
| `[dependencies]` values — `git =` | Known framework repos (aptos-core, aptos-framework) |
| `[dependencies]` values — `rev =` | Recent release tags fetched from GitHub API at completion time |
| `[addresses]` values | Valid address format hint + known named addresses |
| `[package]` — `name =` | No-op (free text) |

**Zed extension side:** `languages/move-toml/config.toml` already associates `Move.toml` to the LSP (via the language server's `languages` list in `extension.toml`). Add `"Move.toml"` to the `[language_servers.aptos-move-lsp]` languages array.

---

### B5 — Move Prover Command

**LSP changes required:**

Register a custom command `aptos-move.proveModule`:
1. Receives the current file path.
2. Resolves the package root.
3. Spawns `aptos move prove` (or scoped to a function if cursor is inside one).
4. Streams output via `$/progress`.
5. Surfaces verification failures as diagnostics (`textDocument/publishDiagnostics`) so they appear inline.

**Zed extension side:**
- Register the command in `lib.rs` via `zed::register_command` (if available in the target API version).
- Surfaces as a command palette entry: `Move: Run Move Prover on Current Module`.

**Aptos CLI + prover dependencies:** Guarded by A5. If `aptos move prove` is unavailable (boogie/z3 not installed), the server emits a `window/showMessage` with setup instructions rather than a silent failure.

---

## Constraints and Non-Goals

- **No test results panel (sidebar):** Zed's extension API has no Testing API equivalent. Code lens is the deliverable. File a Zed upstream issue for the panel.
- **No Aptos CLI integration beyond tests/prover:** Compile, publish, and deploy are out of scope for this iteration.
- **No Move.toml dependency installation:** Move.toml completions suggest values but do not run `aptos move update` or fetch packages.
- **`*.toml` not hijacked:** Only `Move.toml` exactly gets the Move.toml language definition. Other TOML files in the project are unaffected.
- **LSP changes must be additive:** All `aptos-language-server` additions must not break the VS Code extension. All new capabilities are negotiated via standard LSP capability advertisement.

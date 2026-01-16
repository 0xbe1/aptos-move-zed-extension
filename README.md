# Aptos Move Extension for Zed

Language support for Aptos Move in the Zed editor, including syntax highlighting and LSP integration.

## Features

- Syntax highlighting for Move language
- Language Server Protocol (LSP) integration with `aptos-language-server`
- Auto-completion, go-to-definition, and diagnostics
- Bracket matching and auto-indentation
- Support for Move-specific syntax (modules, structs, functions, specs, etc.)

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

## Project Structure

```
aptos-move-zed-extension/
├── extension.toml           # Extension metadata
├── Cargo.toml              # Rust dependencies
├── src/
│   └── lib.rs              # LSP integration code
└── languages/
    └── move/
        ├── config.toml      # Language configuration
        ├── highlights.scm   # Syntax highlighting rules
        ├── brackets.scm     # Bracket matching
        └── indents.scm      # Auto-indentation rules
```

## Development

### Prerequisites

- Rust toolchain (1.82+)
- `wasm32-wasip2` target: `rustup target add wasm32-wasip2`
- Zed editor

### Building

```bash
cargo build --target wasm32-wasip2 --release
cp target/wasm32-wasip2/release/aptos_move_zed_extension.wasm extension.wasm
```

### Testing

Open a Move project in Zed with the extension linked to test changes.

## Contributing

Contributions welcome! Please open issues or pull requests on GitHub.

## License

MIT

## Acknowledgments

- Tree-sitter grammar: [aptos-labs/tree-sitter-move-on-aptos](https://github.com/aptos-labs/tree-sitter-move-on-aptos)
- Language server: [aptos-labs/move-vscode-extension](https://github.com/aptos-labs/move-vscode-extension)

use zed_extension_api::{self as zed, Result};

struct AptosMoveExtension;

impl zed::Extension for AptosMoveExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        // Look for aptos-language-server in PATH
        let server_path = worktree
            .which("aptos-language-server")
            .ok_or_else(|| "aptos-language-server not found in PATH. Please install it with: cargo install --git https://github.com/aptos-labs/move-vscode-extension.git aptos-language-server")?;

        Ok(zed::Command {
            command: server_path,
            args: vec!["lsp-server".to_string()],
            env: Default::default(),
        })
    }
}

zed::register_extension!(AptosMoveExtension);

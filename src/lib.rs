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

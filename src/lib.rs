use zed_extension_api::{
    self as zed, download_file, latest_github_release, make_file_executable, DownloadedFileType,
    GithubReleaseOptions, LanguageServerInstallationStatus, Result,
};

struct AptosMoveExtension {
    cached_binary_path: Option<String>,
    aptos_cli_path: Option<String>,
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
            if std::fs::metadata(path)
                .map(|m| m.len() > 0)
                .unwrap_or(false)
            {
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

        make_file_executable(&binary_name).map_err(|e| {
            format!(
                "Failed to make aptos-language-server executable: {e}. \
                 Install manually: cargo install --git \
                 https://github.com/aptos-labs/move-vscode-extension.git aptos-language-server"
            )
        })?;

        zed::set_language_server_installation_status(
            language_server_id,
            &LanguageServerInstallationStatus::None,
        );

        self.cached_binary_path = Some(binary_name.clone());
        Ok(binary_name)
    }
}

impl zed::Extension for AptosMoveExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
            aptos_cli_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let binary = self.language_server_binary(language_server_id, worktree)?;

        self.aptos_cli_path = worktree.which("aptos");

        // Intentionally no error if aptos is absent — killing the LSP would remove all language
        // features. The aptosCliAvailable init option signals the server to skip code lenses
        // that require the CLI (B3 test runner, B5 prover).

        // Pass aptos CLI path so server can spawn it for tests and prover (Track B).
        // Server gracefully ignores this env var until B3/B5 land.
        let aptos_env = self
            .aptos_cli_path
            .iter()
            .map(|p| ("APTOS_CLI_PATH".to_string(), p.clone()))
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
        _worktree: &zed::Worktree,
    ) -> Result<Option<serde_json::Value>> {
        let aptos_available = self.aptos_cli_path.is_some();

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
            "completion": {
                "autoimport": { "enable": true }
            },
            "aptosCliAvailable": aptos_available
        });

        Ok(Some(options))
    }
}

zed::register_extension!(AptosMoveExtension);

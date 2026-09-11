use zed_extension_api::{
    self as zed, DebugAdapterBinary, DownloadedFileType, GithubReleaseOptions,
    LanguageServerInstallationStatus, Result, StartDebuggingRequestArguments,
    StartDebuggingRequestArgumentsRequest, download_file, latest_github_release,
    make_file_executable,
};

struct AptosMoveExtension {
    cached_binary_path: Option<String>,
    aptos_cli_path: Option<String>,
    cached_dap_path: Option<String>,
    cached_movefmt_path: Option<String>,
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
        if let Some(ref path) = self.cached_binary_path
            && std::fs::metadata(path)
                .map(|m| m.is_file())
                .unwrap_or(false)
        {
            return Ok(path.clone());
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
                ));
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

        // Download destination includes the version so different releases don't
        // collide in the cache. A .gz asset decompresses to the binary itself; a
        // .zip asset (Windows) extracts into a directory of this name, with the
        // executable inside it.
        let download_name = format!("aptos-language-server-{}", release.version);
        let binary_path = match file_type {
            DownloadedFileType::Zip => format!("{download_name}/aptos-language-server.exe"),
            _ => download_name.clone(),
        };

        zed::set_language_server_installation_status(
            language_server_id,
            &LanguageServerInstallationStatus::Downloading,
        );

        download_file(&asset.download_url, &download_name, file_type).map_err(|e| {
            format!(
                "Failed to download aptos-language-server: {e}. \
                 Install manually: cargo install --git \
                 https://github.com/aptos-labs/move-vscode-extension.git aptos-language-server"
            )
        })?;

        make_file_executable(&binary_path).map_err(|e| {
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

        self.cached_binary_path = Some(binary_path.clone());
        Ok(binary_path)
    }

    /// Resolve the `aptos-dap` debug adapter binary (Move test debugging and
    /// transaction replay). Resolution order: a path the user configured in
    /// Zed, a binary on PATH, a previously downloaded copy, then a download
    /// from the aptos-labs/aptos-debugger GitHub releases.
    fn dap_binary(
        &mut self,
        user_provided_path: Option<String>,
        worktree: &zed::Worktree,
    ) -> Result<String> {
        if let Some(path) = user_provided_path {
            return Ok(path);
        }

        if let Some(path) = worktree.which("aptos-dap") {
            return Ok(path);
        }

        if let Some(ref path) = self.cached_dap_path
            && std::fs::metadata(path)
                .map(|m| m.is_file())
                .unwrap_or(false)
        {
            return Ok(path.clone());
        }

        let release = latest_github_release(
            "aptos-labs/aptos-debugger",
            GithubReleaseOptions {
                require_assets: true,
                pre_release: false,
            },
        )
        .map_err(|e| format!("Failed to fetch latest aptos-dap release: {e}"))?;

        let (os, arch) = zed::current_platform();
        let asset_name = match (os, arch) {
            (zed::Os::Mac, zed::Architecture::Aarch64) => "aptos-dap-darwin-arm64.gz",
            (zed::Os::Mac, zed::Architecture::X8664) => "aptos-dap-darwin-x64.gz",
            (zed::Os::Linux, zed::Architecture::X8664) => "aptos-dap-linux-x64.gz",
            _ => {
                return Err(format!(
                    "aptos-dap has no prebuilt binary for {os:?}/{arch:?}. \
                     Build it from source with: cargo install --git \
                     https://github.com/aptos-labs/aptos-debugger"
                ));
            }
        };

        let asset = release
            .assets
            .iter()
            .find(|a| a.name == asset_name)
            .ok_or_else(|| format!("No release asset found for {asset_name}"))?;

        // Versioned name so different releases don't collide in the cache
        let binary_name = format!("aptos-dap-{}", release.version);

        download_file(&asset.download_url, &binary_name, DownloadedFileType::Gzip)
            .map_err(|e| format!("Failed to download aptos-dap: {e}"))?;

        make_file_executable(&binary_name)
            .map_err(|e| format!("Failed to make aptos-dap executable: {e}"))?;

        self.cached_dap_path = Some(binary_name.clone());
        Ok(binary_name)
    }

    /// Resolve the `movefmt` formatter binary: PATH > previously downloaded
    /// copy > download from the aptos-labs/movefmt GitHub releases. movefmt
    /// backs the language server's textDocument/formatting (which requires
    /// movefmt >= 1.2.1).
    fn movefmt_binary(&mut self, worktree: &zed::Worktree) -> Result<String> {
        if let Some(path) = worktree.which("movefmt") {
            return Ok(path);
        }

        if let Some(ref path) = self.cached_movefmt_path
            && std::fs::metadata(path)
                .map(|m| m.is_file())
                .unwrap_or(false)
        {
            return Ok(path.clone());
        }

        let release = latest_github_release(
            "aptos-labs/movefmt",
            GithubReleaseOptions {
                require_assets: true,
                pre_release: false,
            },
        )
        .map_err(|e| format!("Failed to fetch latest movefmt release: {e}"))?;

        let (os, arch) = zed::current_platform();
        let triple = match (os, arch) {
            (zed::Os::Mac, zed::Architecture::Aarch64) => "aarch64-apple-darwin",
            (zed::Os::Mac, zed::Architecture::X8664) => "x86_64-apple-darwin",
            (zed::Os::Linux, zed::Architecture::Aarch64) => "aarch64-unknown-linux-gnu",
            (zed::Os::Linux, zed::Architecture::X8664) => "x86_64-unknown-linux-gnu",
            (zed::Os::Windows, zed::Architecture::X8664) => "x86_64-windows.exe",
            _ => {
                return Err(format!(
                    "movefmt has no prebuilt binary for {os:?}/{arch:?}. \
                     Install it with: aptos update movefmt (or cargo install --git \
                     https://github.com/aptos-labs/movefmt --branch develop movefmt)"
                ));
            }
        };

        // Asset names embed the release version (movefmt-v1.5.3-<triple>), so
        // match on the stable prefix/suffix rather than reconstructing it.
        let asset = release
            .assets
            .iter()
            .find(|a| a.name.starts_with("movefmt-v") && a.name.ends_with(triple))
            .ok_or_else(|| format!("No movefmt release asset found for {triple}"))?;

        // Versioned name so different releases don't collide in the cache
        let binary_name = format!("movefmt-{}", release.version);

        download_file(
            &asset.download_url,
            &binary_name,
            DownloadedFileType::Uncompressed,
        )
        .map_err(|e| format!("Failed to download movefmt: {e}"))?;

        make_file_executable(&binary_name)
            .map_err(|e| format!("Failed to make movefmt executable: {e}"))?;

        self.cached_movefmt_path = Some(binary_name.clone());
        Ok(binary_name)
    }
}

impl zed::Extension for AptosMoveExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
            aptos_cli_path: None,
            cached_dap_path: None,
            cached_movefmt_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let binary = self.language_server_binary(language_server_id, worktree)?;

        // Remember the aptos CLI path (if any); it is passed to the server as the
        // `aptosPath` initialization option in
        // `language_server_initialization_options` below, which is the server's
        // supported way to locate the CLI. Intentionally no error if aptos is
        // absent — killing the LSP would remove all language features. Running
        // tests, coverage, and the prover from Zed goes through tasks
        // (see templates/tasks.json), which invoke `aptos` directly from PATH.
        self.aptos_cli_path = worktree.which("aptos");

        Ok(zed::Command {
            command: binary,
            args: vec!["lsp-server".to_string()],
            env: vec![],
        })
    }

    fn language_server_initialization_options(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<serde_json::Value>> {
        // Resolve movefmt up front so `editor: format` and format-on-save work
        // without manual setup. On failure, fall back to null — formatting
        // stays disabled but every other feature (and server startup itself)
        // is unaffected.
        let movefmt_path = self.movefmt_binary(worktree).ok();
        // Mirrors the `move-on-aptos.*` settings object the server parses — see
        // `crates/aptos-language-server/src/config/options.rs` in
        // aptos-labs/move-vscode-extension. `aptosPath` (null when the CLI was not
        // found) is the server's supported way to locate the aptos CLI; when null
        // the server falls back to `which aptos` on its own. Keys left unset here
        // keep the server's documented defaults (diagnostics, movefmt, DAP paths).
        let options = serde_json::json!({
            "aptosPath": self.aptos_cli_path,
            "lens": {
                "enable": true,
                "run": { "enable": true }
            },
            "inlayHints": {
                "typeHints": { "enable": true },
                "parameterHints": { "enable": true }
            },
            "completion": {
                "autoimport": { "enable": true }
            },
            "movefmt": {
                "path": movefmt_path,
                "extraArgs": []
            },
            // Extra args appended to `aptos move test` / `aptos move prove` when
            // the server builds runnable commands (e.g. "--override-std",
            // "--shards 4"). Empty arrays match the server defaults.
            "tests": { "extraArgs": [] },
            "prover": { "extraArgs": [] }
        });

        Ok(Some(options))
    }

    fn dap_request_kind(
        &mut self,
        _adapter_name: String,
        _config: serde_json::Value,
    ) -> Result<zed::StartDebuggingRequestArgumentsRequest> {
        // aptos-dap only implements DAP `launch` sessions (no attach).
        Ok(zed::StartDebuggingRequestArgumentsRequest::Launch)
    }

    fn get_dap_binary(
        &mut self,
        adapter_name: String,
        config: zed::DebugTaskDefinition,
        user_provided_debug_adapter_path: Option<String>,
        worktree: &zed::Worktree,
    ) -> Result<zed::DebugAdapterBinary> {
        let binary = self.dap_binary(user_provided_debug_adapter_path, worktree)?;

        let debug_config: serde_json::Value = serde_json::from_str(&config.config)
            .map_err(|e| format!("Invalid debug configuration JSON: {e}"))?;

        // Mirrors the VS Code extension's default
        // (`move-on-aptos.dap.extraArgs`).
        let extra_args: Vec<String> = match debug_config.get("extraArgs") {
            Some(serde_json::Value::Array(items)) => items
                .iter()
                .filter_map(|v| v.as_str().map(str::to_string))
                .collect(),
            _ => vec!["--skip-fetch-latest-git-deps".to_string()],
        };

        // Field names follow the VS Code extension's launch configuration
        // schema (editors/code/package.json in move-vscode-extension).
        let (arguments, cwd) = match adapter_name.as_str() {
            "aptos-move-test" | "Aptos Move Test" => {
                let mut args = vec!["test".to_string()];
                if let Some(filter) = debug_config.get("testFilter").and_then(|v| v.as_str()) {
                    args.push("--filter".to_string());
                    args.push(filter.to_string());
                }
                let package_path = debug_config
                    .get("packagePath")
                    .and_then(|v| v.as_str())
                    .map(str::to_string);
                if let Some(ref path) = package_path {
                    args.push("--package-path".to_string());
                    args.push(path.clone());
                }
                args.extend(extra_args);
                (args, package_path)
            }
            "aptos-move-replay" | "Aptos Move Replay" => {
                let mut args = vec!["replay".to_string()];
                let txn_id = debug_config
                    .get("txnId")
                    .and_then(|v| v.as_str())
                    .ok_or("Transaction replay requires a `txnId` field")?;
                args.push("--txn-id".to_string());
                args.push(txn_id.to_string());
                let network = debug_config
                    .get("network")
                    .and_then(|v| v.as_str())
                    .ok_or("Transaction replay requires a `network` field")?;
                args.push("--network".to_string());
                args.push(network.to_string());
                if let Some(packages) = debug_config
                    .get("useLocalPackages")
                    .and_then(|v| v.as_array())
                {
                    for package in packages.iter().filter_map(|v| v.as_str()) {
                        args.push("--use-local-package".to_string());
                        args.push(package.to_string());
                    }
                }
                if let Some(addresses) = debug_config.get("namedAddresses") {
                    match addresses {
                        serde_json::Value::Object(map) => {
                            for (name, address) in map {
                                if let Some(address) = address.as_str() {
                                    args.push("--named-address".to_string());
                                    args.push(format!("{name}={address}"));
                                }
                            }
                        }
                        serde_json::Value::Array(items) => {
                            for item in items.iter().filter_map(|v| v.as_str()) {
                                args.push("--named-address".to_string());
                                args.push(item.to_string());
                            }
                        }
                        _ => {}
                    }
                }
                args.extend(extra_args);
                (args, None)
            }
            other => return Err(format!("Unknown debug adapter: {other}")),
        };

        let envs = match debug_config.get("env").and_then(|v| v.as_object()) {
            Some(map) => map
                .iter()
                .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                .collect(),
            None => Vec::new(),
        };

        // Without a `--port` argument aptos-dap speaks DAP over stdio, which is
        // the transport Zed uses when no `connection` is specified.
        Ok(DebugAdapterBinary {
            command: Some(binary),
            arguments,
            envs,
            cwd,
            connection: None,
            request_args: StartDebuggingRequestArguments {
                configuration: config.config,
                request: StartDebuggingRequestArgumentsRequest::Launch,
            },
        })
    }
}

zed::register_extension!(AptosMoveExtension);

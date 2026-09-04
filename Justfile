default: build

build:
	cargo build --target wasm32-wasip2 --release

check:
	cargo check --target wasm32-wasip2

fmt:
	cargo fmt

fmt-check:
	cargo fmt --check

clippy:
	cargo clippy --target wasm32-wasip2 -- -D warnings

# Tests run on the native target: the extension compiles to a cdylib for the
# wasm32-wasip2 host, but unit tests execute natively.
test:
	cargo test

# Validate language queries and fixtures against the grammars pinned in
# extension.toml. Requires tree-sitter CLI (npm install -g tree-sitter-cli).
test-queries:
	./scripts/validate-queries.sh

clean:
	cargo clean

ci:
	cargo fmt --check
	cargo clippy --locked --target wasm32-wasip2 -- -D warnings
	cargo test --locked
	cargo build --locked --target wasm32-wasip2 --release
	./scripts/validate-queries.sh

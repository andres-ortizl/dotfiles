use std::process::Command;

#[test]
fn binary_does_not_require_web_api_config_before_starting_the_tui() {
    let output = Command::new(env!("CARGO_BIN_EXE_soloist-tui"))
        .args([
            "--config",
            "/tmp/soloist-tui-cli-config-that-does-not-exist.toml",
        ])
        .output()
        .unwrap();
    let stderr = String::from_utf8_lossy(&output.stderr);

    assert!(!stderr.contains("configuration not found"));
    assert!(stderr.contains("failed to enable terminal raw mode"));
}

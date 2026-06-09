fn sq_escape(s: &str) -> String {
    s.replace('\'', "'\\''")
}

pub fn attach_argv(
    program: &str,
    mux: Option<&str>,
    session: &str,
    worktree: Option<&str>,
    session_id: Option<&str>,
) -> Vec<String> {
    let fallback_chain = match session_id {
        Some(id) => format!(
            "claude --resume '{}' || claude --continue || exec \"$SHELL\"",
            sq_escape(id)
        ),
        None => "claude --continue || exec \"$SHELL\"".to_string(),
    };

    let script = match mux {
        Some("tmux") => {
            let cwd = worktree
                .map(|wt| format!(" -c '{}'", sq_escape(wt)))
                .unwrap_or_default();
            format!(
                "exec tmux new-session -A -s '{}'{} '{}'",
                sq_escape(session),
                cwd,
                sq_escape(&fallback_chain)
            )
        }
        Some("zellij") => {
            let cwd = worktree
                .map(|wt| format!(" --cwd '{}'", sq_escape(wt)))
                .unwrap_or_default();
            let s = sq_escape(session);
            format!(
                "zellij attach '{s}' 2>/dev/null || {{ zellij attach -b -c '{s}' && zellij --session '{s}' run{cwd} -- /bin/sh -c '{}' && exec zellij attach '{s}'; }}",
                sq_escape(&fallback_chain)
            )
        }
        _ => {
            let cd = worktree
                .map(|wt| format!("cd '{}' && ", sq_escape(wt)))
                .unwrap_or_default();
            format!("{}{}", cd, fallback_chain)
        }
    };

    if program == "ghostty" {
        vec![
            "open".to_string(),
            "-na".to_string(),
            "Ghostty".to_string(),
            "--args".to_string(),
            "-e".to_string(),
            "/bin/sh".to_string(),
            "-lc".to_string(),
            script,
        ]
    } else {
        vec![
            program.to_string(),
            "-e".to_string(),
            "/bin/sh".to_string(),
            "-lc".to_string(),
            script,
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ---- tmux ----

    #[test]
    fn tmux_attach_or_create_with_session_id() {
        let argv = attach_argv("ghostty", Some("tmux"), "spec-feat", Some("/wt/path"), Some("abc123"));
        assert_eq!(argv[..4], ["open", "-na", "Ghostty", "--args"]);
        assert_eq!(argv[4..7], ["-e", "/bin/sh", "-lc"]);
        assert_eq!(argv[7], "exec tmux new-session -A -s 'spec-feat' -c '/wt/path' 'claude --resume '\\''abc123'\\'' || claude --continue || exec \"$SHELL\"'");
        assert!(argv[7].contains("|| exec \"$SHELL\""), "tmux command must fall back to shell");
    }

    #[test]
    fn tmux_attach_or_create_no_session_id() {
        let argv = attach_argv("ghostty", Some("tmux"), "spec-feat", Some("/wt/path"), None);
        assert_eq!(argv[7], "exec tmux new-session -A -s 'spec-feat' -c '/wt/path' 'claude --continue || exec \"$SHELL\"'");
        assert!(argv[7].contains("|| exec \"$SHELL\""), "tmux command must fall back to shell");
    }

    #[test]
    fn tmux_no_worktree() {
        let argv = attach_argv("ghostty", Some("tmux"), "spec-feat", None, None);
        assert_eq!(argv[7], "exec tmux new-session -A -s 'spec-feat' 'claude --continue || exec \"$SHELL\"'");
        assert!(argv[7].contains("|| exec \"$SHELL\""), "tmux command must fall back to shell");
    }

    // ---- zellij ----

    #[test]
    fn zellij_attach_or_create_with_session_id() {
        let argv = attach_argv("ghostty", Some("zellij"), "spec-feat", Some("/wt/path"), Some("abc123"));
        let script = &argv[7];
        // attach branch: no second claude on existing session
        assert!(script.starts_with("zellij attach 'spec-feat' 2>/dev/null || "),
            "script should start with attach branch: {script}");
        // create branch: (1) create background session
        assert!(script.contains("zellij attach -b -c 'spec-feat'"),
            "script should create background session: {script}");
        // create branch: (2) run claude via /bin/sh -c so || fallback parses
        assert!(script.contains("zellij --session 'spec-feat' run"),
            "script should run claude in created session: {script}");
        assert!(script.contains("/bin/sh -c '"),
            "zellij run must wrap command in /bin/sh -c so || fallback parses: {script}");
        assert!(script.contains("claude --resume '\\''abc123'\\''"),
            "script should resume with session id (sq-escaped): {script}");
        // fallback present inside the /bin/sh -c payload
        assert!(script.contains("|| exec \"$SHELL\""),
            "script must fall back to shell: {script}");
        // create branch: (3) attach so user sees the session
        assert!(script.contains("exec zellij attach 'spec-feat'"),
            "script should attach after create: {script}");
    }

    #[test]
    fn zellij_no_session_id_uses_continue() {
        let argv = attach_argv("ghostty", Some("zellij"), "spec-feat", Some("/wt/path"), None);
        let script = &argv[7];
        assert!(script.contains("claude --continue"), "script should use --continue: {script}");
        assert!(!script.contains("--resume"), "script should not contain --resume: {script}");
        assert!(script.contains("|| exec \"$SHELL\""), "script must fall back to shell: {script}");
        assert!(script.contains("/bin/sh -c '"), "zellij run must wrap in /bin/sh -c: {script}");
    }

    #[test]
    fn zellij_with_worktree_uses_cwd_flag() {
        let argv = attach_argv("ghostty", Some("zellij"), "spec-feat", Some("/wt/path"), Some("id1"));
        let script = &argv[7];
        assert!(script.contains("--cwd '/wt/path'"), "script should set --cwd: {script}");
        assert!(script.contains("|| exec \"$SHELL\""), "script must fall back to shell: {script}");
    }

    #[test]
    fn zellij_no_worktree() {
        let argv = attach_argv("ghostty", Some("zellij"), "spec-feat", None, Some("id1"));
        let script = &argv[7];
        assert!(!script.contains("--cwd"), "no --cwd when worktree is None: {script}");
        assert!(script.contains("|| exec \"$SHELL\""), "script must fall back to shell: {script}");
    }

    // ---- no mux ----

    #[test]
    fn no_mux_with_session_id_falls_back_to_shell() {
        let argv = attach_argv("ghostty", None, "spec-feat", Some("/wt/path"), Some("id1"));
        assert_eq!(argv[7], "cd '/wt/path' && claude --resume 'id1' || claude --continue || exec \"$SHELL\"");
        assert!(argv[7].contains("|| exec \"$SHELL\""), "no-mux must fall back to shell");
    }

    #[test]
    fn no_mux_no_session_id_uses_continue() {
        let argv = attach_argv("ghostty", None, "spec-feat", Some("/wt/path"), None);
        assert_eq!(argv[7], "cd '/wt/path' && claude --continue || exec \"$SHELL\"");
        assert!(argv[7].contains("|| exec \"$SHELL\""), "no-mux must fall back to shell");
    }

    #[test]
    fn no_mux_no_worktree_no_session_id() {
        let argv = attach_argv("ghostty", None, "spec-feat", None, None);
        assert_eq!(argv[7], "claude --continue || exec \"$SHELL\"");
        assert!(argv[7].contains("|| exec \"$SHELL\""), "no-mux must fall back to shell");
    }

    // ---- other programs ----

    #[test]
    fn other_program_zellij() {
        let argv = attach_argv("alacritty", Some("zellij"), "spec-feat", Some("/wt"), Some("id1"));
        assert_eq!(argv[0], "alacritty");
        assert_eq!(argv[1..3], ["-e", "/bin/sh"]);
        assert_eq!(argv[3], "-lc");
        assert!(argv[4].contains("zellij attach 'spec-feat'"));
        assert!(argv[4].contains("|| exec \"$SHELL\""), "zellij command must fall back to shell");
    }

    #[test]
    fn other_program_tmux() {
        let argv = attach_argv("wezterm", Some("tmux"), "spec-feat", None, None);
        assert_eq!(argv[0], "wezterm");
        assert_eq!(argv[4], "exec tmux new-session -A -s 'spec-feat' 'claude --continue || exec \"$SHELL\"'");
        assert!(argv[4].contains("|| exec \"$SHELL\""), "tmux command must fall back to shell");
    }

    // ---- escaping ----

    #[test]
    fn single_quote_in_worktree_is_escaped() {
        let argv = attach_argv(
            "ghostty",
            Some("zellij"),
            "spec-feat",
            Some("/path/it's here"),
            None,
        );
        assert!(argv[7].contains("--cwd '/path/it'\\''s here'"),
            "worktree single quote should be escaped: {}", argv[7]);
        assert!(argv[7].contains("|| exec \"$SHELL\""),
            "script must fall back to shell: {}", argv[7]);
    }

    #[test]
    fn single_quote_in_session_id_is_escaped() {
        let argv = attach_argv("ghostty", None, "spec-feat", None, Some("it's"));
        assert_eq!(argv[7], "claude --resume 'it'\\''s' || claude --continue || exec \"$SHELL\"");
        assert!(argv[7].contains("|| exec \"$SHELL\""), "no-mux must fall back to shell");
    }
}

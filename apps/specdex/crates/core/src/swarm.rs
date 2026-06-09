// NOTE: This module depends on Claude Code experimental teams internals:
//   - tmux sockets at /tmp/tmux-<uid>/claude-swarm-<pid>
//   - session named "claude-swarm" inside the socket
//   - teammate processes have --parent-session-id <CLAUDE_CODE_SESSION_ID> in their argv
// If these internals change, all functions degrade gracefully (return None / empty).

use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;

/// True if `name` is a claude-swarm tmux socket filename (e.g. "claude-swarm-12345").
pub fn is_swarm_socket_name(name: &str) -> bool {
    name.starts_with("claude-swarm-")
}

/// True if `argv` (the full command-line string for a process) contains
/// `--parent-session-id <session_id>` as an argument (word-boundary match).
pub fn argv_contains_parent_session(argv: &str, session_id: &str) -> bool {
    let needle = format!("--parent-session-id {}", session_id);
    if let Some(pos) = argv.find(&needle) {
        let after = &argv[pos + needle.len()..];
        after.is_empty() || after.starts_with(' ') || after.starts_with('\0')
    } else {
        false
    }
}

/// True if the process subtree rooted at `root_pid` contains any process whose argv
/// has `--parent-session-id <session_id>`. `process_table` maps pid → (ppid, args).
pub fn pid_subtree_has_session(
    process_table: &HashMap<u32, (u32, String)>,
    root_pid: u32,
    session_id: &str,
) -> bool {
    if let Some((_, argv)) = process_table.get(&root_pid) {
        if argv_contains_parent_session(argv, session_id) {
            return true;
        }
    }
    for (&pid, (ppid, _)) in process_table {
        if *ppid == root_pid && pid != root_pid {
            if pid_subtree_has_session(process_table, pid, session_id) {
                return true;
            }
        }
    }
    false
}

/// Build a process table from `ps -axo pid=,ppid=,args=`.
/// Returns empty map on any failure; callers degrade gracefully.
fn build_process_table() -> HashMap<u32, (u32, String)> {
    let out = match Command::new("ps").args(["-axo", "pid=,ppid=,args="]).output() {
        Ok(o) if o.status.success() => o,
        _ => return HashMap::new(),
    };
    let text = String::from_utf8_lossy(&out.stdout);
    let mut table = HashMap::new();
    for line in text.lines() {
        let line = line.trim_start();
        if line.is_empty() {
            continue;
        }
        let Some((pid_str, rest)) = line.split_once(char::is_whitespace) else {
            continue;
        };
        let rest = rest.trim_start();
        let Some((ppid_str, args)) = rest.split_once(char::is_whitespace) else {
            continue;
        };
        let Ok(pid) = pid_str.parse::<u32>() else { continue };
        let Ok(ppid) = ppid_str.parse::<u32>() else { continue };
        table.insert(pid, (ppid, args.trim_start().to_string()));
    }
    table
}

#[derive(Debug, Clone)]
pub struct PaneContent {
    pub title: String,
    pub text: String,
}

#[derive(Debug, Clone)]
pub struct TeamPanesResult {
    pub socket_name: Option<String>,
    pub panes: Vec<PaneContent>,
}

/// Read all pane contents for the team associated with `session_id`.
/// Returns empty when teams are off, no socket matches, or any I/O fails.
pub fn read_team_panes(session_id: &str) -> TeamPanesResult {
    let Some((socket_name, raw_panes)) = find_socket_for_session(session_id) else {
        return TeamPanesResult { socket_name: None, panes: vec![] };
    };

    let panes = raw_panes
        .into_iter()
        .filter_map(|(pane_id, title)| {
            let text = capture_pane(&socket_name, &pane_id)?;
            Some(PaneContent { title, text })
        })
        .collect();

    TeamPanesResult { socket_name: Some(socket_name), panes }
}

/// argv to open a read-only attach to the swarm socket in the configured terminal.
pub fn watch_team_argv(program: &str, socket_name: &str) -> Vec<String> {
    let safe = socket_name.replace('\'', "'\\''");
    let script = format!("exec tmux -L '{}' attach -r", safe);
    if program == "ghostty" {
        vec![
            "open".into(), "-na".into(), "Ghostty".into(), "--args".into(),
            "-e".into(), "/bin/sh".into(), "-lc".into(), script,
        ]
    } else {
        vec![program.into(), "-e".into(), "/bin/sh".into(), "-lc".into(), script]
    }
}

/// Find the swarm socket name for `session_id` without capturing pane content.
/// Use this when you only need the socket name (e.g. the "watch team" button).
pub fn find_swarm_socket(session_id: &str) -> Option<String> {
    find_socket_for_session(session_id).map(|(name, _)| name)
}

fn find_socket_for_session(session_id: &str) -> Option<(String, Vec<(String, String)>)> {
    for socket_path in list_swarm_sockets() {
        let socket_name = socket_path.file_name()?.to_str()?.to_string();
        if let Some(panes) = match_panes_for_session(&socket_name, session_id) {
            if !panes.is_empty() {
                return Some((socket_name, panes));
            }
        }
    }
    None
}

fn list_swarm_sockets() -> Vec<PathBuf> {
    let Ok(tmp_entries) = std::fs::read_dir("/tmp") else {
        return vec![];
    };
    let mut sockets = vec![];
    for dir_entry in tmp_entries.flatten() {
        let path = dir_entry.path();
        if !path.is_dir() {
            continue;
        }
        let dir_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
        if !dir_name.starts_with("tmux-") {
            continue;
        }
        let Ok(sock_entries) = std::fs::read_dir(&path) else {
            continue;
        };
        for sock in sock_entries.flatten() {
            let name = sock.file_name().to_string_lossy().into_owned();
            if is_swarm_socket_name(&name) {
                sockets.push(sock.path());
            }
        }
    }
    sockets
}

fn match_panes_for_session(socket_name: &str, session_id: &str) -> Option<Vec<(String, String)>> {
    let out = Command::new("tmux")
        .args(["-L", socket_name, "list-panes", "-a", "-F", "#{pane_id}\t#{pane_title}\t#{pane_pid}"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let process_table = build_process_table();
    let text = String::from_utf8_lossy(&out.stdout);
    let mut matched = vec![];
    for line in text.lines() {
        let parts: Vec<&str> = line.splitn(3, '\t').collect();
        if parts.len() < 3 {
            continue;
        }
        let (pane_id, title, pid_str) = (parts[0], parts[1], parts[2]);
        let Ok(pane_pid) = pid_str.trim().parse::<u32>() else {
            continue;
        };
        if pid_subtree_has_session(&process_table, pane_pid, session_id) {
            matched.push((pane_id.to_string(), title.to_string()));
        }
    }
    Some(matched)
}

fn capture_pane(socket_name: &str, pane_id: &str) -> Option<String> {
    // -e keeps the ANSI escape sequences so the UI can recolor the live pane
    // (Catppuccin palette). Without it, capture-pane strips all color.
    let out = Command::new("tmux")
        .args(["-L", socket_name, "capture-pane", "-e", "-p", "-t", pane_id])
        .output()
        .ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).to_string())
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn is_swarm_socket_name_matches_pattern() {
        assert!(is_swarm_socket_name("claude-swarm-12345"));
        assert!(is_swarm_socket_name("claude-swarm-0"));
        assert!(is_swarm_socket_name("claude-swarm-999999"));
    }

    #[test]
    fn is_swarm_socket_name_rejects_non_swarm() {
        assert!(!is_swarm_socket_name("default"));
        assert!(!is_swarm_socket_name("spec-my-feature"));
        assert!(!is_swarm_socket_name("tmux-default"));
        assert!(!is_swarm_socket_name("claude-swarm"));  // no trailing dash + pid
    }

    #[test]
    fn argv_matches_parent_session_mid_string() {
        let argv = "node /usr/local/bin/claude --parent-session-id abc123def --some-flag";
        assert!(argv_contains_parent_session(argv, "abc123def"));
    }

    #[test]
    fn argv_matches_parent_session_at_end() {
        let argv = "claude --parent-session-id abc123";
        assert!(argv_contains_parent_session(argv, "abc123"));
    }

    #[test]
    fn argv_does_not_match_partial_id() {
        let argv = "claude --parent-session-id abc123";
        assert!(!argv_contains_parent_session(argv, "abc"));
        assert!(!argv_contains_parent_session(argv, "bc123"));
    }

    #[test]
    fn argv_does_not_match_when_flag_absent() {
        let argv = "claude --some-flag abc123";
        assert!(!argv_contains_parent_session(argv, "abc123"));
    }

    #[test]
    fn argv_matches_nul_separated_linux_cmdline() {
        // /proc/<pid>/cmdline uses NUL separators; we normalize to spaces before checking
        let cmdline = "claude\0--parent-session-id\0abc123\0--other\0";
        let normalized = cmdline.replace('\0', " ");
        assert!(argv_contains_parent_session(&normalized, "abc123"));
    }

    // ---- pid_subtree_has_session ----

    fn make_table(entries: &[(u32, u32, &str)]) -> HashMap<u32, (u32, String)> {
        entries.iter().map(|&(pid, ppid, args)| (pid, (ppid, args.to_string()))).collect()
    }

    #[test]
    fn subtree_matches_direct_child_not_root() {
        // pane shell (100) has no session id; its child claude (101) does
        let table = make_table(&[
            (100, 1, "-zsh"),
            (101, 100, "claude --parent-session-id abc123"),
        ]);
        assert!(pid_subtree_has_session(&table, 100, "abc123"),
            "should match via direct child");
        assert!(!pid_subtree_has_session(&table, 100, "other"),
            "should not match a different session id");
    }

    #[test]
    fn subtree_no_match_when_session_absent() {
        let table = make_table(&[
            (100, 1, "-zsh"),
            (101, 100, "claude --parent-session-id different-id"),
        ]);
        assert!(!pid_subtree_has_session(&table, 100, "abc123"));
    }

    #[test]
    fn subtree_matches_grandchild_depth_two() {
        // depth: pane(100) → bash(101) → claude(102)
        let table = make_table(&[
            (100, 1, "-zsh"),
            (101, 100, "bash"),
            (102, 101, "node /usr/bin/claude --parent-session-id abc123 --flag"),
        ]);
        assert!(pid_subtree_has_session(&table, 100, "abc123"),
            "should match at depth 2");
    }

    #[test]
    fn subtree_matches_root_itself() {
        let table = make_table(&[
            (100, 1, "claude --parent-session-id abc123"),
        ]);
        assert!(pid_subtree_has_session(&table, 100, "abc123"));
    }

    #[test]
    fn subtree_ignores_processes_outside_tree() {
        // process 200 has the session id but is not a descendant of 100
        let table = make_table(&[
            (100, 1, "-zsh"),
            (101, 100, "vim"),
            (200, 99, "claude --parent-session-id abc123"),
        ]);
        assert!(!pid_subtree_has_session(&table, 100, "abc123"),
            "should not match a process outside the subtree");
    }

    #[test]
    fn watch_team_argv_ghostty() {
        let argv = watch_team_argv("ghostty", "claude-swarm-12345");
        assert_eq!(argv[..4], ["open", "-na", "Ghostty", "--args"]);
        assert_eq!(argv[7], "exec tmux -L 'claude-swarm-12345' attach -r");
    }

    #[test]
    fn watch_team_argv_other_program() {
        let argv = watch_team_argv("alacritty", "claude-swarm-99");
        assert_eq!(argv[0], "alacritty");
        assert_eq!(argv[4], "exec tmux -L 'claude-swarm-99' attach -r");
    }
}

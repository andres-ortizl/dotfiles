pub mod config;
pub mod curator;
pub mod event;
pub mod lessons;
pub mod notes;
pub mod paths;
pub mod ports;
pub mod state;
pub mod swarm;
pub mod terminal;
pub mod view;

pub use config::{
    config_path, config_view, get_dotted, load_effective, load_effective_opt, project_file,
    reactor_for, referenced_skills, schema, validate, Action, ConfigView, Effective, HookPoint,
    Identity, Models, PortSpec, Providers, ReactorView, Terminal,
};
pub use event::{
    validate_score, Event, GateProvider, GateResult, NoteLevel, Payload, Phase, PrState, Role,
    SpecMode, Verdict,
};
pub use curator::{list_curator_reports, load_curator_report, CuratorReport};
pub use lessons::{load_all_lessons, load_lesson, load_lessons, save_lesson, Anchor, Lesson};
pub use notes::{filter_notes, group_by_topic, load_all_notes, AggregatedNote};
pub use ports::pick_offset;
pub use swarm::{
    argv_contains_parent_session, find_swarm_socket, is_swarm_socket_name, read_team_panes,
    watch_team_argv, PaneContent, TeamPanesResult,
};
pub use terminal::attach_argv;
pub use state::{AgentSnapshot, GateSummary, Health, PrRef, SpecState, TestSummary};
pub use view::{fleet_snapshot, AgentView, FleetRow};

use std::fs::{self, OpenOptions};
use std::io::Write;

use anyhow::{Context, Result};
use chrono::Utc;

/// Append an event to the spec's `events.jsonl` and fold it into `state.json`.
/// Returns the updated snapshot. This is the one write path the producer uses.
/// `actor` is "who" emitted this (lead / coder / reviewer / None for anonymous).
pub fn emit(project: &str, name: &str, payload: Payload, actor: Option<&str>) -> Result<SpecState> {
    let now = Utc::now();
    let dir = paths::spec_dir(project, name)?;
    fs::create_dir_all(&dir).with_context(|| format!("creating {}", dir.display()))?;

    let event = payload.clone().into_event(paths::source_str(project, name), actor.map(String::from), now);
    let line = serde_json::to_string(&event)?;
    let mut f = OpenOptions::new()
        .create(true)
        .append(true)
        .open(paths::events_path(project, name)?)?;
    writeln!(f, "{line}")?;

    let state_path = paths::state_path(project, name)?;
    let mut state = if state_path.exists() {
        serde_json::from_str(&fs::read_to_string(&state_path)?)
            .unwrap_or_else(|_| SpecState::new(project.to_string(), name.to_string(), now))
    } else {
        SpecState::new(project.to_string(), name.to_string(), now)
    };
    state.apply(&payload, now);
    fs::write(&state_path, serde_json::to_string_pretty(&state)?)?;
    Ok(state)
}

/// Read one spec's snapshot, if it exists.
pub fn load_state(project: &str, name: &str) -> Result<Option<SpecState>> {
    let p = paths::state_path(project, name)?;
    match fs::read_to_string(&p) {
        Ok(txt) => Ok(serde_json::from_str(&txt).ok()),
        Err(_) => Ok(None),
    }
}

/// Read a spec's full event log (for the detail timeline). Malformed lines are skipped.
pub fn read_events(project: &str, name: &str) -> Result<Vec<Event>> {
    let p = paths::events_path(project, name)?;
    let mut out = Vec::new();
    if let Ok(txt) = fs::read_to_string(&p) {
        for line in txt.lines() {
            if line.trim().is_empty() {
                continue;
            }
            if let Ok(ev) = serde_json::from_str::<Event>(line) {
                out.push(ev);
            }
        }
    }
    Ok(out)
}

/// Read the spec's design doc (`spec.md`), if the file exists.
pub fn load_spec_doc(project: &str, name: &str) -> Result<Option<String>> {
    let p = paths::spec_doc_path(project, name)?;
    Ok(fs::read_to_string(&p).ok())
}

/// Read the spec's logbook (`logbook.md`), if the file exists.
pub fn load_logbook(project: &str, name: &str) -> Result<Option<String>> {
    let p = paths::logbook_path(project, name)?;
    Ok(fs::read_to_string(&p).ok())
}

/// Raw text of a project's `.dex.toml`. `None` when unresolvable.
pub fn project_config_raw(project: &str) -> Result<Option<String>> {
    for s in load_all()?.into_iter().filter(|s| s.project == project) {
        if let Some(wt) = s.worktree {
            if let Some(path) = config::project_file(std::path::Path::new(&wt)) {
                return Ok(Some(std::fs::read_to_string(path)?));
            }
        }
    }
    Ok(None)
}

/// Resolve a project's effective config by walking up from one of its specs'
/// worktrees to the repo `.dex.toml`. `None` when the project has no spec with a
/// resolvable config (e.g. every worktree predates a `.dex.toml`).
pub fn project_config(project: &str) -> Result<Option<Effective>> {
    for s in load_all()?.into_iter().filter(|s| s.project == project) {
        if let Some(wt) = s.worktree {
            if let Ok(Some(eff)) = config::load_effective_opt(std::path::Path::new(&wt)) {
                return Ok(Some(eff));
            }
        }
    }
    Ok(None)
}

/// Read every live (non-archived) spec snapshot across the whole registry.
pub fn load_all() -> Result<Vec<SpecState>> {
    Ok(collect_specs()?
        .into_iter()
        .filter(|(_, archived)| !archived)
        .map(|(s, _)| s)
        .collect())
}

/// Read every archived spec snapshot — the registry's hidden shelf.
pub fn load_archived() -> Result<Vec<SpecState>> {
    Ok(collect_specs()?
        .into_iter()
        .filter(|(_, archived)| *archived)
        .map(|(s, _)| s)
        .collect())
}

/// Archive (hide from the fleet) or restore a spec by toggling its marker file.
pub fn set_archived(project: &str, name: &str, archived: bool) -> Result<()> {
    let dir = paths::spec_dir(project, name)?;
    if !dir.is_dir() {
        anyhow::bail!("no spec at {project}/{name}");
    }
    let marker = paths::archived_path(project, name)?;
    if archived {
        fs::write(&marker, b"")?;
    } else if marker.exists() {
        fs::remove_file(&marker)?;
    }
    Ok(())
}

fn collect_specs() -> Result<Vec<(SpecState, bool)>> {
    let root = paths::spec_root()?;
    if !root.exists() {
        return Ok(Vec::new());
    }
    collect_specs_from(&root)
}

fn collect_specs_from(root: &std::path::Path) -> Result<Vec<(SpecState, bool)>> {
    let mut out = Vec::new();
    for project in fs::read_dir(root)?.flatten() {
        if project.file_name().to_string_lossy().starts_with('.') {
            continue;
        }
        if !project.path().is_dir() {
            continue;
        }
        for spec in fs::read_dir(project.path())?.flatten() {
            let dir = spec.path();
            if let Ok(txt) = fs::read_to_string(dir.join("state.json")) {
                if let Ok(state) = serde_json::from_str::<SpecState>(&txt) {
                    let archived = dir.join(paths::ARCHIVED_MARKER).exists();
                    out.push((state, archived));
                }
            }
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dot_dir_produces_no_fleet_entries() {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root = std::env::temp_dir().join(format!("specdex_fleet_dotdir_{nanos}"));
        let real_spec = root.join("real-project").join("my-spec");
        let dot_spec = root.join(".curator").join("fake-spec");
        std::fs::create_dir_all(&real_spec).unwrap();
        std::fs::create_dir_all(&dot_spec).unwrap();
        let now = chrono::Utc::now();
        let state = SpecState::new("real-project".into(), "my-spec".into(), now);
        let dot_state = SpecState::new("fake-dot-project".into(), "fake-spec".into(), now);
        std::fs::write(real_spec.join("state.json"), serde_json::to_string(&state).unwrap()).unwrap();
        std::fs::write(dot_spec.join("state.json"), serde_json::to_string(&dot_state).unwrap()).unwrap();
        let collected = collect_specs_from(&root).unwrap();
        let states: Vec<_> = collected.iter().filter(|(_, a)| !a).collect();
        assert_eq!(states.len(), 1, "dot-dir must not produce phantom fleet entries");
        assert_eq!(states[0].0.project, "real-project");
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn archived_marker_splits_live_from_archived() {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root = std::env::temp_dir().join(format!("specdex_archive_{nanos}"));
        let now = chrono::Utc::now();
        for name in ["live-spec", "shelved-spec"] {
            let dir = root.join("proj").join(name);
            std::fs::create_dir_all(&dir).unwrap();
            let state = SpecState::new("proj".into(), name.into(), now);
            std::fs::write(dir.join("state.json"), serde_json::to_string(&state).unwrap()).unwrap();
        }
        std::fs::write(root.join("proj").join("shelved-spec").join(paths::ARCHIVED_MARKER), b"").unwrap();
        let collected = collect_specs_from(&root).unwrap();
        let live: Vec<_> = collected.iter().filter(|(_, a)| !a).map(|(s, _)| s.name.as_str()).collect();
        let archived: Vec<_> = collected.iter().filter(|(_, a)| *a).map(|(s, _)| s.name.as_str()).collect();
        assert_eq!(live, vec!["live-spec"]);
        assert_eq!(archived, vec!["shelved-spec"]);
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn project_config_raw_returns_none_for_unknown_project() {
        assert!(project_config_raw("__no_such_project_xyz__").unwrap().is_none());
    }

    #[test]
    fn project_file_resolves_repo_toml() {
        let found = project_file(std::path::Path::new(env!("CARGO_MANIFEST_DIR"))).unwrap();
        let text = std::fs::read_to_string(&found).unwrap();
        assert!(text.contains("[providers]") || text.contains("[identity]") || text.contains("[terminal]"));
    }

    #[test]
    fn event_roundtrips_through_jsonl() {
        let p = Payload::Review {
            round: 2,
            verdict: Verdict::Fail,
            blockers: 1,
            issues: 3,
        };
        let ev = p.into_event("/spec/proj/feat".into(), None, Utc::now());
        let line = serde_json::to_string(&ev).unwrap();
        let back: Event = serde_json::from_str(&line).unwrap();
        assert_eq!(back.kind, "review.verdict");
        assert_eq!(back.data["blockers"], 1);
        assert_eq!(back.data["verdict"], "fail");
    }

    #[test]
    fn block_is_a_flag_on_the_work_phase() {
        let now = Utc::now();
        let mut s = SpecState::new("proj".into(), "feat".into(), now);
        s.apply(&Payload::PhaseEnter { phase: Phase::Review, reason: None }, now);
        // block does not change the phase — it's a flag.
        s.apply(&Payload::Block { reason: "x".into() }, now);
        assert_eq!(s.phase, Phase::Review);
        assert_eq!(s.blocked_reason.as_deref(), Some("x"));
        assert_eq!(s.health(now, 900), Health::NeedsYou);

        // moving to the next phase clears the block.
        s.apply(&Payload::PhaseEnter { phase: Phase::Ship, reason: None }, now);
        assert_eq!(s.phase, Phase::Ship);
        assert!(s.blocked_reason.is_none());
        // explicit unblock also clears it.
        s.apply(&Payload::Block { reason: "y".into() }, now);
        s.apply(&Payload::Unblock, now);
        assert!(s.blocked_reason.is_none());
    }

    #[test]
    fn init_sets_mode_default_is_autonomous() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        assert_eq!(s.mode, SpecMode::Autonomous);
        s.apply(
            &Payload::Init { branch: "b".into(), worktree: "/wt".into(), mode: SpecMode::Collaborative, session_id: None },
            now,
        );
        assert_eq!(s.mode, SpecMode::Collaborative);
    }

    #[test]
    fn pr_state_folds_into_snapshot() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        s.apply(&Payload::Pr { number: 7, url: "u".into(), state: PrState::Open }, now);
        assert_eq!(s.pr.as_ref().unwrap().state, PrState::Open);
        s.apply(&Payload::Pr { number: 7, url: "u".into(), state: PrState::Merged }, now);
        assert_eq!(s.pr.as_ref().unwrap().state, PrState::Merged);
    }

    #[test]
    fn stale_when_no_heartbeat() {
        let now = Utc::now();
        let mut s = SpecState::new("proj".into(), "feat".into(), now);
        s.apply(&Payload::PhaseEnter { phase: Phase::Build, reason: None }, now);
        let later = now + chrono::Duration::seconds(1000);
        assert_eq!(s.health(later, 900), Health::Stale);
    }
}

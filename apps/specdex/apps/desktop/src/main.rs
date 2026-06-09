#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::sync::mpsc::channel;
use std::time::Duration;

use notify::{RecursiveMode, Watcher};
use specdex_core::{
    attach_argv, config_view, find_swarm_socket, fleet_snapshot, list_curator_reports,
    load_all, load_all_lessons, load_all_notes, load_archived, load_curator_report, load_logbook,
    load_spec_doc, load_state, paths, project_config as core_project_config, project_config_raw,
    read_events, read_team_panes, set_archived, watch_team_argv, AggregatedNote, CuratorReport,
    FleetRow,
};
use tauri::{AppHandle, Emitter};

const STALE_SECS: i64 = 15 * 60;

fn snapshot() -> Vec<FleetRow> {
    match load_all() {
        Ok(specs) => fleet_snapshot(specs, chrono::Utc::now(), STALE_SECS),
        Err(_) => Vec::new(),
    }
}

/// Initial-load command the webview calls on mount.
#[tauri::command]
fn fleet() -> Vec<FleetRow> {
    snapshot()
}

/// Archived specs as fleet rows — the registry's hidden shelf.
#[tauri::command]
fn archived_specs() -> Vec<FleetRow> {
    match load_archived() {
        Ok(specs) => fleet_snapshot(specs, chrono::Utc::now(), STALE_SECS),
        Err(_) => Vec::new(),
    }
}

/// Hide a spec from the fleet (and the file-watch polling). The registry watcher
/// re-emits the fleet snapshot once the marker lands.
#[tauri::command]
fn archive_spec(project: String, name: String) -> Result<(), String> {
    set_archived(&project, &name, true).map_err(|e| e.to_string())
}

/// Restore an archived spec to the live fleet.
#[tauri::command]
fn unarchive_spec(project: String, name: String) -> Result<(), String> {
    set_archived(&project, &name, false).map_err(|e| e.to_string())
}

/// Aggregated notes across the whole registry — the curator's signals plane.
#[tauri::command]
fn signals() -> Vec<AggregatedNote> {
    load_all_notes().unwrap_or_default()
}

/// Per-project lessons (the memory plane), grouped by project.
/// Returns `[{ project, lessons: [{ id, abstract, insight, scope, trigger, state, … }] }]`.
#[tauri::command]
fn memory() -> serde_json::Value {
    match load_all_lessons() {
        Ok(groups) => serde_json::Value::Array(
            groups
                .iter()
                .map(|(project, lessons)| {
                    serde_json::json!({
                        "project": project,
                        "lessons": lessons.iter().map(|l| l.to_json()).collect::<Vec<_>>(),
                    })
                })
                .collect(),
        ),
        Err(_) => serde_json::Value::Array(Vec::new()),
    }
}

/// List all curator reports, newest first.
#[tauri::command]
fn curator_reports() -> Vec<CuratorReport> {
    list_curator_reports().unwrap_or_default()
}

/// Read the markdown content of one curator report by id.
#[tauri::command]
fn read_curator_report(id: String) -> String {
    load_curator_report(&id).unwrap_or_default()
}

/// Full detail for one spec: snapshot state, derived health, the event log, the
/// `spec.md` / `logbook.md` docs, and the project's raw `.dex.toml` (if present).
#[tauri::command]
fn spec_detail(project: String, name: String) -> serde_json::Value {
    let state = load_state(&project, &name).ok().flatten();
    let health = state.as_ref().map(|s| s.health(chrono::Utc::now(), STALE_SECS).label().to_string());
    let events = read_events(&project, &name).unwrap_or_default();
    let doc = load_spec_doc(&project, &name).ok().flatten();
    let logbook = load_logbook(&project, &name).ok().flatten();
    let config_raw = project_config_raw(&project).ok().flatten();
    serde_json::json!({ "state": state, "health": health, "events": events, "doc": doc, "logbook": logbook, "config_raw": config_raw })
}

/// One project's effective `.dex.toml` config plus registry-derived reactors (read-only),
/// or null if none resolves.
#[tauri::command]
fn project_config(project: String) -> Option<serde_json::Value> {
    core_project_config(&project).ok().flatten().map(|eff| {
        let view = config_view(&eff);
        serde_json::to_value(&view).ok().unwrap_or(serde_json::Value::Null)
    })
}

/// Resolve the configured terminal emulator program for a project, defaulting to ghostty.
fn configured_terminal(project: &str) -> (String, Option<String>) {
    let cfg = core_project_config(project).ok().flatten();
    let program = cfg
        .as_ref()
        .and_then(|c| c.terminal.program.as_deref())
        .filter(|s| !s.is_empty())
        .unwrap_or("ghostty")
        .to_string();
    let mux = cfg.as_ref().and_then(|c| c.providers.multiplexer.clone());
    (program, mux)
}

/// Open the spec's worktree in a terminal emulator via the configured provider.
#[tauri::command]
fn attach_terminal(project: String, name: String) -> Result<(), String> {
    let state = load_state(&project, &name)
        .ok()
        .flatten()
        .ok_or_else(|| format!("no state for {project}/{name}"))?;
    let (program, mux) = configured_terminal(&project);
    let session = format!("spec-{name}");
    let argv = attach_argv(&program, mux.as_deref(), &session, state.worktree.as_deref(), state.session_id.as_deref());
    std::process::Command::new(&argv[0]).args(&argv[1..]).spawn().map_err(|e| e.to_string())?;
    Ok(())
}

/// Live agent pane contents for a spec's claude-swarm team.
/// Returns `{ socket_name, panes: [{ title, text }] }`.
/// Returns `{ socket_name: null, panes: [] }` when teams are off or spec has no session id.
#[tauri::command]
fn team_panes(project: String, name: String) -> serde_json::Value {
    let session_id = load_state(&project, &name)
        .ok()
        .flatten()
        .and_then(|s| s.session_id);

    let Some(id) = session_id else {
        return serde_json::json!({ "socket_name": null, "panes": [] });
    };

    let result = read_team_panes(&id);
    serde_json::json!({
        "socket_name": result.socket_name,
        "panes": result.panes.iter().map(|p| serde_json::json!({ "title": p.title, "text": p.text })).collect::<Vec<_>>(),
    })
}

/// Open a read-only terminal view of the spec's live team.
/// No-op (returns Ok) when the spec has no session id or no live swarm socket.
#[tauri::command]
fn watch_team(project: String, name: String) -> Result<(), String> {
    let Some(state) = load_state(&project, &name).ok().flatten() else {
        return Ok(());
    };
    let Some(session_id) = state.session_id.as_deref() else {
        return Ok(());
    };
    let Some(socket_name) = find_swarm_socket(session_id) else {
        return Ok(());
    };
    let (program, _) = configured_terminal(&project);
    let argv = watch_team_argv(&program, &socket_name);
    std::process::Command::new(&argv[0])
        .args(&argv[1..])
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

fn emit_fleet(handle: &AppHandle) {
    let _ = handle.emit("fleet", snapshot());
}

fn emit_signals(handle: &AppHandle) {
    let notes = load_all_notes().unwrap_or_default();
    let _ = handle.emit("signals", notes);
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![fleet, archived_specs, archive_spec, unarchive_spec, signals, memory, curator_reports, read_curator_report, spec_detail, project_config, attach_terminal, team_panes, watch_team])
        .setup(|app| {
            let handle = app.handle().clone();
            // Watch the registry off-thread; push a fresh snapshot to the webview on change.
            std::thread::spawn(move || {
                emit_fleet(&handle);
                emit_signals(&handle);
                let root = match paths::spec_root() {
                    Ok(r) if r.exists() => r,
                    _ => return,
                };
                let (tx, rx) = channel();
                let mut watcher = match notify::recommended_watcher(move |res| {
                    let _ = tx.send(res);
                }) {
                    Ok(w) => w,
                    Err(_) => return,
                };
                if watcher.watch(&root, RecursiveMode::Recursive).is_err() {
                    return;
                }
                while rx.recv().is_ok() {
                    while rx.try_recv().is_ok() {} // coalesce a burst
                    std::thread::sleep(Duration::from_millis(80));
                    emit_fleet(&handle);
                    emit_signals(&handle);
                }
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running specdex");
}

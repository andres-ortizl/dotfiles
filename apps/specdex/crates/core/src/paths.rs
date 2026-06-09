//! Layout of the central spec registry at `~/.spec/<project>/<spec>/`.

use std::path::PathBuf;

use anyhow::{anyhow, Result};

pub fn spec_root() -> Result<PathBuf> {
    let home = dirs::home_dir().ok_or_else(|| anyhow!("could not resolve home directory"))?;
    Ok(home.join(".spec"))
}

pub fn curator_dir() -> Result<PathBuf> {
    Ok(spec_root()?.join(".curator"))
}

pub fn spec_dir(project: &str, name: &str) -> Result<PathBuf> {
    Ok(spec_root()?.join(project).join(name))
}

pub fn events_path(project: &str, name: &str) -> Result<PathBuf> {
    Ok(spec_dir(project, name)?.join("events.jsonl"))
}

pub fn state_path(project: &str, name: &str) -> Result<PathBuf> {
    Ok(spec_dir(project, name)?.join("state.json"))
}

/// Marker file that hides a spec from the fleet (and the file-watch polling).
pub const ARCHIVED_MARKER: &str = "archived";

pub fn archived_path(project: &str, name: &str) -> Result<PathBuf> {
    Ok(spec_dir(project, name)?.join(ARCHIVED_MARKER))
}

pub fn spec_doc_path(project: &str, name: &str) -> Result<PathBuf> {
    Ok(spec_dir(project, name)?.join("spec.md"))
}

pub fn logbook_path(project: &str, name: &str) -> Result<PathBuf> {
    Ok(spec_dir(project, name)?.join("logbook.md"))
}

pub fn source_str(project: &str, name: &str) -> String {
    format!("/spec/{project}/{name}")
}

pub fn lessons_dir(project: &str) -> Result<PathBuf> {
    Ok(spec_root()?.join(project).join("lessons"))
}

pub fn lesson_path(project: &str, id: &str) -> Result<PathBuf> {
    Ok(lessons_dir(project)?.join(format!("{id}.md")))
}

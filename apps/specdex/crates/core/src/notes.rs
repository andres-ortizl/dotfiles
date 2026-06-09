use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::event::Event;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AggregatedNote {
    pub project: String,
    pub spec: String,
    pub actor: Option<String>,
    pub level: String,
    pub topic: String,
    pub scope: Option<String>,
    pub text: String,
    pub time: DateTime<Utc>,
}

/// Pure: filter a slice of notes by optional scope/topic/level.
pub fn filter_notes<'a>(
    notes: &'a [AggregatedNote],
    scope: Option<&str>,
    topic: Option<&str>,
    level: Option<&str>,
) -> Vec<&'a AggregatedNote> {
    notes
        .iter()
        .filter(|n| scope.map_or(true, |s| n.scope.as_deref() == Some(s)))
        .filter(|n| topic.map_or(true, |t| n.topic == t))
        .filter(|n| level.map_or(true, |l| n.level == l))
        .collect()
}

/// Pure: group a slice of notes by topic. Returns vec of (topic, notes) sorted by topic.
pub fn group_by_topic(notes: &[AggregatedNote]) -> Vec<(String, Vec<&AggregatedNote>)> {
    let mut map: std::collections::BTreeMap<&str, Vec<&AggregatedNote>> =
        std::collections::BTreeMap::new();
    for n in notes {
        map.entry(n.topic.as_str()).or_default().push(n);
    }
    map.into_iter().map(|(k, v)| (k.to_string(), v)).collect()
}

/// I/O: read all note events across every spec in the registry.
pub fn load_all_notes() -> anyhow::Result<Vec<AggregatedNote>> {
    let root = crate::paths::spec_root()?;
    if !root.exists() {
        return Ok(Vec::new());
    }
    load_notes_from(&root)
}

fn load_notes_from(root: &std::path::Path) -> anyhow::Result<Vec<AggregatedNote>> {
    use std::fs;
    let mut out = Vec::new();
    for project_entry in fs::read_dir(root)?.flatten() {
        if project_entry.file_name().to_string_lossy().starts_with('.') {
            continue;
        }
        if !project_entry.path().is_dir() {
            continue;
        }
        let project = project_entry.file_name().to_string_lossy().into_owned();
        for spec_entry in fs::read_dir(project_entry.path())?.flatten() {
            if !spec_entry.path().is_dir() {
                continue;
            }
            let spec = spec_entry.file_name().to_string_lossy().into_owned();
            let events_path = spec_entry.path().join("events.jsonl");
            let Ok(text) = fs::read_to_string(&events_path) else {
                continue;
            };
            for line in text.lines() {
                if line.trim().is_empty() {
                    continue;
                }
                let Ok(ev) = serde_json::from_str::<Event>(line) else {
                    continue;
                };
                if ev.kind != "note" {
                    continue;
                }
                let d = &ev.data;
                let level = d["level"].as_str().unwrap_or("info").to_string();
                let topic = d["topic"].as_str().unwrap_or("").to_string();
                let text = d["text"].as_str().unwrap_or("").to_string();
                let scope = d["scope"].as_str().map(String::from);
                out.push(AggregatedNote {
                    project: project.clone(),
                    spec: spec.clone(),
                    actor: ev.actor,
                    level,
                    topic,
                    scope,
                    text,
                    time: ev.time,
                });
            }
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    fn note(project: &str, spec: &str, level: &str, topic: &str, scope: Option<&str>) -> AggregatedNote {
        AggregatedNote {
            project: project.into(),
            spec: spec.into(),
            actor: None,
            level: level.into(),
            topic: topic.into(),
            scope: scope.map(String::from),
            text: "test".into(),
            time: Utc::now(),
        }
    }

    #[test]
    fn filter_by_scope() {
        let notes = vec![
            note("p", "s1", "warn", "env/git", Some("skill")),
            note("p", "s2", "info", "plan", Some("project")),
            note("p", "s3", "error", "test-flake", None),
        ];
        let r = filter_notes(&notes, Some("skill"), None, None);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].spec, "s1");
    }

    #[test]
    fn filter_by_topic() {
        let notes = vec![
            note("p", "s1", "warn", "env/git", None),
            note("p", "s2", "info", "env/git", None),
            note("p", "s3", "error", "plan", None),
        ];
        let r = filter_notes(&notes, None, Some("env/git"), None);
        assert_eq!(r.len(), 2);
    }

    #[test]
    fn filter_by_level() {
        let notes = vec![
            note("p", "s1", "warn", "t", None),
            note("p", "s2", "error", "t", None),
            note("p", "s3", "info", "t", None),
        ];
        let r = filter_notes(&notes, None, None, Some("warn"));
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].spec, "s1");
    }

    #[test]
    fn filter_combined_scope_and_level() {
        let notes = vec![
            note("p", "s1", "warn", "t", Some("skill")),
            note("p", "s2", "error", "t", Some("skill")),
            note("p", "s3", "warn", "t", Some("project")),
        ];
        let r = filter_notes(&notes, Some("skill"), None, Some("warn"));
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].spec, "s1");
    }

    #[test]
    fn filter_none_returns_all() {
        let notes = vec![
            note("p", "s1", "warn", "t1", None),
            note("p", "s2", "info", "t2", None),
        ];
        let r = filter_notes(&notes, None, None, None);
        assert_eq!(r.len(), 2);
    }

    #[test]
    fn dot_dir_produces_no_notes() {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root = std::env::temp_dir().join(format!("specdex_notes_dotdir_{nanos}"));
        let real_spec = root.join("real-project").join("my-spec");
        let dot_spec = root.join(".curator").join("fake-spec");
        std::fs::create_dir_all(&real_spec).unwrap();
        std::fs::create_dir_all(&dot_spec).unwrap();
        let note_line = r#"{"type":"note","time":"2026-06-05T00:00:00Z","source":"/spec/x/y","data":{"level":"info","topic":"test","text":"hello"}}"#;
        std::fs::write(real_spec.join("events.jsonl"), note_line).unwrap();
        std::fs::write(dot_spec.join("events.jsonl"), note_line).unwrap();
        let notes = super::load_notes_from(&root).unwrap();
        assert_eq!(notes.len(), 1, "dot-dir must not produce phantom notes");
        assert_eq!(notes[0].project, "real-project");
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn group_by_topic_clusters() {
        let notes = vec![
            note("p", "s1", "warn", "env/git", None),
            note("p", "s2", "info", "plan", None),
            note("p", "s3", "error", "env/git", None),
        ];
        let groups = group_by_topic(&notes);
        assert_eq!(groups.len(), 2);
        let env_group = groups.iter().find(|(t, _)| t == "env/git").unwrap();
        assert_eq!(env_group.1.len(), 2);
        let plan_group = groups.iter().find(|(t, _)| t == "plan").unwrap();
        assert_eq!(plan_group.1.len(), 1);
    }
}

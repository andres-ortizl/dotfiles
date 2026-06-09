use std::fs;

use anyhow::{anyhow, Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Anchor {
    #[serde(default)]
    pub paths: Vec<String>,
    #[serde(default)]
    pub git_rev: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Lesson {
    pub scope: String,
    pub trigger: String,
    #[serde(rename = "abstract")]
    pub summary: String,
    #[serde(default)]
    pub provenance: Vec<String>,
    #[serde(default)]
    pub anchor: Anchor,
    #[serde(default)]
    pub confidence: f32,
    #[serde(default)]
    pub state: String,
    pub created_at: DateTime<Utc>,
    pub last_validated_at: DateTime<Utc>,
    #[serde(skip)]
    pub insight: String,
    #[serde(skip)]
    pub id: String,
}

pub fn valid_lesson_id(id: &str) -> bool {
    if id.is_empty() {
        return false;
    }
    id.chars().all(|c| c.is_alphanumeric() || c == '-' || c == '_')
}

pub fn parse_lesson(id: &str, raw: &str) -> Result<Lesson> {
    if !valid_lesson_id(id) {
        return Err(anyhow!("invalid lesson id: {id:?}"));
    }
    let parts: Vec<&str> = raw.splitn(3, "+++").collect();
    if parts.len() < 3 {
        return Err(anyhow!("lesson file missing +++ delimiters"));
    }
    let toml_src = parts[1].trim();
    let body = parts[2].trim().to_string();

    let mut lesson: Lesson = toml::from_str(toml_src)
        .with_context(|| format!("parsing TOML frontmatter for lesson {id:?}"))?;
    lesson.insight = body;
    lesson.id = id.to_string();
    Ok(lesson)
}

pub fn serialize_lesson(lesson: &Lesson) -> String {
    let toml_str = toml::to_string(lesson).expect("Lesson serialization failed");
    format!("+++\n{toml_str}+++\n{}\n", lesson.insight)
}

pub fn load_lessons(project: &str) -> Result<Vec<Lesson>> {
    load_lessons_from(&crate::paths::spec_root()?, project)
}

fn load_lessons_from(root: &std::path::Path, project: &str) -> Result<Vec<Lesson>> {
    let dir = root.join(project).join("lessons");
    if !dir.exists() {
        return Ok(Vec::new());
    }
    let mut lessons = Vec::new();
    for entry in fs::read_dir(&dir)?.flatten() {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        let Some(id) = name_str.strip_suffix(".md") else {
            continue;
        };
        if !valid_lesson_id(id) {
            continue;
        }
        let Ok(raw) = fs::read_to_string(entry.path()) else {
            continue;
        };
        let Ok(lesson) = parse_lesson(id, &raw) else {
            continue;
        };
        lessons.push(lesson);
    }
    lessons.sort_by(|a, b| b.created_at.cmp(&a.created_at));
    Ok(lessons)
}

pub fn load_lesson(project: &str, id: &str) -> Result<Lesson> {
    load_lesson_from(&crate::paths::spec_root()?, project, id)
}

fn load_lesson_from(root: &std::path::Path, project: &str, id: &str) -> Result<Lesson> {
    if !valid_lesson_id(id) {
        return Err(anyhow!("invalid lesson id: {id:?}"));
    }
    let path = root.join(project).join("lessons").join(format!("{id}.md"));
    let raw = fs::read_to_string(&path)
        .with_context(|| format!("reading lesson {id:?} at {}", path.display()))?;
    parse_lesson(id, &raw)
}

pub fn save_lesson(project: &str, lesson: &Lesson) -> Result<()> {
    save_lesson_to(&crate::paths::spec_root()?, project, lesson)
}

fn save_lesson_to(root: &std::path::Path, project: &str, lesson: &Lesson) -> Result<()> {
    if !valid_lesson_id(&lesson.id) {
        return Err(anyhow!("invalid lesson id: {:?}", lesson.id));
    }
    let dir = root.join(project).join("lessons");
    fs::create_dir_all(&dir)
        .with_context(|| format!("creating lessons dir {}", dir.display()))?;
    let path = dir.join(format!("{}.md", lesson.id));
    let content = serialize_lesson(lesson);
    fs::write(&path, content)
        .with_context(|| format!("writing lesson {:?}", lesson.id))?;
    Ok(())
}

impl Lesson {
    /// JSON for consumers (desktop, CLI `--json`) — includes the `#[serde(skip)]`
    /// `id` and `insight` that the TOML frontmatter deliberately omits.
    pub fn to_json(&self) -> serde_json::Value {
        let mut v = serde_json::to_value(self).unwrap_or_else(|_| serde_json::json!({}));
        if let Some(obj) = v.as_object_mut() {
            obj.insert("id".into(), serde_json::Value::String(self.id.clone()));
            obj.insert("insight".into(), serde_json::Value::String(self.insight.clone()));
        }
        v
    }
}

/// Every project's lessons across the registry, grouped by project (sorted),
/// skipping projects with no lessons.
pub fn load_all_lessons() -> Result<Vec<(String, Vec<Lesson>)>> {
    let root = crate::paths::spec_root()?;
    if !root.exists() {
        return Ok(Vec::new());
    }
    let mut out = Vec::new();
    for entry in fs::read_dir(&root)?.flatten() {
        if entry.file_name().to_string_lossy().starts_with('.') || !entry.path().is_dir() {
            continue;
        }
        let project = entry.file_name().to_string_lossy().into_owned();
        let lessons = load_lessons(&project)?;
        if !lessons.is_empty() {
            out.push((project, lessons));
        }
    }
    out.sort_by(|a, b| a.0.cmp(&b.0));
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn make_lesson(id: &str) -> Lesson {
        let now = Utc.with_ymd_and_hms(2026, 6, 8, 20, 0, 0).unwrap();
        Lesson {
            id: id.to_string(),
            scope: "project".to_string(),
            trigger: "running tests".to_string(),
            summary: "migrate first".to_string(),
            provenance: vec!["/spec/specdex/curator-signals".to_string()],
            anchor: Anchor {
                paths: vec!["crates/db/migrations".to_string()],
                git_rev: Some("730ede1".to_string()),
            },
            confidence: 0.8,
            state: "active".to_string(),
            created_at: now,
            last_validated_at: now,
            insight: "Always run migrations before the test suite.".to_string(),
        }
    }

    fn temp_root() -> std::path::PathBuf {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("specdex_lessons_{nanos}"))
    }

    #[test]
    fn roundtrip_save_load() {
        let root = temp_root();
        let original = make_lesson("migrate-first");

        save_lesson_to(&root, "p", &original).unwrap();
        let loaded = load_lesson_from(&root, "p", "migrate-first").unwrap();

        assert_eq!(loaded.id, original.id);
        assert_eq!(loaded.scope, original.scope);
        assert_eq!(loaded.trigger, original.trigger);
        assert_eq!(loaded.summary, original.summary);
        assert_eq!(loaded.provenance, original.provenance);
        assert_eq!(loaded.anchor.paths, original.anchor.paths);
        assert_eq!(loaded.anchor.git_rev, original.anchor.git_rev);
        assert_eq!(loaded.confidence, original.confidence);
        assert_eq!(loaded.state, original.state);
        assert_eq!(loaded.created_at, original.created_at);
        assert_eq!(loaded.last_validated_at, original.last_validated_at);
        assert_eq!(loaded.insight, original.insight);

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn missing_required_field_is_err() {
        let raw = "+++\nscope = \"project\"\ntrigger = \"tests\"\n+++\nbody\n";
        let result = parse_lesson("some-lesson", raw);
        assert!(result.is_err(), "missing required fields should produce Err");
    }

    #[test]
    fn valid_lesson_id_rejects_traversal() {
        assert!(!valid_lesson_id("../x"));
        assert!(!valid_lesson_id("a/b"));
        assert!(!valid_lesson_id("foo.md/../bar"));
        assert!(!valid_lesson_id(""));
    }

    #[test]
    fn valid_lesson_id_accepts_valid() {
        assert!(valid_lesson_id("migrate-first"));
        assert!(valid_lesson_id("my_lesson_123"));
        assert!(valid_lesson_id("abc"));
    }

    #[test]
    fn load_lessons_newest_first_skips_junk() {
        let root = temp_root();
        let dir = root.join("p").join("lessons");
        fs::create_dir_all(&dir).unwrap();

        let older_time = Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap();
        let newer_time = Utc.with_ymd_and_hms(2026, 6, 8, 20, 0, 0).unwrap();

        let mut older = make_lesson("older-lesson");
        older.created_at = older_time;
        older.last_validated_at = older_time;
        let mut newer = make_lesson("newer-lesson");
        newer.created_at = newer_time;
        newer.last_validated_at = newer_time;

        fs::write(dir.join("older-lesson.md"), serialize_lesson(&older)).unwrap();
        fs::write(dir.join("newer-lesson.md"), serialize_lesson(&newer)).unwrap();
        fs::write(dir.join("junk.md"), "this is not valid frontmatter").unwrap();

        let lessons = load_lessons_from(&root, "p").unwrap();
        assert_eq!(lessons.len(), 2, "junk file should be skipped");
        assert_eq!(lessons[0].id, "newer-lesson", "newest first");
        assert_eq!(lessons[1].id, "older-lesson");

        let _ = fs::remove_dir_all(&root);
    }
}

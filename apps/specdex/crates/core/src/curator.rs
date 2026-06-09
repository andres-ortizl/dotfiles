use std::path::{Path, PathBuf};

use anyhow::Result;
use chrono::{DateTime, NaiveDateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CuratorReport {
    pub id: String,
    pub time: DateTime<Utc>,
    pub path: PathBuf,
}

pub fn parse_report_filename(name: &str) -> Option<(String, DateTime<Utc>)> {
    let stem = name.strip_suffix(".md")?;
    let slug = stem.strip_prefix("report-")?;
    if slug.is_empty() {
        return None;
    }
    let dt = NaiveDateTime::parse_from_str(slug, "%Y-%m-%dT%H-%M-%S").ok()?;
    Some((slug.to_string(), dt.and_utc()))
}

fn list_curator_reports_from(dir: &Path) -> Result<Vec<CuratorReport>> {
    let mut out = Vec::new();
    for entry in std::fs::read_dir(dir)?.flatten() {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        if let Some((id, time)) = parse_report_filename(&name_str) {
            out.push(CuratorReport {
                id,
                time,
                path: entry.path(),
            });
        }
    }
    out.sort_by_key(|r| std::cmp::Reverse(r.time));
    Ok(out)
}

pub fn list_curator_reports() -> Result<Vec<CuratorReport>> {
    let dir = crate::paths::curator_dir()?;
    if !dir.exists() {
        return Ok(Vec::new());
    }
    list_curator_reports_from(&dir)
}

pub fn load_curator_report(id: &str) -> Result<String> {
    let reports = list_curator_reports()?;
    let report = reports
        .iter()
        .find(|r| r.id == id)
        .ok_or_else(|| anyhow::anyhow!("report not found: {id}"))?;
    Ok(std::fs::read_to_string(&report.path)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_valid_filename() {
        let result = parse_report_filename("report-2026-06-05T14-30-12.md");
        assert!(result.is_some());
        let (id, time) = result.unwrap();
        assert_eq!(id, "2026-06-05T14-30-12");
        assert_eq!(time.format("%Y-%m-%d").to_string(), "2026-06-05");
    }

    #[test]
    fn parse_rejects_traversal() {
        assert!(parse_report_filename("../foo.md").is_none());
        assert!(parse_report_filename("../../etc/passwd.md").is_none());
    }

    #[test]
    fn parse_rejects_wrong_prefix() {
        assert!(parse_report_filename("curator-2026-06-05T14-30-12.md").is_none());
        assert!(parse_report_filename("2026-06-05T14-30-12.md").is_none());
    }

    #[test]
    fn parse_rejects_invalid_timestamp() {
        assert!(parse_report_filename("report-not-a-date.md").is_none());
        assert!(parse_report_filename("report-.md").is_none());
        assert!(parse_report_filename("report-2026-06-05T14:30:12.md").is_none());
    }

    #[test]
    fn parse_rejects_non_md_extension() {
        assert!(parse_report_filename("report-2026-06-05T14-30-12.txt").is_none());
    }

    fn tmp(label: &str) -> std::path::PathBuf {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("{label}_{nanos}"))
    }

    #[test]
    fn reports_sorted_descending() {
        let dir = tmp("specdex_curator_sort");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("report-2026-06-05T10-00-00.md"), "older").unwrap();
        std::fs::write(dir.join("report-2026-06-05T14-30-12.md"), "newer").unwrap();
        let reports = list_curator_reports_from(&dir).unwrap();
        assert_eq!(reports.len(), 2);
        assert!(reports[0].time > reports[1].time);
        assert_eq!(reports[0].id, "2026-06-05T14-30-12");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn reports_ignores_non_report_files() {
        let dir = tmp("specdex_curator_filter");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("report-2026-06-05T10-00-00.md"), "ok").unwrap();
        std::fs::write(dir.join("README.md"), "ignored").unwrap();
        std::fs::write(dir.join("notes.txt"), "ignored").unwrap();
        let reports = list_curator_reports_from(&dir).unwrap();
        assert_eq!(reports.len(), 1);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn traversal_id_rejected_by_load() {
        let dir = tmp("specdex_curator_traversal");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("report-2026-06-05T10-00-00.md"), "real").unwrap();
        let reports = list_curator_reports_from(&dir).unwrap();
        let traversal_found = reports.iter().any(|r| r.id.contains(".."));
        assert!(!traversal_found);
        let _ = std::fs::remove_dir_all(&dir);
    }
}

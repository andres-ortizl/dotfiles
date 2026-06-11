//! The fleet view-model: the serializable snapshot the CLI (`dex ls`/`dex watch`)
//! and the desktop app both render. One shape, derived from the per-spec state.

use chrono::{DateTime, Utc};
use serde::Serialize;

use crate::event::StoryStatus;
use crate::state::SpecState;

#[derive(Debug, Clone, Serialize)]
pub struct AgentView {
    pub role: String,
    pub active: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct FleetRow {
    pub project: String,
    pub name: String,
    pub phase: String,
    pub mode: String,
    pub health: String,
    pub agents: Vec<AgentView>,
    pub pr: Option<u64>,
    pub pr_state: Option<String>,
    pub blocked_reason: Option<String>,
    pub review_round: u32,
    pub review_score: Option<u8>,
    pub offset: Option<u16>,
    /// Build-story progress within the build phase (done / total). 0/0 when the
    /// spec uses no story breakdown. The supervisor reads `done < total` (with a
    /// stale `build` phase) to decide a spec needs resuming; the desktop renders it.
    pub stories_done: usize,
    pub stories_total: usize,
    /// RFC3339 timestamp of the last event — the frontend uses this to decide
    /// whether the life-dot should *breathe* (recent activity) or sit calm. Motion
    /// = real liveness, NOT the health label.
    pub updated_at: String,
}

/// Build the sorted fleet view from raw spec states, deriving health at `now`.
pub fn fleet_snapshot(specs: Vec<SpecState>, now: DateTime<Utc>, stale_secs: i64) -> Vec<FleetRow> {
    let mut rows: Vec<FleetRow> = specs
        .into_iter()
        .map(|s| {
            let health = s.health(now, stale_secs).label().to_string();
            let phase = s.phase.as_str().to_string();
            let mode = s.mode.as_str().to_string();
            let pr = s.pr.as_ref().map(|p| p.number);
            let pr_state = s.pr.as_ref().map(|p| p.state.as_str().to_string());
            let stories_total = s.stories.len();
            let stories_done = s.stories.iter().filter(|st| st.status == StoryStatus::Done).count();
            // A terminal spec has no live agents. `active` is sticky — set on
            // AgentSpawn, cleared only by an AgentIdle a finishing loop often
            // omits — so a done spec would otherwise still report green workers.
            let terminal = s.phase.is_terminal();
            let agents = s
                .agents
                .into_iter()
                .map(|a| AgentView { role: a.role, active: a.active && !terminal })
                .collect();
            FleetRow {
                project: s.project,
                name: s.name,
                phase,
                mode,
                health,
                agents,
                pr,
                pr_state,
                blocked_reason: s.blocked_reason,
                review_round: s.review_round,
                review_score: s.review_score,
                offset: s.offset,
                stories_done,
                stories_total,
                updated_at: s.updated_at.to_rfc3339(),
            }
        })
        .collect();
    rows.sort_by(|a, b| a.project.cmp(&b.project).then(a.name.cmp(&b.name)));
    rows
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::event::{Payload, Phase, Role};

    #[test]
    fn snapshot_sorts_and_derives_health() {
        let now = Utc::now();
        let mut blocked = SpecState::new("z-proj".into(), "b".into(), now);
        blocked.apply(&Payload::PhaseEnter { phase: Phase::Review, reason: None }, now);
        blocked.apply(&Payload::Block { reason: "stuck".into() }, now);
        let done = SpecState::new("a-proj".into(), "d".into(), now);
        let rows = fleet_snapshot(vec![blocked, done], now, 900);
        assert_eq!(rows[0].project, "a-proj"); // sorted
        assert_eq!(rows[1].health, "needs-you");
        assert_eq!(rows[1].blocked_reason.as_deref(), Some("stuck"));
    }

    #[test]
    fn terminal_spec_reports_no_active_agents() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        s.apply(&Payload::AgentSpawn { role: Role::Coder, agent_id: None }, now);
        s.apply(&Payload::AgentSpawn { role: Role::Reviewer, agent_id: None }, now);
        // the loop finished but never emitted AgentIdle — the flag stays sticky-true
        s.apply(&Payload::PhaseEnter { phase: Phase::Accepted, reason: None }, now);
        assert!(s.agents.iter().all(|a| a.active), "precondition: flags still sticky-true");

        let rows = fleet_snapshot(vec![s], now, 300);
        assert!(
            rows[0].agents.iter().all(|a| !a.active),
            "a terminal spec must report no live agents"
        );
    }

    #[test]
    fn story_progress_counts_done_over_total() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        s.apply(&Payload::StoryAdd { id: "S1".into(), title: "a".into() }, now);
        s.apply(&Payload::StoryAdd { id: "S2".into(), title: "b".into() }, now);
        s.apply(&Payload::StoryDone { id: "S1".into(), commit: None }, now);
        let rows = fleet_snapshot(vec![s], now, 900);
        assert_eq!(rows[0].stories_total, 2);
        assert_eq!(rows[0].stories_done, 1);
    }

    #[test]
    fn live_spec_keeps_active_agents() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        s.apply(&Payload::AgentSpawn { role: Role::Coder, agent_id: None }, now);
        s.apply(&Payload::PhaseEnter { phase: Phase::Build, reason: None }, now);

        let rows = fleet_snapshot(vec![s], now, 300);
        assert!(
            rows[0].agents.iter().any(|a| a.active),
            "a building spec keeps its active coder"
        );
    }
}

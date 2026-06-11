//! The derived snapshot. `state.json` is the last-known state of a spec, rewritten
//! on every event so the fleet view is a single cheap read per spec — no log scan.

use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::event::{Payload, Phase, PrState, SpecMode, StoryStatus};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentSnapshot {
    pub role: String,
    pub active: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub agent_id: Option<String>,
    pub since: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorySnapshot {
    pub id: String,
    pub title: String,
    pub status: StoryStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub commit: Option<String>,
    pub since: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrRef {
    pub number: u64,
    pub url: String,
    #[serde(default)]
    pub state: PrState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestSummary {
    pub passed: u32,
    pub failed: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GateSummary {
    pub provider: String,
    pub result: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpecState {
    pub project: String,
    pub name: String,
    pub phase: Phase,
    #[serde(default)]
    pub mode: SpecMode,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub branch: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub worktree: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub offset: Option<u16>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ports: Option<BTreeMap<String, u16>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub pr: Option<PrRef>,
    #[serde(default)]
    pub review_round: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub review_score: Option<u8>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub blocked_reason: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_test: Option<TestSummary>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_gate: Option<GateSummary>,
    #[serde(default)]
    pub agents: Vec<AgentSnapshot>,
    #[serde(default)]
    pub stories: Vec<StorySnapshot>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_heartbeat: Option<DateTime<Utc>>,
}

impl SpecState {
    pub fn new(project: String, name: String, now: DateTime<Utc>) -> Self {
        SpecState {
            project,
            name,
            phase: Phase::Setup,
            mode: SpecMode::Autonomous,
            branch: None,
            worktree: None,
            session_id: None,
            offset: None,
            ports: None,
            pr: None,
            review_round: 0,
            review_score: None,
            blocked_reason: None,
            last_test: None,
            last_gate: None,
            agents: Vec::new(),
            stories: Vec::new(),
            created_at: now,
            updated_at: now,
            last_heartbeat: None,
        }
    }

    pub fn apply(&mut self, p: &Payload, now: DateTime<Utc>) {
        self.updated_at = now;
        match p {
            Payload::Init { branch, worktree, mode, session_id } => {
                self.branch = Some(branch.clone());
                self.worktree = Some(worktree.clone());
                self.mode = *mode;
                if session_id.is_some() {
                    self.session_id = session_id.clone();
                }
            }
            Payload::PortsAssigned { offset, ports } => {
                self.offset = Some(*offset);
                self.ports = Some(ports.clone());
            }
            Payload::PhaseEnter { phase, .. } => {
                self.phase = *phase;
                self.blocked_reason = None; // moving on clears any block
            }
            Payload::Block { reason } => {
                self.blocked_reason = Some(reason.clone());
            }
            Payload::Unblock => {
                self.blocked_reason = None;
            }
            Payload::Heartbeat => {
                self.last_heartbeat = Some(now);
            }
            Payload::AgentSpawn { role, agent_id } => {
                self.set_agent(role.as_str(), true, agent_id.clone(), now);
            }
            Payload::AgentIdle { role } => {
                self.set_agent(role.as_str(), false, None, now);
            }
            Payload::Test { passed, failed, .. } => {
                self.last_test = Some(TestSummary { passed: *passed, failed: *failed });
            }
            Payload::Review { round, .. } => {
                self.review_round = *round;
            }
            Payload::Gate { provider, result, score, .. } => {
                self.last_gate = Some(GateSummary {
                    provider: provider.as_str().to_string(),
                    result: result.as_str().to_string(),
                });
                if let Some(s) = score {
                    self.review_score = Some(*s);
                }
            }
            Payload::Pr { number, url, state } => {
                self.pr = Some(PrRef { number: *number, url: url.clone(), state: *state });
            }
            Payload::Note { .. } => {} // notes are append-only telemetry; no state fold
            Payload::StoryAdd { id, title } => {
                if !self.stories.iter().any(|s| &s.id == id) {
                    self.stories.push(StorySnapshot {
                        id: id.clone(),
                        title: title.clone(),
                        status: StoryStatus::Pending,
                        commit: None,
                        since: now,
                    });
                }
            }
            Payload::StoryStart { id } => self.set_story(id, StoryStatus::Active, None, now),
            Payload::StoryDone { id, commit } => {
                self.set_story(id, StoryStatus::Done, commit.clone(), now)
            }
        }
    }

    fn set_agent(&mut self, role: &str, active: bool, agent_id: Option<String>, now: DateTime<Utc>) {
        if let Some(a) = self.agents.iter_mut().find(|a| a.role == role) {
            a.active = active;
            if agent_id.is_some() {
                a.agent_id = agent_id;
            }
            a.since = now;
        } else {
            self.agents.push(AgentSnapshot { role: role.to_string(), active, agent_id, since: now });
        }
    }

    fn set_story(&mut self, id: &str, status: StoryStatus, commit: Option<String>, now: DateTime<Utc>) {
        // Only an explicit `story.added` creates a story; a start/done for an unknown id
        // is dropped here (the CLI rejects it at the boundary), matching how `note`
        // tolerates unknown shapes — no ghost stories with empty titles on replay.
        if let Some(s) = self.stories.iter_mut().find(|s| s.id == id) {
            s.status = status;
            if commit.is_some() {
                s.commit = commit;
            }
            s.since = now;
        }
    }

    /// The first story not yet `Done`, in registration order — the next one to
    /// (re)dispatch. Drives `dex story next`; `None` only when every story is done.
    /// An in-progress (`Active`) story counts as un-built, so a run resumed mid-story
    /// re-surfaces it rather than skipping straight to "complete".
    pub fn next_unbuilt_story(&self) -> Option<&StorySnapshot> {
        self.stories.iter().find(|s| s.status != StoryStatus::Done)
    }

    /// Liveness, derived rather than stored. `stale_after_secs` is how long a
    /// non-terminal spec can go without a heartbeat (or any event) before it's
    /// assumed stuck.
    pub fn health(&self, now: DateTime<Utc>, stale_after_secs: i64) -> Health {
        if self.phase.is_terminal() {
            return Health::Done;
        }
        if self.blocked_reason.is_some() {
            return Health::NeedsYou;
        }
        let last = self.last_heartbeat.unwrap_or(self.updated_at);
        if (now - last).num_seconds() > stale_after_secs {
            return Health::Stale;
        }
        if self.agents.iter().any(|a| a.active) {
            Health::Alive
        } else {
            Health::Idle
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Health {
    Done,
    NeedsYou,
    Stale,
    Alive,
    Idle,
}

impl Health {
    pub fn label(self) -> &'static str {
        match self {
            Health::Done => "done",
            Health::NeedsYou => "needs-you",
            Health::Stale => "stale",
            Health::Alive => "alive",
            Health::Idle => "idle",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::event::{Payload, SpecMode};
    use chrono::Utc;

    #[test]
    fn init_with_session_id_sets_field() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        assert!(s.session_id.is_none());
        s.apply(
            &Payload::Init {
                branch: "b".into(),
                worktree: "/wt".into(),
                mode: SpecMode::Autonomous,
                session_id: Some("abc123".into()),
            },
            now,
        );
        assert_eq!(s.session_id.as_deref(), Some("abc123"));
    }

    #[test]
    fn init_without_session_id_leaves_field_none() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        s.apply(
            &Payload::Init {
                branch: "b".into(),
                worktree: "/wt".into(),
                mode: SpecMode::Autonomous,
                session_id: None,
            },
            now,
        );
        assert!(s.session_id.is_none());
    }

    #[test]
    fn state_json_backward_compat_missing_session_id() {
        let json = r#"{"project":"p","name":"f","phase":"setup","mode":"autonomous","created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z","agents":[]}"#;
        let s: SpecState = serde_json::from_str(json).expect("old state.json should parse");
        assert!(s.session_id.is_none());
    }

    #[test]
    fn session_id_not_serialized_when_none() {
        let now = Utc::now();
        let s = SpecState::new("p".into(), "f".into(), now);
        let json = serde_json::to_string(&s).unwrap();
        assert!(!json.contains("session_id"));
    }

    #[test]
    fn session_id_serialized_when_some() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        s.apply(
            &Payload::Init {
                branch: "b".into(),
                worktree: "/wt".into(),
                mode: SpecMode::Autonomous,
                session_id: Some("xyz".into()),
            },
            now,
        );
        let json = serde_json::to_string(&s).unwrap();
        assert!(json.contains("\"session_id\":\"xyz\""));
    }

    #[test]
    fn story_lifecycle_derives_status_and_next() {
        let now = Utc::now();
        let mut s = SpecState::new("p".into(), "f".into(), now);
        s.apply(&Payload::StoryAdd { id: "S1".into(), title: "a".into() }, now);
        s.apply(&Payload::StoryAdd { id: "S2".into(), title: "b".into() }, now);
        // re-adding the same id is idempotent — no duplicate
        s.apply(&Payload::StoryAdd { id: "S1".into(), title: "a".into() }, now);
        assert_eq!(s.stories.len(), 2);
        assert_eq!(s.next_unbuilt_story().unwrap().id, "S1");

        // an in-progress (Active) story is still "unbuilt" — next re-surfaces it
        s.apply(&Payload::StoryStart { id: "S1".into() }, now);
        assert_eq!(s.stories[0].status, StoryStatus::Active);
        assert_eq!(s.next_unbuilt_story().unwrap().id, "S1");

        s.apply(&Payload::StoryDone { id: "S1".into(), commit: Some("sha1".into()) }, now);
        assert_eq!(s.stories[0].status, StoryStatus::Done);
        assert_eq!(s.stories[0].commit.as_deref(), Some("sha1"));
        assert_eq!(s.next_unbuilt_story().unwrap().id, "S2");

        s.apply(&Payload::StoryDone { id: "S2".into(), commit: None }, now);
        assert!(s.next_unbuilt_story().is_none());

        // start/done on an unregistered id is ignored at the state layer (no ghost story)
        s.apply(&Payload::StoryStart { id: "S9".into() }, now);
        assert_eq!(s.stories.len(), 2);
    }

    #[test]
    fn state_json_backward_compat_missing_stories() {
        let json = r#"{"project":"p","name":"f","phase":"build","mode":"autonomous","created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z","agents":[]}"#;
        let s: SpecState = serde_json::from_str(json).expect("old state.json should parse");
        assert!(s.stories.is_empty());
    }
}

//! The event vocabulary — the single contract shared by the producer (`dex`,
//! called from the /spec skill) and every consumer (CLI, future desktop app).
//!
//! Wire shape is CloudEvents-flavored (`type`, `time`, `source`, `subject`, `data`)
//! but the `data` payload is domain-specific. The substrate is vendor-agnostic: it
//! never names Greptile, Slack, or a specific CI — it records generic facts (a
//! `verify` phase, a `gate` from provider `ci` or `review`). Which concrete tool
//! fulfills each role is config, consumed by the skill, not the substrate.
//!
//! Everything is an event; state is always derived, never set directly. There is
//! one operation — record an event — and the variety is the event type.
//!
//! Phases are sequential and non-overlapping, so a `phase.enter` implicitly ends
//! the previous phase. `block` is a flag layered on the current phase, not a phase.

use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

/// The lifecycle state machine. Generic activities, no vendor names. A vault may
/// disable phases (e.g. personal specs skip `verify`) but the vocabulary is fixed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Phase {
    Setup,
    Plan,
    Build,
    Review,
    Ship,
    Verify,
    Complete,
    Accepted,
}

impl Phase {
    pub fn as_str(self) -> &'static str {
        match self {
            Phase::Setup => "setup",
            Phase::Plan => "plan",
            Phase::Build => "build",
            Phase::Review => "review",
            Phase::Ship => "ship",
            Phase::Verify => "verify",
            Phase::Complete => "complete",
            Phase::Accepted => "accepted",
        }
    }

    pub fn is_terminal(self) -> bool {
        matches!(self, Phase::Complete | Phase::Accepted)
    }
}

/// How a spec is driven. `Autonomous` is the fleet default (coder/reviewer team,
/// hands-off). `Collaborative` is a human-driven session tracked in the same
/// registry but badged apart — it may run in a worktree or directly on the main
/// checkout, and skips the team/PR automation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum SpecMode {
    #[default]
    Autonomous,
    Collaborative,
}

impl SpecMode {
    pub fn as_str(self) -> &'static str {
        match self {
            SpecMode::Autonomous => "autonomous",
            SpecMode::Collaborative => "collaborative",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    Lead,
    Coder,
    Reviewer,
}

impl Role {
    pub fn as_str(self) -> &'static str {
        match self {
            Role::Lead => "lead",
            Role::Coder => "coder",
            Role::Reviewer => "reviewer",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Verdict {
    Pass,
    Fail,
    PassWithNotes,
}

/// A generic PR gate — the substrate doesn't know CI vs Greptile by vendor, only
/// by role. Config maps `ci` → github-actions, `review` → greptile, etc.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GateProvider {
    Ci,
    Review,
}

impl GateProvider {
    pub fn as_str(self) -> &'static str {
        match self {
            GateProvider::Ci => "ci",
            GateProvider::Review => "review",
        }
    }
}

/// Generic gate outcome — covers both CI conclusions and review outcomes. A skill
/// maps a vendor-specific status (GitHub's `timed_out`, etc.) onto these.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GateResult {
    Success,
    Failure,
    Cancelled,
    Skipped,
    TimedOut,
    Neutral,
    Pending,
}

impl GateResult {
    pub fn as_str(self) -> &'static str {
        match self {
            GateResult::Success => "success",
            GateResult::Failure => "failure",
            GateResult::Cancelled => "cancelled",
            GateResult::Skipped => "skipped",
            GateResult::TimedOut => "timed_out",
            GateResult::Neutral => "neutral",
            GateResult::Pending => "pending",
        }
    }
}

/// Lifecycle of the opened PR. `Open` is the default; the verify/accept phases
/// flip it to `Merged` or `Closed` once the host (e.g. GitHub) reports it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum PrState {
    #[default]
    Open,
    Merged,
    Closed,
}

impl PrState {
    pub fn as_str(self) -> &'static str {
        match self {
            PrState::Open => "open",
            PrState::Merged => "merged",
            PrState::Closed => "closed",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NoteLevel {
    Info,
    Warn,
    Error,
}

/// Greptile-style review scores are 0–5. Returns `None` on an out-of-range value.
pub fn validate_score(s: u8) -> Option<u8> {
    (s <= 5).then_some(s)
}

/// The on-disk wire event (one JSON object per line in `events.jsonl`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    #[serde(rename = "type")]
    pub kind: String,
    pub time: DateTime<Utc>,
    /// CloudEvents "source" = the spec path (always). Do NOT overload with actor.
    pub source: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub subject: Option<String>,
    /// Who emitted this event (lead / coder / reviewer). Separate from `source`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub actor: Option<String>,
    #[serde(default, skip_serializing_if = "Value::is_null")]
    pub data: Value,
}

/// The typed producer side. Each variant maps to one `type` string and renders its
/// own `data`. This is what the CLI builds from args.
#[derive(Debug, Clone)]
pub enum Payload {
    Init { branch: String, worktree: String, mode: SpecMode, session_id: Option<String> },
    PortsAssigned { offset: u16, ports: BTreeMap<String, u16> },
    PhaseEnter { phase: Phase, reason: Option<String> },
    Block { reason: String },
    Unblock,
    Heartbeat,
    AgentSpawn { role: Role, agent_id: Option<String> },
    AgentIdle { role: Role },
    Test { passed: u32, failed: u32, cmd: Option<String> },
    Review { round: u32, verdict: Verdict, blockers: u32, issues: u32 },
    Gate { provider: GateProvider, name: Option<String>, result: GateResult, score: Option<u8> },
    Pr { number: u64, url: String, state: PrState },
    Note { level: NoteLevel, topic: String, text: String, scope: Option<String> },
}

impl Payload {
    pub fn kind(&self) -> &'static str {
        match self {
            Payload::Init { .. } => "spec.created",
            Payload::PortsAssigned { .. } => "ports.assigned",
            Payload::PhaseEnter { .. } => "phase.enter",
            Payload::Block { .. } => "spec.blocked",
            Payload::Unblock => "spec.unblocked",
            Payload::Heartbeat => "heartbeat",
            Payload::AgentSpawn { .. } => "agent.spawn",
            Payload::AgentIdle { .. } => "agent.idle",
            Payload::Test { .. } => "test.result",
            Payload::Review { .. } => "review.verdict",
            Payload::Gate { .. } => "gate.status",
            Payload::Pr { .. } => "pr.created",
            Payload::Note { .. } => "note",
        }
    }

    pub fn subject(&self) -> Option<String> {
        match self {
            Payload::AgentSpawn { role, .. } | Payload::AgentIdle { role } => {
                Some(role.as_str().to_string())
            }
            Payload::Gate { provider, .. } => Some(provider.as_str().to_string()),
            _ => None,
        }
    }

    pub fn data(&self) -> Value {
        match self {
            Payload::Init { branch, worktree, mode, session_id } => {
                let mut m = json!({ "branch": branch, "worktree": worktree, "mode": mode });
                if let Some(id) = session_id {
                    m["session_id"] = json!(id);
                }
                m
            }
            Payload::PortsAssigned { offset, ports } => {
                json!({ "offset": offset, "ports": ports })
            }
            Payload::PhaseEnter { phase, reason } => {
                let mut m = json!({ "phase": phase });
                if let Some(r) = reason {
                    m["reason"] = json!(r);
                }
                m
            }
            Payload::Block { reason } => json!({ "reason": reason }),
            Payload::Unblock => Value::Null,
            Payload::Heartbeat => Value::Null,
            Payload::AgentSpawn { role, agent_id } => json!({ "role": role, "agent_id": agent_id }),
            Payload::AgentIdle { role } => json!({ "role": role }),
            Payload::Test { passed, failed, cmd } => {
                json!({ "passed": passed, "failed": failed, "cmd": cmd })
            }
            Payload::Review { round, verdict, blockers, issues } => {
                json!({ "round": round, "verdict": verdict, "blockers": blockers, "issues": issues })
            }
            Payload::Gate { provider, name, result, score } => {
                json!({ "provider": provider, "name": name, "result": result, "score": score })
            }
            Payload::Pr { number, url, state } => {
                json!({ "number": number, "url": url, "state": state })
            }
            Payload::Note { level, topic, text, scope } => {
                let mut m = json!({ "level": level, "topic": topic, "text": text });
                if let Some(s) = scope {
                    m["scope"] = json!(s);
                }
                m
            }
        }
    }

    pub fn into_event(self, source: String, actor: Option<String>, time: DateTime<Utc>) -> Event {
        Event {
            kind: self.kind().to_string(),
            time,
            source,
            subject: self.subject(),
            actor,
            data: self.data(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    #[test]
    fn init_data_includes_session_id_when_some() {
        let p = Payload::Init {
            branch: "b".into(),
            worktree: "/wt".into(),
            mode: SpecMode::Autonomous,
            session_id: Some("abc123".into()),
        };
        let data = p.data();
        assert_eq!(data["session_id"], "abc123");
    }

    #[test]
    fn init_data_omits_session_id_when_none() {
        let p = Payload::Init {
            branch: "b".into(),
            worktree: "/wt".into(),
            mode: SpecMode::Autonomous,
            session_id: None,
        };
        let data = p.data();
        assert!(data["session_id"].is_null());
    }

    #[test]
    fn init_event_backward_compat_parses_without_session_id() {
        let line = r#"{"type":"spec.created","time":"2024-01-01T00:00:00Z","source":"dex","data":{"branch":"b","worktree":"/wt","mode":"autonomous"}}"#;
        let ev: Event = serde_json::from_str(line).expect("old event should parse");
        assert_eq!(ev.kind, "spec.created");
        assert_eq!(ev.data["branch"], "b");
        assert!(ev.data["session_id"].is_null());
    }

    #[test]
    fn init_event_roundtrip_with_session_id() {
        let p = Payload::Init {
            branch: "feat".into(),
            worktree: "/wt".into(),
            mode: SpecMode::Autonomous,
            session_id: Some("sid1".into()),
        };
        let ev = p.into_event("dex".into(), None, Utc::now());
        let json = serde_json::to_string(&ev).unwrap();
        let back: Event = serde_json::from_str(&json).unwrap();
        assert_eq!(back.data["session_id"], "sid1");
    }

    #[test]
    fn actor_set_in_event() {
        let p = Payload::Heartbeat;
        let ev = p.into_event("/spec/p/f".into(), Some("coder".into()), Utc::now());
        assert_eq!(ev.actor.as_deref(), Some("coder"));
        assert_eq!(ev.source, "/spec/p/f");
    }

    #[test]
    fn actor_none_when_not_provided() {
        let p = Payload::Heartbeat;
        let ev = p.into_event("/spec/p/f".into(), None, Utc::now());
        assert!(ev.actor.is_none());
    }

    #[test]
    fn actor_not_serialized_when_none() {
        let p = Payload::Heartbeat;
        let ev = p.into_event("/spec/p/f".into(), None, Utc::now());
        let json = serde_json::to_string(&ev).unwrap();
        assert!(!json.contains("actor"));
    }

    #[test]
    fn actor_serialized_and_roundtrips() {
        let p = Payload::Heartbeat;
        let ev = p.into_event("/spec/p/f".into(), Some("reviewer".into()), Utc::now());
        let json = serde_json::to_string(&ev).unwrap();
        let back: Event = serde_json::from_str(&json).unwrap();
        assert_eq!(back.actor.as_deref(), Some("reviewer"));
        assert_eq!(back.source, "/spec/p/f");
    }

    #[test]
    fn old_event_without_actor_parses_as_none() {
        let line = r#"{"type":"heartbeat","time":"2024-01-01T00:00:00Z","source":"/spec/p/f"}"#;
        let ev: Event = serde_json::from_str(line).expect("old event should parse");
        assert!(ev.actor.is_none());
        assert_eq!(ev.source, "/spec/p/f");
    }

    #[test]
    fn source_and_actor_are_distinct_fields() {
        let p = Payload::Heartbeat;
        let ev = p.into_event("/spec/proj/feat".into(), Some("lead".into()), Utc::now());
        assert_eq!(ev.source, "/spec/proj/feat");
        assert_eq!(ev.actor.as_deref(), Some("lead"));
    }

    #[test]
    fn note_scope_recorded_in_data() {
        let p = Payload::Note { level: NoteLevel::Warn, topic: "env/git".into(), text: "t".into(), scope: Some("skill".into()) };
        assert_eq!(p.data()["scope"], "skill");
    }

    #[test]
    fn note_scope_absent_when_none() {
        let p = Payload::Note { level: NoteLevel::Info, topic: "t".into(), text: "x".into(), scope: None };
        assert!(p.data()["scope"].is_null());
    }

    #[test]
    fn old_note_without_scope_parses_as_event() {
        let line = r#"{"type":"note","time":"2024-01-01T00:00:00Z","source":"/spec/p/f","data":{"level":"warn","topic":"test","text":"old note"}}"#;
        let ev: Event = serde_json::from_str(line).expect("old note should parse");
        assert_eq!(ev.kind, "note");
        assert!(ev.data["scope"].is_null());
    }
}

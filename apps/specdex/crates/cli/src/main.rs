use std::sync::mpsc::channel;

use anyhow::{anyhow, Result};
use chrono::Utc;
use clap::{Parser, Subcommand};
use include_dir::{include_dir, Dir};
use notify::{RecursiveMode, Watcher};
use specdex_core::{
    emit, fleet_snapshot, get_dotted, load_all, load_effective, load_lesson, load_lessons,
    load_state, paths, pick_offset, save_lesson, schema, validate, validate_score, Anchor,
    GateProvider, GateResult, Lesson, NoteLevel, Payload, Phase, PrState, Role, SpecMode, Verdict,
};

// The skill source + agents moved into the dotfiles tree (config/claude/{skills/specdex,agents}).
// From this crate (apps/specdex/crates/cli) the dotfiles root is four levels up.
static SKILL_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/../../../../config/claude/skills/specdex");
static AGENTS_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/../../../../config/claude/agents");

/// Resource-verb CLI. The target spec is ambient: set `DEX_SPEC=<project>/<name>`
/// once (or pass `-s`). Every write is an event; state is derived.
#[derive(Parser)]
#[command(name = "dex", about = "Spec event substrate — record events, view the fleet")]
struct Cli {
    /// Target spec as <project>/<name> (defaults to $DEX_SPEC)
    #[arg(short, long, global = true, env = "DEX_SPEC")]
    spec: Option<String>,
    /// Actor emitting this event: lead | coder | reviewer (defaults to $DEX_ACTOR)
    #[arg(long, global = true, env = "DEX_ACTOR")]
    actor: Option<String>,
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Register the worktree: branch + path (emits spec.created)
    Init {
        #[arg(long)]
        branch: String,
        #[arg(long)]
        worktree: String,
        /// Mark this as a human-driven session (badged apart from autonomous minions)
        #[arg(long)]
        collaborative: bool,
        /// Claude Code session id for session resumption (value of $CLAUDE_CODE_SESSION_ID)
        #[arg(long)]
        session: Option<String>,
    },
    /// Port allocation
    Ports {
        #[command(subcommand)]
        op: PortsOp,
    },
    /// Set the lifecycle phase (setup|plan|build|review|ship|verify|complete|accepted)
    Phase {
        phase: String,
        #[arg(long)]
        reason: Option<String>,
    },
    /// Flag the spec as blocked on the human
    Block { reason: String },
    /// Clear the blocked flag
    Unblock,
    /// Liveness ping (phase is read from state — no need to repeat it)
    Beat,
    /// Agent activity
    Agent {
        #[command(subcommand)]
        op: AgentOp,
    },
    /// Build-story progress within the build phase (add|start|done|ls|next)
    Story {
        #[command(subcommand)]
        op: StoryOp,
    },
    /// Record a test run
    Test {
        #[arg(long)]
        passed: u32,
        #[arg(long)]
        failed: u32,
        #[arg(long)]
        cmd: Option<String>,
    },
    /// Record a reviewer verdict
    Review {
        #[arg(long)]
        round: u32,
        #[arg(long)]
        verdict: String,
        #[arg(long, default_value_t = 0)]
        blockers: u32,
        #[arg(long, default_value_t = 0)]
        issues: u32,
    },
    /// Record a PR gate outcome (provider: ci|review)
    Gate {
        #[arg(long)]
        provider: String,
        #[arg(long)]
        name: Option<String>,
        #[arg(long)]
        result: String,
        #[arg(long)]
        score: Option<u8>,
    },
    /// Record the PR (state: open|merged|closed — flip to merged once the host reports it)
    Pr {
        #[arg(long)]
        number: u64,
        #[arg(long)]
        url: String,
        #[arg(long, default_value = "open")]
        state: String,
    },
    /// Record a freeform observation (the watcher feed)
    Note {
        #[arg(long, default_value = "info")]
        level: String,
        #[arg(long)]
        topic: String,
        #[arg(long)]
        text: String,
        #[arg(long)]
        scope: Option<String>,
    },
    /// Aggregate notes across all specs in the registry
    Notes {
        /// Filter by scope (spec|project|skill)
        #[arg(long)]
        scope: Option<String>,
        /// Filter by topic
        #[arg(long)]
        topic: Option<String>,
        /// Filter by level (info|warn|error)
        #[arg(long)]
        level: Option<String>,
        /// Output as JSON
        #[arg(long)]
        json: bool,
    },
    /// Manage per-project lessons (durable insights)
    Lessons {
        #[command(subcommand)]
        op: LessonsOp,
    },
    /// List every spec in the fleet with derived health
    Ls {
        /// Emit the fleet as JSON (the same shape `dex watch` streams)
        #[arg(long)]
        json: bool,
    },
    /// Stream the fleet snapshot as JSON, re-emitting on every registry change
    Watch,
    /// Inspect merged effective config
    Config {
        #[command(subcommand)]
        op: ConfigOp,
    },
    /// Install specdex agents, skill, and config scaffold into ~/.claude and ~/.config/dex
    Install {
        /// Overwrite the skill even if ~/.claude/skills/specdex already exists (re-sync)
        #[arg(long)]
        update: bool,
    },
}

#[derive(Subcommand)]
enum ConfigOp {
    /// Write a commented .dex.toml template to the current directory
    Init {
        /// Overwrite an existing .dex.toml
        #[arg(long)]
        force: bool,
    },
    /// Print the merged effective config as JSON
    Show,
    /// Print a single dotted key (e.g. providers.notifier, providers.pr_review.reactor)
    Get { key: String },
    /// Validate config and exit nonzero on any violation
    Validate,
    /// Print the machine-readable config surface (valid providers, hooks, phases)
    Schema,
}

#[derive(Subcommand)]
enum PortsOp {
    /// Allocate a free, collision-aware port offset; records it and prints `export` lines
    Alloc,
}

#[derive(Subcommand)]
enum AgentOp {
    /// A teammate started working
    Spawn {
        role: String,
        #[arg(long)]
        id: Option<String>,
    },
    /// A teammate went idle
    Idle { role: String },
}

#[derive(Subcommand)]
enum StoryOp {
    /// Register a build story (emits story.added)
    Add {
        #[arg(long)]
        id: String,
        #[arg(long)]
        title: String,
    },
    /// Mark a story in progress
    Start { id: String },
    /// Mark a story complete (optionally record its commit sha)
    Done {
        id: String,
        #[arg(long)]
        commit: Option<String>,
    },
    /// List the spec's stories with status
    Ls,
    /// Print the next un-built story (`<id> <title>`); empty + exit 1 when all are done
    Next,
}

#[derive(Subcommand)]
enum LessonsOp {
    /// List lessons for a project
    List {
        #[arg(long)]
        project: Option<String>,
        #[arg(long)]
        scope: Option<String>,
        #[arg(long)]
        state: Option<String>,
        #[arg(long)]
        json: bool,
    },
    /// Show a single lesson
    Show {
        #[arg(long)]
        project: Option<String>,
        id: String,
    },
    /// Add a new lesson
    Add {
        #[arg(long)]
        project: Option<String>,
        #[arg(long)]
        scope: String,
        #[arg(long)]
        trigger: String,
        #[arg(long = "abstract")]
        summary: String,
        #[arg(long)]
        insight: String,
        #[arg(long)]
        name: Option<String>,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Ls { json } => return ls(json),
        Cmd::Watch => return watch(),
        Cmd::Config { ref op } => return config_cmd(op),
        Cmd::Install { ref update } => return install(*update),
        Cmd::Notes { ref scope, ref topic, ref level, json } => {
            return notes_cmd(scope.as_deref(), topic.as_deref(), level.as_deref(), json);
        }
        Cmd::Lessons { ref op } => {
            return lessons_cmd(op, cli.spec.as_deref());
        }
        _ => {}
    }
    let spec = cli
        .spec
        .ok_or_else(|| anyhow!("no target spec — set DEX_SPEC=<project>/<name> or pass -s"))?;
    let actor = cli.actor.as_deref();
    let (project, name) = split_spec(&spec)?;
    if let Cmd::Ports { op } = cli.cmd {
        return ports_cmd(&project, &name, op, actor);
    }
    if let Cmd::Story { op } = cli.cmd {
        return story_cmd(&project, &name, op, actor);
    }
    let payload = build_payload(cli.cmd)?;
    let state = emit(&project, &name, payload, actor)?;
    println!("{spec} → {}", state.phase.as_str());
    Ok(())
}

fn ports_cmd(project: &str, name: &str, op: PortsOp, actor: Option<&str>) -> Result<()> {
    match op {
        PortsOp::Alloc => {
            let eff = load_effective(&std::env::current_dir()?)?;
            if eff.ports.is_empty() {
                eprintln!("# no [ports] configured for this project");
                return Ok(());
            }
            let used = used_offsets(project, name)?;
            let (offset, map) = pick_offset(&eff.ports, &used, 10, 990, port_is_free)
                .ok_or_else(|| anyhow!("no free port offset found up to 990"))?;
            emit(project, name, Payload::PortsAssigned { offset, ports: map.clone() }, actor)?;
            for ps in &eff.ports {
                if let Some(p) = map.get(&ps.service) {
                    println!("export {}={}", ps.env, p);
                }
            }
            Ok(())
        }
    }
}

/// Offsets reserved by other active (non-terminal) specs across the whole registry.
fn used_offsets(self_project: &str, self_name: &str) -> Result<Vec<u16>> {
    Ok(load_all()?
        .into_iter()
        .filter(|s| !(s.project == self_project && s.name == self_name))
        .filter(|s| !s.phase.is_terminal())
        .filter_map(|s| s.offset)
        .collect())
}

fn port_is_free(port: u16) -> bool {
    std::net::TcpListener::bind(("127.0.0.1", port)).is_ok()
}

fn story_cmd(project: &str, name: &str, op: StoryOp, actor: Option<&str>) -> Result<()> {
    match op {
        StoryOp::Add { id, title } => {
            // Best-effort duplicate guard — a racing concurrent add could slip past it,
            // but apply() is idempotent on id, so the snapshot stays correct regardless.
            if let Some(st) = load_state(project, name)? {
                if st.stories.iter().any(|s| s.id == id) {
                    return Err(anyhow!("story {id:?} already registered"));
                }
            }
            let state = emit(project, name, Payload::StoryAdd { id: id.clone(), title }, actor)?;
            println!("story {id} registered ({} total)", state.stories.len());
            Ok(())
        }
        StoryOp::Start { id } => {
            require_story(project, name, &id)?;
            emit(project, name, Payload::StoryStart { id }, actor)?;
            Ok(())
        }
        StoryOp::Done { id, commit } => {
            require_story(project, name, &id)?;
            emit(project, name, Payload::StoryDone { id, commit }, actor)?;
            Ok(())
        }
        StoryOp::Ls => {
            let st = load_state(project, name)?
                .ok_or_else(|| anyhow!("no state for {project}/{name}"))?;
            if st.stories.is_empty() {
                println!("No stories registered — add them with `dex story add --id S1 --title …`.");
                return Ok(());
            }
            for s in &st.stories {
                let commit = s.commit.as_deref().map(|c| format!("  {c}")).unwrap_or_default();
                println!("{:<6} {:<8} {}{}", s.id, s.status.as_str(), s.title, commit);
            }
            Ok(())
        }
        StoryOp::Next => {
            let st = load_state(project, name)?
                .ok_or_else(|| anyhow!("no state for {project}/{name}"))?;
            match st.next_unbuilt_story() {
                Some(s) => {
                    println!("{} {}", s.id, s.title);
                    Ok(())
                }
                None => std::process::exit(1),
            }
        }
    }
}

/// Reject a `start`/`done` on a story id that was never registered (`dex story add`).
fn require_story(project: &str, name: &str, id: &str) -> Result<()> {
    let st = load_state(project, name)?.ok_or_else(|| {
        anyhow!("no state for {project}/{name} — register stories with `dex story add` first")
    })?;
    if !st.stories.iter().any(|s| s.id == id) {
        return Err(anyhow!("unknown story id {id:?} — add it with `dex story add` first"));
    }
    Ok(())
}

const DEX_TOML_TEMPLATE: &str = r#"# .dex.toml — specdex project config. See `dex config schema`.
[providers]
notifier  = "none"   # slack | discord | none
ci        = "none"   # github-actions | none
pr_review = "none"   # greptile | coderabbit | none

# [[ports]]            # services this project runs locally (a CLI/lib declares none)
# service = "frontend"
# base    = 5173
# env     = "VITE_PORT"

# [phases]
# skip = ["verify"]    # phases to skip entirely

# [models]             # per-project agent model: opus | sonnet | haiku | inherit
# coder    = "sonnet"
# reviewer = "opus"

# [hooks]
# on_ship = "/pr"

# [identity]
# github_org = "your-org"
"#;

fn config_cmd(op: &ConfigOp) -> Result<()> {
    let cwd = std::env::current_dir()?;
    match op {
        ConfigOp::Init { force } => {
            let dest = cwd.join(".dex.toml");
            if dest.exists() && !force {
                return Err(anyhow!("{} already exists (use --force to overwrite)", dest.display()));
            }
            std::fs::write(&dest, DEX_TOML_TEMPLATE)?;
            println!("wrote {}", dest.display());
            return Ok(());
        }
        ConfigOp::Show => {
            let eff = load_effective(&cwd)?;
            println!("{}", serde_json::to_string_pretty(&eff)?);
        }
        ConfigOp::Get { key } => {
            let eff = load_effective(&cwd)?;
            println!("{}", get_dotted(&eff, key)?);
        }
        ConfigOp::Validate => {
            let eff = load_effective(&cwd)?;
            validate(&eff)?;
            // Warn (don't fail) on referenced skills that aren't installed.
            if let Some(home) = dirs::home_dir() {
                let skills = home.join(".claude").join("skills");
                for s in specdex_core::referenced_skills(&eff) {
                    if !skills.join(s.trim_start_matches('/')).exists() {
                        eprintln!("warning: referenced skill {s} not found in ~/.claude/skills");
                    }
                }
            }
            println!("ok");
        }
        ConfigOp::Schema => {
            println!("{}", serde_json::to_string_pretty(&schema())?);
        }
    }
    Ok(())
}

fn install(update: bool) -> Result<()> {
    let home = dirs::home_dir().ok_or_else(|| anyhow!("cannot determine home directory"))?;

    let agents_dir = home.join(".claude").join("agents");
    std::fs::create_dir_all(&agents_dir)?;

    let mut agents_written = 0usize;
    for file in AGENTS_DIR.files() {
        let filename = file.path().file_name().unwrap_or_default();
        if !filename.to_string_lossy().starts_with("dex-") {
            continue; // ship only specdex's own agents, not other dotfiles agents
        }
        let dest = agents_dir.join(filename);
        std::fs::write(&dest, file.contents())?;
        println!("  wrote {}", dest.display());
        agents_written += 1;
    }

    let skill_dest = home.join(".claude").join("skills").join("specdex");
    if skill_dest.exists() && !update {
        println!(
            "warning: ~/.claude/skills/specdex already exists (e.g. a dotfiles symlink) — \
re-run `dex install --update` to overwrite it, or remove it to let specdex manage the skill"
        );
    } else {
        std::fs::create_dir_all(&skill_dest)?;
        if let Some(skill_md) = SKILL_DIR.get_file("SKILL.md") {
            let dest = skill_dest.join("SKILL.md");
            std::fs::write(&dest, skill_md.contents())?;
            println!("  wrote {}", dest.display());
        }
        if let Some(reference_dir) = SKILL_DIR.get_dir("reference") {
            let ref_dest = skill_dest.join("reference");
            std::fs::create_dir_all(&ref_dest)?;
            for file in reference_dir.files() {
                let filename = file.path().file_name().unwrap_or_default();
                let dest = ref_dest.join(filename);
                std::fs::write(&dest, file.contents())?;
                println!("  wrote {}", dest.display());
            }
        }
    }

    // Optional global config — scaffold at the path load_effective reads.
    let config_file = specdex_core::config_path()?;
    if let Some(parent) = config_file.parent() {
        std::fs::create_dir_all(parent)?;
    }
    if !config_file.exists() {
        std::fs::write(
            &config_file,
            "# specdex global defaults (optional) — inherited by every project's .dex.toml\n[providers]\nnotifier = \"none\"\n",
        )?;
        println!("  wrote {}", config_file.display());
    } else {
        println!("  skipped {} (already exists)", config_file.display());
    }

    println!();
    println!("install complete — {} agent(s) written to ~/.claude/agents/", agents_written);
    Ok(())
}

fn build_payload(cmd: Cmd) -> Result<Payload> {
    Ok(match cmd {
        Cmd::Init { branch, worktree, collaborative, session } => Payload::Init {
            branch,
            worktree,
            mode: if collaborative { SpecMode::Collaborative } else { SpecMode::Autonomous },
            session_id: session,
        },
        Cmd::Phase { phase, reason } => Payload::PhaseEnter { phase: parse_phase(&phase)?, reason },
        Cmd::Block { reason } => Payload::Block { reason },
        Cmd::Unblock => Payload::Unblock,
        Cmd::Beat => Payload::Heartbeat,
        Cmd::Agent { op } => match op {
            AgentOp::Spawn { role, id } => {
                Payload::AgentSpawn { role: parse_role(&role)?, agent_id: id }
            }
            AgentOp::Idle { role } => Payload::AgentIdle { role: parse_role(&role)? },
        },
        Cmd::Test { passed, failed, cmd } => Payload::Test { passed, failed, cmd },
        Cmd::Review { round, verdict, blockers, issues } => {
            Payload::Review { round, verdict: parse_verdict(&verdict)?, blockers, issues }
        }
        Cmd::Gate { provider, name, result, score } => {
            let score = match score {
                Some(s) => {
                    Some(validate_score(s).ok_or_else(|| anyhow!("score must be 0–5, got {s}"))?)
                }
                None => None,
            };
            Payload::Gate {
                provider: parse_gate_provider(&provider)?,
                name,
                result: parse_gate_result(&result)?,
                score,
            }
        }
        Cmd::Pr { number, url, state } => Payload::Pr { number, url, state: parse_pr_state(&state)? },
        Cmd::Note { level, topic, text, scope } => {
            let validated_scope = scope.map(|s| parse_scope(&s)).transpose()?;
            Payload::Note { level: parse_level(&level)?, topic, text, scope: validated_scope }
        }
        Cmd::Ls { .. } | Cmd::Watch | Cmd::Config { .. } | Cmd::Ports { .. } | Cmd::Story { .. } | Cmd::Install { .. } | Cmd::Notes { .. } | Cmd::Lessons { .. } => {
            unreachable!("handled before payload build")
        }
    })
}

const STALE_SECS: i64 = 15 * 60;

fn ls(json: bool) -> Result<()> {
    if json {
        return print_fleet_json();
    }
    let rows = fleet_snapshot(load_all()?, Utc::now(), STALE_SECS);
    if rows.is_empty() {
        println!("No specs with state.json yet — run `dex …` from the /spec skill.");
        return Ok(());
    }
    println!("{:<22} {:<28} {:<10} {:<10} {:<8} PR", "PROJECT", "SPEC", "PHASE", "HEALTH", "STORIES");
    for r in rows {
        let pr = r.pr.map(|n| format!("#{n}")).unwrap_or_default();
        let stories = if r.stories_total > 0 {
            format!("{}/{}", r.stories_done, r.stories_total)
        } else {
            String::new()
        };
        println!(
            "{:<22} {:<28} {:<10} {:<10} {:<8} {}",
            trunc(&r.project, 22),
            trunc(&r.name, 28),
            r.phase,
            r.health,
            stories,
            pr
        );
    }
    Ok(())
}

fn print_fleet_json() -> Result<()> {
    let rows = fleet_snapshot(load_all()?, Utc::now(), STALE_SECS);
    println!("{}", serde_json::to_string(&rows)?);
    Ok(())
}

/// Print the fleet snapshot, then re-print on every change under `~/.spec`. This is
/// the exact live feed the desktop app's backend wraps.
fn watch() -> Result<()> {
    print_fleet_json()?;
    let root = paths::spec_root()?;
    if !root.exists() {
        return Ok(());
    }
    let (tx, rx) = channel();
    let mut watcher = notify::recommended_watcher(move |res| {
        let _ = tx.send(res);
    })?;
    watcher.watch(&root, RecursiveMode::Recursive)?;
    while rx.recv().is_ok() {
        while rx.try_recv().is_ok() {} // coalesce a burst of fs events
        print_fleet_json()?;
    }
    Ok(())
}

fn split_spec(s: &str) -> Result<(String, String)> {
    let (p, n) = s
        .split_once('/')
        .ok_or_else(|| anyhow!("--spec must be <project>/<name>, got {s:?}"))?;
    Ok((p.to_string(), n.to_string()))
}

fn parse_phase(s: &str) -> Result<Phase> {
    Ok(match s {
        "setup" => Phase::Setup,
        "plan" => Phase::Plan,
        "build" => Phase::Build,
        "review" => Phase::Review,
        "ship" => Phase::Ship,
        "verify" => Phase::Verify,
        "complete" => Phase::Complete,
        "accepted" => Phase::Accepted,
        o => return Err(anyhow!("unknown phase: {o}")),
    })
}

fn parse_role(s: &str) -> Result<Role> {
    Ok(match s {
        "lead" => Role::Lead,
        "coder" => Role::Coder,
        "reviewer" => Role::Reviewer,
        o => return Err(anyhow!("unknown role: {o}")),
    })
}

fn parse_verdict(s: &str) -> Result<Verdict> {
    Ok(match s {
        "pass" => Verdict::Pass,
        "fail" => Verdict::Fail,
        "pass_with_notes" | "notes" => Verdict::PassWithNotes,
        o => return Err(anyhow!("unknown verdict: {o}")),
    })
}

fn parse_gate_provider(s: &str) -> Result<GateProvider> {
    Ok(match s {
        "ci" => GateProvider::Ci,
        "review" => GateProvider::Review,
        o => return Err(anyhow!("unknown gate provider: {o} (expected ci|review)")),
    })
}

fn parse_gate_result(s: &str) -> Result<GateResult> {
    Ok(match s {
        "success" => GateResult::Success,
        "failure" => GateResult::Failure,
        "cancelled" => GateResult::Cancelled,
        "skipped" => GateResult::Skipped,
        "timed_out" => GateResult::TimedOut,
        "neutral" => GateResult::Neutral,
        "pending" => GateResult::Pending,
        o => return Err(anyhow!("unknown gate result: {o}")),
    })
}

fn parse_pr_state(s: &str) -> Result<PrState> {
    Ok(match s {
        "open" => PrState::Open,
        "merged" => PrState::Merged,
        "closed" => PrState::Closed,
        o => return Err(anyhow!("unknown pr state: {o} (expected open|merged|closed)")),
    })
}

fn parse_level(s: &str) -> Result<NoteLevel> {
    Ok(match s {
        "info" => NoteLevel::Info,
        "warn" => NoteLevel::Warn,
        "error" => NoteLevel::Error,
        o => return Err(anyhow!("unknown note level: {o}")),
    })
}

fn parse_scope(s: &str) -> Result<String> {
    match s {
        "spec" | "project" | "skill" => Ok(s.to_string()),
        o => Err(anyhow!("unknown scope: {o} (expected spec|project|skill)")),
    }
}

fn notes_cmd(scope: Option<&str>, topic: Option<&str>, level: Option<&str>, json: bool) -> Result<()> {
    use specdex_core::{filter_notes, group_by_topic, load_all_notes};
    let all = load_all_notes()?;
    let filtered: Vec<_> = filter_notes(&all, scope, topic, level)
        .into_iter()
        .cloned()
        .collect();

    if json {
        println!("{}", serde_json::to_string(&filtered)?);
        return Ok(());
    }

    if filtered.is_empty() {
        println!("No notes found.");
        return Ok(());
    }

    let groups = group_by_topic(&filtered);
    for (topic_name, notes) in &groups {
        println!("\n{} ({})", topic_name, notes.len());
        for n in notes {
            let scope_str = n.scope.as_deref().unwrap_or("—");
            let actor_str = n.actor.as_deref().unwrap_or("?");
            println!(
                "  [{}] {}/{} · {} · {}",
                n.level, n.project, n.spec, actor_str, scope_str
            );
            println!("       {}", n.text);
            println!("       {}", fmt_ago(&n.time));
        }
    }
    Ok(())
}

fn resolve_project(project: Option<&str>, spec: Option<&str>) -> Result<String> {
    if let Some(p) = project {
        return Ok(p.to_string());
    }
    if let Some(s) = spec {
        if let Some((p, _)) = s.split_once('/') {
            return Ok(p.to_string());
        }
        return Ok(s.to_string());
    }
    Err(anyhow!("no project specified — pass --project or set DEX_SPEC=<project>/<name>"))
}

fn kebab_slug(s: &str) -> String {
    s.chars()
        .map(|c| if c.is_alphanumeric() { c.to_ascii_lowercase() } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|p| !p.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

fn lessons_cmd(op: &LessonsOp, spec: Option<&str>) -> Result<()> {
    match op {
        LessonsOp::List { project, scope, state, json } => {
            let proj = resolve_project(project.as_deref(), spec)?;
            let mut lessons = load_lessons(&proj)?;
            if let Some(s) = scope {
                lessons.retain(|l| &l.scope == s);
            }
            if let Some(st) = state {
                lessons.retain(|l| &l.state == st);
            }
            if *json {
                let view: Vec<_> = lessons
                    .iter()
                    .map(|l| {
                        let mut v = serde_json::to_value(l).unwrap();
                        v["id"] = serde_json::Value::String(l.id.clone());
                        v["insight"] = serde_json::Value::String(l.insight.clone());
                        v
                    })
                    .collect();
                println!("{}", serde_json::to_string(&view)?);
                return Ok(());
            }
            if lessons.is_empty() {
                println!("No lessons found for project {proj:?}.");
                return Ok(());
            }
            println!("{:<28} {:<10} {:<10} {:<40} {}", "ID", "SCOPE", "STATE", "TRIGGER", "CREATED");
            for l in &lessons {
                println!(
                    "{:<28} {:<10} {:<10} {:<40} {}",
                    trunc(&l.id, 28),
                    trunc(&l.scope, 10),
                    trunc(&l.state, 10),
                    trunc(&l.trigger, 40),
                    l.created_at.format("%Y-%m-%d"),
                );
            }
            Ok(())
        }
        LessonsOp::Show { project, id } => {
            let proj = resolve_project(project.as_deref(), spec)?;
            let lesson = load_lesson(&proj, id)?;
            println!("id:       {}", lesson.id);
            println!("scope:    {}", lesson.scope);
            println!("state:    {}", lesson.state);
            println!("trigger:  {}", lesson.trigger);
            println!("abstract: {}", lesson.summary);
            if !lesson.provenance.is_empty() {
                println!("provenance: {}", lesson.provenance.join(", "));
            }
            println!("confidence: {}", lesson.confidence);
            println!("created:  {}", lesson.created_at.format("%Y-%m-%dT%H:%M:%SZ"));
            println!();
            println!("{}", lesson.insight);
            Ok(())
        }
        LessonsOp::Add { project, scope, trigger, summary, insight, name } => {
            let proj = resolve_project(project.as_deref(), spec)?;
            let base_id = name
                .as_deref()
                .map(|n| kebab_slug(n))
                .unwrap_or_else(|| kebab_slug(summary));
            if base_id.is_empty() {
                return Err(anyhow!(
                    "could not derive a lesson id from --abstract/--name; pass --name <slug>"
                ));
            }
            let now = Utc::now();
            let id = pick_lesson_id(&proj, &base_id)?;
            let lesson = Lesson {
                id: id.clone(),
                scope: scope.clone(),
                trigger: trigger.clone(),
                summary: summary.clone(),
                provenance: Vec::new(),
                anchor: Anchor::default(),
                confidence: 0.5,
                state: "active".to_string(),
                created_at: now,
                last_validated_at: now,
                insight: insight.clone(),
            };
            save_lesson(&proj, &lesson)?;
            let path = specdex_core::paths::lesson_path(&proj, &id)?;
            println!("{}", path.display());
            Ok(())
        }
    }
}

fn pick_lesson_id(project: &str, base: &str) -> Result<String> {
    let dir = specdex_core::paths::lessons_dir(project)?;
    let candidate = |suffix: &str| -> std::path::PathBuf {
        dir.join(format!("{base}{suffix}.md"))
    };
    if !candidate("").exists() {
        return Ok(base.to_string());
    }
    for n in 2u32.. {
        let suffix = format!("-{n}");
        if !candidate(&suffix).exists() {
            return Ok(format!("{base}{suffix}"));
        }
    }
    unreachable!()
}

fn fmt_ago(t: &chrono::DateTime<chrono::Utc>) -> String {
    let diff = chrono::Utc::now().signed_duration_since(*t);
    let s = diff.num_seconds();
    if s < 60 {
        return format!("{}s ago", s);
    }
    let m = diff.num_minutes();
    if m < 60 {
        return format!("{}m ago", m);
    }
    let h = diff.num_hours();
    if h < 24 {
        return format!("{}h ago", h);
    }
    format!("{}d ago", diff.num_days())
}

fn trunc(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("{}…", &s[..max - 1])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_scope_accepts_valid_values() {
        assert_eq!(parse_scope("spec").unwrap(), "spec");
        assert_eq!(parse_scope("project").unwrap(), "project");
        assert_eq!(parse_scope("skill").unwrap(), "skill");
    }

    #[test]
    fn parse_scope_rejects_invalid() {
        assert!(parse_scope("bogus").is_err());
        assert!(parse_scope("").is_err());
        assert!(parse_scope("SKILL").is_err());
    }
}

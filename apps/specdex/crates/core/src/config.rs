use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use anyhow::{anyhow, Result};
use serde::{Deserialize, Deserializer, Serialize};
use serde_json;

pub struct ProviderDef {
    pub role: &'static str,
    pub reactor: Option<&'static str>,
}

const REGISTRY: &[(&str, ProviderDef)] = &[
    ("slack", ProviderDef { role: "notifier", reactor: None }),
    ("discord", ProviderDef { role: "notifier", reactor: None }),
    ("none", ProviderDef { role: "notifier", reactor: None }),
    ("github-actions", ProviderDef { role: "ci", reactor: Some("/react-to-pipelines") }),
    ("none", ProviderDef { role: "ci", reactor: None }),
    ("greptile", ProviderDef { role: "pr_review", reactor: Some("/react-to-greptile") }),
    ("coderabbit", ProviderDef { role: "pr_review", reactor: Some("/react-to-coderabbit") }),
    ("none", ProviderDef { role: "pr_review", reactor: None }),
    ("zellij", ProviderDef { role: "multiplexer", reactor: None }),
    ("tmux", ProviderDef { role: "multiplexer", reactor: None }),
    ("none", ProviderDef { role: "multiplexer", reactor: None }),
];

fn lookup(role: &str, name: &str) -> Option<&'static ProviderDef> {
    REGISTRY.iter().find(|(n, d)| *n == name && d.role == role).map(|(_, d)| d)
}

pub fn reactor_for(role: &str, name: &str) -> Option<&'static str> {
    lookup(role, name).and_then(|d| d.reactor)
}

fn valid_for_role(role: &str, name: &str) -> bool {
    lookup(role, name).is_some()
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HookPoint {
    OnShip,
    OnVerifyCi,
    OnVerifyReview,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Action {
    Skill { r#ref: String },
}

impl<'de> Deserialize<'de> for Action {
    fn deserialize<D: Deserializer<'de>>(d: D) -> std::result::Result<Self, D::Error> {
        #[derive(Deserialize)]
        #[serde(untagged)]
        enum Raw {
            Short(String),
            Long { kind: String, r#ref: String },
        }
        match Raw::deserialize(d)? {
            Raw::Short(s) => Ok(Action::Skill { r#ref: s }),
            Raw::Long { kind, r#ref } if kind == "skill" => Ok(Action::Skill { r#ref }),
            Raw::Long { kind, .. } => Err(serde::de::Error::custom(format!("unknown action kind: {kind}"))),
        }
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Providers {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub notifier: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ci: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub pr_review: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub multiplexer: Option<String>,
}

/// A service this project runs locally and the env var its allocated port exports as.
/// Generic — no anyformat/web assumptions; a CLI project simply declares none.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PortSpec {
    pub service: String,
    pub base: u16,
    pub env: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Identity {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub env_file: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub github_org: Option<String>,
}

/// Per-project agent model overrides (opus|sonnet|haiku|inherit). Empty → the
/// agent definition's frontmatter default. Applied at spawn; not mid-flight.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Models {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub coder: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reviewer: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub designer: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub curator: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Terminal {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub program: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Effective {
    #[serde(default)]
    pub providers: Providers,
    #[serde(default)]
    pub hooks: BTreeMap<HookPoint, Action>,
    #[serde(default)]
    pub phases_skip: Vec<String>,
    #[serde(default)]
    pub ports: Vec<PortSpec>,
    #[serde(default)]
    pub identity: Identity,
    #[serde(default)]
    pub models: Models,
    #[serde(default)]
    pub terminal: Terminal,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct Layer {
    #[serde(default)]
    providers: Providers,
    #[serde(default)]
    hooks: BTreeMap<HookPoint, Action>,
    #[serde(default)]
    phases: PhasesLayer,
    #[serde(default)]
    ports: Vec<PortSpec>,
    #[serde(default)]
    identity: Identity,
    #[serde(default)]
    models: Models,
    #[serde(default)]
    terminal: Terminal,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct PhasesLayer {
    #[serde(default)]
    skip: Vec<String>,
}

fn merge(base: Effective, over: Layer) -> Effective {
    Effective {
        providers: Providers {
            notifier: over.providers.notifier.or(base.providers.notifier),
            ci: over.providers.ci.or(base.providers.ci),
            pr_review: over.providers.pr_review.or(base.providers.pr_review),
            multiplexer: over.providers.multiplexer.or(base.providers.multiplexer),
        },
        hooks: {
            let mut h = base.hooks;
            h.extend(over.hooks);
            h
        },
        phases_skip: if !over.phases.skip.is_empty() {
            over.phases.skip
        } else {
            base.phases_skip
        },
        ports: if !over.ports.is_empty() { over.ports } else { base.ports },
        identity: Identity {
            env_file: over.identity.env_file.or(base.identity.env_file),
            github_org: over.identity.github_org.or(base.identity.github_org),
        },
        models: Models {
            coder: over.models.coder.or(base.models.coder),
            reviewer: over.models.reviewer.or(base.models.reviewer),
            designer: over.models.designer.or(base.models.designer),
            curator: over.models.curator.or(base.models.curator),
        },
        terminal: Terminal { program: over.terminal.program.or(base.terminal.program) },
    }
}

const VALID_PHASES: &[&str] =
    &["setup", "plan", "build", "review", "ship", "verify", "complete", "accepted"];

pub fn validate(eff: &Effective) -> Result<()> {
    if let Some(n) = &eff.providers.notifier {
        if !valid_for_role("notifier", n) {
            return Err(anyhow!("unknown notifier provider: {n}"));
        }
    }
    if let Some(n) = &eff.providers.ci {
        if !valid_for_role("ci", n) {
            return Err(anyhow!("unknown ci provider: {n}"));
        }
    }
    if let Some(n) = &eff.providers.pr_review {
        if !valid_for_role("pr_review", n) {
            return Err(anyhow!("unknown pr_review provider: {n}"));
        }
    }
    if let Some(n) = &eff.providers.multiplexer {
        if !valid_for_role("multiplexer", n) {
            return Err(anyhow!("unknown multiplexer provider: {n}"));
        }
    }
    for p in &eff.phases_skip {
        if !VALID_PHASES.contains(&p.as_str()) {
            return Err(anyhow!("invalid phases_skip entry: {p}"));
        }
    }
    let mut seen = std::collections::BTreeSet::new();
    for p in &eff.ports {
        if !seen.insert(&p.service) {
            return Err(anyhow!("duplicate port service: {}", p.service));
        }
    }
    const VALID_MODELS: &[&str] = &["opus", "sonnet", "haiku", "inherit"];
    for (role, m) in [
        ("coder", &eff.models.coder),
        ("reviewer", &eff.models.reviewer),
        ("designer", &eff.models.designer),
        ("curator", &eff.models.curator),
    ] {
        if let Some(m) = m {
            if !VALID_MODELS.contains(&m.as_str()) {
                return Err(anyhow!("invalid model for {role}: {m} (expected opus|sonnet|haiku|inherit)"));
            }
        }
    }
    Ok(())
}

fn merge_layers(layers: Vec<Layer>) -> Effective {
    layers.into_iter().fold(Effective::default(), merge)
}

fn find_project_file(cwd: &Path) -> Option<PathBuf> {
    let mut dir = cwd;
    loop {
        let candidate = dir.join(".dex.toml");
        if candidate.exists() {
            return Some(candidate);
        }
        dir = dir.parent()?;
    }
}

pub fn project_file(cwd: &Path) -> Option<PathBuf> {
    find_project_file(cwd)
}

/// The optional global personal config: machine-wide defaults (notifier, identity)
/// inherited by every project. Single source of truth shared by the loader and
/// `dex install` so the scaffold lands where `load_effective` looks.
pub fn config_path() -> Result<PathBuf> {
    let home = dirs::home_dir().ok_or_else(|| anyhow!("could not resolve home directory"))?;
    Ok(home.join(".config").join("dex").join("config.toml"))
}

fn parse_layer_file(path: &Path) -> Result<Layer> {
    let text = std::fs::read_to_string(path)?;
    toml::from_str(&text).map_err(|e| anyhow!("parsing {}: {e}", path.display()))
}

/// Resolve effective config: built-in defaults ← `~/.config/dex/config.toml`
/// (optional global) ← `<repo>/.dex.toml` (project, primary).
pub fn load_effective(cwd: &Path) -> Result<Effective> {
    let mut layers: Vec<Layer> = Vec::new();
    if let Ok(global) = config_path() {
        if global.exists() {
            layers.push(parse_layer_file(&global)?);
        }
    }
    if let Some(project) = find_project_file(cwd) {
        layers.push(parse_layer_file(&project)?);
    }
    let eff = merge_layers(layers);
    validate(&eff)?;
    Ok(eff)
}

/// Effective config resolved from `cwd`, or `None` when no `.dex.toml` exists
/// walking up from `cwd`. Distinct from `load_effective`, which returns an empty
/// (defaults-only) config when no project file is found — the UI needs to tell
/// "this project has config" apart from "no config".
pub fn load_effective_opt(cwd: &Path) -> Result<Option<Effective>> {
    if find_project_file(cwd).is_none() {
        return Ok(None);
    }
    load_effective(cwd).map(Some)
}

/// Skill refs this config points at (hook actions + provider reactors) — used to
/// warn when a referenced skill isn't installed.
pub fn referenced_skills(eff: &Effective) -> Vec<String> {
    let mut out = Vec::new();
    for action in eff.hooks.values() {
        let Action::Skill { r#ref } = action;
        out.push(r#ref.clone());
    }
    for (role, name) in [("ci", &eff.providers.ci), ("pr_review", &eff.providers.pr_review)] {
        if let Some(n) = name {
            if let Some(r) = reactor_for(role, n) {
                out.push(r.to_string());
            }
        }
    }
    out.sort();
    out.dedup();
    out
}

/// Resolved reactor names for the providers that have them. Computed from the
/// registry — never re-derive this in JS or CLI code.
#[derive(Debug, Clone, Serialize)]
pub struct ReactorView {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ci: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pr_review: Option<String>,
}

/// The effective config plus registry-derived reactor names. Returned by the
/// desktop `project_config` command so the UI can show resolved reactors.
#[derive(Debug, Clone, Serialize)]
pub struct ConfigView {
    #[serde(flatten)]
    pub effective: Effective,
    pub reactors: ReactorView,
}

pub fn config_view(eff: &Effective) -> ConfigView {
    let ci = eff.providers.ci.as_deref()
        .and_then(|n| reactor_for("ci", n))
        .map(String::from);
    let pr_review = eff.providers.pr_review.as_deref()
        .and_then(|n| reactor_for("pr_review", n))
        .map(String::from);
    ConfigView {
        effective: eff.clone(),
        reactors: ReactorView { ci, pr_review },
    }
}

pub fn get_dotted(eff: &Effective, key: &str) -> Result<String> {
    match key {
        "providers.notifier" => Ok(eff.providers.notifier.clone().unwrap_or_default()),
        "providers.ci" => Ok(eff.providers.ci.clone().unwrap_or_default()),
        "providers.pr_review" => Ok(eff.providers.pr_review.clone().unwrap_or_default()),
        "providers.multiplexer" => Ok(eff.providers.multiplexer.clone().unwrap_or_default()),
        "providers.pr_review.reactor" => {
            let name = eff.providers.pr_review.as_deref().unwrap_or("none");
            Ok(reactor_for("pr_review", name).unwrap_or("").to_string())
        }
        "providers.ci.reactor" => {
            let name = eff.providers.ci.as_deref().unwrap_or("none");
            Ok(reactor_for("ci", name).unwrap_or("").to_string())
        }
        "hooks.on_ship" => match eff.hooks.get(&HookPoint::OnShip) {
            Some(Action::Skill { r#ref }) => Ok(r#ref.clone()),
            None => Ok(String::new()),
        },
        "hooks.on_verify_ci" => match eff.hooks.get(&HookPoint::OnVerifyCi) {
            Some(Action::Skill { r#ref }) => Ok(r#ref.clone()),
            None => Ok(String::new()),
        },
        "hooks.on_verify_review" => match eff.hooks.get(&HookPoint::OnVerifyReview) {
            Some(Action::Skill { r#ref }) => Ok(r#ref.clone()),
            None => Ok(String::new()),
        },
        "phases_skip" => Ok(serde_json::to_string(&eff.phases_skip)?),
        "ports" => Ok(serde_json::to_string(&eff.ports)?),
        "identity.env_file" => Ok(eff.identity.env_file.clone().unwrap_or_default()),
        "identity.github_org" => Ok(eff.identity.github_org.clone().unwrap_or_default()),
        "models.coder" => Ok(eff.models.coder.clone().unwrap_or_default()),
        "models.reviewer" => Ok(eff.models.reviewer.clone().unwrap_or_default()),
        "models.designer" => Ok(eff.models.designer.clone().unwrap_or_default()),
        "models.curator" => Ok(eff.models.curator.clone().unwrap_or_default()),
        "terminal.program" => Ok(eff.terminal.program.clone().unwrap_or_default()),
        _ => Err(anyhow!("unknown config key: {key}")),
    }
}

/// Machine-readable description of the config surface, sourced from the live
/// REGISTRY + enums (NOT the struct types — the "which providers are valid per
/// role" constraint lives in the registry, which a type-derived JSON Schema can't
/// express). Consumed by `/spec configure` for LLM self-configuration and by humans.
pub fn schema() -> serde_json::Value {
    use serde_json::json;
    let mut providers = serde_json::Map::new();
    for role in ["notifier", "ci", "pr_review", "multiplexer"] {
        let valid: Vec<&str> =
            REGISTRY.iter().filter(|(_, d)| d.role == role).map(|(n, _)| *n).collect();
        let reactors: serde_json::Map<String, serde_json::Value> = REGISTRY
            .iter()
            .filter(|(_, d)| d.role == role)
            .filter_map(|(n, d)| d.reactor.map(|r| (n.to_string(), json!(r))))
            .collect();
        providers.insert(role.to_string(), json!({ "valid": valid, "reactors": reactors }));
    }
    json!({
        "providers": providers,
        "hooks": {
            "points": ["on_ship", "on_verify_ci", "on_verify_review"],
            "value": "a skill ref string (e.g. \"/pr\") or { kind = \"skill\", ref = \"/pr\" }"
        },
        "phases_skip": { "valid": VALID_PHASES },
        "models": {
            "roles": ["coder", "reviewer", "designer", "curator"],
            "valid": ["opus", "sonnet", "haiku", "inherit"],
            "note": "per-project agent model override at spawn; empty falls back to the agent definition's frontmatter"
        },
        "ports": {
            "shape": "array of { service, base, env } tables ([[ports]])",
            "note": "service = logical name; base = base port; env = env var the allocated port exports as. A CLI project declares none."
        },
        "identity": { "fields": ["env_file", "github_org"] },
        "terminal": { "fields": ["program"], "note": "terminal emulator for 'attach in terminal'; defaults to ghostty" },
        "authoring": {
            "format": "toml",
            "project_file": ".dex.toml at repo root (primary config)",
            "global_file": "~/.config/dex/config.toml (optional personal defaults)",
            "merge": "defaults <- ~/.config/dex/config.toml <- project (higher overrides per field)"
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse_layer(s: &str) -> Layer {
        toml::from_str(s).expect("parse layer")
    }

    fn effective_with_phases_skip(phases: Vec<String>) -> Effective {
        Effective { phases_skip: phases, ..Effective::default() }
    }

    #[test]
    fn load_effective_opt_some_when_project_file_present() {
        // The repo's own .dex.toml lives at the workspace root, above this crate.
        let here = Path::new(env!("CARGO_MANIFEST_DIR"));
        let eff = load_effective_opt(here).unwrap();
        assert!(eff.is_some(), "expected to resolve the repo's .dex.toml walking up");
    }

    #[test]
    fn load_effective_opt_none_when_no_project_file() {
        // Root has no .dex.toml and no parent — nothing to find.
        assert!(load_effective_opt(Path::new("/")).unwrap().is_none());
    }

    #[test]
    fn merge_precedence_project_over_vault_over_default() {
        let vault = parse_layer(r#"
            [providers]
            notifier = "slack"
            ci = "github-actions"
            multiplexer = "tmux"
        "#);
        let project = parse_layer(r#"
            [providers]
            notifier = "discord"
            multiplexer = "zellij"
        "#);
        let eff = merge_layers(vec![vault, project]);
        assert_eq!(eff.providers.notifier.as_deref(), Some("discord"));
        assert_eq!(eff.providers.ci.as_deref(), Some("github-actions"));
        assert_eq!(eff.providers.multiplexer.as_deref(), Some("zellij"));
    }

    #[test]
    fn reactor_resolved_from_registry_not_toml() {
        let layer = parse_layer(r#"
            [providers]
            pr_review = "greptile"
        "#);
        let eff = merge_layers(vec![layer]);
        let reactor = reactor_for("pr_review", eff.providers.pr_review.as_deref().unwrap());
        assert_eq!(reactor, Some("/react-to-greptile"));
    }

    #[test]
    fn coderabbit_reactor() {
        assert_eq!(reactor_for("pr_review", "coderabbit"), Some("/react-to-coderabbit"));
    }

    #[test]
    fn github_actions_reactor() {
        assert_eq!(reactor_for("ci", "github-actions"), Some("/react-to-pipelines"));
    }

    #[test]
    fn phases_skip_deserialized() {
        let layer = parse_layer(r#"
            [phases]
            skip = ["verify"]
        "#);
        let eff = merge_layers(vec![layer]);
        assert_eq!(eff.phases_skip, vec!["verify"]);
    }

    #[test]
    fn unknown_provider_fails_validation() {
        let layer = parse_layer(r#"
            [providers]
            pr_review = "acme"
        "#);
        let eff = merge_layers(vec![layer]);
        let err = validate(&eff).unwrap_err();
        assert!(err.to_string().contains("unknown pr_review provider: acme"), "{err}");
    }

    #[test]
    fn on_ship_string_shorthand_deserializes_to_skill() {
        let layer = parse_layer(r#"
            [hooks]
            on_ship = "/pr"
        "#);
        let eff = merge_layers(vec![layer]);
        assert_eq!(eff.hooks.get(&HookPoint::OnShip), Some(&Action::Skill { r#ref: "/pr".into() }));
    }

    #[test]
    fn on_ship_long_form_also_works() {
        let layer = parse_layer(r#"
            [hooks.on_ship]
            kind = "skill"
            ref = "/pr"
        "#);
        let eff = merge_layers(vec![layer]);
        assert_eq!(eff.hooks.get(&HookPoint::OnShip), Some(&Action::Skill { r#ref: "/pr".into() }));
    }

    #[test]
    fn get_dotted_reactor() {
        let layer = parse_layer(r#"
            [providers]
            pr_review = "greptile"
        "#);
        let eff = merge_layers(vec![layer]);
        let val = get_dotted(&eff, "providers.pr_review.reactor").unwrap();
        assert_eq!(val, "/react-to-greptile");
    }

    #[test]
    fn get_dotted_phases_skip_json() {
        let layer = parse_layer(r#"
            [phases]
            skip = ["verify"]
        "#);
        let eff = merge_layers(vec![layer]);
        let val = get_dotted(&eff, "phases_skip").unwrap();
        assert_eq!(val, r#"["verify"]"#);
    }

    #[test]
    fn validate_rejects_invalid_phases_skip_entry() {
        let eff = effective_with_phases_skip(vec!["bogus".to_string()]);
        let err = validate(&eff).unwrap_err();
        assert!(err.to_string().contains("invalid phases_skip entry: bogus"), "{err}");
    }

    #[test]
    fn get_dotted_hooks_on_ship() {
        let layer = parse_layer(r#"
            [hooks]
            on_ship = "/pr"
        "#);
        let eff = merge_layers(vec![layer]);
        let val = get_dotted(&eff, "hooks.on_ship").unwrap();
        assert_eq!(val, "/pr");
    }

    #[test]
    fn unknown_notifier_fails_validation() {
        let layer = parse_layer(r#"
            [providers]
            notifier = "teams"
        "#);
        let eff = merge_layers(vec![layer]);
        let err = validate(&eff).unwrap_err();
        assert!(err.to_string().contains("unknown notifier provider: teams"), "{err}");
    }

    #[test]
    fn valid_config_passes_validation() {
        let layer = parse_layer(r#"
            [providers]
            notifier = "slack"
            ci = "github-actions"
            pr_review = "greptile"

            [hooks]
            on_ship = "/pr"

            [phases]
            skip = ["verify"]
        "#);
        let eff = merge_layers(vec![layer]);
        assert!(validate(&eff).is_ok());
    }

    #[test]
    fn schema_is_registry_sourced() {
        let s = schema();
        let pr = &s["providers"]["pr_review"];
        let valid: Vec<&str> = pr["valid"].as_array().unwrap().iter().map(|v| v.as_str().unwrap()).collect();
        assert!(valid.contains(&"greptile") && valid.contains(&"coderabbit"));
        assert_eq!(pr["reactors"]["greptile"], "/react-to-greptile");
        assert_eq!(s["phases_skip"]["valid"].as_array().unwrap().len(), 8);
        assert!(s["hooks"]["points"].as_array().unwrap().iter().any(|v| v == "on_ship"));
    }

    #[test]
    fn multiplexer_valid_passes_validation() {
        for mux in ["zellij", "tmux", "none"] {
            let layer = parse_layer(&format!(r#"[providers]
multiplexer = "{mux}""#));
            let eff = merge_layers(vec![layer]);
            assert!(validate(&eff).is_ok(), "expected ok for multiplexer={mux}");
        }
    }

    #[test]
    fn unknown_multiplexer_fails_validation() {
        let layer = parse_layer(r#"
            [providers]
            multiplexer = "screen"
        "#);
        let eff = merge_layers(vec![layer]);
        let err = validate(&eff).unwrap_err();
        assert!(err.to_string().contains("unknown multiplexer provider: screen"), "{err}");
    }

    #[test]
    fn get_dotted_multiplexer() {
        let layer = parse_layer(r#"
            [providers]
            multiplexer = "tmux"
        "#);
        let eff = merge_layers(vec![layer]);
        assert_eq!(get_dotted(&eff, "providers.multiplexer").unwrap(), "tmux");
    }

    #[test]
    fn schema_includes_multiplexer() {
        let s = schema();
        let mux = &s["providers"]["multiplexer"];
        let valid: Vec<&str> =
            mux["valid"].as_array().unwrap().iter().map(|v| v.as_str().unwrap()).collect();
        assert!(valid.contains(&"zellij") && valid.contains(&"tmux") && valid.contains(&"none"),
            "valid={valid:?}");
    }

    #[test]
    fn hooks_merge_additive() {
        let vault = parse_layer(r#"
            [hooks]
            on_ship = "/pr"
        "#);
        let project = parse_layer(r#"
            [hooks]
            on_verify_ci = "/wait-for-ci"
        "#);
        let eff = merge_layers(vec![vault, project]);
        assert!(eff.hooks.contains_key(&HookPoint::OnShip));
        assert!(eff.hooks.contains_key(&HookPoint::OnVerifyCi));
    }

    #[test]
    fn terminal_parses_from_toml() {
        let eff = merge_layers(vec![parse_layer("[terminal]\nprogram = \"ghostty\"")]);
        assert_eq!(eff.terminal.program.as_deref(), Some("ghostty"));
    }

    #[test]
    fn terminal_defaults_to_empty_when_unset() {
        assert!(merge_layers(vec![]).terminal.program.is_none());
    }

    #[test]
    fn get_dotted_terminal_program() {
        let eff = merge_layers(vec![parse_layer("[terminal]\nprogram = \"alacritty\"")]);
        assert_eq!(get_dotted(&eff, "terminal.program").unwrap(), "alacritty");
    }

    #[test]
    fn get_dotted_terminal_program_empty_when_unset() {
        assert_eq!(get_dotted(&merge_layers(vec![]), "terminal.program").unwrap(), "");
    }

    #[test]
    fn schema_includes_terminal() {
        let s = schema();
        assert!(s["terminal"]["fields"].as_array().unwrap().iter().any(|v| v == "program"));
    }

    #[test]
    fn project_file_finds_dex_toml() {
        let found = project_file(Path::new(env!("CARGO_MANIFEST_DIR")));
        assert!(found.is_some() && found.unwrap().ends_with(".dex.toml"));
    }

    #[test]
    fn project_file_returns_none_at_root() {
        assert!(project_file(Path::new("/")).is_none());
    }

    #[test]
    fn config_view_greptile_resolves_reactor() {
        let layer = parse_layer(r#"
            [providers]
            pr_review = "greptile"
        "#);
        let eff = merge_layers(vec![layer]);
        let view = config_view(&eff);
        assert_eq!(view.reactors.pr_review.as_deref(), Some("/react-to-greptile"));
        assert!(view.reactors.ci.is_none());
    }

    #[test]
    fn config_view_github_actions_ci_reactor() {
        let layer = parse_layer(r#"
            [providers]
            ci = "github-actions"
        "#);
        let eff = merge_layers(vec![layer]);
        let view = config_view(&eff);
        assert_eq!(view.reactors.ci.as_deref(), Some("/react-to-pipelines"));
        assert!(view.reactors.pr_review.is_none());
    }

    #[test]
    fn config_view_none_provider_has_no_reactor() {
        let layer = parse_layer(r#"
            [providers]
            ci = "none"
            pr_review = "none"
        "#);
        let eff = merge_layers(vec![layer]);
        let view = config_view(&eff);
        assert!(view.reactors.ci.is_none());
        assert!(view.reactors.pr_review.is_none());
    }

    #[test]
    fn config_view_unset_provider_has_no_reactor() {
        let eff = merge_layers(vec![]);
        let view = config_view(&eff);
        assert!(view.reactors.ci.is_none());
        assert!(view.reactors.pr_review.is_none());
    }

    #[test]
    fn config_view_serializes_with_reactors_key() {
        let layer = parse_layer(r#"
            [providers]
            pr_review = "greptile"
        "#);
        let eff = merge_layers(vec![layer]);
        let view = config_view(&eff);
        let json: serde_json::Value = serde_json::to_value(&view).unwrap();
        assert_eq!(json["reactors"]["pr_review"], "/react-to-greptile");
        assert!(json["reactors"]["ci"].is_null() || json["reactors"].get("ci").is_none());
    }
}

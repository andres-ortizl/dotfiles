use std::path::Path;

// The frontend (frontendDist = "ui") is embedded into the binary at compile time
// by generate_context!. Cargo doesn't track those asset files, so edits silently
// fail to re-embed. `rerun-if-changed=<dir>` is NOT enough: a directory's mtime
// doesn't change when a file's *content* is edited (only on add/remove), so cargo
// never re-runs. We must emit rerun-if-changed for every file individually.
fn watch_dir(dir: &Path) {
    let Ok(entries) = std::fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            watch_dir(&path);
        } else {
            println!("cargo:rerun-if-changed={}", path.display());
        }
    }
}

fn main() {
    watch_dir(Path::new("ui"));
    tauri_build::build()
}

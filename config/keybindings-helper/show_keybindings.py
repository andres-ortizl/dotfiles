# /// script
# dependencies = [
#   "rich>=13.0.0",
# ]
# ///
"""
Keybindings Helper - Beautiful TUI viewer for Hyprland and Zed keybindings

Usage:
    uv run show_keybindings.py [menu|hyprland|zed|all|search <query>]
"""

import re
import sys
from pathlib import Path

from rich import box
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from rich.table import Table


class HyprlandParser:
    def __init__(self, config_path: Path):
        self.config_path = config_path

    def parse(self) -> dict:
        categories = {}

        with open(self.config_path) as f:
            content = f.read()

        lines = content.split("\n")
        current_category = "General"
        categories[current_category] = []

        for line in lines:
            line = line.strip()

            if line.startswith("#") and not line.startswith("#$"):
                comment = line.lstrip("#").strip()
                if (
                    comment
                    and len(comment) < 50
                    and not any(
                        c in comment
                        for c in ["=", "bind", "┌", "┐", "├", "┴", "└", "─", "│"]
                    )
                ):
                    current_category = comment
                    categories[current_category] = []
                continue

            if not line or line.startswith("#"):
                continue

            match = re.match(r"bind[em]?\s*=\s*(.+)", line)
            if match:
                bind_content = match.group(1)
                parts = [p.strip() for p in bind_content.split(",", 3)]

                if len(parts) >= 3:
                    modifiers = parts[0]
                    key = parts[1]
                    action = parts[2]
                    param = parts[3] if len(parts) > 3 else ""

                    modifiers = modifiers.replace("$mainMod", "Super")
                    modifiers = modifiers.replace("$winMod", "Meta")
                    modifiers = modifiers.replace("SHIFT", "Shift")
                    modifiers = modifiers.replace("ALT", "Alt")
                    modifiers = modifiers.replace("CTRL", "Ctrl")

                    mod_parts = modifiers.split()
                    if len(mod_parts) > 1:
                        formatted_key = " + ".join(mod_parts) + " + " + key
                    elif mod_parts:
                        formatted_key = f"{mod_parts[0]} + {key}"
                    else:
                        formatted_key = key

                    description = self._get_description(action, param)

                    categories[current_category].append(
                        {
                            "key": formatted_key,
                            "action": action,
                            "description": description,
                        },
                    )

        return {k: v for k, v in categories.items() if v}

    def _get_description(self, action: str, param: str) -> str:
        if action == "exec":
            if "ghostty" in param:
                return "Launch Terminal (Ghostty)"
            if "zen-bin" in param or "browser" in param:
                return "Launch Browser"
            if "zed" in param:
                return "Launch Zed Editor"
            if "rofi" in param and "launcher" in param:
                return "Application Launcher"
            if "grimblast" in param:
                return "Screenshot"
            if "hyprlock" in param:
                return "Lock Screen"
            if "cliphist" in param:
                return "Clipboard History"
            if "setwall" in param:
                return "Cycle Wallpaper"
            if "powermenu" in param:
                return "Power Menu"
            if "scratchpad" in param:
                return "Scratchpad Terminal"
            return param
        if action == "killactive":
            return "Close Window"
        if action == "fullscreen":
            return f"Fullscreen {param if param else '(Maximize)'}"
        if action == "exit":
            return "Exit Hyprland"
        if action == "togglefloating":
            return "Toggle Floating"
        if action == "movefocus":
            return f"Move Focus {param}"
        if action == "swapwindow":
            return f"Swap Window {param}"
        if action == "workspace":
            return f"Go to Workspace {param}"
        if action == "movetoworkspace":
            return f"Move to Workspace {param}"
        if action == "togglegroup":
            return "Toggle Group"
        if action == "changegroupactive":
            return "Change Group Active"
        if action == "movewindow":
            return "Move Window (Mouse)"
        if action == "resizewindow":
            return "Resize Window (Mouse)"
        if action == "submap":
            return f"Enter {param.title()} Mode"
        if action == "resizeactive":
            return f"Resize Active Window {param}"
        return f"{action} {param}".strip()


class ZedParser:
    def __init__(self, config_path: Path):
        self.config_path = config_path

    def parse(self) -> dict:
        categories = {
            "Panels": [],
            "Docks": [],
            "File Navigation": [],
            "Pane Management": [],
            "Code Editing": [],
            "Code Navigation": [],
            "Git": [],
            "Editor Features": [],
        }

        with open(self.config_path) as f:
            content = f.read()

        in_bindings = False
        for line in content.split("\n"):
            line = line.strip()

            if '"bindings"' in line:
                in_bindings = True
                continue

            if in_bindings and line.startswith("}"):
                in_bindings = False
                continue

            if in_bindings:
                match = re.match(r'"([^"]+)":\s*"([^"]+)"', line)
                if match:
                    key = match.group(1)
                    action = match.group(2)

                    if action == "null":
                        continue

                    formatted_key = key.replace("alt-", "Alt + ")
                    formatted_key = formatted_key.replace("ctrl-", "Ctrl + ")
                    formatted_key = formatted_key.replace("shift-", "Shift + ")
                    formatted_key = formatted_key.replace("super-", "Super + ")

                    description = self._get_description(action)
                    category = self._get_category(action)

                    categories[category].append(
                        {
                            "key": formatted_key,
                            "action": action.split("::")[-1],
                            "description": description,
                        },
                    )

        return {k: v for k, v in categories.items() if v}

    def _get_category(self, action: str) -> str:
        if "panel" in action.lower():
            return "Panels"
        if "dock" in action.lower():
            return "Docks"
        if any(x in action.lower() for x in ["file_finder", "tab_switcher", "close"]):
            return "File Navigation"
        if "pane" in action.lower():
            return "Pane Management"
        if any(x in action.lower() for x in ["select", "delete"]):
            return "Code Editing"
        if any(x in action.lower() for x in ["definition", "references", "rename"]):
            return "Code Navigation"
        if "git" in action.lower():
            return "Git"
        return "Editor Features"

    def _get_description(self, action: str) -> str:
        descriptions = {
            "project_panel::ToggleFocus": "Toggle Project Panel Focus",
            "outline_panel::ToggleFocus": "Toggle Outline Panel Focus",
            "git_panel::ToggleFocus": "Toggle Git Panel Focus",
            "terminal_panel::ToggleFocus": "Toggle Terminal Panel Focus",
            "debug_panel::ToggleFocus": "Toggle Debug Panel Focus",
            "notification_panel::ToggleFocus": "Toggle Notification Panel Focus",
            "agent::ToggleFocus": "Toggle AI Agent Focus",
            "workspace::ToggleLeftDock": "Toggle Left Dock",
            "workspace::ToggleRightDock": "Toggle Right Dock",
            "workspace::ToggleBottomDock": "Toggle Bottom Dock",
            "file_finder::Toggle": "File Finder (Quick Open)",
            "tab_switcher::Toggle": "Tab Switcher",
            "tab_switcher::CloseSelectedItem": "Close Tab in Switcher",
            "pane::CloseActiveItem": "Close Active Tab",
            "pane::CloseAllItems": "Close All Tabs",
            "editor::SelectLargerSyntaxNode": "Select Larger Syntax Node",
            "editor::SelectSmallerSyntaxNode": "Select Smaller Syntax Node",
            "editor::ToggleGitBlameInline": "Toggle Git Blame Inline",
            "editor::ToggleInlayHints": "Toggle Inlay Hints",
            "workspace::ActivatePaneLeft": "Activate Pane Left",
            "workspace::ActivatePaneRight": "Activate Pane Right",
            "workspace::ActivatePaneUp": "Activate Pane Up",
            "workspace::ActivatePaneDown": "Activate Pane Down",
            "workspace::ActivatePreviousPane": "Activate Previous Pane",
            "editor::DeleteLine": "Delete Line",
            "editor::Rename": "Rename Symbol (Refactor)",
            "editor::GoToDefinition": "Go to Definition",
            "editor::SelectNext": "Select Next Occurrence",
            "editor::FindAllReferences": "Find All References",
        }
        return descriptions.get(action, action)


class KeybindingsViewer:
    def __init__(self):
        self.console = Console()
        self.config_dir = Path.home() / ".config"

        self.hyprland_config = self.config_dir / "hypr" / "conf" / "keybinding.conf"
        self.zed_config = self.config_dir / "zed" / "keymap.json"

    def load_keybindings(self) -> dict:
        keybindings = {}

        if self.hyprland_config.exists():
            parser = HyprlandParser(self.hyprland_config)
            keybindings["hyprland"] = parser.parse()

        if self.zed_config.exists():
            parser = ZedParser(self.zed_config)
            keybindings["zed"] = parser.parse()

        return keybindings

    def create_table(self, app_name: str, categories: dict) -> Table:
        table = Table(
            title=f"[bold cyan]{app_name.upper()}[/bold cyan]",
            box=box.ROUNDED,
            show_header=True,
            header_style="bold magenta",
            border_style="cyan",
            title_style="bold cyan",
        )

        table.add_column("Key", style="yellow", no_wrap=True, width=30)
        table.add_column("Action", style="green", width=25)
        table.add_column("Description", style="white", width=50)

        for category, bindings in categories.items():
            table.add_row()
            table.add_row(
                f"[bold blue]═══ {category} ═══[/bold blue]",
                "",
                "",
            )

            for binding in bindings:
                key = binding.get("key", "")
                action = binding.get("action", "")
                description = binding.get("description", "")
                table.add_row(key, action, description)

        return table

    def show_menu(self) -> str:
        self.console.clear()

        menu_panel = Panel(
            "[bold cyan]Keybindings Helper[/bold cyan]\n\n"
            "[yellow]1.[/yellow] Hyprland Keybindings\n"
            "[yellow]2.[/yellow] Zed Editor Keybindings\n"
            "[yellow]3.[/yellow] Show Both\n"
            "[yellow]q.[/yellow] Quit",
            title="[bold magenta]Choose an option[/bold magenta]",
            border_style="cyan",
            box=box.DOUBLE,
        )

        self.console.print(menu_panel)

        choice = Prompt.ask(
            "\n[cyan]Enter your choice[/cyan]",
            choices=["1", "2", "3", "q"],
            default="3",
        )

        return choice

    def display_keybindings(self, app: str = None):
        self.console.clear()
        keybindings = self.load_keybindings()

        if app and app in keybindings:
            table = self.create_table(app, keybindings[app])
            self.console.print(table)
        elif app is None:
            for app_name, categories in keybindings.items():
                table = self.create_table(app_name, categories)
                self.console.print(table)
                self.console.print()
        else:
            self.console.print(f"[red]Error: Unknown app '{app}'[/red]")

    def search_keybindings(self, query: str):
        self.console.clear()
        keybindings = self.load_keybindings()
        results = {}

        query_lower = query.lower()

        for app_name, categories in keybindings.items():
            app_results = {}
            for category, bindings in categories.items():
                matching_bindings = [
                    b
                    for b in bindings
                    if query_lower in b.get("key", "").lower()
                    or query_lower in b.get("action", "").lower()
                    or query_lower in b.get("description", "").lower()
                ]
                if matching_bindings:
                    app_results[category] = matching_bindings

            if app_results:
                results[app_name] = app_results

        if results:
            for app_name, categories in results.items():
                table = self.create_table(f"{app_name} - Search: '{query}'", categories)
                self.console.print(table)
                self.console.print()
        else:
            self.console.print(
                f"[yellow]No keybindings found matching '{query}'[/yellow]",
            )

    def run_interactive(self):
        while True:
            choice = self.show_menu()

            if choice == "q":
                self.console.print("[green]Goodbye![/green]")
                break
            if choice == "1":
                self.display_keybindings("hyprland")
                self.console.input("\n[dim]Press Enter to continue...[/dim]")
            elif choice == "2":
                self.display_keybindings("zed")
                self.console.input("\n[dim]Press Enter to continue...[/dim]")
            elif choice == "3":
                self.display_keybindings()
                self.console.input("\n[dim]Press Enter to continue...[/dim]")

    def run(self, args: list):
        if not args or args[0] == "menu":
            self.run_interactive()
        elif args[0] == "hyprland":
            self.display_keybindings("hyprland")
        elif args[0] == "zed":
            self.display_keybindings("zed")
        elif args[0] == "all":
            self.display_keybindings()
        elif args[0] == "search" and len(args) > 1:
            self.search_keybindings(" ".join(args[1:]))
        else:
            self.console.print("[red]Usage:[/red]")
            self.console.print(
                "  show_keybindings.py [menu|hyprland|zed|all|search <query>]",
            )
            self.console.print("\n[yellow]Examples:[/yellow]")
            self.console.print("  show_keybindings.py              # Interactive menu")
            self.console.print(
                "  show_keybindings.py hyprland     # Show Hyprland keybindings",
            )
            self.console.print(
                "  show_keybindings.py zed          # Show Zed keybindings",
            )
            self.console.print(
                "  show_keybindings.py all          # Show all keybindings",
            )
            self.console.print(
                "  show_keybindings.py search term  # Search keybindings",
            )


def main():
    viewer = KeybindingsViewer()
    viewer.run(sys.argv[1:])


if __name__ == "__main__":
    main()

import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
PROJECT = REPO / "os/homeserver"
CONFIG = PROJECT / "config/openclaw/openclaw.json"
PLUGIN = "npm:@openclaw/whatsapp@2026.9.2"


class OpenClawTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not shutil.which("docker"):
            raise unittest.SkipTest(
                "Docker is required for the OpenClaw integration tests"
            )
        result = subprocess.run(
            [
                "docker",
                "compose",
                "--env-file",
                "/dev/null",
                "config",
                "--no-interpolate",
                "--no-env-resolution",
                "--format",
                "json",
            ],
            cwd=PROJECT,
            check=True,
            capture_output=True,
            text=True,
        )
        cls.compose = json.loads(result.stdout)
        cls.service = cls.compose["services"]["openclaw"]
        cls.image = cls.service["image"]
        subprocess.run(
            ["docker", "image", "inspect", cls.image],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        cls.temporary = tempfile.TemporaryDirectory(prefix="openclaw-test-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.state = cls.root / "state"
        cls.state.mkdir()
        cls.workspace = cls.state / "workspace"
        cls.workspace.mkdir()
        cls.test_config = cls.root / "openclaw.json"
        shutil.copyfile(CONFIG, cls.test_config)
        cls.base = [
            "docker",
            "run",
            "--rm",
            "--user",
            f"{os.getuid()}:{os.getgid()}",
            "--read-only",
            "--cap-drop",
            "ALL",
            "--security-opt",
            "no-new-privileges:true",
            "--tmpfs",
            "/tmp:rw,nosuid,size=512m",
            "-e",
            "HOME=/home/node",
            "-e",
            "OPENCLAW_STATE_DIR=/home/node/.openclaw",
            "-e",
            "OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json",
            "-e",
            "OPENCLAW_DISABLE_BONJOUR=1",
            "-e",
            "NPM_CONFIG_CACHE=/tmp/npm-cache",
            "-e",
            "XDG_CACHE_HOME=/tmp/cache",
            "-e",
            "OPENAI_API_KEY=test-not-a-real-key",
            "-e",
            "OPENCLAW_GATEWAY_TOKEN=test-token-not-for-deployment-0123456789",
            "-e",
            "OPENCLAW_OWNER_PHONE=+15555550123",
            "-e",
            "OPENCLAW_IMAP_USER=test@example.com",
            "-e",
            "OPENCLAW_IMAP_PASSWORD=test-not-a-real-password",
            "-e",
            "OPENCLAW_COMPOSIO_MCP_URL=https://connect.composio.dev/mcp/test-not-real",
            "-v",
            f"{cls.state}:/home/node/.openclaw",
            "-v",
            f"{cls.test_config}:/etc/openclaw/openclaw.json:ro",
            "-v",
            f"{PROJECT}/config/openclaw/AGENTS.md:/home/node/.openclaw/workspace/AGENTS.md:ro",
            "-v",
            f"{REPO}/config/claude/skills/knowledge-capture:/home/node/.openclaw/workspace/skills/knowledge-capture:ro",
        ]
        # Only plugin installation has network access. Model and WhatsApp calls never do.
        installed = subprocess.run(
            [
                *cls.base,
                "-e",
                "OPENCLAW_CONFIG_PATH=/tmp/openclaw-setup/openclaw.json",
                cls.image,
                "node",
                "dist/index.js",
                "plugins",
                "install",
                PLUGIN,
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=300,
        )
        if installed.returncode:
            raise AssertionError(
                f"Plugin install failed:\n{installed.stdout}\n{installed.stderr}"
            )
        cls.cli("config", "validate", "--json")
        # Exercise real FTS and wiki operations without calling a paid embedding provider.
        # The IMAP watcher stays disabled: runtime tests run with --network none and the
        # watcher would mark itself unhealthy retrying against unreachable imap.gmail.com.
        config = json.loads(cls.test_config.read_text())
        config["memory"]["search"]["provider"] = "none"
        config["plugins"]["entries"]["imap"]["enabled"] = False
        config["mcp"]["servers"]["composio"]["enabled"] = False
        cls.test_config.write_text(json.dumps(config))
        cls.cli("wiki", "init")

    @classmethod
    def cli(cls, *args: str) -> str:
        result = subprocess.run(
            [*cls.base, "--network", "none", cls.image, "node", "dist/index.js", *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode:
            raise AssertionError(
                f"OpenClaw {' '.join(args)} failed:\n{result.stdout}\n{result.stderr}"
            )
        return result.stdout

    def test_private_opt_in_service(self) -> None:
        self.assertEqual(self.service["profiles"], ["openclaw"])
        self.assertEqual(set(self.service["networks"]), {"openclaw"})
        self.assertTrue(self.service["read_only"])
        self.assertEqual(self.service["cap_drop"], ["ALL"])
        self.assertEqual(len(self.service["ports"]), 1)
        self.assertEqual(self.service["ports"][0]["host_ip"], "127.0.0.1")
        self.assertFalse(self.service["env_file"][0]["required"])
        for mount in self.service["volumes"]:
            self.assertNotIn("docker.sock", mount["source"])
            if mount["target"] != "/home/node/.openclaw":
                self.assertTrue(mount["read_only"])
        self.assertIn("openwebui", self.compose["services"])
        self.assertNotIn("openclaw", self.compose["services"]["traefik"]["networks"])

    def test_policy_and_skill_configuration(self) -> None:
        config = json.loads(CONFIG.read_text())
        self.assertTrue(config["tools"]["fs"]["workspaceOnly"])
        self.assertEqual(config["tools"]["exec"]["security"], "deny")
        self.assertEqual(config["channels"]["whatsapp"]["groupPolicy"], "disabled")
        self.assertEqual(config["channels"]["whatsapp"]["dmPolicy"], "allowlist")
        self.assertFalse(config["channels"]["whatsapp"]["sendReadReceipts"])
        self.assertEqual(config["plugins"]["slots"]["memory"], "memory-core")
        self.assertIn("knowledge-capture", self.cli("skills", "list"))
        self.assertIn("whatsapp", self.cli("plugins", "list"))
        result = subprocess.run(
            [
                *self.base,
                "--network",
                "none",
                self.image,
                "node",
                "-e",
                "require('fs').appendFileSync('/home/node/.openclaw/workspace/AGENTS.md', 'changed')",
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "EROFS|EACCES")

    def test_gateway_starts_and_requires_authentication(self) -> None:
        started = subprocess.run(
            [
                *self.base,
                "--detach",
                "--network",
                "none",
                self.image,
                "node",
                "dist/index.js",
                "gateway",
                "--port",
                "18789",
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        container = started.stdout.strip()
        self.addCleanup(
            subprocess.run,
            ["docker", "rm", "--force", container],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            healthy = subprocess.run(
                ["docker", "exec", container, "node", "dist/docker-healthcheck.js"],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
            if healthy.returncode == 0:
                break
            time.sleep(1)
        else:
            logs = subprocess.run(
                ["docker", "logs", container],
                check=False,
                capture_output=True,
                text=True,
            )
            self.fail(f"Gateway did not become healthy:\n{logs.stdout}\n{logs.stderr}")
        response = subprocess.run(
            [
                "docker",
                "exec",
                container,
                "node",
                "-e",
                (
                    "(async()=>{const statuses=[];"
                    "for(const [tool,auth] of [['wiki_status',false],['wiki_status',true],['exec',true]]){"
                    "const headers={'Content-Type':'application/json'};"
                    "if(auth)headers.Authorization='Bearer '+process.env.OPENCLAW_GATEWAY_TOKEN;"
                    "const r=await fetch('http://127.0.0.1:18789/tools/invoke', {method:'POST',"
                    "headers,body:JSON.stringify({tool,args:{}})});statuses.push(r.status);"
                    "}console.log(JSON.stringify(statuses));})()"
                ),
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
        )
        self.assertEqual(json.loads(response.stdout), [401, 200, 404])

    def test_capture_synthesis_search_and_restart(self) -> None:
        inbox = self.workspace / "inbox"
        inbox.mkdir(exist_ok=True)
        capture = inbox / "2026-09-06-router-notes.md"
        original = "Router field notes: QuasarMesh supports offline configuration.\nSource: https://example.com/router\n"
        capture.write_text(original)
        source = "/home/node/.openclaw/workspace/inbox/2026-09-06-router-notes.md"
        source_page = self.workspace / "knowledge/sources/quasarmesh-source.md"
        source_page.write_text(
            "---\npageType: source\nid: source.quasarmesh-source\n"
            f"title: QuasarMesh source\nsourceType: local-file\nsourcePath: {source}\n"
            "ingestedAt: '2026-09-06T10:00:00Z'\n---\n\n" + original
        )
        self.cli(
            "wiki",
            "apply",
            "synthesis",
            "Home networking",
            "--body",
            "QuasarMesh supports offline configuration according to the saved field notes.",
            "--source-id",
            "source.quasarmesh-source",
        )
        # Each CLI call starts a new container against the same durable state.
        found = self.cli("wiki", "search", "QuasarMesh", "--backend", "local")
        self.assertIn("QuasarMesh", found)
        page = self.cli("wiki", "get", "synthesis.home-networking")
        self.assertIn("QuasarMesh", page)
        self.assertIn("sources/quasarmesh-source", page)
        self.cli("memory", "index", "--force")
        self.assertIn("QuasarMesh", self.cli("memory", "search", "QuasarMesh"))
        self.assertEqual(capture.read_text(), original)
        self.cli("wiki", "lint")


if __name__ == "__main__":
    unittest.main()

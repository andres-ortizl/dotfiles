from result import Ok, Err, Result
from pathlib import Path
import subprocess
from loguru import logger


def execute_cmd(cmd: str, exec_dir: Path = None) -> Result[str, str]:
    logger.info(f"Executing command: {cmd}")
    try:
        result = subprocess.run(
            cmd, shell=True, cwd=exec_dir, check=True, capture_output=True
        )
        return Ok(result.stdout.decode())
    except subprocess.CalledProcessError as e:
        return Err(e.stderr.decode())

from result import Ok, Err, Result
from monodot.subshell import execute_cmd
import platform
import os
from loguru import logger
from os.path import join

DOTBOT_BIN = "dotbot"
CONFIG_MAP = {
    "darwin": ".mac-conf.yml",
    "linux": ".arch-conf.yml",
}
CONFIG_DIR = "dot"


def get_dotfile_env_var() -> Result[str, str]:
    logger.info("Getting DOTFILES environment variable")
    dotfiles = os.getenv("DOT_MONOREPO", None)
    if not dotfiles:
        return Err("DOT_MONOREPO environment variable is not set")
    return Ok(join(dotfiles, CONFIG_DIR))


def sync() -> Result[str, str]:
    logger.info("Syncing dotfiles")
    config = CONFIG_MAP.get(platform.system().lower())
    if not config:
        return Err("Unsupported platform")
    status = get_dotfile_env_var()
    if status.is_err():
        return status

    config_path = f"{status.ok_value}/{config}"
    logger.info(f"Using config file: {config_path}")
    cmd = f"{DOTBOT_BIN} -d {status.ok_value} -c {config_path}"
    return execute_cmd(cmd=cmd)


def add_dotbot_global_env_var() -> Result[str, str]:
    logger.info("Adding DOTFILES environment variable to .bashrc and .zshrc")

    def add_to_file(lines: list, file_path: str) -> Result[str, str]:
        try:
            with open(file_path, "r") as file:
                existing_lines = file.readlines()

            existing_lines = [
                x.replace(
                    "\n",
                    "",
                ).strip()
                for x in existing_lines
            ]
            for line in lines:
                if line in existing_lines:
                    logger.info(f"{line} already existing in {file_path}")
                    continue
                with open(file_path, "a") as file:
                    file.write("\n" + line + "\n")
            return Ok(f"Processed {file_path}")
        except Exception as e:
            return Err(str(e))

    status = get_dotfile_env_var()
    if status.is_err():
        return status
    lines_to_add = [
        f"export DOTFILES={status.ok_value}",
        "source $DOTFILES/shell/main.sh",
    ]
    add_to_bashrc = add_to_file(lines_to_add, os.path.expanduser("~/.bashrc"))
    if add_to_bashrc.is_err():
        return add_to_bashrc
    add_to_zshrc = add_to_file(lines_to_add, os.path.expanduser("~/.zshrc"))
    if add_to_zshrc.is_err():
        return add_to_zshrc
    return Ok("Added global env var")

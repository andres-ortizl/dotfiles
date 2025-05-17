#!/bin/python

"""
In the case of I²C/SMBus devices, these rules also cause the loading of the
`i2c-dev` kernel module.  This module is required for access to I²C/SMBus
devices from userspace, and manually loading kernel modules is in itself a
privileged operation.

Distros will likely want to place this file in `/usr/lib/udev/rules.d/`, while
users installing this manually SHOULD use `/etc/udev/rules.d/` instead.

The suggested name for this file is `71-liquidctl.rules`.  Whatever name is
used, it MUST lexically appear before 73-seat-late.rules.  The suggested name
was chosen so that it is also lexically after systemd-provided 70-uaccess.rules.

Once installed, reload and trigger the new rules with:
   # udevadm control --reload
   # udevadm trigger

SUBSYSTEMS=="usb", ATTRS{idVendor}=="1e71", ATTRS{idProduct}=="300e", TAG+="uaccess"
"""

from __future__ import annotations

import subprocess
import time

import psutil


def get_cpu_fan_speed(temp: int) -> int:
    if temp < 40:
        return 50
    if temp < 50:
        return 50
    if temp < 60:
        return 60
    if temp < 70:
        return 70
    if temp < 80:
        return 85
    return 100


def get_pump_speed(temp: int) -> int:
    if temp < 70:
        return 60
    return 80
    # Using 100% seems to cause higher temps, possibly due to air in the loop


def get_cpu_temp() -> float | None:
    try:
        temps = psutil.sensors_temperatures()
        cpu_temp = temps.get("k10temp")[0]
    except (AttributeError, IndexError):
        print("Unable to read CPU temperature.")
        return None
    else:
        return cpu_temp.current


def set_fan_and_pump_speed(cpu_temp: float) -> tuple[int, int]:
    fan_speed = get_cpu_fan_speed(int(cpu_temp))
    pump_speed = get_pump_speed(int(cpu_temp))
    try:
        subprocess.run(
            [
                "sudo",  # edit visudoers to allow this script to run without password
                "liquidctl",
                "--match",
                "NZXT Kraken 2023",
                "set",
                "fan",
                "speed",
                str(fan_speed),
            ],
            check=True,
        )
        subprocess.run(
            [
                "sudo",
                "liquidctl",
                "--match",
                "NZXT Kraken 2023",
                "set",
                "pump",
                "speed",
                str(pump_speed),
            ],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Failed to set fan or pump speed: {e}")
    return fan_speed, pump_speed


def main():
    temp = get_cpu_temp()
    if temp is None:
        return

    fan_speed, pump_speed = set_fan_and_pump_speed(temp)
    print(f"CPU Temp: {temp:.1f}°C → Fan: {fan_speed}%, Pump: {pump_speed}%")


if __name__ == "__main__":
    while True:
        main()
        # Sleep for 5 seconds before checking again
        time.sleep(5)

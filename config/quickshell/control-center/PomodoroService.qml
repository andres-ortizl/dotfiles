import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property int focusMinutes: state.focusMinutes
    readonly property int shortBreakMinutes: state.shortBreakMinutes
    readonly property int longBreakMinutes: state.longBreakMinutes
    readonly property int focusDurationMs: focusMinutes * 60 * 1000
    readonly property int shortBreakDurationMs: shortBreakMinutes * 60 * 1000
    readonly property int longBreakDurationMs: longBreakMinutes * 60 * 1000
    readonly property int sessionsPerCycle: 4

    property bool presentationActive: false
    property bool initialized: false
    property real clockMs: Date.now()

    readonly property string phase: state.phase
    readonly property string status: state.status
    readonly property bool active: status !== "idle"
    readonly property bool running: status === "running"
    readonly property bool paused: status === "paused"
    readonly property int completedInCycle: state.completedInCycle
    readonly property int remainingSeconds: Math.max(0, Math.ceil(remainingMilliseconds() / 1000))
    readonly property int phaseDurationSeconds: Math.floor(durationForPhase(phase) / 1000)
    readonly property real progress: active && phaseDurationSeconds > 0
        ? Math.max(0, Math.min(1, 1 - remainingSeconds / phaseDurationSeconds))
        : 0
    readonly property string formattedTime: {
        const minutes = Math.floor(remainingSeconds / 60);
        const seconds = remainingSeconds % 60;
        return `${minutes < 10 ? "0" : ""}${minutes}:${seconds < 10 ? "0" : ""}${seconds}`;
    }
    readonly property string phaseLabel: phase === "shortBreak"
        ? "Short break"
        : phase === "longBreak" ? "Long break" : "Focus session"
    readonly property string statusLabel: status === "running"
        ? "In progress"
        : status === "paused" ? "Paused" : status === "ready" ? "Ready" : "Ready to focus"
    readonly property string primaryActionLabel: status === "running"
        ? "Pause"
        : status === "paused" ? "Resume" : "Start"

    function durationForPhase(name: string): int {
        if (name === "shortBreak")
            return shortBreakDurationMs;
        if (name === "longBreak")
            return longBreakDurationMs;
        return focusDurationMs;
    }

    function minutesForPhase(name: string): int {
        if (name === "shortBreak")
            return shortBreakMinutes;
        if (name === "longBreak")
            return longBreakMinutes;
        return focusMinutes;
    }

    function adjustDuration(name: string, deltaMinutes: int): void {
        const currentMinutes = minutesForPhase(name);
        const minimum = name === "focus" || name === "longBreak" ? 5 : 1;
        const maximum = name === "focus" ? 120 : 60;
        const nextMinutes = Math.max(minimum, Math.min(maximum, currentMinutes + deltaMinutes));
        if (nextMinutes === currentMinutes)
            return;

        const deltaMs = (nextMinutes - currentMinutes) * 60 * 1000;
        if (name === "shortBreak")
            state.shortBreakMinutes = nextMinutes;
        else if (name === "longBreak")
            state.longBreakMinutes = nextMinutes;
        else
            state.focusMinutes = nextMinutes;

        if (phase === name) {
            const duration = durationForPhase(name);
            if (running) {
                const now = Date.now();
                const remaining = Math.max(1000, Math.min(duration, Math.ceil(state.deadlineMs - now + deltaMs)));
                state.remainingMs = remaining;
                state.deadlineMs = now + remaining;
                refreshClock();
                scheduleCompletion();
            } else if (paused) {
                state.remainingMs = Math.max(1000, Math.min(duration, state.remainingMs + deltaMs));
                refreshClock();
            } else {
                state.remainingMs = duration;
                refreshClock();
            }
        }

        persist();
    }

    function remainingMilliseconds(): real {
        if (running)
            return Math.max(0, state.deadlineMs - clockMs);
        return Math.max(0, state.remainingMs);
    }

    function refreshClock(): void {
        clockMs = Date.now();
    }

    function persist(): void {
        if (initialized)
            stateFile.writeAdapter();
    }

    function preparePhase(name: string, nextStatus: string): void {
        completionTimer.stop();
        state.phase = name;
        state.status = nextStatus;
        state.deadlineMs = 0;
        state.remainingMs = durationForPhase(name);
        refreshClock();
        persist();
    }

    function scheduleCompletion(): void {
        completionTimer.stop();
        if (!running)
            return;

        const remaining = state.deadlineMs - Date.now();
        if (remaining <= 0) {
            Qt.callLater(root.finishCurrentPhase);
            return;
        }

        completionTimer.interval = Math.max(1, Math.ceil(remaining));
        completionTimer.start();
    }

    function start(): void {
        if (running)
            return;

        if (status === "idle") {
            state.phase = "focus";
            state.remainingMs = focusDurationMs;
        }

        const remaining = Math.max(1000, state.remainingMs || durationForPhase(state.phase));
        state.remainingMs = remaining;
        state.deadlineMs = Date.now() + remaining;
        state.status = "running";
        refreshClock();
        scheduleCompletion();
        persist();
    }

    function pause(): void {
        if (!running)
            return;

        const remaining = Math.max(1000, Math.ceil(state.deadlineMs - Date.now()));
        completionTimer.stop();
        state.remainingMs = remaining;
        state.deadlineMs = 0;
        state.status = "paused";
        refreshClock();
        persist();
    }

    function toggle(): void {
        if (running)
            pause();
        else
            start();
    }

    function reset(): void {
        if (state.completedInCycle >= sessionsPerCycle)
            state.completedInCycle = 0;
        preparePhase("focus", "idle");
    }

    function skip(): void {
        if (!active)
            return;

        if (phase === "focus") {
            const nextBreak = state.completedInCycle >= sessionsPerCycle ? "longBreak" : "shortBreak";
            preparePhase(nextBreak, "ready");
            return;
        }

        if (phase === "longBreak")
            state.completedInCycle = 0;
        preparePhase("focus", "ready");
    }

    function finishCurrentPhase(): void {
        if (!running || state.deadlineMs > Date.now()) {
            scheduleCompletion();
            return;
        }

        const finishedPhase = phase;
        if (finishedPhase === "focus") {
            state.completedInCycle = Math.min(sessionsPerCycle, state.completedInCycle + 1);
            const nextBreak = state.completedInCycle >= sessionsPerCycle ? "longBreak" : "shortBreak";
            preparePhase(nextBreak, "ready");
            notify("Focus complete", nextBreak === "longBreak" ? "Long break is ready" : "Short break is ready");
            return;
        }

        if (finishedPhase === "longBreak")
            state.completedInCycle = 0;
        preparePhase("focus", "ready");
        notify("Break complete", "Your next focus session is ready");
    }

    function notify(title: string, message: string): void {
        Quickshell.execDetached([
            "notify-send",
            "--app-name=Pomodoro",
            "--urgency=normal",
            title,
            message
        ]);
    }

    function summary(): string {
        if (!active)
            return "Ready to focus";
        const currentRemaining = running
            ? Math.max(0, Math.ceil((state.deadlineMs - Date.now()) / 1000))
            : remainingSeconds;
        const minutes = Math.floor(currentRemaining / 60);
        const seconds = currentRemaining % 60;
        const time = `${minutes < 10 ? "0" : ""}${minutes}:${seconds < 10 ? "0" : ""}${seconds}`;
        return `${phaseLabel}: ${time} (${statusLabel.toLowerCase()})`;
    }

    function restoreState(): void {
        let dirty = false;
        const clampedFocus = Math.max(5, Math.min(120, Math.round(Number(state.focusMinutes) || 25)));
        const clampedShortBreak = Math.max(1, Math.min(60, Math.round(Number(state.shortBreakMinutes) || 5)));
        const clampedLongBreak = Math.max(5, Math.min(60, Math.round(Number(state.longBreakMinutes) || 15)));
        if (clampedFocus !== state.focusMinutes) {
            state.focusMinutes = clampedFocus;
            dirty = true;
        }
        if (clampedShortBreak !== state.shortBreakMinutes) {
            state.shortBreakMinutes = clampedShortBreak;
            dirty = true;
        }
        if (clampedLongBreak !== state.longBreakMinutes) {
            state.longBreakMinutes = clampedLongBreak;
            dirty = true;
        }

        const validPhase = state.phase === "focus" || state.phase === "shortBreak" || state.phase === "longBreak";
        const validStatus = state.status === "idle" || state.status === "ready" || state.status === "running" || state.status === "paused";
        if (!validPhase || !validStatus) {
            state.completedInCycle = 0;
            preparePhase("focus", "idle");
            return;
        }

        const clampedCycle = Math.max(0, Math.min(sessionsPerCycle, state.completedInCycle));
        if (clampedCycle !== state.completedInCycle) {
            state.completedInCycle = clampedCycle;
            dirty = true;
        }

        if (running) {
            if (!Number.isFinite(state.deadlineMs) || state.deadlineMs <= 0) {
                preparePhase(state.phase, "ready");
                return;
            }
            refreshClock();
            if (state.deadlineMs <= clockMs) {
                finishCurrentPhase();
            } else {
                scheduleCompletion();
                if (dirty)
                    persist();
            }
            return;
        }

        if (state.deadlineMs !== 0) {
            state.deadlineMs = 0;
            dirty = true;
        }
        const duration = durationForPhase(state.phase);
        if (!Number.isFinite(state.remainingMs) || state.remainingMs <= 0 || state.remainingMs > duration) {
            state.remainingMs = duration;
            dirty = true;
        }
        refreshClock();
        if (dirty)
            persist();
    }


    Timer {
        id: completionTimer

        repeat: false
        onTriggered: root.finishCurrentPhase()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.presentationActive && root.running
        triggeredOnStart: true
        onTriggered: root.refreshClock()
    }


    FileView {
        id: stateFile

        path: Quickshell.statePath("pomodoro.json")
        atomicWrites: true
        blockWrites: true
        printErrors: false
        onLoaded: {
            root.initialized = true;
            root.restoreState();
        }
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("Could not load Pomodoro state:", FileViewError.toString(error));
            root.initialized = true;
            root.restoreState();
        }

        JsonAdapter {
            id: state

            property int focusMinutes: 25
            property int shortBreakMinutes: 5
            property int longBreakMinutes: 15
            property string phase: "focus"
            property string status: "idle"
            property real deadlineMs: 0
            property int remainingMs: 25 * 60 * 1000
            property int completedInCycle: 0
        }
    }
}

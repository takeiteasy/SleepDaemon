# SleepDaemon

SleepDaemon is a small macOS tool for keeping the machine awake while specific work is active.

It has two parts:

- `sleepd`: a per-user LaunchAgent daemon that owns the macOS sleep assertions.
- `sleepctl`: a command line tool that controls the daemon.

When one or more sleep tasks are active, the daemon prevents both system idle sleep and display sleep. When the tasks finish or are cancelled, normal sleep behavior resumes.

## Build

```sh
make build
make test
```

## Install

Install the release binaries to `~/.local/bin`, install the LaunchAgent, and start the daemon:

```sh
make install
```

Install somewhere else:

```sh
make install PREFIX=/usr/local
```

Uninstall the LaunchAgent and remove the installed binaries:

```sh
make uninstall
```

## Usage Patterns

Keep the Mac awake until you cancel it:

```sh
sleepctl off --reason "long build"
sleepctl on
```

Keep the Mac awake for a fixed time:

```sh
sleepctl for 30s
sleepctl for 10m
sleepctl for 1h --reason "download"
```

Keep the Mac awake until a process exits:

```sh
sleepctl until pid 12345
```

Keep the Mac awake while an app bundle is running:

```sh
sleepctl until bundle com.apple.Terminal
```

Keep the Mac awake until a specific window closes:

```sh
sleepctl windows
sleepctl until window 123
```

Inspect or cancel active tasks:

```sh
sleepctl status
sleepctl list
sleepctl cancel <task-uuid>
sleepctl cancel all
```

Manage the daemon directly:

```sh
sleepctl daemon status
sleepctl daemon start
sleepctl daemon stop
```

## Files

- LaunchAgent: `~/Library/LaunchAgents/com.takeiteasy.SleepDaemon.plist`
- Task store: `~/Library/Application Support/SleepDaemon/tasks.json`
- Default install path: `~/.local/bin/sleepd` and `~/.local/bin/sleepctl`

Use `pmset -g assertions` to inspect the active macOS power assertions.

## LICENSE

```
SleepDaemon

Copyright (C) 2025 George Watson

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

# Neovim, one step at a time

A configuration centered on native navigation, project search, Java builds,
and language intelligence. Optional debugging uses one protocol-client plugin.

Start with [the cheat sheet ordered by importance](CHEATSHEET.md). It explains
the keys for our current setup, with a small set to learn first.

Persistent undo is enabled: saved edit history survives restarting Neovim.
History uses Neovim's default state directory, keeping it out of project folders.

The visual setup uses the bundled `habamax` dark scheme, native rounded floats,
and a global status line with a colored mode badge and diagnostic counts.
No font icons or visual plugins are required. Try `:colorscheme` followed by
Space and Tab to preview other bundled themes; edit the colorscheme setting
in init.lua to keep your choice.

Java folding uses native LSP fold ranges and a one-column fold gutter. Files
start expanded when folding is first enabled. Use `za` to toggle a region,
`zc`/`zo` to close/open it, and `zM`/`zR` to close/open all folds. Fold ranges
arrive after JDT LS attaches and imports the project; folding does not edit code.

Symbol references highlight automatically after a 200 ms pause in Normal mode,
using native LSP document highlighting. Move or start typing to clear them.
Colors are configured beside the status-line accents in init.lua. The native
`updatetime` option controls the idle delay and also affects swap-file writes.

## Try it without replacing your current setup

From this directory:

```sh
nvim -u "$PWD/init.lua" path/to/File.java
```

This loads this configuration instead of your old init file. To also isolate it
from your existing configuration directories, copy it to a temporary app:

```sh
mkdir -p /tmp/nvim-ide-config/fresh-ide
cp init.lua /tmp/nvim-ide-config/fresh-ide/init.lua
XDG_CONFIG_HOME=/tmp/nvim-ide-config NVIM_APPNAME=fresh-ide nvim
```

## Replace your active configuration

After cloning on another machine, close Neovim and run:

```sh
bash ./install.sh --debug
```

This installs the configuration, Java language support, Lombok, and Java
debugging. Use `--java` without debugging, or no options for configuration only.
Install Neovim 0.11+ first; Java support also needs Java 21+, Python 3.9+, curl,
and tar. Install `rg`, `svn`, and Maven for their respective workflows.
The installer works from any directory, respects `XDG_CONFIG_HOME` and
`XDG_DATA_HOME`, and backs up the existing configuration directory. Existing
Java/debug tools are reused; editor data and undo history are retained.
Project settings and Tomcat/TomEE installations remain specific to each machine.

For a complete reset on this machine, close all Neovim instances and run
`bash ./reset-nvim.sh`. This deletes the entire Neovim config, data, cache, and
state directories, including downloaded plugins, Mason tools, undo history,
swap files, and ShaDa history, then installs the new init.lua. It makes no backup.
The script uses the paths verified on this machine. The installed Neovim binary,
system runtime, and project files are untouched.

Run these commands from this repository. They move your old configuration to a
dated backup and install only the new init file. Existing downloaded plugins stay
on disk, but this configuration does not load them.

```sh
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
backup_dir="${config_dir}.backup-$(date +%Y%m%d-%H%M%S)-$$"
if [ -e "$config_dir" ] || [ -L "$config_dir" ]; then
    mv -- "$config_dir" "$backup_dir"
fi
mkdir -p -- "$config_dir"
cp -- init.lua "$config_dir/init.lua"
```

## Native workflows

| Task | Command |
| --- | --- |
| Browse files | `:Explore` (built-in netrw) |
| Open a file | `:edit path/to/File.java` (Tab completes paths) |
| Find a Maven Java source by name | `:find UserService.java` (Tab completes) |
| List buffers / switch | `:ls`, then `:buffer NAME` or NUMBER |
| Split horizontally / vertically | `:split`, `:vsplit` |
| Move between windows | `Ctrl-w` then `h`, `j`, `k`, or `l` |
| Search the current file | `/pattern`, then `n` / `N` |
| Search the project | `:grep SomeName`, then `:copen` |
| Move through search results or build errors | `:cnext`, `:cprevious` |
| Compile Java | `:make`, then `:copen` |
| Run Maven tests | `:make test` (default also runs compile) |
| Run Gradle tests | `:make test` (default also runs classes) |
| Open a shell | `:terminal` |
| Leave terminal input mode | `Ctrl-\` then `Ctrl-n` |
| Copy / paste via system clipboard | `"+y` / `"+p` |
| Learn a feature | `:help quickfix`, `:help buffers`, `:help netrw` |

Opening a Java file sets that window's working directory to the nearest project
marker and configures Maven or Gradle using Neovim's built-in Maven/javac parsers.
Multi-module projects may need their root adjusted later. Builds run synchronously
for now. Search requires `rg`; builds require the project's JDK and build tool.

Opening a Maven Java file also configures native `:find` to search recursively
inside `src/main/java` and `src/test/java`. `:sfind` opens a match in a split;
`:2find` selects a second match when filenames repeat. This uses the buffer's
`path` option and adds no plugin. Custom source folders need explicit settings.

## Java language support (Maven)

Neovim 0.11+ uses its built-in LSP client with Eclipse JDT LS. There is no
plugin manager. The server launcher requires Java 21+ and Python 3.9+.

Run from this repository, then restart Neovim:

```sh
bash ./install-jdtls.sh
bash ./install-lombok.sh
cp init.lua ~/.config/nvim/init.lua
```

Open a Java file inside a Maven project and allow time for the first import.
The server may download Maven dependencies. Each project gets its own cache.

| Action | Keys |
| --- | --- |
| Go to definition / return | `gd` / `Ctrl-o` |
| Documentation | `K` |
| Rename symbol | `grn` |
| References | `grr` |
| Code actions | `gra` |
| Completion (Insert mode) | `Ctrl-x Ctrl-o` |
| Select / accept / dismiss completion | `Ctrl-n` or `Ctrl-p` / `Ctrl-y` / `Ctrl-e` |
| Next / previous diagnostic | `]d` / `[d` |
| Diagnostic details | `Ctrl-w d` |

Only `gd` is a custom mapping. The others are native Neovim commands/defaults.
`:Format` is our convenience command for native LSP whole-file formatting.
It changes the buffer without saving; inspect the result, undo with `u` if
needed, and save with `:w`. Formatting does not run automatically on save.
Use `:checkhealth vim.lsp` for connection troubleshooting. Without an installed
server, the editor still works and skips LSP activation.

Upstream installation and runtime requirements:
https://github.com/eclipse-jdtls/eclipse.jdt.ls

### Lombok projects

Run `bash ./install-lombok.sh` to install the pinned Lombok 1.18.48 Java agent
beside JDT LS. Copy the updated init.lua and fully restart Neovim. The launcher
loads it using `--jvm-arg=-javaagent:...`, enabling Eclipse's compiler to recognize
Lombok-generated members. This adds no Neovim plugin. Without the agent file,
the language server still launches normally, with Lombok support unavailable.

The first launch with the agent uses a separate project workspace and reimports
Maven, avoiding stale non-Lombok indexes. Allow time for this import. Projects
still need their own Lombok dependency and annotation processor configuration
for Maven builds; the editor agent does not change pom.xml or fix build settings.

References: [Lombok releases](https://projectlombok.org/changelog),
[JDT LS launcher JVM arguments](https://github.com/eclipse-jdtls/eclipse.jdt.ls/blob/main/org.eclipse.jdt.ls.product/scripts/jdtls.py).

## Run one test from the cursor

Save changed buffers with `:wa`, place the cursor inside a test method, and run
`:TestNearest`. The command asks JDT LS for the containing method and executes
Maven `test` with a `-Dtest=package.Class#method` selector. It uses the project's
wrapper when available. Maven runs as a native background job; your normal
`:make` command and window working directories remain unchanged.

After selecting a test, switch to implementation code, make changes, save with
`:wa`, and use `:TestLast` to rerun it. The project root and method are remembered
for the current Neovim session, including failing test runs. Reruns use that
project even if the current buffer belongs to another project. No LSP request
is needed for a rerun. Before selecting any test, `:TestLast` explains that you
need to run `:TestNearest` first.

This first version supports top-level test classes under `src/test/java` and
Maven Surefire method selection. Nested classes, custom source layouts, and
Failsafe integration tests need separate support. Symbol lookup may wait up to
three seconds; Maven then runs while you keep editing. Save before starting a
run. Files changed while Maven runs can affect what it reads; a run is not a
snapshot of the project.

Only one test job runs at a time. Use `:TestStop` to cancel it and wait for the
completion notification before restarting. Results create a new quickfix list
at completion; `:colder` returns to the preceding list if you were searching.
`:copen` shows parsed errors and `:TestOutput` opens full completed output,
including Maven's summary. Runtime test failures may not all have navigable
source locations. Exit code zero reports Maven success; check its summary to
confirm the expected tests ran. Exiting Neovim stops an active test job.

Selector documentation:
https://maven.apache.org/surefire-archives/surefire-2.22.2/maven-surefire-plugin/examples/single-test.html

## Project settings and running applications

Open a Maven project file and run `:ProjectSettings`. This opens a local JSON
file under Neovim's data directory, outside your checkout. Each project has its
own file, remembered across restarts. Moving a project changes its settings key.
JSON does not support comments; use the examples below as a reference.

Set `run.command` to an executable followed by its arguments. For a project
using Maven Exec to launch a main class, for example:

```json
{
  "run": {
    "command": ["mvn", "compile", "exec:java", "-Dexec.mainClass=com.example.Main"],
    "env": {}
  }
}
```

Replace the main class with yours. Use `"./mvnw"` instead of `"mvn"` when your
project has an executable Maven wrapper. For a Spring Boot project configured
with the Spring Boot Maven plugin, the command can instead be:

```json
["./mvnw", "spring-boot:run"]
```

That array is the value of `run.command`, not the complete settings file.
Choose the command appropriate to your project; the editor does not add Maven
plugins or infer a main class. `run.env` optionally maps environment names to
string values, such as `"JAVA_HOME": "/absolute/path/to/jdk"` for Maven. Settings
are plain text, so keep secrets outside them. Environment settings affect only
the launched application/build process, not JDT LS or the test runner.

Save settings and project changes with `:wa`, then use `:Run`. A native terminal
opens below the editor and runs from the Maven root. Command arguments are passed
directly: shell operators, environment expansion, and tilde expansion are not
interpreted. `Ctrl-\ Ctrl-n` returns to Normal mode; `:RunStop` stops the process,
and `:q` closes the window. Output remains available after exit. Only one
application runs at a time, and exiting Neovim stops it.

## Java debugging

Install the optional debugger once, copy the configuration, and restart:

```sh
bash ./install-debug.sh
cp init.lua ~/.config/nvim/init.lua
```

This installs nvim-dap 0.10.0 as an optional native package and the Java debug
extension 0.59.0 as JDT LS bundles. There is no plugin manager or automatic
download at startup. We reuse the protocol client; our launch logic and controls
are in init.lua. Installation requires network access, curl, tar, and Python 3.

Open a Java file and wait for JDT LS import. Set a breakpoint with
`:DebugBreakpoint`, then `:Debug`. For standalone main classes, the server
discovers entry points, resolves classpaths and the project JDK, and offers a
native picker when needed. This launches Java directly, not the `:Run` command.
Build with `:make` first if needed. Preview-feature JVM arguments and special
application arguments must be configured explicitly.

Optional `debug` settings can be added alongside `run` in `:ProjectSettings`:

```json
{
  "run": { "command": [], "env": {} },
  "debug": {
    "main_class": "com.example.Main",
    "args": [],
    "vm_args": "",
    "env": {}
  }
}
```

### Debug an application server

`mgp_serving` at `/home/alontalmor/dev/Projects/mgp_serving/trunk` builds a WAR.
Its utility main classes are not the serving application's entry point. Debug
the server JVM by attaching, once it has been started with JDWP enabled.

Use this `debug` object in local project settings, with your server's actual
debug port (5005 is only an example):

```json
"debug": {
  "request": "attach",
  "host": "127.0.0.1",
  "port": 5005
}
```

Keep the debug listener local for a local session. For mgp_serving, the supplied
`run-catalina.sh` builds with Maven (including tests), deploys `target/ROOT.war`,
and starts the installed TomEE WebProfile 10.1.2 with local HTTP port 8081 and
JDWP port 5005. Its independent base is under Neovim's state directory; the
installed TomEE and IntelliJ runtime remain unchanged. The project currently
targets Java 25, so Maven and TomEE must use a suitable JDK. Set `JAVA_HOME` in
`run.env` if your shell defaults to an older JDK.

To configure the supplied launch, open a Java file in mgp_serving and run:

```vim
:ProjectSettings
:%!cat /home/alontalmor/dev/SideProjects/nvim-as-ide/examples/mgp-serving.json
:w
```

The filter replaces the local settings buffer with the supplied JSON; retain any
custom environment values you already need. `:Run` packages and starts TomEE.
Leave terminal input mode with `Ctrl-\ Ctrl-n`, set breakpoints in source, then
use `:Debug` to attach. The app must have finished startup before you attach.
Use `:DebugStop` to detach and `:RunStop` to stop the server. HTTP and debug
ports must be free; stop an existing IntelliJ instance using port 8081 first.
Change the ports in settings if needed, keeping `NVIM_DEBUG_PORT` and `debug.port`
in sync. Running with `--prepare-only` prepares the base without building or
starting anything; this was validated using the installed TomEE config in /tmp.

Runtime startup, application dependencies/services, and a real breakpoint still
need a local check. Installer and debugger orchestration were verified offline;
network downloads cannot run in the restricted agent session.

For an attached server, `:DebugStop` disconnects without terminating its JVM.
For an application launched by `:Debug`, it terminates that application.

| Command | Purpose |
| --- | --- |
| `:Debug` | Launch a main class or attach according to project settings |
| `:DebugBreakpoint` | Toggle breakpoint at the cursor |
| `:DebugContinue` | Resume after a pause |
| `:DebugNext` | Step over a statement |
| `:DebugInto` / `:DebugOut` | Step into / out of a method |
| `:DebugInspect` | Inspect the variable under the cursor while paused |
| `:DebugScopes` | Open variables and scopes in a sidebar |
| `:DebugStop` | Stop a launched application or detach from an attached JVM |

References: [nvim-dap](https://github.com/mfussenegger/nvim-dap),
[Java debug adapter](https://github.com/microsoft/java-debug).

## Shared Tomcat and TomEE runner

Both servers use `bin/catalina.sh`, so every WAR project can use the same
`run-catalina.sh`. Per-project values belong in `run.env`; no separate runner
script is needed. `examples/mgp-serving.json` configures TomEE, and
`examples/tomcat.json` provides a Tomcat template using your installed Tomcat 11.

Open a Java file in the intended project, run `:ProjectSettings`, and load a
template, for example:

```vim
:%!cat /home/alontalmor/dev/SideProjects/nvim-as-ide/examples/tomcat.json
```

Change the WAR filename and context to match that project before saving.
Use a compatible server version for the application's Servlet/Java EE/Jakarta EE
APIs; choosing a server path does not migrate the application.

| run.env setting | Meaning |
| --- | --- |
| `NVIM_SERVER_HOME` | Required Tomcat or TomEE installation path |
| `NVIM_WAR_FILE` | Required built WAR, relative to project root or absolute |
| `NVIM_CONTEXT_PATH` | URL context; default `/`; supports `/app` and `/foo/bar` |
| `NVIM_HTTP_PORT` | Local HTTP port; default 8080 |
| `NVIM_DEBUG_PORT` | Local JVM debug port; default 5005; match debug.port |
| `NVIM_PROJECT_ROOT` | Optional override; normally uses :Run's working directory |
| `NVIM_SERVER_BASE` | Optional independent runtime path; otherwise derived automatically |
| `JAVA_HOME` | Optional JDK for Maven and the server |

The runner builds through the Maven wrapper when available, copies the WAR
under its context's deployment name, and starts the server in the foreground.
It creates a separate runtime for each project, server installation, and context,
copies server configuration on first use, and sets up one local HTTP connector.
Installation files stay unchanged. Concurrent servers need distinct HTTP and
debug ports. A lock prevents duplicate launches against the same runtime.

The old `run-mgp-serving.sh` is now just a compatibility shim forwarding legacy
`MGP_*` settings to the shared runner. Existing settings continue to work; new
projects use the shared script directly. Runtime validation is available with
`--prepare-only`, and tests run with `python3 -m unittest discover -s tests -v`.

To migrate existing mgp_serving settings in place, stop its current `:Run`
process and run `python3 migrate-mgp-settings.py` from this repository. It
switches to the shared runner, renames legacy environment keys, adds WAR/context
defaults, preserves other settings, and saves the original as
`.json.before-shared-runner`. If the settings buffer is already open, reload
it with `:edit` after resolving any unsaved edits. No init.lua update is needed.

## SVN integration

The small SVN integration lives in the commented SVN block of `init.lua` and
uses the installed `svn` executable. No third-party SVN plugin is required.
Copy the updated configuration and restart Neovim:

```sh
cp /home/alontalmor/dev/SideProjects/nvim-as-ide/init.lua ~/.config/nvim/init.lua
```

`:SvnStatus` opens a read-only review window with readable labels for modified,
added, deleted, unversioned, and conflicted paths, plus property and tree conflicts.
Project changes and changed directory external working copies have separate
sections. Clean external sections are hidden by default, with a summary count.
Press `x` to show all externals or hide clean sections again. Modified Ignore
files remain visible, including inside external sections.
`Enter` opens a selected file or directory in another window; Space toggles
commit selection, `c` opens a commit message, `i` toggles Ignore, `l` assigns a
changelist, `R` previews file revert, and `r` refreshes while
preserving the selected path; `q` closes the review window. Repeating
`:SvnStatus` reuses and refreshes the existing window for that project.

Press `d` on an entry to inspect its changes. Ordinary modified files use native
side-by-side diffs, including unsaved buffer edits. Property changes, additions,
deletions, and conflicts use a read-only SVN patch of saved working-copy changes.
A property-only directory row shows that directory's changes, not all descendants.
Unversioned paths have no SVN diff; open them with Enter instead.

Native diff navigation uses `]c` and `[c`. Close the BASE window with `:q` and run
`:diffoff` in the remaining file when finished. `:SvnDiff` remains available
directly for files with a BASE revision. Status itself describes saved working-copy
changes; refresh it with `r` after a save, property edit, or external update.
Status loading runs asynchronously and does not contact the repository server.

`:SvnExternals directory` opens the directory's property as an editable buffer.
`:w` calls local `svn propset --file`, retaining unsaved edits if SVN rejects the
value. Saving neither downloads externals nor commits changes. A stale property
buffer cannot overwrite another tool's edits: discard it with `:bd!` and reopen.
`:Svn command arguments` opens an interactive terminal for other operations.
It defaults to the nearest Maven project, then the SVN working-copy root.

For `mgp_serving`, open a file inside `/home/alontalmor/dev/Projects/mgp_serving/trunk`
and run:

```vim
:SvnExternals src/main/java
```

Add this entry alongside the existing externals (verified from `mgp_client`):

```text
svn://svn.pikoya.com/smartmedia_java/GeneralCode/com/pikoya/minifier/base com/pikoya/minifier/base
```

Save with `:w`, inspect with `:Svn diff --properties-only src/main/java`, then
fetch with `:Svn update src/main/java`. After the update completes, rerun `:make`.
This provides the missing `Minifier` and `Minifiers` source package; a fresh build
will show whether any other dependencies need attention. Commit the property
change separately when ready.

SVN support includes status, property editing, native file diffs, changed-line
signs, a history browser, and a terminal interface. Hunk previews and undoable
buffer restores, confirmed whole-file revert, changelists, and a commit editor
are also available.
The offline integration test creates a temporary SVN repository and checks status,
paths containing spaces, @, and XML entities, external grouping, conflict labels,
status actions, property saves, invalid values, stale-buffer
protection, native BASE diffs, line signs, change navigation, history patches,
hunk previews, undoable restores, selective commits, separate external commits,
stale-draft rejection, repository-hook failure/retry, Ignore protection, and
confirmed file reverts with cancellation and stale-preview checks:

```sh
python3 -m unittest discover -s tests -p test_svn.py
```


### Changed lines and revision history

Versioned text files show signs automatically: `+` for added lines, `~` for
modified lines, and `_` where lines were deleted. Signs compare the current
buffer, including unsaved edits, to local SVN BASE. A deletion uses the preceding
surviving line (or line 1 for a deletion at the beginning). Diagnostic signs have
higher priority, so they may cover an SVN sign in the same gutter slot.

`:SvnNextChange` and `:SvnPrevChange` jump between changes without entering diff
mode. `:SvnRefresh` reloads BASE after an update performed elsewhere. BASE also
refreshes when opening, entering, or saving a file and when the editor regains
focus. Typing updates the signs after 200 ms using cached BASE; there are no
network requests on edits. Binary files, BASE contents over 2 MiB, and buffers
with more than 20,000 lines skip signs. New/unversioned files without BASE also
skip signs; they remain visible in status. Line-ending-only changes are not
represented by these line signs; SVN's diff can still show them.

`:SvnLog` shows the latest 50 commits affecting the project, including messages
and changed paths. `:SvnLog src/main/java` or `:SvnLog path/to/File.java` narrows
the history. Move onto a revision entry and press Enter to open its patch for
that target. `:SvnRevision 123` opens revision 123's patch for the project directly.
These buffers are read-only; use `/` to search and `q` to close them. Both history
and patches load asynchronously, with a 30-second timeout. If SVN needs interactive
authentication, use `:Svn log -l 1` first. No history operation commits or reverts.


### Preview and restore a hunk

Place the cursor on a changed line and run `:SvnPreviewHunk`. A native rounded
float shows the selected hunk: `-` lines come from BASE, `+` lines from your
current buffer. Repeat the command to focus the float and scroll; `q` closes it.
Deleted lines use the surviving line with the `_` sign as their cursor target.

`:SvnRevertHunk` restores that hunk's logical lines from local SVN BASE. It edits
only the current buffer, preserving unrelated changes. Unsaved edits in the
selected hunk are restored too. The operation creates its own undo block:
`u` restores the change, Ctrl-r reapplies the restoration, and `:w` saves when
ready. It never invokes `svn revert` or changes directory/file properties.

Both commands reread local BASE before selecting the hunk, so an external SVN
update does not leave these actions using cached content. They reject buffers
without a matching change, files without BASE, and binary/large files. Restore
also rejects read-only buffers or disabled undo. These commands operate on
logical lines; use SVN's full diff to inspect line-ending-only changes.


### Selective commits

1. Open `:SvnStatus` and press Space on each path to include. `[x]` marks selections.
2. Press `c` to open a normal Vim buffer for the message.
3. Write the message and use `:w` to save the draft. Saving does not commit.
4. Run `:SvnCommitReview` from the message buffer to inspect the exact paths and
   patches captured when the draft opened. Close the review with `q` and return
   to the message window.
5. Run `:SvnCommitSubmit` from the message buffer to send the commit. This command
   performs the repository write. A result buffer shows SVN output; status refreshes
   after success. `q` closes the result.

Selections are explicit, using `svn commit --depth empty`. Selecting a directory
with changed properties (including `svn:externals`) does not include child files.
For newly added directories, select required added parent directories and files
explicitly. Each commit belongs to one working copy; the status window prevents
mixing project and external sections, even when they share a repository.

The editor refuses empty messages, conflicted/unversioned paths, selected unsaved
file/property buffers, and selections whose saved changes have changed since
opening the draft. For changed selections, refresh status and open a fresh draft;
you can copy the message from the previous buffer. A failed commit keeps the draft
and shows SVN's error. Authentication can be established in a `:Svn` terminal
before retrying. Out-of-date errors require an appropriate SVN update and a fresh
draft; the editor does not update automatically. A successful draft cannot submit twice.

Messages saved with `:w` live under Neovim's state directory in `svn-commits/`, with
unique filenames. The selection exists only in the running editor session;
reopening a saved message after restarting does not restore its commit targets.
Closing a message window hides its buffer. A commit already running continues
if its draft window closes, and its result appears when SVN finishes.

This initial commit editor handles ordinary file changes and directory properties.
Directory deletions, replacements, copied directories, file externals, and files
larger than 16 MiB use explicit `:Svn` commands for now. It captures raw bytes as
well as patches to detect changed binary selections before submission.


### Changelists, including Ignore

SVN changelists group tracked files locally; they do not untrack files or act as
`svn:ignore` patterns. Existing memberships are read from SVN and shown as
`[Name]` beside status labels, including inside external sections.

In `:SvnStatus`, `i` toggles the selected file into/out of `Ignore`. `l` opens a
native input prompt to assign any name; an empty value removes membership.
`:SvnChangelist Ignore` works on the current or selected file, and
`:SvnChangelist NAME path/to/file` accepts an explicit path. Use
`:SvnChangelistRemove [path/to/file]` to remove membership. Direct commands work
on clean tracked files too; the status window focuses on working-copy changes.

The commit editor rejects files in `Ignore` both when selecting them and just
before submission. Assigning Ignore to a selected path removes its selection
on refresh. These files remain visible and available for editing/diffs.
To commit one intentionally, remove or change its membership first. Other lists
can be protected by setting this before the SVN block in `init.lua`:

```lua
vim.g.svn_ignored_changelists = { 'Ignore', 'LocalOnly' }
```

Names are case-sensitive. This protection applies to this plugin's commit editor;
raw `:Svn commit` commands retain normal SVN behavior and can include Ignore files.
Changelists apply to files, not directories, and remain local to each working copy.

### Confirmed whole-file revert

Run `:SvnRevertFile` on an open file, `:SvnRevertFile path/to/file`, or press `R`
on a file in status. A read-only preview shows saved text/property differences
and unsaved buffer changes. A native selection prompt defaults to Cancel.
Choosing Revert file invokes local `svn revert --depth empty`, reloads the file's
loaded buffer, and refreshes status. Revert keeps changelist membership intact.

This discards the file's saved modifications, property changes, and unsaved
buffer edits. It is an SVN working-copy operation; Vim undo is not a recovery
guarantee. Use the undoable `:SvnRevertHunk` when restoring only a text hunk.
The file, BASE, properties, and buffer are rechecked after confirmation; if any
changed since the preview, open a fresh preview instead. Cancellation changes
nothing and leaves the preview available to inspect.

Files must have SVN BASE and be at most 16 MiB. Newly added files and directories
use explicit `:Svn` operations for now. Deleted versioned files can be restored,
and conflicted files can be reverted after reviewing what will be discarded.


### Changelist groups and native folds

Each project/external section groups files under `Changes` (no changelist) and
named changelist headings, with file counts. Ordinary changes come first;
protected lists such as `Ignore` come last and start collapsed. This keeps local
modifications out of the everyday review list while leaving them easy to inspect.

Put the cursor on a group heading and use native `za` to toggle it, `zo` to open,
or `zc` to close. Expand a group before acting on its files. Refresh preserves
which groups you opened or closed. External working copies retain independent
sections and commit selections. Folding changes only the view; it does not
change changelist membership or commit protection.


### Delete the current SVN file

Run `:SvnDelete` from the file or on a selected file in status, then choose
Delete file. It removes the file, closes its buffer, and schedules SVN deletion.
Commit the deleted entry separately through status. An explicit path also works:
`:SvnDelete path/to/file`. Paths with spaces or @ are handled automatically.
Unsaved buffers are rejected, and SVN's normal protection against deleting local
modifications remains enabled. Cancellation leaves the file and buffer intact.


### Blame the current line

`:SvnBlame` attributes the current unchanged line to its SVN BASE revision and
opens a focused native float with its author, date, and revision. Enter opens the
commit message and affected paths; `d` opens that revision's patch for the file;
`q` closes the float. Message and patch output buffers also close with `q`.

Local insertions or deletions above the cursor are mapped to the corresponding
BASE line. Added or modified lines inside a local diff hunk are rejected instead
of displaying an attribution for unrelated text. Text files up to 2 MiB are
supported. Network blame runs asynchronously with a 30-second timeout; buffer
or BASE changes during loading require a fresh request. Authenticate in a `:Svn`
terminal if the repository needs interactive credentials.

`:SvnDelete` now identifies unversioned/ignored files before requesting SVN info
and directs you to native `:Ex` and `D`. It leaves those files untouched: there
is no tracked deletion to schedule or commit.


### Text conflict resolution with native diffs

Run `:SvnConflict` on an open conflicted file or press `v` on its status row.
An explicit path works too: `:SvnConflict path/to/file`. The command reads SVN's
reported conflict artifacts and opens a separate tab containing three native
diff windows: the actual editable RESULT, and read-only LOCAL and INCOMING copies.
It never overwrites the result or marks it resolved automatically.

Use Ctrl-w h/l to switch windows and `]c`/`[c` to navigate differences. Edit RESULT
directly, or use `:diffget NUMBER` there to take the hunk under the cursor from a
source; each source header displays its buffer number. A conflict region can span
multiple native diff hunks. `:%diffget NUMBER` takes the entire source version
when that is your intended choice. Save RESULT with `:w` when satisfied.

`:SvnResolve` (or `S` on the status row) checks that the merged file is saved and
contains no conflict markers, then asks for confirmation. It accepts the saved
working file using `svn resolve --accept working --depth empty`, removing SVN's
conflict artifacts and refreshing status. It checks the result and conflict
artifacts again after the prompt; edits during confirmation require a fresh review.
Cancellation leaves the conflict intact. Resolution does not commit: inspect the
result and use the normal selective commit workflow separately.

`:tabclose` closes the conflict view using native Vim buffer rules. Text conflict
artifacts up to 2 MiB are supported. Property and tree conflicts are deliberately
rejected so accepting a text result cannot silently resolve those other changes;
use `:Svn resolve path` to invoke SVN's interactive resolver for them.

Offline tests exercise real text, property, and tree conflicts. They verify the
three diff windows, native diffget, unsaved/marker checks, cancellation, edits
during confirmation, artifact cleanup, and preservation of unrelated conflicts.


Press `?` in `:SvnStatus` for a focused, read-only native help window covering
review keys, changelists, commits, deletion, revert, and conflicts. Scroll with
normal Vim keys; `q` or Escape returns to status without changing its selection.


The status summary shows changed/protected path counts and the selected commit
count with its project/external scope. File rows use aligned status columns,
without repeating changelist names already shown in headings. `[x]` marks selected
paths, `[ ]` available paths, and `[-]` protected or otherwise unavailable paths.
Unversioned files are labeled untracked; SVN behavior is unchanged.


### Add new files

Save a new file with `:w`, then run `:SvnAdd`. From status, press `a` on an
untracked file. An explicit path also works: `:SvnAdd path/to/file`. The command
schedules the saved file for addition and refreshes status; it does not commit.
Select the added file and use the normal commit editor when ready. Unsaved
buffers and directories are rejected. Missing parent directories are scheduled
with `--parents`; select those added parents as well when committing the file.
Use explicit `:Svn add` commands for recursive directory additions.


### Keep Eclipse metadata out of Maven projects

JDT LS now receives the JVM property
`-Djava.import.generatesMetadataFilesAtProjectRoot=false`, redirecting generated
`.project`, `.classpath`, `.factorypath`, and `.settings` metadata into its private
workspace under Neovim's cache directory. A new `-private-metadata` workspace suffix
starts a fresh index; the first open can take longer while Java reimports the project.
The option must be a JVM argument, not just a Java LSP settings value.

Existing project-root metadata takes precedence. Close Neovim, install the updated
`init.lua`, and remove the generated unversioned metadata once before reopening.
For `mgp_serving`, verify those four entries remain unversioned in SVN and then,
from `/home/alontalmor/dev/Projects/mgp_serving/trunk`, run:

```sh
rm -rf -- .classpath .factorypath .project .settings
```

Do not use this cleanup on intentionally maintained or versioned Eclipse settings.
The language server's private copies remain available for Java features.
See the upstream [metadata location documentation](https://github.com/redhat-developer/vscode-java/blob/main/document/_java.metadataFilesGeneration.md)
and [JDT LS filesystem implementation](https://github.com/eclipse-jdtls/eclipse.jdt.ls/blob/main/org.eclipse.jdt.ls.filesystem/src/org/eclipse/jdt/ls/core/internal/filesystem/JLSFsUtils.java).


Space toggles a commit selection in place: only the row marker and selection
summary update. It keeps cursor/scroll/fold state and does not rerun project
status. Per-path commit eligibility is still checked; press `r` for a full refresh.

### Publish the prepared snapshot

The personal repository is `git@github.com:alonttal/Neovim-Config.git`.
When a restricted editing session cannot push, it can export `Neovim-Config.bundle`
(an ignored Git bundle containing the prepared commit). Run `bash ./publish-github.sh`
from a normal terminal to publish it. The helper clones the destination, imports
our prepared files, preserves existing remote history and unrelated files, and
pushes without force. It leaves a normal Git checkout available afterward.

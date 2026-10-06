# Neovim cheat sheet by importance

For our current native-first setup and Maven Java projects. Start with section 1;
keep the rest nearby and learn commands when you need them.

**Notation:** `Ctrl-w h` means hold Ctrl and press w, release, then press h.
`gd` means press g then d. Commands beginning with `:` require Enter.
Unless marked otherwise, press Escape first to enter Normal mode.

## 1 Learn these first

| Task | Keys or command | Remember |
| --- | --- | --- |
| Return to Normal mode | `Escape` | Your starting point |
| Start typing / finish typing | `i` / `Escape` | Insert |
| Save | `:w` | Write |
| Close current window | `:q` | Quit; refuses unsaved changes |
| Save and close current window | `:wq` | Write then quit |
| Undo / redo | `u` / `Ctrl-r` | Undo a change |
| Search current file | `/name` then Enter | Search forward |
| Next / previous match | `n` / `N` | Repeat search |
| Open another file | `:e path/to/File.java` | Edit; Tab completes paths |
| Return to previous buffer | `Ctrl-^` or `:b#` | Alternate buffer |
| Java documentation | `K` | Cursor on a symbol; LSP required |
| Java definition / return | `gd` / `Ctrl-o` | Go to definition / jump back |

Buffers hold file contents; windows display buffers. Closing a window does not
necessarily remove its buffer. You can switch away from unsaved buffers;
use `:ls` to find them and `:wa` to save them all. To discard a buffer's unsaved
changes and close its window deliberately, use `:q!`.

## 2 Move and edit efficiently

Vim editing combines an **operator** with a **motion or text object**:
`d` deletes, `c` changes (deletes then enters Insert mode), and `y` copies.
For example, `dw` deletes through the next word start and `ciw` changes the word
under the cursor. Counts repeat motions: `5j` moves five lines down.

| Task | Keys | Remember |
| --- | --- | --- |
| Move left / down / up / right | `h` / `j` / `k` / `l` | Normal mode movement |
| Next word / previous word / word end | `w` / `b` / `e` | Word movement |
| First nonblank character / line end | `^` / `$` | Line movement |
| File start / end | `gg` / `G` | Whole file |
| Move a displayed relative distance | `5j` / `5k` | Use the numbers beside lines |
| Match a bracket | `%` | Cursor on a bracket |
| Append after cursor / at line end | `a` / `A` | Append |
| New line below / above | `o` / `O` | Open a line and start typing |
| Delete / copy a line | `dd` / `yy` | Doubled operators act on lines |
| Paste after / before cursor | `p` / `P` | For line copies: below / above |
| Change a word / contents of quotes | `ciw` / `ci"` | Change inside |
| Change through line end | `C` | Start typing a replacement |
| Repeat last editing change | `.` | Dot repeats |
| Move back / forward in edit history | `:earlier 5m` / `:later 5m` | Five minutes of history; also accepts `30s` or `1h` |
| Select characters / lines | `v` / `V` | Move, then use d, c, or y |
| Indent / unindent line | `>>` / `<<` | Four spaces in our defaults |
| Copy / paste system clipboard | `"+y` / `"+p` | Copy a selection with `"+y`; needs clipboard support |

Undo history now survives saving and restarting Neovim. Reopen the file and
use `u` or `Ctrl-r` as usual. `:earlier` and `:later` also traverse edit branches;
use them when a sequence of undo and new edits makes ordinary redo insufficient.
These commands change the buffer; inspect the result before saving. Persistent
undo preserves history when you save; it does not save unsaved work automatically.
To inspect the undo file's location, use `:echo undofile(expand('%:p'))`.

## 3 Navigate project files and search results

| Task | Command | Notes |
| --- | --- | --- |
| Browse current directory | `:Explore` | Built-in netrw; Enter opens, `-` goes up |
| Find a Maven Java source by filename | `:find UserService.java` | Searches main/test package folders; Tab completes |
| Find a source in a horizontal split | `:sfind UserService.java` | Same search directories as :find |
| Select a second matching filename | `:2find UserService.java` | Useful when names repeat; package paths also work |
| List open buffers | `:ls` | Note the buffer number or name |
| Switch buffer | `:b NAME` or `:b NUMBER` | Tab completes names |
| Next / previous buffer | `:bn` / `:bp` | Cycle through listed buffers |
| Search project | `:grep UserService` | ripgrep; searches current directory |
| View results or errors | `:copen` | Quickfix list; Enter opens a selected item |
| Next / previous result | `:cn` / `:cp` | Short forms of cnext / cprevious |
| Close result window | `:cclose` | Keeps the results |
| Jump back / forward | `Ctrl-o` / `Ctrl-i` | Jump history; works across files |
| Show working directory | `:pwd` | Java project setup changes it per window |
| Clear search highlighting | `:noh` | Only if highlighting is visible |

Quickfix is a built-in list of locations. Both project search and build errors
use it; a new search or build normally replaces the current list. LSP references
can also appear there.

Open a Maven directory, `pom.xml`, or a Java file to configure `:find`. It searches
`src/main/java` and `src/test/java` recursively, plus the file's directory and
the window's working directory. Use `:setlocal path?` to inspect that list.
Custom source layouts and sibling Maven modules are not included automatically.

## 4 Java language tools

These require JDT LS to be attached to the Java buffer. The first Maven import
may take time. `gd` and `Space em` are our custom mappings; `:Format` is our convenience
command; the other keys below are native.

| Task | Keys | Notes |
| --- | --- | --- |
| Documentation | `K` | On a class, method, or variable |
| Definition | `gd` | Return with Ctrl-o |
| Rename symbol | `grn` | Updates references; save changed buffers with `:wa` |
| Find references | `grr` | Where the symbol is used |
| Find implementations | `gri` | Useful for interfaces |
| Code actions | `gra` | Available fixes and refactorings at the cursor |
| Extract method | Select with `V` or `v`, then `Space em` | Enter a method name; Escape cancels; edits stay unsaved |
| Format current file | `:Format` | Our command using native LSP; does not save; `u` undoes |
| List document symbols | `gO` | Capital O; classes, methods, and fields |
| Next / previous diagnostic | `]d` / `[d` | Errors, warnings, and other messages |
| Diagnostic details | `Ctrl-w d` | Floating window |
| Toggle method or region fold | `za` | Cursor inside a foldable region |
| Close / open current fold | `zc` / `zo` | Changes the view only |
| Close / open all folds | `zM` / `zR` | Capital M/R; zM may collapse the whole class |
| Open current fold and its nested folds | `zO` | Capital O; useful after zM |
| Java completion | Appears while typing | Insert mode; nothing selected initially; Enter inserts a newline |
| Request completion manually | `Ctrl-x Ctrl-o` | Insert mode |
| Select next / previous suggestion | `Ctrl-n` / `Ctrl-p` | Insert mode, completion menu open |
| Accept / dismiss suggestion | `Ctrl-y` / `Ctrl-e` | Insert mode, completion menu open |
| Method signature help | `Ctrl-s` | Insert mode; some terminals intercept this |

Java folds use ranges from JDT LS and start expanded. The fold column beside
the line numbers marks foldable regions. Wait for the project import before
using fold commands. Fold choices are per window; folding never edits code.

In Normal mode, pause on a Java symbol for about 200 ms to highlight its
references in the current file. Reads use a blue background and writes a green
one when JDT LS distinguishes them. Highlights clear when moving or typing.
No command is needed. This requires JDT LS document-highlight support.

## 5 Build and test Maven projects

Open a Java file inside the project first so our build configuration applies.
Commands use the project's executable `mvnw` when present, otherwise `mvn`.
Builds read saved files. `:make` blocks; `:TestNearest` and `:TestLast` run Maven
in the background. Only one background test run is allowed at a time.

| Task | Command | Notes |
| --- | --- | --- |
| Save current / all changed buffers | `:w` / `:wa` | Save before building |
| Compile | `:make` | Runs Maven compile |
| Run tests | `:make test` | Runs Maven compile test |
| Run test method under cursor | `:TestNearest` | Save all first; top-level methods under src/test/java; needs LSP |
| Rerun last selected test | `:TestLast` | After :wa; works from implementation code; remembered for this session |
| Cancel background test run | `:TestStop` | Wait for completion notification before another run |
| View full last test output | `:TestOutput` | Read-only window; `:q` closes it |
| Edit local project launch settings | `:ProjectSettings` | Set run.command; see README examples |
| Run application / stop it | `:Run` / `:RunStop` | Save with :wa first; native terminal output |

### Debugging after installing the optional debugger

| Task | Command | Notes |
| --- | --- | --- |
| Toggle breakpoint | `:DebugBreakpoint` | Cursor on an executable source line |
| Start debugger | `:Debug` | Uses local debug settings or discovers main classes |
| Resume / step over | `:DebugContinue` / `:DebugNext` | While paused |
| Step into / out | `:DebugInto` / `:DebugOut` | While paused |
| Inspect variable / show scopes | `:DebugInspect` / `:DebugScopes` | While paused |
| Stop / detach | `:DebugStop` | Attached JVM remains running |

For WAR projects such as mgp_serving, configure attach mode and the server's
JDWP port in `:ProjectSettings`; see README.md. A local app-server launch command
still needs configuring. Debugging uses nvim-dap plus a JDT LS adapter bundle.
| Inspect build errors | `:copen` | Enter opens an error location |
| Next / previous build error | `:cn` / `:cp` | Same quickfix navigation as search |

## 6 Windows and terminal

| Task | Command or keys | Notes |
| --- | --- | --- |
| Horizontal / vertical split | `:sp` / `:vsp` | Two views of the current buffer |
| Open another file in a vertical split | `:vsp path/to/File.java` | Tab completes paths |
| Move between windows | `Ctrl-w h/j/k/l` | Left / down / up / right; choose one direction |
| Close current window | `Ctrl-w c` | Use `:q` for the last window |
| Keep only current window | `Ctrl-w o` | Can refuse to hide unsaved buffers |
| Equalize window sizes | `Ctrl-w =` | After arranging splits |
| Open terminal below | `:sp` then `:terminal` | Shell runs in a buffer |
| Type in terminal | `i` | From Normal mode in a terminal buffer |
| Leave terminal input mode | `Ctrl-\ Ctrl-n` | Then navigate normally |
| Finish shell session | `exit` then Enter | In terminal input mode |

## 7 Help when you forget

| Task | Command |
| --- | --- |
| Open this cheat sheet beside your code | `:vsp /home/alontalmor/dev/SideProjects/nvim-as-ide/CHEATSHEET.md` |
| Help for a command | `:help :grep` or `:help :make` |
| Help for a key | `:help ciw` or `:help CTRL-W` |
| Understand an option | `:help 'relativenumber'` |
| Built-in editing tutorial | `:Tutor` |
| LSP troubleshooting | `:checkhealth vim.lsp` |
| Preview a bundled color scheme | `:colorscheme` then Space and Tab |

In help, place the cursor on a linked topic and press `Ctrl-]` to follow it;
`Ctrl-o` returns. Close the help window with `:q`.

The bottom status line shows mode, file path, `[+]` for unsaved changes,
`E:`/`W:` diagnostic counts when present, filetype, line:column, and progress
through the file. The mode badge turns green in Insert mode and purple in
Visual mode. Theme previews last until restart; change the `colorscheme` line
in init.lua to make your choice permanent.

## A short practice session

1. Open a Java file, search for a method with `/methodName`, and press `K`.
2. Jump to a definition with `gd`, then return with `Ctrl-o`.
3. Search the project with `:grep SomeClass` and inspect it with `:copen`.
4. Make a small edit, save with `:w`, and compile with `:make`.
5. If errors appear, use `:copen` and Enter to visit one.

Learn these through repetition. Keep the other sections as a lookup reference.

## SVN: working-copy changes

| Task | Command | Remember |
| --- | --- | --- |
| Review changed files | `:SvnStatus` | Separate project/external sections; Enter opens, `d` diffs, Space selects, `c` drafts, `r` refreshes, `q` closes |
| Compare current file with SVN base | `:SvnDiff` | Native side-by-side diff, includes unsaved buffer edits |
| Move between differences | `]c` / `[c` | Next / previous diff hunk |
| Close comparison | `:q`, then `:diffoff` in remaining file | BASE buffer is read-only |
| Edit externals on a directory | `:SvnExternals src/main/java` | Relative to Maven project root; `:w` saves the local property |
| Fetch changed externals | `:Svn update src/main/java` | Performs a real SVN update |
| Show property changes | `:Svn diff --properties-only src/main/java` | Inspect before committing |
| Open conflict merge view | `:SvnConflict` / `v` in status | Separate tab: editable RESULT, read-only LOCAL and INCOMING |
| Take a source hunk | `:diffget NUMBER` in RESULT | Source window headers show the buffer numbers; `]c`/`[c` navigate |
| Mark saved merge resolved | `:SvnResolve` / `S` in status | Save, remove markers, review, then confirm; no commit |
| Close conflict view | `:tabclose` | Normal Vim handling of unsaved buffers applies |
| Blame current line | `:SvnBlame` | Author/date/revision; Enter shows message, `d` shows file patch, `q` closes |
| Browse commit history | `:SvnLog` | Latest 50 commits; Enter shows selected revision patch, `q` closes |
| History for one file | `:SvnLog path/to/File.java` | Enter shows patches limited to that target |
| Inspect a revision | `:SvnRevision 123` | Read-only project patch |
| Help for SVN status | `?` in status | Scroll with normal Vim keys; `q` or Escape closes |
| Expand/collapse changelist group | `za` on its heading | Ignore starts collapsed; `zo` opens, `zc` closes |
| Show/hide clean externals | `x` in status | Hidden by default; changed externals remain visible |
| Toggle Ignore changelist | `i` in status | Remains tracked; blocked from this plugin's commit selection |
| Assign a changelist | `l` in status | Enter a name; empty removes membership |
| Changelist for current file | `:SvnChangelist Ignore` | Also accepts `NAME path/to/file` |
| Remove changelist | `:SvnChangelistRemove` | Selected/current file, or supply a path |
| Add new file to SVN | `:SvnAdd` / `a` in status | Save first; schedules addition, commit separately |
| Delete current/selected SVN file | `:SvnDelete` | Confirm; removes file and buffer, schedules SVN deletion; commit later |
| Revert whole file | `R` in status / `:SvnRevertFile` | Preview, then confirm; discards text, properties, and unsaved edits |
| Select commit paths | Space in `:SvnStatus` | `[x]` selected; one project/external section at a time |
| Write commit message | `c` in status | Opens a normal message buffer; `:w` saves only the draft |
| Review commit selection | `:SvnCommitReview` | Run from the draft; `q` closes review |
| Submit the commit | `:SvnCommitSubmit` | Run from the draft; sends selected saved changes to SVN |
| Preview current change | `:SvnPreviewHunk` | Cursor on a sign; repeat to focus the float, `q` closes it |
| Restore current change | `:SvnRevertHunk` | Buffer edit only; `u` undoes, `:w` saves |
| Jump between changes | `:SvnNextChange` / `:SvnPrevChange` | Works in ordinary editing windows |
| Refresh changed-line signs | `:SvnRefresh` | Reload SVN BASE after an external update |
| Other SVN commands | `:Svn command arguments` | Runs at project root; without arguments runs status |
| Leave terminal input | `Ctrl-\ Ctrl-n` | Then use normal window commands |

Use `:SvnExternals` without a path to edit the project root's property. SVN
externals belong to a directory, which may differ from the project root.
`:w` saves locally; update and commit are separate commands. The property editor
refuses to overwrite changes made by another tool while its buffer was open.
After such a conflict, close/discard the property buffer with `:bd!` and reopen it.

The status view includes directory external working copies in separate sections.
Status lists saved changes; `r` refreshes after edits or updates. The `d` action
uses native diffs for ordinary modified files (including unsaved edits), and saved
SVN patches for properties, added/deleted paths, and conflicts. For paths containing spaces, escape the
spaces with backslashes in Ex commands. `:Svn` passes arguments directly to SVN,
so shell pipes and redirections are not supported. `:SvnRevertFile` works on
files with BASE; directory reverts and newly added files use explicit SVN commands.


SVN signs appear automatically beside versioned text: `+` added, `~` modified,
`_` deleted (on a surviving line). Unsaved edits count. Diagnostic signs may
cover them. Newly added files without BASE have no line signs; find them in
`:SvnStatus`. History and revision patches load in the background.


A hunk is a group of nearby changed lines. For `_` deletion signs, place the
cursor on the surviving line with that sign. `:SvnRevertHunk` restores the whole
hunk, including any unsaved edits in it, and leaves other hunks alone. It does
not run `svn revert`, change properties, save, or commit. Use `:SvnPreviewHunk`
first to see what will be restored.


Commit flow: Space selects paths → `c` opens the message → `:w` saves it →
`:SvnCommitReview` reviews → return to the message → `:SvnCommitSubmit` sends it.
Saving alone never commits. Directory selections commit that directory's own
properties, leaving children unselected. A failure preserves the message;
changes made after drafting require a fresh selection/draft. Commit external
working copies separately. Unversioned and conflicted paths cannot be selected.


Changelists are local groupings of tracked files. `[Ignore]` rows stay visible
and can still be opened/diffed, but the commit editor rejects them. Remove or
change membership before selecting one intentionally. This protection applies
to our commit editor; ordinary `:Svn commit` follows SVN's own rules.
Whole-file revert is a working-copy operation, unlike the undoable hunk restore.
Review its preview and confirmation; `u` is not a reliable recovery method for it.

Clean external sections are hidden by default, with a count shown above the
changes. Press `x` to show them all, or press it again to hide them.

Status groups files under Changes and named changelists, showing a count on each
heading. Protected lists start collapsed; refresh preserves your fold choices.

Blame attributes unchanged lines in SVN BASE, adjusting for local insertions and
deletions above them. Locally changed/added lines have no matching committed
attribution. Network loading runs in the background.


Conflict workflow: open the view → edit RESULT or use native diffget → `:w` →
`:SvnResolve` → review and commit separately. Property and tree conflicts use
`:Svn resolve path` for SVN's interactive resolver; this UI handles text conflicts.

Status shows changed, protected, and selected path counts, plus the selected
working copy. `[x]` is selected, `[ ]` is available, and `[-]` is unavailable or
protected. Changelist names appear in group headings rather than every file row.

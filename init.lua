-- Native-first setup; optional debugging uses nvim-dap. See README.md.
-- Lua comments begin with --. true enables an option; false disables it.
-- Space is the prefix for custom <leader> mappings, such as Space em.
vim.g.mapleader = ' '

-- A short name for Neovim's option interface. See :help 'optionname',
-- for example :help 'relativenumber', to learn more about any option below.
local opt = vim.opt
-- Preserve whether an existing file ends with a newline when saving.
-- Reading a file sets 'endofline' from its contents; leave that option alone.
-- Disabling 'fixendofline' prevents :w from adding a missing final newline.
-- New buffers still use Neovim's normal final-newline default.
opt.fixendofline = false
-- Keep undo history after saving, closing, and reopening a file.
-- u / Ctrl-r still undo / redo normally. :earlier 5m moves to the version
-- from five minutes ago; :later 5m moves forward through that history.
-- Neovim stores history in its default state/undo directory, not the project,
-- and creates that directory when needed. See :help persistent-undo.
-- This preserves saved edit history; it does not save unsaved edits for you.
opt.undofile = true
-- Show the current line number, with distances on the other lines.
-- A line marked 5 below the cursor is reachable with 5j (or 5k above).
opt.number = true
opt.relativenumber = true
-- Highlight the cursor's line.
opt.cursorline = true
-- Reserve space for markers such as diagnostics so text does not shift.
opt.signcolumn = 'yes'
-- :split opens below; :vsplit opens to the right.
-- Move between windows with Ctrl-w followed by h, j, k, or l.
opt.splitbelow = true
opt.splitright = true
-- Keep five lines visible above and below the cursor where possible.
opt.scrolloff = 5
-- CursorHold fires after 200 ms without input. Used for symbol highlighting.
-- This native option also controls idle swap-file writes. See :help 'updatetime'.
opt.updatetime = 200
-- /name ignores case; /Name respects case because it contains a capital.
opt.ignorecase = true
opt.smartcase = true
-- Preview :substitute as you type, using a preview split when needed.
-- Example: :%s/old/new/g replaces every occurrence throughout the file.
opt.inccommand = 'split'
-- Display literal tabs at four-column tab stops.
opt.tabstop = 4
-- Indent by four spaces with >>, <<, and automatic indentation.
opt.shiftwidth = 4
-- Tab and Backspace work in four-space steps while editing indentation.
opt.softtabstop = 4
-- Insert spaces rather than literal tab characters when pressing Tab.
opt.expandtab = true
-- Show a completion menu even for one candidate; select nothing initially.
-- This controls the menu, not Java intelligence. In Insert mode, try
-- Ctrl-n / Ctrl-p for native word completion. See :help ins-completion.
opt.completeopt = 'menu,menuone,noselect'
-- Preserve normal registers; use "+y and "+p for the system clipboard.
-- y and p still use Vim registers. Clipboard access needs provider support.
-- Filetype plugins can override indentation for individual languages.

-- Visual layer: all native options, a bundled color scheme, and a status line.
-- True color needs a compatible terminal. habamax is shipped with Neovim;
-- try :colorscheme <Tab> to preview others without installing a theme plugin.
opt.termguicolors = true
opt.background = 'dark'
vim.cmd.colorscheme('habamax')
-- Rounded borders for native floating windows (hover, diagnostics, etc.).
opt.winborder = 'rounded'
-- One status line at the bottom, showing the focused window's buffer.
opt.laststatus = 3

-- These global functions are called by native statusline expressions.
-- Keep them small: Neovim evaluates them frequently while drawing the screen.
function _G.NvimIdeMode()
    local mode = vim.fn.mode(1):sub(1, 1)
    return ({ n = 'NORMAL', i = 'INSERT', v = 'VISUAL', V = 'V-LINE',
        ['\22'] = 'V-BLOCK', R = 'REPLACE', c = 'COMMAND', t = 'TERMINAL',
        s = 'SELECT', S = 'SELECT', ['\19'] = 'SELECT' })[mode] or mode
end

function _G.NvimIdeDiagnostics()
    local win = vim.g.statusline_winid
    local buffer = win and vim.api.nvim_win_is_valid(win)
        and vim.api.nvim_win_get_buf(win) or vim.api.nvim_get_current_buf()
    local counts = vim.diagnostic.count(buffer)
    local errors = counts[vim.diagnostic.severity.ERROR] or 0
    local warnings = counts[vim.diagnostic.severity.WARN] or 0
    local text = ''
    if errors > 0 then text = text .. '%#IdeError# E:' .. errors .. ' ' end
    if warnings > 0 then text = text .. '%#IdeWarning# W:' .. warnings .. ' ' end
    return text .. '%#StatusLine#'
end

-- A few accent colors for the status line. nvim_set_hl defines highlight groups.
-- ModeChanged updates the mode badge; ColorScheme reapplies accents after you
-- preview another scheme. The rest of the editor follows the selected scheme.
local function status_colors()
    local mode = vim.fn.mode(1):sub(1, 1)
    local accent = mode == 'i' and '#a6d189'
        or ((mode == 'v' or mode == 'V' or mode == '\22') and '#c6a0f6')
        or '#8caaee'
    vim.api.nvim_set_hl(0, 'IdeMode', { fg = '#1e2030', bg = accent, bold = true })
    vim.api.nvim_set_hl(0, 'IdeError', { fg = '#ef9f76', bold = true })
    vim.api.nvim_set_hl(0, 'IdeWarning', { fg = '#e5c890', bold = true })
    -- Reference backgrounds stand out without hiding syntax colors.
    -- Reads/text use blue; writes use a green tint. Reapply on theme changes.
    vim.api.nvim_set_hl(0, 'LspReferenceText', { bg = '#303c55' })
    vim.api.nvim_set_hl(0, 'LspReferenceRead', { bg = '#303c55' })
    vim.api.nvim_set_hl(0, 'LspReferenceWrite', { bg = '#34483c' })
end
status_colors()
vim.api.nvim_create_autocmd({ 'ModeChanged', 'ColorScheme' }, {
    callback = function()
        status_colors()
        vim.cmd.redrawstatus()
    end,
})
-- Native statusline syntax: %#Group# selects colors; %f = file path,
-- %m = [+] for unsaved changes; %r = read-only marker; %< truncates long paths;
-- %= separates left/right; %y = filetype; %l:%c = line:column; %p%% = percent.
-- %{...} evaluates a value; %{%...%} also interprets returned highlight codes.
-- See :help 'statusline' to customize this string.
opt.statusline = '%#IdeMode# %{v:lua.NvimIdeMode()} %#StatusLine# %<%f %m%r'
    .. '%=%{%v:lua.NvimIdeDiagnostics()%} %y  %l:%c  %p%% '

-- If ripgrep is installed, use it for native :grep project searches.
-- Example: :grep UserService, then :copen to view the quickfix results.
-- Enter opens a result; :cnext / :cprevious move through them.
-- Search runs in the current working directory. See :pwd and :help quickfix.
if vim.fn.executable('rg') == 1 then
    -- Emit file:line:column:message; capitals make the search case-sensitive.
    -- The final -- ends ripgrep options before the search arguments.
    opt.grepprg = 'rg --vimgrep --smart-case --'
    -- Tell Neovim how to parse that output into the quickfix list.
    opt.grepformat = '%f:%l:%c:%m'
end

-- :find is native file navigation and does not depend on a running LSP.
-- Set its buffer-local search path even when starting with nvim . or pom.xml.
-- Absolute paths keep searches working if netrw changes the window directory.
local function configure_project_find(bufnr)
    if vim.bo[bufnr].buftype ~= '' then return end
    local name = vim.api.nvim_buf_get_name(bufnr)
    local start = vim.b[bufnr].netrw_curdir
        or (name ~= '' and name or vim.fn.getcwd())
    local root = vim.fs.root(start, { 'pom.xml' })
    if not root then return end
    local paths = { '.', '', root, root .. '/src/main/java/**',
        root .. '/src/test/java/**' }
    -- 'path' separates entries with commas/spaces; escape literal characters
    -- so project directories such as "My Java Project" work too.
    for index, path in ipairs(paths) do
        paths[index] = vim.fn.escape(path, '\\ ,')
    end
    vim.bo[bufnr].path = table.concat(paths, ',')
end
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'FileType' }, {
    callback = function(event) configure_project_find(event.buf) end,
})

-- Run :make from the project root. Prefer the project's own wrapper.
-- Save with :write before :make: builds read files from disk.
-- Builds block the editor until finished; inspect errors with :copen.
-- An autocommand runs its callback when the named event occurs.
vim.api.nvim_create_autocmd('FileType', {
    -- Run when Neovim identifies a buffer as Java (not other filetypes).
    pattern = 'java',
    callback = function()
        -- Search upward from this buffer (0) for the nearest project marker.
        -- In multi-module projects this may be a module, not the whole repo.
        local root = vim.fs.root(0, {
            'pom.xml', 'build.gradle', 'build.gradle.kts', '.git',
        })
        -- Without a project marker, leave build settings alone.
        if not root then return end
        -- :lcd changes this window's directory; escape spaces/special chars.
        vim.cmd.lcd(vim.fn.fnameescape(root))
        if vim.fn.filereadable(root .. '/pom.xml') == 1 then
            -- Project navigation above sets 'path' before Java/LSP startup.
            -- Try :find UserService.java; Tab completes filenames.
            -- :sfind UserService.java opens it in a horizontal split.
            -- Duplicate names: :2find UserService.java selects match two,
            -- or provide the package path to choose explicitly.
            -- See :help :find and :help 'path'. Custom source layouts and
            -- sibling Maven modules may need additional directories later.
            -- Built-in compiler configuration parses Maven build errors.
            vim.cmd.compiler('maven')
            -- Buffer-local shell command used by :make. Use the wrapper
            -- if executable, otherwise Maven on PATH. :make runs compile;
            -- :make test adds test, producing mvn compile test.
            vim.bo.makeprg = (vim.fn.executable(root .. '/mvnw') == 1
                and './mvnw' or 'mvn') .. ' compile'
        elseif vim.fn.filereadable(root .. '/build.gradle') == 1
            or vim.fn.filereadable(root .. '/build.gradle.kts') == 1 then
            -- Existing Gradle support; our initial learning focus is Maven.
            -- Gradle's Java compiler emits javac-style diagnostics.
            vim.cmd.compiler('javac')
            -- :make runs classes; :make test adds the test task.
            vim.bo.makeprg = (vim.fn.executable(root .. '/gradlew') == 1
                and './gradlew' or 'gradle') .. ' classes'
        end
    end,
})

-- Native Java folding: JDT LS provides ranges; Neovim displays and toggles them.
-- Folding options belong to a window/buffer view, so configure every window
-- showing this buffer, including later splits. Other filetypes stay untouched.
local function enable_java_folds(bufnr)
    if vim.bo[bufnr].filetype ~= 'java' then return end
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
        local options = vim.wo[win][0]
        if options.foldexpr ~= 'v:lua.vim.lsp.foldexpr()' then
            -- High foldlevel keeps the file expanded when folding is enabled.
            -- Avoid resetting it on later visits, preserving your fold choices.
            options.foldlevel = 99
        end
        options.foldmethod = 'expr' -- Compute fold levels using the expression.
        options.foldexpr = 'v:lua.vim.lsp.foldexpr()'
        options.foldcolumn = '1' -- One column for open/closed fold markers.
        options.foldenable = true
    end
end
-- When an attached Java buffer is opened in another window, configure that
-- view too. Capability checking avoids offering folds without server support.
vim.api.nvim_create_autocmd('BufWinEnter', {
    callback = function(event)
        if vim.bo[event.buf].filetype ~= 'java' then return end
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = event.buf })) do
            if client:supports_method('textDocument/foldingRange') then
                enable_java_folds(event.buf)
                break
            end
        end
    end,
})
-- Normal mode: za toggles; zc closes; zo opens; zM/zR close/open all folds.
-- These are built-in commands. Folding changes the view, not the file contents.
-- Ranges arrive after JDT LS imports the project. See :help folding.

-- Java language intelligence: Neovim is the LSP client; JDT LS is a separate
-- program that understands Java and imports Maven projects. No plugin needed.
-- Install the server with bash ./install-jdtls.sh from this repository.
local jdtls_dir = vim.fn.stdpath('data') .. '/jdtls'
local jdtls = jdtls_dir .. '/bin/jdtls'
-- Optional Java debugger bundles, installed with bash ./install-debug.sh.
-- JDT LS loads these at startup, so installation requires a full restart.
local debug_bundles = vim.fn.glob(vim.fn.stdpath('data') .. '/java-debug/*.jar', false, true)
if vim.fn.executable(jdtls) == 1 then
    vim.lsp.config('jdtls', {
        filetypes = { 'java' },
        init_options = { bundles = debug_bundles },
        -- Only start inside Maven projects for this iteration.
        root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, { 'pom.xml' })
            if root then on_dir(root) end
        end,
        -- This function launches the process. Each project needs its
        -- own server workspace: hashing its full path avoids name collisions.
        cmd = function(dispatchers, config)
            -- Lombok patches Eclipse's compiler inside the server JVM so it
            -- understands generated getters, builders, log fields, etc.
            -- The project's Maven dependency alone cannot enable this patch.
            -- Install the agent with bash ./install-lombok.sh, then restart.
            local lombok = jdtls_dir .. '/lombok.jar'
            local has_lombok = vim.fn.filereadable(lombok) == 1
            local workspace = vim.fn.stdpath('cache') .. '/jdtls/'
                .. vim.fn.sha256(config.root_dir)
            -- Separate the Lombok index from previous non-Lombok sessions.
            if has_lombok then workspace = workspace .. '-lombok' end
            if #debug_bundles > 0 then workspace = workspace .. '-debug' end
            -- A fresh index avoids reusing the previous project-root metadata
            -- layout. This cache is disposable; source files stay in the project.
            workspace = workspace .. '-private-metadata'
            -- This is a JVM system property, not an LSP settings entry. JDT LS
            -- redirects .project/.classpath/.factorypath/.settings into its
            -- workspace only when those files are absent from the project root.
            local command = { jdtls, '-data', workspace,
                '--jvm-arg=-Djava.import.generatesMetadataFilesAtProjectRoot=false' }
            if has_lombok then
                -- --jvm-arg= places this before Java's -jar argument. Passing
                -- a bare -javaagent to the Python launcher would be incorrect.
                table.insert(command, '--jvm-arg=-javaagent:' .. lombok)
            end
            return vim.lsp.rpc.start(command,
                dispatchers, { cwd = config.root_dir })
        end,
        on_attach = function(client, bufnr)
            -- Highlight references to the symbol under the cursor after a
            -- short pause in Normal mode. LSP understands symbol identity,
            -- unlike a text search that also finds unrelated names.
            if client:supports_method('textDocument/documentHighlight') then
                -- One group per buffer prevents duplicate callbacks on attach.
                local group = vim.api.nvim_create_augroup(
                    'NvimIdeReferences' .. bufnr, { clear = true })
                vim.api.nvim_create_autocmd('CursorHold', {
                    group = group, buffer = bufnr,
                    callback = function()
                        vim.lsp.buf.document_highlight()
                    end,
                })
                -- Clear immediately when moving, typing, or leaving the buffer.
                vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI',
                    'InsertEnter', 'BufLeave' }, {
                    group = group, buffer = bufnr,
                    callback = function()
                        vim.lsp.buf.clear_references()
                    end,
                })
                vim.api.nvim_create_autocmd('LspDetach', {
                    group = group, buffer = bufnr,
                    callback = function(event)
                        if event.data.client_id == client.id then
                            vim.lsp.util.buf_clear_references(bufnr)
                            vim.api.nvim_del_augroup_by_id(group)
                        end
                    end,
                })
            end
            if client:supports_method('textDocument/foldingRange') then
                enable_java_folds(bufnr)
            end
            -- Enable native LSP completion. Invoke it deliberately with
            -- Ctrl-x Ctrl-o in Insert mode; Ctrl-n/p select, Ctrl-y accepts,
            -- Ctrl-e dismisses. Suggestions do not pop up automatically.
            if client:supports_method('textDocument/completion') then
                vim.lsp.completion.enable(true, client.id, bufnr,
                    { autotrigger = false })
            end
            -- gd goes to a definition, and
            -- Ctrl-o returns. It only applies to buffers attached to JDT LS.
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition,
                { buffer = bufnr, desc = 'Java: go to definition' })
            -- Select statements with V (whole lines) or v (characters), then
            -- Space em extracts a method. Calling directly from Visual mode
            -- lets native code_action capture the active selection's range.
            -- JDT LS calls method extraction 'refactor.extract.function'.
            -- Apply a single matching action directly; multiple choices use
            -- the native picker. Unavailable extractions report no actions.
            -- This changes the buffer without saving; u undoes the refactor.
            vim.keymap.set('x', '<leader>em', function()
                vim.lsp.buf.code_action({
                    context = { only = { 'refactor.extract.function' } },
                    apply = true,
                })
            end, { buffer = bufnr, desc = 'Java: extract selected code to method' })
        end,
    })
    vim.lsp.enable('jdtls')
end
-- Native LSP defaults once attached: K = documentation, grn = rename,
-- grr = references, gri = implementations, gra = code actions,
-- gO = document symbols. See :help lsp-defaults.
-- ]d / [d move between diagnostics; Ctrl-w d shows one in a floating window.
-- :checkhealth vim.lsp helps investigate problems. First import may take time.

-- :Format wraps the native :lua vim.lsp.buf.format() call; no plugin needed.
-- The server chooses formatting rules and receives shiftwidth/expandtab.
-- Format the whole buffer manually, inspect it, then :w to save or u to undo.
-- No formatting happens automatically on save.
vim.api.nvim_create_user_command('Format', function()
    -- Explain when the current buffer has no attached formatter.
    local clients = vim.lsp.get_clients({
        bufnr = 0, method = 'textDocument/formatting',
    })
    if #clients == 0 then
        vim.notify('No language server with formatting support is attached.',
            vim.log.levels.WARN)
        return
    end
    -- Wait up to three seconds so edits cannot race the formatting request.
    vim.lsp.buf.format({ bufnr = 0, async = false, timeout_ms = 3000 })
end, { desc = 'Format current buffer using its language server' })

-- Remember the selected test for this Neovim session, including its Maven
-- root and error parser. :TestLast can reuse it from implementation code.
-- This does not persist across restarts; reruns always use current saved files.
local last_test
-- Native jobs run Maven without blocking editing. Keep only one active run
-- so :TestStop and the quickfix results always refer to an unambiguous job.
local active_test
local test_output = {}
local function run_maven_test(target)
    if active_test then
        vim.notify('A test is running. Use :TestStop or wait for it to finish.',
            vim.log.levels.WARN)
        return
    end
    -- Do not silently save files or run tests against unsaved edits.
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buffer].modified then
            vim.notify('Save changed buffers with :wa before running tests.',
                vim.log.levels.WARN)
            return
        end
    end
    if vim.fn.filereadable(target.root .. '/pom.xml') ~= 1 then
        vim.notify('The last test project no longer has a pom.xml.', vim.log.levels.WARN)
        return
    end
    local executable = vim.fn.executable(target.root .. '/mvnw') == 1
        and (target.root .. '/mvnw') or 'mvn'
    local run = { output = {}, stopped = false }
    local function collect(_, lines)
        -- Buffered callbacks supply complete lines, ending with an empty item.
        for i, line in ipairs(lines) do
            if i < #lines or line ~= '' then
                table.insert(run.output, (line:gsub('\r$', '')
                    :gsub('\27%[[%d;]*m', ''))) -- Strip terminal color codes.
            end
        end
    end
    -- An argument list avoids shell quoting and injection. cwd applies only
    -- to the child process; window directories and :make options stay intact.
    local ok, job = pcall(vim.fn.jobstart, {
        executable, '--batch-mode', '-Dstyle.color=never', 'test',
        '-Dtest=' .. target.selector,
    }, {
        cwd = target.root,
        stdout_buffered = true, stderr_buffered = true,
        on_stdout = collect, on_stderr = collect,
        on_exit = function(_, code)
            -- Schedule UI work after buffered output callbacks have completed.
            vim.schedule(function()
                if active_test ~= run then return end
                active_test = nil
                test_output = run.output
                -- The synthetic directory line gives relative compiler paths
                -- a project root even if you have switched windows/projects.
                local lines = { '__NVIM_TEST_ROOT__ ' .. target.root }
                vim.list_extend(lines, run.output)
                local parsed = vim.fn.getqflist({ lines = lines,
                    efm = '%D__NVIM_TEST_ROOT__ %f,' .. target.errorformat })
                vim.fn.setqflist({}, ' ', { title = 'Test: ' .. target.selector,
                    items = parsed.items })
                local status = run.stopped and 'Stopped' or (code == 0
                    and 'Maven completed successfully' or ('Failed (exit ' .. code .. ')'))
                vim.notify(status .. ': ' .. target.selector .. '. Use :copen or :TestOutput.',
                    (run.stopped or code == 0) and vim.log.levels.INFO
                        or vim.log.levels.ERROR)
            end)
        end,
    })
    if not ok or job <= 0 then
        vim.notify('Could not start Maven: ' .. tostring(job), vim.log.levels.ERROR)
        return
    end
    run.job = job
    active_test = run
    last_test = target -- Remember failing runs too.
    vim.notify('Testing ' .. target.selector .. ' in the background.')
end

-- :TestNearest runs the method containing the cursor through Maven Surefire.
-- Put the cursor inside a top-level test method in src/test/java, save edits,
-- then run the command. We ask JDT LS for symbols instead of guessing with
-- regexes. Maven decides whether that method is actually a runnable test.
-- Maven runs in the background; symbol lookup can wait up to three seconds.
-- Nested classes and Failsafe integration tests are left for later.
vim.api.nvim_create_user_command('TestNearest', function()
    local function warn(message)
        vim.notify(message, vim.log.levels.WARN)
    end
    local bufnr = vim.api.nvim_get_current_buf()
    local root = vim.fs.root(bufnr, { 'pom.xml' })
    local file = vim.api.nvim_buf_get_name(bufnr)
    local prefix = root and (root .. '/src/test/java/')
    if vim.bo.filetype ~= 'java' or not prefix
        or file:sub(1, #prefix) ~= prefix then
        return warn('Open a Maven Java test under src/test/java first.')
    end
    -- Do not silently save files. Unsaved code would not be tested by Maven.
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buffer].modified then
            return warn('Save changed buffers with :wa before running tests.')
        end
    end
    local responses, err = vim.lsp.buf_request_sync(bufnr,
        'textDocument/documentSymbol',
        { textDocument = { uri = vim.uri_from_bufnr(bufnr) } }, 3000)
    if not responses then return warn('Could not read Java symbols: ' .. tostring(err)) end
    local line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- LSP lines start at zero.
    local method
    local kinds = vim.lsp.protocol.SymbolKind
    local function visit(symbols, class_depth)
        for _, symbol in ipairs(symbols) do
            local range = symbol.range
            if range and line >= range.start.line and line <= range['end'].line then
                local depth = class_depth + (symbol.kind == kinds.Class and 1 or 0)
                if symbol.kind == kinds.Method and depth == 1 then
                    -- JDT LS names may include parameters, e.g. checksValue().
                    method = symbol.name:match('^([%w_$]+)%s*%(')
                        or symbol.name:match('^([%w_$]+)$')
                end
                visit(symbol.children or {}, depth)
            end
        end
    end
    for _, response in pairs(responses) do
        if response.result then visit(response.result, 0) end
    end
    if not method then
        return warn('Place the cursor inside a top-level test method; JDT LS must be ready.')
    end
    -- Use a package-qualified name derived from the standard source layout.
    local class = file:sub(#prefix + 1):gsub('%.java$', ''):gsub('/', '.')
    run_maven_test({ root = root, selector = class .. '#' .. method,
        errorformat = vim.bo[bufnr].errorformat })
end, { desc = 'Run Maven test method containing the cursor' })

-- After :TestNearest, edit implementation code, :wa, then :TestLast.
-- It runs the remembered project even when you are viewing another project.
vim.api.nvim_create_user_command('TestLast', function()
    if not last_test then
        vim.notify('No previous test in this session. Run :TestNearest first.',
            vim.log.levels.WARN)
        return
    end
    run_maven_test(last_test)
end, { desc = 'Rerun the last selected Maven test' })

-- jobstop terminates the native job and its process group on Unix.
-- Wait for the completion notification before starting another run.
vim.api.nvim_create_user_command('TestStop', function()
    if not active_test then
        vim.notify('No test is running.')
        return
    end
    active_test.stopped = true
    vim.fn.jobstop(active_test.job)
end, { desc = 'Stop the active Maven test run' })

-- Quickfix focuses on errors. Keep the complete Maven summary in a read-only
-- scratch buffer too, since not every test failure has a navigable location.
vim.api.nvim_create_user_command('TestOutput', function()
    if #test_output == 0 then
        vim.notify('No completed test output yet.')
        return
    end
    vim.cmd('botright new')
    vim.bo.buftype = 'nofile'
    vim.bo.bufhidden = 'wipe'
    vim.bo.swapfile = false
    vim.api.nvim_buf_set_lines(0, 0, -1, false, test_output)
    vim.bo.modified = false
    vim.bo.modifiable = false
end, { desc = 'View full output of the last completed Maven test run' })

-- Avoid leaving Maven running after you exit the editor.
vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
        if active_test then vim.fn.jobstop(active_test.job) end
    end,
})

-- Project settings are plain JSON, stored locally outside your Git checkout.
-- :ProjectSettings creates/opens the current Maven project's file. A hash of
-- the full root path distinguishes projects with the same directory name.
-- JSON stores data rather than executable Lua; only :Run executes a command.
local function project_settings_location()
    local root = vim.fs.root(0, { 'pom.xml' })
        or vim.fs.root(vim.fn.getcwd(), { 'pom.xml' })
    if not root then
        vim.notify('Open a file in a Maven project first.', vim.log.levels.WARN)
        return
    end
    local path = vim.fn.stdpath('data') .. '/project-settings/'
        .. vim.fn.sha256(root) .. '.json'
    return root, path
end

vim.api.nvim_create_user_command('ProjectSettings', function()
    local root, path = project_settings_location()
    if not root then return end
    if vim.fn.filereadable(path) ~= 1 then
        vim.fn.mkdir(vim.fs.dirname(path), 'p')
        -- Leave the command empty instead of guessing how this project starts.
        -- Each command argument is a separate JSON string; see README examples.
        vim.fn.writefile({ '{', '  "run": {', '    "command": [],',
            '    "env": {}', '  }', '}' }, path)
    end
    vim.cmd('botright split ' .. vim.fn.fnameescape(path))
    -- Retain project context while viewing settings outside the checkout.
    vim.cmd.lcd(vim.fn.fnameescape(root))
    vim.notify('Set run.command, then :w and :Run. See README.md for examples.')
end, { desc = 'Edit local settings for the current Maven project' })

local running_app
vim.api.nvim_create_user_command('Run', function()
    local root, path = project_settings_location()
    if not root then return end
    if vim.fn.filereadable(path) ~= 1 then
        vim.notify('Configure this project with :ProjectSettings first.', vim.log.levels.WARN)
        return
    end
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buffer].modified then
            vim.notify('Save changed buffers with :wa before :Run.', vim.log.levels.WARN)
            return
        end
    end
    local ok, settings = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
    end)
    if not ok or type(settings) ~= 'table' then
        vim.notify('Invalid project JSON. Fix it with :ProjectSettings.', vim.log.levels.ERROR)
        return
    end
    local run = settings.run
    if type(run) ~= 'table' or type(run.command) ~= 'table'
        or not vim.islist(run.command) or #run.command == 0 then
        vim.notify('Set run.command to an argument list in :ProjectSettings.', vim.log.levels.WARN)
        return
    end
    for _, arg in ipairs(run.command) do
        if type(arg) ~= 'string' or arg == '' then
            vim.notify('Each run.command argument must be a nonempty string.', vim.log.levels.ERROR)
            return
        end
    end
    if run.env ~= nil then
        if type(run.env) ~= 'table' then
            vim.notify('run.env must be an object of string values.', vim.log.levels.ERROR)
            return
        end
        for key, value in pairs(run.env) do
            if type(key) ~= 'string' or key == '' or key:find('=', 1, true)
                or type(value) ~= 'string' then
                vim.notify('run.env must map environment names to strings.', vim.log.levels.ERROR)
                return
            end
        end
    end
    if running_app then
        vim.notify('An application is running. Use :RunStop first.', vim.log.levels.WARN)
        return
    end
    local command = vim.deepcopy(run.command)
    -- Native jobstart resolves executables before applying cwd. Resolve an
    -- explicit relative path (e.g. ./mvnw) against this project's root.
    if command[1]:find('/', 1, true) and command[1]:sub(1, 1) ~= '/' then
        command[1] = root .. '/' .. command[1]
    end
    -- The command runs directly, not through a shell: no expansion of ~, $VAR,
    -- pipes, or redirects. env adds/overrides variables only in the child.
    vim.cmd('botright 12new')
    local buffer = vim.api.nvim_get_current_buf()
    local started, job = pcall(vim.fn.jobstart, command, {
        cwd = root, env = run.env, term = true,
        on_exit = function(id, code)
            vim.schedule(function()
                if running_app == id then running_app = nil end
                vim.notify('Application exited (' .. code .. '). Output remains in the terminal.')
            end)
        end,
    })
    if not started or job <= 0 then
        vim.api.nvim_buf_delete(buffer, { force = true })
        vim.notify('Could not start application: ' .. tostring(job), vim.log.levels.ERROR)
        return
    end
    running_app = job
    -- Keep the terminal output after exit so you can inspect it.
    -- Ctrl-\ Ctrl-n leaves terminal input mode; :q closes its window.
    vim.cmd.startinsert()
end, { desc = 'Run the current project in a native terminal' })

vim.api.nvim_create_user_command('RunStop', function()
    if not running_app then
        vim.notify('No application is running.')
        return
    end
    vim.fn.jobstop(running_app)
end, { desc = 'Stop the running application' })

vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
        if running_app then vim.fn.jobstop(running_app) end
    end,
})

-- Debugging has no native DAP client, so reuse nvim-dap for the protocol only.
-- Our commands and Java launch integration remain here and can be tweaked.
-- The opt package loads only when a debugging command is used; no downloads
-- occur at startup. Install it and the Java adapter with install-debug.sh.
local function debug_client()
    pcall(vim.cmd, 'packadd nvim-dap')
    local ok, dap = pcall(require, 'dap')
    if not ok then
        vim.notify('Install debugging with bash ./install-debug.sh, then restart.',
            vim.log.levels.WARN)
        return
    end
    -- Each Java adapter session is served by the matching project's JDT LS.
    dap.adapters.java = function(callback, config)
        for _, client in ipairs(vim.lsp.get_clients({ name = 'jdtls' })) do
            if client.config.root_dir == config.cwd then
                client:request('workspace/executeCommand',
                    { command = 'vscode.java.startDebugSession', arguments = {} },
                    function(err, port)
                        if err or type(port) ~= 'number' then
                            vim.notify('Could not start Java debug adapter: '
                                .. (err and err.message or 'no port returned'), vim.log.levels.ERROR)
                            return
                        end
                        callback({ type = 'server', host = '127.0.0.1', port = port })
                    end, next(client.attached_buffers))
                return
            end
        end
        vim.notify('Open a Java file in the debugger project first.', vim.log.levels.WARN)
    end
    return dap
end

-- :Debug discovers entry points instead of guessing the main class. Project
-- JSON can optionally specify debug.main_class, args, vm_args, and env.
-- This launches the main class directly; it does not run your Maven Run command.
vim.api.nvim_create_user_command('Debug', function()
    local dap = debug_client()
    if not dap then return end
    if dap.session() then
        vim.notify('A debugger session is active. Use :DebugContinue or :DebugStop.')
        return
    end
    local root, settings_path = project_settings_location()
    if not root then return end
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buffer].modified then
            vim.notify('Save changed buffers with :wa before debugging.', vim.log.levels.WARN)
            return
        end
    end
    local client
    for _, candidate in ipairs(vim.lsp.get_clients({ name = 'jdtls' })) do
        if candidate.config.root_dir == root then client = candidate; break end
    end
    if not client then
        vim.notify('Open a Java file and wait for JDT LS to attach.', vim.log.levels.WARN)
        return
    end
    local commands = (client.server_capabilities.executeCommandProvider or {}).commands or {}
    if not vim.tbl_contains(commands, 'vscode.java.startDebugSession') then
        vim.notify('Java debug bundle is unavailable. Install debugging and restart Neovim.',
            vim.log.levels.WARN)
        return
    end
    local settings = {}
    if vim.fn.filereadable(settings_path) == 1 then
        local ok, parsed = pcall(vim.json.decode, table.concat(vim.fn.readfile(settings_path), '\n'))
        if not ok or type(parsed) ~= 'table' then
            vim.notify('Fix project JSON with :ProjectSettings.', vim.log.levels.ERROR)
            return
        end
        settings = parsed
    end
    local options = settings.debug or {}
    if type(options) ~= 'table' then
        vim.notify('debug settings must be a JSON object.', vim.log.levels.ERROR)
        return
    end
    -- WAR applications run inside a server such as Tomcat. Attach to a JVM
    -- started with JDWP instead of choosing an unrelated utility main class.
    -- Set debug.request="attach" and debug.port in :ProjectSettings.
    if options.request == 'attach' then
        if type(options.port) ~= 'number' or options.port % 1 ~= 0
            or options.port < 1 or options.port > 65535 then
            vim.notify('Set debug.port to the server JVM debug port (1-65535).',
                vim.log.levels.ERROR)
            return
        end
        local host = options.host or '127.0.0.1'
        if type(host) ~= 'string' or host == '' then
            vim.notify('debug.host must be a hostname string.', vim.log.levels.ERROR)
            return
        end
        dap.run({ name = 'Attach ' .. root, type = 'java', request = 'attach',
            cwd = root, hostName = host, port = options.port })
        return
    end
    if options.request and options.request ~= 'launch' then
        vim.notify('debug.request must be launch or attach.', vim.log.levels.ERROR)
        return
    end
    local buffer = next(client.attached_buffers)
    -- All discovery requests go to the captured client, even if you change
    -- buffers while they are pending. Errors abort the launch with a message.
    local function execute(command, arguments, callback)
        client:request('workspace/executeCommand',
            { command = command, arguments = arguments }, function(err, result)
                if err then
                    vim.notify(command .. ': ' .. err.message, vim.log.levels.ERROR)
                    return
                end
                callback(result)
            end, buffer)
    end
    execute('vscode.java.resolveMainClass', {}, function(entries)
        if type(entries) ~= 'table' or #entries == 0 then
            vim.notify('No runnable main classes found. Check project import and compile errors.')
            return
        end
        if options.main_class then
            entries = vim.tbl_filter(function(entry)
                return entry.mainClass == options.main_class
            end, entries)
            if #entries == 0 then
                vim.notify('Configured debug.main_class was not found.', vim.log.levels.ERROR)
                return
            end
        end
        local function launch(entry)
            if not entry then return end -- Native picker was dismissed.
            local arguments = { entry.mainClass, entry.projectName or '' }
            execute('vscode.java.resolveClasspath', arguments, function(paths)
                if type(paths) ~= 'table' or type(paths[2]) ~= 'table' then
                    vim.notify('Java server returned no classpath.', vim.log.levels.ERROR)
                    return
                end
                execute('vscode.java.resolveJavaExecutable', arguments, function(java)
                    if type(java) ~= 'string' or java == '' then
                        vim.notify('Java server could not resolve the project JDK.', vim.log.levels.ERROR)
                        return
                    end
                    dap.run({ name = entry.mainClass, type = 'java', request = 'launch',
                        mainClass = entry.mainClass, projectName = entry.projectName,
                        cwd = root, javaExec = java, classPaths = paths[2],
                        modulePaths = paths[1] or {}, console = 'integratedTerminal',
                        args = options.args or {}, vmArgs = options.vm_args or '',
                        env = options.env or (type(settings.run) == 'table' and settings.run.env or nil),
                        stopOnEntry = false })
                end)
            end)
        end
        if #entries == 1 then launch(entries[1]) else
            vim.ui.select(entries, { prompt = 'Debug main class:',
                format_item = function(entry)
                    return entry.mainClass .. ' (' .. (entry.projectName or '') .. ')'
                end }, launch)
        end
    end)
end, { desc = 'Discover and debug a Java main class' })

-- Commands instead of extra keybindings. Breakpoints appear in the sign column.
for name, method in pairs({ DebugBreakpoint = 'toggle_breakpoint',
    DebugContinue = 'continue', DebugNext = 'step_over', DebugInto = 'step_into',
    DebugOut = 'step_out' }) do
    vim.api.nvim_create_user_command(name, function()
        local dap = debug_client()
        if dap then
            if name ~= 'DebugBreakpoint' and not dap.session() then
                vim.notify('No debugger session. Start one with :Debug.')
                return
            end
            dap[method]()
        end
    end, { desc = 'Debugger: ' .. method:gsub('_', ' ') })
end

vim.api.nvim_create_user_command('DebugStop', function()
    local dap = debug_client()
    if not dap then return end
    local session = dap.session()
    if not session then vim.notify('No debugger session.'); return end
    -- Attaching does not give the editor ownership of your app server: detach
    -- without terminating it. For launched apps, terminate the debuggee.
    if session.config.request == 'attach' then
        dap.disconnect({ terminateDebuggee = false })
    else
        dap.terminate()
    end
end, { desc = 'Stop a launched debugger or detach from a server' })

vim.api.nvim_create_user_command('DebugInspect', function()
    if debug_client() then require('dap.ui.widgets').hover() end
end, { desc = 'Inspect variable under cursor while paused' })
vim.api.nvim_create_user_command('DebugScopes', function()
    if debug_client() then
        local widgets = require('dap.ui.widgets')
        widgets.sidebar(widgets.scopes).open()
    end
end, { desc = 'Show debugger variables and scopes' })

-- Small, local SVN integration. SVN owns versioning; Neovim supplies the
-- terminal, status review buffer, editable properties, and native diff windows.
-- Keep this block scoped so its helper variables do not affect Java commands.
do
    local function root()
        if vim.b.svn_root then return vim.b.svn_root end
        local file = vim.api.nvim_buf_get_name(0)
        local start = file ~= '' and vim.fs.dirname(file) or vim.fn.getcwd()
        -- Prefer the Maven project over an external's nested working copy.
        return vim.fs.root(start, 'pom.xml') or vim.fs.root(start, '.svn') or vim.fn.getcwd()
    end

    local function svn(args, cwd)
        local command = { 'svn', '--non-interactive' }
        vim.list_extend(command, args)
        local result = vim.system(command, { cwd = cwd, text = true }):wait(10000)
        if result.code ~= 0 then
            error(vim.trim(result.stderr or '') ~= '' and vim.trim(result.stderr)
                or 'SVN failed or timed out', 0)
        end
        return result.stdout or ''
    end

    -- Catch local command failures and show the SVN explanation in :messages.
    local function guarded(action)
        return function(options)
            local ok, err = pcall(action, options)
            if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
        end
    end

    vim.api.nvim_create_user_command('Svn', guarded(function(options)
        local cwd = root()
        local command = { 'svn' }
        vim.list_extend(command, #options.fargs > 0 and options.fargs or { 'status' })
        vim.cmd('botright 12new')
        vim.b.svn_root = cwd
        -- A real terminal permits interactive authentication. Arguments are
        -- passed directly, without a shell. Ctrl-\ Ctrl-n leaves terminal mode.
        local job = vim.fn.jobstart(command, { cwd = cwd, term = true })
        if job <= 0 then error('Could not start svn') end
        vim.cmd.startinsert()
    end), { nargs = '*', desc = 'Run SVN in a terminal at the project root' })

    vim.api.nvim_create_user_command('SvnExternals', guarded(function(options)
        local cwd = root()
        local target = options.args ~= '' and options.args or cwd
        if target:sub(1, 1) ~= '/' then target = cwd .. '/' .. target end
        target = vim.fs.normalize(target)
        -- A trailing @ prevents SVN interpreting an @ in a filename as a peg revision.
        if vim.trim(svn({ 'info', '--show-item', 'kind', target .. '@' }, cwd)) ~= 'dir' then
            error('svn:externals must belong to a versioned directory')
        end
        local function read_property()
            -- proplist distinguishes an absent property from authentication or
            -- working-copy errors without depending on localized error messages.
            local props = svn({ 'proplist', '--xml', target .. '@' }, cwd)
            if not props:find('name="svn:externals"', 1, true) then return nil end
            return svn({ 'propget', '--strict', 'svn:externals', target .. '@' }, cwd)
        end
        local name = 'svn-externals://' .. target
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(buf) == name then
                vim.cmd.split()
                vim.api.nvim_win_set_buf(0, buf)
                return
            end
        end
        local original = read_property()
        vim.cmd.new()
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_name(buf, name)
        vim.bo[buf].buftype = 'acwrite' -- :w invokes our property writer, not file I/O.
        vim.bo[buf].bufhidden = 'hide' -- Unsaved edits survive closing the window.
        vim.bo[buf].swapfile = false
        vim.bo[buf].filetype = 'conf'
        vim.b[buf].svn_root = cwd
        local lines = vim.split(original or '', '\n', { plain = true })
        if #lines > 1 and lines[#lines] == '' then table.remove(lines) end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modified = false
        vim.api.nvim_create_autocmd('BufWriteCmd', {
            buffer = buf,
            callback = guarded(function()
                if read_property() ~= original then
                    error('Externals changed outside this buffer. Reopen it before saving.')
                end
                local temporary = vim.fn.tempname()
                local ok, err = pcall(function()
                    if vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), temporary) ~= 0 then
                        error('Could not write temporary property file')
                    end
                    svn({ 'propset', 'svn:externals', '--file', temporary, target .. '@' }, cwd)
                end)
                vim.fn.delete(temporary)
                if not ok then error(err, 0) end
                original = read_property()
                vim.bo[buf].modified = false
                vim.notify('Saved local svn:externals on ' .. target .. '. Use :Svn update to fetch externals.')
            end),
        })
        vim.notify('Edit externals, then :w to save the local property. SVN commit is separate.')
    end), { nargs = '?', complete = 'dir', desc = 'Edit a directory\'s svn:externals property' })

    vim.api.nvim_create_user_command('SvnDiff', guarded(function(options)
        local cwd = root()
        local target = options.args ~= '' and options.args or vim.api.nvim_buf_get_name(0)
        if target == '' then error('Open a versioned file or supply its path') end
        if target:sub(1, 1) ~= '/' then target = cwd .. '/' .. target end
        target = vim.fs.normalize(target)
        local contents = svn({ 'cat', '-r', 'BASE', target .. '@' }, cwd)
        vim.cmd('edit ' .. vim.fn.fnameescape(target))
        vim.cmd.diffthis()
        vim.cmd.vnew()
        local buf = vim.api.nvim_get_current_buf()
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].swapfile = false
        vim.b[buf].svn_root = cwd
        local lines = vim.split(contents, '\n', { plain = true })
        if lines[#lines] == '' then table.remove(lines) end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = vim.filetype.match({ filename = target }) or ''
        vim.bo[buf].modifiable = false -- Protect the comparison from accidental edits.
        vim.bo[buf].modified = false
        vim.api.nvim_buf_set_name(buf, 'svn-base://' .. target .. '/' .. buf)
        vim.cmd.diffthis()
    end), { nargs = '?', complete = 'file', desc = 'Compare a file with SVN BASE using native diff' })

    -- Ordinary file buffers get small signs without entering diff mode. BASE
    -- is fetched locally and asynchronously; typing only recomputes the diff
    -- against that cached text. Neither operation writes to the working copy.
    local signs = vim.api.nvim_create_namespace('nvim_svn_signs')
    local states = {}
    for name, link in pairs({ SvnAdded = 'DiffAdd', SvnChanged = 'DiffChange', SvnDeleted = 'DiffDelete' }) do
        vim.api.nvim_set_hl(0, name, { default = true, link = link })
    end

    local function render(buf)
        local state = states[buf]
        if not state or not state.base or not vim.api.nvim_buf_is_loaded(buf) then return end
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        -- Compare logical lines: CRLF and final-newline conventions should not
        -- make every line look changed. Binary and very large files are skipped.
        if #lines > 20000 then
            vim.api.nvim_buf_clear_namespace(buf, signs, 0, -1)
            vim.b[buf].svn_hunks = {}
            return
        end
        local hunks = vim.diff(state.base, table.concat(lines, '\n') .. '\n', {
            result_type = 'indices', algorithm = 'histogram', ignore_cr_at_eol = true,
        })
        vim.api.nvim_buf_clear_namespace(buf, signs, 0, -1)
        vim.b[buf].svn_hunks = hunks
        for _, hunk in ipairs(hunks) do
            local old_count, start, count = hunk[2], hunk[3], hunk[4]
            local text, highlight = '+', 'SvnAdded'
            if count == 0 then text, highlight = '_', 'SvnDeleted'
            elseif old_count > 0 then text, highlight = '~', 'SvnChanged' end
            -- Deletions sit on the preceding surviving line (line 1 if the
            -- deletion is at the beginning). An underscore means lines removed.
            for line = math.max(1, start), math.max(1, start) + math.max(1, count) - 1 do
                if line <= #lines then
                    vim.api.nvim_buf_set_extmark(buf, signs, line - 1, 0, {
                        sign_text = count > old_count and line >= start + old_count and '+' or text,
                        sign_hl_group = count > old_count and line >= start + old_count
                            and 'SvnAdded' or highlight, priority = 5,
                    })
                end
            end
        end
    end

    local function refresh(buf)
        if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= '' then return end
        local path = vim.api.nvim_buf_get_name(buf)
        if path == '' or not vim.fs.root(vim.fs.dirname(path), '.svn') then return end
        local state = states[buf] or {}
        states[buf] = state
        state.generation = (state.generation or 0) + 1
        local generation = state.generation
        -- Abort a previous lookup rather than building up background processes.
        if state.job then state.job:kill(15) end
        state.job = vim.system({ 'svn', '--non-interactive', 'cat', '-r', 'BASE', path .. '@' },
            { text = true, timeout = 10000 }, function(result)
                vim.schedule(function()
                    if states[buf] ~= state or state.generation ~= generation
                        or not vim.api.nvim_buf_is_loaded(buf)
                        or vim.api.nvim_buf_get_name(buf) ~= path then return end
                    state.job = nil
                    state.base = nil
                    vim.api.nvim_buf_clear_namespace(buf, signs, 0, -1)
                    vim.b[buf].svn_hunks = {}
                    -- Unversioned/new files have no BASE; omit their signs.
                    if result.code ~= 0 or #(result.stdout or '') > 2 * 1024 * 1024
                        or (result.stdout or ''):find('\0', 1, true) then return end
                    local base = result.stdout or ''
                    if base:sub(-1) ~= '\n' then base = base .. '\n' end
                    state.base = base
                    render(buf)
                end)
            end)
    end

    local group = vim.api.nvim_create_augroup('NativeSvn', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'BufEnter', 'FocusGained' }, {
        group = group,
        callback = function(event) refresh(event.buf) end,
    })
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
        group = group,
        callback = function(event)
            local state = states[event.buf]
            if not state then return end
            state.edit = (state.edit or 0) + 1
            local edit = state.edit
            -- Debounce typing for 200 ms, independently of symbol highlighting.
            vim.defer_fn(function()
                if states[event.buf] == state and state.edit == edit then render(event.buf) end
            end, 200)
        end,
    })
    vim.api.nvim_create_autocmd('BufWipeout', {
        group = group,
        callback = function(event)
            local state = states[event.buf]
            if state and state.job then state.job:kill(15) end
            states[event.buf] = nil
        end,
    })
    vim.api.nvim_create_user_command('SvnRefresh', function()
        refresh(vim.api.nvim_get_current_buf())
    end, { desc = 'Reload local SVN BASE and refresh changed-line signs' })

    for command, direction in pairs({ SvnNextChange = 1, SvnPrevChange = -1 }) do
        vim.api.nvim_create_user_command(command, function()
            render(vim.api.nvim_get_current_buf())
            local hunks = vim.b.svn_hunks or {}
            local line = vim.api.nvim_win_get_cursor(0)[1]
            local destination
            for _, hunk in ipairs(hunks) do
                local position = math.max(1, hunk[3])
                if direction == 1 and position > line then destination = position; break end
                if direction == -1 and position < line then destination = position end
            end
            if destination then vim.api.nvim_win_set_cursor(0, { destination, 0 })
            else vim.notify('No more SVN changes in this direction.') end
        end, { desc = 'Jump to an SVN change without entering diff mode' })
    end

    -- Resolve the hunk afresh for explicit actions. An SVN update performed
    -- outside the editor must not cause a revert against stale cached BASE.
    local function current_hunk()
        local buf = vim.api.nvim_get_current_buf()
        local path = vim.api.nvim_buf_get_name(buf)
        if vim.bo[buf].buftype ~= '' or path == '' then
            error('Open a versioned text file first')
        end
        local contents = svn({ 'cat', '-r', 'BASE', path .. '@' }, vim.fs.dirname(path))
        if #contents > 2 * 1024 * 1024 or contents:find('\0', 1, true)
            or vim.api.nvim_buf_line_count(buf) > 20000 then
            error('Hunk actions are unavailable for binary or very large files')
        end
        local base = vim.split(contents, '\n', { plain = true })
        if base[#base] == '' then table.remove(base) end
        -- Neovim buffers hold logical lines without CRLF terminators.
        for index, line in ipairs(base) do base[index] = line:gsub('\r$', '') end
        local state = states[buf] or {}
        states[buf] = state
        state.generation = (state.generation or 0) + 1
        if state.job then state.job:kill(15); state.job = nil end
        state.base = table.concat(base, '\n') .. '\n'
        render(buf)
        local cursor = vim.api.nvim_win_get_cursor(0)[1]
        for _, hunk in ipairs(vim.b[buf].svn_hunks or {}) do
            local first = math.max(1, hunk[3])
            if cursor >= first and cursor <= first + math.max(1, hunk[4]) - 1 then
                return buf, hunk, base
            end
        end
        error('No SVN change under the cursor. Use :SvnNextChange or :SvnPrevChange.')
    end

    vim.api.nvim_create_user_command('SvnPreviewHunk', guarded(function()
        local buf, hunk, base = current_hunk()
        local lines = { string.format('@@ -%d,%d +%d,%d @@', unpack(hunk)) }
        for index = hunk[1], hunk[1] + hunk[2] - 1 do
            lines[#lines + 1] = '-' .. base[index]
        end
        if hunk[4] > 0 then
            for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, hunk[3] - 1,
                hunk[3] - 1 + hunk[4], false)) do
                lines[#lines + 1] = '+' .. line
            end
        end
        -- A native float: first invocation previews; repeat the command to
        -- enter the same preview and scroll. q closes it once focused.
        local preview = vim.lsp.util.open_floating_preview(lines, 'diff', {
            border = 'rounded', focus_id = 'svn_hunk_preview',
            max_width = math.max(20, math.floor(vim.o.columns * 0.8)),
            max_height = math.max(3, math.floor(vim.o.lines * 0.5)),
        })
        vim.bo[preview].modifiable = false
        vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = preview, desc = 'Close hunk preview' })
    end), { desc = 'Preview the SVN change under the cursor in a native float' })

    vim.api.nvim_create_user_command('SvnRevertHunk', guarded(function()
        if not vim.bo.modifiable or vim.bo.readonly then error('This buffer is read-only') end
        -- The local sentinel means this buffer inherits the global undo limit.
        local undo_levels = vim.bo.undolevels
        if undo_levels == -123456 then undo_levels = vim.go.undolevels end
        if undo_levels < 0 then error('Enable undo before reverting a hunk') end
        local buf, hunk, base = current_hunk()
        local replacement = {}
        for index = hunk[1], hunk[1] + hunk[2] - 1 do
            replacement[#replacement + 1] = base[index]
        end
        -- For a pure deletion, xdiff's new-start is the surviving line before
        -- the gap: insert AFTER it. Other hunks use a one-based start line.
        local first = hunk[4] == 0 and hunk[3] or hunk[3] - 1
        -- Close the preceding undo block without changing the option's value.
        -- The restoration is one separate undoable edit, even after Lua edits.
        vim.cmd('let &l:undolevels = &l:undolevels')
        vim.api.nvim_buf_set_lines(buf, first, first + hunk[4], false, replacement)
        vim.cmd('let &l:undolevels = &l:undolevels')
        render(buf)
        vim.notify('Restored this hunk from SVN BASE. u undoes it; :w saves when ready.')
    end), { desc = 'Restore the current SVN hunk in the buffer; undoable and not saved' })

    -- Network history queries run asynchronously in read-only scratch buffers.
    -- This lets you keep editing while the server responds. Errors are shown
    -- in that same buffer; authentication can be established with :Svn first.
    local function output_buffer(title, args, cwd, filetype)
        vim.cmd('botright new')
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_name(buf, title .. '/' .. buf)
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].swapfile = false
        vim.bo[buf].filetype = filetype
        vim.b[buf].svn_root = cwd
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Loading SVN output...' })
        vim.bo[buf].modifiable = false
        local command = { 'svn', '--non-interactive' }
        vim.list_extend(command, args)
        local job = vim.system(command, { cwd = cwd, text = true, timeout = 30000 }, function(result)
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(buf) then return end
                local output = result.code == 0 and result.stdout or
                    ('SVN failed: ' .. (result.stderr or '') .. '\nUse :Svn to authenticate if needed.')
                if output == '' then output = 'No changes for this target.' end
                vim.bo[buf].modifiable = true
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, '\n', { plain = true }))
                vim.bo[buf].modified = false
                vim.bo[buf].modifiable = false
            end)
        end)
        vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, once = true,
            callback = function() job:kill(15) end })
        vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, desc = 'Close SVN output' })
        return buf
    end

    -- SVN's XML avoids ambiguous filenames and localized status headings.
    -- This small reader handles SVN's entry attributes, not arbitrary XML.
    local function xml_value(value)
        local entities = { amp = '&', lt = '<', gt = '>', quot = '"', apos = "'" }
        return (value:gsub('&(#?[%w]+);', function(entity)
            if entities[entity] then return entities[entity] end
            local number = entity:match('^#x(%x+)$')
            number = number and tonumber(number, 16) or tonumber(entity:match('^#(%d+)$'))
            return number and vim.fn.nr2char(number) or '&' .. entity .. ';'
        end))
    end
    local function attributes(text)
        local values = {}
        for name, value in text:gmatch('([%w_-]+)%s*=%s*"(.-)"') do
            values[name] = xml_value(value)
        end
        return values
    end
    local function display_path(path)
        return (path:gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t'))
    end

    -- Commit only explicitly selected paths, at depth empty. This is essential
    -- for directory properties: selecting the project must not commit children.
    local drafts, active_commit = {}, nil
    local status_refresh = {}
    -- SVN changelists are local file groupings, not svn:ignore patterns. Files
    -- remain tracked. Protect these named lists in our selective commit UI.
    vim.g.svn_ignored_changelists = vim.g.svn_ignored_changelists or { 'Ignore' }
    local function protected_changelist(name)
        return name and vim.tbl_contains(vim.g.svn_ignored_changelists, name)
    end
    local function changelists(xml, cwd)
        local result = {}
        for header, body in xml:gmatch('<changelist%s+(.-)>(.-)</changelist>') do
            local name = attributes(header).name
            for entry in body:gmatch('<entry%s+(.-)>') do
                local path = attributes(entry).path
                if path then
                    if path:sub(1, 1) ~= '/' then path = cwd .. '/' .. path end
                    result[vim.fs.normalize(path)] = name
                end
            end
        end
        return result
    end
    local status_targets = {}
    local function action_path(options)
        local path = options and options.args ~= '' and options.args or nil
        if not path then
            local selected = status_targets[vim.api.nvim_get_current_buf()]
            path = selected and selected() or vim.api.nvim_buf_get_name(0)
        end
        if not path or path == '' or path:find('://', 1, true) then error('Select or open a tracked file first') end
        if path:sub(1, 1) ~= '/' then path = root() .. '/' .. path end
        return vim.fs.normalize(path)
    end
    local function set_changelist(path, name)
        local cwd = vim.fs.dirname(path)
        if vim.trim(svn({ 'info', '--show-item', 'kind', path .. '@' }, cwd)) ~= 'file' then
            error('SVN changelists apply to files, not directories')
        end
        local args = name and { 'changelist', '--', name, path .. '@' }
            or { 'changelist', '--remove', '--', path .. '@' }
        svn(args, cwd)
        for _, refresh in pairs(status_refresh) do refresh() end
        vim.notify(name and ('Assigned ' .. name .. ': ' .. path) or ('Removed changelist: ' .. path))
    end
    vim.api.nvim_create_user_command('SvnChangelist', guarded(function(options)
        if #options.fargs > 2 then error('Usage: :SvnChangelist NAME [FILE]') end
        local name = options.fargs[1]
        local path = action_path({ args = options.fargs[2] or '' })
        set_changelist(path, name)
    end), { nargs = '+', desc = 'Assign a changelist: NAME [FILE]; defaults to selected/current file' })
    vim.api.nvim_create_user_command('SvnChangelistRemove', guarded(function(options)
        set_changelist(action_path(options), nil)
    end), { nargs = '?', complete = 'file', desc = 'Remove selected/current file from its changelist' })

    local function text_conflict(path)
        local cwd = vim.fs.dirname(path)
        local xml = svn({ 'info', '--xml', path .. '@' }, cwd)
        if xml:find('<tree-conflict', 1, true) then
            error('Tree conflicts need SVN\'s interactive resolver: :Svn resolve PATH')
        end
        local files
        for header, body in xml:gmatch('<conflict%s+(.-)>(.-)</conflict>') do
            local kind = attributes(header).type
            if kind ~= 'text' then error('Property/tree conflicts need :Svn resolve PATH') end
            local function artifact(tag)
                local pattern_tag = tag:gsub('%-', '%%-')
                local value = body:match('<' .. pattern_tag .. '>(.-)</' .. pattern_tag .. '>')
                if not value then error('SVN did not report all text-conflict artifacts') end
                value = xml_value(value)
                if value:sub(1, 1) ~= '/' then value = cwd .. '/' .. value end
                return vim.fs.normalize(value)
            end
            files = { mine = artifact('prev-wc-file'), incoming = artifact('cur-base-file'),
                base = artifact('prev-base-file') }
        end
        if not files then error('No supported text conflict on this file') end
        local function read(pathname)
            local stat = vim.uv.fs_stat(pathname)
            if not stat or stat.type ~= 'file' then error('Missing conflict artifact: ' .. pathname) end
            if stat.size > 2 * 1024 * 1024 then error('Conflict diff supports text files up to 2 MiB') end
            local lines = vim.fn.readfile(pathname)
            for _, line in ipairs(lines) do
                if line:find('\n', 1, true) then error('Use SVN directly for binary conflicts') end
            end
            for index, line in ipairs(lines) do lines[index] = line:gsub('\r$', '') end
            return lines
        end
        files.mine_lines, files.incoming_lines, files.base_lines = read(files.mine), read(files.incoming), read(files.base)
        return files
    end

    vim.api.nvim_create_user_command('SvnConflict', guarded(function(options)
        local path = action_path(options)
        local files = text_conflict(path)
        -- A separate tab keeps these diff windows away from existing reviews.
        -- The result is the real file buffer; the sources are read-only copies.
        vim.cmd('tab split ' .. vim.fn.fnameescape(path))
        local result_window = vim.api.nvim_get_current_win()
        vim.b.svn_root = root()
        vim.cmd.diffthis()
        vim.wo.winbar = 'RESULT — edit here, :w, then :SvnResolve'
        local function source(label, lines)
            vim.cmd.vnew()
            local buf = vim.api.nvim_get_current_buf()
            vim.bo[buf].buftype = 'nofile'
            vim.bo[buf].bufhidden = 'wipe'
            vim.bo[buf].swapfile = false
            vim.b[buf].svn_root = vim.fs.dirname(path)
            vim.b[buf].svn_conflict_target = path
            vim.api.nvim_buf_set_name(buf, 'svn-conflict-' .. label:lower() .. '://' .. path .. '/' .. buf)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].filetype = vim.filetype.match({ filename = path }) or ''
            vim.bo[buf].modified = false
            vim.bo[buf].modifiable = false
            vim.wo.winbar = label .. ' — take hunk in RESULT with :diffget ' .. buf
            vim.cmd.diffthis()
            return buf
        end
        local mine = source('LOCAL', files.mine_lines)
        local incoming = source('INCOMING', files.incoming_lines)
        vim.api.nvim_set_current_win(result_window)
        vim.cmd('wincmd =')
        vim.notify('Edit RESULT. ]c/[c navigate; :diffget ' .. mine .. ' takes LOCAL; :diffget '
            .. incoming .. ' takes INCOMING. Save, then :SvnResolve. :tabclose closes this view.')
    end), { nargs = '?', complete = 'file', desc = 'Open LOCAL, INCOMING, and editable RESULT in native diff windows' })

    vim.api.nvim_create_user_command('SvnResolve', guarded(function(options)
        local path = options.args == '' and vim.b.svn_conflict_target or nil
        path = path or action_path(options)
        local cwd = vim.fs.dirname(path)
        local function snapshot()
            local artifacts = text_conflict(path)
            local buffers = {}
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_get_name(buf) == path and vim.api.nvim_buf_is_loaded(buf) then
                    if vim.bo[buf].modified then error('Save the merged result with :w before resolving') end
                    buffers[buf] = vim.api.nvim_buf_get_changedtick(buf)
                end
            end
            local lines = vim.fn.readfile(path)
            for _, line in ipairs(lines) do
                if line:match('^<<<<<<<') or line:match('^=======') or line:match('^>>>>>>>')
                    or line:match('^|||||||') then error('Conflict markers remain in the result; edit and save it first') end
            end
            return { artifacts = artifacts, buffers = buffers, lines = lines }
        end
        local original = snapshot()
        vim.ui.select({ 'Cancel', 'Mark resolved' }, { prompt = 'Accept the saved merge result: ' .. display_path(path) .. '?' },
            guarded(function(choice)
                if choice ~= 'Mark resolved' then return end
                if not vim.deep_equal(snapshot(), original) then
                    error('Conflict or result changed during confirmation; review and run :SvnResolve again')
                end
                -- Accept the edited working file; do not choose an entire side,
                -- recurse into other conflicts, or commit anything implicitly.
                svn({ 'resolve', '--accept', 'working', '--depth', 'empty', path .. '@' }, cwd)
                for _, refresh in pairs(status_refresh) do refresh() end
                vim.notify('Marked resolved: ' .. path .. '. Review and commit separately.')
            end))
    end), { nargs = '?', complete = 'file', desc = 'Confirm a saved text merge and mark this file resolved' })

    vim.api.nvim_create_user_command('SvnAdd', guarded(function(options)
        local path = action_path(options)
        -- Add one saved file, never recursively schedule an untracked directory.
        -- --parents schedules any missing parent directories as well.
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(buf) == path and vim.bo[buf].modified then
                error('Save the file with :w before adding it to SVN')
            end
        end
        local stat = vim.uv.fs_lstat(path)
        if not stat then error('Save the file with :w before adding it to SVN') end
        if stat.type ~= 'file' and stat.type ~= 'link' then
            error('SvnAdd accepts individual files; use :Svn add for directories')
        end
        svn({ 'add', '--parents', path .. '@' }, vim.fs.dirname(path))
        for _, refresh in pairs(status_refresh) do refresh() end
        vim.notify('Scheduled SVN addition: ' .. path .. '. Select it in :SvnStatus to commit when ready.')
    end), { nargs = '?', complete = 'file', desc = 'Schedule current/selected saved file for SVN addition' })

    vim.api.nvim_create_user_command('SvnDelete', guarded(function(options)
        local path = action_path(options)
        local cwd = vim.fs.dirname(path)
        local xml = svn({ 'status', '--xml', '--depth', 'empty', path .. '@' }, cwd)
        local item = attributes(xml:match('<wc%-status%s+(.-)>') or '').item
        if item == 'unversioned' or item == 'ignored' then
            error('This file is unversioned. Use :Ex and D to delete it; there is no SVN deletion to commit.')
        end
        if vim.trim(svn({ 'info', '--show-item', 'kind', path .. '@' }, cwd)) ~= 'file' then
            error('SvnDelete accepts tracked files only')
        end
        local function saved_buffers()
            local buffers = {}
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_get_name(buf) == path then
                    if vim.bo[buf].modified then error('Save or discard unsaved edits before deleting: ' .. path) end
                    buffers[#buffers + 1] = buf
                end
            end
            return buffers
        end
        saved_buffers()
        vim.ui.select({ 'Cancel', 'Delete file' }, { prompt = 'Delete and schedule SVN removal: ' .. display_path(path) .. '?' },
            guarded(function(choice)
                if choice ~= 'Delete file' then return end
                local buffers = saved_buffers()
                -- Never force deletion: SVN refuses locally modified files.
                svn({ 'delete', path .. '@' }, cwd)
                for _, buf in ipairs(buffers) do
                    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = false }) end
                end
                for _, refresh in pairs(status_refresh) do refresh() end
                vim.notify('Scheduled SVN deletion: ' .. path .. '. Commit it from :SvnStatus when ready.')
            end))
    end), { nargs = '?', complete = 'file', desc = 'Delete current/selected tracked file and schedule SVN removal' })

    local function commit_snapshot(path)
        local cwd = vim.fs.dirname(path)
        local xml = svn({ 'status', '--xml', '--depth', 'empty', path .. '@' }, cwd)
        local status = attributes(xml:match('<wc%-status%s+(.-)>') or '')
        local changelist = changelists(xml, cwd)[path]
        if protected_changelist(changelist) then
            error('Protected changelist ' .. changelist .. ': remove it before selecting for commit: ' .. path)
        end
        local eligible = { modified = true, normal = true, added = true, deleted = true, replaced = true }
        if not eligible[status.item] or status.props == 'conflicted' or status['tree-conflicted'] == 'true'
            or (status.item == 'normal' and status.props ~= 'modified') then
            error('Path is clean, conflicted, or not committable: ' .. path)
        end
        if status['file-external'] == 'true' then error('Commit file externals separately with :Svn: ' .. path) end
        local kind = vim.trim(svn({ 'info', '--show-item', 'kind', path .. '@' }, cwd))
        if kind == 'dir' and (status.item == 'deleted' or status.item == 'replaced'
            or status.copied == 'true') then
            error('Use :Svn for directory deletions, replacements, or copies: ' .. path)
        end
        local working_copy = vim.trim(svn({ 'info', '--show-item', 'wc-root', path .. '@' }, cwd))
        local patch = svn({ 'diff', '--depth', 'empty', path }, cwd)
        -- Also compare raw bytes: binary SVN patches need not contain content.
        local stat = vim.uv.fs_lstat(path)
        local content
        if stat and stat.type == 'link' then content = vim.uv.fs_readlink(path)
        elseif stat and stat.type == 'file' then
            if stat.size > 16 * 1024 * 1024 then error('Commit editor supports files up to 16 MiB: ' .. path) end
            local fd, err = vim.uv.fs_open(path, 'r', 0)
            if not fd then error(err) end
            content, err = vim.uv.fs_read(fd, stat.size, 0)
            vim.uv.fs_close(fd)
            if not content then error(err) end
        end
        return { changelist = changelist, item = status.item, props = status.props, copied = status.copied,
            revision = status.revision, kind = kind, working_copy = working_copy,
            patch = patch, content = content }
    end

    local function review_buffer(title, lines, cwd)
        vim.cmd('botright new')
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_name(buf, title .. '/' .. buf)
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].swapfile = false
        vim.b[buf].svn_root = cwd
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modified = false
        vim.bo[buf].modifiable = false
        vim.bo[buf].filetype = 'diff'
        vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, desc = 'Close commit review/result' })
    end

    vim.api.nvim_create_user_command('SvnRevertFile', guarded(function(options)
        local path = action_path(options)
        local cwd = vim.fs.dirname(path)
        if vim.trim(svn({ 'info', '--show-item', 'kind', path .. '@' }, cwd)) ~= 'file' then
            error('Whole-file revert accepts files only; directory changes need explicit :Svn commands')
        end
        local base = svn({ 'cat', '-r', 'BASE', path .. '@' }, cwd)
        if #base > 16 * 1024 * 1024 then error('Use :Svn for files larger than 16 MiB') end
        -- No BASE (newly added files) is intentionally handled by SVN directly.
        local function snapshot()
            local xml = svn({ 'status', '--xml', '--depth', 'empty', path .. '@' }, cwd)
            local status = attributes(xml:match('<wc%-status%s+(.-)>') or '')
            local stat = vim.uv.fs_lstat(path)
            local content
            if stat and stat.type == 'link' then content = vim.uv.fs_readlink(path)
            elseif stat and stat.type == 'file' then
                if stat.size > 16 * 1024 * 1024 then error('Use :Svn for files larger than 16 MiB') end
                local fd, err = vim.uv.fs_open(path, 'r', 0)
                if not fd then error(err) end
                content, err = vim.uv.fs_read(fd, stat.size, 0)
                vim.uv.fs_close(fd)
                if not content then error(err) end
            end
            local buffers = {}
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_get_name(buf) == path and vim.api.nvim_buf_is_loaded(buf) then
                    buffers[buf] = { tick = vim.api.nvim_buf_get_changedtick(buf), modified = vim.bo[buf].modified }
                end
            end
            return { status = status, content = content, buffers = buffers,
                patch = svn({ 'diff', '--depth', 'empty', path }, cwd),
                base = svn({ 'cat', '-r', 'BASE', path .. '@' }, cwd),
                changelist = changelists(xml, cwd)[path] }
        end
        local original = snapshot()
        local lines = { 'Revert file: ' .. display_path(path),
            'This discards saved text/property changes and unsaved edits in this file.',
            'SVN revert is a working-copy operation; Vim undo is not a recovery guarantee.', '',
            'Saved working-copy diff:' }
        vim.list_extend(lines, vim.split(original.patch ~= '' and original.patch or '(No saved changes)', '\n', { plain = true }))
        for buf, state in pairs(original.buffers) do
            if state.modified then
                lines[#lines + 1] = 'Unsaved buffer compared with BASE (will also be discarded):'
                local current = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n') .. '\n'
                if not base:find('\0', 1, true) and not current:find('\0', 1, true) then
                    vim.list_extend(lines, vim.split(vim.diff(base, current, { result_type = 'unified',
                        ignore_cr_at_eol = true }), '\n', { plain = true }))
                else lines[#lines + 1] = '(Binary buffer; textual preview unavailable)' end
            end
        end
        review_buffer('svn-revert-preview://' .. path, lines, root())
        vim.ui.select({ 'Cancel', 'Revert file' }, { prompt = 'Discard all local changes in ' .. display_path(path) .. '?' },
            guarded(function(choice)
                if choice ~= 'Revert file' then return end
                if not vim.deep_equal(snapshot(), original) then
                    error('File, properties, or buffer changed after preview. Open a fresh revert preview.')
                end
                svn({ 'revert', '--depth', 'empty', path .. '@' }, cwd)
                for buf in pairs(original.buffers) do
                    if vim.api.nvim_buf_is_loaded(buf) then
                        vim.api.nvim_buf_call(buf, function() vim.cmd('edit!') end)
                    end
                end
                for _, refresh in pairs(status_refresh) do refresh() end
                vim.notify('Reverted file and reloaded its buffer: ' .. path)
            end))
    end), { nargs = '?', complete = 'file', desc = 'Preview and confirm full-file SVN revert including properties' })

    local function open_commit(paths, cwd)
        if #paths == 0 then error('Select paths with Space in :SvnStatus first') end
        table.sort(paths)
        local snapshots, working_copy = {}, nil
        for _, path in ipairs(paths) do
            local snapshot = commit_snapshot(path)
            if working_copy and snapshot.working_copy ~= working_copy then
                error('Select paths from one working copy at a time; externals need separate commits')
            end
            working_copy = snapshot.working_copy
            snapshots[path] = snapshot
        end
        -- A normal file preserves the message with native :w and lets :q refuse
        -- unsaved text. Messages remain on disk after success for later reference.
        local directory = vim.fn.stdpath('state') .. '/svn-commits'
        vim.fn.mkdir(directory, 'p', 448)
        vim.cmd.new()
        local buf = vim.api.nvim_get_current_buf()
        local filename = directory .. '/' .. os.date('%Y%m%d-%H%M%S') .. '-'
            .. vim.uv.os_getpid() .. '-' .. vim.fn.fnamemodify(vim.fn.tempname(), ':t') .. '.txt'
        vim.api.nvim_buf_set_name(buf, filename)
        vim.bo[buf].bufhidden = 'hide'
        vim.bo[buf].filetype = 'svn'
        vim.bo[buf].swapfile = false
        vim.b[buf].svn_root = cwd
        drafts[buf] = { paths = paths, snapshots = snapshots, cwd = cwd }
        vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, once = true,
            callback = function() drafts[buf] = nil end })
        vim.notify('Write your message. :w saves the draft; :SvnCommitReview reviews; :SvnCommitSubmit sends '
            .. #paths .. ' selected path(s).')
    end

    vim.api.nvim_create_user_command('SvnCommitReview', guarded(function()
        local draft = drafts[vim.api.nvim_get_current_buf()]
        if not draft then error('Open a commit draft with c in :SvnStatus first') end
        local lines = { 'Selected SVN commit paths (depth empty):',
            'Close with q to return to the message. :SvnCommitSubmit sends it.', '' }
        for _, path in ipairs(draft.paths) do
            lines[#lines + 1] = 'Target: ' .. display_path(path)
            vim.list_extend(lines, vim.split(draft.snapshots[path].patch, '\n', { plain = true }))
        end
        review_buffer('svn-commit-review://', lines, draft.cwd)
    end), { desc = 'Review the exact paths and saved patches in the commit draft' })

    vim.api.nvim_create_user_command('SvnCommitSubmit', guarded(function()
        local buf = vim.api.nvim_get_current_buf()
        local draft = drafts[buf]
        if not draft then error('Run :SvnCommitSubmit from the commit-message buffer') end
        if draft.completed then error('This draft was already committed; create a new selection') end
        if active_commit then error('An SVN commit is already running') end
        local message = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
        if vim.trim(message) == '' then error('Write a nonempty commit message first') end
        -- Unsaved selected files or property editors must be resolved first.
        for _, other in ipairs(vim.api.nvim_list_bufs()) do
            if other ~= buf and vim.bo[other].modified then
                local name = vim.api.nvim_buf_get_name(other)
                for _, path in ipairs(draft.paths) do
                    if name == path or name == 'svn-externals://' .. path then
                        error('Save or discard the selected path\'s unsaved buffer: ' .. path)
                    end
                end
            end
        end
        for _, path in ipairs(draft.paths) do
            if not vim.deep_equal(commit_snapshot(path), draft.snapshots[path]) then
                error('Selected changes changed after drafting. Refresh status and create a new draft: ' .. path)
            end
        end
        -- Saving a message never commits. This explicitly named command does.
        -- No shell, recursive targets, or include-externals: only the selection.
        local temporary = vim.fn.tempname()
        if vim.fn.writefile(vim.split(message, '\n', { plain = true }), temporary) ~= 0 then
            error('Could not prepare commit message')
        end
        vim.fn.setfperm(temporary, 'rw-------')
        local command = { 'svn', '--non-interactive', 'commit', '--depth', 'empty',
            '--encoding', 'UTF-8', '--file', temporary }
        -- An empty peg suffix escapes @ in working-copy paths.
        for _, path in ipairs(draft.paths) do command[#command + 1] = path .. '@' end
        active_commit = draft
        local ok, err = pcall(function()
            -- Do not time out or kill a commit on closing its draft: a server
            -- might already have accepted it. Keep the result until completion.
            draft.job = vim.system(command, { cwd = draft.cwd, text = true }, function(result)
                vim.schedule(function()
                    vim.fn.delete(temporary)
                    active_commit = nil
                    local output = (result.stdout or '') .. (result.stderr or '')
                    if result.code == 0 then
                        draft.completed = true
                        vim.notify('SVN commit succeeded.')
                        for _, refresh in pairs(status_refresh) do refresh() end
                    else
                        vim.notify('SVN commit failed; your draft is preserved. See the result buffer.', vim.log.levels.ERROR)
                    end
                    review_buffer('svn-commit-result://', vim.split(output ~= '' and output
                        or ('SVN exited with code ' .. tostring(result.code)), '\n', { plain = true }), draft.cwd)
                end)
            end)
        end)
        if not ok then active_commit = nil; vim.fn.delete(temporary); error(err) end
        vim.notify('Submitting selected SVN paths...')
    end), { desc = 'Send selected saved changes with this buffer\'s commit message' })

    vim.api.nvim_create_user_command('SvnStatus', guarded(function()
        local cwd = root()
        local name = 'svn-status://' .. cwd
        for _, existing in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(existing) == name then
                local window = vim.fn.bufwinid(existing)
                if window ~= -1 then vim.api.nvim_set_current_win(window)
                else vim.cmd('botright split'); vim.api.nvim_win_set_buf(0, existing) end
                -- Reuse the window and its mappings instead of accumulating tabs.
                status_refresh[existing]()
                return
            end
        end
        vim.cmd('botright 15new')
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_name(buf, name)
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].swapfile = false
        vim.bo[buf].modifiable = false
        vim.b[buf].svn_root = cwd
        local rows, generation, job = {}, 0, nil
        local chosen = {}
        local summary_row, summary_prefix
        -- Large projects can contain dozens of unchanged external checkouts.
        -- Keep only changed externals visible unless x requests the full list.
        local show_clean_externals = false
        local fold_ranges, fold_preferences = {}, {}
        local namespace = vim.api.nvim_create_namespace('svn_status_view')
        local function set_lines(lines)
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].modified = false
            vim.bo[buf].modifiable = false
        end
        local function selected()
            local window = vim.fn.bufwinid(buf)
            return window ~= -1 and rows[vim.api.nvim_win_get_cursor(window)[1]] or nil
        end
        local function refresh_status()
            local selection = selected()
            local selected_path = selection and selection.path
            local window = vim.fn.bufwinid(buf)
            if window ~= -1 then
                vim.api.nvim_win_call(window, function()
                    for _, fold in ipairs(fold_ranges) do
                        fold_preferences[fold.key] = vim.fn.foldclosed(fold.first) ~= -1
                    end
                end)
            end
            generation = generation + 1
            local request = generation
            if job then job:kill(15) end
            rows = {}
            set_lines({ 'SVN status: ' .. display_path(cwd), 'Loading working-copy status...' })
            job = vim.system({ 'svn', '--non-interactive', 'status', '--xml', cwd .. '@' },
                { cwd = cwd, text = true, timeout = 10000 }, function(result)
                    vim.schedule(function()
                        if not vim.api.nvim_buf_is_valid(buf) or request ~= generation then return end
                        job = nil
                        if result.code ~= 0 then
                            set_lines({ 'SVN status failed', result.stderr or 'Command timed out',
                                'Press r to retry; q to close.' })
                            return
                        end
                        local entries, external_paths = {}, {}
                        local lists = changelists(result.stdout or '', cwd)
                        for entry_attributes, body in (result.stdout or ''):gmatch('<entry%s+(.-)>(.-)</entry>') do
                            local entry = attributes(entry_attributes)
                            local status = attributes(body:match('<wc%-status%s+(.-)>') or '')
                            if entry.path and status.item then
                                local path = entry.path
                                if path:sub(1, 1) ~= '/' then path = cwd .. '/' .. path end
                                path = vim.fs.normalize(path)
                                local record = { path = path, changelist = lists[path], item = status.item, props = status.props,
                                    tree_conflict = status['tree-conflicted'] == 'true' }
                                entries[#entries + 1] = record
                                if status.item == 'external' then external_paths[#external_paths + 1] = path end
                            end
                        end
                        table.sort(external_paths)
                        table.sort(entries, function(a, b) return a.path < b.path end)
                        local groups = { [cwd] = {} }
                        for _, path in ipairs(external_paths) do groups[path] = {} end
                        for _, entry in ipairs(entries) do
                            if entry.item ~= 'external' and (entry.item ~= 'normal'
                                or entry.props == 'modified' or entry.props == 'conflicted' or entry.tree_conflict) then
                                -- The longest external prefix owns nested external changes.
                                local owner = cwd
                                for _, external in ipairs(external_paths) do
                                    if (entry.path == external or entry.path:sub(1, #external + 1) == external .. '/')
                                        and #external > #owner then owner = external end
                                end
                                entry.owner = owner
                                groups[owner][#groups[owner] + 1] = entry
                            end
                        end
                        local available = {}
                        for _, group_entries in pairs(groups) do
                            for _, entry in ipairs(group_entries) do available[entry.path] = not protected_changelist(entry.changelist) end
                        end
                        for path in pairs(chosen) do if not available[path] then chosen[path] = nil end end
                        local lines, highlights = {}, {}
                        rows = {}
                        local function add(text, entry, highlight)
                            lines[#lines + 1] = text
                            rows[#lines] = entry or {}
                            if highlight then highlights[#highlights + 1] = { #lines - 1, highlight } end
                        end
                        add('SVN status: ' .. display_path(cwd), nil, 'Title')
                        add('Enter open   d diff   Space select   c commit   ? help', nil, 'Comment')
                        local total, protected_count, selected_count, selection_owner = 0, 0, 0, nil
                        for _, entries in pairs(groups) do
                            for _, entry in ipairs(entries) do
                                total = total + 1
                                if protected_changelist(entry.changelist) then protected_count = protected_count + 1 end
                            end
                        end
                        for _, owner in pairs(chosen) do
                            selected_count = selected_count + 1
                            selection_owner = owner
                        end
                        local selection_scope = selection_owner and (selection_owner == cwd and 'Project'
                            or 'External: ' .. display_path(selection_owner:sub(#cwd + 2))) or nil
                        summary_row = #lines -- Zero-based row for in-place count updates.
                        summary_prefix = string.format('Changes: %d paths | Protected: %d | Selected: ', total, protected_count)
                        add(string.format('Changes: %d paths | Protected: %d | Selected: %d%s',
                            total, protected_count, selected_count,
                            selection_scope and (' (' .. selection_scope .. ')') or ''), nil, 'Comment')
                        local order, clean_count = { cwd }, 0
                        for _, external in ipairs(external_paths) do
                            if #groups[external] == 0 then clean_count = clean_count + 1 end
                            if show_clean_externals or #groups[external] > 0 then
                                order[#order + 1] = external
                            end
                        end
                        if clean_count > 0 then
                            add(show_clean_externals and (clean_count .. ' clean externals shown (x hides clean)')
                                or (clean_count .. ' clean externals hidden (x shows all)'), nil, 'Comment')
                        end
                        fold_ranges = {}
                        local function status_label(entry)
                            local labels = {}
                            if entry.item ~= 'normal' and entry.item ~= 'none' then
                                labels[#labels + 1] = entry.item == 'unversioned' and 'untracked' or entry.item
                            end
                            if entry.props == 'modified' then labels[#labels + 1] = 'property changed'
                            elseif entry.props == 'conflicted' then labels[#labels + 1] = 'property conflict' end
                            if entry.tree_conflict then labels[#labels + 1] = 'tree conflict' end
                            return table.concat(labels, ', ')
                        end
                        local label_width = 8
                        for _, entries in pairs(groups) do
                            for _, entry in ipairs(entries) do label_width = math.max(label_width, #status_label(entry)) end
                        end
                        local function add_entry(entry, owner)
                            local relative = entry.path == owner and '.' or entry.path:sub(#owner + 2)
                            local highlight = (entry.item == 'conflicted' or entry.tree_conflict
                                or entry.props == 'conflicted') and 'DiagnosticError'
                                or entry.item == 'added' and 'SvnAdded'
                                or protected_changelist(entry.changelist) and 'Comment'
                                or entry.item == 'deleted' and 'SvnDeleted' or 'SvnChanged'
                            local unavailable = protected_changelist(entry.changelist) or entry.tree_conflict
                                or entry.item == 'conflicted' or entry.item == 'unversioned' or entry.item == 'ignored'
                                or entry.item == 'missing' or entry.item == 'obstructed' or entry.item == 'incomplete'
                                or entry.props == 'conflicted'
                            local marker = chosen[entry.path] and '[x]' or unavailable and '[-]' or '[ ]'
                            add(string.format('%s %-' .. label_width .. 's | %s', marker,
                                status_label(entry), display_path(relative)), entry, highlight)
                        end
                        for _, owner in ipairs(order) do
                            add('')
                            add(owner == cwd and 'Project' or 'External: ' .. display_path(owner:sub(#cwd + 2)),
                                nil, 'Title')
                            if #groups[owner] == 0 then add('  Clean', nil, 'Comment') end
                            local lists, names = {}, {}
                            for _, entry in ipairs(groups[owner]) do
                                local name = entry.changelist or ''
                                if not lists[name] then lists[name] = {}; names[#names + 1] = name end
                                lists[name][#lists[name] + 1] = entry
                            end
                            -- Ordinary changes first, named lists next, protected lists last.
                            table.sort(names, function(a, b)
                                if a == '' then return b ~= '' end
                                if b == '' then return false end
                                local pa, pb = protected_changelist(a), protected_changelist(b)
                                if (not not pa) ~= (not not pb) then return not pa end
                                return a < b
                            end)
                            for _, name in ipairs(names) do
                                local protected = protected_changelist(name)
                                local count = #lists[name]
                                local heading = name == '' and 'Changes' or ('Changelist: [' .. display_path(name) .. ']')
                                heading = '  ' .. heading .. ' (' .. count .. (count == 1 and ' file' or ' files')
                                    .. (protected and ', protected)' or ')')
                                local first = #lines + 1
                                add(heading, nil, protected and 'Comment' or 'Title')
                                for _, entry in ipairs(lists[name]) do add_entry(entry, owner) end
                                fold_ranges[#fold_ranges + 1] = { first = first, last = #lines,
                                    key = owner .. '\0' .. name, protected = protected }
                            end
                        end
                        set_lines(lines)
                        vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
                        for _, highlight in ipairs(highlights) do
                            vim.api.nvim_buf_set_extmark(buf, namespace, highlight[1], 0,
                                { end_col = #lines[highlight[1] + 1], hl_group = highlight[2], right_gravity = false })
                        end
                        -- Keep the selected file across refreshes, or start on
                        -- the first change so Enter/d are immediately useful.
                        local destination
                        for index, entry in ipairs(rows) do
                            if entry.path and not destination then destination = index end
                            if selected_path and entry.path == selected_path then destination = index; break end
                        end
                        for _, window in ipairs(vim.fn.win_findbuf(buf)) do
                            vim.api.nvim_win_call(window, function()
                                -- Manual folds use native za/zo/zc; they are local
                                -- to this status window and never change SVN data.
                                vim.wo.foldmethod = 'manual'
                                vim.wo.foldenable = true
                                vim.wo.foldminlines = 0
                                vim.wo.foldtext = 'getline(v:foldstart)'
                                vim.cmd('normal! zE')
                                for _, fold in ipairs(fold_ranges) do
                                    local closed = fold_preferences[fold.key]
                                    if closed == nil then closed = not not fold.protected end
                                    vim.cmd(fold.first .. ',' .. fold.last .. 'fold')
                                    if not closed then
                                        vim.api.nvim_win_set_cursor(window, { fold.first, 0 })
                                        vim.cmd('normal! zo')
                                    end
                                end
                                -- Keep closed groups closed when restoring a cursor.
                                local target = destination or 1
                                local closed = vim.fn.foldclosed(target)
                                vim.api.nvim_win_set_cursor(window, { closed ~= -1 and closed or target, 0 })
                            end)
                        end
                    end)
                end)
        end
        local function update_selection(path)
            -- Selecting changes only our local draft selection. Keep the panel,
            -- cursor, folds, and scroll position intact; r rereads SVN status.
            local count, owner = 0, nil
            for _, scope in pairs(chosen) do count = count + 1; owner = scope end
            local scope = owner and (owner == cwd and 'Project'
                or 'External: ' .. display_path(owner:sub(#cwd + 2)))
            vim.bo[buf].modifiable = true
            local ok, err = pcall(function()
                for index, entry in ipairs(rows) do
                    if entry.path == path then
                        vim.api.nvim_buf_set_text(buf, index - 1, 0, index - 1, 3,
                            { chosen[path] and '[x]' or '[ ]' })
                        break
                    end
                end
                local text = summary_prefix .. count .. (scope and (' (' .. scope .. ')') or '')
                local old = vim.api.nvim_buf_get_lines(buf, summary_row, summary_row + 1, false)[1]
                vim.api.nvim_buf_clear_namespace(buf, namespace, summary_row, summary_row + 1)
                vim.api.nvim_buf_set_text(buf, summary_row, 0, summary_row, #old, { text })
                vim.api.nvim_buf_set_extmark(buf, namespace, summary_row, 0,
                    { end_col = #text, hl_group = 'Comment', right_gravity = false })
            end)
            vim.bo[buf].modified = false
            vim.bo[buf].modifiable = false
            if not ok then error(err) end
        end
        status_refresh[buf] = refresh_status
        local help_window
        vim.keymap.set('n', '?', function()
            if help_window and vim.api.nvim_win_is_valid(help_window) then
                vim.api.nvim_set_current_win(help_window)
                return
            end
            local lines = {
                'SVN status help', '',
                'Review',
                '  Enter     Open selected file/directory',
                '  d         Show diff (including properties)',
                '  r         Refresh; preserve selection and folds',
                '  x         Show/hide clean externals',
                '  za/zo/zc  Toggle/open/close a changelist group',
                '  q         Close status', '',
                'Changelists and commits',
                '  i         Toggle Ignore membership',
                '  l         Assign a changelist; empty removes it',
                '  Space     Select/unselect a commit path',
                '  [x] selected   [ ] available   [-] unavailable/protected',
                '  c         Open message for selected paths',
                '  :w        Save message draft (does not commit)',
                '  :SvnCommitReview  Review draft targets and patches',
                '  :SvnCommitSubmit  Send commit from message buffer',
                '  Ignore files cannot be selected; externals commit separately.', '',
                'Restore, delete, and resolve',
                '  R         Preview and confirm whole-file revert',
                '  a / :SvnAdd  Schedule selected/current saved file for addition',
                '  :SvnDelete  Confirm deletion of selected/current tracked file',
                '  v         Open text conflict diff view',
                '  S         Confirm resolution of a saved merge result',
                '  Property/tree conflicts: :Svn resolve PATH', '',
                'While editing a file',
                '  :SvnDiff / :SvnBlame / :SvnRefresh',
                '  :SvnNextChange / :SvnPrevChange',
                '  :SvnPreviewHunk / :SvnRevertHunk (undoable buffer edit)',
                '  :SvnExternals DIRECTORY / :SvnLog', '',
                'This window: j/k or Ctrl-d/Ctrl-u scroll; q or Escape closes.',
            }
            local help = vim.api.nvim_create_buf(false, true)
            vim.bo[help].bufhidden = 'wipe'
            vim.bo[help].swapfile = false
            vim.api.nvim_buf_set_lines(help, 0, -1, false, lines)
            vim.bo[help].modifiable = false
            local width = math.max(1, math.min(80, vim.o.columns - 4))
            local height = math.max(1, math.min(#lines, vim.o.lines - 6))
            help_window = vim.api.nvim_open_win(help, true, {
                relative = 'editor', style = 'minimal', border = 'rounded',
                width = width, height = height,
                row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
                col = math.max(0, math.floor((vim.o.columns - width) / 2)),
            })
            local window = help_window
            local function close()
                if vim.api.nvim_win_is_valid(window) then vim.api.nvim_win_close(window, true) end
                local status_window = vim.fn.bufwinid(buf)
                if status_window ~= -1 then vim.api.nvim_set_current_win(status_window) end
            end
            vim.keymap.set('n', 'q', close, { buffer = help, desc = 'Close SVN help' })
            vim.keymap.set('n', '<Esc>', close, { buffer = help, desc = 'Close SVN help' })
        end, { buffer = buf, desc = 'Show SVN keys and commands in a native help window' })
        status_targets[buf] = function()
            local entry = selected()
            return entry and entry.path
        end
        vim.keymap.set('n', 'i', guarded(function()
            local entry = selected()
            if not entry or not entry.path then error('Select a tracked file first') end
            if entry.changelist == 'Ignore' then set_changelist(entry.path, nil)
            else set_changelist(entry.path, 'Ignore') end
        end), { buffer = buf, desc = 'Toggle selected file in the Ignore changelist' })
        vim.keymap.set('n', 'l', guarded(function()
            local entry = selected()
            if not entry or not entry.path then error('Select a tracked file first') end
            vim.ui.input({ prompt = 'Changelist (empty removes): ', default = entry.changelist or '' },
                guarded(function(name)
                    if name == nil then return end
                    set_changelist(entry.path, name ~= '' and name or nil)
                end))
        end), { buffer = buf, desc = 'Assign or remove a named SVN changelist' })
        vim.keymap.set('n', 'R', '<Cmd>SvnRevertFile<CR>', { buffer = buf, desc = 'Preview and confirm file revert' })
        vim.keymap.set('n', 'a', '<Cmd>SvnAdd<CR>', { buffer = buf, desc = 'Schedule selected file for SVN addition' })
        vim.keymap.set('n', 'v', '<Cmd>SvnConflict<CR>', { buffer = buf, desc = 'Open conflict diff view' })
        vim.keymap.set('n', 'S', '<Cmd>SvnResolve<CR>', { buffer = buf, desc = 'Confirm saved conflict resolution' })
        vim.keymap.set('n', '<Space>', guarded(function()
            local entry = selected()
            if not entry or not entry.path then error('Select a changed path first') end
            if chosen[entry.path] then chosen[entry.path] = nil
            else
                commit_snapshot(entry.path) -- Reject unversioned/conflicted paths early.
                for _, owner in pairs(chosen) do
                    if owner ~= entry.owner then
                        error('Select one project/external section at a time')
                    end
                end
                chosen[entry.path] = entry.owner
            end
            update_selection(entry.path)
        end), { buffer = buf, desc = 'Toggle this path in the commit selection' })
        vim.keymap.set('n', 'c', guarded(function()
            local available, paths = {}, {}
            for _, entry in ipairs(rows) do if entry.path then available[entry.path] = true end end
            for path in pairs(chosen) do
                if not available[path] then error('Selection is stale; refresh and reselect paths') end
                paths[#paths + 1] = path
            end
            open_commit(paths, cwd)
        end), { buffer = buf, desc = 'Write a commit message for selected paths' })
        vim.keymap.set('n', 'r', refresh_status, { buffer = buf, desc = 'Refresh SVN status' })
        vim.keymap.set('n', 'x', function()
            show_clean_externals = not show_clean_externals
            refresh_status()
        end, { buffer = buf, desc = 'Show/hide clean external working copies' })
        vim.keymap.set('n', '<CR>', guarded(function()
            local entry = selected()
            if not entry or not entry.path then vim.notify('Select a changed file or directory.'); return end
            -- Leave the review list open. Native directory browsing handles directories.
            vim.cmd('aboveleft split ' .. vim.fn.fnameescape(entry.path))
        end), { buffer = buf, desc = 'Open selected SVN path' })
        vim.keymap.set('n', 'd', guarded(function()
            local entry = selected()
            if not entry or not entry.path then vim.notify('Select a changed file or directory.'); return end
            if entry.item == 'unversioned' or entry.item == 'ignored' then
                vim.notify('This path has no SVN diff. Press Enter to inspect it.'); return
            end
            -- Saved property changes and deleted/added paths need SVN's patch
            -- output; ordinary modified files can use the existing native diff.
            if entry.item == 'modified' and entry.props ~= 'modified' and entry.props ~= 'conflicted'
                and not entry.tree_conflict then
                vim.cmd('aboveleft split ' .. vim.fn.fnameescape(entry.path))
                vim.cmd.SvnDiff()
            else
                -- Local svn diff takes a literal path (unlike revision diffs).
                local args = { 'diff' }
                if entry.item == 'normal' then
                    -- A property-only directory row should show that directory,
                    -- rather than recursively dumping every descendant's edits.
                    vim.list_extend(args, { '--depth', 'empty' })
                end
                args[#args + 1] = entry.path
                output_buffer('svn-diff://' .. entry.path, args, cwd, 'diff')
            end
        end), { buffer = buf, desc = 'Inspect selected SVN changes including properties' })
        vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, desc = 'Close SVN status' })
        vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, once = true,
            callback = function()
                status_refresh[buf] = nil
                status_targets[buf] = nil
                if job then job:kill(15) end
            end })
        refresh_status()
    end), { desc = 'Review SVN changes, diffs, and external working copies' })

    local function revision_diff(revision, target, cwd)
        output_buffer('svn-revision://r' .. revision,
            { 'diff', '-c', revision, target .. '@' }, cwd, 'diff')
    end

    local blame_requests = {}
    vim.api.nvim_create_user_command('SvnBlame', guarded(function()
        local source = vim.api.nvim_get_current_buf()
        local path = vim.api.nvim_buf_get_name(source)
        if vim.bo[source].buftype ~= '' or path == '' then error('Open a tracked text file first') end
        local cwd = vim.fs.dirname(path)
        local cursor = vim.api.nvim_win_get_cursor(0)[1]
        local tick = vim.api.nvim_buf_get_changedtick(source)
        local base_revision = vim.trim(svn({ 'info', '--show-item', 'revision', path .. '@' }, cwd))
        local base = svn({ 'cat', '-r', 'BASE', path .. '@' }, cwd)
        local current = table.concat(vim.api.nvim_buf_get_lines(source, 0, -1, false), '\n') .. '\n'
        if #base > 2 * 1024 * 1024 or #current > 2 * 1024 * 1024
            or base:find('\0', 1, true) or current:find('\0', 1, true) then
            error('Line blame supports text files up to 2 MiB')
        end
        if base:sub(-1) ~= '\n' then base = base .. '\n' end
        local base_line = cursor
        for _, hunk in ipairs(vim.diff(base, current, { result_type = 'indices', ignore_cr_at_eol = true })) do
            if hunk[4] > 0 and cursor >= hunk[3] and cursor < hunk[3] + hunk[4] then
                error('This line is locally added or changed; it has no matching committed line. Use :SvnDiff.')
            end
            if cursor > hunk[3] + hunk[4] - (hunk[4] > 0 and 1 or 0) then
                base_line = base_line + hunk[2] - hunk[4]
            end
        end
        -- Attribute BASE, not HEAD or working text; local insertions/deletions
        -- above this unchanged line are mapped to its original line number.
        local request = {}
        local previous = blame_requests[source]
        if previous and previous.job then previous.job:kill(15) end
        blame_requests[source] = request
        request.job = vim.system({ 'svn', '--non-interactive', 'blame', '--xml', '-r', 'BASE', path .. '@' },
            { cwd = cwd, text = true, timeout = 30000 }, function(result)
                vim.schedule(guarded(function()
                    if blame_requests[source] ~= request then return end
                    blame_requests[source] = nil
                    if not vim.api.nvim_buf_is_valid(source) then return end
                    if vim.api.nvim_buf_get_changedtick(source) ~= tick
                        or vim.api.nvim_buf_get_name(source) ~= path then
                        error('Buffer changed while loading blame; run :SvnBlame again')
                    end
                    if result.code ~= 0 then error(vim.trim(result.stderr or '') ~= ''
                        and vim.trim(result.stderr) or 'SVN blame failed or timed out') end
                    if vim.trim(svn({ 'info', '--show-item', 'revision', path .. '@' }, cwd)) ~= base_revision then
                        error('SVN BASE changed while loading blame; run :SvnBlame again')
                    end
                    local revision, author, date
                    for header, body in (result.stdout or ''):gmatch('<entry%s+(.-)>(.-)</entry>') do
                        if tonumber(attributes(header)['line-number']) == base_line then
                            revision = attributes(body:match('<commit%s+(.-)>') or '').revision
                            author = xml_value(body:match('<author>(.-)</author>') or '(unknown author)')
                            date = xml_value(body:match('<date>(.-)</date>') or '(unknown date)')
                            break
                        end
                    end
                    if not revision then error('No committed attribution found for this line') end
                    local lines = { 'r' .. revision .. ' — ' .. author, date,
                        display_path(path) .. ':' .. cursor .. ' (BASE line ' .. base_line .. ')',
                        '', 'Enter: commit message   d: revision diff   q: close' }
                    -- Center a native float in the editor so even a one-line
                    -- source split has room for the attribution and its actions.
                    local buf = vim.api.nvim_create_buf(false, true)
                    vim.bo[buf].bufhidden = 'wipe'
                    vim.bo[buf].swapfile = false
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                    vim.bo[buf].modifiable = false
                    local width = math.max(1, math.min(80, vim.o.columns - 4))
                    local height = math.max(1, math.min(#lines, vim.o.lines - 4))
                    local window = vim.api.nvim_open_win(buf, true, {
                        relative = 'editor', border = 'rounded', style = 'minimal',
                        width = width, height = height,
                        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
                        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
                    })
                    vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf })
                    local function close_float()
                        if vim.api.nvim_win_is_valid(window) then vim.api.nvim_win_close(window, true) end
                    end
                    vim.keymap.set('n', '<CR>', function()
                        close_float()
                        output_buffer('svn-blame-log://r' .. revision,
                            { 'log', '-r', revision, '-v', path .. '@' }, cwd, 'svn')
                    end, { buffer = buf, desc = 'Show the blamed commit message and paths' })
                    vim.keymap.set('n', 'd', function()
                        close_float()
                        revision_diff(revision, path, cwd)
                    end, { buffer = buf, desc = 'Inspect the blamed revision for this file' })
                end))
            end)
        vim.notify('Loading SVN blame for line ' .. cursor .. '...')
    end), { desc = 'Attribute the current unchanged line; Enter shows message, d shows patch' })

    vim.api.nvim_create_user_command('SvnLog', guarded(function(options)
        local cwd = root()
        local target = options.args ~= '' and options.args or cwd
        if target:sub(1, 1) ~= '/' then target = cwd .. '/' .. target end
        target = vim.fs.normalize(target)
        local buf = output_buffer('svn-log://' .. target,
            { 'log', '-r', 'HEAD:1', '--limit', '50', '-v', target .. '@' }, cwd, 'svn')
        vim.keymap.set('n', '<CR>', function()
            -- Find the closest preceding revision header, so Enter works on
            -- its message and changed-path lines as well as the header itself.
            local lines = vim.api.nvim_buf_get_lines(buf, 0, vim.api.nvim_win_get_cursor(0)[1], false)
            for index = #lines, 1, -1 do
                local revision = lines[index]:match('^r(%d+) |')
                if revision then revision_diff(revision, target, cwd); return end
            end
            vim.notify('Place the cursor on a revision entry.')
        end, { buffer = buf, desc = 'Show this revision\'s patch for the history target' })
    end), { nargs = '?', complete = 'file', desc = 'Browse the last 50 SVN commits; Enter shows a patch' })

    vim.api.nvim_create_user_command('SvnRevision', guarded(function(options)
        if not options.args:match('^%d+$') then error('Usage: :SvnRevision NUMBER') end
        local cwd = root()
        revision_diff(options.args, cwd, cwd)
    end), { nargs = 1, desc = 'Show a revision\'s changes in the current project' })
end

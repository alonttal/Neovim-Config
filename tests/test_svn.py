"""Exercise the editor commands against a real, offline SVN working copy."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

CONFIG = Path(__file__).resolve().parents[1] / 'init.lua'


class SvnIntegration(unittest.TestCase):
    def test_editor_workflows(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo = base / 'repo'
            wc = base / 'working copy@fixture'
            def svn(*args):
                return subprocess.check_output(['svn', *map(str, args)], text=True)
            subprocess.run(['svnadmin', 'create', str(repo)], check=True)
            svn('checkout', repo.as_uri(), wc)
            (wc / 'src').mkdir()
            (wc / 'lib').mkdir()
            (wc / 'lib' / 'shared.txt').write_text('shared base\n')
            (wc / 'src' / 'deleted.txt').write_text('delete me\n')
            (wc / 'src' / 'conflicted.txt').write_text('base\n')
            (wc / 'pom.xml').write_text('<project/>\n')
            (wc / 'src' / 'markers.txt').write_text('one\ntwo\nthree\nfour\nfive\n')
            (wc / 'src' / 'file with spaces.txt').write_text('original\n')
            svn('add', str(wc) + '/src@', str(wc) + '/pom.xml@', str(wc) + '/lib@')
            svn('commit', '-m', 'fixture', str(wc) + '@')
            svn('propset', 'svn:externals', '^/lib external', str(wc) + '@')
            svn('update', str(wc) + '@')
            peer = base / 'peer'
            svn('checkout', repo.as_uri(), peer)
            (peer / 'src' / 'conflicted.txt').write_text('remote edit\n')
            svn('commit', '-m', 'remote edit', peer / 'src' / 'conflicted.txt')
            (wc / 'src' / 'conflicted.txt').write_text('local edit\n')
            svn('update', str(wc / 'src' / 'conflicted.txt') + '@')
            (wc / 'src' / 'file with spaces.txt').write_text('changed\n')
            script = base / 'check.lua'
            script.write_text(r'''
local wc = vim.env.SVN_TEST_WC
vim.cmd.cd(vim.fn.fnameescape(wc))
local errors = {}
vim.notify = function(message, level)
    if level == vim.log.levels.ERROR then errors[#errors + 1] = message end
end
vim.cmd.SvnStatus()
local status_buf = vim.api.nvim_get_current_buf()
assert(vim.wait(3000, function()
    return table.concat(vim.api.nvim_buf_get_lines(status_buf, 0, -1, false), '\n'):find('modified', 1, true) ~= nil
end), 'status should list changed file')
assert(not vim.bo[status_buf].modifiable)
assert(table.concat(vim.api.nvim_buf_get_lines(status_buf, 0, -1, false), '\n'):find('conflicted', 1, true))

local function mapping(buf, lhs)
    for _, key in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
        if key.lhs == lhs or (lhs == '<Space>' and key.lhs == ' ') then key.callback(); return end
    end
    error('Missing mapping ' .. lhs)
end
local function find_row(buf, text)
    for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line:find(text, 1, true) then return row end
    end
end

local old_cursor = vim.api.nvim_win_get_cursor(0)
mapping(status_buf, '?')
local help = vim.api.nvim_get_current_buf()
assert(vim.api.nvim_win_get_config(0).relative == 'editor' and not vim.bo.modifiable)
local help_text = table.concat(vim.api.nvim_buf_get_lines(help, 0, -1, false), '\n')
assert(help_text:find('SvnCommitSubmit', 1, true) and help_text:find('Show/hide clean externals', 1, true))
mapping(help, 'q')
assert(vim.api.nvim_get_current_buf() == status_buf and vim.deep_equal(vim.api.nvim_win_get_cursor(0), old_cursor))

assert(not find_row(status_buf, 'External: external'), 'clean externals should be hidden by default')
assert(find_row(status_buf, '1 clean externals hidden'))
mapping(status_buf, 'x')
assert(vim.wait(3000, function() return find_row(status_buf, 'External: external') ~= nil end))
mapping(status_buf, 'x')
assert(vim.wait(3000, function() return find_row(status_buf, '1 clean externals hidden') ~= nil end))
-- Refresh preserves selected paths and discovers file/property changes.
vim.fn.writefile({'shared edited'}, wc .. '/external/shared.txt')
vim.fn.writefile({'new'}, wc .. '/src/added.txt')
vim.fn.writefile({'untracked'}, wc .. '/src/odd & <name>.txt')
assert(vim.system({'svn', 'add', wc .. '/src/added.txt@'}):wait().code == 0)
assert(vim.system({'svn', 'delete', wc .. '/src/deleted.txt@'}):wait().code == 0)
vim.api.nvim_win_set_cursor(0, {find_row(status_buf, 'file with spaces.txt'), 0})
mapping(status_buf, 'r')
assert(vim.wait(3000, function() return find_row(status_buf, 'shared.txt') ~= nil end))
assert(vim.api.nvim_win_get_cursor(0)[1] == find_row(status_buf, 'file with spaces.txt'))
assert(find_row(status_buf, 'added') and find_row(status_buf, 'deleted'))
assert(find_row(status_buf, 'odd & <name>.txt'), 'XML filename entities must be decoded')
local external_row = find_row(status_buf, 'shared.txt')
assert(external_row > find_row(status_buf, 'External: external'))
-- Enter opens a path while leaving the review window intact.
vim.api.nvim_win_set_cursor(0, {external_row, 0})
mapping(status_buf, '<CR>')
assert(vim.api.nvim_buf_get_name(0) == wc .. '/external/shared.txt')
assert(vim.fn.bufwinid(status_buf) ~= -1)
vim.cmd.close()
vim.api.nvim_set_current_win(vim.fn.bufwinid(status_buf))
-- d uses a real native diff for ordinary modified files.
vim.api.nvim_win_set_cursor(0, {find_row(status_buf, 'file with spaces.txt'), 0})
mapping(status_buf, 'd')
assert(vim.wo.diff and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'original')
vim.cmd.close()
vim.api.nvim_set_current_win(vim.fn.bufwinid(vim.fn.bufnr(wc .. '/src/file with spaces.txt')))
vim.cmd.diffoff()
vim.cmd.close()
vim.api.nvim_set_current_win(vim.fn.bufwinid(status_buf))
-- Directory property changes use a patch, rather than trying to cat a directory.
vim.api.nvim_win_set_cursor(0, {find_row(status_buf, 'property changed'), 0})
mapping(status_buf, 'd')
local property_patch = vim.api.nvim_get_current_buf()
assert(vim.wait(3000, function()
    return table.concat(vim.api.nvim_buf_get_lines(property_patch, 0, -1, false), '\n')
        :find('svn:externals', 1, true) ~= nil
end), 'property changes should appear in the diff: ' .. table.concat(vim.api.nvim_buf_get_lines(property_patch, 0, -1, false), '\n') .. vim.inspect(errors))
vim.cmd.close()
vim.api.nvim_set_current_win(vim.fn.bufwinid(status_buf))

-- Added and deleted files have no editable comparison, but do have saved patches.
for _, case in ipairs({ {'added.txt', '+new'}, {'deleted.txt', '-delete me'} }) do
    vim.api.nvim_win_set_cursor(0, {find_row(status_buf, case[1]), 0})
    mapping(status_buf, 'd')
    local diff_buf = vim.api.nvim_get_current_buf()
    assert(vim.wait(3000, function()
        return table.concat(vim.api.nvim_buf_get_lines(diff_buf, 0, -1, false), '\n'):find(case[2], 1, true) ~= nil
    end), 'added/deleted path patch missing')
    vim.cmd.close()
    vim.api.nvim_set_current_win(vim.fn.bufwinid(status_buf))
end

-- Unversioned paths have no diff and should leave the list active.
vim.api.nvim_win_set_cursor(0, {find_row(status_buf, 'odd & <name>.txt'), 0})
mapping(status_buf, 'd')
assert(vim.api.nvim_get_current_buf() == status_buf)
-- Calling the command again reuses and refreshes the existing status window.
vim.cmd.SvnStatus()
assert(vim.api.nvim_get_current_buf() == status_buf)
assert(vim.wait(3000, function() return find_row(status_buf, 'shared.txt') ~= nil end))

vim.cmd.close()
vim.cmd('SvnExternals src')
local property_buffer = vim.api.nvim_get_current_buf()
assert(vim.bo.buftype == 'acwrite')
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'^/library external'})
vim.cmd.write()
assert(not vim.bo.modified and #errors == 0)
local target = wc .. '/src@'
local prop = vim.system({'svn', 'propget', '--strict', 'svn:externals', target}, {text=true}):wait()
assert(prop.stdout == '^/library external\n')
-- An invalid external must not change the working-copy property.
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'invalid'})
vim.cmd.write()
assert(vim.bo.modified and #errors == 1)
-- Refuse to overwrite another tool's property edit.
vim.system({'svn', 'propset', 'svn:externals', '^/other external', target}):wait()
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'^/library external'})
vim.cmd.write()
assert(vim.bo.modified and #errors == 2)
vim.cmd('SvnDiff ' .. vim.fn.fnameescape('src/file with spaces.txt'))
assert(vim.wo.diff and vim.bo.modifiable == false)
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == 'original')

vim.cmd('close')
vim.cmd.diffoff()
vim.cmd('edit ' .. vim.fn.fnameescape(wc .. '/src/markers.txt'))
local file = vim.api.nvim_get_current_buf()
local ns = vim.api.nvim_get_namespaces().nvim_svn_signs
vim.cmd.SvnRefresh()
assert(vim.wait(3000, function() return vim.b.svn_hunks ~= nil end), 'BASE lookup timed out')
local function change(lines)
    vim.api.nvim_buf_set_lines(file, 0, -1, false, lines)
    vim.api.nvim_exec_autocmds('TextChanged', {buffer=file})
    vim.wait(350, function() return false end)
    return vim.api.nvim_buf_get_extmarks(file, ns, 0, -1, {details=true})
end
local marks = change({'one', 'TWO', 'three', 'four', 'five'})
assert(#marks == 1 and marks[1][2] == 1 and vim.trim(marks[1][4].sign_text) == '~', vim.inspect(marks))
marks = change({'one', 'two', 'ADDED', 'three', 'four', 'five'})
assert(#marks == 1 and marks[1][2] == 2 and vim.trim(marks[1][4].sign_text) == '+')
marks = change({'two', 'three', 'four', 'five'})
assert(#marks == 1 and marks[1][2] == 0 and vim.trim(marks[1][4].sign_text) == '_')
marks = change({'one', 'two', 'three', 'four'})
assert(#marks == 1 and marks[1][2] == 3 and vim.trim(marks[1][4].sign_text) == '_')
marks = change({'one', 'TWO', 'EXTRA', 'three', 'four', 'five'})
assert(#marks == 2 and vim.trim(marks[1][4].sign_text) == '~'
    and vim.trim(marks[2][4].sign_text) == '+')
marks = change({'one', 'two', 'three', 'four', 'five'})
assert(#marks == 0, 'clean buffer must not have signs')
marks = change({'one', 'TWO', 'three', 'four', 'FIVE'})
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.cmd.SvnNextChange()
assert(vim.api.nvim_win_get_cursor(0)[1] == 2)
vim.cmd.SvnNextChange()
assert(vim.api.nvim_win_get_cursor(0)[1] == 5)
vim.cmd.SvnPrevChange()
assert(vim.api.nvim_win_get_cursor(0)[1] == 2)

-- Preview only the selected hunk and preserve both the buffer and disk.
local before = vim.api.nvim_buf_get_lines(file, 0, -1, false)
vim.cmd.SvnPreviewHunk()
local preview
for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= '' then preview = win end
end
assert(preview, 'preview should use a native float')
local preview_buf = vim.api.nvim_win_get_buf(preview)
local patch_text = table.concat(vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false), '\n')
assert(patch_text:find('-two', 1, true) and patch_text:find('+TWO', 1, true))
assert(not patch_text:find('FIVE', 1, true), 'preview should show only the selected hunk')
assert(not vim.bo[preview_buf].modifiable)
vim.api.nvim_win_close(preview, true)
assert(vim.deep_equal(before, vim.api.nvim_buf_get_lines(file, 0, -1, false)))
vim.cmd.SvnRevertHunk()
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(file, 0, -1, false),
    {'one', 'two', 'three', 'four', 'FIVE'}), 'other hunks must survive: ' .. vim.inspect(vim.api.nvim_buf_get_lines(file, 0, -1, false)) .. vim.inspect(errors))
vim.cmd.undo()
assert(vim.deep_equal(before, vim.api.nvim_buf_get_lines(file, 0, -1, false)), 'undo must restore just the hunk')
vim.cmd.redo()
assert(vim.api.nvim_buf_get_lines(file, 1, 2, false)[1] == 'two')
-- Added, deleted, replacement, and entire-file hunks, including boundaries.
local baseline = {'one', 'two', 'three', 'four', 'five'}
for _, case in ipairs({
    { {'one', 'two', 'EXTRA', 'three', 'four', 'five'}, 3 },
    { {'EXTRA', 'one', 'two', 'three', 'four', 'five'}, 1 },
    { {'one', 'two', 'three', 'four', 'five', 'EXTRA'}, 6 },
    { {'two', 'three', 'four', 'five'}, 1 },
    { {'one', 'two', 'three', 'four'}, 4 },
    { {'one', 'four', 'five'}, 1 },
    { {'one', 'TWO', 'EXTRA', 'three', 'four', 'five'}, 2 },
    { {''}, 1 },
}) do
    change(case[1])
    vim.api.nvim_win_set_cursor(0, {case[2], 0})
    vim.cmd.SvnRevertHunk()
    assert(vim.deep_equal(baseline, vim.api.nvim_buf_get_lines(file, 0, -1, false)), vim.inspect(case))
    vim.cmd.undo()
    assert(vim.deep_equal(case[1], vim.api.nvim_buf_get_lines(file, 0, -1, false)), 'hunk undo failed')
end
assert(vim.deep_equal(vim.fn.readfile(wc .. '/src/markers.txt'), baseline), 'revert must not write disk')
-- A changed BASE must be read afresh before an explicit revert.
vim.fn.writefile({'fresh', 'two', 'three', 'four', 'five'}, wc .. '/src/markers.txt')
local commit = vim.system({'svn', 'commit', '-m', 'new base', wc .. '/src/markers.txt@'}):wait()
assert(commit.code == 0)
change({'dirty', 'two', 'three', 'four', 'five'})
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.cmd.SvnRevertHunk()
assert(vim.api.nvim_buf_get_lines(file, 0, 1, false)[1] == 'fresh', 'revert used stale BASE')

local stable = vim.api.nvim_buf_get_lines(file, 0, -1, false)
vim.cmd.SvnRevertHunk()
assert(#errors == 3 and errors[3]:find('No SVN change', 1, true))
table.remove(errors)
assert(vim.deep_equal(stable, vim.api.nvim_buf_get_lines(file, 0, -1, false)))
change({'dirty', 'two', 'three', 'four', 'five'})
vim.bo.readonly = true
vim.cmd.SvnRevertHunk()
assert(#errors == 3 and errors[3]:find('read-only', 1, true))
table.remove(errors)
vim.bo.readonly = false
local undo_limit = vim.bo.undolevels
vim.bo.undolevels = -1
vim.cmd.SvnRevertHunk()
assert(#errors == 3 and errors[3]:find('Enable undo', 1, true))
table.remove(errors)
vim.bo.undolevels = undo_limit
assert(vim.api.nvim_buf_get_lines(file, 0, 1, false)[1] == 'dirty')


-- Untracked files must not inherit signs or report noisy background errors.
vim.cmd('new ' .. vim.fn.fnameescape(wc .. '/untracked.txt'))
vim.cmd.SvnRefresh()
vim.wait(200, function() return false end)
assert(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) == 0)
-- History and revision patches use the actual temporary repository.
vim.cmd.SvnLog()
local log = vim.api.nvim_get_current_buf()
assert(vim.wait(3000, function()
    return vim.api.nvim_buf_get_lines(log, 0, -1, false)[1] ~= 'Loading SVN output...'
end))
local history = vim.api.nvim_buf_get_lines(log, 0, -1, false)
local header
for index, line in ipairs(history) do if line:match('^r1 |') then header = index end end
assert(header and table.concat(history, '\n'):find('fixture', 1, true))
vim.api.nvim_win_set_cursor(0, {header, 0})
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(log, 'n')) do
    if mapping.lhs == '<CR>' then mapping.callback() end
end
local patch = vim.api.nvim_get_current_buf()
assert(patch ~= log, 'Enter should open the selected revision')
assert(vim.wait(3000, function()
    return vim.api.nvim_buf_get_lines(patch, 0, -1, false)[1] ~= 'Loading SVN output...'
end))
assert(table.concat(vim.api.nvim_buf_get_lines(patch, 0, -1, false), '\n'):find('+original', 1, true))
assert(not vim.bo[patch].modifiable)
-- Commit only a selected property and file; never unrelated descendants.
assert(vim.system({'svn', 'update', '--depth', 'empty', wc .. '@'}):wait().code == 0)
vim.cmd.SvnStatus()
local commit_status = vim.api.nvim_get_current_buf()
assert(vim.wait(3000, function() return find_row(commit_status, 'file with spaces.txt') ~= nil end))
local function focus(buf) vim.api.nvim_set_current_win(vim.fn.bufwinid(buf)) end
local function choose(text)
    focus(commit_status)
    vim.api.nvim_win_set_cursor(0, {find_row(commit_status, text), 0})
    mapping(commit_status, '<Space>')
    assert(vim.wait(3000, function()
        local row = find_row(commit_status, text)
        return row and vim.api.nvim_buf_get_lines(commit_status, row - 1, row, false)[1]:find('[x]', 1, true) ~= nil
    end))
end

local real_system = vim.system
local full_status_requests = 0
vim.system = function(command, ...)
    if command[3] == 'status' and command[4] == '--xml' and command[5] == wc .. '@' then
        full_status_requests = full_status_requests + 1
    end
    return real_system(command, ...)
end
local first_row = find_row(commit_status, 'property changed')
vim.api.nvim_win_set_cursor(0, {first_row, 0})
local cursor_before = vim.api.nvim_win_get_cursor(0)
local panel_before = vim.api.nvim_buf_get_lines(commit_status, 0, -1, false)
choose('property changed')
assert(vim.deep_equal(cursor_before, vim.api.nvim_win_get_cursor(0)), 'selection must keep cursor position')
local panel_after = vim.api.nvim_buf_get_lines(commit_status, 0, -1, false)
assert(#panel_before == #panel_after)
for index, line in ipairs(panel_before) do
    if index ~= first_row and not line:find('Selected:', 1, true) then
        assert(line == panel_after[index], 'selection must not rebuild other panel rows')
    end
end
choose('file with spaces.txt')
assert(full_status_requests == 0, 'selection must not reload project status')
vim.system = real_system

assert(find_row(commit_status, 'Selected: 2 (Project)'), 'selection count and scope should be visible')
vim.api.nvim_win_set_cursor(0, {find_row(commit_status, 'shared.txt'), 0})
mapping(commit_status, '<Space>')
assert(#errors == 3 and errors[3]:find('one project/external', 1, true))
table.remove(errors)
vim.api.nvim_win_set_cursor(0, {find_row(commit_status, 'conflicted.txt'), 0})
mapping(commit_status, '<Space>')
assert(#errors == 3 and errors[3]:find('not committable', 1, true))
table.remove(errors)
mapping(commit_status, 'c')
local draft = vim.api.nvim_get_current_buf()
local draft_name = vim.api.nvim_buf_get_name(draft)
local function youngest()
    return vim.trim(vim.system({'svnlook', 'youngest', vim.env.SVN_TEST_REPO}, {text=true}):wait().stdout)
end
local initial_revision = youngest()
vim.cmd.SvnCommitSubmit()
assert(#errors == 3 and errors[3]:find('nonempty', 1, true))
table.remove(errors)
vim.api.nvim_buf_set_lines(draft, 0, -1, false, {'Selected property and file', '', 'Detailed message.'})
vim.cmd.write()
assert(vim.uv.fs_stat(draft_name) and youngest() == initial_revision, 'saving must not commit')
vim.cmd.SvnCommitReview()
local review = vim.api.nvim_get_current_buf()
local reviewed = table.concat(vim.api.nvim_buf_get_lines(review, 0, -1, false), '\n')
assert(reviewed:find('svn:externals', 1, true) and reviewed:find('+changed', 1, true))
assert(not reviewed:find('+new', 1, true) and not reviewed:find('delete me', 1, true))
assert(not vim.bo[review].modifiable)
vim.cmd.close()
focus(draft)
-- Selected unsaved buffers are rejected, as are changes since draft creation.
local selected_file = vim.fn.bufnr(wc .. '/src/file with spaces.txt')
vim.api.nvim_buf_set_lines(selected_file, 0, -1, false, {'unsaved'})
vim.cmd.SvnCommitSubmit()
assert(#errors == 3 and errors[3]:find('unsaved buffer', 1, true))
table.remove(errors)
vim.api.nvim_buf_set_lines(selected_file, 0, -1, false, {'changed'})
vim.bo[selected_file].modified = false
vim.fn.writefile({'changed after review'}, wc .. '/src/file with spaces.txt')
vim.cmd.SvnCommitSubmit()
assert(#errors == 3 and errors[3]:find('after drafting', 1, true))
table.remove(errors)
assert(youngest() == initial_revision)
vim.fn.writefile({'changed'}, wc .. '/src/file with spaces.txt')
-- A server-side rejection preserves the draft and can be retried.
local hook = vim.env.SVN_TEST_REPO .. '/hooks/pre-commit'
vim.fn.writefile({'#!/bin/sh', 'echo fixture-rejection >&2', 'exit 1'}, hook)
vim.fn.setfperm(hook, 'rwx------')
vim.cmd.SvnCommitSubmit()
assert(vim.wait(3000, function() return #errors == 3 end), 'hook should reject commit')
assert(errors[3]:find('commit failed', 1, true))
assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('fixture-rejection', 1, true), 'hook rejection must be reported')
table.remove(errors)
assert(youngest() == initial_revision and vim.api.nvim_buf_is_valid(draft))
assert(vim.api.nvim_buf_get_lines(draft, 0, 1, false)[1] == 'Selected property and file')
vim.fn.delete(hook)
focus(draft)
vim.cmd.SvnCommitSubmit()
assert(vim.wait(3000, function() return youngest() ~= initial_revision end), vim.inspect(errors) .. table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'))
assert(vim.wait(3000, function() return vim.api.nvim_buf_get_name(0):find('svn-commit-result://', 1, true) ~= nil end))
local remaining = vim.system({'svn', 'status', '--xml', wc .. '@'}, {text=true}):wait().stdout
assert(remaining:find('item="added"', 1, true) and remaining:find('item="deleted"', 1, true)
    and remaining:find('item="conflicted"', 1, true), 'unselected changes must remain')
local committed_file = vim.system({'svn', 'status', wc .. '/src/file with spaces.txt@'}, {text=true}):wait()
assert(committed_file.stdout == '')
local external_status = vim.system({'svn', 'status', wc .. '/external/shared.txt@'}, {text=true}):wait().stdout
assert(external_status:sub(1, 1) == 'M', 'project commit must not include externals')
focus(draft)
vim.cmd.SvnCommitSubmit()
assert(#errors == 3 and errors[3]:find('already committed', 1, true))
table.remove(errors)
-- External selection gets its own separate commit.
focus(commit_status)
mapping(commit_status, 'r')
assert(vim.wait(3000, function() return find_row(commit_status, 'shared.txt') ~= nil end))
choose('shared.txt')
mapping(commit_status, 'c')
local external_draft = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(external_draft, 0, -1, false, {'External-only change'})
local before_external = youngest()
vim.cmd.SvnCommitSubmit()
assert(vim.wait(3000, function() return youngest() ~= before_external end))
assert(vim.wait(3000, function() return vim.api.nvim_buf_get_name(0):find('svn-commit-result://', 1, true) ~= nil end))
assert(vim.system({'svn', 'status', wc .. '/external/shared.txt@'}, {text=true}):wait().stdout == '')

assert(#errors == 2, table.concat(errors, '\n'))
vim.cmd('qa!')
''')
            env = dict(os.environ, SVN_TEST_WC=str(wc), SVN_TEST_REPO=str(repo))
            for key in ('XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME'):
                env[key] = str(base / key)
            result = subprocess.run(['nvim', '--headless', '-i', 'NONE', '-u', str(CONFIG),
                                     '-l', str(script)], env=env, text=True,
                                    capture_output=True, timeout=45)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


    def test_changelists_and_file_revert(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo = base / 'repo'
            wc = base / 'working copy@lists'
            def svn(*args):
                return subprocess.check_output(['svn', *map(str, args)], text=True)
            subprocess.run(['svnadmin', 'create', str(repo)], check=True)
            svn('checkout', repo.as_uri(), wc)
            target = wc / 'local & opts@.txt'
            target.write_text('base content\nsecond line\n')
            svn('add', str(target) + '@')
            svn('commit', '-m', 'fixture', str(wc) + '@')
            svn('update', str(wc) + '@')
            target.write_text('saved content\n')
            svn('propset', 'test:property', 'changed property', str(target) + '@')
            script = base / 'check_lists.lua'
            script.write_text(r'''local wc = vim.env.SVN_TEST_WC
local path = wc .. '/local & opts@.txt'
vim.cmd.cd(vim.fn.fnameescape(wc))
vim.cmd('edit ' .. vim.fn.fnameescape(path))
local file = vim.api.nvim_get_current_buf()
local errors = {}
vim.notify = function(message, level) if level == vim.log.levels.ERROR then errors[#errors + 1] = message end end
local function svn(args)
    local cmd = {'svn'}; vim.list_extend(cmd, args)
    local result = vim.system(cmd, {text=true}):wait()
    assert(result.code == 0, result.stderr)
    return result.stdout
end
local function list_name()
    return svn({'status', '--xml', path .. '@'})
end
vim.cmd('SvnChangelist Ignore')
assert(list_name():find('name="Ignore"', 1, true))
vim.cmd.SvnStatus()
local status = vim.api.nvim_get_current_buf()
local function ready()
    return vim.wait(3000, function()
        return table.concat(vim.api.nvim_buf_get_lines(status, 0, -1, false), '\n'):find('local & opts@.txt', 1, true) ~= nil
    end)
end
local function focus() vim.api.nvim_set_current_win(vim.fn.bufwinid(status)) end
local function row()
    for index, line in ipairs(vim.api.nvim_buf_get_lines(status, 0, -1, false)) do
        if line:find('local & opts@.txt', 1, true) then return index end
    end
end
local function key(lhs)
    focus(); vim.api.nvim_win_set_cursor(0, {row(), 0})
    if lhs ~= 'r' then vim.cmd('normal! zv') end -- Open before file actions.
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(status, 'n')) do
        if mapping.lhs == lhs or lhs == '<Space>' and mapping.lhs == ' ' then mapping.callback(); return end
    end
    error('missing mapping ' .. lhs)
end
assert(ready())
assert(table.concat(vim.api.nvim_buf_get_lines(status, 0, -1, false), '\n'):find('[Ignore]', 1, true))
assert(vim.api.nvim_buf_get_lines(status, row() - 1, row(), false)[1]:find('[-]', 1, true))
assert(not vim.api.nvim_buf_get_lines(status, row() - 1, row(), false)[1]:find('[Ignore]', 1, true), 'changelist belongs in heading, not each row')

local ignore_heading
for index, line in ipairs(vim.api.nvim_buf_get_lines(status, 0, -1, false)) do
    if line:find('Changelist: [Ignore]', 1, true) then ignore_heading = index end
end
assert(ignore_heading and vim.fn.foldclosed(ignore_heading) == ignore_heading,
    'Ignore must be folded by default')
assert(vim.api.nvim_buf_get_lines(status, ignore_heading - 1, ignore_heading, false)[1]:find('1 file', 1, true))
vim.api.nvim_win_set_cursor(0, {ignore_heading, 0})
vim.cmd('normal! za')
assert(vim.fn.foldclosed(ignore_heading) == -1, 'native za must open the group')
key('r'); assert(ready())
assert(vim.fn.foldclosed(row()) == -1, 'refresh must preserve open groups')
vim.cmd('normal! zc')
key('r'); assert(ready())
assert(vim.fn.foldclosed(row()) ~= -1, 'refresh must preserve closed groups')

key('<Space>')
assert(#errors == 1 and errors[1]:find('Protected changelist', 1, true))
errors = {}
key('i') -- Ignore -> no changelist
assert(ready() and not list_name():find('name="Ignore"', 1, true))
vim.ui.input = function(options, callback) callback('Feature & settings') end
key('l')
assert(ready() and list_name():find('Feature &amp; settings', 1, true))
assert(table.concat(vim.api.nvim_buf_get_lines(status, 0, -1, false), '\n'):find('[Feature & settings]', 1, true))
-- A draft cannot bypass Ignore protection added after drafting.
key('<Space>'); assert(ready())
key('c')
local draft = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(draft, 0, -1, false, {'Do not send'})
svn({'changelist', 'Ignore', path .. '@'})
vim.cmd.SvnCommitSubmit()
assert(#errors == 1 and errors[1]:find('Protected changelist', 1, true))
assert(vim.trim(vim.system({'svnlook', 'youngest', vim.env.SVN_TEST_REPO}, {text=true}):wait().stdout) == '1')
errors = {}
focus(); key('r'); assert(ready())
vim.api.nvim_win_set_cursor(0, {row(), 0})
vim.cmd('normal! zv')
vim.cmd.SvnChangelistRemove()
assert(ready() and not list_name():find('<changelist', 1, true))
key('i'); assert(ready()) -- no changelist -> Ignore
assert(list_name():find('name="Ignore"', 1, true))
-- Revert preview includes saved properties and unsaved buffer text.
vim.api.nvim_set_current_win(vim.fn.bufwinid(file))
vim.api.nvim_buf_set_lines(file, 0, -1, false, {'unsaved content'})
vim.ui.select = function(items, options, callback) callback('Cancel') end
vim.cmd.SvnRevertFile()
local preview_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
assert(preview_text:find('test:property', 1, true) and preview_text:find('+unsaved content', 1, true))
assert(vim.fn.readfile(path)[1] == 'saved content' and vim.api.nvim_buf_get_lines(file, 0, 1, false)[1] == 'unsaved content')
-- Editing while a confirmation is pending invalidates the preview.
vim.api.nvim_set_current_win(vim.fn.bufwinid(file))
local confirm
vim.ui.select = function(items, options, callback) confirm = callback end
vim.cmd.SvnRevertFile()
vim.api.nvim_buf_set_lines(file, 0, -1, false, {'changed during confirmation'})
confirm('Revert file')
assert(#errors == 1 and errors[1]:find('after preview', 1, true))
assert(vim.fn.readfile(path)[1] == 'saved content')
errors = {}
vim.api.nvim_set_current_win(vim.fn.bufwinid(file))
vim.ui.select = function(items, options, callback) callback('Revert file') end
vim.cmd.SvnRevertFile()
assert(vim.fn.readfile(path)[1] == 'base content')
assert(vim.api.nvim_buf_get_lines(file, 0, 1, false)[1] == 'base content' and not vim.bo[file].modified)
local props = svn({'proplist', '--xml', path .. '@'})
assert(not props:find('test:property', 1, true))
assert(list_name():find('name="Ignore"', 1, true), 'revert should preserve changelist membership')


-- Blame maps unchanged lines through local insertions and deletions.
local function focus_file() vim.api.nvim_set_current_win(vim.fn.bufwinid(file)) end
local function blame(lines, cursor)
    focus_file()
    vim.api.nvim_buf_set_lines(file, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, {cursor, 0})
    vim.cmd.SvnBlame()
    assert(vim.wait(3000, function() return vim.api.nvim_win_get_config(0).relative ~= '' end), 'blame float missing: ' .. vim.inspect(errors))
    local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    assert(text:find('r1', 1, true) and not vim.bo.modifiable)
    return text, vim.api.nvim_get_current_buf()
end
local function float_key(buf, lhs)
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
        if mapping.lhs == lhs then mapping.callback(); return end
    end
    error('missing blame mapping')
end
local text, attribution = blame({'inserted', 'base content', 'second line'}, 2)
assert(text:find('BASE line 1', 1, true))
float_key(attribution, '<CR>')
local message_buf = vim.api.nvim_get_current_buf()
assert(vim.wait(3000, function()
    return table.concat(vim.api.nvim_buf_get_lines(message_buf, 0, -1, false), '\n'):find('fixture', 1, true) ~= nil
end), 'blame commit message missing')
vim.cmd.close()
text, attribution = blame({'second line'}, 1)
assert(text:find('BASE line 2', 1, true))
float_key(attribution, 'd')
local blame_patch = vim.api.nvim_get_current_buf()
assert(vim.wait(3000, function()
    return table.concat(vim.api.nvim_buf_get_lines(blame_patch, 0, -1, false), '\n'):find('+base content', 1, true) ~= nil
end))
vim.cmd.close()
focus_file()
vim.api.nvim_buf_set_lines(file, 0, -1, false, {'local replacement', 'second line'})
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.cmd.SvnBlame()
assert(#errors == 1 and errors[1]:find('locally added or changed', 1, true))
errors = {}
vim.api.nvim_buf_set_lines(file, 0, -1, false, {'base content', 'second line'})
vim.bo[file].modified = false
-- Unversioned deletion gets a useful native-file-browser explanation.
vim.fn.writefile({'untracked'}, wc .. '/unversioned.txt')
vim.cmd('SvnDelete ' .. vim.fn.fnameescape(wc .. '/unversioned.txt'))
assert(#errors == 1 and errors[1]:find('Use :Ex and D', 1, true))
assert(vim.uv.fs_stat(wc .. '/unversioned.txt'))
errors = {}

vim.cmd('new ' .. vim.fn.fnameescape(wc .. '/unversioned.txt'))
local new_file = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(new_file, 0, -1, false, {'unsaved new content'})
vim.cmd.SvnAdd()
assert(#errors == 1 and errors[1]:find('Save the file', 1, true))
errors = {}
vim.cmd.write()
vim.cmd.SvnAdd()
assert(svn({'status', '--xml', wc .. '/unversioned.txt@'}):find('item="added"', 1, true))
assert(vim.trim(vim.system({'svnlook', 'youngest', vim.env.SVN_TEST_REPO}, {text=true}):wait().stdout) == '1')
vim.cmd.close()
focus_file()


-- A short delete command resolves the current file, including spaces and @.
vim.api.nvim_set_current_win(vim.fn.bufwinid(file))
vim.ui.select = function(items, options, callback) callback('Cancel') end
vim.cmd.SvnDelete()
assert(vim.uv.fs_stat(path) and vim.api.nvim_buf_is_valid(file))
vim.api.nvim_buf_set_lines(file, 0, -1, false, {'unsaved'})
vim.cmd.SvnDelete()
assert(#errors == 1 and errors[1]:find('unsaved edits', 1, true))
errors = {}
vim.api.nvim_buf_set_lines(file, 0, -1, false, {'base content'})
vim.bo[file].modified = false
vim.ui.select = function(items, options, callback) callback('Delete file') end
vim.cmd.SvnDelete()
assert(not vim.uv.fs_stat(path) and not vim.api.nvim_buf_is_valid(file))
assert(list_name():find('item="deleted"', 1, true), 'delete must be scheduled in SVN')

assert(#errors == 0, vim.inspect(errors))
vim.cmd('qa!')
''')
            env = dict(os.environ, SVN_TEST_WC=str(wc), SVN_TEST_REPO=str(repo))
            for key in ('XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME'):
                env[key] = str(base / key)
            result = subprocess.run(['nvim', '--headless', '-i', 'NONE', '-u', str(CONFIG),
                                     '-l', str(script)], env=env, text=True,
                                    capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


    def test_conflict_diff_and_resolution(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo, wc, peer = base / 'repo', base / 'working copy@conflict', base / 'peer'
            def svn(*args):
                return subprocess.check_output(['svn', *map(str, args)], text=True)
            subprocess.run(['svnadmin', 'create', str(repo)], check=True)
            svn('checkout', repo.as_uri(), wc)
            target = wc / 'conflict & file@.txt'
            target.write_text('base content\n')
            property_file = wc / 'property.txt'
            tree_file = wc / 'tree.txt'
            property_file.write_text('property content\n')
            tree_file.write_text('tree base\n')
            svn('add', str(target) + '@', property_file, tree_file)
            svn('propset', 'test:property', 'base', property_file)
            svn('commit', '-m', 'base', str(wc) + '@')
            svn('checkout', repo.as_uri(), peer)
            (peer / target.name).write_text('incoming edit\n')
            (peer / 'tree.txt').write_text('tree incoming\n')
            svn('propset', 'test:property', 'incoming', peer / 'property.txt')
            svn('commit', '-m', 'incoming', str(peer) + '@')
            target.write_text('local edit\n')
            svn('propset', 'test:property', 'local', property_file)
            svn('delete', tree_file)
            svn('update', str(wc) + '@')
            script = base / 'conflict.lua'
            script.write_text(r'''local path = vim.env.SVN_TEST_WC .. '/conflict & file@.txt'
local errors = {}
vim.notify = function(message, level) if level == vim.log.levels.ERROR then errors[#errors + 1] = message end end
vim.cmd('edit ' .. vim.fn.fnameescape(path))
local result = vim.api.nvim_get_current_buf()

vim.cmd('SvnConflict ' .. vim.fn.fnameescape(vim.env.SVN_TEST_WC .. '/property.txt'))
assert(#errors == 1 and errors[1]:find('Property/tree conflicts', 1, true))
errors = {}
vim.cmd('SvnResolve ' .. vim.fn.fnameescape(vim.env.SVN_TEST_WC .. '/property.txt'))
assert(#errors == 1 and errors[1]:find('Property/tree conflicts', 1, true))
errors = {}
vim.cmd('SvnConflict ' .. vim.fn.fnameescape(vim.env.SVN_TEST_WC .. '/tree.txt'))
assert(#errors == 1 and errors[1]:find('Tree conflicts', 1, true))
errors = {}

vim.cmd.SvnConflict()
assert(#vim.api.nvim_tabpage_list_wins(0) == 3, vim.inspect(errors))
assert(vim.api.nvim_get_current_buf() == result and vim.wo.diff)
local local_buf, incoming_buf
for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(window)
    local name = vim.api.nvim_buf_get_name(buf)
    assert(vim.wo[window].diff)
    if name:find('svn-conflict-local://', 1, true) then local_buf = buf end
    if name:find('svn-conflict-incoming://', 1, true) then incoming_buf = buf end
end
assert(local_buf and incoming_buf)
assert(not vim.bo[local_buf].modifiable and not vim.bo[incoming_buf].modifiable)
assert(vim.api.nvim_buf_get_lines(local_buf, 0, 1, false)[1] == 'local edit')
assert(vim.api.nvim_buf_get_lines(incoming_buf, 0, 1, false)[1] == 'incoming edit')
vim.cmd.SvnResolve()
assert(#errors == 1 and errors[1]:find('Conflict markers', 1, true), vim.inspect(errors))
errors = {}
-- Native diffget can take a source hunk into the real result buffer.
vim.cmd.diffupdate()
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.cmd('%diffget ' .. incoming_buf)
assert(vim.api.nvim_buf_get_lines(result, 0, 1, false)[1] == 'incoming edit', vim.inspect(vim.api.nvim_buf_get_lines(result, 0, -1, false)))
vim.cmd.SvnResolve()
assert(#errors == 1 and errors[1]:find('Save the merged', 1, true))
errors = {}
vim.api.nvim_buf_set_lines(result, 0, -1, false, {'reviewed merged result'})
vim.cmd.write()
local function conflicted()
    local output = vim.system({'svn', 'status', '--xml', path .. '@'}, {text=true}):wait().stdout
    return output:find('item="conflicted"', 1, true) ~= nil
end
vim.ui.select = function(items, options, callback) callback('Cancel') end
vim.cmd.SvnResolve()
assert(conflicted(), 'cancel must preserve conflict')
local confirm
vim.ui.select = function(items, options, callback) confirm = callback end
vim.cmd.SvnResolve()
vim.api.nvim_buf_set_lines(result, 0, -1, false, {'changed during prompt'})
vim.cmd.write()
confirm('Mark resolved')
assert(#errors == 1 and errors[1]:find('changed during confirmation', 1, true))
assert(conflicted())
errors = {}
vim.ui.select = function(items, options, callback) callback('Mark resolved') end
vim.cmd.SvnResolve()
assert(not conflicted())

local others = vim.system({'svn', 'status', '--xml', vim.env.SVN_TEST_WC .. '@'}, {text=true}):wait().stdout
assert(others:find('props="conflicted"', 1, true) and others:find('tree-conflicted="true"', 1, true),
    'resolving a file must not affect other property/tree conflicts')

assert(vim.fn.readfile(path)[1] == 'changed during prompt')
assert(not vim.uv.fs_stat(path .. '.mine'))
assert(not vim.uv.fs_stat(path .. '.r1') and not vim.uv.fs_stat(path .. '.r2'))
assert(vim.trim(vim.system({'svnlook', 'youngest', vim.env.SVN_TEST_REPO}, {text=true}):wait().stdout) == '2',
    'resolve must not commit')
assert(#errors == 0, vim.inspect(errors))
vim.cmd('qa!')
''')
            env = dict(os.environ, SVN_TEST_WC=str(wc), SVN_TEST_REPO=str(repo))
            for key in ('XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME'):
                env[key] = str(base / key)
            result = subprocess.run(['nvim', '--headless', '-i', 'NONE', '-u', str(CONFIG),
                                     '-l', str(script)], env=env, text=True,
                                    capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()

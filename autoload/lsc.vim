" vim: set foldmethod=marker foldlevel=0 nomodeline:

" private {{{
let s:enabled = 0
let s:servers = {}
let s:servers_whitelist = {}

function! s:get_visual_selection_pos() abort
    " https://groups.google.com/d/msg/vim_dev/oCUQzO3y8XE/vfIMJiHCHtEJ
    " https://stackoverflow.com/a/6271254
    " getpos("'>'") doesn't give the right column so need to do extra processing
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return [0, 0, 0, 0]
    endif
    let lines[-1] = lines[-1][: column_end - (&selection ==# 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return [line_start, column_start, line_end, len(lines[-1])]
endfunction

function! s:get_server_command(ft) abort
    if !has_key(s:servers_whitelist, a:ft)
        return
    endif
    for l:server_command in get(g:, 'lsc_server_commands', [])
        let l:whitelist = get(l:server_command, 'whitelist', [])
        if index(l:whitelist, a:ft) >= 0
            return l:server_command
        endif
    endfor

    call remove(s:servers_whitelist, a:ft)
endfunction

function! s:get_rootUri(buf) abort
    " TODO
endfunction

function! s:get_server_0(ft) abort
    return get(s:servers, a:ft)
endfunction


function! s:get_server_1(ft) abort
    let l:server = s:get_server_0(a:ft)

    if !empty(l:server)
        return l:server
    endif

    let l:server_command = s:get_server_command(a:ft)
    if type(l:server_command) != v:t_dict
        return
    endif

    let l:whitelist = get(l:server_command, 'whitelist', [])
    for l:ft in l:whitelist
        let l:server = get(s:servers, l:ft)
        if !empty(l:server)
            let s:servers[a:ft] = l:server
            return l:server
        endif
    endfor
    " Server has not been launched
    return l:server_command
endfunction

function! s:server_launch(server_command, buf) abort
    let l:whitelist = get(a:server_command, 'whitelist', [])
    let l:server = lsc#client#launch(a:server_command, getcwd(), a:buf)
    if type(l:server) == v:t_dict
        for l:ft in l:whitelist
            let s:servers[l:ft] = l:server
        endfor
    else
        for l:ft in l:whitelist
            if has_key(l:ft)
                call remove(s:servers_whitelist, l:ft)
            endif
        endfor
    endif
endfunction

function! s:get_last_char()
    let l:line = nvim_get_current_line()
    if empty(l:line)
        return
    endif
    return l:line[col('.') - 2]
endfunction

function! s:on_TextChangedI()
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    let l:char = s:get_last_char()
    call l:server.textDocument_didChange(l:buf_nr)

    if index(l:server.capabilities.completionProvider.triggerCharacters, l:char) >= 0
        call l:server.textDocument_completion(l:buf_nr, line('.') - 1, col('.') - 1, 2, l:char)
    elseif index(l:server.capabilities.signatureHelpProvider.triggerCharacters, l:char) >= 0
        call l:server.textDocument_signatureHelp(l:buf_nr, line('.') -1, col('.') -1)
    endif
    redraws
endfunction

function! s:register_events() abort
    augroup register_events
        autocmd!
        autocmd BufReadPost * if has_key(s:servers_whitelist, &filetype) | call s:on_text_document_did_open() | endif
        autocmd InsertLeave,TextChanged,TextChangedP * if has_key(s:servers_whitelist, &filetype) | call s:on_text_document_did_change() | endif
        autocmd BufWritePre * if has_key(s:servers_whitelist, &filetype) |  call s:on_text_document_did_will_save() | endif
        autocmd BufWritePost * if has_key(s:servers_whitelist, &filetype) |  call s:on_text_document_did_save() | endif
        autocmd BufUnload * if has_key(s:servers_whitelist, &filetype) | call s:on_text_document_did_close() | endif
        autocmd CursorHold * if has_key(s:servers_whitelist, &filetype) | call lsc#textDocument_documentHighlight() | endif
        autocmd FileType c,cpp,python setlocal omnifunc=lsc#complete
        " autocmd TextChangedI *  if has_key(s:servers_whitelist, &filetype) |  call s:on_TextChangedI() | endif
    augroup END
endfunction
" }}}

" Plugins {{{
function! lsc#enable() abort
    if s:enabled
        return
    endif

    for l:server_command in get(g:, 'lsc_server_commands', [])
        let l:whitelist = get(l:server_command, 'whitelist', [])
        for l:ft in l:whitelist
            let s:servers_whitelist[l:ft] = 1
        endfor
    endfor

    call s:register_events()
    let s:enabled = 1
endfunction

function! lsc#status() abort
    if empty(s:servers)
        echom 'No server is running!'
    endif
    for [l:ft, l:server] in items(s:servers)
        let l:jobid = get(l:server, '_jobid', -1)
        if l:jobid < 0
            echom printf('Server for [%s] is not running.', l:ft)
        else
            echom printf('Server for [%s] is running on job[%d] with command [%s].', l:ft, l:jobid, join(l:server._command))
        endif
    endfor
endfunction
" }}}

" cancelRequest {{{
function! lsc#general_cancelRequest(id) abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)

    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.cancelRequest(a:id)
    endif
endfunction
" }}}

" Workspace  {{{
function! lsc#workspace_didChangeWorkspaceFolders(added, removed) abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.workspace_didChangeWorkspaceFolders(a:added, a:removed)
    endif
endfunction

function! lsc#workspace_didChangeConfiguration(settings) abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.workspace_didChangeConfiguration(a:settings)
    endif
endfunction

function! lsc#workspace_didChangeWatchedFiles(events) abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.workspace_didChangeWatchedFiles(a:events)
    endif
endfunction

function! lsc#workspace_symbol() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#workspaceSymbol(l:server.capabilities)
        return
    endif
    let l:query = input('query >', expand('<cword>'))
    call l:server.workspace_symbol(l:query)
endfunction

function! lsc#workspace_executeCommand(command, arguments) abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.workspace_executeCommand(a:command, a:arguments)
    endif
endfunction
" }}}

" TextSynchronization {{{
function! s:on_text_document_did_open() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)

    let l:server = s:get_server_1(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.textDocument_didOpen(l:buf_nr)
    elseif type(l:server) == v:t_dict
        call s:server_launch(l:server, l:buf_nr)
    endif
endfunction

function! s:on_text_document_did_change() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)

    call lsc#log#verbose({'dir': 'C->S', 'didChange': {'buf_nr': l:buf_nr, 'buf_name': bufname(l:buf_nr), 'ft': l:buf_ft}})
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.textDocument_didChange(l:buf_nr)
    endif
endfunction

function! s:on_text_document_did_save() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    call lsc#log#verbose({'dir': 'C->S', 'didSave': {'buf_nr': l:buf_nr, 'buf_name': bufname(l:buf_nr), 'ft': l:buf_ft}})
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#TextDocumentSync_save(l:server.capabilities)
        return
    endif
    call l:server.textDocument_didSave(l:buf_nr)
endfunction

function! s:on_text_document_did_close() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)

    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#TextDocumentSync_openClose(l:server.capabilities)
        return
    endif
    call l:server.textDocument_didClose(l:buf_nr)
endfunction


function! s:on_text_document_did_will_save() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#TextDocumentSync_willSave(l:server.capabilities)
        return
    endif
    call l:server.textDocument_willSave(l:buf_nr, 1)
endfunction

function! lsc#textDocument_willSaveWaitUntil() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#TextDocumentSync_willSaveWaitUntil(l:server.capabilities)
        return
    endif
    call l:server.textDocument_willSaveWaitUntil(l:buf_nr)
endfunction
" }}}

" Omni{{{
function! lsc#complete(findstart, base) abort
    if a:findstart
        return col('.')
    endif

    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)

    if !lsc#client#is_client_instance(l:server)
        return []
    endif
    if !lsc#capabilities#completion(l:server.capabilities)
        return []
    endif

    let l:char = s:get_last_char()

    call l:server.textDocument_didChange(l:buf_nr)
    if index(lsc#capabilities#completion_triggerCharacters(l:server.capabilities), l:char) < 0
        call l:server.textDocument_completion(l:buf_nr, line('.') - 1, col('.') - 1, 1, '')
    else
        call l:server.textDocument_completion(l:buf_nr, line('.') - 1, col('.') - 1, 2, l:char)
    endif
    redraws
    return []
endfunction
" }}}

" {{{
function! lsc#Diagnostics_next()
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.Diagnostics_next(l:buf_nr, line('.') -1, col('.') -1)
    endif
endfunction

function! lsc#Diagnostics_prev()
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.Diagnostics_prev(l:buf_nr, line('.') -1, col('.') -1)
    endif
endfunction

function! lsc#textDocument_diagnostics()
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.textDocument_diagnostics(l:buf_nr)
    endif
endfunction

function! lsc#workspace_diagnostics()
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.workspace_diagnostics()
    endif
endfunction
" }}}

" Language Features {{{
function! lsc#textDocument_completion(kind, string) abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#completion(l:server.capabilities)
        return
    endif

    if a:kind == 2 && index(lsc#capabilities#completion_triggerCharacters(l:server.capabilities), a:string) < 0
        return
    endif

    call l:server.textDocument_didChange(l:buf_nr)
    call l:server.textDocument_completion(l:buf_nr, line('.') -1, col('.') -1, a:kind, a:string)
    redraws
endfunction

function! lsc#textDocument_hover() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#hover(l:server.capabilities)
        return
    endif
    call l:server.textDocument_hover(l:buf_nr, line('.') -1, col('.') -1)
endfunction

function! lsc#textDocument_signatureHelp() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#signatureHelp(l:server.capabilities)
        return
    endif
    if index(lsc#capabilities#signatureHelp_triggerCharacters(l:server.capabilities), '}') < 0
        return
    endif

    call l:server.textDocument_signatureHelp(l:buf_nr, line('.') -1, col('.') -1)
endfunction

function! lsc#textDocument_declaration() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.textDocument_declaration(l:buf_nr, line('.') -1, col('.') -1)
    endif
endfunction

function! lsc#textDocument_definition() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !(lsc#capabilities#definition(l:server.capabilities))
        return
    endif
    call l:server.textDocument_definition(l:buf_nr, line('.') -1, col('.') -1)
endfunction

function! lsc#textDocument_typeDefinition() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif

    call l:server.textDocument_typeDefinition(l:buf_nr, line('.') -1, col('.') -1)
endfunction

function! lsc#textDocument_implementation() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.textDocument_implementation(l:buf_nr, line('.') -1, col('.') -1)
    endif
endfunction

function! lsc#textDocument_references() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#references(l:server.capabilities)
        return
    endif
    call l:server.textDocument_references(l:buf_nr, line('.') -1, col('.') -1, v:true)
endfunction

function! lsc#textDocument_documentHighlight() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#documentHighlight(l:server.capabilities)
        return
    endif
    call l:server.textDocument_documentHighlight(l:buf_nr, line('.') -1, col('.') -1)
endfunction

function! lsc#textDocument_documentSymbol() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#documentSymbol(l:server.capabilities)
        return
    endif
    call l:server.textDocument_documentSymbol(l:buf_nr)
endfunction

function! lsc#textDocument_codeAction() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#codeAction(l:server.capabilities)
        return
    endif
    let l:lnum = line('.')
    let l:range = {
                \    'start': { 'line': l:lnum - 1, 'character': 0 },
                \    'end': { 'line': l:lnum, 'character': 0 },
                \ }
    call l:server.textDocument_rangeCodeAction(l:buf_nr, l:range)
endfunction

function! lsc#textDocument_rangeCodeAction() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#codeAction(l:server.capabilities)
        return
    endif

    let [l:start_lnum, l:start_col, l:end_lnum, l:end_col] = s:get_visual_selection_pos()
    let l:range = {
                \    'start': { 'line': l:start_lnum - 1, 'character': l:start_col - 1 },
                \    'end': { 'line': l:end_lnum - 1, 'character': l:end_col - 1 },
                \ }
    call l:server.textDocument_rangeCodeAction(l:buf_nr, l:range)
endfunction

function! lsc#textDocument_quikFix() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#codeAction(l:server.capabilities)
        return
    endif

endfunction

function! lsc#textDocument_codeAction_all() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#codeAction(l:server.capabilities)
        return
    endif
    call l:server.textDocument_codeAction_all(l:buf_nr)
endfunction


function! lsc#textDocument_codeLens() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#codeLens(l:server.capabilities)
        return
    endif
    call l:server.textDocument_codeLens(l:buf_nr)
endfunction

function! lsc#textDocument_documentLink() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#documentLink(l:server.capabilities)
        return
    endif
    call l:server.textDocument_documentLink(l:buf_nr)
endfunction

function! lsc#textDocument_documentColor() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    call l:server.textDocument_documentColor(l:buf_nr)
endfunction

function! lsc#textDocument_colorPresentation(color, range) abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if lsc#client#is_client_instance(l:server)
        call l:server.textDocument_colorPresentation(l:buf_nr, a:color, a:range)
    endif
endfunction

function! lsc#textDocument_formatting() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#documentFormatting(l:server.capabilities)
        return
    endif
    call l:server.textDocument_formatting(l:buf_nr)
endfunction

function! lsc#textDocument_rangeFormatting() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif

    if !lsc#capabilities#documentRangeFormatting(l:server.capabilities)
        return
    endif
    let [l:start_lnum, l:start_col, l:end_lnum, l:end_col] = s:get_visual_selection_pos()
    let l:range = {
                \    'start': { 'line': l:start_lnum - 1, 'character': l:start_col - 1 },
                \    'end': { 'line': l:end_lnum - 1, 'character': l:end_col - 1 },
                \ }
    call l:server.textDocument_rangeFormatting(l:buf_nr, l:range)
endfunction

function! lsc#textDocument_onTypeFormatting() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#documentOnTypeFormatting(l:server.capabilities)
        return
    endif
    call l:server.textDocument_onTypeFormatting(l:buf_nr, line('.') -1, col('.') -1)
endfunction

function! lsc#textDocument_rename() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    if !lsc#capabilities#rename(l:server.capabilities)
        return
    endif
    call l:server.textDocument_rename(l:buf_nr, line('.') -1, col('.') -1)
endfunction

function! lsc#textDocument_foldingRange() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)
    let l:server = s:get_server_0(l:buf_ft)
    if !lsc#client#is_client_instance(l:server)
        return
    endif
    call l:server.textDocument_foldingRange(l:buf_nr)
endfunction
" }}}

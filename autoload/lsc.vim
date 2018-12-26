let s:enabled = 0
let s:servers = {}
let s:servers_blacklist = {}

function! s:register_events() abort
    augroup LSC
        autocmd!
        autocmd BufReadPost * call s:on_text_document_did_open()
        autocmd InsertLeave,TextChanged * call s:on_text_document_did_change()
        autocmd BufWritePost * call s:on_text_document_did_save()
        autocmd BufWinLeave * call s:on_text_document_did_close()
    augroup END
endfunction

function! s:server_launch(buf) abort
    let l:buf_ft = lsc#utils#get_filetype(a:buf)

    if has_key(s:servers_blacklist, l:buf_ft)
        return
    endif

    let l:server = get(s:servers, l:buf_ft, 0)
    if type(l:server) == v:t_dict
        return
    endif

    let l:server_command = get(get(g:, 'lsc_server_commands', {}), l:buf_ft, 0)
    if type(l:server_command) == v:t_number
        let s:servers_blacklist[l:buf_ft] = 1
        return
    endif

    let l:server = lsc#client#launch(
                \ l:server_command.command,
                \ get(l:server_command, 'initialization_options', {}),
                \ get(l:server_command, 'workspace_config', {}),
                \ getcwd(),
                \ a:buf)
    if type(l:server) == v:t_dict
        let s:servers[l:buf_ft] = l:server
    else
        let s:servers_blacklist[l:buf_ft] = 1
    endif
endfunction

function! s:on_text_document_did_open() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)

    let l:server = get(s:servers, l:buf_ft, 0)
    if type(l:server) != v:t_dict
        call s:server_launch(l:buf_nr)
    else
        call lsc#client#textDocument_didOpen(l:server, l:buf_nr)
    endif
endfunction

function! s:on_text_document_did_change() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)

    let l:server = get(s:servers, l:buf_ft, 0)
    if type(l:server) != v:t_dict
        return
    endif

    call lsc#client#textDocument_didChange(l:server, l:buf_nr)
endfunction

function! s:on_text_document_did_save() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)

    let l:server = get(s:servers, l:buf_ft, 0)
    if type(l:server) != v:t_dict
        return
    endif

    call lsc#client#textDocument_didSave(l:server, l:buf_nr)
endfunction

function! s:on_text_document_did_close() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)

    let l:server = get(s:servers, l:buf_ft, 0)
    if type(l:server) != v:t_dict
        return
    endif

    call lsc#client#textDocument_didClose(l:server, l:buf_nr)
endfunction

" Plugins {{{
function! lsc#enable() abort
    if s:enabled
        return
    endif

    call s:register_events()
    let s:enabled = 1
endfunction

function! lsc#status() abort
    echo s:servers
endfunction

function! lsc#textDocument_codeLens() abort
    let l:buf_nr = bufnr('%')
    let l:buf_ft = lsc#utils#get_filetype(l:buf_nr)

    let l:server = get(s:servers, l:buf_ft, 0)
    if type(l:server) != v:t_dict
        return
    endif

    call lsc#client#textDocument_codeLens(l:server, l:buf_nr)
endfunction

" }}}

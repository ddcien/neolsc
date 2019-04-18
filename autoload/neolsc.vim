" vim: set foldmethod=marker foldlevel=0 nomodeline:

let s:_neolsc_global_init = 0
let s:_neolsc_white_list = {}
let s:_neolsc_black_list = []

function! s:on_text_document_did_open() abort
    let l:buf = nvim_get_current_buf()
    let l:ftp = nvim_buf_get_option(l:buf, 'filetype')
    if index(s:_neolsc_black_list, l:ftp) >= 0
        return
    endif

    let l:server_list = get(s:_neolsc_white_list, l:ftp)
    if empty(l:server_list)
        call add(s:_neolsc_black_list, l:ftp)
        return
    endif
    let l:server = get(g:neolsc_language_settings, l:ftp)
    if empty(l:server)
        let l:server = l:server_list[0]['name']
    endif

    if empty(neolsc#ui#general#get_server(l:server))
        call neolsc#ui#general#start(l:server, g:neolsc_server_commands[l:server])
    endif

    call neolsc#ui#workfile#add(l:buf, l:server)
    call neolsc#ui#textDocumentSynchronization#didOpen()

    augroup neolsc_buffer_events
        autocmd! * <buffer>
        autocmd CursorHold <buffer> call neolsc#ui#textDocument#documentHighlight()
        autocmd CursorMoved <buffer> call s:on_cursor_moved()
        autocmd InsertEnter <buffer> call s:on_insert_enter()
        autocmd InsertLeave <buffer> call s:on_insert_leave()
        " autocmd TextChangedI <buffer> call s:on_text_chande_i()
        " autocmd CursorMovedI <buffer> call s:on_cursor_moved_i()
        autocmd BufWipeout <buffer> call neolsc#ui#textDocumentSynchronization#didClose()
        autocmd TextChanged <buffer> call neolsc#ui#textDocumentSynchronization#didChange()
        autocmd BufWritePost <buffer> call neolsc#ui#textDocumentSynchronization#didSave()
    augroup end

endfunction

function! s:on_text_chande_i() abort
    let l:char = s:_get_current_character()
endfunction

function! s:on_cursor_moved_i() abort
    let l:char = s:_get_current_character()
endfunction

function! s:on_cursor_moved() abort
    call s:stop_cursor_moved_timer()
    let l:current_pos = getcurpos()[1:2]
    if !exists('s:last_pos') || l:current_pos != s:last_pos
        let s:last_pos = l:current_pos
        let s:cursor_moved_timer = timer_start(200, function('s:echo_diagnostics_under_cursor'))
    endif
endfunction

function! s:on_insert_enter() abort
    let l:ctx = neolsc#ui#workfile#get(bufnr('%'))
    call neolsc#ui#vtext#diagnostics_clear_all(l:ctx)
endfunction

function! s:on_insert_leave() abort
    let l:ctx = neolsc#ui#workfile#get(bufnr('%'))
    call neolsc#ui#textDocumentSynchronization#didChange()
    call neolsc#ui#vtext#diagnostics_show_line(l:ctx, line('.') - 1)
endfunction

function! s:echo_diagnostics_under_cursor(...) abort
    let l:ctx = neolsc#ui#workfile#get(bufnr('%'))

    call neolsc#ui#hover#clear()
    call neolsc#ui#vtext#diagnostics_clear_all(l:ctx)
    call neolsc#ui#vtext#diagnostics_show_line(l:ctx, line('.') - 1)
endfunction

function! s:stop_cursor_moved_timer() abort
    if exists('s:cursor_moved_timer')
        call timer_stop(s:cursor_moved_timer)
        unlet s:cursor_moved_timer
    endif
endfunction


function! s:_get_current_character() abort
    let l:line = nvim_get_current_line()
    if empty(l:line)
        return
    endif
    if mode() ==# 'i'
        let l:char = l:line[col('.') - 2]
    else
        let l:char = l:line[col('.') - 1]
    endif
    return l:char
endfunction

function! s:_text_changed_i() abort
    " let l:buf = nvim_get_current_buf()
    " let l:server = neolsc#ui#general#buf_to_server(l:buf)
    " let l:char = s:_get_current_character()
    " if index(l:server.capabilities_signatureHelp_triggerCharacters(), l:char) < 0
        " return
    " endif
    " call neolsc#ui#textDocument#signatureHelp()
endfunction

function! neolsc#global_init() abort
    if s:_neolsc_global_init
        return
    endif

    for [l:name, l:settings] in items(g:neolsc_server_commands)
        for l:ftp in get(l:settings, 'whitelist')
            if !has_key(s:_neolsc_white_list, l:ftp)
                let s:_neolsc_white_list[l:ftp] = []
            endif
            call add(s:_neolsc_white_list[l:ftp], {
                        \ 'name': l:name,
                        \ 'priority': get(l:settings, 'priority', 0)
                        \ })
        endfor

        if get(l:settings, 'auto_start')
            call neolsc#ui#general#start(l:name, l:settings)
        endif
    endfor

    for l:server_names in values(s:_neolsc_white_list)
        call sort(l:server_names, {a, b -> b['priority'] - a['priority']})
    endfor

    augroup neolsc_events
        autocmd!
        autocmd BufReadPost * call s:on_text_document_did_open()
    augroup end

    call _neolsc_init()
    let s:_neolsc_global_init = 1
endfunction

" public {{{
function! neolsc#start() abort
    call neolsc#global_init()
endfunction

function! neolsc#stop() abort
    for l:name in keys(g:neolsc_server_commands)
        call neolsc#ui#general#stop(l:name)
    endfor
    let s:_neolsc_global_init = 0
endfunction

function! neolsc#restart() abort
    call neolsc#stop()
    call neolsc#start()
endfunction

function! neolsc#status() abort
    for l:name in keys(g:neolsc_server_commands)
        call neolsc#ui#general#status(l:name)
    endfor
endfunction

function! neolsc#get_white_list() abort
    return s:_neolsc_white_list
endfunction
" }}}

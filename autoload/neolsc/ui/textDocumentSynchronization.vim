" vim: set foldmethod=marker foldlevel=0 nomodeline:

function! neolsc#ui#textDocumentSynchronization#didOpen() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    call neolsc#lsp#textDocumentSynchronization#didOpen(l:server, l:buf)
    call rpcnotify(g:neolsc_channel_id, 'neolsc_monitor_start', l:buf)
endfunction

function! s:_first(old, new)
    let l:l_old = len(a:old)
    let l:l_new = len(a:new)

    for l:lnum in range(0, l:l_old -1, 1)
        if l:lnum >= l:l_new ||  a:old[l:lnum] !=# a:new[l:lnum]
            return l:lnum
        endif
    endfor

    return l:lnum + 1
endfunction

function! s:_last(old, new, first_line)
    let l:l_old = len(a:old) - a:first_line
    let l:l_new = len(a:new)

    for l:lnum in range(-1, -l:l_old, -1)
        if l:lnum < -l:l_new ||  a:old[l:lnum] !=# a:new[l:lnum]
            return l:lnum
        endif
    endfor
    return l:lnum - 1
endfunction

function! s:_diff(old, new)
    let l:first_line = s:_first(a:old, a:new)
    let l:last_line = s:_last(a:old, a:new, l:first_line)
    let l:last_line_old = len(a:old) + l:last_line
    let l:last_line_new = len(a:new) + l:last_line

    let l:length = 0
    let l:text = ''

    for l:idx in range(l:first_line, l:last_line_old)
        let l:length += len(a:old[l:idx]) + 1
    endfor
    for l:idx in range(l:first_line, l:last_line_new)
        let l:text .= a:new[l:idx] . "\n"
    endfor

    return {
                \ 'text': l:text,
                \ 'rangeLength': l:length,
                \ 'range': {
                \     'start': {'line': l:first_line, 'character': 0},
                \     'end': {'line': l:last_line_old + 1, 'character': 0}
                \ }
                \ }
endfunction

function! s:_build_TextDocumentContentChangeEvent(sync_kind, old, new)
    if a:sync_kind == 0
        return v:null
    endif
    if a:sync_kind == 1
        return [{'text': join(a:new, "\n")}]
    endif
    if a:sync_kind == 2
        try
            return [s:_diff(a:old, a:new)]
        catch
            return [{'text': join(a:new, "\n")}]
        endtry
    endif
endfunction

function! neolsc#ui#textDocumentSynchronization#didChange() abort
    let l:buf = nvim_get_current_buf()
    call neolsc#ui#textDocumentSynchronization#didChangeBuf(l:buf)
endfunction

function! neolsc#ui#textDocumentSynchronization#didChangeBuf(buf) abort
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    if l:buf_ctx['_tick'] == nvim_buf_get_changedtick(a:buf)
        return
    endif

    let l:server = neolsc#ui#general#buf_to_server(a:buf)
    let l:sync_kind = l:server.capabilities_TextDocumentSync_change()

    let l:old = l:buf_ctx['_lines']
    let l:new = nvim_buf_get_lines(a:buf, 0, -1, v:true)
    let l:contentChanges = s:_build_TextDocumentContentChangeEvent(l:sync_kind, l:old, l:new)

    call neolsc#lsp#textDocumentSynchronization#didChange(l:server, a:buf, l:contentChanges)

    let l:buf_ctx['_tick'] = nvim_buf_get_changedtick(a:buf)
    let l:buf_ctx['_version'] += 1
    let l:buf_ctx['_lines'] = l:new
endfunction

function! neolsc#ui#textDocumentSynchronization#willSave(reason) abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    call neolsc#lsp#textDocumentSynchronization#willSave(l:server, l:buf, a:reason)
endfunction

function! neolsc#ui#textDocumentSynchronization#willSaveWaitUntil_handler(server, response) abort
    " TODO(Richard):
endfunction

function! neolsc#ui#textDocumentSynchronization#willSaveWaitUntil(reason) abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    call neolsc#lsp#textDocumentSynchronization#willSaveWaitUntil(l:server, l:buf)
endfunction

function! neolsc#ui#textDocumentSynchronization#didSave() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    call neolsc#lsp#textDocumentSynchronization#didSave(l:server, l:buf)
endfunction

function! neolsc#ui#textDocumentSynchronization#didClose() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    call rpcnotify(g:neolsc_channel_id, 'neolsc_monitor_stop', l:buf)
    call neolsc#lsp#textDocumentSynchronization#didClose(l:server, l:buf)
endfunction

" vim: set foldmethod=marker foldlevel=0 nomodeline:

function! neolsc#ui#textDocumentSynchronization#didOpen() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    call neolsc#lsp#textDocumentSynchronization#didOpen(l:server, l:buf)
endfunction

function! s:_build_TextDocumentContentChangeEvent(sync_kind, old, new) abort
    if a:sync_kind == 0
        return v:null
    endif
    if a:sync_kind == 1
        return [{'text': join(a:new, "\n") . "\n"}]
    endif
    if a:sync_kind == 2
        " TODO(Richard):
        return [{'text': join(a:new, "\n") . "\n"}]
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
    call neolsc#lsp#textDocumentSynchronization#didClose(l:server, l:buf)
endfunction

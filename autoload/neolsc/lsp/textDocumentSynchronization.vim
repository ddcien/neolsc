" vim: set foldmethod=marker foldlevel=0 nomodeline:

" params builders {{{
let s:TextDocumentSaveReason = {
            \ '1': 'Manual',
            \ '2': 'AfterDelay',
            \ '3': 'FocusOut',
            \ }

function! s:_build_DocumentUri(buf) abort
    return neolsc#utils#uri#buf_to_uri(a:buf)
endfunction

function! s:_build_TextDocumentIdentifier(buf) abort
    return {'uri': s:_build_DocumentUri(a:buf)}
endfunction

function! s:_build_TextDocumentItem(buf) abort
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    return {
                \ 'uri': s:_build_DocumentUri(a:buf),
                \ 'languageId': nvim_buf_get_option(a:buf, 'filetype'),
                \ 'version': l:buf_ctx['_version'],
                \ 'text': join(nvim_buf_get_lines(a:buf, 0, -1, v:true), "\n"),
                \ }
endfunction

function! s:_build_VersionedTextDocumentIdentifier(buf) abort
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    let l:ret = s:_build_TextDocumentIdentifier(a:buf)
    let l:ret['version'] = l:buf_ctx['_version']
    return l:ret
endfunction


function! s:_build_DidOpenTextDocumentParams(buf) abort
    return {
                \ 'textDocument': s:_build_TextDocumentItem(a:buf),
                \ }
endfunction

function! s:_build_DidChangeTextDocumentParams(buf, contentChanges) abort
    return {
                \ 'textDocument': s:_build_VersionedTextDocumentIdentifier(a:buf),
                \ 'contentChanges': a:contentChanges,
                \ }
endfunction

function! s:_build_WillSaveTextDocumentParams(buf, reason) abort
    return {
                \ 'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \ 'reason': a:reason
                \ }
endfunction

function! s:build_DidSaveTextDocumentParams(buf, inc_text) abort
    let l:ret = {
                \ 'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \ }
    if a:inc_text
        let l:ret['text'] = join(nvim_buf_get_lines(a:buf, 0, -1, v:true), "\n")
    endif
    return l:ret
endfunction

function! s:_build_DidCloseTextDocumentParams(buf) abort
    return {
                \ 'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \ }
endfunction
" }}}

" didOpen {{{
function! neolsc#lsp#textDocumentSynchronization#didOpen(server, buf) abort
    if !a:server.capabilities_TextDocumentSync_openClose()
        return
    endif
    let l:notification = {
                \ 'method': 'textDocument/didOpen',
                \ 'params': s:_build_DidOpenTextDocumentParams(a:buf)
                \ }
    call a:server.send_notification(l:notification)
endfunction
" }}}

" didChange {{{
function! neolsc#lsp#textDocumentSynchronization#didChange(server, buf, contentChanges) abort
    let l:notification = {
                \ 'method': 'textDocument/didChange',
                \ 'params': s:_build_DidChangeTextDocumentParams(a:buf, a:contentChanges)
                \ }
    call a:server.send_notification(l:notification)
endfunction
" }}}

" willSave {{{
function! neolsc#lsp#textDocumentSynchronization#willSave(server, buf, reason) abort
    if !a:server.capabilities_TextDocumentSync_willSave()
        return
    endif
    let l:notification = {
                \ 'method': 'textDocument/willSave',
                \ 'params': s:_build_WillSaveTextDocumentParams(a:buf, a:reason),
                \ }
    call a:server.send_notification(l:notification)
endfunction
" }}}

" willSaveWaitUntil {{{
function! neolsc#lsp#textDocumentSynchronization#willSaveWaitUntil(server, buf, reason) abort
    if !a:server.capabilities_TextDocumentSync_willSaveWaitUntil()
        return
    endif
    let l:request = {
                \ 'method': 'textDocument/willSaveWaitUntil',
                \ 'params': s:_build_WillSaveTextDocumentParams(a:buf, a:reason),
                \ }
    call a:server.send_request(l:request, function('neolsc#ui#textDocumentSynchronization#willSaveWaitUntil_handler'))
endfunction
" }}}

" didSave {{{
function! neolsc#lsp#textDocumentSynchronization#didSave(server, buf) abort
    if !a:server.capabilities_TextDocumentSync_save()
        return
    endif
    let l:inc_text = a:server.capabilities_TextDocumentSync_save_includeText()
    let l:notification = {
                \ 'method': 'textDocument/didSave',
                \ 'params': s:build_DidSaveTextDocumentParams(a:buf, l:inc_text),
                \ }
    call a:server.send_notification(l:notification)
endfunction
" }}}

" didClose {{{
function! neolsc#lsp#textDocumentSynchronization#didClose(server, buf) abort
    if !a:server.capabilities_TextDocumentSync_openClose()
        return
    endif
    let l:notification = {
                \ 'method': 'textDocument/didClose',
                \ 'params': s:_build_DidCloseTextDocumentParams(a:buf),
                \ }
    call a:server.send_notification(l:notification)
endfunction
" }}}


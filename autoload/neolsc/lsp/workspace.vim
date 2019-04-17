" vim: set foldmethod=marker foldlevel=0 nomodeline:


" params builders {{{
function! s:_build_WorkspaceFolder(name, path) abort
    return {
                \ 'name': a:name,
                \ 'uri': neolsc#utils#uri#path_to_uri(a:path),
                \ }
endfunction

function! s:_build_WorkspaceFoldersChangeEvent(added, removed) abort
    let l:ret = {'added': [], 'removed': []}
    for l:ws in a:added
        call add(l:ret['added'], s:_build_WorkspaceFolder(l:ws['name'], l:ws['path']))
    endfor
    for l:ws in a:removed
        call add(l:ret['removed'], s:_build_WorkspaceFolder(l:ws['name'], l:ws['path']))
    endfor
    return l:ret
endfunction

function! s:_build_DidChangeWorkspaceFoldersParams(added, removed) abort
    return {
                \ 'event': s:_build_WorkspaceFoldersChangeEvent(a:added, a:removed)
                \ }
endfunction

function! s:_build_DidChangeConfigurationParams(settings) abort
    return {'settings': a:settings}
endfunction

let s:FileChangeType = {
            \ '1': 'Created',
            \ '2': 'Changed',
            \ '3': 'Deleted',
            \}
function! s:_build_FileEvent(path, type)
    return {
                \ 'uri': neolsc#utils#uri#path_to_uri(a:path),
                \ 'type': a:type
                \ }
endfunction

function! s:_build_DidChangeWatchedFilesParams(changes) abort
    let l:ret = {'changes': []}
    for l:ch in a:changes
        call add(l:ret['changes'], s:_build_FileEvent(l:ch['path'], l:ch['event']))
    endfor
    return l:ret
endfunction

function! s:_build_WorkspaceSymbolParams(query)
    return {'query': a:query}
endfunction

function! s:_build_ExecuteCommandParams(command, arguments)
    return {'command': a:command, 'arguments': a:arguments}
endfunction
" }}}

" notification to server {{{
" didChangeConfiguration {{{
function! neolsc#lsp#workspace#didChangeConfiguration(server, settings)
    let l:notification = {
                \ 'method': 'workspace/didChangeConfiguration',
                \ 'params': s:_build_DidChangeConfigurationParams(a:settings)
                \ }
    call a:server.send_notification(l:notification)
endfunction
" }}}

" didChangeWorkspaceFolders {{{
function! neolsc#lsp#workspace#didChangeWorkspaceFolders(server, added, removed)
    let l:notification = {
                \ 'method': 'workspace/didChangeWorkspaceFolders',
                \ 'params': s:_build_DidChangeWorkspaceFoldersParams(a:added, a:removed)
                \ }
    call a:server.send_notification(l:notification)
endfunction
" }}}

" didChangeWatchedFiles {{{
function! neolsc#lsp#workspace#didChangeWatchedFiles(server, changes)
    let l:notification = {
                \ 'method': 'workspace/didChangeWatchedFiles',
                \ 'params': s:_build_DidChangeWatchedFilesParams(a:changes)
                \ }
    call a:server.send_notification(l:notification)
endfunction
" }}}
" }}}

" request to server {{{
" symbol {{{
function! neolsc#lsp#workspace#symbol(server, query, ctx)
    let l:request = {
                \ 'method': 'workspace/symbol',
                \ 'params': s:_build_WorkspaceSymbolParams(a:query),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#workspace#symbol_handler(server, response, a:ctx)})
endfunction
" }}}

" executeCommand {{{
function! neolsc#lsp#workspace#executeCommand(server, command)
    let l:request = {
                \ 'method': 'workspace/executeCommand',
                \ 'params': s:_build_ExecuteCommandParams(a:command['command'], a:command['arguments']),
                \ }
    call a:server.send_request(l:request, { server, response -> neolsc#ui#workspace#executeCommand_handler(server, response, a:command) })
endfunction
" }}}
" }}}


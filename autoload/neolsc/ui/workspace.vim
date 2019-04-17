" vim: set foldmethod=marker foldlevel=0 nomodeline:

" let s:_neolsc_current_workspace = {
            " \ 'server_list' : {'ccls': 1, 'cquery':1, 'pyls':1, 'rls':1},
            " \ 'folder_list' : {
            " \     'fold0': {
            " \         'uri': 'path0',
            " \         'server_list' : ['ccls', 'cquery', 'pyls', 'rls'],
            " \     },
            " \     'fold1': {
            " \         'uri': 'path1',
            " \         'server_list' : ['ccls', 'cquery', 'pyls', 'rls'],
            " \     },
            " \     'fold2': {
            " \         'uri': 'path2',
            " \         'server_list' : ['ccls', 'cquery', 'pyls', 'rls'],
            " \     },
            " \ }
            " \ }

let s:_neolsc_current_workspace = {
            \ 'server_list': {},
            \ 'folder_list': {},
            \ }

" notification to server {{{
function! neolsc#ui#workspace#configuration(server, configuration)
    if empty(a:configuration)
        return
    endif
    let l:server = neolsc#ui#general#get_server(a:server)
    call neolsc#lsp#workspace#didChangeConfiguration(l:server, a:configuration)
endfunction

function! neolsc#ui#workspace#addFolderLocal(name, path, server) abort
    let l:folder = get(s:_neolsc_current_workspace['folder_list'], a:name)
    if !empty(l:folder) && index(l:folder['server_list'], a:server) >= 0
        return 0
    endif

    if has_key(s:_neolsc_current_workspace['server_list'], a:server)
        let s:_neolsc_current_workspace['server_list'][a:server] += 1
    else
        let s:_neolsc_current_workspace['server_list'][a:server] = 1
    endif

    if empty(l:folder)
        let s:_neolsc_current_workspace['folder_list'][a:name] = {'uri':  neolsc#utils#uri#path_to_uri(a:path), 'server_list': [a:server]}
    else
        call add(s:_neolsc_current_workspace['folder_list'][a:name]['server_list'], a:server)
    endif
    return 1
endfunction

function! neolsc#ui#workspace#addFolder(name, path, server) abort
    if !neolsc#ui#workspace#addFolderLocal(a:name, a:path, a:server)
        return
    endif
    let l:server = neolsc#ui#general#get_server(a:server)
    if l:server.capabilities_workspace()
        call neolsc#lsp#workspace#didChangeWorkspaceFolders(l:server, [{'name': a:name, 'uri': neolsc#utils#uri#path_to_uri(a:path)}], [])
    endif
endfunction

function! neolsc#ui#workspace#remove(name) abort
    let l:folder = get(s:_neolsc_current_workspace['folder_list'], a:name)
    if empty(l:folder)
        return
    endif

    for l:server_name in l:folder['server_list']
        let s:_neolsc_current_workspace['server_list'][l:server_name] -= 1
        if s:_neolsc_current_workspace['server_list'][l:server_name] == 0
            call remove(s:_neolsc_current_workspace['server_list'], l:server_name)
        endif
        let l:server = neolsc#ui#general#get_server(l:server_name)
        if l:server.capabilities_workspace()
            call neolsc#lsp#workspace#didChangeWorkspaceFolders(l:server, [], [{'name': a:name, 'uri': l:folder['uri']}])
        endif
    endfor

    call remove(s:_neolsc_current_workspace['folder_list'], a:name)
endfunction

" 1: 'Created',
" 2: 'Changed',
" 3: 'Deleted',
function! neolsc#ui#workspace#file_create(path) abort
    let l:server = neolsc#ui#general#path_to_server(a:path)
    if l:server.capabilities_workspace_changeNotifications()
        call neolsc#lsp#workspace#didChangeWatchedFiles(l:server, [{'uri': neolsc#utils#uri#path_to_uri(a:path), 'event': 1}])
    endif
endfunction

function! neolsc#ui#workspace#file_change(path) abort
    let l:server = neolsc#ui#general#path_to_server(a:path)
    if l:server.capabilities_workspace_changeNotifications()
        call neolsc#lsp#workspace#didChangeWatchedFiles(l:server, [{'uri': neolsc#utils#uri#path_to_uri(a:path), 'event': 2}])
    endif
endfunction

function! neolsc#ui#workspace#file_delete(path) abort
    let l:server = neolsc#ui#general#path_to_server(a:path)
    if l:server.capabilities_workspace_changeNotifications()
        call neolsc#lsp#workspace#didChangeWatchedFiles(l:server, [{'uri': neolsc#utils#uri#path_to_uri(a:path), 'event': 3}])
    endif
endfunction
" }}}

" request to server {{{
" symbol {{{
function! neolsc#ui#workspace#symbol_handler(server, response, ctx)
    let a:ctx['server_list'][a:server] = get(a:response, 'result', [])
    let a:ctx['server_count'] -= 1

    if a:ctx['server_count'] > 0
        return
    endif

    call neolsc#ui#symbol#workspace_symbol_handler(a:ctx)
endfunction

function! neolsc#ui#workspace#symbol()
    let l:query = input('query >', expand('<cword>'))
    let l:ctx = {'server_count': 0, 'server_list': {}}
    for l:server_name in keys(s:_neolsc_current_workspace['server_list'])
        let l:server = neolsc#ui#general#get_server(l:server_name)
        if l:server.capabilities_workspaceSymbol()
            let l:ctx['server_count'] += 1
            let l:ctx['server_list'][l:server_name] = []
            call neolsc#lsp#workspace#symbol(l:server, l:query, l:ctx)
        endif
    endfor
endfunction
" }}}

" executeCommand {{{
let s:_neolsc_command = {}

function! neolsc#ui#workspace#executeCommand_handler(server, response, command)
    if has_key(s:_neolsc_command, a:command['command'])
        call s:_neolsc_command[a:command['command']](a:server, a:response, a:command)
    endif
endfunction

function! neolsc#ui#workspace#executeCommand(server, command)
    let l:server = neolsc#ui#general#get_server(a:server)
    call neolsc#lsp#workspace#executeCommand(l:server, a:command)
endfunction

function! neolsc#ui#workspace#executeCommandRegister(command, callback)
    if type(a:callback) == v:t_func
        let s:_neolsc_command[a:command] = a:callback
    endif
endfunction
" }}}
" }}}

" request from server {{{
function! neolsc#ui#workspace#workspaceFolders_handler(server, request)
    let l:result = []
    for [l:name, l:folder] in items(s:_neolsc_current_workspace['folder_list'])
        let l:server_list = l:folder['server_list']
        if index(l:server_list, a:server) >= 0
            call add(l:result, {'name': l:name, 'uri': neolsc#utils#uri#path_to_uri(l:folder['path'])})
        endif
    endfor
    return l:result
endfunction

function! neolsc#ui#workspace#configuration_handler(server, request)
    " TODO(Richard):
    return {'error': {'code': -32001, 'message': 'Not implemented yet!'}}
endfunction

function! neolsc#ui#workspace#applyEdit_handler(server, request)
    " TODO(Richard):
    return {'error': {'code': -32001, 'message': 'Not implemented yet!'}}
endfunction
" }}}

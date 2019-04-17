" vim: set foldmethod=marker foldlevel=0 nomodeline:

let s:_neolsc_lsp_server_list = {}
" Private {{{
let s:ErrorCodes = {
            \ 'ParseError': -32700,
            \ 'InvalidRequest': -32600,
            \ 'MethodNotFound': -32601,
            \ 'InvalidParams': -32602,
            \ 'InternalError': -32603,
            \ 'serverErrorStart': -32099,
            \ 'serverErrorEnd': -32000,
            \ 'ServerNotInitialized': -32002,
            \ 'UnknownErrorCode': -32001,
            \ 'RequestCancelled': -32800,
            \ 'ContentModified': -32801,
            \ }

let s:server = {
            \ '_jobid' : -1,
            \ '_name' : '',
            \ '_initialized': v:false,
            \ '_capabilities': {},
            \ '_context': {
            \     'request_id' : 1,
            \     'data_buf': {'data': '', 'length': -1, 'header_length': -1},
            \ },
            \ '_notification_hooks': {},
            \ '_request_hooks': {},
            \ '_out_request_hooks':{},
            \ }

function! s:get_content_length(headers) abort
    for l:header in split(a:headers, "\r\n")
        let l:kvp = split(l:header, ':')
        if len(l:kvp) == 2
            if l:kvp[0] =~? '^Content-Length'
                return str2nr(l:kvp[1], 10)
            endif
        endif
    endfor
    return -1
endfunction

function! s:server.on_stdout(job_id, data, event) abort
    let l:ctx = self._context.data_buf

    let l:ctx['data'] = join([l:ctx['data'] . a:data[0]] + a:data[1:], "\n")

    while strlen(l:ctx['data']) > 40
        if l:ctx['length'] < 0
            let l:header_end_index = stridx(l:ctx['data'], "\r\n\r\n")
            if l:header_end_index < 0
                return
            endif
            let l:ctx['header_length'] = l:header_end_index + 4
            let l:ctx['length'] = l:header_end_index + 4 + s:get_content_length(l:ctx['data'][:l:header_end_index - 1])
        endif

        if l:ctx['length'] < 0
            return
        endif

        if strlen(l:ctx['data']) < l:ctx['length']
            return
        endif

        try
            let l:response = json_decode(l:ctx['data'][l:ctx['header_length'] : l:ctx['length'] - 1])
        catch
        finally
            let l:ctx['data'] = l:ctx['data'][l:ctx['length'] :]
            let l:ctx['length'] = -1
            let l:ctx['header_length'] = -1
        endtry
        if type(l:response) == v:t_dict
            call self.response_handler(s:_neolsc_lsp_server_list[a:job_id], l:response)
        endif
    endwhile
endfunction

function! s:server.on_stderr(job_id, data, event) abort
endfunction

function! s:server.on_exit(job_id, data, event) abort
    try
        call chanclose(self._jobid)
    finally
        call remove(s:_neolsc_lsp_server_list, self._jobid)
        let self._jobid = -1
    endtry
endfunction

function! s:server.response_handler(server, response) abort
    if has_key(a:response, 'method') && has_key(a:response, 'id')
        " request
        let l:request_id = a:response['id']
        let l:ret = {'id': l:request_id}

        if !self.is_initialized()
            let l:ret['error'] = {
                        \ 'code': s:ErrorCodes['ServerNotInitialized'],
                        \ 'message': 'ServerNotInitialized',
                        \ }
            call self.send_response(l:ret)
            return
        endif

        let l:request_method = a:response['method']
        if !has_key(self._request_hooks, l:request_method)
            let l:ret['error'] = {
                        \ 'code': s:ErrorCodes['MethodNotFound'],
                        \ 'message': 'MethodNotFound',
                        \ }
            call self.send_response(l:ret)
            return
        endif

        try
            call extend(l:ret, self._request_hooks[l:request_method](a:server, a:response))
        catch
            let l:ret['error'] = {
                        \ 'code': s:ErrorCodes['UnknownErrorCode'],
                        \ 'message': 'UnknownErrorCode',
                        \ }
        finally
            call self.send_response(l:ret)
        endtry
    elseif has_key(a:response, 'method')
        " notification
        call writefile([json_encode({'time':strftime('%c') ,'log':a:response})], '/tmp/666.txt', 'a')
        let l:request_method = a:response['method']
        if has_key(self._notification_hooks, l:request_method)
            try
                call self._notification_hooks[l:request_method](a:server, a:response)
            endtry
        endif
    elseif has_key(a:response, 'id')
        " response
        let l:request_id = a:response['id']
        if has_key(self._out_request_hooks, l:request_id)
            try
                call self._out_request_hooks[l:request_id](a:server, a:response)
            finally
                call remove(self._out_request_hooks, l:request_id)
            endtry
        endif
    endif
endfunction

function! s:server.send(data, ...) abort
    call extend(a:data, {'jsonrpc': '2.0'})

    let l:content = json_encode(a:data)
    let l:data = 'Content-Length: ' . string(strlen(l:content)) . "\r\n\r\n" . l:content

    call chansend(self._jobid, l:data)
    if a:0 > 0 && type(a:1) == v:t_func
        call a:1()
    endif
endfunction

function! s:server.send_response(response) abort
    call assert_true(has_key(a:response, 'id'))
    call assert_true(has_key(a:response, 'result') || has_key(a:response, 'error'))
    call self.send(a:response)
endfunction

function! s:server.send_notification(notification, ...) abort
    call assert_true(!has_key(a:notification, 'id'))
    call assert_true(has_key(a:notification, 'method'))
    call self.send(a:notification)
endfunction

function! s:server.send_request(request, on_response, ...) abort
    call assert_true(has_key(a:request, 'method'))

    let a:request['id'] = self._context.request_id

    let self._context.request_id += 1
    if type(a:on_response) == v:t_func
        let self._out_request_hooks[a:request.id] = a:on_response
    endif

    call self.send(a:request)
endfunction

function! s:server.send_request_sync(request, on_response) abort
    call self.send_request(a:request, a:on_response)
    while has_key(self._out_request_hooks, a:request.id)
        sleep 10m
    endwhile
endfunction

function! s:server.register_request_hook(method, on_request) abort
    if type(a:on_request) == v:t_func
        let self._request_hooks[a:method] = a:on_request
    endif
endfunction

function! s:server.register_notification_hook(method, on_notification) abort
    if type(a:on_notification) == v:t_func
        let self._notification_hooks[a:method] = a:on_notification
    endif
endfunction

function! s:server.is_alive() abort
    return self._jobid > 0
endfunction

function! s:server.is_initialized() abort
    return self._jobid > 0 && self._initialized
endfunction

function! s:server._handle_initialize(server, response) abort
    let l:result = get(a:response, 'result')
    if empty(l:result)
        let self._initialized = v:false
        let self._capabilities = {}
        return
    endif
    let self._initialized = v:true
    let self._capabilities = l:result['capabilities']
endfunction

function! s:server.initialize(params) abort
    if !self.is_alive()
        return
    endif

    call self.send_request_sync(
                \ {'method': 'initialize', 'params': a:params},
                \ {server, response -> self._handle_initialize(server, response)}
                \ )
    call self.send_notification({'method': 'initialized', 'params': {}})
endfunction


function! s:server.shutdown() abort
    if !self.is_alive()
        return
    endif

    for l:id in keys(self._out_request_hooks)
        call self.send_notification(
                    \ {'method': '$/cancelRequest', 'params': {'id': l:id}}
                    \ )
    endfor

    let l:_to = 20
    while !empty(self._out_request_hooks) && l:_to > 0
        sleep 10ms
        let l:_to -= 1
    endwhile

    v:t_dict
    call self.send_request_sync(
                \ {'method': 'shutdown'},
                \ v:null
                \ )

    call self.send_notification({'method': 'exit'})
    let l:_to = 20
    while self.is_alive() && l:_to > 0
        sleep 10ms
        let l:_to -= 1
    endwhile

    if self.is_alive()
        call chanclose(self._jobid)
    endif
endfunction
" }}}

" capabilities {{{
" common {{{
function! s:server.capabilities_hover() abort
    return get(self._capabilities, 'hoverProvider', v:false)
endfunction

function! s:server.capabilities_definition() abort
    return get(self._capabilities, 'definitionProvider', v:false)
endfunction

function! s:server.capabilities_references() abort
    return get(self._capabilities, 'referencesProvider', v:false)
endfunction

function! s:server.capabilities_documentHighlight() abort
    return get(self._capabilities, 'documentHighlightProvider', v:false)
endfunction

function! s:server.capabilities_documentSymbol() abort
    return get(self._capabilities, 'documentSymbolProvider', v:false)
endfunction

function! s:server.capabilities_workspaceSymbol() abort
    return get(self._capabilities, 'workspaceSymbolProvider', v:false)
endfunction

function! s:server.capabilities_documentFormatting() abort
    return get(self._capabilities, 'documentFormattingProvider', v:false)
endfunction

function! s:server.capabilities_documentRangeFormatting() abort
    return get(self._capabilities, 'documentRangeFormattingProvider', v:false)
endfunction

function! s:server.capabilities_typeDefinition() abort
    return get(self._capabilities, 'typeDefinitionProvider', v:false)
endfunction

function! s:server.capabilities_implementation() abort
    return get(self._capabilities, 'implementationProvider', v:false)
endfunction

function! s:server.capabilities_declaration() abort
    return get(self._capabilities, 'declarationProvider', v:false)
endfunction

function! s:server.capabilities_foldingRange() abort
    return get(self._capabilities, 'foldingRangeProvider', v:false)
endfunction

function! s:server.capabilities_color() abort
    return get(self._capabilities, 'colorProvider', v:false)
endfunction
" }}}

" textDocumentSync {{{
function! s:server.capabilities_TextDocumentSync_change() abort
    let l:provider = get(self._capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? l:provider : get(l:provider, 'change', 0)
endfunction

function! s:server.capabilities_TextDocumentSync_openClose() abort
    let l:provider = get(self._capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:true : get(l:provider, 'openClose', v:false)
endfunction

function! s:server.capabilities_TextDocumentSync_willSave() abort
    let l:provider = get(self._capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:false : get(l:provider, 'willSave', v:false)
endfunction

function! s:server.capabilities_TextDocumentSync_willSaveWaitUntil() abort
    let l:provider = get(self._capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:false : get(l:provider, 'willSaveWaitUntil', v:false)
endfunction

function! s:server.capabilities_TextDocumentSync_save() abort
    let l:provider = get(self._capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:true : has_key(l:provider, 'save')
endfunction

function! s:server.capabilities_TextDocumentSync_save_includeText() abort
    let l:provider = get(self._capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:false : get(get(l:provider, 'save', {}), 'includeText', v:false)
endfunction
" }}}

" completion {{{
function! s:server.capabilities_completion() abort
    return has_key(self._capabilities, 'completionProvider')
endfunction

function! s:server.capabilities_completion_resolve() abort
    let l:provider = get(self._capabilities, 'completionProvider', {})
    return get(l:provider, 'resolveProvider', v:false)
endfunction

function! s:server.capabilities_completion_triggerCharacters() abort
    let l:provider = get(self._capabilities, 'completionProvider', {})
    return get(l:provider, 'triggerCharacters', [])
endfunction
" }}}

" SignatureHelpOptions {{{
function! s:server.capabilities_signatureHelp() abort
    return has_key(self._capabilities, 'signatureHelpProvider')
endfunction

function! s:server.capabilities_signatureHelp_triggerCharacters() abort
    let l:provider = get(self._capabilities, 'signatureHelpProvider', {})
    return get(l:provider, 'triggerCharacters', [])
endfunction
" }}}

" codeActionProvider {{{
function! s:server.capabilities_codeAction() abort
    let l:provider = get(self._capabilities, 'codeActionProvider', v:false)
    return type(l:provider) ==# v:t_dict || l:provider ==# v:true
endfunction

function! s:server.capabilities_codeAction_codeActionKinds() abort
    let l:provider = get(self._capabilities, 'codeActionProvider', v:false)
    return type(l:provider) != v:t_dict ? [] : get(l:provider, 'codeActionKinds', [])
endfunction
" }}}

" codeLens {{{
function! s:server.capabilities_codeLens() abort
    return has_key(self._capabilities, 'codeLensProvider')
endfunction

function! s:server.capabilities_codeLens_resolve() abort
    let l:provider = get(self._capabilities, 'codeLensProvider', {})
    return get(l:provider, 'resolveProvider', v:false)
endfunction
" }}}

" documentLink {{{
function! s:server.capabilities_documentLink() abort
    return has_key(self._capabilities, 'documentLinkProvider')
endfunction

function! s:server.capabilities_documentLink_resolve() abort
    let l:provider = get(self._capabilities, 'documentLinkProvider', {})
    return get(l:provider, 'resolveProvider', v:false)
endfunction
"}}}

" renameProvider {{{
function! s:server.capabilities_rename() abort
    let l:provider = get(self._capabilities, 'renameProvider', v:false)
    return type(l:provider) ==# v:t_dict || l:provider ==# v:true
endfunction

function! s:server.capabilities_rename_prepare() abort
    let l:provider = get(self._capabilities, 'renameProvider', v:false)
    return type(l:provider) != v:t_dict ? v:false : get(l:provider, 'prepareProvider', v:false)
endfunction
" }}}

" documentOnTypeFormattingProvider {{{
function! s:server.capabilities_documentOnTypeFormatting() abort
    return has_key(self._capabilities, 'documentOnTypeFormattingProvider')
endfunction

function! s:server.capabilities_documentOnTypeFormatting_triggerCharacters() abort
    let l:provider = get(self._capabilities, 'documentOnTypeFormattingProvider', {})
    if empty(l:provider)
        return []
    endif
    let l:triggers = [get(l:provider, 'firstTriggerCharacter')]
    call extend(l:triggers, get(l:provider, 'moreTriggerCharacter', []))
    return l:triggers
endfunction
" }}}

" executeCommandProvider {{{
function! s:server.capabilities_executeCommand() abort
    let l:provider = get(self._capabilities, 'executeCommandProvider', {})
    return empty(l:provider) ? [] : get(l:provider, 'commands', [])
endfunction
" }}}

" workspace {{{
function! s:server.capabilities_workspace() abort
    let l:workspace = get(self._capabilities, 'workspace')
    if empty(l:workspace)
        return v:false
    endif
    return get(l:workspace, 'supported', v:false)
endfunction

function! s:server.capabilities_workspace_changeNotifications() abort
    let l:workspace = get(self._capabilities, 'workspace')
    if empty(l:workspace)
        return v:false
    endif
    return get(l:workspace, 'changeNotifications', v:false)
endfunction
" }}}
" }}}

" PublicAPIs {{{
function! neolsc#lsp#server#start(name, command) abort
    let l:server = deepcopy(s:server)
    let l:server._jobid = jobstart(a:command, l:server)
    if l:server._jobid < 0
        unlet l:server
        return
    endif

    let l:server._command = a:command
    let l:server._name = a:name
    let s:_neolsc_lsp_server_list[l:server._jobid] = a:name

    return l:server
endfunction
" }}}


" vim: set foldmethod=marker foldlevel=0 nomodeline:

" Private {{{
let s:client = {
            \ '_jobid' : -1,
            \ '_context': {
            \     'request_id' : 1,
            \     'data_buf': {'data': '', 'length': -1, 'header_length': -1},
            \     'diagnostics': {},
            \     'initialized': 0,
            \     '_file_handlers': {},
            \ },
            \ '_notification_hooks': {},
            \ '_request_hooks':{},
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

function s:client.on_stdout(job_id, data, event)
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

        let l:response = json_decode(l:ctx['data'][l:ctx['header_length'] : l:ctx['length'] - 1])
        call self.response_handler(l:response)
        let l:ctx['data'] = l:ctx['data'][l:ctx['length'] :]
        let l:ctx['length'] = -1
        let l:ctx['header_length'] = -1
    endwhile
endfunction

function s:client.on_stderr(job_id, data, event)
    call lsc#log#log({'ERROR': [a:data, a:event]})
endfunction

function s:client.on_exit(job_id, data, event)
    call lsc#log#log({'EXIT': [a:data, a:event]})
endfunction

function s:client.response_handler(response)
    if has_key(a:response, 'method')
        let l:request_method = a:response['method']
        if has_key(a:response, 'id')
            call lsc#log#verbose({'dir': 'S->C', 'request': a:response})
        else
            call lsc#log#verbose({'dir': 'S->C', 'notification': a:response})
        endif
        if has_key(self._notification_hooks, l:request_method)
            call self._notification_hooks[l:request_method](a:response)
        else
            call lsc#log#verbose({'dir': 'S->C', 'request or notification IGNORED': a:response})
        endif
    else
        let l:request_id = a:response['id']
        if has_key(self._request_hooks, l:request_id)
            call lsc#log#verbose({'dir': 'S->C', 'response': a:response})
            try
                call self._request_hooks[l:request_id](a:response)
            catch /.*/
                echom printf('EXCEPTION!!!: %s', json_encode({
                            \ 'id': l:request_id,
                            \ 'exception': v:exception
                            \ }))
                call lsc#log#log({'dir': 'S->C', 'response ERROR': a:response})
            endtry
            call remove(self._request_hooks, l:request_id)
        else
            call lsc#log#verbose({'dir': 'S->C', 'response IGNORED': a:response})
        endif
    endif
endfunction

function! s:client.send_notification(notification)
    call extend(a:notification, {'jsonrpc': '2.0'})

    let l:content = json_encode(a:notification)
    let l:data = 'Content-Length: ' . string(strlen(l:content)) . "\r\n\r\n" . l:content

    call lsc#log#verbose({'dir': 'C->S', 'notification': a:notification})
    call chansend(self._jobid, l:data)
endfunction

function! s:client.send_request(request, callback)
    call extend(a:request, {'jsonrpc': '2.0', 'id': self._context.request_id})
    let l:content = json_encode(a:request)
    let l:data = 'Content-Length: ' . string(strlen(l:content)) . "\r\n\r\n" . l:content

    let self._request_hooks[a:request.id] = a:callback
    let self._context.request_id += 1

    call lsc#log#verbose({'dir': 'C->S', 'request': a:request})
    call chansend(self._jobid, l:data)
endfunction

function! s:client.send_request_sync(request, callback)
    call self.send_request(a:request, a:callback)
    while has_key(self._request_hooks, a:request.id)
        sleep 10m
    endwhile
endfunction

function! s:client.send_request_batch(requests, callback)
    for l:request in a:requests
        call self.send_request(l:request, a:callback)
    endfor
endfunction

function! s:client.send_request_batch_sync(requests, callback)
    let l:ctx = {'callback': a:callback, 'ret': []}
    function l:ctx.funcall(res) dict
        call self.callback(a:res)
    endfunction
    call self.send_request_batch(a:requests, {response -> a:callback(response)})
endfunction

function! s:client.register_notification_hook(method, hook)
    if type(a:hook) == v:t_func
        let self._notification_hooks[a:method] = a:hook
    endif
endfunction

function! s:client.initialized()
    return self._context.initialized
endfunction
" }}}

" general {{{
" launch :done {{{
function s:client.launch(command)
    let l:client = deepcopy(s:client)
    let l:client._command = a:command
    let l:client._jobid = jobstart(l:client._command, l:client)
    if l:client._jobid <= 0
        return 0
    endif
    return l:client
endfunction
" }}}
" initialize : done {{{
function! s:client.handle_initialize(workspace_settings, buf, response)
    call extend(self, a:response.result)
    call self.send_notification({'method': 'initialized', 'params': {}})
    let self._context.initialized = 1
    call l:self.register_notification_hook(
                \ '$/cancelRequest',
                \ {notification -> self.handle_cancelRequest(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'window/showMessage',
                \ {notification -> self.handle_window_showMessage(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'window/logMessage',
                \ {notification -> self.handle_window_logMessage(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'window/showMessageRequest',
                \ {notification -> self.handle_window_showMessageRequest(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'telemetry/event',
                \ {notification -> self.handle_telemetry_event(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'client/registerCapability',
                \ {notification -> self.handle_client_registerCapability(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'client/unregisterCapability',
                \ {notification -> self.handle_client_unregisterCapability(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'workspace/workspaceFolders',
                \ {notification -> self.handle_workspace_workspaceFolders(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'workspace/configuration',
                \ {notification -> self.handle_workspace_configuration(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'workspace/applyEdit',
                \ {notification -> self.handle_workspace_applyEdit(notification)}
                \ )
    call l:self.register_notification_hook(
                \ 'textDocument/publishDiagnostics',
                \ {notification -> self.handle_textDocument_publishDiagnostics(notification)}
                \ )
    call l:self.register_notification_hook(
                \ '$ccls/publishSemanticHighlight',
                \ {notification -> self.handle_ccls_publishSemanticHighlight(notification)}
                \ )
    call l:self.register_notification_hook(
                \ '$ccls/publishSkippedRanges',
                \ {notification -> self.handle_ccls_publishSkippedRanges(notification)}
                \ )
    if !empty(a:workspace_settings)
        call self.send_notification({
                    \ 'method': 'workspace/didChangeConfiguration',
                    \ 'params': {
                    \     'settings': a:workspace_settings
                    \     }
                    \ })
    endif
    call self.textDocument_didOpen(a:buf)
    call self.textDocument_didChange(a:buf)
endfunction

let s:current_dir = fnamemodify(resolve(expand('<sfile>')), ':h') . '/'
let s:init_param = json_decode(readfile(s:current_dir . 'init/InitializeParams.json'))
let s:init_param.capabilities.workspace = json_decode(readfile(s:current_dir . 'init/WorkspaceClientCapabilities.json'))
let s:init_param.capabilities.textDocument = json_decode(readfile(s:current_dir . 'init/TextDocumentClientCapabilities.json'))

function! s:client.load_init_params(root_dir, init_opts) abort
    let l:param = deepcopy(s:init_param)

    let l:param.processId = getpid()
    let l:param.rootPath = a:root_dir[0]
    let l:param.rootUri = lsc#uri#path_to_uri(a:root_dir[0])

    call extend(l:param.initializationOptions, a:init_opts)
    return l:param
endfunction

function! s:client.initialize(root_dir, init_opts, workspace_settings, buf)
    let l:params = self.load_init_params([a:root_dir], a:init_opts)
    call self.send_request(
                \ {
                \     'method': 'initialize',
                \     'params': l:params,
                \ },
                \ {response -> self.handle_initialize(a:workspace_settings, a:buf, response)}
                \ )
endfunction
" }}}
" shutdown and exit : done {{{
function! s:client.handle_shutdown(response)
    call self.send_notification({'method': 'exit'})
    let self._context.initialized = 0
endfunction

function! s:client.shutdown()
    if !self.initialized()
        return
    endif
    call self.send_request(
                \ {
                \     'method': 'shutdown'
                \ },
                \ {response -> self.handle_shutdown(response)}
                \ )
endfunction
" }}}
" $/cancelRequest {{{
function! s:client.handle_cancelRequest(notification)
    call assert_equal('$/cancelRequest', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
    let l:request_id = get(l:params, 'id')
endfunction

function! s:client.cancelRequest(request_id)
    if !self.initialized()
        return
    endif
    if has_key(self._request_hooks, a:request_id)
        call self.send_notification({'method': '$/cancelRequest', 'params' : {'id': a:request_id}})
    endif
endfunction
" }}}
" }}}

" window {{{
" showMessage {{{
function! s:client.handle_window_showMessage(notification)
    call assert_equal('window/showMessage', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
endfunction
" }}}
" logMessage {{{
function! s:client.handle_window_logMessage(notification)
    call assert_equal('window/logMessage', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
endfunction
" }}}
" showMessageRequest {{{
function! s:client.handle_window_showMessageRequest(notification)
    call assert_equal('window/showMessageRequest', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
    " TODO(Richard):
    call self.send_notification({'id': a:notification.id, 'result': v:null})
endfunction
" }}}
" }}}

" Telemetry {{{
function! s:client.handle_telemetry_event(notification)
    call assert_equal('telemetry/event', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
    " TODO(Richard):
endfunction
" }}}

" client {{{
function! s:client.handle_client_registerCapability(notification)
    call assert_equal('client/registerCapability', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
    " TODO(Richard):
    call self.send_notification({'id': a:notification.id, 'result': {}})
endfunction

function! s:client.handle_client_unregisterCapability(notification)
    call assert_equal('client/unregisterCapability', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
    " TODO(Richard):
    call self.send_notification({'id': a:notification.id, 'result': {}})
endfunction
" }}}

" workspace {{{
" workspaceFolders {{{
function! s:client.handle_workspace_workspaceFolders(notification)
    call assert_equal('workspace/workspaceFolders', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
    " TODO(Richard):
    call self.send_notification({'id': a:notification.id, 'result': {}})
endfunction
" }}}
" didChangeWorkspaceFolders {{{
function! s:client.workspace_didChangeWorkspaceFolders(added, removed) abort
    if !self.initialized()
        return
    endif
    call self.send_notification({
                \ 'method': 'workspace/didChangeWorkspaceFolders',
                \ 'params': {
                \     'event': {
                \         'added': a:added,
                \         'removed': a:removed,
                \     }
                \ }
                \ })
endfunction
" }}}
" didChangeConfiguration {{{
function! s:client.workspace_didChangeConfiguration(settings) abort
    if !self.initialized()
        return
    endif

    call self.send_notification({
                \ 'method': 'workspace/didChangeConfiguration',
                \ 'params': {
                \     'settings': a:settings
                \     }
                \ })
endfunction
" }}}
" configuration {{{
function! s:client.handle_workspace_configuration(notification)
    call assert_equal('workspace/configuration', get(a:notification, 'method'))
    let l:params = get(a:notification, 'params', {})
    " TODO(Richard):
    call self.send_notification({'id': a:notification.id, 'result': {}})
endfunction
" }}}
" didChangeWatchedFiles {{{
function! s:client.workspace_didChangeWatchedFiles(events) abort
    if !self.initialized()
        return
    endif

    call self.send_notification({
                \ 'method': 'workspace/didChangeWatchedFiles',
                \ 'params': {
                \     'changes': a:events
                \     }
                \ })
endfunction
" }}}
" symbol : done {{{
function! s:client.handle_workspace_symbol(response)
    call lsc#symbols#handle_symbols(-1, a:response)
endfunction

function! s:client.workspace_symbol(query) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'workspaceSymbolProvider', v:false)
        return
    endif

    call self.send_request({
                \ 'method': 'workspace/symbol',
                \ 'params': {
                \     'query': a:query
                \     }
                \ },
                \ {response -> self.handle_workspace_symbol(response)}
                \ )
endfunction
" }}}
" executeCommand {{{
function! s:client.handle_workspace_executeCommand(response)
    " TODO(Richard):
endfunction

function! s:client.workspace_executeCommand(command, arguments) abort
    if !self.initialized()
        return
    endif

    call self.send_request({
                \ 'method': 'workspace/executeCommand',
                \ 'params': {
                \     'command': a:command,
                \     'arguments': a:arguments
                \     }
                \ },
                \ {response -> self.handle_workspace_executeCommand(response)}
                \ )
endfunction
" }}}
" applyEdit : done : never tested {{{
function! s:client.handle_workspace_applyEdit(notification)
    let l:params = get(a:notification, 'params', {})
    if empty(l:params)
        return
    endif
    call lsc#workspaceedit#handle_WorkspaceEdit(l:params['edit'])
    call self.send_notification({'id': a:notification.id, 'result': {'applied': v:true}})
endfunction
" }}}
" }}}

" textSynchronization {{{
" didOpen : done {{{
function! s:client.textDocument_didOpen(buf) abort
    if !self.initialized()
        return
    endif
    let l:uri = lsc#utils#get_buffer_uri(a:buf)
    if empty(l:uri)
        return
    endif

    let l:fh = get(self._context._file_handlers, l:uri)
    if empty(l:fh)
        let l:fh = lsc#file#new(a:buf)
        let self._context._file_handlers[l:uri] = l:fh
    endif

    if l:fh._buf < 0
        let l:fh._buf = a:buf
        let l:fh._tick = getbufvar(a:buf, 'changedtick')
    endif

    call self.send_notification({
                \ 'method': 'textDocument/didOpen',
                \ 'params': {
                \     'textDocument': lsc#lsp#get_TextDocumentItem(a:buf, l:fh._ver)
                \ }
                \ })
    if get(self._settings, 'auto_codeLens') > 0
        call self.textDocument_codeLens(a:buf)
    endif
    if get(self._settings, 'auto_documentlink') > 0
        call self.textDocument_documentLink(a:buf)
    endif

endfunction
" }}}
" didChange : done {{{
function! s:client.textDocument_didChange(buf) abort
    if !self.initialized()
        return
    endif
    let l:uri = lsc#utils#get_buffer_uri(a:buf)
    if empty(l:uri)
        return
    endif
    let l:fh = self._context._file_handlers[l:uri]
    let l:changed_tick = getbufvar(a:buf, 'changedtick')

    if l:fh['_tick'] == l:changed_tick
        return
    endif

    let l:fh['_tick'] = l:changed_tick
    let l:fh['_ver'] += 1

    call self.send_notification({
                \ 'method': 'textDocument/didChange',
                \ 'params': {
                \     'textDocument': lsc#lsp#get_VersionedTextDocumentIdentifier(a:buf, l:fh._ver),
                \     'contentChanges': [{'text': lsc#lsp#get_textDocumentText(a:buf)}],
                \ }
                \ })

    if get(self._settings, 'auto_codeLens') == 2
        call self.textDocument_codeLens(a:buf)
    endif
    if get(self._settings, 'auto_documentlink') == 2
        call self.textDocument_documentLink(a:buf)
    endif
endfunction
" }}}
" willSave {{{
function! s:client.textDocument_willSave(buf, reason) abort
    if !self.initialized()
        return
    endif
    call self.send_notification({
                \ 'method': 'textDocument/willSave',
                \ 'params': {
                \     'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \     'reason': a:reason,
                \ }
                \ })
endfunction
" }}}
" willSaveWaitUntil {{{
function! s:client.handle_textDocument_willSaveWaitUntil(response) abort
    "TODO(Richard):
endfunction

function! s:client.textDocument_willSaveWaitUntil(buf, text) abort
    if !self.initialized()
        return
    endif
    call self.send_request({
                \ 'method': 'textDocument/willSaveWaitUntil',
                \ 'params': {
                \     'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \     'text': a:text,
                \ }},
                \ {response -> self.handle_textDocument_willSaveWaitUntil(response)})
endfunction
" }}}
" didSave done {{{
function! s:client.get_text_document_save_registration_options()
    let l:capabilities = get(self, 'capabilities')
    if !empty(l:capabilities) && has_key(l:capabilities, 'textDocumentSync')
        if type(l:capabilities['textDocumentSync']) == type({})
            if  has_key(l:capabilities['textDocumentSync'], 'save')
                return [1, {
                            \ 'includeText': has_key(l:capabilities['textDocumentSync']['save'], 'includeText') ? l:capabilities['textDocumentSync']['save']['includeText'] : 0,
                            \ }]
            else
                return [0, { 'includeText': 0 }]
            endif
        else
            return [1, { 'includeText': 0 }]
        endif
    endif
    return [0, { 'includeText': 0 }]
endfunction

function! s:client.textDocument_didSave(buf) abort
    if !self.initialized()
        return
    endif
    let l:path = lsc#utils#get_buffer_uri(a:buf)
    let [l:supports_did_save, l:did_save_options] = self.get_text_document_save_registration_options()

    if !l:supports_did_save
        return
    endif

    let l:params = {
                \ 'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \ }

    if l:did_save_options['includeText']
        let l:params['text'] = lsc#lsp#get_textDocumentText(a:buf)
    endif

    call self.send_notification({
                \ 'method': 'textDocument/didSave',
                \ 'params': l:params
                \ })
    if get(self._settings, 'auto_codeLens') == 1
        call self.textDocument_codeLens(a:buf)
    endif
    if get(self._settings, 'auto_documentlink') == 1
        call self.textDocument_documentLink(a:buf)
    endif
endfunction
" }}}
" didClose : working, need more control {{{
function! s:client.textDocument_didClose(buf) abort
    if !self.initialized()
        return
    endif
    let l:path = lsc#utils#get_buffer_uri(a:buf)
    let l:params = {
                \ 'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \ }

    call self.send_notification({
                \ 'method': 'textDocument/didClose',
                \ 'params': l:params
                \ })
    " TODO(Richard):
    " call remove(self._context.buffer_info, l:path)
endfunction
" }}}
" }}}

" diagnostics {{{
"
function! s:position_compare(pos0, pos1) abort
    if a:pos0.line > a:pos1.line
        return 1
    elseif a:pos0.line < a:pos1.line
        return -1
    elseif a:pos0.character > a:pos1.character
        return 1
    elseif a:pos0.character < a:pos1.character
        return -1
    else
        return 0
    endif
endfunction

function! s:client.handle_textDocument_publishDiagnostics(notification)
    let l:diagnostic = get(a:notification, 'params')
    let l:uri = l:diagnostic['uri']
    let l:buf = bufnr(lsc#uri#uri_to_path(l:uri))
    let l:diagnostics = l:diagnostic['diagnostics']

    if l:buf > 0
        let l:fh = self._context._file_handlers[l:uri]
        call assert_equal(l:buf, l:fh._buf)
        let l:fh._diagnostics = sort(deepcopy(l:diagnostics),
                    \ {d0, d1 -> s:position_compare(d0['range']['start'], d1['range']['start'])})
        call lsc#diagnostics#handle_diagnostics(l:fh, l:diagnostics)
    elseif !empty(l:diagnostics)
        let l:fh = lsc#file#new(l:uri)
        let self._context._file_handlers[l:uri] = l:fh
        let l:fh._diagnostics = sort(deepcopy(l:diagnostics),
                    \ {d0, d1 -> s:position_compare(d0['range']['start'], d1['range']['start'])})
    endif
endfunction

function! s:client.Diagnostics_next() abort
    let [l:buf, l:line, l:col, _, _] = getcurpos()
    let l:uri = lsc#utils#get_buffer_uri(l:buf)
    let l:fh = self._context._file_handlers[l:uri]

    if empty(l:fh._diagnostics)
        return
    endif

    let l:to = l:fh._diagnostics[0]['range']['start']

    for l:diag in l:fh._diagnostics
        let l:pos = l:diag['range']['start']
        if (l:pos['line'] > l:line - 1) || (l:pos['line'] == l:line - 1 && l:pos['character'] > l:col)
            let l:to = l:pos
            break
        endif
    endfor

    call setpos('.', [l:buf, l:to['line'] + 1, l:to['character'] + 1, 0])
endfunction

function! s:client.Diagnostics_prev()
    let [l:buf, l:line, l:col, _, _] = getcurpos()
    let l:uri = lsc#utils#get_buffer_uri(l:buf)
    let l:fh = self._context._file_handlers[l:uri]

    if empty(l:fh._diagnostics)
        return
    endif

    let l:to = l:fh._diagnostics[-1]['range']['start']

    for l:diag in l:fh._diagnostics
        let l:pos = l:diag['range']['end']
        if !((l:pos['line'] > l:line - 1) || (l:pos['line'] == l:line - 1 && l:pos['character'] > l:col - 1))
            let l:to = l:diag['range']['start']
            break
        endif
    endfor

    call setpos('.', [l:buf, l:to['line'] + 1, l:to['character'] + 1, 0])
endfunction

" }}}

" languageFeatures {{{
" completion {{{
function! s:client.handle_textDocument_completion(response) abort
    let l:CompletionList = get(a:response, 'result')
    if empty(l:CompletionList)
        return
    endif
    if type(l:CompletionList) == v:t_list
        let l:CompletionList = {'isIncomplete': v:false, 'items': l:CompletionList}
    endif
    if empty(l:CompletionList.items)
        return
    endif

    call lsc#completion#handle_completion(l:CompletionList)
endfunction

function! s:client.textDocument_completion(buf, line, character, kind, string) abort
    if !self.initialized()
        return
    endif
    let l:context = {'triggerKind': a:kind}
    if a:kind == 2
        let l:context['triggerCharacter'] = a:string
    endif
    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/completion',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \         'context': l:context
                \      }
                \ },
                \ {response -> self.handle_textDocument_completion(response)})
endfunction

" }}}
" completionItem/resolve {{{
function! s:client.handle_textDocument_completionItem_resolve(response) abort
    "TODO(Richard):
endfunction

function! s:client.textDocument_completionItem_resolve(item) abort
    if !self.initialized()
        return
    endif
    call self.send_request(
                \ {
                \     'method': 'completionItem/resolve',
                \     'params': a:item
                \ },
                \ {response -> self.handle_textDocument_completionItem_resolve(response)})
endfunction
" }}}
" hover done {{{
function! s:client.handle_textDocument_hover(response)
    call lsc#hover#handle_hover(a:response)
endfunction

function! s:client.textDocument_hover(buf, line, character) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'hoverProvider', v:false)
        return
    endif
    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/hover',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \     }
                \ },
                \ {response -> self.handle_textDocument_hover(response)}
                \ )
endfunction
" }}}
" signatureHelp {{{
function! s:client.handle_textDocument_signatureHelp(response) abort
    "TODO(Richard):
endfunction

function! s:client.textDocument_signatureHelp(buf, line, character) abort
    if !self.initialized()
        return
    endif
    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/signatureHelp',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \     }
                \ },
                \ {response -> self.handle_textDocument_signatureHelp(response)}
                \ )
endfunction
" }}}
" declaration : done {{{
function! s:client.handle_textDocument_declaration(response) abort
    call lsc#locations#handle_locations(1, 1, a:response)
endfunction

function! s:client.textDocument_declaration(buf, line, character) abort
    if !self.initialized()
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/declaration',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \      }
                \ },
                \ {response -> self.handle_textDocument_declaration(response)})
endfunction
" }}}
" definition : done {{{
function! s:client.handle_textDocument_definition(response) abort
    call lsc#locations#handle_locations(1, 1, a:response)
endfunction

function! s:client.textDocument_definition(buf, line, character) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'definitionProvider', v:false)
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/definition',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \      }
                \ },
                \ {response -> self.handle_textDocument_definition(response)})
endfunction
" }}}
" typeDefinition : done {{{
function! s:client.handle_textDocument_typeDefinition(response) abort
    call lsc#locations#handle_locations(1, 1, a:response)
endfunction

function! s:client.textDocument_typeDefinition(buf, line, character) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'typeDefinitionProvider', v:false)
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/typeDefinition',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \      }
                \ },
                \ {response -> self.handle_textDocument_typeDefinition(response)})
endfunction
" }}}
" implementation : done {{{
function! s:client.handle_textDocument_implementation(response) abort
    call lsc#locations#handle_locations(1, 1, a:response)
endfunction

function! s:client.textDocument_implementation(buf, line, character) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'implementationProvider', v:false)
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/implementation',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \      }
                \ },
                \ {response -> self.handle_textDocument_implementation(response)})
endfunction
" }}}
" references : done {{{
function! s:client.handle_textDocument_references(response) abort
    call lsc#locations#handle_locations(1, 0, a:response)
endfunction

function! s:client.textDocument_references(buf, line, character, incdec) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'referencesProvider', v:false)
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/references',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \         'context': {
                \             'includeDeclaration': a:incdec,
                \         }
                \      }
                \ },
                \ {response -> self.handle_textDocument_references(response)})
endfunction
" }}}
" documentHighlight : done {{{
function! s:client.handle_ccls_publishSkippedRanges(notification)
    let l:skippedRanges = get(a:notification, 'params')
    let l:uri = l:skippedRanges['uri']
    let l:ranges = l:skippedRanges['skippedRanges']
    let l:buf = bufnr(lsc#uri#uri_to_path(l:uri))
    if l:buf < 0
        return
    endif
    let l:fh = self._context._file_handlers[l:uri]
    call assert_equal(l:buf, l:fh._buf)

    call lsc#skippedranges#handle_skipped_ranges(l:fh, l:ranges)
endfunction

function! s:client.handle_ccls_publishSemanticHighlight(notification)
    let l:semantichighlight = get(a:notification, 'params')
    let l:uri = l:semantichighlight['uri']
    let l:symbols = l:semantichighlight['symbols']
    let l:buf = bufnr(lsc#uri#uri_to_path(l:uri))
    if l:buf < 0
        return
    endif
    let l:fh = self._context._file_handlers[l:uri]
    call assert_equal(l:buf, l:fh._buf)

    call lsc#semantichighlight#handle_semantic_highlight(l:fh, l:symbols)
endfunction

function! s:client.handle_textDocument_documentHighlight(buf, response)
    let l:highlights = get(a:response, 'result')
    let l:uri = lsc#utils#get_buffer_uri(a:buf)
    if empty(l:uri)
        return
    endif
    let l:fh = self._context._file_handlers[l:uri]

    let l:fh._highlights = sort(deepcopy(l:highlights),
                    \ {d0, d1 -> s:position_compare(d0['range']['start'], d1['range']['start'])})

    call lsc#highlight#handle_highlight(l:fh, l:highlights)
endfunction

function! s:client.textDocument_documentHighlight(buf, line, character) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'documentHighlightProvider', v:false)
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/documentHighlight',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \      }
                \ },
                \ {response -> self.handle_textDocument_documentHighlight(a:buf, response)})
endfunction
" }}}
" documentSymbol : done {{{
function! s:client.handle_textDocument_documentSymbol(buf, response) abort
    call lsc#symbols#handle_symbols(a:buf, a:response)
endfunction

function! s:client.textDocument_documentSymbol(buf) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'documentSymbolProvider', v:false)
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/documentSymbol',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \      }
                \ },
                \ {response -> self.handle_textDocument_documentSymbol(a:buf, response)})
endfunction
" }}}
" codeAction done (need refactoring) {{{
function! s:client.handle_codeAction(action) abort
    if has_key(a:action, 'kind')
        echomsg "KIND: " . a:action['kind']
    endif

    if has_key(a:action, 'edit')
        call lsc#workspaceedit#handle_WorkspaceEdit(self, a:action['edit'])
    endif

    if has_key(a:action, 'command')
        call self.workspace_executeCommand(a:action['command']['command'], a:action['command']['arguments'])
    endif
endfunction

function! s:client.handle_codeActionItem(item) abort
    if has_key(a:item, 'command')
        call self.workspace_executeCommand(a:item['command'], a:item['arguments'])
    else
        call self.handle_codeAction(a:item)
    endif
endfunction

function! s:client.handle_textDocument_codeAction(response) abort
    let l:items = get(a:response, 'result')
    if empty(l:items)
        return
    endif

    if len(l:items) == 1
        call self.handle_codeActionItem(l:items[0])
        return
    endif

    let l:idx = 1
    let l:actlist = []

    for l:item in l:items
        call add(l:actlist, printf('%d. [%s]', l:idx, l:item['title']))
        let l:idx += 1
    endfor

    let l:idx = inputlist(l:actlist)
    if !(l:idx >= 1 && l:idx <= len(l:actlist))
        return
    endif
    call self.handle_codeActionItem(l:items[l:idx - 1])
endfunction

function! s:diagnostics_filter(diagnostics, line)
    if empty(a:diagnostics)
        return
    endif

    let l:idx = 0
    let l:diags = []
    let l:len = len(a:diagnostics)
    let l:end = {'line': 0, 'character': 0}


    while l:idx < l:len && a:diagnostics[l:idx]['range']['end']['line'] < a:line
        let l:idx += 1
    endwhile


    while l:idx < l:len && a:diagnostics[l:idx]['range']['start']['line'] <= a:line
        if s:position_compare(l:end, a:diagnostics[l:idx]['range']['end']) < 0
            let l:end = deepcopy(a:diagnostics[l:idx]['range']['end'])
        endif
        call add(l:diags, deepcopy(a:diagnostics[l:idx]))
        let l:idx += 1
    endwhile

    if empty(l:diags)
        return
    endif

    return {
                \ 'range': {'start': l:diags[0]['range']['start'], 'end': l:end},
                \ 'context': {
                \     'diagnostics': l:diags,
                \     }
                \ }
endfunction

function! s:client.Diagnostics_find(buf, line, character)
    let l:uri = lsc#utils#get_buffer_uri(a:buf)
    let l:fh = self._context._file_handlers[l:uri]
    let l:diagnostics = get(l:fh, '_diagnostics')
    if empty(l:diagnostics)
        return
    endif

    let l:ctx = s:diagnostics_filter(l:diagnostics, a:line)
    if empty(l:ctx)
        return
    endif
    let l:ctx['textDocument'] = lsc#lsp#get_TextDocumentIdentifier(a:buf)
    return l:ctx
endfunction

function! s:client.textDocument_codeAction(buf, line, character) abort
    if !self.initialized()
        return
    endif

    let l:provider = get(self.capabilities, 'codeActionProvider')
    if empty(l:provider)
        return
    endif

    let l:kinds = get(l:provider, 'codeActionKinds')
    " TODO(Richard): use the kind

    let l:params = self.Diagnostics_find(a:buf, a:line, a:character)
    if empty(l:params)
        return
    endif

    let l:params['range']['start']['character'] = 0
    let l:params['range']['end']['line'] += 1
    let l:params['range']['end']['character'] = 0

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/codeAction',
                \     'params': l:params,
                \ },
                \ {response -> self.handle_textDocument_codeAction(response)})
endfunction
" }}}
" codeLens : done {{{
function! s:client.handle_textDocument_codeLens(buf, response) abort
    let l:codelenses = get(a:response, 'result')
    let l:uri = lsc#utils#get_buffer_uri(a:buf)
    if empty(l:uri)
        return
    endif
    let l:fh = self._context._file_handlers[l:uri]

    let l:fh._codelenses = sort(deepcopy(l:codelenses),
                    \ {d0, d1 -> s:position_compare(d0['range']['start'], d1['range']['start'])})


    if !get(self.capabilities['codeLensProvider'], 'resolveProvider')
        return lsc#codelens#handle_codelens(l:fh, l:codelenses)
    endif

    let l:ctx = {'ret': [], 'len': len(l:codelenses), 'buf': a:buf}
    for l:codelens in l:codelenses
        call self.textDocument_codeLens_resolve(l:ctx, l:codelens)
    endfor
endfunction

function! s:client.textDocument_codeLens(buf) abort
    if !self.initialized()
        return
    endif

    if empty(get(self.capabilities, 'codeLensProvider'))
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/codeLens',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \     }
                \ },
                \ {response -> self.handle_textDocument_codeLens(a:buf, response)})
endfunction
" }}}
" codeLens resolve {{{
function! s:client.handle_textDocument_codeLens_resolve(ctx, response) abort
    call add(a:ctx.ret, a:response.result)
    if len(a:ctx.ret) >= a:ctx.len
        return lsc#codelens#handle_codelens(a:ctx.buf, a:ctx.ret)
    endif
endfunction
function! s:client.textDocument_codeLens_resolve(ctx, codelens) abort
    if !self.initialized()
        return
    endif
    call self.send_request(
                \ {
                \     'method': 'codeLens/resolve',
                \     'params': a:codelens
                \ },
                \ {response -> self.handle_textDocument_codeLens_resolve(a:ctx, response)})
endfunction
" }}}
" documentLink : done {{{
function! s:client.handle_textDocument_documentLink(buf, response) abort
    let l:doclinks = a:response.result

    let l:uri = lsc#utils#get_buffer_uri(a:buf)
    if empty(l:uri)
        return
    endif
    let l:fh = self._context._file_handlers[l:uri]

    let l:fh._documentlinks = sort(deepcopy(l:doclinks),
                    \ {d0, d1 -> s:position_compare(d0['range']['start'], d1['range']['start'])})

    call lsc#documentlink#handle_documentlink(l:fh, l:doclinks)
    return

    let l:ctx = {'ret': [], 'len': len(l:doclinks), 'buf': a:buf}
    call self.textDocument_documentLink_resolve(l:ctx, l:doclinks[0])
    " TODO(Richard):

    if !get(self.capabilities['documentLinkProvider'], 'resolveProvider')
        return lsc#documentlink#handle_documentlink(a:buf, l:doclinks)
    endif

    let l:ctx = {'ret': [], 'len': len(l:doclinks), 'buf': a:buf}
    for l:dl in l:doclinks
        call self.textDocument_documentLink_resolve(l:ctx, l:dl)
    endfor
endfunction

function! s:client.textDocument_documentLink(buf) abort
    if !self.initialized()
        return
    endif

    if empty(get(self.capabilities, 'documentLinkProvider'))
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/documentLink',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \     }
                \ },
                \ {response -> self.handle_textDocument_documentLink(a:buf, response)})
endfunction
" }}}
" documentLink resolve {{{
function! s:client.handle_textDocument_documentLink_resolve(ctx, response) abort
    call add(a:ctx.ret, a:response.result)
    if len(a:ctx.ret) >= a:ctx.len
        call lsc#documentlink#handle_documentlink(a:ctx.buf, a:ctx.ret)
    endif
endfunction

function! s:client.textDocument_documentLink_resolve(ctx, doclink) abort
    if !self.initialized()
        return
    endif
    call self.send_request(
                \ {
                \     'method': 'documentLink/resolve',
                \     'params': a:doclink
                \ },
                \ {response -> self.handle_textDocument_documentLink_resolve(a:ctx, response)})
endfunction
" }}}
" documentColor {{{
function! s:client.handle_textDocument_documentColor(buf, response) abort
endfunction
function! s:client.textDocument_documentColor(buf) abort
    if !self.initialized()
        return
    endif
    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/documentColor',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \     }
                \ },
                \ {response -> self.handle_textDocument_documentColor(a:buf, response)})
endfunction
" }}}
" colorPresentation {{{
function! s:client.handle_textDocument_colorPresentation(buf, response) abort
endfunction
function! s:client.textDocument_colorPresentation(buf, color, range) abort
    if !self.initialized()
        return
    endif
    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/colorPresentation',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'color': a:color,
                \         'range': a:range,
                \     }
                \ },
                \ {response -> self.handle_textDocument_colorPresentation(a:buf, response)})
endfunction
" }}}
" formatting done {{{
function! s:client.handle_textDocument_formatting(buf, response) abort
    let l:edits = get(a:response, 'result')
    if empty(l:edits)
        return
    endif
    call lsc#workspaceedit#handle_TextEdits(self, a:buf, l:edits)
endfunction

function! s:client.textDocument_formatting(buf) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'documentFormattingProvider', v:false)
        return
    endif
    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/formatting',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'options': {
                \             'tabSize': getbufvar(bufnr('%'), '&tabstop'),
                \             'insertSpaces': getbufvar(bufnr('%'), '&expandtab') ? v:true : v:false,
                \         },
                \     }
                \ },
                \ {response -> self.handle_textDocument_formatting(a:buf, response)})
endfunction
" }}}
" rangeFormatting done {{{
function! s:client.textDocument_rangeFormatting(buf, range) abort
    if !self.initialized()
        return
    endif
    if !get(self.capabilities, 'documentRangeFormattingProvider', v:false)
        return
    endif
    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/rangeFormatting',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'range': a:range,
                \         'options': {
                \             'tabSize': getbufvar(bufnr('%'), '&tabstop'),
                \             'insertSpaces': getbufvar(bufnr('%'), '&expandtab') ? v:true : v:false,
                \         },
                \     }
                \ },
                \ {response -> self.handle_textDocument_formatting(a:buf, response)})
endfunction
" }}}
" onTypeFormatting {{{
function! s:client.handle_textDocument_onTypeFormatting(buf, response) abort
endfunction
function! s:client.textDocument_onTypeFormatting(buf, line, character) abort
    if !self.initialized()
        return
    endif
    let l:provider = get(self.capabilities, 'documentOnTypeFormattingProvider')
    if empty(l:provider)
        return
    endif
    let l:trigger = get(l:provider, 'firstTriggerCharacter')

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/onTypeFormatting',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \         'ch': l:trigger,
                \         'options': {
                \             'tabSize': getbufvar(bufnr('%'), '&tabstop'),
                \             'insertSpaces': getbufvar(bufnr('%'), '&expandtab') ? v:true : v:false,
                \         },
                \     }
                \ },
                \ {response -> self.handle_textDocument_formatting(a:buf, response)})
endfunction
" }}}
" rename done {{{
function! s:client.handle_textDocument_rename(response) abort
    let l:workspaceedit = get(a:response, 'result')
    if empty(l:workspaceedit)
        return
    endif
    call lsc#workspaceedit#handle_WorkspaceEdit(self, l:workspaceedit)
endfunction

function! s:client.textDocument_rename(buf, line, character, name) abort
    if !self.initialized()
        return
    endif

    if !get(self.capabilities, 'renameProvider', v:false)
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/rename',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \         'newName': a:name,
                \     }
                \ },
                \ {response -> self.handle_textDocument_rename(response)})
endfunction
" }}}
" prepareRename {{{
function! s:client.handle_textDocument_prepareRename(buf, response) abort
    "TODO:
endfunction

function! s:client.textDocument_prepareRename(buf, line, character) abort
    if !self.initialized()
        return
    endif
    let l:renameOptions = get(self.capabilities, 'renameProvider')
    if !l:renameOptions || type(l:renameOptions) != v:t_dict || !get(l:renameOptions, 'prepareProvider')
        return
    endif
    if !get(self.capabilities, 'renameProvider', v:false)
        return
    endif

    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/prepareRename',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \         'position': lsc#lsp#get_Position(a:line, a:character),
                \     }
                \ },
                \ {response -> self.handle_textDocument_prepareRename(a:buf, response)})
endfunction
" }}}
" foldingRange done (need refactoring) {{{
function! s:client.handle_textDocument_foldingRange(buf, response) abort
    let l:foldingranges = get(a:response, 'result')
    if empty(l:foldingranges)
        return
    endif
    call filter(l:foldingranges, {_, fr -> fr['startLine'] < fr['endLine']})
    call map(l:foldingranges, {_, fr -> printf("%d,%dfo", fr['startLine'] + 1, fr['endLine'] + 1)})
    call execute('setlocal foldmethod=manual')
    call execute('normal! zE')
    call execute(l:foldingranges)
endfunction

function! s:client.textDocument_foldingRange(buf) abort
    if !self.initialized()
        return
    endif
    call self.textDocument_didChange(a:buf)
    call self.send_request(
                \ {
                \     'method': 'textDocument/foldingRange',
                \     'params': {
                \         'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \     }
                \ },
                \ {response -> self.handle_textDocument_foldingRange(a:buf, response)})
endfunction
" }}}
" }}}

" PublicAPIs {{{
function! lsc#client#launch(command, root_dir, buf) abort
    let l:client = s:client.launch(a:command.command)
    if type(l:client) != v:t_dict
        return 0
    endif

    let l:client._name = get(a:command, 'name', fnamemodify(a:command.command[0], ':t:r'))
    let l:client._settings = get(a:command, 'settings', {})

    call l:client.initialize(
                \ a:root_dir,
                \ get(a:command, 'initialization_options', {}),
                \ get(a:command, 'workspace_settings', {}),
                \ a:buf)
    return l:client
endfunction

function! lsc#client#is_client_instance(server)
    return type(a:server) == v:t_dict && has_key(a:server, '_jobid') && a:server['_jobid'] != -1
endfunction
" }}}

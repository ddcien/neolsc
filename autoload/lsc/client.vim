" vim: set foldmethod=marker foldlevel=0 nomodeline:
"
let s:client = {
            \ '_jobid' : -1,
            \ '_context': {
            \     'request_id' : 1,
            \     'data_buf': {'data': '', 'length': -1, 'header_length': -1},
            \     'diagnostics': {},
            \     'initialized': 0,
            \     'buffer_info': {},
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
    call lsc#log#log([a:data, a:event])
endfunction

function s:client.on_exit(job_id, data, event)
    call lsc#log#log([a:data, a:event])
endfunction

function s:client.response_handler(response)
    call lsc#log#verbose(a:response)
    let l:request_method = get(a:response, 'method')
    let l:request_id = get(a:response, 'id')

    if has_key(self._notification_hooks, l:request_method)
        call self._notification_hooks[l:request_method](a:response)
    elseif has_key(self._request_hooks, l:request_id)
        call self._request_hooks[l:request_id](a:response)
        call remove(self._request_hooks, l:request_id)
    endif
endfunction

function! s:client.send_notification(method, params)
    let l:request = {
                \ 'jsonrpc': '2.0',
                \ 'method': a:method,
                \ }
    if !empty(a:params)
        let l:request['params'] = a:params
    endif
    let l:content = json_encode(request)
    let l:data = 'Content-Length: ' . string(strlen(l:content)) . "\r\n\r\n" . l:content

    call lsc#log#verbose(l:content)
    call chansend(self._jobid, l:data)
endfunction

function! s:client.send_request(method, params, ...)
    let l:request = {
                \ 'jsonrpc': '2.0',
                \ 'id': self._context.request_id,
                \ 'method': a:method,
                \ }
    if !empty(a:params)
        let l:request['params'] = a:params
    endif
    let l:content = json_encode(request)
    let l:data = 'Content-Length: ' . string(strlen(l:content)) . "\r\n\r\n" . l:content

    if a:0 > 0 && type(a:1) == v:t_func
        let self._request_hooks[l:request.id] = a:1
    endif
    let self._context.request_id += 1

    call lsc#log#verbose(l:content)
    call chansend(self._jobid, l:data)
endfunction

function! s:client.register_notification_hook(method, hook)
    if type(a:hook) == v:t_func
        let self._notification_hooks[a:method] = a:hook
    endif
endfunction

function! s:client.initialized()
    return self._context.initialized
endfunction

" {{{
function! s:client.workspace_didChangeConfiguration(settings) abort
    if !self.initialized()
        return
    endif

    let l:params = {
                \ 'settings': a:settings
                \ }

    call self.send_notification('workspace/didChangeConfiguration', l:params)
endfunction
" }}}

" textSynchronization {{{
function! s:client.textDocument_didOpen(buf) abort
    if !self.initialized()
        return
    endif

    let l:path = lsc#utils#get_buffer_uri(a:buf)

    if empty(l:path)
        return
    endif

    let l:buffer_info = { 'changed_tick': getbufvar(a:buf, 'changedtick'), 'version': 1}
    let self._context.buffer_info[l:path] = l:buffer_info
    let l:params = {
                \ 'textDocument': lsc#lsp#get_TextDocumentItem(a:buf, l:buffer_info.version)
                \ }
    call self.send_notification('textDocument/didOpen', l:params)
endfunction

function! s:client.textDocument_didChange(buf) abort
    if !self.initialized()
        return
    endif
    let l:path = lsc#utils#get_buffer_uri(a:buf)
    let l:buffer_info = self._context.buffer_info[l:path]
    let l:changed_tick = getbufvar(a:buf, 'changedtick')

    if l:buffer_info['changed_tick'] == l:changed_tick
        return
    endif

    let l:buffer_info['changed_tick'] = l:changed_tick
    let l:buffer_info['version'] += 1

    let l:params = {
                \ 'textDocument': lsc#lsp#get_VersionedTextDocumentIdentifier(a:buf, l:buffer_info.version),
                \ 'contentChanges': [
                \     {'text': lsc#lsp#get_textDocumentText(a:buf)},
                \ ],
                \ }
    call self.send_notification('textDocument/didChange', l:params)
endfunction


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

    call self.send_notification('textDocument/didSave', l:params)
endfunction

function! s:client.textDocument_didClose(buf) abort
    if !self.initialized()
        return
    endif
    let l:path = lsc#utils#get_buffer_uri(a:buf)
    let l:params = {
                \ 'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \ }

    call self.send_notification('textDocument/didClose', l:params)
    call remove(self._context.buffer_info, l:path)
endfunction
" }}}

" general {{{
function s:client.launch(command)
    let l:client = deepcopy(s:client)
    let l:client._command = a:command
    let l:client._jobid = jobstart(l:client._command, l:client)
    if l:client._jobid <= 0
        return 0
    endif

    call l:client.register_notification_hook('textDocument/publishDiagnostics', {notification -> self.handle_textDocument_publishDiagnostics(notification)})

    return l:client
endfunction

function! s:client.handle_initialize(settings, buf, response)
    call extend(self, a:response.result)
    call self.send_notification('initialized', {})
    let self._context.initialized = 1
    if !empty(a:settings)
        call self.send_notification('workspace/didChangeConfiguration', {'settings': a:settings})
    endif
    call self.textDocument_didOpen(a:buf)
endfunction

function!  s:client.initialize(root_dir, init_opts, settings, buf)
    let l:params = {
                \ 'rootUri': lsc#uri#path_to_uri(a:root_dir),
                \ 'initializationOptions': a:init_opts,
                \ 'capabilities': {
                \     'workspace': {
                \         'applyEdit ': v:true
                \     }
                \ },
                \ 'trace': 'off'
                \ }
    call self.send_request('initialize', l:params, {response -> self.handle_initialize(a:settings, a:buf, response)})
endfunction

function! s:client.handle_shutdown(response)
    let self._context.initialized = 0
endfunction

function! s:client.shutdown()
    if !self.initialized()
        return
    endif
    call self.send_request('shutdown', {}, {response -> self.handle_shutdown(response)})
endfunction

function! s:client.exit()
    if !self.initialized()
        return
    endif
    call self.send_notification('exit', {})
endfunction

function! s:client.cancelRequest(id)
    if !self.initialized()
        return
    endif
    call self.send_notification('$/cancelRequest', {'id': a:id})
endfunction

function! s:client.handle_textDocument_publishDiagnostics(notification)
    let l:params = get(a:notification, 'params', {})
    if empty(l:params.diagnostics)
        return
    endif
    call extend(self._context.diagnostics, {l:params['uri']: l:params['diagnostics']})
endfunction
" }}}

" languageFeatures {{{
function! s:client.handle_code_lens(buf, response) abort
    let l:codelenses = a:response.result

    let l:dict = {}

    for l:codelens in l:codelenses
        let l:line = l:codelens['range']['start']['line']
        let l:dict[l:line] = add(get(l:dict, l:line, []), l:codelens)
    endfor

    for [l:line, l:codelens] in items(l:dict)
        call sort(l:codelens, {x, y -> x['range']['start']['character'] - y['range']['start']['character']})
        call map(l:codelens, {_, x -> x['command']['title']})
        call nvim_buf_set_virtual_text(a:buf, 1025, str2nr(l:line), [['| ' . join(l:codelens, ' | ') . ' |', 'Comment']], {})
    endfor
endfunction

function! s:client.textDocument_codeLens(buf) abort
    if !self.initialized()
        return
    endif
    let l:path = lsc#utils#get_buffer_uri(a:buf)

    if empty(l:path)
        return
    endif
    let l:params = {
                \ 'textDocument': lsc#lsp#get_TextDocumentIdentifier(a:buf),
                \ }
    call self.send_request('textDocument/codeLens', l:params, {response -> self.handle_code_lens(a:buf, response)})
endfunction
" }}}


" PublicAPIs {{{
function! lsc#client#launch(command, initialization_options, settings, root_dir, buf) abort
    let l:client = s:client.launch(a:command)
    if type(l:client) != v:t_dict
        return 0
    endif
    call l:client.initialize(a:root_dir, a:initialization_options, a:settings, a:buf)
    return l:client
endfunction

function! lsc#client#textDocument_didOpen(client, buf) abort
    call a:client.textDocument_didOpen(a:buf)
endfunction

function! lsc#client#textDocument_didChange(client, buf) abort
    call a:client.textDocument_didChange(a:buf)
endfunction

function! lsc#client#textDocument_didSave(client, buf) abort
    call a:client.textDocument_didSave(a:buf)
endfunction

function! lsc#client#textDocument_didClose(client, buf) abort
    call a:client.textDocument_didClose(a:buf)
endfunction

function! lsc#client#textDocument_codeLens(client, buf) abort
    call a:client.textDocument_codeLens(a:buf)
endfunction

function! lsc#client#workspace_didChangeConfiguration(client, settings) abort
    call a:client.workspace_didChangeConfiguration(a:settings)
endfunction
" }}}


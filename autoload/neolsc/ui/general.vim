" vim: set foldmethod=marker foldlevel=0 nomodeline:

let s:_neolsc_server_list = {}
let s:_neolsc_default_init_file = fnamemodify(expand('<sfile>'), ':h') . '/initialize_params.json'

function! neolsc#ui#general#uri_to_server(uri) abort
    call neolsc#ui#general#path_to_server(neolsc#utils#uri#uri_to_path(a:uri))
endfunction

function! neolsc#ui#general#path_to_server(path) abort
    return neolsc#ui#general#buf_to_server(bufnr(a:path))
endfunction

function! neolsc#ui#general#buf_to_server(buf) abort
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    return neolsc#ui#general#get_server(l:buf_ctx['_server'])
endfunction

function! neolsc#ui#general#get_server(name) abort
    return get(s:_neolsc_server_list, a:name)
endfunction

function! neolsc#ui#general#cancelRequest_handler(server, notification)
    " TODO(Richard):
endfunction

function! neolsc#ui#general#start(name, settings)
    let l:server = get(s:_neolsc_server_list, a:name)
    if !empty(l:server)
        return
    endif
    let l:server = neolsc#lsp#server#start(a:name, a:settings['command'])
    if empty(l:server)
        return
    endif

    call l:server.register_notification_hook('$/cancelRequest', function('neolsc#ui#general#cancelRequest_handler'))

    call l:server.register_notification_hook('window/showMessage', function('neolsc#ui#window#showMessage_handler'))
    call l:server.register_notification_hook('window/logMessage', function('neolsc#ui#window#logMessage_handler'))
    call l:server.register_request_hook('window/showMessageRequest', function('neolsc#ui#window#showMessageRequest_handler'))

    call l:server.register_notification_hook('telemetry/event', function('neolsc#ui#telemetry#event_handler'))

    call l:server.register_request_hook('client/registerCapability', function('neolsc#ui#client#registerCapability'))
    call l:server.register_request_hook('client/unregisterCapability', function('neolsc#ui#client#unregisterCapability'))

    call l:server.register_request_hook('workspace/workspaceFolders', function('neolsc#ui#workspace#workspaceFolders_handler'))
    call l:server.register_request_hook('workspace/configuration', function('neolsc#ui#workspace#configuration_handler'))
    call l:server.register_request_hook('workspace/applyEdit', function('neolsc#ui#workspace#applyEdit_handler'))

    call l:server.register_notification_hook('textDocument/publishDiagnostics', function('neolsc#ui#diagnostics#publishDiagnostics_handler'))


    call l:server.register_notification_hook('$ccls/publishSemanticHighlight', function('neolsc#ui#highlight#semantic_draw'))
    call l:server.register_notification_hook('$ccls/publishSkippedRanges', function('neolsc#ui#highlight#skipped_draw'))
    call neolsc#ui#workspace#executeCommandRegister('ccls.xref', {server, response, command -> neolsc#ui#location#show('ccls.xref', neolsc#ui#location#to_location_list(get(response, 'result', []), v:false), v:true)})


    let l:root_path = getcwd()
    let l:root_name = fnamemodify(l:root_path, ':t:r')
    let l:root_uri = neolsc#utils#uri#path_to_uri(l:root_path)

    let l:init_params = json_decode(readfile(s:_neolsc_default_init_file))
    call extend(l:init_params.initializationOptions, get(a:settings, 'initialization_options', {}))
    let l:init_params['processId'] = getpid()
    let l:init_params['rootPath'] = l:root_path
    let l:init_params['rootUri'] = l:root_uri
    call add(l:init_params['workspaceFolders'], {'uri': l:root_uri, 'name': l:root_name})

    call l:server.initialize(l:init_params)

    call neolsc#ui#workspace#addFolderLocal(l:root_name, l:root_path, a:name)
    if has_key(a:settings, 'workspace_settings')
        call neolsc#ui#workspace#configuration(a:name, a:settings['workspace_settings'])
    endif

    let s:_neolsc_server_list[a:name] = l:server
endfunction

function! neolsc#ui#general#stop(name) abort
    let l:server = get(s:_neolsc_server_list, a:name)
    if empty(l:server)
        return
    endif
    call l:server.shutdown(l:server)
    call remove(s:_neolsc_server_list, a:name)
endfunction

function! neolsc#ui#general#status(name)
    let l:server = get(s:_neolsc_server_list, a:name)
    if empty(l:server)
        echomsg printf('SERVER[%s] is not running.', a:name)
        return
    endif
    echomsg printf('SERVER[%s] is running with jobid: <%d>', a:name, l:server._jobid)
endfunction

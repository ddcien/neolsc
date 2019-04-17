" vim: set foldmethod=marker foldlevel=0 nomodeline:

function! neolsc#ui#window#showMessage_handler(server, notification)
    " TODO(Richard):
endfunction

function! neolsc#ui#window#showMessageRequest_handler(server, request)
    " TODO(Richard):
    return {'error': {'code': -32001, 'message': 'Not implemented yet!'}}
endfunction

function! neolsc#ui#window#logMessage_handler(server, notification)
    " TODO(Richard):
endfunction

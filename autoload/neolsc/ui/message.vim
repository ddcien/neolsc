" vim: set foldmethod=marker foldlevel=0 nomodeline:

let s:MessageType = {
            \ '1': 'Error',
            \ '2': 'Warning',
            \ '3': 'Info',
            \ '4': 'Log',
            \ }

function! neolsc#ui#message#show(message) abort
    " TODO(Richard):
endfunction

function! neolsc#ui#message#showRequest(message) abort
    " TODO(Richard):
    return {'result': v:null}
endfunction

function! neolsc#ui#message#log(message) abort
    " TODO(Richard):
endfunction

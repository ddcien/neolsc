" vim: set foldmethod=marker foldlevel=0 nomodeline:

" omni {{{
function! s:_get_current_character() abort
    let l:line = nvim_get_current_line()
    if empty(l:line)
        return
    endif
    if mode() ==# 'i'
        let l:char = l:line[col('.') - 2]
    else
        let l:char = l:line[col('.') - 1]
    endif
    return l:char
endfunction

function! s:_get_current_position() abort
    let [_, l:lnum, l:col; _] = getcurpos()
    return {'line': l:lnum - 1, 'character': l:col - 1}
endfunction

function! neolsc#ui#completion#omni(findstart, base) abort
    if a:findstart
        return col('.')
    endif

    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_completion()
        return
    endif

    let l:char = s:_get_current_character()
    let l:position = s:_get_current_position()

    call neolsc#ui#textDocumentSynchronization#didChangeBuf(l:buf)
    if index(l:server.capabilities_completion_triggerCharacters(), l:char) >= 0
        call neolsc#lsp#textDocument#completion(l:server, l:buf, l:position, 2, l:char)
    else
        call neolsc#lsp#textDocument#completion(l:server, l:buf, l:position, 1, '')
    endif

    redraws
    return []
endfunction
" }}}

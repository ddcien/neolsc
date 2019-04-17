" vim: set foldmethod=marker foldlevel=0 nomodeline:


function! s:decode_uri(uri) abort
    let l:ret = substitute(a:uri, '[?#].*', '', '')
    return substitute(l:ret, '%\(\x\x\)', '\=printf("%c", str2nr(submatch(1), 16))', 'g')
endfunction

function! s:urlencode_char(c) abort
    return printf('%%%02X', char2nr(a:c))
endfunction

function! s:get_prefix(path) abort
    return matchstr(a:path, '\(^\w\+::\|^\w\+://\)')
endfunction

function! s:encode_uri(path, start_pos_encode, default_prefix) abort
    let l:prefix = s:get_prefix(a:path)
    let l:path = a:path[len(l:prefix):]
    if len(l:prefix) == 0
        let l:prefix = a:default_prefix
    endif

    let l:result = strpart(a:path, 0, a:start_pos_encode)

    for i in range(a:start_pos_encode, len(l:path) - 1)
        " Don't encode '/' here, `path` is expected to be a valid path.
        if l:path[i] =~# '^[a-zA-Z0-9_.~/-]$'
            let l:result .= l:path[i]
        else
            let l:result .= s:urlencode_char(l:path[i])
        endif
    endfor

    return l:prefix . l:result
endfunction

function! neolsc#utils#uri#path_to_uri(path) abort
    return s:encode_uri(fnamemodify(a:path, ':p'), 0, 'file://')
endfunction

function! neolsc#utils#uri#uri_to_path(uri) abort
    return fnamemodify(s:decode_uri(a:uri[len('file://'):]), ':.')
endfunction

function! neolsc#utils#uri#buf_to_uri(buf) abort
    return neolsc#utils#uri#path_to_uri(bufname(a:buf))
endfunction

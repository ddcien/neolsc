" vim: set foldmethod=marker foldlevel=0 nomodeline:

" codeLens {{{
function! lsc#codelens#handle_codelens(buf, response) abort
    let l:codelenses = a:response.result
    if empty(l:codelenses)
        return
    endif
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
" }}}

" vim: set foldmethod=marker foldlevel=0 nomodeline:

" codelens {{{
let s:codelens_ns_id = 0

function! lsc#codelens#handle_codelens(fh, codelenses) abort
    if s:codelens_ns_id == 0
        let s:codelens_ns_id = nvim_create_namespace('ddlsc_codelens')
    else
        call a:fh.set_virtual_text(s:codelens_ns_id, -1, [])
    endif

    if empty(a:codelenses)
        return
    endif

    let l:dict = {}
    for l:codelens in a:codelenses
        let l:line = l:codelens['range']['start']['line']
        let l:dict[l:line] = add(get(l:dict, l:line, []), l:codelens)
    endfor

    for [l:line, l:codelens] in items(l:dict)
        call sort(l:codelens, {x, y -> x['range']['start']['character'] - y['range']['start']['character']})
        call map(l:codelens, {_, x ->  ['[' . x['command']['title'] . ']', 'Comment']})
        call a:fh.set_virtual_text(s:codelens_ns_id, str2nr(l:line), l:codelens)
    endfor
endfunction
" }}}

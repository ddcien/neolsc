" vim: set foldmethod=marker foldlevel=0 nomodeline:

" update {{{
function! neolsc#ui#codelens#update(buf, codelenses) abort
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    if empty(l:buf_ctx)
        return
    endif

    call sort(a:codelenses, {d0, d1 -> neolsc#ui#utils#position_compare(d0['range']['start'], d1['range']['start'])})
    let l:buf_ctx['_codelens'][0] = a:codelenses
    let l:buf_ctx['_codelens'][1] = {}

    for l:codelens in a:codelenses
        let l:line = l:codelens['range']['start']['line']
        let l:buf_ctx['_codelens'][1][l:line] = add(get(l:buf_ctx['_codelens'][1], l:line, []), l:codelens)
    endfor
    call neolsc#ui#vtext#codelens_clear_all(l:buf_ctx)
    call neolsc#ui#vtext#codelens_show_all(l:buf_ctx)
endfunction
" }}}

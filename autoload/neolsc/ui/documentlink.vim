" vim: set foldmethod=marker foldlevel=0 nomodeline:

" update {{{
function! neolsc#ui#documentlink#update(buf, documentlinkes) abort
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    if empty(l:buf_ctx)
        return
    endif

    call sort(a:documentlinkes, {d0, d1 -> neolsc#ui#utils#position_compare(d0['range']['start'], d1['range']['start'])})
    let l:buf_ctx['_doclinks'][0] = a:documentlinkes
    let l:buf_ctx['_doclinks'][1] = {}

    for l:documentlink in a:documentlinkes
        let l:line = l:documentlink['range']['start']['line']
        let l:buf_ctx['_doclinks'][1][l:line] = add(get(l:buf_ctx['_doclinks'][1], l:line, []), l:documentlink)
    endfor
    call neolsc#ui#vtext#documentlink_clear_all(l:buf_ctx)
    call neolsc#ui#vtext#documentlink_show_all(l:buf_ctx)
endfunction
" }}}


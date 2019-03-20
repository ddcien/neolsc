" vim: set foldmethod=marker foldlevel=0 nomodeline:

" highlight {{{
function! s:parse_highlight(hl)
    let l:list = []

    let l:hl = {'1': 'SpellCap', '2': 'SpellLocal', '3': 'SpellRare'}[get(a:hl, 'kind', '3')]

    let l:rg = a:hl['range']
    let l:sl = l:rg['start']['line']
    let l:el = l:rg['end']['line']

    for l:line in range(l:sl, l:el)
        let l:sc = l:line == l:sl ? l:rg['start']['character'] : 0
        let l:ec = l:line == l:el ? l:rg['end']['character'] : -1
        call add(l:list, [l:hl , l:line, l:sc, l:ec])
    endfor

    return l:list
endfunction

function! lsc#highlight#handle_highlight(buf, response) abort
    let l:highlights = a:response.result

    for l:hl in l:highlights
        for [l:hl, l:line, l:sc, l:ec] in s:parse_highlight(l:hl)
            call nvim_buf_add_highlight(0, 1024, l:hl, l:line, l:sc, l:ec)
        endfor
    endfor
endfunction
" }}}

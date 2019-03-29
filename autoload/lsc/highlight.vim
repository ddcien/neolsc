" vim: set foldmethod=marker foldlevel=0 nomodeline:

" highlight {{{
let s:highlight_ns_id = 0

if &background ==# 'dark'
  hi default HighlightText  guibg=#222222 ctermbg=233
else
  hi default HighlightText  guibg=#f9f9f9 ctermbg=15
endif
hi default link HighlightRead  HighlightText
hi default link HighlightWrite HighlightText


function! s:parse_highlight(hl)
    let l:list = []

    let l:hl = {'1': 'HighlightText', '2': 'HighlightRead', '3': 'HighlightWrite'}[get(a:hl, 'kind', '3')]

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

function! lsc#highlight#handle_highlight(fh, highlights) abort
    if s:highlight_ns_id == 0
        let s:highlight_ns_id = nvim_create_namespace('ddlsc_highlight')
    else
        call a:fh.set_virtual_text(s:highlight_ns_id, -1, [])
    endif

    if empty(a:highlights)
        return
    endif

    for l:hl in a:highlights
        for [l:hl, l:line, l:sc, l:ec] in s:parse_highlight(l:hl)
            try
                call a:fh.add_highlight(s:highlight_ns_id, l:line, l:hl, l:sc, l:ec)
            catch /.*/
                echomsg v:exception
            endtry
        endfor
    endfor
endfunction
" }}}

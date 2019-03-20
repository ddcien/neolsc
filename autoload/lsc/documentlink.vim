" vim: set foldmethod=marker foldlevel=0 nomodeline:
" Document Link {{{

function! lsc#documentlink#handle_DocumentLink(buf, response) abort
    let l:doclinks = a:response.result
    if empty(l:doclinks)
        return
    endif
    let l:dict = {}
    for l:doclink in l:doclinks
        let l:line = l:doclink['range']['start']['line']
        let l:dict[l:line] = add(get(l:dict, l:line, []), l:doclink)
    endfor

    for [l:line, l:doclink] in items(l:dict)
        call sort(l:doclink, {x, y -> x['range']['start']['character'] - y['range']['start']['character']})
        call map(l:doclink, {_, x -> fnamemodify(expand(lsc#uri#uri_to_path(x['target'])), ":~:.")})
        call nvim_buf_set_virtual_text(a:buf, 1026, str2nr(l:line), [['| ' . join(l:doclink, ' | ') . ' |', 'Comment']], {})
    endfor
endfunction

" }}}

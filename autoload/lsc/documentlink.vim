" vim: set foldmethod=marker foldlevel=0 nomodeline:
" Document Link {{{

let s:documentlink_ns_id = 0

function! lsc#documentlink#handle_documentlink(fh, doclinks) abort
    if s:documentlink_ns_id == 0
        let s:documentlink_ns_id = nvim_create_namespace('ddlsc_documentlink')
    else
        call a:fh.set_virtual_text(s:documentlink_ns_id, -1, [])
    endif

    if empty(a:doclinks)
        return
    endif

    let l:dict = {}
    for l:doclink in a:doclinks
        let l:line = l:doclink['range']['start']['line']
        let l:dict[l:line] = add(get(l:dict, l:line, []), l:doclink)
    endfor

    for [l:line, l:doclink] in items(l:dict)
        call sort(l:doclink, {x, y -> x['range']['start']['character'] - y['range']['start']['character']})
        call map(l:doclink, {_, x ->  ['[' . lsc#uri#uri_to_path(x['target']) . ']', 'Comment']})
        call a:fh.set_virtual_text(s:documentlink_ns_id, str2nr(l:line), l:doclink)
    endfor
endfunction
" }}}

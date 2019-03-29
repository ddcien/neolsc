" vim: set foldmethod=marker foldlevel=0 nomodeline:

" diagnostics {{{
let s:diagnostic_ns_id = 0

let s:DiagnosticSeverity = {
            \ '0': ['Unknown', 'Error'],
            \ '1': ['Error', 'Error'],
            \ '2': ['Warning', 'Search'],
            \ '3': ['Information', 'WildMenu'],
            \ '4': ['Hint', 'StatusLineNC'],
            \ }

function! s:split_range(range)
    let l:list = []

    let l:sl = a:range['start']['line']
    let l:el = a:range['end']['line']

    for l:line in range(l:sl, l:el)
        let l:sc = l:line == l:sl ? a:range['start']['character'] : 0
        let l:ec = l:line == l:el ? a:range['end']['character'] : -1
        call add(l:list, [l:line, l:sc, l:ec])
    endfor

    return l:list
endfunction


function! lsc#diagnostics#handle_diagnostics(fh, diagnostics) abort
    if s:diagnostic_ns_id == 0
        let s:diagnostic_ns_id = nvim_create_namespace('ddlsc_diagnostic')
    else
        call a:fh.set_virtual_text(s:diagnostic_ns_id, -1, [])
    endif

    if empty(a:diagnostics)
        return
    endif

    let l:dict = {}
    for l:diag in a:diagnostics
        let l:line = l:diag['range']['start']['line']
        let l:dict[l:line] = add(get(l:dict, l:line, []), l:diag)
    endfor

    for [l:line, l:diags] in items(l:dict)
        call sort(l:diags, {x, y -> x['range']['start']['character'] - y['range']['start']['character']})

        let l:chunks = []
        for l:diag in l:diags
            let l:severity = get(s:DiagnosticSeverity, get(l:diag, 'severity'))
            for [l:line, l:sc, l:ec] in s:split_range(l:diag['range'])
                call a:fh.add_highlight(s:diagnostic_ns_id, l:line, l:severity[1], l:sc, l:ec)
            endfor
            call add(l:chunks,
                        \ ['[' . l:severity[0] . ': ' . l:diag['message'] . ']', l:severity[1]]
                        \ )
        endfor

        call a:fh.set_virtual_text(s:diagnostic_ns_id, str2nr(l:line), l:chunks)
    endfor
endfunction
" }}}

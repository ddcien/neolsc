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

function! s:Diagnostic_to_locinfo(buf, diag)
    let l:line = a:diag['range']['start']['line'] + 1
    let l:col = a:diag['range']['start']['character'] + 1
    echom json_encode(a:diag)
    let l:text = printf(' -> [%s]:[%s]: %s', get(a:diag, 'source', 'NA'), get(s:DiagnosticSeverity, get(a:diag, 'severity'))[0], a:diag['message'])
    return {'bufnr': a:buf, 'lnum': l:line, 'col': l:col, 'text': l:text}
endfunction

function! lsc#diagnostics#list_diagnostics(fh) abort
    let l:diagnostics = deepcopy(get(a:fh, '_diagnostics'))
    if empty(l:diagnostics)
        return
    endif
    call map(l:diagnostics, {_, diag -> s:Diagnostic_to_locinfo(a:fh._buf, diag)})
    call setloclist(0, l:diagnostics)
    call lsc#locations#locations_ui(1)
endfunction

function! lsc#diagnostics#list_workspace_diagnostics(fhs) abort
    let l:locs = []
    for l:fh in values(a:fhs)
        let l:diagnostics = deepcopy(get(l:fh, '_diagnostics'))
        if empty(l:diagnostics)
            continue
        endif
        for l:diag in l:diagnostics
            call add(l:locs, s:Diagnostic_to_locinfo(l:fh._buf, l:diag))
        endfor
    endfor

    if empty(l:locs)
        return
    endif

    call setloclist(0, l:locs)
    call lsc#locations#locations_ui(1)
endfunction

" }}}

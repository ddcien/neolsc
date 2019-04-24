" vim: set foldmethod=marker foldlevel=0 nomodeline:

" update  {{{
function! neolsc#ui#diagnostics#publishDiagnostics_handler(server, notification) abort
    let l:diagnostic = get(a:notification, 'params')
    let l:uri = l:diagnostic['uri']
    let l:diagnostics = get(l:diagnostic, 'diagnostics')
    let l:buf = bufnr(neolsc#utils#uri#uri_to_path(l:uri))

    let l:buf_ctx = neolsc#ui#workfile#get(l:buf)
    if empty(l:buf_ctx)
        return
    endif

    call sort(l:diagnostics, {d0, d1 -> neolsc#ui#utils#position_compare(d0['range']['start'], d1['range']['start'])})
    let l:buf_ctx['_diagnostics'][0] = l:diagnostics
    let l:buf_ctx['_diagnostics'][1] = {}

    for l:diag in l:diagnostics
        let l:line = l:diag['range']['start']['line']
        let l:buf_ctx['_diagnostics'][1][l:line] = add(get(l:buf_ctx['_diagnostics'][1], l:line, []), l:diag)
    endfor

    call neolsc#ui#vtext#diagnostics_clear_all(l:buf_ctx)
    " call neolsc#ui#highlight#diagnostics_show(l:buf)
endfunction

function! s:lsp_dia_to_vim_location(buf, diag) abort
    let l:line = a:diag['range']['start']['line'] + 1
    let l:col = a:diag['range']['start']['character'] + 1
    let l:text = a:diag['message']
    return {'filename': bufname(a:buf), 'lnum': l:line, 'col': l:col, 'text': l:text}
endfunction

function! neolsc#ui#diagnostics#diags() abort
    let l:buf = nvim_get_current_buf()
    let l:buf_ctx = neolsc#ui#workfile#get(l:buf)
    if empty(l:buf_ctx)
        return
    endif
    let l:diagnostics = l:buf_ctx['_diagnostics'][0]
    if empty(l:diagnostics)
        return
    endif
    let l:loclist = []
    for l:diag in l:diagnostics
        call add(l:loclist, s:lsp_dia_to_vim_location(l:buf, l:diag))
    endfor
    call neolsc#ui#location#show('Diagnostics', l:loclist, v:false)
endfunction

function! neolsc#ui#diagnostics#workspaceDiags() abort
    let l:loclist = []
    for l:buf_ctx in neolsc#ui#workfile#getAll()
        let l:diagnostics = l:buf_ctx['_diagnostics'][0]
        for l:diag in l:diagnostics
            call add(l:loclist, s:lsp_dia_to_vim_location(l:buf_ctx['_buf'], l:diag))
        endfor
    endfor
    call neolsc#ui#location#show('Diagnostics', l:loclist, v:false)
endfunction
" }}}

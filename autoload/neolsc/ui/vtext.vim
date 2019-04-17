" vim: set foldmethod=marker foldlevel=0 nomodeline:

" private {{{
let s:_vtext_ctx = {
            \ '_codelens': {'ns_id': nvim_create_namespace('neolsc_codelens')},
            \ '_doclinks': {'ns_id': nvim_create_namespace('neolsc_documentlink')},
            \ '_diagnostics': {'ns_id': nvim_create_namespace('neolsc_diagnostics')}
            \ }

function! s:_line_clear(kind, ctx, line) abort
    call nvim_buf_clear_namespace(a:ctx['_buf'], s:_vtext_ctx[a:kind]['ns_id'], a:line, a:line + 1)
endfunction

function! s:_line_show(kind, ctx, line) abort
    let l:chunks = call(function(printf('s:%s_build_chunck', a:kind)), [a:ctx, a:line])
    if empty(l:chunks)
        return
    endif
    call nvim_buf_set_virtual_text(a:ctx['_buf'], s:_vtext_ctx[a:kind]['ns_id'], a:line, l:chunks, {})
endfunction

function! s:_clear(kind, ctx) abort
    call nvim_buf_clear_namespace(a:ctx['_buf'], s:_vtext_ctx[a:kind]['ns_id'], 0, -1)
endfunction

function! s:_show(kind, ctx) abort
    for l:line in keys(a:ctx[a:kind][1])
        call s:_line_show(a:kind, a:ctx, str2nr(l:line))
    endfor
endfunction
" }}}

" codelens {{{
function! s:_codelens_build_chunck(ctx, line) abort
    let l:items = get(a:ctx['_codelens'][1], a:line)
    if empty(l:items)
        return
    endif
    let l:chunks = []
    for l:item in l:items
        call add(l:chunks,[printf('[%s]', l:item['command']['title']), 'Comment'])
    endfor
    return l:chunks
endfunction

function! neolsc#ui#vtext#codelens_clear_line(ctx, line) abort
    call s:_line_clear('_codelens', a:ctx, a:line)
endfunction

function! neolsc#ui#vtext#codelens_show_line(ctx, line) abort
    call s:_line_show('_codelens', a:ctx, a:line)
endfunction

function! neolsc#ui#vtext#codelens_clear_all(ctx) abort
    call s:_clear('_codelens', a:ctx)
endfunction

function! neolsc#ui#vtext#codelens_show_all(ctx) abort
    call s:_show('_codelens', a:ctx)
endfunction
" }}}

" documentlink {{{
function! s:_doclinks_build_chunck(ctx, line) abort
    let l:items = get(a:ctx['_doclinks'][1], a:line)
    if empty(l:items)
        return
    endif
    let l:chunks = []
    for l:item in l:items
        call add(l:chunks,[printf('-> [%s]', neolsc#utils#uri#uri_to_path(l:item['target'])), 'Comment'])
    endfor
    return l:chunks
endfunction

function! neolsc#ui#vtext#documentlink_clear_line(ctx, line) abort
    call s:_line_clear('_doclinks', a:ctx, a:line)
endfunction

function! neolsc#ui#vtext#documentlink_show_line(ctx, line) abort
    call s:_line_show('_doclinks', a:ctx, a:line)
endfunction

function! neolsc#ui#vtext#documentlink_clear_all(ctx) abort
    call s:_clear('_doclinks', a:ctx)
endfunction

function! neolsc#ui#vtext#documentlink_show_all(ctx) abort
    call s:_show('_doclinks', a:ctx)
endfunction
" }}}

" diagnostics {{{
let s:DiagnosticSeverity = {
            \ '0': ['Unknown', 'Error', 'ddlsc_error'],
            \ '1': ['Error', 'Error', 'ddlsc_error'],
            \ '2': ['Warning', 'Search', 'ddlsc_warning'],
            \ '3': ['Information', 'WildMenu', 'ddlsc_information'],
            \ '4': ['Hint', 'StatusLineNC', 'ddlsc_hint'],
            \ }

function! s:_diagnostics_build_chunck(ctx, line) abort
    let l:items = get(a:ctx['_diagnostics'][1], a:line)
    if empty(l:items)
        return
    endif
    let l:highest_severity = get(l:items[0], 'severity')
    let l:chunks = []

    for l:item in l:items
        let l:severity = get(s:DiagnosticSeverity, get(l:item, 'severity'))
        call add(l:chunks,[printf(' -> [%s]:[%s]: %s', get(l:item, 'source', a:ctx['_server']), l:severity[0], l:item['message']), l:severity[1]])
    endfor
    return l:chunks
endfunction

function! neolsc#ui#vtext#diagnostics_clear_line(ctx, line) abort
    call s:_line_clear('_diagnostics', a:ctx, a:line)
endfunction

function! neolsc#ui#vtext#diagnostics_show_line(ctx, line) abort
    call s:_line_show('_diagnostics', a:ctx, a:line)
endfunction

function! neolsc#ui#vtext#diagnostics_clear_all(ctx) abort
    call s:_clear('_diagnostics', a:ctx)
endfunction

function! neolsc#ui#vtext#diagnostics_show_all(ctx) abort
    call s:_show('_diagnostics', a:ctx)
endfunction
" }}}


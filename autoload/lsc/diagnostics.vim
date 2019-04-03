" vim: set foldmethod=marker foldlevel=0 nomodeline:

" sign {{{

let s:sign_defined = 0

function! s:sign_define() abort
    if s:sign_defined
        return
    endif
    call execute([
                \ 'sign define ddlsc_error text=E texthl=Error',
                \ 'sign define ddlsc_warning text=W texthl=Search',
                \ 'sign define ddlsc_information text=I texthl=WildMenu',
                \ 'sign define ddlsc_hint text=H texthl=StatusLineNC',
                \ ])
    let s:sign_defined = 1
endfunction

function! s:sign_undefine() abort
    if !s:sign_defined
        return
    endif

    call execute([
                \ 'sign undefine ddlsc_error',
                \ 'sign undefine ddlsc_warning',
                \ 'sign undefine ddlsc_information',
                \ 'sign undefine ddlsc_hint',
                \ ])
    let s:sign_defined = 0
endfunction

function! s:sign_place(buf, chunks) abort
    for l:item in a:chunks
        call execute(printf('sign place %d line=%d name=%s buffer=%d',
                    \ l:item[0] + 1,
                    \ l:item[0] + 1,
                    \ l:item[1], a:buf)
                    \)
    endfor
endfunction

function! s:sign_unplace(buf) abort
    call execute(printf('sign unplace * buffer=%d', a:buf))
endfunction
" }}}

" diagnostics {{{

" private {{{
function! s:position_compare(pos0, pos1) abort
    if a:pos0.line > a:pos1.line
        return 1
    elseif a:pos0.line < a:pos1.line
        return -1
    elseif a:pos0.character > a:pos1.character
        return 1
    elseif a:pos0.character < a:pos1.character
        return -1
    else
        return 0
    endif
endfunction

let s:diagnostic_ns_id = 0

let g:ddlsc_diagnostics_sign = get(g:, 'ddlsc_diagnostics_sign', 1)
let g:ddlsc_diagnostics_highlight = get(g:, 'ddlsc_diagnostics_highlight', 1)
let g:ddlsc_diagnostics_vtext = get(g:, 'ddlsc_diagnostics_vtext', 1)

let s:DiagnosticSeverity = {
            \ '0': ['Unknown', 'Error', 'ddlsc_error'],
            \ '1': ['Error', 'Error', 'ddlsc_error'],
            \ '2': ['Warning', 'Search', 'ddlsc_warning'],
            \ '3': ['Information', 'WildMenu', 'ddlsc_information'],
            \ '4': ['Hint', 'StatusLineNC', 'ddlsc_hint'],
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

function! s:Diagnostic_to_locinfo(buf, diag)
    let l:line = a:diag['range']['start']['line'] + 1
    let l:col = a:diag['range']['start']['character'] + 1
    echom json_encode(a:diag)
    let l:text = printf(' -> [%s]:[%s]: %s', get(a:diag, 'source', 'NA'), get(s:DiagnosticSeverity, get(a:diag, 'severity'))[0], a:diag['message'])
    return {'bufnr': a:buf, 'lnum': l:line, 'col': l:col, 'text': l:text}
endfunction
" }}}

" public {{{

" lsc#diagnostics#show {{{
function! lsc#diagnostics#show(fh) abort
    if s:diagnostic_ns_id == 0
        let s:diagnostic_ns_id = nvim_create_namespace('ddlsc_diagnostic')
        call s:sign_define()
    else
        call a:fh.set_virtual_text(s:diagnostic_ns_id, -1, [])
        call s:sign_unplace(a:fh._buf)
    endif
    if g:ddlsc_diagnostics_vtext == 0 && g:ddlsc_diagnostics_sign == 0
        return
    endif

    let l:diagnostics = a:fh._diagnostics[1]
    if empty(l:diagnostics)
        return
    endif

    for [l:line, l:diags] in items(l:diagnostics)

        let l:highest_severity = get(l:diags[0], 'severity')
        let l:chunks = []

        for l:diag in l:diags
            if l:diag.severity <= l:highest_severity
                let l:highest_severity = l:diag.severity
            endif
            if g:ddlsc_diagnostics_highlight
                let l:severity = get(s:DiagnosticSeverity, get(l:diag, 'severity'))
                for [l:lnum, l:sc, l:ec] in s:split_range(l:diag['range'])
                    call a:fh.add_highlight(s:diagnostic_ns_id, l:lnum, l:severity[1], l:sc, l:ec)
                endfor
            endif
            if g:ddlsc_diagnostics_vtext
                call add(l:chunks,[printf(' -> [%s]:[%s]: %s', get(l:diag, 'source', 'NA'), l:severity[0], l:diag['message']), l:severity[1]])
            endif
        endfor
        if g:ddlsc_diagnostics_vtext
            call a:fh.set_virtual_text(s:diagnostic_ns_id, str2nr(l:line), l:chunks)
        endif

        if g:ddlsc_diagnostics_sign
            call s:sign_place(a:fh._buf, [[str2nr(line), get(s:DiagnosticSeverity, get(l:diag, 'severity'))[2]]])
        endif
    endfor
endfunction
" }}}

" {{{
function! lsc#diagnostics#list_diagnostics(fh) abort
    let l:diagnostics =a:fh._diagnostics[0]
    if empty(l:diagnostics)
        return
    endif
    let l:locs = []
    for l:diag in l:diagnostics
        call add(l:locs, s:Diagnostic_to_locinfo(a:fh._buf, l:diag))
    endfor
    call setloclist(0, l:diagnostics)
    call lsc#locations#locations_ui(0)
endfunction

function! lsc#diagnostics#list_workspace_diagnostics(fhs) abort
    let l:locs = []

    for l:fh in values(a:fhs)
        let l:diagnostics =l:fh._diagnostics[0]
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
    call lsc#locations#locations_ui(0)
endfunction

" {{{
function! lsc#diagnostics#prev(fh, line, character) abort
    let l:diagnostics = a:fh._diagnostics[0]

    if empty(l:diagnostics)
        return
    endif

    let l:to = l:diagnostics[-1]['range']['start']
    let l:cur = {'line': a:line, 'character': a:character}

    for l:diag in a:fh._diagnostics
        let l:pos = l:diag['range']['end']
        if s:position_compare(l:cur, l:pos) > 0
            let l:to = l:diag['range']['start']
            break
        endif
    endfor
    call setpos('.', [a:fh._buf, l:to['line'] + 1, l:to['character'] + 1, 0])
endfunction

function! lsc#diagnostics#next(fh, line, character) abort
    let l:diagnostics = a:fh._diagnostics[0]

    if empty(l:diagnostics)
        return
    endif

    let l:to = l:diagnostics[0]['range']['start']
    let l:cur = {'line': a:line, 'character': a:character}

    for l:diag in a:fh._diagnostics
        let l:pos = l:diag['range']['start']
        if s:position_compare(l:cur, l:pos) < 0
            let l:to = l:pos
            break
        endif
    endfor
    call setpos('.', [a:fh._buf, l:to['line'] + 1, l:to['character'] + 1, 0])
endfunction


function! lsc#diagnostics#update(fh, diagnostics) abort
    if empty(a:diagnostics)
        let a:fh._diagnostics[0] = []
        let a:fh._diagnostics[1] = {}
        return
    endif

    call sort(a:diagnostics, {d0, d1 -> s:position_compare(d0['range']['start'], d1['range']['start'])})
    let a:fh._diagnostics[0] = a:diagnostics

    for l:diag in a:diagnostics
        let l:line = l:diag['range']['start']['line']
        let a:fh._diagnostics[1][l:line] = add(get(a:fh._diagnostics[1], l:line, []), l:diag)
    endfor
endfunction
" }}}
" }}}
" }}}
" }}}

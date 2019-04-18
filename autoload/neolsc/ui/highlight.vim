" vim: set foldmethod=marker foldlevel=0 nomodeline:

" private {{{
function! s:_range_split(range) abort
    let l:ret = []

    let l:sl = a:range['start']['line']
    let l:el = a:range['end']['line']
    let l:sc = a:range['start']['character']
    let l:ec = a:range['end']['character']

    if l:ec == 0
        let l:el -= 1
        let l:ec = -1
    endif

    for l:line in range(l:sl, l:el)
        let l:lsc = l:line == l:sl ? l:sc : 0
        let l:lec = l:line == l:el ? l:ec : -1
        call add(l:ret, [l:line, l:lsc, l:lec])
    endfor
    return l:ret
endfunction
" }}}

" documentHighlight {{{
let s:neolsc_document_highlight_id = nvim_create_namespace('neolsc_document_highlight')

if &background ==# 'dark'
  hi default NeolscHighlightText  guibg=#222222 ctermbg=233
else
  hi default NeolscHighlightText  guibg=#f9f9f9 ctermbg=15
endif
hi default link NeolscHighlightRead  NeolscHighlightText
hi default link NeolscHighlightWrite NeolscHighlightText

let s:DocumentHighlightKind = {
            \ '0': ['Text', 'NeolscHighlightText'],
            \ '1': ['Text', 'NeolscHighlightText'],
            \ '2': ['Read', 'NeolscHighlightRead'],
            \ '3': ['Write', 'NeolscHighlightWrite'],
            \ }

function! neolsc#ui#highlight#document_clear(buf) abort
    call nvim_buf_clear_namespace(a:buf, s:neolsc_document_highlight_id, 0, -1)
endfunction

function! neolsc#ui#highlight#document_show(buf, highlights) abort
    call neolsc#ui#highlight#document_clear(a:buf)
    if empty(a:highlights)
        return
    endif
    for l:highlight in a:highlights
        let l:hlg = get(s:DocumentHighlightKind, get(l:highlight, 'kind'))[1]
        for [l:line, l:sc, l:ec] in s:_range_split(l:highlight['range'])
            call nvim_buf_add_highlight(a:buf, s:neolsc_document_highlight_id, l:hlg, l:line, l:sc, l:ec)
        endfor
    endfor
endfunction
" }}}

" skippedHighlight {{{
let s:neolsc_skipped_highlight_id = nvim_create_namespace('neolsc_skipped_highlight')

function! neolsc#ui#highlight#skipped_clear(buf) abort
    call nvim_buf_clear_namespace(a:buf, s:neolsc_skipped_highlight_id, 0, -1)
endfunction

function! neolsc#ui#highlight#skipped_show(buf, ranges) abort
    call neolsc#ui#highlight#skipped_clear(a:buf)
    for l:range in a:ranges
        for [l:line, l:sc, l:ec] in s:_range_split(l:range)
            call nvim_buf_add_highlight(a:buf, s:neolsc_skipped_highlight_id, 'Comment', l:line, l:sc, l:ec)
        endfor
    endfor
endfunction

function! neolsc#ui#highlight#skipped_draw(server, notification) abort
    let l:skipped = get(a:notification, 'params')
    let l:uri = l:skipped['uri']
    let l:buf = bufnr(neolsc#utils#uri#uri_to_path(l:uri))

    call neolsc#ui#highlight#skipped_show(l:buf, l:skipped['skippedRanges'])
endfunction
" }}}

" diagnosticsHighlight {{{
let s:neolsc_diagnostics_highlight_id = nvim_create_namespace('neolsc_diagnostics_highlight')

function! neolsc#ui#highlight#diagnostics_clear(buf) abort
    call nvim_buf_clear_namespace(a:buf, s:neolsc_diagnostics_highlight_id, 0, -1)
endfunction

let s:DiagnosticSeverity = {
            \ '0': ['Unknown', 'Error', 'ddlsc_error'],
            \ '1': ['Error', 'Error', 'ddlsc_error'],
            \ '2': ['Warning', 'Search', 'ddlsc_warning'],
            \ '3': ['Information', 'WildMenu', 'ddlsc_information'],
            \ '4': ['Hint', 'StatusLineNC', 'ddlsc_hint'],
            \ }

function! neolsc#ui#highlight#diagnostics_show(buf) abort
    call neolsc#ui#highlight#diagnostics_clear(a:buf)
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    let l:diagnostics = l:buf_ctx['_diagnostics'][0]

    for l:diag in l:diagnostics
        let l:severity = get(s:DiagnosticSeverity, get(l:diag, 'severity'))
        for [l:lnum, l:sc, l:ec] in s:_range_split(l:diag['range'])
            call nvim_buf_add_highlight(a:buf, s:neolsc_diagnostics_highlight_id, l:severity[1], l:lnum, l:sc, l:ec)
        endfor
    endfor
endfunction
" }}}

" semanticHighlight {{{
let s:neolsc_semantic_highlight_id = nvim_create_namespace('neolsc_semantic_highlight')

hi default Member ctermfg=LightBlue guifg=LightBlue
hi default Variable ctermfg=Grey guifg=Grey
hi default Namespace ctermfg=Yellow guifg=#BBBB00
hi default Typedef ctermfg=Yellow gui=bold guifg=#BBBB00
hi default EnumConstant ctermfg=LightGreen guifg=LightGreen
hi default chromaticaException ctermfg=Yellow gui=bold guifg=#B58900
hi default chromaticaCast ctermfg=Green gui=bold guifg=#719E07
hi default OperatorOverload cterm=bold ctermfg=14 gui=bold guifg=#268bd2
hi default AccessQual cterm=underline ctermfg=81 gui=bold guifg=#6c71c4
hi default Linkage ctermfg=239 guifg=#09AA08
hi default AutoType ctermfg=Yellow guifg=#cb4b16

hi link ddlsc_Unknown Normal
hi link ddlsc_File Namespace
hi link ddlsc_Module Namespace
hi link ddlsc_Namespace Namespace
hi link ddlsc_Package Namespace
hi link ddlsc_Class Type
hi link ddlsc_Method Function
hi link ddlsc_Property Normal
hi link ddlsc_Field Member
hi link ddlsc_Constructor Function
hi link ddlsc_Enum Type
hi link ddlsc_Interface Normal
hi link ddlsc_Function Function
hi link ddlsc_Variable Variable
hi link ddlsc_Constant Constant
hi link ddlsc_String String
hi link ddlsc_Number Number
hi link ddlsc_Boolean Boolean
hi link ddlsc_Array Variable
hi link ddlsc_Object Variable
hi link ddlsc_Key Macro
hi link ddlsc_Null Constant
hi link ddlsc_EnumMember Constant
hi link ddlsc_Struct Type
hi link ddlsc_Event Macro
hi link ddlsc_Operator Operator
hi link ddlsc_TypeParameter Identifier
hi link ddlsc_TypeAlias Type
hi link ddlsc_Parameter Variable
hi link ddlsc_StaticMethod Function
hi link ddlsc_Macro Macro

let s:SemanticHighlightKind = {
            \ '0': 'ddlsc_Unknown',
            \ '1': 'ddlsc_File',
            \ '2': 'ddlsc_Module',
            \ '3': 'ddlsc_Namespace',
            \ '4': 'ddlsc_Package',
            \ '5': 'ddlsc_Class',
            \ '6': 'ddlsc_Method',
            \ '7': 'ddlsc_Property',
            \ '8': 'ddlsc_Field',
            \ '9': 'ddlsc_Constructor',
            \ '10': 'ddlsc_Enum',
            \ '11': 'ddlsc_Interface',
            \ '12': 'ddlsc_Function',
            \ '13': 'ddlsc_Variable',
            \ '14': 'ddlsc_Constant',
            \ '15': 'ddlsc_String',
            \ '16': 'ddlsc_Number',
            \ '17': 'ddlsc_Boolean',
            \ '18': 'ddlsc_Array',
            \ '19': 'ddlsc_Object',
            \ '20': 'ddlsc_Key',
            \ '21': 'ddlsc_Null',
            \ '22': 'ddlsc_EnumMember',
            \ '23': 'ddlsc_Struct',
            \ '24': 'ddlsc_Event',
            \ '25': 'ddlsc_Operator',
            \ '26': 'ddlsc_TypeParameter',
            \ '252': 'ddlsc_TypeAlias',
            \ '253': 'ddlsc_Parameter',
            \ '254': 'ddlsc_StaticMethod',
            \ '255': 'ddlsc_Macro',
            \ }

function! neolsc#ui#highlight#semantic_clear(buf)
    call nvim_buf_clear_namespace(a:buf, s:neolsc_semantic_highlight_id, 0, -1)
endfunction

function! neolsc#ui#highlight#semantic_show(buf, highlights)
    call neolsc#ui#highlight#semantic_clear(a:buf)

    for l:highlight in a:highlights
        let l:hlg = get(s:SemanticHighlightKind, get(l:highlight, 'kind'))
        for l:range in get(l:highlight, 'lsRanges')
            for [l:line, l:sc, l:ec] in s:_range_split(l:range)
                call nvim_buf_add_highlight(a:buf, s:neolsc_semantic_highlight_id, l:hlg, l:line, l:sc, l:ec)
            endfor
        endfor
    endfor
endfunction

function! neolsc#ui#highlight#semantic_draw(server, notification) abort
    let l:semantic_highlights = get(a:notification, 'params')
    let l:uri = l:semantic_highlights['uri']
    let l:buf = bufnr(neolsc#utils#uri#uri_to_path(l:uri))

    call neolsc#ui#highlight#semantic_show(l:buf, l:semantic_highlights['symbols'])
endfunction
" }}}

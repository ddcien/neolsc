" vim: set foldmethod=marker foldlevel=0 nomodeline:

" SemanticHighlight {{{
let s:semantic_highlight_ns_id = 0

hi link ddlsc_Unknown Macro
hi link ddlsc_File Macro
hi link ddlsc_Module Macro
hi link ddlsc_Namespace Macro
hi link ddlsc_Package Macro
hi link ddlsc_Class Macro
hi link ddlsc_Method Macro
hi link ddlsc_Property Macro
hi link ddlsc_Field Macro
hi link ddlsc_Constructor Macro
hi link ddlsc_Enum Macro
hi link ddlsc_Interface Macro
hi link ddlsc_Function Macro
hi link ddlsc_Variable Macro
hi link ddlsc_Constant Constant
hi link ddlsc_String String
hi link ddlsc_Number Numbers
hi link ddlsc_Boolean Boolean
hi link ddlsc_Array Macro
hi link ddlsc_Object Macro
hi link ddlsc_Key Macro
hi link ddlsc_Null Macro
hi link ddlsc_EnumMember Macro
hi link ddlsc_Struct Macro
hi link ddlsc_Event Macro
hi link ddlsc_Operator Macro
hi link ddlsc_TypeParameter Macro
hi link ddlsc_TypeAlias Macro
hi link ddlsc_Parameter Macro
hi link ddlsc_StaticMethod Macro
hi link ddlsc_Macro Macro


let s:SymbolKindHL = {
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

function! s:parse_highlight(hl)
    let l:list = []

    let l:hl = get(s:SymbolKindHL, get(a:hl, 'kind'))

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

function! lsc#semantichighlight#handle_semantic_highlight(fh, symbols) abort
    if s:semantic_highlight_ns_id == 0
        let s:semantic_highlight_ns_id = nvim_create_namespace('ddlsc_semantic_highlight')
    else
        call a:fh.set_virtual_text(s:semantic_highlight_ns_id, -1, [])
    endif

    if empty(a:symbols)
        return
    endif

    let l:hls = []

    for l:shl in a:symbols
        let l:str = get(l:shl, 'storage')
        let l:knd = get(l:shl, 'kind')
        let l:rgs = get(l:shl, 'lsRanges')

        for l:rg in l:rgs
            call add(l:hls, {'range': l:rg, 'kind': l:knd})
        endfor
    endfor

    for l:hl in l:hls
        for [l:hl, l:line, l:sc, l:ec] in s:parse_highlight(l:hl)
            call a:fh.add_highlight(s:semantic_highlight_ns_id, str2nr(l:line), l:hl, l:sc, l:ec)
        endfor
    endfor
endfunction
" }}}

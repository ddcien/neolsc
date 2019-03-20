" vim: set foldmethod=marker foldlevel=0 nomodeline:

" symbols {{{
let s:symbol_kinds = {
            \ '1': 'File',
            \ '2': 'Module',
            \ '3': 'Namespace',
            \ '4': 'Package',
            \ '5': 'Class',
            \ '6': 'Method',
            \ '7': 'Property',
            \ '8': 'Field',
            \ '9': 'Constructor',
            \ '10': 'Enum',
            \ '11': 'Interface',
            \ '12': 'Function',
            \ '13': 'Variable',
            \ '14': 'Constant',
            \ '15': 'String',
            \ '16': 'Number',
            \ '17': 'Boolean',
            \ '18': 'Array',
            \ '19': 'Object',
            \ '20': 'Key',
            \ '21': 'Null',
            \ '22': 'EnumMember',
            \ '23': 'Struct',
            \ '24': 'Event',
            \ '25': 'Operator',
            \ '26': 'TypeParameter',
            \ }

function! s:SymbolInformation_to_locinfo(sym)
    let l:loc = a:sym.location
    let l:path = resolve(lsc#uri#uri_to_path(l:loc.uri))
    let l:line = l:loc['range']['start']['line']
    let l:col = l:loc['range']['start']['character']
    let l:text = ' ->: ' . get(s:symbol_kinds, a:sym.kind, 'Unknown[' . string(a:sym.kind) . ']') . ':' . get(a:sym, 'containerName', a:sym.name)
    return {'filename': l:path, 'lnum': l:line + 1, 'col': l:col + 1, 'text': l:text}
endfunction

function! s:DocumentSymbol_to_locinfo(buf, sym)
    let l:line = a:sym['range']['start']['line']
    let l:col = a:sym['range']['start']['character']
    let l:text = ' ->: '. get(s:symbol_kinds, a:sym.kind, 'Unknown[' . string(a:sym.kind) . ']') . ':' . get(a:sym, 'detail', a:sym.name)
    return {'bufnr': a:buf, 'lnum': l:line + 1, 'col': l:col + 1, 'text': l:text}
endfunction

function! lsc#symbols#handle_symbols(buf, response)
    let l:symbols = a:response.result
    if empty(l:symbols)
        return
    endif
    if has_key(l:symbols[0], 'location')
        call map(l:symbols, {_, sym -> s:SymbolInformation_to_locinfo(sym)})
    else
        call map(l:symbols, {_, sym -> s:DocumentSymbol_to_locinfo(a:buf, sym)})
    endif
    call setloclist(0, l:symbols)
    call lsc#locations#locations_ui(0)
endfunction
" }}}

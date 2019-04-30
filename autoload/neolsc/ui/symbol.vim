" vim: set foldmethod=marker foldlevel=0 nomodeline:

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

function! s:SymbolInformation_to_locinfo(sym) abort
    let l:loc = a:sym.location
    let l:path = neolsc#utils#uri#uri_to_path(l:loc.uri)
    let l:line = l:loc['range']['start']['line']
    let l:col = l:loc['range']['start']['character']
    let l:text = get(s:symbol_kinds, a:sym.kind, 'Unknown[' . string(a:sym.kind) . ']') . ':' . a:sym.name
    return {'filename': l:path, 'lnum': l:line + 1, 'col': l:col + 1, 'text': l:text}
endfunction

function! s:DocumentSymbol_to_locinfo(buf, sym) abort
    let l:line = a:sym['range']['start']['line']
    let l:col = a:sym['range']['start']['character']
    let l:text = get(s:symbol_kinds, a:sym.kind, 'Unknown[' . string(a:sym.kind) . ']') . ':' . get(a:sym, 'detail', a:sym.name)
    return {'filename': bufname(a:buf), 'lnum': l:line + 1, 'col': l:col + 1, 'text': l:text}
endfunction


function! neolsc#ui#symbol#workspace_symbol_handler(ctx) abort
    call assert_equal(0, a:ctx['server_count'])
    let l:location_list = []
    for [l:server_name, l:symbol_list] in items(a:ctx['server_list'])
        for l:symbol in l:symbol_list
            call add(l:location_list, s:SymbolInformation_to_locinfo(l:symbol))
        endfor
    endfor
    if empty(l:location_list)
        return
    endif
    call neolsc#ui#location#show('WorkspaceSymbol', l:location_list, v:false)
endfunction

function! neolsc#ui#symbol#textDocument_symbol_handler(buf, symbol_list) abort
    let l:location_list = []
    for l:symbol in a:symbol_list
        if has_key(l:symbol, 'location')
            call add(l:location_list, s:SymbolInformation_to_locinfo(l:symbol))
        else
            call add(l:location_list, s:DocumentSymbol_to_locinfo(a:buf, l:symbol))
        endif
    endfor
    if empty(l:location_list)
        return
    endif
    call neolsc#ui#location#show('DocumentSymbol', l:location_list, v:false)
endfunction

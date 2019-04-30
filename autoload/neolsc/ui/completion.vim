" vim: set foldmethod=marker foldlevel=0 nomodeline:

" omni {{{
function! s:_get_typed() abort
    let l:curpos = getcurpos()
    let l:bcol = l:curpos[2]
    let l:typed = strpart(getline('.'), 0, l:bcol - 1)
    return l:typed
endfunction

function! s:_get_current_position() abort
    let [_, l:lnum, l:col; _] = getcurpos()
    return {'line': l:lnum - 1, 'character': l:col - 1}
endfunction

let s:CompletionItemKind = {
            \    '0': 'Unknown',
            \    '1': 'Text',
            \    '2': 'Method',
            \    '3': 'Function',
            \    '4': 'Constructor',
            \    '5': 'Field',
            \    '6': 'Variable',
            \    '7': 'Class',
            \    '8': 'Interface',
            \    '9': 'Module',
            \    '10': 'Property',
            \    '11': 'Unit',
            \    '12': 'Value',
            \    '13': 'Enum',
            \    '14': 'Keyword',
            \    '15': 'Snippet',
            \    '16': 'Color',
            \    '17': 'File',
            \    '18': 'Reference',
            \    '19': 'Folder',
            \    '20': 'EnumMember',
            \    '21': 'Constant',
            \    '22': 'Struct',
            \    '23': 'Event',
            \    '24': 'Operator',
            \    '25': 'TypeParameter',
            \ }

function! s:CompletionItem_get_info(item) abort
    let l:documentation = get(a:item, 'documentation', a:item.label)

    if type(l:documentation) == v:t_string
        return l:documentation
    endif

    if get(l:documentation, 'kind') ==# 'plaintext'
        return get(l:documentation, 'value')
    endif

    return join(['```', get(l:documentation, 'value'), '```'], "\n")
endfunction

function! s:CompletionItem_get_menu(item) abort
    let l:detail = get(a:item, 'detail')
    if empty(l:detail)
        return ''
    endif
    return split(l:detail, "\n")[0]
endfunction

function! s:CompletionItem_get_word_snippet(item) abort
    let l:edit = get(a:item, 'textEdit')
    let l:fmt = get(a:item, 'insertTextFormat', 1)
    let l:word = get(a:item, 'filterText', get(a:item, 'label'))

    if l:fmt == 2
        if empty(l:edit)
            let l:snippet = substitute(a:item.insertText, '\%x00', '\\n', 'g')
        else
            let l:snippet = substitute(l:edit.newText, '\%x00', '\\n', 'g')
        endif
    else
        if empty(l:edit)
            let l:word = get(a:item, 'insertText', l:word)
        else
            let l:word = get(l:edit, 'newText')
        endif
        let l:snippet = substitute(l:word . '$0', '\%x00', '\\n', 'g')
    endif
    return [l:word, l:snippet]
endfunction

function! s:CompletionItem_get_word(item) abort
    if has_key(a:item, 'textEdit')
        return a:item['textEdit']['newText']
    elseif has_key(a:item, 'insertText')
        return a:item['insertText']
    endif
endfunction

function! s:build_complete_item(item, typed) abort
    let l:ret = {
                \ 'neolsc_start': s:_get_start(a:item, a:typed),
                \ 'word': s:CompletionItem_get_word(a:item),
                \ 'menu': s:CompletionItem_get_menu(a:item),
                \ 'info': s:CompletionItem_get_info(a:item),
                \ 'abbr': get(a:item, 'filterText', a:item['label']),
                \ 'kind' : get(s:CompletionItemKind, get(a:item, 'kind')),
                \ 'icase': 1,
                \ 'dup': 1,
                \ 'empty': 0,
                \ }
    return l:ret
endfunction


function! s:_get_start(item, typed) abort
    if has_key(a:item, 'textEdit')
        return a:item['textEdit']['range']['start']['character']
    endif

    let l:insert = get(a:item, 'insertText')
    let l:len_typed = len(a:typed)
    let l:len_insert = len(l:insert)
    let l:count = min([l:len_typed, l:len_insert])

    if l:count < 0
        return 0
    endif

    while l:count >= 0
        let l:a = strpart(l:insert, 0, l:count)
        let l:b = strpart(a:typed, l:len_typed - l:count, l:count)
        if l:a ==# l:b
            return l:len_typed - l:count
        endif
        let l:count -= 1
    endwhile
endfunction

function! neolsc#ui#completion#completion_handler(server, typed, response)
    let l:CompletionList = get(a:response, 'result')
    if empty(l:CompletionList)
        return [-1, []]
    endif
    if type(l:CompletionList) == v:t_list
        let l:CompletionList = {'isIncomplete': v:false, 'items': l:CompletionList}
    endif
    let l:items = get(l:CompletionList, 'items')
    if empty(l:items)
        return [-1, []]
    endif

    let l:result = []

    let l:start = len(a:typed)
    for l:item in l:items
        let l:_item = s:build_complete_item(l:item, a:typed)
        if l:_item['neolsc_start'] < l:start
            let l:start = l:_item['neolsc_start']
        endif
        call add(l:result, l:_item)
    endfor

    for l:item in l:result
        if l:item['neolsc_start'] > l:start
            let l:item['word'] = strpart(a:typed, l:start, l:item['neolsc_start'] - l:start) . l:item['word']
        endif
        call remove(l:item, 'neolsc_start')
    endfor

    return [l:start + 1, l:result]
endfunction

function! s:_on_omni(server, typed, response) abort
    let [l:start, l:result] = neolsc#ui#completion#completion_handler(a:server, a:typed, a:response)
    if empty(l:result)
        return
    endif
    call complete(l:start, l:result)
endfunction

function! neolsc#ui#completion#omni(findstart, base) abort
    if a:findstart
        return col('.')
    endif

    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_completion()
        return
    endif

    let l:typed = s:_get_typed()
    let l:char = strcharpart(l:typed, strchars(l:typed) - 1, 1)

    if index(l:server.capabilities_completion_triggerCharacters(), l:char) >= 0
        let l:context = {'triggerKind': 2, 'triggerCharacter': l:char}
    else
        let l:context = {'triggerKind': 1}
    endif

    let l:position = s:_get_current_position()
    let l:request = {
                \ 'method': 'textDocument/completion',
                \ 'params': {
                \     'textDocument':{
                \         'uri': neolsc#utils#uri#buf_to_uri(l:buf),
                \     },
                \     'position': l:position,
                \     'context': l:context
                \ }
                \ }
    call neolsc#ui#textDocumentSynchronization#didChangeBuf(l:buf)
    call l:server.send_request(l:request, {server, response -> s:_on_omni(server, l:typed, response)})

    redraws
    return []
endfunction
" }}}

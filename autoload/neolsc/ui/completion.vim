" vim: set foldmethod=marker foldlevel=0 nomodeline:

" omni {{{
function! s:_get_current_character() abort
    let l:line = nvim_get_current_line()
    if empty(l:line)
        return
    endif
    if mode() ==# 'i'
        let l:char = l:line[col('.') - 2]
    else
        let l:char = l:line[col('.') - 1]
    endif
    return l:char
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

function! s:build_complete_item(item) abort
    let l:ret = {
                \ 'menu': s:CompletionItem_get_menu(a:item),
                \ 'info': s:CompletionItem_get_info(a:item),
                \ 'abbr': get(a:item, 'filterText', a:item['label']),
                \ 'kind' : get(s:CompletionItemKind, get(a:item, 'kind')),
                \ 'icase': 1,
                \ 'dup': 1,
                \ 'empty': 0,
                \ }
    let l:word_snippet = s:CompletionItem_get_word_snippet(a:item)
    let l:ret['word'] = l:word_snippet[0]
    " let l:ret['user_data'] = json_encode(l:word_snippet)
    return l:ret
endfunction

function! neolsc#ui#completion#completion_handler(server, response)
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
    let l:start = l:items[0]['textEdit']['range']['start']['character']

    for l:item in l:items
        if l:item['textEdit']['range']['start']['character'] < l:start
            let l:start = l:item['textEdit']['range']['start']['character']
        endif
        call add(l:result, s:build_complete_item(l:item))
    endfor

    let l:idx = 0
    let l:line = nvim_get_current_line()
    while l:idx < len(l:result)
        let l:ls_start = l:items[l:idx]['textEdit']['range']['start']['character']
        let l:cp_item = l:result[l:idx]
        if l:ls_start > l:start
            let l:cp_item['word']  = l:line[: l:start - 1] . l:line[l:start : l:ls_start - 1] . l:cp_item['word']
        endif
        let l:idx += 1
    endwhile

    return [l:start + 1, l:result]
endfunction

function! s:_on_omni(server, response) abort
    let [l:start, l:result] = neolsc#ui#completion#completion_handler(a:server, a:response)
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

    let l:char = s:_get_current_character()
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
    call l:server.send_request(l:request, {server, response -> s:_on_omni(server, response)})

    redraws
    return []
endfunction
" }}}

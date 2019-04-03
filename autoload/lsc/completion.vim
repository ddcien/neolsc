" vim: set foldmethod=marker foldlevel=0 nomodeline:

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
    let l:documentation = get(a:item, 'documentation', 'NA')
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
                \ 'empty': 0
                \ }
    let l:word_snippet = s:CompletionItem_get_word_snippet(a:item)
    let l:ret['word'] = l:word_snippet[0]
    let l:ret['user_data'] = json_encode(l:word_snippet)

    return l:ret
endfunction


function! lsc#completion#handle_completion(CompletionList) abort
    if empty(a:CompletionList)
        return
    endif

    " TODO: handle isIncomplete
    let l:items = get(a:CompletionList, 'items')
    if empty(l:items)
        return
    endif

    " TODO(Richard): Get start more securely and flexibly.
    let l:start = l:items[0].textEdit.range.start.character + 1

    call map(l:items, {_, item -> s:build_complete_item(item)})

    setlocal completeopt=menuone,noinsert,noselect,preview
    call complete(l:start, l:items)
endfunction

function! s:handle_snippet(item) abort
    if empty(a:item)
        return
    endif
    let l:user_data = json_decode(get(a:item, 'user_data'))
    call UltiSnips#Anon(l:user_data[1], l:user_data[0], '', 'i')
endfunction


augroup lsp_ultisnips
    autocmd!
    autocmd CompleteDone * call s:handle_snippet(v:completed_item)
augroup END

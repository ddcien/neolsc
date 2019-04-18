" vim: set foldmethod=marker foldlevel=0 nomodeline:

" private {{{
function! s:_get_visual_selection_pos() abort
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return [0, 0, 0, 0]
    endif
    let lines[- 1] = lines[- 1][: column_end - (&selection ==# 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return [line_start, column_start, line_end, len(lines[- 1])]
endfunction

function! s:_get_visual_selection_range() abort
    let [l:start_lnum, l:start_col, l:end_lnum, l:end_col] = s:_get_visual_selection_pos()
    return {
                \    'start': { 'line': l:start_lnum - 1, 'character': l:start_col - 1 },
                \    'end': { 'line': l:end_lnum - 1, 'character': l:end_col - 1 },
                \ }
endfunction

function! s:_get_current_position() abort
    let [_, l:lnum, l:col; _] = getcurpos()
    return {'line': l:lnum - 1, 'character': l:col - 1}
endfunction

function! s:_get_formating_option(buf) abort
    return {
                \ 'tabSize': getbufvar(a:buf, '&tabstop'),
                \ 'insertSpaces': getbufvar(a:buf, '&expandtab') ? v:true : v:false,
                \ }
endfunction

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
" }}}

" completion {{{
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
                \ 'empty': 0
                \ }
    let l:word_snippet = s:CompletionItem_get_word_snippet(a:item)
    let l:ret['word'] = l:word_snippet[0]
    let l:ret['user_data'] = json_encode(l:word_snippet)
    return l:ret
endfunction

function! neolsc#ui#textDocument#completion_handler(server, response, buf)
    let l:CompletionList = get(a:response, 'result')
    if empty(l:CompletionList)
        return
    endif
    if type(l:CompletionList) == v:t_list
        let l:CompletionList = {'isIncomplete': v:false, 'items': l:CompletionList}
    endif
    let l:items = get(l:CompletionList, 'items')
    if empty(l:items)
        return
    endif

    let l:result = []
    for l:item in l:items
        call add(l:result, s:build_complete_item(l:item))
    endfor
    let l:start = l:items[0].textEdit.range.start.character + 1
    call complete(l:start, l:result)
endfunction

function! neolsc#ui#textDocument#completion() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_completion()
        return
    endif

    let l:char = s:_get_current_character()
    let l:position = s:_get_current_position()
    if index(l:server.capabilities_completion_triggerCharacters, l:char) >= 0
        call neolsc#lsp#textDocument#completion(l:server, l:buf, l:position, 2, l:char)
    else
        call neolsc#lsp#textDocument#completion(l:server, l:buf, l:position, 1, '')
    endif
endfunction
" }}}

" hover : done {{{
function! neolsc#ui#textDocument#hover_handler(server, response, buf)
    let l:hover = get(a:response, 'result')
    if empty(l:hover)
        return
    endif
    call neolsc#ui#hover#show(l:hover)
endfunction

function! neolsc#ui#textDocument#hover() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif

    if !l:server.capabilities_hover()
        return
    endif

    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#hover(l:server, l:buf, l:position)
endfunction
" }}}

" signatureHelp {{{
function! neolsc#ui#textDocument#signatureHelp_handler(server, response, buf)
    echomsg json_encode(a:response)
    "TODO(Richard):
endfunction

function! neolsc#ui#textDocument#signatureHelp() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_signatureHelp()
        return
    endif

    " let l:char = s:_get_current_character()
    " if index(l:server.capabilities_signatureHelp_triggerCharacters(), l:char) < 0
        " return
    " endif
    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#signatureHelp(l:server, l:buf, l:position)
endfunction
" }}}

" declaration : done {{{
function! neolsc#ui#textDocument#declaration_handler(server, response, buf)
    let l:lsp_location_list = get(a:response, 'result', [])
    if empty(l:lsp_location_list)
        return
    endif
    if type(l:lsp_location_list) != v:t_list
        let l:lsp_location_list = [l:lsp_location_list]
    endif
    let l:location_list = neolsc#ui#location#to_location_list(l:lsp_location_list, v:false)
    call neolsc#ui#location#show('Declaration', location_list, v:true)
endfunction

function! neolsc#ui#textDocument#declaration() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    " if !l:server.capabilities_declaration()
        " return
    " endif
    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#declaration(l:server, l:buf, l:position)
endfunction
" }}}

" definition : done {{{
function! neolsc#ui#textDocument#definition_handler(server, response, buf)
    let l:lsp_location_list = get(a:response, 'result', [])
    if empty(l:lsp_location_list)
        return
    endif
    if type(l:lsp_location_list) != v:t_list
        let l:lsp_location_list = [l:lsp_location_list]
    endif
    let l:location_list = neolsc#ui#location#to_location_list(l:lsp_location_list, v:false)
    call neolsc#ui#location#show('Definition', location_list, v:true)
endfunction

function! neolsc#ui#textDocument#definition() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_definition()
        return
    endif
    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#definition(l:server, l:buf, l:position)
endfunction
" }}}

" typeDefinition : done {{{
function! neolsc#ui#textDocument#typeDefinition_handler(server, response, buf)
    let l:lsp_location_list = get(a:response, 'result', [])
    if empty(l:lsp_location_list)
        return
    endif
    if type(l:lsp_location_list) != v:t_list
        let l:lsp_location_list = [l:lsp_location_list]
    endif
    let l:location_list = neolsc#ui#location#to_location_list(l:lsp_location_list, v:false)
    call neolsc#ui#location#show('TypeDefinition', location_list, v:true)
endfunction

function! neolsc#ui#textDocument#typeDefinition() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_typeDefinition()
        return
    endif
    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#typeDefinition(l:server, l:buf, l:position)
endfunction
" }}}

" implementation : done {{{
function! neolsc#ui#textDocument#implementation_handler(server, response, buf)
    let l:lsp_location_list = get(a:response, 'result', [])
    if empty(l:lsp_location_list)
        return
    endif
    if type(l:lsp_location_list) != v:t_list
        let l:lsp_location_list = [l:lsp_location_list]
    endif
    let l:location_list = neolsc#ui#location#to_location_list(l:lsp_location_list, v:false)
    call neolsc#ui#location#show('Implementation', location_list, v:true)
endfunction

function! neolsc#ui#textDocument#implementation() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_implementation()
        return
    endif
    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#implementation(l:server, l:buf, l:position)
endfunction
" }}}

" references : done {{{
function! neolsc#ui#textDocument#references_handler(server, response, buf)
    let l:lsp_location_list = get(a:response, 'result', [])
    if empty(l:lsp_location_list)
        return
    endif
    if type(l:lsp_location_list) != v:t_list
        let l:lsp_location_list = [l:lsp_location_list]
    endif
    let l:location_list = neolsc#ui#location#to_location_list(l:lsp_location_list, v:false)
    call neolsc#ui#location#show('References', location_list, v:false)
endfunction

function! neolsc#ui#textDocument#references() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_references()
        return
    endif
    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#references(l:server, l:buf, l:position, v:false)
endfunction
" }}}

" documentHighlight : done {{{
function! neolsc#ui#textDocument#documentHighlight_handler(server, response, buf)
    let l:highlights = get(a:response, 'result')
    call neolsc#ui#highlight#document_show(a:buf, l:highlights)
endfunction

function! neolsc#ui#textDocument#documentHighlight() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_documentHighlight()
        return
    endif
    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#documentHighlight(l:server, l:buf, l:position)
endfunction
" }}}

" documentSymbol : done {{{
function! neolsc#ui#textDocument#documentSymbol_handler(server, response, buf)
    let l:symbol_list = get(a:response, 'result', [])
    if empty(l:symbol_list)
        return
    endif
    call neolsc#ui#symbol#textDocument_symbol_handler(a:buf, l:symbol_list)
endfunction

function! neolsc#ui#textDocument#documentSymbol() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_documentSymbol()
        return
    endif
    call neolsc#lsp#textDocument#documentSymbol(l:server, l:buf)
endfunction
" }}}

" codeAction : done {{{
function! neolsc#ui#textDocument#codeAction_handler(server, response, buf, all)
    let l:actions = get(a:response, 'result')
    if type(l:actions) != v:t_list
        return
    endif

    if a:all
        call neolsc#ui#codeaction#update(a:server, l:actions, a:buf)
        return
    endif

    if empty(l:actions)
        return
    endif
    call neolsc#ui#codeaction#apply(a:server, l:actions, v:true)
endfunction

function! neolsc#ui#textDocument#codeAction() abort
    let l:buf = nvim_get_current_buf()
    let l:ctx = neolsc#ui#workfile#get(l:buf)
    if empty(l:ctx)
        return
    endif
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_codeAction()
        return
    endif

    let l:diagnostics = l:ctx['_diagnostics'][0]

    if empty(l:diagnostics)
        return
    endif

    call neolsc#lsp#textDocument#codeAction(l:server, l:buf, v:true, l:diagnostics)
endfunction

function! neolsc#ui#textDocument#lineCodeAction() abort
    let l:buf = nvim_get_current_buf()
    let l:ctx = neolsc#ui#workfile#get(l:buf)
    if empty(l:ctx)
        return
    endif
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_codeAction()
        return
    endif

    let l:diagnostics = get(l:ctx['_diagnostics'][1], line('.') - 1)

    if empty(l:diagnostics)
        return
    endif
    call neolsc#lsp#textDocument#codeAction(l:server, l:buf, v:false, l:diagnostics)
endfunction

function! neolsc#ui#textDocument#rangeCodeAction() abort
    let l:buf = nvim_get_current_buf()
    let l:ctx = neolsc#ui#workfile#get(l:buf)
    if empty(l:ctx)
        return
    endif
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_codeAction()
        return
    endif

    let l:range = s:_get_visual_selection_range()
    let l:diagnostics = []
    for l:line in range(l:range['start']['line'], l:range['end']['line'])
        call extend(l:diagnostics, get(l:ctx['_diagnostics'][1], l:line, []))
    endfor

    if empty(l:diagnostics)
        return
    endif
    call neolsc#lsp#textDocument#codeAction(l:server, l:buf, v:false, l:diagnostics)
endfunction
" }}}

" codeLens : done : resolve {{{
function! neolsc#ui#textDocument#codeLens_handler(server, response, buf)
    call neolsc#ui#codelens#update(a:buf, get(a:response, 'result', []))
endfunction

function! neolsc#ui#textDocument#codeLens() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_codeLens()
        return
    endif
    call neolsc#lsp#textDocument#codeLens(l:server, l:buf)
endfunction
" }}}

" documentLink : done : resolve {{{
function! neolsc#ui#textDocument#documentLink_handler(server, response, buf)
    call neolsc#ui#documentlink#update(a:buf, get(a:response, 'result', []))
endfunction

function! neolsc#ui#textDocument#documentLink() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_documentLink()
        return
    endif
    call neolsc#lsp#textDocument#documentLink(l:server, l:buf)
endfunction
" }}}

" documentColor {{{
function! neolsc#ui#textDocument#documentColor_handler(server, response, buf)
    "TODO(Richard): 
endfunction

function! neolsc#ui#textDocument#documentColor() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_color()
        return
    endif
    call neolsc#lsp#textDocument#documentColor(l:server, l:buf)
endfunction
" }}}

" colorPresentation {{{
function! neolsc#ui#textDocument#colorPresentation_handler(server, response, buf)
    "TODO(Richard): 
endfunction

function! neolsc#ui#textDocument#colorPresentation(color) abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_color()
        return
    endif
    let l:range = s:_get_visual_selection_range()
    call neolsc#lsp#textDocument#colorPresentation(l:server, l:buf, l:range, a:color)
endfunction
" }}}

" formatting : done {{{
function! neolsc#ui#textDocument#formatting_handler(server, response, buf)
    call neolsc#ui#edit#TextEdits(a:buf, get(a:response, 'result'))
endfunction

function! neolsc#ui#textDocument#formatting() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_documentFormatting()
        return
    endif
    let l:options = s:_get_formating_option(l:buf)
    call neolsc#lsp#textDocument#formatting(l:server, l:buf, l:options)
endfunction
" }}}

" rangeFormatting : done {{{
function! neolsc#ui#textDocument#rangeFormatting_handler(server, response, buf)
    call neolsc#ui#edit#TextEdits(a:buf, get(a:response, 'result'))
endfunction

function! neolsc#ui#textDocument#rangeFormatting() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_documentRangeFormatting()
        return
    endif
    let l:options = s:_get_formating_option(l:buf)
    let l:range = s:_get_visual_selection_range()
    call neolsc#lsp#textDocument#rangeFormatting(l:server, l:buf, l:range, l:options)
endfunction
" }}}

" onTypeFormatting : done + todo {{{
function! neolsc#ui#textDocument#onTypeFormatting_handler(server, response, buf)
    call neolsc#ui#edit#TextEdits(a:buf, get(a:response, 'result'))
    " TODO(Richard): recovery the cursor
endfunction

function! neolsc#ui#textDocument#onTypeFormatting() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_documentOnTypeFormatting()
        return
    endif

    let l:char = s:_get_current_character()
    if index(l:server.capabilities_documentOnTypeFormatting_triggerCharacters(), l:char) < 0
        return
    endif

    let l:position = _get_current_position()
    let l:options = s:_get_formating_option(l:buf)
    call neolsc#lsp#textDocument#onTypeFormatting(l:server, l:buf, l:position, l:char, l:options)
endfunction
" }}}

" rename : done {{{
function! neolsc#ui#textDocument#rename_handler(server, response, buf)
    let l:result = get(a:response, 'result')
    if empty(l:result)
        return
    endif
    call neolsc#ui#edit#WorkspaceEdit(a:buf, l:result)
endfunction

function! neolsc#ui#textDocument#rename() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif

    if !l:server.capabilities_rename()
        return
    endif

    if l:server.capabilities_rename_prepare()
        call neolsc#ui#textDocument#prepareRename()
        return
    endif

    let l:position = s:_get_current_position()
    let l:new_name = input('query >', expand('<cword>'))
    call neolsc#lsp#textDocument#rename(l:server, l:buf, l:position, l:new_name)
endfunction
" }}}

" prepareRename : done {{{
function! neolsc#ui#textDocument#prepareRename_handler(server, response, buf)
    let l:result = get(a:response, 'result')
    if empty(l:result)
        return
    endif

    if has_key(l:result, 'start')
        let l:range = l:result
        let l:line_start = l:range['start']['line']
        let l:line_end = l:range['end']['line']
        let l:col_start = l:range['start']['character']
        let l:col_end = l:range['end']['character'] - 1

        let l:o_lines = nvim_buf_get_lines(a:buf, l:line_start, l:line_end + 1, v:true)
        if l:line_start == l:line_end
            let l:placeholder = l:o_lines[0][l:col_start : l:col_end]
        else
            let l:placeholder = l:o_lines[0][l:col_start :]
            for l:i in range(1, len(l:o_lines) - 2)
                let l:placeholder .= "\n" . l:o_lines[l:i]
            endfor
            let l:placeholder .= l:o_lines[-1][: l:col_end]
        endif
    else
        let l:range = get(l:result, 'range')
        let l:placeholder = get(l:result, 'placeholder')
    endif

    let l:new_name = input('new name: ', l:placeholder)
    if l:new_name ==# l:placeholder
        return
    endif
    " TODO(Richard): Ask user whether apllying this rename action.

    call neolsc#lsp#textDocument#rename(neolsc#ui#general#get_server(a:server), a:buf, l:range['start'], l:new_name)
endfunction

function! neolsc#ui#textDocument#prepareRename() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_rename_prepare()
        return
    endif
    let l:position = s:_get_current_position()
    call neolsc#lsp#textDocument#prepareRename(l:server, l:buf, l:position)
endfunction
" }}}

" foldingRange : done {{{
function! neolsc#ui#textDocument#foldingRange_handler(server, response, buf)
    call neolsc#ui#folding#fold(a:buf, get(a:response, 'result', []))
endfunction

function! neolsc#ui#textDocument#foldingRange() abort
    let l:buf = nvim_get_current_buf()
    let l:server = neolsc#ui#general#buf_to_server(l:buf)
    if empty(l:server)
        return
    endif
    if !l:server.capabilities_foldingRange()
        return
    endif
    call neolsc#lsp#textDocument#foldingRange(l:server, l:buf)
endfunction
" }}}

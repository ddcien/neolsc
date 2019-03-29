" vim: set foldmethod=marker foldlevel=0 nomodeline:

function! s:merge_TextEdits(edits)
    call sort(a:edits, {e0, e1 -> s:TextEdit_Location_compare(e0, e1)})
    let l:merged = [remove(a:edits, 0)]
    for l:edit in a:edits
        if s:Position_is_same(l:merged[-1].range.start, l:edit.range.start)
            let l:merged[-1].newText .= l:edit.newText
        else
            call add(l:merged, l:edit)
        endif
    endfor
    return reverse(l:merged)
endfunction

function! s:Position_is_same(pos0, pos1)
    return a:pos0.line == a:pos1.line && a:pos0.character == a:pos1.character
endfunction

function! s:TextEdit_Location_compare(edit0, edit1)
    let l:ret = s:Position_compare(a:edit0.range.start, a:edit1.range.start)
    if l:ret != 0
        return l:ret
    endif
    if !s:TextEdit_is_insert(a:edit0)
        return -1
    endif
    if !s:TextEdit_is_insert(a:edit1)
        return 1
    endif
    return 0
endfunction

function! s:TextEdit_is_insert(edit)
    return s:Position_is_same(a:edit.range.start, a:edit.range.end)
endfunction

function! s:Position_compare(pos0, pos1)
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

function! s:build_sub_cmd(edit)
    
endfunction


" ---------------------------------------------------
function! lsc#workspaceedit#handle_WorkspaceEdit(server, workspaceedit)
    if empty(a:workspaceedit)
        return
    endif

    let l:cur_buffer = bufnr('%')
    let l:cur_view = winsaveview()

    if has_key(a:workspaceedit, 'changes')
        call s:handle_changes(a:server, a:workspaceedit.changes)
    elseif has_key(a:workspaceedit, 'documentChanges')
        call s:handle_documentChanges(a:server, a:workspaceedit.documentChanges)
    else
        return
    endif

    if l:cur_buffer !=# bufnr('%')
        execute 'keepjumps keepalt b ' . l:cur_buffer
    endif
    call winrestview(l:cur_view)
endfunction

function! lsc#workspaceedit#handle_TextEdits(server, buf, textedits)
    let l:cur_view = winsaveview()
    call s:handle_buf_edits(a:server, a:buf, a:textedits)
    call winrestview(l:cur_view)
endfunction

function! s:handle_documentChanges(server, documentChanges)
    for l:documentChange in a:documentChanges
        if has_key(l:documentChange, 'kind')
            let l:kind = get(l:documentChange, 'kind')
            if l:kind ==# 'create'
                call s:handle_CreateFile(l:documentChange)
            elseif l:kind ==# 'rename'
                call s:handle_RenameFile(l:documentChange)
            elseif l:kind ==# 'delete'
                call s:handle_DeleteFile(l:documentChange)
            endif
        else
            call s:handle_documentChange(a:server, l:documentChange)
        endif
    endfor
endfunction

function! s:handle_CreateFile(CreateFile)
    "TODO:
    return
endfunction
function! s:handle_RenameFile(RenameFile)
    "TODO:
    return
endfunction
function! s:handle_DeleteFile(DeleteFile)
    "TODO:
    return
endfunction


function! s:handle_textedit(buf, edit)
    let l:range = a:edit.range
    let l:new_text = a:edit.newText

    let l:line_start = l:range['start']['line']
    let l:line_end = l:range['end']['line'] + 1

    let l:col_start = l:range['start']['character']
    let l:col_end = l:range['end']['character']

    let l:o_lines = nvim_buf_get_lines(a:buf, l:line_start, l:line_end, v:true)

    if l:col_start == 0
        let l:head = ''
    else
        let l:head = l:o_lines[0][:l:col_start - 1]
    endif

    let l:tail = l:o_lines[-1][l:col_end:]
    let l:n_lines = split(l:new_text, "\n", 1)
    let l:n_lines[0] = l:head . l:n_lines[0]
    let l:n_lines[-1] = l:n_lines[-1] . l:tail

    call nvim_buf_set_lines(a:buf, l:line_start, l:line_end, v:true, l:n_lines)
endfunction

function! s:handle_changes(server, changes)
    for [l:uri, l:edits] in items(a:changes)
        call s:handle_uri_edits(a:server, l:uri, l:edits)
    endfor
endfunction

function! s:handle_documentChange(server, documentChange)
    let l:uri = a:documentChange.textDocument.uri
    let l:ver = get(a:documentChange.textDocument, 'version')
    let l:edits = a:documentChange.edits

    call s:handle_uri_edits(a:server, l:uri, l:edits)
endfunction

function! s:handle_uri_edits(server, uri, edits)
    if empty(a:edits)
        return
    endif

    let l:path = resolve(lsc#uri#uri_to_path(a:uri))
    let l:buf = bufnr(l:path)

    if l:buf < 0
        let l:cmd = 'keepjumps keepalt'
        let l:cmd .= ' edit '.l:path
        execute l:cmd
        let l:buf = bufnr(l:path)
    endif

    call s:handle_buf_edits(a:server, l:buf, a:edits)
endfunction

function! s:handle_buf_edits(server, buf, edits)
    if empty(a:edits)
        return
    endif

    for l:edit in s:merge_TextEdits(a:edits)
        call s:handle_textedit(a:buf, l:edit)
    endfor

    call a:server.textDocument_didChange(a:buf)
endfunction

" vim: set foldmethod=marker foldlevel=0 nomodeline:
" {{{
function! lsc#utils#get_buffer_path(...) abort
    return expand((a:0 > 0 ? '#' . a:1 : '%') . ':p')
endfunction

function! lsc#utils#get_filetype(...) abort
    if a:0 == 0
        let l:buffer_filetype = &filetype
    else
        if type(a:1) == v:t_string
            let l:buffer_filetype = a:1
        else
            let l:buffer_filetype = getbufvar(a:1, '&filetype')
        endif
    endif
    return l:buffer_filetype
endfunction


function! lsc#utils#get_buffer_uri(...) abort
    return lsc#uri#path_to_uri(expand((a:0 > 0 ? '#' . a:1 : '%') . ':p'))
endfunction
" }}}
"

" {{{
function! lsc#utils#get_visual_selection_pos() abort
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return [0, 0, 0, 0]
    endif
    let lines[-1] = lines[-1][: column_end - (&selection ==# 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return [line_start, column_start, line_end, len(lines[-1])]
endfunction

function! lsc#utils#get_TextDocumentPositionParams() abort
    let [l:bufnum, l:lnum, l:col, l:off, l:curswant] = getcurpos()
    return {
                \ 'textDocument' : {'uri': lsc#utils#get_buffer_uri(l:bufnum)},
                \ 'position': {'line': l:lnum - 1, 'character': l:col - 1},
                \ }
endfunction




function! lsc#utils#get_TextDocumentItem() abort
endfunction
" }}}
"
" LSP utils {{{
function! lsc#utils#position_compare(pos0, pos1) abort
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

function! lsc#utils#range_contains(big_range, small_range) abort
    return lsc#utils#position_compare(a:big_range['start'], a:small_range['start']) <= 0 && lcs#utils#position_compare(a:big_range['end'], a:small_range['end']) >= 0
endfunction
" }}}
" 

" vim: set foldmethod=marker foldlevel=0 nomodeline:

" lsc#hover#handle_hover {{{

function! lsc#hover#visible() abort
    return exists('s:hover_win') && nvim_win_is_valid(s:hover_win)
endfunction

function! lsc#hover#clear() abort
    if exists('s:hover_win') && nvim_win_is_valid(s:hover_win)
        if !nvim_win_get_option(s:hover_win, 'previewwindow')
            call nvim_win_close(s:hover_win, v:true)
        endif
    endif
endfunction

function! s:format_hover_message_extra(response) abort
    let l:hover = a:response.result

    if empty(l:hover)
        return
    endif

    let l:contents = l:hover.contents
    let l:ft = 'markdown'

    let l:lines = ['# Hover', '', '---', '']
    if type(l:contents) == v:t_dict && has_key(l:contents, 'kind')
        call extend(l:lines,  split(l:content.value, "\n"))
        let l:ft = l:contents.kind ==? 'plaintext' ? 'text' : l:contents.kind
    else
        if type(l:contents) != v:t_list
            let l:contents = [l:contents]
        endif
        for l:content in l:contents
            if type(l:content) == v:t_string
                call extend(l:lines,  split(l:content, "\n"))
            else
                call extend(l:lines, ['', '---', '', '```' . l:content['language']])
                call extend(l:lines,  split(l:content.value, "\n"))
                call add(l:lines, '```')
            endif
        endfor
    endif

    return [l:ft, l:lines]
endfunction

function! s:format_hover_message(response) abort
    let l:hover = a:response.result

    if empty(l:hover)
        return
    endif

    let l:contents = l:hover.contents
    let l:ft = 'markdown'

    let l:lines = []
    if type(l:contents) == v:t_dict && has_key(l:contents, 'kind')
        call extend(l:lines,  split(l:content.value, "\n"))
        let l:ft = l:contents.kind ==? 'plaintext' ? 'text' : l:contents.kind
    else
        if type(l:contents) != v:t_list
            let l:contents = [l:contents]
        endif
        for l:content in l:contents
            if type(l:content) == v:t_string
                call extend(l:lines,  split(l:content, "\n"))
            else
                call add(l:lines, '```' . l:content['language'])
                call extend(l:lines,  split(l:content.value, "\n"))
                call add(l:lines, '```')
            endif
        endfor
    endif

    return [l:ft, l:lines]
endfunction


function! s:show_hover_float_window(ft, lines) abort
    if !exists('s:hover_buf')
        let s:hover_buf = nvim_create_buf(v:false, v:true)
    endif

    let l:width = 0
    for l:line in a:lines
        if len(l:line) > l:width
            let l:width = len(l:line)
        endif
    endfor
    call nvim_buf_set_option(s:hover_buf, 'modifiable', v:true)
    call nvim_buf_set_lines(s:hover_buf, 0, -1, v:true, a:lines)
    call nvim_buf_set_option(s:hover_buf, 'filetype', a:ft)
    call nvim_buf_set_option(s:hover_buf, 'modifiable', v:false)

    let l:opts = {
                \ 'relative': 'cursor',
                \ 'width': l:width,
                \ 'height': len(a:lines) + 1,
                \ 'col': 0,
                \ 'row': 1,
                \ 'anchor': 'NW',
                \ 'focusable': v:true
                \}
    if !lsc#hover#visible()
        let s:hover_win = nvim_open_win(s:hover_buf, 0, opts)
        call nvim_win_set_option(s:hover_win, 'spell', v:false)
    endif
    call nvim_win_set_config(s:hover_win, l:opts)
    call nvim_win_set_buf(s:hover_win, s:hover_buf)
endfunction

function! s:show_hover_preview_window(ft, lines) abort
    if !exists('s:hover_buf')
        let s:hover_buf = nvim_create_buf(v:false, v:true)
    endif

    call nvim_buf_set_option(s:hover_buf, 'modifiable', v:true)
    call nvim_buf_set_lines(s:hover_buf, 0, -1, v:true, a:lines)
    call nvim_buf_set_option(s:hover_buf, 'filetype', a:ft)
    call nvim_buf_set_option(s:hover_buf, 'modifiable', v:false)

    if !lsc#hover#visible()
        let l:cw = nvim_get_current_win()
        let l:spr = nvim_get_option('splitright')
        let l:sb = nvim_get_option('splitbelow')
        if g:lsc_hover_preview_direction ==# 'bottom'
            call nvim_set_option('splitbelow', v:true)
            call execute(string(g:lsc_hover_preview_size) . 'split __lsc_hover__')
        elseif g:lsc_hover_preview_direction ==# 'left'
            call nvim_set_option('splitright', v:false)
            call execute(string(g:lsc_hover_preview_size) . 'vsplit __lsc_hover__')
        elseif g:lsc_hover_preview_direction ==# 'right'
            call nvim_set_option('splitright', v:true)
            call execute(string(g:lsc_hover_preview_size) . 'vsplit __lsc_hover__')
        else
            call nvim_set_option('splitbelow', v:false)
            call execute(string(g:lsc_hover_preview_size) . 'split __lsc_hover__')
        endif
        let l:spr = nvim_set_option('splitright', l:spr)
        let l:sb = nvim_set_option('splitbelow', l:sb)
        let s:hover_win = nvim_get_current_win()
        call nvim_set_current_win(l:cw)
        call nvim_win_set_option(s:hover_win, 'previewwindow', v:true)
        call nvim_win_set_option(s:hover_win, 'spell', v:false)
    endif
    call nvim_win_set_buf(s:hover_win, s:hover_buf)
endfunction

function! lsc#hover#handle_hover(response) abort
    if g:lsc_hover_extra_info
        let [l:ft, l:lines] = s:format_hover_message_extra(a:response)
    else
        let [l:ft, l:lines] = s:format_hover_message(a:response)
    endif
    if g:lsc_hover_floating_window
        call s:show_hover_float_window(l:ft, l:lines)
    else
        call s:show_hover_preview_window(l:ft, l:lines)
    endif
endfunction
" }}}

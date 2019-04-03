" vim: set foldmethod=marker foldlevel=0 nomodeline:

" lsc#hover#handle_hover {{{
function! lsc#hover#handle_hover(response) abort
    let l:hover = a:response.result

    if empty(l:hover)
        return
    endif


    pclose
    let l:current_window_id = win_getid()
    execute &previewheight.'new'

    let l:contents = l:hover.contents
    let l:ft = 'markdown'

    if type(l:contents) == v:t_dict && has_key(l:contents, 'kind')
        silent put =l:content.value
        let l:ft = l:contents.kind ==? 'plaintext' ? 'text' : l:contents.kind
    else
        if type(l:contents) != v:t_list
            let l:contents = [l:contents]
        endif
        for l:content in l:contents
            if type(l:content) == v:t_string
                silent put =l:content
            else
                silent put ='```' . l:content['language']
                silent put =l:content.value
                silent put ='```'
            endif
        endfor
    endif

    0delete _

    setlocal readonly nomodifiable
    let &l:filetype = l:ft . '.lsc-hover'

    call win_gotoid(l:current_window_id)
endfunction
" }}}

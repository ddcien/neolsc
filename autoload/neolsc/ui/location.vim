" vim: set foldmethod=marker foldlevel=0 nomodeline:

" private {{{
function! s:loc_compare_lite(loc0, loc1) abort
    return !(a:loc0['filename'] ==# a:loc1['filename'] && a:loc0['lnum'] == a:loc1['lnum'] && a:loc0['col'] == a:loc1['col'])
endfunction

function! s:loc_compare_full(loc0, loc1) abort
    if a:loc0['filename'] ># a:loc1['filename']
        return 1
    elseif a:loc0['filename'] <# a:loc1['filename']
        return -1
    elseif a:loc0['lnum'] ># a:loc1['lnum']
        return 1
    elseif a:loc0['lnum'] <# a:loc1['lnum']
        return -1
    elseif a:loc0['col'] ># a:loc1['col']
        return 1
    elseif a:loc0['col'] <# a:loc1['col']
        return -1
    elseif a:loc0['text'] ># a:loc1['text']
        return 1
    elseif a:loc0['text'] <# a:loc1['text']
        return -1
    else
        return 0
    endif
endfunction

let s:_cache = {}

function! s:lsp_location_to_vim_location(lsp_location) abort
    " TODO(Richard): Handle LocationLink
    " Here the LocationLink instance degenerates to a Location instance
    if has_key(a:lsp_location, 'targetUri')
        let l:path = neolsc#utils#uri#uri_to_path(a:lsp_location['targetUri'])
        let l:line = a:lsp_location['targetRange']['start']['line']
        let l:col = a:lsp_location['targetRange']['start']['character']
    else
        let l:path = neolsc#utils#uri#uri_to_path(a:lsp_location['uri'])
        let l:line = a:lsp_location['range']['start']['line']
        let l:col = a:lsp_location['range']['start']['character']
    endif

    let l:buf = bufnr(l:path)

    if l:buf < 0 || !nvim_buf_is_loaded(l:buf)
        if !has_key(s:_cache, l:path)
            let s:_cache[l:path] = readfile(l:path)
        endif
        let l:text = s:_cache[l:path][l:line]
    else
        if has_key(s:_cache, l:path)
            call remove(s:_cache, l:path)
        endif
        let l:text = nvim_buf_get_lines(l:buf, l:line, l:line + 1, v:true)[0]
    endif
    return {'filename': l:path, 'lnum': l:line + 1, 'col': l:col + 1, 'text': l:text}
endfunction
" }}}

" {{{
function! neolsc#ui#location#to_location_list(lsp_location_list, sort) abort
    let l:location_list = []
    for l:lsp_location in a:lsp_location_list
        call add(l:location_list, s:lsp_location_to_vim_location(l:lsp_location))
    endfor
    if a:sort
        call sort(l:location_list, function('s:loc_compare_full'))
    endif
    return l:location_list
endfunction
" }}}

" FZF {{{
function! s:jump_to_location(loc) abort
    let l:idx = split(a:loc, '\.')[0]
    execute 'll!' l:idx
endfunction


function! neolsc#ui#location#show(prompt, location_list, jump_if_one) abort
    call setloclist(0, a:location_list)
    if a:jump_if_one && len(a:location_list) == 1
        ll! 1
        return
    endif
    let l:fzf_entries = []
    let l:idx = 1
    for l:location in a:location_list
        call add(l:fzf_entries,
                    \ printf('%d. %s | %d col %d | %s', l:idx, l:location['filename'], l:location['lnum'], l:location['col'], l:location['text'])
                    \ )
        let l:idx += 1
    endfor
    call fzf#run(fzf#wrap({
                \ 'source': l:fzf_entries,
                \ 'sink': function('s:jump_to_location'),
                \ 'options': printf('--reverse --prompt="%s> "', a:prompt)
                \ }))
endfunction
" }}}

" vim: set foldmethod=marker foldlevel=0 nomodeline:

" locations {{{
function! s:loc_compare_lite(loc0, loc1)
    return !(a:loc0['filename'] ==# a:loc1['filename'] && a:loc0['lnum'] == a:loc1['lnum'] && a:loc0['col'] == a:loc1['col'])
endfunction

function! s:loc_compare_full(loc0, loc1)
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

function! s:locations_to_qf_list(locations)
    let l:list = []
    let l:cache = {}

    for l:loc in a:locations
        let l:path = lsc#uri#uri_to_path(l:loc.uri)
        let l:line = l:loc['range']['start']['line']
        let l:col = l:loc['range']['start']['character']
        let l:buf = bufnr(l:path)
        if l:buf < 0
            if !has_key(l:cache, l:path)
                let l:cache[l:path] = readfile(l:path)
            endif
            let l:text = l:cache[l:path][l:line]
        else
            let l:text = getbufline(l:buf, l:line + 1)[0]
        endif
        call add(l:list, {'filename': l:path, 'lnum': l:line + 1, 'col': l:col + 1, 'text': printf(' -> [%s]',l:text)})
    endfor

    call uniq(l:list, function('s:loc_compare_lite'))
    return l:list
endfunction

function! s:jump_to_location(loc) abort
    let l:idx = split(a:loc, '\.')[0]
    execute 'll!' l:idx
endfunction

function! lsc#locations#locations_ui(jump_if_one)
    let l:loclist = getloclist(0)
    if a:jump_if_one && len(l:loclist) == 1
        ll! 1
        return
    endif
    call map(l:loclist, {idx, itm -> string(idx + 1) . '. ' . fnamemodify(bufname(itm.bufnr), ':p:.') . ':' . string(itm.lnum) . ':' . string(itm.col) . itm.text})
    call fzf#run(fzf#wrap({
                \ 'source': l:loclist,
                \ 'sink': function('s:jump_to_location'),
                \ 'options': '--reverse +m --prompt="Jomp> "'
                \ }))
endfunction

function! lsc#locations#handle_locations(sort, jump_if_one, response)
    let l:locations = type(a:response.result) == v:t_dict ? [a:response.result]: a:response.result
    if empty(l:locations)
        return
    endif

    " TODO(Richard): Handle LocationLink
    " Here the LocationLink instance degenerates to a Location instance
    if has_key(l:locations[0], 'targetUri')
        call map(l:locations, {_, loc -> {'uri': loc['targetUri'], 'range': loc['targetSelectionRange']}})
    endif

    let l:loclist = s:locations_to_qf_list(l:locations)

    if a:sort
        call sort(l:loclist, function('s:loc_compare_full'))
    endif

    call setloclist(0, l:loclist)
    call lsc#locations#locations_ui(a:jump_if_one)
endfunction
" }}}

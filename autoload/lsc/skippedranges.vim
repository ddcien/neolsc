" vim: set foldmethod=marker foldlevel=0 nomodeline:

let s:skipped_ranges_ns_id = 0

hi SkippedRange guifg=#657b83 ctermfg=11

function! s:parse_highlight(range)
    let l:list = []

    let l:sl = a:range['start']['line']
    let l:el = a:range['end']['line']

    for l:line in range(l:sl, l:el)
        let l:sc = l:line == l:sl ? a:range['start']['character'] : 0
        let l:ec = l:line == l:el ? a:range['end']['character'] : -1
        call add(l:list, [l:line, l:sc, l:ec])
    endfor

    return l:list
endfunction

function! lsc#skippedranges#handle_skipped_ranges(fh, ranges) abort
    if s:skipped_ranges_ns_id == 0
        let s:skipped_ranges_ns_id = nvim_create_namespace('ddlsc_skipped_ranges')
    else
        call a:fh.set_virtual_text(s:skipped_ranges_ns_id, -1, [])
    endif

    if empty(a:ranges)
        return
    endif

    call execute('setlocal foldmethod=manual')
    call execute('normal! zE')

    for l:range in a:ranges
        let l:range['start']['line'] += 1
        let l:range['end']['line'] -= 1

        let l:delta = l:range['end']['line'] - l:range['start']['line']

        if l:delta < 1
            continue
        endif

        for [l:line, l:sc, l:ec] in s:parse_highlight(l:range)
            call a:fh.add_highlight(s:skipped_ranges_ns_id, l:line, 'SkippedRange', l:sc, l:ec)
        endfor

        if l:delta < 2
            continue
        endif

        call execute(printf("%d,%dfo", l:range['start']['line'] + 1, l:range['end']['line']))
    endfor
endfunction


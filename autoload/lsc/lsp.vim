" vim: set foldmethod=marker foldlevel=0 nomodeline:

" private API {{{
function! s:requires_eol_at_eof(buf) abort
    let l:file_ends_with_eol = getbufvar(a:buf, '&eol')
    let l:vim_will_save_with_eol = !getbufvar(a:buf, '&binary') && getbufvar(a:buf, '&fixeol')
    return l:file_ends_with_eol || l:vim_will_save_with_eol
endfunction
" }}}

" Public API {{{
function! lsc#lsp#get_Position(line, character) abort
    return {'line': a:line, 'character': a:character}
endfunction

function! lsc#lsp#get_Range(start, end) abort
    return {'start': a:start, 'end': a:end}
endfunction

function! lsc#lsp#get_Location(uri, range) abort
    return {'uri': a:uri, 'range': a:range}
endfunction

function! lsc#lsp#get_LocationLink(targetUri, targetRange, originSelectionRange, targetSelectionRange) abort
    return {
                \ 'targetUri': a:targetUri,
                \ 'targetRange': a:targetRange,
                \ 'originSelectionRange': a:originSelectionRange,
                \ 'targetSelectionRange': a:targetSelectionRange
                \ }
endfunction


function! lsc#lsp#get_textDocumentText(buf) abort
    let l:buf_fileformat = getbufvar(a:buf, '&fileformat')
    let l:eol = {'unix': "\n", 'dos': "\r\n", 'mac': "\r"}[l:buf_fileformat]
    return join(getbufline(a:buf, 1, '$'), l:eol).(s:requires_eol_at_eof(a:buf) ? l:eol : '')
endfunction


function! lsc#lsp#get_TextDocumentIdentifier(buf) abort
    return {
        \ 'uri': lsc#utils#get_buffer_uri(a:buf),
        \ }
endfunction

function! lsc#lsp#get_TextDocumentItem(buf, version) abort
    return {
        \ 'uri': lsc#utils#get_buffer_uri(a:buf),
        \ 'languageId': lsc#utils#get_filetype(a:buf),
        \ 'text': lsc#lsp#get_textDocumentText(a:buf),
        \ 'version': a:version,
        \ }
endfunction

function! lsc#lsp#get_VersionedTextDocumentIdentifier(buf, version) abort
    return {
        \ 'uri': lsc#utils#get_buffer_uri(a:buf),
        \ 'version': a:version,
        \ }
endfunction

function! lsc#lsp#get_WorkspaceFolder(dir, name) abort
    return {
        \ 'uri': lsc#utils#get_buffer_uri(a:dir),
        \ 'name': a:name,
        \ }
endfunction

" }}}

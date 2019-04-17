" vim: set foldmethod=marker foldlevel=0 nomodeline:

" params builders {{{

function! s:_build_DocumentUri(buf)
    return neolsc#utils#uri#buf_to_uri(a:buf)
endfunction

function! s:_build_TextDocumentIdentifier(buf) abort
    return {'uri': s:_build_DocumentUri(a:buf)}
endfunction

function! s:_build_TextDocumentPositionParams(buf, position)
    return {
                \ 'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \ 'position': a:position
                \ }
endfunction

function! s:_build_CompletionContext(kind, trigger)
    let l:ret = {
                \ 'triggerKind': a:kind,
                \ }

    if a:kind == 2
        let l:ret['triggerCharacter'] = a:trigger
    endif
    return l:ret
endfunction

function! s:_build_CompletionParams(buf, position, kind, trigger)
    let ret = s:_build_TextDocumentPositionParams(a:buf, a:position)
    let ret['context'] = s:_build_CompletionContext(a:kind, a:trigger)
    return l:ret
endfunction

function! s:_build_ReferenceContext(incdec)
    return {'includeDeclaration': a:incdec ? v:true : v:false}
endfunction

function! s:_build_ReferenceParams(buf, position, incdec)
    let ret = s:_build_TextDocumentPositionParams(a:buf, a:position)
    let ret['context'] = s:_build_ReferenceContext(a:incdec)
    return l:ret
endfunction

function! s:_build_DocumentSymbolParams(buf)
    return {
                \ 'textDocument': s:_build_TextDocumentIdentifier(a:buf)
                \ }
endfunction

" }}}

" request to server {{{
" completion {{{
function! neolsc#lsp#textDocument#completion(server, buf, position, kind, trigger)
    let l:request = {
                \ 'method': 'textDocument/completion',
                \ 'params': s:_build_CompletionParams(a:buf, a:position, a:kind, a:trigger),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#completion_handler(server, response, a:buf)})
endfunction
" }}}

" hover {{{
function! neolsc#lsp#textDocument#hover(server, buf, position)
    let l:request = {
                \ 'method': 'textDocument/hover',
                \ 'params': s:_build_TextDocumentPositionParams(a:buf, a:position),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#hover_handler(server, response, a:buf)})
endfunction
" }}}

" signatureHelp {{{
function! neolsc#lsp#textDocument#signatureHelp(server, buf, position)
    let l:request = {
                \ 'method': 'textDocument/signatureHelp',
                \ 'params': s:_build_TextDocumentPositionParams(a:buf, a:position),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#signatureHelp_handler(server, response, a:buf)})
endfunction
" }}}

" declaration {{{
function! neolsc#lsp#textDocument#declaration(server, buf, position)

    let l:request = {
                \ 'method': 'textDocument/declaration',
                \ 'params': s:_build_TextDocumentPositionParams(a:buf, a:position),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#declaration_handler(server, response, a:buf)})
endfunction
" }}}

" definition {{{
function! neolsc#lsp#textDocument#definition(server, buf, position)
    let l:request = {
                \ 'method': 'textDocument/definition',
                \ 'params': s:_build_TextDocumentPositionParams(a:buf, a:position),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#definition_handler(server, response, a:buf)})
endfunction
" }}}

" typeDefinition {{{
function! neolsc#lsp#textDocument#typeDefinition(server, buf, position)
    let l:request = {
                \ 'method': 'textDocument/typeDefinition',
                \ 'params': s:_build_TextDocumentPositionParams(a:buf, a:position),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#typeDefinition_handler(server, response, a:buf)})
endfunction
" }}}

" implementation {{{
function! neolsc#lsp#textDocument#implementation(server, buf, position)
    let l:request = {
                \ 'method': 'textDocument/implementation',
                \ 'params': s:_build_TextDocumentPositionParams(a:buf, a:position),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#implementation_handler(server, response, a:buf)})
endfunction
" }}}

" references {{{
function! neolsc#lsp#textDocument#references(server, buf, position, incdec)
    let l:request = {
                \ 'method': 'textDocument/references',
                \ 'params': s:_build_ReferenceParams(a:buf, a:position, a:incdec),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#references_handler(server, response, a:buf)})
endfunction
" }}}

" documentHighlight {{{
function! neolsc#lsp#textDocument#documentHighlight(server, buf, position)
    let l:request = {
                \ 'method': 'textDocument/documentHighlight',
                \ 'params': s:_build_TextDocumentPositionParams(a:buf, a:position),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#documentHighlight_handler(server, response, a:buf)})
endfunction
" }}}

" documentSymbol {{{
function! neolsc#lsp#textDocument#documentSymbol(server, buf)
    let l:request = {
                \ 'method': 'textDocument/documentSymbol',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf)
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#documentSymbol_handler(server, response, a:buf)})
endfunction
" }}}

" codeAction {{{
function! neolsc#lsp#textDocument#codeAction(server, buf, all, diagnostics)
    if empty(a:diagnostics)
        return
    endif

    let l:start = a:diagnostics[0]['range']['start']
    let l:end = a:diagnostics[-1]['range']['end']

    for l:diag in a:diagnostics
        if neolsc#ui#utils#position_compare(l:diag['range']['start'], l:start) < 0
            let l:start = l:diag['range']['start']
        endif
        if neolsc#ui#utils#position_compare(l:diag['range']['end'], l:end) > 0
            let l:end = l:diag['range']['end']
        endif
    endfor

    let l:request = {
                \ 'method': 'textDocument/codeAction',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \     'range': {
                \         'start': l:start,
                \         'end': l:end,
                \     },
                \     'context': {
                \         'diagnostics': a:diagnostics,
                \     },
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#codeAction_handler(server, response, a:buf, a:all)})
endfunction
" }}}

" codeLens {{{
function! neolsc#lsp#textDocument#codeLens(server, buf)
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    let l:request = {
                \ 'method': 'textDocument/codeLens',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \ }
                \ }
    call a:server.send_request(l:request,{server, response -> neolsc#ui#textDocument#codeLens_handler(server, response, a:buf)})
endfunction
" }}}

" documentLink {{{
function! neolsc#lsp#textDocument#documentLink(server, buf)
    let l:request = {
                \ 'method': 'textDocument/documentLink',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf)
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#documentLink_handler(server, response, a:buf)})
endfunction
" }}}

" documentColor {{{
function! neolsc#lsp#textDocument#documentColor(server, buf)
    let l:request = {
                \ 'method': 'textDocument/documentColor',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf)
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#documentColor_handler(server, response, a:buf)})
endfunction
" }}}

" colorPresentation {{{
function! neolsc#lsp#textDocument#colorPresentation(server, buf, range, color)
    let l:request = {
                \ 'method': 'textDocument/colorPresentation',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \     'range': a:range,
                \     'color': a:color,
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#colorPresentation_handler(server, response, a:buf)})
endfunction
" }}}

" formatting {{{
function! neolsc#lsp#textDocument#formatting(server, buf, options)
    let l:request = {
                \ 'method': 'textDocument/formatting',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \     'options': a:options
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#formatting_handler(server, response, a:buf)})
endfunction
" }}}

" rangeFormatting {{{
function! neolsc#lsp#textDocument#rangeFormatting(server, buf, range, options)
    let l:request = {
                \ 'method': 'textDocument/rangeFormatting',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \     'range': a:range,
                \     'options': a:options,
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#rangeFormatting_handler(server, response, a:buf)})
endfunction
" }}}

" onTypeFormatting {{{
function! neolsc#lsp#textDocument#onTypeFormatting(server, buf, position, trigger, options)
    let l:request = {
                \ 'method': 'textDocument/onTypeFormatting',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \     'position': a:position,
                \     'ch': a:trigger,
                \     'options': a:options,
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#onTypeFormatting_handler(server, response, a:buf)})
endfunction
" }}}

" rename {{{
function! neolsc#lsp#textDocument#rename(server, buf, position, new_name)
    let l:request = {
                \ 'method': 'textDocument/rename',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \     'position': a:position,
                \     'newName': a:new_name,
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#rename_handler(server, response, a:buf)})
endfunction
" }}}

" prepareRename {{{
function! neolsc#lsp#textDocument#prepareRename(server, buf, position)
    let l:request = {
                \ 'method': 'textDocument/prepareRename',
                \ 'params': s:_build_TextDocumentPositionParams(a:buf, a:position),
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#prepareRename_handler(server, response, a:buf)})
endfunction
" }}}

" foldingRange {{{
function! neolsc#lsp#textDocument#foldingRange(server, buf)
    let l:request = {
                \ 'method': 'textDocument/foldingRange',
                \ 'params': {
                \     'textDocument': s:_build_TextDocumentIdentifier(a:buf),
                \ }
                \ }
    call a:server.send_request(l:request, {server, response -> neolsc#ui#textDocument#foldingRange_handler(server, response, a:buf)})
endfunction
" }}}
" }}}

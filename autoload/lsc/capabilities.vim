" vim: set foldmethod=marker foldlevel=1 nomodeline:

function! lsc#capabilities#hover(capabilities) abort
    return get(a:capabilities, 'hoverProvider', v:false)
endfunction

function! lsc#capabilities#definition(capabilities) abort
    return get(a:capabilities, 'definitionProvider', v:false)
endfunction

function! lsc#capabilities#references(capabilities) abort
    return get(a:capabilities, 'referencesProvider', v:false)
endfunction

function! lsc#capabilities#documentHighlight(capabilities) abort
    return get(a:capabilities, 'documentHighlightProvider', v:false)
endfunction

function! lsc#capabilities#documentSymbol(capabilities) abort
    return get(a:capabilities, 'documentSymbolProvider', v:false)
endfunction

function! lsc#capabilities#workspaceSymbol(capabilities) abort
    return get(a:capabilities, 'workspaceSymbolProvider', v:false)
endfunction

function! lsc#capabilities#documentFormatting(capabilities) abort
    return get(a:capabilities, 'documentFormattingProvider', v:false)
endfunction

function! lsc#capabilities#documentRangeFormatting(capabilities) abort
    return get(a:capabilities, 'documentRangeFormattingProvider', v:false)
endfunction

function! lsc#capabilities#typeDefinition(capabilities) abort
    return get(a:capabilities, 'typeDefinitionProvider', v:false)
endfunction

function! lsc#capabilities#implementation(capabilities) abort
    return get(a:capabilities, 'implementationProvider', v:false)
endfunction

function! lsc#capabilities#declaration(capabilities) abort
    return get(a:capabilities, 'declarationProvider', v:false)
endfunction

function! lsc#capabilities#foldingRange(capabilities) abort
    return get(a:capabilities, 'foldingRangeProvider', v:false)
endfunction

function! lsc#capabilities#color(capabilities) abort
    return get(a:capabilities, 'colorProvider', v:false)
endfunction

" textDocumentSync {{{
function! lsc#capabilities#TextDocumentSync_change(capabilities) abort
    let l:provider = get(a:capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? l:provider : get(l:provider, 'change', 0)
endfunction

function! lsc#capabilities#TextDocumentSync_openClose(capabilities) abort
    let l:provider = get(a:capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:false : get(l:provider, 'openClose', v:false)
endfunction

function! lsc#capabilities#TextDocumentSync_willSave(capabilities) abort
    let l:provider = get(a:capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:false : get(l:provider, 'willSave', v:false)
endfunction

function! lsc#capabilities#TextDocumentSync_willSaveWaitUntil(capabilities) abort
    let l:provider = get(a:capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:false : get(l:provider, 'willSaveWaitUntil', v:false)
endfunction

function! lsc#capabilities#TextDocumentSync_save(capabilities) abort
    let l:provider = get(a:capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:false : has_key(l:provider, 'save')
endfunction

function! lsc#capabilities#TextDocumentSync_save_includeText(capabilities) abort
    let l:provider = get(a:capabilities, 'textDocumentSync', 0)
    return type(l:provider) == v:t_number ? v:false : get(get(l:provider, 'save', {}), 'includeText', v:false)
endfunction
" }}}


" completion {{{
function! lsc#capabilities#completion(capabilities) abort
    return has_key(a:capabilities, 'completionProvider')
endfunction

function! lsc#capabilities#completion_resolve(capabilities) abort
    let l:provider = get(a:capabilities, 'completionProvider', {})
    return get(l:provider, 'resolveProvider', v:false)
endfunction

function! lsc#capabilities#completion_triggerCharacters(capabilities) abort
    let l:provider = get(a:capabilities, 'completionProvider', {})
    return get(l:provider, 'triggerCharacters', [])
endfunction
" }}}


" SignatureHelpOptions {{{
function! lsc#capabilities#signatureHelp(capabilities) abort
    return has_key(a:capabilities, 'signatureHelpProvider')
endfunction

function! lsc#capabilities#signatureHelp_triggerCharacters(capabilities) abort
    let l:provider = get(a:capabilities, 'signatureHelpProvider', {})
    return get(l:provider, 'triggerCharacters', [])
endfunction
" }}}
"
" codeActionProvider {{{
function! lsc#capabilities#codeAction(capabilities) abort
    let l:provider = get(a:capabilities, 'codeActionProvider', v:false)
    return type(l:provider) ==# v:t_dict || l:provider ==# v:true
endfunction

function! lsc#capabilities#codeAction_codeActionKinds(capabilities) abort
    let l:provider = get(a:capabilities, 'codeActionProvider', v:false)
    return type(l:provider) != v:t_dict ? [] : get(l:provider, 'codeActionKinds', [])
endfunction
" }}}

" {{{
function! lsc#capabilities#codeLens(capabilities) abort
    return has_key(a:capabilities, 'codeLensProvider')
endfunction

function! lsc#capabilities#codeLens_resolve(capabilities) abort
    let l:provider = get(a:capabilities, 'codeLensProvider', {})
    return get(l:provider, 'resolveProvider', v:false)
endfunction
" }}}
"
" {{{
function! lsc#capabilities#documentLink(capabilities) abort
    return has_key(a:capabilities, 'documentLinkProvider')
endfunction

function! lsc#capabilities#documentLink_resolve(capabilities) abort
    let l:provider = get(a:capabilities, 'documentLinkProvider', {})
    return get(l:provider, 'resolveProvider', v:false)
endfunction
"}}}

" renameProvider {{{
function! lsc#capabilities#rename(capabilities) abort
    let l:provider = get(a:capabilities, 'renameProvider', v:false)
    return type(l:provider) ==# v:t_dict || l:provider ==# v:true
endfunction

function! lsc#capabilities#rename_prepare(capabilities) abort
    let l:provider = get(a:capabilities, 'renameProvider', v:false)
    return type(l:provider) != v:t_dict ? v:false : get(l:provider, 'prepareProvider', v:false)
endfunction
" }}}
"
" documentOnTypeFormattingProvider {{{
function! lsc#capabilities#documentOnTypeFormatting(capabilities) abort
    return has_key(a:capabilities, 'documentOnTypeFormattingProvider')
endfunction

function! lsc#capabilities#documentOnTypeFormatting_triggerCharacters(capabilities) abort
    let l:provider = get(a:capabilities, 'documentOnTypeFormattingProvider', {})
    if empty(l:provider)
        return []
    endif
    let l:triggers = [get(l:provider, 'firstTriggerCharacter')]
    call extend(l:triggers, get(l:provider, 'moreTriggerCharacter', []))
    return l:triggers
endfunction
" }}}

" executeCommandProvider {{{
function! lsc#capabilities#executeCommand(capabilities) abort
    let l:provider = get(a:capabilities, 'executeCommandProvider', {})
    return empty(l:provider) ? [] : get(l:provider, 'commands', [])
endfunction
" }}}


"	workspace?: {
"		workspaceFolders?: {
"			supported?: boolean;
"			changeNotifications?: string | boolean;
"		}
"	}
"	experimental?: any;
"}

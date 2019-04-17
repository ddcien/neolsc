" vim: set foldmethod=marker foldlevel=0 nomodeline:

if exists('g:neolsc_loaded')
    finish
endif
let g:neolsc_loaded = 1

let g:neolsc_auto_enable = get(g:, 'neolsc_auto_enable', 1)

augroup neolsc
    autocmd!
    autocmd VimEnter * call neolsc#global_init()
augroup end

" settings {{{
let g:neolsc_server_commands = {
            \ 'ccls': {
            \     'auto_start': v:false,
            \     'priority': 2,
            \     'command': ['ccls'],
            \     'initialization_options': {
            \         'cache': {
            \             'directory':'.ccls-cache',
            \         },
            \         'highlight': {
            \             'lsRanges': v:true,
            \         },
            \     },
            \     'workspace_settings': {},
            \     'whitelist': ['c', 'cpp', 'objc', 'objcpp', 'cc'],
            \ },
            \ 'clangd': {
            \     'priority': 1,
            \     'auto_start': v:false,
            \     'command': ['clangd'],
            \     'initialization_options': {},
            \     'workspace_settings': {},
            \     'whitelist': ['c', 'cpp', 'objc', 'objcpp', 'cc'],
            \ },
            \ 'cquery': {
            \     'priority': 0,
            \     'auto_start': v:false,
            \     'command': ['cquery'],
            \     'initialization_options': {
            \         'cacheDirectory': '.cquery-cache',
            \     },
            \     'workspace_settings': {},
            \     'whitelist': ['c', 'cpp', 'objc', 'objcpp', 'cc'],
            \ },
            \ 'pyls': {
            \     'priority': 0,
            \     'auto_start': v:false,
            \     'command': ['pyls'],
            \     'initialization_options': {},
            \     'whitelist': ['python']
            \ },
            \ 'rls': {
            \     'priority': 0,
            \     'auto_start': v:false,
            \     'command': ['rls'],
            \     'initialization_options': {},
            \     'whitelist': ['rust']
            \ },
            \ 'efm-langserver': {
            \     'priority': 0,
            \     'auto_start': v:false,
            \     'command': ['efm-langserver'],
            \     'initialization_options': {},
            \     'whitelist': ['vim', 'markdown']
            \ },
            \ }
let g:neolsc_language_settings = {
            \ 'c': 'ccls',
            \ 'cpp': 'ccls',
            \ 'python': 'pyls',
            \ 'rust': 'rls',
            \ 'vim': 'efm-langserver',
            \ 'markdown': 'efm-langserver',
            \ }
" }}}

" commands {{{
command! LscDiags call neolsc#ui#diagnostics#diags()
command! LscWorkspaceDiags call neolsc#ui#diagnostics#workspaceDiags()

command! LscWorkspaceSymbol call neolsc#ui#workspace#symbol()
" completion
command! LscHover call neolsc#ui#textDocument#hover()
" signatureHelp
command! LscDeclaration call neolsc#ui#textDocument#declaration()
command! LscDefinition call neolsc#ui#textDocument#definition()
command! LscTypeDefinition call neolsc#ui#textDocument#typeDefinition()
command! LscImplementation call neolsc#ui#textDocument#implementation()
command! LscReferences call neolsc#ui#textDocument#references()
command! LscHighlight call neolsc#ui#textDocument#documentHighlight()
command! LscSymbol call neolsc#ui#textDocument#documentSymbol()
command! LscAction call neolsc#ui#textDocument#codeAction()
command! LscFixIt call neolsc#ui#textDocument#lineCodeAction()
command! -range LscRangeFixIt call neolsc#ui#textDocument#rangeCodeAction()
command! LscCodelens call neolsc#ui#textDocument#codeLens()
command! LscDocLink call neolsc#ui#textDocument#documentLink()
" documentColor
" colorPresentation
command! LscFormat call neolsc#ui#textDocument#formatting()
command! -range LscRangeFormat call neolsc#ui#textDocument#rangeFormatting()
" onTypeFormatting
command! LscRename call neolsc#ui#textDocument#rename()
command! LscFold call neolsc#ui#textDocument#foldingRange()
" }}}

" mappings {{{
nnoremap <plug>(lsc-diags) :<c-u>call neolsc#ui#diagnostics#diags()<cr>
nnoremap <plug>(lsc-workspace-diags) :<c-u>neolsc#ui#diagnostics#workspaceDiags()<cr>

nnoremap <plug>(lsc-workspace-symbol) :<c-u>call neolsc#ui#workspace#symbol()<cr>

nnoremap <plug>(lsc-hover) :<c-u>call neolsc#ui#textDocument#hover()<cr>
nnoremap <plug>(lsc-declaration) :<c-u>call neolsc#ui#textDocument#declaration()<cr>
nnoremap <plug>(lsc-definition) :<c-u>call neolsc#ui#textDocument#definition()<cr>
nnoremap <plug>(lsc-type-definition) :<c-u>call neolsc#ui#textDocument#typeDefinition()<cr>
nnoremap <plug>(lsc-implementation) :<c-u>call neolsc#ui#textDocument#implementation()<cr>
nnoremap <plug>(lsc-references) :<c-u>call neolsc#ui#textDocument#references()<cr>
nnoremap <plug>(lsc-highlight) :<c-u>call neolsc#ui#textDocument#documentHighlight()<cr>
nnoremap <plug>(lsc-symbol) :<c-u>call neolsc#ui#textDocument#documentSymbol()<cr>
nnoremap <plug>(lsc-action) :<c-u>call neolsc#ui#textDocument#codeAction()<cr>
nnoremap <plug>(lsc-fixit) :<c-u>call neolsc#ui#textDocument#lineCodeAction()<cr>
vnoremap <plug>(lsc-fixit) :call neolsc#ui#textDocument#rangeCodeAction()<cr>
nnoremap <plug>(lsc-codelens) :<c-u>call neolsc#ui#textDocument#codeLens()<cr>
nnoremap <plug>(lsc-doc-link) :<c-u>call neolsc#ui#textDocument#documentLink()<cr>
nnoremap <plug>(lsc-format) :<c-u>call neolsc#ui#textDocument#formatting()<cr>
vnoremap <plug>(lsc-format) :call neolsc#ui#textDocument#rangeFormatting()<cr>
nnoremap <plug>(lsc-rename) :<c-u>call neolsc#ui#textDocument#rename()<cr>
nnoremap <plug>(lsc-fold) :<c-u>call neolsc#ui#textDocument#foldingRange()<cr>
" }}}

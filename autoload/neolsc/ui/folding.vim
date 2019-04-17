" vim: set foldmethod=marker foldlevel=0 nomodeline:

function! neolsc#ui#folding#fold(buf, folds) abort
    call filter(a:folds, {_, fr -> fr['startLine'] < fr['endLine']})
    call map(a:folds, {_, fr -> printf("%d,%dfo", fr['startLine'] + 1, fr['endLine'] + 1)})
    call execute('setlocal foldmethod=manual')
    call execute('normal! zE')
    call execute(a:folds)
endfunction

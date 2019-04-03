# DDLSC

## Tasks

### General

 - [x]: C->S->C : 'initialize'
 - [x]: C->S    : 'initialized'
 - [x]: C->S->C : 'shutdown'
 - [x]: C->S    : 'exit'
 - [ ]: S->C    : '$/cancelRequest'
 - [ ]: C->S    : '$/cancelRequest'

### Window

 - [ ]: S->C    : 'window/logMessage'
 - [ ]: S->C    : 'window/showMessage'
 - [ ]: S->C->S : 'window/showMessageRequest'

### Telemetry

 - [ ]: S->C : 'telemetry/event'

### Client

 - [ ]: S->C->S : 'client/registerCapability'
 - [ ]: S->C->S : 'client/unregisterCapability'

### Workspace

 - [ ]: S->C->S : 'workspace/workspaceFolders'
 - [ ]: C->S    : 'workspace/didChangeWorkspaceFolders'
 - [x]: C->S    : 'workspace/didChangeConfiguration'
 - [ ]: S->C->S : 'workspace/configuration'
 - [ ]: C->S    : 'workspace/didChangeWatchedFiles'
 - [x]: C->S->C : 'workspace/symbol'
 - [x]: C->S->C : 'workspace/executeCommand'
 - [x]: S->C->S : 'workspace/applyEdit'

### TextSynchronization

 - [x]: C->S    : 'textDocument/didOpen'
 - [x]: C->S    : 'textDocument/didChange'
 - [x]: C->S    : 'textDocument/willSave'
 - [ ]: C->S->C : 'textDocument/willSaveWaitUntil'
 - [x]: C->S    : 'textDocument/didSave'
 - [x]: C->S    : 'textDocument/didClose'

### Diagnostics

 - [x]: S->C : 'textDocument/publishDiagnostics'

### Language Features

 - [ ]: C->S->C : 'textDocument/completion'
 - [ ]: C->S->C : 'completionItem/resolve'
 - [x]: C->S->C : 'textDocument/hover'
 - [ ]: C->S->C : 'textDocument/signatureHelp'
 - [x]: C->S->C : 'textDocument/declaration'
 - [x]: C->S->C : 'textDocument/definition'
 - [x]: C->S->C : 'textDocument/typeDefinition'
 - [x]: C->S->C : 'textDocument/implementation'
 - [x]: C->S->C : 'textDocument/references'
 - [x]: C->S->C : 'textDocument/documentHighlight'
 - [x]: C->S->C : 'textDocument/documentSymbol'
 - [x]: C->S->C : 'textDocument/codeAction'
 - [x]: C->S->C : 'textDocument/codeLens'
 - [ ]: C->S->C : 'codeLens/resolve'
 - [x]: C->S->C : 'textDocument/documentLink'
 - [ ]: C->S->C : 'documentLink/resolve'
 - [ ]: C->S->C : 'textDocument/documentColor'
 - [ ]: C->S->C : 'textDocument/colorPresentation'
 - [x]: C->S->C : 'textDocument/formatting'
 - [x]: C->S->C : 'textDocument/rangeFormatting'
 - [ ]: C->S->C : 'textDocument/onTypeFormatting'
 - [x]: C->S->C : 'textDocument/rename'
 - [x]: C->S->C : 'textDocument/prepareRename'
 - [x]: C->S->C : 'textDocument/foldingRange'


### CCLS Features
 - [x]: S->C : "$ccls/publishSkippedRanges"
 - [x]: S->C : "$ccls/publishSemanticHighlight"

 - [x]: C->S->C : '$ccls/call'
 - [ ]: C->S->C : '$ccls/fileInfo'
 - [ ]: C->S->C : '$ccls/info'
 - [x]: C->S->C : '$ccls/inheritance'
 - [x]: C->S->C : '$ccls/member'
 - [x]: C->S->C : '$ccls/navigate'
 - [x]: C->S->C : '$ccls/reload'
 - [x]: C->S->C : '$ccls/vars'

### BUG

1. The preview window for hover information need to be discarded.

### TODO

1. Auto trigger completion, signatureHelp, and onTypeFormatting function.
2. Use floating window for hover and some other information.
5. Export commands and key bindings.
6. Export custom settings.
7. Use neosnippet.vim

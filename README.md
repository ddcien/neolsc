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
 - [ ]: C->S    : 'workspace/didChangeConfiguration'
 - [ ]: S->C->S : 'workspace/configuration'
 - [ ]: C->S    : 'workspace/didChangeWatchedFiles'
 - [x]: C->S->C : 'workspace/symbol'
 - [ ]: C->S->C : 'workspace/executeCommand'
 - [ ]: S->C->S : 'workspace/applyEdit'

### TextSynchronization

 - [x]: C->S    : 'textDocument/didOpen'
 - [x]: C->S    : 'textDocument/didChange'
 - [ ]: C->S    : 'textDocument/willSave'
 - [ ]: C->S->C : 'textDocument/willSaveWaitUntil'
 - [x]: C->S    : 'textDocument/didSave'
 - [x]: C->S    : 'textDocument/didClose'

### Diagnostics

 - [x]: S->C : 'textDocument/publishDiagnostics'

### Language Features

 - [ ]: C->S->C : 'textDocument/completion'
 - [ ]: C->S->C : 'completionItem/resolve'
 - [ ]: C->S->C : 'textDocument/hover'
 - [ ]: C->S->C : 'textDocument/signatureHelp'
 - [x]: C->S->C : 'textDocument/declaration'
 - [x]: C->S->C : 'textDocument/definition'
 - [x]: C->S->C : 'textDocument/typeDefinition'
 - [ ]: C->S->C : 'textDocument/implementation'
 - [x]: C->S->C : 'textDocument/references'
 - [x]: C->S->C : 'textDocument/documentHighlight'
 - [ ]: C->S->C : 'textDocument/documentSymbol'
 - [ ]: C->S->C : 'textDocument/codeAction'
 - [x]: C->S->C : 'textDocument/codeLens'
 - [ ]: C->S->C : 'codeLens/resolve'
 - [ ]: C->S->C : 'textDocument/documentLink'
 - [ ]: C->S->C : 'documentLink/resolve'
 - [ ]: C->S->C : 'textDocument/documentColor'
 - [ ]: C->S->C : 'textDocument/colorPresentation'
 - [ ]: C->S->C : 'textDocument/formatting'
 - [ ]: C->S->C : 'textDocument/rangeFormatting'
 - [ ]: C->S->C : 'textDocument/onTypeFormatting'
 - [ ]: C->S->C : 'textDocument/rename'
 - [ ]: C->S->C : 'textDocument/prepareRename'
 - [ ]: C->S->C : 'textDocument/foldingRange'


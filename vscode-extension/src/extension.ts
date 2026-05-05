import * as vscode from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(_context: vscode.ExtensionContext): void {
    const serverOptions: ServerOptions = { command: 'kconfig-language-server' };
    const clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: 'file', language: 'kconfig' }],
    };
    client = new LanguageClient(
        'kconfig-language-server',
        'Kconfig Language Server',
        serverOptions,
        clientOptions,
    );
    client.start();
}

export function deactivate(): Thenable<void> | undefined {
    return client?.stop();
}

#!/usr/bin/env bats
# Integration tests using lsts — tests the server as a real LSP process.

LSTS_FIXTURES="test/fixtures/codebases/linux"

setup() {
    REPO_ROOT="$(pwd)"
    source test/lsts/lsts
    lsts_set_cmd "${REPO_ROOT}/kconfig-language-server"
    lsts_set_root "${REPO_ROOT}/${LSTS_FIXTURES}"
    lsts_set_langId "kconfig"
    lsts_start
}

teardown() {
    lsts_stop
}

# ---------------------------------------------------------------------------
# initialize
# ---------------------------------------------------------------------------

@test "initialize returns capabilities" {
    lsts_initialize
    echo "$LSTS_RESPONSE" | jq -e '
        .result.capabilities |
        (.hoverProvider == true) and
        (.definitionProvider == true) and
        (.completionProvider | type == "object") and
        (.referencesProvider == true) and
        (.documentSymbolProvider == true) and
        (.documentHighlightProvider == true) and
        (.renameProvider == true)
    '
}

@test "initialize advertises full textDocumentSync" {
    lsts_initialize
    echo "$LSTS_RESPONSE" | jq -e '.result.capabilities.textDocumentSync == 1'
}

# ---------------------------------------------------------------------------
# hover
# ---------------------------------------------------------------------------

@test "hover returns markdown contents" {
    lsts_initialize
    lsts_open "drivers/mmc/core/Kconfig"
    lsts_request "textDocument/hover" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/drivers/mmc/core/Kconfig\"},\"position\":{\"line\":37,\"character\":10}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result.contents.kind == "markdown"'
}

@test "hover over known symbol returns non-empty documentation" {
    lsts_hover \
        "drivers/mmc/core/Kconfig:38:8" \
        "${REPO_ROOT}/test/fixtures/responses/hover-mmc-block.rpc.json"
}

@test "hover over unknown word returns empty value" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/hover" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":0,\"character\":1}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result.contents.value == ""'
}

# ---------------------------------------------------------------------------
# definition
# ---------------------------------------------------------------------------

@test "go to definition resolves single symbol" {
    lsts_definition "kernel/power/Kconfig:13:6" \
        "${REPO_ROOT}/test/fixtures/responses/single-definition-lsts.json"
}

@test "go to definition resolves menuconfig symbol with correct offset" {
    lsts_definition "block/Kconfig:5:13" \
        "${REPO_ROOT}/test/fixtures/responses/definition-menuconfig-block.rpc.json"
}

@test "go to definition returns empty array for unknown symbol" {
    lsts_initialize
    lsts_open "kernel/power/Kconfig"
    lsts_request "textDocument/definition" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/kernel/power/Kconfig\"},\"position\":{\"line\":0,\"character\":1}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result == []'
}

# ---------------------------------------------------------------------------
# document symbols
# ---------------------------------------------------------------------------

@test "documentSymbol lists symbols in block/Kconfig" {
    lsts_document_symbols "block/Kconfig" \
        "${REPO_ROOT}/test/fixtures/responses/document-symbols-block.json"
}

@test "documentSymbol includes menuconfig entries" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/documentSymbol" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '[.result[].name] | any(. == "BLOCK")'
}

# ---------------------------------------------------------------------------
# references
# ---------------------------------------------------------------------------

@test "references finds usages of BLK_DEV_BSG_COMMON" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/references" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":47,\"character\":8},\"context\":{\"includeDeclaration\":true}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result | length == 3'
    echo "$LSTS_RESPONSE" | jq -e '[.result[].uri] | any(endswith("drivers/scsi/Kconfig"))'
    echo "$LSTS_RESPONSE" | jq -e '[.result[].uri] | any(endswith("block/Kconfig"))'
}

@test "references excludes declaration when includeDeclaration is false" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/references" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":47,\"character\":8},\"context\":{\"includeDeclaration\":false}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result | length == 2'
    # None of the results should be the declaration line itself
    echo "$LSTS_RESPONSE" | jq -e '[.result[] | select(.uri | endswith("block/Kconfig")) | .range.start.line] | all(. != 47)'
}

# ---------------------------------------------------------------------------
# completion
# ---------------------------------------------------------------------------

@test "completion returns keyword items" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/completion" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":5,\"character\":2},\"context\":{\"triggerKind\":1}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result.items | length > 0'
    echo "$LSTS_RESPONSE" | jq -e '.result.items[0] | has("label")'
}

@test "completion includes config keyword" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/completion" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":5,\"character\":2},\"context\":{\"triggerKind\":1}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '[.result.items[].label] | any(. == "config")'
}

@test "completion includes depends keyword" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/completion" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":5,\"character\":2},\"context\":{\"triggerKind\":1}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '[.result.items[].label] | any(. == "depends")'
}

@test "completion result is not incomplete" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/completion" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":5,\"character\":2},\"context\":{\"triggerKind\":1}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result.isIncomplete == false'
}

# ---------------------------------------------------------------------------
# document highlight
# ---------------------------------------------------------------------------

@test "documentHighlight finds occurrences of symbol in file" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/documentHighlight" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":47,\"character\":8}}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result | length > 0'
}

@test "documentHighlight declaration has kind 3" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/documentHighlight" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":47,\"character\":8}}"
    lsts_recv_response
    # The declaration line (config BLK_DEV_BSG_COMMON) should have kind=3 (Write)
    echo "$LSTS_RESPONSE" | jq -e '[.result[] | select(.range.start.line == 47)] | any(.kind == 3)'
}

# ---------------------------------------------------------------------------
# rename
# ---------------------------------------------------------------------------

@test "rename returns workspace edits for symbol" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/rename" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":47,\"character\":9},\"newName\":\"BLK_DEV_BSG_COMMON_NEW\"}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result.changes | type == "object"'
    echo "$LSTS_RESPONSE" | jq -e '.result.changes | keys | length > 0'
}

@test "rename edits span multiple files" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/rename" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":47,\"character\":9},\"newName\":\"BLK_DEV_BSG_COMMON_NEW\"}"
    lsts_recv_response
    # Both block/Kconfig and drivers/scsi/Kconfig should have edits
    echo "$LSTS_RESPONSE" | jq -e '.result.changes | keys | length > 1'
}

@test "rename edits use the new name" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/rename" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":47,\"character\":9},\"newName\":\"BLK_DEV_BSG_COMMON_NEW\"}"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '[.result.changes | to_entries[] | .value[] | .newText] | all(. == "BLK_DEV_BSG_COMMON_NEW")'
}

# ---------------------------------------------------------------------------
# diagnostics (publishDiagnostics on didOpen / didChange)
# ---------------------------------------------------------------------------

@test "didOpen with valid file pushes empty diagnostics" {
    lsts_initialize
    lsts_open "block/Kconfig"
    # After didOpen, server pushes publishDiagnostics notification
    lsts_recv
    echo "$LSTS_RESPONSE" | jq -e '.method == "textDocument/publishDiagnostics"'
    echo "$LSTS_RESPONSE" | jq -e '.params.diagnostics | length == 0'
}

@test "didOpen with undefined symbol pushes diagnostic" {
    LSTS_ROOT="${REPO_ROOT}/test/fixtures"
    lsts_set_root "${REPO_ROOT}/test/fixtures"
    lsts_initialize
    lsts_open "invalid.Kconfig"
    lsts_recv
    echo "$LSTS_RESPONSE" | jq -e '.method == "textDocument/publishDiagnostics"'
    echo "$LSTS_RESPONSE" | jq -e '.params.diagnostics | length > 0'
    echo "$LSTS_RESPONSE" | jq -e '.params.diagnostics[0].message | startswith("Undefined symbol:")'
}

@test "didChange updates diagnostics" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_recv  # consume initial publishDiagnostics
    # Send a didChange with content containing an undefined symbol
    local uri="file://$LSTS_ROOT/block/Kconfig"
    local new_text
    new_text="$(printf 'config FOO\n\tbool \"Foo\"\n\tdepends on COMPLETELY_UNDEFINED_SYMBOL\n')"
    lsts_notify "textDocument/didChange" \
        "{\"textDocument\":{\"uri\":\"${uri}\",\"version\":2},\"contentChanges\":[{\"text\":$(echo "$new_text" | jq -Rs .)}]}"
    lsts_recv
    echo "$LSTS_RESPONSE" | jq -e '.method == "textDocument/publishDiagnostics"'
    echo "$LSTS_RESPONSE" | jq -e '.params.diagnostics | length > 0'
}

# ---------------------------------------------------------------------------
# shutdown / exit
# ---------------------------------------------------------------------------

@test "shutdown responds with null result" {
    lsts_initialize
    lsts_request "shutdown" "null"
    lsts_recv_response
    echo "$LSTS_RESPONSE" | jq -e '.result == null'
}

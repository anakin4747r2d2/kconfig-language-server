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

# ---------------------------------------------------------------------------
# definition
# ---------------------------------------------------------------------------

@test "go to definition resolves single symbol" {
    lsts_definition "kernel/power/Kconfig:13:6" \
        "${REPO_ROOT}/test/fixtures/responses/single-definition-lsts.json"
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

# ---------------------------------------------------------------------------
# references
# ---------------------------------------------------------------------------

@test "references finds usages of BLK_DEV_BSG_COMMON" {
    lsts_initialize
    lsts_open "block/Kconfig"
    lsts_request "textDocument/references" \
        "{\"textDocument\":{\"uri\":\"file://$LSTS_ROOT/block/Kconfig\"},\"position\":{\"line\":47,\"character\":8},\"context\":{\"includeDeclaration\":true}}"
    lsts_recv_response
    # Should find references in block/Kconfig and drivers/scsi/Kconfig
    echo "$LSTS_RESPONSE" | jq -e '.result | length == 3'
    echo "$LSTS_RESPONSE" | jq -e '[.result[].uri] | any(endswith("drivers/scsi/Kconfig"))'
    echo "$LSTS_RESPONSE" | jq -e '[.result[].uri] | any(endswith("block/Kconfig"))'
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
    # Should have items with "label" fields
    echo "$LSTS_RESPONSE" | jq -e '.result.items | length > 0'
    echo "$LSTS_RESPONSE" | jq -e '.result.items[0] | has("label")'
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
    # Should have at least the declaration itself
    echo "$LSTS_RESPONSE" | jq -e '.result | length > 0'
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
    # At least one file should have edits
    echo "$LSTS_RESPONSE" | jq -e '.result.changes | keys | length > 0'
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

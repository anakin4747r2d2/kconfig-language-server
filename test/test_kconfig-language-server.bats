#!/usr/bin/env bats

setup() {
    source ./kconfig-language-server
}

@test "parse_headers returns expected output" {
    run parse_headers < test/fixtures/header-content-length-only
    test "$status" -eq 0
    test "$output" = "123"
}

@test "get_cword gets all keywords" {
    run get_cword 2 1 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "config"

    run get_cword 3 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "string"

    run get_cword 4 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "depends"

    run get_cword 5 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "option"

    run get_cword 6 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "default"

    run get_cword 13 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "def_bool"

    run get_cword 41 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "help"

    run get_cword 75 1 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "menu"

    run get_cword 56 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "bool"

    run get_cword 86 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "int"

    run get_cword 179 1 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "choice"

    run get_cword 180 1 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "prompt"

    run get_cword 271 1 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "endchoice"

    run get_cword 422 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "select"

    run get_cword 584 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "tristate"

    run get_cword 585 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "---help---"

    run get_cword 613 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "range"

    run get_cword 750 2 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "endmenu"

    run get_cword 5 2 test/fixtures/codebases/linux/block/Kconfig
    test "$status" -eq 0
    test "$output" = "menuconfig"
}

@test "get_cword gets keywords prefixed with spaces" {
    run get_cword 150 11 test/fixtures/Kconfig
    test "$status" -eq 0
    test "$output" = "string"
}

@test "get_docs works for Kconfig symbols" {

    expected="This selects MultiMediaCard, Secure Digital and Secure
Digital I/O support.

If you want MMC/SD/SDIO support, you should say Y here and
also to your specific host controller driver."

    run get_docs MMC test/fixtures/codebases/linux
    test "$status" -eq 0
    test "$output" = "$expected"
}

@test "get_cword doesn't include ! in cword" {
    run get_cword 17 31 test/fixtures/codebases/linux/mm/Kconfig
    test "$status" -eq 0
    test "$output" = "ARCH_NO_SWAP"
}

@test "go to definition works for single Kconfig symbols" {
    local root="$PWD/test/fixtures/codebases/linux"
    local req
    req="$(jq -n --arg uri "file://${root}/kernel/power/Kconfig" \
        '{jsonrpc:"2.0",id:2,method:"textDocument/definition",params:{position:{line:12,character:13},textDocument:{uri:$uri}}}')"
    run handle_definition "$req" test/fixtures/codebases/linux
    test "$status" -eq 0
    local json
    json="$(echo "$output" | tail -n +3)"
    echo "$json" | jq -e '.result | length > 0'
    echo "$json" | jq -e '.result[0].uri | startswith("file://")'
}

@test "go to definition works for multiple Kconfig symbols" {
    local root="$PWD/test/fixtures/codebases/linux"
    local req
    req="$(jq -n --arg uri "file://${root}/drivers/gpu/drm/Kconfig" \
        '{jsonrpc:"2.0",id:2,method:"textDocument/definition",params:{position:{line:288,character:20},textDocument:{uri:$uri}}}')"
    run handle_definition "$req" test/fixtures/codebases/linux
    test "$status" -eq 0
    local json
    json="$(echo "$output" | tail -n +3)"
    echo "$json" | jq -e '.result | length > 0'
}

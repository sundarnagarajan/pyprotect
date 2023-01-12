#!/bin/bash

function red() {
    # Prints arguments in bold red
    ANSI_ESC=$(printf '\033')
    ANSI_RS="${ANSI_ESC}[0m"    # reset
    ANSI_HC="${ANSI_ESC}[1m"    # hicolor
    ANSI_FRED="${ANSI_ESC}[31m" # foreground red

    echo -e "${ANSI_RS}${ANSI_HC}${ANSI_FRED}$@${ANSI_RS}"
}

function hide_output_unless_error() {
    # Runs arguments and shows output only if there is an error
    local ret=0
    local out=$($@ 2>&1 || ret=$?)
    [[ $ret -ne 0 ]] && {
        >&2 red "$out"
        return $ret
    }
    return 0
}


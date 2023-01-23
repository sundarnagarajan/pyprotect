#!/bin/bash
SCRIPT_DIR=$(readlink -f $(dirname $BASH_SOURCE))

# --------------------------------------------------------------------
# From bash_functions
# --------------------------------------------------------------------
ANSI_ESC=$(printf '\033')
ANSI_RS="${ANSI_ESC}[0m"    # reset
ANSI_HC="${ANSI_ESC}[1m"    # hicolor
ANSI_UL="${ANSI_ESC}[4m"    # underline
ANSI_INV="${ANSI_ESC}[7m"   # inverse background and foreground
ANSI_FBLK="${ANSI_ESC}[30m" # foreground black
ANSI_FRED="${ANSI_ESC}[31m" # foreground red
ANSI_FGRN="${ANSI_ESC}[32m" # foreground green
ANSI_FYEL="${ANSI_ESC}[33m" # foreground yellow
ANSI_FBLE="${ANSI_ESC}[34m" # foreground blue
ANSI_FMAG="${ANSI_ESC}[35m" # foreground magenta
ANSI_FCYN="${ANSI_ESC}[36m" # foreground cyan
ANSI_FWHT="${ANSI_ESC}[37m" # foreground white
ANSI_BBLK="${ANSI_ESC}[40m" # background black
ANSI_BRED="${ANSI_ESC}[41m" # background red
ANSI_BGRN="${ANSI_ESC}[42m" # background green
ANSI_BYEL="${ANSI_ESC}[43m" # background yellow
ANSI_BBLE="${ANSI_ESC}[44m" # background blue
ANSI_BMAG="${ANSI_ESC}[45m" # background magenta
ANSI_BCYN="${ANSI_ESC}[46m" # background cyan
ANSI_BWHT="${ANSI_ESC}[47m" # background white


function red() {
    # Prints arguments in bold red
    [[ -t 2 ]] && {
        echo -e "${ANSI_RS}${ANSI_HC}${ANSI_FRED}$@${ANSI_RS}"
    } || {
        echo -e "$@"
    }
}

function blue() {
    # Prints arguments in bold blue
    [[ -t 1 ]] && {
        echo -e "${ANSI_RS}${ANSI_HC}${ANSI_FBLE}$@${ANSI_RS}"
    } || {
        echo -e "$@"
    }
}

function var_value_contains_spaces() {
    # $1: VALUE - not variable NAME
    # Returns: 0 if $1 contains spaces; 1 otherwise
    [[ $# -lt 1 ]] && return 1
    local pat="[[:space:]]"
    [[ $1 =~ $pat ]] && return 0 || return 1
}

function var_declared() {
    # $1: variable name - WITHOUT '$'
    # Returns: 0 if $1 is declared (normal var/ indexed array or associive array; 1 otherwise
    #[[ "$(declare -p $1 2>/dev/null)" =~ ^declare\ -[-nirxaAx]+\ $1 ]];
    [[ $# -lt 1 ]] && return 1
    var_value_contains_spaces "$1" && return 1

    pat="^declare[[:space:]]+([^[:space:]]+)[[:space:]]+$1(={0,1}|$)"
    [[ "$(declare -p $1 2>/dev/null)" =~ $pat ]];
}

function var_undeclared() {
    # $1: variable name - WITHOUT '$'
    # Returns: 1 if $1 is declared (normal var/ indexed array or associive array; 0 otherwise
    # Exact complement of var_declared
    [[ $# -lt 1 ]] && return 1
    var_declared "$1" && return 1 || return 0
}

function var_type() {
    # $1: variable name - WITHOUT '$'
    # echoes (to stdout): variable type from 'declare -p' output - e.g. --|-a|-A|-n ...
    [[ $# -lt 1 ]] && return 
    var_value_contains_spaces "$1" && return 1

    pat="^declare\s+(\S+)\s+$1="
    # For references 'echo -n' echoes nothing, so use printf
    [[ "$(declare -p $1 2>/dev/null)" =~ $pat ]] && printf '%s\n' "${BASH_REMATCH[1]}" && return 0
    # Associative and non-associative arrays when declared without elements
    # do not have the trailing '='
    pat="^declare\s+(\S+)\s+$1$"
    # For references 'echo -n' echoes nothing, so use printf
    [[ "$(declare -p $1 2>/dev/null)" =~ $pat ]] && printf '%s\n' "${BASH_REMATCH[1]}" && return 0
}

function var_is_ref() {
    # $1: variable name - WITHOUT '$'
    # Returns: 0 if $1 is a reference to another var; 1 otherwise
    [[ $# -lt 1 ]] && return 1
    [[ -n "$1" ]] || return 1
    var_declared "$1" || return 1
    pat="^declare\s+-n\s+$1=\"\S+\""
    [[ "$(declare -p $1 2>/dev/null)" =~ $pat ]]
}

function var_deref() {
    # $1: variable name - WITHOUT '$'
    # Outputs (to stdout):
    #   ARG1 (unchanged) if it is declared but is not a reference
    #   The FINAL variable that ARG1 points at if it is a ref
    #   NOTHING if ARG1 is not a declared variable
    # Returns:
    #   0: If ARG1 is declared and is not a reference
    #   0: If ARG1 is a reference and dereferenced variable is declared
    #   1: If $1 is not set or null or contains white space
    #   2: If ARG1 is not a declared variable
    #   3: If ARG1 is a reference and final var it points at is not declared
    #   4: Unexpected error - should not happen
    [[ $# -lt 1 ]] && return 1
    [[ -n "$1" ]] || return 1
    var_value_contains_spaces "$1" && return 1
    var_declared "$1" || return 2
    var_is_ref "$1" || {
        printf '%s\n' "$1" && return 0 
    }

    local var_name=$1

    while [[ "$var_name" ]];
    do
        pat="^declare\s+-n\s+${var_name}=\"(\S+)\""
        [[ "$(declare -p ${var_name} 2>/dev/null)" =~ $pat ]] || return 4
        var_name=$(printf '%s\n' "${BASH_REMATCH[1]}") || return 4

        var_is_ref "${var_name}"
        if [[ $? -eq 0 ]]; then
            # One more level of deref required
            continue
        else
            # Not a reference - end loop
            var_declared "${var_name}" || return 3
            printf '%s\n' "${var_name}" && return 0
        fi
    done
    return 4
}

function var_is_array() {
    # $1: variable name - WITHOUT '$'
    # Returns: 0 if $1 is a non-associative array; 1 otherwise
    # Other than in var_declared, var_type, var_is_ref and var_deref always dereference first
    [[ $# -lt 1 ]] && return 1
    local dereferenced=$(var_deref "$1") || return 1
    local vt=$(var_type $dereferenced)
    [[ -z "$vt" ]] && return 1
    local pat="[a]"
    [[ $vt =~ $pat ]]
}

function var_is_map() {
    # $1: variable name - WITHOUT '$'
    # Returns: 0 if $1 is a associative array; 1 otherwise
    # Other than in var_declared, var_type, var_is_ref and var_deref always dereference first
    [[ $# -lt 1 ]] && return 1
    local dereferenced=$(var_deref "$1") || return 1
    local vt=$(var_type ${dereferenced})
    [[ -z "$vt" ]] && return 1
    local pat="-A"
    [[ $vt =~ $pat ]]
}

function var_is_array() {
    # $1: variable name - WITHOUT '$'
    # Returns: 0 if $1 is a non-associative array; 1 otherwise
    # Other than in var_declared, var_type, var_is_ref and var_deref always dereference first
    [[ $# -lt 1 ]] && return 1
    local dereferenced=$(var_deref "$1") || return 1
    local vt=$(var_type ${dereferenced})
    [[ -z "$vt" ]] && return 1
    local pat="-a"
    [[ $vt =~ $pat ]]
}

function var_is_nonarray() {
    # $1: variable name - WITHOUT '$'
    # Returns: 0 if $1 is a 'normal' var (non-array); 1 otherwise
    # Other than in var_declared, var_type, var_is_ref and var_deref always dereference first
    [[ $# -lt 1 ]] && return 1
    # var_is_map $1 || return 1
    # var_is_array $1 && return 1
    local dereferenced=$(var_deref "$1") || return 1
    local vt=$(var_type ${dereferenced})
    [[ -z "$vt" ]] && return 1
    local pat="(-a|-A)"
    [[ $vt =~ $pat ]] && return 1
    return 0
}

function var_len() {
    # $1: variable name - WITHOUT '$'
    # echoes (to stdout):
    #   Length of variable value - for non-array vars
    #   Number of elements - for array vars
    #   0 if unset
    # Other than in var_declared, var_type, var_is_ref and var_deref always dereference first
    [[ $# -lt 1 ]] && return 0
    local ret=0
    var_declared "$1" || {
        echo "0" 
        return 0
    }
    local dereferenced=$(var_deref "$1") || {
        echo 0
        return 0
    }
    var_is_nonarray "$dereferenced" && {
        declare -n __ref=$1
        echo ${#__ref}
        return 0
    }

    declare -n ___ref=$dereferenced

    # indexed and associative arrays give 'unbound variable' error when accesing
    # size with '${#var[@]}' even if variable is declared unless array has elements
    # So we need to reset '-u' option if set and restore at the end
    local ___uplus
    [[ -o nounset ]] && ___uplus=yes || ___uplus=no
    [[ "$___uplus" = "yes" ]] && set +u

    declare -i size=${#___ref[@]}
    [[ "$___uplus" = "yes" ]] && set -u
    unset $___uplus
    echo $size
}

function var_empty() {
    # $1: variable name - WITHOUT '$'
    # Returns: 0 if unset _OR_ null or declared without any elements; 1 otherwise
    # Works for ordinary vars, ordinary arrays and associative arrays and references
    # Other than in var_declared, var_type, var_is_ref and var_deref always dereference first
    [[ $# -lt 1 ]] && return 1
    set +e
    local dereferenced=$(var_deref $1)
    [[ $? -ne 0 ]] && return 0
    set -e
    var_is_nonarray "$dereferenced" && {
        [[ -z "${!dereferenced}" ]] && return 0 || return 1
    }
    # Otherwise it is set and it is some type of array
    [[ $(var_len "$1") -eq 0 ]]
}

function var_empty_not_spaces() {
    # $1: variable name - WITHOUT '$'
    # Similar to var_empty, except, additionally returns 1 if
    # $1 is a non-array variable AND it's value contains only whitespace or \n
    # If var_empty_not_spaces VAR returns 0:
    #   [[ -f $VAR ]] would give a syntax error
    #   'for x in $var; do xxx; done would fail
    [[ $# -lt 1 ]] && return 1
    var_empty "$1" && return 0
    var_is_nonarray "$1" || return 1
    set +e
    local dereferenced=$(var_deref "$1")
    [[ $? -ne 0 ]] && return 0
    set -e
    [[ "${!dereferenced}" =~ ^[[:space:]\n]*$ ]] && return 0 || return 1
}

function var_show_vars() {
    # $@: variable names WITHOUT '$'
    # echoes var names and values to stdout
    [[ $# -lt 1 ]] && return;
    local ___VARLIST=
    for v in $@
    do
        ___VARLIST="$___VARLIST $v"
    done
    declare -i ___MAXLEN=$(echo $___VARLIST | sed -e 's/[[:space:]][[:space:]]*/\n/g' | wc -L)
    local fmt=

    for v in $(echo $___VARLIST | sed -e 's/[[:space:]][[:space:]]*/\n/g' | LC_ALL=C sort)
    do
        printf -v fmt "%%-%ds : %%s\\n" "$___MAXLEN"
        var_declared $v || {
            printf "$fmt" "$v" "<unset>"
            continue
        }
        var_is_nonarray $v && {
            printf "$fmt" "$v" "${!v}"
            continue
        }
        var_is_map $v && {
            printf "$fmt" "$v" ""
            # We need VALUE of v ($v) and $v cannot be used in ${map_name[key]}
            declare -n __ref=$v
            declare -i ___KEYLEN=$(echo  "${!__ref[@]}"| sed -e 's/[[:space:]][[:space:]]*/\n/g' | wc -L)
            printf -v fmt "    %%-%ds : %%s\\n" "$___KEYLEN"

            # Show keys in sorted order
            for K in $(echo  "${!__ref[@]}"| sed -e 's/[[:space:]][[:space:]]*/\n/g' | LC_ALL=C sort)
            do
                printf "$fmt" $K ${__ref[$K]}
            done
            continue
        }
        var_is_array $v && {
            printf "$fmt" "$v" ""
            # We need VALUE of v ($v) and $v cannot be used in ${map_name[key]}
            declare -n __ref=$v
            declare -i ___KEYLEN=$(echo  "${!__ref[@]}"| sed -e 's/[[:space:]][[:space:]]*/\n/g' | wc -L)
            printf -v fmt "    %%-%ds : %%s\\n" "$___KEYLEN"
            for K in "${!__ref[@]}"
            do
                printf "$fmt" "$K" "${__ref[$K]}"
            done
            continue
        }
    done
}

# --------------------------------------------------------------------
# End of bash_functions
# --------------------------------------------------------------------


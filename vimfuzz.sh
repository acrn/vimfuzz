#!/bin/bash

# open a file based on some pasted text
#
# a filename or a pattern, maybe there's even a line number in there
#
# this code is a bit rough

vimfuzz() {
    local patterns search_patterns line_number linoarg local_find local_find_a \
        recently_modified git_grep

    line_number=$(printf "$*" | sed -nr 's/(^|.*[: ])([0-9]+)([: ].*|$)/\2/ p')

    [ "$line_number" ] && linoarg="+$line_number"


    patterns=( "$1" )
    search_patterns=()
    # if the argument was git grep or ag output it will have :linenumber:
    patterns+="$IFS${1/:*/}"

    # see if the argument was a verbatim filename
    for pattern in $patterns
    do
        [ "$(stat "$pattern" 2>/dev/null)" ] && vim "$pattern" $linoarg && return 0
        search_patterns+="$IFS*$(basename $pattern)*"
    done

    # try git grep and ag
    for command in "git grep -inaF" "ag -i --noheading --nobreak"
    do
        git_grep="$($command "$1" 2>/dev/null | egrep -o "[^:]*:[0-9]+")"
        if [ "$git_grep" ]
        then
            recently_modified=$(\
                echo "$git_grep" \
                | sed -r 's/:[0-9]*$//' \
                | xargs stat -c "%Y %n" 2>/dev/null \
                | sort -n -r \
                | sed 's/^[0-9]* //' \
                | head -1)
            linoarg="+$(echo "$git_grep" \
                        | sed -rne "/${recently_modified//\//\\\/}/ s/.*:// p" \
                        | sed -n '1 p' )"
            vim $recently_modified $linoarg && return 0
        fi
    done

    # try find
    local_find="$(find . -type f -iname ${search_patterns//$IFS/ -or -iname })"
    local_find_a=( $local_find )

    # only one file under the pwd, open that
    [ "${#local_find_a[@]}" -eq "1" ] && vim "${local_find_a[0]}" $linoarg \
        && return 0

    if [ "${#local_find_a[@]}" -gt "1" ]
    then
        # more than one match, open the one most recently modified
        recently_modified=$(\
            find -type f -iname "*$1*" -exec stat -c "%Y %n" {} 2>/dev/null \; \
            | sort -n -r \
            | sed 's/^[0-9]* //' \
            | head -1)
        printf "maybe you wanted \n${local_find}?\n"
        vim "$recently_modified" $linoarg && return 0
    fi

    # TODO: also try locate

    printf "Too fuzzy\n"
    return 1
}

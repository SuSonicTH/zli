#!/bin/bash

function exit_on_error() {
    if [ $? -ne 0 ]; then
        >&2 echo ""
        >&2 echo "an error occured, stopping."
        >&2 echo ""
        exit 1
    fi
}

echo downloading zli repository from https://github.com/SuSonicTH/zli.git
git clone --quiet --recurse-submodules https://github.com/SuSonicTH/zli.git > /dev/null || exit_on_error
cd zli || exit_on_error
chmod +x build.sh
./build.sh

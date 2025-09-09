#!/usr/bin/bash
zig build --watch -fincremental --summary all --prominent-compile-errors

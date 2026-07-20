#!/bin/sh

for file in "${BUILDDIR}/../../../tools/env-shell.d/"*; do
    . "${file}"
done
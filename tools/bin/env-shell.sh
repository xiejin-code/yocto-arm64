#!/bin/sh

for file in "${BUILDDIR}/../../../tools/env-shell.d/"*; do
    echo "Sourcing ${file}"
    . "${file}"
done
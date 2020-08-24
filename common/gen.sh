#!/bin/bash

for i in {1..50000}
do
    echo "package common" > "$i.go"
    echo "var x$i = $i" >> "$i.go"
done

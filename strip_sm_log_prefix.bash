#!/bin/bash

cat $1 | sed 's/.*: //' > tmp.file
mv tmp.file $1

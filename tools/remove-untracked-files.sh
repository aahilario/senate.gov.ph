#!/bin/bash
git status | grep -A10000 'Untracked files:' | sed -r -e 's@\t@#@g' | grep '^##' | sed -r -e 's@^##(.*)$@rm -fv "\1";@g' | bash

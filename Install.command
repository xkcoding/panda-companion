#!/bin/zsh
set -eu
root="${0:A:h}"
"$root/Install" "$root/PandaCompanion.app"
print '按回车关闭此窗口。'
read -r

@echo off

echo working???
tasm %1
tlink %1
%1
echo done
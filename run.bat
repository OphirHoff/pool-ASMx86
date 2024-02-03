@echo off
REM this is a comment
REM to run asm file you need to call this from dosbox console like this    run _game
echo working???
tasm %1
tlink %1
%1
echo done
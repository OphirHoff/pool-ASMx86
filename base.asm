IDEAL
MODEL small
STACK 100h
DATASEG
; --------------------------
msg db 'Hello World!$'
; --------------------------

CODESEG
start:
	mov ax, @data
	mov ds, ax
; --------------------------

mov ah, 9
mov dx, offset msg
int 21h

; --------------------------

exit:
	mov ax, 4c00h
	int 21h
END start



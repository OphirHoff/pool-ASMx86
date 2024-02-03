IDEAL
MODEL small
STACK 100h
DATASEG

	
	ScrLine 	db 320 dup (0)  ; One Color line read buffer
	
	;<BMP File data>
	FileName 	db 11 dup (0) ,0
	FileHandle	dw ?
	Header 	    db 54 dup(0)
	Palette 	db 400h dup (0)
	
	BmpFileErrorMsg    	db 'Error At Opening Bmp File '
    BmpName  db 'NoName', 0dh, 0ah,'$'
	ErrorFile           db 0
	
	BmpLeft dw ? ;inputed before calling bmp proc
	BmpTop dw ?
	BmpColSize dw ?
	BmpRowSize dw ?
	;</Bmp File data>
	
	
	RndCurrentPos db 0
	
	
	;<strings>
	test_st db "hello world$"
	New_Line db 10, 13, '$' ;used in proc - NewLine
	;</strings>






CODESEG



start:
	mov ax, @data
	mov ds, ax

	mov dl, 'w'
	call PrintChar
	


exit:
	mov ax, 4c00h
	int 21h
	





;---------------------
;---------------------
;---------------------
;---------------------
;miscs proc section 
;---------------------
;---------------------
;---------------------
;---------------------

;===========================
;description - Delay for .1 seconds
;input - none
;output - none
;variables - none
;===========================
proc Delay100ms
	push cx
	mov cx, 100
@@Self1:
	push cx
	mov cx, 3000
@@Self2:
	loop @@Self2
	pop cx
	loop @@Self1
	
	pop cx
	ret
endp Delay100ms




;---------------------
;---------------------
;---------------------
;---------------------
;bmp proc section 
;---------------------
;---------------------
;---------------------
;---------------------


;===========================
;description - Displays an image on the screen
;input - FileName contains the name, and BmpLeft, BmpTop, BmpColSize and BmpRowSize contains the respective values
;output - console
;variables - FileName, BmpLeft, BmpTop, BmpColSize, BmpRowSize
;===========================
proc Bmp
	push bx
	push dx
	push si
	push ax
	
	
	mov dx, offset FileName
	call OpenShowBmp
	cmp [ErrorFile],1
	jne @@cont 
	jmp @@exitError
@@cont:

	
    jmp @@exit
	
@@exitError:
	mov ax,2
	int 10h
	
    mov dx, offset BmpFileErrorMsg
	mov ah,9
	int 21h
	
@@exit:
	
	pop ax
	pop si
	pop dx	
	pop bx
    ret
endp Bmp

;===============
;the following next procs, are used to help the previous proc and shouldn't be called on their own
;===============

proc OpenShowBmp near
	
	 
	call OpenBmpFile
	cmp [ErrorFile],1
	je @@ExitProc
	
	call ReadBmpHeader
	
	call ReadBmpPalette
	
	call CopyBmpPalette
	
	call  ShowBmp
	
	 
	call CloseBmpFile

@@ExitProc:
	ret
endp OpenShowBmp

 

; input dx filename to open
proc OpenBmpFile	near						 
	mov ah, 3Dh
	xor al, al
	int 21h
	jc @@ErrorAtOpen
	mov [FileHandle], ax
	jmp @@ExitProc
	
@@ErrorAtOpen:
	mov [ErrorFile],1
@@ExitProc:	
	ret
endp OpenBmpFile


proc CloseBmpFile near
	mov ah,3Eh
	mov bx, [FileHandle]
	int 21h
	ret
endp CloseBmpFile




; Read 54 bytes the Header
proc ReadBmpHeader	near					
	push cx
	push dx
	
	mov ah,3fh
	mov bx, [FileHandle]
	mov cx,54
	mov dx,offset Header
	int 21h
	
	pop dx
	pop cx
	ret
endp ReadBmpHeader



proc ReadBmpPalette near ; Read BMP file color palette, 256 colors * 4 bytes (400h)
						 ; 4 bytes for each color BGR + null)			
	push cx
	push dx
	
	mov ah,3fh
	mov cx,400h
	mov dx,offset Palette
	int 21h
	
	pop dx
	pop cx
	
	ret
endp ReadBmpPalette


; Will move out to screen memory the colors
; video ports are 3C8h for number of first color
; and 3C9h for all rest
proc CopyBmpPalette		near					
										
	push cx
	push dx
	
	mov si,offset Palette
	mov cx,256
	mov dx,3C8h
	mov al,0  ; black first							
	out dx,al ;3C8h
	inc dx	  ;3C9h
CopyNextColor:
	mov al,[si+2] 		; Red				
	shr al,2 			; divide by 4 Max (cos max is 63 and we have here max 255 ) (loosing color resolution).				
	out dx,al 						
	mov al,[si+1] 		; Green.				
	shr al,2            
	out dx,al 							
	mov al,[si] 		; Blue.				
	shr al,2            
	out dx,al 							
	add si,4 			; Point to next color.  (4 bytes for each color BGR + null)				
								
	loop CopyNextColor
	
	pop dx
	pop cx
	
	ret
endp CopyBmpPalette





proc ShowBMP 
; BMP graphics are saved upside-down.
; Read the graphic line by line (BmpRowSize lines in VGA format),
; displaying the lines from bottom to top.
	push cx
	
	mov ax, 0A000h
	mov es, ax
	
	mov cx,[BmpRowSize]
	
 
	mov ax,[BmpColSize] ; row size must dived by 4 so if it less we must calculate the extra padding bytes
	xor dx,dx
	mov si,4
	div si
	cmp dx,0
	mov bp,0
	jz @@row_ok
	mov bp,4
	sub bp,dx

@@row_ok:	
	mov dx,[BmpLeft]
	
@@NextLine:
	push cx
	push dx
	
	mov di,cx  ; Current Row at the small bmp (each time -1)
	add di,[BmpTop] ; add the Y on entire screen
	
 
	; next 5 lines  di will be  = cx*320 + dx , point to the correct screen line
	mov cx,di
	shl cx,6
	shl di,8
	add di,cx
	add di,dx
	 
	; small Read one line
	mov ah,3fh
	mov cx,[BmpColSize]  
	add cx,bp  ; extra  bytes to each row must be divided by 4
	mov dx,offset ScrLine
	int 21h
	; Copy one line into video memory
	cld ; Clear direction flag, for movsb
	mov cx,[BmpColSize]  
	mov si,offset ScrLine
	rep movsb ; Copy line to the screen
	
	pop dx
	pop cx
	 
	loop @@NextLine
	
	pop cx
	ret
endp ShowBMP 





;---------------------
;---------------------
;---------------------
;---------------------
;basic input output proc section 
;---------------------
;---------------------
;---------------------
;---------------------



;===========================
;description - return pixel color
;input - push x,y 
;output - al (pixel color)
;variables - none
;===========================
proc PixelColor
	push bp
	mov bp, sp
	push cx
	push dx
	
	mov bh, 0
	mov cx, [bp + 6]
	mov dx, [bp + 4]
	mov ah, 0dh
	int 10h
	
	pop dx
	pop cx
	pop bp
	ret 4
endp PixelColor

;===========================
;description - Prints a new line
;input - none
;output - console
;variables - New_Line
;===========================
proc NewLine
	push ax
	push dx
	
	mov ah, 9h
	mov dx, offset New_Line
	int 21h
	
	pop dx
	pop ax
	ret
endp

;===========================
;description - Prints a string
;input - put string offset in dx
;output - console
;variables - none
;===========================
proc PrintString
	push ax
	
	mov ah, 9h
	int 21h
	
	pop ax
	ret
endp


;===========================
;description - Prints a character
;input - put char ascii in dl
;output - console
;variables - none
;===========================
proc PrintChar
	push ax
	
	mov ah, 2
	int 21h
	
	pop ax
	ret
endp

;===========================
;description - Input a character
;input - console
;output - al contains the ascii
;variables - none
;===========================
proc InputChar
	mov ah, 1
	int 21h

	ret
endp

;===========================
;description - Input a string
;input - console, dx contains offset of the string
;output - [dx]
;variables - none
;===========================
proc InputString
	push ax
	
	mov ah, 1
	int 21h
	
	pop ax
	ret
endp






;===========================
;description - Draws a vertical line
;input -  push in that order: x,y,len,color
;output - screen
;variables - none
;===========================
proc DrawVerticalLine 

	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	
	
	mov bh, 0
	mov cx, [bp+6]
@@DrawVertLine:
	push cx
	mov cx, [bp+10]
	mov dx, [bp+8]
	mov al, [bp+4]
	mov ah, 0ch
	int 10h
	pop cx
	inc [bp+8]
	loop @@DrawVertLine
	
	;mov ax, 2
	;int 10h

	pop cx
	pop bx
	pop ax
	pop bp

	ret 8
endp DrawVerticalLine



;===========================
;description - Draws a rectangle
;input - push in that order: x,y,len,wid,color
;output - screen
;variables - none
;===========================
proc DrawFullRect
	push bp
	mov bp, sp
	push cx
	
	mov cx, [bp+6]
@@DrawR:
	push [bp+12]
	push [bp+10]
	push [bp+8]
	push [bp+4]
	call DrawVerticalLine
	add [bp+12], 1
	loop @@DrawR

	pop cx
	pop bp
	
	ret 10
endp DrawFullRect


;===========================
;description - Prints the contain of ax
;input - ax
;output - screen
;variables - none
;===========================
proc ShowAxDecimal
       push ax
	   push bx
	   push cx
	   push dx
	   
	   ; check if negative
	   test ax,08000h
	   jz PositiveAx
			
	   ;  put '-' on the screen
	   push ax
	   mov dl,'-'
	   mov ah,2
	   int 21h
	   pop ax

	   neg ax ; make it positive
PositiveAx:
       mov cx,0   ; will count how many time we did push 
       mov bx,10  ; the divider
   
put_mode_to_stack:
       xor dx,dx
       div bx
       add dl,30h
	   ; dl is the current LSB digit 
	   ; we cant push only dl so we push all dx
       push dx    
       inc cx
       cmp ax,9   ; check if it is the last time to div
       jg put_mode_to_stack

	   cmp ax,0
	   jz pop_next  ; jump if ax was totally 0
       add al,30h  
	   mov dl, al    
  	   mov ah, 2h
	   int 21h        ; show first digit MSB
	       
pop_next: 
       pop ax    ; remove all rest LIFO (reverse) (MSB to LSB)
	   mov dl, al
       mov ah, 2h
	   int 21h        ; show all rest digits
       loop pop_next
		
		mov bh, 0
		mov dh, 2
		mov dl, 74
		mov ah, 2
		int 10h
	   
	   mov dl, 20h
       mov ah, 2h
	   int 21h
   
	   pop dx
	   pop cx
	   pop bx
	   pop ax
	   
	   ret
endp ShowAxDecimal

;===========================
;description - prints any word size number in decimal
;input - push number
;output - screen
;variables - none
;===========================
proc Print
	push bp
	mov bp, sp
	push ax
	push bx
	push dx
	
	; mov bh, 0
	; mov dh, 0
	; mov dl, 200
	; mov ah, 2
	; int 10h
	
	mov ax, [bp +4]
	call ShowAxDecimal
	
	pop bp
	pop ax
	pop bx
	pop dx
	ret 2
endp

;===========================
;description - changes dosbox into Graphic mode
;input - none
;output - none
;variables - none
;===========================
proc  SetGraphic
	push ax
	mov ax,13h   ; 320 X 200 
				 ;Mode 13h is an IBM VGA BIOS mode. It is the specific standard 256-color mode 
	int 10h
	pop ax
	ret
endp 	SetGraphic

;===========================
;description - changes dosbox into text mode
;input - none
;output - none
;variables - none
;===========================
proc SetText
	push ax
	mov ax, 2
	int 10h
	pop ax
	ret
endp SetText


;---------------------
;---------------------
;---------------------
;---------------------
;Random proc section 
;---------------------
;---------------------
;---------------------
;---------------------




; Description  : get RND between any bl and bh includs (max 0 -255)
; Input        : 1. Bl = min (from 0) , BH , Max (till 255)
; 			     2. RndCurrentPos a  word variable,   help to get good rnd number
; 				 	Declre it at DATASEG :  RndCurrentPos dw ,0
;				 3. EndOfCsLbl: is label at the end of the program one line above END start		
; Output:        Al - rnd num from bl to bh  (example 50 - 150)
; More Info:
; 	Bl must be less than Bh 
; 	in order to get good random value again and agin the Code segment size should be 
; 	at least the number of times the procedure called at the same second ... 
; 	for example - if you call to this proc 50 times at the same second  - 
; 	Make sure the cs size is 50 bytes or more 
; 	(if not, make it to be more) 
proc RandomByCs
    push es
	push si
	push di
	
	mov ax, 40h
	mov	es, ax
	
	sub bh,bl  ; we will make rnd number between 0 to the delta between bl and bh
			   ; Now bh holds only the delta
	cmp bh,0
	jz @@ExitP
 
	mov di, [word RndCurrentPos]
	call MakeMask ; will put in si the right mask according the delta (bh) (example for 28 will put 31)
	
RandLoop: ;  generate random number 
	mov ax, [es:06ch] ; read timer counter
	mov ah, [byte cs:di] ; read one byte from memory (from semi random byte at cs)
	xor al, ah ; xor memory and counter
	
	; Now inc di in order to get a different number next time
	inc di
	cmp di,(EndOfCsLbl - start - 1)
	jb @@Continue
	mov di, offset start
@@Continue:
	mov [word RndCurrentPos], di
	
	and ax, si ; filter result between 0 and si (the nask)
	cmp al,bh    ;do again if  above the delta
	ja RandLoop
	
	add al,bl  ; add the lower limit to the rnd num
		 
@@ExitP:	
	pop di
	pop si
	pop es
	ret
endp RandomByCs



; make mask acording to bh size 
; output Si = mask put 1 in all bh range
; example  if bh 4 or 5 or 6 or 7 si will be 7
; 		   if Bh 64 till 127 si will be 127
Proc MakeMask    
    push bx

	mov si,1
    
@@again:
	shr bh,1
	cmp bh,0
	jz @@EndProc
	
	shl si,1 ; add 1 to si at right
	inc si
	
	jmp @@again
	
@@EndProc:
    pop bx
	ret
endp  MakeMask




EndOfCsLbl:

END start





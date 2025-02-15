.model tiny
.data
    Buffer db 128 dup(0)                    ; Buffer for command line arguments
    NoArgsMsg db 'No arguments provided.$'  ; if no argumets provided
; ------------------------------------------------------------------------------------
    strData db 0, 0, 0, 0, 0, 0, 0, 0  ; Initialize a byte array in memory
;		       |  |  |  |  |  |  |  |
;              |  |  |  |  |  |  |  |_color
;              |  |  |  |  |  |  |  
;              |  |  |  |  |  |  |____symbol
;		       |  |  |  |  |  | 
;		       |  |  |	|  |  |__________start y coordinate 
;		       |  |  |	|  |		
;	           |  |  |	|  |_____________start x coordinate
;              |  |  |  |
;		       |  |  |  |__________________________________number of cols
;		       |  |  |		
;		       |  |  |_____________________________________number of strs
;              |  |                                                               
;              |  |________________________________________________________cols counter
;              |
;              |___________________________________________________________strs counter   

;-------------------------------------------------------------------------------------

    boxParameters db 0, 0, 0, 0, 0 ; // TODO rename
;                    |  |  |  |____type
;                    |  |  |
;                    |  |  |__color
;                    |  |
;                    |  |__height
;                    |___________width

    boxBorderSymbols db 11 dup(0)  ; Initialize box in memory // TODO rename (boxBorderSymbols)

    ; ---------- string struct ----------
    phrase db 256 dup(0)
    lngth db 1 dup(0)
    ; -----------------------------------

    ; macro for calling CreateBoxPart
CreateBoxPartMacro macro OffsetForOuter, OffsetForInner, fixOuter, fixInner, startX, startY, symbolOffset,  colorOffset

    mov al, [boxParameters + OffsetForOuter]
    sub al, fixOuter
    mov ah, [boxParameters + OffsetForInner]
    sub ah, fixInner
    mov bl, [si + symbolOffset]
    mov bh, [boxParameters + colorOffset]
    mov byte ptr [strData + 2], al
    mov byte ptr [strData + 3], ah
    mov byte ptr [strData + 4], startX
    mov byte ptr [strData + 5], startY
    mov byte ptr [strData + 6], bl
    mov byte ptr [strData + 7], bh
    call CreateBoxPart
endm

.code
org 100h
Start:
    call GetCommandArgs
    mov ah, 09h         ; DOS function for printing string
    lea dx, boxBorderSymbols      ; move offset of Buffer to dx
    int 21h             ; �맮� ���뢠��� ��� �뢮�� ��ப�

    ;mov byte ptr [boxParameters+0], 15 ; width
    ;mov byte ptr [boxParameters+1], 9  ; height
    call BoxInfoProc


    ; Program termination
    mov ax, 4C00h
    int 21h

;|-----------------------------|
;| Get command line arguments  |
;| Entry: None                 |
;| Exit:  None                 |
;| Destr: AX, CX, SI, DI, ES   |
;|-----------------------------|

GetCommandArgs proc
    mov ax, ds ; save data segment to ax
    mov es, ax
    mov cl, es:[80h] ; get number of command line arguments

    cmp cl, 0   ; if no arguments exit 
    je NoArgs   

    mov si, 81h ; save offset (first letter of the string in cmd line)
    lea di, Buffer      ; DI points to a buffer to store arguments

    ; copy arguments to buffer
CopyArguments:
    lodsb               ; Load byte from [SI] into AL, increment SI

    cmp al, 0Dh         ; if we have reached the end of the line (all args has been copied)
    je Done

    stosb               ; Store byte from AL to [DI], increment DI

    loop CopyArguments  ; repeat until we have copied all arguments 
                        ; (decreases CX, if after CX > 0 go to the label)
    
Done:
    ; add zero byte to the of buffer
    mov byte ptr [di], 0

    ; 
    lea si, Buffer       ; SI point to the start of the buffer
    call ParseNumbers   
    call ParseStrings   

    ret                 ; return from GetCommandsArgs
NoArgs:
    ; if no args, print message about it
    mov ah, 09h         ; DOS function for printing string
    lea dx, NoArgsMsg   ; get offset of the message
    int 21h             ; call DOS interrupt
    ret
GetCommandArgs endp

;|-------------------------------|
;| Parse numbers from arguments  |
;| Entry: SI = pointer to buffer |
;| Exit:  None                   |
;| Destr: AX, BX, SI             |
;|-------------------------------|

ParseNumbers proc
    mov bl, 10
    lodsb ; skip first space

    ; read first number width to boxParameters[0]
    readNum1:
    mov al, [boxParameters]
    mul bl
    mov [boxParameters], al
    lodsb                   ; Load byte from [SI] into AL, increment SI
    sub al, '0'             ; convert char to digit
    add [boxParameters], al
    mov al, [si]
    cmp al, ' '
    jne readNum1

    lodsb ; skip space between numbers

    ; read second number height to boxParameters[1]
    readNum2:
    mov al, [boxParameters + 1]   ; <---|
    mul bl                  ; <---| multiply previous digit by 10
    mov [boxParameters + 1], al   ; <---|

    lodsb                   ; Load byte from [SI] into AL, increment SI
    sub al, '0'             ; convert char to digit
    add [boxParameters + 1], al   ; add new digit to the number

    mov al, [si]            ; <---|
    cmp al, ' '             ; <---| compare next char with space
    jne readNum2            ; <---|

    lodsb ; skip space between numbers

    ; get first digit of hex number
    mov bl, 16      ; because now it's FIRST digit of two-hex number

    lodsb           ; load byte from [SI] into AL, increment SI
    cmp al, '9'     ; compare with '9'
    ja isNum1     ; if less or equal, go to isNum
    call isNum
isNum1:
    cmp al, '9'     ; again compare with '9'
    jbe isChar1      ; if it's A, B, C, D, E or F
    call isChar
isChar1:

    ; get second digit of hex number
    xor bl, bl      ; <---| clear bl because now it's SECOND digit of two-hex number
    inc bl          ; <---|

    lodsb           ; load byte from [SI] into AL, increment SI
    cmp al, '9'     ; compare with '9'
    ja isNum2     ; if less or equal, go to isNum
    call isNum
isNum2:
    cmp al, '9'     ; again compare with '9'
    jbe isChar2      ; if it's A, B, C, D, E or F
    call isChar
isChar2:

    ; skip forth number

    lodsb               ; skip space between numbers

    ; save type of border
    lodsb
    sub al, '0'
    mov [boxParameters + 3], al   

    lodsb               ; skip space between number and string

    ret                 ; parsing numbers has been ended
ParseNumbers endp

;|------------------------------|
;| Convert character to digit   |
;| Entry: AL = num as character |
;|        BL = multiplier       |
;| Exit:  None                  |
;| Destr: AX, BL                |
;|------------------------------|

isNum proc
    sub al, '0'             ; convert digit char to digit
    mul bl                  ; multiply previous digit by 16 if it's first digit or 0 if it's second
    add [boxParameters + 2], al   ; add new digit to the number
    ret
isNum endp

;|-----------------------------|
;| Convert hex char to digit   |
;| Entry: AL = character (A-F) |
;|        BL = multiplier      |
;| Exit:  None                 |
;| Destr: AX, BL               |
;|-----------------------------|

isChar proc
    sub al, '1'             ; convert char (A, B, C, D, E or F) to digit
    mul bl                  ; multiply previous digit by 16 if it's first digit or 0 if it's second
    add [boxParameters + 2], al   ; add new digit to the number
    ret
isChar endp

;|-------------------------------|
;| Parse strings from arguments  |
;| Entry: SI = pointer to buffer |
;| Exit:  None                   |
;| Destr: AX, DI, SI             |
;|-------------------------------|

ParseStrings proc
    cmp [boxParameters+ 3], 0           ; <---| if type was not 0 (custom type) so skip all func
    jne ParseStringsEnd                 ; <---|

    ; first string is a border eadges
    lea di, boxBorderSymbols            ; DI point to the start of the boxBorderSymbols
    call CopyString                     ; call func for copying string

    ; second string is a phrase
    lea di, phrase                      ; DI point to the start of the phrase
    call CopyString                     ; call func for copying string

ParseStringsEnd:
    ret                                 ; return from function
ParseStrings endp

;|---------------------------------|
;| Copy string to destination      |
;| Entry: SI = source pointer      |
;|        DI = destination pointer |
;| Exit:  None                     |
;| Destr: AX, DI, SI               |
;|---------------------------------|

CopyString proc
    mov [lngth], 0
CopyLoop:
    lodsb               ; load byte from [SI] into AL, increment SI

    cmp al, ' '         ; <---| 
    je CopyDone         ; <---| finish copying if in ax space (end of first str) or
    cmp al, 0Dh         ; <---| 0Dh ~ \n (end of second str)
    je CopyDone         ; <---| 
    cmp al, 0
    je CopyDone

    inc [lngth]

    stosb               ; store byte from AL to [DI], increment DI
    jmp CopyLoop        ; continue copying
CopyDone:
    ; add '$' as the end of the string
    mov byte ptr [di], '$'
    ret                 ; return from function
CopyString endp

; |----------------------------------------------------------|
; | Draws a box and text inside it                           |
; | Entry:                                                   |
; |   - boxParameters: width and height of the box (2 bytes) |
; |   - box: characters for drawing the box                  |
; |   - phrase: text to display inside the box               |
; | Exit: None                                               |
; | Destr: AX, BX, CX, DX, SI                                |
; |----------------------------------------------------------|

BoxInfoProc proc
    mov dx, offset boxBorderSymbols
    mov si, dx
    ;-------------------- top center line --------------------
    CreateBoxPartMacro 4, 0, 0, 1, 0, 0, 1, 2
    ;mov al, [boxParameters]
    ;mov byte ptr [strData + 2], 1     ; Set value for outer loop counter
    ;mov byte ptr [strData + 3], al    ; Set value for inner loop counter
;
    ;mov byte ptr [strData + 4], 0     ; Set value for start x coordinate
    ;mov byte ptr [strData + 5], 0     ; Set value for start y coordinate
;
    ;mov al, [si + 1]                ; Load a byte from memory to the address in DX in AL
    ;mov byte ptr [strData + 6], al    ; We save the byte from AL to memory at strData + 6
    ;mov al, [boxParameters + 2]
    ;mov byte ptr [strData + 7], al   ; set value for color
    ;
    ;call CreateBoxPart 	; Call the PrtStr procedure

    ;-------------------- central box of symbols --------------------
    CreateBoxPartMacro 1, 0, 2, 1, 1, 1, 4, 2
    ;mov al, [boxParameters]
    ;dec al
    ;mov ah, [boxParameters + 1]
    ;sub ah, 2
    ;mov byte ptr [strData+2], ah    ; Set value for outer loop counter
    ;mov byte ptr [strData+3], al    ; Set value for inner loop counter
;
    ;mov byte ptr [strData+4], 0     ; Set value for start x coordinate
    ;mov byte ptr [strData+5], 1     ; Set value for start y coordinate
    ;
    ;mov al, [si + 4]                
    ;mov byte ptr [strData+6], al    ; Load a char byte from memory
    ;mov al, [boxParameters + 2]
    ;mov byte ptr [strData + 7], al   ; set value for color
   ;
    ;call CreateBoxPart 	; Call the PrtStr procedure

    ;-------------------- bottom center line --------------------
    mov cl,  [boxParameters + 1]
    dec cl
    CreateBoxPartMacro 4, 0, 0, 0, 0, cl, 7, 2
    ;mov ah, [boxParameters + 1]
    ;sub ah, 1
    ;mov al, [boxParameters]
    ;mov byte ptr [strData+2], 1     ; Set value for outer loop counter
    ;mov byte ptr [strData+3], al    ; Set value for inner loop counter
    ;
    ;mov byte ptr [strData+4], 0     ; Set value for start x coordinate
    ;mov byte ptr [strData+5], ah    ; Set value for start y coordinate
;
    ;mov al, [si + 7]
    ;mov byte ptr [strData+6], al    ; Load a char byte from memory
    ;mov al, [boxParameters + 2]
    ;mov byte ptr [strData + 7], al   ; set value for color
    ;
    ;call CreateBoxPart 	                ; Call the PrtStr procedure
    
    ;-------------------- right center line --------------------
    mov cl,  [boxParameters]
    dec cl
    CreateBoxPartMacro 1, 4, 1, 0, cl, 1, 5, 2
    ;mov ah, [boxParameters+1]
    ;sub ah, 2
    ;mov al, [boxParameters]
    ;sub al, 1
    ;mov byte ptr [strData+2], ah    ; Set value for outer loop counter
    ;mov byte ptr [strData+3], 1     ; Set value for inner loop counter
;
    ;mov byte ptr [strData+4], al  ; Set value for start x coordinate
    ;mov byte ptr [strData+5], 1   ; Set value for start y coordinate
;
    ;mov al, [si + 5]           
    ;mov byte ptr [strData+6], al   ; Load a char byte from memory
    ;mov al, [boxParameters + 2]
    ;mov byte ptr [strData + 7], al   ; set value for color
    ;mov byte ptr [strData], 0
    ;mov byte ptr [strData + 1], 0
    ;call CreateBoxPart 	               ; Call the PrtStr procedure

    ;-------------------- left center line --------------------
    CreateBoxPartMacro 1, 4, 1, 0, 0, 1, 3, 2
    ; mov ah, [boxParameters+1]
    ; sub ah, 2
    ; mov byte ptr [strData+2], ah    ; Set value for outer loop counter
    ; mov al, [boxParameters]
    ; mov byte ptr [strData+3], 1     ; Set value for inner loop counter
    ; mov byte ptr [strData+4], 0
    ; mov byte ptr [strData+5], 1
    ; mov al, [si + 3]               
    ; mov byte ptr [strData+6], al    ; Load a char byte from memory
    ; mov al, [boxParameters + 2]
    ; mov byte ptr [strData + 7], al   ; set value for color
    ; mov byte ptr [strData], 0
    ; mov byte ptr [strData + 1], 0
    ; call CreateBoxPart 	                ; Call the PrtStr procedure

    ;-------------------- left top corner --------------------

    CreateBoxPartMacro 4, 4, 0, 0, 0, 0, 0, 2
    ;mov byte ptr [strData+2], 1     ; Set value for outer loop counter
    ;mov byte ptr [strData+3], 1     ; Set value for inner loop counter
    ;mov byte ptr [strData+4], 0
    ;mov byte ptr [strData+5], 0
    ;mov al, [si]                   
    ;mov byte ptr [strData+6], al    ; Load a char byte from memory
    ;mov al, [boxParameters + 2]
    ;mov byte ptr [strData + 7], al   ; set value for color
    ;mov byte ptr [strData], 0
    ;mov byte ptr [strData + 1], 0
    ;call CreateBoxPart 	                ; Call the PrtStr procedure
    
    ;-------------------- right top corner --------------------
    mov cl,  [boxParameters]
    dec cl
    CreateBoxPartMacro 4, 4, 0, 0, cl, 0, 2, 2

    ; mov al, [boxParameters]
    ; sub al, 1
    ; mov byte ptr [strData+2], 1    ; Set value for outer loop counter
    ; mov byte ptr [strData+3], 1    ; Set value for inner loop counter
    ; mov byte ptr [strData+4], al
    ; mov byte ptr [strData+5], 0
    ; mov al, [si+2]                 
    ; mov byte ptr [strData+6], al   ; Load a char byte from memory
    ; mov al, [boxParameters + 2]
    ; mov byte ptr [strData + 7], al   ; set value for color
    ; mov byte ptr [strData], 0
    ; mov byte ptr [strData + 1], 0
    ; call CreateBoxPart 	               ; Call the PrtStr procedure
    
    ;-------------------- left bottom corner --------------------
    mov cl,  [boxParameters + 1]
    dec cl
    mov ch,  [boxParameters]
    dec ch
    CreateBoxPartMacro 4, 4, 0, 0, 0, cl, 6, 2

    ;mov al, [boxParameters]
    ;mov ah, [boxParameters+1] 
    ;sub ah, 1
    ;mov byte ptr [strData+2], 1    ; Set value for outer loop counter
    ;mov byte ptr [strData+3], 1    ; Set value for inner loop counter
    ;mov byte ptr [strData+4], 0
    ;mov byte ptr [strData+5], ah
    ;mov al, [si + 6]
    ;mov byte ptr [strData+6], al   ; Load a char byte from memory
    ;mov al, [boxParameters + 2]
    ;mov byte ptr [strData + 7], al   ; set value for color
    ;mov byte ptr [strData], 0
    ;mov byte ptr [strData + 1], 0
    ;call CreateBoxPart 	; Call the PrtStr procedure
    
    ;-------------------- right bottom corner --------------------
    mov cl,  [boxParameters + 1]
    dec cl
    mov ch,  [boxParameters]
    dec ch
    CreateBoxPartMacro 4, 4, 0, 0, ch, cl, 8, 2
    ; mov al, [boxParameters]
    ; sub al, 1
    ; mov ah, [boxParameters+1]
    ; sub ah, 1
    ; mov byte ptr [strData+2], 1    ; Set value for outer loop counter
    ; mov byte ptr [strData+3], 1    ; Set value for inner loop counter
    ; mov byte ptr [strData+4], al
    ; mov byte ptr [strData+5], ah
    ; mov al, [si + 8]
    ; mov byte ptr [strData+6], al   ; Load a char byte from memory
    ; mov al, [boxParameters + 2]
    ; mov byte ptr [strData + 7], al   ; set value for color
    ; mov byte ptr [strData], 0
    ; mov byte ptr [strData + 1], 0
    ; call CreateBoxPart 	; Call the PrtStr procedure
    ; 
    ;-------------------- print phrase in box --------------------
    mov al, [boxParameters + 1]
    inc al 
    shr al, 1
    mov bh, al

    mov al, [boxParameters]
    shr al, 1
    sub al, 2
    mov ah, bh
    dec ah

    mov al, [boxParameters + 1]
    shr al, 1
    mov bh, al

    xor ax, ax
    mov al, [boxParameters]
    sub al, [lngth]
    shr al, 1

    mov ah, bh

    mov dx, offset phrase
    mov si, dx
    phraseFor:
    mov byte ptr [strData+2], 1    ; Set value for outer loop counter
    mov byte ptr [strData+3], 1    ; Set value for inner loop counter
    mov byte ptr [strData+4], al
    mov byte ptr [strData+5], ah
    mov bl, [si]                   ; ??????? ???? ?? ????? ?? ????? ? DX ? AL
    mov byte ptr [strData+6], bl   ; Load a char byte from memory
    mov byte ptr [strData+7], 0fh  ; Set color to the char
    push ax
    push bx
    call CreateBoxPart 	           ; Call the PrtStr procedure
    pop bx
    pop ax
    inc al
    inc si
    mov bl, [si]
    cmp bl, '$'
    jne phraseFor

    ret
BoxInfoProc endp
    
;|-----------------------------|
;| Draw a char in video memory |
;| Entry: AL = char to write   |
;|        AH = color attribute |
;| Exit:  None                 |
;| Destr: None                 |
;|-----------------------------|
DrawCh proc
    push cx
    mov cx, 0B800h
    mov es, cx
    mov es:[bx], ax
    pop cx
    ret
DrawCh endp

;|-----------------------------|
;| Print a string of characters|
;| Entry: None                 |
;| Exit:  None                 |
;| Destr: AX, BX, CX, DX       |
;|-----------------------------|
CreateBoxPart proc
    mov byte ptr [strData], 0    ; Outer loop counter
    mov byte ptr [strData+1], 0  ; Inner loop counter

outForY:
    ; Calculate Y position
    mov al, [strData]            ; Load outer loop counter
    add al, [strData + 5]
    mov ah, 0                    ; Clear AH for multiplication
    mov cx, 160                  ; Number of bytes per row // TODO make const (equ)
    mul cx                       ; AX = Y * 160
    mov bx, ax
    mov al, [strData + 4]
    mov ah, 0
    mov cx, 2
    mul cx
    add bx, ax                   ; BX = starting position in video memory

outForX:
    ; Draw character
    mov al, [strData+6]               ; Character 'A' with attribute 0DAh
    mov ah, [strData+7]
    call DrawCh                  ; Call DrawCh to draw character
    add bx, 2                    ; Move to the next position

    ; Increment inner loop counter
    mov al, [strData+1]
    add al, 1
    mov [strData+1], al

    ; Check condition to exit inner loop
    mov ah, [strData+3]          ; Load value for comparison
    cmp al, ah
    jb outForX                   ; If AL < [strData+3], continue inner loop

    ; Reset inner loop counter
    mov byte ptr [strData+1], 0

    ; Increment outer loop counter
    mov al, [strData]
    add al, 1
    mov [strData], al

    ; Check condition to exit outer loop
    mov ah, [strData+2]          ; Load value for comparison
    cmp al, ah
    jb outForY                   ; If AL < [strData+2], continue outer loop

    ret
CreateBoxPart endp

end Start

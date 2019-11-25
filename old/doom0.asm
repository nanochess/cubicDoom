        ;
        ; D project
        ;
        ; by Oscar Toledo G.
        ;
        ; Creation date: Nov/21/2019.
        ; Revision date: Nov/22/2019. Now working.
        ; Revision date: Nov/23/2019. Optimized.
        ;

        ;
        ; Tricks used:
        ; o "Slow" ray-casting so doesn't matter if hits horizontal or
        ;   vertical wall.

        cpu 8086

    %ifdef com_file
        org 0x0100
    %else
        org 0x7c00
    %endif

px:     equ 0x0006      ; Current X position (4.12)
py:     equ 0x0004      ; Current Y position (4.12)
pa:     equ 0x0002      ; Current screen angle
oldtim: equ 0x0000      ; Old time

        ;
        ; Start of the game
        ;
        mov ax,0x0013   ; Graphics mode 320x200x256 colors
        int 0x10        ; Setup video mode
        cld             ; Clear Direction flag.
        mov ax,0xa000   ; Point to video memory.
        mov ds,ax
        mov es,ax
        mov ah,0x18     ; Start point at maze
        push ax
        push ax
        mov al,0x04
        push ax
        push ax
        mov bp,sp
game_loop:
        ;
        ; Wait a frame (18.2 hz)
        ; 
.1:
        mov ah,0x00     ; Get ticks
        int 0x1a        ; Call BIOS time service
        pop ax
        cmp ax,dx       ; Same as old time?
        push dx                 
        je .1           ; Yes, wait.

        ;
        ; Draw 3D view
        ;
        xor di,di       ; Column number is zero
.2:
        mov ax,[bp+pa]  ; Get vision angle
        sub al,20       ; Almost 60 degrees to left
        add ax,di       ; Plus current column angle
        call get_dir    ; Get position and direction
        xor si,si       ; Wall distance = 0
.3:
        inc si          ; Count distance to wall
        call read_maze  ; Verify wall hit
        jns .3          ; Continue if it was open space

.4:
        lea ax,[di+12]  ; Get cos(-30) to cos(30)
        call get_sin    ; Get cos (8 bit fraction)
        mul si          ; Correct wall distance to...
        mov al,ah       ; ...avoid fishbowl effect
        mov ah,0        ; Divide by 256
        inc ax          ; Avoid zero value
        xchg ax,si

        mov ax,0x0800   ; Constant for projection plane
        cwd
        div si          ; Divide
        cmp ax,198      ; Limit to screen height
        jb .14
        mov ax,198
.14:    xchg ax,si

        push di
        mov cl,3        ; Multiply column by 8 pixels
        shl di,cl

        mov ax,si       ; Get distance
        mov cl,4        ; Divide by 16
        shr ax,cl
        add al,18       ; Add grayscale color set
        xchg ax,bx      ; Put into BX

        mov ax,200      ; Screen height...
        sub ax,si       ; ...minus wall height
        shr ax,1        ; Divide by 2

        mov cx,ax
        push cx
        mov al,0x01     ; Blue color
        call fill_column
        mov cx,si
        xchg ax,bx      ; Wall color
        call fill_column
        pop cx
        mov al,0x03     ; Floor color
        call fill_column
        pop di
        inc di          ; Increase column
        cmp di,40       ; 40 columns draw?
        jne .2          ; No, jump

        mov ah,0x02     ; Service 0x02 = Read modifier keys
        int 0x16        ; Call BIOS

        mov bx,[bp+pa]  ; Get current angle
        test al,0x04    ; Left Ctrl pressed?
        je .8
        dec bx          ; Decrease angle
.8:
        test al,0x08    ; Left Alt pressed?
        je .9
        inc bx          ; Increase angle
.9:
        test al,0x01    ; Right shift pressed?
        je .11
        int 0x20        ; Exit
.11:
        mov [bp+pa],bx  ; Update angle

        test al,0x02    ; Left shift pressed?
        je .10
        xchg ax,bx      ; Put angle into AX
        call get_dir    ; Get position and direction
        add cx,cx       ; Multiply X angle by 4
        add cx,cx
        add dx,dx       ; Multiply Y angle by 4
        add dx,dx
        call read_maze  ; Move and check for wall hit
        js .10          ; Hit, jump without updating position.
        mov [bp+px],ax  ; Update X position
        mov [bp+py],bx  ; Update Y position
.10:
        jmp game_loop   ; Repeat game loop

        ;
        ; Get a direction vector
        ;
get_dir:
        push ax
        call get_sin    ; Get sine
        xchg ax,cx      ; Onto CX
        pop ax
        add al,32       ; Add 90 degrees...
        call get_sin    ; ...to get cosine
        xchg ax,dx      ; Onto DX
        mov ax,[bp+px]  ; Get X position
        mov bx,[bp+py]  ; Get Y position
        ret

        ;
        ; Get sine
        ;
get_sin:
        test al,64      ; Angle >= 180 degrees?
        pushf
        test al,32      ; Angle 90-179 or 270-359 degrees?
        je .2
        xor al,31       ; Invert bits (saves byte tables)
.2:
        and ax,31       ; Only 90 degrees in table
        mov bx,sin_table
        cs xlat         ; Get fraction
        popf
        je .1           ; Jump if angle less than 180
        neg ax          ; Else negate result
.1:
        ret

        ;
        ; Read maze
        ;
read_maze:
        add ax,cx       ; Move X
        add bx,dx       ; Move Y
        push ax
        push bx
        push cx
        mov cl,0x04     
        shr ah,cl       ; Divide X by 4096
        shr bh,cl       ; Divide Y by 4096
        mov cl,ah
        mov bl,bh
        mov bh,0
        shl bx,1        ; Convert Y to words
        cs mov ax,[bx+map1]     ; Read maze word
        shl ax,cl       ; Extract maze bit
        or ax,ax        ; Check for bit 
        pop cx
        pop bx
        pop ax
        ret             ; Return

        ;
        ; Fill a screen column
        ;
fill_column:
        mov ah,al       ; Duplicate pixel value
.1:
        stosw           ; Draw 2 pixels
        stosw           ; Draw 2 pixels
        stosw           ; Draw 2 pixels
        stosw           ; Draw 2 pixels
        add di,0x0138   ; Go to next row
        loop .1         ; Repeat until fully drawn
        ret             ; Return

        ;
        ; Sine table (0.8 format)
        ;
sin_table:
	db 0x00,0x09,0x16,0x24,0x31,0x3e,0x47,0x53
	db 0x60,0x6c,0x78,0x80,0x8b,0x96,0xa1,0xab
	db 0xb5,0xbb,0xc4,0xcc,0xd4,0xdb,0xe0,0xe6
        db 0xec,0xf1,0xf5,0xf7,0xfa,0xfd,0xff,0xff

        ;
        ; Map
        ;
map1:
        dw 0xffff
        dw 0x8001
        dw 0xbffd
        dw 0x9e51
        dw 0x9e51
        dw 0x9e01
        dw 0x9e51
        dw 0x8451
        dw 0x8451
        dw 0x8451
        dw 0x87c1
        dw 0x8101
        dw 0x8101
        dw 0x8101
        dw 0x8001
        dw 0xffff

    %ifdef com_file
    %else
	times 510-($-$$) db 0x4f
	db 0x55,0xaa           ; Make it a bootable sector
    %endif


        ;
        ; D project
        ;
        ; by Oscar Toledo G.
        ;
        ; Creation date: Nov/21/2019.
        ; Revision date: Nov/22/2019. Now working.
        ; Revision date: Nov/23/2019. Optimized.
        ; Revision date: Nov/24/2019. Builds a world. Added evil cubes, and
        ;                             can shoot them. 517 bytes.
        ;

        ;
        ; TODO:
        ; o Save 7 bytes.
        ;
        ; Tricks used:
        ; o "Slow" ray-casting so doesn't matter if hits horizontal or
        ;   vertical wall.

        cpu 8086

EMPTY:  equ 0x00
WALL:   equ 0x80
ENEMY:  equ 0xc0

CEIL_COLOR:     equ 0x01
FLOOR_COLOR:    equ 0x03

    %ifdef com_file
        org 0x0100
    %else
        org 0x7c00
    %endif

down:   equ 0x000b
shot:   equ 0x000a
rnd:    equ 0x0008
px:     equ 0x0006      ; Current X position (4.12)
py:     equ 0x0004      ; Current Y position (4.12)
pa:     equ 0x0002      ; Current screen angle
oldtim: equ 0x0000      ; Old time
maze:   equ 0xff00

        ;
        ; Start of the game
        ;
start:
        mov ax,0x0013   ; Graphics mode 320x200x256 colors
        int 0x10        ; Setup video mode
        mov ax,0xa000   ; Point to video memory.
        mov ds,ax
        mov es,ax
restart:
        cld
        xor cx,cx
        push cx
        in ax,0x40
        push ax
        mov ah,0x18     ; Start point at maze
        push ax
        push ax
        mov cl,0x04
        push cx
        push cx
        mov bp,sp

        mov bx,maze
.0:     mov al,bl
        add al,0x11
        cmp al,0x22
        jb .5
        and al,0x0e
        mov al,EMPTY
        jne .4
.5:     mov al,WALL
.4:     mov [bx],al
        inc bx
        jne .0
        
        mov cl,12
        mov [bp+down],cl
        mov di,maze+34
        mov dl,12
.2:
        call random
        mov byte [di+bx],WALL
        call random
        mov byte [di+bx],ENEMY
        add di,16
        loop .2
game_loop:
        call wait_frame

        and dl,31
        jnz .16

        call get_dir    ; Also SI=0
        call get_pos
        mov cx,bx

        mov bl,0
.17:    cmp byte [bx],ENEMY
        jb .18
        mov di,bx
        mov al,bl
        mov ah,cl
        mov dx,0x0f0f
        and dx,ax
        and ax,0xf0f0
        cmp ah,al
        je .19
        lea di,[bx+0x10]
        jnb .19
        lea di,[bx-0x10]
.19:    cmp dh,dl
        je .20
        dec di
        jb .20
        inc di
        inc di
.20:    cmp byte [di],0
        jne .18
        mov al,[bx]
        mov byte [bx],0
        cmp di,cx
        stosb
        jne .18

.22:
        mov byte [si],0x0c
        add si,23
        je .23
        jnb .22
        push si
        call wait_frame
        pop si
        jmp .22
.23:
        jmp restart

.18:
        inc bx
        jne .17

.16:

        ;
        ; Draw 3D view
        ;
        mov di,39       ; Column number is 39
.2:
        lea ax,[di-20]  ; Almost 60 degrees to left
        add ax,[bp+pa]  ; Get vision angle
        call get_dir    ; Get position and direction
.3:
        call read_maze  ; Verify wall hit
        jnc .3          ; Continue if it was open space

.4:

        mov cx,0x1204   ; Add grayscale color set...
                        ; ...also load CL with 4. (division by 16)
        jz .24          ; Jump if normal wall
        mov ch,32       ; Rainbow

        cmp di,20
        jne .24         ; Jump if not at center
        cmp byte [bp+shot],0
        je .24          ; Jump if not shooting
        call get_pos
        inc byte [bx]
        cmp byte [bx],ENEMY+3
        jne .24
        mov byte [bx],0
        dec byte [bp+down]
        je .23
.24:
        lea ax,[di+12]  ; Get cos(-30) to cos(30)
        call get_sin    ; Get cos (8 bit fraction)
        mul si          ; Correct wall distance to...
        mov bl,ah       ; ...avoid fishbowl effect
        mov bh,dl       ; Divide by 256
        inc bx          ; Avoid zero value

        mov ax,0x0800   ; Constant for projection plane
        cwd
        div bx          ; Divide
        cmp ax,198      ; Limit to screen height
        jb .14
        mov ax,198
.14:    mov si,ax       ; Height of wall

        shr ax,cl       ; Divide distance by 16
        add al,ch
        xchg ax,bx      ; Put into BX

        push di
        dec cx          ; CL=3. Multiply column by 8 pixels
        shl di,cl

        mov ax,200
        sub ax,si       ; ...minus wall height
        shr ax,1        ; Divide by 2

        push ax
        push si
        xchg ax,cx
        mov al,CEIL_COLOR
        xor al,[bp+shot]
        call fill_column
        xchg ax,bx      ; Wall color
        pop cx
        call fill_column
        mov al,FLOOR_COLOR     
        pop cx
        call fill_column
        pop di
        dec di          ; Decrease column
        jns .2          ; Completed? No, jump.

        mov ah,0x02     ; Service 0x02 = Read modifier keys
        int 0x16        ; Call BIOS

        mov bx,[bp+pa]  ; Get current angle
        test al,0x04    ; Left Ctrl pressed?
        je .8
        dec bx          ; Decrease angle
        dec bx
.8:
        test al,0x08    ; Left Alt pressed?
        je .9
        inc bx          ; Increase angle
        inc bx
.9:
        mov ah,0
        test al,0x01    ; Right shift pressed?
        je .11
        test bh,0x01
        jne .11
        mov ah,6

.11:    mov [bp+shot],ah
        mov bh,al
        mov [bp+pa],bx  ; Update angle

        test al,0x02    ; Left shift pressed?
        je .10
        xchg ax,bx      ; Put angle into AX
        call get_dir    ; Get position and direction
        add cx,cx       ; Multiply X angle by 4
        add cx,cx
        add ax,ax       ; Multiply Y angle by 4
        add ax,ax
        call read_maze  ; Move and check for wall hit
        jc .10          ; Hit, jump without updating position.
        mov [bp+px],dx  ; Update X position
        mov [bp+py],bx  ; Update Y position
.10:
        jmp game_loop   ; Repeat game loop

        ;
        ; Get a direction vector
        ;
get_dir:
        xor si,si       ; Wall distance = 0
        mov dx,[bp+px]  ; Get X position
        push ax
        call get_sin    ; Get sine
        xchg ax,cx      ; Onto DX
        pop ax
        add al,32       ; Add 90 degrees to get cosine
        ;
        ; Get sine
        ;
get_sin:
        test al,64      ; Angle >= 180 degrees?
        pushf
        test al,32      ; Angle 90-179 or 270-359 degrees?
        je .2
        xor al,31       ; Invert bits (reduces table)
.2:
        and ax,31       ; Only 90 degrees in table
        mov bx,sin_table
        cs xlat         ; Get fraction
        popf
        je .1           ; Jump if angle less than 180
        neg ax          ; Else negate result
.1:
        mov bx,[bp+py]  ; Get Y position
        ret

        ;
        ; Read maze
        ;
read_maze:
        inc si          ; Count distance to wall
        add dx,cx       ; Move X
        add bx,ax       ; Move Y
        push bx
        push cx
        call get_pos
        mov bl,[bx]     ; Read maze byte
        shl bl,1        ; Carry = 1 = wall, Zero = Wall 0 / 1
        pop cx
        pop bx
        ret             ; Return

        ;
        ; Convert coordinates to position
        ;
get_pos:        
        mov bl,dh
        mov cl,0x04
        shr bl,cl
        and bh,0xf0
        or bl,bh
        mov bh,maze>>8
        ret

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
        ; Generate a pseudo-random number
        ;
random:
        mov al,251
        mul byte [bp+rnd]
        add al,83
        mov [bp+rnd],al
        mov ah,0
        div dl
        mov bl,ah
        mov bh,0
        ret

        ;
        ; Wait a frame (18.2 hz)
        ;
wait_frame:
.1:
        mov ah,0x00     ; Get ticks
        int 0x1a        ; Call BIOS time service
        cmp dx,[bp+oldtim]   ; Same as old time?
        je .1           ; Yes, wait.
        mov [bp+oldtim],dx
        ret

        ;
        ; Sine table (0.8 format)
        ;
sin_table:
	db 0x00,0x09,0x16,0x24,0x31,0x3e,0x47,0x53
	db 0x60,0x6c,0x78,0x80,0x8b,0x96,0xa1,0xab
	db 0xb5,0xbb,0xc4,0xcc,0xd4,0xdb,0xe0,0xe6
        db 0xec,0xf1,0xf5,0xf7,0xfa,0xfd,0xff,0xff

    %ifdef com_file
    %else
	times 510-($-$$) db 0x4f
	db 0x55,0xaa           ; Make it a bootable sector
    %endif


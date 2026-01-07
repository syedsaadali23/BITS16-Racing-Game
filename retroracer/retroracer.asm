BITS 16
org 0x100
jmp start

;-----------------------------------------------------
; Lane positions - FIXED positions to avoid road lines
;-----------------------------------------------------
LANE_LEFT   equ 102    ; Left lane X position 
LANE_CENTER equ 143    ; Center lane X position 
LANE_RIGHT  equ 183    ; Right lane X position 

current_lane: dw LANE_CENTER  ; Start in center lane
car_x_pos: dw LANE_CENTER     ; Current X position

CAR_Y_POS   equ 159
CAR_WIDTH   equ 35
CAR_HEIGHT  equ 38

; Enemy car dimensions
ENEMY_WIDTH  equ 33
ENEMY_HEIGHT equ 36

; NEW: Star bonus dimensions
STAR_WIDTH  equ 15
STAR_HEIGHT equ 15

spawn_timer:    dw 0
SPAWN_DELAY equ 120
random_seed: dw 0

scroll_counter: dw 0 

; Enemy car state
enemy_x_pos:   dw LANE_CENTER
enemy_y_pos:   dw 0
enemy_active:  db 0

; NEW: Star bonus state
star_x_pos:    dw LANE_CENTER
star_y_pos:    dw 0
star_active:   db 0
star_spawn_counter: dw 0
STAR_SPAWN_DELAY equ 180  ; Stars spawn less frequently than enemies

; NEW: Score tracking
score: dw 0

temp_enemy_x: dw 0
temp_enemy_width: dw 0

;-----------------------------------------------------
; Initialize random seed
;-----------------------------------------------------
init_random_seed:
    push ax
    push cx
    push dx
    
    mov ah, 00h
    int 1Ah
    mov [random_seed], dx
    
    pop dx
    pop cx
    pop ax
    ret

;-----------------------------------------------------
; Generate random number
;-----------------------------------------------------
get_random_number:
    push bx
    push dx
    
    mov ax, [random_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    adc dx, 0
    mov [random_seed], ax
    
    pop dx
    pop bx
    ret

;-----------------------------------------------------
; Get random lane index (0, 1, or 2)
;-----------------------------------------------------
get_random_lane_index:
    call get_random_number
    mov dx, 0
    mov bx, 3
    div bx
    mov ax, dx
    ret

;-----------------------------------------------------
; Wait for VBlank - CRITICAL FOR SMOOTHNESS
;-----------------------------------------------------
wait_vblank:
    push ax
    push dx
    
    mov dx, 0x03DA
.wait_not_vblank:
    in al, dx
    test al, 0x08
    jnz .wait_not_vblank
    
.wait_for_vblank:
    in al, dx
    test al, 0x08
    jz .wait_for_vblank
    
    pop dx
    pop ax
    ret

;-----------------------------------------------------
; Check keyboard input
;-----------------------------------------------------
check_keyboard:
    push ax
    
    mov ah, 01h
    int 16h
    jz .no_key
    
    mov ah, 00h
    int 16h
    
    cmp ah, 4Bh             ; Left arrow
    je .move_left
    cmp ah, 4Dh             ; Right arrow
    je .move_right
    cmp al, 27              ; ESC
    je .exit_game
    jmp .no_key
    
.move_left:
    mov ax, [current_lane]
    cmp ax, LANE_LEFT
    je .no_key
    
    cmp ax, LANE_CENTER
    je .go_to_left
    mov word [current_lane], LANE_CENTER
    jmp .update_car
    
.go_to_left:
    mov word [current_lane], LANE_LEFT
    jmp .update_car
    
.move_right:
    mov ax, [current_lane]
    cmp ax, LANE_RIGHT
    je .no_key
    
    cmp ax, LANE_CENTER
    je .go_to_right
    mov word [current_lane], LANE_CENTER
    jmp .update_car
    
.go_to_right:
    mov word [current_lane], LANE_RIGHT
    jmp .update_car

.update_car:
    jmp .no_key

.exit_game:
    pop ax
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h
    
.no_key:
    pop ax
    ret

;-----------------------------------------------------
; Check collision between player and enemy car

;-----------------------------------------------------
check_collision:
    push bx
    push cx
    push dx
    
    cmp byte [enemy_active], 0
    je .no_collision
    
    ; Player right edge
    mov ax, [car_x_pos]
    add ax, CAR_WIDTH
    
    ; Enemy left edge  
    mov bx, [enemy_x_pos]
    add bx, 1
    
    cmp ax, bx
    jle .no_collision
    
    ; Player left edge
    mov cx, [car_x_pos]
    
    ; Enemy right edge
    mov dx, [enemy_x_pos]
    add dx, 34
    
    cmp dx, cx
    jle .no_collision
    
    ; Player bottom edge
    mov ax, CAR_Y_POS
    add ax, CAR_HEIGHT
    
    ; Enemy top edge
    mov bx, [enemy_y_pos]
    
    cmp ax, bx
    jle .no_collision
    
    ; Player top edge
    mov cx, CAR_Y_POS
    
    ; Enemy bottom edge
    mov dx, [enemy_y_pos]
    add dx, ENEMY_HEIGHT
    
    cmp dx, cx
    jle .no_collision
    
    ; COLLISION DETECTED
    mov al, 1
    jmp .done
    
.no_collision:
    mov al, 0
    
.done:
    pop dx
    pop cx
    pop bx
    ret

;-----------------------------------------------------
; Check collision between player and star

;-----------------------------------------------------
check_star_collision:
    push bx
    push cx
    push dx
    
    cmp byte [star_active], 0
    je .no_collision
    
   
    
    ; Player right edge
    mov ax, [car_x_pos]
    add ax, CAR_WIDTH
    
    ; Star left edge  
    mov bx, [star_x_pos]
    add bx, 9
    
    cmp ax, bx
    jle .no_collision
    
    ; Player left edge
    mov cx, [car_x_pos]
    
    ; Star right edge
    mov dx, [star_x_pos]
    add dx, 20
    
    cmp dx, cx
    jle .no_collision
    
    ; Player bottom edge
    mov ax, CAR_Y_POS
    add ax, CAR_HEIGHT
    
    ; Star top edge
    mov bx, [star_y_pos]
    
    cmp ax, bx
    jle .no_collision
    
    ; Player top edge
    mov cx, CAR_Y_POS
    
    ; Star bottom edge
    mov dx, [star_y_pos]
    add dx, 15
    
    cmp dx, cx
    jle .no_collision
    
    ; COLLISION DETECTED WITH STAR!
    mov al, 1
    jmp .done
    
.no_collision:
    mov al, 0
    
.done:
    pop dx
    pop cx
    pop bx
    ret

;-----------------------------------------------------
; Draw filled rectangle
;-----------------------------------------------------
Drawing_loop:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push es
    
    mov ax, [bp+10]
    add ax, [bp+6]
    cmp ax, 320
    ja skip_draw
    cmp word [bp+8], 200
    jae skip_draw
    cmp word [bp+4], 0
    jbe skip_draw
    
    mov ax, 0xA000
    mov es, ax
    mov bx, [bp+8]
draw_next_row:
    mov di, bx
    shl di, 8
    mov ax, bx
    shl ax, 6
    add di, ax
    add di, [bp+10]
    mov cx, [bp+6]
    mov al, [bp+12]
    rep stosb
    inc bx
    cmp bx, [bp+4]
    jb draw_next_row
skip_draw:
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

;-----------------------------------------------------
; Draw dashed lines
;-----------------------------------------------------
Drawing_loop_lines:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push es
    
    mov ax, [bp+10]
    add ax, [bp+6]
    cmp ax, 320
    ja skip_draw_lines
    cmp word [bp+8], 200
    jae skip_draw_lines
    
    mov ax, 0xA000
    mov es, ax
    mov bx, [bp+8]
    mov si, [bp+4]
dash_loop:
    cmp bx, si
    jnb skip_draw_lines
    mov dx, bx
    add dx, 15
    cmp dx, si
    jb dash_ok
    mov dx, si
dash_ok:
    cmp dx, 200
    jb dash_in_bounds
    mov dx, 200
dash_in_bounds:
draw_dash_segment:
    cmp bx, dx
    jnb dash_gap
    mov di, bx
    shl di, 8
    mov ax, bx
    shl ax, 6
    add di, ax
    add di, [bp+10]
    mov cx, [bp+6]
    mov al, [bp+12]
    rep stosb
    inc bx
    jmp draw_dash_segment
dash_gap:
    add bx, 5
    cmp bx, si
    jnb skip_draw_lines
    cmp bx, 200
    jb dash_loop
skip_draw_lines:
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

;-----------------------------------------------------
; Fetch a row from screen
;-----------------------------------------------------
fetch_row:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    mov bx, [bp+4]
    mov di, bx
    shl di, 8
    mov ax, bx
    shl ax, 6
    add di, ax
    
    mov si, di
    mov ax, 0xA000
    mov ds, ax
    mov ax, cs
    mov es, ax
    mov di, buffer
    mov cx, 320
    cld
    rep movsb
    
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

;-----------------------------------------------------
; Save background under car
;-----------------------------------------------------
save_car_background:
    pusha
    push ds
    push es
    
    mov ax, 0xA000
    mov ds, ax
    mov ax, cs
    mov es, ax
    
    mov di, car_buffer
    mov bx, CAR_Y_POS
    mov cx, CAR_HEIGHT
    
.save_row:
    cmp bx, 200
    jae .skip_row
    
    mov si, bx
    shl si, 8
    mov ax, bx
    shl ax, 6
    add si, ax
    
    mov ax, [cs:car_x_pos]
    cmp ax, 320
    jae .skip_row
    add si, ax
    
    push di
    push cx
    mov cx, CAR_WIDTH
    
    mov ax, [cs:car_x_pos]
    add ax, CAR_WIDTH
    cmp ax, 320
    jbe .save_ok
    mov cx, 320
    sub cx, [cs:car_x_pos]
.save_ok:
    cld
    rep movsb
    pop cx
    pop di
    add di, CAR_WIDTH 
.skip_row:
    inc bx
    loop .save_row
    
    pop es
    pop ds
    popa
    ret

;-----------------------------------------------------
; Spawn enemy at correct position
;-----------------------------------------------------
spawn_enemy:
    call get_random_lane_index

    cmp ax, 0
    je .spawn_left
    cmp ax, 1
    je .spawn_center
    mov ax, LANE_RIGHT
    jmp .set_position

.spawn_left:
    mov ax, LANE_LEFT
    jmp .set_position

.spawn_center:
    mov ax, LANE_CENTER

.set_position:
    mov [enemy_x_pos], ax
    mov word [enemy_y_pos], -36
    mov byte [enemy_active], 1
    mov word [spawn_timer], SPAWN_DELAY
    ret

;-----------------------------------------------------
; NEW: Spawn star at random lane
;-----------------------------------------------------
spawn_star:
    call get_random_lane_index

    cmp ax, 0
    je .spawn_left
    cmp ax, 1
    je .spawn_center
    mov ax, LANE_RIGHT
    jmp .set_position

.spawn_left:
    mov ax, LANE_LEFT
    jmp .set_position

.spawn_center:
    mov ax, LANE_CENTER

.set_position:
    mov [star_x_pos], ax
    mov word [star_y_pos], -20
    mov byte [star_active], 1
    mov word [star_spawn_counter], STAR_SPAWN_DELAY
    ret

;-----------------------------------------------------
; Draw enemy car
;-----------------------------------------------------
draw_enemy_car:
    cmp byte [enemy_active], 0
    je .done

    pusha
    mov si, coordinates_enemy_car
    mov cx, [Len_of_enemy_car]

.draw_loop:
    mov ax, [si+4]
    add ax, [enemy_y_pos]
    
    cmp ax, 200
    jge .skip_part
    
    mov bx, [si+8]
    add bx, [enemy_y_pos]
    
    cmp bx, 0
    jle .skip_part
    
    cmp ax, 0
    jge .y_start_ok
    xor ax, ax
.y_start_ok:
    
    cmp bx, 200
    jle .y_end_ok
    mov bx, 200
.y_end_ok:
    
    cmp ax, bx
    jge .skip_part
    
    push word [si]
    
    mov dx, [si+2]
    sub dx, LANE_CENTER
    add dx, [enemy_x_pos]
    
    cmp dx, 0
    jl .skip_part_with_color
    cmp dx, 320
    jge .skip_part_with_color
    
    push dx
    push ax
    push word [si+6]
    push bx
    
    call Drawing_loop
    jmp .continue
    
.skip_part_with_color:
    add sp, 2
    jmp .continue
    
.skip_part:

.continue:
    add si, 10
    loop .draw_loop

.done:
    popa
    ret

;-----------------------------------------------------
; NEW: Draw star bonus (pixel-perfect 5-pointed star)
;-----------------------------------------------------
draw_star:
    cmp byte [star_active], 0
    je .done

    pusha
    mov si, coordinates_star
    mov cx, [Len_of_star]

.draw_loop:
    mov ax, [si+4]
    add ax, [star_y_pos]
    
    cmp ax, 200
    jge .skip_part
    
    mov bx, [si+8]
    add bx, [star_y_pos]
    
    cmp bx, 0
    jle .skip_part
    
    cmp ax, 0
    jge .y_start_ok
    xor ax, ax
.y_start_ok:
    
    cmp bx, 200
    jle .y_end_ok
    mov bx, 200
.y_end_ok:
    
    cmp ax, bx
    jge .skip_part
    
    push word [si]
    
    
    mov dx, [si+2]
    sub dx, LANE_CENTER        
    add dx, [star_x_pos]        
    
    cmp dx, 0
    jl .skip_part_with_color
    cmp dx, 320
    jge .skip_part_with_color
    
    push dx
    push ax
    push word [si+6]
    push bx
    
    call Drawing_loop
    jmp .continue
    
.skip_part_with_color:
    add sp, 2
    jmp .continue
    
.skip_part:

.continue:
    add si, 10
    loop .draw_loop

.done:
    popa
    ret

;-----------------------------------------------------
; Restore car background
;-----------------------------------------------------
restore_car_background:
    pusha
    push ds
    push es
    
    mov ax, cs
    mov ds, ax
    mov ax, 0xA000
    mov es, ax
    
    mov si, car_buffer
    mov bx, CAR_Y_POS
    mov cx, CAR_HEIGHT
    
.restore_row:
    cmp bx, 200
    jae .skip_row
    
    mov di, bx
    shl di, 8
    mov ax, bx
    shl ax, 6
    add di, ax
    
    mov ax, [cs:car_x_pos]
    cmp ax, 320
    jae .skip_row
    add di, ax
    
    push si
    push cx
    mov cx, CAR_WIDTH 
    
    mov ax, [cs:car_x_pos]
    add ax, CAR_WIDTH 
    cmp ax, 320
    jbe .restore_ok
    mov cx, 320
    sub cx, [cs:car_x_pos]
	
.restore_ok:
    cld
    rep movsb
    pop cx
    pop si
    add si, CAR_WIDTH 
.skip_row:
    inc bx
    loop .restore_row
    
    pop es
    pop ds
    popa
    ret

;-----------------------------------------------------
; Draw car at position
;-----------------------------------------------------
draw_car_at_position:
    pusha
    
    mov si, coordinates_car
    mov cx, [Len_of_car]
    
.draw_loop:
    push word [si]
    
    mov ax, [si+2]
    sub ax, LANE_CENTER
    add ax, [car_x_pos]
    push ax
    
    push word [si+4]
    push word [si+6]
    push word [si+8]
    
    call Drawing_loop
    
    add si, 10
    loop .draw_loop
    
    popa
    ret

;-----------------------------------------------------
; Erase enemy car by drawing road-colored rectangle
;-----------------------------------------------------
erase_enemy_with_road_color:
    pusha
    
    mov ax, [enemy_x_pos]
    add ax, 1
    cmp ax, 0
    jge .x_ok
    xor ax, ax
.x_ok:
    mov bx, ax
    
    mov cx, 33
    mov ax, bx
    add ax, cx
    cmp ax, 320
    jle .width_ok
    mov cx, 320
    sub cx, bx
.width_ok:
    
    mov dx, [enemy_y_pos]
	dec dx
    cmp dx, 0
    jge .y_ok
    xor dx, dx
.y_ok:
    
    mov si, dx
    add si, 40
    cmp si, 200
    jle .y_end_ok
    mov si, 200
.y_end_ok:
    
    push word 20
    push bx
    push dx
    push cx
    push si
    
    call Drawing_loop
    
    popa
    ret

;-----------------------------------------------------
;  Erase star by drawing road-colored rectangle
;-----------------------------------------------------
erase_star_with_road_color:
    pusha
    
   
    mov ax, [star_x_pos]
    add ax, 9
    cmp ax, 0
    jge .x_ok
    xor ax, ax
.x_ok:
    mov bx, ax
    
    ; Width is 11 pixels
    mov cx, 15
    mov ax, bx
    add ax, cx
    cmp ax, 320
    jle .width_ok
    mov cx, 320
    sub cx, bx
.width_ok:
    
    mov dx, [star_y_pos]
    dec dx
    cmp dx, 0
    jge .y_ok
    xor dx, dx
.y_ok:
    
    ; Height is 17 pixels (15 + buffer)
    mov si, dx
    add si, 17
    cmp si, 200
    jle .y_end_ok
    mov si, 200
.y_end_ok:
    
    push word 20
    push bx
    push dx
    push cx
    push si
    
    call Drawing_loop
    
    popa
    ret

;-----------------------------------------------------
; NEW: Convert number to string
; Input: AX = number, DI = buffer address
;-----------------------------------------------------
num_to_string:
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10
    xor cx, cx
    
.divide_loop:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    test ax, ax
    jnz .divide_loop
    
.pop_loop:
    pop dx
    mov [di], dl
    inc di
    loop .pop_loop
    
    mov byte [di], '$'
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;-----------------------------------------------------
; Main Program
;-----------------------------------------------------
start:
    mov ax, 0013h
    int 10h
    
    call init_random_seed
    mov word [spawn_timer], SPAWN_DELAY
    mov word [star_spawn_counter], STAR_SPAWN_DELAY
    mov word [score], 0
    
    mov ax, 0A000h
    mov es, ax
    
    xor di, di
    mov cx, 64000
    mov al, 6
    rep stosb

    ; Draw Road
    mov si, coordinates_road
    mov cx, [Len_of_road_arr]
draw_road:
    push word [si]
    push word [si+2]
    push word [si+4]
    push word [si+6]
    push word [si+8]
    call Drawing_loop
    add si, 10
    loop draw_road

    ; Draw Left Cacti (Type 2: Short & Stout)
    mov si, coordinates_Cactus_Left
    mov cx, [Len_of_cactus_left]
draw_left_cactus:
    push word [si]
    push word [si+2]
    push word [si+4]
    push word [si+6]
    push word [si+8]
    call Drawing_loop
    add si, 10
    loop draw_left_cactus

    ; Draw Right Cacti (Type 2: Short & Stout)
    mov si, coordinates_Cactus_Right
    mov cx, [Len_of_cactus_right]
draw_right_cactus:
    push word [si]
    push word [si+2]
    push word [si+4]
    push word [si+6]
    push word [si+8]
    call Drawing_loop
    add si, 10
    loop draw_right_cactus

    ; Draw Compact Pebble Clusters
    mov si, coordinates_pebbles
    mov cx, [Len_of_pebbles]
draw_pebbles:
    push word [si]
    push word [si+2]
    push word [si+4]
    push word [si+6]
    push word [si+8]
    call Drawing_loop
    add si, 10
    loop draw_pebbles

    ; Draw Road Lines
    mov si, coordinates_road_lines
    mov cx, [Len_of_road_lines]
draw_road_lines:
    push word [si]
    push word [si+2]
    push word [si+4]
    push word [si+6]
    push word [si+8]
    call Drawing_loop_lines
    add si, 10
    loop draw_road_lines

    mov cx, 5
.initial_delay:
    call wait_vblank
    loop .initial_delay
  
    call save_car_background

    jmp scroll_down_one_row

;-----------------------------------------------------
; Main Game Loop
;-----------------------------------------------------
scroll_down_one_row:
    ; 1. Check input
    call check_keyboard
  
    ; 2. Handle lane changes
    mov ax, [current_lane]
    cmp ax, [car_x_pos]
    je .no_lane_change
    
    call restore_car_background
    mov ax, [current_lane]
    mov [car_x_pos], ax
    call save_car_background
    call draw_car_at_position

.no_lane_change:
  
    ; 3. Handle enemy spawning
    inc word [scroll_counter]
    mov ax, [scroll_counter]
    cmp ax, SPAWN_DELAY
    jl .skip_spawn
    
    mov word [scroll_counter], 0
    
    cmp byte [enemy_active], 0
    jne .skip_spawn
    
    call spawn_enemy

.skip_spawn:

    ; 4. NEW: Handle star spawning
    inc word [star_spawn_counter]
    mov ax, [star_spawn_counter]
    cmp ax, STAR_SPAWN_DELAY
    jl .skip_star_spawn
    
    mov word [star_spawn_counter], 0
    
    cmp byte [star_active], 0
    jne .skip_star_spawn
    
    call spawn_star

.skip_star_spawn:

    ; 5. Update enemy position
    cmp byte [enemy_active], 0
    je .no_enemy_update
    
    add word [enemy_y_pos], 1
    
    mov ax, [enemy_y_pos]
    cmp ax, 164
    jl .no_enemy_update
    
    ; Enemy escaped - add 1 point!
    mov byte [enemy_active], 0
    add word [score], 1

.no_enemy_update:

    ; 6. NEW: Update star position
    cmp byte [star_active], 0
    je .no_star_update
    
    add word [star_y_pos], 1
    
    mov ax, [star_y_pos]
    cmp ax, 170
    jl .no_star_update
    
    ; Star went off screen - erase it first!
    call erase_star_with_road_color
    mov byte [star_active], 0

.no_star_update:

    ; 7. CHECK FOR COLLISION WITH ENEMY
    call check_collision
    cmp al, 1
    je near .game_over
    
    ; 8. NEW: CHECK FOR COLLISION WITH STAR
    call check_star_collision
    cmp al, 1
    jne .no_star_collision
    
    ; Star collected! Add 5 points and deactivate star
    add word [score], 5
    mov byte [star_active], 0
    call erase_star_with_road_color

.no_star_collision:
    
    ; 9. Wait for VBlank
    call wait_vblank
    
    ; 10. Erase enemy if needed
    mov ax, [enemy_y_pos]
    cmp ax, 160
    jl .no_pre_erase
    cmp ax, 200
    jge .no_pre_erase
    
    call erase_enemy_with_road_color
    
.no_pre_erase:

    ; 11. NEW: Erase star if needed
    cmp byte [star_active], 0
    je .no_star_erase
    
    mov ax, [star_y_pos]
    cmp ax, 155
    jl .no_star_erase
    cmp ax, 200
    jge .no_star_erase
    
    call erase_star_with_road_color
    
.no_star_erase:
    
    ; 12. Scroll screen
    mov dx, 199
    push dx
    call fetch_row
    
    mov ax, 0xA000
    mov ds, ax
    mov es, ax
    mov si, 64000 - 320 - 1
    mov di, 64000 - 1
    mov cx, 64000 - 320
    std
    rep movsb
    cld
    
    mov ax, cs
    mov ds, ax
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov si, buffer
    mov cx, 320
    rep movsb
    
    ; 13. Update player car
    call restore_car_background
    call save_car_background
    call draw_car_at_position
    
    ; 14. Draw enemy car
    cmp byte [enemy_active], 0
    je .no_enemy_draw
    
    mov ax, [enemy_y_pos]
    cmp ax, -36
    jl .no_enemy_draw
    cmp ax, 164
    jge .no_enemy_draw
    
    call draw_enemy_car

.no_enemy_draw:

    ; 15. NEW: Draw star
    cmp byte [star_active], 0
    je .no_star_draw
    
    mov ax, [star_y_pos]
    cmp ax, -20
    jl .no_star_draw
    cmp ax, 170
    jge .no_star_draw
    
    call draw_star

.no_star_draw:
    
    jmp scroll_down_one_row

;-----------------------------------------------------
; Game Over Handler
;-----------------------------------------------------
.game_over:
    ; Simple: Just switch to text mode and clear
    mov ax, 0003h
    int 10h
    
    ; Clear screen completely
    mov ax, 0600h     ; Scroll window up
    xor bh, 07h       ; White on black
    xor cx, cx        ; Top-left
    mov dh, 24        ; Bottom row
    mov dl, 79        ; Right column
    int 10h
    
    ; Position cursor for "GAME OVER!" (center-ish)
    mov ah, 02h
    mov bh, 0
    mov dh, 12         ; Row 12
    mov dl, 28         ; Column 28
    int 10h
    
    ; Print GAME OVER! (teletype - NO DOS INT 21h needed)
    mov bl, 0Fh        ; White
    mov si, game_over_msg
.print_gameover:
    mov al, [si]
    cmp al, 0
    je .score_pos
    mov ah, 0Eh
    int 10h
    inc si
    jmp .print_gameover
    
.score_pos:
    ; Position for score
    mov ah, 02h
    mov bh, 0
    mov dh, 14         ; Row 14
    mov dl, 28         ; Column 28
    int 10h
    
    ; Print "SCORE: "
    mov si, score_msg_prefix
.print_score_prefix:
    mov al, [si]
    cmp al, 0
    je .convert_score
    mov ah, 0Eh
    mov bl, 0Fh
    int 10h
    inc si
    jmp .print_score_prefix
    
.convert_score:
    ; Convert score to digits (simple decimal)
    mov ax, [score]
    mov di, score_digits
    mov bx, 10
    
.convert_loop:
    xor dx, dx
    div bx             ; AX = quotient, DX = remainder
    add dl, '0'        ; ASCII digit
    mov [di], dl
    inc di
    test ax, ax
    jnz .convert_loop
    
    ; Null-terminate (backwards)
    mov byte [di], 0
    dec di
    mov si, score_digits  ; SI points to last digit
    
.reverse_digits:
    cmp si, score_digits
    jae .print_digits
    jmp .print_digits   ; Skip reverse for now (simple)
    
.print_digits:
    mov al, [si]
    cmp al, 0
    je .wait_key
    mov ah, 0Eh
    mov bl, 0Eh         ; Yellow for score
    int 10h
    inc si
    jmp .print_digits
    
.wait_key:
    ; Wait for keypress
    mov ah, 00h
    int 16h
    
    ; Exit
    mov ax, 4C00h
    int 21h

;-----------------------------------------------------
; Data Section
;-----------------------------------------------------
game_over_msg:        db 'GAME OVER!$',0      ; $ for DOS + null for teletype
score_msg_prefix:     db 'SCORE: ',0          ; Null-terminated
score_digits:         times 6 db '0',0        ; Space for 65535 max
    
score_buffer: times 10 db 0

buffer: times 320 db 0
car_buffer: times (CAR_WIDTH * CAR_HEIGHT) db 0

coordinates_road:
dw 20,100,0,120,200
dw 14,98,0,2,200
dw 14,220,0,2,200
Len_of_road_arr: dw 3

coordinates_car:
dw 1,151,160,19,162
dw 0,148,164,4,172
dw 0,169,164,4,172
dw 8,152,166,17,168
dw 8,148,180,24,183
dw 0,144,178,5,186
dw 0,172,178,5,186
dw 1,156,162,9,192
dw 1,153,173,15,188
dw 15,157,177,7,185
dw 1,151,192,19,196
Len_of_car: dw 11

coordinates_enemy_car:
dw 4, 151, 0, 19, 2
dw 0, 148, 4, 4, 12
dw 0, 169, 4, 4, 12
dw 8, 152, 6, 17, 8
dw 8, 148, 20, 24, 23
dw 0, 144, 18, 5, 26
dw 0, 172, 18, 5, 26
dw 4, 156, 2, 9, 32
dw 4, 153, 13, 15, 28
dw 15, 157, 17, 7, 25
dw 4, 151, 32, 19, 36
Len_of_enemy_car: dw 11

coordinates_star:
; Top point
dw 14, 157, 0, 2, 1
dw 14, 158, 1, 1, 2
; Upper left arm
dw 14, 155, 2, 2, 3
dw 14, 153, 3, 3, 4
dw 14, 152, 4, 2, 5
; Upper right arm  
dw 14, 160, 2, 2, 3
dw 14, 162, 3, 3, 4
dw 14, 163, 4, 2, 5
; Center body (wider for visibility)
dw 14, 154, 5, 8, 6
dw 14, 155, 6, 6, 7
dw 14, 156, 7, 4, 8
dw 14, 157, 8, 2, 9
; Lower left arm
dw 14, 154, 9, 2, 10
dw 14, 152, 10, 3, 11
dw 14, 153, 11, 2, 12
dw 14, 155, 12, 2, 13
; Lower right arm
dw 14, 161, 9, 2, 10
dw 14, 162, 10, 3, 11
dw 14, 162, 11, 2, 12
dw 14, 160, 12, 2, 13
; Bottom points
dw 14, 157, 13, 2, 14
dw 14, 158, 14, 1, 15
Len_of_star: dw 22

coordinates_road_lines:
dw 15,141,5,2,200
dw 15,179,5,2,200
Len_of_road_lines: dw 2

;-----------------------------------------------------
; LEFT SIDE CACTI - Type 2: Short & Stout Saguaro
;-----------------------------------------------------
coordinates_Cactus_Left:
; Cactus 1 - Position 1
; Main trunk (7 pixels wide, 18 pixels tall)
dw 2,20,148,7,166
; Left arm going down
dw 2,14,155,5,166
; Right arm going up  
dw 10,26,152,5,162
; Highlights
dw 10,22,150,2,164

; Cactus 2 - Position 2
dw 2,40,88,7,106
dw 2,34,95,5,106
dw 10,46,92,5,102
dw 10,42,90,2,104

; Cactus 3 - Position 3
dw 2,60,28,7,46
dw 2,54,35,5,46
dw 10,66,32,5,42
dw 10,62,30,2,44

; Cactus 4 - Position 4
dw 2,10,58,7,76
dw 2,4,65,5,76
dw 10,16,62,5,72
dw 10,12,60,2,74

; Cactus 5 - Position 5
dw 2,80,118,7,136
dw 2,74,125,5,136
dw 10,86,122,5,132
dw 10,82,120,2,134

; Cactus 6 - Position 6
dw 2,55,180,7,198
dw 2,49,187,5,198
dw 10,61,184,5,194
dw 10,57,182,2,196

Len_of_cactus_left: dw 24

;-----------------------------------------------------
; RIGHT SIDE CACTI - Type 2: Short & Stout Saguaro
;-----------------------------------------------------
coordinates_Cactus_Right:
; Cactus 1 - Position 1
dw 2,234,158,7,176
dw 2,228,165,5,176
dw 10,240,162,5,172
dw 10,236,160,2,174

; Cactus 2 - Position 2
dw 2,246,88,7,106
dw 2,240,95,5,106
dw 10,252,92,5,102
dw 10,248,90,2,104

; Cactus 3 - Position 3
dw 2,257,35,7,53
dw 2,251,42,5,53
dw 10,263,39,5,49
dw 10,259,37,2,51

; Cactus 4 - Position 4
dw 2,289,58,7,76
dw 2,283,65,5,76
dw 10,295,62,5,72
dw 10,291,60,2,74

; Cactus 5 - Position 5
dw 2,304,118,7,136
dw 2,298,125,5,136
dw 10,310,122,5,132
dw 10,306,120,2,134

; Cactus 6 - Position 6
dw 2,275,180,7,198
dw 2,269,187,5,198
dw 10,281,184,5,194
dw 10,277,182,2,196

Len_of_cactus_right: dw 24

;-----------------------------------------------------
; Compact Pebble Clusters (scattered on shoulders)
;-----------------------------------------------------
coordinates_pebbles:
    ; Color 8 = dark gray, 7 = medium, 6 = light
    dw 8, 25, 15, 4, 18
    dw 7, 26, 16, 2, 17
    dw 8, 85, 35, 4, 38
    dw 7, 86, 36, 2, 37
    dw 8, 15, 55, 4, 58
    dw 7, 16, 56, 2, 57
    dw 8, 65, 75, 4, 78
    dw 7, 66, 76, 2, 77
    dw 8, 35, 95, 4, 98
    dw 7, 36, 96, 2, 97
    dw 8, 75, 115, 4, 118
    dw 7, 76, 116, 2, 117
    dw 8, 20, 135, 4, 138
    dw 7, 21, 136, 2, 137
    dw 8, 80, 155, 4, 158
    dw 7, 81, 156, 2, 157
    dw 8, 40, 175, 4, 178
    dw 7, 41, 176, 2, 177

    ; Right side pebbles
    dw 8, 275, 20, 4, 23
    dw 7, 276, 21, 2, 22
    dw 8, 235, 40, 4, 43
    dw 7, 236, 41, 2, 42
    dw 8, 295, 60, 4, 63
    dw 7, 296, 61, 2, 62
    dw 8, 245, 80, 4, 83
    dw 7, 246, 81, 2, 82
    dw 8, 285, 100, 4, 103
    dw 7, 286, 101, 2, 102
    dw 8, 230, 120, 4, 123
    dw 7, 231, 121, 2, 122
    dw 8, 270, 140, 4, 143
    dw 7, 271, 141, 2, 142
    dw 8, 250, 160, 4, 163
    dw 7, 251, 161, 2, 162
    dw 8, 290, 180, 4, 183
    dw 7, 291, 181, 2, 182

Len_of_pebbles: dw 38   ; 19 clusters × 2 rectangles each
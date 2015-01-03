.set    BOARD_WIDTH, 79
.set    BOARD_HEIGHT, 23
.set    CH_APPLE, 42
.set    CH_SNAKE_HEAD, 79
.set    CH_SNAKE_BODY, 35
.set    CH_BLANK, 32

.bss
snake_pos:  .space 3840 # 80x24 board, 2 bytes per x/y pair...
apple_pos:  .space 3840 # I guess we could theoretically fill the board with apples as well...
screen:     .space 8

.data
dir:        .byte 3 # 0 = top, clockwise 
snake_len:  .word 3
nr_apples:  .word 5
print_fmt:  .string "%c"

.text
.globl  start_game
.type   start_game, @function

start_game:
    # setup new local stack frame
    pushq   %rbp
    movq    %rsp, %rbp

    # save parameters
    movw    %di, snake_len
    movw    %si, nr_apples

    # seed the prng
    movq    $0, %rdi
    call    time
    movq    %rax, %rdi
    call    srand

    # initialise ncurses screen
    call    ncurses_init

    # initiate apples
    movzwq  nr_apples, %rbx
1:  call    create_apple
    # save coordinates
    leaq    apple_pos(%rip), %r12
    movb    %al, 1(%r12, %rbx, 2)
    shrw    $8, %ax
    movb    %al, (%r12, %rbx, 2)
    # loop
    cmpq    $0, %rbx
    decq    %rbx
    jg      1b

    # initiate snake
    # get pointer to snake coordinates
    leaq    snake_pos(%rip), %r12
    # snake head
    movb    $40, (%r12)
    movb    $12, 1(%r12)
    # snake body
    # initialise counter
    movq    $0, %rbx
1: # increment counter
    incq    %rbx
    # get pointer to this snake part
    leaq    (%r12, %rbx, 2), %r13
    # x
    movzbq  -2(%r13), %r14
    incq    %r14
    movb    %r14b, (%r13)
    # y
    movzbq  -1(%r13), %r14
    movb    %r14b, 1(%r13)
    # loop snake body
    cmpw    snake_len, %bx
    jl      1b

main_loop:
    # get keyboard input and potentially change dir
    call    keyboard_input

    # update snake coordinates
    call    move_snake

    # quit if we're outside playing area
    leaq    snake_pos(%rip), %r12
    cmpb    $0, (%r12)
    jl      quit
    cmpb    $0, 1(%r12)
    jl      quit
    cmpb    $BOARD_WIDTH, (%r12)
    jg      quit
    cmpb    $BOARD_HEIGHT, 1(%r12)
    jg      quit

    # print snake
    call    print_snake

    # check if an apple was eaten
    leaq    snake_pos(%rip), %r12
    leaq    apple_pos(%rip), %r13
    movzbq  (%r12), %r14 # snake x
    movzbq  1(%r12), %r15 # snake y
    movzwq  nr_apples, %rbx
1:  # iterate over apples
    cmpb    %r14b, (%r13, %rbx, 2)
    jne     2f
    cmpb    %r15b, 1(%r13, %rbx, 2)
    jne     2f
    # an apple was eaten
    # increase snake length
    incw    snake_len
    # create new apple
    call    create_apple
    movb    %al, 1(%r13, %rbx, 2)
    shrw    $8, %ax
    movb    %al, (%r13, %rbx, 2)
2:  # loop
    cmpq    $0, %rbx
    decq    %rbx
    jg      1b 

    # check if we hit ourselves
    leaq    snake_pos(%rip), %r12
    movzbq  (%r12), %r14 # snake head x
    movzbq  1(%r12), %r15 # snake head y
    movzwq  snake_len, %rbx
1:  # get pointer to this snake part
    leaq    (%r12, %rbx, 2), %r13
    cmpb    %r14b, (%r13, %rbx, 2)
    jne     2f
    cmpb    %r15b, 1(%r13, %rbx, 2)
    jne     2f
    jmp     quit
2:  # loop
    cmpq    $0, %rbx
    decq    %rbx
    jg      1b

    # print apples
    call    print_apples

    # sleep
    movq    $100000, %rdi
    call    usleep

    # loop main loop
    jmp     main_loop

quit:
    # terminate ncurses screen
    call    endwin

    # restore base pointer
    movq    %rbp, %rsp
    popq    %rbp

    ret

ncurses_init:
    # initialise screen and save WINDOW pointer
    call    initscr
    movq    %rax, screen

    # make cursor invisible
    movq    $0, %rdi
    call    curs_set

    # disable printing of inputted characters
    call    noecho

    # enable keypad
    movq    screen, %rdi
    movq    $1, %rsi
    call    keypad

    # make getch nonblocking
    movq    screen, %rdi
    movq    $1, %rsi
    call    nodelay

    ret

put_char:
    # put character at coordinates
    movq    %rdi, %r15
    movq    %rsi, %rdi
    movq    %r15, %rsi
    movq    %rdx, %rcx
    movq    $print_fmt, %rdx
    call    mvprintw

    # refresh screen
    movq    screen, %rdi
    call    wrefresh

    ret

keyboard_input:
    call    getch
    # get pointer to dir
    movq    $dir, %r12
    movzbq  dir, %r13
    # 'switch' on keyboard input
    cmpq    $258, %rax
    je      0f
    cmpq    $259, %rax
    je      1f
    cmpq    $260, %rax
    je      2f
    cmpq    $261, %rax
    je      3f
    jmp 5f
0:  # pressed down
    # check so we're not going up
    cmpb    $0, dir
    je      5f
    movq    $2, %r13
    jmp     4f
1:  # pressed up
    # check so we're not going down
    cmpb    $2, dir
    je      5f
    movq    $0, %r13
    jmp     4f
2:  # pressed left
    # check so we're not going right
    cmpb    $1, dir
    je      5f
    movq    $3, %r13
    jmp     4f
3:  # pressed right
    # check so we're not going left
    cmpb    $3, dir
    je      5f
    movq    $1, %r13
4:  # write new dir to memory
    movb    %r13b, (%r12)
5:  # dir didn't change
    ret

create_apple:
    # might be nice to collision detect against snake and other apples, but...
    # generate x value
    call    rand
    mov     $0, %edx
    mov     $BOARD_WIDTH, %ecx
    idiv    %ecx
    mov     %rdx, %r14

    # generate y value
    call    rand
    mov     $0, %edx
    mov     $BOARD_HEIGHT, %ecx
    idiv    %ecx
    mov     %rdx, %r15

    # return coordinates in a byte each in %rax, using a shift because apparently x64 can't use %ah
    xorq    %rax, %rax
    movb    %r14b, %al
    shlw    $8, %ax
    movb    %r15b, %al

    ret

move_snake:
    # get pointer to snake coordinates
    leaq    snake_pos(%rip), %r12
    # get how long the snake is
    movzwq  snake_len, %rbx

    # print a blank at the position of the last snake part
    movzbq  (%r12, %rbx, 2), %rdi # x
    movzbq  1(%r12, %rbx, 2), %rsi # y
    # put the snake head character in the third arg reg
    movq    $CH_BLANK, %rdx
    # call the helper function to print the char to screen
    call    put_char

    # snake body
1:  # get pointer to this snake part
    leaq    (%r12, %rbx, 2), %r13
    # get x from snake part closer to head and put here
    movzbq  -2(%r13), %r14
    movb    %r14b, (%r13)
    # get y from snake part closer to head and put here
    movzbq  -1(%r13), %r14
    movb    %r14b, 1(%r13)
    # loop snake body
    cmpq    $0, %rbx
    decq    %rbx
    jg      1b

    # snake head
    # get current coords
    movzbq  (%r12), %r13
    movzbq  1(%r12), %r14
    cmpb    $0, dir
    je      0f
    cmpb    $1, dir
    je      1f
    cmpb    $2, dir
    je      2f
    cmpb    $3, dir
    je      3f
0:  # going up
    decb    %r14b
    jmp     4f
1:  # going right
    incb    %r13b
    jmp     4f
2:  # going down
    incb    %r14b
    jmp     4f
3:  # going left
    decb    %r13b
4:  # exit direction stuff and commit new head coords
    movb    %r13b, (%r12)
    movb    %r14b, 1(%r12)

    ret

print_apples:
    # get how many apples we have
    movzwq  nr_apples, %rbx
    # get a pointer to the apple array
    leaq    apple_pos(%rip), %r12

1:  # put the coords for this apple iteration in the arg regs
    movzbq  (%r12, %rbx, 2), %rdi # x
    movzbq  1(%r12, %rbx, 2), %rsi # y
    # put the character indicating an apple in the third arg reg
    movq    $CH_APPLE, %rdx
    # call the helper function to print the char to screen
    call    put_char
    # loop
    cmpq    $0, %rbx
    decq    %rbx
    jg      1b 

    ret

print_snake:
    # get a pointer to the snake array
    leaq    snake_pos(%rip), %r12

    # print snake head
    # put the coords for the head in the arg regs
    movzbq  (%r12), %rdi # x
    movzbq  1(%r12), %rsi # y
    # put the snake head character in the third arg reg
    movq    $CH_SNAKE_HEAD, %rdx
    # call the helper function to print the char to screen
    call    put_char

    # print snake body
    # get how long the snake is
    movzwq  snake_len, %rbx
1:  # put the coords for the piece in the arg regs
    movzbq  (%r12, %rbx, 2), %rdi # x
    movzbq  1(%r12, %rbx, 2), %rsi # y
    # put the snake body character in the third arg reg
    movq    $CH_SNAKE_BODY, %rdx
    # call the helper function to print the char to screen
    call    put_char
    # loop snake body
    cmpq    $0, %rbx
    decq    %rbx
    jg      1b

    ret

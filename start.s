.text
.globl  _start
.type   _start, @function
_start:
    movq    $3, %rdi
    movq    $5, %rsi
    call    start_game

    movq    $0, %rdi
    call    exit

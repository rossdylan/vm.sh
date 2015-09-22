loadi r0 10
loadi r1 5
call :add2
halt

label add2
add r3 r1 r0
ret

.intel_syntax noprefix 
.global _start

.section .bss

# BUFFERS TO READ/WRITE FROM/TO THE SOCKET
READ_BUFFER:
    .skip 1024
READ_BUFFER_SIZE = . - READ_BUFFER

PATH_BUFFER:
    .skip 1024

WRITE_BUFFER:
    .skip 1024

HTTP_REQUEST_METHOD:
    .skip 8

.section .data

# HTTP CODES
HTTP_OK:
    .ascii "HTTP/1.0 200 OK\r\n\r\n"
HTTP_OK_LEN = . - HTTP_OK

# STRUCT SOCKADDR_IN - Defines family (2 bytes), port (2 bytes), address (4 bytes) and padding (8 bytes)
SOCKADDR_IN:
    .word 2
    .word 0x5000
    .int 0
    .quad 0
SOCKADDR_IN_SIZE = . - SOCKADDR_IN

.section .text

_start:
    # socket(AF_INET, SOCK_STREAM, IPPROTO_IP)
    mov rdi, 2
    mov rsi, 1
    mov rdx, 0
    mov rax, 41
    syscall
    
    # Save the FD in r8
    mov r8, rax

    # bind(3, {sa_family=AF_INET, sin_port=htons(80), sin_addr=inet_addr("0.0.0.0")}, 16)
    mov rdi, r8
    lea rsi, [SOCKADDR_IN]
    mov rdx, SOCKADDR_IN_SIZE
    mov rax, 49
    syscall

    # listen(3, 0)
    mov rdi, r8
    mov rsi, 0
    mov rax, 50
    syscall

    iteration:

        # accept(3, NULL, NULL)
        mov rdi, r8
        mov rsi, 0
        mov rdx, 0
        mov rax, 43
        syscall

        # Save the new FD in r9
        mov r9, rax

        # Fork
        mov rax, 57
        syscall

        # Fork returns 0 when the proccess is a child
        mov r15, rax
        cmp r15, 0
        jne close_sock

        # Close the accepting socket, no need anymore
        mov rdi, r8
        mov rax, 3
        syscall


        # read(4, buf, bufSize)
        mov rdi, r9
        lea rsi, [READ_BUFFER]
        mov rdx, READ_BUFFER_SIZE
        mov rax, 0
        syscall
        mov rcx, rax

        # We need to find out if the request is GET or POST
        xor rax, rax
        xor r8, r8
        lea r10, [HTTP_REQUEST_METHOD]

        func_loop:
            mov al, byte ptr[READ_BUFFER + r8]
            cmp al, 0x20
            je end_func_loop
            mov [r10], al
            inc r8
            inc r10
            jmp func_loop
        
        end_func_loop:
            xor rax, rax
            mov eax, [HTTP_REQUEST_METHOD]
            # Ascii for POST
            cmp eax, 0x54534F50
            je handle_as_post
            jmp handle_as_get

        handle_as_post:
            xor rax, rax
            xor r8, r8
            xor r10, r10
            xor r11, r11
            xor r12, r12
            xor r14, r14

            # POST0x20/path/tofile0X20
            xor rax, rax
            mov r10, 5
            lea r11, [PATH_BUFFER]

            fetch_post_path_loop:
                mov al, byte ptr [READ_BUFFER + r10]
                cmp al, 0x20
                je end_fetch_post_path_loop
                mov [r11], al
                inc r10
                inc r11
                jmp fetch_post_path_loop

            end_fetch_post_path_loop:

            # Fetch the HTTP Request message
            # We will parse the READ_BUFFER from the end until it find a \r\n\r\n
            xor rax, rax
            mov r10, rcx
            dec r10

            fetch_post_message_body_loop:
                mov eax, dword ptr [READ_BUFFER + r10 - 3]
                cmp eax, 0x0A0D0A0D
                je end_fetch_post_message_body_loop
                dec r10
                jmp fetch_post_message_body_loop

            end_fetch_post_message_body_loop:


            # And then parse the message from where we found the \r\n\r\n into the [WRITE_BUFFER]
            lea r11, [WRITE_BUFFER]
            xor r13, r13

            fetch_post_message_loop:
                mov al, byte ptr [READ_BUFFER + r10 + 1]
                cmp al, 0
                je end_fetch_post_message_loop
                mov [r11], al
                inc r10
                inc r11
                inc r13
                jmp fetch_post_message_loop

            end_fetch_post_message_loop:

            # Open the request filed: open("/path")
            lea rdi, [PATH_BUFFER]
            mov rsi, 65
            mov rdx, 511
            mov rax, 2
            syscall

            # Save the file descriptor
            mov rbx, rax
            
            # Write the requested message to the request file
            mov rdi, rbx
            lea rsi, [WRITE_BUFFER]
            mov rdx, r13
            mov rax, 1
            syscall

            # Close the file descriptor: close(5)
            mov rdi, rbx
            mov rax, 3
            syscall
            xor rbx, rbx

            # write(4, HTTP_OK, HTTP_OK_LEN)
            mov rdi, r9
            lea rsi, [HTTP_OK]
            mov rdx, HTTP_OK_LEN
            mov rax, 1
            syscall

            jmp close_sock

        handle_as_get:
            # GET0x20/path/tofile0X20
            xor rax, rax
            mov r10, 4
            lea r11, [PATH_BUFFER]

            get_loop:
                mov al, byte ptr [READ_BUFFER + r10]
                cmp al, 0x20
                je end_get_loop
                mov [r11], al
                inc r10
                inc r11
                jmp get_loop

            end_get_loop:
                

            # Open the request filed: open("/path")
            lea rdi, [PATH_BUFFER]
            mov rsi, 0
            mov rax, 2
            syscall

            # Save FD and Read the requested file: read(5)
            mov r12, rax
            mov rdi, r12
            lea rsi, [READ_BUFFER]
            mov rdx, READ_BUFFER_SIZE
            mov rax, 0
            syscall
            # Save the size
            mov r14, rax

            # Close the file socket: close(5)
            mov rdi, r12
            mov rax, 3
            syscall

            # write(4, HTTP_OK, HTTP_OK_LEN)
            mov rdi, r9
            lea rsi, [HTTP_OK]
            mov rdx, HTTP_OK_LEN
            mov rax, 1
            syscall

            # Write the requested file contents back: write()
            mov rdi, r9
            lea rsi, [READ_BUFFER]
            mov rdx, r14
            mov rax, 1
            syscall

        close_sock:
            # close(4)
            mov rdi, r9
            mov rax, 3
            syscall
    
        cmp r15, 0
        jne iteration

    call exit
    
exit:
    mov rdi, 0
    mov rax, 60
    syscall

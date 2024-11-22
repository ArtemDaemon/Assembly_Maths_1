.386
.model flat, stdcall
.stack 4096

; Include required libraries
includelib kernel32.lib

; Declare external Windows API functions
GetStdHandle proto stdcall :dword
WriteConsoleA proto stdcall :dword, :ptr, :dword, :ptr, :dword
ReadConsoleA proto stdcall :dword, :ptr, :dword, :ptr, :dword
ExitProcess proto stdcall :dword

.const
STD_OUTPUT_HANDLE equ -11
STD_INPUT_HANDLE equ -10

.data
promptX db 'Enter a value for X: ', 0           ; Prompt for X
promptY db 'Enter a value for Y: ', 0           ; Prompt for Y
inputBufferX db 16 dup(0)                       ; Buffer for input X
inputBufferY db 16 dup(0)                       ; Buffer for input Y
bytesReadX dd 0                                 ; Bytes read for X
bytesReadY dd 0                                 ; Bytes read for Y
inputLength dd 16                               ; Length of input buffer
outputMessage db 'You entered X: ', 0           ; Output message for X
outputMessageY db 'You entered Y: ', 0          ; Output message for Y
newline db 13, 10, 0                            ; Newline characters

.code
main PROC
    ; === Get standard output handle ===
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    mov ebx, eax                      ; Save handle in EBX (standard output)
    test ebx, ebx                     ; Check if handle is valid
    jz error                          ; If handle is 0, jump to error

    ; === Get standard input handle ===
    push STD_INPUT_HANDLE
    call GetStdHandle
    mov esi, eax                      ; Save handle in ESI (standard input)
    test esi, esi                     ; Check if handle is valid
    jz error                          ; If handle is 0, jump to error

    ; === Prompt for X ===
    push 0
    push OFFSET bytesReadX            ; Variable to store bytes written
    push LENGTHOF promptX             ; Length of the prompt
    lea edx, promptX                  ; Address of the prompt
    push edx                          ; Pointer to the prompt
    push ebx                          ; Handle to standard output
    call WriteConsoleA
    test eax, eax                     ; Check if WriteConsoleA succeeded
    jz error                          ; If eax is 0, jump to error

    ; === Read input X ===
    push 0
    push OFFSET bytesReadX            ; Variable to store bytes read
    push inputLength                  ; Length of the input buffer
    lea edx, inputBufferX             ; Address of the input buffer
    push edx                          ; Pointer to the input buffer
    push esi                          ; Handle to standard input (preserved in ESI)
    call ReadConsoleA
    test eax, eax                     ; Check if ReadConsoleA succeeded
    jz error                          ; If eax is 0, jump to error

    ; === Display input X ===
    push 0
    push OFFSET bytesReadX
    push LENGTHOF outputMessage
    lea edx, outputMessage
    push edx
    push ebx
    call WriteConsoleA

    push 0
    push OFFSET bytesReadX
    push bytesReadX
    lea edx, inputBufferX
    push edx
    push ebx
    call WriteConsoleA

    push 0
    push OFFSET bytesReadX
    push LENGTHOF newline
    lea edx, newline
    push edx
    push ebx
    call WriteConsoleA

    ; === Prompt for Y ===
    push 0
    push OFFSET bytesReadY            ; Variable to store bytes written
    push LENGTHOF promptY             ; Length of the prompt
    lea edx, promptY                  ; Address of the prompt
    push edx                          ; Pointer to the prompt
    push ebx                          ; Handle to standard output
    call WriteConsoleA
    test eax, eax                     ; Check if WriteConsoleA succeeded
    jz error                          ; If eax is 0, jump to error

    ; === Read input Y ===
    push 0
    push OFFSET bytesReadY            ; Variable to store bytes read
    push inputLength                  ; Length of the input buffer
    lea edx, inputBufferY             ; Address of the input buffer
    push edx                          ; Pointer to the input buffer
    push esi                          ; Handle to standard input (preserved in ESI)
    call ReadConsoleA
    test eax, eax                     ; Check if ReadConsoleA succeeded
    jz error                          ; If eax is 0, jump to error

    ; === Display input Y ===
    push 0
    push OFFSET bytesReadY
    push LENGTHOF outputMessageY
    lea edx, outputMessageY
    push edx
    push ebx
    call WriteConsoleA

    push 0
    push OFFSET bytesReadY
    push bytesReadY
    lea edx, inputBufferY
    push edx
    push ebx
    call WriteConsoleA

    push 0
    push OFFSET bytesReadY
    push LENGTHOF newline
    lea edx, newline
    push edx
    push ebx
    call WriteConsoleA

    ; === Exit process successfully ===
    push 0
    call ExitProcess

error:
    ; Print error message
    lea edx, promptX                  ; Reuse promptX for simplicity
    push 0
    push OFFSET bytesReadX
    push LENGTHOF promptX
    push edx
    push ebx
    call WriteConsoleA

    push 1                            ; Exit with error code
    call ExitProcess
main ENDP

END main

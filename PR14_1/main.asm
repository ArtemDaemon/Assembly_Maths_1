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
promptY db 'Enter a value for Y (non-zero): ', 0; Prompt for Y
inputBufferX db 16 dup(0)                       ; Buffer for input X
inputBufferY db 16 dup(0)                       ; Buffer for input Y
bytesReadX dd 0                                 ; Bytes read for X
bytesReadY dd 0                                 ; Bytes read for Y
inputLength dd 16                               ; Length of input buffer
outputMessage db 'You entered X: ', 0           ; Output message for X
outputMessageY db 'You entered Y: ', 0          ; Output message for Y
errorMessage db 'Error: Non-numeric input or Y is zero.', 0
newline db 13, 10, 0                            ; Newline characters

.code
main PROC
    ; === Get standard output handle ===
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    mov edi, eax                      ; Save handle in EDI (standard output)
    test edi, edi                     ; Check if handle is valid
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
    push edi                          ; Handle to standard output
    call WriteConsoleA

    ; === Read input X ===
    push 0
    push OFFSET bytesReadX
    push inputLength
    lea edx, inputBufferX
    push edx
    push esi
    call ReadConsoleA

    ; === Validate X ===
    lea edx, inputBufferX             ; Load address of inputBufferX
    mov ecx, bytesReadX               ; Load number of bytes read for X
    dec ecx                           ; Exclude the newline character
    call validateInput                ; Call validation subroutine
    test eax, eax                     ; Check result (0 = invalid, 1 = valid)
    jz error                          ; If invalid, jump to error

    ; === Prompt for Y ===
    push 0
    push OFFSET bytesReadY
    push LENGTHOF promptY
    lea edx, promptY
    push edx
    push edi
    call WriteConsoleA

    ; === Read input Y ===
    push 0
    push OFFSET bytesReadY
    push inputLength
    lea edx, inputBufferY
    push edx
    push esi
    call ReadConsoleA

    ; === Validate Y ===
    lea edx, inputBufferY             ; Load address of inputBufferY
    mov ecx, bytesReadY               ; Load number of bytes read for Y
    dec ecx                           ; Exclude the newline character
    call validateInput
    test eax, eax                     ; Check result
    jz error

    ; === Check if Y is Non-Zero ===
    lea edx, inputBufferY             ; Load address of inputBufferY
    call stringToInt                  ; Convert inputBufferY to an integer
    test eax, eax                     ; Check if the value is zero
    jz error                          ; If zero, jump to error

    ; === Exit process successfully ===
    push 0
    call ExitProcess

error:
    ; Print error message
    push 0
    push LENGTHOF errorMessage
    lea edx, errorMessage
    push edx
    push edi                          ; Use EDI (output handle)
    call WriteConsoleA

    push 1                            ; Exit with error code
    call ExitProcess
main ENDP

; === Subroutine: Validate Input ===
; Checks if a string contains only numeric characters.
; Input:
;   EDX - Address of the string
;   ECX - Length of the string (excluding newline)
; Output:
;   EAX - 1 if valid, 0 if invalid
validateInput PROC
    dec ecx                           ; Reduce count to exclude '\r'
    cmp byte ptr [edx + ecx], 13      ; Check if last character is '\r'
    je trimCarriageReturn
continueValidation:
    mov eax, 1                        ; Assume valid input
validateLoop:
    mov al, byte ptr [edx]            ; Load the current character
    cmp al, '0'                       ; Check if >= '0'
    jl invalid                        ; If less, invalid
    cmp al, '9'                       ; Check if <= '9'
    jg invalid                        ; If greater, invalid
    inc edx                           ; Move to the next character
    loop validateLoop                 ; Repeat for all characters
    mov eax, 1                        ; Valid input
    ret
invalid:
    mov eax, 0                        ; Invalid input
    ret
trimCarriageReturn:
    mov byte ptr [edx + ecx], 0       ; Null-terminate string by replacing '\r'
    jmp continueValidation
validateInput ENDP

; === Subroutine: Convert String to Integer ===
stringToInt PROC
    xor eax, eax                      ; Clear EAX (result)
    xor ebx, ebx                      ; Clear EBX (temporary multiplier)
convertLoop:
    mov bl, byte ptr [edx]            ; Load character
    cmp bl, 0                         ; Check for null terminator
    je doneConversion                 ; If null terminator, finish
    sub bl, '0'                       ; Convert ASCII to integer
    imul eax, eax, 10                 ; Multiply current result by 10
    add eax, ebx                      ; Add the new digit
    inc edx                           ; Move to the next character
    jmp convertLoop
doneConversion:
    ret
stringToInt ENDP

END main

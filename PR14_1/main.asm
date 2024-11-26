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
resultBuffer db 16 dup(0)                       ; Buffer for the result
resultBytes dd 0                                ; Bytes written for result
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
    push OFFSET bytesReadX
    push LENGTHOF promptX
    lea edx, promptX
    push edx
    push edi
    call WriteConsoleA

    ; === Read input X ===
    push 0
    push OFFSET bytesReadX
    push inputLength
    lea edx, inputBufferX
    push edx
    push esi
    call ReadConsoleA

    ; === Validate and Convert X ===
    lea edx, inputBufferX             ; Load address of inputBufferX
    mov ecx, bytesReadX               ; Load number of bytes read for X
    dec ecx                           ; Exclude the newline character
    call validateInput                ; Call validation subroutine
    test eax, eax                     ; Check result (0 = invalid, 1 = valid)
    jz error                          ; If invalid, jump to error
    lea ecx, inputBufferX                ; Load address of inputBufferX into ECX
    call stringToInt                     ; Call stringToInt
    mov ebx, eax                         ; Move result to EBX (X value)

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

    ; === Validate and Convert Y ===
    lea edx, inputBufferY             ; Load address of inputBufferY
    mov ecx, bytesReadY               ; Load number of bytes read for Y
    dec ecx                           ; Exclude the newline character
    call validateInput
    test eax, eax                     ; Check result
    jz error
    lea ecx, inputBufferY                ; Load address of inputBufferY into ECX
    call stringToInt                     ; Call stringToInt
    mov ecx, eax                         ; Move result to ECX (Y value)

    ; === Check if Y is Non-Zero ===
    test ecx, ecx                     ; Check if Y is zero
    jz error                          ; If zero, jump to error

    ; === Compute Formula ===
    ; ebx - value of X
    ; ecx - value of Y
    ; edi - OutputHandle
    ; eax - where to put result

    ; X + Y
    mov edx, ebx
    add edx, ecx

    ; Y * Y
    imul ecx, ecx

    ; (X + Y) / Y^2
    mov eax, edx
    xor edx, edx
    div ecx

    ; === Convert Result to String ===
    lea edx, resultBuffer             ; Load result buffer address
    call intToString                  ; Convert EAX to string in resultBuffer

    ; === Print Result ===
    push 0
    push OFFSET resultBytes
    push LENGTHOF resultBuffer
    lea edx, resultBuffer
    push edx
    push edi
    call WriteConsoleA

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
    xor eax, eax                      ; Clear EAX (result accumulator)
    xor edx, edx                      ; Use EDX as a temporary register
convertLoop:
    mov dl, byte ptr [ecx]            ; Load character from the string into DL
    cmp dl, 0                         ; Check for null terminator
    je doneConversion
    sub dl, '0'                       ; Convert ASCII to numeric value
    imul eax, eax, 10                 ; Multiply accumulated value by 10
    add eax, edx                      ; Add the numeric value to the result
    inc ecx                           ; Move to the next character
    jmp convertLoop
doneConversion:
    ret
stringToInt ENDP

; === Subroutine: Convert Integer to String ===
intToString PROC
    push edi                          ; Save the value of EDI
    xor ecx, ecx                      ; Clear ECX (character count)
    mov edi, edx                      ; Save starting address of result buffer
    test eax, eax                     ; Check if number is negative
    jge positiveNumber                ; If positive, skip to conversion
    mov byte ptr [edi], '-'           ; Add '-' sign to buffer
    inc edi                           ; Move buffer pointer forward
    neg eax                           ; Convert number to positive

positiveNumber:
    xor edx, edx                      ; Clear EDX (important to prevent overflow)
    mov ebx, 10                       ; Divisor for decimal conversion
convertLoop:
    xor edx, edx                      ; Clear remainder before each DIV (important!)
    div ebx                           ; Divide EAX by 10 (EAX = quotient, EDX = remainder)
    add dl, '0'                       ; Convert remainder to ASCII
    push edx                          ; Save ASCII character on the stack
    inc ecx                           ; Increment character count
    test eax, eax                     ; Check if quotient is 0
    jnz convertLoop                   ; Continue if not 0

    ; Pop characters back into buffer in reverse order
writeChars:
    pop edx                           ; Pop the top character
    mov byte ptr [edi], dl            ; Write character to buffer
    inc edi                           ; Move to next buffer position
    loop writeChars                   ; Repeat for all characters

    mov byte ptr [edi], 0             ; Null-terminate the string
    pop edi                           ; Restore the original value of EDI
    ret
intToString ENDP


END main

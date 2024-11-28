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
integer dd 0
fraction dd 0                 ; Результат деления в формате целой части + десятичная часть
debugBuffer db 16 dup(0)              ; Буфер для строки (максимум 16 символов)
bytesWritten dd 0                     ; Для записи длины вывода
xValue dd 0
yValue dd 0

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
    ; EBX - value of X
    ; ECX - value of Y
    ; EDI - OutputHandle
    ; EAX - where to put result

    mov xValue, ecx
    mov yValue, ebx

    ; EDX = X + Y
    mov edx, ebx
    add edx, ecx

    ; ECX = Y^2
    imul ecx, ecx

    ; integer.fraction = (X + Y) / Y^2
    mov eax, edx
    mov ebx, ecx
    call divideWithFraction

    ; integer.fraction = (X + Y) / Y^2 - 1
    mov eax, integer
    mov ebx, fraction
    mov ecx, 1
    mov edx, 0
    call subtractNumbers
    mov integer, eax
    mov fraction, ebx

    ; === Convert Result to String ===
    push edi
    ; mov eax, integer
    mov edx, ebx
    lea edi, resultBuffer             ; Load result buffer address
    call intToString                  ; Convert EAX to string in resultBuffer

    ; === Print Result ===
    pop edi
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

; === Subroutine: Convert Integer to String with Decimal Point ===
intToString PROC
    ; Вход:
    ;   EAX = Целая часть
    ;   EBX = Дробная часть
    ;   ESI = Флаг отрицательного числа (0/1)

    push edi                          ; Сохранить регистры
    push eax
    push ebx
    push ecx
    push edx                          ; Сохранить дробную часть

    xor ecx, ecx                      ; Счётчик символов

    ; === Обработка целой части числа ===
    test esi, esi                  ; Проверить, отрицательное ли число
    jz positiveNumber                ; Если положительное, перейти к обработке
    mov byte ptr [edi], '-'           ; Добавить знак "-"
    inc edi                           ; Сдвинуть указатель буфера

positiveNumber:
    xor edx, edx                      ; Очистить остаток
    mov ebx, 10                       ; Делитель для десятичной системы
convertIntegerLoop:
    div ebx                           ; Деление EAX на 10 (EAX = частное, EDX = остаток)
    add dl, '0'                       ; Преобразовать остаток в ASCII
    push edx                          ; Сохранить ASCII-символ в стеке
    inc ecx                           ; Увеличить счётчик символов
    test eax, eax                     ; Проверить, деление завершено
    jnz convertIntegerLoop            ; Продолжать, если частное не 0

    ; Запись целой части в буфер
writeIntegerChars:
    pop edx                           ; Извлечь символ из стека
    mov byte ptr [edi], dl            ; Записать символ в буфер
    inc edi                           ; Сдвинуть указатель
    loop writeIntegerChars            ; Повторить для всех символов

    ; === Обработка дробной части числа ===
    pop eax                           ; Восстановить дробную часть из стека
    test eax, eax
    jz endFraction

    ; === Добавить десятичную точку ===
    mov byte ptr [edi], '.'           ; Добавить символ "."
    inc edi                           ; Сдвинуть указатель

    xor edx, edx                      ; Очистить старшую часть
    mov ebx, 10                       ; Делитель для десятичной системы
convertFractionLoop:
    xor edx, edx
    div ebx                           ; Деление EAX на 10 (EAX = частное, EDX = остаток)
    add dl, '0'                       ; Преобразовать остаток в ASCII
    push edx                          ; Сохранить ASCII-символ в стеке
    inc ecx                           ; Увеличить счётчик символов
    test eax, eax                     ; Проверить, деление завершено
    jnz convertFractionLoop            ; Продолжать, если частное не 0

; Запись дробной части в буфер
writeFractionChars:
    pop edx                           ; Извлечь символ из стека
    mov byte ptr [edi], dl            ; Записать символ в буфер
    inc edi                           ; Сдвинуть указатель
    loop writeFractionChars            ; Повторить для всех символов

endFraction:
    ; === Завершение строки ===
    mov byte ptr [edi], 0             ; Добавить null-терминатор

    ; === Восстановить регистры ===
    pop ecx
    pop ebx
    pop eax
    pop edi

    ret
intToString ENDP

divideWithFraction PROC
    ; Вход:
    ;   EAX - делимое
    ;   EBX - делитель
    ; Выход:
    ;   Целая часть в [result]
    ;   Десятичная часть в [fraction]

    push eax                    ; Сохранить регистры
    push ebx
    push ecx
    push edx
    push esi

    ; Выполнить целочисленное деление
    xor edx, edx                ; Очистить остаток (EDX)
    div ebx                     ; Деление EAX / EBX (целая часть в EAX, остаток в EDX)

    mov [integer], eax           ; Сохранить целую часть
    mov esi, edx                ; Сохранить остаток

    ; Проверить, есть ли остаток
    test esi, esi               ; Проверить остаток
    jz endDivide                ; Если остатка нет, завершить

    ; Обработка остатка
    mov ecx, 10                 ; Максимальное количество знаков после запятой
    xor eax, eax                ; Очистить EAX
    mov [fraction], eax         ; Инициализировать десятичную часть
fractionLoop:
    mov eax, esi                ; Перенести остаток в EAX
    imul eax, 10                ; Умножить остаток на 10
    xor edx, edx                ; Очистить регистр остатка
    div ebx                     ; Выполнить деление (EAX / EBX)

    ; Добавить текущий разряд в десятичную часть
    mov esi, [fraction]         ; Текущая десятичная часть
    imul esi, 10                ; Увеличить разрядность
    add esi, eax                ; Добавить новый разряд
    mov [fraction], esi         ; Сохранить десятичную часть

    ; Проверить новый остаток
    test edx, edx               ; Если остаток стал нулевым
    jz endFraction              ; Прекратить обработку

    mov esi, edx                ; Новый остаток
    loop fractionLoop           ; Повторить цикл

endFraction:
endDivide:
    pop esi                     ; Восстановить регистры
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
divideWithFraction ENDP

subtractNumbers PROC
    ; Процедура для вычитания одного дробного числа из другого
    ; Вход:
    ;   EAX = целая часть первого числа
    ;   EBX = дробная часть первого числа
    ;   ECX = целая часть второго числа
    ;   EDX = дробная часть второго числа
    ; Выход:
    ;   EAX = результат целой части
    ;   EBX = результат дробной части
    ;   ESI = флаг отрицательного результата (0/1)

    cmp eax, ecx
    ja skipSwap
    jb doSwap

    cmp ebx, edx
    ja skipSwap

doSwap:
    xchg eax, ecx
    xchg ebx, edx
    mov esi, 1
    jmp checkFractionPart

skipSwap:
    xor esi, esi

checkFractionPart:
    cmp ebx, edx
    ja noBorrow

    dec eax

    push eax
    push ecx
    push edx
    push ebx

    mov eax, edx
    call getBorrowAdd
    
    pop ebx
    pop edx
    pop ecx
    add ebx, eax
    pop eax
    
noBorrow:
    sub eax, ecx
    sub ebx, edx
    ret

subtractNumbers ENDP

getBorrowAdd PROC
    ; Процедура для получения числа, которое прибавится к меньшей части при вычитании
    ; Например, если из 0 вычитается 17, то к 0 прибавляется 100 (10 ^ (число символов в 17))
    ; Вход:
    ;   EAX = Число X, символы которого нужно посчитать
    ; Выход:
    ;   EAX = 10 ^ (число символов в X)
    ; Используется:
    ;   ECX = Счетчик
    ;   EDX = Хранение остатка деления
    ;   EBX = Хранение делителя
    xor ecx, ecx
countDigits:
    cmp eax, 0             ; Проверяем, не равно ли X нулю
    je computePower        ; Если равно, переходим к вычислению Y
    inc ecx                ; Увеличиваем счетчик цифр
    cdq                    ; Очищаем EDX
    mov ebx, 10            ; Делитель = 10
    div ebx                ; EAX = EAX / 10 (деление нацело)
    jmp countDigits        ; Повторяем цикл

computePower:
    mov eax, 1             ; Начальное значение для Y = 10^0 = 1
    mov ebx, 10            ; Основание степени = 10

powerLoop:
    cmp ecx, 0             ; Проверяем, сколько еще итераций
    je done         ; Если 0, завершаем
    imul eax, ebx          ; Умножаем результат на 10
    dec ecx                ; Уменьшаем счетчик итераций
    jmp powerLoop          ; Повторяем

done:
    ret
getBorrowAdd ENDP

END main

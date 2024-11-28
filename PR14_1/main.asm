.386
.model flat, stdcall
.stack 4096

; Объявление внешних функций Windows API
GetStdHandle proto stdcall :dword
WriteConsoleA proto stdcall :dword, :ptr, :dword, :ptr, :dword
ReadConsoleA proto stdcall :dword, :ptr, :dword, :ptr, :dword
ExitProcess proto stdcall :dword

.const
STD_OUTPUT_HANDLE equ -11
STD_INPUT_HANDLE equ -10

.data
promptX db 'Enter a value for X: ', 0                       ; Сообщение для ввода X
promptY db 'Enter a value for Y (non-zero): ', 0            ; Сообщение для ввода Y
inputBufferX db 16 dup(0)                                   ; Буфер для значения X
inputBufferY db 16 dup(0)                                   ; Буфер для значения Y
bytesReadX dd 0                                             ; Кол-во прочитанных байт X
bytesReadY dd 0                                             ; Кол-во прочитанных байт Y
inputLength dd 16                                           ; Длина буфера входа
resultBuffer db 16 dup(0)                                   ; Буфер для вывода результата
resultBytes dd 0                                            ; Кол-во байт, записанных в буфер результата
errorMessage db 'Error: Non-numeric input or Y is zero.', 0 ; Сообщение об ошибке
integer dd 0                                                ; Целая часть результата
fraction dd 0                                               ; Дробнаячасть результата
xValue dd 0                                                 ; Хранимое значение X
yValue dd 0                                                 ; Хранимое значение Y
resultMessage db 'The result of the (X+Y)/Y^2 - 1: ', 0       ; Сообщение о результате
bytesResultMessage dd 0                                     ; Кол-во прочитанных байт в сообщении о результате

.code
main PROC
    ; === Получаем OutputHandle ===
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    mov edi, eax                      ; Сохраняем Handle в EDI (стандартный вывод)
    test edi, edi                     ; Проверяем, корректный ли Handle
    jz error                          ; Если Handle = 0, переходим к error

    ; === Получаем InputHandle ===
    push STD_INPUT_HANDLE
    call GetStdHandle
    mov esi, eax                      ; Сохраняем Handle в ESI (стандартный ввод)
    test esi, esi                     ; Проверяем, корректный ли Handle
    jz error                          ; Если Handle = 0, переходим к error

    ; === Вывод сообщения для X ===
    push 0
    push OFFSET bytesReadX
    push LENGTHOF promptX
    lea edx, promptX
    push edx
    push edi
    call WriteConsoleA

    ; === Ввод значения X ===
    push 0
    push OFFSET bytesReadX
    push inputLength
    lea edx, inputBufferX
    push edx
    push esi
    call ReadConsoleA

    ; === Проверяем, что X число ===
    lea edx, inputBufferX           ; Привязываем адрес буфера для значения X
    mov ecx, bytesReadX             ; Передаем число байт, прочитанных в X
    call validateInput              ; Вызываем процедуру проверки значения
    test eax, eax                   ; Проверяем результат (0 = ошибка, 1 = корректно)
    jz error                        ; Если ошибка, переходим к error

    ; === Конвертируем X в число ===
    lea ecx, inputBufferX           ; Привязываем адрес буфера для значения X
    call stringToInt                ; Вызываем процедуру конвертации значения
    mov xValue, eax                 ; Сохраняем значение X

    ; === Вывод сообщения для Y ===
    push 0
    push OFFSET bytesReadY
    push LENGTHOF promptY
    lea edx, promptY
    push edx
    push edi
    call WriteConsoleA

    ; === Ввод значения Y ===
    push 0
    push OFFSET bytesReadY
    push inputLength
    lea edx, inputBufferY
    push edx
    push esi
    call ReadConsoleA

    ; === Проверяем, что X число ===
    lea edx, inputBufferY           ; Привязываем адрес буфера для значения Y
    mov ecx, bytesReadY             ; Передаем число байт, прочитанных в Y
    call validateInput              ; Вызываем процедуру проверки значения
    test eax, eax                   ; Проверяем результат (0 = ошибка, 1 = корректно)
    jz error                        ; Если ошибка, переходим к error

    ; === Конвертируем Y в число ===
    lea ecx, inputBufferY               ; Привязываем адрес буфера для значения Y
    call stringToInt                    ; Вызываем процедуру конвертации значения
    mov yValue, eax                     ; Сохраняем значение Y

    ; === Проверяем, что Y != 0 ===
    test eax, eax                   ; Проверяем, равен ли Y нулю
    jz error                        ; Если Y==0, переходим к error

    ; === Вычисление ===
    ; xValue - значение X
    ; yValue - значение Y
    ; EDI - OutputHandle

    ; EAX = X + Y
    mov eax, xValue
    add eax, yValue

    ; EBX = Y^2
    mov ebx, yValue
    imul ebx, ebx

    ; integer.fraction = (X + Y) / Y^2
    push edi
    call divideIntNumbers
    mov integer, edi
    mov fraction, esi
    pop edi

    ; integer.fraction = (X + Y) / Y^2 - 1
    mov eax, integer
    mov ebx, fraction
    mov ecx, 1
    mov edx, 0
    call subtractFloatNumbers
    mov integer, eax
    mov fraction, ebx

    ; === Конвертация результата в строку ===
    push edi
    mov eax, integer
    mov ebx, fraction
    lea edi, resultBuffer               ; Привязываем буфер для результата
    call floatToString                  ; Вызываем процедуру для конвертации результата в строку
    pop edi

    ; === Вывод выражения ===
    push 0
    push OFFSET bytesResultMessage
    push LENGTHOF resultMessage
    lea edx, resultMessage
    push edx
    push edi
    call WriteConsoleA

    ; === Вывод результата ===
    push 0
    push OFFSET resultBytes
    push LENGTHOF resultBuffer
    lea edx, resultBuffer
    push edx
    push edi
    call WriteConsoleA

    ; === Успешное завершение программы ===
    push 0
    call ExitProcess

error:
    ; Вывод сообщения об ошибке
    push 0
    push LENGTHOF errorMessage
    lea edx, errorMessage
    push edx
    push edi                         
    call WriteConsoleA

    push 1
    call ExitProcess
main ENDP

validateInput PROC
    ; === Проверка значения ===
    ; Вход:
    ;   EDX - Адрес буфера со строкой
    ;   ECX - Длина строки
    ; Output:
    ;   EAX - 1 если строка корректна, 0 - если нет

    dec ecx                           ; Уменьшаем счетчик, прочитанных байт, чтобы исключить '\n'
    dec ecx                           ; Уменьшаем счетчик, прочитанных байт, чтобы исключить '\r'
    cmp byte ptr [edx + ecx], 13      ; Проверяем, если последний символ '\r'
    je trimCarriageReturn
continueValidation:
    mov eax, 1                        ; Предположим, что ввод действителен
validateLoop:
    mov al, byte ptr [edx]            ; Получим текущий символ
    cmp al, '0'                       ; Проверяем, если >= '0'
    jl invalid                        ; Если меньше, некорректно
    cmp al, '9'                       ; Проверяем, если <= '9'
    jg invalid                        ; Если больше, некорректно
    inc edx                           ; Переходим к следующему символу
    loop validateLoop                 ; Цикл по всем символам
    mov eax, 1                        ; Ввод корректный
    ret
invalid:
    mov eax, 0                        ; Ввод некорректный
    ret
trimCarriageReturn:
    mov byte ptr [edx + ecx], 0
    jmp continueValidation
validateInput ENDP

stringToInt PROC
    ; === Конвертация строки в число ===
    ; Вход:
    ;   ECX - адрес буфера со строкой
    ; Выход:
    ;   EAX - число
    ; Используется:
    ;   EDX - хранение остатка от деления
    xor eax, eax                      ; Очищаем EAX
    xor edx, edx                      ; Очищаем EDX
convertLoop:
    mov dl, byte ptr [ecx]            ; Сохраняем символ из строки в DL
    cmp dl, 0                         ; Проверияем на null-terminator
    je doneConversion
    sub dl, '0'                       ; Конвертируем ASCII в число
    imul eax, eax, 10                 ; Умножаем EAX на 10
    add eax, edx                      ; Добавляем число к результату
    inc ecx                           ; Переходим к следующему символу
    jmp convertLoop
doneConversion:
    ret
stringToInt ENDP

floatToString PROC
    ; === Конвертация дробного числа в строку
    ; Вход:
    ;   EAX = Целая часть
    ;   EBX = Дробная часть
    ;   ESI = Флаг отрицательного числа (0/1)
    ;   EDI = Ссылка на буфер для строки
    ; Используется:
    ;   ECX = Счетчик символов
    ;   EDX = Хранение остатка

    push ebx                          ; Сохранить дробную часть

    xor ecx, ecx                      ; Счётчик символов

    ; === Обработка целой части числа ===
    test esi, esi                   ; Проверить, отрицательное ли число
    jz positiveNumber               ; Если положительное, перейти к обработке
    mov byte ptr [edi], '-'         ; Добавить знак "-"
    inc edi                         ; Сдвинуть указатель буфера

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
    pop ebx                           ; Извлечь символ из стека
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
    ret
floatToString ENDP

divideIntNumbers PROC
    ; === Процедура для деления одного целого числа на друго с получением десятичного числа
    ; Вход:
    ;   EAX = делимое
    ;   EBX = делитель
    ; Выход:
    ;   EDI = Целая часть
    ;   ESI = Десятичная часть
    ; Используется:
    ;   EDX = Для вренного хранения остатка от деления
    ;   ECX = Для длительного хранения остатка от деления

    xor esi, esi                ; Инициализировать десятичную часть
    ; Выполнить целочисленное деление
    xor edx, edx                ; Очистить остаток (EDX)
    div ebx                     ; Деление EAX / EBX (целая часть в EAX, остаток в EDX)

    mov edi, eax                ; Сохранить целую часть

    ; Проверить, есть ли остаток
    test edx, edx               ; Проверить остаток
    jz done                     ; Если остатка нет, завершить
    mov eax, edx                ; Сохранить остаток

    ; Обработка остатка
    mov ecx, 10                 ; Максимальное количество знаков после запятой             
fractionLoop:
    imul eax, 10                ; Умножить остаток на 10
    xor edx, edx                ; Очистить регистр остатка
    div ebx                     ; Выполнить деление (EAX / EBX)

    ; Добавить текущий разряд в десятичную часть
    mov ecx, esi          ; Текущая десятичная часть
    imul ecx, 10            ; Увеличить разрядность
    add ecx, eax            ; Добавить новый разряд
    mov esi, ecx          ; Сохранить десятичную часть

    ; Проверить новый остаток
    test edx, edx               ; Если остаток стал нулевым
    jz done                     ; Прекратить обработку

    mov eax, edx                ; Новый остаток
    loop fractionLoop           ; Повторить цикл

done:
    ret
divideIntNumbers ENDP

subtractFloatNumbers PROC
    ; === Процедура для вычитания одного дробного числа из другого ===
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

subtractFloatNumbers ENDP

getBorrowAdd PROC
    ; === Процедура для получения числа, которое прибавится к меньшей части при вычитании ===
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

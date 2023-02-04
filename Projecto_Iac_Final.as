stackbase       EQU     8000h

TERM_READ       EQU     FFFFh
TERM_WRITE      EQU     FFFEh
TERM_STATUS     EQU     FFFDh
TERM_CURSOR     EQU     FFFCh
TERM_COLOR      EQU     FFFBh

INT_MASK        EQU     FFFAh
INT_MASK_VAL    EQU     8009h    ;1000 0000 0001 1010 b

random_gen      EQU     B400h
altura          EQU     4
probab_0        EQU     F332h
altura_salto    EQU     3
altura_max      EQU     6
el_memoria      EQU     80       ;numero de elementos em memoria 


; Timer
TIMER_CONTROL   EQU     FFF7h
TIMER_COUNTER   EQU     FFF6h
TIMER_SETSTART  EQU     1
TIMER_SETSTOP   EQU     0
TIMERCOUNT_MAX  EQU     20
TIMERCOUNT_MIN  EQU     1
TIMERCOUNT_INIT EQU     3

; 7 segment display
DISP7_D0        EQU     FFF0h
DISP7_D1        EQU     FFF1h
DISP7_D2        EQU     FFF2h
DISP7_D3        EQU     FFF3h
DISP7_D4        EQU     FFEEh
DISP7_D5        EQU     FFEFh


                ORIG            4000h
terreno         TAB     80

                ORIG            0000h
semente         WORD    33
derrota         WORD    0 ;o jogo acaba quando esta variavel tiver valor 1
altura_dino     WORD    0
saltar_descer   WORD    0 ;1 se estiver a saltar, -1 se estiver a descer 
jogo_iniciado   WORD    0 ;o jogo inicia quando esta variavel tiver valor 1
time            WORD    0 ;pontuacao do jogo
TIMER_TICK      WORD    0 ;caso seja 1, jogo atualiza, seja 0 não 
TIMER_COUNTVAL  WORD    TIMERCOUNT_INIT ; indica o periodo de contagem
ground_txt      STR     0,1,800h,'--------------------------------------------------------------------------------',0,0
game_over_txt   STR     0,1,800h,'                             G A M E           O V E R ',0,0                
                
                ; interrupt mask
                MVI     R1,INT_MASK
                MVI     R2,INT_MASK_VAL
                STOR    M[R1],R2
                
                ; enable interruptions
                ENI

                MVI     R6, stackbase                
                
                MVI     R4,jogo_iniciado 
                
                ; Funcao corre em loop ate que seja premido o botao 0 
                        ;Argumentos
                        ;R1 - endereco de jogo_iniciado
                        ;Nao ha retorno
press_start:    LOAD    R1,M[R4]
                CMP     R1,R0
                BR.Z    press_start
                JAL     write_ground
                
                ; Funcao que configura o temporizador
                        ;Argumentos
                        ;R1 - endereco das propriedades do temporizador a 
                        ;alterar 
                        ;R2 - valores para a configuracao
                        ;Nao ha retorno
timer_set:      MVI     R2,TIMERCOUNT_INIT
                MVI     R1,TIMER_COUNTER
                STOR    M[R1],R2          ; coloca o valor do periodo de 
                                          ;contagem no temporizador
                MVI     R1,TIMER_TICK
                STOR    M[R1],R0          ; reseta o timer_tick
                MVI     R1,TIMER_CONTROL
                MVI     R2,TIMER_SETSTART
                STOR    M[R1],R2          ; inicia o temporizador
                ENI 
                
                ;##### Funcao Principal #####
                MVI     R5, TIMER_TICK
                
                ; Funcao principal do jogo
                        ;Argumentos
                        ;R1 - valor do timer_tick  
                        ;R2 - valor da variavel derrota
                        ;Nao ha retorno
                
LOOP:           LOAD    R1,M[R5]
                CMP     R1,R0
                JAL.NZ  ops_frame           
                JAL.NZ  process_timer_event ;atualizacao do temporizador
                MVI     R2, derrota
                LOAD    R4, M[R2]
                CMP     R4, R0              ;verificacao se o jogador perdeu
                BR.Z    LOOP
                
                ;JOGO ACABOU
                JAL     game_over
                JAL     reiniciar_jogo
                BR      press_start
FIM:            BR      FIM

                        ;##### Atualiza Jogo #####
atualizajogo:   ;Atualiza a tabela movendo todos os valores da direita para a 
                ;esquerda colocando na ultima posicao o valor vindo de geracacto
                        ;Argumentos
                        ;R1 - endereco do terreno em memoria 
                        ;R2 - dimensao do vetor 
                        ;Nao ha retorno 
                        
                DEC     R6
                STOR    M[R6], R7 ;guarda o R7 para sair da funcao        
                JAL     guardar_regs    
                MVI     R1, terreno ;posicao inicial na memoria do vetor
                MVI     R2, 79 ;dimensao do vetor
                ADD     R2, R1, R2 ;r2 -> e a posicao final da tabela

                MOV     R5, R1 
                INC     R5 ;r5 -> endereco de r1 + 1 


.mov_col:       LOAD    R4, M[R5]
                STOR    M[R1], R4
                INC     R5
                INC     R1
                CMP     R2, R5
                BR.NN   .mov_col
                
                JAL     guardar_regs
                JAL     geracacto 
                JAL     repor_regs
                
                STOR    M[R1], R3 ;colocar na ultima coluna o valor de 
                                  ;geracactos
                
                JAL     repor_regs
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

                        ;### Gera Cacto ###   
geracacto:      ;Usa uma constante (semente) para gerar um cacto com valor
                ;entre 0 e a altura maxima, sendo a probabilidade de ser
                ;0 de 95% 
                        ;Argumentos
                        ;R1 - Altura Maxima (potencia de 2)
                        ;Retorno
                        ;R3 - Altura do cacto gerado 
                
                MVI     R4, semente ;altura em r1, valor do cacto em r2
                LOAD    R2, M[R4]
                MVI     R1, altura
                DEC     R1
                
                MVI     R5, 1
                AND     R5, R5, R2     ;X AND 1
                SHRA    R2
                CMP     R5, R0
                BR.Z    .probab         ;se R5 for impar, altera os bits

.altera:        MVI     R4, random_gen ;numero que vai gerar outro aleatorio
                XOR     R2, R2, R4
                
.probab:        MVI     R5, probab_0   ;95% chance de nao gerar cacto
                CMP     R2, R5
                BR.C    .no_cacto       ;C porque R5 < 0 
                AND     R3, R2, R1
                INC     R3
                BR      .final

.no_cacto:      MVI     R3, 0
                
.final:         MVI     R4, semente 
                STOR    M[R4], R2      ;guarda a semente que vai ser utilizada
                JMP     R7
                     
                
guardar_regs:   ;Guarda registos
                DEC     R6
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R2
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                JMP     R7
                
repor_regs:     ;Repoe registos 
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R2, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                JMP     R7  
                
write_ground:   ;Escreve o chao 
                ;Argumentos 
                        ;R1 - Endereco de escrita no terminal
                        ;R2 - Endereco do cursor para escolher a linha 
                        ;Nao retorna nada 
                MVI     R1, TERM_WRITE 
                MVI     R2, TERM_CURSOR
                MVI     R3, TERM_COLOR
                MVI     R4, ground_txt
.TerminalLoop:
                LOAD    R5, M[R4]
                INC     R4
                CMP     R5, R0
                BR.Z    .Control
                STOR    M[R1], R5
                BR      .TerminalLoop
.Control:
                LOAD    R5, M[R4]
                INC     R4
                DEC     R5
                BR.Z    .Position
                DEC     R5
                BR.Z    .Color
                BR      .End
.Position:
                LOAD    R5, M[R4]
                INC     R4
                STOR    M[R2], R5
                BR      .TerminalLoop
.Color:
                LOAD    R5, M[R4]
                INC     R4
                STOR    M[R3], R5
                BR      .TerminalLoop
.End:           JMP     R7

ops_frame:      ;Conjunto de operacoes feitas por frame de jogo. Usada para o  
                ;loop principal ficar mais limpo e legivel
                DEC     R6
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R5
                ;APAGA POSICOES MOVIDAS
                MVI     R3, ' '
                JAL     update_game
                MVI     R1, ' '
                JAL     write_dino
                ;ATUALIZA POSICOES 
                JAL     atualizajogo
                JAL     atualiza_dino
                ;ESCREVE POSICOES 
                MVI     R1, 'K'
                JAL     write_dino
                MVI     R3, 'Y'
                JAL     update_game 
                ;VER SE JOGO ACABOU OU NAO
                JAL     check_derrota
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

update_game:    ;Escreve atual estado de jogo no terminal, iterando sobre a
                ;memoria onde os valores deste estao
                        ;Argumentos:
                        ;R1 - Memoria do terreno 
                        ;R2 - Numero de posicoes pelo qual iterar 
                        ;Nao retorna nada 
                DEC     R6
                STOR    M[R6], R7
                MVI     R1, terreno     ;endereco do estado de jogo
                MVI     R2, el_memoria  ;numero de colunas escritas
                DEC     R2
                ADD     R1, R1, R2

.loop:          LOAD    R5, M[R1]
                CMP     R5, R0
                BR.Z    .decrem        ;se o valor lido for 0, passa a frente
                
                DEC     R6
                STOR    M[R6], R5
                
                MVI     R4, TERM_CURSOR 
                MVI     R5, 700h        ;altura acima do chao 
                ADD     R5, R5, R2      ;altura + coluna (coordenadas do cacto)
                STOR    M[R4], R5
                JAL     write_game     ;desenha cacto 
                
.decrem:        DEC     R1
                DEC     R2     ;aproxima da primeira posicao em memoria,   
                CMP     R2, R0 
                BR.NN   .loop  ;se for a primeira entao acaba a funcao
                
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7
              
              
write_game:     ;Escreve cactos ou apaga-os dependendo do argumento introduzido
                        ;Argumento:
                        ;R3 - Caracter a ser desenhado 
                        ;Nao retorna nada 
                ;ESCREVER NAQUELA POSICAO 
                MVI     R4, TERM_WRITE 
                STOR    M[R4], R3
                ;REPOSICIONAR PARA PROXIMA ESCRITA 
                MVI     R4, 100h
                SUB     R5, R5, R4
                MVI     R4, TERM_CURSOR          
                STOR    M[R4], R5
                
                LOAD    R4,M[R6]
                DEC     R4        ;diminui a altura que falta desenhar 
                STOR    M[R6], R4
                CMP     R4,R0
                BR.NZ   write_game
                LOAD    R4, M[R6]
                INC     R6
                JMP     R7
                
write_dino:     ;Desenha o dino dependendo da sua altura atual
                        ;Argumentos:
                        ;R1 - Caracter a ser desenhado
                        ;Nao retorna valor 

                MVI     R4, altura_dino 
                LOAD    R3, M[R4]        ;altura em R3
                MVI     R4, 100h
                MOV     R5, R0
                
.loop:          ADD     R5, R5, R4        ;soma numero de linhas a subtrair 
                CMP     R3, R0            ;R5 = 200h mesmo se altura = 0
                BR.Z    .write
                DEC     R3                ;diminui a altura
                BR      .loop
                
.write:         MVI     R4, 800h        ;Desenha na linha 6 mesmo se altura = 0
                SUB     R5, R4, R5      ;subtrai o numero de linhas 
                MVI     R4, TERM_CURSOR
                STOR    M[R4], R5
                
                MVI     R4, TERM_WRITE  ;desenha dino 
                STOR    M[R4], R1
                
                JMP     R7
                
atualiza_dino:  ;Atualiza posicao do Dino dependendo da sua trajetoria e se 
                ;esta a saltar ou nao
                        ;Argumentos:
                        ;R1 - Endereco da variavel da altura 
                        ;R2 - Endereco da variavel que define se esta a saltar
                        ;Nao retorna valores 
                
                MVI     R1, altura_dino
                MVI     R2, saltar_descer
                LOAD    R4, M[R1] ;contem valor da altura
                LOAD    R5, M[R2] ;define se esta a saltar ou nao
                
                CMP     R5, R0
                BR.Z    .exit        
                BR.N    .descer       ;se res = 0, entao saltar_descer = 1
                
                ;SE ESTIVER A SUBIR
                CMP     R4, R0
                BR.NZ   .pos6
                ;PASSAR PARA MEIO 
                MVI     R3, altura_salto 
                STOR    M[R1], R3
                BR      .exit
                ;PASSAR PARA ALTURA MAX
.pos6:          MVI     R3, -1
                STOR    M[R2], R3
                MVI     R3, altura_max 
                STOR    M[R1], R3
                BR      .exit
                
                ;SE ESTIVER A DESCER 
.descer:        MVI     R3, altura_salto
                CMP     R4, R3
                BR.Z    .pos0
                ;PASSAR PARA O MEIO
                STOR    M[R1], R3
                BR      .exit
                ;PASSAR PARA O CHAO 
.pos0:          STOR    M[R1], R0
                STOR    M[R2], R0
                ENI    
                
.exit:          JMP     R7
                
check_derrota:  ;Verifica se houve colisao entre o jogador e um cacto, mudando 
                ;a variavel de termino de jogo caso sim
                        ;Argumentos:
                        ;R1 - Endereco da primeira posicao de jogo
                        ;R2 - Endereco da altura do dino
                        
                MVI     R1, terreno
                LOAD    R4, M[R1]
                MVI     R2, altura_dino
                LOAD    R5, M[R2]
                
                CMP     R4, R0 
                BR.Z    .exit    ;se nao haver cacto na primeira posicao da exit
                CMP     R5, R4 
                BR.P    .exit    ;se altura do dino for maior que a do cacto sai
                
                MVI     R4, 1
                MVI     R5, derrota 
                STOR    M[R5], R4 ;jogo terminara quando for verificado no loop
                                  ;principal
.exit:          JMP     R7
                
                ;#### salta_dino ####
salta_dino:     ;Coloca o dino a saltar caso esteja no chao
                              
                MVI     R4, saltar_descer
                LOAD    R5, M[R4]
                MVI     R4, -1
                CMP     R4, R5
                BR.NN   .exit        ;se -1-1 = 2 ou -1+1=0, so eh negativo se 
                                     ;-1-0=-1, ou seja, se estiver parado 
                DSI                  ;para interrupcoes enquanto estiver no ar 
                INC     R5           ;passa para 1, dino esta a saltar
                MVI     R4, saltar_descer
                STOR    M[R4], R5
.exit:          JMP     R7
                

game_over:      ;Escreve a frase 'G A M E   O V E R' 
                ;Argumentos 
                        ;R1 - Endereco de escrita no terminal
                        ;R2 - Endereco do cursor para escolher a linha 
                        ;Nao retorna nada 
                MVI     R1, TERM_WRITE
                MVI     R2, TERM_CURSOR
                MVI     R3, TERM_COLOR
                MVI     R4, game_over_txt
                
                MVI     R5, FFFFh
                STOR    M[R2], R5

.TerminalLoop:
                LOAD    R5, M[R4]
                INC     R4
                CMP     R5, R0
                BR.Z    .Control
                STOR    M[R1], R5
                BR      .TerminalLoop

.Control:
                LOAD    R5, M[R4]
                INC     R4
                DEC     R5
                BR.Z    .Position
                DEC     R5
                BR.Z    .Color
                BR      .End

.Position:
                LOAD    R5, M[R4]
                INC     R4
                STOR    M[R2], R5
                BR      .TerminalLoop

.Color:
                LOAD    R5, M[R4]
                INC     R4
                STOR    M[R3], R5
                BR      .TerminalLoop
.End:           JMP     R7

reiniciar_jogo: ;Reinicia o jogo, mudando as variaveis necessarias para o 
                ;estado inicial e a memoria do estado de jogo
                        ;R1 - Memoria do estado de jogo
                        ;R2 - Numero de posicoes a ser alterado

                MVI     R1, terreno
                MVI     R2, el_memoria
                
.loop:          STOR    M[R1], R0
                DEC     R2
                INC     R1
                CMP     R2,R0
                BR.NZ   .loop
                
                MVI     R5, jogo_iniciado ;jogo nao inciado (0)
                STOR    M[R5], R0
                MVI     R5, TIMER_CONTROL ;timer nao inciado (0)
                STOR    M[R5], R0
                MVI     R5, derrota       ;jogador nao derrotado (0)
                STOR    M[R5], R0
                MVI     R4, jogo_iniciado
                MVI     R5,time
                STOR    M[R5],R0
                JMP     R7
                
                
process_timer_event:
                
                ; Funcao que atualiza a pontuacao quando o jogo atualiza
                        ;Argumentos
                        ;R1 - valor do timer_tick
                        ;R2 - endereco do timer_tick
                        ;Nao ha retorno
                ; DECREMENTO DO TIMER_TICK
                MVI     R2,TIMER_TICK
                DSI     
                LOAD    R1,M[R2]
                DEC     R1
                STOR    M[R2],R1
                ENI
                
                ; ATUALIZACAO PONTUACAO
                MVI     R1,time
                LOAD    R2,M[R1]
                INC     R2
                STOR    M[R1],R2
                
                
                

.SCORE:         
                ; SCORE(conversao do valor da pontuacao de hexadecimal para 
                ;decimal) e display da pontuacao 
                
                DEC     R6
                STOR    M[R6],R7
                
                MVI     R1,10000
                MVI     R3,0
                JAL     .DIVISAO
                MVI     R1,DISP7_D4
                STOR    M[R1],R3
                
                MVI     R1,1000
                MVI     R3,0
                JAL     .DIVISAO
                MVI     R1,DISP7_D3
                STOR    M[R1],R3
                
                MVI     R1,100
                MVI     R3,0
                JAL     .DIVISAO
                MVI     R1,DISP7_D2
                STOR    M[R1],R3
                
                MVI     R1,10
                MVI     R3,0
                JAL     .DIVISAO
                MVI     R1,DISP7_D1
                STOR    M[R1],R3
                
                MVI     R1,DISP7_D0
                STOR    M[R1],R2
                
                LOAD    R7,M[R6]
                INC     R6
                
                JMP     R7
               

.DIVISAO:       ;Funcao auxiliar da funcao SCORE
                CMP     R2,R1             
                JMP.N   R7
                INC     R3
                SUB     R2,R2,R1
                BR      .DIVISAO
                
                                
aux_timer_isr:  ; Funcao que repõe o temporizador quando este atualiza o jogo
                        ;Argumentos
                        ;R1 - endereco das propriedades do temporizador a 
                        ;alterar 
                        ;R2 - valores para a configuracao
                        ;Nao ha retorno
                
                ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R1
                DEC     R6
                STOR    M[R6],R2
                ; Reinicio do temporizador
                MVI     R1,TIMER_COUNTVAL
                LOAD    R2,M[R1]
                MVI     R1,TIMER_COUNTER
                STOR    M[R1],R2          ; recoloca o valor do periodo de 
                                          ;contagem no temporizador
                MVI     R1,TIMER_CONTROL
                MVI     R2,TIMER_SETSTART
                STOR    M[R1],R2          ; inicio do timer
                ; Incremento do timer_tick 
                MVI     R2,TIMER_TICK
                LOAD    R1,M[R2]
                INC     R1
                STOR    M[R2],R1          
                ; RESTORE CONTEXT
                LOAD    R2,M[R6]
                INC     R6
                LOAD    R1,M[R6]
                INC     R6
                
                JMP     R7
                

                
                
                ;======= INTERRUPTIONS =======
                
                ORIG    7F00h
KEYZERO:         ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R1
                DEC     R6
                STOR    M[R6],R2
                ; INICIO DO JOGO
                MVI     R1, jogo_iniciado
                LOAD    R2,M[R1]
                INC     R2
                STOR    M[R1],R2
                
                ; RESTORE CONTEXT
                LOAD    R2,M[R6]
                INC     R6
                LOAD    R1,M[R6]
                INC     R6
                RTI
                
                ORIG    7FF0h
TIMER_ISR:      ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R7
                ; CHAMADA DE FUNCAO AUXILIAR
                JAL     aux_timer_isr
                ; RESTORE CONTEXT
                LOAD    R7,M[R6]
                INC     R6
                RTI
                

        
                ORIG    7F30h
KEYUP:          ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R4
                DEC     R6
                STOR    M[R6],R5
                DEC     R6
                STOR    M[R6],R7
                ; CHAMADA DE FUNCAO AUXILIAR
                JAL     salta_dino
                ; RESTORE CONTEXT
                LOAD    R7,M[R6]
                INC     R6
                LOAD    R5,M[R6]
                INC     R6
                LOAD    R4,M[R6]
                INC     R6
                RTI
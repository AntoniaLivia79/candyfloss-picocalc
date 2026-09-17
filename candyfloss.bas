' ============================================================
'  CANDYFLOSS  -  the Blackpool candyfloss trading game
'  Original (c) John Sinclair 1982, written for the BBC Micro
'  PicoMite BASIC conversion for the PicoCalc (320 x 320 LCD)
' ============================================================

OPTION EXPLICIT
CLEAR

CONST POUND$ = "$"
CONST MAXP = 15

CONST C_BLACK   = &H000000
CONST C_WHITE   = &HFFFFFF
CONST C_RED     = &HFF0000
CONST C_GREEN   = &H00FF00
CONST C_BLUE    = &H0000FF
CONST C_LBLUE   = &H00FFFF
CONST C_YELLOW  = &HFFFF00
CONST C_PINK    = &HFF00FF
CONST C_SAND    = C_YELLOW

' wave (noise) effect volume, 1 = as loud as the BBC original
CONST WAVEVOL = 0.5

' text grid geometry (FONT 1 is 8 x 12 pixels)
CONST CW = 8
CONST CH = 12

' ---------------- game variables -----------------
DIM A(MAXP)          ' assets (pounds)
DIM NAME$(MAXP)
DIM L(MAXP)          ' candyfloss made
DIM B(MAXP)          ' 1 = bankrupt
DIM S(MAXP)          ' signs made
DIM P(MAXP)          ' price charged (pence)
DIM G(MAXP)          ' 1 = stock intact, 0 = destroyed
DIM N, D, SC, C, C1, R1, R2, BAN
DIM P9, S3, S2, A2, C9, C2
DIM N1, N2, E, M, P1, V, W, I, J
DIM GAMEOVER

' economic constants (as in the original)
P9 = 10        ' "fair" price in pence
S3 = .15       ' cost of a sign, pounds
S2 = 30        ' base demand
A2 = 2.00      ' starting cash, pounds
C9 = .5
C2 = 1

FONT 1
RANDOMIZE TIMER

' Font 9 holds a single 8x12 character, a pound sign, at the code
' for "$" (font 1 has no pound sign of its own).
DefineFont #9
  01240C08 20221C00 2020F820 00007E20
End DefineFont

DO
  NewGame
  PlayGame
  CLS
  Say 3, 10, "WOULD YOU LIKE TO PLAY AGAIN (Y/N)?"
LOOP UNTIL UCASE$(WaitKey$()) <> "Y"
CLS
END

' ==================== main game flow ====================

SUB NewGame
  LOCAL k$
  D = 0 : R2 = 0 : SC = 0
  GAMEOVER = 0
  Weather                ' title picture, no forecast yet
  Tune 1, 3
  DO
    CLS
    PRINT
    N = AskNum("How many people are playing (1-15)? ")
  LOOP UNTIL N >= 1 AND N <= MAXP AND N = INT(N)
  FOR I = 1 TO N
    PRINT
    LINE INPUT "Type name of player " + STR$(I) + ": ", k$
    IF k$ = "" THEN k$ = "PLAYER " + STR$(I)
    NAME$(I) = UCASE$(LEFT$(k$, 10))
    B(I) = 0 : A(I) = A2
  NEXT I
END SUB

SUB PlayGame
  DO
    ' ---- pick today's weather ----
    W = RND
    IF W < .5 THEN
      SC = 2                       ' sunny
    ELSEIF W < .8 THEN
      SC = 10                      ' cloudy
    ELSE
      SC = 7                       ' hot and dry
    ENDIF
    IF D < 3 THEN SC = 2
    Weather
    IF GAMEOVER THEN EXIT DO

    ' ---- start of a new day ----
    CLS
    D = D + 1
    BAN = 0
    R1 = 1 : R2 = 0
    FOR I = 1 TO N : G(I) = 1 : NEXT I
    C = 2
    IF D > 2 THEN C = 4
    IF D > 6 THEN C = 5
    C1 = C * .01

    COLOUR C_YELLOW, C_BLACK
    PRINT "On day " + Num$(D) + ", candyfloss costs " + Num$(C) + "p"
    COLOUR C_WHITE, C_BLACK
    PRINT
    IF D = 3 THEN PRINT "(Your mean mum has stopped giving you" : PRINT " free sugar)" : PRINT
    IF D = 7 THEN PRINT "(Due to inflation, the price of sugar" : PRINT " has risen)" : PRINT
    IF D > 2 THEN Events
    PRINT
    IF WaitSpace() = 0 THEN GAMEOVER = 1 : EXIT DO

    ' ---- each player makes their decisions ----
    FOR I = 1 TO N
      IF B(I) = 0 THEN
        Decisions I
        IF GAMEOVER THEN EXIT FOR
      ENDIF
    NEXT I
    IF GAMEOVER THEN EXIT DO
    CLS

    ' ---- surprise events after the decisions ----
    IF SC = 10 AND RND < .25 THEN Thunderstorm
    IF GAMEOVER THEN EXIT DO
    Tune 2, 3
    IF R2 = 2 THEN
      CLS
      COLOUR C_YELLOW, C_BLACK
      PRINT "The workmen bought all your candyfloss"
      PRINT "at lunchtime!"
      COLOUR C_WHITE, C_BLACK
      PRINT
      IF WaitSpace() = 0 THEN GAMEOVER = 1 : EXIT DO
    ENDIF

    ' ---- financial results ----
    FOR I = 1 TO N
      CLS
      Banner 0, "BLACKPOOL DAILY FINANCIAL REPORT"
      IF RND < .08 AND R2 <> 2 AND B(I) = 0 THEN Donkeys I
      IF A(I) < 0 THEN A(I) = 0
      Trade I
      IF B(I) = 1 THEN
        PRINT
        COLOUR C_RED, C_BLACK
        PRINT NAME$(I); "'S STAND IS BANKRUPT"
        COLOUR C_WHITE, C_BLACK
        BAN = BAN + 1
        IF WaitSpace() = 0 THEN GAMEOVER = 1 : EXIT FOR
        IF BAN = N THEN GAMEOVER = 1 : EXIT FOR
      ELSE
        Account I
        IF GAMEOVER THEN EXIT FOR
        IF A(I) <= C / 100 THEN
          B(I) = 1
          CLS
          COLOUR C_RED, C_BLACK
          Say 4, 11, NAME$(I) + "'S STAND IS BANKRUPT"
          COLOUR C_WHITE, C_BLACK
          PLAY BBC SOUND &H11, -15, 41, 6 : PLAY BBC SOUND 1, -15, 29, 6 : PLAY BBC SOUND 1, -15, 13, 10
          IF WaitSpace() = 0 THEN GAMEOVER = 1 : EXIT FOR
        ENDIF
      ENDIF
    NEXT I
    IF GAMEOVER THEN EXIT DO
    ' original: a solo player who cannot afford a single candyfloss is out
    IF N = 1 AND A(1) < C / 100 THEN EXIT DO
    IF AllBankrupt() THEN EXIT DO
  LOOP
  FinalScores
END SUB

' Special events on day 3 onwards
SUB Events
  IF SC = 10 THEN
    J = 30 + INT(RND * 5) * 10
    PRINT "There is a " + Num$(J) + "% chance of rain today."
    PRINT "And the weather is COOLER."
    PRINT
    R1 = 1 - J / 100
  ELSEIF SC = 7 THEN
    PRINT "A heat wave is predicted for today!"
    PRINT
    R1 = 2
  ELSEIF RND < .25 THEN
    PRINT "The council workmen are repairing the"
    PRINT "seawall. There will be no traffic on"
    PRINT "the promenade."
    PRINT
    IF RND > .5 THEN
      R1 = .1
    ELSE
      R2 = 2
    ENDIF
  ENDIF
END SUB

' Ask player I how much to make, how many signs, and the price
SUB Decisions(pl AS INTEGER)
  LOCAL ok, cash, x, k$
  DO
    CLS
    Banner 0, NAME$(pl) + "'S STAND    ASSETS " + Money$(A(pl))
    PRINT
    PRINT

    ' --- how many candyfloss ---
    DO
      ok = 1
      x = AskNum("How many candyfloss will you make? ")
      IF x < 0 THEN
        PRINT : PRINT "You're supposed to make the candyfloss"
        PRINT "not buy it. TRY AGAIN!" : ok = 0
      ELSEIF x > 1000 THEN
        PRINT : PRINT "You can't make that many. TRY AGAIN!!" : ok = 0
      ELSEIF x <> INT(x) THEN
        PRINT : PRINT "And who's going to buy "; STR$(x - INT(x), 1, 2); " of a"
        PRINT "candyfloss?" : ok = 0
      ELSEIF x * C1 > A(pl) THEN
        PRINT
        PPrint "Can't you add up? You've only " + Money$(A(pl)) : PRINT
        PRINT "in cash and to make " + Num$(x) + " candyfloss"
        PPrint "you need " + Money$(x * C1) + " in cash." : PRINT
        ok = 0
      ENDIF
      IF ok = 0 THEN PRINT
    LOOP UNTIL ok
    L(pl) = x

    ' --- how many advertising signs ---
    DO
      ok = 1
      PRINT
      PRINT "How many advertising signs (" + Num$(S3 * 100) + "p"
      x = AskNum("each) do you want to make? ")
      IF x < 0 OR x > 50 THEN
        PRINT : PRINT "Come on, be reasonable!!! Try again." : ok = 0
      ELSEIF x <> INT(x) THEN
        PRINT : PRINT "And what use is "; STR$(x - INT(x), 1, 2); " of a sign?"
        ok = 0
      ELSEIF x * S3 > A(pl) - L(pl) * C1 THEN
        cash = A(pl) - L(pl) * C1
        PRINT : PPrint "Think again, you have only " + Money$(cash) : PRINT
        PRINT "in cash left" : ok = 0
      ENDIF
    LOOP UNTIL ok
    S(pl) = x

    ' --- price ---
    DO
      ok = 1
      PRINT
      PRINT "How much do you wish to charge"
      x = AskNum("for a candyfloss (pence)? ")
      IF x > 100 THEN
        PRINT : PRINT "What are you giving with the"
        PRINT "candyfloss - GOLD DUST?" : ok = 0
      ELSEIF x < 0 THEN
        PRINT : PRINT "What!! Giving money away. Please send"
        PRINT "a small donation to the authors of"
        PRINT "this program." : ok = 0
      ELSEIF x <> INT(x) THEN
        PRINT : PRINT "Whole pence only please." : ok = 0
      ENDIF
    LOOP UNTIL ok
    P(pl) = x

    PRINT : PRINT
    LINE INPUT "WOULD YOU LIKE TO CHANGE ANYTHING? ", k$
  LOOP WHILE UCASE$(LEFT$(k$, 1)) = "Y"
END SUB

' Donkeys eat player I's stock
SUB Donkeys(pl AS INTEGER)
  COLOUR C_RED, C_BLACK
  PRINT " DISASTER!!"
  COLOUR C_WHITE, C_BLACK
  PRINT "Oh dear. Donkeys have eaten all"
  PRINT NAME$(pl); "'s candyfloss"
  PRINT
  G(pl) = 0
END SUB

' Thunderstorm - every stall is wiped out
SUB Thunderstorm
  LOCAL k
  SC = 5
  Weather
  CLS
  COLOUR C_YELLOW, C_BLACK
  PRINT "NEWS FLASH:"
  COLOUR C_WHITE, C_BLACK
  PRINT "A severe thunderstorm hit Blackpool"
  PRINT "today. All stalls destroyed!"
  PRINT
  FOR k = 1 TO N : G(k) = 0 : NEXT k
  IF WaitSpace() = 0 THEN GAMEOVER = 1
END SUB

' The sales model from the original program
SUB Trade(pl AS INTEGER)
  IF P(pl) >= P9 THEN
    N1 = (P9 ^ 2) * S2 / (P(pl) ^ 2)
  ELSE
    N1 = (P9 - P(pl)) / P9 * .8 * S2 + S2
  ENDIF
  W = -S(pl) * C9
  V = 1 - (EXP(W) * C2)
  N2 = R1 * (N1 + (N1 * V))
  N2 = INT(N2 * G(pl))
  IF R2 = 2 THEN N2 = L(pl)
  IF N2 > L(pl) THEN N2 = L(pl)
  E = S(pl) * S3 + L(pl) * C1
  M = N2 * P(pl) * .01
  P1 = M - E
  A(pl) = A(pl) + P1
END SUB

' Daily account statement for player pl (PROCACCOUNT)
SUB Account(pl AS INTEGER)
  PRINT
  COLOUR C_YELLOW, C_BLACK
  PRINT "      DAY " + Num$(D) + "         " + NAME$(pl) + "'S STAND"
  COLOUR C_WHITE, C_BLACK
  PRINT
  PRINT Pad$("   " + Num$(N2), 9) + "CANDYFLOSS SOLD"
  PRINT
  PPrint Pad$("   " + Money$(P(pl) / 100), 9) + Pad$("PER CANDYFLOSS", 17) + "INCOME " + Money$(M)
  PRINT : PRINT
  PRINT Pad$("   " + Num$(L(pl)), 9) + "CANDYFLOSS MADE"
  PRINT
  PPrint Pad$("   " + Num$(S(pl)), 9) + Pad$("SIGNS MADE", 16) + "EXPENSES " + Money$(E)
  PRINT : PRINT
  IF P1 < 0 THEN COLOUR C_RED, C_BLACK ELSE COLOUR C_GREEN, C_BLACK
  PPrint SPACE$(16) + "PROFIT " + Money$(P1)
  COLOUR C_WHITE, C_BLACK
  PRINT : PRINT
  PPrint SPACE$(16) + "ASSETS " + Money$(A(pl))
  PRINT
  IF WaitSpace() = 0 THEN GAMEOVER = 1
END SUB

SUB FinalScores
  LOCAL k
  CLS
  Banner 0, "END OF SEASON - DAY " + STR$(D)
  PRINT : PRINT
  FOR k = 1 TO N
    IF B(k) THEN
      COLOUR C_RED, C_BLACK
      PRINT " " + Pad$(NAME$(k), 15) + "BANKRUPT"
    ELSE
      COLOUR C_WHITE, C_BLACK
      PPrint " " + Pad$(NAME$(k), 15) + "ASSETS " + Money$(A(k)) : PRINT
    ENDIF
  NEXT k
  COLOUR C_WHITE, C_BLACK
  PRINT
  Tune 3, 2
  k = WaitSpace()
END SUB

FUNCTION AllBankrupt()
  LOCAL k
  AllBankrupt = 1
  FOR k = 1 TO N
    IF B(k) = 0 THEN AllBankrupt = 0
  NEXT k
END FUNCTION

' ==================== helpers ====================

FUNCTION Money$(x AS FLOAT)
  LOCAL mv
  mv = INT(x * 100 + .5) / 100
  IF mv < .99 AND mv > -.99 THEN
    Money$ = STR$(INT(100 * mv), 1, 0) + "p"
  ELSEIF mv < 0 THEN
    Money$ = "-" + POUND$ + STR$(-mv, 1, 2)
  ELSE
    Money$ = POUND$ + STR$(mv, 1, 2)
  ENDIF
END FUNCTION

FUNCTION Num$(x AS FLOAT)
  Num$ = STR$(x, 1, 0)
END FUNCTION

FUNCTION Pad$(s$, wd AS INTEGER)
  Pad$ = LEFT$(s$ + SPACE$(wd), wd)
END FUNCTION

FUNCTION AskNum(prompt$)
  LOCAL k$, ok
  DO
    LINE INPUT prompt$, k$
    k$ = LTRIM$(RTRIM$(k$))
    ok = (k$ <> "") AND (INSTR("0123456789.-", LEFT$(k$, 1)) > 0)
    IF ok = 0 THEN PRINT "Please type a number."
  LOOP UNTIL ok
  AskNum = VAL(k$)
END FUNCTION

FUNCTION LTRIM$(s$)
  LOCAL t$
  t$ = s$
  DO WHILE LEFT$(t$, 1) = " " : t$ = MID$(t$, 2) : LOOP
  LTRIM$ = t$
END FUNCTION

FUNCTION RTRIM$(s$)
  LOCAL t$
  t$ = s$
  DO WHILE RIGHT$(t$, 1) = " " : t$ = LEFT$(t$, LEN(t$) - 1) : LOOP
  RTRIM$ = t$
END FUNCTION

SUB Say(cc AS INTEGER, rr AS INTEGER, s$)
  PRINT @(cc * CW, rr * CH) "";
  PPrint s$
END SUB

SUB PPrint(s$)
  LOCAL ci, c$
  FOR ci = 1 TO LEN(s$)
    c$ = MID$(s$, ci, 1)
    IF c$ = POUND$ THEN
      FONT 9 : PRINT "$"; : FONT 1
    ELSE
      PRINT c$;
    ENDIF
  NEXT ci
END SUB

SUB Banner(rr AS INTEGER, s$)
  COLOUR C_WHITE, C_RED
  Say 0, rr, SPACE$(40)
  Say 1, rr, s$
  COLOUR C_WHITE, C_BLACK
  PRINT @(0, CH * (rr + 1)) "";
END SUB

FUNCTION WaitKey$()
  LOCAL k$
  DO : k$ = INKEY$ : LOOP WHILE k$ <> ""      ' flush
  DO : k$ = INKEY$ : LOOP UNTIL k$ <> ""
  WaitKey$ = k$
END FUNCTION

' Bottom-line prompt.  Returns 1 for SPACE, 0 for Q (quit)
FUNCTION WaitSpace()
  LOCAL k$
  COLOUR C_WHITE, C_RED
  Say 0, 25, " PRESS SPACE TO CONTINUE, Q TO QUIT.    "
  COLOUR C_WHITE, C_BLACK
  DO
    k$ = UCASE$(WaitKey$())
  LOOP UNTIL k$ = " " OR k$ = "Q"
  WaitSpace = (k$ = " ")
  COLOUR C_WHITE, C_BLACK
  Say 0, 25, SPACE$(40)
END FUNCTION

' ==================== sound ====================
' PROCTUNE1(M,T) from the original.  Channel 0 is noise, channels
' 1-3 play the melody in three octaves.  The sequencer queues the
' notes and paces the loop itself.

SUB Tune(mm AS INTEGER, t AS INTEGER)
  LOCAL nt, pa
  SELECT CASE mm
    CASE 1 : RESTORE Tune1Data
    CASE 2 : RESTORE Tune2Data
    CASE 3 : RESTORE Tune3Data
    CASE ELSE : RESTORE Tune4Data
  END SELECT
  IF mm = 1 THEN                             ' waves breaking (noise sweep)
    FOR nt = 1 TO 2
      FOR pa = -6 TO -15 STEP -1
        PLAY BBC SOUND 0, CINT(pa * WAVEVOL), 4, 2
      NEXT pa
      PLAY BBC SOUND 0, CINT(-15 * WAVEVOL), 5, 4
      FOR pa = -15 TO -6
        PLAY BBC SOUND 0, CINT(pa * WAVEVOL), 4, 5
      NEXT pa
    NEXT nt
  ENDIF
  PLAY BBC SOUND 2, 0, 0, 1
  PLAY BBC SOUND 1, 0, 0, 1
  DO
    READ pa
    IF pa = 255 THEN EXIT DO
    IF INKEY$ <> "" THEN FlushSound : EXIT SUB   ' any key skips the tune
    IF pa = 0 THEN
      TunePause
    ELSE
      PLAY BBC SOUND 1, -12, pa + 48, t
      PLAY BBC SOUND 2, -12, pa, t
      PLAY BBC SOUND 3, -15, pa + 96, t
    ENDIF
  LOOP
  IF mm = 1 THEN                             ' closing wave
    FOR pa = -3 TO -15 STEP -1
      PLAY BBC SOUND 0, CINT(pa * WAVEVOL), 5, 3
    NEXT pa
    PLAY BBC SOUND 0, CINT(-15 * WAVEVOL), 5, 4
    FOR pa = -15 TO -4
      PLAY BBC SOUND 0, CINT(pa * WAVEVOL), 4, 5
    NEXT pa
  ENDIF
END SUB

' PROCPAUSE - a rest on all three tone channels
SUB TunePause
  PLAY BBC SOUND 1, 0, 0, 1
  PLAY BBC SOUND 2, 0, 0, 1
  PLAY BBC SOUND 3, 0, 0, 1
END SUB

' Stop everything at once (flush every channel queue)
SUB FlushSound
  PLAY BBC SOUND &H10, 0, 0, 1
  PLAY BBC SOUND &H11, 0, 0, 1
  PLAY BBC SOUND &H12, 0, 0, 1
  PLAY BBC SOUND &H13, 0, 0, 1
END SUB

Tune1Data:
DATA 50,50,54,58,58,58,50,50,38,30,30,22,18,18,22,50,50,50,0,50,50,50,50,50
DATA 0,0,50,50,50,58,58,58,50,50,38,30,30,22,18,18,22,58,58,58,58,58,58,58,58,58,58
DATA 0,0,58,58,58,66,66,66,58,58,42,38,38,30,26,26,30,58,58,58,50,50,50,42
DATA 42,42,38,38,26,38,38,38,30,30,30,38,38,38,30,26,30,38,38,38,30,30,30
DATA 18,18,18,50,50,50,58,58,58,50,50,38,30,30,22,18,18,22,50,50,50,0,50,50,50,50,50,50,50,50,50,50
DATA 0,0,58,58,58,50,50,38,30,30,22,18,18,22,58,58,58,58,58,58,58,58,58,0
DATA 0,54,54,58,66,66,62,66,66,62,66,66,66,58,58,46,58,58,50,58,58,50,58,58
DATA 50,42,42,38,30,30,30,58,58,58,0,0,0,38,30,30,38,22,22,22,22,22,22,22
DATA 22,22,255
Tune2Data:
DATA 98,98,98,86,78,66,50,50,50,50,255
Tune3Data:
DATA 78,78,78,78,50,50,66,66,78,78,98,98,86,86,78,78,78,78,50,50,66,66,78,78
DATA 114,114,106,106,106,106,255
Tune4Data:
DATA 18,18,18,0,18,18,0,18,22,22,18,10,10,2,18,18,18,18,255

' ==================== graphics ====================

SUB Weather
  LOCAL k
  CLS
  ' sky and sand
  BOX 0, 0, 320, 168, 0, C_BLUE, C_BLUE
  BOX 0, 168, 320, 152, 0, C_SAND, C_SAND
  ' sea foam line
  LINE 0, 168, 319, 168, 3, C_WHITE
  ' Blackpool Tower
  BOX 60, 64, 16, 80, 0, C_WHITE, C_WHITE
  LINE 60, 64, 52, 140, 2, C_WHITE
  LINE 76, 64, 84, 140, 2, C_WHITE
  BOX 54, 42, 28, 22, 0, C_WHITE, C_WHITE
  LINE 68, 20, 68, 42, 2, C_RED
  CIRCLE 68, 18, 3, 1, 1, C_RED, C_RED
  ' promenade buildings with two rows of windows
  BOX 16, 136, 88, 32, 0, C_RED, C_RED
  BOX 152, 136, 128, 32, 0, C_RED, C_RED
  FOR k = 0 TO 4
    BOX 24 + k * 16, 140, 6, 9, 0, C_YELLOW, C_YELLOW
    BOX 24 + k * 16, 154, 6, 9, 0, C_YELLOW, C_YELLOW
  NEXT k
  FOR k = 0 TO 6
    BOX 160 + k * 18, 140, 6, 9, 0, C_YELLOW, C_YELLOW
    BOX 160 + k * 18, 154, 6, 9, 0, C_YELLOW, C_YELLOW
  NEXT k
  ' the candyfloss stall
  BOX 112, 180, 112, 100, 0, C_LBLUE, C_LBLUE
  BOX 112, 180, 112, 14, 0, C_LBLUE, C_LBLUE
  BOX 104, 192, 128, 16, 0, C_PINK, C_PINK
  COLOUR C_WHITE, C_PINK
  PRINT @(120, 194) "CANDYFLOSS";
  BOX 116, 212, 104, 56, 0, C_BLUE, C_BLUE
  FOR k = 0 TO 2
    LINE 140 + k * 28, 236, 140 + k * 28, 262, 2, C_WHITE
    CIRCLE 140 + k * 28, 232, 9, 1, 1, C_PINK, C_PINK
  NEXT k
  BOX 112, 268, 112, 12, 0, C_LBLUE, C_LBLUE
  COLOUR C_WHITE, C_BLACK

  IF SC = 0 THEN
    COLOUR C_YELLOW, C_BLUE
    Say 8, 1, "* C A N D Y F L O S S *"
    COLOUR C_WHITE, C_BLUE
    Say 6, 2, "the Blackpool trading game"
    COLOUR C_WHITE, C_BLACK
    EXIT SUB
  ENDIF

  COLOUR C_GREEN, C_BLUE
  Say 3, 0, "BLACKPOOL WEATHER REPORT"
  COLOUR C_WHITE, C_BLACK
  SELECT CASE SC
    CASE 2
      COLOUR C_YELLOW, C_BLUE : Say 20, 2, "SUNNY"
      Sunny
      Tune 3, 2
      WaitPic
    CASE 7
      COLOUR C_RED, C_BLUE : Say 20, 2, "HOT AND DRY"
      Sunny
      Tune 3, 2
      WaitPic
    CASE 10
      COLOUR C_WHITE, C_BLUE : Say 20, 2, "CLOUDY"
      Cloud C_WHITE
      Tune 4, 3
      WaitPic
    CASE 5
      COLOUR C_YELLOW, C_BLUE : Say 20, 2, "THUNDERSTORMS"
      Thunder
      WaitPic
  END SELECT
  COLOUR C_WHITE, C_BLACK
END SUB

' Wait for space on the picture screen; Q quits the game
SUB WaitPic
  IF WaitSpace() = 0 THEN GAMEOVER = 1
END SUB

SUB Sunny
  LOCAL k
  CIRCLE 220, 70, 20, 1, 1, C_YELLOW, C_YELLOW
  FOR k = 0 TO 7
    LINE 220 + 26 * COS(k * PI / 4), 70 + 26 * SIN(k * PI / 4), 220 + 36 * COS(k * PI / 4), 70 + 36 * SIN(k * PI / 4), 2, C_YELLOW
  NEXT k
END SUB

SUB Cloud(col AS INTEGER)
  CIRCLE 205, 75, 16, 1, 1, col, col
  CIRCLE 228, 65, 20, 1, 1, col, col
  CIRCLE 252, 76, 16, 1, 1, col, col
  BOX 200, 76, 60, 16, 0, col, col
END SUB

SUB Thunder
  LOCAL k, y
  Cloud C_LBLUE
  ' lightning
  FOR k = 0 TO 2
    LINE 215 + k * 14, 94, 210 + k * 14, 108, 3, C_LBLUE
    LINE 210 + k * 14, 108, 218 + k * 14, 108, 3, C_LBLUE
    LINE 218 + k * 14, 108, 208 + k * 14, 126, 3, C_LBLUE
  NEXT k
  ' rain sweeping up the beach, with the original's rising tones
  FOR y = 22 TO 15 STEP -1
    FOR k = 0 TO 39 STEP 2
      LINE k * 8 + 2, y * CH, k * 8 + 6, y * CH + 10, 1, C_LBLUE
    NEXT k
    PLAY BBC SOUND 1, -13, 50 + 5 * y, 2
    PAUSE 300
    PLAY BBC SOUND 1, -13, 30 + 5 * y, 2
  NEXT y
END SUB

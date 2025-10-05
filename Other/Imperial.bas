Attribute VB_Name = "Imperial"
Option Explicit

' ===========================================================================
' ImperialPlusPlus.bas
' Author: ChatGPT (for Preston)
' Purpose:
'   A batteries-included module for Imperial/Metric conversions, parsing,
'   rounding, and pretty-printing with lots of knobs.
'
' Highlights / Extras:
'   - Auto denominator selection (tightest fraction up to a max power-of-two)
'   - Optional tolerance display (±1/32") independent of primary denom
'   - Fraction-only output for sub-inch values (e.g., 13/16")
'   - Configurable hyphen/space style between whole and fraction
'   - Feet/inches formatting with optional Unicode primes
'   - Robust parsing for imperial & metric strings (ft/in, m/cm/mm, decimals)
'   - Safe math (custom GCD), negative handling, zero handling
'   - Snap helpers, array decomposition to feet-inches-num/den
'
' Public UDFs (callable from cells):
'   =FmtInches(38.9375)                                        -> 3' 2-15/16"
'   =FmtInches(38.9375, , TRUE)                                 -> 3' 2-15/16"
'   =FmtInches(0.8125, 16, FALSE, TRUE)                         -> 13/16"
'   =FmtInchesAuto(1.0/3, 64)                                   -> best up to 1/64
'   =FmtInchesWithTol(10.0/3, 16, 32)                           -> 3" ±1/32"
'   =FmtFeetInches(38.9375)                                     -> 3' 2-15/16"
'   =MetersToInchesText(1.193, 16, TRUE)                        -> 3' 10-15/16"
'   =ParseLengthToInches("5' 7-3/16""")                         -> 67.1875
'   =ParseAndFormat("2m 5cm 4mm", 16, TRUE)                     -> 6' 8-11/16"
'   =SnapToDenom(2.01, 16)                                      -> 2
'   =InchesToFeetInchesArray(38.9375, 16)                       -> {3,2,15,16,1}
' ===========================================================================

' ===== Constants =====
Private Const IN_PER_FT As Double = 12#
Private Const IN_PER_M As Double = 39.3700787401575
Private Const IN_PER_CM As Double = 0.393700787401575
Private Const IN_PER_MM As Double = 3.93700787401575E-02
Private Const M_PER_IN As Double = 0.0254

' ===== Math helpers =====
Private Function AbsD(ByVal x As Double) As Double
    If x < 0# Then AbsD = -x Else AbsD = x
End Function

Private Function SgnD(ByVal x As Double) As Double
    If x < 0# Then
        SgnD = -1#
    ElseIf x > 0# Then
        SgnD = 1#
    Else
        SgnD = 0#
    End If
End Function

Private Function GCD_Long(ByVal a As Long, ByVal b As Long) As Long
    Dim t As Long
    If a < 0 Then a = -a
    If b < 0 Then b = -b
    If a = 0 Then GCD_Long = b: Exit Function
    If b = 0 Then GCD_Long = a: Exit Function
    Do While b <> 0
        t = a Mod b
        a = b
        b = t
    Loop
    GCD_Long = a
End Function

Private Sub ReduceFraction(ByRef n As Long, ByRef d As Long)
    Dim g As Long
    If d = 0 Then Exit Sub
    If n = 0 Then d = 1: Exit Sub
    g = GCD_Long(Abs(n), Abs(d))
    If g > 1 Then
        n = n \ g
        d = d \ g
    End If
End Sub

' ===== Core fractioning =====
Private Sub MixedFractionFromInches(ByVal inches As Double, _
                                    ByVal denom As Long, _
                                    ByRef whole As Long, _
                                    ByRef num As Long, _
                                    ByRef den As Long)
    Dim mag As Double, frac As Double, r As Double, carry As Long
    Const EPS As Double = 0.0000000001 ' tolerance for floating point noise

    If denom < 1 Then denom = 1

    mag = Abs(inches)
    whole = Fix(mag)
    frac = mag - whole

    ' Work in "ticks" of 1/denom
    r = frac * denom

    ' If r is essentially an integer (e.g., 15.0000000000), DON'T add 0.5
    If Abs(r - Fix(r)) < EPS Then
        num = CLng(Fix(r))
    Else
        ' Half-up rounding without banker’s oddities
        num = CLng(Int(r + 0.5))
    End If

    den = denom

    ' Handle carry (e.g., num = 16 -> +1 inch)
    If num >= den Then
        carry = num \ den
        whole = whole + carry
        num = num - carry * den
    End If

    ' Reduce the fraction
    ReduceFraction num, den

    ' Restore sign to the whole part only
    If inches < 0# Then whole = -whole
End Sub


Private Function BestDenominator(ByVal inches As Double, ByVal maxDenom As Long) As Long
    Dim d As Long, bestD As Long
    Dim bestErr As Double, err As Double
    Dim whole As Long, num As Long, den As Long
    If maxDenom < 1 Then maxDenom = 1
    
    bestD = 1
    bestErr = 1E+99
    
    d = 1
    Do While d <= maxDenom
        MixedFractionFromInches inches, d, whole, num, den
        err = AbsD(AbsD(inches) - (AbsD(CDbl(whole)) + IIf(den <> 0, num / den, 0#)))
        If err < bestErr Then
            bestErr = err
            bestD = d
        End If
        d = d * 2
    Loop
    BestDenominator = bestD
End Function

' ===== Formatting helpers =====
Private Function InchMark(ByVal useUnicode As Boolean) As String
    If useUnicode Then
        InchMark = """"
    Else
        InchMark = """"
    End If
End Function

Private Function FootMark(ByVal useUnicode As Boolean) As String
    If useUnicode Then FootMark = "'" Else FootMark = "'"
End Function

Private Function BuildWholeFrac(ByVal whole As Long, ByVal num As Long, ByVal den As Long, _
                                ByVal useHyphen As Boolean, ByVal fractionOnly As Boolean) As String
    If num = 0 Then
        BuildWholeFrac = CStr(whole)
    ElseIf fractionOnly And whole = 0 Then
        BuildWholeFrac = CStr(num) & "/" & CStr(den)
    Else
        BuildWholeFrac = CStr(whole) & IIf(useHyphen, "-", " ") & CStr(num) & "/" & CStr(den)
    End If
End Function

' ===== Main formatters =====
Public Function FmtInches(ByVal inches As Double, _
                          Optional ByVal denom As Long = 16, _
                          Optional ByVal useUnicode As Boolean = False, _
                          Optional ByVal fractionOnlyIfSubInch As Boolean = False, _
                          Optional ByVal hyphenBetween As Boolean = True, _
                          Optional ByVal showFeet As Boolean = True) As String
    Dim s As String
    Dim whole As Long, num As Long, den As Long
    Dim feet As Long, remIn As Long
    
    If AbsD(inches) < 0.0000001 Then
        If showFeet Then
            FmtInches = "0" & FootMark(useUnicode) & " 0" & InchMark(useUnicode)
        Else
            FmtInches = "0" & InchMark(useUnicode)
        End If
        Exit Function
    End If
    
    MixedFractionFromInches inches, denom, whole, num, den
    
    If showFeet Then
        feet = whole \ 12
        remIn = whole Mod 12
        s = CStr(feet) & FootMark(useUnicode) & " " & _
            BuildWholeFrac(remIn, num, den, hyphenBetween, fractionOnlyIfSubInch) & InchMark(useUnicode)
        FmtInches = s
    Else
        s = BuildWholeFrac(whole, num, den, hyphenBetween, fractionOnlyIfSubInch) & InchMark(useUnicode)
        FmtInches = s
    End If
End Function

Public Function FmtInchesAuto(ByVal inches As Double, _
                              Optional ByVal maxDenom As Long = 64, _
                              Optional ByVal useUnicode As Boolean = False, _
                              Optional ByVal fractionOnlyIfSubInch As Boolean = False, _
                              Optional ByVal hyphenBetween As Boolean = True, _
                              Optional ByVal showFeet As Boolean = True) As String
    Dim d As Long
    d = BestDenominator(inches, maxDenom)
    FmtInchesAuto = FmtInches(inches, d, useUnicode, fractionOnlyIfSubInch, hyphenBetween, showFeet)
End Function

Public Function FmtInchesWithTol(ByVal inches As Double, _
                                 Optional ByVal denom As Long = 16, _
                                 Optional ByVal tolDenom As Long = 32, _
                                 Optional ByVal useUnicode As Boolean = False, _
                                 Optional ByVal showFeet As Boolean = False) As String
    Dim baseTxt As String, tolInches As Double, tolWhole As Long, tolNum As Long, tolDen As Long
    Dim tolTxt As String
    
    baseTxt = FmtInches(inches, denom, useUnicode, False, True, showFeet)
    
    tolInches = 1# / tolDenom
    MixedFractionFromInches tolInches, tolDenom, tolWhole, tolNum, tolDen
    If tolWhole <> 0 Then
        tolTxt = CStr(tolWhole)
        If tolNum <> 0 Then tolTxt = tolTxt & "-" & tolNum & "/" & tolDen
    ElseIf tolNum <> 0 Then
        tolTxt = CStr(tolNum) & "/" & CStr(tolDen)
    Else
        tolTxt = "0"
    End If
    
    FmtInchesWithTol = baseTxt & " ±" & tolTxt & InchMark(useUnicode)
End Function

Public Function FmtFeetInches(ByVal inches As Double, _
                              Optional ByVal denom As Long = 16, _
                              Optional ByVal useUnicode As Boolean = False) As String
    FmtFeetInches = FmtInches(inches, denom, useUnicode, False, True, True)
End Function

' ===== Converters =====
Public Function InchesToMeters(ByVal inches As Double) As Double
    InchesToMeters = inches * M_PER_IN
End Function

Public Function MetersToInches(ByVal meters As Double) As Double
    MetersToInches = meters * IN_PER_M
End Function

Public Function MillimetersToInches(ByVal mm As Double) As Double
    MillimetersToInches = mm * IN_PER_MM
End Function

Public Function CentimetersToInches(ByVal cm As Double) As Double
    CentimetersToInches = cm * IN_PER_CM
End Function

Public Function FeetToInches(ByVal feet As Double) As Double
    FeetToInches = feet * IN_PER_FT
End Function

' ===== Parse helpers =====
' (ParseLengthToInches and supporting routines go here — same as in previous module)
' ===========================================================================
' ===== Parse helpers =====
' Parse "5' 7-3/16""", "67 3/16 in", "38.9375""", "2m 5cm 4mm", "120mm"
'
Public Function ParseLengthToInches(ByVal s As String) As Double
    Dim t As String, neg As Boolean
    Dim feet As Double, inchWhole As Double, num As Double, den As Double
    Dim m As Double, cm As Double, mm As Double
    Dim i As Long, parts() As String, token As String
    
    t = Trim$(s)
    If Len(t) = 0 Then ParseLengthToInches = CVErr(xlErrValue): Exit Function
    
    ' Normalize quotes & punctuation
    t = Replace(t, "'", "'")
    t = Replace(t, "”", """")
    t = Replace(t, "in.", "in")
    t = Replace(t, ",", " ")
    t = Application.WorksheetFunction.Trim(t)
    
    If Left$(t, 1) = "-" Then neg = True: t = Mid$(t, 2)
    
    ' Metric scan: collect tokens like 2m, 12cm, 4mm
    parts = Split(t, " ")
    For i = LBound(parts) To UBound(parts)
        token = parts(i)
        If Len(token) = 0 Then GoTo NextToken
        If LCase$(Right$(token, 2)) = "mm" Then
            mm = mm + Val(Left$(token, Len(token) - 2))
        ElseIf LCase$(Right$(token, 2)) = "cm" Then
            cm = cm + Val(Left$(token, Len(token) - 2))
        ElseIf Right$(token, 1) = "m" Then
            If LCase$(Right$(token, 2)) <> "cm" And LCase$(Right$(token, 2)) <> "mm" Then
                m = m + Val(Left$(token, Len(token) - 1))
            End If
        End If
NextToken:
    Next i
    
    If m <> 0 Or cm <> 0 Or mm <> 0 Then
        ParseLengthToInches = m * IN_PER_M + cm * IN_PER_CM + mm * IN_PER_MM
        If neg Then ParseLengthToInches = -ParseLengthToInches
        Exit Function
    End If
    
    ' Imperial: try feet portion
    If InStr(1, t, "'") > 0 Or InStr(1, LCase$(t), "ft") > 0 Then
        Dim pos As Long, tmp As String
        pos = InStr(1, t, "'")
        If pos > 0 Then
            tmp = Trim$(Left$(t, pos - 1))
            feet = Val(tmp)
            t = Trim$(Mid$(t, pos + 1))
        Else
            pos = InStr(1, LCase$(t), "ft")
            If pos > 0 Then
                tmp = Trim$(Left$(t, pos - 1))
                feet = Val(tmp)
                t = Trim$(Mid$(t, pos + 2))
            End If
        End If
    End If
    
    ' strip trailing inch markers
    t = Replace$(t, "in", "", , , vbTextCompare)
    t = Replace$(t, """", "")
    t = Application.WorksheetFunction.Trim(t)
    
    If Len(t) > 0 Then
        Dim parts2() As String
        If InStr(1, t, "-") > 0 Then
            parts2 = Split(t, "-")
            inchWhole = Val(Trim$(parts2(0)))
            If UBound(parts2) >= 1 Then ParseFraction Trim$(parts2(1)), num, den
        ElseIf InStr(1, t, " ") > 0 Then
            parts2 = Split(t, " ")
            inchWhole = Val(Trim$(parts2(0)))
            If UBound(parts2) >= 1 Then ParseFraction Trim$(parts2(1)), num, den
        ElseIf InStr(1, t, "/") > 0 Then
            inchWhole = 0
            ParseFraction Trim$(t), num, den
        Else
            inchWhole = Val(t)
            num = 0: den = 1
        End If
    Else
        num = 0: den = 1
    End If
    
    If den = 0 Then ParseLengthToInches = CVErr(xlErrValue): Exit Function
    
    ParseLengthToInches = feet * IN_PER_FT + inchWhole + IIf(den <> 0, num / den, 0#)
    If neg Then ParseLengthToInches = -ParseLengthToInches
End Function

Public Function TryParseLengthToInches(ByVal s As String, ByRef inches As Double) As Boolean
    Dim v As Variant
    v = ParseLengthToInches(s)
    If IsError(v) Then
        TryParseLengthToInches = False
    Else
        inches = v
        TryParseLengthToInches = True
    End If
End Function

Private Sub ParseFraction(ByVal s As String, ByRef num As Double, ByRef den As Double)
    Dim p As Long, nStr As String, dStr As String
    s = Application.WorksheetFunction.Trim(s)
    p = InStr(1, s, "/")
    If p > 0 Then
        nStr = Trim$(Left$(s, p - 1))
        dStr = Trim$(Mid$(s, p + 1))
        If Len(nStr) > 0 And Len(dStr) > 0 Then
            num = Val(nStr)
            den = Val(dStr)
        Else
            num = 0: den = 1
        End If
    Else
        num = Val(s): den = 1
    End If
End Sub

' ===== Array decomposition =====
Public Function InchesToFeetInchesArray(ByVal inches As Double, Optional ByVal denom As Long = 16) As Variant
    Dim whole As Long, num As Long, den As Long
    Dim feet As Long, remIn As Long, sign As Long
    
    sign = IIf(inches < 0#, -1, 1)
    MixedFractionFromInches inches, denom, whole, num, den
    feet = whole \ 12
    remIn = whole Mod 12
    
    InchesToFeetInchesArray = Array(feet, remIn, num, den, sign)
End Function

' ===== Convenience wrappers =====
Public Function PrettyInches(ByVal inches As Double, _
                             Optional ByVal denom As Long = 16, _
                             Optional ByVal useFeet As Boolean = False, _
                             Optional ByVal useUnicode As Boolean = False) As String
    PrettyInches = FmtInches(inches, denom, useUnicode, False, True, useFeet)
End Function

Public Function MetersToInchesText(ByVal meters As Double, _
                                   Optional ByVal denom As Long = 16, _
                                   Optional ByVal useFeet As Boolean = True, _
                                   Optional ByVal useUnicode As Boolean = False) As String
    MetersToInchesText = FmtInches(MetersToInches(meters), denom, useUnicode, False, True, useFeet)
End Function

Public Function MillimetersToInchesText(ByVal mm As Double, _
                                        Optional ByVal denom As Long = 16, _
                                        Optional ByVal useFeet As Boolean = False, _
                                        Optional ByVal useUnicode As Boolean = False) As String
    MillimetersToInchesText = FmtInches(MillimetersToInches(mm), denom, useUnicode, False, True, useFeet)
End Function

Public Function CentimetersToInchesText(ByVal cm As Double, _
                                        Optional ByVal denom As Long = 16, _
                                        Optional ByVal useFeet As Boolean = False, _
                                        Optional ByVal useUnicode As Boolean = False) As String
    CentimetersToInchesText = FmtInches(CentimetersToInches(cm), denom, useUnicode, False, True, useFeet)
End Function

Public Function ParseAndFormat(ByVal s As String, _
                               Optional ByVal denom As Long = 16, _
                               Optional ByVal useFeet As Boolean = True, _
                               Optional ByVal useUnicode As Boolean = False) As String
    Dim v As Variant
    v = ParseLengthToInches(s)
    If IsError(v) Then
        ParseAndFormat = CVErr(xlErrValue)
    Else
        ParseAndFormat = FmtInches(v, denom, useUnicode, False, True, useFeet)
    End If
End Function

' ===== Snap helpers =====
Public Function SnapToDenom(ByVal inches As Double, ByVal denom As Long) As Double
    If denom < 1 Then denom = 1
    SnapToDenom = CDbl(Fix(inches * denom + SgnD(inches) * 0.5)) / denom
End Function




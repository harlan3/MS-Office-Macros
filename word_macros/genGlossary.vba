Option Explicit

Sub genGlossary()

Application.ScreenUpdating = False
 ' This macro checks the contents of a document for expressions bounded by double-quotes.
 ' These terms are then tallied and their page references output to a table at the end
 ' of the document, showing the page #s on which they occur.
 ' The number of columns for the table is determined by the lCol variable.
 ' Optional code where the output table is created allows the user to choose
 ' between an across then down or down the across table layout.
Dim Doc As Document, Rng As Range, Tbl As Table
Dim StrTerms As String, strFnd As String, StrPages As String
Dim StrOut As String, StrBreak As String, StrBkMk As String
Dim i As Long, j As Long, lCol As Long
StrPages = "": lCol = 2: StrBkMk = "_Defined_Terms": StrPages = "": StrTerms = vbCr
Set Doc = ActiveDocument
'Go through the document looking for defined terms.
With Doc.Content
  'Check whether our table exists. If so, delete it.
  If .Bookmarks.Exists(StrBkMk) Then .Bookmarks(StrBkMk).Range.Tables(1).Delete
  With .Find
    .ClearFormatting
    .Replacement.ClearFormatting
    'Ensure all double quotes are properly formatted,
    'assuming that 'smart quotes' are in use.
    .Text = "[" & ChrW(8220) & Chr(147) & Chr(34) & Chr(148) & ChrW(8221) & "]"
    .Replacement.Text = """"
    .Format = False
    .Wrap = wdFindStop
    .MatchWholeWord = True
    .MatchWildcards = True
    .MatchCase = False
    .Execute Replace:=wdReplaceAll
    'Find terms between matched pairs of double quotes,
    'assuming that 'smart quotes' are in use.
    .Text = "[" & ChrW(8220) & Chr(147) & "]*[" & Chr(148) & ChrW(8221) & "]"
    .Execute
  End With
  Do While .Find.Found
    Set Rng = .Duplicate
    With Rng
      'If it's not in the StrTerms list, add it.
      If InStr(StrTerms, vbCr & .Text & vbCr) = 0 Then StrTerms = StrTerms & .Text & vbCr
    End With
    .Find.Execute
  Loop
End With
'Exit if no defined terms have been found.
If StrTerms = vbCr Then
  MsgBox "No defined terms found." & vbCr & "Aborting.", vbExclamation, "Defined Terms Error"
  GoTo ErrExit
End If
'Sort the key terms
Set Rng = ActiveDocument.Range.Characters.Last
With Rng
  .Collapse wdCollapseEnd
  .InsertBefore vbCr
  .InsertAfter StrTerms
  .Sort ExcludeHeader:=True, FieldNumber:=1, SortFieldType:=wdSortFieldAlphanumeric, _
    SortOrder:=wdSortOrderAscending
  StrTerms = .Text
  .Text = vbNullString
End With
While Left(StrTerms, 1) = vbCr
  StrTerms = Mid(StrTerms, 2, Len(StrTerms) - 1)
Wend
'Build the page records for all terms in the StrTerms list.
For i = 0 To UBound(Split(StrTerms, vbCr)) - 1
  strFnd = Trim(Split(StrTerms, vbCr)(i))
  StrPages = ""
  With Doc.Content
    With .Find
      .ClearFormatting
      .Replacement.ClearFormatting
      .Format = False
      .Text = strFnd
      .Wrap = wdFindStop
      .MatchWholeWord = True
      .MatchWildcards = False
      .MatchCase = True
      .Execute
    End With
    j = 0
    Do While .Find.Found
      'If we haven't already found this term on this page, add it to the list.
      If j <> .Duplicate.Information(wdActiveEndAdjustedPageNumber) Then
        j = .Duplicate.Information(wdActiveEndAdjustedPageNumber)
        StrPages = StrPages & j & " "
      End If
      .Find.Execute
    Loop
    'Turn the pages list into a comma-separated string.
    StrPages = Replace(Trim(StrPages), " ", ",")
    If StrPages <> "" Then
      'Add the current record to the output list (StrOut)
      StrOut = StrOut & strFnd & vbTab & Replace(Replace(ParseNumSeq(StrPages, "&"), ",", ", "), "  ", " ") & vbCr
    End If
  End With
Next i
'Strip off the double quotes
StrOut = Replace(Replace(StrOut, "�", ""), "�", "")
'Output the found terms as a table at the end of the document.
With Rng
  'Calculate the number of table lines for the data.
  j = -Int((UBound(Split(StrOut, vbCr))) / -lCol)
  Set Tbl = ActiveDocument.Tables.Add(Range:=Rng, NumRows:=j + 1, NumColumns:=lCol)
  With Tbl
    'Define the overall table layout.
    With .Range.ParagraphFormat
      .RightIndent = CentimetersToPoints(5 / lCol)
      With .TabStops
        .ClearAll
        .Add Position:=CentimetersToPoints(15 / lCol), Alignment:=wdAlignTabRight, Leader:=wdTabLeaderDots
      End With
    End With
    'Populate & format the header row.
    For i = 1 To lCol
      With .Cell(1, i).Range
        .Text = "Term" & vbTab & "Pages"
        .ParagraphFormat.KeepWithNext = True
      End With
    Next
    With .Rows.First
      'Apply the heading row attribute so that the table header repeats after a page break.
      .HeadingFormat = True
      'Delete the header row's tab leaders.
      With .Range
        With .ParagraphFormat.TabStops
          .ClearAll
          .Add Position:=CentimetersToPoints(15 / lCol), Alignment:=wdAlignTabRight, Leader:=wdTabLeaderSpaces
        End With
        .Font.Bold = True
      End With
    End With
     For i = 0 To UBound(Split(StrOut, vbCr)) - 1
      ' Populate the data rows, down then across
      .Cell(i Mod j + 2, -Int(-(i + 1) / j)).Range.Text = Split(StrOut, vbCr)(i)
      ' Populate the data rows, across then down
       '.Range.Cells(i + lCol + 1).Range.Text = Split(StrOut, vbCr)(i)
     Next
    'Bookmark the table.
    ActiveDocument.Bookmarks.Add Name:=StrBkMk, Range:=Tbl.Range
  End With
End With
'Clean up and exit.
ErrExit:
Set Rng = Nothing: Set Tbl = Nothing: Set Doc = Nothing
Application.ScreenUpdating = True
End Sub

Function ParseNumSeq(StrNums As String, Optional StrEnd As String)
 ' This function converts multiple sequences of 3 or more consecutive numbers in a
 ' list to a string consisting of the first & last numbers separated by a hyphen.
 ' The separator for the last sequence can be set via the StrEnd variable.
Dim ArrTmp(), i As Integer, j As Integer, k As Integer
ReDim ArrTmp(UBound(Split(StrNums, ",")))
For i = 0 To UBound(Split(StrNums, ","))
  ArrTmp(i) = Split(StrNums, ",")(i)
Next
For i = 0 To UBound(ArrTmp) - 1
  If IsNumeric(ArrTmp(i)) Then
    k = 2
    For j = i + 2 To UBound(ArrTmp)
      If CInt(ArrTmp(i) + k) <> CInt(ArrTmp(j)) Then Exit For
      ArrTmp(j - 1) = ""
      k = k + 1
    Next
    i = j - 2
  End If
Next
StrNums = Join(ArrTmp, ",")
StrNums = Replace(Replace(Replace(StrNums, ",,", " "), ", ", " "), " ,", " ")
While InStr(StrNums, "  ")
  StrNums = Replace(StrNums, "  ", " ")
Wend
StrNums = Replace(Replace(StrNums, " ", "-"), ",", ", ")
If StrEnd <> "" Then
  i = InStrRev(StrNums, ",")
  If i > 0 Then
    StrNums = Left(StrNums, i - 1) & Replace(StrNums, ",", " " & Trim(StrEnd), i)
  End If
End If
ParseNumSeq = StrNums
End Function


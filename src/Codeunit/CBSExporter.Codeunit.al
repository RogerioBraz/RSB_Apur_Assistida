namespace RSB.ApurAssistida.CBS;

using System.Utilities;

/// <summary>
/// Exports the reconciliation result and the coverage report (RF12) to CSV - a simple,
/// portable text format that Excel opens natively and that does not depend on any
/// spreadsheet API specific to the installed version.
/// </summary>
codeunit 50140 "CBS Exporter"
{
    Access = Internal;

    /// <summary>Generates the CSV of the current reconciliation result (last evaluation of each debt).</summary>
    procedure ExportReconciliationCsv(var TempBlob: Codeunit "Temp Blob")
    var
        Reconciliation: Record "CBS Reconciliation";
        Debt: Record "CBS Debt";
        OutStr: OutStream;
    begin
        TempBlob.CreateOutStream(OutStr);
        WriteLine(OutStr, 'Access Key;Classification;CBS Assessed;CBS Declared;Difference;Reason;Evaluated On');
        if Reconciliation.FindSet() then
            repeat
                WriteLine(OutStr, StrSubstNo('%1;%2;%3;%4;%5;%6;%7',
                    Reconciliation."Access Key",
                    Format(Reconciliation.Classification),
                    Format(CbsAssessedOfDebt(Debt, Reconciliation."Debt Entry No")),
                    Format(Reconciliation."CBS Declared Total"),
                    Format(Reconciliation.Difference),
                    Reconciliation.Reason,
                    Format(Reconciliation."Evaluated On")));
            until Reconciliation.Next() = 0;
    end;

    /// <summary>Generates the coverage report (gaps by period) in CSV.</summary>
    procedure ExportCoverageCsv(var TempBlob: Codeunit "Temp Blob")
    var
        Coverage: Record "CBS Coverage";
        OutStr: OutStream;
    begin
        TempBlob.CreateOutStream(OutStr);
        WriteLine(OutStr, 'Environment;Service;Period;Last Query;Debts Imported;Gap;Reason');
        if Coverage.FindSet() then
            repeat
                WriteLine(OutStr, StrSubstNo('%1;%2;%3;%4;%5;%6;%7',
                    Format(Coverage.Environment),
                    Format(Coverage.Service),
                    Format(Coverage.Period, 0, '<Month,2>/<Year4>'),
                    Format(Coverage."Query Completed On"),
                    Coverage."Debts Imported",
                    Format(Coverage.Gap),
                    Coverage.Reason));
            until Coverage.Next() = 0;
        Coverage.ModifyAll("Report Generated On", CurrentDateTime());
    end;

    local procedure CbsAssessedOfDebt(var Debt: Record "CBS Debt"; EntryNo: Integer): Decimal
    begin
        if EntryNo = 0 then
            exit(0);
        if Debt.Get(EntryNo) then
            exit(Debt."CBS Assessed");
        exit(0);
    end;

    local procedure WriteLine(var OutStr: OutStream; Line: Text)
    begin
        OutStr.WriteText(Line);
        OutStr.WriteText();
    end;
}

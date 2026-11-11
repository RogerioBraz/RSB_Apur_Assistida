namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Maintenance routines that the specification requires but that are not part of the
/// collection cycle: purge of the original JSON after the retention window (RN09 / 5.7) and
/// rebuild of the coverage ledger by period (7.4 / RF06).
///
/// Both are safe to run any number of times and never touch published debts.
/// </summary>
codeunit 50141 "CBS Maintenance"
{
    Access = Internal;

    var
        Telemetry: Codeunit "CBS Telemetry";

    /// <summary>
    /// Purges the content of CBS File records older than "JSON Retention Days" of CBS Setup.
    /// The row and its hash are kept (so idempotency and audit trail survive); only the blob
    /// holding the fiscal JSON is cleared. Returns the number of files purged.
    /// </summary>
    procedure PurgeExpiredFiles(): Integer
    var
        Setup: Record "CBS Setup";
        CBSFile: Record "CBS File";
        Cutoff: DateTime;
        PurgedCount: Integer;
    begin
        Setup.GetSetup(Setup);
        if Setup."JSON Retention Days" <= 0 then
            exit(0);

        Cutoff := CurrentDateTime() - (Setup."JSON Retention Days" * 86400000);
        CBSFile.SetRange("Received On", 0DT, Cutoff);
        CBSFile.SetFilter("Storage Kind", '%1', CBSFile."Storage Kind"::Blob);
        if CBSFile.FindSet(true) then
            repeat
                Clear(CBSFile.Content);
                CBSFile."Storage Kind" := CBSFile."Storage Kind"::Purged;
                CBSFile.Modify(true);
                PurgedCount += 1;
            until CBSFile.Next() = 0;

        if PurgedCount > 0 then
            Telemetry.ImportEvent('PURGE', StrSubstNo(PurgedMsg, PurgedCount));
        exit(PurgedCount);
    end;

    /// <summary>
    /// Rebuilds the coverage ledger from the published requests: for every period found in
    /// the published debts, records when it was last collected and how many debts it holds.
    /// Periods with published debts but no completed request become a gap.
    /// </summary>
    procedure RebuildCoverage(): Integer
    var
        Setup: Record "CBS Setup";
        Debt: Record "CBS Debt";
        Coverage: Record "CBS Coverage";
        Request: Record "CBS Request";
        Periods: Record "CBS Debt" temporary;
        PeriodValue: Date;
        RowsWritten: Integer;
        DebtCount: Integer;
        LastQuery: DateTime;
    begin
        Setup.GetSetup(Setup);

        Periods.Reset();
        Periods.SetRange(Published, true);
        Periods.SetRange(Environment, Setup.Environment);
        if Periods.FindSet() then
            repeat
                if Periods.Period <> PeriodValue then begin
                    PeriodValue := Periods.Period;

                    Debt.SetRange(Published, true);
                    Debt.SetRange(Environment, Setup.Environment);
                    Debt.SetRange(Period, PeriodValue);
                    DebtCount := Debt.Count();

                    LastQuery := LastCompletedRequest(Setup.Environment);

                    Coverage.Reset();
                    Coverage.SetRange(Environment, Setup.Environment);
                    Coverage.SetRange(Service, Setup."Active Service");
                    Coverage.SetRange(Period, PeriodValue);
                    if not Coverage.Find() then begin
                        Coverage.Init();
                        Coverage.Environment := Setup.Environment;
                        Coverage.Service := Setup."Active Service";
                        Coverage.Period := PeriodValue;
                    end;
                    Coverage."Query Completed On" := LastQuery;
                    Coverage."Debts Imported" := DebtCount;
                    Coverage.Gap := LastQuery = 0DT;
                    if Coverage.Gap then
                        Coverage.Reason := NoQueryMsg
                    else
                        Coverage.Reason := '';
                    if Coverage.Insert(true) then;
                    if Coverage.Modify(true) then;
                    RowsWritten += 1;
                end;
            until Periods.Next() = 0;

        exit(RowsWritten);
    end;

    /// <summary>Timestamp of the last request that reached Published for the environment.</summary>
    local procedure LastCompletedRequest(Environment: Enum "CBS Environment Type"): DateTime
    var
        Request: Record "CBS Request";
    begin
        Request.SetRange(Environment, Environment);
        Request.SetRange("Local State", Request."Local State"::Published);
        Request.SetLoadFields("Updated On");
        if Request.FindLast() then
            exit(Request."Updated On");
        exit(0DT);
    end;

    var
        PurgedMsg: Label 'Purged the original JSON of %1 expired file(s).', Comment = '%1 = number of files purged';
        NoQueryMsg: Label 'No collection completed for this environment yet.';
}

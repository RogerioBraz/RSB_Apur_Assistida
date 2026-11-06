namespace RSB.ApurAssistida.CBS;

using System.Threading;

/// <summary>
/// Single entry point called by the Job Queue (Job Queue Entry: Object Type = Codeunit,
/// Object ID = 50138). Each cycle: processes pending requests (one at a time, isolated by
/// TryFunction so that one failure does not block the others) and, if there is no opening in
/// progress and the daily quota allows it, creates a new request (RF01/4.3).
/// </summary>
codeunit 50138 "CBS Job Queue Dispatcher"
{
    Access = Internal;
    TableNo = "Job Queue Entry";

    var
        Telemetry: Codeunit "CBS Telemetry";
        QuotaReachedMsg: Label 'Daily opening quota reached; waiting for the next day.';

    trigger OnRun()
    begin
        RunCycle();
    end;

    procedure RunCycle()
    var
        Setup: Record "CBS Setup";
        Request: Record "CBS Request";
    begin
        Setup.GetSetup(Setup);
        if Setup.Blocked then
            exit;

        Request.SetFilter(
            "Local State", '%1|%2|%3|%4|%5',
            Request."Local State"::Open,
            Request."Local State"::WaitingProcessing,
            Request."Local State"::FileAvailable,
            Request."Local State"::FileSaved,
            Request."Local State"::TransientError);
        Request.SetFilter("Next Execution", '<=%1', CurrentDateTime());
        if Request.FindSet() then
            repeat
                RunIsolated(Request);
            until Request.Next() = 0;

        OpenNewRequestIfNeeded(Setup);
    end;

    local procedure RunIsolated(var Request: Record "CBS Request")
    begin
        if not TryRun(Request) then begin
            Telemetry.ErrorEvent("CBS Log Category"::Collection, Format(Request."Entry No"), CopyStr(GetLastErrorText(), 1, 250));
            Request.Get(Request."Entry No");
            Request."Local State" := Request."Local State"::TransientError;
            Request."Next Execution" := CurrentDateTime() + 600000;
            Request.Modify();
        end;
    end;

    [TryFunction]
    local procedure TryRun(var Request: Record "CBS Request")
    var
        Orchestrator: Codeunit "CBS Collection Orchestrator";
    begin
        Orchestrator.RunCycle(Request);
    end;

    local procedure OpenNewRequestIfNeeded(Setup: Record "CBS Setup")
    var
        Request: Record "CBS Request";
        NewRequest: Record "CBS Request";
    begin
        if Setup."Base CNPJ" = '' then
            exit; // incomplete configuration: nothing to open yet

        Request.SetRange(Service, Setup."Active Service");
        Request.SetRange(Environment, Setup.Environment);
        Request.SetFilter(
            "Local State", '%1|%2|%3|%4',
            Request."Local State"::Open,
            Request."Local State"::WaitingProcessing,
            Request."Local State"::FileAvailable,
            Request."Local State"::FileSaved);
        if not Request.IsEmpty() then
            exit; // an opening is already in progress (RF01/4.3): do not open another

        if CountOpeningsToday(Setup.Environment, Setup."Active Service") >= Setup."Daily Opening Quota" then begin
            Telemetry.WarningEvent("CBS Log Category"::Collection, '', QuotaReachedMsg);
            exit;
        end;

        NewRequest.Init();
        NewRequest.Service := Setup."Active Service";
        NewRequest.Environment := Setup.Environment;
        NewRequest."Base CNPJ" := Setup."Base CNPJ";
        NewRequest."Local State" := NewRequest."Local State"::Open;
        NewRequest."Next Execution" := CurrentDateTime();
        NewRequest.Insert(true);
        Telemetry.CollectionEvent(Format(NewRequest."Entry No"), 'New collection request created.');
    end;

    local procedure CountOpeningsToday(Environment: Enum "CBS Environment Type"; Service: Enum "CBS Service"): Integer
    var
        Request: Record "CBS Request";
    begin
        Request.SetRange(Environment, Environment);
        Request.SetRange(Service, Service);
        Request.SetFilter("Created On", '%1..%2', CreateDateTime(Today(), 0T), CreateDateTime(Today(), 235959T));
        exit(Request.Count());
    end;
}

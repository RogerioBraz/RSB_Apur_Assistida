namespace RSB.ApurAssistida.CBS;

using System.Utilities;

/// <summary>
/// State machine of a single collection request, executed on every Job Queue cycle (see
/// spec section 3.7/7.1/9.2). The HTTP connector is received as a parameter (Interface
/// ICbsHttpClient) to allow testing with "CBS Http Mock" without network access.
/// </summary>
codeunit 50137 "CBS Collection Orchestrator"
{
    Access = Internal;

    var
        Telemetry: Codeunit "CBS Telemetry";
        UncertainTimeoutMsg: Label 'Timeout or network failure on opening: uncertain state, waiting for intervention before retrying.';
        MaxTransientAttempts: Integer;

    /// <summary>Runs a cycle using the real HTTP connector.</summary>
    procedure RunCycle(var Request: Record "CBS Request")
    var
        RealConnector: Codeunit "CBS Tax Authority Connector";
        Connector: Interface "ICbsHttpClient";
    begin
        Connector := RealConnector;
        RunCycleWithConnector(Request, Connector);
    end;

    /// <summary>Runs a cycle using the given connector (production or test mock).</summary>
    procedure RunCycleWithConnector(var Request: Record "CBS Request"; Connector: Interface "ICbsHttpClient")
    var
        Credential: Record "CBS Credential";
    begin
        if MaxTransientAttempts = 0 then
            MaxTransientAttempts := 5;

        if not GetCredential(Request.Environment, Credential) then begin
            SetDefinitiveError(Request, CredentialNotFoundErr);
            exit;
        end;

        case Request."Local State" of
            Request."Local State"::Open:
                Open(Request, Credential, Connector);
            Request."Local State"::WaitingProcessing:
                GetStatus(Request, Credential, Connector);
            Request."Local State"::FileAvailable:
                DownloadAndProcess(Request, Credential, Connector);
            Request."Local State"::FileSaved:
                PublishSavedFile(Request);
            Request."Local State"::TransientError:
                Resume(Request, Credential, Connector);
        end;
    end;

    local procedure Open(var Request: Record "CBS Request"; Credential: Record "CBS Credential"; Connector: Interface "ICbsHttpClient")
    var
        Ticket: Text[100];
        WaitTimeSeconds: Integer;
        ErrorMessage: Text[250];
    begin
        if Connector.OpenRequest(Credential, Request."Base CNPJ", Request.Service, Ticket, WaitTimeSeconds, ErrorMessage) then begin
            Request.Ticket := Ticket;
            Request."Wait Time Seconds" := WaitTimeSeconds;
            Request."Local State" := Request."Local State"::WaitingProcessing;
            Request."Remote State" := Request."Remote State"::Pending;
            Request.Attempts := 0;
            Request."Next Execution" := CurrentDateTime() + NextWaitMs(WaitTimeSeconds);
            Request.Modify();
            Telemetry.CollectionEvent(Format(Request."Entry No"), 'Request opened successfully.');
        end else begin
            // A timeout/network failure on the opening POST is an UNCERTAIN STATE (section
            // 4.3): do not retry automatically - it stays in TransientError waiting for the
            // operator to decide, but with a longer delay before the next cycle touches it
            // again.
            Request."Remote State Detail" := CopyStr(UncertainTimeoutMsg + ' ' + ErrorMessage, 1, 250);
            Request."Local State" := Request."Local State"::TransientError;
            Request."Next Execution" := CurrentDateTime() + 600000; // 10 minutes
            Request.Modify();
            Telemetry.ErrorEvent("CBS Log Category"::Collection, Format(Request."Entry No"), ErrorMessage);
        end;
    end;

    local procedure GetStatus(var Request: Record "CBS Request"; Credential: Record "CBS Credential"; Connector: Interface "ICbsHttpClient")
    var
        RemoteState: Enum "CBS Remote State";
        ErrorCode: Text[20];
        ErrorMessage: Text[250];
    begin
        Request.TestField(Ticket);
        if not Connector.GetRequestStatus(Credential, Request.Ticket, RemoteState, ErrorCode, ErrorMessage) then begin
            SetTransientError(Request, ErrorMessage);
            exit;
        end;

        Request."Remote State" := RemoteState;
        Request."Remote State Detail" := CopyStr(StrSubstNo('%1 %2', ErrorCode, ErrorMessage).Trim(), 1, 250);

        case RemoteState of
            RemoteState::Completed:
                Request."Local State" := Request."Local State"::FileAvailable;
            RemoteState::Processing, RemoteState::Pending:
                Request."Next Execution" := CurrentDateTime() + NextWaitMs(Request."Wait Time Seconds");
            RemoteState::Error:
                begin
                    Request."Local State" := Request."Local State"::TransientError;
                    Request."Next Execution" := CurrentDateTime() + 600000;
                end;
            RemoteState::Expired:
                Request."Local State" := Request."Local State"::ExpiredProcessing;
            else
                Request."Next Execution" := CurrentDateTime() + NextWaitMs(Request."Wait Time Seconds");
        end;
        Request.Modify();
    end;

    local procedure DownloadAndProcess(var Request: Record "CBS Request"; Credential: Record "CBS Credential"; Connector: Interface "ICbsHttpClient")
    var
        CBSFile: Record "CBS File";
        TempBlob: Codeunit "Temp Blob";
        SignedUrl: Text[2048];
        ExpiresOn: DateTime;
        ErrorMessage: Text[250];
        ContentInStream: InStream;
    begin
        if not Connector.GetDownloadLink(Credential, Request.Ticket, SignedUrl, ExpiresOn, ErrorMessage) then begin
            SetTransientError(Request, ErrorMessage);
            exit;
        end;
        Request."Url Expires On" := ExpiresOn;

        if not Connector.DownloadFile(SignedUrl, TempBlob, ErrorMessage) then begin
            SetTransientError(Request, ErrorMessage);
            exit;
        end;

        CBSFile.Init();
        CBSFile."Request Entry No" := Request."Entry No";
        CBSFile."Received On" := CurrentDateTime();
        CBSFile.Insert(true);
        TempBlob.CreateInStream(ContentInStream);
        CBSFile.SetContent(ContentInStream);
        CBSFile.Modify(true);

        Request."File Entry No" := CBSFile."Entry No";
        Request."File Hash" := CBSFile.Hash;
        Request."Local State" := Request."Local State"::FileSaved;
        Request.Modify();
        Telemetry.CollectionEvent(Format(Request."Entry No"), 'File downloaded and saved.');
    end;

    local procedure PublishSavedFile(var Request: Record "CBS Request")
    var
        CBSFile: Record "CBS File";
        Publisher: Codeunit "CBS Batch Publisher";
        BatchCode: Code[20];
    begin
        CBSFile.Get(Request."File Entry No");
        BatchCode := Publisher.PublishCollection(Request, CBSFile);

        CBSFile.Get(CBSFile."Entry No"); // re-read: Publisher may have updated Processed
        if CBSFile.Processed then begin
            Request."Local State" := Request."Local State"::Published;
            Request.Modify();
        end else begin
            // Publisher did not mark Processed: the import failed and was already logged by
            // the Publisher itself. Keep FileSaved to allow reprocessing (flow 7.2) after
            // diagnosis, without consuming quota again.
            SetTransientError(Request, StrSubstNo(PublishFailureErr, BatchCode));
        end;
    end;

    local procedure Resume(var Request: Record "CBS Request"; Credential: Record "CBS Credential"; Connector: Interface "ICbsHttpClient")
    begin
        if Request.Attempts >= MaxTransientAttempts then begin
            SetDefinitiveError(Request, TooManyAttemptsErr);
            exit;
        end;
        Request.Attempts += 1;
        // Resume from where it stopped: if there is already a ticket, go back to checking
        // the status; otherwise the opening was left uncertain and waits for manual
        // intervention (do not reopen automatically, to avoid duplicating the request at the
        // Revenue Service).
        if Request.Ticket <> '' then begin
            Request."Local State" := Request."Local State"::WaitingProcessing;
            Request.Modify();
            GetStatus(Request, Credential, Connector);
        end else
            Request.Modify();
    end;

    local procedure SetTransientError(var Request: Record "CBS Request"; Detail: Text[250])
    begin
        Request.Attempts += 1;
        Request."Local State" := Request."Local State"::TransientError;
        Request."Remote State Detail" := Detail;
        // Exponential backoff: 1, 2, 4, 8, 16 minutes (bounded by MaxTransientAttempts)
        Request."Next Execution" := CurrentDateTime() + (60000 * Power(2, Request.Attempts - 1));
        Request.Modify();
        Telemetry.ErrorEvent("CBS Log Category"::Collection, Format(Request."Entry No"), Detail);
    end;

    local procedure SetDefinitiveError(var Request: Record "CBS Request"; Detail: Text[250])
    begin
        Request."Local State" := Request."Local State"::DefinitiveError;
        Request."Remote State Detail" := Detail;
        Request.Modify();
        Telemetry.ErrorEvent("CBS Log Category"::Collection, Format(Request."Entry No"), Detail);
    end;

    local procedure GetCredential(Environment: Enum "CBS Environment Type"; var Credential: Record "CBS Credential"): Boolean
    begin
        Credential.SetRange(Environment, Environment);
        Credential.SetRange(Active, true);
        exit(Credential.FindFirst());
    end;

    local procedure NextWaitMs(WaitTimeSeconds: Integer): BigInteger
    begin
        if WaitTimeSeconds <= 0 then
            WaitTimeSeconds := 60;
        exit(WaitTimeSeconds * 1000);
    end;

    var
        CredentialNotFoundErr: Label 'No active credential found for the environment of this request.';
        TooManyAttemptsErr: Label 'Maximum number of attempts in transient error exceeded.';
        PublishFailureErr: Label 'Failed to publish batch %1; see CBS Log Entry for details.', Comment = '%1 = batch code';
}

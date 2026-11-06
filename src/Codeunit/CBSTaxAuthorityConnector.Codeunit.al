namespace RSB.ApurAssistida.CBS;

using System.Utilities;

/// <summary>
/// Real implementation of ICbsHttpClient using HttpClient. The token always flows as
/// SecretText (never materialized as Text) and the client secret is read directly from
/// Isolated Storage via CBS Credential.GetClientSecret - never from a table field. No error
/// message or telemetry event ever includes a token, secret or response body that could
/// contain sensitive tax data (RN03/ADR-08 of the specification).
/// </summary>
codeunit 50133 "CBS Tax Authority Connector" implements "ICbsHttpClient"
{
    Access = Internal;

    var
        UrlHelper: Codeunit "CBS Url Helper";
        Telemetry: Codeunit "CBS Telemetry";

    procedure GetToken(Credential: Record "CBS Credential"; var Token: SecretText; var ExpiresOn: DateTime; var ErrorMessage: Text[250]): Boolean
    var
        Client: HttpClient;
        Req: HttpRequestMessage;
        Resp: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        Secret: SecretText;
        EncodedClientId: SecretText;
        EncodedScope: SecretText;
        Body: SecretText;
        ResponseText: Text;
        Json: JsonObject;
        AccessTokenTok: JsonToken;
        ExpiresInTok: JsonToken;
        ExpiresInSec: Integer;
    begin
        if Credential."Token Url" = '' then begin
            ErrorMessage := TokenUrlNotConfiguredErr;
            exit(false);
        end;
        if not Credential.GetClientSecret(Secret) then begin
            ErrorMessage := SecretNotConfiguredErr;
            exit(false);
        end;

        // SecretStrSubstNo requires every variadic argument to be SecretText; the
        // non-sensitive parts (encoded client_id and scope) are implicitly converted to
        // SecretText only to satisfy the signature - the secret itself (Secret) never passes
        // through a Text variable.
        EncodedClientId := UrlHelper.UriEncodeForm(Credential."Client Id");
        EncodedScope := UrlHelper.UriEncodeForm(Credential.Scope);
        Body := SecretStrSubstNo('grant_type=client_credentials&client_id=%1&client_secret=%2&scope=%3',
            EncodedClientId, Secret, EncodedScope);
        // The body is written directly from the SecretText: WriteFrom(SecretText) exists
        // exactly for this scenario and avoids the secret ever passing through a Text
        // variable (Unwrap() is not allowed in SaaS extensions).
        Content.WriteFrom(Body);
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/x-www-form-urlencoded');

        Req.Method('POST');
        Req.SetRequestUri(Credential."Token Url");
        Req.Content(Content);

        if not Client.Send(Req, Resp) then begin
            ErrorMessage := NetworkFailureErr;
            exit(false);
        end;
        if not Resp.IsSuccessStatusCode() then begin
            Telemetry.ErrorEvent("CBS Log Category"::Security, Credential."Code", StrSubstNo(TokenHttpErrTxt, Resp.HttpStatusCode()));
            ErrorMessage := CopyStr(StrSubstNo(TokenHttpErrTxt, Resp.HttpStatusCode()), 1, 250);
            exit(false);
        end;

        Resp.Content().ReadAs(ResponseText);
        if not Json.ReadFrom(ResponseText) then begin
            ErrorMessage := InvalidResponseErr;
            exit(false);
        end;
        if not Json.Get('access_token', AccessTokenTok) then begin
            ErrorMessage := InvalidResponseErr;
            exit(false);
        end;
        Token := AccessTokenTok.AsValue().AsText();

        ExpiresInSec := 3600;
        if Json.Get('expires_in', ExpiresInTok) then
            ExpiresInSec := ExpiresInTok.AsValue().AsInteger();
        ExpiresOn := CurrentDateTime() + (ExpiresInSec * 1000);
        exit(true);
    end;

    procedure OpenRequest(Credential: Record "CBS Credential"; BaseCnpj: Text[8]; Service: Enum "CBS Service"; var Ticket: Text[100]; var WaitTimeSeconds: Integer; var ErrorMessage: Text[250]): Boolean
    var
        Client: HttpClient;
        Req: HttpRequestMessage;
        Resp: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        ReqHeaders: HttpHeaders;
        Token: SecretText;
        ExpiresOn: DateTime;
        Url: Text;
        ResponseText: Text;
        Json: JsonObject;
        TicketTok: JsonToken;
        WaitTok: JsonToken;
    begin
        if not GetToken(Credential, Token, ExpiresOn, ErrorMessage) then
            exit(false);

        Url := UrlHelper.BaseUrl(Credential.Environment) + '/' + ServicePath(Service) + '/' + UrlHelper.NormalizeBaseCnpj(BaseCnpj);

        Content.WriteFrom('{"urlRetorno":""}');
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        Req.Method('POST');
        Req.SetRequestUri(Url);
        Req.Content(Content);
        Req.GetHeaders(ReqHeaders);
        ReqHeaders.Add('Authorization', SecretStrSubstNo('******', Token));

        if not Client.Send(Req, Resp) then begin
            // A timeout/network failure on the opening POST is an UNCERTAIN STATE (spec
            // section 4.3): the caller must not automatically retry the opening.
            ErrorMessage := NetworkFailureOpeningErr;
            exit(false);
        end;

        if not Resp.IsSuccessStatusCode() then begin
            ErrorMessage := MapHttpError(Resp.HttpStatusCode());
            exit(false);
        end;

        Resp.Content().ReadAs(ResponseText);
        if not Json.ReadFrom(ResponseText) then begin
            ErrorMessage := InvalidResponseErr;
            exit(false);
        end;
        if not Json.Get('tiqueteSolicitacao', TicketTok) then begin
            ErrorMessage := InvalidResponseErr;
            exit(false);
        end;
        Ticket := CopyStr(TicketTok.AsValue().AsText(), 1, 100);

        WaitTimeSeconds := 0;
        if Json.Get('tEASegundos', WaitTok) then
            WaitTimeSeconds := WaitTok.AsValue().AsInteger();
        exit(true);
    end;

    procedure GetRequestStatus(Credential: Record "CBS Credential"; Ticket: Text[100]; var RemoteState: Enum "CBS Remote State"; var ErrorCode: Text[20]; var ErrorMessage: Text[250]): Boolean
    var
        Client: HttpClient;
        Req: HttpRequestMessage;
        Resp: HttpResponseMessage;
        ReqHeaders: HttpHeaders;
        Token: SecretText;
        ExpiresOn: DateTime;
        Url: Text;
        ResponseText: Text;
        Json: JsonObject;
        StatusTok: JsonToken;
        ErrCodeTok: JsonToken;
        ErrMsgTok: JsonToken;
        StatusTxt: Text;
        TempError: Text[250];
    begin
        if not GetToken(Credential, Token, ExpiresOn, TempError) then begin
            ErrorMessage := TempError;
            exit(false);
        end;

        Url := UrlHelper.BaseUrl(Credential.Environment) + '/situacao/' + Ticket;
        Req.Method('GET');
        Req.SetRequestUri(Url);
        Req.GetHeaders(ReqHeaders);
        ReqHeaders.Add('Authorization', SecretStrSubstNo('******', Token));

        if not Client.Send(Req, Resp) then begin
            ErrorMessage := NetworkFailureErr;
            exit(false);
        end;
        if not Resp.IsSuccessStatusCode() then begin
            ErrorMessage := MapHttpError(Resp.HttpStatusCode());
            exit(false);
        end;

        Resp.Content().ReadAs(ResponseText);
        if not Json.ReadFrom(ResponseText) then begin
            ErrorMessage := InvalidResponseErr;
            exit(false);
        end;
        if Json.Get('situacao', StatusTok) then begin
            StatusTxt := StatusTok.AsValue().AsText();
            RemoteState := MapRemoteState(StatusTxt);
        end;
        if Json.Get('codigoErro', ErrCodeTok) then
            ErrorCode := CopyStr(ErrCodeTok.AsValue().AsText(), 1, 20);
        if Json.Get('mensagemErro', ErrMsgTok) then
            ErrorMessage := CopyStr(ErrMsgTok.AsValue().AsText(), 1, 250);
        exit(true);
    end;

    procedure GetDownloadLink(Credential: Record "CBS Credential"; Ticket: Text[100]; var SignedUrl: Text[2048]; var ExpiresOn: DateTime; var ErrorMessage: Text[250]): Boolean
    var
        Client: HttpClient;
        Req: HttpRequestMessage;
        Resp: HttpResponseMessage;
        ReqHeaders: HttpHeaders;
        Token: SecretText;
        TokenExpiresOn: DateTime;
        Url: Text;
        ResponseText: Text;
        Json: JsonObject;
        UrlTok: JsonToken;
        ExpiresTok: JsonToken;
        TempError: Text[250];
    begin
        if not GetToken(Credential, Token, TokenExpiresOn, TempError) then begin
            ErrorMessage := TempError;
            exit(false);
        end;

        Url := UrlHelper.BaseUrl(Credential.Environment) + '/download/' + Ticket;
        Req.Method('GET');
        Req.SetRequestUri(Url);
        Req.GetHeaders(ReqHeaders);
        ReqHeaders.Add('Authorization', SecretStrSubstNo('******', Token));

        if not Client.Send(Req, Resp) then begin
            ErrorMessage := NetworkFailureErr;
            exit(false);
        end;
        if Resp.HttpStatusCode() = 404 then begin
            // Link not yet available; this is not a definitive error (spec section 4.3).
            ErrorMessage := FileNotYetAvailableErr;
            exit(false);
        end;
        if not Resp.IsSuccessStatusCode() then begin
            ErrorMessage := MapHttpError(Resp.HttpStatusCode());
            exit(false);
        end;

        Resp.Content().ReadAs(ResponseText);
        if not Json.ReadFrom(ResponseText) then begin
            ErrorMessage := InvalidResponseErr;
            exit(false);
        end;
        if not Json.Get('urlAssinada', UrlTok) then begin
            ErrorMessage := InvalidResponseErr;
            exit(false);
        end;
        SignedUrl := CopyStr(UrlTok.AsValue().AsText(), 1, 2048);

        if Json.Get('urlAssinadaExpiraEm', ExpiresTok) then
            // [VALIDATE] confirm the exact format of urlAssinadaExpiraEm with the Revenue
            // Service.
            Evaluate(ExpiresOn, ExpiresTok.AsValue().AsText());
        exit(true);
    end;

    procedure DownloadFile(SignedUrl: Text[2048]; var Content: Codeunit "Temp Blob"; var ErrorMessage: Text[250]): Boolean
    var
        Client: HttpClient;
        Req: HttpRequestMessage;
        Resp: HttpResponseMessage;
        RespIn: InStream;
        OutStr: OutStream;
    begin
        // GET on the signed URL: WITHOUT an Authorization header and WITHOUT any other
        // additional header - the URL itself is the access mechanism (spec section 2/6.5).
        Req.Method('GET');
        Req.SetRequestUri(SignedUrl);

        if not Client.Send(Req, Resp) then begin
            ErrorMessage := NetworkFailureErr;
            exit(false);
        end;
        if Resp.HttpStatusCode() = 403 then begin
            ErrorMessage := UrlExpiredErr;
            exit(false);
        end;
        if not Resp.IsSuccessStatusCode() then begin
            ErrorMessage := MapHttpError(Resp.HttpStatusCode());
            exit(false);
        end;

        Resp.Content().ReadAs(RespIn);
        Content.CreateOutStream(OutStr);
        CopyStream(OutStr, RespIn);
        exit(true);
    end;

    local procedure ServicePath(Service: Enum "CBS Service"): Text
    begin
        case Service of
            Service::Debts:
                exit('debitos');
            Service::Credits:
                exit('creditos');
            Service::Payments:
                exit('pagamentos');
            Service::Settlements:
                exit('recolhimentos');
        end;
    end;

    local procedure MapRemoteState(Status: Text): Enum "CBS Remote State"
    begin
        case UpperCase(Status) of
            'PENDENTE':
                exit("CBS Remote State"::Pending);
            'EM_PROCESSAMENTO':
                exit("CBS Remote State"::Processing);
            'CONCLUIDA':
                exit("CBS Remote State"::Completed);
            'ERRO':
                exit("CBS Remote State"::Error);
            'EXPIRADA':
                exit("CBS Remote State"::Expired);
            else
                exit("CBS Remote State"::Unknown);
        end;
    end;

    local procedure MapHttpError(StatusCode: Integer): Text[250]
    begin
        case StatusCode of
            400:
                exit(Http400Err);
            401:
                exit(Http401Err);
            403:
                exit(Http403Err);
            404:
                exit(Http404Err);
            422:
                exit(Http422Err);
            429:
                exit(Http429Err);
            else
                exit(CopyStr(StrSubstNo(HttpGenericErr, StatusCode), 1, 250));
        end;
    end;

    var
        TokenUrlNotConfiguredErr: Label 'Token URL not configured on the credential.';
        SecretNotConfiguredErr: Label 'Credential has no client secret configured.';
        NetworkFailureErr: Label 'Network failure while communicating with the Revenue Service.';
        NetworkFailureOpeningErr: Label 'Network failure while opening the request (uncertain state; do not retry automatically).';
        InvalidResponseErr: Label 'Revenue Service response in an unexpected format.';
        FileNotYetAvailableErr: Label 'File not yet available for download.';
        UrlExpiredErr: Label 'Signed URL expired or invalid.';
        TokenHttpErrTxt: Label 'Failed to issue token (HTTP %1).', Comment = '%1 = HTTP status code';
        Http400Err: Label 'Invalid request (HTTP 400).';
        Http401Err: Label 'Unauthorized: invalid credential or expired token (HTTP 401).';
        Http403Err: Label 'Access denied for the resource or environment (HTTP 403).';
        Http404Err: Label 'Resource not found (HTTP 404).';
        Http422Err: Label 'Data rejected by the Revenue Service (HTTP 422).';
        Http429Err: Label 'Request quota exceeded (HTTP 429).';
        HttpGenericErr: Label 'HTTP failure %1.', Comment = '%1 = HTTP status code';
}

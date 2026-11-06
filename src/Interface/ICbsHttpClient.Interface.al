namespace RSB.ApurAssistida.CBS;

using System.Utilities;

/// <summary>
/// Abstracts every HTTP call to the CBS Assisted Assessment API. It exists to allow
/// automated testing without network access: "CBS Http Mock" implements this interface with
/// configurable responses, so that the orchestrator and the importer can be tested in
/// isolation (see spec section 9).
/// </summary>
interface "ICbsHttpClient"
{
    Access = Internal;

    /// <summary>Gets a valid access token via OAuth2 Client Credentials.</summary>
    procedure GetToken(Credential: Record "CBS Credential"; var Token: SecretText; var ExpiresOn: DateTime; var ErrorMessage: Text[250]): Boolean

    /// <summary>Opens a collection request (POST) and returns the tracking ticket.</summary>
    procedure OpenRequest(Credential: Record "CBS Credential"; BaseCnpj: Text[8]; Service: Enum "CBS Service"; var Ticket: Text[100]; var WaitTimeSeconds: Integer; var ErrorMessage: Text[250]): Boolean

    /// <summary>Queries the current status of the ticket.</summary>
    procedure GetRequestStatus(Credential: Record "CBS Credential"; Ticket: Text[100]; var RemoteState: Enum "CBS Remote State"; var ErrorCode: Text[20]; var ErrorMessage: Text[250]): Boolean

    /// <summary>Gets the signed download URL, once the request has completed.</summary>
    procedure GetDownloadLink(Credential: Record "CBS Credential"; Ticket: Text[100]; var SignedUrl: Text[2048]; var ExpiresOn: DateTime; var ErrorMessage: Text[250]): Boolean

    /// <summary>
    /// Downloads the file at the signed URL (request WITHOUT an authentication header, since
    /// the URL itself is the access mechanism) and writes the content into the given
    /// TempBlob.
    /// </summary>
    procedure DownloadFile(SignedUrl: Text[2048]; var Content: Codeunit "Temp Blob"; var ErrorMessage: Text[250]): Boolean
}

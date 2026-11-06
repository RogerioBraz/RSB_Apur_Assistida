namespace RSB.ApurAssistida.CBS;

/// <summary>
/// OAuth2 Client Credentials used to access the Brazilian Revenue Service API. The client
/// secret is NEVER written to a table field: it lives in Isolated Storage, associated to
/// this record through an opaque, automatically generated key, and is only read as
/// SecretText at the moment of the HTTP call (see CBS Tax Authority Connector). This
/// satisfies RN03/ADR-08 of the specification (secret never in plain text, never logged).
/// </summary>
table 50101 "CBS Credential"
{
    Caption = 'CBS Credential';
    DataClassification = SystemMetadata;
    Access = Internal;
    DrillDownPageId = "CBS Credential List";
    LookupPageId = "CBS Credential List";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            DataClassification = SystemMetadata;
            NotBlank = true;
        }
        field(10; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = SystemMetadata;
        }
        field(11; Environment; Enum "CBS Environment Type")
        {
            Caption = 'Environment';
            DataClassification = SystemMetadata;
        }
        field(20; "Client Id"; Text[250])
        {
            Caption = 'Client Id';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(21; "Token Url"; Text[250])
        {
            Caption = 'Token Url';
            DataClassification = SystemMetadata;
            // [VALIDATE] Confirm the official token issuance URL (OAuth2 Client
            // Credentials) in the Receita Integra documentation before using in production.
        }
        field(22; Scope; Text[250])
        {
            Caption = 'Scope';
            DataClassification = SystemMetadata;
            // [VALIDATE] Confirm the scope required by the client_credentials flow at the
            // Revenue Service.
        }
        field(30; "Secret Storage Key"; Guid)
        {
            Caption = 'Secret Storage Key';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(40; Active; Boolean)
        {
            Caption = 'Active';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }

    trigger OnDelete()
    begin
        if not IsNullGuid("Secret Storage Key") then
            IsolatedStorage.Delete(Format("Secret Storage Key"), DataScope::Company);
    end;

    /// <summary>Sets (or replaces) the client secret, writing it only to Isolated Storage.</summary>
    procedure SetClientSecret(NewSecret: SecretText)
    begin
        if IsNullGuid("Secret Storage Key") then begin
            "Secret Storage Key" := CreateGuid();
            Modify();
        end;
        IsolatedStorage.Set(Format("Secret Storage Key"), NewSecret, DataScope::Company);
    end;

    /// <summary>Gets the client secret directly as SecretText, never materializing it as Text.</summary>
    procedure GetClientSecret(var Secret: SecretText): Boolean
    begin
        if IsNullGuid("Secret Storage Key") then
            exit(false);
        exit(IsolatedStorage.Get(Format("Secret Storage Key"), DataScope::Company, Secret));
    end;

    /// <summary>Indicates whether a secret is configured for this credential.</summary>
    procedure HasClientSecret(): Boolean
    begin
        if IsNullGuid("Secret Storage Key") then
            exit(false);
        exit(IsolatedStorage.Contains(Format("Secret Storage Key"), DataScope::Company));
    end;
}

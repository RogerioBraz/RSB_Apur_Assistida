namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Card for a single OAuth2 credential. The client secret is typed into a masked field that
/// is not bound to any table field: when the field loses focus, the value is written
/// directly to Isolated Storage via CBS Credential.SetClientSecret and the local variable is
/// discarded, following the same rule described on the table (secret never in plain text,
/// never logged).
/// </summary>
page 50160 "CBS Credential Card"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = 'CBS Credential';
    SourceTable = "CBS Credential";

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';

                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the code that identifies this credential.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a free-text description for this credential.';
                }
                field(Environment; Rec.Environment)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this credential is used in Production or Restricted Production (sandbox).';
                }
                field(Active; Rec.Active)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this credential can be selected in CBS Setup.';
                }
            }
            group(Authentication)
            {
                Caption = 'OAuth2 Authentication';

                field("Client Id"; Rec."Client Id")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Client Id of the application registered with the Revenue Service.';
                }
                field("Token Url"; Rec."Token Url")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the token issuance URL used in the OAuth2 Client Credentials flow.';
                }
                field(Scope; Rec.Scope)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the scope required by the client_credentials flow.';
                }
                field(ClientSecret; ClientSecretTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Client Secret';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies a new client secret. The typed value is written only to Isolated Storage and is never shown again.';

                    trigger OnValidate()
                    begin
                        if ClientSecretTxt <> '' then
                            Rec.SetClientSecret(ClientSecretTxt);
                        ClientSecretTxt := '';
                    end;
                }
                field(SecretConfigured; Rec.HasClientSecret())
                {
                    ApplicationArea = All;
                    Caption = 'Secret Configured';
                    Editable = false;
                    ToolTip = 'Specifies whether a client secret is already stored for this credential.';
                }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        ClientSecretTxt := '';
    end;

    var
        ClientSecretTxt: Text[250];
}

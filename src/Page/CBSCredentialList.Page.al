namespace RSB.ApurAssistida.CBS;

/// <summary>List of OAuth2 credentials per environment.</summary>
page 50159 "CBS Credential List"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'CBS Credentials';
    UsageCategory = Lists;
    SourceTable = "CBS Credential";
    CardPageId = "CBS Credential Card";

    layout
    {
        area(content)
        {
            repeater(Control)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field(Environment; Rec.Environment) { ApplicationArea = All; }
                field("Client Id"; Rec."Client Id") { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
                field(SecretConfigured; Rec.HasClientSecret())
                {
                    ApplicationArea = All;
                    Caption = 'Secret Configured';
                }
            }
        }
    }
}

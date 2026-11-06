namespace RSB.ApurAssistida.CBS;

/// <summary>List of collection cycles (requests) opened with the Revenue Service API.</summary>
page 50152 "CBS Request List"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'CBS Requests';
    UsageCategory = Lists;
    SourceTable = "CBS Request";
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Control)
            {
                field("Entry No"; Rec."Entry No") { ApplicationArea = All; }
                field(Service; Rec.Service) { ApplicationArea = All; }
                field(Environment; Rec.Environment) { ApplicationArea = All; }
                field("Base CNPJ"; Rec."Base CNPJ") { ApplicationArea = All; }
                field(Ticket; Rec.Ticket) { ApplicationArea = All; }
                field("Local State"; Rec."Local State") { ApplicationArea = All; }
                field("Remote State"; Rec."Remote State") { ApplicationArea = All; }
                field("Remote State Detail"; Rec."Remote State Detail") { ApplicationArea = All; }
                field(Attempts; Rec.Attempts) { ApplicationArea = All; }
                field("Next Execution"; Rec."Next Execution") { ApplicationArea = All; }
                field("Wait Time Seconds"; Rec."Wait Time Seconds") { ApplicationArea = All; }
                field("Url Expires On"; Rec."Url Expires On") { ApplicationArea = All; }
                field("File Entry No"; Rec."File Entry No") { ApplicationArea = All; }
                field("Created On"; Rec."Created On") { ApplicationArea = All; }
                field("Updated On"; Rec."Updated On") { ApplicationArea = All; }
            }
        }
    }
}

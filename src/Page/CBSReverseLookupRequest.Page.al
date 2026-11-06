namespace RSB.ApurAssistida.CBS;

/// <summary>Small input dialog used by the "Reverse Lookup" action to collect the issue date range to scan.</summary>
page 50100 "CBS Reverse Lookup Request"
{
    PageType = StandardDialog;
    Caption = 'Reverse Lookup';

    layout
    {
        area(content)
        {
            field(FromDateField; FromDate)
            {
                ApplicationArea = All;
                Caption = 'From Issue Date';
                ToolTip = 'Specifies the start of the issue date range to scan for notes without a matching CBS debt.';
            }
            field(ToDateField; ToDate)
            {
                ApplicationArea = All;
                Caption = 'To Issue Date';
                ToolTip = 'Specifies the end of the issue date range to scan for notes without a matching CBS debt.';
            }
        }
    }

    /// <summary>Sets the default date range shown when the dialog opens.</summary>
    procedure SetRange(NewFromDate: Date; NewToDate: Date)
    begin
        FromDate := NewFromDate;
        ToDate := NewToDate;
    end;

    /// <summary>Returns the date range confirmed by the user.</summary>
    procedure GetRange(var ResultFromDate: Date; var ResultToDate: Date)
    begin
        ResultFromDate := FromDate;
        ResultToDate := ToDate;
    end;

    var
        FromDate: Date;
        ToDate: Date;
}

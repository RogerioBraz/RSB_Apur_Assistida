namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Main configuration of the CBS Assisted Assessment. A single record per company: Business
/// Central already isolates data per company natively (each company has its own table), so
/// it is not necessary (nor correct) to include a Company field in the primary key. For this
/// same reason none of the other tables in this app store a Company field - a decision
/// applied consistently throughout the data model.
/// </summary>
table 50100 "CBS Setup"
{
    Caption = 'CBS Setup';
    DataClassification = SystemMetadata;
    Access = Internal;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; Environment; Enum "CBS Environment Type")
        {
            Caption = 'Environment';
            DataClassification = SystemMetadata;
        }
        field(11; "Base CNPJ"; Text[8])
        {
            Caption = 'Base CNPJ';
            DataClassification = EndUserIdentifiableInformation;

            trigger OnValidate()
            begin
                ValidateDigitsOnly("Base CNPJ", 8);
            end;
        }
        field(12; "Taxpayer CNPJ"; Text[14])
        {
            Caption = 'Taxpayer CNPJ';
            DataClassification = EndUserIdentifiableInformation;

            trigger OnValidate()
            begin
                if "Taxpayer CNPJ" <> '' then
                    ValidateDigitsOnly("Taxpayer CNPJ", 14);
            end;
        }
        field(20; "Credential Code"; Code[20])
        {
            Caption = 'Credential';
            TableRelation = "CBS Credential"."Code";
            DataClassification = SystemMetadata;
        }
        field(21; "Fiscal History Adapter"; Enum "CBS Fiscal History Adapter")
        {
            Caption = 'Fiscal History Adapter';
            DataClassification = SystemMetadata;
        }
        field(30; "Reconciliation Tolerance"; Decimal)
        {
            Caption = 'Reconciliation Tolerance';
            DataClassification = SystemMetadata;
            DecimalPlaces = 2 : 2;
            MinValue = 0;
        }
        field(31; "Starting Period"; Date)
        {
            Caption = 'Starting Period (Panel)';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if ("Ending Period" <> 0D) and ("Starting Period" > "Ending Period") then
                    FieldError("Starting Period", PeriodOutOfOrderErr);
            end;
        }
        field(32; "Ending Period"; Date)
        {
            Caption = 'Ending Period (Panel)';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if ("Starting Period" <> 0D) and ("Ending Period" < "Starting Period") then
                    FieldError("Ending Period", PeriodOutOfOrderErr);
            end;
        }
        field(40; "Incremental Window Days"; Integer)
        {
            Caption = 'Incremental Window (Days)';
            DataClassification = SystemMetadata;
            MinValue = 1;
            InitValue = 8;
        }
        field(41; "JSON Retention Days"; Integer)
        {
            Caption = 'Original JSON Retention (Days)';
            DataClassification = SystemMetadata;
            MinValue = 1;
            InitValue = 180;
        }
        field(42; "Daily Opening Quota"; Integer)
        {
            Caption = 'Daily Opening Quota';
            DataClassification = SystemMetadata;
            MinValue = 1;
            InitValue = 4;
        }
        field(50; Blocked; Boolean)
        {
            Caption = 'Collection Blocked';
            DataClassification = SystemMetadata;
        }
        field(51; "Active Service"; Enum "CBS Service")
        {
            Caption = 'Active Service';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        PeriodOutOfOrderErr: Label 'The starting period must be less than or equal to the ending period.';

    local procedure ValidateDigitsOnly(Value: Text; ExpectedLength: Integer)
    var
        CnpjLengthErr: Label 'Must contain exactly %1 numeric digits.', Comment = '%1 = expected number of digits';
        Character: Char;
        Index: Integer;
    begin
        if StrLen(Value) <> ExpectedLength then
            Error(CnpjLengthErr, ExpectedLength);
        for Index := 1 to StrLen(Value) do begin
            Character := Value[Index];
            if not (Character in ['0' .. '9']) then
                Error(CnpjLengthErr, ExpectedLength);
        end;
    end;

    /// <summary>Gets the (single) configuration record of the company, creating it if necessary.</summary>
    procedure GetSetup(var Setup: Record "CBS Setup")
    begin
        if Setup.Get('') then
            exit;
        Setup.Init();
        Setup.Insert();
    end;
}

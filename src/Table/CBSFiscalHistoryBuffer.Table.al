namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Localization-agnostic transfer structure used by the ICbsFiscalHistory interface. The
/// core fills this buffer from the interface and never references localization objects
/// directly. It is a temporary table (TableType = Temporary): it is never persisted to the
/// database, it only exists in memory during the call.
/// </summary>
table 50130 "CBS Fiscal History Buffer"
{
    Caption = 'CBS Fiscal History Note (Buffer)';
    DataClassification = SystemMetadata;
    Access = Internal;
    TableType = Temporary;

    fields
    {
        field(1; "Access Key"; Text[100])
        {
            Caption = 'Access Key';
            DataClassification = SystemMetadata;
        }
        field(10; "Issuer CNPJ"; Text[14])
        {
            Caption = 'Issuer CNPJ';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(11; "Issue Date"; Date)
        {
            Caption = 'Issue Date';
            DataClassification = CustomerContent;
        }
        field(12; Status; Text[30])
        {
            Caption = 'Status';
            DataClassification = SystemMetadata;
        }
        field(20; "CBS Declared Total"; Decimal)
        {
            Caption = 'CBS Declared (Total)';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(21; "CBS Declared Items"; Decimal)
        {
            Caption = 'CBS Declared (Sum of Line Items)';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(30; "Xml Available"; Boolean)
        {
            Caption = 'XML Available';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Access Key")
        {
            Clustered = true;
        }
    }
}

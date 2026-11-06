namespace RSB.ApurAssistida.CBS;

/// <summary>
/// CBS debt normalized from the Revenue Service JSON. The primary key is the natural key
/// defined in the specification (section 5.4): Environment, NI, period (Pa), Document,
/// Access Key and Origin. The Company field intentionally does not exist here (see CBS
/// Setup): Business Central already isolates the table per company.
///
/// "Period" is a Date representing the first day of the assessment period (the official
/// contract uses "mm/yyyy"): a single Date field allows a native inclusive range filter
/// (RF04), unlike two separate Integer fields (year/month), which do not support a
/// continuous SetRange when the interval crosses a year boundary.
///
/// "Issued On", "Registered On" and "Updated On" are DateTime because the official contract
/// publishes those fields as ISO 8601 date-time values (not just a date).
/// </summary>
table 50104 "CBS Debt"
{
    Caption = 'CBS Debt';
    DataClassification = SystemMetadata;
    Access = Internal;
    DrillDownPageId = "CBS Debt List";
    LookupPageId = "CBS Debt List";

    fields
    {
        field(1; "Entry No"; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(10; Environment; Enum "CBS Environment Type")
        {
            Caption = 'Environment';
            DataClassification = SystemMetadata;
        }
        field(11; NI; Text[14])
        {
            Caption = 'Taxpayer NI';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(12; Period; Date)
        {
            Caption = 'Period';
            DataClassification = CustomerContent;
        }
        field(14; Document; Integer)
        {
            // [VALIDATE] The official contract describes "documento" only as "integer -
            // document number in the assessment", without detailing whether it matches a
            // DFe model. Do not assume here any correspondence with model codes (55, 57...)
            // without confirming with a real sample from the Revenue Service.
            Caption = 'Document';
            DataClassification = CustomerContent;
        }
        field(15; "Access Key"; Text[100])
        {
            Caption = 'NF-e Access Key';
            DataClassification = CustomerContent;
        }
        field(16; Origin; Enum "CBS Debt Origin")
        {
            Caption = 'Origin';
            DataClassification = SystemMetadata;
        }
        field(20; "Issued On"; DateTime)
        {
            Caption = 'Issued On';
            DataClassification = CustomerContent;
        }
        field(21; "Registered On"; DateTime)
        {
            Caption = 'Registered On';
            DataClassification = SystemMetadata;
        }
        field(22; "Updated On"; DateTime)
        {
            Caption = 'Updated On';
            DataClassification = SystemMetadata;
        }
        field(30; "CBS Assessed"; Decimal)
        {
            Caption = 'CBS Assessed';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(31; "CBS Excess"; Decimal)
        {
            Caption = 'CBS Excess';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(32; "CBS Not Due"; Decimal)
        {
            Caption = 'CBS Not Due';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(33; "CBS Suspended"; Decimal)
        {
            Caption = 'CBS Suspended';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(34; "CBS Prepaid"; Decimal)
        {
            Caption = 'CBS Prepaid';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(35; "CBS Extinguished"; Decimal)
        {
            Caption = 'CBS Extinguished';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(36; "CBS Outstanding Balance"; Decimal)
        {
            Caption = 'Outstanding Balance';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(40; "Batch Code"; Code[20])
        {
            Caption = 'Publication Batch';
            TableRelation = "CBS Batch".Code;
            DataClassification = SystemMetadata;
        }
        field(41; "File Hash"; Text[64])
        {
            Caption = 'Source File Hash';
            DataClassification = SystemMetadata;
        }
        field(42; "Request Entry No"; Integer)
        {
            Caption = 'Originating Request';
            TableRelation = "CBS Request"."Entry No";
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No")
        {
            Clustered = true;
        }
        key(K2; Environment, NI, Period, Document, "Access Key", Origin)
        {
            // natural key (spec section 5.4): used in code to detect collisions during
            // import (RF06). Not clustered; "Entry No" is the stable technical identifier
            // referenced by CBS Reconciliation, following the same pattern as Business
            // Central ledger tables (e.g. G/L Entry, Item Ledger Entry).
        }
        key(K3; Period, Environment)
        {
            // default filter for the panel by period (inclusive range, RF04)
        }
        key(K4; "Access Key")
        {
            // used by reconciliation and the reverse lookup
        }
        key(K5; "Batch Code")
        {
            // used by atomic batch publication and republication
        }
    }

    trigger OnInsert()
    begin
        TestField(NI);
        TestField("Access Key");
        TestField(Period);
        if "CBS Assessed" < 0 then
            FieldError("CBS Assessed", CbsAssessedNegativeErr);
    end;

    var
        CbsAssessedNegativeErr: Label 'cannot be negative.';
}

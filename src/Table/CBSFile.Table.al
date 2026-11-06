namespace RSB.ApurAssistida.CBS;

using System.Security.Encryption;

/// <summary>
/// Metadata and content of the JSON file downloaded from the Revenue Service for a request.
/// The original content is written to a Blob field (not Media, which is reserved for
/// images) and kept in full to allow reprocessing (see ADR-03 of the specification).
/// </summary>
table 50103 "CBS File"
{
    Caption = 'CBS File';
    DataClassification = SystemMetadata;
    Access = Internal;

    fields
    {
        field(1; "Entry No"; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(10; "Request Entry No"; Integer)
        {
            Caption = 'Request';
            TableRelation = "CBS Request"."Entry No";
            DataClassification = SystemMetadata;
        }
        field(11; Hash; Text[64])
        {
            Caption = 'Hash (SHA-256)';
            DataClassification = SystemMetadata;
        }
        field(12; Size; BigInteger)
        {
            Caption = 'Size (bytes)';
            DataClassification = SystemMetadata;
        }
        field(13; "Storage Kind"; Enum "CBS Storage Kind")
        {
            Caption = 'Storage Kind';
            DataClassification = SystemMetadata;
        }
        field(14; Content; Blob)
        {
            Caption = 'Content';
            DataClassification = CustomerContent;
        }
        field(15; "External Reference"; Text[250])
        {
            Caption = 'External Reference';
            DataClassification = SystemMetadata;
        }
        field(20; "Generated On"; DateTime)
        {
            Caption = 'Generated On (Revenue Service)';
            DataClassification = SystemMetadata;
        }
        field(21; "Received On"; DateTime)
        {
            Caption = 'Received On';
            DataClassification = SystemMetadata;
        }
        field(30; Processed; Boolean)
        {
            Caption = 'Processed';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No")
        {
            Clustered = true;
        }
        key(K2; "Request Entry No", Hash)
        {
            // prevents publishing the same file twice for the same request (idempotency)
        }
    }

    /// <summary>Writes the content of the given stream to the Blob field and updates size/hash.</summary>
    procedure SetContent(var SourceInStream: InStream)
    var
        CryptMgt: Codeunit "Cryptography Management";
        OutStr: OutStream;
        HashInStream: InStream;
    begin
        Clear(Content);
        Content.CreateOutStream(OutStr);
        CopyStream(OutStr, SourceInStream);
        CalcFields(Content);
        Size := Content.Length();
        "Storage Kind" := "Storage Kind"::Blob;
        Content.CreateInStream(HashInStream);
        // HashAlgorithmType is a legacy Option parameter (not a publicly accessible named
        // Enum); the documented order is MD5, SHA1, SHA256, SHA384, SHA512, so 2 = SHA256.
        Hash := CryptMgt.GenerateHash(HashInStream, 2);
    end;

    /// <summary>Returns an InStream to read the stored content.</summary>
    procedure GetContent(var TargetInStream: InStream)
    begin
        CalcFields(Content);
        Content.CreateInStream(TargetInStream);
    end;
}

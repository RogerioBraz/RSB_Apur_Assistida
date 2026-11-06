namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Reference implementation of ICbsFiscalHistory: always returns Found = false. Serves as a
/// base so that the localization (or implementation partner) can deliver the real adapter,
/// without the core depending on any localization-specific object.
/// </summary>
codeunit 50128 "CBS Default Adapter" implements "ICbsFiscalHistory"
{
    Access = Internal;

    procedure GetNoteByKey(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var Buffer: Record "CBS Fiscal History Buffer"): Boolean
    begin
        exit(false);
    end;

    procedure KeyExists(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"): Boolean
    begin
        exit(false);
    end;

    procedure GetDeclaredCbs(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var DeclaredCbsTotal: Decimal; var DeclaredCbsItems: Decimal): Boolean
    begin
        DeclaredCbsTotal := 0;
        DeclaredCbsItems := 0;
        exit(false);
    end;

    procedure GetStatus(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var Status: Text[30]): Boolean
    begin
        exit(false);
    end;

    procedure GetIssuerBranch(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var IssuerCnpj: Text[14]): Boolean
    begin
        exit(false);
    end;

    procedure GetXml(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var XmlInStream: InStream): Boolean
    begin
        exit(false);
    end;

    procedure ListByIssueDate(FromDate: Date; ToDate: Date; Environment: Enum "CBS Environment Type"; var Buffer: Record "CBS Fiscal History Buffer" temporary): Integer
    begin
        exit(0);
    end;

    procedure OpenNoteInViewer(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"): Boolean
    var
        NoAdapterMsg: Label 'No fiscal history adapter is linked. Configure the adapter in CBS Setup.';
    begin
        Message(NoAdapterMsg);
        exit(false);
    end;
}

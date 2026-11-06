namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Parses the JSON envelope of debts from the Revenue Service and upserts the records into
/// CBS Debt, applying the natural key and the collision rule from spec section 5.4/RF06: an
/// existing record is NEVER silently overwritten by a new collection - the collision is
/// always recorded, and replacement only happens when the batch type is Republication
/// (intentional republication, flow 7.2).
///
/// Unrecognized JSON fields are ignored (tolerance to contract evolution, spec section 3);
/// missing or invalid required fields cause the record to be counted as invalid and logged,
/// without interrupting the rest of the file.
/// </summary>
codeunit 50134 "CBS JSON Importer"
{
    Access = Internal;

    var
        Telemetry: Codeunit "CBS Telemetry";

    /// <summary>
    /// Imports the entire content of the file (envelope + apuracao[] + debitos[]) into CBS
    /// Debt, marking each record with the given batch. Publication (visibility to
    /// consumption) is the responsibility of CBS Batch Publisher, not this codeunit.
    /// </summary>
    procedure ImportFile(var CBSFile: Record "CBS File"; Environment: Enum "CBS Environment Type"; Batch: Record "CBS Batch"; RequestEntryNo: Integer; var RecordsImported: Integer; var RecordsDivergent: Integer; var RecordsInvalid: Integer)
    var
        ContentInStream: InStream;
        Envelope: JsonObject;
        Ni: Text[14];
        NiTok: JsonToken;
        AssessmentArrTok: JsonToken;
        AssessmentArr: JsonArray;
        AssessmentItemTok: JsonToken;
        Index: Integer;
    begin
        CBSFile.GetContent(ContentInStream);
        if not Envelope.ReadFrom(ContentInStream) then
            Error(InvalidJsonErr);

        if Envelope.Get('ni', NiTok) then
            Ni := CopyStr(NiTok.AsValue().AsText(), 1, 14);

        if not Envelope.Get('apuracao', AssessmentArrTok) then
            exit; // envelope without the apuracao array: nothing to import, not an error

        AssessmentArr := AssessmentArrTok.AsArray();
        for Index := 0 to AssessmentArr.Count() - 1 do
            if AssessmentArr.Get(Index, AssessmentItemTok) then
                ImportAssessmentItem(AssessmentItemTok.AsObject(), Environment, Ni, Batch, RequestEntryNo, RecordsImported, RecordsDivergent, RecordsInvalid);
    end;

    local procedure ImportAssessmentItem(AssessmentItem: JsonObject; Environment: Enum "CBS Environment Type"; Ni: Text[14]; Batch: Record "CBS Batch"; RequestEntryNo: Integer; var RecordsImported: Integer; var RecordsDivergent: Integer; var RecordsInvalid: Integer)
    var
        PeriodTok: JsonToken;
        DebtsArrTok: JsonToken;
        DebtsArr: JsonArray;
        DebtTok: JsonToken;
        Period: Date;
        Index: Integer;
    begin
        if not AssessmentItem.Get('pa', PeriodTok) then begin
            RecordsInvalid += 1;
            Telemetry.ErrorEvent("CBS Log Category"::Import, Batch."Code", PeriodMissingErr);
            exit;
        end;
        if not ConvertPeriod(PeriodTok.AsValue().AsText(), Period) then begin
            RecordsInvalid += 1;
            Telemetry.ErrorEvent("CBS Log Category"::Import, Batch."Code", PeriodInvalidErr);
            exit;
        end;

        if not AssessmentItem.Get('debitos', DebtsArrTok) then
            exit; // period covered with no debts: valid, not an error

        DebtsArr := DebtsArrTok.AsArray();
        for Index := 0 to DebtsArr.Count() - 1 do
            if DebtsArr.Get(Index, DebtTok) then
                ImportOneDebt(DebtTok.AsObject(), Environment, Ni, Period, Batch, RequestEntryNo, RecordsImported, RecordsDivergent, RecordsInvalid);
    end;

    local procedure ImportOneDebt(DebtObj: JsonObject; Environment: Enum "CBS Environment Type"; Ni: Text[14]; Period: Date; Batch: Record "CBS Batch"; RequestEntryNo: Integer; var RecordsImported: Integer; var RecordsDivergent: Integer; var RecordsInvalid: Integer)
    var
        NewDebt: Record "CBS Debt";
        ExistingDebt: Record "CBS Debt";
        CbsObj: JsonObject;
        Tok: JsonToken;
        AccessKey: Text[100];
        Document: Integer;
        Origin: Enum "CBS Debt Origin";
        CbsAssessed: Decimal;
        Updated: DateTime;
    begin
        if not DebtObj.Get('chave', Tok) then begin
            RecordsInvalid += 1;
            Telemetry.ErrorEvent("CBS Log Category"::Import, Batch."Code", DebtWithoutKeyErr);
            exit;
        end;
        AccessKey := CopyStr(Tok.AsValue().AsText(), 1, 100);

        Document := GetOptionalInt(DebtObj, 'documento');

        if not TryConvertOrigin(GetOptionalInt(DebtObj, 'origem'), Origin) then begin
            Origin := Origin::Normal;
            Telemetry.WarningEvent("CBS Log Category"::Import, Batch."Code", UnknownOriginMsg);
        end;

        if not DebtObj.Get('cbs', Tok) then begin
            RecordsInvalid += 1;
            Telemetry.ErrorEvent("CBS Log Category"::Import, Batch."Code", DebtWithoutCbsErr);
            exit;
        end;
        CbsObj := Tok.AsObject();
        CbsAssessed := GetOptionalDecimal(CbsObj, 'apurado');
        if CbsAssessed < 0 then begin
            RecordsInvalid += 1;
            Telemetry.ErrorEvent("CBS Log Category"::Import, Batch."Code", CbsAssessedNegativeErr);
            exit;
        end;

        Updated := ParseOptionalIso8601(DebtObj, 'atualizacao');

        if ExistingDebt.Get(Environment, Ni, Period, Document, AccessKey, Origin) then begin
            if Batch.Type = Batch.Type::Republication then begin
                FillDebtFields(ExistingDebt, DebtObj, CbsObj, Environment, Ni, Period, Document, AccessKey, Origin, CbsAssessed, Updated, Batch);
                ExistingDebt.Modify(true);
                RecordsImported += 1;
            end else begin
                RecordsDivergent += 1;
                RegisterCollision(ExistingDebt, Updated, Batch);
            end;
            exit;
        end;

        NewDebt.Init();
        FillDebtFields(NewDebt, DebtObj, CbsObj, Environment, Ni, Period, Document, AccessKey, Origin, CbsAssessed, Updated, Batch);
        NewDebt."Request Entry No" := RequestEntryNo;
        NewDebt.Insert(true);
        RecordsImported += 1;
    end;

    local procedure FillDebtFields(var Debt: Record "CBS Debt"; DebtObj: JsonObject; CbsObj: JsonObject; Environment: Enum "CBS Environment Type"; Ni: Text[14]; Period: Date; Document: Integer; AccessKey: Text[100]; Origin: Enum "CBS Debt Origin"; CbsAssessed: Decimal; Updated: DateTime; Batch: Record "CBS Batch")
    begin
        Debt.Environment := Environment;
        Debt.NI := Ni;
        Debt.Period := Period;
        Debt.Document := Document;
        Debt."Access Key" := AccessKey;
        Debt.Origin := Origin;
        Debt."Issued On" := ParseOptionalIso8601(DebtObj, 'emissao');
        Debt."Registered On" := ParseOptionalIso8601(DebtObj, 'registro');
        Debt."Updated On" := Updated;
        Debt."CBS Assessed" := CbsAssessed;
        Debt."CBS Excess" := GetOptionalDecimal(CbsObj, 'excedente');
        Debt."CBS Not Due" := GetOptionalDecimal(CbsObj, 'inexigivel');
        Debt."CBS Suspended" := GetOptionalDecimal(CbsObj, 'suspenso');
        Debt."CBS Prepaid" := GetOptionalDecimal(CbsObj, 'pgtoAntecipado');
        Debt."CBS Extinguished" := GetOptionalDecimal(CbsObj, 'extinto');
        Debt."CBS Outstanding Balance" := GetOptionalDecimal(CbsObj, 'saldoDevedor');
        Debt."Batch Code" := Batch."Code";
        Debt."File Hash" := Batch."File Hash";
    end;

    local procedure RegisterCollision(ExistingDebt: Record "CBS Debt"; NewUpdated: DateTime; Batch: Record "CBS Batch")
    var
        LogEntry: Record "CBS Log Entry";
    begin
        LogEntry.Init();
        LogEntry."Date Time" := CurrentDateTime();
        LogEntry.Category := LogEntry.Category::Import;
        LogEntry.Severity := LogEntry.Severity::Warning;
        LogEntry."Event" := 'CBS-NATURAL-KEY-COLLISION';
        LogEntry."Message" := CopyStr(StrSubstNo(CollisionMsg, ExistingDebt."Access Key", Format(ExistingDebt."Updated On"), Format(NewUpdated)), 1, 250);
        LogEntry.Correlation := Batch."Code";
        LogEntry.Insert();
    end;

    /// <summary>Converts "mm/yyyy" (with or without a leading zero on the month) into the first day of the assessment period.</summary>
    local procedure ConvertPeriod(PeriodText: Text; var Period: Date): Boolean
    var
        Parts: List of [Text];
        PeriodYear: Integer;
        PeriodMonth: Integer;
    begin
        Parts := PeriodText.Split('/');
        if Parts.Count() <> 2 then
            exit(false);
        if not Evaluate(PeriodMonth, Parts.Get(1)) then
            exit(false);
        if not Evaluate(PeriodYear, Parts.Get(2)) then
            exit(false);
        if not ((PeriodMonth >= 1) and (PeriodMonth <= 12) and (PeriodYear >= 2000)) then
            exit(false);
        Period := DMY2Date(1, PeriodMonth, PeriodYear);
        exit(true);
    end;

    local procedure GetOptionalInt(Obj: JsonObject; FieldKey: Text): Integer
    var
        Tok: JsonToken;
    begin
        if Obj.Get(FieldKey, Tok) then
            if Tok.IsValue() then
                exit(Tok.AsValue().AsInteger());
        exit(0);
    end;

    local procedure GetOptionalDecimal(Obj: JsonObject; FieldKey: Text): Decimal
    var
        Tok: JsonToken;
    begin
        if Obj.Get(FieldKey, Tok) then
            if Tok.IsValue() then
                exit(Tok.AsValue().AsDecimal());
        exit(0);
    end;

    local procedure ParseOptionalIso8601(Obj: JsonObject; FieldKey: Text): DateTime
    var
        Tok: JsonToken;
    begin
        if Obj.Get(FieldKey, Tok) then
            if Tok.IsValue() then
                exit(ParseIso8601(Tok.AsValue().AsText()));
        exit(0DT);
    end;

    /// <summary>Converts a "YYYY-MM-DDThh:mm:ss[Z|+hh:mm]" (ISO 8601) text into a DateTime.</summary>
    local procedure ParseIso8601(InputText: Text): DateTime
    var
        YearI, MonthI, DayI, HourI, MinuteI, SecondI : Integer;
        TimeOfDay: Time;
    begin
        if StrLen(InputText) < 19 then
            exit(0DT);
        if not (Evaluate(YearI, CopyStr(InputText, 1, 4)) and Evaluate(MonthI, CopyStr(InputText, 6, 2)) and Evaluate(DayI, CopyStr(InputText, 9, 2)) and
                Evaluate(HourI, CopyStr(InputText, 12, 2)) and Evaluate(MinuteI, CopyStr(InputText, 15, 2)) and Evaluate(SecondI, CopyStr(InputText, 18, 2)))
        then
            exit(0DT);
        TimeOfDay := 0T + (HourI * 3600000) + (MinuteI * 60000) + (SecondI * 1000);
        exit(CreateDateTime(DMY2Date(DayI, MonthI, YearI), TimeOfDay));
    end;

    [TryFunction]
    local procedure TryConvertOrigin(Value: Integer; var Origin: Enum "CBS Debt Origin")
    begin
        Origin := Enum::"CBS Debt Origin".FromInteger(Value);
    end;

    var
        InvalidJsonErr: Label 'Invalid or empty JSON file.';
        PeriodMissingErr: Label 'Assessment item without the pa field.';
        PeriodInvalidErr: Label 'Invalid pa format (expected mm/yyyy).';
        DebtWithoutKeyErr: Label 'Debt without the chave field.';
        DebtWithoutCbsErr: Label 'Debt without the cbs object.';
        CbsAssessedNegativeErr: Label 'Negative assessed CBS.';
        UnknownOriginMsg: Label 'Unrecognized origin code; imported as Normal.';
        CollisionMsg: Label 'Natural key collision on key %1: original record (updated %2) kept; new update %3 discarded until intentional republication.', Comment = '%1 = NF-e key, %2/%3 = update dates';
}

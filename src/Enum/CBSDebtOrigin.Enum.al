namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Origin of the CBS debt as defined by the official Revenue Service contract (field
/// debitos[].origem). Fixed (not extensible) because the codes are normative.
/// </summary>
enum 50118 "CBS Debt Origin"
{
    Extensible = false;
    Access = Internal;
    Caption = 'CBS Debt Origin';

    value(0; Normal)
    {
        Caption = 'Normal';
    }
    value(20; ReturnByPcont)
    {
        Caption = 'Return by PCONT';
    }
    value(21; ReturnByRad)
    {
        Caption = 'Return by RAD';
    }
    value(22; ReturnByCredit)
    {
        Caption = 'Return by Credit';
    }
    value(30; CreditCancellation)
    {
        Caption = 'Credit Cancellation';
    }
    value(31; RadCancellation)
    {
        Caption = 'RAD Cancellation';
    }
    value(32; PcontCancellation)
    {
        Caption = 'PCONT Cancellation';
    }
    value(50; FobTransportSpoilage)
    {
        Caption = 'FOB Transport Spoilage';
    }
    value(51; CifTransportSpoilage)
    {
        Caption = 'CIF Transport Spoilage';
    }
    value(52; CifSpoilageReturnByPcont)
    {
        Caption = 'CIF Spoilage Return by PCONT';
    }
    value(53; CifSpoilageReturnByRad)
    {
        Caption = 'CIF Spoilage Return by RAD';
    }
    value(54; CifSpoilageReturnByCredit)
    {
        Caption = 'CIF Spoilage Return by Credit';
    }
    value(55; CreditNoteFineInterest)
    {
        Caption = 'Credit Note for Fine and Interest';
    }
}

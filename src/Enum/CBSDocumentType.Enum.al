namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Tipo do documento fiscal informado pelo campo debitos[].documento da API de Apuração
/// Assistida da CBS. Os códigos são normativos (contrato oficial, seção 5) e por isso o enum
/// NÃO é extensível: 55 = NF-e, 57 = CT-e, 62 = NFCom, 63 = BP-e, 64 = GTV-e, 65 = NFC-e,
/// 66 = NF3-e, 67 = CT-e OS, 91 = NFS-e, 92 = NFS-e Via, 93 = BP-e TM, 94 = DERE,
/// 97 = CT-e Simplificado.
///
/// Público porque parceiros que estendem o adaptador de histórico fiscal podem precisar
/// avaliar o tipo do documento.
/// </summary>
enum 50119 "CBS Document Type"
{
    Extensible = false;
    Access = Public;
    Caption = 'CBS Document Type';

    value(55; NFe)
    {
        Caption = 'NF-e (55)';
    }
    value(57; CTe)
    {
        Caption = 'CT-e (57)';
    }
    value(62; NFCom)
    {
        Caption = 'NFCom (62)';
    }
    value(63; BPe)
    {
        Caption = 'BP-e (63)';
    }
    value(64; GTVe)
    {
        Caption = 'GTV-e (64)';
    }
    value(65; NFCe)
    {
        Caption = 'NFC-e (65)';
    }
    value(66; NF3e)
    {
        Caption = 'NF3-e (66)';
    }
    value(67; CTeOS)
    {
        Caption = 'CT-e OS (67)';
    }
    value(91; NFSe)
    {
        Caption = 'NFS-e (91)';
    }
    value(92; NFSeVia)
    {
        Caption = 'NFS-e Via (92)';
    }
    value(93; BPeTM)
    {
        Caption = 'BP-e TM (93)';
    }
    value(94; DERE)
    {
        Caption = 'DERE (94)';
    }
    value(97; CTeSimplificado)
    {
        Caption = 'CT-e Simplificado (97)';
    }
}

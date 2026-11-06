namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Builds Revenue Service API URLs per environment and normalizes/encodes values for use in
/// HTTP requests (query string and application/x-www-form-urlencoded body).
/// [VALIDATE] Confirm the official base URLs for Production and Restricted Production with
/// Receita Integra before publishing to production.
/// </summary>
codeunit 50132 "CBS Url Helper"
{
    Access = Internal;

    procedure BaseUrl(Environment: Enum "CBS Environment Type"): Text
    begin
        case Environment of
            Environment::Production:
                exit('https://api.receitafederal.gov.br/apuracao-cbs/v2');
            Environment::RestrictedProduction:
                exit('https://api-prr.receitafederal.gov.br/apuracao-cbs/v2');
        end;
    end;

    /// <summary>Removes formatting and ensures 8 digits for the base CNPJ.</summary>
    procedure NormalizeBaseCnpj(Value: Text): Text[8]
    var
        Output: Text;
        Character: Char;
        Index: Integer;
    begin
        for Index := 1 to StrLen(Value) do begin
            Character := Value[Index];
            if (Character in ['0' .. '9']) and (StrLen(Output) < 8) then
                Output += Format(Character);
        end;
        exit(CopyStr(Output, 1, 8));
    end;

    /// <summary>Encodes a text for use in an application/x-www-form-urlencoded body.</summary>
    procedure UriEncodeForm(Value: Text): Text
    var
        Output: TextBuilder;
        Character: Char;
        Index: Integer;
    begin
        for Index := 1 to StrLen(Value) do begin
            Character := Value[Index];
            case true of
                Character = ' ':
                    Output.Append('+');
                (Character in ['a' .. 'z']) or (Character in ['A' .. 'Z']) or (Character in ['0' .. '9']) or
                (Character in ['-', '_', '.', '~']):
                    Output.Append(Character);
                else
                    Output.Append('%' + HexOfCharacter(Character));
            end;
        end;
        exit(Output.ToText());
    end;

    local procedure HexOfCharacter(Character: Char): Text[2]
    var
        Digits: Text;
    begin
        Digits := '0123456789ABCDEF';
        exit(CopyStr(Format(Digits[(Character div 16) + 1]) + Format(Digits[(Character mod 16) + 1]), 1, 2));
    end;
}

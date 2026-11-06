namespace RSB.ApurAssistida.CBS;

/// <summary>
/// Access contract to the localization's fiscal history (outbound invoices and the declared
/// CBS amount). The core of the app never references localization-specific objects; the
/// localization delivers a concrete implementation selected through the "CBS Fiscal History
/// Adapter" enum in CBS Setup.
///
/// Each method returns a Boolean (Found): true when the data was located, false when the
/// data does not exist or cannot be obtained. The Environment parameter ensures that the
/// query respects the segregation between Production and Restricted Production (see spec
/// section 4.4): a sandbox note must never be used to reconcile a production debt, and it is
/// up to the adapter to enforce this filter.
/// </summary>
interface "ICbsFiscalHistory"
{
    Access = Internal;

    /// <summary>Gets the fiscal history note by its access key.</summary>
    /// <param name="AccessKey">Access key of the NF-e (44 digits).</param>
    /// <param name="Environment">Environment of the debt's originating request.</param>
    /// <param name="Buffer">Transfer buffer filled when Found = true.</param>
    /// <returns>True if the note was found in the given environment.</returns>
    procedure GetNoteByKey(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var Buffer: Record "CBS Fiscal History Buffer"): Boolean

    /// <summary>Checks whether the key exists in the fiscal history, in the given environment.</summary>
    procedure KeyExists(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"): Boolean

    /// <summary>
    /// Gets the CBS amount declared on the note: the document total (gCBS/vCBS) and, when
    /// available, the sum of the line items, to allow detecting internal divergence (see
    /// spec section 8.1/8.4).
    /// </summary>
    procedure GetDeclaredCbs(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var DeclaredCbsTotal: Decimal; var DeclaredCbsItems: Decimal): Boolean

    /// <summary>Gets the current status of the note (Authorized, Cancelled, etc).</summary>
    procedure GetStatus(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var Status: Text[30]): Boolean

    /// <summary>Gets the CNPJ of the issuing branch of the note.</summary>
    procedure GetIssuerBranch(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var IssuerCnpj: Text[14]): Boolean

    /// <summary>Gets the original authorized XML of the note as an InStream, when available.</summary>
    procedure GetXml(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"; var XmlInStream: InStream): Boolean

    /// <summary>
    /// Lists, in the given temporary buffer, the notes issued within the date range and
    /// environment informed. Used by the reverse lookup (RF09) to find issued notes that did
    /// not generate any CBS debt. The default implementation always returns zero results (no
    /// adapter linked).
    /// </summary>
    /// <returns>Number of notes found in the interval.</returns>
    procedure ListByIssueDate(FromDate: Date; ToDate: Date; Environment: Enum "CBS Environment Type"; var Buffer: Record "CBS Fiscal History Buffer" temporary): Integer

    /// <summary>Opens the note in the localization's fiscal history viewer.</summary>
    /// <returns>True if navigation was performed.</returns>
    procedure OpenNoteInViewer(AccessKey: Text[100]; Environment: Enum "CBS Environment Type"): Boolean
}

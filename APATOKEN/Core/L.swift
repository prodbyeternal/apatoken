import Foundation
import SwiftUI

/// Localized string accessors with dynamic language switching support.
/// All keys live in Resources/{en,pl,fr}.lproj/Localizable.strings.
enum L {
    /// UI strings (MAUI resource keys).
    enum ui {
        static var appName: String { LocalizedKey("app_name").localized }
        static var txtEnterToken: String { LocalizedKey("txtEnterToken").localized }
        static var txtUploadToken: String { LocalizedKey("txtUploadToken").localized }
        static var txtPaste: String { LocalizedKey("txtPaste").localized }
        static var txtDeviceName: String { LocalizedKey("txtDeviceName").localized }
        static var txtSelect: String { LocalizedKey("txtSelect").localized }
        static var txtAlertInfo: String { LocalizedKey("txtAlertInfo").localized }
        static var txtError: String { LocalizedKey("txtError").localized }
        static var txtPackageVersion: String { LocalizedKey("txtPackageVersion").localized }
        static var txtPublisher: String { LocalizedKey("txtPublisher").localized }
        static var txtOk: String { LocalizedKey("txtOk").localized }
        static var txtExit: String { LocalizedKey("txtExit").localized }
        static var txtCancel: String { LocalizedKey("txtCancel").localized }
        static var txtNoDevicesFound: String { LocalizedKey("txtNoDevicesFound").localized }
        static var txtClose: String { LocalizedKey("txtClose").localized }
        static var txtPrepaidRecharge: String { LocalizedKey("txtPrepaidRecharge").localized }
        static var txtNoMeterSelected: String { LocalizedKey("txtNoMeterSelected").localized }
        static var txtClear: String { LocalizedKey("txtClear").localized }
        static var txtReadings: String { LocalizedKey("txtReadings").localized }
        static var txtReadCredits: String { LocalizedKey("txtReadCredits").localized }
        static var txtLastUpdated: String { LocalizedKey("txtLastUpdated").localized }
        static var txtCurrentCredits: String { LocalizedKey("txtCurrentCredits").localized }
        static var txtHistory: String { LocalizedKey("txtHistory").localized }
        static var txtChargesHistory: String { LocalizedKey("txtChargesHistory").localized }
        static var txtSettings: String { LocalizedKey("txtSettings").localized }
        static var txtMenuSettings: String { LocalizedKey("txtMenuSettings").localized }
        static var txtDetails: String { LocalizedKey("txtDetails").localized }
        static var txtDate: String { LocalizedKey("txtDate").localized }
        static var txtCode: String { LocalizedKey("txtCode").localized }
        static var txtCodeStatus: String { LocalizedKey("txtCodeStatus").localized }
        static var txtCreditValue: String { LocalizedKey("txtCreditValue").localized }
        static var txtAfterPrepaidRecharge: String { LocalizedKey("txtAfterPrepaidRecharge").localized }
        static var txtTotalCredit: String { LocalizedKey("txtTotalCredit").localized }
        static var txtRecharge: String { LocalizedKey("txtRecharge").localized }
        static var txtTariffZone: String { LocalizedKey("txtTariffZone").localized }
        static var txtZone: String { LocalizedKey("txtZone").localized }
        static var txtSingleCharging: String { LocalizedKey("txtSingleCharging").localized }
        static var txtDualCharging: String { LocalizedKey("txtDualCharging").localized }
        static var txtDeviceAddress: String { LocalizedKey("txtDeviceAddress").localized }
        static var txtDeviceId: String { LocalizedKey("txtDeviceId").localized }
        static var txtSelectDevice: String { LocalizedKey("txtSelectDevice").localized }
        static var txtAvailableDevices: String { LocalizedKey("txtAvailableDevices").localized }
        static var txtScanning: String { LocalizedKey("txtScanning").localized }
        static var txtSampleIdentification: String { LocalizedKey("txtSampleIdentification").localized }
        static var txtSaveSettings: String { LocalizedKey("txtSaveSettings").localized }
        static var txtUnknown: String { LocalizedKey("txtUnknown").localized }
        static var txtMeterNumber: String { LocalizedKey("txtMeterNumber").localized }
        static var txtLocatedOnTheMeterCasing: String { LocalizedKey("txtLocatedOnTheMeterCasing").localized }
        static var txtPickValue: String { LocalizedKey("txtPickValue").localized }
        static var txtResetCredit: String { LocalizedKey("txtResetCredit").localized }
        static var txtUnlockCommunication: String { LocalizedKey("txtUnlockCommunication").localized }
        static var txtLanguage: String { LocalizedKey("txtLanguage").localized }
        static var txtCharges: String { LocalizedKey("txtCharges").localized }
        static var txtDeveloper: String { LocalizedKey("txtDeveloper").localized }
        static var txtReverseEngineering: String { LocalizedKey("txtReverseEngineering").localized }
        static var txtUIUX: String { LocalizedKey("txtUIUX").localized }
        static var txtAboutIAPATOKEN: String { LocalizedKey("txtAboutIAPATOKEN").localized }
        static var txtVersion: String { LocalizedKey("txtVersion").localized }
        static var txtTokenNumber: String { LocalizedKey("txtTokenNumber").localized }
        static var txtEnterTokenPlaceholder: String { LocalizedKey("txtEnterTokenPlaceholder").localized }
        static var txtApplyToken: String { LocalizedKey("txtApplyToken").localized }
        static var txtTokenApplied: String { LocalizedKey("txtTokenApplied").localized }
        static var txtTokenAppliedSuccess: String { LocalizedKey("txtTokenAppliedSuccess").localized }
        static var txtSectionMeter: String { LocalizedKey("txtSectionMeter").localized }
        static var txtSectionTools: String { LocalizedKey("txtSectionTools").localized }
        static var txtSectionDisplay: String { LocalizedKey("txtSectionDisplay").localized }
        static var txtSectionAbout: String { LocalizedKey("txtSectionAbout").localized }
        static var txtSelectPairedMeter: String { LocalizedKey("txtSelectPairedMeter").localized }
        static var txtPortLog: String { LocalizedKey("txtPortLog").localized }
        static var txtNotConfigured: String { LocalizedKey("txtNotConfigured").localized }
        static var txtAll: String { LocalizedKey("txtAll").localized }
    }

    /// App-level messages (MAUI resource keys).
    enum message {
        /// iOS port credit line (About ⓘ).
        static var msgIosPort: String { LocalizedKey("msgIosPort").localized }
        static var msgOperationSucceeded: String { LocalizedKey("msgOperationSucceeded").localized }
        static var msgOperationFailed: String { LocalizedKey("msgOperationFailed").localized }
        static var msgNoResponseFromMeter: String { LocalizedKey("msgNoResponseFromMeter").localized }
        static var msgUnsuccessfulTokenEntering: String { LocalizedKey("msgUnsuccessfulTokenEntering").localized }
        static var msgTokenEnteredButNotAccepted: String { LocalizedKey("msgTokenEnteredButNotAccepted").localized }
        static var msgEnteredTokenIsWrong: String { LocalizedKey("msgEnteredTokenIsWrong").localized }
        static var msgEnteredTokenAlreadyUsed: String { LocalizedKey("msgEnteredTokenAlreadyUsed").localized }
        static var msgTooShortToken: String { LocalizedKey("msgTooShortToken").localized }
        static var msgIncorrentCodeLength: String { LocalizedKey("msgIncorrentCodeLength").localized }
        static var msgToEnterCodeDeviceMustBeSelected: String { LocalizedKey("msgToEnterCodeDeviceMustBeSelected").localized }
        static var msgToReadCreditsDeviceMustBeSelected: String { LocalizedKey("msgToReadCreditsDeviceMustBeSelected").localized }
        static var msgNoAssociatedBluetoothDevice: String { LocalizedKey("msgNoAssociatedBluetoothDevice").localized }
        static var msgDataReadUnsuccessful: String { LocalizedKey("msgDataReadUnsuccessful").localized }
        static var msgDataReadUnderProgress: String { LocalizedKey("msgDataReadUnderProgress").localized }
        static var msgTokenEnteringUnderProgress: String { LocalizedKey("msgTokenEnteringUnderProgress").localized }
        static var msgStayCloseToTheMeter: String { LocalizedKey("msgStayCloseToTheMeter").localized }
        static var msgHistoryInformation: String { LocalizedKey("msgHistoryInformation").localized }
        static var msgNoDeviceFound: String { LocalizedKey("msgNoDeviceFound").localized }
        static var msgBluetoothNotSupported: String { LocalizedKey("msgBluetoothNotSupported").localized }
        static var msgNoBluetoothDeviceSelected: String { LocalizedKey("msgNoBluetoothDeviceSelected").localized }
        static var msgSettingsSaved: String { LocalizedKey("msgSettingsSaved").localized }
        static var msgSettingsNotSaved: String { LocalizedKey("msgSettingsNotSaved").localized }
        static var msgSettingsSaveError: String { LocalizedKey("msgSettingsSaveError").localized }
        static var msgSaveChangedSettingsQ: String { LocalizedKey("msgSaveChangedSettingsQ").localized }
        static var msgMissingCreditInfo: String { LocalizedKey("msgMissingCreditInfo").localized }
        static var msgDeviceMissing: String { LocalizedKey("msgDeviceMissing").localized }
        static var msgCommunicationWithDeviceNotPossible: String { LocalizedKey("msgCommunicationWithDeviceNotPossible").localized }

        // Token code status descriptions
        static var msgCodeStatusOk: String { LocalizedKey("msgCodeStatusOk").localized }
        static var msgCodeStatusNotOk: String { LocalizedKey("msgCodeStatusNotOk").localized }
        static var msgCodeStatusTooOld: String { LocalizedKey("msgCodeStatusTooOld").localized }
        static var msgCodeStatusUsed: String { LocalizedKey("msgCodeStatusUsed").localized }
        static var msgCodeStatusAboveLimit: String { LocalizedKey("msgCodeStatusAboveLimit").localized }
        static var msgCodeStatusBlocked: String { LocalizedKey("msgCodeStatusBlocked").localized }
        static var msgCodeStatusError: String { LocalizedKey("msgCodeStatusError").localized }
        static var msgCodeStatusPrepaidOff: String { LocalizedKey("msgCodeStatusPrepaidOff").localized }
        static var msgCodeStatusUnknown: String { LocalizedKey("msgCodeStatusUnknown").localized }
        static var msgValidationResultFailure: String { LocalizedKey("msgValidationResultFailure").localized }

        // Library / protocol messages
        static var msgNoLLC: String { LocalizedKey("msgNoLLC").localized }
        static var msgEmptyDlmsArray: String { LocalizedKey("msgEmptyDlmsArray").localized }
        static var msgDlmsArrayIsTooShort: String { LocalizedKey("msgDlmsArrayIsTooShort").localized }
        static var msgNotEnoughData: String { LocalizedKey("msgNotEnoughDataAvailable").localized }
        static var msgNotEnoughDataAvailable: String { LocalizedKey("msgNotEnoughDataAvailable").localized }
        static var msgNoData: String { LocalizedKey("msgNoData").localized }
        static var msgWrongDataType: String { LocalizedKey("msgWrongDataType").localized }
        static var msgExpectedVsReceived: String { LocalizedKey("msgExpectedVsReceived").localized }
        static var msgAccessError: String { LocalizedKey("msgAccessError").localized }
        static var msgWrongPDU: String { LocalizedKey("msgWrongPDU").localized }
        static var msgWrongHDLCFrameLength: String { LocalizedKey("msgWrongHDLCFrameLength").localized }
        static var msgWrongHDLCFrameCRC: String { LocalizedKey("msgWrongHDLCFrameCRC").localized }
        static var msgWrongHDLCHeader: String { LocalizedKey("msgWrongHDLCHeader").localized }
        static var msgBadDataChecksum: String { LocalizedKey("msgBadDataChecksum").localized }
        static var msgNoHDLCHeader: String { LocalizedKey("msgNoHDLCHeader").localized }
        static var msgNoHDLCFooter: String { LocalizedKey("msgNoHDLCFooter").localized }
        static var msgNoHeader: String { LocalizedKey("msgNoHeader").localized }
        static var msgNoTile: String { LocalizedKey("msgNoTile").localized }
        static var msgInvalidFrame: String { LocalizedKey("msgInvalidFrame").localized }
        static var msgBadHeaderChecksum: String { LocalizedKey("msgBadHeaderChecksum").localized }
        static var msgAssociationError: String { LocalizedKey("msgAssociationError").localized }
        static var msgProbablyWrongKeys: String { LocalizedKey("msgProbablyWrongKeys").localized }
        static var msgAttributeAccessError: String { LocalizedKey("msgAttributeAccessError").localized }
        static var msgMethodAccessError: String { LocalizedKey("msgMethodAccessError").localized }
        static var msgWrongObisString: String { LocalizedKey("msgWrongObisString").localized }
        static var msgWrongCharInObisCode: String { LocalizedKey("msgWrongCharInObisCode").localized }
        static var msgHDLCFrameParsingError: String { LocalizedKey("msgHDLCFrameParsingError").localized }
        static var msgHDLCFrameCreatingError: String { LocalizedKey("msgHDLCFrameCreatingError").localized }
        static var msgHdlcNoHdlcFramesToSend: String { LocalizedKey("msgHdlc_NoHdlcFramesToSend").localized }
        static var msgHdlcSpaceForPayloadNotNegotiated: String { LocalizedKey("msgHdlc_SpaceForPayloadNotNegotiated").localized }
        static var msgInvalidResponseFrame: String { LocalizedKey("msgInvalidResponseFrame").localized }
        static var msgWrongResponseFromMeter: String { LocalizedKey("msgWrongResponseFromMeter").localized }
        static var msgNoResponse: String { LocalizedKey("msgNoResponse").localized }
        static var msgWrongNumberOfBytes: String { LocalizedKey("msgWrongNumberOfBytes").localized }
        static var msgWrongValue: String { LocalizedKey("msgWrongValue").localized }
        static var msgWrongValueFormat: String { LocalizedKey("msgWrongValueFormat").localized }
        static var msgWrongMemberValueType: String { LocalizedKey("msgWrongMemberValueType").localized }
        static var msgWrongMemberValue: String { LocalizedKey("msgWrongMemberValue").localized }
        static var msgWrongNumberOfStructureFields: String { LocalizedKey("msgWrongNumberOfStructureFields").localized }
        static var msgGivenValueIsNotStructure: String { LocalizedKey("msgGivenValueIsNotStructure").localized }
        static var msgWrongBinaryRepresentation: String { LocalizedKey("msgWrongBinaryRepresentation").localized }
        static var msgSimpleDataTypeExpected: String { LocalizedKey("msgSimpleDataTypeExpected").localized }
        static var msgWrongWrongStatusLength: String { LocalizedKey("msgWrongStatusLength").localized }
        static var msgEntryTypeMustBeSimple: String { LocalizedKey("msgEntryTypeMustBeSimple").localized }
        static var msgUnknownError: String { LocalizedKey("msgUnknownError").localized }
        static var msgUnknownErrorReason: String { LocalizedKey("msgUnknownErrorReason").localized }
        static var msgUnknownCosemType: String { LocalizedKey("msgUnknownCosemType").localized }
        static var msgNotImplemented: String { LocalizedKey("msgNotImplemented").localized }
        static var msgUnsuccessfulPortOpening: String { LocalizedKey("msgUnsuccessfulPortOpening").localized }
        static var msgUnsuccessfulDataSending: String { LocalizedKey("msgUnsuccessfulDataSending").localized }
        static var msgUnsuccessfulDataReceiving: String { LocalizedKey("msgUnsuccessfulDataReceiving").localized }
        static var msgWrongWrapperFrameHeaderLength: String { LocalizedKey("msgWrongWrapperFrameHeaderLength").localized }
        static var msgWrongWrapperFrameLength: String { LocalizedKey("msgWrongWrapperFrameLength").localized }
        static var msgUnsuccessfulPDUProcessing: String { LocalizedKey("msgUnsuccessfulPDUProcessing").localized }
        static var msgTransferError: String { LocalizedKey("msgTransferError").localized }
        static var msgEntityDoesNotMatch: String { LocalizedKey("msgEntityDoesNotMatch").localized }
        static var msgEntityClient: String { LocalizedKey("txtEntityClient").localized }
        static var msgEntityServer: String { LocalizedKey("txtEntityServer").localized }
        static var msgWrongNumberOfCharsInHexString: String { LocalizedKey("msgWrongNumberOfCharsInHexString").localized }
        static var msgTransfer_ApplicationContextNameNotSupported: String { LocalizedKey("msgTransfer_ApplicationContextNameNotSupported").localized }
    }

    static func text(_ key: String) -> String {
        LocalizationManager.shared.localizedString(forKey: key)
    }

    /// Formats a .NET-style {0},{1} template.
    static func fmt(_ template: String, _ args: String...) -> String {
        var result = template
        for (i, arg) in args.enumerated() {
            result = result.replacingOccurrences(of: "{\(i)}", with: arg)
        }
        return result
    }
}

/// Helper for dynamic localization using LocalizationManager
private struct LocalizedKey: ExpressibleByStringLiteral, Hashable {
    let key: String
    let comment: String

    init(stringLiteral value: String) {
        self.key = value
        self.comment = ""
    }

    var localized: String {
        LocalizationManager.shared.localizedString(forKey: key, comment: comment)
    }
}

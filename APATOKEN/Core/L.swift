import Foundation

/// Localized string accessors. All keys live in Localizable.xcstrings.
enum L {
    /// UI strings (MAUI resource keys).
    enum ui {
        static var appName: String { NSLocalizedString("app_name", comment: "") }
        static var txtEnterToken: String { NSLocalizedString("txtEnterToken", comment: "") }
        static var txtUploadToken: String { NSLocalizedString("txtUploadToken", comment: "") }
        static var txtPaste: String { NSLocalizedString("txtPaste", comment: "") }
        static var txtDeviceName: String { NSLocalizedString("txtDeviceName", comment: "") }
        static var txtSelect: String { NSLocalizedString("txtSelect", comment: "") }
        static var txtAlertInfo: String { NSLocalizedString("txtAlertInfo", comment: "") }
        static var txtError: String { NSLocalizedString("txtError", comment: "") }
        static var txtPackageVersion: String { NSLocalizedString("txtPackageVersion", comment: "") }
        static var txtPublisher: String { NSLocalizedString("txtPublisher", comment: "") }
        /// iOS port credit line (About ⓘ).
        static var txtIosPort: String { NSLocalizedString("txtIosPort", comment: "") }
        static var txtOk: String { NSLocalizedString("txtOk", comment: "") }
        static var txtExit: String { NSLocalizedString("txtExit", comment: "") }
        static var txtCancel: String { NSLocalizedString("txtCancel", comment: "") }
        static var txtClose: String { NSLocalizedString("txtClose", comment: "") }
        static var txtPrepaidRecharge: String { NSLocalizedString("txtPrepaidRecharge", comment: "") }
        static var txtReadings: String { NSLocalizedString("txtReadings", comment: "") }
        static var txtReadCredits: String { NSLocalizedString("txtReadCredits", comment: "") }
        static var txtCurrentCredits: String { NSLocalizedString("txtCurrentCredits", comment: "") }
        static var txtHistory: String { NSLocalizedString("txtHistory", comment: "") }
        static var txtChargesHistory: String { NSLocalizedString("txtChargesHistory", comment: "") }
        static var txtSettings: String { NSLocalizedString("txtSettings", comment: "") }
        static var txtMenuSettings: String { NSLocalizedString("txtMenuSettings", comment: "") }
        static var txtDetails: String { NSLocalizedString("txtDetails", comment: "") }
        static var txtDate: String { NSLocalizedString("txtDate", comment: "") }
        static var txtCode: String { NSLocalizedString("txtCode", comment: "") }
        static var txtCodeStatus: String { NSLocalizedString("txtCodeStatus", comment: "") }
        static var txtCreditValue: String { NSLocalizedString("txtCreditValue", comment: "") }
        static var txtAfterPrepaidRecharge: String { NSLocalizedString("txtAfterPrepaidRecharge", comment: "") }
        static var txtTotalCredit: String { NSLocalizedString("txtTotalCredit", comment: "") }
        static var txtRecharge: String { NSLocalizedString("txtRecharge", comment: "") }
        static var txtTariffZone: String { NSLocalizedString("txtTariffZone", comment: "") }
        static var txtZone: String { NSLocalizedString("Zone", comment: "") }
        static var txtSingleCharging: String { NSLocalizedString("txtSingleCharging", comment: "") }
        static var txtDualCharging: String { NSLocalizedString("txtDualCharging", comment: "") }
        static var txtDeviceAddress: String { NSLocalizedString("txtDeviceAddress", comment: "") }
        static var txtDeviceId: String { NSLocalizedString("txtDeviceId", comment: "") }
        static var txtSelectDevice: String { NSLocalizedString("txtSelectDevice", comment: "") }
        static var txtAvailableDevices: String { NSLocalizedString("txtAvailableDevices", comment: "") }
        static var txtScanning: String { NSLocalizedString("txtScanning", comment: "") }
        static var txtSampleIdentification: String { NSLocalizedString("txtSampleIdentification", comment: "") }
        static var txtSaveSettings: String { NSLocalizedString("txtSaveSettings", comment: "") }
        static var txtUnknown: String { NSLocalizedString("txtUnknown", comment: "") }
        static var txtMeterNumber: String { NSLocalizedString("txtMeterNumber", comment: "") }
        static var txtLocatedOnTheMeterCasing: String { NSLocalizedString("txtLocatedOnTheMeterCasing", comment: "") }
        static var txtPickValue: String { NSLocalizedString("txtPickValue", comment: "") }
        static var txtResetCredit: String { NSLocalizedString("txtResetCredit", comment: "") }
        static var txtUnlockCommunication: String { NSLocalizedString("txtUnlockCommunication", comment: "") }
    }

    /// App-level messages (MAUI resource keys).
    enum message {
        static var msgOperationSucceeded: String { NSLocalizedString("msgOperationSucceeded", comment: "") }
        static var msgOperationFailed: String { NSLocalizedString("msgOperationFailed", comment: "") }
        static var msgNoResponseFromMeter: String { NSLocalizedString("msgNoResponseFromMeter", comment: "") }
        static var msgUnsuccessfulTokenEntering: String { NSLocalizedString("msgUnsuccessfulTokenEntering", comment: "") }
        static var msgTokenEnteredButNotAccepted: String { NSLocalizedString("msgTokenEnteredButNotAccepted", comment: "") }
        static var msgEnteredTokenIsWrong: String { NSLocalizedString("msgEnteredTokenIsWrong", comment: "") }
        static var msgEnteredTokenAlreadyUsed: String { NSLocalizedString("msgEnteredTokenAlreadyUsed", comment: "") }
        static var msgTooShortToken: String { NSLocalizedString("msgTooShortToken", comment: "") }
        static var msgIncorrentCodeLength: String { NSLocalizedString("msgIncorrentCodeLength", comment: "") }
        static var msgToEnterCodeDeviceMustBeSelected: String { NSLocalizedString("msgToEnterCodeDeviceMustBeSelected", comment: "") }
        static var msgToReadCreditsDeviceMustBeSelected: String { NSLocalizedString("msgToReadCreditsDeviceMustBeSelected", comment: "") }
        static var msgNoAssociatedBluetoothDevice: String { NSLocalizedString("msgNoAssociatedBluetoothDevice", comment: "") }
        static var msgDataReadUnsuccessful: String { NSLocalizedString("msgDataReadUnsuccessful", comment: "") }
        static var msgDataReadUnderProgress: String { NSLocalizedString("msgDataReadUnderProgress", comment: "") }
        static var msgTokenEnteringUnderProgress: String { NSLocalizedString("msgTokenEnteringUnderProgress", comment: "") }
        static var msgStayCloseToTheMeter: String { NSLocalizedString("msgStayCloseToTheMeter", comment: "") }
        static var msgHistoryInformation: String { NSLocalizedString("msgHistoryInformation", comment: "") }
        static var msgNoDeviceFound: String { NSLocalizedString("msgNoDeviceFound", comment: "") }
        static var msgBluetoothNotSupported: String { NSLocalizedString("msgBluetoothNotSupported", comment: "") }
        static var msgNoBluetoothDeviceSelected: String { NSLocalizedString("msgNoBluetoothDeviceSelected", comment: "") }
        static var msgSettingsSaved: String { NSLocalizedString("msgSettingsSaved", comment: "") }
        static var msgSettingsNotSaved: String { NSLocalizedString("msgSettingsNotSaved", comment: "") }
        static var msgSettingsSaveError: String { NSLocalizedString("msgSettingsSaveError", comment: "") }
        static var msgSaveChangedSettingsQ: String { NSLocalizedString("msgSaveChangedSettingsQ", comment: "") }
        static var msgMissingCreditInfo: String { NSLocalizedString("msgMissingCreditInfo", comment: "") }
        static var msgDeviceMissing: String { NSLocalizedString("msgDeviceMissing", comment: "") }
        static var msgCommunicationWithDeviceNotPossible: String { NSLocalizedString("msgCommunicationWithDeviceNotPossible", comment: "") }

        // Token code status descriptions
        static var msgCodeStatusOk: String { NSLocalizedString("msgCodeStatusOk", comment: "") }
        static var msgCodeStatusNotOk: String { NSLocalizedString("msgCodeStatusNotOk", comment: "") }
        static var msgCodeStatusTooOld: String { NSLocalizedString("msgCodeStatusTooOld", comment: "") }
        static var msgCodeStatusUsed: String { NSLocalizedString("msgCodeStatusUsed", comment: "") }
        static var msgCodeStatusAboveLimit: String { NSLocalizedString("msgCodeStatusAboveLimit", comment: "") }
        static var msgCodeStatusBlocked: String { NSLocalizedString("msgCodeStatusBlocked", comment: "") }
        static var msgCodeStatusError: String { NSLocalizedString("msgCodeStatusError", comment: "") }
        static var msgCodeStatusPrepaidOff: String { NSLocalizedString("msgCodeStatusPrepaidOff", comment: "") }
        static var msgCodeStatusUnknown: String { NSLocalizedString("msgCodeStatusUnknown", comment: "") }
        static var msgValidationResultFailure: String { NSLocalizedString("msgValidationResultFailure", comment: "") }

        // Library / protocol messages
        static var msgNoLLC: String { NSLocalizedString("msgNoLLC", comment: "") }
        static var msgEmptyDlmsArray: String { NSLocalizedString("msgEmptyDlmsArray", comment: "") }
        static var msgDlmsArrayIsTooShort: String { NSLocalizedString("msgDlmsArrayIsToShort", comment: "") }
        static var msgNotEnoughData: String { NSLocalizedString("msgNotEnoughDataAvailable", comment: "") }
        static var msgNotEnoughDataAvailable: String { NSLocalizedString("msgNotEnoughDataAvailable", comment: "") }
        static var msgNoData: String { NSLocalizedString("msgNoData", comment: "") }
        static var msgWrongDataType: String { NSLocalizedString("msgWrongDataType", comment: "") }
        static var msgExpectedVsReceived: String { NSLocalizedString("msgExpectedVsReceived", comment: "") }
        static var msgAccessError: String { NSLocalizedString("msgAccessError", comment: "") }
        static var msgWrongPDU: String { NSLocalizedString("msgWrongPDU", comment: "") }
        static var msgWrongHDLCFrameLength: String { NSLocalizedString("msgWrongHDLCFrameLength", comment: "") }
        static var msgWrongHDLCFrameCRC: String { NSLocalizedString("msgWrongHDLCFrameCRC", comment: "") }
        static var msgWrongHDLCHeaderCRC: String { NSLocalizedString("msgWrongHDLCHeaderCRC", comment: "") }
        static var msgBadDataChecksum: String { NSLocalizedString("msgBadDataChecksum", comment: "") }
        static var msgNoHDLCHeader: String { NSLocalizedString("msgNoHDLCHeader", comment: "") }
        static var msgNoHDLCFooter: String { NSLocalizedString("msgNoHDLCFooter", comment: "") }
        static var msgNoHeader: String { NSLocalizedString("msgNoHeader", comment: "") }
        static var msgNoTile: String { NSLocalizedString("msgNoTile", comment: "") }
        static var msgInvalidFrame: String { NSLocalizedString("msgInvalidFrame", comment: "") }
        static var msgBadHeaderChecksum: String { NSLocalizedString("msgBadHeaderChecksum", comment: "") }
        static var msgAssociationError: String { NSLocalizedString("msgAssociationError", comment: "") }
        static var msgProbablyWrongKeys: String { NSLocalizedString("msgProbablyWrongKeys", comment: "") }
        static var msgAttributeAccessError: String { NSLocalizedString("msgAttributeAccessError", comment: "") }
        static var msgMethodAccessError: String { NSLocalizedString("msgMethodAccessError", comment: "") }
        static var msgWrongObisString: String { NSLocalizedString("msgWrongObisString", comment: "") }
        static var msgWrongCharInObisCode: String { NSLocalizedString("msgWrongCharInObisCode", comment: "") }
        static var msgHDLCFrameParsingError: String { NSLocalizedString("msgHDLCFrameParsingError", comment: "") }
        static var msgHDLCFrameCreatingError: String { NSLocalizedString("msgHDLCFrameCreatingError", comment: "") }
        static var msgHdlcNoHdlcFramesToSend: String { NSLocalizedString("msgHdlc_NoHdlcFramesToSend", comment: "") }
        static var msgHdlcSpaceForPayloadNotNegotiated: String { NSLocalizedString("msgHdlc_SpaceForPayloadNotNegotiated", comment: "") }
        static var msgInvalidResponseFrame: String { NSLocalizedString("msgInvalidResponseFrame", comment: "") }
        static var msgWrongResponseFromMeter: String { NSLocalizedString("msgWrongResponseFromMeter", comment: "") }
        static var msgNoResponse: String { NSLocalizedString("msgNoResponse", comment: "") }
        static var msgWrongNumberOfBytes: String { NSLocalizedString("msgWrongNumberOfBytes", comment: "") }
        static var msgWrongValue: String { NSLocalizedString("msgWrongValue", comment: "") }
        static var msgWrongValueFormat: String { NSLocalizedString("msgWrongValueFormat", comment: "") }
        static var msgWrongMemberValueType: String { NSLocalizedString("msgWrongMemberValueType", comment: "") }
        static var msgWrongMemberValue: String { NSLocalizedString("msgWrongMemberValue", comment: "") }
        static var msgWrongNumberOfStructureFields: String { NSLocalizedString("msgWrongNumberOfStructureFields", comment: "") }
        static var msgGivenValueIsNotStructure: String { NSLocalizedString("msgGivenValueIsNotStructure", comment: "") }
        static var msgWrongBinaryRepresentation: String { NSLocalizedString("msgWrongBinaryRepresentation", comment: "") }
        static var msgSimpleDataTypeExpected: String { NSLocalizedString("msgSimpleDataTypeExpected", comment: "") }
        static var msgWrongWrongStatusLength: String { NSLocalizedString("msgWrongStatusLength", comment: "") }
        static var msgEntryTypeMustBeSimple: String { NSLocalizedString("msgEntryTypeMustBeSimple", comment: "") }
        static var msgUnknownError: String { NSLocalizedString("msgUnknownError", comment: "") }
        static var msgUnknownErrorReason: String { NSLocalizedString("msgUnknownErrorReason", comment: "") }
        static var msgUnknownCosemType: String { NSLocalizedString("msgUnknownCosemType", comment: "") }
        static var msgNotImplemented: String { NSLocalizedString("msgNotImplemented", comment: "") }
        static var msgUnsuccessfulPortOpening: String { NSLocalizedString("msgUnsuccessfulPortOpening", comment: "") }
        static var msgUnsuccessfulDataSending: String { NSLocalizedString("msgUnsuccessfulDataSending", comment: "") }
        static var msgUnsuccessfulDataReceiving: String { NSLocalizedString("msgUnsuccessfulDataReceiving", comment: "") }
        static var msgWrongWrapperFrameHeaderLength: String { NSLocalizedString("msgWrongWrapperFrameHeaderLength", comment: "") }
        static var msgWrongWrapperFrameLength: String { NSLocalizedString("msgWrongWrapperFrameLength", comment: "") }
        static var msgUnsuccessfulPDUProcessing: String { NSLocalizedString("msgUnsuccessfulPDUProcessing", comment: "") }
        static var msgTransferError: String { NSLocalizedString("msgTransferError", comment: "") }
        static var msgEntityDoesNotMatch: String { NSLocalizedString("msgEntityDoesNotMatch", comment: "") }
        static var msgEntityClient: String { NSLocalizedString("txtEntityClient", comment: "") }
        static var msgEntityServer: String { NSLocalizedString("txtEntityServer", comment: "") }
        static var msgWrongNumberOfCharsInHexString: String { NSLocalizedString("msgWrongNumberOfCharsInHexString", comment: "") }
        static var msgTransfer_ApplicationContextNameNotSupported: String { NSLocalizedString("msgTransfer_ApplicationContextNameNotSupported", comment: "") }
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

import Foundation

enum L10n {
    enum Key: String, CaseIterable {
        case appChat
        case appClose
        case appDone
        case appLoading
        case appNoContent
        case appError
        case appSearchFiles
        case deepLinkOpening
        case deepLinkInvalid
        case deepLinkSessionUnavailable
        case deepLinkOpenFailed
        case capabilityPermissionTitle
        case capabilityHealthExportTitle
        case capabilityHealthExportDescription
        case capabilityReason
        case capabilityPermissionFooter
        case capabilityAllowOnce
        case capabilityAllowAlways
        case capabilitySettingsTitle
        case capabilityAllowedAutomatically
        case capabilityAskEveryTime
        case capabilityRevoke
        case capabilitySettingsFooter
        case capabilityAlreadyRunning
        case capabilityLaunchFailed
        case capabilityInvalidCallback
        case capabilityContinuationFailed

        case commonOk
        case commonCancel
        case commonRetry

        case carTab
        case navFiles
        case navSettings
        case sidebarHideSessions
        case sidebarShowSessions

        case contentRefreshHelp

        case settingsTitle
        case settingsUsername
        case settingsPassword
        case settingsConnected
        case settingsDisconnected
        case settingsTestConnection
        case settingsSshSetupGuideTitle
        case settingsSshSetupGuideBody
        case settingsAutoTheme
        case settingsLightTheme
        case settingsDarkTheme
        case settingsAppearance
        case settingsTheme
        case settingsSpeechRecognition
        case settingsRecordingStrategy
        case settingsOpenAIRealtime
        case settingsGPTLiveTranscribe
        case settingsGrokBatch
        case settingsStrategyHelp
        case settingsStrategyDialogTitle
        case settingsStrategyDialogBody
        case settingsAiBuilderBaseURL
        case settingsAiBuilderToken
        case settingsCustomPrompt
        case settingsTerminology
        case settingsTesting
        case settingsTestConnectionScope
        case settingsAbout
        case settingsServerVersion
        case settingsExperimentalFeatures
        case settingsCarMode
        case settingsModelShortlist
        case settingsModelShortlistFooter
        case settingsModelShortlistEmpty
        case settingsModelShortlistAdd
        case settingsModelShortlistSearch
        case settingsModelShortlistEditName
        case settingsModelShortlistShortName
        case settingsModelShortlistAddSelected
        case settingsModelShortlistCatalogEmpty
        case settingsModelShortlistHint
        case settingsModelShortlistSearchClear
        case settingsModelShortlistReorder
        case settingsModelShortlistCatalogHint
        case settingsAIUsageDashboard
        case settingsAIUsageDashboardURL
        case settingsAIUsageDashboardFooter
        case settingsRotateKeyTitle
        case settingsRotateKeyPrompt
        case settingsPublicKeyTitle
        case settingsPublicKeyFooter
        case settingsCopyToClipboard
        case settingsPublicKeyCopied
        case settingsPublicKeyCopyFailed
        case settingsPublicKeyRotate
        case settingsPublicKeyErrorTitle
        case settingsRotate
        case settingsTrustHostKeyTitle
        case settingsTrustHostKeyMessage
        case settingsTrustHostKeyConfirm

        case settingsProject
        case settingsProjectServerDefault
        case settingsProjectCustomPath
        case settingsProjectCustomPathPlaceholder
        case settingsProjectMismatchWarning
        case chatCreateDisabledHint

        case hostCurrent
        case hostCurrentFooter
        case hostNoHost
        case hostAddToConnect
        case hostHosts
        case hostDelete
        case hostDuplicate
        case hostEdit
        case hostAdd
        case hostDeviceKey
        case hostCopyDevicePublicKey
        case hostDeviceKeyFooter
        case hostErrorTitle
        case hostNeverConnected
        case hostLastUsed
        case hostOverview
        case hostName
        case hostTransport
        case hostOpenCodeURL
        case hostStatus
        case hostManagedBySSHTunnel
        case hostSavedHost
        case hostSSHTunnel
        case hostSSHGateway
        case hostGatewayHost
        case hostSSHPort
        case hostSSHUsername
        case hostAssignedRemotePort
        case hostConnectionDiagnostics
        case hostUseThisHost
        case hostConfigCopied
        case hostCopyConfigJSON
        case hostNotFound
        case hostImportConfig
        case hostImportFooter
        case hostConnectionType
        case hostTransportFooter
        case hostSSHGatewayFooter
        case hostDeviceKeySendFooter
        case hostBasicAuth
        case hostSaveHelp
        case hostSave
        case hostEditTitle
        case hostAddTitle
        case hostTitle
        case hostTransportDirect
        case hostUntitled
        case hostDefaultLocalName
        case hostDefaultSSHName
        case hostDuplicateName
        case hostImportErrorDirectRequiresServerURL
        case hostImportErrorSSHTunnelRequiresSSHSettings
        case hostDeleteOnlyHostError
        case hostImportErrorInvalidUTF8
        case hostExportErrorEncodeConfigJSON
        case hostConnectionErrorInvalidURL
        case hostConnectionErrorBasicAuthRejected
        case hostConnectionErrorUnrecognizedGeneration
        case hostConnectionErrorHTTPStatus
        case hostConnectionErrorCannotConnect
        case hostConnectionErrorTimedOut
        case hostConnectionErrorDNS
        case hostConnectionErrorNetwork
        case hostConnectionErrorHealthCheckFailed
        case hostConnectionErrorGeneric
        case hostDiagnosticCheckingHealth
        case hostDiagnosticCheckingHealthURL
        case hostDiagnosticConnectingSSHGateway
        case hostDiagnosticHintConfirmGateway
        case hostDiagnosticSSHTunnelFailed
        case hostDiagnosticHintCopyDeviceKeyAgain
        case hostDiagnosticTunnelReadyCheckingHealth
        case hostDiagnosticHintURLFormat
        case hostDiagnosticConnectedToOpenCode
        case hostDiagnosticHealthUnhealthy
        case hostDiagnosticHintCheckServerLogs
        case hostDiagnosticHintVerifyHostConfig
        case hostDiagnosticLocalListenerFailed
        case hostValidationVPSHostRequired
        case hostValidationSSHUsernameRequired
        case hostValidationSSHPortPositive
        case hostValidationAssignedRemotePortPositive
        case hostSSHTunnelUnavailableVisionOS
        case sshErrorConnectionFailed
        case sshErrorAuthenticationFailed
        case sshErrorKeyNotFound
        case sshErrorInvalidKeyFormat
        case sshErrorTunnelFailed
        case sshErrorHostKeyMismatch
        case sshErrorKeyUnavailable
        case keychainErrorUnhandledStatus

        case connectionPhaseIdle
        case connectionPhaseSSHGateway
        case connectionPhaseSSHAuth
        case connectionPhaseLocalTunnel
        case connectionPhaseHealth
        case connectionPhaseBootstrap
        case connectionPhaseConnected
        case connectionPhaseFailed

        case chatInputPlaceholder
        case chatSendFailed
        case chatRenameSession
        case chatRenameSessionPlaceholder
        case chatTitleField
        case chatSpeechTitle
        case chatSelectSessionFirst
        case chatSessionBusyMessage
        case chatNoMessages
        case chatTurnCompleted
        case chatSpeechTokenMissing
        case chatSpeechTesting
        case chatSpeechNotPassed
        case chatSpeechStreamDisconnected
        case chatSpeechTapToSpeak
        case chatSpeechListening
        case chatSpeechTranscriptWillAppear
        case chatSpeechRecovering
        case chatSpeechTranscribing
        case chatSpeechTranscribingHint
        case chatSpeechPreservedAudio
        case chatSpeechStopWaiting
        case chatSpeechRetrySegment
        case chatSpeechDiscardAudio
        case chatAbortAgent
        case chatAgentRunning
        case chatBackgroundTasksOne
        case chatBackgroundTasksMany
        case chatBackgroundTasksAccessibility
        case chatMicrophoneDenied
        case chatSessionStatusBusy
        case chatSessionStatusRetrying
        case chatSessionStatusIdle
        case chatPullToLoadMore
        case chatLoadingMoreHistory
        case chatLargeMessagePreviewNotice
        case chatSelectText
        case chatCopyMessage
        case chatEditFromHere
        case chatForkFromHere
        case chatThinkingCard
        case taskNotificationCompleted
        case taskNotificationFailed
        case taskNotificationOpenSession
        case taskNotificationNoOutput
        case carTitle
        case carReady
        case carListening
        case carFinalizing
        case carWorking
        case carSpeaking
        case carNeedsConfirmation
        case carFailed
        case carStartSpeaking
        case carStopAndSend
        case carStopSpeaking
        case carStopResponse
        case carSpeakConfirmation
        case carEmptyPrompt
        case carNewSession
        case carNewSessionPrompt
        case carConfirmUtterance
        case carCancelUtterance
        case carNotConnected
        case carServerDefaultRequired
        case carInvalidResponse
        case carUnsupportedAction
        case carMapsUnavailable
        case carTranscriptionFailed
        case attachmentImageTitle
        case attachmentFileTitle
        case attachmentRemoveImageAccessibilityLabel
        case attachmentImageReadFailed
        case attachmentImageTooLargeAfterCompression

        case permissionAllowOnce
        case permissionAllowAlways
        case permissionReject
        case questionTitle
        case questionSingleHint
        case questionMultiHint
        case questionTypeOwnAnswer
        case questionCustomPlaceholder
        case questionDismiss
        case questionSubmit
        case questionBack
        case questionNext
        case questionOf

        case toolReason
        case toolCommandInput
        case toolPath
        case toolOutput
        case toolOpenInFileTree
        case toolOpenFile
        case toolSelectFile
        case toolCallsCountOne
        case toolCallsCountMany
        case toolImageFile
        case toolReadFileAccessibilityLabel
        case toolWriteFileAccessibilityLabel
        case toolReadDirectoryAccessibilityLabel
        case folderEmptyTitle
        case folderEmptyDescription

        case patchFilesChangedOne
        case patchFilesChangedMany

        case contextUsageHelp
        case contextUsageClose
        case contextUsageTitle
        case contextUsageSectionSession
        case contextUsageSectionModel
        case contextUsageSectionTokens
        case contextUsageSectionCost
        case contextUsageTitleLabel
        case contextUsageIdLabel
        case contextUsageProviderLabel
        case contextUsageModelLabel
        case contextUsageLimitLabel
        case contextUsageTotalLabel
        case contextUsageInputLabel
        case contextUsageOutputLabel
        case contextUsageReasoningLabel
        case contextUsageCachedReadLabel
        case contextUsageCachedWriteLabel
        case contextUsageNoCostData
        case contextUsageLoadingConfig
        case contextUsageNoUsageData
        case contextUsageConfigNotLoaded
        case contextUsageSectionThroughput
        case contextUsageThroughputAvg
        case contextUsageThroughputTime
        case contextUsageThroughputTokens
        case contextUsageThroughputNoData
        case statusRoundsLabel
        case statusToolsLabel
        case statusTokensLabel
        case statusCacheHitsLabel
        case statusSinceLastPromptLabel
        case quotaTitle
        case quotaDataSource
        case quotaNotLoaded
        case quotaLoading
        case quotaRefreshing
        case quotaRefreshingProviders
        case quotaNoCachedData
        case quotaStale
        case quotaLastFetched
        case quotaGeneratedAt
        case quotaRemainingFormat
        case quotaUsedFormat
        case quotaResetFormat
        case quotaCurrentModelAccessibility

        case sessionTitle
        case sessionsTitle
        case sessionsEmptyTitle
        case sessionsEmptyDescription
        case sessionsClose
        case sessionsNew
        case sessionsUntitled
        case sessionsFilesOne
        case sessionsFilesMany
        case sessionsStatusBusy
        case sessionsStatusRetry
        case sessionsStatusIdle
        case sessionsStatusNeedAttention
        case sessionsStatusSubagentsRunningOne
        case sessionsStatusSubagentsRunningMany
        case sessionsActive
        case sessionsArchived
        case sessionsArchive
        case sessionsRestore
        case sessionsLoadMore
        case sessionsActionFailedTitle
        case sessionsDelete

        case fileBinary
        case fileNoContent
        case filePreviewMode
        case fileNativePreview
        case fileWebPreview
        case fileMarkdownSource
        case contentImageDecodeFailed
        case contentNoImageData
        case markdownPreviewLoading
        case markdownWebPreviewLoading
        case markdownWebPreviewLargeDocumentTitle
        case markdownWebPreviewLargeDocumentDescription
        case markdownWebPreviewRenderAnyway
        case markdownWebPreviewOpenNative
        case markdownWebPreviewOpenSource
        case markdownWebPreviewFailedTitle
        case markdownWebPreviewAssetsMissing
        case markdownWebPreviewPayloadEncodeFailed
        case markdownWebPreviewRenderCallFailed
        case markdownWebPreviewWebViewLoadFailed
        case markdownWebPreviewWebViewProvisionalLoadFailed
        case markdownWebPreviewUnknownRenderError

        case errorConnectionFailed
        case errorServerError
        case errorInvalidResponse
        case errorUnauthorized
        case errorSessionNotFound
        case errorFileNotFound
        case errorOperationFailed
        case errorUnknown
        case errorAiBuilderTokenEmpty
        case errorInvalidBaseURL
        case errorServerAddressEmpty
        case errorWanRequiresHttps
        case errorUsingLanHttp
        case helpLanHttp
        case helpWanHttp
        case helpTailscaleHttp

        case activityRetrying
        case activityThinking
        case activityDelegating
        case activityPlanning
        case activityGatheringContext
        case activitySearchingCodebase
        case activitySearchingWeb
        case activityMakingEdits
        case activityRunningCommands
        case activityGatheringThoughts
        case configureTitle
        case configureModel
        case configureAgent
        case configureNoAgents
        case configureModelSearchPlaceholder
        case configureModelNoMatches
        case configureModelEmptyShortlist
        case configureModelEditShortlist

        case todoPanelTitle
        case todoPanelCompleted
        case todoPanelEmpty
        case todoUpdatedBadge
    }

    nonisolated private static let en: [String: String] = [
        Key.appChat.rawValue: "Chat",
        Key.appClose.rawValue: "Close",
        Key.appDone.rawValue: "Done",
        Key.appLoading.rawValue: "Loading...",
        Key.appNoContent.rawValue: "No content",
        Key.appError.rawValue: "Error",
        Key.appSearchFiles.rawValue: "Search files",
        Key.deepLinkOpening.rawValue: "Opening session...",
        Key.deepLinkInvalid.rawValue: "This OpenCode session link is invalid.",
        Key.deepLinkSessionUnavailable.rawValue: "This session is not available on the current host. It may belong to another host or exist only in offline history.",
        Key.deepLinkOpenFailed.rawValue: "OpenCode could not open this session. Check the current host connection and try again.",
        Key.capabilityPermissionTitle.rawValue: "Client Capability",
        Key.capabilityHealthExportTitle.rawValue: "Sync Health Quantification data",
        Key.capabilityHealthExportDescription.rawValue: "Export the latest HealthKit data to the configured Health Quantification server.",
        Key.capabilityReason.rawValue: "Reason",
        Key.capabilityPermissionFooter.rawValue: "OpenCode constructs a one-time callback. Health details are not returned through the link.",
        Key.capabilityAllowOnce.rawValue: "Allow Once",
        Key.capabilityAllowAlways.rawValue: "Always Allow",
        Key.capabilitySettingsTitle.rawValue: "Client Capabilities",
        Key.capabilityAllowedAutomatically.rawValue: "Allowed automatically",
        Key.capabilityAskEveryTime.rawValue: "Ask every time",
        Key.capabilityRevoke.rawValue: "Revoke Automatic Access",
        Key.capabilitySettingsFooter.rawValue: "Automatic access only applies to exporting Health data. It does not authorize analysis or other side effects.",
        Key.capabilityAlreadyRunning.rawValue: "A Health export is already in progress.",
        Key.capabilityLaunchFailed.rawValue: "Health Quantification is not installed or could not be opened.",
        Key.capabilityInvalidCallback.rawValue: "OpenCode rejected an invalid or expired Health export callback.",
        Key.capabilityContinuationFailed.rawValue: "The Health export finished, but OpenCode could not continue the original session.",
        Key.commonOk.rawValue: "OK",
        Key.commonCancel.rawValue: "Cancel",
        Key.commonRetry.rawValue: "Retry",
        Key.carTab.rawValue: "Car",
        Key.navFiles.rawValue: "Files",
        Key.navSettings.rawValue: "Settings",
        Key.sidebarHideSessions.rawValue: "Hide sessions",
        Key.sidebarShowSessions.rawValue: "Show sessions",
        Key.contentRefreshHelp.rawValue: "Refresh preview",

        Key.settingsTitle.rawValue: "Settings",
        Key.settingsUsername.rawValue: "Username",
        Key.settingsPassword.rawValue: "Password",
        Key.settingsConnected.rawValue: "Connected",
        Key.settingsDisconnected.rawValue: "Disconnected",
        Key.settingsTestConnection.rawValue: "Test Connection",
        Key.settingsPublicKeyCopied.rawValue: "Public Key Copied",
        Key.settingsSshSetupGuideTitle.rawValue: "SSH Gateway Setup",
        Key.settingsSshSetupGuideBody.rawValue: "1. Tap Copy Public Key and send it to the server admin.\n\n2. The admin adds this device key to your user and gives you Host, SSH Port, Username, and Assigned Remote Port. For opencode-private-host, Username is usually opencode, SSH Port is usually 8006, and the first user's Remote Port is usually 19001.\n\n3. Fill those values here, enable SSH Tunnel, then tap Set Server Address to 127.0.0.1:4096.\n\n4. Tap Test Connection. The app will connect to local 127.0.0.1:4096; the SSH tunnel forwards it to your private OpenCode container.\n\n5. If provider auth is not configured yet, ask the admin to complete the first provider login in the OpenCode Web UI.",
        Key.settingsAutoTheme.rawValue: "Auto",
        Key.settingsLightTheme.rawValue: "Light",
        Key.settingsDarkTheme.rawValue: "Dark",
        Key.settingsAppearance.rawValue: "Appearance",
        Key.settingsTheme.rawValue: "Theme",
        Key.settingsSpeechRecognition.rawValue: "Speech Recognition",
        Key.settingsRecordingStrategy.rawValue: "Recording Strategy",
        Key.settingsOpenAIRealtime.rawValue: "GPT Realtime",
        Key.settingsGPTLiveTranscribe.rawValue: "GPT Live Transcribe",
        Key.settingsGrokBatch.rawValue: "Grok STT",
        Key.settingsStrategyHelp.rawValue: "Which one should I choose?",
        Key.settingsStrategyDialogTitle.rawValue: "Which one should I choose?",
        Key.settingsStrategyDialogBody.rawValue: "GPT Realtime — conversational realtime transcription with strong formatting and punctuation.\n\nGPT Live Transcribe — dedicated live transcription over the same realtime transport.\n\nGrok STT — lower-cost batch transcription. Records locally and uploads after Stop.",
        Key.settingsAiBuilderBaseURL.rawValue: "AI Builder Base URL",
        Key.settingsAiBuilderToken.rawValue: "AI Builder Token",
        Key.settingsCustomPrompt.rawValue: "Custom Prompt",
        Key.settingsTerminology.rawValue: "Terminology (comma-separated)",
        Key.settingsTesting.rawValue: "Testing...",
        Key.settingsTestConnectionScope.rawValue: "Test Connection checks endpoint and token access only. It does not validate the selected transcription strategy.",
        Key.settingsAbout.rawValue: "About",
        Key.settingsServerVersion.rawValue: "Server Version",
        Key.settingsExperimentalFeatures.rawValue: "Experimental Features",
        Key.settingsCarMode.rawValue: "Car Mode",
        Key.settingsModelShortlist.rawValue: "Models",
        Key.settingsModelShortlistFooter.rawValue: "The chat picker only shows this shortlist. Add models from the connected server.",
        Key.settingsModelShortlistEmpty.rawValue: "No models yet. Tap + to search and add.",
        Key.settingsModelShortlistAdd.rawValue: "Add Models",
        Key.settingsModelShortlistSearch.rawValue: "Search catalog",
        Key.settingsModelShortlistEditName.rawValue: "Short Name",
        Key.settingsModelShortlistShortName.rawValue: "Toolbar label",
        Key.settingsModelShortlistAddSelected.rawValue: "Add",
        Key.settingsModelShortlistCatalogEmpty.rawValue: "Connect to a server to load the model catalog.",
        Key.settingsModelShortlistHint.rawValue: "The chat picker shows this list, in this order. Drag to rearrange, swipe left to delete. Tap + to add models.",
        Key.settingsModelShortlistSearchClear.rawValue: "Clear search",
        Key.settingsModelShortlistReorder.rawValue: "Reorder",
        Key.settingsModelShortlistCatalogHint.rawValue: "Search and tap to select. Add puts the checked models on your list. To remove one, go back and swipe it away.",
        Key.settingsAIUsageDashboard.rawValue: "AI Usage Dashboard",
        Key.settingsAIUsageDashboardURL.rawValue: "Dashboard URL (optional)",
        Key.settingsAIUsageDashboardFooter.rawValue: "Leave blank for no quota UI. Enter the dashboard base URL or the full /api/v1/quotas endpoint.",
        Key.settingsRotateKeyTitle.rawValue: "Rotate SSH Key?",
        Key.settingsRotateKeyPrompt.rawValue: "This will generate a new key pair for this device. Update the public key on your SSH server before using SSH tunnel hosts again.",
        Key.settingsPublicKeyTitle.rawValue: "Your Public Key",
        Key.settingsPublicKeyFooter.rawValue: "Send this public key to the server admin. Do not share your private key.",
        Key.settingsCopyToClipboard.rawValue: "Copy to Clipboard",
        Key.settingsPublicKeyCopyFailed.rawValue: "Unable to load SSH public key.",
        Key.settingsPublicKeyRotate.rawValue: "Rotate Key",
        Key.settingsPublicKeyErrorTitle.rawValue: "Public Key Error",
        Key.settingsRotate.rawValue: "Rotate",
        Key.settingsTrustHostKeyTitle.rawValue: "Trust New SSH Host Key?",
        Key.settingsTrustHostKeyMessage.rawValue: "%@:%d presented a different host key.\n\nPrevious: %@\nNew: %@\n\nTrust it only if you expected the server to be rebuilt or reinstalled.",
        Key.settingsTrustHostKeyConfirm.rawValue: "Trust and Reconnect",
        Key.settingsProject.rawValue: "Project (Workspace)",
        Key.settingsProjectServerDefault.rawValue: "Server default",
        Key.settingsProjectCustomPath.rawValue: "Custom path",
        Key.settingsProjectCustomPathPlaceholder.rawValue: "/path/to/project",
        Key.settingsProjectMismatchWarning.rawValue: "Server default project is {server}. New sessions will be created there, not in {effective}. To create sessions in {effective}, start OpenCode from the command line with that project as working directory.",
        Key.chatCreateDisabledHint.rawValue: "New sessions can only be created when using Server default project. To create sessions in another project, start OpenCode from the command line with a different working directory, then select Server default here.",

        Key.hostCurrent.rawValue: "Current Host",
        Key.hostCurrentFooter.rawValue: "A host is one OpenCode environment. It can be reached directly over LAN, Tailscale, VPN, HTTPS, or through an SSH tunnel.",
        Key.hostNoHost.rawValue: "No Host",
        Key.hostAddToConnect.rawValue: "Add a host to connect",
        Key.hostHosts.rawValue: "Hosts",
        Key.hostDelete.rawValue: "Delete",
        Key.hostDuplicate.rawValue: "Duplicate",
        Key.hostEdit.rawValue: "Edit",
        Key.hostAdd.rawValue: "Add Host",
        Key.hostDeviceKey.rawValue: "Device Key",
        Key.hostCopyDevicePublicKey.rawValue: "Copy This Device Public Key",
        Key.hostDeviceKeyFooter.rawValue: "Use this same device key for SSH tunnel hosts. Direct hosts do not need it.",
        Key.hostErrorTitle.rawValue: "Host Error",
        Key.hostNeverConnected.rawValue: "Never connected",
        Key.hostLastUsed.rawValue: "Last used %@",
        Key.hostOverview.rawValue: "Overview",
        Key.hostName.rawValue: "Name",
        Key.hostTransport.rawValue: "Transport",
        Key.hostOpenCodeURL.rawValue: "OpenCode URL",
        Key.hostStatus.rawValue: "Status",
        Key.hostManagedBySSHTunnel.rawValue: "Managed by SSH tunnel",
        Key.hostSavedHost.rawValue: "Saved Host",
        Key.hostSSHTunnel.rawValue: "SSH Tunnel",
        Key.hostSSHGateway.rawValue: "SSH Gateway",
        Key.hostGatewayHost.rawValue: "Gateway Host",
        Key.hostSSHPort.rawValue: "SSH Port",
        Key.hostSSHUsername.rawValue: "SSH Username",
        Key.hostAssignedRemotePort.rawValue: "Assigned Remote Port",
        Key.hostConnectionDiagnostics.rawValue: "Connection Diagnostics",
        Key.hostUseThisHost.rawValue: "Use This Host",
        Key.hostConfigCopied.rawValue: "Host Config Copied",
        Key.hostCopyConfigJSON.rawValue: "Copy Host Config JSON",
        Key.hostNotFound.rawValue: "Host not found",
        Key.hostImportConfig.rawValue: "Import Host Config",
        Key.hostImportFooter.rawValue: "Paste a setup JSON from your server admin, or continue with manual setup below.",
        Key.hostConnectionType.rawValue: "Connection Type",
        Key.hostTransportFooter.rawValue: "Direct is for LAN, VPN, Tailscale, or HTTPS. SSH Tunnel is for an OpenCode server behind an SSH gateway.",
        Key.hostSSHGatewayFooter.rawValue: "These values come from your OpenCode host admin. The app connects locally through the tunnel after this is saved.",
        Key.hostDeviceKeySendFooter.rawValue: "Send this public key to the server admin before testing. Never share the private key.",
        Key.hostBasicAuth.rawValue: "Basic Auth",
        Key.hostSaveHelp.rawValue: "Save is enabled after required fields are present. Test verifies the selected transport and OpenCode health endpoint.",
        Key.hostSave.rawValue: "Save",
        Key.hostEditTitle.rawValue: "Edit Host",
        Key.hostAddTitle.rawValue: "Add Host",
        Key.hostTitle.rawValue: "Host",
        Key.hostTransportDirect.rawValue: "Direct",
        Key.hostUntitled.rawValue: "Untitled Host",
        Key.hostDefaultLocalName.rawValue: "Local OpenCode",
        Key.hostDefaultSSHName.rawValue: "SSH OpenCode",
        Key.hostDuplicateName.rawValue: "%@ Copy",
        Key.hostImportErrorDirectRequiresServerURL.rawValue: "Direct host config requires serverURL.",
        Key.hostImportErrorSSHTunnelRequiresSSHSettings.rawValue: "SSH Tunnel host config requires ssh settings.",
        Key.hostDeleteOnlyHostError.rawValue: "Add another host before deleting this one.",
        Key.hostImportErrorInvalidUTF8.rawValue: "Host config is not valid UTF-8.",
        Key.hostExportErrorEncodeConfigJSON.rawValue: "Could not encode Host Config JSON.",
        Key.hostConnectionErrorInvalidURL.rawValue: "Invalid OpenCode URL. Check the host address and port.",
        Key.hostConnectionErrorBasicAuthRejected.rawValue: "OpenCode rejected Basic Auth. Check username and password.",
        Key.hostConnectionErrorUnrecognizedGeneration.rawValue: "Server is not a recognizable OpenCode v1 or v2 API (health: HTTP %@, info: HTTP %@).",
        Key.hostConnectionErrorHTTPStatus.rawValue: "OpenCode returned HTTP %d. Check the server logs or provider setup.",
        Key.hostConnectionErrorCannotConnect.rawValue: "Could not connect to OpenCode. Check network reachability and that the server is running.",
        Key.hostConnectionErrorTimedOut.rawValue: "Connection timed out. Check the host, port, VPN/Tailscale, and firewall.",
        Key.hostConnectionErrorDNS.rawValue: "Host name could not be resolved. Check the gateway or server host spelling.",
        Key.hostConnectionErrorNetwork.rawValue: "Network error: %@",
        Key.hostConnectionErrorHealthCheckFailed.rawValue: "OpenCode health check failed. Check that the server is running and reachable.",
        Key.hostConnectionErrorGeneric.rawValue: "Connection failed. Check the host configuration and try again.",
        Key.hostDiagnosticCheckingHealth.rawValue: "Checking OpenCode health...",
        Key.hostDiagnosticCheckingHealthURL.rawValue: "Checking %@/global/health...",
        Key.hostDiagnosticConnectingSSHGateway.rawValue: "Connecting to SSH gateway...",
        Key.hostDiagnosticHintConfirmGateway.rawValue: "Confirm the gateway host, SSH port, device public key, and network reachability.",
        Key.hostDiagnosticSSHTunnelFailed.rawValue: "SSH tunnel failed: %@",
        Key.hostDiagnosticHintCopyDeviceKeyAgain.rawValue: "Copy this device public key again if the server has not authorized it.",
        Key.hostDiagnosticTunnelReadyCheckingHealth.rawValue: "SSH tunnel is ready; checking OpenCode health...",
        Key.hostDiagnosticHintURLFormat.rawValue: "Use host:port, http://host:port, or https://host:port.",
        Key.hostDiagnosticConnectedToOpenCode.rawValue: "Connected to OpenCode%@.",
        Key.hostDiagnosticHealthUnhealthy.rawValue: "OpenCode health check returned unhealthy.",
        Key.hostDiagnosticHintCheckServerLogs.rawValue: "Check the OpenCode server process and logs.",
        Key.hostDiagnosticHintVerifyHostConfig.rawValue: "For SSH tunnel hosts, first verify the gateway values and device key. For direct hosts, verify the URL from this device.",
        Key.hostDiagnosticLocalListenerFailed.rawValue: "Local listener failed: %@",
        Key.hostValidationVPSHostRequired.rawValue: "VPS Host is required",
        Key.hostValidationSSHUsernameRequired.rawValue: "SSH Username is required",
        Key.hostValidationSSHPortPositive.rawValue: "SSH Port must be > 0",
        Key.hostValidationAssignedRemotePortPositive.rawValue: "Assigned Remote Port must be > 0",
        Key.hostSSHTunnelUnavailableVisionOS.rawValue: "SSH tunnels are not available in the visionOS build yet. Connect directly to an OpenCode server instead.",
        Key.sshErrorConnectionFailed.rawValue: "Connection failed: %@",
        Key.sshErrorAuthenticationFailed.rawValue: "Authentication failed. Please check your public key is added to the server.",
        Key.sshErrorKeyNotFound.rawValue: "SSH key not found. Please generate a key pair first.",
        Key.sshErrorInvalidKeyFormat.rawValue: "Invalid SSH key format.",
        Key.sshErrorTunnelFailed.rawValue: "Tunnel failed: %@",
        Key.sshErrorHostKeyMismatch.rawValue: "Host key mismatch. Expected %@, got %@. This may be a MITM attack or a reinstalled server. Reset trusted host and verify fingerprint before reconnecting.",
        Key.sshErrorKeyUnavailable.rawValue: "SSH key is unavailable right now. Unlock the device and try again.",
        Key.keychainErrorUnhandledStatus.rawValue: "Keychain operation failed (OSStatus %d).",

        Key.connectionPhaseIdle.rawValue: "Idle",
        Key.connectionPhaseSSHGateway.rawValue: "Connecting to SSH gateway",
        Key.connectionPhaseSSHAuth.rawValue: "Authenticating with device key",
        Key.connectionPhaseLocalTunnel.rawValue: "Starting local tunnel",
        Key.connectionPhaseHealth.rawValue: "Checking OpenCode health",
        Key.connectionPhaseBootstrap.rawValue: "Loading projects and sessions",
        Key.connectionPhaseConnected.rawValue: "Connected",
        Key.connectionPhaseFailed.rawValue: "Connection failed",

        Key.chatInputPlaceholder.rawValue: "Ask anything...",
        Key.chatSendFailed.rawValue: "Send failed",
        Key.chatRenameSession.rawValue: "Rename Session",
        Key.chatRenameSessionPlaceholder.rawValue: "Input new title",
        Key.chatTitleField.rawValue: "Title",
        Key.chatSpeechTitle.rawValue: "Speech Recognition",
        Key.chatSelectSessionFirst.rawValue: "Please pick a session first",
        Key.chatSessionBusyMessage.rawValue: "Session is running, messages are not visible yet, refreshing...",
        Key.chatNoMessages.rawValue: "No messages yet",
        Key.chatTurnCompleted.rawValue: "Completed",
        Key.chatSpeechTokenMissing.rawValue: "Speech recognition is not configured. Set AI Builder Token in Settings → Speech Recognition and tap Test Connection.",
        Key.chatSpeechTesting.rawValue: "AI Builder connection is being tested, please wait.",
        Key.chatSpeechNotPassed.rawValue: "AI Builder connection test failed. Go to Settings → Speech Recognition, tap Test Connection, and confirm it's OK before recording.",
        Key.chatSpeechStreamDisconnected.rawValue: "The speech connection was lost and couldn't recover. Tap stop and try again.",
        Key.chatSpeechTapToSpeak.rawValue: "Tap to speak",
        Key.chatSpeechListening.rawValue: "Listening...",
        Key.chatSpeechTranscriptWillAppear.rawValue: "Transcript will appear here...",
        Key.chatSpeechRecovering.rawValue: "Reconnecting voice...",
        Key.chatSpeechTranscribing.rawValue: "Transcribing...",
        Key.chatSpeechTranscribingHint.rawValue: "Finishing transcript...",
        Key.chatSpeechPreservedAudio.rawValue: "Audio saved. Retry this segment.",
        Key.chatSpeechStopWaiting.rawValue: "Stop transcription wait",
        Key.chatSpeechRetrySegment.rawValue: "Retry this segment",
        Key.chatSpeechDiscardAudio.rawValue: "Discard audio",
        Key.chatAbortAgent.rawValue: "Interrupt agent",
        Key.chatAgentRunning.rawValue: "Agent running",
        Key.chatBackgroundTasksOne.rawValue: "Subagent running",
        Key.chatBackgroundTasksMany.rawValue: "%d subagents running",
        Key.chatBackgroundTasksAccessibility.rawValue: "Subagent running in background. Tap to open subagent session.",
        Key.chatMicrophoneDenied.rawValue: "Microphone permission denied",
        Key.chatSessionStatusBusy.rawValue: "Running",
        Key.chatSessionStatusRetrying.rawValue: "Retrying",
        Key.chatSessionStatusIdle.rawValue: "Idle",
        Key.chatPullToLoadMore.rawValue: "Pull down to load more history",
        Key.chatLoadingMoreHistory.rawValue: "Loading more history...",
        Key.chatLargeMessagePreviewNotice.rawValue: "Large message: showing first %@ of %@ characters. Markdown rendering is skipped to keep the app responsive.",
        Key.chatSelectText.rawValue: "Select Text",
        Key.chatCopyMessage.rawValue: "Copy Message",
        Key.chatEditFromHere.rawValue: "Edit from here",
        Key.chatForkFromHere.rawValue: "Fork from here",
        Key.chatThinkingCard.rawValue: "Thinking",
        Key.taskNotificationCompleted.rawValue: "Completed",
        Key.taskNotificationFailed.rawValue: "Failed",
        Key.taskNotificationOpenSession.rawValue: "Open subagent session",
        Key.taskNotificationNoOutput.rawValue: "No output",
        Key.carTitle.rawValue: "Car Mode",
        Key.carReady.rawValue: "Ready",
        Key.carListening.rawValue: "Listening",
        Key.carFinalizing.rawValue: "Finishing transcript",
        Key.carWorking.rawValue: "OpenCode is working",
        Key.carSpeaking.rawValue: "Speaking",
        Key.carNeedsConfirmation.rawValue: "Confirmation needed",
        Key.carFailed.rawValue: "Needs attention",
        Key.carStartSpeaking.rawValue: "Start speaking",
        Key.carStopAndSend.rawValue: "Stop and send",
        Key.carStopSpeaking.rawValue: "Stop speaking",
        Key.carStopResponse.rawValue: "Stop response",
        Key.carSpeakConfirmation.rawValue: "Say confirm or cancel",
        Key.carEmptyPrompt.rawValue: "Ask about home, messages, traffic, or where to go.",
        Key.carNewSession.rawValue: "New Car Session",
        Key.carNewSessionPrompt.rawValue: "Start a new Car session and leave the current context behind?",
        Key.carConfirmUtterance.rawValue: "Confirm.",
        Key.carCancelUtterance.rawValue: "Cancel.",
        Key.carNotConnected.rawValue: "Connect to OpenCode before using Car Mode.",
        Key.carServerDefaultRequired.rawValue: "Car Mode can create sessions only in the Server default workspace.",
        Key.carInvalidResponse.rawValue: "OpenCode returned an invalid Car Mode response.",
        Key.carUnsupportedAction.rawValue: "OpenCode requested an unsupported client action.",
        Key.carMapsUnavailable.rawValue: "Apple Maps could not open this route.",
        Key.carTranscriptionFailed.rawValue: "The recording could not be transcribed.",
        Key.attachmentImageTitle.rawValue: "Image",
        Key.attachmentFileTitle.rawValue: "Attachment",
        Key.attachmentRemoveImageAccessibilityLabel.rawValue: "Remove image",
        Key.attachmentImageReadFailed.rawValue: "Could not read the selected image.",
        Key.attachmentImageTooLargeAfterCompression.rawValue: "Image is too large after compression (%@ MB). Please choose a smaller image.",

        Key.permissionAllowOnce.rawValue: "Allow Once",
        Key.permissionAllowAlways.rawValue: "Allow Always",
        Key.permissionReject.rawValue: "Reject",
        Key.questionTitle.rawValue: "Question",
        Key.questionSingleHint.rawValue: "Select one option",
        Key.questionMultiHint.rawValue: "Select one or more options",
        Key.questionTypeOwnAnswer.rawValue: "Type your own answer",
        Key.questionCustomPlaceholder.rawValue: "Type your answer...",
        Key.questionDismiss.rawValue: "Dismiss",
        Key.questionSubmit.rawValue: "Submit",
        Key.questionBack.rawValue: "Back",
        Key.questionNext.rawValue: "Next",
        Key.questionOf.rawValue: "%d of %d",

        Key.toolReason.rawValue: "Reason",
        Key.toolCommandInput.rawValue: "Command / Input",
        Key.toolPath.rawValue: "Path",
        Key.toolOutput.rawValue: "Output",
        Key.toolOpenInFileTree.rawValue: "Open \"%@\" in File Tree",
        Key.toolOpenFile.rawValue: "Open File",
        Key.toolSelectFile.rawValue: "Select file to open",
        Key.toolCallsCountOne.rawValue: "%d tool call",
        Key.toolCallsCountMany.rawValue: "%d tool calls",
        Key.toolImageFile.rawValue: "Image file",
        Key.toolReadFileAccessibilityLabel.rawValue: "Read file %@",
        Key.toolWriteFileAccessibilityLabel.rawValue: "Write file %@",
        Key.toolReadDirectoryAccessibilityLabel.rawValue: "Read directory %@",
        Key.folderEmptyTitle.rawValue: "Empty folder",
        Key.folderEmptyDescription.rawValue: "This directory has no entries.",

        Key.patchFilesChangedOne.rawValue: "%d file changed",
        Key.patchFilesChangedMany.rawValue: "%d files changed",

        Key.contextUsageHelp.rawValue: "Context usage",
        Key.contextUsageClose.rawValue: "Close",
        Key.contextUsageTitle.rawValue: "Context",
        Key.contextUsageSectionSession.rawValue: "Session",
        Key.contextUsageSectionModel.rawValue: "Model",
        Key.contextUsageSectionTokens.rawValue: "Tokens",
        Key.contextUsageSectionCost.rawValue: "Cost",
        Key.contextUsageTitleLabel.rawValue: "Title",
        Key.contextUsageIdLabel.rawValue: "ID",
        Key.contextUsageProviderLabel.rawValue: "Provider",
        Key.contextUsageModelLabel.rawValue: "Model",
        Key.contextUsageLimitLabel.rawValue: "Context limit",
        Key.contextUsageTotalLabel.rawValue: "Total",
        Key.contextUsageInputLabel.rawValue: "Input",
        Key.contextUsageOutputLabel.rawValue: "Output",
        Key.contextUsageReasoningLabel.rawValue: "Reasoning",
        Key.contextUsageCachedReadLabel.rawValue: "Cached read",
        Key.contextUsageCachedWriteLabel.rawValue: "Cached write",
        Key.contextUsageNoCostData.rawValue: "No cost data",
        Key.contextUsageLoadingConfig.rawValue: "Loading provider config...",
        Key.contextUsageNoUsageData.rawValue: "No usage data",
        Key.contextUsageConfigNotLoaded.rawValue: "Provider config not loaded",
        Key.contextUsageSectionThroughput.rawValue: "Throughput",
        Key.contextUsageThroughputAvg.rawValue: "Avg throughput",
        Key.contextUsageThroughputTime.rawValue: "Generation time",
        Key.contextUsageThroughputTokens.rawValue: "Generated tokens",
        Key.contextUsageThroughputNoData.rawValue: "No throughput data",
        Key.statusRoundsLabel.rawValue: "rounds",
        Key.statusToolsLabel.rawValue: "tool calls",
        Key.statusTokensLabel.rawValue: "tok",
        Key.statusCacheHitsLabel.rawValue: "cache hit",
        Key.statusSinceLastPromptLabel.rawValue: "since last prompt",
        Key.quotaTitle.rawValue: "Usage & Limits",
        Key.quotaDataSource.rawValue: "Data Source",
        Key.quotaNotLoaded.rawValue: "Quota data has not been loaded.",
        Key.quotaLoading.rawValue: "Loading quota data...",
        Key.quotaRefreshing.rawValue: "Refreshing cached quota data...",
        Key.quotaRefreshingProviders.rawValue: "Refreshing providers...",
        Key.quotaNoCachedData.rawValue: "No cached quota snapshot. Refresh AI Usage Dashboard on the host.",
        Key.quotaStale.rawValue: "Showing stale quota data",
        Key.quotaLastFetched.rawValue: "Last fetched",
        Key.quotaGeneratedAt.rawValue: "Generated at",
        Key.quotaRemainingFormat.rawValue: "%d%% left",
        Key.quotaUsedFormat.rawValue: "%d%% used",
        Key.quotaResetFormat.rawValue: "Resets %@",
        Key.quotaCurrentModelAccessibility.rawValue: "Current model quota: %@",

        Key.sessionTitle.rawValue: "Session",
        Key.sessionsTitle.rawValue: "Sessions",
        Key.sessionsEmptyTitle.rawValue: "No Sessions",
        Key.sessionsEmptyDescription.rawValue: "Tap + to create one, or pull to refresh for existing sessions.",
        Key.sessionsClose.rawValue: "Close",
        Key.sessionsNew.rawValue: "New",
        Key.sessionsUntitled.rawValue: "Untitled",
        Key.sessionsFilesOne.rawValue: "%d file",
        Key.sessionsFilesMany.rawValue: "%d files",
        Key.sessionsStatusBusy.rawValue: "Running",
        Key.sessionsStatusRetry.rawValue: "Retrying",
        Key.sessionsStatusIdle.rawValue: "Idle",
        Key.sessionsStatusNeedAttention.rawValue: "Need attention",
        Key.sessionsStatusSubagentsRunningOne.rawValue: "1 subagent running",
        Key.sessionsStatusSubagentsRunningMany.rawValue: "%d subagents running",
        Key.sessionsActive.rawValue: "Active",
        Key.sessionsArchived.rawValue: "Archived",
        Key.sessionsArchive.rawValue: "Archive",
        Key.sessionsRestore.rawValue: "Restore",
        Key.sessionsLoadMore.rawValue: "Load more sessions",
        Key.sessionsActionFailedTitle.rawValue: "Session Action Failed",
        Key.sessionsDelete.rawValue: "Delete",

        Key.fileBinary.rawValue: "Binary file",
        Key.fileNoContent.rawValue: "No content",
        Key.filePreviewMode.rawValue: "Preview Mode",
        Key.fileNativePreview.rawValue: "Native Preview",
        Key.fileWebPreview.rawValue: "Web Preview",
        Key.fileMarkdownSource.rawValue: "Markdown Source",
        Key.contentImageDecodeFailed.rawValue: "Failed to decode image",
        Key.contentNoImageData.rawValue: "No image data",
        Key.markdownPreviewLoading.rawValue: "Loading preview...",
        Key.markdownWebPreviewLoading.rawValue: "Loading web preview...",
        Key.markdownWebPreviewLargeDocumentTitle.rawValue: "Large document",
        Key.markdownWebPreviewLargeDocumentDescription.rawValue: "This file is large. Web Preview may be slow or memory-heavy.",
        Key.markdownWebPreviewRenderAnyway.rawValue: "Render anyway",
        Key.markdownWebPreviewOpenNative.rawValue: "Open Native Preview",
        Key.markdownWebPreviewOpenSource.rawValue: "Open Markdown Source",
        Key.markdownWebPreviewFailedTitle.rawValue: "Web Preview failed",
        Key.markdownWebPreviewAssetsMissing.rawValue: "Web Preview assets missing from app bundle.",
        Key.markdownWebPreviewPayloadEncodeFailed.rawValue: "Failed to encode preview payload.",
        Key.markdownWebPreviewRenderCallFailed.rawValue: "Render call failed: %@",
        Key.markdownWebPreviewWebViewLoadFailed.rawValue: "WebView load failed: %@",
        Key.markdownWebPreviewWebViewProvisionalLoadFailed.rawValue: "WebView provisional load failed: %@",
        Key.markdownWebPreviewUnknownRenderError.rawValue: "Unknown render error",

        Key.errorConnectionFailed.rawValue: "Connection failed: %@",
        Key.errorServerError.rawValue: "Server error: %@",
        Key.errorInvalidResponse.rawValue: "Server returned invalid response",
        Key.errorUnauthorized.rawValue: "Unauthorized; check your credentials",
        Key.errorSessionNotFound.rawValue: "Session not found",
        Key.errorFileNotFound.rawValue: "File not found: %@",
        Key.errorOperationFailed.rawValue: "Operation failed: %@",
        Key.errorUnknown.rawValue: "Unknown error: %@",
        Key.errorAiBuilderTokenEmpty.rawValue: "Token is empty",
        Key.errorInvalidBaseURL.rawValue: "Invalid base URL",
        Key.errorServerAddressEmpty.rawValue: "Server address is empty",
        Key.errorWanRequiresHttps.rawValue: "WAN address must use HTTPS",
        Key.errorUsingLanHttp.rawValue: "Using HTTP on LAN",
        Key.helpLanHttp.rawValue: "LAN: HTTP is allowed only on trusted local networks.",
        Key.helpWanHttp.rawValue: "WAN: HTTPS is required. HTTP will be blocked.",
        Key.helpTailscaleHttp.rawValue: "Tailscale does not require HTTPS; other WAN addresses still require HTTPS.",

        Key.activityRetrying.rawValue: "Retrying",
        Key.activityThinking.rawValue: "Thinking",
        Key.activityDelegating.rawValue: "Delegating",
        Key.activityPlanning.rawValue: "Planning",
        Key.activityGatheringContext.rawValue: "Gathering context",
        Key.activitySearchingCodebase.rawValue: "Searching codebase",
        Key.activitySearchingWeb.rawValue: "Searching web",
        Key.activityMakingEdits.rawValue: "Making edits",
        Key.activityRunningCommands.rawValue: "Running commands",
        Key.activityGatheringThoughts.rawValue: "Gathering thoughts",

        Key.configureTitle.rawValue: "Model & Agent",
        Key.configureModel.rawValue: "Model",
        Key.configureAgent.rawValue: "Agent",
        Key.configureNoAgents.rawValue: "No agents available",
        Key.configureModelSearchPlaceholder.rawValue: "Search models",
        Key.configureModelNoMatches.rawValue: "No matching models",
        Key.configureModelEmptyShortlist.rawValue: "Add models in Settings → Models.",
        Key.configureModelEditShortlist.rawValue: "Add, remove, or reorder in Settings",

        Key.todoPanelTitle.rawValue: "Todo",
        Key.todoPanelCompleted.rawValue: "%d/%d completed",
        Key.todoPanelEmpty.rawValue: "No todos yet",
        Key.todoUpdatedBadge.rawValue: "Todo updated · %d/%d",
    ]

    static var currentLocale: Locale {
        .current
    }

    static func t(_ key: Key) -> String {
        en[key.rawValue] ?? key.rawValue
    }

    static func t(_ key: Key, _ arguments: CVarArg...) -> String {
        let template = t(key)
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: currentLocale, arguments: arguments)
    }

    static func toolCallsCount(_ count: Int) -> String {
        let key: Key = count == 1 ? .toolCallsCountOne : .toolCallsCountMany
        return formatCount(key: key, count: count)
    }

    static func sessionsFiles(_ count: Int) -> String {
        let key: Key = count == 1 ? .sessionsFilesOne : .sessionsFilesMany
        return formatCount(key: key, count: count)
    }

    static func sessionsSubagentsRunning(_ count: Int) -> String {
        let key: Key = count == 1 ? .sessionsStatusSubagentsRunningOne : .sessionsStatusSubagentsRunningMany
        return formatCount(key: key, count: count)
    }

    static func chatBackgroundTasks(_ count: Int) -> String {
        let key: Key = count == 1 ? .chatBackgroundTasksOne : .chatBackgroundTasksMany
        return formatCount(key: key, count: count)
    }

    static func patchFilesChanged(_ count: Int) -> String {
        let key: Key = count == 1 ? .patchFilesChangedOne : .patchFilesChangedMany
        return formatCount(key: key, count: count)
    }

    private static func formatCount(key: Key, count: Int) -> String {
        t(key).replacingOccurrences(of: "%d", with: count.formatted(.number.locale(currentLocale)))
    }

    static func toolOpenFileLabel(path: String) -> String {
        return t(.toolOpenInFileTree, path)
    }

    static func helpForURLScheme(isLocal: Bool, isTailscale: Bool) -> String {
        if isTailscale { return t(.helpTailscaleHttp) }
        return isLocal ? t(.helpLanHttp) : t(.helpWanHttp)
    }

    static func errorMessage(_ key: Key, _ detail: String) -> String {
        return t(key, detail)
    }

    static var missingEnglishKeys: [String] {
        Key.allCases.map(\.rawValue).filter { en[$0] == nil }
    }
}

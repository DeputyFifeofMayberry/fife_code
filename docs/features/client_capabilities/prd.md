# iOS Client Capabilities PRD

## Conclusion

OpenCode iOS allows a restricted structured action from Car Mode to be dispatched for local execution on the current iPhone, with the execution result returned to the original Car Session. V0 opens exactly one capability, `health_quantification.export_all`: when the AI finds the server-stored health data missing or stale, it invokes the iPhone to open Health Quantification; after the data export finishes, the flow jumps back to OpenCode automatically and seamlessly continues the earlier analysis.

The core value of this capability is removing the tedium of manually bouncing between apps, rather than evolving the iPhone into a general remote tool execution environment. OpenCode Server, the normal Chat flow, the underlying HealthKit data collection, and the health analysis protocol all stay as they are.

## User Flow

```text
User asks for a health analysis in Car Mode
→ AI first checks data freshness with a server tool
→ returns a typed Health export action when data is missing or stale
→ OpenCode iOS shows the first-time local authorization
→ Health Quantification runs Export All
→ callback brings OpenCode back
→ OpenCode sends the normalized result to the original Car session
→ AI re-reads the server data and completes the analysis
```

The first authorization dialog offers three options: "Cancel", "Allow once", and "Allow always". Permanent grants persist under the stable capability name, and the user can revoke them anytime in Settings → Client Capabilities. The model-returned natural-language reason only explains the intent of this invocation to the user and never participates in permission rule matching.

## Product Boundary

- V0 is open only to Car Mode and `health_quantification.export_all`.
- The model has no authority to specify the launch URL, callback URL, Session ID, Host Profile, or expiry time.
- OpenCode itself never reads HealthKit directly; data collection, system permission prompts, progress display, and error messaging remain Health Quantification's responsibility.
- The callback returns only execution status, exported counts, failed categories, and fixed error codes, never concrete health details or free text.
- The continuation phase must re-pull data from the Health Quantification server; receiving a successful callback response is not by itself proof that the server data is current.
- Explicitly unsupported: normal Chat, Shortcuts, the system Share Sheet, arbitrary custom URL invocation, a server-side remote-tool protocol, a background message broker, and multi-device cooperative routing.

## Success Criteria

- The user expresses the health analysis intent once; on first trigger at most one local authorization confirmation is needed, with no manual Export All tap and no re-asking.
- Under abnormal scenarios such as the Health app not installed, an expired callback, duplicate callbacks, network loss, or a Host switch, the system defends gracefully and never mis-delivers results to another Session.
- At most one Health export Pending or Outbox record exists globally at any moment; a duplicate action never triggers a second export.
- Permanent grants support manual revocation; choosing Cancel or Allow once never creates persistent configuration.
- The Maps action and the existing `opencode://session/<id>` deep link behavior stay fully regression-free.

For the canonical URLs, storage spec, and continuation protocol see [`protocol.md`](protocol.md); for concrete architecture implementation trade-offs see [`rfc.md`](rfc.md).

# Keep a custom panel rather than Notification Center banners

MacNotif deliberately presents Notices in a custom AppKit panel rather than
using real Notification Center banners. System banners would provide delivery
integration, but would surrender control over the independent Temporary and
Permanent notice lifecycles, replacement/clear behavior, stacking, and
configurable overlay presentation. The panel instead uses adaptive macOS
materials and semantic colors with system accessibility preferences taking
precedence over visual tokens; this resemblance does not provide Notification
Center history, Focus integration, or per-app notification delivery behavior.

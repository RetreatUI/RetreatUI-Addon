# Installer completion rules

The TBC installer only sets `installerCompleted = true` when every selected component reports success.

Missing embedded WeakAuras or Plater data are blocking failures, not optional success states. The installer keeps the setup incomplete so it can reopen and be retried after the package is corrected.

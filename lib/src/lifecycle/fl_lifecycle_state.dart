enum FlLifecycleState {
  onPageInit,
  onPageContextReady,
  onPagePostFrame,
  onPageReassemble,
  onPageStart,
  onPageResume,
  onPageEnterAnimationEnd,
  onPagePause,
  onPageStop,
  onPageLeaveAnimationEnd,
  onPageDispose,
  onAppResume,
  onAppInactive,
  onAppPause,
  onAppForeground,
  onAppBackground;

  bool get isPageResume => this == FlLifecycleState.onPageResume;

  bool get isPagePause => this == FlLifecycleState.onPagePause;
}

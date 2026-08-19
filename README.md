# fl_core_provider

> A `provider`-based Flutter state management framework — Controller base class + Page/App lifecycle + Type-safe event bus + Enum-granularity UI refresh

---

## Quick Start

### 1. Add dependency

`provider` is a direct dependency of `fl_core_provider` and is auto-included — no need to add it manually:

```yaml
dependencies:
  fl_core_provider: ^0.1.5
```

### 2. Define enum IDs and Controller

```dart
// ---- ids.dart ----
enum CounterId { count, loading }

// ---- counter_controller.dart ----
class CounterController extends FlBaseController<CounterId> {
  int _count = 0;
  bool _loading = false;

  int get count => _count;
  bool get loading => _loading;

  @override
  List<CounterId> get shouldNotifyIds => CounterId.values.toList();

  void increment() {
    _count++;
    notifySingleListener(CounterId.count);
  }

  void setLoading(bool v) {
    _loading = v;
    notifySingleListener(CounterId.loading);
  }
}
```

**What's happening here?**
- `FlBaseController<CounterId>` is the base class — it extends `ChangeNotifier` and includes lifecycle + event bus mixins
- `shouldNotifyIds` declares which IDs this controller will emit notifications for
- `notifySingleListener(id)` triggers a UI rebuild only for widgets observing that specific ID

### 3. Create a page

```dart
class CounterPage extends FlBasePage<CounterController> {
  const CounterPage({super.key});

  @override
  CounterController createController(BuildContext context) =>
      CounterController();

  @override
  Widget buildWithController(BuildContext context, CounterController controller) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            // Only rebuilds when CounterId.count changes
            FlSelectorIds<CounterId, CounterController>(
              ids: [CounterId.count],
              builder: (ctx, ctrl, _) => Text('${ctrl.count}'),
            ),
            // Only rebuilds when CounterId.loading changes
            FlSelectorIds<CounterId, CounterController>(
              ids: [CounterId.loading],
              builder: (ctx, ctrl, _) =>
                  ctrl.loading ? const CircularProgressIndicator() : const SizedBox(),
            ),
            ElevatedButton(
              onPressed: () => controller.increment(),
              child: const Text('+1'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Key patterns:**
- `FlBasePage<CounterController>` — StatelessWidget base that provides the Controller via `ChangeNotifierProvider`
- `createController` — factory method for the Controller
- `buildWithController` — receives the Controller directly, no need for `Provider.of<T>()`
- `FlSelectorIds` — subscribes only to specific enum IDs, avoiding unnecessary rebuilds

### 4. Configure MaterialApp

```dart
MaterialApp(
  navigatorObservers: [FlRouteObserver.instance],
  home: const CounterPage(),
)
```

`FlRouteObserver.instance` is required for lifecycle hooks (`onPageStart`, `onPageResume`, etc.) to work.

### 5. Lifecycle hooks in your Controller

Override any of these 15 hooks in your Controller:

```dart
class MyController extends FlBaseController<MyId> {
  @override
  List<MyId> get shouldNotifyIds => MyId.values.toList();

  @override
  void onPageInit() { /* Controller created */ }

  @override
  void onPageContextReady(BuildContext? context) { /* Route info available */ }

  @override
  void onPagePostFrame() { /* First frame rendered */ }

  @override
  void onPageStart() { /* Page became visible */ }

  @override
  void onPageResume() { /* Regained visibility (pop back) */ }

  @override
  void onPagePause() { /* Covered by popup */ }

  @override
  void onPageStop() { /* Fully invisible */ }

  @override
  void onPageDispose() { /* Cleanup resources */ }

  @override
  void onAppResume() { /* App foregrounded */ }

  @override
  void onAppBackground() { /* App backgrounded */ }
}
```

### 6. Event bus (cross-controller communication)

```dart
// Define event types
class UserLoggedIn { final String userId; UserLoggedIn(this.userId); }
class UserLoggedOut {}

// Fire an event
dispatchEvent(UserLoggedIn('abc123'));

// Listen in another Controller
observeEvent<UserLoggedIn>((event) {
  print('User ${event.userId} logged in');
});
```

### 7. PageView / TabBarView support

> ⚠️ **`FlPageViewScope` and `observePageView => true` must be used together.**
> Neither one works on its own:
>
> | Host wraps with `FlPageViewScope` | Page sets `observePageView => true` | Result |
> | :---: | :---: | --- |
> | ✅ | ✅ | Page-switch lifecycle works |
> | ✅ | ❌ | Scope publishes the page index, but the page ignores it — visible from the first frame |
> | ❌ | ✅ | Page opts in but finds no Scope — falls back to normal route-page behavior |
> | ❌ | ❌ | Plain route page |
>
> `observePageView` defaults to **`false`**, so opting in is always explicit.

**Step 1 — the host:** wrap the children on the side that builds the
`PageView` / `TabBarView` with `FlPageViewScope.wrapChildren` (no extra layout node is
introduced):

```dart
// PageView
final controller = PageController();

PageView(
  controller: controller,
  children: FlPageViewScope.wrapChildren(
    controller: controller,          // PageController
    children: const [PageOne(), PageTwo(), PageThree(), PageFour()],
  ),
)

// TabBarView — pass the TabController
TabBarView(
  children: FlPageViewScope.wrapChildren(
    controller: DefaultTabController.of(context),  // TabController
    children: const [PageOne(), PageTwo(), PageThree(), PageFour()],
  ),
)
```

For `PageView.builder`, wrap the `itemBuilder` instead:

```dart
PageView.builder(
  controller: controller,
  itemCount: pages.length,
  itemBuilder: FlPageViewScope.wrapItemBuilder(
    controller: controller,
    builder: (context, index) => pages[index],
  ),
)
```

**Step 2 — every child page:** override `observePageView` to `true`. Without this the
page never reads the Scope, no matter how the host is wired:

```dart
class _PageOneState extends FlBasePageState<PageOne, PageOneController> {
  @override
  bool get observePageView => true;   // ← required, default is false

  // ... rest of implementation
}

// Same getter on the StatelessWidget flavor
class PageOne extends FlBasePage<PageOneController> {
  @override
  bool get observePageView => true;
}
```

**With both pieces in place, what changes for the child pages:**
- Their `onPageStart` / `onPageResume` / `onPagePause` / `onPageStop` are driven by
  **page switching** instead of route changes — switching to page 2 stops page 1
- Visibility flips at the half-page mark, identically for `PageController` and
  `TabController`
- `onPageViewChanged(from, to)` fires on the Controller when the index changes
- Nesting works: a `TabBarView` inside a `PageView` gets stopped when the outer
  `PageView` scrolls away, and started again when it scrolls back
- `controller` only accepts `PageController` or `TabController` (asserted)

A child that is missing **either** piece is treated as a normal page: visible from the
first frame, and its visibility never changes with page switching. To opt one page out
while its siblings participate, just leave `observePageView` at its default `false`.

### 8. Optimize with `child` parameter

Pass static widget subtrees via `child` to skip rebuilding them on ID changes:

```dart
FlSelectorIds<CounterId, CounterController>(
  ids: [CounterId.count],
  child: const Icon(Icons.star),  // Never rebuilt
  builder: (ctx, ctrl, child) => Column(
    children: [
      if (child != null) child,
      Text('${ctrl.count}'),
    ],
  ),
)
```

---

## Important Constraints

1. **Register before notify** — call `registerIds(shouldNotifyIds)` before using `notifySingleListener` / `notifyMultiListeners` (done automatically in `onPageInit`)
2. **Must attach `FlRouteObserver`** — add `FlRouteObserver.instance` to `MaterialApp.navigatorObservers` for route lifecycle
3. **PageView/TabBarView needs `FlPageViewScope` *and* `observePageView => true`** — the host wraps children with `FlPageViewScope.wrapChildren` / `wrapItemBuilder`, **and** each child page overrides `bool get observePageView => true` (default `false`). Either one alone silently does nothing: the child is treated as a normal page, visible from the first frame, and never receives page-switch lifecycle events
4. **Dispose skips all notifications** — no need to check `mounted` manually
5. **Build-phase notify is deferred** — `notifyListeners()` during build is postponed to post-frame

---

## Full Lifecycle Flow

```
State.initState()
  ├── onPageInit()  →  registerIds(shouldNotifyIds)
  └── First-frame postFrameCallback registered

State.didChangeDependencies()
  ├── Register with FlRouteObserver
  ├── Look up the nearest FlPageViewScope (page index + visibility)
  └── onPageContextReady()  →  setupRouteInfo(name, args)

First-frame callback
  ├── observePageView && in a Scope → visibility comes from the page index
  │   otherwise → treated as a normal page, visible immediately
  └── onPagePostFrame()

Page visible
  ├── onPageStart()
  └── onPageResume()

Runtime:
  push new page    → onPageStop()
  push PopupRoute  → onPagePause()
  pop back         → onPageResume()
  app foreground   → onAppResume()
  app background   → onAppBackground()

State.dispose()
  ├── Cancel all subscriptions
  ├── onPageDispose()
  └── Controller.dispose()
      ├── FlEventBusMixin: cancel all StreamSubscriptions
      └── FlNotifyMixin: clear _updatedIds, set _disposed
```

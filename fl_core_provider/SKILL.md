---
name: fl_core_provider
description: Generate Flutter pages and controllers for the fl_core_provider state management framework. Trigger whenever the user wants to create a new page (FlBasePage / FlBasePageState), controller (FlBaseController), or selector widget (FlSelectorIds / FlSelectorView) in a project that depends on fl_core_provider. Also useful when the user mentions "create page", "create controller", "new page", "page + controller", "add page", or similar code generation requests in a fl_core_provider-based project.
compatibility:
  requires: dart, flutter, fl_core_provider package
---

# fl_core_provider Skill

This skill generates page and controller code for the **fl_core_provider** state management framework.

## Architecture Overview

fl_core_provider uses a **Page + Controller** pattern:

- **Controller** (`FlBaseController<T>`): A `ChangeNotifier` with lifecycle awareness, enum-granularity notifications (`FlNotifyMixin`), and a global event bus (`FlEventBusMixin`). `T` is an **Enum** that defines the notification event types.
- **Page** (`FlBasePage<T>` or `FlBasePageState<S, T>`): The UI layer that connects to a controller via `ChangeNotifierProvider`. It has access to the controller through `context.rc<T>()` or directly via `buildWithController` callback.
- **Selective rebuild** (`FlSelectorIds<E, T>`): Subscribe to specific enum IDs only — widgets rebuild when their observed IDs fire, not on every state change.

## Project Initialization

When the user wants to start a **new project** with `fl_core_provider`, or add it to an **existing project**, follow this workflow.

### 1. Add Dependency

Check `pubspec.yaml`. If `fl_core_provider` is not listed, add it:

```bash
# From the project root
flutter pub add fl_core_provider
```

`provider` is a transitive dependency and is auto-included. After adding, verify:

```bash
flutter pub get
```

### 2. Configure MaterialApp

The only required configuration is `FlRouteObserver.instance` in `MaterialApp.navigatorObservers`. Without this, route lifecycle hooks (`onPageStart`, `onPageResume`, etc.) will not fire.

```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [FlRouteObserver.instance],
      home: const HomePage(),
    );
  }
}
```

If using `GoRouter` or another declarative router, wrap the `MaterialApp.router` and pass `FlRouteObserver.instance` as an observer:

```dart
MaterialApp.router(
  routerConfig: goRouter,
  navigatorObservers: [FlRouteObserver.instance],
);
```

### 3. Create Directory Structure (Recommended)

```bash
mkdir -p lib/pages lib/widgets lib/controllers
```

This separates page widgets, reusable widgets, and controllers into clear layers.

### 4. Create a Starter Page + Controller (Optional)

If the project has no pages yet, create a starter home page and controller using the bundled templates (see [Workflow: Creating a Page + Controller](#workflow-creating-a-page--controller) below).

Minimal home page using the `rc<T>()` extension:

```dart
// lib/pages/home_controller.dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

enum HomeEvent { initialized }

class HomeController extends FlBaseController<HomeEvent> {
  @override
  List<HomeEvent> get shouldNotifyIds => HomeEvent.values;

  String _message = 'Ready';
  String get message => _message;

  @override
  void onPageInit() {
    super.onPageInit();
    _message = 'Hello from fl_core_provider!';
    notifySingleListener(HomeEvent.initialized);
  }
}
```

```dart
// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';
import 'home_controller.dart';

class HomePage extends FlBasePage<HomeController> {
  const HomePage({super.key});

  @override
  HomeController createController(BuildContext context) {
    return HomeController();
  }

  @override
  Widget buildWithController(BuildContext context, HomeController controller) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: FlSelectorIds<HomeEvent, HomeController>(
          ids: [HomeEvent.initialized],
          builder: (context, ctrl, child) => Text(ctrl.message),
        ),
      ),
    );
  }
}
```

### 5. Verify the Setup

```bash
# Run static analysis
dart analyze lib/

# Run the app (pick a platform)
flutter run
```

If `FlLifecycleManager` is working correctly, you should see lifecycle callbacks in action when you navigate, switch apps, or use the back button.

---

## Bundled Templates & Scripts

该 skill 附带以下模板文件和辅助脚本，位于 `fl_core_provider/` 目录中：

| 文件 | 说明 |
|---|---|
| `templates/controller_with_events.txt` | 带事件枚举的 Controller (`FlBaseController<T>`) |
| `templates/controller_simple.txt` | 简单 Controller（无自定义事件，使用空枚举） |
| `templates/page_stateless.txt` | 无状态页面 (`FlBasePage<T>`) |
| `templates/page_stateful.txt` | 有状态页面 (`FlBasePageState<S, T>`) |
| `templates/selector_ids_view.txt` | 选择性刷新组件 (`FlSelectorView`) — 可用于页面内片段或独立组件 |
| `scripts/generate.sh` | 一键生成脚本 |

生成代码时，优先使用这些模板文件作为基础模板，然后根据用户需求填充业务逻辑。

## Workflow: Creating a Page + Controller

When the user asks to create a page/controller, follow this process:

### 1. Gather Requirements

**必须按顺序依次询问以下问题，确认后再进行下一步：**

---

#### 问题 ①：Page 的名字是什么？

用户回答后确认类名和文件名。例如 "Login" → `LoginPage` / `login_page.dart`。

**追问：** Controller 是否与页面同名？通常使用 `Login` → `LoginController` / `login_controller.dart`，如不同名请用户指定。

---

#### 问题 ②：创建 StatefulWidget 还是 StatelessWidget？

| 选择 | 基类 | 说明 |
|------|------|------|
| **Stateless**（默认） | `FlBasePage<T>` | 无 State 类，更简单。绝大多数场景适用 |
| **Stateful** | `FlBasePageState<S, T>` | 需要 `AutomaticKeepAlive`、`TickerProviderStateMixin`，或页面在 PageView/IndexedStack 中 |

> **规则：** 如果用户不确定，默认使用 `FlBasePage<T>`（Stateless）。

---

#### 问题 ③：是否在 PageView 或 TabView（IndexedStack）中？

- **否** → 普通页面，`pageIndex` 保持默认 `-1`，无需额外配置。
- **是** → 需要用户提供索引值：
  - 通过在 `pageIndex` getter 中返回对应的索引（如 `0`, `1`, `2`...）。
  - **只能使用 Stateful**（`FlBasePageState<S, T>`）。
  - 如需保持页面状态，同时设置 `wantKeepAlive = true`。

---

#### 补充信息（可选，但建议询问）

以上 3 个问题确定后，继续收集以下信息以完善代码生成：

| 问题 | 说明 |
|---|---|
| **Controller 是否需要事件枚举？** | **Events** — 自定义枚举，`FlSelectorIds` 粒度刷新（推荐）。**Simple** — 空枚举，全页刷新。默认使用 Events |
| **有哪些事件值？**（Events 模式） | 如 `loadingChanged`, `dataLoaded`, `errorOccurred`，会生成枚举成员 |
| **路由名？**（可选） | 用于 `Navigator.pushNamed` 的路由名称 |
| **输出目录？** | 默认 `lib/pages/` |

**参数速查（`scripts/generate.sh`）：**

```bash
# Stateless + Simple（默认）
bash fl_core_provider/scripts/generate.sh -n Profile

# Stateful + Events + pageIndex
bash fl_core_provider/scripts/generate.sh -n Login -t stateful -c events -e loadingChanged,loginSuccess -i 1

# Stateful + 非 keepAlive + 自定义输出目录
bash fl_core_provider/scripts/generate.sh -n Settings -t stateful -i 2 -k false -d lib/screens
```

### 2. Generate the Controller

Use the corresponding template from `templates/` as the starting point, then customize the business logic.

**Template file:** `templates/controller_with_events.txt` or `templates/controller_simple.txt`

#### Controller with custom events (FlBaseController) — recommended

```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

enum {{Name}}Event { {{eventList}} }

class {{Name}}Controller extends FlBaseController<{{Name}}Event> {
  @override
  List<{{Name}}Event> get shouldNotifyIds => {{Name}}Event.values;

  // --- State Fields ---

  // --- Computed Getters ---

  // --- Lifecycle ---
  @override
  void onPageInit() {
    super.onPageInit();
    // 初始化数据、监听事件等
  }

  @override
  void onPageStart() {
    super.onPageStart();
  }

  // --- Business Methods ---
  // 通过 notifySingleListener / notifyMultiListeners 通知 UI 更新
}
```

#### Simple controller (FlBaseController — no custom events)

When the page doesn't need fine-grained UI refresh, use an empty enum:

```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

/// Empty enum satisfies the `T extends Enum` constraint.
enum {{Name}}SimpleEvent {}

class {{Name}}Controller extends FlBaseController<{{Name}}SimpleEvent> {
  /// Empty list = no selective rebuild. Call `notifyListeners()` for full refresh.
  @override
  List<{{Name}}SimpleEvent> get shouldNotifyIds => [];

  // --- State Fields ---

  // --- Computed Getters ---

  // --- Lifecycle ---
  @override
  void onPageInit() {
    super.onPageInit();
    // 初始化数据、监听事件等
  }

  @override
  void onPageStart() {
    super.onPageStart();
  }

  // --- Business Methods ---
}
```

**命名规范:** 控制器文件命名为 `{{snake_name}}_controller.dart`。

**Key controller APIs:**

| API | Description |
|---|---|
| `notifySingleListener(eventId)` | Notify widgets listening for a specific event to rebuild |
| `notifyMultiListeners([eventId1, eventId2])` | Notify multiple events at once |
| `registerIds([eventId1, ...])` | Register which IDs to track — called automatically in `onPageInit` from `shouldNotifyIds` |
| `observeEvent<T>(callback)` | Listen for events from the global event bus (`FlEventBusMixin`) |
| `dispatchEvent<T>(event)` | Send an event through the global event bus |
| `context.rc<Type>()` | Extension on `BuildContext` to read any controller from widget tree |

**Important:** `shouldNotifyIds` is automatically registered in `onPageInit()`. On Hot Reload, `onPageReassemble()` re-registers IDs automatically.

### 3. Generate the Page

**Template file:** `templates/page_stateless.txt` or `templates/page_stateful.txt`

#### Stateless page (FlBasePage)

```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

{{importController}}

class {{Name}}Page extends FlBasePage<{{Name}}Controller> {
  const {{Name}}Page({super.key});

  @override
  {{Name}}Controller createController(BuildContext context) {
    return {{Name}}Controller();
  }

  @override
  Widget buildWithController(BuildContext context, {{Name}}Controller controller) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('{{Title}}'),
      ),
      body: // TODO: 在此添加页面内容
    );
  }
}
```

#### Stateful page (FlBasePageState) — for PageView / IndexedStack / keepAlive

```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

{{importController}}

class {{Name}}Page extends StatefulWidget {
  const {{Name}}Page({super.key});

  @override
  State<{{Name}}Page> createState() => _{{Name}}PageState();
}

class _{{Name}}PageState extends FlBasePageState<{{Name}}Page, {{Name}}Controller> {
  @override
  {{Name}}Controller createController(BuildContext context) {
    return {{Name}}Controller();
  }

  {{pageIndex}}

  {{keepAlive}}

  @override
  Widget buildWithController(BuildContext context, {{Name}}Controller controller) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('{{Title}}'),
      ),
      body: // TODO: 在此添加页面内容
    );
  }
}
```

**命名规范:** 页面文件命名为 `{{snake_name}}_page.dart`。

### 4. Generate via Helper Script (Optional)

```bash
# Basic: Stateless page + Simple controller
./fl_core_provider/scripts/generate.sh -n Profile

# Stateful page + Events controller
./fl_core_provider/scripts/generate.sh -n Login -t stateful -c events -e loadingChanged,loginSuccess

# With pageIndex, route name, custom output dir
./fl_core_provider/scripts/generate.sh -n Settings -t stateful -i 2 -r settings -d lib/screens
```

### 5. Wire Up Routing (if applicable)

```dart
routes: {
  '/{{routeName}}': (_) => const {{Name}}Page(),
},
```

### 6. Selective Rebuild with FlSelectorIds

`FlSelectorIds<E, T>` is the primary mechanism for fine-grained UI rebuilds. Instead of rebuilding an entire page when state changes, wrap only the parts that depend on specific event IDs.

**Version tag mechanism:** Each registered ID has a monotonically increasing version tag (Dart 64-bit int, no overflow, no wraparound). When `notifySingleListener(id)` is called, the tag increments. `FlSelectorIds` uses `Selector<T, int>` to compare the combined hash of observed IDs — only rebuilding when the hash changes.

#### Pattern A: Inline FlSelectorIds

```dart
FlSelectorIds<{{Name}}Event, {{Name}}Controller>(
  ids: [{{Name}}Event.updateSomething],
  builder: (context, controller, child) {
    return Text('Value: ${controller.someValue}');
  },
),
```

Multiple IDs — rebuilds when **any** of the listed IDs fire:

```dart
FlSelectorIds<{{Name}}Event, {{Name}}Controller>(
  ids: [{{Name}}Event.loadingChanged, {{Name}}Event.dataLoaded],
  builder: (context, controller, child) {
    if (controller.isLoading) return const CircularProgressIndicator();
    return Text('Data: ${controller.data}');
  },
),
```

Optimization via `child` — built once, stable across rebuilds:

```dart
FlSelectorIds<{{Name}}Event, {{Name}}Controller>(
  ids: [{{Name}}Event.countChanged],
  builder: (context, controller, child) {
    return Column(
      children: [
        Text('Count: ${controller.count}'),
        child!, // ← static widget, won't rebuild on countChanged
      ],
    );
  },
  child: const ExpensiveStaticWidget(),
),
```

#### Pattern B: FlSelectorView Subclass

For reusable UI fragments:

```dart
class {{Name}}Section extends FlSelectorView<{{Name}}Event, {{Name}}Controller> {
  const {{Name}}Section({super.key});

  @override
  List<{{Name}}Event> get observeIds => [{{Name}}Event.updateSomething];

  @override
  Widget buildWidget(BuildContext context, {{Name}}Controller controller) {
    return Text('Value: ${controller.someValue}');
  }
}
```

#### Pattern C: StatelessWidget + Internal FlSelectorIds

When extra parameters are needed:

```dart
class {{Name}}CounterTile extends StatelessWidget {
  const {{Name}}CounterTile({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return FlSelectorIds<{{Name}}Event, {{Name}}Controller>(
      ids: [{{Name}}Event.countChanged],
      builder: (context, controller, child) {
        return ListTile(
          title: Text(title),
          trailing: Text('${controller.count}'),
        );
      },
    );
  }
}
```

#### Key Behavioral Notes

| Aspect | Detail |
|---|---|
| **Version tag** | Monotonically increasing per ID (Dart 64-bit int, no wraparound). Multiple IDs combined via polynomial hash (`31 * h + v`) to avoid collisions |
| **Rebuild trigger** | The builder runs only when `notifySingleListener(id)` or `notifyMultiListeners([ids])` is called for one of the observed IDs |
| **Unobserved IDs** | Firing an ID not in the `ids` list does **not** trigger a rebuild for this widget |
| **Registration** | IDs are auto-registered via `shouldNotifyIds` in `onPageInit()`; Hot Reload re-registers via `onPageReassemble()` |
| **Child optimization** | The `child` parameter is built once and stable across rebuilds — use it for static subtrees |
| **Build-phase safety** | `notifyListeners()` called during `SchedulerPhase.persistentCallbacks` is deferred to post-frame, preventing `setState` during build |

## Important Guidelines

1. **Never modify** existing code in `lib/` or `example/` of the `fl_core_provider` package itself — this skill is for generating NEW pages/controllers in USER projects that depend on `fl_core_provider`.
2. **Always check** if the user's project has `fl_core_provider` as a dependency in `pubspec.yaml`. If not, remind them to add it.
3. **Respect existing file structure** — look at how pages/controllers are organized in the target project before generating.
4. **Use correct imports** — the user's project imports from `package:fl_core_provider/fl_core_provider.dart`.
5. **Generate both files** (page + controller) unless the user specifies otherwise.
6. **Show the generated code** to the user before writing — let them confirm the structure is correct.

## 7. Component-Level Controllers & Events

Components inside a page can have **their own controllers** with **their own event enums** — perfect for complex widgets that manage their own state (forms, lists, media players, etc.).

### When to Create a Component Controller

| Scenario | Example |
|---|---|
| Complex internal state | A reusable form with validation, loading, submission states |
| Needs own lifecycle | Must run code on `onPageInit`/`onPageStart` independent of the page |
| Fires UI events | Loading spinner, progress updates, error toasts specific to this component |
| Used in multiple pages | A file-picker widget used across the app |

### Pattern: Component Controller + FlSelectorIds

**Step 1: Define the component's event enum and controller**

```dart
// file_picker_controller.dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

enum FilePickerEvent { statusChanged, fileSelected, uploadProgress }

class FilePickerController extends FlBaseController<FilePickerEvent> {
  @override
  List<FilePickerEvent> get shouldNotifyIds => FilePickerEvent.values;

  bool _isPicking = false;
  bool get isPicking => _isPicking;

  String? _selectedFilePath;
  String? get selectedFilePath => _selectedFilePath;

  double _uploadProgress = 0;
  double get uploadProgress => _uploadProgress;

  Future<void> pickFile() async {
    notifySingleListener(FilePickerEvent.statusChanged);
    _isPicking = true;
    await Future.delayed(const Duration(milliseconds: 500));
    _selectedFilePath = '/path/to/file.pdf';
    _isPicking = false;
    notifyMultiListeners([FilePickerEvent.statusChanged, FilePickerEvent.fileSelected]);
  }

  void simulateUpload() {
    _uploadProgress = 0;
    notifySingleListener(FilePickerEvent.uploadProgress);
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      _uploadProgress += 0.1;
      notifySingleListener(FilePickerEvent.uploadProgress);
      return _uploadProgress < 1.0;
    });
  }
}
```

**Step 2: Create the component widget**

```dart
// file_picker_widget.dart
class FilePickerWidget extends StatelessWidget {
  const FilePickerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FilePickerController>(
      create: (_) => FilePickerController(),
      child: _FilePickerBody(),
    );
  }
}

class _FilePickerBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.rc<FilePickerController>();
    return Column(
      children: [
        FlSelectorIds<FilePickerEvent, FilePickerController>(
          ids: [FilePickerEvent.statusChanged, FilePickerEvent.fileSelected],
          builder: (context, ctrl, child) {
            if (ctrl.isPicking) return const CircularProgressIndicator();
            return Text('Selected: ${ctrl.selectedFilePath ?? "none"}');
          },
        ),
        ElevatedButton(
          onPressed: ctrl.pickFile,
          child: const Text('Pick File'),
        ),
      ],
    );
  }
}
```

**Step 3: Provide the component controller in the page**

```dart
// In page's buildWithController:
@override
Widget buildWithController(BuildContext context, MyPageController controller) {
  return Scaffold(
    body: ChangeNotifierProvider<FilePickerController>(
      create: (_) => FilePickerController(),
      child: const FilePickerWidget(),
    ),
  );
}
```

## 8. Global Event Bus — Cross-Controller Communication

Use `FlGlobalEventBus` (via `observeEvent`/`dispatchEvent` from `FlEventBusMixin`) to communicate across controllers.

### Pattern A: Controller Bridges Global Events → FlSelectorIds Rebuild

```dart
enum ProfileEvent { userDataChanged, avatarUrlChanged }

class ProfileController extends FlBaseController<ProfileEvent> {
  @override
  List<ProfileEvent> get shouldNotifyIds => ProfileEvent.values;

  String _displayName = '';
  String get displayName => _displayName;

  @override
  void onPageInit() {
    super.onPageInit();
    observeEvent<UserUpdatedEvent>((event) {
      _displayName = event.displayName;
      notifySingleListener(ProfileEvent.userDataChanged);
    });
  }
}
```

UI subscribes to specific IDs:

```dart
FlSelectorIds<ProfileEvent, ProfileController>(
  ids: [ProfileEvent.userDataChanged],
  builder: (context, ctrl, child) => Text('Hello, ${ctrl.displayName}'),
),
```

### Pattern B: dispatchEvent from Anywhere

```dart
// In any controller (has FlEventBusMixin):
dispatchEvent(UserUpdatedEvent(displayName: 'New Name'));

// From a plain Dart service:
import 'package:fl_core_provider/fl_core_provider.dart';

class AuthService {
  void onLogin(String token) {
    FlGlobalEventBus.dispatchEvent(UserLoggedInEvent(token));
  }
}
```

### Pattern C: FlStateEventBusMixin in StatefulWidget

For widgets that need global events **without** a dedicated controller:

```dart
class _MyWidgetState extends State<MyWidget> with FlStateEventBusMixin<MyWidget> {
  String _lastMessage = '';

  @override
  void initState() {
    super.initState();
    observeEvent<StatusMessageEvent>((event) {
      setState(() => _lastMessage = event.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_lastMessage);
  }
}
```

### Global Event Bus — Quick Reference

| API | Location | Description |
|---|---|---|
| `observeEvent<T>(callback)` | In controllers with `FlEventBusMixin` | Subscribe to typed global events |
| `dispatchEvent<T>(event)` | In controllers with `FlEventBusMixin` | Send a typed global event |
| `FlGlobalEventBus.observeEvent<T>()` | Anywhere (static) | Subscribe directly |
| `FlGlobalEventBus.dispatchEvent<T>(event)` | Anywhere (static) | Send directly |
| `FlStateEventBusMixin` | On `State` subclasses | Add event listening to any StatefulWidget |

### Best Practices

1. **Granularity matters** — Create specific event IDs for different UI concerns (`loadingChanged` vs `dataLoaded`) rather than a single `stateChanged`
2. **Controller as bridge** — Prefer having controllers listen to global events and call `notifySingleListener` so `FlSelectorIds` works properly
3. **Auto cleanup** — `FlEventBusMixin` and `FlStateEventBusMixin` cancel subscriptions on `dispose()` automatically
4. **Use typed events** — Define custom event classes rather than passing raw strings or maps:
   ```dart
   class UserUpdatedEvent { final String displayName; UserUpdatedEvent(this.displayName); }
   ```
5. **Avoid over-notifying** — Call the most specific `notifySingleListener(id)` for each change, not `notifyMultiListeners` with every possible ID

## Examples

**Template location:** `templates/` — examples below show the filled output.

### Example 1: Counter page (Stateless, Events)

**Controller** (`lib/pages/counter_controller.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

enum CounterEvent { updateCount }

class CounterController extends FlBaseController<CounterEvent> {
  @override
  List<CounterEvent> get shouldNotifyIds => CounterEvent.values;

  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifySingleListener(CounterEvent.updateCount);
  }
}
```

**Page** (`lib/pages/counter_page.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';
import 'counter_controller.dart';

class CounterPage extends FlBasePage<CounterController> {
  const CounterPage({super.key});

  @override
  CounterController createController(BuildContext context) {
    return CounterController();
  }

  @override
  Widget buildWithController(BuildContext context, CounterController controller) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: FlSelectorIds<CounterEvent, CounterController>(
          ids: [CounterEvent.updateCount],
          builder: (context, ctrl, child) => Text('Count: ${ctrl.count}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### Example 2: Login page (Stateful, PageView)

**Controller** (`lib/pages/login_controller.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

enum LoginEvent { loadingChanged, loginSuccess }

class LoginController extends FlBaseController<LoginEvent> {
  @override
  List<LoginEvent> get shouldNotifyIds => LoginEvent.values;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> login(String username, String password) async {
    notifySingleListener(LoginEvent.loadingChanged);
    _isLoading = true;
    try {
      await Future.delayed(const Duration(seconds: 2));
      notifySingleListener(LoginEvent.loginSuccess);
    } finally {
      _isLoading = false;
      notifySingleListener(LoginEvent.loadingChanged);
    }
  }
}
```

**Page** (`lib/pages/login_page.dart`):
```dart
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends FlBasePageState<LoginPage, LoginController> {
  @override
  LoginController createController(BuildContext context) {
    return LoginController();
  }

  @override
  int get pageIndex => 2;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget buildWithController(BuildContext context, LoginController controller) {
    return Scaffold(
      body: Center(
        child: FlSelectorIds<LoginEvent, LoginController>(
          ids: [LoginEvent.loadingChanged],
          builder: (context, ctrl, child) {
            if (ctrl.isLoading) return const CircularProgressIndicator();
            return ElevatedButton(
              onPressed: () => ctrl.login('user', 'pass'),
              child: const Text('Login'),
            );
          },
        ),
      ),
    );
  }
}
```

### Example 3: Simple page (no events)

**Controller** (`lib/pages/about_controller.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

enum AboutSimpleEvent {}

class AboutController extends FlBaseController<AboutSimpleEvent> {
  @override
  List<AboutSimpleEvent> get shouldNotifyIds => [];

  final String appVersion = '1.0.0';
}
```

**Page** (`lib/pages/about_page.dart`) — uses `context.rc<T>()` instead of the controller parameter:
```dart
class AboutPage extends FlBasePage<AboutController> {
  const AboutPage({super.key});

  @override
  AboutController createController(BuildContext context) {
    return AboutController();
  }

  @override
  Widget buildWithController(BuildContext context, AboutController controller) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Text('Version: ${controller.appVersion}'),
      ),
    );
  }
}
```

### Example 4: Component with own controller

**Component Controller** (`lib/components/notification_badge_controller.dart`):
```dart
enum NotificationBadgeEvent { countChanged }

class NotificationBadgeController extends FlBaseController<NotificationBadgeEvent> {
  @override
  List<NotificationBadgeEvent> get shouldNotifyIds => NotificationBadgeEvent.values;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  @override
  void onPageInit() {
    super.onPageInit();
    observeEvent<NewNotificationEvent>((event) {
      _unreadCount += event.count;
      notifySingleListener(NotificationBadgeEvent.countChanged);
    });
    observeEvent<NotificationsReadEvent>((event) {
      _unreadCount = 0;
      notifySingleListener(NotificationBadgeEvent.countChanged);
    });
  }
}
```

**Component Widget** (`lib/components/notification_badge.dart`):
```dart
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return FlSelectorIds<NotificationBadgeEvent, NotificationBadgeController>(
      ids: [NotificationBadgeEvent.countChanged],
      builder: (context, ctrl, child) {
        if (ctrl.unreadCount == 0) return const Icon(Icons.notifications_outlined);
        return Badge(
          label: Text('${ctrl.unreadCount}'),
          child: const Icon(Icons.notifications),
        );
      },
    );
  }
}
```

**Page using the component** (`lib/pages/home_page.dart`):
```dart
class HomePage extends FlBasePage<HomeController> {
  const HomePage({super.key});

  @override
  HomeController createController(BuildContext context) {
    return HomeController();
  }

  @override
  Widget buildWithController(BuildContext context, HomeController controller) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          ChangeNotifierProvider<NotificationBadgeController>(
            create: (_) => NotificationBadgeController(),
            child: const NotificationBadge(),
          ),
        ],
      ),
    );
  }
}
```

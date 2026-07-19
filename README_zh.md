# fl_core_provider

> 基于 `provider` 的 Flutter 状态管理框架 — Controller 基类 + 页面/App 生命周期 + 类型安全事件总线 + 枚举粒度 UI 刷新

---

## 快速开始

### 1. 添加依赖

`provider` 是 `fl_core_provider` 的直接依赖，会自动传递引入，无需手动添加：

```yaml
dependencies:
  fl_core_provider: ^0.1.3
```

### 2. 定义枚举 ID 和 Controller

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

**核心概念：**
- `FlBaseController<CounterId>` 是基类 — 继承自 `ChangeNotifier`，混入了生命周期和事件总线 Mixin
- `shouldNotifyIds` 声明该 Controller 会通知哪些 ID
- `notifySingleListener(id)` 只通知监听该 ID 的 Widget 重建，其他 Widget 不受影响

### 3. 创建页面

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
            // 仅在 CounterId.count 变化时重建
            FlSelectorIds<CounterId, CounterController>(
              ids: [CounterId.count],
              builder: (ctx, ctrl, _) => Text('${ctrl.count}'),
            ),
            // 仅在 CounterId.loading 变化时重建
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

**关键模式：**
- `FlBasePage<CounterController>` — 无状态页面基类，自动通过 `ChangeNotifierProvider` 注入 Controller
- `createController` — Controller 工厂方法
- `buildWithController` — 直接接收 Controller，无需手动调用 `Provider.of<T>()`
- `FlSelectorIds` — 只订阅指定的枚举 ID，避免不必要的重建

### 4. 配置 MaterialApp

```dart
MaterialApp(
  navigatorObservers: [FlRouteObserver.instance],
  home: const CounterPage(),
)
```

必须添加 `FlRouteObserver.instance`，否则生命周期钩子（`onPageStart`、`onPageResume` 等）不会触发。

### 5. 在 Controller 中使用生命周期钩子

可 override 以下任意钩子：

```dart
class MyController extends FlBaseController<MyId> {
  @override
  List<MyId> get shouldNotifyIds => MyId.values.toList();

  @override
  void onPageInit() { /* Controller 创建完成 */ }

  @override
  void onPageContextReady(BuildContext? context) { /* 路由信息可用 */ }

  @override
  void onPagePostFrame() { /* 首帧已渲染 */ }

  @override
  void onPageStart() { /* 页面变为可见 */ }

  @override
  void onPageResume() { /* 恢复可见（pop 返回） */ }

  @override
  void onPagePause() { /* 被 Popup 覆盖 */ }

  @override
  void onPageStop() { /* 完全不可见 */ }

  @override
  void onPageDispose() { /* 清理资源 */ }

  @override
  void onAppResume() { /* App 回到前台 */ }

  @override
  void onAppBackground() { /* App 进入后台 */ }
}
```

### 6. 事件总线（跨 Controller 通信）

```dart
// 定义事件类型
class UserLoggedIn { final String userId; UserLoggedIn(this.userId); }
class UserLoggedOut {}

// 发送事件
dispatchEvent(UserLoggedIn('abc123'));

// 在其他 Controller 中监听
observeEvent<UserLoggedIn>((event) {
  print('用户 ${event.userId} 登录了');
});
```

**自动清理：** Controller dispose 时会自动取消所有事件订阅，无需手动处理。

### 7. PageView / IndexedStack 支持

override `pageIndex` 来启用 Tab 场景的生命周期：

```dart
class TabPage extends FlBasePage<MyController> {
  const TabPage({super.key});

  @override
  int get pageIndex => 0;  // 或 1, 2, ...

  // ... 其余实现
}
```

使用 `FlIndexedStack` 替代标准 `IndexedStack`：

```dart
FlIndexedStack(
  index: _currentIndex,
  children: [
    TabPage(),   // override pageIndex → 0
    TabPage2(),  // override pageIndex → 1
  ],
)
```

### 8. 使用 `child` 参数优化性能

将不随 ID 变化的静态 Widget 子树通过 `child` 传入，避免重复构建：

```dart
FlSelectorIds<CounterId, CounterController>(
  ids: [CounterId.count],
  child: const Icon(Icons.star),  // 永不重建
  builder: (ctx, ctrl, child) => Column(
    children: [
      if (child != null) child,
      Text('${ctrl.count}'),
    ],
  ),
)
```

---

## 重要约束

1. **必须先注册后通知** — 使用 `notifySingleListener` / `notifyMultiListeners` 前必须先调用 `registerIds(shouldNotifyIds)`（`onPageInit` 会自动完成）
2. **必须添加 `FlRouteObserver`** — 将 `FlRouteObserver.instance` 加入 `MaterialApp.navigatorObservers`，否则路由生命周期不生效
3. **PageView/IndexedStack 需设置 `pageIndex`** — Tab 场景必须设置 `pageIndex > -1`
4. **Dispose 后通知自动跳过** — 无需手动检查 `mounted`
5. **Build 阶段的通知延迟到 post-frame** — 避免 build 过程中触发 setState 死循环

---

## 完整生命周期流程

```
State.initState()
  ├── onPageInit()  →  registerIds(shouldNotifyIds)
  └── 注册首帧 postFrameCallback

State.didChangeDependencies()
  ├── 注册 FlRouteObserver
  └── onPageContextReady()  →  setupRouteInfo(name, args)

首帧回调
  ├── 检测 PageView / IndexedStack / 普通页面
  ├── onPagePostFrame()
  └── isInPageView 同步到 Controller

页面可见
  ├── onPageStart()
  └── onPageResume()

运行期间：
  push 新页面     → onPageStop()
  push PopupRoute → onPagePause()
  pop 返回        → onPageResume()
  App 前台        → onAppResume()
  App 后台        → onAppBackground()

State.dispose()
  ├── 取消所有订阅
  ├── onPageDispose()
  └── Controller.dispose()
      ├── FlEventBusMixin: cancel 所有 StreamSubscription
      └── FlNotifyMixin: clear _updatedIds, 标记 _disposed
```

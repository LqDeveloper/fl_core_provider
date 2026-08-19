# fl_core_provider

> 基于 `provider` 的 Flutter 状态管理框架 — Controller 基类 + 页面/App 生命周期 + 类型安全事件总线 + 枚举粒度 UI 刷新

---

## 快速开始

### 1. 添加依赖

`provider` 是 `fl_core_provider` 的直接依赖，会自动传递引入，无需手动添加：

```yaml
dependencies:
  fl_core_provider: ^0.1.5
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

### 7. PageView / TabBarView 支持

> ⚠️ **`FlPageViewScope` 与 `observePageView => true` 必须搭配使用**，缺一个都不生效：
>
> | 宿主包 `FlPageViewScope` | 子页声明 `observePageView => true` | 结果 |
> | :---: | :---: | --- |
> | ✅ | ✅ | 切页生命周期正常工作 |
> | ✅ | ❌ | Scope 下发了页码，但子页不读取 —— 首帧即判定可见 |
> | ❌ | ✅ | 子页想读，但找不到 Scope —— 回退成普通路由页 |
> | ❌ | ❌ | 普通路由页 |
>
> `observePageView` 默认值是 **`false`**，所以必须显式声明才会开启。

**第 1 步 —— 宿主侧**：在构建 `PageView` / `TabBarView` 的一侧，用
`FlPageViewScope.wrapChildren` 把子页包一层（不会引入额外布局节点）：

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

// TabBarView —— 传 TabController
TabBarView(
  children: FlPageViewScope.wrapChildren(
    controller: DefaultTabController.of(context),  // TabController
    children: const [PageOne(), PageTwo(), PageThree(), PageFour()],
  ),
)
```

`PageView.builder` 则包 `itemBuilder`：

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

**第 2 步 —— 每个子页**：override `observePageView` 为 `true`。不写这一句，无论宿主怎么包，
子页都不会去读 Scope：

```dart
class _PageOneState extends FlBasePageState<PageOne, PageOneController> {
  @override
  bool get observePageView => true;   // ← 必须声明，默认是 false

  // ... 其余实现
}

// StatelessWidget 版同名 getter
class PageOne extends FlBasePage<PageOneController> {
  @override
  bool get observePageView => true;
}
```

**两步都做到之后，子页的行为变化：**
- `onPageStart` / `onPageResume` / `onPagePause` / `onPageStop` 改由**切页**驱动，
  而不是路由变化 —— 切到第 2 页，第 1 页就会收到 stop
- 拖过半页即翻转可见性，`PageController` 与 `TabController` 时机一致
- 页码变化时 Controller 上的 `onPageViewChanged(from, to)` 会被触发
- 支持嵌套：`PageView` 里再套 `TabBarView`，外层滑走时内层当前页同样收到 stop，
  滑回来再一起 start
- `controller` 只接受 `PageController` 或 `TabController`（构造时有断言把关）

**缺任意一步的子页**都会被当成普通页面：首帧即判定为可见，可见性不随翻页变化。
如果某个页面不需要参与 PageView 可见性判定（而兄弟页需要），保持 `observePageView`
的默认值 `false`、不 override 即可。

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
3. **PageView/TabBarView 需要 `FlPageViewScope` + `observePageView => true`** — 宿主用 `FlPageViewScope.wrapChildren` / `wrapItemBuilder` 把子页包一层，**并且**每个子页 override `bool get observePageView => true`（默认 `false`）。只做其中一步不会报错但完全无效：子页被当成普通页面，首帧即可见，收不到任何切页生命周期
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
  ├── 查找最近一层 FlPageViewScope（拿到页码 + 可见性）
  └── onPageContextReady()  →  setupRouteInfo(name, args)

首帧回调
  ├── observePageView 且命中 Scope → 可见性由页码决定
  │   否则                          → 按普通页面处理，首帧即可见
  └── onPagePostFrame()

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

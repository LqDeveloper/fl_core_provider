import 'package:flutter/material.dart';

import 'package:meta/meta.dart';

import 'lifecycle_route_aware.dart';

class FlRouteObserver extends NavigatorObserver {
  static final FlRouteObserver instance = FlRouteObserver._();

  factory FlRouteObserver() => instance;

  FlRouteObserver._();

  final Map<Route<dynamic>, Set<LifecycleRouteAware>> _listeners =
      <Route<dynamic>, Set<LifecycleRouteAware>>{};

  @internal
  void subscribe(ModalRoute route, LifecycleRouteAware routeAware) {
    final subscribers = _listeners.putIfAbsent(
      route,
      () => <LifecycleRouteAware>{},
    );
    subscribers.add(routeAware);
  }

  @internal
  void unsubscribe(LifecycleRouteAware routeAware) {
    final routes = _listeners.keys.toList();
    for (final route in routes) {
      final subscribers = _listeners[route];
      if (subscribers != null) {
        subscribers.remove(routeAware);
        if (subscribers.isEmpty) {
          _listeners.remove(route);
        }
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // remove route atomically: 通知后不再持有已 pop 的 route
    final subscribers = _listeners.remove(route)?.toList();
    if (subscribers != null) {
      for (final routeAware in subscribers) {
        routeAware.routePageStop();
      }
    }

    final isPopup = route is PopupRoute;
    final previousSubscribers = _listeners[previousRoute]?.toList();
    if (previousSubscribers != null) {
      for (final routeAware in previousSubscribers) {
        if (isPopup) {
          routeAware.routePageResume();
        } else {
          routeAware.routePageStart();
        }
      }
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    // remove route atomically: 通知后不再持有已移除的 route
    final subscribers = _listeners.remove(route)?.toList();
    if (subscribers != null) {
      for (final routeAware in subscribers) {
        routeAware.routePageStop();
      }
    }

    final previousSubscribers = _listeners[previousRoute]?.toList();
    if (previousSubscribers != null) {
      for (final routeAware in previousSubscribers) {
        routeAware.routePageStart();
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final previousSubscribers = _listeners[previousRoute];
    final isPopup = route is PopupRoute;
    if (previousSubscribers != null) {
      for (final routeAware in previousSubscribers) {
        if (isPopup) {
          routeAware.routePagePause();
        } else {
          routeAware.routePageStop();
        }
      }
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    // pushReplacement: 旧路由立即从 _listeners 中移除
    if (oldRoute != null) {
      final subscribers = _listeners.remove(oldRoute)?.toList();
      if (subscribers != null) {
        for (final routeAware in subscribers) {
          routeAware.routePageStop();
        }
      }
    }
  }
}

// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library route.route;

import 'dart:async';

import 'package:logging/logging.dart';

import 'url_matcher.dart';
export 'url_matcher.dart';
import 'src/common.dart';
import 'url_template.dart';
import 'package:route_hierarchical/src/utils.dart';
import 'dart:math';

part 'route_handle.dart';

final _logger = new Logger('route');
const _PATH_SEPARATOR = '.';

/**
 * [Route] represents a node in the route tree.
 */
abstract class Route {
  /**
   * Name of the route. Used when querying routes.
   */
  String get name;

  /**
   * A path fragment [UrlMatcher] for this route.
   */
  UrlMatcher get path;

  /**
   * Parent route in the route tree.
   */
  Route get parent;

  /**
   * Indicates whether this route is currently active. Root route is always
   * active.
   */
  bool get isActive;

  /**
   * Returns parameters for the currently active route. If the route is not
   * active the getter returns null.
   */
  Map get parameters;

  /**
   * Returns query parameters for the currently active route. If the route is
   * not active the getter returns null.
   */
  Map get queryParameters;

  /**
   * Whether to trigger the leave event when only the parameters change.
   */
  bool get dontLeaveOnParamChanges;

  /**
   * Used to set page title when the route [isActive].
   */
  String get pageTitle;

  /**
   * Returns a stream of [RouteEnterEvent] events. The [RouteEnterEvent] event
   * is fired when route has already been made active, but before subroutes
   * are entered. The event starts at the root and propagates from parent to
   * child routes.
   */
  @Deprecated("use [onEnter] instead.")
  Stream<RouteEnterEvent> get onRoute;

  /**
   * Returns a stream of [RoutePreEnterEvent] events. The [RoutePreEnterEvent]
   * event is fired when the route is matched during the routing, but before
   * any previous routes were left, or any new routes were entered. The event
   * starts at the root and propagates from parent to child routes.
   *
   * At this stage it's possible to veto entering of the route by calling
   * [RoutePreEnterEvent.allowEnter] with a [Future] returns a boolean value
   * indicating whether enter is permitted (true) or not (false).
   */
  Stream<RoutePreEnterEvent> get onPreEnter;

  /**
   * Returns a stream of [RoutePreLeaveEvent] events. The [RoutePreLeaveEvent]
   * event is fired when the route is NOT matched during the routing, but before
   * any routes are actually left, or any new routes were entered.
   *
   * At this stage it's possible to veto leaving of the route by calling
   * [RoutePreLeaveEvent.allowLeave] with a [Future] returns a boolean value
   * indicating whether enter is permitted (true) or not (false).
   */
  Stream<RoutePreLeaveEvent> get onPreLeave;

  /**
   * Returns a stream of [RouteLeaveEvent] events. The [RouteLeaveEvent]
   * event is fired when the route is being left. The event starts at the leaf
   * route and propagates from child to parent routes.
   */
  Stream<RouteLeaveEvent> get onLeave;

  /**
   * Returns a stream of [RouteEnterEvent] events. The [RouteEnterEvent] event
   * is fired when route has already been made active, but before subroutes
   * are entered.  The event starts at the root and propagates from parent
   * to child routes.
   */
  Stream<RouteEnterEvent> get onEnter;

  void addRoute({String name, Pattern path, bool defaultRoute: false,
      RouteEnterEventHandler enter, RoutePreEnterEventHandler preEnter,
      RoutePreLeaveEventHandler preLeave, RouteLeaveEventHandler leave, mount,
      dontLeaveOnParamChanges: false, String pageTitle,
      List<Pattern> watchQueryParameters});

  /**
   * Queries sub-routes using the [routePath] and returns the matching [Route].
   *
   * [routePath] is a dot-separated list of route names. Ex: foo.bar.baz, which
   * means that current route should contain route named 'foo', the 'foo' route
   * should contain route named 'bar', and so on.
   *
   * If no match is found then null is returned.
   */
  @Deprecated("use [findRoute] instead.")
  Route getRoute(String routePath);

  /**
   * Queries sub-routes using the [routePath] and returns the matching [Route].
   *
   * [routePath] is a dot-separated list of route names. Ex: foo.bar.baz, which
   * means that current route should contain route named 'foo', the 'foo' route
   * should contain route named 'bar', and so on.
   *
   * If no match is found then null is returned.
   */
  Route findRoute(String routePath);

  /**
   * Create an return a new [RouteHandle] for this route.
   */
  RouteHandle newHandle();

  String toString() => '[Route: $name]';
}

/**
 * Route is a node in the tree of routes. The edge leading to the route is
 * defined by path.
 */
class RouteImpl extends Route {
  @override
  final String name;
  @override
  final UrlMatcher path;
  @override
  final RouteImpl parent;
  @override
  final String pageTitle;

  /// Child routes map route names to `Route` instances
  final routes = <String, RouteImpl>{};

  final StreamController<RouteEnterEvent> onEnterController;
  final StreamController<RoutePreEnterEvent> onPreEnterController;
  final StreamController<RoutePreLeaveEvent> onPreLeaveController;
  final StreamController<RouteLeaveEvent> onLeaveController;

  final List<Pattern> watchQueryParameters;

  /// The default child route
  RouteImpl _defaultRoute;
  RouteImpl get defaultRoute => _defaultRoute;

  /// The currently active child route
  RouteImpl currentRoute;
  RouteEvent lastEvent;
  @override
  final bool dontLeaveOnParamChanges;

  @override
  @Deprecated("use [onEnter] instead.")
  Stream<RouteEnterEvent> get onRoute => onEnter;
  @override
  Stream<RoutePreEnterEvent> get onPreEnter => onPreEnterController.stream;
  @override
  Stream<RoutePreLeaveEvent> get onPreLeave => onPreLeaveController.stream;
  @override
  Stream<RouteLeaveEvent> get onLeave => onLeaveController.stream;
  @override
  Stream<RouteEnterEvent> get onEnter => onEnterController.stream;

  RouteImpl({this.name, this.path, this.parent,
      this.dontLeaveOnParamChanges: false, this.pageTitle,
      watchQueryParameters})
      : onEnterController = new StreamController<RouteEnterEvent>.broadcast(
          sync: true),
        onPreEnterController = new StreamController<RoutePreEnterEvent>.broadcast(
            sync: true),
        onPreLeaveController = new StreamController<RoutePreLeaveEvent>.broadcast(
            sync: true),
        onLeaveController = new StreamController<RouteLeaveEvent>.broadcast(
            sync: true),
        watchQueryParameters = watchQueryParameters;

  @override
  void addRoute({String name, Pattern path, bool defaultRoute: false,
      RouteEnterEventHandler enter, RoutePreEnterEventHandler preEnter,
      RoutePreLeaveEventHandler preLeave, RouteLeaveEventHandler leave, mount,
      dontLeaveOnParamChanges: false, String pageTitle,
      List<Pattern> watchQueryParameters}) {
    if (name == null) {
      throw new ArgumentError('name is required for all routes');
    }
    if (name.contains(_PATH_SEPARATOR)) {
      throw new ArgumentError('name cannot contain dot.');
    }
    if (routes.containsKey(name)) {
      throw new ArgumentError('Route $name already exists');
    }

    var matcher = path is UrlMatcher ? path : new UrlTemplate(path.toString());

    var route = new RouteImpl(
        name: name,
        path: matcher,
        parent: this,
        dontLeaveOnParamChanges: dontLeaveOnParamChanges,
        pageTitle: pageTitle,
        watchQueryParameters: watchQueryParameters);

    route
      ..onPreEnter.listen(preEnter)
      ..onPreLeave.listen(preLeave)
      ..onEnter.listen(enter)
      ..onLeave.listen(leave);

    if (mount != null) {
      if (mount is Function) {
        mount(route);
      } else if (mount is Routable) {
        mount.configureRoute(route);
      }
    }

    if (defaultRoute) {
      if (_defaultRoute != null) {
        throw new StateError('Only one default route can be added.');
      }
      _defaultRoute = route;
    }
    routes[name] = route;
  }

  @override
  Route getRoute(String routePath) => findRoute(routePath);

  @override
  Route findRoute(String routePath) {
    RouteImpl currentRoute = this;
    List<String> subRouteNames = routePath.split(_PATH_SEPARATOR);
    while (subRouteNames.isNotEmpty) {
      var routeName = subRouteNames.removeAt(0);
      currentRoute = currentRoute.routes[routeName];
      if (currentRoute == null) {
        _logger.warning('Invalid route name: $routeName $routes');
        return null;
      }
    }
    return currentRoute;
  }

  String getHead(String tail) {
    for (RouteImpl route = this; route.parent != null; route = route.parent) {
      var currentRoute = route.parent.currentRoute;
      if (currentRoute == null) {
        throw new StateError(
            'Route ${route.parent.name} has no current route.');
      }

      tail = currentRoute.reverse(tail);
    }
    return tail;
  }

  String getTailUrl(Route routeToGo, Map parameters) {
    var tail = '';
    for (RouteImpl route = routeToGo; route != this; route = route.parent) {
      tail = route.path.reverse(
          parameters: _joinParams(parameters == null
              ? route.parameters
              : parameters, route.lastEvent),
          tail: tail);
    }
    return tail;
  }

  Map _joinParams(Map parameters, RouteEvent lastEvent) =>
      lastEvent == null ? parameters : new Map.from(lastEvent.parameters)
    ..addAll(parameters);

  /**
   * Returns a URL for this route. The tail (url generated by the child path)
   * will be passes to the UrlMatcher to be properly appended in the
   * right place.
   */
  String reverse(String tail) =>
      path.reverse(parameters: lastEvent.parameters, tail: tail);

  /**
   * Create an return a new [RouteHandle] for this route.
   */
  @override
  RouteHandle newHandle() {
    _logger.finest('newHandle for $this');
    return new RouteHandle(this);
  }

  /**
   * Indicates whether this route is currently active. Root route is always
   * active.
   */
  @override
  bool get isActive =>
      parent == null ? true : identical(parent.currentRoute, this);

  /**
   * Returns parameters for the currently active route. If the route is not
   * active the getter returns null.
   */
  @override
  Map get parameters {
    if (isActive) {
      return lastEvent == null ? const {} : new Map.from(lastEvent.parameters);
    }
    return null;
  }

  /**
   * Returns parameters for the currently active route. If the route is not
   * active the getter returns null.
   */
  @override
  Map get queryParameters {
    if (isActive) {
      return lastEvent == null
          ? const {}
          : new Map.from(lastEvent.queryParameters);
    }
    return null;
  }
}

abstract class Routable {
  void configureRoute(Route router);
}

class IndependentRouter {
  final bool useFragment;
  final Route root;
  final _onRouteStart =
      new StreamController<RouteStartEvent>.broadcast(sync: true);
  final bool sortRoutes;

  /**
   * [useFragment] determines whether this Router uses pure paths with
   * [History.pushState] or paths + fragments and [Location.assign]. The default
   * value is null which then determines the behavior based on
   * [History.supportsState].
   */
  IndependentRouter({bool useFragment, bool sortRoutes: true})
      : this._init(null, useFragment: useFragment, sortRoutes: sortRoutes);

  IndependentRouter._init(IndependentRouter parent, {bool useFragment, this.sortRoutes})
      : useFragment = useFragment,
        root = new RouteImpl();

  /**
   * A stream of route calls.
   */
  Stream<RouteStartEvent> get onRouteStart => _onRouteStart.stream;

  /**
   * Finds a matching [Route] added with [addRoute], parses the path
   * and invokes the associated callback. Search for the matching route starts
   * at [startingFrom] route or the root [Route] if not specified. By default
   * the common path from [startingFrom] to the current active path and target
   * path will be ignored (i.e. no leave or enter will be executed on them).
   *
   * This method does not perform any navigation, [go] should be used for that.
   * This method is used to invoke a handler after some other code navigates the
   * window, such as [listen].
   *
   * Setting [forceReload] to true (default false) will force the matched routes
   * to reload, even if they are already active and none of the parameters
   * changed.
   */
  Future<bool> route(String path,
      {Route startingFrom, bool forceReload: false}) {
    _logger.finest('route path=$path startingFrom=$startingFrom '
        'forceReload=$forceReload');
    var baseRoute;
    var trimmedActivePath;
    if (startingFrom == null) {
      baseRoute = root;
      trimmedActivePath = activePath;
    } else {
      baseRoute = dehandle(startingFrom);
      trimmedActivePath = activePath.sublist(activePath.indexOf(baseRoute) + 1);
    }

    var treePath = _matchingTreePath(path, baseRoute);
    // Figure out the list of routes that will be leaved
    var mustLeave = trimmedActivePath;
    var future =
        _preLeave(path, treePath, trimmedActivePath, baseRoute, forceReload);
    _onRouteStart.add(new RouteStartEvent(path, future));
    return future;
  }

  /**
   * Called before leaving the current route.
   *
   * If none of the preLeave listeners veto the leave, chain call [_preEnter].
   *
   * If at least one preLeave listeners veto the leave, returns a Future that
   * will resolve to false. The current route will not change.
   */
  Future<bool> _preLeave(String path, List<RMatch> treePath,
      List<RouteImpl> activePath, RouteImpl baseRoute, bool forceReload) {
    var mustLeave = activePath;
    var leaveBase = baseRoute;
    for (var i = 0, ll = min(activePath.length, treePath.length); i < ll; i++) {
      if (mustLeave.first == treePath[i].route &&
          (treePath[i].route.dontLeaveOnParamChanges ||
              !(forceReload ||
                  _paramsChanged(treePath[i].route, treePath[i])))) {
        mustLeave = mustLeave.skip(1);
        leaveBase = leaveBase.currentRoute;
      } else {
        break;
      }
    }
    // Reverse the list to ensure child is left before the parent.
    mustLeave = mustLeave.toList().reversed;

    var preLeaving = <Future<bool>>[];
    mustLeave.forEach((toLeave) {
      var event = new RoutePreLeaveEvent(toLeave);
      toLeave.onPreLeaveController.add(event);
      preLeaving.addAll(event.allowLeaveFutures);
    });
    return Future.wait(preLeaving).then((List<bool> results) {
      if (!results.any((r) => r == false)) {
        var leaveFn = () => _leave(mustLeave, leaveBase);
        return _preEnter(
            path, treePath, activePath, baseRoute, leaveFn, forceReload);
      }
      return new Future.value(false);
    });
  }

  void _leave(Iterable<Route> mustLeave, Route leaveBase) {
    mustLeave.forEach((toLeave) {
      var event = new RouteLeaveEvent(toLeave);
      toLeave.onLeaveController.add(event);
    });
    if (!mustLeave.isEmpty) {
      _unsetAllCurrentRoutesRecursively(leaveBase);
    }
  }

  void _unsetAllCurrentRoutesRecursively(RouteImpl r) {
    if (r.currentRoute != null) {
      _unsetAllCurrentRoutesRecursively(r.currentRoute);
      r.currentRoute = null;
    }
  }

  Future<bool> _preEnter(String path, List<RMatch> treePath,
      List<Route> activePath, RouteImpl baseRoute, Function leaveFn,
      bool forceReload) {
    var toEnter = treePath;
    var tail = path;
    var enterBase = baseRoute;
    for (var i = 0, ll = min(toEnter.length, activePath.length); i < ll; i++) {
      if (toEnter.first.route == activePath[i] &&
          !(forceReload || _paramsChanged(activePath[i], treePath[i]))) {
        tail = treePath[i].urlMatch.tail;
        toEnter = toEnter.skip(1);
        enterBase = enterBase.currentRoute;
      } else {
        break;
      }
    }
    if (toEnter.isEmpty) {
      leaveFn();
      return new Future.value(true);
    }

    var preEnterFutures = <Future<bool>>[];
    toEnter.forEach((RMatch matchedRoute) {
      var preEnterEvent = new RoutePreEnterEvent.fromMatch(matchedRoute);
      matchedRoute.route.onPreEnterController.add(preEnterEvent);
      preEnterFutures.addAll(preEnterEvent.allowEnterFutures);
    });
    return Future.wait(preEnterFutures).then((List<bool> results) {
      if (!results.any((v) => v == false)) {
        leaveFn();
        _enter(enterBase, toEnter, tail);
        return new Future.value(true);
      }
      return new Future.value(false);
    });
  }

  void _enter(RouteImpl startingFrom, Iterable<RMatch> treePath, String path) {
    var base = startingFrom;
    treePath.forEach((RMatch matchedRoute) {
      var event = new RouteEnterEvent.fromMatch(matchedRoute);
      base.currentRoute = matchedRoute.route;
      base.currentRoute.lastEvent = event;
      matchedRoute.route.onEnterController.add(event);
      base = matchedRoute.route;
    });
  }

  /// Returns the direct child routes of [baseRoute] matching the given [path]
  List<RouteImpl> _matchingRoutes(String path, RouteImpl baseRoute) {
    var routes = baseRoute.routes.values
        .where((RouteImpl r) => r.path.match(path) != null)
        .toList();

    return sortRoutes
        ? (routes..sort((r1, r2) => r1.path.compareTo(r2.path)))
        : routes;
  }

  /// Returns the path as a list of [RMatch]
  List<RMatch> _matchingTreePath(String path, RouteImpl baseRoute) {
    final treePath = <RMatch>[];
    Route matchedRoute;
    do {
      matchedRoute = null;
      List matchingRoutes = _matchingRoutes(path, baseRoute);
      if (matchingRoutes.isNotEmpty) {
        if (matchingRoutes.length > 1) {
          _logger.fine("More than one route matches $path $matchingRoutes");
        }
        matchedRoute = matchingRoutes.first;
      } else {
        if (baseRoute.defaultRoute != null) {
          matchedRoute = baseRoute.defaultRoute;
        }
      }
      if (matchedRoute != null) {
        var match = _getMatch(matchedRoute, path);
        treePath.add(match);
        baseRoute = matchedRoute;
        path = match.urlMatch.tail;
      }
    } while (matchedRoute != null);
    return treePath;
  }

  bool _paramsChanged(RouteImpl route, RMatch match) {
    var lastEvent = route.lastEvent;
    return lastEvent == null ||
        lastEvent.path != match.urlMatch.match ||
        !mapsShallowEqual(lastEvent.parameters, match.urlMatch.parameters) ||
        !mapsShallowEqual(_filterQueryParams(
                lastEvent.queryParameters, route.watchQueryParameters),
            _filterQueryParams(
                match.queryParameters, route.watchQueryParameters));
  }

  Map _filterQueryParams(
      Map queryParameters, List<Pattern> watchQueryParameters) {
    if (watchQueryParameters == null) {
      return queryParameters;
    }
    Map result = {};
    queryParameters.keys.forEach((key) {
      if (watchQueryParameters
          .any((pattern) => pattern.matchAsPrefix(key) != null)) {
        result[key] = queryParameters[key];
      }
    });
    return result;
  }

  Future<bool> reload({Route startingFrom}) {
    var path = activePath;
    RouteImpl baseRoute = startingFrom == null ? root : dehandle(startingFrom);
    if (baseRoute != root) {
      path = path.skipWhile((r) => r != baseRoute).skip(1).toList();
    }
    String reloadPath = '';
    for (int i = path.length - 1; i >= 0; i--) {
      reloadPath = path[i].reverse(reloadPath);
    }
    reloadPath += buildQuery(path.isEmpty ? {} : path.last.queryParameters);
    return route(reloadPath, startingFrom: startingFrom, forceReload: true);
  }

  /// Returns an absolute URL for a given relative route path and parameters.
  String url(String routePath,
      {Route startingFrom, Map parameters, Map queryParameters}) {
    var baseRoute = startingFrom == null ? root : dehandle(startingFrom);
    parameters = parameters == null ? {} : parameters;
    var routeToGo = findRouteFromBase(baseRoute, routePath);
    var tail = baseRoute.getTailUrl(routeToGo, parameters);
    return (useFragment ? '#' : '') +
        baseRoute.getHead(tail) +
        buildQuery(queryParameters);
  }

  /// Attempts to find [Route] for the specified [routePath] relative to the
  /// [baseRoute]. If nothing is found throws a [StateError].
  Route findRouteFromBase(Route baseRoute, String routePath) {
    var route = baseRoute.findRoute(routePath);
    if (route == null) {
      throw new StateError('Invalid route path: $routePath');
    }
    return route;
  }

  /// Build an query string from a parameter `Map`
  String buildQuery(Map queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return '';
    }
    return '?' +
        queryParams.keys
            .map((key) => '$key=${Uri.encodeComponent(queryParams[key])}')
            .join('&');
  }

  Route dehandle(Route r) => r is RouteHandle ? r.getHost(r) : r;

  RMatch _getMatch(Route route, String path) {
    var match = route.path.match(path);
    // default route
    if (match == null) {
      return new RMatch(route, new UrlMatch('', '', {}), {});
    }
    return new RMatch(route, match, _parseQuery(route, path));
  }

  /// Parse the query string to a parameter `Map`
  Map<String, String> _parseQuery(Route route, String path) {
    var params = {};
    if (path.indexOf('?') == -1) return params;
    var queryStr = path.substring(path.indexOf('?') + 1);
    queryStr.split('&').forEach((String keyValPair) {
      List<String> keyVal = _parseKeyVal(keyValPair);
      var key = keyVal[0];
      if (key.isNotEmpty) {
        params[key] = Uri.decodeComponent(keyVal[1]);
      }
    });
    return params;
  }

  /**
   * Parse a key value pair (`"key=value"`) and returns a list of
   * `["key", "value"]`.
   */
  List<String> _parseKeyVal(String kvPair) {
    if (kvPair.isEmpty) {
      return const ['', ''];
    }
    var splitPoint = kvPair.indexOf('=');

    return (splitPoint == -1)
        ? [kvPair, '']
        : [kvPair.substring(0, splitPoint), kvPair.substring(splitPoint + 1)];
  }

  /**
   * Returns the current active route path in the route tree.
   * Excludes the root path.
   */
  List<Route> get activePath {
    var res = <RouteImpl>[];
    var route = root;
    while (route.currentRoute != null) {
      route = route.currentRoute;
      res.add(route);
    }
    return res;
  }

  /**
   * A shortcut for router.root.findRoute().
   */
  Route findRoute(String routePath) => root.findRoute(routePath);
}

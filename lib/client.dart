// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library route.client;

import 'dart:async';
import 'dart:html';

import 'package:logging/logging.dart';

import 'link_matcher.dart';
import 'click_handler.dart';
import 'url_matcher.dart';
export 'url_matcher.dart';
import 'router.dart';
export 'router.dart';
import 'src/common.dart';

final _logger = new Logger('route.client');
const _PATH_SEPARATOR = '.';

/**
 * Stores a set of [UrlPattern] to [Handler] associations and provides methods
 * for calling a handler for a URL path, listening to [Window] history events,
 * and creating HTML event handlers that navigate to a URL.
 */
class Router extends IndependentRouter{
  final Window _window;
  WindowClickHandler _clickHandler;
  bool _listen = false;

  /**
   * [useFragment] determines whether this Router uses pure paths with
   * [History.pushState] or paths + fragments and [Location.assign]. The default
   * value is null which then determines the behavior based on
   * [History.supportsState].
   */
  Router({bool useFragment, Window windowImpl, bool sortRoutes: true,
         RouterLinkMatcher linkMatcher, WindowClickHandler clickHandler})
      : this._init(null, useFragment: useFragment, windowImpl: windowImpl,
          sortRoutes: sortRoutes, linkMatcher: linkMatcher,
          clickHandler: clickHandler);


  Router._init(Router parent, {bool useFragment, Window windowImpl,
      sortRoutes, RouterLinkMatcher linkMatcher,
      WindowClickHandler clickHandler})
      :  _window = (windowImpl == null) ? window : windowImpl, super(useFragment: (useFragment == null)
            ? !History.supportsState
            : useFragment, sortRoutes: sortRoutes){
    if (clickHandler == null) {
      if (linkMatcher == null) {
        linkMatcher = new DefaultRouterLinkMatcher();
      }
      _clickHandler = new DefaultWindowClickHandler(linkMatcher, this,
          this.useFragment, _window, _normalizeHash);
    } else {
      _clickHandler = clickHandler;
    }
  }

  /// Navigates to a given relative route path, and parameters.
  Future<bool> go(String routePath, Map parameters, {Route startingFrom,
       bool replace: false, Map queryParameters, bool forceReload: false}) {
    RouteImpl baseRoute = startingFrom == null ? root : dehandle(startingFrom);
    var routeToGo = findRouteFromBase(baseRoute, routePath);
    var newTail = baseRoute.getTailUrl(routeToGo, parameters) +
        buildQuery(queryParameters);
    String newUrl = baseRoute.getHead(newTail);
    _logger.finest('go $newUrl');
    return route(newTail, startingFrom: baseRoute, forceReload: forceReload)
        .then((success) {
          if (success) {
            _go(newUrl, routeToGo.pageTitle, replace);
          }
          return success;
        });
  }

  /**
   * Listens for window history events and invokes the router. On older
   * browsers the hashChange event is used instead.
   */
  void listen({bool ignoreClick: false, Element appRoot}) {
    _logger.finest('listen ignoreClick=$ignoreClick');
    if (_listen) {
      throw new StateError('listen can only be called once');
    }
    _listen = true;
    if (useFragment) {
      _window.onHashChange.listen((_) {
        route(_normalizeHash(_window.location.hash)).then((allowed) {
          // if not allowed, we need to restore the browser location
          if (!allowed) {
            _window.history.back();
          }
        });
      });
      route(_normalizeHash(_window.location.hash));
    } else {
      String getPath() =>
          '${_window.location.pathname}${_window.location.search}'
          '${_window.location.hash}';

      _window.onPopState.listen((_) {
        route(getPath()).then((allowed) {
          // if not allowed, we need to restore the browser location
          if (!allowed) {
            _window.history.back();
          }
        });
      });
      route(getPath());
    }
    if (!ignoreClick) {
      if (appRoot == null) {
        appRoot = _window.document.documentElement;
      }
      _logger.finest('listen on win');
      appRoot.onClick
          .where((MouseEvent e) => !(e.ctrlKey || e.metaKey || e.shiftKey))
          .listen(_clickHandler);
    }
  }

  String _normalizeHash(String hash) => hash.isEmpty ? '' : hash.substring(1);

  /**
   * Navigates the browser to the path produced by [url] with [args] by calling
   * [History.pushState], then invokes the handler associated with [url].
   *
   * On older browsers [Location.assign] is used instead with the fragment
   * version of the UrlPattern.
   */
  Future<bool> gotoUrl(String url) =>
      route(url).then((success) {
        if (success) {
          _go(url, null, false);
        }
      });

  void _go(String path, String title, bool replace) {
    if (useFragment) {
      if (replace) {
        _window.location.replace('#$path');
      } else {
        _window.location.assign('#$path');
      }
    } else {
      if (title == null) {
        title = (_window.document as HtmlDocument).title;
      }
      if (replace) {
        _window.history.replaceState(null, title, path);
      } else {
        _window.history.pushState(null, title, path);
      }
    }
    if (title != null) {
      (_window.document as HtmlDocument).title = title;
    }
  }

}
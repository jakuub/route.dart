library route.common;

import '../router.dart';
import 'dart:async';

typedef void RoutePreEnterEventHandler(RoutePreEnterEvent event);
typedef void RouteEnterEventHandler(RouteEnterEvent event);
typedef void RoutePreLeaveEventHandler(RoutePreLeaveEvent event);
typedef void RouteLeaveEventHandler(RouteLeaveEvent event);

/**
 * Route enter or leave event.
 */
abstract class RouteEvent {
  final String path;
  final Map parameters;
  final Map queryParameters;
  final Route route;

  RouteEvent(this.path, this.parameters, this.queryParameters, this.route);
}

class RoutePreEnterEvent extends RouteEvent {
  final allowEnterFutures = <Future<bool>>[];

  RoutePreEnterEvent(path, parameters, queryParameters, route)
      : super(path, parameters, queryParameters, route);

  RoutePreEnterEvent.fromMatch(RMatch m)
      : this(m.urlMatch.tail, m.urlMatch.parameters, {}, m.route);

  /**
   * Can be called with a future which will complete with a boolean
   * value allowing (true) or disallowing (false) the current navigation.
   */
  void allowEnter(Future<bool> allow) {
    allowEnterFutures.add(allow);
  }
}

class RouteEnterEvent extends RouteEvent {
  RouteEnterEvent(path, parameters, queryParameters, route)
      : super(path, parameters, queryParameters, route);

  RouteEnterEvent.fromMatch(RMatch m)
      : this(m.urlMatch.match, m.urlMatch.parameters,
          m.queryParameters, m.route);
}

class RouteLeaveEvent extends RouteEvent {
  RouteLeaveEvent(route) : super('', {}, {}, route);
}

class RoutePreLeaveEvent extends RouteEvent {
  final allowLeaveFutures = <Future<bool>>[];

  RoutePreLeaveEvent(route) : super('', {}, {}, route);

  /**
   * Can be called with a future which will complete with a boolean
   * value allowing (true) or disallowing (false) the current navigation.
   */
  void allowLeave(Future<bool> allow) {
    allowLeaveFutures.add(allow);
  }
}

/**
 * Event emitted when routing starts.
 */
class RouteStartEvent {
  /**
   * URI that was passed to [Router.route].
   */
  final String uri;

  /**
   * Future that completes to a boolean value of whether the routing was
   * successful.
   */
  final Future<bool> completed;

  RouteStartEvent(this.uri, this.completed);
}



class RMatch {
  final RouteImpl route;
  final UrlMatch urlMatch;
  final Map queryParameters;

  RMatch(this.route, this.urlMatch, this.queryParameters);

  String toString() => route.toString();
}

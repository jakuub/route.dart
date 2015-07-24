library route.route_test;
import 'package:unittest/unittest.dart';
import 'package:route_hierarchical/router.dart';
import 'package:route_hierarchical/src/common.dart';

main() {
  group("(IndependentRouter)", () {
    test("should be able to identify route", () {
      IndependentRouter router = new IndependentRouter();
      
      router.root.addRoute(name: "base", path: "/path/:id", enter: expectAsync((RouteEnterEvent event) {
        expect(event.parameters["id"], equals("3"));
      }));
      
      router.route("/path/3");
    });

    test("should route trough tree", () {
      IndependentRouter router = new IndependentRouter();
      
      router.root
        ..addRoute(name: "base", path: "/path/:id", enter: expectAsync((RouteEnterEvent event) {
          expect(event.parameters["id"], equals("3"));
        }), mount: (Route route) => route.addRoute(name: "subpath", path: "/subpath/:sub", enter: (RouteEnterEvent event) {
          expect(event.parameters["sub"], equals("hello"));
        }));
      
      router.route("/path/3/subpath/hello");
    });
  });
}
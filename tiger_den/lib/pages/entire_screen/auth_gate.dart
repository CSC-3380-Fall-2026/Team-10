import 'package:flutter/material.dart';

import '../../base_designs/sitewide/design_main.dart';
import '../../services/session_service.dart';
import '../widgets/login_page.dart';

/// Route names used by [TigerDenApp] to distinguish public authentication
/// screens from protected screens that require a logged-in user.
class AuthRoutes {
  AuthRoutes._();

  static const String loading = '/auth-loading';
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String appHome = '/app-home';

  static const Set<String> publicRoutes = <String>{
    login,
    signUp,
    forgotPassword,
  };

  static bool isPublic(String? routeName) =>
      routeName != null && publicRoutes.contains(routeName);
}

/// Tracks the stack of [PageRoute]s on the app's [Navigator] (ignoring popups
/// such as dialogs and bottom sheets) so [TigerDenApp] always knows whether
/// the currently visible screen requires authentication.
class AuthRedirectObserver extends NavigatorObserver {
  AuthRedirectObserver({required this.onRouteChanged});

  final VoidCallback onRouteChanged;
  final List<PageRoute<dynamic>> _pageStack = <PageRoute<dynamic>>[];

  String? get currentPageRouteName =>
      _pageStack.isEmpty ? null : _pageStack.last.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute<dynamic>) {
      _pageStack.add(route);
      onRouteChanged();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute<dynamic>) {
      _pageStack.remove(route);
      onRouteChanged();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is PageRoute<dynamic>) {
      _pageStack.remove(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute is PageRoute<dynamic>) {
      final int index = _pageStack.indexOf(oldRoute);
      if (index != -1 && newRoute is PageRoute<dynamic>) {
        _pageStack[index] = newRoute;
      } else {
        _pageStack.remove(oldRoute);
        if (newRoute is PageRoute<dynamic>) {
          _pageStack.add(newRoute);
        }
      }
      onRouteChanged();
    } else if (newRoute is PageRoute<dynamic>) {
      _pageStack.add(newRoute);
      onRouteChanged();
    }
  }
}

/// Root application wrapper that enforces authentication across every screen.
///
/// - While [SessionService] is checking for a persisted Firebase login, a
///   loading spinner is displayed instead of flashing a protected screen.
/// - Whenever no user is logged in, navigating to or remaining on any
///   non-public screen immediately redirects to [LoginPage] and clears the
///   navigation stack.
/// - When a user logs in (or signs up), they are automatically redirected
///   from the auth screens to [home].
class TigerDenApp extends StatefulWidget {
  const TigerDenApp({
    super.key,
    required this.home,
    this.initialPublicPage,
    this.initialPublicRouteName,
    this.debugShowCheckedModeBanner = false,
    this.sessionService,
  });

  /// The page shown once a user is logged in.
  final Widget home;

  /// Optional public auth screen (e.g. ForgotPasswordPage) to show on launch
  /// when logged out instead of [LoginPage].
  final Widget? initialPublicPage;

  /// Route name for [initialPublicPage]. Must be in [AuthRoutes.publicRoutes].
  final String? initialPublicRouteName;

  final bool debugShowCheckedModeBanner;

  /// Optional [SessionService] override for testing.
  final SessionService? sessionService;

  @override
  State<TigerDenApp> createState() => _TigerDenAppState();
}

class _TigerDenAppState extends State<TigerDenApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final SessionService _session;
  late final AuthRedirectObserver _observer;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionService ?? SessionService.instance;
    _observer = AuthRedirectObserver(onRouteChanged: _scheduleAuthCheck);
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    _scheduleAuthCheck();
  }

  void _scheduleAuthCheck() {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectScheduled = false;
      if (!mounted) return;
      _enforceAuthState();
    });
  }

  void _enforceAuthState() {
    if (!_session.isReady) return;
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final String? currentRoute = _observer.currentPageRouteName;

    if (!_session.isLoggedIn) {
      if (currentRoute == AuthRoutes.loading &&
          widget.initialPublicPage != null) {
        navigator.pushAndRemoveUntil<void>(
          _buildInitialPublicRoute(),
          (Route<dynamic> route) => false,
        );
      } else if (!AuthRoutes.isPublic(currentRoute)) {
        navigator.pushAndRemoveUntil<void>(
          _buildLoginRoute(),
          (Route<dynamic> route) => false,
        );
      }
    } else if (currentRoute == AuthRoutes.loading ||
        AuthRoutes.isPublic(currentRoute)) {
      navigator.pushAndRemoveUntil<void>(
        _buildAuthenticatedRoute(),
        (Route<dynamic> route) => false,
      );
    }
  }

  Route<void> _buildLoadingRoute() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AuthRoutes.loading),
      builder: (BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Route<void> _buildLoginRoute() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AuthRoutes.login),
      builder: (BuildContext context) => const LoginPage(),
    );
  }

  Route<void> _buildInitialPublicRoute() {
    return MaterialPageRoute<void>(
      settings: RouteSettings(
        name: widget.initialPublicRouteName ?? AuthRoutes.login,
      ),
      builder: (BuildContext context) =>
          widget.initialPublicPage ?? const LoginPage(),
    );
  }

  Route<void> _buildAuthenticatedRoute() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AuthRoutes.appHome),
      builder: (BuildContext context) => widget.home,
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    if (!_session.isReady) {
      return _buildLoadingRoute();
    }
    if (!_session.isLoggedIn) {
      return widget.initialPublicPage != null
          ? _buildInitialPublicRoute()
          : _buildLoginRoute();
    }
    return _buildAuthenticatedRoute();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: <NavigatorObserver>[_observer],
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
      builder: (BuildContext context, Widget? child) => Theme(
        data: context.style.theme,
        child: child!,
      ),
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

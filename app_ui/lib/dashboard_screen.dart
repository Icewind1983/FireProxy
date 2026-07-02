part of 'main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final BackendClient backend = const BackendClient();
  late final BackendRuntime backendRuntime;
  Timer? pollTimer;
  bool isRefreshing = false;

  ConnectionStateValue connection = ConnectionStateValue.disconnected;
  RoutingMode routingMode = RoutingMode.global;
  RulesProfile rulesProfile = RulesProfile.global;
  DnsMode dnsMode = DnsMode.auto;
  bool systemProxyEnabled = true;
  bool tunEnabled = false;
  bool launchAtStartup = true;
  bool autoCheckUpdates = false;
  AppLanguage appLanguage = AppLanguage.ru;
  ProfilesWorkspaceMode profilesWorkspaceMode = ProfilesWorkspaceMode.add;
  AppPage selectedPage = AppPage.home;
  bool isLoading = true;
  bool isBusy = false;
  bool isConnecting = false;
  bool isElevationInProgress = false;
  bool isSwitchingTunnelMode = false;
  String? errorMessage;
  RuntimeSnapshot runtimeStatus = RuntimeSnapshot.empty;

  late final TextEditingController proxyController;
  late final TextEditingController directController;
  late final TextEditingController blockedController;
  late final TextEditingController searchController;
  late final TextEditingController ruleTestController;
  late final TextEditingController vpnSearchController;
  late final TextEditingController directSearchController;
  late final TextEditingController blockedSearchController;

  List<String> proxyDomains = const [];
  List<String> directDomains = const [];
  List<String> blockedDomains = const [];
  List<ServerProfile> profiles = const [];
  final Set<String> disabledVpnRules = <String>{};
  final Set<String> disabledDirectRules = <String>{};
  final Set<String> disabledBlockedRules = <String>{};

  String activeProfileId = '';
  String? vpnInputError;
  String? directInputError;
  String? blockedInputError;
  
  Future<void> _minimizeToTray() async {
  	try {
      await windowManager.hide();
  	} catch (e) {
      print('Ошибка при сворачивании: $e');
  	}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    backendRuntime = BackendRuntime(backend);
    proxyController = TextEditingController();
    directController = TextEditingController();
    blockedController = TextEditingController();
    searchController = TextEditingController();
    ruleTestController = TextEditingController();
    vpnSearchController = TextEditingController();
    directSearchController = TextEditingController();
    blockedSearchController = TextEditingController();
    _bootstrap();
    pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isElevationInProgress) {
        return;
      }
      _refreshState(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(backendRuntime.dispose());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pollTimer?.cancel();
    unawaited(backendRuntime.dispose());
    proxyController.dispose();
    directController.dispose();
    blockedController.dispose();
    searchController.dispose();
    ruleTestController.dispose();
    vpnSearchController.dispose();
    directSearchController.dispose();
    blockedSearchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await backendRuntime.ensureRunning();
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = error.toString();
        });
      }
      return;
    }
    await _refreshState();
  }

  bool get hasActiveProfile =>
      profiles.any((profile) => profile.id == activeProfileId);

  TunnelMode get tunnelMode => tunEnabled ? TunnelMode.vpn : TunnelMode.proxy;

  ServerProfile get activeProfile => profiles.firstWhere(
        (profile) => profile.id == activeProfileId,
        orElse: () => const ServerProfile(
          id: 'none',
          name: 'Profile not selected',
          latencyMs: 0,
          health: ProfileHealth.offline,
          protocol: '-',
        ),
      );

  List<ServerProfile> get filteredProfiles {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return profiles;
    }

    return profiles
        .where(
          (profile) =>
              profile.name.toLowerCase().contains(query) ||
              profile.protocol.toLowerCase().contains(query) ||
              profile.address.toLowerCase().contains(query) ||
              profile.sni.toLowerCase().contains(query) ||
              profile.host.toLowerCase().contains(query) ||
              profile.transport.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    _activeLanguage = appLanguage;
    final isDesktopWide = MediaQuery.of(context).size.width >= 1100;
    final content = _buildBody(isDesktopWide);
    Widget blurOrb(double size, Color color) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 56, sigmaY: 56),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.06, -0.25),
            radius: 1.45,
            colors: [
              AppPalette.homeBgTop,
              AppPalette.homeBgMid,
              AppPalette.homeBgBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Positioned(
                  top: -34,
                  left: -40,
                  child: blurOrb(
                    280,
                    const Color(0x335A74F5),
                  ),
                ),
                Positioned(
                  top: 200,
                  right: -70,
                  child: blurOrb(
                    340,
                    const Color(0x20495BB3),
                  ),
                ),
                Positioned(
                  bottom: 46,
                  left: MediaQuery.of(context).size.width * 0.28,
                  child: blurOrb(
                    220,
                    const Color(0x22333F88),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _WorldMapBackdropPainter(),
                    ),
                  ),
                ),
                content,
                if (isBusy)
                  Positioned(
                    top: 22,
                    right: 22,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11172F).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            AppShadows.darkCard,
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              tr('Applying...'),
                              style: TextStyle(
                                color: AppPalette.homeText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDesktopWide) {
    if (isLoading && profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && profiles.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            color: Colors.white.withValues(alpha: 0.86),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    tr('Backend unavailable'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.black.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _refreshState,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(tr('Retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return isDesktopWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: _Sidebar(
                  language: appLanguage,
                  connection: connection,
                  isConnecting: isConnecting,
                  routingMode: routingMode,
                  dnsMode: dnsMode,
                  latencyMs: runtimeStatus.latencyMs,
                  externalIp: runtimeStatus.publicIp,
                  downloadBps: runtimeStatus.downloadBps,
                  uploadBps: runtimeStatus.uploadBps,
                  hasActiveProfile: hasActiveProfile,
                  activeProfileName: hasActiveProfile ? activeProfile.name : '',
                  selectedPage: selectedPage,
                  onLanguageChanged: (language) {
                    setState(() {
                      appLanguage = language;
                    });
                  },
                  onSelect: (page) {
                    setState(() {
                      selectedPage = page;
                    });
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: _buildContent()),
            ],
          )
        : _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(child: _buildContent()),
        const SizedBox(height: 12),
        NavigationBar(
          selectedIndex: selectedPage.index,
          onDestinationSelected: (index) {
            setState(() {
              selectedPage = AppPage.values[index];
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              label: loc(appLanguage, 'Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.rule_folder_outlined),
              label: loc(appLanguage, 'Rules'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.dns_outlined),
              label: loc(appLanguage, 'Profiles'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              label: loc(appLanguage, 'Logs'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _refreshState({bool silent = false}) async {
    if (isRefreshing || isBusy || isElevationInProgress) {
      return;
    }

    isRefreshing = true;
    if (!silent) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final ready = await _ensureBackendReady(silent: silent);
      if (!ready) {
        return;
      }
      final snapshot = await backend.getState();
      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
        if (!silent) {
          isLoading = false;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (!silent) {
        setState(() {
          isLoading = false;
          errorMessage = error.toString();
        });
      }
    } finally {
      isRefreshing = false;
    }
  }

  Future<bool> _ensureBackendReady({bool silent = false}) async {
    if (isElevationInProgress) {
      return false;
    }
    try {
      await backendRuntime.ensureRunning();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (!silent) {
        setState(() {
          isLoading = false;
          errorMessage = error.toString();
        });
        _showMessage(error.toString(), isError: true);
      }
      return false;
    }
  }

  Future<void> _saveConfig(
    AppConfigState config, {
    bool preserveConnection = true,
  }) async {
    final wasConnectedBeforeChange =
        connection == ConnectionStateValue.connected;
    setState(() {
      isBusy = true;
      errorMessage = null;
    });

    try {
      final ready = await _ensureBackendReady();
      if (!ready) {
        return;
      }
      final snapshot = await backend.updateState(config);
      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
      });

      if (preserveConnection && wasConnectedBeforeChange) {
        if (connection == ConnectionStateValue.connected &&
            !runtimeStatus.ready) {
          setState(() {
            isConnecting = true;
          });
        } else if (connection == ConnectionStateValue.disconnected) {
          final assetsBusy =
              snapshot.runtime.routingAssetsStatus == 'downloading';
          final assetsFailed =
              snapshot.runtime.routingAssetsStatus == 'error' &&
                  snapshot.runtime.russiaRoutingAssetsUpdatedAt.isEmpty;
          if (assetsBusy || assetsFailed) {
            _showMessage(
              assetsBusy
                  ? tr('Waiting for routing rules download before reconnecting.')
                  : tr('Routing rules download failed. Retry and reconnect.'),
              isError: assetsFailed,
            );
          } else {
            setState(() {
              isConnecting = true;
            });
            await _restoreConnectionAfterConfigChange();
          }
        }
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      _showMessage(
        tr('Backend did not respond in time. The change may still apply shortly.'),
        isError: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
          if (connection != ConnectionStateValue.connected) {
            isConnecting = false;
          }
        });
      }
    }
  }

  Future<void> _restoreConnectionAfterConfigChange() async {
    if (!mounted || !hasActiveProfile) {
      return;
    }
    try {
      final reconnect = await backend.connect();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySnapshot(reconnect);
      });
      if (reconnect.config.connectionState == ConnectionStateValue.connected) {
        _showMessage(tr('Connection restored after applying changes.'));
      } else {
        _showMessage(
          tr('Reconnection is pending. Complete rule download, then retry.'),
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(
        tr('Reconnection failed after applying changes. Tap Connect to retry.'),
        isError: true,
      );
    }
  }

  Future<void> _showNoProfileAlert() async {
    final goToProfiles = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('No profile configured'),
              style: TextStyle(
                color: AppPalette.homeText.withValues(alpha: 0.96),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Import or create a VPN profile to connect.'),
              style: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogSecondaryButton(
                  label: tr('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 10),
                _DialogPrimaryButton(
                  label: tr('Add profile'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (goToProfiles == true && mounted) {
      setState(() {
        selectedPage = AppPage.profiles;
      });
    }
  }

  Future<void> _toggleConnection() async {
    if (connection == ConnectionStateValue.disconnected && !hasActiveProfile) {
      await _showNoProfileAlert();
      return;
    }

    if (connection == ConnectionStateValue.disconnected &&
        tunnelMode == TunnelMode.vpn) {
      final elevated = await _ensureAdminForTun();
      if (!elevated) {
        return;
      }
    }

    setState(() {
      isBusy = true;
      isConnecting = connection == ConnectionStateValue.disconnected;
      errorMessage = null;
    });

    try {
      final ready = await _ensureBackendReady();
      if (!ready) {
        return;
      }

      if (connection == ConnectionStateValue.disconnected &&
          rulesProfile == RulesProfile.russia) {
        var snap = await backend.getState();
        if (!mounted) {
          return;
        }
        setState(() {
          _applySnapshot(snap);
        });
        if (!_russiaRulesDataReady(snap.runtime)) {
          final ok = await _showRussiaRulesFirstDownloadDialog(
            cancelRevertsProfileToGlobal: false,
          );
          if (!ok || !mounted) {
            return;
          }
          snap = await backend.getState();
          if (!mounted) {
            return;
          }
          setState(() {
            _applySnapshot(snap);
          });
          if (!_russiaRulesDataReady(snap.runtime)) {
            _showMessage(
              loc(appLanguage, 'Could not download routing rules.'),
              isError: true,
            );
            return;
          }
        }
      }

      final snapshot = connection == ConnectionStateValue.connected
          ? await backend.disconnect()
          : await backend.connect();
      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      _showMessage(
        tr('Connection is taking too long. Check Logs. If Xray starts, the status will update automatically.'),
        isError: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
          if (connection == ConnectionStateValue.disconnected) {
            isConnecting = false;
          }
        });
      }
    }
  }

  Future<void> _switchTunnelMode(TunnelMode mode) async {
    if (mode == tunnelMode || isSwitchingTunnelMode || isBusy) {
      return;
    }

    final wasConnected = connection == ConnectionStateValue.connected;

    setState(() {
      isSwitchingTunnelMode = true;
    });

    try {
      if (mode == TunnelMode.vpn) {
        if (wasConnected) {
          final elevated = await _ensureAdminForTun();
          if (!elevated) {
            return;
          }
        }
        await _saveConfig(
          _currentConfig().copyWith(
            tunEnabled: true,
            systemProxyEnabled: false,
          ),
        );
      } else {
        await _saveConfig(
          _currentConfig().copyWith(
            tunEnabled: false,
            systemProxyEnabled: true,
          ),
        );
      }

      if (!mounted) {
        return;
      }
      if (wasConnected &&
          connection == ConnectionStateValue.disconnected) {
        await _reconnectAfterTunnelModeChange();
      }
    } finally {
      if (mounted) {
        setState(() {
          isSwitchingTunnelMode = false;
        });
      }
    }
  }

  Future<void> _reconnectAfterTunnelModeChange() async {
    setState(() {
      isBusy = true;
      isConnecting = true;
      errorMessage = null;
    });
    try {
      final ready = await _ensureBackendReady();
      if (!ready) {
        return;
      }
      final snapshot = await backend.connect();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySnapshot(snapshot);
      });
    } on TimeoutException {
      if (mounted) {
        _showMessage(
          tr('Connection is taking too long. Check Logs. If Xray starts, the status will update automatically.'),
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
          if (connection == ConnectionStateValue.disconnected) {
            isConnecting = false;
          }
        });
      }
    }
  }

  Future<bool> _ensureAdminForTun() async {
    final ready = await _ensureBackendReady();
    if (!ready) {
      return false;
    }

    final elevated = runtimeStatus.elevated || await backend.getAdminStatus();
    if (elevated) {
      return true;
    }

    if (Platform.isLinux) {
      final password = await _showLinuxSudoDialog();
      if (password == null || password.isEmpty) {
        return false;
      }

      try {
        await backend.requestAdmin(password);
        final snapshot = await backend.getState();
        if (!mounted) {
          return false;
        }
        setState(() {
          _applySnapshot(snapshot);
          errorMessage = null;
        });
        return true;
      } catch (error) {
        if (mounted) {
          _showMessage(error.toString(), isError: true);
        }
        return false;
      }
    }

    try {
      if (mounted) {
        setState(() {
          isElevationInProgress = true;
        });
      }
      await backend.requestAdmin();
    } catch (error) {
      final message = error.toString().toLowerCase();
      final reconnectExpected = message.contains('socket') ||
          message.contains('connection') ||
          message.contains('connection reset');
      if (!reconnectExpected) {
        if (mounted) {
          setState(() {
            isElevationInProgress = false;
          });
          _showMessage(error.toString(), isError: true);
        }
        return false;
      }
    }

    if (mounted) {
      _showMessage(tr(
          'Approve the administrator prompt. Waiting for elevated backend...'));
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final snapshot = await backend.getState();
        if (snapshot.runtime.elevated) {
          if (mounted) {
            setState(() {
              isElevationInProgress = false;
              _applySnapshot(snapshot);
              errorMessage = null;
            });
          }
          return true;
        }
      } catch (_) {
        // Ignore short reconnect gaps while the backend restarts elevated.
      }
    }

    if (mounted) {
      setState(() {
        isElevationInProgress = false;
      });
      _showMessage(tr('Failed to reconnect to an elevated backend.'),
          isError: true);
    }
    return false;
  }

  Future<String?> _showLinuxSudoDialog() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _LinuxSudoDialog(controller: controller);
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _applySnapshot(DashboardSnapshot snapshot) {
    final config = snapshot.config;
    connection = config.connectionState;
    routingMode = config.routingMode;
    rulesProfile = config.rulesProfile;
    dnsMode = config.dnsMode;
    systemProxyEnabled = config.systemProxyEnabled;
    tunEnabled = config.tunEnabled;
    launchAtStartup = config.launchAtStartup;
    proxyDomains = List<String>.from(config.proxyDomains);
    directDomains = List<String>.from(config.directDomains);
    blockedDomains = List<String>.from(config.blockedDomains);
    disabledVpnRules
      ..clear()
      ..addAll(config.disabledProxyDomains
          .where((item) => proxyDomains.contains(item)));
    disabledDirectRules
      ..clear()
      ..addAll(config.disabledDirectDomains
          .where((item) => directDomains.contains(item)));
    disabledBlockedRules
      ..clear()
      ..addAll(config.disabledBlockedDomains
          .where((item) => blockedDomains.contains(item)));
    profiles = List<ServerProfile>.from(config.profiles);
    activeProfileId = config.activeProfileId;
    runtimeStatus = snapshot.runtime;
    if (connection != ConnectionStateValue.connected) {
      isConnecting = false;
    } else {
      isConnecting = !runtimeStatus.ready;
    }
  }

  AppConfigState _currentConfig() {
    return AppConfigState(
      activeProfileId: activeProfileId,
      connectionState: connection,
      routingMode: routingMode,
      rulesProfile: rulesProfile,
      dnsMode: dnsMode,
      systemProxyEnabled: systemProxyEnabled,
      tunEnabled: tunEnabled,
      launchAtStartup: launchAtStartup,
      proxyDomains: List<String>.from(proxyDomains),
      directDomains: List<String>.from(directDomains),
      blockedDomains: List<String>.from(blockedDomains),
      disabledProxyDomains: disabledVpnRules.toList(),
      disabledDirectDomains: disabledDirectRules.toList(),
      disabledBlockedDomains: disabledBlockedRules.toList(),
      profiles: List<ServerProfile>.from(profiles),
    );
  }

  Future<void> _showLogsDialog() async {
    // Show a live-updating logs dialog that polls backend.getState()
    await showDialog<void>(
      context: context,
      builder: (context) => _LogsDialog(
        backend: backend,
        initialRuntime: runtimeStatus,
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFF8B3A3A) : null,
        content: Text(message),
      ),
    );
  }

  Widget _buildContent() {
    switch (selectedPage) {
      case AppPage.home:
        return _buildHomeView();
      case AppPage.rules:
        return _buildRulesView();
      case AppPage.profiles:
        return _buildProfilesView();
      case AppPage.settings:
        return _buildLogsView();
    }
  }

  Widget _buildHomeView() {
    final canConnect = hasActiveProfile;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth =
            constraints.maxWidth >= 1300 ? 980.0 : constraints.maxWidth;
        final horizontalPadding = constraints.maxWidth >= 900 ? 16.0 : 6.0;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MainConnectionCard(
                      profileName: hasActiveProfile
                          ? activeProfile.name
                          : loc(appLanguage, 'Select VPN Server'),
                      connection: connection,
                      isConnecting: isConnecting,
                      canConnect: canConnect,
                      isBusy: isBusy,
                      onToggleConnection: _toggleConnection,
                      profileItems: profiles,
                      selectedProfileId: hasActiveProfile
                          ? activeProfileId
                          : (profiles.isNotEmpty ? profiles.first.id : null),
                      onProfileChanged: (profileId) async {
                        if (profileId == null) {
                          return;
                        }
                        await _saveConfig(_currentConfig()
                            .copyWith(activeProfileId: profileId));
                      },
                      tunnelMode: tunnelMode,
                      onTunnelModeChanged: _switchTunnelMode,
                      onNoProfiles: _showNoProfileAlert,
                    ),
                    if (!canConnect) ...[
                      const SizedBox(height: 16),
                      _HintCard(
                        title: loc(appLanguage, 'No profile selected'),
                        description: loc(
                          appLanguage,
                          'Open Profiles, import or create a profile, then select it on this screen.',
                        ),
                        icon: Icons.info_outline_rounded,
                        actionLabel: tr('Add'),
                        onAction: () {
                          setState(() {
                            selectedPage = AppPage.profiles;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ... rest of the file unchanged ...

import 'package:material_ui/material_ui.dart';

import 'voter_db.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'admin/admin_dashboard.dart';
const Color kTdpYellow = Color(0xFFFFD600);
const Color kTdpYellowDark = Color(0xFFEAB308);
const Color kTdpYellowDeep = Color(0xFFFBC02D);
const Color kTdpYellowSoftBg = Color(0xFFFFFBEB);
const Color kTdpDarkInk = Color(0xFF111827);

/// Global language notifier: true = English, false = Telugu
final ValueNotifier<bool> isEnglishNotifier = ValueNotifier<bool>(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const VoterSearchApp());
}
class VoterSearchApp extends StatelessWidget {
  const VoterSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEnglishNotifier,
      builder: (context, isEn, _) {
        return MaterialApp(
          title: isEn ? 'TDP Voter Search' : 'టీడీపీ ఓటరు పరిశోధించుట',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: kTdpYellowSoftBg,
            colorScheme: ColorScheme.fromSeed(
              seedColor: kTdpYellow,
              primary: kTdpYellow,
              onPrimary: kTdpDarkInk,
              secondary: kTdpYellowDark,
              onSecondary: kTdpDarkInk,
              surface: const Color(0xFFFFFDF0),
              onSurface: kTdpDarkInk,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: kTdpYellow,
              foregroundColor: kTdpDarkInk,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: kTdpYellow,
                foregroundColor: kTdpDarkInk,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}

/// Reusable EN | తెలుగు toggle pill for AppBars and Home header
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEnglishNotifier,
      builder: (context, isEn, _) {
        return Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: kTdpDarkInk.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: kTdpDarkInk.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segment('EN', true, isEn),
              _segment('తెలుగు', false, !isEn),
            ],
          ),
        );
      },
    );
  }

  Widget _segment(String text, bool targetIsEn, bool active) {
    return GestureDetector(
      onTap: () => isEnglishNotifier.value = targetIsEn,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? kTdpDarkInk : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? kTdpYellow : kTdpDarkInk,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 1: HOME SCREEN
// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DocumentInfo> _documents = [];
  String? _selectedPdf;
  bool _loadingDocs = true;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    try {
      final docs = await VoterDatabase.instance.getDocuments();
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _loadingDocs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDocs = false);
    }
  }

  String _activeRollLabel(bool isEn) {
    if (_selectedPdf == null) {
      final total = _documents.fold(0, (s, d) => s + d.totalVoters);
      if (_documents.isEmpty) {
        return isEn ? 'All Electoral Rolls' : 'అన్ని ఓటరు జాబితాలు';
      }
      return isEn
          ? 'All Wards (${_documents.length} Roll • $total Voters)'
          : 'అన్ని వార్డులు (${_documents.length} జాబితా • $total ఓటర్లు)';
    }
    final match = _documents.where((d) => d.sourcePdf == _selectedPdf);
    if (match.isNotEmpty) {
      final d = match.first;
      return isEn
          ? 'Ward ${d.wardNo} (${d.totalVoters} Voters)'
          : 'వార్డు ${d.wardNo} (${d.totalVoters} ఓటర్లు)';
    }
    return _selectedPdf!;
  }

  Widget _homeActionButton({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: kTdpDarkInk, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kTdpDarkInk,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: kTdpDarkInk),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEnglishNotifier,
      builder: (context, isEn, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFC400),
                  Color(0xFFFFD600),
                  Color(0xFFFFEA61),
                  Color(0xFFFFFBEB),
                ],
                stops: [0.0, 0.36, 0.72, 1.0],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: LanguageToggleButton(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: kTdpDarkInk, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.how_to_vote_rounded,
                        size: 40,
                        color: kTdpDarkInk,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isEn
                          ? 'TDP Voter Roll\nSearch'
                          : 'టీడీపీ ఓటరు\nపరిశోధించుట',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.bold,
                        color: kTdpDarkInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEn
                          ? 'Find Voter Information Easily'
                          : 'ఓటరు సమాచారం సులభంగా తెలుసుకోండి',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _homeActionButton(
                      icon: Icons.search_rounded,
                      label: isEn ? 'Search by Name' : 'పేరుతో వెతకండి',
                      subtitle: isEn
                          ? 'Search in English or Telugu'
                          : 'ఓటరు పేరు ద్వారా వెతకండి',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(
                              initialMode: 'name',
                              selectedPdf: _selectedPdf,
                              documents: _documents,
                            ),
                          ),
                        );
                      },
                    ),
                    _homeActionButton(
                      icon: Icons.badge_outlined,
                      label: isEn ? 'Search by EPIC ID' : 'ఓటరు ఐడితో వెతకండి',
                      subtitle: isEn
                          ? 'Search by Voter ID number'
                          : 'EPIC నంబర్ ద్వారా వెతకండి',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(
                              initialMode: 'epic',
                              selectedPdf: _selectedPdf,
                              documents: _documents,
                            ),
                          ),
                        );
                      },
                    ),
                    _homeActionButton(
                      icon: Icons.format_list_numbered_rounded,
                      label: isEn
                          ? 'Search by Serial Number'
                          : 'వరుస సంఖ్యతో వెతకండి',
                      subtitle: isEn
                          ? 'Search by roll serial number'
                          : 'ఓటరు వరుస సంఖ్య ద్వారా వెతకండి',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(
                              initialMode: 'serial',
                              selectedPdf: _selectedPdf,
                              documents: _documents,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.black38)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            isEn ? 'Other Options' : 'ఇతర ఎంపికలు',
                            style: const TextStyle(
                              color: kTdpDarkInk,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Colors.black38)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _homeActionButton(
                      icon: Icons.list_alt_rounded,
                      label: isEn
                          ? 'Select Electoral Roll'
                          : 'ఓటరు జాబితా ఎంచుకోండి',
                      subtitle: _loadingDocs
                          ? (isEn ? 'Loading...' : 'లోడ్ అవుతోంది...')
                          : _activeRollLabel(isEn),
                      onTap: () async {
                        final result = await Navigator.push<String?>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SelectRollScreen(
                              documents: _documents,
                              currentPdf: _selectedPdf,
                            ),
                          ),
                        );
                        if (result != null || _selectedPdf != null) {
                          setState(() {
                            _selectedPdf = (result == '__ALL__')
                                ? null
                                : result;
                          });
                        }
                      },
                    ),
                    _homeActionButton(
                      icon: Icons.info_outline_rounded,
                      label: isEn ? 'About' : 'యాప్ గురించి',
                      subtitle: isEn
                          ? 'App information & supported features'
                          : 'యాప్ సమాచారం మరియు ప్రత్యేకతలు',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                    FutureBuilder<AppMember?>(
                      future: AuthService.instance.getCurrentMember(
                        refreshClaims: true,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.data?.isAdmin != true) {
                          return const SizedBox.shrink();
                        }
                        return _homeActionButton(
                          icon: Icons.admin_panel_settings,
                          label: isEn
                              ? 'Administrator Dashboard'
                              : 'అడ్మినిస్ట్రేటర్ డాష్‌బోర్డ్',
                          subtitle: isEn
                              ? 'Manage members and access'
                              : 'సభ్యులను మరియు యాక్సెస్‌ను నిర్వహించండి',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminDashboard(),
                            ),
                          ),
                        );
                      },
                    ),
                    _homeActionButton(
                      icon: Icons.logout,
                      label: isEn ? 'Log out' : 'లాగ్ అవుట్',
                      onTap: () async {
                        await AuthService.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kTdpYellow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kTdpDarkInk, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/branding/tdp_logo.png',
                          height: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 90,
                            child: Center(
                              child: Text(
                                'TDP',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: kTdpDarkInk,
                                ),
                              ),
                            ),
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
      },
    );
  }
}

// ============================================================================
// SCREEN 2: SEARCH RESULTS SCREEN
// ============================================================================
class SearchScreen extends StatefulWidget {
  final String initialMode;
  final String? selectedPdf;
  final List<DocumentInfo> documents;

  const SearchScreen({
    super.key,
    required this.initialMode,
    required this.selectedPdf,
    required this.documents,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late String _searchMode;
  List<VoterRecord> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchMode = widget.initialMode;
    _runSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() => _loading = true);
    try {
      final voters = await VoterDatabase.instance.searchVoters(
        query: _searchController.text,
        mode: _searchMode,
        sourcePdf: widget.selectedPdf,
      );
      if (!mounted) return;
      setState(() {
        _results = voters;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _hintText(bool isEn) {
    switch (_searchMode) {
      case 'epic':
        return isEn
            ? 'Enter EPIC ID (e.g. WWV0920851)'
            : 'EPIC ఐడి నమోదు చేయండి (ఉదా. WWV0920851)';
      case 'serial':
        return isEn
            ? 'Enter Serial Number (e.g. 25)'
            : 'వరుస సంఖ్య నమోదు చేయండి (ఉదా. 25)';
      case 'name':
        return isEn
            ? 'Enter name in English (e.g. Satyavati)'
            : 'తెలుగు పేరు నమోదు చేయండి (ఉదా. సత్యవతి)';
      default:
        return isEn
            ? 'Search name, EPIC ID, or Serial No...'
            : 'పేరు, EPIC ఐడి లేదా వరుస సంఖ్య...';
    }
  }

  String _selectedWardLabel(bool isEn) {
    if (widget.selectedPdf == null) return '';
    final match = widget.documents.where(
      (d) => d.sourcePdf == widget.selectedPdf,
    );
    if (match.isNotEmpty) {
      return isEn
          ? 'Ward ${match.first.wardNo}'
          : 'వార్డు ${match.first.wardNo}';
    }
    return widget.selectedPdf!;
  }

  String _relationShort(String rawType, bool isEn) {
    if (!isEn) {
      return rawType.isNotEmpty ? rawType : 'సంబంధం';
    }
    switch (rawType.trim()) {
      case 'తండ్రి పేరు':
        return "Father";
      case 'భర్త పేరు':
        return "Husband";
      case 'తల్లి పేరు':
        return "Mother";
      case 'ఇతర':
        return "Other";
      default:
        return "Relative";
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEnglishNotifier,
      builder: (context, isEn, _) {
        final wardLabel = _selectedWardLabel(isEn);
        return Scaffold(
          appBar: AppBar(
            title: Text(isEn ? 'Search Results' : 'పరిశోధించుట ఫలితాలు'),
            actions: const [LanguageToggleButton()],
          ),
          body: Column(
            children: [
              Container(
                color: kTdpYellow,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (_) => _runSearch(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: _hintText(isEn),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: kTdpDarkInk,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: kTdpDarkInk,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _runSearch();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _modePill(isEn ? 'All' : 'అన్నీ', 'all'),
                          const SizedBox(width: 8),
                          _modePill(isEn ? 'By Name' : 'పేరుతో', 'name'),
                          const SizedBox(width: 8),
                          _modePill(isEn ? 'By EPIC ID' : 'EPIC ఐడి', 'epic'),
                          const SizedBox(width: 8),
                          _modePill(isEn ? 'By S.No' : 'వరుస సంఖ్య', 'serial'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEn
                          ? 'Found ${_results.length} matches'
                          : '${_results.length} ఫలితాలు లభించాయి',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: kTdpDarkInk,
                      ),
                    ),
                    if (wardLabel.isNotEmpty)
                      Text(
                        wardLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kTdpDarkInk,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: kTdpDarkInk),
                      )
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Error: $_error'),
                        ),
                      )
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          isEn
                              ? 'No matching voters found.'
                              : 'సరిపోయే ఓటర్లు కనుగొనబడలేదు.',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final voter = _results[index];
                          final displayName = isEn
                              ? (voter.voterNameEn.isNotEmpty
                                    ? voter.voterNameEn
                                    : voter.voterName)
                              : voter.voterName;
                          final displayRelName = isEn
                              ? (voter.relativeNameEn.isNotEmpty
                                    ? voter.relativeNameEn
                                    : voter.relativeName)
                              : voter.relativeName;

                          return Card(
                            color: Colors.white,
                            elevation: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              leading: _VoterAvatar(
                                photoPath: voter.photoPath,
                                radius: 24,
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: kTdpDarkInk,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EPIC: ${voter.epicId} • ${isEn ? 'S.No' : 'వ.సంఖ్య'}: ${voter.serialNo}',
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (displayRelName.isNotEmpty)
                                      Text(
                                        '${_relationShort(voter.relationshipType, isEn)}: $displayRelName',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: kTdpDarkInk,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        VoterDetailScreen(voter: voter),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modePill(String label, String mode) {
    final selected = _searchMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _searchMode = mode);
        _runSearch();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kTdpDarkInk : kTdpYellowDeep,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kTdpDarkInk : Colors.black26,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? kTdpYellow : kTdpDarkInk,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _VoterAvatar extends StatelessWidget {
  final String? photoPath;
  final double radius;

  const _VoterAvatar({required this.photoPath, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (photoPath != null && photoPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/$photoPath',
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFFFF3B0),
            child: const Icon(Icons.person, color: kTdpDarkInk),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFF3B0),
      child: const Icon(Icons.person, color: kTdpDarkInk),
    );
  }
}

// ============================================================================
// SCREEN 3: VOTER DETAILS SCREEN
// ============================================================================
class VoterDetailScreen extends StatelessWidget {
  final VoterRecord voter;

  const VoterDetailScreen({super.key, required this.voter});

  String _relationLabel(String rawType, bool isEn) {
    if (!isEn) {
      return rawType.isNotEmpty ? rawType : 'సంబంధం (Unlabeled)';
    }
    switch (rawType.trim()) {
      case 'తండ్రి పేరు':
        return "Father's Name";
      case 'భర్త పేరు':
        return "Husband's Name";
      case 'తల్లి పేరు':
        return "Mother's Name";
      case 'ఇతర':
        return "Other Relative";
      default:
        return "Relative (Unlabeled)";
    }
  }

  Widget _detailRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
                fontSize: 14,
              ),
            ),
          ),
          const Text(':  ', style: TextStyle(color: Colors.black45)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: kTdpDarkInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEnglishNotifier,
      builder: (context, isEn, _) {
        final genderDisplay = voter.gender == 'M'
            ? (isEn ? 'Male' : 'పు (Male)')
            : voter.gender == 'F'
            ? (isEn ? 'Female' : 'స్త్రీ (Female)')
            : 'Unknown';

        final nameVal = isEn
            ? (voter.voterNameEn.isNotEmpty
                  ? voter.voterNameEn
                  : voter.voterName)
            : voter.voterName;
        final relVal = isEn
            ? (voter.relativeNameEn.isNotEmpty
                  ? voter.relativeNameEn
                  : voter.relativeName)
            : voter.relativeName;
        final gpVal = isEn
            ? (voter.gramPanchayatEn.isNotEmpty
                  ? voter.gramPanchayatEn
                  : voter.gramPanchayat)
            : voter.gramPanchayat;
        final mandalVal = isEn
            ? (voter.mandalEn.isNotEmpty ? voter.mandalEn : voter.mandal)
            : voter.mandal;
        final districtVal = isEn
            ? (voter.districtEn.isNotEmpty ? voter.districtEn : voter.district)
            : voter.district;

        return Scaffold(
          appBar: AppBar(
            title: Text(isEn ? 'Voter Details' : 'ఓటరు వివరాలు'),
            actions: const [LanguageToggleButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.white,
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      if (voter.photoPath != null &&
                          voter.photoPath!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/${voter.photoPath}',
                            width: 96,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3B0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 48,
                                color: kTdpDarkInk,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 96,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3B0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 48,
                            color: kTdpDarkInk,
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8CC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kTdpYellowDark, width: 1),
                          ),
                          child: Column(
                            children: [
                              Text(
                                isEn ? 'Voter ID (EPIC)' : 'ఓటరు ఐడి (EPIC)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                voter.epicId.isNotEmpty ? voter.epicId : 'N/A',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kTdpDarkInk,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (voter.needsVerification)
                Card(
                  color: Colors.amber.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade900),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Verification note: ${voter.verificationNotes}',
                            style: TextStyle(color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Card(
                color: Colors.white,
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow(
                        isEn ? 'Serial Number' : 'ఓటర్ సంఖ్య',
                        '${voter.serialNo}',
                      ),
                      _detailRow(isEn ? 'Voter Name' : 'ఓటర్ పేరు', nameVal),
                      _detailRow(
                        _relationLabel(voter.relationshipType, isEn),
                        relVal,
                      ),
                      _detailRow(
                        isEn ? 'Age' : 'వయస్సు',
                        voter.age != null ? '${voter.age}' : '',
                      ),
                      _detailRow(isEn ? 'Gender' : 'లింగం', genderDisplay),
                      _detailRow(
                        isEn ? 'House Number' : 'ఇంటి నంబర్',
                        voter.houseNo,
                      ),
                      const Divider(height: 22),
                      _detailRow(
                        isEn ? 'Assembly Ref' : 'అసెంబ్లీ రిఫరెన్స్',
                        voter.acSerialRef,
                      ),
                      _detailRow(
                        isEn ? 'Village / Ward' : 'గ్రామం / వార్డు',
                        gpVal.isNotEmpty
                            ? (isEn
                                  ? '$gpVal (Ward ${voter.wardNo})'
                                  : '$gpVal (వార్డు ${voter.wardNo})')
                            : '',
                      ),
                      _detailRow(isEn ? 'Mandal' : 'మండలం', mandalVal),
                      _detailRow(isEn ? 'District' : 'జిల్లా', districtVal),
                      _detailRow(
                        isEn ? 'Page Number' : 'పేజీ సంఖ్య',
                        voter.sourcePages,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTdpYellow,
                    foregroundColor: kTdpDarkInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search),
                  label: Text(
                    isEn ? 'Back to Search' : 'పరిశోధించుట తిరిగి వెళ్ళండి',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// SCREEN 4: SELECT ELECTORAL ROLL SCREEN
// ============================================================================
class SelectRollScreen extends StatefulWidget {
  final List<DocumentInfo> documents;
  final String? currentPdf;

  const SelectRollScreen({
    super.key,
    required this.documents,
    required this.currentPdf,
  });

  @override
  State<SelectRollScreen> createState() => _SelectRollScreenState();
}

class _SelectRollScreenState extends State<SelectRollScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentPdf;
  }

  int _wardNumber(DocumentInfo doc) {
    final digits =
        RegExp(r'\d+').firstMatch(doc.wardNo)?.group(0) ??
        RegExp(r'\d+').firstMatch(doc.sourcePdf)?.group(0);
    return int.tryParse(digits ?? '') ?? 9999;
  }

  @override
  Widget build(BuildContext context) {
    final sortedDocs = List<DocumentInfo>.from(widget.documents)
      ..sort((a, b) => _wardNumber(a).compareTo(_wardNumber(b)));

    return ValueListenableBuilder<bool>(
      valueListenable: isEnglishNotifier,
      builder: (context, isEn, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              isEn ? 'Select Electoral Roll' : 'ఓటరు జాబితా ఎంచుకోండి',
            ),
            actions: const [LanguageToggleButton()],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: const Icon(Icons.layers, color: kTdpDarkInk),
                        title: Text(
                          isEn ? 'All Wards' : 'అన్ని వార్డులు',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          isEn
                              ? '${sortedDocs.length} Roll(s) loaded'
                              : '${sortedDocs.length} జాబితా(లు) అందుబాటులో ఉన్నాయి',
                        ),
                        trailing: _selected == null
                            ? const Icon(
                                Icons.check_circle,
                                color: kTdpYellowDark,
                              )
                            : null,
                        onTap: () => setState(() => _selected = null),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...sortedDocs.map((doc) {
                      final isSelected = _selected == doc.sourcePdf;
                      final gpName = isEn
                          ? (doc.gramPanchayatEn.isNotEmpty
                                ? doc.gramPanchayatEn
                                : doc.gramPanchayat)
                          : doc.gramPanchayat;
                      return Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(
                            Icons.description_outlined,
                            color: kTdpDarkInk,
                          ),
                          title: Text(
                            isEn
                                ? 'Ward ${doc.wardNo}'
                                : 'వార్డు ${doc.wardNo}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isEn
                                ? '$gpName • ${doc.totalVoters} Voters'
                                : '$gpName • ${doc.totalVoters} ఓటర్లు',
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: kTdpYellowDark,
                                )
                              : null,
                          onTap: () =>
                              setState(() => _selected = doc.sourcePdf),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTdpYellow,
                      foregroundColor: kTdpDarkInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, _selected ?? '__ALL__');
                    },
                    child: Text(
                      isEn ? 'Apply' : 'వర్తించు',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// SCREEN 5: ABOUT SCREEN
// ============================================================================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget _featureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEnglishNotifier,
      builder: (context, isEn, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isEn ? 'About' : 'యాప్ గురించి'),
            actions: const [LanguageToggleButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: kTdpYellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: kTdpDarkInk, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.how_to_vote_rounded,
                    size: 46,
                    color: kTdpDarkInk,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEn ? 'TDP Voter Roll Search' : 'టీడీపీ ఓటరు పరిశోధించుట',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Version 1.0',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              Text(
                isEn
                    ? 'A fast, offline Android application to search and verify voter information from electoral roll PDF documents in both English and Telugu.'
                    : 'ఓటరు జాబితా PDF పత్రాల నుండి ఇంగ్లీష్ మరియు తెలుగు భాషలలో ఓటరు వివరాలను వేగంగా, ఆఫ్‌లైన్‌లో వెతకడానికి రూపొందించిన ఆండ్రాయిడ్ యాప్.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                isEn ? 'Features:' : 'ప్రత్యేకతలు:',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _featureItem(
                isEn
                    ? 'Instant English & Telugu Language Toggle'
                    : 'ఇంగ్లీష్ మరియు తెలుగు భాషల మార్పిడి',
              ),
              _featureItem(
                isEn
                    ? 'Search by Name, EPIC ID, or Serial Number'
                    : 'పేరు, EPIC ఐడి లేదా వరుస సంఖ్యతో పరిశోధించుట',
              ),
              _featureItem(
                isEn
                    ? 'View Complete Voter Details & Photos'
                    : 'పూర్తి ఓటరు వివరాలు మరియు ఫోటోల వీక్షణ',
              ),
              _featureItem(
                isEn
                    ? 'Support Multiple Electoral Roll Wards'
                    : 'బహుళ వార్డుల ఓటరు జాబితాల మద్దతు',
              ),
              const SizedBox(height: 36),
              const Text(
                'Built with Flutter & SQLite',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}

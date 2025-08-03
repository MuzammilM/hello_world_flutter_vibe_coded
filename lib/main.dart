import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: Consumer<MyAppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Namer App',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepOrange,
                brightness: Brightness.dark,
              ),
              brightness: Brightness.dark,
            ),
            themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: MyHomePage(),
          );
        },
      ),
    );
  }
}

// ...

class MyAppState extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  var current = WordPair.random();
  var history = <WordPair>[];
  var favorites = <WordPair>[];
  var isDarkMode = false;
  var isLoading = false;
  User? user;

  MyAppState() {
    _initializeAuth();
  }

  void _initializeAuth() {
    user = supabase.auth.currentUser;
    supabase.auth.onAuthStateChange.listen((data) {
      user = data.session?.user;
      if (user != null) {
        _loadFavorites();
      } else {
        favorites.clear();
      }
      notifyListeners();
    });

    if (user != null) {
      _loadFavorites();
    }
  }

  Future<void> signInAnonymously() async {
    try {
      isLoading = true;
      notifyListeners();

      await supabase.auth.signInAnonymously();
    } catch (error) {
      print('Error signing in: $error');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      await supabase.auth.signInWithPassword(email: email, password: password);
      return null; // Success
    } catch (error) {
      return error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      await supabase.auth.signUp(email: email, password: password);
      return null; // Success
    } catch (error) {
      return error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (error) {
      print('Error signing out: $error');
    }
  }

  Future<void> _loadFavorites() async {
    if (user == null) return;

    try {
      final response = await supabase
          .from('favorites')
          .select('word')
          .eq('user_id', user!.id);

      favorites = response
          .map<WordPair>(
            (item) => WordPair(
              item['word'].split('_')[0],
              item['word'].split('_')[1],
            ),
          )
          .toList();

      notifyListeners();
    } catch (error) {
      print('Error loading favorites: $error');
    }
  }

  Future<void> _saveFavorite(WordPair word) async {
    if (user == null) return;

    try {
      await supabase.from('favorites').insert({
        'user_id': user!.id,
        'word': '${word.first}_${word.second}',
      });
    } catch (error) {
      print('Error saving favorite: $error');
    }
  }

  Future<void> _removeFavorite(WordPair word) async {
    if (user == null) return;

    try {
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', user!.id)
          .eq('word', '${word.first}_${word.second}');
    } catch (error) {
      print('Error removing favorite: $error');
    }
  }

  void getNext() {
    history.add(current);
    current = WordPair.random();
    notifyListeners();
  }

  void getPrevious() {
    if (history.isNotEmpty) {
      current = history.removeLast();
      notifyListeners();
    }
  }

  Future<void> toggleFavorite() async {
    if (user == null) {
      await signInAnonymously();
      return;
    }

    if (favorites.any(
      (fav) => fav.first == current.first && fav.second == current.second,
    )) {
      favorites.removeWhere(
        (fav) => fav.first == current.first && fav.second == current.second,
      );
      await _removeFavorite(current);
    } else {
      favorites.add(current);
      await _saveFavorite(current);
    }
    notifyListeners();
  }

  bool isFavorite(WordPair word) {
    return favorites.any(
      (fav) => fav.first == word.first && fav.second == word.second,
    );
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  Future<void> removeFavorite(WordPair word) async {
    favorites.removeWhere(
      (fav) => fav.first == word.first && fav.second == word.second,
    );
    await _removeFavorite(word);
    notifyListeners();
  }
}

// ...

// ...

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError('no widget for $_selectedIndex');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Namer App'),
        actions: [
          if (appState.user == null)
            IconButton(
              icon: Icon(Icons.login),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => LoginPage()));
              },
              tooltip: 'Login',
            ),
          if (appState.user != null)
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                appState.signOut();
              },
              tooltip: 'Sign Out',
            ),
          IconButton(
            icon: Icon(
              appState.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              appState.toggleTheme();
            },
            tooltip: appState.isDarkMode
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: page,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'A random AWESOME idea:',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 20),
          Text(
            appState.current.asLowerCase,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SparkleButton(
                onPressed: appState.history.isNotEmpty
                    ? () {
                        appState.getPrevious();
                      }
                    : null,
                child: Text('Back'),
              ),
              SizedBox(width: 20),
              SparkleButton(
                onPressed: () {
                  appState.toggleFavorite();
                },
                child: Icon(
                  appState.isFavorite(appState.current)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: appState.isFavorite(appState.current)
                      ? Colors.red
                      : null,
                ),
              ),
              SizedBox(width: 20),
              SparkleButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Go back to the home page and favorite some words!',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: appState.favorites.length,
      itemBuilder: (context, index) {
        var favorite = appState.favorites[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(Icons.favorite, color: Colors.red),
            title: Text(
              favorite.asLowerCase,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () {
                appState.removeFavorite(favorite);
              },
            ),
          ),
        );
      },
    );
  }
}

class SparkleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const SparkleButton({Key? key, required this.onPressed, required this.child})
    : super(key: key);

  @override
  State<SparkleButton> createState() => _SparkleButtonState();
}

class _SparkleButtonState extends State<SparkleButton>
    with TickerProviderStateMixin {
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
        _sparkleController.repeat();
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
        _sparkleController.stop();
        _sparkleController.reset();
      },
      child: AnimatedBuilder(
        animation: _sparkleAnimation,
        builder: (context, child) {
          return Container(
            decoration: _isHovered
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.3),
                        blurRadius: 10 + (5 * _sparkleAnimation.value),
                        spreadRadius: 2 + (2 * _sparkleAnimation.value),
                      ),
                    ],
                  )
                : null,
            child: ElevatedButton(
              onPressed: widget.onPressed,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: _isHovered ? 8 : 2,
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

// ...
class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    final appState = context.read<MyAppState>();
    String? error;

    if (_isSignUp) {
      error = await appState.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      error = await appState.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Sign Up' : 'Sign In')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_circle,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: appState.isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: appState.isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign In'
                      : 'Don\'t have an account? Sign Up',
                ),
              ),
              SizedBox(height: 24),
              Divider(),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: appState.isLoading
                      ? null
                      : () async {
                          await appState.signInAnonymously();
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  icon: Icon(Icons.person_outline),
                  label: Text('Continue as Guest'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

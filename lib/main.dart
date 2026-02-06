import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';

void main() => runApp(const XtraNeoApp());

class XtraNeoApp extends StatelessWidget {
  const XtraNeoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xtra-Neo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFF9146FF),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          BrowseScreen(),
          MultiStreamScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF9146FF),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Browse'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Multi'),
        ],
      ),
    );
  }
}

// ============ BROWSE SCREEN ============
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  List<Map<String, dynamic>> streams = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadStreams();
  }

  Future<void> loadStreams() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('https://api.twitch.tv/helix/streams?first=20'),
        headers: {'Client-ID': 'kimne78kx3ncx6brgo4mv6wki5h1ko'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => streams = List.from(data['data']));
      }
    } catch (e) {
      print('Error: $e');
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Twitch Streams')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: streams.length,
              itemBuilder: (context, i) {
                final s = streams[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(username: s['user_name']),
                      ),
                    );
                  },
                  child: Card(
                    color: const Color(0xFF1E1E1E),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Image.network(
                            (s['thumbnail_url'] ?? '')
                                .replaceAll('{width}', '400')
                                .replaceAll('{height}', '225'),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['user_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                              ),
                              Text(
                                s['title'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============ PLAYER SCREEN ============
class PlayerScreen extends StatefulWidget {
  final String username;
  const PlayerScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadStream();
  }

  Future<void> _loadStream() async {
    try {
      final url = await _getStreamUrl(widget.username);
      if (url != null) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await _controller!.initialize();
        _controller!.play();
        setState(() => loading = false);
      } else {
        setState(() {
          loading = false;
          error = 'Stream offline';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<String?> _getStreamUrl(String username) async {
    const query = '''
    {
      streamPlaybackAccessToken(channelName: "%s", params: {platform: "web"}) {
        value
        signature
      }
    }
    ''';
    
    try {
      final res = await http.post(
        Uri.parse('https://gql.twitch.tv/gql'),
        headers: {'Client-ID': 'kimne78kx3ncx6brgo4mv6wki5h1ko'},
        body: json.encode({'query': query.replaceFirst('%s', username)}),
      );
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final token = data['data']['streamPlaybackAccessToken']['value'];
        final sig = data['data']['streamPlaybackAccessToken']['signature'];
        
        return 'https://usher.ttvnw.net/api/channel/hls/$username.m3u8'
            '?token=$token&sig=$sig&allow_source=true';
      }
    } catch (e) {
      print('Error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.username)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.white)))
              : Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayer(_controller!),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _controller!.value.isPlaying
                                    ? _controller!.pause()
                                    : _controller!.play();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ============ MULTISTREAM SCREEN ============
class MultiStreamScreen extends StatelessWidget {
  const MultiStreamScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multistream')),
      body: const Center(
        child: Text(
          'Coming Soon!\nAdd up to 4 streams',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

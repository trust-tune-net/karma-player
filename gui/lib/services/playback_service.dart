import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import '../models/song.dart';

enum RepeatMode { off, all, one }

class PlaybackService extends ChangeNotifier {
  // MediaKit player instance (nullable for graceful degradation on unsupported systems)
  Player? _player;
  bool _playerInitialized = false;
  String? _playerError;

  // Playback state
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 0.8;

  // Queue management
  List<Song> _queue = [];
  int _currentIndex = -1;
  List<Song> _originalQueue = [];

  // Playback modes
  RepeatMode _repeatMode = RepeatMode.off;
  bool _isShuffle = false;

  // Mutex to prevent concurrent playback operations
  bool _isPlaybackLocked = false;

  // Getters
  Player? get player => _player;
  bool get isPlayerInitialized => _playerInitialized;
  String? get playerError => _playerError;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  RepeatMode get repeatMode => _repeatMode;
  bool get isShuffle => _isShuffle;

  PlaybackService() {
    _initializePlayer();
  }

  void _initializePlayer() {
    try {
      print('[PLAYBACK] Initializing MediaKit Player...');
      _player = Player();

      // Listen to playback state changes
      _player!.stream.playing.listen((playing) {
        _isPlaying = playing;
        notifyListeners();
      });

      _player!.stream.position.listen((position) {
        _position = position;
        notifyListeners();
      });

      _player!.stream.duration.listen((duration) {
        _duration = duration;
        notifyListeners();
      });

      _player!.stream.completed.listen((completed) {
        if (completed) {
          _onSongCompleted();
        }
      });

      _player!.setVolume(_volume * 100);
      _playerInitialized = true;
      print('[PLAYBACK] ✅ Player initialized successfully');
    } catch (e, stackTrace) {
      _playerError = 'Failed to initialize audio player: $e';
      _playerInitialized = false;
      print('[PLAYBACK] ❌ Player initialization failed: $e');
      print('[PLAYBACK] Stack trace: $stackTrace');
      print('[PLAYBACK] App will continue without audio playback');
    }
  }

  void _onSongCompleted() {
    if (!_playerInitialized || _player == null) return;

    if (_repeatMode == RepeatMode.one && _currentSong != null) {
      _player!.seek(Duration.zero);
      _player!.play();
      return;
    }

    // Auto-advance to next song
    if (_currentIndex < _queue.length - 1) {
      playNext();
    } else if (_repeatMode == RepeatMode.all) {
      // Loop back to start
      playAtIndex(0);
    }
  }

  // Playback controls
  Future<void> playSong(Song song, {List<Song>? queue, bool isShuffled = false}) async {
    // Mutex: prevent concurrent playback operations
    if (_isPlaybackLocked) {
      print('[PLAYBACK] ⚠️ Playback operation already in progress, queuing request...');
      // Wait briefly for the current operation to finish
      await Future.delayed(const Duration(milliseconds: 100));
      if (_isPlaybackLocked) {
        print('[PLAYBACK] ❌ Playback still locked, aborting to prevent crash');
        return;
      }
    }

    _isPlaybackLocked = true;

    try {
      // Stop/pause current playback to avoid concurrent player.open() calls
      if (_playerInitialized && _player != null && _isPlaying) {
        print('[PLAYBACK] Stopping previous playback before starting new song');
        _player!.pause();
        // Give pause operation time to complete (prevents SIGPIPE crashes)
        await Future.delayed(const Duration(milliseconds: 100));
        print('[PLAYBACK] ✓ Previous playback stopped');
      }

      _currentSong = song;

      if (queue != null) {
        if (isShuffled) {
          // Shuffle the queue internally - PlaybackService owns the shuffle logic
          _isShuffle = true;
          _originalQueue = List.from(queue);  // Store original unshuffled order

          // Shuffle while keeping current song at index 0
          _queue = List<Song>.from(queue);
          _queue.remove(song);
          _queue.shuffle();
          _queue.insert(0, song);
          _currentIndex = 0;

          print('[PLAYBACK] Started with shuffled queue (${_queue.length} songs)');
        } else {
          // Normal play, reset shuffle state
          _isShuffle = false;
          _originalQueue.clear();
          _queue = queue;
          _currentIndex = queue.indexOf(song);
          if (_currentIndex == -1) {
            _queue.insert(0, song);
            _currentIndex = 0;
          }
          print('[PLAYBACK] Started with normal queue (${_queue.length} songs)');
        }
      } else if (_queue.isEmpty) {
        _queue = [song];
        _currentIndex = 0;
        _isShuffle = false;
        _originalQueue.clear();
      } else {
        final index = _queue.indexOf(song);
        if (index != -1) {
          _currentIndex = index;
        } else {
          _queue.add(song);
          _currentIndex = _queue.length - 1;
        }
      }

      if (_playerInitialized && _player != null) {
        print('[PLAYBACK] Opening media: ${song.filePath}');
        print('[PLAYBACK] Song title: ${song.title}');

        try {
          // Pass HTTP headers if available (needed for YouTube streams)
          // CRITICAL: await open() before calling play() to prevent race condition
          await _player!.open(Media(song.filePath, httpHeaders: song.httpHeaders ?? {}));
          print('[PLAYBACK] ✓ Media opened successfully');

          _player!.play();
          print('[PLAYBACK] ✓ Started playback');
        } catch (e, stackTrace) {
          print('[PLAYBACK] ❌ Error during open/play: $e');
          print('[PLAYBACK] Stack trace: $stackTrace');
          _playerError = 'Failed to play song: $e';
        }
      } else {
        print('[PLAYBACK] Cannot play song: Player not initialized');
      }

      notifyListeners();
    } finally {
      // Always unlock the mutex
      _isPlaybackLocked = false;
    }
  }

  void togglePlayPause() {
    if (!_playerInitialized || _player == null) {
      print('[PLAYBACK] Cannot toggle play/pause: Player not initialized');
      return;
    }

    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
    notifyListeners();
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    if (!_playerInitialized || _player == null) {
      print('[PLAYBACK] Cannot play next: Player not initialized');
      return;
    }

    // If at end of queue
    if (_currentIndex >= _queue.length - 1) {
      // If shuffle is on, re-shuffle and play from start
      if (_isShuffle && _originalQueue.isNotEmpty) {
        // Use playAtIndex to properly handle async open/play
        final shuffled = List<Song>.from(_originalQueue);
        shuffled.shuffle();
        _queue = shuffled;
        await playAtIndex(0);
        print('[PLAYBACK] Re-shuffled at end of queue');
        return;
      }

      // If repeat all is on, loop to start
      if (_repeatMode == RepeatMode.all) {
        await playAtIndex(0);
        return;
      }

      // Otherwise, do nothing (reached end)
      return;
    }

    // Normal case: play next song
    final nextIndex = _currentIndex + 1;
    await playAtIndex(nextIndex);
  }

  void playPrevious() {
    if (!_playerInitialized || _player == null) {
      print('[PLAYBACK] Cannot play previous: Player not initialized');
      return;
    }

    // If more than 3 seconds into song, restart it
    if (_position.inSeconds > 3) {
      _player!.seek(Duration.zero);
      return;
    }

    if (_queue.isEmpty || _currentIndex <= 0) return;

    final prevIndex = _currentIndex - 1;
    playAtIndex(prevIndex);
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    if (!_playerInitialized || _player == null) {
      print('[PLAYBACK] Cannot play at index: Player not initialized');
      return;
    }

    // Mutex: prevent concurrent operations
    if (_isPlaybackLocked) {
      print('[PLAYBACK] ⚠️ Playback locked, skipping playAtIndex');
      return;
    }
    _isPlaybackLocked = true;

    try {
      // Stop previous playback if playing
      if (_isPlaying) {
        _player!.pause();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _currentIndex = index;
      _currentSong = _queue[index];

      // Pass HTTP headers if available (needed for YouTube streams)
      // CRITICAL: await open() before calling play()
      await _player!.open(Media(_queue[index].filePath, httpHeaders: _queue[index].httpHeaders ?? {}));
      _player!.play();
      notifyListeners();
    } catch (e) {
      print('[PLAYBACK] ❌ Error in playAtIndex: $e');
    } finally {
      _isPlaybackLocked = false;
    }
  }

  void seek(Duration position) {
    if (!_playerInitialized || _player == null) {
      print('[PLAYBACK] Cannot seek: Player not initialized');
      return;
    }
    _player!.seek(position);
    notifyListeners();
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (_playerInitialized && _player != null) {
      _player!.setVolume(_volume * 100);
    }
    notifyListeners();
  }

  // Queue management
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    print('[SHUFFLE] Toggled shuffle to: $_isShuffle');

    if (_isShuffle) {
      // Save original order
      _originalQueue = List.from(_queue);
      print('[SHUFFLE] Saved original queue (${_originalQueue.length} songs)');

      // Shuffle while keeping current song at current index
      final shuffled = List<Song>.from(_queue);
      final currentSong = _currentSong;

      if (currentSong != null) {
        shuffled.remove(currentSong);
        shuffled.shuffle();
        shuffled.insert(_currentIndex, currentSong);
        print('[SHUFFLE] Shuffled queue, kept "${currentSong.title}" at index $_currentIndex');
      } else {
        shuffled.shuffle();
        print('[SHUFFLE] Shuffled entire queue');
      }

      _queue = shuffled;
    } else {
      // Restore original order
      if (_originalQueue.isNotEmpty && _currentSong != null) {
        _queue = List.from(_originalQueue);
        _currentIndex = _queue.indexOf(_currentSong!);
        print('[SHUFFLE] Restored original order, current index: $_currentIndex');
      }
    }

    notifyListeners();
    print('[SHUFFLE] notifyListeners() called, state should update');
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        break;
    }
    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
    _originalQueue.clear();
    _currentIndex = -1;
    _isShuffle = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
}

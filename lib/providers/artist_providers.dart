import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/artist_model.dart';
import '../services/artist_service.dart';

// Artist Service Provider
final artistServiceProvider = Provider<ArtistService>((ref) {
  return ArtistService();
});

// Artists List Provider
final artistsProvider = StateNotifierProvider<ArtistsNotifier, ArtistsState>((ref) {
  final artistService = ref.watch(artistServiceProvider);
  return ArtistsNotifier(artistService: artistService);
});

// Artists State
class ArtistsState {
  final List<Artist> artists;
  final bool isLoading;
  final String error;
  final String searchQuery;

  ArtistsState({
    this.artists = const [],
    this.isLoading = false,
    this.error = '',
    this.searchQuery = '',
  });

  ArtistsState copyWith({
    List<Artist>? artists,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return ArtistsState(
      artists: artists ?? this.artists,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// Artists Notifier
class ArtistsNotifier extends StateNotifier<ArtistsState> {
  final ArtistService _artistService;

  ArtistsNotifier({required ArtistService artistService})
      : _artistService = artistService,
        super(ArtistsState());

  Future<void> loadArtists() async {
    state = state.copyWith(isLoading: true, error: '');
    
    try {
      final artists = await _artistService.getArtists(searchQuery: state.searchQuery);
      state = state.copyWith(artists: artists, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> searchArtists(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadArtists();
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  void clearError() {
    state = state.copyWith(error: '');
  }
}

// Selected Artist Provider
final selectedArtistProvider = StateProvider<Artist?>((ref) => null);
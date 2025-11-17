class SpotifyConfig {
  // Render.com backend URL - YAHI CHANGE KARNA HAI
  static const String baseUrl = 'https://i-music-backend.onrender.com';
  
  // API Endpoints
  static const String getTokenUrl = '$baseUrl/api/token';
  static const String searchSongsUrl = '$baseUrl/api/search/songs';
  static const String searchArtistsUrl = '$baseUrl/api/search/artists';
  static const String getArtistUrl = '$baseUrl/api/artists';
  static const String getArtistTopTracksUrl = '$baseUrl/api/artists';
  static const String getTrackUrl = '$baseUrl/api/tracks';
  static const String getRecommendationsUrl = '$baseUrl/api/recommendations';
  
  // NEW Endpoints for local files
  static const String enhanceLocalMetadataUrl = '$baseUrl/api/enhance-local-metadata';
  static const String getArtistsFromLocalUrl = '$baseUrl/api/artists-from-local';
}
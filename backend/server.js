const express = require('express');
const SpotifyWebApi = require('spotify-web-api-node');
const cors = require('cors');

const app = express();

// ================== CONFIGURATION ==================
const config = {
  spotify: {
    clientId: process.env.SPOTIFY_CLIENT_ID,
    clientSecret: process.env.SPOTIFY_CLIENT_SECRET
  },
  server: {
    port: process.env.PORT || 3000,
    nodeEnv: process.env.NODE_ENV || 'development'
  }
};

// Validate required environment variables
if (!config.spotify.clientId || !config.spotify.clientSecret) {
  console.error('❌ Missing Spotify credentials in environment variables');
  console.error('Please set SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET');
  process.exit(1);
}

// ================== MIDDLEWARE ==================
app.use(cors());
app.use(express.json());

// Custom security headers
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  next();
});

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  console.log(`➡️ ${req.method} ${req.originalUrl} - ${new Date().toISOString()}`);
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`⬅️ ${req.method} ${req.originalUrl} - ${res.statusCode} - ${duration}ms`);
  });
  
  next();
});

// Simple rate limiting
const requestCounts = new Map();
setInterval(() => {
  requestCounts.clear();
}, 15 * 60 * 1000); // Clear every 15 minutes

const simpleRateLimit = (req, res, next) => {
  const ip = req.ip || req.connection.remoteAddress;
  const currentCount = requestCounts.get(ip) || 0;
  
  if (currentCount >= 100) {
    return res.status(429).json({
      success: false,
      error: 'Too many requests, please try again later.'
    });
  }
  
  requestCounts.set(ip, currentCount + 1);
  next();
};

app.use('/api/', simpleRateLimit);

// ================== UTILITY CLASSES ==================

// API Response Formatter
class ApiResponse {
  static success(data, message = 'Success', metadata = {}) {
    return {
      success: true,
      message,
      data,
      metadata,
      timestamp: new Date().toISOString()
    };
  }

  static error(message, code = 500, details = null) {
    return {
      success: false,
      error: message,
      code,
      details,
      timestamp: new Date().toISOString()
    };
  }
}

// Simple Cache Implementation
class SimpleCache {
  constructor() {
    this.cache = new Map();
  }

  set(key, value, ttl = 300000) { // 5 minutes default
    this.cache.set(key, {
      value,
      expiry: Date.now() + ttl
    });
  }

  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;
    
    if (Date.now() > item.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return item.value;
  }

  delete(key) {
    this.cache.delete(key);
  }

  clear() {
    this.cache.clear();
  }
}

// Spotify Service Class
class SpotifyService {
  constructor() {
    this.spotifyApi = new SpotifyWebApi({
      clientId: config.spotify.clientId,
      clientSecret: config.spotify.clientSecret
    });
    this.tokenRefreshTime = null;
    this.cache = new SimpleCache();
  }

  async ensureAuthenticated() {
    if (!this.tokenRefreshTime || Date.now() > this.tokenRefreshTime) {
      try {
        const tokenData = await this.spotifyApi.clientCredentialsGrant();
        this.spotifyApi.setAccessToken(tokenData.body['access_token']);
        
        // Set token refresh 5 minutes before expiry
        this.tokenRefreshTime = Date.now() + (tokenData.body['expires_in'] - 300) * 1000;
        
        console.log('🔑 Spotify token refreshed successfully');
        return true;
      } catch (error) {
        console.error('❌ Spotify authentication failed:', error.message);
        throw new Error(`Spotify authentication failed: ${error.message}`);
      }
    }
    return true;
  }

  async searchTracks(query, limit = 20) {
    await this.ensureAuthenticated();
    return await this.spotifyApi.searchTracks(query, { limit });
  }

  async searchArtists(query, limit = 20) {
    await this.ensureAuthenticated();
    return await this.spotifyApi.searchArtists(query, { limit });
  }

  async getArtist(id) {
    await this.ensureAuthenticated();
    return await this.spotifyApi.getArtist(id);
  }

  async getArtistTopTracks(id, market = 'IN') {
    await this.ensureAuthenticated();
    return await this.spotifyApi.getArtistTopTracks(id, market);
  }

  async getTrack(id) {
    await this.ensureAuthenticated();
    return await this.spotifyApi.getTrack(id);
  }

  async getRecommendations(options) {
    await this.ensureAuthenticated();
    return await this.spotifyApi.getRecommendations(options);
  }

  // Format track response consistently
  formatTrack(track) {
    return {
      id: track.id,
      name: track.name,
      artists: track.artists.map(artist => ({
        id: artist.id,
        name: artist.name,
        type: artist.type
      })),
      album: {
        id: track.album.id,
        name: track.album.name,
        images: track.album.images,
        release_date: track.album.release_date,
        total_tracks: track.album.total_tracks
      },
      duration_ms: track.duration_ms,
      preview_url: track.preview_url,
      external_urls: track.external_urls,
      popularity: track.popularity,
      explicit: track.explicit,
      type: track.type
    };
  }

  // Format artist response consistently
  formatArtist(artist) {
    return {
      id: artist.id,
      name: artist.name,
      images: artist.images,
      popularity: artist.popularity,
      followers: artist.followers?.total || 0,
      genres: artist.genres,
      type: artist.type
    };
  }
}

// Initialize Spotify Service
const spotifyService = new SpotifyService();

// Async error handler wrapper
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Cache middleware
const cacheMiddleware = (duration = 300000) => { // 5 minutes default
  return (req, res, next) => {
    if (req.method !== 'GET') {
      return next();
    }

    const key = req.originalUrl;
    const cachedResponse = spotifyService.cache.get(key);
    
    if (cachedResponse) {
      console.log('📦 Serving from cache:', key);
      return res.json(cachedResponse);
    }
    
    // Override res.json to cache response
    const originalJson = res.json;
    res.json = function(data) {
      if (res.statusCode === 200) {
        spotifyService.cache.set(key, data, duration);
      }
      originalJson.call(this, data);
    };
    
    next();
  };
};

// ================== ROUTES ==================

// Health check
app.get('/', (req, res) => {
  const healthCheck = {
    success: true,
    message: '🎵 I Music Backend is running!',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: config.server.nodeEnv,
    version: '2.0.0'
  };
  
  res.json(healthCheck);
});

// Advanced health check
app.get('/health', (req, res) => {
  const healthCheck = {
    success: true,
    status: 'healthy',
    timestamp: new Date().toISOString(),
    system: {
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      nodeVersion: process.version
    },
    environment: config.server.nodeEnv
  };
  
  res.json(healthCheck);
});

// Get Spotify access token
app.get('/api/token', asyncHandler(async (req, res) => {
  await spotifyService.ensureAuthenticated();
  
  res.json(ApiResponse.success({
    access_token: spotifyService.spotifyApi.getAccessToken(),
    expires_in: Math.floor((spotifyService.tokenRefreshTime - Date.now()) / 1000) + 300
  }, 'Token generated successfully'));
}));

// Search songs with validation and caching
app.get('/api/search/songs', cacheMiddleware(300000), asyncHandler(async (req, res) => {
  const { q: query, limit = 20 } = req.query;

  if (!query || query.trim() === '') {
    return res.status(400).json(ApiResponse.error('Query parameter is required', 400));
  }

  if (limit && (isNaN(limit) || limit < 1 || limit > 50)) {
    return res.status(400).json(ApiResponse.error('Limit must be between 1 and 50', 400));
  }

  console.log('🔍 Searching songs for:', query);

  const searchData = await spotifyService.searchTracks(query, parseInt(limit));
  const tracks = searchData.body.tracks.items.map(track => 
    spotifyService.formatTrack(track)
  );

  res.json(ApiResponse.success(
    { tracks, query },
    'Songs retrieved successfully',
    {
      total_results: searchData.body.tracks.total,
      limit: parseInt(limit),
      offset: searchData.body.tracks.offset
    }
  ));
}));

// Search artists
app.get('/api/search/artists', cacheMiddleware(600000), asyncHandler(async (req, res) => {
  const { q: query, limit = 20 } = req.query;

  if (!query || query.trim() === '') {
    return res.status(400).json(ApiResponse.error('Query parameter is required', 400));
  }

  if (limit && (isNaN(limit) || limit < 1 || limit > 50)) {
    return res.status(400).json(ApiResponse.error('Limit must be between 1 and 50', 400));
  }

  console.log('🎤 Searching artists for:', query);

  const searchData = await spotifyService.searchArtists(query, parseInt(limit));
  const artists = searchData.body.artists.items.map(artist => 
    spotifyService.formatArtist(artist)
  );

  res.json(ApiResponse.success(
    { artists, query },
    'Artists retrieved successfully',
    {
      total_results: searchData.body.artists.total,
      limit: parseInt(limit)
    }
  ));
}));

// Get artist details
app.get('/api/artists/:id', cacheMiddleware(600000), asyncHandler(async (req, res) => {
  const { id } = req.params;

  if (!id) {
    return res.status(400).json(ApiResponse.error('Artist ID is required', 400));
  }

  const artistData = await spotifyService.getArtist(id);
  const artist = spotifyService.formatArtist(artistData.body);

  res.json(ApiResponse.success({ artist }, 'Artist details retrieved successfully'));
}));

// Get artist's top tracks
app.get('/api/artists/:id/top-tracks', cacheMiddleware(300000), asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { market = 'IN' } = req.query;

  if (!id) {
    return res.status(400).json(ApiResponse.error('Artist ID is required', 400));
  }

  const tracksData = await spotifyService.getArtistTopTracks(id, market);
  const tracks = tracksData.body.tracks.map(track => 
    spotifyService.formatTrack(track)
  );

  res.json(ApiResponse.success({ tracks }, 'Top tracks retrieved successfully'));
}));

// Get track details
app.get('/api/tracks/:id', cacheMiddleware(300000), asyncHandler(async (req, res) => {
  const { id } = req.params;

  if (!id) {
    return res.status(400).json(ApiResponse.error('Track ID is required', 400));
  }

  const trackData = await spotifyService.getTrack(id);
  const track = spotifyService.formatTrack(trackData.body);

  res.json(ApiResponse.success({ track }, 'Track details retrieved successfully'));
}));

// Get recommendations
app.get('/api/recommendations', cacheMiddleware(300000), asyncHandler(async (req, res) => {
  const { seed_tracks, seed_artists, limit = 10 } = req.query;

  if (!seed_tracks && !seed_artists) {
    return res.status(400).json(ApiResponse.error('Seed tracks or artists are required', 400));
  }

  if (limit && (isNaN(limit) || limit < 1 || limit > 20)) {
    return res.status(400).json(ApiResponse.error('Limit must be between 1 and 20', 400));
  }

  const recData = await spotifyService.getRecommendations({
    seed_tracks: seed_tracks ? seed_tracks.split(',') : [],
    seed_artists: seed_artists ? seed_artists.split(',') : [],
    limit: parseInt(limit)
  });

  const tracks = recData.body.tracks.map(track => 
    spotifyService.formatTrack(track)
  );

  res.json(ApiResponse.success({ tracks }, 'Recommendations retrieved successfully'));
}));

// ================== ENHANCED BATCH ENDPOINTS ==================

// Batch process multiple artists at once
app.post('/api/artists/batch', asyncHandler(async (req, res) => {
  const { artistNames } = req.body;

  if (!artistNames || !Array.isArray(artistNames)) {
    return res.status(400).json(ApiResponse.error('Artist names array is required', 400));
  }

  if (artistNames.length > 50) {
    return res.status(400).json(ApiResponse.error('Maximum 50 artists allowed per batch', 400));
  }

  console.log(`🎯 Batch processing ${artistNames.length} artists`);

  const results = [];
  const batchSize = 3;
  const delay = 300;

  // Process in batches
  for (let i = 0; i < artistNames.length; i += batchSize) {
    const batch = artistNames.slice(i, i + batchSize);
    const batchPromises = batch.map(async (artistName) => {
      try {
        const searchData = await spotifyService.searchArtists(artistName, 1);
        
        if (searchData.body.artists.items.length > 0) {
          return {
            localName: artistName,
            spotifyArtist: spotifyService.formatArtist(searchData.body.artists.items[0]),
            match: true
          };
        } else {
          return {
            localName: artistName,
            spotifyArtist: null,
            match: false
          };
        }
      } catch (error) {
        return {
          localName: artistName,
          spotifyArtist: null,
          match: false,
          error: error.message
        };
      }
    });

    const batchResult = await Promise.all(batchPromises);
    results.push(...batchResult);

    // Delay between batches to avoid rate limiting
    if (i + batchSize < artistNames.length) {
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  const successful = results.filter(r => r.match && !r.error);
  const failed = results.filter(r => !r.match || r.error);

  res.json(ApiResponse.success(
    { artists: results },
    `Batch processing completed: ${successful.length} successful, ${failed.length} failed`,
    {
      total: results.length,
      successful: successful.length,
      failed: failed.length
    }
  ));
}));

// Get artist data for local songs (GET version)
app.get('/api/artists-from-local', cacheMiddleware(600000), asyncHandler(async (req, res) => {
  const { artistNames } = req.query;

  if (!artistNames) {
    return res.status(400).json(ApiResponse.error('Artist names are required', 400));
  }

  const names = artistNames.split(',').slice(0, 20); // Limit to 20 artists

  const results = [];

  for (const artistName of names) {
    try {
      const searchData = await spotifyService.searchArtists(artistName, 1);
      
      if (searchData.body.artists.items.length > 0) {
        results.push({
          localName: artistName,
          spotifyArtist: spotifyService.formatArtist(searchData.body.artists.items[0]),
          match: true
        });
      } else {
        results.push({
          localName: artistName,
          spotifyArtist: null,
          match: false
        });
      }
    } catch (error) {
      results.push({
        localName: artistName,
        spotifyArtist: null,
        match: false,
        error: error.message
      });
    }
  }

  res.json(ApiResponse.success(
    { artists: results },
    'Local artists data retrieved successfully'
  ));
}));

// Clear cache endpoint (for development)
app.delete('/api/cache', (req, res) => {
  spotifyService.cache.clear();
  res.json(ApiResponse.success(null, 'Cache cleared successfully'));
});

// ================== ERROR HANDLING MIDDLEWARE ==================

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json(ApiResponse.error('Route not found', 404));
});

// Global error handler
app.use((error, req, res, next) => {
  console.error('🚨 Global Error Handler:', error);

  // Spotify API errors
  if (error.body?.error) {
    const spotifyError = error.body.error;
    return res.status(error.statusCode || 500).json(
      ApiResponse.error(spotifyError.message || 'Spotify API error', error.statusCode || 500)
    );
  }

  // Rate limit errors
  if (error.statusCode === 429) {
    return res.status(429).json(
      ApiResponse.error('Rate limit exceeded. Please try again later.', 429)
    );
  }

  // Default error
  res.status(error.status || 500).json(
    ApiResponse.error(error.message || 'Internal server error', error.status || 500)
  );
});

// ================== SERVER START ==================

const PORT = config.server.port;

app.listen(PORT, () => {
  console.log(`
🎵 ===========================================
🚀 I Music Backend v2.0.0 Started Successfully!
📍 Port: ${PORT}
🌍 Environment: ${config.server.nodeEnv}
📊 Cache: Enabled
🔐 Rate Limit: 100 requests/15min
🎯 Spotify API: Connected
📅 Started: ${new Date().toLocaleString()}
🎵 ===========================================
  `);
  
  console.log(`🚀 Server URL: http://localhost:${PORT}`);
  console.log(`❤️  Health Check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 SIGINT received, shutting down gracefully');
  process.exit(0);
});

module.exports = app;
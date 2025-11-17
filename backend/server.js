const express = require('express');
const SpotifyWebApi = require('spotify-web-api-node');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const spotifyApi = new SpotifyWebApi({
  clientId: process.env.SPOTIFY_CLIENT_ID,
  clientSecret: process.env.SPOTIFY_CLIENT_SECRET
});

app.get('/', (req, res) => {
  res.json({ 
    success: true, 
    message: 'I Music Backend is running!',
    timestamp: new Date().toISOString()
  });
});

app.get('/api/token', async (req, res) => {
  try {
    const data = await spotifyApi.clientCredentialsGrant();
    res.json({
      success: true,
      access_token: data.body['access_token'],
      expires_in: data.body['expires_in']
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to get Spotify token'
    });
  }
});

app.get('/api/search', async (req, res) => {
  try {
    const { q: query, limit = 20 } = req.query;
    
    if (!query) {
      return res.status(400).json({
        success: false,
        error: 'Query parameter is required'
      });
    }

    const tokenData = await spotifyApi.clientCredentialsGrant();
    spotifyApi.setAccessToken(tokenData.body['access_token']);
    
    const searchData = await spotifyApi.searchTracks(query, { 
      limit: parseInt(limit) 
    });
    
    const tracks = searchData.body.tracks.items.map(track => ({
      id: track.id,
      name: track.name,
      artists: track.artists.map(artist => artist.name),
      album: track.album.name,
      duration_ms: track.duration_ms,
      preview_url: track.preview_url,
      images: track.album.images
    }));
    
    res.json({
      success: true,
      tracks: tracks
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: 'Search failed'
    });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
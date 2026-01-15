package gobackend

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

type LRCLibAPIReponse struct {
	ID           int     `json:"id"`
	Name         string  `json:"name"`
	TrackName    string  `json:"trackName"`
	ArtistName   string  `json:"artistName"`
	AlbumName    string  `json:"albumName"`
	Duration     float64 `json:"duration"`
	Instrumental bool    `json:"instrumental"`
	PlainLyrics  *string `json:"plainLyrics"`
	SyncedLyrics *string `json:"syncedLyrics"`
}

func fetchLRCLIBLyrics(
	ctx context.Context,
	artistName string,
	trackName string,
	albumName string,
	duration int,
) string {

	LogDebug("LRCLIB", "fallback triggered")

	params := url.Values{}
	params.Set("artist_name", artistName)
	params.Set("track_name", trackName)

	if albumName != "" {
		params.Set("album_name", albumName)
	}
	if duration > 0 {
		params.Set("duration", strconv.Itoa(duration))
	}

	fullURL := "https://lrclib.net/api/get?" + params.Encode()

	// ---- DEBUG: request ----
	LogDebug("LRCLIB", "REQUEST")
	LogDebug("LRCLIB", "  artist_name = %q", artistName)
	LogDebug("LRCLIB", "  track_name  = %q", trackName)
	LogDebug("LRCLIB", "  album_name  = %q", albumName)
	LogDebug("LRCLIB", "  duration    = %d", duration)
	LogDebug("LRCLIB", "  url         = %s", fullURL)

	client := &http.Client{Timeout: 15 * time.Second}

	req, err := http.NewRequestWithContext(ctx, "GET", fullURL, nil)
	if err != nil {
		LogDebug("LRCLIB", "ERROR creating request: %v", err)
		return ""
	}

	resp, err := client.Do(req)
	if err != nil {
		LogDebug("LRCLIB", "ERROR executing request: %v", err)
		return ""
	}
	defer resp.Body.Close()

	LogDebug("LRCLIB", "RESPONSE status_code=%d", resp.StatusCode)

	if resp.StatusCode != http.StatusOK {
		LogDebug("LRCLIB", "non-200 response, aborting")
		return ""
	}

	var lrclibResp LRCLibAPIReponse
	if err := json.NewDecoder(resp.Body).Decode(&lrclibResp); err != nil {
		LogDebug("LRCLIB", "ERROR decoding JSON: %v", err)
		return ""
	}

	// ---- DEBUG: response ----
	LogDebug("LRCLIB", "RESPONSE DATA")
	LogDebug("LRCLIB", "  id           = %d", lrclibResp.ID)
	LogDebug("LRCLIB", "  name         = %q", lrclibResp.Name)
	LogDebug("LRCLIB", "  trackName    = %q", lrclibResp.TrackName)
	LogDebug("LRCLIB", "  artistName   = %q", lrclibResp.ArtistName)
	LogDebug("LRCLIB", "  albumName    = %q", lrclibResp.AlbumName)
	LogDebug("LRCLIB", "  duration     = %.2f", lrclibResp.Duration)
	LogDebug("LRCLIB", "  instrumental = %v", lrclibResp.Instrumental)

	if lrclibResp.SyncedLyrics != nil {
		LogDebug("LRCLIB", "  syncedLyrics length = %d", len(*lrclibResp.SyncedLyrics))
	} else {
		LogDebug("LRCLIB", "  syncedLyrics = <nil>")
	}

	if lrclibResp.PlainLyrics != nil {
		LogDebug("LRCLIB", "  plainLyrics length = %d", len(*lrclibResp.PlainLyrics))
	} else {
		LogDebug("LRCLIB", "  plainLyrics = <nil>")
	}

	// ---- DEBUG: decision ----
	if lrclibResp.SyncedLyrics != nil && *lrclibResp.SyncedLyrics != "" {
		LogDebug("LRCLIB", "RESULT: synced lyrics FOUND")
		return *lrclibResp.SyncedLyrics
	}

	if lrclibResp.PlainLyrics != nil && *lrclibResp.PlainLyrics != "" {
		LogDebug("LRCLIB", "RESULT: plain lyrics FOUND")
		return *lrclibResp.PlainLyrics
	}

	LogDebug("LRCLIB", "RESULT: lyrics NOT FOUND")
	return ""
}
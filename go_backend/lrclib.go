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

func fetchLRCLIBLyrics(ctx context.Context, artistName, trackName, albumName string, duration int) string {
	GoLog("querying lrclib for lyrics as a fallback")
	client := &http.Client{Timeout: 15 * time.Second}

	params := url.Values{}
	params.Set("artist_name", artistName)
	params.Set("track_name", trackName)
	if albumName != "" {
		params.Set("album_name", albumName)
	}
	if duration > 0 {
		params.Set("duration", strconv.Itoa(duration))
	}

	req, err := http.NewRequestWithContext(ctx, "GET", "https://lrclib.net/api/get?"+params.Encode(), nil)
	if err != nil {
		GoLog("lrclib: failed to create request: %v", err)
		return ""
	}

	resp, err := client.Do(req)
	if err != nil {
		GoLog("lrclib: failed to execute request: %v", err)
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		GoLog("lrclib: received non-200 status code: %d", resp.StatusCode)
		GoLog("lrclib_not_found")
		return ""
	}

	var lrclibResp LRCLibAPIReponse
	if err := json.NewDecoder(resp.Body).Decode(&lrclibResp); err != nil {
		GoLog("lrclib: failed to decode response: %v", err)
		GoLog("lrclib_not_found")
		return ""
	}

	if lrclibResp.SyncedLyrics != nil && *lrclibResp.SyncedLyrics != "" {
		GoLog("lrclib_found")
		return *lrclibResp.SyncedLyrics
	}

	if lrclibResp.PlainLyrics != nil && *lrclibResp.PlainLyrics != "" {
		GoLog("lrclib_found")
		return *lrclibResp.PlainLyrics
	}

	GoLog("lrclib_not_found")
	return ""
}

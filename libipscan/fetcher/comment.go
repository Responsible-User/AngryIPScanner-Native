package fetcher

import (
	"sync"

	"github.com/Responsible-User/GoNetworkScanner/libipscan/scanner"
)

// CommentFetcher returns user-defined comments for IP addresses.
type CommentFetcher struct {
	mu       sync.RWMutex
	comments map[string]string // IP or MAC -> comment
}

func NewCommentFetcher(comments map[string]string) *CommentFetcher {
	if comments == nil {
		comments = make(map[string]string)
	}
	return &CommentFetcher{comments: comments}
}

func (f *CommentFetcher) ID() string   { return "fetcher.comment" }
func (f *CommentFetcher) Name() string { return "Comment" }
func (f *CommentFetcher) Init()        {}
func (f *CommentFetcher) Cleanup()     {}

func (f *CommentFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	ip := subject.Address.String()

	f.mu.RLock()
	defer f.mu.RUnlock()

	// Try by IP first
	if comment, ok := f.comments[ip]; ok {
		return comment
	}

	// Try by MAC
	if cached, ok := subject.GetParameter(paramMAC); ok {
		if mac, ok := cached.(string); ok && mac != "" {
			if comment, ok := f.comments[mac]; ok {
				return comment
			}
		}
	}

	return nil
}

// SetComment stores a comment for the given key (IP or MAC).
func (f *CommentFetcher) SetComment(key, comment string) {
	f.mu.Lock()
	f.comments[key] = comment
	f.mu.Unlock()
}

package unique

import (
	"reflect"
	"testing"
)

func TestUnique(t *testing.T) {
	got := Unique([]string{"a", "b", "a", "c", "b"})
	want := []string{"a", "b", "c"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

package calc

import "testing"

func TestSub(t *testing.T) {
	cases := []struct{ a, b, want int }{
		{5, 3, 2},
		{3, 5, -2},
		{0, 4, -4},
		{7, 0, 7},
	}
	for _, c := range cases {
		if got := Sub(c.a, c.b); got != c.want {
			t.Fatalf("Sub(%d, %d) = %d, want %d", c.a, c.b, got, c.want)
		}
	}
}

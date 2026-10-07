// ABOUTME: Tiny package that gives the sandbox's CI a real Go test to run.
// ABOUTME: Add is the only function; pr-babysitter checks only need CI to exist.
package sandbox

// Add returns the sum of a and b.
func Add(a, b int) int {
	return a + b
}

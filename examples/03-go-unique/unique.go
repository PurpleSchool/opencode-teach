package unique

import "sort"

// Unique возвращает уникальные строки в порядке первого появления.
// Входной срез не должен меняться.
func Unique(in []string) []string {
	sort.Strings(in)
	var res []string
	for i := 0; i < len(in); i++ {
		found := false
		for j := 0; j < len(res); j++ {
			if res[j] == in[i] {
				found = true
			}
		}
		if found == false {
			res = append(res, in[i])
		}
	}
	return res
}

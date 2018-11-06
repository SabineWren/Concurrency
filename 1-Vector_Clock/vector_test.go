/*
	@license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt
	
	Copyright (C) 2018 SabineWren
	https://github.com/SabineWren
	
	GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
	https://www.gnu.org/licenses/agpl-3.0.html
	
	@license-end
*/
package main

import "testing"
import "time"

func (r node) assertClocks(a int, b int, c int) bool {
	if r.clocks[0] != a { return false }
	if r.clocks[1] != b { return false }
	if r.clocks[2] != c { return false }
	return true
}

//true = write (with propagation)
//false = read (no message passing)
func TestVectorClock(t *testing.T) {
	a, b, c := makeNodes()
	if !a.assertClocks(0, 0, 0) { t.Error(a.clocks) }
	if !b.assertClocks(0, 0, 0) { t.Error(b.clocks) }
	if !c.assertClocks(0, 0, 0) { t.Error(c.clocks) }
	
	a.makeEvent(false)
	b.makeEvent(false)
	c.makeEvent(true)
	time.Sleep(50 * time.Millisecond)
	if !a.assertClocks(2, 0, 1) { t.Error(a.clocks) }
	if !b.assertClocks(0, 2, 1) { t.Error(b.clocks) }
	if !c.assertClocks(0, 0, 1) { t.Error(c.clocks) }
	
	a.makeEvent(true)
	a.makeEvent(false)
	time.Sleep(50 * time.Millisecond)
	if !a.assertClocks(4, 0, 1) { t.Error(a.clocks) }
	if !b.assertClocks(3, 3, 1) { t.Error(b.clocks) }
	if !c.assertClocks(3, 0, 2) { t.Error(c.clocks) }
	
	b.makeEvent(false)
	c.makeEvent(false)
	b.makeEvent(true)
	time.Sleep(50 * time.Millisecond)
	if !a.assertClocks(5, 5, 1) { t.Error(a.clocks) }
	if !b.assertClocks(3, 5, 1) { t.Error(b.clocks) }
	if !c.assertClocks(3, 5, 4) { t.Error(c.clocks) }
	
	a.term <- true
	b.term <- true
	c.term <- true
}


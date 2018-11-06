/*
	@license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt
	
	Copyright (C) 2018 SabineWren
	https://github.com/SabineWren
	
	GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
	https://www.gnu.org/licenses/agpl-3.0.html
	
	@license-end
*/
package main

type node struct {
	clocks  []int
	id        int
	prompt    chan bool
	receive   chan []int
	sends   []chan []int
	term      chan bool
}

func (r node) increment() {
	r.clocks[r.id]++
}

func (r node) makeEvent(isSend bool) {
	r.prompt <- isSend
}

func (r node) getClocks() []int {
	return r.clocks
}

func (r node) broadcast() {
	var values []int = make([]int, len(r.clocks))
	copy(values, r.clocks)
	r.sends[0] <- values
	r.sends[1] <- values
}

func (r node) resync(w []int) {
	for i := 0; i < len(r.clocks); i++ {
		if i != r.id && w[i] > r.clocks[i] {
			r.clocks[i] = w[i]
		}
	}
}

func start(n node) {
	var isSend bool
	var w []int
	for ;; {
		select {
			case isSend = (<-n.prompt):
				n.increment()
				if isSend {
					n.broadcast()
				}
			case w = (<-n.receive):
				n.increment()
				n.resync(w)
			case <- n.term:
				return
		}
	}
}


func makeNodes() (node, node, node) {
	eventA := make(chan bool)
	eventB := make(chan bool)
	eventC := make(chan bool)
	toA := make(chan []int)
	toB := make(chan []int)
	toC := make(chan []int)
	
	a := node{
		clocks: make([]int, 3),
		id: 0,
		prompt: eventA,
		receive: toA,
		sends: []chan []int{toB, toC},
		term: make(chan bool),
	}
	b := node{
		clocks: make([]int, 3),
		id: 1,
		prompt: eventB,
		receive: toB,
		sends: []chan []int{toA, toC},
		term: make(chan bool),
	}
	c := node{
		clocks: make([]int, 3),
		id: 2,
		prompt: eventC,
		receive: toC,
		sends: []chan []int{toA, toB},
		term: make(chan bool),
	}
	
	go start(a)
	go start(b)
	go start(c)
	return a, b, c
}

func main() {
	_, _, _ = makeNodes()
}

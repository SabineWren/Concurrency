#	@license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt
#	
#	Copyright (C) 2018 SabineWren
#	https://github.com/SabineWren
#	
#	GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
#	https://www.gnu.org/licenses/agpl-3.0.html
#	
#	@license-end
defmodule ChordTest do
	use ExUnit.Case
	doctest Chord
	
	test "DHT" do
		#bootstrap
		firstNodeId = Chord.boot()
		send(firstNodeId, {:query, :getNode, 0, self()})
		firstNode = receive do {:response, :getNode, n} -> n end
		assert firstNode[:Id] === firstNodeId
		
		#insert
		id1 = spawn(Nodes, :insertNode, [firstNode[:Id], self()])
		assert_receive({:ok}, 1_000)
		n1 = Nodes.createNode(id1)
		assert n1[:Id] === id1
		
		id2 = spawn(Nodes, :insertNode, [firstNode[:Id], self()])
		assert_receive({:ok}, 1_000)
		n2 = Nodes.createNode(id2)
		assert n2[:Id] === id2
		
		id3 = spawn(Nodes, :insertNode, [firstNode[:Id], self()])
		assert_receive({:ok}, 1_000)
		n3 = Nodes.createNode(id3)
		assert n3[:Id] === id3
		
		#address hashing
		n = Nodes.createNode(self())
		assert n[:Id] === self()
		assert 64 === (Integer.to_string( n[:Address], 16) |> String.length)
		assert 64 === (Integer.to_string(n1[:Address], 16) |> String.length)
		assert 64 === (Integer.to_string(n2[:Address], 16) |> String.length)
		assert 64 === (Integer.to_string(n3[:Address], 16) |> String.length)
		refute n[:Address] === n1[:Address]
		refute n[:Address] === n2[:Address]
		refute n[:Address] === n3[:Address]
		refute n1[:Address] === n2[:Address]
		refute n1[:Address] === n3[:Address]
		refute n2[:Address] === n3[:Address]
		
		#address ranging
		{small, med, large} = [n1[:Address], n2[:Address], n3[:Address]]
		|> Enum.sort
		|> List.to_tuple
		#case: 0 -> n -> target -> s -> M
		#case: 0 -> s -> n -> target -> M
		#case: 0 -> target -> s -> n -> M
		assert Nodes.addressInRange?(small, large, med)#between
		assert Nodes.addressInRange?(med, small, large)#between, before overflowing
		assert Nodes.addressInRange?(large, med, small)#between, after overflowing
		#case: 0 -> target -> n -> s -> M
		#case: 0 -> n -> s -> target -> M
		#case: 0 -> s -> target -> n -> M
		refute Nodes.addressInRange?(med, large, small)#before
		refute Nodes.addressInRange?(small, med, large)#after
		refute Nodes.addressInRange?(large, small, med)#between but overflow
		
		#getNode
		getNode = fn e ->
			send(n1[:Id], {:query, :getNode, e[:Address], self()})
			assert_receive({:response, :getNode, returned}, 1_000)
			assert returned[:Address] === e[:Address]
			assert returned[:Id]      === e[:Id]
			
			send(n2[:Id], {:query, :getNode, e[:Address], self()})
			assert_receive({:response, :getNode, returned}, 1_000)
			assert returned[:Address] === e[:Address]
			assert returned[:Id]      === e[:Id]
			
			send(n3[:Id], {:query, :getNode, e[:Address], self()})
			assert_receive({:response, :getNode, returned}, 1_000)
			assert returned[:Address] === e[:Address]
			assert returned[:Id]      === e[:Id]
			
			send(n1[:Id], {:query, :getNode, e[:Address] + 1, self()})
			assert_receive({:response, :getNode, returned}, 1_000)
			assert returned[:Address] === e[:Address]
			assert returned[:Id]      === e[:Id]
			
			send(n2[:Id], {:query, :getNode, e[:Address] + 1, self()})
			assert_receive({:response, :getNode, returned}, 1_000)
			assert returned[:Address] === e[:Address]
			assert returned[:Id]      === e[:Id]
			
			send(n3[:Id], {:query, :getNode, e[:Address] + 1, self()})
			assert_receive({:response, :getNode, returned}, 1_000)
			assert returned[:Address] === e[:Address]
			assert returned[:Id]      === e[:Id]
		end
		Enum.map([n1, n2, n3], getNode)
		
		#Data
		insert = fn (e, key, value) ->
			#setData
			send(e[:Id], {:query, :setData, self(), key, value})
			assert_receive({:response, :setData, owner}, 1_000)
			
			send(n1[:Id], {:query, :getNode, key, self()})
			assert_receive({:response, :getNode, returned}, 1_000)
			assert returned[:Address] === owner[:Address]
			assert returned[:Id]      === owner[:Id]
			
			#getData
			send(n1[:Id], {:query, :getData, self(), key})
			assert_receive({:response, :getData, place, returned}, 1_000)
			assert returned === value
			assert place[:Address] === owner[:Address]
			assert place[:Id]      === owner[:Id]
		end
		insert.(n1, 600, "some test data")
		insert.(n1, n1[:Address], "some")
		insert.(n1, n1[:Address] + 10, "test")
		insert.(n1, n3[:Address], "data")
		#overwrite
		insert.(n1, n1[:Address], "replaced")
		insert.(n1, n1[:Address] + 10, "more replacing")
		
	end
end

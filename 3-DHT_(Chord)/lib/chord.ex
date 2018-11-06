#	@license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt
#	
#	Copyright (C) 2018 SabineWren
#	https://github.com/SabineWren
#	
#	GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
#	https://www.gnu.org/licenses/agpl-3.0.html
#	
#	@license-end
defmodule Nodes do
	@address_bits 256
	@address_space :math.pow(2, 256) |> round
	
	#seed hash with process id; hashed value becomes probably unique address
	def createNode(pid) do
		unique = Kernel.inspect(pid)
		%{
			Address: :crypto.hash(:sha256, unique)
				|> Base.encode16
				|> String.to_integer(16),
			Id: pid
		}
	end
	
	#documention in tests
	def addressInRange?(aN, aS, aTarget) do
		isOnlyOneNode = aN === aS
		isRangeOverflow = aS < aN
		case {isOnlyOneNode, isRangeOverflow} do
			{true, _}      -> true
			{false, true}  -> aTarget < aS or aTarget >= aN
			{false, false} -> aTarget >= aN and aTarget < aS
		end
	end
	
	def insertNode(firstNodeId, starterId) do
		n = createNode(self())
		
		send(firstNodeId, {:query, :getNode, n[:Address], n[:Id]})
		p = receive do {:response, :getNode, p} -> p end
		
		send(p[:Id], {:query, :getS, n[:Id]})
		s = receive do {:response, :getS, s} -> s end
		
		send(p[:Id], {:query, :setS, n})
		data = receive do {:response, :setS, data} -> data end
		
		send(s[:Id], {:query, :setP, n})
		
		f = updateFingers(n, s)
		#TODO unit test finger table
		#Enum.map(f, fn e -> IO.inspect(e[:Address]) end)
		
		#TODO setTimeout(PERIOD, updateFingers)
		send(starterId, {:ok})
		nodeListen(data, f, n, p, s)
	end
	
	def makeFirst(mainPid) do
		n = createNode(self())
		f = [2..@address_bits]
		|> Enum.map(fn _ -> n end)
		#TODO setTimeout(PERIOD, updateFingers)
		send(mainPid, {:ok})
		nodeListen(%{}, f, n, n, n)
	end
	
	defp nodeListen(data, f, n, p, s) do
		{data, p, s} = receive do
			{:query, :getData, idToReply, key} ->
				sendData(data, idToReply, key, n, s)
				{data, p, s}
			{:query, :getNode, addToGet, idToReply} ->
				sendNode(addToGet, idToReply, n, s)
				{data, p, s}
			{:query, :getS, id} ->
				send(id, {:response, :getS, s})
				{data, p, s}
			{:query, :setData, idToReply, key, value} ->
				data = setData(data, idToReply, n, s, key, value)
				{data, p, s}
			{:query, :setP, inserted} ->
				{data, inserted, s}
			{:query, :setS, inserted} ->
				keys = Map.keys(data)
				|> Enum.filter(fn k -> k < inserted[:Address] end)
				{data, dataXfer} = Map.split(data, keys)
				send(inserted[:Id], {:response, :setS, dataXfer})
				{data, p, inserted}
		end
		nodeListen(data, f, n, p, s)
	end
	
	defp sendNode(addToGet, idToReply, n, s) do
		if addressInRange?(n[:Address], s[:Address], addToGet) do
			send(idToReply, {:response, :getNode, n})
		else
			#TODO optimize using fingers
			send(s[:Id], {:query, :getNode, addToGet, idToReply})
		end
	end
	#TODO share code
	defp sendData(data, idToReply, key, n, s) do
		if addressInRange?(n[:Address], s[:Address], key) do
			value = Map.get(data, key)
			send(idToReply, {:response, :getData, n, value})
		else
			#TODO optimize using fingers
			send(s[:Id], {:query, :getData, idToReply, key})
		end
	end
	#TODO share code
	defp setData(data, idToReply, n, s, key, value) do
		if addressInRange?(n[:Address], s[:Address], key) do
			send(idToReply, {:response, :setData, n})
			Map.put(data, key, value)
		else
			#TODO optimize using fingers
			send(s[:Id], {:query, :setData, idToReply, key, value})
			data
		end
	end
	
	defp updateFingers(n, s) do
		getAddress = fn finger ->
			offset = :math.pow(2, (finger-1)) |> round
			n[:Address] + offset |> rem(@address_space)
		end
		
		updateFinger = fn address ->
			if addressInRange?(n[:Address], s[:Address], address) do
				n
			else
				send(s[:Id], {:query, :getNode, address, n[:Id]})
				receive do {:response, :getNode, result} -> result end
			end
		end
	
		2..@address_bits
		|> Enum.map(getAddress)
		|> Enum.map(updateFinger)
	end
end

defmodule Chord do
	require Nodes

	def boot() do
		firstNodeId = spawn(Nodes, :makeFirst, [self()])
		receive do {:ok} ->
			firstNodeId
		end
	end
end

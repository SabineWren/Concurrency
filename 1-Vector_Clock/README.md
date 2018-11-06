## Rules
Each node has a clock vector, 'Clocks', and an id. I modelled mine as a distributed database, so nodes either read or write. Reads are concurrent, whereas writes require broadcasting to all other nodes. Vector clocks don't necessarily have to broadcast events to all other nodes, but writes should for data consistency (to scale up, broadcasts could fan out from a starting node). The clocks have three rules:

1) on read, increment Clocks[id]

2) on write, increment Clocks[id], then broadcast Clocks to other nodes (a real database would also send the write data)

3) on recieve message W, increment Clocks[id], then update other clock values as per Clocks[j] = max(Clocks[j], W[j]) where j != id 

### Conflict (Data Race)
In a database, a receiver node has to identify if a received transaction is both concurrent and conflicting with one of its own transactions. If so, it's not clear which write should overwrite the other, so we have a data race. The DB designer has to choose how to resolve the conflict, which could require notifying a user of the conflict, or choosing a master node. A conflict can only occur if two nodes concurrently send events.

### Concurrency
Events A and B are concurrent iff ClocksA and ClocksB each have at least one element greater than the corresponding element in the other. ex) ClocksA[1, 2, 3] and ClocksB[3, 2, 1].

### Happens-Before
Event A happens before event B (A -> B) iff ClocksA[i] < ClocksB[i] for some i and ClocksA[j] <= ClocksB[j] for all j. ex) ClocksA[1, 2, 3] and ClocksB[2, 2, 3]

### Testing
Test cases each run one or more reads and one write, then sleep for an arbitrary amount of time to wait for data propagation. The unit tests verify that transactions on the same node happen sequentially, and that the distributed clocks are eventually consistent.

### Limitations
For simplicity, I use unbuffered channels, which safely allows only one write at a time. That means if two nodes broadcast at the same time, they might deadlock waiting for each other.


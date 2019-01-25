Kelly State and Semantics
========================

Specification header
-------------

K requires us to give our module a name. 

K Allows us to split our definition across multiple files but I don't use this feature. I only separate the program layout into a different file (nothing exciting or required for you to understand the spec).

```k
require "data.k"

module KELLY
    imports KELLY-DATA
```

Configuration
-------------

Note that the genesis block is represented by the initial UTXO.

```k
    configuration
      <k> $PGM:Ledger </k>
      <currEpoch>0</currEpoch>
      <currSlot>0</currSlot>
      <utxo map="*">
        (txid 100; ix 0;):TxIn |-> (addr base 000; coin 50;):TxOut
      </utxo>
      <debugLog list=""> . </debugLog>
```

A ledger is a list of epochs.

```k
  syntax Ledger ::= Epochs
```

Blockchain Structure
------------

In this spec we don't cryptograhically sign data (messy to implement and beside the point). This means our transaction IDs, for example, are simply a unique number. We also don't use base58 because I couldn't figure out how to get it working in K and Int works just as well for our purpose.

### UTXO

```k
  syntax TxId ::= Int
  syntax AddrType ::= "base" | "ptr" | "rwd" // this is unused but theoretically required in Cardano
  syntax Addr ::= AddrType Int
  syntax Coin ::= Int
  syntax Ix ::= Int
  
  syntax TxIn ::= TxIdDecl IxDecl
  syntax TxOut ::= AddrDecl CoinDecl
  syntax TxIns ::= List{TxIn, "-"}
  syntax TxOuts ::= List{TxOut, "-"}

  syntax TxIdDecl ::= "txid" TxId ";"
  syntax AddrDecl ::= "addr" Addr ";"
  syntax CoinDecl ::= "coin" Coin ";"
  syntax IxDecl   ::= "ix" Ix ";"
  syntax TxInDecl  ::= "txin" "[" TxIns "];" [strict]
  syntax TxOutDecl ::= "txout" "["TxOuts "];" [strict]
```

### UTXO Operations

This is a UTXO-specific implementation of the map operators from figure 1 in the spec. Probably these can be made more generic to cover maps in general instead of just the UTXO mapping.

I made it UTXO-specific since for my simple implementation this is all I needed (to implement the UTXO update rules from figure 17)

```k
  syntax RemoveUtxo ::= "#removeUTXO" TxIns
  syntax AddUtxo ::= "#addUTXO" TxIdDecl Int TxOuts

  rule <k> #removeUTXO .TxIns => . ...</k>
  rule <k> #removeUTXO IN:TxIn - INS:TxIns => #removeUTXO INS ...</k>
      <utxo> ... (IN |-> _:TxOut) => (.Map) ...</utxo>

  rule <k> #addUTXO ID:TxIdDecl I:Int .TxOuts => . ...</k>
  rule <k> #addUTXO ID:TxIdDecl I:Int OUT:TxOut - OUTS:TxOuts => #addUTXO ID (I +Int 1) OUTS ...</k>
       <utxo> (. => ID ix I; |-> OUT) ...</utxo>
```

### Balance calculation

I implement both `created` and `destroyed` from figure 15 as one generic `balance` function (as opposed to the spec that creates a `balance` function that is used BY a `created` and `destroyed` function). This could be unified in the future.

```k
  syntax Int ::= balance(K)

  // balance of TxOut
  rule balance(A:AddrDecl coin C:Coin ;) => {C}:>Int

  // balance of TxOuts
  rule <k>balance(OUT:TxOut - OUTS:TxOuts) => balance(OUT) +Int balance(OUTS) ...</k>
  rule balance(.TxOuts) => 0

  // balance of TxIns
  rule <k>balance(IN:TxIn - INS:TxIns) => balance(OUT) +Int balance(INS) ...</k>
       <utxo>... (IN |-> OUT:TxOut) ...</utxo>
  rule balance(.TxIns) => 0
```


### Transactions

Transactions transfer ADA from one account to another by consuming UTXO and creating new UTXO.

This is an implementation of figure 17 which uses `tx` as a signal.

*Note*: My implementation doesn't have explicit fees (needs to be added in a later version)

#### Parse a tx

```k
  syntax TxData ::= TxIdDecl TxInDecl TxOutDecl
  syntax TxDecl ::= "tx" "{" TxData "};"
  syntax Txs ::= List{TxDecl,""}

  // unwrap
  rule tx { TXDATA }; => TXDATA
```

#### Perform checks & update

```k
  syntax K ::= check(TxIdDecl, TxIns, TxOuts) [function]

  // first unwrap tx data then pass to checks
  rule ID:TxIdDecl IN:TxInDecl OUT:TxOutDecl => check(ID, unwrap(IN), unwrap(OUT))

  // ----- Check Tx Data (need to do checks BEFORE modifying state)

  // type of error message is check fails
  syntax TxFailedError ::= TxIdDecl String

  // perform check and then update
  rule check(ID:TxIdDecl, IN:TxIns, OUT:TxOuts)
    => #or balance(IN) <Int balance(OUT) (IN ==K .TxIns) ~> #update ID IN OUT

  // ----- Update UTXO Data

  syntax UpdateUTXOData ::= "#update" TxIdDecl TxIns TxOuts

  // checks pass
  rule false ~> #update ID:TxIdDecl IN:TxIns OUT:TxOuts => #removeUTXO IN ~> #addUTXO ID 0 OUT

  // checks fail
  rule <k>true ~> #update ID:TxIdDecl IN:TxIns OUT:TxOuts => . ...</k>
       <debugLog>... (. => ID "failed. Must have balance(IN)>=balance(OUT) and >=1 input") </debugLog>
```

### Slot

Every epoch is split into slots. Every new epoch starts at slot 0.

We need to keep track of slots in the real ledger spec but they serve no purpose in my version.

*TODO*: add a rule such that slots need to be sequential in numbering

```k
  syntax SlotDecl ::= "slot" Int ";"
  syntax Slot ::= SlotDecl Txs [seqstrict]
  syntax Slots ::= List{Slot,""}

  rule <k>slot S ; => . ...</k>
      <currSlot>_ => S</currSlot>
```

### Epoch

Epochs represent a new iteration of the protocol.

We need to keep track of slots in the real ledger spec but they serve no purpose in my version.

*TODO*: add a rule such that epochs need to be sequential in numbering and can't skip epoch. 

```k
  syntax EpochId ::= Int
  syntax EpochDecl ::= "epoch" EpochId ";"
  syntax Epoch ::= EpochDecl Slots [seqstrict]
  syntax Epochs ::= List{Epoch,""}

  rule <k> epoch E:EpochId ;=> . ...</k>
      <currEpoch>_ => {E}:>Int</currEpoch>
      <currSlot>_ => 0</currSlot>
```

### Charlatan Hideout

For everything to run smoothly, we need some extra rules that make sense as part of an executable spec but seem unnecessary to humans (at least when writing the mathematical spec). This section summarizes all such cases.

#### Unwrap functions

Unlike the matematical spec, I want keywords to be able to execute my program. However, these keywords only dictate the flow of the application and so I need to give them all ignore semantics. One way to do this is to provide "unwrap" functions that extract the data from the keyword-surrounded context.

```k
  syntax TxId ::= unwrap ( TxIdDecl ) [function]
  rule unwrap(txid ID:TxId ;) => ID
  syntax TxIns ::= unwrap ( TxInDecl ) [function]
  rule unwrap(txin [ INS:TxIns ];) => INS
  syntax TxOuts ::= unwrap ( TxOutDecl ) [function]
  rule unwrap(txout [ OUTS:TxOuts ];) => OUTS
```

#### Arithmetic on Balances

To do operations on balances I need to implement heating+cooling rules. See [this video](https://www.youtube.com/watch?v=gYPkhiT2SxA) for more information.

```k
  // define lesser than on balances
  syntax KItem ::= "#lt" K
  rule balance(X:K) <Int balance(Y:K) => balance(X) ~> #lt balance(Y)
  rule X:Int ~> #lt balance(Y:K) => X <Int balance(Y)
  rule X:Int <Int balance(Y:K) => balance(Y) ~> #lt X
  rule Y:Int ~> #lt X:Int => X <Int Y

  // define addition on balances
  syntax KItem ::= "#add" K
  rule balance(X:K) +Int balance(Y:K) => balance(X) ~> #add balance(Y)
  rule X:Int ~> #add balance(Y:K) => X +Int balance(Y)
  rule X:Int +Int balance(Y:K) => balance(Y) ~> #add X
  rule Y:Int ~> #add X:Int => X +Int Y
```

#### Custom or function

The builtin `orBool` function wasn't behaving (seems to only work on primitive types that don't need heating+cooling) so I created my own custom one.

```k
  syntax Bool ::= "#or" K K [strict]
  syntax OrHole ::= "hole"
  rule #or A:K B:K => A ~> #or hole B
  rule A:Bool ~> #or H:OrHole B:K => B ~> #or A hole
  rule B:Bool ~> #or A:Bool HOLE:OrHole => A orBool B
```


#### Sequential Parsing of Signals

We need to specify that a list of elements (ex: list of tx) should be parsed sequentially . We use the sequentual computation operator `~>` to enforce this. This is what we need for "signals" in the ledger spec.

```k
  rule T:TxDecl Ts:Txs => T ~> Ts [structural]
  rule S:Slot Ss:Slots => S ~> Ss [structural]
  rule S:SlotDecl T:Txs => S ~> T [structural]
  rule E:Epoch Es:Epochs => E ~> Es [structural]
  rule E:EpochDecl S:Slots => E ~> S [structural]
```

#### Equivalence of empty types

Lists have a special terminal character and we need to explicitly say there is nothing special about them (equivalent to no computation)

```k
  rule .Txs => .
  rule .Slots => .
  rule .Epochs => .
  rule .TxOuts => .
  rule .TxIns => .
```

#### Computation result


We also need to define primitive types as terminal when executing the semantics of our grammar. This is necessary for know when to stop heating and start cooling.

```k
  syntax KResult ::= Int | Bool
```

Specification End 
-------------

Specifications need to end with the "endmodule" keyword (to match the module name at the start of this file)

```k
endmodule
```

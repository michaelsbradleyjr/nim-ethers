import std/json
import pkg/asynctest
import pkg/stint
import pkg/ethers
import ./hardhat

type

  Erc20* = ref object of Contract
  TestToken = ref object of Erc20

  Transfer = object of Event
    sender {.indexed.}: Address
    receiver {.indexed.}: Address
    value: UInt256

method totalSupply*(erc20: Erc20): UInt256 {.base, contract, view.}
method balanceOf*(erc20: Erc20, account: Address): UInt256 {.base, contract, view.}
method allowance*(erc20: Erc20, owner, spender: Address): UInt256 {.base, contract, view.}
method transfer*(erc20: Erc20, recipient: Address, amount: UInt256) {.base, contract.}

method mint(token: TestToken, holder: Address, amount: UInt256) {.base, contract.}

suite "Contracts":

  var token: TestToken
  var provider: JsonRpcProvider
  var snapshot: JsonNode
  var accounts: seq[Address]

  setup:
    provider = JsonRpcProvider.new("ws://localhost:8545")
    snapshot = await provider.send("evm_snapshot")
    accounts = await provider.listAccounts()
    let deployment = readDeployment()
    token = TestToken.new(!deployment.address(TestToken), provider)

  teardown:
    discard await provider.send("evm_revert", @[snapshot])

  test "can call constant functions":
    check (await token.totalSupply()) == 0.u256
    check (await token.balanceOf(accounts[0])) == 0.u256
    check (await token.allowance(accounts[0], accounts[1])) == 0.u256

  test "can call non-constant functions":
    token = TestToken.new(token.address, provider.getSigner())
    await token.mint(accounts[1], 100.u256)
    check (await token.totalSupply()) == 100.u256
    check (await token.balanceOf(accounts[1])) == 100.u256

  test "can call non-constant functions without a signer":
    await token.mint(accounts[1], 100.u256)
    check (await token.balanceOf(accounts[1])) == 0.u256

  test "can call constant functions without a return type":
    token = TestToken.new(token.address, provider.getSigner())
    proc mint(token: TestToken, holder: Address, amount: UInt256) {.contract, view.}
    await mint(token, accounts[1], 100.u256)
    check (await balanceOf(token, accounts[1])) == 0.u256

  test "fails to compile when function has an implementation":
    let works = compiles:
      proc foo(token: TestToken, bar: Address) {.contract.} = discard
    check not works

  test "fails to compile when function has no parameters":
    let works = compiles:
      proc foo() {.contract.}
    check not works

  test "fails to compile when non-constant function has a return type":
    let works = compiles:
      proc foo(token: TestToken, bar: Address): UInt256 {.contract.}
    check not works

  test "can connect to different providers and signers":
    let signer0 = provider.getSigner(accounts[0])
    let signer1 = provider.getSigner(accounts[1])
    await token.connect(signer0).mint(accounts[0], 100.u256)
    await token.connect(signer0).transfer(accounts[1], 50.u256)
    await token.connect(signer1).transfer(accounts[2], 25.u256)
    check (await token.connect(provider).balanceOf(accounts[0])) == 50.u256
    check (await token.connect(provider).balanceOf(accounts[1])) == 25.u256
    check (await token.connect(provider).balanceOf(accounts[2])) == 25.u256

  test "receives events when subscribed":
    var transfers: seq[Transfer]

    proc handleTransfer(transfer: Transfer) =
      transfers.add(transfer)

    let signer0 = provider.getSigner(accounts[0])
    let signer1 = provider.getSigner(accounts[1])

    let subscription = await token.subscribe(Transfer, handleTransfer)
    await token.connect(signer0).mint(accounts[0], 100.u256)
    await token.connect(signer0).transfer(accounts[1], 50.u256)
    await token.connect(signer1).transfer(accounts[2], 25.u256)
    await subscription.unsubscribe()

    check transfers == @[
      Transfer(receiver: accounts[0], value: 100.u256),
      Transfer(sender: accounts[0], receiver: accounts[1], value: 50.u256),
      Transfer(sender: accounts[1], receiver: accounts[2], value: 25.u256)
    ]

  test "stops receiving events when unsubscribed":
    var transfers: seq[Transfer]

    proc handleTransfer(transfer: Transfer) =
      transfers.add(transfer)

    let signer0 = provider.getSigner(accounts[0])

    let subscription = await token.subscribe(Transfer, handleTransfer)
    await token.connect(signer0).mint(accounts[0], 100.u256)
    await subscription.unsubscribe()

    await token.connect(signer0).transfer(accounts[1], 50.u256)

    check transfers == @[Transfer(receiver: accounts[0], value: 100.u256)]

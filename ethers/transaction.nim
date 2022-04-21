import pkg/stew/byteutils
import ./basics

type
  Transaction* = object of RootObj
    sender*: ?Address
    to*: Address
    data*: seq[byte]
    nonce*: ?UInt256
    chainId*: ?UInt256
    gasPrice*: ?UInt256
    gasLimit*: ?UInt256

  TransactionResponse* = ref object of Transaction
    blockNumber*: ?UInt256
    blockHash*: ?array[32, byte]
    timestamp*: ?UInt256
    confirmations*: Natural
    raw*: ?seq[byte]

  TransactionReceipt* = object
    sender*: ?Address
    to*: ?Address
    contractAddress*: ?Address
    transactionIndex*: Natural
    gasUsed*: UInt256
    logsBloom*: seq[byte]
    blockHash*: array[32, byte]
    transactionHash*: array[32, byte]
    logs*: seq[Log]
    blockNumber*: Natural
    confirmations*: Natural
    cumulativeGasUsed*: UInt256
    byzantium*: bool
    status*: bool


func `$`*(transaction: Transaction): string =
  result = "("
  if sender =? transaction.sender:
    result &= "from: " & $sender & ", "
  result &= "to: " & $transaction.to & ", "
  result &= "data: 0x" & $transaction.data.toHex
  if nonce =? transaction.nonce:
    result &= ", nonce: 0x" & $nonce.toHex
  if chainId =? transaction.chainId:
    result &= ", chainId: " & $chainId
  if gasPrice =? transaction.gasPrice:
    result &= ", gasPrice: 0x" & $gasPrice.toHex
  if gasLimit =? transaction.gasLimit:
    result &= ", gasLimit: 0x" & $gasLimit.toHex
  result &= ")"
